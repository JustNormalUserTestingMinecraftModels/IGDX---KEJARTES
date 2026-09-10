# Koperasi Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Koperasi shop feel alive — coin-pill price tags that wipe to "Beli", a slatted basket icon, shelf items with shadow/bob/lift/unaffordable states, and a warm blurred basket tray replacing the hard-bordered popup.

**Architecture:** Nothing about the pick-item → arc-into-basket mechanic changes. The work is the surfaces around it: new `ThemeFactory` type variations plus a rebake, four new art assets, one new `@tool` script for the price tag, one `PackedScene` for tray slots, and edits to `rakbarang_1.gd` and `koprasi.gd`. Commit 1 (Tasks 1-6) is script-and-asset only; commit 2 (Tasks 7-9) touches the scene.

**Tech Stack:** Godot 4.6, GDScript, `ThemeFactory`/`DesignTokens` theme baking, `McpTestSuite` tests run through the Godot AI MCP bridge.

**Spec:** `docs/superpowers/specs/2026-09-11-koperasi-rework-design.md`

## Global Constraints

- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only exception: layout-only constants (`separation`, `margin_*`).
- **No visual is built at runtime.** Static chrome in the `.tscn`, repeated rows as a `PackedScene`, responsive geometry in a `@tool` script with documented `@export`s.
- **Every script needs a `##` file header and a `##` line on every `@export`** — enforced by `tests/test_script_documentation.gd`.
- **No emoji as UI iconography.** Real transparent SVG textures instead.
- **UI text is Indonesian**; systems code is English.
- **Test suites must be `@tool`, must not be coroutines** (no `await` — the runner does `suite.call(name)` without awaiting, so an `await` silently aborts the test and it reports 0 assertions), and run **inside the editor** via MCP `test_run`.
- **Prefer targeted `test_run(suite=...)`.** A full run takes 15-20s and reliably drops the MCP bridge; budget one editor restart per full run.
- **Rescan after editing a `.gd` before running tests.** Edits made from outside the editor need a no-op `script_patch` on that same file to force the reload (it logs a benign `GDScript reload failed with error code 43`, then works). Cheapest fix: make edits through `script_patch` in the first place.
- **A changed or new `@export` default on a Resource needs a full editor restart** before it takes effect — `load_default()` serves a cached instance otherwise.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through `scene_open` → `node_create`/`node_set_property` → `scene_save`.
- **`scene_save` flushes stale script buffers** over whatever you patched. Do scene work first, script work second; after any `scene_save`, run `git diff HEAD -- '*.gd'` and check no script you were not editing got reverted.
- `Balance.gd` values are owned by a collaborator. Read freely, never edit.
- Branch is `feat/koperasi-rework`, already created, already carrying the two spec commits.

---

## File Structure

**Create:**
- `Assets/Images/Shop/UI/icon_keranjang.svg` — B3 slatted market basket, replaces the black silhouette.
- `Assets/Images/Shop/UI/tray_dots.png` — 26×26 tiling dot-grid, the tray's paper texture.
- `Assets/Images/Shop/UI/icon_keranjang_kosong.svg` — empty-basket glyph, replaces the `🛒` emoji.
- `Assets/Images/Shop/UI/icon_retur.svg` — return arrow, replaces the `↩` emoji.
- `Scenes/Koperasi/PriceTag.tscn` + `Scripts/Koperasi/PriceTag.gd` — the coin pill and its wipe-to-Beli state machine.
- `Scenes/Koperasi/ReturSlot.tscn` + `Scripts/Koperasi/ReturSlot.gd` — one tray slot, replacing runtime-built `_add_retur_entry`.
- `Scripts/Koperasi/ShelfItem.gd` — shadow, idle bob, lift, unaffordable dim for one shelf item.
- `tests/test_koperasi_tray.gd` — tray, tag and shelf-item behaviour.

**Modify:**
- `Scripts/Design/ThemeFactory.gd` — add `PriceTag`, `PriceTagPressed`, `PriceTagDisabled`, `BasketTray` variations.
- `Scripts/Koperasi/rakbarang_1.gd` — wire tags and shelf items; replace `_add_retur_entry`/`_populate_retur_panel` runtime construction; drop two emoji.
- `Scripts/Koperasi/koprasi.gd:117` — drop the `🛒` from the empty-cart message.
- `Scenes/Koperasi/koprasi.tscn` — basket texture swap, tray surface, warm blur wash. **Commit 2 only.**
- `tests/test_viewport_editability.gd:67` — lower the `rakbarang_1.gd` BASELINE from 7.

---

## Task 1: B3 basket icon asset

**Files:**
- Create: `Assets/Images/Shop/UI/icon_keranjang.svg`
- Test: `tests/test_koperasi_tray.gd`

**Interfaces:**
- Produces: an SVG at that exact path, 64×64 viewBox, importable as a `Texture2D`. Task 9 swaps the scene's basket texture to it.

- [ ] **Step 1: Write the failing test**

Create `tests/test_koperasi_tray.gd`:

```gdscript
@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

## Suite for the 2026-09-11 Koperasi rework: basket icon, coin-pill price
## tag, shelf item life, and the warm basket tray that replaces the popup.

const BASKET_ICON := "res://Assets/Images/Shop/UI/icon_keranjang.svg"

func test_basket_icon_exists() -> void:
	assert_true(ResourceLoader.exists(BASKET_ICON),
		"B3 basket icon missing at %s" % BASKET_ICON)

func test_basket_icon_has_no_text_elements() -> void:
	# Godot rasterises SVG through ThorVG, which silently drops <text>.
	# Everything must be a path, rect, or circle.
	var f := FileAccess.open(BASKET_ICON, FileAccess.READ)
	assert_not_null(f, "could not open %s" % BASKET_ICON)
	var src := f.get_as_text()
	assert_false(src.contains("<text"),
		"SVG uses <text>, which ThorVG drops on import")
```

- [ ] **Step 2: Run the test to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "B3 basket icon missing at res://Assets/Images/Shop/UI/icon_keranjang.svg"

- [ ] **Step 3: Create the asset**

