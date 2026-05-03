# UX Principles — detailed

Each principle: **why / ✅ Do / ❌ Don't / example**.

Operating environment (premise): vibration, direct sunlight ↔ dim
conditions, gloved hands, one-handed operation, multi-hour continuous
use.

---

## Core 7

### 1. Easy & Safe — one hand, no two-handed UI

**Why.** The user's other hand is always on a steering wheel or control
lever. The moment the UI demands two hands, machine control either
stops or becomes dangerous. Precision finger motion fails under
vibration.

**✅ Do**
- Make every interaction reachable as a single tap
- Minimum 64dp touch targets (gloved-hand baseline)
- Minimize visual stimuli that pull the eye away from the work surface

**❌ Don't**
- Multi-touch gestures (pinch zoom, two-finger tap)
- Press-and-hold while another finger does something else
- Eye-grabbing transitions, auto-scrolling text

```tsx
// ❌
<View onTouchStart={handlePinchStart} onTouchMove={handlePinchMove} />

// ✅
<Stack gap="lg">
  <Button size="xl" label="Zoom in" onClick={zoomIn} />
  <Button size="xl" label="Zoom out" onClick={zoomOut} />
</Stack>
```

---

### 2. Glanceability + immediate response — 1–2 sec read, 0.25 sec feedback

**Why.** During work the user can spare only 1–2 seconds for the
display. If the information is not legible in that window, the eye
stays off the work surface too long and accidents happen. After an
input, if there is no visual feedback within 0.25 seconds, the user
suspects "did it not register?", taps again, and creates an
unintended duplicate input.

**✅ Do**
- High contrast (legible in direct sunlight)
- Large type, large numbers
- Distinguish meaning by color **plus** shape, position, icon, text
- Visual feedback the moment the input lands (pressed state, color shift)

**❌ Don't**
- Light grey only for disabled state (invisible in sunlight)
- Color-only success / danger
- Small type, too much information per row
- Hide response delay behind a loading indicator

```tsx
// ❌ — color-only danger
<Text color="red">Engine overheat</Text>

// ✅ — color + icon + position (top-fixed)
<AlertBanner severity="danger" icon="thermometer" position="top-fixed">
  Engine overheat
</AlertBanner>
```

---

### 3. Consistency — follow ADS / SeamOS UI as-is

**Why.** A user moves between multiple apps on one device, and between
multiple brand machines on one site. Icons, colors, positions, and
interactions must be consistent so learning cost is near zero. Once
"this one screen has a slightly different pattern" creeps in, the
user has to relearn everywhere.

**✅ Do**
- Use ADS components, icons, colors, spacing as shipped
- Follow domain-standard notations / icons where they exist
- Resist the "just slightly different here" temptation

**❌ Don't**
- Wrap an ADS component to override its color or spacing and re-export
  as a new component
- A different layout grid / typography for one screen only
- Bypass ADS tokens and hand-pick colors

```tsx
// ❌ — wrapping with arbitrary overrides
function MyButton(props) {
  return <Button {...props} style={{ background: '#0066ff', borderRadius: 4 }} />
}

// ✅ — ADS as-is
<Button variant="primary" size="lg">Save</Button>
```

---

### 4. Simplicity in content — operator language, only what is needed

**Why.** The manual is not read. The first screen alone must be enough
to get started. Exposing raw signal names, abbreviations, and
technical terms forces the user to guess meaning every time, and a
wrong guess means wrong work.

**✅ Do**
- **Casual concept**: domain-natural language the operator already uses
- **Minimum feature**: only information directly tied to the current
  workflow
- **Less policy**: minimize rules and sequences the user must memorize
- Preserve standard abbreviations already in field use (don't translate
  them arbitrarily)

**❌ Don't**
- Raw signal names / CAN abbreviations / internal codes verbatim
- Mix statistics / logs / settings into the monitoring screen
- Force a "7-step tutorial" on first entry

```tsx
// ❌
<Field label="Hyd_Press_Sensor_1">{value}</Field>

// ✅
<Field label="Hydraulic pressure">{value} bar</Field>
```

---

### 5. One thing per screen — single goal

**Why.** During work the user can attend to one thing at a time. When
multiple goals share a screen, the cost of deciding where to look
adds 1–2 seconds. A mode switcher next to monitoring causes
mis-presses while operating.

**✅ Do**
- During work = monitoring only
- Settings, calibration, logs on separate screens
- Different screens for different modes (work / drive / standby)

**❌ Don't**
- Monitoring + mode switcher + settings on the same screen
- A mini settings panel inside the work screen
- "Advanced options" toggle that converts the same screen into two
  different modes

