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
##   1. the week-end routing fork (TesNotice vs. Lobby), and
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
##  * SchoolDay.gd is not @tool, so its _ready() does not fire for an
##    editor-instantiated scene. Every assertion here therefore reads
##    either scene-declared state or script source text, never
##    runtime-built state. (Verified empirically: SchoolDay._ready()
##    calls start_simulation(), which would build a StudentManager off
##    GameState -- it does not run here.) BookClockWidget.gd IS @tool as
##    of the 2026-09-03 sky cinematic, but its _ready() only lays out its
##    own two children, so nothing here is disturbed.

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
	assert_true(src.contains("res://Scenes/EndGame/TesNotice.tscn"),
		"the final week now exits into the Tes Besar notice, not straight to the stat check")
	assert_false(src.contains("res://Scenes/EndGame/SemesterEnd.tscn"),
		"SchoolDay no longer reaches the stat check directly")
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


func test_reparented_pill_label_has_its_owner_cleared() -> void:
	# _make_chip instantiates DaySummaryPill.tscn, so the "Text" Label carries
	# that scene's root as its owner. _add_pill re-parents it under a runtime
	# HBoxContainer (owner == null); without clearing owner first Godot warns
	# "will make owner 'DaySummaryPill' inconsistent" once per badge, per
	# student, per day -- enough to flood the log buffer and drop every other
	# diagnostic on this screen.
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("lbl.owner = null"),
		"_add_pill must clear the label's owner before re-parenting it")
	var clear_at := src.find("lbl.owner = null")
	var reparent_at := src.find("hbox.add_child(lbl)")
	assert_gt(reparent_at, clear_at,
		"the owner must be cleared BEFORE hbox.add_child(lbl), not after")


func test_debug_tutorial_bypass_skips_the_end_of_simulation_tutorial() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("if not GameState.tutorials_bypassed and GameState.current_grade == 7 and GameState.minggu_ke == 1:"),
		"the debug menu's master tutorial-bypass flag must skip the end-of-week-1 tutorial too")


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
			"Margin/VBox/Buttons/LogsButton", "Margin/VBox/Buttons/NextButton"],
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


# ---------------------------------------------- schedule application (bug)

## apply_daily_decay_all only reads GameState.day_schedules for a student
## whose id is non-zero -- the guard exists because id 0 means "no real
## student", the shape a schedule dict left over from a placeholder
## fallback would have. This proves the read side is correct for a real,
## non-zero id: a scheduled Akademis day must raise akademis rather than
## leave the student on the Istirahat default. Same technique as
## tests/test_wirausaha.gd -- StudentManager.new() constructed directly,
## no SchoolDay scene involved.
func test_a_scheduled_activity_applies_for_a_student_with_a_real_id() -> void:
	GameState.day_schedules = {
		9: {"Senin": {"category": "Akademis", "mood_cost": 10, "energy_cost": 10}},
	}
	var manager := StudentManager.new()
	var student := StudentData.new()
	student.id = 9
	student.student_name = "Uji"
	student.akademis = 40.0
	student.energy = 80.0
	student.mood = 80.0
	student.record_initial_stats()
	manager.students = [student]

	manager.apply_daily_decay_all("Senin")

	assert_gt(student.akademis, 40.0,
		"a scheduled Akademis day must raise akademis, not leave the student on the Istirahat default")
	GameState.day_schedules = {}
	manager.free()


## ...and the same student with no matching schedule entry defaults to
## Istirahat (no skill gain) -- the contrast that proves the test above is
## actually reading the schedule, not just always granting a gain.
func test_an_unscheduled_day_defaults_to_istirahat_with_no_skill_gain() -> void:
	GameState.day_schedules = {}
	var manager := StudentManager.new()
	var student := StudentData.new()
	student.id = 9
	student.student_name = "Uji"
	student.akademis = 40.0
	student.energy = 80.0
	student.mood = 80.0
	student.record_initial_stats()
	manager.students = [student]

	manager.apply_daily_decay_all("Senin")

	assert_true(is_equal_approx(student.akademis, 40.0),
		"with no schedule assigned, the student must default to Istirahat and gain no akademis")
	manager.free()


func test_student_manager_records_minigames_into_run_stats() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/StudentManager.gd")
	assert_true(src.contains("GameState.run_stats.record_minigame("),
		"record_minigame_result feeds the run tally")


