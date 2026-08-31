# Main Menu Mockup Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `Scenes/MainMenu/main_menu.tscn` to the measured geometry of
`docs/superpowers/mockups/main-menu.png` using the project's existing
background, logo and StudentCard button art, and make it the game's boot scene.

**Architecture:** Three flat layers under the scene root — a full-bleed
`TextureRect` background, a full-bleed `TextureRect` logo drawn 1:1 at a
measured offset, and a `SafeAreaMargin` wrapping the button column and version
label. All positioning comes from anchors and offsets copied verbatim from the
spec's measurement table; the current spacer-stretch-ratio layout is deleted.
The buttons get a new `MainMenuButton` variation in `ThemeFactory` that reuses
StudentCard's `trait_button.png` 9-slice at a larger size.

**Tech Stack:** Godot 4.6 (GDScript, `@tool` scripts), the project's baked
`DesignTokens`/`ThemeFactory` theme pipeline, the Godot AI MCP `test_run`
suite runner.

**Spec:** `docs/superpowers/specs/2026-08-31-main-menu-mockup.md` — read it
first. Every geometry number in this plan is a cell in that spec's measurement
table.

## Global Constraints

- Godot **4.6**. Portrait design space **1080x1920**, `canvas_items` stretch,
  aspect `expand`.
- **Never add a `theme_override_*`.** Style only via `ThemeFactory` type
  variations. Only accepted exception: layout-only constant overrides
  (`separation`, `margin_*`). `tests/test_main_menu.gd::
  test_scene_has_no_theme_overrides` enforces this on this scene.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`.
- After ANY edit to `design_tokens.tres` or `ThemeFactory.gd`, **rebake**:
  run `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X) in the
  editor, which rewrites `Assets/Theme/kejartes_theme.tres`.
- **After editing any `.gd`, run `filesystem_manage(op="scan")` before
  `test_run`** or the runner serves a stale autoload.
- Test suites are `@tool`, extend `McpTestSuite`, and **no test may be a
  coroutine** — an `await` silently aborts the test and it scores "0
  assertions" as a false pass.
- Every script needs a `##` file header and a `##` line on every `@export`
  (`tests/test_script_documentation.gd`).
- UI text is **Indonesian**: `MULAI` / `PENGATURAN` / `KELUAR`.
- Button geometry, verbatim from the spec: rect **670x126**, column at
  **x=206, y=1116**, separation **66**, column size **670x510**.
- Logo: `logo.png` at **scale 1.0, offset (0, 68)**.
- Button font size: **80** (see the spec's typography section for why not 100).

---

### Task 1: The `MainMenuButton` theme variation

Reuses StudentCard's `trait_button.png` 9-slice at main-menu scale. A separate
variation is needed rather than reusing `TraitPill` because `TraitPill` sets
`font_size = tokens.font_h2` (48) and a 6 px text outline; the menu needs 80
and no outline.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add to `_build_buttons`, and add
  the new builder function next to `_build_shop_shelf_button`)
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: `DesignTokens` (`font_display`, `text_on_brand`), the existing
  module constant `_CARD_ART`, and `trait_button.png`'s region/margin recipe
  already proven by `TraitPill` in `_build_student_card`.
- Produces: a theme type named `"MainMenuButton"`, variation of `"Button"`,
  with styleboxes `normal`/`hover`/`pressed`/`focus`/`disabled`, colour
  `font_color`, and `font_size` = 80. Task 2 consumes it via
  `theme_type_variation = &"MainMenuButton"`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_theme_factory.gd`:

```gdscript
func test_main_menu_button_variation_exists_and_is_sized_for_the_mockup() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)

	assert_true(theme.has_type("MainMenuButton"),
		"MainMenuButton variation must exist")
	assert_eq(theme.get_type_variation_base("MainMenuButton"), &"Button",
		"MainMenuButton must vary the Button type")

	# The mockup's buttons are trait_button.png recoloured: same 9-slice art.
	var normal := theme.get_stylebox("normal", "MainMenuButton")
	assert_true(normal is StyleBoxTexture,
		"MainMenuButton must draw the trait_button.png 9-slice, not a flat box")

	# Font size 80, not the mockup-implied 100: see the spec's typography
	# section -- PENGATURAN at 100 overflows the 624 px inner box by 131 px.
	assert_eq(theme.get_font_size("font_size", "MainMenuButton"), 80,
		"MainMenuButton font size")
