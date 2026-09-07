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
