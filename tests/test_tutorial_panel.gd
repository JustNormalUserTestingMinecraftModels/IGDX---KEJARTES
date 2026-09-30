@tool
extends McpTestSuiteCompat

## The onboarding coach-mark. StudentCard.gd and SchoolDay.gd each built it
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
## 2026-10-01 tutorial unification: the card gained a head badge (the "Langkah
## n / N" step pill, or the headmaster beat's name plate, chosen by `mode`),
## an entrance and an exit spring, and the tutorial arrow became an authored
## scene. Those are pinned at the end of this file.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "tutorial_panel"


const LayoutFrame := preload("res://tests/layout_frame.gd")

const SCENE_PATH := "res://Scenes/UI/TutorialPanel.tscn"
const SCHOOL_DAY_PATH := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const STUDENT_CARD_PATH := "res://Scripts/StudentCard/StudentCard.gd"
const PANEL_SCRIPT_PATH := "res://Scripts/UI/TutorialPanel.gd"
const ARROW_SCENE_PATH := "res://Scenes/UI/TutorialArrow.tscn"
const ARROW_SCRIPT_PATH := "res://Scripts/TutorialArrow.gd"
const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const SCHOOL_GLYPH_PATH := "res://Assets/Images/UI/Icons/school.svg"

## The card's layout column, where the badges sit above the title.
const LAYOUT := "Frame/Margin/Layout/"
## Every node the head badge adds, by path under LAYOUT.
const BADGE_NODES := [
	"StepPill", "StepPill/StepLabel", "NamePlate", "NamePlate/Row",
	"NamePlate/Row/Icon", "NamePlate/Row/SpeakerLabel",
]
## The four theme variations ThemeFactory builds for the badges.
const BADGE_VARIATIONS := [
	"TutorialStepPill", "TutorialStepPillLabel",
	"TutorialNamePlate", "TutorialNamePlateLabel",
]
## Every screen that shows the arrow. Each instances the scene; none builds it.
const ARROW_CALLERS := [
	"res://Scripts/StudentCard/StudentCard.gd",
	"res://Scripts/StudentList/StudentList.gd",
	"res://Scripts/AturJadwal/AturJadwal.gd",
	"res://Scripts/Lobby/Lobby.gd",
]


func _make() -> TutorialPanel:
	var panel: TutorialPanel = load(SCENE_PATH).instantiate()
	Engine.get_main_loop().root.add_child(panel)
	track(panel)
	return panel


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var panel := _make()
	for node_path in ["Frame/Margin/Layout/TitleLabel", "Frame/Margin/Layout/Separator1",
			"Frame/Margin/Layout/BodyLabel", "Frame/Margin/Layout/Separator2",
			"Frame/Margin/Layout/PromptLabel"]:
		assert_not_null(panel.get_node_or_null(node_path), "missing node: %s" % node_path)


