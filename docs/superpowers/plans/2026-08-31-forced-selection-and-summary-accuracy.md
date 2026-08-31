# Forced Student Selection & Day/Week Summary Accuracy — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make roster selection mandatory on every fresh game even when tutorials
are bypassed, and make the numbers on the DaySummary and ResultCheckup cards
match the students the player actually picked and the schedule they actually set.

**Architecture:** Five surgical fixes, no new systems. Two restore the selection
step that the tutorial-bypass path silently skipped (`student_card.gd` never armed
its own buttons; `loby.gd` hid the "Pilih Murid" button outright). Three correct
what the simulation records: rest and Wirausaha days were double-logging their
energy/mood movement, minigames were applied to the whole class regardless of
schedule, and an empty roster silently fabricated four placeholder students whose
`id = 0` made every schedule lookup miss.

**Tech Stack:** Godot 4.6 (GDScript), Godot AI MCP in-editor test runner
(`McpTestSuite`), no new dependencies.

**Spec:** No separate spec doc — this plan implements two bug reports, restated
verbatim in **Problem Statement** below, plus the root-cause trace that produced
the task list. The user's two clarifying decisions are recorded there too.

---

## Problem Statement

Reported, verbatim:

1. *"even though we are bypassing every tutorial, code so that everytime we
   starting the game, even though there is no tutorial, we still have to select
   the students like in the tutorial"*
2. *"in the daysummary and resultcheckup, the students name and stat gained did
   not match the selection and scheduling"*

### Root cause of (1)

`DebugManager._apply_playtest_defaults()` (`Scripts/Debug/DebugManager.gd:139`)
sets `GameState.tutorials_bypassed = true` and `lobby_tutorial_completed = true`
on **every debug launch**. Two things then go wrong:

- `Scripts/Lobby/loby.gd:132-156` — the post-tutorial short-circuit sets
  `student_button.visible = false` and `jadwal_button.visible = true`
  unconditionally. "Pilih Murid" is never reachable, so
  `GameState.approved_students` stays empty for the whole session.
- `Scripts/StudentCard/student_card.gd:171-173` — the bypass path sets
  `tutorial_active = false` and hides the overlay, but never calls
  `_show_page(current_page)`. A finished tutorial reaches `_show_page()` through
  `_end_tutorial()` (`student_card.gd:585`); the bypass path does not. So the
  screen opens with `next_kanan`, `next_kiri` and `belajar_button` still hidden
  by `_ready()` (lines 156-165) and no page counter — unusable even when you do
  reach it, which the grade-up route in `Scripts/EndGame/SemesterEnd.gd:441`
  does in ordinary play.

### Root cause of (2) — three separate defects

- **Placeholder roster.** `StudentManager.initialize_from_gamestate()`
  (`Scripts/SchoolSimulation/StudentManager.gd:212-219`) falls back to
  `initialize_students()` when `approved_students` is empty, building
  **Budi / Ani / Cici / Doni** with the default `id = 0`. Every schedule lookup
  in the file is guarded by `student_id != 0`
  (`StudentManager.gd:97, 118, 225`), so no schedule ever binds and every
  student silently defaults to `Istirahat`. That is literally "names and stats
  did not match the selection and scheduling". Fixed at the source by Tasks 1-2;
  Task 5 makes the remaining debug-only path announce itself.
- **Double-logged needs on rest and Wirausaha days.**
  `apply_daily_decay_all()` folds the activity's own energy/mood movement into
  `energy_loss` / `mood_loss` (`StudentManager.gd:140-141, 159-160`) and then
  logs the folded total as `"decay"` (lines 172-173) — *and* logs the activity
  movement a second time as `"activity"` (lines 143-144 for Wirausaha, 182-183
  for Istirahat). `DaySummaryStudentRow._sum_needs_deltas()` sums every line
  regardless of source, so the card reports roughly **twice** the movement the
  student actually made. Study days are already correct (no second log), so the
  daily card and the weekly card — which reads true deltas off
  `record_initial_stats()` — disagree with each other.
- **Whole-class minigames.** `record_minigame_result()`
  (`StudentManager.gd:61`) loops `for student in students` and applies the
  result to everyone, so a student scheduled for `Akademis` gains `olahraga`
  from an Olahraga minigame, and a student on `Istirahat` pays its energy cost.

### Decisions taken by the user

- **Minigame scope:** restrict to the students actually scheduled for that
  category, *keeping* the whole-class behaviour only for the debug menu's scene
  jump — where there is no schedule at all and a minigame that moved nobody
  would make the jump useless. Task 4 implements exactly that: scheduled
  students, falling back to the whole class when nobody is scheduled.
- **Selection gate placement:** in the **Lobby**, mirroring the tutorial's own
  phase 1 shape (show "Pilih Murid", hide "Atur Jadwal") minus the overlay —
  not a direct CutScene→StudentCard reroute.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Engine:** Godot **4.6**, portrait 1080×1920, `mobile` renderer, d3d12.
- **Language split:** game-facing identifiers and all UI text are **Indonesian**;
  engine and systems code is English. Match the surrounding file.
- **No `theme_override_*`.** Use a `ThemeFactory` type variation instead. (No
  task here touches styling; the rule still stands if one is tempted.)
- **Tunable gameplay numbers** belong in `Scripts/Balance.gd` as a named `static
  var`, or as an `@export` — never inline. No task here introduces a new number.
- **No save system.** `GameState` is session-scoped by design. Do not add
  persistence.
