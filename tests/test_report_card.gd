@tool
extends McpTestSuite

## Report card: a read-only student card viewer over approved_students.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "report_card"

const _SCENE_PATH := "res://Scenes/ReportCard/report_card.tscn"
const _SCRIPT_PATH := "res://Scripts/ReportCard/report_card.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "report_card.tscn must exist")
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "report_card.tscn must instantiate")
	scene.free()

func test_has_no_approve_buttons() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("Aprove", true, false) == null,
		"the report card is a viewer -- no approve button")
	scene.free()

func test_has_no_stamp() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("StampApprove", true, false) == null,
		"the report card is a viewer -- no approval stamp")
	scene.free()

func test_has_no_belajar_button() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.find_child("BelajarButton", true, false) == null,
		"the report card is a viewer -- no belajar button")
	scene.free()

func test_script_has_no_approval_logic() -> void:
	var src := _source()
	for symbol in ["_on_approve_pressed", "MAX_APPROVE", "_shift_approve_for_belajar", "_show_stamp_if_approved"]:
		assert_false(src.contains(symbol),
			"approval logic must not survive the derivation: " + symbol)

func test_script_has_no_tutorial() -> void:
	var src := _source()
	assert_false(src.contains("tutorial_steps"),
		"the report card has no tutorial")

func test_keeps_pagination_and_swipe() -> void:
	var src := _source()
	assert_true(src.contains("_transition_page"), "pagination is kept")
	assert_true(src.contains("_evaluate_swipe"), "swipe navigation is kept")

func test_pages_come_from_approved_students() -> void:
	assert_true(_source().contains("GameState.approved_students"),
		"the viewer reads the live roster, not the six-entry candidate list")

func test_delegates_rendering_to_the_shared_view() -> void:
	assert_true(_source().contains("StudentCardView."),
		"rendering is shared with student_card, not forked")

func test_back_button_returns_to_lobby() -> void:
	assert_true(_source().contains("res://Scenes/Lobby/loby.tscn"),
		"back must return to the lobby")

func test_back_button_node_exists_and_is_wired() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	var btn := scene.find_child("BackButton", true, false)
	assert_true(btn != null, "the report card must have a real, tappable back button")
	assert_true(btn is BaseButton, "the back control must be a button")
	scene.free()
