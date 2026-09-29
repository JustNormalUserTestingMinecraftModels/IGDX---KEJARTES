# Weekly Results Colours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the weekly report (`ResultCheckup`) under the role palette: a brown "HASIL MINGGUAN" title plate, a cream summary panel, the game-wide energy yellow and mood pink, and green/red chips marking each week's gain or loss, all on the weekly report only.

**Architecture:** Every new look is a `ThemeFactory` type variation (no `theme_override_*`), baked into `kejartes_theme.tres`. The title plate and the chip are static nodes authored in their `.tscn`. Runtime code only switches text, visibility and `theme_type_variation`. The shared card (`DaySummaryStudentRow`) gains one `_apply_look(week)` call at the top of each entry point, so only `setup_week_row` (the weekly report's path) turns the week look on.

**Tech Stack:** Godot 4.6, GDScript, the project's `DesignTokens` → `ThemeFactory` → baked theme pipeline, `McpTestSuite` tests run through the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-29-weekly-results-colours-design.md`

## Global Constraints

- Scope: the weekly report only. `DaySummaryPopup`, `ApplyStudentRow` and `EventStudentCard` must render exactly as today (purple/orange needs, gold chevrons, `+12/52`).
- Never add a `theme_override_*`. Only layout constants (`separation`, `margin_*`) may be overridden on a node.
- No visual built at runtime: new chrome is a node in the `.tscn`; scripts set text, visibility and variations only.
- Every new script member that is an `@export`, and every file header, carries a `##` doc line (`tests/test_script_documentation.gd`). Document every new function too, as the surrounding files do.
- New display-font variations join `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`.
- UI text is Indonesian: the title reads exactly `HASIL MINGGUAN`.
- The minus sign is the ASCII hyphen `-` (the display font's U+2212 coverage is not assumed).
- Work happens in the worktree `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/weekly-results-colours` on branch `feat/weekly-results-colours`. Use that absolute path for every file. Never edit the main checkout.
- Tests run in the worktree's OWN Godot editor (Task 1, Step 1). Pass its `session_id` on every godot-ai call; never call `session_activate`.
- Scene edits go through the editor (`batch_execute` + `scene_save`), never by hand while that editor is open. Do scene work before script work in a task, and after every `scene_save` run `git diff -- '*.gd'` to catch stale script tabs written back.
- A removed or new `@export` on `DesignTokens` needs a full editor restart before tests see it.
- Commits: Conventional Commits with a scope, message written to a file and committed with `git commit -F <file>`, ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File map

| File | Change |
|---|---|
| `Scripts/Design/DesignTokens.gd` | Delete `recap_banner_fill`. |
| `Scripts/Design/ThemeFactory.gd` | `RecapBannerPanel` cream; `WeekEnergyBar`/`WeekMoodBar` in the bar loop; new `_build_week_report(theme, tokens)` with `ResultTitlePanel`, `ResultTitleLabel`, `DeltaChipGain`, `DeltaChipLoss`, `DeltaChipLabel`. |
| `Assets/Theme/kejartes_theme.tres` | Rebaked. |
| `Scenes/SchoolSimulation/ResultCheckup.tscn` | `TitleRibbon` → `TitlePlate/Title`. |
| `Assets/Images/DaySummary/title_weekly_results.png(.import)` | Deleted. |
| `Scenes/SchoolSimulation/DaySummaryStatRow.tscn` | New hidden `ChipRow/DeltaChip/DeltaChipLabel` and `ChipRow/TargetLabel`. |
| `Scripts/SchoolSimulation/DaySummaryStatRow.gd` | Chip mode: helpers, `set_chip_mode`, `_sync_readout`, reveal hooks. |
| `Scripts/SchoolSimulation/DaySummaryStudentRow.gd` | `NEEDS_VARIATION`, `_apply_look(week)` at the top of the three entry points. |
| `tests/test_result_checkup.gd` | Recap/plate/chip/week-look tests. |
| `tests/test_bar_contrast.gd` | Week needs fills and their word's outline. |
| `tests/test_theme_factory.gd` | Roster additions. |
| `docs/superpowers/design/style-guide.md`, `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md` | Docs. |

---

### Task 1: Theme variations and the cream summary panel

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (the `recap_banner_fill` lines, ~406-407)
- Modify: `Scripts/Design/ThemeFactory.gd` (`build()` ~line 28, `_build_day_summary` bar loop ~3208, `_build_week_recap` ~3257)
- Modify: `tests/test_result_checkup.gd` (`test_recap_theme_matches_the_mockup`, ~line 1088)
- Modify: `tests/test_bar_contrast.gd` (after `test_the_two_needs_fills_clear_the_floor`)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`, ~line 305)
- Rebake: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Produces (theme variation names later tasks use): `ResultTitlePanel` (PanelContainer, stylebox `panel`), `ResultTitleLabel` (Label), `WeekEnergyBar` and `WeekMoodBar` (ProgressBar), `DeltaChipGain` and `DeltaChipLoss` (PanelContainer, stylebox `panel`), `DeltaChipLabel` (Label).

- [ ] **Step 1: Stand up the worktree's own editor**

The bridge's usual editor has the MAIN checkout open and never sees worktree files. Seed the worktree's `.godot` cache from the main checkout and launch a second editor, detached:

```powershell
$main = "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project"
$wt = "$main\.claude\worktrees\weekly-results-colours"
New-Item -ItemType Directory -Force "$wt\.godot" | Out-Null
foreach ($p in "imported","shader_cache") { Copy-Item -Recurse -Force "$main\.godot\$p" "$wt\.godot\" }
foreach ($f in "uid_cache.bin","global_script_class_cache.cfg","scene_groups_cache.cfg") { Copy-Item -Force "$main\.godot\$f" "$wt\.godot\" }
$exe = "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$wt`" -e"; CurrentDirectory = $wt }
```

Then `session_manage(op="list")` until a session whose `project_path` ends in `weekly-results-colours/` reports `ready`. Record its `session_id` as `<WT>` and pass `session_id="<WT>"` on every godot-ai call in this plan. Open the main scene: `scene_open(path="res://Scenes/MainMenu/MainMenu.tscn", session_id="<WT>")`.

- [ ] **Step 2: Write the failing tests**

In `tests/test_result_checkup.gd`, replace the whole of `test_recap_theme_matches_the_mockup` (its `##` comment included) with:

```gdscript
## 2026-09-29 weekly colours (header option A): the summary panel is sunken
## cream with a cream-lip rim, no longer butter yellow; the tiles stay card
## cream and their numbers keep the white rim.
func test_recap_theme_is_brown_and_cream() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var banner := theme.get_stylebox("panel", "RecapBannerPanel") as StyleBoxFlat
	assert_eq(banner.bg_color, tokens.surface_sunken, "the panel is sunken cream, not butter yellow")
	assert_eq(banner.border_color, tokens.button_cream_lip, "with the cream lip as its rim")
	assert_eq(banner.border_width_left, 2, "a 2 px rim")
	assert_eq(banner.corner_radius_top_left, tokens.radius_lg, "it keeps its large radius")
	var tile := theme.get_stylebox("panel", "RecapPillPanel") as StyleBoxFlat
	assert_eq(tile.bg_color, tokens.recap_tile_fill, "each tile is card cream")
	assert_eq(tokens.recap_tile_fill, tokens.surface_card, "the same cream as the student cards")
	assert_eq(tile.corner_radius_top_left, tokens.radius_md,
		"a rounded square, not a capsule")
	assert_eq(theme.get_constant("outline_size", "RecapPillValueLabel"),
		tokens.text_outline_size, "the number carries the white rim")
	assert_false("recap_banner_fill" in tokens, "the butter-yellow token is gone")


## The weekly report's own variations (2026-09-29 weekly colours spec):
## the brown title plate, the green and red change chips, and the needs
## bars in the game-wide energy yellow and mood pink.
func test_the_week_report_variations_are_built() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var plate := theme.get_stylebox("panel", "ResultTitlePanel") as StyleBoxFlat
	assert_eq(plate.bg_color, tokens.brand_primary, "the title plate is brand brown")
	assert_eq(plate.shadow_color, tokens.brand_primary_dark, "on the dark brown lip")
	assert_eq(theme.get_color("font_color", "ResultTitleLabel"), tokens.text_on_brand,
		"cream letters")
	assert_eq(theme.get_font_size("font_size", "ResultTitleLabel"), tokens.font_h1,
		"at H1 size")
	var gain := theme.get_stylebox("panel", "DeltaChipGain") as StyleBoxFlat
	var loss := theme.get_stylebox("panel", "DeltaChipLoss") as StyleBoxFlat
	assert_eq(gain.bg_color, tokens.state_success, "a gain chip is success green")
	assert_eq(loss.bg_color, tokens.state_danger, "a loss chip is danger red")
	assert_eq(gain.corner_radius_top_left, tokens.radius_pill, "chips are pills")
	assert_eq(loss.corner_radius_top_left, tokens.radius_pill, "both of them")
	assert_eq(theme.get_color("font_color", "DeltaChipLabel"), Color.WHITE,
		"white on both chips")
	assert_eq(theme.get_font_size("font_size", "DeltaChipLabel"),
		tokens.day_needs_label_size, "one step under the stat number")
	var energy := theme.get_stylebox("fill", "WeekEnergyBar") as StyleBoxTexture
	var mood := theme.get_stylebox("fill", "WeekMoodBar") as StyleBoxTexture
	assert_eq(energy.modulate_color, tokens.cat_energy_on_dark, "week energy is the game-wide yellow")
	assert_eq(mood.modulate_color, tokens.cat_mood_on_dark, "week mood is the game-wide pink")
	var day_track := theme.get_stylebox("background", "DaySummaryEnergyBar") as StyleBoxFlat
	var week_track := theme.get_stylebox("background", "WeekEnergyBar") as StyleBoxFlat
	assert_eq(week_track.bg_color, day_track.bg_color, "the same dark track as the nightly bar")
	assert_eq(week_track.border_color, day_track.border_color, "and the same rim")
```

In `tests/test_bar_contrast.gd`, directly after `test_the_two_needs_fills_clear_the_floor`, add:

```gdscript
## The weekly report's needs bars wear the game-wide energy yellow and mood
## pink (2026-09-29). Each fill must clear the floor on the dark track; the
## needs word is white on a dark outline, so the outline is what must clear
## the floor against each fill.
func test_the_week_needs_fills_and_their_word_clear_the_floor() -> void:
	var tokens := DesignTokens.load_default()
	for spec in [["energy", tokens.cat_energy_on_dark],
			["mood", tokens.cat_mood_on_dark]]:
		var fill: Color = spec[1]
		var ratio := _contrast(fill, tokens.day_bar_track)
		assert_true(ratio >= FLOOR,
			"week %s fill is %.2f:1 against day_bar_track, floor is %.1f"
				% [spec[0], ratio, FLOOR])
		var rim := _contrast(tokens.day_glyph_outline, fill)
		assert_true(rim >= FLOOR,
			"the needs word's outline is %.2f:1 against the week %s fill, floor is %.1f"
				% [rim, spec[0], FLOOR])
```

In `tests/test_theme_factory.gd`, in `DISPLAY_ROSTER`, directly after the line `"ResultLogsButton",` add:

```gdscript
	# 2026-09-29 weekly colours: the HASIL MINGGUAN plate and the change chips.
	"ResultTitleLabel", "DeltaChipLabel",
```

and change the comment above `"ResultLogsButton",` from `# 2026-09-19 weekly results mockup: the light-red Logs button.` to `# 2026-09-19 weekly results mockup: the Logs button (brown since 2026-09-29).`

- [ ] **Step 3: Run the tests to see them fail**

No-op `script_patch` each edited test file so the editor reloads it (e.g. replace `func suite_name() -> String:` with itself), then:

`test_run(suite="result_checkup", session_id="<WT>")`, `test_run(suite="theme_factory", session_id="<WT>")`, `test_run(suite="bar_contrast", session_id="<WT>")`

Expected: `result_checkup` fails `test_recap_theme_is_brown_and_cream` (bg is the yellow) and `test_the_week_report_variations_are_built` (null styleboxes); `theme_factory` fails the roster test (`ResultTitleLabel` did not get the display font); `bar_contrast` passes already (the tokens exist). That pass is expected: it is a guard, not a driver.

- [ ] **Step 4: Delete the yellow token**

In `Scripts/Design/DesignTokens.gd` delete these two lines:

```gdscript
## Weekly Results banner fill: the mockup's butter yellow (2026-09-19).
@export var recap_banner_fill: Color = Color("FFE17D")
```

Confirm nothing else reads it: `git grep -n "recap_banner_fill" -- "*.gd" "*.tres" "*.tscn"` must list only `tests/test_result_checkup.gd` (the new `assert_false`).

- [ ] **Step 5: Build the variations**

In `Scripts/Design/ThemeFactory.gd`:

(a) In `_build_week_recap`, replace the `RecapBannerPanel` block (from the comment `# The 2026-09-19 mockup's butter-yellow panel:` through `theme.set_stylebox("panel", "RecapBannerPanel", recap_banner)`) with:

```gdscript
	# The week's summary panel: sunken cream with a cream-lip rim, so the
	# header carries no accent colour (2026-09-29 weekly colours, header
	# option A). It was the 2026-09-19 mockup's butter yellow.
	theme.add_type("RecapBannerPanel")
	theme.set_type_variation("RecapBannerPanel", "Panel")
	var recap_banner := StyleBoxFlat.new()
	recap_banner.bg_color = tokens.surface_sunken
	recap_banner.border_color = tokens.button_cream_lip
	recap_banner.set_border_width_all(2)
	recap_banner.set_corner_radius_all(tokens.radius_lg)
	recap_banner.set_content_margin_all(tokens.space_md)
	theme.set_stylebox("panel", "RecapBannerPanel", recap_banner)
```

(b) In `_build_day_summary`, in `bar_specs`, directly after the `DaySummaryMoodBar` entry, add:

```gdscript
		# The weekly report's needs bars: the game-wide energy yellow and
		# mood pink (StatBarEnergy/StatBarMood), on the same track and rim.
		["WeekEnergyBar", tokens.day_bar_track,
			tokens.cat_energy_on_dark, tokens.day_bar_radius],
		["WeekMoodBar", tokens.day_bar_track,
			tokens.cat_mood_on_dark, tokens.day_bar_radius],
```

(c) In `build()`, directly after `_build_week_recap(theme, tokens)`, add `_build_week_report(theme, tokens)`.

(d) Directly after the whole `_build_week_recap` function, add:

```gdscript
## The weekly report's own chrome (2026-09-29 weekly colours spec): the brown
## "HASIL MINGGUAN" title plate and the green/red chips marking a week's gain
## or loss on each stat row.
static func _build_week_report(theme: Theme, tokens: DesignTokens) -> void:
	# -- ResultTitlePanel / ResultTitleLabel: the title plate, the same
	# carved-brown recipe as KoperasiSignPanel, cream letters on it. --
	# PanelContainer, not Panel: the node is a PanelContainer so it can size
	# itself around the label, and a variation only applies on its base type.
	theme.add_type("ResultTitlePanel")
	theme.set_type_variation("ResultTitlePanel", "PanelContainer")
	var plate := LippedBox.make(tokens.brand_primary, tokens.brand_primary_dark,
		tokens.lip_height, tokens.radius_button, tokens.gloss_strength)
	plate.content_margin_left = tokens.space_xl
	plate.content_margin_right = tokens.space_xl
	plate.content_margin_top = tokens.space_sm
	plate.content_margin_bottom = tokens.space_sm
	theme.set_stylebox("panel", "ResultTitlePanel", plate)

	theme.add_type("ResultTitleLabel")
	theme.set_type_variation("ResultTitleLabel", "Label")
	theme.set_font_size("font_size", "ResultTitleLabel", tokens.font_h1)
	theme.set_color("font_color", "ResultTitleLabel", tokens.text_on_brand)
	theme.set_color("font_outline_color", "ResultTitleLabel", tokens.brand_primary_dark)
	theme.set_constant("outline_size", "ResultTitleLabel", tokens.lipped_label_outline)
	if tokens.font_display != null:
		theme.set_font("font", "ResultTitleLabel", tokens.font_display)

	# -- DeltaChipGain / DeltaChipLoss / DeltaChipLabel: a flat pill (a
	# badge, not a button, so no lip) in the state colours, white number. --
	for spec in [["DeltaChipGain", tokens.state_success],
			["DeltaChipLoss", tokens.state_danger]]:
		var chip_name: String = spec[0]
		theme.add_type(chip_name)
		theme.set_type_variation(chip_name, "PanelContainer")
		var chip := StyleBoxFlat.new()
		chip.bg_color = spec[1]
		chip.set_corner_radius_all(tokens.radius_pill)
		chip.content_margin_left = tokens.space_sm
		chip.content_margin_right = tokens.space_sm
		chip.content_margin_top = 2
		chip.content_margin_bottom = 2
		theme.set_stylebox("panel", chip_name, chip)

	theme.add_type("DeltaChipLabel")
	theme.set_type_variation("DeltaChipLabel", "Label")
	theme.set_font_size("font_size", "DeltaChipLabel", tokens.day_needs_label_size)
	theme.set_color("font_color", "DeltaChipLabel", Color.WHITE)
	theme.set_constant("outline_size", "DeltaChipLabel",
		maxi(2, tokens.text_outline_size / 2))
	theme.set_color("font_outline_color", "DeltaChipLabel", tokens.day_glyph_outline)
	if tokens.font_display != null:
		theme.set_font("font", "DeltaChipLabel", tokens.font_display)
```

- [ ] **Step 6: Restart the worktree editor, rebake, and run the tests**

A removed `@export` needs a restart. Quit it (`editor_manage(op="quit", session_id="<WT>")`), relaunch with the same `Invoke-CimMethod` line from Step 1, re-list sessions and take the new `<WT>`. Then rebake alone: `test_run(suite="theme_rebake", session_id="<WT>")`. Then restart the editor once more (a rebake beside later scene saves can write stale style props; memory "rebake then restart before saving").

Run: `test_run(suite="result_checkup", session_id="<WT>")`, `theme_factory`, `bar_contrast`, `day_summary`, `design_tokens`.
Expected: all PASS. If `design_tokens` pins a token count, lower it by one and say so in the commit.

- [ ] **Step 7: Check the bake and commit**

`git diff --stat -- Assets/Theme/kejartes_theme.tres` must show a change; `git status --short` must list only the files in this task (revert `Assets/Audio/default_bus_layout.tres` and any `*.png.import` the editor's boot rewrote, after the editor has exited or with it idle).

```bash
git add Scripts/Design/DesignTokens.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_result_checkup.gd tests/test_bar_contrast.gd tests/test_theme_factory.gd
git commit -F <msg-file>
```

Message: `feat(week-report): cream summary panel and the week report's variations`

---

### Task 2: The "HASIL MINGGUAN" title plate

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn` (node `Margin/VBox/TitleRibbon`)
- Delete: `Assets/Images/DaySummary/title_weekly_results.png`, `Assets/Images/DaySummary/title_weekly_results.png.import`
- Modify: `tests/test_result_checkup.gd` (`_RIBBON` const and `test_the_screen_opens_with_the_weekly_results_ribbon`, ~line 1119)
- Modify: `docs/superpowers/DEBT.md` (the ribbon clause, ~line 77-79)

**Interfaces:**
- Consumes: `ResultTitlePanel`, `ResultTitleLabel` (Task 1).
- Produces: nodes `Margin/VBox/TitlePlate` (PanelContainer) and `Margin/VBox/TitlePlate/Title` (Label).

- [ ] **Step 1: Write the failing test**

In `tests/test_result_checkup.gd`, delete `const _RIBBON := "res://Assets/Images/DaySummary/title_weekly_results.png"` and replace `test_the_screen_opens_with_the_weekly_results_ribbon` (with its body) by:

```gdscript
## 2026-09-29 weekly colours: the red English ribbon became a brown plate
## reading HASIL MINGGUAN, still the column's first child.
func test_the_screen_opens_with_the_hasil_mingguan_plate() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var plate := screen.get_node_or_null("Margin/VBox/TitlePlate") as PanelContainer
	assert_not_null(plate, "the title plate is authored")
	if plate != null:
		assert_eq(plate.get_index(), 0, "it tops the column, above the banner")
		assert_eq(plate.theme_type_variation, &"ResultTitlePanel", "the brown plate")
		assert_eq(plate.size_flags_horizontal, Control.SIZE_SHRINK_CENTER,
			"centred, shrunk to its words")
		var title := plate.get_node_or_null("Title") as Label
		assert_not_null(title, "with its label")
		if title != null:
			assert_eq(title.text, "HASIL MINGGUAN", "in Indonesian")
			assert_eq(title.theme_type_variation, &"ResultTitleLabel", "cream display letters")
	assert_true(screen.get_node_or_null("Margin/VBox/TitleRibbon") == null,
		"the red ribbon art is gone")
	assert_false(FileAccess.file_exists("res://Assets/Images/DaySummary/title_weekly_results.png"),
		"and so is its PNG")
	screen.free()
```

- [ ] **Step 2: Run it to see it fail**

No-op `script_patch` the test file, then `test_run(suite="result_checkup", test_name="hasil_mingguan", session_id="<WT>")`.
Expected: FAIL, "the title plate is authored".

- [ ] **Step 3: Author the plate in the editor**

`scene_open(path="res://Scenes/SchoolSimulation/ResultCheckup.tscn", session_id="<WT>")`, then one `batch_execute(session_id="<WT>")`:

```json
[
 {"command": "delete_node", "params": {"path": "/ResultCheckup/Margin/VBox/TitleRibbon"}},
 {"command": "create_node", "params": {"type": "PanelContainer", "name": "TitlePlate", "parent_path": "/ResultCheckup/Margin/VBox"}},
 {"command": "move_node", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate", "index": 0}},
 {"command": "set_property", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate", "property": "theme_type_variation", "value": "ResultTitlePanel"}},
 {"command": "set_property", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate", "property": "size_flags_horizontal", "value": 4}},
 {"command": "set_property", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate", "property": "mouse_filter", "value": 2}},
 {"command": "create_node", "params": {"type": "Label", "name": "Title", "parent_path": "/ResultCheckup/Margin/VBox/TitlePlate"}},
 {"command": "set_property", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate/Title", "property": "theme_type_variation", "value": "ResultTitleLabel"}},
 {"command": "set_property", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate/Title", "property": "text", "value": "HASIL MINGGUAN"}},
 {"command": "set_property", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate/Title", "property": "horizontal_alignment", "value": 1}},
 {"command": "set_property", "params": {"path": "/ResultCheckup/Margin/VBox/TitlePlate/Title", "property": "vertical_alignment", "value": 1}}
]
```

`scene_save(session_id="<WT>")`. Then `git diff -- Scenes/SchoolSimulation/ResultCheckup.tscn`: expect the `7_ribbon` ext_resource gone, `TitleRibbon` replaced by `TitlePlate` + `Title`, and nothing else. Revert any unrelated baked property the save added (memory "editor saves bake @tool state"). Run `git diff -- '*.gd'`: expect empty.

- [ ] **Step 4: Delete the ribbon art**

`git grep -n "title_weekly_results" -- "*.tscn" "*.gd" "*.tres"` must return nothing. Then:

```bash
git rm Assets/Images/DaySummary/title_weekly_results.png Assets/Images/DaySummary/title_weekly_results.png.import
```

In `docs/superpowers/DEBT.md`, in the placeholder paragraph, replace the clause

`and the 2026-09-14 Weekly Results ribbon,
`Assets/Images/DaySummary/title_weekly_results.png` (cut out of the mockup
and given `title_daily_results.png`'s alpha -- drop-replaceable at the same
path),`

with

`and the weekly report's title, now a themed brown plate reading HASIL
MINGGUAN (`ResultCheckup.tscn` `TitlePlate`, 2026-09-29); an artist's brown
ribbon with those words can replace the plate node,`

- [ ] **Step 5: Run the tests**

`filesystem_manage(op="scan", session_id="<WT>")`, then `test_run(suite="result_checkup", session_id="<WT>")`, `tall_screen_layout`, `project_hygiene`.
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/ResultCheckup.tscn tests/test_result_checkup.gd docs/superpowers/DEBT.md
git commit -F <msg-file>
```

Message: `feat(week-report): a brown HASIL MINGGUAN plate replaces the English ribbon`

---

### Task 3: The chip nodes on the stat row

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryStatRow.tscn` (new nodes after `Value`)

**Interfaces:**
- Consumes: `DeltaChipGain`, `DeltaChipLabel` (Task 1), `DaySummaryStat` (existing).
- Produces: nodes `ChipRow` (HBoxContainer, hidden), `ChipRow/DeltaChip` (PanelContainer), `ChipRow/DeltaChip/DeltaChipLabel` (Label), `ChipRow/TargetLabel` (Label).

This task is scene-only, so it runs before the script work in Task 4 (CLAUDE.md 4b: scene work first).

- [ ] **Step 1: Author the nodes**

`scene_open(path="res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn", session_id="<WT>")`, then one `batch_execute(session_id="<WT>")`:

```json
[
 {"command": "create_node", "params": {"type": "HBoxContainer", "name": "ChipRow", "parent_path": "/DaySummaryStatRow"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "anchor_top", "value": 0.5}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "anchor_right", "value": 1.0}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "anchor_bottom", "value": 0.5}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "offset_top", "value": -25}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "offset_right", "value": -20}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "offset_bottom", "value": 25}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "grow_horizontal", "value": 2}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "grow_vertical", "value": 2}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "alignment", "value": 2}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "mouse_filter", "value": 2}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "theme_override_constants/separation", "value": 6}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow", "property": "visible", "value": false}},
 {"command": "create_node", "params": {"type": "PanelContainer", "name": "DeltaChip", "parent_path": "/DaySummaryStatRow/ChipRow"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/DeltaChip", "property": "theme_type_variation", "value": "DeltaChipGain"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/DeltaChip", "property": "size_flags_vertical", "value": 4}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/DeltaChip", "property": "mouse_filter", "value": 2}},
 {"command": "create_node", "params": {"type": "Label", "name": "DeltaChipLabel", "parent_path": "/DaySummaryStatRow/ChipRow/DeltaChip"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/DeltaChip/DeltaChipLabel", "property": "theme_type_variation", "value": "DeltaChipLabel"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/DeltaChip/DeltaChipLabel", "property": "text", "value": "+12"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/DeltaChip/DeltaChipLabel", "property": "horizontal_alignment", "value": 1}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/DeltaChip/DeltaChipLabel", "property": "vertical_alignment", "value": 1}},
 {"command": "create_node", "params": {"type": "Label", "name": "TargetLabel", "parent_path": "/DaySummaryStatRow/ChipRow"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/TargetLabel", "property": "theme_type_variation", "value": "DaySummaryStat"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/TargetLabel", "property": "text", "value": "/65"}},
 {"command": "set_property", "params": {"path": "/DaySummaryStatRow/ChipRow/TargetLabel", "property": "vertical_alignment", "value": 1}}
]
```

`ChipRow` is created after `Value`, so it is the last child and draws on top, like `Value`.

- [ ] **Step 2: Save and check the diff**

`scene_save(session_id="<WT>")`. `git diff -- Scenes/SchoolSimulation/DaySummaryStatRow.tscn` must show only the four new node blocks (the `separation` constant override is the one allowed layout override). Revert anything else the `@tool` script baked into existing nodes. `git diff -- '*.gd'` must be empty.

- [ ] **Step 3: Run the suites that build this scene**

`test_run(suite="day_summary", session_id="<WT>")`, `result_checkup`, `viewport_editability`, `tall_screen_layout`.
Expected: all PASS (the new nodes are hidden and unused so far).

- [ ] **Step 4: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStatRow.tscn
git commit -F <msg-file>
```

Message: `feat(week-report): author the stat row's hidden change chip`

---

### Task 4: Chip mode on the stat row and the week look on the card

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd`
- Modify: `Scripts/SchoolSimulation/DaySummaryStudentRow.gd`
- Modify: `tests/test_result_checkup.gd` (new section after `test_the_week_card_pairs_each_stat_with_its_own_target`)

**Interfaces:**
- Consumes: the Task 3 nodes; `WeekEnergyBar`, `WeekMoodBar`, `DeltaChipGain`, `DeltaChipLoss` (Task 1).
- Produces on `DaySummaryStatRow`:
  - `static func chip_text(delta: float) -> String` ("+12", "-3")
  - `static func target_text(target: float) -> String` ("/52")
  - `static func chip_variation(delta: float) -> StringName` (`&"DeltaChipGain"` or `&"DeltaChipLoss"`)
  - `static func shows_chip(chip_mode: bool, delta: float) -> bool`
  - `func set_chip_mode(on: bool) -> void`
  - members `chip_row: HBoxContainer`, `delta_chip: PanelContainer`, `chip_label: Label`, `target_label: Label`
- Produces on `DaySummaryStudentRow`: `const NEEDS_VARIATION`, `func _apply_look(week: bool) -> void`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_result_checkup.gd`, directly after `test_the_week_card_pairs_each_stat_with_its_own_target`, add:

```gdscript
# ------------------------------------------- the 2026-09-29 weekly colours

## The chip's text, its target and its colour, without a scene.
func test_the_chip_reads_the_change_and_its_colour() -> void:
	assert_eq(DaySummaryStatRow.chip_text(12.0), "+12", "a gain carries its plus")
	assert_eq(DaySummaryStatRow.chip_text(-3.0), "-3", "a loss reads '-3', never '+-3'")
	assert_eq(DaySummaryStatRow.chip_text(2.6), "+3", "rounded, not truncated")
	assert_eq(DaySummaryStatRow.chip_text(0.0), "+0", "a count starts at +0")
	assert_eq(DaySummaryStatRow.target_text(52.0), "/52", "the run target after a slash")
	assert_eq(DaySummaryStatRow.chip_variation(5.0), &"DeltaChipGain", "a gain is green")
	assert_eq(DaySummaryStatRow.chip_variation(-5.0), &"DeltaChipLoss", "a loss is red")
	assert_true(DaySummaryStatRow.shows_chip(true, -3.0), "a loss in chip mode shows a chip")
	assert_false(DaySummaryStatRow.shows_chip(true, 0.4), "a change that rounds to zero shows none")
	assert_false(DaySummaryStatRow.shows_chip(false, 12.0), "no chip outside chip mode")


## Option A: a gain is a green chip, a loss a red one, each followed by the
## run target; a flat stat keeps the plain "+0/65". The plain label keeps
## the full reading as data either way.
func test_the_week_card_marks_gains_and_losses_with_chips() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 40.0, "seni_budaya": 30.0, "olahraga": 55.0},
		{"akademis": 58.0, "seni_budaya": 30.0, "olahraga": 49.0})

	inst.setup_week_row(s)

	var gain: DaySummaryStatRow = inst.stat_rows[0]
	var flat: DaySummaryStatRow = inst.stat_rows[1]
	var loss: DaySummaryStatRow = inst.stat_rows[2]
	assert_true(gain.chip_row.visible, "a gain shows the chip")
	assert_false(gain.value.visible, "in place of the plain number")
	assert_eq(gain.delta_chip.theme_type_variation, &"DeltaChipGain", "green")
	assert_eq(gain.chip_label.text, "+18", "carrying the week's change")
	assert_eq(gain.target_label.text, "/65", "then the run target")
	assert_false(gain.chevron.visible, "the chip replaces the gold chevron")
	assert_eq(gain.value.text, "+18/65", "the plain label still holds the reading")
	assert_true(loss.chip_row.visible, "a loss shows the chip too")
	assert_eq(loss.delta_chip.theme_type_variation, &"DeltaChipLoss", "red")
	assert_eq(loss.chip_label.text, "-6", "with a minus")
	assert_false(flat.chip_row.visible, "a flat stat shows no chip")
	assert_true(flat.value.visible, "and keeps the plain number")
	assert_eq(flat.value.text, "+0/65", "reading +0")


## The weekly reveal opens the chip at +0, transparent, and the skip lands
## it on the week's change, fully shown and at rest.
func test_the_weekly_reveal_rewinds_and_lands_the_chip() -> void:
	var inst := _card()
	inst.setup_week_row(_student_with_week({"akademis": 40.0}, {"akademis": 58.0}))
	var row: DaySummaryStatRow = inst.stat_rows[0]

	row.rewind()
	assert_eq(row.chip_label.text, "+0", "the reveal opens the chip at +0")
	assert_eq(row.delta_chip.modulate.a, 0.0, "armed but transparent until its turn")

	row.land()
	assert_eq(row.chip_label.text, "+18", "the skip lands the week's change")
	assert_eq(row.delta_chip.modulate.a, 1.0, "fully shown")
	assert_eq(row.delta_chip.scale, Vector2.ONE, "at rest")


## The weekly card wears the game-wide energy yellow and mood pink.
func test_the_week_card_wears_the_week_needs_bars() -> void:
	var inst := _card()
	inst.setup_week_row(_student_with_week({"energy": 80.0}, {"energy": 60.0}))
	assert_eq(inst.energy_bar.theme_type_variation, &"WeekEnergyBar",
		"energy is the game-wide yellow")
	assert_eq(inst.mood_bar.theme_type_variation, &"WeekMoodBar",
		"mood is the game-wide pink")


## Scope is the weekly report only: a card re-armed for the nightly popup or
## a picker drops the week look entirely.
func test_a_reused_card_drops_the_week_look() -> void:
	var inst := _card()
	var s := _student_with_week({"akademis": 40.0}, {"akademis": 58.0})
	inst.setup_week_row(s)

	inst.setup_row("Marcel", [{"stat_key": "akademis", "delta": 6.0}], s)
	assert_eq(inst.energy_bar.theme_type_variation, &"DaySummaryEnergyBar",
		"the nightly energy colour is back")
	assert_eq(inst.mood_bar.theme_type_variation, &"DaySummaryMoodBar",
		"the nightly mood colour is back")
	assert_false(inst.stat_rows[0].chip_row.visible, "no chip in the nightly popup")
	assert_true(inst.stat_rows[0].value.visible, "the plain number is back")
	assert_true(inst.stat_rows[0].chevron.visible, "with the gold chevron on a gain")

	inst.setup_week_row(s)
	inst.setup_current_row(s)
	assert_eq(inst.energy_bar.theme_type_variation, &"DaySummaryEnergyBar",
		"a picker card keeps the nightly colours")
	assert_false(inst.stat_rows[0].chip_row.visible, "and shows no chip")
	assert_true(inst.stat_rows[0].value.visible, "only its standing number")
```

- [ ] **Step 2: Run them to see them fail**

No-op `script_patch` the test file, then `test_run(suite="result_checkup", session_id="<WT>")`.
Expected: the suite fails to load or the new tests fail (`chip_text`, `chip_row` do not exist yet).

- [ ] **Step 3: Chip mode on `DaySummaryStatRow.gd`**

Edit with `script_patch` (the file must be LF; `git ls-files --eol Scripts/SchoolSimulation/DaySummaryStatRow.gd` should show `w/lf`).

(a) After `@onready var value: Label = $Value`, add:

```gdscript
## The weekly report's change readout (2026-09-29 weekly colours spec): a
## green or red chip carrying the week's change, then the run target. Only
## chip mode shows it; `value` keeps the full "+12/65" reading as data
## either way, so every existing reading of the row still holds.
@onready var chip_row: HBoxContainer = $ChipRow
@onready var delta_chip: PanelContainer = $ChipRow/DeltaChip
@onready var chip_label: Label = $ChipRow/DeltaChip/DeltaChipLabel
@onready var target_label: Label = $ChipRow/TargetLabel
```

(b) After the `var _reveal_tweens: Array[Tween] = []` declaration, add:

```gdscript
## Whether this row reads as the weekly report's chip. The card sets it:
## DaySummaryStudentRow.setup_week_row turns it on, its other entry points
## turn it off.
var _chip_mode: bool = false
```

(c) After `format_value`, add:

```gdscript
## "+12" / "-3": the chip's number. Same sign rule as format_value.
static func chip_text(delta: float) -> String:
	var d := int(round(delta))
	return ("+%d" % d) if d >= 0 else ("%d" % d)


## "/52": the run target, read beside the chip.
static func target_text(target: float) -> String:
	return "/%d" % int(round(target))


## Which chip a change wears: success green for a gain, danger red for a
## loss. Only asked for a change that is not zero.
static func chip_variation(delta: float) -> StringName:
	return &"DeltaChipGain" if delta > 0.0 else &"DeltaChipLoss"


## Whether a chip shows: only in chip mode, and only for a change that does
## not round to zero (a flat stat keeps the plain "+0/65").
static func shows_chip(chip_mode: bool, delta: float) -> bool:
	return chip_mode and int(round(delta)) != 0


## Turn the weekly chip readout on or off and redraw the row's readout.
## The card calls it before writing its rows.
func set_chip_mode(on: bool) -> void:
	_chip_mode = on
	_sync_readout(_delta)


## Point the readout at the row's state: with a chip showing, `value` and
## the chevron hide and the chip reads `shown` (the count's current value);
## otherwise the plain label shows, exactly as before chip mode existed.
func _sync_readout(shown: float) -> void:
	var chip_on := shows_chip(_chip_mode, _delta)
	chip_row.visible = chip_on
	value.visible = not chip_on
	if not chip_on:
		return
	chevron.visible = false
	delta_chip.theme_type_variation = chip_variation(_delta)
	chip_label.text = chip_text(shown)
	target_label.text = target_text(_target)


## The counts' formatter: writes the chip as the number climbs (when one
## shows) and returns the plain label's text, which stays the row's data.
func _count_text(v: float) -> String:
	if chip_row.visible:
		chip_label.text = chip_text(v)
	return format_value(v, _target)
```

(d) In `set_stat`, add `_sync_readout(delta)` as the last line (after `track.value = _fill_to`).

(e) In `set_standing`, add `_sync_readout(0.0)` as the last line.

(f) In `play_gain`, replace

```gdscript
	Juice.count_up_formatted(value, 0.0, _delta,
		func(v: float) -> String: return format_value(v, _target), delay)
```

with

```gdscript
	Juice.count_up_formatted(value, 0.0, _delta, _count_text, delay)
```

(g) Replace `rewind()`'s body with:

```gdscript
	_stop_reveal()
	track.value = _fill_from
	value.text = format_value(0.0, _target)
	value.scale = Vector2.ONE
	if chevron.visible:
		chevron.modulate.a = 0.0
	_sync_readout(0.0)
	if chip_row.visible:
		delta_chip.modulate.a = 0.0
```

and add to its `##` comment: `In chip mode the chip is armed the same way, at +0.`

(h) In `play_count`, replace the `var count := ...` statement with

```gdscript
	var count := Juice.count_up_formatted(value, 0.0, _delta,
		_count_text, 0.0, seconds)
```

and after the `if chevron.visible:` block add:

```gdscript
	if chip_row.visible:
		var chip_pop := Juice.pop_in(delta_chip)
		if chip_pop != null:
			_reveal_tweens.append(chip_pop)
```

(i) Replace `land_pop`'s body with:

```gdscript
	var target: Control = delta_chip if chip_row.visible else value
	var center: Vector2 = target.size * 0.5 if chip_row.visible \
		else Juice.text_center(value)
	Juice.punch(target, center)
	if Engine.is_editor_hint():
		return
	var origin: Vector2 = chip_row.position + delta_chip.position \
		if chip_row.visible else value.position
	var fx := _get_or_make_burst(origin + center)
	fx.plays_sfx = false
	fx.fire()
	AudioDirector.play_sfx(&"tally", pitch)
```

and add to its `##` comment: `In chip mode the chip punches and throws the burst instead of the number.`

(j) Replace `land()`'s body with:

```gdscript
	_stop_reveal()
	track.value = _fill_to
	value.text = format_value(_delta, _target)
	value.scale = Vector2.ONE
	_reset_chevron()
	_sync_readout(_delta)
	delta_chip.modulate.a = 1.0
	delta_chip.scale = Vector2.ONE
```

- [ ] **Step 4: The week look on `DaySummaryStudentRow.gd`**

(a) After `const GAIN_STEP := 0.08`, add:

```gdscript
## Which needs-bar variation each look wears. The weekly report uses the
## game-wide energy yellow and mood pink (2026-09-29 weekly colours spec);
## every other screen keeps the popup's own purple and orange.
const NEEDS_VARIATION := {
	true: {"energy": &"WeekEnergyBar", "mood": &"WeekMoodBar"},
	false: {"energy": &"DaySummaryEnergyBar", "mood": &"DaySummaryMoodBar"},
}
```

(b) Before `setup_row`, add:

```gdscript
## Dress the card for the weekly report (`week` true) or for every other
## screen: the needs bars' colours and the stat rows' chip readout. Every
## entry point calls it first, so a reused card never carries one screen's
## look into another.
func _apply_look(week: bool) -> void:
	energy_bar.theme_type_variation = NEEDS_VARIATION[week]["energy"]
	mood_bar.theme_type_variation = NEEDS_VARIATION[week]["mood"]
	for row in stat_rows:
		row.set_chip_mode(week)
```

(c) Make `_apply_look(false)` the first line of `setup_row` and of `setup_current_row`, and `_apply_look(true)` the first line of `setup_week_row`.

- [ ] **Step 5: Run the tests**

`test_run(suite="result_checkup", session_id="<WT>")`, `day_summary`, `apply_item_screen`, `apply_student_row`, `event_student_card_tired`, `week_report_rehearsal`, `script_documentation`, `clean_code`, `viewport_editability`.
Expected: all PASS. If `clean_code` reports a longer function or a new magic number, move the number into a named `const` in the same script (e.g. `const CHIP_POP_...`) rather than raising the ratchet.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStatRow.gd Scripts/SchoolSimulation/DaySummaryStudentRow.gd tests/test_result_checkup.gd
git commit -F <msg-file>
```

Message: `feat(week-report): green and red change chips and the game-wide needs colours`

---

### Task 5: Live check, docs and ship

**Files:**
- Modify: `docs/superpowers/design/style-guide.md` (the Panels / Labels / Progress lists in "Theme variations")
- Modify: `docs/superpowers/CHANGELOG.md` (new entry at the top)

- [ ] **Step 1: Look at it in the running game**

`project_run(autosave=false, session_id="<WT>")`, then in one `game_eval`: `DebugManager._open_week_report_preview()`, wait ~6 s of frames, grab `get_viewport().get_texture().get_image()` and `save_png` it to the session scratchpad. Read the PNG and check: brown plate reading HASIL MINGGUAN; cream summary panel; yellow energy and pink mood bars; green chips on gains and a red chip on any loss, each followed by `/target`; no gold chevrons on the stat rows; Logs brown, Selanjutnya mint. Then close the preview and open one nightly popup path (Debug > Scenes > SchoolDay after a Seed Playtest State + Atur Jadwal pass, or any `DaySummaryPopup` rehearsal the debug overlay offers) and confirm its card still has purple/orange needs and gold chevrons. `project_manage(op="stop", session_id="<WT>")`. Revert `Assets/Audio/default_bus_layout.tres` if the run rewrote it.

- [ ] **Step 2: Docs**

In `docs/superpowers/design/style-guide.md`, "Theme variations":
- under **Panels** add: `` - `ResultTitlePanel` — the weekly report's brown "HASIL MINGGUAN" title plate (`KoperasiSignPanel`'s recipe). `DeltaChipGain` / `DeltaChipLoss` — the weekly report's change chips, `state_success` / `state_danger` pills. ``
- under **Labels** add: `` - `ResultTitleLabel` — cream display letters on `ResultTitlePanel`. `DeltaChipLabel` — the white number on a change chip. ``
- under **Progress** add: `` - `WeekEnergyBar` / `WeekMoodBar` — the weekly report's needs bars, in the game-wide `cat_energy_on_dark` / `cat_mood_on_dark`; the nightly popup keeps `DaySummaryEnergyBar` / `DaySummaryMoodBar`. ``

In `docs/superpowers/CHANGELOG.md`, add at the top (under the file's intro, above the newest entry):

```markdown
## 2026-09-29 — Weekly results under the design rules

The weekly report (`ResultCheckup`) now follows the role palette. The red
English "WEEKLY RESULTS" ribbon is a brown `ResultTitlePanel` plate reading
HASIL MINGGUAN, and the summary panel is sunken cream with a cream-lip rim
instead of butter yellow (`recap_banner_fill` is gone). On the weekly cards
only, energy and mood wear the game-wide yellow and pink (`WeekEnergyBar`,
`WeekMoodBar`) instead of Istirahat's purple and the warning orange, and each
stat's week change is a green (`DeltaChipGain`) or red (`DeltaChipLoss`)
chip followed by the run target, replacing the gold chevron. The nightly
popup, the apply-item rows and the event picker share the card and are
unchanged: `DaySummaryStudentRow._apply_look(week)` runs first in every entry
point. Picked by the owner in the visual companion (header A, chips A,
weekly only). Logs brown, cream tiles and the brown scroll fade came earlier
the same day in #131.
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/design/style-guide.md docs/superpowers/CHANGELOG.md
git commit -F <msg-file>
```

Message: `docs(week-report): the weekly colours in the style guide and changelog`

- [ ] **Step 4: Ship**

Run the `ship-pr` skill from the worktree (its step 3 covers the worktree editor: full `test_run(session_id="<WT>")` with MainMenu open, then restart that editor before any further call). Afterwards quit the worktree editor, and once the PR merges remove the worktree (memory: "Remove worktrees once merged"; `git worktree remove` may hit Windows' path limit with the seeded `.godot`, so delete the folder's `.godot` first).
