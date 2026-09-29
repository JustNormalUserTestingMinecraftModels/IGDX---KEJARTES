# Minigame Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the eight minigames one ×1.618 type ladder, one 48px edge, a one-row header plaque, cards sized to their controls, and fix bugs B1–B6 (spec `docs/superpowers/specs/2026-09-30-minigame-hierarchy-design.md`).

**Architecture:** One static `MinigameType` class holds the ladder (28/45/73/118). `ThemeFactory` gains the minigame variations that read it, then gets rebaked. `MinigameScoreHUD` grows into the plaque (score line + progress line), and `MinigameHeader` flattens to one row. Each game's scene then drops its hand-made styleboxes for those variations and re-spaces to the edge rule.

**Tech Stack:** Godot 4.6 GDScript, `.tscn` text scenes, the godot-ai MCP bridge (`test_run`, `script_patch`, `editor_manage`), `McpTestSuite` tests.

## Global Constraints

- Worktree `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/minigame-hierarchy`, branch `feat/minigame-hierarchy`, stacked on `feat/minigame-mobile-layout` (PR #155). Never touch the main checkout.
- Ladder: `T1 = 28`, `T2 = 45`, `T3 = 73`, `T4 = 118`, minigames only; the house tokens are unchanged.
- Edge: `screen_margin` 48 via each scene's `SafeAreaMargin`; header→content 28; field content→tray 72; card→controls under it 44.
- **Never add a `theme_override_*`** except layout-only `separation` / `margin_*` constants. No runtime visual construction (`test_viewport_editability` baselines only go down).
- `##` file header on every script and `##` on every `@export` (`test_script_documentation`).
- Tests are `@tool`, and no test is a coroutine.
- UI text Indonesian, KBBI. New copy: `Capai %d poin`, tool names `Pensil`, `Canting`, `Pewarna`, `Kompor`.
- `Balance.gd` untouched. New numbers are named `const`s or `@export`s in their owning script.
- Commits: Conventional Commits with a scope, message via `git commit -F <file>`, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

### Editor procedure (controller only; referenced as **RUN**)

Files are edited only while the worktree editor is **closed**. To run suites:

1. Seed once (Task 0), then launch detached from PowerShell:
   `Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`" --path `"<worktree>`" -e"; CurrentDirectory = "<worktree>" }`
2. `session_manage(op="list")` until the `minigame-hierarchy@…` session is `ready`; pass its `session_id` on **every** godot-ai call.
3. No-op `script_patch` each `.gd` changed since the last RUN (a reload error 43 is benign), then `filesystem_manage(op="scan")`.
4. `test_run(suite=…, session_id=…)` for the named suites.
5. Quit: `editor_manage(op="quit")`, or `Stop-Process` its PID after checking that its CommandLine contains the worktree path.
6. `git checkout -- Assets/Audio/default_bus_layout.tres` and any `*.png.import` the boot rewrote; the diff must hold only this task's files.

**Rebake** (Task 1 only): during a RUN, `test_run(suite="theme_rebake")` alone, then quit and relaunch before any other suite, and diff the bake: only the new and retuned variations may change.

---

### Task 0: Environment and baseline

- [ ] **Step 1:** Seed `.godot`: copy `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main checkout's `.godot/` into the worktree's `.godot/`.
- [ ] **Step 2: RUN** the suites `minigame_header minigame_score_hud minigame_typography minigame_layout minigame_layout_kit minigame_kit kalkulator button_roles_phase3 theme_factory light_ground_text minigame_card_shadows minigame_art badminton_visuals tall_screen_layout viewport_editability script_documentation`, and record their pass counts as the baseline. Any red here predates this work: note it and do not fix it in this plan.

### Task 1: Type ladder and theme kit

**Files:**
- Create: `Scripts/Design/MinigameType.gd`, `tests/test_minigame_hierarchy.gd`
- Modify: `Scripts/Design/ThemeFactory.gd` (`_build_minigame_typography`, `_build_minigame_hud`, `_build_minigame_layout`, `_build_minigame_kit`, a new `_build_minigame_hierarchy`)
- Modify tests: `tests/test_minigame_typography.gd` (VARIATIONS), `tests/test_minigame_layout_kit.gd:58-59`, `tests/test_theme_factory.gd` (declared list ~L31, `DISPLAY_ROSTER`)
- Regenerate: `Assets/Theme/kejartes_theme.tres`

**Interfaces produced:** `MinigameType.T1..T4`, `MinigameType.LADDER`; the variations `MinigameTargetLabel`, `MinigameTimerLabel`, `MinigameToolNameLabel`, `MinigameKeyLabel`, `MinigameLcdLabel`, `MinigameChoiceButtonCorrect`, `MinigameChoiceButtonWrong`, `MinigameCtaButton`, `MinigameSecondaryButton`, `WoodNavArrow`, `MinigameAnswerCard`, `MinigameCardLock`, `MinigameBadgePanel`, `MinigameToolCard`, `MinigameToolRing`; `ThemeFactory.MINIGAME_LCD_INK`.

- [ ] **Step 1: Write the failing tests.** Create `tests/test_minigame_hierarchy.gd`:

```gdscript
@tool
extends McpTestSuite

## Pins the 2026-09-30 minigame hierarchy pass (spec
## docs/superpowers/specs/2026-09-30-minigame-hierarchy-design.md): the x1.618
## minigame type ladder, the one-row plaque, the 48 px edge and 72 px tray gap,
## cards sized to their controls, and bugs B1-B6. Must be @tool; no test here
## may be a coroutine (the runner never awaits).

const LayoutFrame := preload("res://tests/layout_frame.gd")
const SoalFit := preload("res://Scripts/Minigames/Akademis/SoalFit.gd")
const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "minigame_hierarchy"


# ---------------------------------------------------------------- ladder

func test_the_ladder_steps_by_the_golden_ratio() -> void:
	assert_eq(MinigameType.LADDER, [28, 45, 73, 118], "the four rungs")
	for i in range(1, MinigameType.LADDER.size()):
		var r := float(MinigameType.LADDER[i]) / float(MinigameType.LADDER[i - 1])
		assert_true(r >= 1.60 and r <= 1.64, "rung %d steps x%.3f" % [i, r])


## Every text role in spec 3, with its rung.
func _role_sizes() -> Dictionary:
	return {
		"MinigameQuestionLabel": MinigameType.T3, "MinigameHudValue": MinigameType.T3,
		"MinigameKeyLabel": MinigameType.T3, "MinigameLcdLabel": MinigameType.T4,
		"MinigameChoiceButton": MinigameType.T2, "MinigameChoiceButtonCorrect": MinigameType.T2,
		"MinigameChoiceButtonWrong": MinigameType.T2, "MinigameCtaButton": MinigameType.T2,
		"MinigameSecondaryButton": MinigameType.T2, "MinigameTimerLabel": MinigameType.T2,
		"MinigameToolNameLabel": MinigameType.T2, "MinigameHintLabel": MinigameType.T1,
		"MinigameTargetLabel": MinigameType.T1, "MinigameProgressLabel": MinigameType.T1,
		"MinigamePlankLabel": MinigameType.T1, "MinigameBadgeLabel": MinigameType.T1,
	}


func test_every_role_is_baked_on_its_rung() -> void:
	var theme := load(THEME_PATH) as Theme
	var sizes := _role_sizes()
	for name: String in sizes:
		assert_true(theme.has_font_size("font_size", name), name + " carries a size")
		assert_eq(theme.get_font_size("font_size", name), sizes[name], name + " rung")


func test_the_state_flashes_keep_their_colour_when_disabled() -> void:
	var theme := load(THEME_PATH) as Theme
	for name in ["MinigameChoiceButtonCorrect", "MinigameChoiceButtonWrong"]:
		var rest := theme.get_stylebox("normal", name) as StyleBoxFlat
		var off := theme.get_stylebox("disabled", name) as StyleBoxFlat
		assert_true(rest != null and off != null, name + " has flat boxes")
		assert_true(rest.bg_color.is_equal_approx(off.bg_color),
			name + ": an answered (disabled) button still shows the flash")


func test_the_new_panels_exist() -> void:
	var theme := load(THEME_PATH) as Theme
	for name in ["MinigameAnswerCard", "MinigameCardLock", "MinigameBadgePanel",
			"MinigameToolCard", "MinigameToolRing"]:
		assert_true(theme.has_stylebox("panel", name), name + " is baked")
```

- [ ] **Step 2:** Update `tests/test_minigame_typography.gd` VARIATIONS to `{"MinigameQuestionLabel": 73, "MinigameChoiceButton": 45, "MinigameMetaLabel": 36, "MinigameBadgeLabel": 28, "MinigameOverlayLabel": 36, "MinigameWheelHeaderWarm": 36, "MinigameWheelHeaderCool": 36}`, and rewrite its header `##` to say the question, choice and badge moved to the ×1.618 ladder (`MinigameType`) on 2026-09-30. In `tests/test_minigame_layout_kit.gd:58-59`, assert `MinigameHintLabel == MinigameType.T1` and `MinigameHowToLabel == tokens.font_title`. In `tests/test_theme_factory.gd`, add the fifteen new variation names to the declared list (~L31-33), and add these to `DISPLAY_ROSTER` under a `# 2026-09-30 minigame hierarchy` comment: `"MinigameTargetLabel", "MinigameTimerLabel", "MinigameToolNameLabel", "MinigameKeyLabel", "MinigameLcdLabel", "MinigameChoiceButtonCorrect", "MinigameChoiceButtonWrong", "MinigameCtaButton", "MinigameSecondaryButton", "WoodNavArrow"`.

- [ ] **Step 3: RUN** `minigame_hierarchy`. Expected: FAIL (the `MinigameType` class is missing). Commit the tests: `test(minigames): pin the x1.618 minigame type ladder`.

- [ ] **Step 4: Implement.** Create `Scripts/Design/MinigameType.gd`:

```gdscript
class_name MinigameType
extends RefCounted

## The minigames' type ladder (spec 2026-09-30 minigame hierarchy, 3): four
## rungs, each x1.618 (the golden ratio) of the one below, rounded, starting
## at the house body floor (DesignTokens.font_body_size, 28). Minigames only;
## every other screen keeps the house tokens. ThemeFactory's minigame
## variations and the games' fit exports read these, so each number is
## written once. Constants only; never instanced.

## Hint, captions, planks, badges: the quietest rung.
const T1 := 28
## Answers, buttons, tool names, timer seconds.
const T2 := 45
## Questions, the plaque's score, calculator keys.
const T3 := 73
## Sums and the calculator display.
const T4 := 118
## The four rungs, smallest first.
const LADDER: Array[int] = [T1, T2, T3, T4]
```

In `ThemeFactory.gd`:
- `_build_minigame_typography`:
  - `MinigameQuestionLabel` size → `MinigameType.T3`;
  - `MinigameBadgeLabel` size → `MinigameType.T1`;
  - after `_add_button_variation(... "MinigameChoiceButton" ...)`, add `theme.set_font_size("font_size", "MinigameChoiceButton", MinigameType.T2)`;
  - point the block's `##` at the new ladder.
- `_build_minigame_hud`: `MinigameHudValue` → `MinigameType.T3`; `MinigamePlankLabel` → `MinigameType.T1`.
- `_build_minigame_layout`:
  - `MinigameProgressLabel` → `MinigameType.T1`;
  - split the Hint/HowTo loop so `MinigameHintLabel` gets `MinigameType.T1` and `MinigameHowToLabel` keeps `tokens.font_title`.
- `_build_minigame_kit`: add a last line `_build_minigame_hierarchy(theme, tokens)`.
- After `_minigame_hud_icon_focus_box`, add:

```gdscript
# ------------------------------------------------ minigame hierarchy

## The 2026-09-30 hierarchy pass (spec
## docs/superpowers/specs/2026-09-30-minigame-hierarchy-design.md, 3 and 5).
## Every size is a MinigameType rung.
##   MinigameTargetLabel      the plaque's "/ 3", cream, T1.
##   MinigameTimerLabel       whole seconds inside the timer ring, T2.
##   MinigameToolNameLabel    a BuatBatik tool's name, T2.
##   MinigameKeyLabel         a calculator key's digit, T3.
##   MinigameLcdLabel         the calculator display, T4, LCD ink.
##   MinigameChoiceButtonCorrect / Wrong  an answer's flash; disabled keeps it.
##   MinigameCtaButton        a tray's one main action (mint), T2.
##   MinigameSecondaryButton  a tray's neutral action (brown), T2.
##   WoodNavArrow             Menjodohkan's reel arrows.
##   MinigameAnswerCard       Menjodohkan's answer card.
##   MinigameCardLock         the veil over a locked card.
##   MinigameBadgePanel       QuestionCard's status badge.
##   MinigameToolCard         a BuatBatik tool tile, cream and lipped.
##   MinigameToolRing         the gold ring round the next tool.

## How much darker than its face a right/wrong flash's lip is.
const MINIGAME_STATE_LIP_DARKEN := 0.3
## The locked-card veil's opacity over surface_overlay.
const MINIGAME_LOCK_VEIL_ALPHA := 0.8
## The ring's stroke round the next BuatBatik tool, px.
const MINIGAME_TOOL_RING_WIDTH := 8
## The calculator display's dark LCD ink (was Kalkulator.layar_color).
const MINIGAME_LCD_INK := Color(0.13, 0.16, 0.12, 1.0)


static func _build_minigame_hierarchy(theme: Theme, tokens: DesignTokens) -> void:
	_add_minigame_display_label(theme, tokens, "MinigameTargetLabel",
		tokens.text_on_brand, MinigameType.T1)
	_add_minigame_display_label(theme, tokens, "MinigameTimerLabel",
		tokens.text_on_brand, MinigameType.T2)
	theme.set_constant("outline_size", "MinigameTimerLabel", tokens.lipped_label_outline)
	theme.set_color("font_outline_color", "MinigameTimerLabel", tokens.brand_primary_dark)
	_add_minigame_display_label(theme, tokens, "MinigameToolNameLabel",
		tokens.text_primary, MinigameType.T2)
	_add_minigame_display_label(theme, tokens, "MinigameKeyLabel",
		tokens.text_on_brand, MinigameType.T3)
	_add_minigame_display_label(theme, tokens, "MinigameLcdLabel",
		MINIGAME_LCD_INK, MinigameType.T4)
	theme.set_constant("outline_size", "MinigameLcdLabel", 0)
	_build_minigame_hierarchy_buttons(theme, tokens)
	_build_minigame_hierarchy_panels(theme, tokens)


## The flash, tray and arrow buttons, all lipped via _add_button_variation.
static func _build_minigame_hierarchy_buttons(theme: Theme, tokens: DesignTokens) -> void:
	for pair in [["MinigameChoiceButtonCorrect", tokens.state_success],
			["MinigameChoiceButtonWrong", tokens.state_danger]]:
		var name: String = pair[0]
		var face: Color = pair[1]
		_add_button_variation(theme, tokens, name, face,
			face.darkened(MINIGAME_STATE_LIP_DARKEN))
		theme.set_font_size("font_size", name, MinigameType.T2)
		# An answered button is disabled, and the flash must stay on it.
		theme.set_stylebox("disabled", name, theme.get_stylebox("normal", name))
		theme.set_color("font_disabled_color", name, theme.get_color("font_color", name))
	_add_button_variation(theme, tokens, "MinigameCtaButton",
		tokens.accent_mint, tokens.accent_mint_lip)
	theme.set_font_size("font_size", "MinigameCtaButton", MinigameType.T2)
	_add_button_variation(theme, tokens, "MinigameSecondaryButton",
		tokens.brand_primary_light, tokens.brand_primary_dark)
	theme.set_font_size("font_size", "MinigameSecondaryButton", MinigameType.T2)
	_add_button_variation(theme, tokens, "WoodNavArrow",
		tokens.brand_primary_light, tokens.brand_primary_dark, tokens.radius_md)


## The answer card, lock veil, badge, tool tile and tool ring.
static func _build_minigame_hierarchy_panels(theme: Theme, tokens: DesignTokens) -> void:
	var answer := StyleBoxFlat.new()
	answer.bg_color = tokens.surface_card
	answer.set_corner_radius_all(tokens.radius_lg)
	answer.set_border_width_all(int(tokens.outline_width / 2.0))
	answer.border_color = tokens.button_cream_lip
	answer.set_content_margin_all(tokens.space_md)
	var lifted: Color = tokens.shadow_color
	lifted.a = minf(1.0, tokens.shadow_color.a + MINIGAME_CARD_SHADOW_ALPHA_BOOST)
	answer.shadow_color = lifted
	answer.shadow_size = tokens.shadow_size
	answer.shadow_offset = tokens.shadow_offset
	_add_minigame_panel(theme, "MinigameAnswerCard", answer)

	var veil := StyleBoxFlat.new()
	veil.bg_color = Color(tokens.surface_overlay, MINIGAME_LOCK_VEIL_ALPHA)
	veil.set_corner_radius_all(tokens.radius_md)
	_add_minigame_panel(theme, "MinigameCardLock", veil)

	var badge := StyleBoxFlat.new()
	badge.bg_color = tokens.brand_primary
	badge.set_corner_radius_all(tokens.radius_sm)
	badge.content_margin_left = tokens.space_sm
	badge.content_margin_right = tokens.space_sm
	badge.content_margin_top = tokens.space_xs
	badge.content_margin_bottom = tokens.space_xs
	_add_minigame_panel(theme, "MinigameBadgePanel", badge)

	_add_minigame_panel(theme, "MinigameToolCard", LippedBox.make(
		tokens.button_cream, tokens.button_cream_lip, tokens.lip_height, tokens.radius_md, 0.0))

	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(MINIGAME_TOOL_RING_WIDTH)
	ring.border_color = tokens.currency_gold
	ring.set_corner_radius_all(tokens.radius_md)
	_add_minigame_panel(theme, "MinigameToolRing", ring)


## A display-face Label variation in `color` at `font_size`.
static func _add_minigame_display_label(theme: Theme, tokens: DesignTokens, name: String,
		color: Color, font_size: int) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Label")
	_set_minigame_display_text(theme, tokens, name, color, font_size)
```

- [ ] **Step 5: RUN** with a **Rebake** first, then `minigame_hierarchy theme_factory minigame_typography minigame_layout_kit minigame_kit clean_code`. Expected: all PASS.
- [ ] **Step 6: Commit** `feat(minigames): x1.618 type ladder and the hierarchy kit variations`, with `MinigameType.gd`, `ThemeFactory.gd`, the tests and the bake.

### Task 2: One-row header and the plaque

**Files:** `Scenes/Minigames/UI/MinigameScoreHUD.tscn`, `Scripts/Minigames/UI/MinigameScoreHUD.gd`, `Scenes/Minigames/UI/MinigameHeader.tscn`, `Scripts/Minigames/UI/MinigameHeader.gd`, `Scripts/Minigames/UI/BaseMinigame.gd:383`, `Scenes/Minigames/SeniBudaya/BuatBatik.tscn` (drop `segmented = true`); tests `test_minigame_header.gd`, `test_minigame_score_hud.gd`, `test_light_ground_text.gd` (`Panel/Row` → `Panel/Stack/Row`), `test_minigame_layout.gd:139-146` (drop the `segmented` assert), `test_minigame_hierarchy.gd`.

**Interfaces:**
- `MinigameScoreHUD` gains `set_progress(value: int, max_value: int, label: String)`, `set_value_row_visible(shown: bool)`, `set_progress_visible(shown: bool)`, `const SEGMENT_MAX := 10`, and `progress_bar`, `progress_label`, `ticks` members.
- `MinigameHeader` drops `timer_icon` and `segmented`; `set_time(left, total)` writes `%TimerLabel`.

- [ ] **Step 1: Failing tests.** Append to `test_minigame_hierarchy.gd`:

```gdscript
# ----------------------------------------------------------------- plaque

const HEADER := "res://Scenes/Minigames/UI/MinigameHeader.tscn"


func _header() -> MinigameHeader:
	var frame := track(LayoutFrame.stand_up(HEADER, Vector2(1080, 1920))) as Control
	return frame.get_child(0) as MinigameHeader


func test_the_header_is_one_row_with_the_bar_inside_the_plaque() -> void:
	var header := _header()
	assert_true(header.get_node_or_null("Stack") == null, "no second row")
	var hud := header.get_node("%ScoreHud") as MinigameScoreHUD
	assert_true(hud.get_node_or_null("Panel/Stack/ProgressLine/ProgressBar") != null,
		"the progress bar lives in the plaque")
	assert_eq((hud.get_node("Panel") as Control).theme_type_variation, &"MinigameHudPill")


func test_the_plaque_fits_the_strip() -> void:
	var header := _header()
	var plaque := (header.get_node("%ScoreHud") as Control).get_node("Panel") as Control
	assert_true(header.get_global_rect().encloses(plaque.get_global_rect()),
		"the plaque stays inside the one-row strip")


func test_the_timer_shows_whole_seconds_rounded_up() -> void:
	var header := _header()
	header.set_time(17.2, 30.0)
	assert_eq((header.get_node("%TimerLabel") as Label).text, "18")


func test_short_counts_draw_segments_and_long_ones_a_bar() -> void:
	var header := _header()
	var hud := header.get_node("%ScoreHud") as MinigameScoreHUD
	header.set_progress(1, 4, "Langkah 2/4")
	assert_eq(hud.ticks.segments, 4, "four steps, four cells")
	header.set_progress(3, 12, "Soal 4/12")
	assert_eq(hud.ticks.segments, 0, "past SEGMENT_MAX the bar is continuous")
	assert_eq(hud.progress_label.text, "Soal 4/12")


func test_hiding_the_score_keeps_the_bar() -> void:
	var header := _header()
	header.show_score = false
	var hud := header.get_node("%ScoreHud") as MinigameScoreHUD
	assert_false((hud.get_node("Panel/Stack/Row") as Control).visible, "score line hidden")
	assert_true(hud.progress_bar.is_visible_in_tree(), "the bar still shows")
```

In `test_minigame_header.gd`:
- `BOUND_NODES` gains `"%TimerLabel"`.
- `set_progress` / `segmented` tests read `(header.get_node("%ScoreHud") as MinigameScoreHUD).progress_bar/.progress_label/.ticks`; the segmented test becomes the ≤10 rule.
- The hidden-timer slot path becomes `"Row/TimerSlot"`.
- The icon test checks only `%PauseGlyph`.
- The hidden-score/progress test uses `set_value_row_visible` semantics.

In `test_minigame_score_hud.gd`, the node list uses `Panel/Stack/Row/...`.

- [ ] **Step 2: RUN** `minigame_hierarchy minigame_header minigame_score_hud`. Expected: FAIL. Commit the tests.

- [ ] **Step 3: Implement the plaque.** Rewrite `MinigameScoreHUD.tscn`:
  - keep the root, the `unique_id`s and the combo chip;
  - `Panel` gets `custom_minimum_size = Vector2(440, 0)` and `theme_type_variation = &"MinigameHudPill"`;
  - add `Panel/Stack` (VBoxContainer, `mouse_filter = 2`, `separation = 0`) holding `Row` (moved; `Icon`, `ValueLabel` on `MinigameHudValue`, `TargetLabel` on `MinigameTargetLabel`, `ComboChip` unchanged);
  - add `ProgressLine` (HBoxContainer, `separation = 16`, `mouse_filter = 2`) with:
    - `ProgressBar` (`custom_minimum_size = Vector2(0, 16)`, `size_flags_horizontal = 3`, `size_flags_vertical = 4`, `mouse_filter = 2`, `MinigameProgressBar`, `max_value = 1.0`, `show_percentage = false`), with its `Ticks` child (full rect, `ProgressTicks.gd` ext_resource `uid://rswrtc2lg4er`);
    - `ProgressLabel` (`MinigameProgressLabel`, `vertical_alignment = 1`).
  In `MinigameScoreHUD.gd`:
  - repoint the `@onready` paths to `Panel/Stack/Row/...`;
  - add `value_row`, `progress_line`, `progress_bar`, `progress_label` and `ticks`;
  - add `const SEGMENT_MAX := 10` with a `##`;
  - move the body of `MinigameHeader.set_progress` here, with `ticks.segments = max_value if max_value <= SEGMENT_MAX else 0`;
  - add the two visibility setters;
  - rewrite the header `##` (chrome is `MinigameHudPill`; it is the plaque).
- [ ] **Step 4: Implement the header.** Rewrite `MinigameHeader.tscn`:
  - root `custom_minimum_size = Vector2(0, 150)` and `offset_bottom = 150.0`;
  - a full-rect `Row` HBoxContainer directly under the root (same `unique_id` 576564000); `Stack`, `ProgressRow`, `TimerGlyph` and the `timer.svg` / ticks ext_resources go;
  - `PauseButton` and `TimerSlot` get `size_flags_vertical = 4`;
  - under `TimerButton` after `Ring`, add a full-rect `TimerLabel` (`unique_name_in_owner`, `MinigameTimerLabel`, `text = "0"`, centred both ways, `mouse_filter = 2`);
  - drop `timer_icon = …`.
  Rewrite `MinigameHeader.gd`:
  - remove the `timer_icon` and `segmented` exports and the `_timer_glyph`, `_progress_*` and `_ticks` refs; add `_timer_label`;
  - `set_progress` forwards to `_score_hud.set_progress`;
  - `set_time` also sets `_timer_label.text = str(ceili(maxf(0.0, left)))`;
  - `_apply_exports` calls `_score_hud.set_value_row_visible(show_score)` and `_score_hud.set_progress_visible(show_progress)`, and sets `_score_hud.visible = show_score or show_progress`;
  - rewrite the file `##` for the one-row strip.
  `BaseMinigame.gd:383`: `card.find_child("StatusBadge", true, false)`. `BuatBatik.tscn`: delete `segmented = true`.
- [ ] **Step 5: RUN** `minigame_hierarchy minigame_header minigame_score_hud light_ground_text minigame_layout tall_screen_layout script_documentation viewport_editability`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(minigames): one-row header with the score-and-progress plaque`.

### Task 3: Bingkai Kayu cards

**Files:**
- `Scenes/Minigames/Akademis/QuestionCard.tscn` and `AnswerCard.tscn`
- `Scripts/Minigames/Akademis/Password.gd:67` and `Variabel.gd:84` (`%SoalCard/Inner/VBox/TextLabel`)
- `Scripts/Minigames/Akademis/SoalFit.gd` (`FALLBACK_BOX`)
- tests: `test_minigame_art.gd:114-127`, `test_minigame_card_shadows.gd`, `test_minigame_hierarchy.gd`

- [ ] **Step 1: Failing tests.** Append:

```gdscript
# ------------------------------------------------------------------ cards

func test_the_cards_wear_the_kit_not_hand_made_boxes() -> void:
	for path in ["res://Scenes/Minigames/Akademis/QuestionCard.tscn",
			"res://Scenes/Minigames/Akademis/AnswerCard.tscn"]:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("theme_override_styles"), path + " has no stylebox override")
		assert_false(src.contains("StyleBoxFlat"), path + " authors no box")
	var q := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/QuestionCard.tscn")
	for v in ["MinigameCard", "MinigameCardInner", "MinigameBadgePanel", "MinigameCardLock"]:
		assert_true(q.contains('&"%s"' % v), "QuestionCard wears " + v)
	var a := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/AnswerCard.tscn")
	for v in ["MinigameAnswerCard", "MinigameCardLock"]:
		assert_true(a.contains('&"%s"' % v), "AnswerCard wears " + v)
