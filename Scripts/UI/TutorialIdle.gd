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
## nudge; a cue with a Hand child (the tutorial arrow) also slides that
## pointing hand in. It escalates ONCE and holds; any tap (reset()) calms it and restarts
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
## The child a cue may carry for the escalation's pointing hand (the tutorial
## arrow's hidden Hand, placeholder art: DEBT.md, "Tutorial art").
const HAND_NODE := "Hand"
## How far, in pixels, the hand starts from its spot each time it slides in.
const HAND_SLIDE := Vector2(70, 70)
## Seconds of one slide of the hand toward its spot.
const HAND_SLIDE_SECONDS := 0.45
## How many times the hand slides in before it rests on its spot.
const HAND_SLIDES := 3
## Meta on a Hand: its slide tween while one plays, so a new one can kill it.
const HAND_TWEEN_META := &"tutorial_hand_slide"
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
	_hide_hands()
	_cues = []


## A tap: calm any escalation and restart the countdown.
func reset() -> void:
	_elapsed = 0.0
	_escalated = false
	_hide_hands()


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
	for cue: Variant in _cues:
		if is_instance_valid(cue) and cue is Control:
			_slide_hand(cue as Control)
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


## Shows `cue`'s Hand child, if it has one, and slides it in toward its spot
## HAND_SLIDES times, then leaves it there until a tap (reset) hides it.
func _slide_hand(cue: Control) -> void:
	var hand := cue.get_node_or_null(HAND_NODE) as Control
	if hand == null:
		return
	if not hand.has_meta(&"home"):
		hand.set_meta(&"home", hand.position)
	var home: Vector2 = hand.get_meta(&"home")
	_kill_hand_slide(hand)
	hand.visible = true
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var slide := hand.create_tween()
	hand.set_meta(HAND_TWEEN_META, slide)
	for i in HAND_SLIDES:
		slide.tween_property(hand, "position", home, HAND_SLIDE_SECONDS) \
				.from(home + HAND_SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Stops `hand`'s slide, if one is playing, so two slides never fight.
func _kill_hand_slide(hand: Control) -> void:
	if not hand.has_meta(HAND_TWEEN_META):
		return
	var slide: Variant = hand.get_meta(HAND_TWEEN_META)
	if slide is Tween and (slide as Tween).is_valid():
		(slide as Tween).kill()
	hand.remove_meta(HAND_TWEEN_META)


## Hides every cue's Hand and puts it back on its spot.
func _hide_hands() -> void:
	for cue: Variant in _cues:
		if not (is_instance_valid(cue) and cue is Node):
			continue
		var hand := (cue as Node).get_node_or_null(HAND_NODE) as Control
		if hand == null:
			continue
		_kill_hand_slide(hand)
		hand.visible = false
		if hand.has_meta(&"home"):
			hand.position = hand.get_meta(&"home")


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
