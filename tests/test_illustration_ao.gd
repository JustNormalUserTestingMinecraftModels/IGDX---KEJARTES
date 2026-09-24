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
## Alpha pass-through (the shader must forward src.a and never write
## COLOR.a *) is covered by test_the_grade_leaves_alpha_alone in
## tests/test_look_layer.gd; it is not re-asserted here.
##
## Must be @tool, and no test here may be a coroutine.

const SHADER := "res://Scripts/Shaders/illustration_grade.gdshader"
const PLAIN := "res://Scripts/Shaders/illustration_grade_material.tres"
const CUTOUT := "res://Scripts/Shaders/illustration_grade_cutout.tres"
const FACE := "res://Scripts/Shaders/illustration_grade_face.tres"
## The Lobby's desks: the cutout grade lit from the upper right (2026-09-24).
const LOBBY_CUTOUT := "res://Scripts/Shaders/illustration_grade_cutout_lobby.tres"


func suite_name() -> String:
	return "illustration_ao"


## Two materials, one shader. If these ever diverge, a change to the grade
## silently stops reaching half the game.
func test_both_materials_share_the_one_shader() -> void:
	var shader: Shader = load(SHADER)
	assert_true(shader != null, "the grade shader must exist")
	for path in [PLAIN, CUTOUT, LOBBY_CUTOUT, FACE]:
		var mat: ShaderMaterial = load(path)
		assert_true(mat != null, "%s must exist" % path)
		if mat == null:
			continue
		assert_eq(mat.shader, shader, "%s must point at the one grade shader" % path)


## The two materials carry independent copies of the five colour-grade
## uniforms. Nothing at the engine level keeps them in sync -- edit one and
## the other silently keeps the old look, so 21 of the 30 graded plates (the
## cutouts) would drift from the other 9 (the backdrops). This is the test
## that would catch that drift.
func test_the_two_materials_agree_on_the_shared_grade() -> void:
	var plain: ShaderMaterial = load(PLAIN)
	assert_true(plain != null, "the plain material must exist")
	if plain == null:
		return
	var reference_tint: Color = plain.get_shader_parameter("tint")
	for path in [CUTOUT, LOBBY_CUTOUT, FACE]:
		var other: ShaderMaterial = load(path)
		assert_true(other != null, "%s must exist" % path)
		if other == null:
			continue
		for uniform in ["saturation", "contrast", "exposure", "amount"]:
			var a: float = plain.get_shader_parameter(uniform)
			var b: float = other.get_shader_parameter(uniform)
			assert_true(is_equal_approx(a, b),
				"%s must match the plain material: plain=%s %s=%s" % [uniform, a, path, b])
		var other_tint: Color = other.get_shader_parameter("tint")
		assert_true(reference_tint.is_equal_approx(other_tint),
			"tint must match the plain material: plain=%s %s=%s"
				% [reference_tint, path, other_tint])


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


## Outside the Lobby, light comes from the upper-left: the contact shadows
## were authored offset down-right -- Herman (12,10), BGHari (8,12), Splash
## (14,10). A rim that disagrees with the art is worse than no rim.
func test_the_light_comes_from_the_upper_left() -> void:
	var mat: ShaderMaterial = load(CUTOUT)
	assert_true(mat != null, "the cutout material must exist")
	if mat == null:
		return
	var dir: Vector2 = mat.get_shader_parameter("light_dir")
	assert_true(dir.x < 0.0, "light_dir.x must point left, matching the window")
	assert_true(dir.y < 0.0, "light_dir.y must point up, matching the painted streaks")


