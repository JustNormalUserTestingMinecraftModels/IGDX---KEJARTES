@tool
extends McpTestSuiteCompat

## The school day used to be one continuous sky sweep with the event
## landing at a random 50-80% of it. It is now three named poses and two
## transitions, with the event pinned to midday.
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


func test_three_poses_are_exports_not_magic_numbers() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for knob in ["dawn_rotation_degrees", "midday_rotation_degrees",
			"evening_rotation_degrees"]:
		assert_contains(src, "@export var %s" % knob,
			"each pose must be tunable in the Inspector")


func test_retired_the_single_sweep_exports() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in ["start_rotation_degrees", "total_rotation_degrees"]:
		assert_false(src.contains(retired),
			"%s is superseded by the three pose exports" % retired)


func test_each_pose_sits_on_the_sky_it_is_named_for() -> void:
	# The arc was 0 / -90 / -180 -- inherited from the old start 0 /
	# total -180 sweep -- until a screenshot showed 0 renders as NIGHT.
	# The original docstring claimed 0 was "morning", so the art and the
	# naming had disagreed since the sweep was written. Shifted one
	# quarter-turn so dawn is morning breaking, midday is full day and
	# evening is dusk.
	var w := _widget()
	assert_eq(w.dawn_rotation_degrees, -90.0, "dawn should be morning breaking")
	assert_eq(w.midday_rotation_degrees, -180.0, "midday should be full bright day")
	assert_eq(w.evening_rotation_degrees, -270.0, "evening should be dusk")
	w.free()


func test_the_day_still_sweeps_counter_clockwise() -> void:
	# The mechanism reference's arrows: the sky turns one way across the
	# day. Re-anchoring the arc must not have flipped its direction.
	var w := _widget()
	assert_true(w.midday_rotation_degrees < w.dawn_rotation_degrees,
		"midday must sit further counter-clockwise than dawn")
	assert_true(w.evening_rotation_degrees < w.midday_rotation_degrees,
		"evening must sit further counter-clockwise than midday")
	w.free()


func test_set_phase_snaps_the_sky_to_each_pose() -> void:
	var w := _widget()
	var sky := w.get_node("SkyBackground") as Control
	w.set_phase(BookClockWidget.Phase.DAWN)
	assert_true(is_equal_approx(sky.rotation_degrees, w.dawn_rotation_degrees),
		"DAWN should place the sky at its dawn angle")
	w.set_phase(BookClockWidget.Phase.MIDDAY)
	assert_true(is_equal_approx(sky.rotation_degrees, w.midday_rotation_degrees),
		"MIDDAY should place the sky at its midday angle")
	w.set_phase(BookClockWidget.Phase.EVENING)
	assert_true(is_equal_approx(sky.rotation_degrees, w.evening_rotation_degrees),
		"EVENING should place the sky at its evening angle")
	w.free()


func test_transition_to_returns_its_tween_so_schoolday_can_await_it() -> void:
	var w := _widget()
	var tween := w.transition_to(BookClockWidget.Phase.MIDDAY, 1.0)
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
	# Chosen in motion-lab on 2026-09-07: SINE/IN_OUT over 2.0s. A sine
	# ease-in-out is the gentlest of the twelve at both ends, which is
	# what a sky wheeling overhead wants -- no snap into or out of rest.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "Tween.TRANS_SINE", "the tuned transition is SINE")
	assert_contains(src, "Tween.EASE_IN_OUT", "the tuned ease is IN_OUT")
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


func test_set_progress_still_maps_through_the_midday_pose() -> void:
	# Old callers and the day progress bar keep working, and the middle
	# of the day now lands exactly on the midday pose rather than
	# halfway along one long sweep.
	var w := _widget()
	w.set_progress(0.5)
	assert_true(is_equal_approx(w.current_rotation_degrees(), w.midday_rotation_degrees),
		"progress 0.5 should sit on the midday pose, got %f" % w.current_rotation_degrees())
	w.free()


func test_midday_pose_can_be_moved_independently() -> void:
	# The point of naming the middle pose: it is no longer forced to be
	# the arithmetic mean of the other two.
	var w := _widget()
	w.midday_rotation_degrees = -120.0
	w.set_progress(0.5)
	assert_true(is_equal_approx(w.current_rotation_degrees(), -120.0),
		"a retuned midday pose should be honoured, got %f" % w.current_rotation_degrees())
	w.free()


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


func test_event_fires_at_midday_not_at_a_random_afternoon_point() -> void:
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	assert_contains(src, "EVENT_TRIGGER_PCT",
		"the event trigger point must be a named const")
	assert_contains(src, "const EVENT_TRIGGER_PCT := 50.0",
		"the event must land on the midday pose")
	assert_false(src.contains("randf_range(0.5, 0.8)"),
		"the event should no longer land at a random point in the day")
