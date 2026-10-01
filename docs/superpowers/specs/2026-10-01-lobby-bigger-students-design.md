# Lobby students at their old size, desk items unchanged — design

**Date:** 2026-10-01 · **Branch:** `feat/lobby-bigger-students` · **Status:** approved in chat (owner's picks: split layers "B", size "C")

Follows `2026-10-01-lobby-seat-on-desk-edge-design.md` (PR #171).

## Goal

The owner finds the Lobby students too small. Students and their arms return
to the size they had before the 2026-09-30 picture pass, while the desk items
keep today's size and place. Everything else that #171 established holds:
each body ends on its desk's back edge, and each student's arms sit at one
place on its own body in every seat.

## 1. Art: arms and items as separate layers

Today each student's arms and desk items are one image,
`TanganItems/<Name>_Table.png` (skin: `Skins/<Name>/<name>_table_skin1.png`).
They are split into layers on the **same canvas** as that image, so the
layers register exactly where the old picture did:

- `TanganItems/<Name>_Arms.png`: the artist's `<Name>_Hand.png` from the
  shared Drive folder `1nJwHl1jXUR4jBrCJIkszcDp4MiF40MU0`, placed on the
  canvas where it matches the old picture (mean error at most 1.3/255; offsets
  Andi 150,7 · Citra 131,0 · Doni 118,0 · Marcel 101,0 · Shinta 149,0 ·
  Thea 139,0). Marcel's red book is part of his hands layer: he holds it.
- `Skins/<Name>/<name>_arms_skin1.png`: the owner's arms-only skin files
  (`<name>_hand_skin1.png`, already full canvas).
- `TanganItems/<Name>_Items.png`: the old default picture with the default
  arms removed. Pixels under the default arms come from the skin picture
  (whose thinner arms show the items there); pixels under both arms are
  cleared; alpha below 40 is dropped. Arms over items recompose both old
  pictures to within a few hundred antialiased edge pixels (largest: Thea,
  157 default / 127 skin).
  The Drive's own `<Name>_Table.png` matches the game only for Doni, Marcel
  and Thea; Andi's, Citra's and Shinta's are a different layout, so the items
  always come from the game's picture.

`StudentSkins`' `hand` layer points at the arms files. Items are one per
student, shared by every skin, so they are not a skin layer. The old
`_Table` images are deleted.

## 2. Scene

- Every `Hand_<Name>` (24) gets a sibling `Items_<Name>` TextureRect,
  directly before it (drawn under the arms), carrying the hand node's
  current transform and the items texture: today's desk items do not move.
- Every seat then grows about the bottom centre of its Portrait square (where
  the body meets the desk):
  - Portrait square side: back row 267.338 → **365**, front 334.172 →
    **400** (the sizes before the picture pass). Factors 1.36531 / 1.19699.
  - Every `Hand_<Name>` (now the arms) scales by the row factor, and its
    drawn centre moves to `pivot + (centre − pivot) × factor`.
  - Each `ChatAnchor` moves the same way.
- The front-row aisle rule now applies to items only. The arms follow the
  body: the arms that were pushed off the aisle together with their items
  (e.g. Andi in the front row) now sit on their own body.

## 3. Code

- `Lobby._show_hand_for` shows the `Items_<Name>` sibling of the chosen
  `Hand_<Name>` (and of the fallback student's).
- `Lobby._apply_hand_skins` still swaps only `Hand_*` textures: skins change
  arms, never items.

## 4. Tests

- `test_lobby_desk_items_fit`:
  - Portrait squares: the picture's square scaled by the row factor about its
    bottom centre; it still ends on the desk's back edge.
  - Arms: the row scale × factor, and the body-relative place on the grown
    body (the same `_place_on_body` rule); no aisle clamp.
  - Pictured students: the picture target scaled about the pivot.
  - Items: every `Items_<Name>` exists beside its `Hand_<Name>`, draws
    before it, and sits exactly where the 2026-10-01 rule put the hands:
    row scale unscaled, body-relative on the unscaled body, mirroring as the
    arms, front-row aisle clamp except for the pictured student in its seat.
  - Art registration: each student's items and every skin's arms share one
    canvas size.
- `test_student_skins`, `test_lobby_skins`: arms paths.
- Unchanged and binding: `test_lobby_layout` (the progress tag clears every
  back-row head for every student and skin; HUD off the front faces, now
  read from the rects), the desk-edge tests.

If the progress-tag rule fails at this size, stop and show the owner.

## Out of scope

Other screens' art; new item layouts; the idle bob (still moves bodies only).
