@tool
extends McpTestSuiteCompat

## Layered lobby faces (StudentFace) for the rest of the roster: Andi, Doni,
## Marcel, Shinta and Thea. Citra's rig predates them and keeps its own suite,
## tests/test_student_face.gd, which also covers the shared StudentFace motion.
##
## Where the numbers come from. The art arrives as separately-cropped PNGs
## with no canvas offsets, numbered 1-7 on the Drive. Every placement below
## was solved against that student's flat MuridPotrait/<Name>.png, not
## eyeballed (docs/superpowers/specs/2026-09-14-student-face-rigs-design.md):
##  * Sclera and Eyelid are pinned where they plug the base's transparent eye
##    cut-outs. They are never nudged to "fit the portrait better": a 1 px
##    nudge leaves a rim of cut-out open and the lobby shows through the eye.
##  * Pupil, Eyelashes and Eyebrows are placed by evidence -- the pixels each
##    layer changes must agree with the portrait -- inside a window near the
##    eyes, because a dark stroke otherwise "matches" anywhere in dark hair.
##  * Shinta's portrait is a darker grade of her base, so her matching ran
##    through a per-channel recolour fitted base -> portrait.
##
## The Drive numbering was NOT the stated Base, Sclera, Pupil, Eyelashes,
## Eyelid, Eyebrows order for every student: file 4 is the closed eyelid and
## 5 the lashes for all five, and 2/3 are pupil/sclera for everyone but Andi.
## The art decided; the file names on disk follow the art.
##
## Marcel's glasses draw through Scripts/Shaders/glasses_lens.gdshader: the
## frame is opaque and the lens adds light, which is how his portrait was
## flattened. A plain alpha mix greys his eyes.
##
## Technique notes, per this project's runner: the suite is @tool, no test is
## a coroutine, and every rig instantiated here is freed through track().

const _LOBBY_SCENE := "res://Scenes/Lobby/loby.tscn"
const _ROSTER_SCRIPT := "res://Scripts/StudentList/student_list.gd"
const _EYE_MASK_SHADER := "res://Scripts/Shaders/eye_mask.gdshader"
const _LENS_SHADER := "res://Scripts/Shaders/glasses_lens.gdshader"
const _CITRA_RIG := "res://Scenes/Lobby/CitraFace.tscn"

## Per student: the rig scene and its solved layers, back to front, as
## [node name, canvas position, native size]. Art facts, not preferences.
const _RIGS := {
	"Andi": {
		"rig": "res://Scenes/Lobby/AndiFace.tscn",
		"layers": [
			["Base", Vector2(0, 0), Vector2(1280, 1280)],
			["Sclera", Vector2(404, 556), Vector2(472, 99)],
			["Pupil", Vector2(477, 525), Vector2(326, 111)],
			["Eyelashes", Vector2(369, 521), Vector2(542, 83)],
			["Eyelid", Vector2(404, 556), Vector2(472, 110)],
			["Eyebrows", Vector2(450, 424), Vector2(380, 52)],
		],
	},
	"Doni": {
		"rig": "res://Scenes/Lobby/DoniFace.tscn",
		"layers": [
			["Base", Vector2(0, 0), Vector2(1280, 1280)],
			["Sclera", Vector2(391, 575), Vector2(498, 87)],
			["Pupil", Vector2(476, 566), Vector2(328, 101)],
			["Eyelashes", Vector2(398, 562), Vector2(484, 67)],
			["Eyelid", Vector2(391, 575), Vector2(498, 99)],
			["Eyebrows", Vector2(476, 490), Vector2(328, 30)],
		],
	},
	"Marcel": {
		"rig": "res://Scenes/Lobby/MarcelFace.tscn",
		"layers": [
			["Base", Vector2(0, 0), Vector2(1280, 1280)],
			["Sclera", Vector2(426, 555), Vector2(428, 128)],
			["Pupil", Vector2(467, 548), Vector2(346, 131)],
			["Eyelashes", Vector2(402, 535), Vector2(476, 139)],
			["Eyelid", Vector2(411, 555), Vector2(458, 145)],
			["Eyebrows", Vector2(414, 439), Vector2(452, 37)],
			["Glasses", Vector2(394, 497), Vector2(492, 233)],
		],
	},
	"Shinta": {
		"rig": "res://Scenes/Lobby/ShintaFace.tscn",
		"layers": [
			["Base", Vector2(0, 0), Vector2(1280, 1280)],
			["Sclera", Vector2(425, 572), Vector2(143, 107)],
			["Pupil", Vector2(492, 564), Vector2(64, 93)],
			["Eyelashes", Vector2(382, 543), Vector2(194, 128)],
			["Eyelid", Vector2(415, 560), Vector2(159, 129)],
			["Eyebrows", Vector2(452, 450), Vector2(93, 37)],
		],
	},
	"Thea": {
		"rig": "res://Scenes/Lobby/TheaFace.tscn",
		"layers": [
			["Base", Vector2(0, 0), Vector2(1280, 1280)],
			["Sclera", Vector2(435, 564), Vector2(410, 102)],
			["Pupil", Vector2(482, 556), Vector2(316, 126)],
			["Eyelashes", Vector2(369, 537), Vector2(542, 110)],
			["Eyelid", Vector2(374, 558), Vector2(532, 157)],
			["Eyebrows", Vector2(492, 444), Vector2(296, 42)],
		],
	},
}

