# Penjadwalan Mockup Rescale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resize the Penjadwalan popup to the mockup's true scale and add the surface finish it is missing, so the shipped screen matches the reference.

**Architecture:** The structure shipped previously is correct — one bordered container per row, icon on its fill, darker pill inset right, label overlapping the bottom edge. What is wrong is **scale**: the card renders at 55.6% of screen width where the mockup is 78.7%. Task 1 rescales the row widget, Task 2 grows and repositions the card and re-seats its children, Task 3 corrects the surface finish (border width, shadows, fill values).

**Tech Stack:** Godot 4.6, GDScript. `ThemeFactory` design-token pipeline, `McpTestSuite` test runner.

**Spec:** The mockup at `C:\Users\ASUS\Downloads\penjadwalan_mockup.png` (1080×1920), measured by pixel probe under the `pixel-accurate-ui-from-mockups` skill. The measurements section below is the spec.

## Global Constraints

- Labels stay **Milker ALL CAPS**. Milker has no lowercase glyphs; the mockup's Title Case is unreachable without a typeface change, which is out of scope.
- **Never add a `theme_override_*`** on a scene node. Use a `ThemeFactory` type variation. Only accepted exception: layout-only constants (`separation`, `margin_*`).
- Every interactive control must clear `tokens.touch_target_min` (96px) — enforced by `tests/test_atur_jadwal.gd::test_interactive_controls_meet_the_minimum_touch_target`.
- Test suites must be `@tool`; **no test may be a coroutine** (the runner does not await; an `await` silently aborts the test).
- A test whose only assertions sit inside a loop that may not execute reports "0 assertions" and **fails**. Collect into a list, assert once after the loop.
- Run `filesystem_manage(op="scan")` after editing any `.gd` and before `test_run`.
- A theme rebake rewrites `Assets/Theme/kejartes_theme.tres`, which `test_theme_factory`, `test_student_card` and `test_activity_row` all assert against. Always follow a rebake with a full-suite run.

## Measured Target Geometry

Probed with `~/.claude/skills/pixel-accurate-ui-from-mockups/probe.ps1`.

### Aspect gate — PASSES

| | Size | Aspect |
|---|---|---|
| Mockup card content | 850 × 1305 | 0.6513 |
| Card texture content (`penjadwalan_card_bg.png`, 1080² canvas) | 658 × 1013 | 0.6495 |

0.3% apart. Safe to map proportionally.

### The scale error

The mockup canvas is 1080×1920 — the game's exact resolution — so mockup pixels map 1:1 to screen pixels.

| | Card on screen | % of 1080 width |
|---|---|---|
| Mockup | x 115–964 (850 wide), y 203–1507 | **78.7%** |
| Currently shipped | 601 wide | 55.6% |

The mockup's card centre is (539.5, 855). Screen centre is (540, 960): horizontally centred, **105px above centre** vertically.

To render card content 850 wide from a texture whose content is 658/1080 of its canvas:
`W = 850 × 1080 / 658 = 1395`. Rounded to **1394** for even half-offsets.

### Surface table (mockup px)

| # | Surface | Parent | Rect | Fill (centroid) | Border | Notes |
|---|---------|--------|------|-----------------|--------|-------|
| 1 | Card | screen | 115,203,850,1305 | gradient `#F4F6B9`→`#B3B487` | `#3D2048` 4px | supplied art, unchanged |
| 2 | Row container | Card | rows at x 218–868 (651 wide), h 141 | gradient `#717171`→`#5D5D5D` | `#3D2048` **3px** | + dark drop shadow `#3B3B2D` ~3px below |
| 3 | Inset pill | Row container | x 433–851, inset 25 top / 22 bottom | gradient `#3C3C3C`→`#303030` | **none** | soft dark edge `#2B2B2B`, a shadow not a stroke |
| — | Icon glyph | on Row container | x 246–432 | `#FFFFFF` | `#3D1E48` outline | not a surface |
| — | Labels / values | text | — | `#FFFFFF` | `#3D1E48` outline | not surfaces |
| 4 | Back arrow | Card | 172,1355,178,105 | `#FFFFFF` | — | asset content is 512×379 (aspect 1.351) |

