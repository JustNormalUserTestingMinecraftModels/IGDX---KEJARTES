@tool
extends CanvasLayer
class_name HapticIndicator

## Desktop-only debug pip for haptics. The phone's motor can't be seen, so on
## PC a haptic call flashes this labelled chip (e.g. "HAPTIC · Pop · 20ms") in
## the top-right corner and fades it out. It never appears on a device build,
## where the player feels the motor instead. Purely a developer aid.

@onready var _text: Label = $Pip/Text
@onready var _pip: Panel = $Pip

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_pip.modulate.a = 0.0

## Flash the chip with `msg`, then fade it. Safe to call repeatedly.
func flash(msg: String) -> void:
	if Engine.is_editor_hint() or _text == null:
		return
	_text.text = msg
	_pip.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_pip, "modulate:a", 0.0, 0.4)
