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
## Since 2026-09-21 it also carries the header the player reads the day from:
## a day banner and a calendar badge, authored in the .tscn as a mirror of
## EventDialogue's -- same DayBannerPanel / DayBannerLabel / CalendarLabel
## variations, same "%d/%d" week format, fed from the same two GameState
## values, so the two screens cannot disagree. set_day() used to record the
## weekday and display nothing; set_week() is its partner.
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

## The banner Label carrying the weekday, and the Label carrying "3/6" on the
## calendar badge. Both are authored in this widget's .tscn, mirroring
## EventDialogue's header so the two screens read identically.
const DAY_LABEL_PATH := ^"Header/DayBanner/DayLabel"
const WEEK_LABEL_PATH := ^"Header/Calendar/Text/WeekLabel"

## The day banner, and the progress fill inside it (2026-09-24 liveliness
## pass). Track sits in the banner's content rect like DayLabel; Clip is
## pushed back out to the inside of the pill's rim and cut to the day's
## progress, so Fill (tinted by the day's category) and KnockoutLabel (the
## name's white twin) show only where the day has got to.
const DAY_BANNER_PATH := ^"Header/DayBanner"
const FILL_TRACK_PATH := ^"Header/DayBanner/Track"
const FILL_CLIP_PATH := ^"Header/DayBanner/Track/Clip"
const FILL_PATH := ^"Header/DayBanner/Track/Clip/Fill"
const MOTIF_PATH := ^"Header/DayBanner/Track/Clip/Fill/Motif"
const KNOCKOUT_PATH := ^"Header/DayBanner/Track/Clip/KnockoutLabel"
## The invisible bar SchoolDay's Juice.fill_bar() tweens. The day's progress
## lives here and the banner reads it, so the fill keeps the day's two-phase,
## event-in-the-middle pacing without SchoolDay knowing about the banner.
const PROGRESS_PATH := ^"Header/DayProgress"

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
## sky sweeps once across both. Tuned in motion-lab on 2026-09-10 for the
## full-turn day, alongside QUAD/OUT: 1.64s a phase, 3.28s a day (it was
## 2.0 for the old half turn).
##
## SchoolDay reads this to pace the day's progress bar across its two
## phases and the sky in a single sweep spanning both, so all three stay
## in lockstep -- changing it here changes how long a simulated school
## day takes on screen.
@export var transition_duration: float = 1.64
## When true, progress runs through smoothstep before it maps to an
## angle, so the sweep eases in and out even under a linear driver.
## Off since 2026-09-10: transition_to()'s tween eases OUT, and smoothstep
## underneath it would put the ease-in back.
@export var ease_in_out: bool = false:
	set(value):
		ease_in_out = value
		_apply_rotation()

@export_group("Banner")
## One motif per weekday, Senin to Jumat, tiled faintly across the banner's
## fill so each day looks different as it fills: grid, stripes, dots,
## zigzag, stars -- SimulationBackground's PatternType order.
@export var motif_textures: Array[Texture2D] = []

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
## "3/6" as the calendar badge shows it, or "" before a week is set.
var _week_text: String = ""


func _ready() -> void:
	_fit_layers()
	_apply_rotation()
	# Pure signal wiring, ungated so the suite can drive the fill.
	var bar := get_node_or_null(PROGRESS_PATH) as Range
	if bar != null and not bar.value_changed.is_connected(_on_day_progress_changed):
		bar.value_changed.connect(_on_day_progress_changed)
	var banner := get_node_or_null(DAY_BANNER_PATH) as Control
	if banner != null and not banner.resized.is_connected(layout_banner_fill):
		banner.resized.connect(layout_banner_fill)
	layout_banner_fill.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_layers()


# ── Public API ────────────────────────────────────────────────────────────────

## Writes the banner without moving the sky. The week's closing screen shows
## "Akhir Pekan" over an evening sky, so it must not rewind to morning.
func set_banner(text: String) -> void:
	_day_name = text
	_write_header()


## Starts a fresh day. Records the weekday, writes it to the banner and
## rewinds the sky to morning.
func set_day(day_name_in: String) -> void:
	set_banner(day_name_in)
	set_progress(0.0)


