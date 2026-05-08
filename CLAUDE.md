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
    }
  }
}
```

- The `url` field supports both local (`localhost`) and production deployments.
- The first MCP call triggers a one-time browser login (OAuth PKCE). The access token is cached by Claude Code and refreshed automatically.

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