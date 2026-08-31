@tool
extends McpTestSuite

func suite_name() -> String:
	return "theme_factory"

var _tokens: DesignTokens
var _theme: Theme


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


func test_build_returns_a_theme() -> void:
	assert_true(_theme != null, "build must return a Theme")
	assert_true(_theme is Theme, "must be a Theme instance")


func test_every_declared_variation_exists() -> void:
	# Later tasks set theme_type_variation to these exact strings.
	# A typo here becomes an invisible styling failure at runtime,
	# because Godot silently falls back to the base type.
	var expected := [
		"PrimaryButton", "SecondaryButton", "DangerButton",
		"Card", "SunkenPanel", "Scrim",
		"DisplayLabel", "H1Label", "H2Label", "TitleLabel",
		"CaptionLabel", "MicroLabel", "StatBar",
	]
	var actual := _theme.get_type_list()
	for variation in expected:
		assert_true(actual.has(variation), "theme must declare type: " + variation)


func test_button_variations_have_all_four_states() -> void:
	for variation in ["PrimaryButton", "SecondaryButton", "DangerButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			assert_true(_theme.has_stylebox(state, variation),
				"%s must define stylebox: %s" % [variation, state])


func test_primary_button_uses_brand_color() -> void:
	var sb := _theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	assert_true(sb != null, "PrimaryButton/normal must be a StyleBoxFlat")
	assert_eq(sb.bg_color, _tokens.brand_primary_light,
		"gradient top of the primary button is brand_primary_light")


func test_buttons_meet_minimum_touch_target() -> void:
	# Anything smaller is a tap the user will miss on a phone.
	for variation in ["PrimaryButton", "SecondaryButton", "DangerButton"]:
		var sb := _theme.get_stylebox("normal", variation) as StyleBoxFlat
		var height := sb.content_margin_top + sb.content_margin_bottom
		assert_true(height >= float(_tokens.touch_target_min) * 0.5,
			variation + " content margins must contribute to a tappable height")


func test_card_has_visible_outline_and_shadow() -> void:
	var sb := _theme.get_stylebox("panel", "Card") as StyleBoxFlat
	assert_eq(sb.bg_color, _tokens.surface_card, "card fill")
	assert_true(sb.border_width_top >= 1, "card must have the white rim")
	assert_eq(sb.border_color, _tokens.outline_card, "rim color")
	assert_true(sb.shadow_size > 0, "card must have a drop shadow")


func test_label_variations_carry_font_sizes_from_tokens() -> void:
	assert_eq(_theme.get_font_size("font_size", "DisplayLabel"), _tokens.font_display_size)
	assert_eq(_theme.get_font_size("font_size", "H1Label"), _tokens.font_h1)
	assert_eq(_theme.get_font_size("font_size", "CaptionLabel"), _tokens.font_caption)


func test_changing_a_token_changes_the_built_theme() -> void:
	# This is the whole point of the pipeline: edit the token, get a new look.
	var custom := DesignTokens.new()
	custom.brand_primary_light = Color("ff0000")
	var custom_theme := ThemeFactory.build(custom)
	var sb := custom_theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	assert_eq(sb.bg_color, Color("ff0000"),
		"theme must be derived from tokens, not hardcoded")


func test_build_survives_null_fonts() -> void:
	# design_tokens.tres has null font slots until Task 4. Baking must
	# not crash in that window.
	var bare := DesignTokens.new()
	bare.font_display = null
	bare.font_body = null
	var t := ThemeFactory.build(bare)
	assert_true(t != null, "build must tolerate unassigned font slots")


func test_redesign_variations_exist() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var actual := theme.get_type_list()
	for variation in ["StatPill", "TraitPill", "BioLabel", "BioValue"]:
		assert_true(actual.has(variation),
			"ThemeFactory must define the " + variation + " variation")


## The pill's art ships gold with a dark purple border baked in. A stylebox
## tint would multiply against both -- muddying the fill to olive and
## turning the purple border brown -- so the texture must draw untinted.
func test_trait_pill_draws_its_art_untinted() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var normal := theme.get_stylebox("normal", "TraitPill")
	assert_true(normal is StyleBoxTexture,
		"TraitPill's normal stylebox must be the pill texture")
	assert_eq((normal as StyleBoxTexture).modulate_color, Color.WHITE,
		"TraitPill must not tint its texture")


## White text on a gold fill needs the dark rim to stay legible, matching
## the treatment CardSectionLabel already uses on the same card.
func test_trait_pill_text_is_outlined() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_color("font_color", "TraitPill"), tokens.text_on_brand,
		"TraitPill text must be white")
	assert_eq(theme.get_color("font_outline_color", "TraitPill"), tokens.text_primary,
		"TraitPill text must carry the dark outline")
	assert_true(theme.get_constant("outline_size", "TraitPill") > 0,
		"TraitPill's outline must have width")


## The card background paints the pill tracks, so the bar must draw no
## background of its own -- otherwise a second track renders on top of the
## painted one and the pill looks doubled.
func test_stat_pill_draws_no_background() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var bg := theme.get_stylebox("background", "StatPill")
	assert_true(bg is StyleBoxEmpty,
		"StatPill's background must be empty; the track is painted into the card")


func test_stat_pill_fill_uses_the_texture() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var fill := theme.get_stylebox("fill", "StatPill")
	assert_true(fill is StyleBoxTexture, "StatPill's fill must be textured")
	assert_true(fill.texture != null, "StatPill's fill texture must load")


## StatBar is shared with AturJadwal, SemesterEnd and ResultCheckup. The
## redesign must not have altered how it looks for them.
func test_stat_bar_variation_is_unchanged() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var bg := theme.get_stylebox("background", "StatBar")
	assert_true(bg is StyleBoxFlat, "StatBar keeps its flat track")


func test_main_menu_button_variation_exists_and_is_sized_for_the_mockup() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)

	assert_true(theme.has_type("MainMenuButton"),
		"MainMenuButton variation must exist")
	assert_eq(theme.get_type_variation_base("MainMenuButton"), &"Button",
		"MainMenuButton must vary the Button type")

	# The mockup's buttons are trait_button.png recoloured: same 9-slice art.
	var normal := theme.get_stylebox("normal", "MainMenuButton")
	assert_true(normal is StyleBoxTexture,
		"MainMenuButton must draw the trait_button.png 9-slice, not a flat box")

	# Font size 80, not the mockup-implied 100: see the spec's typography
	# section -- PENGATURAN at 100 overflows the 624 px inner box by 131 px.
	assert_eq(theme.get_font_size("font_size", "MainMenuButton"), 80,
		"MainMenuButton font size")
