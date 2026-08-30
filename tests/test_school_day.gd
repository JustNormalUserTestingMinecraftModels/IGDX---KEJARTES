@tool
extends McpTestSuite

## SchoolDay is the core gameplay loop: a 1557-line script driving a
## five-day simulation plus TEN sub-scenes (summary popup + its rows,
## badges and pills, two event overlays, the event student picker, the
## decay overview, the weekly checkup, and the book-clock widget).
##
## The first two tests are the *behavioral contract net*: they were
## written and confirmed GREEN against the completely unmodified
## scene/script, before any migration work started, so that every later
## slice has something real to break. They pin down the two things a UI
## migration must never disturb on this screen:
##   1. the week-end routing fork (SemesterEnd vs. Lobby), and
##   2. the minigame launch boundary (GameContainer + Scenes/Minigames/*),
##      which is explicitly out of scope for this task.
##
## Technique notes carried over from Tasks 9-15:
##  * This suite must itself be @tool or the runner reports the class as
##    abstract/broken.
##  * The runner calls `suite.call(name)` WITHOUT awaiting, so no test
##    here may be a coroutine. Touch targets are therefore measured with
##    get_combined_minimum_size(), which is computed on demand from the
##    theme and needs no pending container sort.
##  * Control has no get_theme_*_override_list() in Godot 4.6; the
##    _collect_overrides helper below is copied verbatim from
##    tests/test_main_menu.gd.
##  * ThemeDB's project-theme fallback does not populate for a scene
##    instantiated under the editor's own root, so the baked theme is
##    assigned explicitly before each scene enters the tree.
##  * None of these scripts is @tool, so _ready() does not fire for an
##    editor-instantiated scene. Every assertion here therefore reads
##    either scene-declared state or script source text, never
##    runtime-built state. (Verified empirically: SchoolDay._ready()
##    calls start_simulation(), which would build a StudentManager off
##    GameState -- it does not run here.)

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

const _SCHOOL_DAY_SCENE := "res://Scenes/SchoolSimulation/SchoolDay.tscn"
const _SCHOOL_DAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"

## Every scene this task owns, keyed by the node name its root carries.
const _SCENES := {
	"SchoolDay": "res://Scenes/SchoolSimulation/SchoolDay.tscn",
	"DaySummaryPopup": "res://Scenes/SchoolSimulation/DaySummaryPopup.tscn",
	"DaySummaryStudentRow": "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn",
	"DaySummaryBadge": "res://Scenes/SchoolSimulation/DaySummaryBadge.tscn",
	"DaySummaryPill": "res://Scenes/SchoolSimulation/DaySummaryPill.tscn",
	"EventAnnouncement": "res://Scenes/SchoolSimulation/EventAnnouncement.tscn",
	"EventWarning": "res://Scenes/SchoolSimulation/EventWarning.tscn",
	"EventStudentSelectDialog": "res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn",
	"DailyDecayOverview": "res://Scenes/SchoolSimulation/DailyDecayOverview.tscn",
	"ResultCheckup": "res://Scenes/SchoolSimulation/ResultCheckup.tscn",
	"BookClockWidget": "res://Scenes/SchoolSimulation/BookClockWidget.tscn",
}

## Every script this task owns. SimulationBackground.gd is included
## because it paints SchoolDay's Background node.
const _SCRIPTS := [
	"res://Scripts/SchoolSimulation/SchoolDay.gd",
	"res://Scripts/SchoolSimulation/SimulationBackground.gd",
	"res://Scripts/SchoolSimulation/DaySummaryPopup.gd",
	"res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd",
	"res://Scripts/SchoolSimulation/EventAnnouncement.gd",
	"res://Scripts/SchoolSimulation/EventWarning.gd",
	"res://Scripts/SchoolSimulation/EventStudentSelectDialog.gd",
	"res://Scripts/SchoolSimulation/DailyDecayOverview.gd",
	"res://Scripts/SchoolSimulation/ResultCheckup.gd",
	"res://Scripts/SchoolSimulation/BookClockWidget.gd",
]


func suite_name() -> String:
	return "school_day"


var _day: Control


func setup() -> void:
	_day = _instantiate(_SCHOOL_DAY_SCENE)


func teardown() -> void:
	if is_instance_valid(_day):
		_day.queue_free()
	_day = null


## Instantiate a scene with the baked theme attached, parented under the
## editor root and tracked for cleanup.
func _instantiate(path: String) -> Control:
	var scene: PackedScene = load(path)
	var inst := scene.instantiate() as Control
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	return inst


