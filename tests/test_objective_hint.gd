@tool
extends McpTestSuite

## ObjectiveHint: the plain-language line behind AturJadwal's objective strip
## (2026-09-24 visual polish, D8), and the strip's own numbers. Pure static
## logic, tested directly. Thresholds come from Balance and the student's own
## targets, never restated here.
##
## Must be @tool; no coroutine tests (the runner does not await).

func suite_name() -> String:
	return "objective_hint"


func _student() -> Dictionary:
	return {
		"name": "Marcel",
		"akademis1": 60.0, "target_akademis1": 60.0,
		"akademis2": 60.0, "target_akademis2": 60.0,
		"akademis3": 60.0, "target_akademis3": 60.0,
		"kepribadian1": Balance.BATAS_KELELAHAN + 30.0,
		"kepribadian2": Balance.BATAS_KELELAHAN + 30.0,
	}


## The hint names the student and their most urgent skill, in the words the
## day notes and picker already use.
func test_the_hint_names_the_most_urgent_skill() -> void:
	var s := _student()
	s["akademis3"] = 20.0
	s["akademis1"] = 50.0
	var hint := ObjectiveHint.compose(s)
	assert_true(hint.begins_with("Marcel butuh Atletik"),
		"Olahraga is the biggest gap, and reads 'Atletik', got: " + hint)


func test_low_energy_adds_the_izin_warning() -> void:
	var s := _student()
	s["akademis1"] = 30.0
	s["kepribadian2"] = Balance.BATAS_KELELAHAN - 1.0
	var hint := ObjectiveHint.compose(s)
	assert_true(hint.contains("Akademik"), hint)
	assert_true(hint.contains("jaga energi biar tidak Izin"), "tired students get the Izin warning: " + hint)


func test_low_mood_adds_the_mood_warning() -> void:
	var s := _student()
	s["kepribadian1"] = Balance.BATAS_KELELAHAN - 1.0
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


## The title and the star chip are set in the display face, Boohong, which
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
	for stars in [0.0, 0.25, 1.5, 1.75, 2.0, 3.0]:
		texts.append(ObjectiveHint.star_text(stars))
	for text in texts:
		for i in String(text).length():
			var code := String(text).unicode_at(i)
			assert_true(face.has_char(code),
				"'%s' in '%s' is not in the display face" % [String.chr(code), text])


## The progress bar fills toward the pass line, not toward the three-star
## maximum: full means the grade is passing.
func test_progress_is_measured_against_the_pass_line() -> void:
	assert_eq(ObjectiveHint.progress_percent(0.0), 0.0)
	assert_eq(ObjectiveHint.progress_percent(Balance.STAR_WIN_THRESHOLD), 100.0)
	assert_eq(ObjectiveHint.progress_percent(Balance.STAR_WIN_THRESHOLD * 0.5), 50.0)
	assert_eq(ObjectiveHint.progress_percent(Balance.STARS_TOTAL), 100.0, "clamped at full")


func test_the_star_chip_reads_stars_over_the_pass_line() -> void:
	assert_eq(ObjectiveHint.star_text(1.5), "1.5 / %s" % ObjectiveHint.format_stars(Balance.STAR_WIN_THRESHOLD))
	assert_eq(ObjectiveHint.format_stars(2.0), "2", "a whole number drops its decimal")
	assert_eq(ObjectiveHint.format_stars(1.75), "1.8", "one decimal")
