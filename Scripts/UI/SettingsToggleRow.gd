@tool
extends HBoxContainer

## One Settings on/off row: a BodyLabel on the left and a SettingsSwitch on
## the right (Scenes/UI/SettingsToggleRow.tscn). Settings.tscn instances it
## once per switch and wires `toggle` itself, so the row stays generic. The
## words live in `label_text` on the ROOT, because an instance's children do
## not keep overrides when the scene is saved.

## The row's words, e.g. "Tutorial Minigame". Shown in the editor too.
@export var label_text: String = "":
	set(value):
		label_text = value
		if is_node_ready():
			_apply_label()

## The row's switch. Settings.gd connects to its `toggled` signal.
var toggle: CheckButton:
	get:
		return get_node_or_null("Toggle") as CheckButton


func _ready() -> void:
	_apply_label()


func _apply_label() -> void:
	($Label as Label).text = label_text
