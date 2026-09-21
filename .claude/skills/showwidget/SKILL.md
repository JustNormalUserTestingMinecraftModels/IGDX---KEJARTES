---
name: showwidget
description: Use when the user wants to SEE how a KejarTes screen, card, button or badge could look before any code is written - "show me options", "what would that look like", "give me a couple of versions", "/showwidget" - or when they say one screen looks out of place next to a polished one. Also use when a visual choice is genuinely theirs to make and work should stop until they pick.
---

# Show Widget

A pick-one visual proposal: two or three faithful mockups of a real KejarTes
surface, rendered inline with `mcp__visualize__show_widget`, differing in
exactly one named thing. The user picks; only then does any `.tscn` or `.gd`
get touched.

This is a *decision aid*, not a report. Research as deeply as the change
deserves — then spend almost all of that research on making the mockup right,
and almost none of it on prose.

## 1. Ground the mockup in the real screen

A KejarTes `.tscn` holds no colours. Resolve them, never eyeball them:

```
.tscn node → theme_type_variation (e.g. "Card", "H1Label")
           → Scripts/Design/ThemeFactory.gd (the variation's block)
           → tokens.<field>
           → Scripts/Design/DesignTokens.gd (the literal hex)
```

Useful anchors already in `DesignTokens.gd`: `surface_page #FBF1E3`,
`surface_card #FFFDF8`, `surface_sunken #EFE0CB`, `brand_primary #7A4A2B`,
`text_primary #3B2412`, `text_secondary #7A5C40`, `cat_akademis #1F6FBA`,
`cat_senibudaya #3D7F12`, `cat_olahraga #E03A18`, `currency_gold #ffc93c`.

Take the strings from the scene too — real Indonesian labels, a real student
name, real numbers. A mockup with invented copy is a drawing of a different
game.

If the user named a polished screen to match ("like the inventory card"), read
that scene first: what you are proposing is that its language move to the
other screen, so you need its actual header band, frame, chip and bar
treatment in hand.

## 2. The widget contract

Call `mcp__visualize__read_me` with `modules: ["mockup"]` first. Then build
**one** widget containing, in order, per option:

1. **A label band** — 11px, uppercase, letter-spaced, `var(--text-secondary)`:
   `OPTION A — HEADER BAND, BROWN (TIES TO THE MASTHEAD)`. Dimension, value,
   and the one-phrase reason it might win.
2. **The mock** — the smallest unit that contains the change, drawn at
   fidelity, on a `var(--surface-1)` container with 12px radius and padding.
3. After the last option, **one caption**, at most two lines: what every
   option shares, then the single sentence naming what differs.

**Every option varies one dimension and only that dimension.** Everything
else — geometry, copy, portrait, bars, spacing — is byte-identical between
them, so the user is comparing one thing and not four. Two options is the
good number; three is the ceiling.

If your candidates differ in how they are *built* but look the same to a
player, that is a prose question, not a widget. Ask it in a sentence.

Mechanics that are easy to get wrong:

- `viewBox="0 0 680 H"` for SVG; 680 is load-bearing and makes SVG units
  render 1:1 with CSS pixels. For HTML mocks the container is 680px.
- The mock is a hardcoded-hex island — KejarTes colours must not invert in
  dark mode. The frame around it (label bands, caption) uses theme vars.
  Never mix the two inside one box.
- No gradients, `feDropShadow`, `filter`, `<!-- comments -->`, `<style>`
  colour blocks, font-weight 600, or `class` names the host has not defined.

## 3. The prose contract

**Before the widget:** at most three sentences. Name the reference surface,
name the one dimension that varies, and say you will not implement until they
pick.

**After the widget:** one or two sentences, and a recommendation if you have
one.

That is the whole response. Findings from your research go in *one* line each,
and only if they change the pick — a real bug you found in the art, a test
that pins a rect, a spec that already settled this. Everything else waits
until they have chosen; it is not lost, you still know it.

## 4. After they pick

Build it under the normal rules: `ThemeFactory` variation, never a
`theme_override_*`; static chrome in the `.tscn`, never constructed at
runtime; `@export` knobs documented with `##`. Then `test_run` the suites that
touch the screen.

## Common mistakes

| Mistake | Fix |
|---|---|
| Options vary a different thing each | One named dimension, held constant everywhere else |
| Option labels only in the prose | The label band is inside the widget, above its mock |
| Four options | Two, three at most |
| Approximated colours | Resolve variation → ThemeFactory → DesignTokens |
| Invented copy or student names | Read them out of the scene |
| `viewBox="0 0 880 …"` | 680 wide, always |
| Long diagnosis above, findings list below | Three sentences above, two below |
| Building it before they answer | The pick is the point of the widget |
