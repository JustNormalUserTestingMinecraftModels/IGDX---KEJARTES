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
## Must be @tool, and no test here may be a coroutine.

const SHADER := "res://Scripts/Shaders/illustration_grade.gdshader"
const PLAIN := "res://Scripts/Shaders/illustration_grade_material.tres"
const CUTOUT := "res://Scripts/Shaders/illustration_grade_cutout.tres"


func suite_name() -> String:
	return "illustration_ao"


## Two materials, one shader. If these ever diverge, a change to the grade
## silently stops reaching half the game.
func test_both_materials_share_the_one_shader() -> void:
	var shader: Shader = load(SHADER)
	assert_true(shader != null, "the grade shader must exist")
	for path in [PLAIN, CUTOUT]:
		var mat: ShaderMaterial = load(path)
		assert_true(mat != null, "%s must exist" % path)
		if mat == null:
			continue
		assert_eq(mat.shader, shader, "%s must point at the one grade shader" % path)


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


## Light comes from the upper-left. Three independent things in the shipped game
## agree: the Lobby's WindowLight pool centres up and left, the sun streaks in
## loby_no_tables.png run down-right, and all three contact shadows were authored
## offset down-right -- Herman (12,10), BGHari (8,12), Splash (14,10). A rim that
## disagrees with the art is worse than no rim.
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
## these ceilings sit just above the shipped values. Raise them only after
## re-running the sweep and recording the numbers in the commit.
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


## Every plate this lands on is a cutout, and a grade that multiplied alpha
## would eat the soft edges the art is drawn with. The AO stage must darken
## colour only.
func test_neither_effect_touches_alpha() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_true(src.contains("src.a"), "the shader must pass the source alpha straight through")
	assert_false(src.contains("COLOR.a *"), "nothing may scale alpha, or cutout edges get eaten")


## The census, measured on 2026-09-23 by sampling each texture's alpha channel.
## A cutout has an alpha edge to find; a backdrop is full-bleed and would pay
## five taps per pixel for nothing. Percentages are transparent pixels.
const CUTOUTS := {
	"res://Scenes/Lobby/loby.tscn": [
		"Classroom/Meja_KiriAtas", "Classroom/Meja_KananAtas",
		"Classroom/Meja_KiriBawah", "Classroom/Meja_KananBawah",
	],
	"res://Scenes/Koperasi/koprasi.tscn": ["Stage/Herman", "Stage/Foreground"],
	"res://Scenes/SchoolSimulation/EventDialogue.tscn": ["Splash"],
	"res://Scenes/Lobby/AndiFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/CitraFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/DoniFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/MarcelFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/ShintaFace.tscn": ["Canvas/Base"],
	"res://Scenes/Lobby/TheaFace.tscn": ["Canvas/Base"],
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
## from two angles. If someone adds a plate to one and forgets the other, the
## game quietly has an ungraded illustration or an uncounted one. This is the
## test that notices.
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
	for source in [CUTOUTS, BACKDROPS]:
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
