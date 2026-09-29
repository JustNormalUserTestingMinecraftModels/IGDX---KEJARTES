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
   sits over the upper head of the back-left student (portrait slot x 89–454,
   y 26–430); the coin plate (y 48–160) sits over the back-right student's hair.
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
| Layout direction | Option A: progress collapses to a slim strip on the top edge |
| Strip position | Centred horizontally (not top-left) |
| Coin box position | Beside JADWAL!, in the step to the right of the raised block |
| Coin box on HUD swipe-down | Slides away with the book, comes back with it |
| The `60d6d7d7` nudge | Undone; everything returns to the 48 px grid |

Reference mock: the revised option A widget from the 2026-09-29 brainstorm.
Coordinates below supersede it where they differ.

## 3. Layout

1080×1920 design screen. Every element sits on the `Safe` 48 px margin, and
neighbouring pieces are at least **24 px** apart.

| Element | Rect (x, y, w, h) on the design screen | Anchored to |
|---|---|---|
| `ProgressHeader` (strip) | 220, 48, 640, 72 | top-centre of `Safe/UI` |
| `IconRail` | 936, 964, 96, 456 | bottom-right, inside `%Hud` |
| `ChevronGrip` | 214, 1352, 280, 96 | inside `%BookHud` (unchanged local offsets) |
| `RaisedBlock` | 48, 1400, 612, 216 | inside `%BookHud` (unchanged) |
| `DisplayUang` (coin box) | 684, 1444, 348, 112 | inside `%BookHud` |
| `Shelf` | 48, 1600, 984, 272 | inside `%BookHud` (unchanged) |

- `%Hud` offsets all return to **0**: the book spans x 48–1032 and ends at
  y 1872, the `Safe` bottom margin.
- The coin box's right edge (1032) lines up with the rail's right edge and the
  shelf's right edge. It is vertically centred in the step between the raised
  block's top (1400) and the shelf's top (1600).
- The rail's bottom sits 24 px above the coin box's top (1420 vs 1444). Rail
  pitch stays 96 + 24.
- **Tall phones (20:9, 1080×2400):** the strip stays pinned to the top, and the
  book, coin box and rail stay pinned to the bottom. The classroom stays centred,
  so it sits 240 px lower and the faces clear the strip by more.

### The strip

One row on the existing `ProgressPlate` nine-patch, left to right:

`[KELAS 7 badge] [Minggu 1 / 6] [star bar, fills the rest] [★] [0.0 / 3.0]`

- `GradeBadge/Stack` becomes an `HBoxContainer`, so the badge reads `KELAS 7`
  on one line and fits the 72 px height. Theme variations are unchanged
  (`GradeBadge`, `GradeBadgeLabel`, `GradeBadgeNumber`, `WeekLabel`,
  `StarProgressBar`, `StarNumLabel`).
- The row is a container of static nodes in the `.tscn`. The only overrides
  are layout constants (`separation`, `margin_*`), which the visual rules allow.
- `StarBar/TipSparkle` stays a child of `StarBar` and follows it.

### The coin box

- `DisplayUang` (with `CoinIcon`, `Label`, `PlusUang`) is **reparented under
  `%BookHud`**. It rides the book's slide with no new tween code.
