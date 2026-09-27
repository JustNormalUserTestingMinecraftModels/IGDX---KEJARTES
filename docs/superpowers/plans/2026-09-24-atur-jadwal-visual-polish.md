# AturJadwal visual polish — implementation plan

**Status:** done -- all five phases shipped on `feat/atur-jadwal-sticky-notes` (see CHANGELOG 2026-09-24)
**Author:** design pass (brainstormed 2026-09-24), for handoff to another Claude
**Scope:** the AturJadwal screen (`Scenes/AturJadwal/atur_jadwal.tscn`) and its
Penjadwalan activity picker. Character animation is **deferred to its own
spec** (see "Out of scope").

This document is self-contained: you should be able to execute it without the
original chat. Read `CLAUDE.md` first (especially `## Visual system`,
`## Testing`, `## Working efficiently here`). Every rule there applies —
**no `theme_override_*`**, use `ThemeFactory` type variations and rebake; no
visuals built at runtime; `@tool` suites; edit `.tscn` through the editor MCP,
never by hand while attached.

---

## Why this work exists

The scheduling screen is functional but reads as unpolished, and its best
mechanic is invisible. Concretely, from playtest feedback:

1. **Sticky-note day cards** flood the whole note with a saturated category
   colour, so dark text sits on red/green/purple at failing contrast, and the
   notes scatter at random angles that break the Senin→Jumat reading order.
2. **Stat bars** look like placeholders — the number pill floats at a
   value-dependent position, the fill isn't visually seated in the track, and
   nothing frames them.
3. **No objective is surfaced.** The player sees stats and days but is never
   told the week's goal or which student needs what, so scheduling is blind.
4. **The activity picker** opens with no header and shows bare numbers
   (`+6`, `+3`, `+120~320`). The `+6`-vs-`+3` difference is the specialty
   bonus — a genuinely deep trait mechanic — shown with zero explanation. The
   `~` ranges read as vague. Libur is icon+number soup.

None of this is a logic bug. It is a legibility and transparency pass.

---

## Locked design decisions

These were decided during brainstorming. Where a smaller choice was left to
implementation, the **default** is given — change only with reason.

- **D1 — Sticky notes stay sticky notes.** Keep the paper metaphor, the folded
  corner, the tape, the gentle tilt. Fix readability by moving category colour
  OFF the paper. (Mentor-approved constraint: do not replace the sticky-note
  look with flat cards.)
- **D2 — Paper is cream with a subtle vertical gradient** (light top → warmer
  bottom), never a saturated slab. Category colour lives on a **washi-tape
  strip** across the top of each note.
- **D3 — Aligned staggered grid.** Consistent note size, uniform gentle tilt
  (±2°), laid out so the week scans top-to-bottom. No random scatter.
- **D4 — Empty days invite a tap** — a faint breathing pulse + `＋ Atur`
  affordance. Filled days sit calm.
- **D5 — Stat bars: embossed rim (Option A).** An outer light-toned frame
  around the dark track, inner shadow on the track, 1px highlight on the fill —
  three layers of depth. NOT a panel behind the whole cluster (rejected as too
  crowded).
- **D6 — Stat number is a floating pill** riding the end of the fill, outlined
  in the stat's colour. (Kept deliberately over a fixed column — the player
  liked the floating pill.)
- **D7 — Weak-stat flags.** A skill below its target shows a gently-nudging
  `perlu` chip; low energy/mood shows a `lelah` chip. Healthy stats show
  nothing. **Default:** flag every weak stat; if the top section reads crowded
  in-engine, fall back to flagging only the single most-urgent need.
- **D8 — Objective strip replaces the `AGUSTUS — MINGGU PERTAMA` text** in the
  board header. Gradient brown (`#8A5A32 → #5C3A22` diagonal) with gold-gradient
  accents — not flat single-brown. Centered title + gold star chip + a slim
  always-visible progress bar; **tap to expand** a one-line plain-language hint.
  (Hybrid of the "tap-to-expand" and "progress-only" options.)
- **D9 — Picker becomes a tile-grid selection box**, not a list of rows. Clean
  cream **paper sheet** container with a **soft tan header band** (sleek, no
  heavy wood frame). 2-column grid; Libur spans full width.
