@tool
extends McpTestSuite

## StatFlags: which of AturJadwal's five stat bars wears a weak-stat chip
## (2026-09-24 visual polish, D7). Pure static logic over a student
## dictionary, so it is tested directly. Every threshold is read from
## Balance or from the student's own targets, never restated here, so the
## suite keeps tracking the collaborator's tuning.
##
## Must be @tool; no coroutine tests (the runner does not await).

func suite_name() -> String:
	return "stat_flags"


## A student comfortably clear of every threshold: skills at target, needs
## well above the tiredness line.
func _healthy() -> Dictionary:
	return {
		"akademis1": 60.0, "target_akademis1": 60.0,
		"akademis2": 70.0, "target_akademis2": 60.0,
		"akademis3": 65.0, "target_akademis3": 60.0,
		"kepribadian1": Balance.BATAS_KELELAHAN + 30.0,
		"kepribadian2": Balance.BATAS_KELELAHAN + 30.0,
	}


func test_a_healthy_student_wears_no_flags() -> void:
	assert_eq(StatFlags.flags_for(_healthy()), {}, "nothing is weak, so nothing is flagged")


## Early in a grade every skill sits below its target, so flagging each one
## would put a chip on all three bars all the time. Only the single most
## urgent skill -- the biggest gap to its own target -- is flagged.
func test_only_the_most_urgent_skill_is_flagged() -> void:
	var s := _healthy()
	s["akademis1"] = 50.0   # 10 short
	s["akademis2"] = 35.0   # 25 short: most urgent
	s["akademis3"] = 55.0   # 5 short
	assert_eq(StatFlags.flags_for(s), {"akademis2": StatFlags.PERLU},
		"the biggest gap to target gets the one 'perlu' chip")


func test_a_skill_exactly_at_target_is_not_weak() -> void:
	var s := _healthy()
	s["akademis3"] = s["target_akademis3"]
	assert_false(StatFlags.flags_for(s).has("akademis3"), "at target is cleared, not weak")


## Needs are flagged on the collaborator's own tiredness line,
## Balance.BATAS_KELELAHAN: strictly below it is tired.
func test_needs_below_the_tiredness_line_are_lelah() -> void:
	var s := _healthy()
	s["kepribadian1"] = Balance.BATAS_KELELAHAN - 1.0
	s["kepribadian2"] = Balance.BATAS_KELELAHAN
	var flags := StatFlags.flags_for(s)
	assert_eq(flags.get("kepribadian1", ""), StatFlags.LELAH, "mood below the line is lelah")
	assert_false(flags.has("kepribadian2"), "energy exactly on the line is not yet lelah")


## Tiredness does not compete with the skill flag: a student can be both
## behind on a skill and worn out, and both are worth saying.
func test_lelah_and_perlu_can_show_together() -> void:
	var s := _healthy()
	s["akademis1"] = 10.0
	s["kepribadian2"] = 0.0
	assert_eq(StatFlags.flags_for(s),
		{"akademis1": StatFlags.PERLU, "kepribadian2": StatFlags.LELAH})


## A student dictionary missing a key must not raise or flag it: the screen
## feeds partial dictionaries in its no-roster fallback.
func test_missing_keys_are_never_flagged() -> void:
	assert_eq(StatFlags.flags_for({}), {}, "an empty dictionary flags nothing")


func test_the_chip_words_are_the_indonesian_ones() -> void:
	assert_eq(StatFlags.PERLU, "perlu")
	assert_eq(StatFlags.LELAH, "lelah")
