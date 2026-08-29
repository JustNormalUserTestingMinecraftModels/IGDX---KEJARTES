# Penjadwalan Mockup-Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Penjadwalan popup match the supplied mockup: one bordered container per row with the icon on its grey and a darker pill inset to the right, on an un-stretched square card.

**Architecture:** Three changes, each independently testable. First the theme gains the surfaces the mockup needs (a bordered row container, a retuned inset pill, a flat variant, a bigger outlined label). Then `ActivityRow` is rebuilt from two detached boxes into one container holding icon + inset pill, and the `StatBar`'s collapsed size flag is fixed. Finally the card's `TextureRect` is made square — it is a 1080×1080 texture currently stretched into a 988×1600 rect — and the rows and back arrow are re-seated against the resulting card box.

**Tech Stack:** Godot 4.6, GDScript. `ThemeFactory` design-token pipeline, `StatBar` (`Scripts/UI/StatBar.gd`), `McpTestSuite` test runner.

**Spec:** No separate spec document. This plan implements a user-supplied mockup (`C:\Users\ASUS\Downloads\penjadwalan.png`, 1080×1080), measured by pixel scanline in the "Measured Target Geometry" section below. That section is the spec.

## Global Constraints

- **Labels stay Milker ALL CAPS.** The user chose this explicitly after being shown that Milker has no lowercase glyphs (rendering "Akademik abc" through the font produces "AKADEMIK ABC"). The mockup's Title Case is unreachable without changing typeface; do **not** swap fonts. Match the mockup's label *weight* by sizing up and thickening the outline instead.
- **Colours are in scope this round.** The user reversed the previous round's "layout only" restriction. Every colour below is sampled from the mockup, not invented — use the exact hex values given.
- **Never add a `theme_override_*`** on a scene node. Use a `ThemeFactory` type variation. Only accepted exception: layout-only constant overrides (`separation`, `margin_*`).
- Every interactive control must clear `tokens.touch_target_min` (96px) — `tests/test_atur_jadwal.gd::test_interactive_controls_meet_the_minimum_touch_target` enforces this on all five rows and `PopupBack`.
- Test suites must be `@tool` and **no test may be a coroutine** (the runner calls `suite.call(name)` without awaiting; an `await` silently aborts the test and it reports "0 assertions").
- A test whose only assertions are inside a loop that may not execute reports "0 assertions" and **fails**. Collect into a list and assert once after the loop.
- Run `filesystem_manage(op="scan")` after editing any `.gd` and before `test_run`.
- Rebaking writes `Assets/Theme/kejartes_theme.tres`, which `test_theme_factory`, `test_student_card`, and `test_activity_row` all assert against. Always follow a rebake with a full-suite run.

## Measured Target Geometry

All measurements are from pixel scanlines across the mockup (1080×1080). Its card content occupies **x 211–868 (657 wide), y 34–1046 (1012 tall)**; the rest is transparent padding.

### What the scanlines showed

Horizontal scan across row 1 at y=135:

| x range | Content |
|---|---|
| 211–214 | Card's own purple border `#3D2048` |
| 288–290 | **Row container** purple border `#3D2048` |
| 291–452 | Row container grey `#696969`→`#5C5C5C`, **icon glyph sits directly on it** |
| 453–457 | Inset pill's dark edge `#2B2B2B` |
| 458–775 | **Inset pill** fill `#363636`, number drawn on top |
| 789–791 | Row container border again |

There is **no separate icon box**. The icon's apparent "box" is the container's left region, bounded on the right by the inset pill's edge. Rows 4–5 (Wirausaha, Libur) have the same container but **no inset pill** — their chips sit directly on the grey.

Vertical scans gave row container tops at y = 79, 246, 427, 599, 766 (pitch 167/181/172/167, mean **172**), container height **110**, inset pill y 99–171 (**72** tall), and the name label spanning y≈172–217 — i.e. the label **overlaps the container's bottom edge** and hangs ~28px below it.

### Colours (sampled, do not substitute)

| Role | Hex |
|---|---|
| Row container fill | `#626262` (mockup gradients `#696969`→`#5C5C5C`; `StyleBoxFlat` has no gradient, so use the midpoint) |
| Row container border | `#3D2048` |
| Inset pill fill | `#363636` |
| Icon / text glyph purple | `#3D1E48` (visually identical to the border purple; reuse `#3D2048` rather than adding a token) |

### Conversion into the scene

The `TextureRect` becomes **988×988** (Task 3). The 1080×1080 texture then maps its card content to local **x 193–794 (601 wide), y 31–957 (926 tall)**.

| Mockup fraction | Value | → Scene |
|---|---|---|
| Row block left/right inset | 0.1172 of card width | **263** / **724** (width **461**) |
| Row 1 top | 0.0445 of card height | **72** |
| Row container height | 0.1087 | **101** |
| Row pitch | 0.1700 | **157** |
| Label overhang below container | 0.0277 | **26** |
| `ActivityRow` total height | 101 + 26 | **127** |
| VBox separation | 157 − 127 | **30** |
| Icon region width | 0.3280 of row width | **151** |
| Pill right inset | 0.0318 of row width | **15** |
| Pill vertical inset | 0.1818 of container height | **18** (pill **295×65**) |
| Back arrow centre y | 0.9199 of card height | centre **883** → top **821** |
| Back arrow left / size | 0.0715 / 0.2085 of card width | **236**, **125×125** |

