@tool
extends McpTestSuite

## GameState.use_item writes the canonical roster keys (kepribadian1/2,
## akademis1/2/3), not the dead "mood"/"energy" keys; use_item_on_students
## is all-or-nothing across a list of students.

func suite_name() -> String:
	return "use_item_on_students"

var _inv_backup: Dictionary
var _roster_backup: Array

func setup() -> void:
	_inv_backup = GameState.inventory.duplicate(true)
	_roster_backup = GameState.approved_students.duplicate(true)
	GameState.inventory = {"TestItem": 3}
	GameState.approved_students = [
		{"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": 50.0,
		 "akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0},
		{"id": 2, "name": "B", "kepribadian1": 95.0, "kepribadian2": 50.0,
		 "akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0},
	]

func teardown() -> void:
	GameState.inventory = _inv_backup
	GameState.approved_students = _roster_backup

func _item(mood := 10, energy := 5, ak := 6) -> ItemData:
	var d := ItemData.new()
	d.item_name = "TestItem"
	d.mood_boost = mood
	d.energy_boost = energy
	d.akademis_boost = ak
	return d

func test_use_item_writes_canonical_keys() -> void:
	var r := GameState.use_item(_item(), 1, 1)
	assert_true(r["applied"])
	assert_eq(GameState.approved_students[0]["kepribadian1"], 60.0, "mood -> kepribadian1")
	assert_eq(GameState.approved_students[0]["kepribadian2"], 55.0, "energy -> kepribadian2")
	assert_eq(GameState.approved_students[0]["akademis1"], 46.0, "akademis -> akademis1")
	assert_false(GameState.approved_students[0].has("mood"), "no dead mood key written")
	assert_eq(r["mood_delta"], 10.0)
	assert_eq(r["akademis_delta"], 6.0)

func test_use_item_clamps_at_100() -> void:
	var r := GameState.use_item(_item(10, 5, 6), 2, 1)  # student B mood 95 -> 100
	assert_eq(GameState.approved_students[1]["kepribadian1"], 100.0)
	assert_eq(r["mood_delta"], 5.0, "delta reflects the clamp")

func test_batch_all_or_nothing_refuses_when_short() -> void:
	GameState.inventory = {"TestItem": 2}
	var r := GameState.use_item_on_students(_item(), [1, 2, 1])
	assert_false(r["applied"])
	assert_eq(GameState.inventory["TestItem"], 2, "stock untouched on refusal")

func test_batch_happy_path_consumes_and_reports() -> void:
	var r := GameState.use_item_on_students(_item(), [1, 2])
	assert_true(r["applied"])
	assert_eq(r["results"].size(), 2)
	assert_true(r["results"][0].has("student_id") and r["results"][0].has("name"))
	assert_true(r["results"][0].has("akademis_delta"))
	assert_eq(GameState.inventory["TestItem"], 1, "2 of 3 consumed")

func test_batch_refuses_null_and_empty() -> void:
	assert_false(GameState.use_item_on_students(null, [1])["applied"])
	assert_false(GameState.use_item_on_students(_item(), [])["applied"])
