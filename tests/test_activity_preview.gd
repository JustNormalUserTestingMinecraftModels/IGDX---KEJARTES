@tool
extends McpTestSuite

## ActivityPreview is the single source of every number the Penjadwalan
## popup displays. These tests pin it to Balance.gd: if a tester edits a
## Balance number, the preview must move with it. A hardcoded literal
## here would silently break that promise.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

func suite_name() -> String:
	return "activity_preview"


## A student whose specialty is Akademis. hobby_category "Akademik" is the
## UI spelling; the bridge normalizes it to "Akademis" (see CLAUDE.md).
func _student_akademis() -> Dictionary:
	return {"hobby_category": "Akademik", "name": "Uji"}


func _student_seniman() -> Dictionary:
	return {"hobby_category": "SeniBudaya", "name": "Uji"}


func test_skill_gain_uses_balance_for_a_non_specialty_subject() -> void:
	var gain := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 7)
	assert_eq(gain, Balance.BELAJAR_POIN_KELAS_7,
		"a non-specialty subject gains exactly the grade's base points")


func test_skill_gain_adds_the_specialty_bonus() -> void:
	var gain := ActivityPreview.skill_gain("Akademis", _student_akademis(), 7)
	assert_eq(gain, Balance.BELAJAR_POIN_KELAS_7 + Balance.BELAJAR_BONUS_FAVORIT_KELAS_7,
		"the student's own specialty gains base + bonus")


func test_skill_gain_is_grade_aware() -> void:
	var g7 := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 7)
	var g8 := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 8)
	var g9 := ActivityPreview.skill_gain("Olahraga", _student_akademis(), 9)
	assert_eq(g7, Balance.BELAJAR_POIN_KELAS_7, "grade 7 reads its own field")
	assert_eq(g8, Balance.BELAJAR_POIN_KELAS_8, "grade 8 reads its own field")
	assert_eq(g9, Balance.BELAJAR_POIN_KELAS_9, "grade 9 reads its own field")


## "Akademik" is the UI spelling of the "Akademis" category. A student whose
## hobby_category is "Akademik" must still get the specialty bonus on the
## "Akademis" row -- this mismatch is the single most common bug here.
func test_akademik_hobby_spelling_still_earns_the_specialty_bonus() -> void:
	var gain := ActivityPreview.skill_gain("Akademis", _student_akademis(), 7)
	assert_true(gain > Balance.BELAJAR_POIN_KELAS_7,
		"hobby_category 'Akademik' must match the 'Akademis' category")


func test_skill_row_has_one_chip_showing_the_gain() -> void:
	var chips := ActivityPreview.chips_for("SeniBudaya", _student_seniman(), 7)
	assert_eq(chips.size(), 1, "a skill row shows a single gain chip")
	assert_eq(chips[0]["icon"], "", "the skill chip carries no inline icon")
	var expected := Balance.BELAJAR_POIN_KELAS_7 + Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
	assert_eq(chips[0]["text"], "+%d" % int(expected),
		"the skill chip shows the signed gain")


func test_wirausaha_shows_energy_cost_then_money_range() -> void:
	var chips := ActivityPreview.chips_for("Wirausaha", _student_akademis(), 7)
	assert_eq(chips.size(), 2, "Wirausaha shows an energy chip and a money chip")
	assert_eq(chips[0]["icon"], "energy", "first chip is energy")
	assert_eq(chips[0]["text"], "-%d" % int(Balance.WIRAUSAHA_BIAYA_ENERGI),
		"energy cost is a fixed Balance value, shown as one number")
	assert_eq(chips[1]["icon"], "money", "second chip is money")
	assert_eq(chips[1]["text"], "+%d~%d" % [Balance.WIRAUSAHA_UANG_MIN, Balance.WIRAUSAHA_UANG_MAX],
		"money is a range, shown as min~max")


func test_libur_shows_energy_and_mood_recovery_ranges() -> void:
	var chips := ActivityPreview.chips_for("Istirahat", _student_akademis(), 7)
	assert_eq(chips.size(), 2, "Libur shows an energy chip and a mood chip")
	assert_eq(chips[0]["icon"], "energy", "first chip is energy")
	assert_eq(chips[0]["text"],
		"+%d~%d" % [int(Balance.LIBUR_ENERGI_PULIH_MIN), int(Balance.LIBUR_ENERGI_PULIH_MAX)],
		"energy recovery is a range")
	assert_eq(chips[1]["icon"], "mood", "second chip is mood")
	assert_eq(chips[1]["text"],
		"+%d~%d" % [int(Balance.LIBUR_MOOD_PULIH_MIN), int(Balance.LIBUR_MOOD_PULIH_MAX)],
		"mood recovery is a range")


func test_format_range_collapses_equal_bounds_to_one_number() -> void:
	assert_eq(ActivityPreview.format_range(10.0, 10.0, true), "+10",
		"a range whose bounds match renders as a single number")
	assert_eq(ActivityPreview.format_range(10.0, 20.0, true), "+10~20",
		"a genuine range renders as min~max")


func test_costs_for_a_study_day_come_from_balance() -> void:
	var e := ActivityPreview.energy_cost("Akademis")
	var m := ActivityPreview.mood_cost("Akademis")
	assert_eq(e, Balance.BELAJAR_BIAYA_ENERGI_MAX, "study energy cost reads Balance")
	assert_eq(m, Balance.BELAJAR_BIAYA_MOOD_MAX, "study mood cost reads Balance")


## Istirahat RECOVERS -- its stored cost must be negative, matching the sign
## convention day_schedules has always used.
func test_istirahat_costs_are_negative_because_it_recovers() -> void:
	assert_true(ActivityPreview.energy_cost("Istirahat") < 0.0,
		"Istirahat recovers energy, so its 'cost' is negative")
	assert_true(ActivityPreview.mood_cost("Istirahat") < 0.0,
		"Istirahat recovers mood, so its 'cost' is negative")


func test_no_hardcoded_balance_literals_in_the_helper() -> void:
	# The whole point of this file is that it holds no numbers of its own.
	# Collect violations into a list and assert once at the end, so a clean
	# file (the expected, passing case) still registers an assertion instead
	# of the runner reporting "0 assertions" as a skipped test.
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/ActivityPreview.gd")
	var regex := RegEx.new()
	regex.compile("(?<![\\w.])\\d+\\.\\d+")
	var allowed := ["0.0", "1.0"]
	var violations: Array[String] = []
	for m in regex.search_all(src):
		if not allowed.has(m.get_string()):
			violations.append(m.get_string())
	assert_true(violations.is_empty(),
		"ActivityPreview must hold no balance literals; found " + str(violations))
