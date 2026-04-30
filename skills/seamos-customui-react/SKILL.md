---
name: seamos-customui-react
description: >
  Standard UI skill for building SeamOS CustomUI with React 18 +
  TypeScript + @seamos/ads (Agmo Design System). Provides 10 user
  experience principles (Core 7 + Operational Context 3) tailored for
  the operating-machinery context (vibration, direct sunlight, gloved
  hands, one-handed operation, multi-hour continuous work) and an
  ADS component / token usage guide that delegates to the ADS MCP
  server. Use it whenever the user is building, modifying, or making
  decisions about a SeamOS CustomUI screen — layout, information
  hierarchy, component selection, touch gestures, accessibility.
  Triggers (Korean + English): "CustomUI 만들어", "CustomUI에 버튼
  추가", "토픽 데이터 화면에 보여줘", "모니터링 화면", "컨트롤 버튼",
  "React로 SeamOS UI", "디자인 시스템 컴포넌트", "ADS 버튼/토글/입력",
  "@seamos/ads 사용", "ADS 토큰 색상", "build CustomUI screen",
  "add ADS button", "show topic data on screen", "use design system
  component", "react SeamOS UI", "ads tokens for color/spacing".
  Out of scope (delegate elsewhere): communication protocol — port
  discovery, WebSocket frame shapes, REST base URL, cloud-proxy
  correlation-id — handled by `seamos-customui-client`. Non-SeamOS
  web apps (marketplace dashboard, internal tools) and backend
  (Java / C++) code are not covered.
---

# SeamOS CustomUI React

Skill for writing SeamOS app CustomUI as **React 18 + TypeScript +
`@seamos/ads`**. The skill provides two things.

1. **10 user experience principles** — strong rules tailored to the
   operating-machinery environment. Use them when deciding screen
   layout, information hierarchy, touch gestures, and accessibility.
2. **ADS usage guide** — token categories that `@seamos/ads` ships
   and the ADS MCP server (`https://mcp.ads.seamos.io`) call flow.
   **Component props, examples, and actual token values are owned by
   the MCP** — this skill only steers you toward calling the MCP
   instead of guessing.

Communication (port discovery, WebSocket frames, REST routes,
cloud-proxy) is **out of scope** and lives in `seamos-customui-client`.
This skill provides a thin layer on top: hook-shaped wrappers around
those vanilla helpers, kept in `references/react-patterns.md`.

## Why

CustomUI is not a generic web app. It is **a screen on a moving
machine, viewed by an operator whose other hand is on a control lever
the whole time**. Vibration, direct sunlight, gloves, the cumulative
fatigue of multi-hour continuous work — every one of these breaks the
default assumptions of normal web UX. The principles below are
back-derived from those constraints.

ADS exists as the in-house standard component library, but vanilla
HTML/JS authorship has been creeping back, threatening consistency,
accessibility, and theme-change cost. **CustomUI = React + ADS** is
the standard this skill declares.

## Operating environment (premise of every principle)

- Vibrating, moving machine surface
- Outdoor direct sunlight ↔ dim conditions, both extremes
- Gloved hands (precision touch is unreliable)
- One-handed operation (the other hand is always on a wheel / lever / control)
- Multi-hour to multi-day continuous use

## User experience principles

Detailed rationale + code examples in `references/ux-principles.md`.
Anti-pattern catalog in `references/ux-anti-patterns.md`.

### Core 7 — common to any UI on a moving machine

**1. Easy & Safe — no two-handed UI, everything reachable with one hand**
- ✅ Single large tap targets (minimum 64dp, gloved-hand baseline)
- ❌ Multi-touch gestures, two-hand assumptions, motion that pulls the eye
  (auto-scrolling text, bursty transitions)

**2. Glanceability + immediate response — 1–2 sec read, 0.25 sec feedback**
- ✅ High contrast, large type, meaning conveyed by shape / position
  / icon as well as color
- ❌ Light grey for disabled state (invisible in sunlight), color-only
  status, slow input feedback (causes duplicate taps)

**3. Consistency — follow ADS / SeamOS UI as-is**
- ✅ Use ADS components, icons, colors, spacing as shipped
- ❌ Wrap an ADS component to override its color / spacing, "this one
  screen has a slightly different layout"

**4. Simplicity in content — operator language, only what is needed**
- ✅ Domain-natural terms used in the field, only information directly
  tied to the current task, runnable with no manual
- ❌ Raw signal names / CAN abbreviations / internal codes,
  monitoring screen mixed with statistics and logs

**5. One thing per screen — single goal**
- ✅ Monitoring / settings / calibration on separate screens, mode
  (work / drive / standby) on separate screens
- ❌ Mode switcher, monitoring, and settings stacked on the same
  screen

