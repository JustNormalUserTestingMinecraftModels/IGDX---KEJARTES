@tool
extends McpTestSuite

## GameState.reset_roster_for_new_grade() is the one path that rebases roster
## skill stats when a grade changes -- real progression and debug jumps both
## call it. These tests pin the head-start formula, the mood/energy snap, the
## target-cache wipe, and the empty-roster no-op.

func suite_name() -> String:
	return "roster_reset"

func _make_student(id: int, ak1: float, base1: float) -> Dictionary:
	return {
		"id": id, "name": "T%d" % id,
		"akademis1": ak1, "akademis2": 60.0, "akademis3": 70.0,
		"roster_base_akademis1": base1, "roster_base_akademis2": 40.0, "roster_base_akademis3": 55.0,
		"kepribadian1": 22.0, "kepribadian2": 15.0,
		"base_akademis1": 30.0, "base_akademis2": 40.0, "base_akademis3": 55.0,
	}

func test_head_start_keeps_twenty_percent_of_gains() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	var s: Dictionary = GameState.approved_students[0]
	# 30 + 0.20 * (50 - 30) = 34.0
	assert_true(is_equal_approx(float(s["akademis1"]), 34.0),
		"akademis1 should rebase to roster_base + 20% of gains, got %s" % str(s["akademis1"]))
	GameState.approved_students = saved

func test_skill_below_roster_base_floors_at_roster_base() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = [_make_student(1, 25.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	assert_true(is_equal_approx(float(GameState.approved_students[0]["akademis1"]), 30.0),
		"a skill ending below roster_base must snap up to roster_base exactly")
	GameState.approved_students = saved

func test_mood_energy_snap_and_target_cache_wiped() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	var s: Dictionary = GameState.approved_students[0]
	assert_true(is_equal_approx(float(s["kepribadian1"]), 80.0), "mood snaps to 80")
	assert_true(is_equal_approx(float(s["kepribadian2"]), 80.0), "energy snaps to 80")
	assert_false(s.has("base_akademis1"), "base_akademis1 must be erased")
	assert_false(s.has("base_akademis2"), "base_akademis2 must be erased")
	assert_false(s.has("base_akademis3"), "base_akademis3 must be erased")
	assert_true(s.has("roster_base_akademis1"), "roster_base_akademis1 must be preserved")
	GameState.approved_students = saved

func test_missing_roster_base_is_captured_from_current() -> void:
	var saved := GameState.approved_students
	var s := _make_student(1, 50.0, 30.0)
	s.erase("roster_base_akademis2")  # simulate the debug-seed roster path
	GameState.approved_students = [s]
	GameState.reset_roster_for_new_grade()
	var out: Dictionary = GameState.approved_students[0]
	assert_true(out.has("roster_base_akademis2"),
		"a missing roster_base_akademis2 must be captured from the pre-reset value")
	assert_true(is_equal_approx(float(out["roster_base_akademis2"]), 60.0),
		"captured roster_base_akademis2 should equal the pre-reset akademis2 (60)")
	# end==base -> stays at base
	assert_true(is_equal_approx(float(out["akademis2"]), 60.0),
		"with roster_base just captured from current, akademis2 is unchanged")
	GameState.approved_students = saved

func test_empty_roster_is_a_noop() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = []
	GameState.reset_roster_for_new_grade()  # must not error
	assert_eq(GameState.approved_students.size(), 0)
	GameState.approved_students = saved

func test_gain_tracker_cleared() -> void:
	var saved := GameState.approved_students
	GameState.minigame_gain_this_week = {5: 9.0}
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	assert_eq(GameState.minigame_gain_this_week.size(), 0,
		"reset must clear the weekly minigame-gain tracker")
	GameState.approved_students = saved
