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
		assert_eq(frame.title_text, root.get("step_sticker_text"),
			"the scene's authored sticker is the STEP default, so it reads right before any show_step()")
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


## A promotion's congratulation is a story beat, not a lesson (spec 1b), so the
## frame's sticker must not keep saying TUTORIAL over it: a player with
## tutorials off would read a story beat labelled as one.
func test_the_sticker_follows_the_mode() -> void:
	var panel := _make()
	var frame := panel.get_node("Frame") as NotebookFrame
	var sticker := frame.get_node("Chrome/Sticker") as Control
	var label := frame.get_node("Chrome/Sticker/Title") as Label
	assert_eq(frame.title_text, "TUTORIAL", "a card starts as a tutorial step")
	panel.show_beat("Pak Kepala Sekolah", "Selamat!", "Naik ke Kelas 8.", "Ketuk")
	assert_eq(frame.title_text, "PENGUMUMAN", "a beat is an announcement")
	assert_eq(label.text, "PENGUMUMAN", "and the sticker's own label says so")
	assert_true(sticker.visible, "the sticker stays")
	panel.show_step("Judul", "Isi", "Ketuk", 2, 3)
	assert_eq(frame.title_text, "TUTORIAL", "the next step is a tutorial again")
	assert_eq(label.text, "TUTORIAL")
	panel.show_beat("Pak Kepala Sekolah", "Selamat!", "Naik ke Kelas 8.", "Ketuk")
	panel.mode = TutorialPanel.Mode.STEP
	assert_eq(frame.title_text, "TUTORIAL", "switching the mode back does it too")


func test_the_sticker_texts_are_exports_that_apply_live() -> void:
	var panel := _make()
	for export_name: String in ["step_sticker_text", "beat_sticker_text"]:
		var exported := false
		for prop: Dictionary in panel.get_property_list():
			if prop["name"] == export_name and (int(prop["usage"]) & PROPERTY_USAGE_EDITOR) != 0:
				exported = true
		assert_true(exported, export_name + " is an @export on the panel root, so a scene can set it")
	assert_eq(panel.step_sticker_text, "TUTORIAL")
	assert_eq(panel.beat_sticker_text, "PENGUMUMAN")
	var frame := panel.get_node("Frame") as NotebookFrame
	panel.beat_sticker_text = "KABAR"
	assert_eq(frame.title_text, "TUTORIAL", "changing the beat's text leaves a step's sticker alone")
	panel.show_beat("Pak Kepala Sekolah", "Selamat!", "Naik ke Kelas 8.", "Ketuk")
	assert_eq(frame.title_text, "KABAR", "the beat wears its own text")
	panel.beat_sticker_text = "SAMBUTAN"
	assert_eq(frame.title_text, "SAMBUTAN", "and a change while it shows lands at once")
	panel.step_sticker_text = "PANDUAN"
	assert_eq(frame.title_text, "SAMBUTAN", "a step's text does not touch a beat")
	panel.show_step("Judul", "Isi", "Ketuk")
	assert_eq(frame.title_text, "PANDUAN")


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


## The headmaster's beat is the first flow that taps through cards quickly. A tap
## that lands while the entrance spring (or the step-change fade) is still playing
## calls play_out() over it; unless play_out() stopped them, the entrance would go
## on to fade the card back in over its own exit.
func test_play_out_stops_an_entrance_and_a_step_change_still_playing() -> void:
	var panel := _make()
	var entrance := panel.create_tween()
	entrance.tween_interval(30.0)
	var fade := panel.create_tween()
	fade.tween_interval(30.0)
	panel._entrance_tween = entrance
	panel._step_tween = fade
	assert_true(entrance.is_valid() and fade.is_valid(), "both are running before the exit")
	var exit := panel.play_out()
	assert_false(entrance.is_valid(), "the exit stops the entrance")
	assert_false(fade.is_valid(), "and the step-change fade")
	assert_true(exit != null and exit != entrance and exit != fade, "it still hands back its own tween")


