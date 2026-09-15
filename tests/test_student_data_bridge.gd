@tool
extends McpTestSuite

## GameState.student_data_from_dict is the one roster-Dictionary ->
## StudentData rule. convert_to_student_data_array() is built from it, so the
## item screen's cards and the week simulation can never convert a student
## two different ways (2026-09-12 event-cards spec, section 1.5).

func suite_name() -> String:
	return "student_data_bridge"


const _ENTRY := {
	"id": 7, "name": "Citra",
	"akademis1": 41.0, "akademis2": 52.0, "akademis3": 63.0,
	"kepribadian1": 70.0, "kepribadian2": 30.0,
	"target_akademis1": 55.0, "target_akademis2": 60.0, "target_akademis3": 65.0,
	"quirk": "Penyendiri", "hobby_category": "Akademik",
}


func test_single_conversion_copies_stats_and_targets() -> void:
	var sd: StudentData = GameState.student_data_from_dict(_ENTRY)
	assert_eq(sd.id, 7)
	assert_eq(sd.student_name, "Citra")
	assert_eq(sd.akademis, 41.0)
	assert_eq(sd.seni_budaya, 52.0, "akademis2 is seni_budaya")
	assert_eq(sd.olahraga, 63.0, "akademis3 is olahraga")
	assert_eq(sd.mood, 70.0, "kepribadian1 is mood")
	assert_eq(sd.energy, 30.0, "kepribadian2 is energy")
	assert_eq(sd.target_akademis2, 60.0, "target_akademis2 is the SENI target")
	assert_eq(sd.quirk, "Penyendiri")
	assert_eq(sd.specialty_category, "Akademis", "Akademik normalises to Akademis")


func test_array_conversion_matches_the_single_one() -> void:
	var saved: Array = GameState.approved_students.duplicate(true)
	var one: Array = [_ENTRY.duplicate()]
	GameState.approved_students = one
	var from_array: Array[StudentData] = GameState.convert_to_student_data_array()
	GameState.approved_students = saved
	var single: StudentData = GameState.student_data_from_dict(_ENTRY)
	assert_eq(from_array.size(), 1)
	for field in ["id", "student_name", "akademis", "seni_budaya", "olahraga",
			"mood", "energy", "target_akademis1", "target_akademis2",
			"target_akademis3", "quirk", "specialty_category"]:
		assert_eq(from_array[0].get(field), single.get(field), "field " + field)


func test_array_function_reuses_the_single_rule() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var start := src.find("func convert_to_student_data_array")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	assert_contains(body, "student_data_from_dict(",
		"the array conversion must reuse the single rule")
	assert_false(body.contains("StudentData.new()"),
		"no second copy of the conversion may survive in the array function")
