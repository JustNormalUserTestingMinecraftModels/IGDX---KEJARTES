# ResultCheckup Interactivity & Polish — Design

**Date:** 2026-09-03
**Screen:** `Scenes/SchoolSimulation/ResultCheckup.tscn` / `Scripts/SchoolSimulation/ResultCheckup.gd`
**Builds on:** `docs/superpowers/specs/2026-09-03-result-checkup-week-recap-design.md` (merged this session)
**Status:** approved in brainstorming, not yet planned

## 1. Why

The week recap banner shipped with four pills that look like they should be
tappable but aren't, a needs-bar delta number that visually collides with
the tier word beside it, a pill entrance that counts all four numbers up in
parallel rather than reading left-to-right, tab switching that hard-cuts
between panes with no transition, and one leftover implementation artifact
(`ScrollFade`) that renders as an unexplained flat white bar rather than the
fade cue it was meant to be. This pass makes the banner genuinely
interactive and fixes the two visual defects.

## 2. Goal

1. Each banner pill is tappable, hints that it's tappable with a looping
   idle bounce, and opens a one-sentence explainer popup on tap.
2. The needs-bar delta reads as a directional arrow, not a number that
   overlaps the tier word.
3. The four pills' entrance is a systematic left-to-right cascade instead
   of a simultaneous parallel count-up.
4. Switching between SISWA and RIWAYAT is a directional slide+fade, not an
   instant `visible` snap.
5. `ScrollFade` is an actual gradient, not a flat panel.

## 3. Interactive pills (items 1–3)

### 3.1 Tap target

`WeekRecapPill` (`Scripts/SchoolSimulation/WeekRecapPill.gd`) gains:

- `mouse_filter = Control.MOUSE_FILTER_STOP` on the root (currently
  `MOUSE_FILTER_INHERIT` on a plain `PanelContainer`, so clicks pass
  through today).
- A `gui_input(event)` handler recognizing a press-then-release inside the
  control's rect as a tap: on press, `Juice.press(self)`; on release inside
  the rect, `Juice.release(self)` then `pill_tapped.emit()`; on release
  outside the rect (a drag-off cancel), `Juice.release(self)` only, no
  signal. This mirrors the press/release feel every `Button` gets from
  `UIPolish` without reworking `RecapPillPanel` into a button-shaped theme
  variation.
- `signal pill_tapped` — carries no payload; the pill doesn't know its own
  semantic key (`uang`/`poin`/`menang`/`event`), only `WeekRecapBanner`
  does, from the order it built the pills in.
- SFX: `AudioDirector.play_sfx(&"pill_tap")` fires on a successful tap, in
  `WeekRecapBanner`'s handler (see 3.3), not inside the pill — a tap that
  gets cancelled (drag-off) makes no sound.

### 3.2 Idle bounce hint

Once `WeekRecapBanner.play_entrance()`'s stage-2 count-up cascade (§5)
finishes, `WeekRecapBanner` starts a looping idle cycle: each pill in turn
gets a small scale-pop (`Juice.pop_in`-style, but non-destructive — scale
`1.0 → 1.08 → 1.0` over ~0.3s, not a fade-from-zero), left to right, with a
short gap between pills and a longer pause after the fourth before the
cycle repeats from the first. Entirely silent — no SFX on the idle bounce;
see the design conversation's reasoning: a looping audio cue every cycle
would read as an alarm, not a hint. The cycle:

- Is suspended (not merely invisible-but-running) whenever a
  `WeekRecapPillInfoPopup` is open, so a pill never visibly bounces behind
  the scrim.
- Is stopped outright when `ResultCheckup` starts its own close animation
  (`_on_close_pressed`), so it never outlives the screen.
- Uses a single repeating `Tween` owned by the banner (not per-pill timers),
  so the whole cycle can be paused/killed in one call.

### 3.3 The info popup

