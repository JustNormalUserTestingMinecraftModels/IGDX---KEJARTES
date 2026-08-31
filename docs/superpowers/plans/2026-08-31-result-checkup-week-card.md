# ResultCheckup Week Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the end-of-week report (`ResultCheckup`) on the Daily Results
card art, with each stat reading `+<week's gain>/<target>` and each needs bar
carrying the week's energy/mood movement as a signed number.

**Architecture:** The Daily Results card (`DaySummaryStudentRow.tscn`) already
draws exactly this layout — avatar, name, two needs bars, three
icon+chevron+track+number stat rows — and its stat row already accepts
`(stat_key, delta, target, current)` and rewinds its track to
`(current − delta) / target`. So the week card is the *same scene* driven by a
different delta source: `StudentData.get_*_delta()`, which measures from the
week-start snapshot `record_initial_stats()` takes when `GameState` converts the
roster. The card gains a second entry point (`setup_week_row`) and two
needs-delta labels that stay hidden on the daily path; `ResultCheckup` throws
away its hand-built five-`StatBar` panel and instantiates the card instead.

**Tech Stack:** Godot 4.6, GDScript. Baked theme + `ThemeFactory` type
variations (`DaySummaryStat`, `DaySummaryEnergyBar`, `DaySummaryMoodBar`,
`DaySummaryStatTrack*`). `Juice` for all motion. `McpTestSuite` tests run
in-editor via the `godot-ai` MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md` — the
card's design authority (surface table, motion note, the naming trap). No
separate spec was written for the weekly variant; section 0 below is its
requirement statement and section 2 records the design calls made here.

---

## Global Constraints

- **Godot 4.6**, portrait 1080×1920 design space. Every measurement in the
  card spec is already a game pixel — no rescale term anywhere.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation.
  Only accepted exception: layout-only constant overrides (`separation`,
  `margin_*`). `tests/test_day_summary.gd::test_row_scene_declares_no_theme_overrides`
  fails the build if a colour/font/stylebox override appears in
  `DaySummaryStudentRow.tscn`.
- **Test-suite constraints** (documented in `CLAUDE.md`, learned the hard way):
  1. Every suite is `@tool`, or the runner reports the class abstract.
  2. **No test may be a coroutine.** The runner does `suite.call(name)` without
     awaiting; an `await` silently aborts the test and it reports 0 assertions.
     Tweens are observed with `Tween.custom_step()`, never `await`.
  3. Scripts the runner instantiates live must be `@tool` too, with real side
     effects gated behind `if Engine.is_editor_hint(): return`. Pure signal
     wiring stays ungated so tests can exercise it.
  4. Assign the baked theme (`res://Assets/Theme/kejartes_theme.tres`)
     explicitly before a scene enters the tree — ThemeDB's project-theme
     fallback does not populate under the editor's own root.
- **Rescan before running tests.** After editing any `.gd`, run
  `filesystem_manage(op="scan")` or `test_run` serves a stale script. A new
  suite file is not discovered at all until a scan.
- **The Godot MCP bridge is single-client.** Subagents cannot run the editor.
  If you delegate, subagents write code and the orchestrator runs `test_run`.
- Game-facing identifiers and UI text are **Indonesian**; systems code is
  English. Match the surrounding file.
- Commits: Conventional Commits with a scope, e.g.
  `feat(checkup): rebuild the weekly report on the day-summary card`.
- Tunable numbers belong in a named `const` or an `@export`, not inline.

---

## 0. The requirement, precisely

The daily card prints `+12/65` per stat: **today's** delta over the student's
target for that stat. The weekly report must print the same shape with the
numerator changed:

| | Daily card (unchanged) | Week card (this plan) |
|---|---|---|
| Stat number | `+<today's delta>/<target>` | `+<whole week's delta>/<target>` |
| Stat track fill | `current/target`, rewound to `(current − today's delta)/target` | `current/target`, rewound to `(current − week's delta)/target` |
| Energy / mood bars | value only, no number, **not** animated | value **plus** the week's signed movement, and animated from Monday's value |

**The denominator does not change.** "Points needed" is the target value the
mockup already prints — `target_akademis1/2/3` — not `target − current`. The
request changes the numerator only.

"The whole week" is exactly `StudentData.get_akademis_delta()` and friends:

```gdscript
func get_akademis_delta() -> float: return akademis - initial_akademis
```

`initial_*` is written by `record_initial_stats()`, called from
`GameState.convert_to_student_data_array()` (`Scripts/GameState.gd:208`) and
from `StudentManager.initialize_students()`
(`Scripts/SchoolSimulation/StudentManager.gd:56`). `StudentManager` is rebuilt
from GameState at the top of every week (`SchoolDay.gd:226-227`), so
`get_*_delta()` is "now minus Monday morning" — already correct, already
populated, nothing to thread through the simulation.

---

## 1. File Structure

| File | Change | Responsibility after this plan |
|---|---|---|
| `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` | Modify | The card layout. Gains two hidden `DeltaLabel`s, one inside each needs bar. |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | Modify | Owns the card. Two entry points now: `setup_row` (a day) and `setup_week_row` (a week), sharing `_write_stat_rows`. Owns `play_gain` and `play_week_gain`. |
| `Scripts/SchoolSimulation/DaySummaryStatRow.gd` | **Untouched** | Already takes `(stat_key, delta, target, current)` and rewinds to `(current − delta)/target`. Feed it the week's delta and it is correct with no edit. |
| `Scenes/SchoolSimulation/ResultCheckup.tscn` | Modify | Adds the card scene as an `ext_resource` and assigns `student_card_scene`. |
| `Scripts/SchoolSimulation/ResultCheckup.gd` | Modify | Becomes `@tool`. Stops hand-building panels; instantiates the card, feeds it the week, staggers and replays. Keeps header, history log and close button. |
| `Scripts/SchoolSimulation/SchoolDay.gd` | **Untouched** | Still calls `initialize_checkup(student_manager)`; the signature does not change. |
| `tests/test_result_checkup.gd` | Create | Owns everything this plan adds: the needs labels, the week entry point, the week replay, and ResultCheckup's wiring. |
| `tests/test_day_summary.gd` | Modify | Gains one guard test: the daily path leaves the needs deltas hidden. |

