# Warm UI System — design

**Date:** 2026-09-08
**Status:** approved, not yet implemented
**Scope:** `DesignTokens`, `ThemeFactory`, the Lobby scene, 5 new icon assets

## Why

A design mentor reviewed the build and raised four problems. Each traces to a
concrete defect in the token layer rather than to taste:

1. **The palette reads cold and techy.** `brand_primary` is `#2e5bff`, and it
   fills PrimaryButton, LobbyNavButton, QuirkBadge, ShopShelfButton,
   FilterChipButton and every focus ring. `cat_akademis` is a second blue at
   `#268fff`. The game portrays an Indonesian school; it looks like a fintech app.
2. **Button silhouettes are inconsistent.** `ThemeFactory._pill()` sets
   `radius_pill = 999`, which Godot clamps to half the box height. The 34 themed
   buttons in the project are authored at 15 distinct heights (63, 80, 90, 94,
   96, 116, 120, 135, 140, 144, 148, 160, 178, 267, 290), so one nominal button
   style renders at **15 different corner radii, from 31px to 145px**.
3. **Progress bars are dark and muddy.** The DaySummary and Penjadwalan tokens
   were eyedropped from grey mockup PNGs. Measured, two bars fail outright:
   energy fill `#6d60c0` on track `#585858` is **1.36:1**, and Olahraga
   `#ff263c` on `#383838` is **2.55:1**. A 1.36:1 bar cannot be read at all.
4. **The lobby's bottom buttons look unfinished and clip; the HUD covers faces.**

### Two defects found during analysis, not reported by the mentor

- **Every `custom_minimum_size (0, 96)` button is lying.** `_pill()` pads 28px
  top and bottom (`space_md`); add 12px of border and a ~44px line box for
  `font_title` and the minimum is ~104px. Godot expands past the authored 96.
- **`cat_libur` `#ffd333` and `currency_gold` `#ffc93c` are the same yellow.** A
  Libur bar and a coin count are not distinguishable by hue today.

### The lobby collisions, measured

Mapping the portrait art's opaque bounds (`Thea.png`: art begins 10.8% down the
canvas, spans 13.1%–86.7% across) through each slot's rect:

| Element | Rect | Covers | Head centre |
|---|---|---|---|
| `DailyLogin` | 87–243, 391–547 | Slot3 (front-left) | x≈225, y≈389 |
| `DisplayUang` | 831–1120, 358–521 | Slot4 (front-right) | x≈845, y≈389 |

Both are centred on a front-row student's head. `DisplayUang` additionally
extends to x=1120 on a 1080-wide screen — 40px off-screen. `ReportStudent` ends
at x=1059 with a 6px border and a 14px shadow, which is why it clips on the rim.

`Student` and `Jadwal` are mutually exclusive — `loby.gd:170-198` hides one when
showing the other. They occupy the same slot. The lobby is **one primary CTA
plus three nav tiles**, not five buttons.

## Decisions

All confirmed with the project owner before writing this document.

| Decision | Choice |
|---|---|
| Palette scope | Warm chrome; category accents kept saturated and re-tuned |
| Button corner | **Fixed 20px**, height-independent |
| Size scale | S=96 / M=128 / L=160, font stepping 36/48/64 |
| Shadow | `shadow_size` 14 → 12, offset unchanged at (0, 6) |
| Nav tile treatment | **C** — icon stacked over label |
| Everything else | **A** — larger text, no icon |
| Primary CTA treatment | **B** — icon left of label (it is 984px wide) |
| Bar track | **Warm dark `#4A3728`**, all six accents clear 3.5:1 |
| On-dark accents | **Six explicit `@export` tokens**, not derived in code |
| Lobby HUD | **Bottom strip**, above the CTA |

### Why the bar track is dark, not light

Direction A's swatch implied a light cream track. Measuring it kills the idea:
Seni `#6BD425` on `#E3D3BE` is **1.29:1** — the same failure as today, inverted.
A light track and vibrant accents are mutually exclusive. A warm dark ground is
the only one all six accents clear.

