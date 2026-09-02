@tool
extends McpTestSuite

## SemesterEnd is the payoff/results screen (8th and final per-screen
## migration in the core-ui-polish plan) -- restyled and re-pointed as
## part of the end-of-grade-sequence plan. It no longer applies grade
## progression itself (that moved to RunResult) and now has exactly two
## routing destinations selected by _on_restart_pressed():
##   - WinScreen  (GameState.check_semester_passed() == true)
##   - CutScene   (failed -- also arms GameState.is_game_over_cutscene)
##
## Technique notes carried over from Tasks 9-16:
##  * This suite must itself be @tool or the runner reports it as broken.
##  * The runner calls `suite.call(name)` WITHOUT awaiting, so no test
##    here may be a coroutine.
##  * Control has no get_theme_*_override_list() in Godot 4.6; the
##    _collect_overrides helper is copied verbatim from test_main_menu.gd.
##  * Routing/behavioral-contract checks use source-text scanning (per
##    test_student_card.gd's precedent) rather than exercising the full
##    GameState-dependent branching logic live.
##  * SemesterEnd.gd is NOT @tool (verified empirically, matching
##    StudentCard/StudentList/Lobby precedent): _ready() reads the
##    GameState autoload, calls AudioDirector.play_bgm(), and kicks off
##    the reveal tween chain, none of which should fire just from the
##    editor's own test runner instantiating the scene. Confirmed the
##    hard way: a non-@tool script instantiated here gets a
##    PlaceholderScript instance, where a compiled dot-access like
##    `_screen.card_stagger` throws "Invalid access to property or key"
##    and calling `_screen._slam_stamp(...)` throws "Attempt to call a
##    method on a placeholder instance" -- see the notes on the two
##    reveal-timing tests below for how those are verified instead.

const _SCENE_PATH := "res://Scenes/EndGame/SemesterEnd.tscn"
const _SCRIPT_PATH := "res://Scripts/EndGame/SemesterEnd.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "semester_end"


var _screen: Control


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_screen = scene.instantiate()
	_screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_screen)
	track(_screen)


func teardown() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


# ------------------------------------------------ behavioral contract net

func test_it_exits_to_the_win_screen_when_the_semester_passed() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/EndGame/WinScreen.tscn"),
		"a pass leads to the win screen")


func test_it_exits_to_the_lose_cutscene_when_the_semester_failed() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.is_game_over_cutscene = true"),
		"a fail arms the lose cutscene")
	assert_true(src.contains("res://Scenes/CutScene/cut_scene.tscn"),
		"a fail leads to the cutscene")


func test_grade_progression_has_moved_off_this_screen() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("GameState.current_grade += 1"),
		"the stat check no longer advances the grade -- RunResult does")


func test_the_backdrop_replaced_the_flat_color_rect() -> void:
	assert_true(_screen.get_node_or_null("Backdrop") is TextureRect,
		"there is a blurred backdrop")
	assert_true(_screen.get_node_or_null("Scrim") is Panel,
		"there is a themed scrim over it")
	assert_true(_screen.get_node_or_null("Background") == null,
		"the flat dark ColorRect is gone")


func test_the_page_dots_are_authored_in_the_scene() -> void:
	var dots = _screen.get_node_or_null(
		"MarginContainer/VBoxContainer/PageIndicator")
	assert_eq(dots.get_child_count(), 4,
		"four page dots authored in the .tscn, not built at runtime")


func test_the_copy_dropped_the_emoji_clutter() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for emoji in ["🎓", "❌", "⚠️", "🎉", "🏆"]:
		assert_false(src.contains(emoji), "no %s in the copy" % emoji)


# ---------------------------------------------------------------- structure

func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_screen, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


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


func test_no_hardcoded_colors_in_script() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("Color("),
		"SemesterEnd.gd must source colors from DesignTokens, not literals")


func test_buttons_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	for name in ["BtnRestart"]:
		var b := _screen.find_child(name, true, false) as Control
		var h := b.get_combined_minimum_size().y
		assert_true(h >= float(tokens.touch_target_min),
			"%s has minimum height %d px, below the %d px minimum"
				% [name, int(h), tokens.touch_target_min])


# ------------------------------------------------------- ResultStatRow reuse

