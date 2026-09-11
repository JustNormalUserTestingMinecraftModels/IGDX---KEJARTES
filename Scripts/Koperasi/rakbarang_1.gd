extends Control  # script Rak1

## The koperasi shelf screen (koprasi.tscn:Rak1): four random items on the
## shelf, each with a coin-pill price tag and a little life, and the basket
## tray docked beneath them.
##
## Tapping an item puts one in Cart and flies a copy of its art, in the
## mentor-approved split arc, onto that item's own slot in the tray. The tray
## (BasketTray.tscn) redraws itself from Cart; this script only wires the
## shelf, the flight and the hold-to-return gesture to it.

@export_group("Global Settings")
## Global scale multiplier for all items (1.0 = normal)
@export var global_item_scale: float = 1.0

## The basket tray docked at the bottom of the shelf screen.
@onready var tray: BasketTray = $BasketTray

var shelf_buttons: Array[TextureButton] = []
var item_data_list: Array[ItemData] = []

## Instanced PriceTag per shelf button, parallel to shelf_buttons.
var _price_tags: Array = []

const PRICE_TAG_SCENE := preload("res://Scenes/Koperasi/PriceTag.tscn")
const ShelfItemScript := preload("res://Scripts/Koperasi/ShelfItem.gd")

## ShelfItem helper per shelf button, parallel to shelf_buttons.
var _shelf_items: Array = []

func _ready():
	setup_random_items()

	if not Cart.cart_changed.is_connected(_on_cart_changed):
		Cart.cart_changed.connect(_on_cart_changed)
	if not GameState.money_changed.is_connected(_on_money_changed_refresh):
		GameState.money_changed.connect(_on_money_changed_refresh)
	if is_instance_valid(tray):
		if not tray.remove_requested.is_connected(_on_tray_remove_requested):
			tray.remove_requested.connect(_on_tray_remove_requested)
		if not tray.slot_tapped.is_connected(_on_tray_slot_tapped):
			tray.slot_tapped.connect(_on_tray_slot_tapped)
	_on_cart_changed()

func _find_shelf_buttons():
	shelf_buttons.clear()
	for child in get_children():
		if child is TextureButton and child.name.begins_with("Barang"):
			shelf_buttons.append(child)
	shelf_buttons.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)

func setup_random_items():
	_find_shelf_buttons()
	if shelf_buttons.is_empty():
		return

	item_data_list = ItemDatabase.get_random_items(shelf_buttons.size())

	_shelf_items.clear()
	for i in range(shelf_buttons.size()):
		var btn = shelf_buttons[i]
		if i < item_data_list.size():
			var item = item_data_list[i]
			btn.show()
			btn.texture_normal = item.icon
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

			# Find price tag inside btn
			var tag = _ensure_price_tag(btn)
			if tag:
				tag.set_price(item.price)

			var life = _ensure_shelf_item(btn)
			_shelf_items.append(life)

			# Connect click signal
			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn["callable"])
			btn.pressed.connect(_on_barang_pressed.bind(i))
		else:
			btn.hide()

	_price_tags.clear()
	for btn in shelf_buttons:
		_price_tags.append(btn.get_node_or_null("PriceTag"))
	_refresh_affordability()

func _find_price_display(btn: TextureButton) -> Node:
	for child in btn.get_children():
		if child is Button or child is Label:
			return child
	return null

## Returns the PriceTag under a shelf button, instancing it on first use
## and freeing whatever placeholder label or button the scene shipped with.
func _ensure_price_tag(btn: TextureButton) -> Node:
	var existing = btn.get_node_or_null("PriceTag")
	if existing:
		return existing
	var legacy = _find_price_display(btn)
	if legacy:
		legacy.queue_free()
	var tag = PRICE_TAG_SCENE.instantiate()
	tag.name = "PriceTag"
	btn.add_child(tag)
	return tag

## Returns the ShelfItem helper under a shelf button, instancing it on first
## use and re-attaching it (re-sampling the resting position) otherwise, so
## repeated calls to setup_random_items() never pile up extra helper nodes.
func _ensure_shelf_item(btn: TextureButton) -> Node:
	var existing = btn.get_node_or_null("ShelfItem")
	if existing:
		existing.attach_to(btn)
		return existing
	var life = ShelfItemScript.new()
	life.name = "ShelfItem"
	btn.add_child(life)
	life.attach_to(btn)
	return life

## Greys out tags for items the player cannot currently afford.
func _refresh_affordability() -> void:
	for i in range(_price_tags.size()):
		var tag = _price_tags[i]
		if not is_instance_valid(tag) or i >= item_data_list.size():
			continue
		tag.set_affordable(GameState.player_money >= item_data_list[i].price)
		if i < _shelf_items.size() and is_instance_valid(_shelf_items[i]):
			_shelf_items[i].set_dimmed(GameState.player_money < item_data_list[i].price)

