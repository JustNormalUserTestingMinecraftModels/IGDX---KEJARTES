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


## ReportCard's stagger table drifted from StudentCard's: it named four
## nodes that test_student_card_layout asserts must not exist, and omitted
## the bio panel and all five icon clusters, so those never animated in.
## The two screens render the same card, so the table must be the same.
func test_stagger_table_matches_the_student_card() -> void:
	var report := FileAccess.get_file_as_string(
		"res://Scripts/ReportCard/report_card.gd")
	for row_name in ["BioPanel", "IconAkademis1", "IconAkademis2",
			"IconAkademis3", "IconKepribadian1", "IconKepribadian2"]:
		assert_true(report.contains('"%s"' % row_name),
			"CARD_ROW_ORDER is missing %s" % row_name)
	for dead in ["\"Nama\"", "\"Profil\"", "\"Kepribadian\",", "\"Akademis\","]:
		assert_false(report.contains(dead),
			"CARD_ROW_ORDER still names the removed node %s" % dead)


## Without the pre-hide, the incoming page's rows ride the card's own
## modulate up to fully visible, then get yanked back to invisible when
## _stagger_in_card's pop_in() takes over. StudentCard calls this before
## the fade-in tween, not after (student_card.gd:667).
func test_rows_are_hidden_before_they_stagger_in() -> void:
	var report := FileAccess.get_file_as_string(
		"res://Scripts/ReportCard/report_card.gd")
	assert_true(report.contains("func _hide_card_rows("),
		"report_card.gd has no _hide_card_rows")
	var hide_at := report.find("_hide_card_rows(new_index)")
	var tween_at := report.find("var tween_in = create_tween()")
	assert_true(hide_at != -1, "_hide_card_rows is never called on transition")
	assert_true(tween_at != -1, "the page transition tween is gone")
	assert_true(hide_at < tween_at,
		"the pre-hide must run BEFORE the card's fade-in tween")


## The screen is a read-only report; nothing on it can be chosen, so the
## copied "Pilih Muridmu" header was wrong. Indonesian, per project
## convention.
func test_header_reads_as_a_report_not_a_chooser() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	var header := scene.get_node_or_null("PilihMurid") as Label
	assert_true(header != null, "PilihMurid header label is missing")
	assert_eq(header.text, "Rapor Murid",
		"header still carries StudentCard's chooser copy")
	scene.free()


## ReportCard has no tutorial (test_script_has_no_tutorial), so the copied
## spotlight ColorRect and its full-rect ClickArea button were dead weight
## sitting over the whole card stack.
func test_tutorial_scrim_is_gone() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene.get_node_or_null("ColorRect") == null,
		"the vestigial tutorial ColorRect is still in the scene")
	scene.free()
