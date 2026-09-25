@tool
extends McpTestSuite

## Parallax on the two dioramas (2026-09-22, premium-look PR 3).
##
## The Lobby's Classroom and Koperasi's Stage were authored as separate depth
## bands and drawn flat. Scripts/UI/ParallaxDiorama.gd slides them against
## each other under device tilt. This suite pins the three things that would
## be expensive to find by eye:
##
##   1. Nothing the driver does is ever written to disk. It mutates position,
##      scale and pivot, and an editor that did so would bake the drift into
##      the .tscn on the next save -- exactly how StickyNote's pins once
##      shifted 20px.
##   2. Each row shares one depth plane, or a student's hands slide off the
##      desk they are drawn resting on.
##   3. The overscan really does cover the travel, or a moving band drags its
##      own edge into view -- on the Lobby's BGLayer that means the black
##      Backdrop behind it.
##
## Must be @tool, and no test here may be a coroutine.

const LayoutFrame := preload("res://tests/layout_frame.gd")

const LOBBY := "res://Scenes/Lobby/loby.tscn"
const KOPERASI := "res://Scenes/Koperasi/koprasi.tscn"

## scene -> the diorama holding the bands, and its driver's path.
const DIORAMAS := {
	LOBBY: "World/Classroom",
	KOPERASI: "Stage",
}


func suite_name() -> String:
	return "parallax_diorama"


func _driver(root: Node, host: String) -> Node:
	return root.get_node_or_null("%s/Parallax" % host)


func test_both_dioramas_have_a_driver_over_real_bands() -> void:
	for scene_path in DIORAMAS:
		var host_name: String = DIORAMAS[scene_path]
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		var host := root.get_node_or_null(host_name) as Control
		assert_true(host != null, "%s is missing %s" % [scene_path, host_name])
		if host == null:
			continue
		var driver := _driver(root, host_name)
		assert_true(driver != null, "%s/%s needs a Parallax driver" % [scene_path, host_name])
		if driver == null:
			continue
		var depths: Dictionary = driver.get("depth_by_child")
		assert_true(depths.size() >= 3,
			"%s needs at least three bands to have any parallax at all" % scene_path)
		for band_name in depths:
			assert_true(host.get_node_or_null(NodePath(String(band_name))) != null,
				"%s names a band '%s' that %s does not have"
					% [scene_path, band_name, host_name])


## The driver is a child of the diorama rather than its script, because the
## obvious host is sometimes taken: Koperasi's Stage already runs
## rakbarang_1.gd and a node has only one script.
func test_the_driver_never_displaces_an_existing_script() -> void:
	var root := (load(KOPERASI) as PackedScene).instantiate()
	track(root)
	var stage := root.get_node_or_null("Stage")
	assert_true(stage != null, "Stage is gone")
	if stage == null:
		return
	assert_true(stage.get_script() != null,
		"Stage still needs its own script -- this is why the driver is a child")
	assert_true(_driver(root, "Stage") != null, "the driver must still be there")


## A desk, the students sitting at it and their hands resting on it must move
## as one piece. This is the rule most likely to be broken by someone tuning
## depths later, and the damage -- hands floating off the desk -- is subtle
## enough to ship unnoticed.
func test_each_lobby_row_sits_on_one_depth_plane() -> void:
	var root := (load(LOBBY) as PackedScene).instantiate()
	track(root)
	var driver := _driver(root, "World/Classroom")
	assert_true(driver != null, "no driver")
	if driver == null:
		return
	var depths: Dictionary = driver.get("depth_by_child")
	var rows := {
		"back": ["Meja_KiriAtas", "Meja_KananAtas",
			"StudentPortraitsContainer_Back", "StudentHandsContainer_Back"],
		"front": ["Meja_KiriBawah", "Meja_KananBawah",
			"StudentPortraitsContainer_Front", "StudentHandsContainer_Front"],
	}
	for row_name in rows:
		var seen := {}
		for band_name in rows[row_name]:
			assert_has_key(depths, band_name, "%s is not in the depth map" % band_name)
			seen[float(depths.get(band_name, -1.0))] = true
		assert_eq(seen.keys().size(), 1,
			"the %s row must share one depth or its hands leave the desk; got %s"
				% [row_name, str(seen.keys())])
	# And the three planes must actually differ, or there is no parallax.
	var wall := float(depths.get("BGLayer", 0.0))
	var back := float(depths.get("Meja_KiriAtas", 0.0))
	var front := float(depths.get("Meja_KiriBawah", 0.0))
	assert_true(wall < back and back < front,
		"nearer bands must travel further (wall %s < back %s < front %s)"
			% [wall, back, front])


