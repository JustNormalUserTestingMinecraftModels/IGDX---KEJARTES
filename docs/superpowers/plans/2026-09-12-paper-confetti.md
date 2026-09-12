# Paper Confetti Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ResultCheckup's top-down white confetti with a two-cannon burst of red, yellow and blue paper sheets that shoot up from both bottom corners and flutter down, visibly flipping.

**Architecture:** A new `PaperConfetti.tscn` (root `GPUParticles2D` = left cannon, using the existing `RewardParticles` script; one child `RightCannon`) with mirrored `ParticleProcessMaterial`s, a shared constant-interpolation color ramp, and a shared `ShaderMaterial` running a new `paper_flutter.gdshader` that squashes each quad on its own x axis to fake a 3D flip. `ResultCheckup` swaps its `Celebration` marker and `_CELEBRATION_SCENE` path to the new scene; nothing else changes.

**Tech Stack:** Godot 4.6.2, GDScript, Godot shading language (`canvas_item`), `McpTestSuiteCompat` suites run in the editor via the Godot AI MCP `test_run`.

**Spec:** `docs/superpowers/specs/2026-09-12-paper-confetti-design.md`

## Global Constraints

- Scope is `ResultCheckup` only. Do **not** modify `Scenes/SchoolSimulation/CelebrationConfetti.tscn`, `Scripts/Inventory/ApplyItemScreen.gd`, `Scenes/Minigames/UI/ResultConfetti.tscn`, `Assets/Images/Particles/particle_confetti.png`, or `Scripts/SchoolSimulation/RewardParticles.gd`.
- Colors, exactly: red `#E5484D`, yellow `#FFC93C`, blue `#3B82F6`, constant interpolation, offsets `[0.0, 0.3333, 0.6667]`.
- `damping_max` must stay below `gravity.y` on both cannons (damping ≥ gravity parks pieces mid-air).
- No runtime visual construction (`GPUParticles2D.new()`, `ShaderMaterial.new()`, …) — everything is authored in the `.tscn` (`tests/test_viewport_editability.gd`).
- Test suites are `@tool`, extend `McpTestSuiteCompat`, and contain **no** `await`.
- **Editor hazards (CLAUDE.md "Working efficiently here" §4/4b/5):** never hand-edit a `.tscn` that is open in the editor; do scene work before script work; after any `scene_save` run `git diff HEAD -- '*.gd'` and revert any `.gd` you did not mean to change; after writing a file from outside the editor, run `filesystem_manage(op="scan")` before `test_run`.
- The working tree carries someone else's uncommitted TesNotice work (`CLAUDE.md`, `Scenes/EndGame/TesNotice.tscn`, `tests/test_tes_notice.gd`, `Assets/Images/EndGame/ujian_nasional.png*`). Never stage those — always `git add` explicit paths.
- Commits: Conventional Commits with a scope, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File map

| File | Status | Responsibility |
|---|---|---|
| `Scripts/Shaders/paper_flutter.gdshader` | create | Per-particle flip squash + back-face shade |
| `Scenes/SchoolSimulation/PaperConfetti.tscn` | create | The two authored cannons, materials, ramp |
| `tests/test_paper_confetti.gd` | create | Structure/value contract for the above |
| `Scenes/SchoolSimulation/ResultCheckup.tscn` | modify (via editor) | `Celebration` marker → `PaperConfetti` instance |
| `Scripts/SchoolSimulation/ResultCheckup.gd:70` | modify | `_CELEBRATION_SCENE` path |
| `tests/test_result_checkup.gd` | modify | Assert the checkup uses the paper burst |
| `docs/superpowers/CHANGELOG.md` | modify | Completed-pass entry |

---

### Task 1: The PaperConfetti scene and flutter shader

**Files:**
- Create: `tests/test_paper_confetti.gd`
- Create: `Scripts/Shaders/paper_flutter.gdshader`
- Create: `Scenes/SchoolSimulation/PaperConfetti.tscn`

