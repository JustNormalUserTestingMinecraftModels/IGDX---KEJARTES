@tool
extends McpTestSuite

## Button roles (2026-09-28 UI depth pass, replacing the 2026-09-14
## lobby-style-buttons rule that every action button wore the brown Lobby
## look). Every framed button is now a lipped box (LippedBox): a face on a
## darker lip, sinking onto the lip when held. Its colours say its role --
## mint is the main action and affirm on every screen, tomato is danger,
## brown is neutral (StudentCard's secondary buttons and the filter chips went
## back to it on 2026-09-29, after their cream faces vanished on cream cards;
## the minigame answers stay cream, because their scene authors the box),
## sky and sunflower are the Lobby tiles' and the notebook tabs' own. Information badges keep their meaning colours.
## Spec: docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md.

const _STUDENT_CARD := "res://Scenes/StudentCard/StudentCard.tscn"
const _ROSTER_CARD := "res://Scenes/StudentList/RosterCard.tscn"

var _tokens: DesignTokens
var _theme: Theme


func suite_name() -> String:
	return "lobby_style_buttons"


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


## role -> [face token, lip token], every generated size step included.
func _roles() -> Dictionary:
	var t := _tokens
	var mint := [t.accent_mint, t.accent_mint_lip]
	var brown := [t.brand_primary_light, t.brand_primary_dark]
	var tomato := [t.accent_tomato, t.accent_tomato_lip]
	return {
		"PrimaryButton": mint, "PrimaryButtonM": mint, "PrimaryButtonL": mint,
		"SuccessButton": mint, "SuccessButtonL": mint,
		"LobbyCtaButton": mint, "BookHeroButton": mint, "ResultButton": mint,
		"PlusButton": mint, "NavTileKoperasi": mint,
		"NavTileInventory": [t.accent_sky, t.accent_sky_lip],
		"NavTileRapor": [t.accent_sunflower, t.accent_sunflower_lip],
		"DangerButton": tomato, "DangerButtonM": tomato, "DangerButtonL": tomato,
		"SecondaryButton": brown, "SecondaryButtonM": brown, "SecondaryButtonL": brown,
		"LobbyNavTile": brown, "MainMenuButton": brown, "ShopShelfButton": brown,
		"QuirkBadge": brown, "CardArrowButton": [t.brand_primary, t.brand_primary_dark],
		"StudentCardSecondaryButton": brown, "StudentCardSecondaryButtonL": brown,
		"FilterChipButton": brown,
		"MinigameChoiceButton": [t.button_cream, t.button_cream_lip],
	}


func _box(state: String, name: String) -> StyleBoxFlat:
	return _theme.get_stylebox(state, name) as StyleBoxFlat


## A variation's resting face, or transparent when it is not lipped.
func _fill(name: String) -> Color:
	var sb := _box("normal", name)
	return sb.bg_color if sb != null else Color(0, 0, 0, 0)


func test_every_role_wears_its_palette_colour() -> void:
	var roles := _roles()
	for name in roles:
		var sb := _box("normal", name)
		assert_true(sb != null, name + "/normal is a lipped box")
		if sb == null:
			continue
		assert_eq(sb.bg_color, roles[name][0], name + " face")
		assert_eq(sb.shadow_color, roles[name][1], name + " lip")
		assert_true(LippedBox.is_lipped(sb), name + " is lipped")


func test_every_role_sinks_onto_its_lip_when_held() -> void:
	for name in _roles():
		var rest := _box("normal", name)
		var held := _box("pressed", name)
		assert_true(rest != null and not LippedBox.is_pressed(rest) and LippedBox.lip_height_of(rest) > 0,
			name + " rests on a lip")
		assert_true(held != null and LippedBox.is_pressed(held), name + " sinks when held")


func test_disabled_rests_on_half_a_lip() -> void:
	for name in ["PrimaryButton", "SecondaryButton", "DangerButton"]:
		var disabled := _box("disabled", name)
		assert_eq(LippedBox.lip_height_of(disabled), floori(_tokens.lip_height / 2.0),
			name + " disabled halves the lip")


func test_gold_is_never_a_main_action() -> void:
	for name in ["PrimaryButton", "LobbyCtaButton", "BookHeroButton", "SuccessButton",
			"ResultButton", "PlusButton"]:
		assert_ne(_fill(name), _tokens.accent_sunflower, name + " is not gold")
		assert_ne(_fill(name), _tokens.currency_gold, name + " does not look like a purchase")


