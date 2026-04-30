# React Patterns — hook wrappers around customui-client helpers

Patterns for wrapping the vanilla helpers defined by the
`seamos-customui-client` skill (port discovery, WebSocket frames,
REST calls, cloud-proxy) as React 18 + TypeScript hooks.

> **The communication protocol itself (why a relative URL, exact
> shape of the four WS frames, correlation-id semantics) is out of
> scope here — see `seamos-customui-client` SKILL.md.**

This file only provides **React-hook-shaped usage examples on top
of that protocol**.

---

## Hook catalog

| Hook | Responsibility | Where in customui-client |
|---|---|---|
| `useApiBase()` | Call `get_assigned_ports`, return `http://hostname:port` base URL | port-discovery |
| `useTopic(name)` | Subscribe to a WS topic, return last frame payload | ws-protocol (incoming `topic`) |
| `usePublish()` | Publish helper — `readyState === OPEN` check, failure handling | ws-protocol (outgoing `publish`) |
| `useExternalApi()` | Call external HTTPS via cloud-proxy with correlation-id | cloud-proxy |

---

## 1. `useApiBase()` — base URL

```tsx
import { useEffect, useState } from 'react'

type ApiBaseState =
  | { status: 'loading' }
  | { status: 'ready'; baseUrl: string; port: number }
  | { status: 'error'; error: Error }

export function useApiBase(): ApiBaseState {
  const [state, setState] = useState<ApiBaseState>({ status: 'loading' })

  useEffect(() => {
    let cancelled = false
    fetch('get_assigned_ports', { cache: 'no-store' })   // relative URL only
      .then(r => r.json())
      .then((ports: Record<string, string | number>) => {
        if (cancelled) return
        const raw = Object.values(ports)[0]
        const port = typeof raw === 'number' ? raw : Number.parseInt(String(raw), 10)
        if (!Number.isFinite(port)) throw new Error('bad get_assigned_ports')
        const baseUrl = `http://${location.hostname}:${port}`
        setState({ status: 'ready', baseUrl, port })
      })
      .catch((error: Error) => {
        if (!cancelled) setState({ status: 'error', error })
      })
    return () => { cancelled = true }
  }, [])

  return state
}
```

### Usage

```tsx
function CropList() {
  const api = useApiBase()
  if (api.status === 'loading') return <Skeleton />
  if (api.status === 'error') return <ErrorBanner error={api.error} />

  // api.baseUrl, api.port — app-defined REST routes are on this base
  return <CropFetcher baseUrl={api.baseUrl} />
}
```

### Notes

- **`get_assigned_ports` MUST be a relative URL.** Prepending `/`
  escapes the feature prefix and 404s. (See customui-client SKILL.md
  for why.)
- The map values are usually strings — coerce with `Number.parseInt`
  and validate with `Number.isFinite`.

---

## 2. `useTopic(name)` — WS topic subscription

```tsx
import { useEffect, useRef, useState } from 'react'

export function useTopic<T>(topicName: string): T | undefined {
  const [data, setData] = useState<T | undefined>(undefined)
  const wsRef = useRef<WebSocket | null>(null)

  useEffect(() => {
    let cancelled = false

    fetch('get_assigned_ports', { cache: 'no-store' })
      .then(r => r.json())
      .then(ports => {
        if (cancelled) return
        const raw = Object.values(ports)[0]
        const port = Number.parseInt(String(raw), 10)
        if (!Number.isFinite(port)) throw new Error('bad get_assigned_ports')

        const ws = new WebSocket(`ws://${location.hostname}:${port}/socket`)
        wsRef.current = ws

        ws.onmessage = (ev) => {
          const frame = JSON.parse(ev.data)
          // See customui-client SKILL.md → ws-protocol.md
          if (frame.type === 'topic' && frame.topic === topicName) {
            setData(frame.payload?.PL as T)
          }
        }
        ws.onopen = () => {
          // Subscribe message (exact shape: customui-client docs)
          ws.send(JSON.stringify({ type: 'subscribe', topic: topicName }))
        }
      })

    return () => {
      cancelled = true
      wsRef.current?.close()
      wsRef.current = null
    }
  }, [topicName])

  return data
}
```

### Usage

```tsx
function EngineRpm() {
  const rpm = useTopic<{ value: number }>('Engine.rpm')
  return <Display label="Engine RPM" value={rpm?.value ?? '—'} unit="rpm" />
}
```

### Notes

- **Cleanup is required.** Call `ws.close()` on unmount, or you leak
  sockets and get duplicate messages.
- `payload.PL` parsing follows the customui-client ws-protocol contract.
- The socket silently closes when the app restarts — if you need
  reconnection, add a reconnect policy here (exponential backoff
  recommended).

---

## 3. `usePublish()` — publish helper

```tsx
import { useCallback } from 'react'

