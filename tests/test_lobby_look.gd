@tool
extends McpTestSuite

## The Lobby's look on the rest of the game (spec
## docs/superpowers/specs/2026-09-28-lobby-look-everywhere-design.md, plan
## docs/superpowers/plans/2026-09-28-lobby-look-everywhere.md): where each
## screen places the grade, the light, the shafts, the bloom and the parallax.
##
## Reads saved scenes through tests/scene_census.gd and never instances them.
## Must be @tool, and no test here may be a coroutine.

const Census := preload("res://tests/scene_census.gd")

const LIGHT_POOL := "res://Scenes/Look/LightPool.tscn"
const SUN_SHAFTS := "res://Scenes/Look/SunShafts.tscn"
const AMBIENT_GLOW := "res://Scenes/Look/AmbientGlow.tscn"
const MOOD_TINT := "res://Scenes/Look/MoodTint.tscn"
const WIN_STAGE := "res://Scenes/EndGame/WinStage.tscn"
const PARALLAX_SCRIPT := "res://Scripts/UI/ParallaxDiorama.gd"
const GRADE := "res://Scripts/Shaders/illustration_grade_material.tres"
const BUTTON_TYPES := ["Button", "TextureButton", "CheckButton", "CheckBox",
	"OptionButton", "MenuButton", "LinkButton"]
## The drift of a flat screen: it has no nearer band, so its one plane moves
## at full depth against the UI (planning amendment 5).
const FLAT_DEPTH := 1.0
## AmbientGlow.gd's own glow_threshold default, read when a scene leaves it.
const GLOW_DEFAULT := 0.9

const SHOP_HUB := "res://Scenes/Koperasi/ShopHub.tscn"
const COSMETIC_SHOP := "res://Scenes/Koperasi/CosmeticShop.tscn"
const TES_NOTICE := "res://Scenes/EndGame/TesNotice.tscn"
const STAT_CHECK := "res://Scenes/EndGame/StatCheck.tscn"
const EXAM_PROGRESS := "res://Scenes/EndGame/ExamProgress.tscn"
const END_CUTSCENE := "res://Scenes/EndGame/EndCutscene.tscn"
const RUN_RESULT := "res://Scenes/EndGame/RunResult.tscn"

## Screen -> its Room's children, in draw order.
const ROOMS := {
	SHOP_HUB: ["Backdrop", "Light", "Shafts", "Parallax"],
	COSMETIC_SHOP: ["Backdrop", "Light", "Shafts", "Parallax"],
	TES_NOTICE: ["Backdrop", "Tint", "Light", "Shafts", "Parallax"],
	STAT_CHECK: ["Backdrop", "Tint", "Light", "Shafts", "Parallax"],
	EXAM_PROGRESS: ["Backdrop", "Light", "Shafts"],
	END_CUTSCENE: ["WinStage"],
	RUN_RESULT: ["WinStage"],
}

## Screen -> its measured glow_threshold, or null where no threshold bloomed
## the light without fogging the backdrop, so the screen places no Glow.
## Recipe M writes the measured values.
const BLOOM := {
	SHOP_HUB: null,
	COSMETIC_SHOP: null,
	TES_NOTICE: 0.9,
	STAT_CHECK: 0.9,
	EXAM_PROGRESS: 0.9,
	END_CUTSCENE: 0.9,
	RUN_RESULT: 0.9,
}


func suite_name() -> String:
	return "lobby_look"


