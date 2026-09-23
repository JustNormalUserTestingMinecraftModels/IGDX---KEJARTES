# Illustration AO, Rim Light and Lobby Shafts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the game's 21 painted cutout plates read as solid objects — inner ambient occlusion and a rim light in the shared grade shader, outer AO under seven of them, and light shafts in the Lobby — without darkening any scene overall.

**Architecture:** One shader (`illustration_grade.gdshader`) gains an AO + rim stage gated by per-material strength uniforms. Two materials point at it: the existing one with both strengths at zero (worn by the 9 full-bleed backdrops) and a new `illustration_grade_cutout.tres` with them on (worn by the 21 cutouts). Outer AO is not shader work — a node can only draw inside its own rect — so it is retuned instances of the existing `PaperShadow.tscn`. The Lobby's shafts are one `ColorRect` with a shader extracted from `achievement_glow.gdshader`.

**Tech Stack:** Godot 4.6.2, `mobile` renderer, GDScript, `canvas_item` shaders. Tests are `@tool` suites under `tests/` run **inside the editor** through the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-23-illustration-ao-rim-design.md`

## Global Constraints

Every task's requirements implicitly include all of these.

- **Branch is `Textures`.** Check `git branch --show-current` before every commit — another session shares this checkout and has switched the branch mid-task before.
- **Tests run in the editor, never headless.** `test_run(suite="illustration_ao")` via MCP. `--script` registers no autoloads; running a scene makes `Engine.is_editor_hint()` false and every `@tool` guard fires for real.
- **Every suite is `@tool`** or the runner reports it abstract. **No test may be a coroutine** — the runner does `suite.call(name)` without awaiting, so an `await` silently aborts the test and it reports "0 assertions".
- **Never add a `theme_override_*`.** Layout-only constant overrides (`separation`, `margin_*`) are the sole exception. The debug overlay (Task 7) is explicitly out of scope for the design system and styles itself directly — follow the file's own local pattern there.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`. The shafts node is authored in `loby.tscn`, never `ColorRect.new()` in a script, or `tests/test_viewport_editability.gd` goes red.
- **Every script needs documentation:** a `##` file header and a `##` line on every `@export`. Enforced by `tests/test_script_documentation.gd`.
- **`Balance.gd` is owned by a collaborator.** This plan does not touch it.
- **Indonesian for game-facing text and UI copy**, English for systems code. The debug overlay is developer-facing; match the surrounding file, which is Indonesian.
- **After a full `test_run`, check `git status`.** The run rewrites `Assets/Theme/kejartes_theme.tres` (the `theme_rebake` suite saves in-process) and `Assets/Audio/default_bus_layout.tres` (AudioDirector on boot). `git checkout --` whichever you did not intend.
- **A full `test_run` drops the MCP bridge.** Budget one editor restart per full run. Prefer targeted `test_run(suite=...)` between tasks.

## Editor hazards this plan is built around

Read this before Task 4. It is the difference between a 25-line diff and a corrupted scene.

**`scene_save` bakes `@tool` state into the file.** Proven twice in this project. An editor save of `DancerRig.tscn` writes `Head`'s offsets from `DancerRig.gd`'s layout pass; an editor save of `Kalkulator.tscn` writes a `theme_override_colors/font_color` onto `Layar` from `Kalkulator.gd`'s `add_theme_color_override` — a *banned* override, arriving by itself. `StickyNote` does the same to `RosterCard.tscn`.

**So for a one-property change across many scenes, do not use the editor.** Use this sequence instead, which produced an exactly-25-line diff on 2026-09-23:

1. Close Godot (`Stop-Process` on `Godot_v*`, never `godot-ai.exe`). Check `MainWindowTitle` for `(*)` first — that means unsaved work, so stop and ask.
2. Edit the `.tscn` as text.
3. Relaunch the editor detached:
   `Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`" --path `"<project>`" -e"; CurrentDirectory = "<project>" }`
   (the outer `.exe` is a **directory**; `Start-Process -PassThru` errors on this machine.)
4. `git diff --stat` and confirm only the lines you wrote changed.

**Use the editor** (`scene_open` → `node_create` → `scene_save`) for Task 6, where a new node with several properties is being created — then diff, and revert any stray hunk.

---

### Task 1: Prove `fwidth` works in a canvas shader on this renderer

The whole radius design leans on `fwidth(UV)` giving UV-per-screen-pixel so a 0.34-scale racket and a 1.0-scale desk get the same visual band width. Canvas-shader derivatives are supported on Vulkan, but this is checked on a real frame before anything is built on it. **No production code is committed by this task.**

**Files:**
- Create (temporary, deleted in Step 5): `Scripts/Shaders/_fwidth_probe.gdshader`
- Create (temporary, deleted in Step 5): `Scenes/_FwidthProbe.tscn`

- [ ] **Step 1: Write the probe shader**

Create `Scripts/Shaders/_fwidth_probe.gdshader`:

```glsl
// TEMPORARY probe. Deleted at the end of Task 1. Encodes fwidth(UV).x into red
// so a screenshot can be read back numerically: a plate drawn at half scale
// must report twice the UV-per-screen-pixel of one drawn at full scale.
shader_type canvas_item;

uniform float gain = 1000.0;

void fragment() {
	float upp = fwidth(UV).x;          // UV per screen pixel
	COLOR = vec4(clamp(upp * gain, 0.0, 1.0), 0.0, 0.0, 1.0);
}
```

- [ ] **Step 2: Build the probe scene**

Through the editor, via MCP:

```
scene_manage(op="create", params={"path": "res://Scenes/_FwidthProbe.tscn", "root_type": "Control", "root_name": "FwidthProbe"})
```

Add two `ColorRect` children of the root, both carrying a `ShaderMaterial` on `_fwidth_probe.gdshader`:
- `Full` — `offset_left=0, offset_top=0, offset_right=400, offset_bottom=400`, `scale = Vector2(1, 1)`
- `Half` — `offset_left=500, offset_top=0, offset_right=900, offset_bottom=400`, `scale = Vector2(0.5, 0.5)`

Set `layout_mode = 1` on each **before** setting anchors — a `Control` created under a plain `Control` starts in position mode, where anchors are not saved.

- [ ] **Step 3: Run it and read the pixels back**

```
project_run(mode="scene", scene="res://Scenes/_FwidthProbe.tscn")
```

Then, in **one** `game_eval` call (call latency outlasts any animation, so freeze and sample together):

```gdscript
Engine.time_scale = 0.02
var img: Image = get_viewport().get_texture().get_image()
var full := img.get_pixel(200, 200).r
var half := img.get_pixel(int(500 * 0.5) + 100, 100).r
return "full=%f half=%f ratio=%f" % [full, half, half / maxf(full, 0.0001)]
```

- [ ] **Step 4: Judge the result**

Expected: `ratio ≈ 2.0` (the half-scale rect covers half as many screen pixels per UV, so `fwidth` is twice as large). `ratio ≈ 1.0` or `full == 0.0` means derivatives are not working and **the fallback in spec §1.4 applies** — radius in texels plus a second cutout material for small-scale plates.

Record the three numbers. They go in Task 2's commit message.

- [ ] **Step 5: Delete the probe and confirm the tree is clean**

```bash
rm "Scripts/Shaders/_fwidth_probe.gdshader" "Scripts/Shaders/_fwidth_probe.gdshader.uid" "Scenes/_FwidthProbe.tscn"
git status --porcelain
```

Expected: no `_FwidthProbe` or `_fwidth_probe` entries remain. Nothing is committed in this task.

---

### Task 2: The shader stage and the two materials

**Files:**
- Modify: `Scripts/Shaders/illustration_grade.gdshader`
- Create: `Scripts/Shaders/illustration_grade_cutout.tres`
- Modify: `Scripts/Shaders/illustration_grade_material.tres`
- Create: `tests/test_illustration_ao.gd`

