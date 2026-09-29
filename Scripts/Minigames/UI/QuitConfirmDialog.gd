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
	_spring_in.call_deferred()


## Springs the frame in once its CenterContainer's first layout pass has run:
## that pass resets scale and rotation and only then gives the frame a size
## for the pivot. Deferred from _ready(); a node freed in its opening frame
## just drops the call (same approach as ItemDetailSheet).
func _spring_in() -> void:
	var frame := get_node_or_null("%Frame") as Control
	if frame != null:
		AnimUtils.popup_spring_in(frame)
