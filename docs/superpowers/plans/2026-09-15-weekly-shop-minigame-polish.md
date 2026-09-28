# Weekly Shop and Minigame Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A weekly Koperasi shelf where each item sells once, LombaMenari's wider window with UPS!/BAGUS!/SEMPURNA!, a white photo frame on the win picture, and MainBola's keeper catch plus target respawn.

**Architecture:** Shop state is three session-scoped fields on `GameState`, read by `rakbarang_1.gd`, whose button visibility is derived from sold + basket on every `Cart.cart_changed`. LombaMenari grades by a pure static `grade_for_distance()`. WinStage places an authored `PhotoFrame` Panel (new `ThemeFactory` variation) around a letterbox that now takes an inset. MainBola sends the keeper to the ball's x off-target and respawns the target via a pure static `pick_respawn()`.

**Tech Stack:** Godot 4.6 GDScript, godot-ai MCP bridge (`test_run`, `scene_open`, `node_*`, `scene_save`, `script_patch`).

Spec: `docs/superpowers/specs/2026-09-15-weekly-shop-minigame-polish-design.md`.

## Global Constraints

- Worktree `.claude/worktrees/weekly-shop-minigame-polish`, branch `feat/weekly-shop-minigame-polish`. Its editor is session `weekly-shop-minigame-polish@c74e` — pass it as `session_id` on **every** godot-ai call (written `…` below); never `session_activate`. The id changes on an editor restart: re-list with `session_manage(op="list")`.
- Git in the worktree: plain single commands, commit with `-F <file>` (message files in the scratchpad), end each message with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Check `git branch --show-current` before each commit.
- Never add `theme_override_*` in a scene; new styling is a `ThemeFactory` variation. (Minigames are out of design-system scope; their existing runtime overrides stay.)
- No visual built at runtime: `PhotoFrame` is an authored node.
- Every script: `##` file header, `##` line directly above every `@export`. New tunables are a named `const` or a documented `@export`, never inline.
- `Balance.gd` is read-only. No new persistence — shop state is session-scoped.
- Tests: `@tool`, no coroutines, `suite_name()` overridden.
- **Scene work first, script work second.** All `scene_save`s happen in Task 1. After Task 5's rebake there is **no** `scene_save`, and `project_run` always passes `autosave=false`.
- After editing a `.gd` with the Edit tool, run a no-op `script_patch` on it (old_text = new_text = a unique header line) before `test_run`, so the editor reloads it. New test files: `filesystem_manage(op="scan")` first.
- UI text is Indonesian.

---

### Task 1: Scene edits — dancer behind the hit zone, authored PhotoFrame

**Files:**
- Create: `tests/test_lomba_menari_timing.gd`
- Modify: `tests/test_win_stage.gd` (append one test)
- Modify: `Scenes/Minigames/SeniBudaya/LombaMenari.tscn` (node order, via editor)
- Modify: `Scenes/EndGame/WinStage.tscn` (new `PhotoFrame` node, via editor)

**Interfaces:**
- Produces: node `WinStage/PhotoFrame` (`Panel`, `theme_type_variation = "PhotoFrame"`, index 1, between `BarFill` and `Stage`); `LombaMenari/CharacterDisplay` at index 1, before `HitZone`.

- [ ] **Step 1: Write the failing scene-shape tests**

Create `tests/test_lomba_menari_timing.gd`:

```gdscript
@tool
extends McpTestSuite

## LombaMenari's timing (2026-09-15): a wider hit window, three grades --
## UPS!, BAGUS!, SEMPURNA! -- and the dancer drawn behind the hit zone, so
## the target is never hidden under her. grade_for_distance() is pure and
## tested directly; the rest is source and scene shape, since the minigame
## cannot be played inside the editor.
##
## Must be @tool; no test here may be a coroutine.

const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
const SCENE_PATH := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"


func suite_name() -> String:
	return "lomba_menari_timing"


## Siblings draw in tree order: an earlier sibling is behind a later one.
func test_the_dancer_draws_behind_the_hit_zone() -> void:
	var scene := load(SCENE_PATH).instantiate() as Node
	track(scene)
	var backdrop: int = scene.get_node("Background").get_index()
	var dancer: int = scene.get_node("CharacterDisplay").get_index()
	var zone: int = scene.get_node("HitZone").get_index()
	var notes: int = scene.get_node("NotesParent").get_index()
	assert_true(dancer < zone, "CharacterDisplay is before HitZone, so the zone draws over her")
	assert_true(backdrop < dancer, "she still stands in front of the backdrop")
	assert_true(zone < notes, "and the notes still fly over the zone")
```

Append to `tests/test_win_stage.gd`, in the `# ─── scene shape` section, after `test_the_stage_has_four_authored_slots_and_four_shadows`:

```gdscript
## The win painting sits on a white print: PhotoFrame draws after the bars
## and before Stage, so the painting covers its middle and only the border
## shows around it.
func test_a_photo_frame_sits_between_the_bars_and_the_painting() -> void:
	var s := _stage()
	var frame = s.get_node_or_null("PhotoFrame")
	assert_true(frame is Panel, "PhotoFrame is an authored Panel")
	if frame == null:
		return
	assert_eq(String(frame.theme_type_variation), "PhotoFrame",
		"styled by the PhotoFrame variation, not an override")
	assert_true(s.get_node("BarFill").get_index() < frame.get_index(), "in front of the bars")
	assert_true(frame.get_index() < s.get_node("Stage").get_index(), "behind the painting")
	assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it never eats a host's clicks")
```

- [ ] **Step 2: Run them to verify they fail**

`filesystem_manage(op="scan", session_id=…)`, then
Run: `test_run(suite="lomba_menari_timing", session_id="weekly-shop-minigame-polish@c74e")`
Expected: FAIL — "CharacterDisplay is before HitZone".
Run: `test_run(suite="win_stage", test_name="photo_frame", session_id=…)`
Expected: FAIL — "PhotoFrame is an authored Panel".

- [ ] **Step 3: Move the dancer**

```
scene_open(path="res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn", session_id=…)
node_manage(op="move", params={"path": "/LombaMenari/CharacterDisplay", "index": 1}, session_id=…)
scene_save(session_id=…)
```

- [ ] **Step 4: Author PhotoFrame**

```
scene_open(path="res://Scenes/EndGame/WinStage.tscn", session_id=…)
node_create(type="Panel", name="PhotoFrame", parent_path="", session_id=…)
node_manage(op="move", params={"path": "/WinStage/PhotoFrame", "index": 1}, session_id=…)
node_set_property(path="/WinStage/PhotoFrame", property="theme_type_variation", value="PhotoFrame", session_id=…)
node_set_property(path="/WinStage/PhotoFrame", property="mouse_filter", value=2, session_id=…)
node_set_property(path="/WinStage/PhotoFrame", property="position", value={"x": 36, "y": 297}, session_id=…)
node_set_property(path="/WinStage/PhotoFrame", property="size", value={"x": 1008, "y": 1325}, session_id=…)
scene_save(session_id=…)
```

