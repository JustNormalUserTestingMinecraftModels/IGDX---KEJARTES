# Settings Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `Scenes/UI/Settings.tscn` in Inventory's visual language — blurred Lobby backdrop, header `Card` with Kembali and a `DisplayLabel` title, three titled section cards in a scroll — with brand-styled switches, sliders and row rules.

**Architecture:** Three new `ThemeFactory` variations (`SettingsSwitch`, `SettingsSlider`, `SettingsDivider`) take their textures from new `DesignTokens` exports, since the factory does no I/O. The six on/off rows become one `SettingsToggleRow.tscn` template whose label is an `@export` on its root. `Settings.gd` keeps every behaviour and only re-points its node references.

**Tech Stack:** Godot 4.6 GDScript, `.tscn` text scenes, `McpTestSuite` suites run through the godot-ai `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-28-settings-layout-design.md`

## Global Constraints

- Work only in the worktree `.claude/worktrees/settings-layout`, on branch `feat/settings-layout`. Never `git switch` in the main checkout.
- **No `theme_override_*`** except layout constants (`separation`, `margin_*`).
- **No visual built at runtime.** Every node lives in a `.tscn`.
- Every script has a `##` file header, and every `@export` has a `##` line.
- Every suite and every script a test instantiates is `@tool`. No test is a coroutine: no `await`.
- UI text is Indonesian, exactly: `PENGATURAN`, `Kembali`, `SUARA`, `PERMAINAN`, `TAMPILAN`, `Suara Utama`, `Musik`, `Efek Suara`, `Tutorial Minigame`, `Lewati Dialog Minigame`, `Efek Visual`, `Efek Suasana`, `Kurangi Gerakan`, `Getaran (Haptic)`.
- A new tunable number of ours goes in a named `const`, never inline.
- Commits follow Conventional Commits with a scope, and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Write each message to a file and pass it with `git commit -F`.

## Editor protocol (read once, applies to every task)

The godot-ai bridge's default editor has the **main** checkout open, so it never sees this worktree. Tests run in a **second editor** launched on the worktree:

1. Seed the cache once: copy `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main checkout's `.godot/` into the worktree's `.godot/`. Do not copy `.godot/editor/`.
2. Launch it detached from PowerShell:
   `Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`" --path `"<worktree>`" -e"; CurrentDirectory = "<worktree>" }`
3. Poll `session_manage(op="list")` until a `settings-layout@xxxx` session is `ready`. Pass that `session_id` on **every** godot-ai call, and never `session_activate` (other sessions share the server).
4. **This editor never saves a scene.** Scenes are written as text only while it is **closed** (`editor_manage(op="quit")`, or stop its PID after checking that its CommandLine names the worktree). That sidesteps CLAUDE.md 4/4b entirely.
5. After editing any `.gd` from outside the editor while it runs, do a no-op `script_patch` on that file, or restart the editor, before running `test_run`.
6. Before each commit: `git status`, then revert `Assets/Audio/default_bus_layout.tres` and any `*.png.import` the editor rewrote. Revert the `.import` files only while the editor is closed.

## File map

| File | Status | Responsibility |
|---|---|---|
| `Assets/Images/UI/Settings/switch_on.svg` | create | 112×64 on-switch picture |
| `Assets/Images/UI/Settings/switch_off.svg` | create | 112×64 off-switch picture |
| `Assets/Images/UI/Settings/slider_grabber.svg` | create | 56×56 slider grabber |
| `Scripts/Design/DesignTokens.gd` | modify | three `Texture2D` exports |
| `Assets/Theme/design_tokens.tres` | modify | point those exports at the SVGs |
| `Scripts/Design/ThemeFactory.gd` | modify | `_build_settings` and `_settings_track` |
| `Assets/Theme/kejartes_theme.tres` | rebake | generated |
| `tests/test_theme_factory.gd` | modify | pin the three variations |
| `Scripts/UI/SettingsToggleRow.gd` | create | row script: `label_text`, `toggle` |
| `Scenes/UI/SettingsToggleRow.tscn` | create | row template |
| `Scenes/UI/Settings.tscn` | rewrite | new layout |
| `Scripts/UI/Settings.gd` | modify | node references, `_collect_cards` |
| `tests/test_settings.gd` | modify | structure and switch tests |
| `tests/test_shorten.gd` | modify | find the skip switch through its row |
| `tests/test_back_controls.gd` | modify | new BackButton path |
| `tests/test_tall_screen_layout.gd` | modify | Settings block |
| `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md` | modify | debt and changelog |

---

### Task 1: Settings control theme

