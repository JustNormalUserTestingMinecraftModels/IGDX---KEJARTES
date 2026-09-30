@tool
extends McpTestSuite

## Reads pixels from textures the import may have compressed.
const TexturePixels := preload("res://tests/texture_pixels.gd")

## LombaMenari's note arrow (2026-09-28): one right-pointing, white-filled,
## dark-outlined texture in a MenariNote.tscn template, turned and tinted per
## lane, replacing the ←/→/↖/↗ glyphs Boohong and Open Sans cannot draw. The
## art is checked by pixels, the template by instancing it, and the script by
## source scan plus its pure arrow_rotation() helper, since the minigame
## cannot be played inside the editor.
##
## Must be @tool; no test here may be a coroutine.

const ARROW_PATH := "res://Assets/Images/Minigames/SeniBudaya/note_arrow.png"
const NOTE_SCENE_PATH := "res://Scenes/Minigames/SeniBudaya/MenariNote.tscn"
const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"


func suite_name() -> String:
	return "lomba_menari_arrow"


# ─── the art

func _arrow_image() -> Image:
	var img := TexturePixels.of(load(ARROW_PATH) as Texture2D)
	if img.is_compressed():
		img.decompress()
	return img


## How many rows of column `x` are opaque.
func _opaque_span(img: Image, x: int) -> int:
	var n := 0
	for y in img.get_height():
		if img.get_pixel(x, y).a > 0.5:
			n += 1
	return n


## How many columns of row `y` are opaque.
func _opaque_run_row(img: Image, y: int) -> int:
	var n := 0
	for x in img.get_width():
		if img.get_pixel(x, y).a > 0.5:
			n += 1
	return n


## Pointing right puts the narrow shaft on the left and the wide head on the
## right, so a column through the head is taller than one through the shaft.
## That alone also passes an up- or down-pointing arrow (measured: the source
## down arrow runs 93 opaque rows at 30% vs 396 at 60%, and the up rotation
## 95 vs 395), so an axis check guards the orientation too: a horizontal
## arrow's middle row runs longer than its middle column (about 445 vs 135 for
## note_arrow.png), which an up/down arrow fails.
func test_the_arrow_art_points_right() -> void:
	var img := _arrow_image()
	var w := img.get_width()
	var h := img.get_height()
	var shaft := _opaque_span(img, int(w * 0.3))
	var head := _opaque_span(img, int(w * 0.6))
	assert_gt(shaft, 0, "the shaft is opaque at 30% width")
	assert_gt(head, shaft, "the head (60%%) is taller than the shaft (30%%): %d vs %d" % [head, shaft])
	var middle_row := _opaque_run_row(img, h / 2)
	var middle_col := _opaque_span(img, w / 2)
	assert_gt(middle_row, middle_col,
		"a horizontal arrow's middle row runs longer than its middle column (rejects up/down): %d vs %d" % [middle_row, middle_col])


## A white fill takes the lane tint through self_modulate without muddying it.
func test_the_arrow_fill_is_white() -> void:
	var img := _arrow_image()
	var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	assert_gt(c.a, 0.9, "the centre is inside the arrow")
	assert_gt(minf(c.r, minf(c.g, c.b)), 0.9, "and it is white, not yellow: %s" % c)


## The dark outline is what separates the arrow from the busy stage.
func test_the_arrow_keeps_a_dark_outline() -> void:
	var img := _arrow_image()
	var darkest := 1.0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var p := img.get_pixel(x, y)
			if p.a > 0.9:
				darkest = minf(darkest, p.get_luminance())
	assert_true(darkest < 0.3, "an opaque pixel is dark (outline): darkest luminance %.2f" % darkest)


# ─── the template

