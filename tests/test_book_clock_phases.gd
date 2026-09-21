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
	# Tuned in motion-lab on 2026-09-10 for the full-turn day: QUAD/OUT over
	# 1.64s per phase. The day sets off briskly from dawn and settles into
	# evening, and the whole sweep (two phases) takes 3.28s.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "Tween.TRANS_QUAD", "the tuned transition is QUAD")
	assert_contains(src, "Tween.EASE_OUT", "the day eases out")
	assert_false(src.contains("Tween.EASE_IN_OUT"), "the in-out ease is retired")
	var w := _widget()
	assert_true(is_equal_approx(w.transition_duration, 1.64),
		"the tuned duration is 1.64s per phase, got %f" % w.transition_duration)
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


# ───────────────────────────── the day/week header (2026-09-21)
# BookClockWidget took the weekday through set_day() and displayed nothing;
# the player's only day readout was two bare labels in SchoolDay's corner,
# with no week count anywhere on the screen.

func test_set_week_formats_like_the_event_dialogue() -> void:
	var w = load(SCENE_PATH).instantiate()
	w.set_week(3, 6)
	assert_eq(w.week_text(), "3/6",
		'the week must read "%d/%d", exactly as EventDialogue writes it')
	w.free()


func test_set_day_writes_the_banner_not_just_the_variable() -> void:
	var w = load(SCENE_PATH).instantiate()
	w.set_day("Selasa")
	assert_eq(w.day_name(), "Selasa", "set_day still records the name")
	assert_eq(w.day_text(), "Selasa", "and now it reaches the banner too")
	w.free()


## The grade ladder, which needs no code of its own: get_max_weeks() returns
## 6/12/16 for Kelas 7/8/9. A hard-coded 6 would pass every Kelas 7 test and
## be wrong for two thirds of the game.
func test_the_week_count_follows_the_grade() -> void:
	var w = load(SCENE_PATH).instantiate()
	for pair in [[3, 6], [9, 12], [14, 16]]:
		w.set_week(pair[0], pair[1])
		assert_eq(w.week_text(), "%d/%d" % [pair[0], pair[1]],
			"Kelas with %d weeks must read %d/%d" % [pair[1], pair[0], pair[1]])
	w.free()


func test_reset_clears_the_header() -> void:
	var w = load(SCENE_PATH).instantiate()
	w.set_day("Rabu")
	w.set_week(2, 6)
	w.reset()
	assert_eq(w.day_text(), "", "reset must clear the banner")
	assert_eq(w.week_text(), "", "reset must clear the week")
	w.free()


## The source, not just the format: both screens must read the same two
## GameState values, or they can drift apart by a week.
func test_school_day_feeds_the_header_from_gamestate() -> void:
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	# `.call("set_week", ...)`, matching how this file already drives the
	# widget -- book_clock_widget is typed Control, not BookClockWidget.
	assert_true(src.contains('"set_week"'),
		"SchoolDay must tell the widget which week it is")
	assert_true(src.contains("GameState.get_max_weeks()"),
		"the week count must come from GameState, not a literal")


## The header is authored, and it is EventDialogue's header rather than a
## lookalike: the same variations, not a set of overrides that happen to
## match. The project's rule forbids the overrides anyway.
func test_the_header_is_authored_with_the_shared_variations() -> void:
	var w = load(SCENE_PATH).instantiate()
	for path in [BookClockWidget.DAY_LABEL_PATH, BookClockWidget.WEEK_LABEL_PATH]:
		assert_true(w.get_node_or_null(path) != null,
			"the scene must author %s" % path)
	var banner: Control = w.get_node_or_null("Header/DayBanner")
	assert_true(banner != null, "the day banner must exist")
	if banner != null:
		assert_eq(String(banner.theme_type_variation), "DayBannerPanel",
			"the banner must use EventDialogue's own panel variation")
	var day_label: Label = w.get_node_or_null(BookClockWidget.DAY_LABEL_PATH)
	if day_label != null:
		assert_eq(String(day_label.theme_type_variation), "DayBannerLabel",
			"the day must use EventDialogue's own label variation")
	var minggu: Label = w.get_node_or_null("Header/Calendar/Text/MingguLabel")
	if minggu != null:
		assert_eq(String(minggu.theme_type_variation), "CalendarLabel",
			"the Minggu caption must use the shared calendar variation")
	w.free()


## The illustration asked for by name: the lobby's daily-login calendar, not
## EventDialogue's flat calendar_badge.png and nothing newly drawn.
func test_the_badge_wears_the_daily_login_calendar() -> void:
	var w = load(SCENE_PATH).instantiate()
	var cal: TextureRect = w.get_node_or_null("Header/Calendar")
	assert_true(cal != null, "the calendar badge must exist")
	if cal != null:
		assert_true(cal.texture != null, "the badge must have art")
		if cal.texture != null:
			assert_true(String(cal.texture.resource_path).ends_with("icon_daily_login.png"),
				"the badge must wear the daily-login calendar")
	w.free()


## The daily-login calendar is drawn in perspective: its paper rises to the
## right. Straight text on it reads as sliding off the page. -9 degrees is
## measured from the art -- a least-squares fit through the first cream
## pixel in each of 48 columns gave a slope of -0.1579, or -8.97 degrees --
## not eyeballed.
func test_the_badge_text_is_rotated_onto_the_paper() -> void:
	var w = load(SCENE_PATH).instantiate()
	var text_box: Control = w.get_node_or_null("Header/Calendar/Text")
	assert_true(text_box != null, "the badge's text container must exist")
	if text_box != null:
		assert_true(absf(text_box.rotation_degrees - (-9.0)) < 0.5,
			"the text must sit on the tilted paper, got %f" % text_box.rotation_degrees)
	w.free()


## The header draws over the day screen, so it must not eat taps meant for
## the screen above it -- SchoolDay closes its day summary on a tap anywhere.
func test_the_header_ignores_the_mouse() -> void:
	var w = load(SCENE_PATH).instantiate()
	for path in ["Header", "Header/Calendar", "Header/DayBanner"]:
		var n: Control = w.get_node_or_null(path)
		assert_true(n != null, "%s must exist" % path)
		if n != null:
			assert_eq(n.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s must not take input from the screen above it" % path)
	w.free()
