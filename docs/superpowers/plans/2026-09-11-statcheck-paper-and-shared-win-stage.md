# StatCheck Paper & Shared Win Stage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:**
- Draw each StatCheck student page on StudentCard's own paper, showing the photo, the name alone on the printed plate, and the game's `stat_*` icons.
- Make RunResult open on exactly the win screen EndCutscene shows, through one shared `WinStage` scene.

**Architecture:**
- **Part 1.** `StatCheckCard.tscn` is rebuilt around a native-size `card_bg.png` `TextureRect`, scaled to 0.757, so every child reuses StudentCard's measured coordinates. A new `PlateNameLabel` theme variation styles the name.
- **Part 2.** EndCutscene's painting, letterbox bars and posed roster move into a new `WinStage.tscn`/`WinStage.gd`. EndCutscene and RunResult both instance that scene and dress it with the identical call.

**Tech Stack:**
- Godot 4.6.2, GDScript.
- Test suites run in-editor through the Godot AI MCP `test_run` tool.
- Scenes are edited only through the MCP editor tools.

**Spec:** `docs/superpowers/specs/2026-09-11-statcheck-paper-and-shared-win-stage-design.md`

## Global Constraints

- **Engine:** Godot 4.6, mobile renderer, portrait 1080×1920 design space.
- **No new `theme_override_*`.** Only layout constants (`separation`, `margin_*`) are allowed; styling goes through a `ThemeFactory` variation.
- **No visual is built at runtime.** New nodes are authored in `.tscn` files. `dress()` only sets texture, size, position and visibility on authored nodes.
- **Documentation:** every script needs a `##` file header within its first 12 lines, and every `@export` needs a `##` line (`tests/test_script_documentation.gd`).
- **Test suites** are `@tool`, and **no test may be a coroutine**. Asserts available: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_gt`, `assert_has_key`, `assert_contains`; `assert_not_null` only in suites extending `McpTestSuiteCompat`. There is no `assert_lt`.
- **Language:** UI text is Indonesian; code is English.
- **`Balance.gd`** is collaborator-owned and is never edited.
- **Never hand-edit a `.tscn`.** Use `scene_open`, then `batch_execute` (`create_node`, `set_property`, `delete_node`, `move_node`, `attach_script`), then `scene_save`. Scene paths are root-name-prefixed, e.g. `/StatCheckCard/Paper`.
- **Order of work:** patch scripts first, restart the editor, then edit scenes, because `scene_save` writes open script tabs back to disk. After every `scene_save`, run `git diff HEAD --stat -- '*.gd'` and restore any `.gd` you did not mean to change.
- **Before any editor restart,** probe for unsaved tabs (Task 2, Step 5). A force-kill discards the user's unsaved scene edits.
- **Line endings:** all files touched here are LF, so multi-line `script_patch` anchors are safe.
- **Commits:** Conventional Commits with a scope, ending with the trailer `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Never push without being asked.
- **Measured constants.** Copy these verbatim:

  | Constant | Value |
  |---|---|
  | Paper sheet in `card_bg.png` | `Rect2(52, 238, 994, 1321)` |
  | Paper scale | `0.757` |
  | Paper offsets | `(-35.59, -180.17)`–`(1044.41, 1739.83)` |
  | Photo / frame rect | `(136, 294)`–`(419, 670)` |
  | Name rect | `(468, 300)`–`(925, 667)` |
  | Rows rect | `(132, 740)`–`(941, 1480)`, separation 64 |
  | Row proportions | icon 128, gap 24, bar 68 |
  | Painting | `ART_SIZE = Vector2(1536, 2048)` |
  | Letterbox at 1080×1920 | scale `0.703125`, position `(0, 240)` |

- **The shared dress line**, verbatim in both hosts:
  `win_stage.dress(GameState.run_failed, WinStage.names_of(GameState.approved_students))`

---

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/Design/ThemeFactory.gd` *(modify)* | Adds the `PlateNameLabel` variation next to `BioLabel`/`BioValue`. |
| `Assets/Theme/kejartes_theme.tres` *(rebaked)* | The baked theme the game loads; must gain `PlateNameLabel`. |
| `tests/test_theme_factory.gd` *(modify)* | `PlateNameLabel` on `DISPLAY_ROSTER`, plus a style test. |
| `Scenes/EndGame/StatCheckRow.tscn` *(modify)* | StudentCard proportions: 128 icon, 24 gap, 68 bar; `stat_akademis.png` as the authored icon. |
| `Scenes/EndGame/StatCheckCard.tscn` *(rebuild)* | `Paper` = `card_bg.png` `TextureRect` at 0.757, holding PaperShadow, Photo, PortraitFrame, Name and Rows. |
| `Scripts/EndGame/StatCheckCard.gd` *(rewrite)* | `bind()` fills the name, the photo and three rows; no bio lines. |
| `Scripts/EndGame/StatCheck.gd` *(comment)* | The `_input()` rationale no longer claims the card's paper is a Panel. |
| `tests/test_stat_check.gd` *(modify)* | Paper, sheet fit, frame and plate placement, name-only, icons, name fit, row proportions. |
| `Scripts/EndGame/WinStage.gd` *(create)* | Bars, letterbox/cover fit, lineup dressing. API: `dress()`, `names_of()`, `letterbox()`. |
| `Scenes/EndGame/WinStage.tscn` *(create)* | BarFill, then Stage (Backdrop, Shadows ×4, Students ×4); owns all the art defaults. |
| `tests/test_win_stage.gd` *(create)* | Scene shape, maths, and live `dress()` for both verdicts. |
| `Scripts/EndGame/EndCutscene.gd` *(rewrite)* | Drops the stage code and exports, and dresses `$WinStage`. |
| `Scenes/EndGame/EndCutscene.tscn` *(modify)* | BarFill and Stage replaced by a `WinStage` instance at index 0. |
| `Scripts/EndGame/RunResult.gd` *(modify)* | Drops the backdrop exports, and dresses `$WinStage` with the shared line. |
| `Scenes/EndGame/RunResult.tscn` *(modify)* | Backdrop replaced by a `WinStage` instance at index 0; TitleLabel switches to `ResultHeroLabel`. |
| `Scripts/EndGame/WinLineup.gd`, `tests/test_win_lineup.gd` *(comments)* | References to EndCutscene now point at WinStage. |
| `tests/test_end_cutscene.gd`, `tests/test_run_result.gd` *(modify)* | Retargeted to WinStage; stage internals move to `test_win_stage.gd`. |
| `docs/superpowers/CHANGELOG.md`, `CLAUDE.md` *(docs)* | A changelog entry, the dead-scene line and the suite counts. |

---

### Task 1: `PlateNameLabel` theme variation, rebaked

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`, directly after the `BioValue` block (~line 1001).
- Modify: `tests/test_theme_factory.gd`, `DISPLAY_ROSTER` (~line 346) and a new test.
- Rebake: `Assets/Theme/kejartes_theme.tres`.

