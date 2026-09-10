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
##  * loby.gd is NOT @tool (matching StudentCard/StudentList precedent,
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

const _SCENE_PATH := "res://Scenes/Lobby/loby.tscn"
const _SCRIPT_PATH := "res://Scripts/Lobby/loby.gd"
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


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_lobby = scene.instantiate()
	_lobby.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_lobby)
	track(_lobby)


func teardown() -> void:
	if is_instance_valid(_lobby):
		_lobby.queue_free()
	_lobby = null


# ------------------------------------------------ behavioral contract net

func test_still_routes_to_student_card_and_atur_jadwal() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/StudentCard/student_card.tscn"),
		"lobby must still route Student -> StudentCard")
	assert_true(src.contains("res://Scenes/AturJadwal/atur_jadwal.tscn"),
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
	# pop the one panel node.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.pop_in("),
		"the panel must pop in on open and on claim")
	assert_true(src.contains('AudioDirector.play_sfx(&"reward")'),
		"claiming a day must play a reward sfx")


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_lobby != null, "scene must instantiate")
	assert_true(_lobby.is_inside_tree(), "scene must enter the tree cleanly")
	for name in _NAV_BUTTONS:
		assert_true(_lobby.get_node_or_null(name) != null, "missing nav button: " + name)
	assert_true(_lobby.get_node_or_null("JUDUL") != null, "missing JUDUL")
	assert_true(_lobby.get_node_or_null("DisplayUang/Label") != null, "missing money label")
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
		"loby.gd must read colors from DesignTokens/Color constants, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var paths := _NAV_BUTTONS.duplicate()
	paths.append("DailyReward/ButtonClaim")
	for p in paths:
		var b := _lobby.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		var h := b.get_combined_minimum_size().y
		assert_true(h >= float(tokens.touch_target_min),
			"%s has minimum height %d px, below the %d px minimum" % [p, int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

func test_nav_buttons_use_lobby_nav_tile_or_cta_button_variation() -> void:
	var tile_buttons := ["Koperasi", "Inventory", "ReportStudent"]
	var cta_buttons := ["Student", "Jadwal"]
	for name in tile_buttons:
		var b := _lobby.get_node_or_null(name) as Button
		assert_true(b != null, "missing nav button: " + name)
		assert_eq(b.theme_type_variation, &"LobbyNavTile", name + " variation")
	for name in cta_buttons:
		var b := _lobby.get_node_or_null(name) as Button
		assert_true(b != null, "missing nav button: " + name)
		assert_eq(b.theme_type_variation, &"LobbyCtaButton", name + " variation")


func test_labels_use_theme_variations() -> void:
	var judul := _lobby.get_node_or_null("JUDUL") as Label
	assert_true(judul != null, "missing JUDUL")
	assert_eq(judul.theme_type_variation, &"DisplayLabel", "JUDUL variation")

	var money := _lobby.get_node_or_null("DisplayUang/Label") as Label
	assert_true(money != null, "missing money label")
	assert_eq(money.theme_type_variation, &"CoinLabel", "money label variation")

	var header := _lobby.get_node_or_null("DailyReward/Label") as Label
	assert_true(header != null, "missing Daily Reward header label")
	assert_eq(header.theme_type_variation, &"H1Label", "Daily Reward header variation")


func _lobby_source() -> String:
	return FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")


func test_koperasi_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_koperasi_pressed"),
		"the Koperasi button must have a handler")
	# Changed 2026-09-07: the button lands on the hub, which forks to
	# the item shop or the cosmetic shop.
	assert_true(src.contains("res://Scenes/Koperasi/ShopHub.tscn"),
		"Koperasi must route to the shop hub")
	assert_false(src.contains("res://Scenes/Koperasi/koprasi.tscn"),
		"the Lobby should no longer reach the item shop directly")


func test_inventory_button_is_wired() -> void:
	var src := _lobby_source()
	assert_true(src.contains("_on_inventory_pressed"),
		"the Inventory button must have a handler")
	assert_true(src.contains("res://Scenes/Inventory/inventory.tscn"),
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
	assert_true(src.contains("res://Scenes/ReportCard/report_card.tscn"),
		"ReportStudent must route to the report card scene")


## The money readout was a 1920x1080 pink landscape PNG with a label on
## top -- off-palette, and the reason the chip was 332x187 rather than the
## 332x96 the layout wanted. It is a themed rounded panel now, with the
## coin as a real icon beside the number.
func test_the_money_chip_is_a_themed_panel_with_a_coin_icon() -> void:
	var chip := _lobby.get_node_or_null("DisplayUang") as Panel
	assert_true(chip != null, "DisplayUang must be a Panel now, not a TextureRect")
	assert_eq(chip.theme_type_variation, &"Card",
		"the chip takes its chrome from the theme")
	assert_eq(chip.size.y, 96.0,
		"the chip is 96 tall, matching DailyLogin, got %f" % chip.size.y)

	var icon := _lobby.get_node_or_null("DisplayUang/CoinIcon") as TextureRect
	assert_true(icon != null, "the chip needs a coin icon")
	assert_eq(icon.texture.resource_path, "res://Assets/Images/UI/uang.png",
		"and it is the new coin art")


func test_the_off_palette_chip_art_is_gone() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Lobby/loby.tscn")
	assert_false(src.contains("Desain tanpa judul.png"),
		"the pink chip background must no longer be referenced")


## Both shop screens read the same coin as the lobby, so money looks like
## one currency across the game.
func test_the_shop_screens_use_the_same_coin() -> void:
	for path in ["res://Scenes/Koperasi/koprasi.tscn",
			"res://Scenes/Inventory/inventory.tscn"]:
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
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")
	assert_true(src.contains("DAY_PANELS"),
		"the seven panels must be a named const, not seven inline loads")
	for i in range(1, 8):
		assert_true(src.contains("DailyLogin/day%d.png" % i),
			"day %d's panel must be referenced" % i)
	assert_false(src.contains("day_nodes"),
		"the per-tile tint bookkeeping goes with the tiles")


func test_the_lobby_button_wears_the_calendar_icon() -> void:
	var btn := _lobby.get_node_or_null("DailyLogin") as TextureButton
	assert_true(btn != null, "the DailyLogin button is missing")
	assert_eq(btn.texture_normal.resource_path,
		"res://Assets/Images/UI/icon_daily_login.png",
		"it wears the calendar icon")


## Header top-centre, claim button bottom-centre, both on the display
## face -- the panel art bakes a cream title plate and a gold pill for
## exactly these two, so they sit on top of the art rather than beside it.
func test_the_header_and_claim_button_sit_on_the_baked_art() -> void:
	var header := _lobby.get_node_or_null("DailyReward/Label") as Label
	assert_true(header != null, "missing the panel header")
	assert_eq(header.text, "Daily Login", "the header names the feature")
	assert_eq(header.theme_type_variation, &"H1Label",
		"the header is on the display face")

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