Rows 4 and 5 (Wirausaha, Libur) have the row container but **no inset pill** — chips sit on the grey. Confirmed: a vertical scan at x=600 through those rows finds no `#3D3D3D` pill fill.

### Fractions → new scene coordinates

New `TextureRect` = 1394×1394 ⇒ card content in TextureRect-local coords: **x 272–1120 (848 wide), y 44–1350 (1306 tall)**.

| Measure | Mockup fraction | New local value |
|---|---|---|
| Rows left inset | 103/850 = 0.1212 | 272 + 103 = **375** |
| Rows right inset | 96/850 = 0.1129 | 1120 − 96 = **1024** |
| Rows top | 58/1305 = 0.0444 | 44 + 58 = **102** |
| Row container height | 141/1305 = 0.1080 | **141** |
| Label band below container | 39/1305 = 0.0299 | **39** |
| `ActivityRow` total height | 141 + 39 | **180** |
| Row pitch | 220/1305 = 0.1686 | 220 ⇒ separation **40** |
| Pill left inset (in container) | 215/651 = 0.330 | **214** |
| Pill right inset | 17/651 = 0.026 | **17** |
| Pill vertical inset | ~23/141 | **23** top and bottom |

Stack check: `102 + 5×180 + 4×40 = 1162`, inside the 1350 card bottom. ✅

## Current vs Target

| Property | Current | Target |
|---|---|---|
| `TextureRect` | 988 × 988, centred | **1394 × 1394**, centred horizontally, **−105** vertically |
| `Rows` offsets | 263 / 72 / 724 / 827 | **375 / 102 / 1024 / 1162** |
| `Rows` separation | 30 | **40** |
| `ActivityRow` height | 127 | **180** |
| Container height | 101 | **141** |
| Pill insets | 151 / −15 / 18 / −18 | **214 / −17 / 23 / −23** |
| Icon box | 34,9 → 118,93 (84²) | **48,13 → 166,131 (118²)** |
| `NameLabel` offsets | −340, −40 | **−480, −44** |
| `PopupBack` | 236,821 → 361,946 | **329,1170 → 507,1348** |
| Row border width | 4px | **3px** |
| Row fill | flat `#626262` | flat `#676767` (gradient midpoint) |
| Row shadow | none | **black 70%, size 3, offset (0,3)** |
| Pill fill | flat `#363636` | unchanged — already the measured midpoint |
| Pill edge | none | **black 50%, size 5, offset (0,2)** |

### One deliberate deviation from the mockup

The mockup fills the row container and pill with **vertical gradients**. `StyleBoxFlat` has no gradient support in Godot 4. Reproducing them exactly would mean baking 9-slice gradient textures with the border included — which fights this project's token-driven theme, where every surface is a `StyleBoxFlat` derived from `design_tokens.tres`.

This plan uses the **measured midpoint** of each gradient as a flat fill, which is what the design system can express, and adds the drop shadows that `StyleBoxFlat` *does* support. Row fill moves `#626262` → `#676767`; the current value sat near the gradient's dark end (`#5D5D5D`), making rows read flatter and darker than the reference. If the gradient is wanted later it is a separate task: generate two 9-slice textures and swap the two styleboxes to `StyleBoxTexture`.

## File Structure

- **Modify** `Scenes/AturJadwal/ActivityRow.tscn` — rescale the row's internals.
- **Modify** `Scenes/AturJadwal/atur_jadwal.tscn` — grow/shift the card, re-seat `Rows` and `PopupBack`.
- **Modify** `Scripts/Design/DesignTokens.gd` — one token value change.
- **Modify** `Scripts/Design/ThemeFactory.gd` — border width and the two shadows.
- **Modify** `Assets/Theme/kejartes_theme.tres` — regenerated by rebake, never hand-edited.
- **Modify** `tests/test_activity_row.gd`, `tests/test_atur_jadwal.gd`.

---

### Task 1: Rescale ActivityRow to the mockup's row size

The row widget is built at 127px tall where the mockup's is 180. Every internal offset scales with it.

