@tool
extends McpTestSuite

## EndCutscene (2026-09-05): the win/lose beat between StatCheck and
## RunResult. One scene, dressed by GameState.run_failed.
##
## Structural checks on a bare instantiate() plus source scans -- the white
## fade-out, the badge slam and the button reveal are a tween/timer chain the
## runner cannot await (see test_lobby.gd's no-coroutine note). Suite is
## @tool and no test is a coroutine.

const _SCENE := "res://Scenes/EndGame/EndCutscene.tscn"
const _SCRIPT := "res://Scripts/EndGame/EndCutscene.gd"


func suite_name() -> String:
	return "end_cutscene"


func test_badges_and_backdrops_exist_on_disk() -> void:
	for p in ["res://Assets/Images/UI/Placeholders/stamp_lulus.svg",
			"res://Assets/Images/UI/Placeholders/stamp_gagal.svg",
			"res://Assets/Images/CG/cg_lose.jpg"]:
		assert_true(ResourceLoader.exists(p), p + " exists")
		assert_true(load(p) is Texture2D, p + " imports as a texture")


## Godot rasterises SVG through ThorVG, whose <text> support varies by
## version -- a dropped <text> imports as an empty outlined box with no word
## in it, which looks fine in the file and wrong in the game. This samples
## the badge's interior, a band that the tilted rect's own stroke provably
## cannot reach (the -12 degree rotation moves the horizontal edges at most
## ~28px, well clear of it), so any opaque pixel found there is lettering.
func test_the_stamps_actually_rendered_their_word() -> void:
	for p in ["res://Assets/Images/UI/Placeholders/stamp_lulus.svg",
			"res://Assets/Images/UI/Placeholders/stamp_gagal.svg"]:
		# CACHE_MODE_IGNORE: the editor keeps imported textures alive for the
		# session, so a plain load() here can hand back the pre-reimport
		# rasterisation and quietly test the wrong bytes.
		var tex: Texture2D = ResourceLoader.load(
			p, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		var img: Image = tex.get_image()
		assert_not_null(img, p + " rasterised to an image")
		var w := img.get_width()
		var h := img.get_height()
		var opaque := 0
		for y in range(int(h * 0.44), int(h * 0.66)):
			for x in range(int(w * 0.35), int(w * 0.65)):
				if img.get_pixel(x, y).a > 0.1:
					opaque += 1
		assert_gt(opaque, 40,
			"%s has no lettering inside its frame (%d opaque px in a %dx%d " % [p, opaque, w, h] +
			"image) -- the word did not rasterise; redraw it as paths")
