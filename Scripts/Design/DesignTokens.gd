@tool
class_name DesignTokens
extends Resource

## Single source of truth for every visual constant in KEJARTES.
##
## Edit this resource in the inspector (Assets/Theme/design_tokens.tres),
## then run Scripts/Design/BakeTheme.gd (File > Run) to regenerate the
## Theme. No color, radius, spacing value, font size, or animation
## duration may be hardcoded anywhere else in the project.

const DEFAULT_PATH := "res://Assets/Theme/design_tokens.tres"


static func load_default() -> DesignTokens:
	return load(DEFAULT_PATH) as DesignTokens


@export_group("Brand")
## The saturated brand colour. Fills PrimaryButton, LobbyNavButton and the
## quirk pill's border/tint chain in ThemeFactory. Changing this re-tints
## roughly half the game's call-to-action surfaces -- rebake after editing.
@export var brand_primary: Color = Color("7A4A2B")
## PrimaryButton/LobbyNavButton's hover-lightened and gradient-top variant.
@export var brand_primary_light: Color = Color("9C6440")
## PrimaryButton/LobbyNavButton's pressed-darkened and gradient-bottom variant.
@export var brand_primary_dark: Color = Color("56321B")

@export_group("Surfaces")
## Backdrop colour behind the school-day simulation and its background
## widget -- not used by ThemeFactory, only read directly by SchoolDay.gd
## and SimulationBackground.gd.
@export var surface_page: Color = Color("FBF1E3")
## Fill for the Card theme variation -- every raised panel in the game
## (student cards, popups, day-summary cards) reads from this one colour.
@export var surface_card: Color = Color("FFFDF8")
## Fill for SunkenPanel and the trait-popup badge background -- the
## slightly-recessed surface inset into a Card.
@export var surface_sunken: Color = Color("EFE0CB")
## Base colour for the Scrim theme variation, i.e. every modal backdrop.
## See overlay_scrim_alpha below for the opacity applied on top.
@export var surface_overlay: Color = Color("2E2118")
## Alpha applied to surface_overlay when used as a modal scrim.
@export_range(0.0, 1.0) var overlay_scrim_alpha: float = 0.72

@export_group("Outline & Shadow")
## Border colour on PrimaryButton, DangerButton, SuccessButton,
## LobbyNavButton and Card -- the game's one shared "raised surface" rim.
@export var outline_card: Color = Color("FFF6E8")
## Border width (px) applied everywhere outline_card is, plus Card's own
## border.
@export var outline_width: float = 6.0
## Drop-shadow colour behind every button and Card variation.
@export var shadow_color: Color = Color(0.23, 0.14, 0.06, 0.30)
## Drop-shadow blur radius (px) behind Card and the coin/result labels.
@export var shadow_size: int = 12
## Drop-shadow offset (px) behind buttons and Card; also scaled down for
## the pill button's shorter shadow.
@export var shadow_offset: Vector2 = Vector2(0, 6)

@export_group("Text")
## Default label colour (DisplayLabel, H1Label, day-summary numbers) and
## the outline colour behind BarLabel/coin/result text.
@export var text_primary: Color = Color("3B2412")
## CaptionLabel/MicroLabel colour, and category_color()'s fallback for an
## unrecognized category -- never fully transparent.
@export var text_secondary: Color = Color("7A5C40")
## Font colour on every brand-filled button and BarLabel -- text meant to
## sit on top of a saturated fill.
@export var text_on_brand: Color = Color("FFF6E8")
## Disabled-state font colour (EmptyStateLabel, greyed-out list rows).
@export var text_disabled: Color = Color("BFA88C")
## Chunky outline behind display text, Umamusume style.
@export var text_outline_color: Color = Color("FFF6E8")
## Outline thickness (px) behind BarLabel, ResultHeroLabel and every
## H1Label/DisplayLabel-style heading.
@export var text_outline_size: int = 12

