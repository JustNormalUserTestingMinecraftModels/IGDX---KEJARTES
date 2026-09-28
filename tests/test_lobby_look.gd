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
const SCREEN_GLOW := "res://Scenes/Look/ScreenGlow.tscn"
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
	SHOP_HUB: ["Backdrop", "Light", "Shafts", "Bloom", "Parallax"],
	COSMETIC_SHOP: ["Backdrop", "Light", "Shafts", "Bloom", "Parallax"],
	TES_NOTICE: ["Backdrop", "Tint", "Light", "Shafts", "Bloom", "Parallax"],
	STAT_CHECK: ["Backdrop", "Tint", "Light", "Shafts", "Bloom", "Parallax"],
	EXAM_PROGRESS: ["Backdrop", "Light", "Shafts", "Bloom"],
	END_CUTSCENE: ["WinStage"],
	RUN_RESULT: ["WinStage"],
}

## Screen -> its measured glow_threshold, or null where no threshold bloomed
## the light without fogging the backdrop, so the screen places no Glow.
## Recipe M writes the measured values.
const BLOOM := {
	SHOP_HUB: null,
	COSMETIC_SHOP: null,
	TES_NOTICE: null,
	STAT_CHECK: null,
	EXAM_PROGRESS: null,
	END_CUTSCENE: null,
	RUN_RESULT: null,
}

## Screen -> [its ScreenGlow's path, its tuned threshold]. The screen-read
## bloom replaced the Environment glow on every screen above plus Koperasi and
## the minigames (2026-09-29), placed right after the light so only the
## picture blooms. EndCutscene and RunResult share WinStage's, so the two
## verdict screens bloom alike by construction. Thresholds come from a full-size
## sweep (0.3-0.9): the highest that visibly blooms the light while the
## backdrop's median pixel moves by under +0.01. Pale wood fogs below 0.8;
## the scrimmed exam notices need 0.4 at intensity 0.8 to show at all.
const SCREEN_BLOOM := {
	SHOP_HUB: ["World/Room/Bloom", 0.7],
	COSMETIC_SHOP: ["World/Room/Bloom", 0.7],
	"res://Scenes/Koperasi/Koperasi.tscn": ["Stage/Bloom", 0.8],
	TES_NOTICE: ["World/Room/Bloom", 0.4],
	STAT_CHECK: ["World/Room/Bloom", 0.4],
	EXAM_PROGRESS: ["World/Room/Bloom", 0.5],
	WIN_STAGE: ["Stage/Bloom", 0.7],
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn": ["Bloom", 0.8],
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn": ["Bloom", 0.8],
	"res://Scenes/Minigames/Akademis/Password.tscn": ["Bloom", 0.8],
	"res://Scenes/Minigames/Akademis/Variabel.tscn": ["Bloom", 0.8],
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": ["Bloom", 0.75],
	"res://Scenes/Minigames/Olahraga/Badminton.tscn": ["Bloom", 0.75],
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn": ["Bloom", 0.75],
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn": ["Bloom", 0.8],
}
## ScreenGlow.gd's own threshold default, read when a scene leaves it.
const SCREEN_GLOW_DEFAULT := 0.7


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
	_assert_piece(c, scene_path, "World/Room/Bloom", SCREEN_GLOW)
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
	assert_false(depths.has(&"Bloom") or depths.has("Bloom"),
		scene_path + ": Bloom reads the screen where it is, so it never drifts")
	for band: String in want:
		if band == "Parallax" or band == "Bloom":
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


## Each screen blooms through exactly one ScreenGlow, at its tuned threshold,
## and nothing tappable is drawn before it: a button under the read would
## bloom with the picture.
func test_every_screen_blooms_through_one_screen_glow() -> void:
	for scene_path in SCREEN_BLOOM:
		var c := Census.of(scene_path)
		var want: String = SCREEN_BLOOM[scene_path][0]
		var found: Array[String] = []
		for e in c:
			if e["instance"] == SCREEN_GLOW:
				found.append(e["path"])
		assert_eq(found, [want] as Array[String], scene_path + ": one ScreenGlow, at " + want)
		var at := -1
		for i in c.size():
			if c[i]["path"] == want:
				at = i
		for i in at:
			assert_false(BUTTON_TYPES.has(c[i]["type"]),
				"%s: %s is tappable and drawn under the bloom" % [scene_path, c[i]["path"]])
		assert_eq(float(Census.prop(Census.entry(c, want), "threshold", SCREEN_GLOW_DEFAULT)),
			float(SCREEN_BLOOM[scene_path][1]), scene_path + ": the tuned threshold")


