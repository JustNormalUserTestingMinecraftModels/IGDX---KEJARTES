# Achievements Layout Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Achievements grid, tile and detail popup and the skin picker around the user's mockups, and land two small fixes — a white outline on AturJadwal's student splash and the removal of Koperasi's crate handle.

**Architecture:** The grid's asymmetry is a container-choice bug, so `GridContainer` is replaced by an `HBoxContainer` of two `VBoxContainer`s filled round-robin. The tile and popup are re-proportioned in their `.tscn` files with new `ThemeFactory` variations; no `theme_override_*` is added. The popup's Klaim button is deleted and claiming moves to opening the popup, with the new `notice_icon` badge on the tile carrying the affordance. `SkinSelectPopup` becomes `SkinSelect`: still a Lobby overlay, because only an overlay can blur the live screen, but rebuilt as a full-bleed carousel of one student's skins over a rail of all six characters, committing through one TERAPKAN button.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` suites driven by the Godot AI MCP `test_run` tool.

**Specs:** `docs/superpowers/specs/2026-09-22-achievements-layout-pass-design.md` (Tasks 1-8)
and `docs/superpowers/specs/2026-09-22-skin-select-screen-design.md` (Tasks 9-11)

## Global Constraints

- **Never hand-edit a `.tscn` while the editor is attached.** All scene edits go through `scene_open` → `node_create` / `node_set_property` / `node_manage` / `batch_execute` → `scene_save`. A text edit is silently overwritten by the next `scene_save`.
- **Scene work first, script work second, inside each task.** `scene_save` flushes every open script tab over whatever `script_patch` wrote. After the last `script_patch` of a task, restart the editor before the next task's first `scene_save`.
- **No `theme_override_*`.** Layout-only constant overrides (`separation`, `margin_*`) are the only exception. Anything drawn gets a `ThemeFactory` type variation.
- **Nothing is built at runtime.** Static chrome is a node in the `.tscn`; repeated rows are a `PackedScene` template.
- **Every script needs a `##` file header and a `##` line on every `@export`** (`tests/test_script_documentation.gd`).
- **No test may be a coroutine.** The runner calls `suite.call(name)` without awaiting; a single `await` silently aborts the test and it reports "0 assertions". Where a test needs a container laid out, call `container.notification(Container.NOTIFICATION_SORT_CHILDREN)` — it sorts synchronously — never `await get_tree().process_frame`.
- **Suites must be `@tool`**, and scripts the runner instantiates must be `@tool` with real `_ready()` side effects behind `if Engine.is_editor_hint(): return`.
- **Prefer targeted `test_run(suite=...)`.** A full run drops the bridge and costs an editor restart; take full runs only at Task 9.
- **UI text is Indonesian**, systems code English.
- **`Balance.gd` is a collaborator's file** — read it, never edit it.
- **Design tokens, verbatim:** `font_body_size` 28, `font_title` 36, `font_h2` 48, `space_xs` 8, `space_sm` 16, `space_md` 28, `space_lg` 44, `text_primary` `#3B2412`, `text_secondary` `#7A5C40`.

---

### Task 1: Symmetric two-column grid

The `GridContainer` hands its leftover width to one column — measured live at 420 left, 478 right. A `BoxContainer` splits leftover space evenly among equal-ratio expanding children, so the grid becomes an `HBoxContainer` of two `VBoxContainer`s, filled round-robin so reading order survives.

**Files:**
- Modify: `Scenes/Achievements/achievements.tscn` (`Safe/UI/Scroll/Margin/List`)
- Modify: `Scripts/Achievements/achievements_screen.gd`
- Test: `tests/test_achievements_grid.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `achievements_screen.gd` gains `_columns: Array[VBoxContainer]` and `func _relayout_columns(filter: int) -> void`. `%Columns` (HBoxContainer), `%Left` and `%Right` (VBoxContainer) become the unique names; `%List` is gone. Tasks 2–4 do not touch these.

- [ ] **Step 1: Write the failing tests**

Replace `test_scene_has_grid_columns_two` in `tests/test_achievements_grid.gd` with these four, and add the `Container` import-free helper:

```gdscript
## A BoxContainer splits leftover width evenly between equal-ratio
## expanding children; a GridContainer does not. This test builds both at
## the grid's real measurements (list width 922, h_separation 24, tile
## minimum width 420) and records the difference, so the reason this screen
## stopped using a GridContainer cannot be lost. NOTIFICATION_SORT_CHILDREN
## is sent by hand because the runner forbids awaiting a frame.
func test_hbox_splits_evenly_where_gridcontainer_does_not() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for i in 2:
		var c := Control.new()
		c.custom_minimum_size = Vector2(420, 260)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	Engine.get_main_loop().root.add_child(grid)
	track(grid)
	grid.size = Vector2(922, 600)
	grid.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var grid_even: bool = absf(grid.get_child(0).size.x - grid.get_child(1).size.x) < 0.5

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	for i in 2:
		var c := VBoxContainer.new()
		c.custom_minimum_size = Vector2(420, 260)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(c)
	Engine.get_main_loop().root.add_child(hbox)
	track(hbox)
	hbox.size = Vector2(922, 600)
	hbox.notification(Container.NOTIFICATION_SORT_CHILDREN)
	assert_true(absf(hbox.get_child(0).size.x - hbox.get_child(1).size.x) < 0.5,
		"HBoxContainer must split 922 evenly, got %s and %s" %
			[hbox.get_child(0).size.x, hbox.get_child(1).size.x])
	assert_false(grid_even,
		"GridContainer is expected to split unevenly here -- if this ever passes, " +
		"the reason for the two-column HBox is gone and this suite should be revisited")


func test_scene_has_two_expanding_columns_and_no_grid() -> void:
	var src := _scene_src()
	assert_false(src.contains('type="GridContainer"'),
		"the GridContainer split its columns 420/478; it must be gone")
	assert_true(src.contains('[node name="Columns" type="HBoxContainer"'))
	assert_true(src.contains('[node name="Left" type="VBoxContainer"'))
	assert_true(src.contains('[node name="Right" type="VBoxContainer"'))
	var expand_count := src.count("size_flags_horizontal = 3")
	assert_true(expand_count >= 2, "both columns must be EXPAND_FILL, found %d" % expand_count)


func test_script_distributes_tiles_round_robin() -> void:
	var src := _script_src()
	assert_true(src.contains("_relayout_columns"), "filtering must go through _relayout_columns")
	assert_true(src.contains("_columns[n % 2]"), "the n-th visible tile goes to column n % 2")
	assert_true(src.contains("move_child(tile, n / 2)"), "and to row n / 2 inside it")


## ensure_control_visible needs the ScrollContainer. The old code walked up
## from %List with get_parent().get_parent(); the tree is a level deeper
## now, so it must use the unique name instead of counting hops.
func test_scroll_is_reached_by_unique_name() -> void:
	var src := _script_src()
	assert_false(src.contains("list.get_parent().get_parent()"),
		"walking up from the list breaks with the extra column level")
	assert_true(src.contains("%Scroll"), "the ScrollContainer must be reached by unique name")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="achievements_grid")`
Expected: FAIL — `test_scene_has_two_expanding_columns_and_no_grid` reports the GridContainer still present; the two script tests report the missing anchors. `test_hbox_splits_evenly_where_gridcontainer_does_not` should already PASS (it tests engine behaviour, not our code).

- [ ] **Step 3: Rebuild the scene's list as two columns**

Through the editor only:

```
scene_open(path="res://Scenes/Achievements/achievements.tscn")
```

Then `batch_execute` with these commands, in order:

1. `delete_node` `/Achievements/Safe/UI/Scroll/Margin/List`
2. `create_node` parent `/Achievements/Safe/UI/Scroll/Margin`, type `HBoxContainer`, name `Columns`
3. `set_property` `/Achievements/Safe/UI/Scroll/Margin/Columns` `unique_name_in_owner` = `true`
4. `set_property` … `size_flags_horizontal` = `3`
5. `set_property` … `theme_override_constants/separation` = `24`
6. `create_node` parent `…/Columns`, type `VBoxContainer`, name `Left`
7. `set_property` `…/Columns/Left` `unique_name_in_owner` = `true`
8. `set_property` `…/Columns/Left` `size_flags_horizontal` = `3`
9. `set_property` `…/Columns/Left` `theme_override_constants/separation` = `24`
10. `create_node` parent `…/Columns`, type `VBoxContainer`, name `Right`
11. `set_property` `…/Columns/Right` `unique_name_in_owner` = `true`
12. `set_property` `…/Columns/Right` `size_flags_horizontal` = `3`
13. `set_property` `…/Columns/Right` `theme_override_constants/separation` = `24`

Then `scene_save()`.

Numbers must be unquoted (`3`, not `"3"`); `anchors_preset` is inert here and is not set.

- [ ] **Step 4: Rewire the screen script**

`script_patch` on `Scripts/Achievements/achievements_screen.gd`.

Replace the `@onready var list` line:

```gdscript
@onready var columns_box: HBoxContainer = %Columns
@onready var scroll: ScrollContainer = %Scroll
```

Add below `var _tiles`:

```gdscript
## The two grid columns, left first. Tiles are distributed round-robin
## across them (see _relayout_columns) rather than filled top-to-bottom, so
## the catalogue's reading order survives the split.
var _columns: Array[VBoxContainer] = []
```

In `_ready()`, replace `list.add_child(tile)` with an initial distribution: build `_columns` first, then add each tile.

```gdscript
	_columns = [%Left, %Right]
	var n := 0
	for entry in AchievementCatalog.ENTRIES:
		var tile: AchievementTile = tile_scene.instantiate()
		_columns[n % 2].add_child(tile)
		tile.setup(entry)
		tile.tile_pressed.connect(_on_tile_pressed)
		_tiles.append(tile)
		n += 1
```

Replace `_on_filter_selected` with:

```gdscript
func _on_filter_selected(index: int) -> void:
	_relayout_columns(index)


## Applies `filter` and re-deals the surviving tiles across the two
## columns. Filtering cannot just toggle `visible`: a hidden tile would
## leave a hole in its own column while the other column packed tight, and
## the two would stop lining up row for row. So the n-th tile the filter
## admits is moved to column n % 2 at index n / 2, which keeps row-major
## reading order and keeps the rows aligned.
##
## remove_child + add_child rather than reparent(): reparent keeps a global
## transform, which means nothing to a child of a container.
func _relayout_columns(filter: int) -> void:
	var n := 0
	for tile in _tiles:
		tile.visible = tile.matches_filter(filter)
		if not tile.visible:
			continue
		var col: VBoxContainer = _columns[n % 2]
		if tile.get_parent() != col:
			tile.get_parent().remove_child(tile)
			col.add_child(tile)
		col.move_child(tile, n / 2)
		n += 1
```

In `_scroll_to_tile_deferred`, replace the parent walk:

```gdscript
func _scroll_to_tile_deferred(tile: AchievementTile) -> void:
	if scroll != null:
		scroll.ensure_control_visible(tile)
	Juice.shake(tile, 6.0)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="achievements_grid")` then `test_run(suite="achievement_screen")`
Expected: both PASS. If `achievement_screen` fails on a `%List` node lookup, fix that lookup in the suite to `%Columns`.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Achievements/achievements.tscn Scripts/Achievements/achievements_screen.gd tests/test_achievements_grid.gd tests/test_achievement_screen.gd
git commit -m "fix(achievements): split the grid evenly with two HBox columns"
```

---

### Task 2: Tile geometry and the body-size title

The icon is 3% of the tile and the title uses `CaptionLabel` (22px) — the scale's second-smallest step. The mockup roughly doubles the icon; the title moves to the body step.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (`_build_achievement_tile`)
- Modify: `Scenes/Achievements/AchievementTile.tscn`
- Test: `tests/test_achievement_tile.gd`, `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: theme variation `AchievementTileTitleLabel` (base `Label`, `font_body_size`, `text_primary`, `font_body`). Task 5 adds a second variation, `AchievementSheetBodyLabel`, and does not touch this one.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_achievement_tile.gd`:

```gdscript
## The tile's own label, one step up from CaptionLabel (22) to the body
## step (28), in text_primary rather than text_secondary. The tile's title
## is its most important text and was using the scale's second-smallest
## size.
func test_title_uses_the_tile_title_variation_at_body_size() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_type_variation_base("AchievementTileTitleLabel"), &"Label")
	assert_eq(theme.get_font_size("font_size", "AchievementTileTitleLabel"), tokens.font_body_size)
	assert_eq(theme.get_color("font_color", "AchievementTileTitleLabel"), tokens.text_primary)
	assert_eq(theme.get_font("font", "AchievementTileTitleLabel"), tokens.font_body)


func test_tile_geometry_matches_the_mockup() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains("custom_minimum_size = Vector2(420, 310)"), "tile grows to 420x310")
	assert_true(src.contains("custom_minimum_size = Vector2(132, 132)"), "icon slot doubles to 132")
	assert_true(src.contains("custom_minimum_size = Vector2(0, 80)"), "title band fits two 28px lines")
	assert_true(src.contains('theme_type_variation = &"AchievementTileTitleLabel"'))
	assert_false(src.contains('[node name="Title" type="Label" parent="Content"]\ncustom_minimum_size = Vector2(0, 58)'),
		"the old 58px caption band must be gone")
```

Add `"AchievementTileTitleLabel"` **nowhere** in `tests/test_theme_factory.gd`'s `DISPLAY_ROSTER` — it takes `font_body`, not `font_display`. Add this guard instead:

```gdscript
## AchievementTileTitleLabel is body copy on a card, so it deliberately
## stays off DISPLAY_ROSTER -- pinning that, because every other
## Achievement* label variation is on it and the next reader will assume
## this one should be too.
func test_tile_title_label_is_body_face_not_display() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_font("font", "AchievementTileTitleLabel"), tokens.font_body)
	assert_false(DISPLAY_ROSTER.has("AchievementTileTitleLabel"))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="achievement_tile")` and `test_run(suite="theme_factory")`
Expected: FAIL — `get_type_variation_base` returns an empty `StringName` for the missing variation, and the geometry scan finds the old numbers.

- [ ] **Step 3: Add the theme variation**

`script_patch` on `Scripts/Design/ThemeFactory.gd`, inside `_build_achievement_tile`, after the `AchievementPrizeChipLabelAmber` block:

```gdscript
	# The tile's own title. CaptionLabel (22) put the tile's most important
	# text on the scale's second-smallest step; this is the body step (28)
	# in the primary ink. Body face, not display -- it wraps to two lines
	# and Boohong at 28 over two lines reads as a banner, not a caption.
	theme.add_type("AchievementTileTitleLabel")
	theme.set_type_variation("AchievementTileTitleLabel", "Label")
	theme.set_font_size("font_size", "AchievementTileTitleLabel", tokens.font_body_size)
	theme.set_color("font_color", "AchievementTileTitleLabel", tokens.text_primary)
	if tokens.font_body != null:
		theme.set_font("font", "AchievementTileTitleLabel", tokens.font_body)
```

- [ ] **Step 4: Rebake the theme, then restart the editor**

The bake is `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X), which writes `Assets/Theme/kejartes_theme.tres`. Run it **alone**, never beside a `scene_save`: the cached theme merges stale style properties by id. Then restart the editor so the new bake and the patched script are both read from disk.

Verify with `git diff --stat Assets/Theme/kejartes_theme.tres` — it must show a change, and only to that file.

- [ ] **Step 5: Re-proportion the tile scene**

`scene_open(path="res://Scenes/Achievements/AchievementTile.tscn")`, then `batch_execute`:

1. `set_property` `/AchievementTile` `custom_minimum_size` = `Vector2(420, 310)`
2. `set_property` `/AchievementTile/Content/IconSlot` `custom_minimum_size` = `Vector2(132, 132)`
3. `set_property` `/AchievementTile/Content/Title` `custom_minimum_size` = `Vector2(0, 80)`
4. `set_property` `/AchievementTile/Content/Title` `theme_type_variation` = `AchievementTileTitleLabel`
5. `set_property` `/AchievementTile/Content/ProgressBar` `custom_minimum_size` = `Vector2(0, 6)`

Then `scene_save()`.

`LockIcon` keeps its 16px inset on all four sides, so it scales with the slot on its own.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `test_run(suite="achievement_tile")` and `test_run(suite="theme_factory")`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres Scenes/Achievements/AchievementTile.tscn tests/test_achievement_tile.gd tests/test_theme_factory.gd
git commit -m "feat(achievements): give the tile a 132px icon and a body-size title"
```

---

### Task 3: Prize chip only when there is a prize, and a readable locked state

Twenty of the 26 entries have no prize and render a chip that says "—". And `locked_modulate` fades the tile root, putting a locked title at 1.78:1 against its own card — under the 3.0 floor `tests/test_bar_contrast.gd` pins.

**Files:**
- Modify: `Scripts/Achievements/AchievementTile.gd`
- Test: `tests/test_achievement_tile.gd`

**Interfaces:**
- Consumes: the 420x310 tile from Task 2.
- Produces: `AchievementTile.locked_icon_modulate: Color` replaces `locked_modulate`. Task 4 uses neither.

- [ ] **Step 1: Write the failing tests**

In `tests/test_achievement_tile.gd`, replace `test_prize_chip_empty_is_neutral_dash` and the `locked_modulate` assertion at line 73 with:

```gdscript
## 20 of the 26 catalogue entries set prize to "". A chip reading "—" on
## 77% of the grid teaches nothing and costs the 38px the bigger icon
## needs, so the chip is hidden outright.
func test_prize_chip_is_hidden_when_the_entry_has_no_prize() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_false(tile.prize_chip.visible, "an entry with no prize shows no chip")


func test_prize_chip_is_visible_and_amber_when_the_entry_has_one() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PRIZE_ID))
	assert_true(tile.prize_chip.visible)
	assert_eq(tile.prize_chip.theme_type_variation, &"AchievementPrizeChipAmber")
	assert_eq(tile.prize_label.text, "Hasil Wirausaha +5%")


## The contrast fix. Fading the tile ROOT took a locked title to 1.78:1
## against its own card (measured live, 2026-09-22) -- under the 3.0 floor
## and far under the 4.5 body copy wants. The root now stays opaque in
## every state and only the icon is greyed; the lock overlay already drawn
## on it carries the state.
func test_locked_tile_root_stays_fully_opaque() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_eq(tile.modulate, Color.WHITE, "the tile root must never be faded")
	assert_eq(tile.icon.modulate, tile.locked_icon_modulate, "only the icon is greyed while locked")
	assert_true(tile.lock_icon.visible)


func test_unlocked_tile_restores_the_icon_tint() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_eq(tile.modulate, Color.WHITE)
	assert_eq(tile.icon.modulate, Color.WHITE)
	assert_false(tile.lock_icon.visible)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="achievement_tile")`
Expected: FAIL — `locked_icon_modulate` does not exist, the chip is visible with "—", and the root is at alpha 0.55.

- [ ] **Step 3: Implement**

`script_patch` on `Scripts/Achievements/AchievementTile.gd`.

Replace the `locked_modulate` export:

```gdscript
## Tint applied to the ICON ONLY while the achievement is locked.
## Deliberately not on the tile root: fading the root took a locked title
## to 1.78:1 against its own card (measured live, 2026-09-22), under the
## 3.0 floor tests/test_bar_contrast.gd pins and far under the 4.5 body
## copy wants. Locked now reads from the greyed icon, the lock overlay on
## it, and the absent corner badge -- none of which is text.
@export var locked_icon_modulate: Color = Color(0.62, 0.62, 0.62, 1.0)
```

Replace `_apply_prize`:

```gdscript
func _apply_prize(entry: Dictionary) -> void:
	var prize := String(entry.get("prize", ""))
	prize_chip.visible = prize != ""
	if not prize_chip.visible:
		return
	prize_label.text = prize
	prize_chip.theme_type_variation = &"AchievementPrizeChipAmber"
	prize_label.theme_type_variation = &"AchievementPrizeChipLabelAmber"
```

In `_apply_state`, replace the two `modulate` lines:

```gdscript
	var locked := state == AchievementsScript.STATE_LOCKED
	icon.modulate = locked_icon_modulate if locked else Color.WHITE
	lock_icon.visible = locked
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="achievement_tile")`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Achievements/AchievementTile.gd tests/test_achievement_tile.gd
git commit -m "fix(achievements): keep locked tiles readable and drop the empty prize chip"
```

---

### Task 4: The notice badge

`notice_icon.png` replaces the green "BARU" pill in the same corner slot, and its two theme variations go with it.

**Files:**
- Modify: `Scenes/Achievements/AchievementTile.tscn`
- Modify: `Scripts/Achievements/AchievementTile.gd`
- Modify: `Scripts/Design/ThemeFactory.gd`
- Test: `tests/test_achievement_tile.gd`, `tests/test_theme_factory.gd`
- Already added to the tree by the spec commit: `Assets/Images/Achievements/notice_icon.png` (256x256 RGBA)

**Interfaces:**
- Consumes: Task 3's `_apply_state`.
- Produces: `%NoticeBadge` (TextureRect) replaces `%BaruBadge`; `AchievementTile._notice_shown` replaces `_baru_shown`; `tile.notice_badge` replaces `tile.baru_badge`. Task 5 reuses the same texture path for the popup's `StateIcon`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_achievement_tile.gd`, rename the three BARU tests and rewrite the corner-slot scan's node name:

```gdscript
const NOTICE_ICON := "res://Assets/Images/Achievements/notice_icon.png"


func test_unlocked_state_shows_the_notice_badge() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_true(tile.notice_badge.visible, "an unclaimed prize is marked by the notice icon")
	assert_false(tile.check_badge.visible)


func test_notice_badge_wears_the_notice_icon_at_72px() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains(NOTICE_ICON), "the badge must use the notice_icon asset")
	assert_true(src.contains('[node name="NoticeBadge" type="TextureRect"'))
	assert_true(src.contains("custom_minimum_size = Vector2(72, 72)"))
	assert_false(src.contains('[node name="BaruBadge"'), "the BARU pill is replaced")
	assert_false(src.contains("BARU"))


func test_relock_clears_notice_shown_so_it_replays_on_reunlock() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_true(AchievementTile._notice_shown.has(PLAIN_ID))

	_achievements().relock(PLAIN_ID)
	tile.refresh()
	assert_false(AchievementTile._notice_shown.has(PLAIN_ID), "relock must clear the once-per-session flag")

	_achievements().debug_unlock(PLAIN_ID)
	tile.refresh()
	assert_true(tile.notice_badge.visible)
	assert_true(AchievementTile._notice_shown.has(PLAIN_ID), "re-unlock must be able to replay the pop_in")
```

In `test_badges_stay_top_right_corner`, change the two node-name checks from `BaruBadge` to `NoticeBadge`.

In `tests/test_theme_factory.gd`, delete `"AchievementBaruBadgeLabel"` from `DISPLAY_ROSTER` and add:

```gdscript
## The BARU pill lost its only caller when the tile's corner badge became
## the notice_icon TextureRect; its two variations went with it.
func test_baru_badge_variations_are_gone() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	assert_eq(theme.get_type_variation_base("AchievementBaruBadge"), &"")
	assert_eq(theme.get_type_variation_base("AchievementBaruBadgeLabel"), &"")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="achievement_tile")` and `test_run(suite="theme_factory")`
Expected: FAIL — `notice_badge` and `_notice_shown` do not exist, and the two variations still build.

- [ ] **Step 3: Swap the badge node**

`scene_open(path="res://Scenes/Achievements/AchievementTile.tscn")`, then `batch_execute`:

1. `delete_node` `/AchievementTile/BaruBadge` (this removes its `BaruLabel` child too)
2. `create_node` parent `/AchievementTile`, type `TextureRect`, name `NoticeBadge`
3. `set_property` `/AchievementTile/NoticeBadge` `unique_name_in_owner` = `true`
4. `set_property` … `visible` = `false`
5. `set_property` … `custom_minimum_size` = `Vector2(72, 72)`
6. `set_property` … `size_flags_horizontal` = `8`
7. `set_property` … `size_flags_vertical` = `0`
8. `set_property` … `mouse_filter` = `2`
9. `set_property` … `texture` = `res://Assets/Images/Achievements/notice_icon.png`
10. `set_property` … `expand_mode` = `1`
11. `set_property` … `stretch_mode` = `5`
12. `set_property` `/AchievementTile/CheckBadge` `custom_minimum_size` = `Vector2(48, 48)`
13. `move_node` `/AchievementTile/NoticeBadge` to the last index, so it draws above `Content`

