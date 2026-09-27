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
