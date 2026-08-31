@tool
extends McpTestSuite

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
const TEXTURE_EXPORTS: Array[String] = [
	"goalie_idle_texture", "goalie_left_texture", "goalie_right_texture",
	"goalie_fail_texture", "ball_texture", "field_background_texture",
]

## Every magic fraction _setup_layout() used to hardcode.
const LAYOUT_EXPORTS: Array[String] = [
	"goal_top_frac", "goal_height_frac", "goal_width_frac",
	"post_width_frac", "crossbar_height_frac",
	"goalie_width_frac", "goalie_height_frac", "goalie_depth_frac",
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
