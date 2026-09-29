@tool
class_name PauseMenu
extends Control

## A minigame's JEDA dialog (spec 2026-09-29 minigame mobile layout, 3.5):
## a NotebookFrame dialog with mint Lanjutkan, brown Pengaturan and tomato
## Keluar. Every visual is authored in PauseMenu.tscn; UIPolish juices the
## buttons. Replaces the dark box and its texture/colour @exports.
##
## Affects: nothing outside itself. BaseMinigame listens to the signals.

## The player wants to keep playing.
signal resume_pressed
## The player opened Pengaturan.
signal settings_pressed
## The player chose Keluar (BaseMinigame then asks KELUAR?).
signal quit_pressed


func _ready() -> void:
	_wire(%BtnResume as Button, resume_pressed)
	_wire(%BtnSettings as Button, settings_pressed)
	_wire(%BtnQuit as Button, quit_pressed)
	if Engine.is_editor_hint():
		return
	AnimUtils.popup_spring_in(%Frame as Control)


## Pure signal wiring, ungated so tests can press the buttons.
func _wire(button: Button, relay: Signal) -> void:
	if not button.pressed.is_connected(relay.emit):
		button.pressed.connect(relay.emit)