- **D10 — Picker tiles use the watermark style (Style 3):** a large faded
  category icon behind crisp foreground text. The favorit tile carries a gold
  `⭐ Favorit` ribbon.
- **D11 — Arrow language on every tile.** Green ↑ = gain/recovery, red ↓ =
  cost. Arrow count encodes magnitude (favorit `↑↑↑`, normal `↑`). A one-line
  legend under the grid teaches the code. **Default:** show arrows **plus the
  exact number** on skill tiles (`Akademik ↑↑↑ +6`) — fast read and precision.
- **D12 — No raw ranges.** Wirausaha earnings → coin pips + `Cuan` (magnitude
  tier), cost `energi ↓↓`. Libur → `energi ↑↑ · mood ↑`. Money's `~120-320`
  range is not shown as a range.
- **D13 — Selection then confirm.** Tapping a tile selects it (gold ring +
  check badge, one at a time); a **Batal / Pilih** button pair at the bottom
  confirms or cancels. `Pilih` is dimmed until a tile is selected and then
  labels itself (`Pilih Akademik`). **Default:** no separate X corner —
  Batal + tap-outside-the-sheet is enough.
- **D14 — Favorit is self-teaching.** Selecting the favorit tile expands a
  small breakdown: `Dasar +3 / Bonus favorit +3 / Total +6 · energi lebih
  hemat`.
- **D15 — Assign feedback: single consistent celebratory particle colour**
  (not category-coloured), plus the existing squash-pop.

---

## What already exists (do not rebuild)

The codebase is further along than a first look suggests. **Extend these, don't
replace them:**

- `Scripts/AturJadwal/DayStickyNote.gd` (+ `.tscn`) — the day note is already a
  paper `TextureButton` with day/subject/flavour labels, a peeking category
  icon (`BackIcon`), a holiday lock, an assign-pop (`play_assign_pop`), and a
  full specialty-match reaction (`play_specialty_match`: gold burst + glow +
  star). It currently tints the **whole paper** with `category_color(category)`
  in `_apply()` — that is the saturated-slab we're replacing (D2). It already
  has a `FLAVOR_WORDS` map and per-instance icon `@export`s.
- `Scripts/UI/StatBar.gd` — animated `ProgressBar` with per-category theme
  variations (`StatBar*`, `StatPill*`, `StatBar*Light` families), `set_stat()`
  with `Juice.fill_bar` + `Juice.count_up` + optional `squash_bounce`, and an
  adopted-or-created `ValueLabel`. The **animated sweep and count-up already
  exist** — D5/D6 are a styling change (new StyleBoxes + pill placement), not
  new animation.
- `Scripts/AturJadwal/ActivityRow.gd` (+ `.tscn`) — one picker row: a Button
  with icon, name, a track holding either a `StatBar` (skill rows) or a ghost
  track with chips (Wirausaha/Libur), a `watermark_texture` `@export`, and a
  `SpecialtyBadge` `TextureRect` (**the favorit indicator already exists**).
  Chips come from `ActivityPreview`. This is the row we are restructuring into
  a tile (D9/D10) — the watermark and specialty-badge plumbing carries over.
- `Scripts/AturJadwal/ActivityPreview.gd` — **all preview numbers, read from
  `Balance.gd`**, as pure static functions. `chips_for()` returns
  `{icon, text}` entries; `is_specialty()` answers the favorit question;
  `skill_gain()` returns `base (+ bonus if specialty)`. This is where the
  arrow-magnitude logic (D11/D12) belongs — derive arrow counts from these
  Balance-backed numbers, never hardcode them.
- `Scripts/Design/ThemeFactory.gd` (+ `Assets/Theme/design_tokens.tres`) — all
  colour/StyleBox variations. New looks go here as variations, then **rebake**
  (`Scripts/Design/BakeTheme.gd` via File > Run).
- `RewardFeedback` autoload (merged 2026-09-23) + `AnimUtils.gd` +
  `Scripts/Design/Juice.gd` — the feedback/motion vocabulary. Assign bursts
  route through these, not a new system.
