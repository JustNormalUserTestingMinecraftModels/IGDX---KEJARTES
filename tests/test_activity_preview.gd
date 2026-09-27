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


## A student with no favourite at all -- the "Seimbang" personality.
func _student_seimbang() -> Dictionary:
	return {"hobby_category": "Seimbang", "name": "Uji"}


# ---- arrow language (2026-09-24 picker rebuild, D11/D12) -------------------

func test_favourite_subject_earns_more_up_arrows_than_a_plain_one() -> void:
	var fav := ActivityPreview.gain_arrows("Akademis", _student_akademis(), 7)
	var plain := ActivityPreview.gain_arrows("Olahraga", _student_akademis(), 7)
	assert_eq(plain, 1, "an ordinary study day is one up-arrow")
	assert_true(fav > plain, "the favourite must out-arrow a plain subject")
	assert_true(fav <= ActivityPreview.MAX_ARROWS, "never more than MAX_ARROWS")


## The favourite's arrows follow the bonus's size next to the base, so a
## Balance retune that shrinks the bonus shrinks the arrows with it.
func test_favourite_arrows_follow_the_bonus_to_base_ratio() -> void:
	for grade in [7, 8, 9]:
		var base := ActivityPreview.base_gain(grade)
		var bonus := ActivityPreview.favorit_bonus(grade)
		var expected := clampi(1 + ceili(bonus / base * (ActivityPreview.MAX_ARROWS - 1)),
			1, ActivityPreview.MAX_ARROWS)
		assert_eq(ActivityPreview.gain_arrows("Akademis", _student_akademis(), grade), expected,
			"grade %d favourite arrows must come from its Balance bonus and base" % grade)


func test_non_skill_tiles_carry_no_gain_arrows() -> void:
	assert_eq(ActivityPreview.gain_arrows("Wirausaha", _student_akademis(), 7), 0,
		"Wirausaha gains no skill, so no up-arrows on its skill slot")
	assert_eq(ActivityPreview.gain_arrows("Istirahat", _student_akademis(), 7), 0,
		"Libur gains no skill")


func test_base_and_bonus_read_balance_per_grade() -> void:
	assert_eq(ActivityPreview.base_gain(8), Balance.BELAJAR_POIN_KELAS_8, "grade 8 base")
	assert_eq(ActivityPreview.favorit_bonus(9), Balance.BELAJAR_BONUS_FAVORIT_KELAS_9,
		"grade 9 bonus")


## The multiplier the picker shows must be the one the simulation charges.
func test_cost_multiplier_mirrors_student_data() -> void:
	assert_eq(ActivityPreview.cost_multiplier("Akademis", _student_akademis()),
		Balance.BIAYA_KALAU_MAPEL_FAVORIT, "favourite subject")
	assert_eq(ActivityPreview.cost_multiplier("Olahraga", _student_akademis()),
		Balance.BIAYA_KALAU_BUKAN_FAVORIT, "someone else's subject")
	assert_eq(ActivityPreview.cost_multiplier("Olahraga", _student_seimbang()),
		Balance.BIAYA_KALAU_MURID_SEIMBANG, "a Seimbang student")
	assert_eq(ActivityPreview.cost_multiplier("Istirahat", _student_akademis()), 1.0,
		"Libur is never scaled")
	var data := StudentData.new()
	data.specialty_category = "Akademis"
	assert_eq(ActivityPreview.cost_multiplier("Olahraga", _student_akademis()),
		data.get_category_efficiency_multiplier("Olahraga"),
		"the mirror must agree with StudentData itself")


func test_study_days_drain_and_libur_recovers() -> void:
	assert_true(ActivityPreview.energy_delta("Akademis", _student_akademis()) < 0.0,
		"a study day drains energy")
	assert_true(ActivityPreview.mood_delta("Wirausaha", _student_akademis()) < 0.0,
		"Wirausaha drains mood")
	assert_true(ActivityPreview.energy_delta("Istirahat", _student_akademis()) > 0.0,
		"Libur recovers energy")
	assert_true(ActivityPreview.mood_delta("Istirahat", _student_akademis()) > 0.0,
		"Libur recovers mood")