## Eye cut-out pixels no layer covers, per student, measured from the art.
## A few anti-aliased rim pixels on Doni and Marcel have no opaque cover in
## any placement; the count is frozen so a regression cannot hide in it.
const _SEE_THROUGH_MAX := {"Andi": 0, "Doni": 5, "Marcel": 10, "Shinta": 0, "Thea": 0}

## Marcel's fitted lens gain (glasses_lens.gdshader's lens_gain).
const _MARCEL_LENS_GAIN := 1.173


func suite_name() -> String:
	return "face_rig_roster"


## Every rig's Eyelid layer must have art on disk. A rig whose lid texture is
## missing blinks invisibly: the layer fades in, nothing is drawn, and the
## eyes simply never close. Cheap to assert, and the one failure mode the
## placement tests above cannot see.
func test_every_rig_has_eyelid_art() -> void:
	for student_name in StudentSkins.NAMES:
		var path := "res://Assets/Images/MuridPotrait/%s/%s_eyelid.png" % [
			student_name, student_name.to_lower()]
		assert_true(ResourceLoader.exists(path),
			"%s must have eyelid art at %s" % [student_name, path])


func _rig(student: String) -> StudentFace:
	var scene: PackedScene = load(_RIGS[student]["rig"])
	var face := scene.instantiate() as StudentFace
	Engine.get_main_loop().root.add_child(face)
	track(face)
	return face


func _layer(face: Node, layer_name: String) -> TextureRect:
	return face.get_node_or_null(NodePath("Canvas/" + layer_name)) as TextureRect


func test_every_rig_is_a_student_face_named_for_its_student() -> void:
	for student in _RIGS:
		var face := _rig(student)
		assert_not_null(face, student + "'s rig must instance as a StudentFace")
		assert_eq(face.student_name, student,
			"the rig owns its roster name; the lobby matches seats on it")


func test_layers_stack_back_to_front_in_the_solved_order() -> void:
	for student in _RIGS:
		var face := _rig(student)
		var found: Array[String] = []
		for child in face.get_node(^"Canvas").get_children():
			found.append(str(child.name))
		var wanted: Array[String] = []
		for entry in _RIGS[student]["layers"]:
			wanted.append(entry[0])
		assert_eq(", ".join(found), ", ".join(wanted),
			student + "'s layer draw order must match the art")


func test_each_layer_sits_at_its_solved_offset_at_native_size() -> void:
	for student in _RIGS:
		var face := _rig(student)
		for entry in _RIGS[student]["layers"]:
			var node := _layer(face, entry[0])
			assert_not_null(node, "%s/%s must exist" % [student, entry[0]])
			assert_true(node.position.is_equal_approx(entry[1]),
				"%s/%s moved off its solved position: %s, expected %s"
					% [student, entry[0], node.position, entry[1]])
			assert_true(node.size.is_equal_approx(entry[2]),
				"%s/%s is not drawn at its native size" % [student, entry[0]])
			assert_eq(Vector2(node.texture.get_size()), entry[2],
				"%s/%s: the texture itself must be that size" % [student, entry[0]])


func test_every_layer_draws_its_students_own_art() -> void:
	for student in _RIGS:
		var face := _rig(student)
		var low := String(student).to_lower()
		for entry in _RIGS[student]["layers"]:
			var node := _layer(face, entry[0])
			var want := "res://Assets/Images/MuridPotrait/%s/%s_%s.png" \
				% [student, low, String(entry[0]).to_lower()]
			assert_eq(node.texture.resource_path, want,
				"%s/%s must draw %s" % [student, entry[0], want])


func test_only_the_eyelid_starts_hidden() -> void:
	for student in _RIGS:
		var face := _rig(student)
		for entry in _RIGS[student]["layers"]:
			assert_eq(_layer(face, entry[0]).visible, entry[0] != "Eyelid",
				"%s/%s: only the blink pose starts hidden" % [student, entry[0]])


func test_each_pupil_is_clipped_by_its_own_eye_white() -> void:
	for student in _RIGS:
		var face := _rig(student)
		var mat := _layer(face, "Pupil").material as ShaderMaterial
		assert_not_null(mat, student + "'s pupil needs the eye-mask material")
		assert_eq(mat.shader.resource_path, _EYE_MASK_SHADER,
			student + "'s pupil must use the eye-mask shader")
		var mask: Texture2D = mat.get_shader_parameter("mask_texture")
		assert_eq(mask.resource_path,
			"res://Assets/Images/MuridPotrait/%s/%s_sclera.png" % [student, String(student).to_lower()],
			student + "'s pupil must be clipped to their own sclera")
		assert_true(mat.resource_local_to_scene,
			student + "'s mask must be local to the scene, one per seat")


