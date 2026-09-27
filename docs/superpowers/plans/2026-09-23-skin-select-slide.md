# SkinSelect two-splash carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SkinSelect match `skinselection_mockup.png`: the centred skin and its neighbour on screen together, with brightness, blur, size and position following the finger continuously, and the tray redrawn to the mockup's measurements.

**Architecture:** One float, `SkinSelect._scroll` (card units), poses every card each frame through a pure `card_pose(t)`. `SkinCard.set_pose` applies position, scale and a per-card `ShaderMaterial` (`skin_card_focus.gdshader`) that blurs and dims the card's **own** texture. The tray's styles are new `ThemeFactory` variations built from named consts measured off the mockup.

**Tech Stack:** Godot 4.6 GDScript, canvas_item shaders, `.tscn` text, the project's `McpTestSuite` runner (Godot AI MCP `test_run`).

**Spec:** `docs/superpowers/specs/2026-09-23-skin-select-slide-design.md`

## Global Constraints

- Work only in the worktree `.claude/worktrees/skin-select-slide` (branch `feat/skin-select-slide`). Never `git checkout`/`switch` in the main checkout.
- UI text is Indonesian. The button says **TERAPKAN**.
- Never add a `theme_override_*` except `theme_override_constants/separation` and `theme_override_constants/margin_*`.
- No visual built at runtime: materials and nodes are authored in `.tscn`, not with `.new()`. `SkinCard` instancing is the existing per-call-dynamic exception.
- Every script has a `##` file header and a `##` line on every `@export` (`tests/test_script_documentation.gd`).
- Test suites are `@tool` and no test may `await`.
- Do not edit `Balance.gd`.
- Commits: Conventional Commits with a scope, written to a file and passed with `git commit -F <file>`. End every message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Mockup numbers (1080x1920 design px), verbatim from the spec:
  - Centre splash: scale **0.818**, top-left **(85, 153)**.
  - Neighbour splash: scale **0.658**, top-left **(676, 370)**, brightness **x0.71**, Gaussian blur **sigma 4px** (screen px).
  - Divider: black, y **1328-1335** (8px). Tray fill `#FFFDF8` (`surface_card`).
  - Tiles: 6 x **151x156**, 8px black rim, y **1430-1586**.
  - Back arrow: **(40,1677)-(237,1852)**.
  - Button: **(501,1709)-(1007,1849)**, fill `#D21919`, text `#F2F2F2`, 8px black rim, font 73.
  - Title: fill `#F2F2F2`, outline `#201934`, font 74, outer box (348,95)-(718,182).
- **How tests run here.** The MCP editor is the MAIN checkout's and cannot see this worktree. Tasks 1-4 are text-only (code, scenes and tests), written while **no editor has the worktree open**, which makes hand-editing `.tscn` safe. The controller (not a subagent: the bridge is single-client) verifies each task in a **worktree editor**. Seed it by copying `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg` and `scene_groups_cache.cfg` from the main checkout's `.godot/`. Launch it detached with `Invoke-CimMethod Win32_Process Create` (`"C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" --path "<worktree>" -e`), and pass its `session_id` on every call, never `session_activate`. **Quit and relaunch it before each task's verification**, because `load()` caches the old `PackedScene`s and scripts. Never let that editor `scene_save`.

---

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/Shaders/skin_card_focus.gdshader` (new) | Blurs and dims a card's own texture from two uniforms |
| `Scenes/Skins/SkinCard.tscn` | Full 1080x1920 card; `Art` carries a local-to-scene focus material |
| `Scripts/Skins/SkinCard.gd` | `show_skin`, `set_pose`, the static `settle_index` |
| `Scenes/Skins/skin_option_blur_material.tres` | **Deleted** (its only user was SkinCard) |
| `Scripts/Skins/SkinSelect.gd` | Scroll state, `card_pose`, drag, settle, draw order |
| `Scenes/Skins/SkinSelect.tscn` | Track as a plain Control; tray and title laid out to the mockup |
| `Scenes/Skins/StudentTile.tscn` | Tile size 151x156 |
| `Scripts/Design/ThemeFactory.gd` | `SkinTray`, `SkinApplyButton`, `SkinTitleLabel`, restyled `SkinStudentTile(Active)` |
| `Assets/Theme/kejartes_theme.tres` | Rebaked by the controller in Task 5 |
| `tests/test_skin_card.gd`, `tests/test_skin_select.gd`, `tests/test_student_tile.gd`, `tests/test_theme_factory.gd`, `tests/test_button_geometry.gd` | Updated or added assertions |
| `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md` | Debt line removed; changelog entry |

---

### Task 1: SkinCard blurs its own art, driven by a pose

**Files:**
- Create: `Scripts/Shaders/skin_card_focus.gdshader`
- Modify: `Scenes/Skins/SkinCard.tscn` (whole file)
- Modify: `Scripts/Skins/SkinCard.gd` (header, drop `BLUR_MATERIAL`/`unselected_modulate`/`set_selected`, add `focus` and `set_pose`)
- Delete: `Scenes/Skins/skin_option_blur_material.tres`
- Test: `tests/test_skin_card.gd`

**Interfaces:**
- Produces: `SkinCard.set_pose(origin: Vector2, card_scale: float, focus: float, side_brightness: float, side_blur_px: float) -> void` and `SkinCard.focus: float` (last applied focus, 0..1). The shader uniforms are `sigma_texels: float` and `brightness: float`. `SkinCard.settle_index(...)` is unchanged.
- Removes: `SkinCard.set_selected(bool)`, `SkinCard.unselected_modulate`, `SkinCard.BLUR_MATERIAL`. Task 2 stops calling them.

- [ ] **Step 1: Write the failing tests.** In `tests/test_skin_card.gd`, delete `const BLUR`, `test_selected_card_is_crisp_and_unselected_is_dimmed_and_blurred` and `test_card_is_sized_to_fit_the_whole_figure_above_the_tray`. Add:

```gdscript
const SHADER := "res://Scripts/Shaders/skin_card_focus.gdshader"


