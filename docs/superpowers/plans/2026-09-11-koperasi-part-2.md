# Koperasi Rework Part 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the Koperasi rework: a basket tray docked at the bottom of the
shelf screen, where bought items land and stand at their own heights with ×N
badges, over a Total + Beli row. Plus rim glow on press, the tests the spec
names, and Part 1's deferred minors.

**Architecture:** The tray becomes its own sub-scene, `BasketTray.tscn`, driven
by a `@tool` script that lays out `ReturSlot` instances by hand (no containers).
That makes layout synchronous, so tests can assert real positions and the item
flight can read its landing rect the moment the cart changes. `rakbarang_1.gd`
shrinks to glue: shelf buttons in, `Cart` changes and flight landings out to the
tray. The modal popup, its blur layer and the loose BELI/"Harga++" pair are
deleted.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite`/`McpTestSuiteCompat`
suites run through the Godot AI MCP `test_run` tool.

**Inputs:** spec `docs/superpowers/specs/2026-09-11-koperasi-rework-design.md`
(binding authority), handover `docs/superpowers/handover/2026-09-11-koperasi-part-2-handover.md`,
Part 1 ledger `docs/superpowers/handover/2026-09-11-koperasi-part-1-ledger.md`.

**Decisions taken with the user (2026-09-11), do not re-litigate:**
- **Docked tray.** Always visible at the bottom of the shelf screen. Items fly
  from the shelf into it and stand on its plank at their own heights. This
  deliberately changes where the flight lands and how landed items are placed,
  which the handover had fenced off. The split-arc tweens, the tumble,
  `_on_item_landed`'s bounce and floating text, and hold-to-remove keep their
  behaviour.
- **One Beli, in the tray.** The loose `Rak1/TextureButton` (BELI) and
  `Rak1/Label` ("Harga++") are removed; the tray's footer replaces them.

## Global Constraints

- No `theme_override_*` except layout-only constants (`separation`, `margin_*`).
  New looks are `ThemeFactory` variations, then a rebake of
  `Assets/Theme/kejartes_theme.tres` via `test_run(suite="theme_rebake")`.
- No visual built at runtime: static chrome in the `.tscn`, repeated slots as a
  `PackedScene`, responsive geometry in a `@tool` script with documented
  `@export` knobs. `tests/test_viewport_editability.gd`'s BASELINE only goes down.
- Every script: a `##` file header and a `##` line per `@export`
  (`tests/test_script_documentation.gd`).
- All UI text Indonesian; systems code English.
- New display-face label variations go on `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd`; body-face ones stay off it.
- Buttons land on the S/M/L height steps (`btn_h_s` 96, `btn_h_m` 128,
  `btn_h_l` 160) — `tests/test_button_geometry.gd`.
- A new `@export` on `DesignTokens` needs a full editor restart before its
  default is visible to `DesignTokens.load_default()`.
- An instanced scene's root under a plain `Control` loses its rect on load:
  the root is a bare anchor and a child carries the geometry (authoring guide,
  Pattern C).
- Suites are `@tool`, override `suite_name()`, and no test is a coroutine.
  Follow every `assert_not_null` with `if x == null: return`. Read a stylebox
  only after `assert_true(theme.has_stylebox(...))`. Load the baked theme with
  `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`.
- Balance values are untouched; `Cart`'s `×N` model and the ShopHub return
  path are untouched.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `Scripts/Design/DesignTokens.gd` | modify | New "Koperasi" colour tokens |
| `Scripts/Design/ThemeFactory.gd` | modify | Koperasi variations read tokens; add `TrayBadge`, `TrayBadgeLabel`, `TrayPlank` |
| `Scripts/Koperasi/PriceTag.gd` | modify | Wipe colour from tokens; drop the runtime mouse-filter pass |
| `Scenes/Koperasi/PriceTag.tscn` | modify | `mouse_filter = 2` authored on its four nodes |
| `Scenes/Koperasi/BasketTray.tscn` | create | The docked tray: surface, hint, emblem + count badge, items, plank, empty state, footer |
| `Scripts/Koperasi/BasketTray.gd` | create | `refresh()`, slot layout, landing rects, held landings, total text, buy signal |
| `Scenes/Koperasi/TraySlot.tscn` | create | One item standing in the tray: shadow, art, ×N badge |
| `Scripts/Koperasi/TraySlot.gd` | create | `bind()`, badge text, hold-to-return / tap gestures |
| `Scenes/Koperasi/ReturSlot.tscn`, `Scripts/Koperasi/ReturSlot.gd` | delete | Replaced by TraySlot (Task 5) |
| `Scripts/Inventory/Cart.gd` | modify | `static total_of()`; `get_total()` delegates to it |
| `Scenes/Koperasi/koprasi.tscn` | modify | Instance the tray; delete `Keranjang`, `BlurLayer`, `PopupLayer`, BELI, "Harga++"; move `BackButton`; `Glow` under each `BarangN` |
| `Assets/Images/Shop/UI/item_glow.tres` | create | Radial `GradientTexture2D` shared by the four `Glow` nodes |
| `Scripts/Koperasi/rakbarang_1.gd` | modify | Glue: cart → tray, flight target → tray slot, landing → `tray.land()` |
| `Scripts/Koperasi/koprasi.gd` | modify | Beli wired to the tray's button |
| `Scripts/Koperasi/ShelfItem.gd` | modify | Rim glow on `lift()`; `lift()` returns its `Tween` |
| `tests/test_basket_tray.gd` | create | Suite `basket_tray`: tray behaviour |
| `tests/test_koperasi_tray.gd` | modify | Tokens, slot, glow, price-tag and SVG tests; repoint Part 1 tests |
| `tests/test_rakbarang_blur_layer.gd` | delete | Its subject, the modal's blur chrome, is removed by design |
| `tests/test_viewport_editability.gd` | modify | `rakbarang_1.gd` BASELINE 2 → 1 |
| `tests/test_theme_factory.gd` | modify | `TrayBadgeLabel` on `DISPLAY_ROSTER` |

## How this plan is run

- **One editor, one bridge.** The Godot AI bridge is single-client, so only the
  controller runs `test_run`, `scene_*`, `node_*`, `project_run`. Implementers
  (subagents, if used) author `.gd`/test files only.
- **Scene edits go through the editor** (`scene_open` → `node_*` →
  `scene_save`), never by hand while it is attached. Scene work first, script
  work second; after every `scene_save`, `git diff HEAD -- '*.gd'` must show only
  files being edited.
- **A script edited from outside the editor** needs `script_patch` (or an
  editor restart) before `test_run` sees it. If `script_patch` reports
  `reloaded: false`, prove the file parses with
  `Godot_v4.6.2-stable_win64_console.exe --headless --path <project> --check-only --script <res path>`
  and restart the editor before any rebake.
- **Targeted runs** between tasks; a full `test_run` only at the milestones
  (end of Task 5 and end of Task 8), budgeting an editor restart after each.
- **Check `git status` after a full run** and revert `default_bus_layout.tres`.

---

## Task 1: The shop's colours become DesignTokens

Handover step 1. Small, and it forces the editor restart early rather than mid-flow.

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (insert before `@export_group("Radii")`)
- Modify: `Scripts/Design/ThemeFactory.gd` (`_add_koperasi_variations`)
- Modify: `Scripts/Koperasi/PriceTag.gd:38`
- Test: `tests/test_koperasi_tray.gd` (append)

**Interfaces:**
- Produces: `DesignTokens.koperasi_tag_fill`, `koperasi_tag_border`,
  `koperasi_tag_pressed_fill`, `koperasi_tag_pressed_border`,
  `koperasi_tag_disabled_fill`, `koperasi_tag_disabled_border`,
  `koperasi_tray_fill`, `koperasi_tray_rule` (all `Color`). Task 3 uses
  `koperasi_tray_rule` for the plank and the badge rim.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_koperasi_tray.gd`:

```gdscript
# ───────────────────────────────── Part 2: the shop's colours are tokens

## Every Koperasi stylebox, built from a throwaway token set, must follow the
## tokens. set() rather than assignment, so the test fails on its assertions
## (not a script error) while the tokens do not exist yet.
func test_koperasi_variations_read_their_colours_from_tokens() -> void:
	var t := DesignTokens.new()
	var picks := {
		"koperasi_tag_fill": Color("ff0000"),
		"koperasi_tag_border": Color("00ff00"),
		"koperasi_tag_pressed_fill": Color("0000ff"),
		"koperasi_tag_pressed_border": Color("ffff00"),
		"koperasi_tag_disabled_fill": Color("ff00ff"),
		"koperasi_tag_disabled_border": Color("00ffff"),
		"koperasi_tray_fill": Color("123456"),
		"koperasi_tray_rule": Color("654321"),
	}
	for key in picks:
		t.set(key, picks[key])
	var theme := ThemeFactory.build(t)
	var want := {
		"PriceTag": [Color("ff0000"), Color("00ff00")],
		"PriceTagPressed": [Color("0000ff"), Color("ffff00")],
		"PriceTagDisabled": [Color("ff00ff"), Color("00ffff")],
		"BasketTray": [Color("123456"), Color("654321")],
	}
	for variation in want:
		assert_true(theme.has_stylebox("panel", variation),
			"%s has no panel stylebox" % variation)
		if not theme.has_stylebox("panel", variation):
			continue
		var box := theme.get_stylebox("panel", variation) as StyleBoxFlat
		assert_eq(box.bg_color, want[variation][0], "%s fill follows its token" % variation)
		assert_eq(box.border_color, want[variation][1], "%s border follows its token" % variation)


func test_price_tag_wipe_colour_comes_from_a_token() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/PriceTag.gd")
	assert_false(src.contains("Color(\"#"),
		"the wipe colour must come from DesignTokens, not a hex literal")
	assert_true(src.contains("koperasi_tag_pressed_fill"),
		"the wipe paints the pressed-fill token")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="koperasi_tray", test_name="token")`
Expected: FAIL — "PriceTag fill follows its token" (the build still uses
`#639922`), and "the wipe colour must come from DesignTokens".

- [ ] **Step 3: Add the tokens** — in `DesignTokens.gd`, immediately before `@export_group("Radii")`:

```gdscript
@export_group("Koperasi")
## The price tag's resting pill (PriceTag). Bright green so a price reads as
## "you can buy this" against the shelf's warm wood.
@export var koperasi_tag_fill: Color = Color("639922")
## The resting pill's border (PriceTag).
@export var koperasi_tag_border: Color = Color("3B6D11")
## The dark green the buy wipe paints across the pill, and PriceTagPressed's fill.
@export var koperasi_tag_pressed_fill: Color = Color("2F5A0D")
## PriceTagPressed's border.
@export var koperasi_tag_pressed_border: Color = Color("173404")
## PriceTagDisabled's fill: the neutral grey of an item the player cannot afford.
@export var koperasi_tag_disabled_fill: Color = Color("B4B2A9")
## PriceTagDisabled's border.
@export var koperasi_tag_disabled_border: Color = Color("5F5E5A")
## The basket tray's cream surface (BasketTray).
@export var koperasi_tray_fill: Color = Color("FBEBC8")
## The tray's amber: its top rule, the plank items stand on, the ×N badge rim.
@export var koperasi_tray_rule: Color = Color("A86A1C")

```

- [ ] **Step 4: Read them in ThemeFactory** — in `_add_koperasi_variations`, replace each literal:

```gdscript
	rest.bg_color = tokens.koperasi_tag_fill
	rest.border_color = tokens.koperasi_tag_border
	rest.set_border_width_all(4)
	rest.set_corner_radius_all(tokens.radius_pill)
```
```gdscript
	pressed.bg_color = tokens.koperasi_tag_pressed_fill
	pressed.border_color = tokens.koperasi_tag_pressed_border
```
```gdscript
	disabled.bg_color = tokens.koperasi_tag_disabled_fill
	disabled.border_color = tokens.koperasi_tag_disabled_border
```
```gdscript
	tray.bg_color = tokens.koperasi_tray_fill
	tray.border_color = tokens.koperasi_tray_rule
	tray.border_width_top = 6
	tray.corner_radius_top_left = tokens.radius_lg
	tray.corner_radius_top_right = tokens.radius_lg
```

`radius_pill` renders the tag exactly as the old 40 did: both exceed half the
~68px pill height, and StyleBoxFlat clamps to it. The tray's top corners move
from 40 to `radius_lg` (36). Border widths and content margins stay literal,
as ResultCardPanel's and ScoreHudPanel's do.

- [ ] **Step 5: Paint the wipe from the token** — `PriceTag.gd` `_ready()`:

```gdscript
		_wipe.color = DesignTokens.load_default().koperasi_tag_pressed_fill
```

- [ ] **Step 6: Restart the editor, then rebake**

A new `@export` default is invisible to `load_default()` until restart. Save
nothing open, quit the editor, relaunch, then `test_run(suite="theme_rebake")`.
Expected `git diff --stat Assets/Theme/kejartes_theme.tres`: only the four
Koperasi styleboxes' corner radii change.

- [ ] **Step 7: Run to verify they pass**

Run: `test_run(suite="koperasi_tray")`, `test_run(suite="theme_factory")`
Expected: all pass, including Part 1's `test_price_tag_is_green_and_pressed_is_darker`.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Scripts/Design/ThemeFactory.gd Scripts/Koperasi/PriceTag.gd Assets/Theme/kejartes_theme.tres tests/test_koperasi_tray.gd
git commit -m "refactor(koperasi): read the shop's colours from DesignTokens"
```

---

## Task 2: BasketTray scene — surface, Total + Beli footer, empty state

Handover step 2. Builds the tray standalone; Task 4 docks it into the shop.

**Files:**
- Create: `Scenes/Koperasi/BasketTray.tscn`, `Scripts/Koperasi/BasketTray.gd`
- Modify: `Scripts/Inventory/Cart.gd` (`total_of`, `get_total`)
- Test: `tests/test_basket_tray.gd` (new suite `basket_tray`)

**Interfaces:**
- Produces: `class_name BasketTray` with `signal buy_pressed`,
  `refresh(entries: Dictionary) -> void` (entries shaped like `Cart.cart`:
  `item_name -> {"data": ItemData, "quantity": int}`),
  `get_total_text() -> String`, `get_beli_button() -> Button`,
  `static format_koin(amount: int) -> String`; `Cart.total_of(entries: Dictionary) -> int`.
- Node paths later tasks rely on: `Body`, `Body/Items`, `Body/EmptyState`,
  `Body/Hint`, `Body/Footer/TotalLabel`, `Body/Footer/BeliButton`.

- [ ] **Step 1: Write the failing suite** — create `tests/test_basket_tray.gd`:

```gdscript
@tool
extends McpTestSuiteCompat

## BasketTray (Koperasi Part 2): the tray docked at the bottom of the shelf
## screen. refresh() and the slot layout are plain synchronous code, so the
## tray is exercised live here with hand-made ItemData; the shop wiring is in
## test_koperasi_tray.gd. Suite is @tool and no test is a coroutine.

const _SCENE := "res://Scenes/Koperasi/BasketTray.tscn"


func suite_name() -> String:
	return "basket_tray"


func _item(item_name: String, price: int, size := Vector2(200, 250)) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.price = price
	item.display_size = size
	return item


func _entry(item: ItemData, quantity: int) -> Dictionary:
	return {"data": item, "quantity": quantity}


## A live tray in the editor's root, so @onready resolves. Null (after a
## recorded failure) when the scene does not exist yet.
func _tray() -> Node:
	var packed = load(_SCENE)
	assert_not_null(packed, "BasketTray.tscn missing")
	if packed == null:
		return null
	var tray = packed.instantiate()
	Engine.get_main_loop().root.add_child(tray)
	track(tray)
	return tray


func test_the_total_is_price_times_quantity_summed() -> void:
	assert_true(Cart.has_method("total_of"), "Cart.total_of exists")
	if not Cart.has_method("total_of"):
		return
	var entries := {
		"Susu Kotak": _entry(_item("Susu Kotak", 1000), 2),
		"Pop Ice": _entry(_item("Pop Ice", 400), 1),
	}
	assert_eq(Cart.total_of(entries), 2400, "2 x 1000 + 1 x 400")
	assert_eq(Cart.total_of({}), 0, "an empty cart costs nothing")


func test_the_footer_shows_the_total_in_koin() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({
		"Susu Kotak": _entry(_item("Susu Kotak", 1000), 2),
		"Pop Ice": _entry(_item("Pop Ice", 400), 1),
	})
	assert_eq(tray.get_total_text(), "Total: 2.400 koin")


func test_koin_amounts_group_thousands_with_dots() -> void:
	var tray = _tray()
	if tray == null:
		return
	assert_eq(tray.format_koin(0), "0")
	assert_eq(tray.format_koin(400), "400")
	assert_eq(tray.format_koin(2400), "2.400")
	assert_eq(tray.format_koin(1250000), "1.250.000")


func test_an_empty_tray_shows_its_empty_state() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({})
	assert_true(tray.get_node("Body/EmptyState").visible, "the empty state shows")
	assert_false(tray.get_node("Body/Hint").visible, "no hold-to-return hint over nothing")
	assert_eq(tray.get_total_text(), "Total: 0 koin")


func test_a_filled_tray_hides_its_empty_state() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({"Pop Ice": _entry(_item("Pop Ice", 400), 1)})
	assert_false(tray.get_node("Body/EmptyState").visible, "the empty state hides")
	assert_true(tray.get_node("Body/Hint").visible, "the hint explains hold-to-return")


func test_beli_emits_buy_pressed() -> void:
	var tray = _tray()
	if tray == null:
		return
	var heard := [false]
	tray.buy_pressed.connect(func() -> void: heard[0] = true)
	tray.get_beli_button().pressed.emit()
	assert_true(heard[0], "pressing Beli asks the shop to buy")


func test_the_tray_is_themed_not_overridden() -> void:
	var src := FileAccess.get_file_as_string(_SCENE)
	assert_true(src.contains("&\"BasketTray\""), "the surface wears BasketTray")
	assert_true(src.contains("tray_dots.png"), "the dot-grid tile")
	assert_true(src.contains("texture_repeat = 2"), "the tile repeats on the node")
	assert_true(src.contains("&\"PrimaryButtonM\""), "Beli is theme chrome at the M step")
	for banned in ["theme_override_colors", "theme_override_font_sizes", "theme_override_styles"]:
		assert_false(src.contains(banned), "no %s in the tray" % banned)
```

- [ ] **Step 2: Run to verify it fails**

Run: `filesystem_manage(op="scan")`, then `test_run(suite="basket_tray")`
Expected: every test FAILS — "BasketTray.tscn missing" / "Cart.total_of exists".

- [ ] **Step 3: One sum, in Cart** — replace `get_total()` in `Scripts/Inventory/Cart.gd`:

```gdscript
func get_total() -> int:
	return total_of(cart)

## Sum of price x quantity over Cart-shaped entries. Static so the basket
## tray can total exactly what it was handed -- one sum, never two.
static func total_of(entries: Dictionary) -> int:
	var total: int = 0
	for key in entries:
		total += entries[key]["data"].price * entries[key]["quantity"]
	return total
```

- [ ] **Step 4: Write the script** — create `Scripts/Koperasi/BasketTray.gd`:

```gdscript
@tool
class_name BasketTray
extends Control

## The koperasi basket tray, docked at the bottom of the shelf screen: the
## items the player has picked stand on its plank, and its footer carries the
## running total and the one Beli button.
##
## The root is a bare anchor (authoring guide, Pattern C); Body carries the
## geometry. refresh() is plain synchronous code, so tests drive it directly
## and the shop can read a slot's landing rect the moment the cart changes.

## Emitted when the player presses Beli. koprasi.gd owns the purchase.
signal buy_pressed

@onready var _items: Control = $Body/Items
@onready var _empty_state: Control = $Body/EmptyState
@onready var _hint: Label = $Body/Hint
@onready var _total_label: Label = $Body/Footer/TotalLabel
@onready var _beli_button: Button = $Body/Footer/BeliButton


func _ready() -> void:
	_ensure_nodes()
	if is_instance_valid(_beli_button) and not _beli_button.pressed.is_connected(_on_beli_pressed):
		_beli_button.pressed.connect(_on_beli_pressed)


## Redraws the tray from Cart-shaped entries:
## item_name -> {"data": ItemData, "quantity": int}.
func refresh(entries: Dictionary) -> void:
	_ensure_nodes()
	var empty := entries.is_empty()
	_empty_state.visible = empty
	_hint.visible = not empty
	_total_label.text = "Total: %s koin" % format_koin(Cart.total_of(entries))


