# seamos-everywhere

An open-source Claude Code plugin for the SeamOS AI Native developer ecosystem. Enables developers to create, build, test, and deploy agricultural machinery (농기계) apps using natural language through Claude Code.

## Architecture

The plugin is composed of three layers:

```
┌──────────────────────────────────────────────────────────┐
│                    Claude Code (User)                    │
└──────────────┬───────────────────────┬───────────────────┘
               │                       │
       ┌───────▼──────┐      ┌──────────▼─────────┐
       │  FD MCP Server│      │  SeamOS MCP Server │
       │  (planned)    │      │  (implemented)     │
       └───────┬───────┘      └──────────┬─────────┘
               │                         │
       ┌───────▼───────┐       ┌─────────▼────────┐
       │  FD Headless  │       │  seamos-backend  │
       │  CLI          │       │  API             │
       └───────────────┘       └──────────────────┘

         SeamOS Skills (REST/WS codegen, testing, docs, UI)
```

### 1. FD MCP Server (planned)
Wraps the FD (FeatureDesigner) headless CLI. Handles project lifecycle on the device side.

- Spec: `concept/FD_Headless_CLI_Spec.md`
- Capabilities: project creation, plugin browsing, skeleton generation, build, simulation

### 2. SeamOS Skills
REST/WebSocket code generation, testing, documentation, and UI development — generalized patterns for SeamOS app development.

### 3. SeamOS MCP Server (implemented)
Wraps the seamos-backend API. Handles app publishing to the SeamOS marketplace.

- Protocol: JSON-RPC 2.0, Stateless, Streamable HTTP
- Auth: OAuth 2.1 (PKCE) — Claude Code's standard HTTP MCP client discovers the authorization server via RFC 9728 protected-resource metadata, opens a browser for one-time SeamOS login, then caches the access token. No API key, no env var.
- URL: configurable via `.mcp.json`
- Multipart uploads (`/v2/apps`, `/v2/apps/{id}/versions`) authenticate with a one-time upload token (`ut_*`, 5-min TTL, single-use) returned by the `create_app` / `update_app` MCP tools.

## SeamOS MCP Tools

| Tool | Required Scope | Description |
|------|---------------|-------------|
| `list_apps` | APP_READ | List apps owned by the authenticated user |
| `get_app_status` | APP_READ | Get app detail and version deployment status |
| `create_app` | APP_DEPLOY | Get REST endpoint info for creating a new app |
| `update_app` | APP_DEPLOY | Get REST endpoint info for uploading a new version |
| `edit_app_metadata` | APP_WRITE | Edit app metadata (name, description, categories, deviceTypes, etc.) |

## Docs Reference MCP (`seamos-docs`)

A **local stdio MCP server** bundled with this plugin at `mcp-servers/seamos-docs/index.cjs`. Fronts https://docs.seamos.io by reading `/llms.txt` (index) and `/llms-full.txt` (page bodies) — the docusaurus-plugin-llms format. Zero npm dependencies, Node 18+ built-in `fetch` only. Registered via `${CLAUDE_PLUGIN_ROOT}` in `mcp-servers.json` so GitHub-based plugin installs pick it up without an `npm install` step.

| Tool | Description |
|------|-------------|
| `search_docs` | Full-text search across the docs (top-k matches with snippets and scores) |
| `get_doc` | Fetch a page by URL with `mode=full\|outline\|section` for token-efficient retrieval |
| `list_sections` | Enumerate doc categories (pass `summary=true` for just names + page counts) |

- **Locale**: default `ko` (set `SEAMOS_DOCS_LOCALE=en` to switch — affects which `/llms.txt` path is fetched)
- **Base URL**: default `https://docs.seamos.io` (override with `SEAMOS_DOCS_BASE_URL`, useful for local Docusaurus servers)
- **Cache**: `~/.cache/seamos-docs/`, 24h TTL — repeated queries are offline-tolerant
- **Entry skill**: `/ask-docs` (`skills/ask-docs/SKILL.md`) is the user-facing entry point. Other skills may call these tools directly as a long-tail fallback when their local `references/` don't cover the topic.

