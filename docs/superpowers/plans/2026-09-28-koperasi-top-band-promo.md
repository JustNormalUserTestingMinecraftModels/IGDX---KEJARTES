# Koperasi Top-Band, Kas Kelas Footer, and Weekly Promo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the Koperasi shop's blank top band with a signboard and a promo board, rebuild the coin counter as a legible "Kas Kelas" pill beside the cart with an asleep→awake total pill and a Beli withdrawal animation, and add a real weekly-discount mechanic drawn from the current shelf.

**Architecture:** The discount is one deterministic pick per `(grade, week)` from the freshly rolled shelf, surfaced through the single pricing chokepoint `Cart.price_of()`, so shelf tags, the running total and the affordability check all pick it up for free. All new chrome is static nodes in `.tscn` plus `ThemeFactory` type variations built in the **UI depth pass** language (`LippedBox` faces on a solid lip, the accent palette, outlined display lettering). No `theme_override_*`, no runtime visual construction. Animations reuse `Juice`/`AnimUtils`, driven by signals that already fire (`Cart.cart_changed`, `GameState.money_changed`).

**Tech Stack:** Godot 4.6 (GDScript, `@tool`), the Godot AI MCP editor bridge, `McpTestSuite` suites run in-editor via `test_run`.

**Spec:** `docs/superpowers/specs/2026-09-28-koperasi-top-band-promo-design.md`. **Look:** `docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md` (on `feat/ui-depth-pass`).

## Revision (2026-09-28, maintainer)

The collaborator's handoff plan was revised before building, for two things
that landed after it was written:

1. **The clean-code standard** (`docs/superpowers/design/clean-code.md`,
   ratcheted by `tests/test_clean_code.gd`): no `var x := <Autoload>.…`
   (`test_project_hygiene`), typed loop variables and locals, named constants,
   node references taken once through `%` unique names, and a `push_error`
   when a node the scene must carry is missing. Signals up, calls down: the
   tray owns its own labels, and `Koperasi.gd` calls `tray.show_kas()` /
   `tray.play_withdrawal()` instead of reaching into the tray for a Label.
   Boy Scout: `forget_session()` now calls `reset_shop_week()` rather than
   repeating its three lines, so the promo is cleared in one place.
2. **The UI depth pass** (being built on `feat/ui-depth-pass`): every new
   surface is a `LippedBox` face on a lip, in the accent palette, with the
   depth pass's text rule (outlined `text_on_brand` on a dark face, plain
   `text_primary` on a light one). Concretely:
   - Signboard: the **brown** role (`brand_primary` on `brand_primary_dark`,
     as `SecondaryButton`), outlined white Boohong lettering.
   - Promo board: the **cream** role (`button_cream` on `button_cream_lip`),
     with a **tangerine** "−N%" badge (the palette reserves tangerine for the
     Koperasi badge).
   - Kas pill and awake Total pill: cream on its lip, no stroke (the spec's
     "no cream rim").
   - Total asleep: the depth pass's **disabled** look (face faded
     `DISABLED_FADE` toward `surface_sunken`, half lip).
   - Total over budget: cream face on a **tomato** lip, number in
     `accent_tomato_lip` (the darker tomato reads on cream).
   - Beli stays `PrimaryButtonM`, which the depth pass turns mint.

   The promo tag's struck price is a `Panel` line with its own variation, not
   a `ColorRect` with a colour literal.

**Correctness fix:** the struck "old price" is the price **before the
promo but after the achievement discount** (`Cart.list_price_of()`), so
`old × (1 − N%)` equals the shown price even while Pembimbing Legendaris's
discount is claimed.

## Sequencing

- **Tasks 1–2** (the promo system: no visuals) build on `Textures`.
- **Before Task 3**, merge the UI depth pass branch (`git merge
  feat/ui-depth-pass`; theme-bake conflicts resolve by rebaking, never by
  hand). Tasks 3+ need its `LippedBox`, accent tokens and `DISABLED_FADE`.
- The PR opens as a **draft labelled `hold`** until the depth pass's Phase 1
  PR has merged into `Textures`; then merge `origin/Textures`, rerun the full
  suite, and ship.

## Global Constraints