(36,297) and 1008×1325 are the 1080×1920 frame the spec computes; `WinStage.dress()` re-places it at runtime.

- [ ] **Step 5: Run the tests to verify they pass, and check the saves**

Run: `test_run(suite="lomba_menari_timing", session_id=…)` → PASS.
Run: `test_run(suite="win_stage", session_id=…)` → all PASS.
Run: `test_run(suite="dance_camera", session_id=…)` and `test_run(suite="dancer_rig", session_id=…)` → PASS.
Then `git diff --stat` must list only the two `.tscn`s and the two test files; `git diff HEAD -- '*.gd'` must show only the test files. Inspect `git diff -- Scenes/`: LombaMenari moves one node block; WinStage gains one `[node name="PhotoFrame" type="Panel" …]` block. Anything else (baked offsets, stripped uids): `git checkout -- <file>` and redo.

- [ ] **Step 6: Commit**

```
git add tests/test_lomba_menari_timing.gd tests/test_win_stage.gd Scenes/Minigames/SeniBudaya/LombaMenari.tscn Scenes/EndGame/WinStage.tscn
git commit -F <scratch>/msg1.txt
```
Message: `feat(scenes): dancer behind LombaMenari's hit zone, authored WinStage PhotoFrame`.

---

### Task 2: GameState — the weekly shelf and what sold

**Files:**
- Modify: `Scripts/GameState.gd` (fields after `minigame_gain_this_week`; functions before `forget_session()`; resets inside it)
- Create: `tests/test_shop_weekly_stock.gd`

**Interfaces:**
- Produces on `GameState`: `const SHOP_SHELF_SIZE: int = 4`; `var shop_week_key: String`; `var shop_stock: Array[String]`; `var shop_sold: Array[String]`; `static func shop_week_key_for(grade: int, week: int) -> String`; `func shop_stock_for_week() -> Array[String]`; `func mark_shop_sold(item_name: String) -> void`; `func is_shop_sold(item_name: String) -> bool`; `func is_shop_sold_out() -> bool`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_shop_weekly_stock.gd`:

```gdscript
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
```

- [ ] **Step 2: Run to verify it fails**

`filesystem_manage(op="scan", session_id=…)`
Run: `test_run(suite="shop_weekly_stock", session_id=…)`
Expected: FAIL — `shop_week_key` / `shop_stock_for_week` not found on GameState.

- [ ] **Step 3: Implement**

In `Scripts/GameState.gd`, after the `var minigame_gain_this_week: Dictionary = {}` line insert:

```gdscript

## How many items the Koperasi shelf shows -- one per Barang* button on
## koprasi.tscn's Rak1.
const SHOP_SHELF_SIZE: int = 4
## The week the Koperasi shelf was rolled for, as shop_week_key_for(); ""
## until the first visit. Session-scoped like everything here.
var shop_week_key: String = ""
## Item names on the Koperasi shelf this week, in slot order.
var shop_stock: Array[String] = []
## Item names bought this week. Each shelf item sells once a week.
var shop_sold: Array[String] = []
```

Directly before the `## Debug: return every session run-state field` comment insert:

```gdscript
## The key a week's Koperasi shelf is stored under. The grade is part of it
## because a new grade restarts minggu_ke at 1.
static func shop_week_key_for(grade: int, week: int) -> String:
	return "%d-%d" % [grade, week]


## This week's Koperasi shelf. The first call in a (grade, week) rolls
## SHOP_SHELF_SIZE items from ItemDatabase and clears shop_sold; every later
## call that week returns the same items in the same order.
func shop_stock_for_week() -> Array[String]:
	var key := shop_week_key_for(current_grade, minggu_ke)
	if key != shop_week_key:
		shop_week_key = key
		shop_sold = []
		shop_stock = []
		for item in ItemDatabase.get_random_items(SHOP_SHELF_SIZE):
			shop_stock.append(item.item_name)
	return shop_stock.duplicate()


## Record that `item_name` was bought this week. Idempotent.
func mark_shop_sold(item_name: String) -> void:
	if not shop_sold.has(item_name):
		shop_sold.append(item_name)


## True when `item_name` was bought this week.
func is_shop_sold(item_name: String) -> bool:
	return shop_sold.has(item_name)


## True once every item on this week's shelf has been bought. False before
## the shelf is first rolled.
func is_shop_sold_out() -> bool:
	if shop_stock.is_empty():
		return false
	for item_name in shop_stock:
		if not shop_sold.has(item_name):
			return false
	return true


```

In `forget_session()`, after `minigame_gain_this_week = {}` insert:

```gdscript
	shop_week_key = ""
	shop_stock = []
	shop_sold = []
```

- [ ] **Step 4: Reload and run to verify it passes**

No-op `script_patch` on `res://Scripts/GameState.gd` (old_text = new_text = `## The source of truth for a run.`).
Run: `test_run(suite="shop_weekly_stock", session_id=…)` → PASS.

- [ ] **Step 5: Commit**

`git add Scripts/GameState.gd tests/test_shop_weekly_stock.gd` → message `feat(shop): GameState keeps one Koperasi shelf per week and what sold`.

---

### Task 3: The shelf — stock from the week, hide sold and basketed items

**Files:**
- Modify: `Scripts/Koperasi/rakbarang_1.gd`
- Modify: `Scripts/Koperasi/koprasi.gd`
- Modify: `Scripts/Inventory/ItemDatabase.gd` (header comment only)
- Modify: `tests/test_shop_weekly_stock.gd` (append)