**Interfaces:**
- Produces: seven new uniforms on `illustration_grade.gdshader` — `ao_strength: float`, `ao_radius_px: float`, `ao_color: vec4`, `rim_strength: float`, `rim_radius_px: float`, `rim_color: vec4`, `light_dir: vec2`. Task 4 assigns the material that turns them on; Task 7 drives them live by name.
- Produces: `res://Scripts/Shaders/illustration_grade_cutout.tres`, consumed by Tasks 4 and 7.

- [ ] **Step 1: Write the failing test**

Create `tests/test_illustration_ao.gd`:

```gdscript
@tool
extends McpTestSuite

## Inner AO and the rim light (2026-09-23).
##
## One shader, two materials. The backdrops keep the material they always wore,
## with both strengths at zero; the cutouts wear a second material with them on.
## The split is not a preference -- a full-bleed backdrop has no alpha edge to
## find, so it would pay the extra taps and get nothing back, and this game is
## mostly full-screen backdrops.
##
## Design: docs/superpowers/specs/2026-09-23-illustration-ao-rim-design.md
##
## Must be @tool, and no test here may be a coroutine.

const SHADER := "res://Scripts/Shaders/illustration_grade.gdshader"
const PLAIN := "res://Scripts/Shaders/illustration_grade_material.tres"
const CUTOUT := "res://Scripts/Shaders/illustration_grade_cutout.tres"


func suite_name() -> String:
	return "illustration_ao"


## Two materials, one shader. If these ever diverge, a change to the grade
## silently stops reaching half the game.
func test_both_materials_share_the_one_shader() -> void:
	var shader: Shader = load(SHADER)
	assert_true(shader != null, "the grade shader must exist")
	for path in [PLAIN, CUTOUT]:
		var mat: ShaderMaterial = load(path)
		assert_true(mat != null, "%s must exist" % path)
		if mat == null:
			continue
		assert_eq(mat.shader, shader, "%s must point at the one grade shader" % path)


## The backdrops pay nothing. This is the entire reason there are two materials.
func test_the_plain_material_has_both_effects_off() -> void:
	var mat: ShaderMaterial = load(PLAIN)
	assert_true(mat != null, "the plain material must exist")
	if mat == null:
		return
	assert_true(is_zero_approx(mat.get_shader_parameter("ao_strength")),
		"backdrops must not pay for AO they cannot show")
	assert_true(is_zero_approx(mat.get_shader_parameter("rim_strength")),
		"backdrops must not pay for a rim they cannot show")


## The cutout material actually does something, or the pass is a no-op.
func test_the_cutout_material_has_both_effects_on() -> void:
	var mat: ShaderMaterial = load(CUTOUT)
	assert_true(mat != null, "the cutout material must exist")
	if mat == null:
		return
	assert_true(mat.get_shader_parameter("ao_strength") > 0.0, "AO must be on for cutouts")
	assert_true(mat.get_shader_parameter("rim_strength") > 0.0, "rim must be on for cutouts")


## The radius is in SCREEN pixels, via fwidth. A radius in source texels would
## give a 0.34-scale racket and a 1.0-scale desk different-looking bands, and
## the game would stop looking like one thing. Verified on a real frame in
## Task 1 before this was built.
func test_the_radius_is_in_screen_pixels() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_true(src.contains("fwidth(UV)"),
		"the offsets must be scaled by fwidth(UV), not by TEXTURE_PIXEL_SIZE alone")


## AO is ambient: uniform around the silhouette, no direction. Rim is the only
## directional term. If AO ever starts reading light_dir it has become a cast
## shadow, which is a different effect with a different job.
func test_the_rim_is_directional_and_the_ao_is_not() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	var ao_block := src.substr(src.find("// -- inner AO"), src.find("// -- rim") - src.find("// -- inner AO"))
	assert_true(ao_block.length() > 0, "the shader must mark its AO block with '// -- inner AO'")
	assert_false(ao_block.contains("light_dir"), "AO is ambient; it must not read light_dir")
	assert_true(src.contains("light_dir"), "the rim must read light_dir")


## Light comes from the upper-left. Three independent things in the shipped game
## agree: the Lobby's WindowLight pool centres up and left, the sun streaks in
## loby_no_tables.png run down-right, and all three contact shadows were authored
## offset down-right -- Herman (12,10), BGHari (8,12), Splash (14,10). A rim that
## disagrees with the art is worse than no rim.
func test_the_light_comes_from_the_upper_left() -> void:
	var mat: ShaderMaterial = load(CUTOUT)
	assert_true(mat != null, "the cutout material must exist")
	if mat == null:
		return
	var dir: Vector2 = mat.get_shader_parameter("light_dir")
	assert_true(dir.x < 0.0, "light_dir.x must point left, matching the window")
	assert_true(dir.y < 0.0, "light_dir.y must point up, matching the painted streaks")


## The ceilings. AO darkens, and this grade has already been halved twice for
## reading dark -- see the two 2026-09-22/23 cuts in illustration_grade.gdshader.
## These hold the line. Raise them only after re-running the sweep in the spec's
## section 4 and recording the numbers in the commit.
const AO_STRENGTH_CEILING := 0.45
const RIM_STRENGTH_CEILING := 0.30


func test_the_effects_stay_subtle() -> void:
	var mat: ShaderMaterial = load(CUTOUT)
	assert_true(mat != null, "the cutout material must exist")
	if mat == null:
		return
	var ao: float = mat.get_shader_parameter("ao_strength")
	var rim: float = mat.get_shader_parameter("rim_strength")
	assert_true(ao <= AO_STRENGTH_CEILING,
		"ao_strength %s is past the agreed ceiling %s" % [ao, AO_STRENGTH_CEILING])
	assert_true(rim <= RIM_STRENGTH_CEILING,
		"rim_strength %s is past the agreed ceiling %s" % [rim, RIM_STRENGTH_CEILING])


## Every plate this lands on is a cutout, and a grade that multiplied alpha
## would eat the soft edges the art is drawn with. The AO stage must darken
## colour only.
func test_neither_effect_touches_alpha() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_true(src.contains("src.a"), "the shader must pass the source alpha straight through")
	assert_false(src.contains("COLOR.a *"), "nothing may scale alpha, or cutout edges get eaten")
```

- [ ] **Step 2: Run it to make sure it fails**

```
test_run(suite="illustration_ao")
```

Expected: FAIL. `illustration_grade_cutout.tres` does not exist, so `test_both_materials_share_the_one_shader`, `test_the_cutout_material_has_both_effects_on`, `test_the_light_comes_from_the_upper_left` and `test_the_effects_stay_subtle` all fail, and `test_the_radius_is_in_screen_pixels` fails on the missing `fwidth`.

- [ ] **Step 3: Add the shader stage**

In `Scripts/Shaders/illustration_grade.gdshader`, append after the existing `amount` uniform:

```glsl
// -- inner AO and rim -------------------------------------------------------
// Both are zero on the plain material, so the backdrops that wear it pay
// nothing: the uniform is constant across a draw call, so the branch below is
// coherent and free. See the design doc for why the split exists.

// How dark the edge band goes. 0 disables AO for every plate wearing this
// material.
uniform float ao_strength : hint_range(0.0, 1.0) = 0.0;
// Width of the AO band, in SCREEN pixels -- not texels. See fwidth below.
uniform float ao_radius_px : hint_range(0.0, 24.0) = 6.0;
// What the occluded edge is tinted toward. Warm, to stay in the paper palette.
uniform vec4 ao_color : source_color = vec4(0.17, 0.11, 0.06, 1.0);
// How bright the lit edge gets. 0 disables the rim.
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
// Width of the rim, in SCREEN pixels.
uniform float rim_radius_px : hint_range(0.0, 16.0) = 3.0;
// Colour of the lit edge. Cream, matching the window light.
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
// Where the light is, in UV space. Upper-left, agreeing with the Lobby window,
// the streaks painted into the classroom floor, and the three contact shadows
// the artist authored offset down-right.
uniform vec2 light_dir = vec2(-0.6, -0.8);
```

