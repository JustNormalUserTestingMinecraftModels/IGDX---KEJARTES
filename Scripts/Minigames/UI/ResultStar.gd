@tool
class_name ResultStar
extends Control

## One star in the end-of-minigame result card's three-star row.
##
## Instantiated three times (fixed, in Scenes/Minigames/UI/ResultStar.tscn's
## parent) by MinigameResultPopup.tscn. Before this scene existed,
## BaseMinigame._draw_star_polygon() drew a filled or outlined five-pointed
## star by hand on a throwaway Control every time the result card showed.
##
## Affects: nothing outside itself.
##
## @tool so the scene previews in the editor.

## Whether this star reads as earned. Read by tests and by the popup when
## counting how many stars to reveal.
var is_filled: bool = false

@onready var icon: TextureRect = $Icon


func _ready() -> void:
	icon.visible = icon.texture != null
	queue_redraw()


## Fill this star from the popup's star art/colour @exports.
##
## `filled_tex` / `empty_tex` are BaseMinigame's popup_star_texture /
## popup_star_empty_texture -- leave either null to fall back to the
## procedural five-pointed polygon _draw() draws below.
##
## Affects: this star's own icon and is_filled. Triggers a redraw.
func set_filled(filled: bool, filled_tex: Texture2D, empty_tex: Texture2D,
		filled_color: Color, empty_color: Color) -> void:
	is_filled = filled
	var tex := filled_tex if filled else empty_tex
	icon.texture = tex
	icon.visible = tex != null
	icon.modulate = filled_color if filled else empty_color
	queue_redraw()


## The procedural five-pointed star, drawn only when no texture is set --
## ResultStar falls back to it automatically. Filled draws a solid polygon;
## unfilled draws only the outline.
func _draw() -> void:
	if icon.texture != null:
		return
	var pts := PackedVector2Array()
	var cx := size.x / 2.0
	var cy := size.y / 2.0
	var outer: float = minf(cx, cy) * 0.92
	var inner: float = outer * 0.42
	for i in range(10):
		var angle := deg_to_rad(i * 36.0 - 90.0)
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector2(cx + r * cos(angle), cy + r * sin(angle)))
	var color := icon.modulate
	if is_filled:
		draw_colored_polygon(pts, color)
	else:
		draw_polyline(PackedVector2Array(pts) + PackedVector2Array([pts[0]]), color, 3.0, true)