**Interfaces:**
- Consumes: Task 2's `GameState.shop_stock_for_week()`, `mark_shop_sold()`, `is_shop_sold_out()`, `shop_sold`.
- Produces: `rakbarang_1.gd`: `func setup_shelf()` (replaces `setup_random_items()`), `static func is_on_sale(item_name: String, cart: Dictionary, sold: Array) -> bool`, `func _refresh_shelf_visibility() -> void`. `koprasi.gd`: `const SOLD_OUT_TEXT`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_shop_weekly_stock.gd`, after `const FAKE_ITEM` add:

```gdscript
const RAK_PATH := "res://Scripts/Koperasi/rakbarang_1.gd"
const KOPERASI_PATH := "res://Scripts/Koperasi/koprasi.gd"
## rakbarang_1.gd declares no class_name; reached through a preloaded const.
const RakScript := preload("res://Scripts/Koperasi/rakbarang_1.gd")
```

Append at the end:

```gdscript
# ─── the shelf

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
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run(suite="shop_weekly_stock", session_id=…)`
Expected: FAIL — `is_on_sale` missing, source scans fail.

- [ ] **Step 3: Implement `rakbarang_1.gd`**

Replace header lines 3-10 with:

```gdscript
## The koperasi shelf screen (koprasi.tscn:Rak1): this week's four items on
## the shelf, each with a coin-pill price tag and a little life, and the
## basket tray docked beneath them.
##
## The shelf is rolled once a week (GameState.shop_stock_for_week()) and each
## item sells once that week. A button shows only while its item is on sale:
## not bought this week and not already in the basket (is_on_sale()).
##
## Tapping an item puts one in Cart and flies a copy of its art, in the
## mentor-approved split arc, onto that item's own slot in the tray, and the
## item leaves the shelf. The tray (BasketTray.tscn) redraws itself from Cart;
## this script only wires the shelf, the flight and the hold-to-return gesture
## to it.
```

In `_ready()`: `setup_random_items()` → `setup_shelf()`.

Replace the whole `func setup_random_items():` function with:

```gdscript
## Stock the shelf buttons from this week's shelf and hide whatever is no
## longer on sale. Safe to call again: within a week it restocks the same
## items in the same slots.
func setup_shelf():
	_find_shelf_buttons()
	if shelf_buttons.is_empty():
		return

	item_data_list.clear()
	for item_name in GameState.shop_stock_for_week():
		var stocked: ItemData = ItemDatabase.get_item(item_name)
		if stocked != null:
			item_data_list.append(stocked)

	_shelf_items.clear()
	for i in range(shelf_buttons.size()):
		if i >= item_data_list.size():
			continue
		var btn = shelf_buttons[i]
		var item = item_data_list[i]
		btn.texture_normal = item.icon
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		# Find price tag inside btn
		var tag = _ensure_price_tag(btn)
		if tag:
			tag.set_price(item.price)

		var life = _ensure_shelf_item(btn)
		_shelf_items.append(life)

		# Connect click signal
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])
		btn.pressed.connect(_on_barang_pressed.bind(i))

	_price_tags.clear()
	for btn in shelf_buttons:
		_price_tags.append(btn.get_node_or_null("PriceTag"))
	_refresh_affordability()
	_refresh_shelf_visibility()


## Whether `item_name` belongs on the shelf right now: not bought this week
## (`sold`) and not already in the basket (`cart`, Cart.cart-shaped).
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func is_on_sale(item_name: String, cart: Dictionary, sold: Array) -> bool:
	return not sold.has(item_name) and not cart.has(item_name)


## Show each shelf button only while its item is on sale. Derived from Cart
## and GameState every time, so tap, hold-to-return, Back and Beli agree
## without this script tracking anything. An item returning to a visible
## shelf pops back in.
func _refresh_shelf_visibility() -> void:
	for i in range(shelf_buttons.size()):
		var btn: TextureButton = shelf_buttons[i]
		var on_sale: bool = i < item_data_list.size() \
			and is_on_sale(item_data_list[i].item_name, Cart.cart, GameState.shop_sold)
		var was_hidden := not btn.visible
		btn.visible = on_sale
		if on_sale and was_hidden and btn.is_visible_in_tree():
			Juice.pop_in(btn)
```

Replace `_on_cart_changed()` (and its comment) with:

```gdscript
## Cart.cart_changed: the tray redraws from the cart itself, and the shelf
## re-derives which items are still on sale.
func _on_cart_changed() -> void:
	if is_instance_valid(tray):
		tray.refresh(Cart.cart)
	_refresh_shelf_visibility()
```

In `_on_barang_pressed(index)`, after `var item = item_data_list[index]` insert:

```gdscript
	# One of each per week: a second tap landing before the button hides
	# must not add a second unit.
	if not is_on_sale(item.item_name, Cart.cart, GameState.shop_sold):
		return
```

- [ ] **Step 4: Implement `koprasi.gd`**

Replace header lines 6-11 with:

```gdscript
## The actual shelf/cart/checkout logic lives on rakbarang_1.gd (the Rak1
## panel this screen shows/hides); this file only owns the entry button,
## the money display (kept in sync via GameState.money_changed) and
## routing back to the shop hub. _on_beli_pressed() deducts
## GameState.player_money, calls GameState.add_to_inventory() for each basket
## line and marks it sold for the week (GameState.mark_shop_sold()).
```

After the `@onready var message_label: Label = $MessageLabel` line add:

```gdscript

## Shown on opening the shelf when every item this week has been bought.
const SOLD_OUT_TEXT := "Stok habis! Datang lagi minggu depan."
```

In `_on_rak1_pressed()` replace

```gdscript
	if rak1_panel.has_method("setup_random_items"):
		rak1_panel.setup_random_items()
```

with

```gdscript
	if rak1_panel.has_method("setup_shelf"):
		rak1_panel.setup_shelf()
```

and at the end of `_on_rak1_pressed()` (after the two tween lines) add:

```gdscript

	if GameState.is_shop_sold_out():
		_show_message(SOLD_OUT_TEXT, &"ShopMessageWarning")
```

In `_on_beli_pressed()` replace

```gdscript
	# Transfer items to inventory
	for item_name in Cart.cart:
		var quantity = Cart.cart[item_name]["quantity"]
		GameState.add_to_inventory(item_name, quantity)
```

with

```gdscript
	# Transfer items to inventory. Each is sold for the rest of the week,
	# marked before Cart.clear() below so the shelf keeps it hidden.
	for item_name in Cart.cart:
		var quantity = Cart.cart[item_name]["quantity"]
		GameState.add_to_inventory(item_name, quantity)
		GameState.mark_shop_sold(item_name)
```

- [ ] **Step 5: ItemDatabase header**

In `Scripts/Inventory/ItemDatabase.gd` replace the two lines
`## (get_random_items, used to stock rakbarang_1.gd's shelf buttons each` /
`## time the shop panel opens). To add a new shop item, add an entry to`
with
`## (get_random_items, which GameState.shop_stock_for_week() calls once a` /
`## week to stock the Koperasi shelf). To add a new shop item, add an entry to`

- [ ] **Step 6: Reload and run**

No-op `script_patch` on each of `rakbarang_1.gd`, `koprasi.gd`, `ItemDatabase.gd`.
Run: `test_run(suite="shop_weekly_stock", session_id=…)` → PASS.
Run: `koperasi`, `koperasi_tray`, `koperasi_hud`, `shop_hub`, `script_documentation`, `viewport_editability` → PASS.

- [ ] **Step 7: Commit**

`git add Scripts/Koperasi/rakbarang_1.gd Scripts/Koperasi/koprasi.gd Scripts/Inventory/ItemDatabase.gd tests/test_shop_weekly_stock.gd` → message `feat(koperasi): weekly shelf, each item sold once and gone from the shelf`.

