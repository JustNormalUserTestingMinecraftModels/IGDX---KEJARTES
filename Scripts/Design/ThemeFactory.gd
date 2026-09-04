@tool
class_name ThemeFactory
extends RefCounted

## Builds a Godot Theme from a DesignTokens resource.
##
## Pure: no file I/O, no editor dependencies, no global state. Given the
## same tokens it always produces the same Theme. BakeTheme.gd handles
## persistence; this file only handles construction.


static func build(tokens: DesignTokens) -> Theme:
	var theme := Theme.new()

	if tokens.font_body != null:
		theme.default_font = tokens.font_body
	theme.default_font_size = tokens.font_body_size

	_build_buttons(theme, tokens)
	_build_panels(theme, tokens)
	_build_labels(theme, tokens)
	_build_progress(theme, tokens)
	_build_day_summary(theme, tokens)
	_build_student_card(theme, tokens)
	_build_week_recap(theme, tokens)
	_build_minigame_result(theme, tokens)
	_build_base_overrides(theme, tokens)

	return theme


# ---------------------------------------------------------------- buttons

static func _build_buttons(theme: Theme, tokens: DesignTokens) -> void:
	_add_button_variation(theme, tokens, "PrimaryButton",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand)

	_add_button_variation(theme, tokens, "SecondaryButton",
		tokens.surface_card, tokens.surface_sunken,
		tokens.brand_primary, tokens.brand_primary)

	_add_button_variation(theme, tokens, "DangerButton",
		tokens.state_danger.lightened(0.18), tokens.state_danger.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand)

	# StudentCard's APPROVE is an affirmative, not the screen's primary
	# navigation, so it needs its own green rather than brand blue.
	_add_button_variation(theme, tokens, "SuccessButton",
		tokens.state_success.lightened(0.18), tokens.state_success.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand)

	# Trait chips (Quirk / Persona). Same pill geometry as any other
	# button variation; only the accent differs, so the two trait kinds
	# stay visually distinguishable without per-node styleboxes.
	_add_button_variation(theme, tokens, "QuirkBadge",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand)

	_add_button_variation(theme, tokens, "PersonaBadge",
		tokens.cat_istirahat.lightened(0.18), tokens.cat_istirahat.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand)

	# Lobby's five hub nav buttons used to point at three loose,
	# hand-authored StyleBoxFlat .tres files (lobby_btn_normal/hover/
	# pressed). Folded here so they obey the token cascade like every
	# other button in the game instead of living outside the theme.
	_add_button_variation(theme, tokens, "LobbyNavButton",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand)

	_build_main_menu_button(theme, tokens)
	_build_shop_shelf_button(theme, tokens)


