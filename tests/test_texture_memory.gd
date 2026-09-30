@tool
extends McpTestSuite

## Texture memory budget (2026-09-30 mobile performance pass).
##
## A lossless import sits in video memory at 4 bytes per pixel, so one
## 1080x1920 splash is 8 MB before its mip chain and the Lobby alone held
## 348 MB of textures, measured in the running game. A VRAM-compressed import
## with `compress/high_quality=true` is ASTC 4x4 on a phone and BPTC on
## desktop: 1 byte per pixel, a quarter of the memory, and the GPU samples it
## without unpacking.
##
## So every image at or above PIXEL_BUDGET must be imported that way. Small
## art stays lossless on purpose: icons, 9-slices and the tiled bar fills are
## where block compression shows, and together they are under a tenth of the
## total.
##
## The suite reads the .import sidecars and the image headers, never the
## textures: loading every image to measure it would itself cost over a
## gigabyte.
##
## Must be @tool, and no test here may be a coroutine.

## Pixels (width x height) at which an image must be VRAM-compressed. 500,000
## is a little under 720x720, and 2 MB uncompressed.
const PIXEL_BUDGET := 500_000

## Where the scan starts.
const ROOT := "res://Assets/Images"

## res:// source path -> why it stays lossless although it is over the budget.
## A reviewed, permanent exception; keep the reason honest.
const ALLOWED := {
	"res://Assets/Images/MuridPortrait/Andi/andi_base.png": FACE_BASE,
	"res://Assets/Images/MuridPortrait/Citra/citra_base.png": FACE_BASE,
	"res://Assets/Images/MuridPortrait/Doni/doni_base.png": FACE_BASE,
	"res://Assets/Images/MuridPortrait/Marcel/marcel_base.png": FACE_BASE,
	"res://Assets/Images/MuridPortrait/Shinta/shinta_base.png": FACE_BASE,
	"res://Assets/Images/MuridPortrait/Thea/thea_base.png": FACE_BASE,
	"res://Assets/Images/Skins/Andi/andi_base_skin1.png": FACE_BASE,
	"res://Assets/Images/Skins/Citra/citra_base_skin1.png": FACE_BASE,
	"res://Assets/Images/Skins/Doni/doni_base_skin1.png": FACE_BASE,
	"res://Assets/Images/Skins/Marcel/marcel_base_skin1.png": FACE_BASE,
	"res://Assets/Images/Skins/Shinta/shinta_base_skin1.png": FACE_BASE,
	"res://Assets/Images/Skins/Thea/thea_base_skin1.png": FACE_BASE,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_andi_batik.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_andi_pramuka.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_citra_batik.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_citra_pramuka.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_doni_batik.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_doni_pramuka.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_marcel_batik.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_marcel_pramuka.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_shinta_batik.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_shinta_pramuka.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_thea_batik.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_thea_pramuka.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/splash_andi.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/splash_citra.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/splash_doni.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/splash_marcel.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/splash_shinta.png": STUDENT_ART,
	"res://Assets/Images/SplashArtMurid/splash_thea.png": STUDENT_ART,
	"res://Assets/Images/MuridPortrait/Andi.png": STUDENT_ART,
	"res://Assets/Images/MuridPortrait/Citra.png": STUDENT_ART,
	"res://Assets/Images/MuridPortrait/Doni.png": STUDENT_ART,
	"res://Assets/Images/MuridPortrait/Marcel.png": STUDENT_ART,
	"res://Assets/Images/MuridPortrait/Shinta.png": STUDENT_ART,
	"res://Assets/Images/MuridPortrait/Thea.png": STUDENT_ART,
}

## Why the twelve face bases stay lossless. Each has its eye sockets cut out
## to the pixel, and the eye layers behind are placed to plug those holes
## exactly. Block compression moves the alpha edge: compressed, Thea's base
## left 2 cut-out pixels showing the Lobby through her face
## (tests/test_face_rig_roster.gd, test_no_eye_cut_out_is_left_see_through).
const FACE_BASE := "pixel-exact eye cut-outs; compression opens see-through pixels"

## Why the 24 student portraits, default splashes and day outfits stay
## lossless. The owner judged them on 2026-09-29: VRAM compression, even at
## high quality, left faint block artifacts on their smooth shading and line
## work (tests/test_student_skins.gd, test_student_art_is_lossless). That is
## an art call, so it is not reversed here; DEBT.md carries the memory it
## costs and how to flip it.
const STUDENT_ART := "owner's call 2026-09-29: block artifacts on the character art"