func _focus_material(card: SkinCard) -> ShaderMaterial:
	return (card.get_node("Art") as TextureRect).material as ShaderMaterial


## The old material sampled SCREEN_TEXTURE, so a "blurred" card drew a
## blurred rectangle of the background where the neighbour's splash should
## have been. The focus shader must read the card's own TEXTURE.
func test_focus_shader_blurs_the_cards_own_texture_not_the_screen() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_true(src != "", "skin_card_focus.gdshader must exist")
	assert_false(src.contains("hint_screen_texture"), "must not sample the screen")
	assert_true(src.contains("texture(TEXTURE"), "must sample the card's own art")
	assert_true(src.contains("uniform float sigma_texels"))
	assert_true(src.contains("uniform float brightness"))


func test_the_screen_blur_material_is_gone() -> void:
	assert_false(ResourceLoader.exists("res://Scenes/Skins/skin_option_blur_material.tres"))


## The card is the splash's own 1080x1920 canvas; the pose scales it. A
## smaller authored card was what pushed the neighbour's figure off screen.
func test_card_is_the_full_splash_canvas() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_true(src.contains("custom_minimum_size = Vector2(1080, 1920)"))


## Each card needs its own uniforms, or posing one card would re-pose both.
func test_each_card_owns_its_focus_material() -> void:
	var a := _new_card()
	var b := _new_card()
	assert_true(_focus_material(a) != null, "Art must carry a ShaderMaterial")
	if _focus_material(a) == null:
		return
	assert_eq(_focus_material(a).shader.resource_path, SHADER)
	assert_true(_focus_material(a) != _focus_material(b),
		"the material must be resource_local_to_scene")


func test_a_focused_pose_is_sharp_and_full_brightness() -> void:
	var card := _new_card()
	card.set_pose(Vector2(85, 153), 0.818, 1.0, 0.71, 4.0)
	assert_eq(card.position, Vector2(85, 153))
	assert_eq(card.scale, Vector2(0.818, 0.818))
	assert_eq(card.focus, 1.0)
	var mat := _focus_material(card)
	assert_almost_eq(float(mat.get_shader_parameter("sigma_texels")), 0.0, 0.0001)
	assert_almost_eq(float(mat.get_shader_parameter("brightness")), 1.0, 0.0001)


## The blur is specified in SCREEN pixels, so the texel radius grows as the
## card shrinks: 4px on screen at scale 0.658 is 4 / 0.658 texels.
func test_an_unfocused_pose_is_dim_and_blurred_in_screen_pixels() -> void:
	var card := _new_card()
	card.set_pose(Vector2(676, 370), 0.658, 0.0, 0.71, 4.0)
	var mat := _focus_material(card)
	assert_almost_eq(float(mat.get_shader_parameter("sigma_texels")), 4.0 / 0.658, 0.001)
	assert_almost_eq(float(mat.get_shader_parameter("brightness")), 0.71, 0.0001)


func test_a_half_focused_pose_is_halfway() -> void:
	var card := _new_card()
	card.set_pose(Vector2.ZERO, 0.5, 0.5, 0.71, 4.0)
	var mat := _focus_material(card)
	assert_almost_eq(float(mat.get_shader_parameter("brightness")), 0.855, 0.0001)
	assert_almost_eq(float(mat.get_shader_parameter("sigma_texels")), 4.0, 0.0001)
```

Also change the suite header's spec reference to `docs/superpowers/specs/2026-09-23-skin-select-slide-design.md`. If `assert_almost_eq` is not in `addons/godot_ai/testing/test_suite.gd` (grep for it), use `assert_true(absf(a - b) < tol, msg)` instead.

- [ ] **Step 2: Create the shader** `Scripts/Shaders/skin_card_focus.gdshader`:

```glsl
shader_type canvas_item;

// SkinSelect's per-card focus (spec
// docs/superpowers/specs/2026-09-23-skin-select-slide-design.md). Blurs and
// dims the card's OWN texture. blur.gdshader samples the screen instead,
// which on a card draws the background where the splash should be.
// SkinCard.set_pose drives both uniforms every frame the carousel moves.

// Gaussian sigma in texture pixels. 0 skips the blur entirely.
uniform float sigma_texels = 0.0;
// Multiplier on rgb: 1.0 untouched, the neighbour slot uses 0.71.
uniform float brightness = 1.0;

// Golden-angle spiral taps covering ~2 sigma. Enough for a sigma of
// 4-6 texels on two cards at a time.
const int TAPS = 32;
const float GOLDEN_ANGLE = 2.39996323;

void fragment() {
	vec4 c;
	if (sigma_texels < 0.05) {
		c = texture(TEXTURE, UV);
	} else {
		// Premultiplied, so transparent texels' colour never bleeds into
		// the silhouette.
		vec4 acc = vec4(0.0);
		float wsum = 0.0;
		for (int i = 0; i < TAPS; i++) {
			float r = sqrt((float(i) + 0.5) / float(TAPS)) * sigma_texels * 2.0;
			float a = float(i) * GOLDEN_ANGLE;
			vec2 off = vec2(cos(a), sin(a)) * r * TEXTURE_PIXEL_SIZE;
			float w = exp(-(r * r) / (2.0 * sigma_texels * sigma_texels));
			vec4 s = texture(TEXTURE, UV + off);
			acc += vec4(s.rgb * s.a, s.a) * w;
			wsum += w;
		}
		acc /= wsum;
		c = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
	}
	COLOR = vec4(c.rgb * brightness, c.a);
}
```

- [ ] **Step 3: Rewrite `Scenes/Skins/SkinCard.tscn`** (keep both existing uids):

```
[gd_scene format=3 uid="uid://ciq0pw7nx0ra6"]