Stack check: `72 + 5×127 + 4×30 = 827`, inside the 926-tall card. Back arrow 821→946, also inside. ✅

## Current vs Target

| Property | Current | Target |
|---|---|---|
| `TextureRect` size | 988 × **1600** (card stretched to aspect 0.40) | 988 × **988** (card at its designed 0.65) |
| Row structure | Two detached boxes, card showing through the gap | One bordered container; icon on its grey, pill inset right |
| Row container | *(none)* | `#626262` fill, `#3D2048` border |
| Pill fill | `#141a2e` (near-black) | `#363636` |
| Rows 4–5 | One dark pill | Container with **no** inset pill |
| `StatBar` size | **281 × 1 px** — `size_flags_vertical = 0` (`SHRINK_BEGIN`) with min size (1,1), so it collapses to a hairline | Fills the pill (`SIZE_FILL`, verified live: 281 × 132) |
| Label | `CardSectionLabel`, 36px, outline 4 | New variation, 48px, outline 6 |
| `Rows` container | 265/125/727/1305, sep 45 | 263/72/724/827, sep **30** |
| `PopupBack` | 125×125 at (236, 1370) | 125×125 at (236, **821**) |

## File Structure

- **Modify** `Scripts/Design/DesignTokens.gd` — three new colour tokens in their own export group.
- **Modify** `Assets/Theme/design_tokens.tres` — no edit needed; the new `@export`s take their declared defaults.
- **Modify** `Scripts/Design/ThemeFactory.gd` — add `PreviewRow`, `PreviewPillFlat`, `PreviewRowLabel`; retune `PreviewPill`.
- **Modify** `Assets/Theme/kejartes_theme.tres` — regenerated by rebake, never hand-edited.
- **Modify** `Scenes/AturJadwal/ActivityRow.tscn` — rebuilt around one container.
- **Modify** `Scripts/AturJadwal/ActivityRow.gd` — `has_progress_bar` → `is_skill_row`, driving both the bar and the pill's flatness.
- **Modify** `Scenes/AturJadwal/atur_jadwal.tscn` — square `TextureRect`, re-seated `Rows` and `PopupBack`, two renamed instance properties.
- **Modify** `tests/test_activity_row.gd`, `tests/test_atur_jadwal.gd`.

---

### Task 1: Theme surfaces for the mockup's rows

Adds the three variations the new row structure needs and retunes the pill to the sampled colour. Nothing looks different yet — `ActivityRow` does not consume these until Task 2 — but the theme is independently verifiable.

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (after the `Layout` group, before `category_color()`)
- Modify: `Scripts/Design/ThemeFactory.gd` (the `PreviewPill` block, currently lines 322–341)
- Modify: `Assets/Theme/kejartes_theme.tres` (via rebake)
- Test: `tests/test_activity_row.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces, for Tasks 2 and 3:
  - `DesignTokens.preview_row_fill: Color` = `#626262`
  - `DesignTokens.preview_row_border: Color` = `#3d2048`
  - `DesignTokens.preview_pill_fill: Color` = `#363636`
  - Theme variation `PreviewRow` (base type **`Panel`**) — bordered grey row container
  - Theme variation `PreviewPillFlat` (base type `PanelContainer`) — `StyleBoxEmpty`, for rows with no inset pill
  - Theme variation `PreviewRowLabel` (base type `Label`) — 48px, white, 6px dark outline
  - `PreviewPill` keeps base type `PanelContainer`; only its fill and radius change

- [ ] **Step 1: Write the failing test**

Append to `tests/test_activity_row.gd`:

```gdscript
## The mockup's rows are one bordered grey container with a darker pill inset
## into it. These pin the four surfaces that produces, including base_type --
## a variation without one silently falls back to the engine default, which is
## exactly the bug that made the pills invisible before.
func test_preview_row_is_a_bordered_panel() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewRow"), &"Panel",
		"PreviewRow must declare Panel as its base_type")
	var sb := theme.get_stylebox("panel", "PreviewRow") as StyleBoxFlat
	assert_true(sb != null, "PreviewRow/panel must be a StyleBoxFlat")
	assert_eq(sb.bg_color, tokens.preview_row_fill, "row container fill comes from the token")
	assert_eq(sb.border_color, tokens.preview_row_border, "row container border comes from the token")
	assert_true(sb.border_width_top >= 1, "the mockup's rows carry a visible purple border")


func test_preview_pill_uses_the_sampled_fill() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = load(_THEME_PATH)
	var sb := theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_true(sb != null, "PreviewPill/panel must be a StyleBoxFlat")
	assert_eq(sb.bg_color, tokens.preview_pill_fill,
		"the inset pill is #363636 in the mockup, not the old near-black surface_overlay")


## Wirausaha and Libur have no inset pill -- their chips sit straight on the
## container's grey. They wear this variation so the code path stays single.
func test_preview_pill_flat_draws_nothing() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewPillFlat"), &"PanelContainer",
		"PreviewPillFlat must declare PanelContainer as its base_type")
	assert_true(theme.get_stylebox("panel", "PreviewPillFlat") is StyleBoxEmpty,
		"PreviewPillFlat must draw no panel at all")


func test_preview_row_label_is_big_and_outlined() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewRowLabel"), &"Label",
		"PreviewRowLabel must declare Label as its base_type")
	assert_eq(theme.get_font_size("font_size", "PreviewRowLabel"), tokens.font_h2,
		"the mockup's row labels are noticeably larger than CardSectionLabel's 36px")
	assert_eq(theme.get_color("font_color", "PreviewRowLabel"), tokens.text_on_brand,
		"row labels are white")
	assert_eq(theme.get_color("font_outline_color", "PreviewRowLabel"), tokens.preview_row_border,
		"the label's dark rim is the same purple as the row border")
	assert_true(theme.get_constant("outline_size", "PreviewRowLabel") >= 6,
		"the mockup's label rim is chunkier than CardSectionLabel's 4px")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: FAIL — `preview_row_fill` does not exist on `DesignTokens`, and none of the three new variations are in the theme.

- [ ] **Step 3: Add the colour tokens**

In `Scripts/Design/DesignTokens.gd`, insert directly after the `Layout` group's `screen_margin` line and before `func category_color(...)`:

```gdscript
@export_group("Penjadwalan Preview")
## Sampled from the mockup (docs: 2026-08-29-penjadwalan-mockup-match.md).
## The row container is a grey slab with a purple rim; the pill inset into
## it is darker. The mockup fills the container with a subtle vertical
## gradient (#696969 -> #5C5C5C); StyleBoxFlat has no gradient, so this is
## the midpoint.
@export var preview_row_fill: Color = Color("626262")
@export var preview_row_border: Color = Color("3d2048")
@export var preview_pill_fill: Color = Color("363636")
```

`Assets/Theme/design_tokens.tres` needs no edit — it only stores the two font overrides, so every other property takes the default declared here.

- [ ] **Step 4: Add and retune the theme variations**

In `Scripts/Design/ThemeFactory.gd`, replace the entire `PreviewPill` / `PreviewChipLabel` block (currently lines 322–341) with:

```gdscript
	# -- Penjadwalan row container: the bordered grey slab each row sits on.
	# The icon draws directly onto this; the pill below is inset into it. --
	var preview_row := StyleBoxFlat.new()
	preview_row.bg_color = tokens.preview_row_fill
	preview_row.border_color = tokens.preview_row_border
	preview_row.set_border_width_all(4)
	preview_row.set_corner_radius_all(tokens.radius_md)
	theme.add_type("PreviewRow")
	theme.set_type_variation("PreviewRow", "Panel")
	theme.set_stylebox("panel", "PreviewRow", preview_row)

	# -- The darker pill inset into the row, carrying the numbers. --
	var preview_pill := StyleBoxFlat.new()
	preview_pill.bg_color = tokens.preview_pill_fill
	preview_pill.set_corner_radius_all(tokens.radius_sm)
	preview_pill.content_margin_left = tokens.space_sm
	preview_pill.content_margin_right = tokens.space_sm
	preview_pill.content_margin_top = tokens.space_xs
	preview_pill.content_margin_bottom = tokens.space_xs
	theme.add_type("PreviewPill")
	theme.set_type_variation("PreviewPill", "PanelContainer")
	theme.set_stylebox("panel", "PreviewPill", preview_pill)

	# -- Wirausaha and Libur have no target, so no inset pill: their chips
	# sit straight on the container's grey. Same node, no panel drawn. --
	theme.add_type("PreviewPillFlat")
	theme.set_type_variation("PreviewPillFlat", "PanelContainer")
	theme.set_stylebox("panel", "PreviewPillFlat", StyleBoxEmpty.new())

	# -- The numbers inside that pill: white on the dark slab. --
	theme.add_type("PreviewChipLabel")
	theme.set_type_variation("PreviewChipLabel", "Label")
	theme.set_font_size("font_size", "PreviewChipLabel", tokens.font_h2)
	theme.set_color("font_color", "PreviewChipLabel", tokens.text_on_brand)

	# -- The category name under each row. Bigger and rimmed harder than
	# CardSectionLabel, which is shared with StudentCard and must not move. --
	theme.add_type("PreviewRowLabel")
	theme.set_type_variation("PreviewRowLabel", "Label")
	theme.set_font_size("font_size", "PreviewRowLabel", tokens.font_h2)
	theme.set_color("font_color", "PreviewRowLabel", tokens.text_on_brand)
	theme.set_constant("outline_size", "PreviewRowLabel", 6)
	theme.set_color("font_outline_color", "PreviewRowLabel", tokens.preview_row_border)
	if tokens.font_display != null:
		theme.set_font("font", "PreviewRowLabel", tokens.font_display)
```

- [ ] **Step 5: Rebake the theme**

`BakeTheme.gd` is an `EditorScript` (File > Run), unreachable over MCP. Run the same lines through a live game instead:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "var t = DesignTokens.load_default()\nvar th = ThemeFactory.build(t)\nreturn ResourceSaver.save(th, \"res://Assets/Theme/kejartes_theme.tres\")"})
project_manage(op="stop")
filesystem_manage(op="scan")
```