```

Update `test_minigame_art.gd:118` to assert `theme_type_variation = &"MinigameCard"` (QuestionCard) / `&"MinigameAnswerCard"` (AnswerCard) in place of `corner_radius_top_left = 24`. In `test_minigame_card_shadows.gd`, set `card.theme = load("res://Assets/Theme/kejartes_theme.tres")` before reading the panel stylebox, if it does not already.
- [ ] **Step 2: RUN** `minigame_hierarchy minigame_art minigame_card_shadows`. Expected: FAIL. Commit the tests.
- [ ] **Step 3: Implement.** Change `QuestionCard.tscn`:
  - root `theme_type_variation = &"MinigameCard"`, with the override and all three sub_resources gone;
  - new child `Inner` (PanelContainer, `MinigameCardInner`) holds `CardBgTexture`, `VBox` (separation 28) and `StatusBadge` (`MinigameBadgePanel`, override gone);
  - `LockOverlay` stays a root child with `MinigameCardLock`.

  Change `AnswerCard.tscn`:
  - root `MinigameAnswerCard`, `LockOverlay` `MinigameCardLock`;
  - sub_resources gone.

  Update the two `@onready` paths. In `SoalFit.gd`, set `FALLBACK_BOX := Vector2(664, 200)` with a `##`: Menjodohkan's 736px card, less the frame's 8 and the inner 28 on each side.
