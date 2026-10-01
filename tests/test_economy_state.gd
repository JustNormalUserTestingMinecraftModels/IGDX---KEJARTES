@tool
extends McpTestSuite

## Economy state: ItemData, ItemDatabase, GameState money/inventory/use_item.
## Suite must be @tool and no test may be a coroutine (the runner calls
## suite.call(name) without awaiting) -- same constraints as test_lobby.gd.
##
## GameState results are declared (`var x: int = GameState...`), never inferred
## with `:=`; test_use_item_on_students.gd explains why.

func suite_name() -> String:
	return "economy_state"

const _EXPECTED_ITEMS := [
	"Bank Soal", "Komik", "LKS", "Lompat Tali", "Raket",
	"Cilok", "Mie Instan", "Pop Ice", "Susu Kotak"
]

func test_item_database_registers_every_item() -> void:
	for item_name in _EXPECTED_ITEMS:
		assert_true(ItemDatabase.get_item(item_name) != null,
			"ItemDatabase must know: " + item_name)

func test_every_item_has_a_loaded_icon() -> void:
	for item_name in _EXPECTED_ITEMS:
		var item: ItemData = ItemDatabase.get_item(item_name)
		assert_true(item.icon != null, "icon must load for: " + item_name)

func test_every_item_has_a_positive_price() -> void:
	for item_name in _EXPECTED_ITEMS:
		var item: ItemData = ItemDatabase.get_item(item_name)
		assert_true(item.price > 0, "price must be positive for: " + item_name)

func test_unknown_item_returns_null() -> void:
	assert_true(ItemDatabase.get_item("TidakAda") == null,
		"unknown item must return null, not a blank ItemData")

func test_money_setter_emits_money_changed() -> void:
	var original: int = GameState.player_money
	var seen := []
	var cb := func(amount: int): seen.append(amount)
	GameState.money_changed.connect(cb)
	GameState.player_money = 1234
	GameState.money_changed.disconnect(cb)
	GameState.player_money = original
	assert_eq(seen.size(), 1, "setting player_money must emit exactly once")
	assert_eq(seen[0], 1234, "money_changed must carry the new amount")

func test_add_to_inventory_accumulates() -> void:
	GameState.inventory.clear()
	GameState.add_to_inventory("Komik", 2)
	GameState.add_to_inventory("Komik", 3)
	assert_eq(GameState.get_inventory_quantity("Komik"), 5, "quantities accumulate")
	GameState.inventory.clear()

func test_remove_from_inventory_erases_at_zero() -> void:
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie", 2)
	assert_true(GameState.remove_from_inventory("Mie", 2), "removal succeeds")
	assert_false(GameState.inventory.has("Mie"), "entry is erased, not left at 0")
	GameState.inventory.clear()

func test_remove_from_missing_item_returns_false() -> void:
	GameState.inventory.clear()
	assert_false(GameState.remove_from_inventory("Raket", 1),
		"removing an unowned item must report failure")

func test_get_quantity_of_unowned_item_is_zero() -> void:
	GameState.inventory.clear()
	assert_eq(GameState.get_inventory_quantity("Raket"), 0, "unowned reads as 0")
	# Task 2 tests complete

func test_cart_total_multiplies_price_by_quantity() -> void:
	Cart.clear()
	var komik: ItemData = ItemDatabase.get_item("Komik")
	Cart.add_item(komik)
	Cart.add_item(komik)
	assert_eq(Cart.get_total(), komik.price * 2, "total is price x quantity")
	assert_eq(Cart.get_item_count(), 2, "item count sums quantities")
	Cart.clear()

func test_cart_remove_one_erases_at_zero() -> void:
	Cart.clear()
	Cart.add_item(ItemDatabase.get_item("Mie Instan"))
	Cart.remove_one("Mie Instan")
	assert_true(Cart.is_empty(), "cart is empty after removing the last unit")
	Cart.clear()

func test_cart_clear_empties_everything() -> void:
	Cart.clear()
	Cart.add_item(ItemDatabase.get_item("Raket"))
	Cart.add_item(ItemDatabase.get_item("LKS"))
	Cart.clear()
	assert_eq(Cart.get_total(), 0, "total is 0 after clear")
	assert_true(Cart.is_empty(), "cart reports empty after clear")

