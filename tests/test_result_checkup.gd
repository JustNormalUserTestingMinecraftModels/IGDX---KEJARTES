@tool
extends McpTestSuiteCompat

## The end-of-week report (ResultCheckup), rebuilt on the Daily Results
## card. The card's own geometry, art and daily behaviour belong to
## tests/test_day_summary.gd; this suite owns the WEEKLY reading of it --
## week deltas instead of day deltas, and the two needs numbers the daily
## card does not show.
##
## Suite constraints, carried from tests/test_day_summary.gd:
##  * @tool, or the runner reports the class abstract.
##  * No coroutines -- the runner does suite.call(name) without awaiting,
##    so a tween is only observable through Tween.custom_step().
##  * The baked theme is assigned explicitly before a scene enters the
##    tree; ThemeDB's project-theme fallback does not populate under the
##    editor's own root.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _ROW_SCENE := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"
const _ROW_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd"
const _CHECKUP_SCENE := "res://Scenes/SchoolSimulation/ResultCheckup.tscn"
const _CHECKUP_SCRIPT := "res://Scripts/SchoolSimulation/ResultCheckup.gd"
const _LOGS_SCENE := "res://Scenes/SchoolSimulation/WeekLogsPopup.tscn"


func suite_name() -> String:
	return "result_checkup"


## Snapshot the active tweens, run `action`, then fast-forward only the
## tweens it created by `duration` seconds. Lifted from
## tests/test_day_summary.gd:37 -- diffing against the before-snapshot
## keeps a tween still finishing from an earlier test (or from the
## editor's own UI) from being mistaken for this one's.
func _run_and_step(action: Callable, duration: float) -> void:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var after: Array = Engine.get_main_loop().get_processed_tweens()
	for tw in after:
		if not before.has(tw) and is_instance_valid(tw):
			tw.custom_step(duration)


## A card wearing the baked theme, in the tree so its @onready vars are
## live, freed by the runner.
func _card() -> DaySummaryStudentRow:
	var inst := (load(_ROW_SCENE) as PackedScene).instantiate() as DaySummaryStudentRow
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	return inst


## A student who opened the week on `start` and closed it on `finish`,
## with every target at 65. record_initial_stats() between the two is
## exactly what GameState does at conversion, so this is the shape the
## real week hands ResultCheckup.
func _student_with_week(start: Dictionary, finish: Dictionary) -> StudentData:
	var s := StudentData.new()
	s.student_name = "Marcel"
	s.target_akademis1 = 65.0
	s.target_akademis2 = 65.0
	s.target_akademis3 = 65.0
	for key in start:
		s.set(key, start[key])
	s.record_initial_stats()
	for key in finish:
		s.set(key, finish[key])
	return s


# ------------------------------------------------ the needs-delta labels

## The two numbers the week card adds. They live INSIDE their bars -- the
## card is fixed art and there are 37 free pixels between the bars' right
## edge (579) and the stat rows' left edge (616), which is not a label.
## They start hidden because the daily card must not grow a readout the
## mockup does not have.
func test_the_card_carries_a_hidden_delta_label_on_each_needs_bar() -> void:
	var inst := _card()
	var e := inst.get_node_or_null("EnergyBar/DeltaLabel") as Label
	var m := inst.get_node_or_null("MoodBar/DeltaLabel") as Label
	assert_not_null(e, "EnergyBar is missing its DeltaLabel")
	assert_not_null(m, "MoodBar is missing its DeltaLabel")
	assert_eq(e.theme_type_variation, &"DaySummaryStat",
		"the needs delta must wear the card's own number style")
	assert_eq(m.theme_type_variation, &"DaySummaryStat",
		"the needs delta must wear the card's own number style")
	assert_eq(e.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"the number is right-aligned inside its bar")
	assert_eq(m.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"the number is right-aligned inside its bar")
	assert_false(e.visible, "the needs delta must start hidden")
	assert_false(m.visible, "the needs delta must start hidden")


## Same sign rule as DaySummaryStatRow.format_value: the "+" is explicit
## and the "-" comes free from %d, so a loss never reads "+-12". Zero
## reads "+0" rather than blank, because an empty slot on the card looks
## like a bug.
func test_needs_delta_carries_an_explicit_sign() -> void:
	assert_eq(DaySummaryStudentRow.format_needs_delta(8.0), "+8",
		"a gain must carry its plus")
	assert_eq(DaySummaryStudentRow.format_needs_delta(-12.4), "-12",
		"a loss must not read '+-12'")
	assert_eq(DaySummaryStudentRow.format_needs_delta(0.0), "+0",
		"a flat week is still a number")
	assert_eq(DaySummaryStudentRow.format_needs_delta(2.6), "+3",
		"the number is rounded, not truncated")


# --------------------------------------------------- the weekly reading

## The whole point of the screen: the number over each stat track is the
## WEEK'S movement, not a day's. 40 -> 58 with the target at 65 reads
## "+18/65"; a stat that lost ground reads with a minus and no chevron.
func test_the_week_card_reads_the_whole_weeks_movement() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 40.0, "seni_budaya": 30.0, "olahraga": 55.0},
		{"akademis": 58.0, "seni_budaya": 31.0, "olahraga": 49.0})

	inst.setup_week_row(s)

	assert_eq(inst.stat_rows[0].value.text, "+18/65",
		"akademis moved 40 -> 58 across the week")
	assert_eq(inst.stat_rows[1].value.text, "+1/65",
		"seni budaya moved 30 -> 31 across the week")
	assert_eq(inst.stat_rows[2].value.text, "-6/65",
		"olahraga LOST ground and must read with a minus")
	assert_false(inst.stat_rows[2].chevron.visible,
		"the chevron is an up arrow; a losing week must not show one")


