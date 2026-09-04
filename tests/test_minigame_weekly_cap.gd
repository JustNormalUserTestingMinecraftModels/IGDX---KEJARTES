@tool
extends McpTestSuite

## The per-student weekly minigame-points cap: a student can gain at most
## Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_* skill from minigame
## WINS per week. Losses are never capped.

func suite_name() -> String:
	return "minigame_weekly_cap"

func _fresh_manager() -> StudentManager:
	var sm := StudentManager.new()
	sm.students.clear()
	var s := StudentData.new()
	s.id = 1
	s.student_name = "Cap"
	s.akademis = 10.0
	s.specialty_category = "Seimbang"  # 0.85 cost mult, no specialty stat bonus
	sm.students.append(s)
	return sm

func _win(sm: StudentManager) -> void:
	# score 3 / max 4 -> ratio 0.75 -> grade-7 stat = round(5 + 0.75*10) = 13
	sm.record_minigame_result("Sen", "Akademis", "Q", true, 3, 4)

func test_wins_stop_at_the_grade7_cap() -> void:
	var saved_grade := GameState.current_grade
	var saved_gain := GameState.minigame_gain_this_week
	GameState.current_grade = 7
	GameState.minigame_gain_this_week = {}
	var sm := _fresh_manager()

	_win(sm)
	var after1: float = sm.students[0].akademis
	assert_true(after1 <= 10.0 + 14.0 + 0.01, "one win cannot exceed the 14 cap")
	assert_true(after1 >= 10.0 + 12.0, "one ~13-point win should mostly land")

	_win(sm)
	var after2: float = sm.students[0].akademis
	assert_true(is_equal_approx(after2, 24.0),
		"cumulative minigame gain is capped at 14 over base 10, got %s" % str(after2))

	_win(sm)
	assert_true(is_equal_approx(sm.students[0].akademis, 24.0),
		"a third win adds nothing once the weekly cap is reached")

	GameState.current_grade = saved_grade
	GameState.minigame_gain_this_week = saved_gain

func test_losses_are_not_capped() -> void:
	var saved_grade := GameState.current_grade
	var saved_gain := GameState.minigame_gain_this_week
	GameState.current_grade = 7
	GameState.minigame_gain_this_week = {}
	var sm := _fresh_manager()
	sm.students[0].akademis = 24.0
	GameState.minigame_gain_this_week[1] = 14.0  # cap already reached this week

	sm.record_minigame_result("Sen", "Akademis", "Q", false, 0, 4)
	# grade-7 loss = MINIGAME_KALAH_POIN_KELAS_7 = -3, x Seimbang 0.85 mult is
	# applied to costs only, not the stat penalty -> akademis 24 - 3 = 21
	assert_true(is_equal_approx(sm.students[0].akademis, 21.0),
		"a loss still subtracts in full after the win cap is hit, got %s" % str(sm.students[0].akademis))

	GameState.current_grade = saved_grade
	GameState.minigame_gain_this_week = saved_gain

func test_cap_value_is_per_grade() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/StudentManager.gd")
	assert_true(src.contains("MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8"),
		"grade 8 must select its own cap")
	assert_true(src.contains("MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9"),
		"grade 9 must select its own cap")

func test_week_start_clears_the_tracker() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("minigame_gain_this_week"),
		"start_simulation must clear GameState.minigame_gain_this_week each week")