## Koperasi's shelf-category button (e.g. "KEBUTUHAN SEKOLAH"). A flat
## rounded rectangle with a heavier bottom border for a pressed-tab look,
## not the pill shape _pill()/_add_button_variation() produce, and its
## hover state recolours the text gold rather than lightening the fill --
## neither shape matches an existing variation closely enough to reuse.
static func _build_shop_shelf_button(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "ShopShelfButton"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Button")

	var normal := StyleBoxFlat.new()
	normal.bg_color = tokens.brand_primary
	normal.set_corner_radius_all(tokens.radius_md)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 5
	normal.border_color = tokens.outline_card
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	normal.shadow_color = Color(tokens.shadow_color.r, tokens.shadow_color.g, tokens.shadow_color.b, 0.45)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	theme.set_stylebox("normal", NAME, normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = tokens.brand_primary.lightened(0.15)
	theme.set_stylebox("hover", NAME, hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = tokens.brand_primary.darkened(0.2)
	pressed.border_width_bottom = 2
	pressed.shadow_offset = Vector2(0, 1)
	theme.set_stylebox("pressed", NAME, pressed)

	theme.set_color("font_color", NAME, tokens.text_on_brand)
	theme.set_color("font_hover_color", NAME, tokens.currency_gold)
	theme.set_color("font_pressed_color", NAME, tokens.text_on_brand)
	theme.set_color("font_shadow_color", NAME,
		Color(tokens.shadow_color.r, tokens.shadow_color.g, tokens.shadow_color.b, 0.75))
	theme.set_constant("shadow_offset_x", NAME, 2)
	theme.set_constant("shadow_offset_y", NAME, 2)


## The main menu's three nav buttons. Deliberately the SAME art as
## StudentCard's TraitPill (trait_button.png) -- the main-menu mockup's
## buttons are that asset recoloured, so reusing it reproduces the mockup's
## silhouette, 3 px #3D2048 border, corner radius and top gloss exactly.
##
## It cannot simply reuse the TraitPill variation: TraitPill sets font_size to
## tokens.font_h2 (48) with a 6 px outline, sized for a chip. The menu needs
## 80 with no outline (see the plan's spec for the arithmetic -- PENGATURAN at
## the mockup-implied 100 is 755 px wide against a 624 px inner box).
##
## region_rect and texture_margin are copied from TraitPill because they
## describe the ART, not the chip: the pill occupies (20, 277, 601, 91) inside
## the 640x640 canvas, and a 45 px 9-slice margin keeps both rounded ends
## intact when the box is stretched to the menu's 670x126.
static func _build_main_menu_button(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "MainMenuButton"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Button")

	var normal := StyleBoxTexture.new()
	normal.texture = load(_CARD_ART + "trait_button.png")
	normal.region_rect = Rect2(20, 277, 601, 91)
	normal.set_texture_margin_all(45)
	# Horizontal room for the label. 670 - 2*3 px border - 2*20 = 624 px,
	# which PENGATURAN fills to 604 px at font size 80.
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	theme.set_stylebox("normal", NAME, normal)

	# The art carries no separate state variants, so hover/pressed reuse it
	# and the press feedback comes from UIPolish's automatic Juice scale.
	theme.set_stylebox("hover", NAME, normal)
	theme.set_stylebox("pressed", NAME, normal)
	theme.set_stylebox("disabled", NAME, normal)
	theme.set_stylebox("focus", NAME, StyleBoxEmpty.new())

	theme.set_font_size("font_size", NAME, 80)
	theme.set_color("font_color", NAME, tokens.text_on_brand)
	theme.set_color("font_hover_color", NAME, tokens.text_on_brand)
	theme.set_color("font_pressed_color", NAME, tokens.text_on_brand)
	theme.set_color("font_focus_color", NAME, tokens.text_on_brand)
	theme.set_color("font_disabled_color", NAME, tokens.text_on_brand)
	if tokens.font_display != null:
		theme.set_font("font", NAME, tokens.font_display)


## One glossy pill in four states. `top`/`bottom` form the vertical
## gradient that gives the button its Umamusume sheen.
static func _add_button_variation(
	theme: Theme,
	tokens: DesignTokens,
	name: String,
	top: Color,
	bottom: Color,
	border: Color,
	text_color: Color
) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Button")

	theme.set_stylebox("normal", name,
		_pill(tokens, top, bottom, border, 0.0))
	theme.set_stylebox("hover", name,
		_pill(tokens, top.lightened(0.08), bottom.lightened(0.08), border, 0.0))
	# Pressed sinks: gradient flips and the shadow collapses.
	theme.set_stylebox("pressed", name,
		_pill(tokens, bottom, top, border, -tokens.shadow_offset.y * 0.5))
	theme.set_stylebox("focus", name,
		_pill(tokens, top, bottom, tokens.brand_primary, 0.0))

	var disabled := _pill(tokens,
		top.lerp(tokens.surface_sunken, 0.7),
		bottom.lerp(tokens.surface_sunken, 0.7),
		border.lerp(tokens.surface_sunken, 0.5), 0.0)
	disabled.shadow_size = 0
	theme.set_stylebox("disabled", name, disabled)

	theme.set_color("font_color", name, text_color)
	theme.set_color("font_hover_color", name, text_color)
	theme.set_color("font_pressed_color", name, text_color)
	theme.set_color("font_focus_color", name, text_color)
	theme.set_color("font_disabled_color", name, tokens.text_disabled)
	theme.set_font_size("font_size", name, tokens.font_title)
	if tokens.font_display != null:
		theme.set_font("font", name, tokens.font_display)


static func _pill(
	tokens: DesignTokens,
	top: Color,
	bottom: Color,
	border: Color,
	shadow_dy: float
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top
	# StyleBoxFlat has no gradient; the two-tone look comes from a
	# lighter fill plus a darker, thicker bottom border acting as a bevel.
	sb.border_color = border
	sb.border_width_left = int(tokens.outline_width)
	sb.border_width_top = int(tokens.outline_width)
	sb.border_width_right = int(tokens.outline_width)
	sb.border_width_bottom = int(tokens.outline_width)
	sb.set_corner_radius_all(tokens.radius_pill)
	sb.shadow_color = tokens.shadow_color
	sb.shadow_size = tokens.shadow_size
	sb.shadow_offset = Vector2(tokens.shadow_offset.x,
		tokens.shadow_offset.y + shadow_dy)
	sb.content_margin_left = tokens.space_lg
	sb.content_margin_right = tokens.space_lg
	sb.content_margin_top = tokens.space_md
	sb.content_margin_bottom = tokens.space_md
	return sb


# ----------------------------------------------------------------- panels

static func _build_panels(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("Card")
	theme.set_type_variation("Card", "Panel")
	var card := StyleBoxFlat.new()
	card.bg_color = tokens.surface_card
	card.border_color = tokens.outline_card
	card.set_border_width_all(int(tokens.outline_width))
	card.set_corner_radius_all(tokens.radius_lg)
	card.shadow_color = tokens.shadow_color
	card.shadow_size = tokens.shadow_size
	card.shadow_offset = tokens.shadow_offset
	card.set_content_margin_all(tokens.space_md)
	theme.set_stylebox("panel", "Card", card)

	theme.add_type("SunkenPanel")
	theme.set_type_variation("SunkenPanel", "Panel")
	var sunken := StyleBoxFlat.new()
	sunken.bg_color = tokens.surface_sunken
	sunken.set_corner_radius_all(tokens.radius_md)
	sunken.set_content_margin_all(tokens.space_sm)
	theme.set_stylebox("panel", "SunkenPanel", sunken)

	theme.add_type("Scrim")
	theme.set_type_variation("Scrim", "Panel")
	var scrim := StyleBoxFlat.new()
	scrim.bg_color = tokens.scrim_color()
	theme.set_stylebox("panel", "Scrim", scrim)

	# A card header whose accent is chosen at runtime. The background is
	# white so the caller can tint it with self_modulate -- the accent is the
	# one value on this surface that genuinely varies per instance (quirk
	# versus persona), and no fixed variation can express it. Every other
	# value still comes from a token.
	theme.add_type("TraitPopupHeader")
	theme.set_type_variation("TraitPopupHeader", "Panel")
	var trait_header := StyleBoxFlat.new()
	trait_header.bg_color = Color.WHITE
	trait_header.corner_radius_top_left = tokens.radius_lg
	trait_header.corner_radius_top_right = tokens.radius_lg
	trait_header.content_margin_left = tokens.space_md
	trait_header.content_margin_top = tokens.space_sm
	trait_header.content_margin_right = tokens.space_md
	trait_header.content_margin_bottom = tokens.space_sm
	theme.set_stylebox("panel", "TraitPopupHeader", trait_header)


# ----------------------------------------------------------------- labels

static func _build_labels(theme: Theme, tokens: DesignTokens) -> void:
	# name, size, color, outlined
	var specs := [
		["DisplayLabel", tokens.font_display_size, tokens.text_primary, true],
		["H1Label", tokens.font_h1, tokens.text_primary, true],
		["H2Label", tokens.font_h2, tokens.text_primary, false],
		["TitleLabel", tokens.font_title, tokens.text_primary, false],
		["CaptionLabel", tokens.font_caption, tokens.text_secondary, false],
		["MicroLabel", tokens.font_micro, tokens.text_secondary, false],
		# PageDotLabel styled the SemesterEnd carousel's page dots and has
		# had no consumer since Plan A deleted that screen. Kept baked
		# rather than removed: dropping a variation needs a theme rebake,
		# which has no headless path. Nothing above this line is unused.
		["PageDotLabel", tokens.font_caption, tokens.text_disabled, false],
		# The "no items match this filter" placeholder text. 32px doesn't
		# match a token exactly (nearest are font_body_size 28 / font_title
		# 36); kept as the shipped literal rather than nudging the size.
		["EmptyStateLabel", 32, tokens.text_disabled, false],
	]
	for spec in specs:
		var name: String = spec[0]
		theme.add_type(name)
		theme.set_type_variation(name, "Label")
		theme.set_font_size("font_size", name, spec[1])
		theme.set_color("font_color", name, spec[2])
		if spec[3]:
			# The chunky white rim behind big display text.
			theme.set_constant("outline_size", name, tokens.text_outline_size)
			theme.set_color("font_outline_color", name, tokens.text_outline_color)
			if tokens.font_display != null:
				theme.set_font("font", name, tokens.font_display)

	# Text that sits ON TOP of a StatBar, where the background behind any
	# given glyph may be either the light track or a saturated category
	# fill. The other label variations all assume a known backdrop and so
	# cannot be reused here. White glyph + dark rim reads against both,
	# which is why this one inverts the usual outline relationship
	# (light text, dark outline) instead of DisplayLabel's dark-on-light.
	# The rim is half the display outline: 8px around 36px text is the
	# chunky look wanted on a 96px display heading, but it swallows a
	# stat label. Derived from the token rather than hardcoded so a
	# change to text_outline_size still propagates.
	theme.add_type("BarLabel")
	theme.set_type_variation("BarLabel", "Label")
	theme.set_font_size("font_size", "BarLabel", tokens.font_title)
	theme.set_color("font_color", "BarLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "BarLabel",
		maxi(2, tokens.text_outline_size / 2))
	theme.set_color("font_outline_color", "BarLabel", tokens.text_primary)

	# Gold currency/quantity text with a soft drop shadow rather than a rim
	# -- distinct from BarLabel's outline, and the shape both the koperasi
	# coin counter and an inventory slot's "×N" badge already used before
	# each built it by hand.
	theme.add_type("CoinLabel")
	theme.set_type_variation("CoinLabel", "Label")
	theme.set_font_size("font_size", "CoinLabel", tokens.font_title)
	theme.set_color("font_color", "CoinLabel", tokens.currency_gold)
	theme.set_color("font_shadow_color", "CoinLabel",
		Color(tokens.shadow_color.r, tokens.shadow_color.g, tokens.shadow_color.b, 0.85))
	theme.set_constant("shadow_offset_x", "CoinLabel", 1)
	theme.set_constant("shadow_offset_y", "CoinLabel", 1)

	# Koperasi's coin counter predates CoinLabel and carries its own shipped
	# numbers (bigger font, a flat black shadow, a wider offset) -- kept
	# distinct rather than folding it into CoinLabel and shrinking it.
	theme.add_type("ShopCoinLabel")
	theme.set_type_variation("ShopCoinLabel", "Label")
	theme.set_font_size("font_size", "ShopCoinLabel", 40)
	theme.set_color("font_color", "ShopCoinLabel", tokens.currency_gold)
	theme.set_color("font_shadow_color", "ShopCoinLabel", Color.BLACK)
	theme.set_constant("shadow_offset_x", "ShopCoinLabel", 2)
	theme.set_constant("shadow_offset_y", "ShopCoinLabel", 2)

	# Koperasi's purchase-feedback message, one variation per semantic
	# outcome so the screen swaps theme_type_variation instead of calling
	# add_theme_color_override with a token colour picked at runtime.
	var message_specs := [
		["ShopMessageWarning", tokens.state_warning],
		["ShopMessageDanger", tokens.state_danger],
		["ShopMessageSuccess", tokens.state_success],
	]
	for spec in message_specs:
		var name: String = spec[0]
		theme.add_type(name)
		theme.set_type_variation(name, "Label")
		theme.set_font_size("font_size", name, 36)
		theme.set_color("font_color", name, spec[1])
		theme.set_color("font_shadow_color", name, Color.BLACK)
		theme.set_constant("shadow_offset_x", name, 2)
		theme.set_constant("shadow_offset_y", name, 2)

	# (Unused since Plan A deleted SemesterEnd -- kept baked; removing a
	# variation needs a theme rebake, which is out of scope.)
	# SemesterEnd was the one screen that deliberately kept a dark,
	# certificate-like backdrop instead of the app's usual light surface
	# (the payoff/results reveal), so its outer labels needed their own
	# light-on-dark variations rather than the light-surface defaults
	# every other label variation assumes.
	theme.add_type("ResultHeroLabel")
	theme.set_type_variation("ResultHeroLabel", "Label")
	theme.set_font_size("font_size", "ResultHeroLabel", tokens.font_h2)
	theme.set_color("font_color", "ResultHeroLabel", tokens.currency_gold)
	theme.set_constant("outline_size", "ResultHeroLabel", tokens.text_outline_size)
	theme.set_color("font_outline_color", "ResultHeroLabel", tokens.text_primary)

	theme.add_type("ResultBodyLabel")
	theme.set_type_variation("ResultBodyLabel", "Label")
	theme.set_font_size("font_size", "ResultBodyLabel", tokens.font_caption)
	theme.set_color("font_color", "ResultBodyLabel", tokens.text_on_brand)


# --------------------------------------------------------------- progress

## Shared fill art for every progress bar in the game (StatBar and the
## DaySummary tracks below) -- one rounded-rect piece, stretched via a
## 9-patch margin so it fits any bar width/height without distorting its
## corners. modulate_color is what lets the same texture serve every
## category: white leaves it untouched for StatBar (whose callers tint
## the whole node via self_modulate instead, see StatBar.gd), while
## DaySummary's tracks bake their category colour directly into the
## stylebox since those bars don't use self_modulate.
const _PROGRESS_FILL_ART := "res://Assets/Images/UI/progress_bar_fill.png"

## Measured off the 256x256 source: the opaque rounded-rect content sits
## inside this region, with transparent padding around it that must not
## be stretched into the bar. Margin keeps both rounded ends intact
## (2*24 = 48 < 124, the region's height).
const _PROGRESS_FILL_REGION := Rect2(60, 66, 148, 124)
const _PROGRESS_FILL_MARGIN := 24

static func _progress_fill_stylebox(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var fill := StyleBoxTexture.new()
	fill.texture = load(_PROGRESS_FILL_ART)
	fill.region_rect = _PROGRESS_FILL_REGION
	fill.set_texture_margin_all(_PROGRESS_FILL_MARGIN)
	fill.modulate_color = modulate
	return fill

static func _build_progress(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("StatBar")
	theme.set_type_variation("StatBar", "ProgressBar")

	# The track is a sticker capsule like the rest of the chrome: sunken
	# ground, white rim, soft drop shadow. content_margin insets the fill
	# so a rail of track stays visible even at 100% -- without it the
	# coloured fill runs flush to the rim and the bar reads as a debug
	# widget. The inset is half outline_width so the rail and the rim
	# stay a 1:1 pair at any token value.
	var bg := StyleBoxFlat.new()
	bg.bg_color = tokens.surface_sunken
	bg.set_corner_radius_all(tokens.radius_pill)
	bg.set_border_width_all(int(tokens.outline_width / 2.0))
	bg.border_color = tokens.outline_card
	bg.shadow_color = tokens.shadow_color
	bg.shadow_size = int(tokens.shadow_size / 2.0)
	bg.shadow_offset = tokens.shadow_offset
	bg.set_content_margin_all(tokens.outline_width / 2.0)
	theme.set_stylebox("background", "StatBar", bg)

	# Plain "StatBar" is now only the neutral fallback for an unrecognised
	# category (StatBar.gd._STAT_BAR_VARIATIONS) -- every real caller
	# resolves to one of the six per-category siblings below, whose fill
	# stylebox bakes its colour in directly. None of them tint via
	# self_modulate any more.
	theme.set_stylebox("fill", "StatBar", _progress_fill_stylebox())

	theme.set_font_size("font_size", "StatBar", tokens.font_caption)
	theme.set_color("font_color", "StatBar", tokens.text_primary)

	# self_modulate tints the WHOLE node, not just the fill -- so a StatBar
	# tinted that way multiplies its category colour onto the track's
	# surface_sunken ground and white rim too, and a fill sitting on a
	# same-coloured track is indistinguishable from it. At value 0 that
	# made every bar read as a solid capsule, 100% full. So AturJadwal's
	# per-category bars get their colour baked into the FILL stylebox
	# instead (the same fix DaySummary's tracks already use above), and
	# StatBar.gd switches those bars to theme_type_variation + white
	# self_modulate rather than tinting the node. One variation per
	# category, each set_type_variation'd directly off "ProgressBar" (not
	# chained onto "StatBar") -- the rim/shadow/inset chrome staying
	# identical across all six is because they're handed the SAME `bg`
	# StyleBoxFlat instance below, and font size/color are copied from the
	# same tokens explicitly, not because they inherit from "StatBar". A
	# new theme item added to "StatBar" later will NOT reach these six
	# siblings automatically -- it would need to be added here too.
	var stat_bar_categories := [
		["StatBarAkademis", tokens.cat_akademis],
		["StatBarSeniBudaya", tokens.cat_senibudaya],
		["StatBarOlahraga", tokens.cat_olahraga],
		["StatBarIstirahat", tokens.cat_istirahat],
		["StatBarLibur", tokens.cat_libur],
		["StatBarWirausaha", tokens.cat_wirausaha],
	]
	for spec in stat_bar_categories:
		var name: String = spec[0]
		var color: Color = spec[1]
		theme.add_type(name)
		theme.set_type_variation(name, "ProgressBar")
		theme.set_stylebox("background", name, bg)
		theme.set_stylebox("fill", name, _progress_fill_stylebox(color))
		theme.set_font_size("font_size", name, tokens.font_caption)
		theme.set_color("font_color", name, tokens.text_primary)


# ------------------------------------------------- student card redesign

const _CARD_ART := "res://Assets/Images/StudentCard/"


## Variations used only by the student card's redesigned layout. The card
## background art paints the pill tracks, the bio panel, and the portrait
## frame, so these styles deliberately draw less than their siblings: the
## pill contributes only a fill, and the bio text is light because it sits
## on the painted purple panel.
static func _build_student_card(theme: Theme, tokens: DesignTokens) -> void:
	# -- Stat pill: fill only; the track is painted into the card art. --
	theme.add_type("StatPill")
	theme.set_type_variation("StatPill", "ProgressBar")
	theme.set_stylebox("background", "StatPill", StyleBoxEmpty.new())

	var pill_fill := StyleBoxTexture.new()
	pill_fill.texture = load(_CARD_ART + "pill_fill.png")
	# The art sits inset on a 256x256 canvas; region_rect crops to it so no
	# transparent padding is stretched into the bar.
	pill_fill.region_rect = Rect2(59, 65, 150, 127)
	# 28 px keeps both rounded ends intact inside a 67 px tall track
	# (28 + 28 < 67); anything larger would overlap and distort them.
	pill_fill.set_texture_margin_all(28)
	theme.set_stylebox("fill", "StatPill", pill_fill)

	# -- Trait button ("Sifat Pasif" pills): the art ships gold with its own
	# purple border, so the stylebox draws it untinted. A modulate here
	# multiplies against the texture rather than replacing its colour --
	# it would mud the fill to olive and turn the border brown. --
	theme.add_type("TraitPill")
	theme.set_type_variation("TraitPill", "Button")

	var trait_normal := StyleBoxTexture.new()
	trait_normal.texture = load(_CARD_ART + "trait_button.png")
	trait_normal.region_rect = Rect2(20, 277, 601, 91)
	trait_normal.set_texture_margin_all(45)
	theme.set_stylebox("normal", "TraitPill", trait_normal)
	theme.set_stylebox("hover", "TraitPill", trait_normal)
	theme.set_stylebox("pressed", "TraitPill", trait_normal)
	theme.set_stylebox("focus", "TraitPill", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "TraitPill", tokens.font_h2)
	theme.set_color("font_color", "TraitPill", tokens.text_on_brand)
	theme.set_constant("outline_size", "TraitPill", 6)
	theme.set_color("font_outline_color", "TraitPill", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "TraitPill", tokens.font_display)

	# -- "Sifat Pasif:" section heading: white text needs a dark outline to
	# read against the light card background, unlike the shared TitleLabel
	# (which is dark-on-light and used across many other screens). --
	theme.add_type("CardSectionLabel")
	theme.set_type_variation("CardSectionLabel", "Label")
	theme.set_font_size("font_size", "CardSectionLabel", tokens.font_title)
	theme.set_color("font_color", "CardSectionLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "CardSectionLabel", 4)
	theme.set_color("font_outline_color", "CardSectionLabel", tokens.text_primary)

	# -- Bio text: light, because it sits on the painted purple panel. --
	theme.add_type("BioLabel")
	theme.set_type_variation("BioLabel", "Label")
	theme.set_font_size("font_size", "BioLabel", tokens.font_body_size)
	theme.set_color("font_color", "BioLabel", tokens.text_on_brand)

	theme.add_type("BioValue")
	theme.set_type_variation("BioValue", "Label")
	theme.set_font_size("font_size", "BioValue", tokens.font_body_size + 6)
	theme.set_color("font_color", "BioValue", tokens.text_on_brand)

	# -- Penjadwalan row container: the bordered grey slab each row sits on.
	# The icon draws directly onto this; the pill below is inset into it. The
	# mockup shows a hard dark shadow just under the bottom border. --
	var preview_row := StyleBoxFlat.new()
	preview_row.bg_color = tokens.preview_row_fill
	preview_row.border_color = tokens.preview_row_border
	preview_row.set_border_width_all(3)
	preview_row.set_corner_radius_all(tokens.radius_md)
	preview_row.shadow_color = tokens.preview_row_shadow_color
	preview_row.shadow_size = tokens.preview_row_shadow_size
	preview_row.shadow_offset = tokens.preview_row_shadow_offset
	theme.add_type("PreviewRow")
	theme.set_type_variation("PreviewRow", "Panel")
	theme.set_stylebox("panel", "PreviewRow", preview_row)

	# -- The darker pill inset into the row, carrying the numbers. Its edge in
	# the mockup is a soft dark halo, NOT a stroke -- building it as a border
	# reads as a hard outline the reference does not have. --
	var preview_pill := StyleBoxFlat.new()
	preview_pill.bg_color = tokens.preview_pill_fill
	preview_pill.set_corner_radius_all(tokens.radius_md)
	preview_pill.content_margin_left = tokens.space_sm
	preview_pill.content_margin_right = tokens.space_sm
	preview_pill.content_margin_top = tokens.space_xs
	preview_pill.content_margin_bottom = tokens.space_xs
	preview_pill.shadow_color = tokens.preview_pill_shadow_color
	preview_pill.shadow_size = tokens.preview_pill_shadow_size
	preview_pill.shadow_offset = tokens.preview_pill_shadow_offset
	theme.add_type("PreviewPill")
	theme.set_type_variation("PreviewPill", "PanelContainer")
	theme.set_stylebox("panel", "PreviewPill", preview_pill)

	# -- Wirausaha and Libur have no target, so no inset pill: their chips
	# sit straight on the container's grey. Same node, no panel drawn. --
	theme.add_type("PreviewPillFlat")
	theme.set_type_variation("PreviewPillFlat", "PanelContainer")
	theme.set_stylebox("panel", "PreviewPillFlat", StyleBoxEmpty.new())

	# -- The numbers inside that pill: white on the dark slab. --
	theme.add_type("PreviewChipLabel")
	theme.set_type_variation("PreviewChipLabel", "Label")
	theme.set_font_size("font_size", "PreviewChipLabel", tokens.font_h2)
	theme.set_color("font_color", "PreviewChipLabel", tokens.text_on_brand)

	# -- The category name under each row. Bigger and rimmed harder than
	# CardSectionLabel, which is shared with StudentCard and must not move. --
	theme.add_type("PreviewRowLabel")
	theme.set_type_variation("PreviewRowLabel", "Label")
	theme.set_font_size("font_size", "PreviewRowLabel", tokens.font_h2)
	theme.set_color("font_color", "PreviewRowLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "PreviewRowLabel", 6)
	theme.set_color("font_outline_color", "PreviewRowLabel", tokens.preview_row_border)
	if tokens.font_display != null:
		theme.set_font("font", "PreviewRowLabel", tokens.font_display)


# ------------------------------------------------- unstyled base controls

## Baseline styling for controls used without a variation, so a plain
## Button or Panel dropped into a scene never renders as Godot default gray.
static func _build_base_overrides(theme: Theme, tokens: DesignTokens) -> void:
	theme.set_color("font_color", "Label", tokens.text_primary)
	theme.set_font_size("font_size", "Label", tokens.font_body_size)

	var panel := StyleBoxFlat.new()
	panel.bg_color = tokens.surface_card
	panel.set_corner_radius_all(tokens.radius_md)
	theme.set_stylebox("panel", "Panel", panel)

	theme.set_color("font_color", "Button", tokens.text_on_brand)
	theme.set_font_size("font_size", "Button", tokens.font_title)
	theme.set_stylebox("normal", "Button",
		_pill(tokens, tokens.brand_primary_light, tokens.brand_primary_dark,
			tokens.outline_card, 0.0))
	theme.set_stylebox("hover", "Button",
		_pill(tokens, tokens.brand_primary_light.lightened(0.08),
			tokens.brand_primary_dark.lightened(0.08), tokens.outline_card, 0.0))
	theme.set_stylebox("pressed", "Button",
		_pill(tokens, tokens.brand_primary_dark, tokens.brand_primary_light,
			tokens.outline_card, -tokens.shadow_offset.y * 0.5))
	theme.set_stylebox("disabled", "Button",
		_pill(tokens, tokens.surface_sunken, tokens.surface_sunken,
			tokens.surface_sunken, 0.0))

	# RichTextLabel's base text color theme item is "default_color", not
	# "font_color" (that name is a Label/Button theme item). Setting
	# "font_color" here was a silent no-op: RichTextLabel never reads a
	# key by that name, so any RichTextLabel without a per-node override
	# fell back to the engine default (white), invisible against a white
	# Card background. Found via Task 11 (CutScene)'s live walkthrough --
	# DialogueLabel rendered a fully-revealed but blank line.
	theme.set_color("default_color", "RichTextLabel", tokens.text_primary)
	theme.set_font_size("normal_font_size", "RichTextLabel", tokens.font_body_size)

	# Container rhythm: every screen gets consistent spacing/margins from
	# the theme instead of per-scene theme_override_constants.
	theme.set_constant("separation", "VBoxContainer", tokens.space_md)
	theme.set_constant("separation", "HBoxContainer", tokens.space_sm)
	theme.set_constant("margin_left", "MarginContainer", tokens.screen_margin)
	theme.set_constant("margin_right", "MarginContainer", tokens.screen_margin)
	theme.set_constant("margin_top", "MarginContainer", tokens.screen_margin)
	theme.set_constant("margin_bottom", "MarginContainer", tokens.screen_margin)


# ------------------------------------------------------- day summary

## Variations for the Daily Results card (spec:
## 2026-08-29-day-summary-mockup-design.md). Two things here deliberately
## break this file's usual habits, both because the card art is pale and
## saturated rather than the app's neutral light surface:
##   * text is white with a DARK rim, inverting the usual relationship;
##   * the bars carry their own border colour instead of leaning on
##     outline_card, because the mockup's rim is near-black, not white.
static func _build_day_summary(theme: Theme, tokens: DesignTokens) -> void:
	# name, size, outline divisor
	var text_specs := [
		["DaySummaryName", tokens.day_name_size],
		["DaySummaryStat", tokens.day_stat_size],
	]
	for spec in text_specs:
		var name: String = spec[0]
		theme.add_type(name)
		theme.set_type_variation(name, "Label")
		theme.set_font_size("font_size", name, spec[1])
		theme.set_color("font_color", name, Color.WHITE)
		theme.set_constant("outline_size", name,
			maxi(2, tokens.text_outline_size / 2))
		theme.set_color("font_outline_color", name, tokens.day_glyph_outline)
		if tokens.font_display != null:
			theme.set_font("font", name, tokens.font_display)

	theme.add_type("DaySummaryAvatarFrame")
	theme.set_type_variation("DaySummaryAvatarFrame", "Panel")
	var frame := StyleBoxFlat.new()
	frame.bg_color = tokens.day_avatar_fill
	frame.border_color = tokens.day_avatar_border
	frame.set_border_width_all(5)
	frame.set_corner_radius_all(tokens.day_avatar_radius)
	theme.set_stylebox("panel", "DaySummaryAvatarFrame", frame)

	# The two needs bars and the three stat tracks are the same slab in
	# five flavours: same rim, same radius family, different fill.
	# The stat tracks share the mockup's dark rail and differ only in
	# fill, which carries the subject's category colour so the three
	# rows read apart at a glance the same way their icons do.
	# name, track color, fill color, radius
	var bar_specs := [
		["DaySummaryEnergyBar", tokens.day_bar_track,
			tokens.day_energy_fill, tokens.day_bar_radius],
		["DaySummaryMoodBar", tokens.day_bar_track,
			tokens.day_mood_fill, tokens.day_bar_radius],
		["DaySummaryStatTrackAkademis", tokens.day_stat_track,
			tokens.cat_akademis, tokens.radius_pill],
		["DaySummaryStatTrackSeniBudaya", tokens.day_stat_track,
			tokens.cat_senibudaya, tokens.radius_pill],
		["DaySummaryStatTrackOlahraga", tokens.day_stat_track,
			tokens.cat_olahraga, tokens.radius_pill],
	]
	for spec in bar_specs:
		var name: String = spec[0]
		theme.add_type(name)
		theme.set_type_variation(name, "ProgressBar")

		var track := StyleBoxFlat.new()
		track.bg_color = spec[1]
		track.border_color = tokens.day_bar_border
		track.set_border_width_all(5)
		track.set_corner_radius_all(spec[3])
		theme.set_stylebox("background", name, track)

		theme.set_stylebox("fill", name, _progress_fill_stylebox(spec[2]))

	# The 2026-09-03 needs word, which sits ON the energy/mood bar rather
	# than in a chip of its own -- so there is no new stylebox here, only
	# type. Same white-on-dark-rim inversion the rest of this card uses.
	# Sized from its OWN token (day_needs_label_size), not derived from
	# DaySummaryStat's -- the two used to share one via "day_stat_size - 4"
	# and a stat-row font bump silently overran the needs bar's pill when
	# that dragged the needs word up with it. See day_needs_label_size's
	# own doc comment for the measured numbers.
	theme.add_type("DaySummaryNeedsLabel")
	theme.set_type_variation("DaySummaryNeedsLabel", "Label")
	theme.set_font_size("font_size", "DaySummaryNeedsLabel",
		tokens.day_needs_label_size)
	theme.set_color("font_color", "DaySummaryNeedsLabel", Color.WHITE)
	theme.set_constant("outline_size", "DaySummaryNeedsLabel",
		maxi(2, tokens.text_outline_size / 2))
	theme.set_color("font_outline_color", "DaySummaryNeedsLabel",
		tokens.day_glyph_outline)
	if tokens.font_display != null:
		theme.set_font("font", "DaySummaryNeedsLabel", tokens.font_display)


# ------------------------------------------------------------ week recap

static func _build_week_recap(theme: Theme, tokens: DesignTokens) -> void:
	# The banner is a raised card that must not read as another student
	# card, so it takes the card surface with the brand's own edge.
	theme.add_type("RecapBannerPanel")
	theme.set_type_variation("RecapBannerPanel", "Panel")
	var recap_banner := StyleBoxFlat.new()
	recap_banner.bg_color = tokens.surface_card
	recap_banner.set_corner_radius_all(tokens.radius_md)
	recap_banner.border_color = tokens.brand_primary
	recap_banner.set_border_width_all(int(tokens.outline_width) / 2)
	recap_banner.content_margin_left = tokens.space_md
	recap_banner.content_margin_right = tokens.space_md
	recap_banner.content_margin_top = tokens.space_sm
	recap_banner.content_margin_bottom = tokens.space_sm
	theme.set_stylebox("panel", "RecapBannerPanel", recap_banner)

	# A pill is a sunken capsule -- the counter-form to the banner it sits
	# inside.
	theme.add_type("RecapPillPanel")
	theme.set_type_variation("RecapPillPanel", "Panel")
	var recap_pill := StyleBoxFlat.new()
	recap_pill.bg_color = tokens.surface_sunken
	recap_pill.set_corner_radius_all(tokens.radius_pill)
	recap_pill.content_margin_left = tokens.space_sm
	recap_pill.content_margin_right = tokens.space_sm
	recap_pill.content_margin_top = tokens.space_xs
	recap_pill.content_margin_bottom = tokens.space_xs
	theme.set_stylebox("panel", "RecapPillPanel", recap_pill)

	# The pill's number. Tinted per-pill via self_modulate, so the
	# variation itself stays neutral.
	theme.add_type("RecapPillValueLabel")
	theme.set_type_variation("RecapPillValueLabel", "Label")
	theme.set_font_size("font_size", "RecapPillValueLabel", tokens.font_h2)
	theme.set_color("font_color", "RecapPillValueLabel", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "RecapPillValueLabel", tokens.font_display)

	# The tab. A real pressed state is what makes the active tab legible
	# without any manual tint at the call site.
	theme.add_type("WeekTabButton")
	theme.set_type_variation("WeekTabButton", "Button")
	var tab_normal := StyleBoxFlat.new()
	tab_normal.bg_color = tokens.surface_sunken
	tab_normal.corner_radius_top_left = tokens.radius_md
	tab_normal.corner_radius_top_right = tokens.radius_md
	tab_normal.content_margin_top = tokens.space_sm
	tab_normal.content_margin_bottom = tokens.space_sm
	var tab_pressed := tab_normal.duplicate() as StyleBoxFlat
	tab_pressed.bg_color = tokens.brand_primary
	theme.set_stylebox("normal", "WeekTabButton", tab_normal)
	theme.set_stylebox("hover", "WeekTabButton", tab_normal)
	theme.set_stylebox("pressed", "WeekTabButton", tab_pressed)
	theme.set_stylebox("focus", "WeekTabButton", tab_normal)
	theme.set_color("font_color", "WeekTabButton", tokens.text_secondary)
	theme.set_color("font_pressed_color", "WeekTabButton", tokens.text_on_brand)
	theme.set_color("font_hover_color", "WeekTabButton", tokens.text_primary)
	theme.set_font_size("font_size", "WeekTabButton", tokens.font_title)


# ---------------------------------------------------- minigame result card

## popup_bg.svg's nine-patch source for the result card's frame, following
## the same nine-patch dialog framing the 2026-09-02 PERINGATAN dialog
## established. Placeholder art (a plain rounded rect); the margin below
## keeps its rx=32 corners intact on a 200x200 canvas.
const _RESULT_CARD_ART := "res://Assets/Images/UI/Placeholders/popup_bg.svg"

## The 2026-09-04 minigame reward pass: the end-of-minigame result card and
## the shared in-run score HUD. Every box here replaces a runtime StyleBox
## MinigameResultPopup.configure() used to build from whichever BaseMinigame
## @export values the individual minigame happened to set -- which is why
## the card looked different across the eight games. See that spec's plan,
## docs/superpowers/plans/2026-09-04-minigame-reward-feedback.md, Task 10.
static func _build_minigame_result(theme: Theme, tokens: DesignTokens) -> void:
	# -- ResultCardPanel: the card's own frame. --
	theme.add_type("ResultCardPanel")
	theme.set_type_variation("ResultCardPanel", "Panel")
	var result_card := StyleBoxTexture.new()
	result_card.texture = load(_RESULT_CARD_ART)
	result_card.set_texture_margin_all(40)
	result_card.content_margin_left = 32
	result_card.content_margin_top = 28
	result_card.content_margin_right = 32
	result_card.content_margin_bottom = 28
	theme.set_stylebox("panel", "ResultCardPanel", result_card)

	# -- ResultStatPanel: derived from SunkenPanel -- the score row and the
	# stat/energy/mood delta rows sit on this. --
	theme.add_type("ResultStatPanel")
	theme.set_type_variation("ResultStatPanel", "Panel")
	var result_stat := StyleBoxFlat.new()
	result_stat.bg_color = tokens.surface_sunken
	result_stat.set_corner_radius_all(tokens.radius_md)
	result_stat.content_margin_left = 20
	result_stat.content_margin_top = 12
	result_stat.content_margin_right = 20
	result_stat.content_margin_bottom = 12
	theme.set_stylebox("panel", "ResultStatPanel", result_stat)

	# -- ResultBadgePanel: the category chip's ground. The category accent
	# is applied to the badge's icon TextureRect, never to this panel -- a
	# self_modulate on the panel would multiply its own background too,
	# the same StatBar hazard the 2026-09-02 pass hit. --
	theme.add_type("ResultBadgePanel")
	theme.set_type_variation("ResultBadgePanel", "Panel")
	var result_badge := StyleBoxFlat.new()
	result_badge.bg_color = tokens.surface_card
	result_badge.set_corner_radius_all(tokens.radius_pill)
	result_badge.content_margin_left = 18
	result_badge.content_margin_top = 8
	result_badge.content_margin_right = 18
	result_badge.content_margin_bottom = 8
	theme.set_stylebox("panel", "ResultBadgePanel", result_badge)

	# -- ResultStarSlot: a bare marker variation, no stylebox of its own.
	# Exists only so ResultStar.tscn's root can carry a
	# theme_type_variation instead of the star's 88x88 footprint being
	# passed down as a runtime @export (popup_star_size) -- the node's own
	# custom_minimum_size still sets the actual size. --
	theme.add_type("ResultStarSlot")
	theme.set_type_variation("ResultStarSlot", "Control")

	# -- ResultDeltaLabel: the stat/energy/mood delta rows' text. --
	# font_color is white, not tokens.text_primary -- MinigameResultPopup
	# always overrides this label's colour via self_modulate (green for a
	# gain, red for a loss), and self_modulate *multiplies* the base colour.
	# text_primary is a dark navy; multiplying green/red by near-black
	# collapsed both to near-black, destroying the +/- colour coding. White
	# is the multiplicative identity, so self_modulate's colour reads as-is.
	theme.add_type("ResultDeltaLabel")
	theme.set_type_variation("ResultDeltaLabel", "Label")
	theme.set_font_size("font_size", "ResultDeltaLabel", tokens.font_caption)
	theme.set_color("font_color", "ResultDeltaLabel", Color.WHITE)
	theme.set_constant("outline_size", "ResultDeltaLabel", 4)
	theme.set_color("font_outline_color", "ResultDeltaLabel", tokens.text_outline_color)

	# -- ScoreHudPanel: a translucent dark pill for the in-run score HUD,
	# so the readout stays legible over any minigame's own background art. --
	theme.add_type("ScoreHudPanel")
	theme.set_type_variation("ScoreHudPanel", "Panel")
	var score_hud_panel := StyleBoxFlat.new()
	score_hud_panel.bg_color = Color(tokens.surface_overlay.r,
		tokens.surface_overlay.g, tokens.surface_overlay.b, 0.55)
	score_hud_panel.set_corner_radius_all(tokens.radius_pill)
	score_hud_panel.content_margin_left = 18
	score_hud_panel.content_margin_top = 8
	score_hud_panel.content_margin_right = 18
	score_hud_panel.content_margin_bottom = 8
	theme.set_stylebox("panel", "ScoreHudPanel", score_hud_panel)

	# -- ScoreHudValueLabel: the HUD's score readout -- has to stay legible
	# over a football pitch and a batik cloth, so it borrows DisplayLabel's
	# weight rather than a body-text size. --
	theme.add_type("ScoreHudValueLabel")
	theme.set_type_variation("ScoreHudValueLabel", "Label")
	theme.set_font_size("font_size", "ScoreHudValueLabel", tokens.font_h1)
	theme.set_color("font_color", "ScoreHudValueLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "ScoreHudValueLabel", 8)
	theme.set_color("font_outline_color", "ScoreHudValueLabel", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "ScoreHudValueLabel", tokens.font_display)
