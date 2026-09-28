# Koperasi Top-Band, Kas Kelas Footer, and Weekly Promo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the Koperasi shop's blank top band with a signboard and a promo board, rebuild the coin counter as a legible "Kas Kelas" chip beside the cart with an asleep→awake total pill and a Beli withdrawal animation, and add a real weekly-discount mechanic drawn from the current shelf.

**Architecture:** The discount is one deterministic pick per `(grade, week)` from the freshly rolled shelf, surfaced through the single pricing chokepoint `Cart.price_of()`, so shelf tags, the running total and the affordability check all pick it up for free. All new chrome is static nodes in `.tscn` plus `ThemeFactory` type variations — no `theme_override_*`, no runtime visual construction. Animations reuse existing `AnimUtils`/`Juice` helpers driven by signals that already fire (`Cart.cart_changed`, `GameState.money_changed`).

**Tech Stack:** Godot 4.6 (GDScript, `@tool`), the project's Godot AI MCP editor bridge, `McpTestSuite` tests run in-editor via the MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-28-koperasi-top-band-promo-design.md` (read it alongside this plan).

## Global Constraints

- **Godot 4.6**, mobile renderer, portrait. Game-facing text is **Indonesian**; systems code is English.
- **Tests run only inside the editor** via the Godot AI MCP `test_run` tool — never headless. Every suite is `@tool extends McpTestSuite`, no test is a coroutine (no `await`), and any script the runner instantiates live is `@tool` with real `_ready()` side effects gated behind `if Engine.is_editor_hint(): return`.
- **Never hand-edit a `.tscn` while the editor is attached.** All scene work goes through the MCP tools: `scene_open` → `node_create`/`node_set_property`/`batch_execute` → `scene_save`. Do script work *after* scene saves, and after patching a `class_name`/Resource-`@export` script, restart the editor before the next `scene_save`.
- **After editing any `.gd` outside the editor, `filesystem_manage(op="scan")` before `test_run`**, or prefer `script_patch` (which reloads). Normalise files to LF before patching.
- **No `theme_override_*`** except layout-only constants (`separation`, `margin_*`). Use a `ThemeFactory` type variation; after editing `ThemeFactory.gd` or `DesignTokens.gd`, rebake by running `Scripts/Design/BakeTheme.gd` (File > Run) — or note that a full `test_run` rebakes `kejartes_theme.tres` in-process.
- **No visual built at runtime** (`tests/test_viewport_editability.gd` ratchet): static chrome is a node; per-load label fills go in that test's `ALLOWED` dict with a comment.
- **`Balance.gd` is owned by a collaborator** — do not edit it. New tunables of ours go in a named `const` block in the owning script (here, `GameState.gd`).
- **Persistence rule:** nothing new reaches disk. The promo is derived, not saved.
- **Commit style:** Conventional Commits with a scope, e.g. `feat(koperasi): …`. This is a handoff branch — do not open a PR; leave the work committed for the maintainer.
- Colour tokens (from `Scripts/Design/DesignTokens.gd`): `surface_card #FFFDF8`, `surface_sunken #EFE0CB`, `surface_page #FBF1E3`, `brand_primary #7A4A2B`, `brand_primary_dark #56321B`, `text_primary #3B2412`, `text_secondary #7A5C40`, `currency_gold #ffc93c`, `cat_olahraga #E03A18` (the red used for "over budget").

---

## File Structure

- `Scripts/GameState.gd` (modify) — promo derivation: `PROMO_DISCOUNTS` const, `shop_promo_item`/`shop_promo_percent` vars, pure statics `promo_item_for`/`promo_percent_for`, `shop_promo_multiplier`, set in `shop_stock_for_week()`, cleared in `forget_session()`/`reset_shop_week()`.
- `Scripts/Inventory/Cart.gd` (modify) — `price_of()` applies the promo multiplier.
- `Scripts/Koperasi/PriceTag.gd` + `Scenes/Koperasi/PriceTag.tscn` (modify) — optional promo state: struck old price + "−N%" badge.
- `Scripts/Design/ThemeFactory.gd` (modify) — new variations: `KoperasiSignLabel`, `KoperasiPromoLabel`, `KasPill`, `KasCaptionLabel`, `TotalPillAsleep`/`TotalPillAwake`/`TotalPillOver`, `TotalNumberAsleep`/`TotalNumberAwake`/`TotalNumberOver`.
- `Scripts/Koperasi/PromoBoard.gd` (create) — `@tool` script filling the promo board's two labels from GameState.
- `Scenes/Koperasi/Koperasi.tscn` (modify) — signboard + promo board nodes in the top band; remove `Stage/CoinHUD`.
- `Scenes/Koperasi/BasketTray.tscn` + `Scripts/Koperasi/BasketTray.gd` (modify) — footer twin pills (Kas + Total), pill state API.
- `Scripts/Koperasi/Koperasi.gd` (modify) — repoint coin `@onready`s to the Kas pill; Beli withdrawal animation.
- `tests/test_shop_promo.gd` (create), `tests/test_koperasi.gd` / `test_koperasi_hud.gd` / `test_theme_factory.gd` / `test_tall_screen_layout.gd` / `test_viewport_editability.gd` (modify).

---

## Task 1: Promo derivation in GameState

**Files:**
- Modify: `Scripts/GameState.gd` (add const + vars near the other shop fields ~line 46–57; add statics near `roll_shop_stock`/`shop_stock_for_week` ~line 340–367; extend `forget_session` and `reset_shop_week`)
- Test: `tests/test_shop_promo.gd` (create)

