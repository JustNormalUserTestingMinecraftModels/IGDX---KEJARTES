# Settings "Buku Catatan" polish — design spec

**Date:** 2026-09-28
**Screen:** `Scenes/UI/Settings.tscn` (`PENGATURAN`)
**Status:** Design approved in brainstorming; handoff for implementation
(intended for a teammate's Claude working the branch in GitHub).
**Direction:** A — "Buku Catatan" (grouped notebook), chosen over B (pinned
sticky-note board) for lower risk and fit with the existing `Card`/ThemeFactory
system.

---

## Problem

Settings is the one screen that does not feel like KejarTes. It is a flat
vertical stack of seven near-identical cream `Card` panels: one audio card with
three **bare** `HSlider` rails (no icon, no fill, no value readout — reads as a
technical form) followed by five identical generic `CheckButton` rows, then the
Back button. Nothing is grouped, nothing carries a section label, there is no
iconography and no school metaphor. The reviewer's note: inconsistent, blank,
"no alive or school feeling."

This is a **visual/layout polish only**. Every control keeps its behaviour and
its `%unique` node name; `Settings.gd`'s wiring to `AudioDirector` and
`GameSettings` is untouched except for two additive changes (a live `%` readout
write and per-interaction SFX calls).

## Goals

1. Group the seven loose cards into **three labelled sections** — Suara,
   Permainan, Aksesibilitas — each a `Card` with a header row and a
   colour-coded left accent stripe (warm orange / green / blue).
2. Give the three sliders a face: leading icon + label + **live `%` readout**,
   and a warm **filled track with a round grabber** (new ThemeFactory slider
   variation, no `theme_override`).
3. Restyle the five toggles as warm "wooden" pill switches (ThemeFactory
   `CheckButton` variation; green = on, tan = off).
4. Replace the shared `BG.jpg` sky background with a **dedicated** wood-desk
   notebook background for this screen only (leaving `BG.jpg` untouched on the
   six other screens that share it).
5. Add per-interaction **SFX** (reusing existing `AudioDirector` ids plus one
   placeholder id) and **lively entrance/feedback animations** that honour the
   `Kurangi Gerakan` (reduce_motion) setting.

## Non-goals

- No behaviour change to any setting; no new persisted settings.
- No changes to `GameSettings` or `AudioDirector`'s public API (only new
  `@export` SFX slot + calls).
- No global `BG.jpg` swap; no restyle of any other screen.
- No Direction-B rotated/pinned cards.
- No `theme_override_*` anywhere except layout-only constants
  (`separation`, `margin_*`) — the project rule.

---

## Layout

Single scrolling column inside the existing `SafeArea (SafeAreaMargin) →
Layout (VBox)`. The flat 7-card stack becomes:

```
Layout (VBox, separation ~20)
├── Header (VBox, centered)
│   ├── TitleLabel  "PENGATURAN"           (H1Label — unchanged)
│   └── SubtitleLabel "Atur suasana belajarmu"  (CaptionLabel — NEW)
├── SuaraCard (Card, orange stripe)
│   ├── SectionHeader (HBox: icon + "SUARA")
│   ├── MasterRow  (icon + label + %readout + KejarSlider)
│   ├── BgmRow
│   └── SfxRow
├── PermainanCard (Card, green stripe)
│   ├── SectionHeader (icon + "PERMAINAN")
│   ├── TutorialRow  (icon + label + KejarToggle)
│   └── SkipDialogRow
├── AksesibilitasCard (Card, blue stripe)
│   ├── SectionHeader (icon + "AKSESIBILITAS")
│   ├── LookLayerRow  (Efek Visual)
│   ├── HapticsRow    (Getaran (Haptic))
│   └── ReduceMotionRow (Kurangi Gerakan)
└── BackButton  (SecondaryButton — unchanged, keeps return_button icon)
```

**Control identity is preserved.** The eight interactive nodes keep their exact
current names and `unique_name_in_owner`: `%MasterSlider`, `%BgmSlider`,
`%SfxSlider`, `%TutorialToggle`, `%SkipDialogToggle`, `%LookLayerToggle`,
`%HapticsToggle`, `%ReduceMotionToggle`, `%BackButton`. They move under the new
section cards but resolve identically, so `Settings.gd`'s `@onready` lookups and
signal wiring need no change.

