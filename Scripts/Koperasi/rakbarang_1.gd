extends Control  # script Stage

## The koperasi Stage (koprasi.tscn:Stage): Pak Herman's counter as one
## 1080x1920 piece -- the art layers, this week's six items on the shelf,
## each with a coin-pill price tag and a little life, the chat bubble, the
## back button and the basket tray.
##
## The shelf is rolled once a week (GameState.shop_stock_for_week()) and can
## hold up to SHOP_MAX_COPIES (3) copies of an item. Each slot
## sells once. Cart stays keyed by name, so the shelf keeps which SLOT
## emptied itself (_taken_slots) and re-derives it from Cart and
## GameState.shop_sold on every cart change (reconcile_taken()).
##
## Tapping an item puts one in Cart and flies a copy of its art, in the
## mentor-approved split arc, onto that item's own slot in the tray, and the
## item leaves the shelf. The tray (BasketTray.tscn) redraws itself from Cart;
## this script only wires the shelf, the flight and the hold-to-return gesture
## to it.
##
## Each shelf slot also carries a stock-pip badge (ShelfItem.set_stock_pips,
## PipRow in the .tscn) showing remaining_of(name) filled out of that name's
## copies on this week's shelf. remaining_of() depends only on
## _stock_names/GameState.shop_stock, GameState.shop_sold and Cart, so a
## test can call it on a bare instance that was never added to the tree
## (this script is not @tool, so _ready() never runs under the editor's
## test bridge unless the node enters a live tree).

## Emitted when a tap lands on a slot that is already taken or sold this
## week. The button is hidden the moment a slot empties
## (_refresh_shelf_visibility), so in practice this only fires for a second
## tap landing in the same frame as the first, before the hide takes
## effect -- _on_barang_pressed()'s existing "_taken_slots.has(index)" guard
## is the one reachable dead-tap path in the current UI. koprasi.gd connects
## this to Pak Herman's OUT_OF_STOCK line.
signal shelf_dead_tap(item_name: String)

@export_group("Global Settings")
## Global scale multiplier for all items (1.0 = normal)
@export var global_item_scale: float = 1.0

## The basket tray, docked at the bottom of the Stage.
@onready var tray: BasketTray = $TrayDock/BasketTray

var shelf_buttons: Array[TextureButton] = []
var item_data_list: Array[ItemData] = []

## Item name per shelf slot, parallel to item_data_list. A name can repeat
## up to SHOP_MAX_COPIES times.
var _stock_names: Array[String] = []
## Slots emptied -- tapped into the basket or sold this week -- in the order
## they emptied. Rebuilt by reconcile_taken() on every cart change.
var _taken_slots: Array[int] = []

## Instanced PriceTag per shelf button, parallel to shelf_buttons.
var _price_tags: Array = []

const PRICE_TAG_SCENE := preload("res://Scenes/Koperasi/PriceTag.tscn")
const ShelfItemScript := preload("res://Scripts/Koperasi/ShelfItem.gd")

## ShelfItem helper per shelf button, parallel to shelf_buttons.
var _shelf_items: Array = []

func _ready():
	setup_shelf()

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

## Stock the shelf buttons from this week's shelf and hide whatever is no
## longer on sale. Safe to call again: within a week it restocks the same
## items in the same slots.
func setup_shelf():
	_find_shelf_buttons()
	if shelf_buttons.is_empty():
		return

	item_data_list.clear()
	for item_name in GameState.shop_stock_for_week():
		var stocked: ItemData = ItemDatabase.get_item(item_name)
		if stocked != null:
			item_data_list.append(stocked)
	_stock_names.clear()
	for stocked in item_data_list:
		_stock_names.append(stocked.item_name)

	_shelf_items.clear()
	for i in range(shelf_buttons.size()):
		if i >= item_data_list.size():
			continue
		var btn = shelf_buttons[i]
		var item = item_data_list[i]
		btn.texture_normal = item.icon
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		# Find price tag inside btn
		var tag = _ensure_price_tag(btn)
		if tag:
			tag.set_price(Cart.price_of(item))

		var life = _ensure_shelf_item(btn)
		_shelf_items.append(life)

		# Connect click signal
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])
		btn.pressed.connect(_on_barang_pressed.bind(i))

	_price_tags.clear()
	for btn in shelf_buttons:
		_price_tags.append(btn.get_node_or_null("PriceTag"))
	_refresh_affordability()
	_refresh_shelf_visibility()
	_refresh_stock_pips()