- [ ] **Step 4: RUN** `minigame_hierarchy minigame_art minigame_card_shadows minigame_typography kalkulator`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(minigames): quiz cards wear the Bingkai Kayu kit`.

### Task 4: Edge rule and PilihanGanda (B1, B2)

**Files:** `Scripts/Minigames/UI/MinigameTray.gd` (`PADDING`), `Scenes/Minigames/Akademis/PilihanGanda.tscn`, `Scripts/Minigames/Akademis/PilihanGanda.gd`, `tests/test_minigame_layout_kit.gd` (padding pins, if any), `tests/test_minigame_hierarchy.gd`.

- [ ] **Step 1: Failing tests.** Append:

```gdscript
# ------------------------------------------------------ edge, PilihanGanda

const PILIHAN := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"
const EDGE := 48.0
const TRAY_GAP := 72.0


func test_pilihan_ganda_keeps_one_edge_and_the_tray_gap() -> void:
	for screen in [Vector2(1080, 1920), Vector2(1080, 2400)]:
		var root := (track(LayoutFrame.stand_up(PILIHAN, screen)) as Control).get_child(0)
		var card := (root.get_node("%SoalCard") as Control).get_global_rect()
		var tray := (root.get_node("%MinigameTray") as Control).get_global_rect()
		var grid := (root.get_node("%ChoicesGrid") as Control).get_global_rect()
		assert_true(absf(card.position.x - EDGE) <= 1.0, "card starts at the edge")
		assert_true(absf(screen.x - card.end.x - EDGE) <= 1.0, "card ends at the edge")
		assert_true(absf(grid.position.x - EDGE) <= 1.0, "answers start at the edge")
		assert_true(absf(tray.position.y - card.end.y - TRAY_GAP) <= 1.0,
			"72 px between the card and the tray at %s" % screen)


