@tool
extends McpTestSuite

func suite_name() -> String:
	return "transition"


func test_autoload_exists() -> void:
	var t: Node = Engine.get_main_loop().root.get_node_or_null("Transition")
	assert_true(t != null, "the Transition autoload must be in the tree")


func test_change_scene_still_accepts_a_single_argument() -> void:
	# 21 existing call sites use Transition.change_scene(path). Adding
	# the style parameter must not break any of them.
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var found := false
	for m in t.get_method_list():
		if m.name == "change_scene":
			found = true
			assert_true(m.args.size() >= 1, "change_scene takes a path")
			assert_true(m.default_args.size() >= 1,
				"the style parameter must have a default so 1-arg calls work")
	assert_true(found, "change_scene must exist")


func test_style_enum_covers_all_three_styles() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	assert_true(t.Style.has("WIPE"), "Style.WIPE")
	assert_true(t.Style.has("FADE"), "Style.FADE")
	assert_true(t.Style.has("IRIS"), "Style.IRIS")


func test_scene_changed_signal_exists() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	assert_true(t.has_signal("scene_changed"),
		"screens need a hook to start their entry animation")


func test_transition_layer_is_above_everything() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	assert_true(t.layer >= 100,
		"the transition must draw above all game content")


func test_overlay_does_not_block_input_when_idle() -> void:
	# A transition overlay left hit-testable makes the whole game
	# unclickable — the single worst failure mode for this node.
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var rect := t.get_node_or_null("ColorRect") as Control
	assert_true(rect != null, "ColorRect must exist")
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the overlay must never intercept taps")