**Files:**
- Modify: `Scenes/AturJadwal/ActivityRow.tscn` (full replacement)
- Test: `tests/test_activity_row.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces, for Task 2: `ActivityRow` is **180px** tall (`custom_minimum_size = Vector2(200, 180)`). Task 2's stack arithmetic (`102 + 5×180 + 4×40 = 1162`) depends on exactly 180. Node paths are unchanged: `Container`, `Container/Icon`, `Container/Pill`, `Container/Pill/StatBar`, `Container/Pill/Chips`, `NameLabel`.

- [ ] **Step 1: Update the geometry constants and their tests**

In `tests/test_activity_row.gd`, replace the five geometry constants:

```gdscript
## Geometry pinned to the mockup's scanlines (penjadwalan_mockup.png, 1080x1920).
## Each row is ONE bordered container 141px tall; the icon draws on its grey and
## a darker pill is inset to the right. The name label overlaps the container's
## bottom edge and hangs into the 39px band beneath, so the row is 180 total.
const _ROW_HEIGHT := 180.0
const _CONTAINER_HEIGHT := 141.0
const _ICON_REGION := 214.0
const _PILL_RIGHT_INSET := 17.0
const _PILL_V_INSET := 23.0
```

The assertions already read from these constants, but **three message strings
carry stale literals** and must be updated in the same pass or they will lie to
whoever reads a future failure:

```gdscript
		"the row's height is fixed at the mockup's 180px")
```
```gdscript
	assert_eq(box.offset_bottom, _CONTAINER_HEIGHT, "the container is 141px tall")
```
```gdscript
		"the icon must stay inside the 214px region left of the pill")
```

Then confirm by grep that no literal `127`, `101`, `151`, `15px` or `18px`
remains anywhere in this file's geometry section.

- [ ] **Step 2: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: FAIL — `custom_minimum_size.y` is 127 not 180, `Container.offset_bottom`
is 101 not 141, `Pill.offset_left` is 151 not 214.

- [ ] **Step 3: Rewrite the scene at the new scale**

Replace the whole of `Scenes/AturJadwal/ActivityRow.tscn` with:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://Scripts/AturJadwal/ActivityRow.gd" id="1_row"]
[ext_resource type="Script" path="res://Scripts/UI/StatBar.gd" id="2_statbar"]

[node name="ActivityRow" type="Button"]
custom_minimum_size = Vector2(200, 180)
size_flags_horizontal = 3
flat = true
script = ExtResource("1_row")
category = "Akademis"
display_name = "Akademik"

[node name="Container" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 141.0
grow_horizontal = 2
mouse_filter = 2
theme_type_variation = &"PreviewRow"

[node name="Icon" type="TextureRect" parent="Container"]
layout_mode = 1
anchors_preset = 0
offset_left = 48.0
offset_top = 13.0
offset_right = 166.0
offset_bottom = 131.0
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Pill" type="PanelContainer" parent="Container"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 214.0
offset_top = 23.0
offset_right = -17.0
offset_bottom = -23.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_type_variation = &"PreviewPill"

[node name="StatBar" type="ProgressBar" parent="Container/Pill"]
layout_mode = 2
size_flags_vertical = 1
mouse_filter = 2
show_percentage = false
script = ExtResource("2_statbar")
category = "Akademis"

[node name="Chips" type="HBoxContainer" parent="Container/Pill"]
layout_mode = 2
mouse_filter = 2
alignment = 2
theme_override_constants/separation = 16

[node name="NameLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -480.0
offset_top = -44.0
grow_horizontal = 0
grow_vertical = 0
mouse_filter = 2
theme_type_variation = &"PreviewRowLabel"
text = "Akademik"
horizontal_alignment = 2
vertical_alignment = 1
```

`offset_top = -44.0` on `NameLabel` puts its top at y=136 in a 180-tall row — 5px
above the container's bottom edge at 141, which is the overlap the mockup shows.
`Chips` separation goes 12 → 16, scaling with the row.

- [ ] **Step 4: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: PASS, 23 tests.

