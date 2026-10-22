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
## - Variabel's and Password's Kirim handler resumed after a timer await
##   during which a wrong answer's penalty (or the clock) had ended the game,
##   calling get_tree() on a freed minigame.
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
## Variabel's script, scanned for its Kirim handler's await guards.
const VARIABEL_PATH := "res://Scripts/Minigames/Akademis/Variabel.gd"
## Password's script, scanned for its Kirim handler's await guards.
const PASSWORD_PATH := "res://Scripts/Minigames/Akademis/Password.gd"
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


func test_badminton_enemy_keeps_distance_when_the_player_crowds_the_net() -> void:
	var badminton := load(BADMINTON_PATH)
	var h := 1920.0
	var free_limit: float = badminton.enemy_forward_limit(h * 0.8, h)
	var net_limit: float = badminton.enemy_forward_limit(h * 0.5, h)
	var mid_limit: float = badminton.enemy_forward_limit(h * 0.575, h)
	assert_true(absf(free_limit - (732.0 - 48.0)) < 0.01,
		"a far player leaves the enemy up to its short service line, got %s" % free_limit)
	assert_true(absf(net_limit - h * 0.14) < 0.01, "a player at the net pushes the enemy to the retreat line")
	assert_true(net_limit < mid_limit and mid_limit < free_limit, "the retreat eases out as the player backs off")
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("enemy_forward_limit(player_paddle.global_position.y"),
		"the enemy AI clamps its target to that limit")


func test_badminton_enemy_never_crosses_its_service_line() -> void:
	var badminton := load(BADMINTON_PATH)
	# A 20:9 phone: the court art covers 2400 px, so the line moves with it.
	var tall_line: float = badminton.enemy_service_line_y(2400.0)
	assert_true(absf(tall_line - (2400.0 * 732.0 / 1920.0 - 48.0)) < 0.01,
		"the service line follows the covered court art, got %s" % tall_line)
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("enemy_paddle.global_position.y = minf(enemy_paddle.global_position.y,"),
		"the racket is hard-stopped at the line after it moves, not only aimed short of it")


func test_badminton_enemy_is_a_quarter_less_precise() -> void:
	var badminton := load(BADMINTON_PATH)
	assert_true(is_equal_approx(badminton.ENEMY_PRECISION, 0.75), "the enemy tracks at 75% of the original AI")
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("max_speed *= ENEMY_PRECISION"), "its top speed is scaled")
	assert_true(src.contains("diff_x / delta * 0.15 * ENEMY_PRECISION"), "and its follow gain")


func test_badminton_pop_out_leaves_the_wall_towards_the_other_half() -> void:
	var badminton := load(BADMINTON_PATH)
	var screen := Vector2(1080.0, 1920.0)
	var from_player_left: Vector2 = badminton.pop_heading(Vector2(100.0, 1500.0), screen)
	var from_enemy_right: Vector2 = badminton.pop_heading(Vector2(980.0, 400.0), screen)
	assert_true(from_player_left.y < 0.0 and from_player_left.x > 0.0, "pinned left in the player's half: up and inward")
	assert_true(from_enemy_right.y > 0.0 and from_enemy_right.x < 0.0, "pinned right in the enemy's half: down and inward")
	assert_true(absf(from_player_left.length() - 1.0) < 0.001, "the heading is a unit vector")


func test_badminton_rackets_cannot_squeeze_or_stall_on_anything() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	var setup := _function_body(BADMINTON_PATH, "func _setup_rackets(")
	assert_true(setup.contains("collision_layer = 0") and setup.contains("collision_mask = 0"),
		"both rackets leave the physics board, so nothing blocks them and the shuttle cannot be squeezed")
	var physics := _function_body(BADMINTON_PATH, "func _physics_process(")
	assert_true(physics.contains("player_paddle.global_position = player_target_pos"),
		"the player's racket is set exactly under the finger")
	assert_false(src.contains("max_paddle_speed"), "with no speed cap to lag behind it")
	var input := _function_body(BADMINTON_PATH, "func _input(")
	assert_true(input.contains("player_paddle.global_position = player_target_pos"),
		"a press jumps the racket under the finger, so the hit sweep never starts from the old spot")
	assert_true(physics.contains("_check_racket_hits(") and physics.contains("_watch_for_pin("),
		"hits are swept for and a pinned shuttle is watched for every physics frame")


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


## Asserts every timer await in `body` is followed, past the line restoring
## is_paused, by a _round_still_live() bail-out.
func _assert_awaits_guarded(body: String, label: String) -> void:
	var lines := body.split("\n")
	var awaits := 0
	for i in lines.size():
		if not lines[i].contains("await get_tree().create_timer("):
			continue
		awaits += 1
		var next := ""
		for j in range(i + 1, lines.size()):
			var line := lines[j].strip_edges()
			if line != "" and not line.begins_with("is_paused"):
				next = line
				break
		assert_eq(next, "if not _round_still_live():",
			"%s: the await on handler line %d re-checks the round" % [label, i + 1])
	assert_true(awaits > 0, "%s: the handler still waits on a timer" % label)


func test_kalkulator_kirim_stops_once_the_round_has_ended() -> void:
	_assert_awaits_guarded(_function_body(VARIABEL_PATH, "func _on_submit_pressed("), "Variabel")
	_assert_awaits_guarded(_function_body(PASSWORD_PATH, "func _on_enter_pressed("), "Password")
