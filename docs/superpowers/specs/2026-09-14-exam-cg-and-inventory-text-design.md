# Exam CG and inventory text — design

2026-09-14. Approved through `/gamecode`: the Brief, then "yes".

## Goal

1. ExamProgress shows the user's `cg_ujian` art, taken from their Google Drive,
   in place of the `cg_test.jpg` placeholder.
2. The Inventory item sheet and the item-application screen become comfortable
   to read. No text on them uses the 18 or 22 px styles any more.

## ExamProgress art

- `Assets/Images/CG/cg_ujian.png` is 1920x1920 RGBA and fully opaque, 1,626,500
  bytes, downloaded from the user's Drive.
- `ExamProgress.tscn`'s `Backdrop` points at it. `Backdrop` is a TextureRect,
  1296x1920, stretch mode KEEP_ASPECT_COVERED.
- The pan does not change: 216 px over `fill_seconds` (4.0).
- On a square image the cover fit keeps the full height and shows the middle
  1296 of the 1920 columns, so the pan slides the 1080 px window across that
  middle. The outer 312 px on each side never show. This is noted to the user;
  widening the pan is a follow-up, not part of this pass.
- `cg_test.jpg` and its `.import` are deleted, since ExamProgress was their only
  user.

## Text sizes

The canvas is 1080 wide (`canvas_items` stretch, scale 1.0), so 36 px is about
12 sp. That is the floor for comfortable secondary text on a phone.

| Node | Was | Now |
|---|---|---|
| ItemDetailSheet `DescLabel` | `CaptionLabel`, 22 px, grey | `EventBodyLabel`, 36 px, dark ink |
| EfekRow `ExplainLabel` (x5) | `MicroLabel`, 18 px, grey | `EventBodyLabel`, 36 px, dark ink |
| EfekRow `ValueLabel` (x5) | `ResultDeltaLabel`, 22 px, white with a dark rim | `H2Label`, 48 px, display font, dark ink |
| ApplyItemScreen `RecapCount` | `CaptionLabel`, 22 px | `EventBodyLabel`, 36 px |
| ApplyItemScreen `EffectSummary` | `CaptionLabel`, 22 px | `EventBodyLabel`, 36 px |

**Decision 1, as built.** The Brief's default was "52 px bold, like the student
cards". The cards' `DaySummaryStat` is white with a dark rim, made for their
dark stat tracks. On the item sheet's near-white card (`#FFFDF8`) it would
repeat the white-on-white problem the old `ResultDeltaLabel` had. The same bold
display font in dark ink is `H2Label` at 48 px, so the rows use that.

All five styles already exist. Nothing changes in ThemeFactory or the tokens,
and nothing is rebaked. Other screens are untouched. The shared 18 and 22 px
tokens stay as they are: raising them would change about 20 screens and break
`test_design_tokens`' size ladder.

**Layout.** `DescLabel` and `ExplainLabel` wrap (autowrap 3). The item sheet
has no ScrollContainer, so it is checked at full size with the longest
description ("Bundel soal-soal ujian tahun lalu; latihan paling ampuh sebelum
tes.", 68 characters) and all five effect rows showing. Only if the content
then overflows the sheet does its middle (the description and the effects) move
into a ScrollContainer, with the "Pakai ke Siswa" button pinned below it.
ApplyItemScreen's rows already scroll.

**Out of scope:**
- the 34 px floating gain text
- the 30 px need-tier words and the 32 px empty-state hint, which are shared
  components used on other screens
- item art

## Tests

- **`exam_progress`**: a new test that `Backdrop`'s texture is
  `res://Assets/Images/CG/cg_ujian.png` and that `cg_test.jpg` no longer
  exists.
- **`inventory_text_size`**: a new suite whose `suite_name()` returns
  `"inventory_text_size"`. It works like this:
  - Instantiate `inventory.tscn`, `InventorySlot.tscn`,
    `ItemDetailSheet.tscn`, `ApplyItemScreen.tscn` and
    `ApplyStudentRow.tscn` without adding them to the tree, so no `_ready`
    runs.
  - Resolve every Label's and Button's font size through the baked theme: the
    variation, then its base chain, then the default.
  - Assert each is at least 36 px, except for an `ALLOWED` dict of reviewed
    exceptions: `DaySummaryNeedsLabel` at 30 px (the shared DaySummary card's
    need words) and `EmptyStateLabel` at 32 px (shared with ResultCheckup).
  - Assert that no node uses `CaptionLabel`, `MicroLabel` or
    `ResultDeltaLabel`.
- **`light_ground_text`**: update the Inventory block's comments, since the
  sheet's "+N" is now dark `H2Label` ink. Its contrast assertion keeps
  measuring whatever variation the label wears.
- The full suite runs last.

## Branch

`feat/exam-cg-and-inventory-text`, from `origin/Textures` (`cc20bb3`). It is
built in the reused worktree `.claude/worktrees/project-guide-audit`, with its
own editor (ship-pr §3). Scene edits go through that editor, since it is
running during the work.
