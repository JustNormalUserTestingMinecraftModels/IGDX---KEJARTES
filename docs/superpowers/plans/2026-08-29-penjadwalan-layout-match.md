# Penjadwalan Layout Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Penjadwalan popup's layout match the supplied mockup — correct row proportions, icon-box/pill split, name-label placement, and back-arrow position inside the card.

**Architecture:** Three changes, smallest blast radius first. A one-line `ThemeFactory` bug fix makes the pill boxes render at all (they currently fall back to Godot's built-in panel). Then `ActivityRow.tscn`'s internal geometry is re-cut to the mockup's measured proportions. Then the `Rows` container and back arrow are repositioned inside the card art's real content box.

**Tech Stack:** Godot 4.6, GDScript. `ThemeFactory` design-token pipeline, `McpTestSuite` test runner.

**Spec:** No separate spec document — this plan implements a user-supplied mockup image, measured in "Measured Target Geometry" below. That section is the spec.

## Global Constraints

- **Scope is layout only.** The user explicitly excluded icons and colours from this round: *"not the icons or color, but the layout."* Do **not** add colour tokens, recolour icon art, restyle fills/borders, or touch `design_tokens.tres`. Task 1 is included only because the pill boxes do not render *at all* right now, so no layout can be judged until they do.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only accepted exception: layout-only constant overrides (`separation`, `margin_*`).
- Every interactive control must be at least `tokens.touch_target_min` (96px) — `tests/test_atur_jadwal.gd::test_interactive_controls_meet_the_minimum_touch_target` enforces this on all five rows and `PopupBack`.
- Test suites must be `@tool` and **no test may be a coroutine**.
- Run `filesystem_manage(op="scan")` after editing any `.gd` and before `test_run`.
- Rebaking the theme writes `Assets/Theme/kejartes_theme.tres`, which `test_theme_factory`, `test_student_card`, and `test_activity_row` all assert against. Always follow a rebake with a full-suite run.

## Measured Target Geometry

The mockup is 1080×1080. Its card content occupies **x: 211–868 (657 wide), y: 34–1046 (1012 tall)** — the rest is transparent padding. Every measurement below is expressed as a fraction of that content box, then converted into the live scene's coordinate space.

**Mockup fractions:**

| Element | Fraction |
|---|---|
| Row block, left inset | 0.120 of card width |
| Row block, right inset | 0.111 of card width |
| Icon box width | 145/505 of row-block width |
| Icon→pill gap | 17/505 of row-block width |
| Pill width | 343/505 of row-block width |
| Pill height | 0.099 of card height |
| First row, top | 0.050 of card height |
| Row pitch (top of row N → top of row N+1) | 0.163 of card height |
| Name-label band, below pill | 0.035 of card height |
| Back arrow, left inset | 0.072 of card width |
| Back arrow, top | 0.875 of card height |

**Conversion.** In the live scene `Penjadwalan/TextureRect` is **988×1600** and draws the 1080×1080 texture with `expand_mode = 1`, so the whole texture — transparent padding included — maps onto that rect. The card's visible content therefore sits at TextureRect-local **x: 193–794 (601 wide), y: 50–1550 (1500 tall)**. Applying the fractions:

| Target | Local value |
|---|---|
| `Rows` left edge | 193 + 0.120·601 = **265** |
| `Rows` right edge | 794 − 0.111·601 = **727** |
| `Rows` width | **462** |
| `Rows` top | 50 + 0.050·1500 = **125** |
| Pill height | 0.099·1500 = **148** |
| Name-label band | 0.035·1500 ≈ **52** |
| `ActivityRow` total height | 148 + 52 = **200** |
| Row pitch | 0.163·1500 = 245 → `separation` = 245 − 200 = **45** |
| Icon box width | 145/505·462 = **133** |
| Icon→pill gap | 17/505·462 ≈ **16** |
| Pill left edge (within row) | 133 + 16 = **149** |
| `PopupBack` position | x = 193 + 0.072·601 ≈ **236**, y = 50 + 0.875·1500 ≈ **1370** |
| `PopupBack` size | **125 × 125** |

Sanity check on the vertical stack: `125 + 5·200 + 4·45 = 1305`, leaving 245px of card below the last row for the back arrow at y=1370. Fits.

## Current vs. Target

Measured live from the running game (`RowAkademik`):

| Property | Current | Target | Why it's wrong |
|---|---|---|---|
| Pill resolved stylebox | `Color(0.1, 0.1, 0.1, 0.6)` | the designed `PreviewPill` box | `PreviewPill` has no `base_type`, so Godot ignores the variation |
| `ActivityRow` height | 264 | 200 | `size_flags_vertical = 3` lets the VBox stretch it |
| `IconBox` size | 104 × 228 | 133 × 148 | anchored to fill vertically; mockup's box is far squarer |
| `Pill` size | 480 × 228 | 313 × 148 | inherits the same vertical stretch |
| `Rows` left/right | 190 / 798 | 265 / 727 | flush with the card edge; mockup insets ~12% per side |
| `Rows` top | 60 | 125 | starts above the card's content box |
| `separation` | 40 | 45 | — |
| `PopupBack` | 96×96 at (60, 1480) | 125×125 at (236, 1370) | x=60 is outside the card content, which starts at x=193 |

## File Structure

- **Modify** `Scripts/Design/ThemeFactory.gd` — add the missing `set_type_variation` call for `PreviewPill`.
- **Modify** `Assets/Theme/kejartes_theme.tres` — regenerated by the rebake, not hand-edited.
- **Modify** `Scenes/AturJadwal/ActivityRow.tscn` — re-cut the row's internal geometry.
- **Modify** `Scenes/AturJadwal/atur_jadwal.tscn` — reposition `Rows` and `PopupBack`.
- **Modify** `tests/test_activity_row.gd` — pin the variation resolution and the row geometry.
- **Modify** `tests/test_atur_jadwal.gd` — pin the popup-level placement.

---

### Task 1: Make the PreviewPill variation actually resolve

`ActivityRow` sets `theme_type_variation = &"PreviewPill"` on two `PanelContainer`s, but the baked theme declares `PreviewPill/styles/panel` with **no** `PreviewPill/base_type`. Every other panel variation in the file has one (`Card/base_type = &"Panel"`, `Scrim/base_type = &"Panel"`, `SunkenPanel/base_type = &"Panel"`). Without it Godot never matches the variation to a `PanelContainer`, so both boxes fall back to the engine's default translucent-black panel and the mockup's box structure is invisible.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (the `PreviewPill` block added in the previous plan)
- Modify: `Assets/Theme/kejartes_theme.tres` (via rebake)
- Test: `tests/test_activity_row.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: a `PreviewPill` variation that resolves for `PanelContainer`. Tasks 2 and 3 depend on the boxes being visible to judge layout.

- [ ] **Step 1: Write the failing test**

In `tests/test_activity_row.gd`, **replace** the existing `test_theme_declares_the_new_variations` with the two tests below. The existing test only checked that the type name exists, which is exactly why this bug slipped through — a variation can be declared and still never resolve.

```gdscript
func test_theme_declares_the_new_variations() -> void:
	var theme: Theme = load(_THEME_PATH)
	for variation in ["PreviewPill", "PreviewChipLabel"]:
		assert_true(theme.get_type_list().has(variation),
			"the baked theme must declare " + variation + " -- did you forget to rebake?")


## Declaring the type is not enough. Without a base_type Godot never matches
## the variation to a PanelContainer, so the node silently falls back to the
## engine's default panel and the pill renders as translucent black.
func test_preview_pill_is_bound_to_panel_container() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewPill"), &"PanelContainer",
		"PreviewPill must declare PanelContainer as its base_type, like every other panel variation")