func test_it_is_the_notebook_dialog_with_no_way_out() -> void:
	var root := (load(SCENE_PATH) as PackedScene).instantiate()
	track(root)
	var frame := root.get_node_or_null("Frame") as NotebookFrame
	assert_true(frame != null, "the card is a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "TUTORIAL")
		assert_false(frame.show_close, "a forced step shows no close")


## The F2 regression: BodyLabel's forced minimum used to ignore the frame's
## own horizontal content_padding, so the panel's real minimum width grew
## past its own width_fraction/max_width floor. TutorialPanel.gd's
## _ready() is not gated behind is_editor_hint(), so standing the scene up
## runs it (and _apply_geometry()) for real. reset_size() is the same call
## StudentCard.gd and SchoolDay.gd make before reading panel.size to
## position it.
##
## The expected width is computed from panel.get_viewport_rect().size.x,
## the exact value _apply_geometry() itself reads -- NOT a hardcoded 1080.
## Control.get_viewport_rect() returns the enclosing Viewport's real size
## (here, the editor's own viewport the MCP test runner renders into), not
## the size of the plain Control LayoutFrame.stand_up() wraps the scene in,
## so a hardcoded screen width silently disagreed with what the panel
## itself measured and failed on any editor window that wasn't exactly
## 1080px wide (fix round 2, F4).
func test_the_panel_never_grows_past_its_own_width() -> void:
	var frame := track(LayoutFrame.stand_up(SCENE_PATH, Vector2(1080, 1920))) as Control
	var panel := frame.get_child(0) as TutorialPanel
	panel.reset_size()
	var panel_width: float = minf(
		panel.get_viewport_rect().size.x * panel.width_fraction, panel.max_width)
	assert_true(panel.size.x <= panel_width + 0.5,
		"panel is %.1fpx wide; expected at most %.1fpx (min(viewport width * width_fraction, max_width))"
		% [panel.size.x, panel_width])


func test_show_step_fills_all_three_labels() -> void:
	var panel := _make()
	panel.show_step("Judul", "Isi penjelasan.", "Ketuk untuk lanjut")
	assert_eq(panel.get_node("Frame/Margin/Layout/TitleLabel").text, "Judul")
	assert_eq(panel.get_node("Frame/Margin/Layout/BodyLabel").text, "Isi penjelasan.")
	assert_eq(panel.get_node("Frame/Margin/Layout/PromptLabel").text, "Ketuk untuk lanjut")


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

	var margin := panel.get_node("Frame/Margin") as MarginContainer
	assert_eq(margin.get_theme_constant("margin_left"), 30)
	assert_eq(margin.get_theme_constant("margin_top"), 30)
	assert_eq(margin.get_theme_constant("margin_right"), 30)
	assert_eq(margin.get_theme_constant("margin_bottom"), 30)
	assert_eq((panel.get_node("Frame/Margin/Layout") as VBoxContainer).get_theme_constant("separation"), 20)
	assert_eq((panel.get_node("Frame/Margin/Layout/TitleLabel") as Label).theme_type_variation, &"H2Label")
	assert_eq((panel.get_node("Frame/Margin/Layout/BodyLabel") as Label).theme_type_variation, &"")
	assert_eq((panel.get_node("Frame/Margin/Layout/PromptLabel") as Label).theme_type_variation, &"CaptionLabel")


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


# --------------------------------------------------- head badge and its modes

func test_the_badge_nodes_sit_above_the_title() -> void:
	var panel := _make()
	for path: String in BADGE_NODES:
		assert_not_null(panel.get_node_or_null(LAYOUT + path), "missing node: " + path)
	var title_index := panel.get_node(LAYOUT + "TitleLabel").get_index()
	for badge: String in ["StepPill", "NamePlate"]:
		assert_true(panel.get_node(LAYOUT + badge).get_index() < title_index,
			badge + " heads the card, above the title")


func test_mode_is_an_export_and_toggles_the_pill_and_the_plate() -> void:
	var panel := _make()
	var exported := false
	for prop: Dictionary in panel.get_property_list():
		if prop["name"] == "mode" and (int(prop["usage"]) & PROPERTY_USAGE_EDITOR) != 0:
			exported = true
	assert_true(exported, "mode is an @export, so the scene can pick its badge")
	assert_eq(panel.mode, TutorialPanel.Mode.STEP, "a card starts as a tutorial step")
	var pill := panel.get_node(LAYOUT + "StepPill") as Control
	var plate := panel.get_node(LAYOUT + "NamePlate") as Control
	assert_true(pill.visible, "STEP shows the pill")
	assert_false(plate.visible, "and not the name plate")
	panel.mode = TutorialPanel.Mode.HEADMASTER
	assert_true(plate.visible, "HEADMASTER shows the name plate")
	assert_false(pill.visible, "and not the pill")
	panel.mode = TutorialPanel.Mode.STEP
	assert_true(pill.visible, "switching back shows the pill again")
	assert_false(plate.visible)


func test_show_step_with_a_single_step_hides_the_pill_and_three_shows_it() -> void:
	var panel := _make()
	var pill := panel.get_node(LAYOUT + "StepPill") as Control
	var label := panel.get_node(LAYOUT + "StepPill/StepLabel") as Label
	panel.show_step("Judul", "Isi", "Ketuk", 1, 1)
	assert_false(pill.visible, "one step has nothing to count")
	panel.show_step("Judul", "Isi", "Ketuk", 2, 3)
	assert_true(pill.visible, "three steps show the pill")
	assert_eq(label.text, "Langkah 2 / 3")
	panel.show_step("Judul", "Isi", "Ketuk")
	assert_false(pill.visible, "the three-argument call shows no pill")


func test_show_beat_shows_the_name_plate_with_the_speaker() -> void:
	var panel := _make()
	var pill := panel.get_node(LAYOUT + "StepPill") as Control
	var plate := panel.get_node(LAYOUT + "NamePlate") as Control
	panel.show_beat("Pak Kepala Sekolah", "Selamat!", "Naik ke Kelas 8.", "Ketuk untuk lanjut")
	assert_eq(panel.mode, TutorialPanel.Mode.HEADMASTER)
	assert_true(plate.visible, "a beat shows the name plate")
	assert_false(pill.visible, "and no step pill")
	assert_eq((panel.get_node(LAYOUT + "NamePlate/Row/SpeakerLabel") as Label).text,
		"Pak Kepala Sekolah")
	assert_eq((panel.get_node(LAYOUT + "TitleLabel") as Label).text, "Selamat!")
	assert_eq((panel.get_node(LAYOUT + "BodyLabel") as Label).text, "Naik ke Kelas 8.")
	assert_eq((panel.get_node(LAYOUT + "PromptLabel") as Label).text, "Ketuk untuk lanjut")
	panel.show_step("Judul", "Isi", "Ketuk", 2, 3)
	assert_eq(panel.mode, TutorialPanel.Mode.STEP, "a step after a beat is a step again")
	assert_true(pill.visible)
	assert_false(plate.visible)


func test_the_badge_nodes_carry_no_theme_overrides_beyond_layout_constants() -> void:
	var src := FileAccess.get_file_as_string(SCENE_PATH)
	var checked := 0
	for block in src.split("[node "):
		for node_name in ["StepPill", "StepLabel", "NamePlate", "Row", "Icon", "SpeakerLabel"]:
			if not block.begins_with('name="%s"' % node_name):
				continue
			checked += 1
			for line in block.split("\n"):
				if not line.begins_with("theme_override_"):
					continue
				var is_layout := line.begins_with("theme_override_constants/separation") \
					or line.begins_with("theme_override_constants/margin")
				assert_true(is_layout, "%s carries a styling override: %s" % [node_name, line])
	assert_eq(checked, 6, "all six badge nodes were checked, so this scan is not vacuous")


func test_the_badges_wear_the_variations_the_baked_theme_declares() -> void:
	var panel := _make()
	assert_eq((panel.get_node(LAYOUT + "StepPill") as Control).theme_type_variation,
		&"TutorialStepPill")
	assert_eq((panel.get_node(LAYOUT + "StepPill/StepLabel") as Label).theme_type_variation,
		&"TutorialStepPillLabel")
	assert_eq((panel.get_node(LAYOUT + "NamePlate") as Control).theme_type_variation,
		&"TutorialNamePlate")
	assert_eq((panel.get_node(LAYOUT + "NamePlate/Row/SpeakerLabel") as Label).theme_type_variation,
		&"TutorialNamePlateLabel")
	var baked := ResourceLoader.load(THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for variation: String in BADGE_VARIATIONS:
		assert_true(baked.get_type_list().has(variation),
			"%s must be in the baked theme -- rebake" % variation)


## The badges sit over a forced flow: a tap that lands on one must reach the
## caller's own tap handling, not stop at a PanelContainer that defaults to
## catching the mouse.
func test_the_badges_let_taps_through() -> void:
	var panel := _make()
	for path: String in BADGE_NODES:
		assert_eq((panel.get_node(LAYOUT + path) as Control).mouse_filter,
			Control.MOUSE_FILTER_IGNORE, path + " must ignore the mouse")


func test_the_name_plate_carries_the_school_glyph() -> void:
	assert_true(ResourceLoader.exists(SCHOOL_GLYPH_PATH),
		SCHOOL_GLYPH_PATH + " is missing or not imported -- scan")
	var icon := _make().get_node(LAYOUT + "NamePlate/Row/Icon") as TextureRect
	assert_true(icon.texture != null, "the plate's icon has a texture")
	if icon.texture != null:
		assert_eq(icon.texture.resource_path, SCHOOL_GLYPH_PATH)


func test_the_badges_are_authored_not_built_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	for type_name in ["Label", "PanelContainer", "HBoxContainer", "TextureRect", "Control"]:
		assert_false(src.contains(type_name + ".new("),
			"TutorialPanel.gd builds a %s at runtime" % type_name)


# ------------------------------------------------------- entrance and exit

func test_the_entrance_and_exit_use_the_shared_springs() -> void:
	var src := FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	assert_contains(src, "func play_in() -> void:")
	assert_contains(src, "func play_out() -> Tween:")
	assert_contains(src, "Juice.pop_in(self)")
	assert_contains(src, "AnimUtils.popup_spring_out(self, self)")
	assert_contains(src, "Engine.is_editor_hint()")


func test_the_springs_do_nothing_in_the_editor() -> void:
	if not Engine.is_editor_hint():
		return
	var panel := _make()
	panel.play_in()
	assert_eq(panel.scale, Vector2.ONE, "play_in leaves the card alone in the editor")
	assert_eq(panel.modulate.a, 1.0)
	var tween := panel.play_out()
	assert_true(tween != null, "play_out still hands back a tween to await")
	assert_eq(panel.scale, Vector2.ONE, "and leaves the card alone")
	assert_eq(panel.modulate.a, 1.0)


# ------------------------------------------------------------- the arrow

func test_the_arrow_is_an_authored_scene_180_square_by_default() -> void:
	assert_true(ResourceLoader.exists(ARROW_SCENE_PATH), ARROW_SCENE_PATH + " is missing")
	var arrow := (load(ARROW_SCENE_PATH) as PackedScene).instantiate() as Control
	Engine.get_main_loop().root.add_child(arrow)
	track(arrow)
	assert_eq(arrow.arrow_size, Vector2(180, 180), "the arrow is 180 by 180 by default")
	var visual := arrow.get_node_or_null("Visual") as TextureRect
	assert_true(visual != null, "the picture is an authored Visual child")
	if visual == null:
		return
	assert_true(visual.texture != null, "the picture has its texture")
	assert_eq(visual.size, Vector2(180, 180))
	assert_eq(visual.position, Vector2(-90, -180), "the tip hangs at the origin")
	assert_eq(arrow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the arrow never takes a tap")
	assert_eq(visual.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_arrow_size_knob_resizes_the_picture_about_its_tip() -> void:
	var arrow := (load(ARROW_SCENE_PATH) as PackedScene).instantiate() as Control
	Engine.get_main_loop().root.add_child(arrow)
	track(arrow)
	arrow.arrow_size = Vector2(100, 120)
	var visual := arrow.get_node("Visual") as TextureRect
	assert_eq(visual.size, Vector2(100, 120))
	assert_eq(visual.position, Vector2(-50, -120), "still centred over the tip")
	assert_eq(visual.pivot_offset, Vector2(50, 120), "and it turns about the tip")


func test_the_arrow_flips_to_point_up_and_back() -> void:
	var arrow := (load(ARROW_SCENE_PATH) as PackedScene).instantiate() as Control
	Engine.get_main_loop().root.add_child(arrow)
	track(arrow)
	var visual := arrow.get_node("Visual") as TextureRect
	arrow.set_direction(true)
	assert_eq(visual.rotation_degrees, 180.0, "pointing up turns the picture over")
	arrow.set_direction(false)
	assert_eq(visual.rotation_degrees, 0.0, "pointing down turns it back")


func test_the_arrow_script_builds_nothing() -> void:
	var src := FileAccess.get_file_as_string(ARROW_SCRIPT_PATH)
	assert_false(src.contains(".new("), "TutorialArrow.gd no longer builds a visual node")
	assert_contains(src, "@tool", "the scene's size knob has to run in the editor")
	assert_contains(src, "Engine.is_editor_hint()", "and the bounce must not")


func test_every_caller_instances_the_arrow_scene() -> void:
	for path: String in ARROW_CALLERS:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, ARROW_SCENE_PATH, "%s should preload the arrow scene" % path)
		assert_false(src.contains("TutorialArrow.new("),
			"%s still builds the arrow from its script" % path)
