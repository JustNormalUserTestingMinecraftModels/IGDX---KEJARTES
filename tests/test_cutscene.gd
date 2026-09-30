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
##    Button nodes (top-bar Skip/Debug; the grade picker moved to the
##    Level Select scene on 2026-09-25), unlike Splashscreen/Loading,
##    so the touch-target test from the shared brief template DOES apply
##    here -- but per test_main_menu.gd's finding, it is measured via
##    get_combined_minimum_size() synchronously right after add_child(),
##    not via `.size` after an awaited frame.
##
## CutScene.gd is @tool for the same placeholder-instance reason as
## MainMenu.gd (see that script's header). Its top-bar buttons are
## built unconditionally in _ready() (mirroring
## MainMenu's always-wire-buttons pattern), so they exist and are
## theme-clean even when this suite instantiates the scene inside the
## editor process. Everything GameState-dependent sits behind
## Engine.is_editor_hint() inside CutScene.gd itself and never runs here.

func suite_name() -> String:
	return "cutscene"

const _SCENE_PATH := "res://Scenes/CutScene/CutScene.tscn"
const _SCRIPT_PATH := "res://Scripts/CutScene/CutScene.gd"
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
## builds its interactive controls (top-bar Skip/Debug) in code rather
## than in the .tscn, so the walk starts from
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


## The mockup's panel art is gone: the box is the themed "Buku Catatan"
## note panel (2026-09-30) on the CutsceneNotePanel variation, so a colour or
## radius change in design_tokens reaches it like every other surface. It also
## no longer hangs 100px off the bottom of a 1920-tall screen, which the
## art-backed version did. The ruled-paper background and spiral binding are
## authored TextureRects that must never swallow the advance tap.
func test_dialogue_box_is_a_themed_rounded_panel() -> void:
	var box := _scene.find_child("DialogueBox", true, false) as Panel
	assert_true(box != null,
		"DialogueBox is missing or is no longer a Panel")
	assert_eq(box.theme_type_variation, &"CutsceneNotePanel",
		"DialogueBox must take its rounded chrome from the theme")
	var rule := box.get_node_or_null("RuleBg") as Control
	var spiral := box.get_node_or_null("SpiralStrip") as Control
	assert_true(rule != null and spiral != null,
		"the note keeps its ruled-paper and spiral-binding chrome")
	assert_eq(rule.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"RuleBg must not intercept the advance tap")
	assert_eq(spiral.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"SpiralStrip must not intercept the advance tap")
	assert_true(box.offset_bottom <= 1920.0,
		"the panel must sit inside the screen, got bottom %f" % box.offset_bottom)
	assert_true(box.offset_left >= 44.0,
		"and clear the screen margin on the left, got %f" % box.offset_left)
	assert_true(box.offset_right <= 1036.0,
		"and on the right, got %f" % box.offset_right)


## Retired with the art: nothing should still reference the panel PNG.
func test_the_mockup_panel_art_is_no_longer_referenced() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/CutScene/CutScene.tscn")
	assert_false(src.contains("cutscene_dialogue.png"),
		"the panel is a theme variation now, not a texture")


func test_dialogue_text_uses_the_bigger_variation() -> void:
	var label := _scene.get_node_or_null(
		"DialogueBox/DialogueLabel") as RichTextLabel
	assert_true(label != null, "DialogueLabel is missing or is not a RichTextLabel")
	assert_eq(label.theme_type_variation, &"CutsceneDialogue",
		"the dialogue must take its larger size from the theme")


func test_dialogue_text_sits_inside_its_panel() -> void:
	var box := _scene.find_child("DialogueBox", true, false) as Control
	var label := _scene.get_node_or_null("DialogueBox/DialogueLabel") as Control
	assert_true(box != null and label != null, "panel and label must both exist")
	assert_true(label.offset_left >= 28.0,
		"text is inset from the panel's left edge, got %f" % label.offset_left)
	assert_true(label.offset_top >= 28.0,
		"and from its top, got %f" % label.offset_top)
	assert_true(label.offset_right <= box.size.x - 28.0,
		"and stops before its right edge")
	assert_true(label.offset_bottom <= box.size.y - 28.0,
		"and before its bottom")