**Files:**
- Create: the three SVGs above
- Modify: `Scripts/Design/DesignTokens.gd` (append a group at the end of the exports), `Assets/Theme/design_tokens.tres`, `Scripts/Design/ThemeFactory.gd` (`build()` list, new functions after `_build_picker`)
- Test: `tests/test_theme_factory.gd`
- Rebake: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Produces: theme types `SettingsSwitch` (base `CheckButton`), `SettingsSlider` (base `HSlider`), `SettingsDivider` (base `HSeparator`); token fields `settings_switch_on`, `settings_switch_off`, `settings_slider_grabber: Texture2D`.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_theme_factory.gd`)

```gdscript
# ── Settings controls (2026-09-28 settings-layout spec) ──────────────────────

func test_settings_variations_extend_their_base_types() -> void:
	assert_eq(_theme.get_type_variation_base("SettingsSwitch"), &"CheckButton",
		"SettingsSwitch is a CheckButton variation")
	assert_eq(_theme.get_type_variation_base("SettingsSlider"), &"HSlider",
		"SettingsSlider is an HSlider variation")
	assert_eq(_theme.get_type_variation_base("SettingsDivider"), &"HSeparator",
		"SettingsDivider is an HSeparator variation")


## The switch draws only its picture: every button state is empty, and the
## icons are the token textures.
func test_settings_switch_draws_only_the_token_pictures() -> void:
	assert_true(_tokens.settings_switch_on != null, "tokens carry the on-switch picture")
	assert_true(_tokens.settings_switch_off != null, "tokens carry the off-switch picture")
	for icon in ["checked", "checked_disabled"]:
		assert_eq(_theme.get_icon(icon, "SettingsSwitch"), _tokens.settings_switch_on,
			"SettingsSwitch/%s is the on picture" % icon)
	for icon in ["unchecked", "unchecked_disabled"]:
		assert_eq(_theme.get_icon(icon, "SettingsSwitch"), _tokens.settings_switch_off,
			"SettingsSwitch/%s is the off picture" % icon)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		assert_true(_theme.has_stylebox(state, "SettingsSwitch"),
			"SettingsSwitch defines %s" % state)
		assert_true(_theme.get_stylebox(state, "SettingsSwitch") is StyleBoxEmpty,
			"SettingsSwitch/%s draws nothing" % state)


## A 20px sunken track filled brand brown, with the token grabber.
func test_settings_slider_is_a_brand_track() -> void:
	var track := _theme.get_stylebox("slider", "SettingsSlider") as StyleBoxFlat
	var fill := _theme.get_stylebox("grabber_area", "SettingsSlider") as StyleBoxFlat
	assert_true(track != null and fill != null, "SettingsSlider has flat track and fill")
	if track == null or fill == null:
		return
	assert_eq(track.bg_color, _tokens.surface_sunken, "the track is sunken cream")
	assert_eq(track.content_margin_top + track.content_margin_bottom, 20.0, "the track is 20px thick")
	assert_eq(fill.bg_color, _tokens.brand_primary, "the fill is brand brown")
	assert_true(_theme.has_stylebox("grabber_area_highlight", "SettingsSlider"),
		"the fill stays brown while dragging")
	assert_true(_tokens.settings_slider_grabber != null, "tokens carry the grabber")
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		assert_eq(_theme.get_icon(icon, "SettingsSlider"), _tokens.settings_slider_grabber,
			"SettingsSlider/%s is the token grabber" % icon)


func test_settings_divider_is_a_thin_sunken_rule() -> void:
	var rule := _theme.get_stylebox("separator", "SettingsDivider") as StyleBoxLine
	assert_true(rule != null, "SettingsDivider draws a StyleBoxLine")
	if rule == null:
		return
	assert_eq(rule.color, _tokens.surface_sunken, "the rule is sunken cream")
	assert_eq(rule.thickness, 2, "the rule is 2px")
