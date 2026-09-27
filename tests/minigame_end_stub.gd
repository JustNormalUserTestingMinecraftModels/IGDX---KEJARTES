@tool
extends "res://Scripts/Minigames/UI/BaseMinigame.gd"

## Test helper, not a suite: the smallest possible BaseMinigame.
##
## The shipping minigames are not @tool, so the editor hands a test a
## PLACEHOLDER instance and every `call("win_game")` fails with "Attempt to
## call a method on a placeholder instance" (CLAUDE.md, Testing constraint 3).
## Declaring @tool here makes the instance real, so the inherited end calls
## actually run and tests/test_minigame_single_result.gd can drive them.
##
## It carries no scene of its own. `result_popup_scene` is the only thing
## _show_result_overlay() needs that a bare instance lacks, and the suite
## assigns it.
