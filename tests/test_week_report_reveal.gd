@tool
extends McpTestSuite

## The weekly report's reveal timeline (WeekReportReveal), checked as data:
## the order cards, rows, pops and summary lines play in, and the scroll
## that follows them. Pure -- nothing is instanced and nothing animates.
## @tool, and no test here may be a coroutine.

const _R := preload("res://Scripts/SchoolSimulation/WeekReportReveal.gd")


func suite_name() -> String:
	return "week_report_reveal"


## The steps of one kind, in timeline order.
func _of(steps: Array, kind: StringName) -> Array:
	var out: Array = []
	for s in steps:
		if s["kind"] == kind:
			out.append(s)
	return out


func _first(steps: Array, kind: StringName, card: int, row: int) -> Dictionary:
	for s in steps:
		if s["kind"] == kind and s["card"] == card and s["row"] == row:
			return s
	return {}


func test_steps_come_back_sorted_by_time() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 3.0], [0.0, 2.0, 0.0]], [100.0, 1.0, 0.0])
	for i in range(1, steps.size()):
		assert_true(float(steps[i]["at"]) >= float(steps[i - 1]["at"]),
			"step %d must not come before step %d" % [i, i - 1])


## Card 1 lands, its three rows play top to bottom, and only then card 2.
func test_cards_land_in_order_each_playing_its_rows_top_to_bottom() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 5.0], [5.0, 5.0, 5.0]], [0.0, 0.0, 0.0])
	var seen: Array = []
	for s in steps:
		if s["kind"] == _R.CARD:
			seen.append("c%d" % s["card"])
		elif s["kind"] == _R.ROW_COUNT:
			seen.append("c%dr%d" % [s["card"], s["row"]])
	assert_eq(seen, ["c0", "c0r0", "c0r1", "c0r2", "c1", "c1r0", "c1r1", "c1r2"],
		"one card at a time, its rows top to bottom")


func test_a_gain_pops_exactly_when_its_count_lands() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 0.0]], [0.0, 0.0, 0.0], {"count": 0.4})
	var count := _first(steps, _R.ROW_COUNT, 0, 0)
	var pop := _first(steps, _R.ROW_POP, 0, 0)
	assert_false(pop.is_empty(), "a gaining row pops")
	assert_true(absf(float(pop["at"]) - float(count["at"]) - 0.4) <= 0.0001,
		"the pop lands count seconds after the count starts")


func test_the_next_row_waits_for_the_pop() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 0.0]], [0.0, 0.0, 0.0])
	var pop0 := _first(steps, _R.ROW_POP, 0, 0)
	var count1 := _first(steps, _R.ROW_COUNT, 0, 1)
	assert_true(float(count1["at"]) > float(pop0["at"]),
		"row 2 starts only after row 1 has landed")


## The game's standing rule: no gain, no celebration.
func test_a_row_that_did_not_gain_never_pops() -> void:
	var steps: Array = _R.build([[0.0, -3.0, 7.0]], [0.0, 0.0, 0.0])
	var pops := _of(steps, _R.ROW_POP)
	assert_eq(pops.size(), 1, "only the gaining row pops")
	assert_eq(int(pops[0]["row"]), 2, "and it is the third row")


func test_count_steps_carry_their_own_length() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 0.0]], [100.0, 0.0, 0.0],
		{"count": 0.4, "quiet_row": 0.15})
	assert_eq(float(_first(steps, _R.ROW_COUNT, 0, 0)["seconds"]), 0.4, "a gain counts in full")
	assert_eq(float(_first(steps, _R.ROW_COUNT, 0, 1)["seconds"]), 0.15, "a flat row settles short")
	assert_eq(float(_first(steps, _R.LINE, -1, 0)["seconds"]), 0.4, "a non-zero line counts in full")
	assert_eq(float(_first(steps, _R.LINE, -1, 1)["seconds"]), 0.0, "a zero line has nothing to count")


func test_the_summary_follows_the_last_row_in_order() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 5.0]], [100.0, 2.0, 1.0])
	var lines := _of(steps, _R.LINE)
	assert_eq(lines.size(), 3, "three summary lines")
	assert_eq([int(lines[0]["row"]), int(lines[1]["row"]), int(lines[2]["row"])], [0, 1, 2],
		"coins, then won, then lost")
	var last_row := _first(steps, _R.ROW_POP, 0, 2)
	assert_true(float(lines[0]["at"]) > float(last_row["at"]),
		"the summary waits for the last row to land")