@export_group("Category Accents")
## Tint for the Akademis schedule category and its StatBar/pill/icon uses
## wherever `category_color("Akademis")` is called.
@export var cat_akademis: Color = Color("2E86D8")
## Same as cat_akademis, for Olahraga.
@export var cat_olahraga: Color = Color("E03A18")
## Same as cat_akademis, for SeniBudaya.
@export var cat_senibudaya: Color = Color("4FA317")
## Same as cat_akademis, for Istirahat (the rest-day category, also reused
## as the "Mood" accent on need bars that aren't schedule categories).
@export var cat_istirahat: Color = Color("7C3AED")
## Same as cat_akademis, for Libur (also reused as the "Energy" accent on
## need bars, matching Istirahat's dual role).
@export var cat_libur: Color = Color("D98E0B")
## Wirausaha: the money-earning schedule activity. Teal keeps it clear of
## the five existing category hues.
@export var cat_wirausaha: Color = Color("0E9E7A")

## Akademis on a DARK ground. The light-track cat_akademis measures only
## 1.93:1 against day_bar_track and is unreadable there; this is the value
## the DaySummary card uses. Guarded by tests/test_bar_contrast.gd.
@export var cat_akademis_on_dark: Color = Color("3BA7F5")
## Olahraga on a dark ground. See cat_akademis_on_dark.
@export var cat_olahraga_on_dark: Color = Color("FF5A36")
## SeniBudaya on a dark ground. See cat_akademis_on_dark.
@export var cat_senibudaya_on_dark: Color = Color("6BD425")
## Istirahat on a dark ground, also the DaySummary energy fill's family.
@export var cat_istirahat_on_dark: Color = Color("A78BFA")
## Libur on a dark ground, also the DaySummary mood fill's family.
@export var cat_libur_on_dark: Color = Color("F5A623")
## Wirausaha on a dark ground. See cat_akademis_on_dark.
@export var cat_wirausaha_on_dark: Color = Color("16C79A")

@export_group("Semantic States")
## Positive-outcome tint: SuccessButton, win badges, the specialty-match
## card wash, ShopMessageSuccess.
@export var state_success: Color = Color("35A05A")
## Caution tint: ShopMessageWarning and similar non-fatal alerts.
@export var state_warning: Color = Color("F5A623")
## Negative-outcome tint: DangerButton, loss badges, the tired-student
## card wash, ShopMessageDanger.
@export var state_danger: Color = Color("C0392B")
## Coin/money label colour -- CoinLabel, ShopCoinLabel, ResultHeroLabel.
@export var currency_gold: Color = Color("ffc93c")

@export_group("Radii")
## Unused since the mockup-rescale that moved the schedule pill's corner
## radius to radius_md -- see tests/test_activity_row.gd's regression note.
@export var radius_sm: int = 12
## Corner radius for SunkenPanel and PrimaryButton's fill -- the game's
## most common rounded-rect radius.
@export var radius_md: int = 24
## Corner radius for Card and the trait-popup header's top corners.
@export var radius_lg: int = 36
## Pill buttons use a radius large enough to always round fully.
@export var radius_pill: int = 999
## Corner radius for every Button that reads as a button. Fixed in pixels
## on purpose: radius_pill clamps to half the box height, so before
## 2026-09-08 the project's 15 authored button heights produced 15
## different corner radii between 31 and 145 px. Chips and cards opt out
## explicitly -- see ThemeFactory's radius table.
@export var radius_button: int = 20

@export_group("Spacing")
## Vertical line-spacing inside AturJadwal's tutorial body label, and
## content-margin padding on the schedule preview pill.
@export var space_xs: int = 8
## content_margin for SunkenPanel.
@export var space_sm: int = 16
## content_margin for Card and the quirk-badge header.
@export var space_md: int = 28
## content_margin (left/right) for buttons -- their horizontal breathing room.
@export var space_lg: int = 44
## Currently unused; reserved for a spacing step larger than space_lg.
@export var space_xl: int = 72