- **Test suites** must be `@tool`, must extend `McpTestSuite`
  (`addons/godot_ai/testing/test_suite.gd`), and **no test may be a coroutine** —
  the runner does `suite.call(name)` without awaiting, so an `await` silently
  aborts the test and it reports "0 assertions".
- **Assertion API available:** `assert_true`, `assert_false`, `assert_eq`,
  `assert_ne`, `assert_not_null`, `assert_gt`, `assert_has_key`,
  `assert_contains`, `assert_is_error`. There is **no** `assert_almost_eq` —
  compare floats with `assert_true(abs(a - b) < eps, ...)`.
- **Scripts the runner instantiates live must themselves be `@tool`.**
  `student_card.gd` and `loby.gd` are **not** `@tool`, so their `_ready()` never
  runs under the runner and their `@onready` vars stay null. Tests for Tasks 1
  and 2 are therefore **source-text scans** (`src.contains(...)`), the pattern
  already established in `tests/test_student_card.gd` and `tests/test_lobby.gd`.
  `StudentManager` is a plain `Node` with a `class_name` and *is* instantiable —
  Tasks 3-5 get real behavioural tests, following `tests/test_wirausaha.gd`.
- **Always `filesystem_manage(op="scan")` after editing a `.gd`, before
  `test_run`.** The runner serves a stale autoload otherwise and you will debug
  a phantom.
- **The Godot MCP bridge is single-client.** Only one client may hold the
  backend. Subagents write code; the session driving the editor runs the tests.
- **Commits:** Conventional Commits with a scope, e.g.
  `fix(lobby): demand a roster before showing Atur Jadwal`.
- `loby.gd` and `koprasi.gd` are misspelled but load-bearing. Do not "fix" them.

---

## File Structure

| File | Change | Responsibility after the change |
|---|---|---|
| `Scripts/StudentCard/student_card.gd` | Modify `_ready()` (lines 169-175) | The bypass path arms the screen the same way `_end_tutorial()` does. |
| `Scripts/Lobby/loby.gd` | Modify the post-tutorial branch (lines 132-156) | The Lobby keeps demanding a roster until one exists, tutorial or not. |
| `Scripts/SchoolSimulation/StudentManager.gd` | Modify `apply_daily_decay_all()`, `record_minigame_result()`, `initialize_from_gamestate()`; add `participants_for()` | The day log records each movement exactly once, attributed to its real source; a minigame only touches its participants; a fabricated roster says so out loud. |
| `tests/test_student_card.gd` | Add 1 test | Bypass path still opens a usable card. |
| `tests/test_lobby.gd` | Add 1 test | Post-tutorial Lobby still gates on the roster. |
| `tests/test_stat_log.gd` | **Create** | New suite: what the day summary reports equals what actually moved, and who a minigame is allowed to move. |

`tests/test_stat_log.gd` is a new suite rather than additions to
`tests/test_day_summary.gd` because that suite owns the *card* (art, geometry,
tween behaviour) and this one owns the *ledger the card reads*. They fail for
different reasons and a reviewer should be able to tell which broke.

---

### Task 1: StudentCard opens usable when the tutorial is bypassed

**Files:**
- Modify: `Scripts/StudentCard/student_card.gd:169-175`
- Test: `tests/test_student_card.gd`

**Interfaces:**
- Consumes: `GameState.tutorials_bypassed` (`bool`, `Scripts/GameState.gd:23`);
  `func _show_page(index: int):` (`student_card.gd:760` — no return
  annotation in the file; do not add one), which sets page visibility,
  staggers the card in, shows the approval stamp, calls
  `_update_nav_buttons(index)` and writes the page counter. `current_page`
  (`int`, `student_card.gd:58`) is 0 on entry.
- Produces: nothing new. Later tasks do not depend on this one.

**Why a direct call and not `call_deferred`:** `_show_page()` is safe at
`_ready()` time. Its only size-dependent path is `_shift_approve_for_belajar()`,
reached solely when `approved_count >= MAX_APPROVE` — which cannot be true on
entry: a fresh game has `approved_count == 0`, and `MAX_APPROVE` grows with the
grade (2/3/4) so a carried-over roster is always one short of the new maximum.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card.gd`, directly after
`test_debug_tutorial_bypass_skips_the_student_card_tutorial` (ends line 72):

```gdscript
func test_bypassing_the_tutorial_still_opens_a_usable_card() -> void:
	# _ready() hides both page arrows and the Belajar button and leaves the
	# page counter unwritten; a finished tutorial undoes all three by
	# reaching _show_page() through _end_tutorial(). The bypass path has to
	# do the same or the screen opens with no way to pick anyone.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var bypass_idx := src.find("if GameState.tutorials_bypassed:")
	assert_gt(bypass_idx, -1, "the bypass branch must still exist")
	var else_idx := src.find("\telse:\n\t\t_show_step(0)", bypass_idx)
	assert_gt(else_idx, bypass_idx, "the tutorial branch must still follow it")
	var branch := src.substr(bypass_idx, else_idx - bypass_idx)
	assert_true(branch.contains("_show_page(current_page)"),
		"a bypassed tutorial must arm the page arrows, the Belajar button and the page counter, exactly as _end_tutorial() does")
```

- [ ] **Step 2: Run the test and verify it fails**

Godot MCP, in this order (the scan is mandatory — see Global Constraints):

```
filesystem_manage(op="scan")
test_run(suite="student_card")
```

Expected: `test_bypassing_the_tutorial_still_opens_a_usable_card` FAILS with
"a bypassed tutorial must arm the page arrows…". Every other test in the suite
still passes.

- [ ] **Step 3: Write the implementation**

In `Scripts/StudentCard/student_card.gd`, replace lines 171-173:

```gdscript
	if GameState.tutorials_bypassed:
		tutorial_active = false
		color_rect.hide()
	else:
