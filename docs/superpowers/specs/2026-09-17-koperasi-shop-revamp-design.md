# Koperasi shop revamp — design

Date: 2026-09-17 · Branch: `feat/shop-revamp` · Reference: `newshop_mockup.png`
(900×1600, a 5/6 scale of the 1080×1920 design size).

## What the player gets

Opening **Koperasi** (ShopHub → items tile) lands straight on the counter: Pak
Herman behind a glass case, six items on the wooden shelf to his left, a speech
bubble across the top, and the basket tray exactly as it works today. The
"KEBUTUHAN SEKOLAH" landing and its pop-up shelf panel are gone. The shelf is
the screen.

The shelf holds six items a week instead of four, and the same item can fill
two slots. Buying one of a pair leaves the other on the shelf.

## Art

Three new layers, each 1080×1920 RGBA, copied from `~/Downloads` into
`Assets/Images/Shop/Koperasi/`:

| File | Opaque area | Role |
|---|---|---|
| `shop_background.png` | whole frame | wall, shelf cabinet, door |
| `shop_herman.png` | (499,425)–(1080,1582) | Pak Herman, midground |
| `shop_foreground.png` | (0,1160)–(1080,1920) | glass counter and its painted snacks |

Composited at full size, with no offsets, they match the mockup pixel for pixel
(checked 2026-09-17). The top 200 rows of the background are a flat wall
colour (per-channel std < 2.5), which is what fills the extra height on tall
phones.

Measured off the mockup at 1080×1920:

- **Item circles**, diameter 180: centres x ∈ {126, 490}, y ∈ {400, 676, 944}.
  Slot order is row-major: 1 = top-left, 2 = top-right, … 6 = bottom-right.
- **Bubble body**: (36,23)–(1046,256). **Tail**: a right triangle from
  (787,256) and (852,256) down to its tip at (852,368), pointing at Herman.

## Scene: `Scenes/Koperasi/koprasi.tscn`

```
Koprasi (Control, Full Rect, koprasi.gd)
├─ WallFill      TextureRect, Full Rect, expand 1, stretch 6 (Keep Aspect Covered)
│                texture = AtlasTexture(shop_background, region 0,0,1080,160)
├─ Stage         Control 1080×1920, anchors (0,1,0,1), offsets (0,-1920,1080,0)
│  │             rakbarang_1.gd — "the picture and its items", one piece
│  ├─ Background  TextureRect shop_background, Full Rect of Stage, mouse IGNORE
│  ├─ Barang1..6  TextureButton 180×180 on the circles (see below)
│  │   ├─ Glow      (as today: item_glow.tres, show_behind_parent, alpha 0)
│  │   └─ PriceTag  PriceTag.tscn instance, authored under the item
│  ├─ Herman      TextureRect shop_herman, Full Rect, mouse IGNORE
│  ├─ Foreground  TextureRect shop_foreground, Full Rect, mouse IGNORE
│  ├─ ChatBubble  Control (36,23)–(1046,368), mouse IGNORE
│  │   ├─ Body      PanelContainer (0,0)–(1010,233), variation ShopChatBubble
│  │   │   └─ Text    RichTextLabel, variation EventDialogueText, placeholder copy
│  │   └─ Tail      TextureRect (751,230)–(816,345), chat_bubble_tail.svg
│  ├─ BackButton  TextureButton return.png, (24,1157)–(209,1342) — unchanged rect
│  └─ TrayDock    Control (0,117)–(1080,1828), mouse IGNORE — the old Rak1 rect
│      └─ BasketTray  BasketTray.tscn instance at the dock's origin, as under Rak1
│  (Stage also holds CoinHUD, last, on the counter ledge; see below)
├─ Safe (SafeAreaMargin) / UI   (now empty; kept for future edge UI)
└─ MessageLabel  unchanged
```

Slot rects in Stage space (`left, top, right, bottom`):

| Slot | Rect |
|---|---|
| Barang1 | 36, 310, 216, 490 |
| Barang2 | 400, 310, 580, 490 |
| Barang3 | 36, 586, 216, 766 |
| Barang4 | 400, 586, 580, 766 |
| Barang5 | 36, 854, 216, 1034 |
| Barang6 | 400, 854, 580, 1034 |

Items draw under Herman and the counter because they sit on the back shelf.
No circle overlaps Herman's opaque pixels, so nothing is hidden. The price tag
hangs below its item, within the 96 px gap to the next row.

