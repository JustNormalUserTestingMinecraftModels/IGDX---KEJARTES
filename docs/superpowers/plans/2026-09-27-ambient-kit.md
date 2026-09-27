# Ambient Kit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The Godot bridge is single-client: subagents write files, the controlling session runs every `test_run` / editor call and hands results back.

**Goal:** Give the flat screens (MainMenu, LevelSelect, StudentCard, StudentList, ReportCard, CutScene, TesNotice, StatCheck, RunResult) a colour mood, soft light, drifting particles, glints and — on MainMenu and the desk screens — a bloom that stops below the UI, all behind a new **Efek Suasana** switch and frozen by **Kurangi Gerakan**.

**Architecture:** Five small `@tool` building blocks under `Scenes/Look/` + `Scripts/Look/` (`MoodTint`, `LightPool`, `AmbientParticles`, `AmbientGlow`, `DeskAmbience`) share one static helper, `AmbientKit`, which reads the two `GameSettings` switches, follows their change signals and re-fills a kit root's parent. A `glint.gdshader` material is shared by every glinting node and switched once by `LookLayer`. Screens place the pieces by hand in their `.tscn`: on the five glow screens the backdrop and kit move into a `World` CanvasLayer at −1 so `AmbientGlow` (a Canvas-mode `WorldEnvironment`, `background_canvas_max_layer = -1`) never blooms the UI.

**Tech Stack:** Godot 4.6 GDScript, godot-ai MCP bridge (`test_run`, `editor_manage`, `session_manage`, `filesystem_manage`, `script_patch`, `project_run`), McpTestSuite, Python + Pillow for offline pixel diffs.

**Spec:** `docs/superpowers/specs/2026-09-26-ambient-kit-design.md` (read its "Amendments from planning" section: it supersedes the body where they differ).

## Global Constraints

- Worktree `.claude/worktrees/ambient-kit`, branch `feat/ambient-kit` (already created from `origin/Textures`, spec commits on it). Every bridge call passes `session_id=<WT>` from Task 0. Never `session_activate`; never kill every Godot process; never touch the main checkout's editor.
- `Scripts/Balance.gd` and `Scripts/Debug/DebugManager.gd` are not touched (the latter is at its `LARGE_SCRIPTS` ceiling, 1,880 lines).
- **Clean code (`docs/superpowers/design/clean-code.md`).** A new script starts at zero debt: every `var`, parameter and return typed; no bare number inside a function body other than `0`, `1`, `2`, `-1`, `0.5` (name it in a `const` or `@export`); no function over 50 code lines; file name = `class_name`. A modified script's touched functions end no longer and no less typed than found.
- **Docs (`test_script_documentation`).** Every script opens with a `##` block; a `##` line sits immediately above every `@export` and every `const`.
- No `theme_override_*` except layout constants (`separation`, `margin_*`). No visual built at runtime: no `.new(` of a visual type and no `add_child` in any kit script.
- Test suites are `@tool`, override `suite_name()`, and no test is a coroutine. Fixtures are instanced once in `suite_setup`, never per test. A `test_run(suite=…)` name is the file's `suite_name()` value (`grep -n -A1 'func suite_name' tests/test_<x>.gd`), usually the file name without `test_`.
- **Scene files.** New scenes are written as text and never `scene_save`d. An EXISTING `.tscn` is hand-edited only while the worktree editor is closed (Recipe R). Nothing in this plan calls `scene_save`.
- **Scripts.** After writing a `.gd` while the editor runs: `filesystem_manage(op="scan", session_id=<WT>)`, then a no-op `script_patch` on that file (search and replace the same first line) before `test_run`. If a test then reports an unknown class (`MoodTint`, `LightPool`, …), do Recipe R instead.
- UI text Indonesian. Commits Conventional (`type(scope): …`), message written to a scratch file ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and committed with `git commit -F <file>`; plain git commands only (no `&&` chains, no heredocs).
- Before every commit: `git status --short`; revert `Assets/Audio/default_bus_layout.tres` and any boot-rewritten `*.png.import` with `git checkout -- <file>` **after** the worktree editor has exited, and only after confirming the diff is that known churn.
- Kit paths used everywhere below:
  `res://Scenes/Look/MoodTint.tscn`, `res://Scenes/Look/LightPool.tscn`, `res://Scenes/Look/AmbientParticles.tscn`, `res://Scenes/Look/AmbientGlow.tscn`, `res://Scenes/Look/DeskAmbience.tscn`, `res://Scripts/Shaders/glint_material.tres`.

### Recipe R — close, edit, relaunch the worktree editor

1. `editor_manage(op="quit", session_id=<WT>)`. If it times out: PowerShell `Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v%'" | Where-Object { $_.CommandLine -like '*worktrees\ambient-kit*' } | Select-Object ProcessId, CommandLine`, check the command line names this worktree, then `Stop-Process -Id <that pid>`. Never stop any other Godot process.
2. Make the file edits the task lists.
3. Launch detached (PowerShell):
   `Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = '"C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\ambient-kit" -e'; CurrentDirectory = 'C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\ambient-kit' }` — ReturnValue 0 means launched.
4. `session_manage(op="list")` until a session whose `project_path` is the worktree is `ready`; record its id as the new `<WT>` (it changes every launch).
5. `scene_open("res://Scenes/MainMenu/MainMenu.tscn", session_id=<WT>)`.

---

### Task 0: The worktree's editor

**Files:** none tracked.

- [ ] **Step 1: Seed the cache.** Copy `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main checkout's `.godot/` (`../../../.godot/` from the worktree) into the worktree's `.godot/`. Skip `.godot/editor/`.
- [ ] **Step 2: Launch.** Recipe R steps 3–5.
- [ ] **Step 3: Baseline.** `test_run(suite="settings", session_id=<WT>)`, `test_run(suite="look_layer", session_id=<WT>)`, `test_run(suite="tall_screen_layout", session_id=<WT>)`, `test_run(suite="main_menu", session_id=<WT>)`, `test_run(suite="clean_code", session_id=<WT>)`. Expected: all PASS. If any fails, stop and report — the branch starts from a red `Textures`.
- [ ] **Step 4:** `git status --short` and revert the known boot churn (Global Constraints).

---

### Task 1: The two switches — Efek Suasana, and a signal for Kurangi Gerakan

**Files:**
- Modify: `Scripts/GameSettings.gd` (the `reduce_motion` declaration, `save_settings`, `load_settings`)
- Modify: `Scenes/UI/Settings.tscn` (new `AmbientCard` after `LookLayerCard`) — Recipe R
- Modify: `Scripts/UI/Settings.gd` (`@onready`, `_ready`, new handler)
- Test: `tests/test_settings.gd`

**Interfaces:**
- Produces: `GameSettings.ambient_effects_enabled: bool` (default `true`), `signal ambient_effects_changed(enabled: bool)`, `signal reduce_motion_changed(still: bool)`; both setters emit only on a real change. Config key `[pengaturan] ambient_effects`. Settings node `%AmbientToggle` (CheckButton) in `SafeArea/Layout/AmbientCard`.

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_settings.gd` (add the `LayoutFrame` const beside the file's other consts):

```gdscript
const LayoutFrame := preload("res://tests/layout_frame.gd")


## Efek Suasana (ambient kit, 2026-09-26) is on until the player says
## otherwise: a fresh GameSettings, before any load, holds true.
func test_ambient_effects_default_on() -> void:
	var fresh: Node = (load("res://Scripts/GameSettings.gd") as GDScript).new()
	assert_true(fresh.get("ambient_effects_enabled"), "Efek Suasana defaults to on")
	fresh.free()


func test_ambient_effects_persist() -> void:
	GameSettings.ambient_effects_enabled = false
	GameSettings.save_settings()
	GameSettings.ambient_effects_enabled = true
	GameSettings.load_settings()
	assert_false(GameSettings.ambient_effects_enabled,
		"ambient_effects_enabled round-trips through save/load")
	GameSettings.ambient_effects_enabled = true
	GameSettings.save_settings()


## The kit follows both switches by signal. Each flip emits once, and setting
## the value it already holds emits nothing.
func test_the_kit_switches_announce_their_flips() -> void:
	var heard: Array = []
	var on_ambient := func(_enabled: bool) -> void: heard.append("ambient")
	var on_motion := func(_still: bool) -> void: heard.append("motion")
	GameSettings.ambient_effects_changed.connect(on_ambient)
	GameSettings.reduce_motion_changed.connect(on_motion)
	GameSettings.ambient_effects_enabled = false
	GameSettings.ambient_effects_enabled = false
	GameSettings.reduce_motion = true
	GameSettings.ambient_effects_changed.disconnect(on_ambient)
	GameSettings.reduce_motion_changed.disconnect(on_motion)
	GameSettings.ambient_effects_enabled = true
	GameSettings.reduce_motion = false
	assert_eq(heard, ["ambient", "motion"], "one emit per real flip, none for a repeat")


func test_ambient_toggle_reflects_and_writes_game_settings() -> void:
	var toggle := _screen.find_child("AmbientToggle", true, false) as CheckButton
	assert_true(toggle != null, "Efek Suasana needs its toggle")
	if toggle == null:
		return
	assert_eq(toggle.button_pressed, GameSettings.ambient_effects_enabled,
		"the toggle opens on the current value")
	var original := GameSettings.ambient_effects_enabled
	toggle.button_pressed = not original
	assert_eq(GameSettings.ambient_effects_enabled, not original,
		"the toggle must write through to GameSettings")
	GameSettings.ambient_effects_enabled = original


## Efek Suasana sits right after Efek Visual, labelled in Indonesian.
func test_ambient_card_sits_after_the_look_layer_card() -> void:
	var layout := _screen.find_child("Layout", true, false)
	var look := layout.get_node_or_null("LookLayerCard")
	var ambient := layout.get_node_or_null("AmbientCard")
	assert_true(ambient != null, "Settings needs an AmbientCard")
	if look == null or ambient == null:
		return
	assert_eq(ambient.get_index(), look.get_index() + 1,
		"Efek Suasana sits right after Efek Visual")
	var label := ambient.find_child("AmbientLabel", true, false) as Label
	assert_eq(label.text, "Efek Suasana", "the card is labelled in Indonesian")


## Every card and the back button still fit a 1080x1920 screen.
func test_every_row_fits_the_design_screen() -> void:
	var frame := track(LayoutFrame.stand_up("res://Scenes/UI/Settings.tscn",
		Vector2(1080, 1920))) as Control
	var back := frame.find_child("BackButton", true, false) as Control
	assert_true(back != null, "Settings needs its BackButton")
	if back == null:
		return
	assert_true(back.get_global_rect().end.y <= frame.get_global_rect().end.y,
		"the back button must end inside the screen, not below it")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on `tests/test_settings.gd`; `test_run(suite="settings", session_id=<WT>)`. Expected: FAIL — `ambient_effects_enabled` / signals not found, no `AmbientToggle`, no `AmbientCard`. (`test_every_row_fits_the_design_screen` may already pass; it is a guard.)

- [ ] **Step 3: GameSettings.** In `Scripts/GameSettings.gd` replace

```gdscript
## Reward motion (2026-09-23): true tells RewardFeedback to skip screenshake
## and screen confetti (sound and haptic still fire), for players who dislike
## motion. Saved beside the other switches.
var reduce_motion: bool = false
```

with

```gdscript
## Reward motion (2026-09-23): true tells RewardFeedback to skip screenshake
## and screen confetti (sound and haptic still fire), for players who dislike
## motion. Saved beside the other switches. Since the ambient kit (2026-09-26)
## it also freezes every kit piece, which follows the flip through
## reduce_motion_changed instead of polling.
var reduce_motion: bool = false:
	set(value):
		if reduce_motion == value:
			return
		reduce_motion = value
		reduce_motion_changed.emit(value)

## Emitted when reduce_motion flips.
signal reduce_motion_changed(still: bool)

## Ambient kit (docs/superpowers/specs/2026-09-26-ambient-kit-design.md):
## whether the colour moods, light pools, drifting particles, glints and the
## menu/desk bloom show at all. DEFAULT ON, unlike look_layer_enabled: each
## piece is cheap (at most 40 CPU particles, a few quads, one glow pass on
## five screens), and "Efek Suasana" in Settings turns it off for a slow phone.
var ambient_effects_enabled: bool = true:
	set(value):
		if ambient_effects_enabled == value:
			return
		ambient_effects_enabled = value
		ambient_effects_changed.emit(value)

## Emitted when ambient_effects_enabled flips.
signal ambient_effects_changed(enabled: bool)
```

In `save_settings()` add, after the `look_layer` line:

```gdscript
	config.set_value("pengaturan", "ambient_effects", ambient_effects_enabled)
```

In `load_settings()` add, after the `look_layer_enabled = …` line:

```gdscript
		ambient_effects_enabled = config.get_value("pengaturan", "ambient_effects", true)
```

- [ ] **Step 4: The Settings card (Recipe R).** Close the editor. In `Scenes/UI/Settings.tscn`, insert this block immediately before the line `[node name="HapticsCard" type="PanelContainer" parent="SafeArea/Layout" …]`:

```
[node name="AmbientCard" type="PanelContainer" parent="SafeArea/Layout"]
layout_mode = 2
theme_type_variation = &"Card"

[node name="Margin" type="MarginContainer" parent="SafeArea/Layout/AmbientCard"]
layout_mode = 2
theme_override_constants/margin_left = 24
theme_override_constants/margin_top = 20
theme_override_constants/margin_right = 24
theme_override_constants/margin_bottom = 20

[node name="HBox" type="HBoxContainer" parent="SafeArea/Layout/AmbientCard/Margin"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="AmbientLabel" type="Label" parent="SafeArea/Layout/AmbientCard/Margin/HBox"]
layout_mode = 2
theme_type_variation = &"BodyLabel"
text = "Efek Suasana"
size_flags_horizontal = 3
vertical_alignment = 1

[node name="AmbientToggle" type="CheckButton" parent="SafeArea/Layout/AmbientCard/Margin/HBox"]
unique_name_in_owner = true
layout_mode = 2

```

- [ ] **Step 5: Settings.gd.** Still with the editor closed, in `Scripts/UI/Settings.gd`:
  - after `@onready var _look_layer: CheckButton = %LookLayerToggle` add `@onready var _ambient: CheckButton = %AmbientToggle`;
  - in `_ready()`, after `_look_layer.button_pressed = GameSettings.look_layer_enabled` add `_ambient.button_pressed = GameSettings.ambient_effects_enabled`, and after `_look_layer.toggled.connect(_on_look_layer_toggled)` add `_ambient.toggled.connect(_on_ambient_toggled)`;
  - after `_on_look_layer_toggled` add:

```gdscript
## "Efek Suasana": the ambient kit -- colour moods, soft light, drifting
## particles, glints, and the bloom on the menu and desk screens. On by
## default. Setting the property emits ambient_effects_changed, which every
## kit piece follows at once. Saved.
func _on_ambient_toggled(pressed: bool) -> void:
	GameSettings.ambient_effects_enabled = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()
```

  Relaunch (Recipe R steps 3–5).

- [ ] **Step 6: Run green.** `test_run(suite="settings", session_id=<WT>)`, `test_run(suite="look_layer", session_id=<WT>)`, `test_run(suite="clean_code", session_id=<WT>)`. Expected: PASS. If only `test_every_row_fits_the_design_screen` fails, close the editor, change `SafeArea/Layout`'s `theme_override_constants/separation` from `24` to `16` in `Settings.tscn`, relaunch and re-run; if it still fails, stop and report.
- [ ] **Step 7: Commit.** `git add Scripts/GameSettings.gd Scripts/UI/Settings.gd Scenes/UI/Settings.tscn tests/test_settings.gd`; message `feat(settings): Efek Suasana switch and a reduce_motion change signal`.

---

### Task 2: `AmbientKit` and `MoodTint`

**Files:**
- Create: `Scripts/Look/AmbientKit.gd`, `Scripts/Look/MoodTint.gd`, `Scripts/Shaders/mood_tint.gdshader`, `Scenes/Look/MoodTint.tscn`
- Test: `tests/test_ambient_kit.gd` (new suite `ambient_kit`)

**Interfaces:**
- Consumes: Task 1's `GameSettings.ambient_effects_enabled`, `reduce_motion`, and both signals.
- Produces: `AmbientKit.is_enabled() -> bool`, `AmbientKit.is_still() -> bool`, `AmbientKit.follow_settings(apply: Callable) -> void` (calls `apply` now and on every flip; `apply` takes no arguments and must be a method of the calling node), `AmbientKit.fill_parent(node: Control) -> void`. `MoodTint` (`class_name`, extends `ColorRect`): `enum Mood { NETRAL, PAGI, SORE, MALAM, TEGANG }`, `const MOOD_COLORS: Dictionary`, `@export mood: Mood = NETRAL`, `@export strength: float = 0.35`, `@export vertical_falloff: float = 0.0`, `func tint_color() -> Color`.

- [ ] **Step 1: Write the failing suite** — `tests/test_ambient_kit.gd`:

```gdscript
@tool
extends McpTestSuite

## The ambient kit (spec docs/superpowers/specs/2026-09-26-ambient-kit-design.md,
## plan docs/superpowers/plans/2026-09-27-ambient-kit.md): the kit pieces, and
## where each screen places them.
##
## The pieces are stood up ONCE, in suite_setup, inside a sandbox SubViewport
## with its own World3D: per-test instancing floods the deferred-call queue on
## a full run, a full-rect Control added straight to the editor root would
## draw over the editor, and an AmbientGlow outside its own world would bloom
## the editor's.
##
## Must be @tool, and no test here may be a coroutine.

const MOOD_TINT := "res://Scenes/Look/MoodTint.tscn"

var _sandbox: SubViewport
var _tint: MoodTint


func suite_name() -> String:
	return "ambient_kit"


func suite_setup(_ctx: Dictionary) -> void:
	_sandbox = SubViewport.new()
	_sandbox.own_world_3d = true
	_sandbox.size = Vector2i(1080, 1920)
	_sandbox.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Engine.get_main_loop().root.add_child(_sandbox)
	_tint = _stand(MOOD_TINT) as MoodTint


func suite_teardown() -> void:
	if is_instance_valid(_sandbox):
		_sandbox.free()
	_sandbox = null


## The suite flips the real autoload's switches; put them back after each test.
func teardown() -> void:
	GameSettings.ambient_effects_enabled = true
	GameSettings.reduce_motion = false


func _stand(path: String) -> Node:
	var node := (load(path) as PackedScene).instantiate()
	_sandbox.add_child(node)
	return node


func _anchors(c: Control) -> Vector4:
	return Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom)