**Interfaces:**
- Consumes: `RewardParticles` (`Scripts/SchoolSimulation/RewardParticles.gd`, `class_name RewardParticles extends GPUParticles2D`, `fire(delay: float = 0.0)` restarts the root and every `GPUParticles2D` child, frees the root after `lifetime * (2 - explosiveness) + 0.5` s).
- Produces: `res://Scenes/SchoolSimulation/PaperConfetti.tscn`, root node `PaperConfetti` (a `RewardParticles`), child `RightCannon` (`GPUParticles2D`) at local `(1160, 0)`. Placed so the root sits at the bottom-left corner; Task 2 relies on that.

- [ ] **Step 1: Write the failing test suite**

Create `tests/test_paper_confetti.gd`:

```gdscript
@tool
extends McpTestSuiteCompat

## PaperConfetti -- the week-end checkup's two-cannon paper burst
## (docs/superpowers/specs/2026-09-12-paper-confetti-design.md). This suite
## pins the authored structure and emitter values; the motion itself is
## judged live, because a GPU particle system cannot be stepped in a test.
##
## Suite constraints: @tool, or the runner reports the class abstract; and
## no coroutines -- the runner does suite.call(name) without awaiting.

const _SCENE := "res://Scenes/SchoolSimulation/PaperConfetti.tscn"
const _SHADER := "res://Scripts/Shaders/paper_flutter.gdshader"
## The three paper colors in ramp order: red, yellow, blue.
const _COLORS := [Color("E5484D"), Color("FFC93C"), Color("3B82F6")]


func suite_name() -> String:
	return "paper_confetti"


## Instance the scene; the caller frees it. Null, with a failed assertion,
## if the scene is missing.
func _instance() -> GPUParticles2D:
	assert_true(ResourceLoader.exists(_SCENE), "scene must exist: " + _SCENE)
	if not ResourceLoader.exists(_SCENE):
		return null
	return (load(_SCENE) as PackedScene).instantiate() as GPUParticles2D


## Both emitters, left then right. Shorter than two if the scene is malformed.
func _cannons(root: GPUParticles2D) -> Array[GPUParticles2D]:
	var out: Array[GPUParticles2D] = []
	if root == null:
		return out
	out.append(root)
	var right := root.get_node_or_null("RightCannon") as GPUParticles2D
	if right != null:
		out.append(right)
	return out


## The root rides the existing fire-and-forget script, so ResultCheckup's
## `as RewardParticles` cast and self-freeing keep working unchanged.
func test_root_is_a_one_shot_idle_reward_burst() -> void:
	var root := _instance()
	if root == null:
		return
	assert_true(root is RewardParticles, "the root must carry RewardParticles")
	assert_true(root.one_shot, "the left cannon must be one_shot")
	assert_true(not root.emitting, "the left cannon must start idle")
	root.free()


## Exactly one extra emitter, and it can never outlive the root that frees
## it: RewardParticles times its cleanup off the ROOT's lifetime.
func test_right_cannon_is_a_one_shot_idle_emitter() -> void:
	var root := _instance()
	if root == null:
		return
	assert_eq(root.get_child_count(), 1, "the root must hold exactly one child")
	var cannons := _cannons(root)
	assert_eq(cannons.size(), 2, "RightCannon must be a GPUParticles2D child")
	if cannons.size() == 2:
		var right := cannons[1]
		assert_true(right.one_shot, "the right cannon must be one_shot")
		assert_true(not right.emitting, "the right cannon must start idle")
		assert_true(right.lifetime <= root.lifetime,
			"the right cannon must not outlive the root that frees it")
		assert_true(right.explosiveness >= root.explosiveness,
			"the right cannon must not emit later than the root's cleanup assumes")
	root.free()


## Bottom corners, both firing up and inward.
func test_cannons_sit_at_opposite_edges_and_aim_inward() -> void:
	var root := _instance()
	var cannons := _cannons(root)
	if cannons.size() != 2:
		if root != null:
			root.free()
		assert_true(false, "needs both cannons")
		return
	assert_gt(cannons[1].position.x, 1000.0,
		"RightCannon must sit a screen-width to the right of the root")
	var left_mat := cannons[0].process_material as ParticleProcessMaterial
	var right_mat := cannons[1].process_material as ParticleProcessMaterial
	assert_true(left_mat != null and right_mat != null,
		"each cannon must carry its own ParticleProcessMaterial")
	if left_mat != null and right_mat != null:
		assert_true(left_mat != right_mat,
			"the cannons must not share one process material (they aim opposite ways)")
		assert_gt(left_mat.direction.x, 0.0, "the left cannon must aim right")
		assert_true(right_mat.direction.x < 0.0, "the right cannon must aim left")
		assert_true(left_mat.direction.y < 0.0 and right_mat.direction.y < 0.0,
			"both cannons must fire upward")
	root.free()


## Paper, not stones: drag slows the fall, but must stay under gravity or
## the pieces stop dead mid-air.
func test_paper_falls_rather_than_parking() -> void:
	var root := _instance()
	for c in _cannons(root):
		var mat := c.process_material as ParticleProcessMaterial
		assert_true(mat != null, "%s needs a process material" % c.name)
		if mat == null:
			continue
		assert_gt(mat.damping_min, 0.0, "%s must have air drag" % c.name)
		assert_true(mat.damping_max < mat.gravity.y,
			"%s damping must stay below gravity" % c.name)
	if root != null:
		root.free()


## One ShaderMaterial, shared, running the flutter shader.
func test_both_cannons_share_the_flutter_shader() -> void:
	var root := _instance()
	var cannons := _cannons(root)
	if cannons.size() != 2:
		if root != null:
			root.free()
		assert_true(false, "needs both cannons")
		return
	var sm := cannons[0].material as ShaderMaterial
	assert_true(sm != null, "the root must carry a ShaderMaterial")
	if sm != null:
		assert_true(sm.shader != null and sm.shader.resource_path == _SHADER,
			"the material must run " + _SHADER)
	assert_true(cannons[1].material == cannons[0].material,
		"RightCannon must share the root's ShaderMaterial")
	root.free()


## Every piece lands on exactly one of red, yellow, blue -- never a blend.
func test_ramp_draws_exactly_red_yellow_blue() -> void:
	var root := _instance()
	for c in _cannons(root):
		var mat := c.process_material as ParticleProcessMaterial
		if mat == null:
			assert_true(false, "%s needs a process material" % c.name)
			continue
		var tex := mat.color_initial_ramp as GradientTexture1D
		assert_true(tex != null and tex.gradient != null,
			"%s needs a GradientTexture1D color_initial_ramp" % c.name)
		if tex == null or tex.gradient == null:
			continue
		var g := tex.gradient
		assert_eq(g.interpolation_mode, Gradient.GRADIENT_INTERPOLATE_CONSTANT,
			"%s ramp must not blend between colors" % c.name)
		assert_eq(g.get_point_count(), 3, "%s ramp must hold three colors" % c.name)
		var samples := [0.1, 0.5, 0.9]
		for i in 3:
			assert_true(g.sample(samples[i]).is_equal_approx(_COLORS[i]),
				"%s ramp third %d must be %s" % [c.name, i, _COLORS[i].to_html(false)])
	if root != null:
		root.free()


## The default 200x200 visibility rect sits half off-screen at a corner and
## would cull the whole burst.
func test_visibility_rect_covers_the_flight() -> void:
	var root := _instance()
	for c in _cannons(root):
		assert_gt(c.visibility_rect.size.x, 1000.0, "%s rect too narrow" % c.name)
		assert_gt(c.visibility_rect.size.y, 1500.0, "%s rect too short" % c.name)
	if root != null:
		root.free()


func test_every_cannon_carries_a_sprite() -> void:
	var root := _instance()
	for c in _cannons(root):
		assert_true(c.texture != null, "%s must carry a sprite" % c.name)
	if root != null:
		root.free()


## Source scan: the knobs stay Inspector-tunable and the per-piece phase
## comes from the instance, not a shared clock.
func test_shader_exposes_its_tuning_knobs() -> void:
	var f := FileAccess.open(_SHADER, FileAccess.READ)
	assert_true(f != null, "shader must exist: " + _SHADER)
	if f == null:
		return
	var src := f.get_as_text()
	assert_true(src.contains("shader_type canvas_item"), "must be a canvas_item shader")
	for knob in ["flip_speed", "flip_speed_jitter", "back_shade"]:
		assert_true(src.contains("uniform float " + knob), "missing uniform " + knob)
	assert_true(src.contains("INSTANCE_ID"), "phase must be hashed per particle")
```