Then replace the body of `fragment()`'s final line. The existing grade stays exactly as it is; this runs after it:

```glsl
void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;

	// Fully transparent pixels have no edge and no colour. Skipping them here
	// matters: a desk plate is 92% transparent but the fragment shader still
	// runs on every pixel of its rect, and the transparency is contiguous, so
	// whole tiles take this branch together.
	if (src.a <= 0.0) {
		COLOR = src;
	} else {
		vec3 rgb = src.rgb;
		rgb = mix(vec3(dot(rgb, LUMA)), rgb, saturation);
		rgb = (rgb - vec3(0.5)) * contrast + vec3(0.5);
		rgb *= tint.rgb * exposure;
		vec3 graded = clamp(mix(src.rgb, rgb, amount), vec3(0.0), vec3(1.0));

		// UV covered by one screen pixel. This is what makes the band the same
		// visual width on a desk drawn at 1.0 and a racket drawn at 0.34.
		vec2 upp = fwidth(UV);

		// -- inner AO --------------------------------------------------------
		// Four taps of our own alpha. Deep inside, all four return 1 and edge
		// is 0. Near the rim some fall outside the silhouette and the average
		// drops. Ambient: no direction, all the way around.
		if (ao_strength > 0.0) {
			vec2 r = upp * ao_radius_px;
			float a = texture(TEXTURE, UV + vec2(r.x, 0.0)).a
				+ texture(TEXTURE, UV - vec2(r.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, r.y)).a
				+ texture(TEXTURE, UV - vec2(0.0, r.y)).a;
			float edge = clamp(1.0 - a * 0.25, 0.0, 1.0);
			graded = mix(graded, graded * ao_color.rgb, edge * ao_strength);
		}

		// -- rim -------------------------------------------------------------
		// One tap, offset toward the light. If the neighbour that way is
		// transparent while we are opaque, we are standing on the lit edge.
		// Additive, because light brightens what is behind it.
		if (rim_strength > 0.0) {
			vec2 rr = upp * rim_radius_px * normalize(light_dir);
			float behind = texture(TEXTURE, UV + rr).a;
			float lit = clamp(src.a - behind, 0.0, 1.0);
			graded += rim_color.rgb * (lit * rim_strength);
		}

		COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), src.a);
	}
}
```

Delete the old `fragment()` body that this replaces — the file must contain exactly one `void fragment()`.

- [ ] **Step 4: Add the two strength lines to the plain material**

Append to `Scripts/Shaders/illustration_grade_material.tres` under `[resource]`:

```
shader_parameter/ao_strength = 0.0
shader_parameter/rim_strength = 0.0
```

- [ ] **Step 5: Create the cutout material**

Create `Scripts/Shaders/illustration_grade_cutout.tres`:

```
[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://Scripts/Shaders/illustration_grade.gdshader" id="1_grade"]

[resource]
shader = ExtResource("1_grade")
shader_parameter/saturation = 1.0175
shader_parameter/contrast = 1.01125
shader_parameter/exposure = 0.995
shader_parameter/tint = Color(1.022, 1, 0.972, 1)
shader_parameter/amount = 1.0
shader_parameter/ao_strength = 0.30
shader_parameter/ao_radius_px = 6.0
shader_parameter/ao_color = Color(0.17, 0.11, 0.06, 1)
shader_parameter/rim_strength = 0.18
shader_parameter/rim_radius_px = 3.0
shader_parameter/rim_color = Color(1, 0.95, 0.82, 1)
shader_parameter/light_dir = Vector2(-0.6, -0.8)
```

The grade values are copied from the plain material verbatim, including the two halvings from 2026-09-22 and 2026-09-23. If those ever change, both files change together. The AO and rim strengths here are **starting values, replaced by measurement in Task 3.**

- [ ] **Step 6: Restart the editor, then run the test**

A changed default on a resource needs a full editor restart — `load_default()` keeps serving the cached instance otherwise, and a test asserting the new value fails for no visible reason. Close Godot, relaunch detached (see "Editor hazards"), then:

```
test_run(suite="illustration_ao")
```

Expected: PASS, 8 tests.

- [ ] **Step 7: Confirm nothing else moved, then commit**

```bash
git status --porcelain
git branch --show-current
git add Scripts/Shaders/illustration_grade.gdshader Scripts/Shaders/illustration_grade_material.tres Scripts/Shaders/illustration_grade_cutout.tres Scripts/Shaders/illustration_grade_cutout.tres.uid tests/test_illustration_ao.gd tests/test_illustration_ao.gd.uid
git commit -F <message file>
```

The message records the Task 1 `fwidth` numbers (`full=`, `half=`, `ratio=`), because the radius design rests on them and the next person should not have to re-derive that it was checked. End with the `Co-Authored-By` line.

---

### Task 3: Measure the strengths and set them

The values shipped in Task 2 are guesses. This task replaces them with measurements, by the method that produced the window light's 0.11 ceiling.

**Files:**
- Modify: `Scripts/Shaders/illustration_grade_cutout.tres`
- Modify: `tests/test_illustration_ao.gd` (ceilings only, if the measurement lands lower)

**Interfaces:**
- Consumes: `illustration_grade_cutout.tres` from Task 2.
- Produces: measured `ao_strength` and `rim_strength`, consumed by nothing in code but recorded in the commit and pinned by the ceilings.

- [ ] **Step 1: Seed and reach the Lobby**

Run the game, open the debug overlay **first** (calling teleport from `game_eval` opens the overlay and eats your tap), then General → ⚡ Seed Playtest State, then Scenes → Lobby.

- [ ] **Step 2: Capture the baseline**

In one `game_eval` call:

```gdscript
Engine.time_scale = 0.02
var vp := get_viewport()
var img: Image = vp.get_texture().get_image()
var total := 0.0
var n := 0
for y in range(0, img.get_height(), 4):
	for x in range(0, img.get_width(), 4):
		var c := img.get_pixel(x, y)
		total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		n += 1
return "mean_luma=%f samples=%d size=%dx%d" % [total / float(n), n, img.get_width(), img.get_height()]
```

Record `mean_luma`. **Note the reported size** — the editor's embedded run is half-size, and a 1px band cannot be judged there. If it reports 540x960 rather than 1080x1920, run the game windowed rather than embedded before trusting any band-width judgement.

- [ ] **Step 3: Sweep the rim**

The rim is additive over a palette that is mostly near-white (`surface_page` is `#FBF1E3`), so it clips to flat white fast. For each value in `[0.10, 0.14, 0.18, 0.22, 0.26, 0.30]`, in one `game_eval` per value:

```gdscript
var mat: ShaderMaterial = load("res://Scripts/Shaders/illustration_grade_cutout.tres")
mat.set_shader_parameter("rim_strength", VALUE)
Engine.time_scale = 0.02
var img: Image = get_viewport().get_texture().get_image()
var blown := 0
for y in range(0, img.get_height(), 2):
	for x in range(0, img.get_width(), 2):
		var c := img.get_pixel(x, y)
		if c.r >= 0.999 and c.g >= 0.999 and c.b >= 0.999:
			blown += 1
return "rim=%f blown=%d" % [VALUE, blown]
```

Take the baseline `blown` at `rim_strength = 0.0` first and subtract it. Ship **below the knee** — the value where the count starts climbing sharply — with margin, exactly as the window light ships at 0.11 against a knee of 0.12.