---

### Task 4: LombaMenari — wider window, UPS!/BAGUS!/SEMPURNA!

**Files:**
- Modify: `Scripts/Minigames/SeniBudaya/LombaMenari.gd`
- Modify: `tests/test_lomba_menari_timing.gd` (append)

**Interfaces:**
- Produces: `enum Grade { UPS, BAGUS, SEMPURNA }`; `static func grade_for_distance(distance: float, sempurna_px: float, bagus_px: float) -> Grade`; `const GRADE_TEXT: Dictionary`, `const GRADE_COLOR: Dictionary`; `@export var bagus_window_px: float = 170.0`, `@export var sempurna_window_px: float = 70.0`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_lomba_menari_timing.gd`, after `const SCENE_PATH` add:

```gdscript
## LombaMenari.gd declares no class_name; reached through a preloaded const,
## as tests/test_minigame_star_rubric.gd does.
const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")
```

Append at the end:

```gdscript
# ─── grading

func test_a_hit_grades_by_distance_from_the_centre() -> void:
	assert_eq(MenariScript.grade_for_distance(0.0, 70.0, 170.0), MenariScript.Grade.SEMPURNA,
		"dead centre is SEMPURNA")
	assert_eq(MenariScript.grade_for_distance(69.9, 70.0, 170.0), MenariScript.Grade.SEMPURNA,
		"just inside the tight window")
	assert_eq(MenariScript.grade_for_distance(70.0, 70.0, 170.0), MenariScript.Grade.BAGUS,
		"its edge is only BAGUS")
	assert_eq(MenariScript.grade_for_distance(169.9, 70.0, 170.0), MenariScript.Grade.BAGUS,
		"just inside the wide window")
	assert_eq(MenariScript.grade_for_distance(170.0, 70.0, 170.0), MenariScript.Grade.UPS,
		"its edge is UPS")


func test_the_window_is_wider_than_before() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("var bagus_window_px: float = 170.0"), "BAGUS reaches 170 px, up from 120")
	assert_true(src.contains("var sempurna_window_px: float = 70.0"), "SEMPURNA reaches 70 px, up from 45")
	assert_false(src.contains("min_dist < 120.0"), "the old hardcoded window is gone")
	assert_false(src.contains("min_dist < 45.0"), "both of them")


func test_both_windows_are_documented_exports() -> void:
	var lines := FileAccess.get_file_as_string(SCRIPT_PATH).split("\n")
	for knob in ["bagus_window_px", "sempurna_window_px"]:
		var found := -1
		for i in range(lines.size()):
			if lines[i].strip_edges().begins_with("@export") and lines[i].contains("var " + knob):
				found = i
				break
		assert_gt(found, 0, knob + " is an @export")
		assert_true(lines[found - 1].strip_edges().begins_with("##"), knob + " has a ## doc line")


func test_a_note_stays_swipeable_for_the_whole_window() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("vec_from_target.dot(move_dir) > bagus_window_px"),
		"a note is missed only once it leaves the BAGUS window")
	assert_false(src.contains("dot(move_dir) > 80.0"),
		"not 80 px past centre, which cut late hits short")


func test_the_three_grades_are_the_only_feedback_words() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for word in ["UPS!", "BAGUS!", "SEMPURNA!"]:
		assert_true(src.contains("\"%s\"" % word), word + " is shown")
	for old in ["PERFECT!", "GOOD!", "MISS!", "WRONG SWIPE!", "TOO EARLY!"]:
		assert_false(src.contains("\"%s\"" % old), old + " is retired")


func test_every_failure_shows_ups() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("grade_for_distance(min_dist, sempurna_window_px, bagus_window_px)"),
		"a swipe is graded by the two windows")
	assert_true(src.contains("GRADE_TEXT[Grade.UPS]"), "a note that slips past says UPS!")
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run(suite="lomba_menari_timing", session_id=…)` → FAIL (no `grade_for_distance`).

- [ ] **Step 3: Implement**

Directly above `# ─── Visual - Hit Zone ───…` insert:

```gdscript
# ─── Timing ─────────────────────────────────────────────────────────────────
@export_group("Timing")
## How close to the hit zone's centre, in pixels, a matching swipe must land
## to count at all -- a BAGUS hit. A note also stays swipeable until it is
## this far past centre, so a late hit gets the same room as an early one.
## Widened from 120 on 2026-09-15.
@export_range(40.0, 400.0, 1.0) var bagus_window_px: float = 170.0
## How close to centre, in pixels, a hit must land to be SEMPURNA. Keep it
## below bagus_window_px. Widened from 45 on 2026-09-15.
@export_range(10.0, 200.0, 1.0) var sempurna_window_px: float = 70.0

```

After the `const POINTS_GOOD: int = 50` line insert:

```gdscript

## How well a swipe landed. UPS is every failure: a note that slipped past,
## or a swipe with no matching note inside bagus_window_px.
enum Grade { UPS, BAGUS, SEMPURNA }

## The word shown over the hit zone for each Grade.
const GRADE_TEXT: Dictionary = {
	Grade.UPS: "UPS!",
	Grade.BAGUS: "BAGUS!",
	Grade.SEMPURNA: "SEMPURNA!",
}
## The colour of that word: red, green, gold.
const GRADE_COLOR: Dictionary = {
	Grade.UPS: Color(1.0, 0.25, 0.25),
	Grade.BAGUS: Color(0.2, 0.9, 0.4),
	Grade.SEMPURNA: Color(1.0, 0.84, 0.0),
}
```

In `_process()`, replace `if vec_from_target.dot(move_dir) > 80.0:` with `if vec_from_target.dot(move_dir) > bagus_window_px:`, and `_show_hit_feedback("MISS!", Color.RED)` with `_show_hit_feedback(GRADE_TEXT[Grade.UPS], GRADE_COLOR[Grade.UPS])`.

Replace the whole `func _evaluate_swipe(swipe_type: int) -> void:` function with:

```gdscript
func _evaluate_swipe(swipe_type: int) -> void:
	_show_swipe_effect(swipe_type)

	var hz_center = hit_zone.get_global_rect().get_center()

	# The matching note closest to the hit zone's centre, if any.
	var best_note: Control = null
	var min_dist: float = INF
	for note in active_notes:
		if note.get_meta("note_type") == swipe_type:
			var note_center = note.global_position + note.size / 2.0
			var dist = note_center.distance_to(hz_center)
			if dist < min_dist:
				min_dist = dist
				best_note = note

	var grade: Grade = Grade.UPS
	if best_note != null:
		grade = grade_for_distance(min_dist, sempurna_window_px, bagus_window_px)

	match grade:
		Grade.SEMPURNA:
			score += POINTS_PERFECT
			perfect_hits += 1
			_pulse_hit_zone(Color(1.0, 0.9, 0.2)) # Glowing gold/yellow pulse
		Grade.BAGUS:
			score += POINTS_GOOD
			good_hits += 1
			_pulse_hit_zone(Color(0.3, 1.0, 0.5)) # Glowing green pulse
		Grade.UPS:
			_pulse_hit_zone(Color(0.9, 0.2, 0.2)) # Failed red pulse
			_play_dancer_fail_motion()
	_show_hit_feedback(GRADE_TEXT[grade], GRADE_COLOR[grade])

	if grade != Grade.UPS:
		current_combo += 1
		best_combo = maxi(best_combo, current_combo)
		_play_dancer_motion(swipe_type)
		active_notes.erase(best_note)
		_animate_swiped_note(best_note, swipe_type)

	if score_hud:
		score_hud.set_score(score)
		score_hud.set_combo(current_combo)

	if score >= target_score:
		win_game()


## The grade a matching swipe earns `distance` pixels from the hit zone's
## centre: SEMPURNA inside `sempurna_px`, BAGUS inside `bagus_px`, UPS beyond.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func grade_for_distance(distance: float, sempurna_px: float, bagus_px: float) -> Grade:
	if distance < sempurna_px:
		return Grade.SEMPURNA
	if distance < bagus_px:
		return Grade.BAGUS
	return Grade.UPS
```

(A UPS swipe keeps the combo, as TOO EARLY did; only a note slipping past resets it.)

- [ ] **Step 4: Reload and run**

No-op `script_patch` on `LombaMenari.gd` (old_text = new_text = `## SeniBudaya minigame: a 4-direction rhythm game. Notes spawn per`).
Run: `lomba_menari_timing`, `minigame_star_rubric`, `dance_camera`, `script_documentation`, `viewport_editability` → PASS.

- [ ] **Step 5: Commit**

`git add Scripts/Minigames/SeniBudaya/LombaMenari.gd tests/test_lomba_menari_timing.gd` → message `feat(lomba-menari): wider hit window and UPS!/BAGUS!/SEMPURNA! grades`.

---

### Task 5: WinStage photo frame — layout, PhotoFrame variation, rebake

**Files:**
- Modify: `Scripts/EndGame/WinStage.gd`
- Modify: `Scripts/Design/ThemeFactory.gd` (`_build_panels`, after Scrim)
- Modify: `tests/test_win_stage.gd`, `tests/test_theme_factory.gd`
- Rebaked: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Consumes: Task 1's `PhotoFrame` node.
- Produces: `static func letterbox(area: Vector2, inset: float = 0.0) -> Dictionary`; `@export var photo_border: float = 28.0`; `@export var photo_gap: float = 36.0`; theme type `PhotoFrame` (Panel).

- [ ] **Step 1: Write the failing tests**

In `tests/test_win_stage.gd`, in `test_dressing_a_win_poses_the_roster_on_the_letterboxed_painting` replace
`var fit: Dictionary = WinStage.letterbox(vp)` with
`var fit: Dictionary = WinStage.letterbox(vp, s.photo_border + s.photo_gap)`.

Append after `test_the_letterbox_fits_the_whole_painting_and_centres_it`:

```gdscript
## The frame needs room: an inset shrinks the painting by that much on every
## side and keeps it centred. 64 = the default 28px border + 36px gap.
func test_the_letterbox_can_leave_room_for_a_frame() -> void:
	var framed: Dictionary = WinStage.letterbox(Vector2(1080, 1920), 64.0)
	var s: float = 952.0 / 1536.0
	assert_true(is_equal_approx(framed["scale"], s), "the painting shrinks to leave 64px a side")
	var expect := Vector2(64.0, (1920.0 - 2048.0 * s) * 0.5)
	assert_true((framed["position"] as Vector2).is_equal_approx(expect), "and stays centred")


func test_the_frame_knobs_are_documented_exports() -> void:
	var lines := FileAccess.get_file_as_string(_SCRIPT).split("\n")
	for knob in ["photo_border", "photo_gap"]:
		var found := -1
		for i in range(lines.size()):
			if lines[i].begins_with("@export var " + knob):
				found = i
				break
		assert_gt(found, 0, knob + " is an @export")
		assert_true(lines[found - 1].begins_with("##"), knob + " has a ## doc line")
```

Append in the `# ─── dressing` section:

```gdscript
func test_a_win_frames_the_painting_in_a_white_print() -> void:
	var s := _live_stage()
	s.dress(false, _FOUR)
	var stage: Control = s.get_node("Stage")
	var frame: Control = s.get_node("PhotoFrame")
	var painting := Rect2(stage.position, stage.size * stage.scale)
	var frame_rect := Rect2(frame.position, frame.size)
	var shown := frame.visible
	var border: float = s.photo_border
	Engine.get_main_loop().root.remove_child(s)
	assert_true(shown, "the print shows on a win")
	assert_true(frame_rect.is_equal_approx(painting.grow(border)),
		"exactly photo_border wider than the painting on every side")
	assert_gt(frame_rect.position.x, 0.0, "with a gap to the screen's edge")


func test_a_loss_hides_the_frame() -> void:
	var s := _live_stage()
	s.dress(false, _FOUR)
	s.dress(true, _FOUR)
	var shown: bool = s.get_node("PhotoFrame").visible
	Engine.get_main_loop().root.remove_child(s)
	assert_false(shown, "the lose CG covers the screen with no print under it")
```

In `tests/test_theme_factory.gd`, add `"PhotoFrame",` to the `expected` list after `"Card", "SunkenPanel", "Scrim",`, and append:

```gdscript
func test_photo_frame_is_an_opaque_white_print() -> void:
	var sb := _theme.get_stylebox("panel", "PhotoFrame") as StyleBoxFlat
	assert_true(sb != null, "PhotoFrame has a flat panel stylebox")
	if sb == null:
		return
	assert_eq(sb.bg_color.a, 1.0, "opaque, so the bars never show through the border")
	assert_gt(sb.bg_color.get_luminance(), 0.9, "and white, like photo paper")
	assert_gt(sb.shadow_size, 0, "lifted off the ground by a shadow")
```

- [ ] **Step 2: Run to verify they fail**

Run: `win_stage` → FAIL (`photo_border` unknown, letterbox takes one arg). `theme_factory` → FAIL (no PhotoFrame).

- [ ] **Step 3: Implement WinStage.gd**

After `@export var shadow_flatness: float = 0.28` insert:

```gdscript

@export_group("Photo frame")
## Width, in viewport pixels, of the white print border around the win
## painting. 0 hides the frame and lets the painting fill the width again.
@export var photo_border: float = 28.0
## Gap, in viewport pixels, between the frame's outer edge and the nearest
## screen edge, so the print reads as lying on the dark ground.
@export var photo_gap: float = 36.0
```

