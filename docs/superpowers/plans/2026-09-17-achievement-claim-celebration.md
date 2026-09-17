# Achievement Claim Celebration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reset achievements on every launch (a debug switch), a blurred claim celebration with glowing rays and confetti, and a white outline on every achievement icon.

**Architecture:** One const switch in the `Achievements` autoload. Two canvas_item
shaders: an additive ray glow, and an alpha-following outline. One authored
popup scene that the Achievements screen instances on a successful claim.
Three new label variations in ThemeFactory.

**Tech Stack:** Godot 4.6 GDScript and shaders, McpTestSuite through the worktree editor's session.

## Global Constraints

- No `theme_override_*` except layout constants; new looks are ThemeFactory variations, then rebake.
- No runtime visual construction; the popup is a `.tscn` instanced from an `@export PackedScene`.
- A `##` header on every script and a `##` line on every `@export`.
- Suites are `@tool`, none of their tests is a coroutine, and each overrides `suite_name()`.
- UI text is Indonesian; no emoji. `Balance.gd` is untouched.
- The worktree editor is closed while `.tscn` files are hand-written; it is relaunched before tests.
- Code blocks headed `<!-- file: path -->` are complete file contents.

---

### Task 1: Reset achievements on launch

**Files:** Modify `Scripts/Achievements/Achievements.gd`. Test: `tests/test_achievements.gd`.

- [ ] Append the tests:

```gdscript
func test_debug_reset_on_launch_is_on() -> void:
	assert_true(ACHIEVEMENTS.RESET_ON_LAUNCH, "debug: every launch starts with no achievement progress")
	var src := FileAccess.get_file_as_string("res://Scripts/Achievements/Achievements.gd")
	assert_true(src.contains("if RESET_ON_LAUNCH:\n\t\treset()"), "_ready resets instead of loading")
```

- [ ] Run: `test_run(suite="achievements")`. Expected: FAIL (`RESET_ON_LAUNCH` missing).
- [ ] Add, below `SAVE_PATH`:

```gdscript
## DEBUG (2026-09-17): wipe all achievement progress on every launch, so each
## play session starts fresh. Set false to keep progress between launches.
const RESET_ON_LAUNCH := true
```

  In `_ready()`, replace `load_progress()` with:

```gdscript
	if RESET_ON_LAUNCH:
		reset()
	else:
		load_progress()
```

- [ ] Run: `test_run(suite="achievements")`. Expected: PASS.
- [ ] Commit `feat(achievements): reset progress on every launch (debug switch)`.

### Task 2: Icon outline shader on every achievement icon

**Files:** Create `Scripts/Shaders/icon_outline.gdshader` and `Assets/Images/Achievements/icon_outline_material.tres`. Modify `Scenes/Achievements/AchievementRow.tscn` and `Scenes/Achievements/AchievementToast.tscn` (a `material` on `Icon`). Test: `tests/test_achievement_screen.gd`.

- [ ] Append the tests:

```gdscript
const OUTLINE_MATERIAL := "res://Assets/Images/Achievements/icon_outline_material.tres"


func test_outline_material_is_white() -> void:
	var mat := load(OUTLINE_MATERIAL) as ShaderMaterial
	assert_true(mat != null and mat.shader != null)
	assert_true(mat.shader.code.contains("outline_width"))
	assert_eq(mat.get_shader_parameter("outline_color"), Color.WHITE)
	assert_gt(float(mat.get_shader_parameter("outline_width")), 0.0)


func test_card_and_banner_icons_wear_the_outline() -> void:
	for pair in [[ROW, "HBox/Icon"], ["res://Scenes/Achievements/AchievementToast.tscn", "Banner/Icon"]]:
		var root := (load(pair[0]) as PackedScene).instantiate()
		track(root)
		var icon := root.get_node(pair[1]) as TextureRect
		assert_true(icon.material != null and icon.material.resource_path == OUTLINE_MATERIAL,
			"%s's icon must use the shared outline material" % pair[0])
```

- [ ] Run: `test_run(suite="achievement_screen")`. Expected: FAIL.
- [ ] Write the shader and the material, and add the material to both `Icon` nodes.

<!-- file: Scripts/Shaders/icon_outline.gdshader -->
```glsl
shader_type canvas_item;

// Draws a texture shrunk inside its rect by `outline_width` (a share of the
// rect), with a solid `outline_color` ring that follows the art's alpha --
// so rounded icon corners get a rounded outline. Used by
// icon_outline_material.tres on every achievement icon.

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.2) = 0.03;

const int DIRECTIONS = 16;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	float shrink = 1.0 - 2.0 * outline_width;
	vec2 uv = (UV - 0.5) / shrink + 0.5;
	vec4 art = vec4(0.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		art = texture(TEXTURE, uv);
	}
	float reach = outline_width / shrink;
	float ring = 0.0;
	for (int i = 0; i < DIRECTIONS; i++) {
		float a = TAU * float(i) / float(DIRECTIONS);
		vec2 dir = vec2(cos(a), sin(a));
		ring = max(ring, alpha_at(TEXTURE, uv + dir * reach));
		ring = max(ring, alpha_at(TEXTURE, uv + dir * reach * 0.5));
	}
	vec3 rgb = mix(outline_color.rgb, art.rgb, art.a);
	float alpha = max(art.a, ring * outline_color.a);
	COLOR = vec4(rgb, alpha) * v_modulate;
}
```