## Which slots are empty, given what the player took (`taken`, in the order
## they took it), the basket (`cart`, Cart.cart-shaped) and this week's
## sales (`sold`, one entry per unit). For each item the empty-slot count is
## its sold units plus its basket units, capped at its copies on the shelf:
## extra slots leave from the end of `taken` (hold-to-return brings back the
## latest), missing ones are taken lowest index first (a sale from an
## earlier visit).
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func reconcile_taken(stock: Array, taken: Array, cart: Dictionary, sold: Array) -> Array[int]:
	var result: Array[int] = []
	for slot in taken:
		if slot >= 0 and slot < stock.size() and not result.has(slot):
			result.append(slot)
	var names: Array = []
	for item_name in stock:
		if not names.has(item_name):
			names.append(item_name)
	for item_name in names:
		var in_cart: int = int(cart[item_name].get("quantity", 0)) if cart.has(item_name) else 0
		var want := mini(stock.count(item_name), sold.count(item_name) + in_cart)
		var mine: Array[int] = []
		for slot in result:
			if stock[slot] == item_name:
				mine.append(slot)
		while mine.size() > want:
			result.erase(mine.pop_back())
		for slot in range(stock.size()):
			if mine.size() >= want:
				break
			if stock[slot] == item_name and not mine.has(slot):
				mine.append(slot)
				result.append(slot)
	return result


## Show each shelf slot only while it is not taken. Derived from Cart and
## GameState every time (reconcile_taken), so tap, hold-to-return, Back and
## Beli agree. A slot returning to a visible shelf bounces back in -- scale
## only, so an unaffordable item keeps ShelfItem.set_dimmed()'s alpha rather
## than fading up to full.
func _refresh_shelf_visibility() -> void:
	_taken_slots = reconcile_taken(_stock_names, _taken_slots, Cart.cart, GameState.shop_sold)
	for i in range(shelf_buttons.size()):
		var btn: TextureButton = shelf_buttons[i]
		var on_sale: bool = i < _stock_names.size() and not _taken_slots.has(i)
		var was_hidden := not btn.visible
		btn.visible = on_sale
		if on_sale and was_hidden and btn.is_visible_in_tree():
			AnimUtils.squash_bounce(btn)

## Copies of `item_name` on this week's shelf. Reads _stock_names once
## setup_shelf() has populated it; falls back to GameState.shop_stock so
## remaining_of() and the pip totals are still correct on a bare instance
## that never ran setup_shelf() (a test), or before the Stage's own
## _ready() has (a race that cannot happen in the running game, since
## GameState.shop_stock_for_week() is called synchronously inside it).
func _stock_count(item_name: String) -> int:
	if _stock_names.size() > 0:
		return _stock_names.count(item_name)
	return GameState.shop_stock.count(item_name)


## Units of `item_name` still available to tap this week: its copies on
## the shelf, minus what has sold, minus what already sits in the basket.
## Floored at 0. Depends only on _stock_names/GameState.shop_stock,
## GameState.shop_sold and Cart -- no node lookups -- so it can be called
## on a bare, untree'd instance in a test.
func remaining_of(item_name: String) -> int:
	var stock: int = _stock_count(item_name)
	var sold: int = GameState.shop_sold.count(item_name)
	var carted: int = Cart.get_quantity(item_name)
	return maxi(0, stock - sold - carted)


## Recomputes every shelf slot's stock-pip badge (remaining/total copies of
## its name on this week's shelf) through the ShelfItem helper already
## sitting under its button. Called after setup_shelf() and on every cart
## or money change, so a purchase, a hold-to-return or an affordability
## shift all keep the dots honest.
func _refresh_stock_pips() -> void:
	for i in range(_shelf_items.size()):
		if i >= _stock_names.size():
			continue
		var life = _shelf_items[i]
		if not is_instance_valid(life):
			continue
		var item_name: String = _stock_names[i]
		# Clamped to GameState.SHOP_MAX_COPIES, not a literal 3: PipRow is
		# authored with exactly Pip1..Pip3 in koprasi.tscn, so raising
		# SHOP_MAX_COPIES again needs a Pip4+ node added there too, or this
		# clamp silently keeps hiding the extra copies.
		life.set_stock_pips(remaining_of(item_name), mini(_stock_count(item_name), GameState.SHOP_MAX_COPIES))


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
		tag.set_affordable(GameState.player_money >= Cart.price_of(item_data_list[i]))
		if i < _shelf_items.size() and is_instance_valid(_shelf_items[i]):
			_shelf_items[i].set_dimmed(GameState.player_money < Cart.price_of(item_data_list[i]))

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
	_refresh_stock_pips()

