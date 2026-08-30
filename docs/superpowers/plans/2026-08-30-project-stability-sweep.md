# Project Stability Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the eight defects found in the 2026-08-30 project sweep — an unbounded coroutine recursion that can overflow the stack, a log flood that hides every other diagnostic, two tests that lie about what they verified, a suite that dirties a committed asset, 14 stale resource UIDs, leftover debug prints, and a stale project guide.

**Architecture:** Six independent fixes, ordered by severity and by what unblocks diagnosis. Tasks 1–2 are surgical edits to `Scripts/SchoolSimulation/SchoolDay.gd` (constant-depth day loop, correct node ownership). Task 3 repairs `tests/test_audio_director.gd` and adds one test seam to `Scripts/Audio/AudioDirector.gd`. Tasks 4–5 add a new repo-wide invariant suite, `tests/test_project_hygiene.gd`, that mechanically prevents the UID and debug-print classes from returning. Task 6 refreshes the two documents that mislead the next session. No gameplay behaviour, balance number, or visual changes anywhere in this plan.

**Tech Stack:** Godot 4.6.2-stable, GDScript, `McpTestSuite` (`addons/godot_ai/testing/test_suite.gd`) run in-editor via the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-08-30-project-stability-sweep-findings.md`

## Global Constraints

- **Godot 4.6.2-stable.** Do not use APIs added after 4.6.
- **No test may be a coroutine.** The runner does `suite.call(name)` without awaiting; an `await` silently abandons the test mid-way. It reports "0 assertions" if the `await` precedes every assertion, and — worse — reports **PASS** if any assertion ran before it.
- **Every test suite must be `@tool`**, or the runner reports the class abstract/broken.
- **Rescan before running tests.** After editing any `.gd`, call `filesystem_manage(op="scan")` before `test_run`, or the runner serves a stale copy.
- **Open the main scene before trusting a failure.** Several suites assume `res://Scenes/Splashscreen/Splashscreen.tscn` is the edited scene; `test_run` returns a `scene_warning` when it is not.
- **Baseline to beat:** 28 suites, 421 tests, 420 passed, 1 failed. After Task 3 the target is **0 failed**; every later task must keep it at 0 while the total rises.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Layout-only constant overrides (`separation`, `margin_*`) are the sole exception. No task here should need either.
- **Commits: Conventional Commits with a scope**, e.g. `fix(school-day): run the week as a loop`.
- **Game-facing identifiers and UI text are Indonesian; engine and systems code is English.** Match the surrounding file.
- **Do not add persistence to `GameState`.** The game is session-scoped by design.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `Scripts/SchoolSimulation/SchoolDay.gd` | Modify (T1, T2) | Split `_run_day` into a constant-depth loop plus a single-day body; clear `owner` before re-parenting a pill label |
| `tests/test_school_day.gd` | Modify (T1, T2) | Source-scan guards for the loop shape and the ownership fix |
| `Scripts/Audio/AudioDirector.gd` | Modify (T3) | Add `has_pending_volume_save()` test seam |
| `tests/test_audio_director.gd` | Modify (T3) | De-coroutine two tests; snapshot/restore global bus state around every test |
| `Scenes/AturJadwal/atur_jadwal.tscn` | Modify (T4) | Repair 6 stale UIDs |
| `Scenes/CutScene/cut_scene.tscn` | Modify (T4) | Repair 1 stale UID |
| `Scenes/EndGame/SemesterEnd.tscn` | Modify (T4) | Repair 4 stale UIDs |
| `Scenes/Loading/loading.tscn` | Modify (T4) | Repair 1 stale UID |
| `Scenes/StudentList/student_list.tscn` | Modify (T4) | Repair 2 stale UIDs |
| `tests/test_project_hygiene.gd` | **Create** (T4, T5) | Repo-wide invariants owned by no single screen: every scene UID resolves to its own asset; no `DEBUG` prints ship |
| `Scripts/AturJadwal/atur_jadwal.gd` | Modify (T5) | Delete 4 leftover `DEBUG` prints |
| `Scripts/StudentCard/student_card.gd` | Modify (T5) | Delete 1 leftover `DEBUG` print |
| `CLAUDE.md` | Modify (T6) | Correct four stale claims |
| `docs/superpowers/baseline/known-errors.md` | Modify (T6) | Record that the UID class is fixed and now guarded |

---

## Task 1: Run the school week as a loop, not recursion

