@tool
class_name CloudDrift
extends Control

## The SchoolDay sky's cloud layer (2026-09-30). The artist split the sky
## into two paintings: the gradient, which BookClockWidget turns once a day,
## and the clouds, one square painting on transparency (Clouds, this node's
## child), sized and pivoted exactly like the sky by BookClockWidget.
##
## The clouds ride with the sky -- BookClockWidget hands every sky angle to
## follow_sky() -- so the painted sunset clouds stay over the sunset and the
## white ones over noon. On top of that they creep slowly on their own clock,
## so they are never dead still, even while the day waits on an event. The
## creep turns back at max_drift_degrees: left unbounded, a day screen idling
## on "tap to continue" walked the clouds right out of register again.
## reset_drift() puts them back in register; BookClockWidget calls it at each
## new day, which starts under the full night. An own-clock spin with no ride
## was built first and dropped the same day: the sky turns a full circle in a
## few seconds of play, so by midday the dusk clouds hung over the noon sky.
## This replaced three SVG clouds that slid sideways (2026-09-24 pass); it
## sits behind the sun and moon, which it would otherwise all but hide.
##
## The creep runs in the game only, unless preview_in_editor is on, and never
## under GameSettings.reduce_motion. Before a scene save the creep is cleared,
## so a save never bakes an angle. BookClockWidget.set_night() darkens this
## layer at night.

## How fast the clouds creep on top of the sky, degrees per second. Negative
## turns counter-clockwise, the sky's own direction; 0 stops the creep and
## leaves the clouds riding the sky alone.
@export_range(-30.0, 30.0, 0.1) var spin_degrees_per_second: float = -2.0
## The furthest the clouds creep from the sky's own angle, degrees, before
## they turn back -- so however long a day idles, the painted colours stay
## near the sky they were painted for. 0 lets them creep without limit.
@export_range(0.0, 90.0, 0.5) var max_drift_degrees: float = 24.0
## Opacity of the whole cloud layer, so it can sit back into the sky.
@export_range(0.0, 1.0, 0.01) var base_opacity: float = 0.85:
	set(value):
		base_opacity = value
		_apply_opacity()
## Creeps the clouds in the editor viewport too, to judge the speed. The
## creep is cleared before every save.
@export var preview_in_editor: bool = false:
	set(value):
		preview_in_editor = value
		if not value:
			reset_drift()

## The sky's angle, as last handed in by follow_sky().
var _sky_degrees := 0.0
## How far the clouds have crept past the sky, degrees.
var _drift_degrees := 0.0
## Degrees of creep travelled since the last reset, never negative; the drift
## is this folded back and forth inside max_drift_degrees.
var _travel_degrees := 0.0


func _ready() -> void:
	_apply_opacity()


func _apply_opacity() -> void:
	for cloud in get_children():
		if cloud is CanvasItem:
			(cloud as CanvasItem).modulate.a = base_opacity


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or GameSettings.reduce_motion:
		if Engine.is_editor_hint() and preview_in_editor:
			step(delta)
		return
	step(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		reset_drift()


## Sets the angle the clouds ride on: the sky's, in degrees.
func follow_sky(sky_degrees: float) -> void:
	_sky_degrees = sky_degrees
	_apply_rotation()


## Creeps the clouds on by `delta` seconds. Public so the suite can drive it.
func step(delta: float) -> void:
	_travel_degrees += absf(spin_degrees_per_second) * delta
	var reach := _travel_degrees
	if max_drift_degrees > 0.0:
		reach = pingpong(_travel_degrees, max_drift_degrees)
	_drift_degrees = reach * signf(spin_degrees_per_second)
	_apply_rotation()


## Puts the clouds back in register with the sky.
func reset_drift() -> void:
	_travel_degrees = 0.0
	_drift_degrees = 0.0
	_apply_rotation()


## How far the clouds have crept past the sky, degrees.
func drift_degrees() -> float:
	return _drift_degrees


func _apply_rotation() -> void:
	for cloud in get_children():
		if cloud is Control:
			(cloud as Control).rotation_degrees = _sky_degrees + _drift_degrees
