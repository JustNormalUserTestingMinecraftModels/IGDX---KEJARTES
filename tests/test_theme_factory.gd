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


## Task 3 of the mockup-rescale plan added these shadows as literal Color(...)
## values instead of tokens -- the only hardcoded colors in the whole file.
## This proves the fix: change the token, get a different shadow.
func test_preview_shadows_come_from_tokens() -> void:
	var custom := DesignTokens.new()
	custom.preview_row_shadow_color = Color(1, 0, 0, 0.5)
	custom.preview_row_shadow_size = 9
	custom.preview_row_shadow_offset = Vector2(0, 9)
	custom.preview_pill_shadow_color = Color(0, 1, 0, 0.5)
	custom.preview_pill_shadow_size = 11
	custom.preview_pill_shadow_offset = Vector2(0, 11)
	var custom_theme := ThemeFactory.build(custom)

	var row_sb := custom_theme.get_stylebox("panel", "PreviewRow") as StyleBoxFlat
	assert_eq(row_sb.shadow_color, custom.preview_row_shadow_color,
		"PreviewRow shadow color must come from tokens, not a hardcoded literal")
	assert_eq(row_sb.shadow_size, custom.preview_row_shadow_size,
		"PreviewRow shadow size must come from tokens, not a hardcoded literal")
	assert_eq(row_sb.shadow_offset, custom.preview_row_shadow_offset,
		"PreviewRow shadow offset must come from tokens, not a hardcoded literal")

	var pill_sb := custom_theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_eq(pill_sb.shadow_color, custom.preview_pill_shadow_color,
		"PreviewPill shadow color must come from tokens, not a hardcoded literal")
	assert_eq(pill_sb.shadow_size, custom.preview_pill_shadow_size,
		"PreviewPill shadow size must come from tokens, not a hardcoded literal")
	assert_eq(pill_sb.shadow_offset, custom.preview_pill_shadow_offset,
		"PreviewPill shadow offset must come from tokens, not a hardcoded literal")


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


## StatBar is shared with AturJadwal, StatCheck and ResultCheckup. The
## redesign must not have altered how it looks for them.
func test_stat_bar_variation_is_unchanged() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var bg := theme.get_stylebox("background", "StatBar")
	assert_true(bg is StyleBoxFlat, "StatBar keeps its flat track")