Write `Assets/Images/Shop/UI/icon_keranjang.svg` exactly:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <clipPath id="body">
      <path d="M11 28 H53 L47.5 56 A3 3 0 0 1 44.5 58.5 H19.5 A3 3 0 0 1 16.5 56 Z"/>
    </clipPath>
  </defs>
  <path d="M18 24 Q32 6 46 24" fill="none" stroke="#8A5514" stroke-width="4" stroke-linecap="round"/>
  <path d="M11 28 H53 L47.5 56 A3 3 0 0 1 44.5 58.5 H19.5 A3 3 0 0 1 16.5 56 Z" fill="#EBB868"/>
  <g clip-path="url(#body)" stroke="#8A5514" stroke-width="3" stroke-linecap="round">
    <path d="M20 28 L22.5 60 M28 28 L29 60 M36 28 L35.5 60 M44 28 L42 60"/>
  </g>
  <path d="M14 48 H50" stroke="#8A5514" stroke-width="3" clip-path="url(#body)"/>
  <path d="M11 28 H53 L47.5 56 A3 3 0 0 1 44.5 58.5 H19.5 A3 3 0 0 1 16.5 56 Z" fill="none" stroke="#6B3F0C" stroke-width="3" stroke-linejoin="round"/>
  <rect x="8" y="22" width="48" height="8" rx="4" fill="#C98A2E" stroke="#6B3F0C" stroke-width="3"/>
</svg>
```

- [ ] **Step 4: Import and re-run**

MCP: `filesystem_manage(op="scan")`, then `test_run(suite="test_koperasi_tray")`
Expected: PASS, 2 assertions.

- [ ] **Step 5: Commit**

```bash
git add Assets/Images/Shop/UI/icon_keranjang.svg Assets/Images/Shop/UI/icon_keranjang.svg.import tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): add the B3 slatted basket icon"
```

---

## Task 2: PriceTag and BasketTray theme variations

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add a builder next to the `Card` one, around line 474)
- Test: `tests/test_koperasi_tray.gd`

**Interfaces:**
- Produces: four type variations on the baked theme — `PriceTag` (StyleBoxFlat, bright green), `PriceTagPressed` (dark green), `PriceTagDisabled` (neutral), `BasketTray` (warm cream panel). Task 3 sets `theme_type_variation = &"PriceTag"`; Task 9 uses `BasketTray`.

Colors are literal here rather than `DesignTokens` `@export`s **deliberately** — a new `@export` on a Resource needs a full editor restart before its default takes effect, and this plan must be executable in one sitting. Promoting them to tokens is a good follow-up, not part of this pass.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

func _baked_theme() -> Theme:
	return load(THEME_PATH) as Theme

func test_price_tag_variations_registered() -> void:
	var theme := _baked_theme()
	assert_not_null(theme, "baked theme missing at %s" % THEME_PATH)
	for v in ["PriceTag", "PriceTagPressed", "PriceTagDisabled", "BasketTray"]:
		assert_true(theme.has_stylebox("panel", v),
			"variation %s has no panel stylebox" % v)

func test_price_tag_is_green_and_pressed_is_darker() -> void:
	var theme := _baked_theme()
	var rest := theme.get_stylebox("panel", "PriceTag") as StyleBoxFlat
	var pressed := theme.get_stylebox("panel", "PriceTagPressed") as StyleBoxFlat
	assert_not_null(rest, "PriceTag panel is not a StyleBoxFlat")
	assert_not_null(pressed, "PriceTagPressed panel is not a StyleBoxFlat")
	assert_true(rest.bg_color.g > rest.bg_color.r,
		"PriceTag should read green")
	assert_true(pressed.bg_color.v < rest.bg_color.v,
		"pressed state must be darker than rest")

func test_basket_tray_has_no_black() -> void:
	# The mentor's note: nothing in the tray may read as premium-black.
	var theme := _baked_theme()
	var tray := theme.get_stylebox("panel", "BasketTray") as StyleBoxFlat
	assert_not_null(tray, "BasketTray panel is not a StyleBoxFlat")
	assert_true(tray.bg_color.v > 0.75, "tray surface must stay light and warm")
	assert_true(tray.bg_color.r > tray.bg_color.b, "tray surface must be warm, not cool")
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "variation PriceTag has no panel stylebox"

- [ ] **Step 3: Add the variations**

In `Scripts/Design/ThemeFactory.gd`, find `theme.add_type("Card")` (around line 474) and add this builder after that function. Call it from the same place the other `_add_*` builders are called from:

```gdscript
## Koperasi rework (2026-09-11): the coin-pill price tag in its three
## states, and the warm tray surface that replaces the popup box.
func _add_koperasi_variations(theme: Theme, tokens: DesignTokens) -> void:
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color("#639922")
	rest.border_color = Color("#3B6D11")
	rest.set_border_width_all(4)
	rest.set_corner_radius_all(40)
	rest.content_margin_left = 12
	rest.content_margin_right = 28
	rest.content_margin_top = 8
	rest.content_margin_bottom = 8
	theme.add_type("PriceTag")
	theme.set_type_variation("PriceTag", "Panel")
	theme.set_stylebox("panel", "PriceTag", rest)

	var pressed := rest.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#2F5A0D")
	pressed.border_color = Color("#173404")
	theme.add_type("PriceTagPressed")
	theme.set_type_variation("PriceTagPressed", "Panel")
	theme.set_stylebox("panel", "PriceTagPressed", pressed)

	var disabled := rest.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#B4B2A9")
	disabled.border_color = Color("#5F5E5A")
	theme.add_type("PriceTagDisabled")
	theme.set_type_variation("PriceTagDisabled", "Panel")
	theme.set_stylebox("panel", "PriceTagDisabled", disabled)

	var tray := StyleBoxFlat.new()
	tray.bg_color = Color("#FBEBC8")
	tray.border_color = Color("#A86A1C")
	tray.border_width_top = 6
	tray.corner_radius_top_left = 40
	tray.corner_radius_top_right = 40
	tray.content_margin_left = 28
	tray.content_margin_right = 28
	tray.content_margin_top = 20
	tray.content_margin_bottom = 24
	theme.add_type("BasketTray")
	theme.set_type_variation("BasketTray", "Panel")
	theme.set_stylebox("panel", "BasketTray", tray)
```

If the surrounding builders do not take a `tokens` argument, match their signature instead — `tokens` is unused here.

- [ ] **Step 4: Rebake the theme**

`BakeTheme.gd` is an `EditorScript` with no MCP entry point. Either File > Run (Ctrl+Shift+X) on `Scripts/Design/BakeTheme.gd` in the editor, or run MCP `test_run(suite="test_theme_rebake")` — that suite calls `ResourceSaver.save()` in-process and rebakes as a side effect.

- [ ] **Step 5: Run to verify it passes**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: PASS, 6 assertions.

If `test_price_tag_variations_registered` still fails right after a rebake, re-run it alone before believing it — suite order means a suite reading the baked theme before `theme_rebake` runs sees the old bake.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): add PriceTag and BasketTray theme variations"
```

