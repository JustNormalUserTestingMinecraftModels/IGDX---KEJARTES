# Lobby Look Everywhere — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The Godot bridge is single-client: subagents write files, the controlling session runs every `test_run` / editor call and hands results back.

**Goal:** Give the shops, the end-of-grade sequence and the minigames the Lobby's lighting and atmosphere: colour grade, a warm light pool, full-screen light shafts, bloom where it measures clean, and parallax on the shops and exam notices.

**Architecture:** One new ambient-kit piece, `SunShafts` (the Lobby's full-screen shafts as a drop-in scene), joins the existing `LightPool`, `AmbientGlow`, `MoodTint` and `ParallaxDiorama`. Each screen places them by hand in its `.tscn`. On the shops and end-game screens the backdrop moves into a `World` CanvasLayer at −1 holding one `Room` Control, so bloom never reaches the UI. Minigames stay on layer 0, because SchoolDay hosts them over its own background, and get light without bloom.

**Tech Stack:** Godot 4.6 GDScript, godot-ai MCP bridge (`test_run`, `editor_manage`, `session_manage`, `filesystem_manage`, `script_patch`), McpTestSuite, Python 3 + Pillow for offline pixel measurements.

**Spec:** `docs/superpowers/specs/2026-09-28-lobby-look-everywhere-design.md`. Read its "Amendments from planning" section: it supersedes the body where they differ.

## Global Constraints

- **Three passes, three branches, three PRs, in order.** Part 1 (Shops) runs in the existing worktree `.claude/worktrees/lobby-look-spec` on a new branch `feat/lobby-look-shops` cut from `docs/lobby-look-everywhere-spec`, so the spec and this plan ship with it. Part 2 (End game) and Part 3 (Minigames) each start only after the previous PR has merged, in a new worktree off a fresh `origin/Textures`: `.claude/worktrees/lobby-look-endgame` on `feat/lobby-look-endgame`, then `.claude/worktrees/lobby-look-minigames` on `feat/lobby-look-minigames`. Remove each worktree once its PR merges (user rule).
- `<WT_DIR>` below means the current part's worktree directory; `<WT>` is its editor's bridge session id (Recipe R). Every bridge call passes `session_id=<WT>`. Never `session_activate`; never kill every Godot process; never touch the main checkout's editor.
- `Scripts/Balance.gd` and `Scripts/Debug/DebugManager.gd` are not touched.
- **Clean code (`docs/superpowers/design/clean-code.md`).** A new script starts at zero debt: every `var`, parameter and return typed; no bare number inside a function body other than `0`, `1`, `2`, `-1`, `0.5` (name it in a `const` or `@export`); no function over 50 code lines; file name = `class_name`. A modified script's touched functions end no longer and no less typed than found.
- **Docs (`test_script_documentation`).** Every script opens with a `##` block; a `##` line sits immediately above every `@export` and every `const`.
- No `theme_override_*` except layout constants. No visual built at runtime: no `.new(` of a visual type and no `add_child` in any new or touched script.
- Test suites are `@tool`, override `suite_name()`, and no test is a coroutine. A `test_run(suite=…)` name is the file's `suite_name()` value.
- **Scene files are hand-edited as text only while the worktree editor is closed (Recipe R).** Nothing in this plan calls `scene_save`. New nodes carry no `unique_id`; the editor assigns one on its next save.
- **Scripts.** After writing a `.gd` while the editor runs: `filesystem_manage(op="scan", session_id=<WT>)`, then a no-op `script_patch` on that file (search and replace its first line with itself) before `test_run`. If a test then reports an unknown class (`SunShafts`), do Recipe R.
- Commits are Conventional (`type(scope): …`). Write the message to a scratch file ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and commit with `git commit -F <file>`. Use plain git commands (no `&&` chains, no heredocs). Check `git branch --show-current` before every commit.
- Before every commit: `git status --short`. Revert `Assets/Audio/default_bus_layout.tres` and any boot-rewritten `*.png.import` with `git checkout -- <file>` **after** the worktree editor has exited, and only once the diff is confirmed to be that known churn.
- Paths used everywhere below:

| Name | Path |
|---|---|
| LightPool | `res://Scenes/Look/LightPool.tscn` |
| SunShafts | `res://Scenes/Look/SunShafts.tscn` (new, Task 1) |
| AmbientGlow | `res://Scenes/Look/AmbientGlow.tscn` |
| MoodTint | `res://Scenes/Look/MoodTint.tscn` |
| ParallaxDiorama | `res://Scripts/UI/ParallaxDiorama.gd` |
| Plain grade | `res://Scripts/Shaders/illustration_grade_material.tres` |
| Cutout grade | `res://Scripts/Shaders/illustration_grade_cutout.tres` |

### Recipe R — close, edit, relaunch the worktree editor

1. `editor_manage(op="quit", session_id=<WT>)`. If it times out, run PowerShell `Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v%'" | Where-Object { $_.CommandLine -like '*worktrees\<leaf of WT_DIR>*' } | Select-Object ProcessId, CommandLine`. Check that the command line names this worktree, then `Stop-Process -Id <that pid>`. Never stop any other Godot process.
2. Make the file edits the task lists.
3. Launch detached (PowerShell):
   `Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = '"C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" --path "<absolute WT_DIR>" -e'; CurrentDirectory = '<absolute WT_DIR>' }`. `ReturnValue 0` means it launched.
4. `session_manage(op="list")` until a session whose `project_path` is the worktree is `ready`. Record its id as the new `<WT>`; it changes on every launch.
5. `scene_open("res://Scenes/MainMenu/MainMenu.tscn", session_id=<WT>)`.

### Recipe M — measure one screen's bloom

This recipe measures; it does not eyeball. The embedded game renders at half size, so every number comes from the viewport image at 1080×1920 (memory: measure pixels, don't screenshot).

1. `project_run(session_id=<WT>)`, then reach the screen with `editor_manage(op="game_eval", session_id=<WT>, code=…)`: `(Engine.get_main_loop() as SceneTree).change_scene_to_file("<scene path>")`, or the route the task names. Wait for the Transition to finish with a separate eval (about 2 s).
2. In separate `game_eval` calls, each under ~7 s:
   1. Hold still: `GameSettings.reduce_motion = true`, then `Engine.time_scale = 0.0`. Shader `TIME` ignores `time_scale`, so without `reduce_motion` the breathing and the drift differ between captures.
   2. Capture A (all on): `await RenderingServer.frame_post_draw`, then `tree.root.get_viewport().get_texture().get_image().save_png("user://look_on.png")`, with `var tree := Engine.get_main_loop() as SceneTree` in each eval.
   3. Glow off only: `for g in tree.current_scene.find_children("*", "WorldEnvironment", true, false): g.environment.glow_enabled = false`, then capture B to `user://look_noglow.png`.
   4. Kit off: `GameSettings.ambient_effects_enabled = false`, then capture C to `user://look_off.png`. Then set `GameSettings.ambient_effects_enabled = true`, `GameSettings.reduce_motion = false` and `Engine.time_scale = 1.0`.
3. Copy the three PNGs from `%APPDATA%\Godot\app_userdata\<project name>\` into `<scratchpad>/look/<screen>/`.
4. Run `python <scratchpad>/look/diff.py look_on.png look_noglow.png look_off.png <ui> <far> <core>` (script below). Boxes are `x0,y0,x1,y1` in 1080×1920 pixels:
   - **ui**: an opaque UI area.
   - **far**: backdrop at least 600 px from the light, with no UI over it.
   - **core**: a 120 px box at the light's centre (`LightPool.center × (1080, 1920)`).
5. Pass criteria:
   - **UI untouched:** `ui max diff` ≤ `0.004`. If not, a light piece is on the UI's layer: stop and report.
   - **No fog:** `far-field bloom` < `0.01`. If not, raise that screen's `Glow.glow_threshold` by `0.02` (Recipe R) and measure again, up to `0.98`.
   - **Visible bleed:** `core bloom` ≥ `0.01`. If the threshold that passes "No fog" leaves the core under `0.01`, the screen ships **without** a Glow: delete its `Glow` node and its `look_glow` ext_resource, and set its `BLOOM` entry in `tests/test_lobby_look.gd` to `null`.
6. Record the screen's final threshold (or "none") and its three numbers in `<scratchpad>/look/results.md` for the changelog.

`<scratchpad>/look/diff.py`:

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
print("ui max diff (on vs off):", round(region_maxdiff(on, off, ui), 4))
print("far-field bloom (on vs noglow):", round(region_mean(on, far) - region_mean(noglow, far), 4))
print("core bloom (on vs noglow):", round(region_mean(on, core) - region_mean(noglow, core), 4))
print("whole-frame mean (on):", round(region_mean(on, (0, 0, 1080, 1920)), 4))
```

---

# Part 1 — Shops (`feat/lobby-look-shops`)

### Task 0: The worktree's editor and a green baseline

**Files:** none tracked.

- [ ] **Step 1: Branch.** In `.claude/worktrees/lobby-look-spec`: `git switch -c feat/lobby-look-shops`. Confirm with `git branch --show-current`.
- [ ] **Step 2: Seed the cache.** Copy `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main checkout's `.godot/` (`../../../.godot/` from the worktree) into the worktree's `.godot/`. Skip `.godot/editor/`.
- [ ] **Step 3: Launch.** Recipe R steps 3–5.
- [ ] **Step 4: Baseline.** `test_run` with `session_id=<WT>` for each of: `ambient_kit`, `parallax_diorama`, `illustration_ao`, `tall_screen_layout`, `shop_hub`, `koperasi`, `viewport_editability`, `script_documentation`, `clean_code`. Expected: all PASS. If any fails, stop and report: the branch starts from a red `Textures`.
- [ ] **Step 5:** `git status --short`, and revert the known boot churn (Global Constraints).

---

### Task 1: `SunShafts`, the Lobby's shafts as a kit piece

**Files:**
- Create: `Scripts/Look/SunShafts.gd`
- Create: `Scenes/Look/SunShafts.tscn`
- Test: `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `AmbientKit.fill_parent(node: Control)`, `AmbientKit.follow_settings(apply: Callable)`, `AmbientKit.is_enabled() -> bool`, `AmbientKit.is_still() -> bool`.
- Produces: `class_name SunShafts extends ColorRect`, with `const MAX_INTENSITY := 0.2` and exports `origin: Vector2 = (0.12, -0.08)`, `shaft_color: Color = (1.0, 0.898, 0.706)`, `intensity: float = 0.2` (clamped), `shaft_count: float = 7.0`, `softness: float = 5.0`, `reach: float = 1.4`, `drift_speed: float = 0.035`. Scene root node name `SunShafts`, with a `resource_local_to_scene` ShaderMaterial on `light_shafts.gdshader`.

- [ ] **Step 1: Write the failing tests.** In `tests/test_ambient_kit.gd`:

  Add beside the other path consts (after `DESK_AMBIENCE`):

```gdscript
const SUN_SHAFTS := "res://Scenes/Look/SunShafts.tscn"
```

  Add beside the other fixtures (after `var _desk: DeskAmbience`):

```gdscript
var _shafts: SunShafts
```

  In `suite_setup`, after `_desk = _stand(DESK_AMBIENCE) as DeskAmbience`:

```gdscript
	_shafts = _stand(SUN_SHAFTS) as SunShafts
```

  In `test_every_kit_root_refills_its_parent`, add `"res://Scripts/Look/SunShafts.gd"` to the list of paths.

  Change `const KIT_SCENES := [MOOD_TINT, LIGHT_POOL, AMBIENT_PARTICLES, DESK_AMBIENCE]` to:

```gdscript
const KIT_SCENES := [MOOD_TINT, LIGHT_POOL, AMBIENT_PARTICLES, DESK_AMBIENCE, SUN_SHAFTS]
```

  Insert a new section directly before `# ── AmbientParticles`:

```gdscript
# ── SunShafts ────────────────────────────────────────────────────────────────

func _shafts_mat() -> ShaderMaterial:
	return _shafts.material as ShaderMaterial


## The Lobby's WindowShafts ship at 0.20, the top of the range swept over
## cream without clipping (light_shafts.gdshader's header).
func test_the_shafts_clamp_to_the_lobby_ceiling() -> void:
	_shafts.intensity = 0.5
	assert_eq(_shafts.intensity, SunShafts.MAX_INTENSITY, "intensity clamps to MAX_INTENSITY")
	assert_eq(float(_shafts_mat().get_shader_parameter("intensity")), SunShafts.MAX_INTENSITY,
		"and the shader gets the clamped value")
	assert_eq(SunShafts.MAX_INTENSITY, 0.2, "the Lobby's shipped shafts (light_shafts.gdshader)")
	_shafts.intensity = 0.2


## Unlike LightPool's rays, these cross the whole screen: Full Rect, not a pool.
func test_the_shafts_are_additive_local_full_rect_and_untappable() -> void:
	assert_eq(_shafts_mat().shader.resource_path, "res://Scripts/Shaders/light_shafts.gdshader",
		"the shafts are light_shafts, unchanged")
	assert_true(_shafts_mat().resource_local_to_scene, "each placed SunShafts tunes its own copy")
	assert_eq(_anchors(_shafts), Vector4(0, 0, 1, 1), "Full Rect, so the rays cross the room")
	assert_eq(_offsets(_shafts), Vector4.ZERO, "and carry no inset")
	assert_eq(_shafts.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the shafts never eat a tap")


func test_the_shaft_knobs_reach_the_shader() -> void:
	_shafts.origin = Vector2(0.8, -0.1)
	_shafts.shaft_color = Color(0.7, 0.8, 1.0)
	_shafts.shaft_count = 5.0
	_shafts.softness = 3.0
	_shafts.reach = 2.0
	var mat := _shafts_mat()
	assert_eq(mat.get_shader_parameter("origin"), Vector2(0.8, -0.1), "origin reaches the shader")
	assert_eq(mat.get_shader_parameter("shaft_color"), Color(0.7, 0.8, 1.0), "colour reaches it")
	assert_eq(float(mat.get_shader_parameter("shaft_count")), 5.0, "count reaches it")
	assert_eq(float(mat.get_shader_parameter("softness")), 3.0, "softness reaches it")
	assert_eq(float(mat.get_shader_parameter("reach")), 2.0, "reach reaches it")
	_shafts.origin = Vector2(0.12, -0.08)
	_shafts.shaft_color = Color(1.0, 0.898, 0.706)
	_shafts.shaft_count = 7.0
	_shafts.softness = 5.0
	_shafts.reach = 1.4


func test_reduce_motion_holds_the_shafts_still() -> void:
	GameSettings.ambient_effects_enabled = true
	GameSettings.reduce_motion = true
	assert_eq(float(_shafts_mat().get_shader_parameter("drift_speed")), 0.0, "no drift when still")
	assert_true(_shafts.visible, "still is not off: the shafts stay")
	GameSettings.reduce_motion = false
	assert_eq(float(_shafts_mat().get_shader_parameter("drift_speed")), _shafts.drift_speed,
		"drift resumes")


func test_the_switch_hides_the_shafts() -> void:
	GameSettings.ambient_effects_enabled = false
	assert_false(_shafts.visible, "Efek Suasana off hides the shafts")
	GameSettings.ambient_effects_enabled = true
	assert_true(_shafts.visible, "and on brings them back")
```

- [ ] **Step 2: Run them and watch them fail.** Scan (Global Constraints, Scripts), then `test_run(suite="ambient_kit", session_id=<WT>)`. Expected: the suite fails to load, or every new test fails on an unknown `SunShafts` class or a missing scene.

- [ ] **Step 3: Write the script.** Create `Scripts/Look/SunShafts.gd`:

```gdscript
@tool
class_name SunShafts
extends ColorRect

## Slow sunlight shafts across a whole screen: the Lobby's WindowShafts as a
## kit piece (spec docs/superpowers/specs/2026-09-28-lobby-look-everywhere-design.md,
## section 1). LightPool's own rays stop at its pool's edge
## (LightPool.MAX_RAYS_REACH); these cross the room.
##
## Additive, through light_shafts.gdshader unchanged, so it only ever
## brightens. The material is local to the scene, so every placed SunShafts
## tunes its own copy. The root restores Full Rect in _ready
## (AmbientKit.fill_parent), so it covers a tall phone. Kurangi Gerakan stops
## the drift; Efek Suasana off hides it.

## The brightest the shafts may be: the Lobby's WindowShafts ship at 0.20, the
## top of the range swept over cream without clipping
## (light_shafts.gdshader's header).
const MAX_INTENSITY := 0.2

## Where the shafts converge, in this node's UV: (0, 0) is the top-left
## corner. Upper left by default, the game's light direction.
@export var origin: Vector2 = Vector2(0.12, -0.08):
	set(value):
		origin = value
		_refresh()

## Colour of the light. Warm by default, matching LightPool's.
@export var shaft_color: Color = Color(1.0, 0.898, 0.706):
	set(value):
		shaft_color = value
		_refresh()

## Peak brightness; clamped to MAX_INTENSITY.
@export_range(0.0, 0.2, 0.005) var intensity: float = 0.2:
	set(value):
		intensity = minf(value, MAX_INTENSITY)
		_refresh()

## How many shafts. Few and wide reads as sun; many and thin as a starburst.
@export_range(1.0, 16.0, 1.0) var shaft_count: float = 7.0:
	set(value):
		shaft_count = value
		_refresh()

## Edge softness of each shaft; higher is softer.
@export_range(1.0, 12.0, 0.1) var softness: float = 5.0:
	set(value):
		softness = value
		_refresh()

## How far from `origin` the shafts fade out, in UV.
@export_range(0.1, 3.0, 0.01) var reach: float = 1.4:
	set(value):
		reach = value
		_refresh()

## How fast the shafts turn. Dust moves; sunlight does not strobe.
@export_range(0.0, 0.2, 0.005) var drift_speed: float = 0.035:
	set(value):
		drift_speed = value
		_refresh()


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AmbientKit.follow_settings(_refresh)


func _refresh() -> void:
	if not is_node_ready():
		return
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("shaft_color", shaft_color)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("origin", origin)
	mat.set_shader_parameter("shaft_count", shaft_count)
	mat.set_shader_parameter("softness", softness)
	mat.set_shader_parameter("reach", reach)
	mat.set_shader_parameter("drift_speed", 0.0 if AmbientKit.is_still() else drift_speed)
	visible = AmbientKit.is_enabled()
```

- [ ] **Step 4: Write the scene.** Create `Scenes/Look/SunShafts.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Look/SunShafts.gd" id="1_script"]
[ext_resource type="Shader" path="res://Scripts/Shaders/light_shafts.gdshader" id="2_shafts"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_shafts"]
resource_local_to_scene = true
shader = ExtResource("2_shafts")

[node name="SunShafts" type="ColorRect"]
material = SubResource("ShaderMaterial_shafts")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_script")
```

- [ ] **Step 5: Run them and watch them pass.** Scan, no-op `script_patch` on `Scripts/Look/SunShafts.gd`, then `test_run(suite="ambient_kit")`, `test_run(suite="script_documentation")` and `test_run(suite="clean_code")`, all with `session_id=<WT>`. Expected: PASS. If `SunShafts` is still unknown, do Recipe R (no edits) and rerun.

- [ ] **Step 6: Commit.** `git add Scripts/Look/SunShafts.gd Scenes/Look/SunShafts.tscn tests/test_ambient_kit.gd` (plus the `.gd.uid` the editor wrote), message `feat(look): SunShafts, the Lobby's light shafts as a kit piece`.

---

### Task 2: Parallax holds still under Kurangi Gerakan

**Files:**
- Modify: `Scripts/UI/ParallaxDiorama.gd` (`_process`, and a new `_target_tilt` beside `_read_tilt`)
- Test: `tests/test_parallax_diorama.gd`

**Interfaces:**
- Consumes: `AmbientKit.is_still() -> bool`.
- Produces: `ParallaxDiorama._target_tilt(delta: float) -> Vector2`, which returns `Vector2.ZERO` while `GameSettings.reduce_motion` is on and `_read_tilt(delta)` otherwise. A new `FLAT_DIORAMAS` dictionary and `_all_dioramas() -> Dictionary` in the test, which Tasks 3 and 7 extend.

- [ ] **Step 1: Write the failing test.** Append to `tests/test_parallax_diorama.gd`:

```gdscript
## Kurangi Gerakan holds every diorama at rest (spec 2026-09-28, planning
## amendment 2): the bands chase zero tilt, so they settle back and stay,
## whatever the phone or the pointer does. The Lobby and Koperasi ignored the
## switch until then.
func test_reduce_motion_holds_the_diorama_at_rest() -> void:
	var before := GameSettings.reduce_motion
	var driver := (load("res://Scripts/UI/ParallaxDiorama.gd") as GDScript).new() as Control
	track(driver)
	GameSettings.reduce_motion = true
	var still: Vector2 = driver.call("_target_tilt", 0.016)
	GameSettings.reduce_motion = before
	assert_eq(still, Vector2.ZERO, "no tilt reaches the bands while Kurangi Gerakan is on")
	var src := FileAccess.get_file_as_string("res://Scripts/UI/ParallaxDiorama.gd")
	assert_true(src.contains("_deflection.lerp(_target_tilt(delta)"),
		"the bands chase _target_tilt, not the raw reading")
```

- [ ] **Step 2: Run it and watch it fail.** `test_run(suite="parallax_diorama", session_id=<WT>)`. Expected: the new test fails, because `_target_tilt` does not exist.

- [ ] **Step 3: Implement.** In `Scripts/UI/ParallaxDiorama.gd`, change the `_deflection = …` line in `_process` to:

```gdscript
	_deflection = _deflection.lerp(_target_tilt(delta), clampf(smoothing * delta, 0.0, 1.0))
```

  Add directly above the function that reads the tilt (`_read_tilt`):

```gdscript
## The tilt the bands chase: none while Kurangi Gerakan is on, so they settle
## back to rest and hold still (spec 2026-09-28, planning amendment 2).
func _target_tilt(delta: float) -> Vector2:
	if AmbientKit.is_still():
		return Vector2.ZERO
	return _read_tilt(delta)
```

  Add one line to the file's `##` header, after the "WHAT DRIVES IT" paragraph: `## Kurangi Gerakan (GameSettings.reduce_motion) holds every band at rest.`

- [ ] **Step 4: Run it and watch it pass.** Scan, no-op `script_patch` on the file, then `test_run(suite="parallax_diorama")` and `test_run(suite="clean_code")`. Expected: PASS.

- [ ] **Step 5: Add the flat-diorama hook to the test.** It stays empty until Task 3. In `tests/test_parallax_diorama.gd`, after `const DIORAMAS := {…}`:

```gdscript
## The Lobby look's flat screens (spec 2026-09-28): one picture plane under
## World/Room, drifting against the UI. They carry a single depth, so they
## skip the three-band test but must pass the baked-offset and overscan tests.
const FLAT_DIORAMAS := {}


## Every diorama the driver runs on, layered or flat.
func _all_dioramas() -> Dictionary:
	return DIORAMAS.merged(FLAT_DIORAMAS)
```

  In `test_nothing_the_driver_touches_is_baked_into_the_scene` and `test_the_overscan_covers_the_travel_on_both_dioramas`, change `for scene_path in DIORAMAS:` to `for scene_path in _all_dioramas():`, and in each, `DIORAMAS[scene_path]` to `_all_dioramas()[scene_path]`. Run `parallax_diorama` again: PASS.

- [ ] **Step 6: Commit.** `git add Scripts/UI/ParallaxDiorama.gd tests/test_parallax_diorama.gd`, message `fix(look): parallax holds still under Kurangi Gerakan`.

---

### Task 3: ShopHub and CosmeticShop wear the Lobby's room

**Files:**
- Create: `tests/scene_census.gd` (test helper, not a suite)
- Create: `tests/test_lobby_look.gd`
- Modify: `tests/test_ambient_kit.gd` (its census helpers delegate to the new helper)
- Modify: `tests/test_tall_screen_layout.gd`, `tests/test_illustration_ao.gd`, `tests/test_parallax_diorama.gd`
- Modify (Recipe R): `Scenes/Koperasi/ShopHub.tscn`, `Scenes/Koperasi/CosmeticShop.tscn`

**Interfaces:**
- Consumes: `SunShafts.tscn` (Task 1), `FLAT_DIORAMAS` (Task 2).
- Produces: `tests/scene_census.gd` with static `of(scene_path: String) -> Array[Dictionary]`, `entry(census: Array[Dictionary], path: String) -> Dictionary`, `prop(entry: Dictionary, name: String, fallback: Variant = null) -> Variant`, `children_of(census: Array[Dictionary], parent: String) -> Array[String]`. `tests/test_lobby_look.gd` (suite `lobby_look`) with `ROOMS`, `BLOOM` and the helper `_assert_room(scene_path: String, want: Array)`, which Tasks 4, 7–10 and 13 extend. The node layout `World` (CanvasLayer −1) → `Room` (Control, `%Room`), with `Glow` as the root's second child.

- [ ] **Step 1: The census helper.** Create `tests/scene_census.gd`:

```gdscript
@tool
extends RefCounted

## Test helper, not a suite: reads a saved scene's nodes from its PackedScene
## state without instancing it, so placement tests stay cheap on a full run
## (instancing per test floods the deferred-call queue). Used by
## test_ambient_kit.gd and test_lobby_look.gd.
##
## Every entry is {path, type, instance, props}: `path` relative to the root
## ("." for the root itself), `instance` the instanced scene's path or "",
## `props` only the properties the file sets.


## Every node of `scene_path` in file (= tree) order.
static func of(scene_path: String) -> Array[Dictionary]:
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


## The entry at `path`, or {} when the scene has no such node.
static func entry(census: Array[Dictionary], path: String) -> Dictionary:
	for e in census:
		if e["path"] == path:
			return e
	return {}


## A property the file sets on `entry`, or `fallback` when it leaves it default.
static func prop(entry: Dictionary, name: String, fallback: Variant = null) -> Variant:
	return (entry.get("props", {}) as Dictionary).get(name, fallback)


## Direct children of `parent` ("." for the root), in draw order.
static func children_of(census: Array[Dictionary], parent: String) -> Array[String]:
	var out: Array[String] = []
	for e in census:
		var p: String = e["path"]
		if p == ".":
			continue
		var dad := "." if not p.contains("/") else p.get_base_dir()
		if dad == parent:
			out.append(p.get_file())
	return out
```

- [ ] **Step 2: `test_ambient_kit` delegates.** In `tests/test_ambient_kit.gd`, add `const Census := preload("res://tests/scene_census.gd")` after `MAIN_MENU`. Replace the bodies of `_census`, `_entry`, `_prop` and `_children_of`, keeping each one's `##` comment and signature, with `return Census.of(scene_path)`, `return Census.entry(census, path)`, `return Census.prop(entry, name, fallback)` and `return Census.children_of(census, parent)`. Run `test_run(suite="ambient_kit")`: PASS, with the same test count as before.

- [ ] **Step 3: Write the failing placement suite.** Create `tests/test_lobby_look.gd`:

```gdscript
@tool
extends McpTestSuite

## The Lobby's look on the rest of the game (spec
## docs/superpowers/specs/2026-09-28-lobby-look-everywhere-design.md, plan
## docs/superpowers/plans/2026-09-28-lobby-look-everywhere.md): where each
## screen places the grade, the light, the shafts, the bloom and the parallax.
##
## Reads saved scenes through tests/scene_census.gd and never instances them.
## Must be @tool, and no test here may be a coroutine.

const Census := preload("res://tests/scene_census.gd")

const LIGHT_POOL := "res://Scenes/Look/LightPool.tscn"
const SUN_SHAFTS := "res://Scenes/Look/SunShafts.tscn"
const AMBIENT_GLOW := "res://Scenes/Look/AmbientGlow.tscn"
const MOOD_TINT := "res://Scenes/Look/MoodTint.tscn"
const WIN_STAGE := "res://Scenes/EndGame/WinStage.tscn"
const PARALLAX_SCRIPT := "res://Scripts/UI/ParallaxDiorama.gd"
const GRADE := "res://Scripts/Shaders/illustration_grade_material.tres"
const BUTTON_TYPES := ["Button", "TextureButton", "CheckButton", "CheckBox",
	"OptionButton", "MenuButton", "LinkButton"]
## The drift of a flat screen: it has no nearer band, so its one plane moves
## at full depth against the UI (planning amendment 5).
const FLAT_DEPTH := 1.0
## AmbientGlow.gd's own glow_threshold default, read when a scene leaves it.
const GLOW_DEFAULT := 0.9

const SHOP_HUB := "res://Scenes/Koperasi/ShopHub.tscn"
const COSMETIC_SHOP := "res://Scenes/Koperasi/CosmeticShop.tscn"

## Screen -> its Room's children, in draw order.
const ROOMS := {
	SHOP_HUB: ["Backdrop", "Light", "Shafts", "Parallax"],
	COSMETIC_SHOP: ["Backdrop", "Light", "Shafts", "Parallax"],
}

## Screen -> its measured glow_threshold, or null where no threshold bloomed
## the light without fogging the backdrop, so the screen places no Glow.
## Recipe M writes the measured values.
const BLOOM := {
	SHOP_HUB: 0.9,
	COSMETIC_SHOP: 0.9,
}


func suite_name() -> String:
	return "lobby_look"


## `World` is a CanvasLayer at -1 holding only `Room`; `Room` is a unique,
## tap-through Control whose children are `want`, in order; nothing tappable
## sits under World; each kit piece is the right instance; a Parallax driver
## moves every other band at FLAT_DEPTH and overscans the full-rect ones.
func _assert_room(scene_path: String, want: Array) -> void:
	var c := Census.of(scene_path)
	var world := Census.entry(c, "World")
	assert_eq(world.get("type"), "CanvasLayer", scene_path + ": World must be a CanvasLayer")
	assert_eq(Census.prop(world, "layer"), -1, scene_path + ": World draws at -1, below the UI")
	assert_eq(Census.children_of(c, ".").find("World"), 0, scene_path + ": World is drawn first")
	assert_eq(Census.children_of(c, "World"), ["Room"] as Array[String],
		scene_path + ": World holds one Room")
	var room := Census.entry(c, "World/Room")
	assert_eq(room.get("type"), "Control", scene_path + ": Room is a Control")
	assert_eq(Census.prop(room, "unique_name_in_owner"), true, scene_path + ": %Room")
	assert_eq(Census.prop(room, "mouse_filter"), Control.MOUSE_FILTER_IGNORE,
		scene_path + ": Room never eats a tap")
	assert_eq(Census.children_of(c, "World/Room"), Array(want, TYPE_STRING, &"", null),
		scene_path + ": the Room's bands, in draw order")
	for e in c:
		if (e["path"] as String).begins_with("World/"):
			assert_false(BUTTON_TYPES.has(e["type"]),
				"%s: %s is tappable and must stay on layer 0" % [scene_path, e["path"]])
	_assert_piece(c, scene_path, "World/Room/Light", LIGHT_POOL)
	_assert_piece(c, scene_path, "World/Room/Shafts", SUN_SHAFTS)
	_assert_piece(c, scene_path, "World/Room/Tint", MOOD_TINT)
	_assert_piece(c, scene_path, "World/Room/WinStage", WIN_STAGE)
	if want.has("Backdrop"):
		var mat: Variant = Census.prop(Census.entry(c, "World/Room/Backdrop"), "material")
		assert_true(mat is Material and (mat as Material).resource_path == GRADE,
			scene_path + ": the backdrop wears the plain grade")
	if want.has("Parallax"):
		_assert_flat_parallax(c, scene_path, want)


## When the scene has a node at `path`, it is an instance of `scene`.
func _assert_piece(c: Array[Dictionary], scene_path: String, path: String, scene: String) -> void:
	var e := Census.entry(c, path)
	if e.is_empty():
		return
	assert_eq(e.get("instance"), scene, "%s: %s is an instance of %s" % [scene_path, path, scene])


func _assert_flat_parallax(c: Array[Dictionary], scene_path: String, want: Array) -> void:
	var driver := Census.entry(c, "World/Room/Parallax")
	var script: Variant = Census.prop(driver, "script")
	assert_true(script is Script and (script as Script).resource_path == PARALLAX_SCRIPT,
		scene_path + ": Parallax runs ParallaxDiorama")
	var depths: Dictionary = Census.prop(driver, "depth_by_child", {})
	var overscan: Array = Census.prop(driver, "overscan_children", [])
	for band: String in want:
		if band == "Parallax":
			continue
		assert_eq(float(depths.get(band, 0.0)), FLAT_DEPTH,
			"%s: %s drifts with the picture" % [scene_path, band])
		if band in ["Backdrop", "Tint", "Shafts"]:
			assert_true(overscan.has(StringName(band)),
				"%s: %s fills the screen, so it is overscanned" % [scene_path, band])


## Each measured screen keeps exactly one Glow, second in the root, at its
## measured threshold; a screen that measured no clean threshold has none.
func test_every_bloom_decision_is_pinned() -> void:
	for scene_path in BLOOM:
		var c := Census.of(scene_path)
		var glows := 0
		for e in c:
			if e["instance"] == AMBIENT_GLOW:
				glows += 1
		if BLOOM[scene_path] == null:
			assert_eq(glows, 0, scene_path + ": measured no clean bloom, so it places no Glow")
			continue
		assert_eq(glows, 1, scene_path + ": one Glow")
		assert_eq(Census.children_of(c, ".").find("Glow"), 1,
			scene_path + ": Glow is the root's second child, right after World")
		assert_eq(float(Census.prop(Census.entry(c, "Glow"), "glow_threshold", GLOW_DEFAULT)),
			float(BLOOM[scene_path]), scene_path + ": the measured threshold")


func test_every_lit_screen_wears_the_lobby_room() -> void:
	for scene_path in ROOMS:
		_assert_room(scene_path, ROOMS[scene_path])


## The shops blur their Room on layer 0, so the light blurs with the picture
## and the tiles and the back button stay sharp above it.
## Glow is left out of the order: test_every_bloom_decision_is_pinned owns it,
## and a screen that measured no clean bloom has none.
func test_the_shops_blur_the_room_under_their_ui() -> void:
	assert_eq(_drawn(SHOP_HUB), ["World", "BlurLayer", "Tiles", "BackButton"] as Array[String],
		"ShopHub: the room, the blur, then the UI")
	assert_eq(_drawn(COSMETIC_SHOP),
		["World", "BlurLayer", "ComingSoonLabel", "BackButton"] as Array[String],
		"CosmeticShop: the room, the blur, then the UI")


## The root's children in draw order, without the Glow (a WorldEnvironment
## draws nothing).
func _drawn(scene_path: String) -> Array[String]:
	var kids := Census.children_of(Census.of(scene_path), ".")
	kids.erase("Glow")
	return kids
```


- [ ] **Step 4: The pinned-path tests.**
  - In `tests/test_tall_screen_layout.gd`, add a section at the end:

```gdscript
# ── The Lobby look's World screens (2026-09-28) ─────────────────────────────

## Screen -> its backdrop, now under World/Room.
const LIT_BACKDROPS := {
	"res://Scenes/Koperasi/ShopHub.tscn": "World/Room/Backdrop",
	"res://Scenes/Koperasi/CosmeticShop.tscn": "World/Room/Backdrop",
}


func test_the_lit_screens_backdrops_fill() -> void:
	for path in LIT_BACKDROPS:
		var screen := _scene(path)
		_assert_background_fills(screen.get_node_or_null(LIT_BACKDROPS[path]) as TextureRect, path)
		var room := screen.get_node_or_null("World/Room") as Control
		assert_true(room != null, path + " needs World/Room")
		if room != null:
			assert_eq(_anchors(room), Vector4(0, 0, 1, 1), path + ": Room is Full Rect")
```

  - In `tests/test_illustration_ao.gd`, add these two lines to `BACKDROPS`:

```gdscript
	"res://Scenes/Koperasi/ShopHub.tscn": ["World/Room/Backdrop"],
	"res://Scenes/Koperasi/CosmeticShop.tscn": ["World/Room/Backdrop"],
```

  - In `tests/test_parallax_diorama.gd`, fill `FLAT_DIORAMAS`:

```gdscript
const FLAT_DIORAMAS := {
	"res://Scenes/Koperasi/ShopHub.tscn": "World/Room",
	"res://Scenes/Koperasi/CosmeticShop.tscn": "World/Room",
}
```

- [ ] **Step 5: Run and watch them fail.** Scan, then run `lobby_look`, `tall_screen_layout`, `illustration_ao` and `parallax_diorama`. Expected: FAIL on every new ShopHub and CosmeticShop assertion (no `World`), and the rest still PASS.

- [ ] **Step 6: Edit the scenes (Recipe R).** In `Scenes/Koperasi/ShopHub.tscn`:
  1. Add these ext_resources after the last existing one:

```
[ext_resource type="Material" path="res://Scripts/Shaders/illustration_grade_material.tres" id="illus_grade"]
[ext_resource type="PackedScene" path="res://Scenes/Look/LightPool.tscn" id="look_pool"]
[ext_resource type="PackedScene" path="res://Scenes/Look/SunShafts.tscn" id="look_shafts"]
[ext_resource type="PackedScene" path="res://Scenes/Look/AmbientGlow.tscn" id="look_glow"]
[ext_resource type="Script" path="res://Scripts/UI/ParallaxDiorama.gd" id="parallax_diorama"]
```

  2. Replace the whole `[node name="Backdrop" …]` block (through `stretch_mode = 6`) with:

```
[node name="World" type="CanvasLayer" parent="."]
layer = -1

[node name="Room" type="Control" parent="World"]
unique_name_in_owner = true
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Backdrop" type="TextureRect" parent="World/Room" unique_id=106300855]
material = ExtResource("illus_grade")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("2_u0dhl")
expand_mode = 1
stretch_mode = 6

[node name="Light" parent="World/Room" instance=ExtResource("look_pool")]
center = Vector2(0.15, 0.08)
pool_size = Vector2(1600, 1600)
intensity = 0.1

[node name="Shafts" parent="World/Room" instance=ExtResource("look_shafts")]

[node name="Parallax" type="Control" parent="World/Room"]
layout_mode = 1
anchors_preset = 0
mouse_filter = 2
script = ExtResource("parallax_diorama")
depth_by_child = {
"Backdrop": 1.0,
"Light": 1.0,
"Shafts": 1.0
}
overscan_children = Array[StringName]([&"Backdrop", &"Shafts"])

[node name="Glow" parent="." instance=ExtResource("look_glow")]
```

  3. `Scenes/Koperasi/CosmeticShop.tscn`: the same two edits. Its backdrop's `unique_id` is `735705893` and its texture id is `"2_bnvsf"`; keep both.

  Relaunch (Recipe R steps 3–5).

- [ ] **Step 7: Run and watch them pass.** Run `lobby_look`, `tall_screen_layout`, `illustration_ao`, `parallax_diorama`, `shop_hub` and `ambient_kit`. Expected: PASS.

- [ ] **Step 8: See it once.** `project_run`, reach ShopHub with `game_eval` (`change_scene_to_file("res://Scenes/Koperasi/ShopHub.tscn")`), wait 2 s, then `editor_screenshot` in game mode at full size. Check that the backdrop is blurred **with** the light in it. If the frame shows only the blur tint over a flat colour, BlurLayer is not sampling `World`: stop and report, because the blurred screens in Part 2 depend on it. Stop the game.

- [ ] **Step 9: Commit.** `git add tests/scene_census.gd tests/test_lobby_look.gd tests/test_ambient_kit.gd tests/test_tall_screen_layout.gd tests/test_illustration_ao.gd tests/test_parallax_diorama.gd Scenes/Koperasi/ShopHub.tscn Scenes/Koperasi/CosmeticShop.tscn` (plus any `.uid` files the editor wrote for new scripts), message `feat(shop): light the shop hub and cosmetic shop like the Lobby`.

---

### Task 4: Koperasi lights its stage

**Files:**
- Modify (Recipe R): `Scenes/Koperasi/Koperasi.tscn`
- Test: `tests/test_lobby_look.gd`

**Interfaces:**
- Consumes: `LightPool.tscn`, `SunShafts.tscn`, `Census`.
- Produces: `Stage/Light` and `Stage/Shafts` in Koperasi, both at parallax depth 0.15.

- [ ] **Step 1: Write the failing test.** Append to `tests/test_lobby_look.gd`:

```gdscript
const KOPERASI := "res://Scenes/Koperasi/Koperasi.tscn"
## Koperasi's backdrop band depth (its Parallax, 2026-09-22): the light rides it.
const KOPERASI_BACK_DEPTH := 0.15


## Koperasi stays on layer 0: its backdrop shares Stage with the tappable goods
## and the parallax driving Stage's children. So the light sits in Stage,
## straight after the backdrop and under the goods, and nothing blooms.
func test_koperasi_lights_its_stage_under_the_goods() -> void:
	var c := Census.of(KOPERASI)
	var kids := Census.children_of(c, "Stage")
	assert_eq(kids.slice(0, 4), ["Background", "Light", "Shafts", "Barang1"] as Array[String],
		"the backdrop, its light, then the goods")
	assert_eq(Census.entry(c, "Stage/Light").get("instance"), LIGHT_POOL, "Light is a LightPool")
	assert_eq(Census.entry(c, "Stage/Shafts").get("instance"), SUN_SHAFTS, "Shafts are SunShafts")
	var depths: Dictionary = Census.prop(Census.entry(c, "Stage/Parallax"), "depth_by_child", {})
	for band in ["Light", "Shafts"]:
		assert_eq(float(depths.get(band, 0.0)), KOPERASI_BACK_DEPTH,
			band + " rides the backdrop's depth, so it stays on its window")
	assert_true(Census.entry(c, "World").is_empty(), "no World layer")
	for e in c:
		assert_ne(e["instance"], AMBIENT_GLOW, "nothing on layer 0 can bloom, so no Glow")
```

- [ ] **Step 2: Run it and watch it fail.** `test_run(suite="lobby_look")`. Expected: the new test fails on the Stage children.

- [ ] **Step 3: Edit the scene (Recipe R).** In `Scenes/Koperasi/Koperasi.tscn`:
  1. Add the ext_resources `look_pool` and `look_shafts` exactly as in Task 3 Step 6.1. Don't add a new `illus_grade` or `parallax_diorama` entry: the file already has both.
  2. Directly after the `[node name="Background" type="TextureRect" parent="Stage" …]` block and before `[node name="Barang1" …]`, insert:

```
[node name="Light" parent="Stage" instance=ExtResource("look_pool")]
center = Vector2(0.15, 0.1)
pool_size = Vector2(1600, 1600)
intensity = 0.1

[node name="Shafts" parent="Stage" instance=ExtResource("look_shafts")]
intensity = 0.15
```

  3. In `[node name="Parallax" …]`, set `depth_by_child` to:

```
depth_by_child = {
"Background": 0.15,
"Foreground": 1.0,
"Herman": 0.5,
"Light": 0.15,
"Shafts": 0.15
}
```

  Leave `overscan_children` as it is (planning amendment 9). Relaunch.

- [ ] **Step 4: Run and watch it pass.** Run `lobby_look`, `koperasi`, `parallax_diorama`, `tall_screen_layout` and `koperasi_tray`. Expected: PASS.

- [ ] **Step 5: Commit.** `git add Scenes/Koperasi/Koperasi.tscn tests/test_lobby_look.gd`, message `feat(shop): light the Koperasi stage under its goods`.

---

### Task 5: Measure the shops' bloom and check the light's placement

**Files:**
- Modify (Recipe R, values only): `Scenes/Koperasi/ShopHub.tscn`, `Scenes/Koperasi/CosmeticShop.tscn`, `Scenes/Koperasi/Koperasi.tscn`
- Modify: `tests/test_lobby_look.gd` (`BLOOM` values only)
- Create (scratch, not committed): `<scratchpad>/look/`

**Interfaces:** none new. Only knob values change.

- [ ] **Step 1: Placement by eye, once per screen.** For ShopHub, CosmeticShop and Koperasi: run the game, reach the screen with `change_scene_to_file`, freeze it (`GameSettings.reduce_motion = true`, `Engine.time_scale = 0.0`), capture a viewport PNG as in Recipe M step 2.2 and view it at full size. The pool and the shafts should read as light from the art's brightest opening. If the art's window or lamp sits elsewhere, move `Light.center` onto it and `Shafts.origin` just outside that edge. Write the new values into the `.tscn` with Recipe R, then capture again.
- [ ] **Step 2: Bloom.** Recipe M on ShopHub and CosmeticShop. Boxes: **ui** `300,850,500,1050` (the middle of the first tile); **far** `600,1300,1000,1600`; **core** `102,94,222,214` (or the box around the moved centre). Land each result: if a threshold passes, write it to `glow_threshold` on the scene's `Glow` node and to `BLOOM` in `tests/test_lobby_look.gd`. If none does, delete the node and set the entry to `null` (Recipe M step 5).
- [ ] **Step 3: Kurangi Gerakan, live.** On ShopHub, by `game_eval`: `Engine.time_scale = 1.0`, `tree.paused = true`, `GameSettings.reduce_motion = true`. Capture twice about 1 s apart and compare them with `region_maxdiff` over `0,0,1080,1920`: the result must be ≤ `0.004`. Repeat with `reduce_motion = false`: the difference must now exceed `0.004`, which proves the check can fail. Unpause, restore `reduce_motion = false` and stop the game.
- [ ] **Step 4: Run.** `lobby_look`, `shop_hub`, `koperasi`. Expected: PASS.
- [ ] **Step 5: Commit** (only if a value changed). `git add` the changed scenes and `tests/test_lobby_look.gd`, message `chore(shop): land the measured light and glow values`.

---

### Task 6: Docs, the full suite, and ship Part 1

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md`, `docs/superpowers/design/style-guide.md`, `docs/superpowers/specs/2026-09-26-ambient-kit-design.md`, `CLAUDE.md`

- [ ] **Step 1: style-guide.md.** At the end of "## Illustration materials", add:

```markdown
**The Lobby look on other screens** (spec
`docs/superpowers/specs/2026-09-28-lobby-look-everywhere-design.md`): the
backdrop and its light move into a `World` CanvasLayer at −1 holding one
`Room` Control; the light is a `LightPool` plus a full-screen `SunShafts`
(`Scenes/Look/SunShafts.tscn`); an `AmbientGlow` right after `World` blooms
only where its threshold was measured clean; menus and shops add a flat
`ParallaxDiorama`. Minigames and Koperasi keep their backdrop on layer 0 and
take the light without bloom.
```

- [ ] **Step 2: The ambient-kit spec.** In `docs/superpowers/specs/2026-09-26-ambient-kit-design.md`, append this to the line starting `**Out of this pass:**`: ` Koperasi/ShopHub, the end game's remaining screens and the minigames are taken up by 2026-09-28-lobby-look-everywhere-design.md.`
- [ ] **Step 3: DEBT.md.** In "**Ambient kit gaps (2026-09-27).**":
  - Change `the kit not yet extended to Inventory, Achievements or Koperasi/ShopHub` to `the kit not yet extended to Inventory or Achievements`.
  - After the sentence listing the screens that ship without bloom, add each shop screen that measured no clean threshold in Task 5, with its numbers, as `ShopHub (far +0.0xx at threshold 0.98, core +0.00x)`. Omit this if both shops bloom.
  - Add, as the paragraph's last sentence: `Koperasi cannot bloom at all: its backdrop shares Stage with the tappable goods on layer 0 (lobby-look spec, section 2).`
- [ ] **Step 4: The full suite.** Recipe R restart (no edits), then `test_run(session_id=<WT>)` with no suite. Budget one editor restart: the bridge drops after a full run, and the results stand if they arrived. Expected: every suite PASS. Real failures get fixed at the root; a single theme assertion may be ordering, so rerun that suite alone before believing it (CLAUDE.md). Afterwards run `git status --short` and revert `kejartes_theme.tres` / `default_bus_layout.tres` churn once the editor has exited.
- [ ] **Step 5: CLAUDE.md and CHANGELOG.md.** In CLAUDE.md, update `163 suites, 2509 tests (2026-09-28)` to the full run's counts and today's date. In CHANGELOG.md, add at the top (newest first):

```markdown
## 2026-09-28 — The Lobby look, part 1: the shops

`SunShafts` (`Scenes/Look/SunShafts.tscn`) is the Lobby's full-screen light
shafts as an ambient-kit piece: capped at the Lobby's 0.20, hidden by Efek
Suasana, frozen by Kurangi Gerakan. ShopHub and CosmeticShop moved their
backdrop into `World/Room` with the plain grade, a warm `LightPool`,
`SunShafts` and a flat parallax, all under the existing blur; Koperasi lights
its `Stage` under the goods. `ParallaxDiorama` now holds still under Kurangi
Gerakan, which stills the Lobby and Koperasi too. Bloom, measured with the
ambient kit's method: <one line per screen from results.md>.
`tests/scene_census.gd` is the shared census helper; `test_lobby_look` pins
every placement. Spec: `2026-09-28-lobby-look-everywhere-design.md`.
```

  Replace `<one line per screen from results.md>` with the measured lines from `<scratchpad>/look/results.md`.
- [ ] **Step 6: Commit.** `git add` the five docs, message `docs(look): record the shops' Lobby look`.
- [ ] **Step 7: Ship.** Invoke the `ship-pr` skill. It runs the suite and a local review, pushes, opens the PR against `Textures`, and stamps the tested commit. After `gh pr create`, bind the PR (`bind_pr` + `set_monitor`) at once (memory: bind the PR before stamping). Once it merges, remove the worktree (memory: remove worktrees once merged).

---

# Part 2 — End game (`feat/lobby-look-endgame`)

**Starts only after Part 1's PR has merged.**

### Task 7: The new worktree, then TesNotice and StatCheck

**Files:**
- Modify (Recipe R): `Scenes/EndGame/TesNotice.tscn`, `Scenes/EndGame/StatCheck.tscn`
- Modify: `tests/test_lobby_look.gd`, `tests/test_ambient_kit.gd`, `tests/test_tes_notice.gd`, `tests/test_stat_check.gd`, `tests/test_tall_screen_layout.gd`, `tests/test_illustration_ao.gd`, `tests/test_parallax_diorama.gd`

**Interfaces:**
- Consumes: everything Part 1 produced, now on `Textures`.
- Produces: `World/Room/{Backdrop, Tint, Light, Shafts, Parallax}` on both screens, with `Glow` second at the root.

- [ ] **Step 1: The worktree.** From the main checkout, after `git fetch origin`: `git worktree add -b feat/lobby-look-endgame .claude/worktrees/lobby-look-endgame origin/Textures`. Then Task 0 Steps 2–5 in that directory. The Step 4 suites are now `lobby_look`, `ambient_kit`, `tes_notice`, `stat_check`, `exam_progress`, `end_cutscene`, `run_result`, `win_stage`, `tall_screen_layout`, `illustration_ao`, `parallax_diorama`, `clean_code`.
- [ ] **Step 2: Write the failing tests.**
  - `tests/test_lobby_look.gd`: add the path consts after `COSMETIC_SHOP`:

```gdscript
const TES_NOTICE := "res://Scenes/EndGame/TesNotice.tscn"
const STAT_CHECK := "res://Scenes/EndGame/StatCheck.tscn"
```

  add to `ROOMS`:

```gdscript
	TES_NOTICE: ["Backdrop", "Tint", "Light", "Shafts", "Parallax"],
	STAT_CHECK: ["Backdrop", "Tint", "Light", "Shafts", "Parallax"],
```

  add to `BLOOM`: `TES_NOTICE: 0.9,` and `STAT_CHECK: 0.9,`. Then append:

```gdscript
## The exam notices' light is cool and dim, to sit under their TEGANG tint.
func test_the_exam_notices_light_is_cool() -> void:
	for scene_path in [TES_NOTICE, STAT_CHECK]:
		var c := Census.of(scene_path)
		var colour: Color = Census.prop(Census.entry(c, "World/Room/Light"), "light_color", Color.WHITE)
		assert_true(colour.b > colour.r, scene_path + ": the pool is cool, blue over red")
		var shafts: Color = Census.prop(Census.entry(c, "World/Room/Shafts"), "shaft_color", Color.WHITE)
		assert_true(shafts.b > shafts.r, scene_path + ": and so are the shafts")
		assert_eq(_drawn(scene_path).slice(0, 2), ["World", "Scrim"] as Array[String],
			scene_path + ": the scrim draws over the room, under the card")
```

  - `tests/test_ambient_kit.gd`, `test_the_exam_notices_wear_the_tense_mood`: replace the body's first four lines (from `var kids := _children_of(c, ".")` through the `find("Backdrop") + 1` assertion) with:

```gdscript
		var kids := _children_of(c, "World/Room")
		assert_eq(kids.find("Tint"), kids.find("Backdrop") + 1,
			path + ": the tint sits directly after the backdrop, so it tints nothing else")
```

  and change `_entry(c, "Tint")` to `_entry(c, "World/Room/Tint")` in the two lines that follow.
  - `tests/test_tes_notice.gd`, `test_has_the_backdrop_scrim_and_card`: `"Backdrop"` becomes `"World/Room/Backdrop"`.
  - `tests/test_stat_check.gd`, `test_scene_loads_with_its_chrome`: `screen.get_node_or_null("Backdrop")` becomes `screen.get_node_or_null("World/Room/Backdrop")`.
  - `tests/test_tall_screen_layout.gd`, `LIT_BACKDROPS`: add `"res://Scenes/EndGame/TesNotice.tscn": "World/Room/Backdrop",` and `"res://Scenes/EndGame/StatCheck.tscn": "World/Room/Backdrop",`.
  - `tests/test_illustration_ao.gd`, `BACKDROPS`: add `"res://Scenes/EndGame/TesNotice.tscn": ["World/Room/Backdrop"],` and `"res://Scenes/EndGame/StatCheck.tscn": ["World/Room/Backdrop"],`.
  - `tests/test_parallax_diorama.gd`, `FLAT_DIORAMAS`: add `"res://Scenes/EndGame/TesNotice.tscn": "World/Room",` and `"res://Scenes/EndGame/StatCheck.tscn": "World/Room",`.
- [ ] **Step 3: Run and watch them fail.** Run the suites named in Step 2. Expected: FAIL on every TesNotice and StatCheck path; the rest PASS.
- [ ] **Step 4: Edit the scenes (Recipe R).** For `Scenes/EndGame/TesNotice.tscn`:
  1. Add the ext_resources `illus_grade`, `look_pool`, `look_shafts`, `look_glow` and `parallax_diorama` as in Task 3 Step 6.1.
  2. Replace the `Backdrop` and `Tint` blocks with:

```
[node name="World" type="CanvasLayer" parent="."]
layer = -1

[node name="Room" type="Control" parent="World"]
unique_name_in_owner = true
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Backdrop" type="TextureRect" parent="World/Room" unique_id=531112344]
material = ExtResource("illus_grade")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("2_jutky")
expand_mode = 1
stretch_mode = 6

[node name="Tint" parent="World/Room" instance=ExtResource("amb_tint")]
mood = 4
strength = 0.3

[node name="Light" parent="World/Room" instance=ExtResource("look_pool")]
center = Vector2(0.15, 0.08)
pool_size = Vector2(1600, 1600)
light_color = Color(0.78, 0.86, 1, 1)
intensity = 0.06

[node name="Shafts" parent="World/Room" instance=ExtResource("look_shafts")]
shaft_color = Color(0.78, 0.86, 1, 1)
intensity = 0.1

[node name="Parallax" type="Control" parent="World/Room"]
layout_mode = 1
anchors_preset = 0
mouse_filter = 2
script = ExtResource("parallax_diorama")
depth_by_child = {
"Backdrop": 1.0,
"Light": 1.0,
"Shafts": 1.0,
"Tint": 1.0
}
overscan_children = Array[StringName]([&"Backdrop", &"Tint", &"Shafts"])

[node name="Glow" parent="." instance=ExtResource("look_glow")]
```

  3. `Scenes/EndGame/StatCheck.tscn`: the same, with its backdrop `unique_id=1085290687` and texture id `"2_2mn6t"`. The old node's fixed `offset_right = 1080.0` / `offset_bottom = 1920.0` are **not** carried over: the new block is Full Rect (planning amendment 6).

  Relaunch.
- [ ] **Step 5: Run and watch them pass.** Run the Step 2 suites plus `end_game_rehearsal`. Expected: PASS.
- [ ] **Step 6: Commit.** `git add` the two scenes and seven tests, message `feat(endgame): light the exam notices like the Lobby`.

---

### Task 8: ExamProgress

**Files:**
- Modify (Recipe R): `Scenes/EndGame/ExamProgress.tscn`
- Modify: `Scripts/EndGame/ExamProgress.gd` (the `backdrop` @onready)
- Modify: `tests/test_lobby_look.gd`, `tests/test_exam_progress.gd`, `tests/test_illustration_ao.gd`

**Interfaces:**
- Produces: `World/Room/{Backdrop, Light, Shafts}` on ExamProgress, with no Parallax (planning amendment 3), and `Backdrop` as `%Backdrop`.

- [ ] **Step 1: Write the failing tests.**
  - `tests/test_lobby_look.gd`: const `EXAM_PROGRESS := "res://Scenes/EndGame/ExamProgress.tscn"`, `ROOMS` entry `EXAM_PROGRESS: ["Backdrop", "Light", "Shafts"],`, `BLOOM` entry `EXAM_PROGRESS: 0.9,`. Append:

```gdscript
## ExamProgress already pans its backdrop with a tween on position.x, so it
## takes no Parallax (planning amendment 3), and the script finds the moved
## backdrop by unique name.
func test_exam_progress_pans_its_own_backdrop() -> void:
	var c := Census.of(EXAM_PROGRESS)
	assert_eq(Census.prop(Census.entry(c, "World/Room/Backdrop"), "unique_name_in_owner"), true,
		"the backdrop is %Backdrop")
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/ExamProgress.gd")
	assert_true(src.contains("backdrop: TextureRect = %Backdrop"), "ExamProgress.gd finds it by name")
```

  - `tests/test_exam_progress.gd`: every `"Backdrop"` passed to `get_node` or `get_node_or_null` (lines 38, 103, 111 and 142) becomes `"World/Room/Backdrop"`.
  - `tests/test_illustration_ao.gd`, `BACKDROPS`: add `"res://Scenes/EndGame/ExamProgress.tscn": ["World/Room/Backdrop"],`.
- [ ] **Step 2: Run and watch them fail.** `lobby_look`, `exam_progress`, `illustration_ao`: FAIL on the ExamProgress paths.
- [ ] **Step 3: Edit.** `Scripts/EndGame/ExamProgress.gd`: change `@onready var backdrop: TextureRect = $Backdrop` to `@onready var backdrop: TextureRect = %Backdrop`. Then, with Recipe R, in `Scenes/EndGame/ExamProgress.tscn`:
  1. Add the ext_resources `illus_grade`, `look_pool`, `look_shafts` and `look_glow`.
  2. Replace the `Backdrop` block with a `World`/`Room` pair exactly as in Task 7, then:

```
[node name="Backdrop" type="TextureRect" parent="World/Room" unique_id=384324851]
unique_name_in_owner = true
custom_minimum_size = Vector2(1296, 1920)
material = ExtResource("illus_grade")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_right = 216.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("2_6eyov")
expand_mode = 1
stretch_mode = 6

[node name="Light" parent="World/Room" instance=ExtResource("look_pool")]
center = Vector2(0.15, 0.08)
pool_size = Vector2(1600, 1600)
intensity = 0.08

[node name="Shafts" parent="World/Room" instance=ExtResource("look_shafts")]
intensity = 0.15

[node name="Glow" parent="." instance=ExtResource("look_glow")]
```

  Relaunch.
- [ ] **Step 4: Run and watch them pass.** `lobby_look`, `exam_progress`, `illustration_ao`, `ambient_kit` (`test_exam_progress_stays_undarkened` must still hold), `clean_code`. Expected: PASS.
- [ ] **Step 5: Commit.** Message `feat(endgame): light the exam in progress`.

---

### Task 9: WinStage lights its painting for the verdict

**Files:**
- Modify (Recipe R): `Scenes/EndGame/WinStage.tscn`
- Modify: `Scripts/EndGame/WinStage.gd` (two `@onready`s, `dress()`)
- Modify: `tests/test_win_stage.gd`, `tests/test_illustration_ao.gd`

**Interfaces:**
- Consumes: `LightPool.tscn`, `SunShafts.tscn`.
- Produces: `Stage/LightPass` (a Control holding `Light` and `Shafts`) and `Stage/LightFail` (a Control holding `Light`) in WinStage. `dress(failed, names)` shows exactly one of them.

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_win_stage.gd`:

```gdscript
# ───────────────────────────────────────────────────── the Lobby look (2026-09-28)

## The verdict picks the light (lobby-look spec, planning amendment 4): a pass
## gets a warm pool and shafts, a fail a dim cool pool. Both are authored in
## the Stage, over the figures, so they ride the letterboxed painting; the
## one shared scene is what keeps EndCutscene and RunResult's swap invisible.
func test_the_stage_carries_both_lights_over_the_figures() -> void:
	var s := _stage()
	var names: Array[String] = []
	for c in s.get_node("Stage").get_children():
		names.append(String(c.name))
	assert_eq(names, ["Backdrop", "Shadows", "Students", "LightPass", "LightFail"] as Array[String],
		"the painting, its shadows and figures, then the two lights")
	assert_eq(s.get_node("Stage/LightPass/Light").scene_file_path, "res://Scenes/Look/LightPool.tscn",
		"a pass has a pool")
	assert_eq(s.get_node("Stage/LightPass/Shafts").scene_file_path, "res://Scenes/Look/SunShafts.tscn",
		"and shafts")
	assert_eq(s.get_node("Stage/LightFail/Light").scene_file_path, "res://Scenes/Look/LightPool.tscn",
		"a fail has only a pool")
	assert_eq(s.get_node("Stage/LightFail").get_child_count(), 1, "and no shafts")


func test_dressing_picks_one_light() -> void:
	var s := _live_stage()
	s.dress(false, _FOUR)
	var pass_on := (s.get_node("Stage/LightPass") as CanvasItem).visible
	var fail_on := (s.get_node("Stage/LightFail") as CanvasItem).visible
	s.dress(true, _FOUR)
	var pass_after := (s.get_node("Stage/LightPass") as CanvasItem).visible
	var fail_after := (s.get_node("Stage/LightFail") as CanvasItem).visible
	Engine.get_main_loop().root.remove_child(s)
	assert_true(pass_on and not fail_on, "a pass shows LightPass only")
	assert_true(fail_after and not pass_after, "a fail shows LightFail only")
```

  In `tests/test_illustration_ao.gd`, add to `BACKDROPS`: `"res://Scenes/EndGame/WinStage.tscn": ["Stage/Backdrop"],`. Add to `CUTOUTS`:

```gdscript
	# 2026-09-28: the graduation lineup, splash art on transparency.
	"res://Scenes/EndGame/WinStage.tscn": [
		"Stage/Students/Student1", "Stage/Students/Student2",
		"Stage/Students/Student3", "Stage/Students/Student4",
	],
```

- [ ] **Step 2: Run and watch them fail.** `win_stage`, `illustration_ao`: FAIL on the new tests and entries.
- [ ] **Step 3: The script.** In `Scripts/EndGame/WinStage.gd`, after `@onready var students: Control = $Stage/Students`, add:

```gdscript
## The warm pool and shafts a pass is lit by (lobby-look spec, amendment 4).
@onready var light_pass: Control = $Stage/LightPass
## The dim cool pool a fail is lit by.
@onready var light_fail: Control = $Stage/LightFail
```

  In `dress()`, after `backdrop.texture = lose_backdrop if failed else win_backdrop`, add:

```gdscript
	light_pass.visible = not failed
	light_fail.visible = failed
```

  Add ` and which light is shown` to the end of the sentence in `dress()`'s `##` comment that begins `Sets BarFill, PhotoFrame,`, before its closing `--`.
- [ ] **Step 4: The scene (Recipe R).** In `Scenes/EndGame/WinStage.tscn`:
  1. Add ext_resources `illus_grade`, `look_pool`, `look_shafts` (as in Task 3), plus `[ext_resource type="Material" path="res://Scripts/Shaders/illustration_grade_cutout.tres" id="illus_grade_cut"]`.
  2. Add `material = ExtResource("illus_grade")` as the first property of `Stage/Backdrop`, and `material = ExtResource("illus_grade_cut")` as the first property of each `Stage/Students/Student1`–`Student4`.
  3. After the last `Stage/Students/Student4` block, append:

```
[node name="LightPass" type="Control" parent="Stage"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Light" parent="Stage/LightPass" instance=ExtResource("look_pool")]
center = Vector2(0.2, 0.1)
pool_size = Vector2(2000, 2000)
intensity = 0.1

[node name="Shafts" parent="Stage/LightPass" instance=ExtResource("look_shafts")]

[node name="LightFail" type="Control" parent="Stage"]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Light" parent="Stage/LightFail" instance=ExtResource("look_pool")]
center = Vector2(0.5, 0.2)
pool_size = Vector2(2000, 2000)
light_color = Color(0.7, 0.8, 1, 1)
intensity = 0.05
```

  Relaunch.
- [ ] **Step 5: Run and watch them pass.** `win_stage`, `illustration_ao`, `end_cutscene`, `run_result`, `clean_code`, `script_documentation`. Expected: PASS.
- [ ] **Step 6: Commit.** Message `feat(endgame): the win stage lights its painting for the verdict`.

---

### Task 10: EndCutscene and RunResult move the stage into the World

**Files:**
- Modify (Recipe R): `Scenes/EndGame/EndCutscene.tscn`, `Scenes/EndGame/RunResult.tscn`
- Modify: `Scripts/EndGame/EndCutscene.gd`, `Scripts/EndGame/RunResult.gd`
- Modify: `tests/test_lobby_look.gd`, `tests/test_end_cutscene.gd`, `tests/test_run_result.gd`, `tests/test_ambient_kit.gd`

**Interfaces:**
- Consumes: `WinStage` with its lights (Task 9).
- Produces: `World/Room/WinStage` (`%WinStage`) and `%Room` on both screens, with `Glow` second at the root. RunResult's exit fade fades `%Room` too.

- [ ] **Step 1: Write the failing tests.**
  - `tests/test_lobby_look.gd`: consts `END_CUTSCENE := "res://Scenes/EndGame/EndCutscene.tscn"` and `RUN_RESULT := "res://Scenes/EndGame/RunResult.tscn"`; `ROOMS` entries `END_CUTSCENE: ["WinStage"],` and `RUN_RESULT: ["WinStage"],`; `BLOOM` entries `END_CUTSCENE: 0.9,` and `RUN_RESULT: 0.9,`. Append:

```gdscript
## EndCutscene hands over to RunResult with an invisible swap of the same
## frame, so both must bloom it alike (planning amendment 4).
func test_the_two_verdict_screens_bloom_alike() -> void:
	assert_eq(BLOOM[END_CUTSCENE], BLOOM[RUN_RESULT],
		"EndCutscene and RunResult share one glow decision")


## A CanvasLayer ignores its parent's modulate, so RunResult's exit fade must
## fade the Room as well as its root, or the painting stays lit to the end.
func test_run_result_fades_its_room_on_the_way_out() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/RunResult.gd")
	assert_true(src.contains("@onready var room: Control = %Room"), "RunResult finds its Room")
	assert_true(src.contains("tween.parallel().tween_property(room, \"modulate:a\", 0.0,"),
		"and fades it alongside the root")


func test_both_hosts_find_the_moved_stage_by_name() -> void:
	for path in ["res://Scripts/EndGame/EndCutscene.gd", "res://Scripts/EndGame/RunResult.gd"]:
		assert_true(FileAccess.get_file_as_string(path).contains("win_stage: WinStage = %WinStage"),
			path + " finds the stage by unique name")
```

  - `tests/test_end_cutscene.gd`:
    - `test_scene_has_the_chrome`: `s.get_node_or_null("WinStage")` → `s.get_node_or_null("World/Room/WinStage")`.
    - `test_both_verdicts_are_dressed_from_exports`: `s.get_node("WinStage")` → `s.get_node("World/Room/WinStage")`.
    - `test_the_blur_layer_blurs_the_backdrop_but_not_the_badge_or_button`: replace `var stage_at := order.find("WinStage")` with `var stage_at := order.find("World")`, the first assertion's message with `"World, which holds the stage, is a direct child of the root"`, and the second's with `"World draws first, so the shader samples the painting and its figures"`.
    - `test_the_blur_layer_draws_above_the_stage`: replace its body with:

```gdscript
	var s := _scene()
	var world := s.get_node("World") as CanvasLayer
	assert_eq(world.layer, -1, "the stage's World draws below layer 0, where BlurLayer is")
	assert_true(s.get_node_or_null("World/Room/WinStage") is WinStage,
		"and holds the stage, so the students blur out with the backdrop")
```

    - `test_the_painting_and_lineup_come_from_the_shared_win_stage`: replace `var first := s.get_child(0)` and the next assertion with:

```gdscript
	assert_eq(s.get_child(0).name, &"World", "the stage's World is the first thing drawn")
	var first := s.get_node("World/Room/WinStage")
```

  - `tests/test_run_result.gd`:
    - `test_the_screen_has_a_backdrop_grade_card_and_rows_box`: `"WinStage"` → `"World/Room/WinStage"`.
    - The draw-order assertion `order.find("WinStage") < order.find("BlurLayer")` becomes `order.find("World") < order.find("BlurLayer")`, with the message `"the stage's World draws first, so the shader samples it"`.
    - `test_the_old_backdrop_node_is_gone`: `assert_eq(first_name, "WinStage", "which draws first")` becomes `assert_eq(first_name, "World", "the stage's World draws first")`.
  - `tests/test_ambient_kit.gd`, `test_run_result_carries_both_moods_over_the_blur`: the order assertion becomes (a Glow, if measurement keeps one, is left out; `lobby_look` owns it):

```gdscript
	var order := _children_of(c, ".")
	order.erase("Glow")
	assert_eq(order.slice(0, 4),
		["World", "BlurLayer", "AmbientPass", "AmbientFail"] as Array[String],
		"both moods draw over the blurred stage, under the report")
```

- [ ] **Step 2: Run and watch them fail.** `lobby_look`, `end_cutscene`, `run_result`, `ambient_kit`: FAIL on the moved paths.
- [ ] **Step 3: The scripts.**
  - `Scripts/EndGame/EndCutscene.gd`: `@onready var win_stage: WinStage = $WinStage` → `@onready var win_stage: WinStage = %WinStage`. Its `##` comment gains a line: `## It lives in World/Room, on layer -1, so AmbientGlow blooms it and not the badge.`
  - `Scripts/EndGame/RunResult.gd`: `@onready var win_stage: WinStage = $WinStage` → `@onready var win_stage: WinStage = %WinStage`. After it, add:

```gdscript
## The World layer's one Control. A CanvasLayer ignores this screen's own
## modulate, so the exit fade fades the Room too (lobby-look amendment 1).
@onready var room: Control = %Room
```

    Add beside the script's other consts:

```gdscript
## Seconds the report and its Room take to fade out on Selesai.
const EXIT_FADE_SECONDS := 0.4
```

    In `_on_selesai_pressed`, replace `tween.tween_property(self, "modulate:a", 0.0, 0.4)` with:

```gdscript
	tween.tween_property(self, "modulate:a", 0.0, EXIT_FADE_SECONDS)
	tween.parallel().tween_property(room, "modulate:a", 0.0, EXIT_FADE_SECONDS)
```
- [ ] **Step 4: The scenes (Recipe R).** For `Scenes/EndGame/EndCutscene.tscn`:
  1. Add the ext_resource `look_glow`.
  2. Replace the `[node name="WinStage" parent="." unique_id=702781057 instance=ExtResource("4_iwdes")]` block with:

```
[node name="World" type="CanvasLayer" parent="."]
layer = -1

[node name="Room" type="Control" parent="World"]
unique_name_in_owner = true
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="WinStage" parent="World/Room" unique_id=702781057 instance=ExtResource("4_iwdes")]
unique_name_in_owner = true
layout_mode = 1
grow_horizontal = 2
grow_vertical = 2

[node name="Glow" parent="." instance=ExtResource("look_glow")]
```

  3. `Scenes/EndGame/RunResult.tscn`: the same. Keep its own WinStage `unique_id` and ext_resource id, both read from the file's current `[node name="WinStage" …]` line, and any properties that block sets.

  Relaunch.
- [ ] **Step 5: Run and watch them pass.** `lobby_look`, `end_cutscene`, `run_result`, `ambient_kit`, `win_stage`, `end_game_rehearsal`, `run_grade_ranks`, `clean_code`. Expected: PASS.
- [ ] **Step 6: Commit.** Message `feat(endgame): the verdict screens light their stage like the Lobby`.

---

### Task 11: Measure, document and ship Part 2

**Files:**
- Modify (values only, Recipe R): the five end-game scenes
- Modify: `tests/test_lobby_look.gd` (`BLOOM` values), `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md`, `CLAUDE.md`

- [ ] **Step 1: Placement by eye.** As in Task 5 Step 1, for TesNotice, StatCheck, ExamProgress, and EndCutscene both ways. Arm the debug overlay's **🎭 Gladi Resik Akhir Kelas**, first *Semua Lulus* and then *Semua Gagal* (authoring guide, "Editor and game recipes"), let the sequence reach EndCutscene, freeze, and capture. Afterwards use **↩ Pulihkan Run Sebelum Gladi Resik**. For WinStage's lights the `center` and `origin` are in the painting's art space (1536×2048).
- [ ] **Step 2: Bloom.** Recipe M on TesNotice, StatCheck, ExamProgress, and EndCutscene before Next (pass). Boxes, starting points to adjust to the art: **ui** = the card's middle (TesNotice `400,900,680,1000`; StatCheck the card slot's middle; ExamProgress the progress bar; EndCutscene the badge area `400,800,680,1000` on a fail capture); **far** `600,1300,1000,1600`; **core** around each pool's centre. Land each result in its `Glow` and `BLOOM`. EndCutscene's decision is written to RunResult as well (`test_the_two_verdict_screens_bloom_alike`).
- [ ] **Step 3: The swap stays invisible.** With *Semua Lulus* armed, capture EndCutscene's last blurred frame (after Next, just before the scene changes) and RunResult's first frame, with `reduce_motion = true`. Compare them with `region_maxdiff` over a `far` box, excluding the report card: ≤ `0.02`. If not, the two screens light or bloom the stage differently: stop and report.
- [ ] **Step 4: Run** `lobby_look`, `end_cutscene`, `run_result`: PASS. Commit any changed values: `chore(endgame): land the measured light and glow values`.
- [ ] **Step 5: Docs.** CHANGELOG entry `## 2026-09-28 — The Lobby look, part 2: the end of the grade`, in the Part 1 format: the five screens, WinStage's verdict lights, ExamProgress's and the verdict screens' no-parallax reasons (amendment 3), StatCheck's Full Rect fix, and the measured lines from `results.md`. DEBT.md: add each end-game screen that measured no clean threshold to the `hdr_2d` entry, with its numbers. Update the CLAUDE.md suite count after Step 6.
- [ ] **Step 6: Full suite and ship.** As in Task 6 Steps 4, 6 and 7, with the message `docs(look): record the end game's Lobby look`.

---

# Part 3 — Minigames (`feat/lobby-look-minigames`)

**Starts only after Part 2's PR has merged.**

### Task 12: The new worktree, and Badminton's court moves into its scene

**Files:**
- Modify (Recipe R): `Scenes/Minigames/Olahraga/Badminton.tscn`
- Modify: `Scripts/Minigames/Olahraga/Badminton.gd` (remove `_add_background()` and its call)
- Modify: `tests/test_badminton_visuals.gd`, `tests/test_viewport_editability.gd`, `tests/test_illustration_ao.gd`

**Interfaces:**
- Produces: a `Background` TextureRect as Badminton's first child, on the plain grade, ignoring taps.

- [ ] **Step 1: The worktree.** `git worktree add -b feat/lobby-look-minigames .claude/worktrees/lobby-look-minigames origin/Textures` after `git fetch origin`, then Task 0 Steps 2–5 there. The Step 4 suites are `lobby_look`, `badminton_visuals`, `viewport_editability`, `illustration_ao`, `event_dialogue`, `school_day`, `clean_code`.
- [ ] **Step 2: Write the failing tests.**
  - Append to `tests/test_badminton_visuals.gd`:

```gdscript
## The court is authored in the scene (lobby-look spec, 2026-09-28), so the 2D
## viewport shows it and the Lobby look can light it; the script no longer
## builds it at runtime.
func test_the_court_is_an_authored_backdrop() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var bg := root.get_node_or_null("Background") as TextureRect
	assert_not_null(bg, "Badminton.tscn carries a Background")
	if bg == null:
		return
	assert_eq(bg.get_index(), 0, "drawn first, under the rackets and the shuttlecock")
	assert_eq(bg.texture.resource_path, "res://Assets/Images/Textures/lapanganBadminton.jpg",
		"the court art")
	assert_eq(bg.mouse_filter, Control.MOUSE_FILTER_IGNORE, "input stays with _input")
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("_add_background"), "the script no longer builds the court")
```

  - `tests/test_viewport_editability.gd`, `BASELINE`: `"res://Scripts/Minigames/Olahraga/Badminton.gd": 8,` → `7,`.
  - `tests/test_illustration_ao.gd`, `BACKDROPS`: add `"res://Scenes/Minigames/Olahraga/Badminton.tscn": ["Background"],`.
- [ ] **Step 3: Run and watch them fail.** `badminton_visuals`, `viewport_editability` (BASELINE now under the scan), `illustration_ao`: FAIL.
- [ ] **Step 4: The script.** In `Scripts/Minigames/Olahraga/Badminton.gd`, delete the line `_add_background()` in `_ready()` and the whole `func _add_background() -> void:` function (from its `func` line through `move_child(bg, 0)`).
- [ ] **Step 5: The scene (Recipe R).** In `Scenes/Minigames/Olahraga/Badminton.tscn`:
  1. Add ext_resources `[ext_resource type="Texture2D" path="res://Assets/Images/Textures/lapanganBadminton.jpg" id="court_tex"]` and `[ext_resource type="Material" path="res://Scripts/Shaders/illustration_grade_material.tres" id="illus_grade"]`.
  2. Directly after the root `[node name="Badminton" …]` block, before the first child, insert:

```
[node name="Background" type="TextureRect" parent="."]
material = ExtResource("illus_grade")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("court_tex")
expand_mode = 1
```

  `stretch_mode` stays at its default, `STRETCH_SCALE`, as the runtime version had it: the walls are placed at the court's edges, so a cover crop would move the lines off them. Relaunch.
- [ ] **Step 6: Run and watch them pass.** The Step 1 suites. Expected: PASS.
- [ ] **Step 7: Commit.** Message `refactor(badminton): author the court in the scene`.

---

### Task 13: Every minigame lights its backdrop

**Files:**
- Modify (Recipe R): `Scenes/Minigames/Akademis/{PilihanGanda,Menjodohkan,Password,Variabel}.tscn`, `Scenes/Minigames/Olahraga/{MainBola,Badminton}.tscn`, `Scenes/Minigames/SeniBudaya/{LombaMenari,BuatBatik}.tscn`
- Test: `tests/test_lobby_look.gd`

**Interfaces:**
- Consumes: `LightPool.tscn`, `SunShafts.tscn`, Badminton's authored `Background` (Task 12).
- Produces: `Light` (and `Shafts`, except BuatBatik) directly after each minigame's backdrop, on layer 0.

- [ ] **Step 1: Write the failing test.** Append to `tests/test_lobby_look.gd`:

```gdscript
## Minigame -> [its backdrop node, whether it throws shafts]. They stay on
## layer 0: SchoolDay hosts a minigame inside its own tree, over its own
## layer-0 background, so a World at -1 would draw under that and never show,
## and SchoolDay's fade-in on the minigame's root would not reach it. So the
## light sits directly after the backdrop and nothing blooms (spec, pass 3).
## BuatBatik takes no shafts, so no ray crosses the drawing canvas.
const MINIGAMES := {
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn": ["Background", true],
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn": ["Background", true],
	"res://Scenes/Minigames/Akademis/Password.tscn": ["Background", true],
	"res://Scenes/Minigames/Akademis/Variabel.tscn": ["Background", true],
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": ["FieldBG", true],
	"res://Scenes/Minigames/Olahraga/Badminton.tscn": ["Background", true],
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn": ["Background", true],
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn": ["Background", false],
}


func test_every_minigame_lights_its_backdrop_on_layer_0() -> void:
	for scene_path in MINIGAMES:
		var c := Census.of(scene_path)
		var backdrop: String = MINIGAMES[scene_path][0]
		var throws_shafts: bool = MINIGAMES[scene_path][1]
		var kids := Census.children_of(c, ".")
		assert_eq(kids.find(backdrop), 0, scene_path + ": the backdrop is still drawn first")
		assert_eq(kids.find("Light"), 1, scene_path + ": the light sits right after it")
		assert_eq(Census.entry(c, "Light").get("instance"), LIGHT_POOL, scene_path + ": a LightPool")
		if throws_shafts:
			assert_eq(kids.find("Shafts"), 2, scene_path + ": then the shafts")
			assert_eq(Census.entry(c, "Shafts").get("instance"), SUN_SHAFTS, scene_path + ": SunShafts")
		else:
			assert_eq(kids.find("Shafts"), -1, scene_path + ": no shafts")
		for e in c:
			assert_ne(e["instance"], AMBIENT_GLOW, scene_path + ": no Glow on layer 0")
			if e["type"] == "CanvasLayer":
				assert_true(int(Census.prop(e, "layer", 1)) >= 0,
					"%s: %s must not draw under SchoolDay's background" % [scene_path, e["path"]])
```

- [ ] **Step 2: Run it and watch it fail.** `test_run(suite="lobby_look")`: FAIL for all eight.
- [ ] **Step 3: Edit the eight scenes (Recipe R, one close for all eight).** In each file, add the ext_resources `look_pool` and `look_shafts` (BuatBatik: `look_pool` only), then insert the block below directly after the backdrop node's block (`Background`, or `FieldBG` in MainBola) and before the next `[node …]`:

| Scene | Block |
|---|---|
| PilihanGanda, Menjodohkan, Password, Variabel | `Light`: `center = Vector2(0.15, 0.1)`, `pool_size = Vector2(1400, 1400)`, `intensity = 0.1`. `Shafts`: `intensity = 0.12` |
| MainBola, Badminton | `Light`: `center = Vector2(0.1, 0.02)`, `pool_size = Vector2(1800, 1800)`, `intensity = 0.1`. `Shafts`: `origin = Vector2(0.1, -0.1)` |
| LombaMenari | `Light`: `center = Vector2(0.5, 0.05)`, `pool_size = Vector2(1400, 1800)`, `aspect = 0.8`, `intensity = 0.1`. `Shafts`: `origin = Vector2(0.5, -0.1)`, `shaft_count = 5.0`, `intensity = 0.15` |
| BuatBatik | `Light`: `center = Vector2(0.15, 0.08)`, `pool_size = Vector2(1400, 1400)`, `intensity = 0.08`. No `Shafts` |

  As text, for the desk games for example:

```
[node name="Light" parent="." instance=ExtResource("look_pool")]
center = Vector2(0.15, 0.1)
pool_size = Vector2(1400, 1400)
intensity = 0.1

[node name="Shafts" parent="." instance=ExtResource("look_shafts")]
intensity = 0.12
```

  MainBola's block goes before `FieldMarkings`, so the pitch lines draw over the light and stay crisp. Relaunch.
- [ ] **Step 4: Run and watch it pass.** `lobby_look`, `badminton_visuals`, `school_day`, `event_dialogue`, `minigame_overlays`, `illustration_ao`, `tall_screen_layout`. Expected: PASS.
- [ ] **Step 5: See each once.** For each of the eight: `project_run`, then `change_scene_to_file(<path>)` by `game_eval`. Freeze it (`reduce_motion = true`, `time_scale = 0.0`), capture the viewport at full size and look at it. The light should fall on the art's own light source (lamp, sun, stage spotlight) and not over the play area's key reads: MainBola's goal, the Badminton net, LombaMenari's hit zone. Move `center`/`origin` if not, with Recipe R, and capture again. Also check that a minigame launched from SchoolDay still fades in: seed, run Atur Jadwal, start the day with the debug minigame launcher, and see the light arrive with the game rather than pop in.
- [ ] **Step 6: Commit.** `git add` the eight scenes and `tests/test_lobby_look.gd`, message `feat(minigames): light every minigame backdrop like the Lobby`.

---

### Task 14: Document and ship Part 3

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md`, `CLAUDE.md`

- [ ] **Step 1: DEBT.md.** Append to the "**Ambient kit gaps**" paragraph: `The minigames cannot bloom either: SchoolDay hosts each one inside its own tree over a layer-0 Background, so a World layer at -1 would draw under it, and SchoolDay's fade on the minigame root would not reach a CanvasLayer. Blooming them means hosting minigames on their own CanvasLayer in SchoolDay (lobby-look spec, pass 3).`
- [ ] **Step 2: CHANGELOG.md.** Entry `## 2026-09-28 — The Lobby look, part 3: the minigames`: the eight games lit on layer 0 with no bloom and why, BuatBatik without shafts, Badminton's court authored in the scene (runtime-construction ratchet 8 → 7).
- [ ] **Step 3: Full suite, CLAUDE.md count, and ship.** As in Task 6 Steps 4, 6 and 7, with the message `docs(look): record the minigames' Lobby look`.