## The end-to-end check the base_type test exists to protect: a real
## PanelContainer wearing the variation must resolve OUR stylebox, not the
## engine default (which is StyleBoxFlat with bg_color 0.1,0.1,0.1,0.6).
func test_preview_pill_resolves_the_designed_stylebox() -> void:
	var probe := PanelContainer.new()
	probe.theme = load(_THEME_PATH)
	probe.theme_type_variation = &"PreviewPill"
	Engine.get_main_loop().root.add_child(probe)
	track(probe)
	var resolved := probe.get_theme_stylebox("panel")
	var expected := (load(_THEME_PATH) as Theme).get_stylebox("panel", "PreviewPill")
	assert_true(resolved == expected,
		"a PreviewPill PanelContainer must resolve the theme's own stylebox, not Godot's default panel")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: FAIL on both new tests — `get_type_variation_base("PreviewPill")` returns `&""`, and the probe resolves the engine default rather than the theme's stylebox.

- [ ] **Step 3: Add the missing base_type**

In `Scripts/Design/ThemeFactory.gd`, find the `PreviewPill` block and add the `set_type_variation` line directly after `add_type`:

```gdscript
	theme.add_type("PreviewPill")
	theme.set_type_variation("PreviewPill", "PanelContainer")
	theme.set_stylebox("panel", "PreviewPill", preview_pill)
```

