@tool
class_name ResetProgressPopup
extends CanvasLayer

## Settings' "Reset Progres" confirm (2026-10-01): one page in a
## NotebookFrame asking "Apakah Anda yakin?" over Batal / Ya, Reset. Built
## like ContinuePopup's Confirm page, and like it decides nothing itself:
## Settings listens to reset_confirmed, wipes the run and routes. Batal (and
## Android back, which Settings forwards to close()) only closes it.

## Ya, Reset.
signal reset_confirmed

@onready var _frame: Control = $Scrim/Safe/Center/Frame

## Frames the card stays hidden before it pops in. The popup is hidden from
## launch, so its first layout takes two passes (the autowrapped lines learn
## their width only after their height was computed); ContinuePopup measured
## the same, live, 2026-10-01.
const LAYOUT_PASSES := 2


func _ready() -> void:
	# Pure wiring, ungated, so the suite can press the buttons.
	$Scrim/Safe/Center/Frame/Layout/Confirm/Buttons/CancelButton.pressed.connect(close)
	$Scrim/Safe/Center/Frame/Layout/Confirm/Buttons/ConfirmButton.pressed.connect(
		func() -> void: reset_confirmed.emit())
	_frame.resized.connect(_center_pivot)


## Keeps the card's scale pivot at its centre through every resize, so the
## pop-in never zooms from a pre-layout size (ContinuePopup's first-open bug).
func _center_pivot() -> void:
	Juice.set_pivot_center(_frame)


## Shows the dialog. The card stays hidden (alpha 0) through the first
## layout's LAYOUT_PASSES frames, then pops in about its centre. In the editor
## (tests) it only shows, so a test never leaves a coroutine behind.
func open() -> void:
	visible = true
	if Engine.is_editor_hint():
		return
	_frame.modulate.a = 0.0
	AudioDirector.play_sfx(&"popup_open")
	for _pass in LAYOUT_PASSES:
		await get_tree().process_frame
	# Batal or back may have closed it meanwhile.
	if not visible or not is_instance_valid(_frame):
		return
	Juice.pop_in(_frame)


## Hides the dialog.
func close() -> void:
	visible = false
