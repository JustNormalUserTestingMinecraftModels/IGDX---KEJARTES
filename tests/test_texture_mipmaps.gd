@tool
extends McpTestSuite

## Targeted mipmaps (2026-09-22 crispness pass).
##
## The project draws canvas textures with Linear Mipmap filtering
## (`default_texture_filter = 3`, pinned by tests/test_project_hygiene.gd).
## A mipmapped sampler only ever reads a mip chain that the importer actually
## generated, so the two halves of this suite are one argument:
##
##   TARGETS      -- measured downscale offenders that MUST carry a chain, or
##                   they minify from a single bilinear tap and shimmer.
##   MUST_STAY_CRISP -- art whose sharpness IS the design, which must NOT carry
##                   one. With a single mip level the mipmapped filter is a
##                   no-op on them, which is the whole reason the global
##                   default could be flipped without a blur pass.
##
## Ratios below were measured live at 1080x1920 through tests/layout_frame.gd,
## not derived from .tscn offsets -- several static derivations were wrong
## (the Lobby faces are runtime-assigned by StudentSkins and no static parse
## sees them at all).
##
## Must be @tool, and no test here may be a coroutine.

## res:// source path -> the measured worst-case downscale ratio, for the
## record. Nothing asserts the number; it is why each entry is on the list.
const TARGETS := {
	"res://Assets/Images/UI/stickynotes.png": 11.91,
	"res://Assets/Images/Shop/UI/chat_bubble_tail.svg": 7.39,
	"res://Assets/Images/UI/Placeholders/arrow.png": 7.11,
	"res://Assets/Images/UI/skin_switch.png": 5.63,
	"res://Assets/Images/UI/setting.png": 5.33,
	"res://Assets/Images/UI/Nav/return_button.png": 5.33,
	"res://Assets/Images/UI/star.png": 5.10,
	"res://Assets/Images/UI/uang.png": 4.29,
	"res://Assets/Images/UI/icon_daily_login.png": 4.01,
	"res://Assets/Images/UI/Placeholders/shadow_ellipse.png": 14.22,
	"res://Assets/Images/DaySummary/icon_chevron_up.png": 4.00,
	"res://Assets/Images/Achievements/achievement_button.png": 3.74,
	"res://Assets/Images/Achievements/notice_icon.png": 3.56,
	"res://Assets/Images/EndGame/ujian_sekolah.png": 4.59,
	"res://Assets/Images/EndGame/ujian_nasional.png": 3.43,
	"res://Assets/Images/Particles/particle_star.png": 3.20,
	# The six Lobby faces. loby.gd gives each runtime rig the rect of its
	# seat's Portrait node, measured at 365-400 px from a 1280 px source.
	"res://Assets/Images/MuridPotrait/Andi/andi_base.png": 3.20,
	"res://Assets/Images/MuridPotrait/Citra/citra_base.png": 3.20,
	"res://Assets/Images/MuridPotrait/Doni/doni_base.png": 3.50,
	"res://Assets/Images/MuridPotrait/Marcel/marcel_base.png": 3.20,
	"res://Assets/Images/MuridPotrait/Shinta/shinta_base.png": 3.50,
	"res://Assets/Images/MuridPotrait/Thea/thea_base.png": 3.51,
	# The twelve day outfits (2026-09-25). DaySummaryAvatar draws each through
	# its student's SPLASH_CROP into the 269 px result-card frame: 2.80 is the
	# widest crop (Andi, 752 px) over FRAME_SIZE.x, exact by construction. The
	# batik pattern is the finest repeating detail in the game at that ratio.
	"res://Assets/Images/SplashArtMurid/Seragam/splash_andi_batik.png": 2.80,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_andi_pramuka.png": 2.80,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_citra_batik.png": 2.70,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_citra_pramuka.png": 2.70,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_doni_batik.png": 2.61,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_doni_pramuka.png": 2.61,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_marcel_batik.png": 2.74,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_marcel_pramuka.png": 2.74,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_shinta_batik.png": 2.63,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_shinta_pramuka.png": 2.63,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_thea_batik.png": 2.67,
	"res://Assets/Images/SplashArtMurid/Seragam/splash_thea_pramuka.png": 2.67,
	# Minigame sprites. CLAUDE.md puts Scenes/Minigames/** out of scope for
	# the design system, but an .import flag is not a design decision, and
	# these are the project's worst ratios on art that is always moving.
	"res://Assets/Images/Textures/bola.png": 12.49,
	"res://Assets/Images/Textures/puck.png": 10.15,
	"res://Assets/Images/Textures/batik_tool_pencil.png": 8.77,
	"res://Assets/Images/Textures/batik_tool_canting.png": 8.77,
	"res://Assets/Images/Textures/batik_tool_pewarna.png": 8.77,
	"res://Assets/Images/Textures/batik_tool_kompor.png": 8.77,
	"res://Assets/Images/Textures/raket_1.png": 3.52,
}

