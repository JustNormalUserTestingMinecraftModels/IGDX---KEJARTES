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
	_spring_in.call_deferred()


## Pure signal wiring, ungated so tests can press the buttons.
func _wire(button: Button, relay: Signal) -> void:
	if not button.pressed.is_connected(relay.emit):
		button.pressed.connect(relay.emit)


## Springs the frame in once its CenterContainer's first layout pass has run:
## that pass resets scale and rotation and only then gives the frame a size
## for the pivot. Deferred from _ready(); a node freed in its opening frame
## just drops the call (same approach as ItemDetailSheet).
func _spring_in() -> void:
	var frame := get_node_or_null("%Frame") as Control
	if frame != null:
		AnimUtils.popup_spring_in(frame)