func _offsets(c: Control) -> Vector4:
	return Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)


# ── AmbientKit ───────────────────────────────────────────────────────────────

func test_the_kit_reads_both_switches() -> void:
	GameSettings.ambient_effects_enabled = false
	GameSettings.reduce_motion = true
	assert_false(AmbientKit.is_enabled(), "Efek Suasana off reads as disabled")
	assert_true(AmbientKit.is_still(), "Kurangi Gerakan on reads as still")


## A kit root that an editor save left zero-sized at its parent's corner
## (authoring guide, "Two ways the editor silently drops a Control's rect")
## goes back to Full Rect.
func test_fill_parent_restores_full_rect() -> void:
	var probe := Control.new()
	probe.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	probe.size = Vector2.ZERO
	AmbientKit.fill_parent(probe)
	assert_eq(_anchors(probe), Vector4(0, 0, 1, 1), "anchors are Full Rect again")
	assert_eq(_offsets(probe), Vector4.ZERO, "and carry no inset")
	probe.free()


## follow_settings connects a bound method, so freeing the node drops its
## connections: a freed kit piece never hears a later flip.
func test_a_freed_piece_leaves_no_connection_behind() -> void:
	var before := GameSettings.ambient_effects_changed.get_connections().size()
	var probe := (load(MOOD_TINT) as PackedScene).instantiate() as MoodTint
	AmbientKit.follow_settings(probe._refresh)
	assert_eq(GameSettings.ambient_effects_changed.get_connections().size(), before + 1,
		"following adds one connection")
	probe.free()
	assert_eq(GameSettings.ambient_effects_changed.get_connections().size(), before,
		"freeing the piece removes it again")


func test_every_kit_root_refills_its_parent() -> void:
	for path in ["res://Scripts/Look/MoodTint.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("AmbientKit.fill_parent(self)"),
			path + " must re-fill its parent in _ready")
		assert_true(src.contains("AmbientKit.follow_settings("),
			path + " must follow both switches")


# ── MoodTint ─────────────────────────────────────────────────────────────────

func test_mood_colours_fade_toward_white_by_strength() -> void:
	_tint.mood = MoodTint.Mood.PAGI
	_tint.strength = 1.0
	assert_eq(_tint.color, MoodTint.MOOD_COLORS[MoodTint.Mood.PAGI] as Color,
		"full strength is the mood colour")
	_tint.strength = 0.0
	assert_eq(_tint.color, Color.WHITE, "zero strength multiplies by white: no tint")
	_tint.strength = 0.5
	assert_eq(_tint.color,
		Color.WHITE.lerp(MoodTint.MOOD_COLORS[MoodTint.Mood.PAGI] as Color, 0.5),
		"half strength is half way to the mood colour")
	_tint.mood = MoodTint.Mood.NETRAL
	_tint.strength = 0.35


func test_every_mood_has_a_colour_and_netral_is_white() -> void:
	for mood in MoodTint.Mood.values():
		assert_true(MoodTint.MOOD_COLORS.has(mood), "mood %d needs a colour" % mood)
	assert_eq(MoodTint.MOOD_COLORS[MoodTint.Mood.NETRAL], Color.WHITE,
		"NETRAL multiplies by white and changes nothing")


