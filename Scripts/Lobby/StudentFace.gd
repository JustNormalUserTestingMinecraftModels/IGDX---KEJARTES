@tool
class_name StudentFace
extends Control

## A multi-layer student face for the lobby diorama, in place of the single
## flat portrait TextureRect.
##
## The art is authored on a fixed square canvas (1280x1280 for Citra) and every
## layer is a TextureRect placed at its own canvas pixel offset in the rig's
## .tscn -- nothing here is built at runtime. This script only does the two
## things a .tscn cannot express: it scales that canvas to fit whatever rect
## the roster slot gives it (matching the flat portrait's
## STRETCH_KEEP_ASPECT_CENTERED so the diorama layout is unchanged), and it
## drives the idle motion.
##
## Layer order, back to front: Base, Sclera, Pupil, Eyelashes, Eyelid,
## Eyebrows. Eyebrows are drawn last on purpose -- they sit over the fringe,
## and the base has hair, not brows, underneath them. Eyelid is the closed-eye
## pose and is the one layer that starts hidden.
##
## Idle motion is two independent parts:
##  * Gaze -- the Pupil layer saccades to a new point inside a small ellipse,
##    holds, and jumps again. The pupil is clipped to the Sclera's alpha by
##    Scripts/Shaders/eye_mask.gdshader, so a gaze offset can never paint the
##    iris onto the cheek however far it travels.
##  * Blink -- the Eyelid layer appears for a few frames, hiding the eye
##    beneath it. Wired but idle-off by default: see idle_blink_enabled.
##
## Breathing is NOT here. It stays the lobby's job (loby.gd's
## _animate_breathing), which scales this node as a whole exactly as it scaled
## the flat portrait it replaces.
##
## Must be @tool so the canvas fit previews in the editor viewport and so the
## test runner can instantiate the rig live. _process() is the only real side
## effect and it is disabled under Engine.is_editor_hint(); tests step the
## motion synchronously through advance_motion() instead.

## Canvas path relative to this node. Its children are the layers, positioned
## in canvas pixels.
const CANVAS_PATH := ^"Canvas"
## Layer node names under the canvas, back to front.
const LAYER_NAMES := ["Base", "Sclera", "Pupil", "Eyelashes", "Eyelid", "Eyebrows"]

@export_group("Identity")
## Roster name this rig belongs to, e.g. "Citra". loby.gd matches a rig to a
## student slot on this, case-insensitively; leave empty and the rig is never
## picked automatically.
@export var student_name: String = ""

@export_group("Canvas")
## Size of the square the artist drew on, in art pixels. Every layer's
## position and size in this rig's .tscn is in these coordinates; the whole
## canvas is then scaled to fit the slot.
@export var canvas_size: Vector2i = Vector2i(1280, 1280)

@export_group("Idle Gaze")
## Set false to freeze the pupil at its authored resting position.
@export var idle_gaze_enabled: bool = true
## Peak pupil travel from rest, in canvas pixels: x sideways, y up/down.
## Targets are drawn from the ellipse these two describe.
@export var gaze_range: Vector2 = Vector2(20.0, 7.0)
## How long one saccade takes, in seconds. Real eyes snap, so keep it short.
@export var gaze_move_duration: float = 0.13
## Shortest and longest pause between saccades, in seconds.
@export var gaze_hold_range: Vector2 = Vector2(1.4, 4.2)
## Odds that a given saccade returns to the resting centre instead of picking
## a fresh point, so the gaze does not drift around the rim forever.
@export_range(0.0, 1.0) var gaze_recentre_chance: float = 0.35

@export_group("Blink")
## Idle blinking is off by default: the Eyelid layer is wired into the rig and
## blink() works, but nothing triggers it on its own until this is switched on.
@export var idle_blink_enabled: bool = false
## How long the eyes stay shut per blink, in seconds.
@export var blink_close_seconds: float = 0.08
## Shortest and longest pause between idle blinks, in seconds.
@export var blink_hold_range: Vector2 = Vector2(2.6, 6.4)

@export_group("Determinism")
## Seed for this rig's own motion RNG. 0 randomises, so four slots on screen
## never blink or glance in lockstep; any other value makes the motion
## repeatable, which is what the tests use.
@export var motion_seed: int = 0

var _canvas: Control
var _layers: Dictionary = {}
var _pupil_home: Vector2 = Vector2.ZERO
var _pupil_home_valid: bool = false
var _rng := RandomNumberGenerator.new()

var _gaze: Vector2 = Vector2.ZERO
var _gaze_from: Vector2 = Vector2.ZERO
var _gaze_to: Vector2 = Vector2.ZERO
var _gaze_elapsed: float = 0.0
var _gaze_hold: float = 0.0

var _blink_remaining: float = 0.0
var _blink_hold: float = 0.0


func _ready() -> void:
	if motion_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = motion_seed
	_gaze_hold = _rng.randf_range(gaze_hold_range.x, gaze_hold_range.y)
	_blink_hold = _rng.randf_range(blink_hold_range.x, blink_hold_range.y)
	set_eyes_closed(false)
	fit_canvas()
	_sync_pupil_mask()
	# The motion loop is the script's only real side effect, and an editor
	# preview should sit still: see the file header.
	set_process(not Engine.is_editor_hint())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		fit_canvas()


func _process(delta: float) -> void:
	advance_motion(delta)


