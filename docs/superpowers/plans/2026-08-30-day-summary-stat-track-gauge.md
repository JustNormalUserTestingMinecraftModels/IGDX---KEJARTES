# Daily Results Stat-Track Gauge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the three stat tracks on each Daily Results card read as real
gauges — filled to how close that student is to their target for that stat,
in that stat's category colour — instead of the flat dark rails they are now.

**Architecture:** Two independent defects produce the "empty bar" the director
reported, and this plan fixes both. First, `ThemeFactory` currently bakes
`DaySummaryStatTrack` with `day_stat_track` as **both** the background and the
fill colour, so the bar is visually identical at 0% and 100% — it can never
look filled. That is replaced by three per-category variations whose fills are
the existing `cat_akademis` / `cat_senibudaya` / `cat_olahraga` tokens. Second,
`DaySummaryStatRow.set_stat()` deliberately pins `track.value` to maximum and
documents the track as decorative; it instead receives the student's current
stat value and fills proportionally toward the target, clamped to 0–100.

**Tech Stack:** Godot 4.6, GDScript. `DesignTokens` → `ThemeFactory` →
`BakeTheme` theme pipeline. Tests are `McpTestSuite` suites run in-editor via
the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md`

> **Note on the spec.** The spec's surface table (rows 10–12) lists the three
> stat tracks with a fill column but **no fill row** — unlike the energy and
> mood bars, which have explicit fill rows (#7, #9). The mockup genuinely
> shows no visible fill on these tracks, which is why the original
> implementation documented them as decorative. This plan is a **deliberate
> director-approved departure** from that mockup, not a bug fix against it.
> Update the spec's surface table as part of Task 1 so the two do not drift.

## Global Constraints

- Godot **4.6**. Portrait 1080×1920 design space; the Daily Results mockup is
  1:1 with game pixels — **no rescale factor anywhere**.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. The
  only accepted exception is layout-only constant overrides (`separation`,
  `margin_*`). This is why per-category fill is done with three baked
  variations rather than by setting a StyleBox on the instance.
- After **any** change to `ThemeFactory.gd` or `design_tokens.tres`, rebake by
  running `Scripts/Design/BakeTheme.gd` from the Godot editor via **File > Run
  (Ctrl+Shift+X)**. The baked `Assets/Theme/kejartes_theme.tres` is what the
  game loads; an un-rebaked theme makes tests fail against stale styleboxes.
- Test suites must be `@tool`, and **no test may be a coroutine** — the runner
  calls `suite.call(name)` without awaiting, so an `await` silently aborts the
  test and it reports as "0 assertions".
- `McpTestSuite` has **no `assert_almost_eq`**. Compare floats with
  `assert_true(is_equal_approx(a, b), "...")`.
- **Rescan before running tests** after editing a `.gd` on disk:
  `filesystem_manage(op="scan")`, or `test_run` serves a stale script.
- Tunable numbers belong in a named `const` block or an `@export`, not inline.
- Game-facing identifiers and UI text are Indonesian; systems code is English.
- Commits use Conventional Commits with a scope, e.g. `feat(day-summary): ...`.

## Context an implementer needs

**What "+x/78" means, and why it is NOT changing.** The `+x` is the sum of that
stat's deltas for that one day; `78` is that student's target for the stat. The
director confirmed this is correct. `DaySummaryStudentRow._sum_deltas()` already
implements it, and `StudentManager.log_stat_change()` drops zero deltas at the
source, so a student who only rested legitimately shows `+0` on all three
skills. **No code in this plan changes the number.**

**Why the screenshot showed `+0/50` everywhere.** Two independent, expected
causes, neither a bug: (a) `StudentData.target_akademis1/2/3` all default to
`50.0`, so a roster with no targets assigned shows `/50` on every row; (b) the
debug **⚡ Seed Playtest State** does **not** fill `GameState.day_schedules`
(documented in CLAUDE.md), so a debug teleport straight into SchoolDay leaves
every student on auto-Izin — a forced Istirahat, which moves only mood and
energy. `_sum_deltas` filters mood/energy out, leaving `+0` on all three
skills. Task 3 verifies against a **properly scheduled** week for this reason.

**The naming trap.** `target_akademis2` is the **Seni Budaya** target and
`target_akademis3` the **Olahraga** one. `DaySummaryStudentRow.TARGET_FOR`
already encodes this and has a test guarding it. Do not "fix" it.

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scripts/Design/ThemeFactory.gd` | Bakes every theme variation from tokens | Modify: replace the one `DaySummaryStatTrack` bar-spec with three per-category ones |
| `Assets/Theme/kejartes_theme.tres` | The baked theme the game loads | Regenerated by BakeTheme — never hand-edited |
| `Scenes/SchoolSimulation/DaySummaryStatRow.tscn` | One icon+chevron+track+number row | Modify: `Track`'s default variation name |
| `Scripts/SchoolSimulation/DaySummaryStatRow.gd` | Formats the number, drives the track | Modify: gauge math + per-stat variation |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | One student's card | Modify: pass the current stat value through |
| `tests/test_day_summary.gd` | The suite for this screen | Modify: update the variation map, add gauge + fill-contrast tests |
| `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md` | The mockup spec | Modify: record the departure in the surface table |