- [ ] **Step 5: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: `atur_jadwal` **fails** — its `test_the_row_stack_fits_inside_the_card`
asserts a 127px row, and its `Rows` offsets still describe the small card. Task 2
fixes both. Every other suite must stay green apart from the known
`audio_director::test_volumes_persist_across_a_fresh_director` coroutine failure
(CLAUDE.md Known Issues #1). **If any other suite fails, stop and investigate.**

- [ ] **Step 6: Commit**

```bash
git add Scenes/AturJadwal/ActivityRow.tscn tests/test_activity_row.gd
git commit -m "fix(atur-jadwal): rescale ActivityRow to the mockup's 180px row"
```

---

### Task 2: Grow the card to its true size and re-seat its children

The card renders at 55.6% of screen width where the mockup is 78.7%.

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (`Penjadwalan/TextureRect`, `Rows`, `PopupBack`)
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `ActivityRow`'s 180px height from Task 1.
- Produces: no new API.

- [ ] **Step 1: Update the card-box constants and the geometry tests**

In `tests/test_atur_jadwal.gd`, replace the card constants:

```gdscript
## The card art is a 1080x1080 texture whose visible card occupies only
## x 211-868, y 34-1046. Rendered into a square 1394x1394 TextureRect, that
## content lands at local x 272-1120, y 44-1350 -- and on screen at x 115-964,
## y 202-1508, which is the mockup's card position (115-964, 203-1507).
const _CARD_LEFT := 272.0
const _CARD_RIGHT := 1120.0
const _CARD_TOP := 44.0
const _CARD_BOTTOM := 1350.0
const _ROW_HEIGHT := 180.0
```

Replace the three geometry tests' expected values:

```gdscript
func test_rows_are_inset_within_the_card_content() -> void:
	var rows := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows") as Control
	assert_true(rows != null, "Rows must exist")
	assert_eq(rows.offset_left, 375.0, "rows are inset 12.1% from the card's left edge")
	assert_eq(rows.offset_right, 1024.0, "rows are inset 11.3% from the card's right edge")
	assert_eq(rows.offset_top, 102.0, "the first row starts 4.4% down the card")
	assert_true(rows.offset_left > _CARD_LEFT and rows.offset_right < _CARD_RIGHT,
		"the row block must sit inside the card art, not over its transparent padding")
	assert_true(rows.offset_top > _CARD_TOP,
		"the row block must start below the card's top edge, not over its transparent padding")


func test_row_separation_matches_the_mockup_pitch() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	assert_eq(rows.get_theme_constant("separation"), 40,
		"a 180px row plus 40px separation reproduces the mockup's 220px pitch")


func test_back_arrow_sits_inside_the_card() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack") as Control
	assert_true(back != null, "PopupBack must exist")
	assert_eq(back.offset_left, 329.0, "back arrow x, 6.7% in from the card's left")
	assert_eq(back.offset_top, 1170.0, "back arrow y, its art centred 92.3% down the card")
	assert_true(back.offset_left >= _CARD_LEFT,
		"the back arrow must not hang off the card's left padding")
	assert_true(back.offset_bottom <= _CARD_BOTTOM,
		"the back arrow must stay above the card's bottom edge")
```

Then **replace** the existing `test_card_texture_rect_is_square` (it is already in
this file, at roughly line 302) with the stronger test below. Replace rather than
append — the new test re-asserts squareness, so keeping both would duplicate that
check:

```gdscript
## The mockup's card spans 78.7% of the 1080px screen width (x 115-964). Rendering
## the card texture into too small a rect makes a correct layout look cramped at
## every level, because every child inherits the shortfall.
func test_card_is_rendered_at_the_mockup_scale() -> void:
	var card := _screen.get_node_or_null("Penjadwalan/TextureRect") as TextureRect
	assert_true(card != null, "the popup's card TextureRect must exist")
	var w: float = card.offset_right - card.offset_left
	var h: float = card.offset_bottom - card.offset_top
	assert_eq(w, h, "the card rect must stay square so the 1080x1080 art is not stretched")
	assert_eq(w, 1394.0, "the card rect is 1394px so its content renders 850px wide")
	# Mockup card centre is 105px above screen centre, not centred.
	var centre_y: float = (card.offset_top + card.offset_bottom) / 2.0
	assert_eq(centre_y, -105.0, "the card sits 105px above screen centre, as in the mockup")
```

- [ ] **Step 2: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: FAIL — the rect is 988×988 centred, `Rows` is at 263/72/724/827 with
separation 30, and `PopupBack` is at (236, 821).

- [ ] **Step 3: Grow and shift the card**

In `Scenes/AturJadwal/atur_jadwal.tscn`, on `Penjadwalan/TextureRect` replace the
four offsets:

```
offset_left = -697.0
offset_top = -802.0
offset_right = 697.0
offset_bottom = 592.0
```

Leave `anchors_preset = 8`, the anchors, `texture` and `expand_mode` untouched.
That is a 1394×1394 rect whose centre sits 105px above the screen's, placing the
card's visible content at screen x 115–963, y 202–1508.

- [ ] **Step 4: Re-seat the Rows container**

```
[node name="Rows" type="VBoxContainer" parent="Penjadwalan/TextureRect"]
layout_mode = 0
offset_left = 375.0
offset_top = 102.0
offset_right = 1024.0
offset_bottom = 1162.0
theme_override_constants/separation = 40
```

Leave all five `RowAkademik`…`RowLibur` child instances untouched — their
`category`, `display_name`, `icon_texture`, `energy_icon`, `mood_icon` and
`is_skill_row` values are all still correct.

- [ ] **Step 5: Re-seat the back arrow**

```
[node name="PopupBack" type="TextureButton" parent="Penjadwalan/TextureRect"]
layout_mode = 0
offset_left = 329.0
offset_top = 1170.0
offset_right = 507.0
offset_bottom = 1348.0
texture_normal = ExtResource("10_return")
ignore_texture_size = true
stretch_mode = 0
```

That is 178×178. `return.png`'s arrow content occupies rows 41–419 of its 512²
canvas, so at `stretch_mode = 0` the visible arrow renders 178 wide × 132 tall
with its centre at local y≈1250 — the mockup's arrow centre. 178px also clears
the 96px touch minimum comfortably.

- [ ] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: PASS, 22 tests — including
`test_interactive_controls_meet_the_minimum_touch_target`, now measuring 180px rows.

- [ ] **Step 7: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure.

- [ ] **Step 8: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd
git commit -m "fix(atur-jadwal): render the popup card at the mockup's true scale"
```

---

### Task 3: Correct the surface finish

Border width, the two missing shadows, and the row fill value.

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (`preview_row_fill`)
- Modify: `Scripts/Design/ThemeFactory.gd` (the `PreviewRow` / `PreviewPill` blocks)
- Modify: `Assets/Theme/kejartes_theme.tres` (via rebake)
- Test: `tests/test_activity_row.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: no new API. `PreviewRow` and `PreviewPill` keep their names and base types.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_activity_row.gd`:

```gdscript
## The mockup's rows carry a hard dark shadow just below their bottom border, and
## the inset pill has a soft dark edge rather than a stroke. Without them the
## surfaces read as flat decals on the card instead of raised/inset panels.
func test_preview_row_border_and_shadow_match_the_mockup() -> void:
	var theme: Theme = load(_THEME_PATH)
	var sb := theme.get_stylebox("panel", "PreviewRow") as StyleBoxFlat
	assert_true(sb != null, "PreviewRow/panel must be a StyleBoxFlat")
	assert_eq(sb.border_width_top, 3, "the mockup's row border is 3px, not 4")
	assert_true(sb.shadow_size > 0, "the row casts a drop shadow onto the card")
	assert_true(sb.shadow_offset.y > 0, "that shadow falls below the row, as in the mockup")


func test_preview_pill_has_a_soft_edge_not_a_stroke() -> void:
	var theme: Theme = load(_THEME_PATH)
	var sb := theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_true(sb != null, "PreviewPill/panel must be a StyleBoxFlat")
	assert_eq(sb.border_width_top, 0,
		"the pill's dark edge is a shadow, not a border -- a stroke reads wrong")
	assert_true(sb.shadow_size > 0, "the pill's edge is a soft shadow")
```

- [ ] **Step 2: Run the tests to verify they fail**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: FAIL — `border_width_top` is 4 on `PreviewRow`, and neither stylebox has
a shadow.

- [ ] **Step 3: Correct the row fill token**

In `Scripts/Design/DesignTokens.gd`, change one line and its comment:

```gdscript
## Sampled from the mockup (docs: 2026-08-29-penjadwalan-mockup-rescale.md).
## The row container is a grey slab with a purple rim; the pill inset into
## it is darker. Both are vertical gradients in the mockup (row #717171 ->
## #5D5D5D, pill #3C3C3C -> #303030); StyleBoxFlat cannot express a gradient,
## so each token is that gradient's midpoint.
@export var preview_row_fill: Color = Color("676767")
```

Leave `preview_row_border` and `preview_pill_fill` as they are — `#3d2048` and
`#363636` are already the measured values.

- [ ] **Step 4: Add the shadows and correct the border width**

In `Scripts/Design/ThemeFactory.gd`, replace the `PreviewRow` and `PreviewPill`
stylebox construction (leave `PreviewPillFlat`, `PreviewChipLabel` and
`PreviewRowLabel` untouched):

```gdscript
	# -- Penjadwalan row container: the bordered grey slab each row sits on.
	# The icon draws directly onto this; the pill below is inset into it. The
	# mockup shows a hard dark shadow just under the bottom border. --
	var preview_row := StyleBoxFlat.new()
	preview_row.bg_color = tokens.preview_row_fill
	preview_row.border_color = tokens.preview_row_border
	preview_row.set_border_width_all(3)
	preview_row.set_corner_radius_all(tokens.radius_md)
	preview_row.shadow_color = Color(0, 0, 0, 0.7)
	preview_row.shadow_size = 3
	preview_row.shadow_offset = Vector2(0, 3)
	theme.add_type("PreviewRow")
	theme.set_type_variation("PreviewRow", "Panel")
	theme.set_stylebox("panel", "PreviewRow", preview_row)

	# -- The darker pill inset into the row, carrying the numbers. Its edge in
	# the mockup is a soft dark halo, NOT a stroke -- building it as a border
	# reads as a hard outline the reference does not have. --
	var preview_pill := StyleBoxFlat.new()
	preview_pill.bg_color = tokens.preview_pill_fill
	preview_pill.set_corner_radius_all(tokens.radius_md)
	preview_pill.content_margin_left = tokens.space_sm
	preview_pill.content_margin_right = tokens.space_sm
	preview_pill.content_margin_top = tokens.space_xs
	preview_pill.content_margin_bottom = tokens.space_xs
	preview_pill.shadow_color = Color(0, 0, 0, 0.5)
	preview_pill.shadow_size = 5
	preview_pill.shadow_offset = Vector2(0, 2)
	theme.add_type("PreviewPill")
	theme.set_type_variation("PreviewPill", "PanelContainer")
	theme.set_stylebox("panel", "PreviewPill", preview_pill)
```

The pill's corner radius goes `radius_sm` → `radius_md`: the mockup's pill corners
are visibly as round as the container's.

- [ ] **Step 5: Rebake the theme**

`BakeTheme.gd` is an `EditorScript` (File > Run), unreachable over MCP. Run the
same lines through a live game instead:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "var t = DesignTokens.load_default()\nvar th = ThemeFactory.build(t)\nreturn ResourceSaver.save(th, \"res://Assets/Theme/kejartes_theme.tres\")"})
project_manage(op="stop")
filesystem_manage(op="scan")
```

Expected: `game_eval` returns `0` (`OK`).

**Two caches bite on this project — both are documented and both have a fix.**

1. *Theme cache.* If Step 6 fails while `grep PreviewRow Assets/Theme/kejartes_theme.tres`
   shows the file is correct on disk, the editor is serving a stale `Theme`. Add
   this as the first line of one failing test, run once, then remove it:
   ```gdscript
   	ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
   ```
2. *Token defaults cache.* Changing a `@export` **default** in `DesignTokens.gd`
   may not reach `design_tokens.tres` in the editor process — a freshly
   constructed `DesignTokens.new()` sees the new default while the same property
   loaded from the `.tres` returns the old value or `null`. This plan avoids that
   trap: `preview_row_fill` is already written explicitly into
   `Assets/Theme/design_tokens.tres`, so **update that file's literal too**:
   ```
   preview_row_fill = Color(0.40392157, 0.40392157, 0.40392157, 1)
   ```
   (`#676767` = 103/255 = 0.40392157.)

