@tool
extends HBoxContainer

## One CARA MAIN step (spec 2026-09-29 minigame mobile layout, 3.4): a 96px
## picture and one body-face line. A template: MinigameTutorial instances
## one per MinigameHowToStep, so no row is built from code. The content
## arrives through these root @exports, because an instance's children drop
## their overrides on save.

## The step's picture.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply()
## The step's line.
@export var step_text: String = "":
	set(value):
		step_text = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	(%Icon as TextureRect).texture = icon_texture
	(%Text as Label).text = step_text
