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
