@tool
extends McpTestSuite

## Lobby (Task 14). The game's hub screen: a layered diorama (BGLayer,
## Meja_* desks, portrait/hand containers) that is art, not UI, plus a HUD
## (title, money display, daily-login popup, five nav buttons) that this
## task migrates onto the shared theme/token/Juice system.
##
## Technique notes carried over from Tasks 9-13:
##  * This suite must itself be @tool or the runner reports the class as
##    abstract/broken.
##  * The runner calls `suite.call(name)` WITHOUT awaiting, so no test
##    here may be a coroutine.
##  * Control has no get_theme_*_override_list() in Godot 4.6; the
##    _collect_overrides helper below is copied verbatim from
##    tests/test_main_menu.gd.
##  * ThemeDB's project-theme fallback does not populate for a scene
##    instantiated under the editor's own root, so the baked theme is
##    assigned explicitly before the scene enters the tree.
##  * Touch-target checks read get_combined_minimum_size() synchronously
##    (Task 9/10's established fix).
##  * Lobby.gd is NOT @tool (matching StudentCard/StudentList precedent,
##    verified empirically below): _ready() reads the GameState autoload
##    and builds dynamic content (tutorial panel, blur overlay, daily
##    login wiring), none of which fires when the editor's own test
##    runner instantiates the scene and add_child()s it under
##    Engine.get_main_loop().root. Since @export var initializers DO run
##    at object construction (independent of _ready/@tool), the idle-bob
##    export defaults are still directly testable. Everything else this
##    suite needs (theme overrides, variation assignments, routing,
##    tutorial-gate wiring, money/daily-login juice wiring, no-Color()
##    literals) is either .tscn-authored structure or a source-text scan,
##    so no @tool/is_editor_hint() gating is needed on the script itself.

const _SCENE_PATH := "res://Scenes/Lobby/Lobby.tscn"
const _SCRIPT_PATH := "res://Scripts/Lobby/Lobby.gd"
const _PANEL_SCRIPT_PATH := "res://Scripts/Lobby/DailyLoginPanel.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

const _NAV_BUTTONS := ["Student", "Koperasi", "ReportStudent", "Inventory", "Jadwal"]
const _LOOSE_STYLEBOX_PATHS := [
	"res://Assets/Images/UI/Placeholders/lobby_btn_normal.tres",
	"res://Assets/Images/UI/Placeholders/lobby_btn_hover.tres",
	"res://Assets/Images/UI/Placeholders/lobby_btn_pressed.tres",
]


func suite_name() -> String:
	return "lobby"


var _lobby: Control


## One Lobby for the whole suite, not one per test: the runner gives no
## frame between tests, so 33 fresh Lobbies flooded the editor's message
## queue with deferred layout calls and crashed a full run. Every test
## here only reads it, bar one that puts its label back. Not tracked;
## suite_teardown frees it.
func suite_setup(_ctx: Dictionary) -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_lobby = scene.instantiate()
	_lobby.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_lobby)


func suite_teardown() -> void:
	if is_instance_valid(_lobby):
		_lobby.free()
	_lobby = null


# ------------------------------------------------ behavioral contract net

func test_still_routes_to_student_card_and_atur_jadwal() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/StudentCard/StudentCard.tscn"),
		"lobby must still route Student -> StudentCard")
	assert_true(src.contains("res://Scenes/AturJadwal/AturJadwal.tscn"),
		"lobby must still route Jadwal -> AturJadwal")


func test_tutorial_gate_still_wired() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.lobby_tutorial_completed"),
		"the lobby_tutorial_completed gate must still be read/set")
	assert_true(src.contains("GameState.minggu_ke > 1"),
		"the returning-player short-circuit must still be intact")


func test_money_label_uses_count_up_not_a_direct_set() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.count_up(money_label"),
		"money display must animate via Juice.count_up")
	assert_false(src.contains('money_label.text = str('),
		"money_label.text must no longer be set directly")
	assert_true(src.contains('AudioDirector.play_sfx(&"coin")'),
		"a coin sfx must fire when money increases")


func test_daily_login_uses_pop_in() -> void:
	# The seven day tiles (and their stagger_in) are gone with them -- the
	# panel art bakes the whole calendar, so opening and claiming both just
	# pop the one panel node. The pop lives in the DailyLoginPanel
	# component; the reward feedback stays on the Lobby, which owns the
	# money label it bursts from.
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT_PATH)
	assert_true(panel_src.contains("Juice.pop_in("),
		"the panel must pop in on open and on claim")
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains('RewardFeedback.play(&"coins_earned"'),
		"claiming a day must fire the reward through RewardFeedback")


