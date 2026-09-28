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
## Settles the shared Lobby's Containers in the same frame (no await).
const LayoutFrame := preload("res://tests/layout_frame.gd")
## A tall gesture-bar inset, px in the 1080-wide space, for the I1 case.
const _GESTURE_BAR_PIXELS := 120.0


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
	LayoutFrame.settle(_lobby)
	var book := hud.get_node("%BookHud") as Control
	var rail := hud.get_node("%IconRail") as Control
	var glyph := hud.get_node("%ChevronGlyph") as Control
	var open_book := Vector2(book.offset_top, book.offset_bottom)
	var open_rail := Vector2(rail.offset_left, rail.offset_right)
	hud.set_open(false)
	assert_false(hud.is_open)
	_assert_only_the_grip_peeks(hud, "the design screen")
	assert_eq(rail.offset_left, open_rail.x + hud.rail_slide_pixels,
		"the rail leaves by the right edge with the book (Q5)")
	assert_eq(glyph.rotation_degrees, LobbyHud.CHEVRON_HIDDEN_DEGREES,
		"the chevron turns to show the state")
	assert_true((hud.get_node("%HudHint") as Control).visible,
		"a hide says how to come back")
	hud.set_open(true)
	assert_true(hud.is_open)
	assert_eq(Vector2(book.offset_top, book.offset_bottom), open_book,
		"open returns to the authored rest")
	assert_eq(Vector2(rail.offset_left, rail.offset_right), open_rail,
		"the rail returns with it")
	assert_eq(glyph.rotation_degrees, 0.0)
	assert_eq((hud.get_node("%RosterChip") as Control).modulate.a, 1.0,
		"the roster chip comes back with the book")
	assert_false((hud.get_node("%HudHint") as Control).visible,
		"the hint leaves when the HUD is back")


## Review I1 and M1: a phone's gesture bar grows Safe's bottom margin. The
## device inset reads zero outside a fullscreen mobile build, so Safe's
## extra_margin stands in for it: it lands in the same margin_bottom. The
## hidden book must still peek only the grip, and it must follow a margin
## that changes while it is hidden, then reopen to its authored rest.
func test_a_gesture_bar_inset_still_peeks_only_the_grip() -> void:
	var hud := _hud()
	if hud == null:
		return
	var safe := _lobby.get_node("Safe") as SafeAreaMargin
	var book := hud.get_node("%BookHud") as Control
	GameSettings.reduce_motion = true
	hud.activate(false)
	safe.extra_margin = Vector4(0.0, 0.0, 0.0, _GESTURE_BAR_PIXELS)
	LayoutFrame.settle(_lobby)
	var open_book := Vector2(book.offset_top, book.offset_bottom)
	hud.set_open(false)
	_assert_only_the_grip_peeks(hud, "a gesture-bar inset")
	safe.extra_margin = Vector4.ZERO
	LayoutFrame.settle(_lobby)
	_assert_only_the_grip_peeks(hud, "the inset gone while hidden")
	hud.set_open(true)
	assert_eq(Vector2(book.offset_top, book.offset_bottom), open_book,
		"a resize while hidden still reopens to the authored rest")
	assert_true(is_equal_approx(book.get_global_rect().end.y, hud.get_global_rect().end.y),
		"the reopened book sits on the HUD's bottom edge")