## initialize_from_gamestate() falls back to the hardcoded demo roster
## (Budi/Ani/Cici/Doni, generic Murid*.jpg art) whenever
## GameState.approved_students is empty -- e.g. SchoolDay reached without
## an approved roster. That used to swap in silently; used_fallback_roster
## now lets a caller (or this test) tell the placeholder cast apart from a
## real one instead of it passing for the approved roster.
func test_initialize_from_gamestate_flags_the_fallback_roster_when_empty() -> void:
	var saved_roster: Array = GameState.approved_students.duplicate()
	GameState.approved_students = []

	var manager := StudentManager.new()
	manager.initialize_from_gamestate()

	assert_true(manager.used_fallback_roster,
		"an empty approved_students must be flagged as the fallback roster")
	assert_true(manager.students.size() > 0 and manager.students[0].student_name == "Budi",
		"the fallback roster is the hardcoded Budi/Ani/Cici/Doni demo cast")

	GameState.approved_students = saved_roster
	manager.free()


## ...and the contrast: a real, non-empty approved_students must not be
## flagged, proving the test above is actually reading the empty case and
## not just always true.
func test_initialize_from_gamestate_does_not_flag_a_real_roster() -> void:
	var saved_roster: Array = GameState.approved_students.duplicate()
	GameState.approved_students = [{
		"id": 1, "name": "Uji", "akademis1": 50, "akademis2": 50, "akademis3": 50,
		"kepribadian1": 80, "kepribadian2": 80, "quirk": "", "persona": "Aktif",
		"hobby_category": "Akademis", "portrait": "", "splash": "",
	}]

	var manager := StudentManager.new()
	manager.initialize_from_gamestate()

	assert_true(not manager.used_fallback_roster,
		"a non-empty approved_students must not be flagged as the fallback roster")

	GameState.approved_students = saved_roster
	manager.free()


func test_school_day_records_wirausaha_into_run_stats() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("GameState.run_stats.record_wirausaha("),
		"the wirausaha payout feeds the run tally")


func test_school_day_records_event_students_into_run_stats() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("GameState.run_stats.record_event_student("),
		"the event branch feeds the run tally")


func test_skip_uses_per_grade_loss_chance() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_false(src.contains("Balance.SKIP_PELUANG_KALAH)"),
		"skip must not read the old single SKIP_PELUANG_KALAH constant")
	assert_true(src.contains("SKIP_PELUANG_KALAH_KELAS_"),
		"skip resolution must pick a per-grade SKIP_PELUANG_KALAH_KELAS_* value")


func test_minigame_time_scale_comes_from_balance() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("Balance.MINIGAME_WAKTU_SKALA_KELAS_8"),
		"grade-8 minigame duration must read Balance.MINIGAME_WAKTU_SKALA_KELAS_8")
	assert_true(src.contains("Balance.MINIGAME_WAKTU_SKALA_KELAS_9"),
		"grade-9 minigame duration must read Balance.MINIGAME_WAKTU_SKALA_KELAS_9")


func test_weekly_minigame_count_is_randomised() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("max_minigames_this_week"),
		"SchoolDay must track a per-week max minigame count")
	assert_true(src.contains("randi_range(Balance.MINIGAME_MAKS_MINGGU_MIN, Balance.MINIGAME_MAKS_MINGGU_MAX)"),
		"the per-week minigame count must be rolled from Balance each week")
	assert_false(src.contains("minigames_played_this_week < 2"),
		"the hardcoded < 2 minigame guard must be gone")


func test_minigame_category_has_uniform_noise() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("Balance.MINIGAME_KATEGORI_ACAK_PELUANG"),
		"the minigame category pick must branch on the uniform-noise chance")


# ------------------------------------------------ day-roll weights

## Each school day rolls Normal / Minigame / Event from three weights. The
## day loop (_roll_event) and the skip button (skip_to_results) used to
## compute them separately, and the skip copy had lost Biang Onar's event
## bonus -- a skipped week rolled events at different odds than a watched
## one. SchoolDay.day_roll_weights() is now the one place they are
## computed; it is static and pure, so these tests call it straight off the
## script with hand-built counts and roster: no scene, no GameState.
##
## Expectations are written in terms of the script's ROLL_WEIGHT_* tuning
## and Balance's bonus, so retuning a number never fails a test -- only a
## wrong formula does.

## The week's minigame cap these tests run under. It differs from the event
## cap on purpose, so a helper that checked a counter against the other cap
## fails.
const _ROLL_MINIGAME_CAP := 3
## The week's event cap these tests run under.
const _ROLL_EVENT_CAP := 2


## day_roll_weights() for a Senin, called straight off SchoolDay.gd.
func _roll_weights(counts: Dictionary, roster: Array = [], schedules: Dictionary = {},
		minigames_played: int = 0, events_triggered: int = 0) -> Dictionary:
	var school_day = load(_SCHOOL_DAY_SCRIPT)
	var weights: Dictionary = school_day.day_roll_weights(counts, roster, schedules, "Senin",
		minigames_played, _ROLL_MINIGAME_CAP, events_triggered, _ROLL_EVENT_CAP)
	return weights


