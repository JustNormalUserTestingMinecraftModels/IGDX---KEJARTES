# Per-student lose rule — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A run is lost (letter D) when any student clears fewer than 2 of their 3 skill targets. The HUD shows that rule: AturJadwal's chip counts safe students, and StatCheck stamps a failing student "TIDAK LULUS".

**Architecture:** The verdict stays in one place, `GameState.check_semester_passed()`, which now asks whether every student is safe instead of comparing stars to 2.0. Everything downstream (StatCheck → `run_failed` → `RunGrade.letter()` → `RunResult.destination_for()`) already handles a failed run, so it is untouched. Two UI surfaces read the new rule: `ObjectiveHint` (pure static text and percent for AturJadwal's strip) and `StatCheckCard` (a stamp node authored in its `.tscn`).

**Tech Stack:** Godot 4.6, GDScript, the Godot AI MCP bridge (`test_run`, `script_patch`, `scene_open`, `node_*`, `batch_execute`, `scene_save`, `project_run`, `game_manage`, `editor_screenshot`).

**Spec:** `docs/superpowers/specs/2026-10-01-per-student-lose-rule-design.md`

## Global Constraints

- Tests run **only** inside the editor through MCP `test_run(suite=...)`. Suites are `@tool`, and **no test may `await`**.
- Edit `.gd` files through `script_patch`. A file written from outside the editor needs a no-op `script_patch` on it before `test_run`, or the editor serves the stale copy.
- **Never hand-edit a `.tscn` while the editor is attached.** Scene edits go `scene_open` → `node_create`/`node_set_property`/`node_manage`/`batch_execute` → `scene_save`.
- **Scene work before script work, inside each task.** `scene_save` writes every open script tab back to disk. Once you have patched any `.gd`, restart the editor before the next `scene_save` (a force-kill is safe once scenes are saved). After every `scene_save`, run `git diff HEAD -- '*.gd'` and revert any script you did not mean to change.
- `Balance.gd` belongs to a collaborator: **do not edit it**. Our new tunable is `GameState.MIN_TARGETS_PER_STUDENT`.
- No `theme_override_*` (layout constants excepted), and no visual built at runtime. The stamp is a node in the `.tscn`, and no `Label.new()` or `PanelContainer.new()` is added anywhere.
- Every script keeps its `##` file header and a `##` line on every `@export` (`tests/test_script_documentation.gd`).
- All player-facing text is Indonesian. The only new string is `TIDAK LULUS`.
- No emoji as icons.
- Commits: Conventional Commits with a scope, each ending with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The main checkout is shared. Work in a worktree on a fresh branch off `Textures` (`superpowers:using-git-worktrees`), named `feat/per-student-lose-rule`. This plan and its spec are **untracked** in the main checkout. Copy both into the worktree and commit them in Task 1.
- After any full `test_run`, check `git status`, and `git checkout --` `Assets/Theme/kejartes_theme.tres` and `Assets/Audio/default_bus_layout.tres` if the run rewrote them.
- Finish with the `ship-pr` skill.

## File map

| File | Change |
|---|---|
| `Scripts/GameState.gd` | `MIN_TARGETS_PER_STUDENT`, `SKILL_TARGET_PAIRS`, `targets_cleared_for()`, `student_is_safe()`, `safe_student_count()`. New body for `check_semester_passed()` |
| `tests/test_economy_state.gd` | Rule tests replace the 2.0-star tests |
| `Scripts/Debug/EndGameRehearsal.gd` | Grade B/C presets kept passable |
| `tests/test_end_game_rehearsal.gd` | Pins every passing preset as safe |
| `Scenes/AturJadwal/AturJadwal.tscn` | `StarChip`→`SafeChip`, `Stars`→`Count`, icon → `nav_students.svg` |
| `Scripts/AturJadwal/ObjectiveHint.gd` | `safe_text()`, `safe_percent()` replace the star functions |
| `Scripts/AturJadwal/AturJadwal.gd` | The strip reads the safe count |
| `tests/test_objective_hint.gd`, `tests/test_atur_jadwal.gd` | Updated pins |
| `Scenes/EndGame/StatCheckCard.tscn` | Hidden `FailStamp` + `StampLabel` |
| `Scripts/EndGame/StatCheckCard.gd` | `failed`, `cleared_count()`, `stamp_if_failed()` |
| `Scripts/EndGame/StatCheck.gd` | Calls `card.stamp_if_failed()` after the rows |
| `tests/test_stat_check.gd` | Stamp tests |
| `CLAUDE.md`, `docs/superpowers/CHANGELOG.md`, `Assets/Images/UI/Icons/README.md` | Docs |

---

### Task 1: The rule in GameState

**Files:**
- Modify: `Scripts/GameState.gd:685-726` (`run_stars`, `check_semester_passed`, `count_targets_cleared`)
- Test: `tests/test_economy_state.gd:322-355`

**Interfaces:**
- Produces:
  - `const MIN_TARGETS_PER_STUDENT := 2`
  - `const SKILL_TARGET_PAIRS := [["akademis","target_akademis"],["seni_budaya","target_seni_budaya"],["olahraga","target_olahraga"]]`
  - `static func targets_cleared_for(student: Dictionary) -> int`
  - `static func student_is_safe(student: Dictionary) -> bool`
  - `func safe_student_count() -> int`
  - `func check_semester_passed() -> bool` (same signature, new rule)

- [ ] **Step 0: Set up the branch**

Create the worktree and branch `feat/per-student-lose-rule` off `Textures`. Copy `docs/superpowers/specs/2026-10-01-per-student-lose-rule-design.md` and this plan from the main checkout into the same paths in the worktree. Open the worktree's project in the editor and open `Scenes/MainMenu/MainMenu.tscn`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_economy_state.gd`, add this helper directly under `_roster_with_cleared()` (line 273):

```gdscript
## A roster where student i clears exactly counts[i] of their three skill
## targets -- unlike _roster_with_cleared(), which fills students in order
## and so cannot say which student is short.
func _roster_with_counts(counts: Array) -> Array:
	var roster: Array = []
	for i in range(counts.size()):
		var s := {"id": i + 1, "name": "M%d" % (i + 1)}
		var k := 0
		for pair in GameState.SKILL_TARGET_PAIRS:
			s[pair[1]] = 60.0
			s[pair[0]] = 70.0 if k < int(counts[i]) else 40.0
			k += 1
		roster.append(s)
	return roster
```

Delete `test_semester_passes_at_two_stars_and_fails_below()` and `test_semester_pass_no_longer_requires_every_student_to_clear_everything()` (lines 322-341). Add these in their place:

```gdscript
func test_targets_cleared_for_counts_one_students_three_skills() -> void:
	var roster := _roster_with_counts([3, 2, 1, 0])
	assert_eq(GameState.targets_cleared_for(roster[0]), 3)
	assert_eq(GameState.targets_cleared_for(roster[1]), 2)
	assert_eq(GameState.targets_cleared_for(roster[2]), 1)
	assert_eq(GameState.targets_cleared_for(roster[3]), 0)
	assert_eq(GameState.targets_cleared_for({}), 0,
		"a student with no targets clears nothing, by target_cleared()'s zero rule")


func test_the_per_student_pass_line_is_two() -> void:
	assert_eq(GameState.MIN_TARGETS_PER_STUDENT, 2, "two of three, per student")
	var roster := _roster_with_counts([3, 2, 1])
	assert_true(GameState.student_is_safe(roster[0]), "3 of 3 is safe")
	assert_true(GameState.student_is_safe(roster[1]), "2 of 3 is safe")
	assert_false(GameState.student_is_safe(roster[2]), "1 of 3 is not")


func test_safe_student_count_counts_students_on_the_line() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_counts([3, 2, 1, 0])
	assert_eq(GameState.safe_student_count(), 2)
	GameState.approved_students = original


## The 2026-10-01 rule: one student under the line loses the run, however
## many stars the rest of the roster earned. 3+3+3+1 = 10 of 12 = 2.5 stars.
func test_one_student_under_two_targets_fails_the_run_at_two_and_a_half_stars() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_counts([3, 3, 3, 1])
	assert_true(GameState.run_stars() > 2.0, "the roster is past the old star line")
	assert_false(GameState.check_semester_passed(),
		"a single student on 1 of 3 still loses the run")
	GameState.approved_students = _roster_with_counts([3, 3, 3, 0])
	assert_false(GameState.check_semester_passed(), "nor does 0 of 3 pass")
	GameState.approved_students = original


func test_every_student_on_two_targets_passes() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_counts([2, 2, 2, 2])
	assert_true(GameState.check_semester_passed(), "2 of 3 each is a pass")
	GameState.approved_students = _roster_with_counts([3, 3, 3, 3])
	assert_true(GameState.check_semester_passed(), "a clean sweep passes")
	GameState.approved_students = original


func test_the_verdict_no_longer_reads_the_star_threshold() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	assert_false(src.contains("STAR_WIN_THRESHOLD"),
		"the verdict is per-student now; stars are only a score")
```

In `test_star_tunables_live_in_balance()`, delete the line
`assert_true(is_equal_approx(Balance.STAR_WIN_THRESHOLD, 2.0), "two stars to win")`.
Leave `test_empty_roster_still_counts_as_passed()` as it is.

- [ ] **Step 2: Run the tests to see them fail**

Run: `test_run(suite="economy_state")`
Expected: FAIL. The parser reports `SKILL_TARGET_PAIRS` / `targets_cleared_for` not found on `GameState`, or the new tests fail.

- [ ] **Step 3: Implement**

In `Scripts/GameState.gd`, replace the doc comment and body of `check_semester_passed()` (lines 697-705), and the pair list inside `count_targets_cleared()` (lines 716-720), so the region reads:

```gdscript
## The per-student pass line (2026-10-01): every student must clear at least
## this many of their three skill targets by the end of the grade, or the
## whole run is lost. Ours, not Balance's -- Balance's old two-star win
## threshold is no longer read anywhere. (Do not spell its constant name in
## this file: test_economy_state greps for it.)
const MIN_TARGETS_PER_STUDENT := 2

## Each skill and the target it is checked against. Energy and mood have
## targets too but never count toward the verdict.
const SKILL_TARGET_PAIRS := [
	["akademis", "target_akademis"],
	["seni_budaya", "target_seni_budaya"],
	["olahraga", "target_olahraga"],
]


## The win rule since 2026-10-01: every student clears at least
## MIN_TARGETS_PER_STUDENT of their three targets. It replaced the 2.0-star
## roster fraction, which it implies -- every student on 2 of 3 is at least
## 8 of 12. One student under the line loses the run however strong the
## rest are. An empty roster still passes, so a debug teleport with nothing
## approved never reads as a loss.
func check_semester_passed() -> bool:
	if approved_students.is_empty():
		return true
	return safe_student_count() == approved_students.size()


## How many of the roster are on or past MIN_TARGETS_PER_STUDENT.
## AturJadwal's objective chip shows this over the roster size.
func safe_student_count() -> int:
	var safe := 0
	for student in approved_students:
		if student_is_safe(student):
			safe += 1
	return safe


## True when `student` (an approved_students dictionary) clears at least
## MIN_TARGETS_PER_STUDENT of their three skill targets.
static func student_is_safe(student: Dictionary) -> bool:
	return targets_cleared_for(student) >= MIN_TARGETS_PER_STUDENT


## How many of `student`'s three skill targets are cleared, by
## target_cleared() -- the same predicate the star meter counts with.
static func targets_cleared_for(student: Dictionary) -> int:
	var cleared := 0
	for pair in SKILL_TARGET_PAIRS:
		if target_cleared(float(student.get(pair[0], 0.0)),
				float(student.get(pair[1], 0.0))):
			cleared += 1
	return cleared


## Counts how many of the roster's three-per-student academic targets have
## been cleared, as [cleared, total]. RunGrade's dominant scoring
## component -- kept here rather than in RunResult because it reads the
## approved_students dictionaries, which are this file's own concern.
func count_targets_cleared() -> Array:
	var cleared := 0
	var total := 0
	for student in approved_students:
		total += SKILL_TARGET_PAIRS.size()
		cleared += targets_cleared_for(student)
	return [cleared, total]
```

Also update the comment above `target_cleared()` (line 730) from "shared by the verdict (count_targets_cleared, and so run_stars and check_semester_passed)" to "shared by the verdict (targets_cleared_for, and so check_semester_passed, safe_student_count and run_stars)".

- [ ] **Step 4: Run the tests to see them pass**

Run: `test_run(suite="economy_state")`
Expected: PASS, with every test in the suite reporting assertions (none at "0 assertions").

- [ ] **Step 5: Run the suites that read the verdict**

Run, one at a time: `test_run(suite="stat_check")`, `test_run(suite="run_result")`, `test_run(suite="end_game_rehearsal")`, `test_run(suite="balance_pacing")`.
Expected:
- `stat_check` and `run_result` PASS.
- `end_game_rehearsal`: `test_arm_makes_the_grade_b_preset_resolve_to_a_b` and `..._grade_c_..._to_a_c` FAIL (both now letter D). Task 2 fixes them.
- `balance_pacing`: it uses `check_semester_passed()` as "the roster cleared", so it now measures the stricter rule. **If any pacing test fails, do not edit `Balance.gd` and do not loosen the test.** Record the failing test names and the week numbers in the PR description under "Balance owner: pacing under the per-student rule", and continue. The collaborator retunes.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-10-01-per-student-lose-rule-design.md docs/superpowers/plans/2026-10-01-per-student-lose-rule.md Scripts/GameState.gd tests/test_economy_state.gd
git commit -m "feat(endgame): lose the run when any student clears under 2 of 3 targets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Keep the debug grade presets honest

**Files:**
- Modify: `Scripts/Debug/EndGameRehearsal.gd:57-65` (`CLEARED_COUNTS`), `:222-265` (`REHEARSAL_STATS` and its comment)
- Test: `tests/test_end_game_rehearsal.gd`

**Interfaces:**
- Consumes: `GameState.student_is_safe(student: Dictionary) -> bool`, `GameState.targets_cleared_for(student: Dictionary) -> int` (Task 1)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_end_game_rehearsal.gd`, after `test_arm_makes_the_grade_d_preset_resolve_to_a_d()`:

```gdscript
## Every grade preset that should pass must keep every student on the
## per-student line (GameState.MIN_TARGETS_PER_STUDENT), or the 2026-10-01
## rule forces its letter to D whatever the score says.
func test_passing_grade_presets_keep_every_student_safe() -> void:
	for preset in [EndGameRehearsal.PRESET_GRADE_A,
			EndGameRehearsal.PRESET_GRADE_B, EndGameRehearsal.PRESET_GRADE_C]:
		var roster := EndGameRehearsal.build_roster(preset, 7, _fake_source_four())
		for s in roster:
			assert_true(GameState.student_is_safe(s), "%s: %s clears only %d of 3"
				% [preset, s.get("name", "?"), GameState.targets_cleared_for(s)])
```

- [ ] **Step 2: Run the test to see it fail**

Run: `test_run(suite="end_game_rehearsal")`
Expected: FAIL in the new test (B and C each have a student on 1), and in the B and C letter tests.

- [ ] **Step 3: Implement**

In `CLEARED_COUNTS`, change exactly two lines:

```gdscript
	PRESET_GRADE_B: [3, 3, 2, 2],
	PRESET_GRADE_C: [2, 2, 2, 2],
```

In `REHEARSAL_STATS[PRESET_GRADE_B]`, change only `"won": 6, "lost": 4` to `"won": 4, "lost": 6`, and leave every other key as it is.

Arithmetic, against `RunGrade.score()` as of `cca53276` (targets 55 × cleared/12, minigames 20 × win rate, money 15 × money/20000, events 10 × event students/4):
- **B**: 55×10/12 = 45.83, plus 20×4/10 = 8.00, plus 15×12000/20000 = 9.00, plus 10×2/4 = 5.00, totals **67.83**. That sits in the B band (60–75), 7.8 above its floor and 7.2 below A.
- **C**: still 8 of 12 cleared, so its score is unchanged at **52.17** (C band 45–60).

**Before trusting those numbers, open `Scripts/EndGame/RunGrade.gd` and check that `score()` still has that shape.** The untracked plan `docs/superpowers/plans/2026-09-29-run-result-four-stats-and-selesai-crash.md` changes the event component and removes `points`/`items`. If it has landed, recompute B and C against the live formula. Keep each at least 5 points inside its band by adjusting only `won`/`lost`/`money`, and drop any key that `REHEARSAL_STATS` no longer has.

Rewrite the comment block above `REHEARSAL_STATS` (the one starting `# Grade-letter scenarios.`) to state the new landings. Replace "grade B lands at 67.25 (B band 60-75)" with "grade B lands at 67.83 (B band 60-75, ~7 points clear of both floors)". Replace the D sentence's reason with "its letter is forced to "D" regardless of score because three of its four students clear under GameState.MIN_TARGETS_PER_STUDENT".

- [ ] **Step 4: Run the tests to see them pass**

Run: `test_run(suite="end_game_rehearsal")`, then `test_run(suite="debug_manager")`
Expected: PASS for both.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Debug/EndGameRehearsal.gd tests/test_end_game_rehearsal.gd
git commit -m "fix(debug): keep the B and C rehearsal presets passing under the per-student rule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: AturJadwal's chip counts safe students

**Files:**
- Modify: `Scenes/AturJadwal/AturJadwal.tscn` (nodes `ObjectiveStrip/StarChip`, `StarChip/Stars`, `StarChip/Icon`)
- Modify: `Scripts/AturJadwal/ObjectiveHint.gd:1-61`
- Modify: `Scripts/AturJadwal/AturJadwal.gd:58`, `:1296-1318`
- Modify: `Assets/Images/UI/Icons/README.md` (usage table)
- Test: `tests/test_objective_hint.gd:76-106`, `tests/test_atur_jadwal.gd:1213-1259`

**Interfaces:**
- Consumes: `GameState.safe_student_count() -> int` (Task 1)
- Produces: `ObjectiveHint.safe_text(safe: int, total: int) -> String`, `ObjectiveHint.safe_percent(safe: int, total: int) -> float`. Removes `format_stars`, `star_text` and `progress_percent` (their only caller is AturJadwal).

- [ ] **Step 1: Scene first (restart the editor first if any `.gd` was patched this session)**

`scene_open("res://Scenes/AturJadwal/AturJadwal.tscn")`, then:
1. Rename `ObjectiveStrip/StarChip` → `SafeChip` (`node_manage` rename).
2. Rename `ObjectiveStrip/SafeChip/Stars` → `Count`.
3. `node_set_property` `ObjectiveStrip/SafeChip/Icon` `texture` = `res://Assets/Images/UI/Icons/nav_students.svg`.
4. `node_set_property` `ObjectiveStrip/SafeChip/Count` `text` = `0 / 4`.

Leave the theme variations (`ObjectiveStarLabel`) and the chip material alone. `scene_save`, then `git diff HEAD -- '*.gd'` should be empty. Restart the editor now, before patching scripts.

- [ ] **Step 2: Write the failing tests**

In `tests/test_objective_hint.gd`:

In `test_the_strip_only_uses_glyphs_the_display_face_has()`, replace
```gdscript
	for stars in [0.0, 0.25, 1.5, 1.75, 2.0, 3.0]:
		texts.append(ObjectiveHint.star_text(stars))
```
with
```gdscript
	for pair in [[0, 4], [3, 4], [6, 6], [1, 1]]:
		texts.append(ObjectiveHint.safe_text(pair[0], pair[1]))
```

Delete `test_progress_is_measured_against_the_pass_line()` and `test_the_star_chip_reads_stars_over_the_pass_line()`, and add:

```gdscript
## The bar fills toward the whole roster being safe (GameState's
## per-student rule): full means the grade passes.
func test_progress_is_the_safe_share_of_the_roster() -> void:
	assert_eq(ObjectiveHint.safe_percent(0, 4), 0.0)
	assert_eq(ObjectiveHint.safe_percent(2, 4), 50.0)
	assert_eq(ObjectiveHint.safe_percent(4, 4), 100.0)
	assert_eq(ObjectiveHint.safe_percent(5, 4), 100.0, "clamped at full")
	assert_eq(ObjectiveHint.safe_percent(0, 0), 100.0,
		"an empty roster reads as passing, as check_semester_passed() does")


func test_the_chip_reads_safe_students_over_the_roster() -> void:
	assert_eq(ObjectiveHint.safe_text(3, 4), "3 / 4")
	assert_eq(ObjectiveHint.safe_text(0, 6), "0 / 6")


func test_the_strip_no_longer_measures_stars() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/ObjectiveHint.gd")
	assert_false(src.contains("STAR_WIN_THRESHOLD"),
		"the pass line is per-student now, not a star count")
```

In `tests/test_atur_jadwal.gd`:
- In the `parts` dictionary (line 1213), change `"StarChip/Body"`, `"StarChip/Icon"` and `"StarChip/Stars"` to `"SafeChip/Body"`, `"SafeChip/Icon"` and `"SafeChip/Count"`.
- Line 1224: `strip.get_node("SafeChip/Count")`.
- Line 1230: `strip.get_node("SafeChip/Body")`, and change its message to `"the safe chip is gold gradient"`.
- Lines 1234-1235 become:
```gdscript
	assert_eq((strip.get_node("SafeChip/Icon") as TextureRect).texture.resource_path,
		"res://Assets/Images/UI/Icons/nav_students.svg",
		"the chip counts students, so it wears the roster icon, not a star")
```
- In `test_the_objective_strip_reads_real_data()`, replace the needles `"GameState.run_stars()"`, `"ObjectiveHint.star_text(stars)"` and `"ObjectiveHint.progress_percent(stars)"` with `"GameState.safe_student_count()"`, `"ObjectiveHint.safe_text(safe, total)"` and `"ObjectiveHint.safe_percent(safe, total)"`, and after the loop add:
```gdscript
	assert_false(src.contains("StarChip"), "the chip was renamed SafeChip")
```

- [ ] **Step 3: Run the tests to see them fail**

Run: `test_run(suite="objective_hint")`, then `test_run(suite="atur_jadwal")`
Expected: FAIL. `safe_text`/`safe_percent` don't exist yet, and the real-data needles are missing.

- [ ] **Step 4: Implement**

`Scripts/AturJadwal/ObjectiveHint.gd`:
1. In the header, replace the paragraph starting "Nothing here restates a threshold." with:
```gdscript
## Nothing here restates a threshold. The pass line is GameState's
## per-student rule (MIN_TARGETS_PER_STUDENT), counted by
## GameState.safe_student_count(); "tired" is Balance.BATAS_KELELAHAN; a
## skill's gap is measured against the student's own target. The most
## urgent skill is the same one StatFlags flags "perlu", so the strip and
## the bars never disagree.
```
2. Delete `format_stars()`, `star_text()` and `progress_percent()` with their doc comments (lines 41-60), and add in their place:
```gdscript
## The chip: students on or past the pass line, over the roster.
static func safe_text(safe: int, total: int) -> String:
	return "%d / %d" % [safe, total]


## How far the run is toward passing, 0-100: the share of the roster that is
## safe. Full means the grade passes. An empty roster reads full, matching
## GameState.check_semester_passed().
static func safe_percent(safe: int, total: int) -> float:
	if total <= 0:
		return 100.0
	return clampf(float(safe) / float(total) * 100.0, 0.0, 100.0)
```

`Scripts/AturJadwal/AturJadwal.gd`:
1. Line 58: `@onready var objective_count: Label = $ObjectiveStrip/SafeChip/Count`
2. In `_update_objective_strip()`, replace
```gdscript
	var stars: float = GameState.run_stars()
	if objective_stars:
		objective_stars.text = ObjectiveHint.star_text(stars)
	if objective_progress:
		objective_progress.value = ObjectiveHint.progress_percent(stars)
```
with
```gdscript
	var safe: int = GameState.safe_student_count()
	var total: int = GameState.approved_students.size()
	if objective_count:
		objective_count.text = ObjectiveHint.safe_text(safe, total)
	if objective_progress:
		objective_progress.value = ObjectiveHint.safe_percent(safe, total)
```
3. In the same function, `get_node_or_null("ObjectiveStrip/StarChip/Body")` → `get_node_or_null("ObjectiveStrip/SafeChip/Body")`.
4. Update the function's doc comment: "the run's stars against the pass line" → "how many students are on the per-student pass line".
5. `grep -n "objective_stars" Scripts/AturJadwal/AturJadwal.gd` must return nothing.

`Assets/Images/UI/Icons/README.md`: change the `nav_students.svg` row's "Used by" cell to `Lobby's \`Student\` tile (\`RaisedPage\`); AturJadwal's objective \`SafeChip\``, and add `test_atur_jadwal` to its "Pinned by" cell.

- [ ] **Step 5: Run the tests to see them pass**

Run: `test_run(suite="objective_hint")`, `test_run(suite="atur_jadwal")`, `test_run(suite="ui_icons")`, `test_run(suite="tall_screen_layout")`
Expected: all PASS.

- [ ] **Step 6: Look at it**

Run `project_run`, open the debug overlay (F1) → General → **⚡ Seed Playtest State**, then Scenes → AturJadwal. Take a **full-size** `editor_screenshot` of the game (or crop to the strip) and confirm the chip shows the person icon and "0 / 4" (seeded students start under their targets), with no clipping in the Boohong face. Send that screenshot to the user. Stop the project.

- [ ] **Step 7: Commit**

```bash
git add Scenes/AturJadwal/AturJadwal.tscn Scripts/AturJadwal/ObjectiveHint.gd Scripts/AturJadwal/AturJadwal.gd Assets/Images/UI/Icons/README.md tests/test_objective_hint.gd tests/test_atur_jadwal.gd
git commit -m "feat(atur-jadwal): objective chip counts students on the pass line

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: StatCheck stamps a failing student

**Files:**
- Modify: `Scenes/EndGame/StatCheckCard.tscn` (new `FailStamp`, `FailStamp/StampLabel`)
- Modify: `Scripts/EndGame/StatCheckCard.gd`
- Modify: `Scripts/EndGame/StatCheck.gd:107-128` (`_run_check` rows loop)
- Test: `tests/test_stat_check.gd`

**Interfaces:**
- Consumes: `GameState.MIN_TARGETS_PER_STUDENT`, `GameState.target_cleared(value: float, target: float) -> bool` (static)
- Produces: `StatCheckCard.failed: bool`, `static func StatCheckCard.cleared_count(student: StudentData) -> int`, `func StatCheckCard.stamp_if_failed() -> void`

- [ ] **Step 1: Scene first (restart the editor first if any `.gd` was patched since the last restart)**

`scene_open("res://Scenes/EndGame/StatCheckCard.tscn")`, then create the following under the root `StatCheckCard`, **after** `Paper` so it draws on top. One `batch_execute` works:

`FailStamp`, a `PanelContainer`, parent `.`:
- `layout_mode` 0, `offset_left` 150, `offset_top` 580, `offset_right` 610, `offset_bottom` 700. This sits over the middle of the three rows; the rows span about y 380–940 in card space.
- `rotation` -0.10471976 (about -6°, SchoolDay's `DayStamp` tilt)
- `pivot_offset` (230, 60)
- `mouse_filter` 2 (Ignore), so a tap still rushes the check
- `theme_type_variation` `DayStampPanel`
- `visible` false

`StampLabel`, a `Label`, parent `FailStamp`:
- `layout_mode` 2, `theme_type_variation` `DayStampLabel`, `text` `TIDAK LULUS`, `horizontal_alignment` 1, `vertical_alignment` 1

`scene_save`, then `git diff HEAD -- '*.gd'` should be empty. Restart the editor before patching scripts.

- [ ] **Step 2: Write the failing tests**

In `tests/test_stat_check.gd`, replace the body of `test_the_name_is_the_only_text_on_the_page()` with:

```gdscript
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var stamp: Node = card.get_node("FailStamp")
	var bio: Array = card.find_children("*", "Label", true, false).filter(
		func(l): return not stamp.is_ancestor_of(l))
	assert_eq(bio.size(), 1,
		"one bio Label on the page (the verdict stamp aside): %s" % str(bio))
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	assert_false(src.contains("profil"),
		"StatCheckCard never shows the Agama / Jenis Kelamin lines")
```

Then add after `test_card_rows_carry_the_right_categories_and_icons()`:

```gdscript
## The verdict's mark on a page (2026-10-01): a student under
## GameState.MIN_TARGETS_PER_STUDENT is stamped TIDAK LULUS, in the same ink
## stamp SchoolDay uses for "<hari> selesai".
func test_card_carries_a_hidden_fail_stamp() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var stamp := card.get_node_or_null("FailStamp") as PanelContainer
	assert_true(stamp != null, "FailStamp is a PanelContainer authored in the scene")
	if stamp == null:
		return
	assert_eq(stamp.theme_type_variation, &"DayStampPanel")
	assert_false(stamp.visible, "the stamp starts hidden")
	assert_eq(stamp.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"a tap through the stamp still rushes the check")
	assert_true(stamp.get_index() > card.get_node("Paper").get_index(),
		"the stamp draws over the paper")
	var label := stamp.get_node_or_null("StampLabel") as Label
	assert_true(label != null and label.theme_type_variation == &"DayStampLabel",
		"StampLabel wears DayStampLabel")
	if label != null:
		assert_eq(label.text, "TIDAK LULUS")


func _student_with(a: float, s: float, o: float) -> StudentData:
	var sd := StudentData.new()
	sd.student_name = "Citra"
	sd.akademis = a
	sd.target_akademis = 60.0
	sd.seni_budaya = s
	sd.target_seni_budaya = 60.0
	sd.olahraga = o
	sd.target_olahraga = 60.0
	return sd


func test_cleared_count_uses_the_verdicts_predicate() -> void:
	assert_eq(StatCheckCard.cleared_count(_student_with(70.0, 30.0, 60.0)), 2)
	assert_eq(StatCheckCard.cleared_count(_student_with(70.0, 30.0, 10.0)), 1)
	assert_eq(StatCheckCard.cleared_count(_student_with(0.0, 0.0, 0.0)), 0)


func test_a_student_under_the_line_is_stamped_only_when_asked() -> void:
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	card.bind(_student_with(70.0, 30.0, 10.0))
	assert_true(card.failed, "1 of 3 is under the line")
	assert_false(card.get_node("FailStamp").visible, "bind() alone never shows it")
	card.stamp_if_failed()
	assert_true(card.get_node("FailStamp").visible, "stamp_if_failed() shows it")
	Engine.get_main_loop().root.remove_child(card)


func test_a_safe_student_is_never_stamped() -> void:
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	card.bind(_student_with(70.0, 30.0, 60.0))
	assert_false(card.failed, "2 of 3 is safe")
	card.stamp_if_failed()
	assert_false(card.get_node("FailStamp").visible)
	Engine.get_main_loop().root.remove_child(card)


## The stamp lands after the card's rows have filled, and before the read
## beat and slide-out, so the player sees why.
func test_the_sequence_stamps_each_card_after_its_rows() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var rows_at := src.find("for row in card.rows():")
	var stamp_at := src.find("card.stamp_if_failed()")
	var out_at := src.find("await _slide_out(card)")
	assert_true(stamp_at > 0, "StatCheck calls card.stamp_if_failed()")
	assert_true(rows_at < stamp_at and stamp_at < out_at,
		"after the rows loop, before the slide-out")
```

- [ ] **Step 3: Run the tests to see them fail**

Run: `test_run(suite="stat_check")`
Expected: FAIL. `cleared_count`/`failed`/`stamp_if_failed` don't exist, and StatCheck doesn't call the stamp yet.

- [ ] **Step 4: Implement**

`Scripts/EndGame/StatCheckCard.gd`:
1. Add this paragraph to the file header, after "This page deliberately shows the name only -- it is about the targets, not the student's file.":
```gdscript
##
## A student under GameState.MIN_TARGETS_PER_STUDENT gets the FailStamp
## ("TIDAK LULUS", SchoolDay's day-stamp ink), authored hidden in the scene
## and shown by stamp_if_failed() once StatCheck has filled the rows.
```
2. After the row `@onready`s add:
```gdscript
@onready var fail_stamp: Control = $FailStamp

## True once bind() has seen a student under GameState.MIN_TARGETS_PER_STUDENT.
var failed: bool = false
```
3. At the end of `bind()` add:
```gdscript
	failed = cleared_count(student) < GameState.MIN_TARGETS_PER_STUDENT
	fail_stamp.visible = false
```
4. Add after `rows()`:
```gdscript
## How many of `student`'s three skill targets are cleared, by the verdict's
## own predicate, so the stamp and GameState.check_semester_passed() never
## disagree.
static func cleared_count(student: StudentData) -> int:
	var cleared := 0
	for pair in [
		[student.akademis, student.target_akademis],
		[student.seni_budaya, student.target_seni_budaya],
		[student.olahraga, student.target_olahraga],
	]:
		if GameState.target_cleared(float(pair[0]), float(pair[1])):
			cleared += 1
	return cleared


## Shows the TIDAK LULUS stamp with a pop and the stamp SFX if bind() found
## this student under the line; does nothing otherwise. The SFX is gated so
## the suite can call this in the editor.
func stamp_if_failed() -> void:
	if not failed:
		return
	fail_stamp.visible = true
	Juice.pop_in(fail_stamp)
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"stamp")
```

`Scripts/EndGame/StatCheck.gd`, in `_run_check()`, directly after
```gdscript
		if rushed_clears > 0:
			AudioDirector.play_sfx(&"tally")