- Width drops from 360 to 348 (the step's width minus the 24 px gap), so the
  label narrows by 12 px. `999999` (the playtest seed's balance) must still fit;
  if not, the coin icon's inset gives up the difference, not the `+`.
- `PlusUang` stays mint (spec 2026-09-27 § 3.2; `test_scrapbook_plus_and_hero_are_green`).

## 4. Behaviour changes

| What | Change |
|---|---|
| `LobbyHud._set_book_live` | Also disables `DisplayUang` while hidden, so a double-tap reopen or a mid-slide tap cannot press `+`. `tap_blockers()` includes it for the same reason. |
| `IdleFade.targets` | Only `ProgressHeader`. The coin box leaves with the book; it no longer fades on its own. |
| `DailyReward.wallet_anchor` | Re-pointed to the moved `DisplayUang`. The coin fly-in lands beside JADWAL!. The daily gift is opened from the rail, so the HUD is always open when coins fly. |
| `Lobby.gd`, `DailyLoginPanel.gd` | Already reach `DisplayUang` by its unique name (`%DisplayUang/Label`, the chatter's `tap_blockers`), so the reparent needs no code change there; `DisplayUang` must keep `unique_name_in_owner`. |

Nothing else moves: the chevron's swipe, the rail's slide-right, the entrance
stagger, the badges, the chat bubble, the classroom art.

## 5. Build notes

- **Go through the editor, not the `.tscn` text** (CLAUDE.md § 4): `scene_open`
  → reparent/set properties → `scene_save`. `move_node` only reorders siblings,
  so reparent with `node_manage`. After each save, diff the scene for baked
  `@tool` offsets (StickyNote, DancerRig) and for stray `theme_override_*`.
- Do the scene work first and the scripts second (§ 4b), then restart the editor
  before any further `scene_save`.
- This work lives in the worktree `feat/lobby-layout-grid`. Verify it in a second
  editor on that worktree (memory: verify worktree changes in a second editor).
- No `Balance.gd` change, no rebake (no new theme variation), no new art.

## 6. Tests

Update:

- `tests/test_lobby_layout.gd`: remove `HUD_NUDGE`; set `DESIGN_RECTS` to § 3
  (`ProgressHeader` 220,48,640,72; `DisplayUang` 684,1444,348,112; `IconRail` and
  its four buttons from y 964; book controls at their un-nudged rects).
- `tests/test_lobby_hud.gd`: `DisplayUang` is a descendant of `%BookHud`;
  `IdleFade.targets` is exactly `[ProgressHeader]`; `wallet_anchor` is still
  `%DisplayUang`; hiding the HUD disables `DisplayUang`'s mouse behaviour.
- `tests/test_tall_screen_layout.gd`: `DisplayUang` is still under the safe area
  (through `%Hud`); the strip is top-anchored and centred.

Add (in `test_lobby_layout.gd`):

- **Faces stay clear.** For each of the six students, and every skin they can
  wear, take the texture the back row actually draws: the face rig's base
  (`StudentSkins.face_base_for`) when the student has a rig, otherwise
  `StudentSkins.portrait_for` (see `Lobby.gd`'s seat loop; a rig is fitted to
  the `Portrait` rect by `_match_rect`). Find its topmost opaque row
  (alpha > 128), map it into the back slots' `Portrait` rect (`stretch_mode` 5,
  keep aspect centred), grow it by the breathing tween's peak scale about its
  pivot, and assert the strip's bottom (y 120) sits above it, with the design
  screen's classroom at y 0. If a student's hair crown still reaches above
  y 120, stop and raise it with the owner rather than shrinking the strip
  below 72 px.
- **Spacing.** Every pair among strip, rail, coin box, raised block, shelf and
  chevron grip either overlaps by authored design (grip over raised block, raised
  block over shelf) or is at least 24 px apart.
- **On screen.** At 1080×1920 and 1080×2400, the book, coin box and rail rects
  lie fully inside the viewport, and each sits at least 48 px from the side and
  bottom edges.
- **Balance fits.** With `Label.text = "999999"`, its minimum width is at most
  the label rect's width.

Then run the Lobby suites (`lobby`, `lobby_layout`, `lobby_hud`,
`lobby_skins`, `lobby_tile_icons`, `tall_screen_layout`, `button_geometry`,
`viewport_editability`, `script_documentation`) and one full run before ship-pr.

## 7. Out of scope

- Labels under the rail icons (both references have them). A separate pass, if
  wanted.
- Any change to the tile colours, the book art, the chevron motion or the
  classroom.
- The Balance-owned numbers in the 2026-09-27 spec's Phase 2.
