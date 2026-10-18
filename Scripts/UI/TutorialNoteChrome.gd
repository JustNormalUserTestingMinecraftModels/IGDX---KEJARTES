@tool
class_name TutorialNoteChrome
extends Control

## The Nota Guru's chrome, shared by every tutorial box (spec 2026-10-16
## section 2, "consistent, not identical"): the torn edge and paperclip on the
## note's top, the PAK KEPSEK name tab at its top right, and Pak Kepsek himself
## standing over its top-left corner (placeholder art: DEBT.md, "Tutorial
## art"). TutorialPanel, TutorialComic and MinigameTutorial each instance this
## scene over their own note, so the three boxes wear one frame.
##
## Instance it as a Full Rect child of the note it decorates; every piece is
## placed against this Control's own rect. The mascot stands MASCOT_HEAD_ROOM
## px above the top edge, which is the room a caller must leave above the note
## (TutorialPanel.placement()'s `head_room`).
##
## Set the instance's exports on its root; overrides on an instanced scene's
## children are dropped on save (CLAUDE.md 4b).

## How far the mascot stands above the note's top edge, px: its full height.
## TutorialPanel.placement() keeps this much room above every card.
const MASCOT_HEAD_ROOM := 196.0

## Who the name tab names: the one voice of every tutorial in the game.
@export var speaker_name: String = "Pak Kepsek":
	set(value):
		speaker_name = value
		if is_node_ready():
			name_tab_label.text = value

## Whether the name tab shows. TutorialPanel hides it while a headmaster
## beat's own name plate names the speaker.
@export var show_name_tab: bool = true:
	set(value):
		show_name_tab = value
		if is_node_ready():
			name_tab.visible = value

## Pak Kepsek's face: 0 warm, 1 stern, 2 proud (TutorialPanel.Face's order).
@export_enum("Senang", "Serius", "Bangga") var expression: int = 0:
	set(value):
		expression = value
		if is_node_ready():
			_apply_expression()

## The mascot's warm face (placeholder: DEBT.md, "Tutorial art").
@export var mascot_senang: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/kepsek/kepsek_senang.svg")
## The mascot's stern face.
@export var mascot_serius: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/kepsek/kepsek_serius.svg")
## The mascot's proud face.
@export var mascot_bangga: Texture2D = preload("res://Assets/Images/UI/Placeholders/tutorial/kepsek/kepsek_bangga.svg")

@onready var name_tab: PanelContainer = $NameTab
@onready var name_tab_label: Label = $NameTab/NameTabLabel
@onready var mascot: TextureRect = $Mascot


func _ready() -> void:
	name_tab_label.text = speaker_name
	name_tab.visible = show_name_tab
	_apply_expression()


## Puts the face `expression` names on the mascot.
func _apply_expression() -> void:
	match expression:
		1:
			mascot.texture = mascot_serius
		2:
			mascot.texture = mascot_bangga
		_:
			mascot.texture = mascot_senang
