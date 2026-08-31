@tool
class_name StudentStatRow
extends HBoxContainer

## One "icon (or glyph) + bar + number" row. SchoolDay's per-student
## energy/mood readout and DailyDecayOverview's end-of-day summary both
## build this shape via setup(); when a screen has no icon texture to
## show (DailyDecayOverview never does), Glyph carries the screen's full
## label text instead of a short glyph -- same node, different content.
##
## The three ways the two callers' rows actually differ (bar height,
## Glyph/InfoLabel width, InfoLabel's theme variation) are @export knobs
## below. Everything else (separation, alignment, Bar's tint-via-category)
## is baked into the scene because the shipped values already matched.

## Width of the Glyph label. SchoolDay's short glyph ("⚡") needs only
## 36px; DailyDecayOverview's full-sentence label ("Energy ⚡") needs 220.
@export var glyph_min_width: float = 36.0:
	set(value):
		glyph_min_width = value
		if is_inside_tree():
			_apply_layout_exports()

## Height of the StatBar. SchoolDay's embedded rows are 32px tall;
## DailyDecayOverview's end-of-day rows are 48.
@export var bar_min_height: float = 32.0:
	set(value):
		bar_min_height = value
		if is_inside_tree():
			_apply_layout_exports()

## Theme variation for InfoLabel. SchoolDay uses the quieter CaptionLabel;
## DailyDecayOverview uses TitleLabel to match its bigger summary card.
@export var info_label_variation: StringName = &"CaptionLabel":
	set(value):
		info_label_variation = value
		if is_inside_tree():
			info_label.theme_type_variation = value

## Optional font override for Glyph and InfoLabel. Only DailyDecayOverview
## (and EventStudentSelectDialog, out of scope for this row) ever set one.
@export var custom_font: Font = null:
	set(value):
		custom_font = value
		if is_inside_tree():
			_apply_custom_font()

@onready var icon: TextureRect = $Icon
@onready var glyph: Label = $Glyph
@onready var bar: StatBar = $Bar
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	_ensure_nodes()
	_apply_layout_exports()
	_apply_custom_font()
	info_label.theme_type_variation = info_label_variation


## SchoolDay's and DailyDecayOverview's per-student cards build their
## whole subtree off-tree before appending it in one shot at the end --
## the same pattern the original hand-built code used. That means
## setup()/animate_to() can run before this row's own @onready vars have
## resolved (NOTIFICATION_READY needs real tree entry, which hasn't
## happened yet). get_node() works regardless, since instantiate() built
## the subtree already -- so resolve manually if @onready hasn't fired.
func _ensure_nodes() -> void:
	if icon == null:
		icon = get_node("Icon") as TextureRect
		glyph = get_node("Glyph") as Label
		bar = get_node("Bar") as StatBar
		info_label = get_node("InfoLabel") as Label


func _apply_layout_exports() -> void:
	glyph.custom_minimum_size = Vector2(glyph_min_width, 0)
	bar.custom_minimum_size = Vector2(bar.custom_minimum_size.x, bar_min_height)


func _apply_custom_font() -> void:
	if custom_font == null:
		return
	glyph.add_theme_font_override("font", custom_font)
	info_label.add_theme_font_override("font", custom_font)


## Fills the row for one stat. `icon_texture` left null shows Glyph with
## `label_text` instead of Icon -- pass a texture only when the caller has
## a real icon asset to show (SchoolDay's energy/mood placeholders).
## `category` feeds StatBar.category directly (a tint key like "Libur" or
## "Istirahat", not a skill name -- see StatBar.gd).
func setup(label_text: String, value: float, category: String, icon_texture: Texture2D = null) -> void:
	_ensure_nodes()
	bar.category = category
	bar.value = value
	info_label.text = "%d/100" % int(value)
	if icon_texture != null:
		icon.texture = icon_texture
		icon.visible = true
		glyph.visible = false
	else:
		icon.visible = false
		glyph.visible = true
		glyph.text = label_text


## Animates the bar (and its value label, if shown) to `value` instead of
## snapping -- forwards to StatBar.set_stat, used by DailyDecayOverview's
## end-of-day reveal.
func animate_to(value: float) -> void:
	_ensure_nodes()
	bar.set_stat(value, true)
