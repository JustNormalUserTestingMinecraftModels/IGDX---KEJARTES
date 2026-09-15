# Debug Weekly Report Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline: the Godot bridge takes one client). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A debug-overlay button that opens the weekly report (ResultCheckup) over the current screen, filled with a fixed sample week.

**Architecture:** A pure static `WeekReportRehearsal` puts a sample week onto a throwaway `StudentManager` and hands back the week's coins. `DebugManager` builds that manager from `GameState`, hosts `ResultCheckup.tscn` on its own `CanvasLayer` under the current scene, frees the manager, and frees the layer on `checkup_closed`.

**Tech Stack:** Godot 4.6 GDScript, godot-ai MCP editor bridge, `McpTestSuite` suites run by `test_run`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-15-debug-weekly-report-design.md`.
- Worktree `.claude/worktrees/debug-weekly-report`, branch `feat/debug-weekly-report`, editor session `debug-weekly-report@31da`. Re-list with `session_manage(op="list")` after any restart. Pass `session_id` on every godot-ai call; never `session_activate`; never kill every Godot process.
- Test steps: `Run: test_run(suite="<x>", session_id="debug-weekly-report@31da")`.
- Tests: `@tool`, extend `McpTestSuite`, override `suite_name()`, no coroutines.
- `DebugManager.gd` is not `@tool` and is out of the design-system scope: its tests are source scans, and building its buttons in code is the file's norm.
- A new `class_name` script needs `filesystem_manage(op="scan")`. An edited `class_name` script does not hot-reload here, so restart the worktree editor before its tests. `DebugManager.gd` is an autoload, not a `class_name`.
- Type every result explicitly (`var coins: int = ...`), per the cold-start inference parse error note.
- Commits: `feat(debug)` / `test(debug)` / `docs(debug)`, via `git commit -F <file>`, staging by name. The editor rewrites `Assets/Audio/default_bus_layout.tres`: never stage it, and revert it before stamping. End every message with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File map

| File | Change | Responsibility |
|---|---|---|
| `Scripts/Debug/WeekReportRehearsal.gd` | create | the sample week, pure |
| `tests/test_week_report_rehearsal.gd` | create | behavioural suite for it |
| `Scripts/Debug/DebugManager.gd` | modify | button, open/close handlers |
| `tests/test_debug_manager.gd` | modify | wiring scans, debug-only ratchet |
| `docs/superpowers/CHANGELOG.md`, `CLAUDE.md` | modify | changelog, working-efficiently line, suite count |

---

### Task 1: `WeekReportRehearsal`, the sample week

**Files:**
- Create: `Scripts/Debug/WeekReportRehearsal.gd`
- Create: `tests/test_week_report_rehearsal.gd` (suite `week_report_rehearsal`)

**Interfaces:**
- Produces: `WeekReportRehearsal.REPORT_SCENE: String`, `SKILLS`, `SAMPLE_SKILL_DELTAS`, `SAMPLE_ENERGY_DELTA`, `SAMPLE_MOOD_DELTA`, `SAMPLE_EARNINGS: int` (1500), `SAMPLE_HISTORY`, and `static func apply_sample_week(manager: StudentManager) -> int`.

- [ ] **Step 1: Write the failing suite** — `tests/test_week_report_rehearsal.gd`:

```gdscript
@tool
extends McpTestSuite

## WeekReportRehearsal, the debug overlay's sample week for the weekly
## report, checked behaviourally on a throwaway StudentManager. Its demo
## roster (Budi/Ani/Cici/Doni) takes its own Monday snapshot, so deltas read
## straight off StudentData. @tool, and no test here may be a coroutine.


func suite_name() -> String:
	return "week_report_rehearsal"


func _manager() -> StudentManager:
	var m := StudentManager.new()
	track(m)
	return m


func test_the_sample_hands_back_its_coins() -> void:
	var coins: int = WeekReportRehearsal.apply_sample_week(_manager())
	assert_eq(coins, 1500, "the week's Wirausaha payout")


func test_the_first_student_gains_in_all_three_skills() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	var s: StudentData = m.students[0]
	assert_eq(s.get_akademis_delta(), 12.0, "akademis up")
	assert_eq(s.get_seni_delta(), 8.0, "seni up")
	assert_eq(s.get_olahraga_delta(), 5.0, "olahraga up")


