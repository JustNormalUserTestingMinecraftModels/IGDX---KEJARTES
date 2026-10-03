@tool
extends Control

## The boot logo: the first scene the game runs. The KejarTes logo fades
## (and grows a touch) in on black, holds, fades back out, then hands over to
## MainMenu. Godot's own boot splash is plain black (project.godot), so the
## two meet seamlessly. A tap skips straight to the fade-out.
##
## @tool so the test suite gets a live instance; the animation and the scene
## change are runtime-only, behind Engine.is_editor_hint().

## Where the logo hands over once it has faded out.
@export_file("*.tscn") var next_scene: String = "res://Scenes/MainMenu/MainMenu.tscn"
## Seconds of black before the logo starts to appear.
@export_range(0.0, 2.0, 0.05) var start_delay: float = 0.3
## Seconds the logo takes to fade in.
@export_range(0.05, 3.0, 0.05) var fade_in_seconds: float = 0.8
## Seconds the logo stays fully shown.
@export_range(0.0, 5.0, 0.05) var hold_seconds: float = 1.4
## Seconds the logo takes to fade out.
@export_range(0.05, 3.0, 0.05) var fade_out_seconds: float = 0.7
## Scale the logo grows from while fading in (1.0 = no growth). Ignored when
## Settings' Kurangi Gerakan is on.
@export_range(0.5, 1.0, 0.01) var start_scale: float = 0.9

@onready var _logo: TextureRect = %Logo

var _leaving := false
var _tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_logo.pivot_offset = _logo.size / 2.0
	_logo.modulate.a = 0.0
	if not GameSettings.reduce_motion:
		_logo.scale = Vector2.ONE * start_scale
	_tween = create_tween()
	_tween.tween_interval(start_delay)
	_tween.tween_property(_logo, "modulate:a", 1.0, fade_in_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_logo, "scale", Vector2.ONE, fade_in_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_seconds)
	_tween.tween_callback(_leave)


## A tap or key press skips the wait and fades the logo out now.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _leaving:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if pressed:
		_leave()


## Fades the logo out from wherever it is, then changes to next_scene.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var out := create_tween()
	out.tween_property(_logo, "modulate:a", 0.0, fade_out_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	out.tween_callback(func() -> void:
		Transition.change_scene(next_scene, Transition.Style.FADE))