Change nothing else in that block — the fill, radius, and content margins stay exactly as they are. Colour is out of scope this round.

- [ ] **Step 4: Rebake the theme**

`BakeTheme.gd` is an `EditorScript` (File > Run), unreachable over MCP. Run the same three lines through a live game instead:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "var t = DesignTokens.load_default()\nvar th = ThemeFactory.build(t)\nreturn ResourceSaver.save(th, \"res://Assets/Theme/kejartes_theme.tres\")"})
project_manage(op="stop")
filesystem_manage(op="scan")
```

Expected: `game_eval` returns `0` (`OK`), and `Assets/Theme/kejartes_theme.tres` now contains a `PreviewPill/base_type = &"PanelContainer"` line.

**Editor cache caveat, learned the hard way on this exact file.** The rebake runs in the *game* process; the editor's test runner keeps its own cached copy and will keep serving the stale one through `scan()`, `reimport()`, and even a plugin reload. If Step 5 still fails, force a cache replace from inside the editor process — add this line temporarily at the top of the failing test, run once, then remove it:

```gdscript
	ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
```

That call updates the shared cache in place, so one run is enough and the clean test passes afterwards.

- [ ] **Step 5: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: PASS, 12 tests.

- [ ] **Step 6: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director::test_volumes_persist_across_a_fresh_director` coroutine failure documented in CLAUDE.md. Watch `theme_factory` and `student_card` — they assert against the file you just rewrote.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_activity_row.gd
git commit -m "fix(theme): bind PreviewPill to PanelContainer so the variation resolves"
```

---

### Task 2: Re-cut ActivityRow to the mockup's proportions

The row currently stretches to 264px tall with a 104×228 icon box. The mockup's row is a 148px-tall band — a 133px near-square icon box, a 16px gap, then the pill — with the name label in a 52px band beneath.

**Files:**
- Modify: `Scenes/AturJadwal/ActivityRow.tscn`
- Test: `tests/test_activity_row.gd`

**Interfaces:**
- Consumes: the resolving `PreviewPill` variation from Task 1.
- Produces: an `ActivityRow` that is exactly 200px tall at rest and does not vertically expand. Task 3's `Rows` arithmetic (`125 + 5·200 + 4·45 = 1305`) depends on that height.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_activity_row.gd`:

```gdscript
## Geometry pinned to the mockup. The row is a fixed-height band: a near-square
## icon box, a gap, the pill, and a name-label strip beneath. Letting the row
## expand vertically (the old behaviour) stretched it to 264px and turned the
## icon box into a tall rectangle nothing in the mockup resembles.
const _ROW_HEIGHT := 200.0
const _PILL_HEIGHT := 148.0
const _ICON_BOX_WIDTH := 133.0
const _PILL_LEFT := 149.0


func test_row_is_a_fixed_height_band() -> void:
	assert_eq(_row.custom_minimum_size.y, _ROW_HEIGHT,
		"the row's height is fixed at the mockup's 200px")
	assert_true(_row.size_flags_vertical != Control.SIZE_EXPAND_FILL,
		"the row must not expand vertically, or its parent VBox stretches it out of proportion")


func test_icon_box_is_the_mockup_square() -> void:
	var box := _row.get_node_or_null("IconBox") as Control
	assert_true(box != null, "IconBox must exist")
	_row.size = Vector2(462, _ROW_HEIGHT)
	assert_eq(box.offset_right, _ICON_BOX_WIDTH, "icon box is 133px wide")
	assert_eq(box.offset_bottom, _PILL_HEIGHT, "icon box is 148px tall, matching the pill")


func test_pill_starts_after_the_icon_gap_and_matches_its_height() -> void:
	var pill := _row.get_node_or_null("Pill") as Control
	assert_true(pill != null, "Pill must exist")
	assert_eq(pill.offset_left, _PILL_LEFT,
		"the pill starts at 149 -- a 133px icon box plus the mockup's 16px gap")
	assert_eq(pill.offset_bottom, _PILL_HEIGHT, "the pill is 148px tall")
	assert_eq(pill.anchor_right, 1.0, "the pill stretches to the row's right edge")


func test_name_label_sits_in_the_band_below_the_pill() -> void:
	var label := _row.get_node_or_null("NameLabel") as Label
	assert_true(label != null, "NameLabel must exist")
	assert_eq(label.offset_top, -(_ROW_HEIGHT - _PILL_HEIGHT),
		"the label occupies the 52px band under the pill")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"the mockup right-aligns the name under the pill's right edge")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: FAIL — `custom_minimum_size.y` is 140 not 200, `size_flags_vertical` is 3, `IconBox.offset_right` is 104, `Pill.offset_left` is 120.

- [ ] **Step 3: Rewrite the scene's geometry**

Replace the whole of `Scenes/AturJadwal/ActivityRow.tscn` with:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://Scripts/AturJadwal/ActivityRow.gd" id="1_row"]
[ext_resource type="Script" path="res://Scripts/UI/StatBar.gd" id="2_statbar"]

[node name="ActivityRow" type="Button"]
custom_minimum_size = Vector2(200, 200)
size_flags_horizontal = 3
flat = true
script = ExtResource("1_row")
category = "Akademis"
display_name = "Akademik"

[node name="IconBox" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 0
offset_right = 133.0
offset_bottom = 148.0
mouse_filter = 2
theme_type_variation = &"PreviewPill"

[node name="Icon" type="TextureRect" parent="IconBox"]
layout_mode = 2
custom_minimum_size = Vector2(64, 64)
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Pill" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_left = 149.0
offset_bottom = 148.0
grow_horizontal = 2
mouse_filter = 2
theme_type_variation = &"PreviewPill"

[node name="StatBar" type="ProgressBar" parent="Pill"]
layout_mode = 2
mouse_filter = 2
show_percentage = false
script = ExtResource("2_statbar")
category = "Akademis"

[node name="Chips" type="HBoxContainer" parent="Pill"]
layout_mode = 2
mouse_filter = 2
alignment = 2
theme_override_constants/separation = 12

[node name="NameLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -340.0
offset_top = -52.0
grow_horizontal = 0
grow_vertical = 0
mouse_filter = 2
theme_type_variation = &"CardSectionLabel"
text = "Akademik"
horizontal_alignment = 2
vertical_alignment = 1
```

Three things changed from the old file, all deliberate:
- `custom_minimum_size` is `(200, 200)`; the x floor stays at 200 because `test_interactive_controls_meet_the_minimum_touch_target` needs the row to clear 96px in *both* axes when instantiated bare.
- `size_flags_vertical = 3` is **gone**, so the parent VBox no longer stretches the row past 200px. `size_flags_horizontal = 3` stays — the row still fills the container's width.
- `IconBox` moves from `anchors_preset = 9` (left-wide, fills vertically) to `anchors_preset = 0` with explicit 133×148 offsets.

- [ ] **Step 4: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: PASS, 16 tests.

- [ ] **Step 5: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure. `atur_jadwal` must stay green — in particular the touch-target test, which now measures a 200×200 minimum instead of 200×140.

- [ ] **Step 6: Commit**

```bash
git add Scenes/AturJadwal/ActivityRow.tscn tests/test_activity_row.gd
git commit -m "fix(atur-jadwal): re-cut ActivityRow to the mockup's row proportions"
```

---

### Task 3: Seat the rows and the back arrow inside the card