## One press shows every beat of the reveal: a loss, a single gain, a flat card.
func test_the_ladder_shows_a_loss_a_single_gain_and_a_flat_card() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	assert_eq(m.students[1].get_seni_delta(), -3.0, "student 2 loses seni")
	assert_eq(m.students[1].get_akademis_delta(), 9.0, "while gaining akademis")
	assert_eq(m.students[2].get_akademis_delta(), 0.0, "student 3 gains only seni")
	assert_eq(m.students[2].get_seni_delta(), 7.0, "student 3 gains only seni")
	for key in ["get_akademis_delta", "get_seni_delta", "get_olahraga_delta"]:
		assert_eq(m.students[3].call(key), 0.0, "student 4 is flat: " + key)


func test_both_needs_move_for_everyone() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	for s in m.students:
		assert_eq(s.get_energy_delta(), -12.0, "energy falls for " + s.student_name)
		assert_eq(s.get_mood_delta(), 6.0, "mood rises for " + s.student_name)


func test_a_roster_longer_than_the_ladder_repeats_its_last_entry() -> void:
	var m := _manager()
	var extra := StudentData.new()
	extra.student_name = "Eko"
	extra.akademis = 50.0
	extra.record_initial_stats()
	m.students.append(extra)
	WeekReportRehearsal.apply_sample_week(m)
	assert_eq(extra.get_akademis_delta(), 0.0, "a fifth student reads the flat last entry")


func test_a_stat_near_the_ceiling_is_clamped() -> void:
	var m := _manager()
	m.students[0].akademis = 95.0
	WeekReportRehearsal.apply_sample_week(m)
	assert_eq(m.students[0].akademis, 100.0, "clamped to 100, as the simulation clamps")


func test_the_history_reads_two_won_and_one_lost() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	var recap: Dictionary = WeekRecap.compute(m)
	assert_eq(int(recap["minigames_won"]), 2, "EVENT BERHASIL : 2")
	assert_eq(int(recap["minigames_lost"]), 1, "EVENT GAGAL : 1")
	assert_eq(m.minigame_history.size(), 4, "three minigames and one event in Logs")


## The rows carry the keys StudentManager itself records, so Logs reads
## them exactly as it reads a real week.
func test_every_history_row_carries_the_keys_the_game_records() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	for entry in m.minigame_history:
		for key in ["day", "category", "game_name", "won"]:
			assert_true(entry.has(key), "%s has %s" % [entry.get("game_name", "?"), key])
		if entry["category"] == "Event":
			assert_true(entry.has("details") and entry.has("affected_students"),
				"an event carries details and affected_students")
		else:
			assert_true(entry.has("score") and entry.has("max_score") and entry.has("results"),
				"a minigame carries score, max_score and results")


func test_the_report_scene_is_the_weekly_report() -> void:
	assert_eq(WeekReportRehearsal.REPORT_SCENE,
		"res://Scenes/SchoolSimulation/ResultCheckup.tscn", "the preview opens ResultCheckup")
```

- [ ] **Step 2: Run to verify it fails** — `Run: test_run(suite="week_report_rehearsal", session_id="debug-weekly-report@31da")`. Expected: suite broken / load error (`WeekReportRehearsal` not found).

- [ ] **Step 3: Implement** — `Scripts/Debug/WeekReportRehearsal.gd`:

```gdscript
@tool
class_name WeekReportRehearsal
extends RefCounted

## Debug-only jig for the weekly report (ResultCheckup). It puts a fixed
## sample week onto a throwaway StudentManager, so the report's reveal can
## be watched in one click from the debug overlay's Scenes tab instead of
## played for a school week (2026-09-15 debug-weekly-report spec).
##
## Nothing in the shipped game calls this file: DebugManager is its only
## caller, and tests/test_debug_manager.gd enforces that. It writes only to
## the manager it is handed, never to GameState. Plain static functions and
## consts, no nodes, so tests/test_week_report_rehearsal.gd can check it
## behaviourally.

## The report scene the preview opens.
const REPORT_SCENE := "res://Scenes/SchoolSimulation/ResultCheckup.tscn"

## The three skills in the card's top-to-bottom order. These are
## StudentData's own field names, so the akademis2/3 naming trap does not
## apply here.
const SKILLS := ["akademis", "seni_budaya", "olahraga"]

