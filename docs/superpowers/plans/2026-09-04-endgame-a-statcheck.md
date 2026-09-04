# End-Game Plan A — ExamProgress Parallax + StatCheck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the exam-intro cutscene and the SemesterEnd card carousel with an automated, one-student-at-a-time stat check that fills each bar, pops at 100%, accumulates a single 3-star run meter, and fades to white — and give ExamProgress a slow left-to-right background pan while its bar fills.

**Architecture:** One new scene, `StatCheck`, plays a scripted sequence over the roster: for each student a card slides in from the right, three `StatCheckRow`s fill in order (akademis → seni budaya → olahraga), a full bar pops (squash + `RewardBurst` + sfx), and every cleared stat adds `1 ÷ (roster × 3)` of three stars to a shared `StarMeter`. The pass rule moves to `GameState.run_stars() >= Balance.STAR_WIN_THRESHOLD` (2.0 of 3.0), which is mathematically the old "average per-student stars ≥ 2" and replaces all-or-nothing. The exam cutscene beat and SemesterEnd are deleted outright. Plan B adds win/lose screens; until then StatCheck's white fade hands off to RunResult through two constants Plan B repoints.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` tests run in-editor via the `godot-ai` MCP `test_run` tool. Scenes are built through the editor by the controller (`scene_open` / `node_create` / `node_set_property` / `scene_save`), never hand-edited while the editor is attached.

**Spec:** No separate spec doc — the user's 2026-09-04 end-game brief and its Q&A are captured under "Requirements" and "Decisions taken as defaults" below. Plans B (win/lose screens) and C (RunResult redesign) follow this one.

## Requirements (from the brief)

1. TesNotice is unchanged.
2. ExamProgress: while the progress bar fills, the background image moves slowly from left to right.
3. After ExamProgress, check the chosen students' stats one by one: each student's page (mockup_statcheck) slides in from the right; each bar fills slowly; at 100% it gives a satisfying pop, in order akademis → seni budaya → atletik (olahraga); then slide to the next student until all are checked; then a white screen fades in.
4. Stars: **a single run-level 3-star meter**. Each stat at 100% of its target contributes one equal share; stats below target contribute nothing (user's correction + Q&A). 2–3 stars is a win, 1 star and below is a loss.
5. The exam-intro cutscene beat is deleted. The game-start intro cutscene and the Kelas 7–9 level-select modal inside `cut_scene.gd` stay.

## Decisions taken as defaults (user said "okay done" — override any by name)

- **D1 Parallax image:** reuse `res://Assets/Images/UI/blur_background.png` (it is 369×654, so the Backdrop is widened to 1296×1920 under KEEP_ASPECT_COVERED and panned by −216 px over the fill, never exposing an edge). One pass, no loop.
- **D7 Pan direction:** the brief says "the background image moves slowly from left to right". This is implemented as a **camera** pan rightward, which translates the *image* leftward — hence `pan_pixels = -216.0` (negative). The alternative reading (the image itself sliding rightward, positive px) is equally defensible; if the motion looks wrong in Step 5's live check, flip the sign and widen the Backdrop's start offset instead of its width. Every description of this motion — the script header, the live-check text, the CLAUDE.md sentence — must state the same direction.
- **D2 Bar fill:** `stat ÷ target × 100`, clamped to 100 — a student who met the target shows a full bar.
- **D3 SemesterEnd** (`SemesterEnd.tscn/.gd`, `ResultStatRow.tscn/.gd`, `tests/test_semester_end.gd`) is deleted once StatCheck exists. This also retires the DetailPopup layout bug found on 2026-09-04.
- **D4 Card fields:** the mockup shows Nama / Jenis Kelamin / Tanggal Lahir. `StudentData` has `student_name` and a free-text `profil` ("Agama: …\nJenis Kelamin: …") and **no birthday** — the card shows Nama and the `profil` lines; Tanggal Lahir is omitted until the data exists.
- **D5 Interim hand-off:** Plan B owns win/lose screens. Here, `StatCheck.NEXT_SCENE_WIN` and `NEXT_SCENE_LOSE` both point at `res://Scenes/EndGame/RunResult.tscn`; Plan B changes the two constants and adds the white fade-*out* on its screens.
- **D6 BGM:** StatCheck keeps `exam_notice` playing (continuity from TesNotice/ExamProgress). `result_win`/`result_lose` move to Plan B's screens; the `exam_cutscene` BGM id is removed with the beat it scored.

## Global Constraints

- Test suites MUST be `@tool` and extend `McpTestSuite`, or the runner reports them abstract/broken.
- **No test may be a coroutine.** The runner calls `suite.call(name)` without awaiting; an `await` silently aborts the test and it reports "0 assertions". `RewardParticles.fire()` and every slide/fill sequence here are coroutines — tests assert on state and source text, never by playing the sequence.
- Tests run via the MCP tool `test_run(suite="<name>")`. **After editing any `.gd` from outside the editor, run `filesystem_manage(op="scan")` first**; if the runner still serves stale bytecode, force a reload with a no-op `script_patch` on that file.
- **Scenes are built by the controller through the editor**, never by hand while it is attached: `scene_open` → `node_create` / `node_set_property` / `batch_execute` → `scene_save`. `anchors_preset` is inert (set the four anchors + offsets); numbers unquoted; `node_create` appends last; a node's type can only be changed by delete-and-recreate. Implementer subagents write `.gd` and tests and hand the controller an exact node list.
- **Never add a `theme_override_*`.** Use `ThemeFactory` variations (`H1Label`, `H2Label`, `TitleLabel`, `CaptionLabel`, `Card`, `Scrim`, `StatBar`/`StatBarAkademis`/`StatBarSeniBudaya`/`StatBarOlahraga`, `PrimaryButton`…). Layout-only constant overrides (`separation`, `margin_*`) are the only exception.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`; repeated rows are a `PackedScene`. The per-student card is instanced from a template scene (a reviewed per-call-dynamic exception, registered in `tests/test_viewport_editability.gd`'s `ALLOWED` dict the way `RunResult`'s rows are).
- No emoji as UI iconography — the star is an SVG texture.
- UI text is **Indonesian**; systems code and identifiers are English. Naming quirk: `akademis1`=academic, `akademis2`=seni budaya, `akademis3`=olahraga.
- Tunable numbers live in a named `const` block or an `@export` with a `##` doc line. Every script needs a `##` file header (`tests/test_script_documentation.gd`).
- The project has no save system; nothing here adds persistence.
- Commits: Conventional Commits with a scope. The working tree may carry unrelated uncommitted files — **every commit names its files explicitly; never `git add -A`.** Note `git add <file>` stages the whole file: if a file you commit already carries unrelated uncommitted hunks, the controller commits it with a revert-commit-reapply procedure (see the 2026-09-04 rehearsal ledger, Ruling 5).
- Baseline before this plan: **796/796 tests, 55 suites** (after commit `8288d44`).

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/Balance.gd` (modify) | Two new tunables: `STARS_TOTAL`, `STAR_WIN_THRESHOLD`. |
| `Scripts/GameState.gd` (modify, :267-298) | `run_stars()` and `check_semester_passed()` rewritten on top of `count_targets_cleared()`; `is_exam_intro_cutscene` removed. |
| `Scripts/EndGame/ExamProgress.gd` (modify) | Parallax pan tweened alongside the fill; hand-off to StatCheck. |
| `Scenes/EndGame/ExamProgress.tscn` (controller) | Backdrop widened for the pan. |
| `Assets/Images/UI/Placeholders/icon_star.svg` (create) | Placeholder star, filled; used by `StarMeter`. |
| `Scenes/EndGame/StatCheckRow.tscn` + `Scripts/EndGame/StatCheckRow.gd` (create) | Icon + `StatBar`; `set_result(value, target)`, `fill()` coroutine, `pop()`. |
| `Scenes/EndGame/StatCheckCard.tscn` + `Scripts/EndGame/StatCheckCard.gd` (create) | The mockup card: name/profil panel, portrait, three rows. Template instanced per student. |
| `Scenes/EndGame/StatCheck.tscn` + `Scripts/EndGame/StatCheck.gd` (create) | The sequence: slide cards in, fill rows, accumulate `StarMeter`, white fade, hand-off. |
| `Scripts/EndGame/StarMeter.gd` (create) + three `TextureProgressBar`s inside `StatCheck.tscn` | `set_stars(float)` renders 0.0–3.0 across three star textures. |
| `Scripts/CutScene/cut_scene.gd` + `Scenes/CutScene/cut_scene.tscn` (modify) | Exam-intro branch, `BtnLanjutExam`, flag reads removed. |
| `Scripts/Audio/AudioDirector.gd` (modify) | `exam_cutscene` BGM id removed. |
| `Scripts/Debug/EndGameRehearsal.gd` (modify) | `is_exam_intro_cutscene` dropped from `SNAPSHOT_KEYS` and `arm()`; comments updated. |
| Deleted | `Scenes/EndGame/SemesterEnd.tscn`, `Scripts/EndGame/SemesterEnd.gd`, `Scenes/EndGame/ResultStatRow.tscn`, `Scripts/EndGame/ResultStatRow.gd`, `tests/test_semester_end.gd` (+ `.uid` sidecars). |
| Tests | `tests/test_economy_state.gd` (modify), `tests/test_exam_progress.gd` (modify), `tests/test_stat_check.gd` (create), `tests/test_cutscene.gd` (modify), `tests/test_audio_director.gd` (modify), `tests/test_audio_coverage.gd` (modify), `tests/test_end_game_rehearsal.gd` (modify), `tests/test_viewport_editability.gd` (modify: ALLOWED entry). |
| `CLAUDE.md` (modify) | "Current work" paragraph; the rehearsal paragraph's flow line. |

---

### Task 1: The star rule — `run_stars()` and the new pass predicate

**Files:**
- Modify: `Scripts/Balance.gd:31-33` (append two consts after `TARGET_KENAIKAN_KELAS_9`)
- Modify: `Scripts/GameState.gd:267-277` (`check_semester_passed`), add `run_stars()`
- Test: `tests/test_economy_state.gd` (append)

**Interfaces:**
- Consumes: `GameState.count_targets_cleared() -> Array` (`[cleared, total]`, `GameState.gd:285`).
- Produces: `Balance.STARS_TOTAL: float = 3.0`, `Balance.STAR_WIN_THRESHOLD: float = 2.0`, `GameState.run_stars() -> float` (0.0–3.0), `GameState.check_semester_passed() -> bool` (now `run_stars() >= STAR_WIN_THRESHOLD`; empty roster still returns `true`).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_economy_state.gd` (it already saves and restores `GameState.approved_students` by hand — follow that pattern):

```gdscript
# ────────────────────────────────────────────────────────── run stars (Plan A)

## Four students, twelve stats. `cleared` of them meet their target.
func _roster_with_cleared(cleared: int) -> Array:
	var roster: Array = []
	var k := 0
	for i in range(4):
		var s := {"id": i + 1, "name": "M%d" % (i + 1)}
		for pair in [["akademis1", "target_akademis1"],
				["akademis2", "target_akademis2"],
				["akademis3", "target_akademis3"]]:
			s[pair[1]] = 60.0
			s[pair[0]] = 70.0 if k < cleared else 40.0
			k += 1
		roster.append(s)
	return roster


func test_run_stars_is_three_times_the_cleared_fraction() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_cleared(8)
	assert_true(is_equal_approx(GameState.run_stars(), 2.0),
		"8 of 12 stats cleared is 2.0 stars")
	GameState.approved_students = _roster_with_cleared(7)
	assert_true(is_equal_approx(GameState.run_stars(), 1.75),
		"7 of 12 is 1.75 -- the meter is continuous, not rounded")
	GameState.approved_students = _roster_with_cleared(12)
	assert_true(is_equal_approx(GameState.run_stars(), 3.0), "all cleared is 3.0")
	GameState.approved_students = _roster_with_cleared(0)
	assert_true(is_equal_approx(GameState.run_stars(), 0.0), "none cleared is 0.0")
	GameState.approved_students = original


func test_run_stars_is_zero_for_an_empty_roster() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = []
	assert_true(is_equal_approx(GameState.run_stars(), 0.0),
		"no stats means no stars, and no divide by zero")
	GameState.approved_students = original


func test_semester_passes_at_two_stars_and_fails_below() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_cleared(8)   # exactly 2.0
	assert_true(GameState.check_semester_passed(), "2.0 stars passes")
	GameState.approved_students = _roster_with_cleared(7)   # 1.75
	assert_false(GameState.check_semester_passed(), "1.75 stars fails")
	GameState.approved_students = _roster_with_cleared(4)   # 1.0
	assert_false(GameState.check_semester_passed(), "1 star fails")
	GameState.approved_students = original


func test_semester_pass_no_longer_requires_every_student_to_clear_everything() -> void:
	# The old rule: one missed stat anywhere failed the run. The new rule
	# carries a weak student on a strong roster. 11 of 12 cleared = 2.75.
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_cleared(11)
	assert_true(GameState.check_semester_passed(),
		"one missed target no longer fails the whole run")
	GameState.approved_students = original


func test_empty_roster_still_counts_as_passed() -> void:
	# Preserved from the old predicate: debug teleports with no roster must
	# not read as a loss.
	var original: Array = GameState.approved_students
	GameState.approved_students = []
	assert_true(GameState.check_semester_passed(), "empty roster passes, as before")
	GameState.approved_students = original


func test_star_tunables_live_in_balance() -> void:
	assert_true(is_equal_approx(Balance.STARS_TOTAL, 3.0), "three stars total")
	assert_true(is_equal_approx(Balance.STAR_WIN_THRESHOLD, 2.0), "two stars to win")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="economy_state")`
Expected: FAIL — the suite fails to load with `Static function "run_stars()" not found` / `Cannot find member "STARS_TOTAL" in base "Balance"` (in this project a suite referencing a missing symbol fails to load as a whole; that is the RED).

- [ ] **Step 3: Write the implementation**

In `Scripts/Balance.gd`, directly after `static var TARGET_KENAIKAN_KELAS_9 := 40.0` (line 33), add:

```gdscript

## The end-of-grade star meter (Plan A, 2026-09-04). One star-share per
## academic target cleared across the whole roster: stars = STARS_TOTAL ×
## cleared ÷ total. The run is won at STAR_WIN_THRESHOLD or better -- so
## with four students (twelve targets), 8 cleared is exactly 2.0 and wins,
## 7 is 1.75 and loses. Mathematically the same as "average per-student
## stars ≥ 2", which is how the brief first phrased it.
static var STARS_TOTAL := 3.0
static var STAR_WIN_THRESHOLD := 2.0
```

In `Scripts/GameState.gd`, replace the whole `check_semester_passed()` function (lines 267–277) with:

```gdscript
## The run's star meter, 0.0 to Balance.STARS_TOTAL: every academic target
## cleared anywhere on the roster earns an equal share of the three stars.
## Continuous on purpose -- StatCheck's meter fills star by star as the
## check plays, and 7 of 12 must read as 1.75, not "1".
func run_stars() -> float:
	var counted: Array = count_targets_cleared()
	var total := int(counted[1])
	if total <= 0:
		return 0.0
	return Balance.STARS_TOTAL * float(counted[0]) / float(total)


## Win rule since Plan A: the star meter at or above
## Balance.STAR_WIN_THRESHOLD. Replaces "every student clears all three
## targets" -- one weak student on a strong roster no longer loses the run.
## An empty roster still passes, as it always did, so a debug teleport with
## nothing approved never reads as a loss.
func check_semester_passed() -> bool:
	if approved_students.is_empty():
		return true
	return run_stars() >= Balance.STAR_WIN_THRESHOLD
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="economy_state")`
Expected: PASS, including the 6 new tests. Then `test_run(suite="end_game_rehearsal")` — still 17/17: against that suite's two-student `_fake_source()`, its Lulus preset clears 6/6 (3.0 ≥ 2.0) and Gagal clears 0/6 (0.0 < 2.0), so both preset tests hold under the new rule. Then `test_run(suite="run_result")` — unchanged, RunResult only calls the predicate.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Balance.gd Scripts/GameState.gd tests/test_economy_state.gd
git commit -m "feat(endgame): score the run on a 3-star meter, win at 2

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: ExamProgress parallax and hand-off to StatCheck

**Files:**
- Modify: `Scripts/EndGame/ExamProgress.gd`
- Controller: `Scenes/EndGame/ExamProgress.tscn` — `Backdrop` node
- Test: `tests/test_exam_progress.gd:59-64` (replace one test, add three)

**Interfaces:**
- Consumes: nothing new. StatCheck does not exist yet — the scene path is a constant that Task 4 makes real; `ResourceLoader.exists()` is asserted in Task 4's suite, not here.
- Produces: `ExamProgress.STAT_CHECK_SCENE := "res://Scenes/EndGame/StatCheck.tscn"`, `@export var pan_pixels: float = -216.0`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_exam_progress.gd`, replace `test_it_arms_the_exam_cutscene_and_routes_to_it` (lines 59–64, the whole function) with:

```gdscript
func test_it_routes_to_the_stat_check_and_never_arms_a_cutscene() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/EndGame/StatCheck.tscn"),
		"it routes to the stat check")
	assert_false(src.contains("is_exam_intro_cutscene"),
		"the exam-intro cutscene beat is gone; nothing arms it any more")
	assert_false(src.contains("cut_scene.tscn"),
		"it no longer routes to the cutscene")


