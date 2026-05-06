# UX Anti-Patterns — catalog

Patterns to **avoid** on a screen running on a moving machine, with
**alternatives**. Each entry: **symptom / why it fails / ❌ code /
✅ alternative**.

---

## 1. Horizontal swipe navigation

**Symptom.** Screen / page transitions handled by horizontal swipe.

**Why it fails.** Under vibration, an unintentional horizontal motion
of the hand near the screen flips the page. The user thinks "wait,
why is this screen up?" and the workflow breaks.

```tsx
// ❌
<SwipeableViews onSwipe={(idx) => setPage(idx)}>
  <MonitoringPage />
  <SettingsPage />
</SwipeableViews>

// ✅ — explicit tabs or menu
<TabBar value={page} onChange={setPage}>
  <Tab label="Monitoring" value="monitor" />
  <Tab label="Settings" value="settings" />
</TabBar>
```

---

## 2. Free-text input

**Symptom.** Work names, memos, tags collected as free-text.

**Why it fails.** A keyboard is unusable while operating. Gloves
prevent accurate typing. The seconds spent typing are seconds the
user can't watch the work surface.

```tsx
// ❌
<Input placeholder="Enter work name" value={name} onChange={setName} />

// ✅ — pre-registered, picked from a list
<Select value={selected} onChange={setSelected}>
  {presetWorks.map(w => <Option key={w.id} value={w.id}>{w.name}</Option>)}
</Select>
{/* If free-text is truly required, defer it to a post-work / parked-mode screen */}
```

---

## 3. Auto-scrolling text (marquee / ticker)

**Symptom.** Long messages or alerts that auto-scroll left→right or
top→bottom.

**Why it fails.** The eye is captured by the moving text and stays
off the work surface. Pleos Connect's design guide explicitly forbids
"auto-scrolling text". Operators also have the right to read at their
own pace.

```tsx
// ❌
<Marquee>A very long alert message scrolls automatically...</Marquee>

// ✅ — static, truncate with ellipsis, details on a separate entry
<Banner>
  <Text truncate>A very long alert message...</Text>
  <Button label="Details" onClick={openDetail} />
</Banner>
```

---

## 4. Color-only meaning

**Symptom.** Success is green, danger is red — no other cue.

**Why it fails.** Colors fade in direct sunlight. Color-blind users
can't distinguish them. A peripheral color change is easy to miss.

```tsx
// ❌
<Indicator color={status === 'ok' ? 'green' : 'red'} />

// ✅ — color + icon + position + text
<Indicator
  color={status === 'ok' ? 'success' : 'danger'}
  icon={status === 'ok' ? 'check' : 'alert'}
  label={status === 'ok' ? 'OK' : 'Check required'}
/>
```

---

## 5. Small touch targets

**Symptom.** Buttons / icons sized 32–40 px.

**Why it fails.** Hard to hit with gloves. Vibration triggers adjacent
buttons. The user ends up tapping two or three times — wasted seconds.

```tsx
// ❌
<IconButton icon="settings" size="sm" />   /* 32px */

// ✅ — minimum 64dp
<IconButton icon="settings" size="xl" />   /* 64px+ */
{/* Spacing between adjacent buttons also ≥ 16dp */}
```

---

## 6. Two-handed UI (multi-touch gestures)

**Symptom.** Pinch zoom, two-finger rotate, two-finger swipe.

**Why it fails.** The user's other hand is always on a wheel / lever.
Putting both hands on the screen means either machine control stops
or the operator accepts a safety risk.

```tsx
// ❌
<MapView gestures={['pinch', 'rotate', 'twoFingerPan']} />

// ✅ — equivalent function via single-tap buttons
<MapView>
  <ZoomControls>
    <Button label="+" onClick={zoomIn} size="xl" />
    <Button label="−" onClick={zoomOut} size="xl" />
  </ZoomControls>
  <Button label="North up" onClick={resetRotation} size="xl" />
</MapView>
```

---

## 7. Flashing alert animation

**Symptom.** Risk / warning shown by fast blink (sub-1-second period).

**Why it fails.** The eye is captured and the work surface is missed.
Photosensitive seizure risk. After the alert is acknowledged, ongoing
flashing keeps adding cognitive load. WCAG also forbids more than
3 flashes / second.

```tsx
// ❌
<Alert blink interval={500} />   /* blink every 0.5 sec */

// ✅ — static emphasis + explicit acknowledgement
<Alert
  severity="warning"
  icon="alert"
  pulse="slow"   /* if any pulse, only a very slow one-time pulse */
  requireAck
/>
```

---

## 8. Stacked modals (infinite stack)

**Symptom.** Modal B opens on top of A, then C on top of B. The user
loses track of which action belongs to which modal.

**Why it fails.** During work, the user has no headroom to keep a
context stack in mind. Only one decision at a time should be exposed
(extension of "one thing per screen").

```tsx
// ❌
<Modal open={modalA}>
  <Modal open={modalB}>   {/* B on top of A */}
    <Modal open={modalC}>...</Modal>
  </Modal>
</Modal>

// ✅ — one at a time, advance steps inside the same modal
<Modal open={open} step={step}>
  {step === 1 && <StepA onNext={() => setStep(2)} />}
  {step === 2 && <StepB onNext={() => setStep(3)} />}
  {step === 3 && <StepC onClose={close} />}
</Modal>
```
