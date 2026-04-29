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
- Auth: `X-API-Key` header
- URL: configurable via environment/`.mcp.json`

## SeamOS MCP Tools

| Tool | Required Scope | Description |
|------|---------------|-------------|
| `list_apps` | APP_READ | List apps owned by the authenticated user |
| `get_app_status` | APP_READ | Get app detail and version deployment status |
| `create_app` | APP_DEPLOY | Get REST endpoint info for creating a new app |
| `update_app` | APP_DEPLOY | Get REST endpoint info for uploading a new version |
| `edit_app_metadata` | APP_WRITE | Edit app metadata (name, description, category, etc.) |

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

MCP servers are configured via `.mcp.json` at the project root. This file is **gitignored** because it contains user-specific API keys.

```json
{
  "mcpServers": {
    "seamos-marketplace": {
      "url": "http://localhost:8088/mcp",
      "headers": {
        "X-API-Key": "${SEAMOS_API_KEY}"
      }
    }
  }
}
```

- The `url` field supports both local (`localhost`) and production deployments.
- API keys must be provided via environment variables — never hardcoded.

## Development Principles

- **Open-source first**: Designed for generic environments. No hardcoded secrets or org-specific paths.
- **Configurable endpoints**: All MCP server URLs are user-configurable, not embedded in code.
- **Environment variables for secrets**: Users supply API keys via env vars referenced in `.mcp.json`.
- **Gitignore secrets**: `.mcp.json` must always remain in `.gitignore`.

## 레포/프로젝트 정보
- 조직: AGMO-Inc
- 프로젝트명: AGMO SeamOS System
- 프로젝트 url: https://github.com/orgs/AGMO-Inc/projects/7
- 레포: https://github.com/AGMO-Inc/seamos-everywhere