## A multiply wash can only darken and tint, never paint over; it covers its
## parent and never takes a tap.
func test_the_tint_multiplies_fills_and_ignores_taps() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Shaders/mood_tint.gdshader")
	assert_true(src.contains("render_mode blend_mul"), "the tint is a multiply")
	assert_eq(_tint.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a full-screen tint must never eat a tap")
	assert_eq(_anchors(_tint), Vector4(0, 0, 1, 1), "MoodTint is Full Rect, so it covers a 20:9 phone")


## Each placed tint tunes its own falloff: the material is local to the scene.
func test_the_falloff_reaches_this_instance_only() -> void:
	var mat := _tint.material as ShaderMaterial
	assert_true(mat != null and mat.resource_local_to_scene,
		"MoodTint's material must be local to the scene")
	if mat == null:
		return
	_tint.vertical_falloff = 0.4
	assert_eq(float(mat.get_shader_parameter("vertical_falloff")), 0.4,
		"vertical_falloff reaches the shader")
	_tint.vertical_falloff = 0.0


func test_the_switch_hides_the_tint() -> void:
	GameSettings.ambient_effects_enabled = false
	assert_false(_tint.visible, "Efek Suasana off hides the tint")
	GameSettings.ambient_effects_enabled = true
	assert_true(_tint.visible, "and on brings it back")
	GameSettings.reduce_motion = true
	assert_true(_tint.visible, "a tint does not move, so Kurangi Gerakan keeps it")
```

- [ ] **Step 2: Run it red.** `filesystem_manage(op="scan", session_id=<WT>)`; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: the suite fails to load (unknown `MoodTint` / `AmbientKit`).

- [ ] **Step 3: Write `Scripts/Look/AmbientKit.gd`:**

```gdscript
@tool
class_name AmbientKit
extends RefCounted

## The ambient kit's shared plumbing (spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md). Every kit piece --
## MoodTint, LightPool, AmbientParticles, AmbientGlow, DeskAmbience -- asks
## GameSettings the same two questions, must hear the answers change without
## polling, and must fill its parent however an editor save left its root.
## This is the one place that does those three things, so the pieces cannot
## drift apart on them. Static only; nothing to instance.


## True while the player has Efek Suasana on.
static func is_enabled() -> bool:
	return GameSettings.ambient_effects_enabled


## True while the kit must hold still: Kurangi Gerakan is on.
static func is_still() -> bool:
	return GameSettings.reduce_motion


## Calls `apply` now, and again whenever either switch flips. `apply` must be a
## method of the calling node, never a lambda: a bound method's connections
## are dropped when its node is freed (pinned by test_ambient_kit), a
## lambda's are not.
static func follow_settings(apply: Callable) -> void:
	GameSettings.ambient_effects_changed.connect(apply.unbind(1))
	GameSettings.reduce_motion_changed.connect(apply.unbind(1))
	apply.call()


## Re-anchors `node` to fill its parent. An instanced scene's root under a
## plain Control is saved with `layout_mode = 0` and reloads zero-sized at the
## parent's top-left (authoring guide, "Two ways the editor silently drops a
## Control's rect"), so every kit root restores Full Rect itself in _ready.
static func fill_parent(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
```

- [ ] **Step 4: Write `Scripts/Shaders/mood_tint.gdshader`:**

```glsl
shader_type canvas_item;
render_mode blend_mul;

// MoodTint's wash (ambient kit, 2026-09-26). A multiply: the result is what
// was already drawn times this colour, so it can only darken and tint, and it
// reaches nothing drawn after it -- the UI above all. The colour is the
// ColorRect's own `color` (arriving here as COLOR), which MoodTint.gd sets
// from the mood and its strength; this shader only fades it toward white
// down the rect when `vertical_falloff` asks for a tint heavier at the top.

// 0 = even tint top to bottom; 1 = full at the top edge, none at the bottom.
uniform float vertical_falloff : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float weight = 1.0 - vertical_falloff * UV.y;
	COLOR = vec4(mix(vec3(1.0), COLOR.rgb, weight), 1.0);
}
```

- [ ] **Step 5: Write `Scripts/Look/MoodTint.gd`:**

```gdscript
@tool
class_name MoodTint
extends ColorRect

## A colour mood washed over a screen's backdrop (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 1).
## A multiply blend (mood_tint.gdshader), so it only darkens and tints what
## is drawn BEFORE it in the same canvas layer. Place it directly after the
## backdrop: everything drawn later -- the UI above all -- keeps its true
## colour, which a CanvasModulate (it tints its whole layer) could not promise.
## Efek Suasana off hides it; it does not move, so Kurangi Gerakan leaves it.

## The moods. NETRAL multiplies by white and changes nothing; it is the
## default so every placed tint writes its mood into the scene file.
enum Mood { NETRAL, PAGI, SORE, MALAM, TEGANG }

## Each mood's full-strength colour; `strength` fades it toward white.
## PAGI warm morning, SORE orange dusk, MALAM blue night, TEGANG the cooler,
## darker mood of the exam.
const MOOD_COLORS := {
	Mood.NETRAL: Color(1.0, 1.0, 1.0),
	Mood.PAGI: Color(1.0, 0.9, 0.74),
	Mood.SORE: Color(1.0, 0.72, 0.52),
	Mood.MALAM: Color(0.55, 0.62, 0.9),
	Mood.TEGANG: Color(0.72, 0.76, 0.86),
}

## Which mood this screen wears.
@export var mood: Mood = Mood.NETRAL:
	set(value):
		mood = value
		_refresh()

## How far toward the mood colour: 0 is no tint, 1 the full colour.
@export_range(0.0, 1.0, 0.01) var strength: float = 0.35:
	set(value):
		strength = value
		_refresh()

## How much heavier the tint sits at the top: 0 even, 1 fading to nothing at
## the bottom edge.
@export_range(0.0, 1.0, 0.01) var vertical_falloff: float = 0.0:
	set(value):
		vertical_falloff = value
		_refresh()


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AmbientKit.follow_settings(_refresh)


## The colour this node multiplies by: the mood faded toward white.
func tint_color() -> Color:
	return Color.WHITE.lerp(MOOD_COLORS[mood] as Color, strength)


func _refresh() -> void:
	color = tint_color()
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("vertical_falloff", vertical_falloff)
	visible = AmbientKit.is_enabled()
```

- [ ] **Step 6: Write `Scenes/Look/MoodTint.tscn`:**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Look/MoodTint.gd" id="1_script"]
[ext_resource type="Shader" path="res://Scripts/Shaders/mood_tint.gdshader" id="2_shader"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_tint"]
resource_local_to_scene = true
shader = ExtResource("2_shader")
shader_parameter/vertical_falloff = 0.0

[node name="MoodTint" type="ColorRect"]
material = SubResource("ShaderMaterial_tint")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_script")
```

- [ ] **Step 7: Run green.** `filesystem_manage(op="scan", session_id=<WT>)`; no-op `script_patch` on `Scripts/Look/AmbientKit.gd` and `Scripts/Look/MoodTint.gd`; `test_run(suite="ambient_kit", session_id=<WT>)`, `test_run(suite="script_documentation", session_id=<WT>)`, `test_run(suite="clean_code", session_id=<WT>)`, `test_run(suite="viewport_editability", session_id=<WT>)`. Expected: PASS. If `test_a_freed_piece_leaves_no_connection_behind` fails (the engine did not drop the unbound connection), change `follow_settings` to take the node too — `static func follow_settings(owner: Node, apply: Callable)` — and, after connecting, `owner.tree_exiting.connect(_forget.bind(apply.unbind(1)), CONNECT_ONE_SHOT)` with a `_forget(on_change: Callable)` that disconnects both signals; update the test and every caller to pass `self`. Do not continue with a leaking helper.
- [ ] **Step 8: Commit.** `git add Scripts/Look/AmbientKit.gd Scripts/Look/AmbientKit.gd.uid Scripts/Look/MoodTint.gd Scripts/Look/MoodTint.gd.uid Scripts/Shaders/mood_tint.gdshader Scripts/Shaders/mood_tint.gdshader.uid Scenes/Look/MoodTint.tscn tests/test_ambient_kit.gd tests/test_ambient_kit.gd.uid` (add whichever `.uid` files the scan created: `git status --short`); message `feat(look): AmbientKit plumbing and the MoodTint multiply wash`.

---

### Task 3: `LightPool`

**Files:**
- Create: `Scripts/Look/LightPool.gd`, `Scenes/Look/LightPool.tscn`
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `AmbientKit.*` (Task 2); the existing shaders `res://Scripts/Shaders/light_falloff.gdshader` (uniforms `light_color`, `intensity`, `radius`, `falloff`, `aspect`, `breathe_amount`, `breathe_speed`) and `res://Scripts/Shaders/light_shafts.gdshader` (`shaft_color`, `intensity`, `origin`, `shaft_count`, `softness`, `reach`, `drift_speed`) — unchanged.
- Produces: `LightPool` (`class_name`, extends `Control`, Full Rect root with children `Pool` (ColorRect, falloff material) and `Pool/Rays` (ColorRect, shafts material)). Consts `MAX_INTENSITY := 0.12`, `MAX_RAYS_INTENSITY := 0.2`. Exports: `center: Vector2 = (0.5, 0.5)` (share of the root rect), `pool_size: Vector2 = (1000, 1000)` px, `light_color: Color`, `intensity: float = 0.08` (clamped), `radius: float = 0.5`, `aspect: float = 1.0`, `breath_depth: float = 0.06`, `breath_speed: float = 0.35`, `rays_enabled: bool = false`, `rays_origin: Vector2 = (0.5, 0.5)`, `rays_intensity: float = 0.1` (clamped), `rays_drift_speed: float = 0.035`.

- [ ] **Step 1: Write the failing tests.** In `tests/test_ambient_kit.gd` add `const LIGHT_POOL := "res://Scenes/Look/LightPool.tscn"` under `MOOD_TINT`, `var _pool: LightPool` under `var _tint`, the line `_pool = _stand(LIGHT_POOL) as LightPool` at the end of `suite_setup`, add `"res://Scripts/Look/LightPool.gd"` to the path list in `test_every_kit_root_refills_its_parent`, and append:

```gdscript
# ── LightPool ────────────────────────────────────────────────────────────────

func _pool_mat() -> ShaderMaterial:
	return (_pool.get_node("Pool") as ColorRect).material as ShaderMaterial


func _rays_mat() -> ShaderMaterial:
	return (_pool.get_node("Pool/Rays") as ColorRect).material as ShaderMaterial


## Over this near-white palette additive light clips fast; neither intensity
## may pass the knee measured on the Lobby.
func test_the_pool_clamps_to_the_cream_knee() -> void:
	_pool.intensity = 0.5
	assert_eq(_pool.intensity, LightPool.MAX_INTENSITY, "intensity clamps to MAX_INTENSITY")
	assert_eq(float(_pool_mat().get_shader_parameter("intensity")), LightPool.MAX_INTENSITY,
		"and the shader gets the clamped value")
	assert_eq(LightPool.MAX_INTENSITY, 0.12, "the Lobby-measured knee (changelog 2026-09-22)")
	_pool.rays_intensity = 0.9
	assert_eq(_pool.rays_intensity, LightPool.MAX_RAYS_INTENSITY, "rays clamp too")
	_pool.intensity = 0.08
	_pool.rays_intensity = 0.1


## The root fills its parent; the Pool child is placed by `center` (a share of
## the root, so it keeps its spot on a tall phone) and sized by `pool_size`.
func test_the_pool_sits_where_center_says() -> void:
	assert_eq(_anchors(_pool), Vector4(0, 0, 1, 1), "the LightPool root is Full Rect")
	_pool.center = Vector2(0.25, 0.1)
	_pool.pool_size = Vector2(400, 200)
	var pool := _pool.get_node("Pool") as Control
	assert_eq(_anchors(pool), Vector4(0.25, 0.1, 0.25, 0.1), "Pool anchors on the centre point")
	assert_eq(_offsets(pool), Vector4(-200, -100, 200, 100), "Pool spans pool_size about it")
	_pool.center = Vector2(0.5, 0.5)
	_pool.pool_size = Vector2(1000, 1000)


func test_the_light_is_additive_local_and_untappable() -> void:
	assert_eq(_pool_mat().shader.resource_path, "res://Scripts/Shaders/light_falloff.gdshader",
		"the pool is light_falloff, unchanged")
	assert_true(_pool_mat().resource_local_to_scene, "each placed pool tunes its own copy")
	assert_eq(_rays_mat().shader.resource_path, "res://Scripts/Shaders/light_shafts.gdshader",
		"the rays are light_shafts, unchanged")
	assert_true(_rays_mat().resource_local_to_scene, "each placed pool's rays are its own")
	for path in [".", "Pool", "Pool/Rays"]:
		assert_eq((_pool.get_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s must never eat a tap" % path)


func test_rays_show_only_when_asked() -> void:
	_pool.rays_enabled = false
	assert_false((_pool.get_node("Pool/Rays") as CanvasItem).visible, "no rays by default")
	_pool.rays_enabled = true
	assert_true((_pool.get_node("Pool/Rays") as CanvasItem).visible, "rays_enabled shows them")
	_pool.rays_enabled = false


func test_reduce_motion_holds_the_light_still() -> void:
	_pool.rays_enabled = true
	GameSettings.reduce_motion = true
	assert_eq(float(_pool_mat().get_shader_parameter("breathe_amount")), 0.0, "no breathing when still")
	assert_eq(float(_rays_mat().get_shader_parameter("drift_speed")), 0.0, "no drift when still")
	assert_true(_pool.visible, "still is not off: the light stays")
	GameSettings.reduce_motion = false
	assert_eq(float(_pool_mat().get_shader_parameter("breathe_amount")), _pool.breath_depth,
		"breathing resumes")
	assert_eq(float(_rays_mat().get_shader_parameter("drift_speed")), _pool.rays_drift_speed,
		"drift resumes")
	_pool.rays_enabled = false


func test_the_switch_hides_the_pool() -> void:
	GameSettings.ambient_effects_enabled = false
	assert_false(_pool.visible, "Efek Suasana off hides the light")
	GameSettings.ambient_effects_enabled = true
	assert_true(_pool.visible, "and on brings it back")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on the test; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: the suite fails to load (unknown `LightPool`).

- [ ] **Step 3: Write `Scripts/Look/LightPool.gd`:**

```gdscript
@tool
class_name LightPool
extends Control

## A soft pool of light placed by hand over a screen (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 1).
##
## The root is a bare Full Rect anchor -- an instance root under a plain
## Control loses its rect on an editor save (authoring guide, Pattern C), so
## AmbientKit.fill_parent restores it -- and the Pool child draws. `center`
## places the pool as a share of the root's rect, so it keeps its spot on a
## tall phone; `pool_size` is its size in pixels. Place it as the child of an
## illustration instead (MainMenu's Logo/Spill) and it rides that art.
##
## Additive, through light_falloff.gdshader, so it only ever brightens. With
## `rays_enabled`, Pool/Rays draws slow shafts through light_shafts.gdshader.
## Both materials are local to the scene, so every placed pool tunes its own.
## Kurangi Gerakan stops the breathing and the drift; Efek Suasana off hides it.

## The brightest a pool may be. The Lobby's window light started clipping cream
## paper to white at 0.12 (light_falloff.gdshader, "THE CREAM PROBLEM";
## changelog 2026-09-22).
const MAX_INTENSITY := 0.12
## The brightest the rays may be: the Lobby's shafts ship at 0.20, the top of
## the range swept without clipping (light_shafts.gdshader's header).
const MAX_RAYS_INTENSITY := 0.2

## Where the pool's centre sits, as a share of this node's rect: (0, 0) the
## top-left corner, (1, 1) the bottom-right.
@export var center: Vector2 = Vector2(0.5, 0.5):
	set(value):
		center = value
		_place()

## The pool's width and height, in pixels.
@export var pool_size: Vector2 = Vector2(1000, 1000):
	set(value):
		pool_size = value
		_place()

## Colour of the light. Warm by default, to sit in the paper palette.
@export var light_color: Color = Color(1.0, 0.898, 0.706):
	set(value):
		light_color = value
		_refresh()

## Peak brightness at the centre; clamped to MAX_INTENSITY.
@export_range(0.0, 0.12, 0.005) var intensity: float = 0.08:
	set(value):
		intensity = minf(value, MAX_INTENSITY)
		_refresh()

## Where the light has faded to nothing, in the Pool's UV: 0.5 reaches its edge.
@export_range(0.05, 1.5, 0.01) var radius: float = 0.5:
	set(value):
		radius = value
		_refresh()

## Horizontal stretch of the pool; above 1 is wider than tall.
@export_range(0.1, 6.0, 0.05) var aspect: float = 1.0:
	set(value):
		aspect = value
		_refresh()

## How much the brightness breathes; 0 for none.
@export_range(0.0, 0.5, 0.01) var breath_depth: float = 0.06:
	set(value):
		breath_depth = value
		_refresh()

## Breaths per second.
@export_range(0.0, 2.0, 0.01) var breath_speed: float = 0.35:
	set(value):
		breath_speed = value
		_refresh()

## Draw slow light shafts converging on rays_origin.
@export var rays_enabled: bool = false:
	set(value):
		rays_enabled = value
		_refresh()

## Where the shafts converge, in the Pool's UV.
@export var rays_origin: Vector2 = Vector2(0.5, 0.5):
	set(value):
		rays_origin = value
		_refresh()

## Peak brightness of the shafts; clamped to MAX_RAYS_INTENSITY.
@export_range(0.0, 0.2, 0.005) var rays_intensity: float = 0.1:
	set(value):
		rays_intensity = minf(value, MAX_RAYS_INTENSITY)
		_refresh()

## How fast the shafts turn. Dust moves; sunlight does not strobe.
@export_range(0.0, 0.2, 0.005) var rays_drift_speed: float = 0.035:
	set(value):
		rays_drift_speed = value
		_refresh()

@onready var _pool: ColorRect = $Pool
@onready var _rays: ColorRect = $Pool/Rays


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place()
	AmbientKit.follow_settings(_refresh)


func _place() -> void:
	if not is_node_ready():
		return
	var half := pool_size * 0.5
	_pool.anchor_left = center.x
	_pool.anchor_right = center.x
	_pool.anchor_top = center.y
	_pool.anchor_bottom = center.y
	_pool.offset_left = -half.x
	_pool.offset_right = half.x
	_pool.offset_top = -half.y
	_pool.offset_bottom = half.y


func _refresh() -> void:
	if not is_node_ready():
		return
	var still := AmbientKit.is_still()
	_push_pool(still)
	_push_rays(still)
	visible = AmbientKit.is_enabled()


func _push_pool(still: bool) -> void:
	var mat := _pool.material as ShaderMaterial
	mat.set_shader_parameter("light_color", light_color)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("aspect", aspect)
	mat.set_shader_parameter("breathe_amount", 0.0 if still else breath_depth)
	mat.set_shader_parameter("breathe_speed", breath_speed)


func _push_rays(still: bool) -> void:
	_rays.visible = rays_enabled
	var mat := _rays.material as ShaderMaterial
	mat.set_shader_parameter("shaft_color", light_color)
	mat.set_shader_parameter("intensity", rays_intensity)
	mat.set_shader_parameter("origin", rays_origin)
	mat.set_shader_parameter("drift_speed", 0.0 if still else rays_drift_speed)
```

- [ ] **Step 4: Write `Scenes/Look/LightPool.tscn`:**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Look/LightPool.gd" id="1_script"]
[ext_resource type="Shader" path="res://Scripts/Shaders/light_falloff.gdshader" id="2_falloff"]
[ext_resource type="Shader" path="res://Scripts/Shaders/light_shafts.gdshader" id="3_shafts"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_pool"]
resource_local_to_scene = true
shader = ExtResource("2_falloff")

[sub_resource type="ShaderMaterial" id="ShaderMaterial_rays"]
resource_local_to_scene = true
shader = ExtResource("3_shafts")

[node name="LightPool" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_script")

[node name="Pool" type="ColorRect" parent="."]
material = SubResource("ShaderMaterial_pool")
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -500.0
offset_top = -500.0
offset_right = 500.0
offset_bottom = 500.0
mouse_filter = 2

[node name="Rays" type="ColorRect" parent="Pool"]
visible = false
material = SubResource("ShaderMaterial_rays")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
```

- [ ] **Step 5: Run green.** Scan; no-op `script_patch` on `Scripts/Look/LightPool.gd`; `test_run(suite="ambient_kit", session_id=<WT>)`, `script_documentation`, `clean_code`. Expected: PASS.
- [ ] **Step 6: Commit.** Add the new files (and their `.uid`s) plus the test; message `feat(look): LightPool, a placed additive pool with optional rays`.

---

### Task 4: `AmbientParticles`

**Files:**
- Create: `Scripts/Look/AmbientParticles.gd`, `Scenes/Look/AmbientParticles.tscn`
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `AmbientKit.*`; textures `res://Assets/Images/Particles/particle_glow.png` and `particle_spark.png` (unchanged).
- Produces: `AmbientParticles` (`class_name`, extends `Control`, Full Rect root with child `Emitter: CPUParticles2D`). `enum Preset { DEBU, KILAU }`, `const MAX_AMOUNT := 40`, `const PRESETS: Dictionary`, `static func amount_for(which: Preset, share: float) -> int`. Exports `preset: Preset = DEBU`, `density: float = 1.0`, `drift: Vector2 = (0.15, -1)`, `tint: Color = (1, 0.96, 0.86, 0.6)`.

- [ ] **Step 1: Write the failing tests.** In `tests/test_ambient_kit.gd` add `const AMBIENT_PARTICLES := "res://Scenes/Look/AmbientParticles.tscn"`, `var _particles: AmbientParticles`, `_particles = _stand(AMBIENT_PARTICLES) as AmbientParticles` at the end of `suite_setup`, `"res://Scripts/Look/AmbientParticles.gd"` in the refill path list, and append:

```gdscript
# ── AmbientParticles ─────────────────────────────────────────────────────────

func _emitter() -> CPUParticles2D:
	return _particles.get_node("Emitter") as CPUParticles2D


func test_the_count_never_passes_the_ceiling() -> void:
	assert_eq(AmbientParticles.MAX_AMOUNT, 40, "the ceiling is 40 (spec, section 1)")
	for which in AmbientParticles.Preset.values():
		assert_true(AmbientParticles.amount_for(which, 1.0) <= AmbientParticles.MAX_AMOUNT,
			"preset %d at full density stays under the ceiling" % which)
	assert_eq(AmbientParticles.amount_for(AmbientParticles.Preset.DEBU, 0.0), 1,
		"density 0 still leaves one particle; hide the node to have none")


## The emitter sits at the rect's centre and fills it, and re-fits on every
## resize: a Full Rect instance covers a 20:9 phone too. _fit is called
## directly so the test does not depend on when `resized` is delivered; the
## wiring is pinned by the source check.
func test_the_emitter_fills_the_rect() -> void:
	assert_eq(_anchors(_particles), Vector4(0, 0, 1, 1), "the root is Full Rect")
	var src := FileAccess.get_file_as_string("res://Scripts/Look/AmbientParticles.gd")
	assert_true(src.contains("resized.connect(_fit)"), "the emitter re-fits on resize")
	var was := _particles.size
	_particles.size = Vector2(1080, 2400)
	_particles.call("_fit")
	assert_eq(_emitter().position, Vector2(540, 1200), "the emitter sits at the centre")
	assert_eq(_emitter().emission_rect_extents, Vector2(540, 1200), "and spans the whole rect")
	_particles.size = was
	_particles.call("_fit")


func test_the_preset_sets_the_look() -> void:
	_particles.preset = AmbientParticles.Preset.KILAU
	assert_eq(_emitter().texture.resource_path, "res://Assets/Images/Particles/particle_spark.png",
		"KILAU is the spark")
	assert_eq(_emitter().amount,
		AmbientParticles.amount_for(AmbientParticles.Preset.KILAU, _particles.density),
		"at the preset's count")
	_particles.preset = AmbientParticles.Preset.DEBU
	assert_eq(_emitter().texture.resource_path, "res://Assets/Images/Particles/particle_glow.png",
		"DEBU is the soft glow")


func test_particles_are_additive_and_untappable() -> void:
	var mat := _emitter().material as CanvasItemMaterial
	assert_true(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"the specks read as light, so they add")
	assert_eq(_particles.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never eats a tap")


## A particle that may not move is not ambience: still or off, it stops and hides.
func test_off_or_still_stops_and_hides() -> void:
	GameSettings.reduce_motion = true
	assert_false(_emitter().emitting, "Kurangi Gerakan stops the emitter")
	assert_false(_particles.visible, "and hides it")
	GameSettings.reduce_motion = false
	assert_true(_emitter().emitting, "motion allowed again: it emits")
	assert_true(_particles.visible, "and shows")
	GameSettings.ambient_effects_enabled = false
	assert_false(_emitter().emitting, "Efek Suasana off stops it too")
	assert_false(_particles.visible, "and hides it")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on the test; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: load failure (unknown `AmbientParticles`).

- [ ] **Step 3: Write `Scripts/Look/AmbientParticles.gd`:**

```gdscript
@tool
class_name AmbientParticles
extends Control

## Ambient particles over an area of a screen (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 1 and
## amendment 4). The node's own rect is the area: the Emitter child sits at
## its centre and fills it, and re-fits on every resize, so a Full Rect
## instance covers a 20:9 phone as well as a 9:16 one.
##
## Additive, like SchoolDay's Motes, so the specks read as light; the
## Emitter's colour ramp fades each one in and out. Efek Suasana off, or
## Kurangi Gerakan on, stops the emitter and hides it.
##
## Leaves and petals (a DAUN preset) wait for the artist's sprite sheets:
## spec section 3 has the format.

## DEBU: slow dust drifting in the light. KILAU: small sparkles twinkling.
enum Preset { DEBU, KILAU }

## The most particles any emitter may carry. CPU particles at this count cost
## next to nothing on a phone; the preset counts sit well under it.
const MAX_AMOUNT := 40

## Each preset at density 1.0. Speeds in pixels per second, scales as a share
## of the 128 px texture, spin in degrees per second, spread in degrees.
const PRESETS := {
	Preset.DEBU: {
		"texture": preload("res://Assets/Images/Particles/particle_glow.png"),
		"amount": 24, "lifetime": 9.0, "spread": 30.0, "spin": 0.0,
		"speed_min": 10.0, "speed_max": 26.0, "scale_min": 0.06, "scale_max": 0.16,
	},
	Preset.KILAU: {
		"texture": preload("res://Assets/Images/Particles/particle_spark.png"),
		"amount": 16, "lifetime": 5.0, "spread": 45.0, "spin": 40.0,
		"speed_min": 8.0, "speed_max": 20.0, "scale_min": 0.08, "scale_max": 0.2,
	},
}

## Which particles.
@export var preset: Preset = Preset.DEBU:
	set(value):
		preset = value
		_refresh()

## Share of the preset's full count, 0 to 1 (at least one particle).
@export_range(0.0, 1.0, 0.05) var density: float = 1.0:
	set(value):
		density = value
		_refresh()

## Direction the particles drift; (0, -1) rises. Normalised before use.
@export var drift: Vector2 = Vector2(0.15, -1.0):
	set(value):
		drift = value
		_refresh()

## Colour the particles are multiplied by. They add, so a dim tint is a faint light.
@export var tint: Color = Color(1.0, 0.96, 0.86, 0.6):
	set(value):
		tint = value
		_refresh()

@onready var _emitter: CPUParticles2D = $Emitter


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)
	_fit()
	AmbientKit.follow_settings(_refresh)


