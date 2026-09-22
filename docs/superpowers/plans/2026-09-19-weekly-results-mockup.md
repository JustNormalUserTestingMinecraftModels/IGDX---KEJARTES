# Weekly Results Mockup Pass: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax
> for tracking.

**Goal:** ResultCheckup matches `~/Downloads/mockup_weeklyresults.png`: a red
WEEKLY RESULTS ribbon, a yellow panel with three white tiles (money,
minigames, events; Poin removed), and a lighter-red Logs button. Every result
star uses the new `star.png`.

**Architecture:** Restyle the existing `WeekRecapBanner` / `WeekRecapPill`
templates and their ThemeFactory variations. Nothing new is built at runtime.
The ribbon is the orphaned `title_weekly_results.png` in a `TextureRect`. The
stars are texture swaps plus one tint default.

**Tech Stack:** Godot 4.6 GDScript, `McpTestSuite` suites run through the
godot-ai MCP `test_run`, and Python/PIL for the one-off asset prep.

**Spec:** `docs/superpowers/specs/2026-09-19-weekly-results-mockup-design.md`

## Global Constraints

- Worktree: `.claude/worktrees/weekly-results`, branch
  `feat/weekly-results-redesign`, based on `origin/Textures` d0cd987.
- **All MCP calls pass `session_id="<WT>"`**, the worktree editor's session
  (Task 1). Never `session_activate`.
- **`.tscn` files are edited as text only while the worktree editor is
  closed.** Quit it (`editor_manage(op="quit")`), edit, then relaunch
  (Task 1 Step 3). `.gd` files may be edited while it is open, but each
  edited file then gets a no-op `script_patch` before `test_run`
  (CLAUDE.md §5).
- No `theme_override_*` beyond layout constants. Every script keeps its `##`
  header, and every `@export` / `const` keeps its `##` line.
- UI text is Indonesian. The ribbon art's English "WEEKLY RESULTS" is the
  mockup's and stays.
- Commit messages go through `git commit -F <file>`, written BOM-less
  (`[IO.File]::WriteAllText(..., (New-Object Text.UTF8Encoding $false))`),
  and end with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Run
  git as plain single commands, and check `git branch --show-current` before
  each commit.
- Before every commit, revert what the editor boot rewrote:
  `git checkout -- Assets/Audio/default_bus_layout.tres` and any
  `Assets/Images/MuridPotrait/*.import` / `SplashArtMurid/*.import`, only
  while the editor is closed.

---

### Task 1: Assets, and the worktree editor

**Files:**
- Create: `Assets/Images/ResultCheckup/icon_minigame.png` (from
  `~/Downloads/soccerball.png`) and `Assets/Images/ResultCheckup/icon_event.png`
  (from `~/Downloads/events.png`), both copied as-is.
- Create: `Assets/Images/UI/star.png`, from `~/Downloads/star.png` padded to
  a transparent 360×360 square with the art centred. StatCheck's bars need a
  square texture (Task 6).
- Create: their `.import` files (the editor writes them).

- [ ] **Step 1: Copy and pad**

```powershell
New-Item -ItemType Directory -Force Assets/Images/ResultCheckup | Out-Null
Copy-Item C:\Users\user\Downloads\soccerball.png Assets/Images/ResultCheckup/icon_minigame.png
Copy-Item C:\Users\user\Downloads\events.png Assets/Images/ResultCheckup/icon_event.png
python -c "from PIL import Image; s=Image.open(r'C:/Users/user/Downloads/star.png').convert('RGBA'); c=Image.new('RGBA',(360,360),(0,0,0,0)); c.paste(s,((360-s.width)//2,(360-s.height)//2),s); c.save('Assets/Images/UI/star.png')"
```

Expected: three PNGs. `star.png` is 360×360.

- [ ] **Step 2: Seed the worktree's `.godot` cache.** Copy `imported/`,
  `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg` and
  `scene_groups_cache.cfg` from the main checkout's `.godot/` into this
  worktree's `.godot/`. Skip `editor/`.

- [ ] **Step 3: Launch the worktree editor, detached**