## Ceiling on the memory every image under ROOT would take if all were loaded
## at once, in MiB, mip chains included. Nothing loads them all; the number
## catches a slide back toward lossless, which stood at 1309. It was 632 when
## set, with headroom so that ordinary new art does not trip it: raise it on
## purpose when the game really has grown.
const TOTAL_BUDGET_MIB := 700.0


func suite_name() -> String:
	return "texture_memory"


## Every image source under ROOT that has an .import sidecar.
func _sources() -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array[String] = [ROOT]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for sub in d.get_directories():
			stack.append(dir_path.path_join(sub))
		for f in d.get_files():
			var ext := f.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg"] and d.file_exists(f + ".import"):
				out.append(dir_path.path_join(f))
	return out


## Width and height from the file header, Vector2i.ZERO if unreadable. PNG
## keeps them at a fixed offset; JPEG keeps them in its start-of-frame
## segment, found by walking the segment lengths.
func _pixel_size(source: String) -> Vector2i:
	var f := FileAccess.open(source, FileAccess.READ)
	if f == null:
		return Vector2i.ZERO
	f.big_endian = true
	if source.get_extension().to_lower() == "png":
		f.seek(16)
		var w := f.get_32()
		return Vector2i(w, f.get_32())
	f.seek(2)
	while f.get_position() + 9 < f.get_length():
		if f.get_8() != 0xFF:
			continue
		var marker := f.get_8()
		if marker in [0xC0, 0xC1, 0xC2]:
			f.seek(f.get_position() + 3)
			var h := f.get_16()
			return Vector2i(f.get_16(), h)
		var length := f.get_16()
		f.seek(f.get_position() + length - 2)
	return Vector2i.ZERO


## True when the sidecar asks for a high-quality VRAM-compressed import.
func _is_vram_compressed(source: String) -> bool:
	var text := FileAccess.get_file_as_string(source + ".import")
	return text.contains("compress/mode=2") and text.contains("compress/high_quality=true")


## Bytes `source` takes in video memory with the import it has now.
func _memory_bytes(source: String) -> float:
	var size := _pixel_size(source)
	var text := FileAccess.get_file_as_string(source + ".import")
	var bytes := float(size.x * size.y) * (1.0 if _is_vram_compressed(source) else 4.0)
	if text.contains("mipmaps/generate=true"):
		bytes *= 4.0 / 3.0
	return bytes


func test_the_header_reader_reads_both_formats() -> void:
	assert_eq(_pixel_size("res://Assets/Images/SplashArtMurid/splash_thea.png"),
		Vector2i(1080, 1920), "PNG header")
	assert_eq(_pixel_size("res://Assets/Images/CG/cg4.jpg").x > 0, true, "JPEG header")


func test_large_images_are_vram_compressed() -> void:
	var over := PackedStringArray()
	for source in _sources():
		if ALLOWED.has(source):
			continue
		var size := _pixel_size(source)
		if size.x * size.y >= PIXEL_BUDGET and not _is_vram_compressed(source):
			over.append("%s (%dx%d)" % [source.get_file(), size.x, size.y])
	assert_eq(over.size(), 0,
		"%d image(s) over %d px are imported lossless; set compress/mode=2 and "
			% [over.size(), PIXEL_BUDGET]
			+ "compress/high_quality=true, or add them to ALLOWED with a reason: "
			+ ", ".join(over.slice(0, 12)))


## The compression has to reach the imported texture, not just the sidecar:
## an .import edit that was never reimported leaves the flag set and the
## texture at full size. One texture stands for the pass.
func test_a_compressed_import_really_is_compressed() -> void:
	var tex: Texture2D = load("res://Assets/Images/MuridPortrait/Meja/kiri_atas.png")
	var img: Image = null if tex == null else tex.get_image()
	assert_true(img != null and img.is_compressed(),
		"kiri_atas.png is flagged VRAM-compressed but the imported texture is not; reimport")


func test_allowed_entries_still_exist_and_still_need_the_exception() -> void:
	var stale := PackedStringArray()
	for source in ALLOWED:
		if not FileAccess.file_exists(source) or _is_vram_compressed(source):
			stale.append(String(source).get_file())
	assert_eq(stale.size(), 0, "stale ALLOWED entries: " + ", ".join(stale))


func test_total_texture_memory_stays_under_the_ceiling() -> void:
	var total := 0.0
	for source in _sources():
		total += _memory_bytes(source)
	var mib := total / 1048576.0
	assert_true(mib <= TOTAL_BUDGET_MIB,
		"all images together take %.0f MiB of video memory, over the %.0f MiB ceiling"
			% [mib, TOTAL_BUDGET_MIB])