func test_play_out_with_nothing_playing_is_safe_and_play_in_keeps_its_spring() -> void:
	var panel := _make()
	assert_true(panel.play_out() != null, "an exit before any entrance stops nothing and does not fail")
	var src := FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	assert_contains(_function_source(src, "play_in"), "_entrance_tween = Juice.pop_in(self)",
		"play_in keeps the spring it starts, so play_out can stop it")
	var out := _function_source(src, "play_out")
	var stopped := out.find("_stop_entering()")
	var hint := out.find("Engine.is_editor_hint()")
	var spring := out.find("AnimUtils.popup_spring_out(self, self)")
	assert_true(stopped != -1 and stopped < hint and hint < spring,
		"the entrance is stopped first, in the editor too, so this suite can see it, then the exit spring")


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


# --------------------------------------- where the card and the arrow sit
#
# The three screens that spotlight a control (AturJadwal, StudentList, Lobby)
# seat their card and arrow through TutorialPanel.place_step(): the card
# against the half of the Safe/UI opposite the spot, the arrow beside the
# spot and never across the card. The geometry is pure, so it is tested here
# with the real numbers of those screens at the 1080 x 1920 design size.

## A screen's Safe/UI at 1080 x 1920: (48, 48) to (1032, 1872).
const SAFE_UI := Rect2(48, 48, 984, 1824)
## The card with a few lines of body text.
const CARD := Vector2(993, 520)
## The arrow's default picture.
const ARROW := Vector2(180, 180)
## Spots the tutorials really highlight, padded by the hole's 12px.
const REAL_SPOTS := {
	"AturJadwal stat bars": Rect2(668, 100, 348, 400),
	"AturJadwal Senin": Rect2(38, 988, 295, 291),
	"AturJadwal student splash": Rect2(-88, 33, 724, 1268),
	"StudentList card stack": Rect2(38, 340, 1004, 1434),
	"StudentList roster strip": Rect2(58, 163, 964, 174),
	"StudentList right arrow": Rect2(838, 1760, 184, 152),
	"Lobby Inventory": Rect2(560, 1640, 290, 190),
}


func _make_arrow() -> Control:
	var arrow := (load(ARROW_SCENE_PATH) as PackedScene).instantiate() as Control
	Engine.get_main_loop().root.add_child(arrow)
	track(arrow)
	return arrow


## A Control parked under the editor's root (or under `parent`), freed with the test.
func _make_control(at: Vector2, extent: Vector2, parent: Node = null) -> Control:
	var control := Control.new()
	control.position = at
	control.size = extent
	if parent == null:
		Engine.get_main_loop().root.add_child(control)
		track(control)
	else:
		parent.add_child(control)
	return control


## The source of `func_name`, plain or static, up to the next function.
func _function_source(src: String, func_name: String) -> String:
	var start := src.find("func %s(" % func_name)
	if start == -1:
		return ""
	var stop := src.length()
	for marker: String in ["\nfunc ", "\nstatic func "]:
		var at := src.find(marker, start + 1)
		if at != -1:
			stop = mini(stop, at)
	return src.substr(start, stop - start)


## The arrow's placement for `spot` with the card at `card_at`, as the screens get it, plus its picture.
func _arrow_picture(spot: Rect2, card_at: Vector2) -> Dictionary:
	var fit: Dictionary = TutorialPanel.ArrowScript.fit(spot, SAFE_UI, ARROW, Rect2(card_at, CARD))
	fit["picture"] = TutorialPanel.ArrowScript.picture_rect(fit["tip"], ARROW, fit["pointing_up"])
	return fit


func test_a_step_with_no_spot_centres_the_card() -> void:
	var at := TutorialPanel.placement(SAFE_UI, CARD, Rect2(), ARROW)
	assert_eq(at, SAFE_UI.position + (SAFE_UI.size - CARD) / 2.0, "no spot, no half to avoid")


