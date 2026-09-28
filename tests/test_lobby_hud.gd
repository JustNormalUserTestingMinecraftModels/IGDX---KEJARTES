@tool
extends McpTestSuite

## LobbyProgressHeader and the coin plate (2026-09-27 scrapbook HUD, Task 3):
## the grade/week/star header at Safe/UI's top left and the restyled money
## chip at top right, still wired to DailyLoginPanel's flying reward coin.
##
## Suite is @tool and no test here is a coroutine, per the runner
## constraints. One Lobby is instanced for the whole suite in suite_setup
## (matching tests/test_daily_login_panel.gd) rather than per test, because
## instancing Lobby.tscn per test floods the deferred-call queue and can
## drop a full run. Nothing here writes scene state the tests depend on
## across tests, so a shared fixture is safe.
##
## Written against Task 3's target node tree (task-3-brief.md): until the
## [editor] scene step adds %ProgressHeader, %DisplayUang and %PlusUang to
## Lobby.tscn, these tests are expected to fail loudly rather than silently
## skip, so the missing wiring is obvious.

const _LOBBY_SCENE := "res://Scenes/Lobby/Lobby.tscn"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "lobby_hud"


## The real Lobby, whose Safe/UI subtree resolves the header and coin
## plate's % nodes; shared by every test in this suite.
var _lobby: Control
var _saved_grade: int
var _saved_max_minggu: int
var _saved_minggu_ke: int
var _saved_students: Array
var _saved_money: int
var _saved_inventory: Dictionary
var _saved_reduce_motion: bool


## One Lobby for the whole suite. It enters the editor root so @onready
## lookups resolve; Lobby.gd is not @tool, so its own _ready never runs
## here (matches test_daily_login_panel.gd's fixture). Not tracked;
## suite_teardown frees it.
func suite_setup(_ctx: Dictionary) -> void:
	var scene: PackedScene = load(_LOBBY_SCENE) as PackedScene
	_lobby = scene.instantiate() as Control
	_lobby.theme = load(_THEME_PATH) as Theme
	Engine.get_main_loop().root.add_child(_lobby)


func suite_teardown() -> void:
	if is_instance_valid(_lobby):
		_lobby.free()
	_lobby = null


func setup() -> void:
	_saved_grade = GameState.current_grade
	_saved_max_minggu = GameState.max_minggu
	_saved_minggu_ke = GameState.minggu_ke
	_saved_students = GameState.approved_students.duplicate()
	_saved_money = GameState.player_money
	_saved_inventory = GameState.inventory.duplicate()
	_saved_reduce_motion = GameSettings.reduce_motion


func teardown() -> void:
	GameState.current_grade = _saved_grade
	GameState.max_minggu = _saved_max_minggu
	GameState.minggu_ke = _saved_minggu_ke
	GameState.approved_students = _saved_students
	GameState.player_money = _saved_money
	GameState.inventory = _saved_inventory
	GameSettings.reduce_motion = _saved_reduce_motion


func test_header_draws_grade_week_and_stars() -> void:
	var header := _lobby.get_node_or_null("%ProgressHeader") as LobbyProgressHeader
	assert_true(header != null, "Safe/UI needs a LobbyProgressHeader named ProgressHeader")
	if header == null:
		return
	GameSettings.reduce_motion = true
	GameState.current_grade = 8
	GameState.minggu_ke = 3
	GameState.approved_students = []
	header.refresh()
	assert_eq((header.get_node("%GradeNumber") as Label).text, "8")
	assert_eq((header.get_node("%WeekLabel") as Label).text,
		LobbyProgressHeader.WEEK_FORMAT % [3, GameState.max_minggu])
	assert_eq((header.get_node("%StarBar") as ProgressBar).value, 0.0,
		"an empty roster has no stars")


func test_header_and_coin_plate_wear_the_scrapbook_plates() -> void:
	var header := _lobby.get_node_or_null("%ProgressHeader") as Panel
	var coin := _lobby.get_node_or_null("%DisplayUang") as Panel
	assert_true(header != null and header.theme_type_variation == &"ProgressPlate")
	assert_true(coin != null and coin.theme_type_variation == &"CoinPlate")
	var plus := _lobby.get_node_or_null("%PlusUang") as Button
	assert_true(plus != null and plus.theme_type_variation == &"PlusButton",
		"the coin plate carries the green +")


func test_the_reward_coin_still_flies_to_the_wallet() -> void:
	var panel := _lobby.get_node("DailyReward") as DailyLoginPanel
	assert_eq(panel.wallet_anchor, _lobby.get_node("%DisplayUang"),
		"wallet_anchor must follow DisplayUang out of BottomBar")
