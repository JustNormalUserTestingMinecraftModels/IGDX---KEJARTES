# End-of-Grade Sequence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the player finishes the final week of a grade, run a five-screen
ceremony — Tes Besar notice → exam cutscene → stat check → win/lose screen →
run result — and end the run at the main menu with a letter-graded report of
everything the player did that grade.

**Architecture:** Two new autoload-level pieces (`GameState.run_stats`
counters, a `RunGrade` static scorer), three new scenes under
`Scenes/EndGame/`, one new branch on the existing cutscene, and a restyle of
`SemesterEnd.tscn`. Routing is a straight chain: each screen knows only the
next one. All run-level counters are session-scoped like the rest of
`GameState` — no persistence.

**Tech Stack:** Godot 4.6 (GDScript), the project's `DesignTokens` /
`ThemeFactory` theme system, `Juice.gd` + `AnimUtils.gd` for animation,
`AudioDirector` for BGM/SFX, `McpTestSuite` tests run in-editor via the
`godot-ai` MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-02-end-of-grade-sequence.md`

## Global Constraints

- Godot **4.6**, portrait 1080×1920, `mobile` renderer. All new scenes are
  `Control` roots at `anchors_preset = 15`.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation
  (`PrimaryButton`, `SecondaryButton`, `Card`, `Scrim`, `DisplayLabel`,
  `H1Label`, `H2Label`, `TitleLabel`, `CaptionLabel`, `ResultHeroLabel`,
  `ResultBodyLabel`, …). Only layout-only constant overrides
  (`separation`, `margin_*`) are permitted.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`;
  repeated rows are a `PackedScene` template.
- Every script needs a `##` file header and a `##` line on every `@export`
  (enforced by `tests/test_script_documentation.gd`).
- **Never hand-edit a `.tscn` while the Godot editor is attached.** Go through
  the MCP: `scene_open` → `node_create` / `node_set_property` → `scene_save`.
  `anchors_preset` is inert (set the four anchors); numbers must be unquoted.
- **Rescan (`filesystem_manage(op="scan")`) after editing any `.gd`, before
  `test_run`.** If a `.gd` was written from outside the editor, force a reload
  with a no-op `script_patch` on that file.
- Test suites must be `@tool`, extend `McpTestSuite`, and **must not be
  coroutines** — no `await` in any test body.
- All UI text and game-facing identifiers are **Indonesian**; systems code is
  English.
- Commits: Conventional Commits with a scope, e.g. `feat(endgame): …`.
- New tunable numbers go in a named `const` block or an `@export` — never
  inline.
- No new audio files. New audio ids alias onto existing tracks.
- **No emoji as UI iconography anywhere in this work.** Every icon is a real
  transparent texture asset in a `TextureRect`; every screen's copy is plain
  Indonesian prose. Task 9 strips the emoji already in SemesterEnd's strings,
  and Task 11 authors the six icons the report needs. Emoji in *code comments*
  and in the debug overlay are untouched — the ban is on what the player sees.

---

## File Structure

**Created**
| File | Responsibility |
|---|---|
| `Scripts/EndGame/RunStats.gd` | `class_name RunStats` — the per-grade counter record and its accumulate/reset API. Pure data + math, no nodes. |
| `Scripts/EndGame/RunGrade.gd` | `class_name RunGrade` — turns a `RunStats` + pass/fail into a 0–100 score and a letter (`A+`…`C-`, or `D`). Pure static functions. |
| `Scripts/EndGame/TesNotice.gd` / `Scenes/EndGame/TesNotice.tscn` | The "Tes dimulai" announcement screen. |
| `Scripts/EndGame/WinScreen.gd` / `Scenes/EndGame/WinScreen.tscn` | Cutscene-styled win dialogue. |
| `Scripts/EndGame/RunResult.gd` / `Scenes/EndGame/RunResult.tscn` | The run report: letter grade + stat rows + exit. |
| `Scripts/EndGame/RunResultRow.gd` / `Scenes/EndGame/RunResultRow.tscn` | One icon+label+value row template, count-up animated. The icon is a `TextureRect`, never a glyph. |
| `Assets/Images/UI/Placeholders/icon_minigame_menang.svg`, `icon_minigame_kalah.svg`, `icon_poin.svg`, `icon_barang.svg`, `icon_uang.svg`, `icon_event.svg` | The report's six transparent icons, hand-authored in the same one-line-SVG style as the folder's existing placeholders. |
| `tests/test_run_stats.gd` | RunStats + RunGrade math. |
| `tests/test_tes_notice.gd`, `tests/test_win_screen.gd`, `tests/test_run_result.gd` | Per-screen structure/routing scans. |

**Modified**
| File | Change |
|---|---|
| `Scripts/GameState.gd` | Holds `run_stats: RunStats`; resets it in `set_grade()`; records item use in `use_item()`; new `is_exam_intro_cutscene` and `run_failed` flags. |
| `Scripts/SchoolSimulation/StudentManager.gd` | `record_minigame_result()` also feeds `GameState.run_stats`. |
| `Scripts/SchoolSimulation/SchoolDay.gd` | Records wirausaha payout + event participation; final-week exit routes to TesNotice instead of SemesterEnd. |
| `Scripts/CutScene/cut_scene.gd` | Third branch: the exam cutscene. Game-over branch now exits to RunResult. |
| `Scripts/EndGame/SemesterEnd.gd` + `.tscn` | Restyled backdrop/copy; forward button routes to WinScreen or the lose cutscene; grade-progression logic moves out to RunResult. |
| `Scripts/Audio/AudioDirector.gd` | Three new BGM ids. |
| `tests/test_school_day.gd`, `tests/test_semester_end.gd`, `tests/test_cutscene.gd`, `tests/test_audio_coverage.gd` | Updated routing/audio expectations. |
| `CLAUDE.md` | "Loop" and "Current work" sections. |

---

## Task 1: `RunStats` — the per-grade counter record

**Files:**
- Create: `Scripts/EndGame/RunStats.gd`
- Test: `tests/test_run_stats.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name RunStats` (extends `Resource`) with fields
  `minigames_won: int`, `minigames_lost: int`, `minigame_points: float`,
  `items_used: int`, `wirausaha_money: int`, `event_student_ids: Array[int]`,
  and methods
  `record_minigame(won: bool, points: float) -> void`,
  `record_item_use(count: int = 1) -> void`,
  `record_wirausaha(amount: int) -> void`,
  `record_event_student(student_id: int) -> void`,
  `event_student_count() -> int`,
  `minigames_played() -> int`,
  `minigame_win_rate() -> float`,
  `reset() -> void`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_run_stats.gd`:

```gdscript
@tool
extends McpTestSuite

## Covers RunStats (the per-grade counter record) and RunGrade (the
## letter-grade scorer). Both are pure data/math with no nodes, so unlike
## most suites here these are real behavioural tests rather than
## source-text scans.

func suite_name() -> String:
	return "run_stats"


func test_new_run_stats_starts_at_zero() -> void:
	var s := RunStats.new()
	assert_eq(s.minigames_won, 0, "menang starts at 0")
	assert_eq(s.minigames_lost, 0, "kalah starts at 0")
	assert_eq(s.minigame_points, 0.0, "points start at 0")
	assert_eq(s.items_used, 0, "items start at 0")
	assert_eq(s.wirausaha_money, 0, "money starts at 0")
	assert_eq(s.event_student_count(), 0, "no event students yet")


func test_record_minigame_splits_wins_and_losses() -> void:
	var s := RunStats.new()
	s.record_minigame(true, 10.0)
	s.record_minigame(true, 8.0)
	s.record_minigame(false, -3.0)
	assert_eq(s.minigames_won, 2, "two wins counted")
	assert_eq(s.minigames_lost, 1, "one loss counted")
	assert_eq(s.minigame_points, 15.0, "points summed with sign")
	assert_eq(s.minigames_played(), 3, "played is the sum")


func test_minigame_win_rate_is_zero_when_nothing_played() -> void:
	var s := RunStats.new()
	assert_eq(s.minigame_win_rate(), 0.0, "no divide by zero")


func test_minigame_win_rate_is_wins_over_played() -> void:
	var s := RunStats.new()
	s.record_minigame(true, 1.0)
	s.record_minigame(false, 0.0)
	s.record_minigame(false, 0.0)
	s.record_minigame(false, 0.0)
	assert_eq(s.minigame_win_rate(), 0.25, "1 of 4")


func test_event_students_are_counted_once_each() -> void:
	var s := RunStats.new()
	s.record_event_student(3)
	s.record_event_student(3)
	s.record_event_student(7)
	assert_eq(s.event_student_count(), 2, "duplicates collapse")


func test_item_and_money_accumulate() -> void:
	var s := RunStats.new()
	s.record_item_use()
	s.record_item_use(2)
	s.record_wirausaha(1500)
	s.record_wirausaha(500)
	assert_eq(s.items_used, 3, "item uses summed")
	assert_eq(s.wirausaha_money, 2000, "money summed")


func test_reset_clears_everything() -> void:
	var s := RunStats.new()
	s.record_minigame(true, 10.0)
	s.record_item_use()
	s.record_wirausaha(100)
	s.record_event_student(1)
	s.reset()
	assert_eq(s.minigames_won, 0, "wins cleared")
	assert_eq(s.minigame_points, 0.0, "points cleared")
	assert_eq(s.items_used, 0, "items cleared")
	assert_eq(s.wirausaha_money, 0, "money cleared")
	assert_eq(s.event_student_count(), 0, "event students cleared")
```

- [ ] **Step 2: Run the test to verify it fails**

Via the `godot-ai` MCP:

```
filesystem_manage(op="scan")
test_run(suite="run_stats")
```

Expected: FAIL — `Identifier "RunStats" not declared in the current scope`.

- [ ] **Step 3: Write the implementation**

Create `Scripts/EndGame/RunStats.gd`:

```gdscript
class_name RunStats
extends Resource

## The per-grade tally the run-result screen reports on.
##
## One instance lives on GameState (`GameState.run_stats`) and is reset
## whenever a grade starts. It is written from four places that already
## know these events happen -- StudentManager.record_minigame_result(),
## GameState.use_item(), SchoolDay._pay_out_wirausaha(), and SchoolDay's
## event branch -- and read only by RunGrade and RunResult.
##
## Session-scoped, like everything else on GameState: this is a Resource
## for the typed fields and the Inspector, NOT because it is ever saved.

## Minigames the roster won this grade.
@export var minigames_won: int = 0
## Minigames the roster lost this grade.
@export var minigames_lost: int = 0
## Net stat points minigames awarded (wins) or deducted (losses).
@export var minigame_points: float = 0.0
## Successful GameState.use_item() applications this grade.
@export var items_used: int = 0
## Rupiah paid out from wirausaha this grade.
@export var wirausaha_money: int = 0
## Ids of students that appeared in at least one event. Stored as a list
## of unique ids rather than a count so re-recording the same student is
## idempotent -- SchoolDay's event branch can fire more than once per
## student per grade.
@export var event_student_ids: Array[int] = []


func record_minigame(won: bool, points: float) -> void:
	if won:
		minigames_won += 1
	else:
		minigames_lost += 1
	minigame_points += points


func record_item_use(count: int = 1) -> void:
	items_used += count


func record_wirausaha(amount: int) -> void:
	wirausaha_money += amount


func record_event_student(student_id: int) -> void:
	if not event_student_ids.has(student_id):
		event_student_ids.append(student_id)


func event_student_count() -> int:
	return event_student_ids.size()


func minigames_played() -> int:
	return minigames_won + minigames_lost


func minigame_win_rate() -> float:
	var played := minigames_played()
	if played <= 0:
		return 0.0
	return float(minigames_won) / float(played)


func reset() -> void:
	minigames_won = 0
	minigames_lost = 0
	minigame_points = 0.0
	items_used = 0
	wirausaha_money = 0
	event_student_ids.clear()
```

- [ ] **Step 4: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="run_stats")
```

