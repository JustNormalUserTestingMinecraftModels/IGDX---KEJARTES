@tool
extends McpTestSuite

## ApplyItemScreen: structure, routing through GameState.use_item_on_students,
## particle scene references, confirm-label format, no runtime chrome.

func suite_name() -> String:
	return "apply_item_screen"

const _SCENE := "res://Scenes/Inventory/ApplyItemScreen.tscn"
const _SRC := "res://Scripts/Inventory/ApplyItemScreen.gd"

func _src() -> String:
	return FileAccess.get_file_as_string(_SRC)

func test_scene_instantiates_with_structure() -> void:
	assert_true(ResourceLoader.exists(_SCENE), "ApplyItemScreen.tscn must exist")
	var s := (load(_SCENE) as PackedScene).instantiate()
	for n in ["Rows", "ConfirmButton", "SelectAllButton", "CancelButton",
			"RecapIcon", "RecapName", "EffectSummary"]:
		assert_true(s.find_child(n, true, false) != null, "missing " + n)
	s.free()

func test_routes_through_batch_api() -> void:
	assert_true(_src().contains("GameState.use_item_on_students("),
		"confirm must route through the batch API")

func test_references_payoff_particles() -> void:
	var src := _src()
	assert_true(src.contains("RewardBurst.tscn"), "reward burst referenced")
	assert_true(src.contains("CelebrationConfetti.tscn"), "confetti referenced")

func test_confirm_label_is_formatted() -> void:
	assert_true(_src().contains("Pakai (%d Siswa)"), "confirm label shows the count")

func test_script_is_clean() -> void:
	var src := _src()
	assert_false(src.contains("theme_override"), "no theme_override in script")
	assert_false(src.contains("Color(0."), "no raw Color literals")
	assert_true(src.contains("student_row_scene"), "rows come from a PackedScene")

func test_emits_applied_and_cancelled() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	assert_true(s.has_signal("applied"), "has applied signal")
	assert_true(s.has_signal("cancelled"), "has cancelled signal")
	s.free()
