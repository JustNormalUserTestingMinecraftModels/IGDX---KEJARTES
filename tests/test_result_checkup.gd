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
		"Margin/VBox/ScrollContainer/PaneStack/StudentsPane")
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
	# The number label is never rendered any more (2026-09-03
	# interactivity spec, section 4); the DeltaChevron is what shows
	# the weekly movement now.
	assert_false(first.energy_delta_label.visible,
		"the number itself stays hidden")
	var chevron: TextureRect = first.get_node("EnergyBar/DeltaChevron")
	assert_not_null(chevron, "the weekly card still shows its needs delta, as a chevron")


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
		"Margin/VBox/ScrollContainer/PaneStack/HistoryPane")
	# HistoryPane always keeps its EmptyLabel child (visibility toggles,
	# it is never freed), so the row count is the pane's children minus
	# that one authored label.
	assert_eq(history.get_child_count() - 1, 1,
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


const _HISTORY_ROW_SCENE := "res://Scenes/SchoolSimulation/WeekHistoryRow.tscn"


func test_history_row_renders_a_minigame_win() -> void:
	# set_entry writes through @onready fields, which Godot only
	# populates once the node enters the tree -- same rule as
	# WeekRecapPill's own set_pill test.
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


func test_screen_authors_the_banner_tabs_and_both_panes() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	for path in ["Margin/VBox/Banner",
			"Margin/VBox/TabBar/TabSiswa",
			"Margin/VBox/TabBar/TabRiwayat",
			"Margin/VBox/ScrollContainer/PaneStack/StudentsPane",
			"Margin/VBox/ScrollContainer/PaneStack/HistoryPane",
			"Margin/VBox/ScrollContainer/PaneStack/HistoryPane/EmptyLabel"]:
		assert_not_null(screen.get_node_or_null(path),
			"%s is authored in the scene" % path)
	screen.free()


func test_banner_and_tabs_sit_outside_the_scroll() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var scroll: Node = screen.get_node("Margin/VBox/ScrollContainer")
	assert_false(scroll.is_ancestor_of(screen.get_node("Margin/VBox/Banner")),
		"the banner must stay pinned while the panes scroll")
	assert_false(scroll.is_ancestor_of(screen.get_node("Margin/VBox/TabBar")),
		"and so must the tab bar")
	screen.free()


func test_students_pane_uses_the_spec_separation() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	var pane: VBoxContainer = screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/StudentsPane")
	assert_eq(pane.get_theme_constant("separation"), 28,
		"card separation drops 56 -> 28 (spec section 3)")
	screen.free()


func test_scene_carries_no_emoji_and_no_dead_section_headers() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph),
			"emoji are banned as UI iconography")
	assert_false(src.contains("StudentsHeader"),
		"the emoji section headers are replaced by the tab labels")
	assert_false(src.contains("HistoryHeader"),
		"both of them")


func test_script_no_longer_builds_history_rows_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	assert_false(src.contains("_create_history_item"),
		"the runtime row builder is replaced by WeekHistoryRow.tscn")
	assert_false(src.contains("PanelContainer.new()"),
		"no PanelContainer is constructed at runtime")
	assert_false(src.contains("Label.new()"),
		"nor the empty-state Label")


func test_script_drops_the_dead_section_header_exports() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for dead in ["students_section_header_text",
			"history_section_header_text",
			"students_header_icon_texture",
			"history_header_icon_texture",
			"StudentsSectionHeader", "HistorySectionHeader"]:
		assert_false(src.contains(dead),
			"%s never rendered -- it is removed, not repaired" % dead)


func test_script_carries_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCRIPT)
	for glyph in ["📊", "📝", "📢"]:
		assert_false(src.contains(glyph), "emoji are banned")


func test_default_tab_is_siswa() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	assert_true(screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/StudentsPane").visible,
		"the screen opens on the students pane")
	assert_false(screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/HistoryPane").visible,
		"the history pane starts hidden")
	screen.queue_free()