## The template instantiates and wears the arrow art at the geometry
## _spawn_single_note() relies on. Bails early on a broken template instead
## of crashing on a null dereference.
func test_the_note_template_carries_the_arrow() -> void:
	var note := load(NOTE_SCENE_PATH).instantiate() as Control
	assert_true(note != null, "MenariNote.tscn's root is a Control")
	if note == null:
		return
	track(note)
	var arrow := note.get_node_or_null("Arrow") as TextureRect
	assert_true(arrow != null, "it has an Arrow TextureRect child")
	if arrow == null:
		return
	assert_eq(arrow.texture.resource_path, ARROW_PATH, "wearing note_arrow.png")
	assert_eq(arrow.anchor_right, 1.0, "Arrow fills the note horizontally")
	assert_eq(arrow.anchor_bottom, 1.0, "and vertically")
	assert_eq(arrow.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "so it scales with the note")
	assert_eq(arrow.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "without squashing")


## Swipes are read in _input(), never by the GUI, so a note must not eat them.
func test_the_note_ignores_the_mouse() -> void:
	var note := load(NOTE_SCENE_PATH).instantiate() as Control
	track(note)
	assert_eq(note.mouse_filter, Control.MOUSE_FILTER_IGNORE, "root ignores the mouse")
	assert_eq((note.get_node("Arrow") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "Arrow too")


# ─── the script

## LombaMenari.gd declares no class_name; reached through a preloaded const,
## as tests/test_lomba_menari_timing.gd does.
const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")


func _src() -> String:
	return FileAccess.get_file_as_string(SCRIPT_PATH)


func test_notes_are_instanced_from_the_template() -> void:
	var src := _src()
	assert_contains(src, "NOTE_SCENE.instantiate()", "a note comes from MenariNote.tscn")
	assert_false(src.contains("TextureRect.new()"), "not a TextureRect built in code")


func test_no_arrow_glyphs_remain() -> void:
	var src := _src()
	for glyph in ["←", "→", "↖", "↗"]:
		assert_false(src.contains(glyph), "no %s glyph: the fonts cannot draw it" % glyph)
	assert_false(src.contains("ArrowLabel"), "the glyph Label is gone")


func test_the_per_direction_texture_slots_are_gone() -> void:
	var src := _src()
	for slot in ["left_note_texture", "right_note_texture", "top_left_note_texture",
			"top_right_note_texture", "left_swiped_texture", "right_swiped_texture",
			"top_left_swiped_texture", "top_right_swiped_texture"]:
		assert_false(src.contains(slot), "%s is gone: one arrow is turned per lane" % slot)


## Tinting: a spawned note's arrow takes the lane colour through
## self_modulate, a swiped note's flash lightens that colour toward white,
## and the swipe effect reads the lane colour by name -- never the old
## hardcoded red flash the glyph Label used.
func test_the_arrow_tinting_uses_self_modulate() -> void:
	var src := _src()
	assert_contains(src, "arrow.self_modulate = tint", "a spawned note tints via self_modulate")
	assert_contains(src, ".lightened(swiped_arrow_lighten)", "a swiped note's flash lightens toward white")
	assert_contains(src, "color = left_note_color", "the swipe effect reads the lane colour, not a literal")
	var start := src.find("func _show_swipe_effect")
	assert_true(start >= 0, "_show_swipe_effect exists")
	if start < 0:
		return
	var next_func := src.find("\nfunc ", start + 1)
	var body := src.substr(start, next_func - start) if next_func >= 0 else src.substr(start)
	assert_false(body.contains("Color(1.0, 0.2, 0.2)"), "no hardcoded red flash inside _show_swipe_effect")


## The art points right (angle 0), so each lane's turn is its direction's angle.
func test_arrow_rotation_turns_the_art_toward_each_lane() -> void:
	var cases := {
		MenariScript.NoteType.RIGHT: 0.0,
		MenariScript.NoteType.LEFT: PI,
		MenariScript.NoteType.TOP_LEFT: -0.75 * PI,
		MenariScript.NoteType.TOP_RIGHT: -0.25 * PI,
	}
	for type in cases:
		var got: float = MenariScript.arrow_rotation(type)
		var want: float = cases[type]
		assert_true(absf(angle_difference(got, want)) < 0.001,
			"lane %d turns %.3f rad, wants %.3f" % [type, got, want])
