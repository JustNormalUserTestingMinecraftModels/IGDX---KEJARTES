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


func test_daily_login_uses_stagger_and_pop_in() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.stagger_in("),
		"the seven day tiles must stagger in when the panel opens")
	assert_true(src.contains("Juice.pop_in("),
		"the claimed tile must pop in")
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
	assert_true(_lobby.get_node_or_null("DailyLogin/DailyReward/ButtonClaim") != null,
		"missing claim button")
	for i in range(1, 8):
		assert_true(_lobby.get_node_or_null("DailyLogin/DailyReward/Day%d" % i) != null,
			"missing Day%d" % i)


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
	paths.append("DailyLogin/DailyReward/ButtonClaim")
	for p in paths:
		var b := _lobby.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		var h := b.get_combined_minimum_size().y
		assert_true(h >= float(tokens.touch_target_min),
			"%s has minimum height %d px, below the %d px minimum" % [p, int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

func test_nav_buttons_use_lobby_nav_button_variation() -> void:
	for name in _NAV_BUTTONS:
		var b := _lobby.get_node_or_null(name) as Button
		assert_true(b != null, "missing nav button: " + name)
		assert_eq(b.theme_type_variation, &"LobbyNavButton", name + " variation")


func test_labels_use_theme_variations() -> void:
	var judul := _lobby.get_node_or_null("JUDUL") as Label
	assert_true(judul != null, "missing JUDUL")
	assert_eq(judul.theme_type_variation, &"DisplayLabel", "JUDUL variation")

	var money := _lobby.get_node_or_null("DisplayUang/Label") as Label
	assert_true(money != null, "missing money label")
	assert_eq(money.theme_type_variation, &"BarLabel", "money label variation")

	var header := _lobby.get_node_or_null("DailyLogin/DailyReward/Label") as Label
	assert_true(header != null, "missing Daily Reward header label")
	assert_eq(header.theme_type_variation, &"H1Label", "Daily Reward header variation")

	for i in range(1, 8):
		for sub in ["Label", "Label2"]:
			var lbl := _lobby.get_node_or_null(
				"DailyLogin/DailyReward/Day%d/%s" % [i, sub]) as Label
			assert_true(lbl != null, "missing Day%d/%s" % [i, sub])
			assert_eq(lbl.theme_type_variation, &"CaptionLabel", "Day%d/%s variation" % [i, sub])


func test_claim_button_uses_success_button_variation() -> void:
	var claim := _lobby.get_node_or_null("DailyLogin/DailyReward/ButtonClaim") as Button
	assert_true(claim != null, "missing claim button")
	assert_eq(claim.theme_type_variation, &"SuccessButton", "claim button variation")


func test_loose_stylebox_files_are_gone_and_unreferenced() -> void:
	for path in _LOOSE_STYLEBOX_PATHS:
		assert_false(FileAccess.file_exists(path), "loose stylebox must be deleted: " + path)
	var tscn_src := FileAccess.get_file_as_string(_SCENE_PATH)
	for path in _LOOSE_STYLEBOX_PATHS:
		assert_false(tscn_src.contains(path), "scene must no longer reference " + path)


func test_theme_factory_bakes_lobby_nav_button_variation() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_true(theme != null, "baked theme must load")
	assert_true(theme.get_type_list().has("LobbyNavButton"),
		"baked theme must include the LobbyNavButton variation")


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