## The daily-login popup is a DailyLoginPanel component (2026-09-28). It
## owns the claim and the streak's GameState writes; the Lobby only
## listens for `claimed` and rolls its wallet.
func test_daily_reward_is_a_daily_login_panel() -> void:
	assert_true(_lobby.get_node("DailyReward") is DailyLoginPanel,
		"DailyReward must carry the DailyLoginPanel script")
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("daily_login_day"),
		"the streak day is the panel's to write, not the Lobby's")
	assert_false(src.contains("last_claim_date"),
		"the claim date is the panel's to write, not the Lobby's")
	assert_true(src.contains("claimed.connect(_on_wallet_paid)"),
		"the Lobby must listen for the panel's claimed signal")


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_lobby != null, "scene must instantiate")
	assert_true(_lobby.is_inside_tree(), "scene must enter the tree cleanly")
	for name in _NAV_BUTTONS:
		assert_true(_lobby.get_node_or_null("%" + name) != null, "missing nav button: " + name)
	assert_true(_lobby.get_node_or_null("%ProgressHeader") != null, "missing ProgressHeader")
	assert_true(_lobby.get_node_or_null("%DisplayUang/Label") != null, "missing money label")
	assert_true(_lobby.get_node_or_null("DailyReward/ButtonClaim") != null,
		"missing claim button")


func test_scene_has_no_theme_overrides() -> void:
	# The whole point of centralization: the migrated HUD must be styled
	# entirely by the project theme. The diorama art nodes never carried
	# theme overrides to begin with, so walking the whole tree is safe.
	var offenders: Array[String] = []
	_collect_overrides(_lobby, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


## Copied verbatim from tests/test_main_menu.gd.
func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


func test_no_hardcoded_colors_remain_in_the_script() -> void:
	var re := RegEx.create_from_string("Color\\s*\\(")
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_eq(re.search_all(src).size(), 0,
		"Lobby.gd must read colors from DesignTokens/Color constants, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var paths := []
	for n in _NAV_BUTTONS:
		paths.append("%" + n)
	paths.append("DailyReward/ButtonClaim")
	paths.append("%SettingsButton")
	paths.append("%PlusUang")
	for p in paths:
		var b := _lobby.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		var h := b.get_combined_minimum_size().y
		assert_true(h >= float(tokens.touch_target_min),
			"%s has minimum height %d px, below the %d px minimum" % [p, int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

## Scrapbook HUD (Task 4): the three shelf tiles wear their own colour-coded
## NavTile* variation and the two book buttons share BookHeroButton, not the
## old shared LobbyNavTile / LobbyCtaButton pair.
func test_nav_buttons_use_lobby_nav_tile_or_cta_button_variation() -> void:
	var tile_variations: Dictionary = {"Koperasi": &"NavTileKoperasi",
		"Inventory": &"NavTileInventory", "ReportStudent": &"NavTileRapor"}
	var cta_buttons := ["Student", "Jadwal"]
	for name: String in tile_variations:
		var b := _lobby.get_node_or_null("%" + name) as Button
		assert_true(b != null, "missing nav button: " + name)
		assert_eq(b.theme_type_variation, tile_variations[name], name + " variation")
	for name in cta_buttons:
		var b := _lobby.get_node_or_null("%" + name) as Button
		assert_true(b != null, "missing nav button: " + name)
		assert_eq(b.theme_type_variation, &"BookHeroButton", name + " variation")


func test_labels_use_theme_variations() -> void:
	var money := _lobby.get_node_or_null("%DisplayUang/Label") as Label
	assert_true(money != null, "missing money label")
	assert_eq(money.theme_type_variation, &"CoinLabel", "money label variation")

	# The old header label is gone (2026-09-28, UI depth pass Phase 2, Task
	# 8): the daily-login panel now wears a NotebookFrame, and its title
	# became the frame's stitched sticker.
	var frame := _lobby.get_node_or_null("DailyReward/DailyLoginFrame") as NotebookFrame
	assert_true(frame != null, "missing Daily Reward notebook frame")
	assert_eq(frame.title_text, "DAILY LOGIN", "the header became the sticker")


func _lobby_source() -> String:
	return FileAccess.get_file_as_string("res://Scripts/Lobby/Lobby.gd")


func test_koperasi_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_koperasi_pressed"),
		"the Koperasi button must have a handler")
	# Changed 2026-09-07: the button lands on the hub, which forks to
	# the item shop or the cosmetic shop.
	assert_true(src.contains("res://Scenes/Koperasi/ShopHub.tscn"),
		"Koperasi must route to the shop hub")
	assert_false(src.contains("res://Scenes/Koperasi/Koperasi.tscn"),
		"the Lobby should no longer reach the item shop directly")


func test_inventory_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_inventory_pressed"),
		"the Inventory button must have a handler")
	assert_true(src.contains("res://Scenes/Inventory/Inventory.tscn"),
		"Inventory must route to the inventory scene")


## Changed with the panel-art rebuild: the baked art now draws its own gold
## claim pill, so the button itself must draw nothing (GhostButton) rather
## than layering a second, redundant SuccessButton chrome on top of it.
func test_claim_button_uses_ghost_button_variation() -> void:
	var claim := _lobby.get_node_or_null("DailyReward/ButtonClaim") as Button
	assert_true(claim != null, "missing claim button")
	assert_eq(claim.theme_type_variation, &"GhostButton", "claim button variation")


func test_loose_stylebox_files_are_gone_and_unreferenced() -> void:
	for path in _LOOSE_STYLEBOX_PATHS:
		assert_false(FileAccess.file_exists(path), "loose stylebox must be deleted: " + path)
	var tscn_src := FileAccess.get_file_as_string(_SCENE_PATH)
	for path in _LOOSE_STYLEBOX_PATHS:
		assert_false(tscn_src.contains(path), "scene must no longer reference " + path)


func test_theme_factory_bakes_lobby_nav_button_variation() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_true(theme != null, "baked theme must load")
	assert_true(theme.get_type_list().has("LobbyNavTile"),
		"baked theme must include the LobbyNavTile variation")
	assert_true(theme.get_type_list().has("LobbyCtaButton"),
		"baked theme must include the LobbyCtaButton variation")


## Regression guard (2026-09-10). The claim pill's own art never changes
## between claimed/unclaimed, and GhostButton draws no stylebox chrome at
## all, so a disabled ButtonClaim with no font_disabled_color of its own
## fell through to Godot's stock translucent white -- the only remaining
## "already claimed" cue, and it read as broken rather than intentional.
func test_ghost_button_defines_font_disabled_color() -> void:
	# CACHE_MODE_IGNORE matters: the editor holds kejartes_theme.tres in
	# memory from startup, so a plain load() returns that cached copy --
	# which would hide a real rebake from this test. See
	# test_theme_factory.gd's test_baked_theme_matches_what_the_factory_builds.
	var theme: Theme = ResourceLoader.load(
		_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_true(theme != null, "baked theme must load")
	assert_true(theme.has_color("font_disabled_color", &"GhostButton"),
		"GhostButton must define font_disabled_color, or a disabled claim button falls back to Godot's stock translucent white")


func test_idle_bob_is_exported_and_wired_to_the_portrait_containers() -> void:
	# Verified via source text, matching this suite's other script-content
	# checks: the MCP editor test runner caches compiled GDScript classes
	# per session, so a brand-new @export var added to an already-loaded
	# script can read back as missing on a freshly instantiated node even
	# after an on-disk edit/reload -- a caching quirk of the test harness,
	# not evidence about the real game (a real launch always compiles
	# fresh). Reading the declaration and wiring straight from source
	# sidesteps that quirk entirely.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("@export var idle_bob_pixels: float"),
		"missing idle_bob_pixels export")
	assert_true(src.contains("@export var idle_bob_period: float"),
		"missing idle_bob_period export")
	assert_true(src.contains("_start_idle_bob(portraits_back"),
		"the back portrait container must get the idle bob")
	assert_true(src.contains("_start_idle_bob(portraits_front"),
		"the front portrait container must get the idle bob")

func test_report_student_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_report_student_pressed"),
		"the ReportStudent button must have a handler")
	assert_true(src.contains("res://Scenes/ReportCard/ReportCard.tscn"),
		"ReportStudent must route to the report card scene")


## The money readout was a 1920x1080 pink landscape PNG with a label on
## top -- off-palette, and the reason the chip was 332x187 rather than the
## 332x96 the layout wanted. It is a themed rounded panel now, with the
## coin as a real icon beside the number.
func test_the_money_chip_is_a_themed_panel_with_a_coin_icon() -> void:
	var chip := _lobby.get_node_or_null("%DisplayUang") as Panel
	assert_true(chip != null, "DisplayUang must be a Panel now, not a TextureRect")
	assert_eq(chip.theme_type_variation, &"CoinPlate",
		"the chip takes its chrome from the theme")
	assert_eq(chip.size.y, 112.0,
		"the chip is 112 tall on the coin plate, got %f" % chip.size.y)

	var icon := _lobby.get_node_or_null("%DisplayUang/CoinIcon") as TextureRect
	assert_true(icon != null, "the chip needs a coin icon")
	assert_eq(icon.texture.resource_path, "res://Assets/Images/UI/uang.png",
		"and it is the new coin art")


## Both shop screens read the same coin as the lobby, so money looks like
## one currency across the game. Koperasi's coin lives in BasketTray.tscn
## (the basket tray's KAS KELAS pill); Inventory's coin is in its own scene.
func test_the_shop_screens_use_the_same_coin() -> void:
	for path in ["res://Scenes/Koperasi/BasketTray.tscn",
			"res://Scenes/Inventory/Inventory.tscn"]:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("Assets/Images/UI/uang.png"),
			"%s should show the shared coin" % path)