---

## 2. Design decisions made here

These were not in the request; they are the smallest choices that make it
buildable. Each names the alternative, so they are cheap to flip.

1. **One scene, two entry points** — not a duplicated `WeekSummaryStudentRow`.
   The art, the geometry, the target-field naming trap and the icon map all
   live in one place. *Alternative:* copy the scene; rejected because the two
   cards would drift and the mockup measurements would need maintaining twice.

2. **The needs delta sits inside its own bar, right-aligned.** The card is
   fixed art: the bars occupy x 336–579 and the stat rows start at x 616, so
   there are 37 free pixels beside a bar and no room for a sibling label. The
   bars set `show_percentage = false`, so their interior is empty and a
   right-aligned number reads cleanly on it. *Alternative:* a row of chips
   below the bars in the card's empty lower-left; rejected as a bigger
   departure from a spec'd layout.

3. **The number is white, like the rest of the card** (`DaySummaryStat`: white
   fill, dark rim), with the sign carrying gain vs loss. *Alternative:* tint it
   `state_success` / `state_danger` the way the old ResultCheckup did — one line
   in `_show_needs_delta`. Rejected because the card's typography is
   deliberately inverted from the app's (spec; see the `_build_day_summary`
   comment in `ThemeFactory.gd`) and a saturated tint under a dark rim muddies
   on the violet and gold fills.

4. **The needs bars animate on the week card only.** The spec's motion note
   refuses to animate them on the *daily* card, because energy and mood mostly
   fall over one day and replaying that beside three growing skill tracks reads
   as a contradiction. Over a week the movement is the point the user asked
   for, so `play_week_gain` moves them and `play_gain` still does not.

5. **ResultCheckup keeps its own chrome** — header, subtitle, the minigame /
   event history list, the drag-to-scroll, the close button. Only the
   per-student panel is replaced. The `title_daily_results.png` banner is not
   reused: it says *Daily* Results.

6. **The avatar loses ResultCheckup's hardcoded name→portrait lookup.** The
   card's `DaySummaryAvatar.set_student()` resolves `avatar_texture`, then
   `splash_path`, then nothing. In the real flow `GameState` fills both from the
   roster dictionary, and `StudentManager.initialize_students()` fills
   `avatar_texture` for its four defaults, so the lookup was dead weight in
   every path that ships. A student with neither loses the random-gradient
   placeholder and shows an empty frame — the same thing the daily popup
   already does.

---

## Task 1: The needs-delta labels on the card

Two labels that exist for the week card and stay hidden on the daily one, plus
the formatter that fills them.

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` (after the
  `EnergyBar` node, and after the `MoodBar` node)
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Create: `tests/test_result_checkup.gd`
- Modify: `tests/test_day_summary.gd` (append one test)

**Interfaces:**
- Consumes: `DaySummaryStudentRow.setup_row()` (existing), the baked
  `DaySummaryStat` variation (existing).
- Produces:
  - `DaySummaryStudentRow.energy_delta_label: Label` (node `EnergyBar/DeltaLabel`)
  - `DaySummaryStudentRow.mood_delta_label: Label` (node `MoodBar/DeltaLabel`)
  - `static func DaySummaryStudentRow.format_needs_delta(delta: float) -> String`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_result_checkup.gd` with the suite scaffold and the first two
tests. The scaffold's helpers are used by every later task — write it in full
now:

```gdscript
@tool
extends McpTestSuite

## The end-of-week report (ResultCheckup), rebuilt on the Daily Results
## card. The card's own geometry, art and daily behaviour belong to
## tests/test_day_summary.gd; this suite owns the WEEKLY reading of it --
## week deltas instead of day deltas, and the two needs numbers the daily
## card does not show.
##
## Suite constraints, carried from tests/test_day_summary.gd:
##  * @tool, or the runner reports the class abstract.
##  * No coroutines -- the runner does suite.call(name) without awaiting,
##    so a tween is only observable through Tween.custom_step().
##  * The baked theme is assigned explicitly before a scene enters the
##    tree; ThemeDB's project-theme fallback does not populate under the
##    editor's own root.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _ROW_SCENE := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"
const _ROW_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd"
const _CHECKUP_SCENE := "res://Scenes/SchoolSimulation/ResultCheckup.tscn"
const _CHECKUP_SCRIPT := "res://Scripts/SchoolSimulation/ResultCheckup.gd"


func suite_name() -> String:
	return "result_checkup"


## Snapshot the active tweens, run `action`, then fast-forward only the
## tweens it created by `duration` seconds. Lifted from
## tests/test_day_summary.gd:37 -- diffing against the before-snapshot
## keeps a tween still finishing from an earlier test (or from the
## editor's own UI) from being mistaken for this one's.
func _run_and_step(action: Callable, duration: float) -> void:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var after: Array = Engine.get_main_loop().get_processed_tweens()
	for tw in after:
		if not before.has(tw) and is_instance_valid(tw):
			tw.custom_step(duration)


## A card wearing the baked theme, in the tree so its @onready vars are
## live, freed by the runner.
func _card() -> DaySummaryStudentRow:
	var inst := (load(_ROW_SCENE) as PackedScene).instantiate() as DaySummaryStudentRow
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	return inst


## A student who opened the week on `start` and closed it on `finish`,
## with every target at 65. record_initial_stats() between the two is
## exactly what GameState does at conversion, so this is the shape the
## real week hands ResultCheckup.
func _student_with_week(start: Dictionary, finish: Dictionary) -> StudentData:
	var s := StudentData.new()
	s.student_name = "Marcel"
	s.target_akademis1 = 65.0
	s.target_akademis2 = 65.0
	s.target_akademis3 = 65.0
	for key in start:
		s.set(key, start[key])
	s.record_initial_stats()
	for key in finish:
		s.set(key, finish[key])
	return s


# ------------------------------------------------ the needs-delta labels

## The two numbers the week card adds. They live INSIDE their bars -- the
## card is fixed art and there are 37 free pixels between the bars' right
## edge (579) and the stat rows' left edge (616), which is not a label.
## They start hidden because the daily card must not grow a readout the
## mockup does not have.
func test_the_card_carries_a_hidden_delta_label_on_each_needs_bar() -> void:
	var inst := _card()
	var e := inst.get_node_or_null("EnergyBar/DeltaLabel") as Label
	var m := inst.get_node_or_null("MoodBar/DeltaLabel") as Label
	assert_not_null(e, "EnergyBar is missing its DeltaLabel")
	assert_not_null(m, "MoodBar is missing its DeltaLabel")
	assert_eq(e.theme_type_variation, &"DaySummaryStat",
		"the needs delta must wear the card's own number style")
	assert_eq(m.theme_type_variation, &"DaySummaryStat",
		"the needs delta must wear the card's own number style")
	assert_eq(e.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"the number is right-aligned inside its bar")
	assert_eq(m.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"the number is right-aligned inside its bar")
	assert_false(e.visible, "the needs delta must start hidden")
	assert_false(m.visible, "the needs delta must start hidden")


## Same sign rule as DaySummaryStatRow.format_value: the "+" is explicit
## and the "-" comes free from %d, so a loss never reads "+-12". Zero
## reads "+0" rather than blank, because an empty slot on the card looks
## like a bug.
func test_needs_delta_carries_an_explicit_sign() -> void:
	assert_eq(DaySummaryStudentRow.format_needs_delta(8.0), "+8",
		"a gain must carry its plus")
	assert_eq(DaySummaryStudentRow.format_needs_delta(-12.4), "-12",
		"a loss must not read '+-12'")
	assert_eq(DaySummaryStudentRow.format_needs_delta(0.0), "+0",
		"a flat week is still a number")
	assert_eq(DaySummaryStudentRow.format_needs_delta(2.6), "+3",
		"the number is rounded, not truncated")
```

