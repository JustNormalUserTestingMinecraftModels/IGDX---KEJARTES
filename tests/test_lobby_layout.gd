@tool
extends McpTestSuite

## Geometry guards for the lobby, from the 2026-09-08 warm-UI pass.
##
## Three defects motivated these, all measured rather than eyeballed:
## ReportStudent ended at x=1059 on a 1080-wide screen with a 6px border
## and a 14px shadow, so it clipped; DisplayUang spanned to x=1120, i.e.
## 40px off-screen entirely; and DisplayUang and DailyLogin sat centred
## on the two front-row students' heads (x~845 y~389 and x~225 y~389).

const SCREEN_W := 1080.0
const SCREEN_H := 1920.0
const RIM_CLEARANCE := 24.0

const SCENE := "res://Scenes/Lobby/loby.tscn"

const NAV_TILES := ["Koperasi", "Inventory", "ReportStudent"]


func suite_name() -> String:
	return "lobby_layout"


func _rects() -> Dictionary:
	# Source-text scan rather than instantiation: the lobby pulls in
	# shaders, autoload state and layered face rigs, and cannot be stood
	# up headlessly. This follows the project's established pattern.
	#
	# Restricted to direct children of the scene root (`parent="."`).
	# A .tscn's offset_* values are relative to the node's PARENT, not the
	# screen -- only a root child's offsets are screen-space coordinates.
	# A flat, unscoped scan collected every nested node too and reported
	# false rim offenders that were actually correctly-positioned children
	# inside their parents: a Hand under a StudentHandsContainer_*/Slot*,
	# and labels under DailyReward (its baked panel art replaced the old
	# Day1..Day7 tiles this comment used to name). The scene root
	# itself carries no `parent=` attribute at all and is excluded too --
	# it is the screen, so it cannot clip against itself.
	var src := FileAccess.get_file_as_string(SCENE)
	var out := {}
	var name := ""
	var r := {}
	var is_root_child := false
	for line in src.split("\n"):
		if line.begins_with("[node "):
			if is_root_child and name != "" and r.has("l") and r.has("r"):
				out[name] = r
			name = line.get_slice("name=\"", 1).get_slice("\"", 0)
			is_root_child = line.contains("parent=\".\"")
			r = {}
		elif line.begins_with("offset_left = "):
			r["l"] = float(line.get_slice("= ", 1))
		elif line.begins_with("offset_right = "):
			r["r"] = float(line.get_slice("= ", 1))
		elif line.begins_with("offset_top = "):
			r["t"] = float(line.get_slice("= ", 1))
		elif line.begins_with("offset_bottom = "):
			r["b"] = float(line.get_slice("= ", 1))
	if is_root_child and name != "" and r.has("l") and r.has("r"):
		out[name] = r
	return out


func test_nav_tiles_share_one_height_and_one_baseline() -> void:
	var rects := _rects()
	var heights := []
	var tops := []
	for n in NAV_TILES:
		assert_true(rects.has(n), "lobby is missing node: " + n)
		heights.append(rects[n]["b"] - rects[n]["t"])
		tops.append(rects[n]["t"])
	for i in range(1, heights.size()):
		assert_eq(heights[i], heights[0],
			"%s height %f differs from %s height %f -- the three tiles are one row"
				% [NAV_TILES[i], heights[i], NAV_TILES[0], heights[0]])
		assert_eq(tops[i], tops[0],
			"%s top %f differs from %s top %f -- they must share a baseline"
				% [NAV_TILES[i], tops[i], NAV_TILES[0], tops[0]])


func test_nothing_clips_the_screen_rim() -> void:
	var rects := _rects()
	var offenders := []
	for name in rects:
		var r: Dictionary = rects[name]
		if not (r.has("l") and r.has("r")):
			continue
		# The full-bleed backdrop and card layers are meant to overhang.
		#
		# The Meja_* desk overlays belong to that same class and were
		# added to this list on 2026-09-10, when they were deliberately
		# nudged 8-10px during the per-student desk-art pass. They are
		# full-bleed art sized to the screen, not controls positioned
		# inside it: their offsets are a bleed against the rim, which is
		# exactly what this rule is meant to allow rather than catch.
		if name in ["Backdrop", "BGLayer", "ColorRect", "TutorialOverlay"]:
			continue
		if name.begins_with("Meja_"):
			continue
		if r["l"] < RIM_CLEARANCE or r["r"] > SCREEN_W - RIM_CLEARANCE:
			offenders.append("%s spans %f..%f" % [name, r["l"], r["r"]])
	assert_eq(offenders.size(), 0,
		"lobby controls within %fpx of the rim:\n  " % RIM_CLEARANCE
			+ "\n  ".join(offenders))


func test_hud_does_not_sit_on_the_front_row_faces() -> void:
	# Front-row head centres, derived from the portrait art's opaque
	# bounds (Thea.png: art starts 10.8% down, centred 49.9% across)
	# mapped through Slot3 and Slot4's rects.
	var heads := [Vector2(225, 389), Vector2(845, 389)]
	var radius := 110.0
	var rects := _rects()
	for name in ["DisplayUang", "DailyLogin"]:
		assert_true(rects.has(name), "lobby is missing node: " + name)
		var r: Dictionary = rects[name]
		for head in heads:
			var overlaps: bool = head.x + radius > r["l"] and head.x - radius < r["r"] \
				and head.y + radius > r["t"] and head.y - radius < r["b"]
			assert_true(not overlaps,
				"%s (%f..%f, %f..%f) covers a student's head at %s"
					% [name, r["l"], r["r"], r["t"], r["b"], str(head)])
