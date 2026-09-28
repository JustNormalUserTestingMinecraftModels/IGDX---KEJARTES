@tool
class_name NotifBadge
extends Panel

## A red notification pill (2026-09-27 scrapbook HUD spec §5), instanced
## from NotifBadge.tscn onto a rail icon or a nav tile. Hidden at zero.
## When it turns on it springs in, then gives a gentle rotational wiggle
## every wiggle_interval_seconds, starting wiggle_delay_seconds late so
## badges never wiggle in unison. Calls come down from LobbyHud. @tool so
## the lobby_hud suite can call set_count(); nothing runs in _ready.

## What a badge shows when it marks rather than counts (the achievement "!").
const MARK_TEXT := "!"
## The largest count drawn as a number; above it the badge reads OVERFLOW_TEXT.
const MAX_SHOWN := 9
## A count above MAX_SHOWN.
const OVERFLOW_TEXT := "9+"
## One leg of the wiggle (tilt to a peak, or back to rest), seconds.
const WIGGLE_STEP_SECONDS := 0.1

## Show the count; off shows MARK_TEXT instead.
@export var shows_count: bool = true
## Seconds before this badge's first wiggle: offset each instance.
@export var wiggle_delay_seconds: float = 0.0
## Seconds between two wiggles.
@export var wiggle_interval_seconds: float = 2.4
## Peak tilt of a wiggle, degrees.
@export var wiggle_degrees: float = 8.0

var _wiggle: Tween

@onready var count_label: Label = %Count


## Shows `count` (hidden at zero or below); springs in when it turns on.
func set_count(count: int) -> void:
	var was_visible: bool = visible
	visible = count > 0
	if not visible:
		_stop_wiggle()
		return
	count_label.text = _text_for(count)
	if not was_visible:
		_arrive()


## What the pill reads for `count`: MARK_TEXT when it only marks rather than
## counts, OVERFLOW_TEXT past MAX_SHOWN, otherwise the number itself.
func _text_for(count: int) -> String:
	if not shows_count:
		return MARK_TEXT
	if count > MAX_SHOWN:
		return OVERFLOW_TEXT
	return str(count)


## Springs the badge in from turning on, then starts its idle wiggle. Under
## reduce_motion it simply lands at rest, with no wiggle.
func _arrive() -> void:
	if GameSettings.reduce_motion:
		scale = Vector2.ONE
		rotation_degrees = 0.0
		return
	AnimUtils.popup_spring_in(self)
	_start_wiggle()


## A looped tween: this badge's own delay, then the shared interval, then a
## tilt to −wiggle_degrees, +wiggle_degrees and back to rest. The delay
## repeats every loop (not just the first), so two badges sharing the same
## interval never fall back into sync. Off, with a warning, when
## wiggle_interval_seconds is not positive: a zero-length loop never ends.
func _start_wiggle() -> void:
	_stop_wiggle()
	if wiggle_interval_seconds <= 0.0:
		push_warning("NotifBadge: wiggle_interval_seconds must be above 0; the badge will not wiggle")
		return
	Juice.set_pivot_center(self)
	_wiggle = create_tween().set_loops()
	_wiggle.tween_interval(wiggle_delay_seconds)
	_wiggle.tween_interval(wiggle_interval_seconds)
	_wiggle.tween_property(self, "rotation_degrees", -wiggle_degrees, WIGGLE_STEP_SECONDS)
	_wiggle.tween_property(self, "rotation_degrees", wiggle_degrees, WIGGLE_STEP_SECONDS)
	_wiggle.tween_property(self, "rotation_degrees", 0.0, WIGGLE_STEP_SECONDS)


func _stop_wiggle() -> void:
	if _wiggle != null:
		_wiggle.kill()
	_wiggle = null
	rotation_degrees = 0.0
