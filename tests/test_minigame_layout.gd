@tool
extends McpTestSuite

## The minigame mobile layout contract (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 4, 6
## and 7): BaseMinigame's wiring and, task by task, each game's scene. Must
## be @tool; no test here may be a coroutine.

const BASE := "res://Scripts/Minigames/UI/BaseMinigame.gd"
const LayoutFrame := preload("res://tests/layout_frame.gd")
const PG := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"


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


## `node` sits under a SafeAreaMargin.
func _under_safe(node: Node) -> bool:
	var p := node.get_parent() if node != null else null
	while p != null and not (p is SafeAreaMargin):
		p = p.get_parent()
	return p != null


func _scene(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	track(root)
	return root


func test_pilihan_ganda_is_laid_out_in_three_bands() -> void:
	var root := _scene(PG)
	var header := root.get_node_or_null("%MinigameHeader")
	var tray := root.get_node_or_null("%MinigameTray")
	assert_true(_under_safe(header), "the strip is inside the safe area")
	assert_true(_under_safe(tray), "the tray is inside the safe area")
	var grid := root.get_node_or_null("%ChoicesGrid")
	assert_true(grid != null and grid.get_parent() == tray, "the answers live in the tray")
	assert_eq(String(root.how_to.resource_path), "res://Resources/Minigames/HowTo/PilihanGanda.tres")


func test_pilihan_ganda_answers_are_in_thumb_reach() -> void:
	var frame := track(LayoutFrame.stand_up(PG, Vector2(1080, 1920))) as Control
	var tray := frame.get_child(0).get_node("%MinigameTray") as Control
	assert_true(tray.get_global_rect().position.y >= 1920.0 * 0.45,
		"the tray starts in the bottom 55% of the frame")


func test_pilihan_ganda_no_longer_writes_the_badge() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_false(src.contains("Pertanyaan %d dari %d"), "the long badge rewrite is gone")
	assert_contains(src, "set_progress(")
