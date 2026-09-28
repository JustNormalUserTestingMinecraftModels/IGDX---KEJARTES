# Atur Jadwal — "perlu" bug fix + visual need gauge (implementation plan)

**Branch:** `atur-jadwal-polishing-dan-bug-fix` (off `Textures`)
**Screen:** `Scenes/AturJadwal/AturJadwal.tscn` + `Scripts/AturJadwal/AturJadwal.gd`
**Status:** handoff — nothing here is built on this branch yet.

This plan is written to be picked up cold by another Claude/engineer. Read it
top to bottom once before editing anything. It follows the project's own rules
(`CLAUDE.md`, `docs/superpowers/design/*`): no `theme_override_*`, no visuals
built at runtime, every `@export`/script documented, tests are the quality
floor.

---

## Honesty notes (read first)

- A **tested reference implementation already exists** in another session on
  the `LobyFinalpolish` branch (uncommitted at the time of writing). It is not
  on this branch on purpose — you are meant to build from this plan. If you
  want to compare, ask the human for that diff; do not assume it is correct in
  every detail (see "Known gotcha" below, which is the one thing it got wrong
  first).
- The **logic fix is fully verified** (unit tests pass). The **visual half was
  only partially verified in-game** before hand-off: the gap tail and callout
  rendered correctly, and the target-dot positioning bug (below) was fixed in
  code but its fix was **not** re-confirmed on a running device. Treat the
  dot's runtime placement as the thing most worth eyeballing when you finish.
- The mockup the human approved is an **audit of intent, not a pixel spec**.
  Build to the design described here and to the project's tokens, not to the
  mockup's literal numbers.

---

## Part A — The bug: "perlu" always points to Akademis

### Symptom
On Atur Jadwal, the weak-stat "perlu" chip (and the objective hint
"<nama> butuh <pelajaran>") always names **Akademik**, never Seni Budaya or
Olahraga, regardless of the student.

### Root cause
`Scripts/AturJadwal/StatFlags.gd::flags_for()` flags the skill with the biggest
gap to its target (`target - current`). But `GameState.gd` (see
`_ensure_targets`/target init) builds every skill's target as
`base + one shared uplift` (`Balance.TARGET_KENAIKAN_KELAS_*`). At the start of
a grade `current == base`, so **all three skill gaps equal that same uplift** —
an exact three-way tie. The loop keeps the first entry it sees, and `_SKILLS`
lists `akademis` first, so Akademis wins every tie forever.

### Fix
Keep "biggest gap wins" as the primary rule, but break ties toward the
**weakest raw skill** (lowest current value). Add a small epsilon so
near-ties count as ties.

In `StatFlags.gd`:

- Add `const GAP_EPSILON := 0.5` with a `##` doc line explaining it.
- Rewrite the skill loop in `flags_for()` so it tracks `worst_gap` **and**
  `worst_current`, skips skills already at/above target (`gap <= 0.0`), and
  updates the winner when either the gap is clearly larger
  (`gap > worst_gap + GAP_EPSILON`) **or** it ties within epsilon and the raw
  value is lower (`absf(gap - worst_gap) <= GAP_EPSILON and current < worst_current`).

Do **not** change the needs (mood/energy) branch or restate any Balance
threshold.

### Tests (`tests/test_stat_flags.gd`)
Add two:
- `test_an_exact_gap_tie_flags_the_weakest_raw_skill` — three skills with
  identical gaps but different raw values; assert the lowest raw skill is
  flagged, **not** akademis.
- `test_a_clear_biggest_gap_wins_over_a_lower_raw_skill` — a genuinely larger
  gap on a higher raw skill still wins (tie-break must not override urgency).

Run: `test_run(suite="stat_flags")` — expect all green.

---

## Part B — The visual: a need gauge instead of a bare word

### Design (what the player sees)
The single most-needed skill (the same one `StatFlags` flags `perlu`) is shown
visually, not just as the word "perlu":

1. **Gap tail** — over the empty part of that skill's bar (from the fill's end
   to the bar's target end), a category-tinted ghost-track fill, so the
   distance left to target reads at a glance. Reuse
   `Assets/Images/UI/BarFill/track_ghost.png`, `self_modulate` = the category
   colour at ~0.5 alpha.
2. **Target dot** — a small round marker sitting on that bar's **target end**
   (its right edge), pulsing gently (grow/shrink loop), tinted to the category.
3. **Portrait callout** — a small speech bubble by the portrait voicing the
   need in first person, e.g. `Aku butuh Akademik!`, icon + text tinted to the
   category. Hidden when no skill is behind.

Needs (mood/energy) keep their existing text **"lelah"** chip — they are not
skills and do not get the gauge. Only **one** skill is ever gauged at a time.

