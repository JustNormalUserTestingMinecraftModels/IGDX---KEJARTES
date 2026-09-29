@tool
extends McpTestSuite

## RosterDeck (MURIDMU RosterCard Task 6): the StudentList carousel's
## stack-of-files motion -- finger-follow drag with a capped tilt, a
## parallax GhostCard, throw-or-spring release, and one overlapped switch.
##
## Mostly behavioural. The release reading and the drag pose are pure
## statics (classify_release, drag_pose, place_at_rest). The deck itself is
## @tool and, in the editor, lands every release and switch INSTANTLY with
## no Tween, so a standalone deck driving two plain Controls shows the
## whole signal flow synchronously: picked_up, thrown, switched, settled.
## What only runs live -- the Tweens, their timing, the flick speed off
## real motion events -- is pinned by source scan and left to the
## controller's live check.
##
## Must be @tool (the runner reports a non-@tool suite as abstract/broken)
## and no test here may be a coroutine (the runner calls `suite.call(name)`
## without awaiting).

const _DECK_SCRIPT := "res://Scripts/StudentList/RosterDeck.gd"
## Where every test drag starts, viewport px.
const _PRESS := Vector2(500.0, 900.0)
## A card's size in these tests, roughly the real 980x1410.
const _CARD_SIZE := Vector2(980.0, 1410.0)
## Float comparisons after a pose round-trips through radians.
const _EPSILON := 0.01

var _deck: RosterDeck
var _front: Control
var _back: Control
## Every signal the deck emitted in this test, as [name, args...].
var _events: Array = []


func suite_name() -> String:
	return "roster_deck"


func setup() -> void:
	_events = []
	_deck = RosterDeck.new()
	Engine.get_main_loop().root.add_child(_deck)
	track(_deck)
	_front = _card()
	_back = _card()
	_back.hide()
	_deck.picked_up.connect(func(card: Control) -> void: _events.append(["picked_up", card]))
	_deck.thrown.connect(func(kind: int) -> void: _events.append(["thrown", kind]))
	_deck.switched.connect(func(card: Control) -> void: _events.append(["switched", card]))
	_deck.settled.connect(func(card: Control, landed: bool) -> void:
		_events.append(["settled", card, landed]))


func _card() -> Control:
	var card := Control.new()
	card.size = _CARD_SIZE
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


func _names() -> Array:
	var out: Array = []
	for event: Array in _events:
		out.append(event[0])
	return out


## Presses at _PRESS, moves by `delta` and lifts there.
func _drag(delta: Vector2) -> void:
	_deck.begin_drag(_front, _PRESS)
	_deck.update_drag(_PRESS + delta)
	_deck.end_drag(_PRESS + delta)


# -------------------------------------------------------- classify_release

func test_a_press_that_barely_moves_is_a_tap() -> void:
	assert_eq(RosterDeck.classify_release(0.0, 0.0, 0.0), RosterDeck.Release.TAP, "no travel")
	assert_eq(RosterDeck.classify_release(5.0, -4.0, 0.0), RosterDeck.Release.TAP,
		"under the tap slop")


func test_a_vertical_drag_is_never_a_swipe() -> void:
	assert_eq(RosterDeck.classify_release(40.0, 300.0, 0.0), RosterDeck.Release.SPRING,
		"a long vertical drag springs back")
	assert_eq(RosterDeck.classify_release(100.0, 90.0, 2000.0), RosterDeck.Release.SPRING,
		"under the 1.2x horizontal gate, even fast")


func test_a_short_slow_drag_springs_back() -> void:
	assert_eq(RosterDeck.classify_release(-50.0, 5.0, 0.0), RosterDeck.Release.SPRING, "left")
	assert_eq(RosterDeck.classify_release(60.0, -3.0, 100.0), RosterDeck.Release.SPRING, "right")


func test_a_long_drag_throws_left_to_next_and_right_to_prev() -> void:
	assert_eq(RosterDeck.classify_release(-200.0, 10.0, 0.0), RosterDeck.Release.NEXT,
		"a left swipe moves the stack forward")
	assert_eq(RosterDeck.classify_release(200.0, -10.0, 0.0), RosterDeck.Release.PREV,
		"a right swipe moves it back")
	assert_eq(RosterDeck.classify_release(-RosterDeck.MIN_SWIPE_DISTANCE, 0.0, 0.0),
		RosterDeck.Release.NEXT, "the threshold itself throws, as it always did")