**Tray and back button.** Both keep the global rects they have today:
the tray body (24,1360)–(1056,1920), flush with the bottom edge, and the back
button on the counter's left end. The tray covers the lower glass case. That
is the "cart stays the same" rule taken literally. The tray keeps its old
parent geometry: `TrayDock` reproduces Rak1's rect, and the instance sits at
its origin exactly as it sat under Rak1. Nothing is overridden on the
instance's `Body`, because overrides on an instance's children are dropped on
save (CLAUDE.md 4b).

**CoinHUD moves.** At the design size its old top-left spot lies inside the
bubble. It stands on the counter ledge instead, as a child of `Stage` at
(732,1230)–(1032,1290), right-aligned (`alignment` end). That puts it between
Herman's arms (ending ~1160) and the tray top (1360), in one row with the back
button. It is part of the picture, not bottom-anchored in `Safe`, because
`SafeAreaMargin`'s bottom inset would lift it off the ledge: by a gesture bar
on a phone, and by 768 px in a windowed editor run, where it landed on
Herman's forehead (found in the Task 5 live check).

**Tall phones (1080×2400).** Stage pins to the bottom, so it spans y 480–2400.
Tray, counter and back button keep their relation to the bottom edge. WallFill
covers the 480 px above with the flat wall strip. CoinHUD rides with Stage.

## Chat bubble

- `ShopChatBubble`, a new ThemeFactory PanelContainer variation: StyleBoxFlat
  with `bg_color = tokens.surface_card`, corner radius 28 (a named const
  `SHOP_CHAT_BUBBLE_RADIUS`, measured off the mockup's ~24 px corner at 5/6
  scale), content margins `space_xl` / `space_lg`, no shadow (the mockup has none).
  It uses the body font, so `DISPLAY_ROSTER` is unchanged. Rebake afterwards.
- Text reuses `EventDialogueText`, the existing "someone is speaking" style.
- The tail is `Assets/Images/Shop/UI/chat_bubble_tail.svg`, a 65×115 right
  triangle filled `#FFFDF8` (`surface_card`). A test pins the SVG fill to the
  token, so a token change fails loudly instead of leaving a mismatched seam.
  Its top overlaps the body by 3 px.
- The placeholder copy is authored in the scene: *"Selamat datang di Koperasi!
  Mau beli apa hari ini?"*. It goes on the DEBT.md placeholder list.

## Logic

### Weekly roll with duplicates (`GameState`)

```
SHOP_SHELF_SIZE  := 6     (was 4)
SHOP_MAX_COPIES  := 2     new

static func roll_shop_stock(names: Array[String], size: int, max_copies: int) -> Array[String]
    bag := each name repeated max_copies times
    bag.shuffle()
    return first min(size, bag.size()) of bag        # slot order = bag order
```

`shop_stock_for_week()` calls it with every `ItemDatabase` item name, once per
(grade, week) as today. With 9 items that bag is 18 units, so about 71% of
weeks show at least one pair: 1 − (12·10·8)/(17·15·13). Each item still
appears at most twice. The shelf keeps rolling through `GameState`, never
through `get_random_items`.

### Sold is a count, not a flag

`shop_sold: Array[String]` becomes a multiset with one entry per unit bought.

- `mark_shop_sold(name)` appends only while
  `shop_sold.count(name) < max(1, shop_stock.count(name))`. An item missing
  from the stock (a test, or an unrolled shelf) still sells once.
- `is_shop_sold(name)` is unchanged: at least one unit sold.
- `is_shop_sold_out()`: for every distinct stocked name,
  `shop_sold.count(name) >= shop_stock.count(name)`.
- Beli (`koprasi.gd`) calls `mark_shop_sold` once per unit of quantity, before
  `Cart.clear()` as today.

### Which slot empties (`rakbarang_1.gd`)

`Cart` stays keyed by name with a quantity. That is what the tray draws, so
it does not change. The shelf keeps the slots itself:

```
var _taken_slots: Array[int]   # slots emptied, in the order they emptied

static func reconcile_taken(stock: Array[String], taken: Array[int],
                            cart: Dictionary, sold: Array) -> Array[int]
    for each distinct name in stock:
        want := min(stock.count(name), sold.count(name) + cart quantity of name)
        mine := entries of taken whose slot holds name, in taken order
        drop from the END of mine until mine.size() <= want
        append this name's untaken slots, lowest index first, until mine.size() == want
    result keeps taken's order for kept slots; appended slots go last;
    indices out of range are dropped
```

