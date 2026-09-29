@tool
extends McpTestSuite

## Regression tests for the school-week bug sweep of 2026-09-30: SchoolDay's
## back press, its skip path and exit cleanup, StudentManager's stat log and
## weekly minigame cap, and AturJadwal's holiday lock.
##
## Behavioural where a pure piece can run on its own -- StudentManager and
## StudentData built with .new(), SchoolDay's script instanced with .new()
## (never its .tscn, which the editor swaps for a placeholder; see
## tests/test_wirausaha.gd) and AturJadwal's static lock_holidays(). Source
## scans where only the live screen could run the path.
##
## Every test saves and restores the GameState it touches. Must be @tool, and
## no test here may be a coroutine.

## The week simulation screen's script.
const SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
## The schedule screen's script, for its static lock_holidays().
const ATUR_JADWAL := "res://Scripts/AturJadwal/AturJadwal.gd"


func suite_name() -> String:
	return "bugfix_week"


# ------------------------------------------------------------------ helpers

## A manager holding only `roster` (StudentData), none of
## initialize_students()' demo cast.
func _manager(roster: Array) -> StudentManager:
	var sm := StudentManager.new()
	sm.students.clear()
	sm.minigame_history.clear()
	sm.daily_stat_log.clear()
	for s in roster:
		sm.students.append(s)
	return sm


## One plain student: no quirk, Seimbang, the given needs.
func _student(id: int, student_name: String, energy: float, mood: float) -> StudentData:
	var s := StudentData.new()
	s.id = id
	s.student_name = student_name
	s.specialty_category = "Seimbang"
	s.energy = energy
	s.mood = mood
	return s


## The sum of one student's logged `stat_key` deltas for `day_name`, from
## entries whose source is `source` ("" for any source).
func _logged(sm: StudentManager, day_name: String, student_name: String,
		stat_key: String, source: String = "") -> float:
	var total := 0.0
	for entry in sm.daily_stat_log.get(day_name, []):
		if entry["student_name"] != student_name or entry["stat_key"] != stat_key:
			continue
		if source == "" or entry["source"] == source:
			total += float(entry["delta"])
	return total


## The source of `func <fn_name>(` up to the next top-level function, or ""
## when there is no such function.
func _body(src: String, fn_name: String) -> String:
	var start := src.find("\nfunc %s(" % fn_name)
	if start == -1:
		return ""
	var end := src.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var at := src.find(marker, start + 1)
		if at != -1 and at < end:
			end = at
	return src.substr(start, end - start)


## A real SchoolDay script instance (not the scene), with a stand-in
## back_button, shown or hidden. Free both with _free_day().
func _day_with_button(shown: bool) -> Object:
	var day: Object = load(SCHOOL_DAY).new()
	var button := Button.new()
	button.visible = shown
	day.set("back_button", button)
	return day


## Frees a _day_with_button() instance and its stand-in button.
func _free_day(day: Object) -> void:
	var button: Button = day.get("back_button")
	if is_instance_valid(button):
		button.free()
	day.free()


# ------------------------------- findings 0/7/8/15/16/22/29: the back press

## Positive control for the tests below: the instance is the real script,
## not an editor placeholder that would ignore every call.
func test_school_day_instance_is_real() -> void:
	var day := _day_with_button(false)
	assert_true(day.has_method("_on_back_pressed"), "SchoolDay.new() must carry its methods")
	assert_true("_leaving" in day, "SchoolDay carries the _leaving guard")
	_free_day(day)


## Mid-week the continue button is hidden: a device back press (a minigame's
## pause gesture, a stray edge swipe) must not leave the week.
func test_device_back_mid_week_does_not_leave() -> void:
	var saved_week: int = GameState.minggu_ke
	var day := _day_with_button(false)
	day.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(GameState.minggu_ke, saved_week, "a hidden continue button means back is ignored")
	assert_false(day.get("_leaving"), "nothing started leaving")
	_free_day(day)
	GameState.minggu_ke = saved_week


## The end-of-week-1 tutorial is up over a visible button: back waits for it.
func test_device_back_during_the_tutorial_does_not_leave() -> void:
	var saved_week: int = GameState.minggu_ke
	var day := _day_with_button(true)
	day.set("_is_tutorial_active", true)
	day.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(GameState.minggu_ke, saved_week, "the tutorial owns the screen")
	assert_false(day.get("_leaving"))
	_free_day(day)
	GameState.minggu_ke = saved_week


