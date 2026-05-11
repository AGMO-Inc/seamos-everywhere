# Vibe SeamOS App Agent Playbook

Shared playbook for coordinating a complete SeamOS app build without turning
the agent into a generic web/app generator.

## Agent Stance

- Act as a SeamOS app coordinator: route to the narrow skill that owns each
  decision, then return to the flow map.
- Keep the user in the product loop for app purpose, interface signals,
  marketplace identity, and destructive rebuild/update decisions.
- Prefer existing skills, scripts, and generated context over new snippets.
- Keep outputs grounded in the user's SeamOS workspace, `.seamos-context.json`,
  interface JSON, generated SDK app, and `seamos-assets/`.

## Flow Map

1. Bootstrap or locate workspace: `setup` if markers are missing, then
   `create-project` for FSP + SDK/APP skeleton.
2. Define interface: use `create-project` interface rules and `seamos-plugins`
   for plugin/provider/signal selection.
3. Implement app backend: use `seamos-app-framework` for REST, WebSocket,
   lifecycle, DB persistence, and external API via Cloud plugin.
4. Implement CustomUI: use `seamos-customui-ux` for ADS/operator UX and
   `seamos-customui-client` for ports, REST base URL, WebSocket frames,
   payload parsing, and cloud-proxy envelopes.
5. Build: use `build-fif`; do not hand-package app artifacts.
6. Publish: use `upload-app` for first marketplace release.
7. Update: use `update-app` for a new version of an existing app.

## New App Routing Chart

| User signal | Primary skill | Required handoff |
|---|---|---|
| "Make a SeamOS app" with no project | `create-project` | Collect project name, language, interface JSON/source first |
| Machine/CAN/GPS/IMU/GPIO/platform signal | `seamos-plugins` | Feed selected providers/signals into interface JSON and app code |
| REST route, CRUD, DB, lifecycle, external API | `seamos-app-framework` | Keep CustomUI REST calls on assigned app port |
| Screen, dashboard, controls, charts | `seamos-customui-ux` | Use ADS/operator rules before visual implementation |
| Browser port, WS, topic stream, chart data, cloud API | `seamos-customui-client` | Use `get_assigned_ports`, app-port REST, four-frame WS protocol |
| FIF/package | `build-fif` | Consume `.seamos-context.json` and output to `seamos-assets/builds/` |
| First marketplace publish | `upload-app` | Validate `seamos-assets/` metadata, images, screenshots, FIF |
| Existing marketplace app version | `update-app` | Select app, variant, arch, and FIF; do not use `config.json` |

## Plugin Signals + CustomUI Chart Pattern

- Start with the operator question, not a chart type: what value must be seen
  while the machine is moving?
- Select plugin/provider/signal with `seamos-plugins`; do not invent signal
  names, units, directions, or payload fields.
- Backend owns subscription, normalization, persistence, and REST/WS publishing.
- CustomUI owns rendering, ADS layout, glanceability, and reconnect behavior.
- Chart updates must tolerate sparse, delayed, or missing machine data; show
  explicit stale/unknown states instead of fabricated values.

## REST / DB Flow

1. `seamos-app-framework` defines backend route, CORS behavior, persistence
   path, lifecycle restore/save, and language-specific implementation.
2. `seamos-customui-client` discovers the assigned port with relative
   `get_assigned_ports`.
3. UI REST calls target `http://${location.hostname}:${port}/path`, not the
   UI gateway and not absolute same-origin paths.
4. DB working files stay out of the FIF; only intentional seed data under
   `disk/seed/` is packaged.

## Marketplace Flow

- Build with `build-fif` before upload/update.
- First release uses `upload-app` and requires marketplace metadata, images,
  screenshots, and at least one `.fif`.
- Existing app versions use `update-app`; do not route updates through
  `upload-app` unless the app is genuinely new.
- Do not ask the user to hand-author `.mcp.json`; use `setup` or the helper
  scripts documented by the upload/update skills.

## STOP Conditions

Stop and ask or remediate before continuing when:

- Project name, language, or interface JSON source is ambiguous for a new app.
- A requested signal/plugin cannot be found in the catalog/detail references.
- A command would delete or overwrite hand-written app code.
- Required workspace markers, Docker, marketplace auth, or FIF assets are
  missing and the owning skill cannot self-remediate.
- The user asks for direct external HTTP from the app backend; route through
  the Cloud plugin pattern instead.
- The user requests a generic web UI that ignores CustomUI port/proxy/ADS rules.

## Anti-Generic Rules

- Do not produce a generic React/Vite/SaaS app unless the SeamOS CustomUI
  constraints are explicitly handled.
- Do not hardcode ports, absolute asset paths, Google/CDN fonts, or external
  browser fetches.
- Do not bypass ADS for CustomUI controls, colors, spacing, or typography.
- Do not invent REST/WS protocols; use the language-specific SeamOS patterns.
- Do not duplicate long snippets from child skills in coordinator responses;
  cite the owning skill and load its reference only when needed.

## Token Safety

- Load only the selected plugin detail file and grep very large detail files
  such as `ISOPGN` or `Implement` for the requested signal.
- Prefer catalog tables and flow summaries before opening language templates.
- Keep the coordinator thin: summarize routing decisions, then delegate to
  the specific skill's reference files.
- Do not paste generated code or long snippets unless the user needs the code
  changed in the workspace.