Expected: PASS, 7 tests. If `RunStats` is still "not declared", the editor is
serving stale bytecode — apply a no-op `script_patch` to
`Scripts/EndGame/RunStats.gd` (add and remove a blank line) and re-run.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/RunStats.gd tests/test_run_stats.gd
git commit -m "feat(endgame): add the RunStats per-grade counter record"
```

---

## Task 2: `RunGrade` — the letter-grade scorer

**Files:**
- Create: `Scripts/EndGame/RunGrade.gd`
- Modify: `tests/test_run_stats.gd` (append tests)

**Interfaces:**
- Consumes: `RunStats` from Task 1 (`minigame_win_rate()`,
  `wirausaha_money`, `event_student_count()`).
- Produces: `class_name RunGrade` with statics
  `score(stats: RunStats, targets_cleared: int, targets_total: int, roster_size: int) -> float` (0–100),
  `letter(run_score: float, passed: bool) -> String`,
  `is_top_grade(letter_text: String) -> bool`.

**Scoring**, all weights in a named `const` block:

| Component | Weight | Full marks at |
|---|---|---|
| Targets cleared | 55 | every student cleared all three targets |
| Minigame win rate | 20 | 100% wins |
| Wirausaha money | 15 | `MONEY_FULL_MARKS` (20000) rupiah |
| Event participation | 10 | every student in the roster hit an event |

Letters (win only): `>=95 A+`, `>=88 A`, `>=80 A-`, `>=72 B+`, `>=64 B`,
`>=56 B-`, `>=48 C+`, `>=40 C`, else `C-`. A loss is always `D`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_stats.gd`:

```gdscript
func _perfect_stats() -> RunStats:
	var s := RunStats.new()
	for i in range(10):
		s.record_minigame(true, 10.0)
	s.record_wirausaha(RunGrade.MONEY_FULL_MARKS)
	for i in range(4):
		s.record_event_student(i)
	return s


func test_perfect_run_scores_one_hundred() -> void:
	var s := _perfect_stats()
	assert_eq(RunGrade.score(s, 12, 12, 4), 100.0, "everything maxed")


func test_empty_run_scores_zero() -> void:
	var s := RunStats.new()
	assert_eq(RunGrade.score(s, 0, 12, 4), 0.0, "nothing done")


func test_score_is_clamped_to_one_hundred() -> void:
	var s := _perfect_stats()
	s.record_wirausaha(RunGrade.MONEY_FULL_MARKS * 5)
	assert_eq(RunGrade.score(s, 12, 12, 4), 100.0, "overshoot clamps")


func test_score_handles_empty_roster_without_dividing_by_zero() -> void:
	var s := RunStats.new()
	assert_eq(RunGrade.score(s, 0, 0, 0), 0.0, "no divide by zero")


func test_targets_dominate_the_score() -> void:
	var s := RunStats.new()
	assert_eq(RunGrade.score(s, 12, 12, 4), 55.0, "targets alone are worth 55")


func test_letter_is_d_when_the_run_failed() -> void:
	assert_eq(RunGrade.letter(100.0, false), "D", "a loss is always D")


func test_letter_bands_on_a_win() -> void:
	assert_eq(RunGrade.letter(96.0, true), "A+", "95+ is A+")
	assert_eq(RunGrade.letter(88.0, true), "A", "88 is A")
	assert_eq(RunGrade.letter(80.0, true), "A-", "80 is A-")
	assert_eq(RunGrade.letter(72.0, true), "B+", "72 is B+")
	assert_eq(RunGrade.letter(64.0, true), "B", "64 is B")
	assert_eq(RunGrade.letter(56.0, true), "B-", "56 is B-")
	assert_eq(RunGrade.letter(48.0, true), "C+", "48 is C+")
	assert_eq(RunGrade.letter(40.0, true), "C", "40 is C")
	assert_eq(RunGrade.letter(0.0, true), "C-", "below 40 is C-")


func test_is_top_grade_only_for_the_a_band() -> void:
	assert_true(RunGrade.is_top_grade("A+"), "A+ is top")
	assert_true(RunGrade.is_top_grade("A"), "A is top")
	assert_true(RunGrade.is_top_grade("A-"), "A- is top")
	assert_false(RunGrade.is_top_grade("B+"), "B+ is not top")
	assert_false(RunGrade.is_top_grade("D"), "D is not top")
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="run_stats")
```

Expected: FAIL — `Identifier "RunGrade" not declared in the current scope`.

- [ ] **Step 3: Write the implementation**

Create `Scripts/EndGame/RunGrade.gd`:

```gdscript
class_name RunGrade
extends RefCounted

## Turns a finished run into a 0-100 score and a letter grade.
##
## Pure static math over a RunStats plus the roster's target tally -- no
## nodes, no GameState reads, so it is cheap to test directly. RunResult
## is the only caller.
##
## A failed run is always "D", regardless of score: the letter is the
## player's reward for winning well, not a consolation for losing.

## Weights, summing to 100. Targets dominate on purpose -- clearing every
## student's three targets is the actual win condition; the rest is style.
const WEIGHT_TARGETS := 55.0
const WEIGHT_MINIGAMES := 20.0
const WEIGHT_MONEY := 15.0
const WEIGHT_EVENTS := 10.0

## Wirausaha rupiah that earns full marks on the money component.
const MONEY_FULL_MARKS := 20000

## Score floors for each letter, highest first. Read top-down.
const LETTER_BANDS := [
	[95.0, "A+"], [88.0, "A"], [80.0, "A-"],
	[72.0, "B+"], [64.0, "B"], [56.0, "B-"],
	[48.0, "C+"], [40.0, "C"],
]
const LETTER_FLOOR := "C-"
const LETTER_FAILED := "D"


static func score(stats: RunStats, targets_cleared: int, targets_total: int,
		roster_size: int) -> float:
	if stats == null:
		return 0.0

	var target_part := 0.0
	if targets_total > 0:
		target_part = WEIGHT_TARGETS * clampf(
			float(targets_cleared) / float(targets_total), 0.0, 1.0)

	var minigame_part := WEIGHT_MINIGAMES * clampf(
		stats.minigame_win_rate(), 0.0, 1.0)

	var money_part := WEIGHT_MONEY * clampf(
		float(stats.wirausaha_money) / float(MONEY_FULL_MARKS), 0.0, 1.0)

	var event_part := 0.0
	if roster_size > 0:
		event_part = WEIGHT_EVENTS * clampf(
			float(stats.event_student_count()) / float(roster_size), 0.0, 1.0)

	return clampf(target_part + minigame_part + money_part + event_part,
		0.0, 100.0)


static func letter(run_score: float, passed: bool) -> String:
	if not passed:
		return LETTER_FAILED
	for band in LETTER_BANDS:
		if run_score >= float(band[0]):
			return String(band[1])
	return LETTER_FLOOR


static func is_top_grade(letter_text: String) -> bool:
	return letter_text.begins_with("A")
```

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="run_stats")
```

Expected: PASS, 16 tests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/RunGrade.gd tests/test_run_stats.gd
git commit -m "feat(endgame): add the RunGrade letter-grade scorer"
```

---

## Task 3: Hang `run_stats` off GameState and record item use

**Files:**
- Modify: `Scripts/GameState.gd`
- Test: `tests/test_economy_state.gd` (append)

**Interfaces:**
- Consumes: `RunStats` from Task 1.
- Produces: `GameState.run_stats: RunStats` (never null),
  `GameState.is_exam_intro_cutscene: bool`,
  `GameState.run_failed: bool`,
  `GameState.count_targets_cleared() -> Array` returning `[cleared, total]`.
  `set_grade()` now also calls `run_stats.reset()` and clears both new flags.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_economy_state.gd`:

```gdscript
func test_gamestate_exposes_a_run_stats_record() -> void:
	assert_true(GameState.run_stats != null, "run_stats is never null")
	assert_true(GameState.run_stats is RunStats, "run_stats is a RunStats")


func test_using_an_item_records_it_in_run_stats() -> void:
	var before: int = GameState.run_stats.items_used
	var saved_roster: Array = GameState.approved_students.duplicate(true)
	var saved_inventory: Dictionary = GameState.inventory.duplicate(true)

	GameState.approved_students = [{
		"id": 4242, "name": "Uji", "mood": 10.0, "energy": 10.0,
	}]
	var item := ItemData.new()
	item.item_name = "UjiCoba"
	item.mood_boost = 5.0
	item.energy_boost = 5.0
	GameState.add_to_inventory("UjiCoba", 1)

	var result: Dictionary = GameState.use_item(item, 4242, 1)

	GameState.approved_students = saved_roster
	GameState.inventory = saved_inventory

	assert_true(result.get("applied", false), "the item applied")
	assert_eq(GameState.run_stats.items_used, before + 1,
		"a successful use bumps items_used")


func test_a_refused_item_use_does_not_record() -> void:
	var before: int = GameState.run_stats.items_used
	var item := ItemData.new()
	item.item_name = "TidakAda"
	var result: Dictionary = GameState.use_item(item, -1, 1)
	assert_false(result.get("applied", true), "refused")
	assert_eq(GameState.run_stats.items_used, before,
		"a refused use records nothing")


func test_set_grade_resets_the_run_stats() -> void:
	var saved_grade: int = GameState.current_grade
	GameState.run_stats.record_minigame(true, 10.0)
	GameState.set_grade(saved_grade)
	assert_eq(GameState.run_stats.minigames_won, 0,
		"starting a grade clears the tally")
	assert_false(GameState.is_exam_intro_cutscene,
		"the exam-cutscene flag clears with the grade")
	assert_false(GameState.run_failed, "the fail flag clears with the grade")


func test_count_targets_cleared_reports_cleared_and_total() -> void:
	var saved_roster: Array = GameState.approved_students.duplicate(true)
	GameState.approved_students = [{
		"id": 1, "name": "A",
		"akademis1": 90.0, "akademis2": 90.0, "akademis3": 10.0,
		"target_akademis1": 50.0, "target_akademis2": 50.0,
		"target_akademis3": 50.0,
	}]
	var counted: Array = GameState.count_targets_cleared()
	GameState.approved_students = saved_roster
	assert_eq(counted[0], 2, "two of three targets cleared")
	assert_eq(counted[1], 3, "three targets total for one student")
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="economy_state")
```

Expected: FAIL — `Invalid access to property or key 'run_stats'`.

- [ ] **Step 3: Write the implementation**

In `Scripts/GameState.gd`, immediately after `var grade7_student_ids: Array = []`, add:

```gdscript
## Per-grade tally consumed by the run-result screen. Never null; reset by
## set_grade() and by the grade-advance path in RunResult.
var run_stats: RunStats = RunStats.new()

## True while the exam cutscene branch of cut_scene.gd should play, set by
## TesNotice and cleared by the cutscene itself. Distinct from
## is_game_over_cutscene, which selects the losing branch.
var is_exam_intro_cutscene: bool = false

## True once the stat check has decided the run was lost. Read by
## RunResult to force a D grade without re-running the evaluation.
var run_failed: bool = false
```

In `set_grade()`, after `minggu_ke = 1`, add:

```gdscript
	run_stats.reset()
	is_exam_intro_cutscene = false
	run_failed = false
```

In `use_item()`, replace `remove_from_inventory(item.item_name, quantity)` with:

```gdscript
	remove_from_inventory(item.item_name, quantity)
	run_stats.record_item_use(quantity)
```

At the end of the file, after `check_semester_passed()`, add:

```gdscript
## Counts how many of the roster's three-per-student academic targets have
## been cleared, as [cleared, total]. RunGrade's dominant scoring
## component -- kept here rather than in RunResult because it reads the
## approved_students dictionaries, whose key naming (akademis1/2/3 =
## academic/seni/olahraga) is this file's own concern.
func count_targets_cleared() -> Array:
	var cleared := 0
	var total := 0
	for student in approved_students:
		var pairs := [
			["akademis1", "target_akademis1"],
			["akademis2", "target_akademis2"],
			["akademis3", "target_akademis3"],
		]
		for pair in pairs:
			total += 1
			if float(student.get(pair[0], 0.0)) >= float(student.get(pair[1], 0.0)):
				cleared += 1
	return [cleared, total]
```

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="economy_state")
```

