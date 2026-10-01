@tool
extends McpTestSuite

## SplashShadow (2026-10-01): the soft ambient-occlusion shade behind a
## speaker's splash art, used by EventDialogue and MinigameWinScreen. It
## replaced a PaperShadow whose texture stayed Mom's silhouette for every
## speaker; this component takes whoever speaks now through follow().
##
## Three halves: the follow() contract (texture and stretch mode copied from
## the splash), the scene's own look (behind its parent, Full Rect, a
## mipmapped filter the shader's textureLod needs, the soft AO material), and
## the shader's two rules (it samples mips, and it never multiplies by
## COLOR.a, which would erase the shade the blur spreads past the figure).
## Where each screen wires it is pinned in tests/test_event_dialogue.gd and
## tests/test_minigame_win_screen.gd.
##
## Must be @tool, and no test here may be a coroutine.

## The component scene: one TextureRect carrying SplashShadow.gd.
const _SCENE := "res://Scenes/UI/SplashShadow.tscn"
## The shader the component's material runs.
const _SHADER := "res://Scripts/Shaders/soft_ao_shadow.gdshader"
## The material the scene root wears.
const _MATERIAL := "res://Scripts/Shaders/soft_ao_shadow_material.tres"
## The shade's strength, the owner's pick (65%), as the shadow_color alpha.
const _SHADOW_ALPHA := 0.65


func suite_name() -> String:
	return "splash_shadow"


## A throwaway 4x4 texture, so a test can tell one splash from another.
func _texture(shade: Color) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(shade)
	return ImageTexture.create_from_image(img)


## A tracked splash standing in for the speaker's TextureRect.
func _splash(shade: Color, mode: TextureRect.StretchMode) -> TextureRect:
	var splash := TextureRect.new()
	splash.texture = _texture(shade)
	splash.stretch_mode = mode
	track(splash)
	return splash


## The shader's source with its `//` comments cut away, so a scan sees only
## code (the file's own header says "Do not multiply by COLOR.a").
func _shader_code() -> String:
	var code := PackedStringArray()
	for line in FileAccess.get_file_as_string(_SHADER).split("\n"):
		var cut := line.find("//")
		code.append(line if cut == -1 else line.substr(0, cut))
	return "\n".join(code)


# ── follow() ─────────────────────────────────────────────────────────────────

## follow() takes the source's texture and stretch mode, and takes them again
## when the speaker changes.
func test_follow_copies_the_texture_and_the_stretch_mode() -> void:
	var shadow := SplashShadow.new()
	track(shadow)
	var first := _splash(Color.RED, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	shadow.follow(first)
	assert_eq(shadow.texture, first.texture, "the shade wears the speaker's art")
	assert_eq(shadow.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "and fills its rect the same way")
	var second := _splash(Color.BLUE, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	shadow.follow(second)
	assert_eq(shadow.texture, second.texture, "a new speaker replaces the old silhouette")
	assert_ne(shadow.texture, first.texture, "not Mom's art for everyone")
	assert_eq(shadow.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "and the new stretch mode")


## A speaker-less screen leaves the splash without a texture; the shade must
## not keep the last silhouette.
func test_follow_clears_the_shade_when_the_splash_has_no_art() -> void:
	var shadow := SplashShadow.new()
	track(shadow)
	shadow.follow(_splash(Color.RED, TextureRect.STRETCH_SCALE))
	assert_true(shadow.texture != null, "the shade had a silhouette")
	var empty := TextureRect.new()
	track(empty)
	shadow.follow(empty)
	assert_eq(shadow.texture, null, "no splash art, no shade")


# ── the scene ────────────────────────────────────────────────────────────────

## The component's own look: it draws behind its parent, takes no taps, fills
## its parent, and samples with a mipmap filter the shader's textureLod needs.
func test_the_scene_is_a_full_rect_shade_behind_its_parent() -> void:
	var shadow := (load(_SCENE) as PackedScene).instantiate() as SplashShadow
	assert_true(shadow != null, "SplashShadow.tscn's root carries SplashShadow.gd")
	if shadow == null:
		return
	track(shadow)
	assert_true(shadow.show_behind_parent, "the shade draws under the art, not over it")
	assert_eq(shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a shade must never eat a tap")
	assert_eq(Vector4(shadow.anchor_left, shadow.anchor_top, shadow.anchor_right, shadow.anchor_bottom),
		Vector4(0, 0, 1, 1), "Full Rect, so it follows the splash on any phone")
	assert_eq(Vector4(shadow.offset_left, shadow.offset_top, shadow.offset_right, shadow.offset_bottom),
		Vector4.ZERO, "and not inset, or the shade slides off the art")
	assert_eq(shadow.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"without a mipmap filter textureLod reads one flat level and nothing blurs")
	assert_true(shadow.material != null, "the shade wears a material")
	if shadow.material != null:
		assert_eq(shadow.material.resource_path, _MATERIAL, "the soft AO material")


# ── the shader ───────────────────────────────────────────────────────────────

## The blur is textureLod reads at two mip levels, and the shader must never
## scale its output by COLOR.a: on entry that is the texture's own alpha, zero
## outside the figure, so multiplying by it erases the shade the blur just
## spread there (the first 2026-10-01 preview did exactly that).
func test_the_shader_blurs_through_mips_and_never_multiplies_by_color_alpha() -> void:
	var code := _shader_code()
	assert_true(code.contains("textureLod"), "the blur is a mip read")
	assert_false(code.contains("COLOR.a"), "COLOR.a is the figure's own alpha; scaling by it erases the shade")


## The shade's strength is the owner's pick: 65%, carried as shadow_color's
## alpha. The material also has to run this shader, or the pick tunes nothing.
func test_the_material_runs_the_shader_at_the_owners_strength() -> void:
	var mat := load(_MATERIAL) as ShaderMaterial
	assert_true(mat != null, "the soft AO material must exist")
	if mat == null:
		return
	assert_eq(mat.shader.resource_path, _SHADER, "the material runs the soft AO shader")
	var color: Color = mat.get_shader_parameter("shadow_color")
	assert_true(is_equal_approx(color.a, _SHADOW_ALPHA),
		"the shade's alpha is the owner's 0.65, not %s" % color.a)