**Interfaces:**
- Produces:
  - `const GameState.PROMO_DISCOUNTS: Array[int]`
  - `var GameState.shop_promo_item: String`
  - `var GameState.shop_promo_percent: int`
  - `static GameState.promo_item_for(stock: Array, grade: int, week: int) -> String`
  - `static GameState.promo_percent_for(grade: int, week: int) -> int`
  - `static GameState.shop_promo_multiplier(item_name: String) -> float`

- [ ] **Step 1: Write the failing test.** Create `tests/test_shop_promo.gd`:

```gdscript
@tool
extends McpTestSuite

## The weekly promo: one item from this week's shelf is discounted, both the
## item and the percentage derived deterministically from (grade, week). The
## picks key off a stable hash of the week, not the global RNG, so they are
## reproducible and independent of the shelf-roll order. GameState is the live
## autoload; setup() snapshots the fields these tests write.

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
	GameState.shop_week_key = ""
	GameState.shop_stock = []
	GameState.shop_sold = []

func teardown() -> void:
	GameState.current_grade = _snap["grade"]
	GameState.minggu_ke = _snap["week"]
	GameState.shop_week_key = _snap["key"]
	GameState.shop_stock = _snap["stock"]
	GameState.shop_sold = _snap["sold"]
	GameState.shop_promo_item = _snap["promo_item"]
	GameState.shop_promo_percent = _snap["promo_pct"]

func _stock() -> Array:
	return ["Bank Soal", "Komik", "Bank Soal", "Pensil", "Susu Murni", "Roti"]

func test_promo_item_is_one_of_the_stock() -> void:
	var item := GameState.promo_item_for(_stock(), 7, 2)
	assert_true(_stock().has(item), "the promo is always something on the shelf")

func test_promo_item_is_deterministic_per_week() -> void:
	assert_eq(GameState.promo_item_for(_stock(), 7, 2), GameState.promo_item_for(_stock(), 7, 2),
		"same week, same pick")

func test_promo_item_differs_across_weeks() -> void:
	# Not guaranteed for every pair, but across a span the pick must move.
	var seen := {}
	for w in range(1, 13):
		seen[GameState.promo_item_for(_stock(), 7, w)] = true
	assert_gt(seen.size(), 1, "the promo item is not frozen to one name")

func test_empty_stock_has_no_promo() -> void:
	assert_eq(GameState.promo_item_for([], 7, 2), "", "no shelf, no promo")

func test_promo_percent_is_in_the_allowed_set() -> void:
	assert_true(GameState.PROMO_DISCOUNTS.has(GameState.promo_percent_for(7, 2)),
		"the discount is one of the authored steps")

func test_promo_percent_is_deterministic_per_week() -> void:
	assert_eq(GameState.promo_percent_for(8, 5), GameState.promo_percent_for(8, 5), "same week, same discount")

func test_multiplier_only_touches_the_promo_item() -> void:
	GameState.shop_promo_item = "Susu Murni"
	GameState.shop_promo_percent = 20
	assert_eq(GameState.shop_promo_multiplier("Susu Murni"), 0.8, "20% off the promo item")
	assert_eq(GameState.shop_promo_multiplier("Komik"), 1.0, "everything else is full price")

func test_no_promo_item_leaves_prices_untouched() -> void:
	GameState.shop_promo_item = ""
	assert_eq(GameState.shop_promo_multiplier("Komik"), 1.0, "an empty promo discounts nothing")

func test_rolling_the_week_sets_a_stock_promo() -> void:
	GameState.current_grade = 7
	GameState.minggu_ke = 2
	var stock: Array = GameState.shop_stock_for_week()
	assert_true(stock.has(GameState.shop_promo_item), "the week's promo is on the week's shelf")
	assert_true(GameState.PROMO_DISCOUNTS.has(GameState.shop_promo_percent), "and carries a real discount")

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

func test_forget_and_reset_clear_the_promo() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	for fn in ["func forget_session()", "func reset_shop_week()"]:
		var body := _body(src, fn)
		assert_true(body.contains("shop_promo_item = \"\""), fn + " clears the promo item")
```

- [ ] **Step 2: Run the test to verify it fails.** In the editor, `filesystem_manage(op="scan")`, then `test_run(suite="shop_promo")`. Expected: FAIL (unknown `PROMO_DISCOUNTS`, `promo_item_for`, etc.).

- [ ] **Step 3: Add the const and vars.** In `Scripts/GameState.gd`, near the other shop fields (after `SHOP_MAX_COPIES` ~line 48 and after `shop_sold` ~line 57), add:

```gdscript
## The discount steps a weekly promo can roll, in percent. Ours to tune
## (Balance.gd is a collaborator's); one is picked per (grade, week).
const PROMO_DISCOUNTS: Array[int] = [15, 20, 25, 30]

## This week's promo item -- one name from shop_stock -- and its discount.
## Both derived from the (grade, week) key in shop_stock_for_week(); "" / 0
## before a shelf is rolled or when the shelf is empty.
var shop_promo_item: String = ""
var shop_promo_percent: int = 0
```

- [ ] **Step 4: Add the pure statics.** In `Scripts/GameState.gd`, near `roll_shop_stock` (~line 342), add:

