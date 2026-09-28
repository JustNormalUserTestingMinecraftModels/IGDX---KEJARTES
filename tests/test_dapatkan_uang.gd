@tool
extends McpTestSuite

## Dapatkan Uang (2026-09-27 scrapbook HUD spec §7, Phase 2): the earn-money
## panel the Lobby's coin "+" opens, its dev-mode payouts, and the
## session-scoped GameState.ad_debt the "ambil dulu" cash-ins run up. The
## handlers are called directly: pressing through the GUI needs a frame.

const _GAME_STATE := "res://Scripts/GameState.gd"
const _PANEL_SCENE := "res://Scenes/Lobby/DapatkanUang.tscn"
const _LOBBY_SCRIPT := "res://Scripts/Lobby/Lobby.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _NODES := ["IklanSingkat", "VideoPenuh", "AmbilDulu4", "AmbilDulu8",
	"TontonUtang", "Tutup", "Toast", "ToastLabel", "DevModeTag", "Book", "Scrim"]

var _panel: DapatkanUang
var _saved_money: int
var _saved_debt: int
var _saved_reduce_motion: bool


func suite_name() -> String:
	return "dapatkan_uang"


## One panel for the suite (the runner gives no frame between tests). Not
## tracked; suite_teardown frees it.
func suite_setup(_ctx: Dictionary) -> void:
	var scene: PackedScene = load(_PANEL_SCENE) as PackedScene
	if scene == null:
		return
	_panel = scene.instantiate() as DapatkanUang
	_panel.theme = load(_THEME_PATH) as Theme
	Engine.get_main_loop().root.add_child(_panel)


func suite_teardown() -> void:
	if is_instance_valid(_panel):
		_panel.free()
	_panel = null


func setup() -> void:
	_saved_money = GameState.player_money
	_saved_debt = GameState.ad_debt
	_saved_reduce_motion = GameSettings.reduce_motion
	GameSettings.reduce_motion = true


func teardown() -> void:
	GameState.player_money = _saved_money
	GameState.ad_debt = _saved_debt
	GameSettings.reduce_motion = _saved_reduce_motion
	if is_instance_valid(_panel):
		_panel.is_dev_mode = true
		_panel.hide()


func _fixture() -> DapatkanUang:
	assert_true(_panel != null, "Scenes/Lobby/DapatkanUang.tscn must instance as DapatkanUang")
	return _panel


## A source scan, not a call: forget_session() in the editor would also wipe
## achievement progress.
func test_ad_debt_is_a_session_counter() -> void:
	var src := FileAccess.get_file_as_string(_GAME_STATE)
	assert_true(src.contains("var ad_debt: int = 0"), "ad_debt is a typed int, 0 at start")
	var forget: String = src.get_slice("func forget_session()", 1).get_slice("\nfunc ", 0)
	assert_true(forget.contains("ad_debt = 0"), "Forget Session clears it")
	var saver: String = src.get_slice("func _write_inventory_to(", 1).get_slice("\nfunc ", 0)
	assert_false(saver.contains("ad_debt"), "ad_debt never reaches disk")


func test_the_panel_holds_every_authored_part() -> void:
	var panel := _fixture()
	if panel == null:
		return
	for part: String in _NODES:
		assert_true(panel.get_node_or_null("%" + part) != null, "missing %" + part)


func test_it_starts_hidden_and_opens_and_closes() -> void:
	var panel := _fixture()
	if panel == null:
		return
	assert_false(panel.visible, "the panel waits hidden until the + opens it")
	panel.open()
	assert_true(panel.visible, "open() shows it")
	panel.close()
	assert_false(panel.visible, "close() under reduce_motion hides it at once")


func test_the_lobby_wires_the_plus_and_the_payout() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	assert_true(src.contains("plus_button.pressed.connect(earn_panel.open)"),
		"the coin plate's + opens the panel")
	assert_true(src.contains("earn_panel.paid.connect(_on_wallet_paid)"),
		"a payout rolls the wallet through the daily claim's handler")


