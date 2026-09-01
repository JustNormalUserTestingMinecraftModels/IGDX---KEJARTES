@tool
extends EditorScript

## One-time generator for the three DayStickyNote placeholder icons that have
## no real art yet: a coin (Wirausaha), a crescent (Istirahat) and a flag
## (national holiday). Run it from the editor via File > Run (Ctrl+Shift+X).
## The visual team overrides these PNGs in place later -- keep the file names.
##
## No Python / ImageMagick / Inkscape is installed on this machine, so the
## glyphs are drawn straight into an Image with flat geometry. They are
## deliberately crude: they exist so layout and wiring have something to
## show, not as finished art.

const SIZE := 256
const OUT_DIR := "res://Assets/Images/AturJadwal/"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_draw_coin(),   OUT_DIR + "icon_wirausaha_placeholder.png")
	_save(_draw_crescent(), OUT_DIR + "icon_istirahat_placeholder.png")
	_save(_draw_flag(),   OUT_DIR + "icon_libur_nasional_placeholder.png")
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()
	print("[GenerateStickyNoteIcons] wrote 3 placeholders to ", OUT_DIR)

func _blank() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)

func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	assert(err == OK)

# --- glyph helpers -------------------------------------------------------

func _fill_disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var r2 := r * r
	for y in range(SIZE):
		for x in range(SIZE):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)

func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	for y in range(max(0, y0), min(SIZE, y0 + h)):
		for x in range(max(0, x0), min(SIZE, x0 + w)):
			img.set_pixel(x, y, col)

func _draw_coin() -> Image:
	var img := _blank()
	var teal := Color("00a389")          # matches DesignTokens.cat_wirausaha
	_fill_disc(img, 128, 128, 96, teal)
	_fill_disc(img, 128, 128, 70, teal.darkened(0.18))
	_fill_disc(img, 128, 128, 62, teal)
	return img

func _draw_crescent() -> Image:
	var img := _blank()
	var violet := Color("6b4fe0")        # matches DesignTokens.cat_istirahat
	_fill_disc(img, 128, 128, 92, violet)
	_fill_disc(img, 168, 108, 82, Color(0, 0, 0, 0))   # bite out -> crescent
	return img

func _draw_flag() -> Image:
	var img := _blank()
	var gold := Color("ffc93c")          # matches DesignTokens.cat_libur
	var pole := gold.darkened(0.35)
	_fill_rect(img, 60, 36, 12, 184, pole)              # pole
	_fill_rect(img, 72, 44, 120, 78, gold)              # banner
	return img