## The project's documented naming trap: target_akademis2 is the SENI
## target and target_akademis3 the OLAHRAGA one. Three distinct targets
## catch a card that read the wrong field for a stat.
func test_the_week_card_pairs_each_stat_with_its_own_target() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 40.0, "seni_budaya": 40.0, "olahraga": 40.0},
		{"akademis": 41.0, "seni_budaya": 42.0, "olahraga": 43.0})
	s.target_akademis1 = 65.0
	s.target_akademis2 = 70.0
	s.target_akademis3 = 75.0

	inst.setup_week_row(s)

	assert_eq(inst.stat_rows[0].value.text, "+1/65", "akademis reads target_akademis1")
	assert_eq(inst.stat_rows[1].value.text, "+2/70", "seni budaya reads target_akademis2")
	assert_eq(inst.stat_rows[2].value.text, "+3/75", "olahraga reads target_akademis3")


## The bars still read tonight's value -- what is new is the number
## beside them, which is the week's movement and is shown here (and only
## here). Energy usually falls over a week and mood usually does not; the
## pair below is deliberately one of each.
func test_the_week_card_shows_both_needs_deltas() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"energy": 80.0, "mood": 70.0},
		{"energy": 62.0, "mood": 85.0})

	inst.setup_week_row(s)

	# The number itself is never rendered any more (2026-09-03
	# interactivity spec, section 4) -- direction now reads as the
	# DeltaChevron's rotation. The label still carries the correct text
	# as data (format_needs_delta's own coverage stays meaningful) but
	# stays permanently hidden.
	assert_false(inst.energy_delta_label.visible,
		"the number is never rendered, even for a real delta")
	assert_false(inst.mood_delta_label.visible,
		"same for the mood number")
	assert_eq(inst.energy_delta_label.text, "-18",
		"energy fell 80 -> 62 across the week")
	assert_eq(inst.mood_delta_label.text, "+15",
		"mood rose 70 -> 85 across the week")
	var energy_chevron: TextureRect = inst.get_node("EnergyBar/DeltaChevron")
	var mood_chevron: TextureRect = inst.get_node("MoodBar/DeltaChevron")
	assert_true(energy_chevron.visible, "a real loss shows the energy chevron")
	assert_eq(energy_chevron.rotation_degrees, 180.0, "energy fell, so it points down")
	assert_true(mood_chevron.visible, "a real gain shows the mood chevron")
	assert_eq(mood_chevron.rotation_degrees, 0.0, "mood rose, so it points up")
	assert_true(is_equal_approx(inst.energy_bar.value, 62.0),
		"the bar itself still reads tonight's energy")
	assert_true(is_equal_approx(inst.mood_bar.value, 85.0),
		"the bar itself still reads tonight's mood")


## ResultCheckup iterates StudentManager.students and cannot hand over a
## null -- but the daily path can and does, and both entry points share
## the card. Empty bars and a blank name are the honest answer; the
## scene's baked 36/82 placeholders are not.
func test_the_week_card_empties_itself_for_a_missing_student() -> void:
	var inst := _card()

	inst.setup_week_row(null)

	assert_eq(inst.name_label.text, "", "an absent student has no name to print")
	assert_true(is_equal_approx(inst.energy_bar.value, 0.0),
		"an absent student must not inherit the mockup's 36% energy")
	assert_true(is_equal_approx(inst.mood_bar.value, 0.0),
		"an absent student must not inherit the mockup's 82% mood")
	assert_false(inst.energy_delta_label.visible,
		"there is no delta to show for a student we do not have")
	assert_false(inst.mood_delta_label.visible,
		"there is no delta to show for a student we do not have")


## Both entry points must draw their three rows through the same code --
## two hand-rolled loops would drift on the next change to the trap.
func test_both_entry_points_share_one_stat_row_writer() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("func _write_stat_rows("),
		"the shared stat-row writer must exist")
	assert_eq(src.count("stat_rows[i].set_stat("), 1,
		"exactly one place may drive the stat rows")


# ---------------------------------------------------- the week's replay

## setup_week_row must land the final value on its own, so a card that is
## never animated is still correct; play_week_gain then rewinds and grows
## back. 26 -> 52 against a target of 65 is 40% -> 80%.
func test_the_week_card_rewinds_its_tracks_to_monday() -> void:
	var inst := _card()
	var s := _student_with_week({"akademis": 26.0}, {"akademis": 52.0})
	inst.setup_week_row(s)
	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01,
		"setup alone must leave tonight's 52/65 on the track")

	inst.play_week_gain()

	assert_true(absf(inst.stat_rows[0].track.value - 40.0) <= 0.01,
		"play_week_gain must rewind the track to Monday's 26/65 = 40%")


## The needs bars DO move on the weekly card. The spec refuses to animate
## them on the daily one, because one day's decay replayed beside three
## growing skill tracks reads as a contradiction -- but the week's
## movement is exactly what this screen was asked to show, so it moves.
func test_the_week_card_rewinds_its_needs_bars_to_monday() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"energy": 80.0, "mood": 40.0},
		{"energy": 62.0, "mood": 55.0})
	inst.setup_week_row(s)

	inst.play_week_gain()

	assert_true(absf(inst.energy_bar.value - 80.0) <= 0.01,
		"energy must rewind to Monday's 80 so the week's LOSS is visible as movement")
	assert_true(absf(inst.mood_bar.value - 40.0) <= 0.01,
		"mood must rewind to Monday's 40")


