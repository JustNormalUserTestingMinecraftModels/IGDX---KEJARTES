@tool
extends McpTestSuite

## MainBola's shots (2026-09-15): an off-target shot always ends in the
## keeper's hands, and the target box jumps to a new spot after every goal.
## pick_respawn() is pure and tested with a seeded generator; the shot itself
## is a coroutine that cannot run in the editor, so its wiring is pinned by
## source scans, as test_main_bola_layout.gd does.
##
## Must be @tool; no test here may be a coroutine.

const SCRIPT_PATH := "res://Scripts/Minigames/Olahraga/MainBola.gd"
## MainBola.gd declares no class_name; reached through a preloaded const.
const MainBolaScript := preload("res://Scripts/Minigames/Olahraga/MainBola.gd")

## The target band at 1080x1920 with the scene's defaults: x inside the posts
## less half a box, y 20-60% down the goal mouth. GAP is one box width.
const MIN_POS := Vector2(162.0, 645.0)
const MAX_POS := Vector2(918.0, 860.0)
const GAP := 194.0


func suite_name() -> String:
	return "main_bola_shots"


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## The text of one function: from `signature` to the next top-level func.
func _body(src: String, signature: String) -> String:
	var at := src.find(signature)
	if at < 0:
		return ""
	var end := src.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var next := src.find(marker, at + 1)
		if next > 0:
			end = mini(end, next)
	return src.substr(at, end - at)


# ─── respawn

func test_a_respawn_lands_in_the_band_away_from_the_last_spot() -> void:
	var prev := Vector2(540.0, 700.0)
	for seed_value in range(200):
		var next: Vector2 = MainBolaScript.pick_respawn(prev, MIN_POS, MAX_POS, GAP, _rng(seed_value))
		assert_true(next.x >= MIN_POS.x and next.x <= MAX_POS.x, "x stays inside the goal")
		assert_true(next.y >= MIN_POS.y and next.y <= MAX_POS.y, "y stays inside the band")
		assert_true(next.distance_to(prev) >= GAP, "at least a box-width from where it was")
		prev = next


func test_a_band_too_small_for_the_gap_still_moves_as_far_as_it_can() -> void:
	var prev := Vector2(100.0, 100.0)
	var next: Vector2 = MainBolaScript.pick_respawn(
		prev, Vector2(90, 90), Vector2(110, 110), 500.0, _rng(7))
	assert_true(next.x >= 90.0 and next.x <= 110.0 and next.y >= 90.0 and next.y <= 110.0,
		"still inside the band")
	assert_ne(next, prev, "it still moves")


func test_a_seed_repeats_its_respawn() -> void:
	var a: Vector2 = MainBolaScript.pick_respawn(Vector2(540, 700), MIN_POS, MAX_POS, GAP, _rng(42))
	var b: Vector2 = MainBolaScript.pick_respawn(Vector2(540, 700), MIN_POS, MAX_POS, GAP, _rng(42))
	assert_eq(a, b, "the only randomness is the generator it is handed")


func test_every_goal_moves_the_target() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(_body(src, "func _on_goal_scored()").contains("_respawn_target()"),
		"a goal respawns the target")
	assert_true(_body(src, "func _respawn_target()").contains("pick_respawn("),
		"through the tested picker")


func test_an_aimed_shot_flies_to_the_targets_height() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("target_y_pos if aimed_at_target"),
		"a respawned target at a new height is still where the ball goes")


# ─── the keeper

func test_an_off_target_shot_sends_the_keeper_to_the_ball() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("goalie_tx = clampf(target_x, goal_left_x + 5.0, goal_right_x - 5.0)"),
		"the keeper dives to where the ball is going")
	assert_true(src.contains("ball_target = keeper_catch_point(goalie_tx)"),
		"and the ball ends in his hands")


func test_the_keeper_is_never_slower_than_the_ball() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.contains("clampf(0.35 / goalie_speed_mult, 0.18, BALL_FLIGHT_SECONDS)"),
		"the dive is capped at the ball's flight time")
	assert_false(src.contains(", 0.40)"), "the ball's flight time is one named const")


func test_the_new_knobs_are_documented_exports() -> void:
	var lines := FileAccess.get_file_as_string(SCRIPT_PATH).split("\n")
	for knob in ["target_band_top_frac", "target_band_bottom_frac", "keeper_catch_height_frac"]:
		var found := -1
		for i in range(lines.size()):
			if lines[i].strip_edges().begins_with("@export") and lines[i].contains("var " + knob):
				found = i
				break
		assert_gt(found, 0, knob + " is an @export")
		assert_true(lines[found - 1].strip_edges().begins_with("##"), knob + " has a ## doc line")
