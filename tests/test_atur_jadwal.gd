@tool
extends McpTestSuite

## AturJadwal is the weekly-scheduling screen: pick a day (Senin-Jumat) per
## student, assign a category (Akademis/Olahraga/SeniBudaya/Istirahat), then
## START WEEK routes to SchoolDay. Contract that must never change:
## GameState.day_schedules[student_id][day_name] = {category, mood_cost,
## energy_cost} -- SchoolDay (not yet migrated) reads this shape directly.
##
## Technique notes carried over from Tasks 9-14 (see test_student_card.gd /
## test_main_menu.gd for the fuller writeup):
##  * This suite must itself be @tool.
##  * The runner calls suite.call(name) WITHOUT awaiting -- no coroutine tests.
##  * _collect_overrides is copied verbatim from test_main_menu.gd.
##  * Per Task 12's finding (student_card.gd, not @tool): _ready() does NOT
##    run when this suite instantiates a non-@tool Control under the editor's
##    own root. Structural/contract checks below therefore use
##    get_node_or_null() against the scene-declared tree and source-text
##    scanning, never runtime state that only _ready() would populate.

const _SCENE_PATH := "res://Scenes/AturJadwal/atur_jadwal.tscn"
const _SCRIPT_PATH := "res://Scripts/AturJadwal/atur_jadwal.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "atur_jadwal"


var _screen: Control


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_screen = scene.instantiate()
	_screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_screen)
	track(_screen)


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


# ------------------------------------------------ behavioral contract net

func test_still_routes_to_lobby_studentlist_and_schoolday() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"back button must still route to the Lobby")
	assert_true(src.contains("res://Scenes/StudentList/student_list.tscn"),
		"selecting a student must still route to StudentList")
	assert_true(src.contains("res://Scenes/SchoolSimulation/SchoolDay.tscn"),
		"starting the week must still route to SchoolDay")


func test_day_schedules_still_written_in_the_same_shape() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.day_schedules"),
		"must still write GameState.day_schedules")
	for key in ["\"category\"", "\"mood_cost\"", "\"energy_cost\""]:
		assert_true(src.contains(key),
			"day_schedules entries must still carry " + key)


func test_stat_bar_gd_is_deleted_and_unreferenced() -> void:
	assert_false(FileAccess.file_exists("res://Scripts/AturJadwal/stat_bar.gd"),
		"Scripts/AturJadwal/stat_bar.gd must be deleted")
	var tscn := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_false(tscn.contains("stat_bar.gd"),
		"the scene must no longer reference the deleted stat_bar.gd")
	var gd := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(gd.contains("stat_bar.gd"),
		"the script must no longer reference the deleted stat_bar.gd")


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_screen != null, "scene must instantiate")
	assert_true(_screen.is_inside_tree(), "scene must enter the tree cleanly")
	for day in ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]:
		assert_true(_screen.get_node_or_null("BGHari/" + day) != null,
			"missing day button: " + day)
	assert_true(_screen.get_node_or_null("Peringatan") != null, "missing Peringatan")
	assert_true(_screen.get_node_or_null("Penjadwalan") != null, "missing Penjadwalan")


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func test_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"script must read colors from DesignTokens, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var paths := [
		"BGHari/Senin", "BGHari/Selasa", "BGHari/Rabu", "BGHari/Kamis", "BGHari/Jumat",
		"StartWeek", "BackButton",
		"Peringatan/TextureRect/ButtonYes", "Peringatan/TextureRect/ButtonNo",
		"Penjadwalan/TextureRect/Akademik", "Penjadwalan/TextureRect/Olahraga",
		"Penjadwalan/TextureRect/SeniBudaya", "Penjadwalan/TextureRect/Libur",
	]
	for p in paths:
		var b := _screen.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		if b == null:
			continue
		var h: float = maxf(b.size.y * b.scale.y, b.get_combined_minimum_size().y * b.scale.y)
		var w: float = maxf(b.size.x * b.scale.x, b.get_combined_minimum_size().x * b.scale.x)
		assert_true(minf(h, w) >= float(tokens.touch_target_min),
			"%s is %dx%d px, below the %d px minimum touch target"
				% [p, int(w), int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

func test_day_buttons_are_tinted_via_category_color() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("category_color"),
		"day button tint must come from DesignTokens.category_color()")


func test_popup_category_bars_are_statbars() -> void:
	var expected := {
		"Penjadwalan/TextureRect/Akademik/ProgressBar": "Akademis",
		"Penjadwalan/TextureRect/Olahraga/ProgressBar2": "Olahraga",
		"Penjadwalan/TextureRect/SeniBudaya/ProgressBar3": "SeniBudaya",
	}
	for p in expected.keys():
		var bar := _screen.get_node_or_null(p)
		assert_true(bar is StatBar, "%s must be a StatBar" % p)
		if bar is StatBar:
			assert_eq(bar.category, expected[p], "%s category" % p)


func test_bg_stat_bars_are_statbars() -> void:
	var expected := {
		"TextureButton/BGStat/Akademis1": "Akademis",
		"TextureButton/BGStat/Akademis2": "SeniBudaya",
		"TextureButton/BGStat/Akademis3": "Olahraga",
		"TextureButton/BGStat/Kepribadian1": "Istirahat",
		"TextureButton/BGStat/Kepribadian2": "Libur",
	}
	for p in expected.keys():
		var bar := _screen.get_node_or_null(p)
		assert_true(bar is StatBar, "%s must be a StatBar" % p)
		if bar is StatBar:
			assert_eq(bar.category, expected[p], "%s category" % p)


func test_peringatan_pops_in_over_a_scrim_with_shake_and_fail_sfx() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.pop_in(peringatan)"),
		"Peringatan must enter with Juice.pop_in")
	assert_true(src.contains("&\"Scrim\""),
		"the warning backdrop must be a Scrim-variation panel")
	assert_true(src.contains("Juice.shake(peringatan)"),
		"an incomplete-schedule attempt must shake the warning dialog")
	assert_true(src.contains("AudioDirector.play_sfx(&\"fail\")"),
		"an incomplete-schedule attempt must play the fail sfx")


# ----------------------------------------------------------------- helper

## Copied verbatim from tests/test_main_menu.gd.
func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)