Expected: PASS. If `run_stats` is still missing, the autoload is stale — apply
a no-op `script_patch` to `Scripts/GameState.gd` and re-run.

- [ ] **Step 5: Commit**

```bash
git add Scripts/GameState.gd tests/test_economy_state.gd
git commit -m "feat(endgame): track run stats and exam flags on GameState"
```

---

## Task 4: Feed the recorders — minigames, wirausaha, events

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd:71-99` (`record_minigame_result`)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:1136-1138` (`_pay_out_wirausaha`)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (the `outcome == "Event"` branch, ~line 1228)
- Test: `tests/test_school_day.gd` (append)

**Interfaces:**
- Consumes: `GameState.run_stats` from Task 3.
- Produces: nothing new; three existing call sites now also write
  `run_stats`.

Note the minigame points: `record_minigame_result()` already computes a
per-student `deltas` dictionary with a `stat_delta`. Record the **roster
total** for that minigame, so "total poin minigame" reads as the points the
class earned rather than one student's share.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_school_day.gd`:

```gdscript
func test_student_manager_records_minigames_into_run_stats() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/StudentManager.gd")
	assert_true(src.contains("GameState.run_stats.record_minigame("),
		"record_minigame_result feeds the run tally")


func test_school_day_records_wirausaha_into_run_stats() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("GameState.run_stats.record_wirausaha("),
		"the wirausaha payout feeds the run tally")


func test_school_day_records_event_students_into_run_stats() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("GameState.run_stats.record_event_student("),
		"the event branch feeds the run tally")
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="school_day")
```

Expected: FAIL, three assertions, "record_minigame_result feeds the run tally".

- [ ] **Step 3: Write the implementation**

**3a.** In `Scripts/SchoolSimulation/StudentManager.gd`, inside
`record_minigame_result()`, add a running total next to the existing
`results` accumulation and record it just before `minigame_history.append(...)`:

```gdscript
func record_minigame_result(day_name: String, category: String, game_name: String, won: bool, score: int = -1, max_score: int = -1) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	# Roster-wide points for this one minigame. The run-result screen
	# reports the class total, not any single student's share.
	var roster_points := 0.0
	for student in students:
		var deltas = student.apply_minigame_result(category, won, score, max_score)
		roster_points += float(deltas.get("stat_delta", 0.0))
		results.append({
			"student_name": student.student_name,
			"deltas": deltas
		})
		# ... existing logging body, unchanged ...

	GameState.run_stats.record_minigame(won, roster_points)

	minigame_history.append({
		# ... unchanged ...
	})

	return results
```

**3b.** In `Scripts/SchoolSimulation/SchoolDay.gd`, in `_pay_out_wirausaha()`,
after the loop that sums `GameState.pending_earnings` and before the
`.clear()`:

```gdscript
	for student_id in GameState.pending_earnings:
		total += GameState.pending_earnings[student_id]
	GameState.run_stats.record_wirausaha(total)
	GameState.pending_earnings.clear()
```

**3c.** In `Scripts/SchoolSimulation/SchoolDay.gd`, the fast-simulation branch
where `outcome == "Event"` currently reads:

```gdscript
			else:
				category = "Event"
				events_triggered_this_week += 1
```

becomes:

```gdscript
			else:
				category = "Event"
				events_triggered_this_week += 1
				# Every student on the roster is present for an event, so
				# an event marks the whole roster as having participated.
				for s in GameState.approved_students:
					GameState.run_stats.record_event_student(int(s.get("id", -1)))
```

Apply the identical three-line addition to the **interactive** event branch as
well — grep `events_triggered_this_week += 1` and patch every occurrence, so a
played event counts the same as a fast-simulated one.

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="school_day")
test_run(suite="run_stats")
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_school_day.gd
git commit -m "feat(endgame): record minigames, wirausaha and events into run stats"
```

---

## Task 5: Register the three new BGM ids

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd`
- Test: `tests/test_audio_director.gd` (append)

**Interfaces:**
- Produces: `AudioDirector.play_bgm(&"exam_notice")`,
  `play_bgm(&"exam_cutscene")`, `play_bgm(&"run_result")`.

No new audio files. Each id points at an existing track (spec's Audio table);
swapping in real art later is a one-line `@export` change in the Inspector.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_audio_director.gd`:

```gdscript
func test_the_end_of_grade_bgm_ids_all_resolve() -> void:
	for id in [&"exam_notice", &"exam_cutscene", &"run_result"]:
		assert_true(AudioDirector._bgm_stream_for(id) != null,
			"BGM id %s resolves to a stream" % id)
```

(`_bgm_stream_for` is the existing private lookup at the bottom of
`AudioDirector.gd` — the same one `test_audio_director.gd` already uses for the
existing ids. Match whatever name that file actually uses when you get there.)

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="audio_director")
```

Expected: FAIL — the three new ids return `null`.

- [ ] **Step 3: Write the implementation**

Add three `@export` fields alongside the existing `bgm_*` exports:

```gdscript
## The Tes Besar announcement screen. Placeholder: points at the
## simulation track until dedicated art lands.
@export var bgm_exam_notice: AudioStream = preload("res://Assets/Audio/BGM/schoolsimulation.mp3")
## The exam cutscene. Placeholder: shares the intro cutscene's track.
@export var bgm_exam_cutscene: AudioStream = preload("res://Assets/Audio/BGM/introcutscene.mp3")
## The run-result report screen. Placeholder: shares the win sting's track.
@export var bgm_run_result: AudioStream = preload("res://Assets/Audio/BGM/result_win.mp3")
```

Extend the BGM lookup `match` (the one holding `&"titlescreen"` …
`&"result_lose"`) with:

```gdscript
		&"exam_notice": return bgm_exam_notice
		&"exam_cutscene": return bgm_exam_cutscene
		&"run_result": return bgm_run_result
```

Add three lines to the file's documentation block, matching the existing
`## play_bgm(&"…"): …` style:

```gdscript
## `play_bgm(&"exam_notice")`: the Tes Besar announcement screen.
## `play_bgm(&"exam_cutscene")`: the pre-exam cutscene branch.
## `play_bgm(&"run_result")`: the end-of-grade run report.
```

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="audio_director")
test_run(suite="audio_coverage")
```

Expected: both PASS. `audio_coverage` scans for undocumented ids — if it fails,
the doc lines above are missing or misspelt.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd
git commit -m "feat(audio): register the end-of-grade BGM ids"
```

---

## Task 6: `TesNotice` — the Tes Besar announcement screen

**Files:**
- Create: `Scripts/EndGame/TesNotice.gd`
- Create: `Scenes/EndGame/TesNotice.tscn`
- Test: `tests/test_tes_notice.gd`

**Interfaces:**
- Consumes: `GameState.current_grade`, `AudioDirector`, `Transition`, `Juice`.
- Produces: the scene at `res://Scenes/EndGame/TesNotice.tscn`, which sets
  `GameState.is_exam_intro_cutscene = true` and routes to
  `res://Scenes/CutScene/cut_scene.tscn`.

**Scene tree** (build via MCP; remember `anchors_preset` is inert — set the four
anchors, and numbers are unquoted):

```
TesNotice           Control    anchors 0,0,1,1, script TesNotice.gd
├─ Backdrop         TextureRect  texture blur_background.png, expand_mode 1, stretch_mode 6
├─ Scrim            Panel        anchors 0,0,1,1, theme_type_variation "Scrim"
└─ MarginContainer  MarginContainer  anchors 0,0,1,1, margin_* 80
   └─ NoticeCard    NinePatchRect  texture notice.png, patch_margin_* 48,
      │                            size_flags_vertical 4 (SHRINK_CENTER)
      └─ Content    VBoxContainer  anchors 0,0,1,1, offsets inset 72, separation 32
         ├─ Kicker      Label   "PENGUMUMAN", variation "CaptionLabel", h-align 1
         ├─ TitleLabel  Label   "TES BESAR SEKOLAH", variation "DisplayLabel", h-align 1
         ├─ GradeLabel  Label   "Kelas 7", variation "H2Label", h-align 1
         ├─ BodyLabel   Label   (copy below), variation "ResultBodyLabel",
         │                      h-align 1, autowrap_mode 3
         └─ BtnLanjut   Button  "Hadapi Tes", variation "PrimaryButton",
                                custom_minimum_size (0, 120)
```

`BodyLabel` copy (Indonesian, exact):

> Minggu pembelajaran sudah berakhir. Sekarang seluruh murid akan menghadapi
> Tes Besar Sekolah. Hasilnya akan menentukan apakah mereka naik ke tahap
> berikutnya.

- [ ] **Step 1: Write the failing test**

Create `tests/test_tes_notice.gd`:

```gdscript
@tool
extends McpTestSuite

## TesNotice is the first screen of the end-of-grade sequence: a single
## announcement card that must not leak the pass/fail verdict, and that
## routes into the exam branch of the cutscene.
##
## Structure is checked live (the scene instantiates cleanly); routing is
## checked by source-text scan, per this project's established pattern for
## GameState-dependent branching.

const _SCENE_PATH := "res://Scenes/EndGame/TesNotice.tscn"
const _SCRIPT_PATH := "res://Scripts/EndGame/TesNotice.gd"

var _screen: Control


func suite_name() -> String:
	return "tes_notice"


func setup() -> void:
	_screen = load(_SCENE_PATH).instantiate()


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_screen = null


func test_scene_loads() -> void:
	assert_true(_screen != null, "TesNotice.tscn instantiates")


func test_has_the_backdrop_scrim_and_card() -> void:
	assert_true(_screen.get_node_or_null("Backdrop") != null, "Backdrop node")
	assert_true(_screen.get_node_or_null("Scrim") != null, "Scrim node")
	assert_true(_screen.get_node_or_null(
		"MarginContainer/NoticeCard") != null, "NoticeCard node")


func test_the_card_is_a_nine_patch_of_the_notice_art() -> void:
	var card = _screen.get_node_or_null("MarginContainer/NoticeCard")
	assert_true(card is NinePatchRect, "the card is a NinePatchRect")
	assert_true(String(card.texture.resource_path).ends_with("notice.png"),
		"the card uses notice.png")


func test_the_continue_button_exists_and_is_touch_sized() -> void:
	var btn = _screen.get_node_or_null(
		"MarginContainer/NoticeCard/Content/BtnLanjut")
	assert_true(btn is Button, "BtnLanjut is a Button")
	assert_true(btn.custom_minimum_size.y >= 96.0,
		"the button clears the touch-target minimum")


func test_no_theme_overrides_anywhere() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"no theme_override_* in the scene: %s" % str(offenders))


func test_the_notice_does_not_leak_the_verdict() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("check_semester_passed"),
		"the notice never reads the pass/fail result")


func test_it_routes_into_the_exam_cutscene() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.is_exam_intro_cutscene = true"),
		"it arms the exam cutscene branch")
	assert_true(src.contains("res://Scenes/CutScene/cut_scene.tscn"),
		"it routes to the cutscene")


func test_it_plays_the_notice_bgm() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("play_bgm(&\"exam_notice\")"), "notice BGM")
	assert_true(src.contains("play_sfx(&\"popup_open\")"), "arrival SFX")
```

Copy the `_collect_overrides` helper verbatim from `tests/test_main_menu.gd`
(Godot 4.6 has no `get_theme_*_override_list()`, which is why every suite here
carries its own copy).

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="tes_notice")
```

Expected: FAIL — the scene path does not exist.

- [ ] **Step 3a: Write the script**

Create `Scripts/EndGame/TesNotice.gd`:

```gdscript
@tool
extends Control

## The first screen of the end-of-grade sequence: the Tes Besar Sekolah
## announcement.
##
## It shows at the end of every grade's final week, win or lose, and must
## never reveal the verdict -- that is the stat check's job two screens
## later. All it does is name the grade, set the stakes, and hand off to
## the exam branch of the cutscene.
##
## @tool for the same reason main_menu.gd and cut_scene.gd are: without
## it, this becomes a placeholder instance when the MCP test suite
## instantiates the scene inside the editor process, which breaks every
## traversal-based check. Everything with a real runtime side effect --
## reading GameState, starting BGM, arming the auto-advance timer -- sits
## behind the Engine.is_editor_hint() guard in _ready().

