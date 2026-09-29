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
## The Lobby's own Environment, whose glow values every Glow copies.
const LOBBY_ENVIRONMENT := "res://Scenes/Lobby/lobby_environment.tres"
const MOOD_TINT := "res://Scenes/Look/MoodTint.tscn"
const WIN_STAGE := "res://Scenes/EndGame/WinStage.tscn"
const PARALLAX_SCRIPT := "res://Scripts/UI/ParallaxDiorama.gd"
const GRADE := "res://Scripts/Shaders/illustration_grade_material.tres"
const BUTTON_TYPES := ["Button", "TextureButton", "CheckButton", "CheckBox",
	"OptionButton", "MenuButton", "LinkButton"]
## The drift of a flat screen: it has no nearer band, so its one plane moves
## at full depth against the UI (planning amendment 5).
const FLAT_DEPTH := 1.0
## AmbientGlow.gd's own glow_threshold default, read when a scene leaves it:
## the Lobby's (lobby_environment.tres).
const GLOW_DEFAULT := 0.7

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

## Screen -> its Glow's glow_threshold. Every World screen carries the Lobby's
## own bloom (2026-09-29, owner's call): an AmbientGlow at the Lobby's values,
## second in the root, blooming the World layer under the UI. It replaced the
## screen-read ScreenGlow, which measured but was too faint to see in play.
const BLOOM := {
	SHOP_HUB: GLOW_DEFAULT,
	COSMETIC_SHOP: GLOW_DEFAULT,
	TES_NOTICE: GLOW_DEFAULT,
	STAT_CHECK: GLOW_DEFAULT,
	EXAM_PROGRESS: GLOW_DEFAULT,
	END_CUTSCENE: GLOW_DEFAULT,
	RUN_RESULT: GLOW_DEFAULT,
	"res://Scenes/Koperasi/Koperasi.tscn": GLOW_DEFAULT,
	# 2026-09-30: the minigames and EventDialogue moved their art into a World
	# room too, and the screen-read ScreenGlow gave way to this Glow. Each
	# threshold was swept on a frozen 1080x1920 frame against the Lobby's own
	# bloom (+0.011 mean): MainBola +0.0105 at 0.85, Badminton +0.0056 at 0.7
	# (its court is mid-tone; only the lines bloom), LombaMenari +0.0098 at 0.8.
	# The desk screens' pale wood hazed at 0.85 (36% of the frame lifted), so
	# they take 0.9 (13%). EventDialogue keeps its old bloom's 0.85, which
	# measures the same as before (+0.0004 against +0.0005).
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": 0.85,
	"res://Scenes/Minigames/Olahraga/Badminton.tscn": 0.7,
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn": 0.8,
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn": 0.9,
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn": 0.9,
	"res://Scenes/Minigames/Akademis/Password.tscn": 0.9,
	"res://Scenes/Minigames/Akademis/Variabel.tscn": 0.9,
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn": 0.9,
	"res://Scenes/SchoolSimulation/EventDialogue.tscn": 0.85,
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


## Each World screen keeps exactly one Glow, second in the root, blooming
## the World layer only (max layer -1), at its measured threshold.
func test_every_world_screen_carries_the_lobby_bloom() -> void:
	for scene_path in BLOOM:
		var c := Census.of(scene_path)
		var glows := 0
		for e in c:
			if e["instance"] == AMBIENT_GLOW:
				glows += 1
			assert_ne(e["instance"], SCREEN_GLOW, scene_path + ": no ScreenGlow stacked on the Glow")
		assert_eq(glows, 1, scene_path + ": one Glow")
		assert_eq(Census.children_of(c, ".").find("Glow"), 1,
			scene_path + ": Glow is the root's second child, right after World")
		var glow := Census.entry(c, "Glow")
		assert_eq(float(Census.prop(glow, "glow_threshold", GLOW_DEFAULT)),
			float(BLOOM[scene_path]), scene_path + ": its measured threshold")


## "Copy the Lobby's bloom": the piece's defaults are the Lobby's Environment.
func test_the_glow_defaults_are_the_lobbys() -> void:
	var lobby: Environment = load(LOBBY_ENVIRONMENT)
	var glow := (load(AMBIENT_GLOW) as PackedScene).instantiate() as AmbientGlow
	assert_true(is_equal_approx(glow.glow_threshold, lobby.glow_hdr_threshold), "threshold")
	assert_true(is_equal_approx(glow.glow_intensity, lobby.glow_intensity), "intensity")
	assert_true(is_equal_approx(glow.glow_strength, lobby.glow_strength), "strength")
	assert_eq(glow.environment.glow_blend_mode, lobby.glow_blend_mode, "blend mode")
	assert_eq(glow.environment.background_mode, lobby.background_mode, "Canvas mode")
	glow.free()


func test_every_lit_screen_wears_the_lobby_room() -> void:
	for scene_path in ROOMS:
		_assert_room(scene_path, ROOMS[scene_path])


## The shops blur their Room on layer 0, so the light blurs with the picture
## and the tiles and the back button stay sharp above it.
## Glow is left out of the order: test_every_world_screen_carries_the_lobby_bloom
## owns it.
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


## Koperasi's picture -- wall, backdrop, light, shafts, Pak Herman and the
## counter -- sits in a World CanvasLayer at -1 (2026-09-29) so the Lobby's
## bloom reaches it and never the shop UI. Room mirrors Stage's bottom-pinned
## 1080x1920 rect, so the picture and the goods on Stage still move as one
## piece on a tall phone. The goods (with their price tags and pips), the
## boards, the bubble, the back button and the tray stay on Stage, on layer 0.
## The goods used to draw under Herman and the counter; neither plate has an
## opaque pixel over any shelf slot (measured 2026-09-29), so drawing them
## above instead changes nothing on screen.
func test_koperasi_blooms_its_room_under_the_goods() -> void:
	var c := Census.of(KOPERASI)
	var world := Census.entry(c, "World")
	assert_eq(world.get("type"), "CanvasLayer", "World is a CanvasLayer")
	assert_eq(Census.prop(world, "layer"), -1, "World draws at -1, below the UI")
	assert_eq(Census.children_of(c, ".").slice(0, 3), ["World", "Glow", "Stage"] as Array[String],
		"the room, its bloom, then the shop")
	assert_eq(Census.children_of(c, "World"), ["WallFill", "Room"] as Array[String],
		"the wall strip, then the room")
	assert_eq(Census.children_of(c, "World/Room"),
		["Background", "Light", "Shafts", "Herman", "Foreground", "Parallax"] as Array[String],
		"the room's bands")
	assert_eq(Census.entry(c, "World/Room/Light").get("instance"), LIGHT_POOL, "Light is a LightPool")
	assert_eq(Census.entry(c, "World/Room/Shafts").get("instance"), SUN_SHAFTS, "Shafts are SunShafts")
	assert_eq(Census.children_of(c, "World/Room/Light"), [] as Array[String],
		"the LightPool's own Pool is not re-authored in Koperasi")
	var room := Census.entry(c, "World/Room")
	var stage := Census.entry(c, "Stage")
	for key in ["anchor_top", "anchor_bottom", "offset_top", "offset_right"]:
		assert_eq(Census.prop(room, key, 0.0), Census.prop(stage, key, 0.0),
			"Room matches Stage's %s, so the picture stays under the goods" % key)
	assert_eq(Census.prop(room, "mouse_filter"), Control.MOUSE_FILTER_IGNORE, "Room never eats a tap")
	assert_eq(Census.prop(room, "unique_name_in_owner"), true, "%Room, for a future root fade")
	# A CanvasLayer ignores its parent's modulate: a root fade must fade %Room too.
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/Koperasi.gd")
	if src.contains("tween_property(self, \"modulate"):
		assert_true(src.contains("tween_property(room, \"modulate"),
			"Koperasi's root fade must also fade %Room")
	for e in c:
		if (e["path"] as String).begins_with("World/"):
			assert_false(BUTTON_TYPES.has(e["type"]), e["path"] + " is tappable and must stay on layer 0")
	assert_eq(Census.children_of(c, "Stage")[0], "Barang1", "the goods open the Stage")


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


## A CanvasLayer ignores its parent's modulate, so a World screen that fades
## its own root must fade its Room too, or the lit room stays up to the scene
## swap. RunResult does both; this keeps every other World screen honest if it
## ever adds a root fade (Part 2 code review, 2026-09-28). The minigames and
## EventDialogue joined on 2026-09-30; SchoolDay's fade of a hosted minigame's
## root is crossed by its own day picture instead (see the SchoolDay test).
func test_no_world_screen_fades_its_root_alone() -> void:
	var screens: Array = ROOMS.keys() + MINIGAMES.keys()
	screens.append("res://Scenes/SchoolSimulation/EventDialogue.tscn")
	for scene_path in screens:
		var root_script: Variant = Census.prop(Census.entry(Census.of(scene_path), "."), "script")
		if not root_script is Script:
			continue
		var src := FileAccess.get_file_as_string((root_script as Script).resource_path)
		if src.contains("tween_property(self, \"modulate"):
			assert_true(src.contains("tween_property(room, \"modulate"),
				scene_path + ": its root fade must also fade %Room")


## Minigame -> [its backdrop node, whether it throws shafts, Calm's
## saturation, Tint's strength]. Since 2026-09-30 every minigame lights its
## art the Lobby way: the backdrop, a calm-and-warm grade (ScreenSaturation
## after a fresh BackBufferCopy, then a PAGI MoodTint), the light and the
## shafts, all in a World room at -1 under the Glow. SchoolDay fades its own
## layer-0 picture out while a minigame is up so that room shows (see
## test_school_day_uncovers_its_picture_only_when_the_last_host_closes).
## BuatBatik takes no shafts, so no ray crosses the drawing canvas.
const MINIGAMES := {
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn": ["Background", true, 0.85, 0.2],
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn": ["Background", true, 0.85, 0.2],
	"res://Scenes/Minigames/Akademis/Password.tscn": ["Background", true, 0.85, 0.2],
	"res://Scenes/Minigames/Akademis/Variabel.tscn": ["Background", true, 0.85, 0.2],
	"res://Scenes/Minigames/Olahraga/MainBola.tscn": ["FieldBG", true, 0.8, 0.3],
	"res://Scenes/Minigames/Olahraga/Badminton.tscn": ["Background", true, 0.55, 0.45],
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn": ["Background", true, 0.85, 0.3],
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn": ["Background", false, 0.85, 0.2],
}
## The grade's first half: the screen-read saturation pass.
const SCREEN_SATURATION := "res://Scenes/Look/ScreenSaturation.tscn"


func test_every_minigame_lights_its_art_in_a_world_room() -> void:
	for scene_path in MINIGAMES:
		var spec: Array = MINIGAMES[scene_path]
		var backdrop: String = spec[0]
		var bands: Array = [backdrop, "GradeCopy", "Calm", "Tint", "Light"]
		if spec[1]:
			bands.append("Shafts")
		_assert_room(scene_path, bands)
		_assert_minigame_grade(scene_path, backdrop, spec[2], spec[3])


## The backdrop wears the plain grade, is found by unique name and never eats
## a tap; the calm-and-warm pass reads a fresh copy of the frame; nothing of
## the old screen-read bloom is left.
func _assert_minigame_grade(scene_path: String, backdrop: String, calm_sat: float, warmth: float) -> void:
	var c := Census.of(scene_path)
	var plate := Census.entry(c, "World/Room/" + backdrop)
	var mat: Variant = Census.prop(plate, "material")
	assert_true(mat is Material and (mat as Material).resource_path == GRADE,
		scene_path + ": the backdrop wears the plain grade")
	assert_eq(Census.prop(plate, "unique_name_in_owner"), true, scene_path + ": %" + backdrop)
	assert_eq(Census.prop(plate, "mouse_filter"), Control.MOUSE_FILTER_IGNORE,
		scene_path + ": the backdrop never eats a tap")
	var copy := Census.entry(c, "World/Room/GradeCopy")
	assert_eq(copy.get("type"), "BackBufferCopy", scene_path + ": the grade reads a fresh copy")
	assert_eq(int(Census.prop(copy, "copy_mode", 1)), BackBufferCopy.COPY_MODE_VIEWPORT,
		scene_path + ": of the whole viewport")
	var calm := Census.entry(c, "World/Room/Calm")
	assert_eq(calm.get("instance"), SCREEN_SATURATION, scene_path + ": Calm is a ScreenSaturation")
	assert_eq(float(Census.prop(calm, "saturation", 0.7)), calm_sat, scene_path + ": its calm")
	var tint := Census.entry(c, "World/Room/Tint")
	assert_eq(int(Census.prop(tint, "mood", 0)), MoodTint.Mood.PAGI, scene_path + ": a warm PAGI tint")
	assert_eq(float(Census.prop(tint, "strength", 0.35)), warmth, scene_path + ": its warmth")
	for e in c:
		assert_ne(e["instance"], SCREEN_GLOW, scene_path + ": no screen-read bloom left")
	var script := Census.prop(Census.entry(c, "."), "script") as Script
	var src := FileAccess.get_file_as_string(script.resource_path)
	assert_false(src.contains("(\"" + backdrop + "\")") or src.contains("$" + backdrop),
		scene_path + ": the script finds the moved backdrop by unique name, not by path")


## A lit screen hosted by SchoolDay (a minigame, EventDialogue) draws its
## World at -1, under SchoolDay's own layer-0 picture: the sky, the clock and
## the weather. SchoolDay fades that picture out around the minigame's own
## fade and hides it under EventDialogue, and it counts the covers, so two
## overlapping hosts cannot bring the picture back early.
func test_school_day_uncovers_its_picture_only_when_the_last_host_closes() -> void:
	var cover := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/DayPictureCover.gd")
	for n in ["^\"Background\"", "^\"BookClockWidget\"", "^\"Rain\"", "^\"Motes\"", "^\"DayStamp\"",
			"^\"WeekFireworks\""]:
		assert_true(cover.contains(n), "DAY_PICTURE lists " + n)
	assert_true(cover.contains("covers += 1") and cover.contains("covers -= 1"), "covers are counted")
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("tween_in.tween_property(current_minigame, \"modulate:a\", 1.0, 0.4)\n\t_day_cover.cover(true)"),
		"the day's picture fades out as the minigame fades in")
	assert_true(src.contains("tween_close.tween_property(current_minigame, \"modulate:a\", 0.0, 0.4)\n\t_day_cover.uncover(true)"),
		"and back in as it fades out")
	assert_true(src.contains("add_child(dialogue)\n\t_day_cover.cover(false)"), "EventDialogue covers the day")
	assert_true(src.contains("dialogue.queue_free()\n\t_day_cover.uncover(false)"), "and uncovers it on close")


