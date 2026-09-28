@tool
extends McpTestSuite

## NotebookFrame (2026-09-28 UI depth pass): the popup frame every popup
## moves into in Phase 2. Its decoration lives under one Chrome node, authored
## in the .tscn and kept full-size and behind; any other child is host
## content, laid into the page by sort_now(). Tabs and rings are authored,
## only shown or hidden -- never built at runtime.
##
## _frame() mounts its instance under the scene tree root: out of the tree,
## Control.get_parent_anchorable_rect() returns an empty rect, so size and
## fit_child_in_rect() cannot resolve and every layout assertion sees zeros.
##
## Must be @tool; no test here may be a coroutine.

const SCENE := "res://Scenes/UI/NotebookFrame.tscn"
const SCRIPT_PATH := "res://Scripts/UI/NotebookFrame.gd"
## Test frame size, px.
const FRAME_SIZE := Vector2(800, 900)


func suite_name() -> String:
	return "notebook_frame"


func _frame() -> NotebookFrame:
	var frame := load(SCENE).instantiate() as NotebookFrame
	track(frame)
	Engine.get_main_loop().root.add_child(frame)
	frame.size = FRAME_SIZE
	return frame


func test_host_content_lands_inside_the_page() -> void:
	var frame := _frame()
	var host := Control.new()
	frame.add_child(host)
	frame.sort_now()
	var r := frame.content_rect()
	assert_eq(host.position, r.position, "content starts at the padded corner")
	assert_eq(host.size, r.size, "and fills the padded page")
	assert_true(Rect2(Vector2.ZERO, FRAME_SIZE).encloses(r), "inside the frame")


func test_sort_now_is_a_no_op_off_tree() -> void:
	var frame := load(SCENE).instantiate() as NotebookFrame
	track(frame)
	var host := Control.new()
	frame.add_child(host)
	frame.sort_now()
	assert_eq(host.size, Vector2.ZERO, "off-tree, sort_now waits for the tree")


func test_the_decoration_is_full_size_and_behind() -> void:
	var frame := _frame()
	frame.sort_now()
	var chrome := frame.get_child(0) as Control
	assert_eq(chrome.name, &"Chrome", "the decoration is the first child, drawn first")
	assert_true(chrome.has_meta(NotebookFrame.CHROME_META), "and is marked as chrome")
	assert_eq(chrome.size, FRAME_SIZE, "it spans the whole frame")


func test_tabs_follow_the_export() -> void:
	var frame := _frame()
	frame.tabs = PackedStringArray(["SUARA", "MAIN"])
	frame.active_tab = 0
	var tab0 := frame.get_node("Chrome/Tabs/Tab0") as Button
	var tab1 := frame.get_node("Chrome/Tabs/Tab1") as Button
	var tab2 := frame.get_node("Chrome/Tabs/Tab2") as Button
	assert_true(tab0.visible and tab0.text == "SUARA", "first tab shows its name")
	assert_eq(tab0.theme_type_variation, &"NotebookTabActive", "the active tab is gold")
	assert_eq(tab1.theme_type_variation, &"NotebookTab", "the other is sky")
	assert_false(tab2.visible, "an unused tab hides")
	frame.tabs = PackedStringArray()
	assert_false((frame.get_node("Chrome/Tabs") as Control).visible, "no tabs, no strip")


func test_rings_well_tape_and_close_follow_the_exports() -> void:
	var frame := _frame()
	frame.ring_count = 4
	for i in NotebookFrame.MAX_RINGS:
		assert_eq((frame.get_node("Chrome/Rings/Ring%d" % i) as CanvasItem).visible, i < 4,
			"ring %d" % i)
	frame.show_well = false
	frame.show_tape = false
	frame.show_close = false
	assert_false((frame.get_node("Chrome/Well") as CanvasItem).visible, "well hides")
	assert_false((frame.get_node("Chrome/Tape") as CanvasItem).visible, "tape hides")
	assert_false((frame.get_node("Chrome/Close") as CanvasItem).visible, "close hides")


func test_the_rings_run_down_the_spine() -> void:
	var frame := _frame()
	frame.ring_count = 7
	frame.sort_now()
	var rings := frame.get_node("Chrome/Rings") as Control
	# The Rings VBox's own child positions are a deferred sort; force it now
	# so this synchronous test sees where the rings actually land.
	(rings as Container).queue_sort()
	rings.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var ring0 := frame.get_node("Chrome/Rings/Ring0") as Control
	var ring6 := frame.get_node("Chrome/Rings/Ring6") as Control
	assert_true(absf(ring0.position.y) <= 4.0, "the rings span the spine top to bottom")
	assert_true(absf(ring6.position.y + ring6.size.y - rings.size.y) <= 4.0,
		"the rings span the spine top to bottom")


func test_the_title_reaches_the_sticker() -> void:
	var frame := _frame()
	frame.title_text = "PENGATURAN"
	assert_eq((frame.get_node("Chrome/Sticker/Title") as Label).text, "PENGATURAN")


func test_tab_and_close_presses_become_signals() -> void:
	var frame := _frame()
	frame.tabs = PackedStringArray(["SUARA", "MAIN"])
	var got := []
	frame.tab_selected.connect(func(i: int) -> void: got.append(i))
	frame.close_pressed.connect(func() -> void: got.append("close"))
	(frame.get_node("Chrome/Tabs/Tab1") as Button).pressed.emit()
	(frame.get_node("Chrome/Close") as Button).pressed.emit()
	assert_eq(got, [1, "close"], "tab 1 then close")
	assert_eq(frame.active_tab, 1, "the pressed tab becomes active")


func test_the_authored_ring_spacing_is_not_baked() -> void:
	var src := FileAccess.get_file_as_string(SCENE)
	assert_contains(src, "theme_override_constants/separation = 40",
		"the authored Rings gap survives -- _spread_rings() never bakes into the .tscn")
	var start := src.find("[node name=\"Well\"")
	var next_node := src.find("[node ", start + 1)
	var well_block := src.substr(start, next_node - start)
	assert_false(well_block.contains("offset_"),
		"the Well's runtime-computed offsets never get saved into the frame's own scene")


func test_nothing_is_built_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains(".new()"), "every node is authored in the .tscn")
