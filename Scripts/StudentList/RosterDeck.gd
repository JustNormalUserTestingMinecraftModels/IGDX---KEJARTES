@tool
class_name RosterDeck
extends Node

## The StudentList carousel's motion, as a stack of files (MURIDMU spec
## 4.1). The front card follows the finger with a capped tilt while the
## authored GhostCard -- the next file, peeking out behind -- trails it at a
## parallax fraction. A release past MIN_SWIPE_DISTANCE, or a flick, throws
## the card; anything shorter springs it back. A switch is ONE timeline: the
## outgoing card flies off rotated, shrunk and fading while the incoming one
## rises out of the peek slot to the front, overlapped rather than awaited.
##
## Who owns what: StudentList owns the cards, the current index and every
## rule about which card comes next; this node only moves card ROOTS (the
## card's idle breath animates its inner Paper, so the two never fight).
## Signals up, calls down: StudentList feeds pointer events down through
## handle_pointer() and calls switch(); the deck announces picked_up,
## thrown, switched and settled, which StudentList wires in StudentList.tscn.
##
## `busy` is the carousel's single re-entry guard (it replaced StudentList's
## card_animating): input and switch() are refused while it is set, so a
## new drag during a switch can neither leak a Tween nor double-fire.
##
## @tool so tests/test_roster_deck.gd can instance it and drive a drag
## synchronously: in the editor -- and under GameSettings.reduce_motion --
## every release and switch lands INSTANTLY with no Tween at all, so the
## same code path is observable without awaiting.

## Emitted once a press has moved past TAP_SLOP_PX: `card` is now under the
## finger, so its owner pauses its idle loops.
signal picked_up(card: Control)
## Emitted when a release throws the front card: `kind` is Release.NEXT (a
## left swipe) or Release.PREV (a right one). The owner answers by calling
## switch(); if nobody does (one card, or a refused switch) the card
## springs back on its own.
signal thrown(kind: int)
## Emitted the moment a switch starts, so the owner's chrome (roster strip,
## page dots) follows DURING the slide rather than after it.
signal switched(card: Control)
## Emitted when the deck is at rest again: `landed` is true for the card a
## switch just brought to the front (replay its entry) and false for a card
## that sprang back from a short drag (only resume its idle loops).
signal settled(card: Control, landed: bool)

## How a pointer release reads (classify_release()'s answer).
enum Release { TAP, SPRING, NEXT, PREV }

# -------------------------------------------------------- release reading

## Pointer travel, px, a release must cover to throw the card. The
## carousel's original threshold, kept.
const MIN_SWIPE_DISTANCE := 75.0
## A throw must be this many times wider than it is tall -- the original
## horizontal gate, so a vertical scroll is never a swipe.
const HORIZONTAL_DOMINANCE := 1.2
## Travel under this, px, is a tap: the card does not move for it and the
## card's own tap (to AturJadwal) still fires.
const TAP_SLOP_PX := 12.0
## Horizontal release speed, px/s, at which a short drag still throws.
const FLICK_SPEED := 900.0
## A flick must still cover this much, px, so a jittery tap never throws.
const FLICK_MIN_PX := 24.0
## A finger that stops this long, s, before lifting has not flicked.
const FLICK_WINDOW_SECONDS := 0.1
## Weight of the newest motion sample in the smoothed release speed.
const VELOCITY_SMOOTHING := 0.6
## Motion closer together than this, s, waits for the next sample: two
## events microseconds apart would read as a huge speed, and a spike like
## that turns a slow drag into a flick.
const MIN_SAMPLE_SECONDS := 0.008
## Microseconds per second, for the speed sampled off Time.get_ticks_usec().
const USEC_PER_SECOND := 1000000.0

# ---------------------------------------------------------- finger follow

## Drag tilt, degrees per px of horizontal travel.
const TILT_PER_PX := 0.03
## The drag tilt's cap, degrees either way: a file held, not a page flung.
const TILT_MAX_DEGREES := 6.0
## Fraction of the drag the GhostCard follows, for parallax.
const GHOST_PARALLAX := 0.25
## A short drag's spring back to rest, seconds.
const SPRING_SECONDS := 0.3

