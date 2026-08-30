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


func test_debug_tutorial_bypass_skips_the_atur_jadwal_tutorial() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("if GameState.tutorials_bypassed or tutorial_phase3_done:"),
		"the debug menu's master tutorial-bypass flag must skip this screen's tutorial too")


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
		"Penjadwalan/TextureRect/Rows/RowAkademik", "Penjadwalan/TextureRect/Rows/RowSeniBudaya",
		"Penjadwalan/TextureRect/Rows/RowAtletik", "Penjadwalan/TextureRect/Rows/RowWirausaha",
		"Penjadwalan/TextureRect/Rows/RowLibur", "Penjadwalan/TextureRect/PopupBack",
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


## The popup's five picks are ActivityRows now: icon, preview pill, name.
func test_popup_has_five_activity_rows() -> void:
	var root := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows")
	assert_true(root != null, "the popup must hold its rows in a Rows container")
	var found := {}
	for child in root.get_children():
		if child is ActivityRow:
			found[child.category] = child
	for category in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha", "Istirahat"]:
		assert_true(found.has(category),
			"the popup must offer an ActivityRow for " + category)
	assert_eq(found.size(), 5, "exactly five activity rows, no more")


## The three skill rows keep their progress-toward-target bar; the other two
## have no target, so they must not carry one.
func test_only_skill_rows_carry_a_stat_bar() -> void:
	var root := _screen.get_node("Penjadwalan/TextureRect/Rows")
	for child in root.get_children():
		if not (child is ActivityRow):
			continue
		var bar := child.get_node_or_null("Container/Pill/StatBar")
		var is_skill: bool = child.category in ["Akademis", "SeniBudaya", "Olahraga"]
		if is_skill:
			assert_true(bar != null, child.category + " must keep its StatBar")
		else:
			assert_true(bar == null, child.category + " has no target, so no StatBar")


## The UI says "Atletik" where the code says "Olahraga". Keeping the two
## apart is what lets the label change without breaking every category match.
func test_display_names_are_indonesian_and_decoupled_from_category_keys() -> void:
	var root := _screen.get_node("Penjadwalan/TextureRect/Rows")
	var expected := {
		"Akademis": "Akademik",
		"SeniBudaya": "Seni Budaya",
		"Olahraga": "Atletik",
		"Wirausaha": "Wirausaha",
		"Istirahat": "Libur",
	}
	for child in root.get_children():
		if child is ActivityRow:
			assert_eq(child.display_name, expected[child.category],
				child.category + " must display as " + expected[child.category])


func test_popup_still_has_a_back_button() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack")
	assert_true(back != null, "the popup needs its own back control")
	assert_true(back is BaseButton, "the back control must be tappable")


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


## CLAUDE.md flags atur_jadwal.gd as holding its own copies of numbers that
## also live in Balance.gd. A shadow constant means the tester edits Balance,
## reruns, and the screen does not move -- the exact failure Balance.gd exists
## to prevent.
func test_no_shadow_balance_constants_remain() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for shadowed in [
		"BASE_GAIN", "HOBBY_BONUS_GAIN",
		"MOOD_LOSS_MIN", "MOOD_LOSS_MAX",
		"ENERGY_LOSS_MIN", "ENERGY_LOSS_MAX",
		"DAYOFF_GAIN_MIN", "DAYOFF_GAIN_MAX",
		"WIRAUSAHA_MOOD_MIN", "WIRAUSAHA_MOOD_MAX",
		"WIRAUSAHA_ENERGY_MIN", "WIRAUSAHA_ENERGY_MAX",
	]:
		assert_true(not src.contains("const " + shadowed),
			"atur_jadwal.gd must not redeclare " + shadowed + "; read Balance.gd via ActivityPreview")


## The projected-gain readout was grade-blind: it hardcoded grade 7's numbers,
## so grades 8 and 9 previewed gains their students would never get.
func test_pending_gain_is_grade_aware() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("ActivityPreview.skill_gain"),
		"_compute_pending_gain must delegate to ActivityPreview so it follows the grade")