func test_a_flick_throws_a_short_drag() -> void:
	var fast := RosterDeck.FLICK_SPEED + 100.0
	assert_eq(RosterDeck.classify_release(-40.0, 3.0, -fast), RosterDeck.Release.NEXT, "left flick")
	assert_eq(RosterDeck.classify_release(40.0, 3.0, fast), RosterDeck.Release.PREV, "right flick")
	assert_eq(RosterDeck.classify_release(-40.0, 3.0, fast), RosterDeck.Release.SPRING,
		"a flick against the drag's own direction does not throw")
	assert_eq(RosterDeck.classify_release(-15.0, 0.0, -fast), RosterDeck.Release.SPRING,
		"a jitter under FLICK_MIN_PX never throws, however fast")


# ---------------------------------------------------------------- drag_pose

func test_drag_pose_follows_the_finger_one_to_one() -> void:
	assert_eq(RosterDeck.drag_pose(-137.0)["x"], -137.0, "x tracks the finger")
	assert_eq(RosterDeck.drag_pose(0.0)["rotation_degrees"], 0.0, "no drag, no tilt")


func test_drag_pose_tilt_is_proportional_then_capped() -> void:
	var small: float = RosterDeck.drag_pose(50.0)["rotation_degrees"]
	assert_true(absf(small - 50.0 * RosterDeck.TILT_PER_PX) < _EPSILON, "proportional while small")
	assert_eq(RosterDeck.drag_pose(5000.0)["rotation_degrees"], RosterDeck.TILT_MAX_DEGREES,
		"capped to the right")
	assert_eq(RosterDeck.drag_pose(-5000.0)["rotation_degrees"], -RosterDeck.TILT_MAX_DEGREES,
		"capped to the left")


func test_drag_pose_ghost_trails_at_the_parallax_fraction() -> void:
	var ghost_dx: float = RosterDeck.drag_pose(-200.0)["ghost_dx"]
	assert_true(absf(ghost_dx - (-200.0 * RosterDeck.GHOST_PARALLAX)) < _EPSILON,
		"the ghost follows a fraction behind")
	assert_true(absf(ghost_dx) < 200.0, "and less than the card itself")


# ------------------------------------------------------- the deck, driven

func test_a_tap_moves_nothing_and_leaves_the_tap_to_the_card() -> void:
	_drag(Vector2(4.0, 3.0))
	assert_eq(_front.position, Vector2.ZERO, "the card stays put for a tap")
	assert_eq(_events.size(), 0, "a tap emits nothing")
	assert_true(_deck.accepts_tap(), "the card's own tap (to AturJadwal) still fires")


func test_a_drag_picks_the_card_up_and_it_follows_the_finger() -> void:
	_deck.begin_drag(_front, _PRESS)
	_deck.update_drag(_PRESS + Vector2(-3.0, 0.0))
	assert_eq(_events.size(), 0, "under the tap slop nothing is picked up")
	_deck.update_drag(_PRESS + Vector2(-120.0, 0.0))
	assert_eq(_names(), ["picked_up"], "past the slop the card is picked up, once")
	assert_eq(_front.position.x, -120.0, "the card is under the finger")
	assert_true(absf(_front.rotation_degrees - (-120.0 * RosterDeck.TILT_PER_PX)) < _EPSILON,
		"and tilts with it")
	assert_eq(_front.pivot_offset, _CARD_SIZE / 2.0, "tilting about its centre")
	_deck.update_drag(_PRESS + Vector2(-160.0, 0.0))
	assert_eq(_names(), ["picked_up"], "picked up only once per drag")
	_deck.end_drag(_PRESS)


func test_a_short_drag_springs_back_without_landing() -> void:
	_drag(Vector2(-50.0, 0.0))
	assert_eq(_front.position, Vector2.ZERO, "back at rest")
	assert_eq(_front.rotation_degrees, 0.0, "upright again")
	assert_eq(_names(), ["picked_up", "settled"], "picked up, then settled")
	assert_false(_events[-1][2], "settled(landed = false): a spring-back does not replay the entry")
	assert_false(_deck.accepts_tap(), "a drag is not a tap: the card must not route")
	assert_false(_deck.busy, "free again")


func test_a_drag_out_and_back_is_not_a_tap() -> void:
	_deck.begin_drag(_front, _PRESS)
	_deck.update_drag(_PRESS + Vector2(-100.0, 0.0))
	_deck.end_drag(_PRESS)
	assert_false(_deck.accepts_tap(), "the finger came home, but it dragged")
	assert_eq(_front.position, Vector2.ZERO, "and the card sprang back")


func test_a_vertical_drag_springs_back_and_does_not_throw() -> void:
	_drag(Vector2(10.0, -300.0))
	assert_false(_names().has("thrown"), "a vertical drag is not a swipe")
	assert_eq(_front.position, Vector2.ZERO, "the card returns to rest")