- `Scripts/EndGame/RunGrade.gd` / `GameState.run_stars()` — the star target and
  current progress for the objective strip (D8).

**Existing tests you must keep green (and extend):**
`tests/test_day_sticky_note.gd`, `tests/test_activity_row.gd`,
`tests/test_activity_preview.gd`, `tests/test_atur_jadwal.gd`,
`tests/test_bar_contrast.gd`, `tests/test_ghost_track.gd`,
`tests/test_stat_info.gd`, `tests/test_theme_factory.gd`,
`tests/test_viewport_editability.gd`, `tests/test_tall_screen_layout.gd`.

Note `test_viewport_editability.gd`'s BASELINE/ALLOWED ratchet:
`ActivityRow.gd` already sits at 2 ALLOWED (per-call dynamic chips). Adding a
third runtime-construction site raises the ratchet — prefer scene nodes /
`PackedScene` templates over building chips in code where you can.

---

## Phased implementation

Each phase is independently shippable and testable. Do them in order —
later phases assume earlier theme variations exist. Follow TDD where the
change is behavioural (arrow logic, weak-stat detection, objective data);
follow the established **source-scan** test pattern for pure visual/structural
assertions (see `CLAUDE.md` `## Testing`).

After each phase: run the **targeted** suite(s) for that phase
(`test_run(suite=...)`), not the full suite (full runs drop the bridge — see
`CLAUDE.md`). Take a full run only at the milestones marked ★.

### Phase 1 — Sticky-note day cards (D1–D4)

**Files:** `Scenes/AturJadwal/DayStickyNote.tscn`, `Scripts/AturJadwal/DayStickyNote.gd`,
`ThemeFactory.gd`, `design_tokens.tres`, `atur_jadwal.tscn` (grid layout),
new washi-tape asset(s).

1. Add a **WashiTape** node to `DayStickyNote.tscn` (a `NinePatchRect` or
   `TextureRect` strip across the top). Its `self_modulate` is the category
   colour; the paper is NOT tinted.
2. Change `_apply()`: the paper keeps a **cream** base (new token, e.g.
   `surface_paper`) with a subtle vertical gradient StyleBox instead of
   `self_modulate = category_color(category)`. Move the category colour to the
   tape node. Empty/holiday states adjust the tape (hidden when empty; gold
   when holiday) rather than the paper.
3. Empty-day affordance (D4): a breathing pulse tween on empty notes + the
   `＋ Atur` label. Gate the tween behind `Engine.is_editor_hint()` per the
   `@tool` rule. Keep it subtle (±1° / ~1.04 scale) — do not port the
   exaggerated demo motion.
4. In `atur_jadwal.tscn`, lay the five notes on an **aligned grid** (uniform
   ±2° tilt, equal size) rather than scattered positions. Respect
   `test_tall_screen_layout.gd` (re-anchor to `SafeAreaMargin → UI`).
5. Contrast: verify the day/subject/flavour text passes on the cream paper.
   `paper.png`'s opaque region matters — see `docs/superpowers/DEBT.md` and the
   memory note on `paper.png`; lay text inside the real opaque area.

**Tests:** extend `test_day_sticky_note.gd` — assert the tape node exists and
carries the category colour, the paper stays cream (untinted) across states,
the empty state shows the affordance, and the holiday state locks. Add/adjust a
contrast assertion if `test_bar_contrast.gd`'s helper is reusable for the note
text.

### Phase 2 — Stat bars: rim, pill, flags (D5–D7) ★ full run after

**Files:** `ThemeFactory.gd`, `design_tokens.tres`, `Scripts/UI/StatBar.gd`
(pill placement), `atur_jadwal.tscn` (bar container + flag nodes),
possibly a new `StatFlag` template scene.

1. **Embossed rim (D5):** add a framing StyleBox — a light-toned outer frame
   with an inner shadow on the track and a 1px fill highlight. Do this as new
   `ThemeFactory` variations on the existing `StatBar*` families (or a wrapping
   `Panel` variation), then rebake. **Must still pass `test_bar_contrast.gd`
   (luminance floor) and `test_ghost_track.gd`** — the fill/track move into a
   new container.
