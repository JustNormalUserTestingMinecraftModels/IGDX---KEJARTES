@tool
extends Sprite2D
class_name ShuttlecockSprite

## The badminton shuttle's look: its resting pose, the swell when a racket
## hits it, and the half-turn that keeps the cork leading the flight.
##
## The physics body (Badminton.tscn's Puck) never rotates or scales for a
## hit; everything the player sees move lives here, on the Sprite2D. Every
## tween below animates towards a value this script REMEMBERS, never towards
## one read back off the live node: the old hit punch read the current,
## possibly mid-punch scale as its resting size, so overlapping hits ratcheted
## the shuttle bigger and bigger (fixed 2026-09-10).
##
## The authored pose is the truth. Whatever scale and rotation the scene gives
## this sprite are its rest scale and its cork-up angle. puck.png draws the
## cork on the LEFT, so the scene turns it 90 degrees clockwise to stand it
## up; re-aligning replacement art is an editor rotate, not a code change.
##
## @tool so the editor-hosted test runner can drive it. _ready() touches
## nothing but this node's own remembered pose.

## How much the shuttle swells on a racket hit, as a multiple of its rest scale.
@export var punch_scale: float = 1.6
## Seconds to swell out, and again to settle back; a punch lasts twice this.
@export var punch_half_duration: float = 0.26
## Seconds for the half-turn after a hit reverses the shuttle's direction.
@export var turn_duration: float = 0.18

var _rest_scale: Vector2 = Vector2.ONE
var _cork_up_degrees: float = 0.0
var _cork_up: bool = true
## Where the running (or last) turn is headed, in degrees. Grows by 180 per
## turn, so a turn interrupted mid-way still has an exact target.
var _target_degrees: float = 0.0
var _punch_tween: Tween = null
var _turn_tween: Tween = null


func _ready() -> void:
	_rest_scale = scale
	_cork_up_degrees = rotation_degrees
	_target_degrees = rotation_degrees
	_cork_up = true


## The scale the shuttle settles back to after every punch.
func rest_scale() -> Vector2:
	return _rest_scale


## True while the cork points up the screen.
func is_cork_up() -> bool:
	return _cork_up


## Swell and settle, starting over if a punch is already running. Always ends
## exactly at the rest scale, however many punches overlap.
func punch() -> void:
	_kill(_punch_tween)
	_punch_tween = create_tween()
	_punch_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_punch_tween.tween_property(self, "scale", _rest_scale * punch_scale, punch_half_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", _rest_scale, punch_half_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Point the cork the way the shuttle is flying: up for a negative
## `velocity_y`, down otherwise. Turns half a circle only when that direction
## changed, and always towards an exact target angle.
func face(velocity_y: float) -> void:
	var going_up := velocity_y < 0.0
	if going_up == _cork_up:
		return
	_cork_up = going_up
	_target_degrees += 180.0
	_kill(_turn_tween)
	_turn_tween = create_tween()
	_turn_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_turn_tween.tween_property(self, "rotation_degrees", _target_degrees, turn_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Snap to the rest scale and to cork-up or cork-down, with no animation.
## Called on every serve, while the puck teleports to its serve spot.
func reset_pose(cork_up: bool) -> void:
	_kill(_punch_tween)
	_kill(_turn_tween)
	scale = _rest_scale
	_cork_up = cork_up
	_target_degrees = _cork_up_degrees if cork_up else _cork_up_degrees + 180.0
	rotation_degrees = _target_degrees


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