func test_no_eye_cut_out_is_left_see_through() -> void:
	# A cut-out pixel is see-through when the base is transparent there and no
	# layer drawn in the resting face covers it opaquely. Scan only the eye
	# white's rect plus a 4 px rim -- the cut-outs are exactly there.
	for student in _RIGS:
		var face := _rig(student)
		var sclera := _layer(face, "Sclera")
		var base_img := _layer(face, "Base").texture.get_image()
		var covers: Array = []
		for entry in _RIGS[student]["layers"]:
			if entry[0] in ["Base", "Pupil", "Eyelid"]:
				continue
			var node := _layer(face, entry[0])
			covers.append([node.texture.get_image(), Vector2i(node.position), _cover_alpha(node)])
		var r := Rect2i(Vector2i(sclera.position) - Vector2i(4, 4),
			Vector2i(sclera.size) + Vector2i(8, 8))
		var open := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if base_img.get_pixel(x, y).a >= 0.5:
					continue
				var covered := false
				for c in covers:
					var local: Vector2i = Vector2i(x, y) - c[1]
					var img: Image = c[0]
					if local.x >= 0 and local.y >= 0 and local.x < img.get_width() \
						and local.y < img.get_height() and img.get_pixel(local.x, local.y).a >= c[2]:
						covered = true
						break
				if not covered and _inside_face(base_img, x, y):
					open += 1
		assert_true(open <= _SEE_THROUGH_MAX[student],
			"%s: %d eye cut-out pixels show the lobby through the face (max %d)"
				% [student, open, _SEE_THROUGH_MAX[student]])


## The texture alpha from which a layer hides what is behind it. A plain layer
## covers from 0.5. glasses_lens.gdshader emits alpha 0 below its
## frame_alpha_from -- the lens only adds light and hides nothing -- so on a
## lens-shaded layer only the frame counts as cover.
func _cover_alpha(node: TextureRect) -> float:
	var mat := node.material as ShaderMaterial
	if mat != null and mat.shader != null and mat.shader.resource_path == _LENS_SHADER:
		return float(mat.get_shader_parameter("frame_alpha_from"))
	return 0.5


## True when (x, y) is enclosed by the base horizontally -- opaque base on
## both sides along its row. Keeps the scan from counting the canvas's own
## transparent surround, which a wide rect can reach on a narrow face.
func _inside_face(img: Image, x: int, y: int) -> bool:
	var left := false
	for lx in range(x - 1, maxi(x - 300, -1), -1):
		if img.get_pixel(lx, y).a >= 0.5:
			left = true
			break
	var right := false
	for rx in range(x + 1, mini(x + 300, img.get_width())):
		if img.get_pixel(rx, y).a >= 0.5:
			right = true
			break
	return left and right


func test_marcels_glasses_add_light_through_the_lens_shader() -> void:
	var face := _rig("Marcel")
	var glasses := _layer(face, "Glasses")
	assert_not_null(glasses, "Marcel wears glasses")
	var mat := glasses.material as ShaderMaterial
	assert_not_null(mat, "the glasses need the lens material")
	assert_eq(mat.shader.resource_path, _LENS_SHADER,
		"a plain alpha mix greys Marcel's eyes; the lens must add light")
	assert_true(absf(float(mat.get_shader_parameter("lens_gain")) - _MARCEL_LENS_GAIN) < 0.001,
		"lens_gain is fitted to Marcel's portrait")
	var src := FileAccess.get_file_as_string(_LENS_SHADER)
	assert_contains(src, "render_mode blend_premul_alpha",
		"premultiplied blending is what lets the lens add and the frame cover")


## face_rigs as saved on the lobby's root node, as resource paths.
func _lobby_rig_paths() -> Array[String]:
	var state := (load(_LOBBY_SCENE) as PackedScene).get_state()
	var paths: Array[String] = []
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == &"face_rigs":
			for rig in state.get_node_property_value(0, i):
				paths.append((rig as PackedScene).resource_path)
	return paths


func test_the_lobby_lists_every_rig() -> void:
	var paths := _lobby_rig_paths()
	assert_true(paths.has(_CITRA_RIG), "Citra's rig must stay in the lobby's list")
	for student in _RIGS:
		assert_true(paths.has(_RIGS[student]["rig"]),
			"loby.tscn's face_rigs must list " + _RIGS[student]["rig"])


func test_every_roster_student_has_a_face_rig() -> void:
	var re := RegEx.new()
	re.compile("\"name\":\\s*\"(\\w+)\"")
	var names: Array[String] = []
	for m in re.search_all(FileAccess.get_file_as_string(_ROSTER_SCRIPT)):
		names.append(m.get_string(1))
	assert_gt(names.size(), 0, "the roster script must still list students")
	var rigged: Array[String] = ["Citra"]
	for student in _RIGS:
		rigged.append(student)
	for student_name in names:
		assert_true(rigged.has(student_name),
			student_name + " is on the roster but has no face rig")