```

with:

```gdscript
	if GameState.tutorials_bypassed:
		tutorial_active = false
		color_rect.hide()
		# A finished tutorial ends in _end_tutorial(), whose last act is
		# _show_page() -- that is what reveals the first kertas, arms the
		# two page arrows and the Belajar button, and paints the page
		# counter. Bypassing skipped it, so the screen used to open with
		# every one of those still hidden by _ready() above and no roster
		# could be approved at all.
		_show_page(current_page)
	else:
```

Keep `tutorial_active = false` and `color_rect.hide()` on consecutive lines:
the existing `test_debug_tutorial_bypass_skips_the_student_card_tutorial`
asserts the literal `"tutorial_active = false\n\t\tcolor_rect.hide()"`.

- [ ] **Step 4: Run the tests and verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="student_card")
```

Expected: PASS, including the pre-existing
`test_debug_tutorial_bypass_skips_the_student_card_tutorial`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/StudentCard/student_card.gd tests/test_student_card.gd && git commit -m "fix(student-card): arm the card when the tutorial is bypassed"
```

---

### Task 2: The Lobby demands a roster before it offers Atur Jadwal

**Files:**
- Modify: `Scripts/Lobby/loby.gd:132-156`
- Test: `tests/test_lobby.gd`

**Interfaces:**
- Consumes: `GameState.approved_students` (`Array` of `Dictionary`,
  `Scripts/GameState.gd:9`); `GameState.lobby_tutorial_completed`;
  `_on_student_pressed()` (`loby.gd:669`), already wired in this branch, which
  routes to `res://Scenes/StudentCard/student_card.tscn`.
- Produces: nothing new. StudentCard's own return path
  (`student_card.gd::_on_belajar_pressed`) already sets
  `GameState.returned_from_student_card = true` and fills
  `GameState.approved_students`, so the second visit takes the normal branch.

**Behaviour after the change:** with an empty roster the post-tutorial Lobby
shows "Pilih Murid" and hides "Atur Jadwal" — the same shape tutorial phase 1
has, without the overlay. Once StudentCard fills the roster the branch runs
again with `is_empty() == false` and behaves exactly as it does today. The
grade-up route (`SemesterEnd.gd:441`) carries the roster forward, so it is
unaffected.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_lobby.gd`, directly after `test_tutorial_gate_still_wired`
(ends line 83):

```gdscript
func test_a_lobby_with_no_tutorial_still_demands_a_selection() -> void:
	# Debug builds boot with tutorials_bypassed = true, which sends every
	# fresh session down the post-tutorial short-circuit. That branch used
	# to hide Pilih Murid outright, so approved_students stayed empty for
	# the whole run and the simulation fell back to placeholder students.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var head := src.find("if GameState.lobby_tutorial_completed or GameState.minggu_ke > 1:")
	assert_gt(head, -1, "the post-tutorial short-circuit must still exist")
	var tail := src.find("if GameState.returned_from_student_card:", head)
	assert_gt(tail, head, "the phase-1/phase-2 split must still follow it")
	var branch := src.substr(head, tail - head)
	assert_true(branch.contains("GameState.approved_students.is_empty()"),
		"the post-tutorial lobby must ask whether a roster has been picked yet")
	assert_true(branch.contains("student_button.visible = needs_roster"),
		"Pilih Murid must stay on screen while the roster is empty")
	assert_true(branch.contains("jadwal_button.visible = not needs_roster"),
		"Atur Jadwal must stay hidden until the roster is picked")
	assert_false(branch.contains("student_button.visible = false"),
		"the unconditional hide of Pilih Murid must be gone from this branch")
```

- [ ] **Step 2: Run the test and verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="lobby")
```

Expected: `test_a_lobby_with_no_tutorial_still_demands_a_selection` FAILS with
"the post-tutorial lobby must ask whether a roster has been picked yet".

- [ ] **Step 3: Write the implementation**

In `Scripts/Lobby/loby.gd`, replace lines 136-137:

```gdscript
		student_button.visible = false
		jadwal_button.visible = true
```

with:

```gdscript
		# Bypassing the tutorial must not bypass the roster. Debug builds
		# boot with tutorials_bypassed = true, so this branch is the FIRST
		# thing a fresh session sees -- hiding Pilih Murid here left
		# approved_students empty for the whole run, and the simulation
		# then fell back to four placeholder students the player never
		# picked. Same shape as tutorial phase 1, minus the overlay.
		var needs_roster := GameState.approved_students.is_empty()
		student_button.visible = needs_roster
		jadwal_button.visible = not needs_roster
```

Leave the rest of the branch untouched — `student_button.disabled = false` and
all six `pressed.connect(...)` guards below already wire the button correctly.

- [ ] **Step 4: Run the tests and verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="lobby")
```

Expected: PASS, including the pre-existing
`test_still_routes_to_student_card_and_atur_jadwal` and
`test_tutorial_gate_still_wired`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Lobby/loby.gd tests/test_lobby.gd && git commit -m "fix(lobby): demand a roster before offering Atur Jadwal"
```

---

