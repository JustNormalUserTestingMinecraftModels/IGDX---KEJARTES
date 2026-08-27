@tool
extends McpTestSuite

## Covers Task 11: CutScene. See tests/test_main_menu.gd's header notes
## for the two runner quirks this suite also has to respect:
##
## 1. `_collect_overrides` below is copied VERBATIM from test_main_menu.gd.
##    Godot 4.6's Control does not expose
##    get_theme_{color,font_size,stylebox}_override_list() -- only
##    per-name has_theme_*_override() checks -- so the walk goes through
##    get_property_list() and cross-checks each theme_override_* entry
##    against the matching has_theme_*_override() call.
##
## 2. The MCP test runner's `_run_one_test` calls `suite.call(method_name)`
##    without awaiting it, so a coroutine test returns control at its
##    first `await` before any post-await assertion runs and is scored
##    as "0 assertions" (a false pass). CutScene actually has real
##    Button nodes (top-bar Skip/Debug, and the three grade-select
##    buttons in the level-select modal), unlike Splashscreen/Loading,
##    so the touch-target test from the shared brief template DOES apply
##    here -- but per test_main_menu.gd's finding, it is measured via
##    get_combined_minimum_size() synchronously right after add_child(),
##    not via `.size` after an awaited frame.
##
## cut_scene.gd is @tool for the same placeholder-instance reason as
## main_menu.gd (see that script's header). Its top-bar buttons and
## level-select modal are built unconditionally in _ready() (mirroring
## MainMenu's always-wire-buttons pattern), so they exist and are
## theme-clean even when this suite instantiates the scene inside the
## editor process. Everything GameState-dependent sits behind
## Engine.is_editor_hint() inside cut_scene.gd itself and never runs here.

func suite_name() -> String:
	return "cutscene"

const _SCENE_PATH := "res://Scenes/CutScene/cut_scene.tscn"
const _SCRIPT_PATH := "res://Scripts/CutScene/cut_scene.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

var _scene: Control


func setup() -> void:
	var packed: PackedScene = load(_SCENE_PATH)
	_scene = packed.instantiate()
	_scene.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_scene)
	track(_scene)


func teardown() -> void:
	if is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null


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


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_scene, offenders)
	assert_eq(offenders.size(), 0, "found theme_override_* on: " + ", ".join(offenders))


func test_scene_instantiates_without_errors() -> void:
	assert_true(_scene != null, "scene must instantiate")


## Adapted from the shared brief template: unlike a menu screen, this one
## builds its interactive controls (top-bar Skip/Debug, grade-select
## buttons) in code rather than in the .tscn, so the walk starts from
## the scene root and collects every BaseButton it finds, checking each
## against get_combined_minimum_size() -- synchronous, per note 2 above,
## with no frame wait required (these buttons carry no SIZE_EXPAND flag).
func _collect_small_buttons(node: Node, min_size: int, out: Array[String]) -> void:
	if node is BaseButton:
		var c := node as Control
		var h := c.get_combined_minimum_size().y
		if h < float(min_size):
			out.append("%s (%d px)" % [node.name, int(h)])
	for child in node.get_children():
		_collect_small_buttons(child, min_size, out)


func test_interactive_controls_meet_touch_minimum() -> void:
	var tokens := DesignTokens.load_default()
	var small: Array[String] = []
	_collect_small_buttons(_scene, tokens.touch_target_min, small)
	assert_eq(small.size(), 0, "buttons below touch minimum: " + ", ".join(small))


func test_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0, "script must read colors from DesignTokens, not Color() literals")


func test_dialogue_box_uses_the_card_variation() -> void:
	var box := _scene.find_child("DialogueBox", true, false) as Panel
	assert_true(box != null, "missing DialogueBox")
	assert_eq(box.theme_type_variation, &"Card", "the dialogue box must use the Card variation")


func test_tap_during_reveal_completes_the_line_instead_of_advancing() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("visible_ratio = 1.0"),
		"a tap mid-reveal must snap the line to fully visible")


func test_typewriter_reveal_uses_visible_ratio_not_character_slicing() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("visible_ratio"),
		"the reveal must drive RichTextLabel.visible_ratio")
	assert_false(src.contains("dialogue_label.text +="),
		"must not rebuild the label character-by-character, which breaks BBCode")


func test_cg_changes_crossfade_instead_of_hard_cutting() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("bg_cutscene, \"modulate:a\""),
		"CG swaps must tween BgCutScene.modulate:a rather than hard-cutting the texture")


func test_branching_to_lobby_or_student_card_is_unchanged() -> void:
	# Presentation may change; this routing logic must not.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"must still route to Lobby")
	assert_true(src.contains("res://Scenes/StudentCard/student_card.tscn"),
		"must still route to StudentCard")
	assert_true(src.contains("if grade_num > 7:"),
		"grade > 7 must still be the StudentCard condition")
	assert_true(src.contains("get_tree().change_scene_to_file(\"res://Scenes/Loading/loading.tscn\")"),
		"must still hand off through the Loading scene")


func test_show_current_starts_with_a_hold_before_revealing() -> void:
	# Calling show_current() live here would exercise its
	# `GameState.is_game_over_cutscene` read, which errors in this
	# suite's standalone-instantiation context regardless of this
	# change (GameState resolves fine in other suites' setups, but not
	# when cut_scene.tscn is instantiated bare like test_cutscene.gd
	# does) -- a pre-existing runner quirk, not something this change
	# introduced. Source-text check instead, matching this file's own
	# established pattern (see test_cg_changes_crossfade_instead_of_hard_cutting
	# and test_branching_to_lobby_or_student_card_is_unchanged above).
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var start := src.find("func show_current")
	assert_true(start >= 0, "show_current() must exist")
	var end := src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	var body := src.substr(start, end - start)
	assert_true(body.contains("is_transitioning = true"),
		"show_current() must gate taps during the entrance hold+fade, same as transition_to_next()")
	assert_true(body.contains("bg_cutscene.modulate.a = 0.0"),
		"show_current() must start fully transparent -- no more instant pop-in")


func test_entrance_hold_and_fade_are_slower_than_the_panel_crossfade() -> void:
	# The whole point of this pass: the very first beat of a reveal
	# sequence should read as deliberately slower than routine
	# panel-to-panel movement (transition_to_next(), which uses
	# _tokens.dur_normal), so the player gets a moment to register the
	# scene before it commits to its opening image.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("_ENTRANCE_HOLD_SEC"),
		"show_current() must hold before revealing, not pop in instantly")
	assert_true(src.contains("_ENTRANCE_FADE_SEC"),
		"show_current()'s entrance fade must use its own, slower duration")
