@tool
extends Control

## The pick confirmation over the level select: the chosen amplop opens (the
## seal pops, the flap folds back), its pupils peek out, and the surat tugas
## rises with the grade's brief and Terima Tugas / Batal. Opening IS the
## confirmation ritual. Hidden until present(); the screen owns what happens
## on accepted and cancelled. The envelope also zooms up toward the player on
## its own tween (see _zoom_envelope()); the confirm's own nodes are all
## %UniqueName refs so layout changes elsewhere cannot break it.
##
## @tool so the MCP suite can stand it up. It starts nothing on its own, so
## nothing here needs an Engine.is_editor_hint() gate.

## Player took the assignment for `grade`.
signal accepted(grade: int)
## Player backed out; the screen hides this and returns to the fan.
signal cancelled

## Seconds the scrim takes to fade in.
const SCRIM_FADE_SEC := 0.2
## Seconds the surat tugas takes to rise into place, and how far it rises.
const LETTER_SEC := 0.45
const LETTER_RISE := 40.0

## Final scale of the opened envelope: it surges from the fan's card_scale up
## to this, as if flying toward the player. Capped at 1.35: at Envelope's
## anchor, a bigger target pushes the envelope and its rising pupils off the
## top of a 1920-tall screen.
@export var open_scale_target: float = 1.35
## Seconds the opened envelope takes to zoom up to open_scale_target.
@export var open_zoom_sec: float = 0.35

## The envelope that opens: an AmplopCard shown for display (not interactive).
@onready var card: Control = %Card
## The CenterContainer holding it. Size goes here, never on the card: a
## Container resets its children's scale every time it lays them out.
@onready var envelope: Control = %Envelope
@onready var _letter: NotebookFrame = %Letter
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _accept: Button = %Accept
@onready var _cancel: Button = %Cancel

var _grade := 7
## The letter's authored vertical offsets. The rise moves its position, which
## rewrites these, so they are put back before each rise; the anchored rest
## then follows whatever size the screen is now, never a cached one.
var _letter_rest_offsets := Vector2.ZERO
var _fade: Tween
## The envelope's resting scale: the fan's card_scale, pushed down by
## LevelSelect through set_envelope_scale(). Each open zooms from here and
## dismiss() returns to it; the confirm never reads LevelSelect.
var _envelope_rest_scale := 1.0
var _zoom: Tween


func _ready() -> void:
	_accept.pressed.connect(func() -> void:
		_set_buttons_enabled(false)
		accepted.emit(_grade))
	_cancel.pressed.connect(func() -> void: cancelled.emit())
	_letter.close_pressed.connect(_on_close_pressed)
	_letter_rest_offsets = Vector2(_letter.offset_top, _letter.offset_bottom)


## Fill and show the confirmation for `grade`: one pupil per texture in
## `portraits`, `brief_line` in the letter. Plays the open at once and
## returns its tween.
func present(grade: int, portraits: Array, brief_line: String) -> Tween:
	_grade = grade
	card.grade = grade
	card.tab_text = "Kelas %d" % grade
	_title.text = "Mulai Kelas %d?" % grade
	_body.text = brief_line
	_set_buttons_enabled(true)
	visible = true
	modulate.a = 0.0
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, SCRIM_FADE_SEC)
	return play_open(portraits)


## Draw the envelope `rest_scale` times its template size, grown about its
## bottom-centre (the card's anchor, at the container's centre) so it rises
## away from the letter below instead of into it. While the open zoom is
## mid-flight this only records the new rest scale for later -- snapping
## envelope.scale here would fight that tween's own writes to it every frame.
func set_envelope_scale(rest_scale: float) -> void:
	_envelope_rest_scale = rest_scale
	envelope.pivot_offset = envelope.size * 0.5
	if _zoom != null and _zoom.is_valid() and _zoom.is_running():
		return
	envelope.scale = Vector2.ONE * rest_scale


## The open sequence: the envelope zooms toward the player while its own
## open() runs, then the letter rises in.
func play_open(portraits: Array) -> Tween:
	_rest_letter()
	_zoom_envelope()
	var home := _letter.position.y
	_letter.modulate.a = 0.0
	_letter.position.y = home + LETTER_RISE
	var tw: Tween = card.open(portraits)
	tw.tween_property(_letter, "modulate:a", 1.0, LETTER_SEC)
	tw.parallel().tween_property(_letter, "position:y", home, LETTER_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Reseal the envelope and hide, ready for the next present().
func dismiss() -> void:
	card.reseal()
	_rest_letter()
	_rest_envelope()
	visible = false


func _rest_letter() -> void:
	_letter.offset_top = _letter_rest_offsets.x
	_letter.offset_bottom = _letter_rest_offsets.y


## The zoom runs on its own tween so it starts with the seal, flap and
## pupils rather than after them; TRANS_BACK gives the "flies at you" snap.
func _zoom_envelope() -> void:
	_rest_envelope()
	_zoom = create_tween()
	_zoom.tween_property(envelope, "scale", Vector2.ONE * open_scale_target, open_zoom_sec) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Back to the fan's size, so a re-open replays the zoom from card_scale.
func _rest_envelope() -> void:
	if _zoom != null and _zoom.is_valid():
		_zoom.kill()
	set_envelope_scale(_envelope_rest_scale)


func _set_buttons_enabled(on: bool) -> void:
	_accept.disabled = not on
	_cancel.disabled = not on


## The frame's round close is Batal: it cancels, but only while Batal
## itself could be pressed (the buttons are off while the letter animates).
func _on_close_pressed() -> void:
	if not _cancel.disabled:
		cancelled.emit()
