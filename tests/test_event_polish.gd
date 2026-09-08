@tool
extends McpTestSuite

## 2026-09-08 mobile-readability and asset-polish pass over the mid-
## simulation event popups: EventStudentSelectDialog (the calmed
## background and bigger body text) and EventAnnouncement/EventWarning
## (real PNG icons replacing emoji, per CLAUDE.md's no-emoji rule).

func suite_name() -> String:
	return "event_polish"

func _read(p: String) -> String:
	return FileAccess.get_file_as_string(p)


func test_dialog_uses_calmed_background() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
	assert_true(src.contains("bg_event_dialog.png"),
		"Dialog should reference the new paper-tint background")


func test_dialog_header_uses_event_variation() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
	assert_true(src.contains('theme_type_variation = &"EventDialogHeaderLabel"'),
		"Title should use the new EventDialogHeaderLabel variation")


func test_dialog_desc_and_benefit_cost_use_event_body() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
	var occurrences := src.count('theme_type_variation = &"EventBodyLabel"')
	assert_eq(occurrences, 3,
		"DescLabel, BenefitRow/Text and CostRow/Text should all use EventBodyLabel")


func test_dialog_instructions_use_h2() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
	var header_start := src.find('[node name="StudentsHeaderLabel"')
	assert_true(header_start != -1, "StudentsHeaderLabel must exist")
	var header_end := src.find("[node name=", header_start + 1)
	var header_block := src.substr(header_start, header_end - header_start)
	assert_true(header_block.contains('theme_type_variation = &"H2Label"'),
		"StudentsHeaderLabel must upgrade from CaptionLabel to H2Label")