Then `scene_save()`.

`node_create` appends last, so step 13 is only needed if `CheckBadge` ends up after it; check the order in `scene_get_hierarchy` before deciding.

- [ ] **Step 4: Rename through the script**

`script_patch` on `Scripts/Achievements/AchievementTile.gd`:

- `@onready var baru_badge: PanelContainer = %BaruBadge` → `@onready var notice_badge: TextureRect = %NoticeBadge`
- `static var _baru_shown: Dictionary = {}` → `static var _notice_shown: Dictionary = {}`, and update its `##` comment to say "ids whose notice badge has already played its pop_in this session"
- every `_baru_shown` → `_notice_shown`, `baru_badge` → `notice_badge` (`replace_all=True` on each)

`script_patch` on `Scripts/Design/ThemeFactory.gd`: delete the `AchievementBaruBadge` and `AchievementBaruBadgeLabel` blocks, and update `_build_achievement_tile`'s `##` header line that mentions "the BARU pip".

- [ ] **Step 5: Rebake the theme, then restart the editor**

Same as Task 2 Step 4: run `Scripts/Design/BakeTheme.gd` alone, check `git diff --stat` shows only `kejartes_theme.tres`, then restart the editor.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `test_run(suite="achievement_tile")`, `test_run(suite="theme_factory")`, `test_run(suite="achievements")`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Scenes/Achievements/AchievementTile.tscn Scripts/Achievements/AchievementTile.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_achievement_tile.gd tests/test_theme_factory.gd
git commit -m "feat(achievements): mark claimable tiles with the notice icon"
```

---

### Task 5: Rebuild the detail popup

The card is a fraction of the screen (922px at 1080x1920, 1152px at 1080x2400) holding ~350px of content, the prize prints twice, and the stack is on a 12px separation the user called crowded. The card becomes content-sized and the rhythm becomes `space_lg` (44).

**Files:**
- Modify: `Scenes/Achievements/AchievementDetailSheet.tscn`
- Modify: `Scripts/Achievements/AchievementDetailSheet.gd`
- Modify: `Scripts/Achievements/AchievementCatalog.gd` (delete `description_of`)
- Modify: `Scripts/Design/ThemeFactory.gd` (add `AchievementSheetBodyLabel`)
- Test: `tests/test_achievement_detail_sheet.gd`, `tests/test_achievements_api.gd`

**Interfaces:**
- Consumes: `notice_icon.png` from Task 4.
- Produces: `%StateRow` (HBoxContainer) with `%ProgressLabel` and `%StateIcon` (TextureRect). `%PrizeLabel`, `%LockIcon`, `%ClaimedLabel` and `%ActionArea` are gone. `%PrizeChip` / `%PrizeChipLabel` are new. `AchievementDetailSheet` keeps `open_for(id)`, `close()`, `closed` and `claim_requested(id)` unchanged in signature. Task 6 changes only `open_for`'s body.

- [ ] **Step 1: Write the failing tests**

In `tests/test_achievement_detail_sheet.gd`, replace the three state tests and add the layout ones:

```gdscript
const NOTICE_ICON := "res://Assets/Images/Achievements/notice_icon.png"
const LOCK_ICON := "res://Assets/Images/UI/Placeholders/icon_lock.svg"
const CHECK_ICON := "res://Assets/Images/UI/Placeholders/icon_check.svg"
## An id with a non-empty prize, for the chip assertions.
const PRIZE_ID := "total_25"


func test_locked_state_icon_is_the_lock() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_true(sheet.visible)
	assert_eq((sheet.get_node("%StateIcon") as TextureRect).texture.resource_path, LOCK_ICON)


func test_claimed_state_icon_is_the_check() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	_achievements().claim(PLAIN_ID)
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_eq((sheet.get_node("%StateIcon") as TextureRect).texture.resource_path, CHECK_ICON)


## The prize used to print twice: description_of() appended
## "\nHadiah: <prize>" to the desc AND %PrizeLabel repeated the same
## string underneath. The desc is now the entry's own text and the prize
## lives only in the chip.
func test_desc_is_the_entry_text_and_the_prize_is_only_in_the_chip() -> void:
	var sheet := _new_sheet()
	var entry := AchievementCatalog.get_entry(PRIZE_ID)
	sheet.open_for(PRIZE_ID)
	var desc := (sheet.get_node("%Desc") as Label).text
	assert_eq(desc, entry.desc)
	assert_false(desc.contains("Hadiah"), "the prize must not be baked into the desc")
	assert_true(sheet.get_node("%PrizeChip").visible)
	assert_eq((sheet.get_node("%PrizeChipLabel") as Label).text, entry.prize)


func test_prize_chip_hidden_for_an_entry_without_one() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_false(sheet.get_node("%PrizeChip").visible)


## The card was anchored 0.3-0.78 vertically, so it was 922px tall at
## 1080x1920 and 1152px at 1080x2400 for ~350px of content -- emptier the
## taller the phone. Centred anchors with GROW_DIRECTION_BOTH make a
## Control clamp up to its combined minimum size and split the extra evenly
## about the anchor, so the card is exactly as tall as its content.
func test_sheet_card_is_content_sized_and_centred() -> void:
	var src := FileAccess.get_file_as_string(SHEET)
	assert_false(src.contains("anchor_top = 0.3"), "the fractional height anchors must be gone")
	assert_false(src.contains("anchor_bottom = 0.78"))
	assert_true(src.contains("offset_left = -432.0") and src.contains("offset_right = 432.0"),
		"width stays 864, expressed as offsets about the centre")
	assert_true(src.contains("grow_horizontal = 2") and src.contains("grow_vertical = 2"))


func test_sheet_uses_the_space_lg_rhythm() -> void:
	var src := FileAccess.get_file_as_string(SHEET)
	assert_true(src.contains("theme_override_constants/separation = 44"),
		"the stack is on space_lg (44), not the old 12")
	assert_true(src.contains("custom_minimum_size = Vector2(0, 300)"), "the icon slot is 300 tall")
	assert_true(src.contains("custom_minimum_size = Vector2(96, 96)"), "the back arrow meets the touch floor")
	assert_true(src.contains('[node name="StateRow" type="HBoxContainer"'))
	assert_false(src.contains('[node name="ActionArea"'))


func test_sheet_body_label_variation_is_body_size() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_type_variation_base("AchievementSheetBodyLabel"), &"Label")
	assert_eq(theme.get_font_size("font_size", "AchievementSheetBodyLabel"), tokens.font_body_size)
	assert_eq(theme.get_color("font_color", "AchievementSheetBodyLabel"), tokens.text_secondary)
```

Delete `test_locked_shows_lock_and_hides_claim_and_claimed`, `test_unlocked_shows_claim_and_hides_lock_and_claimed` and `test_claimed_shows_caption_and_hides_claim_and_lock`.

In `tests/test_achievements_api.gd`, delete whatever covers `AchievementCatalog.description_of` (grep for `description_of`) and add:

```gdscript
## description_of() baked the prize into the desc for the detail sheet,
## which then printed it a second time in its own label. The sheet reads
## entry.desc directly now and the prize lives in a chip, so the helper has
## no callers.
func test_description_of_is_gone() -> void:
	assert_false(AchievementCatalog.has_method("description_of"))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="achievement_detail_sheet")` and `test_run(suite="achievements_api")`
Expected: FAIL — `%StateIcon`, `%PrizeChip` and the variation do not exist; the anchors and separation are the old ones; `description_of` still exists.

- [ ] **Step 3: Add the theme variation**

`script_patch` on `Scripts/Design/ThemeFactory.gd`, next to `AchievementTileTitleLabel`:

```gdscript
	# The detail sheet's description. CaptionLabel (22) was too small for a
	# full sentence on an 864-wide card; this is the body step in the
	# secondary ink, so the title above it keeps the hierarchy.
	theme.add_type("AchievementSheetBodyLabel")
	theme.set_type_variation("AchievementSheetBodyLabel", "Label")
	theme.set_font_size("font_size", "AchievementSheetBodyLabel", tokens.font_body_size)
	theme.set_color("font_color", "AchievementSheetBodyLabel", tokens.text_secondary)
	if tokens.font_body != null:
		theme.set_font("font", "AchievementSheetBodyLabel", tokens.font_body)
```

- [ ] **Step 4: Rebake the theme, then restart the editor**

Same as Task 2 Step 4.

- [ ] **Step 5: Rebuild the sheet scene**

`scene_open(path="res://Scenes/Achievements/AchievementDetailSheet.tscn")`, then `batch_execute`:

Card:
1. `set_property` `/AchievementDetailSheet/Sheet` `anchor_left` = `0.5`
2. … `anchor_top` = `0.5`
3. … `anchor_right` = `0.5`
4. … `anchor_bottom` = `0.5`
5. … `offset_left` = `-432`
6. … `offset_top` = `-60`
7. … `offset_right` = `432`
8. … `offset_bottom` = `60`
9. … `grow_horizontal` = `2`
10. … `grow_vertical` = `2`

Spacing:
11. `set_property` `…/Sheet/Margin` `theme_override_constants/margin_left` = `56`
12. … `margin_right` = `56`
13. … `margin_top` = `40`
14. … `margin_bottom` = `64`
15. `set_property` `…/Sheet/Margin/VBox` `theme_override_constants/separation` = `44`

Elements:
16. `set_property` `…/VBox/BackButton` `custom_minimum_size` = `Vector2(96, 96)`
17. `set_property` `…/VBox/IconSlot` `custom_minimum_size` = `Vector2(0, 300)`
18. `set_property` `…/VBox/IconSlot/Icon` `offset_left` = `-150`, `offset_top` = `-150`, `offset_right` = `150`, `offset_bottom` = `150`
19. `set_property` `…/VBox/Desc` `theme_type_variation` = `AchievementSheetBodyLabel`
20. `delete_node` `…/VBox/PrizeLabel`
21. `delete_node` `…/VBox/ActionArea` (removes `ClaimButton`, `LockIcon`, `ClaimedLabel`)

New nodes (each `create_node` then its `set_property` calls):

22. `PanelContainer` `PrizeChip` under `…/VBox`: `unique_name_in_owner` = `true`, `size_flags_horizontal` = `4`, `mouse_filter` = `2`, `theme_type_variation` = `AchievementPrizeChipAmber`
23. `Label` `PrizeChipLabel` under `…/VBox/PrizeChip`: `unique_name_in_owner` = `true`, `theme_type_variation` = `AchievementPrizeChipLabelAmber`, `horizontal_alignment` = `1`
24. `HBoxContainer` `StateRow` under `…/VBox`: `unique_name_in_owner` = `true`, `alignment` = `1`, `theme_override_constants/separation` = `28`
25. `move_node` `…/VBox/ProgressLabel` into `…/VBox/StateRow`, and set its `theme_type_variation` = `TitleLabel`
26. `TextureRect` `StateIcon` under `…/VBox/StateRow`: `unique_name_in_owner` = `true`, `custom_minimum_size` = `Vector2(72, 72)`, `expand_mode` = `1`, `stretch_mode` = `5`, `mouse_filter` = `2`

Order inside `VBox` must end as `BackButton, IconSlot, Title, Desc, PrizeChip, StateRow` — use `move_node` to fix any that `create_node` appended out of place, then `scene_save()`.

- [ ] **Step 6: Rewrite `_refresh_content`**

`script_patch` on `Scripts/Achievements/AchievementDetailSheet.gd`.

Replace the `@onready` block's four dead members with:

```gdscript
@onready var _prize_chip: PanelContainer = %PrizeChip
@onready var _prize_chip_label: Label = %PrizeChipLabel
@onready var _state_icon: TextureRect = %StateIcon
```

Add above `_refresh_content`:

```gdscript
## The three state glyphs the StateRow shows, one per Achievements state.
## The notice icon is the same asset the tile's corner badge wears, so a
## player who tapped a marked tile sees the same mark inside.
const _LOCK_ICON := preload("res://Assets/Images/UI/Placeholders/icon_lock.svg")
const _NOTICE_ICON := preload("res://Assets/Images/Achievements/notice_icon.png")
const _CHECK_ICON := preload("res://Assets/Images/UI/Placeholders/icon_check.svg")
```

Replace the tail of `_refresh_content` (from `_desc_label.text` down):

```gdscript
	_desc_label.text = entry.desc

	var prize := String(entry.get("prize", ""))
	_prize_chip.visible = prize != ""
	_prize_chip_label.text = prize

	_progress_label.visible = not (entry.kind in _ONE_SHOT_KINDS)
	if _progress_label.visible and achievements != null:
		var frac: Vector2i = achievements.progress_fraction_of(achievement_id)
		_progress_label.text = "%d / %d" % [frac.x, frac.y]

	match state:
		AchievementsScript.STATE_UNLOCKED:
			_state_icon.texture = _NOTICE_ICON
		AchievementsScript.STATE_CLAIMED:
			_state_icon.texture = _CHECK_ICON
		_:
			_state_icon.texture = _LOCK_ICON
