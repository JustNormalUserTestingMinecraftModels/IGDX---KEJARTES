@tool
extends McpTestSuiteCompat

## Task 4 of the 2026-09-17 Koperasi polish plan: per-slot stock pips.
## SHOP_MAX_COPIES bumped 2 -> 3, rakbarang_1.gd's remaining_of()
## (stock - sold - carted, floored at 0) and shelf_dead_tap signal, and
## ShelfItem.gd's set_stock_pips(remaining, total) toggling PipRow's
## Pip1..Pip3 (and each one's Fill child) by `visible`.
##
## remaining_of() is exercised on a bare rakbarang_1.gd instance that is
## never added to any tree: the script is not @tool, so its _ready()
## (which expects real Barang* children and a TrayDock/BasketTray) must
## never run here -- setting _stock_names directly on an untree'd instance
## sidesteps that instead of relying on @tool/editor-hint lifecycle rules.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "koperasi_stock_pips"

const RAK_PATH := "res://Scripts/Koperasi/rakbarang_1.gd"
## rakbarang_1.gd declares no class_name; reached through a preloaded const,
## same as tests/test_shop_weekly_stock.gd.
const RakScript := preload("res://Scripts/Koperasi/rakbarang_1.gd")
const SHELF_ITEM_SRC := "res://Scripts/Koperasi/ShelfItem.gd"
const KOPRASI_SCENE := "res://Scenes/Koperasi/koprasi.tscn"

var _snap: Dictionary = {}


func setup() -> void:
	_snap = {
		"stock": GameState.shop_stock.duplicate(),
		"sold": GameState.shop_sold.duplicate(),
		"cart": Cart.cart.duplicate(true),
	}
	Cart.clear()


func teardown() -> void:
	GameState.shop_stock = _snap["stock"]
	GameState.shop_sold = _snap["sold"]
	Cart.cart = _snap["cart"]


# ─── SHOP_MAX_COPIES

func test_shop_max_copies_is_three() -> void:
	assert_eq(GameState.SHOP_MAX_COPIES, 3, "up to three copies per name now")


func test_a_roll_can_produce_a_duplicate_within_twenty_tries() -> void:
	# Fixed seed so the roll is reproducible; SHOP_MAX_COPIES=3 makes a
	# duplicate likely enough (more so than the old max-2 71% figure in
	# tests/test_shop_weekly_stock.gd) that 20 tries is not a flaky margin.
	seed(20260918)
	var names: Array[String] = []
	for item in ItemDatabase.get_all_items():
		names.append(item.item_name)
	var found_duplicate := false
	for _i in range(20):
		var stock: Array[String] = GameState.roll_shop_stock(
			names, GameState.SHOP_SHELF_SIZE, GameState.SHOP_MAX_COPIES)
		for item_name in stock:
			if stock.count(item_name) >= 2:
				found_duplicate = true
				break
		if found_duplicate:
			break
	assert_true(found_duplicate,
		"at least one of 20 rolls should hold a name twice at SHOP_MAX_COPIES=3")


# ─── remaining_of()

func test_remaining_of_reflects_sold_and_cart() -> void:
	GameState.shop_stock = ["Cilok", "Cilok", "Mie Instan"]
	GameState.shop_sold = ["Cilok"]
	Cart.add_item(ItemDatabase.get_item("Cilok"))

	var stage = RakScript.new()
	# stage is untyped (RakScript.new() carries no static type), so this
	# assignment goes through Object.set() dynamically -- an untyped array
	# literal there does not coerce to the property's Array[String] and
	# Godot raises "Invalid assignment". Build a typed local first so the
	# value itself carries Array[String] at runtime.
	var stock_names: Array[String] = ["Cilok", "Cilok", "Mie Instan"]
	stage._stock_names = stock_names

	assert_eq(stage.remaining_of("Cilok"), 0, "2 stock - 1 sold - 1 in cart = 0")
	assert_eq(stage.remaining_of("Mie Instan"), 1, "1 stock, untouched")
	stage.free()


