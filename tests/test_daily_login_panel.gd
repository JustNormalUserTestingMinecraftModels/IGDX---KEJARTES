@tool
extends McpTestSuite

## DailyLoginPanel (2026-09-28 daily-login polish, Task 1): the Lobby's
## daily-login popup as its own component. Pins the streak rules (the day
## after 7 is 1; a missed day breaks the streak) and the claim's GameState
## writes (money, date, advanced day; a second claim the same day is a
## no-op), plus a source scan that the Lobby no longer owns any of it.
##
## Suite is @tool and no test is a coroutine, per the runner constraints.
## The panel under test is a bare DailyLoginPanel.new() that never enters
## the tree, so its @onready % lookups never run: claim() and the static
## rules touch no node.

const _LOBBY_SCRIPT := "res://Scripts/Lobby/Lobby.gd"
const _PANEL_SCRIPT := "res://Scripts/Lobby/DailyLoginPanel.gd"
const _TODAY := "2026-09-28"
const _YESTERDAY := "2026-09-27"
const _TWO_DAYS_AGO := "2026-09-26"


func suite_name() -> String:
	return "daily_login_panel"


var _panel: DailyLoginPanel
var _saved_money: int
var _saved_day: int
var _saved_date: String


## One bare panel for the whole suite. Not tracked; suite_teardown frees it.
func suite_setup(_ctx: Dictionary) -> void:
	_panel = DailyLoginPanel.new()


func suite_teardown() -> void:
	if is_instance_valid(_panel):
		_panel.free()
	_panel = null


func setup() -> void:
	_saved_money = GameState.player_money
	_saved_day = GameState.daily_login_day
	_saved_date = GameState.last_claim_date


func teardown() -> void:
	GameState.player_money = _saved_money
	GameState.daily_login_day = _saved_day
	GameState.last_claim_date = _saved_date


func test_day_after_wraps() -> void:
	for day in range(1, DailyLoginPanel.STREAK_DAYS):
		assert_eq(DailyLoginPanel.day_after(day), day + 1,
			"the day after %d is %d" % [day, day + 1])
	assert_eq(DailyLoginPanel.day_after(DailyLoginPanel.STREAK_DAYS), 1,
		"the day after the last streak day wraps to day 1")


func test_streak_breaks_only_after_a_missed_day() -> void:
	assert_true(DailyLoginPanel.is_streak_broken(_TWO_DAYS_AGO, _TODAY),
		"a whole missed day breaks the streak")
	assert_false(DailyLoginPanel.is_streak_broken(_YESTERDAY, _TODAY),
		"claiming yesterday keeps the streak")
	assert_false(DailyLoginPanel.is_streak_broken("", _TODAY),
		"no claim yet is not a broken streak")
	assert_false(DailyLoginPanel.is_streak_broken(_TODAY, _TODAY),
		"a claim today is not a broken streak")


func test_claim_pays_and_advances() -> void:
	GameState.daily_login_day = 3
	GameState.last_claim_date = _YESTERDAY
	var before: int = GameState.player_money
	var paid: int = _panel.claim(_TODAY)
	assert_eq(paid, DailyLoginPanel.DAILY_REWARD, "a claim pays the daily reward")
	assert_eq(paid, 10, "the flat reward is 10G until the reward curve lands")
	assert_eq(GameState.player_money, before + paid, "the reward lands in the wallet")
	assert_eq(GameState.daily_login_day, 4, "the streak advances a day")
	assert_eq(GameState.last_claim_date, _TODAY, "the claim date is today")


func test_second_claim_same_day_is_a_no_op() -> void:
	GameState.daily_login_day = 3
	GameState.last_claim_date = _YESTERDAY
	_panel.claim(_TODAY)
	var money: int = GameState.player_money
	var day: int = GameState.daily_login_day
	assert_eq(_panel.claim(_TODAY), 0, "a second claim today pays nothing")
	assert_eq(GameState.player_money, money, "the wallet is untouched")
	assert_eq(GameState.daily_login_day, day, "the streak does not advance twice")
	assert_eq(GameState.last_claim_date, _TODAY, "the claim date stays today")


func test_day_panels_cover_the_streak() -> void:
	assert_eq(DailyLoginPanel.DAY_PANELS.size(), DailyLoginPanel.STREAK_DAYS,
		"one panel frame per streak day")


func test_lobby_no_longer_owns_the_claim() -> void:
	var lobby_src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	for moved: String in ["_on_claim_pressed", "DAILY_REWARD", "DAY_PANELS",
			"CLAIMED_CUE_DIM_ALPHA", "_check_daily_login_reset",
			"_update_daily_login_visual", "GameState.player_money +="]:
		assert_false(lobby_src.contains(moved),
			"Lobby.gd still holds %s; the claim is the panel's" % moved)
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT)
	assert_true(panel_src.contains("claimed.emit("),
		"the panel announces a payout rather than reaching into the Lobby")
	assert_false(panel_src.contains("money_label"),
		"the panel never touches the Lobby's wallet label")