## A second tap (or tap + device back) while the first is fading out must not
## advance the week again.
func test_a_second_back_press_does_nothing() -> void:
	var saved_week: int = GameState.minggu_ke
	var day := _day_with_button(true)
	day.set("_leaving", true)
	day.call("_on_back_pressed")
	assert_eq(GameState.minggu_ke, saved_week, "minggu_ke advances once per SchoolDay")
	_free_day(day)
	GameState.minggu_ke = saved_week


## The notification is gated on the continue button, and the first press
## locks the handler and the button before the week counter moves.
func test_back_handler_is_guarded_before_the_week_advances() -> void:
	var src := FileAccess.get_file_as_string(SCHOOL_DAY)
	assert_true(src.contains("NOTIFICATION_WM_GO_BACK_REQUEST and back_button.visible"),
		"device back only while the week-end continue button is up")
	var body := _body(src, "_on_back_pressed")
	var guard := body.find("if _leaving:")
	var lock := body.find("_leaving = true")
	var disable := body.find("back_button.disabled = true")
	var advance := body.find("GameState.minggu_ke += 1")
	assert_true(guard != -1 and guard < lock and lock < advance and disable != -1 and disable < advance,
		"guard, lock and disable all come before minggu_ke += 1")
	assert_true(body.contains("AudioDirector.stop_minigame_bgm()"),
		"leaving the week also silences any minigame track")


# ----------------------------------------- finding 4: skip / exit audio leaks

func test_skip_mid_minigame_restores_audio_and_the_day_picture() -> void:
	var body := _body(FileAccess.get_file_as_string(SCHOOL_DAY), "skip_to_results")
	var free_at := body.find("current_minigame.queue_free()")
	assert_true(free_at != -1, "skip_to_results still frees a running minigame")
	for needle in ["AudioDirector.stop_minigame_bgm()", "AudioDirector.resume_bgm()", "_day_cover.uncover(null)"]:
		var at := body.find(needle)
		assert_true(at != -1 and at < free_at, "%s before the minigame is freed" % needle)


func test_leaving_school_day_by_any_route_stops_its_audio() -> void:
	var body := _body(FileAccess.get_file_as_string(SCHOOL_DAY), "_exit_tree")
	assert_true(body.contains("Engine.is_editor_hint()"), "no audio side effects in the editor")
	assert_true(body.contains("AudioDirector.stop_ambience()"), "the classroom bed stops")
	assert_true(body.contains("AudioDirector.stop_minigame_bgm()"), "a minigame track stops")


# -------------------------------------- finding 9: needs logged exactly once

## Istirahat's recovery rides the net "decay" entry; logging it again as
## "activity" made the day summary's needs bars start far too low.
func test_istirahat_needs_are_logged_once() -> void:
	var saved_sched: Dictionary = GameState.day_schedules
	GameState.day_schedules = {41: {"Senin": {"category": "Istirahat"}}}
	var s := _student(41, "Rehat", 40.0, 40.0)
	var sm := _manager([s])
	sm.apply_daily_decay_all("Senin")
	assert_true(is_equal_approx(_logged(sm, "Senin", "Rehat", "energy"), s.energy - 40.0),
		"logged energy sums to the real change")
	assert_true(is_equal_approx(_logged(sm, "Senin", "Rehat", "mood"), s.mood - 40.0),
		"logged mood sums to the real change")
	sm.free()
	GameState.day_schedules = saved_sched


## Same for Wirausaha's flat cost, which sits inside the "decay" entry.
func test_wirausaha_cost_is_logged_once() -> void:
	var saved_sched: Dictionary = GameState.day_schedules
	var saved_pending: Dictionary = GameState.pending_earnings.duplicate()
	GameState.day_schedules = {42: {"Senin": {"category": "Wirausaha"}}}
	var s := _student(42, "Dagang", 40.0, 40.0)
	var sm := _manager([s])
	sm.apply_daily_decay_all("Senin")
	assert_true(is_equal_approx(_logged(sm, "Senin", "Dagang", "energy"), s.energy - 40.0),
		"logged energy sums to the real change")
	assert_true(is_equal_approx(_logged(sm, "Senin", "Dagang", "mood"), s.mood - 40.0),
		"logged mood sums to the real change")
	sm.free()
	GameState.day_schedules = saved_sched
	GameState.pending_earnings = saved_pending


