---
name: ask-docs
description: >
  Answer questions about SeamOS app development by querying the live official
  docs at docs.seamos.io through the seamos-docs MCP server. Use whenever the
  user asks a factual or how-to question that should be answered from the
  latest published docs rather than memory or local references — including
  fallback queries from other skills whose local references don't cover the
  topic. Triggers: "/ask-docs", "docs", "공식 문서", "공식 docs", "seamos 문서",
  "docs에서", "docs 검색", "문서 찾아", "official docs", "search seamos docs",
  "doc 확인", "docs.seamos.io".
---

# ask-docs

Live-query the SeamOS official documentation at https://docs.seamos.io via the
`seamos-docs` MCP server. The MCP wraps `/llms.txt` (index) and `/llms-full.txt`
(bodies), so answers always reflect the latest published docs — there is no
local doc snapshot to keep in sync.

## When to use

- User explicitly invokes `/ask-docs <question>`
- User asks "공식 문서에 뭐 있어?", "docs에서 찾아줘", "official docs", or
  any phrasing that implies they want an answer grounded in the published docs
- An existing skill's local `references/` don't cover the topic and the
  question could plausibly be answered from docs.seamos.io — call this skill's
  tools as a fallback (see "Cross-skill usage" below)

**Do NOT use this skill for**:
- Generating code → route to `seamos-app-framework`, `seamos-plugins`,
  `seamos-customui-client`
- Marketplace ops → `upload-app`, `update-app`, `manage-device-app`
- Project lifecycle → `create-project`, `regen-sdk-app`, `edit-plugins`

## Workflow

1. **Reformulate the query** — if the user's question is verbose, distill it
   into 3–8 keywords. Keep terminology the docs use (e.g., "FCAL", "FIF",
   "CustomUI", "Protected Region").
2. **Search** — call `search_docs(query, top_k=5)`. Inspect `matches[].score`
   and `snippet` to judge relevance.
3. **Read top hits** — for each candidate URL, choose `mode` by question shape:
   - **Narrow question** (one heading is enough): call `get_doc(url, mode="outline")`
     first to see H1–H3 headings (~5–10% of full size), then
     `get_doc(url, mode="section", section="<heading>")` to grab only that block.
     This avoids pulling whole pages into context.
   - **Broad question** (need the full page): `get_doc(url, mode="full")` (default).
   - If `mode="section"` returns an error listing available headings, retry
     with one of those names — don't escalate straight to `full` unless needed.
4. **Synthesize** — answer **in Korean** (project default). Cite each fact
   with its source URL. If the docs don't say something, say so — never invent.
5. **Discovery fallback** — if the question is broad ("뭘 할 수 있어?",
   "전체 구조"), call `list_sections()` first and present the section tree.

## When the MCP is not yet active

If `search_docs` returns `{ matches: [], notice: ... }` with a message that
`llms.txt` is unreachable, tell the user the live docs index isn't published
yet, name the closest local skill (`seamos-app-framework`, `seamos-plugins`,
etc.), and do **not** fabricate an answer. The MCP starts working automatically
once docs.seamos.io exposes `/llms.txt` — no plugin update needed.

## Cross-skill usage

Other skills MAY call `seamos-docs` tools directly as a long-tail fallback
when their local references don't cover the user's question. The pattern is
identical:

```
search_docs(query) → get_doc(url) for top hits → synthesize with source URLs
```

Always include the source URL in the final answer so the user can verify
against the canonical docs.

## Notes

- Tools are exposed as `mcp__seamos-docs__search_docs`, `mcp__seamos-docs__get_doc`,
  `mcp__seamos-docs__list_sections` (exact prefix depends on Claude Code's MCP
  namespace resolution at runtime).
- Cache lives at `~/.cache/seamos-docs/` with a 24h TTL. Repeated queries
  within 24h are offline-tolerant.
- Env vars:
  - `SEAMOS_DOCS_BASE_URL` — override docs origin (default
    `https://docs.seamos.io`). Useful for preview deployments or local
    Docusaurus servers (e.g., `http://localhost:3000`).
  - `SEAMOS_DOCS_LOCALE` — `ko` (default, matches project Korean policy) or
    `en`. The MCP fetches `/${LOCALE}/llms.txt` for non-`en` locales and
    `/llms.txt` for `en`, matching the Docusaurus i18n layout published at
    docs.seamos.io.