## The panel art carries the whole calendar -- seven slots with the
## active one lit and holding a gift. The seven overlay tiles and their
## "10G"/"DayN" labels are gone with it.
func test_the_day_tiles_are_gone() -> void:
	for i in range(1, 8):
		assert_true(_lobby.get_node_or_null("DailyReward/Day%d" % i) == null,
			"Day%d should be gone -- the panel art shows the day" % i)


func test_the_panel_swaps_art_per_day() -> void:
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT_PATH)
	assert_true(panel_src.contains("DAY_PANELS"),
		"the seven panels must be a named const, not seven inline loads")
	for i in range(1, 8):
		assert_true(panel_src.contains("DailyLogin/day%d.png" % i),
			"day %d's panel must be referenced" % i)
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for script_src: String in [src, panel_src]:
		assert_false(script_src.contains("day_nodes"),
			"the per-tile tint bookkeeping goes with the tiles")


func test_the_lobby_button_wears_the_calendar_icon() -> void:
	var btn := _lobby.get_node_or_null("%DailyLogin") as TextureButton
	assert_true(btn != null, "the DailyLogin button is missing")
	assert_eq(btn.texture_normal.resource_path,
		"res://Assets/Images/UI/icon_daily_login.png",
		"it wears the calendar icon")


## Claim button bottom-centre, on the display face -- the panel art bakes
## a gold pill for it, so it sits on top of the art rather than beside it.
## The header ("Daily Login") is no longer part of the baked art: since
## 2026-09-28 (UI depth pass Phase 2, Task 8) it is the notebook frame's
## stitched sticker, drawn behind the art instead -- see
## test_labels_use_theme_variations for that assertion.
func test_the_claim_button_sits_on_the_baked_art() -> void:
	var panel := _lobby.get_node_or_null("DailyReward") as Control
	var claim := _lobby.get_node_or_null("DailyReward/ButtonClaim") as Button
	assert_true(claim != null, "missing the claim button")
	assert_eq(claim.theme_type_variation, &"GhostButton",
		"the claim button draws nothing -- the baked gold pill is the button")
	var claim_mid: float = claim.offset_left + claim.size.x * 0.5
	assert_true(absf(claim_mid - panel.size.x * 0.5) < 40.0,
		"the claim button is centred, its middle is at %f of %f"
			% [claim_mid, panel.size.x])
	assert_true(claim.offset_top > panel.size.y * 0.6,
		"and sits in the panel's lower third")


