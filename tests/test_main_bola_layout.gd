@tool
extends McpTestSuiteCompat

## MainBola shipped as an invisible scene: every node had no position and no
## size, and _setup_layout() placed all of them at runtime from magic
## fractions buried in the function body. Its five textures came from
## hardcoded load() paths, so an artist could not swap them.
##
## project.godot sets stretch/aspect="expand", so viewport height really does
## vary and the fractional layout has to stay. The rule this suite enforces is
## Pattern C: the fractions are documented @exports, the script is @tool, and
## the art is @export'd Texture2D.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "main_bola_layout"


const SCRIPT_PATH := "res://Scripts/Minigames/Olahraga/MainBola.gd"
const SCENE_PATH := "res://Scenes/Minigames/Olahraga/MainBola.tscn"

## Every art slot the script used to fetch with a hardcoded load().
## The goalkeeper collapsed from four textures to two on 2026-09-07:
## one idle, one dive, with direction carried by flip_h instead.
const TEXTURE_EXPORTS: Array[String] = [
	"goalie_idle_texture", "goalie_jump_texture",
	"ball_texture", "field_background_texture",
]

## Textures the two-state goalie retired. Named so a revert is loud.
const RETIRED_TEXTURE_EXPORTS: Array[String] = [
	"goalie_left_texture", "goalie_right_texture", "goalie_fail_texture",
]

## Every magic fraction _setup_layout() used to hardcode.
const LAYOUT_EXPORTS: Array[String] = [
	"goal_top_frac", "goal_height_frac", "goal_width_frac",
	"post_width_frac", "crossbar_height_frac",
	"goalie_width_frac", "goalie_height_frac",
	"ball_start_height_frac", "ball_radius_frac", "target_size_frac",
]


func test_script_is_tool_so_the_viewport_previews_the_layout() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(src.begins_with("@tool"),
		"MainBola.gd must be @tool or the editor shows an empty scene")


func test_no_art_is_fetched_by_hardcoded_path() -> void:
	# A leading space distinguishes a dynamic "= load(...)" call (the thing
	# being removed) from "= preload(...)" (the correct way to default an
	# @export texture), since "preload(" itself contains the substring
	# "load(" with no space before it.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains(' load("res://Assets/Images/Textures/'),
		"MainBola.gd still load()s art by path at runtime -- use @export Texture2D")


func test_every_texture_slot_is_an_export() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for texture_name in TEXTURE_EXPORTS:
		assert_contains(src, "@export var %s: Texture2D" % texture_name,
			"missing texture export: %s" % texture_name)


func test_every_layout_fraction_is_a_documented_export() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var lines := src.split("\n")
	for fraction_name in LAYOUT_EXPORTS:
		var found := -1
		for i in range(lines.size()):
			if lines[i].contains("var %s" % fraction_name) and lines[i].strip_edges().begins_with("@export"):
				found = i
				break
		assert_gt(found, 0, "missing layout export: %s" % fraction_name)
		assert_true(lines[found - 1].strip_edges().begins_with("##"),
			"%s has no ## doc line -- it would be an unlabelled Inspector slider" % fraction_name)


func test_layout_reruns_when_a_knob_changes() -> void:
	# Without the setter, dragging a slider in the Inspector does nothing
	# until the game runs -- which defeats the point of previewing.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for fraction_name in LAYOUT_EXPORTS:
		var at := src.find("var %s" % fraction_name)
		assert_gt(at, 0, "missing export: %s" % fraction_name)
		var tail := src.substr(at, 320)
		assert_contains(tail, "_setup_layout()",
			"%s does not re-run the layout when set" % fraction_name)


func test_scene_positions_every_visual_node() -> void:
	# The scene, not the script, is where a human reads the layout. Every
	# node the script places must carry a position in the scene file too, so
	# opening it shows the real thing.
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	for path in ["FieldBG", "GoalBack", "GoalNet", "Crossbar",
			"PostLeft", "PostRight", "Goalie", "Ball", "TargetBox"]:
		var node := root.get_node_or_null(path)
		assert_not_null(node, "missing node: %s" % path)
	# Ball and Goalie are the two the player watches; if these are at the
	# origin the scene is still the old empty skeleton.
	assert_ne((root.get_node("Ball") as Node2D).position, Vector2.ZERO,
		"Ball sits at the origin -- the scene was never given a real position")
	assert_ne((root.get_node("Goalie") as Node2D).position, Vector2.ZERO,
		"Goalie sits at the origin -- the scene was never given a real position")


func test_goalie_has_exactly_two_pose_textures() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "kiper_idle.png",
		"goalie_idle_texture should preload the new alpha PNG")
	assert_contains(src, "kiper_jump.png",
		"goalie_jump_texture should preload the new alpha PNG")


func test_retired_goalie_textures_are_gone() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in RETIRED_TEXTURE_EXPORTS:
		assert_false(src.contains(retired),
			"%s should have been removed with the two-state goalie" % retired)


func test_dive_direction_uses_flip_h_not_a_texture_swap() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "goalie_gfx.flip_h",
		"dive direction should mirror the one jump sprite, not swap textures")
	assert_contains(src, "jump_faces_right",
		"which way the jump art faces must stay an Inspector toggle")


## The scene must not NULL an art export.
##
## Found by screenshot on 2026-09-07, not by any test here: MainBola.tscn
## carried `goalie_jump_texture = null`, written when the editor
## re-serialised the scene against a stale copy of the script. The export
## checks above all passed -- they read the SCRIPT -- while the running
## game would have shown an invisible keeper the moment he dived.
func test_scene_does_not_null_any_art_export() -> void:
	var scene_text := FileAccess.get_file_as_string(SCENE_PATH)
	for slot in TEXTURE_EXPORTS:
		assert_false(scene_text.contains("%s = null" % slot),
			"%s is nulled in the scene, which overrides the script's preload "
			% slot + "and renders nothing")


