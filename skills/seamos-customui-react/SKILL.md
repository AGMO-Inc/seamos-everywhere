---
name: seamos-customui-react
description: >
  SeamOS CustomUI를 React + @seamos/ads (Agmo Design System)로 작성하는
  표준 UI 스킬. 운영 중인 기계 위에서 동작하는 화면이라는 특수 환경(진동·
  흔들림, 야외 직사광·저조도, 장갑 착용, 한 손 조작, 수~수십 시간 연속
  작업)에 맞춘 사용자 경험 원칙(Core 7 + Operational Context 3)과 ADS
  컴포넌트·토큰 사용 안내(MCP 기반)를 제공한다. 화면 구성·정보 우선순위·
  컴포넌트 선택·터치 제스처·접근성 결정에 즉시 사용한다. 사용자가 자유
  텍스트로 요청해도 본 스킬을 트리거: "CustomUI 만들어", "CustomUI에
  버튼 추가", "토픽 데이터 화면에 보여줘", "모니터링 화면", "컨트롤 버튼",
  "React로 SeamOS UI", "디자인 시스템 컴포넌트", "ADS 버튼/토글/입력",
  "@seamos/ads 사용", "ADS 토큰 색상", "build CustomUI screen",
  "add ADS button", "show topic data on screen", "use design system
  component", "react SeamOS UI", "ads tokens for color/spacing".
  통신 프로토콜(포트 디스커버리, WebSocket frame 구조, REST 호출 base
  URL, cloud-proxy correlation-id)은 본 스킬 범위 밖 — `seamos-customui-client`
  스킬로 위임한다. SeamOS 외부 웹앱(마켓플레이스 대시보드 등)이나
  백엔드(Java/C++) 코드는 다루지 않는다.
---

# SeamOS CustomUI React

SeamOS 앱의 CustomUI를 **React 18 + TypeScript + `@seamos/ads`** 표준으로
짜기 위한 스킬. 본 스킬은 두 가지를 제공한다.

1. **사용자 경험 원칙 10개** — 운영 중 기계 위에서 동작하는 화면이라는
   특수 환경에 맞춘 강한 규약. 화면 구성·정보 우선순위·터치 제스처·
   접근성 결정에 사용.
2. **ADS 사용 안내** — `@seamos/ads`가 제공하는 토큰 카테고리와 ADS
   MCP(`https://mcp.ads.seamos.io`) 호출 흐름. **컴포넌트 props·예제·
   실제 토큰 값은 MCP가 진실의 출처**이며, 본 스킬은 추측 없이 MCP를
   쓰도록 유도한다.

통신(포트 디스커버리, WebSocket frame, REST, cloud-proxy)은 본 스킬
범위 밖이며 `seamos-customui-client`가 책임진다. 본 스킬은 그 통신
helper를 React hook으로 감싸 쓰는 패턴을 `references/react-patterns.md`에
별도로 제공한다.

## Why

CustomUI는 일반 웹앱이 아니다. **운영 중인 기계 위에서 사용자가 다른
한 손으로 조작기를 잡은 채 보는 화면**이다. 진동, 흔들림, 직사광, 장갑,
연속 작업의 누적 피로 — 이 모든 제약이 일반 웹 UX의 default 가정을
무너뜨린다. 이 스킬의 원칙은 그 제약에서 역산한 결과다.

또한 ADS가 사내 표준 컴포넌트 라이브러리로 존재함에도, vanilla
HTML/JS로 직접 짜는 사례가 늘어 일관성·접근성·테마 변경 비용이 깨질
위험이 있다. **CustomUI = React + ADS = 표준**임을 본 스킬이 선언한다.

## 사용 환경 (모든 원칙의 전제)

- 진동·흔들림이 있는 운영 중 기계
- 야외 직사광 ↔ 저조도 양극단
- 장갑 착용 (정밀 터치 어려움)
- 한 손 조작 (다른 손은 항상 핸들·레버·조작기)
- 수~수십 시간 연속 작업

## 사용자 경험 원칙

상세 + 코드 예시는 `references/ux-principles.md`. 안티 패턴 카탈로그는
`references/ux-anti-patterns.md`.

### Core 7 — 운영 중 기계 UI 공통

**1. Easy & Safe — 양손 UI 금지, 한 손으로 모두 가능**
- ✅ 큰 단일 탭 타겟 (장갑 기준 최소 64dp)
- ❌ 멀티 터치 제스처, 양손 가정 UI, 시선을 묶는 애니메이션·자동 스크롤

**2. Glanceability + 즉시 응답 — 시선 1~2초, 입력 응답 0.25초**
- ✅ 고대비, 큰 글자, 색에 더해 형태·위치로도 구분
- ❌ 옅은 색만으로 구분, 작은 글자, 응답 지연 (= 사용자 중복 입력)

**3. Consistency — ADS·SeamOS UI 표준 그대로**
- ✅ ADS가 제공하는 아이콘·색·spacing 그대로
- ❌ 임의 색상·아이콘 변형, 한 화면만의 special case 패턴

**4. Simplicity in Content — 사용자 언어, 꼭 필요한 것만**
- ✅ 작업 도메인의 자연어, 현재 흐름 직결 정보만, 매뉴얼 없이 시작
- ❌ 시그널 이름·기술 약어 그대로 노출, 통계·로그를 모니터링 화면에 섞기

**5. One Thing Per Screen — 한 화면 한 목표**
- ✅ 작업 모니터링·설정·캘리브레이션 화면 분리, 모드별 화면 분리
- ❌ 한 화면에서 모드 전환 + 모니터링 + 설정을 다 하기