---

## Task 3: PriceTag scene and wipe-to-Beli script

**Files:**
- Create: `Scripts/Koperasi/PriceTag.gd`, `Scenes/Koperasi/PriceTag.tscn`
- Test: `tests/test_koperasi_tray.gd`

**Interfaces:**
- Consumes: the `PriceTag`/`PriceTagPressed`/`PriceTagDisabled` variations from Task 2.
- Produces: `PriceTag.gd` with `set_price(value: int) -> void`, `play_buy() -> void`, `set_affordable(can_afford: bool) -> void`, `get_label_text() -> String`, and `const BELI_TEXT := "Beli"`. Task 4 calls all of these.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
const PRICE_TAG_SCENE := "res://Scenes/Koperasi/PriceTag.tscn"

func test_price_tag_scene_exists() -> void:
	assert_true(ResourceLoader.exists(PRICE_TAG_SCENE),
		"PriceTag.tscn missing")

func test_price_tag_shows_price_at_rest() -> void:
	var tag = load(PRICE_TAG_SCENE).instantiate()
	tag.set_price(800)
	assert_eq(tag.get_label_text(), "800",
		"tag should show the bare price at rest")
	tag.free()

func test_price_tag_swaps_to_beli_on_buy() -> void:
	var tag = load(PRICE_TAG_SCENE).instantiate()
	tag.set_price(800)
	tag.play_buy()
	# play_buy sets the label synchronously; only the tween is deferred,
	# so this test never needs to await.
	assert_eq(tag.get_label_text(), "Beli",
		"pressed state must read Beli, not the number")
	tag.free()

func test_price_tag_unaffordable_keeps_the_price_visible() -> void:
	var tag = load(PRICE_TAG_SCENE).instantiate()
	tag.set_price(1200)
	tag.set_affordable(false)
	assert_eq(tag.get_label_text(), "1200",
		"unaffordable tags still show what the item costs")
	assert_eq(tag.theme_type_variation, &"PriceTagDisabled",
		"unaffordable tag should use the neutral variation")
	tag.free()

func test_price_tag_uses_no_theme_overrides() -> void:
	var f := FileAccess.open("res://Scripts/Koperasi/PriceTag.gd", FileAccess.READ)
	assert_not_null(f, "PriceTag.gd missing")
	assert_false(f.get_as_text().contains("add_theme_"),
		"PriceTag must use type variations, never theme overrides")
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "PriceTag.tscn missing"

- [ ] **Step 3: Write the script**

Create `Scripts/Koperasi/PriceTag.gd`:

```gdscript
@tool
extends PanelContainer

## A koperasi price tag: a green coin pill showing an item's price, which
## wipes left-to-right to dark green and swaps its label to "Beli" when the
## player buys. Three states -- rest, pressed, and unaffordable.
##
## The tag is the press target for buying, which gives the item's flight
## into the basket an explicit trigger.

## Word shown in place of the price once the player commits to buying.
const BELI_TEXT := "Beli"

## How long the dark green wipe takes to cross the pill, in seconds.
## Matches DesignTokens.dur_fast (0.18) so the tag agrees with the rest of
## the UI without depending on a token that would need an editor restart.
@export var wipe_duration: float = 0.18

## Delay before the label pops, in seconds. Deliberately longer than
## wipe_duration so the pop lands after the wipe arrives rather than
## competing with it.
@export var label_delay: float = 0.23

## How long the label's scale pop takes, in seconds.
@export var pop_duration: float = 0.22

## Scale the label springs up from when it swaps to "Beli".
@export var pop_from_scale: float = 0.55

@onready var _wipe: ColorRect = $Wipe
@onready var _value: Label = $Row/Value

var _price: int = 0

func _ready() -> void:
	clip_contents = true
	if is_instance_valid(_wipe):
		_wipe.color = Color("#2F5A0D")
		_wipe.size.x = 0.0

## Sets the displayed price and returns the tag to its rest state.
func set_price(value: int) -> void:
	_price = value
	_ensure_nodes()
	_value.text = str(value)
	_value.scale = Vector2.ONE
	theme_type_variation = &"PriceTag"
	if is_instance_valid(_wipe):
		_wipe.size.x = 0.0

## Reads the label. Exists so tests can assert without knowing node paths.
func get_label_text() -> String:
	_ensure_nodes()
	return _value.text

## Greys the tag out when the player cannot afford the item. The price
## stays visible -- the player should always know what something costs.
func set_affordable(can_afford: bool) -> void:
	_ensure_nodes()
	theme_type_variation = &"PriceTag" if can_afford else &"PriceTagDisabled"

## Runs the buy transition: dark green wipes left to right, then the price
## swaps to "Beli" with a scale pop. The label text changes synchronously
## so callers and tests can rely on it immediately.
func play_buy() -> void:
	_ensure_nodes()
	_value.text = BELI_TEXT
	theme_type_variation = &"PriceTagPressed"
	if not is_inside_tree():
		return

	if is_instance_valid(_wipe):
		_wipe.size.y = size.y
		_wipe.size.x = 0.0
		var wipe_tween := create_tween()
		wipe_tween.tween_property(_wipe, "size:x", size.x, wipe_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	_value.pivot_offset = _value.size / 2.0
	_value.scale = Vector2(pop_from_scale, pop_from_scale)
	var pop := create_tween()
	pop.tween_interval(label_delay)
	pop.tween_property(_value, "scale", Vector2.ONE, pop_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Resolves @onready nodes when the tag is used before _ready -- tests
## instantiate the scene without adding it to the tree.
func _ensure_nodes() -> void:
	if not is_instance_valid(_value):
		_value = get_node_or_null("Row/Value")
	if not is_instance_valid(_wipe):
		_wipe = get_node_or_null("Wipe")
```

- [ ] **Step 4: Build the scene**

Target structure:

```
PriceTag (PanelContainer, theme_type_variation = "PriceTag", clip_contents = true, script = PriceTag.gd)
├── Wipe (ColorRect, mouse_filter = 2)
└── Row (HBoxContainer, separation = 10)
    ├── Coin (TextureRect, custom_minimum_size 44×44, stretch_mode = 5)
    └── Value (Label, theme_type_variation = "BarLabel")
```

