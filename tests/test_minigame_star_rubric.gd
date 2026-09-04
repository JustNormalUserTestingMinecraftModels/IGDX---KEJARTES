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
## Must be @tool; no test here may be a coroutine. BaseMinigame.gd is
## deliberately NOT @tool, so every method call on a live instance of it
## fails in this editor-hosted runner ("placeholder instance") even inside
## the scene tree -- confirmed empirically before this suite was written.
## Every test below therefore calls the class's static helpers directly,
## with no instantiation at all.

func suite_name() -> String:
	return "minigame_star_rubric"


const BASE_PATH := "res://Scripts/Minigames/UI/BaseMinigame.gd"


func test_a_loss_is_always_zero_stars() -> void:
	assert_eq(BaseMinigame._calculate_stars(1.0, false), 0, "a loss earns no stars")
	assert_eq(BaseMinigame._calculate_stars(-1.0, false), 0,
		"a loss with no ratio earns no stars")


func test_a_perfect_ratio_earns_three_stars() -> void:
	assert_eq(BaseMinigame._calculate_stars(1.0, true), 3, "100% mastery is three stars")
	assert_eq(BaseMinigame._calculate_stars(0.92, true), 3, "at the three-star threshold")


func test_a_middling_ratio_earns_two_stars() -> void:
	assert_eq(BaseMinigame._calculate_stars(0.7, true), 2, "70% mastery is two stars")


func test_a_bare_win_earns_one_star() -> void:
	assert_eq(BaseMinigame._calculate_stars(0.2, true), 1, "a scraped win is one star")


## The regression this whole task exists for.
func test_a_win_with_no_tracked_ratio_is_not_capped_at_one_star() -> void:
	assert_eq(BaseMinigame._calculate_stars(-1.0, true), 2,
		"a win the game cannot rate must not read as the worst possible win")


func test_ratio_from_score_uses_max_score_when_present() -> void:
	assert_true(absf(BaseMinigame._ratio_from_score(3, 4) - 0.75) < 0.001,
		"score over max_score")


