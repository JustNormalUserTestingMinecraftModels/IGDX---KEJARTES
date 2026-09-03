@tool
extends EditorScript

## One-time generator for the three reward-particle placeholder sprites
## (2026-09-03 spec section 3.3). Run it from the editor via File > Run
## (Ctrl+Shift+X).
##
## No Python / ImageMagick / Inkscape is installed on this machine, so the
## shapes are drawn straight into an Image with flat geometry -- the same
## constraint Scripts/Design/GenerateStickyNoteIcons.gd documents. They
## are deliberately crude: they exist so the bursts have something to
## throw, not as finished art. The visual team overrides these PNGs in
## place later -- KEEP THE FILE NAMES.

const SIZE := 128
const OUT_DIR := "res://Assets/Images/Particles/"

## White, so a GPUParticles2D's colour ramp can tint each sprite freely.
const INK := Color(1.0, 1.0, 1.0, 1.0)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_draw_star(), OUT_DIR + "particle_star.png")
	_save(_draw_confetti(), OUT_DIR + "particle_confetti.png")
	_save(_draw_ring(), OUT_DIR + "particle_ring.png")
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()
	print("[GenerateParticleSprites] wrote 3 placeholders to ", OUT_DIR)



func _blank() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	assert(err == OK)


## A four-point sparkle: alpha falls off with distance along whichever
## axis is farther, pinched by the nearer one, which concaves the disc
## into points without rasterising a polygon.
func _draw_star() -> Image:
	var img := _blank()
	var c := float(SIZE) * 0.5
	for y in range(SIZE):
		for x in range(SIZE):
			var dx: float = absf(float(x) - c) / c
			var dy: float = absf(float(y) - c) / c
			var far: float = maxf(dx, dy)
			var near: float = minf(dx, dy)
			var a: float = clampf(1.0 - far - near * 3.0, 0.0, 1.0)
			a = pow(a, 0.6)
			if a > 0.0:
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, a))
	return img


## A rounded rectangle chip, 60% wide and 90% tall, corners eased with a
## distance-to-inset-box test.
func _draw_confetti() -> Image:
	var img := _blank()
	var half_w := float(SIZE) * 0.30
	var half_h := float(SIZE) * 0.45
	var radius := float(SIZE) * 0.10
	var c := float(SIZE) * 0.5
	for y in range(SIZE):
		for x in range(SIZE):
			var dx: float = absf(float(x) - c) - (half_w - radius)
			var dy: float = absf(float(y) - c) - (half_h - radius)
			var dist: float = Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
			if dist <= radius:
				var a: float = clampf((radius - dist) / 2.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, a))
	return img


## A soft hollow ring -- the burst's "pop" shockwave.
func _draw_ring() -> Image:
	var img := _blank()
	var c := float(SIZE) * 0.5
	var mid := float(SIZE) * 0.38
	var thickness := float(SIZE) * 0.08
	for y in range(SIZE):
		for x in range(SIZE):
			var d: float = Vector2(float(x) - c, float(y) - c).length()
			var a: float = clampf(1.0 - absf(d - mid) / thickness, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, a))
	return img
