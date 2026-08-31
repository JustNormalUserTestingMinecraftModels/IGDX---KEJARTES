# Main Menu — Mockup Match Spec

**Date:** 2026-08-31
**Screen:** `Scenes/MainMenu/main_menu.tscn`
**Reference:** `docs/superpowers/mockups/main-menu.png` (1080x1920, copied from
`C:\Users\ASUS\Downloads\mockup_mainmenu.png`)

## Goal

Rebuild the main menu to the supplied mockup's measured geometry, using the
project's existing art, and make it the game's boot scene.

## Aspect gate — PASSED

| | canvas | content box | aspect |
|---|---|---|---|
| Mockup | 1080x1920 | x 0..1079, y 0..1919 | 0.5625 |
| Target viewport | 1080x1920 | full | 0.5625 |

Identical. **Mockup pixel coordinates map 1:1 onto Godot design-space
coordinates with no rescaling.** Every number below is therefore usable
verbatim.

## Assets

| Asset | Path | Source size | Use |
|---|---|---|---|
| Background | `res://Assets/Images/UI/titlescreen_background.png` | 1080x1920 | Full-bleed, 1:1. Replaces `BG.jpg`. |
| Logo | `res://Assets/Images/UI/logo.png` | 1080x1080 (alpha bbox 156..1047 x 2..764) | Drawn 1:1 at offset (0, 68). |
| Button | `res://Assets/Images/StudentCard/trait_button.png` | 640x640 | Reused via the existing `TraitPill` 9-slice recipe, resized. |

No new art is created.

## Measurement table

Probed with `pixel-accurate-ui-from-mockups/probe.ps1`. Fills are centroid
samples; borders were confirmed by zoomed crop, not by scanline alone.

| # | Surface | Parent | Rect (mockup px) | Fill (centroid) | Border | Radius |
|---|---|---|---|---|---|---|
| 1 | Background | root | 0,0 1080x1920 | photographic | none | 0 |
| 2 | Logo art (alpha bbox) | root | 156,70 892x763 | photographic | none | 0 |
| 3 | MULAI button | ButtonColumn | 206,1116 670x126 | #6F6F6F -> #525151 | #3D2048, 3 px | ~24 |
| 4 | PENGATURAN button | ButtonColumn | 206,1311 670x126 | #6F6F6F -> #525151 | #3D2048, 3 px | ~24 |
| 5 | KELUAR button | ButtonColumn | 206,1501 670x126 | #6F6F6F -> #525151 | #3D2048, 3 px | ~24 |

Text, listed separately from surfaces:

| Glyph run | Belongs to | Cap height | Colour | Outline |
|---|---|---|---|---|
| (PLAY) | #3 | 70 px (y 1147..1216) | #FFFFFF | none |
| (SETTING) | #4 | 70 px | #FFFFFF | none |
| (QUIT) | #5 | 70 px | #FFFFFF | none |

### How each number was obtained

- **Logo placement.** A per-pixel correlation of `logo.png`'s opaque samples
  against the mockup, swept over scale 0.60–1.10 and offsets +/-300 / +/-400,
  put the global optimum at **scale 1.0, offset (0, 68)**. A 1-px `dy` sweep
  across 60..80 shows a sharp minimum at 68 (mean channel error 28.8, rising
  monotonically to 39.8 at dy=60 and 45.9 at dy=80). A sharp minimum means the
  alignment is real. The logo is **not** resized.
- **Button rects.** Vertical scanlines at x=260 and x=300, horizontal
  scanlines at y=1180 / 1370 / 1560, then single-pixel samples to find the
  exact border row/column. Left border begins at x=206 (x=205 is background);
  right border ends at x=875 (x=876 is background) — width **670**. Button 1
  spans y=1116..1241 — height **126**.
- **The fill is a real gradient, not two merged surfaces.** It ramps
  #6F6F6F -> #525151 left-to-right *and* #707070 -> #626262 top-to-bottom, with
  no border-coloured seam anywhere between. Zoomed 6x crops of the top-left
  and bottom-right corners confirm one rounded surface carrying a bright white
  gloss highlight inside the top edge — the exact signature of
  `trait_button.png`. This is the mockup author recolouring that asset, not a
  nested second surface.
- **Border colour #3D2048 is already a token**: `preview_row_border` in
  `design_tokens.tres`, the same design language as the Penjadwalan rows.
- **Cap height.** Vertical scans through two glyph stems (x=425 gives
  y 1147..1216; x=490 gives y 1147..1217) both measure 70 px.

### Spacing normalisation — a deliberate deviation

The mockup's own button pitch is **not uniform**: tops at 1116, 1311, 1501
(deltas 195 and 190), gaps of 69 px and 64 px. Heights are consistent at 126.
This is hand-placement drift in the mockup, not an intent a `VBoxContainer`
could express anyway.