[ext_resource type="Script" uid="uid://cu2gfvctamp47" path="res://Scripts/Skins/SkinCard.gd" id="1_1owxx"]
[ext_resource type="Texture2D" uid="uid://bsu4hxxxajoaa" path="res://Assets/Images/UI/Placeholders/icon_lock.svg" id="2_k647m"]
[ext_resource type="Shader" path="res://Scripts/Shaders/skin_card_focus.gdshader" id="3_focus"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_focus"]
resource_local_to_scene = true
shader = ExtResource("3_focus")
shader_parameter/sigma_texels = 0.0
shader_parameter/brightness = 1.0

[node name="SkinCard" type="Control" unique_id=1651751090]
custom_minimum_size = Vector2(1080, 1920)
layout_mode = 3
anchors_preset = 0
mouse_filter = 2
script = ExtResource("1_1owxx")

[node name="Art" type="TextureRect" parent="." unique_id=1253486339]
material = SubResource("ShaderMaterial_focus")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Lock" type="TextureRect" parent="." unique_id=2023295989]
visible = false
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -72.0
offset_top = -72.0
offset_right = 72.0
offset_bottom = 72.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("2_k647m")
expand_mode = 1
stretch_mode = 5
```

- [ ] **Step 4: Edit `Scripts/Skins/SkinCard.gd`.** Replace the file header's second paragraph (the "The card is 752x1337..." block) with:

```gdscript
## The card is the splash's own 1080x1920 canvas. SkinSelect poses it every
## frame the carousel moves (set_pose): position, scale, and a focus from 0
## (the neighbour slot: dimmed, blurred) to 1 (centred: crisp). The blur is
## skin_card_focus.gdshader on Art's local-to-scene material, so it blurs
## this card's own splash, not the screen behind it.
```

Delete `const BLUR_MATERIAL`, `@export var unselected_modulate` and `func set_selected`. Add, after `var skin_id`:

```gdscript
## The focus set_pose last applied, 0 (neighbour) to 1 (centred).
var focus: float = 1.0
```

and at the end of the file:

```gdscript
## Places and styles the card for one frame of the carousel. `origin` and
## `card_scale` are in the carousel's design pixels. `focus` runs from 0 (the
## neighbour slot) to 1 (centred). `side_brightness` and `side_blur_px` are
## the neighbour slot's look, and the blur is in SCREEN pixels, converted to
## texels here because the texture is drawn at `card_scale`.
func set_pose(origin: Vector2, card_scale: float, focus_amount: float,
		side_brightness: float, side_blur_px: float) -> void:
	focus = clampf(focus_amount, 0.0, 1.0)
	position = origin
	scale = Vector2(card_scale, card_scale)
	var mat := (get_node(^"Art") as TextureRect).material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter(&"brightness", lerpf(side_brightness, 1.0, focus))
	mat.set_shader_parameter(&"sigma_texels",
		(1.0 - focus) * side_blur_px / maxf(card_scale, 0.01))
```

- [ ] **Step 5: Delete the old material.**

```bash
git rm Scenes/Skins/skin_option_blur_material.tres
```

Then check that nothing else loads it (the only hits should be docs):

```bash
git grep -n "skin_option_blur_material" -- "*.gd" "*.tscn" "*.tres"
```

Expected: no output.

- [ ] **Step 6: Commit.**

```bash
git add Scripts/Shaders/skin_card_focus.gdshader Scenes/Skins/SkinCard.tscn Scripts/Skins/SkinCard.gd tests/test_skin_card.gd
git commit -F <msgfile>   # "feat(skins): blur and dim a skin card's own art from a pose"
```

- [ ] **Step 7 (controller): Verify.** Relaunch the worktree editor, then run `test_run(suite="skin_card", session_id=<wt>)`. Expected: all pass. Also run `script_documentation`. Suite `skin_select` is expected to fail until Task 2 lands, since it still calls `set_selected`.

---

### Task 2: SkinSelect poses cards from a continuous scroll

**Files:**
- Modify: `Scripts/Skins/SkinSelect.gd` (header note, new `@export`s, scroll state, replace `_apply_card_states`/`_pitch`/`_slide_to`/drag functions)
- Modify: `Scenes/Skins/SkinSelect.tscn` (`Track` node only)
- Test: `tests/test_skin_select.gd`

**Interfaces:**
- Consumes: `SkinCard.set_pose(origin, card_scale, focus, side_brightness, side_blur_px)`, `SkinCard.focus`, and `SkinCard.settle_index(current, travel, velocity, pitch, count)` (Task 1).
- Produces: `SkinSelect.card_pose(t: float) -> Dictionary` with keys `"position": Vector2`, `"scale": float` and `"focus": float`; also `SkinSelect.pitch_px() -> float`, `SkinSelect.scroll() -> float` and `SkinSelect.card_for(index: int) -> SkinCard`.

- [ ] **Step 1: Write the failing tests** in `tests/test_skin_select.gd` (append, and add the new spec path to the header):

```gdscript
## Measured off skinselection_mockup.png (spec 2026-09-23): the centred
## splash at 0.818 from (85,153), the right neighbour at 0.658 from (676,370).
func test_card_pose_hits_the_mockups_two_slots() -> void:
	var s := _new_screen()
	var c: Dictionary = s.card_pose(0.0)
	assert_true((c.position as Vector2).distance_to(Vector2(85, 153)) < 0.01, str(c.position))
	assert_almost_eq(float(c.scale), 0.818, 0.0001)
	assert_almost_eq(float(c.focus), 1.0, 0.0001)
	var r: Dictionary = s.card_pose(1.0)
	assert_true((r.position as Vector2).distance_to(Vector2(676, 370)) < 0.01, str(r.position))
	assert_almost_eq(float(r.scale), 0.658, 0.0001)
	assert_almost_eq(float(r.focus), 0.0, 0.0001)


## Position, scale and focus are all linear in |t| up to one card, so the
## halfway pose is the midpoint of the two slots.
func test_card_pose_is_the_midpoint_halfway() -> void:
	var s := _new_screen()
	var h: Dictionary = s.card_pose(0.5)
	assert_true((h.position as Vector2).distance_to(Vector2(380.5, 261.5)) < 0.01, str(h.position))
	assert_almost_eq(float(h.scale), 0.738, 0.0001)
	assert_almost_eq(float(h.focus), 0.5, 0.0001)


## The left neighbour mirrors the right one around the centred card's middle.
func test_the_left_neighbour_mirrors_the_right() -> void:
	var s := _new_screen()
	var mid := 85.0 + 1080.0 * 0.818 * 0.5
	var r: Dictionary = s.card_pose(1.0)
	var l: Dictionary = s.card_pose(-1.0)
	var r_cx: float = (r.position as Vector2).x + 1080.0 * float(r.scale) * 0.5
	var l_cx: float = (l.position as Vector2).x + 1080.0 * float(l.scale) * 0.5
	assert_almost_eq(mid - l_cx, r_cx - mid, 0.01)
	assert_eq((l.position as Vector2).y, (r.position as Vector2).y)
	assert_almost_eq(s.pitch_px(), 504.6, 0.01)


## The regression this pass exists for: with the first skin centred, the
## second must actually be on screen, dim and blurred.
func test_the_neighbour_is_on_screen_when_settled() -> void:
	var s := _new_screen()
	var centre := s.card_for(0)
	var side := s.card_for(1)
	assert_eq(centre.focus, 1.0)
	assert_eq(side.focus, 0.0)
	assert_true(side.position.x < 1080.0 - 150.0,
		"the neighbour must show a real slice of itself, got x=%s" % side.position.x)


## Focus follows the finger, not the selection: half a pitch of drag puts
## both cards at half focus before anything is released.
func test_dragging_half_a_pitch_half_focuses_both_cards() -> void:
	var s := _new_screen()
	s._begin_drag(700.0)
	s._update_drag(700.0 - s.pitch_px() * 0.5)
	assert_almost_eq(s.scroll(), 0.5, 0.0001)
	assert_almost_eq(s.card_for(0).focus, 0.5, 0.0001)
	assert_almost_eq(s.card_for(1).focus, 0.5, 0.0001)


func test_a_drag_past_the_end_stops_at_the_overscroll() -> void:
	var s := _new_screen()
	s._begin_drag(700.0)
	s._update_drag(700.0 + s.pitch_px() * 3.0)
	assert_almost_eq(s.scroll(), -s.overscroll, 0.0001)


## Settling snaps (no tween in the editor), and the selected card ends
## centred and crisp.
func test_select_skin_centres_that_card() -> void:
	var s := _new_screen()
	s.select_skin(1)
	assert_almost_eq(s.scroll(), 1.0, 0.0001)
	assert_true(s.card_for(1).position.distance_to(Vector2(85, 153)) < 0.01,
		str(s.card_for(1).position))
	assert_eq(s.card_for(1).focus, 1.0)


## The nearer card draws on top, so a neighbour never covers the centre.
func test_the_centred_card_draws_last() -> void:
	var s := _new_screen()
	var track := s.get_node("%Track")
	assert_eq(track.get_child(track.get_child_count() - 1), s.card_for(0))
	s.select_skin(1)
	assert_eq(track.get_child(track.get_child_count() - 1), s.card_for(1))


func test_track_is_a_plain_control_not_a_box() -> void:
	assert_eq(get_class_of_track(), "Control")


func get_class_of_track() -> String:
	var src := FileAccess.get_file_as_string(SCREEN)
	var at := src.find('[node name="Track"')
	return src.substr(at).get_slice('type="', 1).get_slice('"', 0)
```

(`_begin_drag`/`_update_drag` are "private" by convention only, and GDScript lets a test call them. The rest of this suite already drives real state the same way. Same `assert_almost_eq` fallback note as Task 1.)

- [ ] **Step 2: Replace the `Track` node in `Scenes/Skins/SkinSelect.tscn`** (drop the HBox, its separation override and `anchors_preset = 4`):

```
[node name="Track" type="Control" parent="Carousel" unique_id=791256449]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
```

- [ ] **Step 3: Edit `Scripts/Skins/SkinSelect.gd`.**

a) In the header, after the "Sliding the carousel records a PENDING choice..." paragraph, add:

```gdscript
## The carousel is posed, not laid out (spec
## docs/superpowers/specs/2026-09-23-skin-select-slide-design.md): one float,
## _scroll, says which card is centred (fractionally mid-drag), and
## card_pose() turns each card's distance from it into a position, scale
## and focus. That is what puts the neighbour on screen at the mockup's
## size, and what fades its dimming and blur with the finger instead of
## snapping them on selection.
```

b) Replace the `slide_time` export's neighbourhood with (keep `card_scene`, `fade_time` and `slide_time` as they are, then add):

```gdscript
## Top-left of the centred card, in design pixels. Fitted to
## skinselection_mockup.png.
@export var center_origin: Vector2 = Vector2(85, 153)
## Scale of the centred card's 1080x1920 splash.
@export var center_scale: float = 0.818
## Top-left of the card one step to the right. The left neighbour mirrors it
## around the centred card's middle.
@export var side_origin: Vector2 = Vector2(676, 370)
## Scale of a neighbouring card.
@export var side_scale: float = 0.658
## Brightness multiplier on a neighbouring card; 1.0 leaves it untouched.
@export_range(0.0, 1.0) var side_brightness: float = 0.71
## Gaussian blur sigma on a neighbouring card, in screen pixels.
@export var side_blur_px: float = 4.0
## How far a drag may pull past the first or last card, in cards.
@export var overscroll: float = 0.35

## Width of the splash canvas every card is drawn at before scaling.
const CARD_W := 1080.0
```

c) Replace the drag state block (`_drag_start_track_x` through `_release_velocity`) with:

```gdscript
## Which card is centred, in card units; fractional while dragging or
## settling. Every card's pose derives from it.
var _scroll: float = 0.0
## The open character's cards in skin order. Track's child order is draw
## order instead, which _layout_cards keeps nearest-last.
var _cards: Array[SkinCard] = []
## _scroll and the press's global x when the current drag began, so travel
## is measured against the press rather than the last motion event.
var _drag_start_scroll: float = 0.0
var _drag_start_x: float = 0.0
## The most recent drag sample and its time, for the release velocity.
var _last_x: float = 0.0
var _last_ms: int = 0
## Release speed in px/s, positive rightwards.
var _release_velocity: float = 0.0
```

d) In `select_skin`, delete the `_apply_card_states()` line. In `_rebuild_carousel`, replace the body from `for old in ...` to the end with:

```gdscript
	for old in _track.get_children():
		_track.remove_child(old)
		old.queue_free()
	_cards.clear()
	var who := current_student()
	var ids := StudentSkins.skins_for(who)
	var worn := pending_id(who)
	_skin_index = maxi(ids.find(worn), 0)
	for id in ids:
		var card: SkinCard = card_scene.instantiate()
		_track.add_child(card)
		card.show_skin(who, id, not GameState.is_skin_unlocked(who, id))
		_cards.append(card)
	_slide_to(_skin_index, false)
	_refresh_dots(ids.size())
	_refresh_tray()
```

e) Delete `_apply_card_states` and `_pitch`, then replace `_slide_to` with:

```gdscript
## Centre-to-centre distance between the centred slot and its neighbour, in
## design pixels: how far a finger travels to move one card. Derived from
## the two slots so moving either keeps the drag in step.
func pitch_px() -> float:
	return (side_origin.x + CARD_W * side_scale * 0.5) \
		- (center_origin.x + CARD_W * center_scale * 0.5)


## The pose of a card `t` cards from the centre (negative is left): top-left
## position, scale and focus. Linear in |t| up to one card, then it keeps
## sliding at the same pitch with the neighbour's scale and no focus.
func card_pose(t: float) -> Dictionary:
	var d := minf(absf(t), 1.0)
	var s := lerpf(center_scale, side_scale, d)
	var cx := center_origin.x + CARD_W * center_scale * 0.5 + pitch_px() * t
	var top := lerpf(center_origin.y, side_origin.y, d)
	return {"position": Vector2(cx - CARD_W * s * 0.5, top), "scale": s, "focus": 1.0 - d}


## Which card is centred, fractionally mid-drag.
func scroll() -> float:
	return _scroll


## The open character's card for skin `index`, or null.
func card_for(index: int) -> SkinCard:
	return _cards[index] if index >= 0 and index < _cards.size() else null


func _set_scroll(value: float) -> void:
	_scroll = value
	_layout_cards()


## Poses every card from _scroll and keeps the nearest one drawn last, so a
## neighbour never covers the centred card.
func _layout_cards() -> void:
	for i in _cards.size():
		var pose := card_pose(float(i) - _scroll)
		_cards[i].set_pose(pose.position, pose.scale, pose.focus,
			side_brightness, side_blur_px)
	var order: Array[SkinCard] = _cards.duplicate()
	order.sort_custom(func(a: SkinCard, b: SkinCard) -> bool:
		return absf(float(_cards.find(a)) - _scroll) > absf(float(_cards.find(b)) - _scroll))
	for k in order.size():
		_track.move_child(order[k], k)


## Moves _scroll to card `index`. Animated, it eases over slide_time and the
## cards' focus eases with it.
func _slide_to(index: int, animated: bool) -> void:
	if _cards.is_empty():
		return
	if is_instance_valid(_slide_tween) and _slide_tween.is_valid():
		_slide_tween.kill()
	if not animated or Engine.is_editor_hint() or not is_inside_tree():
		_set_scroll(float(index))
		return
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_set_scroll, _scroll, float(index), slide_time)
```

f) Replace `_begin_drag`, `_update_drag` and `_end_drag`, and in `_on_carousel_input` change `if _track.get_child_count() == 0:` to `if _cards.is_empty():`:

```gdscript
func _begin_drag(at_x: float) -> void:
	if is_instance_valid(_slide_tween) and _slide_tween.is_valid():
		_slide_tween.kill()
	_dragging = true
	_drag_start_scroll = _scroll
	_drag_start_x = at_x
	_last_x = at_x
	_last_ms = Time.get_ticks_msec()
	_release_velocity = 0.0