## The ceilings, set by measurement on 2026-09-23 rather than by instinct.
##
## The sweep expected to find a clipping knee, the way the window light has one
## at 0.12, and found none: over the frozen Lobby at 1080x1920 the rim drove
## ZERO extra pixels to pure white at any value up to 0.30, and AO's worst
## whole-frame mean-luminance drop was 0.132% at strength 0.45 -- against a 1%
## gate, on a grade that had already been halved twice for reading dark. So
## neither effect is bounded by clipping or by darkening here.
##
## What bounds them is taste, judged on full-size captures: at 1.00/0.70 the
## edges start to look drawn on. The shipped 0.70/0.45 sits below that, and
## these ceilings sit just above the shipped values.
##
## The gate was then re-measured AT the shipped pair, because the first sweep
## stopped short of it and a gate that was never evaluated where it matters is
## not a gate. At 0.70/0.45 the whole-frame mean moves +0.042%, and at the
## ceilings 0.75/0.50 it moves +0.051% -- both inside 1%, and both in the
## brightening direction. Taken apart: AO alone at 0.70 is -0.199% and the rim
## alone at 0.45 is +0.222%, so the two nearly cancel. That is why this pass
## does not re-darken a grade that had already been halved twice for reading
## dark. Raise these only after re-running the sweep and recording the numbers
## in the commit.
const AO_STRENGTH_CEILING := 0.75
const RIM_STRENGTH_CEILING := 0.50


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


## The face material is the cutout material plus hole rejection, and nothing
## else. If someone tunes AO or the rim from the Look page and writes the value
## into only one of them, the six faces drift away from every other character
## in the game -- which is the same failure the shared-grade test above guards
## for the colour stage. The faces sit in the Lobby, so they take the Lobby's
## light, not the rest of the game's.
func test_the_face_material_matches_the_cutout_on_ao_and_rim() -> void:
	var cutout: ShaderMaterial = load(CUTOUT)
	var face: ShaderMaterial = load(FACE)
	var lobby: ShaderMaterial = load(LOBBY_CUTOUT)
	assert_true(cutout != null and face != null and lobby != null, "all three materials must exist")
	if cutout == null or face == null or lobby == null:
		return
	for uniform in ["ao_strength", "ao_radius_px", "rim_strength", "rim_radius_px"]:
		var a: float = cutout.get_shader_parameter(uniform)
		var b: float = face.get_shader_parameter(uniform)
		assert_true(is_equal_approx(a, b),
			"%s must match between cutout and face: cutout=%s face=%s" % [uniform, a, b])
	var a_dir: Vector2 = lobby.get_shader_parameter("light_dir")
	var b_dir: Vector2 = face.get_shader_parameter("light_dir")
	assert_true(a_dir.is_equal_approx(b_dir),
		"the faces and the desks they sit at must agree about where the light is")


## The Lobby is lit from the upper right (2026-09-24, by request). Its desks
## and faces are the only plates that take that light; Herman, the event
## splash and the minigames keep the upper-left light their shadows were drawn
## for, which is why the Lobby desks wear a material of their own.
func test_the_lobby_is_lit_from_the_upper_right() -> void:
	for path in [LOBBY_CUTOUT, FACE]:
		var mat: ShaderMaterial = load(path)
		assert_true(mat != null, "%s must exist" % path)
		if mat == null:
			continue
		var dir: Vector2 = mat.get_shader_parameter("light_dir")
		assert_true(dir.x > 0.0, "%s: the Lobby's light must come from the right" % path)
		assert_true(dir.y < 0.0, "%s: the Lobby's light must come from above" % path)


