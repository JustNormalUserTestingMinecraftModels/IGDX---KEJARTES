@tool
extends McpTestSuite

## TesNotice is the first screen of the end-of-grade sequence: a single
## announcement card that must not leak the pass/fail verdict. Since the
## 2026-09-04 reskin it hands off to ExamProgress (a timed pacing beat)
## rather than arming the exam cutscene flag and jumping straight to
## CutScene itself -- ExamProgress owns that flag now.
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


## Since 2026-09-12 the title is the team's "Ujian Nasional" logo art, not a
## DisplayLabel line. It must keep its aspect inside the content column: a
## TextureRect left on EXPAND_KEEP_SIZE would make the art's 2652px native
## width the column's minimum and push the card off screen.
func test_the_title_is_the_ujian_nasional_art() -> void:
	var content = _screen.get_node("MarginContainer/NoticeCard/Content")
	assert_true(content.get_node_or_null("TitleLabel") == null,
		"the text title was replaced by the logo art")
	var art = content.get_node_or_null("TitleArt")
	assert_true(art is TextureRect, "TitleArt is a TextureRect")
	if not art is TextureRect:
		return
	# The scene's own texture is only the editor preview; _ready() swaps in
	# the grade's logo (see test_the_title_art_follows_the_grade).
	var preview := String(art.texture.resource_path)
	assert_true(preview.ends_with("ujian_sekolah.png")
			or preview.ends_with("ujian_nasional.png"),
		"the preview texture is one of the two exam logos")
	assert_eq(art.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
		"the art's native size must not set the column's minimum")
	assert_eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"the logo keeps its aspect rather than stretching to the column")
	assert_true(art.custom_minimum_size.y > 0.0,
		"the art reserves a height, or the VBox collapses it to nothing")
	assert_eq(String(content.get_child(1).name), "TitleArt",
		"the logo sits directly under the PENGUMUMAN kicker")


## Kelas 7 and 8 sit the Ujian Sekolah; Kelas 9 sits the Ujian Nasional. The
## choice is a pure function of the grade so it can be checked without
## GameState; _ready() feeds it GameState.current_grade.
func test_the_title_art_follows_the_grade() -> void:
	assert_true(_screen.has_method("title_texture_for_grade"),
		"TesNotice picks its title art per grade")
	if not _screen.has_method("title_texture_for_grade"):
		return
	for grade in [7, 8]:
		var tex: Texture2D = _screen.title_texture_for_grade(grade)
		assert_true(tex != null and tex.resource_path.ends_with("ujian_sekolah.png"),
			"Kelas %d shows the Ujian Sekolah logo" % grade)
	var nine: Texture2D = _screen.title_texture_for_grade(9)
	assert_true(nine != null and nine.resource_path.ends_with("ujian_nasional.png"),
		"Kelas 9 shows the Ujian Nasional logo")


## The body copy names the same exam as the logo: Kelas 7-8 face the Tes
## Besar Sekolah, Kelas 9 the Ujian Nasional.
func test_the_body_names_the_grade_exam() -> void:
	assert_true(_screen.has_method("body_text_for_grade"),
		"TesNotice picks its body copy per grade")
	if not _screen.has_method("body_text_for_grade"):
		return
	for grade in [7, 8]:
		var text: String = _screen.body_text_for_grade(grade)
		assert_true(text.contains("Tes Besar Sekolah"),
			"Kelas %d is told about the Tes Besar Sekolah" % grade)
	var nine: String = _screen.body_text_for_grade(9)
	assert_true(nine.contains("Ujian Nasional"),
		"Kelas 9 is told about the Ujian Nasional")
	assert_false(nine.contains("Tes Besar Sekolah"),
		"Kelas 9's copy does not name the school exam")


func test_ready_applies_the_grade_body_text() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("body_label.text = body_text_for_grade(GameState.current_grade)"),
		"_ready() swaps the body copy for the current grade")


func test_ready_applies_the_grade_title_art() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("title_art.texture = title_texture_for_grade(GameState.current_grade)"),
		"_ready() swaps the logo for the current grade")


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


func test_it_routes_into_exam_progress() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/EndGame/ExamProgress.tscn"),
		"it routes to the exam progress beat")
	assert_false(src.contains("GameState.is_exam_intro_cutscene"),
		"arming the exam cutscene flag is ExamProgress's job now, not TesNotice's")


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
