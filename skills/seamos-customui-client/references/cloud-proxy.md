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