# ------------------------------------------------ behavioral contract net

func test_week_end_routing_is_unchanged() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("res://Scenes/EndGame/SemesterEnd.tscn"),
		"the final week must still route to SemesterEnd")
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"a non-final week must still route back to the Lobby")
	assert_true(src.contains("completed_week >= max_weeks"),
		"the routing fork condition must be untouched")
	assert_true(src.contains("GameState.minggu_ke += 1"),
		"the week counter must still advance before routing")
	assert_true(src.contains("student_manager.write_back_to_gamestate()"),
		"simulation results must still be written back before routing")


func test_the_week_advances_by_loop_not_by_self_recursion() -> void:
	# _run_day() used to end with `current_day += 1; _run_day()`. Because it
	# awaits eight times, each recursive call nested a frame that never
	# unwound -- depth grew with every day simulated, and a long session was
	# observed parked in a "Stack overflow (stack size: 1024)" break.
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("while not is_skipped and current_day < DAYS.size():"),
		"the week must advance in a loop so stack depth stays constant")
	assert_true(src.contains("await _run_single_day()"),
		"the loop must await exactly one day per iteration")
	assert_true(src.contains("func _run_single_day() -> void:"),
		"the per-day body must live in its own function")
	# Exactly two occurrences may remain: the `func _run_day() -> void:`
	# definition, and the single call from start_simulation().
	assert_eq(src.count("_run_day()"), 2,
		"_run_day() must be defined once and called once (from start_simulation); any third occurrence is a reintroduced self-call")


func test_minigame_launch_path_is_untouched() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	# The container the minigames are spawned into, and the spawn itself.
	assert_true(src.contains("@onready var game_container: Control      = $GameContainer"),
		"GameContainer must still be resolved the same way")
	assert_true(src.contains("game_container.add_child(current_minigame)"),
		"minigames must still be spawned into GameContainer")
	assert_true(src.contains("current_minigame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)"),
		"the spawned minigame must still be stretched to full rect")
	assert_true(src.contains("current_minigame.start_minigame(diff_level, duration)"),
		"the minigame start handshake must be untouched")
	assert_true(src.contains("current_minigame.activate_minigame()"),
		"the minigame activate handshake must be untouched")
	for path in [
			"res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
			"res://Scenes/Minigames/Akademis/Variabel.tscn",
			"res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
			"res://Scenes/Minigames/Akademis/Password.tscn",
			"res://Scenes/Minigames/Olahraga/MainBola.tscn",
			"res://Scenes/Minigames/Olahraga/Badminton.tscn",
			"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn",
			"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"]:
		assert_true(src.contains(path), "minigame scene reference lost: " + path)
	# ...and the node itself must still exist, unwrapped, at the top level.
	var gc := _day.get_node_or_null("GameContainer")
	assert_true(gc != null, "GameContainer must remain a direct child of SchoolDay")
	assert_eq(gc.get_class(), "Control", "GameContainer must remain a plain Control")


# ------------------------------------------------------- standard four

func test_scenes_instantiate() -> void:
	for name in _SCENES.keys():
		var inst := _instantiate(_SCENES[name])
		assert_true(inst != null, "scene must instantiate: " + name)
		assert_true(inst.is_inside_tree(), "scene must enter the tree: " + name)
		# NOTE: not asserting `inst.name` here. setup() already parented a
		# SchoolDay under the editor root, so a second instance with the
		# same name is auto-renamed by Godot's sibling-name uniquing. The
		# scene's own identity is `scene_file_path`, which is stable.
		assert_eq(inst.scene_file_path, _SCENES[name],
			"unexpected scene_file_path for " + name)


func test_scenes_have_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	for name in _SCENES.keys():
		var inst := _instantiate(_SCENES[name])
		var local: Array[String] = []
		_collect_overrides(inst, local)
		for o in local:
			offenders.append("%s/%s" % [name, o])
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


