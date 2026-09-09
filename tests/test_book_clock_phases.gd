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
			"%s is superseded by the three pose exports" % retired)


func test_each_pose_sits_on_the_sky_it_is_named_for() -> void:
	var w := _widget()
	assert_eq(w.dawn_rotation_degrees, -90.0, "dawn should be morning breaking")
	assert_eq(w.evening_rotation_degrees, -270.0, "evening should be dusk")
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


func test_sky_cover_margin_stays_above_the_source_art_defect_floor() -> void:
	# transition_background.png has a stray artifact the artist left
	# visible: a bluish night-street scene pasted into its bottom-left
	# corner (roughly texture-space x 0..442, y 1837..2047). The sky
	# rotates about its own centre, so a texel's distance from centre is
	# rotation-invariant, and this artifact's nearest texel to centre sits
	# ~1000.4 texels out. On the project's default 1080x1920 layout with
	# the default bottom-centre pivot, the artifact clears every screen
	# corner only once sky_cover_margin exceeds ~1.0236 (measured worst
	# case below that: 45 screen px of clipping in the top-right corner at
	# -200 degrees). 1.04 is a floor with headroom above that threshold,
	# not the exact tuned default (1.06) -- pinning the exact value here
	# would fail this test on every future motion-lab nudge for no reason.
	var w := _widget()
	assert_true(w.sky_cover_margin >= 1.04,
		"sky_cover_margin must stay above the source-art defect threshold (~1.0236), got %f"
			% w.sky_cover_margin)
	w.free()


func test_event_fires_at_midday_not_at_a_random_afternoon_point() -> void:
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	assert_contains(src, "EVENT_TRIGGER_PCT",
		"the event trigger point must be a named const")
	assert_contains(src, "const EVENT_TRIGGER_PCT := 50.0",
		"the event must land on the midday pose")
	assert_false(src.contains("randf_range(0.5, 0.8)"),
		"the event should no longer land at a random point in the day")
