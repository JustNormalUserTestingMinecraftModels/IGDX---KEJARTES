@tool
extends McpTestSuite

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

	assert_true(inst.energy_delta_label.visible,
		"the week card must show the energy delta")
	assert_true(inst.mood_delta_label.visible,
		"the week card must show the mood delta")
	assert_eq(inst.energy_delta_label.text, "-18",
		"energy fell 80 -> 62 across the week")
	assert_eq(inst.mood_delta_label.text, "+15",
		"mood rose 70 -> 85 across the week")
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
		"replaying the week must not disturb the number")


## The daily card's own replay must stay exactly as it was: three tracks
## and no needs movement. This is the guard on the spec's motion note.
func test_the_daily_replay_still_leaves_the_needs_bars_alone() -> void:
	var inst := _card()
	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 44.0
	s.mood = 71.0
	inst.setup_row("Marcel", [], s)

	inst.play_gain()

	assert_true(absf(inst.energy_bar.value - 44.0) <= 0.01,
		"play_gain must not move the energy bar")
	assert_true(absf(inst.mood_bar.value - 71.0) <= 0.01,
		"play_gain must not move the mood bar")
