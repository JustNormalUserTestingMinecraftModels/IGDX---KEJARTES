@tool
extends Control

## A bouncing arrow pointing at whatever the current tutorial step is
## highlighting.
##
## Not an autoload: every tutorial screen (StudentCard, StudentList,
## AturJadwal, Lobby) instances Scenes/UI/TutorialArrow.tscn as part of its
## per-step onboarding highlight, positions it itself and calls
## set_direction() to flip which way it points and restart the bounce.
##
## The picture is the scene's authored `Visual` TextureRect; this script
## only sizes it (arrow_size), flips it and bounces it. The Control's own
## origin is the arrow's tip: the picture hangs above that point, centred,
## so a caller positions the Control at the spot to indicate.

## How far the arrow bounces away from the spot it points at, in pixels.
const BOUNCE_DISTANCE := 50.0
## How long one leg of the bounce takes, in seconds.
const BOUNCE_LEG_SECONDS := 0.45
## How far the picture turns to point up instead of down, in degrees.
const UP_ROTATION_DEGREES := 180.0
## How far the tip stops short of the edge of the spot it points at, in pixels.
const TIP_GAP := 35.0
## The least room the picture leaves to the edge of the area it may sit in.
const EDGE_MARGIN := 20.0

## Size of the arrow picture, in pixels. The tip stays at this Control's
## origin whatever the size.
@export var arrow_size: Vector2 = Vector2(180, 180):
	set(value):
		arrow_size = value
		_apply_arrow_size()

## The arrow picture, the scene's authored `Visual` child.
@onready var visual_arrow: TextureRect = $Visual

var bounce_tween: Tween
var _pointing_up := false


func _ready() -> void:
	_apply_arrow_size()
	if Engine.is_editor_hint():
		return
	_start_bounce()


## Sizes the picture and hangs it from the tip at the origin. Safe before
## _ready(), when the picture is not bound yet; _ready() calls it again.
func _apply_arrow_size() -> void:
	if visual_arrow == null:
		return
	visual_arrow.size = arrow_size
	visual_arrow.position = _rest_position()
	visual_arrow.pivot_offset = Vector2(arrow_size.x / 2.0, arrow_size.y)
	if bounce_tween != null:
		_start_bounce()


## Where the picture sits between bounces: centred on the tip, hanging above.
func _rest_position() -> Vector2:
	return Vector2(-arrow_size.x / 2.0, -arrow_size.y)


## Sets the arrow beside `spot` and returns where the Control's origin, the
## tip, goes, in the parent's space; the caller positions or tweens to it.
## `bounds` is the area the picture may sit in and `avoid` a rectangle it must
## stay off (the tutorial card; empty for none). See fit() for the rules.
func point_at(spot: Rect2, bounds: Rect2, avoid: Rect2 = Rect2()) -> Vector2:
	var placed := fit(spot, bounds, arrow_size, avoid)
	set_direction(placed["pointing_up"])
	return placed["tip"]


## Where an arrow of `picture_size` goes to point at `spot`, as {"tip": Vector2,
## "pointing_up": bool, "clear": bool}; all rectangles share one coordinate
## space. The picture hangs above the spot pointing down, or failing that
## below it pointing up; a side is taken when the picture then sits wholly
## inside `bounds` (less EDGE_MARGIN) and off `avoid`. The tip stops TIP_GAP
## short of the spot's edge and is centred on the spot, pulled in where the
## picture would leave `bounds`, so it is beside the spot and never across it.
## "clear" is false when neither side qualifies (a spot bigger than the screen
## leaves no room): the tip is then clamped into `bounds` above the spot,
## across whatever is there.
static func fit(spot: Rect2, bounds: Rect2, picture_size: Vector2, avoid: Rect2 = Rect2()) -> Dictionary:
	var inner := bounds.grow(-EDGE_MARGIN)
	var x := clampf(spot.get_center().x, inner.position.x + picture_size.x / 2.0,
			inner.end.x - picture_size.x / 2.0)
	var above := Vector2(x, spot.position.y - TIP_GAP)
	var below := Vector2(x, spot.end.y + TIP_GAP)
	for pointing_up: bool in [false, true]:
		var tip := below if pointing_up else above
		var picture := picture_rect(tip, picture_size, pointing_up)
		if inner.encloses(picture) and not (avoid.has_area() and picture.intersects(avoid)):
			return {"tip": tip, "pointing_up": pointing_up, "clear": true}
	var lowest := maxf(inner.end.y, inner.position.y + picture_size.y)
	var squeezed := clampf(above.y, inner.position.y + picture_size.y, lowest)
	return {"tip": Vector2(x, squeezed), "pointing_up": false, "clear": false}


## The rectangle the picture covers when its tip is at `tip`: hanging above it
## pointing down, or below it pointing up, centred across it.
static func picture_rect(tip: Vector2, picture_size: Vector2, pointing_up: bool) -> Rect2:
	var top := tip.y if pointing_up else tip.y - picture_size.y
	return Rect2(Vector2(tip.x - picture_size.x / 2.0, top), picture_size)


func set_direction(pointing_up: bool) -> void:
	if _pointing_up == pointing_up:
		return
	_pointing_up = pointing_up
	visual_arrow.rotation_degrees = UP_ROTATION_DEGREES if _pointing_up else 0.0
	if Engine.is_editor_hint():
		return
	_start_bounce()


func _start_bounce() -> void:
	if bounce_tween != null and bounce_tween.is_valid():
		bounce_tween.kill()
	var start_pos: Vector2 = _rest_position()
	visual_arrow.position = start_pos
	var away: Vector2 = Vector2(0.0, BOUNCE_DISTANCE if _pointing_up else -BOUNCE_DISTANCE)
	bounce_tween = create_tween().set_loops()
	bounce_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce_tween.tween_property(visual_arrow, "position", start_pos + away, BOUNCE_LEG_SECONDS)
	bounce_tween.tween_property(visual_arrow, "position", start_pos, BOUNCE_LEG_SECONDS)