```
add
```gdscript
		card.stamp_if_failed()
```

- [ ] **Step 5: Run the tests to see them pass**

Run: `test_run(suite="stat_check")`, `test_run(suite="viewport_editability")`, `test_run(suite="script_documentation")`
Expected: all PASS.

- [ ] **Step 6: Look at it**

Run `project_run`. Open the debug overlay → Scenes → **🎭 Gladi Resik Akhir Kelas** → **Campur (3/2/1/0 bintang)**. When StatCheck reaches the third card (1 of 3), take a **full-size** `editor_screenshot`. Check that the stamp sits over the rows, reads "TIDAK LULUS" in red display type, is tilted, and isn't clipped by the card slot. Let the run reach RunResult and confirm the letter is **D**. Send the StatCheck screenshot to the user. Stop the project.

- [ ] **Step 7: Commit**

```bash
git add Scenes/EndGame/StatCheckCard.tscn Scripts/EndGame/StatCheckCard.gd Scripts/EndGame/StatCheck.gd tests/test_stat_check.gd
git commit -m "feat(stat-check): stamp TIDAK LULUS on a student under the pass line

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Docs, full run, ship

**Files:**
- Modify: `CLAUDE.md` (`## The game` opening paragraph and the Grades paragraph)
- Modify: `docs/superpowers/CHANGELOG.md` (new top entry)

