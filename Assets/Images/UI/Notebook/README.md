# Notebook frame textures

Placeholders (2026-09-28, UI depth pass), generated with Pillow. They are
drop-replaceable at the same path; `Scenes/UI/NotebookFrame.tscn` uses them.

| File | Size | Notes |
|---|---|---|
| `spiral_ring.png` | 72x32 | One wire loop; the frame shows up to 8 down the page's left edge. |
| `paper_rule.png` | 16x58 | Tiles in both directions over the page (`TextureRect` stretch TILE). Keep the rule spacing 29 px and the ground transparent. |
| `sticker_stitch.png` | 96x96 | 9-slice with 28 px patch margins on every side; the dashed stitch must stay outside the middle. |

The washi tape reuses `Assets/Images/AturJadwal/washi_tape.svg`, tinted by
the frame's `tape_color`.