## The cards follow the finger one pitch per card, up to `overscroll` past
## either end.
func _update_drag(at_x: float) -> void:
	var raw := _drag_start_scroll - (at_x - _drag_start_x) / pitch_px()
	_set_scroll(clampf(raw, -overscroll, float(_cards.size() - 1) + overscroll))
	var now := Time.get_ticks_msec()
	var dt := float(now - _last_ms) / 1000.0
	if dt > 0.0:
		_release_velocity = (at_x - _last_x) / dt
	_last_x = at_x
	_last_ms = now


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	select_skin(SkinCard.settle_index(_skin_index, _last_x - _drag_start_x,
		_release_velocity, pitch_px(), _cards.size()))
```

Finally, confirm that nothing still references the removed names:

```bash
git grep -n "set_selected\|_apply_card_states\|_pitch()\|_drag_start_track_x" -- Scripts tests
```

Expected: no output.

- [ ] **Step 4: Commit.**

```bash
git add Scripts/Skins/SkinSelect.gd Scenes/Skins/SkinSelect.tscn tests/test_skin_select.gd
git commit -F <msgfile>   # "feat(skins): pose the carousel from one scroll value so focus follows the finger"
```

- [ ] **Step 5 (controller): Verify.** Relaunch the worktree editor, then run `test_run(suite="skin_select")`, `skin_card` and `script_documentation`. Expected: all pass, **except** the Task 3/4 layout assertions, which do not exist yet.

---

### Task 3: Tray, tile, button and title styles in ThemeFactory

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd:42-114` (`_build_skin_select` and consts above it)
- Test: `tests/test_theme_factory.gd:369` (`DISPLAY_ROSTER`), `tests/test_student_tile.gd:79-92`, and a new check in `tests/test_skin_select.gd`

