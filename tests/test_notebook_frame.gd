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
## Least distance a tab label's centre sits above the page edge, px: half a
## tab label.
const TAB_LABEL_CLEARANCE := 24


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


## The tab strip is drawn behind the page, so a tab's label must sit in the
## part that shows above the page's top edge (y = 0), not on the edge.
func test_the_tab_labels_clear_the_page_edge() -> void:
	var tabs := _frame().get_node("Chrome/Tabs") as Control
	var centre := (tabs.offset_top + tabs.offset_bottom) * 0.5
	assert_true(centre <= -TAB_LABEL_CLEARANCE,
		"the tab labels centre at %d, on or under the page edge" % centre)


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


## The Rings box's minimum size includes `separation * (shown - 1)`, so a
## Control's clamped `size.y` can only grow once a large gap is set -- the
## span must instead come from Rings' own anchors/offsets against Chrome, or
## a frame first sorted large and later shrunk keeps the old, too-big gap
## and overflows. See NotebookFrame._spread_rings().
func _rings_span(frame: NotebookFrame) -> float:
	var chrome := frame.get_node("Chrome") as Control
	var rings := frame.get_node("Chrome/Rings") as Control
	return chrome.size.y * (rings.anchor_bottom - rings.anchor_top) \
		+ rings.offset_bottom - rings.offset_top


func _force_rings_sort(frame: NotebookFrame) -> void:
	var rings := frame.get_node("Chrome/Rings") as Container
	rings.queue_sort()
	rings.notification(Container.NOTIFICATION_SORT_CHILDREN)


func test_the_ring_gap_shrinks_with_the_frame() -> void:
	var frame := _frame()
	frame.ring_count = 7
	frame.sort_now()
	_force_rings_sort(frame)
	frame.size = Vector2(800, 600)
	frame.sort_now()
	_force_rings_sort(frame)
	var ring6 := frame.get_node("Chrome/Rings/Ring6") as Control
	var span := _rings_span(frame)
	assert_true(ring6.position.y + ring6.size.y <= span + 4.0,
		"the shrunk frame's rings fit inside the anchored span")
	frame.ring_count = 4
	frame.sort_now()
	_force_rings_sort(frame)
	frame.ring_count = 7
	frame.sort_now()
	_force_rings_sort(frame)
	ring6 = frame.get_node("Chrome/Rings/Ring6") as Control
	span = _rings_span(frame)
	assert_true(ring6.position.y + ring6.size.y <= span + 4.0,
		"re-growing the ring count still fits inside the anchored span")


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


## The throwaway host scene: the frame instanced inside another scene, with
## root overrides and a host child -- the shape every Phase 2 popup takes.
const HOST := "res://tests/fixtures/notebook_host.tscn"


## `HOST` instanced (out of the tree unless `mount`), freed after the test.
func _host(mount: bool) -> Control:
	var host := load(HOST).instantiate() as Control
	track(host)
	if mount:
		Engine.get_main_loop().root.add_child(host)
	return host


func test_a_nested_frame_applies_its_root_overrides() -> void:
	# NOTIFICATION_SCENE_INSTANTIATED reaches a nested frame BEFORE the
	# host's overrides are set; each setter must refresh the chrome again.
	var frame := _host(false).get_node("Frame") as NotebookFrame
	assert_eq((frame.get_node("Chrome/Sticker/Title") as Label).text, "UJI")
	assert_true((frame.get_node("Chrome/Tabs") as Control).visible, "two tabs show the strip")
	assert_eq((frame.get_node("Chrome/Tabs/Tab1") as Button).text, "DUA")
	assert_eq((frame.get_node("Chrome/Tabs/Tab1") as Button).theme_type_variation,
		&"NotebookTabActive", "active_tab = 1 is the gold one")
	assert_false((frame.get_node("Chrome/Tabs/Tab2") as Control).visible, "no third tab")
	assert_true((frame.get_node("Chrome/Rings/Ring3") as Control).visible, "four rings")
	assert_false((frame.get_node("Chrome/Rings/Ring4") as Control).visible, "not five")
	assert_false((frame.get_node("Chrome/Well") as Control).visible, "no well")
	assert_eq(frame.get_child(1).name, &"Body", "host content follows the chrome")


func test_a_nested_frame_wires_its_buttons_once() -> void:
	var frame := _host(false).get_node("Frame") as NotebookFrame
	var tab := frame.get_node("Chrome/Tabs/Tab0") as Button
	var close := frame.get_node("Chrome/Close") as Button
	assert_eq(tab.pressed.get_connections().size(), 1, "one tab wiring, not one per refresh")
	assert_eq(close.pressed.get_connections().size(), 1, "one close wiring")
	var got := []
	frame.tab_selected.connect(func(i: int) -> void: got.append(i))
	tab.pressed.emit()
	assert_eq(got, [0], "tab 0 reports itself")


## Mounted: out of the tree Control.update_minimum_size() returns early and
## get_combined_minimum_size() keeps serving its first cached answer.
func test_the_minimum_size_wraps_the_host_content() -> void:
	var frame := _host(true).get_node("Frame") as NotebookFrame
	var pad := frame.content_padding
	var want := Vector2(900 + pad.x + pad.z, 1000 + pad.y + pad.w)
	assert_eq(frame.get_combined_minimum_size(), want, "host minimum plus the padding")


func test_the_page_grows_to_hold_big_content() -> void:
	var host := _host(true)
	var frame := host.get_node("Frame") as NotebookFrame
	frame.sort_now()
	var body := frame.get_node("Body") as Control
	assert_true(frame.size.x >= frame.get_combined_minimum_size().x, "the frame grew wide enough")
	assert_true(Rect2(Vector2.ZERO, frame.size).encloses(body.get_rect()), "the content stays on the page")


func test_the_minimum_never_drops_below_the_authored_size() -> void:
	var frame := _frame()
	assert_eq(frame.get_combined_minimum_size(), frame.custom_minimum_size,
		"no host content: the scene's own 640x520 floor")


func test_a_padding_change_updates_the_minimum() -> void:
	var frame := _host(true).get_node("Frame") as NotebookFrame
	var before := frame.get_combined_minimum_size()
	frame.content_padding = Vector4i(0, 0, 0, 0)
	assert_eq(frame.get_combined_minimum_size(), Vector2(900, 1000), "padding gone")
	assert_ne(before, frame.get_combined_minimum_size())


func test_an_empty_title_hides_the_sticker() -> void:
	var frame := _frame()
	frame.title_text = ""
	assert_false((frame.get_node("Chrome/Sticker") as Control).visible, "no title, no sticker")
	frame.title_text = "LOGS"
	assert_true((frame.get_node("Chrome/Sticker") as Control).visible)


func test_the_sticker_widens_to_a_long_title() -> void:
	var frame := _frame()
	var sticker := frame.get_node("Chrome/Sticker") as Control
	frame.title_text = "LOGS"
	frame.sort_now()
	assert_eq(sticker.size.x, NotebookFrame.STICKER_MIN_WIDTH, "a short title keeps the authored width")
	frame.title_text = "DAPATKAN UANG SEKARANG JUGA"
	frame.sort_now()
	var title := sticker.get_node("Title") as Control
	assert_true(sticker.size.x >= title.get_combined_minimum_size().x + 2 * NotebookFrame.STICKER_SIDE_PAD,
		"a long title gets its width plus the stitching margin")
	assert_eq(sticker.offset_left, -sticker.offset_right, "still centred")


func test_the_page_stops_taps() -> void:
	assert_eq(_frame().mouse_filter, Control.MOUSE_FILTER_STOP,
		"a tap on the page must never fall through to a scrim that dismisses")
