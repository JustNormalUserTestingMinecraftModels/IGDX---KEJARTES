@tool
extends McpTestSuite

## SkinCard.tscn / .gd: one skin in SkinSelect's carousel, and the static
## snap rule the carousel settles with (spec:
## docs/superpowers/specs/2026-09-23-skin-select-slide-design.md). settle_index
## is static so it is testable without a tree or a frame, the same shape as
## BasketTray.classify_drag.

const CARD := "res://Scenes/Skins/SkinCard.tscn"
const SHADER := "res://Scripts/Shaders/skin_card_focus.gdshader"


func suite_name() -> String:
	return "skin_card"


func _new_card() -> SkinCard:
	var card: SkinCard = (load(CARD) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


func _focus_material(card: SkinCard) -> ShaderMaterial:
	return (card.get_node("Art") as TextureRect).material as ShaderMaterial


func test_show_skin_loads_that_skins_splash() -> void:
	var card := _new_card()
	card.show_skin("Shinta", "skin1", false)
	assert_eq(card.skin_id, "skin1")
	var art := card.get_node("Art") as TextureRect
	assert_true(art.texture != null, "the card must have a splash")
	if art.texture == null:
		return
	assert_eq(art.texture.resource_path, StudentSkins.layer_path("Shinta", "skin1", "splash"))
	assert_false(card.get_node("Lock").visible)


func test_locked_skin_shows_the_lock() -> void:
	var card := _new_card()
	card.show_skin("Shinta", "skin1", true)
	assert_true(card.get_node("Lock").visible)


## The old material sampled SCREEN_TEXTURE, so a "blurred" card drew a
## blurred rectangle of the background where the neighbour's splash should
## have been. The focus shader must read the card's own TEXTURE.
func test_focus_shader_blurs_the_cards_own_texture_not_the_screen() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	assert_true(src != "", "skin_card_focus.gdshader must exist")
	assert_false(src.contains("hint_screen_texture"), "must not sample the screen")
	assert_true(src.contains("texture(TEXTURE"), "must sample the card's own art")
	assert_true(src.contains("uniform float sigma_texels"))
	assert_true(src.contains("uniform float brightness"))


func test_the_screen_blur_material_is_gone() -> void:
	assert_false(ResourceLoader.exists("res://Scenes/Skins/skin_option_blur_material.tres"))


## The card is the splash's own 1080x1920 canvas; the pose scales it. A
## smaller authored card was what pushed the neighbour's figure off screen.
func test_card_is_the_full_splash_canvas() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_true(src.contains("custom_minimum_size = Vector2(1080, 1920)"))


## Each card needs its own uniforms, or posing one card would re-pose both.
func test_each_card_owns_its_focus_material() -> void:
	var a := _new_card()
	var b := _new_card()
	assert_true(_focus_material(a) != null, "Art must carry a ShaderMaterial")
	if _focus_material(a) == null:
		return
	assert_eq(_focus_material(a).shader.resource_path, SHADER)
	assert_true(_focus_material(a) != _focus_material(b),
		"the material must be resource_local_to_scene")


func test_a_focused_pose_is_sharp_and_full_brightness() -> void:
	var card := _new_card()
	card.set_pose(Vector2(85, 153), 0.818, 1.0, 0.71, 4.0)
	assert_eq(card.position, Vector2(85, 153))
	assert_eq(card.scale, Vector2(0.818, 0.818))
	assert_eq(card.focus, 1.0)
	var mat := _focus_material(card)
	assert_true(absf(float(mat.get_shader_parameter("sigma_texels")) - 0.0) < 0.0001)
	assert_true(absf(float(mat.get_shader_parameter("brightness")) - 1.0) < 0.0001)


## The blur is specified in SCREEN pixels, so the texel radius grows as the
## card shrinks: 4px on screen at scale 0.658 is 4 / 0.658 texels.
func test_an_unfocused_pose_is_dim_and_blurred_in_screen_pixels() -> void:
	var card := _new_card()
	card.set_pose(Vector2(676, 370), 0.658, 0.0, 0.71, 4.0)
	var mat := _focus_material(card)
	assert_true(absf(float(mat.get_shader_parameter("sigma_texels")) - (4.0 / 0.658)) < 0.001)
	assert_true(absf(float(mat.get_shader_parameter("brightness")) - 0.71) < 0.0001)


func test_a_half_focused_pose_is_halfway() -> void:
	var card := _new_card()
	card.set_pose(Vector2.ZERO, 0.5, 0.5, 0.71, 4.0)
	var mat := _focus_material(card)
	assert_true(absf(float(mat.get_shader_parameter("brightness")) - 0.855) < 0.0001)
	assert_true(absf(float(mat.get_shader_parameter("sigma_texels")) - 4.0) < 0.0001)


func test_settle_index_stays_put_for_a_small_slow_drag() -> void:
	assert_eq(SkinCard.settle_index(0, 40.0, 0.0, 812.0, 2), 0)


func test_settle_index_advances_past_the_halfway_mark() -> void:
	assert_eq(SkinCard.settle_index(0, -500.0, 0.0, 812.0, 2), 1)


## A flick decides on its own, whatever distance it covered.
func test_settle_index_follows_a_fast_flick() -> void:
	assert_eq(SkinCard.settle_index(0, -20.0, -900.0, 812.0, 2), 1)
	assert_eq(SkinCard.settle_index(1, 20.0, 900.0, 812.0, 2), 0)


func test_settle_index_clamps_at_both_ends() -> void:
	assert_eq(SkinCard.settle_index(0, 900.0, 2000.0, 812.0, 2), 0)
	assert_eq(SkinCard.settle_index(1, -900.0, -2000.0, 812.0, 2), 1)
