@tool
class_name ContinuePopup
extends CanvasLayer

## The title screen's "carry on or start over" dialog (2026-10-01 save
## system). Two pages in one NotebookFrame: Ask (Lanjutkan / Permainan baru)
## and Confirm (Ya, mulai baru / Batal). It decides nothing itself: MainMenu
## listens to continue_chosen / new_game_chosen and routes.

## Ya, lanjutkan.
signal continue_chosen
## Ya, mulai baru, after the confirm page.
signal new_game_chosen
## Closed from the Ask page without choosing (Android back).
signal dismissed

@onready var _ask: Control = $Scrim/Safe/Center/Frame/Layout/Ask
@onready var _confirm: Control = $Scrim/Safe/Center/Frame/Layout/Confirm
@onready var _summary: Label = $Scrim/Safe/Center/Frame/Layout/Ask/Summary
@onready var _frame: Control = $Scrim/Safe/Center/Frame


func _ready() -> void:
	# Pure wiring, ungated, so the suite can press the buttons.
	$Scrim/Safe/Center/Frame/Layout/Ask/Buttons/ContinueButton.pressed.connect(
		func() -> void: continue_chosen.emit())
	$Scrim/Safe/Center/Frame/Layout/Ask/Buttons/NewButton.pressed.connect(
		func() -> void: show_confirm(true))
	$Scrim/Safe/Center/Frame/Layout/Confirm/Buttons/CancelButton.pressed.connect(
		func() -> void: show_confirm(false))
	$Scrim/Safe/Center/Frame/Layout/Confirm/Buttons/ConfirmButton.pressed.connect(
		func() -> void: new_game_chosen.emit())


## Shows the dialog on its Ask page with the save's summary line.
func open(summary_text: String) -> void:
	_summary.text = summary_text
	show_confirm(false)
	visible = true
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"popup_open")
	Juice.pop_in(_frame)


## Hides the dialog.
func close() -> void:
	visible = false


## Swaps between the Ask page (false) and the Confirm page (true).
func show_confirm(on: bool) -> void:
	_ask.visible = not on
	_confirm.visible = on


## Android back: Confirm steps back to Ask; Ask closes.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not visible:
		return
	if _confirm.visible:
		show_confirm(false)
	else:
		close()
		dismissed.emit()