Fixes **F1**. `_run_day()` is a coroutine that tail-calls itself at line 359, so
every day nests a stack frame that never unwinds. The fix keeps the ~120-line day
body exactly where it is — it is renamed, not re-indented — and gives it a
driver loop above it. Stack depth becomes a constant 2 regardless of how many
days run.

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:232-242` (function head), `:358-359` (function tail)
- Test: `tests/test_school_day.gd`

**Interfaces:**
- Consumes: `start_simulation()` at `SchoolDay.gd:230` already calls `_run_day()`; that call site does not change.
- Produces: `_run_day() -> void` (unchanged name and signature, now a loop driver) and a new private `_run_single_day() -> void` holding the former body. Both are coroutines. No other file references either.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_school_day.gd`, after `test_week_end_routing_is_unchanged`:

```gdscript
func test_the_week_advances_by_loop_not_by_self_recursion() -> void:
	# _run_day() used to end with `current_day += 1; _run_day()`. Because it
	# awaits eight times, each recursive call nested a frame that never
	# unwound -- depth grew with every day simulated, and a long session was
	# observed parked in a "Stack overflow (stack size: 1024)" break.
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("while not is_skipped and current_day < DAYS.size():"),
		"the week must advance in a loop so stack depth stays constant")
	assert_true(src.contains("await _run_single_day()"),
		"the loop must await exactly one day per iteration")
	assert_true(src.contains("func _run_single_day() -> void:"),
		"the per-day body must live in its own function")
	# Exactly two occurrences may remain: the `func _run_day() -> void:`
	# definition, and the single call from start_simulation().
	assert_eq(src.count("_run_day()"), 2,
		"_run_day() must be defined once and called once (from start_simulation); any third occurrence is a reintroduced self-call")
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="school_day", test_name="test_the_week_advances_by_loop_not_by_self_recursion")
```

Expected: FAIL — the source contains neither `while not is_skipped …` nor
`_run_single_day`, and `_run_day()` currently occurs 3 times.

- [ ] **Step 3: Replace the function head with a driver loop**

In `Scripts/SchoolSimulation/SchoolDay.gd`, replace lines 232–242, which
currently read:

```gdscript
# ─────────────────────────────────────────────────────────────────────────────
# Runs one full day: shows the day screen, fills the progress bar,
# triggers an optional minigame or event, then awaits click to continue to next day.
func _run_day() -> void:
	if is_skipped:
		return
	if current_day >= DAYS.size():
		_on_week_complete()
		return

	var day_name = DAYS[current_day]
```

with:

```gdscript
# ─────────────────────────────────────────────────────────────────────────────
# Drives the whole week. This must stay a loop: _run_single_day() awaits
# eight times, so calling it recursively (as this function used to) leaves
# every previous day's frame suspended on the stack. Depth then grows with
# the number of days simulated and eventually overflows. As a loop, depth is
# a constant 2 no matter how long the week runs.
func _run_day() -> void:
	while not is_skipped and current_day < DAYS.size():
		await _run_single_day()
		if is_skipped:
			return
		current_day += 1
	if not is_skipped:
		_on_week_complete()


# ─────────────────────────────────────────────────────────────────────────────
# Runs one full day: shows the day screen, fills the progress bar,
# triggers an optional minigame or event, then awaits click to continue.
# Returning early (every `if is_skipped: return` below) hands control back to
# the driver loop above, which re-checks is_skipped and stops.
func _run_single_day() -> void:
	var day_name = DAYS[current_day]
```

Leave every line from the `# ── Background color and pattern transitions ──`
comment onward exactly as it is — same indentation, same content.

Note the wording above avoids the literal text `_run_day()` inside this new
comment on purpose: Step 1's test counts occurrences of that exact substring
in the file to make sure no third call site sneaks back in, so an incidental
mention in a comment would make a correct implementation fail its own test.

- [ ] **Step 4: Delete the recursive tail**

At what are now the last two lines of `_run_single_day()`, delete:

```gdscript
	current_day += 1
	_run_day()
```

The function must now end with:

```gdscript
	var fade_out = create_tween()
	fade_out.tween_property(day_screen, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	if is_skipped:
		return
```

`current_day += 1` now lives in the driver loop; leaving it here too would
skip every other day.

- [ ] **Step 5: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="school_day")
```

Expected: the new test PASSES and every other `school_day` test still passes.

- [ ] **Step 6: Run the full suite**

```
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
test_run()
```

Expected: `failed: 1` — still only `audio_director::test_volumes_persist_across_a_fresh_director` (that is Task 3). `total` is 422.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_school_day.gd && git commit -m "fix(school-day): run the week as a loop instead of recursing per day"
```

---

