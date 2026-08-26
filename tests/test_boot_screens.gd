@tool
extends McpTestSuite

## Covers both boot screens (Task 10): Splashscreen and Loading. See
## tests/test_main_menu.gd's header notes for the two runner quirks this
## suite also has to respect:
##
## 1. `_collect_overrides` below is copied VERBATIM from test_main_menu.gd.
##    Godot 4.6's Control does not expose
##    get_theme_{color,font_size,stylebox}_override_list() -- only
##    per-name has_theme_*_override() checks -- so the walk goes through
##    get_property_list() and cross-checks each theme_override_* entry
##    against the matching has_theme_*_override() call.
##
## 2. Neither scene has a real button, so
##    test_interactive_controls_meet_touch_minimum from the shared brief
##    template does not apply as written -- there is nothing with a
##    combined minimum size to measure against touch_target_min. It is
##    intentionally omitted rather than faked into a vacuous pass.
##
## Both scene scripts are @tool (see their own header notes for why):
## the MCP test runner instantiates scenes from inside the editor
## process, and a plain (non-@tool) script attached to a scene root
## becomes a placeholder instance there, which breaks traversal-based
## checks like _collect_overrides the moment it reaches that node.

func suite_name() -> String:
	return "boot_screens"

const _SPLASH_SCENE := "res://Scenes/Splashscreen/Splashscreen.tscn"
const _SPLASH_SCRIPT := "res://Scripts/Splashscreen/splashscreen.gd"
const _LOADING_SCENE := "res://Scenes/Loading/loading.tscn"
const _LOADING_SCRIPT := "res://Scripts/Loading/loading.gd"

var _splash: Control
var _loading: Control


func setup() -> void:
	_splash = (load(_SPLASH_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(_splash)
	track(_splash)

	_loading = (load(_LOADING_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(_loading)
	track(_loading)


func teardown() -> void:
	if is_instance_valid(_splash):
		_splash.queue_free()
	_splash = null
	if is_instance_valid(_loading):
		_loading.queue_free()
	_loading = null


## Copied verbatim from tests/test_main_menu.gd -- see that file's header
## note for why the naive get_theme_*_override_list() approach doesn't
## exist on Godot 4.6's Control and this per-name-check walk is the fix.
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


# ---------------------------------------------------------------------
# Splashscreen
# ---------------------------------------------------------------------

func test_splashscreen_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_splash, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func test_splashscreen_instantiates_without_errors() -> void:
	assert_true(_splash != null, "scene must instantiate")


func test_splashscreen_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string(_SPLASH_SCRIPT)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"script must read colors from DesignTokens, not Color() literals")


func test_splashscreen_is_wrapped_in_a_safe_area() -> void:
	var safe := _splash.find_child("SafeArea", true, false)
	assert_true(safe != null, "top-level content must sit inside a SafeAreaMargin")
	assert_true(safe is SafeAreaMargin, "must be a SafeAreaMargin")


func test_splashscreen_labels_use_theme_variations() -> void:
	var title := _splash.find_child("TitleLabel", true, false) as Label
	assert_true(title != null, "missing TitleLabel")
	assert_eq(title.theme_type_variation, &"DisplayLabel",
		"title must use the DisplayLabel variation")
	var hint := _splash.find_child("HintLabel", true, false) as Label
	assert_true(hint != null, "missing HintLabel")
	assert_eq(hint.theme_type_variation, &"CaptionLabel",
		"hint must use the CaptionLabel variation")


func test_splashscreen_routes_via_game_state_and_transition() -> void:
	# Function must not change: still sets GameState.next_scene then
	# hands off to Loading via Transition.
	var src := FileAccess.get_file_as_string(_SPLASH_SCRIPT)
	assert_true(src.contains("GameState.next_scene"),
		"splashscreen must set GameState.next_scene as it does today")
	assert_true(src.contains("res://Scenes/Loading/loading.tscn"),
		"splashscreen must still transition to the Loading scene")


# ---------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------

func test_loading_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_loading, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func test_loading_instantiates_without_errors() -> void:
	assert_true(_loading != null, "scene must instantiate")


func test_loading_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string(_LOADING_SCRIPT)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"script must read colors from DesignTokens, not Color() literals")


func test_loading_controls_use_theme_variations() -> void:
	var bar := _loading.find_child("LoadingBar", true, false) as ProgressBar
	assert_true(bar != null, "missing LoadingBar")
	assert_eq(bar.theme_type_variation, &"StatBar",
		"the progress bar must use the StatBar variation")
	var label := _loading.find_child("LoadingLabel", true, false) as Label
	assert_true(label != null, "missing LoadingLabel")
	assert_eq(label.theme_type_variation, &"TitleLabel",
		"the loading label must use the TitleLabel variation")


func test_loading_reads_its_target_from_game_state() -> void:
	var src := FileAccess.get_file_as_string(_LOADING_SCRIPT)
	assert_true(src.contains("GameState.next_scene"),
		"loading must route via GameState.next_scene as it does today")


func test_loading_uses_real_threaded_progress_not_a_fake_timer() -> void:
	var src := FileAccess.get_file_as_string(_LOADING_SCRIPT)
	assert_true(src.contains("load_threaded_get_status"),
		"the bar must reflect genuine load progress")
	assert_false(src.contains("tween_property(loading_bar, \"value\""),
		"must not fake progress with a fixed-duration tween")
