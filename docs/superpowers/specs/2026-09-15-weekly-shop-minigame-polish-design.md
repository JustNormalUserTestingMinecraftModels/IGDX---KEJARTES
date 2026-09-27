# Weekly shop and minigame polish — design

Date: 2026-09-15 · Branch: `feat/weekly-shop-minigame-polish` · Approved via /gamecode Brief (bold defaults).

Four independent polish changes, one branch.

## 1. Koperasi: a weekly shelf, each item sold once

**Today.** `rakbarang_1.gd:setup_random_items()` calls
`ItemDatabase.get_random_items(4)` on every `_ready()` and again from
`koprasi.gd:_on_rak1_pressed()`, so the shelf reshuffles on every visit and a
shelf item can be tapped into the basket any number of times.

**After.**

- The shelf's four items are rolled once per week, keyed by
  `(GameState.current_grade, GameState.minggu_ke)`. Every visit in that week
  shows the same four, in the same slots.
- Each rolled item can be bought once that week. Tapping it puts one in the
  basket (`Cart`) and hides its shelf button. A second tap is impossible: the
  button is hidden.
- Holding it out of the basket (`_on_tray_remove_requested` → `Cart.remove_one`)
  or pressing Back (`Cart.clear()`) brings the button back.
- **Beli** marks every basket item sold. A sold item stays off the shelf for
  the rest of that week, across visits; the next week rolls a fresh shelf with
  nothing sold.
- Opening the shelf when every item is sold shows the existing
  `MessageLabel` with "Stok habis! Datang lagi minggu depan." (ShopMessageWarning).

**State** (new, on `GameState`, session-scoped — not persisted, per CLAUDE.md):

| Field | Type | Meaning |
|---|---|---|
| `shop_week_key` | `String` | `"<grade>-<minggu_ke>"` the stock was rolled for; `""` = never rolled |
| `shop_stock` | `Array[String]` | item names on the shelf, slot order |
| `shop_sold` | `Array[String]` | item names bought this week |

API on `GameState`:

- `shop_stock_for_week() -> Array[String]` — rolls via
  `ItemDatabase.get_random_items(SHOP_SHELF_SIZE)` when the key differs from
  the current week (clearing `shop_sold`), otherwise returns the stored stock.
- `mark_shop_sold(item_name: String)` — appends once.
- `is_shop_sold(item_name: String) -> bool`.
- `static func shop_week_key_for(grade: int, week: int) -> String`.
- `forget_session()` clears all three.

`SHOP_SHELF_SIZE := 4` is a named const on GameState (matches the four
`Barang*` buttons).

**Shelf visibility** is derived, never stored: a button is visible iff its item
is neither sold nor in `Cart.cart`. `rakbarang_1.gd` recomputes it on
`Cart.cart_changed`, so tap, hold-to-return, Back and Beli all route through one
function (`_refresh_shelf_visibility()`).

## 2. LombaMenari: wider window, three grades, dancer behind the zone

**Today.** In `_evaluate_swipe()` a hit counts inside 120 px of the hit zone's
centre, PERFECT inside 45 px. `_process()` drops a note as missed once it is
80 px past centre — so any hit later than 80 px was impossible despite the
120 px window. Feedback strings: PERFECT! / GOOD! / MISS! / WRONG SWIPE! /
TOO EARLY!. `CharacterDisplay` is after `HitZone` in the tree, so she draws
over it.

**After.**

- `@export var bagus_window_px: float = 170.0` and
  `@export var sempurna_window_px: float = 70.0` (group "Timing"), documented.
- A note is missed once it is more than `bagus_window_px` past centre, so the
  window is symmetric: early and late both get the full 170 px.
- `static func grade_for_distance(distance, sempurna_px, bagus_px) -> Grade`
  with `enum Grade { UPS, BAGUS, SEMPURNA }` — pure, tested.
- Feedback text: `SEMPURNA!` (gold, 100 pts), `BAGUS!` (green, 50 pts),
  `UPS!` (red) for every failure: a miss, a wrong swipe, a swipe with no note
  in range.