## Cart.cart_changed: the tray redraws from the cart itself, and the shelf
## re-derives which items are still on sale.
func _on_cart_changed() -> void:
	if is_instance_valid(tray):
		tray.refresh(Cart.cart)
	_refresh_shelf_visibility()
	_refresh_stock_pips()

func _on_barang_pressed(index: int):
	if index < 0 or index >= item_data_list.size():
		return
	var item = item_data_list[index]
	var life = _shelf_items[index] if index < _shelf_items.size() else null
	# Each slot sells once: a second tap landing before the button hides
	# must not add a second unit. Checked BEFORE the shelf-debounce lock so
	# a dead tap always reaches Herman -- gating it behind on_tap() first
	# let a lock refusal swallow OUT_OF_STOCK / shelf_dead_tap silently.
	if _taken_slots.has(index):
		shelf_dead_tap.emit(item.item_name)
		return
	# Shelf debounce (tap-spam safeguard layer 2): a slot already mid-flight
	# ignores further taps until on_flight_finished()/the failsafe unlocks it.
	if is_instance_valid(life) and not life.on_tap():
		return
	var btn = shelf_buttons[index]

	AnimUtils.squash_bounce(btn)
	if index < _price_tags.size() and is_instance_valid(_price_tags[index]):
		_price_tags[index].play_buy()
	if index < _shelf_items.size() and is_instance_valid(_shelf_items[index]):
		_shelf_items[index].lift()
	AudioDirector.play_sfx(&"tap")

	# Take the slot before the cart hears of it, so the refresh that
	# Cart.add_item() triggers empties THIS slot, not the pair's other copy.
	_taken_slots.append(index)
	# Hold the unit before the cart hears of it: the refresh that
	# Cart.add_item() triggers then keeps it hidden until its flight lands.
	tray.hold_for_landing(item.item_name)
	if not Cart.add_item(item):
		# Cart's per-frame cap (Cart.MAX_ADDS_PER_FRAME) dropped the unit:
		# roll back everything taken above instead of flying in art for a
		# unit the cart never received.
		_taken_slots.erase(index)
		tray.release_hold(item.item_name)
		_refresh_shelf_visibility()
		if is_instance_valid(life):
			life.on_flight_finished()
		return
	_spawn_falling_item(btn, item, life)

func _spawn_falling_item(source_button: TextureButton, item: ItemData, life = null):
	if not is_instance_valid(tray):
		push_warning("BasketTray tidak ditemukan!")
		if is_instance_valid(life):
			life.on_flight_finished()
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

	tween_y.tween_callback(_on_item_landed.bind(duplikat, item, item_size, target_pos, life))

func _on_item_landed(flying_node: Node, item: ItemData, item_size: Vector2, land_pos: Vector2 = Vector2.ZERO, life = null):
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
	if is_instance_valid(life):
		life.on_flight_finished()

## A tray item was tapped or held: shrink it away, then return one to the
## shelf. Since 2026-09-21 a plain tap returns too, so this is the common
## path rather than the deliberate one.
func _on_tray_remove_requested(item_name: String) -> void:
	AnimUtils.cart_press(tray.get_emblem())
	AudioDirector.play_sfx(&"pop")
	var slot: Control = tray.get_slot(item_name)
	if slot == null or not slot.is_inside_tree():
		Cart.remove_one(item_name)
		return
	var tween := AnimUtils.shrink_and_fade(slot)
	tween.tween_callback(Cart.remove_one.bind(item_name))

## A quick tap on a tray item. Deliberately does nothing now: the wobble here
## used to say "hold me" without words, but since 2026-09-21 a tap returns the
## item outright, so there is nothing left to hint at. Worse, TraySlot emits
## remove_requested before tapped, so the wobble would land on a slot
## _on_tray_remove_requested has already started shrinking away and the two
## tweens would fight over the same node.
##
## The connection is kept rather than dropped: `tapped` is public API, and a
## listener that only wants to know the player touched a slot still gets it.
func _on_tray_slot_tapped(_item_name: String) -> void:
	pass

## Beli and Back empty the cart (the tray redraws from Cart.cart_changed);
## this forgets any unit still flying in. Kept by name: koprasi.gd calls it.
func clear_basket_visuals():
	if is_instance_valid(tray):
		tray.clear_held()
