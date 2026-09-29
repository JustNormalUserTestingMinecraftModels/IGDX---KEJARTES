@tool
class_name NudgeLoop
extends Node

## Nudges the parent Control back and forth on x, a gentle "you can swipe
## this" hint (2026-09-28 muridmu-rostercard spec §4.2, "Nav arrows").
## StudentList attaches one under each nav arrow and sets `enabled` once
## at setup; the *dynamic* "only while there is more than one card" gate
## rides on the arrow's own `visible`, which StudentList was already
## toggling from card count for an unrelated reason -- the loop listens
## for the parent's `visibility_changed` and only ever runs while
## `enabled and parent.is_visible_in_tree()`, so StudentList never has to
## touch this node again after setup.
##
## @tool so the roster_avatar/student_list suites can instance it
## directly and read its exported state; the loop itself only ever
## starts outside the editor and while GameSettings.reduce_motion is
## off -- _ready()'s own start call is gated, matching IdleFade.gd's
## established pattern, and every later (re)start re-checks all three
## conditions so a live reduce_motion toggle or a visibility flip takes
## effect immediately.
##
## The parent must not sit inside a Container: the loop captures the parent's
## rest x once in _ready(), and a Container would re-lay it out from under
## the nudge.

## Nudges the parent this many px each way on x.
@export var amplitude: float = 4.0
## Seconds for one full there-and-back-and-rest cycle.
@export var period: float = 1.6
## The explicit on/off switch; StudentList sets this once at setup. The
## per-card-count gate is `parent.is_visible_in_tree()`, not this flag.
@export var enabled: bool = false:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_enabled()

var _tween: Tween
var _rest_x: float = 0.0


func _ready() -> void:
	var target := get_parent() as Control
	if target == null:
		push_error("NudgeLoop: parent must be a Control")
		return
	_rest_x = target.position.x
	target.visibility_changed.connect(_apply_enabled)
	if Engine.is_editor_hint():
		return
	_apply_enabled()


func _exit_tree() -> void:
	_stop()


## True while the nudge Tween is actually running -- false in the editor
## and under reduce_motion even with enabled = true, since both gate the
## Tween out before it is ever created.
func is_running() -> bool:
	return _tween != null and _tween.is_valid()


## Starts or stops the loop for the current enabled/visible/reduce_motion
## state. Gated on is_editor_hint() so the editor never sees a spinning
## Tween, even when a test sets `enabled` on an instance sitting in its
## root, or when the parent's visibility flips there.
func _apply_enabled() -> void:
	if Engine.is_editor_hint():
		return
	var target := get_parent() as Control
	if enabled and target != null and target.is_visible_in_tree() and not GameSettings.reduce_motion:
		_start()
	else:
		_stop()


## Rocks the parent between +amplitude and -amplitude forever, one full
## round trip per `period`, easing through the rest position in between.
func _start() -> void:
	var target := get_parent() as Control
	if target == null:
		return
	_stop()
	target.position.x = _rest_x
	var half_period: float = period * 0.5
	_tween = create_tween().set_loops()
	_tween.tween_property(target, "position:x", _rest_x + amplitude, half_period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(target, "position:x", _rest_x - amplitude, half_period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop() -> void:
	if _tween != null:
		_tween.kill()
	_tween = null
	var target := get_parent() as Control
	if target != null:
		target.position.x = _rest_x