@export_group("Button Scale")
## Small step: the most common authored height, and equal to
## touch_target_min. Font is font_title.
@export var btn_h_s: int = 96
## Medium step. Font is font_h2.
@export var btn_h_m: int = 128
## Large step. Font is font_h1.
@export var btn_h_l: int = 160
## Icon edge length inside a small button.
@export var btn_icon_s: int = 48
## Icon edge length inside a medium button.
@export var btn_icon_m: int = 64
## Icon edge length inside a large button.
@export var btn_icon_l: int = 80
## Vertical content_margin for the small step. SOLVED, not chosen: it is
## tuned so a small button's NATURAL minimum height equals btn_h_s, which
## is what lets scene authors set no height at all and never land between
## steps. Re-solve with Task 5's probe if the display font changes.
@export var btn_pad_v_s: int = 20
## Vertical content_margin for the medium step. See btn_pad_v_s.
@export var btn_pad_v_m: int = 29
## Vertical content_margin for the large step. See btn_pad_v_s.
@export var btn_pad_v_l: int = 35

@export_group("Typography")
## Default display face for DisplayLabel/H1Label/BarLabel/CoinLabel/etc,
## wherever ThemeFactory checks `if tokens.font_display != null`. Null
## falls back to the theme's default_font (font_body).
@export var font_display: FontFile
## The theme's default_font, applied project-wide unless a variation
## overrides it with font_display.
@export var font_body: FontFile
## Font size for MicroLabel.
@export var font_micro: int = 18
## Font size for CaptionLabel, StatBar's value label, ResultBodyLabel.
@export var font_caption: int = 22
## The theme's default_font_size -- every Label without a variation.
@export var font_body_size: int = 28
## Font size for TitleLabel and BarLabel.
@export var font_title: int = 36
## Font size for H2Label, ResultHeroLabel and TraitPill.
@export var font_h2: int = 48
## Font size for H1Label.
@export var font_h1: int = 64
## Font size for DisplayLabel.
@export var font_display_size: int = 96

@export_group("Motion")
## Juice.gd's fastest named duration (button press feedback).
@export var dur_instant: float = 0.08
## Juice.gd's quick-transition duration -- popup opens, tab switches.
@export var dur_fast: float = 0.18
## Juice.gd's default duration -- most tweens (scene transitions,
## card fades) that don't ask for a faster or slower one explicitly.
@export var dur_normal: float = 0.32
## Juice.gd's slow duration -- event announcements and warnings, where a
## longer read matters more than snappiness.
@export var dur_slow: float = 0.55
## Scale a button shrinks to while held.
@export_range(0.80, 1.0) var press_scale: float = 0.94
## Scale a button overshoots to on release, before settling at 1.0.
@export_range(1.0, 1.25) var release_overshoot: float = 1.06
## Delay between consecutive items in a staggered list entry.
@export var stagger_step: float = 0.05

@export_group("Layout")
## Minimum touch-friendly control size (px) -- checked directly by
## cut_scene.gd for its tap targets, not consumed by ThemeFactory.
@export var touch_target_min: int = 96
## Screen-edge margin (px) -- SafeAreaMargin's default inset, and
## ThemeFactory's schedule-preview layout margin.
@export var screen_margin: int = 48

@export_group("Penjadwalan Preview")
## Sampled from the mockup (docs: 2026-08-29-penjadwalan-mockup-rescale.md).
## The row container is a grey slab with a purple rim; the pill inset into
## it is darker. Both are vertical gradients in the mockup (row #717171 ->
## #5D5D5D, pill #3C3C3C -> #303030); StyleBoxFlat cannot express a gradient,
## so each token is that gradient's midpoint.
@export var preview_row_fill: Color = Color("6B4B33")
## Rim colour around the schedule preview row, reused as
## PreviewRowLabel's text outline so the label reads against either fill.
@export var preview_row_border: Color = Color("2E2118")
## Fill for the pill inset into the preview row -- darker than
## preview_row_fill so it reads as recessed.
@export var preview_pill_fill: Color = Color("4A3728")
## The row's hard drop shadow, cast just below its bottom border.
@export var preview_row_shadow_color: Color = Color(0, 0, 0, 0.7)
## Blur radius (px) of the row's drop shadow.
@export var preview_row_shadow_size: int = 3
## Offset (px) of the row's drop shadow from the row's own rect.
@export var preview_row_shadow_offset: Vector2 = Vector2(0, 3)
## The pill's soft inset edge -- a shadow, not a border.
@export var preview_pill_shadow_color: Color = Color(0, 0, 0, 0.5)
## Blur radius (px) of the pill's inset shadow.
@export var preview_pill_shadow_size: int = 5
## Offset (px) of the pill's inset shadow from the pill's own rect.
@export var preview_pill_shadow_offset: Vector2 = Vector2(0, 2)