## The emitter's count for `which` at `share` of full density, 1..MAX_AMOUNT.
static func amount_for(which: Preset, share: float) -> int:
	var full: int = PRESETS[which]["amount"]
	return clampi(roundi(full * share), 1, MAX_AMOUNT)


func _fit() -> void:
	if not is_node_ready():
		return
	_emitter.position = size * 0.5
	_emitter.emission_rect_extents = size * 0.5


func _refresh() -> void:
	if not is_node_ready():
		return
	_apply_look(PRESETS[preset])
	var shown := AmbientKit.is_enabled() and not AmbientKit.is_still()
	_emitter.emitting = shown
	visible = shown


func _apply_look(look: Dictionary) -> void:
	_emitter.texture = look["texture"]
	_emitter.amount = amount_for(preset, density)
	_emitter.lifetime = look["lifetime"]
	_emitter.preprocess = look["lifetime"]
	_emitter.direction = drift.normalized()
	_emitter.spread = look["spread"]
	_emitter.initial_velocity_min = look["speed_min"]
	_emitter.initial_velocity_max = look["speed_max"]
	_emitter.scale_amount_min = look["scale_min"]
	_emitter.scale_amount_max = look["scale_max"]
	_emitter.angular_velocity_min = -float(look["spin"])
	_emitter.angular_velocity_max = look["spin"]
	_emitter.color = tint
```

Note: `_fit()` also runs from `resized` before ready only if the signal fires early; the guard makes that a no-op.

- [ ] **Step 4: Write `Scenes/Look/AmbientParticles.tscn`:**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Look/AmbientParticles.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://Assets/Images/Particles/particle_glow.png" id="2_glow"]

[sub_resource type="CanvasItemMaterial" id="CanvasItemMaterial_add"]
blend_mode = 1

[sub_resource type="Gradient" id="Gradient_fade"]
offsets = PackedFloat32Array(0, 0.2, 0.8, 1)
colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0)

[node name="AmbientParticles" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_script")

[node name="Emitter" type="CPUParticles2D" parent="."]
material = SubResource("CanvasItemMaterial_add")
position = Vector2(540, 960)
amount = 24
lifetime = 9.0
preprocess = 9.0
texture = ExtResource("2_glow")
emission_shape = 3
emission_rect_extents = Vector2(540, 960)
gravity = Vector2(0, 0)
color_ramp = SubResource("Gradient_fade")
```

- [ ] **Step 5: Run green.** Scan; no-op `script_patch` on `Scripts/Look/AmbientParticles.gd`; `test_run(suite="ambient_kit", session_id=<WT>)`, `script_documentation`, `clean_code`, `viewport_editability`. Expected: PASS.
- [ ] **Step 6: Commit.** Message `feat(look): AmbientParticles, dust and sparkles that fill their rect`.

---

### Task 5: The glint

**Files:**
- Create: `Scripts/Shaders/glint.gdshader`, `Scripts/Shaders/glint_material.tres`
- Modify: `Scripts/Look/LookLayer.gd` (a const, three lines in `_ready`, two functions)
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `AmbientKit.is_enabled()`, `AmbientKit.is_still()`; Task 1's signals.
- Produces: `res://Scripts/Shaders/glint_material.tres` (shared, NOT local to scene) with uniforms `glint_color`, `strength`, `interval`, `sweep_seconds`, `band_width`, `angle`, `motion`. `LookLayer.glint_motion() -> float` (static: 1.0 when on and free to move, else 0.0).

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_ambient_kit.gd` (and add `const GLINT_MATERIAL := "res://Scripts/Shaders/glint_material.tres"` with the other consts):

```gdscript
# ── Glint ────────────────────────────────────────────────────────────────────

## The glint recolours the art's own pixels as a moving band; it never paints
## outside the texture's alpha, and every knob is a uniform.
func test_the_glint_is_a_band_inside_the_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Shaders/glint.gdshader")
	for knob in ["glint_color", "strength", "interval", "sweep_seconds", "band_width", "angle", "motion"]:
		assert_true(src.contains("uniform") and src.contains(" " + knob + " "),
			"glint.gdshader needs the `%s` uniform" % knob)
	assert_false(src.contains("blend_add"), "the glint recolours; it does not add light around the art")