```

Delete `_on_claim_pressed` and its `_claim_button.pressed.connect` line in `_ready`.

`script_patch` on `Scripts/Achievements/AchievementCatalog.gd`: delete `description_of()` and its `##` comment.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `test_run(suite="achievement_detail_sheet")` and `test_run(suite="achievements_api")`
Expected: PASS. `test_claim_button_emits_claim_requested_for_unlocked_entry` will still FAIL — Task 6 replaces it.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Achievements/AchievementDetailSheet.tscn Scripts/Achievements/AchievementDetailSheet.gd Scripts/Achievements/AchievementCatalog.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_achievement_detail_sheet.gd tests/test_achievements_api.gd
git commit -m "feat(achievements): rebuild the detail popup on the space_lg rhythm"
```

---

### Task 6: Claim by opening the popup

The Klaim button is gone; opening the popup on an unlocked achievement claims it. The notice badge on the tile is now the affordance.

**Files:**
- Modify: `Scripts/Achievements/AchievementDetailSheet.gd` (`open_for`)
- Test: `tests/test_achievement_detail_sheet.gd`

**Interfaces:**
- Consumes: Task 5's rebuilt sheet.
- Produces: `open_for(id)` emits `claim_requested(id)` when the state is `STATE_UNLOCKED`. `achievements_screen.gd` is unchanged — its `_on_claim_requested` already does `Achievements.claim(id)` → `tap` sfx → `AchievementClaimPopup`.

- [ ] **Step 1: Write the failing tests**

Replace `test_claim_button_emits_claim_requested_for_unlocked_entry` with:

```gdscript
## The Klaim button is gone (the user's brief). Opening the popup on an
## unlocked achievement is the claim. The emit is deferred so the sheet is
## already visible and laid out when the host screen's celebration lands on
## top of it -- so the test flushes the deferred call itself rather than
## awaiting a frame, which the runner forbids.
func test_opening_an_unlocked_entry_requests_the_claim() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var sheet := _new_sheet()
	var got: Array[String] = []
	sheet.claim_requested.connect(func(id: String): got.append(id))
	sheet.open_for(PLAIN_ID)
	assert_true(sheet.visible, "the sheet shows before the claim goes out")
	# open_for() defers the emit so the sheet is laid out before the host
	# screen's celebration lands on it. A test cannot await the deferred
	# flush (the runner forbids coroutines), so it calls the deferred half
	# directly -- which is also why that half is its own named function.
	sheet._emit_claim_if_unlocked()
	assert_eq(got, [PLAIN_ID])
	# The sheet still never calls Achievements.claim itself -- that stays
	# the host screen's job, so the state is untouched here.
	assert_eq(_achievements().state_of(PLAIN_ID), ACHIEVEMENTS.STATE_UNLOCKED)


func test_opening_a_locked_entry_requests_nothing() -> void:
	var sheet := _new_sheet()
	var got: Array[String] = []
	sheet.claim_requested.connect(func(id: String): got.append(id))
	sheet.open_for(PLAIN_ID)
	sheet._emit_claim_if_unlocked()
	assert_eq(got, [])


func test_opening_a_claimed_entry_requests_nothing() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	_achievements().claim(PLAIN_ID)
	var sheet := _new_sheet()
	var got: Array[String] = []
	sheet.claim_requested.connect(func(id: String): got.append(id))
	sheet.open_for(PLAIN_ID)
	sheet._emit_claim_if_unlocked()
	assert_eq(got, [])


func test_no_claim_button_remains_in_the_scene() -> void:
	var src := FileAccess.get_file_as_string(SHEET)
	assert_false(src.contains("ClaimButton"))
	assert_false(src.contains('text = "Klaim"'))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="achievement_detail_sheet")`
Expected: FAIL — `_emit_claim_if_unlocked` does not exist.

- [ ] **Step 3: Implement**

`script_patch` on `Scripts/Achievements/AchievementDetailSheet.gd`.

Replace the tail of `open_for`:

```gdscript
	visible = true
	_open = true
	var achievements := _achievements()
	if achievements != null and not achievements.state_changed.is_connected(_refresh_content):
		achievements.state_changed.connect(_refresh_content)
	call_deferred("_emit_claim_if_unlocked")


## Claiming has no button any more: opening this sheet on an achievement
## whose prize is still waiting IS the claim, and the tile's notice badge
## is what told the player the prize was there.
##
## Deferred from open_for() so the sheet is visible and laid out before the
## host screen's celebration popup lands on top of it. The sheet still does
## not call Achievements.claim itself -- it emits and lets
## achievements_screen.gd's _on_claim_requested do the claim, the sfx and
## the popup, exactly as the old button did. Achievements.claim() returns
## false for any state that cannot be claimed, so re-opening a sheet that
## is mid-claim cannot double-claim.
func _emit_claim_if_unlocked() -> void:
	if not _open or achievement_id == "":
		return
	var achievements := _achievements()
	if achievements == null:
		return
	if achievements.state_of(achievement_id) != AchievementsScript.STATE_UNLOCKED:
		return
	claim_requested.emit(achievement_id)
```

Update the script's `##` header: replace the paragraph describing the Klaim button and the `claim_requested` wiring with a description of claim-on-open.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `test_run(suite="achievement_detail_sheet")`, `test_run(suite="achievement_screen")`, `test_run(suite="achievement_claim_popup")`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Achievements/AchievementDetailSheet.gd tests/test_achievement_detail_sheet.gd
git commit -m "feat(achievements): claim by opening the popup, not a button"
```

---

### Task 7: White outline on AturJadwal's student splash

The splash is the way into the student picker but reads as scenery. `icon_outline.gdshader` already traces an art's own alpha, so the ring follows the character.

**Files:**
- Create: `Assets/Images/SplashArtMurid/splash_outline_material.tres`
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (root `TextureButton`)
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing later tasks use.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_atur_jadwal.gd`:

```gdscript
const SPLASH_MATERIAL := "res://Assets/Images/SplashArtMurid/splash_outline_material.tres"


## The splash IS the student picker's button (_on_select_student_pressed)
## but carried no affordance. A white silhouette outline says "tappable"
## without adding chrome over the art.
##
## outline_width is a FRACTION of the node's rect, and the button's
## authored rect is 700x1244 -- so the achievement icons' 0.03 would be a
## 21px stroke and would visibly shrink the character (the shader pulls the
## art in by 2 * outline_width to make room). 0.009 is a ~6px stroke and a
## 1.8% shrink.
func test_splash_wears_the_white_outline_material() -> void:
	var mat := load(SPLASH_MATERIAL) as ShaderMaterial
	assert_not_null(mat, "splash_outline_material.tres must exist")
	if mat == null:
		return
	assert_eq(mat.shader.resource_path, "res://Scripts/Shaders/icon_outline.gdshader")
	assert_eq(mat.get_shader_parameter("outline_color"), Color(1, 1, 1, 1))
	assert_true(absf(float(mat.get_shader_parameter("outline_width")) - 0.009) < 0.0001,
		"0.009 of a 700px rect is a ~6px stroke, got %s" % mat.get_shader_parameter("outline_width"))


func test_splash_button_uses_that_material() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/AturJadwal/atur_jadwal.tscn")
	assert_true(src.contains(SPLASH_MATERIAL), "atur_jadwal.tscn must reference the outline material")
	var lines := src.split("\n")
	var i := 0
	var found := false
	while i < lines.size():
		if lines[i].begins_with('[node name="TextureButton" type="TextureButton" parent="."'):
			var j := i + 1
			while j < lines.size() and not lines[j].begins_with("[node"):
				if lines[j].begins_with("material = ExtResource("):
					found = true
				j += 1
		i += 1
	assert_true(found, "the root TextureButton (the student splash) must carry the material")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test_run(suite="atur_jadwal")`
Expected: FAIL — the `.tres` does not exist, so `load` returns null.

- [ ] **Step 3: Create the material**

`filesystem_manage(op="write_text")` to `res://Assets/Images/SplashArtMurid/splash_outline_material.tres`:

```
[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://Scripts/Shaders/icon_outline.gdshader" id="1_outline"]

[resource]
shader = ExtResource("1_outline")
shader_parameter/outline_color = Color(1, 1, 1, 1)
shader_parameter/outline_width = 0.009
```

Then `filesystem_manage(op="scan")` so the editor registers it.

- [ ] **Step 4: Attach it in the scene**

```
scene_open(path="res://Scenes/AturJadwal/atur_jadwal.tscn")
node_set_property(path="/AturJadwal/TextureButton", property="material",
                  value="res://Assets/Images/SplashArtMurid/splash_outline_material.tres")
scene_save()
```

Confirm the root node's real name with `scene_get_hierarchy` first — the path above assumes the scene root is `AturJadwal`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="atur_jadwal")` and `test_run(suite="tall_screen_layout")`
Expected: PASS. `tall_screen_layout` pins the button's authored rect; a material does not change it.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/SplashArtMurid/splash_outline_material.tres Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd
git commit -m "feat(atur-jadwal): outline the student splash so it reads as tappable"
```

---

### Task 8: Remove Koperasi's crate handle

`koperasi fix.png` circles `Stage/CrateHandle`. The tray's drag already toggles it in both directions — `BasketTray` wires `gui_input` on `Body`, and `tray_offset_collapsed` (190) against a Body running 1360–1920 leaves 370px on screen to grab.

**Files:**
- Modify: `Scenes/Koperasi/koprasi.tscn`
- Modify: `Scripts/Koperasi/koprasi.gd`
- Test: `tests/test_koperasi_back_follows_tray.gd`, `tests/test_koperasi_tray_retract.gd`, `tests/test_basket_tray.gd`, `tests/test_koperasi.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `koprasi.gd` loses `crate`, `crate_pos_expanded`, `crate_pos_collapsed`, `_on_crate_pressed`, `_refresh_crate_badge`, `_crate_tween`; gains `_back_tween`. `back_pos_collapsed` becomes `Vector2(24.0, 1353.0)`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_koperasi_back_follows_tray.gd`, replace `test_collapsed_gap_against_crate_top_is_12px` and `test_back_button_animates_inside_the_shared_crate_tween`:

```gdscript
## The crate handle is gone (koperasi fix.png). back_pos_collapsed's 1363
## was derived from the crate's collapsed top edge; it is now derived from
## the collapsed TRAY's top edge, with the same 12px gap:
## 1360 (TrayDock 117 + Body 1243) + 190 (tray_offset_collapsed)
##   - 185 (BackButton height) - 12 = 1353.
func test_collapsed_gap_against_collapsed_tray_top_is_12px() -> void:
	var script_src := _read(KOPRASI_GD)
	var scene_src := _read(KOPRASI_TSCN)
	if script_src.is_empty() or scene_src.is_empty():
		return
	var collapsed := _vector2_after(script_src, "@export var back_pos_collapsed: Vector2 =")
	var back_block := _node_block(scene_src, "[node name=\"BackButton\" type=\"TextureButton\" parent=\"Stage\"")
	var back_height := _prop_float(back_block, "offset_bottom") - _prop_float(back_block, "offset_top")
	var tray_dock_block := _node_block(scene_src, "[node name=\"TrayDock\" type=\"Control\" parent=\"Stage\"")
	var tray_src := _read("res://Scenes/Koperasi/BasketTray.tscn")
	var body_block := _node_block(tray_src, "[node name=\"Body\" type=\"Control\" parent=\".\"")
	var tray_script := _read("res://Scripts/Koperasi/BasketTray.gd")
	var offset_at := tray_script.find("@export var tray_offset_collapsed: float =")
	assert_true(offset_at != -1, "tray_offset_collapsed must exist")
	var offset_collapsed := float(tray_script.substr(offset_at, 80).split("=")[1].split("\n")[0].strip_edges())
	var tray_top := _prop_float(tray_dock_block, "offset_top") + _prop_float(body_block, "offset_top") + offset_collapsed
	var gap := tray_top - (collapsed.y + back_height)
	assert_true(absf(gap - 12.0) < 0.5,
		"collapsed gap against the collapsed tray's top should be 12px, got %s" % gap)


