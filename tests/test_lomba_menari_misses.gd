@tool
extends McpTestSuite

## LombaMenari's miss limit (2026-09-28): the game had no clock and never
## called lose_game(), so a player who could not reach the target was stuck
## until they quit from the pause menu. Now too many notes slipping past the
## hit zone ends the run as a loss, and the last few misses warn first.
##
## Must be @tool; no test here may be a coroutine.

const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")
const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"


func suite_name() -> String:
	return "lomba_menari_misses"


func test_the_limit_tightens_with_the_grade() -> void:
	assert_eq(MenariScript.miss_limit_for(1), 10, "Kelas 7 allows ten misses")
	assert_eq(MenariScript.miss_limit_for(2), 8, "Kelas 8 allows eight")
	assert_eq(MenariScript.miss_limit_for(3), 6, "Kelas 9 allows six")


func test_an_out_of_range_difficulty_clamps_to_the_nearest_grade() -> void:
	assert_eq(MenariScript.miss_limit_for(0), 10, "below Kelas 7 reads as Kelas 7")
	assert_eq(MenariScript.miss_limit_for(5), 6, "above Kelas 9 reads as Kelas 9")


func test_a_miss_warns_only_near_the_limit() -> void:
	var warn: int = MenariScript.MISS_WARN_REMAINING
	assert_eq(MenariScript.miss_text(warn + 1), "UPS!", "plenty left: the plain word")
	assert_eq(MenariScript.miss_text(warn), "UPS!\nSisa %d" % warn, "near the end: how many are left")
	assert_eq(MenariScript.miss_text(1), "UPS!\nSisa 1", "the last one says so")
	assert_eq(MenariScript.miss_text(0), "UPS!", "the losing miss needs no count; the result card follows")


func test_running_out_of_misses_ends_the_game() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var process := src.substr(src.find("func _process("))
	process = process.substr(0, process.find("\nfunc ", 1))
	assert_true(process.contains("missed_notes >= miss_limit"), "_process checks the limit")
	assert_true(process.contains("lose_game()"), "and ends the run when it is reached")


func test_the_limit_is_set_per_run() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var start := src.substr(src.find("func start_minigame("))
	start = start.substr(0, start.find("\nfunc ", 1))
	assert_true(start.contains("miss_limit = miss_limit_for(difficulty)"),
		"start_minigame() sets the limit from the grade")


## BaseMinigame.lose_game() promotes a loss to a win whenever score reaches
## get_target_win_score() -- 1 to 3 -- which suits a quiz scored in answers
## but would turn every Menari loss (scored in hundreds) into a win.
func test_a_loss_is_not_promoted_to_a_win() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var lose := src.substr(src.find("func lose_game("))
	assert_true(src.contains("func lose_game("), "LombaMenari overrides lose_game()")
	lose = lose.substr(0, lose.find("\nfunc ", 1))
	assert_false(lose.contains("super"), "without calling the base's score shortcut")
	assert_false(lose.contains("win_game"), "and without any route to a win")
	assert_true(lose.contains("_show_result_overlay(false"), "it shows the loss card")


func test_the_how_to_card_warns_about_misses() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	var body := src.substr(src.find("func _get_active_tutorial_instructions("))
	var line := body.substr(body.find("\"LombaMenari\": return"))
	line = line.substr(0, line.find("\n"))
	assert_true(line.contains("Geser"), "Menari is played by swiping")
	assert_false(line.contains("waktu habis"), "and has no clock to beat")
	assert_true(line.contains("terlewat"), "the card warns that missed notes lose the game")