func test_main_menu_button_variation_exists_and_is_sized_for_the_mockup() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)

	assert_true(theme.get_type_list().has("MainMenuButton"),
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


## The bars used to be a flat sunken capsule with the fill running flush
## to the outer edge. The track now carries the project's sticker chrome
## (white rim + soft shadow) and insets the fill so a rail stays visible.
func test_stat_bar_track_is_an_inset_outlined_capsule() -> void:
	var bg := _theme.get_stylebox("background", "StatBar") as StyleBoxFlat
	assert_true(bg != null, "StatBar has no StyleBoxFlat background")
	if bg == null:
		return
	assert_true(bg.border_width_top > 0 and bg.border_width_bottom > 0
		and bg.border_width_left > 0 and bg.border_width_right > 0,
		"the track must carry a rim on all four sides")
	assert_true(bg.shadow_size > 0, "the track must carry a soft shadow")
	assert_true(bg.content_margin_left > 0.0 and bg.content_margin_top > 0.0
		and bg.content_margin_right > 0.0 and bg.content_margin_bottom > 0.0,
		"the fill must be inset so the rail stays visible")
	assert_true(bg.corner_radius_top_left >= 32,
		"the track must stay a capsule")


## StatBar used to tint itself via self_modulate, which multiplies the WHOLE
## node -- the track's surface_sunken ground and white rim included -- so a
## bar at value 0 rendered as a solid category-coloured capsule, 100% full
## by eye. Each category now gets its own theme variation whose FILL
## stylebox bakes the colour in directly, sharing the exact "StatBar" track
## above so the rim/shadow/inset chrome can't drift between categories.
func test_stat_bar_category_variations_exist_and_bake_their_colour_into_the_fill() -> void:
	var expected := {
		"StatBarAkademis": _tokens.cat_akademis,
		"StatBarSeniBudaya": _tokens.cat_senibudaya,
		"StatBarOlahraga": _tokens.cat_olahraga,
		"StatBarIstirahat": _tokens.cat_istirahat,
		"StatBarLibur": _tokens.cat_libur,
		"StatBarWirausaha": _tokens.cat_wirausaha,
	}
	var actual := _theme.get_type_list()
	for name in expected.keys():
		assert_true(actual.has(name), "theme must declare type: " + name)
		if not actual.has(name):
			continue

		var fill := _theme.get_stylebox("fill", name) as StyleBoxTexture
		assert_true(fill != null, "%s/fill must be a StyleBoxTexture" % name)
		if fill != null:
			assert_eq(fill.modulate_color, expected[name],
				"%s/fill must bake in its category colour" % name)

		# Same rim/shadow/radius chrome as the shared "StatBar" track, or
		# a value-0 bar in this category is invisible again.
		var bg := _theme.get_stylebox("background", name) as StyleBoxFlat
		assert_true(bg != null, "%s/background must be a StyleBoxFlat" % name)
		if bg != null:
			assert_true(bg.border_width_top > 0,
				"%s/background must keep the track's rim" % name)


func test_headings_take_the_display_font() -> void:
	# H2Label and TitleLabel are headings but are not outlined. Before the
	# 2026-09-05 typography pass they took the body font, because
	# _build_labels keyed the display font off the outline flag.
	var tokens := DesignTokens.load_default()
	if tokens.font_display == null:
		# Nothing to assert while the slot is empty; Task 1/3 fills it.
		assert_true(true, "display slot unassigned, skipping")
		return
	for name in ["DisplayLabel", "H1Label", "H2Label", "TitleLabel"]:
		assert_eq(_theme.get_font("font", name), tokens.font_display,
			"%s must take the display font" % name)


func test_section_and_hero_headings_take_the_display_font() -> void:
	# CardSectionLabel and ResultHeroLabel are built outside _build_labels
	# and so were never reached by its font assignment at all.
	var tokens := DesignTokens.load_default()
	if tokens.font_display == null:
		assert_true(true, "display slot unassigned, skipping")
		return
	assert_eq(_theme.get_font("font", "CardSectionLabel"), tokens.font_display,
		"CardSectionLabel must take the display font")
	assert_eq(_theme.get_font("font", "ResultHeroLabel"), tokens.font_display,
		"ResultHeroLabel must take the display font")


func test_body_labels_do_not_take_the_display_font() -> void:
	# The other half of the contract: promoting headings must not sweep up
	# captions, prose, or stat-bar chrome. BarLabel in particular is the
	# highest-traffic variation in the game (130 scene uses) and stays body.
	#
	# Theme.get_font() always falls back to default_font when no explicit
	# override exists, so it is never null here even for a correctly-body
	# variation -- get_font_list() is the only way to see whether an
	# explicit "font" override was actually registered for this exact type.
	for name in ["CaptionLabel", "MicroLabel", "EmptyStateLabel",
			"ResultBodyLabel", "BioLabel", "BarLabel"]:
		assert_true(not _theme.get_font_list(name).has("font"),
			"%s must not carry an explicit font override (should inherit default_font)" % name)


## Every variation that must render in the display face. Adding a
## variation to ThemeFactory without adding it here (or deliberately
## leaving it out) will fail test_display_font_roster_is_exact.
const DISPLAY_ROSTER := [
	"DisplayLabel", "H1Label", "H2Label", "TitleLabel",
	"CardSectionLabel", "ResultHeroLabel",
	"MainMenuButton", "PrimaryButton", "SecondaryButton", "DangerButton",
	"SuccessButton", "QuirkBadge", "PersonaBadge", "LobbyNavButton",
	"TraitPill", "PreviewRowLabel",
	"DaySummaryName", "DaySummaryStat", "DaySummaryNeedsLabel",
	"RecapPillValueLabel", "ScoreHudValueLabel",
]


func test_display_font_roster_is_exact() -> void:
	# Both directions. A one-directional check would pass while a new
	# heading quietly inherited the body font, which is the exact bug
	# H2Label and TitleLabel had before 2026-09-05.
	var tokens := DesignTokens.load_default()
	assert_true(tokens.font_display != null, "display slot must be assigned")
	for name in DISPLAY_ROSTER:
		assert_eq(_theme.get_font("font", name), tokens.font_display,
			"%s is on the display roster but did not get the display font" % name)

	var strays := []
	for name in _theme.get_type_list():
		if name in DISPLAY_ROSTER:
			continue
		if _theme.get_font("font", name) == tokens.font_display:
			strays.append(name)
	assert_eq(strays.size(), 0,
		"these got the display font but are not on the roster: %s" % str(strays))


func test_default_font_is_the_body_face() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(_theme.default_font, tokens.font_body,
		"default_font must be the body face so untagged Labels inherit it")


func test_the_two_faces_are_actually_different() -> void:
	# Before 2026-09-05 both slots pointed at Milker.otf, so the whole
	# head/body split existed in code and was invisible on screen. This
	# is the assertion that would have caught that.
	var tokens := DesignTokens.load_default()
	assert_true(tokens.font_display != null, "display slot must be assigned")
	assert_true(tokens.font_body != null, "body slot must be assigned")
	assert_true(tokens.font_display != tokens.font_body,
		"display and body must be different faces")


func test_baked_theme_resource_matches_the_factory() -> void:
	# The suite above only ever tests ThemeFactory.build() in memory. The
	# running game loads the baked .tres from disk instead, and that bake
	# has no headless path (Scripts/Design/BakeTheme.gd needs File > Run) --
	# so a ThemeFactory edit with a forgotten rebake would leave every test
	# above green while the shipped game still rendered the stale theme.
	#
	# Plain load() would use Godot's ResourceLoader cache by path: this
	# test runs inside the same long-lived editor process across an entire
	# session (godot-ai MCP bridge), so a bare load() can silently return
	# a copy of this resource cached from BEFORE the last rebake, producing
	# a false result in either direction. CACHE_MODE_REPLACE forces a real
	# read of what's on disk right now and updates the cache to match.
	var tokens := DesignTokens.load_default()
	var baked: Theme = ResourceLoader.load(
		"res://Assets/Theme/kejartes_theme.tres", "", ResourceLoader.CACHE_MODE_REPLACE)
	assert_true(baked != null, "kejartes_theme.tres must load")
	assert_eq(baked.default_font, tokens.font_body,
		"baked theme's default_font must match the current body font")
	assert_eq(baked.get_font("font", "H1Label"), tokens.font_display,
		"baked theme's H1Label must match the current display font")
