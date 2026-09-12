@tool
extends McpTestSuite

## The DaySummary card's "current stats" mode, which the event picker and
## the item screen read it in (2026-09-12 event-cards spec, sections 1.1 and
## 1.2). DaySummary and ResultCheckup keep their own setup_row /
## setup_week_row paths; nothing here may change those.

const _STAT_ROW := "res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn"
const _CARD := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"
const _STAT_ROW_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryStatRow.gd"


func suite_name() -> String:
	return "card_standing_mode"


func _row() -> DaySummaryStatRow:
	var row: DaySummaryStatRow = (load(_STAT_ROW) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	return row


func test_format_standing_has_no_sign() -> void:
	assert_eq(DaySummaryStatRow.format_standing(42.0, 60.0), "42/60")
	assert_eq(DaySummaryStatRow.format_standing(41.6, 59.5), "42/60",
		"both ends round, like format_value's")


func test_set_standing_shows_current_over_target() -> void:
	var row := _row()
	row.set_standing("seni_budaya", 60.0, 30.0)
	assert_eq(row.value.text, "30/60")
	assert_false(row.chevron.visible, "nothing moved, so no chevron")
	assert_eq(row.track.value, 50.0, "half the target is half the track")
	assert_eq(row.track.theme_type_variation, &"DaySummaryStatTrackSeniBudaya")


func test_show_preview_layers_the_gain() -> void:
	var row := _row()
	row.set_standing("akademis", 60.0, 30.0)
	row.show_preview(15.0)
	assert_eq(row.value.text, "+15/60", "the card's own delta format")
	assert_true(row.chevron.visible, "a gain shows the chevron")
	assert_eq(row.track.value, 75.0, "the track moves to (30 + 15) / 60")


func test_zero_preview_restores_the_standing_view() -> void:
	var row := _row()
	row.set_standing("akademis", 60.0, 30.0)
	row.show_preview(15.0)
	row.show_preview(0.0)
	assert_eq(row.value.text, "30/60")
	assert_false(row.chevron.visible)
	assert_eq(row.track.value, 50.0)


func test_capped_preview_reads_maks() -> void:
	var row := _row()
	row.set_standing("olahraga", 60.0, 100.0)
	row.show_preview(0.0, true)
	assert_eq(row.value.text, "MAKS")
	assert_false(row.chevron.visible, "a full stat has nothing to gain")


func test_preview_path_stays_quiet() -> void:
	# The star burst and the tally cue are the day summary's reward. A
	# preview the player toggles on and off must not fire them.
	var src := FileAccess.get_file_as_string(_STAT_ROW_SCRIPT)
	var start := src.find("func show_preview")
	assert_true(start != -1, "show_preview must exist")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	assert_false(body.contains("_play_burst"), "no star burst on a preview")
	assert_false(body.contains("play_sfx"), "no tally cue on a preview")


# ── The card: DaySummaryStudentRow ───────────────────────────────────────────

func _student() -> StudentData:
	var s := StudentData.new()
	s.student_name = "Budi"
	s.akademis = 30.0
	s.seni_budaya = 45.0
	s.olahraga = 60.0
	s.target_akademis1 = 60.0
	s.target_akademis2 = 90.0
	s.target_akademis3 = 60.0
	s.energy = 40.0
	s.mood = 70.0
	return s


func _card() -> DaySummaryStudentRow:
	var card: DaySummaryStudentRow = (load(_CARD) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


func test_current_row_shows_standing_values() -> void:
	var card := _card()
	card.setup_current_row(_student())
	assert_eq(card.name_label.text, "Budi")
	assert_eq(card.stat_rows[0].value.text, "30/60")
	assert_eq(card.stat_rows[1].value.text, "45/90",
		"row 2 is seni, measured against target_akademis2")
	assert_eq(card.energy_bar.value, 40.0)
	assert_eq(card.mood_bar.value, 70.0)
	assert_false(card.energy_delta_chevron.visible, "nothing moved yet")
	assert_true(card.energy_bar.icon.texture != null,
		"the real card's needs bars carry their icon")


func test_preview_stat_targets_the_right_row() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.preview_stat("olahraga", 15.0)
	assert_eq(card.stat_rows[2].value.text, "+15/60")
	assert_eq(card.stat_rows[0].value.text, "30/60", "other rows are untouched")


func test_preview_need_moves_the_bar_and_points_the_chevron() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.preview_need("energy", -15.0)
	assert_eq(card.energy_bar.value, 25.0)
	assert_true(card.energy_delta_chevron.visible)
	assert_eq(card.energy_delta_chevron.rotation_degrees, 180.0, "a loss points down")
	assert_false(card.energy_delta_label.visible, "the number stays hidden")
	card.preview_need("energy", 0.0)
	assert_eq(card.energy_bar.value, 40.0, "zero restores the bar")
	assert_false(card.energy_delta_chevron.visible)


func test_show_only_moves_a_single_skill_to_the_top_slot() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.show_only(["olahraga", "mood"])
	var top: DaySummaryStatRow = card.stat_rows[0]
	assert_true(top.visible)
	assert_eq(top.value.text, "60/60", "olahraga fills the top slot")
	assert_eq(top.track.theme_type_variation, &"DaySummaryStatTrackOlahraga")
	assert_false(card.stat_rows[1].visible)
	assert_false(card.stat_rows[2].visible)
	assert_false(card.energy_bar.visible, "energy was not listed")
	assert_true(card.mood_bar.visible)
	card.preview_stat("olahraga", 5.0)
	assert_eq(top.value.text, "+5/60", "previews follow the reassigned row")


func test_show_only_empty_shows_everything() -> void:
	var card := _card()
	card.setup_current_row(_student())
	card.show_only(["akademis"])
	card.show_only([])
	for row in card.stat_rows:
		assert_true(row.visible)
	assert_true(card.energy_bar.visible and card.mood_bar.visible)
	assert_eq(card.stat_rows[1].value.text, "45/90", "seni is back in its own row")
