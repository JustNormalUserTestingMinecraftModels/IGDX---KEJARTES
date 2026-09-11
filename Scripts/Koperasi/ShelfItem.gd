@tool
extends Node

## Gives one koperasi shelf item its life: a soft shadow on the plank, a
## slow idle bob at a per-item phase offset so the shelf never pulses in
## unison, a lift when pressed, and a dim when the player cannot afford it.
##
## Attached as a child helper of a shelf TextureButton rather than as that
## button's own script, so the shop's existing press wiring is untouched.

## Vertical travel of the idle bob, in pixels.
@export var bob_distance: float = 6.0

## Seconds for one full bob cycle.
@export var bob_period: float = 2.4

## How far the item rises when pressed, in pixels.
@export var lift_distance: float = 10.0

## Seconds the lift takes to rise, and again to settle.
@export var lift_duration: float = 0.16

## Opacity applied when the item is unaffordable.
@export var dim_alpha: float = 0.55

## Shadow texture laid under the item on the shelf plank.
@export var shadow_texture: Texture2D = preload("res://Assets/Images/UI/Placeholders/shadow_ellipse.png")

var _button: TextureButton
var _shadow: TextureRect
var _phase: float = 0.0
var _base_y: float = 0.0

## Wires this helper to a shelf button: adds the shadow, records the
## resting position, and picks a random bob phase.
func attach_to(button: TextureButton) -> void:
	_button = button
	_base_y = button.position.y
	_phase = randf() * TAU

	if shadow_texture and not is_instance_valid(_shadow):
		_shadow = TextureRect.new()
		_shadow.texture = shadow_texture
		_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow.modulate.a = 0.35
		_shadow.size = Vector2(button.size.x * 0.8, 18.0)
		_shadow.position = Vector2(button.size.x * 0.1, button.size.y - 6.0)
		button.add_child(_shadow)
		button.move_child(_shadow, 0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_button):
		return
	_phase += delta * TAU / bob_period
	_button.position.y = _base_y + sin(_phase) * bob_distance

## Rises and settles, for the moment the item is bought.
func lift() -> void:
	if not is_instance_valid(_button):
		return
	var tween := _button.create_tween()
	tween.tween_property(_button, "position:y", _base_y - lift_distance, lift_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "position:y", _base_y, lift_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Fades the item when its price is out of reach.
func set_dimmed(dim: bool) -> void:
	if not is_instance_valid(_button):
		return
	_button.modulate.a = dim_alpha if dim else 1.0