- **Tap slot i**: refuse if `_taken_slots.has(i)`. That guard replaces
  `is_on_sale()` and stops a double tap. Otherwise append `i`, then
  `tray.hold_for_landing` and `Cart.add_item`, as today. The tapped slot is
  the one that empties, even when it holds the second copy of a pair.
- **Every cart change** (`_refresh_shelf_visibility`): reconcile, then
  `visible = not taken`. A slot coming back still bounces (`squash_bounce`)
  and keeps its dimming.
- **Hold-to-return** removes one unit, and reconcile returns the most recently
  taken slot of that name.
- **Back / Beli**: Back clears the cart, so every slot not sold returns. Beli
  marks the units sold, and reconcile keeps exactly those slots empty. Returning
  to the shop another day rebuilds `_taken_slots` from `shop_sold`, lowest
  index first.

`is_on_sale()` is deleted. Its only callers were the tap guard and the
visibility refresh.

### `koprasi.gd`

The Rak1 toggle is gone (`_on_rak1_pressed`, the panel fade, `idle_pulse` on
the sign). What stays:

- `_ready`: wire BackButton, the tray's `buy_pressed`, `money_changed`; update
  the coins. If `GameState.is_shop_sold_out()`, show `SOLD_OUT_TEXT`.
- Back (button or Android back): `Cart.clear()`,
  `stage.clear_basket_visuals()`, `popup_close` SFX, `back_bounce`, then
  `Transition.change_scene(ShopHub, WIPE)`.
- Beli: as today, with the per-unit `mark_shop_sold`.

The stage restocks itself in its own `_ready` (`setup_shelf()`), as the old
panel already did.

## State

No student state is touched: nothing crosses the `approved_students` ↔
`StudentData` bridge. Items reach `GameState.inventory` through
`add_to_inventory` as before. `inventory` is still the only persisted field.
`shop_week_key` / `shop_stock` / `shop_sold` stay session-scoped, and
`EndGameRehearsal`'s snapshot list already names all three.

## Kelas 7 / 8 / 9

No difference. The shelf restocks every (grade, week), and prices, the
six-slot count and the pair cap are the same in every grade. A new grade is
a new week (`set_grade` → `reset_shop_week`, unchanged).

## Files

| File | Change |
|---|---|
| `Assets/Images/Shop/Koperasi/shop_{background,herman,foreground}.png` | new art |
| `Assets/Images/Shop/UI/chat_bubble_tail.svg` | new |
| `Scenes/Koperasi/koprasi.tscn` | rebuilt as above |
| `Scripts/Koperasi/koprasi.gd` | toggle removed, back/beli rewired |
| `Scripts/Koperasi/rakbarang_1.gd` | slot model, `reconcile_taken`, header docs |
| `Scripts/GameState.gd` | `SHOP_SHELF_SIZE` 6, `SHOP_MAX_COPIES`, `roll_shop_stock`, count-based sold |
| `Scripts/Inventory/Cart.gd`, `ItemDatabase.gd` | doc comments only |
| `Scripts/Design/ThemeFactory.gd` + rebake | `ShopChatBubble` |
| `tests/test_shop_weekly_stock.gd` | roll, count-sold, reconcile tests |
| `tests/test_koperasi_shop_layout.gd` | new: layers, slots, bubble, tail colour |
| `tests/test_tall_screen_layout.gd` | Koperasi section rewritten for Stage |
| `tests/test_koperasi_tray.gd` | glow test → six slots under Stage |
| `tests/test_koperasi.gd` | drop `test_script_reads_design_tokens` (the script no longer styles anything) |
| `docs/superpowers/DEBT.md`, `CHANGELOG.md` | placeholder copy, removed sign's width entry |

## Not doing

- Routing purchase feedback ("Pembelian berhasil!") through Herman's bubble.
  MessageLabel stays as it is.
- Deleting the old art (`Illustration4.jpg`, `rak 1.jpg`, `rak2.jpg`), or the
  now-unused `ShopShelfButton` variation and its test. Both go on DEBT.md.
- Animating Herman or the bubble.
- Moving or restyling the tray.
- A tuned duplicate chance. The rate falls out of the 2-copy bag. The rejected
  alternative was a separate `SHOP_DUPLICATE_CHANCE` roll: one more tuning
  number, and it does not cap copies by itself.