## SessionStart Compass

The plugin ships a `SessionStart` hook (`hooks/hooks.json` + `hooks/session-start` + `hooks/compass.md`) that injects a ~34-line **routing compass** into the conversation as additional context — effectively a session-scoped CLAUDE.md without writing any file to the user's repo. Workspace detection walks up to 8 directory levels looking for any of: `.seamos-workspace.json`, `seamos-assets/`, or `.mcp.json` mentioning `seamos-marketplace` / `seamos-docs`. The compass body enumerates intent → skill mappings, USER_ROOT / protected-region / CustomUI conventions, and common don'ts, so the agent can self-route to the right skill without an explicit slash command. Non-SeamOS sessions: zero output, zero token cost.

## AI Development Pipeline

The end-to-end workflow for building a SeamOS app with this plugin:

| Phase | Layer | Actions |
|-------|-------|---------|
| 1. Project Creation | FD MCP (planned) / create-project skill (implemented) | Browse interfaces (offlineDB) → synthesize interface JSON → generate FSP **+ SDK/APP skeleton** via Dockerized FD Headless (`--skip-sdk-app` for FSP-only) |
| 1b. SDK/APP Refresh | regen-sdk-app skill | Re-run FD Headless `UPDATE_SDK_APP` after the FSP changes — merges regenerated SDK hooks into the existing app project while preserving user code |
| 2. Business Logic | SeamOS Skills | Data handling, WebSocket, REST API, verification |
| 3. UI Development | SeamOS Skills | UI framework template, build & integration |
| 4. Testing | FD MCP | Build, simulation, run |
| 5. Deployment | SeamOS MCP | FIF upload, app registration to marketplace |

## Project Structure

```
seamos-everywhere/
├── CLAUDE.md                    # This file
├── .mcp.json                    # MCP server config — gitignored, user-specific
├── concept/                     # Specs, PPT, diagrams, design references
│   ├── FD_Headless_CLI_Spec.md  # FD headless CLI command specification
│   └── ...
```

## MCP Configuration

MCP servers are configured via `.mcp.json` at the project root. The file is **gitignored** because it pins user-specific endpoints (dev / prod / local) and workspace state — not because it stores secrets. There are no static credentials to protect.

```json
{
  "mcpServers": {
    "seamos-marketplace": {
      "url": "http://localhost:8088/mcp"
    },
    "seamos-docs": {
      "type": "stdio",
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp-servers/seamos-docs/index.cjs"]
    }
  }
}
```

- The `seamos-marketplace.url` field supports both local (`localhost`) and production deployments. First call triggers a one-time browser login (OAuth PKCE); the access token is cached by Claude Code and refreshed automatically.
- The `seamos-docs` stdio entry points at the bundled Node script — `${CLAUDE_PLUGIN_ROOT}` is resolved by Claude Code to the plugin install directory, so no path edits are needed regardless of how the plugin was installed.

## Development Principles

- **Open-source first**: Designed for generic environments. No hardcoded secrets or org-specific paths.
- **Configurable endpoints**: All MCP server URLs are user-configurable, not embedded in code.
- **No static secrets**: Authentication is OAuth-based; the plugin never asks the user for an API key. Multipart uploads use one-time tokens issued per request by the backend.
- **Gitignore workspace state**: `.mcp.json` and `.seamos-workspace.json` remain in `.gitignore` — they pin user-specific endpoints and paths.

## 레포/프로젝트 정보
- 조직: AGMO-Inc
- 프로젝트명: AGMO SeamOS System
- 프로젝트 url: https://github.com/orgs/AGMO-Inc/projects/7
- 레포: https://github.com/AGMO-Inc/seamos-everywhere