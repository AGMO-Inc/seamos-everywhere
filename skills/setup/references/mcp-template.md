# `.mcp.json` Template Reference

This document explains the project-scope `.mcp.json` template that `setup` writes for the `seamos-marketplace` MCP server. The template lives at `skills/setup/assets/.mcp.json.template` and is materialized into `${USER_ROOT}/.mcp.json` after placeholder substitution.

## Why stdio + mcp-remote

`setup` writes the project-scope MCP entry as a **stdio transport invoking `npx mcp-remote`** rather than a direct `type: http` entry. Two reasons drive this choice: (1) stdio is Claude Code's most reliable MCP transport for stateless Streamable HTTP backends — `type: http` auth has been inconsistent across Claude Code versions; (2) it intentionally diverges from the plugin's own user-scope `mcp-servers.json` (which uses `type: http` with `${user_config.*}` substitution because Claude Code's plugin install flow handles auth there) — the two scopes solve different problems and the project-scope file must be self-contained without relying on `userConfig`.

The marketplace backend authenticates with OAuth 2.1 (PKCE). On the first request, `mcp-remote` receives a `401` with an RFC 9728 `WWW-Authenticate` challenge, runs OAuth discovery → PKCE → loopback redirect → browser login, and caches the access token locally for subsequent calls. No API key is sent.

## Endpoint options

| Endpoint | URL | When |
|---|---|---|
| `dev` (default) | `https://dev.marketplace-api.seamos.io/mcp` | Most users; staging marketplace API. |
| `local` | `http://localhost:8088/mcp` | When running `seamos-backend` locally. |
| `custom` | user-supplied URL | Self-hosted deployments. |

Note: `setup` defaults to `dev`. Other endpoints are advanced — passed via `--endpoint local` or `--endpoint <URL>` flag. The resolved URL is substituted into the `{ENDPOINT_URL}` placeholder of the template.

## Authentication

`setup` does not collect any credential. Authentication runs at MCP-call time:

- The first marketplace tool call (e.g. `list_apps`) triggers Claude Code → `mcp-remote` → OAuth (PKCE). A browser opens, the user signs in to SeamOS once, and the access token is cached.
- Multipart uploads (`upload-app`, `update-app`) additionally fetch a one-time `ut_*` token from the `create_app` / `update_app` MCP responses and use it as `Authorization: Bearer ut_...` for the actual `POST /v2/apps[/{id}/versions]` request. The token is single-use and expires in 5 minutes — the upload scripts handle masking automatically.

## User scope vs Project scope

| | Project scope | User scope |
|---|---|---|
| Plugin location | repo clone | `~/.claude/plugins/...` |
| MCP registration | `setup` writes `${USER_ROOT}/.mcp.json` (this template) | Plugin auto-registers via `mcp-servers.json` + `userConfig` |
| Server name | `seamos-marketplace` | `seamos-marketplace` (same) |
| Transport | stdio + `npx mcp-remote` | http (direct) |
| Auth bootstrap | first tool call → OAuth (PKCE) via `mcp-remote` | first tool call → OAuth (PKCE) via Claude Code's HTTP MCP client |

Note: `setup` detects scope via `${BASH_SOURCE[0]}`. In user scope, `setup` does NOT write `.mcp.json` — it only verifies the plugin's auto-registration is in place and outputs guidance.

## Migration: `sdm-marketplace` → `seamos-marketplace`

Pre-v0.6.1 setups registered the marketplace MCP server under the legacy name `sdm-marketplace`. The current standard name is `seamos-marketplace`. `setup` detects the legacy entry and emits a migration suggestion, but does NOT auto-rename the entry — this is a user-controlled change to avoid breaking external scripts that may reference the old tool prefix `mcp__sdm-marketplace__*`.

To migrate manually: edit `${USER_ROOT}/.mcp.json`, rename the `sdm-marketplace` key to `seamos-marketplace`, remove any extra header arguments from `args` (the marketplace authenticates via OAuth and does not require headers), restart Claude Code, and update any external scripts that still reference `mcp__sdm-marketplace__*` tool names.