Build it via MCP `batch_execute` on a new scene saved to `Scenes/Koperasi/PriceTag.tscn`. `Coin`'s texture is `res://Assets/Images/Shop/Koin.png`.

Gotchas: numbers unquoted (`1`, not `"1.0"`); `anchors_preset` is inert, set the four anchors; `node_create` appends last, so use `move_node` to put `Wipe` before `Row`; a `Control` created under a plain `Control` starts in position mode where anchors are not saved — set `layout_mode = 1` first.

- [ ] **Step 5: Run to verify it passes**

MCP: `filesystem_manage(op="scan")`, then `test_run(suite="test_koperasi_tray")`
Expected: PASS, 11 assertions.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Koperasi/PriceTag.gd Scenes/Koperasi/PriceTag.tscn tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): coin-pill price tag with the wipe-to-Beli state"
```

---

## Task 4: Wire price tags onto the shelf

**Files:**
- Modify: `Scripts/Koperasi/rakbarang_1.gd` — `setup_random_items` (the price block near line 100), `_on_barang_pressed` (line 125), `_ready` (line 29)
- Test: `tests/test_koperasi_tray.gd`

**Interfaces:**
- Consumes: `set_price`, `play_buy`, `set_affordable` from Task 3.
- Produces: `_price_tags: Array` parallel to `shelf_buttons`, and `_refresh_affordability() -> void`. Task 5 extends both.

Today `setup_random_items` finds a plain `Button`/`Label` child of each shelf button via `_find_price_display` and sets `.text`. That node is replaced by an instanced `PriceTag`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
const RAK_SRC := "res://Scripts/Koperasi/rakbarang_1.gd"

func _rak_source() -> String:
	var f := FileAccess.open(RAK_SRC, FileAccess.READ)
	assert_not_null(f, "rakbarang_1.gd missing")
	return f.get_as_text()

func test_shelf_instances_price_tags() -> void:
	var src := _rak_source()
	assert_true(src.contains("PriceTag.tscn"),
		"shelf should instance the PriceTag scene")
	assert_true(src.contains("set_price("),
		"shelf should push prices through set_price")

func test_shelf_plays_buy_on_press() -> void:
	var src := _rak_source()
	assert_true(src.contains("play_buy()"),
		"_on_barang_pressed should run the tag's buy transition")

func test_shelf_refreshes_affordability() -> void:
	var src := _rak_source()
	assert_true(src.contains("_refresh_affordability"),
		"shelf must recompute which items the player can afford")
	assert_true(src.contains("set_affordable("),
		"affordability must reach the tags")
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "shelf should instance the PriceTag scene"

- [ ] **Step 3: Confirm the money signal**

```bash
grep -n "signal money_changed" Scripts/GameState.gd
```

`koprasi.gd:104` already defines `_on_money_changed(new_amount: int)`, so the signal exists with that shape. Confirm the exact name before wiring.

- [ ] **Step 4: Patch the shelf script**

Use MCP `script_patch`, not a plain write — a plain write needs a no-op patch afterwards to force the reload. Normalise the file to LF first if it has CRLF, or multi-line anchors will miss.

Add after `var shelf_buttons: Array[TextureButton] = []`:

```gdscript
## Instanced PriceTag per shelf button, parallel to shelf_buttons.
var _price_tags: Array = []

const PRICE_TAG_SCENE := preload("res://Scenes/Koperasi/PriceTag.tscn")
```

Replace the price block inside `setup_random_items` — currently:

```gdscript
			var price_node = _find_price_display(btn)
			if price_node:
				price_node.text = "%d" % item.price
```

with:

```gdscript
			var tag = _ensure_price_tag(btn)
			if tag:
				tag.set_price(item.price)
```

Add these two functions:

```gdscript
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

## Greys out tags for items the player cannot currently afford.
func _refresh_affordability() -> void:
	for i in range(_price_tags.size()):
		var tag = _price_tags[i]
		if not is_instance_valid(tag) or i >= item_data_list.size():
			continue
		tag.set_affordable(GameState.money >= item_data_list[i].price)
```

At the end of `setup_random_items`:

```gdscript
	_price_tags.clear()
	for btn in shelf_buttons:
		_price_tags.append(btn.get_node_or_null("PriceTag"))
	_refresh_affordability()
```

In `_on_barang_pressed`, after `AnimUtils.squash_bounce(btn)`:

```gdscript
	if index < _price_tags.size() and is_instance_valid(_price_tags[index]):
		_price_tags[index].play_buy()
```

In `_ready`, after the `Cart.cart_changed` connection:

```gdscript
	if not GameState.money_changed.is_connected(_on_money_changed_refresh):
		GameState.money_changed.connect(_on_money_changed_refresh)
```

and add:

```gdscript
## GameState.money_changed passes the new amount; affordability recomputes
## from GameState directly, so the argument is unused.
func _on_money_changed_refresh(_new_amount: int) -> void:
	_refresh_affordability()
```

- [ ] **Step 5: Run to verify it passes**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: PASS, 15 assertions.

- [ ] **Step 6: Verify in the running game**

MCP `project_run`. Debug overlay (F1, or 5 taps top-right) → General → ⚡ Seed Playtest State → Scenes → teleport to the shop.

Confirm: tags read as green coin pills; pressing one wipes dark green left-to-right and swaps to "Beli"; an item you cannot afford is greyed but still shows its price. To check the unaffordable state, use Debug → General → money editor to drop money below an item's price.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Koperasi/rakbarang_1.gd tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): wire coin-pill tags onto the shelf with affordability"
```

---

## Task 5: Shelf item life

**Files:**
- Create: `Scripts/Koperasi/ShelfItem.gd`
- Modify: `Scripts/Koperasi/rakbarang_1.gd` — `setup_random_items`, `_refresh_affordability`, `_on_barang_pressed`
- Test: `tests/test_koperasi_tray.gd`

**Interfaces:**
- Produces: `ShelfItem.gd` with `attach_to(button: TextureButton) -> void`, `set_dimmed(dim: bool) -> void`, `lift() -> void`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
const SHELF_ITEM_SRC := "res://Scripts/Koperasi/ShelfItem.gd"

func test_shelf_item_script_exists() -> void:
	assert_true(ResourceLoader.exists(SHELF_ITEM_SRC), "ShelfItem.gd missing")

