@tool
class_name IdleFade
extends Node

## Fades `targets` to faded_alpha after idle_seconds with no input, and
## snaps them back on the next touch, click or key (2026-09-27 scrapbook
## HUD spec §3, "Idle fade"). The Lobby uses it for its header and coin
## plate; nothing else fades. It reads input in _input and never marks it
## handled, so every tap still reaches its target. The timer is the
## authored IdleTimer child, not built here. @tool so the lobby_hud suite
## can instance it; _ready's timer start is gated.

## What fades: the Lobby wires its header and coin plate here.
@export var targets: Array[CanvasItem] = []
## Seconds without input before the fade (spec: ~8 s).
@export var idle_seconds: float = 8.0
## Alpha the targets rest at while idle (spec: ~55 %).
@export var faded_alpha: float = 0.55
## Seconds the fade out takes.
@export var fade_seconds: float = 0.6
## Seconds the snap back takes.
@export var restore_seconds: float = 0.12

var _fade: Tween

@onready var idle_timer: Timer = $IdleTimer


## The timeout connection runs even in the editor so the wiring is visible
## there too; only the timer's own start is gated, since a live countdown
## has no purpose while editing the scene.
func _ready() -> void:
	idle_timer.timeout.connect(fade_out)
	if Engine.is_editor_hint():
		return
	_restart_idle_timer()


## (Re)arms idle_timer for one more idle_seconds. A non-positive
## idle_seconds can never fire, so it warns and leaves the timer stopped
## rather than spinning a zero-length timer.
func _restart_idle_timer() -> void:
	if idle_seconds <= 0.0:
		push_warning("IdleFade: idle_seconds must be above 0; the idle fade will not start")
		return
	idle_timer.wait_time = idle_seconds
	idle_timer.one_shot = true
	idle_timer.start()


## Any press wakes the targets back up and restarts the idle countdown.
## Never consumes the event: every tap must still reach whatever it landed on.
## Inert in the edited scene, or a stray editor event could start a fade and
## the next scene_save would bake the faded alpha into the targets (review M3).
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	if not _is_wake(event):
		return
	restore()
	_restart_idle_timer()


static func _is_wake(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	return false


## Dims every valid target to faded_alpha over fade_seconds.
func fade_out() -> void:
	_animate_targets(faded_alpha, fade_seconds)


## Snaps every valid target back to full opacity over restore_seconds.
func restore() -> void:
	_animate_targets(1.0, restore_seconds)


## Shared by fade_out and restore: kills any tween already in flight, then
## either sets modulate:a directly (reduce_motion) or tweens it there. A
## null target is a scene-wiring mistake, so it is loud, not skipped quietly.
func _animate_targets(alpha: float, duration: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = null
	var reduced: bool = GameSettings.reduce_motion
	for target: CanvasItem in targets:
		if target == null:
			_push_null_target_error()
			continue
		if reduced:
			target.modulate.a = alpha
			continue
		if _fade == null:
			_fade = create_tween().set_parallel(true)
		_fade.tween_property(target, "modulate:a", alpha, duration)


func _push_null_target_error() -> void:
	var scene: String = owner.scene_file_path if owner != null else String(get_path())
	push_error("IdleFade: a target is not wired in %s" % scene)
