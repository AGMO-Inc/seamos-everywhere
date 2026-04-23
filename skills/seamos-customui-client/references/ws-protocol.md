# WebSocket Frame Protocol

After the WebSocket opens at `ws://<host>:<port>/socket`, four frame shapes
are in play. The UI sends one (`publish`) and receives three (`publish_ack`,
topic frames, and `external_api_response`).

All frames are JSON text. There is no length prefix or framing beyond what
the WebSocket layer provides.

## Outgoing: `publish`

Used to set the value of an FD-defined interface — buttons, toggles,
sliders, anything user-driven.

```json
{
  "action": "publish",
  "interface": "Implement.setAllSectionValveOpen",
  "value": true
}
```

| Field | Type | Notes |
|-------|------|-------|
| `action` | string | Always `"publish"` for outgoing control frames. |
| `interface` | string | The FD interface path. Same string the FSP/SDK uses (e.g. `Implement.setAllSectionValveOpen`, `Sense.getCurrentSpeed`). Browse via `seamos-plugins`. |
| `value` | depends on interface type | Boolean / number / string / array, matching the interface's declared type. |

**Always guard with readyState** — sending into a closing socket throws:

```js
function publish(ws, interfaceName, value) {
  if (ws.readyState !== WebSocket.OPEN) return false
  ws.send(JSON.stringify({ action: 'publish', interface: interfaceName, value }))
  return true
}
```

## Incoming: `publish_ack`

Server-side confirmation that a `publish` was accepted (or rejected).

```json
{
  "action": "publish_ack",
  "topic": "Implement.setAllSectionValveOpen",
  "status": "ok"
}
```

| Field | Type | Notes |
|-------|------|-------|
| `action` | string | `"publish_ack"`. |
| `topic` | string | Echo of the interface that was published to. |
| `status` | string | `"ok"` on success; otherwise an error string from the app. |

Use this for UI feedback (toast, log line, button-state confirmation). It's
not strictly required to consume it — the UI can fire-and-forget — but
showing acks helps users notice when the app side is unresponsive.

## Incoming: topic frame (sensor / state stream)

Anything the app is broadcasting on its own initiative — sensor reads,
periodic state, computed values. There is no "subscribe" handshake; the
app pushes whatever it's configured to push.

```json
{
  "topic": "Sense.boomSectionFlow",
  "payload": {
    "PL": {
      "<some-key>": { "0": [12.3, 12.5, 12.7, 12.4, 12.6, 12.5] }
    }
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `topic` | string | The interface name being broadcast. |
| `payload.PL` | object | Payload container. The inner shape varies by interface type. |

**Recognising the frame:** check `frame.topic` exists. If yes and it's not
a `publish_ack` (no `action` field), treat it as a topic frame.

**Extracting array previews** — common case is a plot-friendly numeric
array under `payload.PL.<key>['0']`:

```js
function previewArray(frame, max = 6) {
  const pl = frame?.payload?.PL
  if (!pl || typeof pl !== 'object') return ''
  const arrEntry = Object.values(pl).find(
    v => v && typeof v === 'object' && Array.isArray(v['0']),
  )
  if (!arrEntry) return ''
  return arrEntry['0']
    .slice(0, max)
    .map(v => typeof v === 'number' ? v.toFixed(2) : String(v))
    .join(', ')
}
```

For non-array payloads (scalars, structs), inspect `payload.PL` directly —
the FD-generated interface metadata documents the exact shape per topic.

## Incoming: `external_api_response`

Reply envelope for cloud-proxy requests. See `cloud-proxy.md` for the
matching outgoing envelope and full correlation-id flow.

```json
{
  "type": "external_api_response",
  "correlation-id": "UI-1735000000000-1",
  "data": { "...whatever the upstream API returned..." }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `type` | string | `"external_api_response"`. Distinguishes it from topic frames (which have `topic`, not `type`). |
| `correlation-id` | string | Echo of the id the UI sent. Match against the pending-map. |
| `data` | any | The upstream response body, already JSON-parsed by the app. |

## Dispatch skeleton

```js
ws.addEventListener('message', ev => {
  let frame
  try { frame = JSON.parse(ev.data) } catch { return }

  if (frame.type === 'external_api_response') {
    handleApiResponse(frame)         // see cloud-proxy.md
    return
  }
  if (frame.action === 'publish_ack') {
    handlePublishAck(frame)
    return
  }
  if (frame.topic) {
    handleTopic(frame)
    return
  }
  // Unknown frame — log for debugging
})
```

Order matters: `external_api_response` and `publish_ack` are both
distinguished by a unique top-level field; check those before falling
through to the generic `topic` branch.
