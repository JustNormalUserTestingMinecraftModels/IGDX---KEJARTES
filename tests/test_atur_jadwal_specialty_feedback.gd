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

func test_specialty_burst_scene_shape() -> void:
	var packed := load("res://Scenes/AturJadwal/SpecialtyMatchBurst.tscn") as PackedScene
	assert_true(packed != null, "SpecialtyMatchBurst.tscn must exist")
	var inst := packed.instantiate()
	assert_true(inst is CPUParticles2D, "root must be CPUParticles2D")
	assert_true(inst.one_shot, "the burst must be one_shot")
	assert_true(inst.has_method("play"), "the burst must expose play()")
	inst.free()

func test_sticky_note_has_matched_state_api() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/DayStickyNote.gd")
	assert_true(src.contains("func play_specialty_match"), "DayStickyNote needs play_specialty_match()")
	assert_true(src.contains("play_assign_pop()"), "play_specialty_match must reuse play_assign_pop()")
	assert_true(src.contains("specialty_match_burst_scene"), "the burst scene must be an @export")
	assert_true(src.contains("_match_glow") and src.contains("_specialty_star"),
		"both matched-state child nodes must be referenced")

func test_sticky_note_scene_has_matched_nodes() -> void:
	var packed := load("res://Scenes/AturJadwal/DayStickyNote.tscn") as PackedScene
	var inst := packed.instantiate()
	assert_true(inst.get_node_or_null("Paper/MatchGlow") != null, "MatchGlow node must exist")
	assert_true(inst.get_node_or_null("Paper/SpecialtyStar") != null, "SpecialtyStar node must exist")
	inst.free()

func test_activity_selected_plays_specialty_feedback_conditionally() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
	assert_true(src.contains("func _on_activity_selected"), "_on_activity_selected must exist")
	assert_true(src.contains("ActivityPreview.is_specialty(category, student)"),
		"_on_activity_selected must check is_specialty() against the assigned student")
	assert_true(src.contains("_assigned_note.play_specialty_match()"),
		"a specialty match must play the sticky note's matched-state animation")
	assert_true(src.contains("AudioDirector.play_sfx(&\"specialty_match\")"),
		"a specialty match must play the specialty_match cue")
	assert_true(src.contains("_assigned_note.play_assign_pop()"),
		"a non-specialty assignment must still play the plain assign pop")

func test_activity_row_toggles_specialty_badge() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/ActivityRow.gd")
	assert_true(src.contains("Container/SpecialtyBadge"), "refresh() must look up the SpecialtyBadge node")
	assert_true(src.contains("badge.visible = ActivityPreview.is_specialty(category, student)"),
		"the badge's visibility must be driven by is_specialty()")
	var packed := load("res://Scenes/AturJadwal/ActivityRow.tscn") as PackedScene
	var inst := packed.instantiate()
	assert_true(inst.get_node_or_null("Container/SpecialtyBadge") != null,
		"ActivityRow.tscn must have a Container/SpecialtyBadge TextureRect")
	inst.free()
