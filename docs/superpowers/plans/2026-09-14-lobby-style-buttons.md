# Lobby-style Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline, in one session (the Godot bridge takes one client). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Every framed action button wears the Lobby's STUDENT/JADWAL look, except StudentCard's cream buttons and StudentList's red/green status badges.

**Architecture:**
- The look is one recipe: `_add_button_variation()` with `brand_primary_light`, `brand_primary_dark`, `outline_card` and `text_on_brand`.
- A new `_add_lobby_button()` applies it to every action role. The generated M/L size steps follow their base.
- New variations keep the two exceptions' current look, and their scene nodes are repointed to them.

**Spec:** `docs/superpowers/specs/2026-09-14-lobby-style-buttons-design.md`

## Global Constraints

- **Worktree:** `C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\weekly-results`, branch `feat/lobby-style-buttons`. Run git as plain, separate commands.
- **Editor:** this worktree's editor, session `weekly-results@e9a1` now; re-read the id after every restart, written below as `<SESSION>`. Restart it with the PID-guarded kill and detached relaunch used all session (match the command line `*worktrees/weekly-results*`, stop on a "(*)" window title).
- **No `theme_override_*` in scenes.** `.tscn` edits go through the editor only: `scene_open` → `batch_execute` `set_property` → `scene_save`. After each save, `git diff HEAD -- '*.gd'` must show only intended files.
- **Rebake after any ThemeFactory change** by running `test_run(suite="theme_rebake")`, then restart the editor before any scene work.
- **Test suites:** `@tool`, override `suite_name()`, no coroutines, and extend `McpTestSuiteCompat` if they use `assert_not_null`.
- **Script documentation:** a `##` header on every script and a `##` line on every `@export`.
- Button sizes, text and icons don't change. `Balance.gd` is untouched.

---

### Task 1: The Lobby recipe in the theme

**Files:** modify `Scripts/Design/ThemeFactory.gd`, `tests/test_theme_factory.gd` and `tests/test_button_geometry.gd`; create `tests/test_lobby_style_buttons.gd`; rebake `Assets/Theme/kejartes_theme.tres`.

**Produces:** `_add_lobby_button(theme, tokens, name)` and the variations `StudentCardSecondaryButton`, `StudentCardSecondaryButtonL`, `RosterStatusBelum` and `RosterStatusSudah`.

- [ ] **Step 1: the failing suite.** Write `tests/test_lobby_style_buttons.gd`:

```gdscript
@tool
extends McpTestSuite

## Lobby-style buttons (2026-09-14 spec): every framed action button wears
## the Lobby's STUDENT/JADWAL look -- brand_primary_light fill,
## brand_primary_dark bevel, outline_card rim, text_on_brand -- except
## StudentCard's cream secondary buttons and StudentList's red/green status
## badges, which keep theirs.

## The restyled roles, with every generated size step.
const LOBBY_LOOK := [
	"PrimaryButton", "PrimaryButtonM", "PrimaryButtonL",
	"SecondaryButton", "SecondaryButtonM", "SecondaryButtonL",
	"DangerButton", "DangerButtonM", "DangerButtonL",
	"SuccessButton", "SuccessButtonL",
	"MainMenuButton", "ShopShelfButton", "ResultButton",
	"LobbyCtaButton", "LobbyNavTile",
]

const _STUDENT_CARD := "res://Scenes/StudentCard/student_card.tscn"
const _ROSTER_CARD := "res://Scenes/StudentList/RosterCard.tscn"

var _tokens: DesignTokens
var _theme: Theme


func suite_name() -> String:
	return "lobby_style_buttons"


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


func _flat(state: String, name: String) -> StyleBoxFlat:
	return _theme.get_stylebox(state, name) as StyleBoxFlat


## A variation's resting fill, or transparent when it has no flat box.
func _fill(name: String) -> Color:
	var sb := _flat("normal", name)
	return sb.bg_color if sb != null else Color(0, 0, 0, 0)


func test_every_action_button_wears_the_lobby_fill_rim_and_text() -> void:
	for name in LOBBY_LOOK:
		var sb := _flat("normal", name)
		assert_true(sb != null, name + "/normal is a flat box like the Lobby's")
		if sb == null:
			continue
		assert_eq(sb.bg_color, _tokens.brand_primary_light, name + " fill")
		assert_eq(sb.border_color, _tokens.outline_card, name + " rim")
		assert_eq(sb.corner_radius_top_left, _tokens.radius_button, name + " corner")
		assert_eq(_theme.get_color("font_color", name), _tokens.text_on_brand, name + " text")


func test_every_action_button_sinks_the_way_the_lobby_does() -> void:
	for name in LOBBY_LOOK:
		var pressed := _flat("pressed", name)
		assert_true(pressed != null and pressed.bg_color == _tokens.brand_primary_dark,
			name + " pressed flips to the darker bevel, as the Lobby's does")


func test_student_card_keeps_its_cream_secondary() -> void:
	assert_eq(_fill("StudentCardSecondaryButtonL"), _tokens.surface_card, "cream fill, as before")
	var sb := _flat("normal", "StudentCardSecondaryButtonL")
	assert_true(sb != null and sb.border_color == _tokens.brand_primary, "brown rim, as before")
	assert_eq(_theme.get_color("font_color", "StudentCardSecondaryButtonL"),
		_tokens.brand_primary, "brown text, as before")
	assert_eq(_theme.get_font_size("font_size", "StudentCardSecondaryButtonL"),
		_tokens.font_h1, "the L step")


func test_status_badges_keep_their_red_and_green() -> void:
	assert_eq(_fill("RosterStatusBelum"), _tokens.state_danger.lightened(0.18), "BELUM stays red")
	assert_eq(_fill("RosterStatusSudah"), _tokens.state_success.lightened(0.18), "SUDAH stays green")


## The icon-only main menu buttons and Weekly Results' half-row buttons
## keep the fit they were laid out for; only the surface changed.
func test_main_menu_and_weekly_results_keep_their_fit() -> void:
	var mm := _flat("normal", "MainMenuButton")
	assert_true(mm != null and mm.content_margin_left == 20.0 and mm.content_margin_top == 0.0,
		"MainMenuButton keeps its tight icon margins")
	assert_eq(_theme.get_font_size("font_size", "MainMenuButton"), 80, "MainMenuButton text size")
	var rb := _flat("normal", "ResultButton")
	assert_true(rb != null and rb.content_margin_left == 24.0,
		"ResultButton keeps its 24 px sides so SELANJUTNYA fits")
	assert_eq(_theme.get_font_size("font_size", "ResultButton"), _tokens.day_stat_size,
		"ResultButton keeps the card's 52 px text")


func test_student_card_points_its_cream_buttons_at_its_own_style() -> void:
	var src := FileAccess.get_file_as_string(_STUDENT_CARD)
	assert_false(src.contains('&"SecondaryButtonL"'),
		"no StudentCard button takes the restyled secondary")
	assert_eq(src.count('&"StudentCardSecondaryButtonL"'), 8,
		"six Batal and the two page arrows")
	assert_eq(src.count('&"PrimaryButtonL"'), 7,
		"six Aprove and Belajar already wear the Lobby look")


func test_roster_badges_use_the_status_styles() -> void:
	var src := FileAccess.get_file_as_string(_ROSTER_CARD)
	assert_contains(src, 'theme_type_variation = &"RosterStatusBelum"')
	assert_contains(src, 'theme_type_variation = &"RosterStatusSudah"')
	assert_false(src.contains("DangerButton") or src.contains("SuccessButton"),
		"the badges left the action styles")


func test_only_student_card_uses_its_style() -> void:
	var scenes: Array = []
	_scene_files("res://Scenes", scenes)
	for path in scenes:
		if path == _STUDENT_CARD:
			continue
		assert_false(FileAccess.get_file_as_string(path).contains("StudentCardSecondaryButton"),
			path + " must not borrow StudentCard's exception")


func _scene_files(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scene_files(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
```

- [ ] **Step 2: watch it fail.** `filesystem_manage(op="scan")`, then `test_run(suite="lobby_style_buttons", session_id="<SESSION>")`. Expected: the colour, exception and scene tests FAIL.