## The Lobby desk material is the cutout material with the light turned
## around, and nothing else: every other uniform must match, or a value tuned
## into one leaves the Lobby's desks looking unlike every other cutout.
func test_the_lobby_cutout_differs_only_in_its_light() -> void:
	var cutout: ShaderMaterial = load(CUTOUT)
	var lobby: ShaderMaterial = load(LOBBY_CUTOUT)
	assert_true(cutout != null and lobby != null, "both materials must exist")
	if cutout == null or lobby == null:
		return
	for uniform in ["saturation", "contrast", "exposure", "tint", "amount", "ao_strength",
			"ao_radius_px", "ao_color", "rim_strength", "rim_radius_px", "rim_color"]:
		var a: Variant = cutout.get_shader_parameter(uniform)
		var b: Variant = lobby.get_shader_parameter(uniform)
		assert_eq(str(a), str(b), "%s must match the cutout material: cutout=%s lobby=%s" % [uniform, a, b])
	var mirrored: Vector2 = cutout.get_shader_parameter("light_dir") * Vector2(-1.0, 1.0)
	assert_true(mirrored.is_equal_approx(lobby.get_shader_parameter("light_dir")),
		"the Lobby's light is the rest of the game's, mirrored left to right")

## The census, measured on 2026-09-23 by sampling each texture's alpha channel.
## A cutout has an alpha edge to find; a backdrop is full-bleed and would pay
## five taps per pixel for nothing. Percentages are transparent pixels.
const CUTOUTS := {
	"res://Scenes/Koperasi/koprasi.tscn": ["Stage/Herman", "Stage/Foreground"],
	"res://Scenes/SchoolSimulation/EventDialogue.tscn": ["Splash"],
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


## The six Lobby faces are cutouts too, but they wear a third material.
##
## Each face plate is drawn with the eye sockets and the mouth punched out, so
## the sclera, pupil, eyelid and brows underneath show through: 0.78% to 1.77%
## of every base is interior hole. The rim test cannot tell the edge of a hole
## from the outline of a head, so it drew a cream ring around every eye and
## mouth in the room -- measured on a real frame, not guessed. The face material
## turns on rim_hole_reject_texels, which the other plates leave at zero.
const FACES := {
	"res://Scenes/Lobby/AndiFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/CitraFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/DoniFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/MarcelFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/ShintaFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/TheaFace.tscn": ["Canvas/Base"],
}


func test_every_face_wears_the_face_material() -> void:
	var face: Material = load(FACE)
	assert_true(face is ShaderMaterial, "the face grade material must exist")
	for scene_path in FACES:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in FACES[scene_path]:
			var node := root.get_node_or_null(NodePath(node_path)) as CanvasItem
			assert_true(node != null, "%s is missing %s" % [scene_path, node_path])
			if node == null:
				continue
			assert_eq(node.material, face,
				"%s/%s must wear the face grade, which rejects rim at eye and "
					% [scene_path, node_path] + "mouth holes")


## Only the faces reject. A plate with no interior holes pays nothing, and the
## two probes are not free.
func test_only_the_face_material_rejects_interior_holes() -> void:
	var face: ShaderMaterial = load(FACE)
	var cutout: ShaderMaterial = load(CUTOUT)
	var plain: ShaderMaterial = load(PLAIN)
	assert_true(face != null and cutout != null and plain != null, "all three materials must exist")
	if face == null or cutout == null or plain == null:
		return
	assert_true(_param_or_zero(face, "rim_hole_reject_texels") > 0.0,
		"the faces are the reason this uniform exists")
	assert_true(is_zero_approx(_param_or_zero(cutout, "rim_hole_reject_texels")),
		"plates without interior holes must not pay for two extra probes")
	assert_true(is_zero_approx(_param_or_zero(plain, "rim_hole_reject_texels")),
		"backdrops have no rim at all, so they certainly must not probe")


## First tuned as 24 screen pixels in the editor's half-size run, where the
## faces draw at 0.143-0.158 and 24 px spans 152-168 texels. There, with the rim
## at full strength, it took the eye undersides and both mouths and left the
## hair, shoulders and collar alone; 36 px (228-252 texels) started eating the
## collar, a real silhouette, and 28 px (177-196) was the agreed ceiling. On a
## 1080-wide phone the same 24 px spanned only ~80 texels and left 73-93% of the
## eye ring's glow in place (measured 2026-09-23 on the Lobby's four faces), so
## the reach moved to texels. 160 took the ring to 0-5% on all four and matches
## the look that was approved. An offline sweep over all twelve face bases left
## up to 35% of the ring at 120 texels, hence the floor. Re-measure with a
## before/after heatmap before moving either.
const FACE_REJECT_FLOOR := 150.0
const FACE_REJECT_CEILING := 180.0


func test_the_face_reject_does_not_eat_the_silhouette() -> void:
	var face: ShaderMaterial = load(FACE)
	assert_true(face != null, "the face grade material must exist")
	if face == null:
		return
	var reject := _param_or_zero(face, "rim_hole_reject_texels")
	assert_true(reject <= FACE_REJECT_CEILING,
		"reject %s starts removing rim from the collar and shoulders; ceiling is %s"
			% [reject, FACE_REJECT_CEILING])
	assert_true(reject >= FACE_REJECT_FLOOR,
		"reject %s is too short to cross an eye socket; the cream ring comes back below %s"
			% [reject, FACE_REJECT_FLOOR])


## The AO had the rim's blind spot too: it darkened toward the eye sockets and
## drew a brown ring inside every eye, which read as eyeshadow. The faces turn
## on ao_hole_reject_texels; nothing else has holes worth the probes, which cost up
## to eight taps per transparent AO tap.
func test_only_the_face_material_rejects_ao_holes() -> void:
	var face: ShaderMaterial = load(FACE)
	var cutout: ShaderMaterial = load(CUTOUT)
	var plain: ShaderMaterial = load(PLAIN)
	assert_true(face != null and cutout != null and plain != null, "all three materials must exist")
	if face == null or cutout == null or plain == null:
		return
	assert_true(_param_or_zero(face, "ao_hole_reject_texels") > 0.0,
		"the faces are the reason this uniform exists")
	assert_true(is_zero_approx(_param_or_zero(cutout, "ao_hole_reject_texels")),
		"plates without interior holes must not pay for the enclosure probes")
	assert_true(is_zero_approx(_param_or_zero(plain, "ao_hole_reject_texels")),
		"backdrops have no AO at all, so they certainly must not probe")


## Measured on 2026-09-23 by running the shader's four-sided test on the twelve
## face bases (six defaults, six skin1s), whose eye sockets are 125-170 texels
## wide and 86-128 tall. The reach has to cross the whole socket from wherever
## the tap lands in it. At 140 texels part of the ring survives on four faces;
## from 170 the result stops changing (what is left sits on hair gaps and lash
## notches, not the eye). The outline kept 100% of its AO at every reach up to
## 240, because the air beside a head is never walled in on all four sides.
## Texels, so the answer holds on every screen size. Re-measure for new art.
const FACE_AO_REJECT_FLOOR := 170.0
const FACE_AO_REJECT_CEILING := 240.0


func test_the_face_ao_reject_spans_an_eye_socket() -> void:
	var face: ShaderMaterial = load(FACE)
	assert_true(face != null, "the face grade material must exist")
	if face == null:
		return
	var reach := _param_or_zero(face, "ao_hole_reject_texels")
	assert_true(reach >= FACE_AO_REJECT_FLOOR,
		"reach %s is too short to cross an eye socket; the ring comes back below %s"
			% [reach, FACE_AO_REJECT_FLOOR])
	assert_true(reach <= FACE_AO_REJECT_CEILING,
		"reach %s is past the last value measured to spare the outline (%s)"
			% [reach, FACE_AO_REJECT_CEILING])


## Every one of the four AO taps must go through the hole test. One tap left
## on a bare textureLod keeps a quarter of the ring on that side of every eye.
## The four taps run through one loop, so the hole test cannot be skipped on
## one side.
##
## And no helper function may take a sampler2D: the only thing it could be
## handed is TEXTURE, and the shader compiler rejects a builtin texture passed
## as an argument, logging nine ERROR lines on every headless load. The editor
## and a desktop GPU render it fine, so only CI's project-check saw it (#73).
func test_every_ao_tap_goes_through_the_hole_test() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_true(src.contains("for (int i = 0; i < 4; i++)"),
		"the four AO taps must share one loop, so every tap gets the hole test")
	assert_eq(src.count("vec2 uv = UV + taps[i]"), 1, "the loop must walk the four taps")
	assert_true(src.contains("a < 1.0 && reach.x > 0.0"),
		"the enclosure probes must be skipped for an opaque tap or when reach is 0")
	assert_false(src.contains("sampler2D tex"),
		"never pass TEXTURE into a function: the shader compiler rejects it headless")


## A material that never sets a uniform reports null for it, not the shader's
## default, so reading one straight out of get_shader_parameter and handing it
## to a float function aborts the test. Every hole-reject uniform defaults to
## 0.0 -- off.
func _param_or_zero(mat: ShaderMaterial, uniform: String) -> float:
	var value: Variant = mat.get_shader_parameter(uniform)
	return 0.0 if value == null else float(value)


## The Lobby's four desks are cutouts too, lit from the upper right.
const LOBBY_DESKS := {
	"res://Scenes/Lobby/loby.tscn": [
		"Classroom/Meja_KiriAtas", "Classroom/Meja_KananAtas",
		"Classroom/Meja_KiriBawah", "Classroom/Meja_KananBawah",
	],
}


func test_every_lobby_desk_wears_the_lobby_cutout() -> void:
	var lobby: Material = load(LOBBY_CUTOUT)
	for scene_path in LOBBY_DESKS:
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		for node_path in LOBBY_DESKS[scene_path]:
			var node := root.get_node_or_null(NodePath(node_path)) as CanvasItem
			assert_true(node != null, "the Lobby is missing %s" % node_path)
			if node == null:
				continue
			assert_eq(node.material, lobby, "%s must wear the Lobby's cutout grade" % node_path)


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
## from two angles. This checks that agreement: a plate added to one dict and
## forgotten in the other fails here. It does NOT notice a plate that was
## given a grade material in a .tscn but added to neither list -- that plate
## is invisible to this test too. The assert_eq(counted.size(), 30, ...) below
## is a deliberate ratchet, not a discovered fact: bump it by hand when a
## plate is legitimately added to both dicts.
func test_the_census_covers_every_graded_plate_exactly_once() -> void:
	var look_script: GDScript = load("res://tests/test_look_layer.gd")
	assert_true(look_script != null, "test_look_layer.gd must exist")
	if look_script == null:
		return
	var graded: Dictionary = look_script.get_script_constant_map().get("GRADED", {})
	assert_false(graded.is_empty(), "look_layer must expose GRADED")
	if graded.is_empty():
		return

	var counted := {}
	for source in [CUTOUTS, LOBBY_DESKS, FACES, BACKDROPS]:
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


## Additive light over this near-white palette normally clips fast -- the window
## light beside these ships at 0.11 against a measured knee of 0.12. The shafts
## were expected to behave the same way and do not: swept over the frozen Lobby,
## 0.03 left the frame bit-identical and 0.20 moved whole-frame mean luminance
## by +0.170% while driving 3 extra pixels to pure white out of ~127,000
## sampled. They cover little of the screen and fall on the mid-tone wall rather
## than on paper, so the cream never gets the chance to blow out.
##
## So this ceiling is not a clipping limit -- there is no knee in range. It is a
## look limit, set just above the 0.20 chosen from six real frames. Re-sweep
## before moving it; do not assume the window light's knee applies.
const SHAFT_INTENSITY_CEILING := 0.22


func test_the_shafts_stay_under_the_look_ceiling() -> void:
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
	for path in ["illustration_grade_cutout_lobby.tres", "illustration_grade_face.tres"]:
		assert_true(src.contains(path),
			"the sliders must write to %s too, or the Lobby drifts while being tuned" % path)