Expected: `game_eval` returns `0` (`OK`), and `kejartes_theme.tres` gains `PreviewRow/base_type`, `PreviewPillFlat/base_type`, and `PreviewRowLabel/base_type` lines.

**Editor cache caveat — this bites on this exact file.** The rebake runs in the *game* process; the editor's test runner keeps its own cached copy and will keep serving the stale one through `scan()`, `reimport()`, and even a plugin reload. If Step 6 fails while `grep PreviewRow Assets/Theme/kejartes_theme.tres` shows the file is correct on disk, force a cache replace from inside the editor process: temporarily add this as the first line of one failing test, run once, then remove it.

```gdscript
	ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
```

One run is enough — it updates the shared cache in place, and the clean test passes afterwards.

- [ ] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: PASS, 20 tests.

- [ ] **Step 7: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director::test_volumes_persist_across_a_fresh_director` coroutine failure (CLAUDE.md Known Issues #1). Watch `theme_factory` and `student_card` — they assert against the file just rewritten.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Scripts/Design/ThemeFactory.gd \
        Assets/Theme/kejartes_theme.tres tests/test_activity_row.gd
git commit -m "feat(theme): add the Penjadwalan row container, flat pill, and row label"
```

---

### Task 2: Rebuild ActivityRow around one container

Replaces the two detached boxes with the mockup's single bordered container, and fixes the `StatBar`'s collapsed size flag.

**Files:**
- Modify: `Scenes/AturJadwal/ActivityRow.tscn` (full replacement)
- Modify: `Scripts/AturJadwal/ActivityRow.gd`
- Test: `tests/test_activity_row.gd`

**Interfaces:**
- Consumes: `PreviewRow`, `PreviewPill`, `PreviewPillFlat`, `PreviewRowLabel` from Task 1.
- Produces, for Task 3:
  - `ActivityRow` node paths become `Container`, `Container/Icon`, `Container/Pill`, `Container/Pill/StatBar`, `Container/Pill/Chips`, `NameLabel`. **`IconBox` no longer exists.**
  - `@export var is_skill_row: bool = true` **replaces** `has_progress_bar`. It drives both the `StatBar` and whether the pill draws its panel.
  - `ActivityRow.refresh(student: Dictionary, grade: int, progress_percent: float) -> void` — unchanged signature.
  - Row is **127px** tall (`custom_minimum_size = Vector2(200, 127)`); Task 3's stack arithmetic depends on 127.

- [ ] **Step 1: Write the failing test**

In `tests/test_activity_row.gd`, **replace** the four geometry tests added in the previous plan — `test_row_is_a_fixed_height_band`, `test_icon_box_is_the_mockup_square`, `test_pill_starts_after_the_icon_gap_and_matches_its_height`, `test_name_label_sits_in_the_band_below_the_pill` — and their four constants (`_ROW_HEIGHT`, `_PILL_HEIGHT`, `_ICON_BOX_WIDTH`, `_PILL_LEFT`) with:

```gdscript
## Geometry pinned to the mockup's scanlines. Each row is ONE bordered
## container 101px tall; the icon draws on its grey and a darker pill is
## inset to the right. The name label overlaps the container's bottom edge
## and hangs into the 26px band beneath, which is why the row is 127 total.
const _ROW_HEIGHT := 127.0
const _CONTAINER_HEIGHT := 101.0
const _ICON_REGION := 151.0
const _PILL_RIGHT_INSET := 15.0
const _PILL_V_INSET := 18.0


func test_row_is_a_fixed_height_band() -> void:
	assert_eq(_row.custom_minimum_size.y, _ROW_HEIGHT,
		"the row's height is fixed at the mockup's 127px")
	assert_true(not (_row.size_flags_vertical & Control.SIZE_EXPAND),
		"the row must not expand vertically, or its parent VBox stretches it out of proportion")


func test_row_is_one_bordered_container() -> void:
	var box := _row.get_node_or_null("Container") as Panel
	assert_true(box != null, "the row must hold its contents in a single Container panel")
	assert_eq(box.theme_type_variation, &"PreviewRow",
		"the container wears the bordered-grey PreviewRow variation")
	assert_eq(box.offset_bottom, _CONTAINER_HEIGHT, "the container is 101px tall")
	assert_eq(box.anchor_right, 1.0, "the container spans the row's full width")
	assert_true(_row.get_node_or_null("IconBox") == null,
		"the old detached IconBox is gone -- the icon now draws on the container")


func test_icon_sits_inside_the_container_left_region() -> void:
	var icon := _row.get_node_or_null("Container/Icon") as TextureRect
	assert_true(icon != null, "Icon must live inside the Container")
	assert_true(icon.offset_right <= _ICON_REGION,
		"the icon must stay inside the 151px region left of the pill")


func test_pill_is_inset_into_the_container() -> void:
	var pill := _row.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "Pill must live inside the Container")
	assert_eq(pill.offset_left, _ICON_REGION, "the pill starts where the icon region ends")
	assert_eq(pill.offset_right, -_PILL_RIGHT_INSET, "the pill is inset from the container's right edge")
	assert_eq(pill.offset_top, _PILL_V_INSET, "the pill is inset from the container's top")
	assert_eq(pill.offset_bottom, -_PILL_V_INSET, "the pill is inset from the container's bottom")


## The bar was 281x1 px: size_flags_vertical defaulted to SHRINK_BEGIN (0)
## and its minimum size is (1,1), so it collapsed into a hairline across the
## pill's top instead of filling behind the number.
func test_stat_bar_fills_the_pill_vertically() -> void:
	var bar := _row.get_node_or_null("Container/Pill/StatBar") as StatBar
	assert_true(bar != null, "skill rows keep their StatBar")
	assert_true(bar.size_flags_vertical & Control.SIZE_FILL,
		"the StatBar must fill its parent vertically, or it collapses to a 1px line")


func test_name_label_overlaps_the_container_bottom() -> void:
	var label := _row.get_node_or_null("NameLabel") as Label
	assert_true(label != null, "NameLabel must exist")
	assert_eq(label.theme_type_variation, &"PreviewRowLabel",
		"the row label has its own bigger, harder-rimmed variation")
	assert_true(label.offset_top < -(_ROW_HEIGHT - _CONTAINER_HEIGHT),
		"the label starts above the container's bottom edge, overlapping it as in the mockup")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"the mockup right-aligns the name under the pill's right edge")


## Rows with no target (Wirausaha, Libur) keep the same node tree but draw no
## inset pill -- their chips sit straight on the container's grey.
func test_non_skill_rows_flatten_the_pill_and_drop_the_bar() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	var flat := scene.instantiate() as ActivityRow
	flat.is_skill_row = false
	flat.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(flat)
	track(flat)
	var pill := flat.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "the Pill node still exists on a non-skill row")
	assert_eq(pill.theme_type_variation, &"PreviewPillFlat",
		"a non-skill row's pill must draw nothing")
	assert_true(flat.get_node_or_null("Container/Pill/StatBar") == null,
		"a non-skill row has no target, so no StatBar")
	flat.queue_free()
```