- [ ] **Step 4: Sweep the AO against the darkening gate**

For each value in `[0.15, 0.22, 0.30, 0.38, 0.45]`, set `ao_strength` the same way and re-run Step 2's mean-luminance capture. **The gate: whole-frame mean luminance must not fall more than 1% below the baseline.** AO may redistribute light locally; it may not re-darken a scene that has already been lightened twice.

Pick the largest value that passes, then step down one notch for margin.

- [ ] **Step 5: Write the measured values in**

Edit `Scripts/Shaders/illustration_grade_cutout.tres` with the two chosen numbers. If either landed well below the Task 2 ceilings, lower `AO_STRENGTH_CEILING` / `RIM_STRENGTH_CEILING` in `tests/test_illustration_ao.gd` to sit just above the shipped value — a ceiling far above what shipped pins nothing.

- [ ] **Step 6: Restart the editor and re-run**

```
test_run(suite="illustration_ao")
```

Expected: PASS, 8 tests.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Shaders/illustration_grade_cutout.tres tests/test_illustration_ao.gd
git commit -F <message file>
```

The message carries the sweep: baseline `mean_luma`, the blown-pixel counts per rim value, the mean luminance per AO value, the knee, and the shipped numbers. This is the record that lets the next person re-measure instead of re-guessing.

---

### Task 4: Assign the cutout material to the 21 cutouts

**Files (all modified as text, editor closed — see "Editor hazards"):**
- `Scenes/Lobby/loby.tscn` — 4 nodes
- `Scenes/Koperasi/koprasi.tscn` — 2 nodes
- `Scenes/SchoolSimulation/EventDialogue.tscn` — 1 node
- `Scenes/Lobby/AndiFace.tscn`, `CitraFace.tscn`, `DoniFace.tscn`, `MarcelFace.tscn`, `ShintaFace.tscn`, `TheaFace.tscn` — 1 node each
- `Scenes/Minigames/SeniBudaya/DancerRig.tscn` — 2 nodes
- `Scenes/Minigames/Olahraga/MainBola.tscn` — 2 nodes
- `Scenes/Minigames/Olahraga/Badminton.tscn` — 3 nodes
- `Scenes/Minigames/Akademis/Kalkulator.tscn` — 1 node
- Modify: `tests/test_illustration_ao.gd`

**Interfaces:**
- Consumes: `illustration_grade_cutout.tres` from Task 2.
- Produces: the `CUTOUTS` / `BACKDROPS` census dicts in `tests/test_illustration_ao.gd`, cross-checked by Task 5 against nothing — they are terminal.

- [ ] **Step 1: Write the failing census test**

Append to `tests/test_illustration_ao.gd`:

```gdscript
## The census, measured on 2026-09-23 by sampling each texture's alpha channel.
## A cutout has an alpha edge to find; a backdrop is full-bleed and would pay
## five taps per pixel for nothing. Percentages are transparent pixels.
const CUTOUTS := {
	"res://Scenes/Lobby/loby.tscn": [
		"Classroom/Meja_KiriAtas", "Classroom/Meja_KananAtas",
		"Classroom/Meja_KiriBawah", "Classroom/Meja_KananBawah",
	],
	"res://Scenes/Koperasi/koprasi.tscn": ["Stage/Herman", "Stage/Foreground"],
	"res://Scenes/SchoolSimulation/EventDialogue.tscn": ["Splash"],
	"res://Scenes/Lobby/AndiFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/CitraFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/DoniFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/MarcelFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/ShintaFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/TheaFace.tscn": ["Canvas/Base"],
	"res://Scenes/Minigames/SeniBudaya/DancerRig.tscn": ["Body", "Head"],
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": ["Goalie/GFX", "Ball/GFX"],
	"res://Scenes/Minigames/Olahraga/Badminton.tscn": [
		"Puck/Sprite2D", "PlayerPaddle/Sprite2D", "EnemyPaddle/Sprite2D",
	],
	# 1.4% transparent -- a real rounded silhouette with soft edges, so it
	# counts. The one judgement call in this table: if it ends up reading as
	# furniture rather than UI, give it the plain material back.
	"res://Scenes/Minigames/Akademis/Kalkulator.tscn": ["Body/BodyTexture"],
}

## Full-bleed. These keep the material they have always worn.
const BACKDROPS := {
	"res://Scenes/Lobby/loby.tscn": ["Classroom/BGLayer"],
	"res://Scenes/Koperasi/koprasi.tscn": ["Stage/Background"],
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn": ["Background"],
	"res://Scenes/Minigames/Akademis/Password.tscn": ["Background"],
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn": ["Background"],
	"res://Scenes/Minigames/Akademis/Variabel.tscn": ["Background"],
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn": ["Background"],
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn": ["Background"],
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": ["FieldBG"],
}


func test_every_cutout_wears_the_cutout_material() -> void:
	var cutout: Material = load(CUTOUT)
	for scene_path in CUTOUTS:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in CUTOUTS[scene_path]:
			var node := root.get_node_or_null(NodePath(node_path)) as CanvasItem
			assert_true(node != null, "%s is missing %s" % [scene_path, node_path])
			if node == null:
				continue
			assert_eq(node.material, cutout,
				"%s/%s must wear the cutout grade" % [scene_path, node_path])


func test_every_backdrop_keeps_the_plain_material() -> void:
	var plain: Material = load(PLAIN)
	for scene_path in BACKDROPS:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in BACKDROPS[scene_path]:
			var node := root.get_node_or_null(NodePath(node_path)) as CanvasItem
			assert_true(node != null, "%s is missing %s" % [scene_path, node_path])
			if node == null:
				continue
			assert_eq(node.material, plain,
				"%s/%s is full-bleed and must not pay for AO" % [scene_path, node_path])


## The two dicts here and look_layer's GRADED describe the same thirty plates
## from two angles. If someone adds a plate to one and forgets the other, the
## game quietly has an ungraded illustration or an uncounted one. This is the
## test that notices.
func test_the_census_covers_every_graded_plate_exactly_once() -> void:
	var suite := load("res://tests/test_look_layer.gd").new()
	var graded: Dictionary = suite.get("GRADED")
	assert_true(graded != null and not graded.is_empty(), "look_layer must expose GRADED")
	if graded == null:
		return

	var counted := {}
	for source in [CUTOUTS, BACKDROPS]:
		for scene_path in source:
			for node_path in source[scene_path]:
				var key := "%s::%s" % [scene_path, node_path]
				assert_false(counted.has(key), "%s is counted twice" % key)
				counted[key] = true

	var expected := {}
	for scene_path in graded:
		for node_path in graded[scene_path]:
			expected["%s::%s" % [scene_path, node_path]] = true

	for key in expected:
		assert_true(counted.has(key), "%s wears the grade but is in neither census bucket" % key)
	for key in counted:
		assert_true(expected.has(key), "%s is in the census but does not wear the grade" % key)
	assert_eq(counted.size(), 30, "the census must cover all thirty graded plates")