## Builds a throwaway approved_students roster and returns the caller's
## original one so each test can restore it.
func _swap_roster(roster: Array) -> Array:
	var original: Array = GameState.approved_students
	GameState.approved_students = roster
	return original

func test_use_item_boosts_only_the_chosen_student() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 50.0, "energy": 50.0},
		{"id": 2, "student_name": "B", "mood": 50.0, "energy": 50.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Komik", 1)
	var komik: ItemData = ItemDatabase.get_item("Komik")
	var result: Dictionary = GameState.use_item(komik, 1, 1)
	assert_true(result["applied"], "use must succeed when the item is owned")
	assert_eq(GameState.approved_students[0]["mood"], 50.0 + komik.mood_boost, "chosen student gains mood")
	assert_eq(GameState.approved_students[1]["mood"], 50.0, "other student is untouched")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_clamps_at_one_hundred() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 98.0, "energy": 98.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Komik", 1)
	GameState.use_item(ItemDatabase.get_item("Komik"), 1, 1)
	assert_eq(GameState.approved_students[0]["mood"], 100.0, "mood clamps at 100")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_consumes_the_inventory_quantity() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie Instan", 3)
	GameState.use_item(ItemDatabase.get_item("Mie Instan"), 1, 2)
	assert_eq(GameState.get_inventory_quantity("Mie Instan"), 1, "2 of 3 consumed")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_refuses_when_not_enough_owned() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie Instan", 1)
	var result: Dictionary = GameState.use_item(ItemDatabase.get_item("Mie Instan"), 1, 5)
	assert_false(result["applied"], "cannot use more than owned")
	assert_eq(GameState.approved_students[0]["mood"], 10.0, "no stat change on refusal")
	assert_eq(GameState.get_inventory_quantity("Mie Instan"), 1, "nothing consumed on refusal")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_use_item_refuses_for_unknown_student_id() -> void:
	var original := _swap_roster([
		{"id": 1, "student_name": "A", "mood": 10.0, "energy": 10.0},
	])
	GameState.inventory.clear()
	GameState.add_to_inventory("Mie Instan", 1)
	var result: Dictionary = GameState.use_item(ItemDatabase.get_item("Mie Instan"), 99, 1)
	assert_false(result["applied"], "unknown student id must refuse")
	assert_eq(GameState.get_inventory_quantity("Mie Instan"), 1, "nothing consumed on refusal")
	GameState.inventory.clear()
	GameState.approved_students = original

func test_seed_playtest_inventory_stocks_every_item() -> void:
	GameState.inventory.clear()
	GameState.seed_playtest_inventory(2)
	for item_name in _EXPECTED_ITEMS:
		assert_eq(GameState.get_inventory_quantity(item_name), 2,
			"seed must stock: " + item_name)
	GameState.inventory.clear()

func test_seed_playtest_inventory_replaces_rather_than_stacks() -> void:
	GameState.inventory.clear()
	GameState.seed_playtest_inventory(2)
	GameState.seed_playtest_inventory(3)
	assert_eq(GameState.get_inventory_quantity("Komik"), 3,
		"a second seed replaces the quantity instead of adding to it")
	assert_eq(GameState.inventory.size(), _EXPECTED_ITEMS.size(),
		"seeding twice must not duplicate entries")
	GameState.inventory.clear()

func test_seed_playtest_inventory_emits_changed_once() -> void:
	GameState.inventory.clear()
	var seen := []
	var cb := func(): seen.append(1)
	GameState.inventory_changed.connect(cb)
	GameState.seed_playtest_inventory(1)
	GameState.inventory_changed.disconnect(cb)
	assert_eq(seen.size(), 1,
		"one seed must emit inventory_changed exactly once, not once per item")
	GameState.inventory.clear()


func test_gamestate_exposes_a_run_stats_record() -> void:
	assert_true(GameState.run_stats != null, "run_stats is never null")
	assert_true(GameState.run_stats is RunStats, "run_stats is a RunStats")


func test_using_an_item_records_it_in_run_stats() -> void:
	var before: int = GameState.run_stats.items_used
	var saved_roster: Array = GameState.approved_students.duplicate(true)
	var saved_inventory: Dictionary = GameState.inventory.duplicate(true)

	GameState.approved_students = [{
		"id": 4242, "name": "Uji", "mood": 10.0, "energy": 10.0,
	}]
	var item := ItemData.new()
	item.item_name = "UjiCoba"
	item.mood_boost = 5.0
	item.energy_boost = 5.0
	GameState.add_to_inventory("UjiCoba", 1)

	var result: Dictionary = GameState.use_item(item, 4242, 1)

	GameState.approved_students = saved_roster
	GameState.inventory = saved_inventory

	assert_true(result.get("applied", false), "the item applied")
	assert_eq(GameState.run_stats.items_used, before + 1,
		"a successful use bumps items_used")


func test_a_refused_item_use_does_not_record() -> void:
	var before: int = GameState.run_stats.items_used
	var item := ItemData.new()
	item.item_name = "TidakAda"
	var result: Dictionary = GameState.use_item(item, -1, 1)
	assert_false(result.get("applied", true), "refused")
	assert_eq(GameState.run_stats.items_used, before,
		"a refused use records nothing")


func test_set_grade_resets_the_run_stats() -> void:
	var saved_grade: int = GameState.current_grade
	GameState.run_stats.record_minigame(true, 10.0)
	GameState.set_grade(saved_grade)
	assert_eq(GameState.run_stats.minigames_won, 0,
		"starting a grade clears the tally")
	assert_false(GameState.run_failed, "the fail flag clears with the grade")


func test_count_targets_cleared_reports_cleared_and_total() -> void:
	var saved_roster: Array = GameState.approved_students.duplicate(true)
	GameState.approved_students = [{
		"id": 1, "name": "A",
		"akademis": 90.0, "seni_budaya": 90.0, "olahraga": 10.0,
		"target_akademis": 50.0, "target_seni_budaya": 50.0,
		"target_olahraga": 50.0,
	}]
	var counted: Array = GameState.count_targets_cleared()
	GameState.approved_students = saved_roster
	assert_eq(counted[0], 2, "two of three targets cleared")
	assert_eq(counted[1], 3, "three targets total for one student")


# ────────────────────────────────────────────────────────── run stars (Plan A)

## Four students, twelve stats. `cleared` of them meet their target.
func _roster_with_cleared(cleared: int) -> Array:
	var roster: Array = []
	var k := 0
	for i in range(4):
		var s := {"id": i + 1, "name": "M%d" % (i + 1)}
		for pair in [["akademis", "target_akademis"],
				["seni_budaya", "target_seni_budaya"],
				["olahraga", "target_olahraga"]]:
			s[pair[1]] = 60.0
			s[pair[0]] = 70.0 if k < cleared else 40.0
			k += 1
		roster.append(s)
	return roster


## A roster where student i clears exactly counts[i] of their three skill
## targets -- unlike _roster_with_cleared(), which fills students in order
## and so cannot say which student is short.
func _roster_with_counts(counts: Array) -> Array:
	var roster: Array = []
	for i in range(counts.size()):
		var s := {"id": i + 1, "name": "M%d" % (i + 1)}
		var k := 0
		for pair in GameState.SKILL_TARGET_PAIRS:
			s[pair[1]] = 60.0
			s[pair[0]] = 70.0 if k < int(counts[i]) else 40.0
			k += 1
		roster.append(s)
	return roster


func test_run_stars_is_three_times_the_cleared_fraction() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_cleared(8)
	assert_true(is_equal_approx(GameState.run_stars(), 2.0),
		"8 of 12 stats cleared is 2.0 stars")
	GameState.approved_students = _roster_with_cleared(7)
	assert_true(is_equal_approx(GameState.run_stars(), 1.75),
		"7 of 12 is 1.75 -- the meter is continuous, not rounded")
	GameState.approved_students = _roster_with_cleared(12)
	assert_true(is_equal_approx(GameState.run_stars(), 3.0), "all cleared is 3.0")
	GameState.approved_students = _roster_with_cleared(0)
	assert_true(is_equal_approx(GameState.run_stars(), 0.0), "none cleared is 0.0")
	GameState.approved_students = original


## An uninitialized target used to count as CLEARED here (the old
## `value >= target` read a missing key's 0.0 default as met), which meant
## a malformed roster passed the run with an empty star meter on screen.
## Failing it instead keeps the meter and the verdict consistent.
func test_a_target_that_was_never_initialized_does_not_count_as_cleared() -> void:
	var saved: Array = GameState.approved_students
	GameState.approved_students = [
		{"id": 1, "akademis": 80.0, "seni_budaya": 80.0, "olahraga": 80.0},
	]
	var counted: Array = GameState.count_targets_cleared()
	GameState.approved_students = saved
	assert_eq(int(counted[0]), 0, "no target set means nothing was cleared")
	assert_eq(int(counted[1]), 3, "all three still count toward the total")


func test_target_cleared_is_the_one_predicate() -> void:
	assert_true(GameState.target_cleared(60.0, 60.0), "exactly met clears")
	assert_true(GameState.target_cleared(90.0, 60.0), "past it clears")
	assert_false(GameState.target_cleared(59.0, 60.0), "short does not")
	assert_false(GameState.target_cleared(80.0, 0.0), "a zero target does not")
	assert_false(GameState.target_cleared(80.0, -5.0), "nor a negative one")


func test_run_stars_is_zero_for_an_empty_roster() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = []
	assert_true(is_equal_approx(GameState.run_stars(), 0.0),
		"no stats means no stars, and no divide by zero")
	GameState.approved_students = original


func test_targets_cleared_for_counts_one_students_three_skills() -> void:
	var roster := _roster_with_counts([3, 2, 1, 0])
	assert_eq(GameState.targets_cleared_for(roster[0]), 3)
	assert_eq(GameState.targets_cleared_for(roster[1]), 2)
	assert_eq(GameState.targets_cleared_for(roster[2]), 1)
	assert_eq(GameState.targets_cleared_for(roster[3]), 0)
	assert_eq(GameState.targets_cleared_for({}), 0,
		"a student with no targets clears nothing, by target_cleared()'s zero rule")


func test_the_per_student_pass_line_is_two() -> void:
	assert_eq(GameState.MIN_TARGETS_PER_STUDENT, 2, "two of three, per student")
	var roster := _roster_with_counts([3, 2, 1])
	assert_true(GameState.student_is_safe(roster[0]), "3 of 3 is safe")
	assert_true(GameState.student_is_safe(roster[1]), "2 of 3 is safe")
	assert_false(GameState.student_is_safe(roster[2]), "1 of 3 is not")


func test_safe_student_count_counts_students_on_the_line() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_counts([3, 2, 1, 0])
	assert_eq(GameState.safe_student_count(), 2)
	GameState.approved_students = original


## The 2026-10-01 rule: one student under the line loses the run, however
## many stars the rest of the roster earned. 3+3+3+1 = 10 of 12 = 2.5 stars.
func test_one_student_under_two_targets_fails_the_run_at_two_and_a_half_stars() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_counts([3, 3, 3, 1])
	assert_true(GameState.run_stars() > 2.0, "the roster is past the old star line")
	assert_false(GameState.check_semester_passed(),
		"a single student on 1 of 3 still loses the run")
	GameState.approved_students = _roster_with_counts([3, 3, 3, 0])
	assert_false(GameState.check_semester_passed(), "nor does 0 of 3 pass")
	GameState.approved_students = original


func test_every_student_on_two_targets_passes() -> void:
	var original: Array = GameState.approved_students
	GameState.approved_students = _roster_with_counts([2, 2, 2, 2])
	assert_true(GameState.check_semester_passed(), "2 of 3 each is a pass")
	GameState.approved_students = _roster_with_counts([3, 3, 3, 3])
	assert_true(GameState.check_semester_passed(), "a clean sweep passes")
	GameState.approved_students = original


func test_the_verdict_no_longer_reads_the_star_threshold() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	assert_false(src.contains("STAR_WIN_THRESHOLD"),
		"the verdict is per-student now; stars are only a score")


func test_empty_roster_still_counts_as_passed() -> void:
	# Preserved from the old predicate: debug teleports with no roster must
	# not read as a loss.
	var original: Array = GameState.approved_students
	GameState.approved_students = []
	assert_true(GameState.check_semester_passed(), "empty roster passes, as before")
	GameState.approved_students = original


func test_star_tunables_live_in_balance() -> void:
	assert_true(is_equal_approx(Balance.STARS_TOTAL, 3.0), "three stars total")