func test_a_zero_line_does_not_pop() -> void:
	var steps: Array = _R.build([], [1000.0, 0.0, 2.0])
	var pops := _of(steps, _R.LINE_POP)
	assert_eq(pops.size(), 2, "only the non-zero lines pop")
	assert_eq([int(pops[0]["row"]), int(pops[1]["row"])], [0, 2], "coins and lost")


## The pitch climbs through the whole report, stats and lines together.
func test_pop_index_climbs_by_one_across_stats_and_lines() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 5.0]], [100.0, 1.0, 0.0])
	var indices: Array = []
	for s in steps:
		if s["kind"] == _R.ROW_POP or s["kind"] == _R.LINE_POP:
			indices.append(int(s["pop_index"]))
		else:
			assert_eq(int(s["pop_index"]), -1, "a non-pop carries no pop index")
	assert_eq(indices, [0, 1, 2, 3], "one step per pop, in order")


func test_the_finale_comes_last() -> void:
	var steps: Array = _R.build([[5.0, 5.0, 5.0]], [100.0, 1.0, 1.0])
	var last: Dictionary = steps[steps.size() - 1]
	assert_eq(last["kind"], _R.FINALE, "the finale is the last beat")
	assert_eq(_of(steps, _R.FINALE).size(), 1, "and there is exactly one")


func test_an_empty_roster_goes_straight_to_the_summary() -> void:
	var steps: Array = _R.build([], [0.0, 0.0, 0.0], {"start": 0.5})
	assert_eq(steps[0]["kind"], _R.LINE, "no cards, so the first beat is a line")
	assert_eq(float(steps[0]["at"]), 0.5, "on the start offset")


func test_start_offsets_the_whole_timeline() -> void:
	var steps: Array = _R.build([[5.0, 0.0, 0.0]], [0.0, 0.0, 0.0], {"start": 1.0})
	assert_eq(float(steps[0]["at"]), 1.0, "the first card lands on the start offset")


func test_a_bigger_roster_takes_longer() -> void:
	var two: Array = _R.build([[5.0, 5.0, 5.0], [5.0, 5.0, 5.0]], [0.0, 0.0, 0.0])
	var four: Array = _R.build([[5.0, 5.0, 5.0], [5.0, 5.0, 5.0],
		[5.0, 5.0, 5.0], [5.0, 5.0, 5.0]], [0.0, 0.0, 0.0])
	assert_true(float(four[four.size() - 1]["at"]) > float(two[two.size() - 1]["at"]),
		"Kelas 9's four cards run longer than Kelas 7's two")


## The defaults the spec agreed: four gaining Kelas 9 students run about
## nine seconds, well under a quarter-minute.
func test_the_default_pacing_keeps_kelas_9_near_nine_seconds() -> void:
	var gain := [5.0, 5.0, 5.0]
	var steps: Array = _R.build([gain, gain, gain, gain], [1000.0, 3.0, 1.0])
	var total := float(steps[steps.size() - 1]["at"])
	assert_true(total > 7.0 and total < 11.0, "got %.2f s" % total)


# ---------------------------------------------------------------- scrolling

func test_a_card_already_in_view_does_not_scroll() -> void:
	assert_eq(_R.scroll_to_show(100.0, 500.0, 900.0, 0.0), 0.0, "fully shown: stay put")


func test_a_card_below_the_view_scrolls_just_enough() -> void:
	assert_eq(_R.scroll_to_show(932.0, 1342.0, 900.0, 0.0), 442.0,
		"bring its bottom to the view's bottom, no further")


func test_a_card_above_the_view_scrolls_up_to_its_top() -> void:
	assert_eq(_R.scroll_to_show(0.0, 410.0, 900.0, 300.0), 0.0, "scroll back to its top")


func test_a_card_taller_than_the_view_shows_its_top() -> void:
	assert_eq(_R.scroll_to_show(500.0, 1600.0, 900.0, 0.0), 500.0,
		"its top matters more than its bottom")
