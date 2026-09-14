@tool
extends McpTestSuite

## WeekRecap's week tallies (2026-09-14 weekly-results spec; first written
## for the 2026-09-03 banner).
##
## WeekRecap is a plain RefCounted, so every case here runs without
## instantiating a scene. Suite is @tool and no test is a coroutine, per the
## runner's constraints.

const _RECAP_SCRIPT := "res://Scripts/SchoolSimulation/WeekRecap.gd"


func suite_name() -> String:
	return "week_recap"


## A StudentManager standing in for a simulated week, built by hand: these
## tests are about the counting, not about what the simulation produces.
func _manager(history: Array) -> StudentManager:
	var m := StudentManager.new()
	m.minigame_history.assign(history)
	return m


func _entry(day: String, category: String, won: bool) -> Dictionary:
	return {"day": day, "category": category, "game_name": "X", "won": won}


func test_minigame_tally_excludes_events() -> void:
	var m := _manager([
		_entry("Senin", "Olahraga", true),
		_entry("Selasa", "Akademis", false),
		_entry("Rabu", "Event", true),
		_entry("Kamis", "SeniBudaya", true),
	])
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_won"], 2, "two non-event wins")
	assert_eq(r["minigames_total"], 3, "the Event entry is not a minigame")
	assert_eq(r["events_count"], 1, "one Event entry")


func test_minigames_lost_counts_played_losses_only() -> void:
	var m := _manager([
		_entry("Senin", "Olahraga", true),
		_entry("Selasa", "Akademis", false),
		_entry("Rabu", "Event", true),
		_entry("Kamis", "SeniBudaya", false),
	])
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_won"], 1, "one played win")
	assert_eq(r["minigames_lost"], 2, "two played losses")
	assert_eq(r["minigames_won"] + r["minigames_lost"], r["minigames_total"],
		"won + lost = played")


## Random events are recorded won and cannot fail -- even an entry that
## says otherwise is never counted as a lost minigame.
func test_an_event_is_never_a_loss() -> void:
	var m := _manager([_entry("Rabu", "Event", false)])
	assert_eq(WeekRecap.compute(m)["minigames_lost"], 0,
		"an Event entry is not a minigame")


func test_empty_history_reports_zeroes() -> void:
	var r: Dictionary = WeekRecap.compute(_manager([]))
	assert_eq(r["minigames_total"], 0, "no minigames")
	assert_eq(r["minigames_lost"], 0, "no losses")
	assert_eq(r["events_count"], 0, "no events")


func test_all_event_history_reports_no_minigames() -> void:
	var m := _manager([
		_entry("Senin", "Event", true),
		_entry("Selasa", "Event", true),
	])
	var r: Dictionary = WeekRecap.compute(m)
	assert_eq(r["minigames_total"], 0, "every entry was an Event")
	assert_eq(r["events_count"], 2, "both counted as events")


func test_null_manager_reports_zeroes_rather_than_erroring() -> void:
	var r: Dictionary = WeekRecap.compute(null)
	assert_eq(r["minigames_won"], 0, "a null manager is survivable")
	assert_eq(r["minigames_lost"], 0, "and reports an empty week")


func test_format_money_groups_thousands_with_a_dot() -> void:
	assert_eq(WeekRecap.format_money(4200), "4.200",
		"Indonesian thousands separator")
	assert_eq(WeekRecap.format_money(0), "0", "zero needs no separator")
	assert_eq(WeekRecap.format_money(1234567), "1.234.567",
		"grouping repeats every three digits")


## The coins arrive through ResultCheckup.initialize_checkup(); WeekRecap
## must not go back to reading the dict SchoolDay empties first.
func test_week_recap_does_not_read_pending_earnings() -> void:
	assert_false(FileAccess.get_file_as_string(_RECAP_SCRIPT).contains("pending_earnings"),
		"the payout empties pending_earnings before Weekly Results opens")
