extends Control

## The cosmetic shop, deliberately unbuilt.
##
## Ships as a backdrop, a heading and a back button so the hub's second
## tile leads somewhere rather than nowhere. Everything else waits on a
## design pass -- see the outstanding-debt entry in CLAUDE.md.

## Where the back button leads. The hub, not the Lobby: the player came
## from the hub and expects to land back on it.
@export var back_scene_path: String = "res://Scenes/Koperasi/ShopHub.tscn"

@onready var back_button: Button = $BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	Transition.change_scene(back_scene_path, Transition.Style.WIPE)