@onready var grade_label: Label = $MarginContainer/NoticeCard/Content/GradeLabel
@onready var btn_lanjut: Button = $MarginContainer/NoticeCard/Content/BtnLanjut
@onready var notice_card: NinePatchRect = $MarginContainer/NoticeCard

## Seconds before the notice advances on its own. Zero disables the
## auto-advance and waits for the button.
@export var auto_advance_seconds: float = 6.0

## How long the card takes to pop in, in seconds.
@export var card_pop_seconds: float = 0.45

var _advancing: bool = false


func _ready() -> void:
	btn_lanjut.pressed.connect(_on_lanjut_pressed)

	if Engine.is_editor_hint():
		return

	grade_label.text = GameState.get_grade_name()

	AudioDirector.play_bgm(&"exam_notice")
	AudioDirector.play_sfx(&"popup_open")

	Juice.pop_in(notice_card, 0.0)

	if auto_advance_seconds > 0.0:
		await get_tree().create_timer(auto_advance_seconds).timeout
		if is_instance_valid(self):
			_advance()


func _on_lanjut_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	_advance()


## Guarded so the auto-advance timer and an impatient tap cannot both fire
## a scene change.
func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	GameState.is_exam_intro_cutscene = true
	Transition.change_scene("res://Scenes/CutScene/cut_scene.tscn")
```

- [ ] **Step 3b: Build the scene through the MCP**

Do NOT hand-write the `.tscn` — the attached editor's cached copy wins. Use:

```
scene_manage(op="create", path="res://Scenes/EndGame/TesNotice.tscn", root_type="Control", root_name="TesNotice")
scene_open(path="res://Scenes/EndGame/TesNotice.tscn")
batch_execute(...)   # create_node / set_property per the tree above
script_attach(node="/root/TesNotice", script="res://Scripts/EndGame/TesNotice.gd")
scene_save()
```

Reminders that bite here: `anchors_preset` is inert, so set
`anchor_left/top/right/bottom` explicitly; numbers must be unquoted (`1`, not
`"1.0"`); `node_create` appends last, so use `move_node` if the Scrim ends up
above the Backdrop.

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="tes_notice")
```

Expected: PASS, 9 tests.

- [ ] **Step 5: Look at it once**

Open the debug overlay's Scenes tab (F1) and teleport to TesNotice, or run
`project_run` with the scene set, then `editor_screenshot`. Confirm the card is
centred, the text fits inside the nine-patch's frame, and nothing overflows the
1080×1920 frame. Adjust `patch_margin_*` and the `Content` inset if the copy
crowds the border.

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/TesNotice.gd Scenes/EndGame/TesNotice.tscn tests/test_tes_notice.gd
git commit -m "feat(endgame): add the Tes Besar announcement screen"
```

---

## Task 7: The exam cutscene branch

**Files:**
- Modify: `Scripts/CutScene/cut_scene.gd` (`_ready()`, plus a new
  `_setup_exam_cutscene()` next to `_setup_game_over_cutscene()`)
- Test: `tests/test_cutscene.gd` (append)

**Interfaces:**
- Consumes: `GameState.is_exam_intro_cutscene` from Task 3.
- Produces: `cut_scene.gd` routes to `res://Scenes/EndGame/SemesterEnd.tscn`
  when the exam branch finishes, and to `res://Scenes/EndGame/RunResult.tscn`
  when the game-over branch finishes.

Branch precedence in `_ready()`: exam first, then game-over, then the
intro/level-select path. The exam branch hides both top-bar buttons the same
way the game-over branch does, and does **not** darken the backdrop.

Four placeholder dialogues, using the intro's existing CG images as BG
placeholders until real exam art lands.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_cutscene.gd`:

```gdscript
func test_the_exam_branch_exists_and_wins_precedence() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("_setup_exam_cutscene"),
		"there is an exam branch")
	var exam_at := src.find("if GameState.is_exam_intro_cutscene")
	var over_at := src.find("if GameState.is_game_over_cutscene")
	assert_true(exam_at != -1, "the exam flag is branched on")
	assert_true(exam_at < over_at,
		"the exam branch is tested before the game-over branch")


func test_the_exam_branch_has_four_dialogues() -> void:
	var scene = load("res://Scenes/CutScene/cut_scene.tscn").instantiate()
	scene._setup_exam_cutscene()
	var count: int = scene.cg_data.size()
	scene.free()
	assert_eq(count, 4, "four exam dialogues")


func test_the_exam_branch_exits_to_the_stat_check() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("res://Scenes/EndGame/SemesterEnd.tscn"),
		"the exam cutscene ends at the stat check")


func test_the_game_over_branch_exits_to_the_run_result() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("res://Scenes/EndGame/RunResult.tscn"),
		"the lose cutscene ends at the run result")


func test_the_exam_branch_plays_its_own_bgm() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("play_bgm(&\"exam_cutscene\")"), "exam BGM")
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="cutscene")
```

Expected: FAIL — "there is an exam branch".

- [ ] **Step 3: Write the implementation**

**3a.** In `_ready()`, replace the branch selection with:

```gdscript
	if GameState.is_exam_intro_cutscene:
		_setup_exam_cutscene()
	elif GameState.is_game_over_cutscene:
		_setup_game_over_cutscene()
	else:
		# Show level selection BEFORE playing intro cutscene if unlocked or in debug mode
		if GameState.is_game_beaten or GameState.debug_level_select_enabled:
			show_level_select_modal()
		else:
			GameState.set_grade(7)
			show_current()
```

**3b.** Add, directly above `_setup_game_over_cutscene()`:

```gdscript
## The pre-exam beat, between the Tes Besar notice and the stat check.
##
## Deliberately short -- four lines -- and deliberately neutral: the
## player does not yet know whether they passed, and this cutscene must
## not hint either way.
##
## The CG images are the intro's, standing in until dedicated exam art
## lands. Swapping them is a four-line change here and nothing else.
func _setup_exam_cutscene() -> void:
	if btn_debug_toggle: btn_debug_toggle.visible = false
	if btn_skip: btn_skip.visible = false

	AudioDirector.play_bgm(&"exam_cutscene")

	cg_data = [
		{
			"image": preload("res://Assets/Images/CG/cg3.jpg"),
			"text": "[PLACEHOLDER] Pagi itu halaman sekolah terasa berbeda. Semua murid berjalan pelan menuju aula, membawa pensil dan harapan masing-masing."
		},
		{
			"image": preload("res://Assets/Images/CG/cg4.jpg"),
			"text": "[PLACEHOLDER] Aku berdiri di depan pintu aula, menghitung lagi wajah-wajah yang sudah kubimbing selama satu tahun ajaran ini."
		},
		{
			"image": preload("res://Assets/Images/CG/cg2.jpg"),
			"text": "[PLACEHOLDER] 'Bu, Pak... kami sudah siap,' kata salah satu dari mereka. Suaranya bergetar, tapi matanya tidak."
		},
		{
			"image": preload("res://Assets/Images/CG/cg0.jpg"),
			"text": "[PLACEHOLDER] Bel berbunyi. Tes Besar Sekolah dimulai. Sekarang giliran mereka yang berjuang, dan giliranku untuk percaya."
		}
	]
	cg_index = 0
	show_current()
```

**3c.** Find the function that runs when the last CG is dismissed (the one that
today calls `Transition.change_scene(...)` at the end of the intro — grep
`Transition.change_scene` inside `cut_scene.gd`). Replace its single
destination with a three-way choice:

```gdscript
## Where the cutscene lets out depends on which branch played:
##   exam      -> the stat check
##   game-over -> the run result (the run is already decided; the lose
##                cutscene IS the lose screen)
##   intro     -> the roster approval screen, as before
func _next_scene_path() -> String:
	if GameState.is_exam_intro_cutscene:
		GameState.is_exam_intro_cutscene = false
		return "res://Scenes/EndGame/SemesterEnd.tscn"
	if GameState.is_game_over_cutscene:
		GameState.is_game_over_cutscene = false
		GameState.run_failed = true
		return "res://Scenes/EndGame/RunResult.tscn"
	return "res://Scenes/StudentCard/student_card.tscn"
```

and call `Transition.change_scene(_next_scene_path())` at that exit point.
Verify the intro's existing destination first and use whatever string is
actually there for the third return — do not assume `student_card.tscn` if the
file says otherwise.

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="cutscene")
```

Expected: PASS. `test_the_exam_branch_has_four_dialogues` needs `cut_scene.gd`
to stay `@tool` (it already is) — if it reports "Attempt to call a method on a
placeholder instance", the `@tool` annotation was lost in the edit.

- [ ] **Step 5: Commit**

```bash
git add Scripts/CutScene/cut_scene.gd tests/test_cutscene.gd
git commit -m "feat(cutscene): add the pre-exam branch and re-point both exits"
```

---

## Task 8: Route the final week into the sequence

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:1272-1279` (`_on_back_pressed`)
- Modify: `Scripts/Debug/DebugManager.gd:1247` (scene teleport list)
- Test: `tests/test_school_day.gd` (modify the existing SemesterEnd assertion)

**Interfaces:**
- Consumes: `Scenes/EndGame/TesNotice.tscn` from Task 6.
- Produces: SchoolDay's final-week exit now goes to TesNotice.

- [ ] **Step 1: Update the test to the new expectation**

In `tests/test_school_day.gd:106`, replace the existing assertion with:

```gdscript
	assert_true(src.contains("res://Scenes/EndGame/TesNotice.tscn"),
		"the final week now exits into the Tes Besar notice, not straight to the stat check")
	assert_false(src.contains("res://Scenes/EndGame/SemesterEnd.tscn"),
		"SchoolDay no longer reaches the stat check directly")
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="school_day")
```

Expected: FAIL — "the final week now exits into the Tes Besar notice".

- [ ] **Step 3: Write the implementation**

In `_on_back_pressed()`, change:

```gdscript
	if completed_week >= max_weeks:
		Transition.change_scene("res://Scenes/EndGame/TesNotice.tscn")
	else:
		Transition.change_scene("res://Scenes/Lobby/loby.tscn")
```

In `Scripts/Debug/DebugManager.gd`, extend the teleport list so a session can
jump into any screen of the new sequence without playing to it:

```gdscript
		{"name": "Notice Tes Besar (TesNotice)", "path": "res://Scenes/EndGame/TesNotice.tscn"},
		{"name": "Evaluasi Semester (SemesterEnd)", "path": "res://Scenes/EndGame/SemesterEnd.tscn"},
		{"name": "Layar Menang (WinScreen)", "path": "res://Scenes/EndGame/WinScreen.tscn"},
		{"name": "Hasil Run (RunResult)", "path": "res://Scenes/EndGame/RunResult.tscn"},
```

WinScreen and RunResult do not exist yet — this task's teleport entries for
them will 404 until Tasks 10 and 13 land. That is fine and expected; the debug
overlay already tolerates a missing path.

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="school_day")
test_run(suite="debug_manager")
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd Scripts/Debug/DebugManager.gd tests/test_school_day.gd
git commit -m "feat(endgame): route the final week into the Tes Besar sequence"
```

---

## Task 9: Restyle the stat check and re-point its exit

**Files:**
- Modify: `Scenes/EndGame/SemesterEnd.tscn` (background, margins, page dots)
- Modify: `Scripts/EndGame/SemesterEnd.gd` (copy, page dots, routing)
- Test: `tests/test_semester_end.gd` (modify)

**Interfaces:**
- Consumes: `GameState.run_failed` from Task 3;
  `Scenes/EndGame/WinScreen.tscn` from Task 10 (created next task — the string
  is written now and the scene appears in Task 10).
- Produces: SemesterEnd exits to WinScreen on a pass, or arms
  `GameState.is_game_over_cutscene` and goes to the cutscene on a fail. It no
  longer applies grade progression — that moves to RunResult in Task 13.

**What changes visually:**