- [ ] **Step 2: Register and run it to verify it fails**

Run `filesystem_manage(op="scan")`, then `test_run(suite="paper_confetti")`.
Expected: FAIL — `scene must exist: res://Scenes/SchoolSimulation/PaperConfetti.tscn` and `shader must exist: …`.

- [ ] **Step 3: Write the shader**

Create `Scripts/Shaders/paper_flutter.gdshader`:

```glsl
// Paper flutter for confetti particles. Squashes each piece's quad along its
// own x axis by cos(time), so a flat sheet reads as tumbling in 3D, and
// darkens the back face so the flip is legible. Phase and speed are hashed
// per particle from INSTANCE_ID. In a 2D canvas shader the particle's
// instance transform is folded into MODEL_MATRIX, so VERTEX here is still
// the quad's local space and the squash follows each piece's own rotation.
// Used by Scenes/SchoolSimulation/PaperConfetti.tscn.
shader_type canvas_item;

// Base flip rate, radians per second.
uniform float flip_speed : hint_range(0.0, 30.0) = 7.0;
// Per-piece speed spread, as a +/- fraction of flip_speed.
uniform float flip_speed_jitter : hint_range(0.0, 1.0) = 0.5;
// How much darker the back face is (0 = same as the front, 1 = black).
uniform float back_shade : hint_range(0.0, 1.0) = 0.35;

varying float shade;

// Integer hash to [0, 1).
float hash01(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 2147483647u) / 2147483648.0;
}

void vertex() {
	uint id = uint(INSTANCE_ID);
	float speed = flip_speed * (1.0 + flip_speed_jitter * (2.0 * hash01(id) - 1.0));
	float c = cos(TIME * speed + hash01(id + 7919u) * TAU);
	VERTEX.x *= c;
	shade = mix(1.0, 1.0 - back_shade, step(c, 0.0));
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.rgb *= shade;
}
```

