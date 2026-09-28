# SkinSelect: two splashes on screen, and a focus that follows the finger

Date: 2026-09-23. Supersedes the carousel half of
`2026-09-22-skin-select-screen-design.md`; everything that spec says about
pending choices, TERAPKAN committing them, and SkinSelect staying a Lobby
overlay still holds.

Reference: `skinselection_mockup.png` (1080x1920, Downloads). Every number
below was fitted numerically against it, not read by eye.

## Problem

The mockup shows the centred skin crisp and bright, with the next skin
peeking in on the right, smaller, darker and blurred. The shipped screen
shows one splash, for three reasons:

1. **The neighbour is off screen.** Cards are 752 wide with a 60px
   separation, and the figure fills only the middle of its 1080-wide canvas,
   so the neighbour's figure starts near x=1185.
2. **The "blur" hides the art.** `skin_option_blur_material.tres` uses
   `blur.gdshader`, which samples `SCREEN_TEXTURE`. On a card, that draws a
   blurred, opaque rectangle of whatever is behind the card, never the card's
   own splash.
3. **Focus snaps.** `SkinCard.set_selected` swaps the material and tint in
   one step, on selection, not while the card moves.

## Decisions (from the user, 2026-09-23)

| Question | Answer |
|---|---|
| Background | Keep the blurred **live Lobby** (`shop_hub_blur_material.tres`), not the mockup's blurred Koperasi room |
| Dots, skin name, worn chip (absent from mockup) | **Keep all three**, repositioned |
| Button label | **TERAPKAN** (Indonesian-UI rule), mockup's shape and position |
| Tile gaps (mockup's are hand-placed: 29/18/21/18/28) | **Even**, same tile size and same span |

## Measured mockup geometry (1080x1920 design space)

| Element | Value |
|---|---|
| Centre splash | 1080x1920 art at scale **0.818**, top-left **(85, 153)** (fit error 0.75/255) |
| Neighbour splash | scale **0.658**, top-left **(676, 370)**, brightness **x0.71**, Gaussian blur **sigma 4px** (screen px) |
| Distance between splash centres | **504.6px** (527 -> 1031) |
| Divider | black, y **1328-1335** (8px) |
| Tray | fill `#FFFDF8` from y 1336 down |
| Student tiles | 6 x **151x156**, 8px black rounded outline, y **1430-1585**, span x **35-1049** |
| Back arrow | **(40,1677)-(237,1852)** |
| Button | outline **(501,1709)-(1007,1849)**, fill `#D21919`, text `#F2F2F2`, Boohong |
| Title | Boohong, fill `#F2F2F2`, outline `#201934` (~13px stroke), cap height 61px (font ~74), outer box (348,95)-(718,182). The shipped 96px dark-brown `DisplayLabel` is ~30% too big and has no outline |
| Button text | Boohong cap height 60px (font 73) |
| Ink | tiles, divider and button rim are pure black `#000000`, 8px; outer corner radius ~21 (= `radius_button` 20) |

## Design

### 1. One continuous scroll value drives every card

`SkinSelect` holds `_scroll: float` in card units: 0.0 centres card 0, 1.0
centres card 1. Each frame the carousel is dirty, every card `i` is posed from
`t = i - _scroll` by a pure static function:

```
SkinSelect.card_pose(t) -> {position: Vector2, scale: float, focus: float}

 |t| = 0   centre     scale 0.818  top-left (85,153)   focus 1.0
 |t| = 1   neighbour  scale 0.658  top-left (676,370)  focus 0.0
 t < 0     the left neighbour mirrors the right one around the centre
           card's middle (x ~ 526.7)
 0<|t|<1   linear blend of position, scale and focus
 |t| > 1   continues past the neighbour slot at the same pitch, focus 0
```

- **Drag:** `_scroll = drag_start_scroll - (finger_dx / pitch_px)` with
  `pitch_px = 504.6`, clamped to `[-0.35, count - 0.65]` so an end card
  rubber-bands a little instead of sliding away.
- **Release:** `SkinCard.settle_index` picks the target exactly as today
  (flick >= 600 px/s, or travel >= half a pitch); `_scroll` tweens to it over
  `slide_time` (0.28s, cubic ease-out). Because the pose is recomputed from
  `_scroll` every frame, dimming and blur ease with it; nothing snaps.
- **Draw order:** the card with the smaller `|t|` is drawn on top.
- `select_student` sets `_scroll` without tweening (the art underneath has
  just been replaced), as today.

All pose numbers are `@export`s on `SkinSelect`, each with a `##` line:
`center_origin`, `center_scale`, `side_origin`, `side_scale`,
`side_brightness` (0.71), `side_blur_px` (4.0), `overscroll` (0.35).
`pitch_px()` is derived from the two slots (centre-to-centre distance), not a
knob of its own, so moving a slot cannot desync the drag.

### 2. The blur is on the card's own art

- New `Scripts/Shaders/skin_card_focus.gdshader` (`canvas_item`). It blurs
  **`TEXTURE`**, not the screen, with a fixed-tap Gaussian whose radius is
  `(1 - focus) * blur_px`, converted to texels with `TEXTURE_PIXEL_SIZE` and
  the card's scale, then multiplies rgb by `mix(brightness, 1.0, focus)`.
  Alpha is blurred too, so the silhouette softens like the mockup's.
- `SkinCard.tscn`'s `Art` gets a `ShaderMaterial` sub-resource with
  `resource_local_to_scene = true`, so each card owns its uniforms. It is
  authored in the scene, not built at runtime.
- `SkinCard` replaces `set_selected(bool)` with `set_pose(position, scale,
  focus)`. `unselected_modulate` and `BLUR_MATERIAL` go. The card's size
  becomes the full 1080x1920 canvas, scaled by the pose.
- `skin_option_blur_material.tres` is deleted if nothing else uses it.
- `Track` becomes a plain `Control` (mouse_filter ignore), because the script
  positions its children. The `separation` override goes with the
  `HBoxContainer`.

### 3. Tray, matching the mockup

- `Tray`: new `SkinTray` variation, fill `#FFFDF8`, 8px black top border only;
  top edge at y=1328 (anchored bottom, `offset_top = -592`). `Carousel`'s
  bottom follows (`offset_bottom = -592`). The blurred live Lobby stays
  behind the splash band.
- `Rail`: six tiles at 151x156, from x=35 to x=1049; `separation` is set so
  the gaps are even (~22.6px, rounded to whole pixels, centred). The
  `SkinStudentTile` variation is restyled to a transparent fill, 8px black
  border and rounded corners; the portrait stays inside.
- `BackButton` at (40,1677)-(237,1852), the existing `return_button.png`.
- `Terapkan` at (501,1709)-(1007,1849): a new `SkinApplyButton` variation
  (fill `#D21919`, 8px black border, Boohong, text `#F2F2F2`) unless an
  existing red variation already renders those exact values.
- Kept extras, placed where the mockup leaves room:
  - **Dots:** above the divider, y ~1276-1300, centred.
  - **Skin name:** between the tiles and the buttons, y ~1598-1650.
  - **Worn chip:** under the title, y ~200-248, centred.
- `Title` gets a new `SkinTitleLabel` variation (the mockup's white,
  navy-outlined 74px Boohong) in place of `DisplayLabel`.
- The mockup's ink, red, text colour, 8px rim and font sizes are single-screen
  values, so they are named consts in `ThemeFactory.gd` beside
  `_build_skin_select` (the file's existing pattern, e.g.
  `EVENT_DIALOGUE_RADIUS`), not new `DesignTokens` exports. The tray fill is
  the existing `surface_card` token (`#FFFDF8`). Rebaked; no
  `theme_override_*` (layout constants excepted).
- The tiles (156 tall) and the button (140 tall) are off the S/M/L button
  scale. The user asked for a pixel copy, so each gets a reasoned entry in
  `tests/test_button_geometry.gd`'s `HEIGHT_ALLOWED`.

### 4. Tall phones

The splash band keeps its top edge; the tray stays pinned to the bottom. On
1080x2400 the band is 480px taller, so more of the legs show. Poses are in
design-space pixels measured from the carousel's top-left, so they need no
aspect correction. `test_tall_screen_layout` must keep passing.

## Testing

- `test_skin_select.gd`:
  - `card_pose(0)` equals (85,153), 0.818, 1.0. `card_pose(1)` equals
    (676,370), 0.658, 0.0. `card_pose(-1)` mirrors around x ~ 526.7.
    `card_pose(0.5)` is the midpoint of all three.
  - A settled carousel poses the centred card at focus 1 and its neighbour at
    focus 0; the neighbour's rect intersects the 1080-wide screen (the
    regression this spec exists for).
  - The dots-follow-selection and worn-chip tests keep passing.
- `test_skin_card.gd`: `settle_index` cases unchanged; a source scan shows the
  card's material uses `skin_card_focus.gdshader`, not `blur.gdshader`; the
  shader samples `TEXTURE` and not `hint_screen_texture`.
- Theme: the new variations join `ThemeFactory`, with a `DISPLAY_ROSTER`
  entry for `SkinApplyButton` (Boohong).
- Runtime-visual ratchet: no new `BASELINE`/`ALLOWED` entries; the card
  instancing stays the existing allowed per-call-dynamic exception.
- Visual check: one screenshot in the running game, judged at full size
  against the mockup, with the tree frozen mid-drag (t = 0.5) and settled.

## Out of scope

- The mockup's Koperasi backdrop (the user chose the live Lobby).
- Skin names, unlocking, the CosmeticShop.
- `Balance.gd`.

## Debt

Delete the DEBT.md sentence "The carousel's neighbour card peeks only 104px
..." once this lands.