```powershell
$exe = "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
$wt = (Get-Location).Path
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$wt`" -e"; CurrentDirectory = $wt }
```

Then poll `session_manage(op="list")` until a session whose `project_path`
is this worktree reports `ready`. Record its id as `<WT>`. The same command
relaunches it after every quit.

- [ ] **Step 4: Confirm the import.** `filesystem_manage(op="scan",
  session_id="<WT>")`, then check that the three `.png.import` files exist.
  Baseline: `test_run(suite="result_checkup", session_id="<WT>")` → all
  green.

- [ ] **Step 5: Commit** the three PNGs and their `.import` files:
  `chore(result-checkup): add weekly results tile icons and the new star art`.

---

### Task 2: Tokens and theme (the yellow panel, white tiles, outlined value, Logs red)

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd`, adding four `@export` colors next
  to the `day_*` block.
- Modify: `Scripts/Design/ThemeFactory.gd` (`_build_week_recap` ~l.1797,
  `_build_result_button` ~l.667).
- Modify: `Assets/Theme/kejartes_theme.tres` (rebake).
- Test: `tests/test_result_checkup.gd`, `tests/test_theme_factory.gd`,
  `tests/test_lobby_style_buttons.gd` (header doc only).

**Interfaces:**
- Produces: tokens `recap_banner_fill`, `recap_tile_fill`,
  `result_logs_fill`, `result_logs_dark`, and the theme variation
  `ResultLogsButton`.

- [ ] **Step 1: Failing tests.** Append to `tests/test_result_checkup.gd`:

```gdscript
## 2026-09-19 mockup pass: yellow banner, white tiles, outlined numbers.
func test_recap_theme_matches_the_mockup() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var banner := theme.get_stylebox("panel", "RecapBannerPanel") as StyleBoxFlat
	assert_eq(banner.bg_color, tokens.recap_banner_fill, "the banner is the mockup's yellow")
	assert_eq(banner.border_width_left, 0, "and has no brown rim")
	var tile := theme.get_stylebox("panel", "RecapPillPanel") as StyleBoxFlat
	assert_eq(tile.bg_color, tokens.recap_tile_fill, "each tile is white")
	assert_eq(tile.corner_radius_top_left, tokens.radius_md,
		"a rounded square, not a capsule")
	assert_eq(theme.get_constant("outline_size", "RecapPillValueLabel"),
		tokens.text_outline_size, "the number carries the white rim")


## Logs is a lighter red than the ribbon; Selanjutnya keeps the brown.
func test_logs_wears_the_light_red_result_button() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_true(theme.get_type_list().has("ResultLogsButton"),
		"ResultLogsButton is a variation")
	var sb := theme.get_stylebox("normal", "ResultLogsButton") as StyleBoxFlat
	assert_eq(sb.bg_color, tokens.result_logs_fill, "its face is the light red")
	assert_eq(theme.get_font_size("font_size", "ResultLogsButton"),
		theme.get_font_size("font_size", "ResultButton"),
		"same text size as its neighbour, so the row reads as a pair")
```

In `tests/test_theme_factory.gd`, add `"ResultLogsButton",` to
`DISPLAY_ROSTER` right after `"ResultButton",`, with the comment
`# 2026-09-19 weekly results mockup: the light-red Logs button.` In
`tests/test_lobby_style_buttons.gd`'s header `##`, append `, and Weekly
Results' light-red Logs button (ResultLogsButton, 2026-09-19)` to the
exceptions sentence.

- [ ] **Step 2: Run them red.** No-op `script_patch` each edited test file,
  then `test_run(suite="result_checkup", session_id="<WT>")`. Expected:
  a failure or parse error, because the tokens do not exist yet.

- [ ] **Step 3: Tokens.** In `DesignTokens.gd`:

```gdscript
## Weekly Results banner fill: the mockup's butter yellow (2026-09-19).
@export var recap_banner_fill: Color = Color("FFE17D")
## Weekly Results tile fill: near-white, so the icons read on it.
@export var recap_tile_fill: Color = Color("F6F4F2")
## Weekly Results' Logs button face: the ribbon's red (C00000), lightened.
@export var result_logs_fill: Color = Color("E0574B")
## The Logs button's bevel, under result_logs_fill.
@export var result_logs_dark: Color = Color("A8342A")
```

If `Assets/Theme/design_tokens.tres` lists explicit color values, add the
same four lines there.

- [ ] **Step 4: ThemeFactory.** In `_build_week_recap`, the banner box
  becomes:

```gdscript
	var recap_banner := StyleBoxFlat.new()
	recap_banner.bg_color = tokens.recap_banner_fill
	recap_banner.set_corner_radius_all(tokens.radius_lg)
	recap_banner.set_content_margin_all(tokens.space_md)
```

The pill box becomes:

```gdscript
	var recap_pill := StyleBoxFlat.new()
	recap_pill.bg_color = tokens.recap_tile_fill
	recap_pill.set_corner_radius_all(tokens.radius_md)
	recap_pill.set_content_margin_all(tokens.space_sm)
```

After `RecapPillValueLabel`'s font_color, add:

```gdscript
	theme.set_constant("outline_size", "RecapPillValueLabel", tokens.text_outline_size)
	theme.set_color("font_outline_color", "RecapPillValueLabel", tokens.text_outline_color)
```