- [ ] **Step 4: Write the scene**

`PaperConfetti.tscn` is a new file the editor has never opened, so authoring it as text is safe. Create `Scenes/SchoolSimulation/PaperConfetti.tscn`:

```
[gd_scene format=3]

[ext_resource type="Texture2D" uid="uid://skr3tjxap0qw" path="res://Assets/Images/Particles/particle_confetti.png" id="1_paper"]
[ext_resource type="Script" uid="uid://dirvyxt44yitc" path="res://Scripts/SchoolSimulation/RewardParticles.gd" id="2_paper"]
[ext_resource type="Shader" path="res://Scripts/Shaders/paper_flutter.gdshader" id="3_paper"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_flutter"]
shader = ExtResource("3_paper")
shader_parameter/flip_speed = 7.0
shader_parameter/flip_speed_jitter = 0.5
shader_parameter/back_shade = 0.35

[sub_resource type="Gradient" id="Gradient_rgb"]
interpolation_mode = 1
offsets = PackedFloat32Array(0, 0.3333, 0.6667)
colors = PackedColorArray(0.8980392, 0.28235295, 0.3019608, 1, 1, 0.7882353, 0.23529412, 1, 0.23137255, 0.50980395, 0.9647059, 1)

[sub_resource type="GradientTexture1D" id="GradientTexture1D_rgb"]
gradient = SubResource("Gradient_rgb")

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_left"]
emission_shape = 1
emission_sphere_radius = 20.0
angle_max = 360.0
direction = Vector3(0.45, -1, 0)
spread = 14.0
initial_velocity_min = 1800.0
initial_velocity_max = 2400.0
angular_velocity_min = -180.0
angular_velocity_max = 180.0
gravity = Vector3(0, 900, 0)
damping_min = 560.0
damping_max = 640.0
scale_min = 0.25
scale_max = 0.4
color_initial_ramp = SubResource("GradientTexture1D_rgb")
turbulence_enabled = true
turbulence_noise_strength = 1.5
turbulence_influence_min = 0.08
turbulence_influence_max = 0.16

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_right"]
emission_shape = 1
emission_sphere_radius = 20.0
angle_max = 360.0
direction = Vector3(-0.45, -1, 0)
spread = 14.0
initial_velocity_min = 1800.0
initial_velocity_max = 2400.0
angular_velocity_min = -180.0
angular_velocity_max = 180.0
gravity = Vector3(0, 900, 0)
damping_min = 560.0
damping_max = 640.0
scale_min = 0.25
scale_max = 0.4
color_initial_ramp = SubResource("GradientTexture1D_rgb")
turbulence_enabled = true
turbulence_noise_strength = 1.5
turbulence_influence_min = 0.08
turbulence_influence_max = 0.16

[node name="PaperConfetti" type="GPUParticles2D"]
material = SubResource("ShaderMaterial_flutter")
emitting = false
amount = 60
texture = ExtResource("1_paper")
lifetime = 3.2
one_shot = true
explosiveness = 0.9
visibility_rect = Rect2(-100, -1900, 1300, 2100)
process_material = SubResource("ParticleProcessMaterial_left")
script = ExtResource("2_paper")

[node name="RightCannon" type="GPUParticles2D" parent="."]
material = SubResource("ShaderMaterial_flutter")
position = Vector2(1160, 0)
emitting = false
amount = 60
texture = ExtResource("1_paper")
lifetime = 3.2
one_shot = true
explosiveness = 0.9
visibility_rect = Rect2(-1200, -1900, 1300, 2100)
process_material = SubResource("ParticleProcessMaterial_right")
```

