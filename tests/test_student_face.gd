@tool
extends McpTestSuite

## The lobby's layered student face (StudentFace + Scenes/Lobby/CitraFace.tscn),
## which replaces the single flat portrait TextureRect for students that have
## multi-layer art.
##
## The art ships as six separately-cropped PNGs with no canvas offsets of their
## own, so every layer position in the rig was solved rather than eyeballed:
## each crop was matched back onto the flattened Assets/Images/MuridPotrait/
## Citra.png, and Sclera/Eyelid were pinned exactly by the transparent eye
## cut-outs in citra_base.png, which they plug to the pixel. _GEOMETRY below
## freezes that solve -- if someone nudges a layer in the viewport, this suite
## says so.
##
## The one correction worth remembering: citra_eyebrows.png was originally
## delivered as "citra_eyelashes_closed" and first wired as the lower half of a
## blink. It is the eyebrows, it is always visible, and it is the topmost layer
## because the base has hair (not brows) beneath it.
##
## Blink is deliberately inert. The Eyelid layer is in the rig and blink()
## works, but idle_blink_enabled defaults false, so nothing closes the eyes on
## its own yet; two tests below pin both halves of that.
##
## Technique notes, per this project's runner:
##  * This suite must be @tool or the runner reports the class abstract.
##  * No test may be a coroutine -- the runner calls suite.call(name) without
##    awaiting. StudentFace exposes advance_motion() precisely so the idle
##    motion can be stepped synchronously instead of waiting on frames.
##  * StudentFace IS @tool, so instantiating the rig here runs its _ready();
##    it disables _process under Engine.is_editor_hint(), which is why the
##    tests drive advance_motion() by hand.
##  * setup() runs per test and track() frees the rig afterwards, so every
##    test below starts from a fresh, untouched face.

const _RIG_PATH := "res://Scenes/Lobby/CitraFace.tscn"
const _SHADER_PATH := "res://Scripts/Shaders/eye_mask.gdshader"
const _LOBBY_SCRIPT := "res://Scripts/Lobby/loby.gd"
const _ART_DIR := "res://Assets/Images/MuridPotrait/Citra"

## Layer nodes under Canvas, back to front. Order here is draw order: the
## eyebrows are last because they sit over the fringe.
const _LAYERS: Array[String] = [
	"Base", "Sclera", "Pupil", "Eyelashes", "Eyelid", "Eyebrows",
]

## Solved canvas-pixel placement per layer: [position, size]. See the header
## for how these were derived; they are art facts, not preferences.
const _GEOMETRY: Array = [
	["Base", Vector2(0, 0), Vector2(1280, 1280)],
	["Sclera", Vector2(427, 578), Vector2(426, 95)],
	["Pupil", Vector2(476, 571), Vector2(328, 99)],
	["Eyelashes", Vector2(391, 534), Vector2(498, 93)],
	["Eyelid", Vector2(419, 578), Vector2(442, 106)],
	["Eyebrows", Vector2(447, 499), Vector2(384, 26)],
]

## One PNG per layer, named after the layer it feeds.
const _ART_FILES: Array[String] = [
	"citra_base", "citra_sclera", "citra_pupil",
	"citra_eyelashes", "citra_eyelid", "citra_eyebrows",
]


func suite_name() -> String:
	return "student_face"


var _face: StudentFace


func setup() -> void:
	var scene: PackedScene = load(_RIG_PATH)
	_face = scene.instantiate() as StudentFace
	Engine.get_main_loop().root.add_child(_face)
	track(_face)


func _layer(layer_name: String) -> TextureRect:
	return _face.get_node_or_null(NodePath("Canvas/" + layer_name)) as TextureRect


func test_the_rig_stacks_its_six_layers_back_to_front() -> void:
	var canvas := _face.get_node_or_null(^"Canvas") as Control
	assert_not_null(canvas, "the rig needs a Canvas node holding the layers")
	var found: Array[String] = []
	for child in canvas.get_children():
		found.append(str(child.name))
	assert_eq(", ".join(found), ", ".join(_LAYERS),
		"layer draw order is the art's order and must not be reshuffled")


func test_every_layer_is_a_texture_rect_carrying_citra_art() -> void:
	for layer_name in _LAYERS:
		var node := _layer(layer_name)
		assert_not_null(node, layer_name + " must exist as a TextureRect")
		assert_not_null(node.texture, layer_name + " must carry a texture")
		assert_contains(node.texture.resource_path, _ART_DIR,
			layer_name + " must draw from the Citra layer folder")