- Points, `perfect_hits`/`good_hits`/`missed_notes` and the star rubric are
  unchanged.
- The drawn `HitZone` box is not resized (it is already 432×307 px, larger
  than the old window, and notes size from it).
- Scene: `CharacterDisplay` moves to just after `Background`, before
  `HitZone`, so the hit zone and notes draw over her.

## 3. Win screen: a white photo frame

**Where.** `WinStage` (shared by EndCutscene and RunResult), win path only, so
RunResult still opens on exactly the frame EndCutscene blurred out on.

- New authored node `WinStage/PhotoFrame` (`Panel`, theme variation
  `PhotoFrame`), between `BarFill` and `Stage`: a white print with a soft drop
  shadow and a small corner radius. The painting (`Stage`) draws on top of it.
- New `ThemeFactory` variation `PhotoFrame` (Panel): white fill from a design
  token, `radius_sm`, a shadow. Rebake.
- Two `@export`s on WinStage: `photo_border` (white border width, default
  28 px) and `photo_gap` (space between frame and screen edge, default 36 px),
  in viewport pixels.
- `letterbox(area, inset := 0.0)` fits the painting into `area` shrunk by
  `inset` on every side, centred. `dress()` on a win passes
  `photo_border + photo_gap`, then sizes `PhotoFrame` to the painting rect
  grown by `photo_border`. On a loss `PhotoFrame` hides and the CG keeps its
  cover framing.
- At 1080×1920 with the defaults: painting 952×1269 at (64, 325); frame
  1008×1325 at (36, 297).

## 4. MainBola: keeper catches every off-target shot, target jumps after a goal

**Keeper.** When the shot is not aimed at the target
(`aimed_at_target == false`), the keeper's dive x is the ball's x
(`goalie_tx = target_x`), clamped inside the goal, and the ball's flight ends
at the keeper's chest (`keeper_catch_point()`), so it lands in his hands. The
dive time stays ≤ the ball's 0.40 s flight. The shot resolves as blocked. The
aimed-at-target branch (keeper dives away) is unchanged.

**Target respawn.** After each goal (`_on_goal_scored`), the target box
reappears at a random spot inside the goal mouth, at least one target-width
away from its last spot, with a random slide direction, and pops in (scale
from 0). Its height is random too, inside a band of the goal mouth
(`target_band_top_frac`/`target_band_bottom_frac` `@export`s, default
0.2–0.6 of the mouth height). When aimed, the ball flies to the target's
centre height instead of the fixed 45%.

- `static func pick_respawn(prev: Vector2, min_pos: Vector2, max_pos: Vector2,
  min_gap: float, rng: RandomNumberGenerator) -> Vector2` — pure, tested.
  Up to 12 tries for a spot ≥ `min_gap` away; if none fits, the spot farthest
  from `prev` among the tries.
- `target_y_pos` joins `target_x_pos` as state; `_process` keeps the
  horizontal slide and uses `target_y_pos`.

## Tests

- New `tests/test_shop_weekly_stock.gd` (`suite_name` `shop_weekly_stock`):
  same stock within a week, new roll on week or grade change, sold list
  clears on a new week, mark once, forget_session clears; source scans for the
  shelf wiring.
- New `tests/test_lomba_menari_timing.gd` (`lomba_menari_timing`):
  grade_for_distance boundaries, exports documented and defaulted, miss line
  uses the bagus window, the three strings present and the old five gone,
  CharacterDisplay before HitZone in the scene.
- New `tests/test_main_bola_shots.gd` (`main_bola_shots`): pick_respawn gap,
  bounds, fallback; source scans for keeper-to-ball and respawn call.
- Updated `test_win_stage` (letterbox with inset, PhotoFrame sized on win,
  hidden on lose), `test_end_cutscene` / `test_run_result` where they pin the
  240 px bars, `test_theme_factory` for the new variation.

## Not doing

Tilting the photo; a frame on the lose screen; prices or catalog changes;
points or star changes; resizing the drawn hit zone; persisting shop state.