After `@onready var bar_fill: ColorRect = $BarFill` add
`@onready var photo_frame: Panel = $PhotoFrame`.

Replace `letterbox()` and its doc comment with:

```gdscript
## Where the letterboxed painting lands in a viewport of `area`, leaving
## `inset` pixels clear on every side: scaled by the smaller ratio so the
## whole 3:4 image survives on a 9:16 screen, and centred. With no inset, at
## 1080x1920 that is 1080x1440 with 240px bars top and bottom.
## Returns {"scale": float, "position": Vector2}.
static func letterbox(area: Vector2, inset: float = 0.0) -> Dictionary:
	var room := area - Vector2(inset, inset) * 2.0
	var s := minf(room.x / ART_SIZE.x, room.y / ART_SIZE.y)
	return {"scale": s, "position": (area - ART_SIZE * s) * 0.5}
```

In `dress()`'s lose branch, after `_hide_lineup()` add `photo_frame.hide()`. Its doc becomes: "Dress the stage for a verdict. Win letterboxes the painting inside its white PhotoFrame and poses `names` on it; lose covers the viewport with the lose CG and hides the frame and every slot. Sets BarFill, PhotoFrame, Stage's transform, Backdrop's texture and every Student/Shadow slot -- nothing is constructed."

Replace `_fit_stage()` and its doc with:

```gdscript
## Letterbox the painting into `vp`, leaving room for the frame (see
## letterbox()), and put the frame around it.
func _fit_stage(vp: Vector2) -> void:
	var fit := letterbox(vp, photo_border + photo_gap)
	var s: float = fit["scale"]
	stage.size = ART_SIZE
	stage.scale = Vector2(s, s)
	stage.position = fit["position"]
	_frame_photo(Rect2(stage.position, ART_SIZE * s))


## Place PhotoFrame around the painting's on-screen rect, photo_border wider
## on every side, and show it. The frame is an authored node; this only
## sizes and positions it.
func _frame_photo(painting: Rect2) -> void:
	var grown := painting.grow(photo_border)
	photo_frame.position = grown.position
	photo_frame.size = grown.size
	photo_frame.visible = photo_border > 0.0
```

In the file header, change "the letterbox bars, win_background.png, four student slots and their ground shadows" to "the letterbox bars, a white photo-print frame (PhotoFrame), win_background.png, four student slots and their ground shadows".

- [ ] **Step 4: Implement the variation**

In `ThemeFactory._build_panels`, after `theme.set_stylebox("panel", "Scrim", scrim)` insert:

```gdscript

	# The win painting's photo print (WinStage/PhotoFrame): an opaque warm
	# white border with the Card's drop shadow, so the end-of-grade picture
	# reads as a photograph lying on the dark ground.
	theme.add_type("PhotoFrame")
	theme.set_type_variation("PhotoFrame", "Panel")
	var photo := StyleBoxFlat.new()
	photo.bg_color = tokens.surface_card
	photo.set_corner_radius_all(tokens.radius_sm)
	photo.shadow_color = tokens.shadow_color
	photo.shadow_size = tokens.shadow_size
	photo.shadow_offset = tokens.shadow_offset
	theme.set_stylebox("panel", "PhotoFrame", photo)
```

- [ ] **Step 5: Reload, rebake alone, run**

No-op `script_patch` on `WinStage.gd` and `ThemeFactory.gd`.
Run: `test_run(suite="theme_rebake", session_id=…)` **on its own** (rebakes `kejartes_theme.tres`).
Run: `theme_factory`, `win_stage`, `end_cutscene`, `run_result`, `script_documentation` → PASS.
`git diff --stat -- Assets/Theme/kejartes_theme.tres`: it should add one PhotoFrame stylebox and its type lines. If ids churned across unrelated styleboxes, quit this editor, `git checkout -- Assets/Theme/kejartes_theme.tres`, relaunch, rebake alone again.
From here on: no `scene_save`.

- [ ] **Step 6: Commit**

`git add Scripts/EndGame/WinStage.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_win_stage.gd tests/test_theme_factory.gd` → message `feat(win-stage): white photo frame around the win painting`.

---

### Task 6: MainBola — keeper catches every off-target shot, target respawns

**Files:**
- Modify: `Scripts/Minigames/Olahraga/MainBola.gd`
- Create: `tests/test_main_bola_shots.gd`

**Interfaces:**
- Produces: `static func pick_respawn(prev: Vector2, min_pos: Vector2, max_pos: Vector2, min_gap: float, rng: RandomNumberGenerator) -> Vector2`; `func keeper_catch_point(keeper_x: float) -> Vector2`; `func _respawn_target() -> void`; consts `BALL_FLIGHT_SECONDS`, `RESPAWN_TRIES`, `TARGET_POP_SECONDS`; exports `target_band_top_frac`, `target_band_bottom_frac`, `keeper_catch_height_frac`; vars `target_y_pos`, `target_pop`, `goalie_h`, `_rng`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_main_bola_shots.gd`:

```gdscript
@tool
extends McpTestSuite

## MainBola's shots (2026-09-15): an off-target shot always ends in the
## keeper's hands, and the target box jumps to a new spot after every goal.
## pick_respawn() is pure and tested with a seeded generator; the shot itself
## is a coroutine that cannot run in the editor, so its wiring is pinned by
## source scans, as test_main_bola_layout.gd does.
##
## Must be @tool; no test here may be a coroutine.

const SCRIPT_PATH := "res://Scripts/Minigames/Olahraga/MainBola.gd"
## MainBola.gd declares no class_name; reached through a preloaded const.
const MainBolaScript := preload("res://Scripts/Minigames/Olahraga/MainBola.gd")

## The target band at 1080x1920 with the scene's defaults: x inside the posts
## less half a box, y 20-60% down the goal mouth. GAP is one box width.
const MIN_POS := Vector2(162.0, 645.0)
const MAX_POS := Vector2(918.0, 860.0)
const GAP := 194.0


func suite_name() -> String:
	return "main_bola_shots"


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


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


# ─── respawn

func test_a_respawn_lands_in_the_band_away_from_the_last_spot() -> void:
	var prev := Vector2(540.0, 700.0)
	for seed_value in range(200):
		var next: Vector2 = MainBolaScript.pick_respawn(prev, MIN_POS, MAX_POS, GAP, _rng(seed_value))
		assert_true(next.x >= MIN_POS.x and next.x <= MAX_POS.x, "x stays inside the goal")
		assert_true(next.y >= MIN_POS.y and next.y <= MAX_POS.y, "y stays inside the band")
		assert_true(next.distance_to(prev) >= GAP, "at least a box-width from where it was")
		prev = next