- **Godot 4.6**, mobile renderer, portrait. Game-facing text is **Indonesian**; systems code is English.
- **Tests run only inside the editor** via `test_run`, never headless. Every suite is `@tool extends McpTestSuite`, no test is a coroutine (no `await`), and any script the runner instantiates live is `@tool` with real `_ready()` side effects gated behind `if Engine.is_editor_hint(): return`.
- **Never hand-edit a `.tscn` while the editor is attached.** Scene work goes through `scene_open` → `node_create`/`node_set_property`/`batch_execute` → `scene_save`. Scene work first, script work second; after patching a script, restart the editor before the next `scene_save`, and diff every `.gd` after a save.
- **Instance overrides only serialise on an instanced scene's root.** Never set a property on a child of an instanced sub-scene.
- **No `theme_override_*`** except layout-only constants (`separation`, `margin_*`). After editing `ThemeFactory.gd`, rebake alone (`test_run(suite="theme_rebake")`), restart the editor, and verify the bake by content before committing.
- **No visual built at runtime** (`tests/test_viewport_editability.gd`). Setting a label's text is not construction; `AnimUtils.create_floating_text` is an already-allowed helper.
- **Clean code:** every new script has a `##` header and every `@export` a `##` line; typed everything; named constants for meaningful numbers (layout numbers live in the `.tscn`); no `var x := <Autoload>.…`. Run `test_run(suite="clean_code")` at the end of each task; when a count shrinks, lock it in with `ci/clean_code_dump.gd` in the same commit.
- **`Balance.gd` is a collaborator's** — never edit it. The promo tunables are ours and live in `GameState.gd`.
- **Persistence rule:** nothing new reaches disk. The promo is derived, not saved.
- **Commits:** Conventional Commits with a scope, ending with the session's attribution trailer.

---

## File Structure

- `Scripts/GameState.gd` (modify) — `PROMO_DISCOUNTS`, `shop_promo_item`/`shop_promo_percent`, pure statics `promo_item_for`/`promo_percent_for`/`promo_multiplier`, instance `shop_promo_multiplier`; set in `shop_stock_for_week()`, cleared in `reset_shop_week()` (which `forget_session()` now calls).
- `Scripts/Inventory/Cart.gd` (modify) — `list_price_of()` (achievement discount only) and `price_of()` (× promo).
- `Scenes/Koperasi/PriceTag.tscn` + `Scripts/Koperasi/PriceTag.gd` (modify) — promo dress: struck list price + tangerine "−N%" badge.
- `Scripts/Koperasi/KoperasiStage.gd` (modify) — dresses the promo item's tag.
- `Scripts/Design/ThemeFactory.gd` (modify) — `_build_koperasi_chrome()`; drop the unused `ShopCoinLabel`.
- `Scripts/Koperasi/PromoBoard.gd` (create) — fills the board's two labels from `GameState`.
- `Scenes/Koperasi/Koperasi.tscn` (modify) — `Stage/Signboard`, `Stage/PromoBoard`; remove `Stage/CoinHUD`.
- `Scenes/Koperasi/BasketTray.tscn` + `Scripts/Koperasi/BasketTray.gd` (modify) — twin Kas / Total pills; `show_kas()`, `play_withdrawal()`.
- `Scripts/Koperasi/Koperasi.gd` (modify) — drives the Kas through the tray; the withdrawal after a Beli.
- Tests: `tests/test_shop_promo.gd` (create); `test_koperasi.gd`, `test_koperasi_hud.gd`, `test_basket_tray.gd`, `test_theme_factory.gd`, `test_tall_screen_layout.gd`, `test_parallax_diorama.gd` (modify).

---

## Task 1: Promo derivation in GameState

**Files:** Modify `Scripts/GameState.gd` (shop fields ~line 46–57, statics near `roll_shop_stock` ~line 338–370, `reset_shop_week` ~330, `forget_session` ~400). Create `tests/test_shop_promo.gd`.