- [ ] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: PASS, 25 tests.

- [ ] **Step 7: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure. Watch `theme_factory` and
`student_card` — they assert against the file just rewritten.

- [ ] **Step 8: Verify against the mockup**

Seed the state rather than clicking through the game:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "DebugManager._seed_playtest_state()\nawait get_tree().process_frame\nget_tree().change_scene_to_file(\"res://Scenes/AturJadwal/atur_jadwal.tscn\")\nawait get_tree().process_frame\nawait get_tree().process_frame\nvar s = get_tree().current_scene\nGameState.selected_day = \"Senin\"\nGameState.selected_student = GameState.approved_students[0]\ns._show_penjadwalan_popup()\nawait get_tree().process_frame\nreturn s.penjadwalan_popup_open"})
editor_screenshot(source="game", max_resolution=1080)
```

Then confirm the resolved geometry numerically — reading the scene file is not
verification:

```
editor_manage(op="game_eval", params={"code":
  "var s = get_tree().current_scene\nvar c = s.get_node(\"Penjadwalan/TextureRect\")\nvar r = s.get_node(\"Penjadwalan/TextureRect/Rows/RowAkademik\")\nreturn {\"card\": var_to_str(c.size), \"card_global_x\": c.global_position.x, \"row\": var_to_str(r.size), \"container\": var_to_str(r.get_node(\"Container\").size), \"pill\": var_to_str(r.get_node(\"Container/Pill\").size)}"})