## Each roster slot's week, one delta per SKILLS entry. It is a ladder, so
## one press shows every beat of the reveal: all three up; two up and one
## down; one up; flat. Slots past the end repeat the last entry.
const SAMPLE_SKILL_DELTAS := [
	[12.0, 8.0, 5.0],
	[9.0, -3.0, 6.0],
	[0.0, 7.0, 0.0],
	[0.0, 0.0, 0.0],
]

## The week's energy movement, the same for everyone, so the energy bar
## travels and shows its chevron.
const SAMPLE_ENERGY_DELTA := -12.0
## The week's mood movement, the same for everyone.
const SAMPLE_MOOD_DELTA := 6.0

## The Wirausaha coins the sample week paid out.
const SAMPLE_EARNINGS := 1500

## The week's minigames and one event, in the shapes
## StudentManager.record_minigame_result / record_event_result append. Two
## minigames won and one lost (EVENT BERHASIL 2, EVENT GAGAL 1), plus a
## random event that counts in neither line but shows in Logs.
const SAMPLE_HISTORY := [
	{"day": "Senin", "category": "Akademis", "game_name": "Pilihan Ganda",
		"won": true, "score": 4, "max_score": 5, "results": []},
	{"day": "Selasa", "category": "Olahraga", "game_name": "Badminton",
		"won": false, "score": 1, "max_score": 5, "results": []},
	{"day": "Rabu", "category": "Event", "game_name": "Nasi Kotak",
		"won": true, "details": "Semua murid makan siang bersama.",
		"affected_students": []},
	{"day": "Kamis", "category": "SeniBudaya", "game_name": "Buat Batik",
		"won": true, "score": 5, "max_score": 5, "results": []},
]


## Puts the sample week onto `manager`. Each student's skills and needs move
## by their slot's deltas, measured from the Monday snapshot the manager
## took when it converted the roster, and the minigame history becomes
## SAMPLE_HISTORY. Returns the coins to hand to
## ResultCheckup.initialize_checkup(). Every stat is clamped to 0..100, as
## the simulation clamps.
static func apply_sample_week(manager: StudentManager) -> int:
	for i in manager.students.size():
		var deltas: Array = SAMPLE_SKILL_DELTAS[mini(i, SAMPLE_SKILL_DELTAS.size() - 1)]
		var s: StudentData = manager.students[i]
		for k in SKILLS.size():
			var key: String = SKILLS[k]
			s.set(key, clampf(float(s.get(key)) + float(deltas[k]), 0.0, 100.0))
		s.energy = clampf(s.energy + SAMPLE_ENERGY_DELTA, 0.0, 100.0)
		s.mood = clampf(s.mood + SAMPLE_MOOD_DELTA, 0.0, 100.0)
	manager.minigame_history.assign(SAMPLE_HISTORY.duplicate(true))
	return SAMPLE_EARNINGS
```

- [ ] **Step 4: Register and run** — `filesystem_manage(op="scan")`, then `Run: test_run(suite="week_report_rehearsal", ...)` and `test_run(suite="script_documentation", ...)`. Expected: PASS.

- [ ] **Step 5: Commit** the script, the suite and both `.gd.uid` files — `feat(debug): WeekReportRehearsal, a fixed sample week for the weekly report`.

---

### Task 2: The overlay button

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd` (`_build_scenes_panel` after the teleport loop; new handlers after `_restore_before_rehearsal`)
- Modify: `tests/test_debug_manager.gd`

**Interfaces:**
- Consumes: `WeekReportRehearsal.apply_sample_week(manager) -> int`, `WeekReportRehearsal.REPORT_SCENE`; `ResultCheckup.initialize_checkup(student_manager, week_earnings)` and its `checkup_closed` signal; the existing `_auto_approve_students()`, `_set_time_scale()`, `toggle_overlay()` and `log_message()`.
- Produces: `_open_week_report_preview()`, `_close_week_report_preview()`, `var _week_report_canvas: CanvasLayer`, `const WEEK_REPORT_LAYER := 124`.

- [ ] **Step 1: Write the failing tests** — in `tests/test_debug_manager.gd`, generalise the ratchet helper and add the preview section. Replace `test_nothing_in_the_shipped_game_calls_the_rehearsal` and `_scan_for_rehearsal_callers` with:

```gdscript
## The ratchet on requirement 4: the rehearsal is a debug jig, and a
## reference to it from a shipped screen would mean it had leaked into the
## real game loop.
func test_nothing_in_the_shipped_game_calls_the_rehearsal() -> void:
	var offenders: Array[String] = []
	_scan_for_debug_callers("res://Scripts", "EndGameRehearsal", offenders)
	assert_eq(offenders.size(), 0,
		"EndGameRehearsal is debug-only; found shipped callers in: "
			+ ", ".join(offenders))


## The same ratchet for the weekly report's sample week.
func test_nothing_in_the_shipped_game_calls_the_week_report_rehearsal() -> void:
	var offenders: Array[String] = []
	_scan_for_debug_callers("res://Scripts", "WeekReportRehearsal", offenders)
	assert_eq(offenders.size(), 0,
		"WeekReportRehearsal is debug-only; found shipped callers in: "
			+ ", ".join(offenders))


## Walks res://Scripts for references to `name` outside Scripts/Debug/,
## the only directory allowed to name a debug jig.
func _scan_for_debug_callers(dir_path: String, name: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != "Debug":
				_scan_for_debug_callers(full, name, out)
		elif entry.ends_with(".gd"):
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null and f.get_as_text().contains(name):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
```

Append at the end of the file:

```gdscript
# ──────────────────────────────────────────────── weekly report preview

func test_the_scenes_tab_opens_the_weekly_report_preview() -> void:
	var body := _function_body(_source(), "_build_scenes_panel")
	assert_true(body.contains(".pressed.connect(_open_week_report_preview)"),
		"the Scenes tab must offer the weekly report preview")
	assert_true(body.contains("Laporan Mingguan"), "and say what it opens")


## The report measures every card from the Monday snapshot, so the manager
## must be built from GameState before the sample week moves anything.
## The default roster is approved only when none is.
func test_the_preview_builds_the_sample_week_from_the_real_roster() -> void:
	var body := _function_body(_source(), "_open_week_report_preview")
	var empty_at := body.find("if GameState.approved_students.is_empty():")
	var approve_at := body.find("_auto_approve_students()")
	assert_true(empty_at != -1 and approve_at > empty_at,
		"approve the default roster only when nothing is approved")
	var init_at := body.find("initialize_from_gamestate()")
	var sample_at := body.find("WeekReportRehearsal.apply_sample_week(")
	assert_true(init_at != -1 and sample_at > init_at,
		"the snapshot comes first, then the sample week")
	assert_true(body.contains("initialize_checkup(manager, coins)"),
		"the report reads the sample week and its coins")


## StudentManager is a Node: leaving it unfreed leaks one per press. The
## report has copied what it reads by the end of initialize_checkup.
func test_the_preview_frees_its_manager_once_the_report_has_read_it() -> void:
	var body := _function_body(_source(), "_open_week_report_preview")
	var read_at := body.find("initialize_checkup(manager, coins)")
	var free_at := body.find("manager.free()")
	assert_true(read_at != -1 and free_at > read_at, "free the manager after the report reads it")


func test_the_preview_hangs_off_the_current_scene_and_closes_itself() -> void:
	var body := _function_body(_source(), "_open_week_report_preview")
	assert_true(body.contains("get_tree().current_scene"),
		"a teleport must take the preview down with the scene it covers")
	assert_true(body.contains("checkup_closed.connect(_close_week_report_preview)"),
		"Selanjutnya must close the preview")
	assert_true(body.contains("_set_time_scale(1.0)"), "the reveal plays at normal speed")
	var close := _function_body(_source(), "_close_week_report_preview")
	assert_true(close.contains("_week_report_canvas.queue_free()"), "closing frees the host layer")
	assert_true(close.contains("_week_report_canvas = null"), "and forgets it")


func test_a_second_press_while_open_does_not_stack_another() -> void:
	var body := _function_body(_source(), "_open_week_report_preview")
	var guard_at := body.find("if is_instance_valid(_week_report_canvas):")
	var build_at := body.find("CanvasLayer.new()")
	assert_true(guard_at != -1 and build_at > guard_at,
		"an open preview makes a second press a no-op")
```

- [ ] **Step 2: Run to verify** — `Run: test_run(suite="debug_manager", ...)`. Expected: the five new preview tests FAIL; the two ratchets PASS.

- [ ] **Step 3: Implement** — in `Scripts/Debug/DebugManager.gd`, after the `for sc in scenes_list:` loop in `_build_scenes_panel` (before `var sep_rehearsal`):