## One material for every glinting node, so LookLayer switches them all at once.
func test_one_shared_glint_material() -> void:
	var mat := load(GLINT_MATERIAL) as ShaderMaterial
	assert_true(mat != null, "glint_material.tres must exist")
	if mat == null:
		return
	assert_false(mat.resource_local_to_scene, "shared, not local: LookLayer sets `motion` once for all")
	assert_eq(mat.shader.resource_path, "res://Scripts/Shaders/glint.gdshader", "wears the glint shader")


func test_the_glint_moves_only_when_the_kit_may() -> void:
	var look_layer: GDScript = load("res://Scripts/Look/LookLayer.gd")
	assert_eq(look_layer.call("glint_motion"), 1.0, "on and free to move: the band sweeps")
	GameSettings.reduce_motion = true
	assert_eq(look_layer.call("glint_motion"), 0.0, "Kurangi Gerakan stops the band")
	GameSettings.reduce_motion = false
	GameSettings.ambient_effects_enabled = false
	assert_eq(look_layer.call("glint_motion"), 0.0, "Efek Suasana off stops it too")


func test_look_layer_follows_both_switches_for_the_glint() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Look/LookLayer.gd")
	assert_true(src.contains("GameSettings.ambient_effects_changed.connect(_push_glint.unbind(1))"),
		"LookLayer follows Efek Suasana")
	assert_true(src.contains("GameSettings.reduce_motion_changed.connect(_push_glint.unbind(1))"),
		"LookLayer follows Kurangi Gerakan")
	assert_true(src.contains("GLINT_MATERIAL.set_shader_parameter(\"motion\", glint_motion())"),
		"and writes the shared material's motion")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on the test; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: the four glint tests FAIL (file missing, `glint_motion` not found).

- [ ] **Step 3: Write `Scripts/Shaders/glint.gdshader`:**

```glsl
shader_type canvas_item;

// A glint: a diagonal band of light sweeping across a texture every
// `interval` seconds, like the shine running over a trophy (ambient kit,
// 2026-09-26). It recolours the texture's own pixels and keeps their alpha,
// so nothing is drawn outside the art. Every glinting node shares
// glint_material.tres; LookLayer sets `motion` on it, once, from Efek
// Suasana and Kurangi Gerakan -- 0 parks the band off the art.

// Colour of the shine. Its alpha scales it further.
uniform vec4 glint_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
// How far the band pulls a pixel toward glint_color at its centre.
uniform float strength : hint_range(0.0, 1.0) = 0.55;
// Seconds from one sweep's start to the next.
uniform float interval : hint_range(1.0, 20.0) = 5.0;
// Seconds one sweep takes to cross the art.
uniform float sweep_seconds : hint_range(0.1, 3.0) = 0.8;
// Half-width of the band, in UV.
uniform float band_width : hint_range(0.02, 0.5) = 0.12;
// Direction the band travels, in radians from the +x axis; 0.6 runs
// down-right on a diagonal.
uniform float angle : hint_range(-3.2, 3.2) = 0.6;
// 1 = sweeping, 0 = parked (set by LookLayer).
uniform float motion : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float t = mod(TIME, interval) / sweep_seconds;
	vec2 dir = vec2(cos(angle), sin(angle));
	float along = dot(UV - vec2(0.5), dir) + 0.5;
	float centre = mix(-band_width - 0.25, 1.25 + band_width, clamp(t, 0.0, 1.0));
	float band = 1.0 - smoothstep(0.0, band_width, abs(along - centre));
	band *= step(t, 1.0) * motion;
	COLOR.rgb = mix(COLOR.rgb, glint_color.rgb, band * strength * glint_color.a);
}
```

- [ ] **Step 4: Write `Scripts/Shaders/glint_material.tres`:**

```
[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://Scripts/Shaders/glint.gdshader" id="1_glint"]

[resource]
shader = ExtResource("1_glint")
shader_parameter/glint_color = Color(1, 0.98, 0.9, 1)
shader_parameter/strength = 0.55
shader_parameter/interval = 5.0
shader_parameter/sweep_seconds = 0.8
shader_parameter/band_width = 0.12
shader_parameter/angle = 0.6
shader_parameter/motion = 1.0
```

- [ ] **Step 5: LookLayer.** In `Scripts/Look/LookLayer.gd`:
  - above `@onready var _cover` add:

```gdscript
## The ambient kit's glint (spec 2026-09-26, amendment 5): every glinting node
## wears this one shared material, so switching its `motion` here switches
## every glint in the game at once.
const GLINT_MATERIAL := preload("res://Scripts/Shaders/glint_material.tres")
```

  - in `_ready()`, right after `GameSettings.look_layer_changed.connect(_on_setting_changed)`, add:

```gdscript
	GameSettings.ambient_effects_changed.connect(_push_glint.unbind(1))
	GameSettings.reduce_motion_changed.connect(_push_glint.unbind(1))
	_push_glint()
```

  - after `_on_setting_changed`, add:

```gdscript
## 1.0 while the glint may sweep -- Efek Suasana on and Kurangi Gerakan off --
## else 0.0, which parks the band off the art.
static func glint_motion() -> float:
	if AmbientKit.is_enabled() and not AmbientKit.is_still():
		return 1.0
	return 0.0


func _push_glint() -> void:
	GLINT_MATERIAL.set_shader_parameter("motion", glint_motion())
```

- [ ] **Step 6: Run green.** Scan; no-op `script_patch` on `Scripts/Look/LookLayer.gd`; `test_run(suite="ambient_kit", session_id=<WT>)`, `look_layer`, `script_documentation`, `clean_code`. Expected: PASS.
- [ ] **Step 7: Commit.** Message `feat(look): a shared glint shader, switched by LookLayer`.

---

### Task 6: `AmbientGlow`

**Files:**
- Create: `Scripts/Look/AmbientGlow.gd`, `Scenes/Look/AmbientGlow.tscn`
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `AmbientKit.*`.
- Produces: `AmbientGlow` (`class_name`, extends `WorldEnvironment`) with a local-to-scene Canvas-mode `Environment` (`background_canvas_max_layer = -1`, screen blend). Exports `glow_threshold: float = 0.9`, `glow_intensity: float = 1.0`, `glow_strength: float = 1.0`.

- [ ] **Step 1: Write the failing tests.** Add `const AMBIENT_GLOW := "res://Scenes/Look/AmbientGlow.tscn"`, `var _glow: AmbientGlow`, `_glow = _stand(AMBIENT_GLOW) as AmbientGlow` at the end of `suite_setup`, and append:

```gdscript
# ── AmbientGlow ──────────────────────────────────────────────────────────────

## The Lobby's recipe: Canvas mode (the only mode that reaches 2D), screen
## blend, and max layer -1 so the UI on layer 0 is never bloomed.
func test_the_glow_is_the_lobby_recipe_below_the_ui() -> void:
	var env := _glow.environment
	assert_true(env != null, "AmbientGlow carries an Environment")
	if env == null:
		return
	assert_eq(env.background_mode, Environment.BG_CANVAS, "only Canvas mode reaches a 2D scene")
	assert_eq(env.background_canvas_max_layer, -1, "layers at -1 and below bloom; the UI on 0 never does")
	assert_eq(env.glow_blend_mode, Environment.GLOW_BLEND_MODE_SCREEN, "screen blend, as the Lobby")
	assert_true(env.resource_local_to_scene, "each screen tunes its own copy")


func test_the_knobs_reach_the_environment() -> void:
	_glow.glow_threshold = 0.93
	_glow.glow_intensity = 1.4
	_glow.glow_strength = 0.8
	var env := _glow.environment
	assert_true(is_equal_approx(env.glow_hdr_threshold, 0.93), "threshold reaches the environment")
	assert_true(is_equal_approx(env.glow_intensity, 1.4), "intensity reaches it")
	assert_true(is_equal_approx(env.glow_strength, 0.8), "strength reaches it")
	_glow.glow_threshold = 0.9
	_glow.glow_intensity = 1.0
	_glow.glow_strength = 1.0


func test_the_switch_turns_the_glow_off() -> void:
	GameSettings.ambient_effects_enabled = false
	assert_false(_glow.environment.glow_enabled, "Efek Suasana off turns the bloom off")
	GameSettings.ambient_effects_enabled = true
	assert_true(_glow.environment.glow_enabled, "and on turns it back on")
	GameSettings.reduce_motion = true
	assert_true(_glow.environment.glow_enabled, "bloom does not move, so Kurangi Gerakan keeps it")


func test_the_glow_follows_the_switch_in_ready() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Look/AmbientGlow.gd")
	assert_true(src.contains("AmbientKit.follow_settings(_refresh)"), "AmbientGlow follows Efek Suasana")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on the test; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: load failure (unknown `AmbientGlow`).

- [ ] **Step 3: Write `Scripts/Look/AmbientGlow.gd`:**

```gdscript
@tool
class_name AmbientGlow
extends WorldEnvironment

## Bloom for one screen's `World` layer (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, "Light bleed").
## The Lobby's recipe (Scenes/Lobby/lobby_environment.tres): a Canvas
## background, screen-blend glow, and background_canvas_max_layer = -1, so
## only CanvasLayers at -1 or below bloom and the UI on layer 0 never does.
## The Environment is local to the scene, so each screen's instance tunes its
## own copy. Tune it in the Inspector and watch the 2D view, which previews
## Canvas-mode glow live (changelog 2026-09-23).
##
## THE CREAM CATCH. hdr_2d is off (test_look_layer pins it), so nothing is
## brighter than 1.0, and this palette's paper, cloud and pale wood sit close
## to it. A threshold low enough to catch a light pool catches those too and
## fogs the screen: raise glow_threshold until the lightest surface stops
## blooming. Efek Suasana off turns the glow off; it does not move, so
## Kurangi Gerakan leaves it.

## Brightness above which a pixel blooms, 0 to 1. Keep it high; see the header.
@export_range(0.0, 1.0, 0.01) var glow_threshold: float = 0.9:
	set(value):
		glow_threshold = value
		_refresh()

## How strongly the bloom is added back (the Environment's glow_intensity).
@export_range(0.0, 4.0, 0.05) var glow_intensity: float = 1.0:
	set(value):
		glow_intensity = value
		_refresh()

## How far the bloom spreads (the Environment's glow_strength).
@export_range(0.0, 2.0, 0.05) var glow_strength: float = 1.0:
	set(value):
		glow_strength = value
		_refresh()


func _ready() -> void:
	AmbientKit.follow_settings(_refresh)


func _refresh() -> void:
	if environment == null:
		return
	environment.glow_hdr_threshold = glow_threshold
	environment.glow_intensity = glow_intensity
	environment.glow_strength = glow_strength
	environment.glow_enabled = AmbientKit.is_enabled()
```

- [ ] **Step 4: Write `Scenes/Look/AmbientGlow.tscn`:**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Look/AmbientGlow.gd" id="1_script"]

[sub_resource type="Environment" id="Environment_glow"]
resource_local_to_scene = true
background_mode = 3
background_canvas_max_layer = -1
glow_enabled = true
glow_intensity = 1.0
glow_strength = 1.0
glow_blend_mode = 1
glow_hdr_threshold = 0.9

[node name="AmbientGlow" type="WorldEnvironment"]
environment = SubResource("Environment_glow")
script = ExtResource("1_script")
```

- [ ] **Step 5: Run green.** Scan; no-op `script_patch` on `Scripts/Look/AmbientGlow.gd`; `test_run(suite="ambient_kit", session_id=<WT>)`, `look_layer` (still pins `hdr_2d` off), `script_documentation`, `clean_code`. Expected: PASS.
- [ ] **Step 6: Commit.** Message `feat(look): AmbientGlow, the Lobby's bloom as a placeable piece`.

---

### Task 7: `DeskAmbience`

**Files:**
- Create: `Scripts/Look/DeskAmbience.gd`, `Scenes/Look/DeskAmbience.tscn`
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `MoodTint`, `LightPool`, `AmbientParticles`, `AmbientGlow` (Tasks 2–6).
- Produces: `DeskAmbience` (`class_name`, extends `Control`, Full Rect) with children `Tint` (MoodTint, PAGI 0.3), `Lamp` (LightPool, centre (0.17, 0.09), 1200×1200, intensity 0.06), `Dust` (AmbientParticles, DEBU), `Glow` (AmbientGlow). Exports `particle_density: float = 1.0`, `glow_threshold: float = 0.9`, written through to `Dust.density` and `Glow.glow_threshold`.

- [ ] **Step 1: Write the failing tests.** Add `const DESK_AMBIENCE := "res://Scenes/Look/DeskAmbience.tscn"`, `var _desk: DeskAmbience`, `_desk = _stand(DESK_AMBIENCE) as DeskAmbience` at the end of `suite_setup`, `"res://Scripts/Look/DeskAmbience.gd"` in the refill path list, and append:

```gdscript
# ── DeskAmbience ─────────────────────────────────────────────────────────────

## The desk recipe, authored once: a warm morning tint, a lamp upper left
## (the game's light direction), dust in it, and the bloom.
func test_the_desk_recipe() -> void:
	var tint := _desk.get_node("Tint") as MoodTint
	var lamp := _desk.get_node("Lamp") as LightPool
	var dust := _desk.get_node("Dust") as AmbientParticles
	var glow := _desk.get_node("Glow") as AmbientGlow
	assert_true(tint != null and lamp != null and dust != null and glow != null,
		"DeskAmbience holds Tint, Lamp, Dust and Glow")
	if tint == null or lamp == null or dust == null or glow == null:
		return
	assert_eq(tint.mood, MoodTint.Mood.PAGI, "the desk wears the morning")
	assert_true(lamp.center.x < 0.5 and lamp.center.y < 0.5, "the lamp sits upper left")
	assert_eq(dust.preset, AmbientParticles.Preset.DEBU, "dust drifts in the lamp light")
	assert_true(tint.get_index() < lamp.get_index() and lamp.get_index() < dust.get_index(),
		"tint, then light, then particles")


## Overrides on an instance's children do not survive a save, so the two
## per-screen knobs live on the root and are written through.
func test_the_root_knobs_reach_the_children() -> void:
	_desk.particle_density = 0.5
	_desk.glow_threshold = 0.95
	assert_eq((_desk.get_node("Dust") as AmbientParticles).density, 0.5, "density reaches Dust")
	assert_eq((_desk.get_node("Glow") as AmbientGlow).glow_threshold, 0.95, "threshold reaches Glow")
	_desk.particle_density = 1.0
	_desk.glow_threshold = 0.9
	assert_eq(_anchors(_desk), Vector4(0, 0, 1, 1), "DeskAmbience is Full Rect")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on the test; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: load failure (unknown `DeskAmbience`).

- [ ] **Step 3: Write `Scripts/Look/DeskAmbience.gd`:**

```gdscript
@tool
class_name DeskAmbience
extends Control

## The desk recipe (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 2):
## LevelSelect, StudentCard, StudentList and ReportCard share one wooden desk,
## so they share one ambience -- a warm PAGI tint, a lamp pool upper left (the
## game's light comes from there; only the Lobby is lit from the right), dust
## drifting in it, and the bloom. Placed in each screen's `World` layer,
## directly after the backdrop.
##
## Overrides set on an instanced scene's children are dropped on save
## (CLAUDE.md, "Three save hazards"), so the two knobs a screen may need to
## change live here on the root and are written through to the children.

## Share of the dust's full count on this screen (Dust's density).
@export_range(0.0, 1.0, 0.05) var particle_density: float = 1.0:
	set(value):
		particle_density = value
		_refresh()

## Bloom threshold on this screen (Glow's glow_threshold).
@export_range(0.0, 1.0, 0.01) var glow_threshold: float = 0.9:
	set(value):
		glow_threshold = value
		_refresh()

@onready var _dust: AmbientParticles = $Dust
@onready var _glow: AmbientGlow = $Glow


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_dust.density = particle_density
	_glow.glow_threshold = glow_threshold