func test_the_card_sits_on_the_half_opposite_the_spot() -> void:
	var high := TutorialPanel.placement(SAFE_UI, CARD, REAL_SPOTS["AturJadwal stat bars"], ARROW)
	assert_eq(high.y, SAFE_UI.end.y - CARD.y, "a spot in the top half puts the card at the bottom")
	var low := TutorialPanel.placement(SAFE_UI, CARD, REAL_SPOTS["Lobby Inventory"], ARROW)
	assert_eq(low.y, SAFE_UI.position.y, "a spot in the bottom half puts the card at the top")
	assert_eq(high.x, low.x, "both are centred across the safe area")


func test_the_card_always_stays_inside_the_safe_area_vertically() -> void:
	for label: String in REAL_SPOTS:
		var at := TutorialPanel.placement(SAFE_UI, CARD, REAL_SPOTS[label], ARROW)
		assert_true(at.y >= SAFE_UI.position.y and at.y + CARD.y <= SAFE_UI.end.y,
			"%s: the card at y=%d leaves the safe area" % [label, int(at.y)])


## A spot that takes most of the screen leaves the arrow nowhere but across the
## card on the card's usual half, so the card takes the other half.
func test_a_huge_spot_moves_the_card_to_the_half_where_the_arrow_can_be_clear() -> void:
	var stack := TutorialPanel.placement(SAFE_UI, CARD, REAL_SPOTS["StudentList card stack"], ARROW)
	assert_eq(stack.y, SAFE_UI.end.y - CARD.y,
		"the card stack's arrow goes above it, so the card goes to the bottom")
	var splash := TutorialPanel.placement(SAFE_UI, CARD, REAL_SPOTS["AturJadwal student splash"], ARROW)
	assert_eq(splash.y, SAFE_UI.position.y,
		"the splash's arrow goes below it, so the card goes to the top")


func test_the_arrow_is_beside_the_spot_and_off_the_card_in_every_real_step() -> void:
	for label: String in REAL_SPOTS:
		var spot: Rect2 = REAL_SPOTS[label]
		var card_at := TutorialPanel.placement(SAFE_UI, CARD, spot, ARROW)
		var placed := _arrow_picture(spot, card_at)
		var picture: Rect2 = placed["picture"]
		assert_true(placed["clear"], "%s: the arrow found a clear side" % label)
		assert_false(picture.intersects(Rect2(card_at, CARD)),
			"%s: the arrow lies across the card" % label)
		assert_false(picture.intersects(spot), "%s: the arrow lies across the spot" % label)
		assert_true(SAFE_UI.encloses(picture), "%s: the arrow leaves the safe area" % label)


func test_the_arrow_stands_above_the_spot_when_there_is_room_and_below_when_not() -> void:
	var roomy: Dictionary = TutorialPanel.ArrowScript.fit(Rect2(400, 900, 200, 100), SAFE_UI, ARROW)
	assert_false(roomy["pointing_up"], "room above: the arrow hangs above, pointing down")
	var roomy_tip: Vector2 = roomy["tip"]
	assert_eq(roomy_tip.y, 900.0 - TutorialPanel.ArrowScript.TIP_GAP, "its tip stops short of the spot's top edge")
	var cramped: Dictionary = TutorialPanel.ArrowScript.fit(Rect2(400, 100, 200, 100), SAFE_UI, ARROW)
	assert_true(cramped["pointing_up"], "no room above: it moves below the spot, pointing up")
	var cramped_tip: Vector2 = cramped["tip"]
	assert_eq(cramped_tip.y, 200.0 + TutorialPanel.ArrowScript.TIP_GAP, "its tip stops short of the bottom edge")
	assert_true(cramped["clear"])


func test_a_spot_bigger_than_the_screen_squeezes_the_arrow_in_unclear() -> void:
	var fit: Dictionary = TutorialPanel.ArrowScript.fit(Rect2(0, 0, 1080, 1920), SAFE_UI, ARROW)
	assert_false(fit["clear"], "nothing is beside a spot that fills the screen")
	var picture: Rect2 = TutorialPanel.ArrowScript.picture_rect(fit["tip"], ARROW, fit["pointing_up"])
	assert_true(SAFE_UI.grow(-TutorialPanel.ArrowScript.EDGE_MARGIN).encloses(picture),
		"it still stays on screen")