```gdscript
## A stable, RNG-independent hash of a (grade, week) key, so a promo pick is
## reproducible and does not depend on how far roll_shop_stock's shuffle() has
## advanced the global RNG. Pure.
static func _promo_seed(grade: int, week: int) -> int:
	return hash("promo:%d-%d" % [grade, week])

## This week's promo item: one of the DISTINCT names on `stock`, chosen by the
## (grade, week) seed. "" when the shelf is empty. Distinct names so a pair on
## the shelf still advertises a single item. Pure; a test calls it with a
## hand-built stock.
static func promo_item_for(stock: Array, grade: int, week: int) -> String:
	var names: Array = []
	for item_name in stock:
		if not names.has(item_name):
			names.append(item_name)
	if names.is_empty():
		return ""
	return names[_promo_seed(grade, week) % names.size()]

## This week's discount, one of PROMO_DISCOUNTS, chosen by the (grade, week)
## seed with a different salt so the item and the percentage roll independently.
## Pure.
static func promo_percent_for(grade: int, week: int) -> int:
	return PROMO_DISCOUNTS[hash("pct:%d-%d" % [grade, week]) % PROMO_DISCOUNTS.size()]

## Price multiplier for `item_name`: below 1.0 only for this week's promo item.
## Read by Cart.price_of, so the shelf tag, the total and the Beli check all
## agree.
static func shop_promo_multiplier(item_name: String) -> float:
	if item_name == "" or item_name != GameState.shop_promo_item:
		return 1.0
	return 1.0 - float(GameState.shop_promo_percent) / 100.0
```

- [ ] **Step 5: Set the promo when the week rolls.** In `shop_stock_for_week()` (~line 358), inside the `if key != shop_week_key:` block, after `shop_stock = roll_shop_stock(...)`, add:

```gdscript
		shop_promo_item = promo_item_for(shop_stock, current_grade, minggu_ke)
		shop_promo_percent = promo_percent_for(current_grade, minggu_ke)
```

- [ ] **Step 6: Clear the promo on reset.** In `forget_session()` and `reset_shop_week()`, wherever they set `shop_stock = []`, also add:

```gdscript
	shop_promo_item = ""
	shop_promo_percent = 0
```

- [ ] **Step 7: Run the test to verify it passes.** `filesystem_manage(op="scan")`, then `test_run(suite="shop_promo")`. Expected: PASS. Also run `test_run(suite="shop_weekly_stock")` — the shelf roll is unchanged. Expected: PASS.

- [ ] **Step 8: Commit.**

```bash
git add Scripts/GameState.gd tests/test_shop_promo.gd
git commit -m "feat(koperasi): derive a weekly promo item and discount from the shelf"
```

---

## Task 2: Apply the promo in Cart.price_of

**Files:**
- Modify: `Scripts/Inventory/Cart.gd:100-101` (`price_of`)
- Test: `tests/test_shop_promo.gd` (add cases)

**Interfaces:**
- Consumes: `GameState.shop_promo_multiplier(String) -> float` (Task 1)
- Produces: `Cart.price_of(item)` returns the promo-discounted price for the promo item.

- [ ] **Step 1: Write the failing test.** Append to `tests/test_shop_promo.gd`:

```gdscript
const CartScript := preload("res://Scripts/Inventory/Cart.gd")

func _item(name_: String, price: int) -> ItemData:
	var d := ItemData.new()
	d.item_name = name_
	d.price = price
	return d

func test_price_of_discounts_only_the_promo_item() -> void:
	GameState.shop_promo_item = "Susu Murni"
	GameState.shop_promo_percent = 20
	assert_eq(CartScript.price_of(_item("Susu Murni", 1000)), 800, "20% off the promo item")
	assert_eq(CartScript.price_of(_item("Komik", 1000)), 1000, "full price otherwise")
```

- [ ] **Step 2: Run the test to verify it fails.** `filesystem_manage(op="scan")`, then `test_run(suite="shop_promo")`. Expected: FAIL (`price_of` ignores the promo).

- [ ] **Step 3: Extend `price_of`.** In `Scripts/Inventory/Cart.gd`, replace the body of `price_of` (line 100-101) with:

```gdscript
static func price_of(item: ItemData) -> int:
	var base: float = item.price * AchievementsScript.multiplier("shop_price")
	return roundi(base * GameState.shop_promo_multiplier(item.item_name))
```

Update the `##` doc line above it to mention the weekly promo alongside the achievement discount.

- [ ] **Step 4: Run the test to verify it passes.** `test_run(suite="shop_promo")`. Expected: PASS. Run `test_run(suite="koperasi")` and `test_run(suite="koperasi_hud")` to confirm no pricing regressions. Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Scripts/Inventory/Cart.gd tests/test_shop_promo.gd
git commit -m "feat(koperasi): route the weekly promo discount through Cart.price_of"
```

---

## Task 3: Promo state on the price tag

**Files:**
- Modify: `Scenes/Koperasi/PriceTag.tscn` (add a struck-price label + "−N%" badge), `Scripts/Koperasi/PriceTag.gd`
- Modify: `Scripts/Koperasi/KoperasiStage.gd` (`_ensure_price_tag`/`setup_shelf` set promo state)
- Test: `tests/test_koperasi.gd` (add a promo-tag case)

**Interfaces:**
- Consumes: `GameState.shop_promo_item`, `GameState.shop_promo_percent`, `Cart.price_of` (Tasks 1–2)
- Produces: `PriceTag.set_promo(is_promo: bool, old_price: int, percent: int) -> void`; `PriceTag.is_promo() -> bool`

- [ ] **Step 1: Write the failing test.** In `tests/test_koperasi.gd`, add (adjust preload if the suite already has one):

```gdscript
const PriceTagScene := preload("res://Scenes/Koperasi/PriceTag.tscn")

func test_a_promo_tag_shows_the_old_price_and_badge() -> void:
	var tag := PriceTagScene.instantiate()
	tag.set_price(800)
	tag.set_promo(true, 1000, 20)
	assert_true(tag.is_promo(), "the tag knows it is on promo")
	assert_eq(tag.get_old_price_text(), "1000", "the pre-discount price is shown, struck")
	assert_true(tag.get_badge_text().contains("20"), "the badge names the percent")
	tag.set_promo(false, 0, 0)
	assert_false(tag.is_promo(), "a normal tag drops the promo chrome")
	tag.free()
