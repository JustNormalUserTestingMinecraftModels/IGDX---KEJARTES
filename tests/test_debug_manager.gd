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
