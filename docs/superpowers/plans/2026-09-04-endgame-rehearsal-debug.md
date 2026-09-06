# End-Game Rehearsal Debug Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a debug-only entry point that arms a fixed, known student roster and jumps straight to the Tes Besar notice, so the whole end-of-grade sequence can be rehearsed in one click and then undone without losing the run that was in progress.

**Architecture:** All the logic lives in one new plain static-function script, `Scripts/Debug/EndGameRehearsal.gd` — roster presets, a GameState snapshot/restore pair, and an `arm()` that writes the rehearsal state. `DebugManager.gd` only adds four buttons that call into it, keeping the new logic out of that already-1500-line file and (unlike DebugManager) live-testable in the MCP runner. Nothing in the shipped game ever calls this file; the only isolation guarantee it makes is that every write it performs is captured by `snapshot()` first and reversible via `restore()`.

**Tech Stack:** Godot 4.6, GDScript. Tests are `McpTestSuite` suites run in-editor via the `godot-ai` MCP `test_run` tool.

**Spec:** No separate spec doc — this is a debug-only tool whose requirements were settled in conversation and are captured in "Requirements" below. The plan is self-contained.

## Requirements

1. Three fixed presets, selectable from the debug overlay:
   - **Lulus** — all four students clear all three targets (win path).
   - **Gagal** — no student clears any target (lose path).
   - **Campur** — a 3/2/1/0 ladder of cleared targets across the four students, so one pass of the SemesterEnd carousel shows both stamp kinds and every star rating from 3★ down to 0★.
2. The rehearsal **starts at TesNotice** (`res://Scenes/EndGame/TesNotice.tscn`, the "Notice Tes Besar" screen) and runs the real sequence from there — TesNotice → ExamProgress → CutScene (exam) → SemesterEnd → RunResult.
3. **Does not interrupt the main game:** arming snapshots the full GameState first, and a "Pulihkan" (restore) button puts the previous run back — including the state RunResult's own progression mutates on the way out.
4. No shipped-game code path calls the rehearsal. The only production file touched is `DebugManager.gd`, and only to add buttons.

## Global Constraints

- Test suites MUST be `@tool` and extend `McpTestSuite`, or the runner reports them abstract/broken.
- **No test may be a coroutine.** The runner calls `suite.call(name)` without awaiting; an `await` silently aborts the test and it reports "0 assertions".
- Tests run via the MCP tool `test_run(suite="<name>")` — there is no CLI test runner in this project.
- **After editing any `.gd` from outside the editor, run `filesystem_manage(op="scan")` before `test_run`**, or the runner serves stale bytecode. If a scan is not enough, force a reload with a no-op `script_patch` on that file (add and remove a blank line).
- Some suites assume the main scene is open; open `res://Scenes/MainMenu/main_menu.tscn` before trusting a failure.
- UI text is **Indonesian**; systems code and identifiers are English.
- Tunable numbers belong in a named `const` block, never inline.
- Every script needs a `##` file header (`tests/test_script_documentation.gd` enforces this).
- The debug overlay is explicitly exempt from the design-system rules — it styles itself directly with `add_theme_*_override`, and new buttons there should match the surrounding code rather than use `ThemeFactory` variations.
- Commits use Conventional Commits with a scope, e.g. `feat(debug): add end-game rehearsal presets`.
- Existing baseline before this work: **771/772 tests pass**. The one known failure, `project_hygiene::test_the_boot_scene_is_the_main_menu` (`run/main_scene` is a UID rather than a path), predates this work and is out of scope — do not "fix" it, and do not count it as a regression.

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/Debug/EndGameRehearsal.gd` (create) | All rehearsal logic: preset roster construction, target math, GameState snapshot/restore, `arm()`. Pure static functions, no nodes. |
| `tests/test_end_game_rehearsal.gd` (create) | Behavioural tests for the above. Real assertions, not source scans — this file has no nodes and `GameState` resolves live in the runner (see `tests/test_economy_state.gd` for the save-and-restore-globals pattern). |
| `Scripts/Debug/DebugManager.gd` (modify, `_build_scenes_panel` at :1216) | Four new buttons in the Scenes tab that call `EndGameRehearsal` and teleport. No logic beyond wiring. |
| `tests/test_debug_manager.gd` (modify) | Source-scan tests for the new wiring, matching that suite's existing technique (DebugManager is not `@tool`, so it cannot be instantiated live). |
| `CLAUDE.md` (modify) | One short paragraph documenting the tool under "Working efficiently here", next to the existing Seed Playtest State guidance. |

---

### Task 1: Preset roster construction

**Files:**
- Create: `Scripts/Debug/EndGameRehearsal.gd`
- Test: `tests/test_end_game_rehearsal.gd`

**Interfaces:**
- Consumes: `Balance.TARGET_KENAIKAN_KELAS_7/8/9` (`Scripts/Balance.gd:31-33`).
- Produces:
  - `EndGameRehearsal.PRESET_LULUS/PRESET_GAGAL/PRESET_CAMPUR` — `String` constants.
  - `EndGameRehearsal.target_for_grade(grade: int) -> float`
  - `EndGameRehearsal.build_roster(preset: String, grade: int, source_students: Array) -> Array` — returns a fresh `Array` of student `Dictionary` in `GameState.approved_students` format.

- [ ] **Step 1: Write the failing test**

Create `tests/test_end_game_rehearsal.gd`:

```gdscript
@tool
extends McpTestSuite

