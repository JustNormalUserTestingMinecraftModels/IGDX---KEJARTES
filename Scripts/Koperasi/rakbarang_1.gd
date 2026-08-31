extends Control  # script Rak1

@export_group("Global Settings")
## Global scale multiplier for all items (1.0 = normal)
@export var global_item_scale: float = 1.0

@onready var keranjang: Control = $Keranjang
@onready var total_label: Label = $Label

var basket_area: Control
var keranjang_depan: Control
var retur_panel: Control
var retur_grid: GridContainer
var retur_back_button: TextureButton

var shelf_buttons: Array[TextureButton] = []
var item_data_list: Array[ItemData] = []
var basket_visuals: Dictionary = {}  # item_name -> Array[Node]
var retur_original_parent: Node

## Permanent shop chrome (koprasi.tscn:Rak1/BlurLayer, Rak1/PopupLayer) --
## dim/blur backdrop and the layer the shop reparents ReturPanel into
## while it's open. Built once in the scene, just shown/hidden here.
@onready var blur_layer: CanvasLayer = $BlurLayer
@onready var input_blocker: ColorRect = $BlurLayer/InputBlocker
@onready var popup_layer: CanvasLayer = $PopupLayer
@onready var popup_container: Control = $PopupLayer/PopupContainer

func _ready():
	_resolve_nodes()
	setup_random_items()

	if keranjang_depan:
		keranjang_depan.z_index = 100
		keranjang_depan.mouse_filter = Control.MOUSE_FILTER_STOP
		if not keranjang_depan.gui_input.is_connected(_on_keranjang_input):
			keranjang_depan.gui_input.connect(_on_keranjang_input)
	if basket_area:
		basket_area.z_index = 0
		basket_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not Cart.cart_changed.is_connected(_update_total_label):
		Cart.cart_changed.connect(_update_total_label)
	_update_total_label()

	# Klik area keranjang untuk buka panel retur
	if keranjang:
		keranjang.mouse_filter = Control.MOUSE_FILTER_STOP
		if not keranjang.gui_input.is_connected(_on_keranjang_input):
			keranjang.gui_input.connect(_on_keranjang_input)

	if retur_panel:
		retur_panel.hide()

	# Wire the back button on the popup
	if retur_back_button and not retur_back_button.pressed.is_connected(_on_retur_back_pressed):
		retur_back_button.pressed.connect(_on_retur_back_pressed)

func _resolve_nodes():
	basket_area = find_child("BasketArea", true, false)
	keranjang_depan = find_child("KeranjangDepan", true, false)
	retur_panel = find_child("ReturPanel", true, false)
	if retur_panel:
		retur_original_parent = retur_panel.get_parent()
		retur_grid = retur_panel.find_child("GridContainer", true, false)
		retur_back_button = retur_panel.find_child("BackButton", true, false)

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

	for i in range(shelf_buttons.size()):
		var btn = shelf_buttons[i]
		if i < item_data_list.size():
			var item = item_data_list[i]
			btn.show()
			btn.texture_normal = item.icon
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

			# Find price label / button inside btn
			var price_node = _find_price_display(btn)
			if price_node:
				price_node.text = "%d" % item.price

			# Connect click signal
			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn["callable"])
			btn.pressed.connect(_on_barang_pressed.bind(i))
		else:
			btn.hide()

func _find_price_display(btn: TextureButton) -> Node:
	for child in btn.get_children():
		if child is Button or child is Label:
			return child
	return null

## Returns the display size for an item. Uses ItemData.display_size, falls back to source button size or default.
func get_item_effective_size(item: ItemData, source_button: TextureButton = null) -> Vector2:
	if item.display_size != Vector2.ZERO:
		return item.display_size * global_item_scale
	if source_button != null and source_button.size != Vector2.ZERO:
		return source_button.size * global_item_scale
	return Vector2(200, 200) * global_item_scale

func _update_total_label():
	if not is_instance_valid(total_label):
		return
	if Cart.is_empty():
		total_label.text = ""
	else:
		total_label.text = "Total: %d koin (%d item)" % [Cart.get_total(), Cart.get_item_count()]

