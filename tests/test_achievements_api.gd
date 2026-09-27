@tool
extends McpTestSuite

## The Achievements.gd polish-plan API surface (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md): progress
## helpers, totals, state_changed, and the debug-only reset_all/relock/
## debug_unlock. Each test builds a fresh, out-of-tree Achievements instance,
## exactly like tests/test_achievements.gd, so no autoload state and no
## user:// file is touched.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")


func suite_name() -> String:
	return "achievements_api"


func _fresh() -> Node:
	var a: Node = ACHIEVEMENTS.new()
	track(a)
	return a


func test_progress_of_numeric_kind_partial() -> void:
	var a := _fresh()
	for i in 7:
		a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	# total_10 target is 10, 7 played -> 0.7
	assert_true(absf(a.progress_of("total_10") - 0.7) < 0.0001)


func test_progress_of_one_shot_kind_is_binary() -> void:
	var a := _fresh()
	assert_eq(a.progress_of("three_star_akademis"), 0.0)
	a.record_minigame("Akademis", "Menjodohkan", true, 3, -1.0)
	assert_eq(a.progress_of("three_star_akademis"), 1.0)


func test_progress_of_unlocked_and_unknown() -> void:
	var a := _fresh()
	a.record_grade_passed(7)
	assert_eq(a.progress_of("grade_7"), 1.0, "unlocked is always 1.0")
	assert_eq(a.progress_of("no_such_id"), 0.0)


func test_progress_fraction_of_numeric_and_one_shot() -> void:
	var a := _fresh()
	for i in 3:
		a.record_minigame("Akademis", "Menjodohkan", false, 0, -1.0)
	assert_eq(a.progress_fraction_of("total_10"), Vector2i(3, 10))
	assert_eq(a.progress_fraction_of("grade_9"), Vector2i(0, 1))
	a.record_grade_passed(9)
	assert_eq(a.progress_fraction_of("grade_9"), Vector2i(1, 1))


func test_first_unclaimed_id_is_catalog_order() -> void:
	var a := _fresh()
	assert_eq(a.first_unclaimed_id(), "")
	a.record_grade_passed(8)
	a.record_grade_passed(7)
	# grade_7 precedes grade_8 in AchievementCatalog.ENTRIES.
	assert_eq(a.first_unclaimed_id(), "grade_7")
	a.claim("grade_7")
	assert_eq(a.first_unclaimed_id(), "grade_8")


func test_total_unclaimed_count_counts_unlocked_unclaimed() -> void:
	var a := _fresh()
	assert_eq(a.total_unclaimed_count(), 0)
	a.record_grade_passed(7)
	a.record_grade_passed(8)
	assert_eq(a.total_unclaimed_count(), 2)
	a.claim("grade_7")
	assert_eq(a.total_unclaimed_count(), 1)


func test_total_counts() -> void:
	var a := _fresh()
	assert_eq(a.total_count(), AchievementCatalog.ENTRIES.size())
	a.record_grade_passed(7)
	a.claim("grade_7")
	assert_eq(a.total_claimed_count(), 1)


func test_state_changed_fires_once_on_debug_unlock() -> void:
	var a := _fresh()
	var count := [0]
	a.state_changed.connect(func(): count[0] += 1)
	a.debug_unlock("grade_7")
	assert_eq(count[0], 1)


func test_debug_unlock_emits_unlocked_signal_and_is_a_no_op_when_repeated() -> void:
	var a := _fresh()
	var got := []
	a.unlocked.connect(func(id): got.append(id))
	a.debug_unlock("grade_7")
	assert_eq(got, ["grade_7"])
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_UNLOCKED)
	a.debug_unlock("grade_7")
	assert_eq(got, ["grade_7"], "already unlocked -> no-op")
	a.debug_unlock("no_such_id")
	assert_eq(got, ["grade_7"], "unknown id -> no-op")


func test_state_changed_fires_once_on_claim() -> void:
	var a := _fresh()
	a.record_grade_passed(7)
	var count := [0]
	a.state_changed.connect(func(): count[0] += 1)
	a.claim("grade_7")
	assert_eq(count[0], 1)


func test_state_changed_fires_once_on_relock() -> void:
	var a := _fresh()
	a.record_grade_passed(7)
	var count := [0]
	a.state_changed.connect(func(): count[0] += 1)
	a.relock("grade_7")
	assert_eq(count[0], 1)
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_LOCKED)


func test_relock_drops_a_claimed_entry_back_to_locked() -> void:
	var a := _fresh()
	a.record_grade_passed(7)
	a.claim("grade_7")
	a.relock("grade_7")
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_LOCKED)


## Task 7: relock() on an id the catalog doesn't recognise must be a true
## no-op -- no save, no state_changed -- rather than silently erasing keys
## that were never there.
func test_relock_unknown_id_is_a_no_op() -> void:
	var a := _fresh()
	var count := [0]
	a.state_changed.connect(func(): count[0] += 1)
	a.relock("no_such_id")
	assert_eq(count[0], 0, "unknown id must not emit state_changed")


func test_state_changed_fires_once_on_reset_all() -> void:
	var a := _fresh()
	a.record_grade_passed(7)
	var count := [0]
	a.state_changed.connect(func(): count[0] += 1)
	a.reset_all()
	assert_eq(count[0], 1)
	assert_eq(a.state_of("grade_7"), ACHIEVEMENTS.STATE_LOCKED)
	assert_eq(a.minigames_played, 0)
