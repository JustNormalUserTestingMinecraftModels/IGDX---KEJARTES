@tool
extends McpTestSuite

## The minigame mobile-layout kit (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 3):
## its icons, theme variations, tray, hint pill, how-to rows and resources.
## Each piece is pinned by the task that adds it. Must be @tool, and no
## test here may be a coroutine.

const ICON_DIR := "res://Assets/Images/UI/Icons/"
## Every placeholder pictogram the layout kit points at.
const KIT_ICONS: Array[String] = ["pause", "timer", "swipe_up", "howto_tap",
	"howto_swipe", "howto_drag", "howto_read", "howto_timer", "howto_target"]


func suite_name() -> String:
	return "minigame_layout_kit"


func test_every_kit_icon_exists() -> void:
	for icon: String in KIT_ICONS:
		var path := ICON_DIR + icon + ".svg"
		assert_true(ResourceLoader.exists(path), path + " is a kit icon")


func test_every_kit_icon_is_listed_in_the_readme() -> void:
	var readme := FileAccess.get_file_as_string(ICON_DIR + "README.md")
	for icon: String in KIT_ICONS:
		assert_contains(readme, "`" + icon + ".svg`", icon + " has a README row")


const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## variation -> the base type it must extend.
const LAYOUT_VARIATIONS := {
	"MinigameProgressBar": "ProgressBar",
	"MinigameProgressLabel": "Label",
	"MinigameTrayPanel": "Panel",
	"MinigameHintLabel": "Label",
	"MinigameHintPillPanel": "Panel",
	"MinigameHowToLabel": "Label",
}


func _theme() -> Theme:
	return ThemeFactory.build(DesignTokens.load_default())


func test_layout_variations_exist_with_their_base() -> void:
	var theme := _theme()
	for name: String in LAYOUT_VARIATIONS:
		assert_eq(String(theme.get_type_variation_base(name)), LAYOUT_VARIATIONS[name],
			name + " extends " + LAYOUT_VARIATIONS[name])


func test_hints_and_how_to_lines_use_the_body_face_at_36() -> void:
	var theme := _theme()
	var tokens := DesignTokens.load_default()
	for name: String in ["MinigameHintLabel", "MinigameHowToLabel"]:
		assert_eq(theme.get_font_size("font_size", name), tokens.font_title, name + " is 36")
		# get_font_list, not has_font: has_font is also true with a default font.
		assert_false(theme.get_font_list(name).has("font"), name + " keeps the body face")


func test_the_progress_label_is_display_face_at_the_dense_rung() -> void:
	var theme := _theme()
	var tokens := DesignTokens.load_default()
	assert_eq(theme.get_font_size("font_size", "MinigameProgressLabel"), tokens.font_body_size)
	assert_eq(theme.get_font("font", "MinigameProgressLabel"), tokens.font_display)


func test_the_tray_plank_bleeds_past_its_rect() -> void:
	var box := _theme().get_stylebox("panel", "MinigameTrayPanel") as StyleBoxFlat
	assert_true(box != null, "the tray plank is a StyleBoxFlat")
	if box == null:
		return
	assert_true(box.expand_margin_bottom > 0.0 and box.expand_margin_left > 0.0,
		"the plank draws past the safe area to the screen edges")
	assert_eq(box.corner_radius_bottom_left, 0, "square bottom corners")


func test_the_hud_icon_button_is_lipped() -> void:
	var box := _theme().get_stylebox("normal", "MinigameHudIconButton")
	assert_true(LippedBox.is_lipped(box), "the pause/timer chrome is a lipped face")


const LayoutFrame := preload("res://tests/layout_frame.gd")
const TRAY := "res://Scenes/Minigames/UI/MinigameTray.tscn"
const PILL := "res://Scenes/Minigames/UI/MinigameHintPill.tscn"


func _tray_with(children: int) -> MinigameTray:
	var tray := (load(TRAY) as PackedScene).instantiate() as MinigameTray
	for i in children:
		var c := Control.new()
		c.custom_minimum_size = Vector2(0, 100)
		tray.add_child(c)
	var frame := Control.new()
	frame.size = Vector2(984, 1000)
	frame.theme = load(THEME_PATH)
	frame.add_child(tray)
	Engine.get_main_loop().root.add_child(frame)
	track(frame)
	tray.size = Vector2(984, tray.get_combined_minimum_size().y)
	tray.sort_now()
	return tray


func test_the_tray_stacks_host_content_above_its_hint() -> void:
	var tray := _tray_with(2)
	var hint := tray.get_node("HintLabel") as Control
	var first := tray.get_child(tray.get_child_count() - 2) as Control
	var second := tray.get_child(tray.get_child_count() - 1) as Control
	assert_true(first.position.y < second.position.y, "host children stack in order")
	assert_true(second.position.y + second.size.y <= hint.position.y, "the hint is last")
	assert_true(hint.has_meta(MinigameTray.HINT_META), "the hint is tray chrome, not host content")


func test_the_tray_is_as_tall_as_its_content() -> void:
	var one := _tray_with(1).get_combined_minimum_size().y
	var two := _tray_with(2).get_combined_minimum_size().y
	var probe := MinigameTray.new()
	var sep := probe.separation
	probe.free()
	assert_true(is_equal_approx(two - one, 100.0 + sep),
		"each host row adds its height plus one separation")


func test_tray_settle_fades_the_hint_but_never_hides_it() -> void:
	var tray := _tray_with(1)
	tray.set_hint("Ketuk jawaban yang benar")
	var hint := tray.get_node("HintLabel") as Label
	assert_eq(hint.text, "Ketuk jawaban yang benar")
	tray.settle()
	assert_true(is_equal_approx(hint.modulate.a, MinigameTray.SETTLED_ALPHA))
	tray.set_hint("Urutan salah!")
	assert_true(is_equal_approx(hint.modulate.a, 1.0), "a new hint comes back at full strength")


func test_the_pill_ignores_taps_and_shows_its_icon() -> void:
	var pill := (load(PILL) as PackedScene).instantiate() as MinigameHintPill
	pill.icon_texture = load(ICON_DIR + "swipe_up.svg")
	Engine.get_main_loop().root.add_child(pill)
	track(pill)
	assert_eq(pill.mouse_filter, Control.MOUSE_FILTER_IGNORE, "gestures pass through")
	assert_true((pill.get_node("%Icon") as TextureRect).visible, "an icon shows when set")
	pill.set_hint("Geser ke atas untuk menendang")
	assert_eq((pill.get_node("%HintLabel") as Label).text, "Geser ke atas untuk menendang")
	pill.settle()
	assert_true(is_equal_approx((pill.get_node("%HintLabel") as Label).modulate.a,
		MinigameHintPill.SETTLED_ALPHA))
