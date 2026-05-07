# SeamOS Common Rules

Shared rules and constraints for SeamOS MCP Server integration skills (upload-app, update-app, manage-device-app).

## 1. Upload Token Masking

The marketplace multipart endpoints (`POST /v2/apps`, `POST /v2/apps/{id}/versions`) authenticate with a one-time upload token (`ut_*`, 5-minute TTL, single-use) returned by the `create_app` / `update_app` MCP tools, sent as `Authorization: Bearer ut_...`. When displaying any output to the user — summaries, logs, debug info, command previews, or result reports — **ALWAYS mask the token**.

- **Display format**: Show only the first 6 characters followed by `***` (e.g., `ut_abc***`)
- **Full token location**: The complete token should appear only inside the actual curl execution within shell scripts (`upload.sh`, `update.sh`) — never in user-facing text. The scripts mask `--upload-token` automatically in `--dry-run` output.
- **No reuse, no hardcoding**: Tokens are obtained per-upload from the MCP response and consumed by the first request — never hardcode, log, or persist them.

This rule applies across all steps: command previews, dry-run output, and result reports.

## 2. feuType Matching

The `feuType` part name in the multipart request MUST exactly match the `feuType` value in the app's registered variants JSON.

- **Source of truth**: For `update-app`, the feuType is selected from the app's registered types via `get_app_status`, not guessed from filenames
- **No guessing**: Do NOT derive feuType from `.fif` filenames — it is a server-registered value (e.g., `AUTO-IT_RV-C1000`) that may not match the filename
- **Explicit specification**: For `upload-app`, the feuType MUST be explicitly specified by the user in `config.json`

## 3. File Paths

All file paths should be relative to the project root for portability.

- Use relative paths in user-facing output, logs, and command previews
- This ensures the skill works consistently across different development environments