func test_a_band_too_small_for_the_gap_still_moves_as_far_as_it_can() -> void:
	var prev := Vector2(100.0, 100.0)
	var next: Vector2 = MainBolaScript.pick_respawn(
		prev, Vector2(90, 90), Vector2(110, 110), 500.0, _rng(7))
	assert_true(next.x >= 90.0 and next.x <= 110.0 and next.y >= 90.0 and next.y <= 110.0,
		"still inside the band")
	assert_ne(next, prev, "it still moves")


func test_a_seed_repeats_its_respawn() -> void:
	var a: Vector2 = MainBolaScript.pick_respawn(Vector2(540, 700), MIN_POS, MAX_POS, GAP, _rng(42))
	var b: Vector2 = MainBolaScript.pick_respawn(Vector2(540, 700), MIN_POS, MAX_POS, GAP, _rng(42))
	assert_eq(a, b, "the only randomness is the generator it is handed")


func test_every_goal_moves_the_target() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(_body(src, "func _on_goal_scored()").contains("_respawn_target()"),
		"a goal respawns the target")
	assert_true(_body(src, "func _respawn_target()").contains("pick_respawn("),
		"through the tested picker")


func test_an_aimed_shot_flies_to_the_targets_height() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("target_y_pos if aimed_at_target"),
		"a respawned target at a new height is still where the ball goes")


# ─── the keeper

func test_an_off_target_shot_sends_the_keeper_to_the_ball() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("goalie_tx = clampf(target_x, goal_left_x + 5.0, goal_right_x - 5.0)"),
		"the keeper dives to where the ball is going")
	assert_true(src.contains("ball_target = keeper_catch_point(goalie_tx)"),
		"and the ball ends in his hands")


func test_the_keeper_is_never_slower_than_the_ball() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("clampf(0.35 / goalie_speed_mult, 0.18, BALL_FLIGHT_SECONDS)"),
		"the dive is capped at the ball's flight time")
	assert_false(src.contains(", 0.40)"), "the ball's flight time is one named const")


func test_the_new_knobs_are_documented_exports() -> void:
	var lines := FileAccess.get_file_as_string(SCRIPT_PATH).split("\n")
	for knob in ["target_band_top_frac", "target_band_bottom_frac", "keeper_catch_height_frac"]:
		var found := -1
		for i in range(lines.size()):
			if lines[i].strip_edges().begins_with("@export") and lines[i].contains("var " + knob):
				found = i
				break
		assert_gt(found, 0, knob + " is an @export")
		assert_true(lines[found - 1].strip_edges().begins_with("##"), knob + " has a ## doc line")
```

- [ ] **Step 2: Run to verify it fails**

`filesystem_manage(op="scan", session_id=…)`
Run: `test_run(suite="main_bola_shots", session_id=…)` → FAIL (`pick_respawn` missing).

- [ ] **Step 3: Implement**

Before `# ─── Visual - Typography ───…` insert:

```gdscript
# ─── Target & keeper ────────────────────────────────────────────────────────
@export_group("Target & Keeper")
## Highest a respawned target box's centre may sit, as a fraction of the goal
## mouth's height measured down from the crossbar.
@export_range(0.0, 1.0, 0.01) var target_band_top_frac: float = 0.2
## Lowest a respawned target box's centre may sit, same measure. Keep the box
## inside the mouth: its half-height must fit below this line.
@export_range(0.0, 1.0, 0.01) var target_band_bottom_frac: float = 0.6
## Where an off-target shot meets the keeper, as a fraction of his sprite
## height up from his feet -- his chest, so the ball lands in his hands.
@export_range(0.0, 1.0, 0.01) var keeper_catch_height_frac: float = 0.55

```

After `const GOALIE_SPEED_INCREASE: float = 0.15  # +15% per goal` insert:

```gdscript
## Seconds the ball takes to reach the goal. The keeper's dive is capped at
## this, so he always gets there with the ball.
const BALL_FLIGHT_SECONDS: float = 0.40
## Draws pick_respawn() makes for a spot far enough from the last one.
const RESPAWN_TRIES: int = 24
## Seconds the respawned target box takes to pop back in.
const TARGET_POP_SECONDS: float = 0.25
```

After `var pulse_time: float   = 0.0` insert:

```gdscript
## The target box's centre height. 35% down the mouth until the first goal;
## each goal respawns it inside the target band.
var target_y_pos: float = 0.0
## Pop-in multiplier on the target box's scale, tweened 0 -> 1 on respawn.
var target_pop: float = 1.0
## Draws respawn spots. Its own generator, so pick_respawn() can be seeded.
var _rng := RandomNumberGenerator.new()
```

After `var goalie_half_w: float` add:

```gdscript
## The keeper's sprite height, for keeper_catch_point().
var goalie_h: float
```

In `_ready()`, after `super._ready()` add `_rng.randomize()`.

In `_setup_layout()`, after `target_x_pos = sw * 0.5` add `target_y_pos = goal_top + goal_height * 0.35`; after `goalie_half_w = g_width * 0.5` add `goalie_h = g_height`.

In `_process()` replace

```gdscript
		target_box_node.scale = Vector2(scale_pulse, scale_pulse)
		target_box_node.pivot_offset = target_box_node.size * 0.5
		target_box_node.position = Vector2(target_x_pos - target_w * 0.5, goal_top_y + (goal_bot_y - goal_top_y) * 0.35 - target_h * 0.5)
```

with

```gdscript
		target_box_node.scale = Vector2(scale_pulse, scale_pulse) * target_pop
		target_box_node.pivot_offset = target_box_node.size * 0.5
		target_box_node.position = Vector2(target_x_pos - target_w * 0.5, target_y_pos - target_h * 0.5)
```

In `_shoot_ball()` replace everything from `var target_y: float      = goal_top_y + (goal_bot_y - goal_top_y) * 0.45` through `var dive_time: float = clampf(0.35 / goalie_speed_mult, 0.18, 0.40)` with:

```gdscript
	var target_y: float = target_y_pos if aimed_at_target else goal_top_y + (goal_bot_y - goal_top_y) * 0.45
	var ball_target: Vector2 = Vector2(target_x, target_y)

	# ── Goalie dive logic ────────────────────────────────────
	var dive_dir: int
	var goalie_tx: float
	if aimed_at_target:
		# Goalkeeper dives AWAY from the target box so player gets rewarded!
		if target_x >= goalie_base_pos.x:
			dive_dir = -1  # target is on right -> keeper dives left
		else:
			dive_dir = 1   # target is on left -> keeper dives right
		var dive_dist: float = clampf(sw * 0.28 * goalie_speed_mult, sw * 0.18, sw * 0.45)
		goalie_tx = clampf(goalie_base_pos.x + float(dive_dir) * dive_dist, goal_left_x + 5.0, goal_right_x - 5.0)
	else:
		# Off target: the keeper goes exactly where the ball is going and the
		# ball ends in his hands -- every off-target shot is a save.
		goalie_tx = clampf(target_x, goal_left_x + 5.0, goal_right_x - 5.0)
		ball_target = keeper_catch_point(goalie_tx)
		if absf(goalie_tx - goalie_base_pos.x) < goalie_half_w * 0.8:
			dive_dir = 0   # straight at him: he stands and takes it
		elif goalie_tx > goalie_base_pos.x:
			dive_dir = 1
		else:
			dive_dir = -1

	var dive_time: float = clampf(0.35 / goalie_speed_mult, 0.18, BALL_FLIGHT_SECONDS)
```

