@tool
class_name LobbyChatter
extends Node

## Who talks in the Lobby, and when (2026-09-19 student-chatter spec).
## loby.gd hands in the seated students (set_seats) and a can_speak gate
## (false during the tutorial, the daily-reward popup and the skin picker).
## A tap on a student's face asks them to talk; so does an idle timer of
## idle_min_s..idle_max_s, re-rolled on every tap and after every line,
## which picks a random seated student other than the last idle speaker.
## One bubble, one speaker: a request is refused while the bubble is busy
## and for tap_cooldown_s after it finishes, so spamming taps leaves the
## line on screen exactly as it was.

## Path to the one bubble every student speaks through (loby.tscn's
## Classroom/ChatBubble); resolved into `bubble` in _ready().
@export var bubble_path: NodePath
## Shortest wait, in seconds, before an idle student pipes up.
@export var idle_min_s: float = 20.0
## Longest wait, in seconds, before an idle student pipes up.
@export var idle_max_s: float = 50.0
## After a line retracts, taps are ignored for this long, in seconds.
@export var tap_cooldown_s: float = 0.5

## The bubble in use: bubble_path's node, or one a test hands in directly.
var bubble: StudentChatBubble
## Returns whether anyone may talk right now; loby.gd replaces it.
var can_speak: Callable = func() -> bool: return true

var _seats: Array = []
var _picker := StudentChatterPicker.new()
var _idle_timer: Timer
var _last_speaker: int = -1
## When the bubble last went idle (Time.get_ticks_msec()).
var _idle_since_ms: int = -100000


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	_idle_timer = Timer.new()
	_idle_timer.one_shot = true
	add_child(_idle_timer)
	_idle_timer.timeout.connect(_on_idle_timeout)
	if bubble == null and not bubble_path.is_empty():
		bubble = get_node_or_null(bubble_path) as StudentChatBubble
	if bubble and not bubble.finished.is_connected(_on_bubble_finished):
		bubble.finished.connect(_on_bubble_finished)
	reset_idle_timer()


## Seats as {student: Dictionary, hit: Control, anchor: Control}.
func set_seats(seats: Array) -> void:
	_seats = seats.filter(func(s): return s is Dictionary \
		and s.get("hit") is Control and s.get("anchor") is Control)
	_last_speaker = -1


func get_last_speaker() -> int:
	return _last_speaker


func next_idle_delay() -> float:
	return randf_range(idle_min_s, idle_max_s)


func reset_idle_timer() -> void:
	if _idle_timer and _idle_timer.is_inside_tree():
		_idle_timer.start(next_idle_delay())


func dismiss() -> void:
	if bubble:
		bubble.dismiss()


## Seat `i` says a line. False when gated, busy, cooling down or invalid.
func request_line(i: int) -> bool:
	if i < 0 or i >= _seats.size() or bubble == null:
		return false
	if not bool(can_speak.call()):
		return false
	if bubble.is_busy():
		return false
	if Time.get_ticks_msec() - _idle_since_ms < int(tap_cooldown_s * 1000.0):
		return false
	var seat: Dictionary = _seats[i]
	var line := _picker.pick(seat.student)
	if line.is_empty():
		return false
	var anchor_pos: Vector2 = (seat.anchor as Control).global_position
	var width := 1080.0
	if bubble.is_inside_tree():
		width = bubble.get_viewport().get_visible_rect().size.x
	bubble.show_line(line, anchor_pos, StudentChatBubble.flip_for(anchor_pos.x, width))
	_last_speaker = i
	return true


## A random seated student other than the last speaker talks.
func speak_idle() -> bool:
	if _seats.is_empty():
		return false
	var choices: Array = range(_seats.size())
	if choices.size() > 1:
		choices.erase(_last_speaker)
	return request_line(choices[randi() % choices.size()])


## Index of the seat whose face contains `global_pos`, or -1.
func seat_at(global_pos: Vector2) -> int:
	for i in range(_seats.size()):
		var hit := _seats[i].hit as Control
		if hit.is_visible_in_tree() and hit.get_global_rect().has_point(global_pos):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	reset_idle_timer()
	var i := seat_at(event.get("position") as Vector2)
	if i >= 0:
		request_line(i)


func _on_idle_timeout() -> void:
	speak_idle()
	reset_idle_timer()


func _on_bubble_finished() -> void:
	_idle_since_ms = Time.get_ticks_msec()
	reset_idle_timer()