## With no crate to share a tween with, the back button gets its own --
## still exactly one tween per gesture.
func test_back_button_animates_on_its_own_tween() -> void:
	var src := _read(KOPRASI_GD)
	if src.is_empty():
		return
	var start := src.find("func _on_tray_state_changed(")
	assert_true(start != -1, "_on_tray_state_changed must exist")
	if start == -1:
		return
	var next_func := src.find("\nfunc ", start + 1)
	if next_func == -1:
		next_func = src.length()
	var body := src.substr(start, next_func - start)
	assert_true(body.contains("_back_tween.tween_property(back_button,"))
	assert_eq(body.count("create_tween()"), 1, "exactly one tween per gesture")
	assert_true(body.contains("back_pos_expanded if expanded else back_pos_collapsed"))


func test_crate_handle_is_gone_everywhere() -> void:
	var scene_src := _read(KOPRASI_TSCN)
	var script_src := _read(KOPRASI_GD)
	assert_false(scene_src.contains("CrateHandle"), "CrateHandle must be deleted from koprasi.tscn")
	assert_false(scene_src.contains("AnimationLibrary_crate"), "its animation library goes with it")
	assert_false(script_src.contains("crate_pos_expanded"))
	assert_false(script_src.contains("crate_pos_collapsed"))
	assert_false(script_src.contains("_refresh_crate_badge"))
	assert_false(script_src.contains("_on_crate_pressed"))


## The crate was one of two ways to toggle the tray. The other -- the drag
## on Body -- must still be wired, or removing the crate would strand a
## collapsed tray.
func test_the_drag_still_toggles_the_tray() -> void:
	var tray_script := _read("res://Scripts/Koperasi/BasketTray.gd")
	assert_true(tray_script.contains("_body.gui_input.connect(_on_body_gui_input)"),
		"the drag is the only remaining toggle and must stay wired to Body")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="koperasi_back_follows_tray")`
Expected: FAIL — `CrateHandle` is still in the scene and `_back_tween` does not exist.

- [ ] **Step 3: Delete the node**

```
scene_open(path="res://Scenes/Koperasi/koprasi.tscn")
node_manage(op="delete", path="/Koperasi/Stage/CrateHandle")
scene_save()
```

Confirm the root name with `scene_get_hierarchy` first. Deleting the node drops its `Art`, `AP` and `CountBadge` children; Godot drops the now-unreferenced `AnimationLibrary_crate` sub-resource on save. Verify with `grep -c "AnimationLibrary_crate" Scenes/Koperasi/koprasi.tscn` — expect 0.

- [ ] **Step 4: Strip the crate from the script**

`script_patch` on `Scripts/Koperasi/koprasi.gd`:

- Delete `@onready var crate: TextureButton = ...`
- Delete the `crate_pos_expanded` and `crate_pos_collapsed` exports with their `##` comments
- Delete `func _on_crate_pressed()` and `func _refresh_crate_badge()`
- Delete the `if is_instance_valid(crate) ...` blocks in `_ready`, and both `_refresh_crate_badge()` calls
- Rename `var _crate_tween: Tween` to `var _back_tween: Tween` and update its `##` comment:

```gdscript
## The tween sliding the back button between its two positions as the tray
## opens and closes; killed before a new one starts so two quick toggles
## never fight. It used to be the crate handle's tween, which the button
## rode along on -- the crate went with the 2026-09-22 pass, so the button
## owns it now.
var _back_tween: Tween
```

- Set `@export var back_pos_collapsed: Vector2 = Vector2(24.0, 1353.0)` and rewrite its `##` comment to derive 1353 from the collapsed tray's top edge (1360 + 190 − 185 − 12), not the crate's.
- Replace `_on_tray_state_changed` wholesale:

```gdscript
## Slides the back button between its two positions as the tray opens and
## closes, and mutes Pak Herman's idle chatter while the tray is tucked
## away (a collapsed tray means the player is busy browsing the shelf, not
## the cart).
##
## The button used to ride the crate handle's tween as one piece. The crate
## went with the 2026-09-22 pass, so the button owns the tween now -- still
## one tween per user gesture, killed before a new one starts.
func _on_tray_state_changed(state: int) -> void:
	var expanded: bool = state == BasketTray.ViewState.EXPANDED
	if is_instance_valid(_back_tween) and _back_tween.is_valid():
		_back_tween.kill()
	if back_button:
		_back_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_back_tween.tween_property(back_button, "position",
			back_pos_expanded if expanded else back_pos_collapsed, 0.28)
	if bubble:
		bubble.idle_chatter_enabled = expanded
		bubble.reset_idle_timer()
```

Note the early `if not is_instance_valid(crate): return` guard is gone — it used to skip the bubble's chatter toggle whenever the crate was missing, which was a latent bug.

- [ ] **Step 5: Clear the remaining crate references in the other suites**

Run `grep -n "crate\|Crate" tests/test_koperasi_tray_retract.gd tests/test_basket_tray.gd tests/test_koperasi.gd` and handle each hit by kind:

- A **comment** mentioning the crate: reword it to describe the drag, or delete the clause. `tests/test_koperasi.gd:96`'s comment about nodes that "legitimately key their own local position" keeps the back button and drops "crate handle".
- An **assertion** on `CrateHandle`, `crate_pos_expanded`, `crate_pos_collapsed`, `_crate_tween`, `_on_crate_pressed` or `_refresh_crate_badge`: delete the whole test function. Task 8 Step 1's `test_crate_handle_is_gone_everywhere` is what replaces its coverage.
- `tests/test_basket_tray.gd:270`'s comment about the count moving to `CrateHandle`: reword to say the count now shows only on the tray's own slots, and that the crate carried it until 2026-09-22.

Do not leave a test asserting the crate's absence in more than one suite — `koperasi_back_follows_tray` owns that assertion.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `test_run(suite="koperasi_back_follows_tray")`, `test_run(suite="koperasi_tray_retract")`, `test_run(suite="basket_tray")`, `test_run(suite="koperasi")`, `test_run(suite="koperasi_tray")`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add Scenes/Koperasi/koprasi.tscn Scripts/Koperasi/koprasi.gd tests/test_koperasi_back_follows_tray.gd tests/test_koperasi_tray_retract.gd tests/test_basket_tray.gd tests/test_koperasi.gd
git commit -m "fix(koperasi): drop the crate handle and let the drag own the tray"
```

---

### Task 9: The student rail's tile

The six squares in the mockup are all six characters, not the roster. Each shows that student's face cropped out of the splash they are pending, through the existing `SkinFrame`.

**Files:**
- Create: `Scenes/Skins/StudentTile.tscn`, `Scripts/Skins/StudentTile.gd`
- Modify: `Scripts/Skins/SkinFrame.gd` (a `show_border` knob)
- Modify: `Scripts/Design/ThemeFactory.gd`
- Test: `tests/test_skin_frame.gd`, and a new `tests/test_student_tile.gd`

**Interfaces:**
- Consumes: `SkinFrame.show_art(tex, center)` and `StudentSkins.layer_path(name, id, "splash")`, both already public.
- Produces: `class_name StudentTile extends Button`, with `student_name: String`, `func show_student(name: String, skin_id: String) -> void` and `func set_open(open: bool) -> void`. `SkinFrame` gains `@export var show_border: bool`. Theme variations `SkinStudentTile`, `SkinStudentTileActive`, `SkinNameLabel`, `SkinWornChip`, `SkinWornChipLabel`. Task 11 instances six tiles and uses the other three variations.

- [ ] **Step 1: Write the failing tests**

New file `tests/test_student_tile.gd`:

```gdscript
@tool
extends McpTestSuite

## StudentTile.tscn / .gd: one of the six squares in SkinSelect's rail
## (spec: docs/superpowers/specs/2026-09-22-skin-select-screen-design.md
## section 4, "The six squares"). Shows a student's face cropped out of the
## splash of whichever skin they are pending.

const TILE := "res://Scenes/Skins/StudentTile.tscn"


func suite_name() -> String:
	return "student_tile"


func _new_tile() -> StudentTile:
	var tile: StudentTile = (load(TILE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(tile)
	track(tile)
	return tile


func test_show_student_loads_that_skins_splash() -> void:
	var tile := _new_tile()
	tile.show_student("Shinta", StudentSkins.DEFAULT_ID)
	assert_eq(tile.student_name, "Shinta")
	var art := tile.get_node("Frame/Mask/Art") as TextureRect
	assert_not_null(art.texture, "the crop must have a texture")
	assert_eq(art.texture.resource_path,
		StudentSkins.layer_path("Shinta", StudentSkins.DEFAULT_ID, "splash"))


func test_show_student_follows_the_pending_skin_not_the_equipped_one() -> void:
	var tile := _new_tile()
	tile.show_student("Shinta", "skin1")
	var art := tile.get_node("Frame/Mask/Art") as TextureRect
	assert_eq(art.texture.resource_path, StudentSkins.layer_path("Shinta", "skin1", "splash"))


## The open student is marked by a stylebox swap, not by resizing: growing
## the square would re-lay the whole rail out on every switch, for
## legibility the ring already buys.
func test_set_open_swaps_the_variation_and_keeps_the_size() -> void:
	var tile := _new_tile()
	tile.show_student("Andi", StudentSkins.DEFAULT_ID)
	var size_before := tile.custom_minimum_size
	tile.set_open(false)
	assert_eq(tile.theme_type_variation, &"SkinStudentTile")
	tile.set_open(true)
	assert_eq(tile.theme_type_variation, &"SkinStudentTileActive")
	assert_eq(tile.custom_minimum_size, size_before, "the tile must not resize on select")


func test_tile_is_150_square_and_meets_the_touch_floor() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains("custom_minimum_size = Vector2(150, 150)"))


## SkinFrame draws its own brown border. Inside a StudentTile the box is the
## Button's own stylebox, so the frame's border would double it -- hence the
## show_border knob, which is an @export on SkinFrame's ROOT because
## overrides set on an instanced scene's CHILDREN are dropped on save.
func test_tile_turns_the_frames_own_border_off() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains("show_border = false"))


func test_variations_differ_in_ring_colour() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_type_variation_base("SkinStudentTile"), &"Button")
	assert_eq(theme.get_type_variation_base("SkinStudentTileActive"), &"Button")
	var idle := theme.get_stylebox("normal", "SkinStudentTile") as StyleBoxFlat
	var open := theme.get_stylebox("normal", "SkinStudentTileActive") as StyleBoxFlat
	assert_eq(idle.border_color, tokens.text_primary)
	assert_eq(open.border_color, tokens.brand_primary)
	assert_eq(open.bg_color, tokens.outline_card)
