@tool
extends Control
class_name BookClockWidget

## The day-passing cinematic behind the SchoolDay screen.
##
## Two full-screen layers: a square sky texture that rotates about the
## screen centre, and a stationary school-on-a-hill foreground painted
## over it. As the school day advances, set_progress() turns the sky so
## the bright half sweeps away and the night half swings in, and the
## whole screen reads as one day passing.
##
## This file used to draw a procedural cat pocket-watch. It no longer
## draws anything: both layers are authored TextureRects in the scene,
## and all this script does is responsive geometry plus the
## progress-to-rotation mapping. The name and the public API
## (set_day / set_progress / reset) are unchanged so SchoolDay.gd drives
## it exactly as before.
##
## Direction: Godot's rotation is clockwise-positive with y down, so the
## counter-clockwise sweep the mechanism reference asks for runs from 0
## to a NEGATIVE angle. See docs/superpowers/mockups/
## day-transition-mechanism.png.
##
## @tool, so the composited cinematic previews live in the editor
## viewport. Nothing in _ready() has a side effect outside this widget's
## own children, so it needs no Engine.is_editor_hint() gate.

## Child that holds the rotating sky. Task 3's scene must use this name.
const SKY_NODE := "SkyBackground"
## Child that holds the stationary school and hill.
const FOREGROUND_NODE := "SchoolForeground"

@export_group("Motion")
## The sky's angle at progress 0.0, in degrees -- its "morning" pose.
@export var start_rotation_degrees: float = 0.0:
	set(value):
		start_rotation_degrees = value
		_apply_rotation()
## Degrees swept across one whole school day. Negative turns the sky
## counter-clockwise on screen, which is the direction the mechanism
## reference's arrows describe. -180 carries the bright half of the sky
## all the way across and brings the night half down in its place.
@export var total_rotation_degrees: float = -180.0:
	set(value):
		total_rotation_degrees = value
		_apply_rotation()
## When true, progress runs through smoothstep before it maps to an
## angle, so the sweep eases in and out even under a linear driver.
## SchoolDay.gd also eases its own tween; the two compose harmlessly.
@export var ease_in_out: bool = true:
	set(value):
		ease_in_out = value
		_apply_rotation()

@export_group("Layout")
## Slack multiplied into the sky's cover size. The maths already covers
## the screen exactly; this absorbs rounding on odd aspect ratios so a
## corner of the page can never flash through mid-rotation.
@export var sky_cover_margin: float = 1.02:
	set(value):
		sky_cover_margin = value
		_fit_layers()

# ── Internal state ────────────────────────────────────────────────────────────
var _progress: float = 0.0
var _day_name: String = ""


func _ready() -> void:
	_fit_layers()
	_apply_rotation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_layers()


# ── Public API ────────────────────────────────────────────────────────────────

## Starts a fresh day. Records the weekday and rewinds the sky to morning.
func set_day(day_name_in: String) -> void:
	_day_name = day_name_in
	set_progress(0.0)


## Places the sky for a point in the school day, 0.0 (morning) to 1.0
## (night). Applies the angle immediately rather than tweening it -- the
## caller owns the timing, and already eases it.
func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_apply_rotation()


## Rewinds to morning and forgets the weekday.
func reset() -> void:
	_day_name = ""
	set_progress(0.0)


## The weekday currently being simulated, as handed in by set_day().
func day_name() -> String:
	return _day_name


## Raw progress through the day, 0.0 to 1.0, before easing.
func progress() -> float:
	return _progress


## Progress after the easing curve -- what actually drives the angle.
func eased_progress() -> float:
	if ease_in_out:
		return smoothstep(0.0, 1.0, _progress)
	return _progress


## The sky's angle, in degrees, for the current progress.
func current_rotation_degrees() -> float:
	return start_rotation_degrees + eased_progress() * total_rotation_degrees


# ── Internals ─────────────────────────────────────────────────────────────────

func _sky_layer() -> TextureRect:
	return get_node_or_null(SKY_NODE) as TextureRect


func _foreground_layer() -> TextureRect:
	return get_node_or_null(FOREGROUND_NODE) as TextureRect


func _apply_rotation() -> void:
	var sky := _sky_layer()
	if sky != null:
		sky.rotation_degrees = current_rotation_degrees()


## Sizes and centres both layers for the current control rect.
##
## The sky is grown to a square whose side equals the screen's diagonal.
## That makes its INSCRIBED circle reach the screen's corners, and the
## inscribed circle is exactly the region a rotating square is guaranteed
## to keep covered -- so no corner can ever swing into view. At the
## project's 1080x1920 that is a 2203 px square from a 1600 px source,
## i.e. about 1.38x, which the art is drawn loose enough to take.
func _fit_layers() -> void:
	var rect := size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return

	var sky := _sky_layer()
	if sky != null:
		var side: float = rect.length() * sky_cover_margin
		sky.size = Vector2(side, side)
		sky.position = (rect - sky.size) * 0.5
		sky.pivot_offset = sky.size * 0.5

	var foreground := _foreground_layer()
	if foreground != null:
		foreground.position = Vector2.ZERO
		foreground.size = rect