## Outlined light text on a dark face; dark ink with no outline on a light one.
func test_label_ink_follows_the_face() -> void:
	assert_eq(_theme.get_color("font_color", "PrimaryButton"), _tokens.text_on_brand,
		"white on mint")
	assert_eq(_theme.get_constant("outline_size", "PrimaryButton"), _tokens.lipped_label_outline,
		"outlined")
	assert_eq(_theme.get_color("font_outline_color", "PrimaryButton"), _tokens.accent_mint_lip,
		"in the lip colour")
	for light in ["NavTileRapor"]:
		assert_eq(_theme.get_color("font_color", light), _tokens.text_primary, light + " dark ink")
		assert_eq(_theme.get_constant("outline_size", light), 0, light + " no outline")
	for dark in ["StudentCardSecondaryButtonL", "FilterChipButton"]:
		assert_eq(_theme.get_color("font_color", dark), _tokens.text_on_brand, dark + " light ink")
		assert_eq(_theme.get_constant("outline_size", dark), _tokens.lipped_label_outline,
			dark + " outlined")


func test_student_card_secondary_is_brown() -> void:
	assert_eq(_fill("StudentCardSecondaryButtonL"), _tokens.brand_primary_light, "brown face")
	assert_eq(_fill("StudentCardSecondaryButton"), _tokens.brand_primary_light, "brown at every step")
	assert_eq(_fill("MinigameChoiceButton"), _tokens.button_cream,
		"the minigame answers stay cream: their scene authors a near-white box over the variation")
	assert_eq(_theme.get_color("font_color", "MinigameChoiceButton"), _tokens.text_primary,
		"so they keep dark ink")
	assert_eq(_theme.get_font_size("font_size", "StudentCardSecondaryButtonL"),
		_tokens.font_h1, "the L step")


func test_status_badges_keep_their_red_and_green() -> void:
	assert_eq(_fill("RosterStatusBelum"), _tokens.state_danger.lightened(0.18), "BELUM stays red")
	assert_eq(_fill("RosterStatusSudah"), _tokens.state_success.lightened(0.18), "SUDAH stays green")


## The event dialog's student card stays flat: its pressed state means
## SELECTED, which a sink would not say.
func test_the_event_select_card_stays_flat() -> void:
	assert_false(LippedBox.is_lipped(_theme.get_stylebox("normal", "EventSelectCard")),
		"EventSelectCard keeps its flat selectable card")


## The icon-only main menu buttons and Weekly Results' half-row buttons
## keep the fit they were laid out for; only the surface changed.
func test_main_menu_and_weekly_results_keep_their_fit() -> void:
	var mm := _theme.get_stylebox("normal", "MainMenuButton")
	assert_true(mm != null and mm.content_margin_left == 20.0 and mm.content_margin_top == 0.0,
		"MainMenuButton keeps its tight icon margins")
	assert_eq(_theme.get_font_size("font_size", "MainMenuButton"), 80, "MainMenuButton text size")
	var rb := _theme.get_stylebox("normal", "ResultButton")
	assert_true(rb != null and rb.content_margin_left == 24.0,
		"ResultButton keeps its 24 px sides so SELANJUTNYA fits")
	assert_eq(_theme.get_font_size("font_size", "ResultButton"), _tokens.day_stat_size,
		"ResultButton keeps the card's 52 px text")


## Koperasi's Rak1 ("KEBUTUHAN SEKOLAH") is authored 442 px wide with a
## 40 px text override, and a Button grows to its minimum size. In the body
## font it always used, that label already needs 469 px with the 20 px
## margins (27 px over, listed in DEBT.md); the Lobby recipe's display face
## made it 495 (code review, 2026-09-14). So the shelf label keeps the body
## font, and this pass leaves the fit no worse than it found it.
func test_the_shelf_button_keeps_its_body_font_label() -> void:
	# get_font_list, not has_font: Theme.has_font() is also true whenever the
	# theme has a default font, which this one always does.
	assert_false(_theme.get_font_list("ShopShelfButton").has("font"),
		"ShopShelfButton sets no font of its own, so it inherits the body font")
	var font := _theme.get_font("font", "ShopShelfButton")
	var sb := _theme.get_stylebox("normal", "ShopShelfButton")
	assert_true(font != null and sb != null, "the shelf button has a font and a box")
	if font == null or sb == null:
		return
	var text_w := font.get_string_size("KEBUTUHAN SEKOLAH", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var need := text_w + sb.content_margin_left + sb.content_margin_right
	assert_true(need <= 470.0,
		"no wider than the 469 px it needed before this pass, got %d" % int(need))


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
