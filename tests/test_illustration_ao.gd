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


## The ceilings. AO darkens, and this grade has already been halved twice for
## reading dark -- see the two 2026-09-22/23 cuts in illustration_grade.gdshader.
## These hold the line. Raise them only after re-running the sweep in the spec's
## section 4 and recording the numbers in the commit.
const AO_STRENGTH_CEILING := 0.45
const RIM_STRENGTH_CEILING := 0.30


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
