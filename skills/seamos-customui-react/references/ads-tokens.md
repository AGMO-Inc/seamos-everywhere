# ADS Tokens — categories, usage, MCP flow

ADS exposes design tokens as **CSS Variables (`--ads-*`)**.
**Actual token names and values come from the MCP** —
`get_component` / `list_components`. This document describes
categories, structure, and usage patterns only.

---

## Token categories

| Category | Variable pattern | Use |
|---|---|---|
| **color** | `var(--ads-color-*)` | text · background · border, status (success/warning/danger), brand |
| **spacing** | `var(--ads-spacing-*)` | margin · padding · gap, layout grid |
| **typography** | `var(--ads-font-*)` / `var(--ads-text-*)` | font-family · size · weight · line-height |
| **shadow** | `var(--ads-shadow-*)` | elevation · focus ring |
| **radius** | `var(--ads-radius-*)` | border-radius |
| **motion** | `var(--ads-motion-*)` | duration · easing |

The exact token names within each category (e.g.
`--ads-color-text-primary`, `--ads-spacing-md`) can change between
ADS versions, so **always query the MCP** instead of memorizing.

---

## Usage patterns

### CSS-in-JS / styled

```tsx
import { styled } from 'styled-components'  // or whatever ADS recommends

const Card = styled.div`
  background: var(--ads-color-surface);
  color: var(--ads-color-text-primary);
  padding: var(--ads-spacing-md);
  border-radius: var(--ads-radius-lg);
  box-shadow: var(--ads-shadow-sm);
`
```

### Inline style — tokens only, no raw values

```tsx
// ❌ raw values
<div style={{ color: '#1A1A1A', padding: 16 }} />

// ✅ token variables
<div style={{
  color: 'var(--ads-color-text-primary)',
  padding: 'var(--ads-spacing-md)',
}} />
```

### Pass tokens through ADS component props

ADS components consume tokens internally. The user only needs to know
the prop names.

```tsx
// The component applies the right tokens
<Button variant="primary" size="lg">Save</Button>
<Stack gap="md">...</Stack>
```

For each component, **which props map to which tokens** is what
`get_component` returns.

---

## MCP call flow

```
[1] Unknown component — name not known
    → search_components(query)
       e.g. search_components("toggle input")
       → returns candidate list with short descriptions

[2] Right before use — verify props / examples / variables
    → get_component(name)
       e.g. get_component("Button")
       → returns prop signature, usage examples, dependent CSS variables

[3] Apply the recommended pattern as-is
    → follow the MCP-returned recommended example
       (Flat vs Compound varies per component — never hard-coded by
       this skill)
```

### What not to do

```
✗ Write props from memory (sloppy)
✗ Guess props from a different design system (e.g. Material UI)
✗ Call list_components once, cache the result, and rely on it for
   days (ADS version upgrades will silently break you)
```

---

## Meta rules

- **No guessing.** The MCP is the source of truth. Call it right
  before use.
- **No hardcoded token values.** Hardcoding color / spacing /
  typography breaks theme switching, dark mode, and accessibility
  contrast modes.
- **Don't invent new categories.** If a new token is needed, file an
  issue / PR on the ADS repo.
- If you find yourself wanting a non-`var(--ads-*)` variable name
  pattern, that's a sign ADS hasn't defined that category yet — report
  it to ADS.

---

## Quick reference

| Situation | Call |
|---|---|
| "What components are even available?" | `list_components` |
| "Is there something like a button?" | `search_components("button")` |
| "How do I use Button correctly?" | `get_component("Button")` |
| "Is there a toggle? What's it called?" | `search_components("toggle switch")` |
| "Which CSS variables does this component use?" | `get_component(name)` → variables section |
