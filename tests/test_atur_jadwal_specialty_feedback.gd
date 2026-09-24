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
	assert_true(src.contains("ActivityPreview.is_favorit(category, student)"),
		"_on_activity_selected must ask is_favorit() -- the same check as the tile's ribbon")
	assert_true(src.contains("_assigned_note.play_specialty_match()"),
		"a specialty match must play the sticky note's matched-state animation")
	assert_true(src.contains('RewardFeedback.play(&"specialty_match"'),
		"a specialty match must fire the specialty_match cue through RewardFeedback")
	assert_true(src.contains("_assigned_note.play_assign_pop()"),
		"a non-specialty assignment must still play the plain assign pop")

## The picker tile's favourite ribbon replaced ActivityRow's SpecialtyBadge
## (2026-09-24 picker rebuild, D10): shown only on the student's favourite.
func test_activity_tile_shows_the_favorit_ribbon_only_on_the_favourite() -> void:
	var packed := load("res://Scenes/AturJadwal/ActivityTile.tscn") as PackedScene
	var tile := packed.instantiate() as ActivityTile
	Engine.get_main_loop().root.add_child(tile)
	var marcel := {"hobby_category": "Akademik", "name": "Marcel"}
	tile.category = "Akademis"
	tile.refresh(marcel, 7)
	var ribbon := tile.get_node_or_null("FavoritRibbon") as CanvasItem
	assert_true(ribbon != null, "ActivityTile.tscn must have a FavoritRibbon")
	assert_true(ribbon != null and ribbon.visible, "the favourite shows its ribbon")
	tile.category = "Olahraga"
	tile.refresh(marcel, 7)
	assert_true(ribbon != null and not ribbon.visible, "any other tile hides it")
	tile.free()


## D15: a plain assignment bursts through RewardFeedback in the one shared
## colour; only the favourite keeps the gold star burst.
func test_plain_assignments_fire_the_shared_assign_burst() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
	assert_true(src.contains('RewardFeedback.play(&"activity_assigned", _assigned_note)'),
		"a plain assignment must fire activity_assigned from the note")
	assert_true(RewardFeedback.RECIPES.has(&"activity_assigned"),
		"RewardFeedback must know the activity_assigned moment")
	var recipe: Dictionary = RewardFeedback.RECIPES[&"activity_assigned"]
	assert_false(recipe.get("no_particles", false), "the plain assign must burst")
	assert_true(recipe.get("centred", false), "and burst from the note's centre")
	assert_false(recipe.has("particle"),
		"it uses the shared Pop burst -- one colour for every category")
