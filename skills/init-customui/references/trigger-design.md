# Trigger Design — `seamos-everywhere:init-customui`

`init-customui` 의 라우팅 정확도를 위한 트리거 설계 분석. 가장 큰 충돌 후보는 sibling skill `seamos-customui-ux` (디자인 / 컴포넌트 의도) 와 `seamos-customui-client` (런타임 / 통신 의도) 다. 본 스킬은 **scaffold / init / 디렉터리 생성** 의도에 한해 hit 하도록 트리거를 좁힌다.

## Positive examples

다음 utterances 는 반드시 `seamos-everywhere:init-customui` 로 라우팅되어야 한다.

- "이 프로젝트 customui 폴더 만들어줘"
- "react UI 시작하자"
- "vanilla 로 customui 만들어"
- "customui-src 클론해줘"
- "scaffold customui directory"
- "switch this app to react ui"
- "ui template 가져와"
- "customui 모드 react 로 바꿔줘"
- "init customui for this app"

## Negative examples

다음 utterances 는 절대 `seamos-everywhere:init-customui` 로 라우팅되어선 안 된다.

- "CustomUI 화면 설계해줘" → `seamos-customui-ux` (design intent)
- "버튼 컴포넌트 어떻게 만들어?" → `seamos-customui-ux` (component / 디자인)
- "WebSocket 프레임이 안 와" → `seamos-customui-client` (runtime / communication)
- "포트 어떻게 잡아?" → `seamos-customui-client` (port discovery)
- "REST API endpoint 추가" → `seamos-customui-client` 또는 `seamos-app-framework`
- "ADS Foundation 써야 해?" → `seamos-customui-ux`

## Collision analysis

**vs `seamos-customui-ux`** — `seamos-customui-ux` 는 **design** intent 를 다룬다: 어느 컴포넌트를 쓸지, 레이아웃 / UX 원칙 / ADS Foundation 준수 등 "화면을 어떻게 그릴지" 질문이 들어온다. `init-customui` 는 그 화면을 그릴 **공간**(디렉터리 / 템플릿 / 빌드 출력 경로)을 마련하는 **scaffold / init** intent. "CustomUI 만들어" 가 화면 디자인 의미면 ux, 디렉터리 / customui-src 의미면 init-customui — 발화 안의 명사("폴더", "directory", "template", "src", "스캐폴드")가 결정 신호.

**vs `seamos-customui-client`** — `seamos-customui-client` 는 **runtime / communication** intent 를 다룬다: 동적 포트 할당, WebSocket 4-frame 프로토콜, REST 호출, cloud-proxy correlation-id 등 "이미 띄운 UI 가 디바이스와 어떻게 말할지" 질문. `init-customui` 는 UI 코드가 존재하기도 전에 디렉터리와 템플릿을 깔아주는 단계. "fetch 404", "WS 안 옴" 같은 런타임 증상은 항상 client 로, "customui 폴더 / 모드 / 클론 / 스캐폴드" 는 init-customui 로.

요약:
- `init-customui` = **scaffold / init / setup** intent (filesystem, directory, template clone, mode switch).
- `seamos-customui-ux` = **design** intent (component, layout, UX 원칙, ADS Foundation).
- `seamos-customui-client` = **runtime / communication** intent (port discovery, WebSocket frames, REST, cloud-proxy).

## Routing logic

orchestrator 가 사용하는 신호:

- **Intent verbs (init-customui hit)** : `scaffold`, `init`, `setup`, `clone`, `template`, `만들어`, `생성`, `스캐폴드`, `초기화`, `모드`, `switch`, `갈아엎`, `전환`.
- **Object words (init-customui hit)** : `customui` 또는 `ui` + 위 intent verb 1+ → init-customui.
- **Object + design signal** : 동일 object + `design`, `원칙`, `컴포넌트`, `principle`, `레이아웃`, `layout`, `ADS` → `seamos-customui-ux`.
- **Object + runtime signal** : 동일 object + `WebSocket`, `port`, `fetch`, `REST`, `실시간`, `프레임`, `frame`, `proxy`, `404` → `seamos-customui-client`.
- **Negative anchors (init-customui 차단)** : `안 떠`, `안 와`, `404`, `포트`, `frame`, `버튼`, `컴포넌트`, `principle`, `원칙` 단독.

라우팅 휴리스틱: `(customui|ui object) AND (scaffold|init|setup|clone|template|만들어|생성|스캐폴드|초기화|모드|switch intent verb)` → hit. design / runtime 신호가 동시 등장하면 더 강한 신호 (object + design verb / runtime verb) 가 우선.

## Test prompts

skill-creator 가 트리거 정확도를 검증할 때 쓸 수 있는 입력 / 기대 라우팅 페어.

1. `"이 앱 customui 폴더 처음 만들어줘"` — Expected: HIT (`init-customui`).
2. `"react UI 로 customui-src 스캐폴드 해줘"` — Expected: HIT (`init-customui`).
3. `"CustomUI 모니터링 화면 어떻게 디자인해?"` — Expected: MISS (route to `seamos-customui-ux`).
4. `"customui WebSocket frame 이 안 옴"` — Expected: MISS (route to `seamos-customui-client`).
5. `"vanilla 에서 react 로 모드 갈아엎어 줘"` — Expected: HIT (`init-customui`).
6. `"버튼 컴포넌트 ADS 어디 거 써?"` — Expected: MISS (route to `seamos-customui-ux`).
7. `"clone the ui template into this project"` — Expected: HIT (`init-customui`).
