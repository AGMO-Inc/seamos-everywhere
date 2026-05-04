# ADS MCP — usage reference

How to query the **Agmo Design System (ADS) MCP server** to look up
components, props, examples, and CSS variable values. ADS is the
canonical source of truth — never write component props from memory.

> This file is a quick reference. The official documentation site is
> `https://ads.seamos.io`; source code, issues, and PRs live at
> `https://github.com/AGMO-Inc/ADS`.

## Endpoints at a glance

| Resource | URL |
|---|---|
| Official docs site | `https://ads.seamos.io` |
| MCP server (production) | `https://mcp.ads.seamos.io` |
| MCP server (development) | `https://mcp.ads-dev.seamos.io` |
| Source / issues / PR | `https://github.com/AGMO-Inc/ADS` |
| npm package | `@seamos/ads` |

---

## What it is

ADS ships with an MCP server that exposes component metadata over
HTTP. Any AI tool (Claude Code, etc.) registered with the MCP can
ask "what components exist?", "how is `Button` used?", "search for a
toggle-like component" and get authoritative, up-to-date answers.
Use **production** by default; switch to **development** only when
deliberately testing pre-release components.

---

## Registration

### One-line install

```bash
claude mcp add --transport http ads https://mcp.ads.seamos.io/
```

### Manual config

Edit `~/.claude.json` or the project-level `.mcp.json`:

```json
{
  "mcpServers": {
    "ads": {
      "type": "http",
      "url": "https://mcp.ads.seamos.io/"
    }
  }
}
```

After registration, ADS appears in the MCP server list and the three
tools below become callable.

---

## Tools

| Tool | Input | Output |
|---|---|---|
| `list_components` | — | full component catalog (names + short descriptions) |
| `search_components(query)` | free-text query | candidate components matching the query |
| `get_component(name)` | exact component name | props signature, usage example, dependent CSS variables |

---

## Call flow

```
[1] Don't know what exists?
    → list_components

[2] Looking for something specific but unsure of the name?
    → search_components("toggle input")
       → returns candidates with short descriptions
       → pick the right one

[3] About to use a component? Right before writing code, ALWAYS:
    → get_component("Button")
       → returns prop signature, usage examples, CSS variables it uses
       → follow the recommended usage pattern as-is

[4] Apply the recommended pattern.
    Whether it's a Flat API (e.g. <Button label="..." />) or a
    Compound API (e.g. <Button.Root>...<Button.Label />...</Button.Root>)
    is per-component — never enforce a hierarchy.
```

---

## Meta rules

- **No guessing.** Component names, prop names, default values —
  query the MCP, don't recall.
- **Call right before use.** Don't cache `list_components` results
  for days; ADS upgrades silently invalidate stale assumptions.
- **Don't import a name you haven't verified.** Run
  `search_components` first if unsure.
- **Don't translate ADS prop names.** They are the API contract.

---

## Natural-language examples

After registering the MCP, you can ask in natural language:

- "ADS Button 사용법 알려줘"
- "토글 비슷한 컴포넌트 있어?"
- "Input 컴포넌트의 props 보여줘"
- "How do I use the Stack component?"
- "Is there a confirmation modal in ADS?"

Claude (or any MCP-aware tool) will route these through
`get_component` / `search_components` and return concrete answers
rooted in current ADS metadata.

---

## When the MCP can't answer

- **Component genuinely missing.** Don't reinvent locally — file an
  issue or PR on the ADS repo. (See SKILL.md's Foundation rule.)
- **Prop missing for a use case.** Same — issue / PR on the ADS
  repo. Don't wrap-and-override.
- **Token category missing.** Same — extending the design system is
  ADS's responsibility, not the consuming app's.

---

## Cross-references

- Why use ADS at all: `../SKILL.md` → "Foundation rule — Use ADS"
- Communication protocol (separate from UI): `seamos-customui-client`
- Backend code: `seamos-app-framework`
