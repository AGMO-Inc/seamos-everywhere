# React Patterns — customui-client helper의 hook 래핑

`seamos-customui-client` 스킬이 정의하는 vanilla helper(포트 디스커버리,
WebSocket frame, REST 호출, cloud-proxy)를 React 18 + TypeScript에서
hook으로 감싸 쓰는 패턴.

> **통신 프로토콜 자체(왜 relative URL인지, 4-frame WS의 정확한
> shape, correlation-id 동작 등)는 본 문서 범위 밖이다 —
> `seamos-customui-client` SKILL.md를 참조.**

본 문서는 **그 프로토콜 위에서 동작하는 React hook 형태의 사용 예시**
만 제공한다.

---

## Hook 카탈로그

| Hook | 책임 | customui-client의 어디 |
|---|---|---|
| `useApiBase()` | `get_assigned_ports` 호출 후 `http://hostname:port` base URL 반환 | port-discovery |
| `useTopic(name)` | WS 토픽 구독, 마지막 frame 페이로드 반환 | ws-protocol (incoming `topic`) |
| `usePublish()` | publish 헬퍼 — `readyState === OPEN` 체크 + 실패 처리 | ws-protocol (outgoing `publish`) |
| `useExternalApi()` | cloud-proxy로 외부 HTTPS 호출, correlation-id 관리 | cloud-proxy |

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
    fetch('get_assigned_ports', { cache: 'no-store' })   // 반드시 relative URL
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

### 사용

```tsx
function CropList() {
  const api = useApiBase()
  if (api.status === 'loading') return <Skeleton />
  if (api.status === 'error') return <ErrorBanner error={api.error} />

  // api.baseUrl, api.port 사용 — 앱 등록 REST 라우트는 이 base 위
  return <CropFetcher baseUrl={api.baseUrl} />
}
```

### 주의

- **`get_assigned_ports`는 반드시 relative URL.** 앞에 `/`를 붙이면
  feature prefix를 벗어나 404. (자세한 이유: customui-client SKILL.md)
- 반환값은 보통 string이므로 `Number.parseInt` + `Number.isFinite` 검증.

---

## 2. `useTopic(name)` — WS 토픽 구독

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
          // customui-client SKILL.md ws-protocol.md 참고
          if (frame.type === 'topic' && frame.topic === topicName) {
            setData(frame.payload?.PL as T)
          }
        }
        ws.onopen = () => {
          // 구독 메시지 (정확한 shape는 customui-client 문서)
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

### 사용

```tsx
function EngineRpm() {
  const rpm = useTopic<{ value: number }>('Engine.rpm')
  return <Display label="엔진 회전수" value={rpm?.value ?? '—'} unit="rpm" />
}
```

### 주의

- **cleanup 필수**: 언마운트 시 `ws.close()`. 안 그러면 누수·중복 메시지.
- `payload.PL` 파싱은 customui-client의 ws-protocol 규약을 그대로 따른다.
- 앱이 재시작되면 ws가 silent close 되므로, 재연결 정책이 필요하면
  여기에 reconnect 로직 추가 (지수 백오프 권장).

---

## 3. `usePublish()` — publish 헬퍼

```tsx
import { useCallback, useRef } from 'react'

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

### 사용

```tsx
function ToggleValve({ ws }: { ws: WebSocket | null }) {
  const publish = usePublish(ws)
  return (
    <Button
      size="xl"
      label="밸브 열기"
      onClick={() => publish('Implement.setAllSectionValveOpen', { open: true })}
    />
  )
}
```

### 주의

- **`readyState === OPEN` 체크 필수.** 앱이 재시작되면 socket이
  silent close되고, closed socket에 send하면 throw.
- `interface` 필드는 FD가 생성하는 interface 경로 (예:
  `Implement.setAllSectionValveOpen`). 정확한 값은 `seamos-plugins`
  스킬의 interface 합성 결과를 참조.

---

## 4. `useExternalApi()` — cloud-proxy로 외부 HTTPS

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

### 사용

```tsx
function CloudUploadButton({ ws }: { ws: WebSocket | null }) {
  const callExternal = useExternalApi(ws)
  return (
    <Button
      size="xl"
      label="구름에 업로드"
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

### 주의

- **correlation-id 필수.** 같은 socket 위에서 여러 외부 호출이 돌면
  응답이 out-of-order로 도착한다. cid로 매칭.
- pending map 누수 방지를 위해 timeout도 함께 두는 것을 권장 (예제는
  최소 형태).
- 정확한 frame shape (`external_api_request` / `external_api_response`)는
  customui-client SKILL.md의 cloud-proxy 섹션 참조.

---

## 공통 권장 사항

- **상위에서 ws 인스턴스를 한 번만 만들고 context로 내려라.** 컴포넌트
  마다 새 ws를 만들면 메시지 중복·연결 폭증.
- **모든 hook이 unmount 시 cleanup**하는지 확인.
- **에러 상태를 항상 노출**하라. silent failure는 운영 환경에서 가장
  나쁜 패턴.