2. **Floating pill (D6):** the value label rides the end of the fill in a
   colour-outlined pill, rather than centered. This is a placement change to
   how `ValueLabel` is positioned (anchored to fill width). Keep the existing
   `set_stat()` animation; the pill's position tweens with the fill.
3. **Weak-stat flags (D7):** a `perlu` / `lelah` chip beside a bar. New logic:
   a skill is weak if below its grade target (derive from `RunGrade` /
   `Balance`); energy/mood weak if below the Izin/low threshold (`Balance`).
   Build the chip as a scene node / template, not runtime construction, to
   avoid raising the editability ratchet. Nudge animation gated behind
   `is_editor_hint()`.

**Tests (TDD for the logic):** new assertions that weak-stat detection fires at
the right thresholds (drive it off `Balance` values so it tracks tuning). Scan
`atur_jadwal.tscn` for the rim variation + flag nodes. Keep `test_bar_contrast`
/ `test_ghost_track` green. Update `test_theme_factory.gd` if you add
variations (its `DISPLAY_ROSTER` pins font↔variation).

### Phase 3 — Objective strip (D8) ★ needs real data

**Files:** `atur_jadwal.tscn` (replace the month header), `atur_jadwal.gd`
(populate + expand toggle), `ThemeFactory.gd` (gradient strip + gold chip
variations), `design_tokens.tres`.

1. Replace the `AGUSTUS — MINGGU PERTAMA` label with the strip: gradient
   background (D8), centered `Bulan · Minggu N/Total`, a gold star chip showing
   `run_stars()` vs the grade target, a slim always-visible progress bar, and a
   chevron.
2. Tap-to-expand: a collapsible panel with the plain-language hint. Compose the
   hint from real data — the selected student's weakest skill + an energy/mood
   warning ("Marcel butuh Akademik — jaga energi biar tidak Izin"). Pull the
   month/week/total from `GameState` (grade → weeks table in `CLAUDE.md`), stars
   from `GameState.run_stars()` and the target from `RunGrade`.
3. Gradient must not be flat single-brown (explicit playtest note). Gold accents
   via gradient StyleBox tokens.

**Tests:** extend `test_atur_jadwal.gd` — assert the strip replaced the month
label, the star/target read from the right source (source-scan the wiring), and
the expand toggle exists. Verify tall-screen layout still holds.

### Phase 4 — Picker selection box (D9–D14) ★ largest phase

This restructures the Penjadwalan popup from a **list of `ActivityRow` buttons**
into a **tile-grid selection box**. Carry over the `watermark_texture` and
`SpecialtyBadge` plumbing; change the layout, the value language, and the
commit flow.

**Files:** `atur_jadwal.tscn` (the popup subtree), `atur_jadwal.gd` (open/
select/confirm/cancel flow), `ActivityRow.gd` → likely renamed/reshaped into an
`ActivityTile` (or heavily edited in place), `ActivityPreview.gd` (arrow
helpers), `ThemeFactory.gd`, `design_tokens.tres`.

1. **Container (D9):** cream paper sheet + soft tan header band
   (`Selasa mau ngapain?` + subtitle). Dim scrim behind; tap-scrim cancels.