```

- [ ] **Step 2: Run the test to verify it fails**

In the editor, run the theme_factory suite via the MCP `test_run` tool.
Expected: FAIL on `MainMenuButton variation must exist`.

- [ ] **Step 3: Write the implementation**

In `Scripts/Design/ThemeFactory.gd`, add this call at the end of
`_build_buttons`, immediately before the existing
`_build_shop_shelf_button(theme, tokens)` line:

```gdscript
	_build_main_menu_button(theme, tokens)
```

Then add the builder immediately after `_build_shop_shelf_button`'s body:

```gdscript
## The main menu's three nav buttons. Deliberately the SAME art as
## StudentCard's TraitPill (trait_button.png) -- the main-menu mockup's
## buttons are that asset recoloured, so reusing it reproduces the mockup's
## silhouette, 3 px #3D2048 border, corner radius and top gloss exactly.
##
## It cannot simply reuse the TraitPill variation: TraitPill sets font_size to
## tokens.font_h2 (48) with a 6 px outline, sized for a chip. The menu needs
## 80 with no outline (see the plan's spec for the arithmetic -- PENGATURAN at
## the mockup-implied 100 is 755 px wide against a 624 px inner box).
##
## region_rect and texture_margin are copied from TraitPill because they
## describe the ART, not the chip: the pill occupies (20, 277, 601, 91) inside
## the 640x640 canvas, and a 45 px 9-slice margin keeps both rounded ends
## intact when the box is stretched to the menu's 670x126.
static func _build_main_menu_button(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "MainMenuButton"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Button")

	var normal := StyleBoxTexture.new()
	normal.texture = load(_CARD_ART + "trait_button.png")
	normal.region_rect = Rect2(20, 277, 601, 91)
	normal.set_texture_margin_all(45)
	# Horizontal room for the label. 670 - 2*3 px border - 2*20 = 624 px,
	# which PENGATURAN fills to 604 px at font size 80.
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	theme.set_stylebox("normal", NAME, normal)

	# The art carries no separate state variants, so hover/pressed reuse it
	# and the press feedback comes from UIPolish's automatic Juice scale.
	theme.set_stylebox("hover", NAME, normal)
	theme.set_stylebox("pressed", NAME, normal)
	theme.set_stylebox("disabled", NAME, normal)
	theme.set_stylebox("focus", NAME, StyleBoxEmpty.new())

	theme.set_font_size("font_size", NAME, 80)
	theme.set_color("font_color", NAME, tokens.text_on_brand)
	theme.set_color("font_hover_color", NAME, tokens.text_on_brand)
	theme.set_color("font_pressed_color", NAME, tokens.text_on_brand)
	theme.set_color("font_focus_color", NAME, tokens.text_on_brand)
	theme.set_color("font_disabled_color", NAME, tokens.text_on_brand)
	if tokens.font_display != null:
		theme.set_font("font", NAME, tokens.font_display)
```

- [ ] **Step 4: Rescan, rebake, and run the test to verify it passes**

1. MCP `filesystem_manage(op="scan")`.
2. In the editor open `Scripts/Design/BakeTheme.gd` and File > Run
   (Ctrl+Shift+X). Expected console line:
   `BakeTheme: wrote res://Assets/Theme/kejartes_theme.tres (N types)`.
3. MCP `test_run` on the theme_factory suite.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd && git commit -m "feat(theme): add MainMenuButton variation reusing the trait_button art"
```

---

### Task 2: The label-fits-the-button guard

The single most load-bearing constraint on this screen, and the one a future
copy change would silently break. Written before the scene so the scene is
built against a proven number.

**Files:**
- Test: `tests/test_main_menu.gd` (append)

**Interfaces:**
- Consumes: the `MainMenuButton` theme type from Task 1, and the suite's
  existing `_THEME_PATH` constant and `_menu` member.
- Produces: nothing consumed downstream; a regression guard only.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_main_menu.gd`:

```gdscript
## The mockup's cap height implies font size 100, but Milker sets
## "PENGATURAN" 755 px wide at 100 against a 624 px inner box. This asserts
## the compromise (80) actually holds, so a future copy or size change cannot
## silently clip the longest label. Inner box = the button's 670 px width
## minus the art's 3 px border each side minus 20 px content margin each side.
const _BUTTON_WIDTH := 670.0
const _BUTTON_INNER_WIDTH := 670.0 - 2.0 * 3.0 - 2.0 * 20.0


func test_every_label_fits_inside_the_button_at_the_baked_font_size() -> void:
	var theme: Theme = load(_THEME_PATH)
	var font := theme.get_font("font", "MainMenuButton")
	var font_size := theme.get_font_size("font_size", "MainMenuButton")
	assert_true(font != null, "MainMenuButton must have a font")

	for label in ["MULAI", "PENGATURAN", "KELUAR"]:
		var w := font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		assert_true(w <= _BUTTON_INNER_WIDTH,
			"%s renders %d px wide, over the %d px inner box"
				% [label, int(w), int(_BUTTON_INNER_WIDTH)])
```

- [ ] **Step 2: Run the test to verify it passes**

Run the `main_menu` suite via MCP `test_run`.

Expected: PASS — Task 1 already baked font size 80, at which `PENGATURAN`
measures ~604 px against the 624 px box. If it FAILS, do not raise the box;
lower the font size in `_build_main_menu_button` and rebake, then record the
new number in the spec's typography section.

- [ ] **Step 3: Commit**

```bash
git add tests/test_main_menu.gd && git commit -m "test(main-menu): guard that every label fits its button at the baked size"
```

---

### Task 3: Scene geometry tests

Written before the scene is rebuilt, so the rebuild is verified rather than
eyeballed. These read `anchor_*` / `offset_*` / `custom_minimum_size`, which
are populated directly from the `.tscn` at instantiation — unlike `.size`,
which needs a `Container` sort pass the synchronous test runner never flushes.

Coordinates are expressed in `SafeArea`-local space. On the reference device
`SafeAreaMargin` contributes only `screen_margin` (48 px) on each side, so
`SafeArea`'s content rect is (48, 48)..(1032, 1872), i.e. 984x1824. The
mockup's column at y=1116..1626 is therefore at local y=1068..1578, which is
`1824 - 1578 = 246` px up from the bottom. Anchoring to the bottom (rather
than the top) is deliberate: it keeps the buttons a fixed distance from the
thumb on taller screens, and lets the logo above absorb the extra height.

**Files:**
- Test: `tests/test_main_menu.gd` (append)

**Interfaces:**
- Consumes: the node names Task 4 creates — `Background`, `Logo`,
  `SafeArea/Content/ButtonColumn`, and the three buttons under `ButtonColumn`.
- Produces: nothing consumed downstream.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_main_menu.gd`:

```gdscript
## Measured from docs/superpowers/mockups/main-menu.png; see
## docs/superpowers/specs/2026-08-31-main-menu-mockup.md for the probe trail.
## The mockup's own button pitch drifts (gaps of 69 and 64 px); 66 is the
## normalisation that lands the column's bottom edge on the measured 1626.
const _BUTTON_HEIGHT := 126
const _BUTTON_SEPARATION := 66
const _COLUMN_HEIGHT := 3 * _BUTTON_HEIGHT + 2 * _BUTTON_SEPARATION  # 510
const _COLUMN_BOTTOM_INSET := 246.0
const _LOGO_TOP_OFFSET := 68.0


func test_background_uses_the_titlescreen_art() -> void:
	var bg := _menu.find_child("Background", true, false) as TextureRect
	assert_true(bg != null, "Background node must exist")
	assert_eq(bg.texture.resource_path,
		"res://Assets/Images/UI/titlescreen_background.png",
		"background art")


func test_logo_sits_at_the_measured_offset() -> void:
	var logo := _menu.find_child("Logo", true, false) as TextureRect
	assert_true(logo != null, "Logo node must exist")
	assert_eq(logo.texture.resource_path, "res://Assets/Images/UI/logo.png",
		"logo art")
	# Correlating logo.png against the mockup put the optimum at scale 1.0,
	# offset (0, 68) with a sharp 1-px minimum.
	assert_eq(logo.offset_top, _LOGO_TOP_OFFSET, "logo top offset")
	assert_eq(logo.offset_bottom, _LOGO_TOP_OFFSET + 1080.0,
		"logo must be drawn at its native 1080 px height, unscaled")


func test_button_column_matches_the_mockup_rect() -> void:
	var col := _menu.find_child("ButtonColumn", true, false) as VBoxContainer
	assert_true(col != null, "ButtonColumn must exist and be a VBoxContainer")

	# Horizontally centred, 670 wide.
	assert_eq(col.anchor_left, 0.5, "column left anchor")
	assert_eq(col.anchor_right, 0.5, "column right anchor")
	assert_eq(col.offset_right - col.offset_left, _BUTTON_WIDTH,
		"column width")

	# Pinned to the bottom of the safe area, 510 tall.
	assert_eq(col.anchor_top, 1.0, "column top anchor")
	assert_eq(col.anchor_bottom, 1.0, "column bottom anchor")
	assert_eq(col.offset_bottom, -_COLUMN_BOTTOM_INSET, "column bottom inset")
	assert_eq(col.offset_bottom - col.offset_top, float(_COLUMN_HEIGHT),
		"column height")

	assert_eq(col.get_theme_constant("separation"), _BUTTON_SEPARATION,
		"button separation")


func test_each_button_is_the_measured_height_and_uses_the_menu_variation() -> void:
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as Button
		assert_eq(b.custom_minimum_size.y, float(_BUTTON_HEIGHT),
			name + " height")
		assert_eq(b.theme_type_variation, &"MainMenuButton",
			name + " must use the MainMenuButton variation")


func test_the_subtitle_is_gone() -> void:
	# The mockup shows only the logo and three buttons.
	assert_true(_menu.find_child("SubtitleLabel", true, false) == null,
		"SubtitleLabel must be removed")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the `main_menu` suite via MCP `test_run`.

Expected: FAIL — `Background node must exist` still finds the old `BG.jpg`
texture, `Logo node must exist` fails outright, and
`test_buttons_use_theme_variations_not_default_styling` (the pre-existing
test) still expects `PrimaryButton`.

- [ ] **Step 3: Update the one pre-existing test the redesign invalidates**

In `tests/test_main_menu.gd`, replace the body of
`test_buttons_use_theme_variations_not_default_styling` with:

```gdscript
func test_buttons_use_theme_variations_not_default_styling() -> void:
	# All three menu buttons now share one variation: the mockup draws them
	# identically, with no primary/secondary distinction.
	for name in ["PlayButton", "SettingButton", "QuitButton"]:
		var b := _menu.find_child(name, true, false) as Button
		assert_eq(b.theme_type_variation, &"MainMenuButton",
			name + " must use the MainMenuButton variation")
```

Leave `test_scene_has_no_theme_overrides`,
`test_content_is_wrapped_in_a_safe_area`,
`test_all_three_buttons_exist_and_are_wired`,
`test_buttons_meet_the_minimum_touch_target`,
`test_button_labels_are_indonesian` and
`test_layout_uses_containers_not_absolute_offsets` **unchanged** — the rebuild
must keep all six green.

- [ ] **Step 4: Commit the tests**

```bash
git add tests/test_main_menu.gd && git commit -m "test(main-menu): assert the mockup's measured geometry"
```

---

### Task 4: Rebuild the scene and script

**Files:**
- Modify: `Scenes/MainMenu/main_menu.tscn` (full rewrite)
- Modify: `Scripts/MainMenu/main_menu.gd:32-77` (drop the subtitle wiring)

**Interfaces:**
- Consumes: `MainMenuButton` from Task 1; `SafeAreaMargin`
  (`Scripts/UI/SafeAreaMargin.gd`); the node names Task 3's tests assert.
- Produces: node paths `SafeArea/Content/ButtonColumn/{PlayButton,
  SettingButton,QuitButton}` and `SafeArea/Content/VersionLabel`, which
  `main_menu.gd`'s `@onready` vars bind to.

- [ ] **Step 1: Replace the scene file**

Write `Scenes/MainMenu/main_menu.tscn` in full:

```
[gd_scene load_steps=5 format=3 uid="uid://b2vxniec67375"]

[ext_resource type="Script" path="res://Scripts/MainMenu/main_menu.gd" id="1_ftydy"]
[ext_resource type="Script" path="res://Scripts/UI/SafeAreaMargin.gd" id="2_safe"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/titlescreen_background.png" id="3_bg"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/logo.png" id="4_logo"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_ftydy")

[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("3_bg")
expand_mode = 1
stretch_mode = 6

[node name="Logo" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = -1
anchor_right = 1.0
offset_top = 68.0
offset_bottom = 1148.0
grow_horizontal = 2
texture = ExtResource("4_logo")
expand_mode = 1
stretch_mode = 5
mouse_filter = 2

[node name="SafeArea" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("2_safe")

[node name="Content" type="Control" parent="SafeArea"]
layout_mode = 2
mouse_filter = 2

[node name="ButtonColumn" type="VBoxContainer" parent="SafeArea/Content"]
layout_mode = 1
anchors_preset = -1
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -335.0
offset_top = -756.0
offset_right = 335.0
offset_bottom = -246.0
grow_horizontal = 2
grow_vertical = 0
theme_override_constants/separation = 66

[node name="PlayButton" type="Button" parent="SafeArea/Content/ButtonColumn"]
layout_mode = 2
custom_minimum_size = Vector2(0, 126)
theme_type_variation = &"MainMenuButton"
text = "MULAI"

[node name="SettingButton" type="Button" parent="SafeArea/Content/ButtonColumn"]
layout_mode = 2
custom_minimum_size = Vector2(0, 126)
theme_type_variation = &"MainMenuButton"
text = "PENGATURAN"

[node name="QuitButton" type="Button" parent="SafeArea/Content/ButtonColumn"]
layout_mode = 2
custom_minimum_size = Vector2(0, 126)
theme_type_variation = &"MainMenuButton"
text = "KELUAR"

[node name="VersionLabel" type="Label" parent="SafeArea/Content"]
layout_mode = 1
anchors_preset = -1
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -200.0
offset_top = -48.0
offset_right = 200.0
grow_horizontal = 2
grow_vertical = 0
theme_type_variation = &"MicroLabel"
text = "v0.1"
horizontal_alignment = 1
mouse_filter = 2
```

Three things in there that are load-bearing and easy to get wrong:

- `theme_override_constants/separation = 66` on `ButtonColumn` is the **one
  allowed override kind** — layout-only spacing. `test_scene_has_no_theme_
  overrides` deliberately scans only colours, font sizes and styleboxes, so
  this passes. Do not reach for any other override.
- `Logo` is a **sibling of `SafeArea`, not a child.** It is full-bleed 1080-wide
  art, like the background; pushing it inside the safe area would shift it off
  the measured (0, 68) and break the correlation. Its own art bbox starts at
  x=156, so it can never collide with a notch.
- `mouse_filter = 2` (IGNORE) on `Logo`, `SafeArea`, `Content` and
  `VersionLabel` keeps them from eating touches aimed at the buttons.
  `ButtonColumn` and the buttons keep the default.

- [ ] **Step 2: Drop the subtitle from the script**

In `Scripts/MainMenu/main_menu.gd`, delete the `_subtitle` `@onready` line and
update the remaining paths for the new `Content` level. Replace the
`@onready` block with:

```gdscript
@onready var _buttons: VBoxContainer = $SafeArea/Content/ButtonColumn
@onready var _play_button: Button = $SafeArea/Content/ButtonColumn/PlayButton
@onready var _setting_button: Button = $SafeArea/Content/ButtonColumn/SettingButton
@onready var _quit_button: Button = $SafeArea/Content/ButtonColumn/QuitButton
@onready var _version: Label = $SafeArea/Content/VersionLabel
```

Note `_title` goes too — the `TitleLabel` node is gone, replaced by the logo
art. Then replace `_animate_entry` with:

```gdscript
## The logo is static art, so the entry animation is now only the button
## cascade -- there is no longer a title Label or subtitle to fade in.
func _animate_entry() -> void:
	var items: Array = []
	for child in _buttons.get_children():
		items.append(child)
	await get_tree().create_timer(Juice.tokens().dur_normal).timeout
	Juice.stagger_in(items)
```

- [ ] **Step 3: Rescan and run the full suite**

1. MCP `filesystem_manage(op="scan")`.
2. MCP `test_run` across all suites.

Expected: PASS, including all six untouched pre-existing `main_menu` tests
(`test_scene_has_no_theme_overrides`, `test_content_is_wrapped_in_a_safe_area`,
`test_all_three_buttons_exist_and_are_wired`,
`test_buttons_meet_the_minimum_touch_target` — 126 px clears the 96 px
`touch_target_min` — `test_button_labels_are_indonesian`, and
`test_layout_uses_containers_not_absolute_offsets`).

- [ ] **Step 4: Verify against the mockup, do not eyeball it**

Reading the code you just wrote is not verification. Open the scene, run the
game, and diff the render against the reference:

1. MCP `scene_open` on `res://Scenes/MainMenu/main_menu.tscn`, then
   `project_run`, then `editor_screenshot`.
2. For each row of the spec's measurement table, query the live node's
   resolved rect via MCP
   `game_manage(op="get_ui_elements", params={"root_path":
   "/root/MainMenu/SafeArea/Content", "max_depth": 3})` and compare
   `global_rect` against the table, number by number.

Expected: `ButtonColumn` global rect x=205..206, y=1116, 670x510, and each
button 670x126. A discrepancy means the anchors are wrong — fix the scene,
not the table.

- [ ] **Step 5: Commit**

```bash
git add Scenes/MainMenu/main_menu.tscn Scripts/MainMenu/main_menu.gd && git commit -m "feat(main-menu): rebuild the screen to the mockup's measured geometry"
```

---

### Task 5: Make the main menu the boot scene

**Files:**
- Modify: `project.godot:14`
- Modify: `CLAUDE.md` (the "The game" loop line, and "Current work")
- Test: `tests/test_project_hygiene.gd`

**Interfaces:**
- Consumes: `res://Scenes/MainMenu/main_menu.tscn` from Task 4.
- Produces: nothing consumed downstream.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_project_hygiene.gd`:

```gdscript
## The boot scene moved off Splashscreen on 2026-08-31. Splashscreen.tscn and
## Loading.tscn still exist and are still covered by test_boot_screens.gd;
## they are simply no longer reached at startup. Pinned here because nothing
## else in the suite asserts run/main_scene, so a stray edit would go unseen.
func test_the_boot_scene_is_the_main_menu() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(main_scene, "res://Scenes/MainMenu/main_menu.tscn",
		"run/main_scene")
	assert_true(ResourceLoader.exists(main_scene),
		"the boot scene must actually exist")
```

- [ ] **Step 2: Run the test to verify it fails**

Run the `project_hygiene` suite via MCP `test_run`.

Expected: FAIL with the setting still reading
`res://Scenes/Splashscreen/Splashscreen.tscn`.

- [ ] **Step 3: Change the setting**

In `project.godot`, line 14:

```
run/main_scene="res://Scenes/MainMenu/main_menu.tscn"
```

- [ ] **Step 4: Run the full suite to verify it passes**

MCP `test_run` across all suites.

Expected: PASS. In particular `tests/test_boot_screens.gd` and
`tests/test_audio_coverage.gd` stay green — the first loads both boot scenes
by explicit path and does not care what boots, and the second's assertion is a
source-text scan of the untouched `Scripts/Splashscreen/splashscreen.gd`.

- [ ] **Step 5: Launch the game and confirm it boots into the menu**

MCP `project_run`, then `editor_screenshot`.

Expected: the main menu renders immediately with no splash, the `titlescreen`
BGM plays (started by `main_menu.gd`'s own `_ready`, not Splashscreen's), and
the three buttons stagger in.

- [ ] **Step 6: Update CLAUDE.md**

In the "The game" section, change the loop line to read:

```
**Loop:** **MainMenu (boot)** → CutScene → StudentCard (approve roster) →
**Lobby (hub)** → AturJadwal (assign week) → StudentList → SchoolDay
(simulate 5 days) → ResultCheckup → back to Lobby, or SemesterEnd on the final
week. Splashscreen and Loading still exist and are still tested, but since
2026-08-31 they are no longer reached at boot.
```

In "Current work", replace the first paragraph with:

```
Branch `Textures` (this is also the main branch).

The main menu was rebuilt on 2026-08-31 to match
`docs/superpowers/mockups/main-menu.png` measurement-for-measurement and is
now the boot scene — see
`docs/superpowers/specs/2026-08-31-main-menu-mockup.md` for the probe trail
and the two documented deviations (uniform 66 px button separation, and font
size 80 rather than the mockup-implied 100 so "PENGATURAN" fits).
```

- [ ] **Step 7: Commit**

```bash
git add project.godot tests/test_project_hygiene.gd CLAUDE.md docs/superpowers/specs/2026-08-31-main-menu-mockup.md docs/superpowers/mockups/main-menu.png && git commit -m "feat(boot): boot straight into the main menu"
```

---

## Self-review notes

- **Spec coverage.** Background (Task 4 Step 1), logo placement (Task 4 Step 1,
  asserted Task 3), button art (Task 1), button geometry (Task 4, asserted
  Task 3), spacing normalisation (Task 3's `_BUTTON_SEPARATION`), typography
  constraint (Task 2), subtitle removal (Task 3 + Task 4 Step 2), version
  label (Task 4 Step 1), boot scene (Task 5). The two decisions that produce
  no code — shipping the button gold and the background ungraded — are
  recorded in the spec and are why no shader task exists.
- **Naming consistency.** `MainMenuButton` is spelled identically in Tasks 1,
  2, 3 and 4. Node names `Background` / `Logo` / `Content` / `ButtonColumn` /
  `VersionLabel` are asserted in Task 3 exactly as Task 4 creates them.
  `_BUTTON_WIDTH` is defined once, in Task 2, and reused in Task 3 — Task 3
  must be appended to the same file, after Task 2's block.
- **Known risk.** Task 4's scene is hand-written `.tscn` text. If Godot
  rejects any property (most likely `anchors_preset = -1` combined with
  explicit anchors), open the scene in the editor and set the same values in
  the Inspector instead; the numbers, not the file syntax, are what matter.
