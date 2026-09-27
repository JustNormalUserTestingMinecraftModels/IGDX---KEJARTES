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
const LIGHT_POOL := "res://Scenes/Look/LightPool.tscn"
const AMBIENT_PARTICLES := "res://Scenes/Look/AmbientParticles.tscn"
const AMBIENT_GLOW := "res://Scenes/Look/AmbientGlow.tscn"
const GLINT_MATERIAL := "res://Scripts/Shaders/glint_material.tres"
const DESK_AMBIENCE := "res://Scenes/Look/DeskAmbience.tscn"

var _sandbox: SubViewport
var _tint: MoodTint
var _pool: LightPool
var _particles: AmbientParticles
var _glow: AmbientGlow
var _desk: DeskAmbience


func suite_name() -> String:
	return "ambient_kit"


func suite_setup(_ctx: Dictionary) -> void:
	_sandbox = SubViewport.new()
	_sandbox.own_world_3d = true
	_sandbox.size = Vector2i(1080, 1920)
	_sandbox.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Engine.get_main_loop().root.add_child(_sandbox)
	_tint = _stand(MOOD_TINT) as MoodTint
	_pool = _stand(LIGHT_POOL) as LightPool
	_particles = _stand(AMBIENT_PARTICLES) as AmbientParticles
	_glow = _stand(AMBIENT_GLOW) as AmbientGlow
	_desk = _stand(DESK_AMBIENCE) as DeskAmbience


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
	for path in ["res://Scripts/Look/MoodTint.gd", "res://Scripts/Look/LightPool.gd", "res://Scripts/Look/AmbientParticles.gd", "res://Scripts/Look/DeskAmbience.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("AmbientKit.fill_parent(self)"),
			path + " must re-fill its parent in _ready")
		if not path.ends_with("DeskAmbience.gd"):
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
	_particles.offset_bottom = 480.0
	_particles.call("_fit")
	assert_eq(_emitter().position, Vector2(540, 1200), "the emitter sits at the centre")
	assert_eq(_emitter().emission_rect_extents, Vector2(540, 1200), "and spans the whole rect")
	_particles.offset_bottom = 0.0
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