Then append this guard to `tests/test_day_summary.gd`, immediately after
`test_setup_row_empties_the_needs_bars_for_an_unknown_student`:

```gdscript
## The two DeltaLabels exist for ResultCheckup's weekly card. The mockup
## has no needs number, so the daily path must leave them hidden -- if a
## later edit shows them unconditionally, the daily card silently grows a
## readout the design does not have.
func test_setup_row_leaves_the_needs_deltas_hidden() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 40.0
	s.mood = 50.0
	inst.setup_row("Marcel", [], s)

	assert_false(inst.energy_delta_label.visible,
		"the daily card must not show an energy delta")
	assert_false(inst.mood_delta_label.visible,
		"the daily card must not show a mood delta")
```

- [ ] **Step 2: Rescan, then run the tests to verify they fail**

The suite file is new; without a scan the runner does not see it at all.

Run (via MCP, in order):

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
test_run(suite="day_summary")
```

Expected: `result_checkup` — both tests FAIL (`EnergyBar is missing its
DeltaLabel`, and a lookup error on `format_needs_delta`). `day_summary` — the
new test FAILS on `Invalid get index 'energy_delta_label'`.

- [ ] **Step 3: Add the two labels to the card scene**

In `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`, insert this block
immediately after the `EnergyBar` node's last property line
(`show_percentage = false`):

```
[node name="DeltaLabel" type="Label" parent="EnergyBar"]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_right = -16.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"DaySummaryStat"
text = "+0"
horizontal_alignment = 2
vertical_alignment = 1
```

and the identical block after the `MoodBar` node's `show_percentage = false`,
changing only the parent:

```
[node name="DeltaLabel" type="Label" parent="MoodBar"]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_right = -16.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"DaySummaryStat"
text = "+0"
horizontal_alignment = 2
vertical_alignment = 1
```

Notes: `unique_id=` is optional — Godot writes one on the next editor save, and
the file's existing nodes only carry them because the editor saved them. The
16px right inset keeps the number clear of the bar's 5px rim. No
`theme_override_*` anywhere, so `test_row_scene_declares_no_theme_overrides`
still passes.

- [ ] **Step 4: Add the accessors and the formatter**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, extend the `@onready`
block (after `mood_bar`, before `stat_rows`):

```gdscript
@onready var energy_delta_label: Label = $EnergyBar/DeltaLabel
@onready var mood_delta_label: Label = $MoodBar/DeltaLabel
```

and add the formatter directly above `setup_row`:

```gdscript
## "+8" / "-12" -- the week's movement on a needs bar. Same sign rule as
## DaySummaryStatRow.format_value: the "+" is explicit and the "-" comes
## free from %d, so a loss never reads "+-12". Zero reads "+0" rather
## than blank, because an empty slot on the card looks like a bug.
static func format_needs_delta(delta: float) -> String:
	var d := int(round(delta))
	var sign_str := "+" if d >= 0 else ""
	return "%s%d" % [sign_str, d]
```

Then make the daily path explicit about hiding them. Replace the two needs-bar
lines in `setup_row`:

```gdscript
	energy_bar.value = student.energy if student != null else 0.0
	mood_bar.value = student.mood if student != null else 0.0
```

with:

```gdscript
	energy_bar.value = student.energy if student != null else 0.0
	mood_bar.value = student.mood if student != null else 0.0
	# The needs numbers belong to ResultCheckup's weekly card; the mockup
	# has none. Hidden explicitly rather than relying on the scene's
	# default, so a card re-armed from the weekly path is still correct.
	energy_delta_label.hide()
	mood_delta_label.hide()
```

- [ ] **Step 5: Rescan and run the tests to verify they pass**

Run:

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
test_run(suite="day_summary")
```

