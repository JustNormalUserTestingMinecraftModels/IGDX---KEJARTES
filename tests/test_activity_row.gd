@tool
extends McpTestSuite

## ActivityRow is the Penjadwalan popup's repeated row: icon, a pill of
## preview numbers, and the outlined category name. These tests pin its
## structure and its theming, because the popup builds five of them and a
## silent styling failure would be invisible until someone opened the game.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

const _SCENE_PATH := "res://Scenes/AturJadwal/ActivityRow.tscn"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "activity_row"


var _row: Button


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_row = scene.instantiate()
	_row.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_row)
	track(_row)


func teardown() -> void:
	if is_instance_valid(_row):
		_row.queue_free()
	_row = null


func test_scene_instantiates_as_a_button() -> void:
	assert_true(_row != null, "ActivityRow.tscn must load")
	assert_true(_row is Button, "the whole row must be tappable, so its root is a Button")


func test_row_meets_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	assert_true(_row.custom_minimum_size.y >= float(tokens.touch_target_min),
		"a row must be at least touch_target_min tall")


func test_row_has_the_nodes_the_script_reaches_for() -> void:
	for path in ["IconBox/Icon", "Pill", "Pill/Chips", "NameLabel"]:
		assert_true(_row.get_node_or_null(path) != null,
			"ActivityRow.tscn must declare the node: " + path)


func test_name_label_uses_the_outlined_variation() -> void:
	var label := _row.get_node_or_null("NameLabel") as Label
	assert_true(label != null, "NameLabel must exist")
	assert_eq(label.theme_type_variation, &"CardSectionLabel",
		"the category name is white-on-art, so it needs the outlined variation")


func test_pill_uses_the_preview_pill_variation() -> void:
	var pill := _row.get_node_or_null("Pill") as PanelContainer
	assert_true(pill != null, "Pill must exist")
	assert_eq(pill.theme_type_variation, &"PreviewPill",
		"the pill must wear the PreviewPill variation, not a theme_override")


func test_theme_declares_the_new_variations() -> void:
	var theme: Theme = load(_THEME_PATH)
	for variation in ["PreviewPill", "PreviewChipLabel"]:
		assert_true(theme.get_type_list().has(variation),
			"the baked theme must declare " + variation + " -- did you forget to rebake?")


func test_scene_has_no_theme_overrides() -> void:
	# The project rule: styling flows from the theme, never from per-node
	# overrides. Layout-only constants (separation, margin_*) are exempt.
	var src := FileAccess.get_file_as_string(_SCENE_PATH)
	for line in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		var is_layout := line.begins_with("theme_override_constants/separation") \
			or line.begins_with("theme_override_constants/margin")
		assert_true(is_layout, "unexpected theme override in ActivityRow.tscn: " + line)


func test_refresh_writes_the_skill_gain_into_a_chip() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Akademis"
	_row.refresh(student, 7, 50.0)
	var chips := _row.get_node("Pill/Chips")
	assert_true(chips.get_child_count() >= 1, "refresh must populate at least one chip")


func test_refresh_builds_two_chips_for_libur() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Istirahat"
	_row.refresh(student, 7, 0.0)
	var chips := _row.get_node("Pill/Chips")
	assert_eq(chips.get_child_count(), 2,
		"Libur shows an energy chip and a mood chip")


## Rebuilding must not accumulate. Opening the popup five times used to be
## enough to stack fifteen stale chips behind the live ones.
func test_refresh_is_idempotent() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Istirahat"
	_row.refresh(student, 7, 0.0)
	var after_first := _row.get_node("Pill/Chips").get_child_count()
	_row.refresh(student, 7, 0.0)
	_row.refresh(student, 7, 0.0)
	assert_eq(_row.get_node("Pill/Chips").get_child_count(), after_first,
		"refresh must clear old chips before adding new ones")