# ------------------------------------------------------------- the switch

## The outgoing card's flight, seconds.
const OUT_SECONDS := 0.3
## The outgoing card's rotation at the end of its flight, degrees, times
## the switch direction.
const OUT_TILT_DEGREES := 9.0
## The outgoing card's scale at the end of its flight.
const OUT_SCALE := 0.92
## The incoming card's rise from the peek slot to the front, seconds.
const IN_SECONDS := 0.4
## The incoming card starts rising this long after the outgoing one
## leaves, seconds -- overlapped, never awaited.
const IN_DELAY_SECONDS := 0.05
## The peek slot the incoming card rises from: x offset px (the authored
## GhostCard sits at +34, so the new file comes out of the stack) ...
const PEEK_OFFSET_X := 30.0
## ... rotation, degrees ...
const PEEK_TILT_DEGREES := 4.0
## ... and scale.
const PEEK_SCALE := 0.9

## True while the deck animates (a switch or a spring-back), and while the
## owner holds it (StudentList sets it once a card is picked and the screen
## is leaving). Input and switch() are refused while it is set.
var busy := false
## The authored GhostCard behind the cards, resolved in _ready by its
## %unique name; null for a deck standing alone (tests).
var ghost: Control

## The one Tween the deck runs at a time (a switch or a spring-back).
var _tween: Tween
## The card under the finger, while a press is live.
var _card: Control
## A press is live (between press and release).
var _dragging := false
## The press has moved past TAP_SLOP_PX: the card is picked up.
var _moved := false
## Where the press began, in viewport pixels.
var _start := Vector2.ZERO
## The last motion sample's x and its time, for the release speed.
var _last_x := 0.0
var _last_usec := 0
## Smoothed horizontal pointer speed, px/s.
var _velocity_x := 0.0
## The last release was not a tap, so the card's own tap must not fire.
var _tap_blocked := false
## A throw was announced and nobody has switched yet.
var _throw_pending := false
## The GhostCard's resting x, recorded when a drag picks a card up.
var _ghost_home_x := 0.0
## The GhostCard is off its rest (a drag moved it).
var _ghost_displaced := false


func _ready() -> void:
	ghost = get_node_or_null("%GhostCard") as Control
	if ghost == null and owner != null:
		push_error("RosterDeck: %GhostCard is missing from the owner scene")


## A screen leaving mid-motion takes no Tween with it.
func _exit_tree() -> void:
	_kill_tween()


# ------------------------------------------------------------- pure math

## How a release that travelled (`dx`, `dy`) px at `velocity` px/s
## horizontally reads: a tap (barely moved), a spring back (vertical, or
## too short and too slow), or a throw -- Release.NEXT for a left swipe,
## Release.PREV for a right one. Pure, so tests pin it without a scene.
static func classify_release(dx: float, dy: float, velocity: float) -> int:
	var travel := Vector2(dx, dy).length()
	if travel < TAP_SLOP_PX:
		return Release.TAP
	if absf(dx) <= absf(dy) * HORIZONTAL_DOMINANCE:
		return Release.SPRING
	var flicked := absf(velocity) >= FLICK_SPEED \
		and signf(velocity) == signf(dx) and travel >= FLICK_MIN_PX
	if travel < MIN_SWIPE_DISTANCE and not flicked:
		return Release.SPRING
	return Release.NEXT if dx < 0.0 else Release.PREV


## The front card's pose for a horizontal drag of `dx` px: "x" (1:1 with
## the finger), "rotation_degrees" (proportional, capped at
## TILT_MAX_DEGREES) and "ghost_dx" (the GhostCard's parallax offset).
static func drag_pose(dx: float) -> Dictionary:
	return {
		"x": dx,
		"rotation_degrees": clampf(dx * TILT_PER_PX, -TILT_MAX_DEGREES, TILT_MAX_DEGREES),
		"ghost_dx": dx * GHOST_PARALLAX,
	}