### Task 3: A rest or Wirausaha day reports the movement that actually happened

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd:130-183`
- Test: `tests/test_stat_log.gd` (**create**)

**Interfaces:**
- Consumes: `StudentData.apply_personality_daily_decay() -> Dictionary`
  (returns `energy_loss`, `mood_loss`, `reason`, `current_energy`,
  `current_mood`); `StudentData.apply_jadwal_activity(category, base_gain,
  specialty_bonus, same_subject_count) -> Dictionary` (returns `stat_delta`,
  `energy_delta`, `mood_delta`, `is_specialty`, `took_ijin`, `ijin_reason`,
  `final_category`); `StudentManager.log_stat_change(day_name, student_name,
  stat_key, delta, source) -> void`, which returns early on `delta == 0.0`.
- Produces: `tests/test_stat_log.gd` with suite name `"stat_log"`, the constant
  `_EPS := 0.001`, and the helpers `_manager_with(roster: Array) ->
  StudentManager` and `_logged_delta(manager: StudentManager, day: String,
  sname: String, key: String) -> float`. All three are reused by Tasks 4 and 5.

**The invariant being restored:** for every student and every stat, the sum of
that day's logged deltas equals the change the student's fields actually
underwent. `decay_res["energy_loss"]` still holds the *pure* personality decay
after the fix, because `var energy_loss = decay_res["energy_loss"]` copies the
float and the later `+=` / `-=` mutate only the local.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_stat_log.gd`:

```gdscript
@tool
extends McpTestSuite

## The ledger the DaySummary card reads: StudentManager.daily_stat_log,
## surfaced by get_day_summary() and summed by
## DaySummaryStudentRow._sum_deltas/_sum_needs_deltas.
##
## The card's own art, geometry and tweens belong to
## tests/test_day_summary.gd. This suite owns one invariant instead: what
## the summary REPORTS for a day equals what the student actually moved
## that day -- plus the rule for who a minigame is allowed to move.
##
## Suite constraints, carried from tests/test_wirausaha.gd:
##  * @tool, or the runner reports the class abstract.
##  * No coroutines -- the runner does suite.call(name) without awaiting.
##  * StudentManager is a plain Node with a class_name, so unlike the
##    screens it can be driven for real rather than scanned as text.

const _EPS := 0.001


func suite_name() -> String:
	return "stat_log"


## A manager holding exactly the given roster, with the four placeholder
## students _init() builds discarded and the log emptied.
##
## `roster` is deliberately untyped: an array LITERAL at a call site is a
## plain Array, and GDScript will not pass one to an Array[StudentData]
## parameter. Copying into a typed local is what makes `m.students`
## (Array[StudentData]) accept it.
func _manager_with(roster: Array) -> StudentManager:
	var typed: Array[StudentData] = []
	for s in roster:
		typed.append(s)
	var m := StudentManager.new()
	m.students = typed
	m.daily_stat_log.clear()
	m.minigame_history.clear()
	return m


## Everything the day summary would show for one student and one stat,
## summed the same way DaySummaryStudentRow sums it.
func _logged_delta(manager: StudentManager, day: String, sname: String, key: String) -> float:
	var total := 0.0
	for entry in manager.get_day_summary(day):
		if String(entry.get("student_name", "")) != sname:
			continue
		for ch in entry.get("changes", []):
			if String(ch.get("stat_key", "")) == key:
				total += float(ch.get("delta", 0.0))
	return total


func test_a_rest_day_reports_the_movement_that_actually_happened() -> void:
	# Istirahat used to be logged twice: once folded into energy_loss and
	# once again as its own "activity" line, so the card read roughly
	# double the recovery. Start at 50 so neither clamp is reachable --
	# decay is 4..6 and recovery 20..30.
	var original: Dictionary = GameState.day_schedules
	GameState.day_schedules = {
		101: {"Senin": {"category": "Istirahat", "mood_cost": 0, "energy_cost": 0}},
	}
	var s := StudentData.new()
	s.id = 101
	s.student_name = "UjiIstirahat"
	s.personality = "Santai"
	s.energy = 50.0
	s.mood = 50.0
	var before_energy := s.energy
	var before_mood := s.mood
	var m := _manager_with([s])
	m.apply_daily_decay_all("Senin")
	assert_true(abs(_logged_delta(m, "Senin", s.student_name, "energy") - (s.energy - before_energy)) < _EPS,
		"the day summary's energy total must equal the energy the student actually moved")
	assert_true(abs(_logged_delta(m, "Senin", s.student_name, "mood") - (s.mood - before_mood)) < _EPS,
		"the day summary's mood total must equal the mood the student actually moved")
	GameState.day_schedules = original
	m.free()


func test_a_wirausaha_day_reports_the_movement_that_actually_happened() -> void:
	# Same double-log, other branch: the Wirausaha cost was logged as
	# "activity" AND folded into the "decay" line. Start at 80 so the
	# combined 4..6 decay plus the flat 10/6 cost cannot reach zero.
	var original: Dictionary = GameState.day_schedules
	GameState.pending_earnings.clear()
	GameState.day_schedules = {
		102: {"Senin": {"category": "Wirausaha", "mood_cost": 6, "energy_cost": 10}},
	}
	var s := StudentData.new()
	s.id = 102
	s.student_name = "UjiWirausaha"
	s.personality = "Santai"
	s.energy = 80.0
	s.mood = 80.0
	var before_energy := s.energy
	var before_mood := s.mood
	var m := _manager_with([s])
	m.apply_daily_decay_all("Senin")
	assert_true(abs(_logged_delta(m, "Senin", s.student_name, "energy") - (s.energy - before_energy)) < _EPS,
		"a Wirausaha day's reported energy must equal the energy actually spent")
	assert_true(abs(_logged_delta(m, "Senin", s.student_name, "mood") - (s.mood - before_mood)) < _EPS,
		"a Wirausaha day's reported mood must equal the mood actually spent")
	GameState.pending_earnings.clear()
	GameState.day_schedules = original
	m.free()


func test_a_study_day_still_reports_its_movement_exactly_once() -> void:
	# The study branch was already correct. It is asserted here so the fix
	# to the other two branches cannot silently break it.
	var original: Dictionary = GameState.day_schedules
	GameState.day_schedules = {
		103: {"Senin": {"category": "Akademis", "mood_cost": 0, "energy_cost": 0}},
	}
	var s := StudentData.new()
	s.id = 103
	s.student_name = "UjiBelajar"
	s.personality = "Santai"
	s.specialty_category = "Akademis"
	s.energy = 80.0
	s.mood = 80.0
	s.akademis = 40.0
	var before_energy := s.energy
	var before_mood := s.mood
	var before_akademis := s.akademis
	var m := _manager_with([s])
	m.apply_daily_decay_all("Senin")
	assert_true(abs(_logged_delta(m, "Senin", s.student_name, "energy") - (s.energy - before_energy)) < _EPS,
		"a study day's reported energy must equal the energy actually spent")
	assert_true(abs(_logged_delta(m, "Senin", s.student_name, "mood") - (s.mood - before_mood)) < _EPS,
		"a study day's reported mood must equal the mood actually spent")
	assert_true(abs(_logged_delta(m, "Senin", s.student_name, "akademis") - (s.akademis - before_akademis)) < _EPS,
		"a study day's reported akademis must equal the akademis actually gained")
	GameState.day_schedules = original
	m.free()
```

