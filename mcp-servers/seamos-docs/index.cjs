#!/usr/bin/env node
'use strict';

/*
 * seamos-docs MCP server
 *
 * Zero-dependency Node stdio MCP that fronts https://docs.seamos.io.
 * Reads /llms.txt (index) and /llms-full.txt (bodies) — the format published
 * by docusaurus-plugin-llms — caches them locally, and exposes
 *   search_docs / get_doc / list_sections.
 *
 * Index format (llms.txt):
 *   # SeamOS Document
 *   > tagline
 *   ## ko                          <- locale (top-level section)
 *   ### docs                       <- sub-section (category)
 *   - [Title](/path.md): description
 *
 * Body format (llms-full.txt):
 *   <index dump>
 *   ---
 *   # Full Documentation Content   <- anchor
 *   ---
 *   # Page Title
 *   ...body...
 *   ---
 *   # Next Page Title
 *   ...
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

if (typeof fetch === 'undefined') {
  process.stderr.write(
    `[seamos-docs] requires Node 18+ (built-in fetch). Detected ${process.version}\n`
  );
  process.exit(1);
}

const DOCS_BASE = (process.env.SEAMOS_DOCS_BASE_URL || 'https://docs.seamos.io').replace(/\/+$/, '');
// Project policy is Korean responses, so default locale = 'ko'.
const DOCS_LOCALE = (process.env.SEAMOS_DOCS_LOCALE || 'ko').toLowerCase().trim();
const LOCALE_PATH = DOCS_LOCALE === 'en' || DOCS_LOCALE === '' ? '' : `/${DOCS_LOCALE}`;
const LLMS_INDEX_URL = `${DOCS_BASE}${LOCALE_PATH}/llms.txt`;
const LLMS_FULL_URL = `${DOCS_BASE}${LOCALE_PATH}/llms-full.txt`;
const CACHE_DIR = path.join(os.homedir(), '.cache', 'seamos-docs');
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

function log(...args) {
  process.stderr.write(`[seamos-docs] ${args.join(' ')}\n`);
}

function ensureCacheDir() {
  try { fs.mkdirSync(CACHE_DIR, { recursive: true }); } catch (_) {}
}

function cachePath(key) {
  const safe = key.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 200);
  return path.join(CACHE_DIR, safe);
}

async function fetchWithCache(url) {
  ensureCacheDir();
  const cp = cachePath(url);
  try {
    const stat = fs.statSync(cp);
    if (Date.now() - stat.mtimeMs < CACHE_TTL_MS) {
      return fs.readFileSync(cp, 'utf8');
    }
  } catch (_) { /* no cache yet */ }
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'seamos-docs-mcp/0.2' } });
    if (!res.ok) {
      if (fs.existsSync(cp)) {
        log(`fetch ${url} -> ${res.status}; serving stale cache`);
        return fs.readFileSync(cp, 'utf8');
      }
      throw new Error(`HTTP ${res.status} for ${url}`);
    }
    const body = await res.text();
    const ct = (res.headers.get('content-type') || '').toLowerCase();
    if (ct.includes('text/html') || /^\s*(?:<!doctype html|<html)/i.test(body)) {
      if (fs.existsSync(cp)) {
        log(`${url} returned HTML shell; serving stale cache`);
        return fs.readFileSync(cp, 'utf8');
      }
      throw new Error(
        `SPA fallback at ${url} (content-type=${ct || 'unknown'}). llms.txt is likely not yet published at docs.seamos.io.`
      );
    }
    try { fs.writeFileSync(cp, body); } catch (err) { log(`cache write failed: ${err.message}`); }
    return body;
  } catch (err) {
    if (fs.existsSync(cp)) {
      log(`fetch ${url} threw (${err.message}); serving stale cache`);
      return fs.readFileSync(cp, 'utf8');
    }
    throw err;
  }
}

// ---------- URL normalization + parsers ----------

