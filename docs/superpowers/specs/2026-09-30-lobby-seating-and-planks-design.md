# Lobby seating to the owner's picture, and planks on tall phones — design

**Date:** 2026-09-30 · **Branch:** `feat/lobby-match-mockup` · **Status:** approved in chat

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

For each seat, with its pictured student:

1. Measure, in the picture, the desk's visible rect and the student's head
   and hands-and-items boxes. Measure the same desk's rect in the game.
2. Map the picture's boxes through the desk-to-desk transform (uniform scale
   = game desk width / picture desk width, anchored on the desk's top-left),
   giving where the portrait and the hand texture must draw in the game.
3. **Portrait:** set the seat's `Portrait` offsets so the pictured student's
   portrait art lands on the mapped head box. Every student in that seat
   shares the box. `ChatAnchor` moves by the portrait's shift.
4. **Hands:** set the pictured student's `Hand_<Name>` in that seat to land
   on the mapped box. Compute that node's change as a scale ratio and a
   position shift of its pivot, and apply **the same ratio and shift to the
   other five `Hand_*` nodes in that seat** (owner's pick "A"). The by-eye
   proportions between students, including the owner-sized Citra, Shinta and
   Thea, are therefore kept.

Students come out smaller against their desks than today (first estimate
10-15%), and the back row sits fully in view.

Every measured number (picture boxes, game desk rects, resulting ratios and
shifts per seat) is recorded in the plan and in the changelog entry, so the
placement can be re-derived.

## 3. Tests

- `tests/test_lobby_desk_items_fit.gd`: the picture is the new reference.
  The "inside the desk's width" rule and its `OWNER_SIZED` exception are
  replaced by the placements the picture produces, pinned per seat (the
  pictured student's scale and position, and that the other five share the
  seat's ratio and shift). Kept: 24 hands exist, and no hand item is clipped
  by the classroom's edges.
- `tests/test_tall_screen_layout.gd`: `test_lobby_backdrop_is_black_and_full_rect`
  becomes the plank colour and Full Rect; new checks that the two edge
  strips meet the room's top and bottom at 1080x2400 and are off screen at
  1080x1920. The Lobby's other tall and design-size rects are re-pinned only
  where a portrait or hand moved.
- Any other suite pinning the old portrait or hand numbers
  (`lobby`, `lobby_layout`, `lobby_skins`, `lobby_look`, `student_face`,
  `face_rig_roster`) is updated to the new ones, not loosened.

## 4. Verification

- An overlay of the game's render on the reference picture, one crop per
  desk, for the four pictured placements.
- A sheet of all six students in each of the four seats.
- Before/after at 1080x1920 and 1080x2400, full size, sent to the owner.
- Targeted suites for every file touched, then the full suite in `ship-pr`.

## Out of scope

The picture's framing (room lower, wall above); new background art; the
book HUD; the 1.41x-upscaled `lobby_no_tables.png` (DEBT.md).
