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

### REST routes use the same port — the UI gateway does NOT proxy them

This is the second surprise, and it's not obvious from the WS-focused docs.
The UI gateway (port 6563 in `--via-fd-cli`) only serves **static UI assets +
the `get_assigned_ports` endpoint**. Anything you registered on the C++/Java
side with `registerRoute("/crops", ...)` / `registerGetService("crops", ...)`
lives on the **same dynamically-assigned port as the WebSocket** (1456
internally, whatever `get_assigned_ports` returns externally).

```js
// WRONG — hits the UI gateway, which doesn't know about /crops → 404
const res = await fetch('crops')

// WRONG — for the same reason: relative-to-UI-gateway, not the app port
const res = await fetch('/crops')

// CORRECT — same base the WebSocket uses
const apiBase = `http://${location.hostname}:${wsPort}`
const res = await fetch(`${apiBase}/crops`)
```

A tiny helper keeps the rest of the UI honest:

```js
let API_BASE = null

async function ensureApiBase() {
  if (API_BASE) return API_BASE
  const res = await fetch('get_assigned_ports', { cache: 'no-store' })
  const ports = await res.json()
  const raw = Object.values(ports)[0]
  const port = typeof raw === 'number' ? raw : Number.parseInt(String(raw), 10)
  if (!Number.isFinite(port)) throw new Error('bad get_assigned_ports')
  API_BASE = `http://${location.hostname}:${port}`
  return API_BASE
}

async function api(path, init) {
  const base = await ensureApiBase()
  return fetch(`${base}${path}`, init)  // path = '/crops', '/work-logs', ...
}

// Usage everywhere: const res = await api('/crops')
```

The same `port` value is what you build the `ws://...:${port}/socket` URL
from — there is exactly one app port per feature instance, shared by REST
and WebSocket.

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
| "UI needs to call my own REST endpoint (`/crops`, etc.)" | "REST routes use the same port" section above |
| "UI needs to hit marketplace / cloud API" | cloud-proxy.md |
| "Why does my fetch get 404?" | port-discovery.md (relative URL gotcha for `get_assigned_ports`); same-port section above (for app-defined REST routes) |
| "What component should I use for X (Button / Toggle / Modal / ...)?" | UI design system rules + ADS MCP usage live in `seamos-customui-ux` (Foundation rule, vanilla fallback, MCP call flow) |

## Hard rules

- **Relative URL for `get_assigned_ports`.** Never `/get_assigned_ports`.
- **App-defined REST routes go through the assigned port, not the UI gateway.**
  `${location.hostname}:${wsPort}/crops`, never `/crops` or `crops` alone.
  The UI gateway (6563) only serves static assets + `get_assigned_ports`.
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
- UI design system rules (Foundation rule — Use ADS, vanilla CustomUI
  fallback, ADS MCP call flow, UX principles):
  `seamos-customui-ux`. This skill (client) only handles transport;
  visual primitives, component selection, and design tokens belong
  there.
