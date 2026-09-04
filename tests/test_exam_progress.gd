@tool
extends McpTestSuite

## ExamProgress is the pacing beat between TesNotice and the exam-intro
## cutscene: "Tes sedang berlangsung" plus a timed fill bar, added in the
## 2026-09-04 end-game UI reskin. It carries no verdict, same contract as
## TesNotice -- see that screen's own suite for the sibling checks.
##
## Structure is checked live (the scene instantiates cleanly); routing and
## timing are checked by source-text scan, per this project's established
## pattern for GameState-dependent branching.

const _SCENE_PATH := "res://Scenes/EndGame/ExamProgress.tscn"
const _SCRIPT_PATH := "res://Scripts/EndGame/ExamProgress.gd"

var _screen: Control


func suite_name() -> String:
	return "exam_progress"


func setup() -> void:
	_screen = load(_SCENE_PATH).instantiate()


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_screen = null


func test_scene_loads() -> void:
	assert_true(_screen != null, "ExamProgress.tscn instantiates")


func test_has_the_backdrop_and_scrim() -> void:
	assert_true(_screen.get_node_or_null("Backdrop") != null, "Backdrop node")
	assert_true(_screen.get_node_or_null("Scrim") != null, "Scrim node")


func test_has_a_status_label_and_progress_bar() -> void:
	var label = _screen.get_node_or_null(
		"MarginContainer/Content/Inner/StatusLabel")
	var bar = _screen.get_node_or_null(
		"MarginContainer/Content/Inner/ProgressBar")
	assert_true(label is Label, "StatusLabel exists")
	assert_true(bar is ProgressBar, "ProgressBar exists")
	assert_eq(label.text, "Tes sedang berlangsung",
		"the label text is set statically, script overwrites it identically at runtime")


func test_the_notice_does_not_leak_the_verdict() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("check_semester_passed"),
		"the progress beat never reads the pass/fail result")


func test_it_routes_to_the_stat_check_and_never_arms_a_cutscene() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/EndGame/StatCheck.tscn"),
		"it routes to the stat check")
	assert_false(src.contains("is_exam_intro_cutscene"),
		"the exam-intro cutscene beat is gone; nothing arms it any more")
	assert_false(src.contains("cut_scene.tscn"),
		"it no longer routes to the cutscene")


func test_it_fills_over_a_tunable_duration() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("@export var fill_seconds: float = 4.0"),
		"the fill duration must be exported and tunable")
	assert_true(src.contains("tween_property(progress_bar, \"value\", 100.0, fill_seconds)"),
		"the bar must tween its value up to 100 over fill_seconds")


func test_it_plays_the_notice_bgm() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("play_bgm(&\"exam_notice\")"),
		"reuses TesNotice's exam_notice cue for continuity across the two beats")


func test_no_theme_overrides_anywhere() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"no theme_override_* in the scene: %s" % str(offenders))


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