**6. Easy to Answer (3초) — 작업 중 입력 최소화**
- ✅ OK/취소 같은 단순 confirm, 3초 안에 답 가능한 질문
- ❌ 자유 텍스트 입력, 모호한 질문, 다중 선택지 + 긴 설명

**7. Tap & Scroll (한 손) — 정밀 제스처 금지**
- ✅ +/- 버튼·대형 다이얼, 세로 스크롤
- ❌ 가로 스와이프, 작은 슬라이더, 정밀 드래그

### Operational Context 3 — 운영 환경 특화

**8. Status Persistence — 핵심 상태는 어디서나**
- ✅ 동작/연료/온도·압력/작업기 상태/자동 모드 ON·OFF는 persistent status bar
- ❌ 다른 화면 진입 시 핵심 상태가 사라지는 구조

**9. Safety Override — 안전 알림은 모든 UI 위로**
- ✅ 풀스크린 모달 + 시각/음성/햅틱 3중, 명시적 acknowledge 필요
- ❌ Toast로 안전 알림, 자동 사라짐, 무시 가능한 배너

**10. Resumable — 중단·재개 잦음**
- ✅ 마지막 상태 기억 후 복귀 — 진행률·모드·미완료 입력 보존
- ❌ "처음부터 다시" 강제, 새로고침 시 전체 초기화

## ADS 사용 안내 (정보)

`@seamos/ads`는 React 18 + TypeScript + CSS Variables 기반의 사내
디자인 시스템. **실제 컴포넌트 props·사용 예제·CSS 변수 값은 ADS MCP가
진실의 출처**이며, 본 스킬은 그것을 어떻게 호출할지만 안내한다.

### MCP 도구

| 도구 | 용도 |
|---|---|
| `list_components` | 전체 컴포넌트 목록 — 어떤 컴포넌트가 있는지 조회 |
| `search_components(query)` | 키워드 검색 — "토글 비슷한 것", "입력 필드" 등 |
| `get_component(name)` | 특정 컴포넌트의 props·예제·사용하는 CSS 변수 |

### 메타 가이드

- **추측으로 props 작성 금지** — 사용 직전 `get_component(name)` 호출
- **모르는 컴포넌트는 `search_components`부터** — 이름을 추측해 직접
  import하지 말 것
- ADS의 **강한 사용 규약**(Detachment 금지·토큰만 사용·접근성 default 등)
  은 ADS 자체 문서가 책임지는 영역이며, 본 스킬은 정보 안내만 한다

### 토큰 카테고리

ADS는 디자인 토큰을 CSS Variables (`--ads-*`) 형태로 제공한다. 실제
이름·값은 MCP에서 가져온다. 카테고리는 다음과 같다.

| 카테고리 | 변수 패턴 | 용도 |
|---|---|---|
| color | `var(--ads-color-*)` | 텍스트·배경·border·상태(success/warning/danger) 등 |
| spacing | `var(--ads-spacing-*)` | margin·padding·gap |
| typography | `var(--ads-font-*)`, `var(--ads-text-*)` | 폰트 크기·굵기·라인 높이 |
| shadow | `var(--ads-shadow-*)` | elevation, focus ring |
| radius | `var(--ads-radius-*)` | border-radius |
| motion | `var(--ads-motion-*)` | duration, easing |

상세 + 사용 패턴은 `references/ads-tokens.md`.

## 통신 layer — `seamos-customui-client`

CustomUI의 **데이터 통신**(포트 디스커버리, WebSocket frame, REST,
cloud-proxy)은 본 스킬 범위 밖이다. 별도 스킬에서 책임진다.

- 통신 프로토콜·hard rule: `seamos-customui-client` SKILL.md
- 그 helper들을 React hook으로 감싸 쓰는 패턴: `references/react-patterns.md`
  (본 스킬 안의 hook 예시)

## Workflow — 트리거 시 흐름

```
사용자 의도 (예: "버튼 추가", "토픽 데이터 화면에 보여줘")
    ↓
[1] 사용자 경험 원칙 체크
    - 어떤 화면인가? (모니터링 / 설정 / 알림)
    - 한 화면 한 목표? Status Persistence·Safety Override 적용?
    - 작업 중 사용? → 큰 타겟·자유 텍스트 금지·자동 스크롤 금지
    ↓
[2] ADS MCP 조회
    - 모르는 컴포넌트 → search_components(query)
    - 사용 직전 → get_component(name)으로 props·예제·변수 확인
    - 권장 사용 패턴 그대로 따른다 (Flat/Compound는 컴포넌트별 상이)
    ↓
[3] 통신 필요 시 customui-client hook
    - useApiBase / useTopic / usePublish / useExternalApi
    - 통신 프로토콜 자체는 customui-client 스킬 참조
    ↓
[4] 사용자 경험 원칙 위배 여부 최종 체크
    - 안티 패턴 카탈로그(`references/ux-anti-patterns.md`)와 대조
    - 토큰 하드코딩 여부 확인
    ↓
코드 출력
```

## Hard rules

- **추측으로 ADS 컴포넌트 props 작성 금지.** `get_component`로 확인.
- **토큰 값 하드코딩 금지.** 색상·spacing·typography는 `var(--ads-*)`
  CSS Variable로만.
- **자유 텍스트 입력 금지.** 운영 중 키보드 사용 불가.
- **가로 스와이프·정밀 드래그 금지.** 진동에서 오발생.
- **양손 UI 금지.** 다른 한 손은 항상 조작기 위에 있다.

## Cross-references

- 통신 프로토콜 (포트, WS frame, REST base URL, cloud-proxy):
  `seamos-customui-client`
- 백엔드 (Java/C++ REST·WebSocket 서버, DB, lifecycle):
  `seamos-app-framework`
- 디자인 시스템 자체: ADS 레포 `https://github.com/AGMO-Inc/ADS`