## The arrow sizes from its own arrow_size knob, not from a number the caller
## carries: the picture is the knob's size and ends short of the spot.
func test_point_at_reads_the_arrows_own_size_and_turns_the_picture() -> void:
	var arrow := _make_arrow()
	arrow.arrow_size = Vector2(100, 120)
	var visual := arrow.get_node("Visual") as TextureRect
	var spot := Rect2(400, 900, 200, 100)
	var tip: Vector2 = arrow.point_at(spot, SAFE_UI)
	var picture: Rect2 = TutorialPanel.ArrowScript.picture_rect(tip, arrow.arrow_size, false)
	assert_eq(picture.size, Vector2(100, 120), "the picture is the knob's size")
	assert_eq(picture.end.y, spot.position.y - TutorialPanel.ArrowScript.TIP_GAP, "and ends short of the spot")
	assert_eq(visual.rotation_degrees, 0.0, "pointing down")
	arrow.point_at(Rect2(400, 100, 200, 100), SAFE_UI)
	assert_eq(visual.rotation_degrees, 180.0, "a spot at the top turns it over, below the spot")


func test_point_at_keeps_off_the_rectangle_it_is_told_to_avoid() -> void:
	var arrow := _make_arrow()
	var spot := Rect2(400, 900, 200, 100)
	var card := Rect2(0, 600, 1080, 280)
	var tip: Vector2 = arrow.point_at(spot, SAFE_UI, card)
	var picture: Rect2 = TutorialPanel.ArrowScript.picture_rect(tip, arrow.arrow_size, true)
	assert_false(picture.intersects(card), "the card is in the way above, so the arrow goes below")
	assert_eq(tip.y, spot.end.y + TutorialPanel.ArrowScript.TIP_GAP)


func test_spot_in_frames_the_controls_in_the_overlays_space() -> void:
	var overlay := _make_control(Vector2(10, 20), Vector2(1080, 1920))
	var first := _make_control(Vector2(100, 200), Vector2(50, 40), overlay)
	var second := _make_control(Vector2(300, 100), Vector2(20, 30), overlay)
	assert_eq(TutorialPanel.spot_in([first, second], overlay, 0.0), Rect2(100, 100, 220, 140),
		"the rectangle that holds both, in the overlay's own coordinates")
	assert_eq(TutorialPanel.spot_in([first], overlay, 12.0), Rect2(88, 188, 74, 64),
		"the hole stands the padding off the control")
	assert_eq(TutorialPanel.spot_in([first], overlay).size,
		Vector2(50, 40) + Vector2(2, 2) * TutorialPanel.SPOT_PADDING,
		"the padding defaults to SPOT_PADDING")


func test_spot_in_frames_a_tilted_control_whole() -> void:
	var overlay := _make_control(Vector2.ZERO, Vector2(1080, 1920))
	var tilted := _make_control(Vector2(100, 200), Vector2(50, 40), overlay)
	tilted.rotation = PI / 2.0
	var spot := TutorialPanel.spot_in([tilted], overlay, 0.0)
	assert_true(spot.position.is_equal_approx(Vector2(60, 200)),
		"a quarter turn about the corner puts the control left of it: %s" % spot.position)
	assert_true(spot.size.is_equal_approx(Vector2(40, 50)),
		"and swaps its width and height: %s" % spot.size)


func test_spot_in_skips_what_is_not_a_live_control_and_is_empty_for_none() -> void:
	var overlay := _make_control(Vector2.ZERO, Vector2(1080, 1920))
	var gone := Control.new()
	gone.free()
	var not_a_control := Node.new()
	track(not_a_control)
	assert_false(TutorialPanel.spot_in([], overlay).has_area(), "no targets, no spot")
	assert_false(TutorialPanel.spot_in([gone, not_a_control, null], overlay).has_area(),
		"a freed control, a plain node and null are skipped")


