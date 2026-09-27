@tool
extends McpTestSuite

## WeekReportRehearsal, the debug overlay's sample week for the weekly
## report, checked behaviourally on a throwaway StudentManager. Its demo
## roster (Budi/Ani/Cici/Doni) takes its own Monday snapshot, so deltas read
## straight off StudentData. @tool, and no test here may be a coroutine.


func suite_name() -> String:
	return "week_report_rehearsal"


func _manager() -> StudentManager:
	var m := StudentManager.new()
	track(m)
	return m


func test_the_sample_hands_back_its_coins() -> void:
	var coins: int = WeekReportRehearsal.apply_sample_week(_manager())
	assert_eq(coins, 1500, "the week's Wirausaha payout")


func test_the_first_student_gains_in_all_three_skills() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	var s: StudentData = m.students[0]
	assert_eq(s.get_akademis_delta(), 12.0, "akademis up")
	assert_eq(s.get_seni_delta(), 8.0, "seni up")
	assert_eq(s.get_olahraga_delta(), 5.0, "olahraga up")


## One press shows every beat of the reveal: a loss, a single gain, a flat card.
func test_the_ladder_shows_a_loss_a_single_gain_and_a_flat_card() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	assert_eq(m.students[1].get_seni_delta(), -3.0, "student 2 loses seni")
	assert_eq(m.students[1].get_akademis_delta(), 9.0, "while gaining akademis")
	assert_eq(m.students[2].get_akademis_delta(), 0.0, "student 3 gains only seni")
	assert_eq(m.students[2].get_seni_delta(), 7.0, "student 3 gains only seni")
	for key in ["get_akademis_delta", "get_seni_delta", "get_olahraga_delta"]:
		assert_eq(m.students[3].call(key), 0.0, "student 4 is flat: " + key)


func test_both_needs_move_for_everyone() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	for s in m.students:
		assert_eq(s.get_energy_delta(), -12.0, "energy falls for " + s.student_name)
		assert_eq(s.get_mood_delta(), 6.0, "mood rises for " + s.student_name)


func test_a_roster_longer_than_the_ladder_repeats_its_last_entry() -> void:
	var m := _manager()
	var extra := StudentData.new()
	extra.student_name = "Eko"
	extra.akademis = 50.0
	extra.record_initial_stats()
	m.students.append(extra)
	WeekReportRehearsal.apply_sample_week(m)
	assert_eq(extra.get_akademis_delta(), 0.0, "a fifth student reads the flat last entry")


func test_a_stat_near_the_ceiling_is_clamped() -> void:
	var m := _manager()
	m.students[0].akademis = 95.0
	WeekReportRehearsal.apply_sample_week(m)
	assert_eq(m.students[0].akademis, 100.0, "clamped to 100, as the simulation clamps")


func test_the_history_reads_two_won_and_one_lost() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	var recap: Dictionary = WeekRecap.compute(m)
	assert_eq(int(recap["minigames_won"]), 2, "EVENT BERHASIL : 2")
	assert_eq(int(recap["minigames_lost"]), 1, "EVENT GAGAL : 1")
	assert_eq(m.minigame_history.size(), 4, "three minigames and one event in Logs")


## The rows carry the keys StudentManager itself records, so Logs reads
## them exactly as it reads a real week.
func test_every_history_row_carries_the_keys_the_game_records() -> void:
	var m := _manager()
	WeekReportRehearsal.apply_sample_week(m)
	for entry in m.minigame_history:
		for key in ["day", "category", "game_name", "won"]:
			assert_true(entry.has(key), "%s has %s" % [entry.get("game_name", "?"), key])
		if entry["category"] == "Event":
			assert_true(entry.has("details") and entry.has("affected_students"),
				"an event carries details and affected_students")
		else:
			assert_true(entry.has("score") and entry.has("max_score") and entry.has("results"),
				"a minigame carries score, max_score and results")


func test_the_report_scene_is_the_weekly_report() -> void:
	assert_eq(WeekReportRehearsal.REPORT_SCENE,
		"res://Scenes/SchoolSimulation/ResultCheckup.tscn", "the preview opens ResultCheckup")
