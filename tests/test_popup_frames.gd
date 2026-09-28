@tool
extends McpTestSuite

## Phase 2 of the UI depth pass (docs/superpowers/plans/
## 2026-09-28-ui-depth-pass-phase2.md): every popup sits in a NotebookFrame.
## POPUPS is the roster, one row per popup, added task by task: the scene,
## the frame's node path in it, the frame's kind and how it is placed.
##
## kind -- "dialog": no tabs, four rings, no well. "sheet": no tabs.
## "tabs": a tab strip.
## fit -- "safe": the frame has a SafeAreaMargin ancestor (the tall-phone
## rule). "free": its screen places it; each such row says why.
##
## Must be @tool; no test here may be a coroutine.

const FRAME_SCENE := "res://Scenes/UI/NotebookFrame.tscn"
## A dialog's ring count.
const DIALOG_RINGS := 4
## The typed close glyph every popup used before the frame's round close.
const CLOSE_GLYPH := "✕"

## scene -> [frame node path, kind, fit]. The roster must never be empty;
## Task 2 adds the first rows.
const POPUPS := {
	"res://Scenes/UI/StatDetailPopup.tscn": ["Scrim/Safe/Center/Frame", "dialog", "safe"],
	"res://Scenes/UI/TraitDetailPopup.tscn": ["Scrim/Safe/Center/Frame", "dialog", "safe"],
	"res://Scenes/UI/WeekRecapPillInfoPopup.tscn": ["Scrim/Safe/Center/Frame", "dialog", "safe"],
	"res://Scenes/SchoolSimulation/WeekLogsPopup.tscn": ["Safe/Center/Frame", "sheet", "safe"],
	"res://Scenes/SchoolSimulation/DailyDecayOverview.tscn": ["Safe/Frame", "sheet", "safe"],
	"res://Scenes/SchoolSimulation/DaySummaryPopup.tscn": ["DimOverlay/Safe/Content/Frame", "sheet", "safe"],
	"res://Scenes/Inventory/ItemDetailSheet.tscn": ["Safe/Center/Sheet", "sheet", "safe"],
	"res://Scenes/Achievements/AchievementDetailSheet.tscn": ["Safe/Center/Sheet", "sheet", "safe"],
	"res://Scenes/Lobby/DapatkanUang.tscn": ["Safe/Center/Book", "sheet", "safe"],
	"res://Scenes/UI/Settings.tscn": ["SafeArea/Frame", "tabs", "safe"],
	"res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn": ["Safe/Frame", "dialog", "safe"],
	# free: the letter rises out of the envelope by tweening its position,
	# which a container would reset; it is anchored to the screen's centre.
	"res://Scenes/LevelSelect/OpenAmplopConfirm.tscn": ["Letter", "dialog", "free"],
	"res://Scenes/AturJadwal/AturJadwal.tscn": ["Peringatan/Safe/Center/Frame", "dialog", "safe"],
	"res://Scenes/EndGame/TesNotice.tscn": ["Safe/Center/NoticeCard", "dialog", "safe"],
	"res://Scenes/EndGame/StatCheck.tscn": ["Safe/Center/Frame", "dialog", "safe"],
	# free: StudentCard and SchoolDay each place the panel themselves.
	"res://Scenes/UI/TutorialPanel.tscn": ["Frame", "dialog", "free"],
	# free: the frame is drawn behind the calendar art it wraps, so it
	# rides DailyLoginPanel's own show, hide and scale.
	"res://Scenes/Lobby/Lobby.tscn": ["DailyReward/DailyLoginFrame", "sheet", "free"],
}

## scene -> the script that wires its frame's close, when that is the
## screen's own script rather than the instanced root's.
const SCREEN_SCRIPTS := {
	"res://Scenes/AturJadwal/AturJadwal.tscn": "res://Scripts/AturJadwal/AturJadwal.gd",
	"res://Scenes/Lobby/Lobby.tscn": "res://Scripts/Lobby/Lobby.gd",
}


func suite_name() -> String:
	return "popup_frames"


## `path` instanced out of the tree (no _ready runs), freed after the test.
func _instance(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	track(root)
	return root


## The row's frame, or null (with a failed assertion) when it is missing.
func _frame_of(root: Node, path: String) -> NotebookFrame:
	var frame := root.get_node_or_null(POPUPS[path][0]) as NotebookFrame
	assert_true(frame != null, "%s: no NotebookFrame at %s" % [path, POPUPS[path][0]])
	return frame


func test_the_frame_scene_exists() -> void:
	assert_true(ResourceLoader.exists(FRAME_SCENE), "NotebookFrame.tscn is the one popup frame")


func test_every_popup_wears_the_frame() -> void:
	assert_false(POPUPS.is_empty(), "the roster lists every popup")
	for path in POPUPS:
		var frame := _frame_of(_instance(path), path)
		if frame != null:
			assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_STOP, path + ": the page stops taps")


func test_each_frame_is_its_kind() -> void:
	assert_false(POPUPS.is_empty(), "the roster lists every popup")
	for path in POPUPS:
		var frame := _frame_of(_instance(path), path)
		if frame == null:
			continue
		match String(POPUPS[path][1]):
			"dialog":
				assert_true(frame.tabs.is_empty(), path + ": a dialog has no tabs")
				assert_eq(frame.ring_count, DIALOG_RINGS, path + ": a dialog has four rings")
				assert_false(frame.show_well, path + ": a dialog has no well")
			"sheet":
				assert_true(frame.tabs.is_empty(), path + ": a sheet has no tabs")
			"tabs":
				assert_false(frame.tabs.is_empty(), path + ": a tabbed frame has tabs")
			_:
				assert_true(false, path + ": unknown kind " + String(POPUPS[path][1]))


func test_safe_frames_sit_in_the_safe_area() -> void:
	assert_false(POPUPS.is_empty(), "the roster lists every popup")
	for path in POPUPS:
		if POPUPS[path][2] != "safe":
			continue
		var frame := _frame_of(_instance(path), path)
		if frame == null:
			continue
		var p := frame.get_parent()
		while p != null and not (p is SafeAreaMargin):
			p = p.get_parent()
		assert_true(p != null, path + ": the frame must sit under a SafeAreaMargin")


func test_no_popup_types_its_close_glyph() -> void:
	assert_false(POPUPS.is_empty(), "the roster lists every popup")
	for path in POPUPS:
		assert_false(FileAccess.get_file_as_string(path).contains(CLOSE_GLYPH),
			path + " still types a close glyph")
		var script := _instance(path).get_script() as Script
		if script != null:
			assert_false(script.source_code.contains(CLOSE_GLYPH),
				script.resource_path + " still types a close glyph")


func test_every_shown_close_is_heard() -> void:
	assert_false(POPUPS.is_empty(), "the roster lists every popup")
	for path in POPUPS:
		var root := _instance(path)
		var frame := _frame_of(root, path)
		if frame == null or not frame.show_close:
			continue
		var script_path: String = SCREEN_SCRIPTS.get(path, "")
		if script_path == "":
			script_path = (root.get_script() as Script).resource_path
		assert_contains(FileAccess.get_file_as_string(script_path), "close_pressed.connect",
			"%s shows the frame's close, so %s must wire it" % [path, script_path])