func _on_barang_pressed(index: int):
	if index < 0 or index >= item_data_list.size():
		return
	var item = item_data_list[index]
	var btn = shelf_buttons[index]

	AnimUtils.squash_bounce(btn)
	AudioDirector.play_sfx(&"tap")

	Cart.add_item(item)
	_spawn_falling_item(btn, item)

func _spawn_falling_item(source_button: TextureButton, item: ItemData):
	if not is_instance_valid(keranjang):
		push_warning("Node keranjang tidak ditemukan!")
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
	var target_pos = keranjang.global_position + (keranjang.size - item_size) / 2

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
	_add_item_visual(item, item_size)
	AnimUtils.basket_bounce(keranjang)
	AudioDirector.play_sfx(&"pop")
	AnimUtils.create_floating_text(
		get_tree().current_scene,
		"+1 " + item.item_name,
		land_pos + item_size / 2,
		Color(1.0, 0.9, 0.2)
	)

func _add_item_visual(item: ItemData, item_size: Vector2):
	if not is_instance_valid(basket_area):
		return

	var icon_node = TextureRect.new()
	icon_node.texture = item.icon
	icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Retain full original / inspector-configured size
	icon_node.size = item_size
	icon_node.custom_minimum_size = item_size
	icon_node.pivot_offset = item_size / 2

	var area_size = basket_area.size
	var max_x = max(area_size.x - item_size.x, 0.0)
	var max_y = max(area_size.y - item_size.y, 0.0)
	var pos_x = randf_range(0, max_x) if area_size.x >= item_size.x else (area_size.x - item_size.x) * 0.5
	var pos_y = randf_range(0, max_y) if area_size.y >= item_size.y else (area_size.y - item_size.y) * 0.5
	icon_node.position = Vector2(pos_x, pos_y)

	icon_node.rotation_degrees = randf_range(-12, 12)
	icon_node.z_index = min(basket_area.get_child_count() + 1, 99)

	icon_node.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_node.gui_input.connect(_on_item_icon_input.bind(icon_node, item))

	AnimUtils.spawn_pop(icon_node)
	basket_area.add_child(icon_node)

	if not basket_visuals.has(item.item_name):
		basket_visuals[item.item_name] = []
	basket_visuals[item.item_name].append(icon_node)

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if retur_panel and retur_panel.visible:
			_on_retur_back_pressed()

var _icon_touch_data: Dictionary = {}

func _on_item_icon_input(event: InputEvent, icon_node: Node, item: ItemData):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var tween = create_tween()
				tween.tween_property(icon_node, "scale", Vector2(1.15, 1.15), 0.35)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				_icon_touch_data[icon_node] = {
					"time": Time.get_ticks_msec(),
					"pos": event.global_position,
					"tween": tween
				}
			else:
				if _icon_touch_data.has(icon_node):
					var data = _icon_touch_data[icon_node]
					var elapsed = (Time.get_ticks_msec() - data["time"]) / 1000.0
					var dist = data["pos"].distance_to(event.global_position)
					if data["tween"] and is_instance_valid(data["tween"]):
						data["tween"].kill()
					icon_node.scale = Vector2.ONE
					_icon_touch_data.erase(icon_node)

					if dist < 30.0:
						if elapsed >= 0.35:
							# Mobile Long-Press gesture: directly return item with animation
							_animate_and_remove_icon(icon_node, item.item_name)
						else:
							# Mobile Tap: open return panel
							_open_retur_panel()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			accept_event()
			_remove_specific_icon(icon_node, item.item_name)

func _animate_and_remove_icon(icon_node: Node, item_name: String):
	if not is_instance_valid(icon_node):
		return
	AnimUtils.cart_press(keranjang)
	AudioDirector.play_sfx(&"pop")
	var tween = AnimUtils.shrink_and_fade(icon_node)
	tween.tween_callback(_remove_specific_icon.bind(icon_node, item_name))