func test_remaining_of_never_goes_negative() -> void:
	GameState.shop_stock = ["Cilok"]
	GameState.shop_sold = ["Cilok"]
	Cart.add_item(ItemDatabase.get_item("Cilok"))

	var stage = RakScript.new()
	# Same typed-array pitfall as test_remaining_of_reflects_sold_and_cart().
	var stock_names: Array[String] = ["Cilok"]
	stage._stock_names = stock_names

	assert_eq(stage.remaining_of("Cilok"), 0,
		"sold + carted overshoots the single copy on the shelf; floors at 0")
	stage.free()


func test_remaining_of_falls_back_to_gamestate_shop_stock_when_unset() -> void:
	# A test (or a screen reached before setup_shelf() ran) can call
	# remaining_of() on an instance whose _stock_names is still empty.
	GameState.shop_stock = ["Cilok", "Cilok"]
	GameState.shop_sold = []

	var stage = RakScript.new()
	assert_eq(stage.remaining_of("Cilok"), 2, "falls back to GameState.shop_stock")
	stage.free()


# ─── set_stock_pips()

## A PipRow shaped like koprasi.tscn's authored one: three Pip nodes, each
## with a Fill child, under a fake shelf button. Not added to any tree --
## ShelfItem.set_stock_pips() only touches node properties, no _process.
func _make_button_with_pip_row() -> TextureButton:
	var btn := TextureButton.new()
	btn.size = Vector2(180, 180)
	var row := HBoxContainer.new()
	row.name = "PipRow"
	btn.add_child(row)
	for i in range(3):
		var pip := TextureRect.new()
		pip.name = "Pip%d" % (i + 1)
		# Start every pip and fill visible, so a flip to hidden below is
		# proof set_stock_pips() actually ran rather than a node default.
		pip.visible = true
		var fill := TextureRect.new()
		fill.name = "Fill"
		fill.visible = true
		pip.add_child(fill)
		row.add_child(pip)
	return btn


func test_set_stock_pips_toggles_pip_and_fill_visibility() -> void:
	var btn := _make_button_with_pip_row()
	track(btn)
	var life = load(SHELF_ITEM_SRC).new()
	btn.add_child(life)
	life.attach_to(btn)

	life.set_stock_pips(1, 2)

	# Untyped (Variant): Node has no `visible` of its own (only
	# CanvasItem/Control do), so a statically Node-typed local here would
	# fail GDScript's static member check on the chained .visible access.
	var row = btn.get_node("PipRow")
	assert_true(row.get_node("Pip1").visible, "Pip1 on: within total")
	assert_true(row.get_node("Pip1/Fill").visible, "Pip1 filled: within remaining")
	assert_true(row.get_node("Pip2").visible, "Pip2 on: within total")
	assert_false(row.get_node("Pip2/Fill").visible, "Pip2 hollow: beyond remaining")
	assert_false(row.get_node("Pip3").visible, "Pip3 off: beyond total (was on by default)")
	assert_false(row.get_node("Pip3/Fill").visible, "Pip3's fill off too")


func test_set_stock_pips_shows_all_three_when_fully_stocked() -> void:
	var btn := _make_button_with_pip_row()
	track(btn)
	var life = load(SHELF_ITEM_SRC).new()
	btn.add_child(life)
	life.attach_to(btn)

	life.set_stock_pips(3, 3)

	var row = btn.get_node("PipRow")
	for i in range(1, 4):
		var pip = row.get_node("Pip%d" % i)
		assert_true(pip.visible, "Pip%d on: three copies on the shelf" % i)
		assert_true(pip.get_node("Fill").visible, "Pip%d filled: none sold or carted" % i)


func test_set_stock_pips_degrades_without_a_pip_row() -> void:
	# ShelfItem is also attached to buttons in older scenes/tests without a
	# PipRow; set_stock_pips() must not crash on the missing node.
	var btn := TextureButton.new()
	btn.size = Vector2(180, 180)
	track(btn)
	var life = load(SHELF_ITEM_SRC).new()
	btn.add_child(life)
	life.attach_to(btn)
	life.set_stock_pips(1, 2)
	assert_true(true, "no crash with no PipRow present")


# ─── shelf_dead_tap