No new files. `DesignTokens.gd` and `design_tokens.tres` are **not** touched —
the three category colours already exist as `cat_akademis` (`#3D8BFF`),
`cat_senibudaya` (`#7CB342`) and `cat_olahraga` (`#E5484D`).

---

### Task 1: Bake three per-category stat-track variations

The single `DaySummaryStatTrack` variation is the reason the bar cannot look
filled: its `background` and `fill` styleboxes are both `tokens.day_stat_track`.
Replacing it with three variations gives each row a visible, category-coloured
fill and lets the three rows be told apart the way their icons already do.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd:463-473` (the comment above `bar_specs` and the array itself; the old `DaySummaryStatTrack` entry is at line 471)
- Modify: `Scenes/SchoolSimulation/DaySummaryStatRow.tscn` (the `Track` node's `theme_type_variation`)
- Modify: `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md` (surface table)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DesignTokens.cat_akademis`, `.cat_senibudaya`, `.cat_olahraga`,
  `.day_stat_track`, `.day_bar_border`, `.day_glyph_outline`, `.radius_pill`
  — all already exist, none change.
- Produces: three baked theme type variations, each based on `ProgressBar`:
  `DaySummaryStatTrackAkademis`, `DaySummaryStatTrackSeniBudaya`,
  `DaySummaryStatTrackOlahraga`. The name `DaySummaryStatTrack` **ceases to
  exist**. Task 2 assigns these by name.

- [ ] **Step 1: Write the failing tests**

In `tests/test_day_summary.gd`, replace the `DaySummaryStatTrack` entry in the
existing `_DAY_VARIATIONS` const (around line 108) so the map reads:

```gdscript
const _DAY_VARIATIONS := {
	"DaySummaryName": "Label",
	"DaySummaryStat": "Label",
	"DaySummaryAvatarFrame": "Panel",
	"DaySummaryEnergyBar": "ProgressBar",
	"DaySummaryMoodBar": "ProgressBar",
	"DaySummaryStatTrackAkademis": "ProgressBar",
	"DaySummaryStatTrackSeniBudaya": "ProgressBar",
	"DaySummaryStatTrackOlahraga": "ProgressBar",
}
```

Then add these two tests immediately after the existing
`test_energy_and_mood_bars_differ_only_in_fill`:

```gdscript
## Which token each stat track fills with. The icons already tell the
## three rows apart by subject; the fills now agree with them.
const _STAT_TRACK_FILL_TOKEN := {
	"DaySummaryStatTrackAkademis": "cat_akademis",
	"DaySummaryStatTrackSeniBudaya": "cat_senibudaya",
	"DaySummaryStatTrackOlahraga": "cat_olahraga",
}


func test_each_stat_track_fills_in_its_category_colour() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := DesignTokens.load_default()
	for name in _STAT_TRACK_FILL_TOKEN:
		var bg := theme.get_stylebox("background", name) as StyleBoxFlat
		assert_not_null(bg, "%s has no background stylebox -- did you rebake?" % name)
		assert_eq(bg.bg_color, tokens.day_stat_track,
			"%s rail drifted off the mockup's stat-track colour" % name)
		var fill := theme.get_stylebox("fill", name) as StyleBoxFlat
		assert_not_null(fill, "%s has no fill stylebox -- did you rebake?" % name)
		assert_eq(fill.bg_color, tokens.get(_STAT_TRACK_FILL_TOKEN[name]),
			"%s fill is not its category colour" % name)


## The exact defect this change exists to fix: the old single
## DaySummaryStatTrack variation used day_stat_track for BOTH the
## background and the fill, so the bar looked identical at 0% and at
## 100% and read as permanently empty. If a fill ever equals its own
## rail again, the gauge is invisible no matter what value it holds.
func test_no_stat_track_fill_matches_its_own_rail() -> void:
	var theme := load(_THEME_PATH) as Theme
	for name in _STAT_TRACK_FILL_TOKEN:
		var bg := theme.get_stylebox("background", name) as StyleBoxFlat
		var fill := theme.get_stylebox("fill", name) as StyleBoxFlat
		assert_ne(fill.bg_color, bg.bg_color,
			"%s fill equals its rail -- the bar reads as empty at every value" % name)
```

