# Koperasi, Inventory, Wirausaha & Report Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the three dead lobby buttons (`$Koperasi`, `$Inventory`, `$ReportStudent`) to working screens by importing the teammate's shop/inventory scenes, restyling them onto this project's theme, making items affect a chosen student, and adding a "Wirausaha" schedule activity that funds the economy.

**Architecture:** The teammate's forked autoloads are discarded and their state merged into this project's `GameState`; only `Cart` and `ItemDatabase` are imported as new autoloads. The two scenes are ported file-for-file with their art intact, then restyled onto `kejartes_theme.tres` / `DesignTokens`. Wirausaha is added as a fifth schedule category at every enumeration site, accruing per-day and paying out at week end. The report card is derived from `student_card` by deletion, with the shared card-rendering logic extracted into `StudentCardView.gd`.

**Tech Stack:** Godot 4.6 (Mobile renderer), GDScript, `McpTestSuite` tests run via the `godot-ai` MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-08-27-koperasi-inventory-integration-design.md`

## Global Constraints

- **Godot 4.6**, Mobile renderer, portrait 1080×1920. `project.godot` `config/features` is `PackedStringArray("4.6", "Mobile")`.
- **Asset policy — never re-author these files.** Item icons (`Asset/ItemRak/*.png`), `bg_inventory.png`, `panel_header.png`, `panel_sidebar.png`, `panel_detail.png`, `panel_popup.png`, `rak 1.jpg`, `rak2.jpg`, `Koin.png`, `return.png` are finished art. Copy them byte-identical. Only `btn_normal.png`, `btn_pressed.png`, `slot_normal.png`, `slot_selected.png` are placeholder chrome to be replaced by the theme.
- **No new autoloads beyond `Cart` and `ItemDatabase`.** Do not import the teammate's `GameState`, `SceneManager`, `GameSetting`, `transition`, or `SfxManager`.
- **No `Color(...)` literals in ported UI code.** Colors come from `DesignTokens.load_default()`. `tests/test_lobby.gd` already enforces this pattern for the lobby; the new suites do the same.
- **No persistence.** Money and inventory are session-scoped. Do not add `user://` saves.
- **Test suites must be `@tool` and must extend `McpTestSuite`.** No test method may be a coroutine (the runner calls `suite.call(name)` without awaiting).
- **Source project path:** `C:\Users\Legion\Downloads\koprasi&inventory` (registered as an additional working directory).
- **Commit after every task.** Conventional-commit prefixes, matching existing history (`feat(audio):`, `fix(audio):`, `docs(audio):`).

---

## File Structure

**New files:**

| Path | Responsibility |
|---|---|
| `Scripts/Inventory/ItemData.gd` | `class_name ItemData` resource — name, price, icon, description, category, display size, mood/energy boost. |
| `Scripts/Inventory/ItemDatabase.gd` | Autoload. Builds `ItemData` instances from a const table; `get_item(name)`. |
| `Scripts/Inventory/Cart.gd` | Autoload. Shop basket: add/remove/total/count/clear. |
| `Scripts/Inventory/inventory.gd` | Inventory screen controller. |
| `Scripts/Koperasi/koprasi.gd` | Shop screen controller. |
| `Scripts/StudentCard/StudentCardView.gd` | Shared card rendering: populate one `KertasMurid` from a student dictionary, build stat bars, quirk/persona popups. |
| `Scripts/ReportCard/report_card.gd` | Read-only card viewer over `approved_students`. |
| `Scenes/Inventory/inventory.tscn` | Ported inventory scene. |
| `Scenes/Koperasi/koprasi.tscn` | Ported shop scene. |
| `Scenes/ReportCard/report_card.tscn` | Report card scene. |
| `Assets/Images/Shop/**` | Ported art (see Asset policy). |
| `tests/test_economy_state.gd` | `GameState` money/inventory/`use_item` unit tests. |
| `tests/test_koperasi.gd` | Shop scene structure, theming, routing. |
| `tests/test_inventory.gd` | Inventory scene structure, theming, routing, use popup. |
| `tests/test_wirausaha.gd` | Category plumbing, daily accrual, weekly payout. |
| `tests/test_report_card.gd` | Report card structure, absence of approve/belajar, live stats. |

**Modified files:**

| Path | Change |
|---|---|
| `Scripts/GameState.gd` | `money_changed` signal, inventory dictionary + API, `use_item`, `pending_earnings`, Wirausaha in `get_jadwal_for_day` counts. |
| `Scripts/Lobby/loby.gd` | Connect `koperasi_button`, `inventory_button`, `report_student_button`. |
| `Scripts/Design/DesignTokens.gd` | `cat_wirausaha` export + `category_color()` case. |
| `Assets/Theme/design_tokens.tres` | Bake `cat_wirausaha`. |
| `Scenes/AturJadwal/atur_jadwal.tscn` | Fifth activity button. |
| `Scripts/AturJadwal/atur_jadwal.gd` | Wirausaha connection + cost branch. |
| `Scripts/SchoolSimulation/SchoolDay.gd` | `DAY_CATEGORIES`, money pill, weekly payout. |
| `Scripts/SchoolSimulation/StudentManager.gd` | Wirausaha tunables + daily accrual. |
| `Scripts/StudentCard/student_card.gd` | Delegate card rendering to `StudentCardView`. |
| `project.godot` | Register `Cart` and `ItemDatabase` autoloads. |
| `tests/test_design_tokens.gd` | Add `Wirausaha` to the category-color coverage list. |

---

# Phase 1 — Economy State Foundation

## Task 1: Port item assets, `ItemData`, and `ItemDatabase`

**Files:**
- Create: `Assets/Images/Shop/` (copied art), `Scripts/Inventory/ItemData.gd`, `Scripts/Inventory/ItemDatabase.gd`
- Modify: `project.godot` (autoload section)
- Test: `tests/test_economy_state.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name ItemData` with fields `item_name: String`, `price: int`, `icon: Texture2D`, `description: String`, `category: String`, `display_size: Vector2`, `scale: float`, `mood_boost: int`, `energy_boost: int`. Autoload `ItemDatabase` with `items: Dictionary` and `get_item(item_name: String) -> ItemData`.

- [ ] **Step 1: Copy the art, byte-identical**

```bash
cd "C:/Users/Legion/Documents/KEJARTES/new-game-project"
SRC="C:/Users/Legion/Downloads/koprasi&inventory/Asset"
mkdir -p Assets/Images/Shop/ItemRak Assets/Images/Shop/UI
cp "$SRC"/ItemRak/*.png Assets/Images/Shop/ItemRak/
cp "$SRC"/UI/bg_inventory.png "$SRC"/UI/panel_header.png "$SRC"/UI/panel_sidebar.png "$SRC"/UI/panel_detail.png "$SRC"/UI/panel_popup.png Assets/Images/Shop/UI/
cp "$SRC"/Koin.png "$SRC"/return.png "$SRC"/"rak 1.jpg" "$SRC"/rak2.jpg Assets/Images/Shop/
ls -R Assets/Images/Shop
```

Do **not** copy `.import` files — Godot regenerates them, and the source
project's `.import` files carry UIDs from that project. Do **not** copy
`btn_normal.png`, `btn_pressed.png`, `slot_normal.png`, `slot_selected.png`.

- [ ] **Step 2: Let Godot import the new textures**

Open the project once (or use the `godot-ai` MCP `filesystem_manage` scan)
so `.import` files are generated. Verify:

```bash
ls Assets/Images/Shop/ItemRak/*.import | wc -l
```
Expected: `9`

- [ ] **Step 3: Write the failing test**

Create `tests/test_economy_state.gd`:

```gdscript
@tool
extends McpTestSuite

## Economy state: ItemData, ItemDatabase, GameState money/inventory/use_item.
## Suite must be @tool and no test may be a coroutine (the runner calls
## suite.call(name) without awaiting) -- same constraints as test_lobby.gd.

func suite_name() -> String:
	return "economy_state"

const _EXPECTED_ITEMS := [
	"Bank Soal", "Komik", "LKS", "Lompat Tali", "Raket",
	"Cilok", "Mie", "Pop Es", "Susu"
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
```

- [ ] **Step 4: Run it and confirm it fails**

Run the `economy_state` suite via the `godot-ai` MCP `test_run` tool.
Expected: FAIL — `ItemDatabase` is not a known identifier.

- [ ] **Step 5: Create `Scripts/Inventory/ItemData.gd`**

```gdscript
class_name ItemData
extends Resource

@export var item_name: String
@export var price: int
@export var icon: Texture2D
@export var description: String
@export var category: String
@export var display_size: Vector2 = Vector2.ZERO
@export var scale: float = 1.0

@export_group("Stats Boost")
@export var mood_boost: int = 0
@export var energy_boost: int = 0
```

- [ ] **Step 6: Create `Scripts/Inventory/ItemDatabase.gd`**

Copy `Script/AutoLoad/ItemDatabase.gd` from the source project verbatim,
then change every `icon_path` from `res://Asset/ItemRak/<file>` to
`res://Assets/Images/Shop/ItemRak/<file>`. Keep the item names, prices,
categories, descriptions, display sizes, and mood/energy values exactly as
the teammate authored them — those are balance decisions, not placeholders.

Confirm `get_item` returns `null` (not a new `ItemData`) for unknown names;
if the source returns a blank resource, change it to:

```gdscript
func get_item(item_name: String) -> ItemData:
	return items.get(item_name, null)
```

- [ ] **Step 7: Register the autoload**

In `project.godot`, under `[autoload]`, after the existing entries and
before `_mcp_game_helper`:

```
ItemDatabase="*res://Scripts/Inventory/ItemDatabase.gd"
```

- [ ] **Step 8: Run the test and confirm it passes**

Run the `economy_state` suite. Expected: 4 passing tests.

- [ ] **Step 9: Commit**

```bash
git add Assets/Images/Shop Scripts/Inventory project.godot tests/test_economy_state.gd
git commit -m "feat(shop): port item art, ItemData resource and ItemDatabase autoload"
```

---

## Task 2: Money signal and inventory API on `GameState`

**Files:**
- Modify: `Scripts/GameState.gd:77` (the `player_money` declaration)
- Test: `tests/test_economy_state.gd`

**Interfaces:**
- Consumes: `ItemData` (Task 1).
- Produces: on `GameState` — `signal money_changed(new_amount: int)`, `signal inventory_changed`, `var inventory: Dictionary`, `add_to_inventory(item_name: String, quantity: int) -> void`, `remove_from_inventory(item_name: String, quantity: int = 1) -> bool`, `get_inventory_quantity(item_name: String) -> int`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_economy_state.gd`:

```gdscript
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
```

- [ ] **Step 2: Run and confirm failure**

Run the `economy_state` suite.
Expected: FAIL — `money_changed` is not a signal on `GameState`.

- [ ] **Step 3: Implement in `Scripts/GameState.gd`**

Replace line 77 (`var player_money: int = 0`) with:

```gdscript
signal money_changed(new_amount: int)
signal inventory_changed

var _player_money: int = 0
var player_money: int:
	get: return _player_money
	set(value):
		_player_money = value
		money_changed.emit(_player_money)

## Inventory: item_name -> quantity. Session-scoped, like every other
## field on this autoload -- the project has no save system.
var inventory: Dictionary = {}


func add_to_inventory(item_name: String, quantity: int) -> void:
	inventory[item_name] = inventory.get(item_name, 0) + quantity
	inventory_changed.emit()


func remove_from_inventory(item_name: String, quantity: int = 1) -> bool:
	if not inventory.has(item_name):
		return false
	inventory[item_name] -= quantity
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	inventory_changed.emit()
	return true


func get_inventory_quantity(item_name: String) -> int:
	return inventory.get(item_name, 0)
```

- [ ] **Step 4: Verify existing money call sites still compile**

```bash
grep -rn "player_money" Scripts --include=*.gd
```

Expected call sites, all of which keep working unchanged because the
property preserves its read/write interface: `Scripts/Lobby/loby.gd:492`,
`loby.gd:638`, `loby.gd:640`, `Scripts/Debug/DebugManager.gd:613`, `:614`,
`:622`, `:623`, `:653`.

- [ ] **Step 5: Run the full suite set and confirm nothing regressed**

Run the `economy_state` and `lobby` suites via `test_run`.
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/GameState.gd tests/test_economy_state.gd
git commit -m "feat(economy): add money_changed signal and inventory API to GameState"
```

---

## Task 3: `Cart` autoload

**Files:**
- Create: `Scripts/Inventory/Cart.gd`
- Modify: `project.godot`
- Test: `tests/test_economy_state.gd`

**Interfaces:**
- Consumes: `ItemData` (Task 1).
- Produces: autoload `Cart` with `signal cart_changed`, `cart: Dictionary` (item_name → `{"data": ItemData, "quantity": int}`), `add_item(item: ItemData) -> void`, `remove_one(item_name: String) -> void`, `remove_item(item_name: String) -> void`, `clear() -> void`, `get_total() -> int`, `get_item_count() -> int`, `get_quantity(item_name: String) -> int`, `is_empty() -> bool`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_economy_state.gd`:

```gdscript
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
```

- [ ] **Step 2: Run and confirm failure**

Run the `economy_state` suite. Expected: FAIL — `Cart` not declared.

- [ ] **Step 3: Copy `Cart.gd`**

Copy `Script/AutoLoad/Cart.gd` from the source project to
`Scripts/Inventory/Cart.gd` verbatim. It has no dependency on the
teammate's `GameState`, so no edits are needed.

- [ ] **Step 4: Register the autoload**

In `project.godot`, under `[autoload]`, next to `ItemDatabase`:

```
Cart="*res://Scripts/Inventory/Cart.gd"
```

- [ ] **Step 5: Run the test and confirm it passes**

Run the `economy_state` suite. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Inventory/Cart.gd project.godot tests/test_economy_state.gd
git commit -m "feat(shop): add Cart autoload"
```

---

## Task 4: `use_item` applies to a chosen student

This replaces the teammate's global `player_mood` / `player_energy` model.
`GameState.approved_students` is an `Array` of `Dictionary` and is this
project's cross-screen source of truth (written by `student_card.gd:1683`,
read by `atur_jadwal.gd`, `SchoolDay.gd`, `SemesterEnd.gd`).

**Files:**
- Modify: `Scripts/GameState.gd`
- Test: `tests/test_economy_state.gd`

**Interfaces:**
- Consumes: `ItemData` (Task 1), inventory API (Task 2).
- Produces: `GameState.use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary` returning `{"applied": bool, "mood_delta": float, "energy_delta": float}`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_economy_state.gd`:

```gdscript
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
	GameState.add_to_inventory("Mie", 3)
	GameState.use_item(ItemDatabase.get_item("Mie"), 1, 2)
	assert_eq(GameState.get_inventory_quantity("Mie"), 1, "2 of 3 consumed")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_refuses_when_not_enough_owned() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie", 1)
	var result := GameState.use_item(ItemDatabase.get_item("Mie"), 1, 5)
	assert_false(result["applied"], "cannot use more than owned")
	assert_eq(GameState.approved_students[0]["mood"], 10.0, "no stat change on refusal")
	assert_eq(GameState.get_inventory_quantity("Mie"), 1, "nothing consumed on refusal")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_refuses_for_unknown_student_id() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie", 1)
	var result := GameState.use_item(ItemDatabase.get_item("Mie"), 99, 1)
	assert_false(result["applied"], "unknown student id must refuse")
	assert_eq(GameState.get_inventory_quantity("Mie"), 1, "nothing consumed on refusal")
	GameState.inventory.clear()
	GameState.approved_students = original
```

- [ ] **Step 2: Run and confirm failure**

Run the `economy_state` suite. Expected: FAIL — `use_item` not found.

- [ ] **Step 3: Implement in `Scripts/GameState.gd`**

Add after `get_inventory_quantity`:

```gdscript
## Stat ceiling shared with StudentData's mood/energy range.
const STAT_MAX := 100.0

## Applies an item's boosts to ONE student in approved_students.
##
## The teammate's build had a single global player_mood/player_energy;
## this project tracks both per student, so the caller must say who. The
## approved_students dictionaries are the cross-screen source of truth,
## so that is what gets written.
##
## Returns {"applied": bool, "mood_delta": float, "energy_delta": float}.
## The deltas are what actually landed after clamping, which is what the
## inventory's floating stat-pop labels display.
func use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary:
	var refused := {"applied": false, "mood_delta": 0.0, "energy_delta": 0.0}
	if item == null or quantity <= 0:
		return refused
	if get_inventory_quantity(item.item_name) < quantity:
		return refused

	var target: Dictionary = {}
	for student in approved_students:
		if student.get("id", -1) == student_id:
			target = student
			break
	if target.is_empty():
		return refused

	var mood_before: float = float(target.get("mood", 0.0))
	var energy_before: float = float(target.get("energy", 0.0))
	var mood_after := clampf(mood_before + item.mood_boost * quantity, 0.0, STAT_MAX)
	var energy_after := clampf(energy_before + item.energy_boost * quantity, 0.0, STAT_MAX)
	target["mood"] = mood_after
	target["energy"] = energy_after

	remove_from_inventory(item.item_name, quantity)

	return {
		"applied": true,
		"mood_delta": mood_after - mood_before,
		"energy_delta": energy_after - energy_before,
	}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run the `economy_state` suite. Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/GameState.gd tests/test_economy_state.gd
git commit -m "feat(inventory): apply item boosts to a chosen student"
```

---

# Phase 2 — Screen Port

## Task 5: Port the shop scene

The `Inventory` button inside the shop is deleted: the shop and the
inventory are independent siblings, each reached only from the lobby.

**Files:**
- Create: `Scenes/Koperasi/koprasi.tscn`, `Scripts/Koperasi/koprasi.gd`
- Test: `tests/test_koperasi.gd`

**Interfaces:**
- Consumes: `Cart`, `ItemDatabase`, `GameState.money_changed`, `GameState.add_to_inventory`.
- Produces: scene at `res://Scenes/Koperasi/koprasi.tscn`.

- [ ] **Step 1: Copy the scene and script**

```bash
cd "C:/Users/Legion/Documents/KEJARTES/new-game-project"
SRC="C:/Users/Legion/Downloads/koprasi&inventory"
mkdir -p Scenes/Koperasi Scripts/Koperasi
cp "$SRC/Scene/koprasi.tscn" Scenes/Koperasi/koprasi.tscn
cp "$SRC/Script/koprasi.gd" Scripts/Koperasi/koprasi.gd
```

Do not copy the `.tmp` files sitting beside `koprasi.tscn` in the source.

- [ ] **Step 2: Repoint every resource path in the scene**

In `Scenes/Koperasi/koprasi.tscn`, rewrite each `ext_resource` path:

| Old | New |
|---|---|
| `res://Script/koprasi.gd` | `res://Scripts/Koperasi/koprasi.gd` |
| `res://Asset/rak 1.jpg` | `res://Assets/Images/Shop/rak 1.jpg` |
| `res://Asset/rak2.jpg` | `res://Assets/Images/Shop/rak2.jpg` |
| `res://Asset/Koin.png` | `res://Assets/Images/Shop/Koin.png` |
| `res://Asset/return.png` | `res://Assets/Images/Shop/return.png` |
| `res://Asset/ItemRak/<file>` | `res://Assets/Images/Shop/ItemRak/<file>` |
| `res://Asset/UI/<file>` | `res://Assets/Images/Shop/UI/<file>` |

Delete the `uid="..."` attribute from each `ext_resource` line — those UIDs
belong to the source project. Godot re-resolves them from the paths.

- [ ] **Step 3: Delete the in-shop inventory button**

In `Scenes/Koperasi/koprasi.tscn`, delete the `[node name="Inventory" ...]`
block under `TextureRect` and any child nodes it owns.

In `Scripts/Koperasi/koprasi.gd`, delete:
- the `@onready var inventory_button = $TextureRect/Inventory` line (line 4 in the source),
- the `_on_inventory_pressed()` function (lines 254-257 in the source),
- the `inventory_button` entry in `_setup_main_buttons()` and any
  `pressed.connect` referencing it.

- [ ] **Step 4: Remap the SFX calls**

In `Scripts/Koperasi/koprasi.gd`, replace every `SfxManager` call:

| Old | New |
|---|---|
| `SfxManager.play_tap()` | `AudioDirector.play_sfx(&"tap")` |
| `SfxManager.play_navigate()` | `AudioDirector.play_sfx(&"whoosh")` |
| `SfxManager.play_buy()` | `AudioDirector.play_sfx(&"coin")` |
| `SfxManager.play_error()` | `AudioDirector.play_sfx(&"error")` |

Verify none remain:

```bash
grep -n "SfxManager" Scripts/Koperasi/koprasi.gd
```
Expected: no output.

- [ ] **Step 5: Point the back button at the lobby**

In `_on_back_pressed()` / `_finish_back_close()`, the scene change target
becomes the lobby with this project's transition style:

```gdscript
Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)
```

- [ ] **Step 6: Write the test**

Create `tests/test_koperasi.gd`:

```gdscript
@tool
extends McpTestSuite

## Koperasi (shop). Ported from the teammate's project; this suite pins the
## integration contract rather than the art. Suite is @tool and no test is a
## coroutine, per the runner constraints documented in test_lobby.gd.

func suite_name() -> String:
	return "koperasi"

const _SCENE_PATH := "res://Scenes/Koperasi/koprasi.tscn"
const _SCRIPT_PATH := "res://Scripts/Koperasi/koprasi.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "koprasi.tscn must exist")
	var packed := load(_SCENE_PATH) as PackedScene
	assert_true(packed != null, "koprasi.tscn must load as a PackedScene")

func test_scene_instantiates() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "koprasi.tscn must instantiate")
	scene.free()

func test_no_in_shop_inventory_button() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("Inventory", true, false) == null,
		"the shop must not link to the inventory -- both are lobby siblings")
	scene.free()

func test_back_button_returns_to_lobby() -> void:
	assert_true(_source().contains("res://Scenes/Lobby/loby.tscn"),
		"the shop's back button must return to the lobby")

func test_does_not_reference_source_project_paths() -> void:
	var src := _source()
	assert_false(src.contains("res://Scene/"), "no source-project scene paths")
	assert_false(src.contains("res://Asset/"), "no source-project asset paths")

func test_uses_audio_director_not_sfx_manager() -> void:
	var src := _source()
	assert_false(src.contains("SfxManager"), "SfxManager was not imported")
	assert_true(src.contains("AudioDirector.play_sfx"), "must use AudioDirector")

func test_scene_has_no_source_project_resource_paths() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_false(raw.contains("res://Asset/"), "scene must not reference res://Asset/")
	assert_false(raw.contains("res://Script/"), "scene must not reference res://Script/")
```

- [ ] **Step 7: Run the test**

Run the `koperasi` suite. Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Koperasi Scripts/Koperasi tests/test_koperasi.gd
git commit -m "feat(shop): port koperasi scene, drop in-shop inventory link"
```

---

## Task 6: Port the inventory scene

**Files:**
- Create: `Scenes/Inventory/inventory.tscn`, `Scripts/Inventory/inventory.gd`
- Test: `tests/test_inventory.gd`

**Interfaces:**
- Consumes: `ItemDatabase`, `GameState.inventory`, `GameState.money_changed`, `GameState.inventory_changed`, `GameState.use_item` (Task 4).
- Produces: scene at `res://Scenes/Inventory/inventory.tscn`.

- [ ] **Step 1: Copy the scene and script**

```bash
cd "C:/Users/Legion/Documents/KEJARTES/new-game-project"
SRC="C:/Users/Legion/Downloads/koprasi&inventory"
mkdir -p Scenes/Inventory
cp "$SRC/Scene/inventory.tscn" Scenes/Inventory/inventory.tscn
cp "$SRC/Script/inventory.gd" Scripts/Inventory/inventory.gd
```

- [ ] **Step 2: Repoint resource paths and strip source UIDs**

Same mapping table as Task 5, Step 2, applied to
`Scenes/Inventory/inventory.tscn`, plus:

| Old | New |
|---|---|
| `res://Script/inventory.gd` | `res://Scripts/Inventory/inventory.gd` |

Delete every `uid="..."` attribute on `ext_resource` lines.

- [ ] **Step 3: Remap the SFX calls**

Same table as Task 5, Step 4, applied to `Scripts/Inventory/inventory.gd`.
Verify:

```bash
grep -n "SfxManager" Scripts/Inventory/inventory.gd
```
Expected: no output.

- [ ] **Step 4: Point the back button at the lobby**

The source's `_on_back_pressed()` (line 500-504) returns to
`res://Scene/koprasi.tscn`. Since the inventory is now reached only from
the lobby, change it to:

```gdscript
Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)
```

- [ ] **Step 5: Replace the global stat call with the per-student one**

The source's `_on_popup_ok_pressed()` calls
`GameState.use_item(selected_item, popup_quantity)`. That signature no
longer exists. Leave a temporary single-argument-safe call that targets the
first approved student, so the scene runs; Task 10 replaces it with the
real picker:

```gdscript
func _on_popup_ok_pressed() -> void:
	# Task 10 replaces this with the student picker. Until then, target the
	# first approved student so the screen is runnable end to end.
	if GameState.approved_students.is_empty():
		return
	var student_id: int = GameState.approved_students[0].get("id", -1)
	var result := GameState.use_item(selected_item, student_id, popup_quantity)
	if not result["applied"]:
		AudioDirector.play_sfx(&"error")
		return
	_spawn_floating_stat_pops(selected_item, popup_quantity)
	_close_popup_animated()
```

- [ ] **Step 6: Write the test**

Create `tests/test_inventory.gd`:

```gdscript
@tool
extends McpTestSuite

## Inventory screen. Suite is @tool and no test is a coroutine, per the
## runner constraints documented in test_lobby.gd.

func suite_name() -> String:
	return "inventory"

const _SCENE_PATH := "res://Scenes/Inventory/inventory.tscn"
const _SCRIPT_PATH := "res://Scripts/Inventory/inventory.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "inventory.tscn must exist")
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "inventory.tscn must instantiate")
	scene.free()

func test_back_button_returns_to_lobby_not_shop() -> void:
	var src := _source()
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"back must return to the lobby")
	assert_false(src.contains("koprasi.tscn"),
		"the inventory must not link back into the shop")

func test_uses_audio_director_not_sfx_manager() -> void:
	var src := _source()
	assert_false(src.contains("SfxManager"), "SfxManager was not imported")
	assert_true(src.contains("AudioDirector.play_sfx"), "must use AudioDirector")

func test_does_not_reference_source_project_paths() -> void:
	var src := _source()
	assert_false(src.contains("res://Scene/"), "no source-project scene paths")
	assert_false(src.contains("res://Asset/"), "no source-project asset paths")

func test_scene_has_no_source_project_resource_paths() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_false(raw.contains("res://Asset/"), "scene must not reference res://Asset/")
	assert_false(raw.contains("res://Script/"), "scene must not reference res://Script/")

func test_item_icons_are_preserved_art() -> void:
	## The item icons are finished art, not placeholders. This pins that
	## they still resolve after the port.
	for item_name in ["Komik", "Raket", "Mie"]:
		var item: ItemData = ItemDatabase.get_item(item_name)
		assert_true(item.icon != null, "icon preserved for: " + item_name)
```

- [ ] **Step 7: Run the test**

Run the `inventory` suite. Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Inventory Scripts/Inventory/inventory.gd tests/test_inventory.gd
git commit -m "feat(inventory): port inventory scene, route back to lobby"
```

---

## Task 7: Restyle both screens onto the project theme

Only the four placeholder chrome textures are replaced. `bg_inventory`,
`panel_header`, `panel_sidebar`, `panel_detail`, `panel_popup`, the shelf
JPGs, and every item icon stay exactly as they are.

**Files:**
- Modify: `Scenes/Koperasi/koprasi.tscn`, `Scenes/Inventory/inventory.tscn`, `Scripts/Koperasi/koprasi.gd`, `Scripts/Inventory/inventory.gd`
- Test: `tests/test_koperasi.gd`, `tests/test_inventory.gd`

**Interfaces:**
- Consumes: `Assets/Theme/kejartes_theme.tres`, `DesignTokens.load_default()`, `Scripts/UI/SafeAreaMargin.gd`, `TouchFeedbackManager`, `UIPolish`.
- Produces: no new API.

- [ ] **Step 1: Write the failing tests**

Append to both `tests/test_koperasi.gd` and `tests/test_inventory.gd`
(repeat the code in each file — do not cross-reference):

```gdscript
func test_no_placeholder_chrome_textures() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	for placeholder in ["btn_normal", "btn_pressed", "slot_normal", "slot_selected"]:
		assert_false(raw.contains(placeholder),
			"placeholder chrome must be replaced by the theme: " + placeholder)

func test_preserved_art_is_still_referenced() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_true(raw.contains("Assets/Images/Shop/"),
		"the ported art must still be referenced")

func test_no_raw_color_literals_in_script() -> void:
	## Colors come from DesignTokens, matching the rule test_lobby.gd
	## enforces for the lobby.
	var src := _source()
	assert_false(src.contains("Color(0."),
		"no hardcoded Color() literals -- use DesignTokens")

func test_script_reads_design_tokens() -> void:
	assert_true(_source().contains("DesignTokens.load_default()"),
		"styling must be sourced from DesignTokens")

func test_scene_uses_project_theme() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_true(raw.contains("kejartes_theme.tres"),
		"the scene root must carry the project theme")
```

- [ ] **Step 2: Run and confirm failure**

Run the `koperasi` and `inventory` suites.
Expected: FAIL on the placeholder, theme, and `Color(` checks.

- [ ] **Step 3: Strip the placeholder StyleBoxTextures**

In both `.tscn` files, delete every `[sub_resource type="StyleBoxTexture"]`
block whose `texture` is `btn_normal`, `btn_pressed`, `slot_normal`, or
`slot_selected`, and delete the `theme_override_styles/*` properties that
referenced them. Delete the matching `ext_resource` lines.

Keep the `StyleBoxTexture` blocks built on `panel_header`,
`panel_sidebar`, `panel_detail`, and `panel_popup` — those wrap preserved
art.

- [ ] **Step 4: Assign the project theme to both scene roots**

Add to each root node in the `.tscn`:

```
theme = ExtResource("kejartes_theme")
```

with a matching `ext_resource`:

```
[ext_resource type="Theme" path="res://Assets/Theme/kejartes_theme.tres" id="kejartes_theme"]
```

- [ ] **Step 5: Re-source the hardcoded colors**

In both scripts, replace every `Color(...)` literal with a token read. The
source project's palette maps as follows:

| Source literal | Token |
|---|---|
| `Color(0.08, 0.1, 0.22, 1)` and `Color(0.08, 0.09, 0.22, 0.98)` | `tokens.surface_card` |
| `Color(0.25, 0.55, 1, 1)` | `tokens.brand_primary` |
| `Color(0.2, 0.44, 0.8, 1)` | `tokens.brand_primary.darkened(0.2)` |
| `Color(0.36, 0.62, 1, 1)` | `tokens.brand_primary.lightened(0.15)` |
| `Color(0.2, 0.2, 0.45, 1)`, `Color(0.25, 0.38, 0.65, 1)`, `Color(0.3, 0.45, 0.75, 1)` | `tokens.text_secondary` |
| error/red message color | `tokens.state_error` |
| success/green message color | `tokens.state_success` |

Add near the top of each `_ready()`:

```gdscript
var tokens := DesignTokens.load_default()
```

Any `StyleBoxFlat` the script builds gets its `bg_color` / `border_color`
from `tokens`, and its `corner_radius_*` from the token radius scale rather
than the hardcoded 8/12/16.

- [ ] **Step 6: Wire touch feedback, polish, and safe area**

In each `_ready()`, after the button references resolve:

```gdscript
for btn in _all_buttons():
	TouchFeedbackManager.register(btn)
	UIPolish.apply_button_juice(btn)
```

where `_all_buttons()` returns the screen's `BaseButton` children. Follow
the exact registration call signature used in `Scripts/Lobby/loby.gd:603-605`;
copy that pattern rather than inventing one.

Attach `Scripts/UI/SafeAreaMargin.gd` to both scene roots the same way the
lobby does.

- [ ] **Step 7: Run the tests and confirm they pass**

Run the `koperasi` and `inventory` suites. Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Koperasi Scenes/Inventory Scripts/Koperasi Scripts/Inventory
git add tests/test_koperasi.gd tests/test_inventory.gd
git commit -m "feat(shop): restyle koperasi and inventory onto the project theme"
```

---

## Task 8: Rebuild the modals and transitions

The `UsePopup` is currently an opaque full-screen `ColorRect` that slams
into view. It becomes the same modal the rest of the project uses.

**Files:**
- Modify: `Scripts/Inventory/inventory.gd` (`_open_use_popup`, `_close_popup_animated`), `Scripts/Koperasi/koprasi.gd` (`Rak1` panel show/hide)
- Test: `tests/test_inventory.gd`

**Interfaces:**
- Consumes: `DesignTokens.scrim_color()`, `tokens.dur_fast`.
- Produces: no new API.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_inventory.gd`:

```gdscript
func test_use_popup_uses_the_project_scrim() -> void:
	assert_true(_source().contains("scrim_color()"),
		"the modal backdrop must use DesignTokens.scrim_color()")

func test_use_popup_animates_with_token_durations() -> void:
	assert_true(_source().contains("dur_fast"),
		"popup fades must use the token duration, not a magic number")

func test_scene_changes_specify_a_transition_style() -> void:
	assert_true(_source().contains("Transition.Style."),
		"navigation must specify this project's transition style")
```

- [ ] **Step 2: Run and confirm failure**

Run the `inventory` suite. Expected: FAIL on all three.

- [ ] **Step 3: Rebuild the popup open animation**

Replace the body of `_open_use_popup(item, max_qty)` so the backdrop and
panel animate the way `student_card.gd`'s popups do:

```gdscript
func _open_use_popup(item: ItemData, max_qty: int) -> void:
	var tokens := DesignTokens.load_default()
	selected_item = item
	popup_quantity = 1
	_update_popup_qty_display()

	use_popup.visible = true
	use_popup.color = tokens.scrim_color()
	use_popup.modulate.a = 0.0
	use_popup.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := use_popup.get_node("CenterContainer/PopupPanel")
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.9, 0.9)

	AudioDirector.play_sfx(&"popup_open")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(use_popup, "modulate:a", 1.0, tokens.dur_fast)
	tween.tween_property(panel, "scale", Vector2.ONE, tokens.dur_fast) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 4: Rebuild the popup close animation**

```gdscript
func _close_popup_animated() -> void:
	var tokens := DesignTokens.load_default()
	var panel := use_popup.get_node("CenterContainer/PopupPanel")

	AudioDirector.play_sfx(&"popup_close")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(use_popup, "modulate:a", 0.0, tokens.dur_fast)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), tokens.dur_fast) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		use_popup.visible = false
		use_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_item = null
	)
```

- [ ] **Step 5: Add tap-outside-to-dismiss**

Connect the scrim's input so a tap outside the panel closes the popup:

```gdscript
func _on_use_popup_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var panel := use_popup.get_node("CenterContainer/PopupPanel")
		if not panel.get_global_rect().has_point(event.global_position):
			_close_popup_animated()
```

Wire it in `_ready()`:

```gdscript
if not use_popup.gui_input.is_connected(_on_use_popup_input):
	use_popup.gui_input.connect(_on_use_popup_input)
```

- [ ] **Step 6: Apply the same treatment to the shop's `Rak1` panel**

In `Scripts/Koperasi/koprasi.gd`, give the `Rak1` panel the same scrim,
fade-plus-scale, and tap-outside-to-dismiss behavior. Repeat the code
above with `rak1_panel` in place of `use_popup` — do not extract a helper
across the two files.

- [ ] **Step 7: Specify transition styles on every scene change**

Every `Transition.change_scene(path)` call in both scripts takes an
explicit style:

```gdscript
Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)
```

- [ ] **Step 8: Run the tests and confirm they pass**

Run the `inventory` and `koperasi` suites. Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Inventory/inventory.gd Scripts/Koperasi/koprasi.gd tests/test_inventory.gd
git commit -m "feat(shop): rebuild popups on the project modal and transition style"
```

---

## Task 9: Wire the lobby buttons

This is the bug the user reported: `$Koperasi` and `$Inventory` have no
`pressed` connection anywhere in `loby.gd`.

**Files:**
- Modify: `Scripts/Lobby/loby.gd`
- Test: `tests/test_lobby.gd`

**Interfaces:**
- Consumes: the two ported scenes.
- Produces: `_on_koperasi_pressed()`, `_on_inventory_pressed()` on the lobby.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_lobby.gd`:

```gdscript
func _lobby_source() -> String:
	return FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")

func test_koperasi_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_koperasi_pressed"),
		"the Koperasi button must have a handler")
	assert_true(src.contains("res://Scenes/Koperasi/koprasi.tscn"),
		"Koperasi must route to the shop scene")

func test_inventory_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_inventory_pressed"),
		"the Inventory button must have a handler")
	assert_true(src.contains("res://Scenes/Inventory/inventory.tscn"),
		"Inventory must route to the inventory scene")
```

- [ ] **Step 2: Run and confirm failure**

Run the `lobby` suite. Expected: FAIL on both.

- [ ] **Step 3: Add the handlers**

In `Scripts/Lobby/loby.gd`, next to `_on_student_pressed` (line 655):

```gdscript
func _on_koperasi_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/Koperasi/koprasi.tscn", Transition.Style.WIPE)


func _on_inventory_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/Inventory/inventory.tscn", Transition.Style.WIPE)
```

- [ ] **Step 4: Connect them, following the existing guard pattern**

In the same block that connects `student_button` and `jadwal_button`
(lines 167-170), matching its `is_connected` guard style:

```gdscript
if not koperasi_button.pressed.is_connected(_on_koperasi_pressed):
	koperasi_button.pressed.connect(_on_koperasi_pressed)
if not inventory_button.pressed.is_connected(_on_inventory_pressed):
	inventory_button.pressed.connect(_on_inventory_pressed)
```

Note there are two such connection blocks (around lines 143-146 and
167-170, one gated on the tutorial). Add the guards to the ungated block at
167-170 only, so the buttons stay inert during the tutorial exactly as
`student_button` and `jadwal_button` do.

- [ ] **Step 5: Run the tests and confirm they pass**

Run the `lobby` suite. Expected: all PASS.

- [ ] **Step 6: Verify in the running app**

Launch the project. From the lobby, tap Koperasi → shop opens → back →
lobby. Tap Inventory → inventory opens → back → lobby. Confirm the shop has
no inventory button.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Lobby/loby.gd tests/test_lobby.gd
git commit -m "fix(lobby): wire the dead Koperasi and Inventory buttons"
```

---

## Task 10: Student picker in the use popup

**Files:**
- Modify: `Scenes/Inventory/inventory.tscn`, `Scripts/Inventory/inventory.gd`
- Test: `tests/test_inventory.gd`

**Interfaces:**
- Consumes: `GameState.approved_students`, `GameState.use_item` (Task 4).
- Produces: `inventory.gd` gains `_selected_student_id: int` and `_build_student_strip() -> void`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_inventory.gd`:

```gdscript
func test_use_popup_has_a_student_strip() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	var strip := scene.find_child("StudentStrip", true, false)
	assert_true(strip != null,
		"the use popup must offer a student to apply the item to")
	scene.free()

func test_use_targets_the_selected_student() -> void:
	var src := _source()
	assert_true(src.contains("_selected_student_id"),
		"the popup must track which student was picked")
	assert_true(src.contains("GameState.use_item("),
		"confirm must route through GameState.use_item")

func test_confirm_is_gated_on_a_student_selection() -> void:
	assert_true(_source().contains("popup_ok_btn.disabled"),
		"confirm stays disabled until a student is chosen")

func test_no_global_player_mood_reference() -> void:
	var src := _source()
	assert_false(src.contains("GameState.player_mood"),
		"the global stat model was not imported")
	assert_false(src.contains("GameState.player_energy"),
		"the global stat model was not imported")
```

- [ ] **Step 2: Run and confirm failure**

Run the `inventory` suite. Expected: FAIL on the strip and gating checks.

- [ ] **Step 3: Add the strip node to the scene**

In `Scenes/Inventory/inventory.tscn`, inside
`UsePopup/CenterContainer/PopupPanel/VBox`, above `StepperHBox`, add:

```
[node name="StudentStrip" type="HBoxContainer" parent="UsePopup/CenterContainer/PopupPanel/VBox"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 12
```

- [ ] **Step 4: Build the strip at popup open**

In `Scripts/Inventory/inventory.gd`:

```gdscript
@onready var student_strip: HBoxContainer = $UsePopup/CenterContainer/PopupPanel/VBox/StudentStrip

var _selected_student_id: int = -1


## One tappable card per approved student: portrait, name, and live
## mood/energy bars, so the player can see who needs the item most.
func _build_student_strip() -> void:
	for child in student_strip.get_children():
		child.queue_free()
	_selected_student_id = -1
	popup_ok_btn.disabled = true

	var tokens := DesignTokens.load_default()
	for student in GameState.approved_students:
		var card := Button.new()
		card.custom_minimum_size = Vector2(140, 180)
		card.toggle_mode = true
		card.text = str(student.get("student_name", "?"))
		card.set_meta("student_id", student.get("id", -1))

		var bars := VBoxContainer.new()
		bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(_make_strip_bar(float(student.get("mood", 0.0)), tokens.cat_istirahat))
		bars.add_child(_make_strip_bar(float(student.get("energy", 0.0)), tokens.state_success))
		card.add_child(bars)

		card.pressed.connect(_on_student_card_pressed.bind(card))
		student_strip.add_child(card)


func _make_strip_bar(value: float, tint: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.self_modulate = tint
	return bar


func _on_student_card_pressed(card: Button) -> void:
	AudioDirector.play_sfx(&"select")
	for child in student_strip.get_children():
		if child is Button:
			child.button_pressed = (child == card)
	_selected_student_id = card.get_meta("student_id")
	popup_ok_btn.disabled = false
```

Call `_build_student_strip()` at the end of `_open_use_popup()`.

- [ ] **Step 5: Route confirm through the selection**

Replace the temporary `_on_popup_ok_pressed()` from Task 6, Step 5:

```gdscript
func _on_popup_ok_pressed() -> void:
	if _selected_student_id == -1:
		AudioDirector.play_sfx(&"error")
		return
	var result := GameState.use_item(selected_item, _selected_student_id, popup_quantity)
	if not result["applied"]:
		AudioDirector.play_sfx(&"error")
		return
	AudioDirector.play_sfx(&"confirm")
	_spawn_floating_stat_pops(selected_item, popup_quantity)
	_close_popup_animated()
```

- [ ] **Step 6: Show the real deltas in the stat pops**

`_spawn_floating_stat_pops` currently reads `item.mood_boost * qty`
directly, which overstates the gain when a stat clamps at 100. Change its
signature to take the deltas `use_item` returned:

```gdscript
func _spawn_floating_stat_pops(mood_delta: float, energy_delta: float) -> void:
```

and update the call site to `_spawn_floating_stat_pops(result["mood_delta"], result["energy_delta"])`.
Inside, skip a label entirely when its delta is `0.0`.

- [ ] **Step 7: Run the tests and confirm they pass**

Run the `inventory` and `economy_state` suites. Expected: all PASS.

- [ ] **Step 8: Verify in the running app**

Use the `DebugManager` money command to fund a purchase, buy an item, open
the inventory, use it, and confirm the chosen student's bars move and the
others do not.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Inventory Scripts/Inventory/inventory.gd tests/test_inventory.gd
git commit -m "feat(inventory): pick a student before using an item"
```

---

# Phase 3 — Wirausaha

## Task 11: `Wirausaha` design token

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd:49-53` and `:107-113`, `Assets/Theme/design_tokens.tres`
- Test: `tests/test_design_tokens.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `DesignTokens.cat_wirausaha: Color` and a `"Wirausaha"` case in `category_color()`.

- [ ] **Step 1: Write the failing test**

In `tests/test_design_tokens.gd`, extend the existing coverage list in
`test_category_color_lookup_covers_every_schedule_category` to include
`"Wirausaha"`, and add:

```gdscript
func test_wirausaha_color_is_distinct_from_other_categories() -> void:
	var tokens := DesignTokens.load_default()
	var wirausaha := tokens.category_color("Wirausaha")
	for other in ["Akademis", "Olahraga", "SeniBudaya", "Istirahat", "Libur"]:
		assert_true(wirausaha != tokens.category_color(other),
			"Wirausaha must be visually distinct from: " + other)
```

- [ ] **Step 2: Run and confirm failure**

Run the `design_tokens` suite.
Expected: FAIL — `Wirausaha` falls back to `text_secondary`.

- [ ] **Step 3: Add the token**

In `Scripts/Design/DesignTokens.gd`, after `cat_libur` (line 53):

```gdscript
## Wirausaha: the money-earning schedule activity. Teal keeps it clear of
## the five existing category hues.
@export var cat_wirausaha: Color = Color("00a389")
```

And in `category_color()`, before the fallback:

```gdscript
		"Wirausaha": return cat_wirausaha
```

- [ ] **Step 4: Bake it into the resource**

Add the property to `Assets/Theme/design_tokens.tres`:

```
cat_wirausaha = Color(0, 0.639216, 0.537255, 1)
```

Then re-bake the theme:

Run `Scripts/Design/BakeTheme.gd` the way the project's existing theme bake
is invoked (check the file's header comment for its entry point).

- [ ] **Step 5: Run the tests and confirm they pass**

Run the `design_tokens` and `theme_factory` suites. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Assets/Theme tests/test_design_tokens.gd
git commit -m "feat(design): add the Wirausaha category color token"
```

---

## Task 12: Wirausaha in the schedule UI

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn`, `Scripts/AturJadwal/atur_jadwal.gd:909-914` and `:949-968`, `Scripts/GameState.gd:122`, `Scripts/SchoolSimulation/SchoolDay.gd:138`
- Test: `tests/test_wirausaha.gd`

**Interfaces:**
- Consumes: `cat_wirausaha` (Task 11).
- Produces: `"Wirausaha"` accepted as a `day_schedules` category everywhere.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_wirausaha.gd`:

```gdscript
@tool
extends McpTestSuite

## Wirausaha: the fifth schedule activity. Students assigned to it earn
## money at a mood/energy cost, paid out at the end of the week.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "wirausaha"

const _JADWAL_SCENE := "res://Scenes/AturJadwal/atur_jadwal.tscn"

func test_schedule_popup_offers_wirausaha() -> void:
	var scene := (load(_JADWAL_SCENE) as PackedScene).instantiate()
	var btn := scene.find_child("Wirausaha", true, false)
	assert_true(btn != null, "the scheduling popup must offer Wirausaha")
	scene.free()

func test_jadwal_script_binds_wirausaha() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
	assert_true(src.contains("_on_activity_selected.bind(\"Wirausaha\")"),
		"the Wirausaha button must be connected")

func test_day_categories_include_wirausaha() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("\"Wirausaha\""),
		"SchoolDay.DAY_CATEGORIES must include Wirausaha")

func test_jadwal_counts_include_wirausaha() -> void:
	GameState.day_schedules = {
		1: {"Senin": {"category": "Wirausaha", "mood_cost": 8, "energy_cost": 10}},
	}
	var counts := GameState.get_jadwal_for_day("Senin")
	assert_true(counts.has("Wirausaha"), "counts must track Wirausaha")
	assert_eq(counts["Wirausaha"], 1, "one student assigned to Wirausaha")
	GameState.day_schedules = {}
```

- [ ] **Step 2: Run and confirm failure**

Run the `wirausaha` suite. Expected: all four FAIL.

- [ ] **Step 3: Add the button to the scene**

In `Scenes/AturJadwal/atur_jadwal.tscn`, duplicate the
`[node name="Olahraga" type="Button" parent="Penjadwalan/TextureRect"]`
block — including its `ProgressBar2` child — renaming the node to
`Wirausaha` and its child bar to `ProgressBar5`. Position it below
`Olahraga` and reduce each of the five buttons' heights so the popup still
fits; the popup gets visually tighter with five entries, which is expected.

Set the new bar's `category = "Wirausaha"`.

- [ ] **Step 4: Connect the button**

In `Scripts/AturJadwal/atur_jadwal.gd`, add an `@onready` reference beside
`popup_olahraga_btn` (line 54) and its bar beside `popup_olahraga_bar`
(line 58), then in the connection block (lines 909-914):

```gdscript
if popup_wirausaha_btn and not popup_wirausaha_btn.pressed.is_connected(_on_activity_selected.bind("Wirausaha")):
	popup_wirausaha_btn.pressed.connect(_on_activity_selected.bind("Wirausaha"))
```

And beside line 208's tinting:

```gdscript
popup_wirausaha_btn.self_modulate = tokens.category_color("Wirausaha")
```

- [ ] **Step 5: Give Wirausaha its own cost branch**

In `_on_activity_selected` (line 949), the cost branch currently splits
`Istirahat` from everything else. Add a third arm — Wirausaha costs more
than a normal activity day:

```gdscript
		if category == "Istirahat":
			mood_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
			energy_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
		elif category == "Wirausaha":
			mood_cost = randi_range(WIRAUSAHA_MOOD_MIN, WIRAUSAHA_MOOD_MAX)
			energy_cost = randi_range(WIRAUSAHA_ENERGY_MIN, WIRAUSAHA_ENERGY_MAX)
		else:
			mood_cost = randi_range(MOOD_LOSS_MIN, MOOD_LOSS_MAX)
			energy_cost = randi_range(ENERGY_LOSS_MIN, ENERGY_LOSS_MAX)
```

Declare the four new constants beside the existing `MOOD_LOSS_MIN` group:

```gdscript
const WIRAUSAHA_MOOD_MIN := 8
const WIRAUSAHA_MOOD_MAX := 14
const WIRAUSAHA_ENERGY_MIN := 10
const WIRAUSAHA_ENERGY_MAX := 16
```

- [ ] **Step 6: Add it to the two enumeration sites**

`Scripts/SchoolSimulation/SchoolDay.gd:138`:

```gdscript
const DAY_CATEGORIES := ["Olahraga", "Akademis", "Istirahat", "Libur", "SeniBudaya", "Wirausaha"]
```

`Scripts/GameState.gd:122`:

```gdscript
	var counts = {"Akademis": 0, "Olahraga": 0, "SeniBudaya": 0, "Istirahat": 0, "Wirausaha": 0}
```

- [ ] **Step 7: Run the tests and confirm they pass**

Run the `wirausaha` and `atur_jadwal` suites. Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add Scenes/AturJadwal Scripts/AturJadwal Scripts/GameState.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_wirausaha.gd
git commit -m "feat(jadwal): add Wirausaha as a fifth schedule activity"
```

---

## Task 13: Daily earning accrual

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` (top-of-file constants, `apply_daily_decay_all`), `Scripts/GameState.gd`
- Test: `tests/test_wirausaha.gd`

**Interfaces:**
- Consumes: `"Wirausaha"` category (Task 12).
- Produces: `GameState.pending_earnings: Dictionary` (student_id → int), and a `WIRAUSAHA_*` const block at the top of `StudentManager.gd`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_wirausaha.gd`:

```gdscript
func test_pending_earnings_starts_empty() -> void:
	GameState.pending_earnings.clear()
	assert_true(GameState.pending_earnings.is_empty(),
		"no earnings are pending before any Wirausaha day")

func test_wirausaha_accrues_earnings_for_the_assigned_student() -> void:
	GameState.pending_earnings.clear()
	GameState.day_schedules = {
		7: {"Senin": {"category": "Wirausaha", "mood_cost": 10, "energy_cost": 12}},
	}
	var manager := StudentManager.new()
	var student := StudentData.new()
	student.id = 7
	student.student_name = "Uji"
	student.energy = 80.0
	student.mood = 80.0
	manager.students = [student]
	manager.apply_daily_decay_all("Senin")
	assert_true(GameState.pending_earnings.get(7, 0) > 0,
		"a Wirausaha day must accrue money")
	GameState.pending_earnings.clear()
	GameState.day_schedules = {}
	manager.free()

func test_wirausaha_grants_no_academic_stat() -> void:
	GameState.pending_earnings.clear()
	GameState.day_schedules = {
		7: {"Senin": {"category": "Wirausaha", "mood_cost": 10, "energy_cost": 12}},
	}
	var manager := StudentManager.new()
	var student := StudentData.new()
	student.id = 7
	student.student_name = "Uji"
	student.energy = 80.0
	student.mood = 80.0
	student.akademis = 50.0
	student.seni_budaya = 50.0
	student.olahraga = 50.0
	manager.students = [student]
	manager.apply_daily_decay_all("Senin")
	assert_eq(student.akademis, 50.0, "Wirausaha grants no akademis")
	assert_eq(student.seni_budaya, 50.0, "Wirausaha grants no seni budaya")
	assert_eq(student.olahraga, 50.0, "Wirausaha grants no olahraga")
	GameState.pending_earnings.clear()
	GameState.day_schedules = {}
	manager.free()

func test_tired_students_earn_less() -> void:
	## Earnings scale with energy, so the same roll range cannot produce a
	## higher floor for an exhausted student than for a rested one.
	GameState.pending_earnings.clear()
	GameState.day_schedules = {
		7: {"Senin": {"category": "Wirausaha", "mood_cost": 10, "energy_cost": 12}},
	}
	var totals := {}
	for energy_value in [10.0, 100.0]:
		var sum := 0
		for _i in range(30):
			GameState.pending_earnings.clear()
			var manager := StudentManager.new()
			var student := StudentData.new()
			student.id = 7
			student.student_name = "Uji"
			student.energy = energy_value
			student.mood = 80.0
			manager.students = [student]
			manager.apply_daily_decay_all("Senin")
			sum += GameState.pending_earnings.get(7, 0)
			manager.free()
		totals[energy_value] = sum
	assert_true(totals[100.0] > totals[10.0],
		"a rested student must out-earn an exhausted one over 30 rolls")
	GameState.pending_earnings.clear()
	GameState.day_schedules = {}
```

- [ ] **Step 2: Run and confirm failure**

Run the `wirausaha` suite.
Expected: FAIL — `pending_earnings` is not a field on `GameState`.

- [ ] **Step 3: Add the field to `GameState`**

Beside the inventory declaration from Task 2:

```gdscript
## Wirausaha earnings accrued this week, student_id -> rupiah. Emptied by
## SchoolDay at week end, when the total is paid into player_money.
var pending_earnings: Dictionary = {}
```

- [ ] **Step 4: Add the tunables to `StudentManager.gd`**

At the top of the file, with a comment marking it as the balance knob:

```gdscript
# ================= WIRAUSAHA BALANCE =================
# The only numbers that need touching to retune the economy. A Wirausaha
# day grants no academic stat; it trades mood and energy for money, and
# pays out at the end of the week.

## Roll range for a single Wirausaha day at full energy.
const WIRAUSAHA_EARN_MIN := 120
const WIRAUSAHA_EARN_MAX := 320
## Earnings are multiplied by this floor plus the student's energy
## fraction, so an exhausted student still earns something.
const WIRAUSAHA_ENERGY_FLOOR := 0.35
## Stat cost on top of the normal personality decay.
const WIRAUSAHA_MOOD_COST := 6.0
const WIRAUSAHA_ENERGY_COST := 10.0
```

- [ ] **Step 5: Handle the category in `apply_daily_decay_all`**

In the activity branch (around line 126, `if category != ""`), special-case
Wirausaha before the `apply_jadwal_activity` call so no stat gain happens:

```gdscript
		if category == "Wirausaha":
			var energy_fraction: float = clampf(student.energy / 100.0, 0.0, 1.0)
			var multiplier: float = WIRAUSAHA_ENERGY_FLOOR + (1.0 - WIRAUSAHA_ENERGY_FLOOR) * energy_fraction
			var earned: int = int(round(randi_range(WIRAUSAHA_EARN_MIN, WIRAUSAHA_EARN_MAX) * multiplier))
			GameState.pending_earnings[student.id] = GameState.pending_earnings.get(student.id, 0) + earned

			student.mood = clampf(student.mood - WIRAUSAHA_MOOD_COST, 0.0, 100.0)
			student.energy = clampf(student.energy - WIRAUSAHA_ENERGY_COST, 0.0, 100.0)
			mood_loss += WIRAUSAHA_MOOD_COST
			energy_loss += WIRAUSAHA_ENERGY_COST
			activity_reason = " & Wirausaha (Rp%d)" % earned
			log_stat_change(day_name, student.student_name, "mood", -WIRAUSAHA_MOOD_COST, "activity")
			log_stat_change(day_name, student.student_name, "energy", -WIRAUSAHA_ENERGY_COST, "activity")
		elif category != "":
			# ... the existing base_gain / specialty_bonus block, unchanged
```

Also guard the stat-gain logging block below (line ~155) so it skips
`Wirausaha`, since `act_res` is never populated on that path:

```gdscript
		if category != "Istirahat" and category != "Wirausaha" and category != "":
```

- [ ] **Step 6: Run the tests and confirm they pass**

Run the `wirausaha` and `school_day` suites. Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd Scripts/GameState.gd tests/test_wirausaha.gd
git commit -m "feat(wirausaha): accrue daily earnings scaled by student energy"
```

---

## Task 14: Weekly payout and the day badge

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:531-580` (`_build_pill_badges_for_student`), `:1097` (`_on_week_complete`)
- Test: `tests/test_wirausaha.gd`

**Interfaces:**
- Consumes: `GameState.pending_earnings` (Task 13).
- Produces: `SchoolDay._pay_out_wirausaha() -> int`, returning the total paid.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_wirausaha.gd`:

```gdscript
func test_payout_adds_the_total_to_player_money() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings = {1: 300, 2: 250}
	var scene := (load("res://Scenes/SchoolSimulation/SchoolDay.tscn") as PackedScene).instantiate()
	var paid: int = scene._pay_out_wirausaha()
	assert_eq(paid, 550, "payout returns the summed total")
	assert_eq(GameState.player_money, original_money + 550, "money increases by the total")
	scene.free()
	GameState.pending_earnings.clear()
	GameState.player_money = original_money

func test_payout_clears_pending_earnings() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings = {1: 100}
	var scene := (load("res://Scenes/SchoolSimulation/SchoolDay.tscn") as PackedScene).instantiate()
	scene._pay_out_wirausaha()
	assert_true(GameState.pending_earnings.is_empty(),
		"earnings are paid once, then cleared")
	scene.free()
	GameState.player_money = original_money

func test_payout_of_nothing_is_zero_and_harmless() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings.clear()
	var scene := (load("res://Scenes/SchoolSimulation/SchoolDay.tscn") as PackedScene).instantiate()
	assert_eq(scene._pay_out_wirausaha(), 0, "no Wirausaha days pays nothing")
	assert_eq(GameState.player_money, original_money, "money is untouched")
	scene.free()

func test_week_complete_pays_out() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("_pay_out_wirausaha()"),
		"the weekly payout must be invoked at week completion")
```

- [ ] **Step 2: Run and confirm failure**

Run the `wirausaha` suite. Expected: FAIL — `_pay_out_wirausaha` not found.

- [ ] **Step 3: Implement the payout**

In `Scripts/SchoolSimulation/SchoolDay.gd`:

```gdscript
## Wirausaha pays weekly, not daily -- the week's accrued earnings across
## every assigned student land at once, so the player plans a week of
## trading stats for money rather than watching coins trickle in.
## Returns the total paid, for the summary line.
func _pay_out_wirausaha() -> int:
	var total: int = 0
	for student_id in GameState.pending_earnings:
		total += GameState.pending_earnings[student_id]
	GameState.pending_earnings.clear()
	if total > 0:
		GameState.player_money += total
	return total
```

- [ ] **Step 4: Call it at week completion**

In `_on_week_complete()` (line 1097), before the existing summary is
displayed:

```gdscript
	var wirausaha_total := _pay_out_wirausaha()
	if wirausaha_total > 0:
		AudioDirector.play_sfx(&"coin")
```

and add a line to the week summary showing
`"Pendapatan Wirausaha: Rp%d" % wirausaha_total`, styled with
`DesignTokens.load_default().category_color("Wirausaha")`. Follow the
existing summary-row construction in that function rather than inventing a
new layout.

- [ ] **Step 5: Add the day badge**

In `_build_pill_badges_for_student` (line 531), add a `Wirausaha` arm to
the match, alongside the existing `Akademis` / `SeniBudaya` / `Olahraga` /
`Istirahat` arms:

```gdscript
		"Wirausaha":
			_add_pill(hbox, "💰 Wirausaha", tokens.category_color("Wirausaha"))
```

- [ ] **Step 6: Run the tests and confirm they pass**

Run the `wirausaha` and `school_day` suites. Expected: all PASS.

- [ ] **Step 7: Verify in the running app**

Schedule a student for Wirausaha on two days, run the week, and confirm:
the day badge shows on those days, mood and energy drop, no academic stat
moves, and the lobby money display is higher after the week ends.

- [ ] **Step 8: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_wirausaha.gd
git commit -m "feat(wirausaha): pay accrued earnings out at the end of the week"
```

---

# Phase 4 — Report Card

## Task 15: Extract `StudentCardView`

`Scripts/StudentCard/student_card.gd` is 1916 lines. The report card needs
its rendering, not its approval flow. Extract rather than fork.

**Files:**
- Create: `Scripts/StudentCard/StudentCardView.gd`
- Modify: `Scripts/StudentCard/student_card.gd`
- Test: `tests/test_student_card.gd`

**Interfaces:**
- Consumes: `DesignTokens`, `StudentData` field names.
- Produces: `class_name StudentCardView` with static methods
  `populate(card: Control, student: Dictionary) -> void`,
  `build_stat_bars(card: Control, student: Dictionary) -> void`,
  `quirk_description(quirk: String) -> String`,
  `persona_description(persona: String) -> String`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_student_card.gd`:

```gdscript
func test_student_card_view_class_exists() -> void:
	assert_true(ResourceLoader.exists("res://Scripts/StudentCard/StudentCardView.gd"),
		"the shared card view must exist")

func test_quirk_descriptions_are_available_from_the_view() -> void:
	assert_true(StudentCardView.quirk_description("Kutu Buku") != "",
		"Kutu Buku must have a description")
	assert_true(StudentCardView.quirk_description("TidakAda") == "",
		"an unknown quirk yields an empty description, not an error")

func test_persona_descriptions_are_available_from_the_view() -> void:
	assert_true(StudentCardView.persona_description("Persona Tekun") != "",
		"Persona Tekun must have a description")

func test_student_card_delegates_to_the_view() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/student_card.gd")
	assert_true(src.contains("StudentCardView."),
		"student_card must consume the shared view, not duplicate it")

func test_tutorial_target_node_paths_are_unchanged() -> void:
	## The tutorial steps target node paths by string. The extraction must
	## not move any of them.
	var scene := (load("res://Scenes/StudentCard/student_card.tscn") as PackedScene).instantiate()
	for path in ["KertasMurid1/Kepribadian1", "KertasMurid1/KutuBuku"]:
		assert_true(scene.get_node_or_null(path) != null,
			"tutorial target must still resolve: " + path)
	scene.free()
```

- [ ] **Step 2: Run and confirm failure**

Run the `student_card` suite.
Expected: FAIL — `StudentCardView` is not a known identifier.

- [ ] **Step 3: Create `Scripts/StudentCard/StudentCardView.gd`**

Move — do not copy — these from `student_card.gd` into a
`class_name StudentCardView extends RefCounted` with static members:

- `QUIRK_DESCRIPTIONS` and `PERSONA_DESCRIPTIONS` (lines 14-30)
- the function that fills one `KertasMurid` from a student dictionary
  (the body around line 878-940)
- the stat-bar construction it calls

Add the two lookup helpers:

```gdscript
static func quirk_description(quirk: String) -> String:
	return QUIRK_DESCRIPTIONS.get(quirk, "")


static func persona_description(persona: String) -> String:
	return PERSONA_DESCRIPTIONS.get(persona, "")
```

`populate()` must take the card `Control` and the student `Dictionary` and
must not reach for anything on the calling scene. Node paths **inside** a
`KertasMurid` are unchanged; only the code's location moves.

- [ ] **Step 4: Point `student_card.gd` at the extracted view**

Replace the moved bodies with delegating calls. Delete the now-duplicated
constants. Everything else in the file — approval, stamping, the belajar
button, the tutorial, pagination — stays untouched.

- [ ] **Step 5: Run the tests and confirm nothing regressed**

Run the `student_card` suite. Expected: all PASS, including the
pre-existing tests.

- [ ] **Step 6: Verify in the running app**

Open the student card from the lobby. Confirm the cards render identically,
the tutorial still highlights the right nodes, approval still stamps, and
the belajar button still appears at the approval limit.

- [ ] **Step 7: Commit**

```bash
git add Scripts/StudentCard tests/test_student_card.gd
git commit -m "refactor(student-card): extract shared card rendering into StudentCardView"
```

---

## Task 16: The report card screen

**Files:**
- Create: `Scenes/ReportCard/report_card.tscn`, `Scripts/ReportCard/report_card.gd`
- Test: `tests/test_report_card.gd`

**Interfaces:**
- Consumes: `StudentCardView` (Task 15), `GameState.approved_students`.
- Produces: scene at `res://Scenes/ReportCard/report_card.tscn`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_report_card.gd`:

```gdscript
@tool
extends McpTestSuite

## Report card: a read-only student card viewer over approved_students.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "report_card"

const _SCENE_PATH := "res://Scenes/ReportCard/report_card.tscn"
const _SCRIPT_PATH := "res://Scripts/ReportCard/report_card.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "report_card.tscn must exist")
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "report_card.tscn must instantiate")
	scene.free()

func test_has_no_approve_buttons() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("Aprove", true, false) == null,
		"the report card is a viewer -- no approve button")
	scene.free()

func test_has_no_stamp() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("StampApprove", true, false) == null,
		"the report card is a viewer -- no approval stamp")
	scene.free()

func test_has_no_belajar_button() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("BelajarButton", true, false) == null,
		"the report card is a viewer -- no belajar button")
	scene.free()

func test_script_has_no_approval_logic() -> void:
	var src := _source()
	for symbol in ["_on_approve_pressed", "MAX_APPROVE", "_shift_approve_for_belajar", "_show_stamp_if_approved"]:
		assert_false(src.contains(symbol),
			"approval logic must not survive the derivation: " + symbol)

func test_script_has_no_tutorial() -> void:
	var src := _source()
	assert_false(src.contains("tutorial_steps"),
		"the report card has no tutorial")

func test_keeps_pagination_and_swipe() -> void:
	var src := _source()
	assert_true(src.contains("_transition_page"), "pagination is kept")
	assert_true(src.contains("_evaluate_swipe"), "swipe navigation is kept")

func test_pages_come_from_approved_students() -> void:
	assert_true(_source().contains("GameState.approved_students"),
		"the viewer reads the live roster, not the six-entry candidate list")

func test_delegates_rendering_to_the_shared_view() -> void:
	assert_true(_source().contains("StudentCardView."),
		"rendering is shared with student_card, not forked")

func test_back_button_returns_to_lobby() -> void:
	assert_true(_source().contains("res://Scenes/Lobby/loby.tscn"),
		"back must return to the lobby")
```

- [ ] **Step 2: Run and confirm failure**

Run the `report_card` suite. Expected: all FAIL — the scene does not exist.

- [ ] **Step 3: Derive the scene**

```bash
cd "C:/Users/Legion/Documents/KEJARTES/new-game-project"
mkdir -p Scenes/ReportCard Scripts/ReportCard
cp Scenes/StudentCard/student_card.tscn Scenes/ReportCard/report_card.tscn
cp Scripts/StudentCard/student_card.gd Scripts/ReportCard/report_card.gd
```

In `Scenes/ReportCard/report_card.tscn`:
- point the root's script at `res://Scripts/ReportCard/report_card.gd`,
- delete every `Aprove` node under each `KertasMurid`,
- delete the `StampApprove` node,
- delete the `BelajarButton` node,
- regenerate the scene `uid` (delete the `uid="..."` on the `gd_scene` line
  and let Godot assign a fresh one on first save).

- [ ] **Step 4: Strip the script down to a viewer**

In `Scripts/ReportCard/report_card.gd`, delete:
- `_on_approve_pressed`, `_show_stamp_if_approved`, `_reset_all_approve_positions`,
  `_reset_approve_position`, `_shift_approve_for_belajar`, `_on_belajar_pressed`
- the `approved`, `previously_approved_ids`, `approved_count`, `approve_shifted`
  variables and `MAX_APPROVE`
- the `stamp` and `belajar_button` `@onready` references and every use of them
  (including the branches inside `_transition_page`)
- the whole tutorial system: `tutorial_steps`, `_populate_default_tutorial_steps`,
  `_build_tutorial_panel`, `_start_prompt_blink`, `_position_tutorial_panel`,
  `_next_step`, `_show_step`, `_highlight_multiple`, `_clear_highlight`,
  `_end_tutorial`, `_get_button_display_name`, and the `TutorialArrow` preload

Keep: pagination (`_on_next_kanan_pressed`, `_on_next_kiri_pressed`,
`_transition_page`, `_update_nav_buttons`, `_update_page_label`), swipe
(`_input`, `_evaluate_swipe`), and the quirk/persona popups.

- [ ] **Step 5: Source the pages from the live roster**

Replace the hardcoded `student_data_list` (line 940) with:

```gdscript
## The viewer shows the students actually under the player's care, with
## whatever stats the most recent school day left them at -- not the
## six-entry candidate list student_card pages through.
var student_data_list: Array = []


func _load_roster() -> void:
	student_data_list = GameState.approved_students
	for i in kertas_murid.size():
		var has_student: bool = i < student_data_list.size()
		kertas_murid[i].visible = has_student and i == current_page
		if has_student:
			StudentCardView.populate(kertas_murid[i], student_data_list[i])
```

Call `_load_roster()` from `_ready()` and clamp `_update_nav_buttons` /
`_update_page_label` to `student_data_list.size()` rather than
`kertas_murid.size()`, so a 2-student roster shows "1 / 2".

- [ ] **Step 6: Keep the stats live**

Add to `_ready()`:

```gdscript
## approved_students is mutated in place by item use and by the school-day
## simulation, so an open card re-renders rather than showing a snapshot.
if not GameState.inventory_changed.is_connected(_refresh_current_page):
	GameState.inventory_changed.connect(_refresh_current_page)


func _refresh_current_page() -> void:
	if current_page < student_data_list.size():
		StudentCardView.populate(kertas_murid[current_page], student_data_list[current_page])
```

Also call `_refresh_current_page()` from `NOTIFICATION_WM_WINDOW_FOCUS_IN`
and at the end of `_transition_page`, so returning to the screen always
re-reads the roster.

- [ ] **Step 7: Point the back button at the lobby**

```gdscript
Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)
```

- [ ] **Step 8: Run the tests and confirm they pass**

Run the `report_card` and `student_card` suites. Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add Scenes/ReportCard Scripts/ReportCard tests/test_report_card.gd
git commit -m "feat(report-card): add a read-only live student card viewer"
```

---

## Task 17: Wire the report card button and verify end to end

**Files:**
- Modify: `Scripts/Lobby/loby.gd`
- Test: `tests/test_lobby.gd`

**Interfaces:**
- Consumes: the report card scene (Task 16).
- Produces: `_on_report_student_pressed()` on the lobby.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_lobby.gd`:

```gdscript
func test_report_student_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_report_student_pressed"),
		"the ReportStudent button must have a handler")
	assert_true(src.contains("res://Scenes/ReportCard/report_card.tscn"),
		"ReportStudent must route to the report card scene")
```

- [ ] **Step 2: Run and confirm failure**

Run the `lobby` suite. Expected: FAIL.

- [ ] **Step 3: Add the handler and connection**

Beside the Task 9 handlers:

```gdscript
func _on_report_student_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/ReportCard/report_card.tscn", Transition.Style.WIPE)
```

And in the same ungated connection block:

```gdscript
if not report_student_button.pressed.is_connected(_on_report_student_pressed):
	report_student_button.pressed.connect(_on_report_student_pressed)
```

- [ ] **Step 4: Run the whole test set**

Run every suite: `economy_state`, `koperasi`, `inventory`, `wirausaha`,
`report_card`, `lobby`, `student_card`, `atur_jadwal`, `school_day`,
`design_tokens`, `theme_factory`, plus the rest of `tests/`.
Expected: all PASS, no regressions.

- [ ] **Step 5: Full manual pass in the running app**

Walk the complete loop and confirm each step:

1. Lobby → Koperasi → shop opens, no in-shop inventory button → back → lobby.
2. Lobby → Inventory → inventory opens → back → lobby.
3. Atur Jadwal → assign a student to Wirausaha on two days.
4. Run the school week → Wirausaha badge shows on those days, mood and
   energy drop, no academic stat moves.
5. Week ends → money increases by the Wirausaha total, shown in the summary.
6. Lobby → Koperasi → buy an item → confirmation message shows.
7. Lobby → Inventory → the item is there → use it → pick a student → the
   stat pops show the real clamped deltas.
8. Lobby → Report Card → that student's mood/energy reflect the item use →
   swipe between pages → no approve button, no stamp, no belajar button →
   back → lobby.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Lobby/loby.gd tests/test_lobby.gd
git commit -m "fix(lobby): wire the dead ReportStudent button"
```

---

## Deferred

Recorded so they are not lost, but out of scope for this plan:

- **Wirausaha balance.** `WIRAUSAHA_EARN_MIN/MAX`, `WIRAUSAHA_ENERGY_FLOOR`, and the mood/energy costs are first-pass numbers. They live in one const block at the top of `StudentManager.gd` precisely so playtesting can retune them without touching logic.
- **Persistence.** Money and inventory vanish on quit, consistent with the rest of the game state but harsher for an economy.
- **Post-purchase feedback.** With the shop→inventory link removed, the shop's text confirmation is the only signal that a purchase landed. If playtest shows this is thin, the fix is a richer toast in the shop, not re-adding the cross-link.
- **Schedule popup density.** Five activity buttons in `Penjadwalan` is tighter than four. If it reads as cramped, that popup needs its own layout pass.