That is also why each category needs a **pair** of values. One colour cannot
serve both a light `StatBar` track and a dark DaySummary track.

## Token changes

### Changed values

```
brand_primary          2e5bff -> 7A4A2B    brand_primary_light 6e8cff -> 9C6440
brand_primary_dark     1b3acc -> 56321B

surface_page           eef3ff -> FBF1E3    surface_card        ffffff -> FFFDF8
surface_sunken         dde5f7 -> EFE0CB    surface_overlay     141a2e -> 2E2118

outline_card           ffffff -> FFF6E8
shadow_color           rgba(.08,.11,.22,.28) -> rgba(.23,.14,.06,.30)
shadow_size            14 -> 12

text_primary           1e2436 -> 3B2412    text_secondary      6b7490 -> 7A5C40
text_on_brand          ffffff -> FFF6E8    text_disabled       a8b0c4 -> BFA88C
text_outline_color     ffffff -> FFF6E8

cat_akademis           268fff -> 2E86D8    cat_olahraga        ff263c -> E03A18
cat_senibudaya         a3ff1a -> 4FA317    cat_istirahat       6640ff -> 7C3AED
cat_libur              ffd333 -> D98E0B    cat_wirausaha       00e6b8 -> 0E9E7A

state_success          2fb86b -> 35A05A    state_warning       ffb020 -> F5A623
state_danger           c42b6e -> C0392B
currency_gold          ffc93c  (UNCHANGED - cat_libur moved away from it instead)

day_avatar_fill        5e4ebc -> 7A4A2B    day_avatar_border   3d3d3d -> FFF6E8
day_bar_track          585858 -> 4A3728    day_bar_border      2b2b2b -> 2E2118
day_stat_track         383838 -> 3F2E21    day_glyph_outline   3d1e48 -> 2E2118
day_energy_fill        6d60c0 -> A78BFA    day_mood_fill       c8af57 -> F5A623

preview_row_fill       676767 -> 6B4B33    preview_row_border  3d2048 -> 2E2118
preview_pill_fill      363636 -> 4A3728
```

`currency_gold` stays `#ffc93c` deliberately. It is the colour of
`trait_button.png`, the asset whose warmth prompted this whole pass, and moving
`cat_libur` to `#D98E0B` resolves the collision without giving up the reference.

### New exports (14)

```
cat_akademis_on_dark    3BA7F5      radius_button   20
cat_olahraga_on_dark    FF5A36      btn_pad_v       14
cat_senibudaya_on_dark  6BD425      btn_h_s         96
cat_istirahat_on_dark   A78BFA      btn_h_m         128
cat_libur_on_dark       F5A623      btn_h_l         160
cat_wirausaha_on_dark   16C79A      btn_icon_s      48
                                    btn_icon_m      64
                                    btn_icon_l      80
```

Measured contrast of each on-dark accent against `day_bar_track` `#4A3728`:

| Accent | Ratio | | Accent | Ratio |
|---|---|---|---|---|
| akademis | 4.24 | | istirahat | 4.10 |
| olahraga | 3.60 | | libur | 5.48 |
| senibudaya | 5.94 | | wirausaha | 5.15 |

All clear 3.5:1. The floor is set at **3.0:1** so there is headroom for tuning.

`category_color()` gains a sibling `category_color_on_dark()` with the same
`match` shape and the same `text_secondary` fallback.

> **New exports on a `Resource` are invisible to a running editor.** This pass
> therefore *requires* an editor restart plus a manual `Scripts/Design/BakeTheme.gd`
> run (File > Run) before anything renders. This is a scheduled step, not a
> footnote — see Implementation order.

## `ThemeFactory` changes

### `_pill()` → `_button_box()`

- `set_corner_radius_all(tokens.radius_button)` instead of `radius_pill`
- `content_margin_top/bottom = tokens.btn_pad_v` instead of `space_md`
- `content_margin_left/right` stays `space_lg`