```

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="koperasi")`. Expected: FAIL (`set_promo` undefined).

- [ ] **Step 3: Add the promo nodes to `PriceTag.tscn` via the editor.** `scene_open("res://Scenes/Koperasi/PriceTag.tscn")`. Add, as children of the tag root:
  - `OldPrice` (`Label`), `theme_type_variation = "CaptionLabel"`, `visible = false`. It shows the pre-discount price with a strikethrough. (Strikethrough: set the label's text and let `PriceTag.gd` wrap it; there is no built-in strike, so render it as a `Label` whose font is the body font and draw a 2px `ColorRect` line over it — add a `Strike` `ColorRect` child of `OldPrice`, `visible=false`, colour `text_secondary`.)
  - `PromoBadge` (`Label`), `theme_type_variation = "MicroLabel"`, `visible = false`, positioned top-right of the pill, text like `−20%`. Give it a small `StyleBoxFlat` background via a new `PromoBadge` variation (Task 4) — for now just the Label.
  `scene_save`.

- [ ] **Step 4: Extend `PriceTag.gd`.** Add (LF file; use `script_patch`):

```gdscript
@onready var _old_price: Label = get_node_or_null("OldPrice")
@onready var _promo_badge: Label = get_node_or_null("PromoBadge")

var _is_promo: bool = false

## Puts the tag into (or out of) promo dress: the discounted price stays in the
## main pill (set_price already showed it); the pre-discount price shows struck
## above, and a "-N%" badge sits on the pill. Idempotent.
func set_promo(is_promo: bool, old_price: int, percent: int) -> void:
	_is_promo = is_promo
	if not is_instance_valid(_old_price):
		_old_price = get_node_or_null("OldPrice")
	if not is_instance_valid(_promo_badge):
		_promo_badge = get_node_or_null("PromoBadge")
	if is_instance_valid(_old_price):
		_old_price.visible = is_promo
		_old_price.text = str(old_price)
		var strike := _old_price.get_node_or_null("Strike")
		if strike:
			strike.visible = is_promo
	if is_instance_valid(_promo_badge):
		_promo_badge.visible = is_promo
		_promo_badge.text = "-%d%%" % percent

func is_promo() -> bool:
	return _is_promo

func get_old_price_text() -> String:
	if not is_instance_valid(_old_price):
		_old_price = get_node_or_null("OldPrice")
	return _old_price.text if is_instance_valid(_old_price) else ""

func get_badge_text() -> String:
	if not is_instance_valid(_promo_badge):
		_promo_badge = get_node_or_null("PromoBadge")
	return _promo_badge.text if is_instance_valid(_promo_badge) else ""
```

- [ ] **Step 5: Wire the shelf to set promo state.** In `Scripts/Koperasi/KoperasiStage.gd`, inside `setup_shelf()` where each `tag` is set up (after `tag.set_price(Cart.price_of(item))`, ~line 114), add:

```gdscript
			var is_promo := item.item_name == GameState.shop_promo_item
			tag.set_promo(is_promo, item.price, GameState.shop_promo_percent)
```

(`item.price` is the undiscounted catalog price; `Cart.price_of(item)` already returned the discounted one for the main pill.)

- [ ] **Step 6: Run to verify it passes.** `filesystem_manage(op="scan")`, `test_run(suite="koperasi")`. Expected: PASS.

- [ ] **Step 7: Commit.**

```bash
git add Scenes/Koperasi/PriceTag.tscn Scripts/Koperasi/PriceTag.gd Scripts/Koperasi/KoperasiStage.gd tests/test_koperasi.gd
git commit -m "feat(koperasi): show the struck price and -N% badge on the promo tag"
```

---

## Task 4: ThemeFactory variations for the band and footer

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add a `_build_koperasi_chrome` block, called from the main build)
- Test: `tests/test_theme_factory.gd` (pin the new variations)

**Interfaces:**
- Produces theme type variations: `KoperasiSignLabel`, `KoperasiPromoLabel`, `PromoBadge`, `KasPill`, `KasCaptionLabel`, `TotalPillAsleep`, `TotalPillAwake`, `TotalPillOver`, `TotalNumberAsleep`, `TotalNumberAwake`, `TotalNumberOver`.

- [ ] **Step 1: Write the failing test.** In `tests/test_theme_factory.gd`, add:

```gdscript
func test_koperasi_chrome_variations_exist() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	for v in ["KoperasiSignLabel", "KoperasiPromoLabel", "PromoBadge", "KasPill",
			"KasCaptionLabel", "TotalPillAsleep", "TotalPillAwake", "TotalPillOver",
			"TotalNumberAsleep", "TotalNumberAwake", "TotalNumberOver"]:
		assert_true(theme.has_theme_item_type_list("StyleBox").has(v)
			or theme.get_type_variation_base(v) != "",
			v + " is a registered variation")

func test_total_over_number_is_the_red_token() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_color("font_color", "TotalNumberOver"), tokens.cat_olahraga,
		"the over-budget total reads in the danger red")
```

