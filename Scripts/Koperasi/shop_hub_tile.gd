@tool
extends Button
class_name ShopHubTile

## One destination tile on the shop hub: a big icon over a caption.
##
## The icon and caption are @exports on this root rather than properties
## poked into the instance's children, because Godot only serialises
## overrides on an instanced scene's own root unless the instance is
## marked editable. Setting them here keeps ShopHub.tscn readable and
## keeps the tile a single configurable unit.
##
## @tool, so both tiles show their real art in the editor viewport.

## The glyph shown above the caption. A real transparent SVG -- this
## project does not use emoji as iconography.
@export var icon_texture: Texture2D = null:
	set(value):
		icon_texture = value
		_apply()

## The tile's label. Indonesian, like every other game-facing string.
@export var caption_text: String = "":
	set(value):
		caption_text = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var icon := get_node_or_null("Content/Icon") as TextureRect
	if icon != null and icon_texture != null:
		icon.texture = icon_texture
	var caption := get_node_or_null("Content/Caption") as Label
	if caption != null and caption_text != "":
		caption.text = caption_text