## ...and every gauge must end exactly where setup_week_row put it.
## Stepping past dur_slow is what proves these are real animations and
## not a second assignment.
func test_a_played_week_lands_on_tonights_values() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"akademis": 26.0, "energy": 80.0, "mood": 40.0},
		{"akademis": 52.0, "energy": 62.0, "mood": 55.0})
	inst.setup_week_row(s)
	var tokens := DesignTokens.load_default()

	_run_and_step(func(): inst.play_week_gain(), tokens.dur_slow + 0.2)

	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01,
		"the stat track must end on tonight's 52/65")
	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01,
		"energy must end on tonight's value")
	assert_true(absf(inst.mood_bar.value - 55.0) <= 0.01,
		"mood must end on tonight's value")
	assert_eq(inst.energy_delta_label.text, "-18",
		"replaying the week must land exactly on the number, not a float-eased approximation")


## Superseded by the 2026-09-03 interactivity pass (spec section 4):
## the needs delta LABEL is never visible any more, so play_gain's own
## "if energy_delta_label.visible: count_up_formatted(...)" branch
## (Scripts/SchoolSimulation/DaySummaryStudentRow.gd) is permanently
## dead for this label -- there is no more rewind-to-zero-then-count
## animation to verify. What play_week_gain must still get right is
## that it does NOT touch the label's already-correct text at all,
## since the chevron (not the label) is what the player actually sees,
## and the chevron has no "rewind" concept -- rotation is not a counted
## number.
func test_the_week_cards_needs_delta_text_is_untouched_by_play_gain() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"energy": 80.0, "mood": 40.0},
		{"energy": 62.0, "mood": 55.0})
	inst.setup_week_row(s)

	assert_eq(inst.energy_delta_label.text, "-18",
		"setup_week_row already wrote the final text")
	inst.play_week_gain()
	assert_eq(inst.energy_delta_label.text, "-18",
		"play_week_gain leaves it exactly as setup wrote it -- no rewind, no count")
	assert_eq(inst.mood_delta_label.text, "+15",
		"same for mood")


# ------------------------------------------------ the week reveal's API

## The tweens `action` creates, found the way _run_and_step finds them.
func _new_tweens(action: Callable) -> Array:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var out: Array = []
	for tw in Engine.get_main_loop().get_processed_tweens():
		if not before.has(tw) and is_instance_valid(tw):
			out.append(tw)
	return out


## A card set up for the week, 26 -> 52 akademis against 65 (40% -> 80%)
## and energy 80 -> 62, mood 40 -> 55.
func _week_card() -> DaySummaryStudentRow:
	var inst := _card()
	inst.setup_week_row(_student_with_week(
		{"akademis": 26.0, "energy": 80.0, "mood": 40.0},
		{"akademis": 52.0, "energy": 62.0, "mood": 55.0}))
	return inst


func test_a_stat_row_reports_the_delta_it_shows() -> void:
	var inst := _week_card()
	assert_eq(inst.stat_rows[0].shown_delta(), 26.0, "the week's akademis gain")
	assert_eq(inst.stat_rows[1].shown_delta(), 0.0, "seni did not move")


## Before its turn a card waits on Monday: every number at +0, every
## track and needs bar where the week began, the chevron not yet shown.
func test_a_rewound_week_card_waits_on_monday() -> void:
	var inst := _week_card()
	inst.rewind_week()
	var row: DaySummaryStatRow = inst.stat_rows[0]
	assert_true(absf(row.track.value - 40.0) <= 0.01, "the track is back on Monday's 26/65")
	assert_eq(row.value.text, "+0/65", "the number waits at +0")
	assert_true(row.chevron.visible and row.chevron.modulate.a == 0.0,
		"the chevron is armed but not yet shown")
	assert_true(absf(inst.energy_bar.value - 80.0) <= 0.01, "energy on Monday's 80")
	assert_true(absf(inst.mood_bar.value - 40.0) <= 0.01, "mood on Monday's 40")


func test_a_rows_count_lands_on_the_week_in_its_own_time() -> void:
	var inst := _week_card()
	inst.rewind_week()
	_run_and_step(func(): inst.stat_rows[0].play_count(0.2), 0.3)
	assert_eq(inst.stat_rows[0].value.text, "+26/65", "the count lands on the week's gain")
	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01, "and the track on 52/65")


func test_a_rows_count_is_still_running_before_its_time_is_up() -> void:
	var inst := _week_card()
	inst.rewind_week()
	_run_and_step(func(): inst.stat_rows[0].play_count(0.4), 0.1)
	assert_true(inst.stat_rows[0].value.text != "+26/65",
		"a quarter of the way in, the number has not landed")


## A skip lands everything at once, and whatever it interrupted -- the
## count, the fill, the chevron's pop, the needs bars' travel -- must not
## keep writing half-way values over it.
func test_landing_a_week_card_stops_its_counts() -> void:
	var inst := _week_card()
	inst.rewind_week()
	var tweens := _new_tweens(func():
		inst.play_needs_week()
		inst.stat_rows[0].play_count(0.4))
	assert_true(tweens.size() >= 5, "needs travel x2, fill, count and the chevron pop")
	inst.land_week()
	assert_eq(inst.stat_rows[0].value.text, "+26/65", "final number at once")
	assert_true(absf(inst.stat_rows[0].track.value - 80.0) <= 0.01, "final track at once")
	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01, "final energy at once")
	assert_true(absf(inst.mood_bar.value - 55.0) <= 0.01, "final mood at once")
	assert_true(inst.stat_rows[0].chevron.modulate.a == 1.0, "the chevron shown")
	for tw in tweens:
		if tw.is_valid():
			assert_false(tw.is_running(), "an interrupted count must be stopped")