- [ ] **Step 3: ThemeFactory.** Make four `script_patch` edits.
  1. In `_build_buttons`, replace the four `_add_button_variation(...)` calls for `PrimaryButton`, `SecondaryButton`, `DangerButton` and `SuccessButton`, together with the StudentCard APPROVE comment, with:
     ```gdscript
     	# The Lobby's STUDENT/JADWAL look (2026-09-14 lobby-style-buttons spec):
     	# every framed action button wears it, whatever its role name says.
     	for role in ["PrimaryButton", "SecondaryButton", "DangerButton", "SuccessButton"]:
     		_add_lobby_button(theme, tokens, role)

     	# StudentCard keeps the cream secondary look it had before that pass...
     	_add_button_variation(theme, tokens, "StudentCardSecondaryButton",
     		tokens.surface_card, tokens.surface_sunken,
     		tokens.brand_primary, tokens.brand_primary)

     	# ...and StudentList's BELUM/SUDAH badges keep their colour, which is the
     	# information they carry.
     	_add_button_variation(theme, tokens, "RosterStatusBelum",
     		tokens.state_danger.lightened(0.18), tokens.state_danger.darkened(0.24),
     		tokens.outline_card, tokens.text_on_brand)
     	_add_button_variation(theme, tokens, "RosterStatusSudah",
     		tokens.state_success.lightened(0.18), tokens.state_success.darkened(0.24),
     		tokens.outline_card, tokens.text_on_brand)
     ```
  2. Switch the `LobbyNavTile` and `LobbyCtaButton` builders to `_add_lobby_button(theme, tokens, "…")`, keeping their constants. Then add the line `_add_size_step(theme, tokens, "StudentCardSecondaryButton", "L", tokens.font_h1, tokens.btn_pad_v_l)` after the L loop.
  3. Replace `_build_shop_shelf_button`, `_build_result_button` and `_build_main_menu_button` with:
     ```gdscript
     ## Koperasi's shelf-category button (e.g. "KEBUTUHAN SEKOLAH"), in the Lobby
     ## look since the 2026-09-14 lobby-style-buttons pass (it was a flat brown
     ## tab with a gold hover). Keeps its 20/10 padding so the shelf row fits.
     static func _build_shop_shelf_button(theme: Theme, tokens: DesignTokens) -> void:
     	_add_lobby_button(theme, tokens, "ShopShelfButton")
     	_set_content_margins(theme, "ShopShelfButton", 20, 10)


     ## Weekly Results' Logs and Selanjutnya, in the Lobby look (2026-09-14
     ## lobby-style-buttons spec; the cream card_bg.png art is retired). Keeps
     ## its 24 px sides and the card's 52 px text, so SELANJUTNYA still fits the
     ## 436 px half-row it was laid out for.
     static func _build_result_button(theme: Theme, tokens: DesignTokens) -> void:
     	_add_lobby_button(theme, tokens, "ResultButton")
     	_set_content_margins(theme, "ResultButton", 24, tokens.btn_pad_v_s)
     	theme.set_font_size("font_size", "ResultButton", tokens.day_stat_size)


     ## The main menu's icon buttons, in the Lobby look (2026-09-14
     ## lobby-style-buttons spec; the painted gold menu_button.png is retired).
     ## Icon-only boxes, so the sides stay tight and the vertical padding zero --
     ## the Lobby recipe's space_lg sides would squeeze the icon.
     static func _build_main_menu_button(theme: Theme, tokens: DesignTokens) -> void:
     	_add_lobby_button(theme, tokens, "MainMenuButton")
     	_set_content_margins(theme, "MainMenuButton", 20, 0)
     	theme.set_font_size("font_size", "MainMenuButton", 80)
     ```
  4. Add these two helpers just above `static func _add_button_variation(`:
     ```gdscript
     ## The Lobby's STUDENT / JADWAL button: brand_primary_light over the darker
     ## bevel, the cream card rim and cream display text. Every framed action
     ## button wears it since the 2026-09-14 lobby-style-buttons pass; what
     ## differs between them is size, text and icon, never the surface.
     static func _add_lobby_button(theme: Theme, tokens: DesignTokens, name: String) -> void:
     	_add_button_variation(theme, tokens, name,
     		tokens.brand_primary_light, tokens.brand_primary_dark,
     		tokens.outline_card, tokens.text_on_brand)


     ## Re-pad every state of a flat button variation: `pad_h` on both sides,
     ## `pad_v` top and bottom.
     static func _set_content_margins(theme: Theme, name: String, pad_h: int, pad_v: int) -> void:
     	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
     		var sb := theme.get_stylebox(state, name) as StyleBoxFlat
     		sb.content_margin_left = pad_h
     		sb.content_margin_right = pad_h
     		sb.content_margin_top = pad_v
     		sb.content_margin_bottom = pad_v
     ```

- [ ] **Step 4: the pinned tests.**
  - **`test_theme_factory.gd`:**
    - In `test_main_menu_button_variation_exists_and_is_sized_for_the_mockup`, replace the `StyleBoxTexture` assertion and its comment with:
      ```gdscript
      	# Since the 2026-09-14 lobby-style-buttons pass it is the Lobby's flat box.
      	var normal := theme.get_stylebox("normal", "MainMenuButton") as StyleBoxFlat
      	assert_true(normal != null and normal.bg_color == tokens.brand_primary_light,
      		"MainMenuButton wears the Lobby's fill")
      ```
    - In `DISPLAY_ROSTER`, add `"StudentCardSecondaryButton", "StudentCardSecondaryButtonL", "RosterStatusBelum", "RosterStatusSudah",` with a `# 2026-09-14 lobby-style-buttons: the two kept looks.` comment.
  - **`test_button_geometry.gd`:**
    - Remove the `MainMenuButton` and `ResultButton` entries from `RADIUS_EXEMPT`.
    - Delete `test_result_button_draws_the_card_art` and `test_main_menu_button_uses_the_split_asset`.
    - Add `"StudentCardSecondaryButtonL": "l",` to `SIZE_STEPS` and `"StudentCardSecondaryButtonL": _tokens.btn_h_l,` to the natural-height targets.
    - In the comment above `test_no_button_is_authored_off_step`, drop "MainMenuButton's corner is painted into menu_button.png, and".