## Task 2: Clear the pill label's owner before re-parenting it

Fixes **F2**. `_add_pill()` moves a Label that belongs to the instantiated
`DaySummaryPill.tscn` under a runtime-built `HBoxContainer`, and Godot warns on
every badge, every student, every day. In the observed session this single
warning caused `dropped_count: 2708` on the editor log buffer, destroying the
evidence for F1.

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:651-653`
- Test: `tests/test_school_day.gd`

**Interfaces:**
- Consumes: `_make_chip(text: String, tint: Color) -> PanelContainer` at
  `SchoolDay.gd:475`, which instantiates `res://Scenes/SchoolSimulation/DaySummaryPill.tscn`
  and whose returned chip has a child Label named `Text`.
- Produces: nothing new. `_add_pill` keeps its signature.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_school_day.gd`, directly after the Task 1 test:

```gdscript
func test_reparented_pill_label_has_its_owner_cleared() -> void:
	# _make_chip instantiates DaySummaryPill.tscn, so the "Text" Label carries
	# that scene's root as its owner. _add_pill re-parents it under a runtime
	# HBoxContainer (owner == null); without clearing owner first Godot warns
	# "will make owner 'DaySummaryPill' inconsistent" once per badge, per
	# student, per day -- enough to flood the log buffer and drop every other
	# diagnostic on this screen.
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("lbl.owner = null"),
		"_add_pill must clear the label's owner before re-parenting it")
	var clear_at := src.find("lbl.owner = null")
	var reparent_at := src.find("hbox.add_child(lbl)")
	assert_gt(reparent_at, clear_at,
		"the owner must be cleared BEFORE hbox.add_child(lbl), not after")
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="school_day", test_name="test_reparented_pill_label_has_its_owner_cleared")
```

Expected: FAIL — `lbl.owner = null` is not in the source, so `find` returns
`-1` and the first assertion fails.

- [ ] **Step 3: Write the minimal fix**

In `Scripts/SchoolSimulation/SchoolDay.gd`, replace:

```gdscript
	chip.remove_child(lbl)
	chip.add_child(hbox)
	hbox.add_child(tex_rect)
	hbox.add_child(lbl)
```

with:

```gdscript
	chip.remove_child(lbl)
	# lbl came from DaySummaryPill.tscn and still names that scene's root as
	# its owner. Re-parenting it under a runtime-built HBoxContainer (owner ==
	# null) makes the ownership inconsistent, and Godot warns every single
	# time -- per badge, per student, per day.
	lbl.owner = null
	chip.add_child(hbox)
	hbox.add_child(tex_rect)
	hbox.add_child(lbl)
```

- [ ] **Step 4: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="school_day")
```

Expected: PASS, all `school_day` tests green.

- [ ] **Step 5: Confirm the warning is actually gone in a live run**

This is the one fix in the plan whose whole point is runtime log output, so a
source scan alone does not prove it.

```
project_run()
```

In the running game: press `F1` (or tap the top-right corner 5 times) to open
the debug overlay → **General** tab → **⚡ Seed Playtest State** → **Scenes**
tab → teleport to **AturJadwal** → assign any activity to all five days →
**Mulai Minggu** → let one day play through its summary.

Then:

```
logs_read(source="game", count=40, include_details=true)
project_manage(op="stop")
```

Expected: **zero** lines containing `will make owner 'DaySummaryPill'
inconsistent`. Seeding is required because the seed does not fill
`day_schedules` — SchoolDay needs a pass through Atur Jadwal first.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_school_day.gd && git commit -m "fix(school-day): clear the pill label's owner before re-parenting it"
```

---

## Task 3: Stop the audio suite from lying and from dirtying a committed asset

Fixes **F3**, **F4**, and **F5** together — they are one defect wearing three
faces. Two tests `await`, so the runner abandons them; one therefore fails
loudly, the other passes while skipping its most important assertion; and
because both mutate the process-global `AudioServer` and neither reaches its own
cleanup, both leak into `Assets/Audio/default_bus_layout.tres`.

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd` (add one test seam after `get_volume_save_count()`, line 435)
- Modify: `tests/test_audio_director.gd:9-22` (setup/teardown), `:108-122`, `:127-144`
- Revert: `Assets/Audio/default_bus_layout.tres`

**Interfaces:**
- Consumes: `AudioDirector.set_bus_volume(bus: StringName, linear: float) -> void`,
  `get_bus_volume(bus: StringName) -> float`, `flush_volume_save() -> void`,
  `get_volume_save_count() -> int` — all already public.