func test_a_short_question_fits_at_the_hero_rung() -> void:
	var label := Label.new()
	label.theme = load(THEME_PATH)
	label.theme_type_variation = &"MinigameQuestionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(912, 400)
	track(label)
	assert_eq(SoalFit.font_size(label, null,
		"Apa nama ibu kota negara Indonesia saat ini?", MinigameType.T3, MinigameType.T2),
		MinigameType.T3, "B1: a laid-out card fits the question at 73")


func test_pilihan_ganda_refits_once_laid_out_and_styles_through_the_theme() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_true(src.contains("resized.connect(_refit_question)"),
		"B1: the question refits after layout, not against a pre-layout size")
	assert_false(src.contains("add_theme_stylebox_override"), "B2: no stylebox overrides")
	for v in ["MinigameChoiceButtonCorrect", "MinigameChoiceButtonWrong"]:
		assert_true(src.contains(v), "the flash is the %s variation" % v)
	var scene := FileAccess.get_file_as_string(PILIHAN)
	assert_false(scene.contains("StyleBoxFlat"), "B2: the blue boxes are gone")
```

- [ ] **Step 2: RUN** `minigame_hierarchy`. Expected: these three tests FAIL. Commit.
- [ ] **Step 3: Implement.**
  - `MinigameTray.gd`: `const PADDING := Vector4i(0, 28, 0, 24)`, with its `##` updated (the SafeAreaMargin's 48 is the side edge).
  - `PilihanGanda.tscn`:
    - delete the three `StyleBoxFlat` sub_resources and the root's `answer_btn_*_style` lines;
    - `Column` separation 28;
    - `SoalCard` `size_flags_vertical = 3`;
    - delete `Spacer`; after `SoalCard` add `[node name="TrayGap" type="Control" parent="Safe/Column"]` with `custom_minimum_size = Vector2(0, 16)` and `mouse_filter = 2` (28 + 16 + 28 = 72);
    - `ChoicesGrid` `v_separation = 16`.
  - `PilihanGanda.gd`:
    - delete the exports `choice_btn_normal_texture`, `choice_btn_pressed_tint`, `choice_btn_disabled_tint`, `choice_btn_texture_margin`, `answer_btn_normal_style`, `answer_btn_correct_style`, `answer_btn_wrong_style`, `correct_color` and `wrong_color`, and `_make_btn_stylebox`;
    - `_apply_choice_btn_textures` becomes `_wire_choice_btn(btn)`, keeping only the pivot and press/release wiring;
    - `_flash_button_box(btn: Button, correct: bool)` sets `btn.theme_type_variation = &"MinigameChoiceButtonCorrect" if correct else &"MinigameChoiceButtonWrong"`, and every caller passes `true` or `false`;
    - `question_font_size` defaults to `MinigameType.T3` and `min_question_font_size` to `MinigameType.T2` (`##`s updated);
    - add `func _refit_question() -> void`, which re-applies `_fit_font_size(question_label.text)` when the label has text, and connect it once in `_ready` via `question_label.resized.connect(_refit_question)`;
    - the fit in the question swap stays.