## Hidden, JADWAL lies wholly below the viewport's bottom edge while the
## chevron grip still crosses it and its glyph shows whole (spec §4). Read
## from the real drawn rects, so it cannot just restate the arithmetic.
func _assert_only_the_grip_peeks(hud: LobbyHud, where: String) -> void:
	var screen_bottom: float = hud.get_viewport_rect().end.y
	var jadwal: Rect2 = _drawn_rect(hud.get_node("%Jadwal") as Control)
	var grip: Rect2 = _drawn_rect(hud.get_node("%ChevronGrip") as Control)
	var glyph: Rect2 = _drawn_rect(hud.get_node("%ChevronGlyph") as Control)
	assert_true(jadwal.position.y >= screen_bottom,
		"%s: JADWAL (top %.1f) hides below the screen's bottom %.1f"
		% [where, jadwal.position.y, screen_bottom])
	assert_true(grip.position.y < screen_bottom and grip.end.y > screen_bottom,
		"%s: the chevron grip (%.1f..%.1f) peeks across the bottom %.1f"
		% [where, grip.position.y, grip.end.y, screen_bottom])
	assert_true(glyph.end.y <= screen_bottom,
		"%s: the chevron glyph (bottom %.1f) shows whole" % [where, glyph.end.y])
	var chip := hud.get_node("%RosterChip") as Control
	assert_true(is_zero_approx(chip.modulate.a)
		or _drawn_rect(chip).position.y >= screen_bottom,
		"%s: the roster chip does not peek cut in half beside the grip" % where)


