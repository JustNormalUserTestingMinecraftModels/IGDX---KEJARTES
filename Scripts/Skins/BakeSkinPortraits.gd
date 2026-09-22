extends SceneTree

## One-off bake of each student's flat skin portrait (the 1280x1280 picture
## StudentCard, StudentList, AturJadwal and StatCheck show) from their lobby
## face rig. The artist delivers a skin as a new rig Base layer only; the flat
## portrait is that rig at rest (Base, Sclera, Pupil clipped to the Sclera,
## Eyelashes, Eyebrows, plus any extra always-visible layer such as Marcel's
## Glasses), so this composes those layers with Image.blend_rect.
##
## Run headless from the project root:
##   Godot --headless --path . --script res://Scripts/Skins/BakeSkinPortraits.gd
## It first bakes each DEFAULT portrait and prints its mean difference from
## the shipped MuridPotrait/<Name>.png -- the check that the recipe is right --
## then writes Assets/Images/Skins/<Name>/<name>_portrait_skin1.png.
## Not used at runtime.

const NAMES := ["Andi", "Citra", "Doni", "Marcel", "Shinta", "Thea"]
## Layers never part of the resting face.
const SKIP := ["Eyelid"]


func _init() -> void:
	for n in NAMES:
		var lower: String = n.to_lower()
		var rig := (load("res://Scenes/Lobby/%sFace.tscn" % n) as PackedScene).instantiate()
		var default_img := _compose(rig, "")
		var shipped := _raw("res://Assets/Images/MuridPotrait/%s.png" % n)
		print("%s default bake diff: %.4f" % [n, _mean_diff(default_img, shipped)])
		var skin_base := "res://Assets/Images/Skins/%s/%s_base_skin1.png" % [n, lower]
		var out := _compose(rig, skin_base)
		var out_path := ProjectSettings.globalize_path("res://Assets/Images/Skins/%s/%s_portrait_skin1.png" % [n, lower])
		print("  wrote %s: %s" % [out_path, error_string(out.save_png(out_path))])
		rig.free()
	quit()


## The rig's canvas flattened. `base_override` replaces the Base layer's
## texture when non-empty.
func _compose(rig: Node, base_override: String) -> Image:
	var canvas := rig.get_node("Canvas") as Control
	var out := Image.create_empty(1280, 1280, false, Image.FORMAT_RGBA8)
	var sclera_img: Image = null
	var sclera_pos := Vector2i.ZERO
	for child in canvas.get_children():
		var layer := child as TextureRect
		if layer == null or layer.texture == null or String(layer.name) in SKIP:
			continue
		var path := layer.texture.resource_path
		if layer.name == &"Base" and base_override != "":
			path = base_override
		var img := _raw(path)
		var rect_size := Vector2i(layer.size.round())
		if img.get_size() != rect_size:
			img.resize(rect_size.x, rect_size.y, Image.INTERPOLATE_LANCZOS)
		var pos := Vector2i(layer.position.round())
		if layer.name == &"Sclera":
			sclera_img = img
			sclera_pos = pos
		if layer.name == &"Pupil" and sclera_img != null:
			_clip_to(img, pos, sclera_img, sclera_pos)
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), pos)
	return out


## Multiplies `img`'s alpha by the mask's alpha where they overlap (and zero
## elsewhere) -- eye_mask.gdshader's job, done on the CPU.
func _clip_to(img: Image, pos: Vector2i, mask: Image, mask_pos: Vector2i) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var m := Vector2i(x, y) + pos - mask_pos
			var a := 0.0
			if m.x >= 0 and m.y >= 0 and m.x < mask.get_width() and m.y < mask.get_height():
				a = mask.get_pixel(m.x, m.y).a
			var c := img.get_pixel(x, y)
			c.a *= a
			img.set_pixel(x, y, c)


func _raw(res_path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _mean_diff(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		b.resize(a.get_width(), a.get_height())
	var total := 0.0
	var step := 4
	var count := 0
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			# Premultiplied: fully transparent pixels differ only in hidden
			# RGB (the shipped files store white there, the bake black).
			total += (absf(p.r * p.a - q.r * q.a) + absf(p.g * p.a - q.g * q.a) \
				+ absf(p.b * p.a - q.b * q.a) + absf(p.a - q.a)) / 4.0
			count += 1
	return total / count
