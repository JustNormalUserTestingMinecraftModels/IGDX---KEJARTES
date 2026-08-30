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
