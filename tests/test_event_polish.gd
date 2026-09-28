@tool
extends McpTestSuite

## 2026-09-08 mobile-readability and asset-polish pass over the mid-
## simulation event popups: EventStudentSelectDialog (the calmed background
## and bigger body text) and the event warning (real art replacing emoji, per
## CLAUDE.md's no-emoji rule). EventAnnouncement was folded into the sliding
## EventWarning on 2026-09-12.

func suite_name() -> String:
	return "event_polish"

func _read(p: String) -> String:
	return FileAccess.get_file_as_string(p)


func test_dialog_uses_calmed_background() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
	assert_true(src.contains("bg_event_dialog.png"),
		"Dialog should reference the new paper-tint background")


const DIALOG_SCENE := "res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn"
const DIALOG_SCRIPT := "res://Scripts/SchoolSimulation/EventStudentSelectDialog.gd"


## The scene has always set background_texture to that photo, but the swap
## looked for a `Background` node while the scrim is `BackgroundDim`, so the
## photo never showed (confirmed live 2026-09-15). The photo now has its own
## authored node, full-screen and behind the card.
func test_dialog_background_photo_has_an_authored_node() -> void:
	var inst := (load(DIALOG_SCENE) as PackedScene).instantiate()
	var bg := inst.get_node_or_null("Background") as TextureRect
	assert_true(bg != null, "the photo needs an authored Background TextureRect")
	if bg != null:
		assert_eq(bg.stretch_mode, TextureRect.STRETCH_SCALE,
			"the photo must stretch over the screen")
		assert_eq(bg.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
			"the photo must not take its minimum size from the texture")
		assert_eq(Vector4(bg.anchor_left, bg.anchor_top, bg.anchor_right, bg.anchor_bottom),
			Vector4(0, 0, 1, 1), "the photo must be anchored to the full screen")
		assert_gt(inst.get_node("Margin").get_index(), bg.get_index(),
			"the photo must sit behind the dialog card")
	inst.free()


## The same bug stated generally: every node path the script names must exist
## in its scene, because a lookup by a name the scene lacks fails silently.
func test_dialog_script_names_only_nodes_its_scene_has() -> void:
	var inst := (load(DIALOG_SCENE) as PackedScene).instantiate()
	var re := RegEx.new()
	re.compile("(?:\\$|get_node(?:_or_null)?\\(\")([A-Za-z0-9_/]+)")
	var missing: Array[String] = []
	for m in re.search_all(_read(DIALOG_SCRIPT)):
		if inst.get_node_or_null(m.get_string(1)) == null:
			missing.append(m.get_string(1))
	inst.free()
	assert_true(missing.is_empty(),
		"EventStudentSelectDialog.gd names nodes its scene lacks: " + ", ".join(missing))


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


func test_warning_no_longer_uses_emoji() -> void:
	var src := _read("res://Scenes/SchoolSimulation/EventWarning.tscn")
	assert_false(src.contains('"⚠️"'), "Warning emoji glyph must be gone")
	assert_true(src.contains("eventwarning_icon.png"),
		"The warning carries the megaphone art (2026-09-12 slide warning)")


func test_school_day_event_titles_free_of_emoji() -> void:
	var src := _read("res://Scripts/SchoolSimulation/SchoolDay.gd")
	for glyph in ["📚 KEGIATAN", "⚽ KEGIATAN", "🎨 KEGIATAN",
			"🍱 Kejutan", "🌧 Hujan"]:
		assert_false(src.contains(glyph),
			"SchoolDay's event-popup titles should not carry emoji: " + glyph)
