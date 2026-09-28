@tool
extends McpTestSuite

## Dapatkan Uang (2026-09-27 scrapbook HUD spec §7, Phase 2): the earn-money
## panel the Lobby's coin "+" opens, its dev-mode payouts, and the
## session-scoped GameState.ad_debt the "ambil dulu" cash-ins run up.

const _GAME_STATE := "res://Scripts/GameState.gd"


func suite_name() -> String:
	return "dapatkan_uang"


## A source scan, not a call: forget_session() in the editor would also wipe
## achievement progress.
func test_ad_debt_is_a_session_counter() -> void:
	var src := FileAccess.get_file_as_string(_GAME_STATE)
	assert_true(src.contains("var ad_debt: int = 0"), "ad_debt is a typed int, 0 at start")
	var forget: String = src.get_slice("func forget_session()", 1).get_slice("\nfunc ", 0)
	assert_true(forget.contains("ad_debt = 0"), "Forget Session clears it")
	var saver: String = src.get_slice("func _write_inventory_to(", 1).get_slice("\nfunc ", 0)
	assert_false(saver.contains("ad_debt"), "ad_debt never reaches disk")
