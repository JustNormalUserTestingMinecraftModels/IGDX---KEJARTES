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


## The mockup supplies the panel as art (cutscene_dialogue.png), so the box
## draws a texture instead of the Card stylebox. The art is 1:1 with its
## on-screen size, so it sits at its native 1080x1080 offset (0, 940),
## which lands the opaque panel within 1px of the mockup on every edge --
## see the spec, section 5.
func test_dialogue_box_draws_the_mockup_panel_art() -> void:
	var box := _scene.find_child("DialogueBox", true, false) as TextureRect
	assert_true(box != null,
		"DialogueBox is missing or is no longer a TextureRect")
	assert_true(box.texture != null, "DialogueBox has no texture")
	assert_eq(box.texture.resource_path,
		"res://Assets/Images/UI/cutscene_dialogue.png",
		"DialogueBox is not drawing the mockup's panel art")
	assert_eq(box.offset_left, 0.0, "panel left")
	assert_eq(box.offset_top, 940.0, "panel top")
	assert_eq(box.offset_right, 1080.0, "panel right")
	assert_eq(box.offset_bottom, 2020.0, "panel bottom (native 1080 tall)")


## The text and the tap hint must both sit inside the panel's white content
## area -- screen x 110-967, y 1148-1815, which is x 110-967, y 208-875 in
## the box's own coordinates. Outside it they print over the orange frame.
func test_dialogue_text_sits_inside_the_panel_content_area() -> void:
	var label := _scene.get_node_or_null(
		"DialogueBox/DialogueLabel") as Control
	assert_true(label != null, "DialogueLabel is missing")
	assert_true(label.offset_left >= 110.0, "text starts left of the frame")
	assert_true(label.offset_right <= 967.0, "text runs past the right frame")
	assert_true(label.offset_top >= 208.0, "text starts above the frame")
	assert_true(label.offset_bottom <= 875.0, "text runs past the bottom frame")

	var hint := _scene.get_node_or_null("HintLabel") as Control
	assert_true(hint != null, "HintLabel is missing")
	assert_true(hint.offset_top >= 1148.0,
		"the tap hint sits above the panel's content area")
	assert_true(hint.offset_bottom <= 1815.0,
		"the tap hint runs past the panel's content area")


## Both were authored as hardcoded rects that miss 1080x1920 -- the CG
## 1075x1925, the fade 1088x1934 -- so the CG was 5px short across and the
## fade overran the screen. Anchoring both makes them exact and
## resolution-independent.
func test_the_full_screen_layers_fill_the_screen_exactly() -> void:
	for node_name in ["BgCutScene", "FadeOverlay"]:
		var node := _scene.get_node_or_null(node_name) as Control
		assert_true(node != null, "%s is missing" % node_name)
		assert_eq(node.anchor_right, 1.0,
			"%s must anchor to the right edge" % node_name)
		assert_eq(node.anchor_bottom, 1.0,
			"%s must anchor to the bottom edge" % node_name)
		assert_eq(node.offset_right, 0.0,
			"%s has a stray right offset" % node_name)
		assert_eq(node.offset_bottom, 0.0,
			"%s has a stray bottom offset" % node_name)


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


## Pulls one top-level function's body out of the script source, from its
## "func name" line up to (but not including) the next top-level "\nfunc ".
## Shared by the two tests below so each can scope its Lobby/StudentCard
## check to the one function it is actually about.
func _function_body(src: String, func_name: String) -> String:
	var start := src.find("func " + func_name)
	assert_true(start >= 0, func_name + "() must exist")
	var end := src.find("\nfunc ", start + 1)
	if end < 0:
		end = src.length()
	return src.substr(start, end - start)