**Produces:**
- `const PROMO_DISCOUNTS: Array[int]`, `const PERCENT_SCALE: float = 100.0`
- `var shop_promo_item: String`, `var shop_promo_percent: int`
- `static func promo_item_for(stock: Array[String], grade: int, week: int) -> String`
- `static func promo_percent_for(grade: int, week: int) -> int`
- `static func promo_multiplier(item_name: String, promo_item: String, percent: int) -> float` (pure)
- `func shop_promo_multiplier(item_name: String) -> float` (this week's, via the pure one)

- [ ] **Step 1: Write the failing test.** Create `tests/test_shop_promo.gd`:

```gdscript
@tool
extends McpTestSuite

## The weekly promo: one item from this week's shelf is discounted, both the
## item and the percentage derived deterministically from (grade, week). The
## picks hash the week key rather than use the global RNG, so they are
## reproducible and independent of the shelf roll's shuffle(). GameState is
## the live autoload; setup() snapshots every field these tests write.

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
	assert_almost_eq(GameState.promo_multiplier("Susu Murni", "Susu Murni", 20), 0.8, 0.0001,
		"20% off the promo item")
	assert_eq(GameState.promo_multiplier("Komik", "Susu Murni", 20), 1.0,
		"everything else is full price")
	assert_eq(GameState.promo_multiplier("", "", 20), 1.0, "an empty promo discounts nothing")

func test_this_weeks_multiplier_reads_the_rolled_promo() -> void:
	GameState.shop_promo_item = "Susu Murni"
	GameState.shop_promo_percent = 25
	assert_almost_eq(GameState.shop_promo_multiplier("Susu Murni"), 0.75, 0.0001,
		"the live promo is applied")
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
```

Check `McpTestSuite` has `assert_almost_eq` and `assert_gt` (grep `addons/godot_ai/testing/test_suite.gd`); use what it offers.

- [ ] **Step 2: Run it to verify it fails.** `test_run(suite="shop_promo")`. Expected: FAIL (unknown members).

- [ ] **Step 3: Add the consts and vars** after `shop_sold` (~line 57):

```gdscript
## The discount steps a weekly promo can roll, in percent. Ours to tune
## (Balance.gd is a collaborator's); one is picked per (grade, week).
const PROMO_DISCOUNTS: Array[int] = [15, 20, 25, 30]
## Percent to fraction.
const PERCENT_SCALE: float = 100.0

## This week's promo item -- one name from shop_stock -- and its discount in
## percent. Both derived from the (grade, week) key in shop_stock_for_week();
## "" and 0 before a shelf is rolled or when the shelf is empty.
var shop_promo_item: String = ""
var shop_promo_percent: int = 0
```

- [ ] **Step 4: Add the statics** after `roll_shop_stock` (~line 356):

```gdscript
## This week's promo item: one of the DISTINCT names on `stock`, picked by a
## hash of the (grade, week) key -- not the global RNG, which roll_shop_stock's
## shuffle() advances. Distinct, so a pair on the shelf still advertises one
## item. "" for an empty shelf. Pure.
static func promo_item_for(stock: Array[String], grade: int, week: int) -> String:
	var names: Array[String] = []
	for item_name: String in stock:
		if not names.has(item_name):
			names.append(item_name)
	if names.is_empty():
		return ""
	return names[posmod(hash("promo:" + shop_week_key_for(grade, week)), names.size())]

## This week's discount, one of PROMO_DISCOUNTS, from a differently salted
## hash so the item and the percentage roll independently. Pure.
static func promo_percent_for(grade: int, week: int) -> int:
	var at: int = posmod(hash("pct:" + shop_week_key_for(grade, week)), PROMO_DISCOUNTS.size())
	return PROMO_DISCOUNTS[at]

## Price multiplier for `item_name` under a promo on `promo_item` at `percent`:
## below 1.0 only for the promo item. Pure.
static func promo_multiplier(item_name: String, promo_item: String, percent: int) -> float:
	if item_name == "" or item_name != promo_item:
		return 1.0
	return 1.0 - percent / PERCENT_SCALE

## This week's promo multiplier for `item_name`. Cart.price_of reads it, so the
## shelf tag, the running total and the Beli check all agree.
func shop_promo_multiplier(item_name: String) -> float:
	return promo_multiplier(item_name, shop_promo_item, shop_promo_percent)
```

- [ ] **Step 5: Set the promo when the week rolls.** In `shop_stock_for_week()`, inside `if key != shop_week_key:`, right after `shop_stock = roll_shop_stock(...)`:

```gdscript
		shop_promo_item = promo_item_for(shop_stock, current_grade, minggu_ke)
		shop_promo_percent = promo_percent_for(current_grade, minggu_ke)
```

- [ ] **Step 6: Clear it in one place.** Add `shop_promo_item = ""` and `shop_promo_percent = 0` to `reset_shop_week()`, and replace `forget_session()`'s own `shop_week_key = ""` / `shop_stock = []` / `shop_sold = []` lines with a single `reset_shop_week()` call. Update `reset_shop_week`'s `##` line to mention the promo.

- [ ] **Step 7: Run to verify it passes.** `test_run(suite="shop_promo")`, `test_run(suite="shop_weekly_stock")`, `test_run(suite="clean_code")`, `test_run(suite="project_hygiene")`. Expected: PASS. If `clean_code` reports a count shrank, run the dump tool and commit the baseline too.

- [ ] **Step 8: Commit** `feat(koperasi): derive a weekly promo item and discount from the shelf`.

---

## Task 2: Apply the promo in Cart

**Files:** Modify `Scripts/Inventory/Cart.gd` (`price_of`, ~line 98–101). Add cases to `tests/test_shop_promo.gd`.

**Produces:** `static Cart.list_price_of(item) -> int` (achievement discount only: what the shelf showed before this pass) and `static Cart.price_of(item) -> int` (`list × promo`).

- [ ] **Step 1: Write the failing test.** Append to `tests/test_shop_promo.gd`:

```gdscript
const CartScript := preload("res://Scripts/Inventory/Cart.gd")

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
```

(These compare against `list_price_of` so they hold whether or not the achievement discount is claimed in the editor's session.)

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="shop_promo")`. Expected: FAIL.

- [ ] **Step 3: Split the price.** Replace `price_of` with:

```gdscript
## What `item` lists at: its price after Pembimbing Legendaris's claimed shop
## discount, before this week's promo. The promo tag strikes this number.
static func list_price_of(item: ItemData) -> int:
	return roundi(item.price * AchievementsScript.multiplier("shop_price"))

## What `item` costs right now: its list price, less this week's promo when it
## is the promo item. The shelf shows and checks this same number.
static func price_of(item: ItemData) -> int:
	var promo: float = GameState.shop_promo_multiplier(item.item_name)
	return roundi(list_price_of(item) * promo)
```

- [ ] **Step 4: Run to verify it passes.** `test_run` on `shop_promo`, `koperasi`, `koperasi_hud`, `basket_tray`, `koperasi_cart_signals`, `clean_code`, `project_hygiene`. Expected: PASS.

- [ ] **Step 5: Commit** `feat(koperasi): route the weekly promo discount through Cart.price_of`.

---

## Gate: merge the UI depth pass

- [ ] `git merge feat/ui-depth-pass` (a local ref shared by every worktree; prefer `origin/feat/ui-depth-pass` if it is newer). Resolve any `kejartes_theme.tres` conflict by taking either side and **rebaking**, never by hand. Restart this worktree's editor, `test_run(suite="theme_rebake")`, restart again, then `test_run` on `lipped_stylebox`, `button_geometry`, `theme_factory`, `shop_promo`, `koperasi`. Commit the merge.

---

## Task 3: ThemeFactory variations for the band, the tag and the footer

**Files:** Modify `Scripts/Design/ThemeFactory.gd` (a `_build_koperasi_chrome(theme, tokens)` called from `build()` beside `_build_lobby_hud`; delete the now-unused `ShopCoinLabel` block). Modify `tests/test_theme_factory.gd`. Update `DesignTokens.gd`'s `currency_gold` `##` line (it names `ShopCoinLabel`).

**Produces** (every panel a `LippedBox` face; `KOPERASI_*` consts at the top of the builder for the few numbers that are not tokens):

| Variation | Base | Look |
|---|---|---|
| `KoperasiSignPanel` | `Panel` | brown: `brand_primary` on `brand_primary_dark`, `tokens.lip_height`, `radius_button`, `gloss_strength` |
| `KoperasiSignLabel` | `Label` | `font_display`, `font_h1`, `text_on_brand`, outline `brand_primary_dark` × `lipped_label_outline` |
| `KoperasiSignCaptionLabel` | `Label` | `font_display`, `font_caption`-size, `button_cream` |
| `KoperasiPromoPanel` | `Panel` | cream: `button_cream` on `button_cream_lip`, `lip_height`, `radius_button`, no gloss |
| `KoperasiPromoHeaderLabel` | `Label` | `font_display`, `font_title`, `text_primary` |
| `KoperasiPromoItemLabel` | `Label` | `font_display`, `font_h2`, `text_primary` |
| `PromoBadge` | `Label` | tangerine: `accent_tangerine` on `accent_tangerine_lip`, a small lip (`KOPERASI_BADGE_LIP`), `radius_pill`, no gloss; `text_on_brand` outlined in `accent_tangerine_lip` |
| `PromoStrikeLine` | `Panel` | a flat `text_secondary` bar (the struck price's line) |
| `KasPill`, `TotalPillAwake` | `PanelContainer` | cream: `button_cream` on `button_cream_lip`, `lip_height`, `radius_button`, no gloss; padding via `LippedBox.set_vertical_padding` |
| `TotalPillAsleep` | `PanelContainer` | the depth pass's disabled look: face and lip faded `DISABLED_FADE` toward `surface_sunken`, half lip |
| `TotalPillOver` | `PanelContainer` | `button_cream` on `accent_tomato`, full lip |
| `KasCaptionLabel` | `Label` | `font_micro`-size, `text_secondary` |
| `TotalNumberAwake` / `Asleep` / `Over` | `Label` | `font_display`, `font_title`; `text_primary` / `text_disabled` / `accent_tomato_lip` |

Grep `DesignTokens.gd` for the real token names (`radius_pill`, `font_caption`, `font_micro`, `text_disabled`, …) and use what exists. Reuse `_apply_lipped_text` for `PromoBadge` if it fits a Label (it sets Button colour keys; a Label needs `font_color`, `font_outline_color`, `outline_size`).

- [ ] **Step 1: Write the failing test** in `tests/test_theme_factory.gd`, using the suite's existing way of building the theme (`ThemeFactory.build(DesignTokens.load_default())` or its fixture):

```gdscript
func test_koperasi_chrome_is_lipped_and_on_palette() -> void:
	var tokens: DesignTokens = DesignTokens.load_default()
	var theme: Theme = ThemeFactory.build(tokens)
	for panel: String in ["KoperasiSignPanel", "KoperasiPromoPanel"]:
		assert_true(LippedBox.is_lipped(theme.get_stylebox("panel", panel)), panel + " is lipped")
	for pill: String in ["KasPill", "TotalPillAwake", "TotalPillAsleep", "TotalPillOver"]:
		assert_true(LippedBox.is_lipped(theme.get_stylebox("panel", pill)), pill + " is lipped")
	var asleep: StyleBoxFlat = theme.get_stylebox("panel", "TotalPillAsleep")
	var awake: StyleBoxFlat = theme.get_stylebox("panel", "TotalPillAwake")
	assert_lt(LippedBox.lip_height_of(asleep), LippedBox.lip_height_of(awake),
		"an empty total sleeps on a thinner lip")
	var over: StyleBoxFlat = theme.get_stylebox("panel", "TotalPillOver")
	assert_eq(over.shadow_color, tokens.accent_tomato, "over budget stands on a tomato lip")
	assert_eq(theme.get_color("font_color", "TotalNumberOver"), tokens.accent_tomato_lip,
		"and its number reads in the dark tomato")
	var badge: StyleBoxFlat = theme.get_stylebox("normal", "PromoBadge")
	assert_eq(badge.bg_color, tokens.accent_tangerine, "the promo badge is tangerine")

func test_the_ledge_coin_label_is_gone() -> void:
	var theme: Theme = ThemeFactory.build(DesignTokens.load_default())
	assert_false(theme.get_type_list().has("ShopCoinLabel"), "the Kas pill replaced it")
```

If `DISPLAY_ROSTER` (same suite) pins which variations use `font_display`, add the new display labels to it and drop `ShopCoinLabel` if listed.

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="theme_factory")`.
- [ ] **Step 3: Write `_build_koperasi_chrome`** per the table, with a `##` header naming the spec and the depth pass. No colour literals: tokens only.
- [ ] **Step 4: Rebake alone and verify.** Restart the editor, `test_run(suite="theme_rebake")`, restart, then `test_run` on `theme_factory`, `button_geometry`, `clean_code`. Check the bake's diff is only the new variations and the removed `ShopCoinLabel`.
- [ ] **Step 5: Commit** `feat(design): lipped Koperasi signboard, promo board and Kas/Total pills` (ThemeFactory, DesignTokens comment, the bake, the test).

---

## Task 4: Promo dress on the price tag

**Files:** `Scenes/Koperasi/PriceTag.tscn`, `Scripts/Koperasi/PriceTag.gd`, `Scripts/Koperasi/KoperasiStage.gd` (`setup_shelf()` ~line 112–114). Test: `tests/test_koperasi.gd`.

**Produces:** `PriceTag.set_promo(list_price: int, percent: int) -> void`, `PriceTag.clear_promo() -> void`, `PriceTag.is_promo() -> bool`, `get_old_price_text()`, `get_badge_text()`.

- [ ] **Step 1: Write the failing test** in `tests/test_koperasi.gd`:

```gdscript
const PriceTagScene := preload("res://Scenes/Koperasi/PriceTag.tscn")

func test_a_promo_tag_shows_the_list_price_and_badge() -> void:
	var tag: PanelContainer = PriceTagScene.instantiate()
	tag.set_price(800)
	tag.set_promo(1000, 20)
	assert_true(tag.is_promo(), "the tag knows it is on promo")
	assert_eq(tag.get_old_price_text(), "1000", "the list price is shown, struck")
	assert_eq(tag.get_badge_text(), "-20%", "the badge names the percent")
	tag.clear_promo()
	assert_false(tag.is_promo(), "a normal tag drops the promo dress")
	tag.free()

func test_the_shelf_dresses_only_the_promo_item() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scripts/Koperasi/KoperasiStage.gd")
	assert_true(src.contains("GameState.shop_promo_item"), "the stage asks which item is on promo")
	assert_true(src.contains("Cart.list_price_of("), "and strikes the list price, not the raw one")
```

- [ ] **Step 2: Run to verify it fails.** `test_run(suite="koperasi")`.
- [ ] **Step 3: Author the nodes (editor, scene first).** The tag root is a `PanelContainer`, which stretches every child over its rect, so add one `PromoHost` `Control` (Full Rect, `mouse_filter = IGNORE`) and put the dress inside it, placed by offsets:
  - `OldPrice` (`Label`, `unique_name_in_owner`, `CaptionLabel`, hidden), above the pill, with a `Strike` child `Panel` (`PromoStrikeLine`, a few px tall across its middle).
  - `PromoBadge` (`Label`, unique, `PromoBadge` variation, hidden), overlapping the pill's top-right corner, rotated a few degrees like the scrapbook's stickers (a Control, not in a Container, so rotation holds).
  `scene_save`, then diff the `.tscn`.
- [ ] **Step 4: Extend `PriceTag.gd`** (restart the editor first if a script was patched since the last save). Resolve the two new nodes in the existing `_ensure_nodes()` (not in each method), `push_error` if missing. `set_promo` fills and shows both; `clear_promo` hides them; `_is_promo: bool` backs `is_promo()`. Badge text `"-%d%%" % percent`.
- [ ] **Step 5: Dress the shelf.** In `setup_shelf()`, type the touched `tag` local (`var tag: Node = …` → the PriceTag type the script uses) and after `set_price`:

```gdscript
			if item.item_name == GameState.shop_promo_item:
				tag.set_promo(Cart.list_price_of(item), GameState.shop_promo_percent)
			else:
				tag.clear_promo()
```

- [ ] **Step 6: Run** `koperasi`, `koperasi_stock_pips`, `koperasi_shop_layout`, `viewport_editability`, `script_documentation`, `clean_code`. Expected: PASS.
- [ ] **Step 7: Commit** `feat(koperasi): the promo item's tag strikes its list price and wears a -N% badge`.

---

## Task 5: The top band — signboard and promo board

**Files:** Create `Scripts/Koperasi/PromoBoard.gd`. Modify `Scenes/Koperasi/Koperasi.tscn`. Tests: `test_koperasi.gd`, `test_parallax_diorama.gd` (UI list: drop `CoinHUD`, add `Signboard`, `PromoBoard`).

- [ ] **Step 1: Write the failing tests** in `tests/test_koperasi.gd`:

```gdscript
func test_the_top_band_has_a_sign_and_a_promo_board() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scenes/Koperasi/Koperasi.tscn")
	assert_true(src.contains("[node name=\"Signboard\" type=\"Panel\" parent=\"Stage\""),
		"the shop names itself, on the Stage")
	assert_true(src.contains("[node name=\"PromoBoard\" type=\"Panel\" parent=\"Stage\""),
		"and advertises the week's promo")
	assert_false(src.contains("name=\"CoinHUD\""), "the ledge coin HUD is gone")
	assert_true(src.contains("theme_type_variation = &\"KoperasiSignPanel\""), "the sign is lipped brown")
	assert_true(src.contains("theme_type_variation = &\"KoperasiPromoPanel\""), "the board is lipped cream")

func test_promo_board_reads_gamestate() -> void:
	var src: String = FileAccess.get_file_as_string("res://Scripts/Koperasi/PromoBoard.gd")
	assert_true(src.contains("GameState.shop_promo_item"), "the board names the promo item")
	assert_true(src.contains("GameState.shop_promo_percent"), "and its discount")
	assert_true(src.contains("Engine.is_editor_hint()"), "its live fill is editor-gated")
```

- [ ] **Step 2: Run to verify they fail.** `test_run(suite="koperasi")`.
- [ ] **Step 3: Build the band (editor, scene first).** `scene_open("res://Scenes/Koperasi/Koperasi.tscn")`:
  - Delete `Stage/CoinHUD` (grep first: only `Koperasi.gd` and the tests named here reference it).
  - `Stage/Signboard`: `Panel`, `KoperasiSignPanel`, `mouse_filter = IGNORE`, left of the band (about x 36–540, y 24–170 in Stage space; tune on a screenshot), rotated ~−2° like the scrapbook's plates. Children: `Title` `Label` `KoperasiSignLabel` "KOPERASI", `Caption` `Label` `KoperasiSignCaptionLabel` "SEKOLAH", centred by anchors.
  - `Stage/PromoBoard`: `Panel`, `KoperasiPromoPanel`, `mouse_filter = IGNORE`, script `PromoBoard.gd`, right of the band (about x 580–1044, y 24–200). Children: `Header` `KoperasiPromoHeaderLabel` "PROMO MINGGU INI"; `ItemLabel` (unique) `KoperasiPromoItemLabel`; `PercentBadge` (unique) `PromoBadge`, tilted, overlapping the board's corner.
  - Keep both out of the Stage's parallax `depth_by_child` (they are information, not scenery) and clear of the shelf and Herman.
  `scene_save`; diff the scene.
- [ ] **Step 4: Write `PromoBoard.gd`** (restart first if needed):

```gdscript
@tool
extends Panel

## The Koperasi promo board (Koperasi.tscn: Stage/PromoBoard), advertising
## this week's discounted item. The board, its header and both labels are
## authored in the scene; this only fills the two labels from GameState on
## arrival, because the promo changes every week. Its badge is the tangerine
## PromoBadge the promo item's own price tag wears, so the two read as one
## offer (2026-09-28 Koperasi top-band spec, in the UI depth pass look).

@onready var _item_label: Label = %ItemLabel
@onready var _percent_badge: Label = %PercentBadge

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	refresh()

## Fills the labels from this week's promo; hides the board when there is
## none (an empty shelf).
func refresh() -> void:
	if _item_label == null or _percent_badge == null:
		push_error("PromoBoard: ItemLabel or PercentBadge is missing from Koperasi.tscn")
		return
	visible = GameState.shop_promo_item != ""
	_item_label.text = GameState.shop_promo_item
	_percent_badge.text = "-%d%%" % GameState.shop_promo_percent
```

  The shelf must roll before the board reads it: confirm `Koperasi.gd`/`KoperasiStage.gd` call `GameState.shop_stock_for_week()` before the board's `_ready`, or have `Koperasi.gd` call `%PromoBoard.refresh()` after `setup_shelf()` (calls down).
- [ ] **Step 5: Update `test_parallax_diorama.gd`'s UI list** and `test_koperasi_hud.gd`'s `test_coin_hud_and_message_live_in_the_scene` (drop `CoinHUD`/`CoinIcon`/`CoinLabel`, keep `MessageLabel`) and `test_coin_label_uses_the_shop_coin_variation` (delete: the variation is gone). The Kas's own pins come in Task 6.
- [ ] **Step 6: Run** `koperasi`, `koperasi_hud`, `parallax_diorama`, `viewport_editability`, `script_documentation`, `clean_code`. `Koperasi.gd` still references `%CoinHUD` until Task 6, so run Task 6 before any live game run.
- [ ] **Step 7: Commit** `feat(koperasi): a lipped signboard and promo board fill the top band`.

---

## Task 6: The Kas Kelas and Total footer

**Files:** `Scenes/Koperasi/BasketTray.tscn`, `Scripts/Koperasi/BasketTray.gd`, `Scripts/Koperasi/Koperasi.gd` (`coin_hud`/`coin_label` onreadies ~26–27, `_update_coin_display` ~165). Tests: `test_basket_tray.gd`, `test_koperasi_hud.gd`, `test_tall_screen_layout.gd`.

**Produces:** `BasketTray.show_kas(amount: int, animate: bool = true)`, `BasketTray.get_kas_text() -> String`, `BasketTray.get_total_state() -> StringName` (the pill's variation). `refresh(entries)` now also sets the Total pill's state against the last `show_kas` amount. `get_total_text()` returns the Total number's text (`"2.400"`, no "Total:"/"koin": the caption carries "TOTAL" and the coin icon the unit).

- [ ] **Step 1: Write the failing tests.** In `tests/test_basket_tray.gd` (it already builds a tray and entries: reuse its helpers):

```gdscript
func test_an_empty_basket_sleeps() -> void:
	# (build the tray as the suite does)
	tray.show_kas(3880, false)
	tray.refresh({})
	assert_eq(tray.get_total_state(), &"TotalPillAsleep", "nothing picked, nothing owed")

func test_items_wake_the_total() -> void:
	tray.show_kas(3880, false)
	tray.refresh(_entries_costing(1000))
	assert_eq(tray.get_total_state(), &"TotalPillAwake", "items wake it")

func test_a_total_past_the_kas_turns_over() -> void:
	tray.show_kas(3880, false)
	tray.refresh(_entries_costing(5000))
	assert_eq(tray.get_total_state(), &"TotalPillOver", "more than the class fund holds")

func test_the_kas_shows_the_balance() -> void:
	tray.show_kas(3880, false)
	assert_eq(tray.get_kas_text(), "3.880", "the Kas reads the balance, thousands dotted")
```

  Update the suite's two `get_total_text()` expectations to `"2.400"` and `"0"`. In `test_koperasi_hud.gd`, pin: `Koperasi.gd` contains `tray.show_kas(` and no `%CoinHUD`; `BasketTray.tscn` contains `KasPill`, `TotalPill`, `KasLabel`, `TotalNumber` and `&"KasCaptionLabel"`.
  In `test_tall_screen_layout.gd`, replace the three CoinHUD pins with: the Kas pill is inside `Stage/TrayDock/BasketTray` (it rides the tray, which rides the Stage), and the tray rects stay as pinned.

- [ ] **Step 2: Run to verify they fail.** `basket_tray`, `koperasi_hud`, `tall_screen_layout`.
- [ ] **Step 3: Rebuild the footer (editor, scene first).** In `Body/Footer` (HBox, `separation` 24; keep its rect):
  - `KasCluster` (`VBoxContainer`, expand-fill): `KasCaption` `Label` `KasCaptionLabel` "KAS KELAS"; `KasPill` (`PanelContainer`, unique, `KasPill`) → `Row` (`HBoxContainer`) → `Coin` `TextureRect` (the old `CoinIcon`'s `Koin.png` texture and size, expand/keep-aspect) + `KasLabel` (`Label`, unique, `TotalNumberAwake`).
  - `TotalCluster` (`VBoxContainer`, expand-fill), replacing `TotalLabel`: `TotalCaption` "TOTAL"; `TotalPill` (unique, `TotalPillAsleep`) → `Row` → `Coin` + `TotalNumber` (unique, `TotalNumberAsleep`, "0").
  - `BeliButton` unchanged, `size_flags_vertical = FILL`.
  `scene_save`; diff; screenshot the tray at full size before moving on.
- [ ] **Step 4: Tray script** (restart first). Consts: `ASLEEP_COIN_ALPHA := 0.45` (the sleeping coin), `BELI_OVER_ALPHA := 0.6` (Beli dims but stays pressable, so Pak Herman's "not enough" line still answers), `COUNT_UP_SECONDS` if `Juice.count_up_formatted` needs a duration. Resolve `%KasPill`, `%KasLabel`, `%TotalPill`, `%TotalNumber` and the total `Coin` in `_ensure_nodes()`; drop `_total_label`. `show_kas` stores `_kas: int`, sets the label (via `Juice.count_up_formatted(label, old, new, format_koin)` when `animate` and inside the tree, else straight text), and re-derives the Total state. `refresh()` computes `total_of(entries)` once, then `_apply_total_state(total, entries.is_empty())` swaps both variations, the coin alpha and Beli's alpha. `get_total_text()` returns `format_koin(total)` for the last refresh, not a mid-count label text.
- [ ] **Step 5: `Koperasi.gd` calls down.** Delete the `coin_hud`/`coin_label` onreadies and their comment. `_update_coin_display()` becomes `tray.show_kas(GameState.player_money)` (guard `tray` with a `push_error` if missing). The first call on arrival passes `animate = false`.
- [ ] **Step 6: Run** `basket_tray`, `koperasi_tray`, `koperasi_tray_retract`, `koperasi_hud`, `koperasi_back_follows_tray`, `tall_screen_layout`, `viewport_editability`, `script_documentation`, `clean_code`. Expected: PASS.
- [ ] **Step 7: Commit** `feat(koperasi): twin Kas Kelas and waking Total pills in the tray footer`.

---

## Task 7: The Beli withdrawal

**Files:** `Scripts/Koperasi/BasketTray.gd` (`play_withdrawal`), `Scripts/Koperasi/Koperasi.gd` (`_on_beli_pressed` ~170). Test: `test_koperasi_hud.gd`.

**Produces:** `BasketTray.play_withdrawal(amount: int)`: a `-<amount>` rises out of the Kas pill (`AnimUtils.create_floating_text`, coloured from the theme's `TotalNumberOver` `font_color`, not a literal) and the pill shakes (`Juice.shake`). The balance itself counts down through `money_changed` → `show_kas`.

- [ ] **Step 1: Write the failing test** in `tests/test_koperasi_hud.gd`:

```gdscript
func _body(src: String, signature: String) -> String:
	var at: int = src.find(signature)
	if at < 0:
		return ""
	var next: int = src.find("\nfunc ", at + 1)
	return src.substr(at, (src.length() if next < 0 else next) - at)

func test_beli_withdraws_from_the_kas() -> void:
	var body: String = _body(FileAccess.get_file_as_string(SCRIPT_PATH), "func _on_beli_pressed()")
	var deduct_at: int = body.find("GameState.player_money -= total")
	var play_at: int = body.find("tray.play_withdrawal(total)")
	assert_true(deduct_at != -1 and play_at > deduct_at,
		"the withdrawal plays after the money actually leaves")

func test_the_withdrawal_takes_its_red_from_the_theme() -> void:
	var body: String = _body(FileAccess.get_file_as_string("res://Scripts/Koperasi/BasketTray.gd"),
		"func play_withdrawal(")
	assert_true(body.contains("create_floating_text"), "a -total floats out of the Kas")
	assert_true(body.contains("get_theme_color("), "its colour is the theme's, not a literal")
```

- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement** `play_withdrawal` (float text parented to the tray's scene root at the Kas pill's global centre; `Juice.shake(%KasPill)`), and call `tray.play_withdrawal(total)` in `_on_beli_pressed()` right after the deduction.
- [ ] **Step 4: Run** `koperasi_hud`, `koperasi`, `koperasi_tap_spam`, `viewport_editability`, `clean_code`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(koperasi): Beli withdraws visibly from the Kas Kelas`.

---

## Task 8: Live check, docs, full suite, ship

- [ ] **Step 1: Live screenshots at full size**, 1080×1920 and 1080×2400: Debug → ⚡ Seed Playtest State → Lobby → Koperasi. Check: the band reads (sign left, board right, clear of the shelf and Herman); the promo item's tag shows the struck list price and the badge; the Kas pill is legible; the Total sleeps, wakes and counts as items land, and turns tomato past the Kas; Beli floats `−total` out of the Kas while the balance counts down. Also check that a held (pressed) Beli does not clip in the footer (the depth pass's lip-shift risk). Fix what fails, with a pinning test where one is cheap.
- [ ] **Step 2: Docs.** `docs/superpowers/CHANGELOG.md` (newest first); `DEBT.md` if anything is deferred (e.g. hand-drawn sign art); the depth pass's Phase 3 list can drop "Koperasi's new chrome" (note it in the PR). Update CLAUDE.md's suite and test counts.
- [ ] **Step 3: Full suite** (one editor restart budgeted): open `Scenes/MainMenu/MainMenu.tscn`, `test_run()`. Revert `Assets/Audio/default_bus_layout.tres` and any unintended bake churn.
- [ ] **Step 4: Ship** with the `ship-pr` skill as a **draft labelled `hold`** while the depth pass's Phase 1 PR is open; once it merges, merge `origin/Textures`, rerun the full suite, undraft, drop `hold`, and stamp that commit.

---

## Self-review notes for the executor

- **Spec coverage:** promo mechanic → Tasks 1–2, 4, 5; top band → Tasks 3, 5; footer and withdrawal → Tasks 3, 6, 7; layout, docs, ship → Task 8.
- **Deliberate departures from the handoff spec**, all for the depth pass: no brown stroke on the cream pills (the lip is the edge); over-budget is a tomato lip and dark-tomato number, not `cat_olahraga` (stat colours are reserved for stats); Beli dims but stays pressable.
- **Open question for the owner:** the Kas pill rides the tray, so a collapsed tray hides the balance with it (the tray starts expanded; only the player collapses it). The handoff spec accepted this; revisit if playtesting disagrees.
