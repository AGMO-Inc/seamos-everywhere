# Cloud Proxy (External HTTPS via WebSocket)

The browser inside CustomUI often can't reach external HTTPS endpoints
directly — CORS, mixed-content rules, and the device's network policy all
get in the way. The app's Java/C++ side ships a proxy
(`CloudDownloadListenerImpl`) that takes a request envelope over the WS,
makes the HTTPS call from the device, and returns the response over the
same WS.

This is the right tool for: marketplace login, fetching cloud-side config,
posting telemetry to a SaaS endpoint, anything where the URL is not
`location.hostname`.

## Outgoing envelope

```json
{
  "correlation-id": "UI-1735000000000-1",
  "endPoint": "https://dev.marketplace-api.seamos.io/auth/login",
  "methodSelect": "POST",
  "reqHeader": { "Content-Type": "application/json" },
  "reqBody": { "email": "agmo@agmo.farm", "password": "..." }
}
```

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `correlation-id` | string | `"UI-${Date.now()}-${counter}"` | **Required and unique.** The UI uses it to match the response back to the originating request. Anything unique per-request works; the timestamp+counter pattern guarantees uniqueness even within the same millisecond. |
| `endPoint` | string | `""` | Full HTTPS URL. The app forwards verbatim. |
| `methodSelect` | string | `"GET"` | HTTP verb. Common values: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`. |
| `reqHeader` | object | `{}` | Headers as a flat JSON object. Empty `{}` is valid — include the field even when empty so the envelope shape is stable. |
| `reqBody` | object | `{}` | Request body. The app serialises this as JSON. For `GET`/`DELETE` an empty `{}` is fine. |

The proxy does not auto-add a `Content-Type` — set it explicitly in
`reqHeader` for any request with a body.

## Incoming envelope

```json
{
  "type": "external_api_response",
  "correlation-id": "UI-1735000000000-1",
  "data": { "...upstream response body, already parsed..." }
}
```

`data` is the upstream response body **already JSON-parsed** by the app —
the UI does not need to `JSON.parse` it again.

## Correlation-id lifecycle

Cloud calls can take seconds; the user can fire several before the first
one returns. Out-of-order responses are normal. Keep a pending-map keyed
by id:

```js
const pendingReqs = new Map()  // correlation-id → { resolve, reject, timeoutHandle }
let counter = 0

function callCloud(ws, { url, method = 'GET', headers = {}, body = {} }) {
  return new Promise((resolve, reject) => {
    if (ws.readyState !== WebSocket.OPEN) {
      reject(new Error('ws not open'))
      return
    }
    counter += 1
    const cid = `UI-${Date.now()}-${counter}`
    const timeoutHandle = setTimeout(() => {
      pendingReqs.delete(cid)
      reject(new Error(`cloud request timed out: cid=${cid}`))
    }, 30_000)
    pendingReqs.set(cid, { resolve, reject, timeoutHandle })
    ws.send(JSON.stringify({
      'correlation-id': cid,
      endPoint: url,
      methodSelect: method,
      reqHeader: headers,
      reqBody: body,
    }))
  })
}