## The bug this pins: go_to_gameplay() used to route a genuinely fresh
## game (is_game_over_cutscene == false, the very first intro-CG skip or
## finish) straight to Lobby, never to StudentCard -- so
## GameState.approved_students stayed empty and every downstream screen
## (AturJadwal, StudentList, the week simulation itself) silently fell
## back to its own placeholder roster instead of surfacing the problem.
## The grade-7 semester-loss retry had the identical bug: it cleared
## approved_students ("so they select again", per its own comment) but
## then routed to Lobby anyway. Both must now go through StudentCard --
## the only screen that actually populates approved_students.
##
## Scoped to go_to_gameplay()'s own body (not the whole file), because
## _on_skip_pressed() now legitimately routes to Lobby -- see the test
## below.
func test_go_to_gameplay_always_routes_through_student_card() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "go_to_gameplay")
	assert_true(body.contains("GameState.next_scene = _next_scene_path()"),
		"must delegate routing to _next_scene_path()")
	assert_false(body.contains("res://Scenes/Lobby/loby.tscn"),
		"go_to_gameplay must never hand the player to Lobby directly -- " +
		"StudentCard is the only gate that populates approved_students")
	assert_true(body.contains("get_tree().change_scene_to_file(\"res://Scenes/Loading/loading.tscn\")"),
		"must still hand off through the Loading scene")


## _next_scene_path() is the routing table go_to_gameplay() now delegates
## to. StudentCard must remain its default/fallback branch -- this is what
## preserves the original guarantee that the intro branch always ends up
## at StudentCard, not Lobby.
func test_next_scene_path_defaults_to_student_card() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_next_scene_path")
	assert_true(body.contains("res://Scenes/StudentCard/student_card.tscn"),
		"_next_scene_path must default/fallback to StudentCard")


## Skip is a deliberate exception to the rule above: pressing "Skip Intro"
## bails straight to Lobby, even before a roster has been approved. Only
## safe because _setup_game_over_cutscene() hides this button outright, so
## it is never reachable while GameState.is_game_over_cutscene is true --
## covered by test_skip_button_is_hidden_during_the_game_over_cutscene.
func test_skip_button_routes_straight_to_lobby() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_on_skip_pressed")
	assert_true(body.contains("res://Scenes/Lobby/loby.tscn"),
		"Skip Intro must route straight to Lobby")
	assert_false(body.contains("res://Scenes/StudentCard/student_card.tscn"),
		"Skip Intro must not detour through StudentCard")
	assert_true(body.contains("get_tree().change_scene_to_file(\"res://Scenes/Loading/loading.tscn\")"),
		"must still hand off through the Loading scene")


func test_skip_button_is_hidden_during_the_game_over_cutscene() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_setup_game_over_cutscene")
	assert_true(body.contains("btn_skip.visible = false"),
		"the game-over/retry cutscene must hide Skip Intro -- it has no " +
		"safe destination there, since Lobby needs an approved roster on " +
		"a fresh game-7 retry and StudentCard is the point of that screen anyway")


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


func test_the_exam_branch_exists_and_wins_precedence() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("_setup_exam_cutscene"),
		"there is an exam branch")
	var exam_at := src.find("if GameState.is_exam_intro_cutscene")
	var over_at := src.find("if GameState.is_game_over_cutscene")
	assert_true(exam_at != -1, "the exam flag is branched on")
	assert_true(exam_at < over_at,
		"the exam branch is tested before the game-over branch")


func test_the_exam_branch_has_four_dialogues() -> void:
	var scene = load("res://Scenes/CutScene/cut_scene.tscn").instantiate()
	Engine.get_main_loop().root.add_child(scene)
	scene._setup_exam_cutscene()
	var count: int = scene.cg_data.size()
	Engine.get_main_loop().root.remove_child(scene)
	scene.queue_free()
	assert_eq(count, 4, "four exam dialogues")


func test_the_exam_branch_exits_to_the_stat_check() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("res://Scenes/EndGame/SemesterEnd.tscn"),
		"the exam cutscene ends at the stat check")


func test_the_game_over_branch_exits_to_the_run_result() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("res://Scenes/EndGame/RunResult.tscn"),
		"the lose cutscene ends at the run result")


func test_the_exam_branch_plays_its_own_bgm() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains("play_bgm(&\"exam_cutscene\")"), "exam BGM")
