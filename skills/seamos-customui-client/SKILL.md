---
name: seamos-customui-client
description: >
  SeamOS apps serve their CustomUI through a per-feature reverse proxy with
  a dynamically assigned WebSocket port. Browser code that ignores this
  produces silently broken output on every device — 404s on absolute paths,
  hardcoded port failures, malformed WS frames, CORS errors on cloud APIs.
  Use this skill for any HTML/JS that lives inside a SeamOS app's UI surface
  (monitor pages, control buttons, topic streams, charts, WS publishes,
  marketplace/cloud API calls) — even when the user frames it as a generic
  web problem like "fetch 404", "WS not connecting", "CORS blocked", or
  "how do I read this stream in the browser". Covers `get_assigned_ports`
  port discovery, the four-frame WS protocol (publish / publish_ack /
  topic / external_api_response), payload.PL parsing, and the
  correlation-id cloud-proxy envelope for external HTTPS. Trigger
  generously: under-triggering this skill produces code that compiles
  fine and breaks on every real device.
---

# SeamOS CustomUI Client

Browser-side companion to `seamos-app-framework`. The app's Java/C++ side
opens a WebSocket at `/socket` (see that skill); this skill is everything the
HTML/JS inside CustomUI needs to **find that socket, talk to it, and proxy
external HTTPS through it**.

## Why this exists (the one thing that surprises everyone)

Each app gets a **dynamically assigned external port** at runtime, and the
device's FIF web server **reverse-proxies the UI under a per-feature prefix
like `/{featureId}/...`**. Two consequences flow from this and they trip up
every first-time author:

1. The port is not known at build time → the UI must ask for it via a
   `get_assigned_ports` HTTP call before opening the WebSocket.
2. That HTTP call **must use a relative URL** (`get_assigned_ports`, no
   leading slash). A leading slash escapes the `/{featureId}/` prefix and
   the request 404s.

Once you have the external port, the WebSocket goes straight to it —
`ws://${location.hostname}:${wsPort}/socket` — bypassing the reverse proxy.

## Workflow

1. **Discover the port** — `references/port-discovery.md`. Always relative
   URL. Response values may be strings; coerce to number.
2. **Open the WebSocket** to `ws://<host>:<port>/socket`.
3. **Speak the frame protocol** — `references/ws-protocol.md`. Four frame
   shapes: outgoing `publish`, incoming `publish_ack`, incoming `topic`,
   incoming `external_api_response`.
4. **(Optional) Proxy external HTTPS** through the WS using the cloud-proxy
   envelope — `references/cloud-proxy.md`. Required when the UI needs to
   call marketplace / cloud APIs that the browser can't reach directly.
5. When in doubt, read `references/full-example.html` — a complete, working
   monitor/control page that exercises every frame type.

## Pattern selection

| Task | Read |
|------|------|
| First-time CustomUI scaffold | port-discovery.md → ws-protocol.md → full-example.html |
| "Show topic X live in the UI" | ws-protocol.md (incoming `topic` shape) |
| "Add a button that toggles interface Y" | ws-protocol.md (outgoing `publish`) |
| "UI needs to hit marketplace / cloud API" | cloud-proxy.md |
| "Why does my fetch get 404?" | port-discovery.md (relative URL gotcha) |

## Hard rules

- **Relative URL for `get_assigned_ports`.** Never `/get_assigned_ports`.
- **Coerce port to number.** The map's value is typically a string
  (`{"1456": "59449"}`). Use `Number.parseInt(String(raw), 10)` and validate
  with `Number.isFinite`.
- **Check `ws.readyState === WebSocket.OPEN`** before every `ws.send`. The
  socket closes silently when the app restarts; sending into a closed socket
  throws.
- **Generate a unique `correlation-id` per external API request** and keep a
  pending-map keyed by it. Cloud responses arrive out of order.
- **Write paths into `location.hostname` only** — never hardcode IPs. The
  same UI bundle ships to every device.

## Cross-references

- Server side (Java/C++ WebSocket endpoint at `/socket`):
  `seamos-app-framework` → WebSocket section.
- Interface registration (the `interface` field used in `publish` frames is
  the FD-generated interface path, e.g. `Implement.setAllSectionValveOpen`):
  `seamos-plugins` → interface JSON synthesis.