## EndGameRehearsal is the debug-only end-of-grade jig. Unlike most suites
## here these are real behavioural tests rather than source scans: the file
## is plain static functions over Dictionaries with no nodes to
## instantiate, the same reason test_run_stats.gd tests RunStats directly.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "end_game_rehearsal"


## Two stand-in students in approved_students' dictionary format. Kept
## local so these tests never depend on DebugManager.DEFAULT_STUDENTS
## staying four entries long or keeping its current stat values.
func _fake_source() -> Array:
	return [
		{"id": 1, "name": "Satu", "akademis1": 1.0, "akademis2": 2.0,
			"akademis3": 3.0, "kepribadian1": 4.0, "kepribadian2": 5.0,
			"hobby_category": "Akademis"},
		{"id": 2, "name": "Dua", "akademis1": 6.0, "akademis2": 7.0,
			"akademis3": 8.0, "kepribadian1": 9.0, "kepribadian2": 10.0,
			"hobby_category": "Olahraga"},
	]


func test_target_tracks_the_grade_uplift() -> void:
	assert_eq(EndGameRehearsal.target_for_grade(7),
		EndGameRehearsal.BASE_SKILL + Balance.TARGET_KENAIKAN_KELAS_7,
		"grade 7 target is base + the grade 7 uplift")
	assert_eq(EndGameRehearsal.target_for_grade(8),
		EndGameRehearsal.BASE_SKILL + Balance.TARGET_KENAIKAN_KELAS_8,
		"grade 8 target is base + the grade 8 uplift")
	assert_eq(EndGameRehearsal.target_for_grade(9),
		EndGameRehearsal.BASE_SKILL + Balance.TARGET_KENAIKAN_KELAS_9,
		"grade 9 target is base + the grade 9 uplift")


func test_lulus_clears_every_target_for_every_student() -> void:
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_LULUS, 7, _fake_source())
	assert_eq(roster.size(), 2, "one entry per source student")
	for s in roster:
		for pair in [["akademis1", "target_akademis1"],
				["akademis2", "target_akademis2"],
				["akademis3", "target_akademis3"]]:
			assert_true(float(s[pair[0]]) >= float(s[pair[1]]),
				"%s must clear %s" % [s["name"], pair[1]])


func test_gagal_misses_every_target_for_every_student() -> void:
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_GAGAL, 7, _fake_source())
	for s in roster:
		for pair in [["akademis1", "target_akademis1"],
				["akademis2", "target_akademis2"],
				["akademis3", "target_akademis3"]]:
			assert_true(float(s[pair[0]]) < float(s[pair[1]]),
				"%s must miss %s" % [s["name"], pair[1]])


func test_campur_gives_each_slot_a_different_cleared_count() -> void:
	# Four source students so the whole 3/2/1/0 ladder is exercised.
	var source := _fake_source()
	source.append(source[0].duplicate())
	source.append(source[1].duplicate())
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_CAMPUR, 7, source)
	var counts: Array = []
	for s in roster:
		var cleared := 0
		if float(s["akademis1"]) >= float(s["target_akademis1"]): cleared += 1
		if float(s["akademis2"]) >= float(s["target_akademis2"]): cleared += 1
		if float(s["akademis3"]) >= float(s["target_akademis3"]): cleared += 1
		counts.append(cleared)
	# Asserted slot by slot rather than as one array compare: a typed-array
	# equality failure reports "expected [3,2,1,0] got [3,2,1,1]" with no
	# hint which student drifted.
	assert_eq(counts.size(), 4, "one count per student")
	assert_eq(counts[0], 3, "slot 0 clears all three -- the 3-star card")
	assert_eq(counts[1], 2, "slot 1 clears two -- the 2-star card")
	assert_eq(counts[2], 1, "slot 2 clears one -- the 1-star card")
	assert_eq(counts[3], 0, "slot 3 clears none -- the 0-star card")


func test_build_roster_does_not_mutate_its_source() -> void:
	var source := _fake_source()
	EndGameRehearsal.build_roster(EndGameRehearsal.PRESET_LULUS, 7, source)
	assert_eq(source[0]["akademis1"], 1.0,
		"the source roster must be copied, never written through")


func test_roster_keeps_identity_fields_and_sets_base_stats() -> void:
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_LULUS, 7, _fake_source())
	assert_eq(roster[0]["name"], "Satu", "names carry over")
	assert_eq(roster[0]["id"], 1, "ids carry over")
	assert_eq(roster[0]["kepribadian1"], EndGameRehearsal.REHEARSAL_MOOD,
		"mood is set to the rehearsal value, not the source's")
	assert_eq(roster[0]["kepribadian2"], EndGameRehearsal.REHEARSAL_ENERGY,
		"energy is set to the rehearsal value, not the source's")
	assert_eq(roster[0]["base_akademis1"], EndGameRehearsal.BASE_SKILL,
		"base_* must be set so a later initialize_grade_targets() " +
		"recomputes the same targets instead of moving them")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_game_rehearsal")`
