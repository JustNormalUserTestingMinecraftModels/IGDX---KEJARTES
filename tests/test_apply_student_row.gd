@tool
extends McpTestSuite

## ApplyStudentRow on the real DaySummary card (2026-09-12 event-cards spec,
## 1.5). The content is unchanged from the old checkbox row: KEY maps to the
## canonical roster keys, only the boosted stats show, the preview raises
## then restores them, a stat at 100 reads MAKS, and a tired student cannot
## be picked and shows LELAH.

func suite_name() -> String:
	return "apply_student_row"


const _ROW := "res://Scenes/Inventory/ApplyStudentRow.tscn"


func _make() -> ApplyStudentRow:
	var row: ApplyStudentRow = (load(_ROW) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	return row


func _student(energy := 50.0) -> Dictionary:
	return {"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": energy,
		"akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0,
		"target_akademis1": 80.0, "target_akademis2": 80.0, "target_akademis3": 80.0}


func test_key_map_targets_canonical_roster_keys() -> void:
	assert_eq(ApplyStudentRow.KEY["akademis"], "akademis1")
	assert_eq(ApplyStudentRow.KEY["seni_budaya"], "akademis2")
	assert_eq(ApplyStudentRow.KEY["olahraga"], "akademis3")
	assert_eq(ApplyStudentRow.KEY["mood"], "kepribadian1")
	assert_eq(ApplyStudentRow.KEY["energy"], "kepribadian2")


func test_row_is_a_card_button_on_the_day_summary_card() -> void:
	var row := _make()
	assert_true(row is StudentCardButton, "the whole card is the tap target")
	assert_true(row.toggle_mode)
	var card := row.get_node_or_null("Card")
	assert_true(card is DaySummaryStudentRow, "the row hosts the real card")
	if card != null:
		assert_eq(card.scene_file_path, "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	assert_true(row.find_child("Check", true, false) == null, "the checkbox is gone")


func test_setup_shows_only_boosted_stats() -> void:
	var row := _make()
	row.setup(_student(), {"mood": 10, "olahraga": 5})
	var card: DaySummaryStudentRow = row.card
	assert_true(card.mood_bar.visible, "mood is boosted")
	assert_false(card.energy_bar.visible, "energy is not")
	assert_true(card.stat_rows[0].visible)
	assert_eq(card.stat_rows[0].value.text, "40/80", "olahraga fills the top slot")
	assert_false(card.stat_rows[1].visible)
	assert_false(card.stat_rows[2].visible)


func test_preview_raises_then_restores() -> void:
	var row := _make()
	row.setup(_student(), {"mood": 20, "akademis": 8})
	var card: DaySummaryStudentRow = row.card
	assert_eq(int(card.mood_bar.value), 50, "the bar starts at current")
	row.set_preview(true)
	assert_eq(int(card.mood_bar.value), 70, "mood previews the boost")
	assert_eq(card.stat_rows[0].value.text, "+8/80", "akademis previews its gain")
	row.set_preview(false)
	assert_eq(int(card.mood_bar.value), 50, "preview off restores current")
	assert_eq(card.stat_rows[0].value.text, "40/80")


func test_stat_at_100_reads_maks() -> void:
	var s := _student()
	s["akademis1"] = 100.0
	var row := _make()
	row.setup(s, {"akademis": 5})
	row.set_preview(true)
	assert_eq(row.card.stat_rows[0].value.text, "MAKS")


func test_tired_student_cannot_be_selected() -> void:
	var row := _make()
	row.setup(_student(4.0), {"mood": 10})
	assert_true(row.disabled, "tired -> the card refuses the tap")
	assert_false(row.is_selected(), "tired student not selected")
	assert_true(row.lelah_chip.visible, "LELAH shows")
	assert_true(absf(row.modulate.a - 0.55) <= 0.01, "and the card dims")


func test_toggle_emits_argumentless_selection_changed() -> void:
	# ApplyItemScreen connects _refresh_confirm, which takes no arguments.
	var row := _make()
	row.setup(_student(), {"mood": 10})
	var hits := [0]
	row.selection_changed.connect(func() -> void: hits[0] += 1)
	row.button_pressed = true
	assert_eq(hits[0], 1)
	assert_true(row.is_selected())
