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
@export var brand_primary: Color = Color("2e5bff")
@export var brand_primary_light: Color = Color("6e8cff")
@export var brand_primary_dark: Color = Color("1b3acc")

@export_group("Surfaces")
@export var surface_page: Color = Color("eef3ff")
@export var surface_card: Color = Color("ffffff")
@export var surface_sunken: Color = Color("dde5f7")
@export var surface_overlay: Color = Color("141a2e")
## Alpha applied to surface_overlay when used as a modal scrim.
@export_range(0.0, 1.0) var overlay_scrim_alpha: float = 0.72

@export_group("Outline & Shadow")
@export var outline_card: Color = Color("ffffff")
@export var outline_width: float = 6.0
@export var shadow_color: Color = Color(0.08, 0.11, 0.22, 0.28)
@export var shadow_size: int = 14
@export var shadow_offset: Vector2 = Vector2(0, 6)

@export_group("Text")
@export var text_primary: Color = Color("1e2436")
@export var text_secondary: Color = Color("6b7490")
@export var text_on_brand: Color = Color("ffffff")
@export var text_disabled: Color = Color("a8b0c4")
## Chunky outline behind display text, Umamusume style.
@export var text_outline_color: Color = Color("ffffff")
@export var text_outline_size: int = 8

@export_group("Category Accents")
@export var cat_akademis: Color = Color("3d8bff")
@export var cat_olahraga: Color = Color("e5484d")
@export var cat_senibudaya: Color = Color("7cb342")
@export var cat_istirahat: Color = Color("6b4fe0")
@export var cat_libur: Color = Color("ffc93c")

@export_group("Semantic States")
@export var state_success: Color = Color("2fb86b")
@export var state_warning: Color = Color("ffb020")
@export var state_danger: Color = Color("c42b6e")
@export var currency_gold: Color = Color("ffc93c")

@export_group("Radii")
@export var radius_sm: int = 12
@export var radius_md: int = 24
@export var radius_lg: int = 36
## Pill buttons use a radius large enough to always round fully.
@export var radius_pill: int = 999

@export_group("Spacing")
@export var space_xs: int = 8
@export var space_sm: int = 16
@export var space_md: int = 28
@export var space_lg: int = 44
@export var space_xl: int = 72

@export_group("Typography")
@export var font_display: FontFile
@export var font_body: FontFile
@export var font_micro: int = 18
@export var font_caption: int = 22
@export var font_body_size: int = 28
@export var font_title: int = 36
@export var font_h2: int = 48
@export var font_h1: int = 64
@export var font_display_size: int = 96

@export_group("Motion")
@export var dur_instant: float = 0.08
@export var dur_fast: float = 0.18
@export var dur_normal: float = 0.32
@export var dur_slow: float = 0.55
## Scale a button shrinks to while held.
@export_range(0.80, 1.0) var press_scale: float = 0.94
## Scale a button overshoots to on release, before settling at 1.0.
@export_range(1.0, 1.25) var release_overshoot: float = 1.06
## Delay between consecutive items in a staggered list entry.
@export var stagger_step: float = 0.05

@export_group("Layout")
@export var touch_target_min: int = 96
@export var screen_margin: int = 48


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
		_: return text_secondary


## The modal scrim color, i.e. surface_overlay at the configured alpha.
func scrim_color() -> Color:
	var c := surface_overlay
	c.a = overlay_scrim_alpha
	return c
