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


func test_change_scene_accepts_a_duration_override() -> void:
	# One call site (MainMenu -> CutScene) wants a deliberately slower
	# wipe than the other ~20 call sites, without changing their
	# behavior. A third optional parameter is how that stays opt-in.
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var found := false
	for m in t.get_method_list():
		if m.name == "change_scene":
			found = true
			assert_true(m.args.size() >= 3,
				"change_scene must accept a duration override")
			assert_true(m.default_args.size() >= 2,
				"both style and duration_override need defaults so old call sites are unaffected")
	assert_true(found, "change_scene must exist")


## The cover used to be a flat ColorRect. It now carries a horizontal
## gradient (full through the middle, shallower at both edges) and a
## motif tiled from the progress bars' own fill art, so a wipe does not
## read as an empty field of colour.
func test_cover_has_a_gradient_and_a_pattern_layer() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var grad := t.get_node_or_null("ColorRect/Gradient") as TextureRect
	var pat := t.get_node_or_null("ColorRect/Pattern") as TextureRect
	assert_true(grad != null, "the cover must carry a Gradient layer")
	assert_true(pat != null, "the cover must carry a Pattern layer")
	assert_eq(pat.stretch_mode, TextureRect.STRETCH_TILE,
		"the motif must tile, not stretch, or the period breaks")
	assert_true(pat.modulate.a < 1.0,
		"the motif is a texture under the colour, not a foreground element")


## Both layers must ignore input for the same reason the ColorRect does:
## the overlay sits at layer 100 over every screen.
func test_cover_layers_never_intercept_taps() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	for path in ["ColorRect/Gradient", "ColorRect/Pattern"]:
		var node := t.get_node_or_null(path) as Control
		assert_true(node != null, "missing " + path)
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			path + " must never intercept taps")


## The ColorRect is now only the animated parent -- position, scale and
## modulate still drive the cover, but the visible colour rides on the
## Gradient layer. If the ColorRect ever went opaque again it would paint
## a flat block over the gradient and the edge ramp would vanish.
func test_colorrect_is_transparent_so_the_gradient_shows() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var rect := t.get_node_or_null("ColorRect") as ColorRect
	assert_true(rect != null, "ColorRect must exist")
	assert_eq(rect.color.a, 0.0,
		"the ColorRect must stay transparent; the Gradient carries the fill")


## Every motif the randomiser can draw must actually exist, or a
## transition silently falls back to a plain gradient.
func test_every_pattern_tile_resolves() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Transition/transition.gd")
	assert_true(src.contains("PATTERN_TILES"),
		"the tile roster must be a named const, not inline paths")
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var tiles: Array = t.PATTERN_TILES
	assert_eq(tiles.size(), 8, "all eight progress-bar fill tiles are in the roster")
	for path in tiles:
		assert_true(ResourceLoader.exists(path), "missing motif tile: " + str(path))


## The region is the nine-slice middle of a fill tile. Anything else
## either sweeps the capsule's rounded end across the screen or tiles on
## a period that does not divide the motif, which seams visibly.
func test_pattern_region_is_the_tiling_middle() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var region: Rect2 = t.PATTERN_REGION
	assert_eq(region.position, Vector2(84, 90),
		"region must start at the nine-slice middle (60+24, 66+24)")
	assert_eq(region.size, Vector2(100, 76),
		"region must be the 100x76 middle the bars repeat")
	assert_eq(int(region.size.x) % 20, 0, "width must divide the 20px motif period")
	assert_eq(int(region.size.y) % 19, 0, "height must divide the 19px motif period")


## The cover must be wider than the screen.
##
## The gradient's alpha dips at both ends. Sized exactly to the viewport,
## those soft ends sit on screen while the cover is at rest -- which is
## the frame the scene swaps on -- so the outgoing scene shows through
## two vertical bands. The overhang pushes the ramp off both sides.
##
## The floor is arithmetic, not taste: the opaque run is 0.18..0.82 of
## the cover, so it spans 0.64 of the width and must still bracket the
## screen. width * 0.64 >= viewport means overhang >= 0.28 per side.
func test_cover_overhangs_far_enough_to_hide_the_gradient_ends() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var ratio: float = t.cover_overhang_ratio
	var total: float = 1.0 + 2.0 * ratio
	assert_true(total * 0.18 <= ratio,
		"the opaque run must start at or left of the screen's left edge")
	assert_true(total * 0.82 >= ratio + 1.0,
		"the opaque run must end at or right of the screen's right edge")


## _size_cover() writes the offsets and hands back the per-side overhang
## the wipe needs. If it ever returned the total width, or half of it,
## the cover would stop in the wrong place and the bands would come back.
func test_size_cover_widens_the_rect_and_reports_the_overhang() -> void:
	var t: Node = Engine.get_main_loop().root.get_node("Transition")
	var rect := t.get_node_or_null("ColorRect") as Control
	assert_true(rect != null, "ColorRect must exist")
	var overhang: float = t._size_cover()
	assert_true(overhang > 0.0, "the cover must hang past the screen edges")
	assert_eq(rect.offset_left, -overhang, "left offset must be the negative overhang")
	assert_eq(rect.offset_right, overhang, "right offset must be the positive overhang")


## Guards the bug this overhang was added for: a WIPE that parks at
## Vector2.ZERO puts the cover's left edge at the screen's left edge,
## which drags the gradient's soft end back on screen. Setting `position`
## on an anchored Control overrides the offsets, so the resting position
## has to be -overhang, and zero is specifically wrong.
func test_wipe_rests_at_the_overhang_not_at_zero() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Transition/transition.gd")
	var from := src.find("func _cover_in")
	var to := src.find("func _cover_out")
	assert_true(from >= 0 and to > from, "could not isolate _cover_in")
	var body := src.substr(from, to - from)
	assert_true(body.contains("var rest := Vector2(-overhang, 0)"),
		"the covered position must be derived from the overhang")
	assert_false(body.contains("\"position\", Vector2.ZERO"),
		"parking the cover at zero is the see-through-edge bug")
