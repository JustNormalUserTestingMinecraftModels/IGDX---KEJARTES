@tool
extends McpTestSuite

## ItemDetailSheet + its EfekRow / StatBarRow templates.

func suite_name() -> String:
	return "item_detail_sheet"

func test_efek_row_template_instantiates_with_expected_nodes() -> void:
	var path := "res://Scenes/Inventory/EfekRow.tscn"
	assert_true(ResourceLoader.exists(path), "EfekRow.tscn must exist")
	var row := (load(path) as PackedScene).instantiate()
	assert_true(row.get_node_or_null("NeedIcon") != null, "EfekRow needs NeedIcon")
	assert_true(row.get_node_or_null("ValueLabel") != null, "EfekRow needs ValueLabel")
	assert_true(row.get_node_or_null("ExplainLabel") != null, "EfekRow needs ExplainLabel")
	row.free()

func test_stat_bar_row_template_instantiates_with_expected_nodes() -> void:
	var path := "res://Scenes/Inventory/StatBarRow.tscn"
	assert_true(ResourceLoader.exists(path), "StatBarRow.tscn must exist")
	var row := (load(path) as PackedScene).instantiate()
	for n in ["NameLabel", "Bar", "ValueLabel", "DeltaLabel"]:
		assert_true(row.get_node_or_null(n) != null, "StatBarRow missing " + n)
	row.free()

const _SHEET := "res://Scenes/Inventory/ItemDetailSheet.tscn"
const _SHEET_SRC := "res://Scripts/Inventory/ItemDetailSheet.gd"

func _sheet_src() -> String:
	return FileAccess.get_file_as_string(_SHEET_SRC)

func test_sheet_instantiates_with_structure() -> void:
	assert_true(ResourceLoader.exists(_SHEET), "ItemDetailSheet.tscn must exist")
	var s := (load(_SHEET) as PackedScene).instantiate()
	for n in ["Scrim", "Sheet", "EfekList", "ApplyButton"]:
		assert_true(s.find_child(n, true, false) != null, "missing " + n)
	s.free()

func test_sheet_has_five_named_efek_rows() -> void:
	var s := (load(_SHEET) as PackedScene).instantiate()
	for n in ["RowAkademis", "RowSeni", "RowOlahraga", "RowMood", "RowEnergy"]:
		assert_true(s.find_child(n, true, false) != null, "missing " + n)
	s.free()

func test_sheet_script_is_clean() -> void:
	var src := _sheet_src()
	assert_false(src.contains("theme_override"), "no theme_override in script")
	assert_false(src.contains("Color(0."), "no raw Color literals")
	assert_true(src.contains("DesignTokens.load_default()"), "scrim colour from tokens")
	for k in ["akademis", "seni_budaya", "olahraga", "mood", "energy"]:
		assert_true(src.contains('"%s"' % k), "EXPLAIN missing key " + k)

func test_setup_hides_rows_with_no_boost() -> void:
	var s := (load(_SHEET) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(s)
	var item := ItemData.new()
	item.item_name = "X"
	item.category = "Makanan"
	item.description = "desc"
	item.mood_boost = 10
	s.setup(item, 2)
	assert_false(s.find_child("RowAkademis", true, false).visible, "akademis row hidden")
	assert_true(s.find_child("RowMood", true, false).visible, "mood row shown")
	s.free()
