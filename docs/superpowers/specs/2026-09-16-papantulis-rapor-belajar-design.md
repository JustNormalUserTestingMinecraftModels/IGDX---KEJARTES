# Papan tulis, Rapor and the Belajar button — design

**Date:** 2026-09-16
**Scope:** three screen fixes the player can see on a phone taller than 9:16.

Continues `2026-09-15-tall-phone-layout-design.md`, which did Phase 1 (Lobby,
Koperasi, StudentCard, StudentList) and listed AturJadwal and Rapor as Phase 2.
This spec does the two of Phase 2 the user asked for, plus one defect Phase 1
left in StudentCard. It does not do the rest of Phase 2 (CutScene, Inventory)
and does not do the whole of AturJadwal — only its board.

The four rules from that spec still govern: backgrounds fill and cover, UI sits
on its edge, UI sits inside a `SafeAreaMargin`, and a picture carries its items.

---

## 1. AturJadwal: the board becomes `papantulis.png`

### Today

`Scenes/AturJadwal/atur_jadwal.tscn` draws the board as `BGHari`, a
`TextureRect` on `Assets/Images/UI/whiteboard.png` with anchors
`(0, 0, 1.039, 0.995)` and offsets `(0, 0, -42.12, 9.6)`. At 1080×1920 that
resolves to exactly 1080×1920, so the art lands 1:1. On a taller viewport the
rect grows with the screen and `expand_mode = 1` scales the texture into it, so
the board stretches: at 1080×2400 it is 1.25× tall and the shelf baked into the
art slides from y 766 down to y 957, while the `ShelfFace` / `ShelfEdge`
`ColorRect`s that duplicate that shelf stay at 766–843. The result is a doubled
shelf and a stretched board.

The five sticky notes (`Senin`…`Jumat`) are children of `BGHari` in position
mode at y 1000–1693, so they do not follow the stretch.

### The art

Both files are 1080×1920 RGBA and structurally identical; only the shelf's
height in the frame differs.

| | `whiteboard.png` | `papantulis.png` |
|---|---|---|
| transparent | rows 0–765 | rows 0–272 |
| wood face `#B37D4D` | 766–816 | 273–323 |
| dark edge `#775A3A` | 817–842 | 324–349 |
| board face | 843–1919 | 350–1919 |
| board height | 1077 px | **1570 px** |

The new art is fully transparent above its shelf and fully opaque from the
shelf down, across the full width — the same contract the old one met, which is
what lets the splash art show through above the shelf. Its bottom row carries a
soft horizontal vignette: `#E0E0E0` at the centre, `#EEEEEE` at the left edge,
`#E4E4E4` at the right.

The extra 493 px of board is the safety margin. Nothing else changes.

### The change

`BGHari` stops being a stretching full-rect node and becomes a **fixed-size
picture unit** (rule 4), pinned to the top so the shelf cannot move:

- `texture` → `res://Assets/Images/UI/papantulis.png`
- anchors `(0, 0, 0, 0)`, offsets `(0, 493, 1080, 2413)`

493 = 766 − 273: the offset that puts the art's baked shelf exactly on the
`ShelfFace` / `ShelfEdge` `ColorRect`s at 766–843, where it is today. The rect
is exactly the texture's 1080×1920, so the art draws 1:1 and the baked shelf
and the `ColorRect`s coincide to the pixel. The board face then runs from
screen y 843 down to **2413**.

Deliberately *not* scaled to fit a taller screen: at any k ≠ 1 the baked shelf
bands shift a few pixels out from under the `ColorRect`s and the dark edge
draws a visibly thicker line. A 1:1 draw is what makes the seam invisible.

The five notes keep their screen positions. Their offsets are in `BGHari`'s
local space, which now starts 493 px down, so each note's `offset_top` and
`offset_bottom` drop by 493:

| Note | today (top/bottom) | new |
|---|---|---|
| Senin | 1000 / 1267 | 507 / 774 |
| Selasa | 1206 / 1473 | 713 / 980 |
| Rabu | 1017 / 1284 | 524 / 791 |
| Kamis | 1414 / 1681 | 921 / 1188 |
| Jumat | 1426 / 1693 | 933 / 1200 |

Horizontal offsets and `pivot_offset` are untouched. Being children of the
board, the notes now move with it as one piece.

### Beyond 2413

2413 covers 20:9 (2400) with 13 px to spare. A 21:9 phone gets 2520 and would
show 107 px of wall below the board. A new `BoardFill` `ColorRect` closes that
for any aspect ratio:

- `color` `#E0E0E0` (the art's bottom-centre tone), `mouse_filter = 2`
- anchors `(0, 0, 1, 1)`, offsets `(0, 843, 0, 0)` — top pinned under the
  shelf, bottom following the screen
- inserted **between** the splash `TextureButton` and `BGHari`

It is invisible at every height up to 2413 because the opaque board covers it.
Below that it continues the board. The seam it can show is the art's own
vignette — 14/255 lighter at the extreme left edge — at the very bottom of a
21:9 screen. That is the accepted cost of not stretching the art.

Child order becomes: `Backdrop` → `TextureButton` (splash) → `BoardFill` →
`BGHari` → `ShelfFace` → `ShelfEdge` → the rest. This preserves the two
orderings `tests/test_atur_jadwal.gd` pins: the splash draws before the board,
and the shelf draws after it.

### Out of scope here

The rest of Phase 2's AturJadwal — the wall backdrop filling, the top band and
shelf pinning top, `StartWeek` moving next to `BackButton` — is not part of
this pass. `StartWeek` stays at its fixed y 1754. The user asked for the board.

`whiteboard.png` stays in the tree; after this change nothing references it.

---

## 2. Rapor: fill the bottom like StudentCard

### Today

`Scenes/ReportCard/report_card.tscn` is StudentCard before its Phase 1 pass.
Its root is inset by `(70, 254, −77, −352)` and every child carries a negative
offset that cancels the inset back out:

| node | offsets | screen rect at 1080×1920 |
|---|---|---|
| `Backdrop` | −70 / −254 / 1010 / 1666 | (0, 0)–(1080, 1920) |
| `KertasMurid1`…`6` | −70 / −254 / 1010 / 1666 | (0, 0)–(1080, 1920) |
| `NextButtonKiri` | 20 / 1526 / 140 / 1646 | (90, 1780)–(210, 1900) |
| `NextButtonKanan` | 800 / 1526 / 920 / 1646 | (870, 1780)–(990, 1900) |
| `PageLabel` | 370 / 1551 / 570 / 1621 | (440, 1805)–(640, 1875) |
| `PilihMurid` (title) | 90 / −172 / 990 / −44 | (160, 82)–(1060, 210) |
| `BackButton` | 20 / −172 / 280 / −76 | (90, 82)–(350, 178) |

Every one is in position mode, so on a 1080×2400 viewport they all stay where
they are and the screen ends at 1920: **480 px of empty grey below the desk.**
That is the empty space the user reported.

### The change — the StudentCard structure, node for node

1. **Root** loses its inset: offsets `(0, 0, 0, 0)`. Every direct child's
   offsets gain back the `(70, 254)` the root used to supply, so nothing moves
   at the design size.
2. **`Backdrop`** becomes Full Rect and covers: anchors `(0, 0, 1, 1)`, offsets
   `0`, `expand_mode = 1`, `stretch_mode = 6`. This is what removes the empty
   band — `meja_background.png` now fills any height without distorting.
3. **`KertasMurid1`…`6`** become Center-anchored at their 1080×1920 rect:
   anchors `0.5`, offsets `(−540, −960, 540, 960)`. The paper stack then sits
   centred, 240 px down on a 2400 screen, exactly as StudentCard's does.
4. **A `Safe` / `UI` / `BottomBar` group** is added, copying StudentCard's:
   - `Safe` — `MarginContainer` with `Scripts/UI/SafeAreaMargin.gd`, Full Rect,
     `mouse_filter = 2`
   - `UI` — plain `Control`, `layout_mode = 2`, `mouse_filter = 2`
   - `BottomBar` — `Control`, anchors `(0, 1, 1, 1)`, offsets
     `(0, −94, 0, 34)`, `grow_vertical = 0`, `mouse_filter = 2`
5. `NextButtonKiri`, `NextButtonKanan` and `PageLabel` **move into**
   `BottomBar`; the title and `BackButton` move into `UI`. Their new offsets,
   chosen so their screen rects at 1080×1920 are unchanged:

   | node | new parent | new offsets | screen rect (unchanged) |
   |---|---|---|---|
   | `NextButtonKiri` | `BottomBar` | 42 / 2 / 162 / 122 | (90, 1780)–(210, 1900) |
   | `NextButtonKanan` | `BottomBar` | 822 / 2 / 942 / 122 | (870, 1780)–(990, 1900) |
   | `PageLabel` | `BottomBar` | 392 / 27 / 592 / 97 | (440, 1805)–(640, 1875) |
   | `PilihMurid` | `UI` | 112 / 34 / 1012 / 162 | (160, 82)–(1060, 210) |
   | `BackButton` | `UI` | 42 / 34 / 302 / 130 | (90, 82)–(350, 178) |

   `BottomBar` at 1080×1920 is (48, 1778)–(1032, 1906); `UI` is
   (48, 48)–(1032, 1872). Both title and `BackButton` are Top Left in `UI`
   (anchors `0`), so they ride the top edge.

6. **`report_card.gd` switches to unique names.** `$NextButtonKanan`,
   `$NextButtonKiri`, `$BackButton` and `$PageLabel` (`:43-46`) break once the
   nodes move. Each node gets `unique_name_in_owner = true` and the script
   reads `%NextButtonKanan` and so on — the same treatment StudentCard's got.
   None of these appears inside a format string, so
   `test_unique_name_paths_are_not_format_strings` stays green.

### What this deliberately leaves alone

- **The title/`KEMBALI` overlap.** `BackButton` covers x 90–350 and the title
  is a left-aligned `DisplayLabel` whose text starts at x 160, so "Rapor Murid"
  runs under the button. This is a real bug, but it is already filed as its own
  out-of-scope item in the Phase 1 spec, and every way of fixing it (centring
  the title, moving the button to the bottom bar, narrowing either) is a
  judgement about the screen's composition rather than a consequence of this
  restructure. Both nodes keep their current screen rects here.
- **The arrow styling.** Rapor's arrows are 120×120 `CardArrowButton`s with an
  `icon`; StudentCard's are 160×128 `StudentCardSecondaryButtonL`s with an
  `Arrow` child. Making them match is a restyle, not a fill.

---

## 3. StudentCard: the Belajar button lands off-screen

### Today

Two defects compound.

**The authored rect is off-screen.** Phase 1 removed StudentCard's root inset
and pushed every child's offsets by `(70, 254)` to compensate.
`BelajarButton` was at y 1740 and became y 1994 — but unlike the papers and
`StampApprove`, it stayed in position mode with anchors `(0, 0, 0, 0)`. At
1080×1920 its rest position is now 74 px below the bottom of the screen. It is
the only thing that belongs to the paper and does not ride with it.

**`_transition_page` slides it to that rest position.**
`Scripts/StudentCard/student_card.gd:625` captures
`belajar_orig_pos = belajar_button.position` *before* the page changes. When
the button is still hidden, that is the authored `(398, 1994)`. Later in the
same function:

- `:657` `_reset_all_approve_positions()` clears `approve_shifted`;
- `:672` `_update_nav_buttons(new_index)` sets `visible = limit_reached` and
  calls `_shift_approve_for_belajar`, which parks the button off-screen right
  and tweens it to `belajar_target` — the correct spot beside Aprove/Batal;
- `:691-695` then sees `belajar_button.visible` is now true, overwrites the
  position with the stale `belajar_orig_pos − throw_distance` and tweens it
  **back to `belajar_orig_pos`**, undoing the shift.

So the swipe that first reveals BELAJAR flies it to (398, 1994) instead of next
to the Aprove/Batal row: below the screen at 1080×1920, and 14 px out of line
with the paper's other buttons at 1080×2400.

### The change

1. **`BelajarButton` rides the paper** (rule 4), like `StampApprove`:
   anchors `0.5`, offsets `(−142, 780, 348, 940)` — its 1080×1920 rect
   (398, 1740)–(888, 1900) expressed from the centre. This restores the
   pre-Phase-1 rest position and makes the button follow the paper's 240 px
   drop on a tall screen.

   `Control.position` stays parent-relative whatever the anchors are, so
   `_shift_approve_for_belajar`'s arithmetic is unaffected by this.

2. **Delete the slide-in block at `:691-695`.** `_shift_approve_for_belajar`
   already parks the button off-screen right and tweens it in, on every page
   change (`_reset_all_approve_positions` clears `approve_shifted` first), so
   the block is not needed for the animation and only ever fights it. The
   throw-out at `:639-641` and the reset at `:655` stay: the first carries the
   button off with the old card, the second leaves it in a known state.

---

## Files

| File | Change |
|---|---|
| `Assets/Images/UI/papantulis.png` | new, copied from `~/Downloads` |
| `Scenes/AturJadwal/atur_jadwal.tscn` | `BGHari` retextured and fixed-size; five notes re-offset; `BoardFill` added |
| `Scenes/ReportCard/report_card.tscn` | root un-inset; `Backdrop` fills; papers centred; `Safe`/`UI`/`BottomBar` added; five nodes reparented and marked unique |
| `Scripts/ReportCard/report_card.gd` | four `$Node` lookups become `%Node` |
| `Scenes/StudentCard/student_card.tscn` | `BelajarButton` Center-anchored |
| `Scripts/StudentCard/student_card.gd` | `_transition_page`'s stale Belajar slide-in removed |
| `tests/test_atur_jadwal.gd` | board texture path, fixed rect, note offsets, `BoardFill` order |
| `tests/test_tall_screen_layout.gd` | a Rapor section; `BelajarButton` added to StudentCard's |
| `tests/test_student_card.gd` | the `_transition_page` regression |

## Testing

`tests/test_tall_screen_layout.gd` already has the machinery: `layout_frame.gd`
stands a screen up at a given size and settles it in one frame, and
`_authored_rect` reads a node's placement without a running game. Rapor gets
the same five tests StudentCard has — backdrop fills, papers centred, UI under
the safe area, the screen at 1080×2400, the screen at 1080×1920 — with the
rects tabulated above as the expected values.

AturJadwal cannot be instanced bare (it needs `day_schedules`), so its board is
tested the way `test_atur_jadwal.gd` already tests this screen: against the
`.tscn` read out of the tree, asserting the texture path, `BGHari`'s anchors
and offsets, each note's offsets, and `BoardFill`'s rect and child index.

The `_transition_page` fix is a source-text scan, the established pattern for
behaviour that needs a live tween: assert that the function no longer tweens
`belajar_button` toward a captured `belajar_orig_pos`.

## Grades

Nothing here reads `GameState.current_grade`. All three screens render the same
at Kelas 7, 8 and 9; only the values inside the papers differ, and none of this
touches them.

## State

No state crosses the `approved_students` ↔ `StudentData` bridge in this work.
Rapor reads `GameState.approved_students` through `StudentCardView.populate`
and is read-only; StudentCard's approval flow is untouched — only where its
button is drawn. No new persistence.