## Regression guard (2026-09-10). ButtonClaim carries custom_minimum_size =
## Vector2(0, 96) to satisfy the touch-target floor (see the test below), but
## Godot's Control clamps a node's REAL rect up to
## get_combined_minimum_size() no matter what its own offset_top/offset_bottom
## say -- a button authored at a shorter rect than its minimum still renders
## and hit-tests at the minimum height. That is exactly how ButtonClaim once
## spilled past DailyReward's bottom edge while every offset-only check above
## kept passing: the authored offsets looked fine, the *clamped* size did
## not. This compares the clamped height, not the authored offsets, against
## the panel's real height, and reads both from the nodes so a future
## re-tune of either stays honest.
func test_claim_buttons_clamped_height_fits_inside_the_panel() -> void:
	var panel := _lobby.get_node_or_null("DailyReward") as Control
	var claim := _lobby.get_node_or_null("DailyReward/ButtonClaim") as Control
	assert_true(panel != null, "missing the DailyReward panel")
	assert_true(claim != null, "missing the claim button")
	var clamped_height: float = maxf(claim.size.y, claim.get_combined_minimum_size().y)
	var clamped_bottom: float = claim.offset_top + clamped_height
	assert_true(clamped_bottom <= panel.size.y,
		"claim button's clamped height %f pushes its bottom to %f, past the panel's %f bottom edge"
			% [clamped_height, clamped_bottom, panel.size.y])


func test_the_panel_grew_to_the_arts_aspect() -> void:
	var panel := _lobby.get_node_or_null("DailyReward") as Control
	assert_true(panel != null, "missing the DailyReward panel")
	var aspect: float = panel.size.x / panel.size.y
	assert_true(absf(aspect - 2.253) < 0.05,
		"the panel must match the art's 2.253:1, got %f" % aspect)


## Daily-login polish, Task 4. The coin and the amount share one
## HBoxContainer, so a longer amount pushes the row wider instead of
## clipping inside a fixed 120px label box -- and the widest reward, day
## 7's "400G", still ends inside the panel.
func test_the_peak_reward_fits_its_row() -> void:
	var panel := _lobby.get_node_or_null("DailyReward") as Control
	var row := _lobby.get_node_or_null("%RewardRow") as HBoxContainer
	var amount := _lobby.get_node_or_null("%RewardAmount") as Label
	var coin := _lobby.get_node_or_null("%RewardCoin") as TextureRect
	assert_true(row != null, "RewardRow must be an HBoxContainer under DailyReward")
	assert_true(amount != null and coin != null, "missing RewardAmount or RewardCoin")
	if row == null or amount == null or coin == null:
		return
	assert_eq(row.get_parent(), panel, "RewardRow sits directly on the panel")
	assert_eq(coin.get_parent(), row, "the coin lives in the reward row")
	assert_eq(amount.get_parent(), row, "the amount lives in the reward row")
	var shown: String = amount.text
	amount.text = "400G"
	var row_right: float = row.offset_left + row.get_combined_minimum_size().x
	amount.text = shown
	assert_true(row_right <= panel.size.x,
		"with 400G the row ends at %f, past the panel's %f width" % [row_right, panel.size.x])


