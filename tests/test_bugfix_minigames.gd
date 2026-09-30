@tool
extends McpTestSuite

## Regressions for the 2026-09-30 minigame bug sweep: each test pins one
## verified defect so it cannot come back.
##
## - Badminton promoted a lost match to a win through BaseMinigame's
##   score-versus-get_target_win_score() shortcut.
## - Lomba Menari's notes kept flying, and counting misses, through the resume
##   countdown while swipes were off.
## - Keluar after an end sequence had started left the minigame DISABLED.
## - Menjodohkan ignored the grade-scaled clock SchoolDay passes.
## - MainBola's out-of-shots loss showed the card without ending the game,
##   and a winning goal in the last 0.35 s ended as a loss.
##
## The shipping minigames are not @tool, so most checks are source scans; the
## abandon check drives tests/minigame_end_stub.gd, a real BaseMinigame.
## Must be @tool; no test here may be a coroutine.

## Badminton's script, scanned for its lose_game() override.
const BADMINTON_PATH := "res://Scripts/Minigames/Olahraga/Badminton.gd"
## Lomba Menari's script, scanned for its _process() pause guard.
const MENARI_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
## Menjodohkan's script, scanned for its start_minigame() forwarding.
const MENJODOHKAN_PATH := "res://Scripts/Minigames/Akademis/Menjodohkan.gd"
## MainBola's script, scanned for its goal and out-of-shots endings.
const MAIN_BOLA_PATH := "res://Scripts/Minigames/Olahraga/MainBola.gd"
## The smallest real BaseMinigame (@tool, so its methods run in the editor).
const EndStub := preload("res://tests/minigame_end_stub.gd")


func suite_name() -> String:
	return "bugfix_minigames"


## The text of `path`'s function `signature`, up to the next column-0 func,
## or "" when the script has no such function.
func _function_body(path: String, signature: String) -> String:
	var src := FileAccess.get_file_as_string(path)
	var at := src.find(signature)
	if at == -1:
		return ""
	var body := src.substr(at)
	var next := body.find("\nfunc ", 1)
	return body if next == -1 else body.substr(0, next)


func test_badminton_does_not_promote_a_loss_to_a_win() -> void:
	var lose := _function_body(BADMINTON_PATH, "func lose_game(")
	assert_false(lose.is_empty(), "Badminton overrides lose_game()")
	assert_false(lose.contains("super"), "without calling the base's score shortcut")
	assert_false(lose.contains("win_game"), "and without any route to a win")
	assert_true(lose.contains("_show_result_overlay(false"), "it shows the loss card")
	assert_true(lose.contains("if not is_game_active:"), "and shows it once")


func test_menari_notes_hold_still_through_the_resume_countdown() -> void:
	var process := _function_body(MENARI_PATH, "func _process(")
	var guard := process.find("if not is_game_active or is_paused:")
	assert_true(guard != -1, "_process stops while is_paused, which spans the countdown")
	assert_true(guard < process.find("time_elapsed += delta"),
		"before any note spawns, moves or counts a miss")


func test_abandon_unfreezes_an_end_sequence_already_in_flight() -> void:
	var mg: Node = EndStub.new()
	track(mg)
	mg.set("is_game_active", false)
	mg.set("is_paused", true)
	mg.process_mode = Node.PROCESS_MODE_DISABLED
	mg.call("abandon_game")
	assert_eq(mg.process_mode, Node.PROCESS_MODE_INHERIT,
		"the pause's DISABLED mode is lifted so the reveal can finish")
	assert_false(bool(mg.get("is_paused")), "and the game no longer reads as paused")
	assert_eq(mg.get_child_count(), 0, "the in-flight sequence shows its own card, not a second one")


func test_menjodohkan_honours_the_clock_it_is_given() -> void:
	var start := _function_body(MENJODOHKAN_PATH, "func start_minigame(")
	assert_true(start.contains("super.start_minigame(game_difficulty, time_limit)"),
		"the grade-scaled time limit reaches the base")
	assert_false(start.contains("super.start_minigame(game_difficulty, 40.0)"),
		"no hard-coded 40 s override")


func test_main_bola_out_of_shots_ends_through_lose_game() -> void:
	var out := _function_body(MAIN_BOLA_PATH, "func _end_if_out_of_shots(")
	assert_true(out.contains("lose_game()"), "running out of shots ends the game properly")
	assert_false(out.contains("_show_result_overlay"), "not just the card over a live game")
	var missed := _function_body(MAIN_BOLA_PATH, "func _on_shot_missed(")
	assert_true(missed.contains("_end_if_out_of_shots()"), "a last miss checks it")
	var goal := _function_body(MAIN_BOLA_PATH, "func _on_goal_scored(")
	assert_true(goal.contains("_end_if_out_of_shots()"),
		"and so does a last goal short of the target")


func test_main_bola_winning_goal_is_decided_before_the_pause() -> void:
	var goal := _function_body(MAIN_BOLA_PATH, "func _on_goal_scored(")
	var decided := goal.find("is_game_active = false")
	var paused := goal.find("create_timer(")
	assert_true(decided != -1 and paused != -1, "both steps are present")
	assert_true(decided < paused,
		"the win stops the clock before the pacing pause, so a buzzer there cannot lose it")
	assert_true(goal.contains("win_game()"), "and the goal still ends on the win card")