func test_cut_hole_writes_the_hole_into_the_overlays_spotlight() -> void:
	var overlay := ColorRect.new()
	var spotlight := ShaderMaterial.new()
	spotlight.shader = load("res://Scripts/Shaders/spotlight.gdshader") as Shader
	overlay.material = spotlight
	Engine.get_main_loop().root.add_child(overlay)
	track(overlay)
	var control := _make_control(Vector2(100, 200), Vector2(50, 40), overlay)
	assert_true(TutorialPanel.cut_hole(overlay, [control], 12.0))
	assert_eq(spotlight.get_shader_parameter("hole_pos"), Vector2(88, 188))
	assert_eq(spotlight.get_shader_parameter("hole_size"), Vector2(74, 64))
	assert_false(TutorialPanel.cut_hole(overlay, [], 12.0), "nothing to frame: nothing cut")
	var bare := ColorRect.new()
	Engine.get_main_loop().root.add_child(bare)
	track(bare)
	assert_false(TutorialPanel.cut_hole(bare, [control], 12.0), "no spotlight material: nothing cut")


func test_mount_seats_the_card_under_the_click_catcher_and_empties_it() -> void:
	var overlay := _make_control(Vector2.ZERO, Vector2(1080, 1920))
	var other := _make_control(Vector2.ZERO, Vector2(10, 10), overlay)
	var catcher := Button.new()
	overlay.add_child(catcher)
	var panel := TutorialPanel.mount(load(SCENE_PATH) as PackedScene, overlay, catcher)
	assert_eq(String(panel.name), "TutorialPanel")
	assert_eq(panel.get_parent(), overlay)
	assert_eq(panel.get_index(), other.get_index() + 1, "the card joins just after the other children")
	assert_eq(catcher.get_index(), panel.get_index() + 1, "and the click catcher stays above it")
	assert_false(panel.step_pill.visible, "the scene's sample pill stays hidden until a real step")
	assert_eq(panel.prompt_label.text, TutorialPanel.DEFAULT_PROMPT)


# ---------------------------------------------------- the wrong-tap answer

func test_a_wrong_tap_plays_the_error_cue_shakes_the_target_and_dims_the_others() -> void:
	var src := FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	var body := _function_source(src, "answer_wrong_tap")
	assert_false(body.is_empty(), "answer_wrong_tap was found")
	assert_contains(body, 'AudioDirector.play_sfx(&"error")', "the error cue plays")
	assert_contains(body, "Juice.shake(target)", "the control the step wants shakes")
	assert_contains(body, "dim_others(", "the others dim")
	assert_contains(body, "ANSWERING_META",
		"a second tap mid-answer repeats the cue but does not start a second shake")
	assert_false(body.contains(".text"), "no text scolding: the motion says it")


func test_the_dim_returns_each_control_to_the_colour_it_had() -> void:
	var src := FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	var body := _function_source(src, "dim_others")
	assert_contains(body, 'tween_property(node, "modulate", origin,',
		"the last leg of the dim is back to the remembered colour")
	assert_contains(body, "remove_meta", "and the memory is dropped once it is restored")


func test_dim_others_remembers_the_true_colour_and_spares_the_target() -> void:
	var row := _make_control(Vector2.ZERO, Vector2(400, 100))
	var target := Button.new()
	var near := Button.new()
	row.add_child(target)
	row.add_child(near)
	var gone := Button.new()
	gone.free()
	var real := Color(1.0, 0.5, 0.25, 0.8)
	near.modulate = real
	TutorialPanel.dim_others([target, near, gone, null], target)
	assert_false(target.has_meta(TutorialPanel.DIM_ORIGIN_META), "the control the step wants is spared")
	assert_eq(near.get_meta(TutorialPanel.DIM_ORIGIN_META), real, "the real colour is remembered")
	near.modulate = Color(0.1, 0.1, 0.1, 0.1)  # a second wrong tap, mid-dim
	TutorialPanel.dim_others([near])
	assert_eq(near.get_meta(TutorialPanel.DIM_ORIGIN_META), real,
		"a dim begun mid-dim still restores the real colour, not the dimmed one")


