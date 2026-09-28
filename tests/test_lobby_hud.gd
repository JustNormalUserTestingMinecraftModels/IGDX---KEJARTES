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
const _BADGE_SCENE := "res://Scenes/Lobby/NotifBadge.tscn"


func suite_name() -> String:
	return "lobby_hud"


## The real Lobby, whose Safe/UI subtree resolves the header and coin
## plate's % nodes; shared by every test in this suite.
var _lobby: Control
## A bare NotifBadge.tscn instance, in the tree so its @onready %Count
## resolves; null until the Task 6 scene step creates the .tscn.
var _badge: NotifBadge
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
	if ResourceLoader.exists(_BADGE_SCENE):
		var badge_scene: PackedScene = load(_BADGE_SCENE) as PackedScene
		_badge = badge_scene.instantiate() as NotifBadge
		Engine.get_main_loop().root.add_child(_badge)


func suite_teardown() -> void:
	if is_instance_valid(_lobby):
		_lobby.free()
	_lobby = null
	if is_instance_valid(_badge):
		_badge.free()
	_badge = null


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


## Task 4: the stepped book housing (RaisedBlock/RaisedPage over JADWAL! and
## the roster chip, and Shelf/ShelfPage over the three colour-coded tiles)
## plus the ChevronGrip peek handle, replacing the flat BottomBar row.
const _BOOK_PARTS: Array[String] = ["Hud", "BookHud", "RaisedBlock", "RaisedPage",
	"Shelf", "ChevronGrip", "ChevronGlyph", "IconRail", "HudHint", "RosterChip"]


func test_the_stepped_book_is_built() -> void:
	for part: String in _BOOK_PARTS:
		assert_true(_lobby.get_node_or_null("%" + part) != null, "missing %" + part)
	var jadwal := _lobby.get_node("%Jadwal") as Button
	assert_eq(jadwal.theme_type_variation, &"BookHeroButton")
	assert_true((_lobby.get_node("%RaisedPage") as Node).is_ancestor_of(jadwal),
		"JADWAL sits on the raised page")
	var tiles: Dictionary = {"Koperasi": &"NavTileKoperasi",
		"Inventory": &"NavTileInventory", "ReportStudent": &"NavTileRapor"}
	for tile_name: String in tiles:
		var tile := _lobby.get_node("%" + tile_name) as Button
		assert_eq(tile.theme_type_variation, tiles[tile_name], tile_name)
		assert_true((_lobby.get_node("%Shelf") as Node).is_ancestor_of(tile),
			tile_name + " sits on the shelf")


## Task 4: the four fixed-art icon buttons ride in IconRail now, still with
## their delivered art untouched (spec §1 and §8).
func test_the_fixed_icons_moved_with_their_art() -> void:
	var rail := _lobby.get_node("%IconRail") as Node
	var art: Dictionary = {
		"DailyLogin": "res://Assets/Images/UI/icon_daily_login.png",
		"SettingsButton": "res://Assets/Images/UI/setting.png",
		"AchievementButton": "res://Assets/Images/Achievements/achievement_button.png",
		"SkinSwitchButton": "res://Assets/Images/UI/skin_switch.png",
	}
	for icon_name: String in art:
		var icon := _lobby.get_node("%" + icon_name) as TextureButton
		assert_eq(icon.get_parent(), rail, icon_name + " rides in the rail")
		assert_eq(icon.texture_normal.resource_path, art[icon_name],
			icon_name + "'s art is fixed (spec §1)")


## Task 5: LobbyHud, the swipe-away component on %Hud. Under reduce_motion
## set_open() lands at once, so none of these needs an await. Fails loudly
## until the [editor] step attaches Scripts/Lobby/LobbyHud.gd to %Hud.
func _hud() -> LobbyHud:
	var hud := _lobby.get_node_or_null("%Hud") as LobbyHud
	assert_true(hud != null, "Lobby.tscn's %Hud needs Scripts/Lobby/LobbyHud.gd")
	return hud


