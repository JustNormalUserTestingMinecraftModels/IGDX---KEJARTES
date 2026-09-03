@tool
extends McpTestSuite

## Covers RunStats (the per-grade counter record) and RunGrade (the
## letter-grade scorer). Both are pure data/math with no nodes, so unlike
## most suites here these are real behavioural tests rather than
## source-text scans.

func suite_name() -> String:
	return "run_stats"


func test_new_run_stats_starts_at_zero() -> void:
	var s := RunStats.new()
	assert_eq(s.minigames_won, 0, "menang starts at 0")
	assert_eq(s.minigames_lost, 0, "kalah starts at 0")
	assert_eq(s.minigame_points, 0.0, "points start at 0")
	assert_eq(s.items_used, 0, "items start at 0")
	assert_eq(s.wirausaha_money, 0, "money starts at 0")
	assert_eq(s.event_student_count(), 0, "no event students yet")


func test_record_minigame_splits_wins_and_losses() -> void:
	var s := RunStats.new()
	s.record_minigame(true, 10.0)
	s.record_minigame(true, 8.0)
	s.record_minigame(false, -3.0)
	assert_eq(s.minigames_won, 2, "two wins counted")
	assert_eq(s.minigames_lost, 1, "one loss counted")
	assert_eq(s.minigame_points, 15.0, "points summed with sign")
	assert_eq(s.minigames_played(), 3, "played is the sum")


func test_minigame_win_rate_is_zero_when_nothing_played() -> void:
	var s := RunStats.new()
	assert_eq(s.minigame_win_rate(), 0.0, "no divide by zero")


func test_minigame_win_rate_is_wins_over_played() -> void:
	var s := RunStats.new()
	s.record_minigame(true, 1.0)
	s.record_minigame(false, 0.0)
	s.record_minigame(false, 0.0)
	s.record_minigame(false, 0.0)
	assert_eq(s.minigame_win_rate(), 0.25, "1 of 4")


func test_event_students_are_counted_once_each() -> void:
	var s := RunStats.new()
	s.record_event_student(3)
	s.record_event_student(3)
	s.record_event_student(7)
	assert_eq(s.event_student_count(), 2, "duplicates collapse")


func test_item_and_money_accumulate() -> void:
	var s := RunStats.new()
	s.record_item_use()
	s.record_item_use(2)
	s.record_wirausaha(1500)
	s.record_wirausaha(500)
	assert_eq(s.items_used, 3, "item uses summed")
	assert_eq(s.wirausaha_money, 2000, "money summed")


func test_reset_clears_everything() -> void:
	var s := RunStats.new()
	s.record_minigame(true, 10.0)
	s.record_item_use()
	s.record_wirausaha(100)
	s.record_event_student(1)
	s.reset()
	assert_eq(s.minigames_won, 0, "wins cleared")
	assert_eq(s.minigame_points, 0.0, "points cleared")
	assert_eq(s.items_used, 0, "items cleared")
	assert_eq(s.wirausaha_money, 0, "money cleared")
	assert_eq(s.event_student_count(), 0, "event students cleared")


func _perfect_stats() -> RunStats:
	var s := RunStats.new()
	for i in range(10):
		s.record_minigame(true, 10.0)
	s.record_wirausaha(RunGrade.MONEY_FULL_MARKS)
	for i in range(4):
		s.record_event_student(i)
	return s


func test_perfect_run_scores_one_hundred() -> void:
	var s := _perfect_stats()
	assert_eq(RunGrade.score(s, 12, 12, 4), 100.0, "everything maxed")


func test_empty_run_scores_zero() -> void:
	var s := RunStats.new()
	assert_eq(RunGrade.score(s, 0, 12, 4), 0.0, "nothing done")


func test_score_is_clamped_to_one_hundred() -> void:
	var s := _perfect_stats()
	s.record_wirausaha(RunGrade.MONEY_FULL_MARKS * 5)
	assert_eq(RunGrade.score(s, 12, 12, 4), 100.0, "overshoot clamps")


func test_score_handles_empty_roster_without_dividing_by_zero() -> void:
	var s := RunStats.new()
	assert_eq(RunGrade.score(s, 0, 0, 0), 0.0, "no divide by zero")


func test_targets_dominate_the_score() -> void:
	var s := RunStats.new()
	assert_eq(RunGrade.score(s, 12, 12, 4), 55.0, "targets alone are worth 55")


func test_letter_is_d_when_the_run_failed() -> void:
	assert_eq(RunGrade.letter(100.0, false), "D", "a loss is always D")


func test_letter_bands_on_a_win() -> void:
	assert_eq(RunGrade.letter(96.0, true), "A+", "95+ is A+")
	assert_eq(RunGrade.letter(88.0, true), "A", "88 is A")
	assert_eq(RunGrade.letter(80.0, true), "A-", "80 is A-")
	assert_eq(RunGrade.letter(72.0, true), "B+", "72 is B+")
	assert_eq(RunGrade.letter(64.0, true), "B", "64 is B")
	assert_eq(RunGrade.letter(56.0, true), "B-", "56 is B-")
	assert_eq(RunGrade.letter(48.0, true), "C+", "48 is C+")
	assert_eq(RunGrade.letter(40.0, true), "C", "40 is C")
	assert_eq(RunGrade.letter(0.0, true), "C-", "below 40 is C-")


func test_is_top_grade_only_for_the_a_band() -> void:
	assert_true(RunGrade.is_top_grade("A+"), "A+ is top")
	assert_true(RunGrade.is_top_grade("A"), "A is top")
	assert_true(RunGrade.is_top_grade("A-"), "A- is top")
	assert_false(RunGrade.is_top_grade("B+"), "B+ is not top")
	assert_false(RunGrade.is_top_grade("D"), "D is not top")