func test_result_stat_row_replaces_inline_rows() -> void:
	# Every Murid card's StatsContainer must hold ResultStatRow instances,
	# not the old ad-hoc VBoxContainer{Labels{Icon,Title,Value},Progress}.
	var card_container := _screen.find_child("CardContainer", true, false)
	assert_true(card_container != null, "missing CardContainer")

	var found_any := false
	for card in card_container.get_children():
		var stats := card.get_node_or_null("StatsContainer")
		if not stats:
			continue
		for subject in ["Akademis", "Seni", "Olahraga"]:
			var row := stats.get_node_or_null(subject)
			if row == null:
				continue
			found_any = true
			assert_true(row is ResultStatRow,
				"%s/%s must be a ResultStatRow instance" % [card.name, subject])
	assert_true(found_any, "expected at least one ResultStatRow to be found")


func test_result_stat_row_has_expected_exports_and_method() -> void:
	var scene: PackedScene = load("res://Scenes/EndGame/ResultStatRow.tscn")
	var row := scene.instantiate()
	track(row)
	assert_true(row.has_method("set_result"),
		"ResultStatRow must expose set_result(value, target)")
	assert_true("category" in row, "ResultStatRow must @export category")
	assert_true("icon" in row, "ResultStatRow must @export icon")
	assert_true("label_text" in row, "ResultStatRow must @export label_text")


# ----------------------------------------------------------------- reveal

## NOTE on technique: SemesterEnd.gd is NOT @tool (verified empirically --
## see the @tool decision note near the top of this file). A non-@tool
## script instantiated by the editor's own test runner gets a
## PlaceholderScript instance: the `in` operator can still see @export
## names in the property list, but a *compiled* dot-access like
## `_screen.card_stagger` throws "Invalid access to property or key" at
## runtime, and calling any real method (e.g. `_screen._slam_stamp(...)`)
## throws "Attempt to call a method on a placeholder instance" -- both
## confirmed by an earlier failed run of this exact test. This mirrors
## test_lobby.gd's documented finding for idle_bob_pixels/idle_bob_period.
## Fix: verify the export declarations and _slam_stamp's shape via
## source-text scanning instead of live property/method access.
func test_reveal_timing_is_exported_and_tunable() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for decl in [
		"@export var card_stagger: float = 0.12",
		"@export var stat_fill_delay: float = 0.35",
		"@export var stamp_delay: float = 0.9",
	]:
		assert_true(src.contains(decl), "missing tunable export: " + decl)


func test_slam_stamp_sets_pre_animation_state_synchronously() -> void:
	# See the technique note above: _slam_stamp cannot be called live on a
	# placeholder instance, so its shape (pre-animation scale/alpha set
	# before the tween starts, correct ease/trans, shake+sfx keyed to
	# pass/fail) is verified via source text instead.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("func _slam_stamp(stamp: Control, passed: bool) -> void:"),
		"SemesterEnd must implement _slam_stamp(stamp, passed)")
	assert_true(src.contains("stamp.scale = Vector2(3.0, 3.0)"),
		"stamp must start scaled up 3x before slamming down to 1.0")
	assert_true(src.contains("stamp.modulate.a = 0.0"),
		"stamp must start invisible before fading in during the slam")
	assert_true(src.contains("Tween.EASE_IN).set_trans(Tween.TRANS_BACK)"),
		"the slam must ease in with a back-out overshoot")
	assert_true(src.contains("Juice.shake(stamp.get_parent()"),
		"the slam must finish with a shake on the parent card")
	assert_true(src.contains("AudioDirector.play_sfx(&\"success\" if passed else &\"fail\")"),
		"the slam must play the pass/fail sting keyed to the outcome")


func test_reveal_is_sequenced_not_simultaneous() -> void:
	# A genuinely sequenced reveal must gate later beats behind earlier
	# ones -- verified structurally via source text for the delay/await
	# ordering, since the MCP runner cannot await a multi-second reveal
	# tween chain inside a synchronous test call.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("card_stagger"), "reveal must reference card_stagger")
	assert_true(src.contains("stat_fill_delay"), "reveal must reference stat_fill_delay")
	assert_true(src.contains("stamp_delay"), "reveal must reference stamp_delay")
	assert_true(src.contains("await"),
		"reveal sequencing must use await to gate later beats")
