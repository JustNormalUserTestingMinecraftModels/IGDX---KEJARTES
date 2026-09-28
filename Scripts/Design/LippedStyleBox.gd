@tool
class_name LippedStyleBox
extends StyleBox

## A surface with depth for buttons, tabs and panels (2026-09-28 UI depth
## pass; docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md).
##
## Draws three shapes, back to front: a solid darker LIP, the FACE on top of
## it, and a white GLOSS band across the face's top third. pressed = true is
## the held state -- no lip, the face lowered by lip_height -- so a button
## sinks onto its lip on the exact frame of the touch, with no animation to
## lag or skip.
##
## Each shape is drawn by an internal StyleBoxFlat, which keeps Godot's
## anti-aliased corners. layout() is the geometry, pure, so the tests read
## the same numbers _draw() uses.

## Gloss band inset from the face's left and right edges, px.
const GLOSS_INSET_X := 8
## Gloss band inset from the face's top edge, px.
const GLOSS_INSET_TOP := 4
## Gloss band height as a fraction of the face's height.
const GLOSS_HEIGHT_RATIO := 0.34

## The face colour (named like StyleBoxFlat's, so a reader of either type
## finds it in the same place).
@export var bg_color: Color = Color.WHITE:
	set(value):
		bg_color = value
		emit_changed()
## The lip colour: the solid slab showing under the face.
@export var lip_color: Color = Color.BLACK:
	set(value):
		lip_color = value
		emit_changed()
## How far the lip shows below the face, px. 0 draws a flat face.
@export_range(0, 32) var lip_height: int = 0:
	set(value):
		lip_height = maxi(value, 0)
		emit_changed()
## Corner radius of the face and lip, px. Godot clamps it to half the
## shorter side, so a large value makes a pill.
@export var corner_radius: int = 0:
	set(value):
		corner_radius = maxi(value, 0)
		emit_changed()
## Alpha of the white gloss band. 0 hides it.
@export_range(0.0, 1.0) var gloss_strength: float = 0.0:
	set(value):
		gloss_strength = value
		emit_changed()
## The soft drop shadow, drawn under the bottom-most shape.
@export var shadow_color: Color = Color(0, 0, 0, 0):
	set(value):
		shadow_color = value
		emit_changed()
## Blur size of the drop shadow, px.
@export var shadow_size: int = 0:
	set(value):
		shadow_size = maxi(value, 0)
		emit_changed()
## Offset of the drop shadow, px.
@export var shadow_offset: Vector2 = Vector2.ZERO:
	set(value):
		shadow_offset = value
		emit_changed()
## True draws the held state: no lip, the face lowered by lip_height.
@export var pressed: bool = false:
	set(value):
		pressed = value
		emit_changed()

var _lip_box: StyleBoxFlat = StyleBoxFlat.new()
var _face_box: StyleBoxFlat = StyleBoxFlat.new()
var _gloss_box: StyleBoxFlat = StyleBoxFlat.new()


## Face, lip and gloss rects for `rect`, and whether the lip shows.
##
## Affects: nothing. Pure.
func layout(rect: Rect2) -> Dictionary:
	var lip := float(lip_height)
	var face_size := Vector2(rect.size.x, maxf(rect.size.y - lip, 0.0))
	var face := Rect2(rect.position + Vector2(0.0, lip if pressed else 0.0), face_size)
	var gloss := Rect2(
		face.position + Vector2(GLOSS_INSET_X, GLOSS_INSET_TOP),
		Vector2(maxf(face.size.x - 2.0 * GLOSS_INSET_X, 0.0), face.size.y * GLOSS_HEIGHT_RATIO))
	return {
		"face": face,
		"lip": Rect2(rect.position + Vector2(0.0, lip), face_size),
		"gloss": gloss,
		"show_lip": lip_height > 0 and not pressed,
	}


## Split `pad_v` between top and bottom so the label centres on the face,
## keeping the sum -- and so the button's height -- unchanged. At rest the
## label rises by half the lip; held, it drops by the same, so it moves
## with the face.
##
## Affects: content_margin_top, content_margin_bottom.
func set_vertical_padding(pad_v: int) -> void:
	var shift := mini(floori(lip_height / 2.0), pad_v)
	var lift := -shift if pressed else shift
	content_margin_top = pad_v - lift
	content_margin_bottom = pad_v + lift


## Re-run set_vertical_padding() with the padding the box already carries,
## after lip_height changed.
##
## Affects: content_margin_top, content_margin_bottom.
func repad() -> void:
	set_vertical_padding(roundi((content_margin_top + content_margin_bottom) / 2.0))


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var parts := layout(rect)
	var show_lip: bool = parts["show_lip"]
	_paint(_lip_box, lip_color, corner_radius)
	_paint(_face_box, bg_color, corner_radius)
	_paint(_gloss_box, Color(1, 1, 1, gloss_strength), maxi(corner_radius - GLOSS_INSET_X, 0))
	var lowest := _lip_box if show_lip else _face_box
	lowest.shadow_color = shadow_color
	lowest.shadow_size = shadow_size
	lowest.shadow_offset = shadow_offset
	if show_lip:
		_lip_box.draw(to_canvas_item, parts["lip"])
	_face_box.draw(to_canvas_item, parts["face"])
	if gloss_strength > 0.0:
		_gloss_box.draw(to_canvas_item, parts["gloss"])


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(shadow_size + ceili(shadow_offset.length()))


static func _paint(box: StyleBoxFlat, color: Color, radius: int) -> void:
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.shadow_size = 0
