# Lobby students sit at the desk, not on the chair — design

**Date:** 2026-10-01 · **Branch:** `fix/lobby-seat-desk-edge` · **Status:** approved in chat (owner's pick "A")

Fixes the 2026-09-30 seating pass
(`specs/2026-09-30-lobby-seating-and-planks-design.md`, PR #169).

## The problem

Every Lobby student sits about one chair-back too high. Their arms and desk
items rest on the chair back that is drawn into each desk plate, not on the
desk top, so they read as perched on the chair. The owner's reference picture
(`docs/superpowers/mockups/lobby-seating-reference-2026-09-30.jpg`) has the
body covering the chair and the arms on the desk.

## The cause

The 2026-09-30 plan found each game desk's top by a wood-colour bounding box.
The chair back baked into every `Meja/*.png` is the same wood, so the box
started at the **chair's top**, not the desk's back edge:

| Desk plate | Chair top (texture px) | Real desk back edge (texture px) | Chair height |
|---|---|---|---|
| `kiri_atas.png` | 343 | 411 | 68 |
| `kanan_atas.png` | 343 | 409 | 66 |
| `kiri_bawah.png` | 687 | 765 | 78 |
| `kanan_bawah.png` | 687 | 765 | 78 |

(first alpha > 128 row; the desk edge is the first row wider than 300 px.)

Every seat was anchored on that chair top (plan: 338 back, 683 front), so the
row "rise" of 72 / 80 px was mostly the chair's height. With the chair
excluded the game desk is 156 px deep against the picture's 155: the desks are
the same art, and the plan's "other art" conclusion came from the same error.

## The fix

**Move whole seats, down, by one number per seat.** For each of the four seats,
shift both the portrait slot (`StudentPortraitsContainer_*/SlotN`, which holds
`Portrait` and `ChatAnchor`) and the hands slot (`StudentHandsContainer_*/SlotN`,
which holds all six `Hand_*`) down by the same `drop`:

    drop = desk_back_edge - portrait_square_bottom

- `desk_back_edge`: the first row of the seat's desk plate whose opaque
  (alpha > 128) run is wider than 300 px — the chair back is at most 220 px
  wide, so this skips it — mapped to classroom px by adding the plate's
  `offset_top` (all four plates have y scale 1).
- `portrait_square_bottom`: the seat's `Portrait` rect bottom in classroom px
  today (back 338.4, front 681.8).

In the picture, each pictured portrait square ends within 1.2 px of its
desk's back edge (Thea: 491.8 + 320 = 811.8 against 813), so this is the
picture's own rule. Expected drops: about **63 px back, 82 px front**, exact
values measured in build and recorded in the test.

Nothing else moves. Portrait sizes, hand scales, x positions and Marcel's
flip in Slot3 stay as #169 set them. Both slots of a seat move by the same
`drop`, so body, hands and items keep their relative placement from the
picture. That is 8 node edits in `Scenes/Lobby/Lobby.tscn`, made in the worktree
(no editor attached to it), and no script changes:

- the face rig copies `Portrait`'s rect (`Lobby._match_rect`), so it follows;
- the idle bob tweens from the container's current position, so it follows;
- the tall-phone layout moves `World/Classroom` as one piece.

The back row moves down toward the front desks; the all-students sheet
(Verification) checks that no back-row item now runs under a front desk
plate or a front student.

## Tests

- `tests/test_lobby_desk_items_fit.gd`: the pinned portrait squares and hand
  centres move by their seat's `drop`; the recorded 2026-09-30 anchor
  numbers (338 / 683) are replaced by the real desk edges. **New test:** each
  seat's `Portrait` bottom equals its desk plate's back edge (±1 px), where
  the edge is read from the plate texture's alpha at run time (widest-run
  rule above), not from a constant. That test would have caught this bug.
- `tests/test_lobby_layout.gd`, `tests/test_tall_screen_layout.gd`,
  `tests/test_student_chatter.gd`, `tests/test_parallax_diorama.gd`: re-pin
  only the rects that moved; no rule changes.
- Targeted `test_run` per touched suite, then the full suite in `ship-pr`.

## Verification

- A side-by-side of the reference picture and the game, like the one sent in
  chat on 2026-10-01, showing arms on the desk top and the chair hidden.
- A sheet of all six students in each of the four seats (skins differ in
  width, so check that no chair shows above an arm).
- Full-size before/after at 1080x1920 and 1080x2400, sent to the owner.

## Docs

- The 2026-09-30 spec and plan get a one-line note pointing here (their
  desk-edge numbers are wrong).
- `docs/superpowers/CHANGELOG.md`: one entry.
- The new test pins the rule, so no CLAUDE.md line: the desk plates carry a
  chair back, so a desk is measured by its first run wider than 300 px, never
  by a wood-colour bounding box. The test's `##` header says so.

## Out of scope

Separating the chairs from the desk art (option "B"); removing them (option
"C"); any change to sizes, x positions or the room's framing.
