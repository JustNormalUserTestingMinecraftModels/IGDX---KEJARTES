# Lobby Layout Grid — Design

**Date:** 2026-09-29
**Screen:** `Scenes/Lobby/Lobby.tscn`
**Status:** Design approved by the owner. Not yet built.
**Builds on:** `2026-09-27-lobby-scrapbook-hud-design.md` (the scrapbook HUD). Its
intent stands: the classroom is the stage, the stepped book holds the actions,
JADWAL! is the biggest and greenest thing on screen. This pass moves pieces and
fixes spacing; it changes no art, colour or motion.

## 1. Why

The owner named three problems with the Lobby as built:

1. **The Minggu panel covers a face.** `ProgressHeader` (x 48–564, y 48–216)
   covers the back-left student's brows and eyes. The coin plate (y 48–160)
   covers the back-right student's hair.
2. **Some elements have no spacing.** A hand nudge of `%Hud` (commit
   `60d6d7d7`: 41 px left, 112 px down) put the book 64 px past the bottom edge
   at 1080×1920. The nav tiles' lips are clipped, the left margin is 7 px
   against 89 px on the right, and the icon rail's right edge sits 41 px inside
   the coin box's.
3. **It should read as clearly as the owner's two reference lobbies**, a hero
   game and a Gakumas-style idol lobby. Both keep the character centre clear
   and pin every control to an edge on a steady grid.

## 2. Decisions (owner-approved)

| Question | Answer |
|---|---|
| Layout direction | Progress leaves the top-left; the coin box leaves the top-right |
| Progress position | A compact tag at the top, **in the gap between the two back-row heads**, clearing their hair as well as their faces |
| Coin box position | Beside JADWAL!, in the step to the right of the raised block |
| Coin box on HUD swipe-down | Slides away with the book, comes back with it |
| The `60d6d7d7` nudge | Undone; everything returns to the 48 px grid |

Reference mock: "Option 2: top centre, squeezed between the heads" from the
2026-09-29 brainstorm. Coordinates below supersede it where they differ.

## 3. Measurements the layout rests on

Measured from the art on 2026-09-29, for all six students and every skin
(`StudentSkins.skins_for`), in both back slots, at 1080×1920:

- The back row always draws a **face rig** (`Lobby.face_rigs` holds all six).
  The rig's 1280×1280 canvas (`StudentFace.canvas_size`) is fitted, keeping
  its aspect and centred, into the slot's `Portrait` rect (`StudentFace.fit_canvas`).
  Slot1's Portrait is x 89–454, y 26–430; Slot2's is x 621–987, y 22–437.
- **Breathing** (`Lobby._animate_breathing`) scales the rig to (1.01, 1.02)
  about its bottom centre.
- **Parallax** (`ParallaxDiorama`) moves `StudentPortraitsContainer_Back` by
  up to depth 0.45 × travel (14, 8), about ±6.3 px across and ±3.6 px down.
- The hair crowns reach **y 55–80**. The brows start at **y ≈ 160**.
- The free gap between the heads, worst case, including breathing but before
  parallax:

| y | 100 | 120 | 140 | 160 | 180 | 200 | 220 | 240 |
|---|---|---|---|---|---|---|---|---|
| free x | 373–702 | 386–690 | 394–682 | 402–666 | 406–669 | 407–667 | 404–671 | 379–679 |

The gap is centred on x ≈ 536, not the screen centre (540).

On a 20:9 phone the classroom sits 240 px lower, so the tag is clear with a
wide margin there.

## 4. Layout

1080×1920 design screen. The book, coin box and rail sit on the `Safe` 48 px
margin, and neighbouring HUD pieces are at least **24 px** apart.

