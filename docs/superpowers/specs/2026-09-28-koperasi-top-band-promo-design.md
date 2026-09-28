# Koperasi top-band, Kas Kelas footer, and weekly promo — design

Date: 2026-09-28
Screen: `Scenes/Koperasi/Koperasi.tscn` (Pak Herman's shop)
Status: handoff design, awaiting review

## Why

The shop's top band (everything above the shelf, `y < 310`) is dead dark-wood
cabinet — a reviewer flagged it as blank. Separately, the coin balance
(`ShopCoinLabel`, gold text at `y≈1230`) has no backing plate, so gold-on-wood
washes out to near-invisible. This pass fills the band, rebuilds the money box
as a legible class-fund chip beside the cart, gives the running total a real
home, and adds a genuine weekly-discount mechanic the top-band promo board
advertises.

Confirmed with the reviewer over three rounds of `show_widget` mockups:
- Top band: **signboard left + promo board right**, shelf kept clear.
- Money box: **cream, brown-stroked, 3D-bevel chip**, relabelled **KAS KELAS**
  (class fund, not a personal wallet), moved **down beside the cart**.
- Footer: **twin pills** — raised KAS KELAS (what you have) beside a TOTAL pill
  (what you owe) — TOTAL asleep/grey until items land, then counts up and wakes
  into colour; red + dimmed Beli when the total passes the Kas.
- Beli: **withdrawal animation** — a `−amount` floats out of the Kas pill, the
  pill shakes, the Kas balance counts down.
- Promo: **real mechanic** — rotates through a curated promo list by week, with
  a **per-week discount roll** (deterministic from the `(grade, week)` seed).

## Scope

In: the Koperasi top band, the BasketTray footer, the promo pricing mechanic,
and the price-tag/board visuals that surface it. Plus the `ThemeFactory`
variations and tests they need.

Out: the shelf grid, the flight-into-basket arc, Pak Herman's dialogue, the
ShopHub/CosmeticShop. `Balance.gd` is untouched — the promo tunables are ours
and live in the owning scripts.

## Part 1 — The promo mechanic (the only new system)

### Derivation — deterministic, no stored state beyond the week key

Both the promo item and its discount derive from the existing
`shop_week_key_for(current_grade, minggu_ke)` seed, alongside the shelf roll in
`shop_stock_for_week()`. No new persistence (the CLAUDE.md persistence rule
stands — nothing new reaches disk).

New in `GameState.gd`, rolled in the same `if key != shop_week_key` block that
rolls the shelf:

- `PROMO_ITEMS: Array[String]` — a curated const list of promo-eligible item
  names (a named `const` block in `GameState.gd`, ours to own). Items must
  exist in `ItemDatabase`.
- `PROMO_DISCOUNTS: Array[int]` — the allowed discount percentages, e.g.
  `[15, 20, 25, 30]` (const block, ours).
- `shop_promo_item: String` — `PROMO_ITEMS[global_week % PROMO_ITEMS.size()]`,
  where `global_week` is a monotonic week counter across grades (derive from
  `(current_grade, minggu_ke)`; a pure static helper
  `promo_index_for(grade, week)` so a test can call it with no instance).
- `shop_promo_percent: int` — chosen from `PROMO_DISCOUNTS` by a seeded pick on
  the `(grade, week)` key (a pure static `promo_percent_for(grade, week)`), so
  the same week always yields the same discount and tests are deterministic.
- **The promo item is force-stocked.** After `roll_shop_stock`, if
  `shop_promo_item` is not in `shop_stock`, replace the last slot with it — the
  advertised deal is always buyable. (Guarded so it never pushes the shelf over
  `SHOP_SHELF_SIZE`.)

Static accessors, callable from `Cart.price_of` (an autoload reference):
- `GameState.shop_promo_item` (property).
- `GameState.shop_promo_multiplier(item_name) -> float` → returns
  `1.0 - percent/100.0` when `item_name == shop_promo_item`, else `1.0`.

### Pricing hook — one chokepoint

`Cart.price_of(item)` is the single price source (shelf tags, `total_of`, and
the Beli affordability check all read it). Extend it:

```gdscript
static func price_of(item: ItemData) -> int:
    var base := item.price * AchievementsScript.multiplier("shop_price")
    var promo := GameStateScript.shop_promo_multiplier(item.item_name)
    return roundi(base * promo)
```

Because everything routes through here, the shelf price tag, the running total,
the twin TOTAL pill, and the "can I afford it" check all pick up the discount
with no further wiring.

### Surfacing the discount

- **Promo board** (top-band right): shows the promo item's name and the week's
  discount, e.g. "PROMO MINGGU INI — Susu Murni −20%". It reads
  `shop_promo_item` + `shop_promo_percent`. Static chrome node in the `.tscn`;
  a small `@tool` script fills its two `@export`-documented labels from
  GameState on `_ready` (per-load dynamic content, not runtime construction —
  goes in the authoring-guide `ALLOWED` list if the viewport-editability test
  flags it).
- **Promo price tag**: the promo item's shelf `PriceTag` shows the discounted
  price with the old price struck through and a small "−N%" badge. Extend
  `PriceTag.tscn`/`ShelfItem` to accept an optional promo state; a plain item
  passes the existing single-price path unchanged.

## Part 2 — The top band (art + layout, no new system)

Two static nodes added under `Stage`, both in the band above the shelf
(`y < 300`), clear of Herman (full-rect illustration pinned bottom-right):

- **Signboard** (left): carved wooden plate on `PrimaryButton`-family brown
  (`brand_primary #7A4A2B`, stroke `brand_primary_dark #56321B`), display font,
  "KOPERASI" / "SEKOLAH". Identity anchor.
- **Promo board** (right): the discount surface from Part 1.

Both are nodes in `Koperasi.tscn`, not built at runtime. Text uses
`DisplayLabel`/`H2Label`-family variations, never `theme_override_*`.

## Part 3 — The Kas Kelas footer (rework)

`BasketTray.tscn` footer today: `HBoxContainer` = `TotalLabel` (expands) +
`BeliButton`. The old `CoinHUD` (`Stage/CoinHUD`, `ShopCoinLabel`) is removed
from the counter ledge and its balance moves into the footer as the KAS KELAS
pill. `Koperasi.gd`'s `coin_hud`/`coin_label` `@onready`s and
`_update_coin_display` repoint to the new node.

New footer, left→right:
1. **KAS KELAS pill** (raised): cream `surface_card #FFFDF8`, brown stroke, a
   darker cream slab (`#d9c3a3`) offset below as the 3D bevel, gold coin icon
   (rim `#c8930f`), balance in `text_primary #3B2412`. Caption "KAS KELAS" in
   `text_secondary` above.
2. **TOTAL pill** (its twin): same silhouette. Two visual states driven by
   `Cart.cart_changed`:
   - **Asleep** (empty cart): sunken beige `#e3d2b8`, greyed coin, muted number
     `#b7a488`.
   - **Awake** (items present): cream fill, live gold coin, dark number; count
     up via `AnimUtils.count_up`; a small `coin_pulse`/scale-pop on each change.
   - **Over budget** (total > Kas): number, coin and stroke go
     `cat_olahraga #E03A18` (red), Beli dims. Reuses the price-tag
     affordability pattern.
3. **Beli** (`PrimaryButtonM`), grown to a full-height tap target.

Each state is a `ThemeFactory` type variation (e.g. `KasPill`, `TotalPillAsleep`
/ `TotalPillAwake` / `TotalPillOver`) toggled by swapping
`theme_type_variation`, not by overriding colours at runtime.

### Beli withdrawal

On a successful `_on_beli_pressed` (after the existing deduction):
- `AnimUtils.create_floating_text` spawns "−<total>" rising out of the KAS
  pill.
- The KAS pill shakes (`AnimUtils.squash_bounce` or a short x-jitter tween).
- The KAS balance counts down from old to new via `AnimUtils.count_up`
  (driven off `GameState.money_changed`, which already fires).
- Cart clears (existing), so the TOTAL pill returns to Asleep.

## Data flow

```
(grade, week) seed ─┬─ roll_shop_stock ──────────► shop_stock (+ forced promo item)
                    ├─ promo_index_for ──────────► shop_promo_item
                    └─ promo_percent_for ────────► shop_promo_percent
                                   │
shop_promo_multiplier(name) ◄──────┘
        │
Cart.price_of(item) ──► shelf PriceTag (strike + −N% on promo)
        ├────────────► Cart.total_of ──► TOTAL pill (asleep/awake/over)
        └────────────► Beli affordability check
Promo board ◄─ shop_promo_item + shop_promo_percent
```

## Testing

- `test_cart` (or new): `price_of` applies the promo multiplier only to the
  promo item; non-promo items unchanged; achievement multiplier still stacks.
- New `test_shop_promo`: `promo_index_for`/`promo_percent_for` are deterministic
  per `(grade, week)` and range-bounded; the promo item is always in the forced
  stock; discount ∈ `PROMO_DISCOUNTS`.
- `test_atur_jadwal`-style source scans / `test_theme_factory`: the new pill and
  board variations exist and are pinned; no `theme_override_*` added.
- `test_tall_screen_layout`: the new band nodes and footer re-anchor correctly
  on a 20:9 phone; BackButton's pinned authored rect is unchanged.
- `test_viewport_editability`: the promo-board and pill fills are nodes /
  variations, not runtime-constructed; any per-load label fill is in `ALLOWED`.

## Open / risks

- `global_week` monotonic counter: confirm a clean derivation from
  `(current_grade, minggu_ke)` that survives a grade change (grades restart
  `minggu_ke` at 1). If none is clean, key the rotation on
  `shop_week_key_for` directly via a stable hash.
- `PROMO_ITEMS` curation is a content decision — needs a real list of item
  names that exist in `ItemDatabase`.
- Removing `CoinHUD` from the ledge: check nothing else references
  `%CoinHUD`/`Stage/CoinHUD` besides `Koperasi.gd`.
