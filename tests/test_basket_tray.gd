@tool
extends McpTestSuiteCompat

## BasketTray (Koperasi Part 2): the tray docked at the bottom of the shelf
## screen. refresh() and the slot layout are plain synchronous code, so the
## tray is exercised live here with hand-made ItemData; the shop wiring is in
## test_koperasi_tray.gd. Suite is @tool and no test is a coroutine.

const _SCENE := "res://Scenes/Koperasi/BasketTray.tscn"


func suite_name() -> String:
	return "basket_tray"


func _item(item_name: String, price: int, size := Vector2(200, 250)) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.price = price
	item.display_size = size
	return item


func _entry(item: ItemData, quantity: int) -> Dictionary:
	return {"data": item, "quantity": quantity}


## A live tray in the editor's root, so @onready resolves. Null (after a
## recorded failure) when the scene does not exist yet.
func _tray() -> Node:
	var packed = load(_SCENE)
	assert_not_null(packed, "BasketTray.tscn missing")
	if packed == null:
		return null
	var tray = packed.instantiate()
	Engine.get_main_loop().root.add_child(tray)
	track(tray)
	return tray


func test_the_total_is_price_times_quantity_summed() -> void:
	assert_true(Cart.has_method("total_of"), "Cart.total_of exists")
	if not Cart.has_method("total_of"):
		return
	var entries := {
		"Susu Kotak": _entry(_item("Susu Kotak", 1000), 2),
		"Pop Ice": _entry(_item("Pop Ice", 400), 1),
	}
	# call(), not a direct call: Cart is a typed autoload, so a missing
	# total_of fails this test instead of risking the whole suite's compile.
	assert_eq(Cart.call("total_of", entries), 2400, "2 x 1000 + 1 x 400")
	assert_eq(Cart.call("total_of", {}), 0, "an empty cart costs nothing")


func test_the_footer_shows_the_total_in_koin() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({
		"Susu Kotak": _entry(_item("Susu Kotak", 1000), 2),
		"Pop Ice": _entry(_item("Pop Ice", 400), 1),
	})
	assert_eq(tray.get_total_text(), "Total: 2.400 koin")


func test_koin_amounts_group_thousands_with_dots() -> void:
	var tray = _tray()
	if tray == null:
		return
	assert_eq(tray.format_koin(0), "0")
	assert_eq(tray.format_koin(400), "400")
	assert_eq(tray.format_koin(2400), "2.400")
	assert_eq(tray.format_koin(1250000), "1.250.000")


func test_an_empty_tray_shows_its_empty_state() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({})
	assert_true(tray.get_node("Body/EmptyState").visible, "the empty state shows")
	assert_false(tray.get_node("Body/Hint").visible, "no hold-to-return hint over nothing")
	assert_eq(tray.get_total_text(), "Total: 0 koin")


func test_a_filled_tray_hides_its_empty_state() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({"Pop Ice": _entry(_item("Pop Ice", 400), 1)})
	assert_false(tray.get_node("Body/EmptyState").visible, "the empty state hides")
	assert_true(tray.get_node("Body/Hint").visible, "the hint explains hold-to-return")


func test_beli_emits_buy_pressed() -> void:
	var tray = _tray()
	if tray == null:
		return
	var heard := [false]
	tray.buy_pressed.connect(func() -> void: heard[0] = true)
	tray.get_beli_button().pressed.emit()
	assert_true(heard[0], "pressing Beli asks the shop to buy")


func test_the_tray_is_themed_not_overridden() -> void:
	var src := FileAccess.get_file_as_string(_SCENE)
	assert_true(src.contains("&\"BasketTray\""), "the surface wears BasketTray")
	assert_true(src.contains("tray_dots.png"), "the dot-grid tile")
	assert_true(src.contains("texture_repeat = 2"), "the tile repeats on the node")
	assert_true(src.contains("&\"PrimaryButtonM\""), "Beli is theme chrome at the M step")
	for banned in ["theme_override_colors", "theme_override_font_sizes", "theme_override_styles"]:
		assert_false(src.contains(banned), "no %s in the tray" % banned)


# ────────────────────────────────────────────── one item on the plank

const _SLOT := "res://Scenes/Koperasi/TraySlot.tscn"
const _THEME := "res://Assets/Theme/kejartes_theme.tres"


func _slot() -> Node:
	var packed = load(_SLOT)
	assert_not_null(packed, "TraySlot.tscn missing")
	if packed == null:
		return null
	var slot = packed.instantiate()
	Engine.get_main_loop().root.add_child(slot)
	track(slot)
	return slot


func test_a_slot_wears_its_quantity_as_a_badge() -> void:
	var slot = _slot()
	if slot == null:
		return
	slot.bind(_item("Raket", 1500, Vector2(180, 280)), 3)
	assert_eq(slot.get_badge_text(), "×3")
	slot.set_quantity(1)
	assert_eq(slot.get_badge_text(), "×1")


func test_a_slot_without_art_is_its_display_size() -> void:
	var slot = _slot()
	if slot == null:
		return
	slot.bind(_item("Raket", 1500, Vector2(180, 280)), 1)
	assert_eq(slot.natural_size, Vector2(180, 280))


func test_a_slots_width_follows_its_arts_aspect() -> void:
	var slot = _slot()
	if slot == null:
		return
	var item := _item("Pop Ice", 400, Vector2(160, 240))
	item.icon = ImageTexture.create_from_image(
		Image.create_empty(100, 300, false, Image.FORMAT_RGBA8))
	slot.bind(item, 1)
	assert_eq(slot.natural_size, Vector2(80, 240),
		"the display height, at the art's own 1:3 aspect")


func test_hold_and_tap_are_told_apart() -> void:
	var slot = _slot()
	if slot == null:
		return
	assert_eq(slot.classify_release(0.5, 5.0, 0.35, 30.0), &"hold")
	assert_eq(slot.classify_release(0.1, 5.0, 0.35, 30.0), &"tap")
	assert_eq(slot.classify_release(0.5, 50.0, 0.35, 30.0), &"none", "a drag is neither")


func test_a_right_click_returns_one_at_once() -> void:
	var slot = _slot()
	if slot == null:
		return
	slot.bind(_item("Raket", 1500), 2)
	var heard := [""]
	slot.remove_requested.connect(func(n: String) -> void: heard[0] = n)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	slot._gui_input(click)
	assert_eq(heard[0], "Raket")


func test_the_tray_badge_and_plank_are_baked() -> void:
	var theme := ResourceLoader.load(_THEME, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for variation in ["TrayBadge", "TrayPlank"]:
		assert_true(theme.has_stylebox("panel", variation), "%s is baked" % variation)
	assert_true(theme.get_type_list().has("TrayBadgeLabel"), "TrayBadgeLabel is baked")
	if theme.has_stylebox("panel", "TrayBadge"):
		var box := theme.get_stylebox("panel", "TrayBadge") as StyleBoxFlat
		assert_eq(box.border_color, DesignTokens.load_default().koperasi_tray_rule,
			"the badge rim is the tray's amber")


func test_the_badge_face_can_draw_the_times_sign() -> void:
	var theme := ResourceLoader.load(_THEME, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var font := theme.get_font("font", "TrayBadgeLabel")
	assert_true(font != null and font.has_char(0x00D7),
		"the badge's face has a × glyph -- if not, give TrayBadgeLabel the "
		+ "body face and take it off DISPLAY_ROSTER")
