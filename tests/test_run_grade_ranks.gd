@tool
extends McpTestSuiteCompat

## The run's letter grade, collapsed from ten +/- bands to five ranks
## with badge art -- S at the top, D always on a failed run.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "run_grade_ranks"


const SCRIPT_PATH := "res://Scripts/EndGame/RunGrade.gd"
const RESULT_SCRIPT := "res://Scripts/EndGame/RunResult.gd"
const SCENE_PATH := "res://Scenes/EndGame/RunResult.tscn"


func test_there_are_exactly_five_ranks() -> void:
	var seen := {}
	for s in [100.0, 92.0, 90.0, 80.0, 75.0, 62.0, 60.0, 50.0, 45.0, 20.0, 0.0]:
		seen[RunGrade.letter(s, true)] = true
	var ranks: Array = seen.keys()
	ranks.sort()
	assert_eq(ranks.size(), 5, "five ranks, got %s" % str(ranks))
	for r in ["S", "A", "B", "C", "D"]:
		assert_true(seen.has(r), "rank %s must be reachable" % r)


func test_the_bands_sit_where_the_spec_put_them() -> void:
	assert_eq(RunGrade.letter(90.0, true), "S", "90 is the S floor")
	assert_eq(RunGrade.letter(89.9, true), "A", "just under it is an A")
	assert_eq(RunGrade.letter(75.0, true), "A", "75 is the A floor")
	assert_eq(RunGrade.letter(74.9, true), "B", "just under it is a B")
	assert_eq(RunGrade.letter(60.0, true), "B", "60 is the B floor")
	assert_eq(RunGrade.letter(59.9, true), "C", "just under it is a C")
	assert_eq(RunGrade.letter(45.0, true), "C", "45 is the C floor")
	assert_eq(RunGrade.letter(44.9, true), "D", "below that is a D")


## Unchanged rule, restated because it is the one the player feels: the
## letter rewards winning well, it is not a consolation for losing.
func test_a_failed_run_is_always_d_however_well_it_scored() -> void:
	assert_eq(RunGrade.letter(100.0, false), "D",
		"a perfect score on a failed run is still a D")


func test_the_plus_minus_bands_are_gone() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in ["\"A+\"", "\"A-\"", "\"B+\"", "\"B-\"", "\"C+\"", "\"C-\""]:
		assert_false(src.contains(retired),
			"%s is superseded by the five-rank scheme" % retired)


func test_s_and_a_are_the_top_grades() -> void:
	assert_true(RunGrade.is_top_grade("S"), "S is a top grade")
	assert_true(RunGrade.is_top_grade("A"), "so is A")
	assert_false(RunGrade.is_top_grade("B"), "B is not")
	assert_false(RunGrade.is_top_grade("D"), "and D certainly is not")


func test_every_rank_has_a_caption() -> void:
	var src := FileAccess.get_file_as_string(RESULT_SCRIPT)
	var from := src.find("const GRADE_CAPTIONS")
	var to := src.find("}", from)
	var body := src.substr(from, to - from)
	for r in ["S", "A", "B", "C", "D"]:
		assert_true(body.contains("\"%s\":" % r),
			"rank %s needs a caption" % r)


## The badge art draws the letter and a RANK ribbon itself, so a text
## label beside it would just repeat it.
##
## Resolve everything to bools BEFORE freeing: a freed Object reference
## compares equal to null in GDScript, so `assert_not_null` on it would
## wrongly pass, and `is` on a freed instance is a hard script error that
## aborts the whole test (test_report_card.gd:139-142 and
## test_run_result.gd:242-244 hit the same hazard). Casting with `as`
## resolves both existence and type in one step: the cast is null if the
## node is missing OR if it is the wrong type (e.g. a Label), so
## `badge_is_texture_rect` still fails the way a direct `is` check would.
func test_the_grade_is_a_badge_not_a_letter_label() -> void:
	var screen = load(SCENE_PATH).instantiate()
	var stack := "MarginContainer/Column/GradeCard/GradeStack"
	var badge_node = screen.get_node_or_null("%s/GradeBadge" % stack)
	var old_label = screen.get_node_or_null("%s/GradeLetter" % stack)
	var badge_exists: bool = badge_node != null
	var badge_is_texture_rect: bool = (badge_node as TextureRect) != null
	var old_label_gone: bool = old_label == null
	screen.free()
	assert_true(badge_exists, "GradeBadge must exist")
	assert_true(badge_is_texture_rect, "and be a TextureRect, never a Label")
	assert_true(old_label_gone,
		"GradeLetter is retired -- the badge draws its own letter")


func test_all_five_badges_are_inspector_assignable() -> void:
	var screen = load(SCENE_PATH).instantiate()
	var missing: Array[String] = []
	for r in ["s", "a", "b", "c", "d"]:
		if screen.get("rank_badge_%s" % r) == null:
			missing.append(r)
	screen.free()
	assert_eq(missing.size(), 0,
		"every rank badge must be assigned in the Inspector, missing: %s"
			% str(missing))