<!-- file: Assets/Images/Achievements/icon_outline_material.tres -->
```ini
[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://Scripts/Shaders/icon_outline.gdshader" id="1_outline"]

[resource]
shader = ExtResource("1_outline")
shader_parameter/outline_color = Color(1, 1, 1, 1)
shader_parameter/outline_width = 0.03
```

- [ ] Run: `test_run(suite="achievement_screen")`. Expected: PASS.
- [ ] Commit `feat(achievements): white outline on achievement icons`.

### Task 3: Claim popup theme variations

**Files:** Modify `Scripts/Design/ThemeFactory.gd` (inside `_build_achievements`) and `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`, adding `AchievementClaimHeadlineLabel` and `AchievementClaimTitleLabel`). Rebake. Test: `tests/test_achievement_claim_popup.gd` (new, Task 4).

```gdscript
const ACHIEVEMENT_CLAIM_HEADLINE_SIZE := 88
const ACHIEVEMENT_CLAIM_TITLE_SIZE := 76
const ACHIEVEMENT_CLAIM_HINT_SIZE := 52
const ACHIEVEMENT_CLAIM_OUTLINE := 22
```

`AchievementClaimHeadlineLabel` and `AchievementClaimTitleLabel` are Labels
with the display font, a `Color.WHITE` fill, `outline_size`
`ACHIEVEMENT_CLAIM_OUTLINE` and `font_outline_color` `tokens.event_warning_ink`.
`AchievementClaimHintLabel` is a Label with the body font at size 52 and a
white fill.

- [ ] Write the variation test (in the Task 4 suite). Run: FAIL. Implement, rebake, run `achievement_claim_popup` and `theme_factory`: PASS. Commit `feat(theme): claim celebration label variations`.

### Task 4: The claim popup with glow and confetti

**Files:** Create `Scripts/Shaders/achievement_glow.gdshader`, `Scenes/Achievements/AchievementClaimPopup.tscn` and `Scripts/Achievements/AchievementClaimPopup.gd`. Modify `Scripts/Achievements/achievements_screen.gd`. Test: `tests/test_achievement_claim_popup.gd`.

<!-- file: tests/test_achievement_claim_popup.gd -->
```gdscript
@tool
extends McpTestSuite

## The claim celebration (spec:
## docs/superpowers/specs/2026-09-17-achievement-claim-celebration-design.md):
## its authored scene, its shaders and theme variations, and the screen that
## opens it.

const POPUP := "res://Scenes/Achievements/AchievementClaimPopup.tscn"


func suite_name() -> String:
	return "achievement_claim_popup"


func _popup() -> Control:
	var p := (load(POPUP) as PackedScene).instantiate() as Control
	track(p)
	return p


func test_scene_contract() -> void:
	var p := _popup()
	assert_eq(p.mouse_filter, Control.MOUSE_FILTER_STOP, "a tap anywhere reaches the popup")
	var blur := p.get_node("Blur") as ColorRect
	assert_eq(blur.material.resource_path, "res://Scenes/Koperasi/shop_hub_blur_material.tres")
	var glow := p.get_node("Safe/UI/Glow") as ColorRect
	assert_true((glow.material as ShaderMaterial).shader.resource_path.ends_with("achievement_glow.gdshader"))
	var icon := p.get_node("Safe/UI/Icon") as TextureRect
	assert_eq(icon.material.resource_path, "res://Assets/Images/Achievements/icon_outline_material.tres")
	assert_eq((p.get_node("Safe/UI/Headline") as Label).text, "SELAMAT, ANDA MENDAPATKAN")
	assert_eq((p.get_node("Safe/UI/Headline") as Label).theme_type_variation, &"AchievementClaimHeadlineLabel")
	assert_eq((p.get_node("Safe/UI/Title") as Label).theme_type_variation, &"AchievementClaimTitleLabel")
	var hint := p.get_node("Safe/UI/Hint") as Label
	assert_eq(hint.text, "tekan dimana saja untuk menutup")
	assert_eq(hint.anchor_top, 1.0, "the hint rides the bottom edge")
	assert_true(p.get_node("Confetti") is RewardParticles)


func test_open_fills_icon_and_title() -> void:
	var p := _popup()
	p.icon = p.get_node("Safe/UI/Icon")
	p.title_label = p.get_node("Safe/UI/Title")
	p.content = p.get_node("Safe/UI")
	p.confetti = p.get_node("Confetti")
	p.open(AchievementCatalog.get_entry("three_star_akademis"))
	assert_eq(p.title_label.text, "Cap-cip-cup kembang kuncup!")
	assert_eq(p.icon.texture.resource_path, AchievementCatalog.icon_path("three_star_akademis"))


func test_glow_shader_is_additive_and_animated() -> void:
	var code := (load("res://Scripts/Shaders/achievement_glow.gdshader") as Shader).code
	assert_true(code.contains("blend_add"))
	assert_true(code.contains("TIME"))
	assert_true(code.contains("ray_count"))


func test_factory_builds_the_claim_labels() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	for name in ["AchievementClaimHeadlineLabel", "AchievementClaimTitleLabel"]:
		assert_eq(theme.get_type_variation_base(name), &"Label")
		assert_eq(theme.get_color("font_outline_color", name), t.event_warning_ink)
		assert_gt(theme.get_constant("outline_size", name), 0)
		assert_eq(theme.get_font("font", name), t.font_display)
	assert_eq(theme.get_type_variation_base("AchievementClaimHintLabel"), &"Label")


func test_screen_opens_the_popup_on_claim() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Achievements/achievements_screen.gd")
	assert_true(src.contains("claim_popup_scene.instantiate()"))
	assert_true(src.contains(".open(AchievementCatalog.get_entry(id))"))
```

