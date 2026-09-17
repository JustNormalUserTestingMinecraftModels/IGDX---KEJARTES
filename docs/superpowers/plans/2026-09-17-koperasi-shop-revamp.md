# Koperasi Shop Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Koperasi opens straight onto Pak Herman's counter: three layered art planes, six shelf slots whose weekly stock can hold a pair of one item, a placeholder speech bubble, and the unchanged basket tray.

**Architecture:** `GameState` rolls six names from a bag holding every item twice, and counts sales per unit. `rakbarang_1.gd` (now on a 1080×1920 `Stage` pinned to the bottom edge) tracks which *slot* emptied through a pure static `reconcile_taken()`, so `Cart` and the tray stay name-keyed and unchanged. The scene is rewritten as text while the worktree editor is closed, then re-saved by that editor to assign uids.

**Tech Stack:** Godot 4.6 GDScript, `McpTestSuite` suites run through the godot-ai bridge.

Spec: `docs/superpowers/specs/2026-09-17-koperasi-shop-revamp-design.md`

## Global Constraints

- Worktree: `.claude/worktrees/shop-revamp`, branch `feat/shop-revamp`. Every godot-ai call passes the worktree editor's `session_id` (called `$SID` below). Never `session_activate`, never kill every Godot process.
- No `theme_override_*` added. New styling is a ThemeFactory variation (`ShopChatBubble`), then a rebake.
- No visual built at runtime. The bubble, tail, slots, glows and price tags are scene nodes.
- Every script keeps a `##` header, and every `@export` a `##` line.
- Suites are `@tool`, and no test is a coroutine.
- `Balance.gd` is not touched.
- UI text is Indonesian. Placeholder bubble copy: `Selamat datang di Koperasi! Mau beli apa hari ini?`
- New tuning numbers are named consts: `SHOP_SHELF_SIZE := 6`, `SHOP_MAX_COPIES := 2`, `SHOP_CHAT_BUBBLE_RADIUS := 28`.
- Commits: Conventional Commits with scope, written to a scratch file and committed with `git commit -F`, ending `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Run git as plain single commands (no `&&`, no heredocs).
- Script edits made with the Edit tool are forced into the editor with a no-op `script_patch` on the same file before any `test_run` (CLAUDE.md §5). A new test file needs `filesystem_manage(op="scan")` first.
- Before every commit: `git status --porcelain`, then `git checkout -- Assets/Audio/default_bus_layout.tres` and revert any `*.png.import` the editor rewrote, if they show up.

---

### Task 1: Worktree editor, and a weekly roll that can hold pairs

**Files:**
- Modify: `Scripts/GameState.gd:47-56` (consts/docs), `:272-283` (`shop_stock_for_week`)
- Modify: `Scripts/Inventory/ItemDatabase.gd:8` (doc line naming the caller)
- Test: `tests/test_shop_weekly_stock.gd`

**Interfaces:**
- Produces: `GameState.SHOP_SHELF_SIZE: int = 6`, `GameState.SHOP_MAX_COPIES: int = 2`, `static func roll_shop_stock(names: Array[String], size: int, max_copies: int) -> Array[String]`

- [ ] **Step 1: Seed and launch the worktree editor**

PowerShell (main checkout = `C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project`, `$wt` = its `.claude\worktrees\shop-revamp`):

```powershell
$main = "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project"
$wt = "$main\.claude\worktrees\shop-revamp"
New-Item -ItemType Directory -Force "$wt\.godot" | Out-Null
foreach ($p in "imported","shader_cache") { Copy-Item -Recurse -Force "$main\.godot\$p" "$wt\.godot\" }
foreach ($f in "uid_cache.bin","global_script_class_cache.cfg","scene_groups_cache.cfg") { Copy-Item -Force "$main\.godot\$f" "$wt\.godot\" }
$exe = "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$wt`" -e"; CurrentDirectory = $wt }
```

Then poll `session_manage(op="list")` until a session whose `project_path` is the worktree reports `ready`. Record its id as `$SID`.

- [ ] **Step 2: Write the failing tests**

Append to `tests/test_shop_weekly_stock.gd`, after `test_a_new_grade_is_a_new_week`:

```gdscript
## Nine names, like the catalog, so the roll's odds match the game's.
func _nine() -> Array[String]:
	return ["A", "B", "C", "D", "E", "F", "G", "H", "I"]


## Six slots, filled from a bag holding every item twice (2026-09-17 revamp).
func test_a_roll_fills_every_slot_and_caps_copies() -> void:
	var full := true
	var capped := true
	for _i in range(200):
		var stock: Array[String] = GameState.roll_shop_stock(_nine(), 6, 2)
		full = full and stock.size() == 6
		for item_name in stock:
			capped = capped and stock.count(item_name) <= 2
	assert_true(full, "every roll fills all six slots")
	assert_true(capped, "no roll holds an item more than twice")


func test_pairs_turn_up() -> void:
	var paired := false
	for _i in range(200):
		var stock: Array[String] = GameState.roll_shop_stock(_nine(), 6, 2)
		for item_name in stock:
			paired = paired or stock.count(item_name) == 2
	assert_true(paired, "about 71% of rolls hold a pair; 200 rolls without one is ~0 odds")


func test_a_small_catalog_cannot_overfill() -> void:
	var names: Array[String] = ["A", "B"]
	assert_eq(GameState.roll_shop_stock(names, 6, 2).size(), 4,
		"two items, two copies each: four units is all the bag holds")


func test_the_weekly_shelf_is_six_with_pairs_at_most() -> void:
	assert_eq(GameState.SHOP_SHELF_SIZE, 6, "one per Barang slot on the Stage")
	assert_eq(GameState.SHOP_MAX_COPIES, 2, "a pair at most")
	_at(7, 2)
	var stock: Array[String] = GameState.shop_stock_for_week()
	for item_name in stock:
		assert_true(stock.count(item_name) <= GameState.SHOP_MAX_COPIES,
			item_name + " appears at most twice")
```

- [ ] **Step 3: Run the tests to verify they fail**

`filesystem_manage(op="scan", session_id=$SID)`, then
Run: `test_run(suite="shop_weekly_stock", session_id=$SID)`
Expected: FAIL. The four new tests error on `roll_shop_stock` (not a member) and `SHOP_SHELF_SIZE` is 4. The existing tests still pass.

- [ ] **Step 4: Implement**

`Scripts/GameState.gd`, replacing the `SHOP_SHELF_SIZE` block and its doc:

```gdscript
## How many items the Koperasi shelf shows -- one per Barang* slot on
## koprasi.tscn's Stage.
const SHOP_SHELF_SIZE: int = 6
## The most copies of one item a week's shelf can hold.
const SHOP_MAX_COPIES: int = 2
```

Change the `shop_stock` doc to `## Item names on the Koperasi shelf this week, in slot order. An item can fill up to SHOP_MAX_COPIES slots.`

Replace `shop_stock_for_week()` and add the roll above it:

```gdscript
## A shelf of `size` names drawn from a bag holding every name
## `max_copies` times, in slot order. Pure, apart from the global RNG
## that shuffle() uses.
static func roll_shop_stock(names: Array[String], size: int, max_copies: int) -> Array[String]:
	var bag: Array[String] = []
	for item_name in names:
		for _copy in range(max_copies):
			bag.append(item_name)
	bag.shuffle()
	var stock: Array[String] = []
	for i in range(mini(size, bag.size())):
		stock.append(bag[i])
	return stock


## This week's Koperasi shelf. The first call in a (grade, week) rolls
## SHOP_SHELF_SIZE items from ItemDatabase (roll_shop_stock, so a pair can
## turn up) and clears shop_sold; every later call that week returns the
## same items in the same order.
func shop_stock_for_week() -> Array[String]:
	var key := shop_week_key_for(current_grade, minggu_ke)
	if key != shop_week_key:
		shop_week_key = key
		shop_sold = []
		var names: Array[String] = []
		for item in ItemDatabase.get_all_items():
			names.append(item.item_name)
		shop_stock = roll_shop_stock(names, SHOP_SHELF_SIZE, SHOP_MAX_COPIES)
	return shop_stock.duplicate()
```

In `Scripts/Inventory/ItemDatabase.gd`, line 8's parenthetical becomes `(get_all_items, which GameState.shop_stock_for_week() reads once a`. Keep the rest of that sentence.

Force reload: a no-op `script_patch` on `res://Scripts/GameState.gd` and `res://Scripts/Inventory/ItemDatabase.gd` with `session_id=$SID`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="shop_weekly_stock", session_id=$SID)`
Expected: PASS, all tests.

- [ ] **Step 6: Commit**

```
git add Scripts/GameState.gd Scripts/Inventory/ItemDatabase.gd tests/test_shop_weekly_stock.gd
git commit -F <scratch>/msg.txt     # feat(koperasi): six-slot weekly shelf that can hold a pair
```

---

### Task 2: Sales count per unit

**Files:**
- Modify: `Scripts/GameState.gd` (`shop_sold` doc, `mark_shop_sold`, `is_shop_sold_out`)
- Modify: `Scripts/Koperasi/koprasi.gd` (`_on_beli_pressed` loop)
- Test: `tests/test_shop_weekly_stock.gd`

**Interfaces:**
- Consumes: `GameState.shop_stock` (Task 1)
- Produces: `shop_sold` is a multiset. `mark_shop_sold(name)` appends while `shop_sold.count(name) < maxi(1, shop_stock.count(name))`.

- [ ] **Step 1: Write the failing tests**

Replace `test_an_item_sells_once` in `tests/test_shop_weekly_stock.gd` with:

```gdscript
func test_a_single_copy_sells_once() -> void:
	GameState.shop_stock = ["Bank Soal", "Komik"]
	GameState.mark_shop_sold("Bank Soal")
	GameState.mark_shop_sold("Bank Soal")
	assert_eq(GameState.shop_sold.count("Bank Soal"), 1, "marked once, however often Beli sees it")
	assert_true(GameState.is_shop_sold("Bank Soal"), "and reads back as sold")
	assert_false(GameState.is_shop_sold(FAKE_ITEM), "another item is not")


func test_a_pair_sells_twice() -> void:
	GameState.shop_stock = ["Bank Soal", "Komik", "Bank Soal"]
	for _i in range(3):
		GameState.mark_shop_sold("Bank Soal")
	assert_eq(GameState.shop_sold.count("Bank Soal"), 2, "one sale per copy on the shelf, no more")


func test_an_unstocked_item_still_sells_once() -> void:
	GameState.mark_shop_sold("Bank Soal")
	GameState.mark_shop_sold("Bank Soal")
	assert_eq(GameState.shop_sold.count("Bank Soal"), 1, "an unrolled shelf counts as one copy")


func test_a_pair_is_sold_out_only_once_both_sold() -> void:
	GameState.shop_stock = ["Bank Soal", "Komik", "Bank Soal"]
	GameState.mark_shop_sold("Bank Soal")
	GameState.mark_shop_sold("Komik")
	assert_false(GameState.is_shop_sold_out(), "the second Bank Soal is still on the shelf")
	GameState.mark_shop_sold("Bank Soal")
	assert_true(GameState.is_shop_sold_out(), "both copies gone")


func test_beli_marks_every_unit() -> void:
	var body := _body(FileAccess.get_file_as_string(KOPERASI_PATH), "func _on_beli_pressed()")
	assert_true(body.contains("for _unit in range(quantity):"),
		"a line of two marks two sales, so the pair's second slot stays empty")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="shop_weekly_stock", session_id=$SID)`
Expected: FAIL on `test_a_pair_sells_twice` (count 1), `test_a_pair_is_sold_out_only_once_both_sold` (sold out after one of the pair) and `test_beli_marks_every_unit`.

- [ ] **Step 3: Implement**

`Scripts/GameState.gd`:

```gdscript
## Item names bought this week, one entry per unit. An item sells once per
## copy on the shelf.
var shop_sold: Array[String] = []
```

```gdscript
## Record one unit of `item_name` bought this week. Capped at the copies on
## the shelf (at least one, so an unstocked name still sells once).
func mark_shop_sold(item_name: String) -> void:
	if shop_sold.count(item_name) < maxi(1, shop_stock.count(item_name)):
		shop_sold.append(item_name)