## Daily-login polish, Task 5: a welcome-back greeting and the streak line
## sit above the panel, so the baked strip art stays untouched.
func test_the_greeting_and_streak_sit_above_the_panel() -> void:
	var greeting := _lobby.get_node_or_null("%DailyGreeting") as Label
	assert_true(greeting != null, "missing DailyGreeting")
	if greeting == null:
		return
	# ResultHeroLabel: gold display face with a dark outline, the light-on-dark
	# variation -- H2Label's dark text disappeared over the blurred lobby.
	assert_eq(greeting.theme_type_variation, &"ResultHeroLabel",
		"the greeting reads light-on-dark over the blur")
	assert_eq(greeting.text, "Selamat datang kembali!", "the greeting welcomes the player back")
	assert_true(_lobby.get_node_or_null("%StreakLabel") is Label, "missing StreakLabel")
	for header_path: String in ["%DailyGreeting", "%DailyStreak"]:
		var header := _lobby.get_node_or_null(header_path) as Control
		assert_true(header != null, "missing " + header_path)
		if header == null:
			continue
		assert_eq(header.get_parent(), _lobby.get_node("DailyReward"),
			header_path + " sits on DailyReward")
		var bottom: float = header.position.y + maxf(header.size.y, header.get_combined_minimum_size().y)
		assert_true(bottom <= 0.0,
			"%s ends at y=%f, over the panel's strip art (top edge 0)" % [header_path, bottom])
	var flame := _lobby.get_node_or_null("%StreakFlame") as TextureRect
	assert_true(flame != null, "missing StreakFlame")
	if flame == null:
		return
	assert_true(flame.texture != null
		and flame.texture.resource_path.ends_with("streak_flame.svg"),
		"the streak flame wears streak_flame.svg")
	# The panel scales the flame by streak day. A Container resets its
	# direct children's scale to 1 on every sort, so the flame must sit in
	# a plain Control slot, not straight in the DailyStreak row.
	assert_false(flame.get_parent() is Container,
		"StreakFlame's parent is a Container, which would undo its scale")


func test_the_panel_springs_the_greeting_in() -> void:
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT_PATH)
	assert_true(panel_src.contains("AnimUtils.popup_spring_in("),
		"opening the panel springs the greeting and streak in")


## Daily-login polish, Task 6: the prize-box reveal lives on the panel,
## and the panel knows where the reward coin flies.
func test_the_reveal_sits_on_the_panel_and_aims_at_the_wallet() -> void:
	var panel := _lobby.get_node_or_null("DailyReward") as DailyLoginPanel
	var reveal := _lobby.get_node_or_null("%DailyRewardReveal") as Control
	assert_true(reveal != null, "missing DailyRewardReveal")
	if reveal == null or panel == null:
		return
	assert_eq(reveal.get_parent(), panel, "the reveal is a child of DailyReward")
	assert_eq(panel.wallet_anchor, _lobby.get_node("%DisplayUang"),
		"DailyReward's wallet_anchor is wired to %DisplayUang")


## Daily-login polish, Task 7: the "besok" teaser under the strip. It reads
## ResultDeltaLabel (white with a dark outline), not CaptionLabel -- a dark
## caption was unreadable over the Lobby's blurred backdrop.
func test_the_besok_teaser_is_a_caption() -> void:
	var teaser := _lobby.get_node_or_null("%BesokTeaser") as Label
	assert_true(teaser != null, "missing BesokTeaser")
	if teaser == null:
		return
	assert_eq(teaser.theme_type_variation, &"ResultDeltaLabel", "the teaser is readable over the blur")


## The popup redraws for the current date each time it opens, so a Lobby
## left open past midnight never shows yesterday's claim as today's.
func test_opening_the_daily_reward_refreshes_for_today() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body_start: int = src.find("func _show_daily_reward")
	assert_true(body_start >= 0, "Lobby has _show_daily_reward")
	var body: String = src.substr(body_start, src.find("\nfunc ", body_start + 1) - body_start)
	var refresh_at: int = body.find("daily_reward.refresh(Time.get_date_string_from_system())")
	assert_true(refresh_at >= 0, "opening refreshes the panel with today's date")
	assert_true(refresh_at < body.find("daily_reward.open()"), "and does so before open()")


# ------------------------------------------- the tutorial on the shared panel
#
# 2026-10-01 tutorial unification. The Lobby built a fifth runtime copy of the
# coach-mark (a PanelContainer, three Labels, two separators, "(n/N)" titles)
# and clamped its arrow with a hard-coded 320px picture. It is now
# TutorialPanel.tscn, mounted into the overlay and seated inside the HUD's
# Safe/UI. The overlay either takes the tap to advance or, at the last step of
# a phase, lets it through to the real button -- and to every other HUD button,
# which then answers it as a wrong tap (_tutorial_refuses).

## The source of one function, from its `func` line to the next.
func _function_body(name: String) -> String:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	return src.get_slice("func %s(" % name, 1).get_slice("\nfunc ", 0)


func test_the_tutorial_card_is_the_shared_panel_not_a_runtime_build() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(_function_body("_build_tutorial_panel").contains(
			"TutorialPanel.mount(tutorial_panel_scene, color_rect, click_area)"),
		"the card is the shared TutorialPanel scene, mounted in the overlay")
	for gone: String in ["PanelContainer.new(", "HSeparator.new(", "_tutorial_title_label",
			"_tutorial_body_label", "_tutorial_panel_should_center"]:
		assert_false(src.contains(gone), "Lobby.gd still carries %s" % gone)
	assert_true(src.contains(
			'@export var tutorial_panel_scene: PackedScene = preload("res://Scenes/UI/TutorialPanel.tscn")'),
		"the scene is an export, so it can be swapped in the inspector")


func test_every_step_goes_through_the_panel_with_its_number_and_count() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(_function_body("_show_step").contains(
			"_tutorial_panel.show_step(step.title, step.text, prompt, index + 1, current_phase_steps.size())"),
		"each step fills the card via show_step with its 1-based number and the phase's step count")
	assert_false(src.contains("(%d/%d)"),
		"the panel's pill is the step counter; a title prefix would count the steps twice")


