@tool
extends McpTestSuite

## LombaMenari's timing (2026-09-15): a wider hit window, three grades --
## UPS!, BAGUS!, SEMPURNA! -- and the dancer drawn behind the hit zone, so
## the target is never hidden under her. grade_for_distance() is pure and
## tested directly; the rest is source and scene shape, since the minigame
## cannot be played inside the editor.
##
## Must be @tool; no test here may be a coroutine.

const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
const SCENE_PATH := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"


func suite_name() -> String:
	return "lomba_menari_timing"


## Siblings draw in tree order: an earlier sibling is behind a later one.
func test_the_dancer_draws_behind_the_hit_zone() -> void:
	var scene := load(SCENE_PATH).instantiate() as Node
	track(scene)
	var backdrop: int = scene.get_node("Background").get_index()
	var dancer: int = scene.get_node("CharacterDisplay").get_index()
	var zone: int = scene.get_node("HitZone").get_index()
	var notes: int = scene.get_node("NotesParent").get_index()
	assert_true(dancer < zone, "CharacterDisplay is before HitZone, so the zone draws over her")
	assert_true(backdrop < dancer, "she still stands in front of the backdrop")
	assert_true(zone < notes, "and the notes still fly over the zone")


# ─── grading

## LombaMenari.gd declares no class_name; reached through a preloaded const,
## as tests/test_minigame_star_rubric.gd does.
const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")


func test_a_hit_grades_by_distance_from_the_centre() -> void:
	assert_eq(MenariScript.grade_for_distance(0.0, 70.0, 170.0), MenariScript.Grade.SEMPURNA,
		"dead centre is SEMPURNA")
	assert_eq(MenariScript.grade_for_distance(69.9, 70.0, 170.0), MenariScript.Grade.SEMPURNA,
		"just inside the tight window")
	assert_eq(MenariScript.grade_for_distance(70.0, 70.0, 170.0), MenariScript.Grade.BAGUS,
		"its edge is only BAGUS")
	assert_eq(MenariScript.grade_for_distance(169.9, 70.0, 170.0), MenariScript.Grade.BAGUS,
		"just inside the wide window")
	assert_eq(MenariScript.grade_for_distance(170.0, 70.0, 170.0), MenariScript.Grade.UPS,
		"its edge is UPS")


func test_the_window_is_wider_than_before() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("var bagus_window_px: float = 170.0"), "BAGUS reaches 170 px, up from 120")
	assert_true(src.contains("var sempurna_window_px: float = 70.0"), "SEMPURNA reaches 70 px, up from 45")
	assert_false(src.contains("min_dist < 120.0"), "the old hardcoded window is gone")
	assert_false(src.contains("min_dist < 45.0"), "both of them")


func test_both_windows_are_documented_exports() -> void:
	var lines := FileAccess.get_file_as_string(SCRIPT_PATH).split("\n")
	for knob in ["bagus_window_px", "sempurna_window_px"]:
		var found := -1
		for i in range(lines.size()):
			if lines[i].strip_edges().begins_with("@export") and lines[i].contains("var " + knob):
				found = i
				break
		assert_gt(found, 0, knob + " is an @export")
		assert_true(lines[found - 1].strip_edges().begins_with("##"), knob + " has a ## doc line")


func test_a_note_stays_swipeable_for_the_whole_window() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("vec_from_target.dot(move_dir) > bagus_window_px"),
		"a note is missed only once it leaves the BAGUS window")
	assert_false(src.contains("dot(move_dir) > 80.0"),
		"not 80 px past centre, which cut late hits short")


func test_the_three_grades_are_the_only_feedback_words() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for word in ["UPS!", "BAGUS!", "SEMPURNA!"]:
		assert_true(src.contains("\"%s\"" % word), word + " is shown")
	for old in ["PERFECT!", "GOOD!", "MISS!", "WRONG SWIPE!", "TOO EARLY!"]:
		assert_false(src.contains("\"%s\"" % old), old + " is retired")


func test_every_failure_shows_ups() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("grade_for_distance(min_dist, sempurna_window_px, bagus_window_px)"),
		"a swipe is graded by the two windows")
	assert_true(src.contains("GRADE_TEXT[Grade.UPS]"), "a note that slips past says UPS!")