## WinStage draws its lights last in Stage; the bloom follows both, so the
## verdict's light blooms whichever one dress() shows.
func test_the_win_stage_blooms_after_both_lights() -> void:
	var kids := Census.children_of(Census.of(WIN_STAGE), "Stage")
	assert_eq(kids.slice(-3), ["LightPass", "LightFail", "Bloom"] as Array[String],
		"the pass light, the fail light, then the bloom")


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
	assert_eq(kids.slice(0, 5), ["Background", "Light", "Shafts", "Bloom", "Barang1"] as Array[String],
		"the backdrop, its light, its bloom, then the goods")
	assert_eq(Census.entry(c, "Stage/Light").get("instance"), LIGHT_POOL, "Light is a LightPool")
	assert_eq(Census.entry(c, "Stage/Shafts").get("instance"), SUN_SHAFTS, "Shafts are SunShafts")
	assert_eq(Census.entry(c, "Stage/Bloom").get("instance"), SCREEN_GLOW, "Bloom is a ScreenGlow")
	var depths: Dictionary = Census.prop(Census.entry(c, "Stage/Parallax"), "depth_by_child", {})
	assert_false(depths.has(&"Bloom") or depths.has("Bloom"),
		"Bloom reads the screen where it is, so it never drifts")
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
		var bloom: Color = Census.prop(Census.entry(c, "World/Room/Bloom"), "bloom_tint", Color.WHITE)
		assert_true(bloom.b > bloom.r, scene_path + ": and so is the bloom")
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


## A CanvasLayer ignores its parent's modulate, so a World screen that fades
## its own root must fade its Room too, or the lit room stays up to the scene
## swap. RunResult does both; this keeps every other World screen honest if it
## ever adds a root fade (Part 2 code review, 2026-09-28).
func test_no_world_screen_fades_its_root_alone() -> void:
	for scene_path in ROOMS:
		var root_script: Variant = Census.prop(Census.entry(Census.of(scene_path), "."), "script")
		if not root_script is Script:
			continue
		var src := FileAccess.get_file_as_string((root_script as Script).resource_path)
		if src.contains("tween_property(self, \"modulate"):
			assert_true(src.contains("tween_property(room, \"modulate"),
				scene_path + ": its root fade must also fade %Room")


## Minigame -> [its backdrop node, whether it throws shafts]. They stay on
## layer 0: SchoolDay hosts a minigame inside its own tree, over its own
## layer-0 background, so a World at -1 would draw under that and never show,
## and SchoolDay's fade-in on the minigame's root would not reach it. So the
## light sits directly after the backdrop and nothing blooms (spec, pass 3).
## BuatBatik takes no shafts, so no ray crosses the drawing canvas.
const MINIGAMES := {
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn": ["Background", true],
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn": ["Background", true],
	"res://Scenes/Minigames/Akademis/Password.tscn": ["Background", true],
	"res://Scenes/Minigames/Akademis/Variabel.tscn": ["Background", true],
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": ["FieldBG", true],
	"res://Scenes/Minigames/Olahraga/Badminton.tscn": ["Background", true],
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn": ["Background", true],
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn": ["Background", false],
}


func test_every_minigame_lights_its_backdrop_on_layer_0() -> void:
	for scene_path in MINIGAMES:
		var c := Census.of(scene_path)
		var backdrop: String = MINIGAMES[scene_path][0]
		var throws_shafts: bool = MINIGAMES[scene_path][1]
		var kids := Census.children_of(c, ".")
		assert_eq(kids.find(backdrop), 0, scene_path + ": the backdrop is still drawn first")
		assert_eq(kids.find("Light"), 1, scene_path + ": the light sits right after it")
		assert_eq(Census.entry(c, "Light").get("instance"), LIGHT_POOL, scene_path + ": a LightPool")
		if throws_shafts:
			assert_eq(kids.find("Shafts"), 2, scene_path + ": then the shafts")
			assert_eq(Census.entry(c, "Shafts").get("instance"), SUN_SHAFTS, scene_path + ": SunShafts")
		else:
			assert_eq(kids.find("Shafts"), -1, scene_path + ": no shafts")
		assert_eq(kids.find("Bloom"), 3 if throws_shafts else 2,
			scene_path + ": the bloom right after the light, under everything the player reads")
		for e in c:
			assert_ne(e["instance"], AMBIENT_GLOW, scene_path + ": no Glow on layer 0")
			if e["type"] == "CanvasLayer":
				assert_true(int(Census.prop(e, "layer", 1)) >= 0,
					"%s: %s must not draw under SchoolDay's background" % [scene_path, e["path"]])