func test_the_needs_bars_travel_the_week_on_their_own_call() -> void:
	var inst := _week_card()
	inst.rewind_week()
	var tokens := DesignTokens.load_default()
	_run_and_step(func(): inst.play_needs_week(), tokens.dur_slow + 0.2)
	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01, "energy travels to tonight's 62")
	assert_true(absf(inst.mood_bar.value - 55.0) <= 0.01, "mood travels to tonight's 55")


## The pop grows from the number itself: the stat number is right-aligned
## on a wide label, so its pivot sits right of the label's middle.
func test_a_pop_punches_about_the_number() -> void:
	var inst := _week_card()
	inst.land_week()
	var row: DaySummaryStatRow = inst.stat_rows[0]
	var tokens := DesignTokens.load_default()
	var tweens := _new_tweens(func(): row.land_pop(1.2))
	for tw in tweens:
		tw.custom_step(tokens.dur_instant)
	assert_true(row.value.scale.x > 1.1, "mid-pop the number is punched up")
	assert_true(row.value.pivot_offset.x > row.value.size.x * 0.5,
		"about the right-aligned text, not the label's middle")
	for tw in tweens:
		tw.custom_step(tokens.dur_normal + 0.1)
	assert_true(absf(row.value.scale.x - 1.0) <= 0.02, "and it settles back")


## The nightly popup's own path is untouched by the weekly API.
func test_the_week_api_leaves_the_nightly_play_gain_alone() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/DaySummaryStatRow.gd")
	var start := src.find("func play_gain(")
	var body := src.substr(start, src.find("func _play_burst(") - start)
	assert_false(body.contains("_reveal_tweens"), "play_gain keeps its own, untracked tweens")
	assert_contains(src, 'play_sfx(&"tally", pitch)', "the week pop climbs")
	assert_contains(src, 'play_sfx(&"tally")', "the nightly burst still plays the plain tally")


## The daily card's needs bars now animate too (2026-08-31 request:
## ease-out motion on every progress bar in both screens) -- the same
## rewind-then-grow the weekly card already does, just over one day's
## movement instead of a week's. This supersedes the spec's 2026-08-30
## "needs bars do not move on the daily card" note.
func test_the_daily_card_rewinds_its_needs_bars_to_this_morning() -> void:
	var inst := _card()
	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 62.0
	s.mood = 55.0
	var changes := [
		{"stat_key": "energy", "delta": -18.0},
		{"stat_key": "mood", "delta": 15.0},
	]
	inst.setup_row("Marcel", changes, s)
	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01,
		"setup_row alone must leave tonight's value on the bar")
	assert_true(absf(inst.mood_bar.value - 55.0) <= 0.01,
		"setup_row alone must leave tonight's value on the bar")

	inst.play_gain()

	assert_true(absf(inst.energy_bar.value - 80.0) <= 0.01,
		"play_gain must rewind energy to this morning's 62 - (-18) = 80")
	assert_true(absf(inst.mood_bar.value - 40.0) <= 0.01,
		"play_gain must rewind mood to this morning's 55 - 15 = 40")


## ...and land exactly back on tonight's value once the tween finishes --
## stepping past dur_slow is what proves this is a real animation and not
## a second assignment.
func test_a_played_daily_gain_lands_the_needs_bars_on_tonights_values() -> void:
	var inst := _card()
	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 62.0
	s.mood = 55.0
	var changes := [
		{"stat_key": "energy", "delta": -18.0},
		{"stat_key": "mood", "delta": 15.0},
	]
	inst.setup_row("Marcel", changes, s)
	var tokens := DesignTokens.load_default()

	_run_and_step(func(): inst.play_gain(), tokens.dur_slow + 0.2)

	assert_true(absf(inst.energy_bar.value - 62.0) <= 0.01,
		"energy must end exactly on tonight's value")
	assert_true(absf(inst.mood_bar.value - 55.0) <= 0.01,
		"mood must end exactly on tonight's value")


## A day where energy/mood did not move at all (no matching entries in
## changes) must not fabricate a rewind -- the bar should hold still,
## same as before/after being visually indistinguishable from motion of
## zero distance.
func test_a_flat_day_still_lands_the_needs_bars_correctly() -> void:
	var inst := _card()
	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 50.0
	s.mood = 50.0
	inst.setup_row("Marcel", [], s)
	var tokens := DesignTokens.load_default()

	_run_and_step(func(): inst.play_gain(), tokens.dur_slow + 0.2)

	assert_true(absf(inst.energy_bar.value - 50.0) <= 0.01,
		"a flat day must still land on the correct value")
	assert_true(absf(inst.mood_bar.value - 50.0) <= 0.01,
		"a flat day must still land on the correct value")


# ----------------------------------------------- the screen that uses it

## The weekly card must be the SAME scene the daily popup shows, not a
## copy -- one set of mockup measurements, one piece of art.
func test_the_checkup_scene_supplies_the_week_card() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var packed: PackedScene = inst.student_card_scene
	assert_not_null(packed, "ResultCheckup.tscn must assign student_card_scene")
	assert_eq(packed.resource_path, _ROW_SCENE,
		"the weekly card must be the Daily Results card scene itself")
	inst.free()


## The Logs sheet is a scene of its own, instanced on each Logs tap.
func test_the_checkup_scene_supplies_the_logs_sheet() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var packed: PackedScene = inst.logs_popup_scene
	assert_not_null(packed, "ResultCheckup.tscn must assign logs_popup_scene")
	assert_eq(packed.resource_path, _LOGS_SCENE, "Logs opens WeekLogsPopup")
	inst.free()