## The card art is a 1080x1080 texture whose visible card occupies only
## x 211-868, y 34-1046. Rendered into a square 1394x1394 TextureRect, that
## content lands at local x 272-1120, y 44-1350 -- and on screen at x 115-964,
## y 202-1508, which is the mockup's card position (115-964, 203-1507).
const _CARD_LEFT := 272.0
const _CARD_RIGHT := 1120.0
const _CARD_TOP := 44.0
const _CARD_BOTTOM := 1350.0
const _ROW_HEIGHT := 180.0


func test_rows_are_inset_within_the_card_content() -> void:
	var rows := _screen.get_node_or_null("Penjadwalan/TextureRect/Rows") as Control
	assert_true(rows != null, "Rows must exist")
	assert_eq(rows.offset_left, 375.0, "rows are inset 12.1% from the card's left edge")
	assert_eq(rows.offset_right, 1024.0, "rows are inset 11.3% from the card's right edge")
	assert_eq(rows.offset_top, 102.0, "the first row starts 4.4% down the card")
	assert_true(rows.offset_left > _CARD_LEFT and rows.offset_right < _CARD_RIGHT,
		"the row block must sit inside the card art, not over its transparent padding")
	assert_true(rows.offset_top > _CARD_TOP,
		"the row block must start below the card's top edge, not over its transparent padding")


func test_row_separation_matches_the_mockup_pitch() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	assert_eq(rows.get_theme_constant("separation"), 40,
		"a 180px row plus 40px separation reproduces the mockup's 220px pitch")


func test_back_arrow_sits_inside_the_card() -> void:
	var back := _screen.get_node_or_null("Penjadwalan/TextureRect/PopupBack") as Control
	assert_true(back != null, "PopupBack must exist")
	assert_eq(back.offset_left, 329.0, "back arrow x, 6.7% in from the card's left")
	assert_eq(back.offset_top, 1170.0, "back arrow y, its art centred 92.3% down the card")
	assert_true(back.offset_left >= _CARD_LEFT,
		"the back arrow must not hang off the card's left padding")
	assert_true(back.offset_bottom <= _CARD_BOTTOM,
		"the back arrow must stay above the card's bottom edge")


## 102 + 5*180 + 4*40 = 1162, which must clear the card's bottom edge with room
## for the arrow beneath. If a later change alters row height or separation,
## this is the test that catches the stack overflowing the card.
func test_the_row_stack_fits_inside_the_card() -> void:
	var rows := _screen.get_node("Penjadwalan/TextureRect/Rows") as VBoxContainer
	var row_count := 0
	var row_height := 0.0
	for child in rows.get_children():
		if child is ActivityRow:
			row_count += 1
			row_height = (child as ActivityRow).custom_minimum_size.y
	assert_eq(row_height, _ROW_HEIGHT, "each row is the mockup's 180px tall")
	var sep: int = rows.get_theme_constant("separation")
	var stack_bottom: float = rows.offset_top + row_count * row_height + (row_count - 1) * sep
	assert_true(stack_bottom <= _CARD_BOTTOM,
		"the row stack ends at %d, past the card's bottom at %d" % [int(stack_bottom), int(_CARD_BOTTOM)])


## The mockup's card spans 78.7% of the 1080px screen width (x 115-964). Rendering
## the card texture into too small a rect makes a correct layout look cramped at
## every level, because every child inherits the shortfall.
func test_card_is_rendered_at_the_mockup_scale() -> void:
	var card := _screen.get_node_or_null("Penjadwalan/TextureRect") as TextureRect
	assert_true(card != null, "the popup's card TextureRect must exist")
	var w: float = card.offset_right - card.offset_left
	var h: float = card.offset_bottom - card.offset_top
	assert_eq(w, h, "the card rect must stay square so the 1080x1080 art is not stretched")
	assert_eq(w, 1394.0, "the card rect is 1394px so its content renders 850px wide")
	# Mockup card centre is 105px above screen centre, not centred.
	var centre_y: float = (card.offset_top + card.offset_bottom) / 2.0
	assert_eq(centre_y, -105.0, "the card sits 105px above screen centre, as in the mockup")


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