```

```gdscript
## True once every copy on this week's shelf has been bought. False before
## the shelf is first rolled.
func is_shop_sold_out() -> bool:
	if shop_stock.is_empty():
		return false
	for item_name in shop_stock:
		if shop_sold.count(item_name) < shop_stock.count(item_name):
			return false
	return true
```

`Scripts/Koperasi/koprasi.gd`, in `_on_beli_pressed()`, replace the transfer loop:

```gdscript
	for item_name in Cart.cart:
		var quantity = Cart.cart[item_name]["quantity"]
		GameState.add_to_inventory(item_name, quantity)
		for _unit in range(quantity):
			GameState.mark_shop_sold(item_name)
```

No-op `script_patch` on both files.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="shop_weekly_stock", session_id=$SID)`
Expected: PASS. `test_the_shelf_is_sold_out_only_once_every_item_sold` also still passes, because a pair's first mark leaves the last slot's copy unsold.

- [ ] **Step 5: Commit**

```
git add Scripts/GameState.gd Scripts/Koperasi/koprasi.gd tests/test_shop_weekly_stock.gd
git commit -F <scratch>/msg.txt     # feat(koperasi): count shop sales per unit
```

---

### Task 3: The shelf tracks which slot emptied

**Files:**
- Modify: `Scripts/Koperasi/rakbarang_1.gd` (header, new vars, `setup_shelf`, delete `is_on_sale`, add `reconcile_taken`, `_refresh_shelf_visibility`, `_on_barang_pressed`)
- Test: `tests/test_shop_weekly_stock.gd` (the `# ─── the shelf` section)

