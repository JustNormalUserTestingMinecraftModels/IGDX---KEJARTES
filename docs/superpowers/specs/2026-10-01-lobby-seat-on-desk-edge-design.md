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

(chair top: first row with alpha > 0.5; desk edge: first row whose longest
opaque run is wider than 260 px.)

Every seat was anchored on that chair top (plan: 338 back, 683 front), so the
row "rise" of 72 / 80 px was mostly the chair's height. With the chair
excluded the game desk is 156 px deep against the picture's 155: the desks are
the same art, and the plan's "other art" conclusion came from the same error.

## The fix

**Re-anchor the picture on the real desk edge, and move whole seats by the
correction.** The 2026-09-30 mapping `game = anchor_game + (picture -
anchor_picture) * K` stays; only each seat's `anchor_game.y` changes, from the
chair top to the desk's real back edge. Both slots of the seat — the portrait
slot (`StudentPortraitsContainer_*/SlotN`, holding `Portrait` and
`ChatAnchor`) and the hands slot (`StudentHandsContainer_*/SlotN`, holding all
six `Hand_*`) — move down by that correction:

    drop = desk_back_edge - old anchor_game.y

- `desk_back_edge`: the first row of the seat's desk plate whose longest
  opaque (alpha > 0.5) run is wider than 260 px — the chair backs are at most
  223 px wide and each desk's first row at least 303 — plus the plate's
  `offset_top` (all four plates have y scale 1).

| Seat | Plate | Edge (texture + offset_top) | Old anchor | drop |
|---|---|---|---|---|
| Slot1 back-left | `Meja_KiriAtas` | 410 − 9.955 = 400.045 | 338 | 62.045 |
| Slot2 back-right | `Meja_KananAtas` | 410 − 10 = 400.0 | 338 | 62.0 |
| Slot3 front-left | `Meja_KiriBawah` | 766 + 0 = 766.0 | 683 | 83.0 |
| Slot4 front-right | `Meja_KananBawah` | 766 + 0 = 766.0 | 683 | 83.0 |

Each seat's `Portrait` square then ends within 1.25 px of its desk's back
edge, the gap the picture itself has (Thea: 491.8 + 320 = 811.8 against 813,
times K).

Nothing else moves. Portrait sizes, hand scales, x positions and Marcel's
flip in Slot3 stay as #169 set them. Both slots of a seat move by the same
`drop`, so body, hands and items keep their relative placement from the
picture. That is 8 node edits in `Scenes/Lobby/Lobby.tscn`, made through the
worktree's own editor, and no script changes:

- the face rig copies `Portrait`'s rect (`Lobby._match_rect`), so it follows;
- the idle bob tweens from the container's current position, so it follows;
- the tall-phone layout moves `World/Classroom` as one piece.

The back row moves down toward the front desks; the all-students sheet
(Verification) checks that no back-row item now runs under a front desk
plate or a front student.

## Tests

- `tests/test_lobby_desk_items_fit.gd`: `anchor_game.y` becomes the real
  edges above, so every existing picture check follows. **Two new tests:**
  each seat's `anchor_game.y` equals its plate's back edge read from the
  texture's alpha at run time (the rule above), and each seat's `Portrait`
  ends within 1.5 px of that edge. Either would have caught this bug.
- `tests/test_lobby_layout.gd`: the front-row head centres it hard-codes
  (y 389) move down 83 px to y 472; `DESK_TOP_ROWS` starts at the desk's real
  back edge (410, not the chair's 343). The back-row centring still holds:
  the desk-top centre moves 1.54 px, inside its 2.5 px tolerance.
- `tests/test_tall_screen_layout.gd`, `tests/test_student_chatter.gd`,
  `tests/test_parallax_diorama.gd`: pin no seat heights; run unchanged.
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
  chair back, so a desk is measured by its first run wider than 260 px, never
  by a wood-colour bounding box. The test's `##` header says so.

## Out of scope

Separating the chairs from the desk art (option "B"); removing them (option
"C"); any change to sizes, x positions or the room's framing.