## The week this day belongs to, in EventDialogue's format: "3/6".
##
## max_weeks is grade-scaled (GameState.get_max_weeks() returns 6/12/16 for
## Kelas 7/8/9), so the same call reads 3/6 in Kelas 7 and 3/16 in Kelas 9
## with nothing here to change.
func set_week(week: int, max_weeks: int) -> void:
	_week_text = "%d/%d" % [week, max_weeks]
	_write_header()


## Places the sky for a point in the school day, 0.0 (morning) to 1.0
## (night). Applies the angle immediately rather than tweening it -- the
## caller owns the timing, and already eases it.
func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_apply_rotation()


## Tints the banner's fill with the day's colour and lays that weekday's motif
## over it. `weekday` is 0 for Senin; it wraps.
func set_day_style(tint: Color, weekday: int) -> void:
	var fill := get_node_or_null(FILL_PATH) as CanvasItem
	if fill != null:
		fill.self_modulate = tint
	var motif := get_node_or_null(MOTIF_PATH) as TextureRect
	if motif != null and not motif_textures.is_empty():
		motif.texture = motif_textures[posmod(weekday, motif_textures.size())]


## The Range whose value (0-100) is the banner's fill. SchoolDay tweens it.
func day_progress_bar() -> Range:
	return get_node_or_null(PROGRESS_PATH) as Range


## How much of the banner is filled, 0.0 to 1.0.
func fill_ratio() -> float:
	var bar := day_progress_bar()
	return bar.get_as_ratio() if bar != null else 0.0


## Rewinds to morning and clears the header.
func reset() -> void:
	_day_name = ""
	_week_text = ""
	_write_header()
	set_progress(0.0)


## The weekday currently being simulated, as handed in by set_day().
func day_name() -> String:
	return _day_name


## What the banner reads. Exists so tests need not know node paths.
func day_text() -> String:
	var label := get_node_or_null(DAY_LABEL_PATH) as Label
	return label.text if label != null else ""


## What the calendar badge reads.
func week_text() -> String:
	var label := get_node_or_null(WEEK_LABEL_PATH) as Label
	return label.text if label != null else ""


## Pushes both strings into the authored Labels. Missing nodes are ignored
## rather than erroring: the widget is instanced bare in tests and previewed
## in the editor, and a half-built scene must not take the day cinematic
## down with it.
func _write_header() -> void:
	var day_label := get_node_or_null(DAY_LABEL_PATH) as Label
	if day_label != null:
		day_label.text = _day_name
	var knockout := get_node_or_null(KNOCKOUT_PATH) as Label
	if knockout != null:
		knockout.text = _day_name
	var week_label := get_node_or_null(WEEK_LABEL_PATH) as Label
	if week_label != null:
		week_label.text = _week_text


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
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


# ── Internals ─────────────────────────────────────────────────────────────────

func _on_day_progress_changed(_value: float) -> void:
	layout_banner_fill()


## Places the fill for the current progress. The banner is a PanelContainer,
## which pins Track and DayLabel to its content rect -- inset far on the left
## where the calendar badge overlaps. So Clip is positioned back out to the
## inside of the pill's rim, measured from the banner's own stylebox rather
## than restated here, and cut to the progress; Fill spans the whole inner
## pill so its rounded left end stays put while the right edge advances; and
## the knockout name is laid exactly over DayLabel. Public so the suite can
## lay it out without waiting a frame.
func layout_banner_fill() -> void:
	var banner := get_node_or_null(DAY_BANNER_PATH) as Control
	var track := get_node_or_null(FILL_TRACK_PATH) as Control
	var clip := get_node_or_null(FILL_CLIP_PATH) as Control
	if banner == null or track == null or clip == null:
		return
	var rim := Rect2(Vector2.ZERO, banner.size)
	var box := banner.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		rim = rim.grow_individual(-flat.border_width_left, -flat.border_width_top,
			-flat.border_width_right, -flat.border_width_bottom)
	var ratio := fill_ratio()
	clip.position = rim.position - track.position
	clip.size = Vector2(rim.size.x * ratio, rim.size.y)
	var fill := get_node_or_null(FILL_PATH) as Control
	if fill != null:
		fill.position = Vector2.ZERO
		fill.size = rim.size
	var knockout := get_node_or_null(KNOCKOUT_PATH) as Control
	var day_label := get_node_or_null(DAY_LABEL_PATH) as Control
	if knockout != null and day_label != null:
		knockout.position = day_label.position - rim.position
		knockout.size = day_label.size


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