func _remove_specific_icon(icon_node: Node, item_name: String):
	Cart.remove_one(item_name)

	if basket_visuals.has(item_name):
		basket_visuals[item_name].erase(icon_node)
		if basket_visuals[item_name].is_empty():
			basket_visuals.erase(item_name)

	if is_instance_valid(icon_node):
		icon_node.queue_free()

func _remove_last_icon_by_name(item_name: String):
	if not basket_visuals.has(item_name) or basket_visuals[item_name].is_empty():
		return
	var icon_node = basket_visuals[item_name][-1]
	_remove_specific_icon(icon_node, item_name)

func clear_basket_visuals():
	_icon_touch_data.clear()
	for key in basket_visuals:
		for node in basket_visuals[key]:
			if is_instance_valid(node):
				node.queue_free()
	basket_visuals.clear()

# ============ SISTEM RETUR ============

func _on_keranjang_input(event: InputEvent):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		accept_event()
		AnimUtils.cart_press(keranjang)
		AudioDirector.play_sfx(&"tap")
		_open_retur_panel()

func _open_retur_panel():
	if not retur_panel or retur_panel.visible:
		return
	AnimUtils.cart_press(keranjang)
	_populate_retur_panel()

	retur_original_parent = retur_panel.get_parent()
	retur_panel.reparent(popup_container)

	blur_layer.show()
	popup_layer.show()
	retur_panel.show()

	AnimUtils.spring_pop_in(retur_panel, 0.5)

func _on_retur_back_pressed():
	if not retur_panel:
		return

	if retur_back_button:
		AnimUtils.back_bounce(retur_back_button)
	AudioDirector.play_sfx(&"whoosh")

	AnimUtils.spring_pop_out(retur_panel, _finish_retur_close)

func _finish_retur_close():
	retur_panel.hide()
	popup_layer.hide()
	blur_layer.hide()

	if is_instance_valid(retur_original_parent):
		retur_panel.reparent(retur_original_parent)
	retur_panel.scale = Vector2(1.0, 1.0)
	retur_panel.modulate.a = 1.0

func _populate_retur_panel():
	if not retur_grid:
		return
	for child in retur_grid.get_children():
		child.queue_free()

	if Cart.is_empty():
		var empty_label = Label.new()
		empty_label.text = "🛒 Keranjang kosong"
		empty_label.add_theme_font_size_override("font_size", 28)
		retur_grid.add_child(empty_label)
		return

	for item_name in Cart.cart:
		var entry = Cart.cart[item_name]
		var item: ItemData = entry["data"]
		var quantity: int = entry["quantity"]
		_add_retur_entry(item, quantity)

func _add_retur_entry(item: ItemData, quantity: int):
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(300, 380)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon = TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(300, 300)
	icon.pivot_offset = Vector2(150, 150)
	box.add_child(icon)

	var name_label = Label.new()
	name_label.text = "%s ×%d" % [item.item_name, quantity]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	box.add_child(name_label)

	var retur_button = Button.new()
	retur_button.text = "↩ Retur 1"
	retur_button.custom_minimum_size = Vector2(180, 55)
	retur_button.add_theme_font_size_override("font_size", 24)
	retur_button.pressed.connect(_on_retur_button_pressed.bind(item.item_name, retur_button, icon))
	box.add_child(retur_button)

	retur_grid.add_child(box)

	# Entry entrance animation
	AnimUtils.spring_pop_in(box, 0.8)

func _on_retur_button_pressed(item_name: String, btn: Button = null, icon: TextureRect = null):
	if btn and is_instance_valid(btn):
		AnimUtils.squash_bounce(btn)
	AudioDirector.play_sfx(&"pop")

	# Icon shrink animation
	if icon and is_instance_valid(icon):
		icon.pivot_offset = icon.size / 2
		var icon_tween = create_tween()
		icon_tween.tween_property(icon, "scale", Vector2(0.7, 0.7), 0.12).set_trans(Tween.TRANS_QUAD)
		icon_tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK)

	_remove_last_icon_by_name(item_name)
	_populate_retur_panel()