Expected: `result_checkup` 2/2 PASS. `day_summary` all PASS, including the new
`test_setup_row_leaves_the_needs_deltas_hidden` and the untouched
`test_row_scene_declares_no_theme_overrides`.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_result_checkup.gd tests/test_result_checkup.gd.uid tests/test_day_summary.gd && git commit -m "feat(day-summary): add hidden needs-delta labels to the card"
```

`tests/test_result_checkup.gd.uid` is generated by the editor on scan. If it
does not exist yet, drop it from the `git add` and pick it up in Task 2 — a
missing `.uid` sidecar has already cost this project one follow-up commit.

---

## Task 2: `setup_week_row()` — the card, driven by the week

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `DaySummaryStatRow.set_stat(stat_key, delta, target, current)`,
  `DaySummaryAvatar.set_student(student)`,
  `DaySummaryStudentRow.format_needs_delta()` (Task 1),
  `StudentData.get_akademis_delta()` / `get_seni_delta()` /
  `get_olahraga_delta()` / `get_energy_delta()` / `get_mood_delta()`.
- Produces:
  - `func DaySummaryStudentRow.setup_week_row(student: StudentData) -> void`
  - `func DaySummaryStudentRow._write_stat_rows(deltas: Dictionary, student: StudentData) -> void`
  - `var DaySummaryStudentRow._energy_from: float` and `._mood_from: float`
    (Monday's needs values, cached for Task 3)

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_result_checkup.gd`:

```gdscript
# --------------------------------------------------- the weekly reading

## The whole point of the screen: the number over each stat track is the
## WEEK'S movement, not a day's. 40 -> 58 with the target at 65 reads
## "+18/65"; a stat that lost ground reads with a minus and no chevron.
func test_the_week_card_reads_the_whole_weeks_movement() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 40.0, "seni_budaya": 30.0, "olahraga": 55.0},
		{"akademis": 58.0, "seni_budaya": 31.0, "olahraga": 49.0})

	inst.setup_week_row(s)

	assert_eq(inst.stat_rows[0].value.text, "+18/65",
		"akademis moved 40 -> 58 across the week")
	assert_eq(inst.stat_rows[1].value.text, "+1/65",
		"seni budaya moved 30 -> 31 across the week")
	assert_eq(inst.stat_rows[2].value.text, "-6/65",
		"olahraga LOST ground and must read with a minus")
	assert_false(inst.stat_rows[2].chevron.visible,
		"the chevron is an up arrow; a losing week must not show one")


## The project's documented naming trap: target_akademis2 is the SENI
## target and target_akademis3 the OLAHRAGA one. Three distinct targets
## catch a card that read the wrong field for a stat.
func test_the_week_card_pairs_each_stat_with_its_own_target() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 40.0, "seni_budaya": 40.0, "olahraga": 40.0},
		{"akademis": 41.0, "seni_budaya": 42.0, "olahraga": 43.0})
	s.target_akademis1 = 65.0
	s.target_akademis2 = 70.0
	s.target_akademis3 = 75.0

	inst.setup_week_row(s)

	assert_eq(inst.stat_rows[0].value.text, "+1/65", "akademis reads target_akademis1")
	assert_eq(inst.stat_rows[1].value.text, "+2/70", "seni budaya reads target_akademis2")
	assert_eq(inst.stat_rows[2].value.text, "+3/75", "olahraga reads target_akademis3")


## The bars still read tonight's value -- what is new is the number
## beside them, which is the week's movement and is shown here (and only
## here). Energy usually falls over a week and mood usually does not; the
## pair below is deliberately one of each.
func test_the_week_card_shows_both_needs_deltas() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"energy": 80.0, "mood": 70.0},
		{"energy": 62.0, "mood": 85.0})

	inst.setup_week_row(s)

	assert_true(inst.energy_delta_label.visible,
		"the week card must show the energy delta")
	assert_true(inst.mood_delta_label.visible,
		"the week card must show the mood delta")
	assert_eq(inst.energy_delta_label.text, "-18",
		"energy fell 80 -> 62 across the week")
	assert_eq(inst.mood_delta_label.text, "+15",
		"mood rose 70 -> 85 across the week")
	assert_true(is_equal_approx(inst.energy_bar.value, 62.0),
		"the bar itself still reads tonight's energy")
	assert_true(is_equal_approx(inst.mood_bar.value, 85.0),
		"the bar itself still reads tonight's mood")


## ResultCheckup iterates StudentManager.students and cannot hand over a
## null -- but the daily path can and does, and both entry points share
## the card. Empty bars and a blank name are the honest answer; the
## scene's baked 36/82 placeholders are not.
func test_the_week_card_empties_itself_for_a_missing_student() -> void:
	var inst := _card()

	inst.setup_week_row(null)

	assert_eq(inst.name_label.text, "", "an absent student has no name to print")
	assert_true(is_equal_approx(inst.energy_bar.value, 0.0),
		"an absent student must not inherit the mockup's 36% energy")
	assert_true(is_equal_approx(inst.mood_bar.value, 0.0),
		"an absent student must not inherit the mockup's 82% mood")
	assert_false(inst.energy_delta_label.visible,
		"there is no delta to show for a student we do not have")
	assert_false(inst.mood_delta_label.visible,
		"there is no delta to show for a student we do not have")


## Both entry points must draw their three rows through the same code --
## two hand-rolled loops would drift on the next change to the trap.
func test_both_entry_points_share_one_stat_row_writer() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("func _write_stat_rows("),
		"the shared stat-row writer must exist")
	assert_eq(src.count("stat_rows[i].set_stat("), 1,
		"exactly one place may drive the stat rows")
```

- [ ] **Step 2: Rescan and run to verify they fail**

Run:

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
```

Expected: the five new tests FAIL with
`Invalid call. Nonexistent function 'setup_week_row'`, and the source scan fails
on the missing `_write_stat_rows`.

- [ ] **Step 3: Implement the shared writer and the weekly entry point**

In `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, add the cached
week-opening values immediately after the `@onready` block:

```gdscript
## Where the two needs bars stood on Monday morning, cached by
## setup_week_row so play_week_gain can rewind and travel back. Unused on
## the daily path, whose needs bars deliberately do not move.
var _energy_from: float = 0.0
var _mood_from: float = 0.0
```

Replace the three-row loop at the end of `setup_row`:

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

with a call to the extracted writer:

```gdscript
	_write_stat_rows(_sum_deltas(changes), student)
```