```

- [ ] **Step 2: Run it to make sure it fails**

```
test_run(suite="illustration_ao")
```

Expected: FAIL — 21 assertions of the form "must wear the cutout grade", because every plate still wears the plain material.

- [ ] **Step 3: Close the editor**

Check `MainWindowTitle` for `(*)` first. Then `Stop-Process` on the `Godot_v*` PID only.

- [ ] **Step 4: Rewrite the 13 scenes as text**

For each scene, add one `ext_resource` line after the last existing `[ext_resource ...]` line:

```
[ext_resource type="Material" path="res://Scripts/Shaders/illustration_grade_cutout.tres" id="illus_grade_cut"]
```

and, on each cutout node listed above, **replace** its existing `material = ExtResource("illus_grade")` line with:

```
material = ExtResource("illus_grade_cut")
```

Where a scene has no remaining node using `illus_grade` afterwards (`loby.tscn` keeps `BGLayer`, `koprasi.tscn` keeps `Background`, `MainBola.tscn` keeps `FieldBG` — but `EventDialogue`, the six faces, `DancerRig`, `Badminton` and `Kalkulator` do not), **delete the now-unused `illus_grade` ext_resource line** or Godot will warn on load.

- [ ] **Step 5: Relaunch the editor and run the test**

Relaunch detached, then:

```
test_run(suite="illustration_ao")
```

Expected: PASS, 11 tests.

- [ ] **Step 6: Check the diff is only what you wrote**

```bash
git diff --stat
```

Expected: 13 scenes, and the line count should be close to `21 material lines + 13 ext_resource adds + 9 ext_resource deletes`. Anything else — baked offsets, a `theme_override`, `grow_horizontal` appearing — means an editor save slipped in. Restore from `HEAD` and redo the text edit.

- [ ] **Step 7: Run the neighbouring suites**

```
test_run(suite="look_layer")
test_run(suite="minigame_art")
test_run(suite="kalkulator")
test_run(suite="badminton_visuals")
test_run(suite="main_bola_layout")
test_run(suite="lobby")
```

Expected: all green. `look_layer`'s `test_every_graded_node_shares_the_one_material` **will now fail** — it asserts every graded node wears the *one* material, which is no longer true.

- [ ] **Step 8: Update `look_layer` for the two-material world**

In `tests/test_look_layer.gd`, change `test_every_graded_node_shares_the_one_material` to accept either material, and say why in the docstring:

```gdscript
## One shader, two materials since 2026-09-23: the cutouts wear
## illustration_grade_cutout.tres, which adds AO and a rim, and the full-bleed
## backdrops wear the plain one. Both are the shared resources -- what this
## still forbids is a per-node copy, which would strand a plate the next time
## the grade is tuned. Which plate gets which is tested in illustration_ao.
func test_every_graded_node_shares_a_shared_material() -> void:
	var plain: Material = load(GRADE_MATERIAL)
	var cutout: Material = load("res://Scripts/Shaders/illustration_grade_cutout.tres")
	assert_true(plain is ShaderMaterial, "the grade material must exist")
	assert_true(cutout is ShaderMaterial, "the cutout grade material must exist")
	for scene_path in GRADED:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in GRADED[scene_path]:
			var node := root.get_node_or_null(NodePath(node_path)) as CanvasItem
			assert_true(node != null, "%s is missing %s" % [scene_path, node_path])
			if node == null:
				continue
			assert_true(node.material == plain or node.material == cutout,
				"%s/%s must wear one of the two shared grades, not a copy"
					% [scene_path, node_path])
```

Also update `_collect_ui_offenders` so the "grade never lands on UI" test covers both materials — change its `shared: Material` parameter to `shared: Array` and test `item.material in shared`, passing `[plain, cutout]` from `test_the_grade_never_lands_on_a_ui_node`.

- [ ] **Step 9: Re-run both suites**

```
test_run(suite="look_layer")
test_run(suite="illustration_ao")
```

Expected: both PASS.

- [ ] **Step 10: Commit**

```bash
git add Scenes/ tests/test_illustration_ao.gd tests/test_look_layer.gd
git commit -F <message file>
```

---

### Task 5: Outer AO — four new instances, three retuned

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (4 new `Shadow` children)
- Modify: `Scenes/Koperasi/koprasi.tscn` (`Stage/Herman/Shadow`)
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (`BGHari/Shadow`)
- Modify: `Scenes/SchoolSimulation/EventDialogue.tscn` (`Splash/Shadow`)
- Modify: `tests/test_paper_shadow.gd`

**Interfaces:**
- Consumes: `res://Scenes/UI/PaperShadow.tscn`, whose root exports are `shadow_texture: Texture2D`, `shadow_offset: Vector2`, `shadow_scale: float`, `shadow_alpha: float`, `blur: float`, `follow_parent_rect: bool`, `shadow_stretch_mode: TextureRect.StretchMode`.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing tests**

In `tests/test_paper_shadow.gd`, **delete** `test_the_lobby_desks_cast_no_shadow` and its `_LOBBY_DESKS` const, and put the Lobby back into `_CONTACT_SHADOWS`:

```gdscript
	"res://Scenes/Lobby/loby.tscn": [
		"Classroom/Meja_KiriAtas", "Classroom/Meja_KananAtas",
		"Classroom/Meja_KiriBawah", "Classroom/Meja_KananBawah",
	],
```

Then add:

```gdscript
## Outer AO, not a cast shadow (2026-09-23).
##
## These seven were authored as drop shadows -- offset 8-14 px at alpha
## 0.24-0.30 with a wide blur -- and the Lobby's four were removed that morning
## for reading as dirt beside the desk rather than contact under it. They come
## back the same day as something else: zero offset, a third of the blur. It is
## not a shadow from anywhere; it is the floor going dark where the plate
## occludes it, which is why it can be denser without reading as grime.
##
## A deliberate reversal, not an accident. The design doc's section 6 has the
## argument in full.
const _OUTER_AO := {
	"res://Scenes/Lobby/loby.tscn": [
		"Classroom/Meja_KiriAtas", "Classroom/Meja_KananAtas",
		"Classroom/Meja_KiriBawah", "Classroom/Meja_KananBawah",
	],
	"res://Scenes/Koperasi/koprasi.tscn": ["Stage/Herman"],
	"res://Scenes/AturJadwal/atur_jadwal.tscn": ["BGHari"],
	"res://Scenes/SchoolSimulation/EventDialogue.tscn": ["Splash"],
}
const _OUTER_AO_ALPHA := 0.34
const _OUTER_AO_BLUR := 1.2


func test_the_contact_shadows_are_outer_ao_not_drop_shadows() -> void:
	for scene_path in _OUTER_AO:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in _OUTER_AO[scene_path]:
			var shadow := root.get_node_or_null(NodePath(node_path + "/Shadow")) as Control
			assert_true(shadow != null, "%s/%s has no Shadow" % [scene_path, node_path])
			if shadow == null:
				continue
			assert_eq(shadow.get("shadow_offset"), Vector2.ZERO,
				"%s/%s: an offset makes it a cast shadow again" % [scene_path, node_path])
			assert_true(is_equal_approx(shadow.get("shadow_alpha"), _OUTER_AO_ALPHA),
				"%s/%s: outer AO alpha must match the rest of the game" % [scene_path, node_path])
			assert_true(is_equal_approx(shadow.get("blur"), _OUTER_AO_BLUR),
				"%s/%s: outer AO blur must match the rest of the game" % [scene_path, node_path])


## The twelve paper shadows in StudentCard and ReportCard are NOT outer AO and
## must keep their offset. A paper thrown off-screen by _transition_page()
## should cast a real shadow; that is a different effect with a different job.
func test_the_paper_shadows_keep_their_offset() -> void:
	for scene_path in _SCENES:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for paper_name in _PAPERS:
			var paper := root.get_node_or_null(NodePath(paper_name)) as Control
			if paper == null:
				continue
			var shadow := paper.get_node_or_null("PaperShadow") as Control
			if shadow == null:
				continue
			assert_true(shadow.get("shadow_offset") != Vector2.ZERO,
				"%s/%s: a flying paper still casts a real shadow" % [scene_path, paper_name])
```

- [ ] **Step 2: Run it to make sure it fails**

```
test_run(suite="paper_shadow")
```

Expected: FAIL — the Lobby's four have no `Shadow` at all, and the other three still carry their authored offsets.

- [ ] **Step 3: Close the editor and edit the four scenes as text**

In `Scenes/Lobby/loby.tscn`, restore the `paper_shadow` ext_resource after the last `[ext_resource ...]` line:

```
[ext_resource type="PackedScene" uid="uid://dbpxkqo7wrn8e" path="res://Scenes/UI/PaperShadow.tscn" id="paper_shadow"]
```

and add one block immediately after each desk node's property block (after its `stretch_mode = 5` line and the blank line that follows):

```
[node name="Shadow" parent="Classroom/Meja_KiriAtas" instance=ExtResource("paper_shadow")]
layout_mode = 0
shadow_texture = ExtResource("meja_ka_tex")
shadow_offset = Vector2(0, 0)
shadow_scale = 1.0
shadow_alpha = 0.34
blur = 1.2
```

Repeat for `Meja_KananAtas` (`meja_kna_tex`), `Meja_KiriBawah` (`meja_kb_tex`) and `Meja_KananBawah` (`meja_knb_tex`) — each shadow uses **its own desk's texture**, so the silhouette matches the plate.

In the other three scenes, change only the three property lines on the existing `Shadow` nodes:

| Scene | Node | From | To |
|---|---|---|---|
| `koprasi.tscn` | `Stage/Herman/Shadow` | `(12,10)`, `0.26`, `3.0` | `Vector2(0, 0)`, `0.34`, `1.2` |
| `atur_jadwal.tscn` | `BGHari/Shadow` | `(8,12)`, `0.30`, `3.0` | `Vector2(0, 0)`, `0.34`, `1.2` |
| `EventDialogue.tscn` | `Splash/Shadow` | `(14,10)`, `0.24`, `3.5` | `Vector2(0, 0)`, `0.34`, `1.2` |

Leave `follow_parent_rect` and `shadow_stretch_mode` on `Splash/Shadow` exactly as they are — a Full Rect element's shadow takes its size from the parent, and `test_a_full_rect_element_gets_a_shadow_that_follows_its_size` pins both.

- [ ] **Step 4: Relaunch and run**

```
test_run(suite="paper_shadow")
```

Expected: PASS. The suite is now 9 tests.

- [ ] **Step 5: Run the suites that touch these scenes**

```
test_run(suite="lobby")
test_run(suite="lobby_layout")
test_run(suite="atur_jadwal")
test_run(suite="tall_screen_layout")
test_run(suite="illustration_ao")
```

Expected: all green.

- [ ] **Step 6: Look at it**

Run the game, seed, teleport to the Lobby, and take **one full-size screenshot**. A scaled capture cannot show a 1px band. Confirm the desks read as sitting on the floor and that nothing reads as a smudge beside them. If it does, the blur or alpha is wrong — change the two numbers in all seven places and the two consts in the test together.

- [ ] **Step 7: Commit**

```bash
git diff --stat
git add Scenes/ tests/test_paper_shadow.gd
git commit -F <message file>
```

The message must state plainly that this reverses the same day's removal, and why the two are different objects — otherwise the git log reads as an accident.

---

### Task 6: Lobby light shafts