Expected: FAIL — the suite errors or every test fails on `EndGameRehearsal` not existing.

- [ ] **Step 3: Write the minimal implementation**

Create `Scripts/Debug/EndGameRehearsal.gd`:

```gdscript
class_name EndGameRehearsal
extends RefCounted

## Debug-only jig for the end-of-grade sequence: builds a fixed, known
## roster so TesNotice -> ExamProgress -> CutScene -> SemesterEnd ->
## RunResult can be rehearsed in one click instead of played for six to
## sixteen weeks.
##
## Nothing in the shipped game calls this file -- DebugManager's Scenes
## tab is its only caller. Everything it writes to GameState is captured
## by snapshot() first and undone by restore(), so arming a rehearsal
## mid-run does not cost the run.
##
## Plain static functions over Dictionaries, no nodes, which is why
## tests/test_end_game_rehearsal.gd can test it behaviourally rather than
## by source scan the way DebugManager has to be tested.

## The three fixed outcomes the debug overlay offers.
const PRESET_LULUS := "lulus"
const PRESET_GAGAL := "gagal"
const PRESET_CAMPUR := "campur"

# ── Tunables ──────────────────────────────────────────────────────────────────
## Base skill value every rehearsal student starts from. Targets are
## derived as base + the grade's uplift -- the same arithmetic
## GameState.initialize_grade_targets() does -- so one number keeps the
## presets correct at grade 7, 8 and 9 instead of three hardcoded sets.
const BASE_SKILL := 45.0
## How far above its target a "cleared" skill sits.
const CLEAR_MARGIN := 10.0
## How far below its target a "missed" skill sits.
const MISS_MARGIN := 20.0
## Mood and energy every rehearsal student carries. Comfortably above the
## energy <= 5 threshold that would force an "Izin" day, so nothing the
## sequence passes through second-guesses the roster.
const REHEARSAL_MOOD := 70.0
const REHEARSAL_ENERGY := 70.0

## How many of the three skills each student clears, by slot in the
## roster. The campur ladder is deliberate: one card per star rating, so
## the SemesterEnd carousel shows 3-, 2-, 1- and 0-star detail popups and
## both stamp kinds in a single pass. Slots past the end of the list
## repeat its last entry, so a roster of any size still works.
const CLEARED_COUNTS := {
	PRESET_LULUS: [3, 3, 3, 3],
	PRESET_GAGAL: [0, 0, 0, 0],
	PRESET_CAMPUR: [3, 2, 1, 0],
}

## Skill keys in the order CLEARED_COUNTS counts them, paired with the
## target key each is checked against. Mirrors GameState's own naming
## quirk: akademis2 is Seni Budaya, akademis3 is Olahraga.
const SKILL_KEYS := [
	["akademis1", "base_akademis1", "target_akademis1"],
	["akademis2", "base_akademis2", "target_akademis2"],
	["akademis3", "base_akademis3", "target_akademis3"],
]


## The target every skill is measured against for `grade`. Duplicates
## GameState.initialize_grade_targets()'s uplift table rather than calling
## it, because that function works in place on GameState.approved_students
## and this one must stay pure.
static func target_for_grade(grade: int) -> float:
	var uplift := Balance.TARGET_KENAIKAN_KELAS_7
	match grade:
		8: uplift = Balance.TARGET_KENAIKAN_KELAS_8
		9: uplift = Balance.TARGET_KENAIKAN_KELAS_9
	return clampf(BASE_SKILL + uplift, 0.0, 100.0)


## Builds a rehearsal roster in approved_students' dictionary format.
## `source_students` supplies identity only (id, name, portrait, splash,
## quirk, persona, hobby_category and anything else the screens read);
## every stat is overwritten. The source is deep-copied, never mutated.
static func build_roster(preset: String, grade: int,
		source_students: Array) -> Array:
	var counts: Array = CLEARED_COUNTS.get(preset, CLEARED_COUNTS[PRESET_CAMPUR])
	var target := target_for_grade(grade)
	var cleared_value := clampf(target + CLEAR_MARGIN, 0.0, 100.0)
	var missed_value := clampf(target - MISS_MARGIN, 0.0, 100.0)

	var roster: Array = []
	for i in range(source_students.size()):
		var student: Dictionary = source_students[i].duplicate(true)
		var cleared: int = int(counts[mini(i, counts.size() - 1)])

		for s in range(SKILL_KEYS.size()):
			var value := cleared_value if s < cleared else missed_value
			student[SKILL_KEYS[s][0]] = value
			# base_* is what initialize_grade_targets() derives targets
			# from; setting it keeps the targets stable if any screen
			# recomputes them after the rehearsal is armed.
			student[SKILL_KEYS[s][1]] = BASE_SKILL
			student[SKILL_KEYS[s][2]] = target

		student["kepribadian1"] = REHEARSAL_MOOD
		student["kepribadian2"] = REHEARSAL_ENERGY
		roster.append(student)

	return roster
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_game_rehearsal")`
Expected: PASS, 6 tests.