The `Rows` container currently spans 190→798, flush against the card art's edges, and starts at y=60 — above the card's content box, which begins at y=50 but whose first row should start at 125. `PopupBack` sits at x=60, entirely outside the card content that begins at x=193.

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (the `Rows` and `PopupBack` nodes)
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `ActivityRow`'s fixed 200px height from Task 2.
- Produces: no new API.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_atur_jadwal.gd`:

```gdscript
## The card art is a 1080x1080 texture whose visible card occupies only
## x 211-868, y 34-1046 -- the rest is transparent padding. Stretched into the
## 988x1600 TextureRect that becomes local x 193-794, y 50-1550. Anything the
## player is meant to read must sit inside that box, not on the padding.
const _CARD_LEFT := 193.0
const _CARD_RIGHT := 794.0
const _CARD_TOP := 50.0
const _CARD_BOTTOM := 1550.0


func test_rows_are_inset_within_the_card_content() -> void:
	var rows := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows") as Control
	assert_true(rows != null, "Rows must exist")
	assert_eq(rows.offset_left, 265.0, "rows are inset 12% from the card's left edge")
	assert_eq(rows.offset_right, 727.0, "rows are inset 11% from the card's right edge")
	assert_eq(rows.offset_top, 125.0, "the first row starts 5% down the card")
	assert_true(rows.offset_left > _CARD_LEFT and rows.offset_right < _CARD_RIGHT,
		"the row block must sit inside the card art, not over its transparent padding")


func test_row_separation_matches_the_mockup_pitch() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	assert_eq(rows.get_theme_constant("separation"), 45,
		"a 200px row plus 45px separation reproduces the mockup's 245px pitch")


func test_back_arrow_sits_inside_the_card() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack") as Control
	assert_true(back != null, "PopupBack must exist")
	assert_true(back.offset_left >= _CARD_LEFT,
		"the back arrow must not hang off the card's left padding")
	assert_true(back.offset_bottom <= _CARD_BOTTOM,
		"the back arrow must stay above the card's bottom edge")
	assert_eq(back.offset_left, 236.0, "back arrow x, 7.2% in from the card's left")
	assert_eq(back.offset_top, 1370.0, "back arrow y, 87.5% down the card")


## 125 + 5*200 + 4*45 = 1305, which must clear the card's bottom edge with room
## for the arrow beneath. If a later change alters row height or separation,
## this is the test that catches the stack overflowing the card.
func test_the_row_stack_fits_inside_the_card() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	var row_count := 0
	for child in rows.get_children():
		if child is ActivityRow:
			row_count += 1
	var sep: int = rows.get_theme_constant("separation")
	var stack_bottom: float = rows.offset_top + row_count * 200.0 + (row_count - 1) * sep
	assert_true(stack_bottom <= _CARD_BOTTOM,
		"the row stack ends at %d, past the card's bottom at %d" % [int(stack_bottom), int(_CARD_BOTTOM)])
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: FAIL — `offset_left` is 190 not 265, `offset_top` is 60 not 125, `separation` is 40 not 45, and `PopupBack.offset_left` is 60, which is less than the card's 193.

- [ ] **Step 3: Reposition the Rows container**

In `Scenes/AturJadwal/atur_jadwal.tscn`, find the `Rows` node and replace its four offsets and the separation constant:

```
[node name="Rows" type="VBoxContainer" parent="Penjadwalan/TextureRect"]
layout_mode = 0
offset_left = 265.0
offset_top = 125.0
offset_right = 727.0
offset_bottom = 1430.0
theme_override_constants/separation = 45
```

`offset_bottom` is 1430 (= 125 + 1305), the stack's natural end. Leave every `RowAkademik`…`RowLibur` child node exactly as it is.

- [ ] **Step 4: Reposition the back arrow**

Find the `PopupBack` node and replace its offsets:

```
[node name="PopupBack" type="TextureButton" parent="Penjadwalan/TextureRect"]
layout_mode = 0
offset_left = 236.0
offset_top = 1370.0
offset_right = 361.0
offset_bottom = 1495.0
texture_normal = ExtResource("10_return")
ignore_texture_size = true
stretch_mode = 0
```

That is a 125×125 button, up from 96×96 — still comfortably over the 96px touch minimum, and matching the arrow's size in the mockup.

- [ ] **Step 5: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: PASS, 20 tests.

- [ ] **Step 6: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure.