**A slider row** is a `VBox`:
- top `HBox`: `TextureRect` (icon, `%unique` not needed) + label
  (`BodyLabel`) with `size_flags_horizontal = 3` + a right-aligned readout
  label. The readout label **is** `%unique` (e.g. `%MasterValueLabel`) so
  `Settings.gd` can update it.
- the `HSlider` below, `KejarSlider` variation.

**A toggle row** is an `HBox`: icon `TextureRect` + label (`BodyLabel`,
`size_flags_horizontal = 3`) + the `CheckButton` (`KejarToggle` variation).

**Tall-phone rule.** The whole `Layout` stays inside `SafeArea`; the background
is Full Rect + Keep Aspect Covered; sections re-anchor to their edge as the
existing MainMenu pattern. Add the scene to
`tests/test_tall_screen_layout.gd` coverage if it is not already picked up.

---

## New assets

### Background — 1 texture
`Assets/Images/UI/Settings/settings_desk_bg.png` — a warm wooden desk with an
open ruled notebook, muted enough that the cream cards read on top. Must be
tall-phone safe (important content within the central 9:16, extendable to
20:9). Placeholder-generated until final art lands; drop-replaceable at the
same path. **Constraint:** muted mid-tones only — the cards and their brown ink
must keep contrast over it (measure alpha/luminance if it carries soft edges,
per the `paper.png` lesson).

### Icons — 8 transparent SVGs
`Assets/Images/UI/Settings/`, one flat brown line family so they read as a set
(Godot imports SVG natively). Reuse was considered but no existing icon maps
cleanly to audio/haptic/motion, and mixing the stat-icon style with reused nav
PNGs looked inconsistent, so a fresh consistent family is generated:

| File | For |
|---|---|
| `ic_suara.svg`    | Suara Utama (speaker) |
| `ic_musik.svg`    | Musik (note) |
| `ic_sfx.svg`      | Efek Suara (soundwave) |
| `ic_tutorial.svg` | Tutorial Minigame (mortarboard) |
| `ic_dialog.svg`   | Lewati Dialog Minigame (slashed speech bubble) |
| `ic_visual.svg`   | Efek Visual (sparkle) |
| `ic_haptic.svg`   | Getaran (phone vibrate) |
| `ic_motion.svg`   | Kurangi Gerakan (running figure) |

Plus three small section-header glyphs (or reuse three of the above): volume,
gamepad, accessibility. Author's call at build time whether the section header
reuses the row icon or gets its own.

### ThemeFactory variations (in `ThemeFactory.gd`, then rebake)
- **`KejarSlider`** (`HSlider`): filled track StyleBox in warm amber
  (`tokens`-driven), grabber StyleBox as a round cream knob with amber border,
  unfilled track in `ece3d2`-equivalent token. No `theme_override`.
- **`KejarToggle`** (`CheckButton`): pill background, green when pressed / tan
  when not, cream knob. Use existing token colours; add tokens only if a needed
  colour is genuinely absent.
- **`SectionLabel`** (`Label`): Boohong display, small, letter-spaced, brown —
  for the `SUARA` / `PERMAINAN` / `AKSESIBILITAS` headers. Reuse `H2Label` if it
  fits; add `SectionLabel` only if not.
- **Section stripe:** the coloured left accent is a `Card`-variant StyleBox with
  a coloured left border, OR a thin coloured `Panel` child pinned to the card's
  left edge. Prefer a StyleBox variant (`SuaraCard`/`PermainanCard`/
  `AksesibilitasCard`, or one `SectionCard` variation parameterised by a child
  stripe node) so nothing is built at runtime. Three accent colours become
  three `DesignTokens` entries.

All colour/radius tokens go through `design_tokens.tres`; after editing
`ThemeFactory.gd` or tokens, **rebake** via `Scripts/Design/BakeTheme.gd`
(Ctrl+Shift+X). Remember a changed/added Resource `@export` default needs a full
editor restart before it takes effect.

---

## SFX (reuse-only + one placeholder)

Existing `AudioDirector` ids cover almost everything. Wire in `Settings.gd`:

| Interaction | id | Notes |
|---|---|---|
| Slider drag | `tap` (SFX) / `pop` (BGM) | **already wired** in `_on_volume_changed`; keep |
| Toggle → on | `settings_toggle` (NEW placeholder id) | see below |
| Toggle → off | `settings_toggle` | same clip; pitch/variant optional |
| Section entrance | `whoosh` | one per section as it staggers in (or a single `whoosh` on open) |
| Back pressed | `cancel` | **already wired**; keep |

**One new id, `settings_toggle`**, added to `AudioDirector.gd` as a documented
`@export` slot **aliasing an existing clip** (e.g. `select.ogg`), exactly like
the existing `tally` / `score_tick` / `combo_up` placeholder aliases. No new
audio file is required to ship; a real clip drops onto the slot later with no
code change. Record it in `DEBT.md`'s audio-placeholder group.

All SFX calls gated with `if not Engine.is_editor_hint():` to stay silent under
test, matching the existing file.

---

## Animations (honour `reduce_motion`)

Use the project's own `Juice.gd` and `AnimUtils.gd`. Every motion below checks
`GameSettings.reduce_motion` and degrades to an instant state when it is on
(the setting already exists and is read here).

- **Section entrance:** `Juice.stagger_in` on the section cards when the screen
  opens (already called on `_collect_rows()`; retarget to the three section
  cards so they cascade). reduce_motion → cards appear at rest.
- **Toggle flip:** a small `AnimUtils.squash_bounce` on the knob when toggled.
  reduce_motion → no bounce.
- **Slider change:** the `%` readout does a tiny pop / `count_up` toward the new
  value; the filled track eases to width rather than snapping. reduce_motion →
  readout updates instantly, track snaps.
- **Back button:** existing press/release juice from `UIPolish` (automatic).

All animation kick-offs stay gated behind `if Engine.is_editor_hint(): return`
as the file already does for its entry animation.

---

## `Settings.gd` changes (additive only)

1. `@onready` refs to the three new value labels
   (`%MasterValueLabel`, `%BgmValueLabel`, `%SfxValueLabel`).
2. In `_ready`, set each readout from the initial slider value; extend
   `_on_volume_changed` to write `"%d%%" % round(value * 100)` to the matching
   label and trigger the readout pop (reduce_motion-aware).
3. In each `_on_*_toggled`, add the `settings_toggle` SFX + `squash_bounce`
   (both editor-gated / reduce_motion-aware).
4. `_collect_rows()` returns the three section cards for the stagger.

Every new line carries the project's `##` documentation. No behaviour of any
setting changes.

---

## Tests (`tests/test_settings.gd`, source-scan style)

Extend the existing suite:
- The three section cards exist and carry the section-card variation.
- Each of the eight controls still resolves by its `%unique` name.
- The three slider value labels exist and are `%unique`.
- `KejarSlider` / `KejarToggle` variations are applied to the sliders/toggles.
- The 8 icon textures and the desk background load (path/`load()` check).
- `AudioDirector` exposes the new `settings_toggle` id.
- `Settings.gd` source references `reduce_motion` in its animation paths.

Run targeted `test_run(suite="test_settings")` (and `test_theme_factory`,
`test_tall_screen_layout` after the theme/layout edits). Budget one editor
restart per full run. After any full run, `git status` — the `theme_rebake`
and `AudioDirector` boot-write hazards apply.

---

## Constraints honoured (project rules)

- No `theme_override_*` except layout constants — ThemeFactory variations only.
- No runtime-built visuals — all chrome is static nodes in the `.tscn`; icons
  are textures; the only runtime work is per-call dynamic content (value text,
  animations), which is allowed.
- Every screen fills any phone — content inside `SafeAreaMargin`, background
  Keep Aspect Covered, edge re-anchoring.
- No emoji as iconography — real transparent SVG textures.
- `Balance.gd` untouched; any new tunable is a named `const`/`@export`/token,
  never inline.
- New placeholder art/audio recorded in `DEBT.md` (desk bg, 8 icons,
  `settings_toggle` alias), grouped not itemised.

## Open items for the implementer

- Decide section-header icon reuse vs dedicated glyph at build time.
- Confirm whether `H2Label` suffices for section headers or `SectionLabel` is
  needed.
- Choose StyleBox-stripe vs child-panel-stripe for the section accent (prefer
  StyleBox).