**Interfaces:**
- Produces the theme variations `SkinTray` (Panel), `SkinApplyButton` (Button) and `SkinTitleLabel` (Label). It also restyles `SkinStudentTile` / `SkinStudentTileActive`. Task 4's scene uses these names.

- [ ] **Step 1: Write the failing tests.** In `tests/test_student_tile.gd`, change `test_variations_differ_in_ring_colour`'s idle assertion from `tokens.text_primary` to `Color.BLACK`, and add:

```gdscript
## Measured off skinselection_mockup.png: an 8px black rim on the tray's
## cream, with no fill of its own.
func test_idle_tile_is_an_8px_black_rim_with_no_fill() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var idle := theme.get_stylebox("normal", "SkinStudentTile") as StyleBoxFlat
	assert_eq(idle.border_width_top, 8)
	assert_eq(idle.bg_color.a, 0.0)
```

In `tests/test_skin_select.gd` add:

```gdscript
func test_mockup_styles_exist_with_measured_values() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var tray := theme.get_stylebox("panel", "SkinTray") as StyleBoxFlat
	assert_true(tray != null, "SkinTray must be a StyleBoxFlat panel")
	if tray != null:
		assert_eq(tray.bg_color, tokens.surface_card)
		assert_eq(tray.border_width_top, 8)
		assert_eq(tray.border_width_bottom, 0)
		assert_eq(tray.border_color, Color.BLACK)
	var btn := theme.get_stylebox("normal", "SkinApplyButton") as StyleBoxFlat
	assert_true(btn != null, "SkinApplyButton must be a StyleBoxFlat button")
	if btn != null:
		assert_eq(btn.bg_color, Color("D21919"))
		assert_eq(btn.border_width_left, 8)
		assert_eq(btn.corner_radius_top_left, tokens.radius_button)
	assert_eq(theme.get_color("font_color", "SkinApplyButton"), Color("F2F2F2"))
	assert_eq(theme.get_font_size("font_size", "SkinApplyButton"), 73)
	assert_eq(theme.get_color("font_color", "SkinTitleLabel"), Color("F2F2F2"))
	assert_eq(theme.get_color("font_outline_color", "SkinTitleLabel"), Color("201934"))
	assert_eq(theme.get_font_size("font_size", "SkinTitleLabel"), 74)
```

