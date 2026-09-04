@tool
extends McpTestSuite

## AturJadwal specialty feedback: is_specialty() truth table, the SFX cue,
## the particle scene, the sticky-note matched state, the picker badge, and
## the atur_jadwal wiring. Source-scan + light-instantiate, matching this
## project's established AturJadwal test style.

func suite_name() -> String:
	return "atur_jadwal_specialty_feedback"

func test_is_specialty_truth_table() -> void:
	var marcel := {"hobby_category": "Akademis"}
	assert_true(ActivityPreview.is_specialty("Akademis", marcel))
	assert_false(ActivityPreview.is_specialty("Olahraga", marcel))
	var ui_spelling := {"hobby_category": "Akademik"}
	assert_true(ActivityPreview.is_specialty("Akademis", ui_spelling),
		"the UI spelling 'Akademik' must normalize to 'Akademis'")
	assert_false(ActivityPreview.is_specialty("Akademis", {}),
		"a student with no hobby_category has no specialty")

func test_specialty_match_cue_registered() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Audio/AudioDirector.gd")
	assert_true(src.contains("sfx_specialty_match"), "AudioDirector needs the sfx_specialty_match export")
	assert_true(src.contains("&\"specialty_match\": return sfx_specialty_match"),
		"the &\"specialty_match\" cue must map to sfx_specialty_match")