(Confirm `ThemeFactory.build(...)` is the real entry name; match whatever `test_theme_factory.gd` already calls.)

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="theme_factory")`. Expected: FAIL.

- [ ] **Step 3: Add the chrome builder.** In `Scripts/Design/ThemeFactory.gd`, add a `static func _build_koperasi_chrome(theme, tokens)` following the `_build_picker` idiom (lines 154+), and call it from the same place the other `_build_*` are called (near line 37). Define:

```gdscript
static func _build_koperasi_chrome(theme: Theme, tokens: DesignTokens) -> void:
	# Signboard + promo board display text.
	theme.add_type("KoperasiSignLabel")
	theme.set_type_variation("KoperasiSignLabel", "Label")
	if tokens.font_display != null:
		theme.set_font("font", "KoperasiSignLabel", tokens.font_display)
	theme.set_font_size("font_size", "KoperasiSignLabel", tokens.font_h1)
	theme.set_color("font_color", "KoperasiSignLabel", tokens.surface_card)

	theme.add_type("KoperasiPromoLabel")
	theme.set_type_variation("KoperasiPromoLabel", "Label")
	if tokens.font_display != null:
		theme.set_font("font", "KoperasiPromoLabel", tokens.font_display)
	theme.set_font_size("font_size", "KoperasiPromoLabel", tokens.font_h2)
	theme.set_color("font_color", "KoperasiPromoLabel", tokens.surface_card)

	var badge := StyleBoxFlat.new()
	badge.bg_color = tokens.cat_olahraga
	badge.set_corner_radius_all(tokens.radius_pill)
	badge.content_margin_left = 8
	badge.content_margin_right = 8
	theme.add_type("PromoBadge")
	theme.set_type_variation("PromoBadge", "Label")
	theme.set_stylebox("normal", "PromoBadge", badge)
	theme.set_color("font_color", "PromoBadge", tokens.surface_card)
	theme.set_font_size("font_size", "PromoBadge", tokens.font_micro)

	# Kas Kelas pill: cream, brown stroke, a darker bottom border for the bevel.
	var kas := StyleBoxFlat.new()
	kas.bg_color = tokens.surface_card
	kas.set_border_width_all(3)
	kas.border_width_bottom = 6
	kas.border_color = tokens.brand_primary
	kas.set_corner_radius_all(tokens.radius_md)
	kas.content_margin_left = 14
	kas.content_margin_right = 16
	kas.content_margin_top = 8
	kas.content_margin_bottom = 8
	theme.add_type("KasPill")
	theme.set_type_variation("KasPill", "PanelContainer")
	theme.set_stylebox("panel", "KasPill", kas)

	theme.add_type("KasCaptionLabel")
	theme.set_type_variation("KasCaptionLabel", "Label")
	theme.set_font_size("font_size", "KasCaptionLabel", tokens.font_micro)
	theme.set_color("font_color", "KasCaptionLabel", tokens.text_secondary)

	# Total pill: three states. Asleep = sunken beige; Awake = same shell as Kas;
	# Over = red stroke. Number colour tracks each state.
	var asleep := StyleBoxFlat.new()
	asleep.bg_color = tokens.surface_sunken
	asleep.set_border_width_all(3)
	asleep.border_width_bottom = 6
	asleep.border_color = tokens.surface_sunken.darkened(0.12)
	asleep.set_corner_radius_all(tokens.radius_md)
	for m in ["left", "right", "top", "bottom"]:
		asleep.set("content_margin_" + m, 10 if m in ["top", "bottom"] else 16)
	theme.add_type("TotalPillAsleep")
	theme.set_type_variation("TotalPillAsleep", "PanelContainer")
	theme.set_stylebox("panel", "TotalPillAsleep", asleep)

	var awake := kas.duplicate()
	theme.add_type("TotalPillAwake")
	theme.set_type_variation("TotalPillAwake", "PanelContainer")
	theme.set_stylebox("panel", "TotalPillAwake", awake)

	var over := kas.duplicate()
	over.border_color = tokens.cat_olahraga
	theme.add_type("TotalPillOver")
	theme.set_type_variation("TotalPillOver", "PanelContainer")
	theme.set_stylebox("panel", "TotalPillOver", over)

	for pair in [["TotalNumberAsleep", tokens.text_secondary.lightened(0.25)],
			["TotalNumberAwake", tokens.text_primary],
			["TotalNumberOver", tokens.cat_olahraga]]:
		theme.add_type(pair[0])
		theme.set_type_variation(pair[0], "Label")
		if tokens.font_display != null:
			theme.set_font("font", pair[0], tokens.font_display)
		theme.set_font_size("font_size", pair[0], tokens.font_title)
		theme.set_color("font_color", pair[0], pair[1])
```

If a referenced token (`radius_pill`, `radius_md`, `font_h1`, `font_micro`, `font_title`) is named differently in `DesignTokens.gd`, use the actual name — grep `DesignTokens.gd` first.

- [ ] **Step 4: Rebake and run.** Run `Scripts/Design/BakeTheme.gd` (File > Run) to write `kejartes_theme.tres`, then `test_run(suite="theme_factory")`. Expected: PASS. (Remember `test_run` full-suite also rebakes; commit the rebaked `kejartes_theme.tres`.)

- [ ] **Step 5: Commit.**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd
git commit -m "feat(design): koperasi signboard, promo badge, and Kas/Total pill variations"
```

---

## Task 5: The top band — signboard + promo board

