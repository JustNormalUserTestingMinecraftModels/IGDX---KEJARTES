@tool
extends McpTestSuite

## GameState.reset_roster_for_new_grade() is the one path that rebases roster
## skill stats when a grade changes -- real progression and debug jumps both
## call it. These tests pin the head-start formula, the mood/energy snap, the
## target-cache wipe, and the empty-roster no-op.
##
## GameState results are declared (`var x: int = GameState...`), never inferred
## with `:=`; test_use_item_on_students.gd explains why.

func suite_name() -> String:
	return "roster_reset"

func _make_student(id: int, akademis: float, roster_base_akademis: float) -> Dictionary:
	return {
		"id": id, "name": "T%d" % id,
		"akademis": akademis, "seni_budaya": 60.0, "olahraga": 70.0,
		"roster_base_akademis": roster_base_akademis, "roster_base_seni_budaya": 40.0, "roster_base_olahraga": 55.0,
		"mood": 22.0, "energy": 15.0,
		"base_akademis": 30.0, "base_seni_budaya": 40.0, "base_olahraga": 55.0,
	}

func test_head_start_keeps_twenty_percent_of_gains() -> void:
	var saved: Array = GameState.approved_students
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	var s: Dictionary = GameState.approved_students[0]
	# 30 + 0.20 * (50 - 30) = 34.0
	assert_true(is_equal_approx(float(s["akademis"]), 34.0),
		"akademis should rebase to roster_base + 20%% of gains, got %s" % str(s["akademis"]))
	GameState.approved_students = saved

func test_skill_below_roster_base_floors_at_roster_base() -> void:
	var saved: Array = GameState.approved_students
	GameState.approved_students = [_make_student(1, 25.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	assert_true(is_equal_approx(float(GameState.approved_students[0]["akademis"]), 30.0),
		"a skill ending below roster_base must snap up to roster_base exactly")
	GameState.approved_students = saved

func test_mood_energy_snap_and_target_cache_wiped() -> void:
	var saved: Array = GameState.approved_students
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	var s: Dictionary = GameState.approved_students[0]
	assert_true(is_equal_approx(float(s["mood"]), 80.0), "mood snaps to 80")
	assert_true(is_equal_approx(float(s["energy"]), 80.0), "energy snaps to 80")
	assert_false(s.has("base_akademis"), "base_akademis must be erased")
	assert_false(s.has("base_seni_budaya"), "base_seni_budaya must be erased")
	assert_false(s.has("base_olahraga"), "base_olahraga must be erased")
	assert_true(s.has("roster_base_akademis"), "roster_base_akademis must be preserved")
	GameState.approved_students = saved

func test_missing_roster_base_is_captured_from_current() -> void:
	var saved: Array = GameState.approved_students
	var s := _make_student(1, 50.0, 30.0)
	s.erase("roster_base_seni_budaya")  # simulate the debug-seed roster path
	GameState.approved_students = [s]
	GameState.reset_roster_for_new_grade()
	var out: Dictionary = GameState.approved_students[0]
	assert_true(out.has("roster_base_seni_budaya"),
		"a missing roster_base_seni_budaya must be captured from the pre-reset value")
	assert_true(is_equal_approx(float(out["roster_base_seni_budaya"]), 60.0),
		"captured roster_base_seni_budaya should equal the pre-reset seni_budaya (60)")
	# end==base -> stays at base
	assert_true(is_equal_approx(float(out["seni_budaya"]), 60.0),
		"with roster_base just captured from current, seni_budaya is unchanged")
	GameState.approved_students = saved

func test_empty_roster_is_a_noop() -> void:
	var saved: Array = GameState.approved_students
	GameState.approved_students = []
	GameState.reset_roster_for_new_grade()  # must not error
	assert_eq(GameState.approved_students.size(), 0)
	GameState.approved_students = saved

func test_gain_tracker_cleared() -> void:
	var saved: Array = GameState.approved_students
	GameState.minigame_gain_this_week = {5: 9.0}
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	assert_eq(GameState.minigame_gain_this_week.size(), 0,
		"reset must clear the weekly minigame-gain tracker")
	GameState.approved_students = saved

func test_student_card_captures_roster_base_on_approval() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/StudentCard.gd")
	assert_true(src.contains("roster_base_akademis"),
		"student_card must stamp roster_base_akademis when it approves the roster")
	assert_true(src.contains("roster_base_olahraga"),
		"student_card must stamp roster_base_olahraga when it approves the roster")

func test_set_grade_resets_roster_only_on_real_change() -> void:
	var saved: Array = GameState.approved_students
	var saved_grade: int = GameState.current_grade
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.current_grade = 7

	GameState.set_grade(8)
	assert_true(is_equal_approx(float(GameState.approved_students[0]["akademis"]), 34.0),
		"set_grade(8) from 7 must rebase the roster")

	GameState.approved_students[0]["akademis"] = 90.0
	GameState.set_grade(8)  # same grade -> no-op
	assert_true(is_equal_approx(float(GameState.approved_students[0]["akademis"]), 90.0),
		"set_grade to the SAME grade must not re-rebase (no stacked head-start)")

	GameState.approved_students = saved
	GameState.current_grade = saved_grade

func test_set_grade_debug_jump_wires_into_reset_roster() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	assert_true(src.contains("reset_roster_for_new_grade()"),
		"set_grade must call reset_roster_for_new_grade() when grade changes")

func test_student_card_only_stamps_roster_base_on_first_approval() -> void:
	# A re-approval mid-grade (player re-opens StudentCard, presses Belajar
	# again) must not move the roster_base_* keys off their first-set values,
	# or reset_roster_for_new_grade()'s head-start formula collapses toward
	# ~100% retention. Source-scan for the guard, matching this file's
	# established convention for asserting student_card's approval behavior.
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/StudentCard.gd")
	assert_true(src.contains('not _s.has("roster_base_akademis")'),
		"student_card must guard roster_base_akademis with a has() check so only the first approval sets it")
	assert_true(src.contains('not _s.has("roster_base_seni_budaya")'),
		"student_card must guard roster_base_seni_budaya with a has() check so only the first approval sets it")
	assert_true(src.contains('not _s.has("roster_base_olahraga")'),
		"student_card must guard roster_base_olahraga with a has() check so only the first approval sets it")
