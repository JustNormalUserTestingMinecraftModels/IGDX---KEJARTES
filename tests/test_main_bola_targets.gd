@tool
extends McpTestSuite

## MainBola shipped Kelas 9 games that could not be won. Every game gave eight
## shots and refunded none, while start_minigame() rolled Kelas 9's goal
## target as 8, 9 or 10 (Kelas 8's as 6-8): two Kelas 9 games in three asked
## for more goals than there were shots, and the third needed eight from eight.
##
## Since 2026-09-14 each difficulty has its own shot count and target range,
## in two tables in MainBola.gd. This suite holds the rule those tables must
## keep: the highest target a game can roll still leaves shots to miss.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "main_bola_targets"


## MainBola.gd declares no class_name, so it is reached through a preloaded
## const, as tests/test_minigame_star_rubric.gd does.
const MainBolaScript := preload("res://Scripts/Minigames/Olahraga/MainBola.gd")

## Every difficulty start_minigame() can be handed. SchoolDay passes
## clampi(current_grade - 6, 1, 3), so 1 is Kelas 7 and 3 is Kelas 9. 0 and 4
## never arrive from SchoolDay, and must play as 1 and 3, as they always have.
const DIFFICULTIES: Array[int] = [0, 1, 2, 3, 4]

## Shots a game at its highest target can still afford to miss -- the
## balance decision of 2026-09-14. Kelas 7 already had exactly two: six goals
## from eight shots.
const MIN_SPARE_SHOTS := 2

## Games started per difficulty by the rolling tests. Each target range is
## three values wide, so the odds of never rolling its top in 60 starts are
## (2/3)^60, about 3e-11.
const STARTS_PER_DIFFICULTY := 60


func test_the_highest_target_never_exceeds_the_shots_at_any_difficulty() -> void:
	for d in DIFFICULTIES:
		var highest: int = MainBolaScript.target_range_for(d).y
		var shots: int = MainBolaScript.attempts_for(d)
		assert_true(highest <= shots,
			"difficulty %d can roll a %d-goal target with only %d shots -- that game cannot be won"
			% [d, highest, shots])


func test_the_highest_target_leaves_shots_to_miss() -> void:
	for d in DIFFICULTIES:
		var highest: int = MainBolaScript.target_range_for(d).y
		var shots: int = MainBolaScript.attempts_for(d)
		assert_true(highest + MIN_SPARE_SHOTS <= shots,
			"difficulty %d: a %d-goal target from %d shots leaves %d to miss, wants at least %d"
			% [d, highest, shots, shots - highest, MIN_SPARE_SHOTS])


## The tables only matter if start_minigame() reads them. This drives the real
## function rather than the helpers, so it fails if the start path rolls its
## own target or hands every difficulty the same shots.
func test_a_started_game_never_asks_for_more_goals_than_it_can_spare() -> void:
	for d in DIFFICULTIES:
		var game := MainBolaScript.new()
		track(game)
		for _start in STARTS_PER_DIFFICULTY:
			game.start_minigame(d, 0.0)
			assert_true(game.target_score + MIN_SPARE_SHOTS <= game.attempts_left,
				"difficulty %d started a %d-goal game with %d shots"
				% [d, game.target_score, game.attempts_left])


## Stars rate goals per shot taken, and shots taken counts down from the shots
## THIS game started with. Counting from a fixed eight rates a ten-shot Kelas 9
## game on the wrong number of shots.
func test_the_star_ratio_counts_the_shots_this_game_took() -> void:
	for d in DIFFICULTIES:
		var game := MainBolaScript.new()
		track(game)
		game.start_minigame(d, 0.0)
		game.score = 3
		game.attempts_left -= 6
		assert_true(absf(game.get_star_ratio() - 0.5) < 0.001,
			"difficulty %d: 3 goals from 6 shots should rate 0.5, got %.3f"
			% [d, game.get_star_ratio()])