1. `Background` `ColorRect` (`Color(0.04,0.05,0.08,1)`) → delete. In its place,
   a `Backdrop` `TextureRect` (`blur_background.png`, `expand_mode 1`,
   `stretch_mode 6`) with a `Scrim` `Panel` (`theme_type_variation "Scrim"`)
   over it, exactly as DaySummary / ResultCheckup / AturJadwal already do.
2. `MarginContainer` gains `margin_left/right = 64`, `margin_top = 96`,
   `margin_bottom = 72` (layout-only constant overrides, which the style guide
   permits).
3. `VBoxContainer` gains `separation = 40`.
4. The page dots stop being runtime-built `Label`s with
   `add_theme_color_override`. Author **four** `PageDot` `Label`s in the
   `.tscn` (the roster is capped at four), each `theme_type_variation
   "PageDotLabel"`, and have the script only show/hide and re-modulate them.
   Add `PageDotLabel` to `ThemeFactory.gd` if it does not exist (a
   `CaptionLabel`-sized label at `text_disabled`), then rebake.
5. Copy loses the emoji clutter — see the strings in step 3b.

- [ ] **Step 1: Update the tests**

In `tests/test_semester_end.gd`, replace the routing tests with:

```gdscript
func test_it_exits_to_the_win_screen_when_the_semester_passed() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/EndGame/WinScreen.tscn"),
		"a pass leads to the win screen")


func test_it_exits_to_the_lose_cutscene_when_the_semester_failed() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.is_game_over_cutscene = true"),
		"a fail arms the lose cutscene")
	assert_true(src.contains("res://Scenes/CutScene/cut_scene.tscn"),
		"a fail leads to the cutscene")


func test_grade_progression_has_moved_off_this_screen() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("GameState.current_grade += 1"),
		"the stat check no longer advances the grade -- RunResult does")


func test_the_backdrop_replaced_the_flat_color_rect() -> void:
	assert_true(_screen.get_node_or_null("Backdrop") is TextureRect,
		"there is a blurred backdrop")
	assert_true(_screen.get_node_or_null("Scrim") is Panel,
		"there is a themed scrim over it")
	assert_true(_screen.get_node_or_null("Background") == null,
		"the flat dark ColorRect is gone")


func test_the_page_dots_are_authored_in_the_scene() -> void:
	var dots = _screen.get_node_or_null(
		"MarginContainer/VBoxContainer/PageIndicator")
	assert_eq(dots.get_child_count(), 4,
		"four page dots authored in the .tscn, not built at runtime")


func test_the_copy_dropped_the_emoji_clutter() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for emoji in ["🎓", "❌", "⚠️", "🎉", "🏆"]:
		assert_false(src.contains(emoji), "no %s in the copy" % emoji)
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="semester_end")
```

Expected: FAIL on all six.

- [ ] **Step 3a: Restyle the scene through the MCP**

```
scene_open(path="res://Scenes/EndGame/SemesterEnd.tscn")
```
then `node_manage(op="delete", node="Background")`, `node_create` the
`Backdrop` TextureRect and `Scrim` Panel, `move_node` both to the top of the
child order (before `MarginContainer`), set the margin/separation constants,
and `node_create` four `PageDot` Labels under `PageIndicator` with
`theme_type_variation = "PageDotLabel"` and `text = "●"`. Then `scene_save()`.

If `PageDotLabel` does not exist in `ThemeFactory.gd`, add it there, rebake by
writing a transient `@tool McpTestSuite` into `res://tests/` whose one test
does `ThemeFactory.build()` + `ResourceSaver.save(...)` to
`res://Assets/Theme/kejartes_theme.tres`, `test_run` it, then delete it — that
is this project's headless path around File > Run.

- [ ] **Step 3b: Update the script**

Replace the emoji copy in `_evaluate_students()`:

```gdscript
	if all_passed:
		AudioDirector.play_sfx(&"reward")
		title_label.text = "Hasil Tes Besar - %s" % GameState.get_grade_name()
		congrats_title.text = "Semua murid berhasil!"
		congrats_title.add_theme_color_override("font_color", tokens.state_success)
		# ... teacher-rank block unchanged ...
		congrats_text.text = "Seluruh muridmu memenuhi target %s. Mereka siap melangkah ke tahap berikutnya." % GameState.get_grade_name()
		btn_restart.text = "Lihat Hasil"
	else:
		title_label.text = "Hasil Tes Besar - %s" % GameState.get_grade_name()
		congrats_title.text = "Belum semua murid tuntas"
		congrats_title.add_theme_color_override("font_color", tokens.state_danger)
		teacher_title_label.text = "Gelar Gurumu: Guru Pembimbing Remedial"
		congrats_text.text = "Sebagian muridmu belum mencapai target %s. Mari lihat bagaimana tahun ajaran ini berjalan." % GameState.get_grade_name()
		btn_restart.text = "Lihat Hasil"
```

(The two `add_theme_color_override("font_color", …)` calls above are the
existing runtime-only pattern in this file and stay — the style guide's ban is
on overrides authored *in the scene*, and these are the documented exception
for state colours already in place here. Do not add new ones.)

Replace `_build_page_indicators()` with a show/hide over the authored dots:

```gdscript
## The dots are authored in the .tscn (four of them, the roster cap), so
## this only decides how many are visible. Nothing is constructed here --
## see the authoring guide's "no visual is built at runtime" rule.
func _build_page_indicators() -> void:
	if not page_indicator:
		return
	for i in range(page_indicator.get_child_count()):
		page_indicator.get_child(i).visible = (i < card_nodes.size())
```

Replace `_on_restart_pressed()` in full:

```gdscript
## The stat check no longer decides progression -- it only decides which
## emotional beat plays next. RunResult applies the grade advance, because
## RunResult is now the last screen of a run.
func _on_restart_pressed() -> void:
	var all_passed := GameState.check_semester_passed()
	var next_scene_path := ""

	if all_passed:
		next_scene_path = "res://Scenes/EndGame/WinScreen.tscn"
	else:
		GameState.run_failed = true
		GameState.is_game_over_cutscene = true
		next_scene_path = "res://Scenes/CutScene/cut_scene.tscn"

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	Transition.change_scene(next_scene_path)
```

Delete `_on_menu_pressed()` and the `BtnMainMenu` node — the run's only exit is
now forward through RunResult. Remove the `btn_menu` `@onready`, its
`pressed.connect`, and its `_setup_button_juice` call.

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="semester_end")
```

Expected: PASS. Then `editor_screenshot` the scene once and confirm the cards
read against the blurred backdrop rather than the old flat near-black.

- [ ] **Step 5: Commit**

```bash
git add Scenes/EndGame/SemesterEnd.tscn Scripts/EndGame/SemesterEnd.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_semester_end.gd
git commit -m "feat(endgame): restyle the stat check and re-point its exit"
```

---

## Task 10: `WinScreen` — the win beat, in the cutscene's clothes

**Files:**
- Create: `Scripts/EndGame/WinScreen.gd`
- Create: `Scenes/EndGame/WinScreen.tscn`
- Test: `tests/test_win_screen.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: the scene at `res://Scenes/EndGame/WinScreen.tscn`, exiting to
  `res://Scenes/EndGame/RunResult.tscn`.

This is the mirror of the existing lose cutscene, so it must **look identical
to the intro cutscene**: same `cutscene_dialogue.png` chatbox at the same
place, same `RichTextLabel` typewriter, same `HintLabel`, same tap-to-advance,
same fade overlay. Copy the node geometry from `Scenes/CutScene/cut_scene.tscn`
rather than eyeballing it — open both and match the offsets exactly.

**Scene tree:**

```
WinScreen        Control      anchors 0,0,1,1, script WinScreen.gd
├─ BgCutScene    TextureRect  (geometry copied from cut_scene.tscn)
├─ DialogueBox   TextureRect  texture cutscene_dialogue.png, geometry copied
│  └─ DialogueLabel  RichTextLabel  geometry copied
├─ FadeOverlay   ColorRect    anchors 0,0,1,1, color a=0
└─ HintLabel     Label        variation "CaptionLabel", script hint_label.gd,
                              geometry copied
```

Four placeholder win dialogues (Indonesian):

1. `[PLACEHOLDER] Hasilnya keluar sore itu. Aku membaca daftar nama satu per satu, dan tanganku sedikit gemetar.`
2. `[PLACEHOLDER] Semuanya lulus. Tidak ada satu pun nama yang tertinggal di daftar itu.`
3. `[PLACEHOLDER] Mereka berteriak di halaman, saling memeluk, dan salah satu dari mereka berbalik dan berkata, 'Terima kasih sudah tidak menyerah pada kami.'`
4. `[PLACEHOLDER] Aku hanya tersenyum. Ini bukan hasil kerjaku -- ini hasil kerja mereka. Aku cuma kebetulan berdiri di sampingnya.`

- [ ] **Step 1: Write the failing test**

Create `tests/test_win_screen.gd`:

```gdscript
@tool
extends McpTestSuite

## WinScreen is the win-path mirror of the existing game-over cutscene
## branch. Its whole job is to look and behave exactly like the intro
## cutscene, so most of these tests assert structural parity with
## cut_scene.tscn rather than anything novel.

const _SCENE_PATH := "res://Scenes/EndGame/WinScreen.tscn"
const _SCRIPT_PATH := "res://Scripts/EndGame/WinScreen.gd"
const _CUTSCENE_PATH := "res://Scenes/CutScene/cut_scene.tscn"

var _screen: Control


func suite_name() -> String:
	return "win_screen"


func setup() -> void:
	_screen = load(_SCENE_PATH).instantiate()


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_screen = null


func test_scene_loads() -> void:
	assert_true(_screen != null, "WinScreen.tscn instantiates")


func test_it_mirrors_the_cutscene_node_names() -> void:
	for path in ["BgCutScene", "DialogueBox", "DialogueBox/DialogueLabel",
			"FadeOverlay", "HintLabel"]:
		assert_true(_screen.get_node_or_null(path) != null,
			"WinScreen has %s, same as the cutscene" % path)


func test_the_chatbox_uses_the_cutscene_art() -> void:
	var box = _screen.get_node_or_null("DialogueBox")
	assert_true(String(box.texture.resource_path).ends_with("cutscene_dialogue.png"),
		"same chatbox art as the intro")


func test_the_chatbox_sits_where_the_cutscene_puts_it() -> void:
	var other = load(_CUTSCENE_PATH).instantiate()
	var mine = _screen.get_node_or_null("DialogueBox")
	var theirs = other.get_node_or_null("DialogueBox")
	var same_anchors := (mine.anchor_left == theirs.anchor_left
		and mine.anchor_top == theirs.anchor_top
		and mine.anchor_right == theirs.anchor_right
		and mine.anchor_bottom == theirs.anchor_bottom)
	other.free()
	assert_true(same_anchors, "the chatbox anchors match the intro cutscene")


func test_it_has_four_dialogues() -> void:
	assert_eq(_screen.dialogues.size(), 4, "four win lines")


func test_it_plays_the_win_bgm_and_exits_to_the_run_result() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("play_bgm(&\"result_win\")"), "win BGM")
	assert_true(src.contains("res://Scenes/EndGame/RunResult.tscn"),
		"exits to the run result")


func test_no_theme_overrides_anywhere() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"no theme_override_* in the scene: %s" % str(offenders))
```

Copy `_collect_overrides` verbatim from `tests/test_main_menu.gd`.

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="win_screen")
```

Expected: FAIL — scene does not exist.

- [ ] **Step 3a: Write the script**

Create `Scripts/EndGame/WinScreen.gd`:

```gdscript
@tool
extends Control

## The win beat: the mirror of the existing game-over cutscene branch, but
## warm instead of grey.
##
## It is deliberately a separate scene rather than a fourth branch inside
## cut_scene.gd: that script already carries three branches plus a level
## select modal, and the win path wants its own BGM and its own exit. What
## it is NOT allowed to differ on is the look -- the chatbox art, geometry
## and typewriter here are copied from cut_scene.tscn on purpose, and
## tests/test_win_screen.gd fails if the anchors drift apart.
##
## @tool for the same placeholder-instance reason as cut_scene.gd; every
## runtime side effect sits behind the Engine.is_editor_hint() guard.