- [ ] **Step 4: RUN** `minigame_hierarchy minigame_typography minigame_layout minigame_layout_kit minigame_art tall_screen_layout script_documentation`. Expected: PASS.
- [ ] **Step 5: Commit** `fix(pilihan-ganda): hero question fits after layout; cream answers through the theme`.

### Task 5: Calculator games (B3)

**Files:** `Scripts/Minigames/Akademis/Kalkulator.gd`, `Scenes/Minigames/Akademis/Kalkulator.tscn`, `KalkulatorKey.tscn`, `Password.tscn` / `Variabel.tscn`, `Password.gd` / `Variabel.gd`; tests `test_kalkulator.gd`, `test_button_roles_phase3.gd`, `test_minigame_hierarchy.gd`.

**Interface:** `Kalkulator.follow_width(target: Control) -> void` keeps `target.custom_minimum_size.x` equal to the calculator body's width.

- [ ] **Step 1: Failing tests.** Append:

```gdscript
# ------------------------------------------------------------- calculator

const KALK := "res://Scenes/Minigames/Akademis/Kalkulator.tscn"


func _kalk(zero: bool) -> Control:
	var frame := track(LayoutFrame.stand_up(KALK, Vector2(860, 1184))) as Control
	var k := frame.get_child(0) as Control
	k.set("show_zero_key", zero)
	LayoutFrame.settle(k)
	return k


## `r` as fractions of `body`'s rect.
func _frac(r: Rect2, body: Rect2) -> Rect2:
	return Rect2((r.position - body.position) / body.size, r.size / body.size)


func test_the_keypad_is_centred_on_the_painted_face() -> void:
	var k := _kalk(true)
	var body := (k.get_node("Body") as Control).get_global_rect()
	var keys := (k.get_node("Body/KeyGrid") as Control).get_global_rect().merge(
		(k.get_node("Body/ZeroRow") as Control).get_global_rect())
	var f := _frac(keys, body)
	var face: Rect2 = k.get("FACE_RECT")
	assert_true(absf(f.get_center().x - face.get_center().x) <= 0.01, "B3: centred on the face")
	assert_true(face.encloses(f), "B3: the keys stay on the face, off the rim")
	var glass: Rect2 = k.get("GLASS_RECT")
	var lcd := _frac((k.get_node("Body/Layar") as Control).get_global_rect(), body)
	assert_true(glass.grow(0.002).encloses(lcd), "B3: the display stays on the glass")


func test_without_zero_the_grid_takes_its_row() -> void:
	var k := _kalk(false)
	var body := (k.get_node("Body") as Control).get_global_rect()
	var grid := _frac((k.get_node("Body/KeyGrid") as Control).get_global_rect(), body)
	assert_true(absf(grid.end.y - float(k.get("KEYPAD_BOTTOM"))) <= 0.005,
		"Variabel's three rows reach the keypad's bottom")


func test_the_card_follows_the_calculator_width() -> void:
	var k := _kalk(true)
	var card := Control.new()
	track(card)
	k.call("follow_width", card)
	assert_eq(card.custom_minimum_size.x, (k.get_node("Body") as Control).size.x)


func test_the_calculator_games_use_the_minigame_buttons_and_ladder() -> void:
	for game in ["Password", "Variabel"]:
		var scene := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/%s.tscn" % game)
		assert_true(scene.contains('&"MinigameCtaButton"'), game + ": Kirim is the minigame CTA")
		assert_true(scene.contains('&"MinigameSecondaryButton"'), game + ": Hapus is brown")
		var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/%s.gd" % game)
		assert_true(src.contains("follow_width("), game + ": the card follows the calculator")
		assert_true(src.contains("MinigameType.T2"), game + ": fits never drop below T2")
```