**Files:**
- Create: `Scripts/Koperasi/PromoBoard.gd`
- Modify: `Scenes/Koperasi/Koperasi.tscn` (add Signboard + PromoBoard nodes under `Stage`, in the `y < 300` band; remove `Stage/CoinHUD`)
- Test: `tests/test_koperasi.gd` (band nodes present), `tests/test_viewport_editability.gd` (ALLOWED entry for PromoBoard's per-load labels)

**Interfaces:**
- Consumes: `GameState.shop_promo_item`, `GameState.shop_promo_percent` (Task 1); theme variations (Task 4)
- Produces: nodes `Stage/Signboard`, `Stage/PromoBoard`; `PromoBoard.gd` fills its labels on `_ready`.

- [ ] **Step 1: Write the failing test.** In `tests/test_koperasi.gd`:

```gdscript
func test_the_top_band_has_a_sign_and_a_promo_board() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Koperasi/Koperasi.tscn")
	assert_true(src.contains("name=\"Signboard\""), "the shop names itself")
	assert_true(src.contains("name=\"PromoBoard\""), "and advertises the week's promo")
	assert_false(src.contains("name=\"CoinHUD\""), "the old ledge coin HUD is gone")

func test_promo_board_reads_gamestate() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/PromoBoard.gd")
	assert_true(src.contains("GameState.shop_promo_item"), "the board names the promo item")
	assert_true(src.contains("GameState.shop_promo_percent"), "and its discount")
	assert_true(src.contains("Engine.is_editor_hint()"), "its live fill is editor-gated")
```

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="koperasi")`. Expected: FAIL.

- [ ] **Step 3: Write `PromoBoard.gd`.** Create `Scripts/Koperasi/PromoBoard.gd`:

```gdscript
@tool
extends Control

## The koperasi promo board (Koperasi.tscn:Stage/PromoBoard): a hanging board
## that advertises this week's discounted item. Static chrome -- the board, its
## frame and its two labels live in the scene; this script only fills the two
## labels from GameState on arrival, since the promo changes each week. The fill
## is the sole per-load dynamic bit and is listed in test_viewport_editability's
## ALLOWED dict.

## The label naming the promo item (e.g. "Susu Murni").
@export var item_label_path: NodePath
## The label naming the discount (e.g. "-20%").
@export var percent_label_path: NodePath

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_fill()

## Fills the two labels from GameState's current promo. Public so a test or a
## debug reseed can refresh it.
func _fill() -> void:
	var item := get_node_or_null(item_label_path) as Label
	var pct := get_node_or_null(percent_label_path) as Label
	if item:
		item.text = GameState.shop_promo_item
	if pct:
		pct.text = "-%d%%" % GameState.shop_promo_percent
```

- [ ] **Step 4: Build the band nodes in the editor.** `scene_open("res://Scenes/Koperasi/Koperasi.tscn")`. Then:
  - Delete `Stage/CoinHUD` (`node_manage` delete). Its balance moves to the footer in Task 6.
  - Add `Stage/Signboard` (`Panel` or `TextureRect` if a sign texture exists; otherwise a `PanelContainer` with the brown look). Position in the left of the band: `offset_left≈36, offset_top≈24, offset_right≈560, offset_bottom≈150`. Under it a `Label` with `theme_type_variation="KoperasiSignLabel"`, text `"KOPERASI"`, and a second `CaptionLabel` `"SEKOLAH"`. Static text, so no script.
  - Add `Stage/PromoBoard` (`Control`), script `PromoBoard.gd`, in the right of the band: `offset_left≈600, offset_top≈22, offset_right≈1044, offset_bottom≈150`. Children: a board `Panel`/`TextureRect`, a header `Label` `KoperasiPromoLabel` with static text `"PROMO MINGGU INI"`, an `ItemLabel` (`Label`, `KoperasiPromoLabel`) and a `PercentLabel` (`Label`, `PromoBadge`). Set `PromoBoard`'s `@export`s `item_label_path`/`percent_label_path` to those two nodes (set the exports on the `PromoBoard` root — overrides on an instanced sub-scene's children do not serialise; here the labels are plain children of a scripted `Control` in this same scene, so pathing from the root is fine).
  `scene_save`.

- [ ] **Step 5: Add the ALLOWED entry.** In `tests/test_viewport_editability.gd`, add a commented `ALLOWED` entry for `PromoBoard.gd`'s `_fill()` (per-load dynamic text from GameState — the promo rotates weekly, so it cannot be authored static). Follow the file's existing `ALLOWED` shape.

- [ ] **Step 6: Run to verify it passes.** `filesystem_manage(op="scan")`, `test_run(suite="koperasi")`, `test_run(suite="viewport_editability")`. Expected: PASS.

- [ ] **Step 7: Commit.**

```bash
git add Scenes/Koperasi/Koperasi.tscn Scripts/Koperasi/PromoBoard.gd tests/test_koperasi.gd tests/test_viewport_editability.gd
git commit -m "feat(koperasi): fill the top band with a signboard and a promo board"
```

---

## Task 6: The Kas Kelas + Total footer

**Files:**
- Modify: `Scenes/Koperasi/BasketTray.tscn` (footer: add `KasPill` cluster + `TotalPill`), `Scripts/Koperasi/BasketTray.gd`
- Modify: `Scripts/Koperasi/Koperasi.gd` (repoint `coin_hud`/`coin_label` `@onready`s to the Kas pill's label; keep `_update_coin_display`)
- Test: `tests/test_koperasi_hud.gd`

**Interfaces:**
- Consumes: theme variations (Task 4); `Cart.total_of` / `Cart.cart_changed`; `GameState.player_money` / `money_changed`
- Produces: `BasketTray.set_total_state(entries: Dictionary, kas: int) -> void` — swaps the Total pill between asleep/awake/over and updates the number; `BasketTray.get_kas_label() -> Label`.

- [ ] **Step 1: Write the failing test.** In `tests/test_koperasi_hud.gd`:

```gdscript
const TrayScene := preload("res://Scenes/Koperasi/BasketTray.tscn")

func test_total_pill_is_asleep_when_empty() -> void:
	var tray := TrayScene.instantiate()
	add_child(tray)
	tray.set_total_state({}, 3880)
	var pill := tray.get_node("Body/Footer/TotalPill")
	assert_eq(pill.theme_type_variation, &"TotalPillAsleep", "an empty cart sleeps")
	tray.free()