## `World` is a CanvasLayer at -1 holding only `Room`; `Room` is a unique,
## tap-through Control whose children are `want`, in order; nothing tappable
## sits under World; each kit piece is the right instance; a Parallax driver
## moves every other band at FLAT_DEPTH and overscans the full-rect ones.
func _assert_room(scene_path: String, want: Array) -> void:
	var c := Census.of(scene_path)
	var world := Census.entry(c, "World")
	assert_eq(world.get("type"), "CanvasLayer", scene_path + ": World must be a CanvasLayer")
	assert_eq(Census.prop(world, "layer"), -1, scene_path + ": World draws at -1, below the UI")
	assert_eq(Census.children_of(c, ".").find("World"), 0, scene_path + ": World is drawn first")
	assert_eq(Census.children_of(c, "World"), ["Room"] as Array[String],
		scene_path + ": World holds one Room")
	var room := Census.entry(c, "World/Room")
	assert_eq(room.get("type"), "Control", scene_path + ": Room is a Control")
	assert_eq(Census.prop(room, "unique_name_in_owner"), true, scene_path + ": %Room")
	assert_eq(Census.prop(room, "mouse_filter"), Control.MOUSE_FILTER_IGNORE,
		scene_path + ": Room never eats a tap")
	assert_eq(Census.children_of(c, "World/Room"), Array(want, TYPE_STRING, &"", null),
		scene_path + ": the Room's bands, in draw order")
	for e in c:
		if (e["path"] as String).begins_with("World/"):
			assert_false(BUTTON_TYPES.has(e["type"]),
				"%s: %s is tappable and must stay on layer 0" % [scene_path, e["path"]])
	_assert_piece(c, scene_path, "World/Room/Light", LIGHT_POOL)
	_assert_piece(c, scene_path, "World/Room/Shafts", SUN_SHAFTS)
	_assert_piece(c, scene_path, "World/Room/Tint", MOOD_TINT)
	_assert_piece(c, scene_path, "World/Room/WinStage", WIN_STAGE)
	if want.has("Backdrop"):
		var mat: Variant = Census.prop(Census.entry(c, "World/Room/Backdrop"), "material")
		assert_true(mat is Material and (mat as Material).resource_path == GRADE,
			scene_path + ": the backdrop wears the plain grade")
	if want.has("Parallax"):
		_assert_flat_parallax(c, scene_path, want)


## When the scene has a node at `path`, it is an instance of `scene`.
func _assert_piece(c: Array[Dictionary], scene_path: String, path: String, scene: String) -> void:
	var e := Census.entry(c, path)
	if e.is_empty():
		return
	assert_eq(e.get("instance"), scene, "%s: %s is an instance of %s" % [scene_path, path, scene])


func _assert_flat_parallax(c: Array[Dictionary], scene_path: String, want: Array) -> void:
	var driver := Census.entry(c, "World/Room/Parallax")
	var script: Variant = Census.prop(driver, "script")
	assert_true(script is Script and (script as Script).resource_path == PARALLAX_SCRIPT,
		scene_path + ": Parallax runs ParallaxDiorama")
	var depths: Dictionary = Census.prop(driver, "depth_by_child", {})
	var overscan: Array = Census.prop(driver, "overscan_children", [])
	for band: String in want:
		if band == "Parallax":
			continue
		assert_eq(float(depths.get(band, 0.0)), FLAT_DEPTH,
			"%s: %s drifts with the picture" % [scene_path, band])
		if band in ["Backdrop", "Tint", "Light", "Shafts"]:
			assert_true(overscan.has(StringName(band)),
				"%s: %s fills the screen, so it is overscanned" % [scene_path, band])


## Each measured screen keeps exactly one Glow, second in the root, at its
## measured threshold; a screen that measured no clean threshold has none.
func test_every_bloom_decision_is_pinned() -> void:
	for scene_path in BLOOM:
		var c := Census.of(scene_path)
		var glows := 0
		for e in c:
			if e["instance"] == AMBIENT_GLOW:
				glows += 1
		if BLOOM[scene_path] == null:
			assert_eq(glows, 0, scene_path + ": measured no clean bloom, so it places no Glow")
			continue
		assert_eq(glows, 1, scene_path + ": one Glow")
		assert_eq(Census.children_of(c, ".").find("Glow"), 1,
			scene_path + ": Glow is the root's second child, right after World")
		assert_eq(float(Census.prop(Census.entry(c, "Glow"), "glow_threshold", GLOW_DEFAULT)),
			float(BLOOM[scene_path]), scene_path + ": the measured threshold")


func test_every_lit_screen_wears_the_lobby_room() -> void:
	for scene_path in ROOMS:
		_assert_room(scene_path, ROOMS[scene_path])


## The shops blur their Room on layer 0, so the light blurs with the picture
## and the tiles and the back button stay sharp above it.
## Glow is left out of the order: test_every_bloom_decision_is_pinned owns it,
## and a screen that measured no clean bloom has none.
func test_the_shops_blur_the_room_under_their_ui() -> void:
	assert_eq(_drawn(SHOP_HUB), ["World", "BlurLayer", "Tiles", "BackButton"] as Array[String],
		"ShopHub: the room, the blur, then the UI")
	assert_eq(_drawn(COSMETIC_SHOP),
		["World", "BlurLayer", "ComingSoonLabel", "BackButton"] as Array[String],
		"CosmeticShop: the room, the blur, then the UI")