func test_the_card_and_arrow_are_seated_inside_the_huds_safe_ui() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("@onready var tutorial_safe_ui: Control = $Safe/UI"),
		"the bounds are the HUD's own Safe/UI")
	assert_true(_lobby.get_node_or_null("Safe/UI") is Control, "and the scene has one")
	var seating := _function_body("_position_tutorial_panel")
	assert_true(seating.contains(
			"TutorialPanel.place_step(_tutorial_panel, tutorial_safe_ui, color_rect, _step_targets, _tutorial_arrow)"),
		"the card and the arrow are seated by the shared placement")
	assert_false(seating.contains("get_viewport_rect"), "with no raw viewport math")


# ----------------------------------- the tutorial shows, and points at the HUD
#
# 2026-10-01. The scene authors the tutorial overlay hidden, so the classroom shows
# in the editor, and an editor save on 2026-09-10 baked that state in while nothing
# in code ever turned the overlay on: the Lobby tutorial (phase 1 before
# StudentCard, phase 2 after) ran unseen for three weeks. The first-visit path,
# Lobby._start_tutorial, now shows it. Lobby.gd is not @tool, so its _ready cannot
# run in this suite; the path's order is pinned by source scan, as above.

## The first-visit path shows the overlay itself, before it starts step one, so the
## scene's authored `visible = false` no longer decides whether the tutorial is seen.
func test_the_first_visit_path_shows_the_overlay_before_step_one() -> void:
	var start := _function_body("_start_tutorial")
	var shown_at := start.find("color_rect.show()")
	var first_step_at := start.find("_show_step(0)")
	assert_true(shown_at >= 0, "the tutorial path shows the overlay in code")
	assert_true(first_step_at >= 0, "and starts step one there")
	assert_true(shown_at < first_step_at, "and shows the overlay before step one, not after it")
	assert_false(start.contains("color_rect.hide()"), "the path that teaches never hides it")
	var ready := _function_body("_ready")
	assert_eq(ready.count("_start_tutorial()"), 1, "_ready takes the first-visit path exactly once")
	var completed_at := ready.find("GameState.lobby_tutorial_completed or GameState.minggu_ke > 1")
	assert_true(completed_at >= 0, "_ready still gates on a finished tutorial or a later week")
	assert_true(ready.find("_start_tutorial()") > ready.find("\t\treturn", completed_at),
		"and starts the tutorial only once that gate has returned")


## The two ways out of the tutorial still hide the overlay: a returning player never
## sees it, and finishing the last step takes it down.
func test_the_completed_path_and_the_finish_still_hide_the_overlay() -> void:
	var ready := _function_body("_ready")
	var completed_at := ready.find("GameState.lobby_tutorial_completed or GameState.minggu_ke > 1")
	var completed_path := ready.substr(completed_at, ready.find("_start_tutorial()") - completed_at)
	assert_true(completed_path.contains("color_rect.hide()"), "a returning player's Lobby hides the overlay")
	assert_true(completed_path.contains("tutorial_active = false"), "and marks the tutorial over")
	var finish := _function_body("_end_tutorial")
	assert_true(finish.contains("color_rect.hide()"), "finishing the last step hides the overlay")
	assert_true(finish.contains("tutorial_active = false"), "and marks the tutorial over")


## A quoted GDScript string: runs of characters that are neither a quote nor a
## backslash, and backslash escapes. Four of them, comma-separated inside square
## brackets, are one default step: title, text, target node, prompt.
const _STEP_ROW := "\\[\"((?:[^\"\\\\]|\\\\.)*)\",\\s*\"((?:[^\"\\\\]|\\\\.)*)\",\\s*\"((?:[^\"\\\\]|\\\\.)*)\",\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\]"
## The target of each default step, phase by phase; "" is a step that highlights
## nothing. Phase 1 ends on the button that leaves for StudentCard, phase 2 on the
## one that leaves for AturJadwal.
const _PHASE1_TARGETS := ["", "Student"]
const _PHASE2_TARGETS := ["", "Inventory", "ReportStudent", "Koperasi", "Jadwal"]


## The default steps the Lobby runs, as [title, text, target, prompt] rows, one
## Array per phase: the rows before `var p2` in _populate_default_tutorial_steps
## are phase 1's, the rest phase 2's.
func _default_steps() -> Array:
	var body := _function_body("_populate_default_tutorial_steps")
	var split_at := body.find("var p2")
	var row_pattern := RegEx.create_from_string(_STEP_ROW)
	var phases: Array = []
	for chunk: String in [body.substr(0, split_at), body.substr(split_at)]:
		var rows: Array = []
		for found: RegExMatch in row_pattern.search_all(chunk):
			rows.append([found.get_string(1), found.get_string(2), found.get_string(3), found.get_string(4)])
		phases.append(rows)
	return phases


## True when `node`, or any ancestor up to the Lobby, is authored hidden. The
## Lobby's own _ready never runs here, so this reads the scene as saved: the
## Student and Jadwal buttons it shows and hides per phase are not in play.
func _hidden_in_lobby(node: Node) -> bool:
	var at: Node = node
	while at != null:
		if at is CanvasItem and not (at as CanvasItem).visible:
			return true
		if at == _lobby:
			return false
		at = at.get_parent()
	return false