func test_the_backdrop_pans_alongside_the_fill() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("@export var pan_pixels: float = -216.0"),
		"the pan distance is a documented, tunable export")
	assert_true(src.contains("tween_property(backdrop, \"position:x\""),
		"the backdrop's x position is tweened")
	assert_true(src.contains("fill_seconds)"),
		"the pan runs over the same duration as the fill, so they end together")


func test_the_backdrop_is_wider_than_the_viewport_so_the_pan_shows_no_edge() -> void:
	var backdrop = _screen.get_node_or_null("Backdrop")
	assert_true(backdrop is TextureRect, "Backdrop exists")
	assert_true(backdrop.size.x >= 1080.0 - (-216.0),
		"Backdrop must be at least viewport width plus |pan_pixels| wide (1296)")
	assert_eq(int(backdrop.size.y), 1920, "Backdrop keeps the full viewport height")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="exam_progress")`
Expected: FAIL — the three new tests fail on their first assertions (`StatCheck.tscn` string absent; `pan_pixels` absent; Backdrop width is 1080).

- [ ] **Step 3: Write the implementation — script**

Replace the whole of `Scripts/EndGame/ExamProgress.gd` with:

```gdscript
@tool
extends Control

## The beat between TesNotice and the stat check: "Tes sedang
## berlangsung", with a progress bar that fills over a fixed duration
## while the backdrop drifts slowly left-to-right behind it, and then hands
## off to StatCheck. Purely a pacing beat -- it carries no verdict, same
## contract as TesNotice.
##
## @tool for the same reason every other end-of-grade screen is: without
## it, this becomes a placeholder instance when the MCP test suite
## instantiates the scene inside the editor process. The runtime side
## effects (the two tweens and the scene hand-off) sit behind the
## Engine.is_editor_hint() guard in _ready().

@onready var progress_bar: ProgressBar = $MarginContainer/Content/Inner/ProgressBar
@onready var status_label: Label = $MarginContainer/Content/Inner/StatusLabel
@onready var backdrop: TextureRect = $Backdrop

## Where the fill hands off. Plan A's StatCheck replaced the exam-intro
## cutscene beat that used to sit here.
const STAT_CHECK_SCENE := "res://Scenes/EndGame/StatCheck.tscn"