In `tests/test_theme_factory.gd` line 369, extend the SkinSelect roster line to:

```gdscript
	"SkinNameLabel", "SkinWornChipLabel", "SkinApplyButton", "SkinTitleLabel",
```

- [ ] **Step 2: Implement in `Scripts/Design/ThemeFactory.gd`.** Directly above `static func _build_skin_select`, add:

```gdscript
## Measured off skinselection_mockup.png (spec
## docs/superpowers/specs/2026-09-23-skin-select-slide-design.md). The ink
## the mockup draws its divider, tiles and button rim in, the rim's width,
## the button's red and text, and the title's colours and sizes. No token
## matches; these are single-screen values, like EVENT_DIALOGUE_RADIUS.
const SKIN_INK := Color("000000")
const SKIN_RIM := 8
const SKIN_APPLY_FILL := Color("D21919")
const SKIN_APPLY_TEXT := Color("F2F2F2")
## Boohong size whose cap height is the mockup's 60px.
const SKIN_APPLY_FONT := 73
const SKIN_TITLE_FILL := Color("F2F2F2")
const SKIN_TITLE_OUTLINE := Color("201934")
## Boohong size whose cap height is the mockup's 61px.
const SKIN_TITLE_FONT := 74
## Godot outline_size for the title's ~13px stroke. Task 5 checks it
## against the mockup's outer box (348,95)-(718,182).
const SKIN_TITLE_OUTLINE_SIZE := 26
```

In `_build_skin_select`: change the `square` lambda's `box.set_border_width_all(int(tokens.outline_width))` to `box.set_border_width_all(SKIN_RIM)`. Change the idle tile call to `square.call(Color(0, 0, 0, 0), SKIN_INK)`. The active tile stays `square.call(tokens.outline_card, tokens.brand_primary)`. Then append, at the end of the function:

```gdscript
	# The tray under the carousel: cream with the mockup's black divider as
	# its top border, so the line moves with the tray on tall phones.
	theme.add_type("SkinTray")
	theme.set_type_variation("SkinTray", "Panel")
	var tray := StyleBoxFlat.new()
	tray.bg_color = tokens.surface_card
	tray.border_color = SKIN_INK
	tray.border_width_top = SKIN_RIM
	theme.set_stylebox("panel", "SkinTray", tray)

	# TERAPKAN in the mockup's flat red with a black rim. Flat, not
	# _add_button_variation's gradient, because the mockup draws it flat.
	# radius_button keeps it inside tests/test_button_geometry.gd.
	var apply_box := func(fill: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = SKIN_INK
		box.set_border_width_all(SKIN_RIM)
		box.set_corner_radius_all(tokens.radius_button)
		return box
	theme.add_type("SkinApplyButton")
	theme.set_type_variation("SkinApplyButton", "Button")
	theme.set_stylebox("normal", "SkinApplyButton", apply_box.call(SKIN_APPLY_FILL))
	theme.set_stylebox("hover", "SkinApplyButton", apply_box.call(SKIN_APPLY_FILL.lightened(0.08)))
	theme.set_stylebox("pressed", "SkinApplyButton", apply_box.call(SKIN_APPLY_FILL.darkened(0.15)))
	theme.set_stylebox("focus", "SkinApplyButton", apply_box.call(SKIN_APPLY_FILL))
	theme.set_stylebox("disabled", "SkinApplyButton",
		apply_box.call(SKIN_APPLY_FILL.lerp(tokens.surface_sunken, 0.7)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(key, "SkinApplyButton", SKIN_APPLY_TEXT)
	theme.set_color("font_disabled_color", "SkinApplyButton", tokens.text_disabled)
	theme.set_font_size("font_size", "SkinApplyButton", SKIN_APPLY_FONT)
	if tokens.font_display != null:
		theme.set_font("font", "SkinApplyButton", tokens.font_display)

	# The character's name over the carousel: the mockup's white Boohong
	# with a navy stroke, smaller than DisplayLabel.
	theme.add_type("SkinTitleLabel")
	theme.set_type_variation("SkinTitleLabel", "Label")
	theme.set_font_size("font_size", "SkinTitleLabel", SKIN_TITLE_FONT)
	theme.set_color("font_color", "SkinTitleLabel", SKIN_TITLE_FILL)
	theme.set_color("font_outline_color", "SkinTitleLabel", SKIN_TITLE_OUTLINE)
	theme.set_constant("outline_size", "SkinTitleLabel", SKIN_TITLE_OUTLINE_SIZE)
	if tokens.font_display != null:
		theme.set_font("font", "SkinTitleLabel", tokens.font_display)
```

