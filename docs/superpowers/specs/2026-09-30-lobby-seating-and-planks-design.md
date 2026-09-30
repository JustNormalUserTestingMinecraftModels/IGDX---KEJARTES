# Lobby seating to the owner's picture, and planks on tall phones — design

**Date:** 2026-09-30 · **Branch:** `feat/lobby-match-mockup` · **Status:** approved in chat; seating rule revised in build (section 2)

Reference picture: `docs/superpowers/mockups/lobby-seating-reference-2026-09-30.jpg`
(1080x1920, attached by the owner in chat).

## Goal

Two changes to `Scenes/Lobby/Lobby.tscn`, both owner decisions:

1. On a phone taller than 9:16 the Lobby's 240 px black bands above and
   below the classroom become **desk-wood planks** (owner's pick "B" of
   flat colour / edge-carried colour / fade / blurred room / three plank
   tones).
2. The **students, their hands and their desk items** are placed as in the
   reference picture, measured relative to each desk. The room and desks keep
   today's framing (owner's pick "B": not the picture's lower, zoomed-out
   framing).

## 1. Planks

The classroom is one 1080x1920 piece held at the screen's centre
(`World/Classroom`); `World/Backdrop` is a full-rect black `ColorRect` behind
it. At 1080x2400 that leaves 240 px above and below.

- `World/Backdrop.color` becomes the desk wood, `#B07A45`. It stays Full
  Rect, so it is the plank at any height; the colour is the owner's knob, on
  the node.
- Two edge strips mark where each plank meets the room, as in the mock-up:
  `World/PlankEdgeTop` and `World/PlankEdgeBottom`, each a `Control` holding
  two `ColorRect`s -- an 8 px dark line (the wood darkened 35%) against the
  room and a 6 px light line (the wood lightened 12%) beyond it. They are
  placed by anchors only: top edge `anchor_top = anchor_bottom = 0.5`,
  offsets `-974 .. -960`; bottom edge offsets `960 .. 974`. At 1080x1920 both
  sit just off screen, so the design size is unchanged.
- They sit below `Classroom` in the World layer, so the room and its light
  draw over them. `WindowLight` reaches 420 px above the room and adds a
  faint warm glow (about +6/255) to the top plank; left as it is.
- No theme variation and no script: layout-only nodes with colours.

## 2. Seating

### What the Lobby has

- One `Portrait` box per seat (`StudentPortraitsContainer_Back/Slot1..2`,
  `_Front/Slot3..4`), shared by whichever student sits there, with a
  `ChatAnchor` sibling.
- One `Hand_<Name>` node per student per seat (24), each drawing that
  student's `TanganItems/<Name>_Table.png` -- arms and desk items in one
  texture -- at native size, scaled about `pivot_offset`, hand-placed.
- Four desk plates: `Meja_KiriAtas`, `Meja_KananAtas`, `Meja_KiriBawah`,
  `Meja_KananBawah`.

### What the picture shows

Four placements: **Andi** back-left (Slot1), **Citra** back-right (Slot2),
**Marcel** front-left (Slot3), **Thea** front-right (Slot4). Marcel's items
are mirrored against his texture (book stack left, pencil case right), so
his `Hand_Marcel` in that seat is flipped (`flip_h`).

### The rule

As first approved, each seat's other five students were to take the pictured
student's scale ratio and shift. **Revised in build, 2026-09-30**, on what
the measurements showed:

- **The picture's desks are other art** (tops 429 px wide and 155 deep against
  the game's 448 and 223), so there is no exact "same place on the desk".
  Picture pixels map to game pixels by `K = 448 / 429`, anchored vertically
  on each desk's back edge, where the body meets it.
- **One item scale per row.** The picture draws both back-row students' items
  at 0.80 of the native art and both front-row students' at 1.00. Today's
  scales differ by student (Andi 0.79, Citra 1.10 in the same row), so a
  per-seat ratio would have left Andi at 0.61 in Citra's seat and 0.84 in his
  own. Every `Hand_*` in a row therefore wears that row's picture scale times
  K (0.835 back, 1.044 front), uniform on both axes. This supersedes the
  2026-09-29 by-eye sizes of Citra, Shinta and Thea: the picture is newer and
  shows Citra and Thea at the row scale.
- **The pictured four are matched exactly** (scale and drawn centre). Marcel
  in the front-left seat is mirrored, as pictured.
- **The other students keep their own place along the desk** and their
  mirroring, and rise by their row's shift (the mean of its two pictured
  students' rise: 72 px back, 80 px front). In the front row an item wider
  than its desk is pushed to run off the screen's edge, as the picture's
  Marcel does, never over the aisle.
- **Portraits.** Each seat's `Portrait` becomes exactly the pictured square
  (0.20 of 1280 px in the back row, 0.25 in the front, times K); `ChatAnchor`
  moves with it. Back-row students stay centred on their desk's top, the
  owner's 2026-09-29 rule that `test_lobby_layout` pins: the picture's Citra
  sits 11 px off her (other) desk's centre, which is not carried over, and
  her hands keep the picture's offset from her body. Andi's and Marcel's
  heads are occluded in the picture, so their seats mirror Citra's and
  Thea's.

Students come out smaller than before (back row 365 px to 267, front 365 to
334), and the back row sits fully in view.

Every measured number (picture boxes, game desk rects, resulting ratios and
shifts per seat) is recorded in the plan and in the changelog entry, so the
placement can be re-derived.

## 3. Tests

- `tests/test_lobby_desk_items_fit.gd`: the picture is the new reference.
  The "inside the desk's width" rule and its `OWNER_SIZED` exception are
  replaced by: each seat's portrait square; the pictured four's scale,
  mirroring and drawn centre; every hand wearing its row's scale, keeping its
  old x (off the aisle in the front row) and rising with its row, against a
  recorded table of the old placements; and no item more than a quarter
  outside the classroom.
- `tests/test_tall_screen_layout.gd`: `test_lobby_backdrop_is_black_and_full_rect`
  becomes the plank colour and Full Rect; new checks that the two edge
  strips meet the room's top and bottom at 1080x2400 and are off screen at
  1080x1920. The Lobby's other tall and design-size rects are re-pinned only
  where a portrait or hand moved.
- `tests/test_lobby_layout.gd`: the header-clears-the-hair test now passes a
  back seat that never reaches the header's keep-out by geometry (the smaller
  squares stop short of it); a seat that does reach it must still scan.

## 4. Verification

- An overlay of the game's render on the reference picture, one crop per
  desk, for the four pictured placements.
- A sheet of all six students in each of the four seats.
- Before/after at 1080x1920 and 1080x2400, full size, sent to the owner.
- Targeted suites for every file touched, then the full suite in `ship-pr`.

## Out of scope

The picture's framing (room lower, wall above); new background art; the
book HUD; the 1.41x-upscaled `lobby_no_tables.png` (DEBT.md).