- [ ] **Step 2: Run the tests and verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="stat_log")
```

Expected: `test_a_rest_day_...` and `test_a_wirausaha_day_...` FAIL ("the day
summary's energy total must equal…"). `test_a_study_day_...` already PASSES —
that branch was never broken.

- [ ] **Step 3: Write the implementation**

In `Scripts/SchoolSimulation/StudentManager.gd`:

**3a.** Cancel the Wirausaha cost back out of the folded totals. Replace lines
143-144:

```gdscript
			log_stat_change(day_name, student.student_name, "mood", -Balance.WIRAUSAHA_BIAYA_MOOD, "activity")
			log_stat_change(day_name, student.student_name, "energy", -Balance.WIRAUSAHA_BIAYA_ENERGI, "activity")
```

with:

```gdscript
			log_stat_change(day_name, student.student_name, "mood", -Balance.WIRAUSAHA_BIAYA_MOOD, "activity")
			log_stat_change(day_name, student.student_name, "energy", -Balance.WIRAUSAHA_BIAYA_ENERGI, "activity")
			# The two costs above are now the ONLY log lines carrying
			# them. Take them back out of the running totals so the
			# "decay" line below reports personality decay alone --
			# logging both is what made a Wirausaha day read double.
			mood_loss -= Balance.WIRAUSAHA_BIAYA_MOOD
			energy_loss -= Balance.WIRAUSAHA_BIAYA_ENERGI
```

> **The cancel is deliberate, not redundant.** `energy_loss` feeds two consumers
> with different needs: the log (wants decay only, since the activity has its own
> line) and `decay_results` (wants the folded total, because
> `SchoolDay._animate_embedded_decay_bars` reconstructs the morning value as
> `current_energy + energy_loss`). Leaving the `+=` on lines 140-141 intact and
> subtracting again here keeps `decay_results` correct while giving the log the
> unfolded number through `decay_res`, which those `+=`/`-=` never touch.

**3b.** Log the activity's own energy and mood movement in the study/rest
branch. Insert after line 160 (`mood_loss -= m_delta`):

```gdscript

			# The activity's own movement, as its own line. It is ALSO
			# folded into energy_loss/mood_loss above -- that folded
			# total is what decay_results reports to the embedded day
			# cards -- so the "decay" line below deliberately logs
			# decay_res's untouched values instead of the folded ones,
			# and this movement never reaches the summary twice.
			log_stat_change(day_name, student.student_name, "energy", e_delta, "activity")
			log_stat_change(day_name, student.student_name, "mood", m_delta, "activity")
```

**3c.** Log the pure personality decay, and delete the now-duplicate Istirahat
block. Replace lines 171-183:

```gdscript
		# Log decay
		log_stat_change(day_name, student.student_name, "energy", -energy_loss, "decay")
		log_stat_change(day_name, student.student_name, "mood", -mood_loss, "decay")
		# Log activity stat gain
		if category != "Istirahat" and category != "Wirausaha" and category != "":
			var act_cat_key = category.to_lower().replace(" ", "_")
			var stat_key_map = {"akademis": "akademis", "senibudaya": "seni_budaya", "olahraga": "olahraga"}
			var stat_k = stat_key_map.get(act_cat_key, "")
			if stat_k != "" and act_res.get("stat_delta", 0.0) != 0.0:
				log_stat_change(day_name, student.student_name, stat_k, act_res.get("stat_delta", 0.0), "activity")
		elif category == "Istirahat":
			log_stat_change(day_name, student.student_name, "energy", act_res.get("energy_delta", 0.0), "activity")
			log_stat_change(day_name, student.student_name, "mood", act_res.get("mood_delta", 0.0), "activity")