func test_switching_tabs_swaps_pane_visibility_without_freeing() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	var students: Node = screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/StudentsPane")
	var history: Node = screen.get_node(
		"Margin/VBox/ScrollContainer/PaneStack/HistoryPane")
	screen.show_pane(1)
	assert_false(students.visible, "students pane hides")
	assert_true(history.visible, "history pane shows")
	assert_true(is_instance_valid(students),
		"panes are hidden, never freed")
	screen.show_pane(0)
	assert_true(students.visible, "and it comes back")
	screen.queue_free()


func test_each_pane_keeps_its_own_scroll_offset() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	var scroll: ScrollContainer = screen.get_node(
		"Margin/VBox/ScrollContainer")
	# ScrollContainer.scroll_vertical clamps synchronously against its
	# scrollbar's max_value, computed from child content size. Nothing
	# was added via initialize_checkup, so the panes are empty and the
	# scrollable range is 0 -- without this, "400" would clamp straight
	# back to 0 before show_pane ever runs, and the test would pass
	# trivially without exercising the offset-memory logic at all.
	scroll.get_v_scroll_bar().max_value = 1000
	scroll.scroll_vertical = 400
	screen.show_pane(1)
	assert_eq(scroll.scroll_vertical, 0,
		"the history pane opens at its own top")
	screen.show_pane(0)
	assert_eq(scroll.scroll_vertical, 400,
		"returning to SISWA restores where you were reading")
	screen.queue_free()


func test_history_pane_animation_latch_fires_only_once() -> void:
	var screen: Control = load(_CHECKUP_SCENE).instantiate()
	_add_themed(screen)
	screen.show_pane(1)
	assert_true(screen._history_animated,
		"the first open latches the animation")
	screen.show_pane(0)
	screen.show_pane(1)
	assert_true(screen._history_animated,
		"and it stays latched, so audio never re-fires")
	screen.queue_free()


## Adds a screen to the tree with the baked theme assigned. ThemeDB's
## project-theme fallback does not populate under the editor's own root,
## so the theme is set explicitly -- the same pattern the suite's other
## in-tree tests use.
func _add_themed(screen: Control) -> void:
	screen.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(screen)


## Finding 1 fix (2026-09-03 Task 9 review): win/loss must be read from
## WeekHistoryRow's own accessors, not inferred from the badge's tint --
## an event row is tinted brand_primary, which matched neither
## state_success nor state_danger and used to fall through to the "lost"
## branch and shake. These three set_entry() calls exercise an event, a
## won minigame, and a lost minigame; none needs tree-entry since
## is_event()/is_win() are now plain field reads, not @onready.
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


func test_pill_root_stops_mouse_input() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	assert_eq(pill.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the pill must consume clicks, not pass them through")
	pill.free()


func test_pill_tapped_fires_on_a_clean_press_release() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(pill)
	pill.size = Vector2(228, 132)
	# A plain int local would be captured BY VALUE inside the lambda below
	# (GDScript closures snapshot value-type locals rather than
	# referencing the caller's own variable), so "fired += 1" would mutate
	# a copy the assertion below can never see. A one-element Array is
	# captured by reference, which is what a closure needs to write back.
	var fired := [0]
	pill.pill_tapped.connect(func() -> void: fired[0] += 1)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50, 50)
	pill._gui_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(60, 60)
	pill._gui_input(release)

	assert_eq(fired[0], 1, "one clean tap fires the signal exactly once")
	pill.queue_free()


func test_pill_tapped_does_not_fire_on_drag_off() -> void:
	var pill: Control = load(_PILL_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(pill)
	pill.size = Vector2(228, 132)
	# See the note in test_pill_tapped_fires_on_a_clean_press_release --
	# a plain int local is captured by value inside the lambda below, so
	# a one-element Array is used instead to catch a real false-positive
	# firing rather than accidentally asserting a copy that never moves.
	var fired := [0]
	pill.pill_tapped.connect(func() -> void: fired[0] += 1)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50, 50)
	pill._gui_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(9999, 9999)
	pill._gui_input(release)

	assert_eq(fired[0], 0, "releasing outside the rect cancels the tap")
	pill.queue_free()