func test_sibling_buttons_are_the_visible_other_buttons() -> void:
	var row := _make_control(Vector2.ZERO, Vector2(400, 100))
	var target := Button.new()
	var near := Button.new()
	var hidden := Button.new()
	hidden.visible = false
	var label := Label.new()
	for child: Control in [target, near, hidden, label]:
		row.add_child(child)
	var found := TutorialPanel.sibling_buttons(target)
	assert_eq(found.size(), 1, "the hidden button and the label are not candidates")
	assert_true(found.has(near))
	var lone := Button.new()
	assert_eq(TutorialPanel.sibling_buttons(lone).size(), 0, "a control with no parent has no siblings")
	lone.free()


# ----------------------------------------------- the arrow callers' sizing

func test_no_arrow_caller_hard_codes_the_arrow_size() -> void:
	for path: String in ARROW_CALLERS:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("320.0"), "%s still clamps with a 320 arrow" % path)
		assert_false(src.contains("var W =") or src.contains("var H ="),
			"%s still carries its own arrow width and height" % path)


func test_every_arrow_caller_places_the_arrow_from_its_own_size() -> void:
	var panel_src := FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	var place := _function_source(panel_src, "place_step")
	assert_contains(place, "arrow.arrow_size", "place_step reads the arrow's own size")
	assert_contains(place, "arrow.point_at(spot, bounds, Rect2(panel.position, panel.size))",
		"and points it clear of the card")
	for path: String in ["res://Scripts/AturJadwal/AturJadwal.gd",
			"res://Scripts/StudentList/StudentList.gd", "res://Scripts/Lobby/Lobby.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "TutorialPanel.place_step(_tutorial_panel, tutorial_safe_ui, color_rect,",
			"%s seats its card and arrow through place_step" % path)
	var card_src := FileAccess.get_file_as_string(STUDENT_CARD_PATH)
	assert_contains(card_src, "_tutorial_arrow.point_at(", "StudentCard points its arrow the same way")


# ------------------------------------------------ the card never takes a tap
#
# The old runtime panels ignored the mouse throughout. The shared card is a
# NotebookFrame, whose root STOPs taps and whose Cover PASSes them (both right
# for a popup), so a mounted card swallowed a tap wherever it sat -- and the
# placement tests above put it over the forced target at AturJadwal's "Pilih
# Murid" (the splash) and StudentList's last step (the lower card). At a forced
# step the caller's click catcher is IGNORE, so the tap has to reach the
# control under the card; nothing on the card ever needs to take one.

func test_no_control_in_the_card_takes_a_tap() -> void:
	var panel := _make()
	var everyone: Array[Node] = [panel]
	everyone.append_array(panel.find_children("*", "Control", true, false))
	var catching: Array[String] = []
	for node: Node in everyone:
		var filter := (node as Control).mouse_filter
		if filter != Control.MOUSE_FILTER_IGNORE:
			catching.append("%s (filter %d)" % [panel.get_path_to(node), filter])
	assert_true(everyone.size() > 20,
		"the walk reached the frame's own chrome (%d controls), so this is not vacuous" % everyone.size())
	assert_true(catching.is_empty(), "these still take a tap: " + ", ".join(catching))


func test_the_frames_cover_and_hidden_buttons_are_covered_by_the_walk() -> void:
	var panel := _make()
	for path: String in ["Frame", "Frame/Margin", "Frame/Chrome/Cover", "Frame/Chrome/Close",
			"Frame/Chrome/Tabs/Tab0", "Frame/Chrome/Sticker"]:
		var control := panel.get_node_or_null(path) as Control
		assert_not_null(control, "missing " + path)
		if control != null:
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, path + " lets a tap through")