// In the WS message dispatcher (see ws-protocol.md):
function handleApiResponse(frame) {
  const cid = frame['correlation-id']
  const pending = pendingReqs.get(cid)
  if (!pending) {
    // Orphan — request was cancelled, or duplicate response. Log and drop.
    return
  }
  clearTimeout(pending.timeoutHandle)
  pendingReqs.delete(cid)
  pending.resolve(frame.data)
}
```

## Why `correlation-id` and not just request order?

The WebSocket itself preserves order, but the proxy on the app side may
finish requests out of order (one slow upstream blocks behind a faster
later one). Pairing by id is the only reliable scheme.

## Failure modes worth handling

| Symptom | Cause / fix |
|---------|------------|
| Response never arrives | Upstream hung or app-side proxy busy. The `setTimeout` reject path is required, not optional. |
| Orphan response in handler | UI cancelled but the request still fired — drop silently after logging. |
| `data` is a string, not an object | Upstream returned non-JSON. The app passes it through as-is; handle the string branch. |
| Duplicate `correlation-id` | Counter not advanced or two UIs sharing one id space. Always include `Date.now()` *and* the counter. |

## Pattern: minimal usage

```js
try {
  const userInfo = await callCloud(ws, {
    url: 'https://dev.marketplace-api.seamos.io/auth/me',
    method: 'GET',
    headers: { 'Authorization': `Bearer ${token}` },
    // body omitted — defaults to {}, harmless for GET
  })
  renderUser(userInfo)
} catch (err) {
  showError(err.message)
}
```

## How the backend dispatches the envelope (the other half)

The UI-side envelope above is only half the story — the app's C++/Java side
unwraps it, forwards through the Cloud plugin, and routes the response back.
Knowing the contract here helps you debug "why isn't my response coming back"
without reading the SDK source.

### Key rename: UI envelope → proxy envelope (project-dependent!)

This is the part where two real projects disagree. **Check the backend
service before settling on UI envelope keys.**

**Convention A — UI uses friendly aliases, app renames** (C++ reference
`cpp_deploy_test_19`):

| UI envelope        | Cloud proxy envelope |
|--------------------|----------------------|
| `endPoint`         | `externalUrl`        |
| `methodSelect`     | `method`             |
| `reqHeader`        | `header`             |
| `reqBody`          | `msg`                |
| `correlation-id`   | `correlation-id`     |

**Convention B — UI sends backend keys directly, no rename** (Java reference
`agnote-core`): UI just sends `externalUrl`, `method`, `header`, `msg`,
`correlation-id`. The service forwards verbatim. This is simpler — start
here unless you're targeting a backend that already speaks Convention A.

If you don't know which the backend uses, grep its service class for
`endPoint` (Convention A) or only `externalUrl` (Convention B). The
"why isn't my response coming back" failure mode below is almost always
"UI sent `endPoint` but backend reads `externalUrl`" or vice versa.

If the app receives an envelope without a `correlation-id`, behaviour
depends on the backend:
- C++ reference: generates `WS{epoch_ms}` / `HTTP{epoch_ms}` and uses the
  prefix to dispatch responses.
- Java reference (`agnote-core`): expects the **service** to generate a
  UUID v4 before calling `uploadData`. UI shouldn't omit it on the
  WebSocket path either — agnote's listener uses `PendingRequestRegistry`
  to demux by id, so a missing id falls into the untyped passthrough
  branch and the UI may not recognise the frame.

### Two backend dispatch patterns

The official spec (https://docs.seamos.io/docs/4/5/4) defines two ways the
app can wait for the response. The `correlation-id` **prefix** (`HTTP*` vs
`WS*`) tells the response handler which path to take:

| Pattern | UI entry point | correlation-id prefix | App-side wait | When to use |
|---------|----------------|-----------------------|---------------|-------------|
| **A. Sync HTTP proxy** | `POST /extApi` | `HTTP*` | `std::promise` + 10 s `wait_for` | Form submit, bulk fetch, UI expects synchronous return |
| **B. Async WebSocket** | `ws://.../socket` | `WS*` | None — push back via WS | Real-time streams, multiple concurrent calls, long ops |

This skill (browser-side) implements Pattern B. Pattern A is a parallel
backend route the UI hits with plain `fetch('/extApi', ...)` instead of
opening a WebSocket — useful when you want one round-trip without managing
a WS pending-map.

### Response envelope (incoming) — frame shape varies by backend

The cloud returns `{ data, correlation-id }` to the app. **The app then
re-wraps it before broadcasting**, and the wrapper differs across
projects:

| Backend reference | WS frame the UI sees |
|-------------------|----------------------|
| C++ (`cpp_deploy_test_19`) | `{"type":"external_api_response","correlation-id":"<id>","data":<body>}` |
| Java (`agnote-core`) | `{"type":"EXT-<domain>","data":<body>}` — no `correlation-id`, type carries the routing info |

UI dispatch should branch on `frame.type`:
- `"external_api_response"` → look up `frame['correlation-id']` in the
  pending-map (the snippet in the previous section).
- `"EXT-…"` → match by `type` (e.g. `"EXT-weather"`, `"EXT-fuel"`) and
  feed `frame.data` into the appropriate domain handler. There's no
  per-request id to match against — the broadcast is fan-out.

In both cases `data` is **already JSON-parsed by the app** — don't
`JSON.parse` again.

### When you suspect the backend, not the UI

Symptoms that point at the backend, not your UI code:

| Symptom | Likely backend cause |
|---------|---------------------|
| `external_api_response` never arrives, but `publish` works | Cloud channel not registered, or `CloudDownloadListener` not wired |
| Response arrives but UI's pending-map orphans it | UI's `correlation-id` doesn't match what backend sent — backend may have generated its own |
| 504 / Gateway Timeout | App used Pattern A and the upstream took >10 s; either retry or switch to Pattern B |

Backend implementation (Cloud listener registration, prefix dispatch, the
`uploadData(payload, 1)` call where `1` is the importance/priority and is
conventionally fixed) lives in `seamos-app-framework` → External API Server
Communication. Read that file when working on the app side.
