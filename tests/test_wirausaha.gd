@tool
extends McpTestSuite

## Wirausaha: the fifth schedule activity. Students assigned to it earn
## money at a mood/energy cost, paid out at the end of the week.
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "wirausaha"

const _JADWAL_SCENE := "res://Scenes/AturJadwal/atur_jadwal.tscn"
const _SCHOOL_DAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"

## Builds a throwaway approved_students roster and returns the caller's
## original one so each test can restore it.
func _swap_roster(roster: Array) -> Array:
	var original: Array = GameState.approved_students
	GameState.approved_students = roster
	return original

## The scheduling popup's five picks are ActivityRows now (see ActivityRow.gd)
## rather than a node literally named "Wirausaha" -- find it by category.
func test_schedule_popup_offers_wirausaha() -> void:
	var scene := (load(_JADWAL_SCENE) as PackedScene).instantiate()
	var rows := scene.get_node_or_null("Penjadwalan/TextureRect/Rows")
	var found := false
	if rows:
		for row in rows.get_children():
			if row is ActivityRow and row.category == "Wirausaha":
				found = true
	assert_true(found, "the scheduling popup must offer an ActivityRow for Wirausaha")
	scene.free()

## _connect_activity_buttons() binds every row dynamically via row.category
## now, rather than one hardcoded bind("Wirausaha") call -- so Wirausaha's
## wiring is covered by the same generic loop as every other category.
func test_jadwal_script_binds_wirausaha() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
	assert_true(src.contains("_on_activity_selected.bind(row.category)"),
		"every ActivityRow, Wirausaha included, must connect via row.category")

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
## `_pay_out_wirausaha` is a plain instance method on SchoolDay.gd. Loading
## the script directly with `load()` and calling `.new()` constructs a real
## instance whose custom methods -- including this one -- are callable
## normally; only instancing the .tscn (PackedScene.instantiate()) inside
## the editor process hits Godot's placeholder-script substitution, which is
## why tests/test_school_day.gd avoids calling instance methods on its
## instantiated scene and instead reads source text or scene-declared state.

func test_payout_adds_the_total_to_player_money() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings = {1: 300, 2: 250}
	var paid: int = load(_SCHOOL_DAY_SCRIPT).new()._pay_out_wirausaha()
	assert_eq(paid, 550, "payout returns the summed total")
	assert_eq(GameState.player_money, original_money + 550, "money increases by the total")
	GameState.pending_earnings.clear()
	GameState.player_money = original_money

func test_payout_clears_pending_earnings() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings = {1: 100}
	load(_SCHOOL_DAY_SCRIPT).new()._pay_out_wirausaha()
	assert_true(GameState.pending_earnings.is_empty(),
		"earnings are paid once, then cleared")
	GameState.player_money = original_money

func test_payout_of_nothing_is_zero_and_harmless() -> void:
	var original_money := GameState.player_money
	GameState.pending_earnings.clear()
	assert_eq(load(_SCHOOL_DAY_SCRIPT).new()._pay_out_wirausaha(), 0, "no Wirausaha days pays nothing")
	assert_eq(GameState.player_money, original_money, "money is untouched")

func test_week_complete_pays_out() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("_pay_out_wirausaha()"),
		"the weekly payout must be invoked at week completion")
