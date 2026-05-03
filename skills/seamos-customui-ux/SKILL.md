---
name: seamos-customui-ux
description: >
  User-experience principles for SeamOS CustomUI. The screen runs on
  an operating machine — vibration, direct sunlight, gloved hands,
  one-handed operation, multi-hour continuous work — so default web
  UX assumptions break. This skill declares two things every CustomUI
  must follow: (1) **Foundation rule** — build with the in-house
  Agmo Design System (`@seamos/ads`); do not reinvent components,
  do not fork or detach. (2) **10 UX principles** — Core 7 (Easy &
  Safe / Glanceability + immediate response / Consistency /
  Simplicity in Content / One Thing Per Screen / Easy to Answer 3 sec
  / Tap & Scroll) + Operational Context 3 (Status Persistence /
  Safety Override / Resumable). Use this skill whenever the user is
  designing or reviewing a CustomUI screen — layout, information
  hierarchy, component selection, touch interaction, accessibility,
  alerting. Triggers (Korean + English): "CustomUI 만들어",
  "CustomUI 화면 설계", "모니터링 화면", "컨트롤 버튼", "토픽 표시",
  "UI 원칙", "UX 원칙", "ADS 써야 해?", "디자인 시스템",
  "@seamos/ads", "CustomUI 검토", "build CustomUI screen",
  "design SeamOS UI", "UI principles", "UX guideline", "use design
  system", "ADS components", "review CustomUI". Out of scope
  (delegate elsewhere): how to call the ADS MCP, exact component
  props, token variable names — owned by the ADS MCP / ADS docs;
  communication protocol (port discovery, WebSocket frames, REST,
  cloud-proxy) — owned by `seamos-customui-client`; backend code —
  owned by `seamos-app-framework`.
---

# SeamOS CustomUI UX

User-experience principles every SeamOS CustomUI must follow. The
operating environment of a SeamOS app is **a screen on a moving
machine, viewed by an operator whose other hand is on a control
lever**. Vibration, direct sunlight, gloves, the cumulative fatigue
of multi-hour continuous work — every one of these breaks the
default assumptions of normal web UX.

This skill declares **what every CustomUI must follow**, not how to
implement it. How-to (ADS MCP calls, component props, token names,
React hooks) is intentionally out of scope and delegated to the ADS
MCP / `seamos-customui-client`.

## Operating environment (premise of every rule below)

- Vibrating, moving machine surface
- Outdoor direct sunlight ↔ dim conditions, both extremes
- Gloved hands (precision touch is unreliable)
- One-handed operation (the other hand is always on a wheel / lever)
- Multi-hour to multi-day continuous use

---

## Foundation rule — Use ADS

**Build CustomUI with the in-house Agmo Design System (`@seamos/ads`).**
Do not reinvent components. Do not hardcode colors, spacing, or
typography that bypass ADS tokens. Do not local-fork or detach an
ADS component to "tweak" it.

- ✅ Use ADS components, icons, tokens as shipped
- ✅ If something is missing, file an issue / PR on the ADS repo
- ❌ Reimplementing a button / input / dialog from scratch
- ❌ Wrapping an ADS component to override its color or spacing
- ❌ Local fork, detach, `!important` overrides

> *How* to use ADS — looking up components, reading props, picking
> tokens — is owned by the **ADS MCP** (the canonical source of
> truth for component API and token values). This skill does not
> repeat that — it only declares the rule.

---

## UX principles

Detailed rationale + examples per principle in
`references/ux-principles.md`. Anti-pattern catalog in
`references/ux-anti-patterns.md`.

### Core 7 — every UI on a moving machine

1. **Easy & Safe** — One hand. No two-handed UI, no multi-touch
   gestures, no eye-grabbing animation or auto-scrolling text.
   Targets ≥ 64 dp (gloved-hand baseline).

2. **Glanceability + immediate response** — The user can spare
   1–2 seconds for the display. If information isn't legible in that
   window, the eye stays off the work surface too long. Input
   feedback within 0.25 sec, or duplicate taps follow. High contrast.
   Color + shape + position — never color alone.

3. **Consistency** — Follow ADS / SeamOS UI as shipped. The user
   moves between apps and brand machines; learning cost must be
   near zero. No "this one screen looks slightly different".

4. **Simplicity in content** — Operator language, not raw signal
   names. Only information directly tied to the current task
   (Minimum Feature). No memorized rules required (Less Policy).
   Runnable from the first screen alone.

5. **One thing per screen** — A single goal per screen. Monitoring,
   settings, calibration, mode switching are separate screens. Mixing
   them causes mis-presses while operating.

6. **Easy to answer (3 sec)** — Every confirm or modal is answerable
   in 3 seconds. No free-text input (keyboards are unusable while
   operating). Up to 2–3 options at once.

7. **Tap & Scroll (one hand)** — Single-tap interactions, vertical
   scroll. No horizontal swipe (false-positive under vibration), no
   fine-grained sliders, no drag-and-drop.

### Operational Context 3 — moving-machine specific

8. **Status persistence** — Core machine state (engine, fuel,
   pressure, implement, auto-mode ON/OFF) lives in a persistent
   status bar visible on every screen. Never hidden by a settings
   screen or full-screen mode.

9. **Safety override** — Critical alerts (collision, overheat,
   fault, person detected) appear as a full-screen modal that blocks
   every other UI. Visual + audio + haptic, simultaneously. Explicit
   acknowledgement required. Never a toast. Never auto-dismissed.

10. **Resumable** — Work is interrupted frequently for external
    reasons (refuel, meal, zone change). Persist progress, mode,
    partial input. On re-entry, resume from the last screen — never
    force a full restart.

---

## Hard rules (the most often violated)

- **Use ADS.** Do not reinvent or fork.
- **No two-handed UI.** Other hand is on a control.
- **No free-text input** during operation.
- **No horizontal swipe, no precision drag.** Vibration → false positives.
- **No color-only meaning.** Sunlight + color blindness will defeat it.
- **No toast for safety alerts.** Full-screen modal, three channels,
  explicit ack.

## Cross-references

- ADS components, props, token values, MCP usage: **ADS docs / ADS MCP**
- Communication protocol (port discovery, WS frames, REST, cloud-proxy):
  `seamos-customui-client`
- Backend (Java / C++ REST · WebSocket server, DB, lifecycle):
  `seamos-app-framework`
