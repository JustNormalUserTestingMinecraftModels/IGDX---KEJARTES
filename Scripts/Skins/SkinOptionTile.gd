@tool
class_name SkinOptionTile
extends Button

## One skin in the popup's option column (SkinOptionTile.tscn): a square
## bust-up of that skin's splash. A locked skin is darkened and disabled.

## Modulate applied to a locked tile.
@export var locked_tint: Color = Color(0.32, 0.32, 0.32, 1.0)

## The skin this tile stands for.
var skin_id: String = ""


func show_skin(student_name: String, id: String, locked: bool) -> void:
	skin_id = id
	var path := StudentSkins.layer_path(student_name, id, "splash")
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Frame") as SkinFrame).show_art(tex, StudentSkins.bust_center(student_name))
	disabled = locked
	modulate = locked_tint if locked else Color.WHITE
