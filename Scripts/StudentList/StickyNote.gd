@tool
class_name StickyNote
extends TextureRect

## One sticky-note day/activity chip on a StudentList card. Extracted
## from ~20 near-identical inline subtrees (4 students x 5 days) so a
## designer can retune the note's look in one place. Tinted per
## schedule category via DesignTokens.category_color(), applied to
## self_modulate (not modulate) so the tint never bleeds into the
## child labels' own theme-driven font colors.

## Shown uppercased on DayLabel (e.g. "Senin" -> "SENIN").
@export var day_name: String = "Senin":
	set(value):
		day_name = value
		if is_node_ready():
			$DayLabel.text = value.to_upper()

## The schedule category for this day -- shown on ActivityLabel and used
## to tint the note via DesignTokens.category_color().
@export var activity: String = "-":
	set(value):
		activity = value
		if is_node_ready():
			$ActivityLabel.text = value
			self_modulate = DesignTokens.load_default().category_color(value)

## The schedule category's glyph, shown beside the activity name. Set
## from student_list.gd per the day's scheduled category so every day in
## the week strip reads at a glance.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			$Icon.texture = value


func _ready() -> void:
	$DayLabel.text = day_name.to_upper()
	$ActivityLabel.text = activity
	self_modulate = DesignTokens.load_default().category_color(activity)
	$Icon.texture = icon_texture
