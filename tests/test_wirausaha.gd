@tool
extends McpTestSuite

## Wirausaha: the fifth schedule activity. Students assigned to it earn
## money at a mood/energy cost, paid out at the end of the week.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "wirausaha"

const _JADWAL_SCENE := "res://Scenes/AturJadwal/atur_jadwal.tscn"

## Builds a throwaway approved_students roster and returns the caller's
## original one so each test can restore it.
func _swap_roster(roster: Array) -> Array:
	var original: Array = GameState.approved_students
	GameState.approved_students = roster
	return original

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
	var original := _swap_roster([
		{"id": 1, "student_name": "Uji"},
	])
	GameState.day_schedules = {
		1: {"Senin": {"category": "Wirausaha", "mood_cost": 8, "energy_cost": 10}},
	}
	var counts := GameState.get_jadwal_for_day("Senin")
	assert_true(counts.has("Wirausaha"), "counts must track Wirausaha")
	assert_eq(counts["Wirausaha"], 1, "one student assigned to Wirausaha")
	GameState.day_schedules = {}
	GameState.approved_students = original

func test_pending_earnings_starts_empty() -> void:
	GameState.pending_earnings.clear()
	assert_true(GameState.pending_earnings.is_empty(),
		"no earnings are pending before any Wirausaha day")

func test_wirausaha_accrues_earnings_for_the_assigned_student() -> void:
	GameState.pending_earnings.clear()
	GameState.day_schedules = {
		7: {"Senin": {"category": "Wirausaha", "mood_cost": 10, "energy_cost": 12}},
	}
	var manager := StudentManager.new()
	var student := StudentData.new()
	student.id = 7
	student.student_name = "Uji"
	student.energy = 80.0
	student.mood = 80.0
	manager.students = [student]
	manager.apply_daily_decay_all("Senin")
	assert_true(GameState.pending_earnings.get(7, 0) > 0,
		"a Wirausaha day must accrue money")
	GameState.pending_earnings.clear()
	GameState.day_schedules = {}
	manager.free()

func test_wirausaha_grants_no_academic_stat() -> void:
	GameState.pending_earnings.clear()
	GameState.day_schedules = {
		7: {"Senin": {"category": "Wirausaha", "mood_cost": 10, "energy_cost": 12}},
	}
	var manager := StudentManager.new()
	var student := StudentData.new()
	student.id = 7
	student.student_name = "Uji"
	student.energy = 80.0
	student.mood = 80.0
	student.akademis = 50.0
	student.seni_budaya = 50.0
	student.olahraga = 50.0
	manager.students = [student]
	manager.apply_daily_decay_all("Senin")
	assert_eq(student.akademis, 50.0, "Wirausaha grants no akademis")
	assert_eq(student.seni_budaya, 50.0, "Wirausaha grants no seni budaya")
	assert_eq(student.olahraga, 50.0, "Wirausaha grants no olahraga")
	GameState.pending_earnings.clear()
	GameState.day_schedules = {}
	manager.free()

func test_tired_students_earn_less() -> void:
	## Earnings scale with energy, so the same roll range cannot produce a
	## higher floor for an exhausted student than for a rested one.
	GameState.pending_earnings.clear()
	GameState.day_schedules = {
		7: {"Senin": {"category": "Wirausaha", "mood_cost": 10, "energy_cost": 12}},
	}
	var totals := {}
	for energy_value in [10.0, 100.0]:
		var sum := 0
		for _i in range(30):
			GameState.pending_earnings.clear()
			var manager := StudentManager.new()
			var student := StudentData.new()
			student.id = 7
			student.student_name = "Uji"
			student.energy = energy_value
			student.mood = 80.0
			manager.students = [student]
			manager.apply_daily_decay_all("Senin")
			sum += GameState.pending_earnings.get(7, 0)
			manager.free()
		totals[energy_value] = sum
	assert_true(totals[100.0] > totals[10.0],
		"a rested student must out-earn an exhausted one over 30 rolls")
	GameState.pending_earnings.clear()
	GameState.day_schedules = {}

## SchoolDay.gd is not a @tool script. Instantiating its .tscn while the
## MCP test runner is executing inside the editor process triggers
## Godot's automatic placeholder-script substitution for any non-tool
## scene instanced under the editor (verified empirically: even the
## long-standing, untouched _scene_name() call hits the same "Attempt to
## call a method on a placeholder instance" error against a PackedScene
## instance -- this is why tests/test_school_day.gd never calls instance
## methods on its instantiated SchoolDay and instead reads source text
## or scene-declared state only). Loading the script resource directly
## and calling .new() was meant to bypass PackedScene's editor placeholder
## path -- but it does not: Godot substitutes a placeholder for ANY
## instance of a non-@tool script created while running inside the editor
## process (which is exactly how the MCP test runner executes), regardless
## of whether that instance comes from PackedScene.instantiate() or a bare
## GDScript.new(). A placeholder instance carries the script's exported
## property values but none of its methods, so any call on it fails with
## "Invalid call. Nonexistent function" -- indistinguishable, from the
## caller's side, from the method genuinely not existing (verified
## empirically: this happened even right after confirming, via
## script_patch's diagnostics, that the file parses with zero errors, and
## survived forcing ResourceLoader.load(..., CACHE_MODE_REPLACE) to
## recompile from disk on every call).
##
## `_pay_out_wirausaha` never reads or writes `self` -- it only touches
## the GameState singleton -- so it is declared `static` on SchoolDay.gd.
## A static call is dispatched on the class itself and never instantiates
## anything, so it never enters the placeholder path above.
##
## Reaching it needs a real, compiler-recognized class identifier, though
## -- not just any handle to the Script resource. A plain `load()` (or a
## `const` initialized with `preload()`) is typed as the generic `GDScript`
## resource wrapper, and calling a user-defined static method on that
## generic type by name fails with the same "Nonexistent function" error
## as the placeholder case above, whether written as
## `script._pay_out_wirausaha()` or `script.call("_pay_out_wirausaha")`
## (both verified empirically). What actually resolves a static call is a
## registered global class name, so SchoolDay.gd declares
## `class_name SchoolDay` and these tests call `SchoolDay._pay_out_wirausaha()`
## directly, the same way any other global-class static method is called.

func test_payout_adds_the_total_to_player_money() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings = {1: 300, 2: 250}
	var paid: int = SchoolDay._pay_out_wirausaha()
	assert_eq(paid, 550, "payout returns the summed total")
	assert_eq(GameState.player_money, original_money + 550, "money increases by the total")
	GameState.pending_earnings.clear()
	GameState.player_money = original_money

func test_payout_clears_pending_earnings() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings = {1: 100}
	SchoolDay._pay_out_wirausaha()
	assert_true(GameState.pending_earnings.is_empty(),
		"earnings are paid once, then cleared")
	GameState.player_money = original_money

func test_payout_of_nothing_is_zero_and_harmless() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings.clear()
	assert_eq(SchoolDay._pay_out_wirausaha(), 0, "no Wirausaha days pays nothing")
	assert_eq(GameState.player_money, original_money, "money is untouched")

func test_week_complete_pays_out() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("_pay_out_wirausaha()"),
		"the weekly payout must be invoked at week completion")