- [ ] **Step 2: Run the tests to verify they fail**

Rescan first, then run the suite:

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: `test_theme_declares_every_day_summary_variation` FAILS with "theme
is missing variation DaySummaryStatTrackAkademis -- did you rebake?", and both
new tests FAIL (missing styleboxes / null).

- [ ] **Step 3: Replace the bar-spec entry in ThemeFactory**

In `Scripts/Design/ThemeFactory.gd`, change the `bar_specs` array. Replace the
single `DaySummaryStatTrack` line with three entries, and update the leading
comment. The loop below the array is unchanged — it already reads
`spec[1]` as the track colour, `spec[2]` as the fill and `spec[3]` as the radius.

```gdscript
	# The two needs bars and the three stat tracks are the same slab in
	# five flavours: same rim, same radius family, different fill.
	# The stat tracks share the mockup's dark rail and differ only in
	# fill, which carries the subject's category colour so the three
	# rows read apart at a glance the same way their icons do.
	# name, track color, fill color, radius
	var bar_specs := [
		["DaySummaryEnergyBar", tokens.day_bar_track,
			tokens.day_energy_fill, tokens.day_bar_radius],
		["DaySummaryMoodBar", tokens.day_bar_track,
			tokens.day_mood_fill, tokens.day_bar_radius],
		["DaySummaryStatTrackAkademis", tokens.day_stat_track,
			tokens.cat_akademis, tokens.radius_pill],
		["DaySummaryStatTrackSeniBudaya", tokens.day_stat_track,
			tokens.cat_senibudaya, tokens.radius_pill],
		["DaySummaryStatTrackOlahraga", tokens.day_stat_track,
			tokens.cat_olahraga, tokens.radius_pill],
	]
```

- [ ] **Step 4: Point the scene's Track at the akademis variation**

In `Scenes/SchoolSimulation/DaySummaryStatRow.tscn`, on the `Track` node,
change:

```
theme_type_variation = &"DaySummaryStatTrack"
```

to:

```
theme_type_variation = &"DaySummaryStatTrackAkademis"
```

Akademis is the correct default because `StatRow1` is the akademis row.
Task 2 reassigns this per stat at runtime, so rows 2 and 3 only wear it for
the instant between instantiation and `set_stat()`.

- [ ] **Step 5: Rebake the theme**

In the Godot editor, open `Scripts/Design/BakeTheme.gd` and run **File > Run
(Ctrl+Shift+X)**. Confirm the output panel prints `BakeTheme: wrote
res://Assets/Theme/kejartes_theme.tres`. If it does not, the theme is stale and
every following step will fail against old styleboxes.

- [ ] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: PASS, including `test_theme_declares_every_day_summary_variation`,
`test_each_stat_track_fills_in_its_category_colour` and
`test_no_stat_track_fill_matches_its_own_rail`.

One existing test will still FAIL at this point:
`test_stat_row_scene_wears_the_theme_and_has_no_overrides` asserts the old
name. Fix it now — in `tests/test_day_summary.gd` around line 251, change:

```gdscript
	assert_eq(track.theme_type_variation, &"DaySummaryStatTrackAkademis",
		"Track is not wearing a DaySummaryStatTrack* variation")
```

Re-run `test_run(suite="day_summary")` and confirm the whole suite is green.

- [ ] **Step 7: Record the departure in the spec**

In `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md`, in the
section 2 surface table, insert a row after `| 12 | Stat track 3 | ...` :

```markdown
| 12a | Stat track fill (×3) | #10–#12 | fills #10–#12 left-to-right @ current/target | per category: Akademis `#3D8BFF`, Seni Budaya `#7CB342`, Olahraga `#E5484D` | `#3D1E48`, 3px | pill |
```

And immediately below the table, add:

```markdown
> **Departure from the mockup (2026-08-30, director-approved).** The mockup
> draws these three tracks with no visible fill, and the first implementation
> honoured that by pinning the bar to full and documenting it as decorative.
> The director has since asked for them to be real gauges: **100% of the bar
> means the student is at the target set for that run.** Row 12a above
> supersedes the "no fill" reading of rows 10–12.
```

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres Scenes/SchoolSimulation/DaySummaryStatRow.tscn tests/test_day_summary.gd docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md
git commit -m "feat(day-summary): bake per-category fills for the three stat tracks"
```