func test_each_layer_sits_at_its_solved_canvas_offset() -> void:
	for entry in _GEOMETRY:
		var layer_name: String = entry[0]
		var node := _layer(layer_name)
		assert_not_null(node, layer_name + " must exist")
		assert_true(node.position.is_equal_approx(entry[1]),
			"%s moved off its solved position: %s, expected %s"
				% [layer_name, node.position, entry[1]])
		assert_true(node.size.is_equal_approx(entry[2]),
			"%s is no longer drawn at its native size: %s, expected %s"
				% [layer_name, node.size, entry[2]])


func test_the_eyelid_is_the_only_layer_that_starts_hidden() -> void:
	assert_false(_layer("Eyelid").visible,
		"the eyelid is the blink pose and must start lifted")
	for layer_name in _LAYERS:
		if layer_name == "Eyelid":
			continue
		assert_true(_layer(layer_name).visible,
			layer_name + " is part of the resting face and must be visible")


func test_the_eyebrows_are_permanent_not_half_of_a_blink() -> void:
	# The eyebrow art arrived named "citra_eyelashes_closed" and was first
	# wired as a closed-lash layer. Pin the correction so it cannot regress.
	var brows := _layer("Eyebrows")
	assert_true(brows.visible, "eyebrows are always on")
	_face.blink()
	assert_true(brows.visible, "a blink must not take the eyebrows with it")
	# FileAccess, not ResourceLoader: a deleted texture lingers in the editor's
	# import cache for the rest of the session and ResourceLoader still says
	# yes. Ask the filesystem.
	assert_false(FileAccess.file_exists(_ART_DIR + "/citra_eyelashes_closed.png"),
		"the mislabelled export should be gone, renamed to citra_eyebrows.png")


func test_every_citra_layer_asset_is_present() -> void:
	for file_name in _ART_FILES:
		var path := "%s/%s.png" % [_ART_DIR, file_name]
		assert_true(ResourceLoader.exists(path), "missing layer art: " + path)


func test_the_canvas_is_scaled_to_fit_the_slot_and_centred_in_it() -> void:
	# Matches the flat portrait's STRETCH_KEEP_ASPECT_CENTERED, so swapping a
	# rig in for a portrait does not shift the diorama.
	_face.size = Vector2(500.0, 640.0)
	_face.fit_canvas()
	var canvas := _face.get_node(^"Canvas") as Control
	assert_true(canvas.size.is_equal_approx(Vector2(1280.0, 1280.0)),
		"the canvas keeps its art-pixel size; only its scale changes")
	assert_true(absf(canvas.scale.x - 0.390625) < 0.0001,
		"canvas should scale to the tighter axis, got %f" % canvas.scale.x)
	assert_eq(canvas.scale.x, canvas.scale.y, "the fit must stay uniform")
	assert_true(canvas.position.is_equal_approx(Vector2(0.0, 70.0)),
		"leftover space belongs on both sides, got %s" % canvas.position)


func test_the_pupil_is_clipped_to_the_eye_white_by_the_mask_shader() -> void:
	var pupil := _layer("Pupil")
	var mat := pupil.material as ShaderMaterial
	assert_not_null(mat, "the pupil needs the eye-mask material to be clippable")
	assert_not_null(mat.shader, "the material needs its shader")
	assert_eq(mat.shader.resource_path, _SHADER_PATH,
		"the pupil must use the eye-mask shader")
	var mask: Texture2D = mat.get_shader_parameter("mask_texture")
	assert_not_null(mask, "the shader needs a mask texture")
	assert_contains(mask.resource_path, "citra_sclera",
		"the eye white is what defines where the iris may draw")


func test_each_rig_instance_gets_its_own_mask_material() -> void:
	# Four seats share one .tscn. Without resource_local_to_scene the four
	# faces would write the same uniforms and every pupil would follow the
	# last one to move.
	var mat := (_layer("Pupil").material as ShaderMaterial)
	assert_true(mat.resource_local_to_scene,
		"the eye-mask material must be local to the scene")
	var other := (load(_RIG_PATH) as PackedScene).instantiate() as StudentFace
	Engine.get_main_loop().root.add_child(other)
	track(other)
	var other_mat := ((other.get_node(^"Canvas/Pupil") as TextureRect).material as ShaderMaterial)
	assert_ne(mat.get_instance_id(), other_mat.get_instance_id(),
		"two rigs must not share one material instance")


