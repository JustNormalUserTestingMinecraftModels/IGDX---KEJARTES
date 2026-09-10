@tool
class_name StickyNote
extends TextureRect

## One sticky-note day/activity chip on a StudentList card. Extracted
## from ~20 near-identical inline subtrees (4 students x 5 days) so a
## designer can retune the note's look in one place. Tinted per
## schedule category via DesignTokens.category_color(), applied to
## self_modulate (not modulate) so the tint never bleeds into the
## child labels' own theme-driven font colors.
##
## The tint is washed toward white before it is applied. self_modulate
## *multiplies* the paper texture, so a full-strength category color --
## or text_secondary, which an unscheduled "-" day resolves to -- drives
## the note dark enough that the dark-brown label text sitting on top of
## it stops being legible on a phone. TINT_WASH keeps the category
## readable as a hue while leaving the note light enough to write on.

## How far each category color is pulled toward white before it is
## multiplied into the paper. 0.0 is the raw token (illegible), 1.0 is
## plain white paper with no category read at all.
const TINT_WASH := 0.55

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
			_apply_tint()

## The schedule category's glyph, shown beside the activity name. Set
## from student_list.gd per the day's scheduled category so every day in
## the week strip reads at a glance.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			$Icon.texture = value


## Wash this day's category color toward white and multiply it into the
## paper. Kept in one place so the setter and _ready() cannot drift.
func _apply_tint() -> void:
	var raw: Color = DesignTokens.load_default().category_color(activity)
	self_modulate = raw.lerp(Color.WHITE, TINT_WASH)


func _ready() -> void:
	$DayLabel.text = day_name.to_upper()
	$ActivityLabel.text = activity
	_apply_tint()
	$Icon.texture = icon_texture