---

### Task 2: Fill each track to the student's progress toward target

The row currently pins `track.value = track.max_value` and documents the track
as decorative. It instead takes the student's **current** value for that stat
and fills proportionally, so a full bar means "at target". The `+x` number is
untouched — it keeps meaning the day's gain.

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd`
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd:33-50` (`setup_row`)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: the three variations from Task 1, by exact name.
- Produces:
  - `DaySummaryStatRow.track_ratio(current: float, target: float) -> float`
    — static, returns 0.0–100.0, clamped, and returns `0.0` when
    `target <= 0.0` rather than dividing by zero.
  - `DaySummaryStatRow.TRACK_VARIATION_FOR: Dictionary` — stat key →
    `StringName` variation name.
  - `DaySummaryStatRow.set_stat(stat_key: String, delta: float, target: float,
    current: float) -> void` — **signature gains a fourth parameter.**
    `DaySummaryStudentRow.setup_row` is the only caller in the project.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_day_summary.gd`, after the existing
`test_stat_row_formats_a_loss_without_a_stray_plus`:

```gdscript
## The gauge contract the director set: a full bar means the student has
## reached the target for that stat this run. Floats are compared with
## is_equal_approx -- McpTestSuite has no assert_almost_eq, and
## 39.0/50.0*100.0 is not bit-exact.
func test_track_ratio_is_progress_toward_the_target() -> void:
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(39.0, 50.0), 78.0),
		"39 of a 50 target must read 78%")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(25.0, 50.0), 50.0),
		"half the target must read 50%")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(50.0, 50.0), 100.0),
		"at target must read a full bar")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(0.0, 78.0), 0.0),
		"a zeroed stat must read an empty bar")


## Every degenerate input a real roster can produce. StudentData's
## target_akademis1/2/3 all default to 50.0, but a row built with no
## student at all passes target 0.0 -- that must not divide by zero, and
## overshooting a target must not paint outside the rail.
func test_track_ratio_clamps_and_survives_a_missing_target() -> void:
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(65.0, 50.0), 100.0),
		"past the target must clamp to full, not overflow")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(30.0, 0.0), 0.0),
		"a zero target must return 0, not divide by zero")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(30.0, -10.0), 0.0),
		"a negative target must return 0")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(-5.0, 50.0), 0.0),
		"a negative stat must clamp to empty")


## The row must wear the variation matching its own stat, or all three
## bars come out akademis blue (the scene's default from Task 1).
func test_stat_row_wears_the_variation_for_its_stat() -> void:
	assert_eq(DaySummaryStatRow.TRACK_VARIATION_FOR["akademis"],
		&"DaySummaryStatTrackAkademis", "akademis track variation is wrong")
	assert_eq(DaySummaryStatRow.TRACK_VARIATION_FOR["seni_budaya"],
		&"DaySummaryStatTrackSeniBudaya", "seni_budaya track variation is wrong")
	assert_eq(DaySummaryStatRow.TRACK_VARIATION_FOR["olahraga"],
		&"DaySummaryStatTrackOlahraga", "olahraga track variation is wrong")


## set_stat is the whole point of this change, so exercise it on a live
## instance rather than only asserting the pure helper. The scene is
## added to the tree so its @onready vars resolve, and the baked theme is
## assigned explicitly -- ThemeDB's project-theme fallback does not
## populate under the editor's own root.
func test_set_stat_fills_the_track_and_leaves_the_number_alone() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.set_stat("olahraga", 6.0, 50.0, 39.0)

	assert_true(is_equal_approx(inst.track.value, 78.0),
		"track must fill to current/target, not sit at max")
	assert_eq(inst.value.text, "+6/50",
		"the number must still be the DAY'S GAIN over the target")
	assert_eq(inst.track.theme_type_variation, &"DaySummaryStatTrackOlahraga",
		"track must switch to its own stat's variation")