```

with:

```gdscript
		# Log the personality decay ALONE. energy_loss/mood_loss carry the
		# activity's share too (decay_results needs them to), and that
		# share is already on the log as its own "activity" line above --
		# logging the folded total here as well is what made every rest
		# and Wirausaha day read roughly double on the summary card.
		log_stat_change(day_name, student.student_name, "energy", -decay_res["energy_loss"], "decay")
		log_stat_change(day_name, student.student_name, "mood", -decay_res["mood_loss"], "decay")
		# Log activity stat gain
		if category != "Istirahat" and category != "Wirausaha" and category != "":
			var act_cat_key = category.to_lower().replace(" ", "_")
			var stat_key_map = {"akademis": "akademis", "senibudaya": "seni_budaya", "olahraga": "olahraga"}
			var stat_k = stat_key_map.get(act_cat_key, "")
			if stat_k != "" and act_res.get("stat_delta", 0.0) != 0.0:
				log_stat_change(day_name, student.student_name, stat_k, act_res.get("stat_delta", 0.0), "activity")
```

A student who auto-takes "Izin" needs no special case: `apply_jadwal_activity`
flips its own local category to `Istirahat` and returns `stat_delta == 0.0`,
which `log_stat_change` discards on its zero guard, while its
`energy_delta`/`mood_delta` still reach the log through 3b.

- [ ] **Step 4: Run the tests and verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="stat_log")
test_run(suite="wirausaha")
test_run(suite="day_summary")
```

Expected: all three suites PASS. `wirausaha` and `day_summary` are run because
they are the two existing suites that touch this function and this log.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd tests/test_stat_log.gd && git commit -m "fix(school-day): stop double-logging rest and Wirausaha needs movement"
```

---

### Task 4: A minigame only moves the students who were scheduled for it

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd:59-87`
- Test: `tests/test_stat_log.gd`

**Interfaces:**
- Consumes: `GameState.day_schedules` (`Dictionary`,
  `day_schedules[student_id][day_name] = {category, mood_cost, energy_cost}`);
  `StudentData.apply_minigame_result(category, won, score, max_score) ->
  Dictionary`; the helpers `_manager_with` and `_logged_delta` from Task 3.
- Produces: `StudentManager.participants_for(day_name: String, category:
  String) -> Array[StudentData]` — the students a day's minigame may move.
  No other task consumes it; `SchoolDay.gd` is untouched.

**The rule, as decided:** the minigame moves the students whose schedule for that
day *is* the minigame's category. If nobody is scheduled for it, it moves the
whole class — which is what a debug scene-jump straight into SchoolDay looks
like, since `day_schedules` is empty there and a minigame that moved nobody
would render that jump useless. In normal play (Tasks 1-2 guarantee a scheduled
roster) the fallback never fires. Schedule categories are normalised the same way
the rest of the file does it: `Akademik`→`Akademis`, `DayOff`→`Istirahat`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_stat_log.gd`:

```gdscript
func test_a_minigame_only_moves_the_students_scheduled_for_it() -> void:
	var original: Dictionary = GameState.day_schedules
	GameState.day_schedules = {
		201: {"Senin": {"category": "Olahraga", "mood_cost": 0, "energy_cost": 0}},
		202: {"Senin": {"category": "Akademis", "mood_cost": 0, "energy_cost": 0}},
	}
	var runner := StudentData.new()
	runner.id = 201
	runner.student_name = "Pelari"
	runner.olahraga = 40.0
	var reader := StudentData.new()
	reader.id = 202
	reader.student_name = "Pembaca"
	reader.olahraga = 40.0
	var m := _manager_with([runner, reader])
	m.record_minigame_result("Senin", "Olahraga", "Uji", true, 10, 10)
	assert_gt(runner.olahraga, 40.0,
		"the student scheduled for Olahraga must gain from an Olahraga minigame")
	assert_eq(reader.olahraga, 40.0,
		"a student scheduled for Akademis must not gain olahraga from an Olahraga minigame")
	GameState.day_schedules = original
	m.free()


func test_a_resting_student_pays_no_minigame_cost() -> void:
	var original: Dictionary = GameState.day_schedules
	GameState.day_schedules = {
		203: {"Senin": {"category": "Olahraga", "mood_cost": 0, "energy_cost": 0}},
		204: {"Senin": {"category": "Istirahat", "mood_cost": 0, "energy_cost": 0}},
	}
	var runner := StudentData.new()
	runner.id = 203
	runner.student_name = "PelariDua"
	runner.energy = 80.0
	var rester := StudentData.new()
	rester.id = 204
	rester.student_name = "Peristirahat"
	rester.energy = 80.0
	rester.olahraga = 40.0
	var m := _manager_with([runner, rester])
	m.record_minigame_result("Senin", "Olahraga", "Uji", true, 10, 10)
	assert_eq(rester.energy, 80.0,
		"a resting student pays none of the minigame's energy cost")
	assert_eq(rester.olahraga, 40.0,
		"a resting student gains nothing from a minigame they sat out")
	assert_true(abs(_logged_delta(m, "Senin", rester.student_name, "olahraga")) < _EPS,
		"a resting student must not appear in the day summary's minigame lines")
	GameState.day_schedules = original
	m.free()


func test_an_unscheduled_class_still_plays_the_minigame() -> void:
	# The debug menu's Scenes tab teleports straight into SchoolDay with no
	# schedule at all. Restricting a minigame to its scheduled students
	# would make that jump show a flat, empty day, so an unscheduled class
	# keeps the old whole-class behaviour.
	var original: Dictionary = GameState.day_schedules
	GameState.day_schedules = {}
	var a := StudentData.new()
	a.id = 205
	a.student_name = "TanpaJadwalSatu"
	a.olahraga = 40.0
	var b := StudentData.new()
	b.id = 206
	b.student_name = "TanpaJadwalDua"
	b.olahraga = 40.0
	var m := _manager_with([a, b])
	m.record_minigame_result("Senin", "Olahraga", "Uji", true, 10, 10)
	assert_gt(a.olahraga, 40.0, "an unscheduled class still plays the minigame")
	assert_gt(b.olahraga, 40.0, "an unscheduled class plays it as a whole class")
	GameState.day_schedules = original
	m.free()
