@tool
extends McpTestSuite

## Debug overlay wiring. DebugManager.gd is not @tool, so the in-editor runner
## cannot instantiate it -- these are source scans, the same technique
## test_lobby.gd and test_main_menu.gd use for screens they cannot build live.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

const _SCRIPT_PATH := "res://Scripts/Debug/DebugManager.gd"


func suite_name() -> String:
	return "debug_manager"


func _source() -> String:
	var f := FileAccess.open(_SCRIPT_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Slices out one top-level function's body: everything after its `func` line
## up to the next line that starts at column 0. Lets a test assert about one
## handler instead of the whole 1200-line file, where a call like
## `_auto_approve_students()` also appears at its own definition and at the
## Students-tab button that shares it.
func _function_body(src: String, fname: String) -> String:
	var out := ""
	var inside := false
	for line in src.split("\n"):
		if line.begins_with("func " + fname + "("):
			inside = true
			continue
		if inside:
			if line.length() > 0 and not (line.begins_with("\t") or line.begins_with(" ")):
				break
			out += line + "\n"
	return out


func test_seed_button_is_wired_to_the_handler() -> void:
	var body := _function_body(_source(), "_build_general_panel")
	assert_true(body.contains("btn_seed.pressed.connect(_seed_playtest_state)"),
		"the Seed Playtest State button must be connected to its handler")


func test_seed_handler_sets_every_piece_of_state_the_docs_promise() -> void:
	var body := _function_body(_source(), "_seed_playtest_state")
	assert_true(body.contains("_auto_approve_students()"),
		"the seed must approve the roster")
	assert_true(body.contains("_set_money(999999)"),
		"the seed must set money through _set_money, which clamps and repaints")
	assert_true(body.contains("GameState.seed_playtest_inventory(5)"),
		"the seed must stock the inventory")
	assert_true(body.contains("GameState.lobby_tutorial_completed = true"),
		"the seed must bypass the lobby tutorial")
	assert_true(body.contains("GameState.tutorials_bypassed = true"),
		"the seed must bypass every tutorial in the game, not just the lobby's")


func test_tutorial_toggle_is_a_master_switch_for_every_tutorial() -> void:
	var body := _function_body(_source(), "_toggle_lobby_tutorial")
	assert_true(body.contains("GameState.tutorials_bypassed = not GameState.tutorials_bypassed"),
		"the button must flip the master bypass flag every tutorial screen checks")
	assert_true(body.contains("GameState.lobby_tutorial_completed = GameState.tutorials_bypassed"),
		"the lobby's own completed flag must follow the master switch")
	assert_true(body.contains("settings.minigame_tutorial_enabled = not GameState.tutorials_bypassed"),
		"the minigame tutorial setting must follow the master switch too")


func test_ready_applies_playtest_defaults() -> void:
	var body := _function_body(_source(), "_ready")
	assert_true(body.contains("_apply_playtest_defaults()"),
		"_ready must apply the playtest defaults on every launch")


func test_playtest_defaults_bypass_tutorial_fullscreen_and_mute_music() -> void:
	var body := _function_body(_source(), "_apply_playtest_defaults")
	assert_true(body.contains("GameState.tutorials_bypassed = true"),
		"playtest must always bypass every tutorial in the game")
	assert_true(body.contains("GameState.lobby_tutorial_completed = true"),
		"playtest must always skip the lobby tutorial")
	assert_true(body.contains("settings.minigame_tutorial_enabled = false"),
		"playtest must always skip the minigame tutorial")
	assert_true(body.contains("DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)"),
		"playtest must always launch fullscreen")
	assert_true(body.contains("AudioServer.set_bus_mute(bgm_idx, true)"),
		"playtest must always start with music off")


func test_function_body_slicer_stops_at_the_next_function() -> void:
	var src := "func a():\n\tvar x = 1\nfunc b():\n\tvar y = 2\n"
	var body := _function_body(src, "a")
	assert_true(body.contains("var x = 1"), "slicer must capture the target body")
	assert_false(body.contains("var y = 2"), "slicer must stop at the next top-level func")


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
