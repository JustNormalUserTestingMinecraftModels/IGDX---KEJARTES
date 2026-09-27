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

## The sun and moon (2026-09-24 liveliness pass, layer 4). They are placed
## from the same progress that turns the sky, inside set_progress(), so they
## rise and set with the sweep and have no timer of their own to drift. They
## are not the sky's children: the sky turns a full circle a day, so a body
## fixed to it crossed the 1080-wide screen in a fraction of a second. They
## travel a visible arc instead -- the sun from the right horizon, overhead
## at midday, down to the left; the moon the same arc half a day out, so it
## is up in the dark at dawn and evening. They sit under the school, which
## hides them as they set.
const SUN_PATH := ^"SkyBodies/Sun"
const MOON_PATH := ^"SkyBodies/Moon"
## The night beat's layers, faded together by set_night(): a blue tint over
## the sky, a star field and the moon above it, the drifting clouds dimmed,
## the school darkened to a silhouette, and its windows lit warm. SchoolNight and WindowGlow are full-frame images fitted
## exactly like SchoolForeground, so the windows stay on the painting at any
## aspect ratio.
const NIGHT_TINT_PATH := ^"NightTint"
const STARS_PATH := ^"Stars"
const SCHOOL_NIGHT_PATH := ^"SchoolNight"
const WINDOW_GLOW_PATH := ^"WindowGlow"
const CLOUD_LAYER_PATH := ^"CloudLayer"
## Width of one repeat of the motif tiles, px: the drift wraps every this
## many so it never jumps. The Motif node runs this much past the fill's right
## edge to cover the shift.
const MOTIF_PERIOD := 48.0

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

@export_group("Sky bodies")
## The day progress (0-1) at which the sun clears the right horizon and
## sinks below the left one. The moon runs the same arc half a day out.
@export var sun_rise_progress: float = 0.12:
	set(value):
		sun_rise_progress = value
		_place_bodies()
## See sun_rise_progress.
@export var sun_set_progress: float = 0.88:
	set(value):
		sun_set_progress = value
		_place_bodies()
## The moon's own rise and set, as progress through ITS half of the day --
## the day shifted by half, so 0.5 is dawn and evening. Narrower than the
## sun's, so the moon shows only in the dark and is not up in the afternoon
## beside the sun.
@export var moon_rise_progress: float = 0.3:
	set(value):
		moon_rise_progress = value
		_place_bodies()
## See moon_rise_progress.
@export var moon_set_progress: float = 0.7:
	set(value):
		moon_set_progress = value
		_place_bodies()
## Where the arc's horizon sits, as a fraction of the widget's height. The
## school's roofline is about 0.74; below it the painted school hides a body.
@export_range(0.0, 1.0, 0.01) var horizon_ratio: float = 0.8:
	set(value):
		horizon_ratio = value
		_place_bodies()
## Half the arc's width and its height, as fractions of the widget's width
## and height. 0.4 wide keeps a body on the 1080 screen for most of the arc;
## 0.55 tall puts the midday sun just under the status strip.
@export var arc_radius_ratio: Vector2 = Vector2(0.4, 0.55):
	set(value):
		arc_radius_ratio = value
		_place_bodies()

@export_group("Night")
## How dark the school gets at full night, 0-1: the alpha of its navy
## silhouette over the painted building.
@export_range(0.0, 1.0, 0.01) var school_night_strength: float = 0.6
## How much the drifting clouds darken at full night, 0-1. They sit above
## the tint so the moon can shine through it, so they dim themselves.
@export_range(0.0, 1.0, 0.01) var night_cloud_dim: float = 0.6
## Seconds the night takes to fall, and to lift again into dawn.
@export_range(0.05, 2.0, 0.05) var night_fade_seconds: float = 0.35

@export_group("Idle motion")
## How far the day banner bobs, px, so the day's name is never dead still.
## 0 stops it.
@export_range(0.0, 20.0, 0.5) var banner_bob_px: float = 4.0
## Seconds for one bob of the banner, down and back.
@export_range(0.5, 8.0, 0.1) var banner_bob_seconds: float = 2.6
## How fast the weekday motif drifts along the banner's fill, px per second
## -- the fill's "breathing" as the day runs.
@export_range(0.0, 120.0, 1.0) var motif_drift_speed: float = 16.0

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
## How deep into night the sky is, 0 (day) to 1 (the night beat's peak).
var _night: float = 0.0
## Seconds of idle motion so far, and where the banner rests before it bobs.
var _idle_time := 0.0
var _banner_rest_y := NAN


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