```

(DeskAmbience does not call `follow_settings`: each child follows the switches itself. The refill test's source check for `AmbientKit.follow_settings(` must therefore skip it — in `test_every_kit_root_refills_its_parent`, assert `follow_settings` only for paths other than `DeskAmbience.gd`: wrap that assert in `if not path.ends_with("DeskAmbience.gd"):`.)

- [ ] **Step 4: Write `Scenes/Look/DeskAmbience.tscn`:**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Look/DeskAmbience.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://Scenes/Look/MoodTint.tscn" id="2_tint"]
[ext_resource type="PackedScene" path="res://Scenes/Look/LightPool.tscn" id="3_pool"]
[ext_resource type="PackedScene" path="res://Scenes/Look/AmbientParticles.tscn" id="4_particles"]
[ext_resource type="PackedScene" path="res://Scenes/Look/AmbientGlow.tscn" id="5_glow"]

[node name="DeskAmbience" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_script")

[node name="Tint" parent="." instance=ExtResource("2_tint")]
layout_mode = 1
mood = 1
strength = 0.3

[node name="Lamp" parent="." instance=ExtResource("3_pool")]
layout_mode = 1
center = Vector2(0.17, 0.09)
pool_size = Vector2(1200, 1200)
intensity = 0.06

[node name="Dust" parent="." instance=ExtResource("4_particles")]
layout_mode = 1
drift = Vector2(0.3, -1)

[node name="Glow" parent="." instance=ExtResource("5_glow")]
```

- [ ] **Step 5: Run green.** Scan; no-op `script_patch` on `Scripts/Look/DeskAmbience.gd`; `test_run(suite="ambient_kit", session_id=<WT>)`, `script_documentation`, `clean_code`, `viewport_editability`. Expected: PASS.
- [ ] **Step 6: Commit.** Message `feat(look): DeskAmbience, the shared desk recipe`.

---

### Task 8: MainMenu wears the kit

**Files:**
- Modify: `Scenes/MainMenu/MainMenu.tscn` — Recipe R
- Modify: `Scripts/MainMenu/MainMenu.gd:27-28` (`$Logo` → `%Logo`, `$LogoShadow` → `%LogoShadow`)
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: every kit scene; `glint_material.tres`.
- Produces: MainMenu tree `World (CanvasLayer, layer -1)/{Background, Tint, Sun, Specks, LogoShadow, Logo, Logo/Spill}`, root child `Glow` (AmbientGlow). The census helpers below are reused by Tasks 9–11.

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_ambient_kit.gd` (with `const MAIN_MENU := "res://Scenes/MainMenu/MainMenu.tscn"` among the consts):

```gdscript
# ── Placement census (reads PackedScene state: no script runs) ──────────────

const KIT_SCENES := [MOOD_TINT, LIGHT_POOL, AMBIENT_PARTICLES, DESK_AMBIENCE]
const BUTTON_TYPES := ["Button", "TextureButton", "CheckButton", "CheckBox",
	"OptionButton", "MenuButton", "LinkButton"]


## Every node of `scene_path` in file (= tree) order: {path, type, instance,
## props}. `instance` is the instanced scene's path or "".
func _census(scene_path: String) -> Array[Dictionary]:
	var state := (load(scene_path) as PackedScene).get_state()
	var out: Array[Dictionary] = []
	for i in state.get_node_count():
		var inst := state.get_node_instance(i)
		var props := {}
		for j in state.get_node_property_count(i):
			props[str(state.get_node_property_name(i, j))] = state.get_node_property_value(i, j)
		out.append({
			"path": str(state.get_node_path(i)).trim_prefix("./"),
			"type": str(state.get_node_type(i)),
			"instance": inst.resource_path if inst != null else "",
			"props": props,
		})
	return out


func _entry(census: Array[Dictionary], path: String) -> Dictionary:
	for e in census:
		if e["path"] == path:
			return e
	return {}


func _prop(entry: Dictionary, name: String, fallback: Variant = null) -> Variant:
	return (entry.get("props", {}) as Dictionary).get(name, fallback)


## Direct children of `parent` ("." for the root), in draw order.
func _children_of(census: Array[Dictionary], parent: String) -> Array[String]:
	var out: Array[String] = []
	for e in census:
		var p: String = e["path"]
		if p == ".":
			continue
		var dad := "." if not p.contains("/") else p.get_base_dir()
		if dad == parent:
			out.append(p.get_file())
	return out


## A glow screen: `World` is a CanvasLayer at -1 holding the backdrop and only
## kit instances; nothing tappable sits in it; exactly one bloom exists.
func _assert_glow_screen(scene_path: String, backdrop: String) -> void:
	var census := _census(scene_path)
	var world := _entry(census, "World")
	assert_eq(world.get("type"), "CanvasLayer", scene_path + ": World must be a CanvasLayer")
	assert_eq(_prop(world, "layer"), -1, scene_path + ": World draws at -1, below the UI")
	assert_eq(_children_of(census, "World").find(backdrop), 0,
		scene_path + ": the backdrop is the first thing World draws")
	var blooms := 0
	for e in census:
		var p: String = e["path"]
		if e["instance"] == AMBIENT_GLOW or e["instance"] == DESK_AMBIENCE:
			blooms += 1
		if not p.begins_with("World/"):
			continue
		assert_false(BUTTON_TYPES.has(e["type"]), "%s: %s is tappable and must stay on layer 0" % [scene_path, p])
		if e["instance"] != "":
			assert_true(KIT_SCENES.has(e["instance"]),
				"%s: only kit pieces are instanced inside World (%s)" % [scene_path, p])
	assert_eq(blooms, 1, scene_path + ": exactly one AmbientGlow (a DeskAmbience carries one)")


# ── MainMenu ─────────────────────────────────────────────────────────────────

func test_main_menu_is_a_glow_screen() -> void:
	_assert_glow_screen(MAIN_MENU, "Background")


func test_main_menu_wears_the_morning_kit() -> void:
	var c := _census(MAIN_MENU)
	assert_eq(_children_of(c, "World"),
		["Background", "Tint", "Sun", "Specks", "LogoShadow", "Logo"] as Array[String],
		"backdrop, tint, sun, specks, then the logo and its shadow")
	assert_eq(_entry(c, "World/Tint").get("instance"), MOOD_TINT, "Tint is a MoodTint")
	assert_eq(_prop(_entry(c, "World/Tint"), "mood"), MoodTint.Mood.PAGI, "a warm morning")
	assert_eq(_entry(c, "World/Sun").get("instance"), LIGHT_POOL, "Sun is a LightPool")
	assert_eq(_prop(_entry(c, "World/Sun"), "rays_enabled"), true, "the sun throws rays")
	assert_eq(_entry(c, "World/Specks").get("instance"), AMBIENT_PARTICLES, "Specks are AmbientParticles")
	assert_eq(_entry(c, "World/Logo/Spill").get("instance"), LIGHT_POOL,
		"a spill pool rides the logo, drawn over it")
	var logo_mat: Variant = _prop(_entry(c, "World/Logo"), "material")
	assert_true(logo_mat is Material and (logo_mat as Material).resource_path == GLINT_MATERIAL,
		"the logo glints")
	assert_eq(_entry(c, "Glow").get("instance"), AMBIENT_GLOW, "the bloom sits at the root")


func test_main_menu_finds_its_logo_by_unique_name() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/MainMenu.gd")
	assert_true(src.contains("= %Logo") and src.contains("= %LogoShadow"),
		"the logo moved into World; MainMenu.gd must find it by unique name")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on the test; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: the three MainMenu tests FAIL (no `World`).

- [ ] **Step 3: Edit the scene (Recipe R, editor closed).** In `Scenes/MainMenu/MainMenu.tscn`:
  1. After the last `[ext_resource …]` line add:
     ```
     [ext_resource type="PackedScene" path="res://Scenes/Look/MoodTint.tscn" id="amb_tint"]
     [ext_resource type="PackedScene" path="res://Scenes/Look/LightPool.tscn" id="amb_pool"]
     [ext_resource type="PackedScene" path="res://Scenes/Look/AmbientParticles.tscn" id="amb_particles"]
     [ext_resource type="PackedScene" path="res://Scenes/Look/AmbientGlow.tscn" id="amb_glow"]
     [ext_resource type="Material" path="res://Scripts/Shaders/glint_material.tres" id="amb_glint"]
     ```
  2. Immediately before `[node name="Background" …]` insert:
     ```
     [node name="World" type="CanvasLayer" parent="."]
     layer = -1

     ```
  3. In the `Background`, `LogoShadow` and `Logo` node headers change `parent="."` to `parent="World"`.
  4. In the `LogoShadow` and `Logo` blocks add the line `unique_name_in_owner = true`; in the `Logo` block also add `material = ExtResource("amb_glint")`.
  5. Immediately after the `Background` block (before `LogoShadow`) insert:
     ```
     [node name="Tint" parent="World" instance=ExtResource("amb_tint")]
     mood = 1
     strength = 0.2

     [node name="Sun" parent="World" instance=ExtResource("amb_pool")]
     center = Vector2(0.83, 0.12)
     pool_size = Vector2(1200, 1200)
     intensity = 0.08
     rays_enabled = true

     [node name="Specks" parent="World" instance=ExtResource("amb_particles")]
     density = 0.5

     ```
  6. Immediately after the `Logo` block (before `SafeArea`) insert:
     ```
     [node name="Spill" parent="World/Logo" instance=ExtResource("amb_pool")]
     center = Vector2(0.75, 0.22)
     pool_size = Vector2(700, 700)
     intensity = 0.06
     breath_depth = 0.1

     [node name="Glow" parent="." instance=ExtResource("amb_glow")]
     glow_threshold = 0.9

     ```
  7. In `Scripts/MainMenu/MainMenu.gd` change `@onready var _logo: TextureRect = $Logo` to `@onready var _logo: TextureRect = %Logo` and `@onready var _logo_shadow: TextureRect = $LogoShadow` to `@onready var _logo_shadow: TextureRect = %LogoShadow`.
  Relaunch (Recipe R 3–5).

- [ ] **Step 4: Run green.** `test_run(suite="ambient_kit", session_id=<WT>)`, `main_menu`, `boot_screens`, `project_check`, `project_hygiene`, `clean_code`. Expected: PASS. (`test_main_menu` finds `Background`/`Logo` with `find_child`, so its paths need no change; the shadow is still drawn before the logo.)
- [ ] **Step 5: Look once.** `project_run(session_id=<WT>)`, wait for `helper_live`, `editor_screenshot(source="game", max_resolution=0, session_id=<WT>)`: the sky is warmer, a sun glows upper right with slow rays, specks rise, the logo shines every ~5 s, and the buttons and prompt keep their colours. `project_manage(op="stop", session_id=<WT>)`. Any error in `logs_read(source="game")` is a failure.
- [ ] **Step 6: Commit.** `git add Scenes/MainMenu/MainMenu.tscn Scripts/MainMenu/MainMenu.gd tests/test_ambient_kit.gd`; message `feat(main-menu): morning tint, sun, specks, a glinting logo and bloom`.

---

### Task 9: The desk screens, and the envelope seal

**Files:**
- Modify (Recipe R): `Scenes/LevelSelect/LevelSelect.tscn`, `Scenes/StudentCard/StudentCard.tscn`, `Scenes/StudentList/StudentList.tscn`, `Scenes/ReportCard/ReportCard.tscn`, `Scenes/LevelSelect/AmplopCard.tscn`
- Modify: `tests/test_tall_screen_layout.gd` (Backdrop paths)
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `DeskAmbience` (Task 7), glint material, the census helpers (Task 8).
- Produces: each desk screen's `World (layer -1)/{Backdrop, Desk}`; `Desk` is a DeskAmbience instance (StudentList with `particle_density = 0.5`). `AmplopCard.tscn`'s `Bob/Seal` wears the glint.

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_ambient_kit.gd`:

```gdscript
# ── The desk screens ─────────────────────────────────────────────────────────

const DESK_SCREENS := [
	"res://Scenes/LevelSelect/LevelSelect.tscn",
	"res://Scenes/StudentCard/StudentCard.tscn",
	"res://Scenes/StudentList/StudentList.tscn",
	"res://Scenes/ReportCard/ReportCard.tscn",
]


func test_every_desk_screen_is_a_glow_screen() -> void:
	for path in DESK_SCREENS:
		_assert_glow_screen(path, "Backdrop")


func test_every_desk_screen_wears_the_desk_recipe() -> void:
	for path in DESK_SCREENS:
		var c := _census(path)
		assert_eq(_children_of(c, "World"), ["Backdrop", "Desk"] as Array[String],
			path + ": World holds the desk and its ambience, nothing else")
		assert_eq(_entry(c, "World/Desk").get("instance"), DESK_AMBIENCE,
			path + ": Desk is a DeskAmbience")


func test_the_roster_list_keeps_its_dust_sparse() -> void:
	var c := _census("res://Scenes/StudentList/StudentList.tscn")
	assert_eq(_prop(_entry(c, "World/Desk"), "particle_density"), 0.5,
		"StudentList's cards are busy; half the dust")


func test_the_envelope_seal_glints() -> void:
	var c := _census("res://Scenes/LevelSelect/AmplopCard.tscn")
	var mat: Variant = _prop(_entry(c, "Bob/Seal"), "material")
	assert_true(mat is Material and (mat as Material).resource_path == GLINT_MATERIAL,
		"the wax seal glints")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on the test; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: the four new tests FAIL.

- [ ] **Step 3: Edit the scenes (Recipe R, editor closed).** For each of `LevelSelect.tscn`, `StudentCard.tscn`, `StudentList.tscn`, `ReportCard.tscn`:
  1. After the last `[ext_resource …]` line add `[ext_resource type="PackedScene" path="res://Scenes/Look/DeskAmbience.tscn" id="amb_desk"]`.
  2. Immediately before `[node name="Backdrop" type="TextureRect" parent="." …]` insert:
     ```
     [node name="World" type="CanvasLayer" parent="."]
     layer = -1

     ```
  3. In the `Backdrop` header change `parent="."` to `parent="World"`.
  4. Immediately after the `Backdrop` block insert (StudentList adds the `particle_density` line; the others omit it):
     ```
     [node name="Desk" parent="World" instance=ExtResource("amb_desk")]
     particle_density = 0.5

     ```
  In `Scenes/LevelSelect/AmplopCard.tscn`: add `[ext_resource type="Material" path="res://Scripts/Shaders/glint_material.tres" id="amb_glint"]` after the last `ext_resource`, and the line `material = ExtResource("amb_glint")` directly under the `[node name="Seal" …]` header.
  In `tests/test_tall_screen_layout.gd`, in the StudentCard, StudentList, LevelSelect and Rapor sections, change every `get_node("Backdrop")` / `get_node_or_null("Backdrop")` to `"World/Backdrop"`. Check: `grep -n '"Backdrop"' tests/test_tall_screen_layout.gd` prints nothing (the Lobby's is already `"World/Backdrop"`).
  Relaunch (Recipe R 3–5).

- [ ] **Step 4: Run green.** `test_run(suite="ambient_kit", session_id=<WT>)`, `tall_screen_layout`, `level_select`, `student_card_layout`, `student_list`, `report_card` (run whichever of these suite names exist: `ls tests | grep -E 'level_select|student_card|student_list|report_card'`), `project_check`, `clean_code`. Expected: PASS.
- [ ] **Step 5: Look once each.** Run the game; for LevelSelect and StudentList/ReportCard (which need a roster) first seed: debug overlay → General → Seed Playtest State, then Scenes → StudentCard; for the others use `editor_manage(op="game_eval", session_id=<WT>, …)` with `Transition.change_scene("res://Scenes/LevelSelect/LevelSelect.tscn")` (and the StudentList / ReportCard paths). One full-size `editor_screenshot(source="game", max_resolution=0)` per screen: the wood is warmer, a lamp glow sits upper left with dust in it, the papers, envelopes and buttons are untouched and still respond to taps. Stop the game.
- [ ] **Step 6: Commit.** `git add` the five scenes, `tests/test_tall_screen_layout.gd`, `tests/test_ambient_kit.gd`; message `feat(desk): DeskAmbience on the four desk screens, a glinting seal`.

---

### Task 10: CutScene and the exam screens

**Files:**
- Modify (Recipe R): `Scenes/CutScene/CutScene.tscn`, `Scenes/EndGame/TesNotice.tscn`, `Scenes/EndGame/StatCheck.tscn`
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `LightPool`, `AmbientParticles`, `MoodTint`; census helpers.
- Produces: CutScene root children `BgCutScene, Sun, Sparkles, …` (no World, no glow); TesNotice and StatCheck root children `Backdrop, Tint, …` with `Tint` a TEGANG MoodTint; ExamProgress unchanged.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
# ── CutScene and the exam screens (layer 0, no bloom: amendment 1) ──────────

func test_cutscene_gets_a_soft_sun_and_sparkles() -> void:
	var c := _census("res://Scenes/CutScene/CutScene.tscn")
	var kids := _children_of(c, ".")
	assert_eq(kids.slice(0, 3), ["BgCutScene", "Sun", "Sparkles"] as Array[String],
		"the pieces sit right over the picture, under the dialogue and the fade")
	assert_eq(_entry(c, "Sun").get("instance"), LIGHT_POOL, "Sun is a LightPool")
	assert_eq(_prop(_entry(c, "Sparkles"), "preset"), AmbientParticles.Preset.KILAU, "sparkles, not dust")
	assert_true(_entry(c, "World").is_empty(), "no World layer: the picture changes slide to slide")


func test_the_exam_notices_wear_the_tense_mood() -> void:
	for path in ["res://Scenes/EndGame/TesNotice.tscn", "res://Scenes/EndGame/StatCheck.tscn"]:
		var c := _census(path)
		var kids := _children_of(c, ".")
		assert_eq(kids.find("Tint"), kids.find("Backdrop") + 1,
			path + ": the tint sits directly after the backdrop, so it tints nothing else")
		assert_eq(_entry(c, "Tint").get("instance"), MOOD_TINT, path + ": Tint is a MoodTint")
		assert_eq(_prop(_entry(c, "Tint"), "mood"), MoodTint.Mood.TEGANG, path + ": the exam mood")


## ExamProgress's art was left undarkened on 2026-09-20 so text_primary reads
## at ~4.6:1 over it; a multiply would cut that (amendment 2).
func test_exam_progress_stays_undarkened() -> void:
	var c := _census("res://Scenes/EndGame/ExamProgress.tscn")
	for e in c:
		assert_ne(e["instance"], MOOD_TINT, "ExamProgress takes no tint")
```

- [ ] **Step 2: Run it red.** No-op `script_patch`; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: the CutScene and exam-notice tests FAIL; `test_exam_progress_stays_undarkened` passes (it is a guard).

- [ ] **Step 3: Edit the scenes (Recipe R, editor closed).**
  `Scenes/CutScene/CutScene.tscn`: add after the last `ext_resource`
  ```
  [ext_resource type="PackedScene" path="res://Scenes/Look/LightPool.tscn" id="amb_pool"]
  [ext_resource type="PackedScene" path="res://Scenes/Look/AmbientParticles.tscn" id="amb_particles"]
  ```
  and immediately after the `BgCutScene` block (before `DialogueBox`):
  ```
  [node name="Sun" parent="." instance=ExtResource("amb_pool")]
  center = Vector2(0.8, 0.08)
  pool_size = Vector2(1100, 1100)
  intensity = 0.06

  [node name="Sparkles" parent="." instance=ExtResource("amb_particles")]
  preset = 1
  density = 0.6
  drift = Vector2(1, -0.2)

  ```
  `Scenes/EndGame/TesNotice.tscn` and `Scenes/EndGame/StatCheck.tscn`: add after the last `ext_resource`
  `[ext_resource type="PackedScene" path="res://Scenes/Look/MoodTint.tscn" id="amb_tint"]`
  and immediately after the `Backdrop` block:
  ```
  [node name="Tint" parent="." instance=ExtResource("amb_tint")]
  mood = 4
  strength = 0.3

  ```
  Relaunch (Recipe R 3–5).

- [ ] **Step 4: Run green.** `test_run(suite="ambient_kit", session_id=<WT>)`, `cutscene`, `tes_notice`, `stat_check`, `exam_progress`, `end_game_rehearsal`, `project_check`, `clean_code`. Expected: PASS.
- [ ] **Step 5: Look once.** Run the game; `game_eval` a `Transition.change_scene("res://Scenes/CutScene/CutScene.tscn")`, screenshot at full size (sun and drifting sparkles over the picture, the dialogue box and fade unaffected). For TesNotice and StatCheck, arm the **Gladi Resik** rehearsal as in memory note `freeze-game-time-for-screenshots` (arm, change scene, wait on a node condition, freeze), and screenshot: the blurred school is cooler and darker, the notice card and its text unchanged. Stop the game.
- [ ] **Step 6: Commit.** Message `feat(end-game): a sun and sparkles for the cutscene, the exam mood for the notices`.

---

### Task 11: RunResult, pass or fail

**Files:**
- Modify (Recipe R): `Scenes/EndGame/RunResult.tscn`
- Modify: `Scripts/EndGame/RunResult.gd` (`@onready` pair, `_passed`, `_compute_grade`, new `_dress_ambience`, one call in `_ready`)
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `MoodTint`, `LightPool`, `AmbientParticles`, glint material; the verdict `not GameState.run_failed and GameState.check_semester_passed()` that `_compute_grade` already computes.
- Produces: RunResult root children `WinStage, BlurLayer, AmbientPass, AmbientFail, MarginContainer`; `AmbientPass/{Tint (PAGI), Warm (LightPool), Sparkles (KILAU)}`, `AmbientFail/{Tint (MALAM), Dust (DEBU, 0.4)}`; `GradeBadge` wears the glint on a pass only.

- [ ] **Step 1: Write the failing tests.** Append:

```gdscript
# ── RunResult ────────────────────────────────────────────────────────────────

const RUN_RESULT := "res://Scenes/EndGame/RunResult.tscn"


func test_run_result_carries_both_moods_over_the_blur() -> void:
	var c := _census(RUN_RESULT)
	assert_eq(_children_of(c, ".").slice(0, 4),
		["WinStage", "BlurLayer", "AmbientPass", "AmbientFail"] as Array[String],
		"both moods draw over the blurred stage, under the report")
	assert_eq(_prop(_entry(c, "AmbientPass/Tint"), "mood"), MoodTint.Mood.PAGI, "a pass is warm")
	assert_eq(_entry(c, "AmbientPass/Warm").get("instance"), LIGHT_POOL, "with light behind the grade")
	assert_eq(_prop(_entry(c, "AmbientPass/Sparkles"), "preset"), AmbientParticles.Preset.KILAU,
		"and sparkles")
	assert_eq(_prop(_entry(c, "AmbientFail/Tint"), "mood"), MoodTint.Mood.MALAM, "a fail is night")
	assert_eq(_entry(c, "AmbientFail/Dust").get("instance"), AMBIENT_PARTICLES, "with slow dust")
	var badge_mat: Variant = _prop(_entry(c, "MarginContainer/Column/GradeCard/GradeStack/GradeBadge"), "material")
	assert_true(badge_mat is Material and (badge_mat as Material).resource_path == GLINT_MATERIAL,
		"the grade badge glints")


## RunResult is not @tool, so its choice is pinned in the source: one group
## from the same verdict the letter used, and no glint on a failing badge.
func test_run_result_picks_one_mood_from_the_verdict() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/RunResult.gd")
	assert_true(src.contains("ambient_pass.visible = _passed"), "a pass shows AmbientPass")
	assert_true(src.contains("ambient_fail.visible = not _passed"), "a fail shows AmbientFail")
	assert_true(src.contains("grade_badge.material = null"), "a failing badge does not shine")
	assert_true(src.contains("_dress_ambience()"), "_ready dresses the ambience")
```

- [ ] **Step 2: Run it red.** No-op `script_patch`; `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: both FAIL.

- [ ] **Step 3: Edit the scene (Recipe R, editor closed).** In `Scenes/EndGame/RunResult.tscn`:
  1. After the last `ext_resource` add:
     ```
     [ext_resource type="PackedScene" path="res://Scenes/Look/MoodTint.tscn" id="amb_tint"]
     [ext_resource type="PackedScene" path="res://Scenes/Look/LightPool.tscn" id="amb_pool"]
     [ext_resource type="PackedScene" path="res://Scenes/Look/AmbientParticles.tscn" id="amb_particles"]
     [ext_resource type="Material" path="res://Scripts/Shaders/glint_material.tres" id="amb_glint"]
     ```
  2. Immediately after the `BlurLayer` block (before `MarginContainer`) insert:
     ```
     [node name="AmbientPass" type="Control" parent="."]
     visible = false
     layout_mode = 1
     anchors_preset = 15
     anchor_right = 1.0
     anchor_bottom = 1.0
     grow_horizontal = 2
     grow_vertical = 2
     mouse_filter = 2

     [node name="Tint" parent="AmbientPass" instance=ExtResource("amb_tint")]
     mood = 1
     strength = 0.25

     [node name="Warm" parent="AmbientPass" instance=ExtResource("amb_pool")]
     center = Vector2(0.5, 0.33)
     pool_size = Vector2(1100, 900)
     intensity = 0.08

     [node name="Sparkles" parent="AmbientPass" instance=ExtResource("amb_particles")]
     preset = 1

     [node name="AmbientFail" type="Control" parent="."]
     visible = false
     layout_mode = 1
     anchors_preset = 15
     anchor_right = 1.0
     anchor_bottom = 1.0
     grow_horizontal = 2
     grow_vertical = 2
     mouse_filter = 2

     [node name="Tint" parent="AmbientFail" instance=ExtResource("amb_tint")]
     mood = 3
     strength = 0.35

     [node name="Dust" parent="AmbientFail" instance=ExtResource("amb_particles")]
     density = 0.4
     drift = Vector2(0, -1)

     ```
  3. In the `GradeBadge` block add `material = ExtResource("amb_glint")`.

  In `Scripts/EndGame/RunResult.gd`:
  - after `@onready var btn_selesai: Button = …` add
    ```gdscript
    @onready var ambient_pass: Control = $AmbientPass
    @onready var ambient_fail: Control = $AmbientFail
    ```
  - after `var _exiting: bool = false` add
    ```gdscript
    ## The verdict _compute_grade reached; _dress_ambience reads it.
    var _passed: bool = false
    ```
  - in `_compute_grade()` replace `var passed := not GameState.run_failed and GameState.check_semester_passed()` with `_passed = not GameState.run_failed and GameState.check_semester_passed()`, and `RunGrade.letter(run_score, passed)` with `RunGrade.letter(run_score, _passed)`;
  - in `_ready()` add `_dress_ambience()` on the line after `_compute_grade()`;
  - after `_compute_grade()` add:
    ```gdscript
    ## The ambient kit's two moods (spec 2026-09-26, section 2): warm light and
    ## sparkles for a pass, a blue night and slow dust for a fail. Both groups
    ## are authored in the scene; this only picks one, from the verdict the
    ## grade letter used, and takes the glint off a failing badge.
    func _dress_ambience() -> void:
    	ambient_pass.visible = _passed
    	ambient_fail.visible = not _passed
    	if not _passed:
    		grade_badge.material = null
    ```
  Relaunch (Recipe R 3–5).

- [ ] **Step 4: Run green.** `test_run(suite="ambient_kit", session_id=<WT>)`, `run_result`, `run_grade_ranks`, `end_cutscene`, `back_controls`, `viewport_editability`, `clean_code`. Expected: PASS (`test_run_result`'s "WinStage draws first" and "WinStage before BlurLayer" still hold).
- [ ] **Step 5: Look twice.** Rehearse *Semua Lulus* and then *Semua Gagal* (memory note `freeze-game-time-for-screenshots`; wait until `GradeBadge.texture != null`, freeze at `Engine.time_scale = 0.02`), one full-size screenshot each. Pass: warm, a glow behind the grade card, sparkles, the badge shines. Fail: cool blue, slow dust, no shine. **Stop the game — never press "Kembali ke Menu"** (it runs grade progression).
- [ ] **Step 6: Commit.** Message `feat(run-result): a warm mood for a pass, a night for a fail`.

---

### Task 12: Tune on frozen frames, and prove the UI untouched

**Files:**
- Modify (Recipe R, values only): `Scenes/Look/DeskAmbience.tscn`, `Scenes/MainMenu/MainMenu.tscn`, and any screen whose knob changes
- Create (scratch, not committed): `<scratchpad>/ambient/` captures and `diff.py`

**Interfaces:** none new. Knob values only.

This task measures; it does not eyeball. The embedded game renders at half size, so every number comes from the viewport image at 1080×1920 (memory note `measure-pixels-when-the-game-runs-embedded`).

- [ ] **Step 1: The capture routine.** For each glow screen (MainMenu, LevelSelect, StudentCard, StudentList, ReportCard): run the game, reach the screen (Task 8/9 Step 5 routes), then in separate `editor_manage(op="game_eval", session_id=<WT>)` calls, each under ~7 s:
  1. hold still: `GameSettings.reduce_motion = true` first — shader `TIME` ignores `Engine.time_scale`, so without this the pool's breathing, the rays' drift and the glint's sweep differ between captures and contaminate every diff (the particles hide, which these measurements do not need) — then `Engine.time_scale = 0.0` to stop the tweens (the logo float, the prompt blink);
  2. capture A (kit on): `await RenderingServer.frame_post_draw` then `tree.root.get_viewport().get_texture().get_image().save_png("user://amb_on.png")`, with `var tree := Engine.get_main_loop() as SceneTree` in each eval;
  3. glow off only: `for g in tree.current_scene.find_children("*", "WorldEnvironment", true, false): g.environment.glow_enabled = false`, then capture B to `user://amb_noglow.png`;
  4. kit off: `GameSettings.ambient_effects_enabled = false`, capture C to `user://amb_off.png`; then `GameSettings.ambient_effects_enabled = true` and `GameSettings.reduce_motion = false`.
  Copy the three PNGs from the game's `user://` (`%APPDATA%\Godot\app_userdata\<project name>\`) into the scratchpad.

- [ ] **Step 2: The measurements** — `diff.py` (Python 3 + Pillow):

```python
import sys
from PIL import Image

def lum(p):
    r, g, b = p[:3]
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0

def region_mean(img, box):
    x0, y0, x1, y1 = box
    px = [lum(img.getpixel((x, y))) for x in range(x0, x1, 4) for y in range(y0, y1, 4)]
    return sum(px) / len(px)

def region_maxdiff(a, b, box):
    x0, y0, x1, y1 = box
    return max(abs(lum(a.getpixel((x, y))) - lum(b.getpixel((x, y))))
               for x in range(x0, x1, 4) for y in range(y0, y1, 4))

on, noglow, off = (Image.open(sys.argv[i]).convert("RGB") for i in (1, 2, 3))
ui, far, core = (tuple(int(v) for v in sys.argv[i].split(",")) for i in (4, 5, 6))
print("ui max diff (kit on vs off):", round(region_maxdiff(on, off, ui), 4))
print("far-field bloom (on vs noglow):", round(region_mean(on, far) - region_mean(noglow, far), 4))
print("pool-core bloom (on vs noglow):", round(region_mean(on, core) - region_mean(noglow, core), 4))
```

  Run `python diff.py amb_on.png amb_noglow.png amb_off.png <ui box> <far box> <core box>`, boxes as `x0,y0,x1,y1` in 1080×1920 pixels: **ui** = an opaque UI area (MainMenu: the icon bar; desk screens: the middle of the front paper card, or LevelSelect's brief card); **far** = backdrop at least 600 px from any pool centre with no UI over it; **core** = a 120 px box at the pool centre (`center × (1080, 1920)`).

- [ ] **Step 3: The pass criteria**, per screen:
  - **UI untouched:** `ui max diff` ≤ `0.004` (one 8-bit step). If not, a kit piece is on the UI's layer or the UI is translucent there: stop and report.
  - **No fog:** `far-field bloom` < `0.015`. If not, raise that screen's threshold by `0.02` (MainMenu: `Glow.glow_threshold`; desk screens: `Desk.glow_threshold`, or `DeskAmbience.tscn`'s `Glow` if all four fail) and re-measure, up to `0.98`.
  - **Visible bleed:** `pool-core bloom` ≥ `0.01`. If the threshold that passes "No fog" leaves the core under `0.01`, that screen ships without glow: set its threshold to `1.0` (with `hdr_2d` off nothing exceeds 1.0, so nothing blooms — `test_look_layer`'s note), and add the screen to DEBT.md's `hdr_2d` entry (Task 13).
  Record each screen's final numbers in a scratch table for the changelog.

- [ ] **Step 4: Land the values (Recipe R).** Write each tuned knob into its `.tscn` by text with the editor closed; relaunch; `test_run(suite="ambient_kit", session_id=<WT>)`, `tall_screen_layout`, `main_menu`. Expected: PASS. (`test_the_roster_list_keeps_its_dust_sparse` pins only density; thresholds are not pinned.)
- [ ] **Step 5: Reduce Motion, live.** On MainMenu, by `game_eval`: `Engine.time_scale = 1.0`, `tree.paused = true` (stops every node tween — the logo float — while shader `TIME` keeps running), `GameSettings.reduce_motion = true`; capture twice, about 1 s apart, and compare them with `region_maxdiff` over the whole frame `0,0,1080,1920`: ≤ `0.004`, i.e. with the tree paused nothing the kit draws still moves. Repeat with `reduce_motion = false`: the same diff must now exceed `0.004` (the breathing and the rays do move), which proves the check can fail. Unpause, restore `reduce_motion = false`, stop the game.
- [ ] **Step 6: Commit** (only if Step 4 changed a value). Message `chore(look): land the measured glow thresholds`.

---

### Task 13: Docs, the full suite, and ship

**Files:**
- Modify: `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`, `docs/superpowers/design/authoring-guide.md`, `CLAUDE.md` (the test count; the kit pointer only if the budget allows)

- [ ] **Step 1: DEBT.md.** Under `## Placeholder art` add one grouped entry, **Ambient kit art (2026-09-26)**: the leaf and petal sheets (`Assets/Images/Particles/particle_leaf_sheet.png`, `particle_petal_sheet.png`: 512×128, four 128×128 frames in a row, real colour, 8 px empty border per frame, tip up, straight alpha, no shadow) that a `DAUN` preset of `AmbientParticles` and an `h_frames` uniform on `paper_flutter.gdshader` wait on; the optional white `particle_dust.png` / `particle_sparkle.png` redraws (128×128, white on transparent) that would replace `particle_glow` / `particle_spark` in DEBU and KILAU; the deferred Sway shader, which needs separated plant/paper/curtain art. Under `## Known bugs and gaps` add **Ambient kit gaps (2026-09-27)**: `hdr_2d` (the clean way to bloom only the lights; project-wide, `test_look_layer` pins it off) plus any screen Task 12 shipped without glow; light wrap on the cutout materials; the kit not yet on Inventory, Achievements, Koperasi/ShopHub; the Debug Look page's bloom section is still Lobby-only (DebugManager is at its size ceiling).
- [ ] **Step 2: authoring-guide.md.** After the "Tall phones: fill the screen" section add `## Ambient kit` (≤ 25 lines): the five pieces and `AmbientKit`; the tree order on a glow screen (`World` CanvasLayer −1: backdrop, tint, light, particles, non-interactive art, spill; `AmbientGlow` anywhere; UI on 0) and on a plain screen (the same pieces directly after the backdrop on layer 0); only non-interactive art goes in `World`; per-screen knobs go on instance roots (`DeskAmbience` forwards); glow is tuned in the Inspector against the cream catch.
- [ ] **Step 3: CHANGELOG.md.** Newest-first entry `## 2026-09-27 — Ambient kit: moods, light, particles, glints and a UI-safe bloom`, listing the pieces, the screens, the Efek Suasana switch, the six planning amendments in one line each, and Task 12's measured numbers per screen.
- [ ] **Step 4: CLAUDE.md.** Under `## Visual system`, after the "third rule" paragraph, add one line only if the file stays under its 23,000-character budget (`wc -c CLAUDE.md`): `**Ambient kit.** Moods, light, particles, glint and bloom are placed pieces from Scenes/Look/ (authoring guide, "Ambient kit"); the UI never goes in a World layer.` Update the suite/test count line after Step 5.
- [ ] **Step 5: The full suite.** Recipe R relaunch (fresh editor), `scene_open` MainMenu, `test_run(session_id=<WT>)` with no suite. Expected: every suite PASS. Budget one more relaunch afterwards (a full run drops the bridge). A single failing theme assertion: re-run that suite alone before believing it. Then `git status --short`: revert the full run's `Assets/Theme/kejartes_theme.tres` rebake and `default_bus_layout.tres` if they are the known churn.
- [ ] **Step 6: Commit docs.** Message `docs(ambient-kit): debt, authoring guide, changelog`.
- [ ] **Step 7: Ship.** Invoke the `ship-pr` skill for `feat/ambient-kit` into `Textures`. It runs the full suite and a local review, pushes, opens the PR and stamps the tested commit; bind the PR right after `gh pr create` (memory note `ship-pr-bind-pr-before-stamping`).