Update `_build_skin_select`'s `##` header to list the three new variations and point at the 2026-09-23 spec.

- [ ] **Step 3: Commit** (no rebake here, since the controller rebakes in Task 5):

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_student_tile.gd tests/test_theme_factory.gd tests/test_skin_select.gd
git commit -F <msgfile>   # "feat(theme): add the skin tray, apply button and title styles from the mockup"
```

- [ ] **Step 4 (controller): Verify.** Relaunch, then run `student_tile`, `theme_factory`, `button_geometry` and the `skin_select` test `test_mockup_styles_exist_with_measured_values`. These build the theme in-process, so they need no rebake.

---

### Task 4: Lay the tray and title out to the mockup

**Files:**
- Modify: `Scenes/Skins/SkinSelect.tscn` (Carousel, Title, Dots, Tray, Rail, SkinName, WornChip moved to root, BackButton, Terapkan)
- Modify: `Scenes/Skins/StudentTile.tscn:7`
- Test: `tests/test_skin_select.gd`, `tests/test_student_tile.gd:59-67`, `tests/test_button_geometry.gd:171-177`

**Interfaces:**
- Consumes the variations `SkinTray`, `SkinApplyButton`, `SkinTitleLabel` and `SkinStudentTile` (Task 3).
- `%WornChip` keeps its unique name, so `SkinSelect.gd` needs no change.

- [ ] **Step 1: Update the tests.**

In `tests/test_skin_select.gd`:
- Replace `test_commit_button_is_indonesian_and_not_danger_red`'s PrimaryButton assertion (and its doc comment) with `assert_true(src.contains('theme_type_variation = &"SkinApplyButton"'), "the mockup's red button")`. Keep both TERAPKAN/APPLY assertions.
- In `test_the_carousel_stretches_to_the_trays_top_edge`, change `offset_bottom = -583.0` to `offset_bottom = -592.0` and update its comment: the tray's top (and the divider) is at y=1328.
- Append:

```gdscript
func _node_block(src: String, name: String) -> String:
	var at := src.find('[node name="%s"' % name)
	if at == -1:
		return ""
	var next := src.find("[node", at + 1)
	return src.substr(at, (next - at) if next != -1 else src.length() - at)


## Every offset is measured off skinselection_mockup.png; the tray's own
## origin is y=1328 on a 1920-tall screen.
func test_tray_is_laid_out_to_the_mockup() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	var tray := _node_block(src, "Tray")
	assert_true(tray.contains("offset_top = -592.0"), "divider at y=1328")
	assert_true(tray.contains('theme_type_variation = &"SkinTray"'))
	var rail := _node_block(src, "Rail")
	assert_true(rail.contains("offset_top = 102.0") and rail.contains("offset_bottom = 258.0"),
		"tiles at y 1430-1586")
	var back := _node_block(src, "BackButton")
	for v in ["offset_left = 40.0", "offset_top = 349.0", "offset_right = 237.0", "offset_bottom = 524.0"]:
		assert_true(back.contains(v), "BackButton " + v)
	var btn := _node_block(src, "Terapkan")
	for v in ["offset_left = 501.0", "offset_top = 381.0", "offset_right = 1007.0", "offset_bottom = 521.0"]:
		assert_true(btn.contains(v), "Terapkan " + v)


func test_title_uses_the_mockup_title_style() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(_node_block(src, "Title").contains('theme_type_variation = &"SkinTitleLabel"'))


## The mockup has no room in the tray for the worn chip, so it sits under
## the title instead.
func test_worn_chip_sits_under_the_title() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains('[node name="WornChip" type="PanelContainer" parent="."'))
```

In `tests/test_student_tile.gd`, replace `test_tile_is_on_the_button_size_scale` (and its comment) with:

```gdscript
## 151x156, measured off skinselection_mockup.png. Off the S/M/L scale on
## purpose: the user asked for a pixel copy (2026-09-23), so the tile has a
## reasoned HEIGHT_ALLOWED entry in tests/test_button_geometry.gd.
func test_tile_is_the_mockups_size() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains("custom_minimum_size = Vector2(151, 156)"))
```

In `tests/test_button_geometry.gd`, add to `HEIGHT_ALLOWED` (keep the existing comments):

```gdscript
	"Scenes/Skins/StudentTile.tscn::StudentTile":
		"151x156, a pixel copy of skinselection_mockup.png (user request 2026-09-23)",
	"Scenes/Skins/SkinSelect.tscn::Tray/Terapkan":
		"140 tall, a pixel copy of skinselection_mockup.png (user request 2026-09-23)",
```

Check the key format against `_check_node`: the key is `path::parent/name`, with `res://` stripped. The root node has parent `""`, so its key is just its name.