- Produces: `AudioDirector.has_pending_volume_save() -> bool` — new public test
  seam, returns whether a debounced save is still scheduled. Used only by
  `tests/test_audio_director.gd`.

- [ ] **Step 1: Write the failing test seam usage**

In `tests/test_audio_director.gd`, replace `test_rapid_volume_changes_do_not_write_once_per_change`
entirely with the non-coroutine version:

```gdscript
func test_rapid_volume_changes_do_not_write_once_per_change() -> void:
	# Dragging a slider fires value_changed on every pixel. Writing the
	# config file that often stutters on mobile storage.
	var before: int = _director.get_volume_save_count()
	for i in range(50):
		_director.set_bus_volume(&"SFX", float(i) / 50.0)
	var immediately_after: int = _director.get_volume_save_count()
	assert_eq(immediately_after - before, 0,
		"50 rapid changes must coalesce behind the debounce timer, not write synchronously; got %d saves"
			% (immediately_after - before))

	# The coalesced write must be genuinely SCHEDULED, not silently dropped by
	# a stray early return. This used to be checked by awaiting out the 0.4s
	# window -- but the runner calls suite.call(name) without awaiting, so that
	# assertion never actually ran while the test still reported PASS.
	# Asserting the pending timer exists, then flushing it, proves the same
	# thing with no coroutine.
	assert_true(_director.has_pending_volume_save(),
		"the 50 changes must leave exactly one save pending, not zero")
	_director.flush_volume_save()
	var after: int = _director.get_volume_save_count()
	assert_eq(after - before, 1,
		"50 rapid changes must coalesce into exactly 1 save, got %d" % (after - before))
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="audio_director", test_name="test_rapid_volume_changes_do_not_write_once_per_change")
```

Expected: FAIL with `Nonexistent function 'has_pending_volume_save' in base
'Node'`.

- [ ] **Step 3: Add the test seam**

In `Scripts/Audio/AudioDirector.gd`, directly after `get_volume_save_count()`
(which ends at line 436), add:

```gdscript


## True while a debounced volume save is still scheduled. Test hook: lets a
## non-coroutine test prove the write was queued rather than silently dropped,
## without waiting out the 0.4s debounce window.
func has_pending_volume_save() -> bool:
	return _save_timer != null
```

- [ ] **Step 4: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="audio_director", test_name="test_rapid_volume_changes_do_not_write_once_per_change")
```

Expected: PASS with 3 assertions.

- [ ] **Step 5: De-coroutine the persistence test**

In `tests/test_audio_director.gd`, replace `test_volumes_persist_across_a_fresh_director`
entirely with:

```gdscript
func test_volumes_persist_across_a_fresh_director() -> void:
	# The relaunch requirement: what the player set must come back.
	# No await here -- flush_volume_save() writes synchronously, and the runner
	# calls suite.call(name) without awaiting, so a coroutine would be
	# abandoned at its first await and score "0 assertions".
	_director.set_bus_volume(&"BGM", 0.42)
	_director.flush_volume_save()

	var scene: PackedScene = load("res://Scenes/Audio/audio_director.tscn")
	var second: Node = scene.instantiate()
	Engine.get_main_loop().root.add_child(second)
	track(second)
	assert_true(absf(second.get_bus_volume(&"BGM") - 0.42) <= 0.01,
		"a freshly loaded director must restore the saved BGM volume")

	# Restore so this test does not leave user://audio.cfg at 0.42. This line
	# now actually runs; before the await removal it never did.
	second.set_bus_volume(&"BGM", 1.0)
	second.flush_volume_save()
```

- [ ] **Step 6: Make the whole suite incapable of dirtying the bus layout**

Per-test cleanup is not enough: a test that fails partway never reaches its own
restore. In `tests/test_audio_director.gd`, replace lines 7–22 — currently:

```gdscript
var _director: Node


func setup() -> void:
	# Instantiate a fresh copy rather than poking the live autoload, so
	# volume changes in these tests do not leak into the running game.
	var scene: PackedScene = load("res://Scenes/Audio/audio_director.tscn")
	_director = scene.instantiate()
	Engine.get_main_loop().root.add_child(_director)
	track(_director)


func teardown() -> void:
	if is_instance_valid(_director):
		_director.queue_free()
	_director = null
```

with:

```gdscript
const _MIXER_BUSES := ["Master", "BGM", "SFX"]

var _director: Node
var _saved_bus_state: Array[Dictionary] = []


