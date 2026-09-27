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
const MAIN_MENU := "res://Scenes/MainMenu/MainMenu.tscn"

var _sandbox: SubViewport
var _tint: MoodTint
var _pool: LightPool
var _particles: AmbientParticles
var _glow: AmbientGlow
var _desk: DeskAmbience
## The developer's own switches, read before this suite touches either one,
## so teardown() can put them back instead of guessing true/false.
var _snapshot_ambient_enabled: bool = true
## As above, for Kurangi Gerakan.
var _snapshot_reduce_motion: bool = false


func suite_name() -> String:
	return "ambient_kit"


func suite_setup(_ctx: Dictionary) -> void:
	_snapshot_ambient_enabled = GameSettings.ambient_effects_enabled
	_snapshot_reduce_motion = GameSettings.reduce_motion
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


## The suite flips the real autoload's switches; put them back after each test
## to whatever the developer had them set to, not a guessed true/false.
func teardown() -> void:
	GameSettings.ambient_effects_enabled = _snapshot_ambient_enabled
	GameSettings.reduce_motion = _snapshot_reduce_motion


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


## Past MAX_RAYS_REACH a shaft would still be bright at the Pool rect's edge
## and stop there in a straight line instead of fading inside it.
func test_the_rays_reach_clamps_inside_the_pool() -> void:
	_pool.rays_reach = 1.4
	assert_eq(_pool.rays_reach, LightPool.MAX_RAYS_REACH, "reach clamps to MAX_RAYS_REACH")
	assert_eq(float(_rays_mat().get_shader_parameter("reach")), LightPool.MAX_RAYS_REACH,
		"and the rays material gets the clamped value")
	_pool.rays_reach = 0.5


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
	GameSettings.ambient_effects_enabled = true
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
	GameSettings.ambient_effects_enabled = true
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
		var re := RegEx.new()
		re.compile("uniform\\s+\\w+\\s+" + knob + "\\b")
		assert_true(re.search(src) != null, "glint.gdshader needs the `%s` uniform" % knob)
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
	GameSettings.ambient_effects_enabled = true
	GameSettings.reduce_motion = false
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
## (the game's light direction), and dust in it.
func test_the_desk_recipe() -> void:
	var tint := _desk.get_node("Tint") as MoodTint
	var lamp := _desk.get_node("Lamp") as LightPool
	var dust := _desk.get_node("Dust") as AmbientParticles
	assert_true(tint != null and lamp != null and dust != null,
		"DeskAmbience holds Tint, Lamp and Dust")
	if tint == null or lamp == null or dust == null:
		return
	assert_eq(tint.mood, MoodTint.Mood.PAGI, "the desk wears the morning")
	assert_true(lamp.center.x < 0.5 and lamp.center.y < 0.5, "the lamp sits upper left")
	assert_eq(dust.preset, AmbientParticles.Preset.DEBU, "dust drifts in the lamp light")
	assert_true(tint.get_index() < lamp.get_index() and lamp.get_index() < dust.get_index(),
		"tint, then light, then particles")
	assert_true(_desk.get_node_or_null("Glow") == null, "no bloom on the desk: spec amendment 7")


## Overrides on an instance's children do not survive a save, so the one
## per-screen knob lives on the root and is written through.
func test_the_root_knobs_reach_the_children() -> void:
	_desk.particle_density = 0.5
	assert_eq((_desk.get_node("Dust") as AmbientParticles).density, 0.5, "density reaches Dust")
	_desk.particle_density = 1.0
	assert_eq(_anchors(_desk), Vector4(0, 0, 1, 1), "DeskAmbience is Full Rect")


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


## A world screen: `World` is a CanvasLayer at -1 holding the backdrop and
## only kit instances; nothing tappable sits in it; no bloom is placed --
## spec amendment 7.
func _assert_world_screen(scene_path: String, backdrop: String) -> void:
	var census := _census(scene_path)
	var world := _entry(census, "World")
	assert_eq(world.get("type"), "CanvasLayer", scene_path + ": World must be a CanvasLayer")
	assert_eq(_prop(world, "layer"), -1, scene_path + ": World draws at -1, below the UI")
	assert_eq(_children_of(census, "World").find(backdrop), 0,
		scene_path + ": the backdrop is the first thing World draws")
	var blooms := 0
	for e in census:
		var p: String = e["path"]
		if e["instance"] == AMBIENT_GLOW:
			blooms += 1
		if not p.begins_with("World/"):
			continue
		assert_false(BUTTON_TYPES.has(e["type"]), "%s: %s is tappable and must stay on layer 0" % [scene_path, p])
		if e["instance"] != "":
			assert_true(KIT_SCENES.has(e["instance"]),
				"%s: only kit pieces are instanced inside World (%s)" % [scene_path, p])
	assert_eq(blooms, 0, scene_path + ": no AmbientGlow is placed (spec amendment 7)")


# ── MainMenu ─────────────────────────────────────────────────────────────────

func test_main_menu_is_a_world_screen() -> void:
	_assert_world_screen(MAIN_MENU, "Background")


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
	assert_true(_entry(c, "Glow").is_empty(), "no bloom on the menu: spec amendment 7")


func test_main_menu_finds_its_logo_by_unique_name() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/MainMenu/MainMenu.gd")
	assert_true(src.contains("= %Logo") and src.contains("= %LogoShadow"),
		"the logo moved into World; MainMenu.gd must find it by unique name")


# ── The desk screens ─────────────────────────────────────────────────────────

const DESK_SCREENS := [
	"res://Scenes/LevelSelect/LevelSelect.tscn",
	"res://Scenes/StudentCard/StudentCard.tscn",
	"res://Scenes/StudentList/StudentList.tscn",
	"res://Scenes/ReportCard/ReportCard.tscn",
]


func test_every_desk_screen_is_a_world_screen() -> void:
	for path in DESK_SCREENS:
		_assert_world_screen(path, "Backdrop")


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


# ── CutScene and the exam screens (layer 0, no bloom: amendment 1) ──────────

func test_cutscene_gets_a_soft_sun_and_sparkles() -> void:
	var c := _census("res://Scenes/CutScene/CutScene.tscn")
	var kids := _children_of(c, ".")
	assert_eq(kids[0], "BgCutScene", "the picture is still the first thing drawn")
	assert_eq(kids[1], "DialogueBox", "DialogueBox still follows it")
	assert_eq(_children_of(c, "BgCutScene"), ["Sun", "Sparkles"] as Array[String],
		"they ride the picture, so its fades take them too")
	assert_eq(_entry(c, "BgCutScene/Sun").get("instance"), LIGHT_POOL, "Sun is a LightPool")
	assert_eq(_prop(_entry(c, "BgCutScene/Sparkles"), "preset"), AmbientParticles.Preset.KILAU, "sparkles, not dust")
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
	assert_true(src.contains("shown.modulate.a = 0.0"), "the shown mood starts transparent")
	assert_true(src.contains("tween_property(shown, \"modulate:a\", 1.0, Juice.tokens().dur_slow)"),
		"and fades in, so it never pops on EndCutscene's invisible scene swap")