type PublishFn = (interfacePath: string, payload: unknown) => void

export function usePublish(ws: WebSocket | null): PublishFn {
  return useCallback((interfacePath, payload) => {
    if (!ws) return
    if (ws.readyState !== WebSocket.OPEN) {
      console.warn('[publish] socket not open, dropping', interfacePath)
      return
    }
    const frame = {
      type: 'publish',
      interface: interfacePath,
      payload,
    }
    ws.send(JSON.stringify(frame))
  }, [ws])
}
```

### Usage

```tsx
function ToggleValve({ ws }: { ws: WebSocket | null }) {
  const publish = usePublish(ws)
  return (
    <Button
      size="xl"
      label="Open valve"
      onClick={() => publish('Implement.setAllSectionValveOpen', { open: true })}
    />
  )
}
```

### Notes

- **Always check `readyState === OPEN`.** When the app restarts the
  socket silently closes; sending into a closed socket throws.
- The `interface` field is the FD-generated interface path (e.g.
  `Implement.setAllSectionValveOpen`). The exact path comes from the
  `seamos-plugins` skill's interface synthesis result.

---

## 4. `useExternalApi()` — external HTTPS via cloud-proxy

```tsx
import { useCallback, useEffect, useRef } from 'react'

type ExternalApiCall = (req: { url: string; method: string; body?: unknown }) => Promise<unknown>

export function useExternalApi(ws: WebSocket | null): ExternalApiCall {
  const pendingRef = useRef<Map<string, (data: unknown) => void>>(new Map())

  useEffect(() => {
    if (!ws) return
    const onMessage = (ev: MessageEvent) => {
      const frame = JSON.parse(ev.data)
      if (frame.type !== 'external_api_response') return
      const cid = frame.correlationId
      const resolver = pendingRef.current.get(cid)
      if (resolver) {
        resolver(frame.payload)
        pendingRef.current.delete(cid)
      }
    }
    ws.addEventListener('message', onMessage)
    return () => ws.removeEventListener('message', onMessage)
  }, [ws])

  return useCallback((req) => {
    return new Promise((resolve) => {
      if (!ws || ws.readyState !== WebSocket.OPEN) {
        resolve({ error: 'socket not open' })
        return
      }
      const cid = crypto.randomUUID()
      pendingRef.current.set(cid, resolve)
      ws.send(JSON.stringify({
        type: 'external_api_request',
        correlationId: cid,
        ...req,
      }))
    })
  }, [ws])
}
```

### Usage

```tsx
function CloudUploadButton({ ws }: { ws: WebSocket | null }) {
  const callExternal = useExternalApi(ws)
  return (
    <Button
      size="xl"
      label="Upload to cloud"
      onClick={async () => {
        const result = await callExternal({
          url: 'https://api.example.com/upload',
          method: 'POST',
          body: { foo: 'bar' },
        })
        // ...
      }}
    />
  )
}
```

### Notes

- **Correlation-id is required.** Multiple concurrent external calls
  on the same socket will return out of order — match by cid.
- Add a per-request timeout to prevent the pending map from leaking
  (the example above is the minimum form).
- The exact frame shape (`external_api_request` /
  `external_api_response`) lives in the customui-client cloud-proxy
  section.

---

## Common recommendations

- **Create the `ws` instance once at the top and pass it down via
  context.** Spawning a new WebSocket per component creates duplicate
  messages and connection storms.
- **Every hook must clean up on unmount.**
- **Always surface error states.** Silent failures are the worst
  pattern in an operating-machinery environment.