2. **Tiles (D10):** 2-col grid, watermark icon behind foreground text, Libur
   full-width. **Watermark must render BEHIND the labels** — give the label
   content its own node above the watermark in the tree (the mockup hit exactly
   this z-order bug; in Godot it's tree order / a sub-Control). The
   `SpecialtyBadge` becomes the gold `⭐ Favorit` ribbon.
3. **Arrow language (D11/D12) — behavioural, TDD this:** add helpers to
   `ActivityPreview.gd` that turn the Balance-backed numbers into arrow counts:
   e.g. `gain_arrows(category, student, grade) -> int` (specialty → more),
   `energy_cost_arrows` / `mood_cost_arrows`, and a magnitude tier for
   Wirausaha earnings (the coin pips). Keep the exact number available too
   (D11 default: `↑↑↑ +6`). **No literals in `ActivityPreview` — thresholds
   come from `Balance`.** Libur/Wirausaha show arrows, never `~` ranges.
4. **Selection + confirm (D13):** tap selects (gold ring + check, single
   selection); `Batal` / `Pilih` buttons; `Pilih` dimmed until selection, then
   labelled `Pilih <name>`. Assigning the day happens on `Pilih`, not on tile
   tap. (This changes the current tap-to-assign-immediately flow — update
   `atur_jadwal.gd`'s row-pressed handler accordingly, and the assign-pop /
   specialty-match call site moves to the confirm handler.)
5. **Favorit breakdown (D14):** selecting the favorit tile expands the
   `Dasar / Bonus favorit / Total` panel, values from `ActivityPreview`.

**Tests:** extend `test_activity_preview.gd` (arrow helpers: specialty yields
more up-arrows than base; costs map to the right arrow counts; equal-bound
ranges don't appear as ranges). Extend `test_activity_row.gd` (or new
`test_activity_tile.gd`) for the tile structure, favorit ribbon, watermark
z-order, and the select/confirm state. Update `test_atur_jadwal.gd` for the new
popup flow. Mind the editability ratchet — prefer template scenes over runtime
chip construction.

### Phase 5 — Motion & feedback polish (D4/D15) ★ full run after

**Files:** `atur_jadwal.gd`, `DayStickyNote.gd`, `ThemeFactory`/scene for the
button, `RewardFeedback` wiring.

1. **Assign burst = single consistent colour (D15).** The existing
   `play_specialty_match` gold burst stays for favorit; the ordinary assign
   burst uses one celebratory colour (not per-category). Route through
   `RewardFeedback` / the existing burst scene.
2. **Stagger-in on open:** notes `stagger_in`, stat rows via the existing
   `_stagger_stat_rows()`. Objective strip and picker fade/pop in.
3. **Button press feedback** on MULAI MINGGU and the picker's Pilih (press +
   firmer burst on the commit). `UIPolish` already auto-juices buttons; add the
   burst on the commit actions only.
4. Keep all motion subtle on a real phone; gate tweens behind
   `is_editor_hint()`.

**Tests:** mostly source-scans that the wiring exists (feedback calls present,
stagger invoked). Behavioural motion isn't unit-testable headlessly here.

---

## Out of scope — deferred to its own spec

**Character (MARCEL) animation.** Idle breathing, a periodic cute
attention-bounce (so he reads as tappable), tap-to-react, and mood-reactive
pose/expression. This is **art-blocked** (needs new pose/expression states and
a dialogue/emote hook) and is deliberately split so Phases 1–5 can ship without
waiting on art. Write it as
`docs/superpowers/specs/2026-09-24-atur-jadwal-character-life-design.md` when
art direction is ready. It layers on top of this work and shares the
`AnimUtils` / `Juice` vocabulary; nothing in Phases 1–5 depends on it.

---

## Open decisions (defaults chosen; flip with reason)

- **D7** flag density — all weak stats (default) vs only the most urgent.
- **D11** skill tiles — arrows + number (default) vs arrows only.
- **D13** confirm label — `Pilih <name>` (default) vs plain `Pilih`; no X
  corner (default) vs add one.
- Watermark opacity — start at ~13%, tune in-engine at full-size screenshot.

## Verification checklist

- [ ] Targeted suite green after each phase; ★ full run at the marked
      milestones (budget one editor restart per full run).
- [ ] `git status` clean of unintended `kejartes_theme.tres` /
      `default_bus_layout.tres` churn after full runs (see `CLAUDE.md`).
- [ ] No `theme_override_*` added; all new looks are `ThemeFactory` variations,
      rebaked.
- [ ] No new runtime-built visuals beyond what the editability ratchet allows;
      `test_viewport_editability.gd` not raised without a reasoned ALLOWED entry.
- [ ] `test_bar_contrast` / `test_ghost_track` still pass after the bar rim.
- [ ] Tall-screen layout holds (`test_tall_screen_layout.gd`).
- [ ] Full-size screenshots of: filled board, empty board, objective expanded,
      picker with a favorit selected, picker with Libur selected.
- [ ] Ship the branch with the `ship-pr` skill (`CLAUDE.md` `## Pull requests`).

## Progress and handoff (2026-09-24)