If the suite reports "Nonexistent function" or cannot see `EndGameRehearsal`, the editor is serving stale bytecode or has not registered the new `class_name`: run `filesystem_manage(op="scan")` again, then a no-op `script_patch` on `Scripts/Debug/EndGameRehearsal.gd` (add a blank line, remove it).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Debug/EndGameRehearsal.gd tests/test_end_game_rehearsal.gd
git commit -m "feat(debug): add end-game rehearsal roster presets

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: GameState snapshot and restore

**Files:**
- Modify: `Scripts/Debug/EndGameRehearsal.gd`
- Test: `tests/test_end_game_rehearsal.gd`

**Interfaces:**
- Consumes: Task 1's constants.
- Produces:
  - `EndGameRehearsal.snapshot() -> Dictionary`
  - `EndGameRehearsal.restore(snap: Dictionary) -> bool` — returns `false` for an empty/absent snapshot, `true` when it restored.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_end_game_rehearsal.gd`:

```gdscript
# ─────────────────────────────────────────────────────── snapshot / restore

## These tests write to the GameState autoload, so each one restores what
## it touched before returning -- the same discipline test_economy_state.gd
## uses. A snapshot taken at the top and restored at the bottom is exactly
## the feature under test, so the tests deliberately do it by hand instead.
func test_snapshot_then_restore_round_trips_the_roster() -> void:
	var original_roster: Array = GameState.approved_students.duplicate(true)
	var original_week: int = GameState.minggu_ke
	var original_grade: int = GameState.current_grade

	GameState.approved_students = [{"id": 99, "name": "Asli", "akademis1": 11.0}]
	GameState.minggu_ke = 3
	GameState.current_grade = 8

	var snap := EndGameRehearsal.snapshot()

	GameState.approved_students = [{"id": 1, "name": "Palsu"}]
	GameState.minggu_ke = 12
	GameState.current_grade = 9

	assert_true(EndGameRehearsal.restore(snap), "restore reports success")
	assert_eq(GameState.approved_students.size(), 1, "roster length is back")
	assert_eq(GameState.approved_students[0]["name"], "Asli", "roster is back")
	assert_eq(GameState.minggu_ke, 3, "week is back")
	assert_eq(GameState.current_grade, 8, "grade is back")

	GameState.approved_students = original_roster
	GameState.current_grade = original_grade
	GameState.minggu_ke = original_week


func test_snapshot_deep_copies_so_later_edits_do_not_leak_in() -> void:
	var original_roster: Array = GameState.approved_students.duplicate(true)

	GameState.approved_students = [{"id": 1, "name": "Asli", "akademis1": 11.0}]
	var snap := EndGameRehearsal.snapshot()
	# Mutate the live dictionary in place. A shallow snapshot would be
	# holding this same Dictionary and would "restore" the mutation.
	GameState.approved_students[0]["akademis1"] = 99.0

	EndGameRehearsal.restore(snap)
	assert_eq(GameState.approved_students[0]["akademis1"], 11.0,
		"the snapshot must hold its own copy of each student dictionary")

	GameState.approved_students = original_roster


func test_restore_puts_back_run_stats_and_the_end_game_flags() -> void:
	var original_stats: RunStats = GameState.run_stats
	var original_failed: bool = GameState.run_failed
	var original_exam: bool = GameState.is_exam_intro_cutscene

	GameState.run_stats = RunStats.new()
	GameState.run_stats.minigames_won = 7
	GameState.run_failed = false
	GameState.is_exam_intro_cutscene = false

	var snap := EndGameRehearsal.snapshot()

	GameState.run_stats = RunStats.new()
	GameState.run_failed = true
	GameState.is_exam_intro_cutscene = true

	EndGameRehearsal.restore(snap)
	assert_eq(GameState.run_stats.minigames_won, 7, "the tally is back")
	assert_false(GameState.run_failed, "run_failed is back")
	assert_false(GameState.is_exam_intro_cutscene, "the exam flag is back")

	GameState.run_stats = original_stats
	GameState.run_failed = original_failed
	GameState.is_exam_intro_cutscene = original_exam


func test_restore_refuses_an_empty_snapshot() -> void:
	assert_false(EndGameRehearsal.restore({}),
		"restoring nothing must be a reported no-op, not a wipe")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_game_rehearsal")`
Expected: FAIL with "Invalid call. Nonexistent function 'snapshot'".

- [ ] **Step 3: Write the minimal implementation**

Append to `Scripts/Debug/EndGameRehearsal.gd`:

```gdscript
# ─────────────────────────────────────────────────────── snapshot / restore

## Every GameState field a rehearsal can move, directly or through the
## sequence it starts. RunResult's own progression is the reason this list
## is longer than what arm() writes: a rehearsal that runs to completion
## advances the grade, clears schedules, resets run_stats and may clear the
## roster, so all of that has to be captured up front.
const SNAPSHOT_KEYS := [
	"approved_students", "selected_student", "day_schedules",
	"pending_earnings", "grade7_student_ids", "inventory",
	"minggu_ke", "current_grade", "player_money",
	"run_failed", "is_exam_intro_cutscene", "is_game_beaten",
	"lobby_tutorial_completed", "tutorials_bypassed",
	"returned_from_student_card",
]


## Captures the current run. Collections are deep-copied and run_stats is
## duplicated, so nothing the rehearsal does afterwards writes through into
## the snapshot.
static func snapshot() -> Dictionary:
	var snap := {}
	for key in SNAPSHOT_KEYS:
		var value = GameState.get(key)
		if value is Array or value is Dictionary:
			snap[key] = value.duplicate(true)
		else:
			snap[key] = value
	snap["run_stats"] = GameState.run_stats.duplicate(true)
	return snap


## Puts a snapshot() back. Returns false (and changes nothing) for an empty
## dictionary, so a "restore" pressed before anything was ever armed is a
## logged no-op rather than a wipe.
##
## Known limitation, deliberate: assigning `inventory` back does not emit
## GameState.inventory_changed, so an Inventory screen left open across a
## restore keeps its old grid until it rebuilds. Restoring is a debug
## action taken from the overlay, before navigating anywhere, so the case
## does not arise in practice -- and emitting the signal here would fire it
## at screens mid-teardown.
static func restore(snap: Dictionary) -> bool:
	if snap.is_empty():
		return false

	# current_grade first: its setter recomputes max_minggu, so restoring
	# it after minggu_ke would leave the pair briefly inconsistent.
	if snap.has("current_grade"):
		GameState.current_grade = snap["current_grade"]

	for key in SNAPSHOT_KEYS:
		if key == "current_grade" or not snap.has(key):
			continue
		var value = snap[key]
		if value is Array or value is Dictionary:
			GameState.set(key, value.duplicate(true))
		else:
			GameState.set(key, value)

	if snap.has("run_stats") and snap["run_stats"] != null:
		GameState.run_stats = snap["run_stats"].duplicate(true)

	return true
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_game_rehearsal")`
Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Debug/EndGameRehearsal.gd tests/test_end_game_rehearsal.gd
git commit -m "feat(debug): snapshot and restore GameState around a rehearsal

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Arming the rehearsal

**Files:**
- Modify: `Scripts/Debug/EndGameRehearsal.gd`
- Test: `tests/test_end_game_rehearsal.gd`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces:
  - `EndGameRehearsal.ENTRY_SCENE` — `String`, `"res://Scenes/EndGame/TesNotice.tscn"`.
  - `EndGameRehearsal.arm(preset: String, source_students: Array) -> void`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_end_game_rehearsal.gd`:

```gdscript
# ───────────────────────────────────────────────────────────────── arming

func test_entry_scene_is_the_tes_besar_notice() -> void:
	assert_eq(EndGameRehearsal.ENTRY_SCENE,
		"res://Scenes/EndGame/TesNotice.tscn",
		"the rehearsal starts at the Tes Besar notice, not mid-sequence")
	assert_true(ResourceLoader.exists(EndGameRehearsal.ENTRY_SCENE),
		"the entry scene must actually exist")


func test_arm_lands_on_the_final_week_with_a_clean_sequence_state() -> void:
	var snap := EndGameRehearsal.snapshot()

	GameState.current_grade = 7
	GameState.minggu_ke = 2
	GameState.run_failed = true
	GameState.is_exam_intro_cutscene = true
	GameState.day_schedules = {"stale": true}

	EndGameRehearsal.arm(EndGameRehearsal.PRESET_LULUS, _fake_source())

	assert_eq(GameState.minggu_ke, GameState.max_minggu,
		"arming lands on the grade's final week, where the sequence fires")
	assert_false(GameState.run_failed,
		"a fresh rehearsal must not inherit a previous run's verdict")
	assert_false(GameState.is_exam_intro_cutscene,
		"the cutscene flag is ExamProgress's to set, not arm()'s")
	assert_true(GameState.day_schedules.is_empty(),
		"stale schedules are cleared -- the rehearsal simulates no weeks")
	assert_eq(GameState.approved_students.size(), 2, "the roster is armed")
	assert_true(GameState.returned_from_student_card,
		"screens that gate on roster approval must see it as approved")

	EndGameRehearsal.restore(snap)


func test_arm_makes_the_lulus_preset_actually_pass_the_stat_check() -> void:
	var snap := EndGameRehearsal.snapshot()

	GameState.current_grade = 7
	EndGameRehearsal.arm(EndGameRehearsal.PRESET_LULUS, _fake_source())
	assert_true(GameState.check_semester_passed(),
		"the lulus preset must satisfy the real pass condition")

	EndGameRehearsal.restore(snap)


func test_arm_makes_the_gagal_preset_actually_fail_the_stat_check() -> void:
	var snap := EndGameRehearsal.snapshot()

	GameState.current_grade = 7
	EndGameRehearsal.arm(EndGameRehearsal.PRESET_GAGAL, _fake_source())
	assert_false(GameState.check_semester_passed(),
		"the gagal preset must fail the real pass condition")

	EndGameRehearsal.restore(snap)


func test_arm_seeds_a_run_stats_tally_matched_to_the_preset() -> void:
	var snap := EndGameRehearsal.snapshot()

	GameState.current_grade = 7
	EndGameRehearsal.arm(EndGameRehearsal.PRESET_LULUS, _fake_source())
	var winning := GameState.run_stats.minigame_win_rate()

	EndGameRehearsal.arm(EndGameRehearsal.PRESET_GAGAL, _fake_source())
	var losing := GameState.run_stats.minigame_win_rate()

	assert_true(winning > losing,
		"the lulus preset must out-score the gagal one on minigames, or " +
		"RunGrade's non-target components never leave their floor")
	assert_true(GameState.run_stats.wirausaha_money > 0,
		"money must be non-zero or the money component is always 0/15")

	EndGameRehearsal.restore(snap)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_game_rehearsal")`
