# Weekly Results Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Stay in one session: the Godot bridge takes one client. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild ResultCheckup, the end-of-week screen, to `docs/superpowers/mockups/mockup_weeklyresults.png`. The screen shows a red WEEKLY RESULTS ribbon, one week card per student, the week's coins, minigames won and lost, and two buttons: Logs and Selanjutnya.

**Architecture:**
- The student card (`DaySummaryStudentRow`, week mode) is reused unchanged.
- ResultCheckup's scene is rebuilt around it:
  - a ribbon `TextureRect`
  - a card scroll
  - a three-line summary in the card's own `DaySummaryStat` text style
  - two buttons on a new `ResultButton` variation, textured with the card's cream art
- Logs opens a new `WeekLogsPopup` scene that lists the existing `WeekHistoryRow`s.
- The old banner, pills, pill info popup and tabs are retired.
- SchoolDay now hands the Wirausaha payout in, because it empties `pending_earnings` before the screen opens.

**Tech Stack:** Godot 4.6.2 and GDScript. Tests are `McpTestSuite` suites run in the editor through the godot-ai MCP `test_run`. Placeholder art comes from PowerShell with `System.Drawing` and C# `Add-Type`.

**Spec:** `docs/superpowers/specs/2026-09-14-weekly-results-design.md`

## Global Constraints

- **Where to work:** the worktree `C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\weekly-results`, branch `feat/weekly-results`. Run git as plain, separate commands from that directory. Print `git branch --show-current` before every commit.
- **The editor:** this worktree's own Godot editor. Its session id is `weekly-results@66a0` now, and it changes on every restart. Re-read it with `session_manage(op="list")` (the row whose `project_path` ends in `worktrees/weekly-results/`). Pass it as `session_id` to every godot-ai call; below it is written `<SESSION>`. Never call `session_activate`. Never touch the main checkout's editor (`new-game-project@…`).
- **Restart the editor** by running the PowerShell block in "Appendix A: restart".
- **No `theme_override_*`** except the layout constants `separation` and `margin_*`. Styling comes from ThemeFactory variations.
- **No visual built at runtime.** No `Control`, `TextureRect`, `Label` or `StyleBox` `.new(` in these scripts. PackedScene `.instantiate()` of an authored scene is fine.
- **Script documentation:** every script has a `##` header, and every `@export` has a `##` line (enforced by `tests/test_script_documentation.gd`).
- **Test suites:** `@tool`, override `suite_name()`, contain no coroutine tests, and extend `McpTestSuiteCompat` if they call `assert_not_null` (`test_project_hygiene`).
- **Text:**
  - The UI copy, exactly: `EVENT BERHASIL : `, `EVENT GAGAL : `, `Logs`, `Selanjutnya`, `LOGS`, `Tutup`, and `Tidak ada minigame yang dimainkan minggu ini.`
  - No emoji anywhere.
- **Button geometry:** authored heights are size steps (96/128/160), and touch targets are at least 96.
- **Popups:** follow the popup-dismiss rule. The scrim starts at `MOUSE_FILTER_IGNORE` and turns STOP only after the open.
- **`Scripts/Balance.gd`:** never edited.
- **Editor save hazards (CLAUDE.md 4 and 4b):**
  - Edit `.tscn` files only through the editor: `scene_open`, then `batch_execute`, then `scene_save`.
  - A `Control` created under a plain `Control` needs `layout_mode = 1` before anchors.
  - After any `.gd` change made while the editor is up, restart the editor before the next `scene_save`.
  - After every `scene_save`, check `git diff HEAD -- '*.gd'` for files you did not mean to change.
- **Theme bake:** after a rebake, restart the editor before any scene work (memory: "Rebake, then restart before saving"). Never hand-merge `kejartes_theme.tres`.

---

### Task 1: WeekRecap counts the minigames lost

**Files:**
- Modify: `Scripts/SchoolSimulation/WeekRecap.gd:35-61`
- Test: `tests/test_week_recap.gd`

**Interfaces:**
- Produces: `WeekRecap.compute(manager)` returns a Dictionary that also carries `"minigames_lost": int`. It counts played minigames with `won == false`, never `"Event"` entries.

- [ ] **Step 1: Write the failing tests.** Use `script_patch` on `res://tests/test_week_recap.gd` to insert these after `test_all_event_history_reports_no_minigames` (anchor: the line `func test_null_manager_reports_zeroes_rather_than_erroring() -> void:`):

```gdscript
func test_minigames_lost_counts_played_losses_only() -> void:
	var m := _manager([
		_entry("Senin", "Olahraga", true),
		_entry("Selasa", "Akademis", false),
		_entry("Rabu", "Event", true),
		_entry("Kamis", "SeniBudaya", false),
	], {})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_won"], 1, "one played win")
	assert_eq(r["minigames_lost"], 2, "two played losses")
	assert_eq(r["minigames_won"] + r["minigames_lost"], r["minigames_total"],
		"won + lost = played")


## Random events are recorded won and cannot fail -- even an entry that
## says otherwise is never counted as a lost minigame.
func test_an_event_is_never_a_loss() -> void:
	var m := _manager([_entry("Rabu", "Event", false)], {})
	assert_eq(WeekRecap.compute(m)["minigames_lost"], 0,
		"an Event entry is not a minigame")


```

- [ ] **Step 2: Run it and watch it fail.**

  Run: `test_run(suite="week_recap", session_id="<SESSION>")`

  Expected: the 2 new tests FAIL, with `minigames_lost` missing from the Dictionary.

- [ ] **Step 3: Implement.** `script_patch` `res://Scripts/SchoolSimulation/WeekRecap.gd`, in two places.

  First, change
  ```gdscript
  		"minigames_total": 0,
  ```
  to
  ```gdscript
  		"minigames_lost": 0,
  		"minigames_total": 0,
  ```
  Second, change
  ```gdscript
  			if entry.get("won", false):
  				result["minigames_won"] += 1
  ```
  to
  ```gdscript
  			if entry.get("won", false):
  				result["minigames_won"] += 1
  			else:
  				result["minigames_lost"] += 1
  ```

- [ ] **Step 4: Run it and watch it pass.**

  Run: `test_run(suite="week_recap", session_id="<SESSION>")`

  Expected: every test PASSES.

- [ ] **Step 5: Commit**

```bash
git branch --show-current
git add Scripts/SchoolSimulation/WeekRecap.gd tests/test_week_recap.gd
git commit -m "feat(week-recap): count the minigames lost" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: The ResultButton variation

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (a new function after `_build_main_menu_button`, and its call in `_build_buttons` after `_build_shop_shelf_button(theme, tokens)`, near line 327)
- Modify: `tests/test_button_geometry.gd` (the `RADIUS_EXEMPT` dictionary at line 27, plus one new test)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`, line 317)
- Rebaked: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Produces: the theme type variation `ResultButton`, based on `Button`. Its `normal`, `hover`, `pressed` and `disabled` styleboxes are the `StyleBoxTexture` over `res://Assets/Images/DaySummary/card_bg.png`. It uses the display font at `tokens.day_stat_size`, white, with the `tokens.day_glyph_outline` outline.

- [ ] **Step 1: Write the failing tests.**

  `script_patch` `res://tests/test_button_geometry.gd`. Change
  ```gdscript
  const RADIUS_EXEMPT := {
  	"MainMenuButton":
  		"StyleBoxTexture -- the gold gloss is painted, so the corner lives in menu_button.png",
  ```
  to
  ```gdscript
  const RADIUS_EXEMPT := {
  	"MainMenuButton":
  		"StyleBoxTexture -- the gold gloss is painted, so the corner lives in menu_button.png",
  	"ResultButton":
  		"StyleBoxTexture -- Weekly Results' cream buttons are the student card's own card_bg.png, so the corner lives in the art",
  ```
  Then append this test at the end of the file:
  ```gdscript


  ## ResultButton is exempt from the radius rule because its corner is
  ## painted into card_bg.png -- so pin that it really draws that art
  ## (2026-09-14 weekly-results spec).
  func test_result_button_draws_the_card_art() -> void:
  	var sb := _theme.get_stylebox("normal", "ResultButton") as StyleBoxTexture
  	assert_true(sb != null and sb.texture != null,
  		"ResultButton/normal must be a textured StyleBoxTexture")
  	if sb != null and sb.texture != null:
  		assert_eq(sb.texture.resource_path, "res://Assets/Images/DaySummary/card_bg.png",
  			"ResultButton must use the student card's own art")
  ```

  `script_patch` `res://tests/test_theme_factory.gd`. Change
  ```gdscript
  	"RecapPillValueLabel", "ScoreHudValueLabel",
  ```
  to
  ```gdscript
  	"RecapPillValueLabel", "ScoreHudValueLabel",
  	# 2026-09-14 Weekly Results: the cream Logs / Selanjutnya buttons.
  	"ResultButton",
  ```

- [ ] **Step 2: Run them and watch them fail.**

  Run: `test_run(suite="button_geometry", session_id="<SESSION>")`, then `test_run(suite="theme_factory", session_id="<SESSION>")`

  Expected:
  - `test_result_button_draws_the_card_art` FAILS: the variation is missing.
  - `theme_factory`'s display-roster test FAILS: `ResultButton` is not in the theme.