- [ ] Run: `test_run(suite="achievement_claim_popup")`. Expected: FAIL (scene missing).
- [ ] Write the shader, scene and script below, then patch `achievements_screen.gd`: add
  `## The celebration shown after a successful claim.` and
  `@export var claim_popup_scene: PackedScene = preload("res://Scenes/Achievements/AchievementClaimPopup.tscn")`,
  and at the end of `_on_claim_pressed`:

```gdscript
	var popup := claim_popup_scene.instantiate()
	add_child(popup)
	popup.open(AchievementCatalog.get_entry(id))
```

<!-- file: Scripts/Shaders/achievement_glow.gdshader -->
```glsl
shader_type canvas_item;
render_mode blend_add;

// The light behind a claimed achievement's icon: a pulsing soft core and two
// layers of light shafts rotating in opposite directions, each shaft
// flickering on its own noise. Additive, so it only ever brightens what lies
// behind it. Drawn on a square ColorRect centred on the icon.

uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int ray_count = 14;
uniform float rotate_speed = 0.18;
uniform float flicker_speed = 1.4;
uniform float core_size : hint_range(0.05, 1.0) = 0.42;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

float rays(vec2 p, float dist, float turn, float count, float sharpness) {
	float sector = (atan(p.y, p.x) + turn) / TAU * count;
	float across = abs(fract(sector) - 0.5) * 2.0;
	float flicker = 0.5 + 0.5 * noise1(TIME * flicker_speed + floor(sector) * 7.13);
	return pow(1.0 - across, sharpness) * flicker * smoothstep(1.0, 0.2, dist);
}

void fragment() {
	vec2 p = UV - 0.5;
	float dist = length(p) * 2.0;
	float count = float(ray_count);
	float shafts = rays(p, dist, TIME * rotate_speed, count, 5.0)
		+ 0.6 * rays(p, dist, -TIME * rotate_speed * 0.6, count * 0.5, 9.0);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.2);
	float core = exp(-pow(dist / core_size, 2.0)) * pulse;
	float a = clamp(shafts * 0.5 + core, 0.0, 1.0) * intensity * glow_color.a;
	COLOR = vec4(glow_color.rgb, a) * vec4(1.0, 1.0, 1.0, v_modulate.a);
}
```

<!-- file: Scripts/Achievements/AchievementClaimPopup.gd -->
```gdscript
@tool
extends Control

## The celebration shown when the player claims an achievement
## (AchievementClaimPopup.tscn; reference: achievementclaim_mockup.png). A
## blurred screen, "SELAMAT, ANDA MENDAPATKAN", the icon large over animated
## light rays, the achievement's title, and paper confetti. Opened by
## achievements_screen.gd with open(); any tap after a short lock closes it,
## and it frees itself. @tool so the test runner can call open().

signal closed

## Seconds a tap is ignored after opening, so the Klaim tap cannot close it.
@export var input_lock_time: float = 0.4
## Seconds the content takes to fade in.
@export var fade_in_time: float = 0.25
## Seconds the popup takes to fade out once tapped.
@export var fade_out_time: float = 0.2

@onready var icon: TextureRect = $Safe/UI/Icon
@onready var title_label: Label = $Safe/UI/Title
@onready var content: Control = $Safe/UI
@onready var confetti: RewardParticles = $Confetti

var _accepting: bool = false
var _closing: bool = false


## Shows catalog entry `entry` and plays the entrance.
func open(entry: Dictionary) -> void:
	icon.texture = load(AchievementCatalog.icon_path(entry.id))
	title_label.text = entry.title
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	content.modulate.a = 0.0
	create_tween().tween_property(content, "modulate:a", 1.0, fade_in_time)
	Juice.pop_in(icon)
	AudioDirector.play_sfx(&"tap")
	confetti.fire()
	get_tree().create_timer(input_lock_time).timeout.connect(func() -> void: _accepting = true)


func _gui_input(event: InputEvent) -> void:
	if not _accepting or _closing:
		return
	var pressed := (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		close()


## Fades the popup out, emits `closed` and frees it.
func close() -> void:
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_out_time)
	tw.finished.connect(func() -> void:
		closed.emit()
		queue_free())
```