and add the writer plus the weekly entry point after `_sum_deltas`:

```gdscript
## The three stat rows, given one delta per stat. Shared by the daily and
## weekly entry points, which differ ONLY in where their deltas come
## from -- a card that drew its rows two different ways would drift, and
## the akademis2/3 naming trap below is the last thing that should be
## written down twice.
func _write_stat_rows(deltas: Dictionary, student: StudentData) -> void:
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


## The same card, one week wide: ResultCheckup's end-of-week report.
##
## Every delta here is "now minus Monday morning", straight off the
## week-start snapshot record_initial_stats() takes when GameState
## converts the roster -- StudentManager is rebuilt at the top of every
## week, so no snapshot has to be threaded through the simulation.
##
## Two things separate this from setup_row: the deltas span the week
## rather than the day, and the two needs numbers are shown. The stat
## rows themselves need no special case -- DaySummaryStatRow already
## rewinds to (current - delta) / target, which IS Monday's ratio once
## the delta is a week long.
func setup_week_row(student: StudentData) -> void:
	name_label.text = student.student_name if student != null else ""
	avatar.set_student(student)

	if student == null:
		energy_bar.value = 0.0
		mood_bar.value = 0.0
		_energy_from = 0.0
		_mood_from = 0.0
		energy_delta_label.hide()
		mood_delta_label.hide()
		_write_stat_rows({}, null)
		return

	var energy_delta := student.get_energy_delta()
	var mood_delta := student.get_mood_delta()
	energy_bar.value = student.energy
	mood_bar.value = student.mood
	# StudentData clamps its needs as it applies them, so on a week that
	# hit the 0 or 100 ceiling this opening value overshoots the true
	# Monday reading slightly and the bar travels a touch further than it
	# really did. Cosmetic, and the same trade DaySummaryStatRow already
	# documents for the stat tracks.
	_energy_from = clampf(student.energy - energy_delta, 0.0, 100.0)
	_mood_from = clampf(student.mood - mood_delta, 0.0, 100.0)
	_show_needs_delta(energy_delta_label, energy_delta)
	_show_needs_delta(mood_delta_label, mood_delta)

	_write_stat_rows({
		"akademis": student.get_akademis_delta(),
		"seni_budaya": student.get_seni_delta(),
		"olahraga": student.get_olahraga_delta(),
	}, student)


func _show_needs_delta(label: Label, delta: float) -> void:
	label.text = format_needs_delta(delta)
	label.show()
```

- [ ] **Step 4: Rescan and run to verify they pass**

Run:

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
test_run(suite="day_summary")
```

Expected: `result_checkup` 7/7 PASS. `day_summary` still all PASS — in
particular `test_row_sums_same_stat_deltas_and_reads_the_correct_target_field`
and `test_row_always_shows_three_stat_rows`, which now exercise the extracted
`_write_stat_rows` through `setup_row`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_result_checkup.gd && git commit -m "feat(day-summary): drive the card from a whole week's deltas"
```

---

## Task 3: `play_week_gain()` — replay the week

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `DaySummaryStudentRow.play_gain(delay)` (existing), `_energy_from` /
  `_mood_from` (Task 2), `Juice.fill_bar(bar, to, duration, delay)`.
- Produces: `func DaySummaryStudentRow.play_week_gain(delay: float = 0.0) -> void`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_result_checkup.gd`:

```gdscript
# ---------------------------------------------------- the week's replay

## setup_week_row must land the final value on its own, so a card that is
## never animated is still correct; play_week_gain then rewinds and grows
## back. 26 -> 52 against a target of 65 is 40% -> 80%.
func test_the_week_card_rewinds_its_tracks_to_monday() -> void:
	var inst := _card()
	var s := _student_with_week({"akademis": 26.0}, {"akademis": 52.0})
	inst.setup_week_row(s)
	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01,
		"setup alone must leave tonight's 52/65 on the track")

	inst.play_week_gain()

	assert_true(absf(inst.stat_rows[0].track.value - 40.0) <= 0.01,
		"play_week_gain must rewind the track to Monday's 26/65 = 40%")


## The needs bars DO move on the weekly card. The spec refuses to animate
## them on the daily one, because one day's decay replayed beside three
## growing skill tracks reads as a contradiction -- but the week's
## movement is exactly what this screen was asked to show, so it moves.
func test_the_week_card_rewinds_its_needs_bars_to_monday() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"energy": 80.0, "mood": 40.0},
		{"energy": 62.0, "mood": 55.0})
	inst.setup_week_row(s)

	inst.play_week_gain()

	assert_true(absf(inst.energy_bar.value - 80.0) <= 0.01,
		"energy must rewind to Monday's 80 so the week's LOSS is visible as movement")
	assert_true(absf(inst.mood_bar.value - 40.0) <= 0.01,
		"mood must rewind to Monday's 40")


## ...and every gauge must end exactly where setup_week_row put it.
## Stepping past dur_slow is what proves these are real animations and
## not a second assignment.
func test_a_played_week_lands_on_tonights_values() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 26.0, "energy": 80.0, "mood": 40.0},
		{"akademis": 52.0, "energy": 62.0, "mood": 55.0})
	inst.setup_week_row(s)
	var tokens := DesignTokens.load_default()

	_run_and_step(func(): inst.play_week_gain(), tokens.dur_slow + 0.2)

	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01,
		"the stat track must end on tonight's 52/65")
	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01,
		"energy must end on tonight's value")
	assert_true(absf(inst.mood_bar.value - 55.0) <= 0.01,
		"mood must end on tonight's value")
	assert_eq(inst.energy_delta_label.text, "-18",
		"replaying the week must not disturb the number")


## The daily card's own replay must stay exactly as it was: three tracks
## and no needs movement. This is the guard on the spec's motion note.
func test_the_daily_replay_still_leaves_the_needs_bars_alone() -> void:
	var inst := _card()
	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 44.0
	s.mood = 71.0
	inst.setup_row("Marcel", [], s)

	inst.play_gain()

	assert_true(absf(inst.energy_bar.value - 44.0) <= 0.01,
		"play_gain must not move the energy bar")
	assert_true(absf(inst.mood_bar.value - 71.0) <= 0.01,
		"play_gain must not move the mood bar")
