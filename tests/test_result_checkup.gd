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
		"replaying the week must land exactly on the number, not a float-eased approximation")


## The needs delta labels count up (or down) from 0 alongside the bar
## they sit beside, same as the stat rows' "+18/65" -- play_week_gain
## must rewind the label the instant it is called, before any tween
## stepping, or a still screenshot mid-animation would show the wrong
## number relative to the bar's own rewound position.
func test_the_week_cards_needs_deltas_rewind_to_zero_before_counting_up() -> void:
	var inst := _card()
	var s := _student_with_week(
		{"energy": 80.0, "mood": 40.0},
		{"energy": 62.0, "mood": 55.0})
	inst.setup_week_row(s)

	inst.play_week_gain()

	assert_eq(inst.energy_delta_label.text, "+0",
		"the energy delta must rewind to 0 before counting down to -18")
	assert_eq(inst.mood_delta_label.text, "+0",
		"the mood delta must rewind to 0 before counting up to +15")


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


## The screen end to end: a StudentManager whose first default has moved,
## one card per student, each reading its own week.
func test_the_checkup_builds_one_week_card_per_student() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var manager := StudentManager.new()
	track(manager)
	manager.students[0].akademis += 12.0

	inst.initialize_checkup(manager)

	var container := inst.get_node(
		"Margin/VBox/ScrollContainer/MainContent/StudentsContainer")
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
	assert_true(first.energy_delta_label.visible,
		"the weekly card shows its needs deltas")


## The old screen hand-built a five-StatBar panel per student, plus an
## avatar loader and a gradient placeholder. All of it goes -- leaving it
## beside the card would be a second, silently diverging report.
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
	assert_true(src.contains("play_week_gain("),
		"the checkup must replay the week")


## Same rhythm the daily popup uses: cards land first, then their gauges
## start moving, offset card by card. Filling before the cards are
## visible wastes the whole gesture.
func test_the_checkup_fills_its_cards_after_they_land() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_true(src.contains("Juice.stagger_in(cards)"),
		"the cards must still stagger in")
	assert_true(src.find("Juice.stagger_in(cards)") < src.find("play_week_gain("),
		"the fill must be kicked off after stagger_in, not before it")


## A card's @onready nodes -- name_label, energy_bar, stat_rows -- are
## null until it enters the tree, so setting it up before add_child
## crashes on the first assignment. DaySummaryPopup already adds first
## and sets up second; this pins the checkup to the same order.
func test_the_checkup_sets_each_card_up_only_once_it_is_in_the_tree() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_true(
		src.find("students_container.add_child(card)") < src.find("card.setup_week_row("),
		"add_child must come before setup_week_row -- @onready nodes are null outside the tree")


## The history log and the close button are the week's own chrome and
## must survive the card swap.
func test_the_checkup_keeps_its_history_and_its_close_button() -> void:
	var inst := (load(_CHECKUP_SCENE) as PackedScene).instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var manager := StudentManager.new()
	track(manager)
	manager.minigame_history.append({
		"day": "Senin", "category": "Akademis",
		"game_name": "Uji", "won": true,
	})

	inst.initialize_checkup(manager)

	var history := inst.get_node(
		"Margin/VBox/ScrollContainer/MainContent/HistoryList")
	assert_eq(history.get_child_count(), 1,
		"the week's minigame log must still be built")
	assert_not_null(inst.get_node_or_null("Margin/VBox/BtnClose"),
		"the close button must survive the card swap")


## The screen ships with a themed SunkenPanel backdrop and an @export that
## replaces it with art. Assigning the blurred classroom there keeps the
## weekly report in the same setting as the nightly popup, and reuses the
## existing swap in _apply_visual_exports rather than adding a node.
func test_screen_declares_the_blurred_backdrop_texture() -> void:
	var scene := load(_CHECKUP_SCENE) as PackedScene
	assert_not_null(scene, "ResultCheckup.tscn failed to load")
	var inst := scene.instantiate()

	var tex: Texture2D = inst.background_texture
	assert_not_null(tex, "background_texture export is not assigned")
	assert_eq(tex.resource_path, "res://Assets/Images/UI/blur_background.png",
		"background_texture is not blur_background.png")

	inst.free()


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