```gdscript
	var btn_week_report = Button.new()
	btn_week_report.text = " 📊 Laporan Mingguan (ResultCheckup) "
	btn_week_report.custom_minimum_size = Vector2(0, 95)
	btn_week_report.add_theme_font_size_override("font_size", 21)
	btn_week_report.pressed.connect(_open_week_report_preview)
	vbox.add_child(btn_week_report)
```

After `_restore_before_rehearsal()` (before `# --- Logs/Console Panel ---`):

```gdscript
## The weekly report preview's host layer, or null when none is open.
var _week_report_canvas: CanvasLayer = null
## The preview's layer: just under the standalone minigame launcher's (125)
## and the overlay's own (128).
const WEEK_REPORT_LAYER := 124

## Opens the weekly report (ResultCheckup) over the current screen, filled
## with WeekReportRehearsal's sample week, so its reveal can be watched in
## one click. Nothing in the run changes: the sample lands on a throwaway
## StudentManager, and the report writes nothing. The host layer hangs off
## the current scene, so a teleport takes it down too.
func _open_week_report_preview() -> void:
	if is_instance_valid(_week_report_canvas):
		log_message("Laporan mingguan sudah terbuka.")
		return
	if GameState.approved_students.is_empty():
		_auto_approve_students()
	var manager: StudentManager = StudentManager.new()
	manager.initialize_from_gamestate()
	var coins: int = WeekReportRehearsal.apply_sample_week(manager)
	_set_time_scale(1.0)
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else self
	_week_report_canvas = CanvasLayer.new()
	_week_report_canvas.layer = WEEK_REPORT_LAYER
	host.add_child(_week_report_canvas)
	var report = load(WeekReportRehearsal.REPORT_SCENE).instantiate()
	_week_report_canvas.add_child(report)
	report.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	report.initialize_checkup(manager, coins)
	# The report has copied everything it reads; the manager is a Node.
	manager.free()
	report.checkup_closed.connect(_close_week_report_preview)
	if debug_ui_root and debug_ui_root.visible:
		toggle_overlay()
	log_message("Laporan mingguan dibuka dengan minggu contoh (%d murid)." % GameState.approved_students.size())


## Frees the preview once its Selanjutnya has faded it out.
func _close_week_report_preview() -> void:
	if is_instance_valid(_week_report_canvas):
		_week_report_canvas.queue_free()
	_week_report_canvas = null
```

- [ ] **Step 4: Reload and run** — no-op `script_patch` on `DebugManager.gd`. Then `Run: test_run(suite="debug_manager", ...)`, `test_run(suite="week_report_rehearsal", ...)` and `test_run(suite="audio_coverage", ...)`. Expected: all PASS.

- [ ] **Step 5: Commit** both files — `feat(debug): Laporan Mingguan opens the weekly report with a sample week`.

---

### Task 3: See it, run everything, write it down

- [ ] **Step 1: Live check.** `project_run(autosave=false)`, then in one `game_eval`:
  1. snapshot `GameState.player_money`, `minggu_ke`, and the first student's `akademis1`
  2. call `DebugManager._open_week_report_preview()`
  3. wait, capped by wall-clock time, until the report's `next_button` is enabled
  4. freeze `Engine.time_scale = 0.02` and return the card count, the three summary texts and the snapshot comparison

  Then `editor_screenshot(source="game", max_resolution=0)`. Then in a second eval, resume time, call the report's `_on_next_pressed()`, wait until `DebugManager._week_report_canvas == null` (wall-clock cap), and return whether the layer is gone and GameState is unchanged. Stop the game.
- [ ] **Step 2: Full suite.** `Run: test_run(session_id="debug-weekly-report@31da")`. Afterwards run `git status`, and revert `Assets/Audio/default_bus_layout.tres` and/or `Assets/Theme/kejartes_theme.tres` if they changed. Fix anything this branch broke and re-run.
- [ ] **Step 3: Docs.**
  - CHANGELOG entry, newest first.
  - CLAUDE.md, `## Working efficiently here` item 1: add one sentence. The Scenes tab's **📊 Laporan Mingguan** opens the weekly report over the current screen with a fixed sample week, with no Atur Jadwal pass needed.
  - CLAUDE.md's suite and test count, from the full run.
- [ ] **Step 4: Commit** the docs — `docs(debug): changelog, CLAUDE.md shortcut and suite count`.