## The scene authors no steps of its own, so the defaults in
## _populate_default_tutorial_steps are the ones a player sees.
func test_the_scene_authors_no_tutorial_steps() -> void:
	var scene_src := FileAccess.get_file_as_string(_SCENE_PATH)
	for exported: String in ["tutorial_phase1_steps", "tutorial_phase2_steps"]:
		assert_false(scene_src.contains(exported), "Lobby.tscn overrides %s" % exported)


## Every step's target resolves to a live button of the redesigned book HUD (the
## 2026-09-27 scrapbook pass), and is the tile the step's own words are about.
## Pinned as a list, so a retired or renamed tile fails here instead of quietly
## leaving a step with no spotlight.
func test_each_tutorial_step_targets_the_hud_button_its_text_is_about() -> void:
	var phases: Array = _default_steps()
	var phase_one: Array = phases[0]
	var phase_two: Array = phases[1]
	assert_eq(phase_one.size(), 2, "phase 1 has two steps (the rows were read from the source)")
	assert_eq(phase_two.size(), 5, "phase 2 has five steps (the rows were read from the source)")
	var book := _lobby.get_node_or_null("%BookHud") as Control
	assert_true(book != null, "the book HUD the steps point into exists")
	if book == null:
		return
	var wanted: Array = [_PHASE1_TARGETS, _PHASE2_TARGETS]
	for phase: int in 2:
		var rows: Array = phases[phase]
		var expected: Array = wanted[phase]
		var targets := PackedStringArray()
		for row: Array in rows:
			targets.append(String(row[2]))
		assert_eq(",".join(targets), ",".join(PackedStringArray(expected)),
			"phase %d's step targets" % (phase + 1))
		for row: Array in rows:
			if row[2] != "":
				_check_step_target(row, book)


## One step row's target: a visible, enabled Button inside the book, whose caption
## (lower-cased, without a trailing "!") appears in the step's title, text or prompt.
func _check_step_target(row: Array, book: Control) -> void:
	var target_name: String = row[2]
	var button := _lobby.get_node_or_null("%" + target_name) as Button
	assert_true(button != null, "%s: no Button of that unique name in the Lobby" % target_name)
	if button == null:
		return
	assert_true(book.is_ancestor_of(button), "%s sits in the book HUD" % target_name)
	assert_false(_hidden_in_lobby(button), "%s and every ancestor are authored visible" % target_name)
	assert_false(button.disabled, "%s is authored enabled" % target_name)
	var caption := button.text.to_lower().trim_suffix("!")
	var spoken := ("%s %s %s" % [row[0], row[1], row[3]]).to_lower()
	assert_true(caption != "" and spoken.contains(caption),
		"%s wears the caption \"%s\", which its step never mentions" % [target_name, button.text])


## The Lobby tutorial now shows to every new player, so its copy is one voice
## ("kamu" / "-mu", never "anda" or "kalian") in standard words: "di mana" apart,
## "barang" for items, "rapor" (the button's own caption) for the report, "statistik"
## for stats, and no "customisasi".
func test_the_tutorial_copy_is_one_voice_in_standard_indonesian() -> void:
	var spoken := ""
	for rows: Array in _default_steps():
		for row: Array in rows:
			spoken += " %s %s %s" % [row[0], row[1], row[3]]
	spoken = spoken.to_lower()
	var drift := RegEx.create_from_string("\\b(anda|kalian|dimana|disini|silahkan|items?|raport|stats?|customisasi|ampu)\\b")
	var found := drift.search(spoken)
	assert_true(found == null, "the Lobby tutorial still says \"%s\"" % (found.get_string() if found != null else ""))
	assert_true(spoken.contains("muridmu") and spoken.contains("barangmu"),
		"and it speaks to the player as -mu (the rows were read from the source)")
	var first: String = _default_steps()[0][0][1]
	assert_true(first.contains("Sebelum mulai mengajar") and first.contains("mari kita kenali dulu fasilitasnya"),
		"step 1 is a whole sentence: its \"Sebelum ...\" clause has its main clause")


## Each phase's last step names the button that leaves the Lobby, and the overlay lets
## a tap through to it, in either phase. Phase 2 once kept the overlay catching taps,
## so the first press on JADWAL only ended the tutorial and the prompt ("Tekan tombol
## 'Jadwal' untuk lanjut!") was wrong about it.
func test_the_last_step_of_either_phase_passes_taps_through_to_its_button() -> void:
	var step := _function_body("_show_step")
	assert_false(step.contains("returned_from_student_card"),
		"the last-step branch does not ask which phase it is")
	var last_at := step.find("if index == current_phase_steps.size() - 1:")
	var else_at := step.find("\telse:", last_at)
	assert_true(last_at >= 0 and else_at > last_at, "a branch for the last step, then the rest")
	var last_step := step.substr(last_at, else_at - last_at)
	assert_true(last_step.contains("color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE"),
		"the overlay passes the tap on")
	assert_true(last_step.contains("click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE"),
		"and so does its click catcher")
	assert_true(last_step.contains("(_step_targets[0] as BaseButton).disabled = false"),
		"the step's own first target is enabled, whichever button that is")
	assert_false(last_step.contains("student_button"), "no button is hard-coded into it")
	var other_steps := step.substr(else_at, step.find("\n\n", else_at) - else_at)
	assert_true(other_steps.contains("color_rect.mouse_filter = Control.MOUSE_FILTER_STOP")
			and other_steps.contains("click_area.mouse_filter = Control.MOUSE_FILTER_STOP"),
		"every earlier step still takes the tap to advance")