## The four variations the recap banner and tab bar need. Without these
## the screen would have to reach for theme_override_*, which the project
## forbids (2026-09-03 spec section 8).
func test_theme_carries_the_recap_variations() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_not_null(theme, "the baked theme loads")
	for variation in ["RecapBannerPanel", "RecapPillPanel",
			"RecapPillValueLabel", "WeekTabButton"]:
		assert_true(theme.has_stylebox("panel", variation)
				or theme.has_stylebox("normal", variation)
				or theme.has_font_size("font_size", variation),
			"%s is baked into the theme" % variation)


const _PILL_SCENE := "res://Scenes/SchoolSimulation/WeekRecapPill.tscn"


func test_pill_scene_has_its_three_authored_nodes() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	assert_not_null(pill.get_node_or_null("Icon"), "Icon is authored")
	assert_not_null(pill.get_node_or_null("Value"), "Value is authored")
	assert_not_null(pill.get_node_or_null("Ring"), "Ring emitter is authored")
	pill.free()


func test_pill_uses_the_theme_variation_not_an_override() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/SchoolSimulation/WeekRecapPill.tscn")
	assert_contains(src, "RecapPillPanel", "the pill takes its variation")
	assert_false(src.contains("theme_override_styles"),
		"no stylebox override on the pill")


func test_pill_set_pill_writes_text_and_tint() -> void:
	# set_pill writes through @onready fields, which Godot only populates
	# once the node enters the tree -- the same requirement
	# DaySummaryStudentRow documents for its own setup_row/setup_week_row.
	var pill: Control = load(_PILL_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(pill)
	pill.set_pill(null, "4.200", Color.RED)
	assert_eq((pill.get_node("Value") as Label).text, "4.200",
		"the value label carries the formatted number")
	assert_eq((pill.get_node("Value") as Label).self_modulate, Color.RED,
		"and the caller's tint")
	pill.queue_free()


const _BANNER_SCENE := "res://Scenes/SchoolSimulation/WeekRecapBanner.tscn"


func test_banner_authors_all_four_pills() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	for pill_name in ["PillUang", "PillPoin", "PillMenang", "PillEvent"]:
		assert_not_null(banner.get_node_or_null("Pills/" + pill_name),
			"%s is authored, not built at runtime" % pill_name)
	banner.free()


func test_banner_writes_every_total_into_its_pills() -> void:
	# set_recap writes through the pills' @onready fields (and its own),
	# which Godot only populates once the node enters the tree -- same
	# rule as WeekRecapPill's own set_pill test.
	var banner: Control = load(_BANNER_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(banner)
	banner.set_recap({
		"money_earned": 4200, "net_skill_delta": 37,
		"minigames_won": 3, "minigames_total": 5, "events_count": 2,
	})
	assert_eq(_pill_text(banner, "PillUang"), "4.200", "money is grouped")
	assert_eq(_pill_text(banner, "PillPoin"), "+37", "poin is signed")
	assert_eq(_pill_text(banner, "PillMenang"), "3/5", "won over total")
	assert_eq(_pill_text(banner, "PillEvent"), "2", "a bare event count")
	banner.queue_free()


func test_banner_shows_a_negative_week_as_negative() -> void:
	var banner: Control = load(_BANNER_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(banner)
	banner.set_recap({
		"money_earned": 0, "net_skill_delta": -4,
		"minigames_won": 0, "minigames_total": 2, "events_count": 0,
	})
	assert_eq(_pill_text(banner, "PillPoin"), "-4",
		"a losing week is not hidden")
	banner.queue_free()


func _pill_text(banner: Control, pill_name: String) -> String:
	return (banner.get_node("Pills/" + pill_name).get_node("Value")
		as Label).text