Update `test_button_roles_phase3.gd` ROLES: BtnHapus → `&"MinigameSecondaryButton"`, BtnKirim → `&"MinigameCtaButton"`. In `test_kalkulator.gd`, lines L161/163/259/261 count `MinigameCtaButton` / `MinigameSecondaryButton`, and L50/L52 assert `MinigameKeyLabel` with no `theme_override_colors`.
- [ ] **Step 2: RUN** `minigame_hierarchy kalkulator button_roles_phase3`. Expected: FAIL. Commit.
- [ ] **Step 3: Implement.** `Kalkulator.gd`, under a `##` citing the 2026-09-30 measurement of `kalkulator_base.png` (1080×1487):

```gdscript
## The painted keypad face, as fractions of the body (measured 2026-09-30).
const FACE_RECT := Rect2(0.0537, 0.2751, 0.9259, 0.7061)
## The LCD glass, as fractions of the body.
const GLASS_RECT := Rect2(0.0963, 0.0935, 0.8074, 0.1560)
## Keypad block edges, centred on the face (0.5167) and wide enough that key 1
## covers most of a stray painted key outline at the art's top left.
const KEYPAD_LEFT := 0.085
const KEYPAD_RIGHT := 0.948
const KEYPAD_TOP := 0.300
## The 1-9 grid's bottom when the zero row shows, and the zero row's top.
const GRID_BOTTOM := 0.787
const ZERO_TOP := 0.807
const KEYPAD_BOTTOM := 0.955
```

  - `_apply_keypad_layout()` sets these anchors on `Body/KeyGrid`, `Body/ZeroRow` and `Body/Layar` (glass rect; offsets 0 on all four sides). `KeyGrid.anchor_bottom` is `GRID_BOTTOM` when `show_zero_key` is true, else `KEYPAD_BOTTOM`. `_ready` and the `show_zero_key` setter call it.
  - `follow_width(target)` sets the width once and connects `Body.resized` to re-set it.
  - In `Kalkulator.tscn`, write the same anchors; `KeyGrid` `h_separation = 44`, `v_separation = 34`; `ZeroRow` separation 44; `Layar` → `MinigameLcdLabel`, `outline_size` override gone.
  - `layar_color` defaults to `ThemeFactory.MINIGAME_LCD_INK`.
  - In `KalkulatorKey.tscn`, `Digit` → `MinigameKeyLabel`, with the colour override gone.
  - In `Password.tscn` / `Variabel.tscn`:
    - `Column` separation 44;
    - `SoalCard` `custom_minimum_size = Vector2(0, 0)`, still `size_flags_horizontal = 4`;
    - `AksiRow` separation 16;
    - BtnHapus → `MinigameSecondaryButton`, BtnKirim → `MinigameCtaButton`;
    - add a `TrayGap` Control (`custom_minimum_size = Vector2(0, 28)`, `mouse_filter = 2`) before `MinigameTray`, so 44 + 28 = 72.
  - In `Password.gd` / `Variabel.gd`:
    - call `kalkulator.follow_width(soal_card)` in `_ready`; the `soal_card` onready is `%SoalCard`;
    - `problem_font_size = MinigameType.T4` and `min_problem_font_size = MinigameType.T2`;
    - `equation_font_size = MinigameType.T3` and `min_equation_font_size = MinigameType.T2`.
