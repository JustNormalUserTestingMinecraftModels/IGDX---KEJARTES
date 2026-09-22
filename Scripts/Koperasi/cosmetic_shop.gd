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


## Android delivers the hardware/gesture back press as a notification, not as
## ui_cancel, so an _input handler never sees it. Routed to the same function
## the on-screen back button calls, so both do exactly the same thing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	Transition.change_scene(back_scene_path, Transition.Style.WIPE)