func test_shelf_item_documents_every_export() -> void:
	var f := FileAccess.open(SHELF_ITEM_SRC, FileAccess.READ)
	assert_not_null(f, "ShelfItem.gd missing")
	var lines := f.get_as_text().split("\n")
	var i := 0
	while i < lines.size():
		if lines[i].strip_edges().begins_with("@export"):
			var prev := lines[i - 1].strip_edges() if i > 0 else ""
			assert_true(prev.begins_with("##"),
				"undocumented @export on line %d" % (i + 1))
		i += 1

func test_shelf_item_bobs_with_a_phase_offset() -> void:
	var f := FileAccess.open(SHELF_ITEM_SRC, FileAccess.READ)
	assert_not_null(f, "ShelfItem.gd missing")
	assert_true(f.get_as_text().contains("phase"),
		"items must bob out of sync, so the shelf does not pulse in unison")
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "ShelfItem.gd missing"

- [ ] **Step 3: Write the script**

Create `Scripts/Koperasi/ShelfItem.gd`:

```gdscript
@tool
extends Node

## Gives one koperasi shelf item its life: a soft shadow on the plank, a
## slow idle bob at a per-item phase offset so the shelf never pulses in
## unison, a lift when pressed, and a dim when the player cannot afford it.
##
## Attached as a child helper of a shelf TextureButton rather than as that
## button's own script, so the shop's existing press wiring is untouched.

## Vertical travel of the idle bob, in pixels.
@export var bob_distance: float = 6.0

## Seconds for one full bob cycle.
@export var bob_period: float = 2.4

## How far the item rises when pressed, in pixels.
@export var lift_distance: float = 10.0

## Seconds the lift takes to rise, and again to settle.
@export var lift_duration: float = 0.16

## Opacity applied when the item is unaffordable.
@export var dim_alpha: float = 0.55

## Shadow texture laid under the item on the shelf plank.
@export var shadow_texture: Texture2D = preload("res://Assets/Images/UI/Placeholders/shadow_ellipse.png")

var _button: TextureButton
var _shadow: TextureRect
var _phase: float = 0.0
var _base_y: float = 0.0

## Wires this helper to a shelf button: adds the shadow, records the
## resting position, and picks a random bob phase.
func attach_to(button: TextureButton) -> void:
	_button = button
	_base_y = button.position.y
	_phase = randf() * TAU

	if shadow_texture and not is_instance_valid(_shadow):
		_shadow = TextureRect.new()
		_shadow.texture = shadow_texture
		_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow.modulate.a = 0.35
		_shadow.size = Vector2(button.size.x * 0.8, 18.0)
		_shadow.position = Vector2(button.size.x * 0.1, button.size.y - 6.0)
		button.add_child(_shadow)
		button.move_child(_shadow, 0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_button):
		return
	_phase += delta * TAU / bob_period
	_button.position.y = _base_y + sin(_phase) * bob_distance

## Rises and settles, for the moment the item is bought.
func lift() -> void:
	if not is_instance_valid(_button):
		return
	var tween := _button.create_tween()
	tween.tween_property(_button, "position:y", _base_y - lift_distance, lift_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "position:y", _base_y, lift_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Fades the item when its price is out of reach.
func set_dimmed(dim: bool) -> void:
	if not is_instance_valid(_button):
		return
	_button.modulate.a = dim_alpha if dim else 1.0
```

Note the shadow is a `TextureRect` built in code. That is per-call-dynamic content attached to a runtime-randomised shelf, so it belongs in `test_viewport_editability.gd`'s `ALLOWED` dict rather than `BASELINE` — add it there with a comment if the suite flags it.

- [ ] **Step 4: Wire it in**

Add at the top of `rakbarang_1.gd`:

```gdscript
const ShelfItemScript := preload("res://Scripts/Koperasi/ShelfItem.gd")

## ShelfItem helper per shelf button, parallel to shelf_buttons.
var _shelf_items: Array = []
```

In `setup_random_items`, right after the tag is set:

```gdscript
			var life = ShelfItemScript.new()
			life.name = "ShelfItem"
			btn.add_child(life)
			life.attach_to(btn)
			_shelf_items.append(life)
```

Clear `_shelf_items` alongside `_price_tags.clear()`.

Extend `_refresh_affordability`, inside the same loop:

```gdscript
		if i < _shelf_items.size() and is_instance_valid(_shelf_items[i]):
			_shelf_items[i].set_dimmed(GameState.money < item_data_list[i].price)
```

In `_on_barang_pressed`, beside the `play_buy()` call:

```gdscript
	if index < _shelf_items.size() and is_instance_valid(_shelf_items[index]):
		_shelf_items[index].lift()
```

- [ ] **Step 5: Run to verify it passes**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: PASS, 18 assertions.

- [ ] **Step 6: Verify visually**

`project_run`, seed, teleport to the shop. Items should bob gently and out of step with each other, cast a soft shadow, lift on press, and fade when unaffordable.

Judge this from a **full-size** `editor_screenshot` — a scaled capture cannot show a 6px bob or an 18px shadow, and signing off a visual change from a scaled one is how the 2026-09-10 cream pass shipped a half-finished layout.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Koperasi/ShelfItem.gd Scripts/Koperasi/rakbarang_1.gd tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): give shelf items shadow, bob, lift and dim states"
```

---

## Task 6: Remove the three emoji

**Files:**
- Create: `Assets/Images/Shop/UI/icon_keranjang_kosong.svg`, `Assets/Images/Shop/UI/icon_retur.svg`
- Modify: `Scripts/Koperasi/koprasi.gd:117`, `Scripts/Koperasi/rakbarang_1.gd:346`, `Scripts/Koperasi/rakbarang_1.gd:383`
- Test: `tests/test_koperasi_tray.gd`

The spec named one emoji; there are three: `koprasi.gd:117` `"Keranjang kosong! 🛒"`, `rakbarang_1.gd:346` `"🛒 Keranjang kosong"`, `rakbarang_1.gd:383` `"↩ Retur 1"`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
func test_koperasi_scripts_carry_no_emoji() -> void:
	# Project convention bans emoji as UI iconography (2026-09-02).
	var paths := [
		"res://Scripts/Koperasi/koprasi.gd",
		"res://Scripts/Koperasi/rakbarang_1.gd",
	]
	for path in paths:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_not_null(f, "%s missing" % path)
		var src := f.get_as_text()
		for glyph in ["\u{1F6D2}", "↩"]:
			assert_false(src.contains(glyph),
				"%s still contains an emoji glyph" % path)
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "res://Scripts/Koperasi/koprasi.gd still contains an emoji glyph"

- [ ] **Step 3: Create the two glyphs**

`Assets/Images/Shop/UI/icon_keranjang_kosong.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <path d="M18 24 Q32 6 46 24" fill="none" stroke="#A89370" stroke-width="4" stroke-linecap="round"/>
  <path d="M11 28 H53 L47.5 56 A3 3 0 0 1 44.5 58.5 H19.5 A3 3 0 0 1 16.5 56 Z" fill="none" stroke="#A89370" stroke-width="3" stroke-linejoin="round"/>
  <rect x="8" y="22" width="48" height="8" rx="4" fill="none" stroke="#A89370" stroke-width="3"/>