func test_a_gaze_offset_moves_the_pupil_and_re_aims_the_mask() -> void:
	var pupil := _layer("Pupil")
	var sclera := _layer("Sclera")
	var rest := pupil.position
	_face.apply_gaze(Vector2(12.0, -4.0))
	assert_true(pupil.position.is_equal_approx(rest + Vector2(12.0, -4.0)),
		"apply_gaze moves the pupil from its authored rest position")
	var mat := pupil.material as ShaderMaterial
	var expected_offset: Vector2 = (pupil.position - sclera.position) / sclera.size
	var actual_offset: Vector2 = mat.get_shader_parameter("mask_uv_offset")
	assert_true(actual_offset.is_equal_approx(expected_offset),
		"the clip must follow the pupil: got %s, expected %s"
			% [actual_offset, expected_offset])
	var actual_scale: Vector2 = mat.get_shader_parameter("mask_uv_scale")
	assert_true(actual_scale.is_equal_approx(pupil.size / sclera.size),
		"mask_uv_scale is the pupil/sclera size ratio, got %s" % actual_scale)


func test_idle_gaze_wanders_but_never_leaves_its_configured_ellipse() -> void:
	var worst := 0.0
	for _i in range(4000):
		_face.advance_motion(0.016)
		var g := _face.get_gaze()
		var radius := Vector2(g.x / _face.gaze_range.x, g.y / _face.gaze_range.y).length()
		worst = maxf(worst, radius)
	assert_gt(worst, 0.0, "idle gaze never moved the pupil at all")
	assert_true(worst <= 1.0001,
		"gaze escaped gaze_range (worst normalised radius %f)" % worst)


func test_the_gaze_can_be_frozen() -> void:
	_face.idle_gaze_enabled = false
	for _i in range(600):
		_face.advance_motion(0.05)
	assert_true(_face.get_gaze().is_equal_approx(Vector2.ZERO),
		"with idle_gaze_enabled off the pupil must stay at rest")


func test_a_blink_closes_the_eye_and_lifts_again() -> void:
	var eyelid := _layer("Eyelid")
	assert_false(eyelid.visible, "eyes start open")
	_face.blink()
	assert_true(eyelid.visible, "blink() lowers the lid")
	_face.advance_motion(_face.blink_close_seconds + 0.01)
	assert_false(eyelid.visible, "the lid lifts once blink_close_seconds elapses")


func test_idle_blinking_is_wired_in_but_switched_off() -> void:
	# The eyelid layer is present and blink() works; nothing drives it yet.
	assert_false(_face.idle_blink_enabled,
		"idle blinking stays off until the blink pass is actually done")
	var eyelid := _layer("Eyelid")
	for _i in range(2000):
		_face.advance_motion(0.05)
		if eyelid.visible:
			break
	assert_false(eyelid.visible,
		"nothing may close the eyes across 100s while idle blinking is off")


func test_switching_idle_blinking_on_makes_the_eye_blink() -> void:
	_face.idle_blink_enabled = true
	var eyelid := _layer("Eyelid")
	var blinked := false
	for _i in range(4000):
		_face.advance_motion(0.016)
		if eyelid.visible:
			blinked = true
			break
	_face.idle_blink_enabled = false
	_face.set_eyes_closed(false)
	assert_true(blinked, "with idle blinking on the eyes must close within ~64s")


func test_the_rig_announces_which_student_it_belongs_to() -> void:
	assert_eq(_face.student_name, "Citra",
		"the rig owns its roster name; the lobby only reads it")


func test_the_rigs_student_name_is_readable_without_instantiating_it() -> void:
	# This is exactly how loby.gd._rig_student_name() matches a rig to a seat,
	# so the mechanism is worth pinning independently of the export default.
	var state := (load(_RIG_PATH) as PackedScene).get_state()
	assert_gt(state.get_node_count(), 0, "the rig scene must have a root node")
	var found := ""
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == &"student_name":
			found = str(state.get_node_property_value(0, i))
	assert_eq(found, "Citra", "student_name must be saved on the rig's root")


func test_the_lobby_swaps_a_face_rig_in_for_the_flat_portrait() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	assert_contains(src, "@export var face_rigs: Array[PackedScene]",
		"the lobby exposes its rigs in the Inspector")
	assert_contains(src, _RIG_PATH,
		"an empty face_rigs must still fall back to Citra's rig")
	assert_contains(src, "_acquire_face(p_slot",
		"each roster slot asks for a rig by student name")
	assert_contains(src, "_match_rect(face, portrait_node)",
		"a rig must inherit the flat portrait's rect so layout is unchanged")
	assert_contains(src, "_animate_breathing(face, breathing_delay)",
		"a layered face breathes exactly like the portrait it replaces")