```

- [ ] **Step 2: Rescan and run to verify they fail**

Run:

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
```

Expected: the three `play_week_gain` tests FAIL with
`Invalid call. Nonexistent function 'play_week_gain'`.
`test_the_daily_replay_still_leaves_the_needs_bars_alone` PASSES already — it
pins behaviour that must not change.

- [ ] **Step 3: Implement**

Append to `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`, after `play_gain`:

```gdscript
## Replay a whole week: the three stat tracks grow the way play_gain
## already grows them, and the two needs bars travel from Monday's value
## to tonight's.
##
## The daily card deliberately does NOT animate its needs bars (spec
## 2026-08-29-day-summary-mockup-design.md, motion note) -- that rule is
## about one day's decay reading as a contradiction beside three growing
## tracks. Over a week the movement is the readout, so it travels, in
## either direction.
##
## Never awaited and never required: setup_week_row has already written
## every final value, so a caller that skips this sees a correct, static
## card. Call setup_week_row first -- this reads the two openings it
## cached, which otherwise default to 0.
func play_week_gain(delay: float = 0.0) -> void:
	play_gain(delay)
	_play_needs_travel(energy_bar, _energy_from, delay)
	_play_needs_travel(mood_bar, _mood_from, delay)


func _play_needs_travel(bar: ProgressBar, from_value: float, delay: float) -> void:
	var to_value: float = bar.value
	bar.value = from_value
	Juice.fill_bar(bar, to_value, -1.0, delay)
```

- [ ] **Step 4: Rescan and run to verify they pass**

Run:

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
test_run(suite="day_summary")
```

Expected: `result_checkup` 11/11 PASS, `day_summary` all PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_result_checkup.gd && git commit -m "feat(day-summary): replay a full week across every gauge on the card"
```

---

## Task 4: ResultCheckup shows the card

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn`
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `DaySummaryStudentRow.setup_week_row(student)` (Task 2),
  `.play_week_gain(delay)` (Task 3), `Juice.stagger_in(nodes)`,
  `Juice.tokens()`, `StudentManager.students`, `.minigame_history`.
- Produces:
  - `@export var ResultCheckup.student_card_scene: PackedScene`
  - `initialize_checkup(student_manager)` and the `checkup_closed` signal are
    unchanged, so `SchoolDay.gd` needs no edit.

**The one trap in this task:** a card's `@onready` nodes (`name_label`,
`energy_bar`, `stat_rows`, …) are null until it enters the tree. `setup_week_row`
must therefore be called **after** `students_container.add_child(card)`, never
before — which is exactly the order `DaySummaryPopup.setup_summary` already
uses. This is why the card is built inline in the loop rather than by a
`_create_student_card(student)` helper: a helper that both instantiated and set
up the card could only do it in the wrong order.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_result_checkup.gd`:

```gdscript
# ----------------------------------------------- the screen that uses it

## The weekly card must be the SAME scene the daily popup shows, not a
## copy -- one set of mockup measurements, one piece of art.
func test_the_checkup_scene_supplies_the_week_card() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var packed: PackedScene = inst.student_card_scene
	assert_not_null(packed, "ResultCheckup.tscn must assign student_card_scene")
	assert_eq(packed.resource_path, _ROW_SCENE,
		"the weekly card must be the Daily Results card scene itself")
	inst.free()


## The screen end to end: a StudentManager whose first default has moved,
## one card per student, each reading its own week.
func test_the_checkup_builds_one_week_card_per_student() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var manager := StudentManager.new()
	track(manager)
	manager.students[0].akademis += 12.0

	inst.initialize_checkup(manager)

	var container := inst.get_node(
		"Margin/VBox/ScrollContainer/MainContent/StudentsContainer")
	assert_eq(container.get_child_count(), manager.students.size(),
		"one card per student in the roster")
	var first = container.get_child(0)
	assert_true(first is DaySummaryStudentRow,
		"the checkup must show the Daily Results card, not a hand-built panel")
	assert_eq(first.name_label.text, manager.students[0].student_name,
		"each card is labelled with the student it was built for")
	assert_eq(first.stat_rows[0].value.text,
		"+12/%d" % int(round(manager.students[0].target_akademis1)),
		"the card must read the WEEK's gain against that student's target")
	assert_true(first.energy_delta_label.visible,
		"the weekly card shows its needs deltas")


## The old screen hand-built a five-StatBar panel per student, plus an
## avatar loader and a gradient placeholder. All of it goes -- leaving it
## beside the card would be a second, silently diverging report.
func test_the_checkup_no_longer_hand_builds_its_stat_bars() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_false(src.contains("func _add_stat_bar"),
		"the hand-built stat bar builder must be gone, not left beside the card")
	assert_false(src.contains("StatBar.new()"),
		"the checkup must not build StatBars any more")
	assert_false(src.contains("_placeholder_avatar"),
		"the card owns avatar fallback now (DaySummaryAvatar)")
	assert_false(src.contains("_create_student_card"),
		"the card is built inline, after add_child -- there is no builder left")
	assert_true(src.contains("setup_week_row("),
		"the checkup must feed the card the week")
	assert_true(src.contains("play_week_gain("),
		"the checkup must replay the week")


## Same rhythm the daily popup uses: cards land first, then their gauges
## start moving, offset card by card. Filling before the cards are
## visible wastes the whole gesture.
func test_the_checkup_fills_its_cards_after_they_land() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_true(src.contains("Juice.stagger_in(cards)"),
		"the cards must still stagger in")
	assert_true(src.find("Juice.stagger_in(cards)") < src.find("play_week_gain("),
		"the fill must be kicked off after stagger_in, not before it")


## A card's @onready nodes -- name_label, energy_bar, stat_rows -- are
## null until it enters the tree, so setting it up before add_child
## crashes on the first assignment. DaySummaryPopup already adds first
## and sets up second; this pins the checkup to the same order.
func test_the_checkup_sets_each_card_up_only_once_it_is_in_the_tree() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_true(
		src.find("students_container.add_child(card)") < src.find("card.setup_week_row("),
		"add_child must come before setup_week_row -- @onready nodes are null outside the tree")


## The history log and the close button are the week's own chrome and
## must survive the card swap.
func test_the_checkup_keeps_its_history_and_its_close_button() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var manager := StudentManager.new()
	track(manager)
	manager.minigame_history.append({
		"day": "Senin", "category": "Akademis",
		"game_name": "Uji", "won": true,
	})

	inst.initialize_checkup(manager)

	var history := inst.get_node(
		"Margin/VBox/ScrollContainer/MainContent/HistoryList")
	assert_eq(history.get_child_count(), 1,
		"the week's minigame log must still be built")
	assert_not_null(inst.get_node_or_null("Margin/VBox/BtnClose"),
		"the close button must survive the card swap")
```

