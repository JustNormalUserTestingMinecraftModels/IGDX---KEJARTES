@tool
extends McpTestSuiteCompat

## The school day was one continuous sweep, then three named poses with
## the event pinned to midday, and is now two poses and one uninterrupted
## sweep: the sky no longer rests mid-day while the event popup is up.
##
## Must be @tool; no test here may be a coroutine -- which is why
## transition_to is tested by inspecting the Tween it returns rather
## than by awaiting it.

func suite_name() -> String:
	return "book_clock_phases"


const SCRIPT_PATH := "res://Scripts/SchoolSimulation/BookClockWidget.gd"
const SCENE_PATH := "res://Scenes/SchoolSimulation/BookClockWidget.tscn"
const SCHOOLDAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"


func _widget() -> BookClockWidget:
	var w := (load(SCENE_PATH) as PackedScene).instantiate() as BookClockWidget
	w.size = Vector2(1080, 1920)
	return w


func test_both_poses_are_exports_not_magic_numbers() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for knob in ["dawn_rotation_degrees", "evening_rotation_degrees"]:
		assert_contains(src, "@export var %s" % knob,
			"each pose must be tunable in the Inspector")


func test_retired_the_midday_pose() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("midday_rotation_degrees"),
		"the midday angle is derived from the arc now, not authored")


func test_retired_the_single_sweep_exports() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in ["start_rotation_degrees", "total_rotation_degrees"]:
		assert_false(src.contains(retired),
			"%s is superseded by the two pose exports" % retired)


func test_each_pose_sits_on_the_sky_it_is_named_for() -> void:
	# Picked from a 12-angle contact sheet of the real composite on
	# 2026-09-10: 60 shows the same frame as -300, the darkest one.
	var w := _widget()
	assert_eq(w.dawn_rotation_degrees, 60.0, "dawn should open on the dark sky")
	assert_eq(w.evening_rotation_degrees, -300.0, "evening should close on the dark sky")
	w.free()


func test_the_day_is_one_full_turn() -> void:
	# Dark to dark on the same frame: dawn sits exactly one turn above
	# evening, so sunrise, midday and dusk all pass in between.
	var w := _widget()
	assert_true(is_equal_approx(w.dawn_rotation_degrees - w.evening_rotation_degrees, 360.0),
		"the sky should turn exactly one full circle across the day")
	w.free()


func test_the_day_still_sweeps_counter_clockwise() -> void:
	var w := _widget()
	assert_true(w.evening_rotation_degrees < w.dawn_rotation_degrees,
		"evening must sit further counter-clockwise than dawn")
	w.free()


func test_set_phase_snaps_the_sky_to_each_pose() -> void:
	var w := _widget()
	var sky := w.get_node("SkyBackground") as Control
	w.set_phase(BookClockWidget.Phase.DAWN)
	assert_true(is_equal_approx(sky.rotation_degrees, w.dawn_rotation_degrees),
		"DAWN should place the sky at its dawn angle")
	w.set_phase(BookClockWidget.Phase.EVENING)
	assert_true(is_equal_approx(sky.rotation_degrees, w.evening_rotation_degrees),
		"EVENING should place the sky at its evening angle")
	w.free()


func test_transition_to_returns_its_tween_so_schoolday_can_await_it() -> void:
	var w := _widget()
	var tween := w.transition_to(BookClockWidget.Phase.EVENING, 1.0)
	assert_not_null(tween, "transition_to must hand its Tween back to the caller")
	assert_true(tween is Tween, "and it must actually be a Tween")
	tween.kill()
	w.free()


func test_transition_duration_is_a_single_tunable_knob() -> void:
	# motion-lab patches one place, not every call site.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "@export var transition_duration",
		"how long a transition takes must be an Inspector knob")


func test_transition_carries_the_tuned_motion_lab_preset() -> void:
	# 2026-09-10: the day eases OUT -- it sets off briskly from dawn and
	# settles gently into evening. SINE/OUT over 2.0s per phase is the
	# starting preset; a motion-lab token re-tunes it here and in the script.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "Tween.TRANS_SINE", "the tuned transition is SINE")
	assert_contains(src, "Tween.EASE_OUT", "the day eases out")
	assert_false(src.contains("Tween.EASE_IN_OUT"), "the in-out ease is retired")
	var w := _widget()
	assert_true(is_equal_approx(w.transition_duration, 2.0),
		"the tuned duration is 2.0s, got %f" % w.transition_duration)
	w.free()


func test_schoolday_paces_both_phases_off_the_clock() -> void:
	# The sky and the day's progress bar must not drift: SchoolDay takes
	# each phase's length from the widget rather than splitting its own
	# constant, so the tuned sweep is the single source of pacing.
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	assert_contains(src, "func _phase_duration",
		"SchoolDay should derive its phase length, not hardcode a split")
	assert_contains(src, "transition_duration",
		"and that length should come off the BookClock")
	# Both phases, and only the phases -- counting call sites rather than
	# mentions, so a doc comment naming the helper cannot skew this.
	assert_eq(src.count(":= _phase_duration()"), 2,
		"both day phases should take their length from the clock")


func test_the_arc_is_one_straight_lerp_between_the_two_poses() -> void:
	# With midday gone, progress 0.5 is the arithmetic middle of the arc
	# by construction rather than a separately authored angle.
	var w := _widget()
	w.set_progress(0.5)
	var want := (w.dawn_rotation_degrees + w.evening_rotation_degrees) * 0.5
	assert_true(is_equal_approx(w.current_rotation_degrees(), want),
		"progress 0.5 should sit halfway along the arc, got %f want %f"
			% [w.current_rotation_degrees(), want])
	w.free()


func test_schoolday_sweeps_the_sky_once_across_the_whole_day() -> void:
	# The sky used to be handed two transitions with the event between
	# them, so it visibly froze at midday behind the popup. One call now,
	# spanning both phases.
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	# Count CALL sites, not mentions: each one is guarded by a
	# has_method("transition_to") test, so the bare string appears twice
	# per sweep and counting it would read 2 for a single call.
	assert_eq(src.count(".call(\"transition_to\""), 1,
		"the sky is swept exactly once per day")
	assert_false(src.contains("BookClockWidget.Phase.MIDDAY"),
		"nothing drives the sky to a midday pose any more")


func test_rotation_stays_monotone_across_the_whole_day() -> void:
	var w := _widget()
	var previous: float = INF
	for i in range(21):
		w.set_progress(float(i) / 20.0)
		var current: float = w.current_rotation_degrees()
		assert_true(current <= previous + 0.001,
			"the sky must never turn back on itself at progress %f" % (float(i) / 20.0))
		previous = current
	w.free()


func test_event_fires_at_the_days_halfway_point_not_a_random_afternoon_point() -> void:
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	assert_contains(src, "EVENT_TRIGGER_PCT",
		"the event trigger point must be a named const")
	assert_contains(src, "const EVENT_TRIGGER_PCT := 50.0",
		"the event must land at the 50% point of the day, there is no midday pose to land on any more")
	assert_false(src.contains("randf_range(0.5, 0.8)"),
		"the event should no longer land at a random point in the day")
