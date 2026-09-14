@tool
extends McpTestSuite

## Lobby-style buttons (2026-09-14 spec): every framed action button wears
## the Lobby's STUDENT/JADWAL look -- brand_primary_light fill,
## brand_primary_dark bevel, outline_card rim, text_on_brand -- except
## StudentCard's cream secondary buttons and StudentList's red/green status
## badges, which keep theirs.

## The restyled roles, with every generated size step.
const LOBBY_LOOK := [
	"PrimaryButton", "PrimaryButtonM", "PrimaryButtonL",
	"SecondaryButton", "SecondaryButtonM", "SecondaryButtonL",
	"DangerButton", "DangerButtonM", "DangerButtonL",
	"SuccessButton", "SuccessButtonL",
	"MainMenuButton", "ShopShelfButton", "ResultButton",
	"LobbyCtaButton", "LobbyNavTile",
]

const _STUDENT_CARD := "res://Scenes/StudentCard/student_card.tscn"
const _ROSTER_CARD := "res://Scenes/StudentList/RosterCard.tscn"

var _tokens: DesignTokens
var _theme: Theme


func suite_name() -> String:
	return "lobby_style_buttons"


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


func _flat(state: String, name: String) -> StyleBoxFlat:
	return _theme.get_stylebox(state, name) as StyleBoxFlat


## A variation's resting fill, or transparent when it has no flat box.
func _fill(name: String) -> Color:
	var sb := _flat("normal", name)
	return sb.bg_color if sb != null else Color(0, 0, 0, 0)


func test_every_action_button_wears_the_lobby_fill_rim_and_text() -> void:
	for name in LOBBY_LOOK:
		var sb := _flat("normal", name)
		assert_true(sb != null, name + "/normal is a flat box like the Lobby's")
		if sb == null:
			continue
		assert_eq(sb.bg_color, _tokens.brand_primary_light, name + " fill")
		assert_eq(sb.border_color, _tokens.outline_card, name + " rim")
		assert_eq(sb.corner_radius_top_left, _tokens.radius_button, name + " corner")
		assert_eq(_theme.get_color("font_color", name), _tokens.text_on_brand, name + " text")


func test_every_action_button_sinks_the_way_the_lobby_does() -> void:
	for name in LOBBY_LOOK:
		var pressed := _flat("pressed", name)
		assert_true(pressed != null and pressed.bg_color == _tokens.brand_primary_dark,
			name + " pressed flips to the darker bevel, as the Lobby's does")


func test_student_card_keeps_its_cream_secondary() -> void:
	assert_eq(_fill("StudentCardSecondaryButtonL"), _tokens.surface_card, "cream fill, as before")
	var sb := _flat("normal", "StudentCardSecondaryButtonL")
	assert_true(sb != null and sb.border_color == _tokens.brand_primary, "brown rim, as before")
	assert_eq(_theme.get_color("font_color", "StudentCardSecondaryButtonL"),
		_tokens.brand_primary, "brown text, as before")
	assert_eq(_theme.get_font_size("font_size", "StudentCardSecondaryButtonL"),
		_tokens.font_h1, "the L step")


func test_status_badges_keep_their_red_and_green() -> void:
	assert_eq(_fill("RosterStatusBelum"), _tokens.state_danger.lightened(0.18), "BELUM stays red")
	assert_eq(_fill("RosterStatusSudah"), _tokens.state_success.lightened(0.18), "SUDAH stays green")


## The icon-only main menu buttons and Weekly Results' half-row buttons
## keep the fit they were laid out for; only the surface changed.
func test_main_menu_and_weekly_results_keep_their_fit() -> void:
	var mm := _flat("normal", "MainMenuButton")
	assert_true(mm != null and mm.content_margin_left == 20.0 and mm.content_margin_top == 0.0,
		"MainMenuButton keeps its tight icon margins")
	assert_eq(_theme.get_font_size("font_size", "MainMenuButton"), 80, "MainMenuButton text size")
	var rb := _flat("normal", "ResultButton")
	assert_true(rb != null and rb.content_margin_left == 24.0,
		"ResultButton keeps its 24 px sides so SELANJUTNYA fits")
	assert_eq(_theme.get_font_size("font_size", "ResultButton"), _tokens.day_stat_size,
		"ResultButton keeps the card's 52 px text")


func test_student_card_points_its_cream_buttons_at_its_own_style() -> void:
	var src := FileAccess.get_file_as_string(_STUDENT_CARD)
	assert_false(src.contains('&"SecondaryButtonL"'),
		"no StudentCard button takes the restyled secondary")
	assert_eq(src.count('&"StudentCardSecondaryButtonL"'), 8,
		"six Batal and the two page arrows")
	assert_eq(src.count('&"PrimaryButtonL"'), 7,
		"six Aprove and Belajar already wear the Lobby look")


func test_roster_badges_use_the_status_styles() -> void:
	var src := FileAccess.get_file_as_string(_ROSTER_CARD)
	assert_contains(src, 'theme_type_variation = &"RosterStatusBelum"')
	assert_contains(src, 'theme_type_variation = &"RosterStatusSudah"')
	assert_false(src.contains("DangerButton") or src.contains("SuccessButton"),
		"the badges left the action styles")


func test_only_student_card_uses_its_style() -> void:
	var scenes: Array = []
	_scene_files("res://Scenes", scenes)
	for path in scenes:
		if path == _STUDENT_CARD:
			continue
		assert_false(FileAccess.get_file_as_string(path).contains("StudentCardSecondaryButton"),
			path + " must not borrow StudentCard's exception")


func _scene_files(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scene_files(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