func test_goalie_breathing_is_tunable_not_hardcoded() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for knob in ["breath_rate", "breath_scale_amount"]:
		assert_contains(src, "@export var %s" % knob,
			"breathing amplitude and rate must be Inspector knobs")


func test_goalie_breathing_pivots_at_the_feet() -> void:
	# A standing character scaled about its middle lifts off the goal
	# line. The pivot has to sit at bottom-centre, and it has to be
	# rewritten in _apply_layout because that function rewrites size.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "goalie_gfx.pivot_offset",
		"breathing needs an explicit pivot")
	assert_contains(src, "goalie_gfx.size.y)",
		"the pivot's y should be the full height, i.e. the feet")


func test_goalie_stands_on_the_goal_line_not_below_it() -> void:
	# kiper_idle.png draws the keeper's feet flush with the bottom of the
	# image (under 1% transparent padding), so the sprite has to be offset
	# by its FULL height above the node's origin for the feet to land on
	# the spot the Goalie node is dragged to. This was a hardcoded 0.78
	# until 2026-09-08, which left 22% of the sprite hanging below the
	# line and the keeper reading as floating.
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "goalie_feet_frac",
		"where the keeper's feet sit must be an Inspector knob, not a literal")
	assert_contains(src, "-g_height * goalie_feet_frac",
		"the sprite offset must read the knob rather than a hardcoded fraction")

	assert_contains(src, "var goalie_feet_frac: float = 1.0",
		"the default must ground the keeper: a full sprite height above the line")


func test_goalie_breathing_pauses_while_a_shot_resolves() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "func _breathe_goalie",
		"breathing should live in its own function, not inline in _process")
	assert_contains(src, "is_resolving",
		"breathing must yield to the dive animation")


## Knobs the draggable goalie retired on 2026-09-10. Named so a revert is loud.
const RETIRED_LAYOUT_EXPORTS: Array[String] = ["goalie_depth_frac"]

## The goal mouth in design space, from the default fractions: top
## 0.28 x 1920, height 0.28 x 1920, width 0.88 x 1080, centred.
const GOAL_MOUTH_DESIGN := Rect2(64.8, 537.6, 950.4, 537.6)


## The text of one function, from its `func` line up to the next `func`.
func _function_body(src: String, fn: String) -> String:
	var at := src.find("func %s(" % fn)
	if at == -1:
		return ""
	var end := src.find("\nfunc ", at + 1)
	return src.substr(at, end - at) if end != -1 else src.substr(at)


func test_goalie_depth_knob_is_retired() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in RETIRED_LAYOUT_EXPORTS:
		assert_false(src.contains(retired),
			"%s is superseded by dragging the Goalie in the 2D editor" % retired)


func test_layout_measures_the_root_not_the_editor_viewport() -> void:
	# Inside the editor the viewport rect is a 2x2 stub (confirmed live on
	# 2026-09-10): the whole layout collapsed into the top-left corner, with
	# the goalie a speck at (1, 0.99).
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var layout := _function_body(src, "_setup_layout")
	assert_false(layout.contains("get_viewport_rect()"),
		"_setup_layout() must not measure the editor's stub viewport")
	assert_contains(layout, "screen_size = size",
		"_setup_layout() must measure the root Control's own size")
	assert_contains(src, "NOTIFICATION_RESIZED",
		"the layout must follow a resize of the root")


func test_the_editor_never_moves_the_goalie() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	var layout := _function_body(src, "_setup_layout")
	assert_false(layout.contains("goalie.global_position ="),
		"_setup_layout() must not compute the Goalie's position")
	assert_contains(layout, "_place_goalie()",
		"_setup_layout() hands the Goalie to _place_goalie()")
	var place := _function_body(src, "_place_goalie")
	assert_contains(place, "Engine.is_editor_hint()",
		"_place_goalie() must leave the Goalie where he was dragged in the editor")
	assert_contains(place, "_goalie_design_pos",
		"in game the Goalie's authored position is mapped, not recomputed")


func test_the_scene_goalie_stands_inside_the_goal_mouth() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var pos := (root.get_node("Goalie") as Node2D).position
	assert_true(GOAL_MOUTH_DESIGN.has_point(pos),
		"the Goalie is authored at %s, outside the goal mouth %s" % [pos, GOAL_MOUTH_DESIGN])


func test_design_to_screen_maps_each_axis_proportionally() -> void:
	var s: Script = load(SCRIPT_PATH)
	var design := Vector2(1080, 1920)
	var same: Vector2 = s.call("design_to_screen", Vector2(540, 946.176), design, design)
	assert_true(same.is_equal_approx(Vector2(540, 946.176)),
		"at the design size the authored position is used as-is, got %s" % same)
	var tall: Vector2 = s.call("design_to_screen", Vector2(540, 960), design, Vector2(1080, 2340))
	assert_true(tall.is_equal_approx(Vector2(540, 1170)),
		"on a taller phone he moves down in proportion, like the goal, got %s" % tall)
	var wide: Vector2 = s.call("design_to_screen", Vector2(270, 960), design, Vector2(1440, 1920))
	assert_true(wide.is_equal_approx(Vector2(360, 960)),
		"on a wider screen he moves sideways in proportion, got %s" % wide)