`radius_pill` is **not** removed. It survives for non-button chips —
`TraitPill`, `QuirkBadge`, `PersonaBadge`, the result badges and the score HUD —
which should stay fully round precisely so they read as labels rather than as
something tappable. The rule becomes: **every `Button` gets `radius_button`;
chips keep `radius_pill`.**

`_pill()`'s doc comment currently describes an "Umamusume sheen" from a
gradient. That framing goes with the rename; the warm system's affordance is the
bevel and shadow, not a sheen.

### Size-step variations

Godot type variations do not compose, so a size step cannot be layered onto a
role — `PrimaryButton` + "make it L" is not expressible. Each role that has a
non-S call site therefore needs an explicit sibling. The base role variations
keep `font_title` and are the S step, which is both the most common authored
height and `touch_target_min`.

Sorting the 34 measured call sites into the three steps gives:

| Step | Font | Existing heights that land here | Siblings needed |
|---|---|---|---|
| S (96) | `font_title` 36 | 63, 80, 90, 94, 96 | none — the base variations |
| M (128) | `font_h2` 48 | 116, 120, 135, 140, 144, 148 | `PrimaryButtonM`, `SecondaryButtonM`, `DangerButtonM` |
| L (160) | `font_h1` 64 | 160, 178 | `PrimaryButtonL`, `SecondaryButtonL`, `DangerButtonL`, `SuccessButtonL` |

`SuccessButton` has no M call site and `Success`/`Filter`/`ShopShelf` have no
others, so no siblings are generated for combinations nothing uses. Adding one
later is three lines in `_build_buttons()` plus a roster entry.

Two new lobby-specific variations:

- `LobbyNavTile` — L height, `radius_button`, vertical layout, icon 64 over
  `font_title`, `btn_pad_v` padding. Replaces `LobbyNavButton` on the three tiles.
- `LobbyCtaButton` — L height, `radius_button`, horizontal, icon 80 left of
  `font_h1`. Replaces `LobbyNavButton` on `Student`/`Jadwal`.

`LobbyNavButton` itself is retired once both replacements land.

All nine new variations must be added to `DISPLAY_ROSTER` in
`tests/test_theme_factory.gd` — that roster is pinned in both directions, so
omitting one fails the suite either way.

### Bar styleboxes

`_build_progress()`'s per-category fills continue to read `cat_*` (light
`StatBar` track). The five `bar_specs` in the DaySummary block switch to
`cat_*_on_dark`. `StatBar`'s track picks up the re-tinted `surface_sunken` and
`outline_card` automatically.

## Lobby layout

All values in the 1080×1920 design space. Bottom-up, with a 48px screen margin.

| Element | Rect | Notes |
|---|---|---|
| `JUDUL` "KELAS 7" | 381–704, 40–140 | Moved into the empty 360px channel between the back-row students |
| HUD strip | y 1392–1488 | S height, clear of the front row (ends y≈790) |
| ├ `DailyLogin` | 48–144 | 96×96 icon button |
| └ `DisplayUang` | 700–1032 | 332×96 pill, coin icon + amount |
| CTA (`Student`/`Jadwal`) | 48–1032, 1520–1680 | L height, treatment B |
| Nav tiles | y 1712–1872 | L height, treatment C, one baseline |
| ├ Koperasi | 48–354 | 306 wide |
| ├ Inventory | 386–692 | 306 wide |
| └ Rapor | 724–1030 | 306 wide, **50px clear of the rim** |

Three equal 306px columns with 32px gaps. `ReportStudent`'s label shortens to
"Rapor" — "REPORT STUDENT" does not fit a 306px tile at `font_title`, and Rapor
is the correct Indonesian term besides.

Nothing in the portrait or desk art moves. The HUD relocates into space that is
already empty, which is why this option was chosen over a scrimmed top bar.

## New assets

Five transparent PNGs, authored at 256×256 and downscaled by the node. These are
**real art**, not placeholders — they go in `Assets/Images/UI/Nav/`, not
`Assets/Images/UI/Placeholders/`.

- `icon_nav_koperasi.png` — shopfront
- `icon_nav_inventory.png` — satchel
- `icon_nav_rapor.png` — report sheet
- `icon_cta_jadwal.png` — calendar
- `icon_cta_student.png` — student silhouette

