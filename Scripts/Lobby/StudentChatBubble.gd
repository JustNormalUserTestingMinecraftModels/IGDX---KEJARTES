@tool
class_name StudentChatBubble
extends Control

## A Lobby student's speech bubble (2026-09-19 student-chatter spec):
## StudentChatBubble.tscn's Body (PanelContainer) > Text (Label) plus a
## Tail TextureRect. show_line() mirrors the tail to the speaker's side
## (flip = speaker in the left half of the screen: tail on the left, bubble
## grows right), lands the tail's tip on the speaker's ChatAnchor, clamps
## the body inside the visible screen, and pops in from that tip like
## Pak Herman's ChatBubble -- then lingers and shrinks back into it.
## States IDLE -> SHOWING -> LINGERING -> HIDING -> IDLE; is_busy() is
## everything but IDLE, which LobbyChatter's spam guard reads.
##
## @tool because the test suite instantiates the scene in the editor; the
## hidden pose and timer are skipped only for the scene open for editing,
## so saving it never bakes a shrunk, transparent bubble.

signal finished

enum State { IDLE, SHOWING, LINGERING, HIDING }

## Body's authored size; the 3-line fit test measures text against it.
const BODY_SIZE := Vector2i(560, 200)
## Minimum gap between the bubble and the visible screen edge, in px.
const EDGE_MARGIN := 24.0
const SHRUNK_SCALE := Vector2(0.2, 0.2)
const FADE_IN_S := 0.32
const FADE_OUT_S := 0.28

## How long a line stays fully shown before it retracts, in seconds.
@export var linger_s: float = 2.6

var _state: int = State.IDLE
var _tween: Tween
var _linger_timer: Timer
## Tail's authored (unflipped) x; the flipped x mirrors it across the body.
var _tail_x: float = 0.0

@onready var _label: Label = get_node_or_null("Body/Text") as Label
@onready var _tail: TextureRect = get_node_or_null("Tail") as TextureRect


func _ready() -> void:
	if _tail:
		_tail_x = _tail.position.x
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	_linger_timer = Timer.new()
	_linger_timer.one_shot = true
	add_child(_linger_timer)
	_linger_timer.timeout.connect(_hide)
	scale = SHRUNK_SCALE
	modulate.a = 0.0


func get_state() -> int:
	return _state


func is_busy() -> bool:
	return _state != State.IDLE


func get_text() -> String:
	return _label.text if _label else ""


## True when a speaker at `anchor_x` sits in the screen's left half.
static func flip_for(anchor_x: float, screen_width: float) -> bool:
	return anchor_x < screen_width * 0.5


## Top-left for a bubble whose tail tip (`tip`, bubble-local) should land
## on `anchor`, clamped so the whole bubble stays `margin` inside `bounds`.
static func placement(anchor: Vector2, tip: Vector2, bubble_size: Vector2, bounds: Rect2, margin: float) -> Vector2:
	var p := anchor - tip
	p.x = clampf(p.x, bounds.position.x + margin, bounds.end.x - margin - bubble_size.x)
	p.y = clampf(p.y, bounds.position.y + margin, bounds.end.y - margin - bubble_size.y)
	return p


## The tail tip in bubble-local px for the given side.
func tip_local(flip: bool) -> Vector2:
	if _tail == null:
		return Vector2.ZERO
	var w := _tail.size.x
	var bottom := _tail.position.y + _tail.size.y
	if flip:
		return Vector2(size.x - (_tail_x + w), bottom)
	return Vector2(_tail_x + w, bottom)


## Say `text` from a speaker whose ChatAnchor is at `anchor_global`.
func show_line(text: String, anchor_global: Vector2, flip: bool) -> void:
	if _label:
		_label.text = text
	if _tail:
		_tail.flip_h = flip
		_tail.position.x = size.x - (_tail_x + _tail.size.x) if flip else _tail_x
	var tip := tip_local(flip)
	pivot_offset = tip
	position = placement(_to_parent_space(anchor_global), tip, size, _visible_bounds(), EDGE_MARGIN)
	_set_state(State.SHOWING)
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	if _linger_timer:
		_linger_timer.stop()
	_kill_tween()
	scale = SHRUNK_SCALE
	modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween = tw
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, FADE_IN_S)
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_shown.bind(tw))


## Retract now (a popup opened over the Lobby). No-op while IDLE.
func dismiss() -> void:
	if _state == State.IDLE or _state == State.HIDING:
		return
	_hide()


func _on_shown(tw: Tween) -> void:
	if tw != _tween:
		return
	_set_state(State.LINGERING)
	if _linger_timer:
		_linger_timer.start(linger_s)


func _hide() -> void:
	_set_state(State.HIDING)
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		_set_state(State.IDLE)
		return
	if _linger_timer:
		_linger_timer.stop()
	_kill_tween()
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween = tw
	tw.set_parallel(true)
	tw.tween_property(self, "scale", SHRUNK_SCALE, FADE_OUT_S)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_hidden.bind(tw))


func _on_hidden(tw: Tween) -> void:
	if tw != _tween:
		return
	_set_state(State.IDLE)
	finished.emit()


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _set_state(s: int) -> void:
	_state = s


## `p` (canvas/global px) in the parent's frame; identity without a
## Control parent, as in tests.
func _to_parent_space(p: Vector2) -> Vector2:
	var parent := get_parent() as CanvasItem
	if parent == null or not is_inside_tree():
		return p
	return parent.get_global_transform().affine_inverse() * p


## The visible screen in the parent's frame -- on a 20:9 phone the Lobby's
## Classroom is centred in a taller viewport, so this is not 0..1920.
func _visible_bounds() -> Rect2:
	if not is_inside_tree():
		return Rect2(Vector2.ZERO, Vector2(1080, 1920))
	var vis := get_viewport().get_visible_rect()
	var parent := get_parent() as CanvasItem
	if parent == null:
		return vis
	return parent.get_global_transform().affine_inverse() * vis