## Seconds for the bar to fill from 0 to 100 before advancing. The pan
## below runs over the same span so both end on the same frame.
@export var fill_seconds: float = 4.0

## How far the backdrop drifts during the fill, in px. Negative moves the
## image left, which reads as the camera panning right. The Backdrop node
## is authored 1296 px wide (viewport 1080 + |pan|) under
## KEEP_ASPECT_COVERED, so the drift never exposes an edge -- if you widen
## the pan, widen the node to match.
@export var pan_pixels: float = -216.0

var _advancing: bool = false


func _ready() -> void:
	status_label.text = "Tes sedang berlangsung"
	progress_bar.value = 0.0

	if Engine.is_editor_hint():
		return

	AudioDirector.play_bgm(&"exam_notice")

	# One tween, two tracks, one duration: the pan is deliberately not
	# eased so it reads as a slow, steady camera move rather than a settle.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(progress_bar, "value", 100.0, fill_seconds)
	tw.tween_property(backdrop, "position:x", backdrop.position.x + pan_pixels, fill_seconds) \
		.set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	if is_instance_valid(self):
		_advance()


## Guarded the same way TesNotice guards its own auto-advance, in case a
## future tap-to-skip is added alongside the timed fill.
func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	Transition.change_scene(STAT_CHECK_SCENE)
```

- [ ] **Step 4: Controller — widen the Backdrop in the editor**

The controller runs, in the editor (the implementer only lists this):

```
scene_open("res://Scenes/EndGame/ExamProgress.tscn")
node_set_property("/ExamProgress/Backdrop", "size", {"x": 1296, "y": 1920})
node_set_property("/ExamProgress/Backdrop", "position", {"x": 0, "y": 0})
scene_save()
```

`expand_mode` (1) and `stretch_mode` (6, KEEP_ASPECT_COVERED) stay as authored on 2026-09-04, so the 369×654 image scales to cover 1296×1920 and the pan slides the covered image left by 216 px, keeping the right edge on-screen throughout.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="exam_progress")`
Expected: PASS, 10 tests (7 existing + 3 new; the replaced test is gone).

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/ExamProgress.gd Scenes/EndGame/ExamProgress.tscn tests/test_exam_progress.gd
git commit -m "feat(endgame): pan the ExamProgress backdrop and hand off to StatCheck

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `StatCheckRow` and the star placeholder

**Files:**
- Create: `Assets/Images/UI/Placeholders/icon_star.svg`
- Create: `Scripts/EndGame/StatCheckRow.gd`
- Controller: `Scenes/EndGame/StatCheckRow.tscn`
- Test: `tests/test_stat_check.gd` (create; Task 4 appends to it)

**Interfaces:**
- Consumes: `StatBar.set_stat(new_value, animate, pop)` (`Scripts/UI/StatBar.gd:171`), `StatBar.category`, `Juice.fill_bar(bar, to, duration, delay) -> Tween` (`Juice.gd:143`), `AnimUtils.squash_bounce(node)`, `RewardParticles.fire()` on `res://Scenes/SchoolSimulation/RewardBurst.tscn`.
- Produces: `StatCheckRow` (`class_name`, `extends HBoxContainer`) with `@export var category: String`, `@export var icon: Texture2D`, `static func ratio(value, target) -> float`, `func set_result(value: float, target: float) -> void` (instant, no animation — sets the public `target_ratio`, zeroes the bar), `func fill() -> void` (coroutine: fills to the ratio over `fill_seconds`, then `pop()` if it reached 100), `func pop() -> void`, `var target_ratio: float`, `var cleared: bool` (true after a full fill), `@export var fill_seconds: float = 0.9`, `signal filled(cleared: bool)`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_stat_check.gd`:

```gdscript
@tool
extends McpTestSuite

## StatCheck (Plan A, 2026-09-04): the automated one-by-one stat check that
## replaced the SemesterEnd card carousel. The sequence itself is a chain
## of coroutines (slides, fills, a white fade), so nothing here plays it --
## these are structural checks on bare instantiate()s plus source scans for
## the wiring, per the runner's no-coroutine rule documented in
## test_lobby.gd. StatCheckRow's non-animated path IS exercised live.

const _ROW_SCENE := "res://Scenes/EndGame/StatCheckRow.tscn"
const _ROW_SCRIPT := "res://Scripts/EndGame/StatCheckRow.gd"
const _STAR_ICON := "res://Assets/Images/UI/Placeholders/icon_star.svg"


func suite_name() -> String:
	return "stat_check"


# ────────────────────────────────────────────────────────────── StatCheckRow

func test_row_scene_loads_and_holds_an_icon_and_a_stat_bar() -> void:
	var row = load(_ROW_SCENE).instantiate()
	track(row)
	assert_true(row is StatCheckRow, "the row wears StatCheckRow.gd")
	assert_true(row.get_node_or_null("Icon") is TextureRect, "Icon node")
	assert_true(row.get_node_or_null("Bar") is StatBar, "Bar is a StatBar")


func test_row_ratio_is_value_over_target_capped_at_100() -> void:
	assert_true(is_equal_approx(StatCheckRow.ratio(30.0, 60.0), 50.0), "half")
	assert_true(is_equal_approx(StatCheckRow.ratio(60.0, 60.0), 100.0), "met")
	assert_true(is_equal_approx(StatCheckRow.ratio(90.0, 60.0), 100.0), "capped")
	assert_true(is_equal_approx(StatCheckRow.ratio(10.0, 0.0), 0.0),
		"a zero target reads as empty, never a divide by zero")


func test_row_set_result_arms_the_target_without_animating() -> void:
	var row = load(_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	row.set_result(45.0, 60.0)
	assert_true(is_equal_approx(row.get_node("Bar").value, 0.0),
		"set_result leaves the bar empty -- fill() is what moves it")
	assert_true(is_equal_approx(row.target_ratio, 75.0), "the ratio is armed")
	assert_false(row.cleared, "not cleared until a full fill has played")
	Engine.get_main_loop().root.remove_child(row)


func test_row_fill_is_a_coroutine_that_pops_only_at_full() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("func fill() -> void:"), "fill() exists")
	assert_true(src.contains("await Juice.fill_bar(bar, target_ratio, fill_seconds).finished"),
		"fill() awaits Juice.fill_bar over fill_seconds")
	assert_true(src.contains("if target_ratio >= 100.0:"),
		"the pop is gated on a full bar")
	assert_true(src.contains("filled.emit(cleared)"),
		"fill() reports whether the stat cleared")


func test_row_pop_is_squash_burst_and_sfx() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("AnimUtils.squash_bounce(bar)"), "squash the bar")
	assert_true(src.contains("res://Scenes/SchoolSimulation/RewardBurst.tscn"),
		"instance the authored RewardBurst -- never build particles at runtime")
	assert_true(src.contains("AudioDirector.play_sfx(&\"pop\")"), "the pop cue")


func test_star_placeholder_exists_and_loads_as_a_texture() -> void:
	assert_true(ResourceLoader.exists(_STAR_ICON), "icon_star.svg exists")
	var tex = load(_STAR_ICON)
	assert_true(tex is Texture2D, "it imports as a Texture2D")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="stat_check")`
Expected: FAIL — the suite fails to load (`Identifier "StatCheckRow" not declared`).

- [ ] **Step 3: Write the star SVG**

Create `Assets/Images/UI/Placeholders/icon_star.svg` (flat, same style as the other placeholders):

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><polygon points="50,6 61,38 95,38 67,58 78,92 50,71 22,92 33,58 5,38 39,38" fill="#f5c542" stroke="#b98a12" stroke-width="4" stroke-linejoin="round"/></svg>
```

- [ ] **Step 4: Write the row script**

Create `Scripts/EndGame/StatCheckRow.gd`:

```gdscript
@tool
class_name StatCheckRow
extends HBoxContainer

## One subject row on a StatCheck card: an icon and a StatBar, nothing
## else -- the mockup shows no numbers. Replaces SemesterEnd's
## ResultStatRow, which carried a title and a value label the new design
## dropped.
##
## Two-phase on purpose. set_result() only arms the target ratio and
## leaves the bar empty; fill() is the animated beat StatCheck plays for
## each row in turn, and it is the only thing that moves the bar. A full
## fill pops -- squash, an authored RewardBurst, the pop cue -- and reports
## `cleared` so the card's star meter can count it.

## One of StatBar's categories: Akademis, SeniBudaya, Olahraga.
@export var category: String = "Akademis":
	set(value):
		category = value
		if is_node_ready():
			bar.category = value

## Subject icon shown on Icon.
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			icon_rect.texture = value

## Seconds a fill takes from empty to its target ratio. Slower than
## Juice's dur_slow because this is the whole beat, not a settle.
@export var fill_seconds: float = 0.9

## Emitted when fill() finishes; true when the bar reached 100.
signal filled(cleared: bool)

## The authored one-shot burst thrown at a full bar. Instanced, never
## built -- see the project's "no visual is built at runtime" rule.
const BURST_SCENE := "res://Scenes/SchoolSimulation/RewardBurst.tscn"

## Where the fill will stop, 0-100. Armed by set_result().
var target_ratio: float = 0.0
## True once fill() has played to 100.
var cleared: bool = false

@onready var icon_rect: TextureRect = $Icon
@onready var bar: StatBar = $Bar


func _ready() -> void:
	bar.category = category
	icon_rect.texture = icon
	bar.value = 0.0


## value ÷ target as a 0-100 percentage, capped so a stat past its target
## reads as exactly full. A zero target reads as empty rather than
## dividing by zero -- the case when a row is armed with no StudentData.
static func ratio(value: float, target: float) -> float:
	if target <= 0.0:
		return 0.0
	return clampf(value / target * 100.0, 0.0, 100.0)


## Arm the row. Does not animate: the bar stays empty until fill().
func set_result(value: float, target: float) -> void:
	target_ratio = ratio(value, target)
	cleared = false
	bar.value = 0.0


## The beat. A coroutine -- StatCheck awaits it row by row; never call it
## from a test (the MCP runner does not await).
func fill() -> void:
	await Juice.fill_bar(bar, target_ratio, fill_seconds).finished
	if not is_inside_tree():
		return
	if target_ratio >= 100.0:
		cleared = true
		pop()
	filled.emit(cleared)


## The satisfying part: a scale-only squash (Juice.pop_in would blink the
## bar transparent), a burst off the bar's right cap, and the pop cue.
func pop() -> void:
	AnimUtils.squash_bounce(bar)
	var burst: RewardParticles = load(BURST_SCENE).instantiate()
	add_child(burst)
	burst.position = bar.position + Vector2(bar.size.x, bar.size.y * 0.5)
	burst.plays_sfx = false
	burst.fire()
	AudioDirector.play_sfx(&"pop")
```

