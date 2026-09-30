@tool
extends McpTestSuite

## Regressions for two settings bugs (2026-09-30 bug scan, audio-debug group).
##
## 1. The coin cue: AudioDirector.tscn once overrode sfx_coin with the old
##    Kenney click (SFX/coin.ogg), so the 2026-09-21 earnMoney cue that the
##    script default names never played.
## 2. The minigame tutorial switch: DebugManager's playtest defaults held a
##    `GameSettings.minigame_tutorial_enabled = false` that, had it run, the
##    next save_settings() would have written to settings.cfg as the player's
##    own choice. It never ran (`"GameSettings" in root` is always false: `in`
##    asks for a property, not a child node), so it is gone, and the CARA MAIN
##    gate keeps following the Settings switch alone, debug builds included.
##
## Source scans, PackedScene state reads and two bare Nodes: no scene is
## instanced, so no autoload or bus state is touched. Must be @tool; no test
## is a coroutine.

## The audio autoload's scene, whose saved overrides beat the script defaults.
const AUDIO_SCENE := "res://Scenes/Audio/AudioDirector.tscn"
## The audio autoload's script, which holds the sfx_coin default.
const AUDIO_SCRIPT := "res://Scripts/Audio/AudioDirector.gd"
## The 2026-09-21 pack's coin cue: money coming in.
const EARN_MONEY := "res://Assets/Audio/SFX/earnMoney.ogg"
## The debug overlay whose playtest defaults once wrote the saved switch.
const DEBUG_SCRIPT := "res://Scripts/Debug/DebugManager.gd"
## The minigame base class whose activate_minigame gates the CARA MAIN card.
const BASE_MINIGAME := "res://Scripts/Minigames/UI/BaseMinigame.gd"


func suite_name() -> String:
	return "bugfix_audio_debug"


## One top-level function's body, from after its `func` line to the next
## column-0 line (the slicer test_debug_manager.gd uses).
func _function_body(src: String, fname: String) -> String:
	var out := ""
	var inside := false
	for line in src.split("\n"):
		if line.begins_with(fname):
			inside = true
			continue
		if inside:
			if line.length() > 0 and not (line.begins_with("\t") or line.begins_with(" ")):
				break
			out += line + "\n"
	return out


# ──────────────────────────────────────────────── 1. coin cue

func test_the_shipped_scene_does_not_override_the_coin_slot() -> void:
	var scene := ResourceLoader.load(AUDIO_SCENE, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert_true(scene != null, "AudioDirector.tscn loads")
	if scene == null:
		return
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		assert_ne(state.get_node_property_name(0, i), &"sfx_coin",
			"the scene must leave sfx_coin to the script default (earnMoney)")


func test_the_scene_no_longer_references_the_old_click() -> void:
	var src := FileAccess.get_file_as_string(AUDIO_SCENE)
	assert_false(src.contains("res://Assets/Audio/SFX/coin.ogg"),
		"the Kenney click the coin slot used before 2026-09-21 is unused")


func test_the_script_default_coin_cue_is_earn_money() -> void:
	var src := FileAccess.get_file_as_string(AUDIO_SCRIPT)
	assert_true(src.contains("var sfx_coin: AudioStream = preload(\"%s\")" % EARN_MONEY),
		"with no scene override, play_sfx(&\"coin\") plays earnMoney")
	assert_true(ResourceLoader.exists(EARN_MONEY), "earnMoney.ogg is still in the project")


# ──────────────────────────────────────────────── 2. tutorial switch

func test_playtest_defaults_leave_the_saved_tutorial_switch_alone() -> void:
	var body := _function_body(FileAccess.get_file_as_string(DEBUG_SCRIPT),
		"func _apply_playtest_defaults(")
	assert_true(body.contains("GameState.tutorials_bypassed = true"),
		"playtest still bypasses the screen tutorials, session-only")
	assert_false(body.contains("minigame_tutorial_enabled"),
		"a forced value in the saved field reaches settings.cfg on the next save")
	assert_false(body.contains("save_settings"),
		"playtest defaults never write the player's settings")


## Why the forced false never ran: `"Name" in node` asks whether the node has
## a PROPERTY of that name, so an autoload-style child never answers true.
func test_in_asks_for_a_property_not_a_child_node() -> void:
	var parent := Node.new()
	var child := Node.new()
	child.name = "GameSettings"
	parent.add_child(child)
	assert_true(parent.get_node_or_null("GameSettings") != null, "the child is there")
	assert_false("GameSettings" in parent, "yet `in` does not see a child node")
	parent.free()


func test_the_minigame_tutorial_gate_follows_the_settings_switch_alone() -> void:
	var body := _function_body(FileAccess.get_file_as_string(BASE_MINIGAME),
		"func activate_minigame(")
	assert_true(body.contains("should_show_how_to(GameSettings.minigame_tutorial_enabled,"),
		"the CARA MAIN card follows the saved Settings switch")
	assert_false(body.contains("tutorials_bypassed"),
		"the debug boot's bypass must not silence the switch: every editor " +
		"run is a debug build, where the Settings toggle would then do nothing")