New: `Scenes/UI/WeekRecapPillInfoPopup.tscn` +
`Scripts/UI/WeekRecapPillInfoPopup.gd`, structurally a smaller sibling of
`Scenes/UI/StatDetailPopup.tscn` — same shell (`CanvasLayer` → `Scrim`
`ColorRect` → `Card` `PanelContainer`), same tap-anywhere-on-scrim-to-close
behavior, its own `pill_popup_open`/`pill_popup_close` SFX pair (see §8 —
dedicated ids, not `StatDetailPopup`'s shared ones), same
`scrim_fade_in_seconds`/`close_slide_seconds`/`scrim_fade_out_seconds`
export shape — but no `StatBar`, no numeric value line: just an icon, a
title, and one sentence of body text, because a pill has no 0–100 value to
visualize.

```gdscript
@onready var scrim: ColorRect = $Scrim
@onready var card: PanelContainer = $Scrim/Card
@onready var icon_rect: TextureRect = $Scrim/Card/Layout/Header/IconRect
@onready var title_label: Label = $Scrim/Card/Layout/Header/TitleLabel
@onready var body_label: Label = $Scrim/Card/Layout/BodyLabel
@onready var close_button: Button = $Scrim/Card/Layout/Header/CloseButton

signal closed

func configure(icon: Texture2D, title: String, body: String) -> void: ...
func open() -> void: ...  # same shape as StatDetailPopup.open()
func close() -> void: ...  # same shape as StatDetailPopup.close()
```

`WeekRecapBanner` connects to each pill's `pill_tapped` and, on the signal,
looks up that pill's fixed copy from a local const and instantiates the
popup:

```gdscript
const PILL_INFO := {
	"uang": {"title": "Uang", "body": "Total penghasilan Wirausaha yang terkumpul minggu ini."},
	"poin": {"title": "Poin", "body": "Total kenaikan Akademis, Seni Budaya, dan Olahraga minggu ini -- bisa minus jika menurun."},
	"menang": {"title": "Menang", "body": "Jumlah minigame yang dimenangkan dari total yang dimainkan minggu ini."},
	"event": {"title": "Event", "body": "Jumlah kejadian acak yang terjadi minggu ini."},
}
```

Icon per popup reuses the same texture already wired onto that pill
(`icon_uang`/`icon_poin`/`icon_menang`/`icon_event` — the banner's own
exports), so no new art and no risk of the popup showing a different icon
than the pill it explains.

## 4. Needs-bar delta becomes an arrow (item 4)

`DaySummaryNeedsBar.tscn` gains a `DeltaChevron` `TextureRect` per bar,
positioned at the bar's right edge the same way `DaySummaryStatRow`'s own
`Chevron` sits on its track — reusing
`Assets/Images/DaySummary/icon_chevron_up.png` with no new art:
`rotation_degrees = 180` gives the down arrow for a loss, `0` for a gain.
Zero delta shows neither arrow (hidden), matching the project's existing
"no news, no icon" rule elsewhere on this card.

`DaySummaryStudentRow._show_needs_delta(label, delta)` — the single
funnel both `setup_row` and `setup_week_row` already go through — stops
writing the numeric `format_needs_delta` text into a visible label and
instead:

- Shows/hides and rotates the paired `DeltaChevron` by sign.
- Keeps writing `label.text` (the number) for tests and any future reuse,
  but the `Label` node itself becomes `visible = false` permanently — its
  text is no longer rendered, only carried as data. (Decided this way
  rather than deleting the label outright: `format_needs_delta` and its
  existing test coverage stay meaningful without a second code path.)

This is the one change to `DaySummaryStudentRow.gd`/`DaySummaryNeedsBar.gd`
in this pass; both are shared with the nightly `DaySummaryPopup`, so the
fix lands there too.

## 5. Systematic pill entrance (item 5)

`WeekRecapBanner.play_entrance()`'s stage 2 currently fires all four
`pill.play_count_up(...)` calls in one loop with only a small stagger on
the count-up's own internal delay parameter, while every pill's
slide/fade-in happens together (implicitly, via the banner's own single
fade). This pass gives each pill its own slide+fade entrance, sequenced:

- Each pill starts `modulate.a = 0`, `position.y` offset `-20px` above its
  authored position.
- Pill *N* (0-indexed) starts its own tween at `N * 0.10s` after stage 2
  begins — a cascade, not four simultaneous tweens with a shared start.
- Each pill's tween: `position.y` and `modulate.a` in parallel, duration
  `dur_fast`, ease-out.
- That pill's own `play_count_up(...)` call fires only once its slide+fade
  tween finishes (chained after, not parallel with, that pill's entrance) —
  so the numbers visibly cascade left-to-right in the same rhythm as the
  pills landing, rather than counting up simultaneously while the pills are
  still arriving.

## 6. Directional pane transition (item 6)

`ResultCheckup.show_pane(pane: int)` currently does a hard
`students_pane.visible = ...` / `history_pane.visible = ...` swap with no
animation. This pass replaces that with a chained slide+fade:

- Direction is derived from `sign(pane - _active_pane)` — SISWA(0)→RIWAYAT(1)
  is `+1` (outgoing exits left, incoming enters from right); RIWAYAT(1)→SISWA(0)
  is `-1` (outgoing exits right, incoming enters from left). Deriving the
  sign rather than hardcoding two literal directions keeps the function
  correct if a third pane is ever added.
- Outgoing pane: `position.x` to `sign * -40px` and `modulate.a` to `0`,
  over `dur_fast`. Only once this tween finishes does the outgoing pane's
  `visible` actually flip to `false` — never before, so it doesn't get cut
  off mid-slide.
- Incoming pane: starts at `position.x = sign * 40px`, `modulate.a = 0`,
  `visible = true`, then tweens to `position.x = 0, modulate.a = 1` over
  `dur_fast` — chained to start right after the outgoing tween finishes,
  not in parallel with it (so the two panes never visually overlap
  mid-transition, since they occupy the same rect).
- SFX: `AudioDirector.play_sfx(&"pane_swipe")` fires once, at the start of
  the transition — a dedicated id/file copied from `swipe.ogg` (see §8),
  not the shared `swipe` cue itself. Replaces nothing; `show_pane`
  currently plays no SFX on its own (the `select` cue lives elsewhere in
  the function, on the tab tap itself, and is unchanged).
- The already-existing scroll-offset save/restore (§3.1 of the week-recap
  spec) and the `_history_animated` latch are unaffected — they still fire
  at the same points relative to the pane swap, just with the swap itself
  now animated instead of instant.
- This transition is skipped (instant swap, as before) when
  `Engine.is_editor_hint()` is true, matching every other animation on this
  screen — the editor's test runner must see synchronous state changes.

## 7. Fix `ScrollFade` (item 7)

`ScrollFade` (`Scenes/SchoolSimulation/ResultCheckup.tscn`,
`Margin/VBox/ScrollFade`) is currently a plain `Panel` with the
`SunkenPanel` theme variation — a flat, opaque, light-colored box sitting
between the scrollable pane and `BtnClose`, with no visual relationship to
"there's more content below." This pass replaces it with a real top-to-
transparent gradient:

- `TextureRect` (not `Panel`), `texture` a `GradientTexture2D` created via
  the editor's `resource_manage` tooling (or authored as a `.tres`) with
  two `Gradient` points: `surface_page`-colored at alpha matching the
  screen's own backdrop opacity at offset 0 (top), fully transparent
  (`alpha = 0`) at offset 1 (bottom) — `fill = FILL_LINEAR`, vertical.
- Same `custom_minimum_size = Vector2(0, 96)` and
  `mouse_filter = Control.MOUSE_FILTER_IGNORE` as today, so nothing about
  its layout or click-passthrough changes — only what it looks like.
- No `theme_type_variation` — a gradient texture isn't a themed surface, so
  removing `SunkenPanel` here isn't a rule violation; it's not being
  themed at all, it's textured.

## 8. Audio

Fetching a new third-party SFX pack was raised and declined: downloading
files from an external, untrusted source is out of scope for an agent
session regardless of convenience. Instead, each new interaction gets its
**own** `AudioDirector` id and its **own** audio file — a byte-identical
copy of an existing cue under a new filename, not a second id pointing at
the same file. This is a step beyond the project's existing alias pattern
(`sfx_tally`/`sfx_sparkle`, which point a new export directly at an
existing file with no copy) — copying the file means these four new cues
can each be swapped for a genuinely distinct sound later without touching
whatever else in the project still uses the original cue:

| New id | New file (copy of) | Interaction |
|---|---|---|
| `pill_tap` | `pill_tap.ogg` (copy of `tap.ogg`) | Tapping a pill |
| `pill_popup_open` | `pill_popup_open.ogg` (copy of `popup_open.ogg`) | Pill info popup opens |
| `pill_popup_close` | `pill_popup_close.ogg` (copy of `popup_close.ogg`) | Pill info popup closes |
| `pane_swipe` | `pane_swipe.ogg` (copy of `swipe.ogg`) | SISWA↔RIWAYAT pane switch |

`AudioDirector.gd` gains four new `@export var sfx_<id>: AudioStream`
fields (each `preload()`-defaulted to its new file, matching the
`sfx_tally`/`sfx_sparkle` export style) and four new `&"<id>": return
sfx_<id>` branches in `play_sfx`'s lookup, each with a `##` doc line above
its export naming which screen/interaction it belongs to — same
documentation convention as every existing entry in that file.

The idle pill bounce (§3.2) stays deliberately silent — no id, no file, no
change from the design already agreed. If the project wants a genuinely
different *sound*, not just a different *file*, for any of the four above,
a human drops a real recording into `Assets/Audio/SFX/` under the same
filename and nothing else in the codebase needs to change — the id and the
call sites are already correct.

## 9. Testing

- **`tests/test_result_checkup.gd`** (extended): pill `gui_input` press/
  release/tap-cancel-on-drag-off; `pill_tapped` signal firing exactly once
  per clean tap; `WeekRecapBanner` opening the correct popup content per
  pill key; the idle-bounce tween existing and being killed on popup-open
  and on screen-close; the pane-transition direction sign for both switch
  directions; `ScrollFade` no longer carrying `theme_type_variation`.
- **New: a small popup test for `WeekRecapPillInfoPopup`** — `configure()`
  writes the right icon/title/body; `close()` is idempotent (matching
  `StatDetailPopup`'s own `_is_closing` guard test, if one exists — reuse
  that pattern).
- **`tests/test_day_summary.gd`** (extended): `DeltaChevron` visible+
  rotated 0° on a gain, visible+rotated 180° on a loss, hidden at exactly
  zero; `DeltaLabel` confirmed `visible = false` always (text still
  written, never rendered).
- Every suite `@tool`, no coroutine tests, per the project's hard
  constraints — animation-bearing production code (the tween-driven
  methods) is exercised only for its *setup* (signals connected, tweens
  created) in tests, never awaited.

## 10. Out of scope

- Any change to what the four pills compute (`WeekRecap.gd`) — this pass
  is presentation-only.
- A distinct pill-tap SFX beyond the reused `tap` cue (see §8).
- The `particle_glow.png` sprite wiring into `CelebrationConfetti` — still
  tracked from the prior spec, untouched here.