func test_a_taken_slot_emits_shelf_dead_tap_before_returning() -> void:
	var body := _body(FileAccess.get_file_as_string(RAK_PATH), "func _on_barang_pressed(")
	assert_true(body.contains("if _taken_slots.has(index):"),
		"the existing double-tap guard is the one reachable dead-tap path")
	var guard := body.find("if _taken_slots.has(index):")
	var emit := body.find("shelf_dead_tap.emit(")
	assert_true(guard != -1 and emit != -1 and guard < emit,
		"shelf_dead_tap fires inside the taken-slot guard")


func test_shelf_dead_tap_signal_is_declared() -> void:
	var src := FileAccess.get_file_as_string(RAK_PATH)
	assert_true(src.contains("signal shelf_dead_tap(item_name: String)"))


func test_koprasi_wires_shelf_dead_tap_to_out_of_stock() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/koprasi.gd")
	# rakbarang_1.gd has no class_name, so `stage` is typed as plain Control;
	# koprasi.gd must go through Signal(stage, "shelf_dead_tap") rather than
	# a static `stage.shelf_dead_tap` member the parser would reject.
	assert_true(src.contains("Signal(stage, \"shelf_dead_tap\")"),
		"koprasi.gd reaches shelf_dead_tap dynamically, since Control has no such member")
	assert_true(src.contains("dead_tap.connect(_on_shelf_dead_tap)"),
		"koprasi.gd connects the Stage's shelf_dead_tap")
	assert_true(src.contains("dead_tap.disconnect(_on_shelf_dead_tap)"),
		"and disconnects it in _exit_tree, like every other Cart/Stage listener here")
	var handler := _body(src, "func _on_shelf_dead_tap(")
	assert_true(handler.contains("bubble.say(&\"OUT_OF_STOCK\")"),
		"a dead tap speaks Pak Herman's OUT_OF_STOCK line")


# ─── refresh call sites

func test_cart_and_money_changes_refresh_the_pips() -> void:
	var cart_body := _body(FileAccess.get_file_as_string(RAK_PATH), "func _on_cart_changed()")
	assert_true(cart_body.contains("_refresh_stock_pips()"),
		"a cart change (tap, hold-to-return, Beli) redraws the pips")
	var money_body := _body(FileAccess.get_file_as_string(RAK_PATH), "func _on_money_changed_refresh(")
	assert_true(money_body.contains("_refresh_stock_pips()"),
		"an affordability shift redraws the pips too, per the design doc")
	var setup_body := _body(FileAccess.get_file_as_string(RAK_PATH), "func setup_shelf()")
	assert_true(setup_body.contains("_refresh_stock_pips()"),
		"arriving at the shop paints the pips for the first time")


## The text of one function: from `signature` to the next top-level func.
## Copied from tests/test_shop_weekly_stock.gd's helper of the same name.
func _body(src: String, signature: String) -> String:
	var at := src.find(signature)
	if at < 0:
		return ""
	var end := src.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var next := src.find(marker, at + 1)
		if next > 0:
			end = mini(end, next)
	return src.substr(at, end - at)


# ─── the scene carries a PipRow under every shelf slot

func test_every_barang_slot_has_a_pip_row_with_three_pips() -> void:
	var src := FileAccess.get_file_as_string(KOPRASI_SCENE)
	assert_true(not src.is_empty(), "koprasi.tscn missing or unreadable")
	for i in range(1, 7):
		var parent := "Stage/Barang%d" % i
		assert_true(
			src.contains("[node name=\"PipRow\" type=\"HBoxContainer\" parent=\"%s\"" % parent),
			"%s is missing a PipRow" % parent)
		for p in range(1, 4):
			assert_true(
				src.contains("[node name=\"Pip%d\" type=\"TextureRect\" parent=\"%s/PipRow\"" % [p, parent]),
				"%s/PipRow is missing Pip%d" % [parent, p])
			assert_true(
				src.contains("[node name=\"Fill\" type=\"TextureRect\" parent=\"%s/PipRow/Pip%d\"" % [parent, p]),
				"%s/PipRow/Pip%d is missing its Fill child" % [parent, p])