## Behaviour, on a stand-in host: two overlapping covers need two uncovers,
## each node gets its own alpha back (the motes' 0.45), and an extra uncover
## is harmless.
func test_the_day_cover_is_counted_and_restores_each_alpha() -> void:
	var host := Control.new()
	for n in ["Background", "Motes"]:
		var item := ColorRect.new()
		item.name = n
		host.add_child(item)
	(host.get_node("Motes") as CanvasItem).modulate.a = 0.45
	var cover = (load("res://Scripts/SchoolSimulation/DayPictureCover.gd") as GDScript).new(host)
	cover.cover(false)
	cover.cover(false)
	assert_eq((host.get_node("Background") as CanvasItem).modulate.a, 0.0, "covered")
	cover.uncover(false)
	assert_eq((host.get_node("Background") as CanvasItem).modulate.a, 0.0, "still covered by the second host")
	cover.uncover(false)
	assert_eq((host.get_node("Background") as CanvasItem).modulate.a, 1.0, "back once the last host closes")
	assert_true(is_equal_approx((host.get_node("Motes") as CanvasItem).modulate.a, 0.45), "the motes keep their own alpha")
	cover.uncover(false)
	assert_eq(cover.covers, 0, "an extra uncover does nothing")
	host.free()


## A dev skip mid fade-in snaps the picture back while the cover's fade is
## still running: the fade is settled first, so it cannot drive the sky back
## to 0 afterwards.
func test_an_instant_uncover_settles_a_running_cover_fade() -> void:
	var host := Control.new()
	var sky := ColorRect.new()
	sky.name = "Background"
	host.add_child(sky)
	var cover = (load("res://Scripts/SchoolSimulation/DayPictureCover.gd") as GDScript).new(host)
	cover.cover(true)
	cover.uncover(false)
	assert_eq(sky.modulate.a, 1.0, "the sky is back at once")
	assert_eq(cover.get("_tween"), null, "and no fade is left running to undo it")
	host.free()


