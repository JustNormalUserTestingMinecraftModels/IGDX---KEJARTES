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


func test_announcement_no_longer_uses_emoji() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventAnnouncement.tscn")
	assert_false(src.contains('"📢"'), "Emoji glyph must be gone from announcement scene")
	assert_true(src.contains("icon_event_announce.png"),
		"Announcement should reference the polished icon PNG")


func test_warning_no_longer_uses_emoji() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventWarning.tscn")
	assert_false(src.contains('"⚠️"'), "Warning emoji glyph must be gone")
	assert_true(src.contains("eventwarning_icon.png"),
		"The warning carries the megaphone art (2026-09-12 slide warning)")


func test_announce_scene_wires_burst() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventAnnouncement.tscn")
	assert_true(src.contains("AnnouncementBurst.tscn"),
		"EventAnnouncement should instance the burst")


func test_announce_script_plays_sfx() -> void:
	var src := _read("res://Scripts/SchoolSimulation/EventAnnouncement.gd")
	assert_true(src.contains('play_sfx(&"event_announce")'),
		"Announcement should play the new SFX cue")


func test_announce_script_has_no_emoji_fallback() -> void:
	var src := _read("res://Scripts/SchoolSimulation/EventAnnouncement.gd")
	assert_false(src.contains("announcement_symbol_text"),
		"The emoji-fallback export must be removed, not just unused")
	assert_false(src.contains("📢"),
		"No emoji glyph should remain anywhere in the script")


func test_school_day_event_titles_free_of_emoji() -> void:
	var src := _read("res://Scripts/SchoolSimulation/SchoolDay.gd")
	for glyph in ["📚 KEGIATAN", "⚽ KEGIATAN", "🎨 KEGIATAN",
			"🍱 Kejutan", "🌧 Hujan"]:
		assert_false(src.contains(glyph),
			"SchoolDay's event-popup titles should not carry emoji: " + glyph)
