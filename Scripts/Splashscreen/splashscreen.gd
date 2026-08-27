@tool
extends Control

## @tool note: mirrors Scripts/MainMenu/main_menu.gd's established pattern.
## The MCP test suite instantiates this scene from inside the editor
## process (tests/test_boot_screens.gd); without @tool the script becomes
## a placeholder instance, which broke MainMenu's equivalent traversal
## checks (see main_menu.gd's header note). Engine.is_editor_hint() is
## true both when a human has this scene open in the editor and when the
## test suite instantiates it, so the pop-in/pulse tweens -- runtime-only
## motion -- sit behind that guard. _input() stays unguarded: Control
## nodes edited in the editor never receive real game input events, so
## there is nothing to gate there.

@onready var _title: Label = $SafeArea/Layout/TitleLabel
@onready var _hint: Label = $SafeArea/Layout/HintLabel

var _already_clicked := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	AudioDirector.play_bgm(&"titlescreen")
	Juice.pop_in(_title)
	var tw := _hint.create_tween().set_loops()
	tw.tween_property(_hint, "modulate:a", 0.35, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_hint, "modulate:a", 1.0, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)


func _input(event: InputEvent) -> void:
	if _already_clicked:
		return
	if event is InputEventScreenTouch and event.pressed:
		_go_to_loading()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_loading()


func _go_to_loading() -> void:
	_already_clicked = true
	GameState.next_scene = "res://Scenes/MainMenu/main_menu.tscn"
	Transition.change_scene("res://Scenes/Loading/loading.tscn")
