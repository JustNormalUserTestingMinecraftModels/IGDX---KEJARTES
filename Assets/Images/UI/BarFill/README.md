# Progress bar fill tiles

One file per stat. These are the textures every progress bar in the game
draws its coloured half from — the student card, Atur Jadwal, SchoolDay,
Exam Progress, Report Card, the inventory rows and the stat popup.

| File | Stat | Motif |
|---|---|---|
| `fill_akademis.png` | Akademis | open book |
| `fill_senibudaya.png` | Seni Budaya | tenun chevrons |
| `fill_olahraga.png` | Olahraga | batik lereng diagonal |
| `fill_wirausaha.png` | Wirausaha | coin |
| `fill_istirahat.png` | Istirahat | crescent moon |
| `fill_libur.png` | Libur | sun |
| `fill_mood.png` | Mood | heart |
| `fill_energi.png` | Energi | lightning bolt |

The shipped tiles are **generated geometry, not final art** (PowerShell +
`System.Drawing`). They are meant to be replaced. Drop a hand-drawn PNG at
the same path and nothing in code changes — no scene edit, no theme
rebake, no code review.

## Two rules any replacement must follow

Both are checked by `tests/test_bar_contrast.gd`, so breaking either one
fails the build rather than shipping quietly.

**1. Stay light — mean luminance above 0.90.**

The bar's colour is not in this file. The file is near-white, and the
engine *multiplies* the stat's colour through it. A tile at 50% grey
halves the colour, which is how these bars once shipped looking muddy and
measuring below the contrast floor. Draw the motif as a **light grey mark**
(around `#D6D6D6`) on a near-white body, not as dark ink.

**2. Tile on a period that divides 100 × 76.**

The texture is nine-sliced with a 24px margin, so the middle of the bar
repeats a 100 × 76 region as the bar fills. A motif whose repeat does not
divide that region evenly will visibly jump at every repeat. The shipped
tiles use a **20 × 19** period — 5 across, 4 down. Other safe periods:
10 × 19, 25 × 19, 20 × 38.

## Canvas

Keep these exactly as they are, or the frame geometry breaks:

- **256 × 256** canvas, transparent outside the capsule
- the bar is cropped from **region (60, 66), 148 × 124**
- corner radius must stay **inside the 24px margin** (the shipped tiles use
  22). A larger radius pushes the curve into the tiling middle and the bar
  comes out with sawtooth edges.

## Checking your work

Open the game and look at a bar at a low value — most problems show up in
the first 20% of the fill, not at 100%. If the suite fails on
`test_stat_bar_on_dark_accents_clear_the_floor_as_rendered`, the message
names the file and its measured brightness.

## track_ghost.png

Not a fill -- a track. Used by `PreviewTrackGhost` behind the Wirausaha and
Libur rows, which have no target stat and therefore no gauge.

Two rules bind a replacement, and they are different from the fill rules
above:

- **It must stretch, not tile.** The alpha ramps left to right; a tiled ramp
  sawtooths back to transparent at every repeat.
- **The left 22px cap must hold the ramp's starting alpha (0.18)**, or a seam
  shows where the rounded end meets the ramp.

The 0.90 mean-luminance floor does **not** apply. That floor exists because
fill textures multiply against an accent colour; a track multiplies nothing.
`tests/test_ghost_track.gd` asserts this file stays out of the fill roster.