## Koperasi's Stage holds the shop UI as well as the picture. Anything the
## player aims at must stay put, or on the desktop pointer path the button
## slides away from the cursor reaching for it.
func test_koperasi_ui_is_left_out_of_the_parallax() -> void:
	var root := (load(KOPERASI) as PackedScene).instantiate()
	track(root)
	var driver := _driver(root, "Stage")
	assert_true(driver != null, "no driver")
	if driver == null:
		return
	var depths: Dictionary = driver.get("depth_by_child")
	for ui_name in ["BackButton", "TrayDock", "CoinHUD", "ChatBubble"]:
		assert_false(depths.has(ui_name),
			"%s is UI and must not drift with the diorama" % ui_name)
	# The shelf goods are tap targets too, and each one's ShelfItem writes its
	# idle bob into position.y every frame. A driver writing the same node
	# after it erased the bob outright (review, 2026-09-24).
	for i in range(1, 7):
		assert_false(depths.has("Barang%d" % i),
			"Barang%d is a bobbing shelf button and must not be a band" % i)


## A capture that fails because one band has no layout yet must leave every
## band untouched. It used to grow the overscanned bands as it went, so a
## later unsized band failed the capture after an earlier one had grown, and
## the next frame grew that one again: ~20px of creep per frame of waiting.
func test_a_failed_capture_grows_nothing() -> void:
	var host := track(Control.new()) as Control
	host.size = Vector2(1080, 1920)
	var wall := Control.new()
	wall.name = "Wall"
	wall.size = Vector2(1080, 1920)
	host.add_child(wall)
	var row := Control.new()
	row.name = "Row"
	host.add_child(row)
	var driver: Control = (load("res://Scripts/UI/ParallaxDiorama.gd") as GDScript).new()
	driver.set("depth_by_child", {"Wall": 0.15, "Row": 1.0})
	driver.set("overscan_children", Array([&"Wall"], TYPE_STRING_NAME, &"", null))
	host.add_child(driver)

	assert_false(driver.call("force_deflection", Vector2.ONE), "Row has no size yet")
	assert_false(driver.call("force_deflection", Vector2.ONE), "Row still has no size")
	assert_eq(wall.offset_left, 0.0, "a failed capture must not grow the wall")

	row.size = Vector2(1080, 400)
	assert_true(driver.call("force_deflection", Vector2.ZERO), "every band has layout now")
	var reach: Vector2 = driver.call("required_reach")
	assert_true(is_equal_approx(wall.offset_left, -reach.x),
		"the wall is grown exactly once: offset_left %s, reach %s" % [wall.offset_left, reach.x])


## The bands move through their offsets, never an absolute `position`, so the
## anchors keep a moved band on its parent through a resize or a rotation. And
## the phone reads tilt against the pose it is held in: against gravity, pitch
## sat at 5-10 m/s^2 at every holding angle and the clamp pinned it at full.
func test_the_driver_moves_offsets_and_reads_tilt_from_the_held_pose() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/ParallaxDiorama.gd")
	for line in src.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		assert_false(stripped.contains("band.position ="),
			"write offsets, not position: " + stripped)
		assert_false(stripped.contains("9.8"),
			"tilt must be read against the held pose, not gravity: " + stripped)
	assert_true(src.contains("_neutral"), "the phone path needs a tracked neutral pose")


## The saved scene must show the authored diorama, with no overscan baked in
## by an editor session. The driver grows a band by pushing its offsets out,
## so a Full Rect band that was saved mid-growth has negative left/top
## offsets. If this fails, someone ran the motion outside play and saved.
func test_nothing_the_driver_touches_is_baked_into_the_scene() -> void:
	for scene_path in DIORAMAS:
		var host_name: String = DIORAMAS[scene_path]
		var root := (load(scene_path) as PackedScene).instantiate()
		track(root)
		var host := root.get_node_or_null(host_name) as Control
		var driver := _driver(root, host_name)
		if host == null or driver == null:
			continue
		for band_name in (driver.get("overscan_children") as Array):
			var band := host.get_node_or_null(NodePath(String(band_name))) as Control
			assert_true(band != null,
				"%s names an overscan band '%s' it does not have" % [scene_path, band_name])
			if band == null:
				continue
			assert_eq(Vector4(band.offset_left, band.offset_top,
					band.offset_right, band.offset_bottom), Vector4.ZERO,
				"%s/%s was saved with the overscan baked into its offsets"
					% [scene_path, band_name])