func test_no_hardcoded_colors_remain_in_the_scripts() -> void:
	var re := RegEx.create_from_string("Color\\s*\\(")
	var offenders: Array[String] = []
	for path in _SCRIPTS:
		var src := FileAccess.get_file_as_string(path)
		var hits := re.search_all(src).size()
		if hits > 0:
			offenders.append("%s (%d)" % [path.get_file(), hits])
	assert_eq(offenders.size(), 0,
		"scripts must read colors from DesignTokens, not Color() literals: "
			+ ", ".join(offenders))


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var targets := {
		"res://Scenes/SchoolSimulation/SchoolDay.tscn": [
			"DayScreen/BackButton", "DayScreen/SkipButton"],
		"res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn": [
			"Margin/DialogPanel/Margin/MainVBox/ActionVBox/SecondaryHBox/SelectAllButton",
			"Margin/DialogPanel/Margin/MainVBox/ActionVBox/SecondaryHBox/CancelButton",
			"Margin/DialogPanel/Margin/MainVBox/ActionVBox/ConfirmButton"],
		"res://Scenes/SchoolSimulation/DailyDecayOverview.tscn": [
			"Margin/Panel/Margin/VBox/ContinueButton"],
		"res://Scenes/SchoolSimulation/ResultCheckup.tscn": [
			"Margin/VBox/BtnClose"],
	}
	for scene_path in targets.keys():
		var inst := _instantiate(scene_path)
		for node_path in targets[scene_path]:
			var b := inst.get_node_or_null(node_path) as Control
			assert_true(b != null, "missing control: " + node_path)
			if b == null:
				continue
			var h := b.get_combined_minimum_size().y
			assert_true(h >= float(tokens.touch_target_min),
				"%s has minimum height %d px, below the %d px minimum"
					% [node_path, int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

func test_day_progress_bar_is_a_statbar_filled_through_juice() -> void:
	var bar := _day.get_node_or_null("DayScreen/ProgressBar")
	assert_true(bar is StatBar, "the day-progress bar must be a StatBar")
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("Juice.fill_bar(progress_bar"),
		"the day-progress bar must be filled through Juice.fill_bar")


func test_background_is_token_driven() -> void:
	var bg := _day.get_node_or_null("Background") as Control
	assert_true(bg != null, "SchoolDay must still have a Background node")
	var scene_src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCENE)
	assert_false(scene_src.contains("color = Color("),
		"SchoolDay.tscn must not bake a raw background color")
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("surface_page"),
		"the background must be derived from tokens.surface_page")


func test_click_to_continue_label_pulses_like_the_splash_hint() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("Juice.tokens().dur_slow"),
		"the continue-prompt pulse must be timed from tokens.dur_slow")
	assert_true(src.contains("click_to_continue_label, \"modulate:a\", 0.35"),
		"the continue prompt must pulse down to 0.35 alpha, like the splash hint")
	assert_true(src.contains("click_to_continue_label, \"modulate:a\", 1.0"),
		"the continue prompt must pulse back up to full alpha")


func test_day_summary_deltas_count_up_with_audio_feedback() -> void:
	var popup := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/DaySummaryPopup.gd")
	assert_true(popup.contains("Juice.stagger_in"),
		"summary rows must stagger in")
	assert_true(popup.contains("AudioDirector.play_sfx(&\"success\")"),
		"a net gain above target must play the success sfx")
	assert_true(popup.contains("AudioDirector.play_sfx(&\"fail\")"),
		"a net loss must play the fail sfx")


func test_hazard_stripe_color_comes_from_tokens_at_runtime() -> void:
	var warning := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/EventWarning.gd")
	assert_true(warning.contains("set_shader_parameter"),
		"EventWarning must drive the hazard shader from script")
	assert_true(warning.contains("state_warning"),
		"the hazard stripe color must come from tokens.state_warning")
	var scene_src := FileAccess.get_file_as_string(
		"res://Scenes/SchoolSimulation/EventWarning.tscn")
	assert_false(scene_src.contains("shader_parameter/color1 = Color("),
		"the stripe color must not stay baked into the scene's ShaderMaterial")
	# The shader itself stays.
	assert_true(scene_src.contains("HazardStripeShader.gdshader"),
		"the hazard shader must be kept")


func test_simulation_bgm_is_requested() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("AudioDirector.play_bgm(&\"simulation\")"),
		"the school day must request the simulation bgm")


func test_summary_and_event_overlays_use_the_scrim_variation() -> void:
	var expected := {
		"res://Scenes/SchoolSimulation/DaySummaryPopup.tscn": "DimOverlay",
		"res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn": "BackgroundDim",
		"res://Scenes/SchoolSimulation/DailyDecayOverview.tscn": "BackgroundDim",
	}
	for scene_path in expected.keys():
		var inst := _instantiate(scene_path)
		var dim := inst.get_node_or_null(expected[scene_path]) as Control
		assert_true(dim != null,
			"missing dim overlay in " + scene_path.get_file())
		if dim == null:
			continue
		assert_eq(dim.theme_type_variation, &"Scrim",
			scene_path.get_file() + " dim overlay must use the Scrim variation")


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
