@tool
class_name TutorialIdle
extends Node

## The tutorial's idle layer (2026-10-07 overhaul, spec
## docs/superpowers/specs/2026-10-07-tutorial-visual-overhaul-design.md
## section 3e), in one focused place so every screen that teaches shares it.
##
## Resting loop, always on while started: the step's `cues` (the tutorial
## arrow, a ring) breathe -- a slow fade between full and REST_ALPHA. The
## escalation: after idle_nudge_seconds with no tap, the target shakes, the cues
## pulse brighter, and `nudged` fires so the caller can drop its one-line
## nudge. It escalates ONCE and holds; any tap (reset()) calms it and restarts
## the countdown. pause() holds it while a pop-up, comic or beat is up.
##
## Touch-first: it reacts to a timer and to presses only, never to the pointer
## entering anything. tick() is the clock _process drives, so tests can step it.
## Builds nothing: it only animates controls its caller already has.

## Emitted once per idle spell, when the escalation plays.
signal nudged

## The alpha a resting cue breathes down to, from its full alpha.
const REST_ALPHA := 0.55
## Seconds for one breath out (and the same back in).
const REST_HALF_PERIOD := 0.8
## How hard the escalation shakes the target, in pixels (Juice.shake).
const NUDGE_SHAKE := 14.0
## How much a cue grows at the escalation's pulse.
const NUDGE_PULSE := 1.18

## Seconds of no input before the escalation plays. 2.5 confirmed by the owner
## on 2026-10-09 (spec section 10).
@export var idle_nudge_seconds: float = 2.5

var _target: Control
var _cues: Array = []
var _elapsed := 0.0
var _running := false
var _paused := false
var _escalated := false
var _rest_tweens: Array[Tween] = []


## A new TutorialIdle as a child of `owner`, for a screen that builds its
## tutorial at runtime (Lobby, StudentList). StudentCard authors its own node.
static func attach(owner: Node) -> TutorialIdle:
	var idle := TutorialIdle.new()
	owner.add_child(idle)
	return idle


## Starts the resting loop on `cues` (Controls; anything else is skipped) and
## arms the countdown toward a nudge on `target`. Calling it again moves both
## to the new step.
func start(target: Control, cues: Array = []) -> void:
	stop()
	_target = target
	_cues = cues
	_running = true
	_paused = false
	_elapsed = 0.0
	_escalated = false
	_start_rest()


## Stops everything and puts the cues back to full alpha.
func stop() -> void:
	_running = false
	for tween: Tween in _rest_tweens:
		if tween.is_valid():
			tween.kill()
	_rest_tweens.clear()
	for cue: Variant in _cues:
		if is_instance_valid(cue) and cue is CanvasItem:
			(cue as CanvasItem).modulate.a = 1.0
	_cues = []


## A tap: calm any escalation and restart the countdown.
func reset() -> void:
	_elapsed = 0.0
	_escalated = false


## Holds the countdown (a pop-up, the comic or a beat is on screen).
func pause() -> void:
	_paused = true


## Lets the countdown run again, from the start.
func resume() -> void:
	_paused = false
	_elapsed = 0.0


## True while started and not paused.
func is_counting() -> bool:
	return _running and not _paused


## Advances the countdown by `delta` seconds; plays the escalation once it
## passes idle_nudge_seconds.
func tick(delta: float) -> void:
	if not is_counting() or _escalated:
		return
	_elapsed += delta
	if _elapsed >= idle_nudge_seconds:
		_escalate()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	tick(delta)


func _input(event: InputEvent) -> void:
	if not _running:
		return
	var press := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if press:
		reset()


func _escalate() -> void:
	_escalated = true
	nudged.emit()
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if is_instance_valid(_target):
		Juice.shake(_target, NUDGE_SHAKE)
	for cue: Variant in _cues:
		if not (is_instance_valid(cue) and cue is Control):
			continue
		var control := cue as Control
		control.pivot_offset = control.size / 2.0
		var pulse := control.create_tween()
		pulse.tween_property(control, "scale", Vector2.ONE * NUDGE_PULSE, REST_HALF_PERIOD / 2.0) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.tween_property(control, "scale", Vector2.ONE, REST_HALF_PERIOD / 2.0)


func _start_rest() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	for cue: Variant in _cues:
		if not (is_instance_valid(cue) and cue is CanvasItem):
			continue
		var item := cue as CanvasItem
		var breathe := item.create_tween().set_loops()
		breathe.tween_property(item, "modulate:a", REST_ALPHA, REST_HALF_PERIOD) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breathe.tween_property(item, "modulate:a", 1.0, REST_HALF_PERIOD) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_rest_tweens.append(breathe)