## Cost arrows must map the Balance numbers onto one shared scale.
func test_cost_arrows_map_balance_onto_the_shared_scale() -> void:
	for category in ["Akademis", "Olahraga", "Wirausaha", "Istirahat"]:
		var s := _student_akademis()
		var e := ActivityPreview.energy_delta(category, s)
		var expected := clampi(roundi(absf(e) / ActivityPreview.energy_scale()
			* ActivityPreview.MAX_ARROWS), 1, ActivityPreview.MAX_ARROWS)
		assert_eq(ActivityPreview.energy_arrows(category, s), expected,
			category + " energy arrows must follow Balance")
		var m := ActivityPreview.mood_delta(category, s)
		var expected_m := clampi(roundi(absf(m) / ActivityPreview.mood_scale()
			* ActivityPreview.MAX_ARROWS), 1, ActivityPreview.MAX_ARROWS)
		assert_eq(ActivityPreview.mood_arrows(category, s), expected_m,
			category + " mood arrows must follow Balance")


## The favourite is cheaper, so it can never show more cost arrows than
## the same subject for a student who does not favour it.
func test_the_favourite_never_costs_more_arrows() -> void:
	var fav := ActivityPreview.energy_arrows("Akademis", _student_akademis())
	var other := ActivityPreview.energy_arrows("Akademis", _student_seniman())
	assert_true(fav <= other, "favourite energy arrows %d must not exceed %d" % [fav, other])


func test_arrows_for_bounds() -> void:
	assert_eq(ActivityPreview.arrows_for(0.0, 10.0), 0, "no effect, no arrow")
	assert_eq(ActivityPreview.arrows_for(0.1, 10.0), 1, "a tiny effect still shows one arrow")
	assert_eq(ActivityPreview.arrows_for(10.0, 10.0), ActivityPreview.MAX_ARROWS,
		"the biggest swing is the full count")
	assert_eq(ActivityPreview.arrows_for(-10.0, 10.0), ActivityPreview.MAX_ARROWS,
		"direction is the caller's job; the count uses the size")


func test_earning_pips_are_a_magnitude_from_balance() -> void:
	var typical := float(Balance.WIRAUSAHA_UANG_MIN + Balance.WIRAUSAHA_UANG_MAX) / 2
	assert_eq(ActivityPreview.earning_pips(),
		ActivityPreview.arrows_for(typical, float(Balance.WIRAUSAHA_UANG_MAX)),
		"coin pips measure a typical day against the best one")
	assert_true(ActivityPreview.earning_pips() >= 1, "Wirausaha always earns something")


## D12: no raw ranges anywhere the picker speaks.
func test_no_note_shows_a_range() -> void:
	for category in ["", "Akademis", "Olahraga", "Wirausaha", "Istirahat"]:
		for s in [_student_akademis(), _student_seimbang()]:
			var note := ActivityPreview.selection_note(category, s, 7)
			assert_false(note.contains("~"), "a picker note must not show a ~ range: " + note)
			assert_true(note.length() > 0, "every state has a note")


## D14: the favourite teaches its own bonus.
func test_the_favourite_note_is_the_bonus_breakdown() -> void:
	var note := ActivityPreview.selection_note("Akademis", _student_akademis(), 7)
	var base := int(Balance.BELAJAR_POIN_KELAS_7)
	var bonus := int(Balance.BELAJAR_BONUS_FAVORIT_KELAS_7)
	assert_true(note.contains("Dasar +%d" % base), "shows the base: " + note)
	assert_true(note.contains("Bonus favorit +%d" % bonus), "shows the bonus: " + note)
	assert_true(note.contains("Total +%d" % (base + bonus)), "shows the total: " + note)
	assert_true(note.contains("hemat"), "says the favourite is cheaper: " + note)


func test_an_empty_selection_explains_what_to_do() -> void:
	var note := ActivityPreview.selection_note("", _student_akademis(), 7)
	assert_true(note.contains("Pilih"), "with nothing selected, point at the Pilih button")


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
