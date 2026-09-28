@tool
extends McpTestSuite

## The weekly promo: one item from this week's shelf is discounted, both the
## item and the percentage derived deterministically from (grade, week). The
## picks hash the week key rather than use the global RNG, so they are
## reproducible and independent of the shelf roll's shuffle(). GameState is
## the live autoload; setup() snapshots every field these tests write.

## McpTestSuite has no assert_almost_eq (checked addons/godot_ai/testing/
## test_suite.gd); float promo multipliers are compared with this tolerance
## via assert_true instead.
const FLOAT_TOLERANCE: float = 0.0001

const CartScript := preload("res://Scripts/Inventory/Cart.gd")

var _snap: Dictionary = {}

func suite_name() -> String:
	return "shop_promo"

func setup() -> void:
	_snap = {
		"grade": GameState.current_grade,
		"week": GameState.minggu_ke,
		"key": GameState.shop_week_key,
		"stock": GameState.shop_stock.duplicate(),
		"sold": GameState.shop_sold.duplicate(),
		"promo_item": GameState.shop_promo_item,
		"promo_pct": GameState.shop_promo_percent,
	}
	GameState.reset_shop_week()

func teardown() -> void:
	GameState.current_grade = _snap["grade"]
	GameState.minggu_ke = _snap["week"]
	GameState.shop_week_key = _snap["key"]
	GameState.shop_stock = _snap["stock"]
	GameState.shop_sold = _snap["sold"]
	GameState.shop_promo_item = _snap["promo_item"]
	GameState.shop_promo_percent = _snap["promo_pct"]

func _stock() -> Array[String]:
	return ["Bank Soal", "Komik", "Bank Soal", "Pensil", "Susu Murni", "Roti"]

func test_promo_item_is_one_of_the_stock() -> void:
	var item: String = GameState.promo_item_for(_stock(), 7, 2)
	assert_true(_stock().has(item), "the promo is always something on the shelf")

func test_promo_item_is_deterministic_per_week() -> void:
	assert_eq(GameState.promo_item_for(_stock(), 7, 2), GameState.promo_item_for(_stock(), 7, 2),
		"same week, same pick")

func test_promo_item_moves_across_weeks() -> void:
	var seen: Dictionary = {}
	for week: int in range(1, 13):
		seen[GameState.promo_item_for(_stock(), 7, week)] = true
	assert_gt(seen.size(), 1, "the promo item is not frozen to one name")

func test_empty_stock_has_no_promo() -> void:
	var empty: Array[String] = []
	assert_eq(GameState.promo_item_for(empty, 7, 2), "", "no shelf, no promo")

func test_promo_percent_is_in_the_allowed_set() -> void:
	for week: int in range(1, 17):
		assert_true(GameState.PROMO_DISCOUNTS.has(GameState.promo_percent_for(9, week)),
			"week %d's discount is one of the authored steps" % week)

func test_promo_percent_is_deterministic_per_week() -> void:
	assert_eq(GameState.promo_percent_for(8, 5), GameState.promo_percent_for(8, 5),
		"same week, same discount")

func test_multiplier_only_touches_the_promo_item() -> void:
	var promo_multiplier: float = GameState.promo_multiplier("Susu Murni", "Susu Murni", 20)
	assert_true(absf(promo_multiplier - 0.8) < FLOAT_TOLERANCE, "20% off the promo item")
	assert_eq(GameState.promo_multiplier("Komik", "Susu Murni", 20), 1.0,
		"everything else is full price")
	assert_eq(GameState.promo_multiplier("", "", 20), 1.0, "an empty promo discounts nothing")

func test_this_weeks_multiplier_reads_the_rolled_promo() -> void:
	GameState.shop_promo_item = "Susu Murni"
	GameState.shop_promo_percent = 25
	var live_multiplier: float = GameState.shop_promo_multiplier("Susu Murni")
	assert_true(absf(live_multiplier - 0.75) < FLOAT_TOLERANCE, "the live promo is applied")
	assert_eq(GameState.shop_promo_multiplier("Komik"), 1.0, "and nothing else")

func test_rolling_the_week_sets_a_stock_promo() -> void:
	GameState.current_grade = 7
	GameState.minggu_ke = 2
	var stock: Array[String] = GameState.shop_stock_for_week()
	assert_true(stock.has(GameState.shop_promo_item), "the week's promo is on the week's shelf")
	assert_true(GameState.PROMO_DISCOUNTS.has(GameState.shop_promo_percent),
		"and carries a real discount")

func test_reset_clears_the_promo() -> void:
	GameState.shop_promo_item = "Komik"
	GameState.shop_promo_percent = 20
	GameState.reset_shop_week()
	assert_eq(GameState.shop_promo_item, "", "reset forgets the promo item")
	assert_eq(GameState.shop_promo_percent, 0, "and its discount")

func test_forget_session_goes_through_reset_shop_week() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var at: int = src.find("func forget_session()")
	var body: String = src.substr(at, src.find("\nfunc ", at + 1) - at)
	assert_true(body.contains("reset_shop_week()"),
		"one place clears the shop week, promo included")
	assert_false(body.contains("shop_stock = []"), "not a second copy of it")

func _item(item_name: String, price: int) -> ItemData:
	var data := ItemData.new()
	data.item_name = item_name
	data.price = price
	return data

func test_price_of_discounts_only_the_promo_item() -> void:
	GameState.shop_promo_item = "Susu Murni"
	GameState.shop_promo_percent = 20
	var promo: ItemData = _item("Susu Murni", 1000)
	assert_eq(CartScript.price_of(promo), roundi(CartScript.list_price_of(promo) * 0.8),
		"20% off the promo item's list price")
	var plain: ItemData = _item("Komik", 1000)
	assert_eq(CartScript.price_of(plain), CartScript.list_price_of(plain), "full price otherwise")

func test_total_of_sums_the_promo_price() -> void:
	GameState.shop_promo_item = "Susu Murni"
	GameState.shop_promo_percent = 20
	var promo: ItemData = _item("Susu Murni", 1000)
	var entries: Dictionary = {"Susu Murni": {"data": promo, "quantity": 2}}
	assert_eq(CartScript.total_of(entries), CartScript.price_of(promo) * 2,
		"the basket total uses the same discounted price")