**6. Easy to answer (3 sec) — minimize input during work**
- ✅ Plain OK / cancel confirms, questions answerable in 3 seconds
- ❌ Free-text input (keyboard unusable while operating), ambiguous
  prompts, more than 3 options at once

**7. Tap & scroll (one hand) — no precision gestures**
- ✅ +/- buttons, large dials, vertical scrolling
- ❌ Horizontal swipe, fine-grained sliders, drag-and-drop

### Operational Context 3 — moving-machine specific

**8. Status persistence — core state visible everywhere**
- ✅ Engine state, fuel, temperature / pressure, implement state,
  auto-mode ON/OFF in a persistent status bar on every screen
- ❌ Status bar disappears when entering settings or full-screen modes

**9. Safety override — alerts above all UI**
- ✅ Full-screen modal that blocks every other UI, visual + audio +
  haptic, explicit acknowledgement required
- ❌ Toast for safety alerts, auto-dismiss, dismissible banners

**10. Resumable — interruptions are frequent**
- ✅ Persist progress / mode / partial input across reloads, return to
  last screen on re-entry
- ❌ Full reset on refresh, partial form lost on interruption,
  forced restart from step 1

## ADS usage guide (informational)

`@seamos/ads` is the in-house React 18 + TypeScript + CSS Variables
design system. **The authoritative source for component props, usage
examples, and CSS variable values is the ADS MCP server** — this skill
only describes how to call it.

### MCP tools

| Tool | Use |
|---|---|
| `list_components` | Browse the full component list — what exists at all |
| `search_components(query)` | Keyword search — "toggle-like component", "input field" |
| `get_component(name)` | Specific component's props, examples, CSS variables it depends on |

### Meta rules

- **Do not write props from memory.** Call `get_component(name)` right
  before using a component.
- **Don't guess component names — search first.** If you're unsure of
  the canonical name, run `search_components` rather than importing a
  guessed identifier.
- ADS's stronger usage rules (no detachment, tokens-only, accessibility
  by default, etc.) are owned by ADS's own documentation. This skill
  only points to the MCP and explains the categories.

### Token categories

ADS exposes design tokens as CSS Variables (`--ads-*`). **Actual names
and values come from the MCP.** The categories are:

| Category | Variable pattern | Use |
|---|---|---|
| color | `var(--ads-color-*)` | text · background · border · status (success/warning/danger) · brand |
| spacing | `var(--ads-spacing-*)` | margin · padding · gap |
| typography | `var(--ads-font-*)`, `var(--ads-text-*)` | font size · weight · line height |
| shadow | `var(--ads-shadow-*)` | elevation · focus ring |
| radius | `var(--ads-radius-*)` | border-radius |
| motion | `var(--ads-motion-*)` | duration · easing |

Detailed patterns in `references/ads-tokens.md`.

## Communication layer — `seamos-customui-client`

The CustomUI's **data communication** (port discovery, WebSocket frame
protocol, REST base URL, cloud-proxy) is out of scope here and is
owned by another skill.

- Protocol & hard rules: `seamos-customui-client` SKILL.md
- React-hook wrappers around the same helpers:
  `references/react-patterns.md` (this skill)

## Workflow — when this skill is triggered

```
User intent (e.g. "add a button", "show topic data on screen")
    ↓
[1] Apply UX principles
    - What kind of screen is this? (monitoring / settings / alert)
    - Single goal? Status persistence + safety override applicable?
    - Used while operating? → large targets, no free text, no auto-scroll
    ↓
[2] Query ADS via MCP
    - Unknown component → search_components(query)
    - Right before use → get_component(name) for props / examples / variables
    - Follow the recommended pattern as returned (Flat vs Compound
      varies per component — never enforced by this skill)
    ↓
[3] If communication is needed, use customui-client hooks
    - useApiBase / useTopic / usePublish / useExternalApi
    - Communication protocol itself is owned by the customui-client skill
    ↓
[4] Final pass against UX principles + anti-patterns
    - Cross-check `references/ux-anti-patterns.md`
    - Verify no hardcoded color / spacing values
    ↓
Output code
```

## Hard rules

- **Never guess ADS component props.** Call `get_component`.
- **Never hardcode token values.** Use `var(--ads-*)` CSS Variables for
  color, spacing, typography.
- **No free-text input.** Keyboards are unusable during operation.
- **No horizontal swipe or precision drag.** Vibration causes false
  positives.
- **No two-handed UI.** The other hand is always on a control.

## Cross-references

- Communication protocol (port, WS frame, REST base URL, cloud-proxy):
  `seamos-customui-client`
- Backend (Java / C++ REST · WebSocket server, DB, lifecycle):
  `seamos-app-framework`
- Design system itself: ADS repo `https://github.com/AGMO-Inc/ADS`
