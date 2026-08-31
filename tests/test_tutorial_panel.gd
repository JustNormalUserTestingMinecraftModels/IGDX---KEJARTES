@tool
extends McpTestSuite

## The onboarding coach-mark. student_card.gd and SchoolDay.gd each built it
## by hand, and reading both before extracting turned up far more drift than
## the width/margin the plan anticipated: title variation (H1Label vs
## H2Label), body variation (TitleLabel vs none), body width offset
## (60 vs 100), prompt variation (TitleLabel vs CaptionLabel), a
## success-tinted prompt (SchoolDay only), and vbox separation (10 vs 20).
## Every one of those is now an @export knob rather than a picked winner --
## unifying any of them would change what the player sees, which is out of
## scope for this extraction.
##
## SchoolDay's dimming Scrim overlay is deliberately NOT part of this scene:
## it is a single `Panel.new()` line that is the PARENT of the tutorial
## panel, not a sibling inside it, so folding it in would invert the real
## hierarchy for no real reduction in construction sites. It stays in
## SchoolDay.gd, pinned by a regression test below.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "tutorial_panel"


const SCENE_PATH := "res://Scenes/UI/TutorialPanel.tscn"
const SCHOOL_DAY_PATH := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const STUDENT_CARD_PATH := "res://Scripts/StudentCard/student_card.gd"


func _make() -> TutorialPanel:
	var panel: TutorialPanel = load(SCENE_PATH).instantiate()
	Engine.get_main_loop().root.add_child(panel)
	track(panel)
	return panel


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var panel := _make()
	for node_path in ["Margin/Layout/TitleLabel", "Margin/Layout/Separator1",
			"Margin/Layout/BodyLabel", "Margin/Layout/Separator2",
			"Margin/Layout/PromptLabel"]:
		assert_not_null(panel.get_node_or_null(node_path), "missing node: %s" % node_path)


func test_show_step_fills_all_three_labels() -> void:
	var panel := _make()
	panel.show_step("Judul", "Isi penjelasan.", "Ketuk untuk lanjut")
	assert_eq(panel.get_node("Margin/Layout/TitleLabel").text, "Judul")
	assert_eq(panel.get_node("Margin/Layout/BodyLabel").text, "Isi penjelasan.")
	assert_eq(panel.get_node("Margin/Layout/PromptLabel").text, "Ketuk untuk lanjut")


func test_layout_knobs_default_to_student_cards_shipped_numbers() -> void:
	var panel := _make()
	assert_eq(panel.width_fraction, 0.92)
	assert_eq(panel.max_width, 1000.0)
	assert_eq(panel.content_margin, 0)
	assert_eq(panel.vbox_separation, 10)
	assert_eq(panel.title_variation, &"H1Label")
	assert_eq(panel.body_variation, &"TitleLabel")
	assert_eq(panel.body_width_offset, 60.0)
	assert_eq(panel.prompt_variation, &"TitleLabel")
	assert_false(panel.prompt_success_tint)


func test_overriding_layout_knobs_reaches_the_nodes() -> void:
	var panel := _make()
	panel.content_margin = 30
	panel.vbox_separation = 20
	panel.title_variation = &"H2Label"
	panel.body_variation = &""
	panel.prompt_variation = &"CaptionLabel"
	panel.prompt_success_tint = true

	var margin := panel.get_node("Margin") as MarginContainer
	assert_eq(margin.get_theme_constant("margin_left"), 30)
	assert_eq(margin.get_theme_constant("margin_top"), 30)
	assert_eq(margin.get_theme_constant("margin_right"), 30)
	assert_eq(margin.get_theme_constant("margin_bottom"), 30)
	assert_eq((panel.get_node("Margin/Layout") as VBoxContainer).get_theme_constant("separation"), 20)
	assert_eq((panel.get_node("Margin/Layout/TitleLabel") as Label).theme_type_variation, &"H2Label")
	assert_eq((panel.get_node("Margin/Layout/BodyLabel") as Label).theme_type_variation, &"")
	assert_eq((panel.get_node("Margin/Layout/PromptLabel") as Label).theme_type_variation, &"CaptionLabel")


func test_each_screen_still_sets_its_own_shipped_numbers() -> void:
	# StudentCard's 0.92/1000 are TutorialPanel's own component defaults
	# (see test_layout_knobs_default_to_student_cards_shipped_numbers), so
	# StudentCard's source no longer needs to restate them -- only
	# SchoolDay, which overrides away from those defaults, does.
	var day := FileAccess.get_file_as_string(SCHOOL_DAY_PATH)
	assert_contains(day, "0.85", "SchoolDay's width fraction was lost")
	assert_contains(day, "900.0", "SchoolDay's max width was lost")
	assert_contains(day, "30", "SchoolDay's 30px content margin was lost")


func test_neither_screen_builds_the_panel_by_hand() -> void:
	for path in [STUDENT_CARD_PATH, SCHOOL_DAY_PATH]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "TutorialPanel", "%s should instantiate the scene" % path)
		assert_false(src.contains("HSeparator.new("),
			"%s still builds the panel's separators" % path)


func test_school_day_still_owns_its_scrim_overlay() -> void:
	# See suite header: the Scrim is the tutorial panel's PARENT, not a
	# sibling inside it, so it deliberately stays out of TutorialPanel.tscn.
	var src := FileAccess.get_file_as_string(SCHOOL_DAY_PATH)
	assert_contains(src, 'theme_type_variation = &"Scrim"')
