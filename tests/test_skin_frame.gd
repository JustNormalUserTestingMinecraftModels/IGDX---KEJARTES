@tool
extends McpTestSuite

## SkinFrame (the masked, bordered student art in the skin popup) and the
## theme variations it draws with.


func suite_name() -> String:
	return "skin_frame"


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
