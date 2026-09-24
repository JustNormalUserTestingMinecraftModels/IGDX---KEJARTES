@tool
extends McpTestSuite

## A minigame must show its result exactly once, however many times its end is
## triggered (2026-09-22).
##
## THE BUG THIS PINS. LombaMenari scores per swipe and ends itself inline:
##
##     if score >= target_score:
##         win_game()
##
## That runs on EVERY successful swipe, so once the score crosses the target
## the player's next note hit calls win_game() again, and the next, and the
## next. `lose_game()` and `abandon_game()` both open with
## `if not is_game_active: return`; `win_game()` did not, so each call built
## another MinigameResultPopup. A real run reached thirty of them: thirty
## CanvasLayers at 999, thirty sets of tweens, a hundred and twenty
## GPUParticles2D and thirty overlapping result fanfares. Thirty translucent
## dim overlays composite to OPAQUE BLACK, and each LANJUTKAN press dismissed
## only one of them -- the game looked frozen.
##
## WHY THE GUARD IS ON _show_result_overlay AND NOT ON win_game. The obvious
## fix -- copying lose_game()'s `if not is_game_active: return` into
## win_game() -- silently breaks the win-on-timeout path: lose_game() clears
## is_game_active at its top and THEN calls win_game() when the score cleared
## the threshold, so that guard would suppress the result entirely and hang
## the game for real. The invariant that actually holds is "the result is
## shown once", so that is what is guarded.
##
## Must be @tool, and no test here may be a coroutine -- nothing here awaits
## play(); the popup is added synchronously before play()'s first await, which
## is exactly what makes this testable.



func suite_name() -> String:
	return "minigame_single_result"



## The smallest real BaseMinigame, standing in the editor tree.
##
## It has to be the @tool stub rather than LombaMenari itself: the shipping
## minigames are not @tool, so the editor hands back a PLACEHOLDER whose
## methods cannot be called at all ("Attempt to call a method on a placeholder
## instance"). The guard under test lives in BaseMinigame and is shared by
## every minigame, so the stub tests the real thing.
func _stood_up() -> Node:
	var mg: Node = preload("res://tests/minigame_end_stub.gd").new()
	mg.result_popup_scene = load("res://Scenes/Minigames/UI/MinigameResultPopup.tscn")
	Engine.get_main_loop().root.add_child(mg)
	track(mg)
	return mg


func _popup_count(mg: Node) -> int:
	var found := 0
	for child in mg.get_children():
		var s: Script = child.get_script() as Script
		if s != null and str(s.resource_path).contains("MinigameResultPopup"):
			found += 1
	return found


## The regression itself.
func test_repeated_wins_show_one_result() -> void:
	var mg := _stood_up()
	mg.set("is_game_active", true)
	mg.call("win_game")
	assert_eq(_popup_count(mg), 1, "the first win must show a result")
	for i in 5:
		mg.call("win_game")
	assert_eq(_popup_count(mg), 1,
		"every later win must be ignored; a rhythm game calls win_game() once "
			+ "per note hit after the score crosses its target")


## The same guard has to hold whichever end call gets there first, because a
## minigame can be abandoned, time out and win in any order.
func test_a_win_after_an_abandon_does_not_stack_a_second_result() -> void:
	var mg := _stood_up()
	mg.set("is_game_active", true)
	mg.call("abandon_game")
	assert_eq(_popup_count(mg), 1, "abandoning must show a result")
	mg.set("is_game_active", true)
	mg.call("win_game")
	assert_eq(_popup_count(mg), 1, "a later win must not stack another result")


## Guards the fix that would have looked obvious and been wrong. lose_game()
## clears is_game_active before deciding the score cleared the threshold, so
## win_game() must NOT gate on that flag or the win-on-timeout path shows no
## result at all -- a real hang rather than a cosmetic one.
func test_win_game_does_not_gate_on_is_game_active() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	var at := src.find("func win_game() -> void:")
	assert_true(at != -1, "win_game must exist")
	if at == -1:
		return
	var body := src.substr(at, 240)
	assert_false(body.contains("if not is_game_active:"),
		"win_game must not gate on is_game_active: lose_game() clears it before "
			+ "routing a threshold win here, so this would suppress that result")
