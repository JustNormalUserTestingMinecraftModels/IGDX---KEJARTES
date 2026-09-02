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