**Interfaces:**
- Consumes: `DesignTokens.font_display_size` (96), `text_on_brand` (#FFF6E8), `font_display` (Boohong).
- Produces: the theme type `"PlateNameLabel"`, a variation of `Label`, used by `Paper/Name` in Task 2.

- [ ] **Step 1: Write the failing tests.** In `tests/test_theme_factory.gd`, replace the last line of `DISPLAY_ROSTER`:

```gdscript
	"SpecialtyBadgeM", "PersonaBadgeM", "QuirkBadgeM",
]
```

with:

```gdscript
	"SpecialtyBadgeM", "PersonaBadgeM", "QuirkBadgeM",
	# 2026-09-11: the student's name alone on StatCheck's painted plate.
	"PlateNameLabel",
]
```

and append at the end of the file:

```gdscript


## StatCheck's page shows the student's name alone on StudentCard's
## painted brown plate (2026-09-11). Cream, because the plate is dark; the
## display step, because it is the only text on the page.
func test_plate_name_label_is_cream_display_text() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_true(theme.get_type_list().has("PlateNameLabel"),
		"ThemeFactory must build a PlateNameLabel variation")
	assert_eq(theme.get_type_variation_base("PlateNameLabel"), &"Label",
		"PlateNameLabel varies Label")
	assert_eq(theme.get_font_size("font_size", "PlateNameLabel"),
		tokens.font_display_size, "the display step")
	assert_eq(theme.get_color("font_color", "PlateNameLabel"),
		tokens.text_on_brand, "cream, to read on the brown plate")
```

- [ ] **Step 2: Run the tests and watch them fail.** Call `filesystem_manage(op="scan")`, then `test_run(suite="theme_factory")`.
  Expected: FAIL in `test_display_font_roster_is_exact` ("PlateNameLabel is on the display roster but did not get the display font") and in `test_plate_name_label_is_cream_display_text`.

- [ ] **Step 3: Implement.** Call `script_patch` on `res://Scripts/Design/ThemeFactory.gd` with `old_text`:

```gdscript
	theme.set_color("font_color", "BioValue", tokens.text_on_brand)
```

and `new_text`:

```gdscript
	theme.set_color("font_color", "BioValue", tokens.text_on_brand)

	# -- A name alone on the painted plate: StatCheck's page (2026-09-11).
	# StudentCard stacks three bio rows on that plate in BioLabel/BioValue;
	# StatCheck shows only the name, so it takes the display face at the
	# display step and fills the plate. Cream for the same reason as the bio
	# text. No outline: the plate is opaque and flat, so an outline would
	# only thicken the letterforms (the call TraitPopupNameLabel makes too).
	# At 96px the widest roster name, MARCEL, is ~413px against the 457px
	# Name slot in StatCheckCard.tscn -- tests/test_stat_check.gd measures it. --
	theme.add_type("PlateNameLabel")
	theme.set_type_variation("PlateNameLabel", "Label")
	theme.set_font_size("font_size", "PlateNameLabel", tokens.font_display_size)
	theme.set_color("font_color", "PlateNameLabel", tokens.text_on_brand)
	if tokens.font_display != null:
		theme.set_font("font", "PlateNameLabel", tokens.font_display)
```

- [ ] **Step 4: Rebake the theme.** Run `test_run(suite="theme_rebake")`.
  Expected: PASS, and the log line `theme_rebake: wrote res://Assets/Theme/kejartes_theme.tres`. Then run:

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff --stat -- Assets/Theme/kejartes_theme.tres && grep -c "PlateNameLabel" Assets/Theme/kejartes_theme.tres
```

  Expected: the `.tres` is modified and the count is ≥ 1.

- [ ] **Step 5: Run the tests and confirm they pass.** Run `test_run(suite="theme_factory")`.
  Expected: PASS, including `test_baked_theme_matches_what_the_factory_builds`.

- [ ] **Step 6: Commit.**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): add PlateNameLabel for a name alone on the painted plate" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: StatCheck's page on StudentCard's paper

**Files:**
- Modify: `tests/test_stat_check.gd`. Replace three card tests and add five new ones.
- Rewrite: `Scripts/EndGame/StatCheckCard.gd`.
- Modify: `Scripts/EndGame/StatCheck.gd`, a comment at ~lines 143-148.
- Modify (editor): `Scenes/EndGame/StatCheckRow.tscn`.
- Rebuild (editor): `Scenes/EndGame/StatCheckCard.tscn`.

**Interfaces:**
- Consumes: `PlateNameLabel` (Task 1); `StudentCardView.BIO_PANEL_RECT` (`Rect2(452, 300, 489, 367)`); `StudentData.student_name`, `.avatar_texture`, the skill values and their targets.
- Produces: `StatCheckCard.bind(student: StudentData) -> void` and `StatCheckCard.rows() -> Array`. Their signatures are unchanged, so `StatCheck.gd` needs no code change.

- [ ] **Step 1: Write the failing tests.** In `tests/test_stat_check.gd`, replace `test_card_scene_has_the_mockup_parts`, `test_card_bind_fills_name_profil_portrait_and_arms_three_rows` and `test_card_rows_carry_the_right_categories_and_icons` with this block. Leave `_CARD_SCENE`, `_SCENE`, `_SCRIPT` and `_METER_SCRIPT` in place above it.

```gdscript
const _CARD_SCRIPT := "res://Scripts/EndGame/StatCheckCard.gd"
const _PAPER_ART := "res://Assets/Images/StudentCard/card_bg.png"
const _SHADOW_SCENE := "res://Scenes/UI/PaperShadow.tscn"
const _ICON_DIR := "res://Assets/Images/StudentCard/"

## card_bg.png is 1080x1920 but paper only across this rect (alpha > 200,
## measured 2026-09-11); everything outside is transparent. The card must be
## filled by the SHEET, not by the texture's empty margin.
const _SHEET := Rect2(52, 238, 994, 1321)
## The frame printed on card_bg.png -- StudentCard's own PortraitFrame rect.
const _PHOTO_RECT := Rect2(136, 294, 283, 376)
## The six students the game ships. Kept here rather than read from
## student_card.gd, whose roster is a script variable, not a constant.
const _ROSTER := ["Marcel", "Doni", "Andi", "Citra", "Shinta", "Thea"]
## The art StudentCard, StudentList and AturJadwal already use for the
## three skills -- not the placeholder SVGs the page shipped with.
const _STAT_ICONS := {
	"Akademis": "stat_akademis.png",
	"SeniBudaya": "stat_senibudaya.png",
	"Olahraga": "stat_olahraga.png",
}


func test_card_is_studentcards_paper() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var paper = card.get_node_or_null("Paper")
	assert_true(paper is TextureRect, "the page is a TextureRect, not a themed panel")
	assert_eq(String(paper.texture.resource_path), _PAPER_ART,
		"the same paper StudentCard draws")
	var shadow = card.get_node_or_null("Paper/PaperShadow")
	assert_true(shadow != null, "the paper casts StudentCard's shadow")
	assert_eq(shadow.scene_file_path, _SHADOW_SCENE,
		"instanced from PaperShadow.tscn, not rebuilt")
	assert_true(card.get_node_or_null("Paper/Header") == null,
		"the old bio-panel header is gone")


## Mapped through the paper's own offsets and scale, the measured sheet must
## sit inside the 760x1000 card and fill its height -- lay out against the
## alpha, not the texture rect (CLAUDE.md's paper.png lesson).
func test_the_paper_sheet_fills_the_card() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var paper: TextureRect = card.get_node("Paper")
	assert_true(is_equal_approx(paper.scale.x, paper.scale.y),
		"the paper is scaled uniformly, so the art is not distorted")
	var origin := Vector2(paper.offset_left, paper.offset_top)
	var top_left := origin + _SHEET.position * paper.scale
	var bottom_right := origin + _SHEET.end * paper.scale
	var card_size: Vector2 = card.custom_minimum_size
	assert_true(top_left.x >= -1.0 and top_left.y >= -1.0,
		"the sheet's top-left %s stays inside the card" % top_left)
	assert_true(bottom_right.x <= card_size.x + 1.0 and bottom_right.y <= card_size.y + 1.0,
		"the sheet's bottom-right %s stays inside %s" % [bottom_right, card_size])
	assert_true(bottom_right.y - top_left.y >= card_size.y - 2.0,
		"and the sheet fills the card's height")


func test_the_photo_and_name_sit_on_the_printed_frame_and_plate() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	for n in ["Photo", "PortraitFrame"]:
		var r: TextureRect = card.get_node_or_null("Paper/" + n)
		assert_true(r != null, n + " exists")
		var rect := Rect2(r.offset_left, r.offset_top,
			r.offset_right - r.offset_left, r.offset_bottom - r.offset_top)
		assert_eq(rect, _PHOTO_RECT, n + " covers the printed photo frame")
	assert_eq(String(card.get_node("Paper/PortraitFrame").texture.resource_path),
		"res://Assets/Images/StudentCard/portrait_frame.png", "StudentCard's frame art")
	var name_label: Label = card.get_node_or_null("Paper/Name")
	assert_true(name_label != null, "a Name label")
	var plate: Rect2 = StudentCardView.BIO_PANEL_RECT
	var rect := Rect2(name_label.offset_left, name_label.offset_top,
		name_label.offset_right - name_label.offset_left,
		name_label.offset_bottom - name_label.offset_top)
	assert_true(plate.encloses(rect), "Name %s sits on the plate %s" % [rect, plate])
	assert_eq(String(name_label.theme_type_variation), "PlateNameLabel",
		"cream display text for the brown plate")
	for n in ["Akademis", "Seni", "Olahraga"]:
		assert_true(card.get_node_or_null("Paper/Rows/" + n) is StatCheckRow,
			"%s row is a StatCheckRow" % n)


## "Put only the student name": nothing from the bio file but the name.
func test_the_name_is_the_only_text_on_the_page() -> void:
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var labels := card.find_children("*", "Label", true, false)
	assert_eq(labels.size(), 1, "one Label on the page: %s" % str(labels))
	var src := FileAccess.get_file_as_string(_CARD_SCRIPT)
	assert_false(src.contains("profil"),
		"StatCheckCard never shows the Agama / Jenis Kelamin lines")


func test_card_bind_fills_name_and_photo_and_arms_three_rows() -> void:
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var photo: Texture2D = load("res://Assets/Images/MuridPotrait/Murid3.jpg")
	var s := StudentData.new()
	s.student_name = "Citra"
	s.avatar_texture = photo
	s.akademis = 70.0
	s.target_akademis1 = 60.0
	s.seni_budaya = 30.0
	s.target_akademis2 = 60.0
	s.olahraga = 60.0
	s.target_akademis3 = 60.0
	card.bind(s)
	assert_eq(card.get_node("Paper/Name").text, "Citra", "the name lands on the plate")
	assert_true(card.get_node("Paper/Photo").texture == photo, "the photo lands in the frame")
	var rows: Array = card.rows()
	assert_eq(rows.size(), 3, "three rows, akademis/seni/olahraga")
	assert_true(is_equal_approx(rows[0].target_ratio, 100.0), "akademis 70/60 caps at 100")
	assert_true(is_equal_approx(rows[1].target_ratio, 50.0), "seni 30/60 is half")
	assert_true(is_equal_approx(rows[2].target_ratio, 100.0), "olahraga 60/60 is full")
	Engine.get_main_loop().root.remove_child(card)


func test_card_rows_carry_the_right_categories_and_icons() -> void:
	# rows() reads @onready vars, so the card must be in the tree first.
	var card = load(_CARD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	var rows: Array = card.rows()
	assert_eq(rows[0].category, "Akademis", "row 0 is Akademis")
	assert_eq(rows[1].category, "SeniBudaya", "row 1 is SeniBudaya")
	assert_eq(rows[2].category, "Olahraga", "row 2 is Olahraga")
	for r in rows:
		assert_eq(String(r.icon.resource_path), _ICON_DIR + _STAT_ICONS[r.category],
			"%s wears the game's own stat icon" % r.category)
	Engine.get_main_loop().root.remove_child(card)


## Every roster name has to fit the plate at the label's real font and size.
## The widest, MARCEL, measured ~413px in Boohong at 96 against a 457px slot
## on 2026-09-11 -- close enough that a size bump would clip it on screen
## while every structural test stayed green.
func test_every_roster_name_fits_on_the_plate() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var font: Font = theme.get_font("font", "PlateNameLabel")
	var size: int = theme.get_font_size("font_size", "PlateNameLabel")
	var card = load(_CARD_SCENE).instantiate()
	track(card)
	var label: Label = card.get_node("Paper/Name")
	var slot := label.offset_right - label.offset_left
	for student_name in _ROSTER:
		var text: String = student_name.to_upper() if label.uppercase else student_name
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		assert_true(width <= slot,
			"%s is %.0fpx at %dpx; the plate's Name slot is %.0fpx" % [text, width, size, slot])


## StudentCard's proportions: a 128px icon beside a 68px-tall bar.
func test_row_matches_studentcards_proportions() -> void:
	var row = load(_ROW_SCENE).instantiate()
	track(row)
	var icon: TextureRect = row.get_node("Icon")
	assert_eq(icon.custom_minimum_size, Vector2(128, 128), "a 128px icon, like StudentCard's")
	assert_eq(String(icon.texture.resource_path), _ICON_DIR + "stat_akademis.png",
		"a bare row shows the real akademis art")
	assert_eq(row.get_node("Bar").custom_minimum_size.y, 68.0, "StudentCard's pill height")
```

Also, in `test_a_tap_rushes_the_current_student`, change the message fragment `"the Scrim and Paper Panels default to MOUSE_FILTER_STOP and would "` to `"the full-screen Scrim Panel defaults to MOUSE_FILTER_STOP and would "`.

- [ ] **Step 2: Run the tests and watch them fail.** Call `filesystem_manage(op="scan")`, then `test_run(suite="stat_check")`.
  Expected: FAIL in the seven card and row tests above (`Paper` is still a Panel, and there is no `Paper/Name`). Every pre-existing StatCheck, StarMeter and row test still passes.

- [ ] **Step 3: Rewrite `Scripts/EndGame/StatCheckCard.gd`** with the Write tool. The Step 5 restart reloads it. The header must not contain the word "profil" (a test scans for it):

```gdscript
@tool
class_name StatCheckCard
extends Control

## One student's page in the stat check, drawn on StudentCard's own paper
## (2026-09-11): card_bg.png with its PaperShadow, the student's photo in
## the frame printed on it, the name alone on the printed brown plate, and
## three StatCheckRows wearing the stat_* icons the rest of the game uses.
## The page reads as the same sheet the player approved at the start of
## the grade.
##
## Paper is authored at the art's native 1080x1920 and scaled to fit the
## card (StatCheckCard.tscn), so every child sits at StudentCard's own
## measured coordinates and PaperShadow works unmodified.
##
## StudentCard also lists Jenis Kelamin and Tanggal Lahir under the name.
## This page deliberately shows the name only -- it is about the targets,
## not the student's file.
##
## Instanced from StatCheckCard.tscn once per student by StatCheck, which is
## a reviewed per-call-dynamic exception to the no-runtime-construction rule
## (tests/test_viewport_editability.gd ALLOWED).

@onready var name_label: Label = $Paper/Name
@onready var photo: TextureRect = $Paper/Photo
@onready var row_akademis: StatCheckRow = $Paper/Rows/Akademis
@onready var row_seni: StatCheckRow = $Paper/Rows/Seni
@onready var row_olahraga: StatCheckRow = $Paper/Rows/Olahraga


## Fill the page from a StudentData and arm its three rows. Nothing
## animates here -- StatCheck plays each row's fill() in turn.
func bind(student: StudentData) -> void:
	name_label.text = student.student_name
	photo.texture = student.avatar_texture
	row_akademis.set_result(student.akademis, student.target_akademis1)
	row_seni.set_result(student.seni_budaya, student.target_akademis2)
	row_olahraga.set_result(student.olahraga, student.target_akademis3)


## The three rows in the order the check plays them: akademis, seni
## budaya, olahraga -- the brief's order.
func rows() -> Array:
	return [row_akademis, row_seni, row_olahraga]
```

- [ ] **Step 4: Patch the `StatCheck.gd` comment.** Call `script_patch` on `res://Scripts/EndGame/StatCheck.gd` with `old_text`:

```
Control claimed first. The screen's Scrim (StatCheck.tscn) and the
## card's Paper (StatCheckCard.tscn) are Panels at the default
## MOUSE_FILTER_STOP, which consumes pointer events and marks them handled
## before that other callback would ever get a look -- so it would never
## fire here. _input() runs before GUI input handling, so the covering
## Panels cannot swallow it first; this follows the precedent in
```

and `new_text`:

```
Control claimed first. The screen's full-screen Scrim (StatCheck.tscn)
## is a Panel at the default MOUSE_FILTER_STOP, which consumes pointer
## events and marks them handled before that other callback would ever get
## a look -- so it would never fire here. _input() runs before GUI input
## handling, so the covering Scrim cannot swallow it first; this follows
## the precedent in
```

- [ ] **Step 5: Probe for unsaved tabs, then restart the editor.**
  1. Write this throwaway suite as `tests/test_zz_probe_unsaved.gd`:

```gdscript
@tool
extends McpTestSuite

## Throwaway: reports editor tabs with unsaved changes, then fails on
## purpose so the report comes back as the failure message. Delete after use.

func suite_name() -> String:
	return "zz_probe_unsaved"


func test_report_unsaved_tabs() -> void:
	var dirty: Array[String] = []
	for bar in EditorInterface.get_base_control().find_children("*", "TabBar", true, false):
		for i in bar.tab_count:
			if bar.get_tab_title(i).contains("(*)"):
				dirty.append(bar.get_tab_title(i))
	for list in EditorInterface.get_script_editor().find_children("*", "ItemList", true, false):
		for i in list.item_count:
			if list.get_item_text(i).contains("(*)"):
				dirty.append("script: " + list.get_item_text(i))
	assert_true(false, "UNSAVED: %s" % str(dirty))
```

  2. Call `filesystem_manage(op="scan")`, then `test_run(suite="zz_probe_unsaved")`. Read the failure message.
  3. **If it lists anything, stop and ask the user before restarting.** Otherwise delete the probe file and its `.uid`.
  4. Run `bash ~/godot-restart.sh`, then poll `session_manage(op="list")` until `count` is 1.

- [ ] **Step 6: Edit `StatCheckRow.tscn` in the editor.** Call `scene_open("res://Scenes/EndGame/StatCheckRow.tscn")`, then `batch_execute` with these commands:

| path | property | value |
|---|---|---|
| `/StatCheckRow` | `custom_minimum_size` | `{"x":0,"y":128}` |
| `/StatCheckRow` | `theme_override_constants/separation` | `24` |
| `/StatCheckRow/Icon` | `custom_minimum_size` | `{"x":128,"y":128}` |
| `/StatCheckRow/Icon` | `texture` | `"res://Assets/Images/StudentCard/stat_akademis.png"` |
| `/StatCheckRow/Bar` | `custom_minimum_size` | `{"x":0,"y":68}` |

  Each row is `{"command":"set_property","params":{"path":…,"property":…,"value":…}}`. Then call `scene_save`, and run `git diff HEAD --stat -- '*.gd'`. Expected: only `StatCheckCard.gd` and `StatCheck.gd` are listed.

- [ ] **Step 7: Rebuild `StatCheckCard.tscn` in the editor.**
  1. Call `scene_open("res://Scenes/EndGame/StatCheckCard.tscn")`.
  2. Run `batch_execute` with `delete_node` on `/StatCheckCard/Paper`. Confirm it is gone with `node_manage(op="get_children", params={"path":"/StatCheckCard"})` before creating a new node of the same name.
  3. Run one `batch_execute` that creates the nodes in this order (`P` = `/StatCheckCard/Paper`):

| # | create_node | then set_property |
|---|---|---|
| 1 | `TextureRect` "Paper" under `/StatCheckCard` | `texture` = `res://Assets/Images/StudentCard/card_bg.png`; `offset_left` -35.59, `offset_top` -180.17, `offset_right` 1044.41, `offset_bottom` 1739.83; `scale` `{"x":0.757,"y":0.757}`; `mouse_filter` 2 |
| 2 | `scene_path` `res://Scenes/UI/PaperShadow.tscn`, "PaperShadow", under `P` | — |
| 3 | `TextureRect` "Photo" under `P` | offsets 136 / 294 / 419 / 670; `expand_mode` 1; `stretch_mode` 6; `mouse_filter` 2 |
| 4 | `TextureRect` "PortraitFrame" under `P` | `texture` = `res://Assets/Images/StudentCard/portrait_frame.png` (283×376, native size, so no expand settings); offsets 136 / 294 / 419 / 670; `mouse_filter` 2 |
| 5 | `Label` "Name" under `P` | offsets 468 / 300 / 925 / 667; `theme_type_variation` `"PlateNameLabel"`; `horizontal_alignment` 1; `vertical_alignment` 1; `uppercase` true; `text` `"Nama"` |
| 6 | `VBoxContainer` "Rows" under `P` | offsets 132 / 740 / 941 / 1480; `alignment` 1; `theme_override_constants/separation` 64 |
| 7 | `scene_path` `res://Scenes/EndGame/StatCheckRow.tscn`, "Akademis", under `P/Rows` | `icon` = `res://Assets/Images/StudentCard/stat_akademis.png` |
| 8 | same scene, "Seni", under `P/Rows` | `category` `"SeniBudaya"`; `icon` = `res://Assets/Images/StudentCard/stat_senibudaya.png` |
| 9 | same scene, "Olahraga", under `P/Rows` | `category` `"Olahraga"`; `icon` = `res://Assets/Images/StudentCard/stat_olahraga.png` |

  Offsets are listed left / top / right / bottom. Each create is `{"command":"create_node","params":{"type"|"scene_path":…,"name":…,"parent_path":…}}`; each set is `{"command":"set_property","params":{"path":…,"property":…,"value":…}}`.
  4. Call `scene_save`. Then run `git diff HEAD --stat -- '*.gd'`, which must be unchanged from Step 6.
  5. Open the saved file with `filesystem_manage(op="read_text")` and confirm it has `scale = Vector2(0.757, 0.757)`, the offsets above, and **no** `icon_akademis.svg`.

- [ ] **Step 8: Run the tests and confirm they pass.** Run `test_run(suite="stat_check")`, then `test_run(suite="viewport_editability")` and `test_run(suite="script_documentation")`.
  Expected: all PASS.

- [ ] **Step 9: Check it live.**
  1. `project_run(mode="main", autosave=false)`; poll `editor_state` until `helper_live`.
  2. `editor_manage(op="game_eval")` with:

```gdscript
var tree := Engine.get_main_loop() as SceneTree
tree.root.get_node("DebugManager")._start_end_game_rehearsal("lulus")
tree.change_scene_to_file("res://Scenes/EndGame/StatCheck.tscn")
return "ok"
```

  3. Wait about 2 s, then `editor_screenshot(source="game", max_resolution=0)`.
  4. Judge at full size:
     - the paper fills the card
     - the photo sits in the frame
     - the name is cream on the brown plate and not clipped
     - three rows with the `stat_*` icons, bars filling
     - the star meter below, uncovered
  5. Fix anything wrong before moving on, then call `project_manage(op="stop")`.

- [ ] **Step 10: Commit.** Revert `Assets/Audio/default_bus_layout.tres` first if `git status` shows it (the AudioDirector rewrites it on boot).

```bash
git checkout -- Assets/Audio/default_bus_layout.tres 2>/dev/null
git add Scenes/EndGame/StatCheckCard.tscn Scenes/EndGame/StatCheckRow.tscn Scripts/EndGame/StatCheckCard.gd Scripts/EndGame/StatCheck.gd tests/test_stat_check.gd
git commit -m "feat(statcheck): draw each student's page on StudentCard's paper" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: `WinStage`, the shared painting-and-roster scene

**Files:**
- Create: `tests/test_win_stage.gd`
- Create: `Scripts/EndGame/WinStage.gd`
- Create (editor): `Scenes/EndGame/WinStage.tscn`

**Interfaces:**
- Consumes: `WinLineup.assign(names: Array) -> Array[Dictionary]` and `WinLineup.shadow_for(placed: Dictionary, spread: float, flatness: float) -> Dictionary`, both unchanged.
- Produces (used by Task 4):
  - `class_name WinStage extends Control`, @tool
  - `func dress(failed: bool, names: Array) -> void`
  - `static func names_of(roster: Array) -> Array`
  - `static func letterbox(area: Vector2) -> Dictionary` returning `{"scale": float, "position": Vector2}`
  - the scene `res://Scenes/EndGame/WinStage.tscn`, whose root is named `WinStage`

This task only **adds**. EndCutscene keeps its own Stage until Task 4, so every existing suite stays green here.

- [ ] **Step 1: Write the failing test suite** as `tests/test_win_stage.gd`:

```gdscript
@tool
extends McpTestSuiteCompat

## WinStage (2026-09-11): the end-of-grade painting with the run's roster
## posed on it, shared by EndCutscene and RunResult so the two screens open
## and close on the same frame. dress() is plain synchronous code, so the
## layout is exercised live here; the host wiring is covered by
## test_end_cutscene.gd and test_run_result.gd. Suite is @tool and no test
## is a coroutine.

const _SCENE := "res://Scenes/EndGame/WinStage.tscn"
const _SCRIPT := "res://Scripts/EndGame/WinStage.gd"
const _FOUR := ["Doni", "Andi", "Citra", "Shinta"]


func suite_name() -> String:
	return "win_stage"


func _stage() -> WinStage:
	var s: WinStage = load(_SCENE).instantiate()
	track(s)
	return s


## In the editor's root so @onready resolves and dress() can measure a real
## viewport. The caller removes it again before asserting.
func _live_stage() -> WinStage:
	var s := _stage()
	Engine.get_main_loop().root.add_child(s)
	return s


# ───────────────────────────────────────────────────────────── scene shape

func test_the_scene_wears_win_stage() -> void:
	assert_true(_stage() is WinStage, "WinStage.tscn's root runs WinStage.gd")


func test_the_letterbox_bars_are_painted_behind_the_painting() -> void:
	var s := _stage()
	var bars = s.get_node_or_null("BarFill")
	assert_true(bars is ColorRect, "a ColorRect fills the letterbox bars")
	assert_true(bars.get_index() < s.get_node("Stage").get_index(),
		"the bars are behind the painting")
	assert_true(bars.color.a > 0.9, "the bars are opaque -- nothing shows through")
	assert_eq(bars.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the bars never eat a host's clicks")


func test_the_stage_is_the_paintings_art_space() -> void:
	var stage := _stage().get_node_or_null("Stage")
	assert_true(stage is Control, "Stage holds the painting and its figures")
	var backdrop = stage.get_node_or_null("Backdrop")
	assert_true(backdrop is TextureRect, "the painting")
	assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Backdrop covers whatever Stage it sits in, on both verdicts")
	assert_true(stage.get_node_or_null("Shadows") is Control, "the Shadows layer")
	assert_true(stage.get_node_or_null("Students") is Control, "the Students layer")


## All shadows are drawn before all figures, rather than pairing each shadow
## with its own sprite. Pairing would let Doni's wide crouch-shadow smear
## across the side students' shoes.
func test_shadows_draw_beneath_every_student() -> void:
	var stage := _stage().get_node("Stage")
	var backdrop: int = stage.get_node("Backdrop").get_index()
	var shadows: int = stage.get_node("Shadows").get_index()
	var students: int = stage.get_node("Students").get_index()
	assert_true(backdrop < shadows, "the backdrop is behind the shadows")
	assert_true(shadows < students, "every shadow is behind every figure")


func test_the_stage_has_four_authored_slots_and_four_shadows() -> void:
	var stage := _stage().get_node("Stage")
	for i in range(1, 5):
		assert_true(stage.get_node_or_null("Students/Student%d" % i) is TextureRect,
			"Student%d is authored in the scene, not built at runtime" % i)
		assert_true(stage.get_node_or_null("Shadows/Shadow%d" % i) is TextureRect,
			"Shadow%d is authored in the scene, not built at runtime" % i)


## The art lives here and only here -- neither host overrides it, which is
## what guarantees the two screens show the same picture.
func test_both_verdicts_art_is_wired() -> void:
	var s := _stage()
	assert_true(s.win_backdrop is Texture2D, "a win painting is assigned")
	assert_true(s.lose_backdrop is Texture2D, "a lose CG is assigned")
	assert_ne(s.win_backdrop, s.lose_backdrop, "the two outcomes look different")
	assert_eq(String(s.win_backdrop.resource_path),
		"res://Assets/Images/CG/Win/win_background.png", "the graduation painting")
	assert_true(s.shadow_texture is Texture2D, "the ground shadow art is assigned")


## Six typed Texture2D exports, not one Dictionary -- a Dictionary's nested
## values cannot be wired as Resources through the editor's property API.
func test_every_roster_name_has_a_splash_wired() -> void:
	var s := _stage()
	for student_name in ["Doni", "Andi", "Citra", "Shinta", "Marcel", "Thea"]:
		assert_true(s._splash_for(student_name) is Texture2D,
			student_name + "'s splash is a texture")
	assert_true(s._splash_for("Nobody") == null, "an unknown name has no splash")


func test_the_shadow_knobs_are_exported() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	for prop in ["shadow_opacity", "shadow_spread", "shadow_flatness", "bar_color",
			"win_splash_doni"]:
		assert_true(src.contains("@export var " + prop), prop + " is tunable in the Inspector")


# ─────────────────────────────────────────────────────────────── the maths

func test_the_letterbox_fits_the_whole_painting_and_centres_it() -> void:
	var tall: Dictionary = WinStage.letterbox(Vector2(1080, 1920))
	assert_true(is_equal_approx(tall["scale"], 0.703125), "1080 / 1536")
	assert_eq(tall["position"], Vector2(0, 240), "240px bars top and bottom")
	var taller: Dictionary = WinStage.letterbox(Vector2(1080, 2340))
	assert_eq(taller["position"], Vector2(0, 450), "a taller phone gets taller bars")
	var native: Dictionary = WinStage.letterbox(Vector2(1536, 2048))
	assert_true(is_equal_approx(native["scale"], 1.0), "the art's own size is scale 1")
	assert_eq(native["position"], Vector2.ZERO, "with no bars")


func test_the_stage_fits_by_computed_scale_not_a_hardcoded_transform() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("minf("), "it fits by the smaller of the two ratios")
	assert_false(src.contains("0.703125"),
		"the letterbox scale is derived from the viewport, not pasted in")


func test_names_of_reads_names_in_roster_order() -> void:
	var names: Array = WinStage.names_of([{"name": "Citra"}, {"name": "Doni"}, {}])
	assert_eq(names, ["Citra", "Doni", ""], "one name per student, in roster order")


# ──────────────────────────────────────────────────────────────── dressing

func test_dressing_a_win_poses_the_roster_on_the_letterboxed_painting() -> void:
	var s := _live_stage()
	s.dress(false, _FOUR)
	var vp: Vector2 = s.get_viewport_rect().size
	var fit: Dictionary = WinStage.letterbox(vp)
	var stage: Control = s.get_node("Stage")
	var backdrop_tex: Texture2D = s.get_node("Stage/Backdrop").texture
	var shown := 0
	for i in range(1, 5):
		var sprite: TextureRect = s.get_node("Stage/Students/Student%d" % i)
		var shadow: TextureRect = s.get_node("Stage/Shadows/Shadow%d" % i)
		if sprite.visible and sprite.texture != null and shadow.visible:
			shown += 1
	var bars_size: Vector2 = s.get_node("BarFill").size
	Engine.get_main_loop().root.remove_child(s)
	assert_eq(backdrop_tex, s.win_backdrop, "the win painting")
	assert_eq(shown, 4, "four students stand on it, each with a shadow")
	assert_true(is_equal_approx(stage.scale.x, stage.scale.y), "scaled uniformly")
	assert_true(is_equal_approx(stage.scale.x, fit["scale"]), "by the letterbox scale")
	assert_true(stage.position.is_equal_approx(fit["position"]), "and centred")
	assert_eq(bars_size, vp, "the bars fill the whole screen behind it")


## Lose keeps the framing the CG always had: Stage fills the viewport and
## Backdrop's KEEP_ASPECT_COVERED crops it. Dressed after a win on purpose,
## so a stale lineup cannot survive onto the lose CG.
func test_dressing_a_loss_covers_the_screen_and_hides_the_lineup() -> void:
	var s := _live_stage()
	s.dress(false, _FOUR)
	s.dress(true, _FOUR)
	var vp: Vector2 = s.get_viewport_rect().size
	var stage: Control = s.get_node("Stage")
	var backdrop_tex: Texture2D = s.get_node("Stage/Backdrop").texture
	var visible_slots := 0
	for i in range(1, 5):
		if s.get_node("Stage/Students/Student%d" % i).visible:
			visible_slots += 1
		if s.get_node("Stage/Shadows/Shadow%d" % i).visible:
			visible_slots += 1
	Engine.get_main_loop().root.remove_child(s)
	assert_eq(backdrop_tex, s.lose_backdrop, "the lose CG")
	assert_eq(stage.scale, Vector2.ONE, "unscaled")
	assert_eq(stage.size, vp, "covering the viewport")
	assert_eq(visible_slots, 0, "no student or shadow survives onto the lose CG")


func test_the_lineup_comes_from_win_lineup() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("WinLineup.assign("), "slot assignment lives in WinLineup")
	assert_true(src.contains("WinLineup.shadow_for("), "so does shadow geometry")


## StatCheck wrote the verdict; the stage only draws what it is told.
func test_the_stage_never_decides_the_verdict() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_false(src.contains("check_semester_passed"),
		"WinStage must not recompute the verdict")
```

- [ ] **Step 2: Run the suite and watch it fail.** Call `filesystem_manage(op="scan")`, then `test_run(suite="win_stage")`.
  Expected: the suite fails to load or every test fails, because the `WinStage` class and scene do not exist yet.

- [ ] **Step 3: Create `Scripts/EndGame/WinStage.gd`** with `script_create`, then call `filesystem_manage(op="scan")` so `class_name WinStage` registers:

```gdscript
@tool
class_name WinStage
extends Control

## The end-of-grade painting with the run's roster posed on it (2026-09-11):
## the letterbox bars, win_background.png, four student slots and their
## ground shadows. EndCutscene and RunResult both instance this one scene,
## so the frame RunResult opens on is the frame EndCutscene blurred out on --
## the same art, the same framing, the same students -- rather than two
## layouts kept in step by hand. It used to live inside EndCutscene; it moved
## here when RunResult needed the same picture behind its report.
##
## dress() is the only entry point, and the host passes everything in: the
## verdict StatCheck wrote and the roster's names. Nothing here decides the
## verdict or reads the roster itself.
##
## The root is a bare anchor that draws from its children. An instanced
## scene's root under a plain Control reloads with its rect snapped to zero
## (authoring guide, "Two ways the editor silently drops a Control's rect"),
## so dress() sizes BarFill and fits Stage to the viewport in code, the way
## PaperShadow draws from its Silhouette.
##
## @tool so the test suites can instantiate it inside the editor. _ready()
## only re-asserts the bar colour; the layout happens when a host calls
## dress() at runtime.

@export_group("Backdrops")
## Painting shown when the run passed. Real graduation artwork; the students and shadows compose on top.
@export var win_backdrop: Texture2D
## CG shown when the run failed. Covers the viewport, with no lineup on it.
@export var lose_backdrop: Texture2D

@export_group("Win lineup")
## Splash art for roster name "Doni". Null leaves its slot hidden.
@export var win_splash_doni: Texture2D
## Splash art for roster name "Andi". Null leaves its slot hidden.
@export var win_splash_andi: Texture2D
## Splash art for roster name "Citra". Null leaves its slot hidden.
@export var win_splash_citra: Texture2D
## Splash art for roster name "Shinta". Null leaves its slot hidden.
@export var win_splash_shinta: Texture2D
## Splash art for roster name "Marcel". Null leaves its slot hidden.
@export var win_splash_marcel: Texture2D
## Splash art for roster name "Thea". Null leaves its slot hidden.
@export var win_splash_thea: Texture2D
## Fills the letterbox bars above and below the painting. Defaults to the
## surface_overlay token so the bars read as the game's own chrome rather
## than as a video letterbox.
@export var bar_color: Color = Color("141a2e")
## Texture every ground shadow wears. Drop-replacement point for real art.
@export var shadow_texture: Texture2D
## Alpha of every ground shadow, 0-1.
@export var shadow_opacity: float = 0.28
## Multiplies each student's measured foot span to get its shadow width.
@export var shadow_spread: float = 1.25
## Ellipse height as a fraction of its width. Lower reads as a flatter
## floor, higher as a softer pool.
@export var shadow_flatness: float = 0.28

## The painting's native size. Students are positioned in this space and the
## whole Stage is scaled into the viewport, so numbers measured off the
## mockup transfer 1:1 and the composition never drifts from the art.
const ART_SIZE := Vector2(1536.0, 2048.0)

@onready var bar_fill: ColorRect = $BarFill
@onready var stage: Control = $Stage
@onready var backdrop: TextureRect = $Stage/Backdrop
@onready var shadows: Control = $Stage/Shadows
@onready var students: Control = $Stage/Students


func _ready() -> void:
	# Authored at the token's value too, but re-asserted so changing the
	# export is enough -- the bars and the export must not drift apart.
	bar_fill.color = bar_color


## The names of an approved_students-shaped roster, in roster order. A
## student with no "name" key contributes "", which has no splash and so
## leaves its slot hidden.
static func names_of(roster: Array) -> Array:
	var names: Array = []
	for student in roster:
		names.append(student.get("name", ""))
	return names


## Where the letterboxed painting lands in a viewport of `area`: scaled by
## the smaller ratio so the whole 3:4 image survives on a 9:16 screen, and
## centred. At 1080x1920 that is 1080x1440 with 240px bars top and bottom.
## Returns {"scale": float, "position": Vector2}.
static func letterbox(area: Vector2) -> Dictionary:
	var s := minf(area.x / ART_SIZE.x, area.y / ART_SIZE.y)
	return {"scale": s, "position": (area - ART_SIZE * s) * 0.5}


## Dress the stage for a verdict. Win letterboxes the painting and poses
## `names` on it; lose covers the viewport with the lose CG and hides every
## slot. Sets BarFill, Stage's transform, Backdrop's texture and every
## Student/Shadow slot -- nothing is constructed.
func dress(failed: bool, names: Array) -> void:
	var vp := get_viewport_rect().size
	bar_fill.position = Vector2.ZERO
	bar_fill.size = vp
	backdrop.texture = lose_backdrop if failed else win_backdrop
	if not failed:
		_fit_stage(vp)
		_dress_lineup(names)
	else:
		_fit_stage_cover(vp)
		_hide_lineup()


## Letterbox the painting into `vp` (see letterbox()).
func _fit_stage(vp: Vector2) -> void:
	var fit := letterbox(vp)
	var s: float = fit["scale"]
	stage.size = ART_SIZE
	stage.scale = Vector2(s, s)
	stage.position = fit["position"]


## The lose path keeps the framing the CG has always had: Stage fills the
## viewport and Backdrop covers it (KEEP_ASPECT_COVERED), so cg_lose.jpg is
## centred and cropped rather than stretched. Left at the 1536x2048 art
## size, Stage would show only the CG's top-left corner.
func _fit_stage_cover(vp: Vector2) -> void:
	stage.size = vp
	stage.scale = Vector2.ONE
	stage.position = Vector2.ZERO


## Splash art for a roster name, or null when the name is unknown.
##
## Six separate exports rather than one Dictionary: a Dictionary's nested
## values cannot be wired as Resources through the editor's property API,
## so the paths stayed strings and the textures never loaded.
func _splash_for(student_name: String) -> Texture2D:
	match student_name:
		"Doni": return win_splash_doni
		"Andi": return win_splash_andi
		"Citra": return win_splash_citra
		"Shinta": return win_splash_shinta
		"Marcel": return win_splash_marcel
		"Thea": return win_splash_thea
	return null


## Put the roster on the stage. Slots and shadows are authored nodes; this
## only sets texture, size, position and visibility on them.
func _dress_lineup(names: Array) -> void:
	var placed := WinLineup.assign(names)
	for i in range(4):
		var sprite: TextureRect = students.get_node("Student%d" % (i + 1))
		var shadow: TextureRect = shadows.get_node("Shadow%d" % (i + 1))
		if i >= placed.size():
			sprite.hide()
			shadow.hide()
			continue

		var p: Dictionary = placed[i]
		var tex: Texture2D = _splash_for(p["name"])
		if tex == null:
			push_warning("WinStage: no win splash for '%s'" % p["name"])
			sprite.hide()
			shadow.hide()
			continue

		# The splash is anchored bottom-centre: its canvas is square, so
		# half its scaled width sits either side of the anchor and its
		# full scaled height sits above it.
		var side: float = tex.get_width() * float(p["scale"])
		sprite.texture = tex
		sprite.size = Vector2(side, side)
		sprite.position = Vector2(p["anchor"]) - Vector2(side * 0.5, side)
		sprite.show()

		var sh := WinLineup.shadow_for(p, shadow_spread, shadow_flatness)
		var sh_size: Vector2 = sh["size"]
		var sh_centre: Vector2 = sh["centre"]
		shadow.texture = shadow_texture
		shadow.size = sh_size
		shadow.position = sh_centre - sh_size * 0.5
		shadow.modulate = Color(0.0, 0.0, 0.0, shadow_opacity)
		shadow.show()


## Hide every student and shadow. The lose CG has no lineup, and a stage
## dressed twice must not keep a previous win's figures.
func _hide_lineup() -> void:
	for i in range(1, 5):
		students.get_node("Student%d" % i).hide()
		shadows.get_node("Shadow%d" % i).hide()
```

- [ ] **Step 4: Build `WinStage.tscn` in the editor.**
  1. Call `scene_manage(op="create", params={"path":"res://Scenes/EndGame/WinStage.tscn","root_type":"Control","root_name":"WinStage"})`.
  2. Run one `batch_execute`. Paths are root-prefixed: `W` = `/WinStage`, `S` = `/WinStage/Stage`.

| # | command | settings |
|---|---|---|
| 1 | `attach_script` `{path: W, script_path: "res://Scripts/EndGame/WinStage.gd"}` | root: `anchor_right` 1, `anchor_bottom` 1, `mouse_filter` 2 |
| 2 | `create_node` `ColorRect` "BarFill" under W | `offset_right` 1080, `offset_bottom` 1920, `color` `"#141a2e"`, `mouse_filter` 2 |
| 3 | `create_node` `Control` "Stage" under W | `offset_right` 1536, `offset_bottom` 2048, `mouse_filter` 2 |
| 4 | `create_node` `TextureRect` "Backdrop" under S | `layout_mode` 1, then `anchor_right` 1 and `anchor_bottom` 1; `expand_mode` 1; `stretch_mode` 6; `mouse_filter` 2; `texture` = `res://Assets/Images/CG/Win/win_background.png` |
| 5 | `create_node` `Control` "Shadows" under S | `mouse_filter` 2 |
| 6 | `TextureRect` "Shadow1"…"Shadow4" under `S/Shadows` | each: `visible` false, `mouse_filter` 2, `expand_mode` 1, `texture` = `res://Assets/Images/UI/Placeholders/shadow_ellipse.png` |
| 7 | `create_node` `Control` "Students" under S | `mouse_filter` 2 |
| 8 | `TextureRect` "Student1"…"Student4" under `S/Students` | each: `visible` false, `mouse_filter` 2, `expand_mode` 1 |

  3. Set the root exports as `res://` paths with `set_property` on `/WinStage`:

| export | value |
|---|---|
| `win_backdrop` | `res://Assets/Images/CG/Win/win_background.png` |
| `lose_backdrop` | `res://Assets/Images/CG/cg_lose.jpg` |
| `shadow_texture` | `res://Assets/Images/UI/Placeholders/shadow_ellipse.png` |
| `win_splash_doni` | `res://Assets/Images/CG/Win/win_doni.png` |
| `win_splash_andi` | `res://Assets/Images/CG/Win/win_andi.png` |
| `win_splash_citra` | `res://Assets/Images/CG/Win/win_citra.png` |
| `win_splash_shinta` | `res://Assets/Images/CG/Win/win_shinta.png` |
| `win_splash_marcel` | `res://Assets/Images/CG/Win/win_marcel.png` |
| `win_splash_thea` | `res://Assets/Images/CG/Win/win_thea.png` |

  If an export reports `PROPERTY_NOT_ON_CLASS`, the script has not registered yet: rescan and re-run that part.
  4. Call `scene_save`, then run `git diff HEAD --stat -- '*.gd'`. Nothing may be listed except files this plan changes.

- [ ] **Step 5: Run the tests and confirm they pass.** Run `test_run(suite="win_stage")`, then `test_run(suite="script_documentation")` and `test_run(suite="end_cutscene")`. The last one is still untouched.
  Expected: all PASS.

- [ ] **Step 6: Commit.**

```bash
git add Scripts/EndGame/WinStage.gd Scripts/EndGame/WinStage.gd.uid Scenes/EndGame/WinStage.tscn tests/test_win_stage.gd tests/test_win_stage.gd.uid
git commit -m "feat(endgame): lift the win painting and roster into a shared WinStage scene" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: EndCutscene and RunResult both stand on the WinStage

**Files:**
- Modify: `tests/test_end_cutscene.gd`, `tests/test_run_result.gd`
- Rewrite: `Scripts/EndGame/EndCutscene.gd`
- Modify: `Scripts/EndGame/RunResult.gd` (three patches)
- Comments only: `Scripts/EndGame/WinLineup.gd`, `tests/test_win_lineup.gd`
- Modify (editor): `Scenes/EndGame/EndCutscene.tscn`, `Scenes/EndGame/RunResult.tscn`

**Interfaces:**
- Consumes: from Task 3, `WinStage.dress(failed, names)`, `WinStage.names_of(roster)`, and `res://Scenes/EndGame/WinStage.tscn`.
- Produces: both hosts carry a `WinStage` child at index 0, and both scripts contain the shared dress line verbatim.

- [ ] **Step 1: Update `tests/test_end_cutscene.gd`.**
  1. **Delete** these nine tests, which now live in `test_win_stage.gd`:
     - `test_the_scene_carries_an_art_space_stage`
     - `test_shadows_draw_beneath_every_student`
     - `test_the_lose_path_covers_the_viewport_like_it_used_to`
     - `test_the_stage_has_four_authored_slots_and_four_shadows`
     - `test_the_stage_fits_by_computed_scale_not_a_hardcoded_transform`
     - `test_the_lineup_comes_from_win_lineup`
     - `test_the_shadow_knobs_are_exported`
     - `test_every_roster_name_has_a_splash_wired`
     - `test_the_letterbox_bars_are_painted`
  2. In `test_scene_has_the_chrome`, replace `assert_true(s.get_node_or_null("Stage/Backdrop") is TextureRect, "Backdrop")` with `assert_true(s.get_node_or_null("WinStage") is WinStage, "the shared win stage")`.
  3. Replace the body of `test_both_verdicts_are_dressed_from_exports` with:

```gdscript
	var s := _scene()
	var stage: WinStage = s.get_node("WinStage")
	assert_true(stage.win_backdrop is Texture2D, "the stage carries a win painting")
	assert_true(stage.lose_backdrop is Texture2D, "and a lose CG")
	assert_true(s.lose_badge is Texture2D, "a lose badge is assigned")
	assert_eq(String(s.win_bgm), "result_win", "win BGM")
	assert_eq(String(s.lose_bgm), "result_lose", "lose BGM")
```

  4. In `test_the_blur_layer_blurs_the_backdrop_but_not_the_badge_or_button`:
     - replace `var stage_at := order.find("Stage")` with `var stage_at := order.find("WinStage")`
     - change the two messages to `"WinStage is a direct child of the root"` and `"WinStage draws first, so the shader samples the painting and its figures"`
  5. In `test_the_blur_layer_draws_above_the_stage`, replace `s.get_node("Stage").get_index()` with `s.get_node("WinStage").get_index()`.
  6. Append:

```gdscript


# ─────────────────────────────────────────────────── the shared win stage

const _WIN_STAGE_SCENE := "res://Scenes/EndGame/WinStage.tscn"
## The one line EndCutscene and RunResult both dress the stage with. Pinned
## verbatim in both suites: the same call with the same inputs is what makes
## RunResult open on the frame this screen blurred out on.
const _DRESS_CALL := "win_stage.dress(GameState.run_failed, WinStage.names_of(GameState.approved_students))"


func test_the_painting_and_lineup_come_from_the_shared_win_stage() -> void:
	var s := _scene()
	var first := s.get_child(0)
	assert_eq(first.name, &"WinStage", "the stage is the first thing drawn")
	assert_eq(first.scene_file_path, _WIN_STAGE_SCENE,
		"an instance of the shared scene, not a local copy")
	assert_true(s.get_node_or_null("Stage") == null and s.get_node_or_null("BarFill") == null,
		"the old local Stage and BarFill are gone")


func test_it_dresses_the_stage_with_the_shared_call() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains(_DRESS_CALL), "the verdict and roster go to WinStage.dress()")
	for gone in ["func _dress_lineup(", "func _fit_stage(", "func _splash_for(",
			"@export var win_backdrop", "@export var win_splash_doni"]:
		assert_false(src.contains(gone), "EndCutscene no longer owns '%s'" % gone)
```

- [ ] **Step 2: Update `tests/test_run_result.gd`.**
  1. In `test_the_screen_has_a_backdrop_grade_card_and_rows_box`, replace `screen.get_node_or_null("Backdrop") != null` with `screen.get_node_or_null("WinStage") != null`.
  2. In `test_the_backdrop_is_the_same_blurred_cg_the_cutscene_ended_on`, replace `order.find("Backdrop") < order.find("BlurLayer")` with `order.find("WinStage") < order.find("BlurLayer")`, and its message with `"the win stage draws first, so the shader samples it"`.
  3. Replace `test_the_backdrop_is_dressed_from_the_same_verdict_flag` and `test_the_win_backdrop_is_the_image_the_cutscene_actually_ends_on`, including their `##` doc comments, with:

```gdscript
## Which picture is shown is StatCheck's verdict, passed to the shared stage
## exactly the way EndCutscene passes it. RunResult must not recompute it.
func test_the_backdrop_is_dressed_from_the_same_verdict_flag() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("@export var win_backdrop"),
		"the painting moved to WinStage.tscn -- one art source for both screens")
	assert_false(src.contains("@export var lose_backdrop"), "and so did the lose CG")
	var from := src.find("func _dress_backdrop()")
	assert_true(from != -1, "_dress_backdrop exists")
	var to := src.find("\nfunc ", from + 1)
	var body := src.substr(from, to - from) if to != -1 else src.substr(from)
	assert_true(body.contains("GameState.run_failed"),
		"the choice comes from the flag StatCheck wrote")
	assert_false(body.contains("check_semester_passed"),
		"the backdrop must not re-decide the verdict, only mirror it")


## RunResult's header always promised "the SAME image EndCutscene shows". It
## pointed at cg_win.jpg while EndCutscene moved on, then showed the right
## painting cropped differently and without the students. Now both screens
## instance one scene, and the art is referenced in exactly one file.
func test_both_screens_open_on_the_one_win_stage() -> void:
	var run_src := FileAccess.get_file_as_string(_SCENE_PATH)
	var cut_src := FileAccess.get_file_as_string("res://Scenes/EndGame/EndCutscene.tscn")
	var stage_src := FileAccess.get_file_as_string("res://Scenes/EndGame/WinStage.tscn")
	var stage_scene := "res://Scenes/EndGame/WinStage.tscn"
	var painting := "Assets/Images/CG/Win/win_background.png"
	assert_true(run_src.contains(stage_scene), "RunResult instances WinStage")
	assert_true(cut_src.contains(stage_scene), "and so does EndCutscene")
	assert_true(stage_src.contains(painting), "the painting is wired in WinStage.tscn")
	assert_false(run_src.contains(painting) or cut_src.contains(painting),
		"and nowhere else -- no host keeps or overrides its own copy")
	assert_false(run_src.contains("cg_win.jpg"), "the old, smaller win CG stays gone")


## The line EndCutscene dresses the stage with, verbatim -- see
## test_end_cutscene.gd's copy. Same call, same inputs, same frame.
const _DRESS_CALL := "win_stage.dress(GameState.run_failed, WinStage.names_of(GameState.approved_students))"


func test_both_screens_dress_the_stage_with_the_identical_call() -> void:
	var run_src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var cut_src := FileAccess.get_file_as_string(_CUTSCENE_SCRIPT)
	assert_true(run_src.contains(_DRESS_CALL), "RunResult dresses the stage from the verdict and roster")
	assert_true(cut_src.contains(_DRESS_CALL), "exactly as EndCutscene does")


func test_the_old_backdrop_node_is_gone() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	# Resolve to plain values BEFORE freeing -- see the Scrim test above.
	var has_backdrop: bool = screen.get_node_or_null("Backdrop") != null
	var first_name := String(screen.get_child(0).name)
	screen.free()
	assert_false(has_backdrop, "the cropped painting is replaced by the win stage")
	assert_eq(first_name, "WinStage", "which draws first")


## Letterboxed, the win stage puts the navy bar behind the title, where
## H1Label's dark brown vanished. The title takes the results screens' own
## light-on-dark label instead: gold display face with a dark outline, which
## reads on the bar and, on shorter screens with no bar, on the blurred
## painting.
func test_the_title_reads_over_the_letterbox_bar() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var variation := String(screen.get_node("MarginContainer/Column/TitleLabel").theme_type_variation)
	screen.free()
	assert_eq(variation, "ResultHeroLabel", "gold with a dark outline, not dark brown")
```

- [ ] **Step 3: Run the tests and watch them fail.** Call `filesystem_manage(op="scan")`, then run `test_run(suite="end_cutscene")` and `test_run(suite="run_result")`.
  Expected: FAIL in the new tests and the retargeted ones. The hosts do not carry a WinStage yet.

- [ ] **Step 4: Rewrite `Scripts/EndGame/EndCutscene.gd`** with the Write tool:

```gdscript
@tool
class_name EndCutscene
extends Control

## The win / lose beat between StatCheck and RunResult (2026-09-05).
##
## One scene for both outcomes: StatCheck writes GameState.run_failed on its
## way out, this screen reads it once in _ready() and dresses itself from
## it -- the shared WinStage, a badge and a BGM from the paired exports
## below. Nothing else here branches, and it never recomputes the verdict.
##
## The painting, the letterbox bars and the posed roster live in
## WinStage.tscn, not here, since 2026-09-11: RunResult instances the same
## scene behind its report, so the frame this screen blurs out on is the
## frame RunResult opens on.
##
## Sequence: the scene opens under an opaque white overlay -- completing the
## fade StatCheck ends on, which is why that hand-off deliberately bypasses
## Transition -- fades it out over the image, holds so the image reads,
## slams the badge into the top-left (lose only), holds again, then reveals
## the Next button. The button is the only way forward, and is disabled
## until then.
##
## Pressing it blurs the stage in place and swaps RunResult in underneath.
## That blur is the transition: this screen does not call Transition, exactly
## as StatCheck does not on the way in, so the three screens read as one
## continuous beat instead of three wipes.
##
## @tool so the MCP test suite can instantiate the scene inside the editor;
## every runtime side effect sits behind Engine.is_editor_hint(). The button
## signal is wired before that guard so the wiring stays testable.

@export_group("Win")
## Assigned to Badge.texture on the win path (_dress_for_verdict()) but
## never stamped there -- only the lose path stamps this badge (method name
## avoided here since the test scans the file for it, comments included). The
## win chalkboard already reads "Selamat Kelulusan" (see the note above
## _dress_for_verdict()). Retained only so the win branch still has a texture
## to assign.
@export var win_badge: Texture2D
## BGM started when the run passed.
@export var win_bgm: StringName = &"result_win"

@export_group("Lose")
## Badge stamped into the top-left when the run failed.
@export var lose_badge: Texture2D
## BGM started when the run failed.
@export var lose_bgm: StringName = &"result_lose"

@export_group("Pacing")
## Seconds the opaque white overlay takes to clear.
@export var white_fade_seconds: float = 0.8
## Pause after the white clears, so the image reads before the badge lands.
@export var image_hold_seconds: float = 0.6
## Pause after the badge lands before the Next button appears.
@export var button_delay_seconds: float = 0.5

@export_group("Exit blur")
## Seconds the backdrop takes to blur once Next is pressed. This IS the
## transition to RunResult -- there is no wipe over the top of it.
@export var blur_seconds: float = 0.5
## Final blur strength, as a screen-texture mip level. Matches the shop's
## BlurLayer (koprasi.tscn) so the two blurs read as the same effect.
@export var blur_lod: float = 3.0
## Final dim applied with the blur, 0-1. RunResult opens on exactly this
## value so the swap between the two screens is invisible -- change one and
## you must change the other (test_run_result pins them together).
@export var blur_darkness: float = 0.3

## Where the button goes.
const RUN_RESULT_SCENE := "res://Scenes/EndGame/RunResult.tscn"

## The painting, the letterbox bars and the posed roster -- the scene
## RunResult instances too. Drawn first, so BlurLayer samples all of it.
@onready var win_stage: WinStage = $WinStage
@onready var badge: TextureRect = $Badge
@onready var btn_next: Button = $BtnNext
@onready var white_fade: ColorRect = $WhiteFade
## Sits between WinStage and Badge on purpose: the shader samples what is
## already drawn, so only the stage blurs and the badge stays sharp.
@onready var blur_layer: ColorRect = $BlurLayer

var _exiting: bool = false


func _ready() -> void:
	btn_next.pressed.connect(_on_next_pressed)

	# Re-asserted here as well as authored in the scene: @tool means the
	# editor may have left any of these part-way through an edit.
	white_fade.modulate.a = 1.0
	badge.modulate.a = 0.0
	btn_next.modulate.a = 0.0
	btn_next.disabled = true

	# Park the blur inert. lod 0 makes textureLod an identity sample and
	# darkness 0 leaves the colour alone, so the layer is a no-op even if it
	# is shown -- the scene authors darkness at the shader's own 0.3 default,
	# which would otherwise dim the image the moment the layer appeared.
	blur_layer.hide()
	_set_blur(0.0, 0.0)

	if Engine.is_editor_hint():
		return

	_dress_for_verdict()
	_play()


## Reads the verdict once and dresses the screen for it. StatCheck decided
## it; this screen is only the reveal.
##
## The stage dresses itself for either verdict (the roster on the painting
## for a win, the covering CG for a loss). The badge differs too: win shows
## none -- the chalkboard already reads "Selamat Kelulusan", so a LULUS
## stamp over it would be redundant and would cover the art.
func _dress_for_verdict() -> void:
	var failed: bool = GameState.run_failed
	win_stage.dress(GameState.run_failed, WinStage.names_of(GameState.approved_students))
	badge.texture = lose_badge if failed else win_badge
	AudioDirector.play_bgm(lose_bgm if failed else win_bgm)


## The beat, as a coroutine -- never call this from a test.
func _play() -> void:
	var tw := create_tween()
	tw.tween_property(white_fade, "modulate:a", 0.0, white_fade_seconds) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(image_hold_seconds).timeout
	if not is_inside_tree():
		return

	var failed: bool = GameState.run_failed
	if failed:
		_slam_badge()
		await get_tree().create_timer(button_delay_seconds).timeout
		if not is_inside_tree():
			return

	btn_next.disabled = false
	Juice.pop_in(btn_next)


## The stamp gesture RunResult._slam_grade() uses for the letter grade: down
## from 3x with a back-out overshoot, a shake, and the stamp cue.
func _slam_badge() -> void:
	Juice.set_pivot_center(badge)
	badge.scale = Vector2(3.0, 3.0)
	badge.modulate.a = 0.0
	var t := Juice.tokens()
	var tw := badge.create_tween().set_parallel(true)
	tw.tween_property(badge, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(badge, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(badge.get_parent(), 8.0))


## Writes both blur uniforms at once. Kept in one place because they are
## only ever meaningful together: lod without darkness reads as a smear,
## darkness without lod as a plain dim.
func _set_blur(lod: float, darkness: float) -> void:
	var mat: ShaderMaterial = blur_layer.material
	mat.set_shader_parameter("lod", lod)
	mat.set_shader_parameter("darkness", darkness)


## The hand-off: the stage blurs where it stands, and RunResult is swapped in
## underneath it. A coroutine -- never call it from a test.
##
## Deliberately bypasses the project-wide wipe. The blur is the transition; a
## wipe over the top would read as two of them. StatCheck bypasses it on the
## way in here for the same reason, so the whole StatCheck -> this ->
## RunResult stretch is one continuous piece rather than three wipes.
##
## (Naming the autoload's method in full here would trip the suite's own
## grep for it -- that assertion is how the wipe is kept out.)
func _blur_out() -> void:
	_set_blur(0.0, 0.0)
	blur_layer.show()
	var mat: ShaderMaterial = blur_layer.material
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "shader_parameter/lod", blur_lod, blur_seconds)
	tw.tween_property(mat, "shader_parameter/darkness", blur_darkness,
		blur_seconds)
	await tw.finished


## Guarded so a double-tap cannot fire two scene changes, the same way
## TesNotice and RunResult guard theirs.
func _on_next_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	await _blur_out()
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(RUN_RESULT_SCENE)
```

- [ ] **Step 5: Patch `Scripts/EndGame/RunResult.gd`** with three `script_patch` calls. The Write tool is also fine, because Step 7 restarts the editor.
  1. `old_text`:

```
@export_group("Backdrop")
## Backdrop when the run passed. The SAME image EndCutscene shows, so this
## screen opens on the frame that one blurred out on.
@export var win_backdrop: Texture2D
## Backdrop when the run failed. Likewise paired with EndCutscene's.
@export var lose_backdrop: Texture2D
## Blur strength
```

     `new_text`:

```
@export_group("Backdrop blur")
## Blur strength
```

  2. `old_text`:

```
@onready var backdrop: TextureRect = $Backdrop
## Between Backdrop and the report UI: the shader samples what is already
```

     `new_text`:

```
## The painting, the letterbox bars and the posed roster: the same scene
## EndCutscene shows, dressed the same way (_dress_backdrop()).
@onready var win_stage: WinStage = $WinStage
## Between WinStage and the report UI: the shader samples what is already
```

  3. `old_text`, from the `_dress_backdrop` doc through its first body line:

```
## Opens on the frame EndCutscene blurred out on: the same CG for the same
## verdict, at the same blur and the same dim. StatCheck decided the verdict
## and EndCutscene already showed it -- this only re-dresses, it never
## recomputes.
```

     `new_text`:

```
## Opens on the frame EndCutscene blurred out on -- literally the same
## scene, WinStage, dressed by the same call from the same two inputs, then
## blurred by the same shader at the same strength and dim. StatCheck
## decided the verdict and EndCutscene already showed it -- this only
## re-dresses, it never recomputes.
```

     Then one more patch on the body line, `old_text` `	backdrop.texture = lose_backdrop if GameState.run_failed else win_backdrop` → `new_text` `	win_stage.dress(GameState.run_failed, WinStage.names_of(GameState.approved_students))`.

- [ ] **Step 6: Patch the comments** so they point at the new owner. Each patch is one single-line `script_patch`, quoted byte-for-byte from the file (grepped 2026-09-11).

| File:line | `old_text` | `new_text` |
|---|---|---|
| `Scripts/EndGame/WinLineup.gd:4` | `(2026-09-09). EndCutscene shows the` | `(2026-09-09). WinStage shows the` |
| `Scripts/EndGame/WinLineup.gd:19` | `## EndCutscene.gd converts. Full derivation:` | `## WinStage.gd converts. Full derivation:` |
| `Scripts/EndGame/WinLineup.gd:107` | `slots_for(). EndCutscene._dress_lineup() maps` | `slots_for(). WinStage._dress_lineup() maps` |
| `Scripts/EndGame/WinLineup.gd:110` | `render on top without EndCutscene having` | `render on top without WinStage having` |
| `Scripts/EndGame/WinLineup.gd:158` | `of its width -- both are EndCutscene` | `of its width -- both are WinStage` |
| `tests/test_win_lineup.gd:134` | `back to front, so EndCutscene can` | `back to front, so WinStage can` |

  Afterwards, `grep -n EndCutscene Scripts/EndGame/WinLineup.gd` must print nothing.

- [ ] **Step 7: Probe for unsaved tabs and restart the editor.** Repeat Task 2, Step 5 exactly: probe, stop if anything is unsaved, delete the probe, run `bash ~/godot-restart.sh`, and wait for the session.

- [ ] **Step 8: Put a WinStage under EndCutscene.**
  1. `scene_open("res://Scenes/EndGame/EndCutscene.tscn")`.
  2. `batch_execute` with `delete_node` on `/EndCutscene/BarFill` and on `/EndCutscene/Stage`. Confirm with `node_manage(op="get_children")`.
  3. `batch_execute`:
     - `create_node` `{"scene_path":"res://Scenes/EndGame/WinStage.tscn","name":"WinStage","parent_path":"/EndCutscene"}`
     - `move_node` `{"path":"/EndCutscene/WinStage","index":0}`
  4. `scene_save`, then `git diff HEAD --stat -- '*.gd'`. Only this plan's `.gd` files may be listed.
  5. Read the saved `.tscn` with `filesystem_manage(op="read_text")`. It must contain `WinStage.tscn`, and must **not** contain `win_background.png`, `win_splash_`, `shadow_texture`, `[node name="Stage"` or `[node name="BarFill"`.

- [ ] **Step 9: Put a WinStage under RunResult.**
  1. `scene_open("res://Scenes/EndGame/RunResult.tscn")`.
  2. `batch_execute` with `delete_node` on `/RunResult/Backdrop`, then confirm it is gone.
  3. `batch_execute`:
     - `create_node` `{"scene_path":"res://Scenes/EndGame/WinStage.tscn","name":"WinStage","parent_path":"/RunResult"}`
     - `move_node` `{"path":"/RunResult/WinStage","index":0}`
     - `set_property` `{"path":"/RunResult/MarginContainer/Column/TitleLabel","property":"theme_type_variation","value":"ResultHeroLabel"}`
  4. `scene_save`, then the same `git diff` check.
  5. Read the saved `.tscn`. It must contain `WinStage.tscn` and `ResultHeroLabel`, and must **not** contain `win_background.png` or `cg_lose.jpg`.

- [ ] **Step 10: Run the tests and confirm they pass.** Run `test_run` for each suite: `end_cutscene`, `run_result`, `win_stage`, `win_lineup`, `audio_coverage`, `script_documentation`, `viewport_editability`.
  Expected: all PASS.

- [ ] **Step 11: Check both verdicts live.**
  1. `project_run(mode="main", autosave=false)`; wait for `helper_live`.
  2. **Win.** `game_eval`:

```gdscript
var tree := Engine.get_main_loop() as SceneTree
tree.root.get_node("DebugManager")._start_end_game_rehearsal("lulus")
tree.change_scene_to_file("res://Scenes/EndGame/StatCheck.tscn")
Engine.time_scale = 8.0
return "ok"
```

     Poll `game_eval` `return (Engine.get_main_loop() as SceneTree).current_scene.name` until it returns `EndCutscene`. Then `game_eval` `Engine.time_scale = 1.0; return "ok"`, wait ~2 s, and screenshot at full size. Call this **A**.
  3. Press Lanjut: `game_eval` `(Engine.get_main_loop() as SceneTree).current_scene._on_next_pressed(); return "ok"`. Wait ~3 s and screenshot. Call this **B**.
  4. Judge A and B at full size:
     - B's blurred background shows the same letterbox bars, the same painting framing, and the same four students with shadows as A.
     - The gold title reads on the top bar.
     - The report is intact.
  5. **Lose.** Repeat with `"gagal"`, giving C (EndCutscene with the GAGAL stamp) and D (RunResult). D's background must be the covering `cg_lose.jpg` with no students, as before.
  6. `project_manage(op="stop")`. Never press *Kembali ke Menu* here: it runs grade progression.

- [ ] **Step 12: Commit.**

```bash
git checkout -- Assets/Audio/default_bus_layout.tres 2>/dev/null
git add Scripts/EndGame/EndCutscene.gd Scripts/EndGame/RunResult.gd Scripts/EndGame/WinLineup.gd Scenes/EndGame/EndCutscene.tscn Scenes/EndGame/RunResult.tscn tests/test_end_cutscene.gd tests/test_run_result.gd tests/test_win_lineup.gd
git commit -m "feat(endgame): open RunResult on the same win stage EndCutscene shows" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Full suite, then the docs

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (a new entry at the top)
- Modify: `CLAUDE.md` (the dead-scene line and the suite counts)

**Interfaces:**
- Consumes: Tasks 1–4, all committed.
- Produces: a green full suite and the history entry.

- [ ] **Step 1: Run the full suite.**
  1. `scene_open("res://Scenes/MainMenu/main_menu.tscn")`. Some suites assume the main scene is open.
  2. `test_run()` with no suite.
  3. Record the suite and test totals from the summary.
  - Expected: 0 failures. A single theme assertion failing may just be suite ordering: re-run that suite alone before believing it.
  - Anything failing that this plan did not touch: report it to the user, and do not fix it silently.
  - A full run can drop the bridge afterwards. If `session_manage(op="list")` shows `count=0`, run `bash ~/godot-restart.sh`.

- [ ] **Step 2: Clean up the files a full run rewrites.**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git status --short
git checkout -- Assets/Audio/default_bus_layout.tres 2>/dev/null
git diff --stat -- Assets/Theme/kejartes_theme.tres
```

  `kejartes_theme.tres` should be unchanged since Task 1's bake. If it differs, read the diff. Commit it only if it adds a type this plan introduced.

- [ ] **Step 3: Add the changelog entry.** Insert under the file's intro, above `## 2026-09-10 — LombaMenari note camera`:

```markdown
## 2026-09-11 — StatCheck on StudentCard's paper; one win stage for EndCutscene and RunResult

Spec `docs/superpowers/specs/2026-09-11-statcheck-paper-and-shared-win-stage-design.md`,
plan `docs/superpowers/plans/2026-09-11-statcheck-paper-and-shared-win-stage.md`.

**StatCheck.** Each student's page is StudentCard's own paper now:
`card_bg.png` with its `PaperShadow`. It is authored at native 1080×1920 inside
`StatCheckCard.tscn` and scaled 0.757, so the 1321px sheet fills the 1000px
card. The photo sits in the frame printed on the paper, and the name sits alone
on the printed brown plate in the new `PlateNameLabel` (Boohong 96, cream). The
three rows wear the `StudentCard/stat_*.png` icons at StudentCard's proportions
(128 icon, 68 bar). The bio lines are gone.

The paper in `card_bg.png` is only x 52..1045, y 238..1558 of the texture. A
test maps that sheet through the paper's transform and fails if it leaves the
card or underfills it. Another re-measures every roster name against the
plate at the real font size.

**RunResult.** EndCutscene's painting, letterbox bars and posed roster moved
into `Scenes/EndGame/WinStage.tscn` (`WinStage.gd`). EndCutscene and RunResult
both instance it and dress it with the same line.

RunResult used to cover the screen with the painting alone, cropped to
1440×1920 with no students, so the blur hand-off jumped. Now its first frame is
EndCutscene's last. The letterbox put RunResult's dark title on the navy bar,
so the title moved to `ResultHeroLabel`.

WinStage's root is a bare anchor that sizes its children in `dress()`, per the
authoring guide's rule for instanced roots.
```

- [ ] **Step 4: Update `CLAUDE.md`.**
  - Replace `The real win screen is \`EndCutscene\`'s win branch. Safe to delete.` with `The real win screen is \`WinStage.tscn\`, which EndCutscene shows and RunResult keeps blurred behind its report. Safe to delete.`
  - Replace `91 suites, 1253 tests (2026-09-10)` with the totals from Step 1, dated `2026-09-11`.

- [ ] **Step 5: Commit.**

```bash
git add docs/superpowers/CHANGELOG.md CLAUDE.md
git commit -m "docs: changelog and guide for StatCheck's paper and the shared win stage" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

Do not push. Pushing waits for the user to ask, after this green full run.
