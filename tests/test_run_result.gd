@tool
extends McpTestSuite

## The end-of-grade report: RunResultRow (one row template) here, and the
## RunResult screen itself in the tests appended by the next task.

const _ROW_PATH := "res://Scenes/EndGame/RunResultRow.tscn"


func suite_name() -> String:
	return "run_result"



func test_the_row_template_loads() -> void:
	var row = load(_ROW_PATH).instantiate()
	var ok := row != null
	row.free()
	assert_true(ok, "RunResultRow.tscn instantiates")


func test_the_row_has_icon_name_and_value() -> void:
	var row = load(_ROW_PATH).instantiate()
	var icon = row.get_node_or_null("Row/IconRect")
	var has_all := icon is TextureRect \
		and row.get_node_or_null("Row/NameLabel") != null \
		and row.get_node_or_null("Row/ValueLabel") != null
	row.free()
	assert_true(has_all, "a texture icon, a name label and a value label")


func test_the_icon_is_a_texture_not_a_glyph() -> void:
	var row = load(_ROW_PATH).instantiate()
	var icon = row.get_node_or_null("Row/IconRect")
	var is_texture_rect := icon is TextureRect
	var has_default: bool = is_texture_rect and icon.texture != null
	row.free()
	assert_true(is_texture_rect, "IconRect is a TextureRect, never a Label")
	assert_true(has_default, "the template ships with a stand-in texture")


func test_set_row_swaps_the_icon_texture() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	var wanted: Texture2D = load(
		"res://Assets/Images/UI/Placeholders/icon_uang.svg")
	row.set_row("Uang dari wirausaha", 0.0, "G", wanted)
	var landed: Texture2D = row.get_node("Row/IconRect").texture
	row.free()
	assert_true(landed == wanted, "set_row writes the icon through")


func test_set_row_writes_the_name_and_the_final_value() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	row.set_row("Minigame selesai", 7.0)
	var name_text: String = row.get_node("Row/NameLabel").text
	var value_text: String = row.get_node("Row/ValueLabel").text
	row.free()
	assert_eq(name_text, "Minigame selesai", "the name lands")
	assert_eq(value_text, "0", "the value starts at zero, ready to count up")


func test_set_row_keeps_the_suffix() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	row.set_row("Uang wirausaha", 1500.0, "G")
	var target: float = row.target_value
	var suffix: String = row.value_suffix
	row.free()
	assert_eq(target, 1500.0, "target stored")
	assert_eq(suffix, "G", "suffix stored")


const _SCENE_PATH := "res://Scenes/EndGame/RunResult.tscn"
const _SCRIPT_PATH := "res://Scripts/EndGame/RunResult.gd"


func test_the_screen_loads() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var ok := screen != null
	screen.free()
	assert_true(ok, "RunResult.tscn instantiates")


func test_the_screen_has_a_backdrop_grade_card_and_rows_box() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var has_all := screen.get_node_or_null("Backdrop") != null \
		and screen.get_node_or_null("Scrim") != null \
		and screen.get_node_or_null(
			"MarginContainer/Column/GradeCard/GradeStack/GradeLetter") != null \
		and screen.get_node_or_null("MarginContainer/Column/RowsBox") != null
	screen.free()
	assert_true(has_all, "the report's structural nodes are all present")


func test_the_rows_box_starts_empty_in_the_scene() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var count: int = screen.get_node("MarginContainer/Column/RowsBox").get_child_count()
	screen.free()
	assert_eq(count, 0, "rows are instanced from the template at runtime")


func test_it_reports_all_six_figures() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for label in ["Minigame selesai", "Minigame kalah", "Total poin minigame",
			"Barang dipakai", "Uang dari wirausaha", "Murid ikut event"]:
		assert_true(src.contains(label), "the report includes '%s'" % label)


func test_it_grades_through_run_grade() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("RunGrade.score("), "it scores the run")
	assert_true(src.contains("RunGrade.letter("), "it letters the run")
	assert_true(src.contains("GameState.run_failed"), "a failed run is honoured")


func test_it_applies_grade_progression_and_exits_to_the_menu() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.current_grade += 1"),
		"a win advances the grade")
	assert_true(src.contains("res://Scenes/MainMenu/main_menu.tscn"),
		"the run ends at the main menu")


func test_it_plays_the_report_bgm_and_the_grade_stings() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("play_bgm(&\"run_result\")"), "report BGM")
	assert_true(src.contains("play_sfx(&\"stamp\")"), "the letter slams")
	assert_true(src.contains("play_sfx(&\"coin\")"), "the money row chimes")
	assert_true(src.contains("play_sfx(&\"reward\")"), "an A-band grade rewards")
	assert_true(src.contains("play_sfx(&\"fail\")"), "a D grade stings")


func test_the_report_uses_texture_icons_not_emoji() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Assets/Images/UI/Placeholders/icon_uang.svg"),
		"the rows reference real icon assets")
	for glyph in ["🎮", "💰", "⭐", "🎒", "🎪"]:
		assert_false(src.contains(glyph),
			"no emoji glyph is used as an icon")


func test_no_theme_overrides_in_the_scene() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var offenders: Array[String] = []
	_collect_overrides(screen, offenders)
	screen.free()
	assert_eq(offenders.size(), 0, "no theme_override_*: %s" % str(offenders))


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