func test_ratio_from_score_is_unknown_without_a_real_max_score() -> void:
	assert_true(absf(BaseMinigame._ratio_from_score(0, 0) - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"a game that tracks nothing reports no ratio rather than a fake zero")
	assert_true(absf(BaseMinigame._ratio_from_score(0, -1) - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"a negative max_score is also 'no real max'")


func test_ratio_from_score_clamps_to_one() -> void:
	assert_true(absf(BaseMinigame._ratio_from_score(9, 3) - 1.0) < 0.001,
		"a score above max_score still clamps to a perfect ratio, never over 1.0")


func test_get_star_ratio_is_thin_glue_over_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	assert_true(src.contains("_ratio_from_score("),
		"get_star_ratio() delegates its math to the static helper rather than "
		+ "re-deriving it, so every override can reuse the same pattern")


func test_calculate_stars_is_static_and_no_longer_takes_a_max_score() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	assert_true(src.contains("static func _calculate_stars(ratio: float, is_win: bool) -> int:"),
		"the rubric takes a ratio, not a (score, max_score) pair, and is static "
		+ "so every minigame test can call it without instantiating a live node")
	assert_false(src.contains("return 1  # Win with no score tracking = 1 star minimum"),
		"the one-star cap is gone")


func test_thresholds_are_named_constants() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	for name in ["STAR_RATIO_THREE", "STAR_RATIO_TWO", "STAR_UNRATED_DEFAULT"]:
		assert_true(src.contains("const %s" % name), "%s is a named const" % name)


const MAINBOLA_PATH := "res://Scripts/Minigames/Olahraga/MainBola.gd"
## MainBola.gd declares no class_name, so its static helper is reached
## through this preloaded Script reference rather than a bare identifier --
## `MainBola.foo()` fails to parse ("Identifier not declared"); a preloaded
## Script const resolves statics fine with no class_name required. Confirmed
## empirically before this was written.
const MainBolaScript := preload("res://Scripts/Minigames/Olahraga/MainBola.gd")


func test_mainbola_rates_a_flawless_striker_at_three_stars() -> void:
	# 5 goals from 5 shots is perfect.
	assert_true(absf(MainBolaScript._shot_accuracy_ratio(5, 5) - 1.0) < 0.001,
		"5 goals from 5 shots is perfect")
	assert_eq(BaseMinigame._calculate_stars(MainBolaScript._shot_accuracy_ratio(5, 5), true), 3,
		"and earns three stars")


func test_mainbola_rates_a_wasteful_striker_lower() -> void:
	# 4 goals from 8 shots.
	assert_true(absf(MainBolaScript._shot_accuracy_ratio(4, 8) - 0.5) < 0.001,
		"4 goals from 8 shots")
	assert_eq(BaseMinigame._calculate_stars(MainBolaScript._shot_accuracy_ratio(4, 8), true), 1,
		"a scraped win is one star")


func test_mainbola_reports_unknown_before_any_shot() -> void:
	assert_true(absf(MainBolaScript._shot_accuracy_ratio(0, 0) - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"no shots taken means no accuracy to divide by")


func test_mainbola_get_star_ratio_delegates_to_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(MAINBOLA_PATH)
	assert_true(src.contains("_shot_accuracy_ratio("),
		"get_star_ratio() calls the static helper rather than re-deriving the math")


const MENARI_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
## LombaMenari.gd declares no class_name -- see MainBolaScript's comment in
## this same suite for why a preloaded Script const is used instead of the
## bare class name.
const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")


func test_menari_rates_an_all_perfect_routine_at_three_stars() -> void:
	var ratio := MenariScript._note_accuracy_ratio(20, 0, 0)
	assert_true(absf(ratio - 1.0) < 0.001, "every note PERFECT")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 3, "and earns three stars")


func test_menari_rates_a_half_good_half_missed_routine_lower() -> void:
	# 10 good hits = 500 points of a possible 2000
	var ratio := MenariScript._note_accuracy_ratio(0, 10, 10)
	assert_true(absf(ratio - 0.25) < 0.001, "half the notes at half credit")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 1, "a sloppy win is one star")


func test_menari_reports_unknown_before_a_single_note() -> void:
	var ratio := MenariScript._note_accuracy_ratio(0, 0, 0)
	assert_true(absf(ratio - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"no notes presented means nothing to rate")


func test_menari_get_star_ratio_delegates_to_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(MENARI_PATH)
	assert_true(src.contains("_note_accuracy_ratio("),
		"get_star_ratio() calls the static helper rather than re-deriving the math")


const BADMINTON_PATH := "res://Scripts/Minigames/Olahraga/Badminton.gd"
## Badminton.gd declares no class_name -- see MainBolaScript's comment in
## Task 2's test additions for why a preloaded Script const is used instead
## of the bare class name.
const BadmintonScript := preload("res://Scripts/Minigames/Olahraga/Badminton.gd")


func test_badminton_rates_a_shutout_at_three_stars() -> void:
	var ratio := BadmintonScript._rally_margin_ratio(7, 0)
	assert_true(absf(ratio - 1.0) < 0.001, "a shutout is perfect")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 3, "and earns three stars")


func test_badminton_rates_a_narrow_win_lower() -> void:
	var ratio := BadmintonScript._rally_margin_ratio(7, 6)
	assert_true(absf(ratio - (7.0 / 13.0)) < 0.001, "a 7-6 grind")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 1, "and is one star")


func test_badminton_reports_unknown_before_any_rally() -> void:
	var ratio := BadmintonScript._rally_margin_ratio(0, 0)
	assert_true(absf(ratio - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"no rallies played means nothing to rate")


func test_badminton_get_star_ratio_delegates_to_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("_rally_margin_ratio("),
		"get_star_ratio() calls the static helper rather than re-deriving the math")


func test_badminton_declares_score_and_max_score_mirrors() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("var score: int = 0"),
		"score mirrors player_score so the result card can show a score row")
	assert_true(src.contains("var max_score: int = 0"),
		"max_score mirrors the rally target")


func test_badminton_sync_score_alias_assigns_both_mirrors() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("func sync_score_alias() -> void:"),
		"the mirror-sync method exists")
	var body: String = src.split("func sync_score_alias() -> void:")[1].split("\nfunc ")[0]
	assert_true(body.contains("score = player_score"), "score mirrors player_score")
	assert_true(body.contains("max_score = target_score"), "max_score mirrors target_score")


func test_badminton_calls_sync_score_alias_on_every_rally_point_and_at_game_end() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	var call_count: int = src.count("sync_score_alias()") - 1   # subtract the func's own declaration line
	assert_gt(call_count, 3,
		"sync_score_alias() should be called at both score sites, in both "
		+ "win_game() and lose_game(), and once on reset -- five call sites beyond "
		+ "the declaration, so more than 3")