```

- [ ] **Step 2: Seed and launch the worktree editor, then run the tests and confirm they fail**

Follow the editor protocol. Run `test_run(suite="theme_factory", session_id=<id>)`.
Expected: the four new tests FAIL (the types do not exist, and `settings_switch_on` is an invalid property). Everything else passes.

- [ ] **Step 3: Create the three SVGs**

`Assets/Images/UI/Settings/switch_on.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="112" height="64" viewBox="0 0 112 64"><rect width="112" height="64" rx="32" fill="#35A05A"/><circle cx="80" cy="32" r="25" fill="#FFFDF8"/></svg>
```
`Assets/Images/UI/Settings/switch_off.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="112" height="64" viewBox="0 0 112 64"><rect x="1.5" y="1.5" width="109" height="61" rx="30.5" fill="#EFE0CB" stroke="#D8C2A2" stroke-width="3"/><circle cx="32" cy="32" r="23" fill="#FFFDF8" stroke="#D8C2A2" stroke-width="2"/></svg>
```
`Assets/Images/UI/Settings/slider_grabber.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 56 56"><circle cx="28" cy="28" r="25" fill="#FFFDF8" stroke="#7A4A2B" stroke-width="6"/></svg>
```

- [ ] **Step 4: Add the token exports** (end of `Scripts/Design/DesignTokens.gd`)

```gdscript
@export_group("Settings")
## SettingsSwitch's "on" picture (Assets/Images/UI/Settings/switch_on.svg,
## 112x64): a green pill with its knob on the right. Null leaves the base
## CheckButton's icon in place.
@export var settings_switch_on: Texture2D
## SettingsSwitch's "off" picture (switch_off.svg, 112x64): a sunken cream
## pill with its knob on the left.
@export var settings_switch_off: Texture2D
## SettingsSlider's grabber (slider_grabber.svg, 56x56): a cream disc ringed
## in brand brown.
@export var settings_slider_grabber: Texture2D
```

- [ ] **Step 5: Point the token resource at the SVGs** (`Assets/Theme/design_tokens.tres`)

Add after the last `[ext_resource ...]` line:
```
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Settings/switch_on.svg" id="3_sw_on"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Settings/switch_off.svg" id="4_sw_off"]
[ext_resource type="Texture2D" path="res://Assets/Images/UI/Settings/slider_grabber.svg" id="5_grab"]
```
Add at the end of the `[resource]` block:
```
settings_switch_on = ExtResource("3_sw_on")
settings_switch_off = ExtResource("4_sw_off")
settings_slider_grabber = ExtResource("5_grab")
```
Bump the header's `load_steps` if it has one (this file has none).

- [ ] **Step 6: Build the variations** (`Scripts/Design/ThemeFactory.gd`)

In `build()`, add `_build_settings(theme, tokens)` on the line before `_build_base_overrides(theme, tokens)`. Then add after `_build_picker`'s function:

```gdscript
## Settings' track thickness and row-rule thickness, in px.
const SETTINGS_TRACK_THICKNESS := 20
const SETTINGS_RULE_THICKNESS := 2