- [ ] **Step 2: Rescan and run to verify they fail**

Run:

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
```

Expected: FAIL — `Invalid get index 'student_card_scene'`, and
`test_the_checkup_builds_one_week_card_per_student` fails because
`initialize_checkup` cannot run in the editor (the script is not `@tool`, so its
`@onready` vars are null).

- [ ] **Step 3: Wire the card scene into ResultCheckup.tscn**

In `Scenes/SchoolSimulation/ResultCheckup.tscn`:

**3a.** Bump the step count and add the card as an `ext_resource`. Replace:

```
[gd_scene load_steps=2 format=3 uid="uid://result_checkup"]

[ext_resource type="Script" path="res://Scripts/SchoolSimulation/ResultCheckup.gd" id="1_checkup"]
```

with:

```
[gd_scene load_steps=3 format=3 uid="uid://result_checkup"]

[ext_resource type="Script" path="res://Scripts/SchoolSimulation/ResultCheckup.gd" id="1_checkup"]
[ext_resource type="PackedScene" uid="uid://c1dstgm0d4nvr" path="res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn" id="2_card"]
```

`uid://c1dstgm0d4nvr` is `DaySummaryStudentRow.tscn`'s own UID, read from its
`gd_scene` header. `tests/test_project_hygiene.gd::test_every_scene_ext_resource_uid_resolves_to_its_own_asset`
fails the build if it points anywhere else.

**3b.** Assign it on the root node. Replace:

```
script = ExtResource("1_checkup")
```

with:

```
script = ExtResource("1_checkup")
student_card_scene = ExtResource("2_card")
```

**3c.** Give the card stack the popup's own gap, since it is now the same art in
both places. On the `StudentsContainer` node, change:

```
theme_override_constants/separation = 48
```

to:

```
theme_override_constants/separation = 56
```

(A `separation` constant is the one override this project's styling rule
allows: layout, not colour.)

- [ ] **Step 4: Rebuild the screen's card construction**

In `Scripts/SchoolSimulation/ResultCheckup.gd`:

**4a.** Make the script `@tool` and update the header docs. Replace the first
eight lines:

```gdscript
extends Control

## The end-of-week report card: one &"Card" per student with five
## category-tinted StatBars filling from last week's value, followed by a
## log of the week's minigames and events.
##
## Every surface is a theme variation and every accent is a DesignToken;
## this script builds no StyleBoxFlat and holds no Color literal.
```

with:

```gdscript
@tool
extends Control

## The end-of-week report card: one Daily Results card per student -- the
## same DaySummaryStudentRow the nightly popup shows -- read one week
## wide instead of one day, followed by a log of the week's minigames and
## events.
##
## Each card's three stat numbers are "+<the week's gain>/<target>", and
## its two needs bars carry the week's energy and mood movement as a
## signed number. All of that lives on the card; this screen only chooses
## WHICH deltas the card is shown (see DaySummaryStudentRow.setup_week_row).
##
## @tool so the in-editor test runner can build the screen and inspect it
## (CLAUDE.md, testing constraint 3). Everything with a real side effect
## is gated on Engine.is_editor_hint(); signal wiring deliberately is not.
##
## Every surface is a theme variation and every accent is a DesignToken;
## this script builds no StyleBoxFlat and holds no Color literal.
```

**4b.** Add the export at the end of the `@export_group("Visual - Buttons")`
block, just above `const _BADGE_SCENE`:

```gdscript
# ── Wiring ───────────────────────────────────────────────────────────────────
## The per-student card. Assigned in ResultCheckup.tscn to
## DaySummaryStudentRow.tscn -- the same scene the nightly popup uses.
@export var student_card_scene: PackedScene
```

**4c.** Delete the now-dead constant:

```gdscript
const _AVATAR_SIZE := 240
```

(`_BADGE_SCENE` stays — the history log still uses it.)

**4d.** Delete the now-dead field:

```gdscript
var animated_bars: Array[Dictionary] = []
```

**4e.** Gate `_ready`. Replace the whole function with:

```gdscript
func _ready() -> void:
	# Signal wiring stays ungated so the editor's test runner can exercise
	# it; everything below the guard is a real side effect.
	btn_close.pressed.connect(_on_close_pressed)
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)
	if Engine.is_editor_hint():
		return

	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	_apply_visual_exports()
	btn_close.modulate.a = 0.0
	btn_close.disabled = true
```

**4f.** In `initialize_checkup`, drop `animated_bars.clear()` and build the
cards inline. Replace:

```gdscript
	animated_bars.clear()

	var cards: Array = []
	for student in student_manager.students:
		var card = _create_student_card(student, student_manager.minigame_history)
		students_container.add_child(card)
		_set_mouse_filter_pass(card)
		cards.append(card)
```

with:

```gdscript
	var cards: Array = []
	for student in student_manager.students:
		var card := student_card_scene.instantiate() as DaySummaryStudentRow
		students_container.add_child(card)
		# Set up only once the card is in the tree: its @onready nodes are
		# null until then. Same order DaySummaryPopup.setup_summary uses.
		card.setup_week_row(student)
		_set_mouse_filter_pass(card)
		cards.append(card)
```

