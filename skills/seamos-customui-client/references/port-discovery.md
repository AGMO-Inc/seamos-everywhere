# Port Discovery

The dynamically assigned external port for the app's WebSocket is fetched
from the device's FIF web server via a per-feature endpoint named
`get_assigned_ports`.

## The endpoint

```
GET get_assigned_ports
```

**Relative URL — no leading slash.** The device exposes the UI under
`/{featureId}/...` and reverse-proxies anything below that prefix into the
app. A leading slash escapes the prefix and the request 404s. Authors who
copy-paste from generic JS examples (`fetch('/api/...')`) hit this
immediately.

```js
// CORRECT
const res = await fetch('get_assigned_ports', { cache: 'no-store' })

// WRONG — escapes /{featureId}/ prefix, 404
const res = await fetch('/get_assigned_ports')
```

`cache: 'no-store'` matters because the port can change across app restarts;
a stale cached response would point at a dead port.

## Response shape

```json
{ "<internal_port>": "<external_port>" }
```

Single-entry map. Keys and values are typically **strings** even though they
look like numbers. Real-world example:

```json
{ "1456": "59449" }
```

- `1456` — the in-container port the app's WS server bound to
- `59449` — the host-side port the device exposes externally

The UI only cares about the value (external port).

## Parsing

Coerce defensively — accept both string and number, validate finite:

```js
const ports = await res.json()
const raw = Object.values(ports)[0]
const parsed = typeof raw === 'number' ? raw : Number.parseInt(String(raw), 10)
if (!Number.isFinite(parsed)) {
  throw new Error(`unexpected payload: ${JSON.stringify(ports)}`)
}
const wsPort = parsed
```

## Building the WebSocket URL

The WebSocket connects directly to the external port — it does **not** go
through the `/{featureId}/` reverse proxy.

```js
const wsUrl = `ws://${location.hostname}:${wsPort}/socket`
```

## Building app REST URLs (same port as WS)

REST routes registered on the app side via
`UIWebServiceProvider::registerRoute("/crops", ...)` (C++) or
`registerGetService("crops", ...)` (Java) are served on the **same**
dynamically-assigned port as the WebSocket. The UI gateway (e.g. 6563)
does **not** reverse-proxy them — calling them with a relative URL or with
the gateway's port returns 404.

```js
const apiBase = `http://${location.hostname}:${wsPort}`

// CORRECT — hits the app, which registered /crops
await fetch(`${apiBase}/crops`)

// WRONG — relative path resolves under the UI gateway prefix
await fetch('crops')

// WRONG — leading slash escapes the prefix but still hits the gateway, not the app
await fetch('/crops')
```

So one round-trip to `get_assigned_ports` gives you the host:port for both
WS frames *and* your REST endpoints. Cache it for the lifetime of the page.

- `location.hostname` — never hardcode an IP. The UI bundle ships to every
  device and `location.hostname` is whatever the user typed in the browser.
- `/socket` — the path the app's Java/C++ side registered with
  `UIWebServiceProvider.openWebsocket("/socket", ...)` /
  `registerWebsocketRoute("/socket", ...)`. If the server side uses a
  different path, mirror it here.
- `ws://` (not `wss://`) — the device serves plain WS on the LAN. If the
  page itself loads over `https://`, mixed-content rules will block this;
  serve the UI over `http://` to match.

## Failure modes worth handling

| Symptom | Likely cause |
|---------|-------------|
| `fetch` returns 404 | Used `/get_assigned_ports` (absolute). Drop the slash. |
| `fetch` returns empty `{}` | App not started yet, or feature ID prefix wrong. Retry after a beat. |
| `Number.isFinite` false | Response shape changed. Log the raw payload before throwing. |
| WS `error` immediately | Wrong port (e.g. you grabbed the *internal* one — use `Object.values`, not `Object.keys`). |
| `fetch('${host}:${wsPort}/crops')` blocked by CORS / preflight `OPTIONS` 404 | UI gateway port and assigned app port are different origins. **Server-side fix** — register `handleOptions` (C++) or `registerBeforeFilter` + `registerOptionsService("/*", ...)` (Java) on the app side. See SKILL.md → "CORS — fix on the server, not in the browser" and `seamos-app-framework` → REST API Convention → CORS Handling. |

## Pattern

```js
async function discoverWsUrl() {
  const res = await fetch('get_assigned_ports', { cache: 'no-store' })
  if (!res.ok) throw new Error(`get_assigned_ports HTTP ${res.status}`)
  const ports = await res.json()
  const raw = Object.values(ports)[0]
  const port = typeof raw === 'number' ? raw : Number.parseInt(String(raw), 10)
  if (!Number.isFinite(port)) {
    throw new Error(`bad get_assigned_ports payload: ${JSON.stringify(ports)}`)
  }
  return `ws://${location.hostname}:${port}/socket`
}
```