- [ ] **Step 4: RUN** `minigame_hierarchy kalkulator button_roles_phase3 minigame_layout minigame_typography tall_screen_layout script_documentation`. Expected: PASS.
- [ ] **Step 5: Commit** `fix(kalkulator): centre the keypad on the painted face; one column with the card`.

### Task 6: Menjodohkan (B6)

**Files:** `Scenes/Minigames/Akademis/Menjodohkan.tscn`, `Scripts/Minigames/Akademis/Menjodohkan.gd`; tests `test_minigame_typography.gd:200-210`, `test_minigame_hierarchy.gd`; remove the `MinigameWheelHeaderWarm/Cool` variations, their `DISPLAY_ROSTER` entries and their VARIATIONS entries.

- [ ] **Step 1: Failing tests.** Append:

```gdscript
# ------------------------------------------------------------ Menjodohkan

const MJ := "res://Scenes/Minigames/Akademis/Menjodohkan.tscn"


func test_menjodohkan_arrows_ride_the_edge_lanes_beside_the_cards() -> void:
	var root := (track(LayoutFrame.stand_up(MJ, Vector2(1080, 1920))) as Control).get_child(0)
	for path in ["Safe/Column/TopCarousel/BtnPrevQ",
			"Safe/Column/MinigameTray/BottomCarousel/BtnPrevA"]:
		var b := root.get_node(path) as Button
		assert_eq(b.theme_type_variation, &"WoodNavArrow")
		assert_true(absf(b.get_global_rect().position.x - EDGE) <= 1.0, path + " at the edge")
	assert_eq(float(root.get("card_width")), 1080.0 - 2.0 * (48.0 + 96.0 + 28.0),
		"cards fill the space between the arrow lanes, 28 clear of each")
	for plank in ["Safe/Column/TopCarousel/SoalPlank",
			"Safe/Column/MinigameTray/BottomCarousel/JawabanPlank"]:
		assert_eq((root.get_node(plank) as Control).theme_type_variation, &"MinigamePlankPanel")


func test_menjodohkan_drops_its_dead_style_exports() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/Menjodohkan.gd")
	for gone in ["nav_btn_style", "submit_btn_active_style", "submit_btn_disabled_style",
			"correct_color", "wrong_color"]:
		assert_false(src.contains(gone), "B6: %s is gone" % gone)
	assert_true(src.contains("MinigameType.T3") and src.contains("MinigameType.T2"),
		"tile text fits T3 down to T2")
```

In `test_minigame_typography.gd`, `test_menjodohkan_headers_clear_the_contrast_floor` keeps the DEAD_INKS check and asserts `MinigamePlankLabel` in place of the two wheel headers; drop the two wheel names from VARIATIONS.
- [ ] **Step 2: RUN** `minigame_hierarchy minigame_typography`. Expected: FAIL. Commit.
- [ ] **Step 3: Implement.** `Menjodohkan.tscn`:
  - `Column` separation 28.
  - `TopHeaderLabel` → `SoalPlank`: a PanelContainer (`MinigamePlankPanel`), anchored top-centre (`anchor_left = 0.5`, `anchor_right = 0.5`, `grow_horizontal = 2`), with a `Label` child (`MinigamePlankLabel`, `text = "SOAL"`).
  - `QuestionWheelParent` `anchor_top = 0.0`, `offset_top = 84.0`.
  - The four arrows: `WoodNavArrow`; left offsets `(0, -48, 96, 48)`, right `(-96, -48, 0, 48)`.
  - `BottomCarousel` `custom_minimum_size = Vector2(0, 404)`, with `BottomHeaderLabel` → `JawabanPlank` built the same way and `AnswerWheelParent` `offset_top = 84.0`.
  - `MinigameTray` instance `separation = 44`.
  - `ActionRow` separation 16; BtnLock → `MinigameSecondaryButton`, BtnSubmit → `MinigameCtaButton`.

  `Menjodohkan.gd`:
  - add `## Width of every wheel card: the space between the two 96 px arrow lanes, 28 px clear of each.` and `@export var card_width: float = 736.0`, then set `card.custom_minimum_size.x = card_width` right after each card is instanced;
  - `TILE_TEXT_MAX := MinigameType.T3`, `TILE_TEXT_MIN := MinigameType.T2`;
  - delete `nav_btn_style`, `submit_btn_active_style`, `submit_btn_disabled_style`, `correct_color`, `wrong_color` and the branches that read them;
  - update the `@onready` label refs if any pointed at the removed header labels.

  In `ThemeFactory.gd`, delete the `MinigameWheelHeader*` loop; remove them from `DISPLAY_ROSTER` and from the declared list if present. **Rebake** in the RUN.
- [ ] **Step 4: RUN** (**Rebake** first) `minigame_hierarchy minigame_typography minigame_layout theme_factory tall_screen_layout script_documentation viewport_editability`. Expected: PASS.
- [ ] **Step 5: Commit** `fix(menjodohkan): planks, edge-lane arrows and room in the tray`.

### Task 7: BuatBatik tools (B2, B4)

**Files:** `Scenes/Minigames/SeniBudaya/BuatBatik.tscn`, `Scripts/Minigames/SeniBudaya/BuatBatik.gd`; tests `test_minigame_art.gd:381-396` (the `ToolTextureRect` anchors become `(0, 0, 1, TOOL_NAME_SPLIT)`), `test_minigame_hierarchy.gd`.

- [ ] **Step 1: Failing tests.** Append:

```gdscript
# -------------------------------------------------------------- BuatBatik

const BATIK := "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn"


func test_batik_tools_are_cream_named_and_ringed() -> void:
	var root := (track(LayoutFrame.stand_up(BATIK, Vector2(1080, 1920))) as Control).get_child(0)
	var names := ["Pensil", "Canting", "Pewarna", "Kompor"]
	for i in 4:
		var slot := root.get_node("Safe/Column/MinigameTray/ToolsContainer/Tool%d" % i)
		assert_eq((slot.get_node("Bg") as Control).theme_type_variation, &"MinigameToolCard")
		var label := slot.get_node("NameLabel") as Label
		assert_eq(label.theme_type_variation, &"MinigameToolNameLabel")
		assert_eq(label.text, names[i], "B4: Tool%d shows its name" % i)
		assert_eq((slot.get_node("Ring") as Control).theme_type_variation, &"MinigameToolRing")
	var scene := FileAccess.get_file_as_string(BATIK)
	assert_false(scene.contains("Color(0.2, 0.5019608, 0.8509804, 1)"), "B2: no blue rim")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/SeniBudaya/BuatBatik.gd")
	assert_true(src.contains('tool0_display_name: String = "Pensil"'), "Indonesian name")
	assert_true(src.contains("_ring_next_tool("), "the ring follows the next step")
```

