# Lobby Seating and Planks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Place the Lobby's students, hands and desk items as in the owner's reference picture, and turn the tall-phone black bands into desk-wood planks.

**Architecture:** Everything is authored in `Scenes/Lobby/Lobby.tscn`: four shared `Portrait` boxes, 24 hand-placed `Hand_<Name>` TextureRects, one `Backdrop` ColorRect. The new numbers are derived from measurements of the reference picture (below) and written into the scene as plain offsets and scales. No script changes.

**Tech Stack:** Godot 4.6 `.tscn`, GDScript test suites run through the godot-ai MCP `test_run`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-30-lobby-seating-and-planks-design.md`. Reference: `docs/superpowers/mockups/lobby-seating-reference-2026-09-30.jpg`.
- The room and desks keep today's framing; only portraits, hands, `ChatAnchor`s, `Backdrop` and the two new plank edges change.
- Never hand-edit a `.tscn` while an editor has this worktree open: quit it, edit, relaunch.
- No `theme_override_*`; suites stay `@tool` with no coroutine tests.
- Plank wood is `#B07A45`; edges are that colour darkened 35% (8 px, against the room) and lightened 12% (6 px).

## Revised in build

The per-seat "ratio and shift" rule of Task 3 was replaced (spec, section 2):
one item scale per row, the pictured four exact, the rest keep their x (off
the aisle in the front row) and rise with their row. The back-row x anchors
became the student's centre line (picture portrait centre 253.8 / 826.2 to
the game's desk-top centre 271.26 / 803.74), which keeps the back seats
centred on their desks; the back-right desk plate is offset -8 px in the
scene. The tables below are the first pass; the final numbers are the
constants in `tests/test_lobby_desk_items_fit.gd`.

## Measurements (2026-09-30)

Taken by masked template matching of the game's own textures in the picture, and by wood-colour bounding boxes.

> **Corrected 2026-10-01:** the game y0 values here (338, 683) are the top of the chair back drawn into each plate; the desks' real back edges are 400.045 / 400.0 / 766 / 766 (2026-10-01-lobby-seat-on-desk-edge).

**Desk top surfaces** (x0, y0, x1, y1):

| Desk | Picture | Game (classroom px) |
|---|---|---|
| back-left | 38, 523, 467, 678 | 35, 338, 483, 561 |
| back-right | 623, 524, 1052, 678 | 601, 338, 1049, 561 |
| front-left | 0, 813, 481, 1006 | 0, 683, 462, 943 |
| front-right | 599, 813, 1080, 1006 | 622, 683, 1080, 943 |

The picture's desks are other art (429 wide, 155 deep against 448 wide, 223 deep), so the map is a uniform scale `K = 448 / 429 = 1.0443` anchored on the desk's **back edge**; horizontally on the desk's centre for the back row and on its inner edge for the front row (the front desks run off the screen).

| Seat | x anchor (picture → game) | y anchor (picture → game) |
|---|---|---|
| Slot1 back-left | 252.5 → 259 | 523 → 338 |
| Slot2 back-right | 837.5 → 825 | 523.5 → 338 |
| Slot3 front-left | 481 → 462 | 813 → 683 |
| Slot4 front-right | 599 → 622 | 813 → 683 |

`game = anchor_game + (picture - anchor_picture) * K`.