- [ ] **Step 3: Implement.** `script_patch` `res://Scripts/Design/ThemeFactory.gd`.

  First, change
  ```gdscript
  	_build_main_menu_button(theme, tokens)
  	_build_shop_shelf_button(theme, tokens)
  ```
  to
  ```gdscript
  	_build_main_menu_button(theme, tokens)
  	_build_shop_shelf_button(theme, tokens)
  	_build_result_button(theme, tokens)
  ```
  Second, insert this function directly above the line `## The main menu's three nav buttons.`:
  ```gdscript
  ## Weekly Results' two cream buttons, Logs and Selanjutnya (2026-09-14
  ## weekly-results spec). The student card's own card_bg.png, 9-sliced, so
  ## the buttons read as the same material as the cards above them, with the
  ## card's white display text and purple glyph outline (the "+12/65" look).
  ##
  ## A StyleBoxTexture, so the corner lives in the art: test_button_geometry
  ## exempts it from the radius rule and checks the texture path instead, as
  ## it does for MainMenuButton.
  static func _build_result_button(theme: Theme, tokens: DesignTokens) -> void:
  	const NAME := "ResultButton"
  	theme.add_type(NAME)
  	theme.set_type_variation(NAME, "Button")

  	var normal := StyleBoxTexture.new()
  	normal.texture = load("res://Assets/Images/DaySummary/card_bg.png")
  	normal.texture_margin_left = 40
  	normal.texture_margin_right = 40
  	normal.texture_margin_top = 40
  	normal.texture_margin_bottom = 48
  	normal.content_margin_left = 24
  	normal.content_margin_right = 24
  	normal.content_margin_top = 0
  	normal.content_margin_bottom = 12
  	# The art carries no state variants; press feedback is UIPolish's Juice.
  	for state in ["normal", "hover", "pressed", "disabled"]:
  		theme.set_stylebox(state, NAME, normal)
  	theme.set_stylebox("focus", NAME, StyleBoxEmpty.new())

  	for color_name in ["font_color", "font_hover_color", "font_pressed_color",
  			"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
  		theme.set_color(color_name, NAME, Color.WHITE)
  	theme.set_color("font_outline_color", NAME, tokens.day_glyph_outline)
  	theme.set_constant("outline_size", NAME, maxi(2, tokens.text_outline_size / 2))
  	theme.set_font_size("font_size", NAME, tokens.day_stat_size)
  	if tokens.font_display != null:
  		theme.set_font("font", NAME, tokens.font_display)


  ```

- [ ] **Step 4: Run the two suites and watch them pass.**

  Run: `test_run(suite="button_geometry", session_id="<SESSION>")`, then `test_run(suite="theme_factory", session_id="<SESSION>")`

  Expected: every test PASSES.

- [ ] **Step 5: Rebake, and check nothing else objects.**

  Run: `test_run(suite="theme_rebake", session_id="<SESSION>")`. It rebakes `kejartes_theme.tres` in-process.

  Then run each suite that walks every theme type, and expect every test to PASS: `test_run(suite=…)` with `light_ground_text`, `day_summary`, `lobby`, `run_result`, `event_warning`, `event_dialogue`, `student_card_layout`, `basket_tray` and `activity_row`.

  If one fails on `ResultButton`, read the rule it enforces. Either satisfy it in `_build_result_button`, or add a reasoned exemption in that suite in the same style as its existing ones. Then re-run it.

  Finally, check the bake:
  ```bash
  git diff --stat -- Assets/Theme/kejartes_theme.tres
  ```
  ```bash
  git diff -- Assets/Theme/kejartes_theme.tres
  ```
  The diff must add a `ResultButton/` block. Renumbered sub-resource IDs are fine.

- [ ] **Step 6: Restart the editor** with Appendix A, then re-read `<SESSION>`.

- [ ] **Step 7: Commit**

```bash
git branch --show-current
git add Scripts/Design/ThemeFactory.gd tests/test_button_geometry.gd tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): ResultButton, the cream card-art button for Weekly Results" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The WEEKLY RESULTS ribbon (placeholder)

**Files:**
- Create: `Assets/Images/DaySummary/title_weekly_results.png`, plus the `.import` file the editor writes

**Interfaces:**
- Produces: `res://Assets/Images/DaySummary/title_weekly_results.png`. It is the same canvas size as `title_daily_results.png` (1058x325) and transparent outside the ribbon. Task 5's `TitleBanner` uses it at the daily popup's size (932x286).

- [ ] **Step 1: Cut the ribbon from the mockup.** Take the mockup's pixels and give them the daily ribbon's alpha. The two ribbons are aligned by the bounding box of their bright red, so the new image keeps exactly the daily ribbon's outline. Run in PowerShell:

```powershell
$wt = 'C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\weekly-results'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging;
public static class RibbonCut {
  static bool IsRed(Color c) { return c.A > 200 && c.R > 150 && c.G < 70 && c.B < 70; }
  public static Rectangle RedBox(Bitmap b, int maxY) {
    int x0 = b.Width, y0 = b.Height, x1 = -1, y1 = -1;
    for (int y = 0; y < Math.Min(maxY, b.Height); y++)
      for (int x = 0; x < b.Width; x++)
        if (IsRed(b.GetPixel(x, y))) { x0 = Math.Min(x0, x); y0 = Math.Min(y0, y); x1 = Math.Max(x1, x); y1 = Math.Max(y1, y); }
    return Rectangle.FromLTRB(x0, y0, x1 + 1, y1 + 1);
  }
  public static Bitmap Cut(Bitmap mock, Bitmap daily, out string report) {
    Rectangle rm = RedBox(mock, 420), rd = RedBox(daily, daily.Height);
    double sx = (double)rm.Width / rd.Width, sy = (double)rm.Height / rd.Height;
    var o = new Bitmap(daily.Width, daily.Height, PixelFormat.Format32bppArgb);
    for (int y = 0; y < daily.Height; y++)
      for (int x = 0; x < daily.Width; x++) {
        int a = daily.GetPixel(x, y).A;
        if (a == 0) { o.SetPixel(x, y, Color.Transparent); continue; }
        int mx = (int)Math.Round(rm.X + (x - rd.X) * sx), my = (int)Math.Round(rm.Y + (y - rd.Y) * sy);
        mx = Math.Max(0, Math.Min(mock.Width - 1, mx)); my = Math.Max(0, Math.Min(mock.Height - 1, my));
        Color m = mock.GetPixel(mx, my);
        o.SetPixel(x, y, Color.FromArgb(a, m.R, m.G, m.B));
      }
    report = string.Format("mock red {0} | daily red {1} | scale {2:F3} x {3:F3}", rm, rd, sx, sy);
    return o;
  }
}
'@
$mock = [System.Drawing.Bitmap]::FromFile("$wt\docs\superpowers\mockups\mockup_weeklyresults.png")
$daily = [System.Drawing.Bitmap]::FromFile("$wt\Assets\Images\DaySummary\title_daily_results.png")
$report = ''
$out = [RibbonCut]::Cut($mock, $daily, [ref]$report)
$out.Save("$wt\Assets\Images\DaySummary\title_weekly_results.png", [System.Drawing.Imaging.ImageFormat]::Png)
$report
$mock.Dispose(); $daily.Dispose(); $out.Dispose()
```

  Expected: a report line like `mock red {X=…,Y=…,Width≈900,Height≈260} | daily red {…} | scale ≈0.9 x ≈0.9`. If the two scale factors differ by more than 0.05, the ribbons aren't the same art. Stop and note it in the final report, but keep the file: it is still a usable placeholder.

- [ ] **Step 2: Look at it.** Read `Assets/Images/DaySummary/title_weekly_results.png` (the image) and the mockup's top 400 px. Expected:
  - the ribbon reads "WEEKLY RESULTS" in white on red, with the daily ribbon's dark outline;
  - the corners are transparent;
  - no blurred background shows as a fringe wider than about 3 px.

  A thin fringe is acceptable, since this is a placeholder.

- [ ] **Step 3: Import it.** Run `filesystem_manage(op="scan", session_id="<SESSION>")`. Then check that `Assets/Images/DaySummary/title_weekly_results.png.import` exists.

- [ ] **Step 4: Commit**

```bash
git branch --show-current
git add Assets/Images/DaySummary/title_weekly_results.png Assets/Images/DaySummary/title_weekly_results.png.import
git commit -m "art(weekly-results): placeholder WEEKLY RESULTS ribbon cut from the mockup" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: WeekLogsPopup, the Logs sheet

**Files:**
- Create: `Scripts/SchoolSimulation/WeekLogsPopup.gd`
- Create: `Scenes/SchoolSimulation/WeekLogsPopup.tscn`
- Create: `tests/test_week_logs_popup.gd`

**Interfaces:**
- Consumes: `WeekHistoryRow` (`set_entry(entry: Dictionary)`, `is_event() -> bool`, `is_win() -> bool`) and `res://Scenes/SchoolSimulation/WeekHistoryRow.tscn`.
- Produces: `class_name WeekLogsPopup` (a Control):
  - `signal closed`
  - `set_history(entries: Array) -> void`
  - `row_count() -> int`
  - `open(animate_rows: bool = true) -> void`
  - `close() -> void`
  - `@onready` fields `scrim`, `card`, `title_label`, `rows`, `empty_label`, `close_button`
  - `@export history_row_scene: PackedScene`

- [ ] **Step 1: Write the failing suite.** Write `tests/test_week_logs_popup.gd`:

```gdscript
@tool
extends McpTestSuiteCompat

## WeekLogsPopup (2026-09-14 weekly-results spec): the Logs sheet Weekly
## Results opens -- one WeekHistoryRow per history entry, over a scrim that
## follows the popup-dismiss rule.

const _SCENE := "res://Scenes/SchoolSimulation/WeekLogsPopup.tscn"
const _SCRIPT := "res://Scripts/SchoolSimulation/WeekLogsPopup.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "week_logs_popup"


## The sheet wearing the baked theme, in the tree so its @onready vars are
## live, freed by the runner. Untyped: typed as Control, GDScript rejects
## the script members.
func _popup():
	var p = (load(_SCENE) as PackedScene).instantiate()
	p.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(p)
	track(p)
	return p


func _entry(day: String, category: String, won: bool) -> Dictionary:
	return {"day": day, "category": category, "game_name": "Uji", "won": won}


func test_the_scene_authors_every_node_the_script_binds() -> void:
	var p = _popup()
	for path in ["Scrim", "Center/Card", "Center/Card/Content/TitleLabel",
			"Center/Card/Content/Scroll/Rows",
			"Center/Card/Content/Scroll/Rows/EmptyLabel",
			"Center/Card/Content/CloseButton"]:
		assert_not_null(p.get_node_or_null(path), path + " is authored")


func test_the_scene_supplies_the_history_row_template() -> void:
	var p = _popup()
	assert_not_null(p.history_row_scene, "history_row_scene is assigned")
	assert_eq(p.history_row_scene.resource_path,
		"res://Scenes/SchoolSimulation/WeekHistoryRow.tscn")


func test_the_labels_come_from_the_exports() -> void:
	var p = _popup()
	assert_eq(p.title_label.text, "LOGS")
	assert_eq(p.close_button.text, "Tutup")
	assert_eq(p.empty_label.text, "Tidak ada minigame yang dimainkan minggu ini.")


func test_one_row_per_history_entry_events_included() -> void:
	var p = _popup()
	p.set_history([_entry("Senin", "Akademis", true), _entry("Rabu", "Event", true),
		_entry("Kamis", "Olahraga", false)])
	assert_eq(p.row_count(), 3, "one row per entry, events included")
	assert_false(p.empty_label.visible, "the empty line hides when there is history")
	assert_true(p.rows.get_child(1) is WeekHistoryRow,
		"rows are WeekHistoryRow instances after the authored EmptyLabel")


func test_an_empty_week_shows_the_empty_line() -> void:
	var p = _popup()
	p.set_history([])
	assert_eq(p.row_count(), 0, "no rows")
	assert_true(p.empty_label.visible, "the empty line explains why")


func test_set_history_replaces_rather_than_appends() -> void:
	var p = _popup()
	p.set_history([_entry("Senin", "Akademis", true)])
	p.set_history([_entry("Selasa", "Olahraga", false), _entry("Rabu", "Event", true)])
	assert_eq(p.row_count(), 2, "a second fill replaces the first")


func test_the_scrim_waits_for_the_open() -> void:
	var p = _popup()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"popup-dismiss rule: the opening tap must not also close it")
	p.open()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_STOP,
		"after the open, tapping the dim closes it")


func test_tapping_the_dim_closes_the_sheet() -> void:
	var p = _popup()
	p.open()
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	p._on_scrim_gui_input(tap)
	assert_true(closed[0], "tapping the dim closes the sheet")


func test_the_close_button_closes_the_sheet_once() -> void:
	var p = _popup()
	var count := [0]
	p.closed.connect(func(): count[0] += 1)
	p.close_button.pressed.emit()
	p.close()
	assert_eq(count[0], 1, "closed fires exactly once")


func test_the_center_never_swallows_a_tap_meant_for_the_dim() -> void:
	var p = _popup()
	assert_eq((p.get_node("Center") as Control).mouse_filter,
		Control.MOUSE_FILTER_IGNORE, "taps outside the card must reach the Scrim")


func test_the_sheet_is_authored_not_built() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_false(src.contains(".new("), "no node or stylebox is built at runtime")
	var scene := FileAccess.get_file_as_string(_SCENE)
	for kind in ["theme_override_colors", "theme_override_font_sizes",
			"theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in WeekLogsPopup.tscn")


func test_the_rows_entrance_keeps_stamp_and_shake() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_contains(src, 'play_sfx(&"stamp")', "a won minigame stamps")
	assert_contains(src, "Juice.shake(row)", "a lost one shakes")
	assert_contains(src, "row.is_event()", "an event does neither")
```

- [ ] **Step 2: Run it and watch it fail.** Run `filesystem_manage(op="scan", session_id="<SESSION>")`, then `test_run(suite="week_logs_popup", session_id="<SESSION>")`.

  Expected: the tests FAIL, because the scene does not exist.

- [ ] **Step 3: Write the script.** Write `Scripts/SchoolSimulation/WeekLogsPopup.gd`:

```gdscript
@tool
extends Control
class_name WeekLogsPopup

## Weekly Results' Logs sheet (2026-09-14 weekly-results spec): the week's
## minigames and random events as WeekHistoryRows, over a scrim.
## ResultCheckup instances it when Logs is tapped; it frees itself once it
## closes. Every node is authored in WeekLogsPopup.tscn; the script only
## fills the rows, opens, and closes.
##
## @tool so the editor's test runner can build it. Real side effects --
## audio and tweens -- are gated on Engine.is_editor_hint(); signal wiring is
## not.

## Emitted once, when the sheet closes for any reason.
signal closed

## The history row template, WeekHistoryRow.tscn.
@export var history_row_scene: PackedScene
## The sheet's heading.
@export var title_text: String = "LOGS"
## The close button's label.
@export var close_text: String = "Tutup"
## Shown instead of rows when the week logged nothing.
@export var empty_text: String = "Tidak ada minigame yang dimainkan minggu ini."

@onready var scrim: Panel = $Scrim
@onready var card: PanelContainer = $Center/Card
@onready var title_label: Label = $Center/Card/Content/TitleLabel
@onready var rows: VBoxContainer = $Center/Card/Content/Scroll/Rows
@onready var empty_label: Label = $Center/Card/Content/Scroll/Rows/EmptyLabel
@onready var close_button: Button = $Center/Card/Content/CloseButton

## The instanced rows, in history order.
var _rows: Array = []
var _is_closed := false


func _ready() -> void:
	close_button.pressed.connect(close)
	scrim.gui_input.connect(_on_scrim_gui_input)
	title_label.text = title_text
	close_button.text = close_text
	empty_label.text = empty_text


## One row per history entry, events included; the empty line when there
## are none. Replaces whatever the sheet held before.
func set_history(entries: Array) -> void:
	for child in rows.get_children():
		if child != empty_label:
			rows.remove_child(child)
			child.queue_free()
	_rows.clear()
	empty_label.visible = entries.is_empty()
	for entry in entries:
		var row := history_row_scene.instantiate() as WeekHistoryRow
		rows.add_child(row)
		row.set_entry(entry)
		_rows.append(row)


## How many history rows the sheet holds.
func row_count() -> int:
	return _rows.size()


## Show the sheet. The scrim ignores input until the pop-in is done (the
## popup-dismiss rule), so the tap that opened it can never also close it.
## `animate_rows` plays the rows' stamp-and-shake entrance; ResultCheckup
## passes true on the first open only.
func open(animate_rows: bool = true) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	AudioDirector.play_sfx(&"popup_open")
	Juice.pop_in(card)
	var t := Juice.tokens()
	var arm := create_tween()
	arm.tween_interval(t.dur_normal)
	arm.tween_callback(func(): scrim.mouse_filter = Control.MOUSE_FILTER_STOP)
	if animate_rows and not _rows.is_empty():
		# A beat between popup_open and the first stamp, so the two cues land
		# as two gestures (tests/test_audio_coverage.gd's double-fire guard).
		await get_tree().create_timer(t.dur_normal).timeout
		_play_rows_entrance()


## Close the sheet and hand control back. Safe to call twice.
func close() -> void:
	if _is_closed:
		return
	_is_closed = true
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"popup_close")
	closed.emit()
	queue_free()


func _on_scrim_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close()


## Rows stagger in; a win stamps into place, a loss shakes, an event does
## neither.
func _play_rows_entrance() -> void:
	Juice.stagger_in(_rows)
	for row in _rows:
		if not is_instance_valid(row) or row.is_event():
			continue
		if row.is_win():
			AudioDirector.play_sfx(&"stamp")
		else:
			Juice.shake(row)
```

  Then run `filesystem_manage(op="scan", session_id="<SESSION>")`.

- [ ] **Step 4: Author the scene in the editor.**
  1. Create it with `scene_manage(op="create", session_id="<SESSION>")`: path `res://Scenes/SchoolSimulation/WeekLogsPopup.tscn`, root type `Control`, root name `WeekLogsPopup`.
  2. Build the tree below with `batch_execute` (`create_node`, `set_property`, `attach_script`). Numbers are unquoted. Set `layout_mode` 1 before the anchors on each child of the root `Control`.
  3. Run `scene_save`.

  | Node (path from root) | Type | Properties |
  |---|---|---|
  | `.` | Control | anchor_left 0, anchor_top 0, anchor_right 1, anchor_bottom 1, offsets 0; script `res://Scripts/SchoolSimulation/WeekLogsPopup.gd`; `history_row_scene` = `res://Scenes/SchoolSimulation/WeekHistoryRow.tscn` |
  | `Scrim` | Panel | layout_mode 1, anchor_right 1, anchor_bottom 1, offsets 0, `theme_type_variation` `Scrim`, mouse_filter 2 |
  | `Center` | CenterContainer | layout_mode 1, anchor_right 1, anchor_bottom 1, offsets 0, mouse_filter 2 |
  | `Center/Card` | PanelContainer | `theme_type_variation` `Card`, custom_minimum_size (960, 0) |
  | `Center/Card/Content` | VBoxContainer | `theme_override_constants/separation` 24 |
  | `Center/Card/Content/TitleLabel` | Label | `theme_type_variation` `H2Label`, text `LOGS`, horizontal_alignment 1 |
  | `Center/Card/Content/Scroll` | ScrollContainer | custom_minimum_size (0, 1200), horizontal_scroll_mode 0 |
  | `Center/Card/Content/Scroll/Rows` | VBoxContainer | size_flags_horizontal 3, `theme_override_constants/separation` 16 |
  | `Center/Card/Content/Scroll/Rows/EmptyLabel` | Label | `theme_type_variation` `EmptyStateLabel`, text `Tidak ada minigame yang dimainkan minggu ini.`, horizontal_alignment 1, autowrap_mode 2, visible false |
  | `Center/Card/Content/CloseButton` | Button | `theme_type_variation` `SecondaryButton`, text `Tutup`, custom_minimum_size (0, 96) |

  After saving, run `git diff HEAD -- '*.gd'`. Only the files this task created should appear.

- [ ] **Step 5: Run it and watch it pass.**

  Run: `test_run(suite="week_logs_popup", session_id="<SESSION>")`, then the same for `popup_dismiss`, `button_geometry` and `script_documentation`.

  Expected: every test PASSES.

- [ ] **Step 6: Commit**