```

Add to `tests/test_skin_frame.gd`:

```gdscript
## StudentTile draws its own box, so it needs the frame's border off. The
## knob is on SkinFrame's root, not on Border, because a property set on an
## instanced scene's child does not serialise.
func test_show_border_hides_the_border_node() -> void:
	var frame: SkinFrame = (load("res://Scenes/Skins/SkinFrame.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(frame)
	track(frame)
	assert_true(frame.get_node("Border").visible, "the border is on by default")
	frame.show_border = false
	assert_false(frame.get_node("Border").visible)
	frame.show_border = true
	assert_true(frame.get_node("Border").visible)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="student_tile")` and `test_run(suite="skin_frame")`
Expected: FAIL — `StudentTile.tscn` does not exist (the `load` returns null), and `show_border` is not a property.

- [ ] **Step 3: Add the theme variations**

`script_patch` on `Scripts/Design/ThemeFactory.gd`: add a `_build_skin_select(theme, tokens)` and call it from `build()` beside the other `_build_*` calls.

```gdscript
## SkinSelect (spec:
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md): the six
## student squares in two states, the skin's name, and the "sedang dipakai"
## chip that is the only visible proof TERAPKAN did anything.
static func _build_skin_select(theme: Theme, tokens: DesignTokens) -> void:
	var square := func(bg: Color, border: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.border_color = border
		box.set_border_width_all(int(tokens.outline_width))
		box.set_corner_radius_all(tokens.radius_md)
		return box

	theme.add_type("SkinStudentTile")
	theme.set_type_variation("SkinStudentTile", "Button")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "SkinStudentTile",
			square.call(tokens.surface_card, tokens.text_primary))

	theme.add_type("SkinStudentTileActive")
	theme.set_type_variation("SkinStudentTileActive", "Button")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "SkinStudentTileActive",
			square.call(tokens.outline_card, tokens.brand_primary))

	theme.add_type("SkinNameLabel")
	theme.set_type_variation("SkinNameLabel", "Label")
	theme.set_font_size("font_size", "SkinNameLabel", tokens.font_title)
	theme.set_color("font_color", "SkinNameLabel", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "SkinNameLabel", tokens.font_display)

	theme.add_type("SkinWornChip")
	theme.set_type_variation("SkinWornChip", "PanelContainer")
	var chip := StyleBoxFlat.new()
	chip.bg_color = tokens.state_success.lightened(0.7)
	chip.border_color = tokens.state_success
	chip.set_border_width_all(int(tokens.outline_width / 2.0))
	chip.set_corner_radius_all(tokens.radius_pill)
	chip.content_margin_left = tokens.space_md
	chip.content_margin_right = tokens.space_md
	chip.content_margin_top = tokens.space_xs
	chip.content_margin_bottom = tokens.space_xs
	theme.set_stylebox("panel", "SkinWornChip", chip)

	theme.add_type("SkinWornChipLabel")
	theme.set_type_variation("SkinWornChipLabel", "Label")
	theme.set_font_size("font_size", "SkinWornChipLabel", tokens.font_micro)
	theme.set_color("font_color", "SkinWornChipLabel", tokens.state_success.darkened(0.45))
	if tokens.font_display != null:
		theme.set_font("font", "SkinWornChipLabel", tokens.font_display)
```

`SkinNameLabel` and `SkinWornChipLabel` both take `font_display`, so add both to `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`:

```gdscript
	# 2026-09-22 SkinSelect: the skin's name and the "sedang dipakai" chip.
	"SkinNameLabel", "SkinWornChipLabel",
```

- [ ] **Step 4: Rebake the theme, then restart the editor**

Run `Scripts/Design/BakeTheme.gd` alone via File > Run (Ctrl+Shift+X), check `git diff --stat` shows only `Assets/Theme/kejartes_theme.tres`, then restart the editor.

- [ ] **Step 5: Add the `show_border` knob**

`script_patch` on `Scripts/Skins/SkinFrame.gd`, next to the other exports:

```gdscript
## Whether the frame draws its own brown outline. StudentTile turns it off
## because its Button stylebox already draws the box, and two borders on the
## same 150px square read as a smudge. The knob is on this root, not on the
## Border node, because a property set on an instanced scene's CHILD is
## reported as saved and then dropped.
@export var show_border: bool = true:
	set(v):
		show_border = v
		var border := get_node_or_null(^"Border") as Control
		if border != null:
			border.visible = v
```

And re-apply it once the children exist, by extending the existing `_notification`:

```gdscript
	if what == NOTIFICATION_READY:
		var border := get_node_or_null(^"Border") as Control
		if border != null:
			border.visible = show_border
```

- [ ] **Step 6: Create the tile**

`script_create` `res://Scripts/Skins/StudentTile.gd`:

```gdscript
@tool
class_name StudentTile
extends Button

## One of the six squares in SkinSelect's rail (StudentTile.tscn; mockup
## skinselection_mockup.png, spec
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md). It shows
## a character's face, cropped out of the splash of whichever skin they are
## pending, and marks whether the rail has that character open.
##
## All six characters get a tile, not just the approved roster:
## GameState.equipped_skins is keyed by NAME, not roster id, so a skin
## follows a character across the grade change that clears the roster.
##
## @tool so the test runner can drive it; it has no side effects of its own.

## The character shown, "" before show_student().
var student_name: String = ""


## Shows `name`'s face out of skin `skin_id`'s splash. An unknown student or
## skin clears the crop rather than erroring -- layer_path returns "".
func show_student(name: String, skin_id: String) -> void:
	student_name = name
	var path := StudentSkins.layer_path(name, skin_id, "splash")
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Frame") as SkinFrame).show_art(tex, StudentSkins.bust_center(name))


## Marks this tile as the one the rail has open. A stylebox swap, never a
## resize: growing the square would re-lay the whole rail out on every
## switch, and the ring already carries the state.
func set_open(open: bool) -> void:
	theme_type_variation = &"SkinStudentTileActive" if open else &"SkinStudentTile"
```

Then build the scene through the editor:

```
scene_manage(op="create", path="res://Scenes/Skins/StudentTile.tscn", root_type="Button", root_name="StudentTile")
scene_open(path="res://Scenes/Skins/StudentTile.tscn")
```

`batch_execute`:
1. `attach_script` `/StudentTile` → `res://Scripts/Skins/StudentTile.gd`
2. `set_property` `/StudentTile` `custom_minimum_size` = `Vector2(150, 150)`
3. `set_property` `/StudentTile` `theme_type_variation` = `SkinStudentTile`
4. `create_node` parent `/StudentTile`, instance `res://Scenes/Skins/SkinFrame.tscn`, name `Frame`
5. `set_property` `/StudentTile/Frame` `layout_mode` = `1`
6. `set_property` `/StudentTile/Frame` `anchor_right` = `1`
7. `set_property` `/StudentTile/Frame` `anchor_bottom` = `1`
8. `set_property` `/StudentTile/Frame` `grow_horizontal` = `2`
9. `set_property` `/StudentTile/Frame` `grow_vertical` = `2`
10. `set_property` `/StudentTile/Frame` `show_border` = `false`
11. `set_property` `/StudentTile/Frame` `visible_source_height` = `520`
12. `set_property` `/StudentTile/Frame` `face_y_ratio` = `0.5`

Then `scene_save()`.

Steps 10–12 set properties on the instance's **root**, which is the only place an override on an instanced scene serialises. An instanced scene's root also loses its rect under a plain parent, which is why steps 5–9 set `layout_mode` first and then the four anchors — `anchors_preset` is inert.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `test_run(suite="student_tile")`, `test_run(suite="skin_frame")`, `test_run(suite="theme_factory")`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Skins/StudentTile.tscn Scripts/Skins/StudentTile.gd Scripts/Skins/SkinFrame.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_student_tile.gd tests/test_skin_frame.gd tests/test_theme_factory.gd
git commit -m "feat(skins): add the SkinSelect student rail tile"
```

---

### Task 10: The skin card and the carousel's snap maths

One card per skin, the centred one crisp and the rest dimmed and blurred. The snap rule is a `static func` so it is testable without a tree or a frame, exactly as `BasketTray.classify_drag` is.

**Files:**
- Create: `Scenes/Skins/SkinCard.tscn`, `Scripts/Skins/SkinCard.gd`
- Test: new `tests/test_skin_card.gd`

**Interfaces:**
- Consumes: `Scenes/Skins/skin_option_blur_material.tres` (already in the tree) and `StudentSkins.layer_path`.
- Produces: `class_name SkinCard extends Control`, with `skin_id: String`, `func show_skin(name: String, id: String, locked: bool) -> void`, `func set_selected(sel: bool) -> void`, `@export var unselected_modulate: Color`, and `static func settle_index(current: int, travel: float, velocity: float, pitch: float, count: int) -> int`. Task 11 drives all of it.

- [ ] **Step 1: Write the failing tests**

New file `tests/test_skin_card.gd`:

```gdscript
@tool
extends McpTestSuite

## SkinCard.tscn / .gd: one skin in SkinSelect's carousel, and the static
## snap rule the carousel settles with (spec:
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md section 4,
## "The carousel"). settle_index is static so it is testable without a tree
## or a frame, the same shape as BasketTray.classify_drag.

const CARD := "res://Scenes/Skins/SkinCard.tscn"
const BLUR := "res://Scenes/Skins/skin_option_blur_material.tres"


func suite_name() -> String:
	return "skin_card"


func _new_card() -> SkinCard:
	var card: SkinCard = (load(CARD) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


func test_show_skin_loads_that_skins_splash() -> void:
	var card := _new_card()
	card.show_skin("Shinta", "skin1", false)
	assert_eq(card.skin_id, "skin1")
	var art := card.get_node("Art") as TextureRect
	assert_eq(art.texture.resource_path, StudentSkins.layer_path("Shinta", "skin1", "splash"))
	assert_false(card.get_node("Lock").visible)


func test_locked_skin_shows_the_lock() -> void:
	var card := _new_card()
	card.show_skin("Shinta", "skin1", true)
	assert_true(card.get_node("Lock").visible)


## The two-state swap from the spec: selected is crisp and full colour,
## unselected is dimmed and carries the blur material. Assigning a preloaded
## material is a reference swap, not runtime construction.
func test_selected_card_is_crisp_and_unselected_is_dimmed_and_blurred() -> void:
	var card := _new_card()
	card.show_skin("Shinta", StudentSkins.DEFAULT_ID, false)
	var art := card.get_node("Art") as TextureRect

	card.set_selected(true)
	assert_eq(art.modulate, Color.WHITE)
	assert_null(art.material, "the selected card must not be blurred")

	card.set_selected(false)
	assert_eq(art.modulate, card.unselected_modulate)
	assert_not_null(art.material)
	assert_eq(art.material.resource_path, BLUR)


## The splash art is 1080x1920 but the band above the tray is 1080x1337, so
## a card that filled the screen would crop the outfit at the knees -- on
## the one screen whose job is showing the outfit. 1337 tall at the art's
## own 9:16 is 752 wide.
func test_card_is_sized_to_fit_the_whole_figure_above_the_tray() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_true(src.contains("custom_minimum_size = Vector2(752, 1337)"))


func test_settle_index_stays_put_for_a_small_slow_drag() -> void:
	assert_eq(SkinCard.settle_index(0, 40.0, 0.0, 812.0, 2), 0)


func test_settle_index_advances_past_the_halfway_mark() -> void:
	assert_eq(SkinCard.settle_index(0, -500.0, 0.0, 812.0, 2), 1)


## A flick decides on its own, whatever distance it covered.
func test_settle_index_follows_a_fast_flick() -> void:
	assert_eq(SkinCard.settle_index(0, -20.0, -900.0, 812.0, 2), 1)
	assert_eq(SkinCard.settle_index(1, 20.0, 900.0, 812.0, 2), 0)


func test_settle_index_clamps_at_both_ends() -> void:
	assert_eq(SkinCard.settle_index(0, 900.0, 2000.0, 812.0, 2), 0)
	assert_eq(SkinCard.settle_index(1, -900.0, -2000.0, 812.0, 2), 1)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="skin_card")`
Expected: FAIL — `SkinCard.tscn` does not exist, so `load` returns null.

- [ ] **Step 3: Write the script**

`script_create` `res://Scripts/Skins/SkinCard.gd`:

```gdscript
@tool
class_name SkinCard
extends Control

## One skin in SkinSelect's carousel (SkinCard.tscn; mockup
## skinselection_mockup.png, spec
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md). The
## centred card is crisp and full colour; the ones either side are dimmed
## and blurred so the middle one reads as the selection.
##
## The card is 752x1337, not 1080x1920: the tray's top edge is at y=1337, so
## a full-screen splash would lose its bottom 583px -- the shoes and the
## skirt hem, on the one screen whose job is showing an outfit. Scaled to
## the band's height the figure is 752 wide and wholly visible, which also
## leaves 328px for the neighbouring card to peek into.
##
## @tool so the test runner can drive it; it has no side effects of its own.

## The blur worn by every card except the centred one. A preloaded resource
## swapped onto Art, never built at runtime.
const BLUR_MATERIAL := preload("res://Scenes/Skins/skin_option_blur_material.tres")

## Drag speed (px/s) past which a flick picks the next card on its own,
## whatever distance it covered. Mirrors BasketTray's own flick threshold so
## the two drag gestures in the game settle the same way.
const FLICK_SPEED := 600.0
## Fraction of one card's pitch a slow drag must cross to commit to the next
## card. 0.5 is the midpoint: past it the carousel moves on, short of it it
## springs back.
const COMMIT_RATIO := 0.5

## Tint on a card that is not the centred one.
@export var unselected_modulate: Color = Color(0.55, 0.55, 0.62, 1.0)

## The skin id shown, "" before show_skin().
var skin_id: String = ""


## Where a released drag settles. `travel` is how far the track has moved
## (negative is leftwards, towards a higher index) and `velocity` is the
## release speed in px/s, same sign convention. `pitch` is one card's width
## plus the track's separation. Static and tree-free so it can be tested
## without a frame -- the same shape as BasketTray.classify_drag.
static func settle_index(current: int, travel: float, velocity: float,
		pitch: float, count: int) -> int:
	var step := 0
	if absf(velocity) >= FLICK_SPEED:
		step = 1 if velocity < 0.0 else -1
	elif absf(travel) >= pitch * COMMIT_RATIO:
		step = 1 if travel < 0.0 else -1
	return clampi(current + step, 0, maxi(count - 1, 0))


## Shows skin `id` of `name`. `locked` draws the lock overlay; the card is
## still shown, because a player should see what they have not earned.
func show_skin(name: String, id: String, locked: bool) -> void:
	skin_id = id
	var path := StudentSkins.layer_path(name, id, "splash")
	var art := get_node(^"Art") as TextureRect
	art.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
	(get_node(^"Lock") as Control).visible = locked


## Crisp and full colour when centred, dimmed and blurred otherwise.
func set_selected(sel: bool) -> void:
	var art := get_node(^"Art") as TextureRect
	art.modulate = Color.WHITE if sel else unselected_modulate
	art.material = null if sel else BLUR_MATERIAL
```

- [ ] **Step 4: Build the scene**

```
scene_manage(op="create", path="res://Scenes/Skins/SkinCard.tscn", root_type="Control", root_name="SkinCard")
scene_open(path="res://Scenes/Skins/SkinCard.tscn")
```

`batch_execute`:
1. `attach_script` `/SkinCard` → `res://Scripts/Skins/SkinCard.gd`
2. `set_property` `/SkinCard` `custom_minimum_size` = `Vector2(752, 1337)`
3. `set_property` `/SkinCard` `mouse_filter` = `2`
4. `create_node` parent `/SkinCard`, type `TextureRect`, name `Art`
5. `set_property` `/SkinCard/Art` `layout_mode` = `1`
6. `set_property` `/SkinCard/Art` `anchor_right` = `1`
7. `set_property` `/SkinCard/Art` `anchor_bottom` = `1`
8. `set_property` `/SkinCard/Art` `grow_horizontal` = `2`
9. `set_property` `/SkinCard/Art` `grow_vertical` = `2`
10. `set_property` `/SkinCard/Art` `expand_mode` = `1`
11. `set_property` `/SkinCard/Art` `stretch_mode` = `5`
12. `set_property` `/SkinCard/Art` `mouse_filter` = `2`
13. `create_node` parent `/SkinCard`, type `TextureRect`, name `Lock`
14. `set_property` `/SkinCard/Lock` `visible` = `false`
15. `set_property` `/SkinCard/Lock` `layout_mode` = `1`
16. `set_property` `/SkinCard/Lock` `anchor_left` = `0.5`
17. `set_property` `/SkinCard/Lock` `anchor_top` = `0.5`
18. `set_property` `/SkinCard/Lock` `anchor_right` = `0.5`
19. `set_property` `/SkinCard/Lock` `anchor_bottom` = `0.5`
20. `set_property` `/SkinCard/Lock` `offset_left` = `-72`
21. `set_property` `/SkinCard/Lock` `offset_top` = `-72`
22. `set_property` `/SkinCard/Lock` `offset_right` = `72`
23. `set_property` `/SkinCard/Lock` `offset_bottom` = `72`
24. `set_property` `/SkinCard/Lock` `grow_horizontal` = `2`
25. `set_property` `/SkinCard/Lock` `grow_vertical` = `2`
26. `set_property` `/SkinCard/Lock` `texture` = `res://Assets/Images/UI/Placeholders/icon_lock.svg`
27. `set_property` `/SkinCard/Lock` `expand_mode` = `1`
28. `set_property` `/SkinCard/Lock` `stretch_mode` = `5`
29. `set_property` `/SkinCard/Lock` `mouse_filter` = `2`

Then `scene_save()`.

A `Control` created under a plain `Control` starts in position mode, where anchors are **not saved** — which is why `layout_mode = 1` is set before the anchors on both children.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `test_run(suite="skin_card")`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Skins/SkinCard.tscn Scripts/Skins/SkinCard.gd tests/test_skin_card.gd
git commit -m "feat(skins): add the SkinSelect carousel card and its snap rule"
```

---

### Task 11: Rebuild SkinSelect around them

The card popup becomes the full-bleed screen: title, carousel, dots, the six-square rail, the skin's name and worn chip, back and TERAPKAN. `SkinSelectPopup` is renamed `SkinSelect`, and the two nodes the old option column used are deleted.

**Files:**
- Rename: `Scenes/Skins/SkinSelectPopup.tscn` → `Scenes/Skins/SkinSelect.tscn`; `Scripts/Skins/SkinSelectPopup.gd` → `Scripts/Skins/SkinSelect.gd`; `tests/test_skin_select_popup.gd` → `tests/test_skin_select.gd`
- Delete: `Scenes/Skins/SkinSlot.tscn`, `Scripts/Skins/SkinSlot.gd`, `Scenes/Skins/SkinOptionTile.tscn`, `Scripts/Skins/SkinOptionTile.gd`
- Modify: `Scripts/Lobby/loby.gd`
- Test: `tests/test_skin_select.gd`, `tests/test_lobby_skins.gd`

**Interfaces:**
- Consumes: `StudentTile.show_student/set_open` (Task 9), `SkinCard.show_skin/set_selected/settle_index` (Task 10).
- Produces: `class_name SkinSelect extends Control`, with `open()` (no argument — it reads `StudentSkins.NAMES`, not the roster), `current_student()`, `pending_id(name)`, `select_skin(index)`, `select_student(index)`, `apply()`, `apply_without_closing()`, `close()`, `go_back()`, and the `closed` signal. `loby.gd` calls `open()`.

- [ ] **Step 1: Write the failing tests**

Rename the suite file, set `suite_name()` to `"skin_select"`, keep whatever in it still describes surviving behaviour (the blur material, the back-request handling), and replace the popup-era tests with:

```gdscript
const SCREEN := "res://Scenes/Skins/SkinSelect.tscn"

var _saved: Dictionary


func setup() -> void:
	_saved = GameState.equipped_skins.duplicate()
	GameState.equipped_skins = {}


func teardown() -> void:
	GameState.equipped_skins = _saved


func _new_screen() -> SkinSelect:
	var s: SkinSelect = (load(SCREEN) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(s)
	track(s)
	s.open()
	return s


## All six characters, not the roster: equipped_skins is keyed by NAME, so a
## skin follows a character across the grade change that clears the roster.
func test_rail_holds_all_six_characters_in_catalogue_order() -> void:
	var s := _new_screen()
	var rail := s.get_node("%Rail")
	assert_eq(rail.get_child_count(), StudentSkins.NAMES.size())
	for i in StudentSkins.NAMES.size():
		assert_eq((rail.get_child(i) as StudentTile).student_name, StudentSkins.NAMES[i])


func test_open_takes_no_argument_and_first_student_is_open() -> void:
	var s := _new_screen()
	assert_eq(s.current_student(), StudentSkins.NAMES[0])
	var rail := s.get_node("%Rail")
	assert_eq((rail.get_child(0) as StudentTile).theme_type_variation, &"SkinStudentTileActive")
	assert_eq((rail.get_child(1) as StudentTile).theme_type_variation, &"SkinStudentTile")


func test_carousel_holds_one_card_per_skin_of_the_open_student() -> void:
	var s := _new_screen()
	assert_eq(s.get_node("%Track").get_child_count(),
		StudentSkins.skins_for(StudentSkins.NAMES[0]).size())


## Sliding is a PENDING choice. Nothing is equipped until TERAPKAN, which is
## what lets one button serve all six characters in one visit.
func test_selecting_a_skin_does_not_equip_it() -> void:
	var s := _new_screen()
	var name := s.current_student()
	s.select_skin(1)
	assert_eq(s.pending_id(name), StudentSkins.skins_for(name)[1])
	assert_eq(GameState.equipped_skin(name), StudentSkins.DEFAULT_ID,
		"sliding must not equip -- TERAPKAN does")


func test_apply_commits_every_pending_student_at_once() -> void:
	var s := _new_screen()
	var first := StudentSkins.NAMES[0]
	var second := StudentSkins.NAMES[1]
	s.select_skin(1)
	s.select_student(1)
	s.select_skin(1)
	s.apply_without_closing()
	assert_eq(GameState.equipped_skin(first), StudentSkins.skins_for(first)[1])
	assert_eq(GameState.equipped_skin(second), StudentSkins.skins_for(second)[1])


func test_back_discards_every_pending_change() -> void:
	var s := _new_screen()
	var name := s.current_student()
	s.select_skin(1)
	s.go_back()
	assert_eq(GameState.equipped_skin(name), StudentSkins.DEFAULT_ID)


## The chip keys off the COMMITTED skin, not the centred one, so it
## disappears the moment the carousel moves and comes back after TERAPKAN.
## With two skins and both unlocked, that is the only on-screen proof the
## button did anything.
func test_worn_chip_tracks_the_committed_skin_not_the_selection() -> void:
	var s := _new_screen()
	assert_true(s.get_node("%WornChip").visible, "the default skin starts worn")
	s.select_skin(1)
	assert_false(s.get_node("%WornChip").visible)
	s.apply_without_closing()
	assert_true(s.get_node("%WornChip").visible)


func test_switching_students_keeps_each_ones_pending_choice() -> void:
	var s := _new_screen()
	var first := StudentSkins.NAMES[0]
	s.select_skin(1)
	s.select_student(1)
	s.select_student(0)
	assert_eq(s.pending_id(first), StudentSkins.skins_for(first)[1])


func test_commit_button_is_indonesian_and_not_danger_red() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains('text = "TERAPKAN"'), "UI text is Indonesian; APPLY is not")
	assert_false(src.contains('text = "APPLY"'))
	assert_true(src.contains('theme_type_variation = &"PrimaryButton"'),
		"brand brown, so the commit button and the red back arrow do not read as a pair")


func test_backdrop_still_blurs_the_live_lobby() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains("shop_hub_blur_material.tres"),
		"the live-screen blur is why this stays an overlay instead of a scene change")


func test_the_popup_era_nodes_are_gone() -> void:
	assert_false(ResourceLoader.exists("res://Scenes/Skins/SkinSlot.tscn"))
	assert_false(ResourceLoader.exists("res://Scenes/Skins/SkinOptionTile.tscn"))
	assert_false(ResourceLoader.exists("res://Scenes/Skins/SkinSelectPopup.tscn"))
```

In `tests/test_lobby_skins.gd`, rename `test_lobby_opens_the_popup_and_reseats_on_close` to `test_lobby_opens_skin_select_and_reseats_on_close` and point its class and scene references at `SkinSelect`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="skin_select")`
Expected: FAIL — `SkinSelect.tscn` does not exist yet.

- [ ] **Step 3: Rename and delete the files**

The editor was restarted at the end of Task 10, so it is not holding these open.