## The banner's idle bob and the fill motif's drift. Game only: in the editor
## a scene save would bake wherever they happened to be. Stopped under
## reduce_motion.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or GameSettings.reduce_motion:
		return
	_idle_time += delta
	var banner := get_node_or_null(DAY_BANNER_PATH) as Control
	if banner != null and banner_bob_seconds > 0.0:
		if is_nan(_banner_rest_y):
			_banner_rest_y = banner.position.y
		banner.position.y = _banner_rest_y + sin(_idle_time * TAU / banner_bob_seconds) * banner_bob_px
	var motif := get_node_or_null(MOTIF_PATH) as Control
	if motif != null:
		motif.position.x = -fposmod(_idle_time * motif_drift_speed, MOTIF_PERIOD)


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
	_place_bodies()


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


## Sets how deep into night the scene is, 0 to 1, fading the tint, stars,
## darkened school and lit windows together. Applied at once; night_in() and
## night_out() are the animated forms.
func set_night(amount: float) -> void:
	_night = clampf(amount, 0.0, 1.0)
	for path in [NIGHT_TINT_PATH, STARS_PATH, WINDOW_GLOW_PATH]:
		var layer := get_node_or_null(path) as CanvasItem
		if layer != null:
			layer.modulate.a = _night
	var school := get_node_or_null(SCHOOL_NIGHT_PATH) as CanvasItem
	if school != null:
		school.modulate.a = _night * school_night_strength
	var clouds := get_node_or_null(CLOUD_LAYER_PATH) as CanvasItem
	if clouds != null:
		clouds.modulate = Color.WHITE.darkened(night_cloud_dim * _night)


## How deep into night the scene is now.
func night() -> float:
	return _night


## Lets night fall over night_fade_seconds (the deep-night beat between
## school days) and hands the Tween back so the caller can await it.
func night_in() -> Tween:
	return _tween_night(1.0)


## Lifts the night again, into the next day's dawn.
func night_out() -> Tween:
	return _tween_night(0.0)


func _tween_night(target: float) -> Tween:
	var tween := create_tween()
	tween.tween_method(set_night, _night, target, night_fade_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


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


## Where a body stands on its arc at arc position `t` (0 = rising at the
## right horizon, 1 = setting at the left), in this widget's coordinates.
func body_point(t: float) -> Vector2:
	var theta := lerpf(0.0, PI, t)
	var centre := Vector2(size.x * 0.5, size.y * horizon_ratio)
	return centre + Vector2(cos(theta) * size.x * arc_radius_ratio.x,
		-sin(theta) * size.y * arc_radius_ratio.y)


## How far along its arc the sun is for day progress `p`: 0 at sunrise, 1 at
## sunset, outside that range when it is down.
func sun_arc(p: float) -> float:
	return inverse_lerp(sun_rise_progress, sun_set_progress, p)


## The moon's arc position: half a day out from the sun, over its own
## narrower window, so it is overhead at dawn and evening.
func moon_arc(p: float) -> float:
	return inverse_lerp(moon_rise_progress, moon_set_progress, fposmod(p + 0.5, 1.0))


## Puts the sun and moon on their arcs for the current progress, and hides
## whichever is down.
func _place_bodies() -> void:
	for pair in [[SUN_PATH, sun_arc(_progress)], [MOON_PATH, moon_arc(_progress)]]:
		var body := get_node_or_null(pair[0]) as Control
		if body == null:
			continue
		var t: float = pair[1]
		body.visible = t > 0.0 and t < 1.0
		body.position = body_point(clampf(t, 0.0, 1.0)) - body.size * 0.5


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
	# The night's school silhouette and lit windows are the foreground's twins
	# and must cover exactly the same rect, or the windows slide off the
	# painting on a tall phone.
	for path in [SCHOOL_NIGHT_PATH, WINDOW_GLOW_PATH]:
		var twin := get_node_or_null(path) as Control
		if twin != null:
			twin.position = Vector2.ZERO
			twin.size = rect

	_place_bodies()