Expected: FAIL with "Nonexistent function 'arm'" / missing `ENTRY_SCENE`.

- [ ] **Step 3: Write the minimal implementation**

Append to `Scripts/Debug/EndGameRehearsal.gd`:

```gdscript
# ───────────────────────────────────────────────────────────────── arming

## Where a rehearsal starts. The whole point of the tool is that it enters
## at the notice and runs the REAL sequence from there, rather than
## teleporting into SemesterEnd and skipping the beats before it.
const ENTRY_SCENE := "res://Scenes/EndGame/TesNotice.tscn"

## Plausible per-preset tallies for GameState.run_stats.
##
## RunGrade weights targets 55%, minigame win-rate 20%, wirausaha money 15%
## and event participation 10% (Scripts/EndGame/RunGrade.gd:15-21). An
## empty tally would therefore cap even a perfect roster near a C+ and hide
## the A-range the lulus preset exists to show, so each preset carries a
## tally matching its ambition. `money` is measured against
## RunGrade.MONEY_FULL_MARKS (20000).
const REHEARSAL_STATS := {
	PRESET_LULUS: {
		"won": 8, "lost": 1, "points": 64.0, "items": 6,
		"money": 24000, "events": 4,
	},
	PRESET_GAGAL: {
		"won": 1, "lost": 7, "points": -22.0, "items": 1,
		"money": 4000, "events": 1,
	},
	PRESET_CAMPUR: {
		"won": 5, "lost": 4, "points": 18.0, "items": 3,
		"money": 12000, "events": 2,
	},
}


## Writes the rehearsal state onto GameState. Call snapshot() FIRST if the
## current run matters -- this overwrites the roster, the week and the
## tally without asking.
static func arm(preset: String, source_students: Array) -> void:
	var roster := build_roster(preset, GameState.current_grade, source_students)
	GameState.approved_students = roster
	GameState.selected_student = roster[0] if not roster.is_empty() else {}
	GameState.returned_from_student_card = true

	# The sequence only fires on the grade's final week, and SchoolDay
	# compares minggu_ke against max_minggu to decide that -- so land there,
	# and clear the schedules for weeks this rehearsal never played.
	GameState.day_schedules.clear()
	GameState.minggu_ke = GameState.max_minggu

	# Both flags belong to the sequence itself: SemesterEnd sets run_failed
	# from its own stat check, ExamProgress arms the cutscene branch.
	GameState.run_failed = false
	GameState.is_exam_intro_cutscene = false

	_seed_run_stats(preset, roster)


static func _seed_run_stats(preset: String, roster: Array) -> void:
	var spec: Dictionary = REHEARSAL_STATS.get(preset,
		REHEARSAL_STATS[PRESET_CAMPUR])
	var stats := RunStats.new()
	stats.minigames_won = int(spec["won"])
	stats.minigames_lost = int(spec["lost"])
	stats.minigame_points = float(spec["points"])
	stats.items_used = int(spec["items"])
	stats.wirausaha_money = int(spec["money"])
	# Event ids have to be real roster ids: RunGrade scores them as a
	# fraction of roster size, and RunResult lists them by student.
	var wanted: int = mini(int(spec["events"]), roster.size())
	for i in range(wanted):
		stats.record_event_student(int(roster[i].get("id", i + 1)))
	GameState.run_stats = stats
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `filesystem_manage(op="scan")` then `test_run(suite="end_game_rehearsal")`
Expected: PASS, 15 tests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Debug/EndGameRehearsal.gd tests/test_end_game_rehearsal.gd
git commit -m "feat(debug): arm the end-game sequence from a preset

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Debug overlay buttons

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd` (`_build_scenes_panel`, starts at :1216; the scene list is at :1241-1252)
- Test: `tests/test_debug_manager.gd`

**Interfaces:**
- Consumes: `EndGameRehearsal.PRESET_*`, `arm()`, `snapshot()`, `restore()`, `ENTRY_SCENE`; `DebugManager.DEFAULT_STUDENTS` (:30), `DebugManager._teleport_to_scene()` (:1262), `DebugManager.log_message()`.
- Produces: `DebugManager._rehearsal_snapshot` (`Dictionary`), `_start_end_game_rehearsal(preset: String)`, `_restore_before_rehearsal()`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_debug_manager.gd`:

```gdscript
# ──────────────────────────────────────────────── end-game rehearsal wiring

func test_rehearsal_buttons_exist_for_all_three_presets() -> void:
	var body := _function_body(_source(), "_build_scenes_panel")
	for preset in ["PRESET_LULUS", "PRESET_GAGAL", "PRESET_CAMPUR"]:
		assert_true(body.contains("EndGameRehearsal." + preset),
			"the Scenes tab must offer the %s preset" % preset)
	assert_true(body.contains("_restore_before_rehearsal"),
		"the Scenes tab must offer the restore button too, or an armed " +
		"rehearsal has no way back to the run it replaced")