```bash
git branch --show-current
git add Scripts/SchoolSimulation/WeekLogsPopup.gd Scripts/SchoolSimulation/WeekLogsPopup.gd.uid Scenes/SchoolSimulation/WeekLogsPopup.tscn tests/test_week_logs_popup.gd tests/test_week_logs_popup.gd.uid
git commit -m "feat(weekly-results): the Logs sheet, WeekLogsPopup" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

  (Skip any `.uid` path that `git status` does not show.)

---

### Task 5: ResultCheckup rebuilt to the mockup

**Files:**
- Rewrite: `Scripts/SchoolSimulation/ResultCheckup.gd`
- Rebuild: `Scenes/SchoolSimulation/ResultCheckup.tscn`
- Modify: `tests/test_result_checkup.gd` (line 384 to the end is replaced)
- Modify: `tests/test_school_day.gd:240-241` (touch targets)
- Modify: `tests/test_viewport_editability.gd:82` (the ratchet entry goes)
- Modify: `docs/superpowers/specs/2026-09-14-weekly-results-design.md` (the Logs row: instanced per tap)

**Interfaces:**
- Consumes:
  - `WeekRecap.compute()["minigames_won"/"minigames_lost"]` (Task 1)
  - the `ResultButton` variation (Task 2)
  - `title_weekly_results.png` (Task 3)
  - `WeekLogsPopup` (Task 4)
  - `DaySummaryStudentRow.setup_week_row(student)`, `play_week_gain(delay)` and `gained_ground()`
- Produces:
  - `initialize_checkup(student_manager: StudentManager, week_earnings: int = 0) -> void`
  - `static format_earnings(value: int) -> String`
  - `open_logs() -> void`
  - `signal checkup_closed`
  - `@onready` fields `title_banner`, `cards_scroll`, `cards_list`, `money_label`, `event_won_label`, `event_lost_label`, `logs_button`, `next_button`
  - `@export` fields `student_card_scene` and `logs_popup_scene`

- [ ] **Step 1: Write the failing tests.** In `tests/test_result_checkup.gd`, add `const _LOGS_SCENE := "res://Scenes/SchoolSimulation/WeekLogsPopup.tscn"` under `_CHECKUP_SCRIPT` (line 22). Then **replace everything from line 384 (`func test_the_checkup_scene_supplies_the_week_card`) to the end of the file** with the block below. Lines 1-383 (the helpers and the week-card tests) stay as they are. Write the whole file, then run a no-op `script_patch` on it to force the reload (CLAUDE.md §5).

```gdscript
func test_the_checkup_scene_supplies_the_week_card() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var packed: PackedScene = inst.student_card_scene
	assert_not_null(packed, "ResultCheckup.tscn must assign student_card_scene")
	assert_eq(packed.resource_path, _ROW_SCENE,
		"the weekly card must be the Daily Results card scene itself")
	inst.free()


## The Logs sheet is a scene of its own, instanced on each Logs tap.
func test_the_checkup_scene_supplies_the_logs_sheet() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var packed: PackedScene = inst.logs_popup_scene
	assert_not_null(packed, "ResultCheckup.tscn must assign logs_popup_scene")
	assert_eq(packed.resource_path, _LOGS_SCENE, "Logs opens WeekLogsPopup")
	inst.free()