```bash
git mv Scenes/Skins/SkinSelectPopup.tscn Scenes/Skins/SkinSelect.tscn
git mv Scripts/Skins/SkinSelectPopup.gd Scripts/Skins/SkinSelect.gd
git mv Scripts/Skins/SkinSelectPopup.gd.uid Scripts/Skins/SkinSelect.gd.uid
git mv tests/test_skin_select_popup.gd tests/test_skin_select.gd
git mv tests/test_skin_select_popup.gd.uid tests/test_skin_select.gd.uid
git rm Scenes/Skins/SkinSlot.tscn Scripts/Skins/SkinSlot.gd Scripts/Skins/SkinSlot.gd.uid
git rm Scenes/Skins/SkinOptionTile.tscn Scripts/Skins/SkinOptionTile.gd Scripts/Skins/SkinOptionTile.gd.uid
sed -i 's#Scripts/Skins/SkinSelectPopup.gd#Scripts/Skins/SkinSelect.gd#' Scenes/Skins/SkinSelect.tscn
```

The `sed` fixes the scene's `ext_resource` path, which still points at the old script. This is the one moment a text edit to a `.tscn` is safe here: the editor has just been restarted and does not hold the file.

Then `filesystem_manage(op="scan")` and restart the editor, so the global `class_name` table drops `SkinSelectPopup`, `SkinSlot` and `SkinOptionTile`. A renamed `class_name` breaks the next `project_run` with *Could not find script for class* until that rescan has happened.

- [ ] **Step 4: Rebuild the scene**

`scene_open(path="res://Scenes/Skins/SkinSelect.tscn")`, delete `Safe` and `OptionLayer` entirely, keep `Blur`, and build this tree. Geometry is the spec's measured table; `%` marks `unique_name_in_owner = true`.

```
SkinSelect   Control, full rect
  Blur       ColorRect, full rect, shop_hub_blur_material.tres      [kept as-is]
  Title      %, Label, anchors top-wide, y 80..200, DisplayLabel, centred
  Carousel   %, Control, anchors wide, y 200..1337, clip_contents = true
    Track    %, HBoxContainer, separation 60, alignment 1
  Dots       %, HBoxContainer, anchors top-wide, y 1262..1302, separation 16, alignment 1
  Tray       Panel, anchors bottom-wide, y 1337..1920, SunkenPanel
    Rail       %, HBoxContainer, anchors top-wide, y 1431..1581, separation 23, alignment 1
    SkinName   %, Label, anchors top-wide, y 1601..1653, SkinNameLabel, centred
    WornChip   %, PanelContainer, anchors top-centre, y 1661..1709, SkinWornChip
      WornChipLabel  %, Label, SkinWornChipLabel, text "SEDANG DIPAKAI"
    BackButton %, TextureButton, x 40..240, y 1690..1845, return_button.png,
               ignore_texture_size = true, stretch_mode = 5
    Terapkan   %, Button, x 505..998, y 1710..1843, PrimaryButton, text "TERAPKAN"
```

`Rail`'s six `StudentTile` instances and `Dots`' two circles are **authored as nodes**, not built at runtime: `StudentSkins.NAMES` is a fixed six, and a student with more skins hides unused dots rather than creating any.

`Track`'s `SkinCard`s **are** per-call dynamic — the count depends on the open student — so they are instanced in `_rebuild_carousel()` from an `@export var card_scene: PackedScene`. That is the same exception `SkinSelectPopup` already held for its option column; carry its `##` justification across so `tests/test_viewport_editability.gd`'s `ALLOWED` entry still reads true.

Then `scene_save()`, and restart the editor before the script work in Step 5.

- [ ] **Step 5: Rewrite the script**

`script_patch` `Scripts/Skins/SkinSelect.gd`: `class_name SkinSelectPopup` → `class_name SkinSelect`, rewrite the `##` header for the new screen, and replace the body. The parts the tests pin:

```gdscript
## The character the rail currently has open.
func current_student() -> String:
	return StudentSkins.NAMES[_student_index]


## The skin `name` will be wearing after TERAPKAN -- their pending choice if
## they have one, else whatever they are wearing now.
func pending_id(name: String) -> String:
	return _pending.get(name, GameState.equipped_skin(name))


## Centres card `index` of the open student and records it as pending.
## Nothing is equipped here: TERAPKAN commits, which is what lets one button
## serve all six characters in one visit.
func select_skin(index: int) -> void:
	var ids := StudentSkins.skins_for(current_student())
	if index < 0 or index >= ids.size():
		return
	_skin_index = index
	_pending[current_student()] = ids[index]
	_apply_card_states()
	_slide_to(index)
	_refresh_tray()


## Opens character `index`'s skins, keeping every other character's pending
## choice. Jumps the carousel rather than animating -- every card under it
## has just been replaced, so a slide would animate the wrong art.
func select_student(index: int) -> void:
	if index < 0 or index >= StudentSkins.NAMES.size():
		return
	_student_index = index
	for i in StudentSkins.NAMES.size():
		(_rail.get_child(i) as StudentTile).set_open(i == index)
	_rebuild_carousel()
	_refresh_tray()


## Commits every pending choice and closes. equip_skin already returns false
## for a locked or unknown skin and no-ops when re-equipping the worn one,
## so the loop needs no guard of its own.
func apply() -> void:
	apply_without_closing()
	close()


## The half of apply() that does not close, so a test can watch the worn
## chip flip without the node freeing itself out from under it.
func apply_without_closing() -> void:
	for name in _pending:
		GameState.equip_skin(str(name), str(_pending[name]))
	_pending.clear()
	for i in StudentSkins.NAMES.size():
		var n: String = StudentSkins.NAMES[i]
		(_rail.get_child(i) as StudentTile).show_student(n, pending_id(n))
	_refresh_tray()


## The player-facing name of a skin id. One place to hang real names when
## the catalogue grows past "default" and "skin1".
static func skin_label(id: String) -> String:
	if id == StudentSkins.DEFAULT_ID:
		return "Seragam Sekolah"
	return "Seragam %s" % id.trim_prefix("skin")
```

`_refresh_tray()` sets `%SkinName.text` to `skin_label(pending_id(current_student()))`, and `%WornChip.visible` to `pending_id(name) == GameState.equipped_skin(name)` — the **committed** skin, not the centred one. A locked centred skin hides the chip and puts TERKUNCI in `%SkinName`'s place.

`open()` takes no argument: it builds the rail from `StudentSkins.NAMES`, calls `select_student(0)`, and keeps the existing fade-in and `AudioDirector.play_sfx(&"tap")`.

`go_back()` keeps its shape but has only one level now — there is no option column to close first — so it calls `close()`. `_unhandled_input`'s `ui_cancel` route and the `NOTIFICATION_WM_GO_BACK_REQUEST` route both stay.

The drag lives on `%Carousel`'s `gui_input`: record the press x and time, move `%Track.position.x` on motion, and on release call `SkinCard.settle_index(_skin_index, travel, velocity, pitch, count)` and pass the result to `select_skin()`. `pitch` is one card's width plus `%Track`'s separation, read from the first card rather than hardcoded.

- [ ] **Step 6: Rewire the Lobby**

`script_patch` `Scripts/Lobby/loby.gd`:

```gdscript
@export var skin_select_scene: PackedScene = preload("res://Scenes/Skins/SkinSelect.tscn")
```

`_skin_popup_open` → `_skin_select_open` (`replace_all`), `as SkinSelectPopup` → `as SkinSelect`, and drop the argument from the `popup.open(GameState.approved_students)` call.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `test_run(suite="skin_select")`, `test_run(suite="lobby_skins")`, `test_run(suite="student_skins")`, `test_run(suite="skin_frame")`, `test_run(suite="student_tile")`, `test_run(suite="skin_card")`, `test_run(suite="viewport_editability")`
Expected: all PASS. If `viewport_editability` fails, its `ALLOWED` entry still names `SkinSelectPopup` — rename it to `SkinSelect` rather than adding a new entry.

- [ ] **Step 8: Commit**

```bash
git add -A Scenes/Skins Scripts/Skins Scripts/Lobby/loby.gd tests/test_skin_select.gd tests/test_lobby_skins.gd tests/test_viewport_editability.gd
git commit -m "feat(skins): rebuild SkinSelect as a full-screen carousel picker"
```

---

### Task 12: Full suite, screenshots, and the docs

**Files:**
- Modify: `docs/superpowers/DEBT.md`
- Modify: `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Run the full suite**

Run: `test_run()` (no suite argument).

Budget one editor restart for this: a full run is 15–20s of near-continuous main-thread work and the plugin's transport does not survive it. The results are valid if the drop happens after the reply arrives.

Expected: no failures. A single failing theme assertion may be ordering — the `theme_rebake` suite rebakes in-process, so a suite that reads the baked theme before it runs sees the old bake. Re-run that suite alone before believing it.

- [ ] **Step 2: Check the tree for the two files a full run writes**

```bash
git status --porcelain
```

`Assets/Theme/kejartes_theme.tres` (rebaked by the `theme_rebake` suite) is intended here and should already be committed by Task 5. `default_bus_layout.tres` (rewritten by `AudioDirector` on boot) is not — `git checkout -- default_bus_layout.tres` if it appears.

- [ ] **Step 3: Look at all three screens at full size**

Seed and teleport rather than playing:

```
project_run(mode="main")
```

Then debug overlay (`F1`) → General → **⚡ Seed Playtest State**, and the **Scenes** tab to reach Lobby → Achievements, AturJadwal and Koperasi. Debug → Prestasi → "Buka semua" gives a grid with notice badges on it.

Capture each with `editor_screenshot(source="game", max_resolution=0)` and check, at full size:
- both grid columns are the same width, and rows line up across them
- a locked tile's title is readable
- the notice badge sits on the tile corner and does not clip
- the popup's spacing reads as roomy, and the card has no dead band
- the student splash has a white outline
- Koperasi has no crate, and dragging the tray still collapses and re-opens it
- SkinSelect shows the whole figure with its feet, the open student's square is
  ringed, the neighbour skin is dimmed and blurred, and TERAPKAN makes the
  SEDANG DIPAKAI chip come back

SkinSelect is reached from the Lobby's skin-switch button, so it needs no
teleport — seed, go to the Lobby, tap it. Drag the splash sideways to check the
snap, and tap two different squares to check that each keeps its own pending
choice.

- [ ] **Step 4: Update DEBT.md**

Delete the `AchievementBaruBadge` mention if one exists, and the "tray crate sits at scale 0.35 … a visible size mismatch" line from the Koperasi polish leftovers — the crate is gone, so that debt is resolved, and resolved entries are deleted, not marked done.

Add, under the Achievements group:

```markdown
**Achievements notice badge (2026-09-22).** The claimable badge is the
user's `notice_icon.png` — a red circled "!", which is the error idiom
everywhere else in this game. It ships as drawn; if it reads as an alarm
rather than a reward, recolour it to `state_warning` amber at the same
path, no code change needed.
```

Add, under the audit leftovers:

```markdown
**Achievements header (2026-09-22).** The status pill truncates
("2 HADIAH BELUM DIAMBIL" is clipped by the filter button at 1080 wide),
and `%FilterButton` (96px) and the pill (64px) are both under the ~130px
touch floor. Found in the 2026-09-22 design audit, deliberately left out of
that pass's scope.
```

And, under the skins group:

```markdown
**SkinSelect is still an overlay, not a scene (2026-09-22).** The brief
asked for a scene; it stayed a full-screen Lobby overlay because only an
overlay can blur the *live* lobby through `shop_hub_blur_material.tres` —
a `Transition.change_scene` would need a baked backdrop like
`bg_achievements_blur.jpg` and would stop showing the room the student is
standing in. Revisit only if the Lobby ever stops being the sole entry
point.

**SkinSelect's skin names are derived (2026-09-22).** `SkinSelect.skin_label`
turns `default` into "Seragam Sekolah" and `skin1` into "Seragam 1". Real
names belong in `StudentSkins.SKINS` once there is more than one extra skin
per character.
```

- [ ] **Step 5: Update CHANGELOG.md**

Add a newest-first entry describing the pass: symmetric columns, the rebuilt tile, the content-sized popup, claim-on-open, the splash outline and the crate removal. Include the measured numbers — 420/478 columns, 1.78:1 locked title — since they are the reason the pass exists.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md
git commit -m "docs: record the achievements layout pass"
```
