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
