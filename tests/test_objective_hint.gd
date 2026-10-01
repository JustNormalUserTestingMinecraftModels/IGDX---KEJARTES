@tool
extends McpTestSuite

## ObjectiveHint: the plain-language line behind AturJadwal's objective strip
## (2026-09-24 visual polish, D8), and the strip's own numbers. Pure static
## logic, tested directly. The pass line is GameState.MIN_TARGETS_PER_STUDENT and the
## student's own targets, never restated here.
##
## Must be @tool; no coroutine tests (the runner does not await).

func suite_name() -> String:
	return "objective_hint"


func _student() -> Dictionary:
	return {
		"name": "Marcel",
		"akademis": 60.0, "target_akademis": 60.0,
		"seni_budaya": 60.0, "target_seni_budaya": 60.0,
		"olahraga": 60.0, "target_olahraga": 60.0,
		"mood": Balance.BATAS_KELELAHAN + 30.0,
		"energy": Balance.BATAS_KELELAHAN + 30.0,
	}


## The hint names the student and their most urgent skill, in the words the
## day notes and picker already use.
func test_the_hint_names_the_most_urgent_skill() -> void:
	var s := _student()
	s["olahraga"] = 20.0
	s["akademis"] = 50.0
	var hint := ObjectiveHint.compose(s)
	assert_true(hint.begins_with("Marcel butuh Atletik"),
		"Olahraga is the biggest gap, and reads 'Atletik', got: " + hint)


func test_low_energy_adds_the_izin_warning() -> void:
	var s := _student()
	s["akademis"] = 30.0
	s["energy"] = Balance.BATAS_KELELAHAN - 1.0
	var hint := ObjectiveHint.compose(s)
	assert_true(hint.contains("Akademik"), hint)
	assert_true(hint.contains("jaga energi biar tidak Izin"), "tired students get the Izin warning: " + hint)


func test_low_mood_adds_the_mood_warning() -> void:
	var s := _student()
	s["mood"] = Balance.BATAS_KELELAHAN - 1.0
	var hint := ObjectiveHint.compose(s)
	assert_true(hint.contains("mood"), "a low mood gets its own warning: " + hint)


func test_a_student_on_every_target_is_told_so() -> void:
	var hint := ObjectiveHint.compose(_student())
	assert_true(hint.begins_with("Marcel sudah mencapai semua target"), hint)


func test_a_missing_name_still_reads() -> void:
	var s := _student()
	s.erase("name")
	assert_true(ObjectiveHint.compose(s).begins_with("Murid "), "falls back to 'Murid'")


## The strip's title: month and week of the grade, counted against the
## grade's own length.
func test_the_title_reads_month_and_week_of_total() -> void:
	assert_eq(ObjectiveHint.title(1, 6), "Agustus - Minggu 1/6")
	assert_eq(ObjectiveHint.title(5, 12), "September - Minggu 5/12")
	assert_eq(ObjectiveHint.title(40, 16), "Desember - Minggu 40/16",
		"a week past the calendar clamps to the last month rather than failing")


## The title and the safe-student chip are set in the display face, Boohong, which
## carries no "·" and no "—" (the plan's separator and the old header's). A
## glyph the face lacks falls back to the device's fonts or to a box, so
## every character these can produce must be one Boohong actually has.
func test_the_strip_only_uses_glyphs_the_display_face_has() -> void:
	var face: Font = DesignTokens.load_default().font_display
	assert_true(face != null, "no display face")
	if face == null:
		return
	var texts := []
	for week in [1, 5, 9, 13, 17, 21]:
		texts.append(ObjectiveHint.title(week, 16))
	for pair in [[0, 4], [3, 4], [6, 6], [1, 1]]:
		texts.append(ObjectiveHint.safe_text(pair[0], pair[1]))
	for text in texts:
		for i in String(text).length():
			var code := String(text).unicode_at(i)
			assert_true(face.has_char(code),
				"'%s' in '%s' is not in the display face" % [String.chr(code), text])


## The bar fills toward the whole roster being safe (GameState's
## per-student rule): full means the grade passes.
func test_progress_is_the_safe_share_of_the_roster() -> void:
	assert_eq(ObjectiveHint.safe_percent(0, 4), 0.0)
	assert_eq(ObjectiveHint.safe_percent(2, 4), 50.0)
	assert_eq(ObjectiveHint.safe_percent(4, 4), 100.0)
	assert_eq(ObjectiveHint.safe_percent(5, 4), 100.0, "clamped at full")
	assert_eq(ObjectiveHint.safe_percent(0, 0), 100.0,
		"an empty roster reads as passing, as check_semester_passed() does")


func test_the_chip_reads_safe_students_over_the_roster() -> void:
	assert_eq(ObjectiveHint.safe_text(3, 4), "3 / 4")
	assert_eq(ObjectiveHint.safe_text(0, 6), "0 / 6")


func test_the_strip_no_longer_measures_stars() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/ObjectiveHint.gd")
	assert_false(src.contains("STAR_WIN_THRESHOLD"),
		"the pass line is per-student now, not a star count")
