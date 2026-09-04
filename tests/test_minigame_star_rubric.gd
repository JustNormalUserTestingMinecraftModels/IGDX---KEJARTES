@tool
extends McpTestSuite

## The end-of-minigame star rubric.
##
## Before 2026-09-04, _calculate_stars() read `max_score`, which only the four
## Akademis quizzes declare. MainBola, LombaMenari, Badminton and BuatBatik fell
## through the `max_score <= 0` branch and were hard-capped at one star on every
## win, however perfect the run. This suite pins the replacement rubric: a
## per-game mastery ratio via get_star_ratio(), and a never-one-star floor for a
## win that reports no ratio at all.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_star_rubric"


const BASE_PATH := "res://Scripts/Minigames/UI/BaseMinigame.gd"


## _calculate_stars is a pure function on the script, so the suite exercises it
## on a bare instance -- no scene, no viewport, no tree.
func _base() -> Node:
	var node: Node = Node.new()
	node.set_script(load(BASE_PATH))
	track(node)
	return node


func test_a_loss_is_always_zero_stars() -> void:
	var b := _base()
	assert_eq(b._calculate_stars(1.0, false), 0, "a loss earns no stars")
	assert_eq(b._calculate_stars(-1.0, false), 0, "a loss with no ratio earns no stars")


func test_a_perfect_ratio_earns_three_stars() -> void:
	var b := _base()
	assert_eq(b._calculate_stars(1.0, true), 3, "100% mastery is three stars")
	assert_eq(b._calculate_stars(0.92, true), 3, "at the three-star threshold")


func test_a_middling_ratio_earns_two_stars() -> void:
	var b := _base()
	assert_eq(b._calculate_stars(0.7, true), 2, "70% mastery is two stars")


func test_a_bare_win_earns_one_star() -> void:
	var b := _base()
	assert_eq(b._calculate_stars(0.2, true), 1, "a scraped win is one star")


## The regression this whole task exists for.
func test_a_win_with_no_tracked_ratio_is_not_capped_at_one_star() -> void:
	var b := _base()
	assert_eq(b._calculate_stars(-1.0, true), 2,
		"a win the game cannot rate must not read as the worst possible win")


func test_default_get_star_ratio_uses_max_score_when_present() -> void:
	var b := _base()
	b.set("score", 3)
	b.set("max_score", 4)
	assert_true(absf(b.get_star_ratio() - (0.75)) < 0.001, "score over max_score")


func test_default_get_star_ratio_is_unknown_without_max_score() -> void:
	var b := _base()
	assert_true(absf(b.get_star_ratio() - (-1.0)) < 0.001,
		"a game that tracks nothing reports no ratio rather than a fake zero")


func test_calculate_stars_no_longer_takes_a_max_score() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	assert_true(src.contains("func _calculate_stars(ratio: float, is_win: bool) -> int:"),
		"the rubric takes a ratio, not a (score, max_score) pair")
	assert_false(src.contains("return 1  # Win with no score tracking = 1 star minimum"),
		"the one-star cap is gone")


func test_thresholds_are_named_constants() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	for name in ["STAR_RATIO_THREE", "STAR_RATIO_TWO", "STAR_UNRATED_DEFAULT"]:
		assert_true(src.contains("const %s" % name), "%s is a named const" % name)
