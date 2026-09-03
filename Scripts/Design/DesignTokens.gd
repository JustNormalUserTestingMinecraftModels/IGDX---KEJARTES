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
@export var brand_primary: Color = Color("2e5bff")
## PrimaryButton/LobbyNavButton's hover-lightened and gradient-top variant.
@export var brand_primary_light: Color = Color("6e8cff")
## PrimaryButton/LobbyNavButton's pressed-darkened and gradient-bottom variant.
@export var brand_primary_dark: Color = Color("1b3acc")

@export_group("Surfaces")
## Backdrop colour behind the school-day simulation and its background
## widget -- not used by ThemeFactory, only read directly by SchoolDay.gd
## and SimulationBackground.gd.
@export var surface_page: Color = Color("eef3ff")
## Fill for the Card theme variation -- every raised panel in the game
## (student cards, popups, day-summary cards) reads from this one colour.
@export var surface_card: Color = Color("ffffff")
## Fill for SunkenPanel and the trait-popup badge background -- the
## slightly-recessed surface inset into a Card.
@export var surface_sunken: Color = Color("dde5f7")
## Base colour for the Scrim theme variation, i.e. every modal backdrop.
## See overlay_scrim_alpha below for the opacity applied on top.
@export var surface_overlay: Color = Color("141a2e")
## Alpha applied to surface_overlay when used as a modal scrim.
@export_range(0.0, 1.0) var overlay_scrim_alpha: float = 0.72

@export_group("Outline & Shadow")
## Border colour on PrimaryButton, DangerButton, SuccessButton,
## LobbyNavButton and Card -- the game's one shared "raised surface" rim.
@export var outline_card: Color = Color("ffffff")
## Border width (px) applied everywhere outline_card is, plus Card's own
## border.
@export var outline_width: float = 6.0
## Drop-shadow colour behind every button and Card variation.
@export var shadow_color: Color = Color(0.08, 0.11, 0.22, 0.28)
## Drop-shadow blur radius (px) behind Card and the coin/result labels.
@export var shadow_size: int = 14
## Drop-shadow offset (px) behind buttons and Card; also scaled down for
## the pill button's shorter shadow.
@export var shadow_offset: Vector2 = Vector2(0, 6)

@export_group("Text")
## Default label colour (DisplayLabel, H1Label, day-summary numbers) and
## the outline colour behind BarLabel/coin/result text.
@export var text_primary: Color = Color("1e2436")
## CaptionLabel/MicroLabel colour, and category_color()'s fallback for an
## unrecognized category -- never fully transparent.
@export var text_secondary: Color = Color("6b7490")
## Font colour on every brand-filled button and BarLabel -- text meant to
## sit on top of a saturated fill.
@export var text_on_brand: Color = Color("ffffff")
## Disabled-state font colour (EmptyStateLabel, greyed-out list rows).
@export var text_disabled: Color = Color("a8b0c4")
## Chunky outline behind display text, Umamusume style.
@export var text_outline_color: Color = Color("ffffff")
## Outline thickness (px) behind BarLabel, ResultHeroLabel and every
## H1Label/DisplayLabel-style heading.
@export var text_outline_size: int = 12

@export_group("Category Accents")
## Tint for the Akademis schedule category and its StatBar/pill/icon uses
## wherever `category_color("Akademis")` is called.
@export var cat_akademis: Color = Color("268fff")
## Same as cat_akademis, for Olahraga.
@export var cat_olahraga: Color = Color("ff263c")
## Same as cat_akademis, for SeniBudaya.
@export var cat_senibudaya: Color = Color("a3ff1a")
## Same as cat_akademis, for Istirahat (the rest-day category, also reused
## as the "Mood" accent on need bars that aren't schedule categories).
@export var cat_istirahat: Color = Color("6640ff")
## Same as cat_akademis, for Libur (also reused as the "Energy" accent on
## need bars, matching Istirahat's dual role).
@export var cat_libur: Color = Color("ffd333")
## Wirausaha: the money-earning schedule activity. Teal keeps it clear of
## the five existing category hues.
@export var cat_wirausaha: Color = Color("00e6b8")

@export_group("Semantic States")
## Positive-outcome tint: SuccessButton, win badges, the specialty-match
## card wash, ShopMessageSuccess.
@export var state_success: Color = Color("2fb86b")
## Caution tint: ShopMessageWarning and similar non-fatal alerts.
@export var state_warning: Color = Color("ffb020")
## Negative-outcome tint: DangerButton, loss badges, the tired-student
## card wash, ShopMessageDanger.
@export var state_danger: Color = Color("c42b6e")
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
@export var preview_row_fill: Color = Color("676767")
## Rim colour around the schedule preview row, reused as
## PreviewRowLabel's text outline so the label reads against either fill.
@export var preview_row_border: Color = Color("3d2048")
## Fill for the pill inset into the preview row -- darker than
## preview_row_fill so it reads as recessed.
@export var preview_pill_fill: Color = Color("363636")

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
@export var day_avatar_fill: Color = Color("5e4ebc")
## Rim around the portrait frame.
@export var day_avatar_border: Color = Color("3d3d3d")
## Empty-track colour shared by the energy and mood bars.
@export var day_bar_track: Color = Color("585858")
## Rim around both the energy and mood bar tracks.
@export var day_bar_border: Color = Color("2b2b2b")
## Fill colour for the energy bar specifically (day_bar_track is the
## shared empty state; this is energy's fill).
@export var day_energy_fill: Color = Color("6d60c0")
## Fill colour for the mood bar specifically.
@export var day_mood_fill: Color = Color("c8af57")
## Empty-track colour for the three academic stat bars (Akademis,
## SeniBudaya, Olahraga) -- distinct from day_bar_track, which is only
## the needs (energy/mood) bars.
@export var day_stat_track: Color = Color("383838")
## The dark rim every white glyph on this card carries -- name, stat
## icons and the +N/T numbers alike.
@export var day_glyph_outline: Color = Color("3d1e48")

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


## The modal scrim color, i.e. surface_overlay at the configured alpha.
func scrim_color() -> Color:
	var c := surface_overlay
	c.a = overlay_scrim_alpha
	return c
