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
