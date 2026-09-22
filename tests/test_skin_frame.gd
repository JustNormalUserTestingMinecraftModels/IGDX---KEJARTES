@tool
extends McpTestSuite

## SkinFrame (the masked, bordered student art in the skin popup) and the
## theme variations it draws with.


func suite_name() -> String:
	return "skin_frame"


## StudentTile draws its own box, so it needs the frame's border off. The
## knob is on SkinFrame's root, not on Border, because a property set on an
## instanced scene's CHILD is reported as saved and then dropped.
func test_show_border_hides_the_border_node() -> void:
	var frame: SkinFrame = (load("res://Scenes/Skins/SkinFrame.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(frame)
	track(frame)
	assert_true(frame.get_node("Border").visible, "the border is on by default")
	frame.show_border = false
	assert_false(frame.get_node("Border").visible)
	frame.show_border = true
	assert_true(frame.get_node("Border").visible)


func test_factory_builds_the_skin_panels() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	for name in ["SkinFrameMask", "SkinFrameBorder", "SkinOptionColumn"]:
		assert_eq(theme.get_type_variation_base(name), &"Panel", name)
	var mask := theme.get_stylebox("panel", "SkinFrameMask") as StyleBoxFlat
	assert_eq(mask.bg_color.a, 1.0, "the mask is opaque: it is what clips the art")
	assert_eq(mask.corner_radius_top_left, ThemeFactory.SKIN_FRAME_RADIUS)
	var border := theme.get_stylebox("panel", "SkinFrameBorder") as StyleBoxFlat
	assert_false(border.draw_center, "the border draws no fill over the art")
	assert_eq(border.border_width_left, ThemeFactory.SKIN_BORDER_WIDTH)
	assert_eq(border.border_color, t.brand_primary)
	var column := theme.get_stylebox("panel", "SkinOptionColumn") as StyleBoxFlat
	assert_eq(column.border_color, t.brand_primary)
	assert_eq(column.bg_color, t.surface_card)


const FRAME := "res://Scenes/Skins/SkinFrame.tscn"


func _frame() -> SkinFrame:
	var f := (load(FRAME) as PackedScene).instantiate() as SkinFrame
	track(f)
	return f


func test_scene_contract() -> void:
	var f := _frame()
	var mask := f.get_node("Mask") as Panel
	assert_eq(mask.theme_type_variation, &"SkinFrameMask")
	assert_eq(mask.clip_children, CanvasItem.CLIP_CHILDREN_AND_DRAW)
	assert_true(f.get_node("Mask/Art") is TextureRect)
	assert_eq((f.get_node("Border") as Panel).theme_type_variation, &"SkinFrameBorder")
	assert_eq(f.get_child_count(), 2, "Border is a sibling after Mask, so it is not clipped")
	for n in ["Mask", "Mask/Art", "Border"]:
		assert_eq((f.get_node(n) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, n)


func test_show_art_places_the_face() -> void:
	var f := _frame()
	f.size = Vector2(200, 400)
	f.visible_source_height = 800.0
	f.face_y_ratio = 0.25
	var tex := load("res://Assets/Images/SplashArtMurid/splash_andi.png") as Texture2D
	f.show_art(tex, Vector2(500, 300))
	var art := f.get_node("Mask/Art") as TextureRect
	assert_eq(art.texture, tex)
	assert_eq(art.size, Vector2(540, 960), "scale = 400 / 800")
	assert_eq(art.position, Vector2(100 - 250, 100 - 150), "centre x mid-frame, face at 25% height")


func test_relayout_on_resize() -> void:
	var f := _frame()
	# NOTIFICATION_RESIZED only fires inside the tree.
	Engine.get_main_loop().root.add_child(f)
	f.size = Vector2(200, 400)
	f.visible_source_height = 800.0
	f.show_art(load("res://Assets/Images/SplashArtMurid/splash_andi.png"), Vector2(500, 300))
	f.size = Vector2(200, 800)
	assert_eq((f.get_node("Mask/Art") as TextureRect).size, Vector2(1080, 1920))


func test_null_texture_clears() -> void:
	var f := _frame()
	f.size = Vector2(200, 400)
	f.show_art(null, Vector2.ZERO)
	assert_eq((f.get_node("Mask/Art") as TextureRect).texture, null)
