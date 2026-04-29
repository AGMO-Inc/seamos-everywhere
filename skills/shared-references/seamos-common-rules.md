# SeamOS Common Rules

Shared rules and constraints for SeamOS MCP Server integration skills (upload-app, update-app, manage-device-app).

## 1. API Key Masking

When displaying any output to the user — including summaries, logs, debug info, command previews, or result reports — **ALWAYS mask the API key**.

- **Display format**: Show only the first 6 characters followed by `***` (e.g., `sdm_ak_***`)
- **Full key location**: The complete API key should appear only inside the actual curl execution within shell scripts (e.g., `upload.sh`, `update.sh`) — never in user-facing text
- **No hardcoding**: NEVER hardcode API keys in commands shown to the user. Always read the API key from `.mcp.json` at runtime

This rule applies across all steps: config parsing reports, command previews, and result reports.

## 2. feuType Matching

The `feuType` part name in the multipart request MUST exactly match the `feuType` value in the app's registered variants JSON.

- **Source of truth**: For `update-app`, the feuType is selected from the app's registered types via `get_app_status`, not guessed from filenames
- **No guessing**: Do NOT derive feuType from `.fif` filenames — it is a server-registered value (e.g., `AUTO-IT_RV-C1000`) that may not match the filename
- **Explicit specification**: For `upload-app`, the feuType MUST be explicitly specified by the user in `config.json`

## 3. File Paths

All file paths should be relative to the project root for portability.

- Use relative paths in user-facing output, logs, and command previews
- This ensures the skill works consistently across different development environments