@onready var dialogue_label: RichTextLabel = $DialogueBox/DialogueLabel
@onready var bg: TextureRect = $BgCutScene
@onready var fade_overlay: ColorRect = $FadeOverlay

## Typewriter speed, matching the intro cutscene's default.
@export var typewriter_chars_per_second: float = 45.0

## How long the fade to the next screen takes, in seconds.
@export var exit_fade_seconds: float = 0.6

## The win dialogue. Placeholders until the final script is written --
## keep them four lines so the pacing stays close to the lose cutscene's.
@export var dialogues: Array[String] = [
	"[PLACEHOLDER] Hasilnya keluar sore itu. Aku membaca daftar nama satu per satu, dan tanganku sedikit gemetar.",
	"[PLACEHOLDER] Semuanya lulus. Tidak ada satu pun nama yang tertinggal di daftar itu.",
	"[PLACEHOLDER] Mereka berteriak di halaman, saling memeluk, dan salah satu dari mereka berbalik dan berkata, 'Terima kasih sudah tidak menyerah pada kami.'",
	"[PLACEHOLDER] Aku hanya tersenyum. Ini bukan hasil kerjaku -- ini hasil kerja mereka. Aku cuma kebetulan berdiri di sampingnya.",
]

var _index: int = 0
var _reveal_tween: Tween
var _exiting: bool = false


func _ready() -> void:
	fade_overlay.color.a = 0.0
	if Engine.is_editor_hint():
		return
	AudioDirector.play_bgm(&"result_win")
	_show_current()


func _input(event: InputEvent) -> void:
	if _exiting:
		return
	var tapped := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return
	# A tap mid-typewriter completes the line; a tap on a finished line
	# advances. Same two-stage feel as the intro cutscene.
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
		dialogue_label.visible_ratio = 1.0
		return
	AudioDirector.play_sfx(&"tap")
	_advance()


func _show_current() -> void:
	if _index >= dialogues.size():
		return
	dialogue_label.text = dialogues[_index]
	dialogue_label.visible_ratio = 0.0
	var chars := float(dialogue_label.text.length())
	var seconds := chars / maxf(typewriter_chars_per_second, 1.0)
	if _reveal_tween:
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(dialogue_label, "visible_ratio", 1.0, seconds)


func _advance() -> void:
	_index += 1
	if _index < dialogues.size():
		_show_current()
	else:
		_exit_to_result()


func _exit_to_result() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	var tw := create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, exit_fade_seconds)
	await tw.finished
	Transition.change_scene("res://Scenes/EndGame/RunResult.tscn")
```

- [ ] **Step 3b: Build the scene through the MCP**

Open `Scenes/CutScene/cut_scene.tscn`, read every anchor/offset on
`BgCutScene`, `DialogueBox`, `DialogueBox/DialogueLabel`, `FadeOverlay` and
`HintLabel` with `node_get_properties`, then create the same five nodes in
`Scenes/EndGame/WinScreen.tscn` with those exact values. Attach
`Scripts/CutScene/hint_label.gd` to `HintLabel`, and
`Scripts/EndGame/WinScreen.gd` to the root. `scene_save()`.

For `BgCutScene`'s texture, use `res://Assets/Images/CG/cg0.jpg` as the
placeholder backdrop — same "BG placeholder from the intro" approach as the
exam cutscene.

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="win_screen")
```

Expected: PASS, 8 tests. `test_the_chatbox_sits_where_the_cutscene_puts_it` is
the one that catches a hand-eyeballed copy — if it fails, re-read the intro's
anchors instead of nudging.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/WinScreen.gd Scenes/EndGame/WinScreen.tscn tests/test_win_screen.gd
git commit -m "feat(endgame): add the cutscene-styled win screen"
```

---

## Task 11: Author the six report icons

**Files:**
- Create: `Assets/Images/UI/Placeholders/icon_minigame_menang.svg`
- Create: `Assets/Images/UI/Placeholders/icon_minigame_kalah.svg`
- Create: `Assets/Images/UI/Placeholders/icon_poin.svg`
- Create: `Assets/Images/UI/Placeholders/icon_barang.svg`
- Create: `Assets/Images/UI/Placeholders/icon_uang.svg`
- Create: `Assets/Images/UI/Placeholders/icon_event.svg`
- Test: `tests/test_project_hygiene.gd` (append)

**Interfaces:**
- Consumes: nothing.
- Produces: six `Texture2D` resources at the paths above, each loadable with
  `load("res://Assets/Images/UI/Placeholders/icon_*.svg")`.

**Why SVG and not PNG.** This project's icon placeholders are already
hand-authored single-line SVGs in exactly this folder — `icon_akademis.svg`,
`icon_mood.svg`, `icon_energy.svg`, `icon_olahraga.svg`, `icon_seni.svg`,
`icon_warning.svg`. Godot 4.6 imports `.svg` through the same texture importer
that handles `.png` (`importer="texture"`, `type="CompressedTexture2D"`), so a
`TextureRect` cannot tell them apart, and the background is transparent by
default because nothing paints it. They are also editable as text, which is
what makes them authorable here at all. If you later want literal rasters,
export each of these to a 128×128 PNG with an alpha channel and change only the
six paths — nothing else in the plan touches the file type.

**Every icon:** a `100 × 100` viewBox, no background rect (transparency is the
point), and colours drawn from the project's own accent palette so they sit
next to the existing placeholders without clashing. Keep each one to a single
line of markup, matching the folder's established style.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_project_hygiene.gd`:

```gdscript
func test_the_run_result_icons_all_exist_and_load_as_textures() -> void:
	var icons := [
		"icon_minigame_menang", "icon_minigame_kalah", "icon_poin",
		"icon_barang", "icon_uang", "icon_event",
	]
	for icon_name in icons:
		var path := "res://Assets/Images/UI/Placeholders/%s.svg" % icon_name
		assert_true(ResourceLoader.exists(path), "%s exists" % icon_name)
		assert_true(load(path) is Texture2D, "%s loads as a Texture2D" % icon_name)


func test_the_run_result_icons_are_transparent_backed() -> void:
	# A background rect covering the whole viewBox would defeat the point --
	# these sit on the Card surface and must not paint their own plate.
	var icons := [
		"icon_minigame_menang", "icon_minigame_kalah", "icon_poin",
		"icon_barang", "icon_uang", "icon_event",
	]
	for icon_name in icons:
		var src := FileAccess.get_file_as_string(
			"res://Assets/Images/UI/Placeholders/%s.svg" % icon_name)
		assert_false(src.contains('x="0" y="0" width="100" height="100"'),
			"%s has no full-bleed background rect" % icon_name)
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="project_hygiene")
```

Expected: FAIL — "icon_minigame_menang exists".

- [ ] **Step 3: Write the six icons**

Each file is exactly one line. Write them with plain file writes (they are not
`.gd` or `.tscn`, so neither the script-reload nor the scene-cache hazard
applies), then `filesystem_manage(op="scan")` so Godot imports them.

`icon_minigame_menang.svg` — a gamepad with a check:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><rect x="12" y="34" width="76" height="40" rx="18" fill="#3ec46d"/><rect x="26" y="48" width="14" height="5" rx="2.5" fill="white"/><rect x="30.5" y="43.5" width="5" height="14" rx="2.5" fill="white"/><circle cx="64" cy="47" r="4.5" fill="white"/><circle cx="74" cy="56" r="4.5" fill="white"/><path d="M40 78 L48 86 L66 66" stroke="#2a8f4d" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
```

`icon_minigame_kalah.svg` — the same gamepad silhouette with a cross:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><rect x="12" y="34" width="76" height="40" rx="18" fill="#e2685f"/><rect x="26" y="48" width="14" height="5" rx="2.5" fill="white"/><rect x="30.5" y="43.5" width="5" height="14" rx="2.5" fill="white"/><circle cx="64" cy="47" r="4.5" fill="white"/><circle cx="74" cy="56" r="4.5" fill="white"/><path d="M42 68 L64 88 M64 68 L42 88" stroke="#a83b34" stroke-width="7" fill="none" stroke-linecap="round"/></svg>
```

`icon_poin.svg` — a star:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><path d="M50 12 L61 39 L90 42 L68 61 L75 90 L50 74 L25 90 L32 61 L10 42 L39 39 Z" fill="#f2c14e" stroke="#d19c22" stroke-width="4" stroke-linejoin="round"/></svg>
```

`icon_barang.svg` — a satchel:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><path d="M34 34 v-6 a16 16 0 0 1 32 0 v6" stroke="#8c6239" stroke-width="7" fill="none" stroke-linecap="round"/><rect x="16" y="34" width="68" height="52" rx="12" fill="#b07c46"/><rect x="16" y="52" width="68" height="12" fill="#8c6239"/><rect x="44" y="48" width="12" height="20" rx="4" fill="#f0d9b5"/></svg>
```

`icon_uang.svg` — a coin, matching the project's gold:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><circle cx="50" cy="50" r="36" fill="#f2c14e" stroke="#d19c22" stroke-width="5"/><circle cx="50" cy="50" r="26" fill="none" stroke="#d19c22" stroke-width="3"/><path d="M42 38 h14 a9 9 0 0 1 0 18 h-14 M42 47 h20 M50 34 v32" stroke="#8a6410" stroke-width="5" fill="none" stroke-linecap="round"/></svg>
```

`icon_event.svg` — a festival tent/flag:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><path d="M20 44 h60 v40 a6 6 0 0 1 -6 6 h-48 a6 6 0 0 1 -6 -6 Z" fill="#b07cd6"/><path d="M50 10 L86 44 H14 Z" fill="#8f56c4"/><path d="M20 44 h15 v46 h-15 Z M50 44 h15 v46 h-15 Z" fill="#d6b4ea"/><circle cx="50" cy="8" r="6" fill="#f2c14e"/></svg>
```

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="project_hygiene")
```

Expected: PASS. `project_hygiene` also checks that every scene's
`ext_resource` UID resolves to its own asset — that check only bites once the
icons are referenced from a scene, which happens in Task 13.

- [ ] **Step 5: Look at them once**

Instantiate a scratch `TextureRect` for each at 64×64 over a `Card` surface and
`editor_screenshot` it, or simply open the folder in the editor's FileSystem
dock and read the thumbnails. Confirm each reads at thumbnail size and none
carries an opaque plate behind it.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/UI/Placeholders/icon_minigame_menang.svg Assets/Images/UI/Placeholders/icon_minigame_kalah.svg Assets/Images/UI/Placeholders/icon_poin.svg Assets/Images/UI/Placeholders/icon_barang.svg Assets/Images/UI/Placeholders/icon_uang.svg Assets/Images/UI/Placeholders/icon_event.svg tests/test_project_hygiene.gd
git commit -m "feat(art): add the six run-result report icons"
```

---

## Task 12: `RunResultRow` — one report row

**Files:**
- Create: `Scripts/EndGame/RunResultRow.gd`
- Create: `Scenes/EndGame/RunResultRow.tscn`
- Test: `tests/test_run_result.gd`

**Interfaces:**
- Consumes: `Juice.count_up`; the six icon textures from Task 11.
- Produces: `RunResultRow` scene with
  `set_row(label_text: String, value: float, suffix: String = "", icon: Texture2D = null) -> void`
  and `play_count_up(duration: float) -> void`.

**Scene tree:**

```
RunResultRow      PanelContainer  theme_type_variation "Card", script RunResultRow.gd
└─ Row            HBoxContainer   separation 24
   ├─ IconRect    TextureRect  custom_minimum_size (72, 72),
   │                           expand_mode 1 (IGNORE_SIZE),
   │                           stretch_mode 5 (KEEP_ASPECT_CENTERED),
   │                           texture = icon_poin.svg (a stand-in so the
   │                           template is not blank in the editor)
   ├─ NameLabel   Label   variation "ResultBodyLabel", size_flags_horizontal 3
   └─ ValueLabel  Label   variation "H2Label", h-align 2
```