## The Frame and its Margin are the scene's own nodes, so the scene says it
## (an override on an instance ROOT serialises); everything below the frame's
## root is the NotebookFrame scene's, so TutorialPanel._let_taps_through does it.
func test_the_scene_authors_the_frame_and_margin_as_tap_through() -> void:
	var src := FileAccess.get_file_as_string(SCENE_PATH)
	for header: String in ['[node name="Frame" parent="."',
			'[node name="Margin" type="MarginContainer" parent="Frame"']:
		var at := src.find(header)
		assert_true(at != -1, header + " is in the scene")
		var block := src.substr(at, src.find("\n[node", at + 1) - at)
		assert_true(block.contains("mouse_filter = 2"), header + " is authored IGNORE")
	var code := FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	assert_contains(_function_source(code, "_ready"), "_let_taps_through(self)",
		"and _ready sweeps the rest -- with no editor-hint gate, so the suites see it")
	assert_false(_function_source(code, "_let_taps_through").contains("is_editor_hint"))


# ------------------------------------- an arrow that keeps off a card it does not place

## StudentCard centres its card down the screen from step 7 on, so an arrow
## hung above a spot below the card can land on it. The arrow takes the card's
## rectangle to keep off, the way the three spotlight screens' arrows do.
func test_point_at_moves_below_a_spot_when_the_card_is_centred_above_it() -> void:
	var arrow := _make_arrow()
	var screen := Rect2(0, 0, 1080, 1920)
	var spot := Rect2(400, 1300, 200, 150)
	var card := Rect2(43.5, 700, 993, 520)
	var unaware: Vector2 = arrow.point_at(spot, screen)
	assert_eq(unaware.y, spot.position.y - TutorialPanel.ArrowScript.TIP_GAP,
		"without the card the arrow hangs above the spot")
	var unaware_picture: Rect2 = TutorialPanel.ArrowScript.picture_rect(unaware, arrow.arrow_size, false)
	assert_true(unaware_picture.intersects(card), "which is across a card centred above the spot")
	var tip: Vector2 = arrow.point_at(spot, screen, card)
	var picture: Rect2 = TutorialPanel.ArrowScript.picture_rect(tip, arrow.arrow_size, true)
	assert_false(picture.intersects(card), "told where the card is, it stands below the spot instead")
	assert_eq(tip.y, spot.end.y + TutorialPanel.ArrowScript.TIP_GAP)
	assert_eq(arrow.get_node("Visual").rotation_degrees, 180.0, "pointing up at the spot")


# ---------------------------------------------- the final review's fix wave

## Every screen whose tutorial copy and tap prompt share the panel's one line.
const PROMPT_SCREENS := [
	"res://Scripts/StudentCard/StudentCard.gd",
	"res://Scripts/StudentCard/HeadmasterBeat.gd",
	"res://Scripts/StudentList/StudentList.gd",
	"res://Scripts/AturJadwal/AturJadwal.gd",
	"res://Scripts/SchoolSimulation/SchoolDay.gd",
	"res://Scripts/Lobby/Lobby.gd",
	"res://Scripts/UI/TutorialPanel.gd",
]


## Every "tap anywhere" card says one thing, in standard Indonesian: the headmaster's
## beat and the pick step after it used to show two different prompts back to back,
## and the rest said an English "CLICK" or "KLIK" with a run-together "dimana".
func test_the_tap_prompt_is_one_line_in_standard_indonesian() -> void:
	assert_eq(TutorialPanel.DEFAULT_PROMPT, "KETUK DI MANA SAJA UNTUK LANJUT")
	assert_eq(HeadmasterBeat.PROMPT, TutorialPanel.DEFAULT_PROMPT,
		"the beat's card and the pick step after it ask for the tap in the same words")
	for path: String in PROMPT_SCREENS:
		var src := FileAccess.get_file_as_string(path)
		for drift: String in ["CLICK DIMANA", "KLIK DIMANA", "DIMANA SAJA", "KETUK MANA SAJA"]:
			assert_false(src.contains(drift), "%s still says \"%s\"" % [path, drift])
	var card_src := FileAccess.get_file_as_string(STUDENT_CARD_PATH)
	assert_eq(card_src.count("TutorialPanel.DEFAULT_PROMPT"), 2,
		"StudentCard's empty card and its default step both use the panel's constant")
	assert_contains(FileAccess.get_file_as_string("res://Scripts/AturJadwal/AturJadwal.gd"),
		"prompt_lbl.text = TutorialPanel.DEFAULT_PROMPT", "so does AturJadwal's holiday card")
	assert_contains(FileAccess.get_file_as_string(SCHOOL_DAY_PATH),
		"@export var end_tutorial_prompt: String = \"KETUK DI MANA SAJA UNTUK MELANJUTKAN\"",
		"SchoolDay's end-of-week card says the same, in its longer form")


