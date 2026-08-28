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
	_build_student_card(theme, tokens)
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

	# SemesterEnd is the one screen that deliberately keeps a dark,
	# certificate-like backdrop instead of the app's usual light surface
	# (the payoff/results reveal), so its outer labels need their own
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

static func _build_progress(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("StatBar")
	theme.set_type_variation("StatBar", "ProgressBar")

	var bg := StyleBoxFlat.new()
	bg.bg_color = tokens.surface_sunken
	bg.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("background", "StatBar", bg)

	# White fill so callers can tint per category via self_modulate.
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("fill", "StatBar", fill)

	theme.set_font_size("font_size", "StatBar", tokens.font_caption)
	theme.set_color("font_color", "StatBar", tokens.text_primary)


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

	# -- Trait button: one recolourable pill, tinted by the caller. --
	theme.add_type("TraitPill")
	theme.set_type_variation("TraitPill", "Button")

	var trait_normal := StyleBoxTexture.new()
	trait_normal.texture = load(_CARD_ART + "trait_button.png")
	trait_normal.region_rect = Rect2(20, 277, 601, 91)
	trait_normal.set_texture_margin_all(45)
	trait_normal.modulate_color = tokens.currency_gold
	theme.set_stylebox("normal", "TraitPill", trait_normal)
	theme.set_stylebox("hover", "TraitPill", trait_normal)
	theme.set_stylebox("pressed", "TraitPill", trait_normal)
	theme.set_stylebox("focus", "TraitPill", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "TraitPill", tokens.font_body_size)
	theme.set_color("font_color", "TraitPill", tokens.text_on_brand)

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