func test_the_hud_hides_to_its_peek_and_comes_back() -> void:
	var hud := _hud()
	if hud == null:
		return
	GameSettings.reduce_motion = true
	hud.activate(false)
	var book := hud.get_node("%BookHud") as Control
	var rail := hud.get_node("%IconRail") as Control
	var glyph := hud.get_node("%ChevronGlyph") as Control
	var open_y: float = book.position.y
	var open_x: float = rail.position.x
	hud.set_open(false)
	assert_false(hud.is_open)
	assert_eq(book.position.y, open_y + book.size.y - hud.peek_pixels,
		"hidden leaves only the chevron's peek")
	assert_eq(rail.position.x, open_x + hud.rail_slide_pixels,
		"the rail leaves by the right edge with the book (Q5)")
	assert_eq(glyph.rotation_degrees, LobbyHud.CHEVRON_HIDDEN_DEGREES,
		"the chevron turns to show the state")
	assert_true((hud.get_node("%HudHint") as Control).visible,
		"a hide says how to come back")
	hud.set_open(true)
	assert_true(hud.is_open)
	assert_eq(book.position.y, open_y, "open returns to the authored rest")
	assert_eq(rail.position.x, open_x, "the rail returns with it")
	assert_eq(glyph.rotation_degrees, 0.0)
	assert_false((hud.get_node("%HudHint") as Control).visible,
		"the hint leaves when the HUD is back")


func test_the_hud_waits_for_the_tutorial() -> void:
	var fresh := track(LobbyHud.new()) as LobbyHud
	assert_false(fresh.is_active, "a HUD starts inactive")
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/Lobby.gd")
	assert_true(src.contains("hud.activate(true)"), "returning players get the entrance")
	assert_true(src.contains("hud.activate(false)"), "the tutorial's end turns the swipe on")


func test_the_roster_chip_counts_the_class() -> void:
	var hud := _hud()
	if hud == null:
		return
	GameState.approved_students = [{"name": "Andi"}, {"name": "Citra"}]
	hud.refresh(false)
	assert_true((hud.get_node("%RosterChip") as Control).visible)
	assert_eq((hud.get_node("%RosterChipLabel") as Label).text,
		LobbyHud.ROSTER_CHIP_FORMAT % 2)
	GameState.approved_students = []
	hud.refresh(false)
	assert_false((hud.get_node("%RosterChip") as Control).visible,
		"no chip before a roster exists")


## The chatter ignores taps on the whole book and rail, not a list of
## buttons Lobby.gd has to keep in step with the scene.
func test_the_hud_hands_the_chatter_its_blockers() -> void:
	var hud := _hud()
	if hud == null:
		return
	var blockers: Array[Control] = hud.tap_blockers()
	for part: String in ["RaisedBlock", "Shelf", "ChevronGrip", "IconRail"]:
		assert_true(blockers.has(hud.get_node("%" + part)), part + " blocks face taps")


## Task 6: NotifBadge, the icon rail and nav tiles' red count pill. Fails
## loudly until Scenes/Lobby/NotifBadge.tscn exists (the [editor] scene
## step), matching this suite's existing Task 3-5 fixture pattern.
func _badge_fixture() -> NotifBadge:
	assert_true(_badge != null, "Scenes/Lobby/NotifBadge.tscn must exist and instance as NotifBadge")
	return _badge


func test_notif_badge_hides_at_zero() -> void:
	var badge := _badge_fixture()
	if badge == null:
		return
	GameSettings.reduce_motion = true
	badge.set_count(0)
	assert_false(badge.visible, "a zero count hides the badge")


func test_notif_badge_shows_a_small_count() -> void:
	var badge := _badge_fixture()
	if badge == null:
		return
	GameSettings.reduce_motion = true
	badge.set_count(3)
	assert_true(badge.visible, "a positive count shows the badge")
	assert_eq(badge.count_label.text, "3")


