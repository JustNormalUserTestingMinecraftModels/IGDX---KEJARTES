@tool
class_name QuitConfirmDialog
extends CanvasLayer

## The KELUAR? confirmation a minigame's JEDA dialog opens (spec 2026-09-29
## minigame mobile layout, 3.5): a NotebookFrame dialog whose safe choice,
## "Tidak, lanjut main", is mint and on top, and whose destructive choice,
## "Ya, keluar", is tomato. Every visual is authored in the .tscn; the old
## configure() and its texture/colour arguments are gone.
##
## Affects: nothing outside itself. BaseMinigame decides what the signals
## mean (abandon_game() / re-show JEDA).

## The player confirmed quitting.
signal confirmed
## The player backed out.
signal cancelled


func _ready() -> void:
	var yes := %YesButton as Button
	var no := %NoButton as Button
	if not yes.pressed.is_connected(confirmed.emit):
		yes.pressed.connect(confirmed.emit)
	if not no.pressed.is_connected(cancelled.emit):
		no.pressed.connect(cancelled.emit)
	if Engine.is_editor_hint():
		return
	AnimUtils.popup_spring_in(%Frame as Control)