<!-- file: Scenes/Achievements/AchievementClaimPopup.tscn -->
```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Achievements/AchievementClaimPopup.gd" id="1_popup"]
[ext_resource type="Material" path="res://Scenes/Koperasi/shop_hub_blur_material.tres" id="2_blur"]
[ext_resource type="Script" path="res://Scripts/UI/SafeAreaMargin.gd" id="3_safe"]
[ext_resource type="Shader" path="res://Scripts/Shaders/achievement_glow.gdshader" id="4_glow"]
[ext_resource type="Material" path="res://Assets/Images/Achievements/icon_outline_material.tres" id="5_outline"]
[ext_resource type="Texture2D" path="res://Assets/Images/Achievements/Icons/three_star_akademis.png" id="6_icon"]
[ext_resource type="PackedScene" path="res://Scenes/SchoolSimulation/PaperConfetti.tscn" id="7_confetti"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_glow"]
shader = ExtResource("4_glow")
shader_parameter/glow_color = Color(1, 0.86, 0.45, 1)
shader_parameter/intensity = 1.0
shader_parameter/ray_count = 14
shader_parameter/rotate_speed = 0.18
shader_parameter/flicker_speed = 1.4
shader_parameter/core_size = 0.42

[node name="AchievementClaimPopup" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_popup")

[node name="Blur" type="ColorRect" parent="."]
material = ExtResource("2_blur")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Safe" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("3_safe")

[node name="UI" type="Control" parent="Safe"]
layout_mode = 2
mouse_filter = 2

[node name="Headline" type="Label" parent="Safe/UI"]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -480.0
offset_top = 192.0
offset_right = 480.0
offset_bottom = 402.0
grow_horizontal = 2
theme_type_variation = &"AchievementClaimHeadlineLabel"
text = "SELAMAT, ANDA MENDAPATKAN"
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3

[node name="Glow" type="ColorRect" parent="Safe/UI"]
material = SubResource("ShaderMaterial_glow")
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -550.0
offset_top = -715.0
offset_right = 550.0
offset_bottom = 385.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Icon" type="TextureRect" parent="Safe/UI"]
material = ExtResource("5_outline")
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -270.0
offset_top = -435.0
offset_right = 270.0
offset_bottom = 105.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("6_icon")
expand_mode = 1
stretch_mode = 5

[node name="Title" type="Label" parent="Safe/UI"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -480.0
offset_top = 230.0
offset_right = 480.0
offset_bottom = 460.0
grow_horizontal = 2
grow_vertical = 2
theme_type_variation = &"AchievementClaimTitleLabel"
text = "Cap-cip-cup kembang kuncup!"
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3

[node name="Hint" type="Label" parent="Safe/UI"]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -270.0
offset_bottom = -190.0
grow_horizontal = 2
grow_vertical = 0
theme_type_variation = &"AchievementClaimHintLabel"
text = "tekan dimana saja untuk menutup"
horizontal_alignment = 1

[node name="Confetti" parent="." instance=ExtResource("7_confetti")]
z_index = 100
position = Vector2(-40, 1780)
```

(Top- and bottom-anchored offsets are measured from `Safe`'s 48 px inset edges; centre-anchored ones are unaffected, since the inset is symmetric.)

- [ ] Run: `test_run(suite="achievement_claim_popup")`, `achievement_screen`, `achievements`. Expected: PASS.
- [ ] In the game: claim an unlocked achievement and screenshot the popup at full size. Check the blur, the rays moving, the outline and the confetti.
- [ ] Commit `feat(achievements): claim celebration with glow rays and confetti`.

### Task 5: Docs and the full suite

- [ ] Add a CHANGELOG entry. Add a DEBT entry: "RESET_ON_LAUNCH is on for debugging; turn it off before release." CLAUDE.md's persistence line notes the switch.
- [ ] Run: full `test_run`. Expected: all pass. Revert editor noise (`default_bus_layout.tres`, the portrait `.import` files).
- [ ] Commit.