**4g.** Delete the hand-built card. Remove everything from
`func _create_student_card(student: StudentData, _history: Array[Dictionary]) -> PanelContainer:`
down to and including the closing `row.add_child(delta_lbl)` of `_add_stat_bar`
— that is `_create_student_card`, `_section_header`, `_placeholder_avatar` and
`_add_stat_bar`, four consecutive functions. Nothing replaces them: step 4f now
builds the card inline, because a helper that instantiated *and* set up the card
could only do it in the wrong order.

`_create_history_item` and `_make_badge`, which follow, are untouched.

**4h.** Rewrite the entrance. Replace `_play_entrance_animations` with:

```gdscript
func _play_entrance_animations(cards: Array = []) -> void:
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return

	var t := Juice.tokens()
	modulate.a = 0.0
	var fader = create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished

	# Cards land one at a time only after the screen itself is visible --
	# staggering under a still-transparent root wastes the effect.
	Juice.stagger_in(cards)

	# Each card's five gauges start moving on the beat that card ARRIVES
	# on -- the same offset stagger_in uses, so the week's growth and the
	# card's entrance share a rhythm. This is the nightly popup's own
	# cadence, one week long.
	for i in cards.size():
		cards[i].play_week_gain(float(i) * t.stagger_step)
	await get_tree().create_timer(t.dur_slow).timeout

	var button_tween = create_tween()
	button_tween.tween_property(btn_close, "modulate:a", 1.0, t.dur_fast)
	btn_close.disabled = false
```

- [ ] **Step 5: Rescan and run the full suite**

Run:

```
filesystem_manage(op="scan")
test_run()
```

Expected: every suite green — 30 suites now. Watch specifically for
`result_checkup` (17/17), `day_summary`, `school_day`
(`test_interactive_controls_meet_the_minimum_touch_target` still finds
`Margin/VBox/BtnClose`), `audio_coverage` (`test_result_checkup_has_sfx` still
finds `popup_open` and `confirm` in the source), and `project_hygiene` (the new
`ext_resource` UID).

If `test_run` reports a `scene_warning`, open
`Scenes/Splashscreen/Splashscreen.tscn` in the editor before trusting any
failure.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/ResultCheckup.tscn Scripts/SchoolSimulation/ResultCheckup.gd tests/test_result_checkup.gd && git commit -m "feat(checkup): rebuild the weekly report on the day-summary card"
```

---

## Task 5: See it, then write down what it looks like

Tests prove the numbers; only the screen proves the layout. This task is the
visual gate — the card is fixed art at 992×410 and the needs number is the one
element in this plan that was never in a mockup.

**Files:**
- Modify: `CLAUDE.md` (the "Current work" paragraph)

- [ ] **Step 1: Reach the screen**

Do not play a week to get here. Run the game (`project_run`), then:

1. Open the debug overlay — `F1`, or five taps in the top-right corner.
2. General tab → **⚡ Seed Playtest State** (roster approved, 999999G, full
   inventory, lobby tutorial bypassed).
3. The seed does **not** fill `day_schedules`, and SchoolDay needs them: go
   Lobby → **Atur Jadwal**, assign the week, confirm.
4. Continue into StudentList → SchoolDay, then press the day screen's **Skip**
   button to run the week out.
5. ResultCheckup opens on week end.

- [ ] **Step 2: Screenshot and judge four things**

`editor_screenshot`. Check:

1. Each card's three numbers read `+N/target` with N spanning the **week**, not
   a day — cross-check one student against the Rapor screen if unsure.
2. The energy and mood numbers sit inside their bars, clear of the 5px rim, and
   are legible on both the violet energy fill and the gold mood fill.
3. A card fits: 992px of art centred inside the 1040px content box, no
   horizontal scroll, no clipping against the ScrollContainer's scrollbar.
4. The stagger reads as one gesture — cards land, then five gauges per card
   travel, then the close button fades in.

If the needs number collides with the bar fill at high values, the fix is the
label's `offset_right` in `DaySummaryStudentRow.tscn`, not a theme override.

- [ ] **Step 3: Update the project guide**

In `CLAUDE.md`, under **Current work**, replace:

```
The koperasi/inventory integration is committed and done. Recent work is the
day-summary readout: see `docs/superpowers/plans/2026-08-29-day-summary-mockup.md`,
`2026-08-30-day-summary-annotated-readout.md`, and
`2026-08-30-day-summary-stat-track-gauge.md` (**plan checkboxes are never
ticked — git log is the real record**).
```

with:

```
The koperasi/inventory integration is committed and done. Recent work is the
day-summary readout: see `docs/superpowers/plans/2026-08-29-day-summary-mockup.md`,
`2026-08-30-day-summary-annotated-readout.md`, and
`2026-08-30-day-summary-stat-track-gauge.md` (**plan checkboxes are never
ticked — git log is the real record**). `ResultCheckup` now draws the same
card one week wide — `+<week's gain>/<target>` per stat, plus the week's
energy and mood movement on the needs bars — via
`DaySummaryStudentRow.setup_week_row()`; see
`docs/superpowers/plans/2026-08-31-result-checkup-week-card.md`.
```

- [ ] **Step 4: Re-run the full suite one last time**

Run:

```
filesystem_manage(op="scan")
test_run()
```

Expected: 30 suites, all green. Record the actual counts in the commit body —
not "all green" from memory.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md && git commit -m "docs: record the ResultCheckup week card in the project guide"
```

---

## Noticed in passing — not in scope

`ResultCheckup._apply_visual_exports()` writes `students_section_header_text` /
`history_section_header_text` into
`Margin/VBox/ScrollContainer/MainContent/StudentsSectionHeader/Label` and
`.../HistorySectionHeader/Label`. Neither node exists: the scene's headers are
plain Labels named `StudentsHeader` and `HistoryHeader`. Both exports are
therefore dead, and have been since before this plan. The fix is two node paths
— but it changes user-visible copy on a screen this plan is already rewriting,
so it is called out rather than folded in. Ask before doing it.