</svg>
```

`Assets/Images/Shop/UI/icon_retur.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <path d="M42 44 H26 A12 12 0 0 1 26 20 H44" fill="none" stroke="#6B3F0C" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M34 12 L44 20 L34 28" fill="none" stroke="#6B3F0C" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 4: Drop the emoji from the strings**

- `koprasi.gd:117`: `"Keranjang kosong! 🛒"` → `"Keranjang kosong!"`
- `rakbarang_1.gd:346`: `"🛒 Keranjang kosong"` → `"Keranjang kosong"`
- `rakbarang_1.gd:383`: `"↩ Retur 1"` → `"Retur 1"`

The two glyphs get placed as real `TextureRect`s in Tasks 8 and 9, where those call sites become scene-driven.

- [ ] **Step 5: Run to verify it passes**

MCP: `filesystem_manage(op="scan")`, then `test_run(suite="test_koperasi_tray")`
Expected: PASS, 22 assertions.

- [ ] **Step 6: Commit and push — this closes commit 1**

```bash
git add Assets/Images/Shop/UI/ Scripts/Koperasi/koprasi.gd Scripts/Koperasi/rakbarang_1.gd tests/test_koperasi_tray.gd
git commit -m "fix(koperasi): replace three emoji with real glyph textures"
git push -u origin feat/koperasi-rework
```

**Push here.** Everything through Task 6 is script-and-asset only and stands on its own. If the day runs out during commit 2, this is the shippable state — a half-restructured tray is worse than the current popup, so stop at a task boundary, not mid-task.

---

## Task 7: Tray dot-grid tile

**Files:**
- Create: `Assets/Images/Shop/UI/tray_dots.png`
- Test: `tests/test_koperasi_tray.gd`

The pattern must be a **texture tile**, not drawn at runtime — a procedural dot field would land on `tests/test_viewport_editability.gd`'s `BASELINE`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
const TRAY_DOTS := "res://Assets/Images/Shop/UI/tray_dots.png"

func test_tray_dot_tile_exists_and_tiles() -> void:
	assert_true(ResourceLoader.exists(TRAY_DOTS), "tray dot tile missing")
	var tex := load(TRAY_DOTS) as Texture2D
	assert_not_null(tex, "tray dot tile did not load as a texture")
	assert_eq(tex.get_width(), 26, "tile must be 26px wide to repeat cleanly")
	assert_eq(tex.get_height(), 26, "tile must be 26px tall to repeat cleanly")
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "tray dot tile missing"

- [ ] **Step 3: Generate the tile**

The project's other placeholder art is PowerShell + `System.Drawing`; follow that. From the repo root:

```powershell
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 26, 26
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(102, 201, 155, 74))
$g.FillEllipse($brush, 11, 11, 4, 4)
$g.Dispose()
$bmp.Save("$PWD\Assets\Images\Shop\UI\tray_dots.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
```

One dot per 26px cell, `#C99B4A` at 40% alpha — quiet enough that item art stays the loudest thing on the tray.

- [ ] **Step 4: Set the import flags**

The tile repeats, so it needs repeat enabled. MCP `filesystem_manage(op="scan")`, then in the editor select `tray_dots.png` → Import tab → **Repeat: Enabled** → Reimport.

- [ ] **Step 5: Run to verify it passes**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: PASS, 26 assertions.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/Shop/UI/tray_dots.png Assets/Images/Shop/UI/tray_dots.png.import tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): add the tray dot-grid tile"
```

---

## Task 8: ReturSlot scene replaces runtime construction

**Files:**
- Create: `Scenes/Koperasi/ReturSlot.tscn`, `Scripts/Koperasi/ReturSlot.gd`
- Modify: `Scripts/Koperasi/rakbarang_1.gd` — `_populate_retur_panel` (line 341), `_add_retur_entry` (line 365, deleted), `_on_retur_button_pressed` (line 391), `_resolve_nodes` (line 59)
- Modify: `tests/test_viewport_editability.gd:67`
- Test: `tests/test_koperasi_tray.gd`

**Interfaces:**
- Produces: `ReturSlot.gd` with `bind(item: ItemData, quantity: int) -> void`, `get_caption() -> String`, and `signal retur_requested(item_name: String)`.

`_add_retur_entry` currently builds a `VBoxContainer`, `TextureRect`, `Label` and `Button` with `.new()` plus three `add_theme_font_size_override` calls — runtime construction and theme overrides in one function. Moving it into a scene **lowers** `rakbarang_1.gd`'s BASELINE of 7. Do not raise it.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
const RETUR_SLOT_SCENE := "res://Scenes/Koperasi/ReturSlot.tscn"

func test_retur_slot_scene_exists() -> void:
	assert_true(ResourceLoader.exists(RETUR_SLOT_SCENE), "ReturSlot.tscn missing")

func test_retur_slot_binds_name_and_quantity() -> void:
	var slot = load(RETUR_SLOT_SCENE).instantiate()
	var item := ItemData.new()
	item.item_name = "Susu Murni"
	item.price = 1000
	slot.bind(item, 2)
	assert_eq(slot.get_caption(), "Susu Murni ×2",
		"slot caption should carry the name and quantity")
	slot.free()

func test_shelf_no_longer_builds_retur_entries_at_runtime() -> void:
	var src := _rak_source()
	assert_false(src.contains("VBoxContainer.new()"),
		"tray slots must come from ReturSlot.tscn, not runtime construction")
	assert_false(src.contains("add_theme_font_size_override"),
		"use theme type variations, never font-size overrides")
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "ReturSlot.tscn missing"

- [ ] **Step 3: Write the slot script**

Create `Scripts/Koperasi/ReturSlot.gd`:

```gdscript
@tool
extends VBoxContainer

