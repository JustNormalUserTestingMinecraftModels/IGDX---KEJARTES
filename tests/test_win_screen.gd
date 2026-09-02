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
	var mine: Control = _screen.get_node_or_null("DialogueBox")
	var theirs: Control = other.get_node_or_null("DialogueBox")
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


func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)