function normalizeUrl(p) {
  if (!p) return '';
  if (/^https?:\/\//i.test(p)) return p;
  let s = p.trim();
  if (!s.startsWith('/')) s = '/' + s;
  s = s.replace(/\.md$/i, '');
  if (s === '/index') s = '/';
  return `${DOCS_BASE}${LOCALE_PATH}${s}`;
}

function parseIndex(text) {
  // ## = locale, ### = category. Pages may also live directly under the locale.
  const sections = [];
  let topSection = null;
  let currentSection = null;
  for (const raw of text.split(/\r?\n/)) {
    const h2 = raw.match(/^##\s+(.+?)\s*$/);
    if (h2) {
      topSection = { name: h2[1].trim(), pages: [] };
      sections.push(topSection);
      currentSection = topSection;
      continue;
    }
    const h3 = raw.match(/^###\s+(.+?)\s*$/);
    if (h3) {
      currentSection = {
        name: topSection ? `${topSection.name} / ${h3[1].trim()}` : h3[1].trim(),
        pages: []
      };
      sections.push(currentSection);
      continue;
    }
    const item = raw.match(/^\s*-\s*\[([^\]]+)\]\(([^)]+)\)\s*(?::\s*(.+))?$/);
    if (item && currentSection) {
      currentSection.pages.push({
        title: item[1].trim(),
        path: item[2].trim(),
        description: (item[3] || '').trim()
      });
    }
  }
  return { sections };
}

function parseFull(text) {
  const lines = text.split(/\r?\n/);
  // Skip the index dump prefix; real bodies start after the
  // "# Full Documentation Content" anchor.
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^#\s+Full\s+Documentation\s+Content/i.test(lines[i])) {
      start = i + 1;
      break;
    }
  }
  if (start < 0) start = 0;

  const pages = [];
  let cur = null;
  function commit() {
    if (!cur) return;
    const body = cur.body.replace(/\s+$/g, '');
    if (cur.title) pages.push({ title: cur.title, body });
  }
  for (let i = start; i < lines.length; i++) {
    const line = lines[i];
    const h1 = line.match(/^#\s+(.+?)\s*$/);
    if (h1) {
      commit();
      cur = { title: h1[1].trim(), body: '' };
      continue;
    }
    if (cur) cur.body += line + '\n';
  }
  commit();
  return { pages };
}

// ---------- Cache + merged pool ----------

let indexCache = null;
let fullCache = null;
let poolCache = null;

async function loadIndex() {
  if (indexCache) return indexCache;
  const text = await fetchWithCache(LLMS_INDEX_URL);
  indexCache = parseIndex(text);
  return indexCache;
}

async function loadFull() {
  if (fullCache) return fullCache;
  const text = await fetchWithCache(LLMS_FULL_URL);
  fullCache = parseFull(text);
  return fullCache;
}

async function buildPool() {
  if (poolCache) return poolCache;
  let idx = null;
  let full = null;
  const errors = {};
  try { idx = await loadIndex(); } catch (err) { errors.index = err.message; }
  try { full = await loadFull(); } catch (err) { errors.full = err.message; }

  // Match index pages to full-text bodies by title. First-wins on collision.
  const bodiesByTitle = new Map();
  if (full) {
    for (const p of full.pages) {
      if (!bodiesByTitle.has(p.title)) bodiesByTitle.set(p.title, p.body);
    }
  }

  const pool = [];
  const byUrl = new Map();
  if (idx) {
    for (const sec of idx.sections) {
      for (const p of sec.pages) {
        const url = normalizeUrl(p.path);
        const entry = {
          title: p.title,
          url,
          path: p.path,
          description: p.description,
          section: sec.name,
          body: bodiesByTitle.get(p.title) || ''
        };
        pool.push(entry);
        if (url) byUrl.set(url, entry);
      }
    }
  } else if (full) {
    for (const p of full.pages) {
      pool.push({ title: p.title, url: '', path: '', description: '', section: '', body: p.body });
    }
  }

  poolCache = { pool, byUrl, hasIndex: !!idx, hasFull: !!full, errors };
  return poolCache;
}

// ---------- Search ----------

function tokenize(s) {
  return (String(s || '').toLowerCase().match(/[\p{L}\p{N}]+/gu) || []).filter((t) => t.length > 1);
}

function scoreEntry(qTokens, title, haystack) {
  const t = (title || '').toLowerCase();
  const h = (haystack || '').toLowerCase();
  let score = 0;
  for (const tok of qTokens) {
    if (t.includes(tok)) score += 5;
    let i = 0, cnt = 0;
    while ((i = h.indexOf(tok, i)) !== -1) { cnt++; i += tok.length; if (cnt >= 5) break; }
    score += cnt;
  }
  return score;
}

function makeSnippet(body, qTokens) {
  if (!body) return '';
  const lower = body.toLowerCase();
  let pos = -1;
  for (const tok of qTokens) {
    const i = lower.indexOf(tok);
    if (i >= 0 && (pos < 0 || i < pos)) pos = i;
  }
  if (pos < 0) pos = 0;
  const start = Math.max(0, pos - 80);
  return body.slice(start, start + 240).replace(/\s+/g, ' ').trim();
}