Also update the two node-path tests already in the file. Replace `test_row_has_the_nodes_the_script_reaches_for`'s path list and `test_pill_uses_the_preview_pill_variation`'s lookup:

```gdscript
func test_row_has_the_nodes_the_script_reaches_for() -> void:
	for path in ["Container/Icon", "Container/Pill", "Container/Pill/Chips", "NameLabel"]:
		assert_true(_row.get_node_or_null(path) != null,
			"ActivityRow.tscn must declare the node: " + path)


func test_pill_uses_the_preview_pill_variation() -> void:
	var pill := _row.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "Pill must exist")
	assert_eq(pill.theme_type_variation, &"PreviewPill",
		"a skill row's pill must wear the PreviewPill variation, not a theme_override")
```

And the three `refresh` tests reference `Pill/Chips`; update each of their `get_node` paths from `"Pill/Chips"` to `"Container/Pill/Chips"`. That is `test_refresh_writes_the_skill_gain_into_a_chip`, `test_refresh_builds_two_chips_for_libur`, and `test_refresh_is_idempotent` (which uses the path twice).

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: FAIL — there is no `Container` node, and `is_skill_row` does not exist.

- [ ] **Step 3: Rewrite the scene**

Replace the whole of `Scenes/AturJadwal/ActivityRow.tscn` with:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://Scripts/AturJadwal/ActivityRow.gd" id="1_row"]
[ext_resource type="Script" path="res://Scripts/UI/StatBar.gd" id="2_statbar"]

[node name="ActivityRow" type="Button"]
custom_minimum_size = Vector2(200, 127)
size_flags_horizontal = 3
flat = true
script = ExtResource("1_row")
category = "Akademis"
display_name = "Akademik"

