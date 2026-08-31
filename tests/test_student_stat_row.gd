@tool
extends McpTestSuite

## One "icon (or glyph) + bar + number" row. SchoolDay's per-student
## energy/mood readout and DailyDecayOverview's end-of-day summary both
## built this four-node shape by hand -- a change meant editing two
## near-identical builders that had already drifted (different bar
## heights, glyph/label widths, and InfoLabel theme variation). Those
## three differences are now @export knobs on the shared scene; the rest
## (separation, alignment, InfoLabel width) is baked in identically
## because the shipped values already matched.
##
## setup()'s signature is (label_text, value, category, icon_texture)
## -- not the StatInfo-driven "bar_name" the original plan sketch assumed.
## The real call sites (SchoolDay.gd:_add_embedded_bar_row,
## DailyDecayOverview.gd:_add_bar_row) already pass a category string
## ("Libur"/"Istirahat") straight to StatBar.category, so there was
## nothing for StatInfo to resolve.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "student_stat_row"


const SCENE_PATH := "res://Scenes/SchoolSimulation/StudentStatRow.tscn"
const SCRIPT_PATH := "res://Scripts/SchoolSimulation/StudentStatRow.gd"


func _make() -> StudentStatRow:
	var row: StudentStatRow = load(SCENE_PATH).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	return row


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var row := _make()
	for node_name in ["Icon", "Glyph", "Bar", "InfoLabel"]:
		assert_not_null(row.get_node_or_null(node_name), "missing node: %s" % node_name)


func test_setup_without_an_icon_shows_the_glyph_label() -> void:
	var row := _make()
	row.setup("⚡", 47.0, "Libur")
	assert_eq((row.get_node("Bar") as StatBar).value, 47.0)
	assert_eq((row.get_node("Bar") as StatBar).category, "Libur")
	assert_eq((row.get_node("InfoLabel") as Label).text, "47/100")
	assert_false((row.get_node("Icon") as TextureRect).visible)
	assert_true((row.get_node("Glyph") as Label).visible)
	assert_eq((row.get_node("Glyph") as Label).text, "⚡")


func test_setup_with_an_icon_hides_the_glyph() -> void:
	var row := _make()
	var tex := PlaceholderTexture2D.new()
	row.setup("⚡", 10.0, "Istirahat", tex)
	assert_true((row.get_node("Icon") as TextureRect).visible)
	assert_eq((row.get_node("Icon") as TextureRect).texture, tex)
	assert_false((row.get_node("Glyph") as Label).visible)


func test_layout_knobs_default_to_school_day_values() -> void:
	var row := _make()
	assert_eq(row.glyph_min_width, 36.0)
	assert_eq(row.bar_min_height, 32.0)
	assert_eq(row.info_label_variation, &"CaptionLabel")


func test_overriding_layout_knobs_reaches_the_nodes() -> void:
	var row := _make()
	row.glyph_min_width = 220.0
	row.bar_min_height = 48.0
	row.info_label_variation = &"TitleLabel"
	assert_eq((row.get_node("Glyph") as Label).custom_minimum_size.x, 220.0)
	assert_eq((row.get_node("Bar") as StatBar).custom_minimum_size.y, 48.0)
	assert_eq((row.get_node("InfoLabel") as Label).theme_type_variation, &"TitleLabel")


func test_animate_to_forwards_to_the_bar() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var body := src.get_slice("func animate_to", 1)
	assert_contains(body, "set_stat(value, true)")


func test_both_screens_use_the_shared_row() -> void:
	for path in ["res://Scripts/SchoolSimulation/SchoolDay.gd",
			"res://Scripts/SchoolSimulation/DailyDecayOverview.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "StudentStatRow", "%s should use the shared row" % path)
		assert_false(src.contains("StatBar.new("),
			"%s still builds a bar by hand" % path)
