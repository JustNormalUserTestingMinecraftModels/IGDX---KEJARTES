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


# ─── the shelf

const RAK_PATH := "res://Scripts/Koperasi/rakbarang_1.gd"
const KOPERASI_PATH := "res://Scripts/Koperasi/koprasi.gd"
## rakbarang_1.gd declares no class_name; reached through a preloaded const.
const RakScript := preload("res://Scripts/Koperasi/rakbarang_1.gd")


func test_an_item_is_on_sale_until_basketed_or_sold() -> void:
	assert_true(RakScript.is_on_sale("Bank Soal", {}, []), "on the shelf by default")
	assert_false(RakScript.is_on_sale("Bank Soal", {"Bank Soal": {}}, []),
		"off the shelf while it is in the basket")
	assert_false(RakScript.is_on_sale("Bank Soal", {}, ["Bank Soal"]),
		"off the shelf once bought this week")
	assert_true(RakScript.is_on_sale("Bank Soal", {"Kamus": {}}, ["Kamus"]),
		"other items leaving do not take it with them")


func test_the_shelf_stocks_from_the_weekly_roll() -> void:
	var src := FileAccess.get_file_as_string(RAK_PATH)
	assert_true(src.contains("GameState.shop_stock_for_week()"), "the shelf reads this week's stock")
	assert_false(src.contains("get_random_items("), "and never rolls its own")
	assert_false(src.contains("func setup_random_items"), "the per-visit reshuffle is gone")


func test_every_cart_change_rechecks_the_shelf() -> void:
	var body := _body(FileAccess.get_file_as_string(RAK_PATH), "func _on_cart_changed()")
	assert_true(body.contains("_refresh_shelf_visibility()"),
		"tap, hold-to-return, Back and Beli all move the cart, so one refresh covers them")


func test_a_second_tap_cannot_add_a_second_unit() -> void:
	var body := _body(FileAccess.get_file_as_string(RAK_PATH), "func _on_barang_pressed(")
	assert_true(body.contains("is_on_sale("), "the tap handler refuses an item not on sale")


func test_beli_marks_the_basket_sold_before_emptying_it() -> void:
	var body := _body(FileAccess.get_file_as_string(KOPERASI_PATH), "func _on_beli_pressed()")
	var mark := body.find("GameState.mark_shop_sold(")
	assert_gt(mark, -1, "Beli marks each item sold")
	assert_true(mark < body.find("Cart.clear()"),
		"before the cart empties, so the shelf never flickers them back")


func test_opening_the_shelf_restocks_it_for_the_week() -> void:
	var src := FileAccess.get_file_as_string(KOPERASI_PATH)
	assert_true(src.contains("setup_shelf()"), "the Rak1 button restocks via setup_shelf()")
	assert_false(src.contains("setup_random_items"), "not the old reshuffle")
	assert_true(src.contains("GameState.is_shop_sold_out()"), "an empty shelf explains itself")


## Review finding: pop_in fades a node to full alpha, which overwrote
## ShelfItem.set_dimmed()'s 0.55 on an item the player cannot afford.
func test_a_returning_item_keeps_its_dimming() -> void:
	var body := _body(FileAccess.get_file_as_string(RAK_PATH), "func _refresh_shelf_visibility()")
	assert_false(body.contains("Juice.pop_in("), "no alpha fade on a returning item")
	assert_true(body.contains("AnimUtils.squash_bounce("), "a scale-only bounce instead")


# ─── a new run is a new week

const RUN_RESULT_PATH := "res://Scripts/EndGame/RunResult.gd"


func test_resetting_the_shop_week_forces_a_fresh_roll() -> void:
	_at(7, 1)
	GameState.shop_week_key = "7-1"
	GameState.shop_stock = [FAKE_ITEM]
	GameState.shop_sold = [FAKE_ITEM]
	GameState.reset_shop_week()
	assert_eq(GameState.shop_week_key, "", "no week is stocked")
	assert_true(GameState.shop_sold.is_empty(), "nothing is sold")
	assert_false(GameState.shop_stock_for_week().has(FAKE_ITEM),
		"the same grade and week, reached again, rolls a fresh shelf")


## Review finding: a run restart resets minggu_ke to 1 without touching the
## shop, so a retried grade -- or Kelas 7 after a loss or after beating the
## game -- landed on the last run's key and inherited its sold list.
func test_every_run_restart_clears_the_shop() -> void:
	var gs := _body(FileAccess.get_file_as_string(GAME_STATE_PATH), "func set_grade(")
	assert_true(gs.contains("reset_shop_week()"),
		"set_grade() -- new game, level select, beating the game -- starts a fresh shelf")
	var rr := _body(FileAccess.get_file_as_string(RUN_RESULT_PATH), "func _apply_progression()")
	var failed_branch := rr.substr(0, rr.find("if GameState.current_grade < 9:"))
	assert_true(failed_branch.contains("GameState.reset_shop_week()"),
		"a lost run's retry starts a fresh shelf too")