- [ ] **Step 2: Edit `Scenes/Skins/StudentTile.tscn`** line 7 to `custom_minimum_size = Vector2(151, 156)`.

- [ ] **Step 3: Edit `Scenes/Skins/SkinSelect.tscn`** (keep every `unique_id`):

- `Carousel`: `offset_bottom = -592.0`.
- `Title`: `theme_type_variation = &"SkinTitleLabel"`; offsets top 80 / bottom 200 unchanged.
- Move the `WornChip` and `WornChipLabel` blocks from `Tray` to the root, placed right after `Title` (and `WornChipLabel`'s parent becomes `"WornChip"`). WornChip: `parent="."`, `anchors_preset = 5`, `anchor_left = 0.5`, `anchor_right = 0.5`, `offset_top = 200.0`, `offset_bottom = 248.0`, `grow_horizontal = 2`, and keep the rest as-is.
- `Dots`: `offset_top = -644.0`, `offset_bottom = -620.0` (y 1276-1300).
- `Tray`: `offset_top = -592.0`, `theme_type_variation = &"SkinTray"`.
- `Rail`: `offset_top = 102.0`, `offset_bottom = 258.0`, `theme_override_constants/separation = 22`. The six 151-wide tiles plus five 22px gaps are 1016 wide, centred at x 32-1048 against the mockup's 35-1049; even gaps were the user's choice.
- `SkinName`: `offset_top = 270.0`, `offset_bottom = 322.0` (y 1598-1650).
- `BackButton`: `offset_left = 40.0`, `offset_top = 349.0`, `offset_right = 237.0`, `offset_bottom = 524.0`.
- `Terapkan`: `offset_left = 501.0`, `offset_top = 381.0`, `offset_right = 1007.0`, `offset_bottom = 521.0`, `theme_type_variation = &"SkinApplyButton"`.

- [ ] **Step 4: Commit.**

```bash
git add Scenes/Skins/SkinSelect.tscn Scenes/Skins/StudentTile.tscn tests/test_skin_select.gd tests/test_student_tile.gd tests/test_button_geometry.gd
git commit -F <msgfile>   # "feat(skins): lay the skin tray and title out to the mockup"
```

- [ ] **Step 5 (controller): Verify.** Relaunch, then run `skin_select`, `skin_card`, `student_tile`, `button_geometry`, `tall_screen_layout`, `viewport_editability`, `script_documentation` and `lobby_skins`. Expected: all pass.

---

### Task 5 (controller): Rebake, measure against the mockup, document, full run

**Files:**
- Modify: `Assets/Theme/kejartes_theme.tres` (rebake)
- Maybe modify: `Scripts/Design/ThemeFactory.gd` (`SKIN_TITLE_OUTLINE_SIZE` only)
- Modify: `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Rebake alone.** In a freshly launched worktree editor, run `test_run(suite="theme_rebake")` and nothing else in that call. Quit the editor. Check `git diff --stat Assets/Theme/kejartes_theme.tres`: it should add the new variations and restyle the tiles, with no unrelated stylebox churn (see memory "rebake, then restart before saving"). Relaunch.

- [ ] **Step 2: Measure pixels, not a screenshot.** Run the game from the worktree editor. Seed through the debug overlay (General > Seed Playtest State), teleport to Lobby, and open SkinSelect via the Lobby's skin button (`skin_switch.png`). Then, in ONE `game_eval`: set `Engine.time_scale = 0.02`, open Shinta, capture `get_viewport().get_texture().get_image()` and save it to the scratchpad. Compare it against `C:/Users/user/Downloads/skinselection_mockup.png` with a Python script.
  - Region y 1328-1920 (the tray): the tiles, divider, back arrow and button box must land within 3px of the mockup's measured boxes (tiles within 3px because of the even gaps).
  - Title outer dark box ≈ (348,95)-(718,182). If the height is off by more than 4px, adjust `SKIN_TITLE_OUTLINE_SIZE` (stroke) or `SKIN_TITLE_FONT` (cap). Then rebake again (Step 1) and re-measure.
  - Splash placement: fit the settled centre card with the same `fit2.py` method used in brainstorming. It must land at scale 0.818 ±0.004 from (85,153) ±3px, with the neighbour at 0.658 from (676,370) ±3px. Background pixels differ (live Lobby vs the mockup's room), so compare only the splash's opaque pixels.
  - Mid-drag: call `_begin_drag(700)` and `_update_drag(700 - pitch_px()*0.5)` in the same `game_eval`, capture again, and confirm both figures are visible and equally soft.
  Send the settled capture and the mid-drag capture to the user with `SendUserFile`.

- [ ] **Step 3: Docs.** In `docs/superpowers/DEBT.md`, delete the two sentences starting "The carousel's neighbour card peeks only 104px" from the "SkinSelect's skin names are derived" entry, and keep the rest of that entry. In `docs/superpowers/CHANGELOG.md`, add at the top, following that file's format, an entry for 2026-09-23. It covers: the two-splash carousel, focus following the finger, the screen-blur bug, and the tray and title redrawn to the mockup with the two HEIGHT_ALLOWED entries.

- [ ] **Step 4: Full run.** Run `test_run()` (full) in the worktree editor. Budget one restart, since the bridge drops after a full run. Fix any real failure; re-run a lone theme failure on its own before believing it (suite order). Then revert the side-effect files: `Assets/Audio/default_bus_layout.tres` and any `*.png.import` that only lost `etc2_astc`. Revert them **after** the editor has exited.

- [ ] **Step 5: Commit.**

```bash
git status --short
git add Assets/Theme/kejartes_theme.tres Scripts/Design/ThemeFactory.gd docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md
git commit -F <msgfile>   # "chore(theme): rebake for the skin select styles; docs for the pass"
```

- [ ] **Step 6:** Quit the worktree editor. Hand the branch to the `ship-pr` skill when the user asks to ship.