- [ ] **Step 5: Controller — build `StatCheckRow.tscn` in the editor**

```
scene_manage(op="create", params={"path": "res://Scenes/EndGame/StatCheckRow.tscn", "root_type": "HBoxContainer", "root_name": "StatCheckRow"})
script_attach("/StatCheckRow", "res://Scripts/EndGame/StatCheckRow.gd")
batch_execute:
  set_property /StatCheckRow custom_minimum_size {x: 520, y: 96}
  create_node TextureRect "Icon" parent /StatCheckRow
  set_property /StatCheckRow/Icon custom_minimum_size {x: 96, y: 96}
  set_property /StatCheckRow/Icon expand_mode 1
  set_property /StatCheckRow/Icon stretch_mode 5
  set_property /StatCheckRow/Icon texture "res://Assets/Images/UI/Placeholders/icon_akademis.svg"
  create_node ProgressBar "Bar" parent /StatCheckRow
  set_property /StatCheckRow/Bar script "res://Scripts/UI/StatBar.gd"
  set_property /StatCheckRow/Bar custom_minimum_size {x: 0, y: 56}
  set_property /StatCheckRow/Bar size_flags_horizontal 3
  set_property /StatCheckRow/Bar size_flags_vertical 4
  set_property /StatCheckRow/Bar category "Akademis"
  set_property /StatCheckRow/Bar show_value_label false
scene_save()
```

(`Bar` gets `StatBar.gd` attached by setting its `script` property; StatBar's own `_ready` resolves `theme_type_variation` from `category`.)

- [ ] **Step 6: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` (a new `class_name` needs the scan; if `StatCheckRow` is still unknown, no-op `script_patch` the file) then `test_run(suite="stat_check")`
Expected: PASS, 6 tests.

- [ ] **Step 7: Commit**

```bash
git add Assets/Images/UI/Placeholders/icon_star.svg Assets/Images/UI/Placeholders/icon_star.svg.import Scripts/EndGame/StatCheckRow.gd Scripts/EndGame/StatCheckRow.gd.uid Scenes/EndGame/StatCheckRow.tscn tests/test_stat_check.gd tests/test_stat_check.gd.uid
git commit -m "feat(endgame): add StatCheckRow and the star placeholder

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

(The `.import` and `.uid` sidecars are generated by the editor on scan; include whichever exist.)

---

### Task 4: `StatCheckCard`, `StarMeter`, and the `StatCheck` sequence

**Files:**
- Create: `Scripts/EndGame/StatCheckCard.gd`, `Scripts/EndGame/StarMeter.gd`, `Scripts/EndGame/StatCheck.gd`
- Controller: `Scenes/EndGame/StatCheckCard.tscn`, `Scenes/EndGame/StatCheck.tscn`
- Modify: `tests/test_viewport_editability.gd` (one `ALLOWED` entry)
- Test: `tests/test_stat_check.gd` (append)

**Interfaces:**
- Consumes: Task 3's `StatCheckRow` (`set_result`, `fill()`, `filled`, `cleared`); Task 1's `GameState.run_stars()`, `check_semester_passed()`; `GameState.convert_to_student_data_array() -> Array[StudentData]` (`student_name`, `avatar_texture`, `profil`, `akademis`, `seni_budaya`, `olahraga`, `target_akademis1/2/3`); `Balance.STARS_TOTAL`; `Juice.pop_in`.
- Produces:
  - `StatCheckCard` (`extends Control`): `func bind(student: StudentData) -> void`, `func rows() -> Array` (three `StatCheckRow`s in akademis/seni/olahraga order).
  - `StarMeter` (`extends HBoxContainer`): `func set_stars(stars: float) -> void` (0.0–3.0 across `Star1/Star2/Star3` `TextureProgressBar`s), `func animate_to(stars: float) -> void`.
  - `StatCheck` (`extends Control`): `const NEXT_SCENE_WIN`, `const NEXT_SCENE_LOSE`, `@export var slide_seconds`, `@export var hold_seconds`, `@export var white_fade_seconds`, `func _run_check() -> void` (coroutine), `static func star_share(total_stats: int) -> float`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_stat_check.gd`:

```gdscript
# ────────────────────────────────────────────────────────────── StatCheckCard

const _CARD_SCENE := "res://Scenes/EndGame/StatCheckCard.tscn"
const _SCENE := "res://Scenes/EndGame/StatCheck.tscn"
const _SCRIPT := "res://Scripts/EndGame/StatCheck.gd"
const _METER_SCRIPT := "res://Scripts/EndGame/StarMeter.gd"


func test_card_scene_has_the_mockup_parts() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	assert_true(card.get_node_or_null("Paper") is Panel, "the paper backing")
	assert_true(card.get_node_or_null("Paper/Header/BioPanel/Bio/Nama") is Label, "Nama")
	assert_true(card.get_node_or_null("Paper/Header/BioPanel/Bio/Profil") is Label, "Profil lines")
	assert_true(card.get_node_or_null("Paper/Header/Portrait") is TextureRect, "Portrait")
	for n in ["Akademis", "Seni", "Olahraga"]:
		assert_true(card.get_node_or_null("Paper/Rows/" + n) is StatCheckRow,
			"%s row is a StatCheckRow" % n)


func test_card_bind_fills_name_profil_portrait_and_arms_three_rows() -> void:
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var s := StudentData.new()
	s.student_name = "Citra"
	s.profil = "Agama: Katolik\nJenis Kelamin: Perempuan"
	s.akademis = 70.0
	s.target_akademis1 = 60.0
	s.seni_budaya = 30.0
	s.target_akademis2 = 60.0
	s.olahraga = 60.0
	s.target_akademis3 = 60.0
	card.bind(s)
	assert_eq(card.get_node("Paper/Header/BioPanel/Bio/Nama").text, "Citra", "name")
	assert_true(card.get_node("Paper/Header/BioPanel/Bio/Profil").text.contains("Jenis Kelamin"),
		"profil lines are shown verbatim")
	var rows: Array = card.rows()
	assert_eq(rows.size(), 3, "three rows, akademis/seni/olahraga")
	assert_true(is_equal_approx(rows[0].target_ratio, 100.0), "akademis 70/60 caps at 100")
	assert_true(is_equal_approx(rows[1].target_ratio, 50.0), "seni 30/60 is half")
	assert_true(is_equal_approx(rows[2].target_ratio, 100.0), "olahraga 60/60 is full")
	Engine.get_main_loop().root.remove_child(card)


func test_card_rows_carry_the_right_categories_and_icons() -> void:
	# rows() reads @onready vars, so the card must be in the tree first.
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var rows: Array = card.rows()
	assert_eq(rows[0].category, "Akademis", "row 0 is Akademis")
	assert_eq(rows[1].category, "SeniBudaya", "row 1 is SeniBudaya")
	assert_eq(rows[2].category, "Olahraga", "row 2 is Olahraga")
	for r in rows:
		assert_true(r.icon != null, "every row has an icon texture")
	Engine.get_main_loop().root.remove_child(card)


# ───────────────────────────────────────────────────────────────── StarMeter

func test_star_meter_maps_a_float_onto_three_star_bars() -> void:
	var screen = load(_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(screen)
	track(screen)
	var meter = screen.get_node("MarginContainer/Column/StarMeter")
	assert_true(meter is StarMeter, "StarMeter script")
	meter.set_stars(1.75)
	assert_true(is_equal_approx(meter.get_node("Star1").value, 100.0), "star 1 full")
	assert_true(is_equal_approx(meter.get_node("Star2").value, 75.0), "star 2 three-quarters")
	assert_true(is_equal_approx(meter.get_node("Star3").value, 0.0), "star 3 empty")
	meter.set_stars(3.0)
	assert_true(is_equal_approx(meter.get_node("Star3").value, 100.0), "3.0 fills the last star")
	meter.set_stars(0.0)
	assert_true(is_equal_approx(meter.get_node("Star1").value, 0.0), "0.0 empties the first")
	Engine.get_main_loop().root.remove_child(screen)


func test_star_meter_bars_use_the_placeholder_star() -> void:
	var screen = load(_SCENE).instantiate()
	track(screen)
	for n in ["Star1", "Star2", "Star3"]:
		var bar = screen.get_node("MarginContainer/Column/StarMeter/" + n)
		assert_true(bar is TextureProgressBar, "%s is a TextureProgressBar" % n)
		assert_true(String(bar.texture_progress.resource_path).ends_with("icon_star.svg"),
			"%s fills with icon_star.svg" % n)
		assert_eq(bar.fill_mode, TextureProgressBar.FILL_LEFT_TO_RIGHT,
			"%s fills left to right" % n)


# ───────────────────────────────────────────────────────────────── StatCheck

func test_scene_loads_with_its_chrome() -> void:
	var screen = load(_SCENE).instantiate()
	track(screen)
	assert_true(screen.get_node_or_null("Backdrop") is TextureRect, "Backdrop")
	assert_true(screen.get_node_or_null("Scrim") is Panel, "Scrim")
	assert_true(screen.get_node_or_null("MarginContainer/Column/CardSlot") is Control,
		"CardSlot, where each student's card is instanced")
	assert_true(screen.get_node_or_null("MarginContainer/Column/StarMeter") is StarMeter,
		"StarMeter")
	var white = screen.get_node_or_null("WhiteFade")
	assert_true(white is ColorRect, "the white fade overlay")
	assert_true(is_equal_approx(white.color.a, 1.0) and white.modulate.a == 0.0,
		"WhiteFade is opaque white, fully transparent via modulate until the end")


func test_star_share_is_one_over_total_stats_scaled_to_three() -> void:
	assert_true(is_equal_approx(StatCheck.star_share(12), 0.25), "4 students: 0.25 per stat")
	assert_true(is_equal_approx(StatCheck.star_share(6), 0.5), "2 students: 0.5 per stat")
	assert_true(is_equal_approx(StatCheck.star_share(0), 0.0), "no stats: nothing to share")


func test_the_sequence_slides_fills_in_order_and_awaits_each_beat() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _run_check() -> void:"), "the sequence coroutine")
	var slide_at := src.find("await _slide_in(card)")
	var fill_at := src.find("await row.fill()")
	var slide_out_at := src.find("await _slide_out(card)")
	assert_true(slide_at != -1 and fill_at != -1 and slide_out_at != -1,
		"slide in, fill, slide out are all awaited")
	assert_true(slide_at < fill_at and fill_at < slide_out_at,
		"a card slides in, its rows fill, then it slides out -- in that order")
	assert_true(src.contains("for row in card.rows():"),
		"rows fill in card order: akademis, seni budaya, olahraga")


func test_every_cleared_stat_adds_one_share_to_the_meter() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("_stars += star_share(_total_stats)"),
		"a cleared stat adds exactly one share")
	assert_true(src.contains("star_meter.animate_to(_stars)"),
		"the meter animates to the running total after each clear")
	assert_true(src.contains("if row.cleared:"),
		"only a cleared row moves the meter -- a partial fill adds nothing")


func test_it_ends_on_a_white_fade_then_hands_off_by_verdict() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("tween_property(white_fade, \"modulate:a\", 1.0, white_fade_seconds)"),
		"the white overlay fades in over white_fade_seconds")
	assert_true(src.contains("GameState.run_failed = not GameState.check_semester_passed()"),
		"the verdict is written to GameState before leaving")
	assert_true(src.contains("NEXT_SCENE_WIN if not GameState.run_failed else NEXT_SCENE_LOSE"),
		"win and lose have separate destinations")
	assert_true(src.contains("get_tree().change_scene_to_file("),
		"the hand-off bypasses Transition, whose cover is brand blue and would flash over the white")
	assert_false(src.contains("Transition.change_scene"),
		"no Transition wipe on the way out")


