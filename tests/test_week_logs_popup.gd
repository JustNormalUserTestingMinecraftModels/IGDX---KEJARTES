@tool
extends McpTestSuiteCompat

## WeekLogsPopup (2026-09-14 weekly-results spec): the Logs sheet Weekly
## Results opens -- one WeekHistoryRow per history entry, over a scrim that
## follows the popup-dismiss rule.

const _SCENE := "res://Scenes/SchoolSimulation/WeekLogsPopup.tscn"
const _SCRIPT := "res://Scripts/SchoolSimulation/WeekLogsPopup.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "week_logs_popup"


## The sheet wearing the baked theme, in the tree so its @onready vars are
## live, freed by the runner. Untyped: typed as Control, GDScript rejects
## the script members.
func _popup():
	var p = (load(_SCENE) as PackedScene).instantiate()
	p.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(p)
	track(p)
	return p


func _entry(day: String, category: String, won: bool) -> Dictionary:
	return {"day": day, "category": category, "game_name": "Uji", "won": won}


func test_the_scene_authors_every_node_the_script_binds() -> void:
	var p = _popup()
	for path in ["Scrim", "Center/Card", "Center/Card/Content/TitleLabel",
			"Center/Card/Content/Scroll/Rows",
			"Center/Card/Content/Scroll/Rows/EmptyLabel",
			"Center/Card/Content/CloseButton"]:
		assert_not_null(p.get_node_or_null(path), path + " is authored")


func test_the_scene_supplies_the_history_row_template() -> void:
	var p = _popup()
	assert_not_null(p.history_row_scene, "history_row_scene is assigned")
	assert_eq(p.history_row_scene.resource_path,
		"res://Scenes/SchoolSimulation/WeekHistoryRow.tscn")


func test_the_labels_come_from_the_exports() -> void:
	var p = _popup()
	assert_eq(p.title_label.text, "LOGS")
	assert_eq(p.close_button.text, "Tutup")
	assert_eq(p.empty_label.text, "Tidak ada minigame yang dimainkan minggu ini.")


func test_one_row_per_history_entry_events_included() -> void:
	var p = _popup()
	p.set_history([_entry("Senin", "Akademis", true), _entry("Rabu", "Event", true),
		_entry("Kamis", "Olahraga", false)])
	assert_eq(p.row_count(), 3, "one row per entry, events included")
	assert_false(p.empty_label.visible, "the empty line hides when there is history")
	assert_true(p.rows.get_child(1) is WeekHistoryRow,
		"rows are WeekHistoryRow instances after the authored EmptyLabel")


func test_an_empty_week_shows_the_empty_line() -> void:
	var p = _popup()
	p.set_history([])
	assert_eq(p.row_count(), 0, "no rows")
	assert_true(p.empty_label.visible, "the empty line explains why")


func test_set_history_replaces_rather_than_appends() -> void:
	var p = _popup()
	p.set_history([_entry("Senin", "Akademis", true)])
	p.set_history([_entry("Selasa", "Olahraga", false), _entry("Rabu", "Event", true)])
	assert_eq(p.row_count(), 2, "a second fill replaces the first")


func test_the_scrim_waits_for_the_open() -> void:
	var p = _popup()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"popup-dismiss rule: the opening tap must not also close it")
	p.open()
	assert_eq(p.scrim.mouse_filter, Control.MOUSE_FILTER_STOP,
		"after the open, tapping the dim closes it")


func test_tapping_the_dim_closes_the_sheet() -> void:
	var p = _popup()
	p.open()
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	p._on_scrim_gui_input(tap)
	assert_true(closed[0], "tapping the dim closes the sheet")


func test_the_close_button_closes_the_sheet_once() -> void:
	var p = _popup()
	var count := [0]
	p.closed.connect(func(): count[0] += 1)
	p.close_button.pressed.emit()
	p.close()
	assert_eq(count[0], 1, "closed fires exactly once")


func test_the_center_never_swallows_a_tap_meant_for_the_dim() -> void:
	var p = _popup()
	assert_eq((p.get_node("Center") as Control).mouse_filter,
		Control.MOUSE_FILTER_IGNORE, "taps outside the card must reach the Scrim")


func test_the_sheet_is_authored_not_built() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_false(src.contains(".new("), "no node or stylebox is built at runtime")
	var scene := FileAccess.get_file_as_string(_SCENE)
	for kind in ["theme_override_colors", "theme_override_font_sizes",
			"theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in WeekLogsPopup.tscn")


func test_the_rows_entrance_keeps_stamp_and_shake() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_contains(src, 'play_sfx(&"stamp")', "a won minigame stamps")
	assert_contains(src, "Juice.shake(row)", "a lost one shakes")
	assert_contains(src, "row.is_event()", "an event does neither")
