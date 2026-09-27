@tool
extends Button

## One calculator key cap.
##
## The art (kalkulator_button.png) draws its own recessed skirt under the
## cap, so a press is animated as the cap squishing down ONTO that skirt --
## scale toward the bottom edge plus a darkening modulate -- rather than the
## uniform shrink UIPolish gives every other Button. Only the `Visual` child
## moves, so the Button's own hit rect never shifts under the finger.
##
## @tool so the editor shows the digit as authored. It has no _ready() side
## effects beyond its own visuals, so no Engine.is_editor_hint() guard is
## needed.

## Emitted on release, carrying this key's own character.
signal key_pressed(key_text: String)

## The character this key types. Also the label the cap shows.
@export var key_text: String = "1":
	set(value):
		key_text = value
		_sync_digit()

## Scale the cap squishes to while held. Wider than tall: a key going down
## bulges a little as it flattens.
@export var press_scale: Vector2 = Vector2(1.03, 0.88)

## Tint multiplied over the cap while held. Below 1 on every channel, so the
## key darkens rather than changing hue.
@export var press_tint: Color = Color(0.68, 0.68, 0.72, 1.0)

## Seconds the squish takes. Short: a key should feel instant.
@export var press_duration: float = 0.06

## Seconds the spring back takes. Longer than the squish, with TRANS_BACK.
@export var release_duration: float = 0.16

@onready var visual: Control = $Visual
@onready var digit_label: Label = $Visual/Digit

func _ready() -> void:
	_sync_digit()
	# One press animation, not two: UIPolish auto-juices every Button.
	set_meta(Juice.NO_AUTO_JUICE, true)
	if visual:
		visual.resized.connect(_park_pivot)
		_park_pivot()
	# Ungated on purpose: this is pure signal wiring with no side effects, and
	# the test runner lives inside the editor, where is_editor_hint() is true.
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(func(): key_pressed.emit(key_text))

## Puts the scale origin at the cap's bottom centre, so the squish presses
## the cap down onto its skirt instead of shrinking it toward its middle.
func _park_pivot() -> void:
	if is_instance_valid(visual):
		visual.pivot_offset = Vector2(visual.size.x * 0.5, visual.size.y)

func _sync_digit() -> void:
	var lbl := get_node_or_null("Visual/Digit") as Label
	if lbl:
		lbl.text = key_text

func _on_down() -> void:
	if not is_instance_valid(visual):
		return
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(visual, "scale", press_scale, press_duration)
	tw.tween_property(visual, "modulate", press_tint, press_duration)

func _on_up() -> void:
	if not is_instance_valid(visual):
		return
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", Vector2.ONE, release_duration)
	tw.tween_property(visual, "modulate", Color.WHITE, release_duration)