The icon is a real transparent texture, not a glyph — `set_row()` swaps
`IconRect.texture` per row. The template ships with `icon_poin.svg` in the slot
so the scene reads correctly in the editor rather than showing an empty box.

- [ ] **Step 1: Write the failing test**

Create `tests/test_run_result.gd` (the RunResult screen's own tests join it in
Task 13):

```gdscript
@tool
extends McpTestSuite

## The end-of-grade report: RunResultRow (one row template) here, and the
## RunResult screen itself in the tests appended by the next task.

const _ROW_PATH := "res://Scenes/EndGame/RunResultRow.tscn"


func suite_name() -> String:
	return "run_result"


func test_the_row_template_loads() -> void:
	var row = load(_ROW_PATH).instantiate()
	var ok := row != null
	row.free()
	assert_true(ok, "RunResultRow.tscn instantiates")


func test_the_row_has_icon_name_and_value() -> void:
	var row = load(_ROW_PATH).instantiate()
	var icon = row.get_node_or_null("Row/IconRect")
	var has_all := icon is TextureRect \
		and row.get_node_or_null("Row/NameLabel") != null \
		and row.get_node_or_null("Row/ValueLabel") != null
	row.free()
	assert_true(has_all, "a texture icon, a name label and a value label")


func test_the_icon_is_a_texture_not_a_glyph() -> void:
	var row = load(_ROW_PATH).instantiate()
	var icon = row.get_node_or_null("Row/IconRect")
	var is_texture_rect := icon is TextureRect
	var has_default: bool = is_texture_rect and icon.texture != null
	row.free()
	assert_true(is_texture_rect, "IconRect is a TextureRect, never a Label")
	assert_true(has_default, "the template ships with a stand-in texture")


func test_set_row_swaps_the_icon_texture() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	var wanted: Texture2D = load(
		"res://Assets/Images/UI/Placeholders/icon_uang.svg")
	row.set_row("Uang dari wirausaha", 0.0, "G", wanted)
	var landed: Texture2D = row.get_node("Row/IconRect").texture
	row.free()
	assert_true(landed == wanted, "set_row writes the icon through")


func test_set_row_writes_the_name_and_the_final_value() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	row.set_row("Minigame selesai", 7.0)
	var name_text: String = row.get_node("Row/NameLabel").text
	var value_text: String = row.get_node("Row/ValueLabel").text
	row.free()
	assert_eq(name_text, "Minigame selesai", "the name lands")
	assert_eq(value_text, "0", "the value starts at zero, ready to count up")


func test_set_row_keeps_the_suffix() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	row.set_row("Uang wirausaha", 1500.0, "G")
	var target: float = row.target_value
	var suffix: String = row.value_suffix
	row.free()
	assert_eq(target, 1500.0, "target stored")
	assert_eq(suffix, "G", "suffix stored")
```

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="run_result")
```

Expected: FAIL — the row scene does not exist.

- [ ] **Step 3a: Write the script**

Create `Scripts/EndGame/RunResultRow.gd`:

```gdscript
@tool
extends PanelContainer

## One row of the end-of-grade report: an icon, a name, and a number that
## counts up.
##
## A PackedScene template rather than a runtime-built HBox, per the
## authoring guide -- RunResult instantiates one of these per reported
## figure. The value deliberately renders as "0" until play_count_up()
## runs, so the screen never flashes its own punchline before the reveal
## reaches that row.

@onready var icon_rect: TextureRect = $Row/IconRect
@onready var name_label: Label = $Row/NameLabel
@onready var value_label: Label = $Row/ValueLabel

## The number this row counts up to. Set through set_row().
var target_value: float = 0.0
## Appended to the counted number, e.g. "G" for rupiah. Set through set_row().
var value_suffix: String = ""


## The icon is a Texture2D, never a text glyph -- these rows sit on a Card
## surface and must render the same on every device and font fallback,
## which an emoji cannot promise. Passing null leaves the template's
## stand-in texture in place rather than blanking the slot.
func set_row(label_text: String, value: float, suffix: String = "",
		icon: Texture2D = null) -> void:
	name_label.text = label_text
	target_value = value
	value_suffix = suffix
	if icon != null:
		icon_rect.texture = icon
	value_label.text = "0" + value_suffix


## Counts the value up over `duration` seconds. Uses the project's own
## Juice.count_up so the easing matches every other counter in the game.
func play_count_up(duration: float) -> void:
	Juice.count_up(value_label, 0.0, target_value, duration, value_suffix)
```

Check `Juice.count_up`'s real signature before writing that last line — if it
does not take a suffix, format the label in a `tween_method` callback instead
and note the deviation in the commit message.

- [ ] **Step 3b: Build the scene through the MCP**

`scene_manage(op="create", ...)` a `PanelContainer` root named `RunResultRow`
with `theme_type_variation = "Card"`, then the `Row` HBox, the `IconRect`
`TextureRect` and the two labels per the tree above, `script_attach` the
script, `scene_save()`. Set `IconRect.texture` to
`res://Assets/Images/UI/Placeholders/icon_poin.svg` as the stand-in.

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="run_result")
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/RunResultRow.gd Scenes/EndGame/RunResultRow.tscn tests/test_run_result.gd
git commit -m "feat(endgame): add the run-result row template"
```

---

## Task 13: `RunResult` — the graded report, and the run's exit

**Files:**
- Create: `Scripts/EndGame/RunResult.gd`
- Create: `Scenes/EndGame/RunResult.tscn`
- Modify: `tests/test_run_result.gd` (append)

**Interfaces:**
- Consumes: `RunStats`, `RunGrade`, `GameState.run_stats`,
  `GameState.run_failed`, `GameState.count_targets_cleared()`,
  `RunResultRow.set_row()` / `play_count_up()`.
- Produces: the scene at `res://Scenes/EndGame/RunResult.tscn`, which applies
  grade progression and exits to `res://Scenes/MainMenu/main_menu.tscn`.

**Scene tree:**

```
RunResult          Control        anchors 0,0,1,1, script RunResult.gd
├─ Backdrop        TextureRect    blur_background.png, expand_mode 1, stretch_mode 6
├─ Scrim           Panel          anchors 0,0,1,1, variation "Scrim"
└─ MarginContainer MarginContainer  anchors 0,0,1,1, margin_* 64
   └─ Column       VBoxContainer  separation 36
      ├─ TitleLabel   Label   "Hasil Tahun Ajaran", variation "H1Label", h-align 1
      ├─ GradeCard    PanelContainer  variation "Card", size_flags_vertical 4
      │  └─ GradeStack  VBoxContainer  separation 8
      │     ├─ GradeLetter  Label  "A", variation "DisplayLabel", h-align 1
      │     └─ GradeCaption Label  "", variation "CaptionLabel", h-align 1
      ├─ RowsBox      VBoxContainer  separation 16, size_flags_vertical 3
      └─ BtnSelesai   Button  "Kembali ke Menu", variation "PrimaryButton",
                              custom_minimum_size (0, 120)
```

`RowsBox` is empty in the `.tscn` — its children are six `RunResultRow`
instances. This is the reviewed exception the authoring guide allows for
per-call-dynamic content (the row *count* is fixed at six here, but the values
are entirely run-dependent); add a comment saying so at the instantiation site,
and add the entry to `ALLOWED` in `tests/test_viewport_editability.gd` rather
than to `BASELINE`.

**The six rows**, in order:

| Icon (Task 11) | Name | Value | Suffix |
|---|---|---|---|
| `icon_minigame_menang.svg` | Minigame selesai | `run_stats.minigames_won` | — |
| `icon_minigame_kalah.svg` | Minigame kalah | `run_stats.minigames_lost` | — |
| `icon_poin.svg` | Total poin minigame | `run_stats.minigame_points` | " poin" |
| `icon_barang.svg` | Barang dipakai | `run_stats.items_used` | — |
| `icon_uang.svg` | Uang dari wirausaha | `run_stats.wirausaha_money` | "G" |
| `icon_event.svg` | Murid ikut event | `run_stats.event_student_count()` | " murid" |

**Reveal order:** title pops in → rows stagger in and count up → the letter
slams down last, with `reward` SFX on an A-band grade and `fail` on a D. The
letter comes last on purpose: the numbers build the case, and then the grade
lands.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_result.gd`:

```gdscript
const _SCENE_PATH := "res://Scenes/EndGame/RunResult.tscn"
const _SCRIPT_PATH := "res://Scripts/EndGame/RunResult.gd"


func test_the_screen_loads() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var ok := screen != null
	screen.free()
	assert_true(ok, "RunResult.tscn instantiates")


func test_the_screen_has_a_backdrop_grade_card_and_rows_box() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var has_all := screen.get_node_or_null("Backdrop") != null \
		and screen.get_node_or_null("Scrim") != null \
		and screen.get_node_or_null(
			"MarginContainer/Column/GradeCard/GradeStack/GradeLetter") != null \
		and screen.get_node_or_null("MarginContainer/Column/RowsBox") != null
	screen.free()
	assert_true(has_all, "the report's structural nodes are all present")


func test_the_rows_box_starts_empty_in_the_scene() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var count: int = screen.get_node("MarginContainer/Column/RowsBox").get_child_count()
	screen.free()
	assert_eq(count, 0, "rows are instanced from the template at runtime")


func test_it_reports_all_six_figures() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for label in ["Minigame selesai", "Minigame kalah", "Total poin minigame",
			"Barang dipakai", "Uang dari wirausaha", "Murid ikut event"]:
		assert_true(src.contains(label), "the report includes '%s'" % label)


func test_it_grades_through_run_grade() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("RunGrade.score("), "it scores the run")
	assert_true(src.contains("RunGrade.letter("), "it letters the run")
	assert_true(src.contains("GameState.run_failed"), "a failed run is honoured")


func test_it_applies_grade_progression_and_exits_to_the_menu() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.current_grade += 1"),
		"a win advances the grade")
	assert_true(src.contains("res://Scenes/MainMenu/main_menu.tscn"),
		"the run ends at the main menu")


func test_it_plays_the_report_bgm_and_the_grade_stings() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("play_bgm(&\"run_result\")"), "report BGM")
	assert_true(src.contains("play_sfx(&\"stamp\")"), "the letter slams")
	assert_true(src.contains("play_sfx(&\"coin\")"), "the money row chimes")
	assert_true(src.contains("play_sfx(&\"reward\")"), "an A-band grade rewards")
	assert_true(src.contains("play_sfx(&\"fail\")"), "a D grade stings")


func test_the_report_uses_texture_icons_not_emoji() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Assets/Images/UI/Placeholders/icon_uang.svg"),
		"the rows reference real icon assets")
	for glyph in ["\u{1F3AE}", "\u{1F4B0}", "\u{2B50}", "\u{1F392}", "\u{1F3AA}"]:
		assert_false(src.contains(glyph),
			"no emoji glyph is used as an icon")


func test_no_theme_overrides_in_the_scene() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var offenders: Array[String] = []
	_collect_overrides(screen, offenders)
	screen.free()
	assert_eq(offenders.size(), 0, "no theme_override_*: %s" % str(offenders))
```

Copy `_collect_overrides` verbatim from `tests/test_main_menu.gd`.

- [ ] **Step 2: Run to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="run_result")
```

Expected: FAIL — the RunResult scene does not exist.

- [ ] **Step 3a: Write the script**

Create `Scripts/EndGame/RunResult.gd`:

```gdscript
extends Control

## The last screen of a run: what the player actually did this grade,
## reported as six counted-up figures and one letter grade.
##
## Deliberately NOT @tool -- like SemesterEnd and StudentCard, _ready()
## reads GameState, starts BGM and kicks off a tween chain, none of which
## should fire because the editor opened the scene. Its tests are
## therefore source-text scans plus structural checks on a bare
## instantiate(), never live property reads.
##
## This screen also owns grade progression, which used to live in
## SemesterEnd._on_restart_pressed(). It moved here because RunResult is
## now the last thing a run touches, and progression has to happen exactly
## once, after the report has been read.

@export_group("Reveal Timing")
## Delay between each report row appearing.
@export var row_stagger: float = 0.14
## How long each row's number takes to count up.
@export var count_up_seconds: float = 0.7
## Pause after the last row before the letter grade slams in.
@export var grade_delay: float = 0.5

@onready var rows_box: VBoxContainer = $MarginContainer/Column/RowsBox
@onready var grade_letter: Label = $MarginContainer/Column/GradeCard/GradeStack/GradeLetter
@onready var grade_caption: Label = $MarginContainer/Column/GradeCard/GradeStack/GradeCaption
@onready var title_label: Label = $MarginContainer/Column/TitleLabel
@onready var btn_selesai: Button = $MarginContainer/Column/BtnSelesai

const ROW_SCENE := preload("res://Scenes/EndGame/RunResultRow.tscn")

## The report's six icons, preloaded so a row swap costs nothing at
## reveal time. Transparent SVGs authored alongside the project's other
## placeholder icons -- see Task 11's note on why SVG and not PNG.
const ICON_MINIGAME_MENANG := preload("res://Assets/Images/UI/Placeholders/icon_minigame_menang.svg")
const ICON_MINIGAME_KALAH := preload("res://Assets/Images/UI/Placeholders/icon_minigame_kalah.svg")
const ICON_POIN := preload("res://Assets/Images/UI/Placeholders/icon_poin.svg")
const ICON_BARANG := preload("res://Assets/Images/UI/Placeholders/icon_barang.svg")
const ICON_UANG := preload("res://Assets/Images/UI/Placeholders/icon_uang.svg")
const ICON_EVENT := preload("res://Assets/Images/UI/Placeholders/icon_event.svg")

## One caption per letter band, so the grade says something rather than
## just scoring something.
const GRADE_CAPTIONS := {
	"A+": "Sempurna. Tidak ada yang tertinggal.",
	"A": "Luar biasa. Kelas ini beruntung punya kamu.",
	"A-": "Sangat baik. Hampir sempurna.",
	"B+": "Baik sekali. Masih ada ruang untuk rapi.",
	"B": "Baik. Targetnya tercapai.",
	"B-": "Cukup baik. Beberapa hal bisa lebih halus.",
	"C+": "Lulus, dengan perjuangan.",
	"C": "Lulus tipis. Lain kali lebih awal.",
	"C-": "Nyaris tidak lulus, tapi lulus.",
	"D": "Belum berhasil. Mereka masih menunggumu.",
}

var _grade_text: String = "D"
var _money_row: Control = null


func _ready() -> void:
	btn_selesai.pressed.connect(_on_selesai_pressed)
	AudioDirector.play_bgm(&"run_result")

	title_label.text = "Hasil %s" % GameState.get_grade_name()
	grade_letter.text = ""
	grade_caption.text = ""

	_build_rows()
	_compute_grade()
	_play_reveal()


## The six rows are instanced from RunResultRow.tscn rather than authored
## in this scene. Reviewed exception to the no-runtime-construction rule
## (per-call-dynamic content): the row count is fixed, but every value is
## run-dependent, and authoring six frozen rows would mean six near-empty
## nodes plus a parallel wiring table. Registered in
## tests/test_viewport_editability.gd's ALLOWED dict, not BASELINE.
func _build_rows() -> void:
	var stats: RunStats = GameState.run_stats
	var spec := [
		[ICON_MINIGAME_MENANG, "Minigame selesai", float(stats.minigames_won), ""],
		[ICON_MINIGAME_KALAH, "Minigame kalah", float(stats.minigames_lost), ""],
		[ICON_POIN, "Total poin minigame", stats.minigame_points, " poin"],
		[ICON_BARANG, "Barang dipakai", float(stats.items_used), ""],
		[ICON_UANG, "Uang dari wirausaha", float(stats.wirausaha_money), "G"],
		[ICON_EVENT, "Murid ikut event", float(stats.event_student_count()), " murid"],
	]
	for entry in spec:
		var row := ROW_SCENE.instantiate()
		rows_box.add_child(row)
		row.set_row(String(entry[1]), float(entry[2]), String(entry[3]),
			entry[0] as Texture2D)
		row.modulate.a = 0.0
		if String(entry[1]) == "Uang dari wirausaha":
			_money_row = row


func _compute_grade() -> void:
	var counted: Array = GameState.count_targets_cleared()
	var passed := not GameState.run_failed and GameState.check_semester_passed()
	var run_score := RunGrade.score(GameState.run_stats,
		int(counted[0]), int(counted[1]), GameState.approved_students.size())
	_grade_text = RunGrade.letter(run_score, passed)


## Title first, then the rows one at a time counting up, then the letter.
## The letter lands last on purpose: the numbers build the case, and the
## grade is the verdict on them.
func _play_reveal() -> void:
	Juice.pop_in(title_label)

	for i in range(rows_box.get_child_count()):
		await get_tree().create_timer(row_stagger).timeout
		if not is_instance_valid(self):
			return
		var row: Control = rows_box.get_child(i)
		Juice.pop_in(row)
		row.play_count_up(count_up_seconds)
		if row == _money_row:
			AudioDirector.play_sfx(&"coin")
		else:
			AudioDirector.play_sfx(&"pop")

	await get_tree().create_timer(count_up_seconds + grade_delay).timeout
	if not is_instance_valid(self):
		return
	_slam_grade()


func _slam_grade() -> void:
	var tokens := DesignTokens.load_default()
	grade_letter.text = _grade_text
	grade_caption.text = String(GRADE_CAPTIONS.get(_grade_text, ""))
	grade_letter.add_theme_color_override("font_color",
		tokens.state_success if RunGrade.is_top_grade(_grade_text)
		else (tokens.state_danger if _grade_text == "D" else tokens.currency_gold))

	Juice.set_pivot_center(grade_letter)
	grade_letter.scale = Vector2(3.0, 3.0)
	grade_letter.modulate.a = 0.0

	var t := Juice.tokens()
	var tw := grade_letter.create_tween().set_parallel(true)
	tw.tween_property(grade_letter, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(grade_letter, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(grade_letter.get_parent(), 8.0)
		if RunGrade.is_top_grade(_grade_text):
			AudioDirector.play_sfx(&"reward")
		elif _grade_text == "D":
			AudioDirector.play_sfx(&"fail"))


## Applies the progression SemesterEnd used to apply, then goes home.
## Exactly the same three cases as before -- advance, beat-the-game reset,
## or retry the same grade -- just moved to the end of the sequence.
func _on_selesai_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	_apply_progression()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	Transition.change_scene("res://Scenes/MainMenu/main_menu.tscn")


func _apply_progression() -> void:
	if GameState.run_failed:
		# A failed grade is retried from the top, roster intact.
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.run_stats.reset()
		GameState.run_failed = false
		return

	if GameState.current_grade < 9:
		GameState.current_grade += 1
		for student in GameState.approved_students:
			student["kepribadian1"] = 80.0
			student["kepribadian2"] = 80.0
			student.erase("base_akademis1")
			student.erase("base_akademis2")
			student.erase("base_akademis3")
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.returned_from_student_card = false
		GameState.lobby_tutorial_completed = true
		GameState.run_stats.reset()
	else:
		# The game is beaten: unlock level select and reset to Kelas 7.
		GameState.is_game_beaten = true
		GameSettings.save_settings()
		GameState.set_grade(7)
		GameState.approved_students.clear()
		GameState.grade7_student_ids.clear()
		GameState.lobby_tutorial_completed = false
```

Note `set_grade(7)` in the last branch already clears `run_stats`,
`day_schedules` is cleared by the `set_grade` path's callers today — verify
that against `set_grade()` as written in Task 3, and add an explicit
`GameState.day_schedules.clear()` there if it does not.

The tutorial-flag resets that SemesterEnd's beat-the-game branch performed
(`AturJadwalScript.tutorial_phase1_done`, `LobbyScript.tutorial_shown`) must be
carried over verbatim into the `else` branch above — copy them from
`SemesterEnd.gd`'s old `_on_restart_pressed()` before deleting it.

- [ ] **Step 3b: Build the scene through the MCP**

Per the tree above. `RowsBox` stays childless. `scene_save()`.

- [ ] **Step 3c: Register the runtime-construction exception**

In `tests/test_viewport_editability.gd`, add to the `ALLOWED` dict:

```gdscript
	"Scripts/EndGame/RunResult.gd": "Six report rows instanced from RunResultRow.tscn -- per-call-dynamic content: the values are entirely run-dependent, and the template carries all the visual structure.",
```

- [ ] **Step 4: Run to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="run_result")
test_run(suite="viewport_editability")
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/RunResult.gd Scenes/EndGame/RunResult.tscn tests/test_run_result.gd tests/test_viewport_editability.gd
git commit -m "feat(endgame): add the graded run-result report"
```

---

## Task 14: Walk the whole sequence, then document it

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-09-02-end-of-grade-sequence.md` (STATUS block)

- [ ] **Step 1: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: every suite green. Fix anything red before continuing — in
particular `test_project_hygiene` (new scenes bring new `ext_resource` UIDs)
and `test_script_documentation` (every new `@export` needs its `##` line).

- [ ] **Step 2: Walk the sequence once, live**

Seed rather than play (this is the rule that saves the most time here):

1. `project_run`, then F1 → General tab → **⚡ Seed Playtest State**.
2. Scenes tab → teleport to **Notice Tes Besar**.
3. Tap through: notice → exam cutscene (4 lines) → stat check → win screen
   (4 lines) → run result → main menu.
4. `editor_screenshot` at the notice, the stat check, and the run result.
5. Teleport back to the stat check with a deliberately failing roster (use the
   debug overlay's stat editor to drop one student below target) and confirm
   the lose path: stat check → lose cutscene → run result showing **D**.

Note anything that looks wrong and fix it before the docs commit. Coordinates
for simulated clicks are in the 1080-wide design space; rescale by
`original_width / 1080` from `editor_screenshot` if you drive it by input
events, and send a `motion` event before each `button` press.

- [ ] **Step 3: Update `CLAUDE.md`**

Replace the loop line in "The game" with:

```
**Loop:** **MainMenu (boot)** → CutScene → StudentCard (approve roster) →
**Lobby (hub)** → AturJadwal (assign week) → StudentList → SchoolDay
(simulate 5 days) → ResultCheckup → back to Lobby. On the final week of a
grade, SchoolDay instead runs the end-of-grade sequence: **TesNotice →
CutScene (exam branch) → SemesterEnd (stat check) → WinScreen or the
game-over cutscene → RunResult → MainMenu.**
```

Add to "Current work":

```
The 2026-09-02 end-of-grade sequence is complete. Spec:
`docs/superpowers/specs/2026-09-02-end-of-grade-sequence.md`. It added the
Tes Besar notice, the cutscene's third (exam) branch, a per-grade `RunStats`
tally on GameState, the `RunGrade` A+/…/C-/D scorer, a cutscene-styled
WinScreen, and the RunResult report — which now owns grade progression, moved
off SemesterEnd. Placeholders still outstanding: every cutscene line in the
exam and win branches is marked `[PLACEHOLDER]`, the exam/win backdrops reuse
the intro's CG images, and the three new BGM ids alias existing tracks.
```

- [ ] **Step 4: Write the spec's STATUS block**

Append to the spec a `## STATUS` section recording what shipped, every
deviation from this plan, and the outstanding placeholders (dialogue text,
backdrop art, the three aliased BGM ids), matching the format the other specs
in `docs/superpowers/specs/` use.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-09-02-end-of-grade-sequence.md
git commit -m "docs(endgame): record the end-of-grade sequence and its placeholders"
```

---

## Follow-ups (not in this plan)

- Real art for the Tes Besar notice card and both cutscene backdrops, and
  finished icons replacing the six hand-authored SVG placeholders (drop-in:
  same six paths, or the same six names as 128x128 PNGs with alpha).
- Final dialogue copy replacing the eight `[PLACEHOLDER]` lines.
- Three dedicated audio tracks for `exam_notice`, `exam_cutscene`,
  `run_result`.
- Balance pass on `RunGrade`'s weights and `MONEY_FULL_MARKS` once real runs
  produce real numbers — right now 20000 rupiah is an estimate, not a
  measurement.