func test_notif_badge_overflows_past_max_shown() -> void:
	var badge := _badge_fixture()
	if badge == null:
		return
	GameSettings.reduce_motion = true
	badge.set_count(12)
	assert_eq(badge.count_label.text, NotifBadge.OVERFLOW_TEXT,
		"a count past MAX_SHOWN reads OVERFLOW_TEXT")


func test_notif_badge_with_shows_count_off_reads_a_mark() -> void:
	var badge := _badge_fixture()
	if badge == null:
		return
	GameSettings.reduce_motion = true
	badge.shows_count = false
	badge.set_count(1)
	assert_eq(badge.count_label.text, NotifBadge.MARK_TEXT,
		"shows_count = false marks rather than counts")
	badge.shows_count = true


## refresh(true) must show the daily-gift badge. Fails loudly until the
## [editor] scene step adds %DailyBadge under %DailyLogin.
func test_daily_badge_shows_while_claimable() -> void:
	var hud := _hud()
	if hud == null:
		return
	var badge := hud.get_node_or_null("%DailyBadge") as NotifBadge
	assert_true(badge != null, "Lobby.tscn needs %DailyBadge under %DailyLogin")
	if badge == null:
		return
	GameSettings.reduce_motion = true
	hud.refresh(true)
	assert_true(badge.visible, "the daily badge shows while today is claimable")


## The inventory badge sums GameState.inventory's quantities, not its item
## count. Fails loudly until %InventoryBadge exists under %Inventory.
func test_inventory_badge_shows_the_total_quantity() -> void:
	var hud := _hud()
	if hud == null:
		return
	var badge := hud.get_node_or_null("%InventoryBadge") as NotifBadge
	assert_true(badge != null, "Lobby.tscn needs %InventoryBadge under %Inventory")
	if badge == null:
		return
	GameSettings.reduce_motion = true
	GameState.inventory = {"kompas": 2, "topi": 3}
	hud.refresh(false)
	assert_eq(badge.count_label.text, "5", "the inventory badge sums item quantities")


## The three rail/shelf badges must carry distinct wiggle_delay_seconds
## (0.0 / 0.8 / 1.6 per the brief) so they never wiggle in lockstep.
func test_the_three_badges_wiggle_out_of_sync() -> void:
	var hud := _hud()
	if hud == null:
		return
	var daily := hud.get_node_or_null("%DailyBadge") as NotifBadge
	var achievement := hud.get_node_or_null("%AchievementBadge") as NotifBadge
	var inventory := hud.get_node_or_null("%InventoryBadge") as NotifBadge
	assert_true(daily != null and achievement != null and inventory != null,
		"Lobby.tscn needs %DailyBadge, %AchievementBadge and %InventoryBadge")
	if daily == null or achievement == null or inventory == null:
		return
	assert_ne(daily.wiggle_delay_seconds, achievement.wiggle_delay_seconds,
		"DailyBadge and AchievementBadge must not share a wiggle offset")
	assert_ne(daily.wiggle_delay_seconds, inventory.wiggle_delay_seconds,
		"DailyBadge and InventoryBadge must not share a wiggle offset")
	assert_ne(achievement.wiggle_delay_seconds, inventory.wiggle_delay_seconds,
		"AchievementBadge and InventoryBadge must not share a wiggle offset")


## A claim clears the daily badge: the Lobby re-asks the panel after the
## claim, and refresh(false) must hide what refresh(true) showed.
func test_daily_badge_clears_once_claimed() -> void:
	var hud := _hud()
	if hud == null:
		return
	var badge := hud.get_node_or_null("%DailyBadge") as NotifBadge
	assert_true(badge != null, "Lobby.tscn needs %DailyBadge under %DailyLogin")
	if badge == null:
		return
	GameSettings.reduce_motion = true
	hud.refresh(true)
	hud.refresh(false)
	assert_false(badge.visible, "a claimed gift leaves no badge")
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/Lobby.gd")
	assert_eq(src.count("hud.refresh(daily_reward.is_claimable())"), 2,
		"the Lobby refreshes the badges on entry and again on the claim")