## The tutorial bodies shipped with "Disini" and "Silahkan" (standard: "di sini",
## "silakan"), and the Lobby's with "dimana".
func test_no_tutorial_text_says_disini_silahkan_or_dimana() -> void:
	for path: String in PROMPT_SCREENS:
		var src := FileAccess.get_file_as_string(path)
		for drift: String in ["Disini", "disini", "Silahkan", "silahkan", "dimana", "Dimana"]:
			assert_false(src.contains(drift), "%s still says \"%s\"" % [path, drift])


const NOTEBOOK_FRAME_PATH := "res://Scenes/UI/NotebookFrame.tscn"

## NotebookFrame.tscn floors every frame at 640 x 520, which suits a popup and
## left a short coach-mark step a band of empty ruled page. The card's own Frame
## carries a lower floor on the instance (the popups keep the scene's).
func test_the_cards_frame_floor_is_below_the_popup_default() -> void:
	var popup := (load(NOTEBOOK_FRAME_PATH) as PackedScene).instantiate() as NotebookFrame
	track(popup)
	var card := (load(SCENE_PATH) as PackedScene).instantiate()
	track(card)
	var frame := card.get_node("Frame") as NotebookFrame
	assert_true(popup.custom_minimum_size.y >= 520.0,
		"the popup default is still 520 tall, so the popups are untouched (and this is not vacuous)")
	assert_true(frame.custom_minimum_size.y < popup.custom_minimum_size.y,
		"the card's frame floor (%.0f) is below the popup's (%.0f)"
		% [frame.custom_minimum_size.y, popup.custom_minimum_size.y])
	var src := FileAccess.get_file_as_string(SCENE_PATH)
	var at := src.find('[node name="Frame" parent="."')
	var block := src.substr(at, src.find("\n[node", at + 1) - at)
	assert_contains(block, "custom_minimum_size",
		"the override is on the Frame instance's root, the one place an instance override serialises")


## A short step's card is shorter than the popup floor, and a long one still
## grows it past the short one (so the lower floor did not cap the card).
func test_a_short_step_makes_a_card_shorter_than_the_popup_floor() -> void:
	var popup := (load(NOTEBOOK_FRAME_PATH) as PackedScene).instantiate() as NotebookFrame
	track(popup)
	var frame := track(LayoutFrame.stand_up(SCENE_PATH, Vector2(1080, 1920))) as Control
	var panel := frame.get_child(0) as TutorialPanel
	panel.show_step("Pilihan Bagus!", "Pilihan yang sangat bagus!", TutorialPanel.DEFAULT_PROMPT, 1, 5)
	panel.reset_size()
	LayoutFrame.settle(panel)
	var short_height := panel.get_combined_minimum_size().y
	assert_true(short_height < popup.custom_minimum_size.y,
		"a one-line step's card is %.0f tall; it must be under the popup floor of %.0f"
		% [short_height, popup.custom_minimum_size.y])
	panel.show_step("Judul", "Kalimat yang panjang sekali. ".repeat(24), TutorialPanel.DEFAULT_PROMPT, 2, 5)
	panel.reset_size()
	LayoutFrame.settle(panel)
	assert_true(panel.get_combined_minimum_size().y > short_height + 100.0,
		"a long step's card still grows with its text")
