@tool
class_name MinigameTutorial
extends CanvasLayer

## The CARA MAIN card a minigame shows before its first round (spec
## 2026-09-29 minigame mobile layout, 3.4): a NotebookFrame dialog with the
## game's name, two or three HowToStepRow rows from its MinigameHowTo, and a
## mint Mulai. Only Mulai closes it -- a tap on the scrim does nothing -- so
## nobody skips the card by accident. Replaces the code-built dark box of
## paragraphs; every visual is authored in MinigameTutorial.tscn or
## HowToStepRow.tscn.
##
## Affects: nothing outside itself. BaseMinigame awaits tutorial_finished.

## Emitted when the player presses Mulai.
signal tutorial_finished

## One step row, instanced per MinigameHowToStep.
const STEP_ROW := preload("res://Scenes/Minigames/UI/HowToStepRow.tscn")


func _ready() -> void:
	var mulai := get_node_or_null("%Mulai") as Button
	if mulai != null and not mulai.pressed.is_connected(_on_mulai):
		mulai.pressed.connect(_on_mulai)
	if Engine.is_editor_hint():
		return
	var frame := get_node_or_null("%Frame") as Control
	if frame != null:
		AnimUtils.popup_spring_in(frame)


## Fill the card from `how_to`: the heading and one row per step.
func setup(how_to: MinigameHowTo) -> void:
	(%GameTitle as Label).text = how_to.title if how_to != null else ""
	var steps := %Steps as VBoxContainer
	for child in steps.get_children():
		steps.remove_child(child)
		child.queue_free()
	if how_to == null:
		return
	var rows: Array = []
	for step in how_to.steps:
		var row := STEP_ROW.instantiate()
		row.icon_texture = step.icon
		row.step_text = step.text
		steps.add_child(row)
		rows.append(row)
	if not Engine.is_editor_hint():
		Juice.stagger_in(rows)


func _on_mulai() -> void:
	tutorial_finished.emit()