- [ ] **Step 5: green, rebake, restart.**
  1. Run `test_run(suite="theme_factory")`, `test_run(suite="button_geometry")` and `test_run(suite="theme_rebake")`.
  2. Check that `git diff -- Assets/Theme/kejartes_theme.tres` adds `StudentCardSecondaryButton`, `StudentCardSecondaryButtonL` and `RosterStatus*`, and that `MainMenuButton`, `ResultButton` and `ShopShelfButton` lose their `StyleBoxTexture`.
  3. Restart the editor.
  4. Run `test_run(suite="lobby_style_buttons")`. Expected: all tests PASS except the three scene tests, which Task 2 turns green.
  5. `button_geometry` now also checks MainMenuButton's authored heights. If the main menu's icon buttons are not on a size step, add a reasoned `HEIGHT_ALLOWED` entry ("icon-only square, sized by the menu mockup").

- [ ] **Step 6: commit** ThemeFactory, the three test files and the bake: `feat(theme): the Lobby look for every action button`.

### Task 2: Repoint the exceptions

**Files:** modify `Scenes/StudentCard/student_card.tscn`, `Scenes/StudentList/RosterCard.tscn`, `tests/test_student_card.gd`, `tests/test_student_list.gd`, `tests/test_confirm_pair_semantics.gd` and `tests/test_main_menu.gd`.

- [ ] **Step 1: StudentCard.** Run `scene_open` on `student_card.tscn`, then use `batch_execute` `set_property` to set `theme_type_variation` = `StudentCardSecondaryButtonL` on each of these, then `scene_save`:
  - `KertasMurid1..6/Batal`;
  - `NextButtonKanan`;
  - the other page arrow, the `SecondaryButtonL` node near line 1610.
- [ ] **Step 2: RosterCard.** Run `scene_open` on `RosterCard.tscn`, set `Belum` → `RosterStatusBelum` and `Sudah` → `RosterStatusSudah`, then `scene_save`. After both saves, `git diff HEAD -- '*.gd'` should list only files this plan touched.
- [ ] **Step 3: tests.**
  - `test_student_card.gd`: `"KertasMurid1/Batal": &"StudentCardSecondaryButtonL"`, with the comment noting that StudentCard keeps the pre-2026-09-14 cream secondary.
  - `test_student_list.gd` lines 173 and 177: `&"RosterStatusBelum"` and `&"RosterStatusSudah"`.
  - `test_confirm_pair_semantics.gd`:
    - Point the RosterCard badge test at the two new names.
    - Extend the header doc: since 2026-09-14 every action role wears the Lobby look, so the roles are kept as names (pairs still name Primary + Secondary, and the quit dialog still names Danger) while colour stays only on the status badges.
  - `test_main_menu.gd`: the message becomes "must keep the MainMenuButton variation", with "yellow" dropped.
- [ ] **Step 4:** run each of `test_run(suite=…)` `lobby_style_buttons`, `student_card`, `student_list`, `confirm_pair_semantics` and `main_menu`, and expect all PASS. Commit: `feat(lobby-buttons): StudentCard and the status badges keep their looks`.

### Task 3: Retire the gold art, docs, full suite

- [ ] **Step 1:** grep `Scripts Scenes tests` for `menu_button.png`, expecting no hits. Then `git rm Assets/Images/StudentCard/menu_button.png` (plus its `.import`), remove it from DEBT.md's generated-art list, and run `filesystem_manage(op="scan")`.
- [ ] **Step 2: look at it.**
  1. Write a throwaway `_preview/ButtonsPreview.tscn`/`.gd` that instances `Scenes/Lobby/ShortenPanel.tscn` and `Scenes/Minigames/UI/QuitConfirmDialog.tscn` side by side. Have it save one frame to the scratchpad after 2 s.
  2. Run it with `project_run(mode="custom")` and check the frame shows brown Lobby buttons.
  3. Delete `_preview/`.
- [ ] **Step 3: docs.**
  - Add a CHANGELOG entry at the top summarising the recipe, the exceptions, the retired `menu_button.png`, and the retired pair rule.
  - Reword `style-guide.md` if it describes Secondary as cream, or Danger/Success as action colours: grep `docs/superpowers/design/style-guide.md` for `SecondaryButton|DangerButton|SuccessButton`.
- [ ] **Step 4: full suite.**
  1. Open `main_menu.tscn`, then run `test_run(session_id="<SESSION>")` and note the totals.
  2. Restore `kejartes_theme.tres` if it changed only by renumbered IDs, and `default_bus_layout.tres` if it changed at all.
  3. Update CLAUDE.md's test count.
  4. Restart the editor.
  5. Commit: `docs(lobby-buttons): changelog, style guide, retired menu art, suite count`.
