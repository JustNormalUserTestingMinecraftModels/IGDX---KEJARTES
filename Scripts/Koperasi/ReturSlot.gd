@tool
extends VBoxContainer

## One item sitting in the koperasi basket tray: its art, its name and
## quantity, and the button that returns one of it to the shelf.
##
## Replaces the VBoxContainer/Label/Button that rakbarang_1.gd used to
## build at runtime with font-size overrides.

## Emitted when the player returns one of this item.
signal retur_requested(item_name: String)

@onready var _icon: TextureRect = $Icon
@onready var _caption: Label = $Caption
@onready var _button: Button = $ReturButton

var _item_name: String = ""

func _ready() -> void:
	if is_instance_valid(_button) and not _button.pressed.is_connected(_on_retur_pressed):
		_button.pressed.connect(_on_retur_pressed)

## Fills the slot from a cart entry.
func bind(item: ItemData, quantity: int) -> void:
	_ensure_nodes()
	_item_name = item.item_name
	_icon.texture = item.icon
	_caption.text = "%s ×%d" % [item.item_name, quantity]

## Reads the caption. Exists so tests need not know node paths.
func get_caption() -> String:
	_ensure_nodes()
	return _caption.text

func _on_retur_pressed() -> void:
	AnimUtils.squash_bounce(_button)
	retur_requested.emit(_item_name)

func _ensure_nodes() -> void:
	if not is_instance_valid(_icon):
		_icon = get_node_or_null("Icon")
	if not is_instance_valid(_caption):
		_caption = get_node_or_null("Caption")
	if not is_instance_valid(_button):
		_button = get_node_or_null("ReturButton")