**Files:**
- Create: `Scripts/Shaders/light_shafts.gdshader`
- Create: `Scripts/Shaders/window_shafts_material.tres`
- Modify: `Scenes/Lobby/loby.tscn` (one new node, one property on `Classroom`'s `ParallaxDiorama`)
- Modify: `tests/test_illustration_ao.gd`

**Interfaces:**
- Consumes: `ParallaxDiorama`'s `depth_by_child: Dictionary` export, keyed by child node name.
- Produces: `res://Scripts/Shaders/window_shafts_material.tres`, driven by Task 7.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_illustration_ao.gd`:

```gdscript
## The Lobby's light shafts (2026-09-23). The volumetric piece of the pass, and
## the only one placed per scene rather than applied to every plate -- shafts
## need a window to come from, and the Lobby is the only room that has one.
##
## Extracted from achievement_glow.gdshader, which has drawn rotating shafts
## since the achievements pass. Additive, because light brightens what is behind
## it; an alpha-blended overlay would flatten the art it falls on.
func test_the_lobby_shafts_are_additive_and_placed() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Shaders/light_shafts.gdshader")
	assert_true(src.contains("render_mode blend_add"),
		"shafts brighten what is behind them; they do not paint over it")

	var lobby := (load("res://Scenes/Lobby/loby.tscn") as PackedScene).instantiate()
	track(lobby)
	var shafts := lobby.get_node_or_null("Classroom/WindowShafts") as Control
	assert_true(shafts != null, "the Lobby should carry the window shafts")
	if shafts == null:
		return
	assert_eq(shafts.mouse_filter, Control.MOUSE_FILTER_IGNORE, "light must never eat a tap")
	var mat: ShaderMaterial = load("res://Scripts/Shaders/window_shafts_material.tres")
	assert_true(mat != null, "the shafts material must exist")
	assert_eq(shafts.material, mat, "the shafts must use the shared material")


## Over a palette this near-white, additive light clips to flat white fast:
## surface_page is #FBF1E3, and the window light next to these ships at 0.11
## against a measured knee of 0.12. Shafts are thinner than that pool, but they
## are also animated, so an over-bright value reads as flicker. Measured by the
## same sweep.
const SHAFT_INTENSITY_CEILING := 0.09


func test_the_shafts_stay_under_the_clipping_knee() -> void:
	var mat: ShaderMaterial = load("res://Scripts/Shaders/window_shafts_material.tres")
	assert_true(mat != null, "the shafts material must exist")
	if mat == null:
		return
	var intensity: float = mat.get_shader_parameter("intensity")
	assert_true(intensity <= SHAFT_INTENSITY_CEILING,
		"intensity %s blows the cream palette to flat white; ceiling is %s"
			% [intensity, SHAFT_INTENSITY_CEILING])


## The shafts must move with the wall they come through, or they float over a
## room that is parallaxing underneath them. BGLayer's own depth is 0.15.
func test_the_shafts_parallax_with_the_room() -> void:
	var lobby := (load("res://Scenes/Lobby/loby.tscn") as PackedScene).instantiate()
	track(lobby)
	var diorama := lobby.get_node_or_null("Classroom/ParallaxDiorama")
	if diorama == null:
		for child in lobby.get_node("Classroom").get_children():
			if child.get("depth_by_child") != null:
				diorama = child
				break
	assert_true(diorama != null, "the Classroom must have its ParallaxDiorama")
	if diorama == null:
		return
	var depths: Dictionary = diorama.get("depth_by_child")
	assert_true(depths.has("WindowShafts"), "the shafts must be registered for parallax")
	if depths.has("WindowShafts"):
		assert_true(is_equal_approx(depths["WindowShafts"], depths.get("BGLayer", 0.15)),
			"the shafts come through the back wall, so they share its depth")
```

- [ ] **Step 2: Run it to make sure it fails**

```
test_run(suite="illustration_ao")
```

Expected: FAIL — the shader, the material and the node do not exist.

- [ ] **Step 3: Write the shader**

Create `Scripts/Shaders/light_shafts.gdshader`:

```glsl
shader_type canvas_item;
render_mode blend_add;

// Light shafts through a window. The rotating-shaft half of
// achievement_glow.gdshader, pulled out without the pulsing starburst core so a
// room can have sunlight without looking like an achievement popped.
//
// WHY ADDITIVE. blend_add only ever brightens what is behind it, which is what
// light does. An alpha-blended overlay would replace the art's colour with its
// own wherever it is opaque, flattening exactly the detail the light is
// supposed to reveal. Same reasoning as light_falloff.gdshader.
//
// THE CREAM PROBLEM. This palette is mostly near-white -- surface_page is
// #FBF1E3 -- so additive light clips to flat white almost immediately and reads
// as a blown-out patch rather than illumination. `intensity` wants to be small
// here: the window light beside these ships at 0.11 against a measured knee of
// 0.12, and these are animated, so an over-bright value reads as flicker
// instead of sun. Judge it on a full-size capture.

// Colour of the light. Warm, matching the window pool it sits beside.
uniform vec4 shaft_color : source_color = vec4(1.0, 0.898, 0.706, 1.0);
// Peak brightness. Keep it low over cream; see the header.
uniform float intensity : hint_range(0.0, 0.5) = 0.06;
// Where the shafts converge, in UV. The window, which is up and to the left.
uniform vec2 origin = vec2(0.12, -0.08);
// How many shafts. Fewer and wider reads as sun; many and thin reads as a
// starburst, which is the effect this was extracted to avoid.
uniform float shaft_count = 7.0;
// Edge softness of each shaft. Higher is softer.
uniform float softness : hint_range(1.0, 12.0) = 5.0;
// How far from the origin the shafts fade out, in UV.
uniform float reach : hint_range(0.1, 3.0) = 1.4;
// Speed of the slow drift. Dust moves; sunlight does not strobe.
uniform float drift_speed = 0.035;

void fragment() {
	vec2 p = UV - origin;
	float dist = length(p) / reach;
	float sector = (atan(p.y, p.x) + TIME * drift_speed) / TAU * shaft_count;
	float across = abs(fract(sector) - 0.5) * 2.0;
	float shaft = pow(1.0 - across, softness);
	float fade = smoothstep(1.0, 0.15, dist);
	COLOR = vec4(shaft_color.rgb, 1.0) * (shaft * fade * intensity);
}
```

- [ ] **Step 4: Write the material**

Create `Scripts/Shaders/window_shafts_material.tres`:

```
[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://Scripts/Shaders/light_shafts.gdshader" id="1_shafts"]

[resource]
shader = ExtResource("1_shafts")
shader_parameter/shaft_color = Color(1, 0.898, 0.706, 1)
shader_parameter/intensity = 0.06
shader_parameter/origin = Vector2(0.12, -0.08)
shader_parameter/shaft_count = 7.0
shader_parameter/softness = 5.0
shader_parameter/reach = 1.4
shader_parameter/drift_speed = 0.035
```

- [ ] **Step 5: Add the node through the editor**

This one is a new node with several properties, so use the editor rather than a text edit.

```
scene_open(path="res://Scenes/Lobby/loby.tscn")
batch_execute(commands=[
  {"command": "create_node", "params": {"parent_path": "/Lobby/Classroom", "node_type": "ColorRect", "node_name": "WindowShafts"}},
  {"command": "set_property", "params": {"path": "/Lobby/Classroom/WindowShafts", "property": "layout_mode", "value": 1}},
  {"command": "set_property", "params": {"path": "/Lobby/Classroom/WindowShafts", "property": "anchor_right", "value": 1}},
  {"command": "set_property", "params": {"path": "/Lobby/Classroom/WindowShafts", "property": "anchor_bottom", "value": 1}},
  {"command": "set_property", "params": {"path": "/Lobby/Classroom/WindowShafts", "property": "mouse_filter", "value": 2}},
  {"command": "set_property", "params": {"path": "/Lobby/Classroom/WindowShafts", "property": "color", "value": "Color(1, 1, 1, 1)"}},
  {"command": "set_property", "params": {"path": "/Lobby/Classroom/WindowShafts", "property": "material", "value": "res://Scripts/Shaders/window_shafts_material.tres"}}
])
```

Confirm the scene root's actual name first with `scene_get_hierarchy` — the paths above assume `Lobby`. `anchors_preset` is inert; the four anchors must be set individually, and `layout_mode = 1` must come first or the anchors are not saved.

`node_create` appends last, which is what we want: the shafts draw over the room. Then register the parallax depth on the `ParallaxDiorama` node (find its exact path with `scene_get_hierarchy`) by setting `depth_by_child` to the existing dictionary plus `"WindowShafts": 0.15`.

Then `scene_save`.

- [ ] **Step 6: Diff immediately**

```bash
git diff Scenes/Lobby/loby.tscn
```

Expected: the new node, the `depth_by_child` line, and nothing else. `BookClockWidget` sky-layer offsets and a `main_scene` uid rewrite are known-harmless if they appear; a baked `theme_override` or shifted offsets on anything else are not — restore from `HEAD` and redo.

- [ ] **Step 7: Measure the intensity, then run**

Run the game, seed, Lobby, and sweep `intensity` over `[0.03, 0.06, 0.09, 0.12]` using the blown-pixel count from Task 3 Step 3. Ship below the knee. If the measured value exceeds `SHAFT_INTENSITY_CEILING`, the ceiling was wrong — but re-read the cream-palette note before raising it.

```
test_run(suite="illustration_ao")
test_run(suite="lobby")
test_run(suite="lobby_layout")
test_run(suite="tall_screen_layout")
test_run(suite="viewport_editability")
```

Expected: all green. `viewport_editability` matters here: the shafts are authored in the `.tscn`, so the `BASELINE` dict must not move.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Shaders/light_shafts.gdshader Scripts/Shaders/light_shafts.gdshader.uid Scripts/Shaders/window_shafts_material.tres Scenes/Lobby/loby.tscn tests/test_illustration_ao.gd
git commit -F <message file>
```

---

### Task 7: The debug overlay's Look page

The point of this page is that the user tunes the effect while looking at it, instead of asking a session to halve a number and waiting. Both materials are shared resources, so one slider moves every plate in the scene at once.

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd` (new `_build_look_panel`, one entry in `tab_names`, one call in `_build_ui`)
- Modify: `tests/test_illustration_ao.gd`

**Interfaces:**
- Consumes: `illustration_grade_cutout.tres` and `window_shafts_material.tres` by path, and their uniform names from Tasks 2 and 6.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_illustration_ao.gd`:

```gdscript
## The Look page exists so the effect is tuned by the person looking at it.
## Source-scanned rather than instantiated: DebugManager builds its UI
## programmatically in _ready and is an autoload, so standing one up in a test
## would build the whole overlay.
func test_the_debug_overlay_has_a_look_page() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugManager.gd")
	assert_true(src.contains("_build_look_panel"), "the overlay needs a Look panel builder")
	assert_true(src.contains('"Look"'), "Look must be registered as a tab")
	for uniform in ["ao_strength", "ao_radius_px", "rim_strength", "rim_radius_px"]:
		assert_true(src.contains(uniform), "the Look page must drive %s" % uniform)
	assert_true(src.contains("illustration_grade_cutout.tres"),
		"the sliders must write to the shared cutout material")
```

- [ ] **Step 2: Run it to make sure it fails**

```
test_run(suite="illustration_ao")
```

Expected: FAIL on `_build_look_panel`.

- [ ] **Step 3: Register the tab**

In `Scripts/Debug/DebugManager.gd`, add `"Look"` to `tab_names` (line ~285), and add `_build_look_panel(content_area)` beside the other `_build_*_panel` calls (line ~318).

- [ ] **Step 4: Write the panel**

Add this method, following the file's existing panel pattern exactly (`ScrollContainer` → `MarginContainer` → `VBoxContainer`, programmatic styling, Indonesian labels):

```gdscript
## Live control over the illustration look: inner AO, the rim light and the
## Lobby's shafts. Every slider writes to a SHARED material, so one drag moves
## every plate on screen at once -- which is the point. Nothing here persists;
## when a value looks right, write it into the .tres.
func _build_look_panel(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	panels["Look"] = scroll

	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_top", 30)
	margin_container.add_theme_constant_override("margin_right", 30)
	margin_container.add_theme_constant_override("margin_bottom", 30)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin_container)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.text = "Tampilan Ilustrasi (live, tidak tersimpan):"
	lbl_title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(lbl_title)

	var cutout: ShaderMaterial = load("res://Scripts/Shaders/illustration_grade_cutout.tres")
	_add_look_slider(vbox, cutout, "ao_strength", "Kekuatan AO", 0.0, 0.6, 0.01)
	_add_look_slider(vbox, cutout, "ao_radius_px", "Lebar AO (piksel layar)", 0.0, 16.0, 0.5)
	_add_look_slider(vbox, cutout, "rim_strength", "Kekuatan Rim", 0.0, 0.4, 0.01)
	_add_look_slider(vbox, cutout, "rim_radius_px", "Lebar Rim (piksel layar)", 0.0, 10.0, 0.5)

	var lbl_shafts = Label.new()
	lbl_shafts.text = "Cahaya Jendela (khusus Lobby):"
	lbl_shafts.add_theme_font_size_override("font_size", 26)
	vbox.add_child(lbl_shafts)

	var shafts: ShaderMaterial = load("res://Scripts/Shaders/window_shafts_material.tres")
	_add_look_slider(vbox, shafts, "intensity", "Kekuatan Cahaya", 0.0, 0.2, 0.005)
	_add_look_slider(vbox, shafts, "shaft_count", "Jumlah Berkas", 3.0, 16.0, 1.0)

	var lbl_note = Label.new()
	lbl_note.text = "Catatan: nilai di sini hilang saat keluar. Salin ke .tres kalau sudah pas."
	lbl_note.add_theme_font_size_override("font_size", 20)
	lbl_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_note)


## One labelled slider bound to one shader uniform on a shared material.
func _add_look_slider(parent: Control, mat: ShaderMaterial, uniform: String,
		caption: String, min_value: float, max_value: float, step: float) -> void:
	if mat == null:
		return
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl = Label.new()
	var current: float = float(mat.get_shader_parameter(uniform))
	lbl.text = "%s: %.3f" % [caption, current]
	lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = current
	slider.custom_minimum_size = Vector2(0, 60)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float):
		mat.set_shader_parameter(uniform, v)
		lbl.text = "%s: %.3f" % [caption, v])
	row.add_child(slider)
```

- [ ] **Step 5: Run the test**

```
test_run(suite="illustration_ao")
```

Expected: PASS.

- [ ] **Step 6: Use it once, for real**

Run the game, seed, Lobby, open the overlay, and drag each slider. Confirm every desk and every face changes together. If only one plate moves, a node is carrying a **copy** of the material rather than the shared resource — go back to Task 4 and find it.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Debug/DebugManager.gd tests/test_illustration_ao.gd
git commit -F <message file>
```

---

### Task 8: Prove each effect still switches off, then document and ship

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`
- Modify: `CLAUDE.md` (one line under "Visual system")
- Modify: `docs/superpowers/DEBT.md` (only if something was deferred)

- [ ] **Step 1: Verify the four off-switches, one at a time**

The user asked to be able to revert or control each effect. Prove it rather than assert it. For each row, make the change, run `test_run(suite="illustration_ao")` **and** `test_run(suite="paper_shadow")`, confirm the game still runs, then revert the change:

| Off-switch | Change | Expected |
|---|---|---|
| Inner AO | `ao_strength = 0` in the cutout material | Only `test_the_cutout_material_has_both_effects_on` and `test_the_effects_stay_subtle` react; nothing crashes; rim still visible |
| Rim | `rim_strength = 0` | Same shape; AO still visible |
| Outer AO | `shadow_alpha = 0` on all seven | `test_the_contact_shadows_are_outer_ao_not_drop_shadows` fails on alpha only |
| Shafts | `visible = false` on `WindowShafts` | `test_the_lobby_shafts_are_additive_and_placed` still passes; the room is unlit |

Record what each one did. If disabling one breaks something unrelated, they are entangled and the design's §5.1 promise is not being kept — fix that before shipping.

- [ ] **Step 2: Run the full suite**

```
test_run()
```

Expected: every suite green. Budget an editor restart afterwards — a full run drops the bridge.

- [ ] **Step 3: Clean the two files the run rewrites**

```bash
git status --porcelain
git checkout -- Assets/Theme/kejartes_theme.tres Assets/Audio/default_bus_layout.tres
```

Only revert the ones you did not intend. Nothing in this plan edits design tokens, so both should be reverted.

- [ ] **Step 4: Write the changelog entry**

Newest first in `docs/superpowers/CHANGELOG.md`. Cover: what shipped, the measured numbers (the `fwidth` ratio, the rim knee, the AO luminance gate result, the shaft intensity), the desk-shadow reversal and why, and that Kalkulator was a judgement call.

- [ ] **Step 5: Add the one durable rule to `CLAUDE.md`**

Under "Visual system", after the `ThemeFactory` rule, one short paragraph — the file has a 23,000-character soft budget, so this earns its place or something else moves:

```markdown
**Illustration plates wear one of two materials.** Cutouts take
`illustration_grade_cutout.tres` (grade + inner AO + rim); full-bleed backdrops
take `illustration_grade_material.tres` (grade only), because a backdrop has no
alpha edge and would pay five texture taps per pixel for nothing. Which is
which is pinned by `tests/test_illustration_ao.gd`'s census, measured from each
texture's alpha. Tune both live from the debug overlay's **Look** page, then
write the value into the `.tres`.
```

- [ ] **Step 6: Commit the documentation**

```bash
git add docs/superpowers/CHANGELOG.md CLAUDE.md
git commit -F <message file>
```

- [ ] **Step 7: Ship**

Use the `ship-pr` skill. It runs the full suite and a local review, opens the PR and stamps the tested commit. Bind the PR immediately after `gh pr create` (`bind_pr` + `set_monitor`) — the merge gate fires about two minutes after the stamps and the app may not auto-bind in time.

---

## Self-review

**Spec coverage.** §1.1 two materials → Task 2. §1.2 AO → Task 2 Step 3. §1.3 rim → Task 2 Step 3. §1.4 `fwidth` → Task 1, pinned in Task 2's test. §1.5 light direction → Task 2's `test_the_light_comes_from_the_upper_left`. §2 census → Task 4. §3.1/3.2 → Task 2. §3.3 outer AO → Task 5. §3.4 shafts → Task 6. §4 tuning method → Task 3, reused in Task 6 Step 7. §5.1 off-switches → Task 8 Step 1. §5.2 live control → Task 7. §5.3 revert path → the four commits are Tasks 2+3, 4, 5, 6, in that order. §6 reversal → Task 5 Step 1 and Step 7. §7 tests → Tasks 2, 4, 5, 6, 7. §8 risks → the early-out is in Task 2's shader; the racket opt-out is Task 4's census; the `fwidth` risk is Task 1. §9 acceptance → Task 8.

**One gap found and closed:** the spec's §5.3 lists four commits, but Task 3 (measurement) also commits. That is a fifth commit inside commit 1's scope — it touches only the cutout material and its ceilings, so reverting Task 2's commit still strands nothing. Noted rather than restructured, because splitting measurement from the thing being measured would make both commits meaningless on their own.

**Placeholder scan:** no TBD, no "add error handling", no "similar to Task N". Every code step carries its code. The one deliberate blank is the exact `ao_strength` / `rim_strength` / `intensity` numbers, which Task 3 and Task 6 Step 7 produce by a fully specified procedure — writing invented numbers there would be the actual failure.

**Type consistency:** uniform names are identical across Tasks 2, 4, 7 (`ao_strength`, `ao_radius_px`, `ao_color`, `rim_strength`, `rim_radius_px`, `rim_color`, `light_dir`) and Tasks 6, 7 (`intensity`, `shaft_count`, `origin`, `softness`, `reach`, `drift_speed`, `shaft_color`). Material paths are identical everywhere. `PaperShadow`'s export names match its script. `test_look_layer.gd`'s renamed test (`test_every_graded_node_shares_a_shared_material`) is referenced only in Task 4.