## 2400 -> "2.400": Indonesian groups thousands with a dot.
static func format_koin(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


## Reads the footer. Exists so tests need not know node paths.
func get_total_text() -> String:
	_ensure_nodes()
	return _total_label.text


## The footer's Beli button, for the shop's press feedback.
func get_beli_button() -> Button:
	_ensure_nodes()
	return _beli_button


func _on_beli_pressed() -> void:
	buy_pressed.emit()


## Resolves @onready nodes when a method runs before _ready.
func _ensure_nodes() -> void:
	if not is_instance_valid(_items):
		_items = get_node_or_null("Body/Items")
	if not is_instance_valid(_empty_state):
		_empty_state = get_node_or_null("Body/EmptyState")
	if not is_instance_valid(_hint):
		_hint = get_node_or_null("Body/Hint")
	if not is_instance_valid(_total_label):
		_total_label = get_node_or_null("Body/Footer/TotalLabel")
	if not is_instance_valid(_beli_button):
		_beli_button = get_node_or_null("Body/Footer/BeliButton")
```

- [ ] **Step 5: Write the scene** — a brand-new file, so the editor holds no copy
of it and writing the text is safe. Create `Scenes/Koperasi/BasketTray.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Koperasi/BasketTray.gd" id="1_tray"]
[ext_resource type="Texture2D" path="res://Assets/Images/Shop/UI/tray_dots.png" id="2_dots"]
[ext_resource type="Texture2D" path="res://Assets/Images/Shop/UI/icon_keranjang_kosong.svg" id="3_empty"]

[node name="BasketTray" type="Control"]
mouse_filter = 2
script = ExtResource("1_tray")

[node name="Body" type="Control" parent="."]
layout_mode = 0
offset_left = 24.0
offset_top = 1243.0
offset_right = 1056.0
offset_bottom = 1803.0

[node name="Sheet" type="Panel" parent="Body"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
theme_type_variation = &"BasketTray"

[node name="Dots" type="TextureRect" parent="Body"]
texture_repeat = 2
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource("2_dots")
stretch_mode = 1

[node name="Hint" type="Label" parent="Body"]
visible = false
layout_mode = 0
offset_left = 28.0
offset_top = 16.0
offset_right = 820.0
offset_bottom = 56.0
theme_type_variation = &"CaptionLabel"
text = "Tahan barang untuk mengembalikan"

[node name="Items" type="Control" parent="Body"]
layout_mode = 0
offset_left = 28.0
offset_top = 64.0
offset_right = 1004.0
offset_bottom = 344.0
mouse_filter = 2

[node name="EmptyState" type="VBoxContainer" parent="Body"]
layout_mode = 0
offset_left = 336.0
offset_top = 96.0
offset_right = 696.0
offset_bottom = 312.0
theme_override_constants/separation = 16
alignment = 1

[node name="Icon" type="TextureRect" parent="Body/EmptyState"]
custom_minimum_size = Vector2(128, 128)
layout_mode = 2
texture = ExtResource("3_empty")
expand_mode = 1
stretch_mode = 5

[node name="Caption" type="Label" parent="Body/EmptyState"]
layout_mode = 2
theme_type_variation = &"CaptionLabel"
text = "Keranjang kosong"
horizontal_alignment = 1

[node name="Footer" type="HBoxContainer" parent="Body"]
layout_mode = 0
offset_left = 28.0
offset_top = 380.0
offset_right = 1004.0
offset_bottom = 508.0
theme_override_constants/separation = 24

[node name="TotalLabel" type="Label" parent="Body/Footer"]
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"TitleLabel"
text = "Total: 0 koin"
vertical_alignment = 1

[node name="BeliButton" type="Button" parent="Body/Footer"]
custom_minimum_size = Vector2(280, 128)
layout_mode = 2
theme_type_variation = &"PrimaryButtonM"
text = "Beli"
```

Body sits at `(24, 1243)`–`(1056, 1803)` in the shelf screen's space: Rak1
starts at global y 117, so the tray's bottom edge is the screen's (1920).
Then `filesystem_manage(op="scan")`, `scene_open` the new scene once and
`scene_save` so the editor stamps its uids, and check `git diff HEAD -- '*.gd'`.

- [ ] **Step 6: Run to verify it passes**

Run: `test_run(suite="basket_tray")`, then `button_geometry`,
`script_documentation`, `viewport_editability`.
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Scenes/Koperasi/BasketTray.tscn Scripts/Koperasi/BasketTray.gd Scripts/Koperasi/BasketTray.gd.uid Scripts/Inventory/Cart.gd tests/test_basket_tray.gd tests/test_basket_tray.gd.uid
git commit -m "feat(koperasi): the basket tray scene, its total and its Beli"
```

---

## Task 3: TraySlot — one item standing in the tray

A new scene rather than a rewrite of `ReturSlot` in place: `rakbarang_1.gd`
preloads `ReturSlot.tscn`, so the editor may hold it cached, and its root
type has to change (VBoxContainer → Control). `ReturSlot.*` is deleted in
Task 5, once nothing preloads it.

**Files:**
- Create: `Scenes/Koperasi/TraySlot.tscn`, `Scripts/Koperasi/TraySlot.gd`
- Modify: `Scripts/Design/ThemeFactory.gd` (`_add_koperasi_variations`)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`)
- Test: `tests/test_basket_tray.gd` (append)

**Interfaces:**
- Consumes: `DesignTokens.koperasi_tray_rule` (Task 1).
- Produces: `class_name TraySlot extends Control` with
  `signal remove_requested(item_name: String)`, `signal tapped(item_name: String)`,
  `bind(item: ItemData, quantity: int) -> void`, `set_quantity(quantity: int) -> void`,
  `get_badge_text() -> String`, `get_item_name() -> String`,
  `var natural_size: Vector2`, and
  `static classify_release(held_seconds: float, drift: float, hold_threshold: float, slop: float) -> StringName`
  returning `&"hold"`, `&"tap"` or `&"none"`. Theme variations `TrayBadge`
  (PanelContainer), `TrayBadgeLabel` (Label), `TrayPlank` (Panel).

- [ ] **Step 1: Write the failing tests** — append to `tests/test_basket_tray.gd`:

```gdscript
# ────────────────────────────────────────────── one item on the plank

const _SLOT := "res://Scenes/Koperasi/TraySlot.tscn"
const _THEME := "res://Assets/Theme/kejartes_theme.tres"


func _slot() -> Node:
	var packed = load(_SLOT)
	assert_not_null(packed, "TraySlot.tscn missing")
	if packed == null:
		return null
	var slot = packed.instantiate()
	Engine.get_main_loop().root.add_child(slot)
	track(slot)
	return slot


func test_a_slot_wears_its_quantity_as_a_badge() -> void:
	var slot = _slot()
	if slot == null:
		return
	slot.bind(_item("Raket", 1500, Vector2(180, 280)), 3)
	assert_eq(slot.get_badge_text(), "×3")
	slot.set_quantity(1)
	assert_eq(slot.get_badge_text(), "×1")


func test_a_slot_without_art_is_its_display_size() -> void:
	var slot = _slot()
	if slot == null:
		return
	slot.bind(_item("Raket", 1500, Vector2(180, 280)), 1)
	assert_eq(slot.natural_size, Vector2(180, 280))


func test_a_slots_width_follows_its_arts_aspect() -> void:
	var slot = _slot()
	if slot == null:
		return
	var item := _item("Pop Ice", 400, Vector2(160, 240))
	item.icon = ImageTexture.create_from_image(
		Image.create_empty(100, 300, false, Image.FORMAT_RGBA8))
	slot.bind(item, 1)
	assert_eq(slot.natural_size, Vector2(80, 240),
		"the display height, at the art's own 1:3 aspect")


func test_hold_and_tap_are_told_apart() -> void:
	var slot = _slot()
	if slot == null:
		return
	assert_eq(slot.classify_release(0.5, 5.0, 0.35, 30.0), &"hold")
	assert_eq(slot.classify_release(0.1, 5.0, 0.35, 30.0), &"tap")
	assert_eq(slot.classify_release(0.5, 50.0, 0.35, 30.0), &"none", "a drag is neither")


func test_a_right_click_returns_one_at_once() -> void:
	var slot = _slot()
	if slot == null:
		return
	slot.bind(_item("Raket", 1500), 2)
	var heard := [""]
	slot.remove_requested.connect(func(n: String) -> void: heard[0] = n)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	slot._gui_input(click)
	assert_eq(heard[0], "Raket")


func test_the_tray_badge_and_plank_are_baked() -> void:
	var theme := ResourceLoader.load(_THEME, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for variation in ["TrayBadge", "TrayPlank"]:
		assert_true(theme.has_stylebox("panel", variation), "%s is baked" % variation)
	assert_true(theme.get_type_list().has("TrayBadgeLabel"), "TrayBadgeLabel is baked")
	if theme.has_stylebox("panel", "TrayBadge"):
		var box := theme.get_stylebox("panel", "TrayBadge") as StyleBoxFlat
		assert_eq(box.border_color, DesignTokens.load_default().koperasi_tray_rule,
			"the badge rim is the tray's amber")


func test_the_badge_face_can_draw_the_times_sign() -> void:
	var theme := ResourceLoader.load(_THEME, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var font := theme.get_font("font", "TrayBadgeLabel")
	assert_true(font != null and font.has_char(0x00D7),
		"the badge's face has a × glyph -- if not, give TrayBadgeLabel the "
		+ "body face and take it off DISPLAY_ROSTER")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="basket_tray", test_name="slot")` and `test_name="baked"`
Expected: FAIL — "TraySlot.tscn missing", "TrayBadge is baked".

- [ ] **Step 3: Add the variations** — at the end of `_add_koperasi_variations`:

```gdscript
	# -- The ×N on a tray slot and the count on the basket emblem: a cream
	# pill with an amber rim, the tray's own colours. PanelContainer base,
	# because both badges are PanelContainers. --
	var badge := StyleBoxFlat.new()
	badge.bg_color = tokens.surface_card
	badge.border_color = tokens.koperasi_tray_rule
	badge.set_border_width_all(3)
	badge.set_corner_radius_all(tokens.radius_pill)
	badge.content_margin_left = 12
	badge.content_margin_right = 12
	badge.content_margin_top = 2
	badge.content_margin_bottom = 2
	theme.add_type("TrayBadge")
	theme.set_type_variation("TrayBadge", "PanelContainer")
	theme.set_stylebox("panel", "TrayBadge", badge)

	# Display face: CLAUDE.md gives badges Boohong. Body step, dark ink.
	theme.add_type("TrayBadgeLabel")
	theme.set_type_variation("TrayBadgeLabel", "Label")
	theme.set_font_size("font_size", "TrayBadgeLabel", tokens.font_body_size)
	theme.set_color("font_color", "TrayBadgeLabel", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "TrayBadgeLabel", tokens.font_display)

	# -- The plank the tray's items stand on: one amber rule. --
	var plank := StyleBoxFlat.new()
	plank.bg_color = tokens.koperasi_tray_rule
	plank.set_corner_radius_all(tokens.radius_sm)
	theme.add_type("TrayPlank")
	theme.set_type_variation("TrayPlank", "Panel")
	theme.set_stylebox("panel", "TrayPlank", plank)
```

Then add `TrayBadgeLabel` to `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`,
after the last entry:

```gdscript
	# 2026-09-11 Koperasi Part 2: the tray's ×N and count badges.
	"TrayBadgeLabel",
```

- [ ] **Step 4: Write the script** — create `Scripts/Koperasi/TraySlot.gd`:

```gdscript
@tool
class_name TraySlot
extends Control

## One item standing in the koperasi basket tray: its art at the item's own
## height, a soft shadow where it meets the plank, and a ×N badge on its
## corner. BasketTray sizes and places it; the slot only knows its own shape.
##
## Hold it to return one to the shelf -- the gesture the basket always had,
## moved here from rakbarang_1.gd's _on_item_icon_input when the tray
## replaced the basket popup. A right-click returns one at once.

## Emitted when the player holds the item long enough to return one.
signal remove_requested(item_name: String)
## Emitted on a quick tap, which the shop answers with a nudge.
signal tapped(item_name: String)

## Seconds a press must last to count as hold-to-return.
@export var hold_seconds: float = 0.35
## Pixels a finger may drift before a press counts as neither hold nor tap.
@export var hold_slop: float = 30.0
## Scale the item swells to while held -- the press feedback.
@export var hold_scale: float = 1.15

## The item's own size in the tray, before BasketTray fits the row.
var natural_size: Vector2 = Vector2(200.0, 200.0)

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Badge/Count

var _item_name: String = ""
var _press_msec: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _press_tween: Tween


## Fills the slot from a cart line. Height is the item's authored display
## height; width follows the art's own aspect, so the art fills the slot and
## its bottom edge is the item's foot on the plank.
func bind(item: ItemData, quantity: int) -> void:
	_ensure_nodes()
	_item_name = item.item_name
	_icon.texture = item.icon
	var h: float = item.display_size.y if item.display_size.y > 0.0 else 200.0
	var w: float = item.display_size.x if item.display_size.x > 0.0 else h
	if item.icon != null and item.icon.get_height() > 0:
		w = h * float(item.icon.get_width()) / float(item.icon.get_height())
	natural_size = Vector2(w, h)
	set_quantity(quantity)


## Updates the ×N badge.
func set_quantity(quantity: int) -> void:
	_ensure_nodes()
	_count.text = "×%d" % quantity


## Reads the badge. Exists so tests need not know node paths.
func get_badge_text() -> String:
	_ensure_nodes()
	return _count.text


## The cart key this slot shows.
func get_item_name() -> String:
	return _item_name


## What a released press meant: &"hold" returns one, &"tap" nudges, &"none"
## was a drag. Pure, so the gesture's rule is testable without waiting.
static func classify_release(held_seconds: float, drift: float,
		hold_threshold: float, slop: float) -> StringName:
	if drift >= slop:
		return &"none"
	return &"hold" if held_seconds >= hold_threshold else &"tap"


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		accept_event()
		remove_requested.emit(_item_name)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_begin_press(button.global_position)
		elif _press_msec >= 0:
			_end_press(button.global_position)


func _begin_press(at: Vector2) -> void:
	_press_msec = Time.get_ticks_msec()
	_press_pos = at
	pivot_offset = size / 2.0
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE * hold_scale, hold_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _end_press(at: Vector2) -> void:
	var held := (Time.get_ticks_msec() - _press_msec) / 1000.0
	_press_msec = -1
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	scale = Vector2.ONE
	match classify_release(held, _press_pos.distance_to(at), hold_seconds, hold_slop):
		&"hold":
			remove_requested.emit(_item_name)
		&"tap":
			tapped.emit(_item_name)


## Resolves @onready nodes when a method runs before _ready.
func _ensure_nodes() -> void:
	if not is_instance_valid(_icon):
		_icon = get_node_or_null("Icon")
	if not is_instance_valid(_count):
		_count = get_node_or_null("Badge/Count")
```

- [ ] **Step 5: Write the scene** — new file; create `Scenes/Koperasi/TraySlot.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Koperasi/TraySlot.gd" id="1_slot"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Placeholders/shadow_ellipse.png" id="2_shadow"]

[node name="TraySlot" type="Control"]
offset_right = 200.0
offset_bottom = 200.0
script = ExtResource("1_slot")

[node name="Shadow" type="TextureRect" parent="."]
modulate = Color(1, 1, 1, 0.35)
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 12.0
offset_top = -10.0
offset_right = -12.0
offset_bottom = 8.0
mouse_filter = 2
texture = ExtResource("2_shadow")
expand_mode = 1

[node name="Icon" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Badge" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -44.0
offset_top = -16.0
offset_right = 20.0
offset_bottom = 32.0
grow_horizontal = 0
mouse_filter = 2
theme_type_variation = &"TrayBadge"

[node name="Count" type="Label" parent="Badge"]
layout_mode = 2
theme_type_variation = &"TrayBadgeLabel"
text = "×1"
horizontal_alignment = 1
```

The root keeps Control's default `MOUSE_FILTER_STOP`: it is the hold target.
The root carries no `custom_minimum_size`, so BasketTray can size it freely.

- [ ] **Step 6: Rebake, scan, run to verify they pass**

Run: `test_run(suite="theme_rebake")`, `filesystem_manage(op="scan")`, then
`test_run(suite="basket_tray")`, `theme_factory`, `script_documentation`.
Expected: all pass. If `the_badge_face_can_draw_the_times_sign` fails, drop
the `set_font` line from `TrayBadgeLabel`, take it off `DISPLAY_ROSTER`,
rebake and re-run.

- [ ] **Step 7: Commit**

```bash
git add Scenes/Koperasi/TraySlot.tscn Scripts/Koperasi/TraySlot.gd Scripts/Koperasi/TraySlot.gd.uid Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd tests/test_basket_tray.gd
git commit -m "feat(koperasi): TraySlot, one item standing in the tray"
```

---

## Task 4: The row on the plank, and landings

Handover step 3, the layout itself. Slots are placed by hand: each at its own
size, bottoms on the plank line, the row centred, shrinking evenly when it
would not fit. A unit that is still flying in keeps its slot's place but stays
hidden until its flight lands.

**Files:**
- Modify: `Scenes/Koperasi/BasketTray.tscn` (add `Plank`, `Emblem`, `Emblem/CountBadge`, `Emblem/CountBadge/Count`) — through the editor
- Modify: `Scripts/Koperasi/BasketTray.gd` (full replacement below)
- Test: `tests/test_basket_tray.gd` (append)

**Interfaces:**
- Consumes: `TraySlot.bind/natural_size/remove_requested/tapped` (Task 3),
  `Cart.total_of` (Task 2).
- Produces, on `BasketTray`: `signal remove_requested(item_name: String)`,
  `signal slot_tapped(item_name: String)`, `hold_for_landing(item_name: String) -> void`,
  `land(item_name: String) -> Control`, `clear_held() -> void`,
  `landing_rect_for(item_name: String) -> Rect2`, `get_slot(item_name: String) -> TraySlot`,
  `get_emblem() -> Control`, `get_emblem_count_text() -> String`; exports
  `item_gap: float = 20.0`, `item_scale: float = 1.0`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_basket_tray.gd`:

```gdscript
# ───────────────────────────────────────────── the row on the plank

func _floor_of(tray) -> float:
	return tray.get_node("Body/Items").size.y


func test_items_stand_at_their_own_heights_on_the_plank() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({
		"Raket": _entry(_item("Raket", 1500, Vector2(180, 280)), 1),
		"Mie Instan": _entry(_item("Mie Instan", 700, Vector2(200, 200)), 1),
	})
	var raket: Control = tray.get_slot("Raket")
	var mie: Control = tray.get_slot("Mie Instan")
	assert_eq(raket.size.y, 280.0, "the racket at its own height")
	assert_eq(mie.size.y, 200.0, "the noodles at theirs")
	assert_eq(raket.position.y + raket.size.y, _floor_of(tray), "the racket stands on the plank")
	assert_eq(mie.position.y + mie.size.y, _floor_of(tray), "and so do the noodles")


func test_the_row_is_centred_on_the_plank() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({
		"Raket": _entry(_item("Raket", 1500, Vector2(180, 280)), 1),
		"Mie Instan": _entry(_item("Mie Instan", 700, Vector2(200, 200)), 1),
	})
	var room: float = tray.get_node("Body/Items").size.x
	var first: Control = tray.get_slot("Raket")
	var last: Control = tray.get_slot("Mie Instan")
	var left := first.position.x
	var right := room - (last.position.x + last.size.x)
	assert_true(absf(left - right) < 0.5, "equal margins: %s vs %s" % [left, right])


func test_a_crowded_row_shrinks_evenly_to_fit() -> void:
	var tray = _tray()
	if tray == null:
		return
	var entries := {}
	for i in 6:
		entries["Barang %d" % i] = _entry(_item("Barang %d" % i, 100, Vector2(240, 220)), 1)
	tray.refresh(entries)
	var room: float = tray.get_node("Body/Items").size.x
	var first: Control = tray.get_slot("Barang 0")
	var last: Control = tray.get_slot("Barang 5")
	assert_true(first.position.x >= -0.5, "the row starts on the plank")
	assert_true(last.position.x + last.size.x <= room + 0.5, "and ends on it")
	assert_true(absf(first.size.x / first.size.y - 240.0 / 220.0) < 0.01, "aspect kept")


func test_a_line_that_left_the_cart_leaves_the_row() -> void:
	var tray = _tray()
	if tray == null:
		return
	var raket := _entry(_item("Raket", 1500), 1)
	tray.refresh({"Raket": raket, "Pop Ice": _entry(_item("Pop Ice", 400), 1)})
	tray.refresh({"Raket": raket})
	assert_true(tray.get_slot("Pop Ice") == null, "the returned item's slot is gone")
	assert_true(tray.get_slot("Raket") != null, "the other stays")


func test_the_emblem_counts_every_unit() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({
		"Susu Kotak": _entry(_item("Susu Kotak", 1000), 2),
		"Pop Ice": _entry(_item("Pop Ice", 400), 1),
	})
	assert_eq(tray.get_emblem_count_text(), "3")
	assert_true(tray.get_node("Body/Emblem/CountBadge").visible, "the count shows")
	tray.refresh({})
	assert_false(tray.get_node("Body/Emblem/CountBadge").visible, "no count on an empty basket")


func test_a_unit_in_flight_is_hidden_until_it_lands() -> void:
	var tray = _tray()
	if tray == null:
		return
	var entries := {"Pop Ice": _entry(_item("Pop Ice", 400), 1)}
	tray.hold_for_landing("Pop Ice")
	tray.refresh(entries)
	var slot: Control = tray.get_slot("Pop Ice")
	assert_eq(slot.modulate.a, 0.0, "its place is kept, but it waits for the flight")
	assert_eq(tray.get_emblem_count_text(), "0", "not in the basket until it lands")
	tray.land("Pop Ice")
	assert_eq(slot.modulate.a, 1.0, "it shows the moment the item lands")
	assert_eq(slot.get_badge_text(), "×1")


func test_a_second_unit_in_flight_keeps_the_first_on_show() -> void:
	var tray = _tray()
	if tray == null:
		return
	var entries := {"Pop Ice": _entry(_item("Pop Ice", 400), 2)}
	tray.hold_for_landing("Pop Ice")
	tray.refresh(entries)
	var slot: Control = tray.get_slot("Pop Ice")
	assert_eq(slot.modulate.a, 1.0, "the first unit is already there")
	assert_eq(slot.get_badge_text(), "×1", "counting only what has landed")
	tray.land("Pop Ice")
	assert_eq(slot.get_badge_text(), "×2")


func test_clearing_held_units_shows_everything() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.hold_for_landing("Pop Ice")
	tray.clear_held()
	tray.refresh({"Pop Ice": _entry(_item("Pop Ice", 400), 1)})
	assert_eq(tray.get_slot("Pop Ice").modulate.a, 1.0)


func test_the_landing_rect_is_the_items_own_slot() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({"Raket": _entry(_item("Raket", 1500, Vector2(180, 280)), 1)})
	assert_eq(tray.landing_rect_for("Raket"), tray.get_slot("Raket").get_global_rect())


func test_a_slot_hold_reaches_the_tray() -> void:
	var tray = _tray()
	if tray == null:
		return
	tray.refresh({"Raket": _entry(_item("Raket", 1500), 1)})
	var heard := [""]
	tray.remove_requested.connect(func(n: String) -> void: heard[0] = n)
	tray.get_slot("Raket").remove_requested.emit("Raket")
	assert_eq(heard[0], "Raket", "the tray forwards a slot's hold")


func test_items_and_their_shadows_draw_over_the_plank() -> void:
	var tray = _tray()
	if tray == null:
		return
	var body: Node = tray.get_node("Body")
	var plank: Node = body.get_node_or_null("Plank")
	assert_true(plank is Panel, "a Plank panel")
	if plank == null:
		return
	assert_eq(String(plank.theme_type_variation), "TrayPlank")
	assert_true(plank.get_index() < body.get_node("Items").get_index(),
		"the plank draws first, so each item's shadow lands on it")


func test_a_line_that_keeps_units_comes_back_full_size() -> void:
	var tray = _tray()
	if tray == null:
		return
	var item := _item("Pop Ice", 400)
	tray.refresh({"Pop Ice": _entry(item, 2)})
	var slot: Control = tray.get_slot("Pop Ice")
	slot.scale = Vector2(0.1, 0.1)  # what a hold-to-return's shrink leaves behind
	tray.refresh({"Pop Ice": _entry(item, 1)})
	assert_eq(slot.scale, Vector2.ONE, "one left, and it stands at full size again")
	assert_eq(slot.get_badge_text(), "×1")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="basket_tray")`
Expected: the new tests FAIL — `get_slot` / `hold_for_landing` do not exist
yet ("Invalid call") and there is no `Plank`.

- [ ] **Step 3: Add the plank and the emblem** — through the editor
(`scene_open` BasketTray.tscn → `batch_execute` → `scene_save`), under `Body`:

| Node | Type | Properties |
|---|---|---|
| `Plank` | Panel | `layout_mode = 0`, offsets `(28, 344)`–`(1004, 356)`, `mouse_filter = 2`, `theme_type_variation = &"TrayPlank"`; move to index 2 (after `Dots`, before `Items`) |
| `Emblem` | TextureRect | `layout_mode = 0`, offsets `(876, -64)`–`(1004, 64)`, `mouse_filter = 2`, `texture = icon_keranjang.svg`, `expand_mode = 1`, `stretch_mode = 5`; last child of `Body` |
| `Emblem/CountBadge` | PanelContainer | `visible = false`, `layout_mode = 1`, `anchor_left = 1`, `anchor_right = 1`, offsets `(-40, -8)`–`(16, 40)`, `grow_horizontal = 0`, `mouse_filter = 2`, `theme_type_variation = &"TrayBadge"` |
| `Emblem/CountBadge/Count` | Label | `layout_mode = 2`, `theme_type_variation = &"TrayBadgeLabel"`, `text = "0"`, `horizontal_alignment = 1` |

The emblem overhangs the tray's top edge by half its height: the B3 basket
art sitting on the tray's rim. Then `git diff HEAD -- '*.gd'`.

- [ ] **Step 4: Replace the script** — `Scripts/Koperasi/BasketTray.gd` becomes:

```gdscript
@tool
class_name BasketTray
extends Control

## The koperasi basket tray, docked at the bottom of the shelf screen: the
## items the player has picked stand on its plank at their own heights, each
## with a ×N badge, and its footer carries the running total and the one
## Beli button.
##
## The root is a bare anchor (authoring guide, Pattern C); Body carries the
## geometry. Slots are placed by hand rather than by a container, so layout is
## synchronous: tests assert real positions, and the shop reads a slot's
## landing rect the moment the cart changes -- no frame of waiting.

## Emitted when the player presses Beli. koprasi.gd owns the purchase.
signal buy_pressed
## Emitted when the player holds a tray item to return one to the shelf.
signal remove_requested(item_name: String)
## Emitted on a quick tap on a tray item.
signal slot_tapped(item_name: String)

## Gap between two items on the plank, in pixels, before the row is fitted.
@export var item_gap: float = 20.0:
	set(value):
		item_gap = value
		if is_inside_tree():
			_layout_slots()

## Scale on every item's own size before the row is fitted to the plank.
## 1.0 keeps an item exactly as tall as its authored display size.
@export var item_scale: float = 1.0:
	set(value):
		item_scale = value
		if is_inside_tree():
			_layout_slots()

const SLOT_SCENE := preload("res://Scenes/Koperasi/TraySlot.tscn")

@onready var _items: Control = $Body/Items
@onready var _empty_state: Control = $Body/EmptyState
@onready var _hint: Label = $Body/Hint
@onready var _total_label: Label = $Body/Footer/TotalLabel
@onready var _beli_button: Button = $Body/Footer/BeliButton
@onready var _emblem: Control = $Body/Emblem
@onready var _emblem_badge: Control = $Body/Emblem/CountBadge
@onready var _emblem_count: Label = $Body/Emblem/CountBadge/Count

## item_name -> TraySlot, in the order the lines entered the cart.
var _slots: Dictionary = {}
## The entries last handed to refresh().
var _entries: Dictionary = {}
## item_name -> units bought but still flying in; refresh() hides them.
var _held: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()
	if is_instance_valid(_beli_button) and not _beli_button.pressed.is_connected(_on_beli_pressed):
		_beli_button.pressed.connect(_on_beli_pressed)


## Redraws the tray from Cart-shaped entries:
## item_name -> {"data": ItemData, "quantity": int}.
func refresh(entries: Dictionary) -> void:
	_ensure_nodes()
	_entries = entries
	for item_name in _slots.keys():
		if not entries.has(item_name):
			var gone: Node = _slots[item_name]
			_slots.erase(item_name)
			gone.queue_free()
	var shown_units := 0
	for item_name in entries:
		var slot: TraySlot = _slots.get(item_name)
		if slot == null:
			slot = SLOT_SCENE.instantiate()
			_items.add_child(slot)
			slot.remove_requested.connect(_on_slot_remove_requested)
			slot.tapped.connect(_on_slot_tapped)
			_slots[item_name] = slot
		var shown := int(entries[item_name]["quantity"]) - int(_held.get(item_name, 0))
		slot.bind(entries[item_name]["data"], maxi(shown, 1))
		# A hold-to-return shrinks the slot before the cart hears of it; a
		# line that still has units must come back at full size.
		slot.scale = Vector2.ONE
		slot.modulate.a = 1.0 if shown > 0 else 0.0
		shown_units += maxi(shown, 0)
	_layout_slots()
	var empty := entries.is_empty()
	_empty_state.visible = empty
	_hint.visible = not empty
	_emblem_count.text = str(shown_units)
	_emblem_badge.visible = shown_units > 0
	_total_label.text = "Total: %s koin" % format_koin(Cart.total_of(entries))


## Call BEFORE Cart.add_item(): the refresh that follows keeps the new unit
## hidden until land() says its flight has arrived.
func hold_for_landing(item_name: String) -> void:
	_held[item_name] = int(_held.get(item_name, 0)) + 1


## One unit of item_name has landed: show it and pop its slot. Returns the
## slot, or null if the line left the cart mid-flight.
func land(item_name: String) -> Control:
	if _held.has(item_name):
		_held[item_name] -= 1
		if _held[item_name] <= 0:
			_held.erase(item_name)
	refresh(_entries)
	var slot: TraySlot = _slots.get(item_name)
	if slot != null and slot.is_inside_tree():
		AnimUtils.spawn_pop(slot)
	return slot


## Forgets every unit still in flight -- the cart was bought or emptied.
func clear_held() -> void:
	_held.clear()


## Where a unit of item_name lands, in global coordinates: its slot's rect,
## or the whole row while the line has no slot.
func landing_rect_for(item_name: String) -> Rect2:
	_ensure_nodes()
	var slot: TraySlot = _slots.get(item_name)
	if slot == null:
		return _items.get_global_rect()
	return slot.get_global_rect()


## The slot showing item_name, or null.
func get_slot(item_name: String) -> TraySlot:
	return _slots.get(item_name)


## The basket emblem, which bounces when an item lands.
func get_emblem() -> Control:
	_ensure_nodes()
	return _emblem


## Reads the emblem's unit count. Exists so tests need not know node paths.
func get_emblem_count_text() -> String:
	_ensure_nodes()
	return _emblem_count.text


## 2400 -> "2.400": Indonesian groups thousands with a dot.
static func format_koin(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


## Reads the footer. Exists so tests need not know node paths.
func get_total_text() -> String:
	_ensure_nodes()
	return _total_label.text


## The footer's Beli button, for the shop's press feedback.
func get_beli_button() -> Button:
	_ensure_nodes()
	return _beli_button


## Places every slot on the plank: each at its own size (times item_scale),
## bottoms on the plank line, the row centred. A row wider than the plank, or
## an item taller than the room above it, shrinks evenly to fit.
func _layout_slots() -> void:
	_ensure_nodes()
	var order: Array = _slots.keys()
	if order.is_empty():
		return
	var room: Vector2 = _items.size
	var row_w := item_gap * float(order.size() - 1)
	var tallest := 0.0
	for item_name in order:
		var s: Vector2 = _slots[item_name].natural_size * item_scale
		row_w += s.x
		tallest = maxf(tallest, s.y)
	var fit := 1.0
	if row_w > room.x:
		fit = room.x / row_w
	if tallest * fit > room.y:
		fit = room.y / tallest
	var x := (room.x - row_w * fit) / 2.0
	for item_name in order:
		var slot: TraySlot = _slots[item_name]
		var s: Vector2 = slot.natural_size * item_scale * fit
		slot.size = s
		slot.position = Vector2(x, room.y - s.y)
		x += s.x + item_gap * fit


func _on_beli_pressed() -> void:
	buy_pressed.emit()


func _on_slot_remove_requested(item_name: String) -> void:
	remove_requested.emit(item_name)


func _on_slot_tapped(item_name: String) -> void:
	slot_tapped.emit(item_name)


## Resolves @onready nodes when a method runs before _ready.
func _ensure_nodes() -> void:
	if not is_instance_valid(_items):
		_items = get_node_or_null("Body/Items")
	if not is_instance_valid(_empty_state):
		_empty_state = get_node_or_null("Body/EmptyState")
	if not is_instance_valid(_hint):
		_hint = get_node_or_null("Body/Hint")
	if not is_instance_valid(_total_label):
		_total_label = get_node_or_null("Body/Footer/TotalLabel")
	if not is_instance_valid(_beli_button):
		_beli_button = get_node_or_null("Body/Footer/BeliButton")
	if not is_instance_valid(_emblem):
		_emblem = get_node_or_null("Body/Emblem")
	if not is_instance_valid(_emblem_badge):
		_emblem_badge = get_node_or_null("Body/Emblem/CountBadge")
	if not is_instance_valid(_emblem_count):
		_emblem_count = get_node_or_null("Body/Emblem/CountBadge/Count")
```

Removed slots are `queue_free`d, not freed: a slot's own hold can trigger the
refresh that removes it, and freeing a node inside its own signal crashes.

- [ ] **Step 5: Reload, run to verify they pass**

The script was replaced from outside the editor, so force the reload first (a
`script_patch` on it, or an editor restart). Then:
Run: `test_run(suite="basket_tray")`, `script_documentation`, `viewport_editability`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Koperasi/BasketTray.tscn Scripts/Koperasi/BasketTray.gd tests/test_basket_tray.gd
git commit -m "feat(koperasi): items stand at their own heights on the tray's plank"
```

---

## Task 5: Dock the tray into the shop — then the mentor review

Handover steps 3–4 in the running game. The modal popup, its blur and popup
layers, the basket art block and the loose BELI/"Harga++" pair all go; the
tray is instanced in their place and the shelf script becomes glue.

**Files:**
- Modify: `Scenes/Koperasi/koprasi.tscn` — through the editor
- Modify: `Scripts/Koperasi/rakbarang_1.gd` (full replacement), `Scripts/Koperasi/koprasi.gd` (`_setup_beli_button`)
- Delete: `Scenes/Koperasi/ReturSlot.tscn`, `Scripts/Koperasi/ReturSlot.gd`, `Scripts/Koperasi/ReturSlot.gd.uid`, `tests/test_rakbarang_blur_layer.gd`, `tests/test_rakbarang_blur_layer.gd.uid`
- Modify: `tests/test_koperasi_tray.gd`, `tests/test_viewport_editability.gd`

**Interfaces:**
- Consumes: everything `BasketTray` produces (Tasks 2 and 4).
- Produces: `rakbarang_1.gd`'s `tray` (`@onready`, the `BasketTray` instance at
  `Rak1/BasketTray`) and `clear_basket_visuals()` (kept: `koprasi.gd` calls it).

- [ ] **Step 1: Write the failing tests** — in `tests/test_koperasi_tray.gd`,
delete `test_retur_slot_scene_exists` and `test_retur_slot_binds_name_and_quantity`
(TraySlot's own tests cover the slot now), replace
`test_tray_panel_uses_the_basket_tray_variation` and
`test_shop_shows_a_scene_empty_state_not_a_built_label` with the versions
below, and add the three new tests:

```gdscript
const TRAY_SCENE := "res://Scenes/Koperasi/BasketTray.tscn"


func test_tray_panel_uses_the_basket_tray_variation() -> void:
	var shop := FileAccess.get_file_as_string("res://Scenes/Koperasi/koprasi.tscn")
	var tray := FileAccess.get_file_as_string(TRAY_SCENE)
	assert_true(shop.contains("res://Scenes/Koperasi/BasketTray.tscn"),
		"the shop docks the basket tray scene")
	assert_true(tray.contains("BasketTray"), "the tray surface carries the BasketTray variation")
	assert_true(tray.contains("tray_dots.png"), "tray should wear the dot-grid tile")
	assert_true(tray.contains("icon_keranjang.svg"), "the tray's emblem is the B3 basket")
	assert_false(shop.contains("pngwing.com (6).png") or tray.contains("pngwing.com (6).png"),
		"the black basket silhouette should no longer be referenced")
	assert_true(tray.contains("EmptyState"), "the empty-basket state is a scene node")
	assert_true(tray.contains("texture_repeat = 2"),
		"the dot tile must set texture_repeat on the node -- in Godot 4 "
		+ "repeat is a CanvasItem property, not a texture import flag")


## The empty state is the tray scene's own node; BasketTray.gd never builds a
## Label. Its behaviour is exercised live in test_basket_tray.gd.
func test_shop_shows_a_scene_empty_state_not_a_built_label() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/BasketTray.gd")
	assert_true(src.contains("_empty_state"), "the tray shows its scene EmptyState")
	assert_false(src.contains("Label.new()"), "empty state must not be built as a runtime Label")


func test_the_docked_tray_replaced_the_modal() -> void:
	var shop := FileAccess.get_file_as_string("res://Scenes/Koperasi/koprasi.tscn")
	for gone in ["name=\"ReturPanel\"", "name=\"PopupLayer\"", "name=\"BlurLayer\"",
			"name=\"Keranjang\"", "text = \"Harga++\"", "text = \"BELI\""]:
		assert_false(shop.contains(gone), "koprasi.tscn still carries %s" % gone)


func test_the_flight_lands_on_the_items_tray_slot() -> void:
	var src := _rak_source()
	assert_true(src.contains("tray.landing_rect_for(item.item_name)"),
		"the arc's target is the item's own tray slot")
	assert_true(src.contains("tray.land(item.item_name)"), "landing shows the unit in the tray")
	var hold := src.find("tray.hold_for_landing(item.item_name)")
	var add := src.find("Cart.add_item(item)")
	assert_true(hold != -1 and add != -1 and hold < add,
		"the unit is held before the cart hears of it, so it cannot pop in early")


## The mentor approved the flight itself; Part 2 moves only its target. A
## regression guard: it passes before this task and must still pass after.
func test_the_approved_flight_is_unchanged() -> void:
	var src := _rak_source()
	for line in [
		"var duplikat = TextureRect.new()",
		"tween_property(duplikat, \"global_position:x\", target_pos.x, 0.45)",
		"tween_property(duplikat, \"global_position:y\", mid_y, 0.14)",
		"tween_property(duplikat, \"global_position:y\", target_pos.y, 0.31)",
		"randf_range(-20.0, 20.0)",
	]:
		assert_true(src.contains(line), "the flight lost: %s" % line)
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="koperasi_tray")`
Expected: FAIL — "the shop docks the basket tray scene", "koprasi.tscn still
carries name=\"ReturPanel\"", "the arc's target is the item's own tray slot".
`test_the_approved_flight_is_unchanged` passes (it is the guard).

- [ ] **Step 3: Scene surgery** — `scene_open` koprasi.tscn, then under `Rak1`:

| Action | Node |
|---|---|
| delete | `Keranjang` (and its whole subtree: `BasketArea`, `KeranjangDepan`, `ReturPanel`…) |
| delete | `TextureButton` (the loose BELI) and `Label` ("Harga++") |
| delete | `BlurLayer` and `PopupLayer` |
| instance | `res://Scenes/Koperasi/BasketTray.tscn` as `BasketTray`, last child of `Rak1` |
| move | `BackButton` offsets to `(24, 1040)`–`(209, 1225)`, above the tray's left end |

`scene_save`, then `git diff HEAD -- '*.gd'` (only files being edited may
appear). The editor drops the now-unused ext_resources on save.

- [ ] **Step 4: Replace the shelf script** — `Scripts/Koperasi/rakbarang_1.gd` becomes:

```gdscript
extends Control  # script Rak1

## The koperasi shelf screen (koprasi.tscn:Rak1): four random items on the
## shelf, each with a coin-pill price tag and a little life, and the basket
## tray docked beneath them.
##
## Tapping an item puts one in Cart and flies a copy of its art, in the
## mentor-approved split arc, onto that item's own slot in the tray. The tray
## (BasketTray.tscn) redraws itself from Cart; this script only wires the
## shelf, the flight and the hold-to-return gesture to it.

@export_group("Global Settings")
## Global scale multiplier for all items (1.0 = normal)
@export var global_item_scale: float = 1.0

## The basket tray docked at the bottom of the shelf screen.
@onready var tray: BasketTray = $BasketTray

var shelf_buttons: Array[TextureButton] = []
var item_data_list: Array[ItemData] = []

## Instanced PriceTag per shelf button, parallel to shelf_buttons.
var _price_tags: Array = []

const PRICE_TAG_SCENE := preload("res://Scenes/Koperasi/PriceTag.tscn")
const ShelfItemScript := preload("res://Scripts/Koperasi/ShelfItem.gd")

## ShelfItem helper per shelf button, parallel to shelf_buttons.
var _shelf_items: Array = []

func _ready():
	setup_random_items()

	if not Cart.cart_changed.is_connected(_on_cart_changed):
		Cart.cart_changed.connect(_on_cart_changed)
	if not GameState.money_changed.is_connected(_on_money_changed_refresh):
		GameState.money_changed.connect(_on_money_changed_refresh)
	if is_instance_valid(tray):
		if not tray.remove_requested.is_connected(_on_tray_remove_requested):
			tray.remove_requested.connect(_on_tray_remove_requested)
		if not tray.slot_tapped.is_connected(_on_tray_slot_tapped):
			tray.slot_tapped.connect(_on_tray_slot_tapped)
	_on_cart_changed()

func _find_shelf_buttons():
	shelf_buttons.clear()
	for child in get_children():
		if child is TextureButton and child.name.begins_with("Barang"):
			shelf_buttons.append(child)
	shelf_buttons.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)

func setup_random_items():
	_find_shelf_buttons()
	if shelf_buttons.is_empty():
		return

	item_data_list = ItemDatabase.get_random_items(shelf_buttons.size())

	_shelf_items.clear()
	for i in range(shelf_buttons.size()):
		var btn = shelf_buttons[i]
		if i < item_data_list.size():
			var item = item_data_list[i]
			btn.show()
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
		else:
			btn.hide()

	_price_tags.clear()
	for btn in shelf_buttons:
		_price_tags.append(btn.get_node_or_null("PriceTag"))
	_refresh_affordability()

func _find_price_display(btn: TextureButton) -> Node:
	for child in btn.get_children():
		if child is Button or child is Label:
			return child
	return null

## Returns the PriceTag under a shelf button, instancing it on first use
## and freeing whatever placeholder label or button the scene shipped with.
func _ensure_price_tag(btn: TextureButton) -> Node:
	var existing = btn.get_node_or_null("PriceTag")
	if existing:
		return existing
	var legacy = _find_price_display(btn)
	if legacy:
		legacy.queue_free()
	var tag = PRICE_TAG_SCENE.instantiate()
	tag.name = "PriceTag"
	btn.add_child(tag)
	return tag

## Returns the ShelfItem helper under a shelf button, instancing it on first
## use and re-attaching it (re-sampling the resting position) otherwise, so
## repeated calls to setup_random_items() never pile up extra helper nodes.
func _ensure_shelf_item(btn: TextureButton) -> Node:
	var existing = btn.get_node_or_null("ShelfItem")
	if existing:
		existing.attach_to(btn)
		return existing
	var life = ShelfItemScript.new()
	life.name = "ShelfItem"
	btn.add_child(life)
	life.attach_to(btn)
	return life

## Greys out tags for items the player cannot currently afford.
func _refresh_affordability() -> void:
	for i in range(_price_tags.size()):
		var tag = _price_tags[i]
		if not is_instance_valid(tag) or i >= item_data_list.size():
			continue
		tag.set_affordable(GameState.player_money >= item_data_list[i].price)
		if i < _shelf_items.size() and is_instance_valid(_shelf_items[i]):
			_shelf_items[i].set_dimmed(GameState.player_money < item_data_list[i].price)

## Returns the display size for an item. Uses ItemData.display_size, falls back to source button size or default.
func get_item_effective_size(item: ItemData, source_button: TextureButton = null) -> Vector2:
	if item.display_size != Vector2.ZERO:
		return item.display_size * global_item_scale
	if source_button != null and source_button.size != Vector2.ZERO:
		return source_button.size * global_item_scale
	return Vector2(200, 200) * global_item_scale

## GameState.money_changed passes the new amount; affordability recomputes
## from GameState directly, so the argument is unused.
func _on_money_changed_refresh(_new_amount: int) -> void:
	_refresh_affordability()

## Cart.cart_changed: the tray redraws from the cart itself.
func _on_cart_changed() -> void:
	if is_instance_valid(tray):
		tray.refresh(Cart.cart)

func _on_barang_pressed(index: int):
	if index < 0 or index >= item_data_list.size():
		return
	var item = item_data_list[index]
	var btn = shelf_buttons[index]

	AnimUtils.squash_bounce(btn)
	if index < _price_tags.size() and is_instance_valid(_price_tags[index]):
		_price_tags[index].play_buy()
	if index < _shelf_items.size() and is_instance_valid(_shelf_items[index]):
		_shelf_items[index].lift()
	AudioDirector.play_sfx(&"tap")

	# Hold the unit before the cart hears of it: the refresh that
	# Cart.add_item() triggers then keeps it hidden until its flight lands.
	tray.hold_for_landing(item.item_name)
	Cart.add_item(item)
	_spawn_falling_item(btn, item)

func _spawn_falling_item(source_button: TextureButton, item: ItemData):
	if not is_instance_valid(tray):
		push_warning("BasketTray tidak ditemukan!")
		return

	# Use exact size configured in ItemData
	var item_size: Vector2 = get_item_effective_size(item, source_button)

	var duplikat = TextureRect.new()
	duplikat.texture = item.icon
	duplikat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	duplikat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	duplikat.size = item_size
	duplikat.custom_minimum_size = item_size
	duplikat.pivot_offset = item_size / 2
	duplikat.global_position = source_button.global_position + (source_button.size - item_size) / 2

	get_tree().current_scene.add_child(duplikat)

	var start_pos = duplikat.global_position
	# Land centred on the item's own slot in the tray.
	var slot_rect: Rect2 = tray.landing_rect_for(item.item_name)
	var target_pos = slot_rect.position + (slot_rect.size - item_size) / 2

	# Playful arc trajectory + tumble
	var tween_x = create_tween()
	tween_x.tween_property(duplikat, "global_position:x", target_pos.x, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	var tween_y = create_tween()
	var mid_y = min(start_pos.y, target_pos.y) - 50.0
	tween_y.tween_property(duplikat, "global_position:y", mid_y, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(duplikat, "global_position:y", target_pos.y, 0.31)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var tween_rot = create_tween()
	var tumble_angle = randf_range(-20.0, 20.0)
	tween_rot.tween_property(duplikat, "rotation_degrees", tumble_angle, 0.45)

	tween_y.tween_callback(_on_item_landed.bind(duplikat, item, item_size, target_pos))

func _on_item_landed(flying_node: Node, item: ItemData, item_size: Vector2, land_pos: Vector2 = Vector2.ZERO):
	flying_node.queue_free()
	tray.land(item.item_name)
	AnimUtils.basket_bounce(tray.get_emblem())
	AudioDirector.play_sfx(&"pop")
	AnimUtils.create_floating_text(
		get_tree().current_scene,
		"+1 " + item.item_name,
		land_pos + item_size / 2,
		Color(1.0, 0.9, 0.2)
	)

## A tray item was held: shrink it away, then return one to the shelf.
func _on_tray_remove_requested(item_name: String) -> void:
	AnimUtils.cart_press(tray.get_emblem())
	AudioDirector.play_sfx(&"pop")
	var slot: Control = tray.get_slot(item_name)
	if slot == null or not slot.is_inside_tree():
		Cart.remove_one(item_name)
		return
	var tween := AnimUtils.shrink_and_fade(slot)
	tween.tween_callback(Cart.remove_one.bind(item_name))

## A quick tap on a tray item: a wobble says "hold me" without words.
func _on_tray_slot_tapped(item_name: String) -> void:
	var slot: Control = tray.get_slot(item_name)
	if slot != null:
		AnimUtils.wobble(slot)

## Beli and Back empty the cart (the tray redraws from Cart.cart_changed);
## this forgets any unit still flying in. Kept by name: koprasi.gd calls it.
func clear_basket_visuals():
	if is_instance_valid(tray):
		tray.clear_held()
```

- [ ] **Step 5: Beli comes from the tray** — `Scripts/Koperasi/koprasi.gd`:

```gdscript
func _setup_beli_button():
	# Beli lives in the basket tray's footer.
	var tray = rak1_panel.get_node_or_null("BasketTray")
	if tray == null:
		return
	beli_button = tray.get_beli_button()
	if not tray.buy_pressed.is_connected(_on_beli_pressed):
		tray.buy_pressed.connect(_on_beli_pressed)
```

- [ ] **Step 6: Delete what the tray replaced, and turn the ratchet**

Delete `Scenes/Koperasi/ReturSlot.tscn`, `Scripts/Koperasi/ReturSlot.gd(.uid)`,
`tests/test_rakbarang_blur_layer.gd(.uid)` (its subject, the modal's blur
chrome, is gone; its one surviving pin, the `duplikat` construction, moved into
`test_the_approved_flight_is_unchanged`). Then `grep -rn icon_retur` outside
`.godot/`: if nothing references it, delete `Assets/Images/Shop/UI/icon_retur.svg(.import)`
and drop it from CLAUDE.md's placeholder list. In
`tests/test_viewport_editability.gd` set
`"res://Scripts/Koperasi/rakbarang_1.gd": 1,` — only the flying `duplikat`
remains. `filesystem_manage(op="scan")`; restart the editor (scripts were
replaced and files deleted from outside it).

- [ ] **Step 7: Run to verify they pass**

Run: `koperasi_tray`, `basket_tray`, `koperasi`, `viewport_editability`,
`button_geometry`, `script_documentation`.
Expected: all pass.

- [ ] **Step 8: Verify in the running game**

`project_run(mode="custom", scene="res://Scenes/Koperasi/koprasi.tscn")`. In
one `game_eval`: `GameState.player_money = 5000`, press `TextureRect/Rak1`,
then call `$Rak1._on_barang_pressed(0)` twice and `(1)` once; loop on
`await get_tree().process_frame` until item 1's slot shows `×1`; set
`Engine.time_scale = 0`. Screenshot at full size (`max_resolution=0`). Check:
two items stand on the plank at their own heights, badges `×2` and `×1`, the
emblem reads `3`, the footer reads the right total, BackButton clears the tray.
Then a real tap: send a `motion` then a `button` event on a price pill (scale
`global_rect` by `original_width / 1080`) and watch the arc land on the slot.
Emit a slot's `remove_requested` and confirm `×2` → `×1`. Press Beli and
confirm "Pembelian berhasil!" and an empty tray. Stop the game.

- [ ] **Step 9: Full suite** — milestone run. `test_run()`; check `git status`,
revert `default_bus_layout.tres`; restart the editor if the bridge dropped.

- [ ] **Step 10: Commit**

```bash
git add -A Scenes/Koperasi Scripts/Koperasi tests Assets/Images/Shop/UI CLAUDE.md
git commit -m "feat(koperasi): dock the basket tray; items land on their own slots"
```

- [ ] **Step 11: Mentor review — STOP**

Send the Step 8 screenshots to the user for the mentor. The layout is the part
the mentor picked from a sketch and the part most likely to need a round trip.
Tasks 6 and 7 do not depend on the review and may proceed; Task 8 waits for it.

---

## Task 6: Rim glow on press

Spec section 4: "lift plus rim glow on press". The glow is static chrome — a
`Glow` node authored behind each of the four shelf buttons — so nothing new is
built at runtime; `ShelfItem.lift()` swells it with the rise and fades it with
the settle.

**Files:**
- Create: `Assets/Images/Shop/UI/item_glow.tres`
- Modify: `Scenes/Koperasi/koprasi.tscn` (a `Glow` under each `Rak1/BarangN`) — through the editor
- Modify: `Scripts/Koperasi/ShelfItem.gd`
- Test: `tests/test_koperasi_tray.gd` (append)

**Interfaces:**
- Produces: `ShelfItem.lift() -> Tween` (was `void`), `ShelfItem.glow_alpha: float`.
  `rakbarang_1.gd` ignores the return value, so no caller changes.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_koperasi_tray.gd`:

```gdscript
# ───────────────────────────────────────────── Part 2: rim glow on press

## Stepped by hand with Tween.custom_step, so no test waits on real time.
func test_lift_swells_and_fades_the_rim_glow() -> void:
	var button := TextureButton.new()
	button.size = Vector2(200, 200)
	var glow := TextureRect.new()
	glow.name = "Glow"
	button.add_child(glow)
	Engine.get_main_loop().root.add_child(button)
	track(button)
	var life = load(SHELF_ITEM_SRC).new()
	button.add_child(life)
	life.attach_to(button)
	assert_eq(glow.modulate.a, 0.0, "no glow at rest")
	var tween = life.lift()
	assert_true(tween is Tween, "lift() hands back its tween")
	if not tween is Tween:
		return
	tween.pause()
	tween.custom_step(life.lift_duration)
	assert_true(absf(glow.modulate.a - life.glow_alpha) < 0.01,
		"the glow peaks as the item tops out")
	tween.custom_step(life.lift_duration)
	assert_true(glow.modulate.a < 0.01, "and is gone once it settles")
	assert_eq(glow.self_modulate, DesignTokens.load_default().currency_gold,
		"gold, from the tokens")


func test_each_shelf_item_has_a_glow_behind_it() -> void:
	var packed = load("res://Scenes/Koperasi/koprasi.tscn")
	assert_not_null(packed, "koprasi.tscn missing")
	if packed == null:
		return
	var shop = packed.instantiate()
	track(shop)
	for i in range(1, 5):
		var glow = shop.get_node_or_null("Rak1/Barang%d/Glow" % i)
		assert_true(glow is TextureRect, "Barang%d has a Glow" % i)
		if glow == null:
			continue
		assert_true(glow.show_behind_parent, "Barang%d's glow draws behind the item" % i)
		assert_eq(glow.modulate.a, 0.0, "Barang%d's glow is dark at rest" % i)
		assert_eq(glow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the glow never eats a tap")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run(suite="koperasi_tray", test_name="glow")`
Expected: FAIL — "lift() hands back its tween", "Barang1 has a Glow".

- [ ] **Step 3: The glow texture** — a new resource file; create `Assets/Images/Shop/UI/item_glow.tres`:

```
[gd_resource type="GradientTexture2D" load_steps=2 format=3]

[sub_resource type="Gradient" id="Gradient_glow"]
offsets = PackedFloat32Array(0, 0.55, 1)
colors = PackedColorArray(1, 1, 1, 0.9, 1, 1, 1, 0.45, 1, 1, 1, 0)

[resource]
gradient = SubResource("Gradient_glow")
width = 256
height = 256
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.5, 0)
```

White, so `ShelfItem` tints it from a token; radial, so it reads as a halo round
cut-out art. `filesystem_manage(op="scan")`.

- [ ] **Step 4: Four Glow nodes** — `scene_open` koprasi.tscn; under each of
`Rak1/Barang1`…`Barang4` create a `TextureRect` named `Glow`: `texture` =
`item_glow.tres`, `show_behind_parent = true`, `layout_mode = 1`, anchors
`0, 0, 1, 1`, offsets `-32, -32, 32, 32`, `mouse_filter = 2`,
`modulate = Color(1, 1, 1, 0)`, `expand_mode = 1`, `stretch_mode = 0`; move it to
index 0. `scene_save`, then `git diff HEAD -- '*.gd'`.

`_find_price_display()` only matches Button and Label children, so the Glow is
never mistaken for the old price label.

- [ ] **Step 5: Drive it from ShelfItem** — in `Scripts/Koperasi/ShelfItem.gd`,
after the `dim_alpha` export add:

```gdscript
## Peak opacity of the gold rim glow behind the item while it is lifted.
@export var glow_alpha: float = 0.85
```

next to the other state vars add `var _glow: CanvasItem`, and at the end of
`attach_to()` add:

```gdscript
	_glow = button.get_node_or_null("Glow")
	if is_instance_valid(_glow):
		_glow.self_modulate = DesignTokens.load_default().currency_gold
		_glow.modulate.a = 0.0
```

Replace `lift()`:

```gdscript
## Rises and settles, for the moment the item is bought, with a gold rim glow
## that swells on the way up and fades on the way down. Suspends the idle bob
## for the duration so the tween isn't stomped by _process every frame.
## Returns the tween, so tests can step it.
func lift() -> Tween:
	if not is_instance_valid(_button):
		return null
	_lifting = true
	var tween := _button.create_tween()
	tween.tween_property(_button, "position:y", _base_y - lift_distance, lift_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_glow):
		tween.parallel().tween_property(_glow, "modulate:a", glow_alpha, lift_duration)
	tween.tween_property(_button, "position:y", _base_y, lift_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(_glow):
		tween.parallel().tween_property(_glow, "modulate:a", 0.0, lift_duration)
	tween.tween_callback(_on_lift_finished)
	return tween
```

- [ ] **Step 6: Reload, run to verify they pass**

Force the ShelfItem reload (`script_patch` or restart). Run: `koperasi_tray`,
`script_documentation`, `viewport_editability` (ShelfItem's ALLOWED stays 1:
the glow is a scene node, not built in code).
Expected: all pass. Then check it live: press a price pill and screenshot at
the lift's peak (freeze `Engine.time_scale` inside the `game_eval`).

- [ ] **Step 7: Commit**

```bash
git add Assets/Images/Shop/UI/item_glow.tres Scenes/Koperasi/koprasi.tscn Scripts/Koperasi/ShelfItem.gd tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): a gold rim glow as a shelf item is lifted"
```

---

## Task 7: Part 1's deferred minors

**Files:**
- Modify: `Scenes/Koperasi/PriceTag.tscn` (through the editor), `Scripts/Koperasi/PriceTag.gd`
- Test: `tests/test_koperasi_tray.gd`

- [ ] **Step 1: Write the failing test** — append:

```gdscript
## Part 1 set these in _ready() because the bridge was down when the fix
## landed; they belong in the scene. Checked on an instance that never ran
## _ready, so only the scene's own values count.
func test_price_tag_lets_taps_through_by_scene() -> void:
	var packed = load(PRICE_TAG_SCENE)
	assert_not_null(packed, "PriceTag.tscn missing")
	if packed == null:
		return
	var tag = packed.instantiate()
	track(tag)
	for path in [".", "Row", "Row/Coin", "Row/Value"]:
		var node: Control = tag.get_node(path)
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s must let a tap through to the shelf button" % path)
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/PriceTag.gd")
	assert_false(src.contains("_ignore_mouse_so_taps_reach_the_button_beneath"),
		"the runtime pass is gone now that the scene says it")
```

and replace `test_basket_icon_has_no_text_elements` with a scan that also
catches the two ways text sneaks into an SVG, over both tray icons (a guard: it
passes before and after):

```gdscript
func test_basket_icon_has_no_text_elements() -> void:
	# ThorVG drops <text> on import. <tspan> lives inside text, and <use> can
	# pull a text node in by reference, so all three are checked.
	for path in [BASKET_ICON, "res://Assets/Images/Shop/UI/icon_keranjang_kosong.svg"]:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_not_null(f, "%s missing" % path)
		if f == null:
			continue
		var src := f.get_as_text()
		for element in ["<text", "<tspan", "<use"]:
			assert_false(src.contains(element), "%s must not contain %s" % [path, element])
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run(suite="koperasi_tray", test_name="lets_taps")`
Expected: FAIL — ". must let a tap through to the shelf button".

- [ ] **Step 3: Author it in the scene** — `scene_open` PriceTag.tscn; set
`mouse_filter = 2` on `PriceTag`, `Row`, `Row/Coin`, `Row/Value`; `scene_save`;
`git diff HEAD -- '*.gd'`.

- [ ] **Step 4: Drop the runtime pass** — in `PriceTag.gd` delete the
`_ignore_mouse_so_taps_reach_the_button_beneath()` function and its call at the
end of `_ready()`.

- [ ] **Step 5: Run to verify it passes** — `koperasi_tray`, `script_documentation`.
Then live: a tap on a price pill (motion, then button) still buys.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Koperasi/PriceTag.tscn Scripts/Koperasi/PriceTag.gd tests/test_koperasi_tray.gd
git commit -m "refactor(koperasi): the price tag lets taps through by scene, not code"
```

---

## Task 8: Docs, the full suite, and the pull request

Waits on the mentor review from Task 5, Step 11.

- [ ] **Step 1: CHANGELOG** — add a top entry to `docs/superpowers/CHANGELOG.md`,
"2026-09-11 — Koperasi rework, Part 2": the docked tray and its two decisions,
TraySlot and BasketTray, the tokens, the glow, the minors, the deleted modal
chrome and `test_rakbarang_blur_layer.gd`, the ratchet (rakbarang_1.gd 2 → 1),
and the full-suite count from Step 3.

- [ ] **Step 2: CLAUDE.md and the handover** — add `item_glow.tres` to nothing
(it is an authored resource, not placeholder art); drop `icon_retur.svg` from
the placeholder list if Task 5 deleted it. At the top of
`docs/superpowers/handover/2026-09-11-koperasi-part-2-handover.md`, add a
status line pointing at this plan and the CHANGELOG entry, and list anything
the mentor review sent back.

- [ ] **Step 3: Full suite** — `test_run()`; revert `default_bus_layout.tres`;
restart the editor if the bridge dropped. Every suite green.

- [ ] **Step 4: Commit and push**

```bash
git add docs/superpowers/CHANGELOG.md CLAUDE.md docs/superpowers/handover/2026-09-11-koperasi-part-2-handover.md
git commit -m "docs(koperasi): changelog and guide for the rework's Part 2"
git push -u origin feat/koperasi-part-2
```

- [ ] **Step 5: Pull request** — base `feat/koperasi-rework` (PR #15, still
open) so the diff shows Part 2 alone; retarget to `Textures` once #15 merges.
Body: what changed, the two decisions, test counts, and the mentor-review
screenshots.
