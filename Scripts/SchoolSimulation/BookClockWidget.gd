@tool
extends Control
class_name BookClockWidget

## The day-passing cinematic behind the SchoolDay screen.
##
## Two full-screen layers: a square sky texture that rotates about a
## pivot near the bottom of the screen, and a stationary school-on-a-hill
## foreground painted over it. As the school day advances, set_progress()
## turns the sky one full circle -- from the dark of dawn, through sunrise
## and the bright midday, back round to the dark of evening -- and the whole
## screen reads as one day passing.
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
## Pivot: the mechanism mockup marks its rotation point (a blue dot) at
## the bottom-centre of the visible frame, not the frame's middle -- the
## sky's own vortex art converges there, at the school's ground line,
## rather than at screen-centre. See sky_pivot_ratio.
##
## @tool, so the composited cinematic previews live in the editor
## viewport. Nothing in _ready() has a side effect outside this widget's
## own children, so it needs no Engine.is_editor_hint() gate.

## Child that holds the rotating sky. Task 3's scene must use this name.
const SKY_NODE := "SkyBackground"
## Child that holds the stationary school and hill.
const FOREGROUND_NODE := "SchoolForeground"

## The day's two resting poses, plus MIDDAY as the arc's midpoint -- the
## event still rolls there, but the sky no longer stops for it.
enum Phase { DAWN, MIDDAY, EVENING }

@export_group("Motion")
## The two angles the school day rests at, in degrees.
##
## The day was two deliberate transitions between three named poses from
## 2026-09-07, with the event pinned to the middle one; from 2026-09-10 it
## is one continuous sweep between these two poses, and the event still
## rolls at the midpoint but the sky no longer stops there. Later that day
## the sweep grew from a half turn to a full one, starting and ending on
## the darkest frame of the sky art.
##
## Godot's rotation is clockwise-positive with y down, so the
## counter-clockwise sweep the mechanism reference asks for runs toward
## NEGATIVE angles.

## The sky's angle at the start of the school day: still dark, just
## before sunrise.
##
## 60 is the same view as -300, the darkest frame of the sky art, picked
## from a 12-angle contact sheet of the real composite on 2026-09-10 --
## the old -90 opened the day half dark, half bright blue. Dawn sits one
## full turn above evening, so the day sweeps dark -> orange sunrise ->
## blue midday -> dusk -> dark, counter-clockwise (monotonically
## decreasing) as the mechanism reference asks. The poses were 0 / -180
## before 2026-09-07 and -90 / -270 until 2026-09-10; a third, midday pose
## sat between them until it was retired -- see current_rotation_degrees().
@export var dawn_rotation_degrees: float = 60.0:
	set(value):
		dawn_rotation_degrees = value
		_apply_rotation()
## The sky's angle when the school day ends: dark again, on the same frame
## the day started on, one full turn later.
@export var evening_rotation_degrees: float = -300.0:
	set(value):
		evening_rotation_degrees = value
		_apply_rotation()
## How long one phase of the school day takes, in seconds -- the day has
## two, dawn-to-midday and midday-to-evening, each this length, and the
## sky sweeps once across both. 2.0 was chosen in motion-lab on 2026-09-07
## for a half turn; the full turn of 2026-09-10 kept it, so the sky now
## spins twice as fast -- retune it in motion-lab alongside the ease.
##
## SchoolDay reads this to pace the day's progress bar across its two
## phases and the sky in a single sweep spanning both, so all three stay
## in lockstep -- changing it here changes how long a simulated school
## day takes on screen.
@export var transition_duration: float = 2.0
## When true, progress runs through smoothstep before it maps to an
## angle, so the sweep eases in and out even under a linear driver.
## Off since 2026-09-10: transition_to()'s tween eases OUT, and smoothstep
## underneath it would put the ease-in back.
@export var ease_in_out: bool = false:
	set(value):
		ease_in_out = value
		_apply_rotation()

@export_group("Layout")
## Where the sky's rotation pivot sits, as a fraction of the widget's own
## size (0,0 = top-left, 1,1 = bottom-right). The mechanism mockup's blue
## dot marks this at the screen's bottom-centre, Vector2(0.5, 1.0): the
## sky's vortex "eye" sits at the school's ground line rather than the
## screen's geometric middle, so the sky reads as wheeling overhead
## while the ground stays put.
@export var sky_pivot_ratio: Vector2 = Vector2(0.5, 1.0):
	set(value):
		sky_pivot_ratio = value
		_fit_layers()
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
##
## One straight lerp between the day's two poses. This was piecewise
## through a third, separately authored midday angle until 2026-09-10;
## the middle of the day is now the middle of the arc by construction.
func current_rotation_degrees() -> float:
	return lerpf(dawn_rotation_degrees, evening_rotation_degrees, eased_progress())


## The angle one phase rests at. MIDDAY has no authored angle of its own
## any more -- it is simply the arc's midpoint.
func angle_for_phase(phase: Phase) -> float:
	match phase:
		Phase.MIDDAY:
			return lerpf(dawn_rotation_degrees, evening_rotation_degrees, 0.5)
		Phase.EVENING:
			return evening_rotation_degrees
		_:
			return dawn_rotation_degrees


## The raw progress value one phase sits at.
func progress_for_phase(phase: Phase) -> float:
	match phase:
		Phase.MIDDAY:
			return 0.5
		Phase.EVENING:
			return 1.0
		_:
			return 0.0


## Snaps the sky to one pose, with no animation.
func set_phase(phase: Phase) -> void:
	set_progress(progress_for_phase(phase))


## Sweeps the sky to one pose and hands the Tween back, so the caller can
## await it and line the rest of the screen up with the sweep.
##
## The easing lives here rather than at the call site so there is exactly
## one place to tune how a transition feels. Pass a negative duration to
## take transition_duration.
func transition_to(phase: Phase, duration: float = -1.0) -> Tween:
	var seconds: float = transition_duration if duration < 0.0 else duration
	var tween := create_tween()
	tween.tween_method(set_progress, _progress, progress_for_phase(phase), seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


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
## The sky is a square CENTRED ON THE PIVOT (sky_pivot_ratio), not on the
## screen -- rotating a square about its own centre leaves its inscribed
## circle (radius = side / 2) untouched at every angle, so that circle is
## exactly the region guaranteed to stay covered. To cover the whole
## screen from an off-centre pivot, the inscribed circle must reach the
## screen's FARTHEST corner from that pivot, not the nearest: for the
## default bottom-centre pivot on the project's 1080x1920, the far
## corners are the top two, ~1994 px away, so the square ends up ~4069 px
## (2 x 1994 x margin) from a 1600 px source -- about 2.5x, noticeably
## more zoomed than a centre pivot's 1.38x. That is the tradeoff of
## anchoring the sky's vortex at the school's ground line instead of
## screen-centre; the art is drawn loose enough to take it.
func _fit_layers() -> void:
	var rect := size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return

	var sky := _sky_layer()
	if sky != null:
		var pivot_point: Vector2 = rect * sky_pivot_ratio
		var farthest_corner_distance: float = 0.0
		for corner in [Vector2.ZERO, Vector2(rect.x, 0.0), Vector2(0.0, rect.y), rect]:
			farthest_corner_distance = maxf(farthest_corner_distance, pivot_point.distance_to(corner))
		var side: float = farthest_corner_distance * 2.0 * sky_cover_margin
		sky.size = Vector2(side, side)
		sky.position = pivot_point - sky.size * 0.5
		sky.pivot_offset = sky.size * 0.5

	var foreground := _foreground_layer()
	if foreground != null:
		foreground.position = Vector2.ZERO
		foreground.size = rect