## The 2026-09-30 VN pass dropped the "Ketuk untuk melanjutkan" caption for a
## visual-novel advance chevron and a "Catatan Guru" name plate. The chevron
## carries the advance cue (breathed by _pulse_chevron()) and must not swallow
## the tap; the name plate is the speaker label. Both live inside the box.
func test_name_plate_and_advance_chevron_replace_the_caption() -> void:
	var box := _scene.find_child("DialogueBox", true, false) as Control
	assert_true(box != null, "DialogueBox must exist")
	assert_true(_scene.find_child("HintLabel", true, false) == null,
		"the old text caption is gone -- the chevron carries the advance cue")
	var tab := box.get_node_or_null("NameTab") as Label
	assert_true(tab != null, "the Catatan Guru name plate must exist")
	assert_eq(tab.text, "Catatan Guru", "the name plate names the speaker")
	assert_eq(tab.theme_type_variation, &"CutsceneNoteTab",
		"the name plate takes its chrome from the theme")
	var chev := box.get_node_or_null("Chevron") as Control
	assert_true(chev != null, "the advance chevron must exist")
	assert_eq(chev.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the chevron must not intercept the advance tap")


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
## game (the very first intro-CG skip or finish) straight to Lobby, never
## to StudentCard -- so
## GameState.approved_students stayed empty and every downstream screen
## (AturJadwal, StudentList, the week simulation itself) silently fell
## back to its own placeholder roster instead of surfacing the problem.
## The grade-7 semester-loss retry had the identical bug: it cleared
## approved_students ("so they select again", per its own comment) but
## then routed to Lobby anyway. Both must now go through StudentCard --
## the only screen that actually populates approved_students.
##
## Scoped to go_to_gameplay()'s own body (not the whole file) so it and
## test_on_skip_pressed_also_routes_through_student_card below can each
## pin their own function independently.
func test_go_to_gameplay_always_routes_through_student_card() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "go_to_gameplay")
	assert_true(body.contains("Transition.change_scene(_next_scene_path()"),
		"must delegate routing to _next_scene_path()")
	assert_false(body.contains("res://Scenes/Lobby/Lobby.tscn"),
		"go_to_gameplay must never hand the player to Lobby directly -- " +
		"StudentCard is the only gate that populates approved_students")
	assert_false(body.contains("change_scene_to_file"),
		"must hand off through Transition, not a raw change_scene_to_file -- " +
		"a raw call skips the wipe, the inventory flush and the anti-flash frame")


## _next_scene_path() is the routing table go_to_gameplay() now delegates
## to. StudentCard must remain its default/fallback branch -- this is what
## preserves the original guarantee that the intro branch always ends up
## at StudentCard, not Lobby.
func test_next_scene_path_defaults_to_student_card() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_next_scene_path")
	assert_true(body.contains("res://Scenes/StudentCard/StudentCard.tscn"),
		"_next_scene_path must default/fallback to StudentCard")


## The bug this pins: _on_skip_pressed() routed straight to Lobby, even
## though this scene (and therefore Skip Intro, a normal always-visible
## button, not a debug affordance) is only ever reached fresh from
## MainMenu -- GameState.approved_students is always empty here. That is
## the exact bug go_to_gameplay() had before its own fix
## (test_go_to_gameplay_always_routes_through_student_card, above); Skip
## just never got the same fix applied to it.
func test_on_skip_pressed_also_routes_through_student_card() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_on_skip_pressed")
	assert_true(body.contains("Transition.change_scene(_next_scene_path()"),
		"Skip Intro must delegate routing to _next_scene_path(), same as go_to_gameplay()")
	assert_false(body.contains("res://Scenes/Lobby/Lobby.tscn"),
		"Skip Intro must never hand the player to Lobby directly -- " +
		"StudentCard is the only gate that populates approved_students")
	assert_false(body.contains("change_scene_to_file"),
		"must hand off through Transition, not a raw change_scene_to_file -- " +
		"a raw call skips the wipe, the inventory flush and the anti-flash frame")


func test_show_current_starts_with_a_hold_before_revealing() -> void:
	# Calling show_current() live here would exercise Godot autoload
	# resolution, which errors in this suite's standalone-instantiation
	# context (GameState resolves fine in other suites' setups, but not
	# when CutScene.tscn is instantiated bare like test_cutscene.gd
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


## Plan A (2026-09-04) deleted the exam-intro cutscene beat: ExamProgress
## now hands off straight to StatCheck. CutScene is back to a single
## responsibility -- the game-start intro (its grade picker is now the
## Level Select scene, 2026-09-25).
func test_the_exam_branch_is_gone() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for gone in ["is_exam_intro_cutscene", "_setup_exam_cutscene", "btn_lanjut_exam",
			"BtnLanjutExam", "exam_cutscene", "SemesterEnd.tscn", "StatCheck.tscn"]:
		assert_false(src.contains(gone), "CutScene.gd must not mention " + gone)
	assert_true(_scene.get_node_or_null("BtnLanjutExam") == null,
		"the BtnLanjutExam node is deleted from CutScene.tscn")


func test_next_scene_path_has_a_single_destination_again() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := _function_body(src, "_next_scene_path")
	assert_true(body.contains("res://Scenes/StudentCard/StudentCard.tscn"),
		"the intro still lands on roster approval")
	assert_false(body.contains("if "), "no branch left: one destination")
