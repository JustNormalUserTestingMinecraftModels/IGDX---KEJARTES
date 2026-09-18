@tool
class_name ChatBubble
extends Control

## Pak Herman's speech bubble in the Koperasi (Stage/ChatBubble in
## koprasi.tscn: a Body PanelContainer > Text RichTextLabel, plus a Tail
## TextureRect pointing down at Herman). A tiny FSM: say()/say_for_item()
## pick a line from DialogueCatalog, tween the bubble in from Herman's
## direction, hold it, then tween it back into him. say_sticky() pins a
## line (SOLD_OUT) until clear_sticky(). Per-event SAY_COOLDOWN debounces
## tap-spam -- different events are not coupled to each other.
##
## @tool because tests instantiate this script directly with a bare
## ChatBubble.new(). Every child lookup goes through get_node_or_null() so
## a bubble built without the authored Body/Text/Tail children (or with a
## hand-built minimal tree, as in tests/test_koperasi_chat_bubble.gd)
## degrades instead of crashing on a hard $Path lookup.
##
## The one-time hide (scale/modulate) and the linger timer are skipped
## while this node is part of the scene *currently open for editing* --
## gated on is_part_of_edited_scene(), not just is_editor_hint(), because
## test_run also executes inside the editor and still needs the real
## behaviour. Saving koprasi.tscn from the editor must never bake the
## shrunk/hidden pose into the file.

signal state_changed(state: int)

enum State { IDLE, SHOWING, LINGERING, HIDING }

const SAY_COOLDOWN := 0.12
const LINGER_S := 2.2
const FADE_IN_S := 0.32
const FADE_OUT_S := 0.28
## Bubble -> Herman, in px. The shrunk/hidden pose sits this far toward
## him from rest_position, so the bubble reads as retracting into him
## instead of fading in place.
const HERMAN_ANCHOR_OFFSET := Vector2(60.0, 40.0)
const SHRUNK_SCALE := Vector2(0.2, 0.2)

## Where the bubble rests while SHOWING/LINGERING, in the parent's frame.
## Defaults to the node's authored position in koprasi.tscn (36, 23).
@export var rest_position: Vector2 = Vector2(36.0, 23.0)

var _state: int = State.IDLE
var _sticky: bool = false
## event (StringName) -> Time.get_ticks_msec() of the last accepted say()
## for that event, for the per-event cooldown.
var _last_say_time: Dictionary = {}
var _linger_timer: Timer

@onready var _label: RichTextLabel = get_node_or_null("Body/Text") as RichTextLabel
@onready var _tail: Control = get_node_or_null("Tail") as Control


func _ready() -> void:
	if _tail:
		# Pivot toward the tail's tip (its bottom, centred on its width) so
		# the bubble shrinks/grows into Herman rather than from its own
		# centre or a hardcoded corner.
		pivot_offset = _tail.position + Vector2(_tail.size.x * 0.5, _tail.size.y)

	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return

	_linger_timer = Timer.new()
	_linger_timer.one_shot = true
	add_child(_linger_timer)
	_linger_timer.timeout.connect(_on_linger_timeout)

	scale = SHRUNK_SCALE
	modulate.a = 0.0


func get_state() -> int:
	return _state


## Speak a line from DialogueCatalog.LINES[event]. Ignored while sticky, or
## within SAY_COOLDOWN of the previous accepted say() of the same event.
func say(event: StringName) -> void:
	if _sticky or not _pass_cooldown(event):
		return
	var text := DialogueCatalog.pick(event)
	if text.is_empty():
		return
	_play(text)


## Like say(), but for &"ADD"/&"REMOVE" where `item_name` may have its own
## DialogueCatalog.ITEM_LINES pool (falls back to the generic pool).
func say_for_item(event: StringName, item_name: String) -> void:
	if _sticky or not _pass_cooldown(event):
		return
	var text := DialogueCatalog.pick_for_item(event, item_name)
	if text.is_empty():
		return
	_play(text)


## Pin `text` until clear_sticky(). Bypasses the cooldown (idempotent: the
## text does not change while already sticky) and every later say()/
## say_for_item() is ignored until cleared.
func say_sticky(text: String) -> void:
	_sticky = true
	if _linger_timer:
		_linger_timer.stop()
	_play(text)


## Release a sticky line and retract the bubble.
func clear_sticky() -> void:
	_sticky = false
	_hide()


func _pass_cooldown(event: StringName) -> bool:
	var now := Time.get_ticks_msec()
	var last: int = _last_say_time.get(event, -1000000)
	if float(now - last) / 1000.0 < SAY_COOLDOWN:
		return false
	_last_say_time[event] = now
	return true


func _play(text: String) -> void:
	if _label:
		_label.text = text
	_set_state(State.SHOWING)

	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return

	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, FADE_IN_S)
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN_S)
	tw.tween_property(self, "position", rest_position, FADE_IN_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_shown)


func _on_shown() -> void:
	_set_state(State.LINGERING)
	if _sticky:
		return
	if _linger_timer:
		_linger_timer.start(LINGER_S)


func _on_linger_timeout() -> void:
	if _sticky:
		return
	_hide()


func _hide() -> void:
	_set_state(State.HIDING)

	if Engine.is_editor_hint() and is_part_of_edited_scene():
		_set_state(State.IDLE)
		return

	var end_pos := rest_position + HERMAN_ANCHOR_OFFSET
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_parallel(true)
	tw.tween_property(self, "scale", SHRUNK_SCALE, FADE_OUT_S)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT_S)
	tw.tween_property(self, "position", end_pos, FADE_OUT_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_hidden)


func _on_hidden() -> void:
	_set_state(State.IDLE)


func _set_state(s: int) -> void:
	if _state == s:
		return
	_state = s
	state_changed.emit(s)