**Textures in the picture** (origin = where the texture's pixel 0,0 lands; scale of the native texture):

| Element | Scale | Origin | Match error |
|---|---|---|---|
| Citra portrait (1280²), Slot2 | 0.20 | 698.2, 267.4 | 0.0003 |
| Thea portrait (1280²), Slot4 | 0.25 | 692.2, 491.8 | 0.0024 |
| Andi portrait, Slot1 | 0.20 | 125.8, 267.4 | mirrored from Citra (his head is occluded) |
| Marcel portrait, Slot3 | 0.25 | 67.8, 491.8 | mirrored from Thea |
| `Andi_Table.png` 518×239, Slot1 | 0.80 | 48.2, 499.0 | 0.0047 |
| `Citra_Table.png` 522×242, Slot2 | 0.80 | 630.0, 462.0 | 0.0027 |
| `Marcel_Table.png` 515×254, **flipped**, Slot3 | 1.00 | -41.0, 717.0 | 0.0018 |
| `Thea_Table.png` 428×278, Slot4 | 1.00 | 598.0, 727.0 | 0.0004 |

**Game targets** (classroom px; portrait = square side, hand = scale and drawn centre):

| Seat | Portrait square (x, y, side) | Pictured hand: scale, centre |
|---|---|---|
| Slot1 | 126.7, 71.1, 267.3 | Andi 0.8354, (262.1, 412.8) |
| Slot2 | 679.5, 70.6, 267.3 | Citra 0.8354, (826.4, 374.8) |
| Slot3 | 30.5, 347.6, 334.2 | Marcel 1.0443 flipped, (185.8, 715.4) |
| Slot4 | 719.3, 347.6, 334.2 | Thea 1.0443, (844.4, 738.4) |

---

### Task 1: Planks

**Files:**
- Modify: `Scenes/Lobby/Lobby.tscn` (`World/Backdrop`; new `World/PlankEdgeTop`, `World/PlankEdgeBottom`)
- Test: `tests/test_tall_screen_layout.gd`

- [ ] **Step 1: Failing tests.** In `tests/test_tall_screen_layout.gd` replace `test_lobby_backdrop_is_black_and_full_rect` with `test_lobby_backdrop_is_the_plank_and_full_rect` (colour `Color("b07a45")`, Full Rect, zero offsets) and add `test_lobby_plank_edges_meet_the_room`: each of `World/PlankEdgeTop` / `World/PlankEdgeBottom` has `anchor_top == anchor_bottom == 0.5`, spans the width, and offsets `(-974, -960)` / `(960, 974)`; each holds a `Dark` ColorRect 8 px against the room and a `Light` ColorRect 6 px beyond it; both sit before `Classroom` in `World`.
- [ ] **Step 2:** `test_run(suite="tall_screen_layout")` — expect the two new tests to fail.
- [ ] **Step 3:** With the editor closed, set `Backdrop` `color = Color(0.6902, 0.4784, 0.2706, 1)` and insert the two edge nodes after `Backdrop`:

```
[node name="PlankEdgeTop" type="Control" parent="World"]
layout_mode = 3
anchors_preset = -1
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_top = -974.0
offset_bottom = -960.0
grow_horizontal = 2
mouse_filter = 2

[node name="Light" type="ColorRect" parent="World/PlankEdgeTop"]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 6.0
grow_horizontal = 2
mouse_filter = 2
color = Color(0.7274, 0.541, 0.3581, 1)

[node name="Dark" type="ColorRect" parent="World/PlankEdgeTop"]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -8.0
grow_horizontal = 2
grow_vertical = 0
mouse_filter = 2
color = Color(0.4486, 0.311, 0.1759, 1)
```

`PlankEdgeBottom` mirrors it: offsets `960 .. 974`, `Dark` at the top (preset 10, `offset_bottom = 8`), `Light` at the bottom (preset 12, `offset_top = -6`).
- [ ] **Step 4:** Relaunch the editor; `test_run(suite="tall_screen_layout")` passes.
- [ ] **Step 5:** Commit `feat(lobby): desk-wood planks fill the tall-phone bands`.

### Task 2: Portraits and chat anchors

**Files:**
- Modify: `Scenes/Lobby/Lobby.tscn` (four `Portrait` and four `ChatAnchor` nodes)
- Test: `tests/test_lobby_layout.gd` (or the suite that pins portrait rects)

A `Portrait` is Full Rect in a 400×450 slot with `stretch_mode = 5`; its square art draws centred at `min(w, h)`. Make the node exactly the target square: `offset_left = x - slot_x`, `offset_top = y - slot_y`, `offset_right = offset_left + side - 400`, `offset_bottom = offset_top + side - 450`.

| Slot (origin) | offset_left | offset_top | offset_right | offset_bottom |
|---|---|---|---|---|
| Slot1 (50, 0) | 76.7 | 71.1 | -56.0 | -111.6 |
| Slot2 (620, 0) | 59.5 | 70.6 | -73.2 | -112.1 |
| Slot3 (50, 370) | -19.5 | -22.4 | -85.3 | -138.2 |
| Slot4 (620, 370) | 99.3 | -22.4 | 33.5 | -138.2 |

Each `ChatAnchor` moves by its portrait's centre shift (new square centre minus the old drawn centre).

- [ ] **Step 1:** Failing test `test_portraits_sit_where_the_reference_puts_them` pinning the four squares above (±0.5).
- [ ] **Step 2:** Run it; expect failure.
- [ ] **Step 3:** Editor closed; write the offsets; shift the anchors.
- [ ] **Step 4:** Run the Lobby suites; update any that pinned the old rects to the new ones.
- [ ] **Step 5:** Commit `feat(lobby): portraits take the reference picture's size and place`.

### Task 3: Hands and desk items

**Files:**
- Modify: `Scenes/Lobby/Lobby.tscn` (24 `Hand_*` nodes)
- Rewrite: `tests/test_lobby_desk_items_fit.gd`

A `Hand_*` draws its texture at native size centred in its node rect, scaled about `pivot_offset` (the rect's centre). Drawn centre = slot origin + (200 + (offset_left + offset_right) / 2, 450 + (offset_top + offset_bottom) / 2).

Per seat, for the pictured student: `ratio = target_scale / current_scale` (per axis) and `shift = target_centre - current_centre`. Set the pictured node to the uniform target scale and centre; give the other five nodes in that seat `scale *= ratio` and all four offsets `+= shift`. Slot3's `Hand_Marcel` also gets `flip_h = true`.

- [ ] **Step 1:** Rewrite the suite: 24 hands exist; per seat the pictured student's scale and drawn centre equal the table (±0.5 px, ±0.002); the other five share that seat's ratio and shift against the pre-change values recorded in the suite; `Hand_Marcel` is flipped only in Slot3; no hand's drawn box is wholly outside the classroom.
- [ ] **Step 2:** Run; expect failure.
- [ ] **Step 3:** Editor closed; apply with a one-off script that parses the scene, prints the before/after table, and rewrites the numbers.
- [ ] **Step 4:** Run `lobby_desk_items_fit` and every Lobby suite.
- [ ] **Step 5:** Commit `feat(lobby): hands and desk items follow the reference picture`.

### Task 4: Verify, document, ship-ready

- [ ] Render the Lobby at 1080×1920 and 1080×2400 (seeded roster Andi/Citra/Marcel/Thea in the pictured seats); overlay on the reference per desk; sheet of all six students in all four seats; send before/after at full size.
- [ ] `docs/superpowers/CHANGELOG.md` entry with the measurement table; DEBT.md: the tall-phone band item resolved.
- [ ] Targeted suites for every touched file; commit.