func test_total_pill_wakes_with_items() -> void:
	var tray := TrayScene.instantiate()
	add_child(tray)
	var entries := {"Komik": {"data": _komik(1000), "quantity": 1}}
	tray.set_total_state(entries, 3880)
	assert_eq(tray.get_node("Body/Footer/TotalPill").theme_type_variation, &"TotalPillAwake",
		"items wake it")
	tray.free()

func test_total_pill_flags_over_budget() -> void:
	var tray := TrayScene.instantiate()
	add_child(tray)
	var entries := {"Komik": {"data": _komik(5000), "quantity": 1}}
	tray.set_total_state(entries, 3880)
	assert_eq(tray.get_node("Body/Footer/TotalPill").theme_type_variation, &"TotalPillOver",
		"a total past the kas turns over-budget")
	tray.free()

func _komik(price: int) -> ItemData:
	var d := ItemData.new(); d.item_name = "Komik"; d.price = price; return d
```

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="koperasi_hud")`. Expected: FAIL.

- [ ] **Step 3: Rebuild the footer in the editor.** `scene_open("res://Scenes/Koperasi/BasketTray.tscn")`. In `Body/Footer` (HBoxContainer):
  - Add, before `TotalLabel`, a `KasCluster` `VBoxContainer`: a `Label` `KasCaptionLabel` text `"KAS KELAS"`, and a `KasPill` `PanelContainer` holding an HBox of a coin `TextureRect` (reuse the old CoinHUD's `CoinIcon` texture) + a `KasLabel` `Label` (`TotalNumberAwake` variation for the dark cream number).
  - Replace `TotalLabel` with a `TotalCluster` `VBoxContainer`: a `Label` `KasCaptionLabel` text `"TOTAL"`, and a `TotalPill` `PanelContainer` (`theme_type_variation="TotalPillAsleep"`) holding a coin `TextureRect` + a `TotalNumber` `Label` (`TotalNumberAsleep`), text `"0"`.
  - Keep `BeliButton`, give it `size_flags_vertical = 3` (fill) so it grows to the cluster height.
  `scene_save`.

- [ ] **Step 4: Add the tray API.** In `Scripts/Koperasi/BasketTray.gd` (via `script_patch`, LF):

```gdscript
@onready var _total_pill: PanelContainer = get_node_or_null("Body/Footer/TotalCluster/TotalPill")
@onready var _total_number: Label = get_node_or_null("Body/Footer/TotalCluster/TotalPill/Row/TotalNumber")
@onready var _kas_label: Label = get_node_or_null("Body/Footer/KasCluster/KasPill/Row/KasLabel")

## The Kas pill's label, for Koperasi.gd to drive the balance count-up.
func get_kas_label() -> Label:
	if not is_instance_valid(_kas_label):
		_kas_label = get_node_or_null("Body/Footer/KasCluster/KasPill/Row/KasLabel")
	return _kas_label

## Swap the Total pill between asleep (empty), awake (items, affordable) and
## over (items, total > kas), and set its number. `entries` is Cart.cart-shaped.
func set_total_state(entries: Dictionary, kas: int) -> void:
	if not is_instance_valid(_total_pill):
		_total_pill = get_node_or_null("Body/Footer/TotalCluster/TotalPill")
		_total_number = get_node_or_null("Body/Footer/TotalCluster/TotalPill/Row/TotalNumber")
	var total: int = CART_SCRIPT.total_of(entries)
	var awake: bool = not entries.is_empty()
	var over: bool = awake and total > kas
	var pill_var := &"TotalPillAsleep"
	var num_var := &"TotalNumberAsleep"
	if over:
		pill_var = &"TotalPillOver"; num_var = &"TotalNumberOver"
	elif awake:
		pill_var = &"TotalPillAwake"; num_var = &"TotalNumberAwake"
	if is_instance_valid(_total_pill):
		_total_pill.theme_type_variation = pill_var
	if is_instance_valid(_total_number):
		_total_number.theme_type_variation = num_var
		if is_inside_tree() and awake:
			AnimUtils.count_up(_total_number, int(str(_total_number.text).replace(".", "")), total, 0.42)
		else:
			_total_number.text = format_koin(total)
```

Call `set_total_state(entries, GameState.player_money)` from the existing `refresh(entries)` where the footer total was set (replace or sit beside the old `_total_label.text = …` at line 153). If `AnimUtils.count_up`'s signature differs, match it (grep `Scripts/AnimUtils.gd`); it must set the label text — if it does not format thousands, format after.

- [ ] **Step 5: Repoint the coin display in `Koperasi.gd`.** Replace the `coin_hud`/`coin_label` `@onready`s (lines 26-27) with:

```gdscript
@onready var kas_label: Label = tray.get_kas_label() if is_instance_valid(tray) else null
```

and rewrite `_update_coin_display()` to set `kas_label.text = format …` and pulse the Kas pill instead of the removed `%CoinHUD`. Keep the `GameState.money_changed` connection.

- [ ] **Step 6: Run to verify it passes.** `filesystem_manage(op="scan")`, `test_run(suite="koperasi_hud")`, `test_run(suite="koperasi_tray")`. Expected: PASS.

- [ ] **Step 7: Commit.**

```bash
git add Scenes/Koperasi/BasketTray.tscn Scripts/Koperasi/BasketTray.gd Scripts/Koperasi/Koperasi.gd tests/test_koperasi_hud.gd
git commit -m "feat(koperasi): twin Kas Kelas and waking Total pills in the tray footer"
```

---

## Task 7: The Beli withdrawal animation

**Files:**
- Modify: `Scripts/Koperasi/Koperasi.gd` (`_on_beli_pressed` success path)
- Test: `tests/test_koperasi_hud.gd` (source scan of the withdrawal)

**Interfaces:**
- Consumes: `AnimUtils.create_floating_text`, `AnimUtils.count_up`/`squash_bounce`; `BasketTray.get_kas_label()` (Task 6)
- Produces: on a successful Beli, a `−<total>` floats out of the Kas pill, the pill shakes, the Kas number counts down.

- [ ] **Step 1: Write the failing test.** In `tests/test_koperasi_hud.gd`:

```gdscript
func _body(src: String, sig: String) -> String:
	var at := src.find(sig)
	if at < 0: return ""
	var end := src.length()
	for m in ["\nfunc ", "\nstatic func "]:
		var n := src.find(m, at + 1)
		if n > 0: end = mini(end, n)
	return src.substr(at, end - at)

func test_beli_withdraws_from_the_kas() -> void:
	var body := _body(FileAccess.get_file_as_string("res://Scripts/Koperasi/Koperasi.gd"),
		"func _on_beli_pressed()")
	assert_true(body.contains("create_floating_text"), "a -total floats out of the kas")
	var float_at := body.find("create_floating_text")
	var deduct_at := body.find("GameState.player_money -= total")
	assert_true(deduct_at != -1 and float_at > deduct_at,
		"the withdrawal animates after the money actually leaves")
```

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="koperasi_hud")`. Expected: FAIL.

- [ ] **Step 3: Add the withdrawal.** In `Scripts/Koperasi/Koperasi.gd` `_on_beli_pressed()`, after `GameState.player_money -= total` (line 191) and before/around the existing feedback, add:

```gdscript
	var kas := tray.get_kas_label() if is_instance_valid(tray) else null
	if is_instance_valid(kas):
		AnimUtils.squash_bounce(kas.get_parent())
		AnimUtils.create_floating_text(
			get_tree().current_scene,
			"-" + str(total),
			kas.get_global_position() + kas.size / 2.0,
			Color(0.878, 0.227, 0.094)) # cat_olahraga