Normalised to a uniform **separation of 66 px**: tops land at 1116, 1308, 1500
(within 3 px of measured), and the column's bottom edge lands at
1116 + 3*126 + 2*66 = **1626**, which matches the measured bottom of button 3
exactly. Column rect: **x=206, y=1116, 670x510**.

## Decisions taken (2026-08-31, confirmed with the user)

1. **Button copy stays Indonesian** — `MULAI` / `PENGATURAN` / `KELUAR`. The
   mockup's PLAY / SETTING / QUIT are English placeholders; CLAUDE.md's rule
   wins and `test_button_labels_are_indonesian` stays green unchanged.
2. **Button art is `trait_button.png`, reused as-is, in gold.** The mockup's
   grey is a recolour of that same asset; `ThemeFactory` already documents that
   `modulate` multiplies and so cannot neutralise gold. Geometry, border,
   radius and gloss match the mockup; the fill hue stays gold, matching
   StudentCard.
3. **Background ships ungraded.** The mockup's background is
   `titlescreen_background.png` at exact 1:1 geometry with a Photoshop grade on
   top (per-channel linear fit `1.12*R-70`, `1.40*G-127`, `1.49*B-146`, mean
   residual 7–16). That grade is not reproduced; the in-game screen reads
   brighter than the mockup, by decision.
4. **Subtitle deleted, version label kept.** `SubtitleLabel` is removed
   entirely. `VersionLabel` stays as a QA affordance, pinned bottom-centre.
5. **The main menu becomes the boot scene** — `run/main_scene` moves from
   `Splashscreen.tscn` to `main_menu.tscn`.

## The typography constraint — read before implementing

**"PENGATURAN" cannot be set at the mockup's cap height.** This is arithmetic,
not preference:

- Milker's cap height is **0.70 * font_size** (measured by rendering `M` at
  200 px: ink box 140 px).
- The mockup's 70 px cap height therefore implies `font_size = 100`.
- At `font_size = 100`, Milker sets `PENGATURAN` **755 px** wide (typographic
  measure). The button's inner box is 670 - 2*3 px border - 2*20 px content
  margin = **624 px**. It overflows by 131 px.

Two contributing facts, both measured:

- The mockup's typeface is **not Milker**. At the mockup's 70 px cap height its
  "PLAY" spans x 419..640, about 221 px; Milker sets `PLAY` at ~336 px for the
  same cap height. The mockup uses a condensed face roughly 65% of Milker's
  width. The project has no such font and none is being added.
- "PENGATURAN" is 10 characters against "SETTING"'s 7.

**Resolution:** uniform `font_size = 80` on the button variation
(`PENGATURAN` = 604 px, fitting the 624 px inner box with 20 px to spare; cap
height 56 px). All three labels share one size. The rendered text is smaller
relative to the button than the mockup's, and that is the unavoidable cost of
Indonesian copy in Milker at this button width.

Renaming the action to something shorter was rejected: `PENGATURAN` is used in
`Scenes/UI/Settings.tscn`, `Scenes/Minigames/UI/PauseMenu.tscn` and
`Scripts/Pengaturan.gd`, and the menu must not diverge from the screen it
opens.

## Layout model

Two layers, both anchored to the full 1080x1920 rect:

- `Background` — `TextureRect`, full-rect, behind everything.
- Content — logo and button column, positioned by **measured anchors and
  offsets**, not by spacer stretch ratios.

The current scene positions everything with `TitleSpacer` / `MidSpacer` /
`BottomSpacer` `size_flags_stretch_ratio` values chosen by feel. That is
precisely why it cannot match a comp, and it is what this change removes.

Two existing tests constrain the structure and must keep passing:

- `test_content_is_wrapped_in_a_safe_area` — a `SafeAreaMargin` must wrap the
  content. It is retained, but its 48 px `screen_margin` must not displace
  measured geometry; see the plan's Task 3.
- `test_layout_uses_containers_not_absolute_offsets` — the three buttons'
  direct parent must be a `BoxContainer`. The column stays a `VBoxContainer`;
  only its position and size come from the mockup.

## Consequence of making this the boot scene

Splashscreen and Loading stop being reached at boot. Two knock-on facts:

- Splashscreen currently starts the `titlescreen` BGM at boot, and
  `tests/test_audio_coverage.gd:344` asserts that
  `Scripts/Splashscreen/splashscreen.gd` contains `play_bgm(&"titlescreen")`.
  `main_menu.gd` **already** calls the same thing in its runtime path, so boot
  audio is preserved with no code change, and that source-text assertion scans
  an untouched file, so it stays green.
- Neither scene is deleted; `tests/test_boot_screens.gd` keeps loading both by
  explicit path. **No test asserts the value of `run/main_scene`** (verified by
  grep), so nothing breaks. The reachability change is intentional and is
  recorded in CLAUDE.md.

## Out of scope

- Any change to Splashscreen, Loading, CutScene, or Settings.
- Reproducing the mockup's colour grade.
- Adding a condensed display font.
- Persistence of any kind.
