@tool
extends McpTestSuite

## StudentTile.tscn / .gd: one of the six squares in SkinSelect's rail
## (spec: docs/superpowers/specs/2026-09-22-skin-select-screen-design.md
## section 4, "The six squares"). Shows a character's face cropped out of
## the splash of whichever skin they are pending.

const TILE := "res://Scenes/Skins/StudentTile.tscn"


func suite_name() -> String:
	return "student_tile"


func _new_tile() -> StudentTile:
	var tile: StudentTile = (load(TILE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(tile)
	track(tile)
	return tile


func test_show_student_loads_that_skins_splash() -> void:
	var tile := _new_tile()
	tile.show_student("Shinta", StudentSkins.DEFAULT_ID)
	assert_eq(tile.student_name, "Shinta")
	var art := tile.get_node("Frame/Mask/Art") as TextureRect
	assert_true(art.texture != null, "the crop must have a texture")
	if art.texture == null:
		return
	assert_eq(art.texture.resource_path,
		StudentSkins.layer_path("Shinta", StudentSkins.DEFAULT_ID, "splash"))


func test_show_student_follows_the_pending_skin_not_the_equipped_one() -> void:
	var tile := _new_tile()
	tile.show_student("Shinta", "skin1")
	var art := tile.get_node("Frame/Mask/Art") as TextureRect
	assert_true(art.texture != null)
	if art.texture == null:
		return
	assert_eq(art.texture.resource_path, StudentSkins.layer_path("Shinta", "skin1", "splash"))


## The open student is marked by a stylebox swap, not by resizing: growing
## the square would re-lay the whole rail out on every switch, for
## legibility the ring already buys.
func test_set_open_swaps_the_variation_and_keeps_the_size() -> void:
	var tile := _new_tile()
	tile.show_student("Andi", StudentSkins.DEFAULT_ID)
	var size_before := tile.custom_minimum_size
	tile.set_open(false)
	assert_eq(tile.theme_type_variation, &"SkinStudentTile")
	tile.set_open(true)
	assert_eq(tile.theme_type_variation, &"SkinStudentTileActive")
	assert_eq(tile.custom_minimum_size, size_before, "the tile must not resize on select")


## 151x156, measured off skinselection_mockup.png. Off the S/M/L scale on
## purpose: the user asked for a pixel copy (2026-09-23), so the tile has a
## reasoned HEIGHT_ALLOWED entry in tests/test_button_geometry.gd.
func test_tile_is_the_mockups_size() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains("custom_minimum_size = Vector2(151, 156)"))


## SkinFrame draws its own brown border. Inside a StudentTile the box is the
## Button's own stylebox, so the frame's border would double it -- hence the
## show_border knob, which is an @export on SkinFrame's ROOT because
## overrides set on an instanced scene's CHILDREN are dropped on save.
func test_tile_turns_the_frames_own_border_off() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains("show_border = false"))


func test_variations_differ_in_ring_colour() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_type_variation_base("SkinStudentTile"), &"Button")
	assert_eq(theme.get_type_variation_base("SkinStudentTileActive"), &"Button")
	var idle := theme.get_stylebox("normal", "SkinStudentTile") as StyleBoxFlat
	var open := theme.get_stylebox("normal", "SkinStudentTileActive") as StyleBoxFlat
	assert_true(idle != null and open != null, "both variations must carry a normal stylebox")
	if idle == null or open == null:
		return
	assert_eq(idle.border_color, Color.BLACK)
	assert_eq(open.border_color, tokens.brand_primary)
	assert_eq(open.bg_color, tokens.outline_card)


## Measured off skinselection_mockup.png: an 8px black rim on the tray's
## cream, with no fill of its own.
func test_idle_tile_is_an_8px_black_rim_with_no_fill() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var idle := theme.get_stylebox("normal", "SkinStudentTile") as StyleBoxFlat
	assert_eq(idle.border_width_top, 8)
	assert_eq(idle.bg_color.a, 0.0)