# ------------------------------------------- finding 10: events reach the log

## A class-wide event logs what really moved, clamping included.
func test_a_class_event_logs_what_really_changed() -> void:
	var s := _student(43, "Hujan", 95.0, 50.0)
	var sm := _manager([s])
	sm.apply_event("Selasa", "Uji Kelas", "rincian", sm.students, "", 0.0, 20.0, -10.0)
	assert_true(is_equal_approx(_logged(sm, "Selasa", "Hujan", "energy", "event"), 5.0),
		"energy 95 + 20 clamps at 100, so +5 is logged")
	assert_true(is_equal_approx(_logged(sm, "Selasa", "Hujan", "mood", "event"), -10.0))
	var entry: Dictionary = sm.minigame_history.back()
	assert_eq(entry["category"], "Event", "still one history entry, as an event")
	assert_eq(entry["affected_students"].size(), 1, "the whole (one-student) class")
	assert_eq(entry["affected_students"][0], "Hujan")
	sm.free()


## A pick-students event logs its skill gain and only its picked students.
func test_a_pick_students_event_logs_its_skill() -> void:
	var picked := _student(44, "Ikut", 60.0, 50.0)
	picked.akademis = 40.0
	var left_out := _student(45, "Absen", 60.0, 50.0)
	var sm := _manager([picked, left_out])
	var chosen: Array[StudentData] = [picked]
	sm.apply_event("Rabu", "Les", "1 siswa", chosen, "Akademis", 15.0, -15.0, 0.0)
	assert_true(is_equal_approx(_logged(sm, "Rabu", "Ikut", "akademis", "event"), 15.0))
	assert_true(is_equal_approx(_logged(sm, "Rabu", "Ikut", "energy", "event"), picked.energy - 60.0))
	assert_true(is_equal_approx(_logged(sm, "Rabu", "Absen", "energy"), 0.0), "the left-out student logs nothing")
	sm.free()


func test_school_day_routes_every_event_through_apply_event() -> void:
	var src := FileAccess.get_file_as_string(SCHOOL_DAY)
	assert_eq(src.count("student_manager.apply_event("), 3, "Nasi Kotak, Hujan and the pick-students events")
	assert_false(_body(src, "_run_event").contains("record_event_result("))
	assert_false(_body(src, "_handle_interactive_event").contains("record_event_result("))


# ------------------------------- finding 11: a skipped event is not a minigame

func test_a_skipped_event_is_logged_as_an_event_only() -> void:
	var saved_stats: RunStats = GameState.run_stats
	GameState.run_stats = RunStats.new()
	var day: Object = load(SCHOOL_DAY).new()
	var sm := _manager([_student(46, "Lewat", 60.0, 60.0)])
	day.set("student_manager", sm)
	day.call("_skip_event", "Kamis")
	var entry: Dictionary = sm.minigame_history.back()
	assert_eq(entry["category"], "Event")
	assert_eq(GameState.run_stats.minigames_won + GameState.run_stats.minigames_lost, 0,
		"run_stats' minigame tally is untouched")
	assert_eq(day.get("events_triggered_this_week"), 1)
	day.free()
	sm.free()
	GameState.run_stats = saved_stats


## Positive control: a skipped minigame still reaches the run tally.
func test_a_skipped_minigame_still_counts_as_a_minigame() -> void:
	var saved_stats: RunStats = GameState.run_stats
	var saved_gain: Dictionary = GameState.minigame_gain_this_week
	GameState.run_stats = RunStats.new()
	GameState.minigame_gain_this_week = {}
	var day: Object = load(SCHOOL_DAY).new()
	var sm := _manager([_student(47, "Main", 60.0, 60.0)])
	day.set("student_manager", sm)
	day.call("_skip_minigame", "Kamis", "Akademis")
	assert_eq(GameState.run_stats.minigames_won + GameState.run_stats.minigames_lost, 1)
	day.free()
	sm.free()
	GameState.run_stats = saved_stats
	GameState.minigame_gain_this_week = saved_gain


# ----------------------------------- finding 13: the cap never lowers a skill