| Element | Rect (x, y, w, h) on the design screen | Anchored to |
|---|---|---|
| `ProgressHeader` (the tag) | 420, 48, 232, 184 | top-centre of `Safe/UI` (offsets −120 … +112) |
| `IconRail` | 936, 964, 96, 456 | bottom-right, inside `%Hud` |
| `ChevronGrip` | 214, 1352, 280, 96 | inside `%BookHud` (unchanged local offsets) |
| `RaisedBlock` | 48, 1400, 612, 216 | inside `%BookHud` (unchanged) |
| `DisplayUang` (coin box) | 684, 1444, 348, 112 | inside `%BookHud` |
| `Shelf` | 48, 1600, 984, 272 | inside `%BookHud` (unchanged) |

- `%Hud` offsets all return to **0**: the book spans x 48–1032 and ends at
  y 1872, the `Safe` bottom margin.
- The coin box's right edge (1032) lines up with the rail's and the shelf's.
  It is vertically centred in the step between the raised block's top (1400)
  and the shelf's top (1600).
- The rail's bottom sits 24 px above the coin box's top (1420 vs 1444). The
  rail pitch stays 96 + 24.
- **Tall phones (20:9, 1080×2400):** the tag stays pinned to the top, and the
  book, coin box and rail stay pinned to the bottom.

### The tag

`ProgressHeader` stays a `LobbyProgressHeader` `Panel` on the `ProgressPlate`
nine-patch. Its children keep absolute offsets (layout mode 0), as today, in
two rows. Local coordinates are within the 232×184 tag:

| Node | Local rect | Variation | Shows |
|---|---|---|---|
| `GradeBadge` (stacked, unchanged) | 10, 10, 106, 119 | `GradeBadge` | `KELAS` over `7` |
| `WeekCaption` (**new** Label) | 124, 24, 98, 30 | `CaptionLabel` | `Minggu` (static) |
| `WeekLabel` | 124, 58, 98, 50 | `WeekLabel` | `1 / 6` |
| `StarBar` | 10, 143, 73, 24 | `StarProgressBar` | the run's stars |
| `StarIcon` | 89, 139, 30, 30 | — | ★ |
| `StarNum` | 123, 137, 99, 36 | `StarNumLabel` | `0.0 / 3.0` |

- The badge rect is its **real** minimum size: `KELAS` at 22 px (74 wide) and
  the grade at 64 px, stacked, plus `space_sm` (16) margins. The old 88×84
  authored rect was smaller than that, so the badge always drew at its
  minimum size.
- `LobbyProgressHeader.WEEK_FORMAT` becomes `"%d / %d"`. The word `Minggu`
  moves to the static `WeekCaption` node, because `Minggu 1 / 6` at the
  `WeekLabel` size (36 px, 264 px wide) cannot fit a tag this narrow.
- No new theme variation and no rebake: `CaptionLabel` already exists.
- `StarBar/TipSparkle` stays a child of `StarBar` and follows it.

### The coin box

- `DisplayUang` (with `CoinIcon`, `Label`, `PlusUang`) is **reparented under
  `%BookHud`**. It rides the book's slide with no new tween code. It keeps
  `unique_name_in_owner`.
