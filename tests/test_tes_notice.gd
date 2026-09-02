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