## One item sitting in the koperasi basket tray: its art, its name and
## quantity, and the button that returns one of it to the shelf.
##
## Replaces the VBoxContainer/Label/Button that rakbarang_1.gd used to
## build at runtime with font-size overrides.

## Emitted when the player returns one of this item.
signal retur_requested(item_name: String)

@onready var _icon: TextureRect = $Icon
@onready var _caption: Label = $Caption
@onready var _button: Button = $ReturButton

var _item_name: String = ""

func _ready() -> void:
	if is_instance_valid(_button) and not _button.pressed.is_connected(_on_retur_pressed):
		_button.pressed.connect(_on_retur_pressed)

## Fills the slot from a cart entry.
func bind(item: ItemData, quantity: int) -> void:
	_ensure_nodes()
	_item_name = item.item_name
	_icon.texture = item.icon
	_caption.text = "%s ×%d" % [item.item_name, quantity]

## Reads the caption. Exists so tests need not know node paths.
func get_caption() -> String:
	_ensure_nodes()
	return _caption.text

func _on_retur_pressed() -> void:
	AnimUtils.squash_bounce(_button)
	retur_requested.emit(_item_name)

func _ensure_nodes() -> void:
	if not is_instance_valid(_icon):
		_icon = get_node_or_null("Icon")
	if not is_instance_valid(_caption):
		_caption = get_node_or_null("Caption")
	if not is_instance_valid(_button):
		_button = get_node_or_null("ReturButton")