## A Control's on-screen bounds. get_global_rect() ignores rotation, and the
## hidden chevron glyph turns 180 degrees about its centre, which would put
## its reported rect a whole glyph lower than where it draws.
func _drawn_rect(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


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


## Review 4-5 Important #1: the hidden HUD's gestures. Every test drives
## _input and the chevron's pressed signal synchronously under
## reduce_motion, and leaves the HUD open and ungated as it found it.
## _hidden_hud ends on a plain press, so no earlier double tap lingers.
func _press(is_double: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.double_tap = is_double
	return touch


func _hidden_hud() -> LobbyHud:
	var hud := _hud()
	if hud == null:
		return null
	GameSettings.reduce_motion = true
	hud.can_reopen = Callable()
	hud.activate(false)
	hud.set_open(false)
	hud._input(_press(false))
	return hud


## Double-tapping the peeking chevron: the first release reopens, and the
## second must not close it again (it used to bounce straight back down).
func test_a_double_tap_on_the_chevron_stays_open() -> void:
	var hud := _hidden_hud()
	if hud == null:
		return
	var grip := hud.get_node("%ChevronGrip") as Button
	hud._input(_press(false))
	grip.pressed.emit()
	assert_true(hud.is_open, "the first tap on the chevron reopens")
	hud._input(_press(true))
	grip.pressed.emit()
	assert_true(hud.is_open, "the double tap's second release does not toggle again")
	hud._input(_press(false))
	grip.pressed.emit()
	assert_false(hud.is_open, "a later single tap still toggles")
	hud.set_open(true)


## Hidden, the book's buttons ignore input, so the double tap that reopens
## over the peeking JADWAL cannot also open AturJadwal; the reopening tap
## is marked handled, and the buttons come back with the book.
func test_the_peeking_book_is_not_live_while_hidden() -> void:
	var hud := _hidden_hud()
	if hud == null:
		return
	var parts: Array[Control] = [hud.raised_page, hud.koperasi, hud.inventory,
		hud.report_student]
	for part: Control in parts:
		assert_eq(part.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED,
			String(part.name) + " ignores taps while hidden")
	hud._input(_press(true))
	assert_true(hud.is_open, "a double tap anywhere reopens")
	assert_true(hud.get_viewport().is_input_handled(),
		"the reopening tap presses nothing under it")
	for part: Control in parts:
		assert_eq(part.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED,
			String(part.name) + " is live again once open")


## A single tap never reopens, and a popup (the Lobby's can_reopen) keeps
## the HUD down under a double tap.
func test_only_an_allowed_double_tap_reopens() -> void:
	var hud := _hidden_hud()
	if hud == null:
		return
	hud._input(_press(false))
	assert_false(hud.is_open, "a single tap is not the gesture")
	hud.can_reopen = func() -> bool: return false
	hud._input(_press(true))
	assert_false(hud.is_open, "a popup owns the screen")
	hud.can_reopen = Callable()
	hud.set_open(true)
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/Lobby.gd")
	assert_true(src.contains("hud.can_reopen = _chatter_allowed"),
		"the Lobby gates the reopen on its popups")


## Before activate() (the tutorial), neither gesture moves the HUD.
func test_an_inactive_hud_ignores_its_gestures() -> void:
	var fresh := track(LobbyHud.new()) as LobbyHud
	fresh.is_open = false
	fresh._input(_press(true))
	fresh._on_chevron_pressed()
	assert_false(fresh.is_open, "nothing reopens while the tutorial runs")


## JADWAL's breathe runs only while the book is up, and a mid-session
## reduce_motion stops it.
func test_the_breathe_stops_while_hidden() -> void:
	var hud := _hud()
	if hud == null:
		return
	GameSettings.reduce_motion = false
	hud.activate(false)
	assert_true(hud._breathe != null and hud._breathe.is_valid(), "an open HUD breathes")
	GameSettings.reduce_motion = true
	hud._on_reduce_motion_changed(true)
	assert_false(hud._breathe.is_valid(), "reduce_motion stops the breathe")
	GameSettings.reduce_motion = false
	hud._on_reduce_motion_changed(false)
	hud.set_open(false)
	assert_false(hud._breathe.is_valid(), "a hidden book does not breathe")
	assert_eq(hud.raised_page.scale, Vector2.ONE, "and rests at full size")
	GameSettings.reduce_motion = true
	hud.set_open(true)


## Task 7: IdleFade on the header and coin plate. Fails loudly until the
## [editor] scene step adds an IdleFade node (with an IdleTimer child) at
## the Lobby root and wires its targets, matching this suite's Task 3-6
## fixture pattern.
func _idle_fade() -> IdleFade:
	var fade := _lobby.get_node_or_null("IdleFade") as IdleFade
	assert_true(fade != null, "Lobby.tscn needs an IdleFade node at its root")
	return fade


func test_idle_fade_targets_the_header_and_coin_plate() -> void:
	var fade := _idle_fade()
	if fade == null:
		return
	var header := _lobby.get_node("%ProgressHeader") as CanvasItem
	var coin := _lobby.get_node("%DisplayUang") as CanvasItem
	assert_eq(fade.targets.size(), 2, "only the header and coin plate fade")
	assert_true(fade.targets.has(header), "the header is a target")
	assert_true(fade.targets.has(coin), "the coin plate is a target")
	var hud := _lobby.get_node("%Hud") as CanvasItem
	assert_false(fade.targets.has(hud), "the HUD itself does not fade, only the plates")


## Review M3: an editor event reaching the edited Lobby must not start a
## fade, or the next scene_save bakes the faded alpha into both plates.
## A source scan: the editor's own input routing cannot be driven here.
func test_idle_fade_is_inert_in_the_edited_scene() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/IdleFade.gd")
	assert_true(src.contains("if Engine.is_editor_hint() and is_part_of_edited_scene():"),
		"IdleFade._input carries the house edited-scene guard")


func test_idle_fade_timing_matches_the_spec() -> void:
	var fade := _idle_fade()
	if fade == null:
		return
	assert_eq(fade.idle_seconds, 8.0, "idle after ~8 s per the spec")
	assert_eq(fade.faded_alpha, 0.55, "rests at ~55% alpha while idle")


func test_idle_fade_under_reduce_motion_snaps_instead_of_tweening() -> void:
	var fade := _idle_fade()
	if fade == null:
		return
	GameSettings.reduce_motion = true
	fade.fade_out()
	for target: CanvasItem in fade.targets:
		# modulate.a is a 32-bit float, so 0.55 reads back as 0.5500000119.
		assert_true(is_equal_approx(target.modulate.a, fade.faded_alpha),
			"fade_out snaps straight to faded_alpha")
	fade.restore()
	for target: CanvasItem in fade.targets:
		assert_eq(target.modulate.a, 1.0, "restore snaps straight back to full opacity")
