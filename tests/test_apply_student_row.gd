@tool
extends McpTestSuite

## ApplyStudentRow: KEY maps to canonical roster keys, bars show only for
## boosted stats, preview raises then restores a bar, a tired student's
## checkbox is disabled.

func suite_name() -> String:
	return "apply_student_row"

const _ROW := "res://Scenes/Inventory/ApplyStudentRow.tscn"

func _make() -> Node:
	return (load(_ROW) as PackedScene).instantiate()

func _student(energy := 50.0) -> Dictionary:
	return {"id": 1, "name": "A", "kepribadian1": 50.0, "kepribadian2": energy,
		"akademis1": 40.0, "akademis2": 40.0, "akademis3": 40.0}

func test_key_map_targets_canonical_roster_keys() -> void:
	assert_eq(ApplyStudentRow.KEY["akademis"], "akademis1")
	assert_eq(ApplyStudentRow.KEY["seni_budaya"], "akademis2")
	assert_eq(ApplyStudentRow.KEY["olahraga"], "akademis3")
	assert_eq(ApplyStudentRow.KEY["mood"], "kepribadian1")
	assert_eq(ApplyStudentRow.KEY["energy"], "kepribadian2")

func test_setup_shows_only_boosted_bars() -> void:
	var row := _make()
	Engine.get_main_loop().root.add_child(row)
	row.setup(_student(), {"mood": 10})
	assert_true(row.find_child("BarRowMood", true, false).visible, "mood bar shown")
	assert_false(row.find_child("BarRowAkademis", true, false).visible, "akademis bar hidden")
	row.free()

func test_preview_raises_then_restores_bar_value() -> void:
	var row := _make()
	Engine.get_main_loop().root.add_child(row)
	row.setup(_student(), {"mood": 20})
	var bar: Range = row.find_child("BarRowMood", true, false).get_node("Bar")
	assert_eq(int(bar.value), 50, "bar starts at current")
	row.set_preview(true)
	assert_eq(int(bar.value), 70, "preview adds the boost")
	row.set_preview(false)
	assert_eq(int(bar.value), 50, "preview off restores current")
	row.free()

func test_tired_student_cannot_be_selected() -> void:
	var row := _make()
	Engine.get_main_loop().root.add_child(row)
	row.setup(_student(4.0), {"mood": 10})
	assert_true(row.find_child("Check", true, false).disabled, "tired -> checkbox disabled")
	assert_false(row.is_selected(), "tired student not selected")
	row.free()