- [ ] **Step 2: RUN** `minigame_hierarchy`. Expected: FAIL. Commit.
- [ ] **Step 3: Implement.**
  - `BuatBatik.tscn`:
    - delete the four `StyleBoxFlat` sub_resources and the `Bg` overrides; `Bg` gets `theme_type_variation = &"MinigameToolCard"`;
    - slots: `custom_minimum_size = Vector2(0, 280)`, `size_flags_horizontal = 3`;
    - `ToolsContainer`: `custom_minimum_size = Vector2(0, 280)`, separation 16;
    - `ToolTextureRect`: `anchor_bottom = 0.7`, offsets `(16, 16, -16, 0)`;
    - add a `NameLabel` per slot (Label, `MinigameToolNameLabel`, `anchor_top = 0.7`, `anchor_right = 1.0`, `anchor_bottom = 1.0`, centred, `mouse_filter = 2`, text Pensil / Canting / Pewarna / Kompor for Tool0–3);
    - add a `Ring` per slot (Panel, full rect, `MinigameToolRing`, `visible = false`, `mouse_filter = 2`).
  - `BuatBatik.gd`:
    - `tool0_display_name` defaults to `"Pensil"`;
    - `_apply_visual_exports` also writes each slot's `NameLabel.text` from its `toolN_display_name`;
    - add `const TOOL_NAME_SPLIT := 0.7` with a `##` (used by the art test);
    - add `func _ring_next_tool() -> void`, which shows `Ring` only on the slot named `correct_sequence[player_sequence.size()]` (none when done), called from `_update_progress_label()`.
  - Update `test_minigame_art.gd`'s anchor assertion to `(0, 0, 1, 0.7)`.
- [ ] **Step 4: RUN** `minigame_hierarchy minigame_art minigame_layout minigame_typography tall_screen_layout script_documentation viewport_editability`. Expected: PASS.
- [ ] **Step 5: Commit** `fix(buat-batik): named cream tool cards and a ring on the next tool`.

### Task 8: Badminton (B5) and the one-score caption

**Files:** `Scenes/Minigames/Olahraga/Badminton.tscn`, `Scripts/Minigames/Olahraga/Badminton.gd:595`; tests `test_minigame_layout.gd:178-185` (`"Capai %d poin"`), `test_minigame_hierarchy.gd`.

- [ ] **Step 1: Failing test.** Append:

```gdscript
# -------------------------------------------------------------- Badminton

const BADMINTON := "res://Scenes/Minigames/Olahraga/Badminton.tscn"
## The painted bottom baseline's last row in lapanganBadminton.jpg (1080x1920),
## measured 2026-09-30.
const COURT_BASELINE_ROW := 1794.0


func test_the_court_baseline_clears_the_hint_pill() -> void:
	for screen in [Vector2(1080, 1920), Vector2(1080, 2400)]:
		var root := (track(LayoutFrame.stand_up(BADMINTON, screen)) as Control).get_child(0)
		var bg := root.get_node("Background") as TextureRect
		var r := bg.get_global_rect()
		var tex := bg.texture.get_size()
		var s := maxf(r.size.x / tex.x, r.size.y / tex.y)
		var baseline := r.position.y + (r.size.y - tex.y * s) / 2.0 + COURT_BASELINE_ROW * s
		var pill := (root.get_node("%MinigameHintPill") as Control).get_global_rect()
		assert_true(baseline <= pill.position.y - 16.0,
			"B5: baseline %.0f vs pill %.0f at %s" % [baseline, pill.position.y, screen])
		var surround := bg.get_node("Surround") as Control
		assert_true(surround.show_behind_parent and surround.get_global_rect().end.y >= screen.y,
			"the uncovered strip is filled to the screen bottom")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Olahraga/Badminton.gd")
	assert_true(src.contains('"Capai %d poin"'), "one score: the bar names the goal")
```

- [ ] **Step 2: RUN** `minigame_hierarchy`. Expected: FAIL. Commit.
- [ ] **Step 3: Implement.**
  - `Badminton.tscn`, `Background`: `offset_top = -48.0` and `offset_bottom = -48.0` (the cover scale is unchanged, so the art only moves up).
  - Add a child `[node name="Surround" type="ColorRect" parent="Background"]` with:
    - `show_behind_parent = true`, full-rect anchors, `offset_bottom = 48.0`, `mouse_filter = 2`;
    - `color = Color(0.08, 0.33, 0.51, 1)`, the art's measured bottom-edge blue.
  - Add a `##`-style comment (a scene `metadata/_note` is not used; the explanation goes in `Badminton.gd` beside `_update_score_ui`).
  - `Badminton.gd:595`: `set_progress(player_score, target_score, "Capai %d poin" % target_score)`.
  - Update `test_minigame_layout.gd:185`'s string.
  - If B5 still fails at 1920, raise both offsets in 16px steps and keep `Surround.offset_bottom` equal to their absolute value.
- [ ] **Step 4: RUN** `minigame_hierarchy minigame_layout badminton_visuals illustration_ao look_layer lobby_look tall_screen_layout`. Expected: PASS.
- [ ] **Step 5: Commit** `fix(badminton): lift the court off the hint pill; one score`.

### Task 9: Docs, full run, live sheet, ship

- [ ] **Step 1:** `DEBT.md`:
  - delete "Score HUD restyle deferred";
  - update the override tally (QuestionCard 3→0, AnswerCard 2→0, KalkulatorKey 1→0, BuatBatik 6→2);
  - drop `timer.svg` from the placeholders if `grep -r "timer.svg" Scenes Scripts` is empty;
  - add "kalkulator_base.png has a stray painted key outline top-left (≈ 0.051–0.275 × 0.293–0.468 of the art) — artist";
  - remove the Badminton duplicate-score line.

  `CHANGELOG.md`: a newest-first entry for this pass. In CLAUDE.md's `## Visual system`, the minigame line gains `and one type ladder (MinigameType, x1.618: 28/45/73/118)`.
- [ ] **Step 2: RUN** the full suite (`test_run()` with no suite), with a fresh editor, and expect the bridge to drop after the reply. Compare to the Task 0 baseline; every new red is a real failure. Fix it with a targeted RUN, then take one more full run.
- [ ] **Step 3: Live sheet.**
  - Launch the game from the worktree editor (`project_run`, `autosave=false`), and capture all eight minigames with the debug launcher at 1080×1920. Use the scratchpad capture method from brainstorming: one `game_eval` per game, `Engine.time_scale = 0`, `save_png`.
  - Compose `minigame-hierarchy-after.jpg` next to the before-sheet in `docs/superpowers/mockups/`, and send the before and after to the owner at full size.
- [ ] **Step 4: Commit** `docs(minigames): hierarchy pass changelog, debt and the after-sheet`.
- [ ] **Step 5: Ship** with the `ship-pr` skill: base `feat/minigame-mobile-layout` while #155 is open, label `hold` (mentor gate, spec 9), and bind the PR.