@export_group("Day Summary")
## Sampled from dailyresults_mockup.png (spec:
## 2026-08-29-day-summary-mockup-design.md). Several surfaces in that
## mockup are vertical gradients, which StyleBoxFlat cannot express; as
## with the Penjadwalan tokens above, each colour here is that
## gradient's midpoint.
##   avatar frame  -- flat violet behind the splash crop
##   bar track     -- #636363 -> #4E4E4E
##   energy fill   -- #7062C7 -> #695CB9
##   mood fill     -- #DFC361 -> #A69249
##   stat track    -- #3C3C3C -> #353535
## Fill behind the student portrait crop on the day-summary card.
@export var day_avatar_fill: Color = Color("7A4A2B")
## Rim around the portrait frame.
@export var day_avatar_border: Color = Color("FFF6E8")
## Empty-track colour shared by the energy and mood bars.
@export var day_bar_track: Color = Color("4A3728")
## Rim around both the energy and mood bar tracks.
@export var day_bar_border: Color = Color("2E2118")
## Fill colour for the energy bar specifically (day_bar_track is the
## shared empty state; this is energy's fill).
@export var day_energy_fill: Color = Color("A78BFA")
## Fill colour for the mood bar specifically.
@export var day_mood_fill: Color = Color("F5A623")
## Empty-track colour for the three academic stat bars (Akademis,
## SeniBudaya, Olahraga) -- distinct from day_bar_track, which is only
## the needs (energy/mood) bars.
@export var day_stat_track: Color = Color("3F2E21")
## The dark rim every white glyph on this card carries -- name, stat
## icons and the +N/T numbers alike.
@export var day_glyph_outline: Color = Color("2E2118")

## Geometry measured off the mockup, in game pixels (mockup is 1:1).
## Corner radius of the avatar frame.
@export var day_avatar_radius: int = 22
## Corner radius of every stat/need bar track on the card.
@export var day_bar_radius: int = 18
## Font size for the student's name on the card.
@export var day_name_size: int = 40
## Font size for the card's stat numbers ("+12/65", overlaid on the
## stat track).
@export var day_stat_size: int = 52
## Font size for the energy/mood bar's tier word ("Lelah", "Senang").
## Independent of day_stat_size on purpose: the two used to share one
## token (day_stat_size - 4), which meant bumping the stat number for
## the stat-row polish pass silently blew this one up too -- "Senang"
## at that size measured ~235px against the ~175px of pill actually
## free past the icon, and visibly overran the needs bar. Keep this
## under ~32 unless EnergyBar/MoodBar's own width also grows -- see
## test_needs_bar_word_fits_its_pill.
@export var day_needs_label_size: int = 30


## Resolve a schedule category name to its accent color.
## Returns text_secondary for anything unrecognized so callers never
## get a transparent color they would silently render as invisible.
func category_color(category: String) -> Color:
	match category:
		"Akademis", "Akademik": return cat_akademis
		"Olahraga": return cat_olahraga
		"SeniBudaya", "Seni Budaya": return cat_senibudaya
		"Istirahat": return cat_istirahat
		"Libur": return cat_libur
		"Wirausaha": return cat_wirausaha
		_: return text_secondary


## Resolve a schedule category to its accent for use on a DARK ground.
## Same shape and same fallback as category_color(); the two exist as a
## pair because one colour cannot clear contrast on both the light
## StatBar track and the dark DaySummary track.
func category_color_on_dark(category: String) -> Color:
	match category:
		"Akademis", "Akademik": return cat_akademis_on_dark
		"Olahraga": return cat_olahraga_on_dark
		"SeniBudaya", "Seni Budaya": return cat_senibudaya_on_dark
		"Istirahat": return cat_istirahat_on_dark
		"Libur": return cat_libur_on_dark
		"Wirausaha": return cat_wirausaha_on_dark
		_: return text_secondary


## The modal scrim color, i.e. surface_overlay at the configured alpha.
func scrim_color() -> Color:
	var c := surface_overlay
	c.a = overlay_scrim_alpha
	return c