## The screen with the baked theme, in the tree, freed by the runner.
## Untyped: typed as Control, GDScript rejects the script members.
func _themed_checkup():
	var inst = (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	return inst


## The source block of one node, from its header to the next section.
func _node_block(src: String, node_name: String) -> String:
	var start := src.find('[node name="%s" ' % node_name)
	if start == -1:
		return ""
	var end := src.find("\n[", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


## The screen end to end: a StudentManager whose first default has moved,
## one card per student, each reading its own week.
func test_the_checkup_builds_one_week_card_per_student() -> void:
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.students[0].akademis += 12.0

	inst.initialize_checkup(manager)

	var container: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	assert_eq(container.get_child_count(), manager.students.size(),
		"one card per student in the roster")
	var first = container.get_child(0)
	assert_true(first is DaySummaryStudentRow,
		"the checkup must show the Daily Results card, not a hand-built panel")
	assert_eq(first.name_label.text, manager.students[0].student_name,
		"each card is labelled with the student it was built for")
	assert_eq(first.stat_rows[0].value.text,
		"+12/%d" % int(round(manager.students[0].target_akademis1)),
		"the card must read the WEEK's gain against that student's target")
	assert_false(first.energy_delta_label.visible,
		"the number itself stays hidden")
	var chevron: TextureRect = first.get_node("EnergyBar/DeltaChevron")
	assert_not_null(chevron, "the weekly card still shows its needs delta, as a chevron")


## The old screen hand-built a five-StatBar panel per student, plus an
## avatar loader and a gradient placeholder. None of it may come back.
func test_the_checkup_no_longer_hand_builds_its_stat_bars() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_false(src.contains("func _add_stat_bar"),
		"the hand-built stat bar builder must be gone, not left beside the card")
	assert_false(src.contains("StatBar.new()"),
		"the checkup must not build StatBars any more")
	assert_false(src.contains("_placeholder_avatar"),
		"the card owns avatar fallback now (DaySummaryAvatar)")
	assert_false(src.contains("_create_student_card"),
		"the card is built inline, after add_child -- there is no builder left")
	assert_true(src.contains("setup_week_row("),
		"the checkup must feed the card the week")
	assert_true(src.contains("play_count("),
		"the checkup must replay the week, row by row")


## The weekly report is one reward at a time now (2026-09-14 reveal spec):
## the cards no longer stagger in together, the screen plays the
## WeekReportReveal timeline, each card waiting rewound until its turn.
func test_the_checkup_plays_its_cards_through_the_reveal_timeline() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_false(src.contains("Juice.stagger_in(cards)"),
		"the cards no longer land together")
	assert_true(src.contains("WeekReportReveal.build("), "the screen plays the timeline")
	assert_true(src.contains("rewind_week()"), "each card waits on Monday")
	assert_true(src.contains("play_needs_week()"), "and travels its needs bars as it lands")


## A card's @onready nodes are null until it enters the tree, so setting it
## up before add_child crashes. Both strings must exist: the old version of
## this test searched for a container name the script no longer had, so
## find() returned -1 and the test always passed (CLAUDE.md debt entry,
## fixed 2026-09-14).
func test_the_checkup_sets_each_card_up_only_once_it_is_in_the_tree() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	var add := src.find("cards_list.add_child(card)")
	var setup := src.find("card.setup_week_row(")
	assert_true(add != -1 and setup != -1, "both calls exist")
	assert_true(add < setup,
		"add_child must come before setup_week_row -- @onready nodes are null outside the tree")


## Mockup order, top to bottom: ribbon, cards, summary, buttons.
func test_the_screen_authors_the_mockup_layout_in_order() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var order := []
	for child in screen.get_node("Margin/Layout").get_children():
		order.append(String(child.name))
	assert_eq(order, ["TitleBanner", "CardsScroll", "Summary", "Buttons"],
		"top to bottom as in the mockup")
	for path in ["Backdrop", "Margin/Layout/CardsScroll/CardsList",
			"Margin/Layout/Summary/Lines/CoinRow/CoinIcon",
			"Margin/Layout/Summary/Lines/CoinRow/MoneyLabel",
			"Margin/Layout/Summary/Lines/EventWonLabel",
			"Margin/Layout/Summary/Lines/EventLostLabel",
			"Margin/Layout/Buttons/LogsButton",
			"Margin/Layout/Buttons/NextButton", "Celebration"]:
		assert_not_null(screen.get_node_or_null(path), path + " is authored")
	screen.free()


func test_the_ribbon_is_the_cut_out_weekly_art() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var ribbon := screen.get_node("Margin/Layout/TitleBanner") as TextureRect
	assert_eq(ribbon.texture.resource_path,
		"res://Assets/Images/DaySummary/title_weekly_results.png")
	assert_eq(ribbon.texture.get_image().get_pixel(0, 0).a, 0.0,
		"the ribbon is cut out, not a rectangle of the mockup")
	screen.free()


## The blurred school is an authored node now; the old runtime
## TextureRect swap is gone (and so is its viewport_editability debt).
func test_the_backdrop_is_the_blurred_school_authored_in_the_scene() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var backdrop := screen.get_node("Backdrop") as TextureRect
	assert_eq(backdrop.texture.resource_path, "res://Assets/Images/UI/blur_background.png")
	assert_false(FileAccess.get_file_as_string(_CHECKUP_SCRIPT).contains(".new("),
		"nothing visual is built at runtime")
	screen.free()


## The summary is the card's own "+12/65" text; the buttons are the card's
## own cream art.
func test_the_summary_and_buttons_wear_the_card_styles() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	for n in ["MoneyLabel", "EventWonLabel", "EventLostLabel"]:
		assert_contains(_node_block(src, n), 'theme_type_variation = &"DaySummaryStat"', n)
	for n in ["LogsButton", "NextButton"]:
		assert_contains(_node_block(src, n), 'theme_type_variation = &"ResultButton"', n)


func test_the_buttons_read_as_the_mockup() -> void:
	var inst = _themed_checkup()
	assert_eq(inst.logs_button.text, "Logs")
	assert_eq(inst.next_button.text, "Selanjutnya")


func test_the_summary_reads_the_week() -> void:
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.minigame_history.assign([
		{"day": "Senin", "category": "Akademis", "game_name": "Uji", "won": true},
		{"day": "Selasa", "category": "Olahraga", "game_name": "Lomba", "won": false},
		{"day": "Rabu", "category": "Event", "game_name": "Hujan Deras", "won": true},
		{"day": "Kamis", "category": "SeniBudaya", "game_name": "Batik", "won": true},
	])
	inst.initialize_checkup(manager, 1000)
	assert_eq(inst.money_label.text, "+1.000", "the week's payout, grouped and signed")
	assert_eq(inst.event_won_label.text, "EVENT BERHASIL : 2",
		"two minigames won; the random event is not counted")
	assert_eq(inst.event_lost_label.text, "EVENT GAGAL : 1", "one minigame lost")


func test_a_week_that_earned_nothing_reads_zero() -> void:
	var script = load(_CHECKUP_SCRIPT)
	assert_eq(script.format_earnings(0), "0", "no sign on an empty week")
	assert_eq(script.format_earnings(4200), "+4.200", "a positive week is signed")


func test_logs_opens_one_sheet_with_the_weeks_history() -> void:
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.minigame_history.assign([
		{"day": "Senin", "category": "Akademis", "game_name": "Uji", "won": true},
		{"day": "Rabu", "category": "Event", "game_name": "Hujan Deras", "won": true},
	])
	inst.initialize_checkup(manager)
	inst.logs_button.pressed.emit()
	inst.logs_button.pressed.emit()
	var sheets: Array = []
	for child in inst.get_children():
		if child is WeekLogsPopup:
			sheets.append(child)
	assert_eq(sheets.size(), 1, "Logs opens the sheet, and a second tap never stacks another")
	if sheets.size() == 1:
		assert_eq(sheets[0].row_count(), 2, "every minigame and event of the week")


func test_the_rows_entrance_plays_on_the_first_open_only() -> void:
	var inst = _themed_checkup()
	inst.initialize_checkup(null)
	assert_false(inst._logs_seen, "nothing opened yet")
	inst.open_logs()
	assert_true(inst._logs_seen, "the first open latches")
	assert_contains(FileAccess.get_file_as_string(_CHECKUP_SCRIPT),
		"popup.open(not _logs_seen)", "only the first open animates the rows")


func test_selanjutnya_hands_control_back() -> void:
	var inst = _themed_checkup()
	assert_true(inst.next_button.pressed.is_connected(Callable(inst, "_on_next_pressed")),
		"Selanjutnya is wired")
	assert_true(inst.logs_button.pressed.is_connected(Callable(inst, "open_logs")),
		"and so is Logs")
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_contains(src.substr(src.find("func _on_next_pressed")), "checkup_closed.emit()",
		"Selanjutnya returns to SchoolDay, which goes on to the Lobby")


# ------------------------------------------------------- the reveal

## A screen filled for a week in which the first student gained 12 akademis
## and the minigames went 2 won / 1 lost, with 1.000 coins earned.
func _revealed_checkup():
	var inst = _themed_checkup()
	var manager := StudentManager.new()
	track(manager)
	manager.students[0].akademis += 12.0
	manager.minigame_history.assign([
		{"day": "Senin", "category": "Akademis", "game_name": "Uji", "won": true},
		{"day": "Selasa", "category": "Olahraga", "game_name": "Lomba", "won": false},
		{"day": "Kamis", "category": "SeniBudaya", "game_name": "Batik", "won": true},
	])
	inst.initialize_checkup(manager, 1000)
	return inst


func test_each_pop_sounds_one_step_higher_and_caps() -> void:
	var script = load(_CHECKUP_SCRIPT)
	assert_eq(script.pop_pitch(0, 0.06, 1.6), 1.0, "the first pop is at normal pitch")
	assert_true(absf(script.pop_pitch(3, 0.06, 1.6) - 1.18) <= 0.0001, "three steps up")
	assert_eq(script.pop_pitch(100, 0.06, 1.6), 1.6, "never past the ceiling")


func test_the_reveal_pacing_is_exported() -> void:
	var inst = _themed_checkup()
	var names: Array = []
	for p in inst.get_property_list():
		names.append(p.name)
	for knob in ["card_lead_seconds", "count_seconds", "row_gap_seconds",
			"quiet_row_seconds", "card_gap_seconds", "line_gap_seconds",
			"finale_gap_seconds", "pitch_step", "pitch_max"]:
		assert_true(names.has(knob), "the Reveal group exports " + knob)


## The opening frame is the backdrop alone: ribbon, cards and summary lines
## transparent, each card rewound to Monday, each line reading 0.
func test_the_reveal_opens_on_the_backdrop_alone() -> void:
	var inst = _revealed_checkup()
	inst._prepare_reveal()
	assert_eq(inst.title_banner.modulate.a, 0.0, "the ribbon waits")
	var list: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	for card in list.get_children():
		assert_eq(card.modulate.a, 0.0, "every card waits")
	var first: DaySummaryStudentRow = list.get_child(0)
	assert_eq(first.stat_rows[0].value.text,
		"+0/%d" % int(round(first.stat_rows[0]._target)), "rewound to +0")
	for path in ["Margin/Layout/Summary/Lines/CoinRow",
			"Margin/Layout/Summary/Lines/EventWonLabel",
			"Margin/Layout/Summary/Lines/EventLostLabel"]:
		assert_eq(inst.get_node(path).modulate.a, 0.0, path + " waits")
	assert_eq(inst.money_label.text, "0", "the coins wait at 0")
	assert_eq(inst.event_won_label.text, "EVENT BERHASIL : 0", "won waits at 0")


## A skip's landing: every card and line fully shown on its final value.
func test_landing_the_reveal_shows_every_final_value() -> void:
	var inst = _revealed_checkup()
	inst._prepare_reveal()
	inst._land_all()
	var list: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	for card in list.get_children():
		assert_eq(card.modulate.a, 1.0, "every card shown")
	var first: DaySummaryStudentRow = list.get_child(0)
	assert_eq(first.stat_rows[0].value.text,
		"+12/%d" % int(round(first.stat_rows[0]._target)), "the week's gain")
	assert_eq(inst.title_banner.modulate.a, 1.0, "the ribbon shown")
	assert_eq(inst.money_label.text, "+1.000", "the coins")
	assert_eq(inst.event_won_label.text, "EVENT BERHASIL : 2", "won")
	assert_eq(inst.event_lost_label.text, "EVENT GAGAL : 1", "lost")
	assert_eq(inst.get_node("Margin/Layout/Summary/Lines/CoinRow").modulate.a, 1.0,
		"the coin row shown")


## The screen feeds the timeline every card's rows and the three lines.
func test_the_timeline_reads_every_card_and_line() -> void:
	var inst = _revealed_checkup()
	var steps: Array = inst._build_steps()
	var rows := 0
	var lines := 0
	var pops := 0
	for s in steps:
		if s["kind"] == WeekReportReveal.ROW_COUNT:
			rows += 1
		elif s["kind"] == WeekReportReveal.LINE:
			lines += 1
		elif s["kind"] == WeekReportReveal.ROW_POP:
			pops += 1
	var list: Node = inst.get_node("Margin/Layout/CardsScroll/CardsList")
	assert_eq(rows, list.get_child_count() * 3, "three rows per card")
	assert_eq(lines, 3, "coins, won, lost")
	assert_eq(pops, 1, "only the student who gained pops")


## A tap anywhere skips -- but only while the reveal is playing, so Logs,
## Selanjutnya and the drag-scroll behave normally afterwards. It is
## _input() for StatCheck's reason: the full-screen controls would claim
## the tap first.
func test_a_tap_skips_only_while_the_reveal_plays() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	var input_at := src.find("func _input(")
	assert_true(input_at != -1, "the skip listens in _input()")
	var body := src.substr(input_at, src.find("\nfunc ", input_at + 1) - input_at)
	assert_contains(body, "_revealing", "gated on the reveal playing")
	assert_contains(body, "skip_reveal()", "and it skips")
	var skip_at := src.find("func skip_reveal(")
	var skip := src.substr(skip_at, src.find("\nfunc ", skip_at + 1) - skip_at)
	assert_contains(skip, "_reveal_tween.kill()", "the timeline stops")
	assert_contains(skip, "_land_all()", "everything lands")
	assert_contains(skip, "_finale(true)", "and the finale plays")


## Under the editor the entrance returns before scheduling anything, and a
## skip with nothing playing does nothing -- in particular it never lands
## the cards over the values setup_week_row wrote.
func test_the_editor_never_plays_or_skips_the_reveal() -> void:
	var inst = _revealed_checkup()
	assert_false(inst._revealing, "under the editor the reveal never starts")
	assert_true(inst._reveal_tween == null, "and nothing is ever scheduled")
	inst._prepare_reveal()
	inst.skip_reveal()
	var first: DaySummaryStudentRow = inst.get_node("Margin/Layout/CardsScroll/CardsList").get_child(0)
	assert_eq(first.modulate.a, 0.0,
		"a skip while nothing plays is a no-op: the rewound card stays put")


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()


## The weekly celebration is authored, gated and singular: one confetti
## node in the scene, fired only when a card actually gained, never
## constructed at runtime.
func test_checkup_celebrates_only_a_week_that_gained() -> void:
	var src := _source("res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_true(src.contains("gained_ground()"),
		"the confetti must be gated on a card having gained ground")
	assert_true(src.contains("celebration"),
		"the checkup must reference its authored confetti node")
	assert_true(not src.contains("GPUParticles2D.new()"),
		"the confetti must come from the .tscn, never be built at runtime")


func test_checkup_scene_carries_an_idle_confetti_node() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var fx := inst.get_node_or_null("Celebration") as GPUParticles2D
	assert_true(fx != null, "ResultCheckup must author a Celebration node")
	assert_true(not fx.emitting, "the confetti must start idle")
	assert_true(fx.one_shot, "the confetti must be one_shot")
	inst.free()


## The weekly celebration is the two-cannon paper burst, not the shared
## top-down CelebrationConfetti (2026-09-12 paper confetti spec).
func test_checkup_fires_the_paper_confetti() -> void:
	var src := _source(_CHECKUP_SCRIPT)
	assert_true(src.contains("PaperConfetti.tscn"),
		"the checkup must fire PaperConfetti.tscn")
	assert_true(not src.contains("CelebrationConfetti.tscn"),
		"the checkup must no longer fire CelebrationConfetti.tscn")
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	var fx := inst.get_node_or_null("Celebration")
	assert_true(fx != null and fx.scene_file_path.ends_with("PaperConfetti.tscn"),
		"the Celebration marker must be a PaperConfetti instance")
	if fx != null:
		assert_true(fx.position.x < 0.0 and fx.position.y > 1500.0,
			"the marker must sit at the bottom-left corner")
	inst.free()


const _HISTORY_ROW_SCENE := "res://Scenes/SchoolSimulation/WeekHistoryRow.tscn"


func test_history_row_renders_a_minigame_win() -> void:
	# set_entry writes through @onready fields, which Godot only populates
	# once the node enters the tree.
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	row.set_entry({
		"day": "Senin", "category": "Olahraga",
		"game_name": "Lomba Badminton", "won": true,
		"score": 3, "max_score": 5,
		"results": [{"student_name": "Budi"}, {"student_name": "Doni"}],
	})
	assert_contains(_row_text(row, "Breadcrumb"), "Senin",
		"the day leads the breadcrumb")
	assert_contains(_row_text(row, "Breadcrumb"), "Olahraga",
		"the category follows it")
	assert_eq(_row_text(row, "TitleRow/NameLabel"), "Lomba Badminton",
		"the game name is the row's title")
	assert_contains(_row_text(row, "DetailLabel"), "Budi",
		"participants are named -- this is the new information")
	assert_contains(_row_text(row, "DetailLabel"), "3/5",
		"and the score is carried")
	row.queue_free()


func test_history_row_renders_an_event_with_affected_students() -> void:
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	row.set_entry({
		"day": "Rabu", "category": "Event", "game_name": "Hujan Deras",
		"won": true, "details": "Semua siswa kehilangan 5 energi",
		"affected_students": ["Ani", "Cici"],
	})
	assert_contains(_row_text(row, "DetailLabel"), "Ani",
		"affected students are named")
	assert_contains(_row_text(row, "DetailLabel"), "kehilangan",
		"and the event's own details are shown")
	row.queue_free()


func test_history_row_hides_the_detail_line_when_there_is_nothing_to_say() -> void:
	var row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	row.set_entry({"day": "Kamis", "category": "Akademis",
		"game_name": "Password", "won": false})
	var detail: Label = row.get_node("Body/Lines/DetailLabel")
	assert_false(detail.visible,
		"an entry with no participants and no details collapses to two lines")
	row.queue_free()


func test_history_row_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekHistoryRow.gd")
	for glyph in ["📢", "📊", "📝"]:
		assert_false(src.contains(glyph),
			"emoji are banned as UI iconography; use the SVG icons")


func _row_text(row: Control, path: String) -> String:
	return (row.get_node("Body/Lines/" + path) as Label).text


## Win/loss must be read from WeekHistoryRow's own accessors, not inferred
## from the badge's tint (2026-09-03 Task 9 review, finding 1).
func test_history_row_exposes_event_and_win_state() -> void:
	var event_row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(event_row)
	event_row.set_entry({"day": "Rabu", "category": "Event",
		"game_name": "Hujan Deras", "won": true})
	assert_true(event_row.is_event(),
		"an Event-category entry must report is_event() true")
	event_row.queue_free()

	var won_row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(won_row)
	won_row.set_entry({"day": "Senin", "category": "Akademis",
		"game_name": "Uji", "won": true})
	assert_false(won_row.is_event(),
		"a played minigame must not report is_event()")
	assert_true(won_row.is_win(),
		"a won minigame must report is_win() true")
	won_row.queue_free()

	var lost_row: Control = load(_HISTORY_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(lost_row)
	lost_row.set_entry({"day": "Kamis", "category": "Olahraga",
		"game_name": "Lomba", "won": false})
	assert_false(lost_row.is_event(),
		"a played minigame must not report is_event()")
	assert_false(lost_row.is_win(),
		"a lost minigame must report is_win() false")
	lost_row.queue_free()


func test_scene_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned as UI iconography")


func test_script_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned")


## SchoolDay pays the Wirausaha earnings out -- and empties
## GameState.pending_earnings -- BEFORE it opens this screen, so the week's
## coins must be handed over, not re-read. Before 2026-09-14 the old
## banner's money pill read that emptied dict and always showed 0.
func test_school_day_hands_the_payout_to_the_checkup() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	var payout := src.find("var wirausaha_total := _pay_out_wirausaha()")
	var handoff := src.find("checkup_instance.initialize_checkup(student_manager, wirausaha_total)")
	assert_true(payout != -1 and handoff > payout,
		"the checkup gets the total the payout just made")


## The old banner, its pills, their info popup and the SISWA/RIWAYAT tabs
## are retired with the 2026-09-14 revamp, and WeekRecap stops reading the
## dict SchoolDay empties.
func test_the_old_banner_and_tabs_are_gone() -> void:
	for path in ["res://Scenes/SchoolSimulation/WeekRecapBanner.tscn",
			"res://Scenes/SchoolSimulation/WeekRecapPill.tscn",
			"res://Scenes/UI/WeekRecapPillInfoPopup.tscn",
			"res://Scenes/SchoolSimulation/CoinShower.tscn"]:
		assert_false(FileAccess.file_exists(path), path + " is retired")
	var theme: Theme = load(_THEME_PATH)
	for variation in ["RecapBannerPanel", "RecapPillPanel", "RecapPillValueLabel",
			"WeekTabButton"]:
		assert_false(theme.get_type_list().has(variation), variation + " left the bake")
	assert_false(FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecap.gd").contains("pending_earnings"),
		"WeekRecap no longer reads the dict the payout empties")


## Code review, 2026-09-14: both buttons stayed live through the 0.32 s
## fade-out, so a double tap emitted checkup_closed twice and a tap on Logs
## opened a sheet on a closing screen.
func test_selanjutnya_disables_both_buttons_before_the_fade() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	var body := src.substr(src.find("func _on_next_pressed"))
	var fade := body.find("create_tween()")
	for line in ["next_button.disabled = true", "logs_button.disabled = true"]:
		var at := body.find(line)
		assert_true(at != -1 and at < fade, line + " happens before the fade-out starts")
