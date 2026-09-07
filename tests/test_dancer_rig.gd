@tool
extends McpTestSuite

## The dancer is two layers, not one sprite: a body that swaps pose and
## mirrors, and a head that does neither. The head's offset was solved
## against dance_mockup.png by minimising per-pixel difference, not
## eyeballed -- see docs/superpowers/specs/2026-09-07-sprite-rig-and-
## shop-hub-design.md.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "dancer_rig"


const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/DancerRig.gd"
const SCENE_PATH := "res://Scenes/Minigames/SeniBudaya/DancerRig.tscn"
const MENARI_SCRIPT := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"

## The offset solved against the mockup, on the sprites' 1280 canvas.
const SOLVED_HEAD_OFFSET_PX := Vector2(2.0, 28.0)
const SPRITE_CANVAS := 1280.0


func test_script_is_tool_so_the_composite_previews_in_the_editor() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.begins_with("@tool"),
		"DancerRig must be @tool or the head sits unplaced in the viewport")


func test_scene_has_a_body_and_a_head_layer() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	assert_not_null(packed, "DancerRig.tscn should load")
	var rig := packed.instantiate()
	assert_not_null(rig.get_node_or_null("Body"), "rig needs a Body layer")
	assert_not_null(rig.get_node_or_null("Head"), "rig needs a Head layer")
	rig.free()


func test_head_draws_on_top_of_the_body() -> void:
	# The body sprite carries her back hair; the head carries her face.
	# Wrong order and the face is behind the hair.
	var rig := (load(SCENE_PATH) as PackedScene).instantiate()
	var names: Array[String] = []
	for child in rig.get_children():
		names.append(child.name)
	assert_true(names.find("Head") > names.find("Body"),
		"Head must come after Body so it draws on top, got %s" % [names])
	rig.free()


func test_head_offset_ratio_matches_the_solved_mockup_offset() -> void:
	var rig := (load(SCENE_PATH) as PackedScene).instantiate() as DancerRig
	var expected := SOLVED_HEAD_OFFSET_PX / SPRITE_CANVAS
	assert_true(rig.head_offset_ratio.is_equal_approx(expected),
		"head_offset_ratio should be the solved (2,28)/1280, got %s" % rig.head_offset_ratio)
	rig.free()


func test_side_pose_mirrors_the_body_but_never_the_head() -> void:
	var rig := (load(SCENE_PATH) as PackedScene).instantiate() as DancerRig
	rig.set_pose(DancerRig.Pose.SIDE, true)
	var body := rig.get_node("Body") as TextureRect
	var head := rig.get_node("Head") as TextureRect
	assert_true(body.flip_h, "a flipped pose must mirror the body")
	assert_false(head.flip_h, "the head must never mirror -- her face stays put")
	rig.free()


func test_unflipped_pose_clears_a_previous_mirror() -> void:
	var rig := (load(SCENE_PATH) as PackedScene).instantiate() as DancerRig
	rig.set_pose(DancerRig.Pose.SIDE, true)
	rig.set_pose(DancerRig.Pose.SIDE, false)
	var body := rig.get_node("Body") as TextureRect
	assert_false(body.flip_h, "set_pose must clear a previous mirror, not latch it")
	rig.free()


func test_each_pose_selects_its_own_body_texture() -> void:
	var rig := (load(SCENE_PATH) as PackedScene).instantiate() as DancerRig
	var body := rig.get_node("Body") as TextureRect
	rig.set_pose(DancerRig.Pose.IDLE, false)
	var idle_tex := body.texture
	rig.set_pose(DancerRig.Pose.SIDE, false)
	var side_tex := body.texture
	rig.set_pose(DancerRig.Pose.UP, false)
	var up_tex := body.texture
	assert_ne(idle_tex, side_tex, "IDLE and SIDE must not share art")
	assert_ne(side_tex, up_tex, "SIDE and UP must not share art")
	rig.free()


func test_failed_tints_the_rig_and_clears() -> void:
	var rig := (load(SCENE_PATH) as PackedScene).instantiate() as DancerRig
	rig.set_failed(true)
	assert_ne(rig.modulate, Color.WHITE, "a miss should tint the rig")
	rig.set_failed(false)
	assert_eq(rig.modulate, Color.WHITE, "clearing a miss should restore the tint")
	rig.free()


func test_menari_drives_the_rig_instead_of_swapping_textures() -> void:
	var src := FileAccess.get_file_as_string(MENARI_SCRIPT)
	assert_contains(src, "character_display.set_pose",
		"LombaMenari should drive the rig, not assign textures directly")
	assert_false(src.contains("character_display.texture ="),
		"direct texture assignment should be gone with the rig")


func test_menari_retired_the_six_flat_dancer_textures() -> void:
	var src := FileAccess.get_file_as_string(MENARI_SCRIPT)
	for retired in ["dancer_idle_texture", "dancer_left_texture",
			"dancer_right_texture", "dancer_top_left_texture",
			"dancer_top_right_texture", "dancer_fail_texture"]:
		assert_false(src.contains(retired),
			"%s should have been replaced by the rig's own exports" % retired)


func test_menari_no_longer_builds_a_fallback_label_for_the_dancer() -> void:
	# The label was built at runtime and carried emoji as iconography.
	# The rig always has real art, so it is not needed.
	#
	# background_rect's own _create_flat_texture fallback is a separate
	# concern and deliberately stays -- it is unrelated to the dancer and
	# is still carried in the editability BASELINE.
	var src := FileAccess.get_file_as_string(MENARI_SCRIPT)
	assert_false(src.contains("dancer_label"),
		"the emoji fallback label should be gone")
	for glyph in ["🕺", "💃", "💔"]:
		assert_false(src.contains(glyph),
			"emoji are banned as UI iconography; %s should be gone" % glyph)
