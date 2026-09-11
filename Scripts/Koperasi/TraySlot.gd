@tool
class_name TraySlot
extends Control

## One item standing in the koperasi basket tray: its art at the item's own
## height, a soft shadow where it meets the plank, and a ×N badge on its
## corner. BasketTray sizes and places it; the slot only knows its own shape.
##
## Hold it to return one to the shelf -- the gesture the basket always had,
## moved here from rakbarang_1.gd's _on_item_icon_input when the tray
## replaced the basket popup. A right-click returns one at once.

## Emitted when the player holds the item long enough to return one.
signal remove_requested(item_name: String)
## Emitted on a quick tap, which the shop answers with a nudge.
signal tapped(item_name: String)

## Seconds a press must last to count as hold-to-return.
@export var hold_seconds: float = 0.35
## Pixels a finger may drift before a press counts as neither hold nor tap.
@export var hold_slop: float = 30.0
## Scale the item swells to while held -- the press feedback.
@export var hold_scale: float = 1.15

## The item's own size in the tray, before BasketTray fits the row.
var natural_size: Vector2 = Vector2(200.0, 200.0)

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Badge/Count

var _item_name: String = ""
var _press_msec: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _press_tween: Tween


## Fills the slot from a cart line. Height is the item's authored display
## height; width follows the art's own aspect, so the art fills the slot and
## its bottom edge is the item's foot on the plank.
func bind(item: ItemData, quantity: int) -> void:
	_ensure_nodes()
	_item_name = item.item_name
	var art := _cropped(item.icon)
	_icon.texture = art
	var h: float = item.display_size.y if item.display_size.y > 0.0 else 200.0
	var w: float = item.display_size.x if item.display_size.x > 0.0 else h
	if art != null and art.get_height() > 0:
		w = h * float(art.get_width()) / float(art.get_height())
	natural_size = Vector2(w, h)
	set_quantity(quantity)


## Crops keyed by source texture, so a line re-bound on every refresh never
## decodes its image twice.
static var _crops: Dictionary = {}


## The art cropped to its opaque pixels. Item PNGs carry transparent
## padding, and padded art floats above the plank with its badge adrift; the
## crop puts the art's own foot on the plank. An AtlasTexture is a resource,
## not a node, so nothing visual is built here. Art with no opaque pixel,
## nothing to trim, or an unreadable image comes back as it was.
static func _cropped(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _crops.has(tex):
		return _crops[tex]
	var out: Texture2D = tex
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0 and used.size != img.get_size():
			var crop := AtlasTexture.new()
			crop.atlas = tex
			crop.region = Rect2(used)
			out = crop
	_crops[tex] = out
	return out


## Updates the ×N badge.
func set_quantity(quantity: int) -> void:
	_ensure_nodes()
	_count.text = "×%d" % quantity


## Reads the badge. Exists so tests need not know node paths.
func get_badge_text() -> String:
	_ensure_nodes()
	return _count.text


## The cart key this slot shows.
func get_item_name() -> String:
	return _item_name


## What a released press meant: &"hold" returns one, &"tap" nudges, &"none"
## was a drag. Pure, so the gesture's rule is testable without waiting.
static func classify_release(held_seconds: float, drift: float,
		hold_threshold: float, slop: float) -> StringName:
	if drift >= slop:
		return &"none"
	return &"hold" if held_seconds >= hold_threshold else &"tap"


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		accept_event()
		remove_requested.emit(_item_name)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_begin_press(button.global_position)
		elif _press_msec >= 0:
			_end_press(button.global_position)


func _begin_press(at: Vector2) -> void:
	_press_msec = Time.get_ticks_msec()
	_press_pos = at
	pivot_offset = size / 2.0
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE * hold_scale, hold_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _end_press(at: Vector2) -> void:
	var held := (Time.get_ticks_msec() - _press_msec) / 1000.0
	_press_msec = -1
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	scale = Vector2.ONE
	match classify_release(held, _press_pos.distance_to(at), hold_seconds, hold_slop):
		&"hold":
			remove_requested.emit(_item_name)
		&"tap":
			tapped.emit(_item_name)


## Resolves @onready nodes when a method runs before _ready.
func _ensure_nodes() -> void:
	if not is_instance_valid(_icon):
		_icon = get_node_or_null("Icon")
	if not is_instance_valid(_count):
		_count = get_node_or_null("Badge/Count")