- [ ] **Step 7: Verify it visually against the mockup**

Do not click through the game to reach this state — seed it:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "DebugManager._seed_playtest_state()\nawait get_tree().process_frame\nget_tree().change_scene_to_file(\"res://Scenes/AturJadwal/atur_jadwal.tscn\")\nawait get_tree().process_frame\nawait get_tree().process_frame\nvar s = get_tree().current_scene\nGameState.selected_day = \"Senin\"\nGameState.selected_student = GameState.approved_students[0]\ns._show_penjadwalan_popup()\nawait get_tree().process_frame\nreturn s.penjadwalan_popup_open"})
editor_screenshot(source="game", max_resolution=1080)
```

Capture at `max_resolution=1080`, not lower — at 506px the pill borders and the card's rounded edge alias away and a correct layout can read as a flat rectangle.

Check against the mockup, in this order:
1. Five rows, each a dark near-square icon box then a wider dark pill, with a clear gap between them.
2. Rows inset from the card's left and right edges — card gradient visible on both sides of every row.
3. Each name label right-aligned in the band directly beneath its own pill.
4. The back arrow inside the card's lower-left, fully on the gradient, not on the transparent padding.

Then confirm the numbers survived the layout change:

```
editor_manage(op="game_eval", params={"code":
  "var s = get_tree().current_scene\nvar r = s.get_node(\"Penjadwalan/TextureRect/Rows/RowAkademik\")\nreturn {\"row\": var_to_str(r.size), \"icon\": var_to_str(r.get_node(\"IconBox\").size), \"pill\": var_to_str(r.get_node(\"Pill\").size)}"})
project_manage(op="stop")
```

Expected: `row` is `(462, 200)`, `icon` is `(133, 148)`, `pill` is `(313, 148)`.

- [ ] **Step 8: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd
git commit -m "fix(atur-jadwal): seat the popup rows and back arrow inside the card art"
```

---

## Self-Review

**Spec coverage.** Every row of the "Current vs. Target" table maps to a task. The stylebox fallback is Task 1. Row height, icon-box size, and pill size are Task 2. `Rows` left/right/top, separation, and `PopupBack` are Task 3. Nothing in that table is unaddressed.

**Scope discipline.** The user narrowed this round to layout, excluding icons and colour. No task edits `design_tokens.tres`, recolours art, or changes any fill/border/font colour. Task 1 touches `ThemeFactory.gd`, but only to add a `set_type_variation` binding — the pill's colours are copied forward untouched. It is in scope because the boxes render as Godot's default panel today, so there is no visible box structure to judge the layout against until it is fixed.

**Placeholder scan.** No TBDs. Every geometry number traces to a measured fraction in "Measured Target Geometry" rather than being asserted bare, and both scene edits give the full node block to paste rather than describing the change.

**Type consistency.** `_ROW_HEIGHT` (200) in Task 2's tests matches the `200.0` used in Task 3's `test_the_row_stack_fits_inside_the_card` arithmetic and the `custom_minimum_size = Vector2(200, 200)` in Task 2 Step 3. `_PILL_HEIGHT` (148) matches `offset_bottom = 148.0` on both `IconBox` and `Pill`. `_PILL_LEFT` (149) equals `_ICON_BOX_WIDTH` (133) plus the 16px gap. The `Rows` offsets in Task 3's test match Step 3's node block exactly.

**Two risks worth flagging to the executor.**

Task 1's rebake rewrites `Assets/Theme/kejartes_theme.tres`, which `test_theme_factory` and `test_student_card` also assert against — Step 6's full-suite run is what catches a bad bake; do not skip it. And the editor's resource cache genuinely does serve a stale theme after a game-process rebake on this project; the `CACHE_MODE_REPLACE` escape hatch in Task 1 Step 4 is there because plain `scan()` was confirmed insufficient, so reach for it rather than assuming the rebake failed.

**One deliberate non-change.** `Pill` keeps `StatBar` and `Chips` as sibling children of a `PanelContainer`, which lays both out over the same content rect and gives the intended overlay. That is unusual but working, and the user's earlier instruction — *"it keeps the progress bar, but instead of showing number percentage it shows how many value it added"* — means the bar must stay even though the mockup art shows the pills empty.
