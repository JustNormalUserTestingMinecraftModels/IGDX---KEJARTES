@tool
extends McpTestSuite

## StudentCard is the heaviest screen in the project (2297-line scene,
## 512 theme overrides, 2051-line script). The first two tests here are
## the *behavioral contract net*: they were written and confirmed GREEN
## against the completely unmodified scene/script, before any migration
## work started, so that every later slice has something real to break.
##
## Technique notes carried over from Tasks 9/10/11:
##  * This suite must itself be @tool or the runner reports the class as
##    abstract/broken.
##  * The runner calls `suite.call(name)` WITHOUT awaiting, so no test
##    here may be a coroutine.
##  * Control has no get_theme_*_override_list() in Godot 4.6; the
##    _collect_overrides helper below is copied verbatim from
##    tests/test_main_menu.gd, which walks get_property_list() and
##    cross-checks the per-name has_theme_*_override() APIs.
##  * ThemeDB's project-theme fallback does not populate for a scene
##    instantiated under the editor's own root, so the baked theme is
##    assigned explicitly before the scene enters the tree.

const _SCENE_PATH := "res://Scenes/StudentCard/student_card.tscn"
const _SCRIPT_PATH := "res://Scripts/StudentCard/student_card.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "student_card"


var _card: Control


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_card = scene.instantiate()
	_card.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_card)
	track(_card)


func teardown() -> void:
	if is_instance_valid(_card):
		_card.queue_free()
	_card = null


# ------------------------------------------------ behavioral contract net

func test_approved_students_contract_is_intact() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for symbol in ["GameState.approved_students", "GameState.selected_student",
			"GameState.returned_from_student_card"]:
		assert_true(src.contains(symbol),
			"the selection contract must still write: " + symbol)


func test_still_routes_to_the_lobby() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"student_card must still route to the lobby")


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_card != null, "scene must instantiate")
	assert_true(_card.is_inside_tree(), "scene must enter the tree cleanly")
	for i in range(1, 7):
		assert_true(_card.get_node_or_null("KertasMurid%d" % i) != null,
			"missing student page KertasMurid%d" % i)


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_card, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func test_no_hardcoded_colors_remain_in_the_script() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0,
		"script must read colors from DesignTokens, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	# These buttons are absolutely positioned (no container sort pending),
	# so their rect comes straight from the scene's offsets and is readable
	# without a frame wait. `scale` matters: the page arrows are drawn from
	# a 520px icon shrunk by a scale factor.
	var tokens := DesignTokens.load_default()
	var paths := [
		"KertasMurid1/Aprove", "KertasMurid1/Batal",
		"KertasMurid1/KutuBuku", "KertasMurid1/KutuBuku2",
		"BelajarButton", "NextButtonKanan", "NextButtonKiri",
	]
	for p in paths:
		var b := _card.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		var h: float = maxf(b.size.y * b.scale.y,
			b.get_combined_minimum_size().y * b.scale.y)
		var w: float = maxf(b.size.x * b.scale.x,
			b.get_combined_minimum_size().x * b.scale.x)
		assert_true(minf(h, w) >= float(tokens.touch_target_min),
			"%s is %dx%d px, below the %d px minimum touch target"
				% [p, int(w), int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

func test_stat_bars_are_statbars_with_a_category() -> void:
	var expected := {
		"Kepribadian1": "Istirahat",
		"Kepribadian2": "Libur",
		"Akademis1": "Akademis",
		"Akademis2": "SeniBudaya",
		"Akademis3": "Olahraga",
	}
	for i in range(1, 7):
		for bar_name in expected.keys():
			var bar := _card.get_node_or_null("KertasMurid%d/%s" % [i, bar_name])
			assert_true(bar is StatBar,
				"KertasMurid%d/%s must be a StatBar" % [i, bar_name])
			assert_eq(bar.category, expected[bar_name],
				"KertasMurid%d/%s category" % [i, bar_name])


func test_action_buttons_use_theme_variations() -> void:
	var expected := {
		"KertasMurid1/Aprove": &"SuccessButton",
		"KertasMurid1/Batal": &"DangerButton",
		"KertasMurid1/KutuBuku": &"QuirkBadge",
		"KertasMurid1/KutuBuku2": &"PersonaBadge",
		"BelajarButton": &"PrimaryButton",
	}
	for p in expected.keys():
		var b := _card.get_node_or_null(p) as Button
		assert_true(b != null, "missing button: " + p)
		assert_eq(b.theme_type_variation, expected[p], p + " variation")


func test_motion_and_audio_feedback_are_wired() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.stagger_in"),
		"student pages must stagger in on entry")
	assert_true(src.contains("Juice.pop_in"),
		"the detail popup must pop in")
	assert_true(src.contains("AudioDirector.play_sfx(&\"stamp\")"),
		"approve must play the stamp sfx")
	assert_true(src.contains("AudioDirector.play_sfx(&\"unstamp\")"),
		"reject must play the unstamp sfx")


# ----------------------------------------------------------------- helper

## Copied verbatim from tests/test_main_menu.gd. Godot 4.6's Control has
## no get_theme_*_override_list(); this walks get_property_list() and asks
## the per-name has_theme_*_override() APIs instead. Constants/fonts/icons
## are deliberately excluded, matching the reference test.
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