project_manage(op="stop")
```

Expected: `card` `(1394, 1394)`, `card_global_x` ≈ `-157`, `row` `(649, 180)`,
`container` `(649, 141)`, `pill` `(418, 95)`.

Against the mockup, check in this order:
1. The card fills ~79% of the screen width — noticeably larger than before, and
   sitting slightly above centre.
2. Each row is one bordered container with a visible dark shadow beneath it.
3. The inset pill has a soft dark halo at its edge, not a hard outline.
4. Wirausaha and Libur show no inset pill; their chips sit on the grey.
5. Each label is right-aligned, overlapping its own container's bottom edge.
6. The back arrow sits in the card's lower-left, on the gradient.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Scripts/Design/ThemeFactory.gd \
        Assets/Theme/design_tokens.tres Assets/Theme/kejartes_theme.tres \
        tests/test_activity_row.gd
git commit -m "fix(theme): match the Penjadwalan row and pill surface finish to the mockup"
```

---

## Self-Review

**Spec coverage.** Every row of the Current-vs-Target table maps to a task. Row
widget scale is Task 1. Card size/position, `Rows`, and `PopupBack` are Task 2.
Border width, both shadows, the fill value and the pill radius are Task 3. The
one measurement deliberately *not* reproduced — the gradients — is called out in
its own section with the reason and the follow-up path, rather than quietly
dropped.