func test_a_short_ad_pays_now() -> void:
	var panel := _fixture()
	if panel == null:
		return
	GameState.player_money = 100
	var payouts: Array[int] = []
	var record := func(amount: int, _previous: int) -> void: payouts.append(amount)
	panel.paid.connect(record)
	panel._on_short_ad_pressed()
	panel.paid.disconnect(record)
	assert_eq(GameState.player_money, 100 + DapatkanUang.SHORT_AD_REWARD)
	assert_eq(payouts.size(), 1, "paid announces it once")
	assert_eq(payouts[0], DapatkanUang.SHORT_AD_REWARD)
	assert_eq((panel.get_node("%ToastLabel") as Label).text,
		DapatkanUang.AD_TOAST_FORMAT % DapatkanUang.SHORT_AD_REWARD)


func test_a_full_video_pays_more() -> void:
	var panel := _fixture()
	if panel == null:
		return
	GameState.player_money = 0
	var previous: Array[int] = []
	var record := func(_amount: int, before: int) -> void: previous.append(before)
	panel.paid.connect(record)
	panel._on_full_ad_pressed()
	panel.paid.disconnect(record)
	assert_eq(GameState.player_money, DapatkanUang.FULL_AD_REWARD)
	assert_eq(previous, [0] as Array[int], "paid carries the balance before the payout")


func test_a_cash_in_pays_now_and_owes_ads() -> void:
	var panel := _fixture()
	if panel == null:
		return
	GameState.player_money = 0
	GameState.ad_debt = 0
	panel._on_cash_in_pressed(DapatkanUang.CASH_IN_LARGE, DapatkanUang.CASH_IN_LARGE_ADS)
	assert_eq(GameState.player_money, DapatkanUang.CASH_IN_LARGE)
	assert_eq(GameState.ad_debt, DapatkanUang.CASH_IN_LARGE_ADS)
	var owed := panel.get_node("%TontonUtang") as Button
	assert_true(owed.visible, "owing ads shows the owed-ad button (Q6)")
	assert_eq(owed.text, DapatkanUang.OWED_AD_BUTTON_FORMAT % DapatkanUang.CASH_IN_LARGE_ADS)
	assert_eq((panel.get_node("%ToastLabel") as Label).text,
		DapatkanUang.CASH_IN_TOAST_FORMAT % [DapatkanUang.CASH_IN_LARGE, DapatkanUang.CASH_IN_LARGE_ADS])


func test_watching_an_owed_ad_pays_one_back_and_never_goes_negative() -> void:
	var panel := _fixture()
	if panel == null:
		return
	GameState.player_money = 50
	GameState.ad_debt = 1
	panel._on_owed_ad_pressed()
	assert_eq(GameState.ad_debt, 0)
	assert_eq(GameState.player_money, 50, "an owed ad pays nothing more")
	assert_false((panel.get_node("%TontonUtang") as Button).visible,
		"with nothing owed the button leaves")
	panel._on_owed_ad_pressed()
	assert_eq(GameState.ad_debt, 0, "no debt, nothing to watch")


func test_the_dev_mode_tag_follows_is_dev_mode() -> void:
	var panel := _fixture()
	if panel == null:
		return
	var tag := panel.get_node("%DevModeTag") as Control
	panel.is_dev_mode = true
	panel.open()
	assert_true(tag.visible, "dev mode wears the tag")
	panel.close()
	panel.is_dev_mode = false
	panel.open()
	assert_false(tag.visible, "real mode hides it")
	panel.close()


## Copy with "—" or "…" must sit in body-font labels: Boohong has neither.
func test_dash_and_ellipsis_copy_uses_the_body_font() -> void:
	var panel := _fixture()
	if panel == null:
		return
	for label: Label in [panel.get_node("%ToastLabel") as Label,
			panel.get_node("Book/Page/Margin/Column/Tip/TipMargin/TipRow/TipLabel") as Label]:
		assert_eq(label.theme_type_variation, &"",
			"%s keeps the body-font default Label" % label.name)