In the two ball tweens replace `0.40)` with `BALL_FLIGHT_SECONDS)`.

After `_shoot_ball()` add:

```gdscript
## Where an off-target shot meets the keeper standing at `keeper_x`: his
## chest, keeper_catch_height_frac of his height up from his feet.
func keeper_catch_point(keeper_x: float) -> Vector2:
	return Vector2(keeper_x, goalie_base_pos.y - goalie_h * keeper_catch_height_frac)
```

In `_on_goal_scored()` replace

```gdscript
	await get_tree().create_timer(0.35).timeout

	_reset_shot()
```

with

```gdscript
	await get_tree().create_timer(0.35).timeout

	_respawn_target()
	_reset_shot()
```

After `_on_goal_scored()` add:

```gdscript
## Move the target box to a new spot in the target band, at least one box
## width from where it was, sliding a random way, and pop it back in.
##
## Affects: target_x_pos, target_y_pos, target_dir, target_pop.
func _respawn_target() -> void:
	var mouth_h: float = goal_bot_y - goal_top_y
	var margin: float = target_w * 0.5 + 10.0
	var min_pos := Vector2(goal_left_x + margin, goal_top_y + mouth_h * target_band_top_frac)
	var max_pos := Vector2(goal_right_x - margin, goal_top_y + mouth_h * target_band_bottom_frac)
	var next := pick_respawn(Vector2(target_x_pos, target_y_pos), min_pos, max_pos, target_w, _rng)
	target_x_pos = next.x
	target_y_pos = next.y
	target_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	target_pop = 0.0
	create_tween().tween_property(self, "target_pop", 1.0, TARGET_POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A new spot for the target box: uniform inside min_pos..max_pos and at
## least `min_gap` from `prev`. Tries RESPAWN_TRIES draws; when none is far
## enough (a band too small for the gap) it keeps the farthest draw, so the
## box always moves as far as the room allows.
##
## Affects: `rng`'s state only. Static so a test can call it with no instance.
static func pick_respawn(prev: Vector2, min_pos: Vector2, max_pos: Vector2,
		min_gap: float, rng: RandomNumberGenerator) -> Vector2:
	var best := prev
	var best_dist := -1.0
	for i in range(RESPAWN_TRIES):
		var p := Vector2(rng.randf_range(min_pos.x, max_pos.x), rng.randf_range(min_pos.y, max_pos.y))
		var d := p.distance_to(prev)
		if d >= min_gap:
			return p
		if d > best_dist:
			best_dist = d
			best = p
	return best
```

- [ ] **Step 4: Reload and run**

No-op `script_patch` on `MainBola.gd` (old_text = new_text = `## The goalkeeper standing ready, before the shot resolves.`).
Run: `main_bola_shots`, `main_bola_layout`, `main_bola_targets`, `minigame_star_rubric`, `script_documentation`, `viewport_editability` → PASS.

- [ ] **Step 5: Commit**

`git add Scripts/Minigames/Olahraga/MainBola.gd tests/test_main_bola_shots.gd` → message `feat(main-bola): keeper catches every off-target shot, target respawns after a goal`.

---

### Task 7: Changelog, full suite, visual check, cleanup

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (new entry at the top)

- [ ] **Step 1: Changelog**

Insert above `## 2026-09-15 — Tall phones, Phase 1: …`:

```markdown
## 2026-09-15 — Weekly shop and minigame polish

Plan `docs/superpowers/plans/2026-09-15-weekly-shop-minigame-polish.md`, spec
`docs/superpowers/specs/2026-09-15-weekly-shop-minigame-polish-design.md`.

- **Koperasi** rolls its four items once per week (`GameState.shop_stock_for_week()`,
  keyed by grade and `minggu_ke`) instead of on every visit. Each item sells
  once a week: it leaves the shelf when it goes into the basket, comes back if
  it is held out or the player backs out, and stays gone after Beli
  (`GameState.shop_sold`). Session-scoped, like the rest of GameState.
- **LombaMenari**'s hit window is 170 px (BAGUS) and 70 px (SEMPURNA), up from
  120/45, and a note is only missed once it leaves the whole window -- it used
  to be dropped 80 px past centre, so late hits were impossible. Feedback is
  UPS!/BAGUS!/SEMPURNA!; the dancer draws behind the hit zone.
- **Win screen**: WinStage puts the painting on a white `PhotoFrame` print
  (new ThemeFactory variation); RunResult opens on the same framed picture.
- **MainBola**: an off-target shot ends in the keeper's hands, and the target
  box respawns somewhere new (x and height) after every goal.

```

Commit: `docs(changelog): weekly shop and minigame polish`.

- [ ] **Step 2: Full suite**

`scene_open(path="res://Scenes/MainMenu/main_menu.tscn", session_id=…)` (no save).
Run: `test_run(session_id="weekly-shop-minigame-polish@c74e")` — every suite. Record `<passed>/<total>`. The bridge may drop after the reply; the results still count.
Fix genuine failures this branch caused (a lone theme assertion may be suite ordering: re-run that suite alone first), commit, re-run.

- [ ] **Step 3: Restart the editor and look at the frame once**

Stop this worktree editor's PID after checking its CommandLine contains the worktree path; relaunch detached (CIM `Win32_Process Create`); re-list sessions for the new id.
`project_run(mode="main", autosave=false, session_id=…)`, then `editor_manage(op="game_eval")` with:

```gdscript
var s = load("res://Scenes/EndGame/WinStage.tscn").instantiate()
get_tree().root.add_child(s)
s.dress(false, ["Doni", "Andi", "Citra", "Shinta"])
return true
```

`editor_screenshot(source="game", max_resolution=0, session_id=…)` — judge the frame at full size: an even white border on all sides, a visible shadow, the painting inside it. Then `project_manage(op="stop")`.

- [ ] **Step 4: Clean the tree**

`editor_manage(op="quit", session_id=…)` (or stop its checked PID). Then `git status --porcelain`: `git checkout -- Assets/Audio/default_bus_layout.tres` and any `*.png.import` the boot rewrote, only once that editor has exited. Nothing else may be modified.