- [ ] **Step 5: Scan, check for load errors, run the suite**

1. `filesystem_manage(op="scan")`.
2. `logs_read(source="editor", count=30)` — expected: no shader compile error naming `paper_flutter.gdshader` and no load error for `PaperConfetti.tscn`. A shader error here (e.g. an unsupported literal) must be fixed before going on.
3. `test_run(suite="paper_confetti")` — expected: PASS, 9 tests, 0 failed.
4. `test_run(suite="day_summary")` and `test_run(suite="apply_item_screen")` — expected: PASS (they pin the untouched `CelebrationConfetti.tscn`).

- [ ] **Step 6: Let the editor stamp a uid, then commit**

`filesystem_manage(op="scan")` usually writes `Scripts/Shaders/paper_flutter.gdshader.uid`. Check with `git status --short`. Stage only these paths (plus the `.uid` sidecar if it exists):

```bash
git add tests/test_paper_confetti.gd Scripts/Shaders/paper_flutter.gdshader Scenes/SchoolSimulation/PaperConfetti.tscn
git add Scripts/Shaders/paper_flutter.gdshader.uid tests/test_paper_confetti.gd.uid
git commit -m "feat(checkup): add two-cannon paper confetti scene and flutter shader" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

(If either `.uid` file does not exist, drop it from the second `git add`.)

---

### Task 2: Wire the paper burst into ResultCheckup

**Files:**
- Modify: `tests/test_result_checkup.gd` (append one test after `test_checkup_scene_carries_an_idle_confetti_node`, ~line 541)
- Modify (via editor only): `Scenes/SchoolSimulation/ResultCheckup.tscn` — node `Celebration` (currently the last root child, lines 144-146)
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd:70`

**Interfaces:**
- Consumes: `res://Scenes/SchoolSimulation/PaperConfetti.tscn` from Task 1 (root is a `RewardParticles`; root = bottom-left corner).
- Produces: `ResultCheckup` stage 5 fires `PaperConfetti` at the `Celebration` marker's position. The stage-5 code (`ResultCheckup.gd:364-370`) is unchanged: it instantiates `_CELEBRATION_SCENE`, casts `as RewardParticles`, copies `get_node("Celebration").position`, and calls `fire(float(cards.size()) * t.stagger_step)`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`, directly after `test_checkup_scene_carries_an_idle_confetti_node()`:

```gdscript


## The weekly celebration is the two-cannon paper burst, not the shared
## top-down CelebrationConfetti (2026-09-12 paper confetti spec). The
## ApplyItemScreen keeps CelebrationConfetti; only the checkup moved.
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
```

- [ ] **Step 2: Run it to verify it fails**

The test file was written from outside the editor: run `filesystem_manage(op="scan")`, then `test_run(suite="result_checkup", test_name="paper_confetti")`.
Expected: FAIL — `the checkup must fire PaperConfetti.tscn`.

- [ ] **Step 3: Swap the scene marker, through the editor (scene work first)**

`ResultCheckup.tscn` must not be text-edited. In order:

1. `scene_open(path="res://Scenes/SchoolSimulation/ResultCheckup.tscn")`.
2. `scene_get_hierarchy` (depth 1) to confirm the node path of `Celebration`, and that it is the last child of the root.
3. `node_manage(op="delete", params={"path": "<Celebration path from step 2>", "scene_file": "res://Scenes/SchoolSimulation/ResultCheckup.tscn"})`.
4. `node_create(name="Celebration", scene_path="res://Scenes/SchoolSimulation/PaperConfetti.tscn", parent_path="", scene_file="res://Scenes/SchoolSimulation/ResultCheckup.tscn")` — it appends last, which is where the old node was, so no `move` is needed.
5. `node_set_property` on the new `Celebration`: `position` = `Vector2(-40, 1780)`, `z_index` = `100`.
6. `scene_save`.
7. Verify on disk:
   - `git diff -- Scenes/SchoolSimulation/ResultCheckup.tscn` shows the `CelebrationConfetti.tscn` ext_resource replaced by `PaperConfetti.tscn`, and the `Celebration` node with `z_index = 100` and `position = Vector2(-40, 1780)`. Nothing else in the file should change except a possible `unique_id`.
   - `git diff HEAD --stat -- '*.gd'` — expected: empty (only the test file from Step 1, which is uncommitted and yours). If any other `.gd` shows up, `git checkout -- <that file>`.

- [ ] **Step 4: Point the script at the new scene (script work second)**

`script_patch`:
- path: `res://Scripts/SchoolSimulation/ResultCheckup.gd`
- old_text: `const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/CelebrationConfetti.tscn"`
- new_text: `const _CELEBRATION_SCENE := "res://Scenes/SchoolSimulation/PaperConfetti.tscn"`

If the preceding line holds a `##` doc comment that says "confetti from the top" or similar, update it to describe the two-cannon paper burst. (Read lines 66-70 first.)

**Do not call `scene_save` again in this session after this patch** (CLAUDE.md §4b). If a later step needs a scene save, restart the editor first.

- [ ] **Step 5: Run the affected suites**

`test_run` each, expecting PASS with 0 failures:
- `suite="result_checkup"` — including the new test and the old `test_checkup_scene_carries_an_idle_confetti_node` (the new marker is still a one-shot, idle `GPUParticles2D`).
- `suite="paper_confetti"`
- `suite="viewport_editability"`
- `suite="script_documentation"`

If `result_checkup` returns a `scene_warning`, `scene_open` `res://Scenes/MainMenu/main_menu.tscn` and re-run before trusting a failure.

- [ ] **Step 6: Commit**

```bash
git add tests/test_result_checkup.gd Scenes/SchoolSimulation/ResultCheckup.tscn Scripts/SchoolSimulation/ResultCheckup.gd
git commit -m "feat(checkup): fire the paper confetti from both bottom corners" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Judge it live, tune, and log it

**Files:**
- Possibly modify: `Scenes/SchoolSimulation/PaperConfetti.tscn` (tuning values only). Text edits are safe because the editor never opens this scene as its edited scene — do not `scene_open` it.
- Modify: `docs/superpowers/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1's scene, Task 2's wiring.
- Produces: tuned values, and evidence (a screenshot plus numbers) that the burst looks right.