## The debug overlay's standalone launcher hosts a minigame over whatever
## scene is open. That scene's layer-0 picture would cover the minigame's
## World, its own WorldEnvironment would win, and a HIDDEN CanvasLayer at -1
## or below switches a Canvas-mode glow off outright (measured 2026-09-30). So
## the launcher hides the scene, parks its negative layers at 0 and lifts its
## environments out, and puts all three back afterwards.
func test_the_debug_launcher_clears_the_way_for_a_lit_minigame() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugManager.gd")
	assert_true(src.contains("_scene_stash.hide(get_tree().current_scene)\n\tactive_minigame = m_scene.instantiate()"),
		"the scene underneath is cleared before the minigame arrives")
	assert_true(src.contains("_scene_stash.restore()"), "and put back when it ends")
	var stash := FileAccess.get_file_as_string("res://Scripts/Debug/SceneStash.gd")
	assert_true(stash.contains("canvas.layer = maxi(canvas.layer, 0)"), "negative layers are parked at 0")
	assert_true(stash.contains("parent.remove_child(env)"), "the scene's environments step aside")


## Behaviour: hide() hides the scene, parks its negative layer at 0 and lifts
## its WorldEnvironment out; restore() puts all three back where they were.
## Built detached, so no environment ever reaches the editor's own viewport.
func test_the_scene_stash_puts_everything_back() -> void:
	var scene := Control.new()
	var world := CanvasLayer.new()
	world.layer = -1
	scene.add_child(world)
	var env := WorldEnvironment.new()
	scene.add_child(env)
	var stash = (load("res://Scripts/Debug/SceneStash.gd") as GDScript).new()
	stash.hide(scene)
	assert_false(scene.visible, "the scene is hidden")
	assert_false(world.visible, "its World too")
	assert_eq(world.layer, 0, "parked at 0, where a hidden layer cannot switch the glow off")
	assert_eq(env.get_parent(), null, "its environment is lifted out")
	stash.restore()
	assert_true(scene.visible and world.visible, "shown again")
	assert_eq(world.layer, -1, "back at -1")
	assert_eq(env.get_parent(), scene, "the environment is back")
	assert_eq(env.get_index(), 1, "in its old place")
	scene.free()
