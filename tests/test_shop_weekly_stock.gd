@tool
extends McpTestSuite

## The Koperasi shelf restocks once a week (2026-09-15). GameState holds the
## week's four items and the ones bought: shop_stock_for_week() rolls on the
## first call of a (grade, week) and returns the same list after, and a new
## roll clears the sold list. rakbarang_1.gd hides an item that is sold or
## already in the basket, and koprasi.gd's Beli marks the basket sold.
##
## GameState is the live autoload: setup() snapshots every field these tests
## write and teardown() puts it back, so the editor's session is untouched.
##
## Must be @tool; no test here may be a coroutine.

const GAME_STATE_PATH := "res://Scripts/GameState.gd"
## Not a catalog item. Planted in shop_stock to prove whether a call rolled.
const FAKE_ITEM := "Bukan Barang"

var _snap: Dictionary = {}


func suite_name() -> String:
	return "shop_weekly_stock"


func setup() -> void:
	_snap = {
		"grade": GameState.current_grade,
		"week": GameState.minggu_ke,
		"key": GameState.shop_week_key,
		"stock": GameState.shop_stock.duplicate(),
		"sold": GameState.shop_sold.duplicate(),
	}
	GameState.shop_week_key = ""
	GameState.shop_stock = []
	GameState.shop_sold = []


func teardown() -> void:
	GameState.current_grade = _snap["grade"]
	GameState.minggu_ke = _snap["week"]
	GameState.shop_week_key = _snap["key"]
	GameState.shop_stock = _snap["stock"]
	GameState.shop_sold = _snap["sold"]


func _at(grade: int, week: int) -> void:
	GameState.current_grade = grade
	GameState.minggu_ke = week


## The text of one function: from `signature` to the next top-level func.
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


# ─── the week's stock

func test_the_key_names_grade_and_week() -> void:
	assert_eq(GameState.shop_week_key_for(8, 3), "8-3", "grade, then week")
	assert_ne(GameState.shop_week_key_for(7, 1), GameState.shop_week_key_for(8, 1),
		"a new grade's week 1 is a different week")


func test_the_first_visit_rolls_a_full_shelf() -> void:
	_at(7, 2)
	var stock: Array[String] = GameState.shop_stock_for_week()
	assert_eq(stock.size(), GameState.SHOP_SHELF_SIZE, "one item per shelf button")
	assert_eq(GameState.shop_week_key, "7-2", "rolled for this week")
	for item_name in stock:
		assert_true(ItemDatabase.has_item(item_name), item_name + " is a catalog item")


func test_a_later_visit_the_same_week_does_not_reroll() -> void:
	_at(7, 2)
	GameState.shop_week_key = "7-2"
	GameState.shop_stock = [FAKE_ITEM]
	var stock: Array[String] = GameState.shop_stock_for_week()
	assert_eq(stock.size(), 1, "the stored shelf comes back")
	assert_true(stock.has(FAKE_ITEM), "untouched")


func test_a_new_week_rolls_again_and_forgets_what_sold() -> void:
	_at(7, 2)
	GameState.shop_week_key = "7-2"
	GameState.shop_stock = [FAKE_ITEM]
	GameState.shop_sold = [FAKE_ITEM]
	_at(7, 3)
	var stock: Array[String] = GameState.shop_stock_for_week()
	assert_eq(GameState.shop_week_key, "7-3", "the new week rolled its own shelf")
	assert_eq(stock.size(), GameState.SHOP_SHELF_SIZE, "a full one")
	assert_false(stock.has(FAKE_ITEM), "last week's shelf is gone")
	assert_true(GameState.shop_sold.is_empty(), "nothing is sold in a fresh week")


func test_a_new_grade_is_a_new_week() -> void:
	_at(7, 1)
	GameState.shop_week_key = "7-1"
	GameState.shop_stock = [FAKE_ITEM]
	_at(8, 1)
	assert_false(GameState.shop_stock_for_week().has(FAKE_ITEM),
		"Kelas 8's first week does not inherit Kelas 7's shelf")


# ─── what sold

func test_an_item_sells_once() -> void:
	GameState.mark_shop_sold("Bank Soal")
	GameState.mark_shop_sold("Bank Soal")
	assert_eq(GameState.shop_sold.count("Bank Soal"), 1, "marked once, however often Beli sees it")
	assert_true(GameState.is_shop_sold("Bank Soal"), "and reads back as sold")
	assert_false(GameState.is_shop_sold(FAKE_ITEM), "another item is not")


func test_the_shelf_is_sold_out_only_once_every_item_sold() -> void:
	assert_false(GameState.is_shop_sold_out(), "an unrolled shelf is not sold out")
	_at(7, 2)
	var stock: Array[String] = GameState.shop_stock_for_week()
	for i in range(stock.size() - 1):
		GameState.mark_shop_sold(stock[i])
	assert_false(GameState.is_shop_sold_out(), "one item is still on the shelf")
	GameState.mark_shop_sold(stock[stock.size() - 1])
	assert_true(GameState.is_shop_sold_out(), "every item bought")


func test_forget_session_clears_the_shop() -> void:
	var body := _body(FileAccess.get_file_as_string(GAME_STATE_PATH), "func forget_session()")
	for reset in ["shop_week_key = \"\"", "shop_stock = []", "shop_sold = []"]:
		assert_true(body.contains(reset), "forget_session() does " + reset)