```

- [ ] **Step 2: Run the tests and verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="stat_log")
```

Expected: `test_a_minigame_only_moves_the_students_scheduled_for_it` and
`test_a_resting_student_pays_no_minigame_cost` FAIL. Task 3's three tests and
`test_an_unscheduled_class_still_plays_the_minigame` PASS (the last one asserts
today's behaviour, which the fallback preserves).

- [ ] **Step 3: Write the implementation**

In `Scripts/SchoolSimulation/StudentManager.gd`, insert directly above
`func record_minigame_result` (line 59):

```gdscript
## Who a day's minigame is allowed to move: the students whose schedule
## for that day IS the minigame's category. SchoolDay already picks the
## category by weighting how many students signed up for each (see
## GameState.get_jadwal_for_day), so the participants are exactly the
## students that weighting counted.
##
## Falls back to the whole class when nobody is scheduled for it, which
## is what the debug menu's scene jump into SchoolDay looks like --
## day_schedules is empty there and a minigame that moved nobody would
## make the jump show a flat, empty day. In normal play the roster is
## always scheduled, so the fallback never fires.
func participants_for(day_name: String, category: String) -> Array[StudentData]:
	var scheduled: Array[StudentData] = []
	for student in students:
		if student.id == 0 or not GameState.day_schedules.has(student.id):
			continue
		var cat := String(GameState.day_schedules[student.id].get(day_name, {}).get("category", ""))
		if cat == "Akademik": cat = "Akademis"
		elif cat == "DayOff": cat = "Istirahat"
		if cat == category:
			scheduled.append(student)
	if scheduled.is_empty():
		return students
	return scheduled

```

Then change line 61 from:

```gdscript
	for student in students:
```

to:

```gdscript
	for student in participants_for(day_name, category):
```

`minigame_history`'s `results` entry now lists only the participants, which is
what `ResultCheckup._create_history_item` reads for its per-day log line —
correct, and no change is needed there.

- [ ] **Step 4: Run the tests and verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="stat_log")
test_run(suite="school_day")
test_run(suite="result_checkup")
```

Expected: all three PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd tests/test_stat_log.gd && git commit -m "fix(school-day): apply a minigame only to the students scheduled for it"
```

---

### Task 5: A fabricated roster says so out loud

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd:212-219`
- Test: `tests/test_stat_log.gd`

**Interfaces:**
- Consumes: `GameState.approved_students`;
  `GameState.convert_to_student_data_array() -> Array[StudentData]`;
  `StudentManager.initialize_students()`.
- Produces: nothing. Terminal task.

**Why this is still worth doing after Tasks 1-2:** the fallback is what turned an
empty roster into Budi / Ani / Cici / Doni — the exact symptom reported. Tasks
1-2 close the normal path into it, but the debug menu's scene jump straight to
SchoolDay still reaches it legitimately. A `push_warning` makes that state
self-diagnosing instead of silently plausible, so if the symptom ever recurs the
editor log names the cause on the first run. The fallback roster itself is left
alone — it is what makes the debug jump simulate anything at all.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_stat_log.gd`:

```gdscript
func test_an_empty_roster_announces_its_placeholder_students() -> void:
	# Budi/Ani/Cici/Doni are placeholders, not a roster anyone picked, and
	# they carry the default id 0 -- which every schedule lookup in this
	# file skips. Seeing them in a summary means the selection step was
	# missed, so the fallback has to say so rather than look like a class.
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/StudentManager.gd")
	var head := src.find("func initialize_from_gamestate()")
	assert_gt(head, -1, "initialize_from_gamestate must still exist")
	var tail := src.find("func apply_jadwal_effects_all", head)
	assert_gt(tail, head, "the next function must still follow it")
	var body := src.substr(head, tail - head)
	assert_true(body.contains("push_warning("),
		"falling back to placeholder students must warn, not pass silently")
```

- [ ] **Step 2: Run the test and verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="stat_log")
```

Expected: `test_an_empty_roster_announces_its_placeholder_students` FAILS with
"falling back to placeholder students must warn, not pass silently".

- [ ] **Step 3: Write the implementation**

In `Scripts/SchoolSimulation/StudentManager.gd`, replace lines 212-219:

```gdscript
func initialize_from_gamestate() -> void:
	students.clear()
	minigame_history.clear()
	daily_stat_log.clear()
	if GameState.approved_students.is_empty():
		initialize_students()
	else:
		students = GameState.convert_to_student_data_array()
```

with:

```gdscript
## The roster the week simulates, taken from the player's own selection.
##
## The empty-roster fallback builds four PLACEHOLDER students
## (Budi/Ani/Cici/Doni) carrying the default id 0, which every schedule
## lookup in this file skips -- so they all silently rest, and the summary
## shows names nobody picked against a schedule nobody set. Ordinary play
## can no longer reach it: the Lobby withholds Atur Jadwal until a roster
## exists (loby.gd, the post-tutorial branch). It survives for the debug
## menu's scene jump straight into SchoolDay, which has no roster by
## design -- and it warns, so that state is never mistaken for a class.
func initialize_from_gamestate() -> void:
	students.clear()
	minigame_history.clear()
	daily_stat_log.clear()
	if GameState.approved_students.is_empty():
		push_warning("StudentManager: no approved_students -- simulating four placeholder students with no schedule. Expected only after a debug scene jump; in normal play the roster is picked on StudentCard.")
		initialize_students()
	else:
		students = GameState.convert_to_student_data_array()