- Width drops from 360 to 348, the step's width less the 24 px gap. `999999`
  (the playtest seed's balance) must still fit. If it does not, the coin icon's
  inset gives up the difference, not the `+`.
- `PlusUang` stays mint (2026-09-27 spec § 3.2; `test_scrapbook_plus_and_hero_are_green`).

## 5. Behaviour changes

| What | Change |
|---|---|
| `LobbyHud._set_book_live` | Also disables `DisplayUang` while hidden, so a double-tap reopen or a mid-slide tap cannot press `+`. |
| `LobbyHud.tap_blockers()` | Unchanged: `Lobby.gd` already hands the chatter `%DisplayUang` beside `hud.tap_blockers()`. |
| `IdleFade.targets` | Only `ProgressHeader`. The coin box leaves with the book, so it no longer fades on its own. |
| `DailyReward.wallet_anchor` | Still `%DisplayUang`, now beside JADWAL!. The daily gift opens from the rail, so the HUD is always open when the coins fly. |
| `Lobby.gd`, `DailyLoginPanel.gd` | Already reach `DisplayUang` by unique name (`%DisplayUang/Label`, the chatter's `tap_blockers`). The reparent needs no code change there. |

Nothing else moves: the chevron's swipe, the rail's slide-right, the entrance
stagger, the badges, the chat bubble, the classroom art.

## 6. Build notes

- **Go through the editor, not the `.tscn` text** (CLAUDE.md § 4): `scene_open`
  → reparent and set properties → `scene_save`. `move_node` only reorders
  siblings, so reparent with `node_manage`. After each save, diff the scene for
  baked `@tool` offsets (StickyNote, DancerRig) and for stray `theme_override_*`.
- Do the scene work first and the scripts second (§ 4b), and restart the editor
  before any further `scene_save`.
- This work lives in the worktree `feat/lobby-layout-grid`. Verify it in a
  second editor on that worktree (memory: verify worktree changes in a second
  editor).
- No `Balance.gd` change, no rebake, no new art.

## 7. Tests

Update:

- `tests/test_lobby_layout.gd`: remove `HUD_NUDGE`. Set `DESIGN_RECTS` to § 4:
  `ProgressHeader` 420,48,232,184; `DisplayUang` 684,1444,348,112; `IconRail`
  and its four buttons from y 964; the book's controls at their un-nudged rects.
- `tests/test_lobby_hud.gd`:
  - `DisplayUang` is a descendant of `%BookHud`.
  - `IdleFade.targets` is exactly `[ProgressHeader]`.
  - `wallet_anchor` is still `%DisplayUang`.
  - Hiding the HUD disables `DisplayUang`'s mouse behaviour.
  - The week line reads `WEEK_FORMAT`, and `%WeekCaption` reads `Minggu`.
- `tests/test_tall_screen_layout.gd`: the 20:9 rects move by the un-nudge. The
  tag is 420,48,232,184, and the coin box is 684,1924,348,112.

Add (in `test_lobby_layout.gd`):

- **Hair and faces stay clear.** For each of the six students and every skin
  in `StudentSkins.skins_for`, take the rig base (`StudentSkins.layer_path(name,
  id, "face_base")`), and for each back slot:
  1. Map the base into the slot's `Portrait` rect the way `fit_canvas` does.
  2. Apply the breathing peak (1.01, 1.02) about the rect's bottom centre, and
     check both at rest and at the peak.
  3. Grow the tag's rect by the parallax reach (the `Parallax` node's `travel`
     × the `StudentPortraitsContainer_Back` depth) plus a 4 px clearance.
  4. Assert no opaque pixel (alpha > 128) lands inside that grown rect.

  Sample every 2nd row and column so the test stays well under the bridge's
  20 s limit.
- **The tag's contents fit.** Every child of `ProgressHeader` has a combined
  minimum size no larger than its authored rect, with the week line set to
  `8 / 8` and the stars to `3.0 / 3.0`.
- **Spacing.** Every pair among the tag, rail, coin box, raised block, shelf
  and chevron grip is either an authored overlap (the grip over the raised
  block, the raised block over the shelf) or at least 24 px apart.
- **On screen.** At 1080×1920 and 1080×2400, the book, coin box and rail lie
  fully inside the viewport, at least 48 px from the side and bottom edges.
- **Balance fits.** With `Label.text = "999999"`, its minimum width is at most
  the label rect's width.

Then run the Lobby suites (`lobby`, `lobby_layout`, `lobby_hud`,
`lobby_skins`, `lobby_tile_icons`, `tall_screen_layout`, `button_geometry`,
`viewport_editability`, `script_documentation`, `theme_factory`) and one full
run before ship-pr.

## 8. Out of scope

- Labels under the rail icons (both references have them). A separate pass, if
  wanted.
- Any change to the tile colours, the book art, the chevron motion or the
  classroom.
- The Balance-owned numbers in the 2026-09-27 spec's Phase 2.
