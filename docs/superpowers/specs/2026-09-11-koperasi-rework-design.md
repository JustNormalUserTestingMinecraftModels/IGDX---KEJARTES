# Koperasi rework — design

Date: 2026-09-11
Status: approved, pending implementation plan

## Problem

Mentor review (part 4) on the Koperasi shop: the scene reads as bland and
dead. Specifically:

- Shelf items have no life — no hover/press feedback, no shadow, no glow.
- The cart button is a black basket silhouette with no character.
- The cart popup is a small hard-bordered box, crowded into one region of
  the screen, and painful to look at.
- Price tags are flat green rectangles carrying a bare number.
- The scene's chrome does not match the visual language of the other
  screens, even though the background art itself is good.

The background stays. This pass reworks the surfaces around it.

## What is explicitly NOT changing

The pick-item → arc-into-basket mechanic is approved as-is and must be
preserved:

- `rakbarang_1.gd:137` `_spawn_falling_item` — the split flight
  (`tween_x` quad in-out over 0.45s; `tween_y` a 0.14s rise then a 0.31s
  fall; a parallel rotation tumble).
- `rakbarang_1.gd:177` `_on_item_landed` — `AnimUtils.basket_bounce`
  plus `create_floating_text`.
- `rakbarang_1.gd:230` `_on_item_icon_input` — hold-to-remove with
  `shrink_and_fade`.
- `Cart` and its `×N` quantity model.
- Shop flow and navigation: koperasi still returns to ShopHub.

Implementation must re-point these at new node paths, not rewrite them.

## Design

### 1. Basket tray replaces the popup

`ReturPanel`'s `ScrollContainer` + `GridContainer` become a `BasketTray`
sub-scene (a `PackedScene` row/slot template, per the authoring guide —
no runtime visual construction).

- A themed `Card` surface with a shelf-plank rule across it, so the cart
  reuses the shelf language the scene already has rather than an
  app-style list.
- Items sit bottom-aligned at their own heights, as physical objects, not
  centred in uniform grid cells.
- `×N` badge on each slot corner, fed by `Cart.cart[item]["quantity"]`.
- Existing hold-to-remove affordance retained.
- One row below the tray: `Total` left, a single `PrimaryButton` "Beli"
  right. The Beli button is theme chrome — no generated art.
- The tray peeks at the bottom of the shelf screen rather than opening as
  a centred modal, so the drop target is always on screen.

The flight's landing position is read from the tray's slot rect, so the
preserved arc still terminates where it should.

### 2. Price tag — green coin pill with a wipe-to-Beli state

A new `PriceTag` theme variation. One pill in two states, not two tags.

- **Rest:** bright green pill (`#639922` body, `#3B6D11` border), a pale
  coin disc on the left carrying `Rp`, the price as the label.
- **Pressed:** a dark green (`#2F5A0D`) wipe travels left to right across
  the pill over `dur_fast` (0.18s, the existing token), the border
  darkens, and then the label swaps from the number to `Beli` with a
  scale pop from 0.55 to 1.0 over 0.22s, starting at 230ms so the pop
  lands after the wipe completes rather than competing with it.
- **Unaffordable:** pill and item desaturate to neutral; price stays
  visible; press does nothing.

The tag is the press target, which gives the drop animation an explicit
trigger instead of the whole item being one large invisible button.

### 3. Basket icon

`Assets/Images/Shop/UI/icon_keranjang.svg` — a slatted market basket:
chunky vertical slats, one belly band, rolled rim, arch handle. Warm
browns matching the koperasi palette. Hand-authored vector paths, not
`System.Drawing` output; drop-replaceable at that path with no code
change, like the project's other placeholder art. Replaces the black
silhouette. Carries a count badge and keeps `basket_bounce` on landing.

### 4. Shelf item life

Per item, driven by documented `@export` knobs on a `@tool` script:

- Soft drop shadow onto the plank, reusing the existing
  `shadow_ellipse.png`.
- Idle bob at a per-item phase offset, so the shelf does not pulse in
  unison.
- Lift plus rim glow on press.
- Dimmed and desaturated when unaffordable — the feedback most missing
  today.

### 5. Cleanup folded in

`koprasi.gd:117` ships `"Keranjang kosong! 🛒"`. Emoji as UI iconography
is banned by the project conventions; this becomes a real texture plus
plain text.

## Constraints this pass must honour

- No `theme_override_*`. New `ThemeFactory` type variations
  (`PriceTag`, `BasketTray`, and whatever the tray slot needs), then a
  rebake of `Assets/Theme/kejartes_theme.tres`.
- No runtime visual construction: static chrome in the `.tscn`, repeated
  slots as a `PackedScene`, responsive geometry in a `@tool` script.
- Every script gets a `##` file header and a `##` line per `@export`.
- All UI text Indonesian; systems code English.
- New `@export`s on `DesignTokens` require a full editor restart before
  their defaults take effect.

## Testing

- New `tests/test_koperasi_tray.gd` — tray slot layout, `×N` badge
  behaviour, empty state, total calculation.
- New assertions in the theme suite for the added variations.
- `tests/test_script_documentation.gd` and
  `tests/test_viewport_editability.gd` must not regress; the BASELINE
  ratchet only ever goes down.
- Source-text scans where the UI cannot be instantiated headlessly,
  following the established pattern.

## Open items

None. Basket (B3), tag reading (R2 with the left-to-right wipe), and the
tray layout (L3) are all confirmed by the mentor.