**Interfaces:**
- Consumes: `Cart.cart` shape `{name: {"data": ItemData, "quantity": int}}`, `GameState.shop_sold` multiset (Task 2)
- Produces: `static func reconcile_taken(stock: Array, taken: Array, cart: Dictionary, sold: Array) -> Array[int]`, `var _taken_slots: Array[int]`, `var _stock_names: Array[String]`

- [ ] **Step 1: Write the failing tests**

In `tests/test_shop_weekly_stock.gd`, delete `test_an_item_is_on_sale_until_basketed_or_sold` and add:

```gdscript
## Slot 0 and 2 hold the pair.
func _pair_shelf() -> Array:
	return ["Bank Soal", "Komik", "Bank Soal"]


func _reconciled(taken: Array, cart: Dictionary, sold: Array) -> String:
	return str(RakScript.reconcile_taken(_pair_shelf(), taken, cart, sold))


func test_a_fresh_shelf_has_nothing_taken() -> void:
	assert_eq(_reconciled([], {}, []), "[]")


func test_the_tapped_copy_is_the_one_that_empties() -> void:
	assert_eq(_reconciled([2], {"Bank Soal": {"quantity": 1}}, []), "[2]",
		"tapping the second copy leaves the first on the shelf")


func test_hold_to_return_brings_back_the_latest_copy() -> void:
	assert_eq(_reconciled([0, 2], {"Bank Soal": {"quantity": 1}}, []), "[0]",
		"one unit returned: the slot taken last comes back")


func test_a_sale_seen_on_a_later_visit_empties_the_lowest_slot() -> void:
	assert_eq(_reconciled([], {}, ["Bank Soal"]), "[0]")


func test_back_returns_every_unsold_slot() -> void:
	assert_eq(_reconciled([0, 1], {}, []), "[]")


func test_beli_keeps_the_bought_slots_empty() -> void:
	assert_eq(_reconciled([2, 1], {}, ["Bank Soal", "Komik"]), "[2, 1]")


func test_out_of_range_slots_are_dropped() -> void:
	assert_eq(_reconciled([7], {}, []), "[]")


func test_one_items_units_never_move_another() -> void:
	assert_eq(_reconciled([1], {"Komik": {"quantity": 1}}, ["Bank Soal"]), "[1, 0]")


func test_a_taken_slot_refuses_a_second_tap() -> void:
	var body := _body(FileAccess.get_file_as_string(RAK_PATH), "func _on_barang_pressed(")
	assert_true(body.contains("if _taken_slots.has(index):"), "a double tap cannot add a second unit")
	var take := body.find("_taken_slots.append(index)")
	assert_true(take != -1 and take < body.find("Cart.add_item(item)"),
		"the slot is taken before the cart hears of it, so the refresh keeps it empty")


func test_visibility_comes_from_reconcile() -> void:
	var src := FileAccess.get_file_as_string(RAK_PATH)
	assert_true(_body(src, "func _refresh_shelf_visibility()").contains("reconcile_taken("))
	assert_false(src.contains("func is_on_sale("), "the name-only check is gone")
```

Delete `test_a_second_tap_cannot_add_a_second_unit` (its replacement is `test_a_taken_slot_refuses_a_second_tap`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="shop_weekly_stock", session_id=$SID)`
Expected: FAIL. `reconcile_taken` is not a member, and the source scans miss.

- [ ] **Step 3: Implement**

`Scripts/Koperasi/rakbarang_1.gd`. Replace the header's second and third paragraphs:

```gdscript
## The koperasi Stage (koprasi.tscn:Stage): Pak Herman's counter as one
## 1080x1920 piece -- the art layers, this week's six items on the shelf,
## each with a coin-pill price tag and a little life, the chat bubble, the
## back button and the basket tray.
##
## The shelf is rolled once a week (GameState.shop_stock_for_week()) and can
## hold two copies of an item. Each slot sells once. Cart stays keyed by
## name, so the shelf keeps which SLOT emptied itself (_taken_slots) and
## re-derives it from Cart and GameState.shop_sold on every cart change
## (reconcile_taken()).
```

Change `@onready var tray: BasketTray = $BasketTray` to `$TrayDock/BasketTray`, and its doc to `## The basket tray, docked at the bottom of the Stage.`

Add after `var item_data_list`:

```gdscript
## Item name per shelf slot, parallel to item_data_list. A pair shows twice.
var _stock_names: Array[String] = []
## Slots emptied -- tapped into the basket or sold this week -- in the order
## they emptied. Rebuilt by reconcile_taken() on every cart change.
var _taken_slots: Array[int] = []
```

In `setup_shelf()`, after the `item_data_list` loop:

```gdscript
	_stock_names.clear()
	for stocked in item_data_list:
		_stock_names.append(stocked.item_name)
```

Delete `is_on_sale()` and its doc. Add in its place:

```gdscript
## Which slots are empty, given what the player took (`taken`, in the order
## they took it), the basket (`cart`, Cart.cart-shaped) and this week's
## sales (`sold`, one entry per unit). For each item the empty-slot count is
## its sold units plus its basket units, capped at its copies on the shelf:
## extra slots leave from the end of `taken` (hold-to-return brings back the
## latest), missing ones are taken lowest index first (a sale from an
## earlier visit).
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func reconcile_taken(stock: Array, taken: Array, cart: Dictionary, sold: Array) -> Array[int]:
	var result: Array[int] = []
	for slot in taken:
		if slot >= 0 and slot < stock.size() and not result.has(slot):
			result.append(slot)
	var names: Array = []
	for item_name in stock:
		if not names.has(item_name):
			names.append(item_name)
	for item_name in names:
		var in_cart: int = int(cart[item_name].get("quantity", 0)) if cart.has(item_name) else 0
		var want := mini(stock.count(item_name), sold.count(item_name) + in_cart)
		var mine: Array[int] = []
		for slot in result:
			if stock[slot] == item_name:
				mine.append(slot)
		while mine.size() > want:
			result.erase(mine.pop_back())
		for slot in range(stock.size()):
			if mine.size() >= want:
				break
			if stock[slot] == item_name and not mine.has(slot):
				mine.append(slot)
				result.append(slot)
	return result
```

Replace `_refresh_shelf_visibility()`:

```gdscript
## Show each shelf slot only while it is not taken. Derived from Cart and
## GameState every time (reconcile_taken), so tap, hold-to-return, Back and
## Beli agree. A slot returning to a visible shelf bounces back in -- scale
## only, so an unaffordable item keeps ShelfItem.set_dimmed()'s alpha rather
## than fading up to full.
func _refresh_shelf_visibility() -> void:
	_taken_slots = reconcile_taken(_stock_names, _taken_slots, Cart.cart, GameState.shop_sold)
	for i in range(shelf_buttons.size()):
		var btn: TextureButton = shelf_buttons[i]
		var on_sale: bool = i < _stock_names.size() and not _taken_slots.has(i)
		var was_hidden := not btn.visible
		btn.visible = on_sale
		if on_sale and was_hidden and btn.is_visible_in_tree():
			AnimUtils.squash_bounce(btn)
```

