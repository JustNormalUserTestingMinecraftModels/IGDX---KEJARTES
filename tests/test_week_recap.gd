@tool
extends McpTestSuite

## WeekRecap's week-total arithmetic (2026-09-03 spec section 4).
##
## WeekRecap is a plain RefCounted, so every case here runs without
## instantiating a scene -- this is the cheap half of the pass's
## coverage. Suite is @tool and no test is a coroutine, per the runner's
## constraints.

const _RECAP_SCRIPT := "res://Scripts/SchoolSimulation/WeekRecap.gd"


func suite_name() -> String:
	return "week_recap"


## A StudentManager standing in for a simulated week. Built by hand
## rather than by running a real simulation: these tests are about the
## summing, not about what the simulation produces.
func _manager(history: Array, log: Dictionary) -> StudentManager:
	var m := StudentManager.new()
	m.minigame_history.assign(history)
	m.daily_stat_log = log
	return m


func _entry(day: String, category: String, won: bool) -> Dictionary:
	return {"day": day, "category": category, "game_name": "X", "won": won}


func _delta(name_: String, stat_key: String, delta: float) -> Dictionary:
	return {"student_name": name_, "stat_key": stat_key,
		"delta": delta, "source": "activity"}


func test_net_skill_delta_sums_all_three_skills() -> void:
	var m := _manager([], {
		"Senin": [_delta("Budi", "akademis", 10.0),
			_delta("Ani", "seni_budaya", 5.0)],
		"Selasa": [_delta("Budi", "olahraga", 22.0)],
	})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["net_skill_delta"], 37, "10 + 5 + 22 = 37")


func test_net_skill_delta_is_net_not_positive_only() -> void:
	var m := _manager([], {
		"Senin": [_delta("Budi", "akademis", 6.0),
			_delta("Ani", "olahraga", -10.0)],
	})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["net_skill_delta"], -4,
		"a losing week must be allowed to read negative")


func test_needs_deltas_never_leak_into_net_skill_delta() -> void:
	var m := _manager([], {
		"Senin": [_delta("Budi", "energy", -30.0),
			_delta("Budi", "mood", -25.0),
			_delta("Budi", "akademis", 8.0)],
	})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["net_skill_delta"], 8,
		"energy and mood are excluded; only akademis counts")


func test_minigame_tally_excludes_events() -> void:
	var m := _manager([
		_entry("Senin", "Olahraga", true),
		_entry("Selasa", "Akademis", false),
		_entry("Rabu", "Event", true),
		_entry("Kamis", "SeniBudaya", true),
	], {})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_won"], 2, "two non-event wins")
	assert_eq(r["minigames_total"], 3, "the Event entry is not a minigame")
	assert_eq(r["events_count"], 1, "one Event entry")


func test_empty_history_reports_zeroes() -> void:
	var r: Dictionary = WeekRecap.compute(_manager([], {}))
	assert_eq(r["minigames_total"], 0, "no minigames")
	assert_eq(r["events_count"], 0, "no events")
	assert_eq(r["net_skill_delta"], 0, "no movement")


func test_all_event_history_reports_no_minigames() -> void:
	var m := _manager([
		_entry("Senin", "Event", true),
		_entry("Selasa", "Event", true),
	], {})
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_total"], 0, "every entry was an Event")
	assert_eq(r["events_count"], 2, "both counted as events")


func test_null_manager_reports_zeroes_rather_than_erroring() -> void:
	var r: Dictionary = WeekRecap.compute(null)
	assert_eq(r["money_earned"], 0, "a null manager is survivable")
	assert_eq(r["minigames_total"], 0, "and reports an empty week")


func test_format_money_groups_thousands_with_a_dot() -> void:
	assert_eq(WeekRecap.format_money(4200), "4.200",
		"Indonesian thousands separator")
	assert_eq(WeekRecap.format_money(0), "0", "zero needs no separator")
	assert_eq(WeekRecap.format_money(1234567), "1.234.567",
		"grouping repeats every three digits")


func test_format_skill_delta_signs_and_neutral_word() -> void:
	assert_eq(WeekRecap.format_skill_delta(37), "+37", "gains carry a +")
	assert_eq(WeekRecap.format_skill_delta(-4), "-4",
		"the minus comes free from %d")
	assert_eq(WeekRecap.format_skill_delta(0), "Netral",
		"exact zero reads as a word, not a bare 0")
