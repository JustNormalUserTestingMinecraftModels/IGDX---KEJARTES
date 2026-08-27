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
	Cart.add_item(ItemDatabase.get_item("Mie Instan"))
	Cart.remove_one("Mie Instan")
	assert_true(Cart.is_empty(), "cart is empty after removing the last unit")
	Cart.clear()

func test_cart_clear_empties_everything() -> void:
	Cart.clear()
	Cart.add_item(ItemDatabase.get_item("Raket"))
	Cart.add_item(ItemDatabase.get_item("LKS"))
	Cart.clear()
	assert_eq(Cart.get_total(), 0, "total is 0 after clear")
	assert_true(Cart.is_empty(), "cart reports empty after clear")

## Builds a throwaway approved_students roster and returns the caller's
## original one so each test can restore it.
func _swap_roster(roster: Array) -> Array:
	var original: Array = GameState.approved_students
	GameState.approved_students = roster
	return original

func test_use_item_boosts_only_the_chosen_student() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 50.0, "energy": 50.0},
		{"id": 2, "student_name": "B", "mood": 50.0, "energy": 50.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Komik", 1)
	var komik: ItemData = ItemDatabase.get_item("Komik")
	var result := GameState.use_item(komik, 1, 1)
	assert_true(result["applied"], "use must succeed when the item is owned")
	assert_eq(GameState.approved_students[0]["mood"], 50.0 + komik.mood_boost, "chosen student gains mood")
	assert_eq(GameState.approved_students[1]["mood"], 50.0, "other student is untouched")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_clamps_at_one_hundred() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 98.0, "energy": 98.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Komik", 1)
	GameState.use_item(ItemDatabase.get_item("Komik"), 1, 1)
	assert_eq(GameState.approved_students[0]["mood"], 100.0, "mood clamps at 100")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_consumes_the_inventory_quantity() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie Instan", 3)
	GameState.use_item(ItemDatabase.get_item("Mie Instan"), 1, 2)
	assert_eq(GameState.get_inventory_quantity("Mie Instan"), 1, "2 of 3 consumed")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_refuses_when_not_enough_owned() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie Instan", 1)
	var result := GameState.use_item(ItemDatabase.get_item("Mie Instan"), 1, 5)
	assert_false(result["applied"], "cannot use more than owned")
	assert_eq(GameState.approved_students[0]["mood"], 10.0, "no stat change on refusal")
	assert_eq(GameState.get_inventory_quantity("Mie Instan"), 1, "nothing consumed on refusal")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_refuses_for_unknown_student_id() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie Instan", 1)
	var result := GameState.use_item(ItemDatabase.get_item("Mie Instan"), 99, 1)
	assert_false(result["applied"], "unknown student id must refuse")
	assert_eq(GameState.get_inventory_quantity("Mie Instan"), 1, "nothing consumed on refusal")
	GameState.inventory.clear()
	GameState.approved_students = original
