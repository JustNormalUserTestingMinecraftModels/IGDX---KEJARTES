@tool
class_name StudentSummaryCard
extends PanelContainer

## The Card+Margin chrome shared by SchoolDay's day-summary card,
## DailyDecayOverview's decay card and EventStudentSelectDialog's picker
## card. Each screen's actual content (name/badge layout, stat rows,
## checkboxes, tinting) stays hand-built as a child of `margin` -- the
## three screens' content differs in node type and shape, not just
## numbers, so only the genuinely shared outer frame lives here.

## Margin between the Card surface and its content. Defaults match
## DailyDecayOverview and EventStudentSelectDialog (both 20/16/20/16);
## SchoolDay overrides to its own 24/14/24/12.
@export var margin_left: int = 20:
	set(value):
		margin_left = value
		if is_inside_tree():
			margin.add_theme_constant_override("margin_left", value)

## Same as margin_left, for the top edge.
@export var margin_top: int = 16:
	set(value):
		margin_top = value
		if is_inside_tree():
			margin.add_theme_constant_override("margin_top", value)

## Same as margin_left, for the right edge.
@export var margin_right: int = 20:
	set(value):
		margin_right = value
		if is_inside_tree():
			margin.add_theme_constant_override("margin_right", value)

## Same as margin_left, for the bottom edge.
@export var margin_bottom: int = 16:
	set(value):
		margin_bottom = value
		if is_inside_tree():
			margin.add_theme_constant_override("margin_bottom", value)

@onready var margin: MarginContainer = $Margin


func _ready() -> void:
	margin.add_theme_constant_override("margin_left", margin_left)
	margin.add_theme_constant_override("margin_top", margin_top)
	margin.add_theme_constant_override("margin_right", margin_right)
	margin.add_theme_constant_override("margin_bottom", margin_bottom)


## An art-supplied card texture wins over the theme's Card surface --
## only SchoolDay's day-summary card ever calls this. The content-margin
## numbers are SchoolDay's shipped values (the texture's own padding, on
## top of this node's own `margin_*` above). Passing null restores the
## plain Card variation.
func set_background_texture(texture: Texture2D) -> void:
	if texture == null:
		remove_theme_stylebox_override("panel")
		theme_type_variation = &"Card"
		return
	var style_tex := StyleBoxTexture.new()
	style_tex.texture = texture
	style_tex.content_margin_left = 24
	style_tex.content_margin_right = 24
	style_tex.content_margin_top = 16
	style_tex.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style_tex)