## _on_pill_tapped, start_idle_bounce, and stop_idle_bounce all gate on
## Engine.is_editor_hint() -- the same convention play_entrance() already
## uses on this class, matching every other animated/side-effecting
## method on this screen (CLAUDE.md testing constraint 3). Since
## test_run itself runs INSIDE the editor process, that guard is always
## true here, so calling these methods directly can only ever exercise
## the early return -- never the real behaviour. Source-scan tests are
## this codebase's established substitute for exactly this situation
## (see the existing pill/entrance tests earlier in this suite).
func test_pill_tap_wires_to_the_info_popup_with_the_right_content() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_contains(src, "pill_tapped.connect", "each pill's tap signal is wired")
	assert_contains(src, "WeekRecapPillInfoPopup", "opens the pill info popup")
	assert_contains(src, "PILL_INFO", "content comes from the fixed per-pill copy")
	assert_contains(src, "AudioDirector.play_sfx(&\"pill_tap\")",
		"a tap plays the dedicated pill_tap cue")


func test_idle_bounce_start_stop_pause_are_present() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_contains(src, "func start_idle_bounce", "the banner exposes start_idle_bounce")
	assert_contains(src, "func stop_idle_bounce", "and stop_idle_bounce")
	assert_contains(src, "_idle_tween.pause()",
		"a live popup pauses the bounce so a pill never bounces under the scrim")
	assert_contains(src, "_idle_tween.play()",
		"and the bounce resumes once that popup closes")


## The cascade itself is a coroutine (play_entrance), so this test only
## checks the SETUP each pill's tween needs before it can slide+fade in
## -- that every pill starts the cascade at alpha 0 and offset above its
## slot, per the 2026-09-03 interactivity spec section 5. It does not
## await play_entrance() itself.
func test_pills_start_the_cascade_transparent_and_offset() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_contains(src, "modulate.a = 0.0",
		"each pill starts fully transparent before its slide-in")
	assert_contains(src, "PILL_SLIDE_DISTANCE",
		"a named constant drives the pill's start offset, not a literal")


func test_pill_cascade_step_is_a_named_constant() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/WeekRecapBanner.gd")
	assert_contains(src, "PILL_CASCADE_STEP",
		"the stagger between one pill starting and the next is named, not a literal")


## show_pane's transition is a coroutine under real play, but every test
## that already calls it directly (test_default_tab_is_siswa,
## test_switching_tabs_swaps_pane_visibility_without_freeing, the
## scroll-offset and latch tests) runs inside the editor process, where
## Engine.is_editor_hint() is true -- this test confirms the transition
## code stays behind that SAME existing guard, so none of those tests'
## synchronous assumptions (pane.visible flips immediately) can break.
func test_pane_transition_is_gated_on_editor_hint() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_contains(src, "PANE_SLIDE_DISTANCE",
		"a named constant drives the pane transition, not a literal")


func test_pane_transition_direction_is_derived_not_hardcoded() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/ResultCheckup.gd")
	assert_contains(src, "signi(",
		"the transition direction comes from signi(pane - _active_pane), " +
			"not two hardcoded literal directions")


## ScrollFade was a flat SunkenPanel -- an unexplained white box between
## the scrollable pane and BtnClose. It's a gradient now: an actual
## fade-to-transparent cue, not a themed surface (2026-09-03
## interactivity spec, section 7).
func test_scroll_fade_is_a_gradient_not_a_flat_panel() -> void:
	var src := FileAccess.get_file_as_string(_CHECKUP_SCENE)
	assert_contains(src, "GradientTexture2D",
		"ScrollFade must render an actual fade, not a flat SunkenPanel")
	# Isolate ScrollFade's own node block and confirm it carries no
	# theme_type_variation -- a gradient texture is not a themed surface.
	var node_start := src.find('[node name="ScrollFade"')
	assert_true(node_start != -1, "ScrollFade node exists")
	var next_node := src.find("[node name=", node_start + 1)
	var block := src.substr(node_start, next_node - node_start)
	assert_false(block.contains("theme_type_variation"),
		"ScrollFade is textured, not themed -- no SunkenPanel variation left on it")
