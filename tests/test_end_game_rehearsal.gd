@tool
extends McpTestSuite

## EndGameRehearsal is the debug-only end-of-grade jig. Unlike most suites
## here these are real behavioural tests rather than source scans: the file
## is plain static functions over Dictionaries with no nodes to
## instantiate, the same reason test_run_stats.gd tests RunStats directly.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "end_game_rehearsal"


## Two stand-in students in approved_students' dictionary format. Kept
## local so these tests never depend on DebugManager.DEFAULT_STUDENTS
## staying four entries long or keeping its current stat values.
func _fake_source() -> Array:
	return [
		{"id": 1, "name": "Satu", "akademis1": 1.0, "akademis2": 2.0,
			"akademis3": 3.0, "kepribadian1": 4.0, "kepribadian2": 5.0,
			"hobby_category": "Akademis"},
		{"id": 2, "name": "Dua", "akademis1": 6.0, "akademis2": 7.0,
			"akademis3": 8.0, "kepribadian1": 9.0, "kepribadian2": 10.0,
			"hobby_category": "Olahraga"},
	]


func test_target_tracks_the_grade_uplift() -> void:
	assert_eq(EndGameRehearsal.target_for_grade(7),
		EndGameRehearsal.BASE_SKILL + Balance.TARGET_KENAIKAN_KELAS_7,
		"grade 7 target is base + the grade 7 uplift")
	assert_eq(EndGameRehearsal.target_for_grade(8),
		EndGameRehearsal.BASE_SKILL + Balance.TARGET_KENAIKAN_KELAS_8,
		"grade 8 target is base + the grade 8 uplift")
	assert_eq(EndGameRehearsal.target_for_grade(9),
		EndGameRehearsal.BASE_SKILL + Balance.TARGET_KENAIKAN_KELAS_9,
		"grade 9 target is base + the grade 9 uplift")


func test_lulus_clears_every_target_for_every_student() -> void:
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_LULUS, 7, _fake_source())
	assert_eq(roster.size(), 2, "one entry per source student")
	for s in roster:
		for pair in [["akademis1", "target_akademis1"],
				["akademis2", "target_akademis2"],
				["akademis3", "target_akademis3"]]:
			assert_true(float(s[pair[0]]) >= float(s[pair[1]]),
				"%s must clear %s" % [s["name"], pair[1]])


func test_gagal_misses_every_target_for_every_student() -> void:
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_GAGAL, 7, _fake_source())
	for s in roster:
		for pair in [["akademis1", "target_akademis1"],
				["akademis2", "target_akademis2"],
				["akademis3", "target_akademis3"]]:
			assert_true(float(s[pair[0]]) < float(s[pair[1]]),
				"%s must miss %s" % [s["name"], pair[1]])


func test_campur_gives_each_slot_a_different_cleared_count() -> void:
	# Four source students so the whole 3/2/1/0 ladder is exercised.
	var source := _fake_source()
	source.append(source[0].duplicate())
	source.append(source[1].duplicate())
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_CAMPUR, 7, source)
	var counts: Array = []
	for s in roster:
		var cleared := 0
		if float(s["akademis1"]) >= float(s["target_akademis1"]): cleared += 1
		if float(s["akademis2"]) >= float(s["target_akademis2"]): cleared += 1
		if float(s["akademis3"]) >= float(s["target_akademis3"]): cleared += 1
		counts.append(cleared)
	# Asserted slot by slot rather than as one array compare: a typed-array
	# equality failure reports "expected [3,2,1,0] got [3,2,1,1]" with no
	# hint which student drifted.
	assert_eq(counts.size(), 4, "one count per student")
	assert_eq(counts[0], 3, "slot 0 clears all three -- the 3-star card")
	assert_eq(counts[1], 2, "slot 1 clears two -- the 2-star card")
	assert_eq(counts[2], 1, "slot 2 clears one -- the 1-star card")
	assert_eq(counts[3], 0, "slot 3 clears none -- the 0-star card")


func test_build_roster_does_not_mutate_its_source() -> void:
	var source := _fake_source()
	EndGameRehearsal.build_roster(EndGameRehearsal.PRESET_LULUS, 7, source)
	assert_eq(source[0]["akademis1"], 1.0,
		"the source roster must be copied, never written through")


func test_roster_keeps_identity_fields_and_sets_base_stats() -> void:
	var roster := EndGameRehearsal.build_roster(
		EndGameRehearsal.PRESET_LULUS, 7, _fake_source())
	assert_eq(roster[0]["name"], "Satu", "names carry over")
	assert_eq(roster[0]["id"], 1, "ids carry over")
	assert_eq(roster[0]["kepribadian1"], EndGameRehearsal.REHEARSAL_MOOD,
		"mood is set to the rehearsal value, not the source's")
	assert_eq(roster[0]["kepribadian2"], EndGameRehearsal.REHEARSAL_ENERGY,
		"energy is set to the rehearsal value, not the source's")
	assert_eq(roster[0]["base_akademis1"], EndGameRehearsal.BASE_SKILL,
		"base_* must be set so a later initialize_grade_targets() " +
		"recomputes the same targets instead of moving them")