Because each bar's `max` **is** its target (the bar shows `current/target`,
see `AturJadwal.gd::_percent`), the empty remainder already equals the gap and
the bar's right edge already equals the target — there is no separate "notch"
inside the bar. The value pill rides the fill end (existing behaviour), so the
target end is free for the dot.

Colours (from `Scripts/Design/DesignTokens.gd`, resolve via
`tokens.category_color(category)`): `cat_akademis #1F6FBA`,
`cat_senibudaya #3D7F12`, `cat_olahraga #E03A18`.

### B1 — Theme variations (`Scripts/Design/ThemeFactory.gd`)
Add a `_build_need_signal(theme, tokens)` builder, registered in `build()`
next to `_build_objective_strip`. It adds three **category-neutral** variations
(the screen tints each per bar with `self_modulate`, so one of each serves all
skills):

- `StatTargetDot` — a `Panel` variation whose `panel` stylebox is a white
  `StyleBoxFlat` with full corner radius (`tokens.radius_pill`), a cream rim
  (`tokens.outline_card`) and a small shadow. White so `self_modulate` tints
  it to the category.
- `NeedCalloutPanel` — a `PanelContainer` variation: cream bubble
  (`tokens.surface_card`), `tokens.radius_lg` corners, brown rim
  (`tokens.brand_primary`), small shadow, `space_xs` content margins.
- `NeedCalloutLabel` — a `Label` variation on the display face
  (`tokens.font_display`), `tokens.font_caption` size, `tokens.text_primary`.
  **Add `"NeedCalloutLabel"` to `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd`** or `test_display_font_roster_is_exact` fails.

After editing ThemeFactory, **rebake**: run `test_run(suite="theme_rebake")`
(it writes `Assets/Theme/kejartes_theme.tres`), or File > Run
`Scripts/Design/BakeTheme.gd`. Note: a `class_name` script edit is not always
hot-reloaded — if the rebake seems to use stale code, restart the editor, then
rebake. Confirm with `grep StatTargetDot Assets/Theme/kejartes_theme.tres`.

### B2 — Scene nodes (`AturJadwal.tscn`, via the editor — never hand-edit tscn)
On **each** of the three skill bars `BGStat/Akademis`, `BGStat/SeniBudaya`,
`BGStat/Olahraga` (they are `StatBar`), add two children:

- `GapTail` — `TextureRect`, `texture = track_ghost.png`,
  `expand_mode = IGNORE_SIZE` (so the script can size it freely — the texture's
  native width otherwise forces a min size), `stretch_mode = TILE`,
  `texture_repeat = ENABLED`, `mouse_filter = IGNORE`, `visible = false`,
  `self_modulate` = category colour at 0.5 alpha.
- `TargetDot` — `Panel`, `theme_type_variation = StatTargetDot`, ~22×22,
  `mouse_filter = IGNORE`, `visible = false`, `self_modulate` = category colour.

Under the scene root add the callout, near the portrait/name:

- `NeedCallout` — `PanelContainer`, `theme_type_variation = NeedCalloutPanel`,
  `mouse_filter = IGNORE`, `visible = false`, high `z_index` so it sits over the
  portrait art. Child `Row` (`HBoxContainer`, small `separation`) with
  `Icon` (`TextureRect`) + `Text` (`Label`, `theme_type_variation = NeedCalloutLabel`).

All new controls are `mouse_filter = IGNORE` (they never take a tap) — the
existing `test_each_stat_bar_is_embossed_with_a_pill_and_a_flag` pins this idea
for the bar's other children; keep it true for the new ones. Save the scene
**before** doing script work (a `scene_save` flushes open script tabs).

### B3 — Behaviour: extract into a `NeedGauge` unit
Put all of this in a new `Scripts/AturJadwal/NeedGauge.gd`
(`class_name NeedGauge extends RefCounted`, `@tool`, fully `##`-documented),
the same isolated-unit shape as `StatFlags`/`ObjectiveHint`. This keeps the
already-large `AturJadwal.gd` from growing (see "clean-code ratchet" below).

`NeedGauge` owns:
- `update(screen, flags, bars, tokens)` — the single entry point.
- the needs "lelah" chip logic (moved out of AturJadwal),
- the skill gap-marker logic,
- the callout logic,
- the looping tweens (chip nudge + dot pulse), created on `screen`
  (`screen.create_tween()`), off under `Engine.is_editor_hint()` and
  `GameSettings.reduce_motion`.

