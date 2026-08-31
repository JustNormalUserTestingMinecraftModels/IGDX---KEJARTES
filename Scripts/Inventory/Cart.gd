@tool
extends Node

## The shop's in-progress basket, staged between picking items in Koperasi
## and paying for them.
##
## An autoload, populated only by rakbarang_1.gd (adding items as the
## player taps shelf art) and drained by koprasi.gd's "BELI" button, which
## deducts `GameState.player_money` and calls `GameState.add_to_inventory()`
## per line before clearing this cart. Never persisted -- leaving the shop
## without buying loses the basket, matching every other session-scoped
## state in the game.

signal cart_changed

# Maps item_name -> { "data": ItemData, "quantity": int }
var cart: Dictionary = {}

func add_item(item: ItemData) -> void:
	if cart.has(item.item_name):
		cart[item.item_name]["quantity"] += 1
	else:
		cart[item.item_name] = { "data": item, "quantity": 1 }
	cart_changed.emit()

func remove_one(item_name: String) -> void:
	if cart.has(item_name):
		cart[item_name]["quantity"] -= 1
		if cart[item_name]["quantity"] <= 0:
			cart.erase(item_name)
		cart_changed.emit()

func remove_item(item_name: String) -> void:
	if cart.has(item_name):
		cart.erase(item_name)
		cart_changed.emit()

func clear() -> void:
	cart.clear()
	cart_changed.emit()

func get_total() -> int:
	var total: int = 0
	for key in cart:
		total += cart[key]["data"].price * cart[key]["quantity"]
	return total

func get_item_count() -> int:
	var count: int = 0
	for key in cart:
		count += cart[key]["quantity"]
	return count

func get_quantity(item_name: String) -> int:
	if cart.has(item_name):
		return cart[item_name]["quantity"]
	return 0

func is_empty() -> bool:
	return cart.is_empty()