func setup() -> void:
	# AudioServer buses are process-GLOBAL. Instantiating a fresh director does
	# NOT isolate anything: set_bus_volume() writes straight to AudioServer, so
	# anything a test sets leaks into the editor's live mixer, and Godot then
	# writes that back into the committed Assets/Audio/default_bus_layout.tres.
	# Snapshotting here and restoring in teardown is the only placement that
	# also covers a test which fails or is abandoned partway through.
	_saved_bus_state.clear()
	for bus in _MIXER_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			_saved_bus_state.append({
				"idx": idx,
				"db": AudioServer.get_bus_volume_db(idx),
				"mute": AudioServer.is_bus_mute(idx),
			})

	var scene: PackedScene = load("res://Scenes/Audio/audio_director.tscn")
	_director = scene.instantiate()
	Engine.get_main_loop().root.add_child(_director)
	track(_director)


func teardown() -> void:
	if is_instance_valid(_director):
		_director.queue_free()
	_director = null

	for state in _saved_bus_state:
		AudioServer.set_bus_volume_db(state["idx"], state["db"])
		AudioServer.set_bus_mute(state["idx"], state["mute"])
	_saved_bus_state.clear()
```

- [ ] **Step 7: Revert the asset the old tests dirtied**

```bash
git checkout -- Assets/Audio/default_bus_layout.tres && git status --short Assets/Audio/
```

Expected: no output — the file is clean.

- [ ] **Step 8: Run the full suite and prove the asset stays clean**

```
filesystem_manage(op="scan")
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
test_run()
```

Expected: **`failed: 0`**, `total: 423` (Task 3 rewrites two existing tests
rather than adding any). Then:

```bash
git status --short Assets/Audio/
```

Expected: still no output. This is the assertion that matters — before this
task, that command printed `M Assets/Audio/default_bus_layout.tres` after every
single run.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd && git commit -m "fix(audio): de-coroutine the director tests and stop them leaking bus state"
```

---

## Task 4: Repair 14 stale scene UIDs and guard against new ones

Fixes **F6**. Every referenced asset exists; only the UID recorded in the
`.tscn` is wrong, so Godot falls back to the text path and logs a warning. The
repair is mechanical. The guard test is the durable part — it derives truth from
`ResourceUID` rather than from a hand-maintained list, so it catches the next
one too.

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn`, `Scenes/CutScene/cut_scene.tscn`, `Scenes/EndGame/SemesterEnd.tscn`, `Scenes/Loading/loading.tscn`, `Scenes/StudentList/student_list.tscn`
- Create: `tests/test_project_hygiene.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `tests/test_project_hygiene.gd` with `suite_name() -> "project_hygiene"`
  and two private helpers Task 5 also uses:
  `_attr(line: String, key: String) -> String` (reads `key="value"` out of a
  `.tscn` header line) and `_all_files_under(root: String, suffix: String) -> PackedStringArray`
  (recursive `res://` walk).

- [ ] **Step 1: Write the failing test**

Create `tests/test_project_hygiene.gd`:

```gdscript
@tool
extends McpTestSuite

## Repo-wide invariants that no single screen's suite owns.
##
## Both tests here derive truth from the engine or the filesystem rather than
## from a hand-maintained list, so they keep working as scenes and scripts are
## added. Neither instantiates anything, so both are cheap and neither needs
## the main scene open.
##
## This suite must be @tool or the runner reports the class abstract/broken,
## and no test here may be a coroutine -- the runner calls suite.call(name)
## without awaiting.

func suite_name() -> String:
	return "project_hygiene"


## Read a `key="value"` attribute out of a .tscn header line. Returns "" when
## the key is absent, which is normal: ext_resource lines written before UIDs
## existed carry only a path.
func _attr(line: String, key: String) -> String:
	var needle := key + "=\""
	var start := line.find(needle)
	if start == -1:
		return ""
	start += needle.length()
	var end := line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


## Every res:// file under `root` whose name ends with `suffix`.
func _all_files_under(root: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(suffix):
				out.append(dir.path_join(f))
	return out


func test_every_scene_ext_resource_uid_resolves_to_its_own_asset() -> void:
	# A wrong UID is only a warning -- Godot falls back to the text path and
	# the scene still loads -- but the warnings are per-load and they crowd out
	# real diagnostics. One wrong UID for paper.png had been copy-pasted into
	# three separate scenes before this test existed.
	var offenders: Array[String] = []
	for scene_path in _all_files_under("res://Scenes", ".tscn"):
		var text := FileAccess.get_file_as_string(scene_path)
		for line in text.split("\n"):
			if not line.begins_with("[ext_resource "):
				continue
			var uid_text := _attr(line, "uid")
			var res_path := _attr(line, "path")
			if uid_text == "" or res_path == "":
				continue
			var id := ResourceUID.text_to_id(uid_text)
			if id == -1 or not ResourceUID.has_id(id):
				offenders.append("%s: %s is not a known UID (%s)"
					% [scene_path, uid_text, res_path])
			elif ResourceUID.get_id_path(id) != res_path:
				offenders.append("%s: %s resolves to %s, but the line claims %s"
					% [scene_path, uid_text, ResourceUID.get_id_path(id), res_path])
	assert_eq(offenders.size(), 0,
		"every ext_resource UID must resolve to the asset on its own line; offenders: "
			+ ", ".join(offenders))
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="project_hygiene")
```