func test_the_bare_semester_end_teleport_is_gone() -> void:
	var body := _function_body(_source(), "_build_scenes_panel")
	assert_false(body.contains("res://Scenes/EndGame/SemesterEnd.tscn"),
		"the bare SemesterEnd teleport was replaced by the rehearsal " +
		"buttons -- it landed on an empty carousel, because the screen " +
		"builds its cards from GameState.approved_students")


func test_rehearsal_snapshots_before_it_overwrites_anything() -> void:
	var body := _function_body(_source(), "_start_end_game_rehearsal")
	var snap_at := body.find("EndGameRehearsal.snapshot()")
	var arm_at := body.find("EndGameRehearsal.arm(")
	assert_true(snap_at != -1, "the rehearsal must snapshot the run")
	assert_true(arm_at != -1, "the rehearsal must arm a preset")
	assert_true(snap_at < arm_at,
		"the snapshot must be taken BEFORE arm() overwrites GameState, " +
		"or the run being rehearsed over is unrecoverable")


func test_rehearsal_enters_at_the_notice_scene() -> void:
	var body := _function_body(_source(), "_start_end_game_rehearsal")
	assert_true(body.contains("_teleport_to_scene(EndGameRehearsal.ENTRY_SCENE)"),
		"the rehearsal must enter at EndGameRehearsal.ENTRY_SCENE so the " +
		"real sequence runs from the notice, not from mid-sequence")


func test_restore_handler_clears_the_snapshot_after_using_it() -> void:
	var body := _function_body(_source(), "_restore_before_rehearsal")
	assert_true(body.contains("EndGameRehearsal.restore(_rehearsal_snapshot)"),
		"restore must hand back the stored snapshot")
	assert_true(body.contains("_rehearsal_snapshot = {}"),
		"the snapshot must be cleared once spent, so a second press " +
		"cannot re-apply a now-stale run")


## The ratchet on requirement 4: the rehearsal is a debug jig, and a
## reference to it from a shipped screen would mean it had leaked into the
## real game loop.
func test_nothing_in_the_shipped_game_calls_the_rehearsal() -> void:
	var offenders: Array[String] = []
	_scan_for_rehearsal_callers("res://Scripts", offenders)
	assert_eq(offenders.size(), 0,
		"EndGameRehearsal is debug-only; found shipped callers in: "
			+ ", ".join(offenders))