async function searchDocs(query, topK) {
  const q = tokenize(query);
  if (q.length === 0) return { matches: [] };
  const limit = Number.isInteger(topK) && topK > 0 ? topK : 5;
  const { pool, hasIndex, hasFull, errors } = await buildPool();
  if (pool.length === 0) {
    return {
      matches: [],
      notice: `SeamOS docs unavailable. Tried ${LLMS_INDEX_URL} (${errors.index || 'ok'}) and ${LLMS_FULL_URL} (${errors.full || 'ok'}).`
    };
  }
  const scored = [];
  for (const entry of pool) {
    const hay = `${entry.description} ${entry.body}`;
    const score = scoreEntry(q, entry.title, hay);
    if (score <= 0) continue;
    scored.push({
      title: entry.title,
      url: entry.url,
      section: entry.section,
      snippet: makeSnippet(entry.body, q) || entry.description || '',
      score
    });
  }
  scored.sort((a, b) => b.score - a.score);
  return {
    matches: scored.slice(0, limit),
    total: scored.length,
    indexed: pool.length,
    sources: { index: hasIndex, full: hasFull }
  };
}

// ---------- get_doc with mode support ----------

function extractOutline(markdown) {
  const out = [];
  for (const line of (markdown || '').split(/\r?\n/)) {
    const m = line.match(/^(#{1,3})\s+(.+?)\s*$/);
    if (m) out.push({ level: m[1].length, title: m[2].trim() });
  }
  return out;
}

function renderOutline(headings) {
  if (!headings || headings.length === 0) return '(no headings found)';
  const minLevel = headings.reduce((m, h) => Math.min(m, h.level), 6);
  return headings
    .map((h) => `${'  '.repeat(h.level - minLevel)}- ${'#'.repeat(h.level)} ${h.title}`)
    .join('\n');
}

function extractSection(markdown, target) {
  const lines = (markdown || '').split(/\r?\n/);
  const want = String(target || '').toLowerCase().trim();
  if (!want) return null;
  let startIdx = -1;
  let startLevel = 0;
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^(#{1,6})\s+(.+?)\s*$/);
    if (m && m[2].trim().toLowerCase() === want) {
      startIdx = i;
      startLevel = m[1].length;
      break;
    }
  }
  if (startIdx < 0) return null;
  const out = [lines[startIdx]];
  for (let i = startIdx + 1; i < lines.length; i++) {
    const m = lines[i].match(/^(#{1,6})\s+/);
    if (m && m[1].length <= startLevel) break;
    out.push(lines[i]);
  }
  return out.join('\n').replace(/\s+$/g, '');
}

async function getDoc(url, opts) {
  if (!url || typeof url !== 'string') throw new Error('url required');
  const o = opts || {};
  const mode = (o.mode || 'full').toLowerCase();
  if (!['full', 'outline', 'section'].includes(mode)) {
    throw new Error(`Invalid mode '${mode}'. Use 'full', 'outline', or 'section'.`);
  }
  if (mode === 'section' && !o.section) {
    throw new Error("mode='section' requires a 'section' argument (heading name).");
  }

  const { byUrl } = await buildPool();
  const hit = byUrl.get(url);
  let title = hit ? hit.title : '';
  let markdown = hit && hit.body ? hit.body : '';
  let source = markdown ? 'llms-full' : '';
  if (!markdown) {
    try {
      markdown = await fetchWithCache(url);
      source = 'direct-fetch';
    } catch (err) {
      return {
        url, title, mode, markdown: '',
        error: hit ? `${err.message} (body not in llms-full either)` : err.message
      };
    }
  }

  if (mode === 'outline') {
    return { url, title, mode, source, outline: extractOutline(markdown), markdown: '' };
  }
  if (mode === 'section') {
    const block = extractSection(markdown, o.section);
    if (block === null) {
      const available = extractOutline(markdown).map((h) => h.title).slice(0, 20).join(' | ');
      return {
        url, title, mode, source, markdown: '',
        error: `Section '${o.section}' not found. Top headings: ${available}`
      };
    }
    return { url, title, mode, source, section: o.section, markdown: block };
  }
  return { url, title, mode, source, markdown };
}

// ---------- list_sections ----------

async function listSections(opts) {
  const o = opts || {};
  const summary = o.summary === true || o.summary === 'true';
  try {
    const idx = await loadIndex();
    return {
      sections: idx.sections.map((s) => summary
        ? { name: s.name, pageCount: s.pages.length }
        : {
            name: s.name,
            pageCount: s.pages.length,
            pages: s.pages.map((p) => ({
              title: p.title,
              url: normalizeUrl(p.path),
              description: p.description
            }))
          })
    };
  } catch (err) {
    return { sections: [], error: err.message };
  }
}

// ---------- MCP JSON-RPC stdio loop ----------

const TOOLS = [
  {
    name: 'search_docs',
    description:
      'Full-text search across SeamOS official docs (docs.seamos.io). Returns top-k pages with title, URL, snippet, and score. Use this before get_doc to find relevant pages.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Keywords or natural-language question (e.g., "WebSocket envelope", "FIF build pipeline", "CustomUI port discovery").' },
        top_k: { type: 'integer', description: 'Max results (default 5).', default: 5 }
      },
      required: ['query']
    }
  },
  {
    name: 'get_doc',
    description:
      'Fetch a doc page by URL. For large pages, start with mode=outline (returns only H1–H3 headings, ~5–10% of full size), then call again with mode=section + section=<heading> to grab only the relevant block. Use mode=full (default) when you actually need the whole page.',
    inputSchema: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'Page URL returned by search_docs (e.g., https://docs.seamos.io/ko/docs/3/5/skeleton-code).' },
        mode: {
          type: 'string',
          enum: ['full', 'outline', 'section'],
          description: 'full = entire markdown (default). outline = H1–H3 headings only (cheap, for scanning). section = body under one heading (requires `section`).',
          default: 'full'
        },
        section: {
          type: 'string',
          description: "Heading text to extract when mode='section' — case-insensitive exact match against a markdown heading (any level)."
        }
      },
      required: ['url']
    }
  },
  {
    name: 'list_sections',
    description: 'List doc sections and (optionally) the pages they contain. Pass summary=true to get only section names and page counts — much smaller, useful for "what categories exist?" type questions.',
    inputSchema: {
      type: 'object',
      properties: {
        summary: { type: 'boolean', description: 'When true, omit per-page lists.', default: false }
      }
    }
  }
];

