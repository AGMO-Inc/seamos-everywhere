# `.mcp.json` Template Reference

This document explains the project-scope `.mcp.json` template that `setup` writes for the `seamos-marketplace` MCP server. The template lives at `skills/setup/assets/.mcp.json.template` and is materialized into `${USER_ROOT}/.mcp.json` after placeholder substitution.

## Why stdio + mcp-remote

`setup` writes the project-scope MCP entry as a **stdio transport invoking `npx mcp-remote`** rather than a direct `type: http` entry. Three reasons drive this choice: (1) stdio is Claude Code's most reliable MCP transport for stateless Streamable HTTP backends that need custom headers — http-mode auth can be inconsistent across Claude Code versions, while stdio + `mcp-remote` is stable; (2) `mcp-remote` reliably proxies the `X-API-Key` header on every request, which `type: http` does not always pass cleanly through to the upstream server; (3) it intentionally diverges from the plugin's own user-scope `mcp-servers.json` (which uses `type: http` with `${user_config.*}` substitution because Claude Code's plugin install flow handles header injection there) — the two scopes solve different problems and the project-scope file must be self-contained without relying on `userConfig`.

## Endpoint options

| Endpoint | URL | When |
|---|---|---|
| `dev` (default) | `https://dev.marketplace-api.seamos.io/mcp` | Most users; staging marketplace API. |
| `local` | `http://localhost:8088/mcp` | When running `seamos-backend` locally. |
| `custom` | user-supplied URL | Self-hosted deployments. |

Note: `setup` defaults to `dev`. Other endpoints are advanced — passed via `--endpoint local` or `--endpoint <URL>` flag. The resolved URL is substituted into the `{ENDPOINT_URL}` placeholder of the template.

## API key sourcing

`setup` prompts the user for the marketplace API key, then substitutes the entered value into the `{API_KEY}` placeholder in the template. The substitution is purely textual — `setup` performs no validation or auth round-trip on the key.

- `setup` prompts the user for the marketplace API key, then substitutes it into the `{API_KEY}` placeholder in the template.
- If the user skips the prompt (presses Enter), the placeholder remains literally as `{API_KEY}` in the resulting `.mcp.json` — this is intentional. The user can edit `.mcp.json` manually later, or re-run `setup --reconfigure` to provide the key.
- **No format validation.** `setup` does not check that the key matches `sdm_ak_*` or any other pattern. Reason: the marketplace backend's key format is not finalized; auth failure is reported by the backend on the first MCP call, not at setup time.
- The API key is sensitive — the gitignored `.mcp.json` is the only on-disk location. Do not echo it to logs, do not commit it, do not embed it in scripts.

## User scope vs Project scope

| | Project scope | User scope |
|---|---|---|
| Plugin location | repo clone | `~/.claude/plugins/...` |
| MCP registration | `setup` writes `${USER_ROOT}/.mcp.json` (this template) | Plugin auto-registers via `mcp-servers.json` + `userConfig` |
| API key entry | `setup` prompt → `.mcp.json` substitution | Claude Code plugin install prompt → `userConfig.seamos_api_key` |
| Server name | `seamos-marketplace` | `seamos-marketplace` (same) |
| Transport | stdio + `npx mcp-remote` | http (direct) |

Note: `setup` detects scope via `${BASH_SOURCE[0]}`. In user scope, `setup` does NOT write `.mcp.json` — it only verifies the plugin's auto-registration is in place and outputs guidance.

## Migration: `sdm-marketplace` → `seamos-marketplace`

Pre-v0.6.1 setups registered the marketplace MCP server under the legacy name `sdm-marketplace`. The current standard name is `seamos-marketplace`. `setup` detects the legacy entry and emits a migration suggestion, but does NOT auto-rename the entry — this is a user-controlled change to avoid breaking external scripts that may reference the old tool prefix `mcp__sdm-marketplace__*`.

Before (deprecated, found in pre-v0.6.1 setups):
```json
{ "mcpServers": { "sdm-marketplace": { "type": "stdio", "command": "npx", "args": ["mcp-remote", "...", "--header", "X-API-Key: ..."] } } }
```

After (current):
```json
{ "mcpServers": { "seamos-marketplace": { "type": "stdio", "command": "npx", "args": ["mcp-remote", "...", "--header", "X-API-Key: ..."] } } }
```

To migrate manually: edit `${USER_ROOT}/.mcp.json`, rename the `sdm-marketplace` key to `seamos-marketplace`, restart Claude Code, and update any external scripts that still reference `mcp__sdm-marketplace__*` tool names.