## Walks res://Scripts for references to EndGameRehearsal outside
## Scripts/Debug/, which is the only directory allowed to name it.
func _scan_for_rehearsal_callers(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != "Debug":
				_scan_for_rehearsal_callers(full, out)
		elif entry.ends_with(".gd"):
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null and f.get_as_text().contains("EndGameRehearsal"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `filesystem_manage(op="scan")` then `test_run(suite="debug_manager")`
Expected: FAIL — `_function_body` returns "" for the two missing handlers, so the `contains` assertions fail.

- [ ] **Step 3: Write the minimal implementation**

First, **remove the bare SemesterEnd teleport entry** from `scenes_list` (:1249) — the rehearsal buttons replace it. Delete this line:

```gdscript
		{"name": "Evaluasi Semester (SemesterEnd)", "path": "res://Scenes/EndGame/SemesterEnd.tscn"},
```

It was never useful on its own: teleporting to SemesterEnd with no roster armed lands on an empty carousel, because the screen builds its cards from `GameState.approved_students`. Every reason to press it is better served by a rehearsal, which arms real stats first. Leave the other end-game teleports (TesNotice, ExamProgress, RunResult) alone.

Then, inside `_build_scenes_panel`, immediately after the `for sc in scenes_list:` loop that ends at :1260 (before the closing of the function), add:

```gdscript

	var sep_rehearsal = HSeparator.new()
	vbox.add_child(sep_rehearsal)

	var lbl_rehearsal = Label.new()
	lbl_rehearsal.text = "Gladi Resik Akhir Kelas (mulai dari Notice Tes Besar):"
	lbl_rehearsal.add_theme_font_size_override("font_size", 26)
	vbox.add_child(lbl_rehearsal)

	var rehearsals = [
		{"name": "Semua Lulus", "preset": EndGameRehearsal.PRESET_LULUS},
		{"name": "Semua Gagal", "preset": EndGameRehearsal.PRESET_GAGAL},
		{"name": "Campur (3/2/1/0 bintang)", "preset": EndGameRehearsal.PRESET_CAMPUR},
	]
	for r in rehearsals:
		var btn_r = Button.new()
		btn_r.text = " 🎭 Gladi Resik: " + r["name"]
		btn_r.custom_minimum_size = Vector2(0, 95)
		btn_r.add_theme_font_size_override("font_size", 21)
		btn_r.pressed.connect(func(): _start_end_game_rehearsal(r["preset"]))
		vbox.add_child(btn_r)

	var btn_restore = Button.new()
	btn_restore.text = " ↩ Pulihkan Run Sebelum Gladi Resik "
	btn_restore.custom_minimum_size = Vector2(0, 95)
	btn_restore.add_theme_font_size_override("font_size", 21)
	btn_restore.pressed.connect(_restore_before_rehearsal)
	vbox.add_child(btn_restore)
```

Then add the two handlers immediately after `_teleport_to_scene()` (which ends around :1280):

```gdscript

## The run that was in progress when the last rehearsal was armed. Empty
## when nothing is stashed -- _restore_before_rehearsal() reports that
## rather than wiping the current run with a blank snapshot.
var _rehearsal_snapshot: Dictionary = {}

## Arms a fixed roster and enters the end-of-grade sequence at its first
## screen. The snapshot MUST be taken before arm() -- that is the whole
## "doesn't interrupt the main game" guarantee, and the ordering is pinned
## by test_debug_manager.gd.
func _start_end_game_rehearsal(preset: String) -> void:
	_rehearsal_snapshot = EndGameRehearsal.snapshot()
	EndGameRehearsal.arm(preset, DEFAULT_STUDENTS)
	log_message("Gladi resik akhir kelas armed: preset '%s', %s, minggu %d/%d. Run sebelumnya disimpan." % [
		preset, GameState.get_grade_name(), GameState.minggu_ke, GameState.max_minggu])
	_refresh_ui_fields()
	_teleport_to_scene(EndGameRehearsal.ENTRY_SCENE)

## Puts back the run the last rehearsal replaced, then forgets it: the
## stashed state describes a moment that has now passed, and re-applying it
## twice would silently rewind whatever happened in between.
func _restore_before_rehearsal() -> void:
	if not EndGameRehearsal.restore(_rehearsal_snapshot):
		log_message("Tidak ada run tersimpan -- gladi resik belum pernah dijalankan.")
		return
	_rehearsal_snapshot = {}
	log_message("Run sebelum gladi resik dipulihkan: %s, minggu %d." % [
		GameState.get_grade_name(), GameState.minggu_ke])
	_refresh_ui_fields()
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `filesystem_manage(op="scan")` then `test_run(suite="debug_manager")`
Expected: PASS, including the 6 new tests. Then confirm nothing else broke: `test_run(suite="end_game_rehearsal")` — still 15 passing.

- [ ] **Step 5: Verify it live, once**

This is the one step a source scan cannot cover — that the buttons render and the sequence actually runs.

1. `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, then `project_run(mode="main")`.
2. Open the overlay (`F1`, or five taps in the top-right corner), go to the **Scenes** tab, scroll to "Gladi Resik Akhir Kelas".
3. Press **Gladi Resik: Campur**. Expected: the Tes Besar notice appears, auto-advances to ExamProgress, then the exam cutscene, then SemesterEnd showing four cards — one LULUS stamp, three TIDAK LULUS — and the Detail popup showing 3, 2, 1 and 0 stars across the four cards.
4. Finish through to RunResult, then reopen the overlay and press **Pulihkan Run Sebelum Gladi Resik**. Expected: the log line reports the restored grade and week.
5. `project_manage(op="stop")`.

If a screenshot is needed to judge the carousel, use `editor_screenshot(source="game")`; remember a backgrounded window returns `stale_frame: true`, so focus it and retry rather than trusting the first frame.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Debug/DebugManager.gd tests/test_debug_manager.gd
git commit -m "feat(debug): add end-game rehearsal buttons to the Scenes tab

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Document it and verify the whole suite

**Files:**
- Modify: `CLAUDE.md` ("Working efficiently here", rule 1, next to the Seed Playtest State paragraph)

**Interfaces:**
- Consumes: everything above. Produces: nothing code-facing.

- [ ] **Step 1: Add the documentation**

In `CLAUDE.md`, find rule **1. Never play the game to reach a state — seed it.** and append this paragraph at the end of that rule, right after the sentence ending "...still needs a pass through Atur Jadwal first.":

```markdown
The overlay's **Scenes** tab also carries **🎭 Gladi Resik Akhir Kelas** —
three one-click rehearsals of the whole end-of-grade sequence (TesNotice →
ExamProgress → CutScene → SemesterEnd → RunResult) with a fixed roster:
*Semua Lulus* (win path), *Semua Gagal* (lose path), and *Campur*, which
ladders 3/2/1/0 cleared targets across the four students so one pass of the
SemesterEnd carousel shows both stamp kinds and every star rating. Arming
one snapshots the run first; **↩ Pulihkan Run Sebelum Gladi Resik** puts it
back, which matters because RunResult's progression otherwise advances the
grade and clears the roster on its way out. These replaced the bare
"Teleport ke: Evaluasi Semester" button, which landed on an empty carousel
whenever no roster was approved. The logic is in
`Scripts/Debug/EndGameRehearsal.gd` (plain static functions, tested
behaviourally in `tests/test_end_game_rehearsal.gd`); `DebugManager.gd`
only holds the buttons.
```

- [ ] **Step 2: Run the full suite**

Run: `filesystem_manage(op="scan")`, `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, then `test_run()` with no suite filter.

Expected: **793 total, 792 passing, 1 failing** — 772 before this work (of which 771 passed), plus 15 new tests in `end_game_rehearsal` and 6 in `debug_manager`. The single expected failure is the pre-existing `project_hygiene::test_the_boot_scene_is_the_main_menu`. Any other failure is a regression from this work and must be fixed before the commit.

If the count is short, `filesystem_manage(op="scan")` and re-run before debugging — the runner serves stale bytecode after external file writes.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(debug): document the end-game rehearsal presets

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