function rpcResult(id, result) { return JSON.stringify({ jsonrpc: '2.0', id, result }); }
function rpcError(id, code, message) { return JSON.stringify({ jsonrpc: '2.0', id, error: { code, message } }); }

async function handle(msg) {
  const { id, method, params } = msg;
  switch (method) {
    case 'initialize':
      return rpcResult(id, {
        protocolVersion: (params && params.protocolVersion) || '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'seamos-docs', version: '0.2.0' }
      });
    case 'initialized':
    case 'notifications/initialized':
      return null;
    case 'tools/list':
      return rpcResult(id, { tools: TOOLS });
    case 'tools/call': {
      const name = params && params.name;
      const args = (params && params.arguments) || {};
      try {
        if (name === 'search_docs') {
          const r = await searchDocs(args.query, args.top_k);
          return rpcResult(id, { content: [{ type: 'text', text: JSON.stringify(r, null, 2) }] });
        }
        if (name === 'get_doc') {
          const r = await getDoc(args.url, { mode: args.mode, section: args.section });
          if (r.error) {
            return rpcResult(id, {
              content: [{ type: 'text', text: `Error: ${r.error}\nURL: ${r.url}\nMode: ${r.mode}` }],
              isError: true
            });
          }
          const headerLines = [
            `Title: ${r.title || '(untitled)'}`,
            `URL: ${r.url}`,
            `Mode: ${r.mode}`
          ];
          if (r.section) headerLines.push(`Section: ${r.section}`);
          if (r.source) headerLines.push(`Source: ${r.source}`);
          const body = r.mode === 'outline' ? renderOutline(r.outline) : r.markdown;
          return rpcResult(id, { content: [{ type: 'text', text: `${headerLines.join('\n')}\n\n${body}` }] });
        }
        if (name === 'list_sections') {
          const r = await listSections({ summary: args.summary });
          return rpcResult(id, { content: [{ type: 'text', text: JSON.stringify(r, null, 2) }] });
        }
        return rpcError(id, -32601, `Unknown tool: ${name}`);
      } catch (err) {
        return rpcError(id, -32000, err.message);
      }
    }
    case 'ping':
      return rpcResult(id, {});
    default:
      if (id !== undefined && id !== null) return rpcError(id, -32601, `Method not found: ${method}`);
      return null;
  }
}

const rl = readline.createInterface({ input: process.stdin });
rl.on('line', async (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  let msg;
  try { msg = JSON.parse(trimmed); }
  catch (err) { log(`bad json: ${err.message}`); return; }
  try {
    const out = await handle(msg);
    if (out) process.stdout.write(out + '\n');
  } catch (err) {
    log(`handler error: ${err.message}`);
    if (msg && msg.id !== undefined && msg.id !== null) {
      process.stdout.write(rpcError(msg.id, -32000, err.message) + '\n');
    }
  }
});

process.on('SIGINT', () => process.exit(0));
process.on('SIGTERM', () => process.exit(0));
