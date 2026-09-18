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
	_build_achievement_tile_bar(theme, tokens)
	_build_day_summary(theme, tokens)
	_build_student_card(theme, tokens)
	_build_week_recap(theme, tokens)
	_build_minigame_result(theme, tokens)
	_build_event_warning(theme, tokens)
	_build_event_dialogue(theme, tokens)
	_build_shop_chat_bubble(theme, tokens)
	_build_achievements(theme, tokens)
	_build_achievement_tile(theme, tokens)
	_build_achievement_status_pill(theme, tokens)
	_build_base_overrides(theme, tokens)

	return theme


## Measured off mockup_eventdialogue.png: the dialogue card's corner radius
## and the day banner's brown rim. No token matches either; both are
## single-screen values.
const EVENT_DIALOGUE_RADIUS := 80
const DAY_BANNER_OUTLINE := 12

## Measured off newshop_mockup.png: the Koperasi chat bubble's ~24 px corner
## at the mockup's 5/6 scale. No token matches; a single-screen value.
const SHOP_CHAT_BUBBLE_RADIUS := 28


## Koperasi's chat bubble (2026-09-17 shop revamp spec): Pak Herman's
## speech, a flat card-white rounded box with no shadow. Its tail is
## chat_bubble_tail.svg, filled with the same surface_card colour
## (test_koperasi_shop_layout pins that). Body font, so not on DISPLAY_ROSTER.
static func _build_shop_chat_bubble(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("ShopChatBubble")
	theme.set_type_variation("ShopChatBubble", "PanelContainer")
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = tokens.surface_card
	bubble.set_corner_radius_all(SHOP_CHAT_BUBBLE_RADIUS)
	bubble.content_margin_left = tokens.space_xl
	bubble.content_margin_right = tokens.space_xl
	bubble.content_margin_top = tokens.space_lg
	bubble.content_margin_bottom = tokens.space_lg
	theme.set_stylebox("panel", "ShopChatBubble", bubble)


## The event dialogue (2026-09-14 event-dialogue spec): a white rounded card
## with dark bold text, and the header's day banner and calendar labels, all
## in the bold body face the mockup uses.
static func _build_event_dialogue(theme: Theme, tokens: DesignTokens) -> void:
	var bold: Font = tokens.font_body_bold if tokens.font_body_bold != null else tokens.font_body

	theme.add_type("EventDialoguePanel")
	theme.set_type_variation("EventDialoguePanel", "PanelContainer")
	var card := StyleBoxFlat.new()
	card.bg_color = tokens.surface_card
	card.set_corner_radius_all(EVENT_DIALOGUE_RADIUS)
	card.shadow_color = tokens.shadow_color
	card.shadow_size = tokens.shadow_size
	card.shadow_offset = tokens.shadow_offset
	card.content_margin_left = tokens.space_xl
	card.content_margin_right = tokens.space_xl
	card.content_margin_top = tokens.space_lg
	card.content_margin_bottom = tokens.space_lg
	theme.set_stylebox("panel", "EventDialoguePanel", card)

	# RichTextLabel's theme items are "normal_font"/"normal_font_size"/
	# "default_color", not the Label names -- see _add_cutscene_dialogue.
	theme.add_type("EventDialogueText")
	theme.set_type_variation("EventDialogueText", "RichTextLabel")
	theme.set_font_size("normal_font_size", "EventDialogueText", tokens.font_title + 8)
	theme.set_color("default_color", "EventDialogueText", tokens.text_primary)
	if bold != null:
		theme.set_font("normal_font", "EventDialogueText", bold)

	theme.add_type("DayBannerPanel")
	theme.set_type_variation("DayBannerPanel", "PanelContainer")
	var pill := StyleBoxFlat.new()
	pill.bg_color = tokens.surface_card
	pill.border_color = tokens.brand_primary_dark
	pill.set_border_width_all(DAY_BANNER_OUTLINE)
	pill.set_corner_radius_all(tokens.radius_pill)
	# The calendar badge overlaps the banner's left end in the mockup.
	pill.content_margin_left = tokens.space_xl + tokens.space_lg
	pill.content_margin_right = tokens.space_lg
	theme.set_stylebox("panel", "DayBannerPanel", pill)

	for spec in [["DayBannerLabel", tokens.font_h1], ["CalendarLabel", tokens.font_body_size]]:
		var variation: String = spec[0]
		theme.add_type(variation)
		theme.set_type_variation(variation, "Label")
		theme.set_font_size("font_size", variation, spec[1])
		theme.set_color("font_color", variation, tokens.text_primary)
		if bold != null:
			theme.set_font("font", variation, bold)


## Measured off Achievement mockup.psd (2026-09-17): single-screen values
## no token matches. The card is 865x306 with a 24px corner; Klaim is a
## 202x64 olive pill with a 6px rim.
const ACHIEVEMENT_RADIUS := 24
const ACHIEVEMENT_INK := Color.BLACK
const ACHIEVEMENT_CLAIM_FILL := Color("B2C73B")
const ACHIEVEMENT_CLAIM_RIM := Color("8D8A2F")
const ACHIEVEMENT_CLAIM_RIM_WIDTH := 6
const ACHIEVEMENT_TITLE_SIZE := 44
const ACHIEVEMENT_BODY_SIZE := 29
## Smaller than the card title so the longest names wrap to three lines in the banner.
const ACHIEVEMENT_TOAST_TITLE_SIZE := 40
## The claim celebration's lettering (achievementclaim_mockup.png): white
## display text rimmed in the event navy, and a white body hint.
const ACHIEVEMENT_CLAIM_HEADLINE_SIZE := 88
const ACHIEVEMENT_CLAIM_TITLE_SIZE := 76
const ACHIEVEMENT_CLAIM_HINT_SIZE := 52
const ACHIEVEMENT_CLAIM_OUTLINE := 22
## The claimed card's gradient and glow, baked 9-slice: 24px glow + 24px corner.
const _ACHIEVEMENT_CLAIMED_ART := "res://Assets/Images/Achievements/card_claimed.png"
const _ACHIEVEMENT_CLAIMED_GLOW := 24

## The Achievements screen (spec: docs/superpowers/specs/2026-09-17-achievements-design.md):
## white and claimed cards, their title and body text, the Klaim pill, and
## the unlock banner.
static func _build_achievements(theme: Theme, tokens: DesignTokens) -> void:
	var margins := func(box: StyleBox) -> void:
		box.content_margin_left = 25
		box.content_margin_top = 30
		box.content_margin_right = 25
		box.content_margin_bottom = 28

	theme.add_type("AchievementCard")
	theme.set_type_variation("AchievementCard", "PanelContainer")
	var card := StyleBoxFlat.new()
	card.bg_color = Color.WHITE
	card.set_corner_radius_all(ACHIEVEMENT_RADIUS)
	margins.call(card)
	theme.set_stylebox("panel", "AchievementCard", card)

	theme.add_type("AchievementCardClaimed")
	theme.set_type_variation("AchievementCardClaimed", "PanelContainer")
	var claimed := StyleBoxTexture.new()
	claimed.texture = load(_ACHIEVEMENT_CLAIMED_ART)
	claimed.set_texture_margin_all(_ACHIEVEMENT_CLAIMED_GLOW + ACHIEVEMENT_RADIUS)
	claimed.set_expand_margin_all(_ACHIEVEMENT_CLAIMED_GLOW)
	margins.call(claimed)
	theme.set_stylebox("panel", "AchievementCardClaimed", claimed)

	theme.add_type("AchievementTitleLabel")
	theme.set_type_variation("AchievementTitleLabel", "Label")
	theme.set_font_size("font_size", "AchievementTitleLabel", ACHIEVEMENT_TITLE_SIZE)
	theme.set_color("font_color", "AchievementTitleLabel", ACHIEVEMENT_INK)
	if tokens.font_display != null:
		theme.set_font("font", "AchievementTitleLabel", tokens.font_display)

	theme.add_type("AchievementDescLabel")
	theme.set_type_variation("AchievementDescLabel", "Label")
	theme.set_font_size("font_size", "AchievementDescLabel", ACHIEVEMENT_BODY_SIZE)
	theme.set_color("font_color", "AchievementDescLabel", ACHIEVEMENT_INK)

	const CLAIM := "AchievementClaimButton"
	theme.add_type(CLAIM)
	theme.set_type_variation(CLAIM, "Button")
	var states := {
		"normal": ACHIEVEMENT_CLAIM_FILL,
		"hover": ACHIEVEMENT_CLAIM_FILL.lightened(0.08),
		"pressed": ACHIEVEMENT_CLAIM_FILL.darkened(0.12),
		"focus": ACHIEVEMENT_CLAIM_FILL,
	}
	for state in states:
		var pill := StyleBoxFlat.new()
		pill.bg_color = states[state]
		pill.border_color = ACHIEVEMENT_CLAIM_RIM
		pill.set_border_width_all(ACHIEVEMENT_CLAIM_RIM_WIDTH)
		pill.set_corner_radius_all(tokens.radius_pill)
		theme.set_stylebox(state, CLAIM, pill)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(key, CLAIM, Color.WHITE)
	theme.set_font_size("font_size", CLAIM, ACHIEVEMENT_BODY_SIZE)
	if tokens.font_display != null:
		theme.set_font("font", CLAIM, tokens.font_display)

	theme.add_type("AchievementToastPanel")
	theme.set_type_variation("AchievementToastPanel", "Panel")
	var toast := StyleBoxFlat.new()
	toast.bg_color = Color.WHITE
	toast.corner_radius_bottom_left = ACHIEVEMENT_RADIUS
	toast.corner_radius_bottom_right = ACHIEVEMENT_RADIUS
	theme.set_stylebox("panel", "AchievementToastPanel", toast)

	theme.add_type("AchievementToastTitleLabel")
	theme.set_type_variation("AchievementToastTitleLabel", "Label")
	theme.set_font_size("font_size", "AchievementToastTitleLabel", ACHIEVEMENT_TOAST_TITLE_SIZE)
	theme.set_color("font_color", "AchievementToastTitleLabel", ACHIEVEMENT_INK)
	if tokens.font_display != null:
		theme.set_font("font", "AchievementToastTitleLabel", tokens.font_display)

	for pair in [["AchievementClaimHeadlineLabel", ACHIEVEMENT_CLAIM_HEADLINE_SIZE],
			["AchievementClaimTitleLabel", ACHIEVEMENT_CLAIM_TITLE_SIZE]]:
		var claim_name: String = pair[0]
		theme.add_type(claim_name)
		theme.set_type_variation(claim_name, "Label")
		theme.set_font_size("font_size", claim_name, pair[1])
		theme.set_color("font_color", claim_name, Color.WHITE)
		theme.set_constant("outline_size", claim_name, ACHIEVEMENT_CLAIM_OUTLINE)
		theme.set_color("font_outline_color", claim_name, tokens.event_warning_ink)
		if tokens.font_display != null:
			theme.set_font("font", claim_name, tokens.font_display)

	theme.add_type("AchievementClaimHintLabel")
	theme.set_type_variation("AchievementClaimHintLabel", "Label")
	theme.set_font_size("font_size", "AchievementClaimHintLabel", ACHIEVEMENT_CLAIM_HINT_SIZE)
	theme.set_color("font_color", "AchievementClaimHintLabel", Color.WHITE)


## The 2-column achievement grid tile (2026-09-18 achievements-polish spec):
## a small prize chip (neutral when the entry carries no effect, amber when
## it does) and a tiny "BARU" unlock pip. Both chips reuse the Card
## variation's radius_pill shape so they read as siblings of the trait
## chips (QuirkBadge/PersonaBadge) despite being Panels, not Buttons -- the
## tile itself is the tappable surface (AchievementTile.gd's _gui_input),
## so these inner chips must stay non-interactive Panels.
static func _build_achievement_tile(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("AchievementPrizeChip")
	theme.set_type_variation("AchievementPrizeChip", "Panel")
	var neutral := StyleBoxFlat.new()
	neutral.bg_color = tokens.surface_sunken
	neutral.set_corner_radius_all(tokens.radius_pill)
	neutral.content_margin_left = tokens.space_md
	neutral.content_margin_right = tokens.space_md
	neutral.content_margin_top = tokens.space_xs
	neutral.content_margin_bottom = tokens.space_xs
	theme.set_stylebox("panel", "AchievementPrizeChip", neutral)

	theme.add_type("AchievementPrizeChipAmber")
	theme.set_type_variation("AchievementPrizeChipAmber", "Panel")
	var amber := StyleBoxFlat.new()
	amber.bg_color = tokens.state_warning.lightened(0.35)
	amber.border_color = tokens.state_warning
	amber.set_border_width_all(int(tokens.outline_width / 2.0))
	amber.set_corner_radius_all(tokens.radius_pill)
	amber.content_margin_left = tokens.space_md
	amber.content_margin_right = tokens.space_md
	amber.content_margin_top = tokens.space_xs
	amber.content_margin_bottom = tokens.space_xs
	theme.set_stylebox("panel", "AchievementPrizeChipAmber", amber)

	theme.add_type("AchievementPrizeChipLabel")
	theme.set_type_variation("AchievementPrizeChipLabel", "Label")
	theme.set_font_size("font_size", "AchievementPrizeChipLabel", tokens.font_micro)
	theme.set_color("font_color", "AchievementPrizeChipLabel", tokens.text_secondary)
	if tokens.font_display != null:
		theme.set_font("font", "AchievementPrizeChipLabel", tokens.font_display)

	theme.add_type("AchievementPrizeChipLabelAmber")
	theme.set_type_variation("AchievementPrizeChipLabelAmber", "Label")
	theme.set_font_size("font_size", "AchievementPrizeChipLabelAmber", tokens.font_micro)
	theme.set_color("font_color", "AchievementPrizeChipLabelAmber", tokens.state_warning.darkened(0.35))
	if tokens.font_display != null:
		theme.set_font("font", "AchievementPrizeChipLabelAmber", tokens.font_display)

	# The "BARU" unlock pip, top-right corner of the tile.
	theme.add_type("AchievementBaruBadge")
	theme.set_type_variation("AchievementBaruBadge", "Panel")
	var baru := StyleBoxFlat.new()
	baru.bg_color = tokens.state_success
	baru.set_corner_radius_all(tokens.radius_pill)
	baru.content_margin_left = tokens.space_xs
	baru.content_margin_right = tokens.space_xs
	baru.content_margin_top = tokens.space_xs / 2.0
	baru.content_margin_bottom = tokens.space_xs / 2.0
	theme.set_stylebox("panel", "AchievementBaruBadge", baru)

	theme.add_type("AchievementBaruBadgeLabel")
	theme.set_type_variation("AchievementBaruBadgeLabel", "Label")
	theme.set_font_size("font_size", "AchievementBaruBadgeLabel", tokens.font_micro)
	theme.set_color("font_color", "AchievementBaruBadgeLabel", tokens.text_on_brand)
	if tokens.font_display != null:
		theme.set_font("font", "AchievementBaruBadgeLabel", tokens.font_display)


## The header's morphing status pill (2026-09-18 achievements-polish spec,
## Task 4): a cream IDLE background and a green WAITING background, each
## with a label variation whose font color reads on top of it, plus the
## IDLE dash bar's two segment fills.
static func _build_achievement_status_pill(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("AchievementStatusPillIdle")
	theme.set_type_variation("AchievementStatusPillIdle", "PanelContainer")
	var idle_box := StyleBoxFlat.new()
	idle_box.bg_color = tokens.surface_card
	idle_box.set_corner_radius_all(tokens.radius_pill)
	idle_box.content_margin_left = tokens.space_md
	idle_box.content_margin_right = tokens.space_md
	idle_box.content_margin_top = tokens.space_xs
	idle_box.content_margin_bottom = tokens.space_xs
	theme.set_stylebox("panel", "AchievementStatusPillIdle", idle_box)

	theme.add_type("AchievementStatusPillWaiting")
	theme.set_type_variation("AchievementStatusPillWaiting", "PanelContainer")
	var waiting_box := StyleBoxFlat.new()
	waiting_box.bg_color = tokens.state_success
	waiting_box.set_corner_radius_all(tokens.radius_pill)
	waiting_box.content_margin_left = tokens.space_md
	waiting_box.content_margin_right = tokens.space_md
	waiting_box.content_margin_top = tokens.space_xs
	waiting_box.content_margin_bottom = tokens.space_xs
	theme.set_stylebox("panel", "AchievementStatusPillWaiting", waiting_box)

	theme.add_type("AchievementStatusPillIdleLabel")
	theme.set_type_variation("AchievementStatusPillIdleLabel", "Label")
	theme.set_color("font_color", "AchievementStatusPillIdleLabel", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "AchievementStatusPillIdleLabel", tokens.font_display)

	theme.add_type("AchievementStatusPillWaitingLabel")
	theme.set_type_variation("AchievementStatusPillWaitingLabel", "Label")
	theme.set_color("font_color", "AchievementStatusPillWaitingLabel", tokens.text_on_brand)
	if tokens.font_display != null:
		theme.set_font("font", "AchievementStatusPillWaitingLabel", tokens.font_display)

	theme.add_type("AchievementDashSegmentFilled")
	theme.set_type_variation("AchievementDashSegmentFilled", "Panel")
	var seg_filled := StyleBoxFlat.new()
	seg_filled.bg_color = tokens.state_success
	seg_filled.set_corner_radius_all(2)
	theme.set_stylebox("panel", "AchievementDashSegmentFilled", seg_filled)

	theme.add_type("AchievementDashSegmentEmpty")
	theme.set_type_variation("AchievementDashSegmentEmpty", "Panel")
	var seg_empty := StyleBoxFlat.new()
	seg_empty.bg_color = tokens.surface_sunken
	seg_empty.set_corner_radius_all(2)
	theme.set_stylebox("panel", "AchievementDashSegmentEmpty", seg_empty)


## The slide warning (2026-09-12 event-cards spec, 2.1): a flat mustard
## panel from the mockup, and a display-face caption in the light brand text
## colour rimmed in the icon's navy, so the words and the megaphone read as
## one mark.
static func _build_event_warning(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("EventWarningPanel")
	theme.set_type_variation("EventWarningPanel", "Panel")
	var panel := StyleBoxFlat.new()
	panel.bg_color = tokens.event_warning_bg
	theme.set_stylebox("panel", "EventWarningPanel", panel)

	theme.add_type("EventWarningCaptionLabel")
	theme.set_type_variation("EventWarningCaptionLabel", "Label")
	theme.set_font_size("font_size", "EventWarningCaptionLabel", tokens.font_display_size)
	theme.set_color("font_color", "EventWarningCaptionLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "EventWarningCaptionLabel",
		tokens.event_warning_caption_outline)
	theme.set_color("font_outline_color", "EventWarningCaptionLabel", tokens.event_warning_ink)
	if tokens.font_display != null:
		theme.set_font("font", "EventWarningCaptionLabel", tokens.font_display)


## The shop hub's two destination tiles, panel-less by design.
##
## Deliberately NOT _add_button_variation: a pill's light card fill made
## the white icons invisible against it and read as an egg rather than a
## tile. The mockup has no panel under them at all -- icon and caption sit
## straight on the dimmed blur -- so normal draws nothing and only the
## touch states wash in, which is also the only affordance a tile this
## size needs.
static func _add_shop_hub_tile(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "ShopHubTile"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Button")

	theme.set_stylebox("normal", NAME, StyleBoxEmpty.new())
	theme.set_stylebox("focus", NAME, StyleBoxEmpty.new())

	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(1, 1, 1, 0.14)
	wash.set_corner_radius_all(tokens.radius_button)
	theme.set_stylebox("hover", NAME, wash)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1, 1, 1, 0.24)
	pressed.set_corner_radius_all(tokens.radius_button)
	theme.set_stylebox("pressed", NAME, pressed)
	theme.set_stylebox("disabled", NAME, StyleBoxEmpty.new())


## The caption under each hub tile. White, because it sits on the dimmed
## blur rather than on a panel -- H2Label's ink would disappear into it.
static func _add_shop_hub_tile_label(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "ShopHubTileLabel"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Label")
	theme.set_font_size("font_size", NAME, tokens.font_h2)
	theme.set_color("font_color", NAME, tokens.text_on_brand)
	theme.set_constant("outline_size", NAME, 8)
	theme.set_color("font_outline_color", NAME, Color(0, 0, 0, 0.55))
	if tokens.font_display != null:
		theme.set_font("font", NAME, tokens.font_display)


## A button with no chrome of its own, for sitting on top of art that
## already draws the button -- the daily-login panel's baked gold pill.
##
## Modelled on ShopHubTile, which solves the same problem for the shop
## hub's panel-less tiles: nothing in the resting state, and only the
## touch states wash in.
##
## Unlike ShopHubTile, the wash radius here is radius_pill, not
## radius_button. The two solve different shapes: ShopHubTile's icon card
## is squarish, so its fixed radius_button corner is correct. This button
## sits on Task 8's baked claim-button art (day1.png), which is a full
## capsule -- corner radius roughly half the button's own height. Only
## radius_pill gets that: Godot clamps 999 to half the box's smaller
## dimension at draw time, so the wash always matches the capsule under
## it regardless of the button's authored size. A fixed radius_button
## (20px) undershoots that curve and pokes square-ish corners past the
## art's rounded ends on hover/press. Do not "fix" this back to
## radius_button -- see RADIUS_EXEMPT in tests/test_button_geometry.gd.
static func _add_ghost_button(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "GhostButton"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Button")

	theme.set_stylebox("normal", NAME, StyleBoxEmpty.new())
	theme.set_stylebox("focus", NAME, StyleBoxEmpty.new())
	theme.set_stylebox("disabled", NAME, StyleBoxEmpty.new())

	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(1, 1, 1, 0.14)
	wash.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("hover", NAME, wash)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0, 0, 0, 0.12)
	pressed.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("pressed", NAME, pressed)

	theme.set_font_size("font_size", NAME, tokens.font_h2)
	theme.set_color("font_color", NAME, tokens.text_primary)
	theme.set_color("font_disabled_color", NAME, tokens.text_disabled)
	if tokens.font_display != null:
		theme.set_font("font", NAME, tokens.font_display)


# ---------------------------------------------------------------- buttons

static func _build_buttons(theme: Theme, tokens: DesignTokens) -> void:
	# The Lobby's STUDENT/JADWAL look (2026-09-14 lobby-style-buttons spec):
	# every framed action button wears it, whatever its role name says.
	for role in ["PrimaryButton", "SecondaryButton", "DangerButton", "SuccessButton"]:
		_add_lobby_button(theme, tokens, role)

	# StudentCard keeps the cream secondary look it had before that pass...
	_add_button_variation(theme, tokens, "StudentCardSecondaryButton",
		tokens.surface_card, tokens.surface_sunken,
		tokens.brand_primary, tokens.brand_primary)

	# ...and StudentList's BELUM/SUDAH badges keep their colour, which is the
	# information they carry.
	_add_button_variation(theme, tokens, "RosterStatusBelum",
		tokens.state_danger.lightened(0.18), tokens.state_danger.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand)
	_add_button_variation(theme, tokens, "RosterStatusSudah",
		tokens.state_success.lightened(0.18), tokens.state_success.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand)

	_add_shop_hub_tile(theme, tokens)
	_add_shop_hub_tile_label(theme, tokens)
	_add_ghost_button(theme, tokens)

	# The event dialog's per-student card. The whole card is the toggle,
	# so its "pressed" state has to read as SELECTED rather than as a
	# button being held: normal is the plain card surface, pressed picks
	# up the brand outline. Sits with the other button variations because
	# it is literally a Button, however card-shaped it looks.
	# The radius argument is what makes "chips stay round" implementable.
	# QuirkBadge and PersonaBadge are chips but are built through
	# _add_button_variation, so without it they would be forced to
	# radius_button along with everything else.
	_add_button_variation(theme, tokens, "EventSelectCard",
		tokens.surface_card, tokens.surface_card,
		tokens.brand_primary, tokens.text_primary,
		tokens.radius_lg)

	# Trait chips (Quirk / Persona). Same pill geometry as any other
	# button variation; only the accent differs, so the two trait kinds
	# stay visually distinguishable without per-node styleboxes.
	_add_button_variation(theme, tokens, "QuirkBadge",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand,
		tokens.radius_pill)

	_add_button_variation(theme, tokens, "PersonaBadge",
		tokens.cat_istirahat.lightened(0.18), tokens.cat_istirahat.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand,
		tokens.radius_pill)

	# The roster card's third chip. Quirk and Persona carry their own
	# accents; specialty stays neutral because its category colour
	# varies per student and rides on the chip's icon instead.
	_add_button_variation(theme, tokens, "SpecialtyBadge",
		tokens.surface_sunken, tokens.surface_sunken.darkened(0.18),
		tokens.brand_primary, tokens.text_primary,
		tokens.radius_pill)

	# Compact S step for all three chips. The full-size badges are
	# font_title over btn_pad_v_s and space_lg -- about 160x290 each, so
	# three of them overflow StudentList's 880px trait row and clip every
	# label ("Semangat Juang" -> "SEMANGAT J"). The S step drops to
	# font_caption with space_xs/space_md padding, which fits the worst
	# case (Citra's "Seni Dalam Kesunyian") with room to spare. The
	# accents, rim and radius_pill are inherited, so an S chip is
	# unmistakably the same chip.
	for chip in ["SpecialtyBadge", "PersonaBadge", "QuirkBadge"]:
		_add_size_step(theme, tokens, chip, "S",
			tokens.font_caption, tokens.space_xs, tokens.space_md)
		# The category SVGs rasterise at their 100px viewBox, taller than
		# the whole compact chip. Capping here rather than with
		# expand_icon keeps the glyph a fixed size beside the word instead
		# of stretching with whatever the label happens to be.
		theme.set_constant("icon_max_width", chip + "S",
			tokens.space_md + tokens.space_xs)

		# ...and an M step, the one the StudentList card actually wears.
		# S turned out to be a phone-hostile 22px -- under Material's 12sp
		# caption floor once the 1080-wide design space is scaled down to
		# a real handset. M lifts the word to body size and keeps the
		# horizontal padding tight so three chips still share one row.
		_add_size_step(theme, tokens, chip, "M",
			tokens.font_body_size, tokens.space_sm, tokens.space_sm)
		theme.set_constant("icon_max_width", chip + "M", tokens.space_lg)

	# The lobby's three destination tiles. Icon stacked over label: at
	# the L step there is room for a 64px icon, an 8px gap and a
	# font_title line inside the 120px content box, and the icon is what
	# makes a destination scannable. Retired LobbyNavButton, which was
	# one variation stretched across five boxes of five different sizes.
	_add_lobby_button(theme, tokens, "LobbyNavTile")
	theme.set_constant("icon_max_width", "LobbyNavTile", tokens.btn_icon_m)
	theme.set_constant("h_separation", "LobbyNavTile", 8)

	# The week's primary call to action. Horizontal rather than stacked:
	# it is 984px wide, and a stacked icon in a banner that shape leaves
	# exactly the horizontal emptiness this pass exists to remove.
	_add_lobby_button(theme, tokens, "LobbyCtaButton")
	theme.set_font_size("font_size", "LobbyCtaButton", tokens.font_h1)
	theme.set_constant("icon_max_width", "LobbyCtaButton", tokens.btn_icon_l)
	theme.set_constant("h_separation", "LobbyCtaButton", 24)

	# Inventory's category filter row: a quiet pill at rest; the toggled-on
	# chip renders with the pressed stylebox _add_button_variation already
	# builds, so no extra "selected" styling is needed.
	_add_button_variation(theme, tokens, "FilterChipButton",
		tokens.surface_card, tokens.surface_sunken,
		tokens.brand_primary, tokens.brand_primary)
	# Its category icons are white placeholder glyphs, and a Button draws its
	# icon untinted unless its variation names an icon colour: white on this
	# cream pill measured 1.02:1 at rest and 1.30:1 selected, so on a phone
	# only the selected chip showed an icon (2026-09-15). Ink them like the
	# label -- which is why a replacement icon has to stay a white glyph.
	for slot in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(slot, "FilterChipButton", tokens.brand_primary)
	theme.set_color("icon_disabled_color", "FilterChipButton", tokens.text_disabled)

	# The student card's page arrows. Fixed 120x120, so radius_pill yields a
	# circle rather than a height-dependent capsule -- the one place that
	# radius is still correct on a Button, and why the geometry test
	# allow-lists it. Replaces two rotated copies of a pure-#FF0000 asset
	# that had no palette relationship to anything.
	_add_button_variation(theme, tokens, "CardArrowButton",
		tokens.brand_primary, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand,
		tokens.radius_pill)
	theme.set_constant("icon_max_width", "CardArrowButton", tokens.btn_icon_m)

	_build_main_menu_button(theme, tokens)
	_build_shop_shelf_button(theme, tokens)
	_build_result_button(theme, tokens)

	# Size steps. M covers the 116-148 px call sites (TesNotice, RunResult,
	# QuitConfirmDialog, EndCutscene, AturJadwal's StartWeek); L covers the
	# 160-178 px ones (StudentCard's Aprove and Batal, StudentList's
	# arrows). SuccessButton has no M call site, so none is generated.
	for base in ["PrimaryButton", "SecondaryButton", "DangerButton"]:
		_add_size_step(theme, tokens, base, "M", tokens.font_h2, tokens.btn_pad_v_m)
	for base in ["PrimaryButton", "SecondaryButton", "DangerButton", "SuccessButton"]:
		_add_size_step(theme, tokens, base, "L", tokens.font_h1, tokens.btn_pad_v_l)
	_add_size_step(theme, tokens, "StudentCardSecondaryButton", "L", tokens.font_h1, tokens.btn_pad_v_l)


## Koperasi's shelf-category button (e.g. "KEBUTUHAN SEKOLAH"), in the Lobby
## look since the 2026-09-14 lobby-style-buttons pass (it was a flat brown
## tab with a gold hover). Keeps its 20/10 padding and its body-font label:
## Rak1 is authored 442 px wide with a 40 px text override, and the display
## face would need 495 px for "KEBUTUHAN SEKOLAH", stretching the button off
## its spot (test_lobby_style_buttons pins the fit).
static func _build_shop_shelf_button(theme: Theme, tokens: DesignTokens) -> void:
	_add_lobby_button(theme, tokens, "ShopShelfButton")
	_set_content_margins(theme, "ShopShelfButton", 20, 10)
	# Only set when tokens carry a display face; clearing a font that was never
	# set logs an engine error (the null-font theme tests build exactly that).
	if theme.get_font_list("ShopShelfButton").has("font"):
		theme.clear_font("font", "ShopShelfButton")


## Weekly Results' Logs and Selanjutnya, in the Lobby look (2026-09-14
## lobby-style-buttons spec; the cream card_bg.png art is retired). Keeps
## its 24 px sides and the card's 52 px text, so SELANJUTNYA still fits the
## 436 px half-row it was laid out for.
static func _build_result_button(theme: Theme, tokens: DesignTokens) -> void:
	_add_lobby_button(theme, tokens, "ResultButton")
	_set_content_margins(theme, "ResultButton", 24, tokens.btn_pad_v_s)
	theme.set_font_size("font_size", "ResultButton", tokens.day_stat_size)


## The main menu's icon buttons, in the Lobby look (2026-09-14
## lobby-style-buttons spec; the painted gold menu_button.png is retired).
## Icon-only boxes, so the sides stay tight and the vertical padding zero --
## the Lobby recipe's space_lg sides would squeeze the icon.
static func _build_main_menu_button(theme: Theme, tokens: DesignTokens) -> void:
	_add_lobby_button(theme, tokens, "MainMenuButton")
	_set_content_margins(theme, "MainMenuButton", 20, 0)
	theme.set_font_size("font_size", "MainMenuButton", 80)


## The Lobby's STUDENT / JADWAL button: brand_primary_light over the darker
## bevel, the cream card rim and cream display text. Every framed action
## button wears it since the 2026-09-14 lobby-style-buttons pass; what
## differs between them is size, text and icon, never the surface.
static func _add_lobby_button(theme: Theme, tokens: DesignTokens, name: String) -> void:
	_add_button_variation(theme, tokens, name,
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand)


## Re-pad every state of a flat button variation: `pad_h` on both sides,
## `pad_v` top and bottom.
static func _set_content_margins(theme: Theme, name: String, pad_h: int, pad_v: int) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := theme.get_stylebox(state, name) as StyleBoxFlat
		sb.content_margin_left = pad_h
		sb.content_margin_right = pad_h
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v


static func _add_button_variation(
	theme: Theme,
	tokens: DesignTokens,
	name: String,
	top: Color,
	bottom: Color,
	border: Color,
	text_color: Color,
	radius: int = -1
) -> void:
	# -1 means "the default", resolved here so callers that do not care
	# about shape do not have to name the token.
	var r: int = tokens.radius_button if radius < 0 else radius

	theme.add_type(name)
	theme.set_type_variation(name, "Button")

	theme.set_stylebox("normal", name,
		_button_box(tokens, top, bottom, border, 0.0, r))
	theme.set_stylebox("hover", name,
		_button_box(tokens, top.lightened(0.08), bottom.lightened(0.08), border, 0.0, r))
	# Pressed sinks: gradient flips and the shadow collapses.
	theme.set_stylebox("pressed", name,
		_button_box(tokens, bottom, top, border, -tokens.shadow_offset.y * 0.5, r))
	theme.set_stylebox("focus", name,
		_button_box(tokens, top, bottom, tokens.brand_primary, 0.0, r))

	var disabled := _button_box(tokens,
		top.lerp(tokens.surface_sunken, 0.7),
		bottom.lerp(tokens.surface_sunken, 0.7),
		border.lerp(tokens.surface_sunken, 0.5), 0.0, r)
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


## Clone an existing role variation at a larger size step.
##
## Only font_size differs -- the fill, rim and radius are the role's, so
## a PrimaryButtonL is unmistakably a PrimaryButton. Height comes from
## the step's own vertical padding, which is why this also re-pads.
## `pad_h` defaults to -1, meaning "keep the role's own horizontal
## padding". The S chip step passes a real value: a compact chip has to
## give back width as well as height, and space_lg (44px per side) is
## most of what makes a three-chip row overflow an 880px card.
static func _add_size_step(
	theme: Theme,
	tokens: DesignTokens,
	base: String,
	suffix: String,
	font_size: int,
	pad_v: int,
	pad_h: int = -1
) -> void:
	var name := base + suffix
	theme.add_type(name)
	theme.set_type_variation(name, "Button")

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := (theme.get_stylebox(state, base) as StyleBoxFlat).duplicate()
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v
		if pad_h >= 0:
			sb.content_margin_left = pad_h
			sb.content_margin_right = pad_h
		theme.set_stylebox(state, name, sb)

	for key in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		theme.set_color(key, name, theme.get_color(key, base))

	theme.set_font_size("font_size", name, font_size)
	if tokens.font_display != null:
		theme.set_font("font", name, tokens.font_display)


## One button surface in four states.
##
## `radius` is explicit rather than always tokens.radius_button because
## chips (QuirkBadge, PersonaBadge) and cards (EventSelectCard) are built
## through this same path and must opt out. See the table in
## _build_buttons.
##
## `top`/`bottom` are kept as separate parameters even though
## StyleBoxFlat has no gradient: the two-tone read comes from a lighter
## fill plus the darker bottom border acting as a bevel, and the pressed
## state flips them.
static func _button_box(
	tokens: DesignTokens,
	top: Color,
	bottom: Color,
	border: Color,
	shadow_dy: float,
	radius: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top
	sb.border_color = border
	sb.border_width_left = int(tokens.outline_width)
	sb.border_width_top = int(tokens.outline_width)
	sb.border_width_right = int(tokens.outline_width)
	sb.border_width_bottom = int(tokens.outline_width)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = tokens.shadow_color
	sb.shadow_size = tokens.shadow_size
	sb.shadow_offset = Vector2(tokens.shadow_offset.x,
		tokens.shadow_offset.y + shadow_dy)
	sb.content_margin_left = tokens.space_lg
	sb.content_margin_right = tokens.space_lg
	sb.content_margin_top = tokens.btn_pad_v_s
	sb.content_margin_bottom = tokens.btn_pad_v_s
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

	# The win painting's photo print (WinStage/PhotoFrame): an opaque warm
	# white border with the Card's drop shadow, so the end-of-grade picture
	# reads as a photograph lying on the dark ground.
	theme.add_type("PhotoFrame")
	theme.set_type_variation("PhotoFrame", "Panel")
	var photo := StyleBoxFlat.new()
	photo.bg_color = tokens.surface_card
	photo.set_corner_radius_all(tokens.radius_sm)
	photo.shadow_color = tokens.shadow_color
	photo.shadow_size = tokens.shadow_size
	photo.shadow_offset = tokens.shadow_offset
	theme.set_stylebox("panel", "PhotoFrame", photo)

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

	_add_koperasi_variations(theme, tokens)


## Koperasi rework (2026-09-11): the coin-pill price tag in its three
## states, and the warm tray surface that replaces the popup box.
static func _add_koperasi_variations(theme: Theme, tokens: DesignTokens) -> void:
	var rest := StyleBoxFlat.new()
	rest.bg_color = tokens.koperasi_tag_fill
	rest.border_color = tokens.koperasi_tag_border
	rest.set_border_width_all(4)
	rest.set_corner_radius_all(tokens.radius_pill)
	rest.content_margin_left = 12
	rest.content_margin_right = 28
	rest.content_margin_top = 8
	rest.content_margin_bottom = 8
	theme.add_type("PriceTag")
	theme.set_type_variation("PriceTag", "Panel")
	theme.set_stylebox("panel", "PriceTag", rest)

	var pressed := rest.duplicate() as StyleBoxFlat
	pressed.bg_color = tokens.koperasi_tag_pressed_fill
	pressed.border_color = tokens.koperasi_tag_pressed_border
	theme.add_type("PriceTagPressed")
	theme.set_type_variation("PriceTagPressed", "Panel")
	theme.set_stylebox("panel", "PriceTagPressed", pressed)

	var disabled := rest.duplicate() as StyleBoxFlat
	disabled.bg_color = tokens.koperasi_tag_disabled_fill
	disabled.border_color = tokens.koperasi_tag_disabled_border
	theme.add_type("PriceTagDisabled")
	theme.set_type_variation("PriceTagDisabled", "Panel")
	theme.set_stylebox("panel", "PriceTagDisabled", disabled)

	var tray := StyleBoxFlat.new()
	tray.bg_color = tokens.koperasi_tray_fill
	tray.border_color = tokens.koperasi_tray_rule
	tray.border_width_top = 6
	tray.corner_radius_top_left = tokens.radius_lg
	tray.corner_radius_top_right = tokens.radius_lg
	tray.content_margin_left = 28
	tray.content_margin_right = 28
	tray.content_margin_top = 20
	tray.content_margin_bottom = 24
	theme.add_type("BasketTray")
	theme.set_type_variation("BasketTray", "Panel")
	theme.set_stylebox("panel", "BasketTray", tray)

	# -- The ×N on a tray slot and the count on the basket emblem: a cream
	# pill with an amber rim, the tray's own colours. PanelContainer base,
	# because both badges are PanelContainers. --
	var badge := StyleBoxFlat.new()
	badge.bg_color = tokens.surface_card
	badge.border_color = tokens.koperasi_tray_rule
	badge.set_border_width_all(3)
	badge.set_corner_radius_all(tokens.radius_pill)
	badge.content_margin_left = 12
	badge.content_margin_right = 12
	badge.content_margin_top = 2
	badge.content_margin_bottom = 2
	theme.add_type("TrayBadge")
	theme.set_type_variation("TrayBadge", "PanelContainer")
	theme.set_stylebox("panel", "TrayBadge", badge)

	# Display face: CLAUDE.md gives badges Boohong. Body step, dark ink.
	theme.add_type("TrayBadgeLabel")
	theme.set_type_variation("TrayBadgeLabel", "Label")
	theme.set_font_size("font_size", "TrayBadgeLabel", tokens.font_body_size)
	theme.set_color("font_color", "TrayBadgeLabel", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "TrayBadgeLabel", tokens.font_display)

	# -- The plank the tray's items stand on: one amber rule. --
	var plank := StyleBoxFlat.new()
	plank.bg_color = tokens.koperasi_tray_rule
	plank.set_corner_radius_all(tokens.radius_sm)
	theme.add_type("TrayPlank")
	theme.set_type_variation("TrayPlank", "Panel")
	theme.set_stylebox("panel", "TrayPlank", plank)


## The cutscene's dialogue text: one step up the scale from body, on the
## body face, over the Card panel Task 3 puts behind it.
##
## RichTextLabel's theme items are NOT the Label ones. Its size key is
## "normal_font_size" and its colour key is "default_color"; setting
## "font_size"/"font_color" here compiles and does nothing, which is the
## same trap _build_base_overrides already documents for the base type.
static func _add_cutscene_dialogue(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "CutsceneDialogue"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "RichTextLabel")
	theme.set_font_size("normal_font_size", NAME, tokens.font_title)
	theme.set_color("default_color", NAME, tokens.text_primary)


# ----------------------------------------------------------------- labels

static func _build_labels(theme: Theme, tokens: DesignTokens) -> void:
	# name, size, color, outlined, heading
	#
	# `outlined` and `heading` are deliberately independent. Before
	# 2026-09-05 the display font was applied inside the `outlined`
	# branch, which silently gave every un-outlined heading the body
	# font. Outline is about the backdrop a label sits on; heading is
	# about typographic role. They coincide for DisplayLabel/H1Label and
	# diverge for H2Label/TitleLabel.
	var specs := [
		["DisplayLabel", tokens.font_display_size, tokens.text_primary, true, true],
		["H1Label", tokens.font_h1, tokens.text_primary, true, true],
		["H2Label", tokens.font_h2, tokens.text_primary, false, true],
		["TitleLabel", tokens.font_title, tokens.text_primary, false, true],
		["CaptionLabel", tokens.font_caption, tokens.text_secondary, false, false],
		["MicroLabel", tokens.font_micro, tokens.text_secondary, false, false],
		# PageDotLabel styled the SemesterEnd carousel's page dots and has
		# had no consumer since Plan A deleted that screen. Kept baked
		# rather than removed: dropping a variation needs a theme rebake,
		# which has no headless path. Nothing above this line is unused.
		["PageDotLabel", tokens.font_caption, tokens.text_disabled, false, false],
		# The "no items match this filter" placeholder text. 32px doesn't
		# match a token exactly (nearest are font_body_size 28 / font_title
		# 36); kept as the shipped literal rather than nudging the size.
		["EmptyStateLabel", 32, tokens.text_disabled, false, false],
		# 2026-09-08 mobile-readability pass: the mid-simulation event
		# popups (the event warning and EventStudentSelectDialog)
		# needed a title bigger than H1Label without becoming a second
		# DisplayLabel -- H1+6 in the display face, no outline (these titles
		# sit on their own opaque card/scrim, not over busy art).
		["EventDialogHeaderLabel", tokens.font_h1 + 6, tokens.text_primary, false, true],
		# Same pass: the event dialog's benefit/cost lines and description
		# sat in 22px CaptionLabel, unreadably small on a 1080px phone.
		# Body face (not display), over font_body_size(28). Raised again on
		# 2026-09-09 from +4 to +8 after the trait popup was reviewed on a
		# phone: 32px was legible but cramped in a modal that fills most of
		# the screen. Also used by StatDetailPopup and
		# EventStudentSelectDialog, which want the same bump.
		["EventBodyLabel", tokens.font_body_size + 8, tokens.text_primary, false, false],
		# The StudentList card's teacher's-note strip. Same story as
		# EventBodyLabel one line up: it shipped in 22px CaptionLabel and
		# was reported unreadable on a phone without squinting. Body face
		# over font_body_size + 8, and text_primary rather than
		# CaptionLabel's text_secondary -- it sits on cream paper, where
		# the secondary brown is the half of the problem the size alone
		# does not fix.
		["CatatanLabel", tokens.font_body_size + 8, tokens.text_primary, false, false],
		# RunResult's report rows: the name beside each figure, on the
		# near-white Card. It shipped in ResultBodyLabel, whose cream
		# text_on_brand measures 1.05:1 on surface_card -- all six names
		# barely showed (2026-09-11). Not a recolour of that variation: the
		# minigame score HUD still sets it on a dark translucent pill, where
		# cream is what reads. Body face at the same phone step as the two
		# above; at 36px the widest name, "Uang dari wirausaha", takes 352 of
		# the 579px beside "24000G" (measured live, lulus rehearsal).
		["RunResultNameLabel", tokens.font_body_size + 8, tokens.text_primary, false, false],
		# The minigame result card's small labels on light ground: the
		# minigame's name on the card itself (popup_bg.svg, #F5F2EB) and
		# "Skor:" on its sunken stat panel. Both shipped in ResultBodyLabel
		# and measured 1.04:1 and 1.21:1 (2026-09-11). Dark ink at the
		# caption size they shipped with: each is a few words beside
		# something larger -- the stars, the display-size score -- so the
		# fix is the ink, not the size.
		["ResultCardBodyLabel", tokens.font_caption, tokens.text_primary, false, false],
		# The score HUD's combo count ("x3") on its light ResultBadgePanel
		# chip: 1.05:1 in ResultBodyLabel. TargetLabel beside it keeps that
		# cream -- it sits on the dark translucent ScoreHudPanel itself,
		# where dark ink would fall to 1.3:1 over dark art.
		["ScoreHudComboLabel", tokens.font_caption, tokens.text_primary, false, false],
		# The trait popup's header sits on a per-trait tinted panel
		# (TraitPopupHeader, self_modulated brand_primary for a quirk and
		# cat_istirahat for a persona), so its two labels need CREAM text.
		# Every other label variation above is text_primary, which is why
		# these exist rather than reusing TitleLabel/H2Label: dark ink on
		# either of those tints is close to unreadable. Display face --
		# they are the modal's title, and the review note was that they
		# read as body copy. No outline: the panel behind them is opaque
		# and flat, so an outline would only thicken the letterforms.
		["TraitPopupKindLabel", tokens.font_title, tokens.text_on_brand, false, true],
		["TraitPopupNameLabel", tokens.font_h2, tokens.text_on_brand, false, true],
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
		if spec[4] and tokens.font_display != null:
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

	# SemesterEnd, which these two were made for, is gone (Plan A); both
	# outlived it. They still assume a DARK ground -- ResultBodyLabel is
	# cream and vanishes on a light surface, which is why RunResult's rows,
	# the minigame result card and the HUD's combo chip each moved to a dark
	# variation above. What still wears it sits on dark: the HUD's
	# TargetLabel on the translucent ScoreHudPanel, and TesNotice's body,
	# which today floats on that screen's scrim.
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
	if tokens.font_display != null:
		theme.set_font("font", "ResultHeroLabel", tokens.font_display)

	theme.add_type("ResultBodyLabel")
	theme.set_type_variation("ResultBodyLabel", "Label")
	theme.set_font_size("font_size", "ResultBodyLabel", tokens.font_caption)
	theme.set_color("font_color", "ResultBodyLabel", tokens.text_on_brand)

	_add_cutscene_dialogue(theme, tokens)


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

## Where the per-stat fill tiles live. One PNG per stat, drop-in
## replaceable: same 256x256 canvas, same region, same near-white body.
## Hand-drawn art at these paths needs no code change.
const _BAR_FILL_ART := "res://Assets/Images/UI/BarFill/fill_%s.png"

## Stat key -> its fill tile's file suffix. The keys are the `category`
## strings StatBar carries, including the spellings the schedule data uses.
const _BAR_FILL_BY_CATEGORY := {
	"Akademis": "akademis", "SeniBudaya": "senibudaya", "Olahraga": "olahraga",
	"Wirausaha": "wirausaha", "Istirahat": "istirahat", "Libur": "libur",
	"Mood": "mood", "Energy": "energi",
}


## A bar's fill: the stat's own motif tile, tinted by its accent.
##
## Every bar used to share ONE near-white capsule that each category tinted.
## Since 2026-09-09 each stat has its own tile carrying its own motif, so a
## bar is identifiable by texture as well as by hue. Six are objects -- a
## book, a coin, a crescent, a sun, a heart, a bolt -- and two are woven
## geometry, because at bar scale the two stats that most need telling
## apart do better as texture than as a picture: seni budaya wears tenun
## chevrons and olahraga the batik lereng diagonal. `category` empty falls
## back to the plain untextured capsule.
##
## The centre slice TILES rather than stretching. That is load-bearing: a
## stretched centre would smear the motif horizontally as the bar fills.
## The tiles' motif period (20x19) divides the centre slice (100x76) exactly
## 5 x 4, which is what makes the repeat seamless -- changing
## _PROGRESS_FILL_MARGIN or the region without regenerating the art at a
## matching period will make the motif jump at every repeat.
static func _progress_fill_stylebox(modulate: Color = Color.WHITE,
		category: String = "") -> StyleBoxTexture:
	var fill := StyleBoxTexture.new()
	var suffix: String = _BAR_FILL_BY_CATEGORY.get(category, "")
	fill.texture = load(_BAR_FILL_ART % suffix) if suffix != "" \
		else load(_PROGRESS_FILL_ART)
	fill.region_rect = _PROGRESS_FILL_REGION
	fill.set_texture_margin_all(_PROGRESS_FILL_MARGIN)
	fill.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	fill.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	fill.modulate_color = modulate
	return fill

static func _build_progress(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("StatBar")
	theme.set_type_variation("StatBar", "ProgressBar")

	# The track is a sticker capsule like the rest of the chrome: dark
	# ground, white rim, soft drop shadow. content_margin insets the fill
	# so a rail of track stays visible even at 100% -- without it the
	# coloured fill runs flush to the rim and the bar reads as a debug
	# widget. The inset is half outline_width so the rail and the rim
	# stay a 1:1 pair at any token value. The track is deliberately dark
	# (stat_bar_track, not surface_sunken) so the fill can be a bright
	# cat_*_on_dark accent instead of a light track forcing those accents
	# to be darkened until they were muddy -- see stat_bar_track's doc
	# comment on DesignTokens.gd.
	var bg := StyleBoxFlat.new()
	bg.bg_color = tokens.stat_bar_track
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
	# Mood and Energy joined this list on 2026-09-09. They are needs rather
	# than schedule categories and used to borrow Istirahat's and Libur's
	# variations outright, which the batik motifs made untenable -- mood
	# would have worn the rest motif and energy the holiday one.
	var stat_bar_categories := [
		["StatBarAkademis", tokens.cat_akademis_on_dark, "Akademis"],
		["StatBarSeniBudaya", tokens.cat_senibudaya_on_dark, "SeniBudaya"],
		["StatBarOlahraga", tokens.cat_olahraga_on_dark, "Olahraga"],
		["StatBarIstirahat", tokens.cat_istirahat_on_dark, "Istirahat"],
		["StatBarLibur", tokens.cat_libur_on_dark, "Libur"],
		["StatBarWirausaha", tokens.cat_wirausaha_on_dark, "Wirausaha"],
		["StatBarMood", tokens.cat_mood_on_dark, "Mood"],
		["StatBarEnergy", tokens.cat_energy_on_dark, "Energy"],
	]
	for spec in stat_bar_categories:
		var name: String = spec[0]
		var color: Color = spec[1]
		theme.add_type(name)
		theme.set_type_variation(name, "ProgressBar")
		theme.set_stylebox("background", name, bg)
		theme.set_stylebox("fill", name, _progress_fill_stylebox(color, spec[2]))
		theme.set_font_size("font_size", name, tokens.font_caption)
		theme.set_color("font_color", name, tokens.text_primary)

	# -- Light-track siblings, for bars on a cream surface. --
	#
	# The dark ground above exists so bright cat_*_on_dark accents can read
	# against it. AturJadwal's cream card inverts that premise: a dark well
	# on a cream sheet is the loudest thing in the popup, which is what the
	# 2026-09-10 mentor reference objected to. These use the base cat_*
	# colours -- deep and saturated -- on a light track instead.
	#
	# Only the three schedule skills need them: Wirausaha and Libur carry
	# no bar at all, they take the ghost track. Selected by setting
	# StatBar.variation to "StatBarLight", mirroring how StatPill picks its
	# own siblings.
	var light_bg := StyleBoxFlat.new()
	light_bg.bg_color = tokens.preview_pill_fill
	light_bg.set_corner_radius_all(tokens.radius_pill)
	light_bg.set_content_margin_all(tokens.outline_width / 2.0)

	for lspec in [
		["StatBarAkademisLight", tokens.cat_akademis, "Akademis"],
		["StatBarSeniBudayaLight", tokens.cat_senibudaya, "SeniBudaya"],
		["StatBarOlahragaLight", tokens.cat_olahraga, "Olahraga"],
	]:
		var lname: String = lspec[0]
		var lcolor: Color = lspec[1]
		theme.add_type(lname)
		theme.set_type_variation(lname, "ProgressBar")
		theme.set_stylebox("background", lname, light_bg)
		theme.set_stylebox("fill", lname, _progress_fill_stylebox(lcolor, lspec[2]))
		theme.set_font_size("font_size", lname, tokens.font_caption)
		theme.set_color("font_color", lname, tokens.text_primary)


## AchievementTile's progress bar (Task 8, 2026-09-18 polish pass): StatBar's
## min height wins over any scene-level custom_minimum_size override on a
## ProgressBar using "StatBar", rendering it ~36px tall on a tile that wants
## a thin 4-6px sliver. A dedicated thin variation, built the same way as
## StatBar above but flat (no textured fill/rim/shadow chrome -- a tile-sized
## sliver is too small for that detail to read), sidesteps the min-height
## fight entirely instead of trying to override it per-instance.
static func _build_achievement_tile_bar(theme: Theme, tokens: DesignTokens) -> void:
	const BAR_HEIGHT := 5.0

	theme.add_type("AchievementTileBar")
	theme.set_type_variation("AchievementTileBar", "ProgressBar")

	var bg := StyleBoxFlat.new()
	bg.bg_color = tokens.stat_bar_track
	bg.set_corner_radius_all(int(BAR_HEIGHT / 2.0))
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	theme.set_stylebox("background", "AchievementTileBar", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = tokens.cat_akademis_on_dark
	fill.set_corner_radius_all(int(BAR_HEIGHT / 2.0))
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	theme.set_stylebox("fill", "AchievementTileBar", fill)

	theme.set_font_size("font_size", "AchievementTileBar", tokens.font_caption)
	theme.set_color("font_color", "AchievementTileBar", tokens.text_primary)


# ------------------------------------------------- student card redesign

const _CARD_ART := "res://Assets/Images/StudentCard/"



## Variations used only by the student card's redesigned layout. The card
## background art paints the bio panel and the portrait frame, so these
## styles deliberately draw less than their siblings.
static func _build_student_card(theme: Theme, tokens: DesignTokens) -> void:
	# -- Stat pill track. --
	#
	# This used to be a StyleBoxEmpty, because card_bg.png painted a dark
	# chip behind every pill and the stylebox only had to supply the fill.
	# Those painted chips were removed on 2026-09-09: the bars had been
	# real ProgressBar nodes for a while, the chips' right column stuck out
	# past the bar's edge, and the art could not follow the bars when they
	# moved. Deleting them made an empty bar invisible -- the fill drew
	# nothing and there was no track behind it, so a stat at 0 looked like
	# blank paper.
	#
	# The track now comes from the theme, where it belongs, and reuses
	# StatBar's own recipe (same stat_bar_track ground, same rim, same
	# half-outline content inset keeping a rail of track visible at 100%)
	# so the two bar families read as one component. It carries no drop
	# shadow: unlike StatBar these sit directly on the card's paper, where
	# a cast shadow would read as the pill floating off the page.
	theme.add_type("StatPill")
	theme.set_type_variation("StatPill", "ProgressBar")

	var pill_bg := StyleBoxFlat.new()
	pill_bg.bg_color = tokens.stat_bar_track
	pill_bg.set_corner_radius_all(tokens.radius_pill)
	pill_bg.set_border_width_all(int(tokens.outline_width / 2.0))
	pill_bg.border_color = tokens.outline_card
	pill_bg.set_content_margin_all(tokens.outline_width / 2.0)
	theme.set_stylebox("background", "StatPill", pill_bg)

	# The pills share the StatBar family's fill helper, and therefore its
	# tiles and its geometry. They used to carry their own pill_fill.png at
	# a slightly different region and a 28px margin; that divergence had no
	# purpose and could not survive the motif tiles, whose period is cut to
	# divide the shared 24px-margin centre slice exactly.
	theme.set_stylebox("fill", "StatPill", _progress_fill_stylebox())

	# -- Per-category pill siblings. --
	#
	# StatPill used to be tinted by StatBar.gd setting self_modulate on the
	# node. That worked only while its background was a StyleBoxEmpty:
	# self_modulate multiplies EVERYTHING the node draws, so the moment the
	# pill grew a real track (above), the accent started multiplying the
	# track's brown ground and cream rim too, giving each pill a differently
	# tinted "empty" half.
	#
	# This is the same trap the StatBar family walked into and out of, and
	# the same fix: one variation per category with the colour baked into
	# the FILL stylebox, and a white self_modulate on the node. They share
	# the single `pill_bg` instance, so the track stays identical across all
	# six -- a new theme item added to plain "StatPill" will NOT reach these
	# automatically and would need adding here too.
	for spec in [
		["StatPillAkademis", tokens.cat_akademis_on_dark, "Akademis"],
		["StatPillSeniBudaya", tokens.cat_senibudaya_on_dark, "SeniBudaya"],
		["StatPillOlahraga", tokens.cat_olahraga_on_dark, "Olahraga"],
		["StatPillIstirahat", tokens.cat_istirahat_on_dark, "Istirahat"],
		["StatPillLibur", tokens.cat_libur_on_dark, "Libur"],
		["StatPillWirausaha", tokens.cat_wirausaha_on_dark, "Wirausaha"],
		["StatPillMood", tokens.cat_mood_on_dark, "Mood"],
		["StatPillEnergy", tokens.cat_energy_on_dark, "Energy"],
	]:
		var pill_name: String = spec[0]
		theme.add_type(pill_name)
		theme.set_type_variation(pill_name, "ProgressBar")
		theme.set_stylebox("background", pill_name, pill_bg)
		theme.set_stylebox("fill", pill_name, _progress_fill_stylebox(spec[1], spec[2]))

	# -- Trait button ("Sifat Pasif" pills): the art ships gold with its own
	# purple border, so the stylebox draws it untinted. A modulate here
	# multiplies against the texture rather than replacing its colour --
	# it would mud the fill to olive and turn the border brown. --
	# The vertical texture margin is smaller than the horizontal: the pills
	# are a fixed 70px tall, and 45+45 (fine on the ~840px-wide horizontal
	# axis) does not fit vertically -- 30+30 does, leaving a 31px centre
	# slice out of the 91px source region. Content margins are set
	# explicitly rather than left at their StyleBoxTexture default (-1),
	# because a StyleBoxTexture with default content margins inherits them
	# from its TEXTURE margins -- at 45/45 that starved the 70px-tall label
	# of any room at all.
	theme.add_type("TraitPill")
	theme.set_type_variation("TraitPill", "Button")

	var trait_normal := StyleBoxTexture.new()
	trait_normal.texture = load(_CARD_ART + "trait_button.png")
	trait_normal.region_rect = Rect2(20, 277, 601, 91)
	trait_normal.texture_margin_left = 45
	trait_normal.texture_margin_right = 45
	trait_normal.texture_margin_top = 30
	trait_normal.texture_margin_bottom = 30
	trait_normal.content_margin_left = 32
	trait_normal.content_margin_right = 32
	trait_normal.content_margin_top = 4
	trait_normal.content_margin_bottom = 4
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

	# -- "Sifat Pasif:" section heading: the card paper (card_bg.png) is warm
	# cream, so this heading reads dark-on-light like the rest of the
	# project's text, same as the shared TitleLabel. It keeps a light outline
	# (thinner than TitleLabel needs) only to stay crisp where it crosses the
	# painted fold in the card art's corner. --
	theme.add_type("CardSectionLabel")
	theme.set_type_variation("CardSectionLabel", "Label")
	theme.set_font_size("font_size", "CardSectionLabel", tokens.font_title)
	theme.set_color("font_color", "CardSectionLabel", tokens.text_primary)
	theme.set_constant("outline_size", "CardSectionLabel", 2)
	theme.set_color("font_outline_color", "CardSectionLabel", tokens.text_outline_color)
	if tokens.font_display != null:
		theme.set_font("font", "CardSectionLabel", tokens.font_display)

	# -- Bio text: light, because it sits on the painted purple panel. --
	# 2026-09-08 mobile-readability pass: BioLabel shrinks to caption-size
	# so it reads as a label rather than competing with BioValue, which
	# jumps to H2 so the student's own name/date is the thing that pops.
	theme.add_type("BioLabel")
	theme.set_type_variation("BioLabel", "Label")
	theme.set_font_size("font_size", "BioLabel", tokens.font_caption)
	theme.set_color("font_color", "BioLabel", tokens.text_on_brand)

	theme.add_type("BioValue")
	theme.set_type_variation("BioValue", "Label")
	theme.set_font_size("font_size", "BioValue", tokens.font_h2)
	theme.set_color("font_color", "BioValue", tokens.text_on_brand)

	# -- A name alone on the painted plate: StatCheck's page (2026-09-11).
	# StudentCard stacks three bio rows on that plate in BioLabel/BioValue;
	# StatCheck shows only the name, so it takes the display face at the
	# display step and fills the plate. Cream for the same reason as the bio
	# text. No outline: the plate is opaque and flat, so an outline would
	# only thicken the letterforms (the call TraitPopupNameLabel makes too).
	# At 96px the widest roster name, MARCEL, is ~413px against the 457px
	# Name slot in StatCheckCard.tscn -- tests/test_stat_check.gd measures it. --
	theme.add_type("PlateNameLabel")
	theme.set_type_variation("PlateNameLabel", "Label")
	theme.set_font_size("font_size", "PlateNameLabel", tokens.font_display_size)
	theme.set_color("font_color", "PlateNameLabel", tokens.text_on_brand)
	if tokens.font_display != null:
		theme.set_font("font", "PlateNameLabel", tokens.font_display)

	# -- Penjadwalan row: a plain cream slab on the sheet. Before the
	# 2026-09-10 pass this was a brown slab with a 3px stroke and a hard
	# drop shadow; with the card behind it and the pill inside it, that
	# stacked four surfaces per row and read as clutter. Depth now comes
	# from the inset track alone. --
	# Draws nothing at rest. A row that paints its own fill reads as a box
	# on the card whatever colour that fill is -- recolouring the boxes was
	# the first attempt and it still looked like five stacked cards. The
	# rows ARE the sheet now; only the hairlines divide them.
	# PreviewRowPressed below is what gives a row a surface, and only while
	# it is held. preview_row_fill survives as that variation's resting
	# reference rather than as anything drawn.
	theme.add_type("PreviewRow")
	theme.set_type_variation("PreviewRow", "Panel")
	theme.set_stylebox("panel", "PreviewRow", StyleBoxEmpty.new())

	# -- The same slab while held. Panel has no pressed state, so
	# ActivityRow.gd swaps this in on button_down. The inset top edge is
	# what sells the sink; a flat colour change alone reads as a hover. --
	var preview_row_pressed := StyleBoxFlat.new()
	preview_row_pressed.bg_color = tokens.preview_row_pressed_fill
	preview_row_pressed.set_border_width_all(0)
	preview_row_pressed.border_width_top = 2
	preview_row_pressed.border_color = tokens.preview_row_pressed_fill.darkened(0.12)
	preview_row_pressed.set_corner_radius_all(tokens.radius_md)
	theme.add_type("PreviewRowPressed")
	theme.set_type_variation("PreviewRowPressed", "Panel")
	theme.set_stylebox("panel", "PreviewRowPressed", preview_row_pressed)

	# -- The hairline between rows, replacing the per-row stroke. --
	var preview_separator := StyleBoxLine.new()
	preview_separator.color = tokens.preview_row_separator
	preview_separator.thickness = 1
	theme.add_type("PreviewRowSeparator")
	theme.set_type_variation("PreviewRowSeparator", "HSeparator")
	theme.set_stylebox("separator", "PreviewRowSeparator", preview_separator)

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

	# -- Wirausaha and Libur have no target, so no gauge. Against the old
	# dark slab an empty row read fine; on the cream sheet they collapsed
	# into near-empty strips beside the three rows that do carry bars.
	# They now get the gauge's silhouette used as a container: a texture
	# whose alpha ramps from 0.18 at the left to solid at the right, so
	# the row still reads as empty without reading as missing.
	#
	# STRETCH, not TILE. The BarFill fills above tile, but a horizontal
	# alpha ramp sawtooths back to transparent at every repeat if tiled.
	var ghost := StyleBoxTexture.new()
	ghost.texture = load("res://Assets/Images/UI/BarFill/track_ghost.png")
	ghost.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	ghost.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	ghost.set_texture_margin_all(22)
	ghost.content_margin_left = tokens.space_sm
	ghost.content_margin_right = tokens.space_sm
	ghost.content_margin_top = tokens.space_xs
	ghost.content_margin_bottom = tokens.space_xs
	theme.add_type("PreviewTrackGhost")
	theme.set_type_variation("PreviewTrackGhost", "PanelContainer")
	theme.set_stylebox("panel", "PreviewTrackGhost", ghost)

	# -- The numbers inside that pill: white on the dark slab. --
	theme.add_type("PreviewChipLabel")
	theme.set_type_variation("PreviewChipLabel", "Label")
	theme.set_font_size("font_size", "PreviewChipLabel", tokens.font_h2)
	# Dark on the light track since 2026-09-10. These were text_on_brand
	# cream, which was right on the old dark pill and invisible on the
	# ghost track that replaced it.
	theme.set_color("font_color", "PreviewChipLabel", tokens.text_primary)

	# -- The category name for each row. Until 2026-09-10 this was cream
	# text with a near-black 6px rim, overlapping the bottom of a dark
	# brown row -- correct then, and an outlined white smear once the row
	# went cream. It is now quiet dark text sitting above its bar, so the
	# rim has nothing to do and the size drops a step: the bar is the loud
	# element in the row, not its name. --
	theme.add_type("PreviewRowLabel")
	theme.set_type_variation("PreviewRowLabel", "Label")
	theme.set_font_size("font_size", "PreviewRowLabel", tokens.font_body_size)
	theme.set_color("font_color", "PreviewRowLabel", tokens.text_secondary)
	theme.set_constant("outline_size", "PreviewRowLabel", 0)
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
		_button_box(tokens, tokens.brand_primary_light, tokens.brand_primary_dark,
			tokens.outline_card, 0.0, tokens.radius_button))
	theme.set_stylebox("hover", "Button",
		_button_box(tokens, tokens.brand_primary_light.lightened(0.08),
			tokens.brand_primary_dark.lightened(0.08), tokens.outline_card, 0.0,
			tokens.radius_button))
	theme.set_stylebox("pressed", "Button",
		_button_box(tokens, tokens.brand_primary_dark, tokens.brand_primary_light,
			tokens.outline_card, -tokens.shadow_offset.y * 0.5, tokens.radius_button))
	theme.set_stylebox("disabled", "Button",
		_button_box(tokens, tokens.surface_sunken, tokens.surface_sunken,
			tokens.surface_sunken, 0.0, tokens.radius_button))

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
			tokens.cat_akademis_on_dark, tokens.radius_pill],
		["DaySummaryStatTrackSeniBudaya", tokens.day_stat_track,
			tokens.cat_senibudaya_on_dark, tokens.radius_pill],
		["DaySummaryStatTrackOlahraga", tokens.day_stat_track,
			tokens.cat_olahraga_on_dark, tokens.radius_pill],
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
	# text_primary is a dark brown; multiplying green/red by near-black
	# collapsed both to near-black, destroying the +/- colour coding. White
	# is the multiplicative identity, so self_modulate's colour reads as-is.
	#
	# So the OUTLINE carries the text, and it is dark. Every user of this
	# variation sits on a light ground -- the result card's delta rows and
	# category badge, the item sheet's "+N", the apply-item preview -- where
	# no bright tint can read: the green measured 1.13:1 and the red 2.54:1
	# on surface_sunken, the untinted white 1.02:1 on surface_card, and the
	# cream outline it shipped with did no better (2026-09-11).
	# self_modulate multiplies the outline too, but a dark rim stays dark
	# under any tint: the tint keeps the colour code, the rim does the
	# reading. Guarded by tests/test_light_ground_text.gd.
	theme.add_type("ResultDeltaLabel")
	theme.set_type_variation("ResultDeltaLabel", "Label")
	theme.set_font_size("font_size", "ResultDeltaLabel", tokens.font_caption)
	theme.set_color("font_color", "ResultDeltaLabel", Color.WHITE)
	theme.set_constant("outline_size", "ResultDeltaLabel", 4)
	theme.set_color("font_outline_color", "ResultDeltaLabel", tokens.text_primary)

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