Update the two comments above them ("a raised card …", "a sunken capsule
…") to the mockup's yellow panel and white tiles. In `_build_result_button`,
append:

```gdscript
	# 2026-09-19: Logs is the ribbon's red, lightened; Selanjutnya keeps the
	# brown as the one primary action.
	_add_button_variation(theme, tokens, "ResultLogsButton",
		tokens.result_logs_fill, tokens.result_logs_dark,
		tokens.outline_card, tokens.text_on_brand)
	_set_content_margins(theme, "ResultLogsButton", 24, tokens.btn_pad_v_s)
	theme.set_font_size("font_size", "ResultLogsButton", tokens.day_stat_size)
```

- [ ] **Step 5: Restart and rebake.** New Resource `@export`s need a full
  editor restart. Quit `<WT>`, relaunch (Task 1 Step 3), re-list for the new
  id, then `test_run(suite="theme_rebake", session_id="<WT>")`.

- [ ] **Step 6: Green.** `test_run` suites `result_checkup`,
  `theme_factory`, `lobby_style_buttons`, `button_geometry` → all pass.

- [ ] **Step 7: Commit** `DesignTokens.gd`, `design_tokens.tres` (if
  changed), `ThemeFactory.gd`, `kejartes_theme.tres` and the three tests.
  Diff the bake first: only recap/Logs styleboxes should change.
  Message: `feat(result-checkup): yellow recap panel, white tiles, light-red Logs`.

---

### Task 3: The tile puts its icon above its number

**Files:**
- Modify: `Scenes/SchoolSimulation/WeekRecapPill.tscn`
- Modify: `Scripts/SchoolSimulation/WeekRecapPill.gd` (the `@onready` paths
  and the header doc)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Produces: `WeekRecapPill` children `Column/Icon`, `Column/Value`, `Ring`.
  `set_pill(icon, text, tint)` is unchanged.

- [ ] **Step 1: Failing test.** Replace
  `test_pill_scene_has_its_three_authored_nodes` with:

```gdscript
func test_pill_scene_stacks_its_icon_above_its_value() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	var column := pill.get_node_or_null("Column") as VBoxContainer
	assert_not_null(column, "Icon and Value share one column (mockup tile)")
	assert_not_null(pill.get_node_or_null("Column/Icon"), "Icon is authored")
	assert_not_null(pill.get_node_or_null("Column/Value"), "Value is authored")
	assert_true(column.get_node("Icon").get_index() < column.get_node("Value").get_index(),
		"the icon sits above its number, not under it")
	assert_not_null(pill.get_node_or_null("Ring"), "Ring emitter is authored")
	pill.free()
```

In `test_pill_set_pill_writes_text_and_tint`, change both `"Value"` lookups
to `"Column/Value"`. In `_pill_text`, change `get_node("Value")` to
`get_node("Column/Value")`.

- [ ] **Step 2: Red.** No-op `script_patch` the test, then
  `test_run(suite="result_checkup", session_id="<WT>")` → the new test fails.

- [ ] **Step 3: Scene (editor closed).** Quit `<WT>`. Rewrite
  `WeekRecapPill.tscn`'s nodes:

```
[node name="WeekRecapPill" type="PanelContainer" unique_id=593429704]
custom_minimum_size = Vector2(0, 260)
theme_type_variation = &"RecapPillPanel"
script = ExtResource("1_ldboa")

[node name="Column" type="VBoxContainer" parent="." unique_id=1402298571]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 8
alignment = 1

[node name="Icon" type="TextureRect" parent="Column" unique_id=276348365]
custom_minimum_size = Vector2(0, 150)
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Value" type="Label" parent="Column" unique_id=1801363007]
layout_mode = 2
theme_type_variation = &"RecapPillValueLabel"
horizontal_alignment = 1

[node name="Ring" parent="." unique_id=2106305868 instance=ExtResource("2_hxt6t")]
position = Vector2(140, 130)
amount = 10
texture = ExtResource("3_cg0p4")
explosiveness = 1.0
plays_sfx = false
```

Keep the header and ext_resources as they are. `Ring` moves to the new
tile's approximate centre.

- [ ] **Step 4: Script.** In `WeekRecapPill.gd`: `$Icon` → `$Column/Icon`,
  `$Value` → `$Column/Value`. In the header, "instanced four times" becomes
  "instanced three times", and add the line `## Icon above number, the
  2026-09-19 mockup tile.`

- [ ] **Step 5: Green.** Relaunch, then `test_run` suites `result_checkup`,
  `viewport_editability`, `script_documentation`.

- [ ] **Step 6: Commit**: `feat(result-checkup): recap tiles stack icon over number`.

---

### Task 4: The banner shows three tiles, with Poin and the week line gone

**Files:**
- Modify: `Scenes/SchoolSimulation/WeekRecapBanner.tscn`
- Modify: `Scripts/SchoolSimulation/WeekRecapBanner.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `recap_banner_fill` (Task 2) and `Column/Value` (Task 3).
- Produces: `PILL_ORDER == ["uang", "menang", "event"]`; nodes
  `Pills/PillUang`, `Pills/PillMenang`, `Pills/PillEvent`.

- [ ] **Step 1: Failing tests.** Replace `test_banner_authors_all_four_pills`,
  `test_banner_writes_every_total_into_its_pills` and
  `test_banner_shows_a_negative_week_as_negative` with:

```gdscript
func test_banner_authors_the_mockups_three_tiles_in_order() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	var names: Array = []
	for child in banner.get_node("Pills").get_children():
		names.append(child.name)
	assert_eq(names, ["PillUang", "PillMenang", "PillEvent"],
		"money, minigames, events, left to right; Poin is gone")
	assert_null(banner.get_node_or_null("Header"),
		"the mockup has no week/grade line")
	banner.free()


func test_banner_writes_its_three_totals_in_one_ink() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(banner)
	banner.set_recap({
		"money_earned": 4200, "net_skill_delta": 37,
		"minigames_won": 3, "minigames_total": 5, "events_count": 2,
	})
	assert_eq(_pill_text(banner, "PillUang"), "4.200", "money is grouped")
	assert_eq(_pill_text(banner, "PillMenang"), "3/5", "won over total")
	assert_eq(_pill_text(banner, "PillEvent"), "2", "a bare event count")
	var ink := Juice.tokens().text_primary
	for n in ["PillUang", "PillMenang", "PillEvent"]:
		assert_eq((banner.get_node("Pills/%s/Column/Value" % n) as Label).self_modulate,
			ink, "%s is text_primary: gold is unreadable on a white tile" % n)
	banner.queue_free()


func test_banner_script_drops_poin() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_contains(src, 'const PILL_ORDER := ["uang", "menang", "event"]',
		"three tiles, in the mockup's order")
	for dead in ["pill_poin", "icon_poin", "net_skill_delta", "format_skill_delta", "week_label"]:
		assert_false(src.contains(dead), "%s left with the Poin tile / week line" % dead)


func test_banner_uses_the_new_tile_icons() -> void:
	var banner = load(_BANNER_SCENE).instantiate()
	assert_eq(banner.icon_uang.resource_path, "res://Assets/Images/UI/Placeholders/icon_uang.svg",
		"money keeps its existing icon")
	assert_eq(banner.icon_menang.resource_path, "res://Assets/Images/ResultCheckup/icon_minigame.png",
		"minigames wear the soccer ball")
	assert_eq(banner.icon_event.resource_path, "res://Assets/Images/ResultCheckup/icon_event.png",
		"events wear the checklist notebook")
	banner.free()
```

- [ ] **Step 2: Red.** No-op `script_patch`, then
  `test_run(suite="result_checkup", session_id="<WT>")`.

- [ ] **Step 3: Scene (editor closed).** In `WeekRecapBanner.tscn`:
  - Delete the `icon_poin.svg` ext_resource (`3_nu073`) and
    `icon_poin = …`.
  - Point `4_eia8w` at
    `path="res://Assets/Images/ResultCheckup/icon_minigame.png"` and
    `5_80yyh` at `path="res://Assets/Images/ResultCheckup/icon_event.png"`.
    Drop their stale `uid=` attributes; the editor writes new ones on the
    next save.
  - Delete the `Header`, `WeekLabel`, `GradeLabel` and `PillPoin` nodes.
  - Root: `custom_minimum_size = Vector2(0, 300)`. `Pills`:
    `theme_override_constants/separation = 28`.
  - `CoinShower`: `position = Vector2(150, 150)` (over the money tile).
  - Root is a `PanelContainer`, so with `Header` gone the lone `Pills` HBox
    fills it. That is intended.

- [ ] **Step 4: Script.** In `WeekRecapBanner.gd`:
  - Header doc: "the week and grade, and the four headline totals" becomes
    "the three headline totals (money, minigames, events) as tiles; Poin and
    the week line left with the 2026-09-19 mockup pass".
  - `const PILL_ORDER := ["uang", "menang", "event"]`, and remove `"poin"`
    from `PILL_INFO`.
  - Delete `week_label`, `grade_label` and the `pill_poin` `@onready`s, the
    `icon_poin` export, the `pill_poin` connect in `_ready`, and the
    `"poin": icon_poin,` icon-map entry.
  - Both `[pill_uang, pill_poin, pill_menang, pill_event]` arrays become
    `[pill_uang, pill_menang, pill_event]`.
  - `set_recap` body becomes:

```gdscript
	_recap = recap
	var ink := Juice.tokens().text_primary
	pill_uang.set_pill(icon_uang,
		WeekRecap.format_money(recap.get("money_earned", 0)), ink)
	pill_menang.set_pill(icon_menang, "%d/%d" % [
		recap.get("minigames_won", 0), recap.get("minigames_total", 0)], ink)
	pill_event.set_pill(icon_event, str(recap.get("events_count", 0)), ink)
```

  and its doc becomes "Write all three tiles. Idempotent …".
  - `play_entrance`: `pills` / `values` / `formatters` lose their Poin
    entries (the `net_skill_delta` value and the `format_skill_delta`
    formatter).
  - Doc lines that say "four pills" or "fourth" now say three.

- [ ] **Step 5: Green.** Relaunch, then `test_run` suites `result_checkup`,
  `week_recap_pill_info_popup`, `script_documentation`,
  `viewport_editability`, `tall_screen_layout`.

- [ ] **Step 6: Commit**: `feat(result-checkup): three mockup tiles, Poin removed`.

---

### Task 5: The screen gets its ribbon and the light-red Logs button

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn`
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `ResultLogsButton` (Task 2).
- Produces: node `Margin/VBox/TitleRibbon`.

- [ ] **Step 1: Failing tests.** Append:

```gdscript
const _RIBBON := "res://Assets/Images/DaySummary/title_weekly_results.png"


func test_the_screen_opens_with_the_weekly_results_ribbon() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var ribbon := screen.get_node_or_null("Margin/VBox/TitleRibbon") as TextureRect
	assert_not_null(ribbon, "the mockup's ribbon is authored")
	assert_eq(ribbon.texture.resource_path, _RIBBON, "wearing the WEEKLY RESULTS art")
	assert_eq(ribbon.get_index(), 0, "it tops the column, above the banner")
	assert_null(screen.get_node_or_null("Margin/VBox/HeaderPanel"),
		"the old title and subtitle are replaced by the ribbon")
	screen.free()


func test_script_drops_the_header_text_exports() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for dead in ["header_title_text", "header_subtitle_text", "HeaderPanel"]:
		assert_false(src.contains(dead), "%s left with the header" % dead)
```

Replace `test_the_buttons_wear_the_result_style`'s variation assertion with:

```gdscript
	assert_true(src.contains('theme_type_variation = &"ResultLogsButton"'),
		"Logs wears the light-red variation")
	assert_true(src.contains('theme_type_variation = &"ResultButton"'),
		"Selanjutnya keeps the brown one")
```

- [ ] **Step 2: Red.** `test_run(suite="result_checkup", session_id="<WT>")`.

- [ ] **Step 3: Scene (editor closed).** In `ResultCheckup.tscn`:
  - Add
    `[ext_resource type="Texture2D" path="res://Assets/Images/DaySummary/title_weekly_results.png" id="7_ribbon"]`.
  - Delete the `HeaderPanel`, `TitleLabel` and `SubtitleLabel` nodes.
  - Insert, directly after the `VBox` node and before `Banner`:

```
[node name="TitleRibbon" type="TextureRect" parent="Margin/VBox" unique_id=1733019024]
custom_minimum_size = Vector2(0, 250)
layout_mode = 2
mouse_filter = 2
texture = ExtResource("7_ribbon")
expand_mode = 1
stretch_mode = 5
```

  - `LogsButton`: `theme_type_variation = &"ResultLogsButton"`.

- [ ] **Step 4: Script.** In `ResultCheckup.gd`, delete `header_title_text`,
  `header_subtitle_text`, the `title_label` / `subtitle_label` `@onready`s,
  and the two `if title_label:` / `if subtitle_label:` blocks. The export
  group becomes `"Visual - Typography"` (it still holds `font`).

- [ ] **Step 5: Green.** Relaunch, then `test_run` suites `result_checkup`,
  `tall_screen_layout`, `viewport_editability`, `script_documentation`,
  `lobby_style_buttons`.

- [ ] **Step 6: Commit**: `feat(result-checkup): WEEKLY RESULTS ribbon and light-red Logs`.

---

### Task 6: The student card becomes PR #53's cream ID card

The user chose PR #53's (`origin/feat/weekly-results-polish`) cream ID-card
look over the green `card_bg.png`. `DaySummaryStudentRow` is shared, so this
changes the weekly report, the daily popup, SchoolDay's embedded cards and
the `StudentCardButton` wrappers together. Textures has not touched any of
these files since that branch's merge-base (`cdf7b27`), so its versions come
across whole.

**Files:**
- Take from `origin/feat/weekly-results-polish` unchanged:
  `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`,
  `Assets/Images/UI/header_stripes.svg` (+ `.import`),
  `Scripts/UI/StudentCardButton.gd` (`card_design_size` 410→486),
  `tests/test_day_summary.gd`, `tests/test_student_card_button.gd`.
- Modify: `Scripts/Design/ThemeFactory.gd`, porting only `IdCardPanel` and
  `RecapMastheadPanel` from its `_build_weekly_results_polish`.
  `RecapChipPanel` stays behind; nothing here uses it.
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Produces: theme variations `IdCardPanel` and `RecapMastheadPanel`. The card
  box is 992×486 with nodes `CardBg`, `HeaderBand/HeaderStripes`,
  `NameLabel`. The `DaySummaryStudentRow.gd` API is unchanged.

- [ ] **Step 1: Tests first.** Quit `<WT>`, then:

```powershell
git checkout origin/feat/weekly-results-polish -- tests/test_day_summary.gd tests/test_student_card_button.gd
```

Append to `tests/test_theme_factory.gd`:

```gdscript
## 2026-09-19: the weekly report takes PR #53's cream ID card; its frame
## and brown name band are these two variations.
func test_id_card_variations_exist() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	for v in ["IdCardPanel", "RecapMastheadPanel"]:
		assert_true(theme.get_type_list().has(v), "%s missing" % v)
```

- [ ] **Step 2: Red.** Relaunch, then `test_run` suites `day_summary`,
  `student_card_button`, `theme_factory`. Expect failures on `CardBg`, 486,
  and the missing variations.

- [ ] **Step 3: Theme.** In `ThemeFactory.gd`, add
  `_build_id_card(theme, tokens)` to `build()` after `_build_week_recap`,
  holding PR #53's `RecapMastheadPanel` and `IdCardPanel` blocks verbatim
  (`git show 58364b0 -- Scripts/Design/ThemeFactory.gd`), with the `##`
  header: "The cream ID-card frame and its brown name band, shared by every
  DaySummaryStudentRow (from PR #53, 2026-09-16; adopted 2026-09-19)."

- [ ] **Step 4: Scene and wrapper (editor closed).** Quit `<WT>`, then:

```powershell
git checkout origin/feat/weekly-results-polish -- Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scripts/UI/StudentCardButton.gd Assets/Images/UI/header_stripes.svg Assets/Images/UI/header_stripes.svg.import
```

- [ ] **Step 5: Restart, rebake, green.** Relaunch, then
  `test_run(suite="theme_rebake")`, then `day_summary`,
  `student_card_button`, `theme_factory`, `result_checkup`,
  `tall_screen_layout`, `viewport_editability`, `event_polish`.

- [ ] **Step 6: Orphan.** `card_bg.png` / `card_bg_uncropped.png`: if
  `git grep -n "DaySummary/card_bg" -- . ":!docs"` is empty, note them in
  `DEBT.md` as retired-but-kept (drop-in if the green card ever returns).
  Do not delete them.

- [ ] **Step 7: Commit**: `feat(day-summary): adopt PR #53's cream ID card for every student card`.

---

### Task 7: Every result star uses `star.png`

**Files:**
- Modify: `Scenes/EndGame/StatCheck.tscn`,
  `Scenes/SchoolSimulation/EventStudentCard.tscn`
- Modify: `Scripts/Minigames/UI/ResultStar.gd`,
  `Scripts/Minigames/UI/BaseMinigame.gd:78-79`,
  `Scripts/EndGame/StarMeter.gd:5`
- Delete: `Assets/Images/UI/Placeholders/icon_star.svg`, `icon_bintang.svg`,
  `icon_bintang_kosong.svg` and their `.import` files, only if Step 6's grep
  is empty.
- Test: `tests/test_stat_check.gd`, `tests/test_minigame_result_popup.gd`

**Interfaces:**
- Consumes: `res://Assets/Images/UI/star.png` (Task 1, 360×360).

- [ ] **Step 1: Failing tests.** In `test_stat_check.gd`, set
  `const _STAR_ICON := "res://Assets/Images/UI/star.png"`. The two message
  strings "icon_star.svg" become "star.png". In
  `test_star_meter_bars_use_the_placeholder_star`, rename the test to
  `test_star_meter_bars_use_the_new_star` and assert:

```gdscript
		assert_true(String(bar.texture_progress.resource_path).ends_with("UI/star.png"),
			"%s fills with star.png" % n)
		assert_true(bar.nine_patch_stretch,
			"%s stretches the 360 px star into its 180 px cell" % n)
```

In `test_minigame_result_popup.gd`, replace `RESULT_ICONS`' two
`icon_bintang*` lines with `"res://Assets/Images/UI/star.png",`, and
append:

```gdscript
func test_result_stars_default_to_the_new_star_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/ResultStar.gd")
	assert_contains(src, 'DEFAULT_FILLED_TEXTURE := "res://Assets/Images/UI/star.png"',
		"an earned star is star.png")
	assert_contains(src, 'DEFAULT_EMPTY_TEXTURE := "res://Assets/Images/UI/star.png"',
		"so is an unearned one; popup_star_empty_color darkens it")
	var base := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(base, "@export var popup_star_color: Color = Color.WHITE",
		"the art is already gold, so the default tint must not re-tint it")


func test_event_student_card_wears_the_new_star() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/SchoolSimulation/EventStudentCard.tscn")
	assert_contains(src, 'path="res://Assets/Images/UI/star.png"', "the card's star is star.png")
	assert_false(src.contains("icon_star.svg"), "the old placeholder is gone")
```

- [ ] **Step 2: Red.** `test_run` suites `stat_check` and
  `minigame_result_popup` → the new assertions fail.

- [ ] **Step 3: Scenes (editor closed).** `StatCheck.tscn`: change ext
  `4_qgn2j` to `path="res://Assets/Images/UI/star.png"` (drop `uid=`), and
  add `nine_patch_stretch = true` to `Star1`, `Star2` and `Star3`.
  `EventStudentCard.tscn`: change ext `8_8prce` the same way.

- [ ] **Step 4: Scripts.** `ResultStar.gd`: set both `DEFAULT_*_TEXTURE`s to
  `"res://Assets/Images/UI/star.png"`, and update their `##` lines ("the
  2026-09-19 glossy star; the empty one is the same art darkened by
  popup_star_empty_color"). `BaseMinigame.gd`:
  `@export var popup_star_color: Color = Color.WHITE`, with its `##` line
  becoming "Tint multiplied onto the filled star. White keeps star.png's own
  gold." Fix the empty-colour `##` line likewise: it is applied to the
  texture, not "ignored". `StarMeter.gd:5`: `icon_star.svg` → `star.png`.

- [ ] **Step 5: Green.** Relaunch, then `test_run` suites `stat_check`,
  `minigame_result_popup`, `minigame_star_rubric`, `light_ground_text`,
  `project_hygiene`, `script_documentation`.

- [ ] **Step 6: Orphans.** Run `git grep -n -E "icon_star\.svg|icon_bintang"
  -- . ":!docs"`. If it is empty, `git rm` the three SVGs and their
  `.import` files, and delete their entries in `DEBT.md`'s placeholder
  inventory. If `project_hygiene` lists the names, remove them there too.
  Re-run `project_hygiene`.

- [ ] **Step 7: Commit**: `feat(stars): every result star uses the new star art`.

---

### Task 8: Docs, the visual check, and the full suite

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (a new entry at the top),
  `docs/superpowers/DEBT.md` (the `title_weekly_results.png` orphan notes at
  ~l.60 and ~l.323 are resolved: delete them).

- [ ] **Step 1: Docs.** CHANGELOG entry
  `## 2026-09-19 — Weekly Results mockup pass`: ribbon back, three tiles
  (Poin removed), light-red Logs, `star.png` everywhere, and the tokens
  added.

- [ ] **Step 2: Visual check.** `project_run(session_id="<WT>")`, then open
  Debug → Scenes → 📊 Laporan Mingguan (open the overlay first; see memory
  "debug teleport toggles the overlay"). Take one full-size screenshot and
  compare it with the mockup: ribbon on top, yellow panel, three white tiles
  with icon above number, light-red LOGS. Fix only real mismatches.
  `project_manage(op="stop")`.

- [ ] **Step 3: Full suite.** Open `Scenes/MainMenu/main_menu.tscn`, then
  `test_run(session_id="<WT>")` → 0 failures. Budget one editor restart
  after it (the bridge drops). Re-run any lone theme failure by itself
  before believing it.

- [ ] **Step 4: Clean the tree.** Quit the editor, revert
  `default_bus_layout.tres` and the portrait/splash `.import` rewrites, and
  confirm `git status` shows only intended files. Commit:
  `docs(result-checkup): changelog and debt for the mockup pass`.