- [ ] **Step 1: Fire the burst in the running game and freeze it mid-flight**

1. `project_run(mode="main")`, then poll `editor_state` until `game_capture_ready` is true.
2. One `editor_manage(op="game_eval")` call does the rest in-game, so no tool-call gap can outlast the animation (memory: *freeze-game-time-for-screenshots*):

```gdscript
var tree := Engine.get_main_loop() as SceneTree
var fx: RewardParticles = load("res://Scenes/SchoolSimulation/PaperConfetti.tscn").instantiate()
fx.position = Vector2(-40, 1780)
fx.z_index = 100
tree.current_scene.add_child(fx)
fx.fire()
var start := Time.get_ticks_msec()
while Time.get_ticks_msec() - start < 1200:
	await tree.process_frame
Engine.time_scale = 0.0
return {"right_x": fx.get_node("RightCannon").global_position.x, "root": fx.global_position}
```

3. `editor_screenshot(source="game", max_resolution=0)` — judge it at full size.

- [ ] **Step 2: Judge against the spec**

All must hold. If one fails, tune `PaperConfetti.tscn` and repeat Step 1 (stop the game first, `filesystem_manage(op="scan")`, relaunch):

| Check | If it fails, tune |
|---|---|
| Pieces come from **both** bottom corners and cross toward the centre | `direction.x` (±0.45) |
| The arc peaks in the upper third of the screen (y < ~700) at 1.2 s | `initial_velocity_min/max` up, or `damping` down |
| Three distinct colors: red, yellow and blue, and no white pieces | the ramp colors; the shader's `COLOR` multiply |
| Pieces at visibly varied widths, some near edge-on, some darker (back face) | `flip_speed`, `back_shade` |
| Pieces fall slowly and drift rather than drop | `damping` toward `gravity.y` (must stay below it), `turbulence_influence` |

Then set `Engine.time_scale = 1.0` in a second `game_eval` and take one more screenshot about 2.5 s later, to confirm the fall is still fluttering and on screen. Stop the game with `project_manage(op="stop")`.

If any value changed, re-run `test_run(suite="paper_confetti")` (it must still pass; damping stays below gravity), then:

```bash
git add Scenes/SchoolSimulation/PaperConfetti.tscn
git commit -m "tune(checkup): paper confetti arc and flutter from live check" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 3: Changelog entry**

Insert directly above `## 2026-09-11 — Koperasi rework, Part 2` in `docs/superpowers/CHANGELOG.md`, with the real commit count and test numbers filled in from this run:

```markdown
## 2026-09-12 — Paper confetti on the week-end checkup

Plan `docs/superpowers/plans/2026-09-12-paper-confetti.md`. ResultCheckup's
celebration is now `PaperConfetti.tscn`: two cannons at the bottom corners
fire red, yellow and blue sheets up and inward, and they flutter down.
`Scripts/Shaders/paper_flutter.gdshader` fakes the 3D flip by squashing each
quad on its own x axis by a per-particle cosine, and shades the back face.
Air drag set below gravity makes the pieces hang instead of dropping. The
week-gained gate and its timing are unchanged. `CelebrationConfetti.tscn` is
untouched and still serves ApplyItemScreen. On screens wider than 9:16 the
right cannon lands short of the edge. That was accepted, not fixed.
```

```bash
git add docs/superpowers/CHANGELOG.md
git commit -m "docs(changelog): paper confetti on the week-end checkup" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Ship**

Finish the branch with the `ship-pr` skill (`.claude/skills/ship-pr/SKILL.md`). It runs the full suite, which may drop the bridge (budget one editor restart). It also runs a local review, opens the PR into `Textures`, and stamps the tested commit. After the full run, check `git status` and `git checkout --` any of `Assets/Theme/kejartes_theme.tres` or `Assets/Audio/default_bus_layout.tres` that it rewrote without meaning to.