## The screen with the baked theme, in the tree, freed by the runner.
## Untyped: typed as Control, GDScript rejects the script members.
func _themed_checkup():
	var inst = (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	return inst


## The source block of one node, from its header to the next section.
func _node_block(src: String, node_name: String) -> String:
	var start := src.find('[node name="%s" ' % node_name)
	if start == -1:
		return ""
	var end := src.find("\n[", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


## The screen end to end: a StudentManager whose first default has moved,
## one card per student, each reading its own week.
func test_the_checkup_builds_one_week_card_per_student() -> void:
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.students[0].akademis += 12.0

	inst.initialize_checkup(manager)

	var container: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	assert_eq(container.get_child_count(), manager.students.size(),
		"one card per student in the roster")
	var first = container.get_child(0)
	assert_true(first is DaySummaryStudentRow,
		"the checkup must show the Daily Results card, not a hand-built panel")
	assert_eq(first.name_label.text, manager.students[0].student_name,
		"each card is labelled with the student it was built for")
	assert_eq(first.stat_rows[0].value.text,
		"+12/%d" % int(round(manager.students[0].target_akademis1)),
		"the card must read the WEEK's gain against that student's target")
	assert_false(first.energy_delta_label.visible,
		"the number itself stays hidden")
	var chevron: TextureRect = first.get_node("EnergyBar/DeltaChevron")
	assert_not_null(chevron, "the weekly card still shows its needs delta, as a chevron")


## The old screen hand-built a five-StatBar panel per student, plus an
## avatar loader and a gradient placeholder. None of it may come back.
func test_the_checkup_no_longer_hand_builds_its_stat_bars() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_false(src.contains("func _add_stat_bar"),
		"the hand-built stat bar builder must be gone, not left beside the card")
	assert_false(src.contains("StatBar.new()"),
		"the checkup must not build StatBars any more")
	assert_false(src.contains("_placeholder_avatar"),
		"the card owns avatar fallback now (DaySummaryAvatar)")
	assert_false(src.contains("_create_student_card"),
		"the card is built inline, after add_child -- there is no builder left")
	assert_true(src.contains("setup_week_row("),
		"the checkup must feed the card the week")
	assert_true(src.contains("play_week_gain("),
		"the checkup must replay the week")


## Same rhythm the daily popup uses: cards land first, then their gauges
## start moving, offset card by card.
func test_the_checkup_fills_its_cards_after_they_land() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_true(src.contains("Juice.stagger_in(cards)"),
		"the cards must still stagger in")
	assert_true(src.find("Juice.stagger_in(cards)") < src.find("play_week_gain("),
		"the fill must be kicked off after stagger_in, not before it")


## A card's @onready nodes are null until it enters the tree, so setting it
## up before add_child crashes. Both strings must exist: the old version of
## this test searched for a container name the script no longer had, so
## find() returned -1 and the test always passed (CLAUDE.md debt entry,
## fixed 2026-09-14).
func test_the_checkup_sets_each_card_up_only_once_it_is_in_the_tree() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	var add := src.find("cards_list.add_child(card)")
	var setup := src.find("card.setup_week_row(")
	assert_true(add != -1 and setup != -1, "both calls exist")
	assert_true(add < setup,
		"add_child must come before setup_week_row -- @onready nodes are null outside the tree")


## Mockup order, top to bottom: ribbon, cards, summary, buttons.
func test_the_screen_authors_the_mockup_layout_in_order() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var order := []
	for child in screen.get_node("Margin/Layout").get_children():
		order.append(String(child.name))
	assert_eq(order, ["TitleBanner", "CardsScroll", "Summary", "Buttons"],
		"top to bottom as in the mockup")
	for path in ["Backdrop", "Margin/Layout/CardsScroll/CardsList",
			"Margin/Layout/Summary/Lines/CoinRow/CoinIcon",
			"Margin/Layout/Summary/Lines/CoinRow/MoneyLabel",
			"Margin/Layout/Summary/Lines/EventWonLabel",
			"Margin/Layout/Summary/Lines/EventLostLabel",
			"Margin/Layout/Buttons/LogsButton",
			"Margin/Layout/Buttons/NextButton", "Celebration"]:
		assert_not_null(screen.get_node_or_null(path), path + " is authored")
	screen.free()


func test_the_ribbon_is_the_cut_out_weekly_art() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var ribbon := screen.get_node("Margin/Layout/TitleBanner") as TextureRect
	assert_eq(ribbon.texture.resource_path,
		"res://Assets/Images/DaySummary/title_weekly_results.png")
	assert_eq(ribbon.texture.get_image().get_pixel(0, 0).a, 0.0,
		"the ribbon is cut out, not a rectangle of the mockup")
	screen.free()


## The blurred school is an authored node now; the old runtime
## TextureRect swap is gone (and so is its viewport_editability debt).
func test_the_backdrop_is_the_blurred_school_authored_in_the_scene() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var backdrop := screen.get_node("Backdrop") as TextureRect
	assert_eq(backdrop.texture.resource_path, "res://Assets/Images/UI/blur_background.png")
	assert_false(FileAccess.get_file_as_string(_CHECKUP_SCRIPT).contains(".new("),
		"nothing visual is built at runtime")
	screen.free()


## The summary is the card's own "+12/65" text; the buttons are the card's
## own cream art.
func test_the_summary_and_buttons_wear_the_card_styles() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	for n in ["MoneyLabel", "EventWonLabel", "EventLostLabel"]:
		assert_contains(_node_block(src, n), 'theme_type_variation = &"DaySummaryStat"', n)
	for n in ["LogsButton", "NextButton"]:
		assert_contains(_node_block(src, n), 'theme_type_variation = &"ResultButton"', n)


func test_the_buttons_read_as_the_mockup() -> void:
	var inst = _themed_checkup()
	assert_eq(inst.logs_button.text, "Logs")
	assert_eq(inst.next_button.text, "Selanjutnya")


func test_the_summary_reads_the_week() -> void:
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.minigame_history.assign([
		{"day": "Senin", "category": "Akademis", "game_name": "Uji", "won": true},
		{"day": "Selasa", "category": "Olahraga", "game_name": "Lomba", "won": false},
		{"day": "Rabu", "category": "Event", "game_name": "Hujan Deras", "won": true},
		{"day": "Kamis", "category": "SeniBudaya", "game_name": "Batik", "won": true},
	])
	inst.initialize_checkup(manager, 1000)
	assert_eq(inst.money_label.text, "+1.000", "the week's payout, grouped and signed")
	assert_eq(inst.event_won_label.text, "EVENT BERHASIL : 2",
		"two minigames won; the random event is not counted")
	assert_eq(inst.event_lost_label.text, "EVENT GAGAL : 1", "one minigame lost")


func test_a_week_that_earned_nothing_reads_zero() -> void:
	var script = load(_CHECKUP_SCRIPT)
	assert_eq(script.format_earnings(0), "0", "no sign on an empty week")
	assert_eq(script.format_earnings(4200), "+4.200", "a positive week is signed")


func test_logs_opens_one_sheet_with_the_weeks_history() -> void:
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.minigame_history.assign([
		{"day": "Senin", "category": "Akademis", "game_name": "Uji", "won": true},
		{"day": "Rabu", "category": "Event", "game_name": "Hujan Deras", "won": true},
	])
	inst.initialize_checkup(manager)
	inst.logs_button.pressed.emit()
	inst.logs_button.pressed.emit()
	var sheets: Array = []
	for child in inst.get_children():
		if child is WeekLogsPopup:
			sheets.append(child)
	assert_eq(sheets.size(), 1, "Logs opens the sheet, and a second tap never stacks another")
	if sheets.size() == 1:
		assert_eq(sheets[0].row_count(), 2, "every minigame and event of the week")


func test_the_rows_entrance_plays_on_the_first_open_only() -> void:
	var inst = _themed_checkup()
	inst.initialize_checkup(null)
	assert_false(inst._logs_seen, "nothing opened yet")
	inst.open_logs()
	assert_true(inst._logs_seen, "the first open latches")
	assert_contains(FileAccess.get_file_as_string(_CHECKUP_SCRIPT),
		"popup.open(not _logs_seen)", "only the first open animates the rows")


func test_selanjutnya_hands_control_back() -> void:
	var inst = _themed_checkup()
	assert_true(inst.next_button.pressed.is_connected(Callable(inst, "_on_next_pressed")),
		"Selanjutnya is wired")
	assert_true(inst.logs_button.pressed.is_connected(Callable(inst, "open_logs")),
		"and so is Logs")
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_contains(src.substr(src.find("func _on_next_pressed")), "checkup_closed.emit()",
		"Selanjutnya returns to SchoolDay, which goes on to the Lobby")


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()


## The weekly celebration is authored, gated and singular: one confetti
## node in the scene, fired only when a card actually gained, never
## constructed at runtime.
func test_checkup_celebrates_only_a_week_that_gained() -> void:
	var src := _source("res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_true(src.contains("gained_ground()"),
		"the confetti must be gated on a card having gained ground")
	assert_true(src.contains("celebration"),
		"the checkup must reference its authored confetti node")
	assert_true(not src.contains("GPUParticles2D.new()"),
		"the confetti must come from the .tscn, never be built at runtime")


func test_checkup_scene_carries_an_idle_confetti_node() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var fx := inst.get_node_or_null("Celebration") as GPUParticles2D
	assert_true(fx != null, "ResultCheckup must author a Celebration node")
	assert_true(not fx.emitting, "the confetti must start idle")
	assert_true(fx.one_shot, "the confetti must be one_shot")
	inst.free()


## The weekly celebration is the two-cannon paper burst, not the shared
## top-down CelebrationConfetti (2026-09-12 paper confetti spec).
func test_checkup_fires_the_paper_confetti() -> void:
	var src := _source(_CHECKUP_SCRIPT)
	assert_true(src.contains("PaperConfetti.tscn"),
		"the checkup must fire PaperConfetti.tscn")
	assert_true(not src.contains("CelebrationConfetti.tscn"),
		"the checkup must no longer fire CelebrationConfetti.tscn")
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var fx := inst.get_node_or_null("Celebration")
	assert_true(fx != null and fx.scene_file_path.ends_with("PaperConfetti.tscn"),
		"the Celebration marker must be a PaperConfetti instance")
	if fx != null:
		assert_true(fx.position.x < 0.0 and fx.position.y > 1500.0,
			"the marker must sit at the bottom-left corner")
	inst.free()


const _HISTORY_ROW_SCENE := "res://Scenes/SchoolSimulation/WeekHistoryRow.tscn"


func test_history_row_renders_a_minigame_win() -> void:
	# set_entry writes through @onready fields, which Godot only populates
	# once the node enters the tree.
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	row.set_entry({
		"day": "Senin", "category": "Olahraga",
		"game_name": "Lomba Badminton", "won": true,
		"score": 3, "max_score": 5,
		"results": [{"student_name": "Budi"}, {"student_name": "Doni"}],
	})
	assert_contains(_row_text(row, "Breadcrumb"), "Senin",
		"the day leads the breadcrumb")
	assert_contains(_row_text(row, "Breadcrumb"), "Olahraga",
		"the category follows it")
	assert_eq(_row_text(row, "TitleRow/NameLabel"), "Lomba Badminton",
		"the game name is the row's title")
	assert_contains(_row_text(row, "DetailLabel"), "Budi",
		"participants are named -- this is the new information")
	assert_contains(_row_text(row, "DetailLabel"), "3/5",
		"and the score is carried")
	row.queue_free()


func test_history_row_renders_an_event_with_affected_students() -> void:
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	row.set_entry({
		"day": "Rabu", "category": "Event", "game_name": "Hujan Deras",
		"won": true, "details": "Semua siswa kehilangan 5 energi",
		"affected_students": ["Ani", "Cici"],
	})
	assert_contains(_row_text(row, "DetailLabel"), "Ani",
		"affected students are named")
	assert_contains(_row_text(row, "DetailLabel"), "kehilangan",
		"and the event's own details are shown")
	row.queue_free()


func test_history_row_hides_the_detail_line_when_there_is_nothing_to_say() -> void:
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	row.set_entry({"day": "Kamis", "category": "Akademis",
		"game_name": "Password", "won": false})
	var detail: Label = row.get_node("Body/Lines/DetailLabel")
	assert_false(detail.visible,
		"an entry with no participants and no details collapses to two lines")
	row.queue_free()


func test_history_row_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekHistoryRow.gd")
	for glyph in ["📢", "📊", "📝"]:
		assert_false(src.contains(glyph),
			"emoji are banned as UI iconography; use the SVG icons")


func _row_text(row: Control, path: String) -> String:
	return (row.get_node("Body/Lines/" + path) as Label).text


## Win/loss must be read from WeekHistoryRow's own accessors, not inferred
## from the badge's tint (2026-09-03 Task 9 review, finding 1).
func test_history_row_exposes_event_and_win_state() -> void:
	var event_row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(event_row)
	event_row.set_entry({"day": "Rabu", "category": "Event",
		"game_name": "Hujan Deras", "won": true})
	assert_true(event_row.is_event(),
		"an Event-category entry must report is_event() true")
	event_row.queue_free()

	var won_row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(won_row)
	won_row.set_entry({"day": "Senin", "category": "Akademis",
		"game_name": "Uji", "won": true})
	assert_false(won_row.is_event(),
		"a played minigame must not report is_event()")
	assert_true(won_row.is_win(),
		"a won minigame must report is_win() true")
	won_row.queue_free()

	var lost_row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(lost_row)
	lost_row.set_entry({"day": "Kamis", "category": "Olahraga",
		"game_name": "Lomba", "won": false})
	assert_false(lost_row.is_event(),
		"a played minigame must not report is_event()")
	assert_false(lost_row.is_win(),
		"a lost minigame must report is_win() false")
	lost_row.queue_free()


func test_scene_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned as UI iconography")


func test_script_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned")
```

  Also make these two edits:
  - `script_patch` `res://tests/test_school_day.gd`. Change
    ```gdscript
    		"res://Scenes/SchoolSimulation/ResultCheckup.tscn": [
    			"Margin/VBox/BtnClose"],
    ```
    to
    ```gdscript
    		"res://Scenes/SchoolSimulation/ResultCheckup.tscn": [
    			"Margin/Layout/Buttons/LogsButton", "Margin/Layout/Buttons/NextButton"],
    ```
  - `script_patch` `res://tests/test_viewport_editability.gd`. Delete the line `	"res://Scripts/SchoolSimulation/ResultCheckup.gd": 1,`. The runtime backdrop swap it counted goes away in this task.

- [ ] **Step 2: Run it and watch it fail.**

  Run: `test_run(suite="result_checkup", session_id="<SESSION>")`

  Expected: the new layout, summary and Logs tests FAIL on missing nodes and exports. The card and history-row tests PASS.

- [ ] **Step 3: Rewrite the script.** Write `Scripts/SchoolSimulation/ResultCheckup.gd` in full:

```gdscript
@tool
extends Control

## Weekly Results: the end-of-week report, rebuilt to
## docs/superpowers/mockups/mockup_weeklyresults.png (2026-09-14
## weekly-results spec). A red ribbon; one DaySummaryStudentRow per student,
## read one week wide; the week's Wirausaha coins; how many minigames were
## won and lost; and two buttons -- Logs (the week's history, in a
## WeekLogsPopup) and Selanjutnya (back to SchoolDay, then the Lobby).
##
## Everything visual is an authored scene. This script only fills the
## labels, instances the cards and the Logs sheet, and runs the entrance.
##
## @tool so the in-editor test runner can build the screen and inspect it
## (CLAUDE.md, testing constraint 3). Everything with a real side effect is
## gated on Engine.is_editor_hint(); signal wiring deliberately is not.

signal checkup_closed

# ── Copy ─────────────────────────────────────────────────────────────
@export_group("Copy")
## Prefix of the minigames-won line; the count follows it.
@export var event_won_prefix: String = "EVENT BERHASIL : "
## Prefix of the minigames-lost line; the count follows it.
@export var event_lost_prefix: String = "EVENT GAGAL : "
## The Logs button's label.
@export var logs_button_text: String = "Logs"
## The Selanjutnya button's label.
@export var next_button_text: String = "Selanjutnya"

# ── Wiring ───────────────────────────────────────────────────────────
@export_group("Wiring")
## The per-student card. Assigned in ResultCheckup.tscn to
## DaySummaryStudentRow.tscn -- the same scene the nightly popup uses.
@export var student_card_scene: PackedScene
## The Logs sheet, WeekLogsPopup.tscn, instanced on each Logs tap.
@export var logs_popup_scene: PackedScene

const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/PaperConfetti.tscn"

@onready var title_banner: TextureRect = $Margin/Layout/TitleBanner
@onready var cards_scroll: ScrollContainer = $Margin/Layout/CardsScroll
@onready var cards_list: VBoxContainer = $Margin/Layout/CardsScroll/CardsList
@onready var money_label: Label = $Margin/Layout/Summary/Lines/CoinRow/MoneyLabel
@onready var event_won_label: Label = $Margin/Layout/Summary/Lines/EventWonLabel
@onready var event_lost_label: Label = $Margin/Layout/Summary/Lines/EventLostLabel
@onready var logs_button: Button = $Margin/Layout/Buttons/LogsButton
@onready var next_button: Button = $Margin/Layout/Buttons/NextButton

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

## This week's history, handed to each Logs sheet.
var _history: Array = []
## The Wirausaha payout the money line counts up to.
var _week_earnings: int = 0
## Latched on the first Logs open: the rows' stamp-and-shake entrance plays
## once, so reopening the sheet never re-fires the stamp cue.
var _logs_seen: bool = false
## The open Logs sheet, or null.
var _logs_popup: Control = null


func _ready() -> void:
	# Signal wiring stays ungated so the editor's test runner can exercise
	# it; everything below the guard is a real side effect.
	logs_button.pressed.connect(open_logs)
	next_button.pressed.connect(_on_next_pressed)
	cards_scroll.gui_input.connect(_on_scroll_gui_input)
	logs_button.text = logs_button_text
	next_button.text = next_button_text
	if Engine.is_editor_hint():
		return

	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	for b in [logs_button, next_button]:
		b.modulate.a = 0.0
		b.disabled = true


## Fill the screen for the week `student_manager` just simulated.
## `week_earnings` is the Wirausaha payout SchoolDay made just before opening
## this screen -- it has already left GameState.pending_earnings, so it is
## handed over rather than re-read.
func initialize_checkup(student_manager: StudentManager, week_earnings: int = 0) -> void:
	var recap: Dictionary = WeekRecap.compute(student_manager)
	_week_earnings = week_earnings
	money_label.text = format_earnings(week_earnings)
	event_won_label.text = event_won_prefix + str(recap["minigames_won"])
	event_lost_label.text = event_lost_prefix + str(recap["minigames_lost"])

	for child in cards_list.get_children():
		child.queue_free()
	_history = []
	if student_manager == null:
		return

	var cards: Array = []
	for student in student_manager.students:
		var card := student_card_scene.instantiate() as DaySummaryStudentRow
		cards_list.add_child(card)
		# Set up only once the card is in the tree: its @onready nodes are
		# null until then. Same order DaySummaryPopup.setup_summary uses.
		card.setup_week_row(student)
		_set_mouse_filter_pass(card)
		cards.append(card)

	_history = student_manager.minigame_history.duplicate()
	_play_entrance(cards)


## "+1.000" for a week that earned, "0" for one that did not.
static func format_earnings(value: int) -> String:
	return ("+" if value > 0 else "") + WeekRecap.format_money(value)


## Open the Logs sheet over the screen. One at a time; the rows' entrance
## plays on the first open only.
func open_logs() -> void:
	if is_instance_valid(_logs_popup):
		return
	var popup := logs_popup_scene.instantiate() as WeekLogsPopup
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.set_history(_history)
	popup.closed.connect(func(): _logs_popup = null)
	_logs_popup = popup
	popup.open(not _logs_seen)
	_logs_seen = true


func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control:
		if not node is Button:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)


func _play_entrance(cards: Array) -> void:
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return

	var t := Juice.tokens()
	var fader := create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished

	Juice.pop_in(title_banner)
	await get_tree().create_timer(t.dur_fast).timeout

	# Cards land one at a time, each card's five gauges moving on the beat
	# that card ARRIVES on -- the nightly popup's own cadence, one week long.
	Juice.stagger_in(cards)
	for i in cards.size():
		cards[i].play_week_gain(float(i) * t.stagger_step)

	# The coins count up and the two tallies pop once the cards are down.
	var cards_down := float(cards.size()) * t.stagger_step + t.dur_normal
	Juice.count_up_formatted(money_label, 0.0, float(_week_earnings),
		func(v: float) -> String: return format_earnings(int(round(v))), cards_down)
	Juice.pop_in(event_won_label, cards_down)
	Juice.pop_in(event_lost_label, cards_down + t.stagger_step)

	# One celebration for the whole week, landing just behind the last
	# card's own burst -- and only if the week went somewhere. A flat or
	# losing week gets the report without the party.
	var week_gained := false
	for card in cards:
		if card.gained_ground():
			week_gained = true
			break
	if week_gained:
		AudioDirector.play_sfx(&"reward")
		var celebration_scene: PackedScene = load(_CELEBRATION_SCENE)
		var celebration := celebration_scene.instantiate() as RewardParticles
		celebration.position = get_node("Celebration").position
		add_child(celebration)
		celebration.fire(float(cards.size()) * t.stagger_step)

	await get_tree().create_timer(cards_down + t.dur_slow).timeout

	for b in [logs_button, next_button]:
		var tw := create_tween()
		tw.tween_property(b, "modulate:a", 1.0, t.dur_fast)
		b.disabled = false


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_scroll = true
			drag_start_y = event.global_position.y
			initial_scroll_v = cards_scroll.scroll_vertical
		else:
			is_dragging_scroll = false
	elif event is InputEventMouseMotion and is_dragging_scroll:
		var delta_y = event.global_position.y - drag_start_y
		cards_scroll.scroll_vertical = int(initial_scroll_v - delta_y)


func _on_next_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, Juice.tokens().dur_normal)
	await fade_out.finished
	checkup_closed.emit()
```

  The script is rewritten before the scene is rebuilt because the scene needs `logs_popup_scene` to exist as an export. So **restart the editor now** (Appendix A) and re-read `<SESSION>`. That picks up the new script and clears every script buffer before the scene save below. Opening the old scene with the new script will print `@onready` null errors; they are expected and go away once the scene is rebuilt.

- [ ] **Step 4: Rebuild the scene in the editor.**
  1. Run `scene_open("res://Scenes/SchoolSimulation/ResultCheckup.tscn", session_id="<SESSION>")`.
  2. With `batch_execute`, `delete_node` `Background` and `Margin` (and with it the whole old subtree).
  3. On the root, set `background_texture` and `history_row_scene` to null (they leave the file), and set `logs_popup_scene` = `res://Scenes/SchoolSimulation/WeekLogsPopup.tscn`. Keep `student_card_scene`.
  4. Create the tree below. Set `layout_mode` 1 before the anchors on `Backdrop` and `Margin`.
  5. `move_node` `Backdrop` to index 0 and `Margin` to index 1, so `Celebration` stays last.
  6. Run `scene_save`.

  | Node | Type | Properties |
  |---|---|---|
  | `Backdrop` | TextureRect | layout_mode 1, anchor_right 1, anchor_bottom 1, offsets 0, mouse_filter 2, texture `res://Assets/Images/UI/blur_background.png`, expand_mode 1, stretch_mode 6 |
  | `Margin` | MarginContainer | layout_mode 1, anchor_right 1, anchor_bottom 1, offsets 0; `theme_override_constants/margin_left` 44, `margin_right` 44, `margin_top` 40, `margin_bottom` 60 |
  | `Margin/Layout` | VBoxContainer | `theme_override_constants/separation` 24 |
  | `Margin/Layout/TitleBanner` | TextureRect | custom_minimum_size (932, 286), size_flags_horizontal 4, texture `res://Assets/Images/DaySummary/title_weekly_results.png`, expand_mode 1 |
  | `Margin/Layout/CardsScroll` | ScrollContainer | size_flags_vertical 3, horizontal_scroll_mode 0 |
  | `Margin/Layout/CardsScroll/CardsList` | VBoxContainer | size_flags_horizontal 3, `theme_override_constants/separation` 56 |
  | `Margin/Layout/Summary` | MarginContainer | `theme_override_constants/margin_left` 36 |
  | `Margin/Layout/Summary/Lines` | VBoxContainer | `theme_override_constants/separation` 12 |
  | `Margin/Layout/Summary/Lines/CoinRow` | HBoxContainer | `theme_override_constants/separation` 40 |
  | `…/CoinRow/CoinIcon` | TextureRect | custom_minimum_size (140, 112), texture `res://Assets/Images/UI/uang.png`, expand_mode 1, stretch_mode 5 |
  | `…/CoinRow/MoneyLabel` | Label | `theme_type_variation` `DaySummaryStat`, text `+0`, vertical_alignment 1 |
  | `Margin/Layout/Summary/Lines/EventWonLabel` | Label | `theme_type_variation` `DaySummaryStat`, text `EVENT BERHASIL : 0` |
  | `Margin/Layout/Summary/Lines/EventLostLabel` | Label | `theme_type_variation` `DaySummaryStat`, text `EVENT GAGAL : 0` |
  | `Margin/Layout/Buttons` | HBoxContainer | alignment 1, `theme_override_constants/separation` 172 |
  | `Margin/Layout/Buttons/LogsButton` | Button | custom_minimum_size (368, 160), `theme_type_variation` `ResultButton`, text `Logs` |
  | `Margin/Layout/Buttons/NextButton` | Button | custom_minimum_size (368, 160), `theme_type_variation` `ResultButton`, text `Selanjutnya` |

  The sizes follow the mockup:
  - the 992-wide card fits exactly inside the 44/44 margins;
  - the ribbon is at the daily popup's 932x286;
  - two cards stay visible above the summary, and more scroll;
  - the buttons measure about 368x155 in the mockup, and 160 is a size step.

  After saving, run `git diff HEAD -- '*.gd'`. Only the three test files and `ResultCheckup.gd` should appear.

- [ ] **Step 5: Correct the spec.** In `docs/superpowers/specs/2026-09-14-weekly-results-design.md`, change the table row
  ```
  | `Logs` | the `WeekLogsPopup` instance, hidden until opened | overlay |
  ```
  to
  ```
  | — | `WeekLogsPopup` is instanced on each Logs tap (like the Lobby's Shorten panel), not authored in the scene: a scene instance under a plain `Control` loses its rect on load (authoring guide, Pattern C) | overlay |
  ```

- [ ] **Step 6: Run it and watch it pass.**

  Run: `test_run(suite="result_checkup", session_id="<SESSION>")`, then each of `school_day`, `viewport_editability`, `button_geometry`, `audio_coverage`, `paper_confetti`, `script_documentation` and `week_logs_popup`.

  Expected: every test PASSES.

- [ ] **Step 7: Commit**

```bash
git branch --show-current
git add Scripts/SchoolSimulation/ResultCheckup.gd Scenes/SchoolSimulation/ResultCheckup.tscn tests/test_result_checkup.gd tests/test_school_day.gd tests/test_viewport_editability.gd docs/superpowers/specs/2026-09-14-weekly-results-design.md
git commit -m "feat(weekly-results): rebuild ResultCheckup to the weekly results mockup" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: SchoolDay hands the payout to the screen

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:1286`
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `initialize_checkup(student_manager, week_earnings)` (Task 5).

- [ ] **Step 1: Write the failing test.** Append to `tests/test_result_checkup.gd` with `script_patch`, anchored after the last function:

```gdscript


## SchoolDay pays the Wirausaha earnings out -- and empties
## GameState.pending_earnings -- BEFORE it opens this screen, so the week's
## coins must be handed over, not re-read. Before 2026-09-14 the old
## banner's money pill read the emptied dict and always showed 0.
func test_school_day_hands_the_payout_to_the_checkup() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	var payout := src.find("var wirausaha_total := _pay_out_wirausaha()")
	var handoff := src.find("checkup_instance.initialize_checkup(student_manager, wirausaha_total)")
	assert_true(payout != -1 and handoff > payout,
		"the checkup gets the total the payout just made")
```

- [ ] **Step 2: Run it and watch it fail.**

  Run: `test_run(suite="result_checkup", session_id="<SESSION>")`

  Expected: `test_school_day_hands_the_payout_to_the_checkup` FAILS.

- [ ] **Step 3: Implement.** `script_patch` `res://Scripts/SchoolSimulation/SchoolDay.gd`. Change
  ```gdscript
  		checkup_instance.initialize_checkup(student_manager)
  ```
  to
  ```gdscript
  		# _pay_out_wirausaha() above already emptied pending_earnings, so the
  		# week's coins travel in by hand.
  		checkup_instance.initialize_checkup(student_manager, wirausaha_total)
  ```

- [ ] **Step 4: Run it and watch it pass.**

  Run: `test_run(suite="result_checkup", session_id="<SESSION>")`, then `test_run(suite="school_day", session_id="<SESSION>")`

  Expected: every test PASSES.

- [ ] **Step 5: Commit**

```bash
git branch --show-current
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_result_checkup.gd
git commit -m "fix(school-day): hand the week's Wirausaha payout to Weekly Results" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Retire the banner, pills, info popup and tabs

**Files:**
- Delete:
  - `Scripts/SchoolSimulation/WeekRecapBanner.gd`, `Scenes/SchoolSimulation/WeekRecapBanner.tscn`
  - `Scripts/SchoolSimulation/WeekRecapPill.gd`, `Scenes/SchoolSimulation/WeekRecapPill.tscn`
  - `Scripts/UI/WeekRecapPillInfoPopup.gd`, `Scenes/UI/WeekRecapPillInfoPopup.tscn`
  - `Scenes/SchoolSimulation/CoinShower.tscn`
  - `tests/test_week_recap_pill_info_popup.gd`
  - `Assets/Audio/SFX/pill_tap.ogg`, `pill_popup_open.ogg`, `pill_popup_close.ogg`, `pane_swipe.ogg`. These are dedicated copies of `tap`/`popup_open`/`popup_close`/`swipe`, per AudioDirector's own docs, so no unique sound is lost.
  - Each file's `.uid` / `.import` companion that `git ls-files` lists.
- Rewrite: `Scripts/SchoolSimulation/WeekRecap.gd`, `tests/test_week_recap.gd`
- Modify:
  - `Scripts/Design/ThemeFactory.gd`: drop the `_build_week_recap(theme, tokens)` call (line 25) and the whole `# ---- week recap` section with `_build_week_recap` (lines 1450-1510)
  - `tests/test_theme_factory.gd`: `"RecapPillValueLabel"` leaves `DISPLAY_ROSTER`
  - `Scripts/Audio/AudioDirector.gd`: the four cues' docs, exports and match arms (lines 67-70, 98-106, 246-249)
  - `tests/test_audio_director.gd:543-546`: the test goes
  - `tests/test_audio_coverage.gd:128`: the four ids go
  - `tests/test_result_checkup.gd`: one new assertion test
- Rebaked: `Assets/Theme/kejartes_theme.tres`

- [ ] **Step 1: Write the failing test.** Append to `tests/test_result_checkup.gd` with `script_patch`:

```gdscript


## The old banner, its pills, their info popup and the SISWA/RIWAYAT tabs
## are retired with the 2026-09-14 revamp, and WeekRecap stops reading the
## dict SchoolDay empties.
func test_the_old_banner_and_tabs_are_gone() -> void:
	for path in ["res://Scenes/SchoolSimulation/WeekRecapBanner.tscn",
			"res://Scenes/SchoolSimulation/WeekRecapPill.tscn",
			"res://Scenes/UI/WeekRecapPillInfoPopup.tscn",
			"res://Scenes/SchoolSimulation/CoinShower.tscn"]:
		assert_false(FileAccess.file_exists(path), path + " is retired")
	var theme: Theme = load(_THEME_PATH)
	for variation in ["RecapBannerPanel", "RecapPillPanel", "RecapPillValueLabel",
			"WeekTabButton"]:
		assert_false(theme.get_type_list().has(variation), variation + " left the bake")
	assert_false(FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecap.gd").contains("pending_earnings"),
		"WeekRecap no longer reads the dict the payout empties")
```

  Run `test_run(suite="result_checkup", session_id="<SESSION>")`. Expected: this test FAILS.

- [ ] **Step 2: Rewrite WeekRecap.** Write `Scripts/SchoolSimulation/WeekRecap.gd` in full:

```gdscript
extends RefCounted
class_name WeekRecap

## The week's minigame tallies, computed from one StudentManager, and the
## Indonesian money format Weekly Results shows (2026-09-14 weekly-results
## spec; first written for the 2026-09-03 banner, since retired).
##
## A plain RefCounted rather than a node or an autoload, so the numbers can
## be tested without instantiating a scene. Nothing here is persisted.
##
## The week's coins are NOT computed here. SchoolDay pays the Wirausaha
## earnings out -- emptying GameState.pending_earnings -- before Weekly
## Results opens, so it hands the paid total to
## ResultCheckup.initialize_checkup() instead.

## The history category that marks an entry as a random event rather than a
## played minigame. Everything else is a minigame.
const EVENT_CATEGORY := "Event"


## The week's minigame tallies for `manager`. Random events are counted
## apart: they are recorded as won and cannot fail. Safe on a null manager,
## which reports an empty week -- the editor's test runner builds
## ResultCheckup with no simulation behind it.
static func compute(manager: StudentManager) -> Dictionary:
	var result := {
		"minigames_won": 0,
		"minigames_lost": 0,
		"minigames_total": 0,
		"events_count": 0,
	}
	if manager == null:
		return result

	for entry in manager.minigame_history:
		if entry.get("category", "") == EVENT_CATEGORY:
			result["events_count"] += 1
		else:
			result["minigames_total"] += 1
			if entry.get("won", false):
				result["minigames_won"] += 1
			else:
				result["minigames_lost"] += 1

	return result


## "4.200" -- Indonesian thousands grouping, which uses a dot where
## English uses a comma.
static func format_money(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	return ("-" if value < 0 else "") + grouped
```

  Then write `tests/test_week_recap.gd` in full:

```gdscript
@tool
extends McpTestSuite

## WeekRecap's week tallies (2026-09-14 weekly-results spec; first written
## for the 2026-09-03 banner).
##
## WeekRecap is a plain RefCounted, so every case here runs without
## instantiating a scene. Suite is @tool and no test is a coroutine, per the
## runner's constraints.

const _RECAP_SCRIPT := "res://Scripts/SchoolSimulation/WeekRecap.gd"


func suite_name() -> String:
	return "week_recap"


## A StudentManager standing in for a simulated week, built by hand: these
## tests are about the counting, not about what the simulation produces.
func _manager(history: Array) -> StudentManager:
	var m := StudentManager.new()
	m.minigame_history.assign(history)
	return m


func _entry(day: String, category: String, won: bool) -> Dictionary:
	return {"day": day, "category": category, "game_name": "X", "won": won}


func test_minigame_tally_excludes_events() -> void:
	var m := _manager([
		_entry("Senin", "Olahraga", true),
		_entry("Selasa", "Akademis", false),
		_entry("Rabu", "Event", true),
		_entry("Kamis", "SeniBudaya", true),
	])
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_won"], 2, "two non-event wins")
	assert_eq(r["minigames_total"], 3, "the Event entry is not a minigame")
	assert_eq(r["events_count"], 1, "one Event entry")


func test_minigames_lost_counts_played_losses_only() -> void:
	var m := _manager([
		_entry("Senin", "Olahraga", true),
		_entry("Selasa", "Akademis", false),
		_entry("Rabu", "Event", true),
		_entry("Kamis", "SeniBudaya", false),
	])
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_won"], 1, "one played win")
	assert_eq(r["minigames_lost"], 2, "two played losses")
	assert_eq(r["minigames_won"] + r["minigames_lost"], r["minigames_total"],
		"won + lost = played")


## Random events are recorded won and cannot fail -- even an entry that
## says otherwise is never counted as a lost minigame.
func test_an_event_is_never_a_loss() -> void:
	var m := _manager([_entry("Rabu", "Event", false)])
	assert_eq(WeekRecap.compute(m)["minigames_lost"], 0,
		"an Event entry is not a minigame")


func test_empty_history_reports_zeroes() -> void:
	var r: Dictionary = WeekRecap.compute(_manager([]))
	assert_eq(r["minigames_total"], 0, "no minigames")
	assert_eq(r["minigames_lost"], 0, "no losses")
	assert_eq(r["events_count"], 0, "no events")


func test_all_event_history_reports_no_minigames() -> void:
	var m := _manager([
		_entry("Senin", "Event", true),
		_entry("Selasa", "Event", true),
	])
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_total"], 0, "every entry was an Event")
	assert_eq(r["events_count"], 2, "both counted as events")


func test_null_manager_reports_zeroes_rather_than_erroring() -> void:
	var r: Dictionary = WeekRecap.compute(null)
	assert_eq(r["minigames_won"], 0, "a null manager is survivable")
	assert_eq(r["minigames_lost"], 0, "and reports an empty week")


func test_format_money_groups_thousands_with_a_dot() -> void:
	assert_eq(WeekRecap.format_money(4200), "4.200",
		"Indonesian thousands separator")
	assert_eq(WeekRecap.format_money(0), "0", "zero needs no separator")
	assert_eq(WeekRecap.format_money(1234567), "1.234.567",
		"grouping repeats every three digits")


## The coins arrive through ResultCheckup.initialize_checkup(); WeekRecap
## must not go back to reading the dict SchoolDay empties first.
func test_week_recap_does_not_read_pending_earnings() -> void:
	assert_false(FileAccess.get_file_as_string(_RECAP_SCRIPT).contains("pending_earnings"),
		"the payout empties pending_earnings before Weekly Results opens")
```

- [ ] **Step 3: Remove the rest.**
  1. Delete the retired files: `git rm` each path in **Files → Delete**, plus the `.uid` and `.import` files `git ls-files` shows for them.
  2. `script_patch` `ThemeFactory.gd`. Delete the line `	_build_week_recap(theme, tokens)`, then delete everything from `# ------------------------------------------------------------ week recap` up to (not including) `# ---------------------------------------------------- minigame result card`.
  3. `script_patch` `test_theme_factory.gd`. Change `	"RecapPillValueLabel", "ScoreHudValueLabel",` to `	"ScoreHudValueLabel",`.
  4. `script_patch` `AudioDirector.gd`. Delete the `pill_tap` doc and export (4 lines), the three doc-and-export pairs for `pill_popup_open`, `pill_popup_close` and `pane_swipe` (9 lines), and the four `match` arms (`&"pill_tap": return sfx_pill_tap` … `&"pane_swipe": return sfx_pane_swipe`).
  5. `script_patch` `test_audio_director.gd`. Delete `test_pill_and_pane_sfx_are_registered` (4 lines and the blank line before it).
  6. `script_patch` `test_audio_coverage.gd`. Delete the line `		"pill_tap", "pill_popup_open", "pill_popup_close", "pane_swipe",`.
  7. Run `filesystem_manage(op="scan", session_id="<SESSION>")`, then a no-op `script_patch` on each `.gd` written with the Write tool in Step 2, to force the reload.
  8. Grep the whole worktree for `WeekRecapBanner|WeekRecapPill|CoinShower|pill_tap|pill_popup|pane_swipe|net_skill_delta|format_skill_delta|WeekTabButton|Recap(Banner|Pill)`. The only hits allowed are under `docs/`.

- [ ] **Step 4: Rebake, then restart.** Run `test_run(suite="theme_rebake", session_id="<SESSION>")`. Then check the bake:
  ```bash
  git diff --stat -- Assets/Theme/kejartes_theme.tres
  ```
  The diff must remove the `RecapBannerPanel/`, `RecapPillPanel/`, `RecapPillValueLabel/` and `WeekTabButton/` blocks and keep `ResultButton/`. Then restart the editor with Appendix A and re-read `<SESSION>`.

- [ ] **Step 5: Run the affected suites.** Run `test_run(suite=…, session_id="<SESSION>")` for each of `result_checkup`, `week_recap`, `theme_factory`, `audio_director`, `audio_coverage`, `project_hygiene`, `school_day` and `script_documentation`.

  Expected: every test PASSES.

- [ ] **Step 6: Commit**

```bash
git branch --show-current
git add -A Scripts Scenes tests Assets
git status --short
git commit -m "chore(weekly-results): retire the recap banner, pills, info popup and tabs" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

  Before committing, check that `git status --short` lists only this task's files. It must not include `addons/godot_ai/utils/update_activation_runner.gd`, the plugin's untracked runner file. Unstage it with `git restore --staged <path>` if it slipped in.

---

### Task 8: Look at it against the mockup

**Files:**
- Create, then delete before the commit: `_preview/WeeklyResultsPreview.tscn` and `_preview/WeeklyResultsPreview.gd`

- [ ] **Step 1: Write a throwaway preview.** It is new, so the editor has never loaded it and a hand-written `.tscn` is safe.

  `_preview/WeeklyResultsPreview.gd`:
  ```gdscript
  extends Node

  ## TRANSIENT (2026-09-14 weekly-results Task 8): shows Weekly Results with a
  ## sample week so it can be compared with the mockup. Delete after use.

  func _ready() -> void:
  	var manager := StudentManager.new()
  	add_child(manager)
  	manager.students[0].akademis += 12.0
  	manager.minigame_history.assign([
  		{"day": "Senin", "category": "Akademis", "game_name": "Password", "won": true},
  		{"day": "Selasa", "category": "Olahraga", "game_name": "Badminton", "won": false},
  		{"day": "Rabu", "category": "Event", "game_name": "Hujan Deras", "won": true},
  		{"day": "Kamis", "category": "SeniBudaya", "game_name": "Batik", "won": true},
  	])
  	var screen = load("res://Scenes/SchoolSimulation/ResultCheckup.tscn").instantiate()
  	add_child(screen)
  	screen.initialize_checkup(manager, 1000)
  ```
  `_preview/WeeklyResultsPreview.tscn`:
  ```
  [gd_scene format=3]

  [ext_resource type="Script" path="res://_preview/WeeklyResultsPreview.gd" id="1"]

  [node name="WeeklyResultsPreview" type="Node"]
  script = ExtResource("1")
  ```

- [ ] **Step 2: Run it and capture it.**
  1. Run `filesystem_manage(op="scan", session_id="<SESSION>")`.
  2. `project_run` the preview scene. Check the tool's schema for the scene parameter; if it cannot run a given scene, temporarily open the preview scene and use "run current scene".
  3. Wait about 4 s for the entrance to finish, then capture the game view with `editor_screenshot` at full size.
  4. Open Logs by sending a `motion` then a `button` event to `LogsButton`'s `global_rect` centre, rescaled to window pixels per CLAUDE.md "Clicking". Capture again.
  5. Stop the game.

- [ ] **Step 3: Compare with the mockup** (Read `docs/superpowers/mockups/mockup_weeklyresults.png`). Check:
  - the ribbon is centred at the top;
  - the 992-wide cards sit edge to edge inside the margins;
  - about two cards are visible;
  - the coin line and the two event lines sit at the lower left in white-with-purple-outline text;
  - the two cream buttons fill the bottom row;
  - the Logs sheet lists 4 rows over a dim.

  If a gap or size is visibly off, adjust the numbers in the Task 5 table through the editor (`scene_open`, `set_property`, `scene_save`) and re-run `result_checkup`. A restart first is not required: no script has changed since Task 7's restart. If something is off and deliberately left, write it down for the final report.

- [ ] **Step 4: Delete the preview.** Remove the `_preview/` folder and any `.uid` files the scan created, then run `filesystem_manage(op="scan", session_id="<SESSION>")`. Afterwards `git status --short` must show nothing under `_preview/`.

- [ ] **Step 5: Commit** any layout adjustments:

```bash
git branch --show-current
git add Scenes/SchoolSimulation/ResultCheckup.tscn
git commit -m "fix(weekly-results): match the mockup's spacing" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

  Skip this commit if nothing changed.

---

### Task 9: Docs, then the full suite

**Files:**
- Modify: `CLAUDE.md`, `docs/superpowers/CHANGELOG.md`, `docs/superpowers/design/authoring-guide.md:232`

- [ ] **Step 1: Update CLAUDE.md.**
  - In the generated-placeholder list, after the 2026-09-14 EventDialogue set, add: `and the 2026-09-14 Weekly Results ribbon, Assets/Images/DaySummary/title_weekly_results.png (cut out of the mockup and given title_daily_results.png's alpha -- drop-replaceable at the same path)`.
  - In "Loose ends from the event-cards pass", delete the sentence that starts `` `tests/test_result_checkup.gd`'s `` and ends `so it always passes.` Task 5 fixed that test.
  - Leave the suite count for Step 4.

- [ ] **Step 2: Update the authoring guide.** Remove `` `ResultCheckup.gd`, `` from the "Known gaps" list at line 232. Its runtime backdrop swap is gone.

- [ ] **Step 3: Add a CHANGELOG entry** at the top of `docs/superpowers/CHANGELOG.md`, newest first:

```markdown
## 2026-09-14 — Weekly Results: the week-end screen rebuilt to the mockup

Plan `docs/superpowers/plans/2026-09-14-weekly-results.md`, spec
`docs/superpowers/specs/2026-09-14-weekly-results-design.md`, mockup
`docs/superpowers/mockups/mockup_weeklyresults.png`.

ResultCheckup now matches the Weekly Results mockup:
- A red WEEKLY RESULTS ribbon, and one DaySummary card per student in week
  mode.
- The week's coins, then EVENT BERHASIL / EVENT GAGAL (minigames won and
  lost; random events cannot fail, so they show only in Logs).
- Two cream `ResultButton`s: **Logs** opens the new `WeekLogsPopup` with the
  week's history rows, and **Selanjutnya** closes the screen.

`ResultButton` is a new textured variation over the card's own
`card_bg.png`. The ribbon is a placeholder cut from the mockup.

**Fixed while here:** SchoolDay paid the Wirausaha earnings out, emptying
`pending_earnings`, before it opened the screen, so the old banner's money
pill always read 0. The paid total is now passed to `initialize_checkup()`.
`test_result_checkup`'s set-up-in-the-tree test was always passing; it now
checks both calls exist.

**Retired:** `WeekRecapBanner`, `WeekRecapPill`, `WeekRecapPillInfoPopup`,
`CoinShower.tscn`, the SISWA/RIWAYAT tabs, the `RecapBannerPanel` /
`RecapPillPanel` / `RecapPillValueLabel` / `WeekTabButton` variations, the
`pill_tap` / `pill_popup_open` / `pill_popup_close` / `pane_swipe` cues and
their dedicated `.ogg` copies, and `WeekRecap`'s `net_skill_delta`,
`format_skill_delta` and money read.
```

  Add a bullet for any mockup deviation Task 8 recorded.

- [ ] **Step 4: Run the full suite.**
  1. Open the main scene: `scene_open("res://Scenes/MainMenu/main_menu.tscn", session_id="<SESSION>")`.
  2. Run `test_run(session_id="<SESSION>")`. Expected: every suite PASSES. Note `<passed>/<total>` and the suite count.
  3. Run `git status --short`. If `Assets/Theme/kejartes_theme.tres` changed, compare it with HEAD by content:
     ```bash
     diff <(git show HEAD:Assets/Theme/kejartes_theme.tres | sed -E 's/_[A-Za-z0-9]{5}"/_ID"/g; s/_[A-Za-z0-9]{5}\)/_ID)/g') <(sed -E 's/_[A-Za-z0-9]{5}"/_ID"/g; s/_[A-Za-z0-9]{5}\)/_ID)/g' Assets/Theme/kejartes_theme.tres) | wc -l
     ```
     If that prints `0`, restore it with `git checkout -- Assets/Theme/kejartes_theme.tres`. Restore `default_bus_layout.tres` the same way if it changed.
  4. Update CLAUDE.md's Testing count line to `<suites> suites, <total> tests (2026-09-14)`.
  5. Restart the editor with Appendix A: the full run hangs it.

- [ ] **Step 5: Commit**

```bash
git branch --show-current
git add CLAUDE.md docs/superpowers/CHANGELOG.md docs/superpowers/design/authoring-guide.md
git commit -m "docs(weekly-results): changelog, project guide and known gaps" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Appendix A: restart this worktree's editor

This is PID-guarded to the weekly-results editor, and it stops if that editor has an unsaved scene. The main checkout's editor and other sessions' editors are never touched.

```powershell
$wt = 'C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\weekly-results'
$exe = 'C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
$mine = Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v%'" | Where-Object { $_.CommandLine -like '*worktrees/weekly-results*' }
foreach ($m in $mine) {
  $p = Get-Process -Id $m.ProcessId -ErrorAction SilentlyContinue
  if ($p -and $p.MainWindowTitle.Contains('(*)')) { "STOP: unsaved scene: $($p.MainWindowTitle)"; return }
  taskkill /PID $m.ProcessId /F | Out-Null
  Wait-Process -Id $m.ProcessId -Timeout 20 -ErrorAction SilentlyContinue
  "closed $($m.ProcessId)"
}
$path = $wt -replace '\\','/'
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$path`" -e"; CurrentDirectory = $wt }
"relaunched ReturnValue=$($r.ReturnValue) PID=$($r.ProcessId)"
```

Then call `session_manage(op="list")` until a row with `project_path` ending in `worktrees/weekly-results/` reports `readiness: ready`, and use its `session_id` from then on.