## The root's children in draw order, without the Glow (a WorldEnvironment
## draws nothing).
func _drawn(scene_path: String) -> Array[String]:
	var kids := Census.children_of(Census.of(scene_path), ".")
	kids.erase("Glow")
	return kids


const KOPERASI := "res://Scenes/Koperasi/Koperasi.tscn"
## Koperasi's backdrop band depth (its Parallax, 2026-09-22): the light rides it.
const KOPERASI_BACK_DEPTH := 0.15


## Koperasi stays on layer 0: its backdrop shares Stage with the tappable goods
## and the parallax driving Stage's children. So the light sits in Stage,
## straight after the backdrop and under the goods, and nothing blooms.
func test_koperasi_lights_its_stage_under_the_goods() -> void:
	var c := Census.of(KOPERASI)
	var kids := Census.children_of(c, "Stage")
	assert_eq(kids.slice(0, 4), ["Background", "Light", "Shafts", "Barang1"] as Array[String],
		"the backdrop, its light, then the goods")
	assert_eq(Census.entry(c, "Stage/Light").get("instance"), LIGHT_POOL, "Light is a LightPool")
	assert_eq(Census.entry(c, "Stage/Shafts").get("instance"), SUN_SHAFTS, "Shafts are SunShafts")
	var depths: Dictionary = Census.prop(Census.entry(c, "Stage/Parallax"), "depth_by_child", {})
	for band in ["Light", "Shafts"]:
		assert_eq(float(depths.get(band, 0.0)), KOPERASI_BACK_DEPTH,
			band + " rides the backdrop's depth, so it stays on its window")
	assert_true(Census.entry(c, "World").is_empty(), "no World layer")
	for e in c:
		assert_ne(e["instance"], AMBIENT_GLOW, "nothing on layer 0 can bloom, so no Glow")


## The exam notices' light is cool and dim, to sit under their TEGANG tint.
func test_the_exam_notices_light_is_cool() -> void:
	for scene_path in [TES_NOTICE, STAT_CHECK]:
		var c := Census.of(scene_path)
		var colour: Color = Census.prop(Census.entry(c, "World/Room/Light"), "light_color", Color.WHITE)
		assert_true(colour.b > colour.r, scene_path + ": the pool is cool, blue over red")
		var shafts: Color = Census.prop(Census.entry(c, "World/Room/Shafts"), "shaft_color", Color.WHITE)
		assert_true(shafts.b > shafts.r, scene_path + ": and so are the shafts")
		assert_eq(_drawn(scene_path).slice(0, 2), ["World", "Scrim"] as Array[String],
			scene_path + ": the scrim draws over the room, under the card")


## ExamProgress already pans its backdrop with a tween on position.x, so it
## takes no Parallax (planning amendment 3), and the script finds the moved
## backdrop by unique name.
func test_exam_progress_pans_its_own_backdrop() -> void:
	var c := Census.of(EXAM_PROGRESS)
	assert_eq(Census.prop(Census.entry(c, "World/Room/Backdrop"), "unique_name_in_owner"), true,
		"the backdrop is %Backdrop")
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/ExamProgress.gd")
	assert_true(src.contains("backdrop: TextureRect = %Backdrop"), "ExamProgress.gd finds it by name")


## EndCutscene hands over to RunResult with an invisible swap of the same
## frame, so both must bloom it alike (planning amendment 4).
func test_the_two_verdict_screens_bloom_alike() -> void:
	assert_eq(BLOOM[END_CUTSCENE], BLOOM[RUN_RESULT],
		"EndCutscene and RunResult share one glow decision")


## A CanvasLayer ignores its parent's modulate, so RunResult's exit fade must
## fade the Room as well as its root, or the painting stays lit to the end.
func test_run_result_fades_its_room_on_the_way_out() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/RunResult.gd")
	assert_true(src.contains("@onready var room: Control = %Room"), "RunResult finds its Room")
	assert_true(src.contains("tween.parallel().tween_property(room, \"modulate:a\", 0.0,"),
		"and fades it alongside the root")


func test_both_hosts_find_the_moved_stage_by_name() -> void:
	for path in ["res://Scripts/EndGame/EndCutscene.gd", "res://Scripts/EndGame/RunResult.gd"]:
		assert_true(FileAccess.get_file_as_string(path).contains("win_stage: WinStage = %WinStage"),
			path + " finds the stage by unique name")
