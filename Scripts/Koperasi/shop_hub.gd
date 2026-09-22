extends Control

## The fork between the two shops.
##
## The Lobby's shop button used to drop straight into the Koperasi. It
## now lands here, which splits consumables from cosmetics and gives the
## cosmetic shop somewhere to exist before it is built.
##
## The backdrop is the Koperasi's own artwork behind the project's
## existing screen-space blur shader, so this screen needs no image asset
## of its own and reads plainly as "the shop, out of focus". Both the
## blur strength and the dim live on the shader material in the scene.

## Where the "Makanan & Barang" tile leads.
@export var items_scene_path: String = "res://Scenes/Koperasi/koprasi.tscn"
## Where the "Kosmetik" tile leads.
@export var cosmetics_scene_path: String = "res://Scenes/Koperasi/CosmeticShop.tscn"
## Where the back button leads.
@export var back_scene_path: String = "res://Scenes/Lobby/loby.tscn"

@onready var items_tile: Button = $Tiles/ItemsTile
@onready var cosmetics_tile: Button = $Tiles/CosmeticsTile
@onready var back_button: Button = $BackButton


func _ready() -> void:
	items_tile.pressed.connect(_on_items_pressed)
	cosmetics_tile.pressed.connect(_on_cosmetics_pressed)
	back_button.pressed.connect(_on_back_pressed)
	# Not in the editor: pop_in starts a node at zero alpha and 0.82 scale, so
	# a suite that stands this screen up would measure a tile that has not
	# arrived yet. play_entrance() is public so a test can drive it instead.
	if not Engine.is_editor_hint():
		play_entrance()


## Cascades the two shop tiles in.
##
## This screen is two big choices and nothing else, so staggering them reads
## as the fork offering them one after the other rather than as a page that
## simply exists. UIPolish already gives every button press-scale and a tap
## SFX for free, so what this screen was missing was never the press -- it
## was the entrance.
func play_entrance() -> void:
	Juice.stagger_in([items_tile, cosmetics_tile])


func _on_items_pressed() -> void:
	AudioDirector.play_sfx(&"select")
	Transition.change_scene(items_scene_path, Transition.Style.WIPE)


func _on_cosmetics_pressed() -> void:
	AudioDirector.play_sfx(&"select")
	Transition.change_scene(cosmetics_scene_path, Transition.Style.WIPE)


## Android delivers the hardware/gesture back press as a notification, not as
## ui_cancel, so an _input handler never sees it. Routed to the same function
## the on-screen back button calls, so both do exactly the same thing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _on_back_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	Transition.change_scene(back_scene_path, Transition.Style.WIPE)
