@tool
extends McpTestSuite

## The Lobby's split-tone grade (2026-10-01): deeper, still-warm shadows and
## cream highlights, after the owner's key-art reference, on the Lobby only until
## it has been tuned there and is carried to the rest of the game.
##
## Design: docs/superpowers/specs/2026-10-01-lobby-split-tone-design.md
##
## Must be @tool, and no test here may be a coroutine. The Lobby is
## instanced once, out of the tree, in suite_setup: a big scene per test
## floods the message queue in a full run (CLAUDE.md).

const SHADER := "res://Scripts/Shaders/illustration_grade.gdshader"
const LOBBY_SCENE := "res://Scenes/Lobby/Lobby.tscn"
## The Lobby's three split-tone materials: backdrop, desks, faces (and, with
## the faces, the hands and desk items).
const LOBBY_PLAIN := "res://Scripts/Shaders/illustration_grade_material_lobby.tres"
const LOBBY_CUTOUT := "res://Scripts/Shaders/illustration_grade_cutout_lobby.tres"
const FACE := "res://Scripts/Shaders/illustration_grade_face.tres"
const LOBBY_MATERIALS := [LOBBY_PLAIN, LOBBY_CUTOUT, FACE]
## The game's shared grades, which leave split-tone off until the spread pass.
const SHARED_MATERIALS := [
	"res://Scripts/Shaders/illustration_grade_material.tres",
	"res://Scripts/Shaders/illustration_grade_cutout.tres",
	"res://Scripts/Shaders/illustration_grade_splash.tres",
]
const PLAIN := "res://Scripts/Shaders/illustration_grade_material.tres"
const SPLIT_UNIFORMS := [
	"shadow_tone", "highlight_tone", "split_balance", "split_strength", "shadow_saturation",
]
## The two containers that hold every student's arms and desk items.
const HAND_CONTAINERS := [
	"World/Classroom/StudentHandsContainer_Back",
	"World/Classroom/StudentHandsContainer_Front",
]
## Four slots, six students, an arms node and an items node each.
const HAND_AND_ITEM_PLATES := 48

var _lobby: Node


func suite_name() -> String:
	return "lobby_split_tone"


func suite_setup(_ctx: Dictionary) -> void:
	_lobby = (load(LOBBY_SCENE) as PackedScene).instantiate()


func suite_teardown() -> void:
	if is_instance_valid(_lobby):
		_lobby.free()


## A material that never sets a uniform reports null for it, not the shader's
## default; split-tone's off value is 0.
func _strength_or_zero(mat: ShaderMaterial) -> float:
	var value: Variant = mat.get_shader_parameter("split_strength")
	return 0.0 if value == null else float(value)


## The Lobby's three materials carry one split-tone between them. Tune one
## from the Look page and write it into only that .tres, and the students
## would lean a different colour from the room they sit in.
func test_the_lobby_materials_agree_on_split_tone() -> void:
	var first: ShaderMaterial = load(LOBBY_MATERIALS[0])
	assert_true(first != null, "%s must exist" % LOBBY_MATERIALS[0])
	if first == null:
		return
	assert_gt(_strength_or_zero(first), 0.0, "the Lobby's split-tone must be on")
	for path: String in LOBBY_MATERIALS:
		var mat: ShaderMaterial = load(path)
		assert_true(mat != null, "%s must exist" % path)
		if mat == null:
			continue
		for uniform: String in SPLIT_UNIFORMS:
			assert_eq(str(mat.get_shader_parameter(uniform)), str(first.get_shader_parameter(uniform)),
				"%s: %s must match %s" % [path, uniform, LOBBY_MATERIALS[0]])


## The lean (2026-10-01): the owner kept the deeper darks of the plum pass
## ("the contrast is better now") but asked for the earlier warmth back, so the
## darks stay warm (blue under red), deepened only by shadow_saturation, and
## the highlights lean cream. Any tuned value inside that holds.
func test_the_lean_is_warm_shadows_and_cream_highlights() -> void:
	var mat: ShaderMaterial = load(LOBBY_PLAIN)
	assert_true(mat != null, "the Lobby backdrop material must exist")
	if mat == null:
		return
	var shadow: Color = mat.get_shader_parameter("shadow_tone")
	var highlight: Color = mat.get_shader_parameter("highlight_tone")
	assert_true(shadow.r > shadow.b,
		"shadows stay warm (blue under red), not %s" % shadow)
	assert_true(highlight.r > highlight.b,
		"highlights lean cream (blue under red), not %s" % highlight)
	assert_true(float(mat.get_shader_parameter("shadow_saturation")) < 1.0,
		"the darks are pulled part-way toward grey: that is what deepens them against the "
			+ "lights (owner, 2026-10-01: 'the contrast is better now')")