- [ ] **Step 1: CLAUDE.md**

Replace the sentences from "Clear two-thirds of the roster's academic targets" to "and passes." with:

```markdown
To pass, by the end of the grade's final week **every student must clear at
least 2 of their 3 academic targets** (`GameState.MIN_TARGETS_PER_STUDENT`);
one student under that loses the run with a D, however strong the rest.
`run_stars()` (cleared ÷ total × 3) is only a score now: the Lobby header,
StatCheck's meter and RunGrade read it, the verdict does not.
```

In the paragraph under the Grades table, after "…but nothing reads them.", add: "`Balance.STAR_WIN_THRESHOLD` (2.0) is unread too since the per-student rule."

Keep the file under its 23,000-character soft budget: `wc -c CLAUDE.md`.

- [ ] **Step 2: CHANGELOG**

Add a top entry, `## 2026-10-01 — Per-student lose rule`, with three or four lines. Cover the rule (any student under 2 of 3 loses the run, a D), the AturJadwal safe-student chip, the StatCheck stamp, and the B/C rehearsal presets. If Task 1 Step 5 recorded any `balance_pacing` failures, add them as "pacing reported to the Balance owner".

- [ ] **Step 3: Full suite**

Run: `test_run()` (full). Expected: all PASS, apart from `balance_pacing` failures already recorded for the owner. Then `git status`, and `git checkout --` `Assets/Theme/kejartes_theme.tres` and `Assets/Audio/default_bus_layout.tres` if they changed. Budget one editor restart for this.

- [ ] **Step 4: Commit and ship**

```bash
git add CLAUDE.md docs/superpowers/CHANGELOG.md
git commit -m "docs(endgame): record the per-student lose rule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then invoke the `ship-pr` skill.
