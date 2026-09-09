@tool
extends McpTestSuiteCompat

## WinLineup (2026-09-09): the win screen's roster arrangement. Doni is
## pinned to the front slot; everyone else fills in roster order. Plain
## static functions over Dictionaries, so these are behavioural tests
## rather than the source scans this project falls back on for scenes it
## cannot instantiate headlessly.

const _SCRIPT := "res://Scripts/EndGame/WinLineup.gd"

const _SPLASHES := ["andi", "citra", "doni", "marcel", "shinta", "thea"]


func suite_name() -> String:
	return "win_lineup"


func test_the_win_art_imported() -> void:
	var bg := "res://Assets/Images/CG/Win/win_background.png"
	assert_true(ResourceLoader.exists(bg), bg + " exists")
	assert_true(load(bg) is Texture2D, bg + " imports as a texture")
	for n in _SPLASHES:
		var p := "res://Assets/Images/CG/Win/win_%s.png" % n
		assert_true(ResourceLoader.exists(p), p + " exists")
		assert_true(load(p) is Texture2D, p + " imports as a texture")


func test_the_shadow_ellipse_imported_and_is_soft() -> void:
	var p := "res://Assets/Images/UI/Placeholders/shadow_ellipse.png"
	assert_true(ResourceLoader.exists(p), p + " exists")
	var tex: Texture2D = ResourceLoader.load(
		p, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	var img: Image = tex.get_image()
	assert_not_null(img, "the ellipse rasterised")
	# Opaque at the centre, clear at the corner, and genuinely soft in
	# between -- a hard-edged ellipse would read as a sticker, not a shadow.
	var w := img.get_width()
	var h := img.get_height()
	assert_gt(img.get_pixel(w / 2, h / 2).a, 0.9, "solid at the centre")
	assert_true(img.get_pixel(2, 2).a < 0.05, "clear at the corner")
	var mid := img.get_pixel(int(w * 0.75), h / 2).a
	assert_true(mid > 0.05 and mid < 0.9,
		"partially transparent partway out (got %f) -- the falloff is a gradient" % mid)