`AturJadwal.gd::_update_stat_flags(projected)` shrinks to: build the `bars`
dict and call `_need_gauge.update(self, StatFlags.flags_for(projected), bars, _get_tokens())`.
Move `_SKILL_CATEGORY`, the chip-nudge constants and helpers, and delete the
now-dead code from `AturJadwal.gd`. The callout word comes from
`DayStickyNote.DISPLAY_NAMES` (Akademis→"Akademik", SeniBudaya→"Seni Budaya",
Olahraga→"Atletik"); the callout icon can be copied from the bar's existing
`BGStat/Icon<Category>` `TextureRect`.

### ⚠ Known gotcha — the target dot must be seated from the bar's LIVE width
This is the one thing that broke first. In the editor a skill bar is ~324 px
wide; **at runtime, on a tall/wide phone (`aspect="expand"`, 1080×2400), the
layout stretches it to ~601 px.** If the `TargetDot` keeps an authored `x`, it
floats in the middle of the bar. The dot's resting position **must be derived
from the bar's live `size.x`**, not authored.

Do it in `Scripts/UI/StatBar.gd::layout_fill_followers()` — the same method
that already rides the value pill and the gloss on the fill, and which fires on
value change and on resize. Add, gated on the child existing and being visible:

- `GapTail` → `position = (fill_end, 0)`, `size = (max(0, size.x - fill_end), size.y)`.
- `TargetDot` → `position.x = size.x - dot.size.x/2` (straddle the target
  edge), vertically centred; set its `pivot_offset` to centre for the pulse.

`NeedGauge` then only toggles visibility/tint and calls
`bar.layout_fill_followers()` once so both land immediately; the resize/animation
signals keep them correct afterward. Gate the additions on
`child != null and child.visible` so bars on other screens (StudentCard,
ReportCard, StatCheck, Inventory) that have no such children pay nothing.

### B4 — Tests (`tests/test_atur_jadwal.gd`)
Add:
- each skill bar authors a hidden, tap-transparent `GapTail` (`TextureRect`)
  and `TargetDot` (`Panel`, variation `StatTargetDot`);
- `NeedCallout` exists, is a hidden tap-transparent `NeedCalloutPanel` with
  `Row/Icon` + `Row/Text` (`NeedCalloutLabel`);
- wiring: `AturJadwal.gd` contains `_need_gauge.update(`, and `NeedGauge.gd`
  contains the gap-marker and callout functions.
- The existing nudge test that greps `AturJadwal.gd` for `func _start_flag_nudge`
  must be repointed at `NeedGauge.gd` (that code moved).

---

## Constraints & gotchas (project rules that will bite)

- **No `Color(...)` literals in screen scripts.** `test_no_hardcoded_colors_remain_in_the_script`
  scans for them. To alpha a token colour, copy it and set `.a`, don't
  `Color(r,g,b,a)`.
- **Clean-code ratchet** (`tests/test_clean_code.gd`, baseline in
  `ci/clean_code_baseline.gd`): large scripts may not grow, and a shrink must
  lower the baseline (run `ci/clean_code_dump.gd` to regenerate). Extracting to
  `NeedGauge` keeps `AturJadwal.gd` at/below its baseline. Type every var in
  `NeedGauge` (the `untyped` measurement is ratcheted too — e.g.
  `var bar: StatBar = bars.get(...)`).
- **Viewport-editability ratchet** counts only `<VisualType>.new(` runtime
  construction. Setting `position`/`size`/`visible` on authored nodes does
  **not** count, so this plan adds nothing to that baseline. Do not build these
  nodes at runtime.
- **Editor/tscn hazards** (`CLAUDE.md` §"Working efficiently"): do scene work
  first then script work; after a `scene_save` check `git diff HEAD -- '*.gd'`
  for stray flushes; an override set on an *instanced sub-scene's child* is
  dropped on save (not relevant here — new nodes are plain children of the
  scene's own bars); a `class_name` edit may need an editor restart before it is
  picked up.
- Everything is **Indonesian** in UI text; systems code English. `## ` header
  on every script and `##` on every `@export` (`test_script_documentation`).

---

## Verification checklist
Targeted runs (fast, never drop the bridge):
- `test_run(suite="stat_flags")`
- `test_run(suite="atur_jadwal")`
- `test_run(suite="theme_factory")`
- `test_run(suite="clean_code")`
- `test_run(suite="script_documentation")`
- `test_run(suite="viewport_editability")`
- Spot-check StatBar consumers unaffected: `student_card`, `inventory`.

Then **see it running** (this is the step that catches the dot-width bug):
Debug overlay (F1) → General → ⚡ Seed Playtest State → Scenes → Atur Jadwal.
Confirm on the flagged skill: the pulsing dot sits at the bar's **target
(right) end**, the gap tail covers the remainder, the callout names the right
subject, and the flag now varies per student (not always Akademik). Judge at
full resolution.

Finish with the `ship-pr` skill.
