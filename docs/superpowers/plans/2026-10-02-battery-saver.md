# Battery Saver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cap the game at 60 fps by default, and add a saved "Hemat Baterai" switch that drops it to 30 fps.

**Architecture:** `project.godot` sets `application/run/max_fps=60`. `GameSettings` owns `battery_saver_enabled`; its setter applies `Engine.max_fps` (30 on, the project's 60 off) and emits `battery_saver_changed`. Settings gets a `BatterySaverRow` in the TAMPILAN card; the debug Look panel gets a switch.

**Tech Stack:** Godot 4.6 GDScript, McpTestSuite via the godot-ai bridge.

**Spec:** `docs/superpowers/specs/2026-10-02-battery-saver-design.md`

## Global Constraints

- Worktree `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/battery-saver`, branch `feat/battery-saver`.
- Scene work through the editor only (CLAUDE.md 4), and **scene work before script work** (4b). Never hand-edit `Settings.tscn`.
- No `theme_override_*`. The row is a `SettingsToggleRow` instance (`ExtResource("5_row")`), like `HdGraphicsRow`.
- Row label: `Hemat Baterai`. `SettingsToggleRow` has only `label_text`, so the spec's subtitle is dropped.
- Named consts, not inline numbers: `BATTERY_SAVER_FPS := 30` in `GameSettings.gd`.
- Every `@export`/file keeps its `##` docs (test_script_documentation).
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, written via `git commit -F`.

---

### Task 1: The cap and the setting

**Files:** Modify `project.godot`, `Scripts/GameSettings.gd`; Test `tests/test_settings.gd`, `tests/test_project_hygiene.gd`.

**Produces:** `GameSettings.battery_saver_enabled: bool`, `signal battery_saver_changed(enabled: bool)`, `const BATTERY_SAVER_FPS := 30`, `func normal_fps() -> int`.

- [ ] **Step 1: Failing tests.** Append to `tests/test_settings.gd`:

```gdscript
func test_battery_saver_default_off() -> void:
	var fresh: Node = (load("res://Scripts/GameSettings.gd") as GDScript).new()
	assert_false(fresh.get("battery_saver_enabled"), "Hemat Baterai defaults to off")
	fresh.free()


func test_battery_saver_caps_fps_persists_and_announces() -> void:
	var original_fps := Engine.max_fps
	var heard: Array = []
	var on_flip := func(enabled: bool) -> void: heard.append(enabled)
	GameSettings.battery_saver_changed.connect(on_flip)
	GameSettings.battery_saver_enabled = true
	GameSettings.battery_saver_enabled = true
	assert_eq(Engine.max_fps, GameSettings.BATTERY_SAVER_FPS, "on caps at 30")
	GameSettings.save_settings()
	GameSettings.battery_saver_changed.disconnect(on_flip)
	GameSettings.battery_saver_enabled = false
	assert_eq(Engine.max_fps, GameSettings.normal_fps(), "off returns to the project cap")
	GameSettings.load_settings()
	assert_true(GameSettings.battery_saver_enabled, "round-trips through save/load")
	assert_eq(heard, [true], "one emit per real flip")
	GameSettings.battery_saver_enabled = false
	GameSettings.save_settings()
	Engine.max_fps = original_fps
```

Append to `tests/test_project_hygiene.gd`:

```gdscript
## A 90-120 Hz phone otherwise renders up to 120 fps on still menus and runs
## warm (spec 2026-10-02-battery-saver-design.md).
func test_frame_rate_is_capped_at_60() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/max_fps", 0), 60,
		"project.godot caps the frame rate at 60")
```

- [ ] **Step 2:** `test_run(suite="settings")` and `test_run(suite="project_hygiene")`: the three new tests fail.

- [ ] **Step 3: Implement.** In `project.godot` `[application]` add `run/max_fps=60` (editor closed for this file, or via `ProjectSettings` + save in the editor). In `Scripts/GameSettings.gd`, after `look_layer_changed`:

```gdscript
## Hemat Baterai (2026-10-02, spec 2026-10-02-battery-saver-design.md): on,
## the game renders at BATTERY_SAVER_FPS instead of the project's cap (60),
## halving GPU work so the phone runs cooler. DEFAULT OFF. GameSettings
## applies it itself, at load and on every flip.
var battery_saver_enabled: bool = false:
	set(value):
		if battery_saver_enabled == value:
			return
		battery_saver_enabled = value
		_apply_frame_cap()
		battery_saver_changed.emit(value)

## Emitted when battery_saver_enabled flips.
signal battery_saver_changed(enabled: bool)

## Frame rate while Hemat Baterai is on.
const BATTERY_SAVER_FPS := 30


## The project's own cap (application/run/max_fps, 60).
func normal_fps() -> int:
	return int(ProjectSettings.get_setting("application/run/max_fps", 60))


func _apply_frame_cap() -> void:
	Engine.max_fps = BATTERY_SAVER_FPS if battery_saver_enabled else normal_fps()
```

In `save_settings()` add `config.set_value("pengaturan", "battery_saver", battery_saver_enabled)`; in `load_settings()` add `battery_saver_enabled = config.get_value("pengaturan", "battery_saver", false)`. Leave `_apply_frame_cap()` unguarded: the tests run in the editor and must see `Engine.max_fps` change, and every test restores it afterwards.

- [ ] **Step 4:** No-op `script_patch` GameSettings.gd, re-run both suites: pass.
- [ ] **Step 5:** Commit `feat(settings): cap at 60 fps; Hemat Baterai drops to 30`.

### Task 2: The Settings row and the debug switch

**Files:** Modify `Scenes/UI/Settings.tscn` (editor), `Scripts/UI/Settings.gd`, `Scripts/Debug/DebugLookPanel.gd`, `tests/test_settings.gd`.

- [ ] **Step 1: Failing tests.** In `tests/test_settings.gd`: `_SECTIONS["DisplayCard"]` rows become `["HdGraphicsRow", "BatterySaverRow", "LookLayerRow", "AmbientRow", "ReduceMotionRow", "HapticsRow"]`; add `"BatterySaverRow": "Hemat Baterai"` to `_ROW_LABELS` and `"BatterySaverRow": "battery_saver_enabled"` to `_ROW_SETTINGS`. Run `suite="settings"`: row tests fail.
- [ ] **Step 2: Scene (editor, first).** `scene_open Settings.tscn`; duplicate `HdGraphicsRow` plus a `SettingsDivider` HSeparator directly after it; name `BatterySaverRow`, `unique_name_in_owner=true`, `label_text="Hemat Baterai"`; order: HdGraphicsRow, Rule, BatterySaverRow, Rule0 …; `scene_save`; diff the `.tscn` (only the new nodes).
- [ ] **Step 3: Script.** `Settings.gd`: `@onready var _battery_saver: CheckButton = %BatterySaverRow.toggle`; in `_ready` `_battery_saver.button_pressed = GameSettings.battery_saver_enabled` and `_battery_saver.toggled.connect(_on_battery_saver_toggled)`; add

```gdscript
## "Hemat Baterai": caps the frame rate at 30 so the phone stays cooler.
## Off by default. Saved.
func _on_battery_saver_toggled(pressed: bool) -> void:
	GameSettings.battery_saver_enabled = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()
```

`DebugLookPanel.gd`, after the Grafis HD switch: `_add_setting_switch(vbox, " Hemat Baterai (30 FPS) ", "battery_saver_enabled")`.
- [ ] **Step 4:** No-op `script_patch` both scripts; `test_run(suite="settings")` passes, including the fit test.
- [ ] **Step 5:** Full-size screenshot of Settings (MAIN tab) with the new row; send to the user.
- [ ] **Step 6:** Commit `feat(settings): Hemat Baterai row and debug switch`; CHANGELOG entry; ship with `ship-pr`.