```

The Kas number itself counts down via the existing `GameState.money_changed` → `_update_coin_display` path — make `_update_coin_display` use `AnimUtils.count_up` on `kas_label` from its old value to `GameState.player_money` so the balance visibly ticks down (guard `is_inside_tree()`).

- [ ] **Step 4: Run to verify it passes.** `filesystem_manage(op="scan")`, `test_run(suite="koperasi_hud")`, `test_run(suite="koperasi")`. Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Scripts/Koperasi/Koperasi.gd tests/test_koperasi_hud.gd
git commit -m "feat(koperasi): animate the Beli withdrawal out of the Kas Kelas"
```

---

## Task 8: Layout, ratchet, and full-suite verification

**Files:**
- Modify: `tests/test_tall_screen_layout.gd` (re-anchor assertions for the new band + footer, if it pins Koperasi)
- Verify: full `test_run`

- [ ] **Step 1: Re-anchor for tall phones.** Confirm the Signboard/PromoBoard sit inside the band and the footer clusters re-anchor on a 20:9 (1080×2400) screen. In the editor, open `Koperasi.tscn`, check the band nodes use edge anchors inside `SafeAreaMargin`/`UI` per the authoring guide's "Tall phones". If `test_tall_screen_layout.gd` pins Koperasi rects, update its expected offsets to the new nodes; keep BackButton's pinned authored rect unchanged.

- [ ] **Step 2: Run the layout suite.** `test_run(suite="tall_screen_layout")`. Expected: PASS.

- [ ] **Step 3: Full suite.** Budget one editor restart for this. Open `Scenes/MainMenu/MainMenu.tscn` (some suites need the main scene open), then `test_run()` (no `suite`). Expected: all green. Check `git status` afterward — `kejartes_theme.tres` and `default_bus_layout.tres` may be rewritten by the run; commit the intended theme rebake (Task 4 already staged it) and `git checkout --` the bus layout if you did not intend it.

- [ ] **Step 4: Screenshot check (manual, optional but recommended).** Debug overlay → General → ⚡ Seed Playtest State, then Scenes → teleport toward the shop (or run the game to the Lobby → Koperasi). Confirm: the band reads (sign left, promo right), the promo item on the shelf shows a struck price + badge, the Kas pill is legible, the Total pill sleeps then wakes and counts up as you tap items, over-budget turns red, and Beli floats a `−total` out of the Kas.

- [ ] **Step 5: Commit any layout fixes.**

```bash
git add tests/test_tall_screen_layout.gd Scenes/Koperasi/Koperasi.tscn
git commit -m "test(koperasi): pin the new top-band and footer layout on tall phones"
```

---

## Self-review notes for the executor

- **Spec coverage:** Part 1 (promo) → Tasks 1–3, 5; Part 2 (top band) → Task 5 + Task 4; Part 3 (footer + withdrawal) → Tasks 4, 6, 7. Layout/ratchet/tests → Task 8.
- **Token names:** the ThemeFactory code assumes `radius_md`, `radius_pill`, `font_h1`, `font_h2`, `font_title`, `font_micro`, `cat_olahraga` exist in `DesignTokens.gd`. Grep and substitute the real names before running Task 4.
- **`AnimUtils` signatures:** `count_up`, `create_floating_text`, `squash_bounce` are used by name — confirm each signature in `Scripts/AnimUtils.gd` and adapt the calls.
- **`CoinHUD` references:** before deleting the node (Task 5), grep the repo for `%CoinHUD` and `Stage/CoinHUD` — only `Koperasi.gd` should reference it; repoint or drop each hit.
- **Editor hazards:** do scene edits before script edits within a task; after patching a script, restart the editor before the next `scene_save`; rescan after any out-of-editor `.gd` write.