Expected: FAIL, listing 14 offenders across the five scene files.

- [ ] **Step 3: Repair the UIDs**

Each replacement is `old` → `new` on the named line. Apply all 14:

```bash
cd "C:/Users/ASUS/Downloads/KejarTestAlphaVer2.15/new-game-project"
sed -i 's|uid://dvkb3glcg53su|uid://bmxugmsumo04o|; s|uid://0c5vps0sx30f|uid://dbkqgaqqwkp57|; s|uid://0ycjsvqdwjf3|uid://cqc6snupncqgd|; s|uid://4slit8im18tb|uid://6rhjvqlmehwq|; s|uid://bhanm4qbpra2a|uid://dlyxcrhuswotn|; s|uid://cuih86con4sr1|uid://c8uw72nl2167r|' Scenes/AturJadwal/atur_jadwal.tscn
sed -i 's|uid://f0niudwtemxb|uid://cfe2yal5hh4dl|' Scenes/CutScene/cut_scene.tscn
sed -i 's|uid://bhanm4qbpra2a|uid://dlyxcrhuswotn|; s|uid://b6p4x47c2s0gq|uid://b0ah0m8tx4h7q|; s|uid://cye75x61s7rge|uid://cxym6c466l7q8|; s|uid://chfshk4b7u2w|uid://cj4co2v2kmqrg|' Scenes/EndGame/SemesterEnd.tscn
sed -i 's|uid://cwmltvrg3rr1t|uid://b1l1tgslf2wkw|' Scenes/Loading/loading.tscn
sed -i 's|uid://c7gmkcle3uv8o|uid://d2cvc7nosdip2|; s|uid://bhanm4qbpra2a|uid://dlyxcrhuswotn|' Scenes/StudentList/student_list.tscn
git diff --stat -- Scenes/
```

Expected: five files changed, 14 lines changed in total (6 + 1 + 4 + 1 + 2).

- [ ] **Step 4: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="project_hygiene")
```

Expected: PASS with 1 assertion and an empty offender list.

- [ ] **Step 5: Confirm the scenes still load and the warnings are gone**

```
scene_open(path="res://Scenes/AturJadwal/atur_jadwal.tscn", force_reload=true)
scene_open(path="res://Scenes/EndGame/SemesterEnd.tscn", force_reload=true)
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
logs_read(source="editor", count=30, include_details=true)
```

Expected: both scenes open (`switched: true`) and no `invalid UID` warnings
appear for them.

- [ ] **Step 6: Run the full suite**

```
test_run()
```

Expected: `failed: 0`, `total: 424`, `suite_count: 29`.

- [ ] **Step 7: Commit**

```bash
git add Scenes/ tests/test_project_hygiene.gd && git commit -m "fix(scenes): point 14 stale ext_resource UIDs at their real assets"
```

---

## Task 5: Delete the leftover DEBUG prints and guard against new ones

Fixes **F7**. Five `print("DEBUG…")` calls ship in production screens.
`atur_jadwal.gd:564` dumps the whole `selected_student` dictionary and was
observed firing six times per student selection.

**Files:**
- Modify: `Scripts/AturJadwal/atur_jadwal.gd:564`, `:659`, `:692`, `:875`
- Modify: `Scripts/StudentCard/student_card.gd:1528`
- Test: `tests/test_project_hygiene.gd` (created in Task 4)

**Interfaces:**
- Consumes: `_all_files_under(root: String, suffix: String) -> PackedStringArray`
  from `tests/test_project_hygiene.gd`, defined in Task 4.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_project_hygiene.gd`:

```gdscript
func test_no_debug_prints_survive_in_production_scripts() -> void:
	# Scripts/Debug/ is the in-game debug overlay -- printing is its job.
	# Everywhere else a DEBUG print is a leftover, and they are not harmless:
	# atur_jadwal.gd dumped the entire selected_student dictionary six times
	# per selection, crowding real diagnostics out of a finite log buffer.
	var offenders: Array[String] = []
	for script_path in _all_files_under("res://Scripts", ".gd"):
		if script_path.begins_with("res://Scripts/Debug/"):
			continue
		var text := FileAccess.get_file_as_string(script_path)
		var lines := text.split("\n")
		for i in range(lines.size()):
			if lines[i].strip_edges().begins_with("print(\"DEBUG"):
				offenders.append("%s:%d" % [script_path, i + 1])
	assert_eq(offenders.size(), 0,
		"DEBUG prints must not ship outside Scripts/Debug/; offenders: "
			+ ", ".join(offenders))
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="project_hygiene", test_name="test_no_debug_prints_survive_in_production_scripts")
```

Expected: FAIL listing exactly five offenders —
`res://Scripts/AturJadwal/atur_jadwal.gd:564`, `:659`, `:692`, `:875`, and
`res://Scripts/StudentCard/student_card.gd:1528`.

- [ ] **Step 3: Delete the five prints**

Delete each of these whole lines, leaving surrounding logic untouched:

```gdscript
	print("DEBUG selected_student: ", GameState.selected_student)   # atur_jadwal.gd:564
	print("DEBUG: TOMBOL TERTEKAN!")                                # atur_jadwal.gd:659
	print("DEBUG: START WEEK DITEKAN!")                             # atur_jadwal.gd:692
	print("DEBUG: PROCEEDING START WEEK")                           # atur_jadwal.gd:875
	print("DEBUG approve ditekan, tutorial_active: ", tutorial_active)  # student_card.gd:1528
```

```bash
cd "C:/Users/ASUS/Downloads/KejarTestAlphaVer2.15/new-game-project"
sed -i '/print("DEBUG/d' Scripts/AturJadwal/atur_jadwal.gd Scripts/StudentCard/student_card.gd
git diff --stat -- Scripts/AturJadwal/atur_jadwal.gd Scripts/StudentCard/student_card.gd
```

Expected: 2 files changed, 5 deletions, 0 insertions.

Watch for one hazard: if any of those prints was the **only** statement in an
`if` or `else` block, deleting it leaves an empty block and a parse error. Check
the diff context before moving on; if it happened, put `pass` in that block.

- [ ] **Step 4: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="project_hygiene")
```

Expected: PASS, 2 tests, empty offender list. A parse error here means the
empty-block hazard above bit — fix it before continuing.

- [ ] **Step 5: Run the full suite**

```
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
test_run()
```

Expected: `failed: 0`, `total: 425`. In particular `atur_jadwal` and
`student_card` must both stay green — those two scripts just changed.

- [ ] **Step 6: Commit**

```bash
git add Scripts/AturJadwal/atur_jadwal.gd Scripts/StudentCard/student_card.gd tests/test_project_hygiene.gd && git commit -m "chore(logging): drop the five leftover DEBUG prints from production screens"
```

---

## Task 6: Correct the two documents that misdirect the next session

Fixes **F8**. `CLAUDE.md` is the file every new session reads first, and four of
its claims are now wrong — one of them (Known Issue #2) sends the reader hunting
a bug that no longer reproduces.

**Files:**
- Modify: `CLAUDE.md` (Testing section; Known issues 1–3; Current work section)
- Modify: `docs/superpowers/baseline/known-errors.md`

**Interfaces:**
- Consumes: the final `test_run` counts from Task 5, Step 5.
- Produces: nothing executable.

- [ ] **Step 1: Capture the true numbers**

```
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
test_run()
```

Record `suite_count`, `total`, `passed`, `failed` from the response and use
those exact values below rather than the ones this plan predicts.

- [ ] **Step 2: Update the Testing section of `CLAUDE.md`**

Replace:

```
Suites live in `tests/test_*.gd`, extend `McpTestSuite`
(`addons/godot_ai/testing/test_suite.gd`), and run **inside the editor** via
the Godot AI MCP `test_run` tool. 23 suites, 284 tests.
```

with (substituting the Step 1 numbers):

```
Suites live in `tests/test_*.gd`, extend `McpTestSuite`
(`addons/godot_ai/testing/test_suite.gd`), and run **inside the editor** via
the Godot AI MCP `test_run` tool. 29 suites, 425 tests, all green.
```

- [ ] **Step 3: Rewrite the Known issues section of `CLAUDE.md`**

Replace the whole `## Known issues (as of 2026-08-28)` section — all three
numbered entries — with:

```markdown
## Known issues (as of 2026-08-30)

None outstanding. The 2026-08-30 stability sweep closed all three of the
previous entries; see `docs/superpowers/specs/2026-08-30-project-stability-sweep-findings.md`
for what each turned out to be.

1. **The `test_audio_director` coroutine test** (old #1) — fixed. Both offending
   tests are non-coroutine now, and the suite snapshots/restores the global
   AudioServer bus state in `setup`/`teardown`, so a run can no longer dirty
   `Assets/Audio/default_bus_layout.tres`. If you see that file modified with no
   audio work done, it is a *new* leak, not this one.
2. **`test_audio_coverage` double-SFX** (old #2) — did not reproduce on
   2026-08-30; that suite passes. The entry was stale.
3. **Stale `ext_resource` UIDs** (old #3) — fixed. All 14 across six scenes now
   point at their real assets, and
   `tests/test_project_hygiene.gd::test_every_scene_ext_resource_uid_resolves_to_its_own_asset`
   fails the build if a new one appears.
```

- [ ] **Step 4: Update the Current work section of `CLAUDE.md`**

Replace the whole `## Current work` section with:

```markdown
## Current work

Branch `Textures` (this is also the main branch).

The koperasi/inventory integration is committed and done. Recent work is the
day-summary readout: see `docs/superpowers/plans/2026-08-29-day-summary-mockup.md`,
`2026-08-30-day-summary-annotated-readout.md`, and
`2026-08-30-day-summary-stat-track-gauge.md` (**plan checkboxes are never
ticked — git log is the real record**).

The 2026-08-30 stability sweep
(`docs/superpowers/plans/2026-08-30-project-stability-sweep.md`) is complete.

`-REFERENCE-/prototype/` is the original prototype, kept for reference only —
not built, not imported. `koprasi&inventory` was a second programmer's separate
project; the spec's Asset Policy documents exactly which of its art is
finished (copy byte-identical) versus placeholder chrome (restyle onto our
theme).
```

- [ ] **Step 5: Retire the UID section of the baseline doc**

At the top of `docs/superpowers/baseline/known-errors.md`, directly under the
`# Known pre-existing errors/warnings` heading, insert:

```markdown
> **Superseded 2026-08-30.** The "Invalid ext_resource UIDs" section below is
> historical. That audit caught 4 of them; a full sweep on 2026-08-30 found 14
> across six scenes, and all 14 are now repaired. The class is guarded by
> `tests/test_project_hygiene.gd::test_every_scene_ext_resource_uid_resolves_to_its_own_asset`,
> which derives truth from `ResourceUID` rather than from a list, so it also
> catches new ones. See
> `docs/superpowers/specs/2026-08-30-project-stability-sweep-findings.md` (F6).
```

- [ ] **Step 6: Verify the docs match reality**

```bash
cd "C:/Users/ASUS/Downloads/KejarTestAlphaVer2.15/new-game-project"
git branch --show-current
grep -n "suites," CLAUDE.md
grep -n "Known issues" CLAUDE.md
```

Expected: the branch printed matches what `CLAUDE.md`'s Current work section
now claims, and the suite/test counts match Step 1's response.

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md docs/superpowers/baseline/known-errors.md && git commit -m "docs: refresh the project guide and baseline after the stability sweep"
```

---

## Final verification

- [ ] **Step 1: Clean full run from a known state**

```
scene_open(path="res://Scenes/Splashscreen/Splashscreen.tscn")
filesystem_manage(op="scan")
test_run()
```

Expected: `failed: 0`.

- [ ] **Step 2: Prove the suite leaves no dirt**

```bash
cd "C:/Users/ASUS/Downloads/KejarTestAlphaVer2.15/new-game-project"
git status --short -- Assets/ Scripts/ Scenes/ tests/
```

Expected: empty. Anything listed here is a test writing to the repo — the exact
problem Task 3 fixed.

- [ ] **Step 3: One live pass through the loop that changed**

```
project_run()
```

Debug overlay (`F1`) → **⚡ Seed Playtest State** → **Scenes** → AturJadwal →
fill the week → **Mulai Minggu** → play all five days through to the week-end
result.

```
logs_read(source="game", count=60, include_details=true)
project_manage(op="stop")
```

Expected, and each of these is a specific defect this plan removed:
- the week reaches day 5 and routes onward — no stack-overflow break (F1)
- **zero** `will make owner 'DaySummaryPill' inconsistent` lines (F2)
- **zero** `invalid UID` warnings (F6)
- **zero** `DEBUG` lines (F7)
