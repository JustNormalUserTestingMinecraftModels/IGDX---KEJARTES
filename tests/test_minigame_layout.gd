@tool
extends McpTestSuite

## The minigame mobile layout contract (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 4, 6
## and 7): BaseMinigame's wiring and, task by task, each game's scene. Must
## be @tool; no test here may be a coroutine.

const BASE := "res://Scripts/Minigames/UI/BaseMinigame.gd"


func suite_name() -> String:
	return "minigame_layout"


func test_the_card_shows_once_per_session_and_only_when_enabled() -> void:
	var seen := {}
	assert_true(BaseMinigame.should_show_how_to(true, seen, "res://a.tres"))
	seen["res://a.tres"] = true
	assert_false(BaseMinigame.should_show_how_to(true, seen, "res://a.tres"), "seen this session")
	assert_true(BaseMinigame.should_show_how_to(true, seen, "res://b.tres"), "another game")
	assert_false(BaseMinigame.should_show_how_to(false, {}, "res://a.tres"), "setting off")
	assert_false(BaseMinigame.should_show_how_to(true, {}, ""), "a game with no card")


func test_the_countdown_runs_outside_the_tutorial_branch() -> void:
	var src := FileAccess.get_file_as_string(BASE)
	var body := src.substr(src.find("func activate_minigame"))
	body = body.substr(0, body.find("\nfunc ", 1))
	var tut_if := body.find("if should_show_how_to(")
	var countdown := body.find("await _play_countdown()")
	assert_true(tut_if != -1 and countdown != -1, "both steps are in activate_minigame")
	var branch_end := body.find("\n\tawait _play_countdown()")
	assert_true(branch_end != -1, "the countdown sits at the function's own indent, after the if")


func test_forget_session_clears_the_seen_cards() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	assert_contains(src, "var seen_minigame_how_to: Dictionary = {}")
	var forget := src.substr(src.find("func forget_session"))
	forget = forget.substr(0, forget.find("\nfunc ", 1))
	assert_contains(forget, "seen_minigame_how_to = {}")


func test_the_old_tutorial_strings_are_gone() -> void:
	var src := FileAccess.get_file_as_string(BASE)
	for gone: String in ["tutorial_title", "tutorial_instructions",
			"_get_active_tutorial_title", "_get_active_tutorial_instructions"]:
		assert_false(src.contains(gone), gone + " is retired by MinigameHowTo")