```

- [ ] **Step 4: Run the tests and verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="stat_log")
```

Expected: PASS — all seven tests in the suite.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd tests/test_stat_log.gd && git commit -m "fix(school-day): warn when the simulation falls back to placeholder students"
```

---

### Task 6: Full-suite regression and a live play-through

**Files:**
- Modify: `CLAUDE.md` (the "Current work" section)
- Test: every suite

**Interfaces:**
- Consumes: everything Tasks 1-5 produced.
- Produces: nothing. Terminal task.

- [ ] **Step 1: Run every suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: 30 suites (29 existing + `stat_log`), 0 failures. The test count rises
from 425 to 434 — one new test each in `student_card` and `lobby`, seven new in
`stat_log`. If a suite fails, open `Scenes/Splashscreen/Splashscreen.tscn`
before trusting it: some suites assume the main scene is open, and `test_run`
returns a `scene_warning` when it is not.

- [ ] **Step 2: Verify the selection gate in the running game**

Use `project_run`, then — without touching the debug overlay's **⚡ Seed
Playtest State** button, which auto-approves a roster and would mask the very
thing under test:

1. MainMenu → Play → skip the CutScene → land in the Lobby.
2. Confirm **"Pilih Murid" is visible and "Atur Jadwal" is not.**
3. Press Pilih Murid → StudentCard opens with the first card shown, the page
   counter reading `1/6`, and the right-hand page arrow live.
4. Approve two students (grade 7 → `MAX_APPROVE == 2`); the Belajar button
   appears on the second approval.
5. Press Belajar → back in the Lobby, **"Atur Jadwal" is now visible and
   "Pilih Murid" is not.**

Screenshot steps 2 and 5 with `editor_screenshot` — these are the whole point of
Tasks 1-2 and the only genuinely visual checks in this plan.

When clicking, note the two quirks from CLAUDE.md: send a `motion` event to the
target before the `button` press, and rescale coordinates —
`window_x = global_x * original_width / 1080`, deriving the factor from the
`original_width` that `editor_screenshot` reports, and reading the target's own
`global_rect` rather than eyeballing the screenshot.

- [ ] **Step 3: Verify the summary numbers against the schedule**

Continue the same run: Atur Jadwal → give one student `Akademis` every day and
the other `Istirahat` every day → StudentList → SchoolDay.

On each day's summary popup confirm:
- **Both cards carry the names you picked** — not Budi/Ani/Cici/Doni.
- The Akademis student's card shows an akademis gain; the Istirahat student's
  shows none.
- The Istirahat student's energy/mood numbers read as one day's recovery (order
  of +15..+25 net), not double it.
- If a minigame fires, only the student scheduled for that subject moves.

Then let the week finish and confirm ResultCheckup shows the same two names, and
that each stat reads `+<the week's gain>/<target>`.

Check `logs_read(source="game")` for the Task 5 `push_warning`: it must **not**
appear on this run. If it does, the roster never made it to `GameState` and
Tasks 1-2 did not take.

- [ ] **Step 4: Update the project guide**

In `CLAUDE.md`, append to the end of the **Current work** section:

```markdown
Roster selection is mandatory on every fresh game, tutorial or not: the Lobby's
post-tutorial branch keeps "Pilih Murid" on screen and withholds "Atur Jadwal"
until `GameState.approved_students` is non-empty, and StudentCard's own
tutorial-bypass path now calls `_show_page()` so the screen opens armed. The
day/week summaries were corrected alongside it — rest and Wirausaha days no
longer double-log their needs movement, and a minigame only moves the students
scheduled for its category (falling back to the whole class only when nothing is
scheduled, i.e. after a debug scene jump). See
`docs/superpowers/plans/2026-08-31-forced-selection-and-summary-accuracy.md`.
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md && git commit -m "docs: record the forced-selection and summary-accuracy fixes"
```

---

## Notes for the executor

**Do not "fix" these on the way past** — they are known, benign, and out of
scope:

- `_on_belajar_pressed` appends `student_data_list[i]` by reference rather than
  `.duplicate()` (`student_card.gd`). Harmless: re-entering the screen replaces
  each entry with `approved_s.duplicate()` anyway.
- `_on_belajar_pressed`'s auto-fill (first N students when nothing is approved)
  is now unreachable through the button, which only appears at
  `approved_count >= MAX_APPROVE`. Leave it as a safety net.
- `DaySummaryPopup` matches students by **name**, not id. The six roster names
  are unique, so it holds.
- The post-tutorial Lobby still hides "Pilih Murid" once a roster exists, so
  StudentCard cannot be reopened from the hub. That is pre-existing behaviour
  and Task 2 deliberately preserves it for the non-empty case.
- `DebugManager.DEFAULT_STUDENTS` duplicates `student_card.gd`'s roster and
  approves four students regardless of grade. It is a debug cheat; leave it.
- `apply_daily_decay_all`'s `"decay"` source label carried activity costs before
  this plan and will carry only decay after it. No screen reads the `source`
  field — `DaySummaryStudentRow` sums across all sources — so the relabelling is
  for the next reader of the log, not for the UI.
