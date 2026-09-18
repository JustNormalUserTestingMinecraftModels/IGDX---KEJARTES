@tool
class_name SkinFrame
extends Control

## A student's art cropped into a rounded rectangle with a brown outline --
## the skin popup's tall roster cards and square bust-ups (SkinFrame.tscn,
## mockups skinselect_mockup.png / skinselectoption_mockup.png).
##
## Mask is an opaque rounded Panel with clip_children, so the Art inside it is
## clipped to the rounded shape; Border is a fill-less outline drawn on top as
## a sibling, so it is never clipped. This script only lays out Art: it scales
## the texture so `visible_source_height` source pixels fill the frame's
## height and places the given head point mid-width at `face_y_ratio` down.
## Pure geometry on authored nodes -- nothing is created here.

## Source (splash) pixels shown top-to-bottom. Smaller zooms in.
@export var visible_source_height: float = 1050.0:
	set(v):
		visible_source_height = maxf(v, 1.0)
		_layout()
## Where the head point lands, as a fraction of the frame's height from the top.
@export_range(0.0, 1.0) var face_y_ratio: float = 0.3:
	set(v):
		face_y_ratio = v
		_layout()

var _texture: Texture2D
var _center: Vector2 = Vector2.ZERO


## Shows `tex` with source point `center` (usually StudentSkins.bust_center)
## placed by the knobs above. A null texture clears the frame.
func show_art(tex: Texture2D, center: Vector2) -> void:
	_texture = tex
	_center = center
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var art := get_node_or_null(^"Mask/Art") as TextureRect
	if art == null:
		return
	art.texture = _texture
	if _texture == null or size.y <= 0.0:
		return
	var s := size.y / visible_source_height
	art.size = _texture.get_size() * s
	art.position = Vector2(size.x * 0.5 - _center.x * s, size.y * face_y_ratio - _center.y * s)