func test_a_throw_nobody_answers_springs_back() -> void:
	_drag(Vector2(-220.0, 0.0))
	assert_eq(_names(), ["picked_up", "thrown", "settled"],
		"announced the throw, then sprang back when no switch came")
	assert_eq(_events[1][1], RosterDeck.Release.NEXT, "a left throw asks for the next card")
	assert_eq(_front.position, Vector2.ZERO, "back at rest")


func test_a_throw_answered_with_a_switch_lands_the_next_card() -> void:
	_deck.thrown.connect(func(_kind: int) -> void: _deck.switch(_front, _back, -1))
	_drag(Vector2(-220.0, 0.0))
	assert_eq(_names(), ["picked_up", "thrown", "switched", "settled"],
		"switched fires as the switch starts, settled when it lands")
	assert_eq(_events[2][1], _back, "switched names the incoming card")
	assert_eq(_events[3][1], _back, "the incoming card is the one that settles")
	assert_true(_events[3][2], "settled(landed = true): the new card replays its entry")
	assert_false(_front.visible, "the outgoing card is put away")
	assert_true(_back.visible, "the incoming card is shown")
	for card: Control in [_front, _back]:
		assert_eq(card.position, Vector2.ZERO, "%s at rest" % card)
		assert_eq(card.scale, Vector2.ONE, "%s full size" % card)
		assert_eq(card.modulate.a, 1.0, "%s opaque" % card)
	assert_false(_deck.busy, "free again")


func test_a_busy_deck_refuses_input_and_switches() -> void:
	_deck.busy = true
	_drag(Vector2(-220.0, 0.0))
	assert_eq(_front.position, Vector2.ZERO, "no drag while busy")
	_deck.switch(_front, _back, -1)
	assert_eq(_events.size(), 0, "no switch while busy: nothing double-fires")
	assert_false(_back.visible, "the incoming card never moved")
	assert_false(_deck.accepts_tap(), "and no tap either")


func test_a_press_swallowed_while_busy_never_becomes_a_tap() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = _PRESS
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = _PRESS
	_deck.busy = true
	_deck.handle_pointer(press, _front)
	_deck.busy = false
	_deck.handle_pointer(release, _front)
	assert_false(_deck.accepts_tap(), "a press that landed mid-switch must not route on lift")


func test_the_ghost_trails_the_drag_and_returns_home() -> void:
	var ghost := _card()
	ghost.position = Vector2(34.0, 0.0)
	_deck.ghost = ghost
	_deck.begin_drag(_front, _PRESS)
	_deck.update_drag(_PRESS + Vector2(-200.0, 0.0))
	assert_true(absf(ghost.position.x - (34.0 - 200.0 * RosterDeck.GHOST_PARALLAX)) < _EPSILON,
		"the ghost follows a fraction behind the card")
	_deck.end_drag(_PRESS + Vector2(-40.0, 0.0))
	assert_eq(ghost.position.x, 34.0, "and goes home with the spring-back")


func test_set_card_count_hides_the_ghost_for_a_lone_card() -> void:
	var ghost := _card()
	_deck.ghost = ghost
	_deck.set_card_count(1)
	assert_false(ghost.visible, "one card: nothing to peek")
	_deck.set_card_count(4)
	assert_true(ghost.visible, "a stack: the next file peeks")


func test_place_at_rest_resets_every_channel_the_deck_moves() -> void:
	_front.position = Vector2(-300.0, 0.0)
	_front.rotation_degrees = -9.0
	_front.scale = Vector2.ONE * 0.9
	_front.modulate.a = 0.0
	RosterDeck.place_at_rest(_front)
	assert_eq(_front.position, Vector2.ZERO, "position")
	assert_eq(_front.rotation_degrees, 0.0, "rotation")
	assert_eq(_front.scale, Vector2.ONE, "scale")
	assert_eq(_front.modulate.a, 1.0, "alpha")


# ------------------------------------------------- live-only, by source

## The Tweens never start in the editor, so their shape is pinned here:
## one stored Tween, killed before a new one and on _exit_tree; the switch
## overlaps (no await) and honours reduce_motion.
func test_the_switch_is_one_stored_overlapped_timeline() -> void:
	var src := FileAccess.get_file_as_string(_DECK_SCRIPT)
	assert_false(src.contains("await "), "the deck never awaits: out and in share one timeline")
	assert_true(src.contains("func _exit_tree() -> void:\n\t_kill_tween()"),
		"leaving the tree kills the running Tween")
	assert_true(src.contains("GameSettings.reduce_motion"), "reduced motion lands at once")
	assert_true(src.contains("set_delay(IN_DELAY_SECONDS)"), "the incoming card overlaps the outgoing")
	assert_true(src.contains("Tween.TRANS_BACK"), "the incoming card springs to the front")
	assert_false(src.contains("Color("), "no colour literals")