## Puts `card` at the front's rest pose: origin, upright, full size, opaque.
static func place_at_rest(card: Control) -> void:
	card.position = Vector2.ZERO
	card.rotation_degrees = 0.0
	card.scale = Vector2.ONE
	card.modulate.a = 1.0


# ------------------------------------------------------------ public reach

## Shows the GhostCard only when there is a second file to peek.
func set_card_count(count: int) -> void:
	if ghost != null:
		ghost.visible = count > 1


## False after a release that was a drag, and while busy: the card's own
## tap (its Button's `pressed`, which fires after this deck has read the
## same release) must not route a drag to AturJadwal.
func accepts_tap() -> bool:
	return not busy and not _tap_blocked


## Feeds one pointer event on the front `card` to the deck. Mouse events
## only, read by global_position: the project emulates mouse from touch
## (and touch from mouse), and a touch event's position is local to the
## card -- which is moving under the finger.
func handle_pointer(event: InputEvent, card: Control) -> void:
	if busy:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			begin_drag(card, button.global_position)
		else:
			end_drag(button.global_position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		update_drag(motion.global_position)


## A press on `card` at `pointer` (viewport px). Nothing moves yet.
func begin_drag(card: Control, pointer: Vector2) -> void:
	if busy or _dragging:
		return
	_card = card
	_dragging = true
	_moved = false
	_tap_blocked = false
	_start = pointer
	_last_x = pointer.x
	_last_usec = Time.get_ticks_usec()
	_velocity_x = 0.0


## The finger moved to `pointer`: past TAP_SLOP_PX the card is picked up
## and follows, tilting, with the GhostCard trailing.
func update_drag(pointer: Vector2) -> void:
	if not _dragging or not is_instance_valid(_card):
		return
	_sample_velocity(pointer.x)
	if not _moved:
		if pointer.distance_to(_start) < TAP_SLOP_PX:
			return
		_pick_up()
	var pose := drag_pose(pointer.x - _start.x)
	_card.position.x = pose["x"]
	_card.rotation_degrees = pose["rotation_degrees"]
	if ghost != null:
		ghost.position.x = _ghost_home_x + float(pose["ghost_dx"])


## The finger lifted at `pointer`: throw (announce `thrown`), spring back,
## or -- for a tap -- nothing at all.
func end_drag(pointer: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var delta := pointer - _start
	var kind := classify_release(delta.x, delta.y, _release_velocity())
	if kind == Release.TAP and _moved:
		kind = Release.SPRING  # dragged out and back: still not a tap
	_tap_blocked = kind != Release.TAP
	if kind == Release.TAP:
		return
	if kind == Release.SPRING:
		_spring_back()
		return
	_throw_pending = true
	thrown.emit(kind)
	if _throw_pending:
		_throw_pending = false
		_spring_back()


## Swaps the front card: `outgoing` flies off toward `direction` (-1 left,
## i.e. next; +1 right, i.e. prev -- StudentList._switch_card's convention)
## rotated, shrunk and fading, while `incoming` rises from the peek slot to
## the front with TRANS_BACK on the same timeline. Starts from wherever a
## drag left `outgoing`. Emits `switched` at once and `settled(incoming,
## true)` on landing. Refused while busy.
func switch(outgoing: Control, incoming: Control, direction: int) -> void:
	if busy:
		return
	_throw_pending = false
	if _dragging:
		_dragging = false
		_tap_blocked = true
	_kill_tween()
	outgoing.pivot_offset = outgoing.size / 2.0
	incoming.pivot_offset = incoming.size / 2.0
	_stage_in_peek_slot(incoming)
	switched.emit(incoming)
	if _is_instant():
		_finish_switch(outgoing, incoming)
		return
	busy = true
	# The outgoing file lifts over the one rising beneath it. A tree move,
	# not z_index: a raised z_index would paint over the HUD as well.
	outgoing.get_parent().move_child(outgoing, -1)
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween_out(outgoing, get_viewport().get_visible_rect().size.x * direction, direction)
	_tween_in(incoming)
	_tween_ghost_home(OUT_SECONDS)
	_tween.finished.connect(_finish_switch.bind(outgoing, incoming))


# --------------------------------------------------------------- internals

## Reduced motion, and the editor (where no Tween may start), land every
## release and switch at once.
func _is_instant() -> bool:
	return Engine.is_editor_hint() or GameSettings.reduce_motion


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _pick_up() -> void:
	_moved = true
	_card.pivot_offset = _card.size / 2.0
	if ghost != null and not _ghost_displaced:
		_ghost_home_x = ghost.position.x
	_ghost_displaced = ghost != null
	picked_up.emit(_card)


func _sample_velocity(x: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := float(now - _last_usec) / USEC_PER_SECOND
	if elapsed < MIN_SAMPLE_SECONDS:
		return
	_velocity_x = lerpf(_velocity_x, (x - _last_x) / elapsed, VELOCITY_SMOOTHING)
	_last_x = x
	_last_usec = now


## The smoothed speed, or zero when the finger rested before lifting.
func _release_velocity() -> float:
	var idle := float(Time.get_ticks_usec() - _last_usec) / USEC_PER_SECOND
	return 0.0 if idle > FLICK_WINDOW_SECONDS else _velocity_x


func _spring_back() -> void:
	var card := _card
	if not is_instance_valid(card):
		return
	if _is_instant():
		place_at_rest(card)
		_place_ghost_home()
		settled.emit(card, false)
		return
	busy = true
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "position:x", 0.0, SPRING_SECONDS)
	_tween.tween_property(card, "rotation_degrees", 0.0, SPRING_SECONDS)
	_tween_ghost_home(SPRING_SECONDS)
	_tween.finished.connect(_finish_spring.bind(card))


func _finish_spring(card: Control) -> void:
	_tween = null
	place_at_rest(card)
	_place_ghost_home()
	busy = false
	settled.emit(card, false)


func _stage_in_peek_slot(card: Control) -> void:
	card.position = Vector2(PEEK_OFFSET_X, 0.0)
	card.rotation_degrees = PEEK_TILT_DEGREES
	card.scale = Vector2.ONE * PEEK_SCALE
	card.modulate.a = 0.0
	card.show()


func _tween_out(card: Control, throw_x: float, direction: int) -> void:
	_tween.tween_property(card, "position:x", throw_x, OUT_SECONDS)
	_tween.tween_property(card, "rotation_degrees", OUT_TILT_DEGREES * direction, OUT_SECONDS)
	_tween.tween_property(card, "scale", Vector2.ONE * OUT_SCALE, OUT_SECONDS)
	_tween.tween_property(card, "modulate:a", 0.0, OUT_SECONDS)


## The incoming card springs from the peek slot to the front (TRANS_BACK
## overshoots a touch past full size, then settles); its fade does not
## overshoot.
func _tween_in(card: Control) -> void:
	_rise(card, "position", Vector2.ZERO).set_trans(Tween.TRANS_BACK)
	_rise(card, "rotation_degrees", 0.0).set_trans(Tween.TRANS_BACK)
	_rise(card, "scale", Vector2.ONE).set_trans(Tween.TRANS_BACK)
	_rise(card, "modulate:a", 1.0).set_trans(Tween.TRANS_QUAD)


func _rise(card: Control, property: String, rest: Variant) -> PropertyTweener:
	return _tween.tween_property(card, property, rest, IN_SECONDS) \
		.set_delay(IN_DELAY_SECONDS).set_ease(Tween.EASE_OUT)


func _tween_ghost_home(seconds: float) -> void:
	if ghost != null and _ghost_displaced:
		_tween.tween_property(ghost, "position:x", _ghost_home_x, seconds) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _place_ghost_home() -> void:
	if ghost != null and _ghost_displaced:
		ghost.position.x = _ghost_home_x
	_ghost_displaced = false


func _finish_switch(outgoing: Control, incoming: Control) -> void:
	_tween = null
	outgoing.hide()
	place_at_rest(outgoing)
	place_at_rest(incoming)
	_place_ghost_home()
	busy = false
	settled.emit(incoming, true)