## Pressing JADWAL during the tutorial ends it (phase 2's last step has no tap-anywhere
## to do it), before leaving for AturJadwal. Pressing STUDENT does not: phase 1 ends on
## the trip to StudentCard and phase 2 follows it.
func test_pressing_jadwal_ends_an_active_tutorial_and_student_does_not() -> void:
	var jadwal := _function_body("_on_jadwal_pressed")
	var gate_at := jadwal.find("if tutorial_active:")
	assert_true(gate_at >= 0, "JADWAL's press asks whether the tutorial is still on")
	var ends_at := jadwal.find("_end_tutorial()", gate_at)
	assert_true(ends_at > gate_at, "and ends it if so")
	assert_true(ends_at < jadwal.find("Transition.change_scene("), "before the scene changes")
	assert_false(_function_body("_on_student_pressed").contains("_end_tutorial()"),
		"STUDENT's press leaves phase 2 still to come")


## The HUD buttons the tutorial never points at, by handler. The last step of
## either phase lets taps through the overlay, so these are reachable then.
const _TUTORIAL_GATED_HANDLERS := {
	"_on_koperasi_pressed": "koperasi_button",
	"_on_inventory_pressed": "inventory_button",
	"_on_report_student_pressed": "report_student_button",
	"_on_achievement_pressed": "achievement_button",
	"_on_settings_pressed": "settings_button",
	"_on_skin_switch_pressed": "skin_switch_button",
	"_on_daily_login_pressed": "daily_login_btn",
}
## What each of those handlers does once it lets a tap through.
const _HANDLER_ACTIONS := ["Transition.change_scene(", "_show_daily_reward()", "instantiate()"]

## At the last step of either phase every HUD button can be tapped, not just the
## one the step names; Koperasi, say, left the Lobby with the tutorial unfinished,
## and phase 2 replayed on return. Each such button asks _tutorial_refuses first,
## which answers the tap as the forced steps do and drops it.
func test_other_hud_buttons_refuse_a_tap_while_the_tutorial_is_up() -> void:
	for handler: String in _TUTORIAL_GATED_HANDLERS:
		var body := _function_body(handler)
		var gate_at := body.find("_tutorial_refuses(%s)" % _TUTORIAL_GATED_HANDLERS[handler])
		assert_true(gate_at >= 0, "%s asks the tutorial before acting" % handler)
		var acted := false
		for action: String in _HANDLER_ACTIONS:
			var action_at := body.find(action)
			if action_at >= 0:
				acted = true
				assert_true(gate_at < action_at, "%s asks before %s" % [handler, action])
		assert_true(acted, "%s still does something once allowed (not vacuous)" % handler)
	var refuses := _function_body("_tutorial_refuses")
	assert_true(refuses.contains("if not tutorial_active or _step_targets.has(button):"),
		"only a tap during the tutorial, on a button its step does not point at, is refused")
	assert_true(refuses.contains("TutorialPanel.answer_wrong_tap(wanted, [button])")
			and refuses.contains("_step_targets[0]"),
		"with the shared wrong-tap answer: the step's button shakes, the tapped one dims")
	assert_false(refuses.contains("play_sfx("),
		"the answer plays the cue itself; a second local cue would read as a double fire")
	for target_handler: String in ["_on_student_pressed", "_on_jadwal_pressed"]:
		assert_false(_function_body(target_handler).contains("_tutorial_refuses"),
			"%s is a step's own button; it is never refused" % target_handler)


## `_start_tutorial` makes the last step's button visible in its own phase: Student in
## phase 1, Jadwal in phase 2 (the two share a spot on the book's page, and the script
## shows one and hides the other). The scene alone cannot show that, since it authors
## both visible.
func test_each_phase_shows_the_button_its_last_step_points_at() -> void:
	var start := _function_body("_start_tutorial")
	var phase2_at := start.find("if GameState.returned_from_student_card:")
	var phase1_at := start.find("\telse:", phase2_at)
	var phase1_end := start.find("_connect_hud_buttons()", phase1_at)
	assert_true(phase2_at >= 0 and phase1_at > phase2_at and phase1_end > phase1_at,
		"phase 2's branch, then phase 1's, then the shared wiring")
	var phase_one_part := start.substr(phase1_at, phase1_end - phase1_at)
	var phase_two_part := start.substr(phase2_at, phase1_at - phase2_at)
	var phases: Array = _default_steps()
	var phase_one: Array = phases[0]
	var phase_two: Array = phases[1]
	var last_one: Array = phase_one[phase_one.size() - 1]
	var last_two: Array = phase_two[phase_two.size() - 1]
	assert_eq(last_one[2], "Student", "phase 1 ends on the button that leaves for StudentCard")
	assert_eq(last_two[2], "Jadwal", "phase 2 ends on the button that leaves for AturJadwal")
	assert_true(phase_one_part.contains("student_button.visible = true"), "phase 1 shows Student")
	assert_true(phase_two_part.contains("jadwal_button.visible = true"), "phase 2 shows Jadwal")
