@tool
extends McpTestSuite

## The Amplop Coklat level select (spec:
## docs/superpowers/specs/2026-09-25-amplop-level-select-design.md): a fan
## of three brown envelopes, one per grade, a briefing card for the centred
## one, and an open-envelope confirmation that sets the grade and wipes into
## the intro cutscene.
##
## Must be @tool, and no test here may be a coroutine.

const LS := preload("res://Scripts/LevelSelect/level_select.gd")
const STUDENT_CARD := preload("res://Scripts/StudentCard/student_card.gd")

const _SCRIPT_PATH := "res://Scripts/LevelSelect/level_select.gd"


func suite_name() -> String:
	return "level_select"


# ── Data ─────────────────────────────────────────────────────────────────────

## Weeks and target must be read from Balance.gd, never hardcoded literals.
func test_weeks_and_target_come_from_balance() -> void:
	assert_eq(LS.weeks_for(7), Balance.JUMLAH_MINGGU_KELAS_7, "wk7")
	assert_eq(LS.weeks_for(8), Balance.JUMLAH_MINGGU_KELAS_8, "wk8")
	assert_eq(LS.weeks_for(9), Balance.JUMLAH_MINGGU_KELAS_9, "wk9")
	assert_eq(LS.target_for(7), int(Balance.TARGET_KENAIKAN_KELAS_7), "t7")
	assert_eq(LS.target_for(8), int(Balance.TARGET_KENAIKAN_KELAS_8), "t8")
	assert_eq(LS.target_for(9), int(Balance.TARGET_KENAIKAN_KELAS_9), "t9")


## Every grade has a difficulty word, a gauge fill, a tag and a brief line.
func test_difficulty_map_covers_all_grades() -> void:
	for g in LS.GRADES:
		assert_true(LS.DIFFICULTY_WORD.has(g), "word for %d" % g)
		assert_true(LS.DIFFICULTY_FILL.has(g), "fill for %d" % g)
		assert_true(LS.TAG_TEXT.has(g), "tag for %d" % g)
		assert_true(LS.BRIEF_FLAVOR.has(g), "brief flavour for %d" % g)
	assert_eq(LS.DIFFICULTY_WORD[7], "santai", "kelas 7 is santai")
	assert_eq(LS.DIFFICULTY_WORD[8], "menantang", "kelas 8 is menantang")
	assert_eq(LS.DIFFICULTY_WORD[9], "susah", "kelas 9 is susah")


## The screen must not re-type balance numbers as literals.
func test_source_reads_balance_constants() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Balance.JUMLAH_MINGGU_KELAS_"), "reads weeks from Balance")
	assert_true(src.contains("Balance.TARGET_KENAIKAN_KELAS_"), "reads target from Balance")


## The pupil count is the roster StudentCard really approves, not a copy.
func test_roster_size_is_student_cards_own_count() -> void:
	for g in LS.GRADES:
		assert_eq(LS.roster_size_for(g), STUDENT_CARD.max_approve_for(g),
			"kelas %d roster matches StudentCard" % g)
	assert_eq([LS.roster_size_for(7), LS.roster_size_for(8), LS.roster_size_for(9)],
		[2, 3, 4], "2/3/4 pupils by grade")
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/student_card.gd")
	assert_true(src.contains("MAX_APPROVE = max_approve_for("),
		"StudentCard reads its own count from the shared function")
