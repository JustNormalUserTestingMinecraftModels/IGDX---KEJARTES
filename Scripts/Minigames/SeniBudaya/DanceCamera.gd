@tool
extends RefCounted

## LombaMenari's Friday Night Funkin' note camera: where the stage camera is
## looking, relative to centre, in design pixels.
##
## A successful arrow calls lean() -- the camera eases toward that offset,
## holds it for a beat, then drifts home. recenter() sends it home at once,
## for a miss. step() advances one frame and returns the new offset.
##
## Pure logic, no nodes: LombaMenari owns one and slides its stage (backdrop
## and dancer) by -offset, as the world slides under a panning camera. @tool
## so tests/test_dance_camera.gd can drive it inside the editor.
##
## Affects: nothing by itself.

## Where the camera looks now, relative to centre. +x is right, +y is down.
var offset: Vector2 = Vector2.ZERO
## Where the camera is easing toward.
var _target: Vector2 = Vector2.ZERO
## Seconds left before _target returns to centre.
var _hold_left: float = 0.0


## Lean toward `target` and hold it for `hold` seconds. A new lean replaces
## the last one outright and restarts the hold.
func lean(target: Vector2, hold: float) -> void:
	_target = target
	_hold_left = hold


## Head home now, whatever was left of the hold.
func recenter() -> void:
	_target = Vector2.ZERO
	_hold_left = 0.0


## Advance one frame of `delta` seconds at `follow_speed` (see follow()) and
## return the new offset.
func step(delta: float, follow_speed: float) -> Vector2:
	if _hold_left > 0.0:
		_hold_left -= delta
		if _hold_left <= 0.0:
			_target = Vector2.ZERO
	offset = follow(offset, _target, follow_speed, delta)
	return offset


## One frame of exponential follow: every second closes the same share of the
## gap, 1 - e^-speed, whatever the frame rate, and a long frame lands on the
## target rather than past it. The frame-rate-safe form of FNF's
## `lerp(camera, target, speed * elapsed)`.
##
## Affects: nothing. Pure.
static func follow(current: Vector2, target: Vector2, speed: float, delta: float) -> Vector2:
	return current.lerp(target, 1.0 - exp(-speed * delta))