func test_it_keeps_the_exam_bgm_and_never_reads_the_cutscene_flag() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("play_bgm(&\"exam_notice\")"),
		"continuity with TesNotice/ExamProgress; result BGM belongs to Plan B's screens")
	assert_false(src.contains("is_exam_intro_cutscene"), "the flag is gone")


func test_interim_hand_off_targets_run_result_until_plan_b() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("const NEXT_SCENE_WIN := \"res://Scenes/EndGame/RunResult.tscn\""),
		"Plan B repoints this to WinScreen")
	assert_true(src.contains("const NEXT_SCENE_LOSE := \"res://Scenes/EndGame/RunResult.tscn\""),
		"Plan B repoints this to LoseScreen")
	assert_true(ResourceLoader.exists("res://Scenes/EndGame/RunResult.tscn"),
		"the interim destination exists")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="stat_check")`
Expected: FAIL — the suite fails to load (`Identifier "StarMeter"`/`"StatCheck"` not declared).

- [ ] **Step 3: Write `StatCheckCard.gd`**

```gdscript
@tool
class_name StatCheckCard
extends Control

## One student's page in the stat check -- the mockup_statcheck card: a
## purple bio panel (name, profil lines), the portrait, and three
## StatCheckRows. Instanced from StatCheckCard.tscn once per student by
## StatCheck, which is a reviewed per-call-dynamic exception to the
## no-runtime-construction rule (tests/test_viewport_editability.gd ALLOWED).
##
## The mockup also shows "Tanggal Lahir"; StudentData carries no birthday,
## so the card shows Nama and whatever lines `profil` already holds
## ("Agama: …" / "Jenis Kelamin: …") and nothing invented.

@onready var nama: Label = $Paper/Header/BioPanel/Bio/Nama
@onready var profil: Label = $Paper/Header/BioPanel/Bio/Profil
@onready var portrait: TextureRect = $Paper/Header/Portrait
@onready var row_akademis: StatCheckRow = $Paper/Rows/Akademis
@onready var row_seni: StatCheckRow = $Paper/Rows/Seni
@onready var row_olahraga: StatCheckRow = $Paper/Rows/Olahraga


## Fill the card from a StudentData and arm its three rows. Nothing
## animates here -- StatCheck plays each row's fill() in turn.
func bind(student: StudentData) -> void:
	nama.text = student.student_name
	profil.text = student.profil
	portrait.texture = student.avatar_texture
	row_akademis.set_result(student.akademis, student.target_akademis1)
	row_seni.set_result(student.seni_budaya, student.target_akademis2)
	row_olahraga.set_result(student.olahraga, student.target_akademis3)


## The three rows in the order the check plays them: akademis, seni
## budaya, olahraga -- the brief's order.
func rows() -> Array:
	return [row_akademis, row_seni, row_olahraga]
```

- [ ] **Step 4: Write `StarMeter.gd`**

```gdscript
@tool
class_name StarMeter
extends HBoxContainer

## The run's 3-star meter: three TextureProgressBars wearing icon_star.svg,
## filled left to right so a value of 1.75 reads as one full star, one
## three-quarter star, one empty. Continuous by design -- every cleared
## stat adds one equal share, and StatCheck animates the meter to the
## running total after each one.

## Seconds a meter step takes. Short: it follows a bar that already popped.
@export var step_seconds: float = 0.35

@onready var _stars: Array[TextureProgressBar] = [$Star1, $Star2, $Star3]


## Render `stars` (0.0-3.0) instantly. Star i shows clamp(stars - i, 0, 1).
func set_stars(stars: float) -> void:
	for i in range(_stars.size()):
		_stars[i].value = clampf(stars - float(i), 0.0, 1.0) * 100.0