Drawn in `text_on_brand` `#FFF6E8` as flat silhouettes, matching the existing
SVG icon set's weight. Per project convention, **no emoji** — these exist
precisely so the tiles do not use glyphs.

## Test impact

Token references in tests are almost all by name and survive value changes.
**Eleven assertions hardcode hex literals** and must be updated:

- `tests/test_design_tokens.gd:14-16` — `brand_primary`, `surface_card`, `text_primary`
- `tests/test_day_summary.gd:105-112` — all eight `day_*` colours

### New tests

1. **Contrast guard.** Assert every `cat_*_on_dark` clears **3.0:1** against
   `day_bar_track`, computing WCAG relative luminance directly. This is the test
   that would have caught the 1.36:1 energy bar, and it makes the dark-track
   decision self-enforcing.
2. **One radius for every button.** Walk every type in the built theme whose
   variation base is `Button`, and assert its `normal` stylebox — where it is a
   `StyleBoxFlat` — uses `radius_button`. Excludes the chips by construction,
   since they are not `Button`-based variations, and excludes `MainMenuButton`,
   which is a `StyleBoxTexture`.
3. **Lobby geometry.** Assert the three nav tiles share one height and one
   baseline, and that no lobby control's rect exceeds x=1080 or comes within
   `shadow_size` of the rim. This is the regression guard for both the clipping
   and the off-screen `DisplayUang`.

`tests/test_activity_row.gd` carries a regression note about the schedule pill's
radius moving to `radius_md`. That pill is not a `Button` and is unaffected —
but the note should be re-read before touching `_build_penjadwalan()`.

## Implementation order

The editor-restart constraint dictates the sequence.

1. Update `DesignTokens.gd` — changed values **and** all 14 new exports, each
   with its `##` doc line (`tests/test_script_documentation.gd` enforces this).
2. Update the 11 hardcoded hex assertions.
3. **Restart the editor.** The new exports are invisible until this happens.
4. Rebake: `Scripts/Design/BakeTheme.gd` via File > Run, or the transient
   `McpTestSuite` trick if the editor is being driven headlessly.
5. `ThemeFactory` — `_button_box()`, the nine new variations, `DISPLAY_ROSTER`,
   the DaySummary `bar_specs` switch to on-dark.
6. Rebake again, run the suite.
7. Generate the five icons.
8. Lobby scene work through the editor — `scene_open` → `node_*` → `scene_save`.
   Per the project guide, **scene work last and separately from script work**:
   `scene_save` flushes stale script buffers over anything patched from outside.
9. Re-audit button heights project-wide against the S/M/L scale. 15 authored
   heights collapse to 3; the 63px `ShopShelfButton` and the 178px `Batal` are
   the two furthest from a step and need judgement, not a formula.

Steps 1–6 are one unit — the game will not render correctly between step 1 and
step 6, so they should not be split across sessions.

## Out of scope

- **Minigames** and the **debug overlay** are excluded from the design system by
  standing project policy. They inherit the Theme and will shift colour with it,
  but no layout work is done there.
- **`Balance.gd`** is owned by a collaborator and is not touched.
- The **`radius_pill` chips** keep their current geometry. Only their colours move.
- **`MainMenuButton`** keeps `trait_button.png`. Its silhouette does not match
  the new 20px radius, but replacing it means re-authoring the art, which is a
  separate pass. Flagged in Outstanding debt rather than fixed here.
- The **viewport-editability ratchet** is not advanced. This pass should not
  raise `BASELINE`; if lobby work would add a runtime-constructed visual, it
  goes in the `.tscn` instead.

## Known risk

Nine screens read `brand_primary` for something other than a button — washes,
tints, focus rings, the event-row highlight noted at
`tests/test_result_checkup.gd:847`. A brown at `#7A4A2B` is much darker than
`#2e5bff`, so any place that composites it at low alpha over a light surface
will read muddier rather than merely warmer. These need a visual pass after
step 6, not just a green suite.