## The driver must never write `scale` or `pivot_offset`. Koperasi's Herman is
## authored with pivot (540, 1920) so HermanAP can scale him up from the
## floor, and that animation writes `scale` every frame it plays -- an earlier
## draft of this script set both, which would have fought the animation and
## silently lost its own overscan. Caught by this suite before it shipped.
func test_the_driver_leaves_scale_and_pivot_to_their_owners() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/ParallaxDiorama.gd")
	for line in src.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		assert_false(stripped.contains(".scale =") or stripped.contains(".pivot_offset ="),
			"the driver must not assign scale or pivot: " + stripped)

	var root := (load(KOPERASI) as PackedScene).instantiate()
	track(root)
	var herman := root.get_node_or_null("Stage/Herman") as Control
	assert_true(herman != null, "Herman is gone")
	if herman == null:
		return
	assert_eq(herman.pivot_offset, Vector2(540, 1920),
		"Herman's authored pivot is HermanAP's, and must survive untouched")


## Overscan is only for bands that are opaque to their own edges. Listing a
## transparent cutout would stretch empty pixels; omitting an opaque one lets
## its edge show the moment it moves.
func test_only_the_opaque_bands_are_overscanned() -> void:
	var expected := {
		LOBBY: ["BGLayer"],
		KOPERASI: ["Background", "Foreground"],
	}
	for scene_path in expected:
		var driver := _driver((load(scene_path) as PackedScene).instantiate(),
			DIORAMAS[scene_path])
		assert_true(driver != null, "%s has no driver" % scene_path)
		if driver == null:
			continue
		track(driver.get_owner() if driver.get_owner() != null else driver)
		var got := PackedStringArray()
		for n in (driver.get("overscan_children") as Array):
			got.append(String(n))
		var want := PackedStringArray(expected[scene_path])
		assert_eq(got, want, "%s overscan list" % scene_path)
		# Every overscanned band must also be one that actually moves.
		var depths: Dictionary = driver.get("depth_by_child")
		for n in got:
			assert_has_key(depths, n, "%s is overscanned but never moves" % n)


## Standing the screen up runs _ready in the editor, which must leave the
## motion switched off. This is the guard that keeps the test above true.
func test_the_driver_does_not_process_inside_the_editor() -> void:
	var frame := track(LayoutFrame.stand_up(LOBBY, Vector2(1080, 1920))) as Control
	var driver := _driver(frame.get_child(0), "World/Classroom")
	assert_true(driver != null, "no driver")
	if driver == null:
		return
	assert_false(driver.is_processing(),
		"the driver must not run in the editor, or the next scene save bakes the drift")


## The geometry that makes the whole thing safe: a band grown by the overscan
## has to stay at least as wide as its parent plus the distance it travels on
## each side. If this is ever false, the band's edge shows.
func test_the_overscan_covers_the_travel_on_both_dioramas() -> void:
	for scene_path in DIORAMAS:
		var host_name: String = DIORAMAS[scene_path]
		var frame := track(LayoutFrame.stand_up(scene_path, Vector2(1080, 1920))) as Control
		var screen := frame.get_child(0)
		var host := screen.get_node_or_null(host_name) as Control
		var driver := _driver(screen, host_name)
		if host == null or driver == null:
			continue
		var reach: Vector2 = driver.call("required_reach")
		var depths: Dictionary = driver.get("depth_by_child")
		var travel: Vector2 = driver.get("travel")
		var deepest := 0.0
		for band_name in depths:
			deepest = maxf(deepest, absf(float(depths[band_name])))
		var furthest := travel * deepest
		assert_true(reach.x >= furthest.x and reach.y >= furthest.y,
			"%s: reach %s must cover the furthest band's travel %s, or its edge shows"
				% [scene_path, reach, furthest])
		assert_true(reach.x > 0.0 and reach.y > 0.0,
			"%s: a moving band needs margin to move inside" % scene_path)