## Tween to `stars`. Each star bar is tweened separately so a value that
## crosses a star boundary fills the first star fully before the next
## starts -- the meter reads as stars lighting one at a time.
func animate_to(stars: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for i in range(_stars.size()):
		var target := clampf(stars - float(i), 0.0, 1.0) * 100.0
		tw.tween_property(_stars[i], "value", target, step_seconds)
```

- [ ] **Step 5: Write `StatCheck.gd`**

The `class_name` is required: the suite calls `StatCheck.star_share()` statically, which does not resolve without it.

```gdscript
@tool
class_name StatCheck
extends Control

## The automated stat check (Plan A, 2026-09-04): one card per student
## slides in from the right, its three bars fill in turn -- akademis, seni
## budaya, olahraga -- a full bar pops, every cleared stat lights one share
## of the 3-star meter, the card slides out, the next slides in, and when
## the roster is done the screen fades to white and hands off by verdict.
## Replaces both the exam-intro cutscene beat and the SemesterEnd carousel.
##
## Deliberately NOT tap-driven: the check is a reveal the player watches.
##
## @tool so the MCP test suite can instantiate the scene inside the
## editor; the sequence itself sits behind Engine.is_editor_hint() and is
## a chain of coroutines -- tests assert on state and source, never by
## playing it.

## Where the white fade lands. Plan B repoints both at its win/lose
## screens; until then the report follows straight on.
const NEXT_SCENE_WIN := "res://Scenes/EndGame/RunResult.tscn"
const NEXT_SCENE_LOSE := "res://Scenes/EndGame/RunResult.tscn"

## The card template, instanced once per student into CardSlot. Reviewed
## per-call-dynamic exception (tests/test_viewport_editability.gd ALLOWED).
const CARD_SCENE := preload("res://Scenes/EndGame/StatCheckCard.tscn")

@export_group("Pacing")
## Seconds a card takes to slide in from the right edge (and out to the left).
@export var slide_seconds: float = 0.45
## Pause after a card lands before its first bar starts, and after its
## last bar before it leaves -- the beat that lets a pop register.
@export var hold_seconds: float = 0.4
## Seconds the white overlay takes to reach full.
@export var white_fade_seconds: float = 0.8

@onready var card_slot: Control = $MarginContainer/Column/CardSlot
@onready var star_meter: StarMeter = $MarginContainer/Column/StarMeter
@onready var white_fade: ColorRect = $WhiteFade

var _stars: float = 0.0
var _total_stats: int = 0
var _exiting: bool = false


func _ready() -> void:
	white_fade.modulate.a = 0.0
	star_meter.set_stars(0.0)
	if Engine.is_editor_hint():
		return
	AudioDirector.play_bgm(&"exam_notice")
	_run_check()


## One star-share per stat on the roster: Balance.STARS_TOTAL split evenly
## across every student's three targets. Zero when there is nothing to
## share, so an empty roster never divides by zero.
static func star_share(total_stats: int) -> float:
	if total_stats <= 0:
		return 0.0
	return Balance.STARS_TOTAL / float(total_stats)


## The whole sequence. A coroutine -- never call from a test.
func _run_check() -> void:
	var students: Array[StudentData] = GameState.convert_to_student_data_array()
	_total_stats = students.size() * 3
	_stars = 0.0

	for student in students:
		var card: StatCheckCard = CARD_SCENE.instantiate()
		card_slot.add_child(card)
		card.bind(student)
		await _slide_in(card)
		await get_tree().create_timer(hold_seconds).timeout

		for row in card.rows():
			await row.fill()
			if row.cleared:
				_stars += star_share(_total_stats)
				star_meter.animate_to(_stars)
				AudioDirector.play_sfx(&"tally")

		await get_tree().create_timer(hold_seconds).timeout
		await _slide_out(card)
		card.queue_free()

	await _fade_to_white()
	_hand_off()


## From just past the right edge to its resting spot, with the entry
## overshoot the rest of the game's pop-ins use.
func _slide_in(card: Control) -> void:
	var rest := card.position
	card.position.x = get_viewport_rect().size.x
	AudioDirector.play_sfx(&"swipe")
	var tw := create_tween()
	tw.tween_property(card, "position:x", rest.x, slide_seconds) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tw.finished


## Out to the left, easing in, so the next card's entrance reads as a
## continuation of the same pan.
func _slide_out(card: Control) -> void:
	var tw := create_tween()
	tw.tween_property(card, "position:x", -card.size.x, slide_seconds) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished


func _fade_to_white() -> void:
	var tw := create_tween()
	tw.tween_property(white_fade, "modulate:a", 1.0, white_fade_seconds) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## The verdict is decided here, once, and written to GameState for every
## screen after this. The Transition autoload's wipe is deliberately not
## used here: its cover is brand blue and would flash over the white. The
## next screen starts under its own white overlay and fades it out (Plan B).
##
## (That wording avoids the literal call spelling on purpose -- the test
## for this function greps the whole file for it, comments included.)
func _hand_off() -> void:
	if _exiting:
		return
	_exiting = true
	GameState.run_failed = not GameState.check_semester_passed()
	var next := NEXT_SCENE_WIN if not GameState.run_failed else NEXT_SCENE_LOSE
	get_tree().change_scene_to_file(next)
```

- [ ] **Step 6: Register the card instancing as a reviewed exception**

`tests/test_viewport_editability.gd`'s `ALLOWED` (line 99) maps a script path to the number of runtime-built visual nodes the scanner may count there. `.instantiate()` of an authored scene is not runtime construction and scans as 0 — `RunResult.gd` is registered at `0` (line 128) purely to document its per-call-dynamic exception. Register the two new instancing sites the same way, directly after the `RunResult.gd` entry:

```gdscript
	# StatCheck instances one StatCheckCard per student into CardSlot, and
	# StatCheckRow instances the authored RewardBurst on a full bar -- both
	# per-call-dynamic content (roster size / which bars clear), the same
	# shape as RunResult's rows. Every visual lives in a .tscn; scans as 0.
	"res://Scripts/EndGame/StatCheck.gd": 0,
	"res://Scripts/EndGame/StatCheckRow.gd": 0,
```

- [ ] **Step 7: Controller — build `StatCheckCard.tscn` in the editor**

Geometry follows the mockup on a 1080-wide design space: a 760×1000 paper card, a purple bio panel top-left, the portrait top-right, three rows below. `Paper` and `BioPanel` are plain `Panel`s (the `Card` and `SunkenPanel` variations are registered on `Panel`), so children are free-positioned; the two text lines sit in a `VBoxContainer` because a `Panel` does no layout. The node names and nesting below are the test contract (`Paper/Header/BioPanel/Bio/Nama`, `Paper/Rows/Akademis`, …).

```
scene_manage(op="create", params={"path": "res://Scenes/EndGame/StatCheckCard.tscn", "root_type": "Control", "root_name": "StatCheckCard"})
script_attach("/StatCheckCard", "res://Scripts/EndGame/StatCheckCard.gd")

/StatCheckCard                        Control  custom_minimum_size {760,1000}, size {760,1000}
  Paper                               Panel    theme_type_variation "Card"; anchors 0,0,1,1; offsets 0,0,0,0
    Header                            HBoxContainer  position {32,32}, size {696,300}
      BioPanel                        Panel    theme_type_variation "SunkenPanel"; custom_minimum_size {420,300}
        Bio                           VBoxContainer  anchors 0,0,1,1; offsets 24,24,-24,-24
          Nama                        Label    theme_type_variation "TitleLabel"; text "Nama"
          Profil                      Label    theme_type_variation "CaptionLabel"; text "Jenis Kelamin: -"; autowrap_mode 3
      Portrait                        TextureRect  custom_minimum_size {240,300}; expand_mode 1; stretch_mode 5;
                                      texture "res://Assets/Images/UI/Placeholders/icon_akademis.svg"  (placeholder until bind)
    Rows                              VBoxContainer  position {32,380}, size {696,360}
      Akademis                        node_create(scene_path="res://Scenes/EndGame/StatCheckRow.tscn"); category "Akademis";  icon ".../icon_akademis.svg"
      Seni                            node_create(scene_path=StatCheckRow.tscn); category "SeniBudaya"; icon ".../icon_seni.svg"
      Olahraga                        node_create(scene_path=StatCheckRow.tscn); category "Olahraga";  icon ".../icon_olahraga.svg"

scene_save()
```

`node_create` appends last, so create in the order listed. The three row instances are created with `scene_path`, then `node_set_property` their exported `category` and `icon`. Leave every container's `separation` at the theme default (`space_sm`/`space_md`) — no constant overrides.

- [ ] **Step 8: Controller — build `StatCheck.tscn` in the editor**

```
scene_manage(op="create", params={"path": "res://Scenes/EndGame/StatCheck.tscn", "root_type": "Control", "root_name": "StatCheck"})
script_attach("/StatCheck", "res://Scripts/EndGame/StatCheck.gd")
batch_execute (numbers unquoted; anchors set as four values + four offsets = 0 for full-rect):
  set_property /StatCheck anchor_right 1 ; anchor_bottom 1
  create_node TextureRect "Backdrop" parent /StatCheck
    texture "res://Assets/Images/UI/blur_background.png" ; size {1080,1920} ; expand_mode 1 ; stretch_mode 6
  create_node Panel "Scrim" parent /StatCheck
    theme_type_variation "Scrim" ; size {1080,1920}
  create_node MarginContainer "MarginContainer" parent /StatCheck   (full-rect anchors)
  create_node VBoxContainer "Column" parent /StatCheck/MarginContainer
    alignment 1                                    # center; separation stays at the theme default
  create_node Control "CardSlot" parent /StatCheck/MarginContainer/Column
    custom_minimum_size {760, 1000} ; size_flags_horizontal 4 (shrink center)
  create_node HBoxContainer "StarMeter" parent /StatCheck/MarginContainer/Column
    script "res://Scripts/EndGame/StarMeter.gd" ; alignment 1
    for n in Star1, Star2, Star3:
      create_node TextureProgressBar n parent .../StarMeter
        texture_progress "res://Assets/Images/UI/Placeholders/icon_star.svg"
        texture_under    "res://Assets/Images/UI/Placeholders/icon_star.svg"
        tint_under {r:0.3,g:0.3,b:0.35,a:1}        # dim, unlit star
        fill_mode 0                                  # FILL_LEFT_TO_RIGHT
        min_value 0 ; max_value 100 ; value 0
        custom_minimum_size {180, 180}
  create_node ColorRect "WhiteFade" parent /StatCheck            # LAST child so it draws over everything
    color {r:1,g:1,b:1,a:1} ; modulate {r:1,g:1,b:1,a:0} ; mouse_filter 2 ; full-rect anchors
scene_save()
```

`tint_under` is a `Color` property on `TextureProgressBar`, not a theme override, so it is allowed.

**Star sizing — do this, or the meter renders wrong.** `TextureProgressBar` draws its textures at their native pixel size: `custom_minimum_size` reserves the 180×180 slot but does **not** scale the art, so the 100×100 SVG would sit top-left inside the box instead of filling it. Fix it at import time, not in the scene. After the first scan imports `icon_star.svg`, open `Assets/Images/UI/Placeholders/icon_star.svg.import`, set `svg/scale=1.8` under `[params]`, then `filesystem_manage(op="reimport", params={"paths": ["res://Assets/Images/UI/Placeholders/icon_star.svg"]})` so it rasterizes at 180×180. Step 10's screenshot is the confirmation.

- [ ] **Step 9: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` (three new `class_name`s; no-op `script_patch` any that stay unknown) then `test_run(suite="stat_check")`
Expected: PASS, **18 tests** (6 from Task 3 + 12 new — count Step 1's functions, there are twelve). Also `test_run(suite="viewport_editability")` — still green with the new ALLOWED entries.

- [ ] **Step 10: Live check, once (controller)**

`project_run(mode="main")` → open the debug overlay (F1) → Scenes → **Gladi Resik: Campur** (the rehearsal tool from the previous plan; it enters at TesNotice with a 3/2/1/0 ladder over four students).

With `star_share(12) = 0.25`, the meter's running total after each card is: Marcel 3 cleared → **0.75**; Doni 2 → **1.25**; Andi 1 → **1.50**; Citra 0 → **1.50**. Final: 1.50 stars, below the 2.0 threshold, so `run_failed = true` and the hand-off takes `NEXT_SCENE_LOSE`.

Expected: TesNotice → ExamProgress with the backdrop drifting over 4 s → StatCheck playing those four cards with the pops and meter steps above → white fade → RunResult (Plan A's interim destination for both verdicts). Then press **Pulihkan Run Sebelum Gladi Resik**. One `editor_screenshot(source="game")` mid-check to judge the card against mockup_statcheck, and one of the meter to confirm the star art fills its slot (see the sizing note in Step 8).

- [ ] **Step 11: Commit**

```bash
git add Scripts/EndGame/StatCheckCard.gd Scripts/EndGame/StatCheckCard.gd.uid Scripts/EndGame/StarMeter.gd Scripts/EndGame/StarMeter.gd.uid Scripts/EndGame/StatCheck.gd Scripts/EndGame/StatCheck.gd.uid Scenes/EndGame/StatCheckCard.tscn Scenes/EndGame/StatCheck.tscn tests/test_stat_check.gd tests/test_viewport_editability.gd
git commit -m "feat(endgame): add the StatCheck sequence with a 3-star meter

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Delete the exam-intro cutscene beat

**Files:**
- Modify: `Scripts/CutScene/cut_scene.gd` (:29, :72, :79-87 `_ready` branch, :89-126 `_setup_exam_cutscene` + its doc block, :268 comment, :311-312, :345 guard, :403-405, and `_on_lanjut_exam_pressed`) — ranges verified against the file 2026-09-04
- Controller: `Scenes/CutScene/cut_scene.tscn` — delete node `BtnLanjutExam`
- Modify: `Scripts/GameState.gd:63` and `:85` (remove `is_exam_intro_cutscene`)
- Modify: `Scripts/Audio/AudioDirector.gd:98-99` and `:450` (remove the `exam_cutscene` id)
- Modify: `Scripts/Debug/EndGameRehearsal.gd:115` (drop the key), `:219-222` (drop the write + fix the comment), `:5` and `:41` header comments
- Test: `tests/test_cutscene.gd` (delete the exam-branch tests at :250-370 and fix comments), `tests/test_audio_director.gd:538`, `tests/test_end_game_rehearsal.gd:161-181, :205-214` (+ append the inverse ratchet), **`tests/test_economy_state.gd:238-239`** (a live read of the deleted field — the suite fails to load without this), `tests/test_tes_notice.gd:77` (keep — it asserts absence)

**Interfaces:**
- Consumes: nothing new.
- Produces: `cut_scene.gd` with exactly one branch (the intro/level-select flow); `GameState` without `is_exam_intro_cutscene`; `EndGameRehearsal.SNAPSHOT_KEYS` without it. **Note:** the existing completeness ratchet does NOT catch a stale key — it only iterates GameState's fields looking for ones missing from `SNAPSHOT_KEYS`, never the reverse. Step 1 adds the inverse ratchet that does.

- [ ] **Step 1: Write the failing tests**

In `tests/test_cutscene.gd`, delete these seven functions entirely (they are at lines 270–370): `test_skip_and_hint_are_hidden_during_the_exam_cutscene`, `test_the_exam_branch_exists_and_the_game_over_branch_is_gone`, `test_the_exam_branch_has_four_dialogues`, `test_the_exam_branch_exits_to_the_stat_check` (it asserts `SemesterEnd.tscn` at :344), `test_the_exam_branch_plays_its_own_bgm`, `test_btn_lanjut_exam_exists_and_is_touch_sized`, `test_input_bails_while_btn_lanjut_exam_is_visible`. Fix the two doc comments at :252-254 and :284 that mention the exam beat. Then append:

```gdscript
## Plan A (2026-09-04) deleted the exam-intro cutscene beat: ExamProgress
## now hands off straight to StatCheck. CutScene is back to a single
## responsibility -- the game-start intro and its level-select modal.
func test_the_exam_branch_is_gone() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for gone in ["is_exam_intro_cutscene", "_setup_exam_cutscene", "btn_lanjut_exam",
			"BtnLanjutExam", "exam_cutscene", "SemesterEnd.tscn", "StatCheck.tscn"]:
		assert_false(src.contains(gone), "cut_scene.gd must not mention " + gone)
	assert_true(_scene.get_node_or_null("BtnLanjutExam") == null,
		"the BtnLanjutExam node is deleted from cut_scene.tscn")


func test_next_scene_path_has_a_single_destination_again() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_next_scene_path")
	assert_true(body.contains("res://Scenes/StudentCard/student_card.tscn"),
		"the intro still lands on roster approval")
	assert_false(body.contains("if "), "no branch left: one destination")
```

In `tests/test_audio_director.gd:538`, change the loop list `[&"exam_notice", &"exam_cutscene", &"run_result"]` to `[&"exam_notice", &"run_result"]`.

In `tests/test_end_game_rehearsal.gd`: in `test_restore_puts_back_run_stats_and_the_end_game_flags` (around :158-181) remove every line touching `is_exam_intro_cutscene` (the `original_exam` save, the two writes, the assert, the restore); in `test_arm_lands_on_the_final_week_with_a_clean_sequence_state` (around :205-214) remove the `GameState.is_exam_intro_cutscene = true` line and the assert on it.

Also append this inverse ratchet to the same suite. The existing completeness ratchet only catches a GameState field **missing** from `SNAPSHOT_KEYS`; it cannot catch the reverse — a key naming a field that no longer exists, where `GameState.get()` silently returns null and `set()` no-ops. This task deletes exactly such a field, so the guard is earned:

```gdscript
## The inverse of the completeness ratchet above: every SNAPSHOT_KEYS entry
## must still name a real GameState field. A key left behind after a field
## is deleted fails silently -- get() returns null, set() no-ops -- so the
## snapshot would quietly stop round-tripping. Plan A deleted
## is_exam_intro_cutscene, which is exactly this shape.
func test_every_snapshot_key_names_a_real_game_state_property() -> void:
	var declared := {}
	for prop in GameState.get_script().get_script_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			declared[prop.name] = true
	var stale: Array[String] = []
	for key in EndGameRehearsal.SNAPSHOT_KEYS:
		if not declared.has(key):
			stale.append(String(key))
	assert_eq(stale.size(), 0,
		"SNAPSHOT_KEYS names fields GameState no longer declares: " + ", ".join(stale))
```

In `tests/test_economy_state.gd`, in `test_set_grade_resets_the_run_stats()` (:238-239), delete the two lines

```gdscript
	assert_false(GameState.is_exam_intro_cutscene,
		"the exam-cutscene flag clears with the grade")
```

keeping the `run_failed` assert that follows. This is a **live property read**, not a source scan — left in place it is an unresolved-member error and the whole suite fails to load the moment the field is deleted.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `filesystem_manage(op="scan")` then `test_run(suite="cutscene")`
Expected: FAIL — `test_the_exam_branch_is_gone` fails on `is_exam_intro_cutscene` (still present) and on the `BtnLanjutExam` node (still in the scene); `test_next_scene_path_has_a_single_destination_again` fails on the `if `.

- [ ] **Step 3: Write the implementation**

`Scripts/CutScene/cut_scene.gd`: **the line ranges below were verified against the real file on 2026-09-04 — do not trust an approximate range, the function bodies are longer than they look.**
- Delete line 29 (`@onready var btn_lanjut_exam`) and line 72 (`btn_lanjut_exam.pressed.connect(...)`).
- Replace the `_ready()` branch, **lines 79–87** (the branch's last line is `show_current()` at 87 — stopping at 86 leaves a duplicated, mis-indented `show_current()` and a parse error), so it reads only:

```gdscript
	# Show level selection BEFORE playing intro cutscene if unlocked or in debug mode
	if GameState.is_game_beaten or GameState.debug_level_select_enabled:
		show_level_select_modal()
	else:
		GameState.set_grade(7)
		show_current()
```
- Delete the whole `_setup_exam_cutscene()` function and its `##` doc block, **lines 89–126** (doc block starts at 89; the function runs through `show_current()` at 125 because it carries a four-entry `cg_data = [...]` literal; 126 is the trailing blank line before `_setup_top_bar_buttons()` at 127).
- Fix the `_on_skip_pressed` doc comment (line ~268) to: `## This button only exists during the intro, so there is nothing to reconcile here.`
- In `show_current()`, replace the two-branch BGM (lines 311–314) with the single line `AudioDirector.play_bgm(&"introcutscene")`.
- In `_input()`, delete the four-line comment and the `if btn_lanjut_exam.visible: return` guard (line ~345).
- Delete `_on_lanjut_exam_pressed()`.
- Replace `_next_scene_path()` (lines ~399–406) with:

```gdscript
## The intro lands on the roster approval screen, as before. (The exam
## branch that once lived here was deleted with the exam-intro beat.)
func _next_scene_path() -> String:
	return "res://Scenes/StudentCard/student_card.tscn"
```

`Scripts/GameState.gd`: delete the `## True while the exam cutscene branch...` comment and `var is_exam_intro_cutscene: bool = false` (lines 61–63), and the `is_exam_intro_cutscene = false` line inside `set_grade()` (line 85).

`Scripts/Audio/AudioDirector.gd`: delete the `## \`play_bgm(&"exam_cutscene")\`` doc line and the `@export var bgm_exam_cutscene` line (98–99), and the `&"exam_cutscene": return bgm_exam_cutscene` match arm (450).

`Scripts/Debug/EndGameRehearsal.gd`:
- Line 115: remove `"is_exam_intro_cutscene",` from `SNAPSHOT_KEYS`.
- Lines ~219–222: delete `GameState.is_exam_intro_cutscene = false` and rewrite the comment to: `# run_failed belongs to the sequence itself: StatCheck writes the verdict.`
- Header lines 5–6: rewrite the pair together (editing line 5 alone duplicates "RunResult can be") so they read:
  ```gdscript
  ## roster so TesNotice -> ExamProgress -> StatCheck -> RunResult can be
  ## rehearsed in one click instead of played for six to sixteen weeks.
  ```
- Line 41: replace "the SemesterEnd carousel shows 3-, 2-, 1- and 0-star detail popups" with "the StatCheck meter lights 3, 2, 1 and 0 shares in turn".
- Lines 174 and 211 also still say "SemesterEnd" — line 174's "teleporting into SemesterEnd and skipping the beats before it" becomes "teleporting into StatCheck and skipping the beats before it"; line 211's mention sits in the `arm()` comment rewritten above, so fold it into that same edit.

- [ ] **Step 4: Controller — delete the button node**

```
scene_open("res://Scenes/CutScene/cut_scene.tscn")
node_manage(op="delete", params={"path": "/CutScene/BtnLanjutExam"})
scene_save()
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="cutscene")`, `test_run(suite="audio_director")`, `test_run(suite="end_game_rehearsal")`, `test_run(suite="economy_state")`, `test_run(suite="tes_notice")`.
Expected: all PASS. The new inverse ratchet is the proof the key removal was complete — had `is_exam_intro_cutscene` stayed in `SNAPSHOT_KEYS` after the field was deleted, it would name a field GameState no longer declares and go red.

- [ ] **Step 6: Commit**

```bash
git add Scripts/CutScene/cut_scene.gd Scenes/CutScene/cut_scene.tscn Scripts/GameState.gd Scripts/Audio/AudioDirector.gd Scripts/Debug/EndGameRehearsal.gd tests/test_cutscene.gd tests/test_audio_director.gd tests/test_end_game_rehearsal.gd tests/test_economy_state.gd
git commit -m "refactor(cutscene): delete the exam-intro beat, StatCheck replaced it

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Delete SemesterEnd and ResultStatRow

**Files:**
- Delete: `Scenes/EndGame/SemesterEnd.tscn`, `Scripts/EndGame/SemesterEnd.gd` (+ `.uid`), `Scenes/EndGame/ResultStatRow.tscn`, `Scripts/EndGame/ResultStatRow.gd` (+ `.uid`), `tests/test_semester_end.gd` (+ `.uid`)
- Modify: `tests/test_audio_coverage.gd:173-178` and `:357-363`, `tests/test_school_day.gd:14,:106-111` (comments), `Scripts/UI/StatBar.gd:7,:53` (comments), `Scripts/Design/ThemeFactory.gd:297-299,:379-395` (comments; the `PageDotLabel`/`ResultHeroLabel`/`ResultBodyLabel` variations stay baked — removing a variation needs a theme rebake, which is out of scope; note them as unused), `Scripts/EndGame/RunResult.gd:6,:13,:170,:214,:225` (comments), `Scripts/Audio/AudioDirector.gd:57` (comment), `tests/test_theme_factory.gd:174` (comment), `tests/test_debug_manager.gd:114-115` (comment only — the assertion still holds, SemesterEnd.tscn is gone either way)
- Test: `tests/test_project_hygiene.gd` (append one ratchet)

**Interfaces:** none produced; consumes nothing.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_project_hygiene.gd`:

```gdscript
## Plan A (2026-09-04) replaced the SemesterEnd carousel with StatCheck.
## Pinned so the scene and its row template cannot drift back in.
func test_semester_end_and_its_row_template_are_gone() -> void:
	for path in ["res://Scenes/EndGame/SemesterEnd.tscn",
			"res://Scripts/EndGame/SemesterEnd.gd",
			"res://Scenes/EndGame/ResultStatRow.tscn",
			"res://Scripts/EndGame/ResultStatRow.gd"]:
		assert_false(ResourceLoader.exists(path), path + " must be deleted")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `filesystem_manage(op="scan")` then `test_run(suite="project_hygiene")`
Expected: FAIL on all four paths.

- [ ] **Step 3: Delete, then fix the references**

**Deletions must go through the editor** — a shell `rm` of a scene the editor has cached is resurrected on the next save (this bit `WinScreen.tscn` on 2026-09-04). The controller: `scene_open` each of the two scenes, then close it in the editor (open another scene, e.g. `main_menu.tscn`), then delete the files and sidecars with `rm`, then `filesystem_manage(op="scan")` and confirm with `ResourceLoader.exists()` via the test. If a file returns, use the editor's FileSystem dock delete.

```bash
rm -f Scenes/EndGame/SemesterEnd.tscn Scripts/EndGame/SemesterEnd.gd Scripts/EndGame/SemesterEnd.gd.uid \
      Scenes/EndGame/ResultStatRow.tscn Scripts/EndGame/ResultStatRow.gd Scripts/EndGame/ResultStatRow.gd.uid \
      tests/test_semester_end.gd tests/test_semester_end.gd.uid
```

`tests/test_audio_coverage.gd`: delete the **whole** `test_semester_end_has_sfx()` function — **lines 173–178**, header included. Deleting only its body (174–178) leaves a headerless `func` and the suite fails to load. Keep the surrounding two-blank-line spacing. Then replace the block at 357–363 with:

```gdscript
	# result_win / result_lose moved to Plan B's win/lose screens; until they
	# land, no shipped script plays them. StatCheck keeps exam_notice going.
	var stat_check_src := _source("res://Scripts/EndGame/StatCheck.gd")
	assert_true(stat_check_src.contains('play_bgm(&"exam_notice")'),
		"StatCheck.gd must keep the exam BGM running")
```

Comments — grep the repo for `SemesterEnd` and `ResultStatRow` after the deletions and fix every hit. The full list as of 2026-09-04: `tests/test_school_day.gd:14` "(SemesterEnd vs. Lobby)" → "(TesNotice vs. Lobby)" and `:106-111` (the assertion still holds — it asserts SchoolDay does *not* route to SemesterEnd — but its comment needs rewording); `Scripts/UI/StatBar.gd:7,:53` "SemesterEnd" → "StatCheck"; `Scripts/Design/ThemeFactory.gd:297-299,:379-395` prefix with `# (Unused since Plan A deleted SemesterEnd -- kept baked; removing a variation needs a theme rebake.)`; `Scripts/EndGame/RunResult.gd:6,:13,:170,:214` "SemesterEnd" → "StatCheck" where it describes the current flow (`:225`'s "SemesterEnd's old grade-7" stays — it is history); `Scripts/Audio/AudioDirector.gd:57` "(SemesterEnd, lobby, …)" → "(StatCheck, lobby, …)"; `tests/test_theme_factory.gd:174` "shared with AturJadwal, SemesterEnd and ResultCheckup" → "…, StatCheck and ResultCheckup"; `tests/test_debug_manager.gd:114-115` comment only (the assertion is about the deleted teleport and still passes).

Run the grep again after editing and confirm the only remaining hits are the two deliberate history references.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `filesystem_manage(op="scan")` then `test_run(suite="project_hygiene")`, `test_run(suite="audio_coverage")`, `test_run(suite="school_day")`, `test_run(suite="theme_factory")`, `test_run(suite="script_documentation")`.
Expected: all PASS; `semester_end` no longer appears in the suite list.

- [ ] **Step 5: Commit**

```bash
git add -u Scenes/EndGame/SemesterEnd.tscn Scripts/EndGame/SemesterEnd.gd Scripts/EndGame/SemesterEnd.gd.uid Scenes/EndGame/ResultStatRow.tscn Scripts/EndGame/ResultStatRow.gd Scripts/EndGame/ResultStatRow.gd.uid tests/test_semester_end.gd tests/test_semester_end.gd.uid
git add tests/test_project_hygiene.gd tests/test_audio_coverage.gd tests/test_school_day.gd Scripts/UI/StatBar.gd Scripts/Design/ThemeFactory.gd Scripts/EndGame/RunResult.gd
git commit -m "refactor(endgame): delete SemesterEnd and ResultStatRow, replaced by StatCheck

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

(`git add -u <paths>` stages deletions of tracked files by name — still no `-A`.)

---

### Task 7: Documentation and the full-suite gate

**Files:**
- Modify: `CLAUDE.md` — the "Current work" paragraph that begins "The 2026-09-04 end-game UI reskin replaced part of the flow…", and the rehearsal paragraph's flow line "(TesNotice → ExamProgress → CutScene → SemesterEnd → RunResult)".

- [ ] **Step 1: Update the docs**

Replace the reskin paragraph's first sentences so the flow reads: **TesNotice → ExamProgress → StatCheck → RunResult → MainMenu** (Plan B inserts WinScreen/LoseScreen before RunResult; Plan C redesigns RunResult). Add: "The 2026-09-04 Plan A replaced the exam-intro cutscene beat and the SemesterEnd carousel with `StatCheck` — an automated one-student-at-a-time reveal (card slides in, bars fill akademis → seni → olahraga, a full bar pops, every cleared stat lights `1/(roster×3)` of a 3-star `StarMeter`), ending in a white fade. The win rule is now `GameState.run_stars() >= Balance.STAR_WIN_THRESHOLD` (2.0 of 3.0), i.e. two-thirds of all targets cleared — no longer all-or-nothing. ExamProgress pans its backdrop 216 px during the fill (the node is authored 1296 wide for that)."

In the rehearsal paragraph, change the flow line to "(TesNotice → ExamProgress → StatCheck → RunResult)" and "so one pass of the SemesterEnd carousel shows both stamp kinds and every star rating" to "so one pass of StatCheck lights the meter 3, 2, 1 and 0 shares in turn (6 of 12 = 1.5 stars, a loss)".

- [ ] **Step 2: Run the full suite**

Run: `filesystem_manage(op="scan")`, `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, then `test_run()`.
Expected: **all passing, 55 suites** — `semester_end` gone, `stat_check` added.

Count, worked through with every pre-flight correction applied:
`796` baseline
`− 17` semester_end suite deleted
`− 7` exam-branch tests deleted from cutscene
`− 1` exam_progress test replaced
`− 1` `test_semester_end_has_sfx` deleted from audio_coverage (Task 6)
`+ 6` economy_state (Task 1)
`+ 3` exam_progress (Task 2)
`+ 18` stat_check (6 from Task 3 + 12 from Task 4)
`+ 2` cutscene (Task 5)
`+ 1` end_game_rehearsal inverse ratchet (Task 5)
`+ 1` project_hygiene (Task 6)
**= 801**

The plan's original figure of 800 came from omitting both the audio_coverage deletion and the stat_check miscount; those did not cancel once the inverse ratchet was added. Any other number is a regression from this plan.

- [ ] **Step 3: Commit**

`CLAUDE.md` may already carry uncommitted hunks from the 2026-09-04 reskin. If `git diff CLAUDE.md` shows more than this task's paragraph edits, the controller commits it with the revert-commit-reapply procedure; otherwise:

```bash
git add CLAUDE.md
git commit -m "docs(endgame): describe the StatCheck flow and the star win rule

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```