In `_on_barang_pressed(index)`, replace the guard and add the take:

```gdscript
	var item = item_data_list[index]
	# Each slot sells once: a second tap landing before the button hides
	# must not add a second unit.
	if _taken_slots.has(index):
		return
	var btn = shelf_buttons[index]
```

and, just before `tray.hold_for_landing(item.item_name)`:

```gdscript
	# Take the slot before the cart hears of it, so the refresh that
	# Cart.add_item() triggers empties THIS slot, not the pair's other copy.
	_taken_slots.append(index)
```

No-op `script_patch` on `res://Scripts/Koperasi/rakbarang_1.gd`. (Until Task 5 the scene has no `TrayDock`. Only the scene-instancing suites notice, and they are rerun there.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="shop_weekly_stock", session_id=$SID)` and `test_run(suite="viewport_editability", session_id=$SID)`
Expected: both PASS. No new `.new()` visual construction was added.

- [ ] **Step 5: Commit**

```
git add Scripts/Koperasi/rakbarang_1.gd tests/test_shop_weekly_stock.gd
git commit -F <scratch>/msg.txt     # feat(koperasi): the tapped shelf slot is the one that empties
```

---

### Task 4: Chat bubble style and tail art

**Files:**
- Create: `Assets/Images/Shop/UI/chat_bubble_tail.svg`
- Modify: `Scripts/Design/ThemeFactory.gd` (const + `_build_shop_chat_bubble`, called from `build`)
- Modify (rebake): `Assets/Theme/kejartes_theme.tres`
- Test: `tests/test_koperasi_shop_layout.gd` (new, `suite_name()` = `"koperasi_shop_layout"`)

**Interfaces:**
- Produces: theme variation `ShopChatBubble` (PanelContainer), texture `res://Assets/Images/Shop/UI/chat_bubble_tail.svg` (65×115)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_koperasi_shop_layout.gd`:

```gdscript
@tool
extends McpTestSuite

## The 2026-09-17 Koperasi revamp (spec
## docs/superpowers/specs/2026-09-17-koperasi-shop-revamp-design.md): Pak
## Herman's counter as three art layers, six shelf slots on the mockup's
## circles, and a placeholder chat bubble whose tail matches its box.
##
## Must be @tool; no test here may be a coroutine.

const SCENE := "res://Scenes/Koperasi/koprasi.tscn"
const TAIL := "res://Assets/Images/Shop/UI/chat_bubble_tail.svg"


func suite_name() -> String:
	return "koperasi_shop_layout"


# ─── the bubble's style

func test_the_bubble_is_a_flat_card_box() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("panel", "ShopChatBubble") as StyleBoxFlat
	assert_true(box != null, "ShopChatBubble has a flat panel")
	if box == null:
		return
	assert_eq(theme.get_type_variation_base("ShopChatBubble"), &"PanelContainer")
	assert_eq(box.bg_color, tokens.surface_card, "card white, from the tokens")
	assert_eq(box.corner_radius_top_left, ThemeFactory.SHOP_CHAT_BUBBLE_RADIUS)
	assert_eq(box.shadow_size, 0, "the mockup's bubble has no shadow")


func test_the_tail_is_filled_with_the_bubbles_colour() -> void:
	var svg := FileAccess.get_file_as_string(TAIL)
	assert_true(svg != "", "tail art missing at " + TAIL)
	var want := "#" + DesignTokens.load_default().surface_card.to_html(false).to_upper()
	assert_true(svg.contains('fill="%s"' % want),
		"the tail must match surface_card (%s), or a seam shows where it meets the box" % want)
	for element in ["<text", "<tspan", "<use"]:
		assert_false(svg.contains(element), "ThorVG drops " + element)


func test_the_bubble_is_baked() -> void:
	var baked := ResourceLoader.load("res://Assets/Theme/kejartes_theme.tres", "",
		ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_true(baked != null and baked.has_stylebox("panel", "ShopChatBubble"),
		"rebake after adding the variation")
```

- [ ] **Step 2: Run the tests to verify they fail**

`filesystem_manage(op="scan", session_id=$SID)`, then
Run: `test_run(suite="koperasi_shop_layout", session_id=$SID)`
Expected: FAIL. No `ShopChatBubble` stylebox, no tail file, nothing baked.

- [ ] **Step 3: Implement**

Create `Assets/Images/Shop/UI/chat_bubble_tail.svg`. Check the `surface_card` default in `Scripts/Design/DesignTokens.gd:39` first. It is `FFFDF8`; if it differs, use its value:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="65" height="115" viewBox="0 0 65 115"><path d="M0 0 L65 0 L65 115 Z" fill="#FFFDF8"/></svg>
```

`Scripts/Design/ThemeFactory.gd`: add `_build_shop_chat_bubble(theme, tokens)` to `build()` right after `_build_event_dialogue(theme, tokens)`, and below the `DAY_BANNER_OUTLINE` const:

```gdscript
## Measured off newshop_mockup.png: the Koperasi chat bubble's ~24 px corner
## at the mockup's 5/6 scale. No token matches; a single-screen value.
const SHOP_CHAT_BUBBLE_RADIUS := 28