**Placeholder scan.** No TBDs. Every number traces to a probe result in Measured
Target Geometry; every colour is a sampled hex or an explicit derivation from one
(`#676767` is stated as the midpoint of `#717171`/`#5D5D5D`). Both scene edits
give the exact block to paste.

**Type consistency.** `_ROW_HEIGHT` (180) is used in Task 1's tests, Task 2's
tests, and matches `custom_minimum_size = Vector2(200, 180)`. `_CONTAINER_HEIGHT`
(141) matches `Container.offset_bottom`. `_ICON_REGION` (214) matches
`Pill.offset_left`. `_PILL_RIGHT_INSET` (17) and `_PILL_V_INSET` (23) match the
pill's negative offsets. The card constants (272/1120/44/1350) are derived from
the 1394 rect set in Task 2 Step 3 and used by Task 2's containment assertions.

**A deliberate cross-task red state.** Task 1 leaves `atur_jadwal` failing: its
stack-fit test reads the row height from the live `ActivityRow`, so a 180px row
overflows the card box that Task 2 has not yet grown. Task 2 closes it. This is
flagged in Task 1 Step 5 with the guard that any *other* failing suite means stop.
Splitting the row rescale from the card rescale is still right — they are
separately reviewable, and merging them would put two unrelated scene files in
one commit.

**Risks worth flagging.** Task 3's rebake rewrites `kejartes_theme.tres`, which
two other suites assert against; Step 7's full-suite run is the gate. And this
project has bitten twice on editor-side caches — the theme cache and, newly, a
token-default cache that returns `null` for a freshly added `@export`. Both are
documented inline in Task 3 Step 5 with their fixes, so an implementer does not
rediscover them the slow way.