Phases 1-3 are done on branch `feat/atur-jadwal-sticky-notes` (pushed, no PR
yet; the owner wants all five phases shipped as ONE PR to avoid conflicts).
Continue Phases 4 and 5 on that same branch, then ship with `ship-pr`.

**Done:** Phase 1 (`ea86092`, `73bef50`), Phase 2 (`bf21318`), Phase 3
(`21934e3`). Targeted suites green after each; the last full run was 2203/2203
after Phase 1, so take a full run before shipping.

**Decisions taken that differ from the plan text:**
- Sticky notes: uniform -2 degree tilt (each instance +1.5 on the art's baked
  -3.5); "+ Atur" uses ASCII "+", not "＋". The screen's perpetual random
  sway was removed (it caused the scatter). Note lines stack in a
  `Paper/Lines` VBox so a long holiday title wraps clear.
- D7: only the single most urgent skill is flagged "perlu" (every skill is
  below target early in a grade), plus "lelah" for needs under
  `Balance.BATAS_KELELAHAN`. Logic in `Scripts/AturJadwal/StatFlags.gd`.
- D8: title separator is a plain hyphen. Logic in `ObjectiveHint.gd`.
- Found and fixed: the mood and energy rows were fed each other's values.

**Measured facts Phase 4 must respect:**
- **No arrow glyphs exist in any of our fonts.** Boohong (display) and Open
  Sans (body, bold) all lack ↑ and ↓; Boohong also lacks "·" and "—". D11's
  arrows must be SVG textures (TextureRects), not text. Pin any display-face
  text with a `has_char` test like `test_objective_hint.gd`'s.
- The picker only has the student *dictionary*; the cost multiplier lives on
  `StudentData`, so an arrow helper must mirror it from
  `Balance.BIAYA_KALAU_*` (favourite / "Seimbang" / otherwise; study only).
- `ActivityPreview`'s literal scan rejects float literals only; an int
  display constant (e.g. `MAX_ARROWS := 3`) passes.
- Nine suites pin the current row picker (ActivityRow): test_activity_row,
  test_atur_jadwal (about 20 references, incl. the touch-target path list),
  test_atur_jadwal_specialty_feedback, test_back_controls,
  test_cream_panel_tokens, test_day_sticky_note (DISPLAY_NAMES synced with
  the row wording), test_ghost_track, test_viewport_editability (ActivityRow
  sits in ALLOWED), test_wirausaha. Read each before deleting ActivityRow.

**Phases 4 and 5 (done, same day).** Decisions that differ from the text:
- The picker lost its back arrow for Batal / Pilih, both S-step buttons.
  Batal is a plain `SecondaryButton`, which the lobby-style-buttons rule
  draws in the same brown as Pilih (only StudentCard may use the cream
  secondary); Pilih stays distinct by being dimmed until a tile is chosen
  and then naming it. The tile has a reviewed `test_button_geometry`
  height exemption: it is a card, not an action button.
- The D14 breakdown is not a separate expanding panel: the note line under
  the grid always holds a line for the current selection, and for the
  favourite it is the breakdown (and pops). A fixed slot, so the sheet never
  jumps.
- Arrow counts: gain is 1 for a plain day and `1 + ceil(bonus / base * 2)`
  for the favourite. A cost is its middle-of-range size over the biggest
  one-day swing Balance allows, times 3, rounded and clamped 1-3. Coin pips
  measure a typical day's earnings against the best day.
- The plain assign burst reuses RewardBurst (the Pop tier's) instead of a new
  scene: one colour for every category, as D15 asks.

**Working notes:** the Godot bridge drops after every full run; restart the
editor. A spurious "(*)" on loby.tscn after a restart held no real changes
(packed and diffed). Rebake via `test_run(suite="theme_rebake")`, then
restart before any scene save.

## Suggested branch / commit shape

One branch, commits per phase, Conventional Commits with scope, e.g.
`feat(atur-jadwal): move day-note colour to washi tape, cream the paper`,
`feat(atur-jadwal): emboss stat bars and float the value pill`,
`feat(atur-jadwal): surface the week objective in the board header`,
`feat(atur-jadwal): rebuild the activity picker as an arrow selection box`,
`feat(atur-jadwal): single-colour assign burst and stagger-in`.