[node name="Container" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 101.0
grow_horizontal = 2
mouse_filter = 2
theme_type_variation = &"PreviewRow"

[node name="Icon" type="TextureRect" parent="Container"]
layout_mode = 1
anchors_preset = 0
offset_left = 34.0
offset_top = 9.0
offset_right = 118.0
offset_bottom = 93.0
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Pill" type="PanelContainer" parent="Container"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 151.0
offset_top = 18.0
offset_right = -15.0
offset_bottom = -18.0
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
theme_override_constants/separation = 12

[node name="NameLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -340.0
offset_top = -40.0
grow_horizontal = 0
grow_vertical = 0
mouse_filter = 2
theme_type_variation = &"PreviewRowLabel"
text = "Akademik"
horizontal_alignment = 2
vertical_alignment = 1
```

`size_flags_vertical = 1` on `StatBar` is the hairline fix — verified live: with it the bar measures 281×132 instead of 281×1. `offset_top = -40.0` on `NameLabel` makes the label start 40px above the row's bottom, i.e. 14px above the container's bottom edge at y=101 — the overlap the mockup shows.

- [ ] **Step 4: Update the script's node paths and flag**

In `Scripts/AturJadwal/ActivityRow.gd`, make four edits.

Replace the `category` setter's lookup:

```gdscript
@export var category: String = "Akademis":
	set(value):
		category = value
		if is_inside_tree():
			var bar := get_node_or_null("Container/Pill/StatBar") as StatBar
			if bar:
				bar.category = value
```

Replace the `icon_texture` setter's lookup:

```gdscript
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			var icon := get_node_or_null("Container/Icon") as TextureRect
			if icon:
				icon.texture = value
```

Replace the `has_progress_bar` export with `is_skill_row`:

```gdscript
## True for the three rows with a target to progress toward (Akademis,
## SeniBudaya, Olahraga). Those get a StatBar and a drawn inset pill. The
## other two -- Wirausaha and Istirahat -- have neither: their chips sit
## straight on the container's grey, matching the mockup. One flag because
## the two always move together; there is no row with a bar but no pill.
@export var is_skill_row: bool = true
```

Replace `_ready()`:

```gdscript
func _ready() -> void:
	var label := get_node_or_null("NameLabel") as Label
	if label:
		label.text = display_name
	var icon := get_node_or_null("Container/Icon") as TextureRect
	if icon:
		icon.texture = icon_texture
	var pill := get_node_or_null("Container/Pill") as PanelContainer
	var bar := get_node_or_null("Container/Pill/StatBar") as StatBar
	if is_skill_row:
		if bar:
			bar.category = category
	else:
		if pill:
			pill.theme_type_variation = &"PreviewPillFlat"
		if bar:
			bar.get_parent().remove_child(bar)
			bar.free()
```

Replace the two lookups in `refresh()`:

```gdscript
	var chips := get_node_or_null("Container/Pill/Chips")
```

```gdscript
	var bar := get_node_or_null("Container/Pill/StatBar") as StatBar
```

Also update the class doc comment at the top of the file, which describes the old two-box layout:

```gdscript
## One row of the Penjadwalan popup: a bordered container carrying the
## category icon on its left, a darker pill inset to its right holding the
## preview numbers, and the category name overlapping the bottom edge. The
## whole row is the Button -- the player taps anywhere on it to assign that
## activity to the selected day.
##
## Rows with a target (the three skills) draw the inset pill and a StatBar
## behind the numbers. Wirausaha and Libur have neither.
```

- [ ] **Step 5: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="activity_row")
```

Expected: PASS, 25 tests.

- [ ] **Step 6: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: `atur_jadwal` **fails** — its five instances still set the removed `has_progress_bar`, and `test_only_skill_rows_carry_a_stat_bar` looks up `Pill/StatBar` rather than `Container/Pill/StatBar`. Task 3 fixes both. Every other suite must stay green apart from the known `audio_director` failure. If a suite other than `atur_jadwal` or `audio_director` fails, stop and investigate before committing.

- [ ] **Step 7: Commit**

```bash
git add Scenes/AturJadwal/ActivityRow.tscn Scripts/AturJadwal/ActivityRow.gd \
        tests/test_activity_row.gd
git commit -m "feat(atur-jadwal): rebuild ActivityRow as one bordered container"
```

---

### Task 3: Un-stretch the card and re-seat its contents

The card texture is 1080×1080 but renders into a 988×1600 rect, stretching the art to aspect 0.40 against the mockup's 0.65. Making the rect square restores the designed proportions; the rows and arrow are then re-seated against the new card box, and the five row instances pick up Task 2's renamed flag.

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (`Penjadwalan/TextureRect`, `Rows`, `PopupBack`, and the five `ActivityRow` instances)
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `ActivityRow`'s 127px height and `is_skill_row` flag from Task 2.
- Produces: no new API.

- [ ] **Step 1: Write the failing test**

In `tests/test_atur_jadwal.gd`, replace the four `_CARD_*` constants with the square card's box, and update the two tests that reference the old row paths and flag.

Replace the constants:

```gdscript
## The card art is a 1080x1080 texture whose visible card occupies only
## x 211-868, y 34-1046 -- the rest is transparent padding. The TextureRect
## is square (988x988) so the art keeps its designed proportions, which puts
## the card's content at local x 193-794, y 31-957. Anything the player is
## meant to read must sit inside that box, not on the padding.
const _CARD_LEFT := 193.0
const _CARD_RIGHT := 794.0
const _CARD_TOP := 31.0
const _CARD_BOTTOM := 957.0
const _ROW_HEIGHT := 127.0
```

Replace `test_only_skill_rows_carry_a_stat_bar` (its `Pill/StatBar` path is now nested one deeper):

```gdscript
## The three skill rows keep their progress-toward-target bar; the other two
## have no target, so they must not carry one.
func test_only_skill_rows_carry_a_stat_bar() -> void:
	var root := _screen.get_node("Penjadwalan/TextureRect/Rows")
	for child in root.get_children():
		if not (child is ActivityRow):
			continue
		var bar := child.get_node_or_null("Container/Pill/StatBar")
		var is_skill: bool = child.category in ["Akademis", "SeniBudaya", "Olahraga"]
		if is_skill:
			assert_true(bar != null, child.category + " must keep its StatBar")
		else:
			assert_true(bar == null, child.category + " has no target, so no StatBar")
```

Replace `test_rows_are_inset_within_the_card_content`, `test_row_separation_matches_the_mockup_pitch`, `test_back_arrow_sits_inside_the_card`, and `test_the_row_stack_fits_inside_the_card` with:

```gdscript
func test_rows_are_inset_within_the_card_content() -> void:
	var rows := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows") as Control
	assert_true(rows != null, "Rows must exist")
	assert_eq(rows.offset_left, 263.0, "rows are inset 11.7% from the card's left edge")
	assert_eq(rows.offset_right, 724.0, "rows are inset 11.7% from the card's right edge")
	assert_eq(rows.offset_top, 72.0, "the first row starts 4.4% down the card")
	assert_true(rows.offset_left > _CARD_LEFT and rows.offset_right < _CARD_RIGHT,
		"the row block must sit inside the card art, not over its transparent padding")
	assert_true(rows.offset_top > _CARD_TOP,
		"the row block must start below the card's top edge, not over its transparent padding")


func test_row_separation_matches_the_mockup_pitch() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	assert_eq(rows.get_theme_constant("separation"), 30,
		"a 127px row plus 30px separation reproduces the mockup's 157px pitch")


func test_back_arrow_sits_inside_the_card() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack") as Control
	assert_true(back != null, "PopupBack must exist")
	assert_eq(back.offset_left, 236.0, "back arrow x, 7.2% in from the card's left")
	assert_eq(back.offset_top, 821.0, "back arrow y, centred 92% down the card")
	assert_true(back.offset_left >= _CARD_LEFT,
		"the back arrow must not hang off the card's left padding")
	assert_true(back.offset_bottom <= _CARD_BOTTOM,
		"the back arrow must stay above the card's bottom edge")


## 72 + 5*127 + 4*30 = 827, which must clear the card's bottom edge with room
## for the arrow beneath. If a later change alters row height or separation,
## this is the test that catches the stack overflowing the card.
func test_the_row_stack_fits_inside_the_card() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	var row_count := 0
	var row_height := 0.0
	for child in rows.get_children():
		if child is ActivityRow:
			row_count += 1
			row_height = (child as ActivityRow).custom_minimum_size.y
	assert_eq(row_height, _ROW_HEIGHT, "each row is the mockup's 127px tall")
	var sep: int = rows.get_theme_constant("separation")
	var stack_bottom: float = rows.offset_top + row_count * row_height + (row_count - 1) * sep
	assert_true(stack_bottom <= _CARD_BOTTOM,
		"the row stack ends at %d, past the card's bottom at %d" % [int(stack_bottom), int(_CARD_BOTTOM)])
```

Then append the new test for the square card:

```gdscript
## The card is a 1080x1080 texture. Rendering it into a non-square rect
## stretches the art -- it was 988x1600, squashing the card to aspect 0.40
## against the mockup's 0.65, which is what made every row look cramped.
func test_card_texture_rect_is_square() -> void:
	var card := _screen.get_node_or_null("Penjadwalan/TextureRect") as TextureRect
	assert_true(card != null, "the popup's card TextureRect must exist")
	var w: float = card.offset_right - card.offset_left
	var h: float = card.offset_bottom - card.offset_top
	assert_eq(w, h, "the card rect must be square so the 1080x1080 art is not stretched")
```

- [ ] **Step 2: Run the test to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: FAIL — the rect is 988×1600, the `Rows` offsets are the old ones, `separation` is 45, `PopupBack` is at y=1370, and the row instances still set the removed `has_progress_bar`.

- [ ] **Step 3: Make the card square**

In `Scenes/AturJadwal/atur_jadwal.tscn`, change the `Penjadwalan/TextureRect` node's vertical offsets (currently lines 388 and 390) so the rect is 988×988 centred on the screen:

```
offset_top = -494.0
offset_bottom = 494.0
```

Leave `offset_left = -494.0`, `offset_right = 494.0`, the anchors, `texture`, and `expand_mode` untouched.

- [ ] **Step 4: Re-seat the Rows container**

Replace the `Rows` node's offsets and separation:

```
[node name="Rows" type="VBoxContainer" parent="Penjadwalan/TextureRect"]
layout_mode = 0
offset_left = 263.0
offset_top = 72.0
offset_right = 724.0
offset_bottom = 827.0
theme_override_constants/separation = 30
```

- [ ] **Step 5: Rename the flag on the two non-skill row instances**

`RowWirausaha` and `RowLibur` each carry a `has_progress_bar = false` line, which Task 2 renamed. Change both to:

```
is_skill_row = false
```

Leave `RowAkademik`, `RowSeniBudaya`, and `RowAtletik` alone — they set no flag and take the `true` default. Do not touch any instance's `category`, `display_name`, `icon_texture`, `energy_icon`, or `mood_icon`.

- [ ] **Step 6: Re-seat the back arrow**

Replace the `PopupBack` node's offsets:

```
offset_left = 236.0
offset_top = 821.0
offset_right = 361.0
offset_bottom = 946.0
```

That stays 125×125 — comfortably over the 96px touch minimum — and now sits in the square card's lower-left rather than below its bottom edge.

- [ ] **Step 7: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: PASS, 21 tests — including `test_interactive_controls_meet_the_minimum_touch_target`, which now measures 127px-tall rows.

- [ ] **Step 8: Run the full suite**

```
filesystem_manage(op="scan")
test_run()
```

Expected: only the known `audio_director` failure. `activity_row` must still be green.

- [ ] **Step 9: Verify it visually against the mockup**

Do not click through the game to reach this state — seed it:

```
project_run()
editor_manage(op="game_eval", params={"code":
  "DebugManager._seed_playtest_state()\nawait get_tree().process_frame\nget_tree().change_scene_to_file(\"res://Scenes/AturJadwal/atur_jadwal.tscn\")\nawait get_tree().process_frame\nawait get_tree().process_frame\nvar s = get_tree().current_scene\nGameState.selected_day = \"Senin\"\nGameState.selected_student = GameState.approved_students[0]\ns._show_penjadwalan_popup()\nawait get_tree().process_frame\nreturn s.penjadwalan_popup_open"})
editor_screenshot(source="game", max_resolution=1080)
```

Capture at `max_resolution=1080` — at lower resolutions the border and the pill's inset alias away and a correct layout can read as a flat slab.

Check against the mockup, in order:

1. The card is a compact square-ish panel, no longer a tall narrow strip.
2. Each row is **one** bordered grey container — no card gradient showing between the icon and the pill.
3. The icon sits on the container's grey; the darker pill is inset to its right with a visible margin on all four sides.
4. Wirausaha and Libur show **no** inset pill — their chips sit on the grey.
5. On a skill row with progress, the bar reads as a filled band behind the number, not a hairline.
6. Each label is right-aligned, overlapping its own container's bottom edge.
7. The back arrow sits inside the card's lower-left, on the gradient.

Then confirm the resolved geometry:

```
editor_manage(op="game_eval", params={"code":
  "var s = get_tree().current_scene\nvar r = s.get_node(\"Penjadwalan/TextureRect/Rows/RowAkademik\")\nvar bar = r.get_node(\"Container/Pill/StatBar\")\nreturn {\"card\": var_to_str(s.get_node(\"Penjadwalan/TextureRect\").size), \"row\": var_to_str(r.size), \"container\": var_to_str(r.get_node(\"Container\").size), \"pill\": var_to_str(r.get_node(\"Container/Pill\").size), \"bar\": var_to_str(bar.size)}"})
project_manage(op="stop")
```

Expected: `card` `(988, 988)`, `row` `(461, 127)`, `container` `(461, 101)`, `pill` `(295, 65)`, and `bar` with a height well above 1 — the hairline fix holding in the live scene.

- [ ] **Step 10: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd
git commit -m "feat(atur-jadwal): un-stretch the popup card and re-seat its rows"
```

---

## Self-Review

**Spec coverage.** Every row of the Current-vs-Target table maps to a task. Theme surfaces (row container, pill fill, flat variant, label) are Task 1. Row restructure, the `IconBox` removal, the `is_skill_row` rename, and the `StatBar` hairline are Task 2. The square card, `Rows`, `PopupBack`, and the two instance-flag renames are Task 3. The user's four brainstorming decisions are all honoured: Milker ALL CAPS kept (no font change anywhere in the plan), colours in scope (three sampled tokens), rows unified under one container, and the bar fixed to fill rather than hidden.

**Placeholder scan.** No TBDs. Every geometry number traces to a measured fraction in "Measured Target Geometry"; every colour is a sampled hex. Both scene edits give the exact lines to paste. The one diagnostic that would otherwise have been "investigate the bar" is instead a stated root cause with a verified fix — `size_flags_vertical` was read as `0` live, and setting `SIZE_FILL` was confirmed to change the bar from 281×1 to 281×132 before this plan was written.

**Type consistency.** `_ROW_HEIGHT` (127) is used in Task 2's tests, Task 3's tests, and matches `custom_minimum_size = Vector2(200, 127)` in Task 2's scene. `_CONTAINER_HEIGHT` (101) matches `Container.offset_bottom`. `_ICON_REGION` (151) matches `Pill.offset_left`. `_PILL_RIGHT_INSET` (15) and `_PILL_V_INSET` (18) match the `Pill`'s negative offsets. `is_skill_row` is defined in Task 2 and set in Task 3's two instances. Node paths (`Container/Pill/StatBar`, `Container/Pill/Chips`, `Container/Icon`) are identical across the script edits, both test files, and Step 9's verification eval.

**A deliberate cross-task red state.** Task 2 leaves `atur_jadwal` failing — its instances still set the renamed flag and its test still uses the old node path. Task 3 fixes both. This is called out explicitly in Task 2 Step 6 so an implementer does not treat it as their own breakage, with the guard that any *other* suite failing means stop. The alternative — renaming the flag in Task 3 and the paths in Task 2 — would split one rename across two commits, which is worse.

**Two risks worth flagging.** Task 1's rebake rewrites `kejartes_theme.tres`, which `test_theme_factory` and `test_student_card` also assert against; Step 7's full-suite run is what catches a bad bake. And the editor's resource cache genuinely serves a stale theme after a game-process rebake on this project — the `CACHE_MODE_REPLACE` escape hatch in Task 1 Step 5 exists because plain `scan()` was confirmed insufficient twice before.

**One deliberate non-change.** `CardSectionLabel` is left alone rather than resized, because StudentCard's "Sifat Pasif:" heading shares it. The row labels get their own `PreviewRowLabel` variation instead.
