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
		assert_false(theme.has_font("font", name), name + " keeps the body face")


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