```

- [ ] **Step 4: Build the scene**

Scene work first, script work second. Target structure:

```
ReturSlot (VBoxContainer, script = ReturSlot.gd, separation = 8, custom_minimum_size 300×380, alignment = 1)
├── Icon (TextureRect, custom_minimum_size 300×300, expand_mode = 1, stretch_mode = 5)
├── Caption (Label, theme_type_variation = "CaptionLabel", horizontal_alignment = 1)
└── ReturButton (Button, theme_type_variation = "SecondaryButton", text = "Retur 1",
    icon = res://Assets/Images/Shop/UI/icon_retur.svg, custom_minimum_size 180×55)
```

`separation` is a layout-only constant override — the one accepted exception to the no-overrides rule.

After `scene_save`: run `git diff HEAD -- '*.gd'` and confirm no script you were not editing got reverted. If one was, restore it from the last commit and re-apply.

- [ ] **Step 5: Replace the runtime builders**

Delete `_add_retur_entry` entirely. Add the preload at the top:

```gdscript
const RETUR_SLOT_SCENE := preload("res://Scenes/Koperasi/ReturSlot.tscn")
```

Declare the empty-state node (added to the scene in Task 9) beside the other panel vars:

```gdscript
var retur_empty_state: Control
```

and resolve it in `_resolve_nodes`, inside the existing `if retur_panel:` block:

```gdscript
		retur_empty_state = retur_panel.find_child("EmptyState", true, false)
```

Rewrite `_populate_retur_panel`:

```gdscript
func _populate_retur_panel():
	if not retur_grid:
		return
	for child in retur_grid.get_children():
		child.queue_free()

	if Cart.is_empty():
		if is_instance_valid(retur_empty_state):
			retur_empty_state.show()
		return
	if is_instance_valid(retur_empty_state):
		retur_empty_state.hide()

	for item_name in Cart.cart:
		var entry = Cart.cart[item_name]
		var slot = RETUR_SLOT_SCENE.instantiate()
		retur_grid.add_child(slot)
		slot.bind(entry["data"], entry["quantity"])
		slot.retur_requested.connect(_on_retur_button_pressed)
		AnimUtils.spring_pop_in(slot, 0.8)
```

`retur_requested` already carries the item name, so the signal connects directly with no bind.

Simplify `_on_retur_button_pressed` — the slot owns its own button animation now:

```gdscript
func _on_retur_button_pressed(item_name: String):
	AudioDirector.play_sfx(&"pop")
	_remove_last_icon_by_name(item_name)
	_populate_retur_panel()
```

- [ ] **Step 6: Lower the ratchet**

Run MCP `test_run(suite="test_viewport_editability")`. It will report the actual new count for `rakbarang_1.gd`. Edit `tests/test_viewport_editability.gd:67` to that number. **Only ever lower it.**

If the suite flags `ShelfItem.gd`'s shadow `TextureRect` from Task 5, add it to the `ALLOWED` dict with a comment saying it is per-call-dynamic content on a runtime-randomised shelf — that is what `ALLOWED` is for.

- [ ] **Step 7: Run to verify both pass**

MCP: `test_run(suite="test_koperasi_tray")`, then `test_run(suite="test_viewport_editability")`
Expected: both PASS.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Koperasi/ReturSlot.tscn Scripts/Koperasi/ReturSlot.gd Scripts/Koperasi/rakbarang_1.gd tests/test_viewport_editability.gd tests/test_koperasi_tray.gd
git commit -m "refactor(koperasi): build tray slots from a scene, not at runtime"
```

---

## Task 9: Warm blurred tray surface

**Files:**
- Modify: `Scenes/Koperasi/koprasi.tscn` — `ReturPanel` surface, `BlurLayer/BlurRect` wash, `Keranjang`/`KeranjangDepan` textures, new `EmptyState` node
- Test: `tests/test_koperasi_tray.gd`

**Interfaces:**
- Consumes: `BasketTray` variation (Task 2), `tray_dots.png` (Task 7), `icon_keranjang.svg` (Task 1), `icon_keranjang_kosong.svg` (Task 6), `EmptyState` resolved by Task 8.

The blur already exists — `Rak1/BlurLayer/BlurRect` with `shop_hub_blur_material.tres`, shown by `_open_retur_panel` (line 306). This task changes its wash from neutral dim to warm and dresses the panel.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_koperasi_tray.gd`:

```gdscript
func test_tray_panel_uses_the_basket_tray_variation() -> void:
	var f := FileAccess.open("res://Scenes/Koperasi/koprasi.tscn", FileAccess.READ)
	assert_not_null(f, "koprasi.tscn missing")
	var src := f.get_as_text()
	assert_true(src.contains("BasketTray"),
		"ReturPanel should carry the BasketTray type variation")
	assert_true(src.contains("tray_dots.png"),
		"tray should wear the dot-grid tile")
	assert_true(src.contains("icon_keranjang.svg"),
		"basket should use the B3 icon, not the black silhouette")
```

- [ ] **Step 2: Run to verify it fails**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: FAIL — "ReturPanel should carry the BasketTray type variation"

- [ ] **Step 3: Dress the scene**

`scene_open` on `Scenes/Koperasi/koprasi.tscn`, then:

- `ReturPanel`: set `theme_type_variation = "BasketTray"`. If it is not a `Panel`/`PanelContainer`, a node's type can only be changed by delete-and-recreate — recreate it as a `PanelContainer` and re-parent its children.
- Add `Dots` (TextureRect) as `ReturPanel`'s **first** child: `texture` = `tray_dots.png`, `stretch_mode = 1` (tile), `mouse_filter = 2`, `layout_mode = 1`, four anchors 0/0/1/1. `node_create` appends last, so `move_node` it to index 0.
- `BlurLayer/BlurRect`: set `color` to `Color(0.52, 0.31, 0.04, 0.10)` — the warm 10% brown wash. **No black.**
- `Keranjang` and `KeranjangDepan`: swap `texture` to `res://Assets/Images/Shop/UI/icon_keranjang.svg`.
- Add `EmptyState` (a `VBoxContainer` under `ReturPanel`, `visible = false`) containing a `TextureRect` with `icon_keranjang_kosong.svg` and a `Label` reading `Keranjang kosong` on the `CaptionLabel` variation.
- `scene_save`.

Then `git diff HEAD -- '*.gd'` — confirm the save did not revert a script.

- [ ] **Step 4: Restart the editor**

You patched scripts in Tasks 4-8 and have now saved a scene. Restart before any further `scene_save` so every script tab reloads from disk — skipping this is what reverted `BuatBatik.gd` on 2026-09-10. A force-kill is safe once scenes are saved.

- [ ] **Step 5: Run to verify it passes**

MCP: `test_run(suite="test_koperasi_tray")`
Expected: PASS, 33 assertions.

- [ ] **Step 6: Verify visually at full size**

`project_run`, seed, teleport to the shop, add two or three items, tap the basket.

Check: the shelf behind is blurred rather than dimmed; the tray is warm cream with a visible but quiet dot grid; no black or cool gray anywhere in the tray; the empty state shows the outline basket rather than a `🛒`; slot art still lands where the flight ends.

Judge from a full-size `editor_screenshot`. A scaled capture cannot show whether the dots read as texture or as noise.

- [ ] **Step 7: Commit**

```bash
git add Scenes/Koperasi/koprasi.tscn tests/test_koperasi_tray.gd
git commit -m "feat(koperasi): warm blurred basket tray with the dot-grid surface"
```

---

## Task 10: Full verification and pull request

**Files:** `docs/superpowers/CHANGELOG.md` only — this task otherwise verifies.

- [ ] **Step 1: Run the whole suite**

MCP `test_run()` with no suite argument. Budget an editor restart afterwards: a full run is 15-20s of near-continuous main-thread work and reliably drops the bridge. The results are still valid when the drop happens after the reply arrives.

Expected: no new failures against the 2026-09-10 baseline of 91 suites / 1253 tests, plus the new `test_koperasi_tray`.

- [ ] **Step 2: Check the two tracked files a full run rewrites**

```bash
git status --porcelain
```

A full run rebakes `Assets/Theme/kejartes_theme.tres` — wanted here, it picks up Task 2. `AudioDirector` rewrites `default_bus_layout.tres` on boot — not wanted; `git checkout -- default_bus_layout.tres` if it moved.

- [ ] **Step 3: Update the changelog**

Add an entry to the top of `docs/superpowers/CHANGELOG.md`, newest first, covering the tags, basket, item life, tray, emoji cleanup, and the lowered `rakbarang_1.gd` BASELINE.

Also update `CLAUDE.md`'s `## Outstanding debt & placeholders`: add the four new generated assets to the placeholder path list, and note `tray_dots.png` must stay 26×26 to tile cleanly.

```bash
git add docs/superpowers/CHANGELOG.md CLAUDE.md
git commit -m "docs(koperasi): changelog and placeholder entries for the shop rework"
```

- [ ] **Step 4: Push and open the PR**

```bash
git push -u origin feat/koperasi-rework
```

Then open the PR against `Textures` with `gh pr create`, body covering: coin-pill tags with the wipe-to-Beli state and affordability greying; the B3 slatted basket replacing the black silhouette; shelf item shadow/bob/lift/dim; the warm blurred tray with its dot-grid surface replacing the hard-bordered popup; three emoji replaced with real glyphs; tray slots moved out of runtime construction, lowering `rakbarang_1.gd`'s editability BASELINE. State explicitly that the pick-item to arc-into-basket mechanic is untouched. End the body with:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Self-Review

**Spec coverage:** tray (Tasks 7-9), price tag (2-4), basket icon (1), shelf item life (5), emoji cleanup (6), theme variations (2), tests (throughout), delivery order (the Task 6 push is the commit-1 boundary). Every spec section maps to at least one task.

**Deliberate deviations from the spec:**
- The spec allows tag colors to become `DesignTokens` entries. Task 2 keeps them literal, because a new `@export` default on a Resource needs a full editor restart before it takes effect and this plan must run in one sitting. Promoting them is a clean follow-up.
- The spec named one emoji; there are three. Task 6 handles all three.
- The spec priced the tray as high-risk partly on the assumption that item layout changes. It does not: `BasketArea` (`rakbarang_1.gd:189`) already scatters landed items at random positions and rotations, which is what L3 asked for. Only `ReturPanel`'s grid changes, so Task 8 is smaller than the spec implies — and it lowers the ratchet rather than raising it.

**Type consistency:** `set_price` / `play_buy` / `set_affordable` / `get_label_text` on `PriceTag` are named identically in Task 3's definition and Tasks 4-5's call sites. `attach_to` / `lift` / `set_dimmed` on `ShelfItem` match between Task 5's definition and its wiring in the same task. `bind` / `get_caption` / `retur_requested` on `ReturSlot` match between Task 8's script, its test, and `_populate_retur_panel`. `retur_empty_state` is declared and resolved in Task 8 and created in Task 9 — Task 8's code guards it with `is_instance_valid`, so the ordering is safe.
