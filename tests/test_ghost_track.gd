@tool
extends McpTestSuite

## The ghost track behind Wirausaha and Libur.
##
## Those two rows have no target stat, so they carry no gauge. On the old
## dark slab that read acceptably. On the cream sheet they collapsed into
## near-empty strips beside the three rows that do have bars -- confirmed
## visually at the 2026-09-10 review gate, not just predicted. They now
## get the same silhouette used as a container rather than a meter: a
## texture whose alpha ramps from 0.18 at the left edge to 1.0 at the
## right.
##
## The ramp is why this must STRETCH rather than TILE. The BarFill
## textures tile, and a horizontal alpha ramp sawtooths back to
## transparent at every repeat if tiled.

const TRACK_PATH := "res://Assets/Images/UI/BarFill/track_ghost.png"
const LEFT_ALPHA := 0.18
const TOLERANCE := 0.03


func suite_name() -> String:
	return "ghost_track"


func test_the_texture_exists_at_the_expected_size() -> void:
	var tex := load(TRACK_PATH) as Texture2D
	assert_not_null(tex, "missing " + TRACK_PATH)
	assert_eq(tex.get_width(), 256, "track_ghost should be 256 wide")
	assert_eq(tex.get_height(), 48, "track_ghost should be 48 tall")


## The whole point of the asset: transparent at the left, solid at the
## right. If this inverts, the empty half is the one that looks filled.
func test_alpha_ramps_left_to_right() -> void:
	var tex := load(TRACK_PATH) as Texture2D
	assert_not_null(tex, "missing " + TRACK_PATH)
	var img := tex.get_image()
	var mid_y := int(img.get_height() / 2)
	var left := img.get_pixel(2, mid_y).a
	var right := img.get_pixel(img.get_width() - 3, mid_y).a
	assert_true(right > left,
		"alpha should rise left to right, got left=%f right=%f" % [left, right])
	assert_true(right > 0.95, "the right end should be solid, got %f" % right)


## The 9-slice left cap is a fixed region; if it is authored at a
## different alpha than the ramp's start, a seam shows at the rounded end.
func test_left_cap_matches_the_ramp_start() -> void:
	var tex := load(TRACK_PATH) as Texture2D
	assert_not_null(tex, "missing " + TRACK_PATH)
	var img := tex.get_image()
	var mid_y := int(img.get_height() / 2)
	var left := img.get_pixel(2, mid_y).a
	assert_true(abs(left - LEFT_ALPHA) < TOLERANCE,
		"left cap alpha should be ~%f, got %f" % [LEFT_ALPHA, left])


func test_the_variation_stretches_rather_than_tiles() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("panel", "PreviewTrackGhost") as StyleBoxTexture
	assert_not_null(box, "PreviewTrackGhost should be a StyleBoxTexture")
	assert_eq(box.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH,
		"a horizontal alpha ramp sawtooths if tiled")


## Documents that this asset is deliberately outside test_bar_contrast's
## 0.90 luminance floor. That floor governs BarFill *fill* textures,
## which multiply against an accent colour; a track multiplies nothing.
func test_the_ghost_track_is_not_a_fill_texture() -> void:
	var f := FileAccess.open("res://tests/test_bar_contrast.gd", FileAccess.READ)
	assert_not_null(f, "could not open test_bar_contrast.gd")
	var src := f.get_as_text()
	f.close()
	assert_false(src.contains("track_ghost"),
		"track_ghost must not be in the fill-texture roster: it is a track, "
		+ "not a fill, and is not multiplied by an accent colour")


## The two rows without a gauge must wear the ghost track, not the empty
## PreviewPillFlat that left them looking collapsed.
func test_the_gaugeless_rows_use_the_ghost_variation() -> void:
	var f := FileAccess.open("res://Scripts/AturJadwal/ActivityRow.gd", FileAccess.READ)
	assert_not_null(f, "could not open ActivityRow.gd")
	var src := f.get_as_text()
	f.close()
	assert_contains(src, "PreviewTrackGhost",
		"the non-skill rows should take the ghost track")
