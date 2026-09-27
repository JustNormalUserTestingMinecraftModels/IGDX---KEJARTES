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
	"akademis": 41.0, "seni_budaya": 52.0, "olahraga": 63.0,
	"mood": 70.0, "energy": 30.0,
	"target_akademis": 55.0, "target_seni_budaya": 60.0, "target_olahraga": 65.0,
	"quirk": "Penyendiri", "hobby_category": "Akademik",
}


func test_single_conversion_copies_stats_and_targets() -> void:
	var sd: StudentData = GameState.student_data_from_dict(_ENTRY)
	assert_eq(sd.id, 7)
	assert_eq(sd.student_name, "Citra")
	assert_eq(sd.akademis, 41.0)
	assert_eq(sd.seni_budaya, 52.0, "seni_budaya copies across")
	assert_eq(sd.olahraga, 63.0, "olahraga copies across")
	assert_eq(sd.mood, 70.0, "mood copies across")
	assert_eq(sd.energy, 30.0, "energy copies across")
	assert_eq(sd.target_seni_budaya, 60.0, "target_seni_budaya is the SENI target")
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
			"mood", "energy", "target_akademis", "target_seni_budaya",
			"target_olahraga", "quirk", "specialty_category"]:
		assert_eq(from_array[0].get(field), single.get(field), "field " + field)


func test_array_function_reuses_the_single_rule() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var start := src.find("func convert_to_student_data_array")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	assert_contains(body, "student_data_from_dict(",
		"the array conversion must reuse the single rule")
	assert_false(body.contains("StudentData.new()"),
		"no second copy of the conversion may survive in the array function")