```

> Three notes on that last test, because it departs from this file's usual
> shape and the departure is deliberate:
>
> - **It must enter the tree.** `icon`, `track` and `value` on
>   `DaySummaryStatRow` are `@onready`, so they stay null until the node is
>   inside a tree. Every other stat-row test in this file uses a bare
>   `instantiate()` + `inst.free()` and only touches consts, which is why they
>   get away without it. This one calls `set_stat`, so it cannot.
> - **`track(inst)` is `McpTestSuite`'s own cleanup helper**
>   (`addons/godot_ai/testing/test_suite.gd:42`), which frees the node after
>   the test. It is the pattern `tests/test_school_day.gd` uses for
>   tree-attached scenes; this file has not needed it before. Do not confuse it
>   with the local `var track` inside
>   `test_stat_row_scene_wears_the_theme_and_has_no_overrides`, which shadows
>   the method name within that one function only.
> - `_STAT_ROW_SCENE` and `_THEME_PATH` are existing consts in this file — do
>   not redeclare them.

- [ ] **Step 2: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: the four new tests FAIL — `track_ratio` and `TRACK_VARIATION_FOR` do
not exist, and `set_stat` takes three arguments, not four.

- [ ] **Step 3: Implement the gauge in DaySummaryStatRow.gd**

In `Scripts/SchoolSimulation/DaySummaryStatRow.gd`, add the variation map
directly below the existing `ICON_FOR` const:

```gdscript
## Which baked variation each stat's track wears. The fills are the
## category colours, so the three rows read apart the way the icons do.
const TRACK_VARIATION_FOR := {
	"akademis": &"DaySummaryStatTrackAkademis",
	"seni_budaya": &"DaySummaryStatTrackSeniBudaya",
	"olahraga": &"DaySummaryStatTrackOlahraga",
}
```

Then add the static helper immediately after `format_value`:

```gdscript
## How full the track sits, 0-100. A full bar means the student has
## reached the target set for this run -- so this is the STANDING stat
## over its target, not the day's gain, which the number beside it
## already carries.
##
## A target of zero reaches this whenever a row is built with no
## StudentData; returning 0 there is what keeps it off a divide by zero.
static func track_ratio(current: float, target: float) -> float:
	if target <= 0.0:
		return 0.0
	return clampf(current / target * 100.0, 0.0, 100.0)
```

Finally replace the body of `set_stat` entirely:

```gdscript
func set_stat(stat_key: String, delta: float, target: float, current: float) -> void:
	if ICON_FOR.has(stat_key):
		icon.texture = load(ICON_FOR[stat_key])
	if TRACK_VARIATION_FOR.has(stat_key):
		track.theme_type_variation = TRACK_VARIATION_FOR[stat_key]
	value.text = format_value(delta, target)
	track.value = track_ratio(current, target)
```

Note the old three-line comment above `track.value = track.max_value` —
explaining that the track is decorative and stays full — must be **deleted**,
not left in place. It now describes the opposite of what the code does.

- [ ] **Step 4: Pass the current stat value from DaySummaryStudentRow.gd**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, in `setup_row`, replace
the stat loop:

```gdscript
	var deltas := _sum_deltas(changes)
	for i in STAT_ORDER.size():
		var key: String = STAT_ORDER[i]
		var target := 0.0
		var current := 0.0
		if student != null:
			target = float(student.get(TARGET_FOR[key]))
			# STAT_ORDER's keys are StudentData's own field names, so the
			# standing value reads straight off the resource -- it is only
			# the TARGET field names that carry the akademis2/3 naming trap.
			current = float(student.get(key))
		stat_rows[i].set_stat(key, deltas.get(key, 0.0), target, current)
```

- [ ] **Step 5: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="day_summary", verbose=true)
```

Expected: the whole `day_summary` suite PASSES, including all four new tests.

- [ ] **Step 6: Run the full suite for regressions**

```
test_run()
```

Expected: exactly **one** failure —
`audio_director / test_volumes_persist_across_a_fresh_director`, the
pre-existing coroutine issue in CLAUDE.md's Known Issues #1. Any other failure
is caused by this change and must be fixed before committing.

That known-broken test also dirties `Assets/Audio/default_bus_layout.tres` as a
side effect. Revert it so it does not ride along in the commit:

```bash
git checkout -- Assets/Audio/default_bus_layout.tres
```

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStatRow.gd Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_day_summary.gd
git commit -m "feat(day-summary): fill each stat track to the student's progress toward target"
```

---

### Task 3: Verify on a real scheduled week in the running game

Every test in Tasks 1–2 is either a pure function or a stylebox lookup. None of
them prove the popup actually renders three visibly different, partially-filled
bars on a real card. This task is the only step that does, and it is the reason
the plan is not finished at Task 2.

**Files:** none — verification only.

**Interfaces:** none.

- [ ] **Step 1: Reach the Daily Results popup with real schedule data**

Do **not** teleport straight to SchoolDay. The debug seed does not fill
`GameState.day_schedules`, so every student auto-takes Izin and all three
deltas come out `+0` — the exact misleading state from the original bug report.

1. Run the project (`project_run`, or F5 in the editor).
2. Open the debug overlay (`F1`, or five taps in the top-right corner).
3. General tab → **⚡ Seed Playtest State**.
4. Scenes tab → teleport to **Lobby**.
5. Go through **Atur Jadwal** and assign each student a real activity for
   Monday — pick `Akademis` for one, `SeniBudaya` for another and `Olahraga`
   for a third, so all three bar colours appear on the same screen.
6. Start the week and let Monday simulate to the Daily Results popup.

- [ ] **Step 2: Screenshot and check the five things that can still be wrong**

Take one `editor_screenshot` of the popup and confirm, per card:

1. Each of the three tracks shows a **partial** fill — not empty, not full,
   unless that student genuinely sits at or past the target for that stat.
2. Row 1 fills **blue**, row 2 **green**, row 3 **red**. If all three are
   blue, `set_stat` is not reassigning `theme_type_variation`.
3. The fill starts at the track's **left** edge and has the dark
   `#3D1E48` rim, matching the energy and mood bars beside it.
4. The `+x/T` number to the right of each track is **unchanged** and still
   reads the day's gain — a student scheduled `Akademis` should show a
   positive `+x` on row 1 specifically.
5. The fill does not paint over the white stat icon or the gold chevron,
   which sit on top of the track's left end.

- [ ] **Step 3: Confirm the at-target and over-target cases clamp**

Still in the debug overlay, Students tab: raise one student's Akademis above
their `target_akademis1` (the stat editors are on that tab). Simulate another
day and confirm that student's akademis bar renders **completely full and
flush with the rail's right edge** — not overflowing past it, and not wrapping.

- [ ] **Step 4: Report the result**

Report to the director with the screenshot. If any of the five checks in Step 2
fails, that is a real defect in Tasks 1–2 — fix it and re-run
`test_run(suite="day_summary")` before reporting success. Do not report this
plan complete on the strength of the test suite alone.

---

## Self-Review

**Spec coverage.** The director's request had two halves. *"the +x sections is
the any point gained for the stats for that day"* — verified as already correct
(`_sum_deltas` + `log_stat_change`); no code change, and Task 2 Step 1 pins it
with an explicit assertion that `set_stat` leaves the number alone, plus Task 3
Step 2 check 4 confirms it live. *"fill the progress bar next to it as it still
empty right now"* — Task 1 fixes the invisible fill colour, Task 2 fixes the
pinned value, Task 3 confirms both on screen. The director's clarification
*"100% of the bar is how close the student to the target set for that run"* is
the contract encoded in `track_ratio` and asserted at 39/50→78%, 50/50→100%.
The colour choice (per-category) is Task 1's `_STAT_TRACK_FILL_TOKEN` map.

**Placeholder scan.** No TBDs, no "add error handling", no "similar to Task N".
Every code step carries the literal code. The one degenerate case that could
have hidden behind "handle edge cases" — `target <= 0.0` — is named, given a
reason (rows built with no `StudentData`), and has its own test.

**Type consistency.** `track_ratio(current, target)` is defined in Task 2 Step 3
and called with that argument order in Task 2 Step 1's tests and inside
`set_stat`. `set_stat(stat_key, delta, target, current)` is defined in Task 2
Step 3 and called with that order in Task 2 Step 4 and in the Step 1 test. The
three variation names are spelled identically in Task 1 Step 1's
`_DAY_VARIATIONS`, Task 1 Step 1's `_STAT_TRACK_FILL_TOKEN`, Task 1 Step 3's
`bar_specs`, Task 1 Step 6's scene assertion, and Task 2 Step 3's
`TRACK_VARIATION_FOR` — note `SeniBudaya` (no underscore) in the variation name
versus `seni_budaya` (underscore) as the stat key, which is correct: the former
follows the theme's PascalCase, the latter is `StudentData`'s field name.

**One deliberate omission.** The fill is set directly rather than animated with
`Juice.fill_bar`, matching the energy and mood bars on the same card, which are
also set directly. Animating all five together would be a consistent follow-up,
but animating only the three new ones would make the card inconsistent with
itself — so it is out of scope here rather than half-done.