## One of SchoolDay.gd's ROLL_WEIGHT_* tuning constants.
func _roll_tuning(const_name: String) -> int:
	var school_day = load(_SCHOOL_DAY_SCRIPT)
	return int(school_day.get(const_name))


## A roster student carrying `quirk`, for the day-roll tests.
func _roll_student(id: int, quirk: String) -> StudentData:
	var s := StudentData.new()
	s.id = id
	s.quirk = quirk
	return s


## Studying students raise the minigame weight, resting students the normal
## weight, and a Wirausaha student neither. Breaks if the helper mixes the
## two counts up, or starts counting Wirausaha as either.
func test_day_roll_weights_scale_with_who_studies_and_who_rests() -> void:
	var counts := {"Akademis": 2, "Olahraga": 1, "SeniBudaya": 1, "Istirahat": 3, "Wirausaha": 2}
	var weights: Dictionary = _roll_weights(counts)

	assert_eq(weights.get("normal"), _roll_tuning("ROLL_WEIGHT_NORMAL_BASE")
		+ 3 * _roll_tuning("ROLL_WEIGHT_NORMAL_PER_RESTING"),
		"normal weight is the base plus one share per resting student")
	assert_eq(weights.get("minigame"), 4 * _roll_tuning("ROLL_WEIGHT_MINIGAME_PER_STUDYING"),
		"minigame weight is one share per student in Akademis, Olahraga or SeniBudaya")
	assert_eq(weights.get("event"), _roll_tuning("ROLL_WEIGHT_EVENT_BASE"),
		"with no Biang Onar on the roster the event weight is the flat base")


## The bug this section exists for: a Biang Onar student in class that day
## adds Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT to the event weight. The skip
## path's old inline copy dropped exactly this term.
func test_a_biang_onar_student_in_class_adds_the_event_bonus() -> void:
	assert_gt(Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT, 0,
		"precondition: a zero bonus cannot tell applied from dropped")
	var roster := [_roll_student(1, "Biang Onar")]
	var schedules := {1: {"Senin": {"category": "Akademis"}}}
	var weights: Dictionary = _roll_weights({"Akademis": 1}, roster, schedules)

	assert_eq(weights.get("event"),
		_roll_tuning("ROLL_WEIGHT_EVENT_BASE") + Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT,
		"a Biang Onar student studying that day adds the quirk's event bonus")


## The bonus is per student, and anything but rest counts as in class --
## Wirausaha included, as the day loop has always had it.
func test_each_active_biang_onar_student_adds_their_own_bonus() -> void:
	var roster := [_roll_student(1, "Biang Onar"), _roll_student(2, "Biang Onar")]
	var schedules := {
		1: {"Senin": {"category": "Olahraga"}},
		2: {"Senin": {"category": "Wirausaha"}},
	}
	var weights: Dictionary = _roll_weights({"Olahraga": 1, "Wirausaha": 1}, roster, schedules)

	assert_eq(weights.get("event"),
		_roll_tuning("ROLL_WEIGHT_EVENT_BASE") + 2 * Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT,
		"two Biang Onar students out of rest add the bonus twice")


## No bonus from a Biang Onar student who is resting, off, scheduled only on
## another day or not scheduled at all; from a student without the quirk;
## or from id 0, the "no real student" id a placeholder schedule carries.
func test_a_biang_onar_student_out_of_class_adds_nothing() -> void:
	var roster := [
		_roll_student(1, "Biang Onar"),  # resting
		_roll_student(2, "Biang Onar"),  # day off
		_roll_student(3, "Biang Onar"),  # scheduled on another day only
		_roll_student(4, "Biang Onar"),  # no schedule at all
		_roll_student(5, "Kutu Buku"),   # in class, but not the quirk
		_roll_student(0, "Biang Onar"),  # in class, but id 0
	]
	var schedules := {
		1: {"Senin": {"category": "Istirahat"}},
		2: {"Senin": {"category": "DayOff"}},
		3: {"Selasa": {"category": "Akademis"}},
		5: {"Senin": {"category": "Akademis"}},
		0: {"Senin": {"category": "Akademis"}},
	}
	var weights: Dictionary = _roll_weights({"Akademis": 2, "Istirahat": 1}, roster, schedules)

	assert_eq(weights.get("event"), _roll_tuning("ROLL_WEIGHT_EVENT_BASE"),
		"only a Biang Onar student with a real id and a non-rest activity that day earns the bonus")