## Art drawn at or near 1:1 whose sharpness is the point. A mip chain here
## would visibly soften it under the mipmapped filter.
const MUST_STAY_CRISP := [
	# Documented 20x19 motif period; Transition crops and tiles it.
	"res://Assets/Images/UI/BarFill/fill_akademis.png",
	"res://Assets/Images/UI/BarFill/fill_energi.png",
	"res://Assets/Images/UI/BarFill/fill_mood.png",
	"res://Assets/Images/UI/BarFill/track_ghost.png",
	# 26x26, tiled through the node's texture_repeat.
	"res://Assets/Images/Shop/UI/tray_dots.png",
]


func suite_name() -> String:
	return "texture_mipmaps"


## The `mipmaps/generate` flag as written in `source`'s .import sidecar.
## Reads the file rather than the imported texture so a failure names the
## thing a fix has to edit.
func _generates_mipmaps(source: String) -> bool:
	var text := FileAccess.get_file_as_string(source + ".import")
	return text.contains("mipmaps/generate=true")


func test_every_target_import_generates_mipmaps() -> void:
	var missing := PackedStringArray()
	for source in TARGETS:
		if not FileAccess.file_exists(source + ".import"):
			missing.append(String(source).get_file() + " (no .import)")
		elif not _generates_mipmaps(source):
			missing.append(String(source).get_file())
	assert_eq(missing.size(), 0,
		"these minify hard enough to shimmer and need mipmaps/generate=true: "
			+ ", ".join(missing))


## The mip chain has to survive into the imported .ctex, not just sit in the
## sidecar: an .import edit that was never reimported leaves the flag set and
## the texture flat, and nothing else would catch that.
func test_every_target_texture_actually_carries_a_chain() -> void:
	var flat := PackedStringArray()
	for source in TARGETS:
		if not ResourceLoader.exists(source):
			flat.append(String(source).get_file() + " (missing)")
			continue
		var tex: Texture2D = ResourceLoader.load(source, "", ResourceLoader.CACHE_MODE_IGNORE)
		var img: Image = null if tex == null else tex.get_image()
		if img == null or not img.has_mipmaps():
			flat.append(String(source).get_file())
	assert_eq(flat.size(), 0,
		"flag set but no chain in the imported texture -- reimport these: "
			+ ", ".join(flat))


## The premise that lets `default_texture_filter = 3` be a global setting.
func test_crisp_art_carries_no_chain_to_sample() -> void:
	var blurred := PackedStringArray()
	for source in MUST_STAY_CRISP:
		if not ResourceLoader.exists(source):
			blurred.append(String(source).get_file() + " (missing)")
			continue
		var tex: Texture2D = ResourceLoader.load(source, "", ResourceLoader.CACHE_MODE_IGNORE)
		var img: Image = null if tex == null else tex.get_image()
		if img != null and img.has_mipmaps():
			blurred.append(String(source).get_file())
	assert_eq(blurred.size(), 0,
		"tiled/crisp art must keep a single mip level so the mipmapped filter "
			+ "stays a no-op on it: " + ", ".join(blurred))


## Guards the other direction: a bulk flip of every .import would defeat the
## per-asset discipline and soften small glyphs and 9-slices across the game.
## The number is a ceiling, not a target -- raise it deliberately when a
## measured offender is added to TARGETS.
func test_mipmaps_stay_targeted_not_global() -> void:
	var total := 0
	var mipmapped := 0
	var stack: Array[String] = ["res://Assets/Images"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".import"):
				continue
			total += 1
			var text := FileAccess.get_file_as_string(dir_path.path_join(f))
			if text.contains("mipmaps/generate=true"):
				mipmapped += 1
		for sub in d.get_directories():
			stack.append(dir_path.path_join(sub))
	assert_true(total > 300, "sanity: expected the full texture set, saw %d" % total)
	# 45 until 2026-09-25, when the twelve day outfits joined TARGETS above.
	assert_true(mipmapped <= 57,
		"mipmaps are per-asset and measured, not a bulk flip: %d of %d imports "
			% [mipmapped, total] + "generate them")