## A capped win near 100 lands on before + allowed; it used to clamp to 100
## and then subtract the whole overflow.
func test_a_capped_win_near_the_ceiling_never_lowers_the_skill() -> void:
	var saved_grade: int = GameState.current_grade
	var saved_gain: Dictionary = GameState.minigame_gain_this_week
	var saved_stats: RunStats = GameState.run_stats
	GameState.run_stats = RunStats.new()
	GameState.current_grade = 7
	var cap: float = Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7
	var s := _student(48, "Pintar", 80.0, 80.0)
	s.akademis = 97.0
	GameState.minigame_gain_this_week = {48: cap - 2.0}
	var sm := _manager([s])
	var results: Array[Dictionary] = sm.record_minigame_result("Senin", "Akademis", "Q", true, 3, 4)
	assert_true(is_equal_approx(s.akademis, 99.0), "97 + the 2 points left, got %s" % s.akademis)
	assert_true(is_equal_approx(float(results[0]["deltas"]["stat_delta"]), 2.0), "reports what landed")
	GameState.minigame_gain_this_week = {48: cap}
	sm.record_minigame_result("Senin", "Akademis", "Q", true, 3, 4)
	assert_true(is_equal_approx(s.akademis, 99.0), "a spent cap adds nothing and takes nothing")
	sm.free()
	GameState.current_grade = saved_grade
	GameState.minigame_gain_this_week = saved_gain
	GameState.run_stats = saved_stats


# ------------------------------ finding 14: the holiday lock gives the day back

## The locked holiday entry AturJadwal builds (costs are placeholders here).
const _REST := {"category": "Istirahat", "holiday": true, "mood_cost": -5, "energy_cost": -5}
## A player's own entry for a day.
const _STUDY := {"category": "Akademis", "mood_cost": 10, "energy_cost": 10}
## Week 3's holidays, in AturJadwal.HOLIDAYS' shape.
const _WEEK_3 := {"Rabu": {"title": "Hari Kemerdekaan RI"}}


func test_a_holiday_keeps_and_later_restores_the_players_entry() -> void:
	var aturjadwal: GDScript = load(ATUR_JADWAL)
	var plan := {"Senin": _STUDY.duplicate(), "Rabu": _STUDY.duplicate()}
	aturjadwal.call("lock_holidays", plan, _WEEK_3, _REST)
	assert_eq(plan["Rabu"]["category"], "Istirahat", "the holiday rests")
	aturjadwal.call("lock_holidays", plan, _WEEK_3, _REST)
	assert_eq(plan["Rabu"]["pre_holiday"], _STUDY, "a second visit keeps the player's entry, not the lock")
	aturjadwal.call("lock_holidays", plan, {}, _REST)
	assert_eq(plan["Rabu"], _STUDY, "the next week gets Akademis back")
	assert_eq(plan["Senin"], _STUDY, "an ordinary day is untouched")


func test_a_holiday_on_an_unplanned_day_empties_afterwards() -> void:
	var aturjadwal: GDScript = load(ATUR_JADWAL)
	var plan := {}
	aturjadwal.call("lock_holidays", plan, _WEEK_3, _REST)
	assert_true(plan.has("Rabu"), "the holiday fills the day")
	aturjadwal.call("lock_holidays", plan, {}, _REST)
	assert_false(plan.has("Rabu"), "no plan to restore: empty, so the incomplete-week warning catches it")


# ------------------------------- finding 12: an Izin day is not an event

## A forced rest day is logged under its own category: the report's rows still
## show it (with the event styling), but WeekRecap counts it neither as a
## random event nor as a minigame.
func test_an_izin_day_is_neither_an_event_nor_a_minigame_in_the_recap() -> void:
	var sm := _manager([_student(49, "Lelah", 3.0, 60.0)])
	sm.record_event_result("Senin", "Izin Sakit/Istirahat", ["Lelah"], "Izin", {}, StudentManager.IZIN_CATEGORY)
	sm.record_event_result("Selasa", "Nasi Kotak Berbagi", ["Lelah"], "Semua siswa")
	var recap: Dictionary = WeekRecap.compute(sm)
	assert_eq(recap["events_count"], 1, "only the real event counts as an event")
	assert_eq(recap["minigames_total"], 0, "and the Izin day is not a minigame either")
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/StudentManager.gd")
	assert_true(src.contains("ijin_msg, {}, IZIN_CATEGORY)"), "the Izin call site logs its own category")
	sm.free()