## Returns the display size for an item. Uses ItemData.display_size, falls back to source button size or default.
func get_item_effective_size(item: ItemData, source_button: TextureButton = null) -> Vector2:
	if item.display_size != Vector2.ZERO:
		return item.display_size * global_item_scale
	if source_button != null and source_button.size != Vector2.ZERO:
		return source_button.size * global_item_scale
	return Vector2(200, 200) * global_item_scale

## GameState.money_changed passes the new amount; affordability recomputes
## from GameState directly, so the argument is unused.
func _on_money_changed_refresh(_new_amount: int) -> void:
	_refresh_affordability()

## Cart.cart_changed: the tray redraws from the cart itself.
func _on_cart_changed() -> void:
	if is_instance_valid(tray):
		tray.refresh(Cart.cart)

func _on_barang_pressed(index: int):
	if index < 0 or index >= item_data_list.size():
		return
	var item = item_data_list[index]
	var btn = shelf_buttons[index]

	AnimUtils.squash_bounce(btn)
	if index < _price_tags.size() and is_instance_valid(_price_tags[index]):
		_price_tags[index].play_buy()
	if index < _shelf_items.size() and is_instance_valid(_shelf_items[index]):
		_shelf_items[index].lift()
	AudioDirector.play_sfx(&"tap")

	# Hold the unit before the cart hears of it: the refresh that
	# Cart.add_item() triggers then keeps it hidden until its flight lands.
	tray.hold_for_landing(item.item_name)
	Cart.add_item(item)
	_spawn_falling_item(btn, item)

func _spawn_falling_item(source_button: TextureButton, item: ItemData):
	if not is_instance_valid(tray):
		push_warning("BasketTray tidak ditemukan!")
		return

	# Use exact size configured in ItemData
	var item_size: Vector2 = get_item_effective_size(item, source_button)

	var duplikat = TextureRect.new()
	duplikat.texture = item.icon
	duplikat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	duplikat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	duplikat.size = item_size
	duplikat.custom_minimum_size = item_size
	duplikat.pivot_offset = item_size / 2
	duplikat.global_position = source_button.global_position + (source_button.size - item_size) / 2

	get_tree().current_scene.add_child(duplikat)

	var start_pos = duplikat.global_position
	# Land centred on the item's own slot in the tray.
	var slot_rect: Rect2 = tray.landing_rect_for(item.item_name)
	var target_pos = slot_rect.position + (slot_rect.size - item_size) / 2

	# Playful arc trajectory + tumble
	var tween_x = create_tween()
	tween_x.tween_property(duplikat, "global_position:x", target_pos.x, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	var tween_y = create_tween()
	var mid_y = min(start_pos.y, target_pos.y) - 50.0
	tween_y.tween_property(duplikat, "global_position:y", mid_y, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(duplikat, "global_position:y", target_pos.y, 0.31)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var tween_rot = create_tween()
	var tumble_angle = randf_range(-20.0, 20.0)
	tween_rot.tween_property(duplikat, "rotation_degrees", tumble_angle, 0.45)

	tween_y.tween_callback(_on_item_landed.bind(duplikat, item, item_size, target_pos))

func _on_item_landed(flying_node: Node, item: ItemData, item_size: Vector2, land_pos: Vector2 = Vector2.ZERO):
	flying_node.queue_free()
	tray.land(item.item_name)
	AnimUtils.basket_bounce(tray.get_emblem())
	AudioDirector.play_sfx(&"pop")
	AnimUtils.create_floating_text(
		get_tree().current_scene,
		"+1 " + item.item_name,
		land_pos + item_size / 2,
		Color(1.0, 0.9, 0.2)
	)

## A tray item was held: shrink it away, then return one to the shelf.
func _on_tray_remove_requested(item_name: String) -> void:
	AnimUtils.cart_press(tray.get_emblem())
	AudioDirector.play_sfx(&"pop")
	var slot: Control = tray.get_slot(item_name)
	if slot == null or not slot.is_inside_tree():
		Cart.remove_one(item_name)
		return
	var tween := AnimUtils.shrink_and_fade(slot)
	tween.tween_callback(Cart.remove_one.bind(item_name))

## A quick tap on a tray item: a wobble says "hold me" without words.
func _on_tray_slot_tapped(item_name: String) -> void:
	var slot: Control = tray.get_slot(item_name)
	if slot != null:
		AnimUtils.wobble(slot)

## Beli and Back empty the cart (the tray redraws from Cart.cart_changed);
## this forgets any unit still flying in. Kept by name: koprasi.gd calls it.
func clear_basket_visuals():
	if is_instance_valid(tray):
		tray.clear_held()