## Settings' controls (2026-09-28 settings-layout spec). The three pictures
## come from DesignTokens, because this file does no I/O.
##
##   SettingsSwitch   a CheckButton that draws only its switch picture; the
##                    row's Label carries the words, so every state is empty.
##   SettingsSlider   a sunken cream track filled brand brown, with a cream
##                    grabber disc ringed in brown.
##   SettingsDivider  the thin sunken rule between rows in a section card.
static func _build_settings(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("SettingsSwitch")
	theme.set_type_variation("SettingsSwitch", "CheckButton")
	_set_icons(theme, "SettingsSwitch", ["checked", "checked_disabled"], tokens.settings_switch_on)
	_set_icons(theme, "SettingsSwitch", ["unchecked", "unchecked_disabled"], tokens.settings_switch_off)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "SettingsSwitch", StyleBoxEmpty.new())

	theme.add_type("SettingsSlider")
	theme.set_type_variation("SettingsSlider", "HSlider")
	theme.set_stylebox("slider", "SettingsSlider", _settings_track(tokens, tokens.surface_sunken))
	var fill := _settings_track(tokens, tokens.brand_primary)
	theme.set_stylebox("grabber_area", "SettingsSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "SettingsSlider", fill)
	_set_icons(theme, "SettingsSlider", ["grabber", "grabber_highlight", "grabber_disabled"],
		tokens.settings_slider_grabber)

	theme.add_type("SettingsDivider")
	theme.set_type_variation("SettingsDivider", "HSeparator")
	var rule := StyleBoxLine.new()
	rule.color = tokens.surface_sunken
	rule.thickness = SETTINGS_RULE_THICKNESS
	theme.set_stylebox("separator", "SettingsDivider", rule)
	theme.set_constant("separation", "SettingsDivider", SETTINGS_RULE_THICKNESS)


## A pill-ended bar of `color`, SETTINGS_TRACK_THICKNESS tall.
static func _settings_track(tokens: DesignTokens, color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(tokens.radius_pill)
	sb.content_margin_top = SETTINGS_TRACK_THICKNESS / 2.0
	sb.content_margin_bottom = SETTINGS_TRACK_THICKNESS / 2.0
	return sb


## Sets every icon in `names` on `type` to `tex`; a null `tex` leaves the base
## type's icons in place.
static func _set_icons(theme: Theme, type: String, names: Array, tex: Texture2D) -> void:
	if tex == null:
		return
	for icon_name in names:
		theme.set_icon(icon_name, type, tex)
```

If `const` declarations must sit at the top of the file in this codebase's style, move the two consts under the file header instead. Grep for `^const` in `ThemeFactory.gd` first and match what is there.

- [ ] **Step 7: Restart the worktree editor** (new Resource `@export`s need a full restart, and so do the new SVGs' imports). Quit it, relaunch it, and wait for `ready`.

- [ ] **Step 8: Run the tests and confirm they pass**

Run `test_run(suite="theme_factory", session_id=<id>)`. Expected: all tests pass, **except** that `test_baked_theme_resource_matches_the_factory` may fail until the rebake.

- [ ] **Step 9: Rebake, alone**

Run `test_run(suite="theme_rebake", session_id=<id>)` as its own call. Then quit the editor (a rebake must never be followed by a scene op in the same editor). Run `git diff --stat Assets/Theme/kejartes_theme.tres`, and check that the added lines are the three new types. Id churn elsewhere in the file is a warning sign: if you see it, `git checkout --` the bake, relaunch, and rebake again.

- [ ] **Step 10: Relaunch and re-run `theme_factory` and `design_tokens`.** Expected: all tests pass, `test_baked_theme_resource_matches_the_factory` included.

- [ ] **Step 11: Commit**

Include the three `.svg` files and their `.svg.import` files, `DesignTokens.gd`, `design_tokens.tres`, `ThemeFactory.gd`, `kejartes_theme.tres` and `test_theme_factory.gd`. Revert `default_bus_layout.tres`.
Message: `feat(settings): brand-styled switch, slider and divider theme variations`

---

### Task 2: Settings screen rebuild

**Files:**
- Create: `Scripts/UI/SettingsToggleRow.gd`, `Scenes/UI/SettingsToggleRow.tscn`
- Rewrite: `Scenes/UI/Settings.tscn`
- Modify: `Scripts/UI/Settings.gd`
- Test: `tests/test_settings.gd`, `tests/test_shorten.gd`, `tests/test_back_controls.gd`

**Interfaces:**
- Consumes: `SettingsSwitch`, `SettingsSlider` and `SettingsDivider` from Task 1.
- Produces: a row with `label_text: String` (an export on the root) and `toggle: CheckButton` (a getter returning `$Toggle`). Row names `TutorialRow`, `SkipDialogRow`, `LookLayerRow`, `AmbientRow`, `ReduceMotionRow`, `HapticsRow`. Path `SafeArea/MainColumn/Header/HeaderCol/Row/BackButton`. Path `SafeArea/MainColumn/Scroll/Pad/Sections` holding `AudioCard`, `GameplayCard` and `DisplayCard`.

- [ ] **Step 1: Write the failing tests** in `tests/test_settings.gd`

Add near the top, after `const LayoutFrame ...`:
```gdscript
## Each section card: its heading, then its rows in order.
const _SECTIONS := {
	"AudioCard": ["SUARA", ["MasterRow", "BgmRow", "SfxRow"]],
	"GameplayCard": ["PERMAINAN", ["TutorialRow", "SkipDialogRow"]],
	"DisplayCard": ["TAMPILAN", ["LookLayerRow", "AmbientRow", "ReduceMotionRow", "HapticsRow"]],
}
## Each switch row's words.
const _ROW_LABELS := {
	"TutorialRow": "Tutorial Minigame", "SkipDialogRow": "Lewati Dialog Minigame",
	"LookLayerRow": "Efek Visual", "AmbientRow": "Efek Suasana",
	"ReduceMotionRow": "Kurangi Gerakan", "HapticsRow": "Getaran (Haptic)",
}
## Each switch row's GameSettings property.
const _ROW_SETTINGS := {
	"TutorialRow": "minigame_tutorial_enabled", "SkipDialogRow": "skip_event_dialogue",
	"LookLayerRow": "look_layer_enabled", "AmbientRow": "ambient_effects_enabled",
	"ReduceMotionRow": "reduce_motion", "HapticsRow": "haptics_enabled",
}
const _ROW_SCRIPT := "res://Scripts/UI/SettingsToggleRow.gd"
```

Add a helper after `teardown()`:
```gdscript
## The switch inside the SettingsToggleRow named `row_name`, or null.
func _toggle(row_name: String) -> CheckButton:
	var row := _screen.find_child(row_name, true, false)
	return (row.get_node_or_null("Toggle") as CheckButton) if row != null else null
```

**Delete** `test_tutorial_toggle_reflects_and_writes_game_settings`, `test_ambient_toggle_reflects_and_writes_game_settings`, `test_ambient_card_sits_after_the_look_layer_card` and `test_every_row_fits_the_design_screen`. The tests below replace them. Then add:

```gdscript
func test_backdrop_is_the_blurred_lobby() -> void:
	var bg := _screen.get_node_or_null("Background") as TextureRect
	assert_true(bg != null and bg.texture != null, "Settings needs its Background")
	if bg == null or bg.texture == null:
		return
	assert_eq(bg.texture.resource_path, "res://Assets/Images/UI/blur_background.png",
		"Settings sits on the blurred Lobby, like its siblings")


## Inventory's header: a Card with Kembali over the DisplayLabel title.
func test_header_matches_inventory() -> void:
	var header := _screen.get_node_or_null("SafeArea/MainColumn/Header") as PanelContainer
	assert_true(header != null, "Settings needs SafeArea/MainColumn/Header")
	if header == null:
		return
	assert_eq(header.theme_type_variation, &"Card", "the header is a Card")
	var back := header.get_node_or_null("HeaderCol/Row/BackButton") as Button
	assert_true(back != null, "Kembali rides in the header")
	if back != null:
		assert_eq(back.theme_type_variation, &"SecondaryButton", "Kembali is a SecondaryButton")
		assert_eq(back.text, "Kembali", "Kembali, as on Inventory")
	var title := header.get_node_or_null("HeaderCol/TitleLabel") as Label
	assert_true(title != null and title.theme_type_variation == &"DisplayLabel",
		"the title is a DisplayLabel under the back button")


func test_sections_scroll_under_the_header() -> void:
	var scroll := _screen.get_node_or_null("SafeArea/MainColumn/Scroll") as ScrollContainer
	assert_true(scroll != null, "Settings needs SafeArea/MainColumn/Scroll")
	if scroll == null:
		return
	assert_eq(scroll.size_flags_vertical, Control.SIZE_EXPAND_FILL, "the scroll takes the rest")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"it never scrolls sideways")
	assert_true(scroll.get_node_or_null("Pad/Sections") != null, "the cards sit in Pad/Sections")


## Three titled cards, in order, each holding its rows in order with one
## SettingsDivider between neighbours.
func test_settings_are_grouped_into_three_titled_cards() -> void:
	var sections := _screen.find_child("Sections", true, false)
	assert_true(sections != null, "Settings needs its Sections column")
	if sections == null:
		return
	var names: Array = []
	for card in sections.get_children():
		names.append(String(card.name))
	assert_eq(names, _SECTIONS.keys(), "the three cards, in order")
	for card_name in _SECTIONS:
		var vbox := sections.get_node_or_null("%s/Margin/VBox" % card_name)
		assert_true(vbox != null, card_name + " needs Margin/VBox")
		if vbox == null:
			continue
		assert_eq((sections.get_node(card_name) as Control).theme_type_variation, &"Card",
			card_name + " is a Card")
		var heading := vbox.get_child(0) as Label
		assert_true(heading != null and heading.theme_type_variation == &"CardSectionLabel",
			card_name + " opens with a CardSectionLabel")
		if heading != null:
			assert_eq(heading.text, _SECTIONS[card_name][0], card_name + " heading")
		var rows: Array = []
		for i in range(1, vbox.get_child_count()):
			var child := vbox.get_child(i)
			if child is HSeparator:
				assert_eq((child as HSeparator).theme_type_variation, &"SettingsDivider",
					card_name + " rules are SettingsDividers")
			else:
				rows.append(String(child.name))
		assert_eq(rows, _SECTIONS[card_name][1], card_name + " rows, in order")
		assert_eq(vbox.get_child_count(), 2 * rows.size(),
			card_name + ": heading, rows, and one rule between each pair")


func test_every_switch_row_is_the_template_labelled_in_indonesian() -> void:
	for row_name in _ROW_LABELS:
		var row := _screen.find_child(row_name, true, false)
		assert_true(row != null, "Settings needs " + row_name)
		if row == null:
			continue
		assert_eq((row.get_script() as Script).resource_path, _ROW_SCRIPT,
			row_name + " is a SettingsToggleRow")
		assert_eq((row.get_node("Label") as Label).text, _ROW_LABELS[row_name],
			row_name + " is labelled in Indonesian")
		assert_eq(_toggle(row_name).theme_type_variation, &"SettingsSwitch",
			row_name + " wears the brand switch")
		assert_eq(row.toggle, _toggle(row_name), row_name + ".toggle is its switch")


func test_every_slider_wears_the_brand_slider() -> void:
	for slider_name in ["MasterSlider", "BgmSlider", "SfxSlider"]:
		var s := _screen.find_child(slider_name, true, false) as HSlider
		assert_true(s != null and s.theme_type_variation == &"SettingsSlider",
			slider_name + " is a SettingsSlider")


## Every switch opens on its setting and writes it back. It is restored
## through the switch itself, so any setting it saved is saved back too.
func test_every_switch_opens_on_and_writes_its_setting() -> void:
	for row_name in _ROW_SETTINGS:
		var key: String = _ROW_SETTINGS[row_name]
		var toggle := _toggle(row_name)
		assert_true(toggle != null, row_name + " needs its Toggle")
		if toggle == null:
			continue
		var original: bool = GameSettings.get(key)
		assert_eq(toggle.button_pressed, original, row_name + " opens on " + key)
		toggle.button_pressed = not original
		assert_eq(GameSettings.get(key), not original, row_name + " writes " + key)
		toggle.button_pressed = original


## At 1080x1920 all three cards fit above the scroll's bottom edge: 9:16
## never scrolls.
func test_every_card_fits_the_design_screen_without_scrolling() -> void:
	var frame := track(LayoutFrame.stand_up("res://Scenes/UI/Settings.tscn",
		Vector2(1080, 1920))) as Control
	var scroll := frame.find_child("Scroll", true, false) as Control
	var last := frame.find_child("DisplayCard", true, false) as Control
	assert_true(scroll != null and last != null, "Settings needs Scroll and DisplayCard")
	if scroll == null or last == null:
		return
	assert_true(last.get_global_rect().end.y <= scroll.get_global_rect().end.y,
		"TAMPILAN ends at %d, below the scroll's %d" % [
			last.get_global_rect().end.y, scroll.get_global_rect().end.y])
```

In `tests/test_shorten.gd`, replace the two `s.find_child("SkipDialogToggle", true, false) as CheckButton` lookups with:
```gdscript
	var toggle := s.find_child("SkipDialogRow", true, false).get_node("Toggle") as CheckButton
```
In `test_settings_has_the_skip_dialog_toggle`, replace the `SkipDialogLabel` lookup with:
```gdscript
	var label := s.find_child("SkipDialogRow", true, false).get_node("Label") as Label
```

In `tests/test_back_controls.gd`, change `"SafeArea/Layout/BackButton": "icon",` to `"SafeArea/MainColumn/Header/HeaderCol/Row/BackButton": "icon",`.

- [ ] **Step 2: Run the tests and confirm they fail**

With the editor running: do a no-op `script_patch` on each edited test file, then run `test_run` on `settings`, `shorten` and `back_controls`. Expected: the new tests FAIL on missing nodes, and the old slider tests still pass.

- [ ] **Step 3: Quit the worktree editor.** Scenes are written as text with it closed.

- [ ] **Step 4: Write the row script** `Scripts/UI/SettingsToggleRow.gd`

```gdscript
@tool
extends HBoxContainer

## One Settings on/off row: a BodyLabel on the left and a SettingsSwitch on
## the right (Scenes/UI/SettingsToggleRow.tscn). Settings.tscn instances it
## once per switch and wires `toggle` itself, so the row stays generic. The
## words live in `label_text` on the ROOT, because an instance's children do
## not keep overrides when the scene is saved.

## The row's words, e.g. "Tutorial Minigame". Shown in the editor too.
@export var label_text: String = "":
	set(value):
		label_text = value
		if is_node_ready():
			_apply_label()

## The row's switch. Settings.gd connects to its `toggled` signal.
var toggle: CheckButton:
	get:
		return get_node_or_null("Toggle") as CheckButton


func _ready() -> void:
	_apply_label()


func _apply_label() -> void:
	($Label as Label).text = label_text
```

- [ ] **Step 5: Write the row scene** `Scenes/UI/SettingsToggleRow.tscn`

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/UI/SettingsToggleRow.gd" id="1_row"]

[node name="SettingsToggleRow" type="HBoxContainer"]
custom_minimum_size = Vector2(0, 80)
theme_override_constants/separation = 16
script = ExtResource("1_row")

[node name="Label" type="Label" parent="."]
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"BodyLabel"
vertical_alignment = 1

[node name="Toggle" type="CheckButton" parent="."]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"SettingsSwitch"
```

- [ ] **Step 6: Rewrite `Scenes/UI/Settings.tscn`**

Keep the scene uid `uid://yoh7p3bbelyd`. Full file:

```
[gd_scene format=3 uid="uid://yoh7p3bbelyd"]

[ext_resource type="Script" uid="uid://4h5mljbcblli" path="res://Scripts/UI/Settings.gd" id="1_settings"]
[ext_resource type="Script" uid="uid://88qrfscj2817" path="res://Scripts/UI/SafeAreaMargin.gd" id="2_safe"]
[ext_resource type="Texture2D" uid="uid://csno01mdnqmpx" path="res://Assets/Images/UI/blur_background.png" id="3_bg"]
[ext_resource type="Texture2D" uid="uid://t8h6mqxkw5k" path="res://Assets/Images/UI/Nav/return_button.png" id="4_ret"]
[ext_resource type="PackedScene" path="res://Scenes/UI/SettingsToggleRow.tscn" id="5_row"]

[node name="Settings" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_settings")

[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("3_bg")
expand_mode = 1
stretch_mode = 6

[node name="SafeArea" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 48
theme_override_constants/margin_top = 48
theme_override_constants/margin_right = 48
theme_override_constants/margin_bottom = 48
script = ExtResource("2_safe")

[node name="MainColumn" type="VBoxContainer" parent="SafeArea"]
layout_mode = 2
theme_override_constants/separation = 32

[node name="Header" type="PanelContainer" parent="SafeArea/MainColumn"]
layout_mode = 2
theme_type_variation = &"Card"

[node name="HeaderCol" type="VBoxContainer" parent="SafeArea/MainColumn/Header"]
layout_mode = 2
theme_override_constants/separation = 18

[node name="Row" type="HBoxContainer" parent="SafeArea/MainColumn/Header/HeaderCol"]
layout_mode = 2

[node name="BackButton" type="Button" parent="SafeArea/MainColumn/Header/HeaderCol/Row"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 96)
layout_mode = 2
size_flags_horizontal = 0
size_flags_vertical = 4
theme_type_variation = &"SecondaryButton"
text = "Kembali"
icon = ExtResource("4_ret")

[node name="TitleLabel" type="Label" parent="SafeArea/MainColumn/Header/HeaderCol"]
layout_mode = 2
theme_type_variation = &"DisplayLabel"
text = "PENGATURAN"
vertical_alignment = 1

[node name="Scroll" type="ScrollContainer" parent="SafeArea/MainColumn"]
layout_mode = 2
size_flags_vertical = 3
horizontal_scroll_mode = 0

[node name="Pad" type="MarginContainer" parent="SafeArea/MainColumn/Scroll"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/margin_top = 8
theme_override_constants/margin_bottom = 24

[node name="Sections" type="VBoxContainer" parent="SafeArea/MainColumn/Scroll/Pad"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 32
```

Then, for each card, one block of this shape. `AudioCard` is shown in full:

```
[node name="AudioCard" type="PanelContainer" parent="SafeArea/MainColumn/Scroll/Pad/Sections"]
layout_mode = 2
theme_type_variation = &"Card"

[node name="Margin" type="MarginContainer" parent="SafeArea/MainColumn/Scroll/Pad/Sections/AudioCard"]
layout_mode = 2
theme_override_constants/margin_left = 24
theme_override_constants/margin_top = 20
theme_override_constants/margin_right = 24
theme_override_constants/margin_bottom = 20

[node name="VBox" type="VBoxContainer" parent="SafeArea/MainColumn/Scroll/Pad/Sections/AudioCard/Margin"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="SectionLabel" type="Label" parent="SafeArea/MainColumn/Scroll/Pad/Sections/AudioCard/Margin/VBox"]
layout_mode = 2
theme_type_variation = &"CardSectionLabel"
text = "SUARA"

[node name="MasterRow" type="VBoxContainer" parent="SafeArea/MainColumn/Scroll/Pad/Sections/AudioCard/Margin/VBox"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="MasterLabel" type="Label" parent="SafeArea/MainColumn/Scroll/Pad/Sections/AudioCard/Margin/VBox/MasterRow"]
layout_mode = 2
theme_type_variation = &"BodyLabel"
text = "Suara Utama"

[node name="MasterSlider" type="HSlider" parent="SafeArea/MainColumn/Scroll/Pad/Sections/AudioCard/Margin/VBox/MasterRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 56)
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"SettingsSlider"
max_value = 1.0
step = 0.01
value = 0.77

[node name="Rule1" type="HSeparator" parent="SafeArea/MainColumn/Scroll/Pad/Sections/AudioCard/Margin/VBox"]
layout_mode = 2
theme_type_variation = &"SettingsDivider"
```

…then `BgmRow` (`BgmLabel` "Musik", `BgmSlider`), `Rule2`, and `SfxRow` (`SfxLabel` "Efek Suara", `SfxSlider`), each identical in shape to `MasterRow` and `Rule1`.

`GameplayCard` has the same `Margin`/`VBox`/`SectionLabel` shape with text `PERMAINAN`, then:
```
[node name="TutorialRow" parent="SafeArea/MainColumn/Scroll/Pad/Sections/GameplayCard/Margin/VBox" instance=ExtResource("5_row")]
unique_name_in_owner = true
layout_mode = 2
label_text = "Tutorial Minigame"
```
then `Rule1` (a SettingsDivider), then `SkipDialogRow` with `label_text = "Lewati Dialog Minigame"`.

`DisplayCard` has the same shape with text `TAMPILAN`: `LookLayerRow` "Efek Visual", `Rule1`, `AmbientRow` "Efek Suasana", `Rule2`, `ReduceMotionRow` "Kurangi Gerakan", `Rule3`, `HapticsRow` "Getaran (Haptic)". All rows are `unique_name_in_owner = true`.

Write the whole file out, with no "…" left in it.

- [ ] **Step 7: Re-point `Scripts/UI/Settings.gd`**

Replace the six CheckButton `@onready` lines with:
```gdscript
@onready var _tutorial: CheckButton = %TutorialRow.toggle
@onready var _skip_dialog: CheckButton = %SkipDialogRow.toggle
@onready var _look_layer: CheckButton = %LookLayerRow.toggle
@onready var _ambient: CheckButton = %AmbientRow.toggle
@onready var _haptics: CheckButton = %HapticsRow.toggle
@onready var _reduce_motion: CheckButton = %ReduceMotionRow.toggle
```
Replace `Juice.stagger_in(_collect_rows())` with `Juice.stagger_in(_collect_cards())`, and replace `_collect_rows()` with:
```gdscript
## The three section cards, which pop in one after another on entry.
func _collect_cards() -> Array:
	return %Sections.get_children()
```

- [ ] **Step 8: Relaunch the worktree editor and run the tests.** Expected: `settings`, `shorten`, `back_controls`, `script_documentation`, `viewport_editability` and `device_back_button` all pass. If `test_every_card_fits_the_design_screen_without_scrolling` fails, its message gives the overflow in px. Tighten `Sections`' separation, `MainColumn`'s separation or the cards' `Margin` values (with the editor closed) until the cards fit, and record the values you used.

- [ ] **Step 9: Commit**

Include both new files and the `.gd.uid` the editor created, `Settings.tscn`, `Settings.gd` and the three test files. Revert `default_bus_layout.tres`.
Message: `feat(settings): Inventory-style layout with titled section cards`

---

### Task 3: Tall-phone contract for Settings

**Files:**
- Test: `tests/test_tall_screen_layout.gd` (a new block before `test_unique_name_paths_are_not_format_strings`)

- [ ] **Step 1: Write the tests**

```gdscript
# ── Settings ─────────────────────────────────────────────────────────────────

const SETTINGS := "res://Scenes/UI/Settings.tscn"


func test_settings_backdrop_fills() -> void:
	_assert_background_fills(_scene(SETTINGS).get_node_or_null("Background") as TextureRect,
		"Settings Background")


func test_settings_column_is_inside_the_safe_area() -> void:
	_assert_under_safe_area(_scene(SETTINGS).get_node_or_null("SafeArea/MainColumn"),
		"Settings MainColumn")


## The header stays at the safe area's top-left, and the scroll runs to the
## bottom margin, at `screen` size.
func _assert_settings_fills(screen: Vector2) -> void:
	var s := _stood_up(SETTINGS, screen)
	var header := s.get_node("SafeArea/MainColumn/Header") as Control
	var scroll := s.get_node("SafeArea/MainColumn/Scroll") as Control
	assert_eq(header.get_global_rect().position, Vector2(48, 48),
		"the header stays at the top at %s" % str(screen))
	assert_true(absf(scroll.get_global_rect().end.y - (screen.y - 48)) < 0.5,
		"the scroll ends at %d, expected %d" % [scroll.get_global_rect().end.y, screen.y - 48])


func test_settings_on_a_tall_phone() -> void:
	_assert_settings_fills(TALL)


func test_settings_at_the_design_size() -> void:
	_assert_settings_fills(DESIGN)
```

- [ ] **Step 2: Run** `test_run(suite="tall_screen_layout", session_id=<id>)` after a no-op `script_patch` on the file. Expected: all tests pass. Task 2 already built the layout, so these pin it rather than drive it. To prove they can fail, temporarily change `Vector2(48, 48)` to `Vector2(48, 49)`, confirm one failure, then revert.

- [ ] **Step 3: Commit.** Message: `test(settings): pin the tall-phone layout`

---

### Task 4: Docs, full suite, and a visual check

**Files:**
- Modify: `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Update `DEBT.md`.** In the upscaled-textures note, change `` `UI/BG.jpg` (1.47x up, CutScene and Settings) `` to `` `UI/BG.jpg` (1.47x up, CutScene) ``. Add a placeholder-art line in the placeholder inventory section (grep for the section that lists our own drawn SVGs, and follow its format): `Assets/Images/UI/Settings/switch_on.svg, switch_off.svg, slider_grabber.svg` — drawn by us for the Settings pass, drop-replaceable at the same size (112×64, 112×64, 56×56).

- [ ] **Step 2: Add a `CHANGELOG.md` entry** at the top, in the file's existing format: *Settings layout (2026-09-28)*. Settings moves to Inventory's look: the blurred Lobby backdrop, a header Card with Kembali and PENGATURAN, and SUARA/PERMAINAN/TAMPILAN section cards in a scroll. New `SettingsSwitch`, `SettingsSlider` and `SettingsDivider` variations, and a `SettingsToggleRow` template. Spec: `specs/2026-09-28-settings-layout-design.md`.

- [ ] **Step 3: Full suite.** Relaunch the worktree editor fresh, then run `test_run(session_id=<id>)` with no suite. Expected: everything passes. A lone theme failure may just be suite ordering, so re-run that suite alone before believing it. The bridge drops after a full run: stop the editor's PID once you have the results. Then check `git status` and revert `default_bus_layout.tres` and any `.import` rewrites. `kejartes_theme.tres` must be unchanged from Task 1's commit.

- [ ] **Step 4: Visual check.** Relaunch and run `project_run(mode="custom", scene="res://Scenes/UI/Settings.tscn", session_id=<id>)`. Wait for the entry stagger to finish, then take one full-size `editor_screenshot(source="game", max_resolution=0)`. Judge it against the approved mockup (option B): the header card, the three cards, the brown slider fill, and green and cream switches. Stop the game, and revert `default_bus_layout.tres`.

- [ ] **Step 5: Commit.** Message: `docs(settings): changelog and debt for the layout pass`

- [ ] **Step 6: Hand off.** Report to the user with the screenshot. Finishing the branch is the `ship-pr` skill's job, and only on the user's word.
