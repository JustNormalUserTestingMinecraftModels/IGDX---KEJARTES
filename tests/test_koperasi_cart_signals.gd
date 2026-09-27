@tool
extends McpTestSuiteCompat

## Cart's granular per-item signals for the koperasi polish (item_added,
## item_removed). Later Koperasi-polish tasks hang Pak Herman's dialogue
## off these; this suite pins that add_item/remove_one/remove_item fire
## them, each immediately before the existing whole-cart cart_changed.
##
## Handlers are named methods (not lambdas) so setup()/teardown() can
## connect and disconnect them cleanly, and Cart -- an autoload, so state
## would otherwise leak into whichever suite runs next -- is left empty.

const ITEM_NAME := "Cilok"

var _added: Array[String] = []
var _removed: Array[String] = []
var _order: Array[String] = []


func suite_name() -> String:
	return "koperasi_cart_signals"


func setup() -> void:
	Cart.clear()
	_added.clear()
	_removed.clear()
	_order.clear()
	Cart.item_added.connect(_on_item_added)
	Cart.item_removed.connect(_on_item_removed)
	Cart.cart_changed.connect(_on_cart_changed)


func teardown() -> void:
	Cart.item_added.disconnect(_on_item_added)
	Cart.item_removed.disconnect(_on_item_removed)
	Cart.cart_changed.disconnect(_on_cart_changed)
	Cart.clear()


func _on_item_added(item_name: String) -> void:
	_added.append(item_name)
	_order.append("item_added")


func _on_item_removed(item_name: String) -> void:
	_removed.append(item_name)
	_order.append("item_removed")


func _on_cart_changed() -> void:
	_order.append("cart_changed")


func test_item_added_signal_fires_once_on_add() -> void:
	var item: ItemData = ItemDatabase.get_item(ITEM_NAME)
	Cart.add_item(item)
	assert_eq(_added, [ITEM_NAME], "item_added should fire once with the item's name")


func test_item_removed_signal_fires_on_remove_one() -> void:
	var item: ItemData = ItemDatabase.get_item(ITEM_NAME)
	Cart.add_item(item)
	Cart.remove_one(ITEM_NAME)
	assert_eq(_removed, [ITEM_NAME], "item_removed should fire once with the item's name")


func test_item_removed_signal_fires_on_remove_item() -> void:
	var item: ItemData = ItemDatabase.get_item(ITEM_NAME)
	Cart.add_item(item)
	Cart.remove_item(ITEM_NAME)
	assert_eq(_removed, [ITEM_NAME], "item_removed should fire once with the item's name")


func test_item_added_fires_before_cart_changed() -> void:
	var item: ItemData = ItemDatabase.get_item(ITEM_NAME)
	Cart.add_item(item)
	assert_eq(_order, ["item_added", "cart_changed"],
		"item_added must fire immediately before cart_changed")


func test_item_removed_fires_before_cart_changed() -> void:
	var item: ItemData = ItemDatabase.get_item(ITEM_NAME)
	Cart.add_item(item)
	_order.clear()
	Cart.remove_item(ITEM_NAME)
	assert_eq(_order, ["item_removed", "cart_changed"],
		"item_removed must fire immediately before cart_changed")


func test_clear_emits_neither_granular_signal() -> void:
	var item: ItemData = ItemDatabase.get_item(ITEM_NAME)
	Cart.add_item(item)
	_added.clear()
	_removed.clear()
	Cart.clear()
	assert_eq(_added, [], "clear() must not emit item_added")
	assert_eq(_removed, [], "clear() must not emit item_removed")