## Lobby only, until the spread pass relaxes this on purpose.
func test_the_shared_materials_leave_split_tone_off() -> void:
	for path: String in SHARED_MATERIALS:
		var mat: ShaderMaterial = load(path)
		assert_true(mat != null, "%s must exist" % path)
		if mat == null:
			continue
		assert_true(is_zero_approx(_strength_or_zero(mat)),
			"%s: split-tone is the Lobby's until it is tuned there" % path)


## The shader's own defaults are off and white, so a material that never
## mentions split-tone renders exactly as it did before.
func test_the_shader_defaults_are_off() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_contains(src, "uniform float split_strength : hint_range(0.0, 1.0) = 0.0;")
	assert_contains(src, "uniform vec4 shadow_tone : source_color = vec4(1.0, 1.0, 1.0, 1.0);")
	assert_contains(src, "uniform vec4 highlight_tone : source_color = vec4(1.0, 1.0, 1.0, 1.0);")
	assert_contains(src, "uniform float shadow_saturation : hint_range(0.0, 1.0) = 1.0;")


## Split-tone moves hue and never brightness: each pixel is scaled back to
## its own luma. This scan pins the rule; it does not prove the arithmetic,
## which was measured on the running Lobby when the pass landed. And it costs
## nothing where it is off: the branch is on a uniform.
func test_split_tone_keeps_brightness_and_is_free_when_off() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_contains(src, "toned *= l / max(dot(toned, LUMA), 1e-4);",
		"the toned pixel must be rescaled to its own luma")
	assert_contains(src, "if (split_strength > 0.0) {",
		"plates that leave split-tone off must skip it")
	assert_contains(src, "vec3 base = max(rgb, vec3(0.0));",
		"clamp before the rescale: contrast leaves near-black channels under zero, and dividing "
			+ "near-zero lumas turned black hair grey (2026-10-01)")
	assert_contains(src, "float l = dot(base, LUMA);", "the luma comes from the clamped colour")
	assert_contains(src, "base = mix(vec3(l), base, mix(shadow_saturation, 1.0, t));",
		"the darks desaturate toward their own luma, which keeps brightness")


## The Lobby's backdrop material is the shared backdrop plus split-tone,
## nothing else: same five grade values, AO and rim still off.
func test_the_lobby_backdrop_is_the_plain_grade_plus_split_tone() -> void:
	var plain: ShaderMaterial = load(PLAIN)
	var lobby: ShaderMaterial = load(LOBBY_PLAIN)
	assert_true(plain != null and lobby != null, "both backdrop materials must exist")
	if plain == null or lobby == null:
		return
	for uniform: String in ["saturation", "contrast", "exposure", "tint", "amount"]:
		assert_eq(str(lobby.get_shader_parameter(uniform)), str(plain.get_shader_parameter(uniform)),
			"%s must match the shared backdrop" % uniform)
	assert_true(is_zero_approx(float(lobby.get_shader_parameter("ao_strength"))),
		"a full-bleed backdrop has no edge for AO")
	assert_true(is_zero_approx(float(lobby.get_shader_parameter("rim_strength"))),
		"a full-bleed backdrop has no edge for a rim")


func test_the_backdrop_wears_the_lobby_backdrop_material() -> void:
	var bg := _lobby.get_node_or_null("World/Classroom/BGLayer") as CanvasItem
	assert_true(bg != null, "the Lobby is missing BGLayer")
	if bg == null:
		return
	assert_eq(bg.material, load(LOBBY_PLAIN), "BGLayer must wear the Lobby's own backdrop grade")


## Every arms and desk-item plate wears the face grade, so a hand matches the
## face beside it. Walked from the containers rather than listed, so a new
## student or slot cannot slip through ungraded; the count keeps the walk
## from passing on an empty tree.
func test_every_hand_and_item_wears_the_face_material() -> void:
	var face: Material = load(FACE)
	var seen := 0
	for container_path: String in HAND_CONTAINERS:
		var container := _lobby.get_node_or_null(container_path)
		assert_true(container != null, "the Lobby is missing %s" % container_path)
		if container == null:
			continue
		for plate: Node in container.find_children("*", "TextureRect", true, false):
			if not (plate.name.begins_with("Hand_") or plate.name.begins_with("Items_")):
				continue
			seen += 1
			assert_eq((plate as CanvasItem).material, face,
				"%s/%s must wear the face grade" % [container_path, container.get_path_to(plate)])
	assert_eq(seen, HAND_AND_ITEM_PLATES, "every slot's arms and items, for all six students")


## The Look page drives all three Lobby materials.
func test_the_look_page_tunes_split_tone() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugLookPanel.gd")
	assert_contains(src, "_build_split_tone_section(vbox)", "the Look page builds the block")
	for path: String in LOBBY_MATERIALS:
		assert_contains(src, path, "the Look page drives %s" % path)
