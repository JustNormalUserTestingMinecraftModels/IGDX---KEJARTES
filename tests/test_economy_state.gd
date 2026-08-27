@tool
extends McpTestSuite

## Economy state: ItemData, ItemDatabase, GameState money/inventory/use_item.
## Suite must be @tool and no test may be a coroutine (the runner calls
## suite.call(name) without awaiting) -- same constraints as test_lobby.gd.

func suite_name() -> String:
	return "economy_state"

const _EXPECTED_ITEMS := [
	"Bank Soal", "Komik", "LKS", "Lompat Tali", "Raket",
	"Cilok", "Mie Instan", "Pop Ice", "Susu Kotak"
]

func test_item_database_registers_every_item() -> void:
	for item_name in _EXPECTED_ITEMS:
		assert_true(ItemDatabase.get_item(item_name) != null,
			"ItemDatabase must know: " + item_name)

func test_every_item_has_a_loaded_icon() -> void:
	for item_name in _EXPECTED_ITEMS:
		var item: ItemData = ItemDatabase.get_item(item_name)
		assert_true(item.icon != null, "icon must load for: " + item_name)

func test_every_item_has_a_positive_price() -> void:
	for item_name in _EXPECTED_ITEMS:
		var item: ItemData = ItemDatabase.get_item(item_name)
		assert_true(item.price > 0, "price must be positive for: " + item_name)

func test_unknown_item_returns_null() -> void:
	assert_true(ItemDatabase.get_item("TidakAda") == null,
		"unknown item must return null, not a blank ItemData")

func test_money_setter_emits_money_changed() -> void:
	var original := GameState.player_money
	var seen := []
	var cb := func(amount: int): seen.append(amount)
	GameState.money_changed.connect(cb)
	GameState.player_money = 1234
	GameState.money_changed.disconnect(cb)
	GameState.player_money = original
	assert_eq(seen.size(), 1, "setting player_money must emit exactly once")
	assert_eq(seen[0], 1234, "money_changed must carry the new amount")

func test_add_to_inventory_accumulates() -> void:
	GameState.inventory.clear()
	GameState.add_to_inventory("Komik", 2)
	GameState.add_to_inventory("Komik", 3)
	assert_eq(GameState.get_inventory_quantity("Komik"), 5, "quantities accumulate")
	GameState.inventory.clear()

func test_remove_from_inventory_erases_at_zero() -> void:
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie", 2)
	assert_true(GameState.remove_from_inventory("Mie", 2), "removal succeeds")
	assert_false(GameState.inventory.has("Mie"), "entry is erased, not left at 0")
	GameState.inventory.clear()

func test_remove_from_missing_item_returns_false() -> void:
	GameState.inventory.clear()
	assert_false(GameState.remove_from_inventory("Raket", 1),
		"removing an unowned item must report failure")

func test_get_quantity_of_unowned_item_is_zero() -> void:
	GameState.inventory.clear()
	assert_eq(GameState.get_inventory_quantity("Raket"), 0, "unowned reads as 0")
	# Task 2 tests complete

func test_cart_total_multiplies_price_by_quantity() -> void:
	Cart.clear()
	var komik: ItemData = ItemDatabase.get_item("Komik")
	Cart.add_item(komik)
	Cart.add_item(komik)
	assert_eq(Cart.get_total(), komik.price * 2, "total is price x quantity")
	assert_eq(Cart.get_item_count(), 2, "item count sums quantities")
	Cart.clear()

func test_cart_remove_one_erases_at_zero() -> void:
	Cart.clear()
	Cart.add_item(ItemDatabase.get_item("Mie"))
	Cart.remove_one("Mie")
	assert_true(Cart.is_empty(), "cart is empty after removing the last unit")
	Cart.clear()

func test_cart_clear_empties_everything() -> void:
	Cart.clear()
	Cart.add_item(ItemDatabase.get_item("Raket"))
	Cart.add_item(ItemDatabase.get_item("LKS"))
	Cart.clear()
	assert_eq(Cart.get_total(), 0, "total is 0 after clear")
	assert_true(Cart.is_empty(), "cart reports empty after clear")