## Koperasi's chat bubble (2026-09-17 shop revamp spec): Pak Herman's
## speech, a flat card-white rounded box with no shadow. Its tail is
## chat_bubble_tail.svg, filled with the same surface_card colour
## (test_koperasi_shop_layout pins that). Body font, so not on DISPLAY_ROSTER.
static func _build_shop_chat_bubble(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("ShopChatBubble")
	theme.set_type_variation("ShopChatBubble", "PanelContainer")
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = tokens.surface_card
	bubble.set_corner_radius_all(SHOP_CHAT_BUBBLE_RADIUS)
	bubble.content_margin_left = tokens.space_xl
	bubble.content_margin_right = tokens.space_xl
	bubble.content_margin_top = tokens.space_lg
	bubble.content_margin_bottom = tokens.space_lg
	theme.set_stylebox("panel", "ShopChatBubble", bubble)
```

No-op `script_patch` on ThemeFactory.gd, then `filesystem_manage(op="scan", session_id=$SID)` so the SVG imports.

- [ ] **Step 4: Rebake alone, then run the tests**

Run: `test_run(suite="theme_rebake", session_id=$SID)`. It writes `kejartes_theme.tres`. Then
Run: `test_run(suite="koperasi_shop_layout", session_id=$SID)` and `test_run(suite="theme_factory", session_id=$SID)`
Expected: all PASS.

Check `git diff --stat Assets/Theme/kejartes_theme.tres`. Expect a small diff that adds `ShopChatBubble`. A mass renumber of stylebox ids is also fine (memory: bake conflicts); verify by content.

- [ ] **Step 5: Commit, then quit the editor (rebake before a scene save needs a restart)**

```
git add Assets/Images/Shop/UI/chat_bubble_tail.svg Assets/Images/Shop/UI/chat_bubble_tail.svg.import Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_koperasi_shop_layout.gd tests/test_koperasi_shop_layout.gd.uid
git commit -F <scratch>/msg.txt     # feat(koperasi): ShopChatBubble variation and its tail art
```

Then `editor_manage(op="quit", session_id=$SID)`. If it times out, stop that PID after checking that its CommandLine contains `shop-revamp`. Task 5 writes the scene with the editor closed.

---

### Task 5: The counter scene

**Files:**
- Create: `Assets/Images/Shop/Koperasi/shop_background.png`, `shop_herman.png`, `shop_foreground.png` (copied from `C:\Users\user\Downloads\`)
- Rewrite: `Scenes/Koperasi/koprasi.tscn`
- Rewrite: `Scripts/Koperasi/koprasi.gd`
- Modify tests: `tests/test_koperasi_shop_layout.gd` (scene tests), `tests/test_tall_screen_layout.gd` (Koperasi section), `tests/test_koperasi_tray.gd` (`test_each_shelf_item_has_a_glow_behind_it`), `tests/test_shop_weekly_stock.gd` (`test_opening_the_shelf_restocks_it_for_the_week`), `tests/test_koperasi.gd` (drop `test_script_reads_design_tokens`)

**Interfaces:**
- Consumes: `ShopChatBubble`, `chat_bubble_tail.svg` (Task 4); `rakbarang_1.gd` expecting `$TrayDock/BasketTray` (Task 3)
- Produces: nodes `WallFill`, `Stage/{Background, Barang1..6/{Glow,PriceTag}, Herman, Foreground, ChatBubble/{Body/Text, Tail}, BackButton, TrayDock/BasketTray}`, `Safe/UI/CoinHUD`, `MessageLabel`

- [ ] **Step 1: Write the failing tests (editor closed; plain file edits)**

Append to `tests/test_koperasi_shop_layout.gd`:

```gdscript
# ─── the scene

func _shop() -> Control:
	var shop := (load(SCENE) as PackedScene).instantiate() as Control
	track(shop)
	return shop


func _rect(c: Control) -> Rect2:
	return Rect2(c.offset_left, c.offset_top,
		c.offset_right - c.offset_left, c.offset_bottom - c.offset_top)


func test_the_three_layers_stack_full_size_and_let_taps_through() -> void:
	var stage := _shop().get_node_or_null("Stage") as Control
	assert_true(stage != null, "missing the Stage")
	if stage == null:
		return
	var art := {
		"Background": "res://Assets/Images/Shop/Koperasi/shop_background.png",
		"Herman": "res://Assets/Images/Shop/Koperasi/shop_herman.png",
		"Foreground": "res://Assets/Images/Shop/Koperasi/shop_foreground.png",
	}
	for layer in art:
		var tex := stage.get_node_or_null(layer) as TextureRect
		assert_true(tex != null, layer + " missing")
		if tex == null:
			continue
		assert_eq(tex.texture.resource_path, art[layer], layer + "'s art")
		assert_eq(tex.texture.get_size(), Vector2(1080, 1920), layer + " is drawn at 1080x1920")
		assert_eq(Vector4(tex.anchor_left, tex.anchor_top, tex.anchor_right, tex.anchor_bottom),
			Vector4(0, 0, 1, 1), layer + " fills the stage")
		assert_eq(tex.mouse_filter, Control.MOUSE_FILTER_IGNORE, layer + " never eats a tap")
	var order := ["Background", "Barang1", "Barang6", "Herman", "Foreground",
		"ChatBubble", "BackButton", "TrayDock"]
	for i in range(order.size() - 1):
		assert_true(stage.get_node(order[i]).get_index() < stage.get_node(order[i + 1]).get_index(),
			"%s draws under %s" % [order[i], order[i + 1]])


## Measured off newshop_mockup.png's circles: diameter 180, centres
## x 126 / 490 and y 400 / 676 / 944, numbered row by row.
func test_six_slots_sit_on_the_mockups_circles() -> void:
	var stage := _shop().get_node("Stage")
	var want := [Rect2(36, 310, 180, 180), Rect2(400, 310, 180, 180),
		Rect2(36, 586, 180, 180), Rect2(400, 586, 180, 180),
		Rect2(36, 854, 180, 180), Rect2(400, 854, 180, 180)]
	for i in range(6):
		var slot := stage.get_node_or_null("Barang%d" % (i + 1)) as TextureButton
		assert_true(slot != null, "Barang%d missing" % (i + 1))
		if slot == null:
			continue
		assert_eq(_rect(slot), want[i], "Barang%d's circle" % (i + 1))
		assert_true(slot.get_node_or_null("PriceTag") != null, "Barang%d's price tag is in the scene" % (i + 1))
	assert_true(stage.get_node_or_null("Barang7") == null, "six slots, no more")


func test_the_bubble_points_at_herman() -> void:
	var bubble := _shop().get_node_or_null("Stage/ChatBubble") as Control
	assert_true(bubble != null, "missing Stage/ChatBubble")
	if bubble == null:
		return
	assert_eq(_rect(bubble), Rect2(36, 23, 1010, 345), "box plus tail, off the mockup")
	assert_eq(bubble.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var body := bubble.get_node("Body") as PanelContainer
	assert_eq(body.theme_type_variation, &"ShopChatBubble")
	assert_eq(_rect(body), Rect2(0, 0, 1010, 233), "the box")
	var tail := bubble.get_node("Tail") as TextureRect
	assert_eq(tail.texture.resource_path, TAIL)
	assert_eq(_rect(tail), Rect2(751, 230, 65, 115), "tip at (852, 368) on screen")
	var text := bubble.get_node("Body/Text") as RichTextLabel
	assert_eq(text.theme_type_variation, &"EventDialogueText", "the game's speaking voice")
	assert_true(text.text.length() > 0, "placeholder copy until the real lines land")


func test_the_old_landing_is_gone() -> void:
	var raw := FileAccess.get_file_as_string(SCENE)
	for gone in ["KEBUTUHAN SEKOLAH", "ShopShelfButton", "Illustration4.jpg", "rak2.jpg"]:
		assert_false(raw.contains(gone), "koprasi.tscn still carries " + gone)
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/koprasi.gd")
	assert_false(src.contains("_on_rak1_pressed"), "no shelf toggle: the counter is the screen")
```

In `tests/test_tall_screen_layout.gd`, replace everything from `const KOPERASI :=` through `test_koperasi_at_the_design_size_is_unchanged` (inclusive) with:

```gdscript
const KOPERASI := "res://Scenes/Koperasi/koprasi.tscn"


## A flat wall strip fills the screen and covers; it only shows above the
## counter on a phone taller than 9:16.
func test_koperasi_wall_fills() -> void:
	_assert_background_fills(_scene(KOPERASI).get_node_or_null("WallFill") as TextureRect,
		"Koperasi wall strip (WallFill)")


## The counter -- art layers, six items, bubble, back button and tray -- is
## one 1080x1920 piece pinned to the bottom edge, so the tray still ends
## flush with it.
func test_koperasi_stage_is_one_piece_pinned_bottom() -> void:
	var stage := _scene(KOPERASI).get_node_or_null("Stage") as Control
	assert_true(stage != null, "missing the Stage")
	if stage == null:
		return
	assert_eq(_anchors(stage), Vector4(0, 1, 0, 1), "Stage pins to the bottom edge")
	assert_eq(_offsets(stage), Vector4(0, -1920, 1080, 0), "and keeps its 1080x1920 rect")
	for n in ["Background", "Barang1", "Barang6", "Herman", "Foreground", "ChatBubble",
			"BackButton", "TrayDock/BasketTray"]:
		assert_true(stage.get_node_or_null(n) != null, n + " moves with the stage")


## The coin readout sits in the safe area on the counter ledge, bottom-right,
## because the bubble fills the top. Nothing over the shelf eats a tap.
func test_koperasi_coin_hud_sits_in_the_safe_area() -> void:
	var shop := _scene(KOPERASI)
	var hud := shop.get_node_or_null("%CoinHUD") as Control
	_assert_under_safe_area(hud, "CoinHUD")
	if hud == null:
		return
	assert_eq(_anchors(hud), Vector4(1, 1, 1, 1), "CoinHUD pins bottom-right")
	for p in ["Safe", "Safe/UI", "WallFill", "Stage", "Stage/TrayDock"]:
		var c := shop.get_node_or_null(p) as Control
		assert_true(c != null and c.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			p + " must let taps through to the shelf")


## On a 1080x2400 phone the counter rides the bottom edge and the coins ride
## with it.
func test_koperasi_on_a_tall_phone() -> void:
	var shop := _stood_up(KOPERASI, TALL)
	_assert_placed((shop.get_node("WallFill") as Control), Rect2(0, 0, 1080, 2400), "wall strip")
	_assert_placed((shop.get_node("Stage") as Control), Rect2(0, 480, 1080, 1920), "stage")
	_assert_placed((shop.get_node("Stage/TrayDock/BasketTray/Body") as Control),
		Rect2(24, 1840, 1032, 560), "basket tray")
	assert_eq(_authored_rect(shop.get_node("%CoinHUD") as Control).position,
		Vector2(732, 1710), "the coins stay on the counter ledge")


## At 1080x1920 the tray and back button are where they were.
func test_koperasi_at_the_design_size() -> void:
	var shop := _stood_up(KOPERASI, DESIGN)
	_assert_placed((shop.get_node("Stage") as Control), Rect2(0, 0, 1080, 1920), "stage")
	_assert_placed((shop.get_node("Stage/TrayDock/BasketTray/Body") as Control),
		Rect2(24, 1360, 1032, 560), "basket tray, unchanged")
	_assert_placed((shop.get_node("Stage/BackButton") as Control),
		Rect2(24, 1157, 185, 185), "back button, unchanged")
	assert_eq(_authored_rect(shop.get_node("%CoinHUD") as Control).position,
		Vector2(732, 1230), "coins on the ledge")
```

In `tests/test_koperasi_tray.gd`, `test_each_shelf_item_has_a_glow_behind_it`: `range(1, 5)` → `range(1, 7)`, `"Rak1/Barang%d/Glow"` → `"Stage/Barang%d/Glow"`.

In `tests/test_shop_weekly_stock.gd`, replace `test_opening_the_shelf_restocks_it_for_the_week`:

```gdscript
func test_arriving_restocks_the_shelf_for_the_week() -> void:
	var rak := _body(FileAccess.get_file_as_string(RAK_PATH), "func _ready()")
	assert_true(rak.contains("setup_shelf()"), "the Stage restocks itself on arrival")
	var src := FileAccess.get_file_as_string(KOPERASI_PATH)
	assert_false(src.contains("setup_random_items"), "not the old reshuffle")
	assert_true(src.contains("GameState.is_shop_sold_out()"), "an empty shelf explains itself")
```

In `tests/test_koperasi.gd`, delete `test_script_reads_design_tokens`. koprasi.gd no longer styles or animates anything with tokens. The Transition wipe does the work.

- [ ] **Step 2: Copy the art and write the scene (editor still closed)**

```
mkdir -p Assets/Images/Shop/Koperasi
cp /c/Users/user/Downloads/shop_background.png Assets/Images/Shop/Koperasi/
cp /c/Users/user/Downloads/shop_herman.png Assets/Images/Shop/Koperasi/
cp /c/Users/user/Downloads/shop_foreground.png Assets/Images/Shop/Koperasi/
```

Write `Scenes/Koperasi/koprasi.tscn` in full. New ext_resources carry no `uid=`; Step 4's re-save adds them.

```
[gd_scene format=3 uid="uid://dgdiebg5vu00j"]

[ext_resource type="Script" uid="uid://ioeh8qtnpgo5" path="res://Scripts/Koperasi/koprasi.gd" id="1_ap2qe"]
[ext_resource type="Texture2D" path="res://Assets/Images/Shop/Koperasi/shop_background.png" id="2_bg"]
[ext_resource type="Texture2D" path="res://Assets/Images/Shop/Koperasi/shop_herman.png" id="3_herman"]
[ext_resource type="Texture2D" path="res://Assets/Images/Shop/Koperasi/shop_foreground.png" id="4_fg"]
[ext_resource type="Texture2D" uid="uid://fuwhxl8ethbp" path="res://Assets/Images/Shop/return.png" id="5_46s2e"]
[ext_resource type="Script" uid="uid://bgp5ht1pwg3s1" path="res://Scripts/Koperasi/rakbarang_1.gd" id="5_jfwhh"]
[ext_resource type="Texture2D" path="res://Assets/Images/Shop/UI/chat_bubble_tail.svg" id="6_tail"]
[ext_resource type="Texture2D" uid="uid://ku8mk6u7pm31" path="res://Assets/Images/Shop/UI/item_glow.tres" id="8_st3ia"]
[ext_resource type="PackedScene" uid="uid://dwgcebdsp5rjh" path="res://Scenes/Koperasi/PriceTag.tscn" id="9_tag"]
[ext_resource type="PackedScene" uid="uid://0ais0usytajp" path="res://Scenes/Koperasi/BasketTray.tscn" id="11_rr7aj"]
[ext_resource type="Script" uid="uid://88qrfscj2817" path="res://Scripts/UI/SafeAreaMargin.gd" id="13_pstwm"]
[ext_resource type="Texture2D" uid="uid://cinn50y7nlgac" path="res://Assets/Images/UI/uang.png" id="14_pstwm"]
[ext_resource type="Theme" uid="uid://bo3dwau466faa" path="res://Assets/Theme/kejartes_theme.tres" id="kejartes_theme"]

[sub_resource type="AtlasTexture" id="AtlasTexture_wall"]
atlas = ExtResource("2_bg")
region = Rect2(0, 0, 1080, 160)

[node name="Koprasi" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("kejartes_theme")
script = ExtResource("1_ap2qe")

[node name="WallFill" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = SubResource("AtlasTexture_wall")
expand_mode = 1
stretch_mode = 6

[node name="Stage" type="Control" parent="."]
layout_mode = 1
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_top = -1920.0
offset_right = 1080.0
grow_vertical = 0
mouse_filter = 2
script = ExtResource("5_jfwhh")

[node name="Background" type="TextureRect" parent="Stage"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("2_bg")
expand_mode = 1
```

Then `Barang1`…`Barang6`, each block identical except the name and the four offsets from the spec table (1: 36,310,216,490 · 2: 400,310,580,490 · 3: 36,586,216,766 · 4: 400,586,580,766 · 5: 36,854,216,1034 · 6: 400,854,580,1034). Shown for Barang1:

```
[node name="Barang1" type="TextureButton" parent="Stage"]
layout_mode = 0
offset_left = 36.0
offset_top = 310.0
offset_right = 216.0
offset_bottom = 490.0
ignore_texture_size = true
stretch_mode = 5

[node name="Glow" type="TextureRect" parent="Stage/Barang1"]
modulate = Color(1, 1, 1, 0)
show_behind_parent = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -32.0
offset_top = -32.0
offset_right = 32.0
offset_bottom = 32.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("8_st3ia")
expand_mode = 1

[node name="PriceTag" parent="Stage/Barang1" instance=ExtResource("9_tag")]
layout_mode = 0
offset_left = 30.0
offset_top = 176.0
offset_right = 150.0
offset_bottom = 226.0
```

After Barang6:

```
[node name="Herman" type="TextureRect" parent="Stage"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("3_herman")
expand_mode = 1

[node name="Foreground" type="TextureRect" parent="Stage"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("4_fg")
expand_mode = 1

[node name="ChatBubble" type="Control" parent="Stage"]
layout_mode = 1
anchors_preset = 0
offset_left = 36.0
offset_top = 23.0
offset_right = 1046.0
offset_bottom = 368.0
mouse_filter = 2

[node name="Body" type="PanelContainer" parent="Stage/ChatBubble"]
layout_mode = 1
anchors_preset = 0
offset_right = 1010.0
offset_bottom = 233.0
mouse_filter = 2
theme_type_variation = &"ShopChatBubble"

[node name="Text" type="RichTextLabel" parent="Stage/ChatBubble/Body"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"EventDialogueText"
text = "Selamat datang di Koperasi! Mau beli apa hari ini?"
scroll_active = false
vertical_alignment = 1

[node name="Tail" type="TextureRect" parent="Stage/ChatBubble"]
layout_mode = 1
anchors_preset = 0
offset_left = 751.0
offset_top = 230.0
offset_right = 816.0
offset_bottom = 345.0
mouse_filter = 2
texture = ExtResource("6_tail")
expand_mode = 1

[node name="BackButton" type="TextureButton" parent="Stage"]
layout_mode = 0
offset_left = 24.0
offset_top = 1157.0
offset_right = 209.0
offset_bottom = 1342.0
texture_normal = ExtResource("5_46s2e")
ignore_texture_size = true
stretch_mode = 0

[node name="TrayDock" type="Control" parent="Stage"]
layout_mode = 1
anchors_preset = 0
offset_top = 117.0
offset_right = 1080.0
offset_bottom = 1828.0
mouse_filter = 2

[node name="BasketTray" parent="Stage/TrayDock" instance=ExtResource("11_rr7aj")]
layout_mode = 0

[node name="Safe" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("13_pstwm")

[node name="UI" type="Control" parent="Safe"]
layout_mode = 2
mouse_filter = 2

[node name="CoinHUD" type="HBoxContainer" parent="Safe/UI"]
unique_name_in_owner = true
z_index = 10
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -300.0
offset_top = -642.0
offset_bottom = -582.0
grow_horizontal = 0
grow_vertical = 0
theme_override_constants/separation = 10
alignment = 2

[node name="CoinIcon" type="TextureRect" parent="Safe/UI/CoinHUD"]
custom_minimum_size = Vector2(60, 60)
layout_mode = 2
texture = ExtResource("14_pstwm")
expand_mode = 1
stretch_mode = 5

[node name="CoinLabel" type="Label" parent="Safe/UI/CoinHUD"]
layout_mode = 2
theme_type_variation = &"ShopCoinLabel"
vertical_alignment = 1

[node name="MessageLabel" type="Label" parent="."]
z_index = 20
layout_mode = 1
anchors_preset = -1
anchor_top = 0.47
anchor_right = 1.0
anchor_bottom = 0.47
offset_bottom = 80.0
grow_horizontal = 2
theme_type_variation = &"ShopMessageSuccess"
horizontal_alignment = 1
```

(`theme_override_constants/separation` is the layout-only exception CLAUDE.md allows. It was already there.)

- [ ] **Step 3: Rewrite `Scripts/Koperasi/koprasi.gd`**

```gdscript
extends Control

## Koperasi (the shop): Pak Herman's counter. The Stage (rakbarang_1.gd)
## owns the shelf, the flight into the basket and the basket tray; this file
## owns the back button, the coin HUD, the purchase-feedback message and
## Beli.
##
## _on_beli_pressed() deducts GameState.player_money, calls
## GameState.add_to_inventory() for each basket line and marks every unit
## sold for the week (GameState.mark_shop_sold(), once per unit).

@onready var stage: Control = $Stage
@onready var back_button: TextureButton = $Stage/BackButton
# CoinHUD sits in Safe/UI on the counter ledge since the 2026-09-17 revamp.
@onready var coin_hud: HBoxContainer = %CoinHUD
@onready var coin_label: Label = get_node("%CoinHUD/CoinLabel")
@onready var message_label: Label = $MessageLabel

## Shown on arrival when every item this week has been bought.
const SOLD_OUT_TEXT := "Stok habis! Datang lagi minggu depan."

var beli_button: Button

func _ready():
	if back_button:
		back_button.pivot_offset = back_button.size / 2
		if not back_button.pressed.is_connected(_on_back_pressed):
			back_button.pressed.connect(_on_back_pressed)

	_setup_beli_button()
	_update_coin_display()

	# Signal-driven coin updates
	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)

	# The Stage, a child, has already stocked the shelf in its own _ready.
	if GameState.is_shop_sold_out():
		_show_message(SOLD_OUT_TEXT, &"ShopMessageWarning")

func _setup_beli_button():
	# Beli lives in the basket tray's footer.
	var tray = stage.get_node_or_null("TrayDock/BasketTray")
	if tray == null:
		return
	beli_button = tray.get_beli_button()
	if not tray.buy_pressed.is_connected(_on_beli_pressed):
		tray.buy_pressed.connect(_on_beli_pressed)

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

## Leave without buying: the basket empties and the shop hub wipes in.
func _on_back_pressed():
	AnimUtils.back_bounce(back_button)
	Cart.clear()
	if stage.has_method("clear_basket_visuals"):
		stage.clear_basket_visuals()
	AudioDirector.play_sfx(&"popup_close")
	Transition.change_scene("res://Scenes/Koperasi/ShopHub.tscn", Transition.Style.WIPE)

func _on_money_changed(new_amount: int):
	_update_coin_display()

func _update_coin_display():
	if coin_label:
		coin_label.text = "%d" % GameState.player_money
		AnimUtils.coin_pulse(coin_hud)
```

Then keep `_on_beli_pressed()` (with Task 2's per-unit loop) and `_show_message()` verbatim, except that inside `_on_beli_pressed` the lines

```gdscript
	var rak1_script = rak1_panel as Control
	if rak1_script.has_method("clear_basket_visuals"):
		rak1_script.clear_basket_visuals()
```

become

```gdscript
	if stage.has_method("clear_basket_visuals"):
		stage.clear_basket_visuals()
```

- [ ] **Step 4: Launch the editor, import, re-save the scene**

Relaunch the worktree editor exactly as in Task 1 Step 1 (without re-seeding), re-list sessions, and update `$SID`. Then `filesystem_manage(op="scan", session_id=$SID)` so the three PNGs import. Then `scene_open("res://Scenes/Koperasi/koprasi.tscn", session_id=$SID)` → `scene_save(session_id=$SID)`.

Check `git diff HEAD -- '*.gd'`. Only `koprasi.gd`, `rakbarang_1.gd` and the tests should differ. Check `git diff -- Scenes/Koperasi/koprasi.tscn`: the save should only add `uid=` / `unique_id=` and may normalise `anchors_preset`. If any `[node … parent="Stage/TrayDock/BasketTray…"]` block appears without `instance=`, delete it by text with the editor closed (authoring guide).

- [ ] **Step 5: Run the tests**

Run each with `session_id=$SID`: `test_run(suite="koperasi_shop_layout")`, `tall_screen_layout`, `koperasi_tray`, `shop_weekly_stock`, `koperasi`, `koperasi_hud`, `shop_hub`, `viewport_editability`, `script_documentation`, `basket_tray`, `achievements`.
Expected: all PASS. If `tall_screen_layout`'s CoinHUD position is off by the HBox's own minimum width, it is a layout fact, not a test bug: CoinHUD grows left from its right edge. Re-measure the authored rect and correct `offset_left` in the scene (through `node_set_property` + `scene_save`, not by text).

- [ ] **Step 6: Look at it once**

`project_run(session_id=$SID)`. Then one `game_manage(op="game_eval")`: `GameState.player_money = 999999; get_tree().change_scene_to_file("res://Scenes/Koperasi/koprasi.tscn")`. Then `editor_screenshot` of the game at full size. Judge four things: the layers line up with the mockup; items sit in the circle spots with tags below; the bubble box and tail meet without a seam; the coins sit on the ledge clear of Herman's arms and the tray. Tap one pair's second copy with `game_eval` calling `$Stage._on_barang_pressed(<index>)`, then screenshot and confirm only that slot emptied. Stop the game. Revert `Assets/Audio/default_bus_layout.tres` and any rewritten `*.png.import` outside `Assets/Images/Shop/Koperasi/`.

- [ ] **Step 7: Commit**

```
git add Assets/Images/Shop/Koperasi Scenes/Koperasi/koprasi.tscn Scripts/Koperasi/koprasi.gd tests/test_koperasi_shop_layout.gd tests/test_tall_screen_layout.gd tests/test_koperasi_tray.gd tests/test_shop_weekly_stock.gd tests/test_koperasi.gd
git commit -F <scratch>/msg.txt     # feat(koperasi): Pak Herman's counter replaces the shelf pop-up
```

---

### Task 6: Docs, and the full suite

**Files:**
- Modify: `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: DEBT.md**

- Delete the entry **"Koperasi's first shelf button is 27 px wider than authored (2026-09-14)."** The node is gone.
- Add to the placeholder group: *Koperasi chat bubble copy is placeholder (2026-09-17). `Stage/ChatBubble/Body/Text` in `Scenes/Koperasi/koprasi.tscn` says "Selamat datang di Koperasi! Mau beli apa hari ini?" until Pak Herman's real lines are written.*
- Add: *Koperasi leftovers after the 2026-09-17 revamp.* First `grep -rn "Illustration4\|rak 1.jpg\|rak2.jpg" --include=*.tscn --include=*.gd --include=*.tres .` (excluding `.claude/` and `-REFERENCE-/`), and list only the files nothing references. Also list the unused `ShopShelfButton` variation, which `tests/test_lobby_style_buttons.gd:test_the_shelf_button_keeps_its_body_font_label` still pins. Both can go together.

- [ ] **Step 2: CHANGELOG.md**, newest first:

```markdown
## 2026-09-17 — Koperasi revamp: Pak Herman's counter
Koperasi opens on a three-layer counter (background, Pak Herman, glass case)
pinned to the bottom edge, with a flat wall strip above on tall phones. Six
shelf slots on the mockup's circles; the weekly roll draws from a bag of every
item twice, so pairs turn up (~71% of weeks) and each copy sells once.
`rakbarang_1.gd` tracks which slot emptied (`reconcile_taken`), leaving `Cart`
and the basket tray unchanged. Placeholder speech bubble (`ShopChatBubble`);
the coin HUD moved to the counter ledge. The "KEBUTUHAN SEKOLAH" landing and
its pop-up are gone. Spec: `docs/superpowers/specs/2026-09-17-koperasi-shop-revamp-design.md`.
```

- [ ] **Step 3: Full suite**

Budget an editor restart around it. Run: `test_run(session_id=$SID)` with no suite.
Expected: every suite passes, and the total is the baseline (1603 tests on 2026-09-15, plus whatever landed since) plus this branch's new tests, minus the removed ones. A failing theme assertion that follows an unrelated suite gets rerun alone before it is believed (CLAUDE.md). Then check `git status`: revert `default_bus_layout.tres`, and keep `kejartes_theme.tres` only if its content diff is empty or matches Task 4.

- [ ] **Step 4: Commit**

```
git add docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md
git commit -F <scratch>/msg.txt     # docs(koperasi): changelog and debt for the counter revamp
```