## Node lookup that works before _ready and survives the editor rebuilding the
## instance, which plain @onready vars do not.
func _layer(layer_name: String) -> TextureRect:
	var cached: Variant = _layers.get(layer_name)
	if cached is TextureRect and is_instance_valid(cached):
		return cached
	var canvas := _canvas_node()
	if canvas == null:
		return null
	var node := canvas.get_node_or_null(NodePath(layer_name)) as TextureRect
	if node != null:
		_layers[layer_name] = node
	return node


func _canvas_node() -> Control:
	if not is_instance_valid(_canvas):
		_canvas = get_node_or_null(CANVAS_PATH) as Control
	return _canvas


## Scales the art canvas to fit this node's rect and centres it, which is what
## the flat portrait's STRETCH_KEEP_ASPECT_CENTERED did. Called on every
## resize so the rig tracks a slot the designer moves in the viewport.
func fit_canvas() -> void:
	var canvas := _canvas_node()
	if canvas == null:
		return
	var design := Vector2(canvas_size)
	if design.x <= 0.0 or design.y <= 0.0:
		return
	canvas.size = design
	canvas.pivot_offset = Vector2.ZERO
	var factor: float = minf(size.x / design.x, size.y / design.y)
	canvas.scale = Vector2(factor, factor)
	canvas.position = (size - design * factor) * 0.5


## Feeds eye_mask.gdshader the pupil's current rect relative to the sclera's,
## as ratios, so the clip holds at any canvas scale.
func _sync_pupil_mask() -> void:
	var pupil := _layer("Pupil")
	var sclera := _layer("Sclera")
	if pupil == null or sclera == null:
		return
	var mat := pupil.material as ShaderMaterial
	if mat == null:
		return
	var mask_size := sclera.size
	if mask_size.x <= 0.0 or mask_size.y <= 0.0:
		return
	mat.set_shader_parameter("mask_uv_offset",
		(pupil.position - sclera.position) / mask_size)
	mat.set_shader_parameter("mask_uv_scale", pupil.size / mask_size)


## The pupil's authored resting position, read once from the .tscn so a gaze
## offset is always measured from the art's own placement.
func _pupil_rest() -> Vector2:
	if not _pupil_home_valid:
		var pupil := _layer("Pupil")
		if pupil == null:
			return Vector2.ZERO
		_pupil_home = pupil.position
		_pupil_home_valid = true
	return _pupil_home


## Moves the pupil `offset` canvas pixels from rest and re-clips it.
func apply_gaze(offset: Vector2) -> void:
	_gaze = offset
	var pupil := _layer("Pupil")
	if pupil == null:
		return
	pupil.position = _pupil_rest() + offset
	_sync_pupil_mask()


## Where the pupil currently sits, in canvas pixels from rest.
func get_gaze() -> Vector2:
	return _gaze


## Shows or hides the blink pose. That is the Eyelid layer alone -- it carries
## both the lid and its own lash line, and it is drawn above the open eye, so
## nothing else has to be toggled with it.
func set_eyes_closed(closed: bool) -> void:
	var eyelid := _layer("Eyelid")
	if eyelid != null:
		eyelid.visible = closed


## True while the blink pose is showing.
func are_eyes_closed() -> bool:
	var eyelid := _layer("Eyelid")
	return eyelid != null and eyelid.visible


## Plays one blink. Nothing calls this on its own unless idle_blink_enabled is
## on -- it is the hook the lobby (or a future reaction) drives.
func blink() -> void:
	set_eyes_closed(true)
	_blink_remaining = maxf(blink_close_seconds, 0.0)


## Advances gaze and blink by `delta` seconds. _process() calls this every
## frame at runtime; tests call it directly, because the runner cannot await.
func advance_motion(delta: float) -> void:
	_advance_gaze(delta)
	_advance_blink(delta)


func _advance_gaze(delta: float) -> void:
	if not idle_gaze_enabled:
		return
	if _gaze_elapsed < gaze_move_duration:
		_gaze_elapsed += delta
		var k: float = clampf(_gaze_elapsed / maxf(gaze_move_duration, 0.0001), 0.0, 1.0)
		# Ease-out cubic: a saccade launches fast and settles, it does not
		# glide evenly from one point to the next.
		apply_gaze(_gaze_from.lerp(_gaze_to, 1.0 - pow(1.0 - k, 3.0)))
		return
	_gaze_hold -= delta
	if _gaze_hold <= 0.0:
		_begin_saccade()


func _begin_saccade() -> void:
	_gaze_from = _gaze
	_gaze_to = _pick_gaze_target()
	_gaze_elapsed = 0.0
	_gaze_hold = _rng.randf_range(gaze_hold_range.x, gaze_hold_range.y)


## A point inside the gaze_range ellipse, or dead centre. sqrt() on the radius
## spreads targets evenly over the area instead of bunching them in the middle.
func _pick_gaze_target() -> Vector2:
	if _rng.randf() < gaze_recentre_chance:
		return Vector2.ZERO
	var angle: float = _rng.randf() * TAU
	var radius: float = sqrt(_rng.randf())
	return Vector2(cos(angle) * gaze_range.x, sin(angle) * gaze_range.y) * radius


func _advance_blink(delta: float) -> void:
	if _blink_remaining > 0.0:
		_blink_remaining -= delta
		if _blink_remaining <= 0.0:
			_blink_remaining = 0.0
			set_eyes_closed(false)
		return
	if not idle_blink_enabled:
		return
	_blink_hold -= delta
	if _blink_hold <= 0.0:
		_blink_hold = _rng.randf_range(blink_hold_range.x, blink_hold_range.y)
		blink()
