@tool
extends McpTestSuite

## Wirausaha: the fifth schedule activity. Students assigned to it earn
## money at a mood/energy cost, paid out at the end of the week.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "wirausaha"

const _JADWAL_SCENE := "res://Scenes/AturJadwal/atur_jadwal.tscn"

func test_schedule_popup_offers_wirausaha() -> void:
	var scene := (load(_JADWAL_SCENE) as PackedScene).instantiate()
	var btn := scene.find_child("Wirausaha", true, false)
	assert_true(btn != null, "the scheduling popup must offer Wirausaha")
	scene.free()

func test_jadwal_script_binds_wirausaha() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
	assert_true(src.contains("_on_activity_selected.bind(\"Wirausaha\")"),
		"the Wirausaha button must be connected")

func test_day_categories_include_wirausaha() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("\"Wirausaha\""),
		"SchoolDay.DAY_CATEGORIES must include Wirausaha")

func test_jadwal_counts_include_wirausaha() -> void:
	GameState.day_schedules = {
		1: {"Senin": {"category": "Wirausaha", "mood_cost": 8, "energy_cost": 10}},
	}
	var counts := GameState.get_jadwal_for_day("Senin")
	assert_true(counts.has("Wirausaha"), "counts must track Wirausaha")
	assert_eq(counts["Wirausaha"], 1, "one student assigned to Wirausaha")
	GameState.day_schedules = {}
