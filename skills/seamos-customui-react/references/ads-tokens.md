# ADS Tokens — 카테고리 + 사용 패턴 + MCP 흐름

ADS는 디자인 토큰을 **CSS Variables (`--ads-*`)** 형태로 제공한다.
**실제 토큰 이름·값은 MCP의 `get_component`/`list_components`에서
가져온다 — 본 문서는 카테고리·구조·사용 패턴만 안내한다.**

---

## 토큰 카테고리

| 카테고리 | 변수 패턴 | 용도 |
|---|---|---|
| **color** | `var(--ads-color-*)` | 텍스트·배경·border, 상태(success/warning/danger), brand |
| **spacing** | `var(--ads-spacing-*)` | margin·padding·gap, layout grid |
| **typography** | `var(--ads-font-*)` / `var(--ads-text-*)` | font-family, size, weight, line-height |
| **shadow** | `var(--ads-shadow-*)` | elevation, focus ring |
| **radius** | `var(--ads-radius-*)` | border-radius |
| **motion** | `var(--ads-motion-*)` | duration, easing |

각 카테고리 안의 정확한 토큰 이름(예: `--ads-color-text-primary`,
`--ads-spacing-md`)은 ADS 버전마다 다를 수 있으므로 **반드시 MCP에서
조회**한다.

---

## 사용 패턴

### CSS-in-JS / styled

```tsx
import { styled } from 'styled-components'  // 또는 ADS 권장 방식

const Card = styled.div`
  background: var(--ads-color-surface);
  color: var(--ads-color-text-primary);
  padding: var(--ads-spacing-md);
  border-radius: var(--ads-radius-lg);
  box-shadow: var(--ads-shadow-sm);
`
```

### 인라인 style — 토큰만, 직접 값 금지

```tsx
// ❌ 직접 값
<div style={{ color: '#1A1A1A', padding: 16 }} />

// ✅ 토큰 변수
<div style={{
  color: 'var(--ads-color-text-primary)',
  padding: 'var(--ads-spacing-md)',
}} />
```

### ADS 컴포넌트의 props로 전달

ADS 컴포넌트는 대부분 토큰을 내부적으로 사용한다. 사용자는 props
이름만 알면 된다.

```tsx
// 컴포넌트가 토큰을 알아서 적용
<Button variant="primary" size="lg">저장</Button>
<Stack gap="md">...</Stack>
```

각 컴포넌트가 **어떤 props로 어떤 토큰을 받는지**는 `get_component`로
확인.

---

## MCP 호출 흐름

```
[1] 모르는 컴포넌트 — 이름이 무엇인지 모름
    → search_components(query)
       예: search_components("토글 입력")
       → 후보 목록과 짧은 설명 반환

[2] 사용 직전 — props·예제·CSS 변수 확인
    → get_component(name)
       예: get_component("Button")
       → props 시그니처, 사용 예제, 의존하는 CSS 변수 반환

[3] 권장 패턴 그대로 사용
    → MCP가 알려주는 권장 사용 예제를 따름
       (Flat이든 Compound든 컴포넌트별로 권장 패턴이 다름)
```

### 안 되는 흐름

```
✗ 기억으로 props 적기 (sloppy)
✗ 다른 디자인 시스템의 props 추측해서 적기 (예: Material UI 추측)
✗ list_components 한 번 호출하고 그 결과를 캐싱해 며칠 동안 그대로
   사용 (ADS 버전 업그레이드 후 깨짐)
```

---

## 메타 가이드

- **추측 금지.** ADS의 진실의 출처는 MCP다. 사용 직전 호출.
- **토큰 값 하드코딩 금지.** 색상·spacing·typography를 직접 적으면
  테마 변경/다크 모드/대비 모드 전환이 무력화된다.
- **카테고리 외부 토큰 만들지 말 것.** 새 토큰이 필요하면 ADS 레포에
  이슈/PR.
- **var(--ads-*)가 아닌 변수 이름 패턴**이 필요하다고 느낀다면 ADS가
  그 카테고리를 아직 정의하지 않은 것 — ADS에 보고.

---

## 토큰 조회 빠른 참조

| 상황 | 호출 |
|---|---|
| "어떤 컴포넌트들이 있는지 보고 싶다" | `list_components` |
| "버튼 비슷한 게 있나?" | `search_components("button")` |
| "Button 어떻게 쓰는지 정확히 알고 싶다" | `get_component("Button")` |
| "토글이 있나? 이름이 뭐지?" | `search_components("toggle switch")` |
| "이 컴포넌트가 쓰는 CSS 변수는?" | `get_component(name)` 응답의 변수 섹션 |