## The week's minigame cap zeroes the minigame weight once it is reached,
## not a day before, and leaves the event weight alone.
func test_the_minigame_cap_zeroes_the_minigame_weight() -> void:
	var counts := {"Akademis": 3}
	var open: Dictionary = _roll_weights(counts, [], {}, _ROLL_MINIGAME_CAP - 1)
	var reached: Dictionary = _roll_weights(counts, [], {}, _ROLL_MINIGAME_CAP)

	assert_eq(open.get("minigame"), 3 * _roll_tuning("ROLL_WEIGHT_MINIGAME_PER_STUDYING"),
		"one minigame short of the cap, the day can still roll a minigame")
	assert_eq(reached.get("minigame"), 0,
		"at the cap the minigame weight is 0")
	assert_eq(reached.get("event"), _roll_tuning("ROLL_WEIGHT_EVENT_BASE"),
		"the minigame cap does not touch the event weight")


## The week's event cap zeroes the event weight -- Biang Onar's bonus with
## it -- once it is reached, not a day before, and leaves the minigame
## weight alone.
func test_the_event_cap_zeroes_the_event_weight_bonus_included() -> void:
	var roster := [_roll_student(1, "Biang Onar")]
	var schedules := {1: {"Senin": {"category": "Akademis"}}}
	var counts := {"Akademis": 1}
	var open: Dictionary = _roll_weights(counts, roster, schedules, 0, _ROLL_EVENT_CAP - 1)
	var reached: Dictionary = _roll_weights(counts, roster, schedules, 0, _ROLL_EVENT_CAP)

	assert_eq(open.get("event"),
		_roll_tuning("ROLL_WEIGHT_EVENT_BASE") + Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT,
		"one event short of the cap, the day keeps its event weight and the bonus")
	assert_eq(reached.get("event"), 0,
		"at the cap the event weight is 0, Biang Onar's bonus included")
	assert_eq(reached.get("minigame"), _roll_tuning("ROLL_WEIGHT_MINIGAME_PER_STUDYING"),
		"the event cap does not touch the minigame weight")


## Both simulation paths must take their weights from the one helper, so a
## watched week and a skipped week roll at the same odds. A source scan,
## because neither path runs without the live scene (see the file header);
## the tests above prove what the helper returns, this proves both ask it.
func test_both_day_rolls_take_their_weights_from_the_shared_helper() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	for fn_name in ["_roll_event", "skip_to_results"]:
		var body := _function_body(src, fn_name)
		assert_true(body.contains("_todays_roll_weights("),
			"%s() must take its day-roll weights from the shared helper" % fn_name)
		assert_false(body.contains("SIFAT_BIANG_ONAR_PELUANG_EVENT"),
			"%s() must not add Biang Onar's bonus itself -- the helper does" % fn_name)
		assert_false(body.contains("active_studying"),
			"%s() must not compute its own weights -- the helper does" % fn_name)


## The source of `func <fn_name>(` up to the next top-level function, or ""
## when there is no such function.
func _function_body(src: String, fn_name: String) -> String:
	var start := src.find("\nfunc %s(" % fn_name)
	if start == -1:
		return ""
	var end := src.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var at := src.find(marker, start + 1)
		if at != -1 and at < end:
			end = at
	return src.substr(start, end - start)


# ───────────────────────────── the day/week header (2026-09-21)

## With BookClockWidget's banner showing "Senin", DayScreen/DayLabel showed
## it a second time a few hundred pixels away. Hidden, not deleted: this
## suite pins the node path, and removing a node from a shipped scene is a
## bigger decision than de-duplicating a label needs to be. SchoolDay.gd
## still writes its text, so one edit brings it back if this is wrong on a
## real screen.
func test_the_day_name_is_not_shown_twice() -> void:
	var block := _scene_node_block('[node name="DayLabel" type="Label" parent="DayScreen"')
	assert_true(block != "", "DayScreen/DayLabel must still exist")
	if block == "":
		return
	assert_true(block.contains("visible = false"),
		"DayLabel must be hidden now the header carries the day")


## One node's block in SchoolDay.tscn: from its [node] header to the next
## one. A fixed character window is not good enough here -- DayNumberLabel
## and DayLabel are seven lines apart, so a 400-char window read one node's
## properties as the other's.
func _scene_node_block(header: String) -> String:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/SchoolSimulation/SchoolDay.tscn")
	var start := src.find(header)
	if start < 0:
		return ""
	var next := src.find("[node ", start + header.length())
	return src.substr(start, (next - start) if next > 0 else -1)


## DayNumberLabel stays: "Hari 1 dari 5" is the day's place in the WEEK,
## which the header does not carry -- the header is the day's name and the
## week's place in the grade. Three facts, no repeats.
func test_the_day_number_is_still_shown() -> void:
	var block := _scene_node_block(
		'[node name="DayNumberLabel" type="Label" parent="DayScreen"')
	assert_true(block != "", "DayScreen/DayNumberLabel must exist")
	if block == "":
		return
	assert_false(block.contains("visible = false"),
		"the day-of-week counter must stay visible")