```tsx
// ❌
<Screen>
  <Monitoring />
  <ModeSelector />     {/* mis-pressed during work */}
  <SettingsPanel />
</Screen>

// ✅
<MonitoringScreen />
{/* Mode switching is a separate screen with explicit entry */}
```

---

### 6. Easy to answer (3 sec) — minimize input during work

**Why.** During work the user can answer in 3 seconds at most. Past
that, the question is wrong. Free-text input is forbidden outright
because keyboards are unusable while operating.

**✅ Do**
- All confirms / modals are simple OK / cancel
- Multiple choice up to 2–3 options
- Choose from pre-defined values (registry / menu)

**❌ Don't**
- Free-text input (work names, memos belong on a separate post-work screen)
- Ambiguous prompts ("Continue?" — continue what?)
- 5+ options

```tsx
// ❌
<Modal>
  <Input placeholder="Enter work name" />
</Modal>

// ✅
<Modal>
  <RadioGroup>
    <Radio value="A">Zone A</Radio>
    <Radio value="B">Zone B</Radio>
  </RadioGroup>
</Modal>
```

---

### 7. Tap & scroll (one hand) — no precision gestures

**Why.** Under vibration, fine-grained sliders and small drags either
trigger unintentionally or fail to land on the intended value.
Horizontal swipe is especially prone to false-positive from machine
shake. Vertical scroll, even when slow on a large area, works
reliably because it's tolerant of jitter.

**✅ Do**
- +/- buttons, large dials, step inputs
- Vertical scroll
- Large toggle switches (single tap)

**❌ Don't**
- Horizontal swipe navigation
- Fine-grained sliders (1px step)
- Drag-and-drop

```tsx
// ❌
<Slider min={0} max={100} step={1} />

// ✅
<Stack direction="row" gap="md">
  <Button size="xl" label="-" onClick={dec} />
  <Display value={value} />
  <Button size="xl" label="+" onClick={inc} />
</Stack>
```

---

## Operational Context 3

### 8. Status persistence — core state visible everywhere

**Why.** The user is constantly checking "is this machine still OK?".
If core state (engine state, fuel, temperature / pressure, implement
state, auto-mode ON/OFF) disappears the moment a different screen
opens, the user has to keep returning to the main screen — and any
fault that develops in the meantime goes unnoticed.

**✅ Do**
- A persistent status bar / strip on every screen
- 5–7 core indicators always visible
- Color / icon change in the status bar the moment something goes wrong

**❌ Don't**
- Status bar removed on screen entry
- "Full screen mode" in settings hiding the status
- Core state visible only on the monitoring screen

```tsx
// ❌
<Screen>
  <SettingsForm />   {/* no status bar */}
</Screen>

// ✅
<Screen>
  <PersistentStatusBar />
  <SettingsForm />
</Screen>
```

---

### 9. Safety override — alerts above all UI

**Why.** Critical signals (collision / overheat / fault / nearby person
detected) tolerate no delay. A toast is missed when the user is
looking elsewhere. In a noisy environment audio alone is not enough,
and haptic alone is not enough either. All three channels must fire
together.

**✅ Do**
- Full-screen modal that blocks every other UI
- Visual + audio + haptic, simultaneously
- Explicit acknowledgement required (no auto-dismiss)

**❌ Don't**
- Toast for safety alerts
- Auto-dismiss
- Dismissible / collapsible banners

```tsx
// ❌
toast.error('Nearby person detected')

// ✅
<SafetyOverrideModal
  severity="critical"
  visual={true}
  audio={true}
  haptic={true}
  requireAck={true}
>
  Nearby person detected — stop immediately
</SafetyOverrideModal>
```

---

### 10. Resumable — interruptions are frequent

**Why.** Work is interrupted frequently for external reasons (refuel,
meal, zone change). If the UI forces the user to "start over",
5–10 minutes of re-setup accumulate every time, totalling tens of
lost minutes per day. The UI must remember the last state and let
the user continue from where they left off.

**✅ Do**
- Persist progress / mode / partial input (in memory + on-device)
- On re-entry, automatically return to the last screen / last step
- Explicit "start over" button is separate (with one extra confirm)

**❌ Don't**
- Full reset on refresh
- Partial form lost
- Mid-work modal closed by an external cause restarts from step 1

```tsx
// ❌
const [step, setStep] = useState(1)  // memory only

// ✅
const [step, setStep] = usePersistedState('workflow.step', 1)
useEffect(() => {
  if (step > 1) showResumeBanner()
}, [])
```
