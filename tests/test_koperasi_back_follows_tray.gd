@tool
extends McpTestSuiteCompat

## Suite for Task 6 of the 2026-09-17 Koperasi polish: the back button's two
## export positions and its ride inside the crate's shared tween.
##
## koprasi.gd is not @tool and its Stage children have real side effects in
## _ready(), so (matching test_koperasi_tray_retract.gd's established
## pattern for this same script) none of these tests instantiate
## koprasi.tscn -- they scan its source text and koprasi.gd's, the same way
## the crate-handle tests in that suite already do.

func suite_name() -> String:
	return "koperasi_back_follows_tray"

const KOPRASI_TSCN := "res://Scenes/Koperasi/koprasi.tscn"
const KOPRASI_GD := "res://Scripts/Koperasi/koprasi.gd"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "%s missing" % path)
	if f == null:
		return ""
	return f.get_as_text()


## Pulls "Vector2(x.x, y.y)" straight after `needle` in src (the export's
## default-value literal) and returns it, or Vector2.INF if not found.
func _vector2_after(src: String, needle: String) -> Vector2:
	var at := src.find(needle)
	if at == -1:
		return Vector2.INF
	var open := src.find("(", at)
	var close := src.find(")", open)
	if open == -1 or close == -1:
		return Vector2.INF
	var parts := src.substr(open + 1, close - open - 1).split(",")
	if parts.size() != 2:
		return Vector2.INF
	return Vector2(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float())


## Pulls a numeric node property (e.g. "offset_top = 1157.0") out of one
## `[node ...]` block of tscn text.
func _node_block(src: String, node_header: String) -> String:
	var start := src.find(node_header)
	if start == -1:
		return ""
	var next_node := src.find("\n[node ", start + 1)
	if next_node == -1:
		next_node = src.length()
	return src.substr(start, next_node - start)


func _prop_float(block: String, prop: String) -> float:
	var at := block.find(prop + " = ")
	if at == -1:
		return NAN
	var line_end := block.find("\n", at)
	if line_end == -1:
		line_end = block.length()
	return block.substr(at + (prop + " = ").length(), line_end - at - (prop + " = ").length()).strip_edges().to_float()


func test_back_pos_exports_declared_with_doc_lines() -> void:
	var src := _read(KOPRASI_GD)
	if src.is_empty():
		return
	assert_true(src.contains("@export var back_pos_expanded: Vector2"),
		"koprasi.gd must declare back_pos_expanded")
	assert_true(src.contains("@export var back_pos_collapsed: Vector2"),
		"koprasi.gd must declare back_pos_collapsed")
	var exp_at := src.find("@export var back_pos_expanded")
	var col_at := src.find("@export var back_pos_collapsed")
	assert_true(exp_at != -1 and col_at != -1, "both exports must be found")
	# Each @export must be immediately preceded by a `##` doc line
	# (CLAUDE.md / common-context.md documentation rule).
	for at in [exp_at, col_at]:
		var line_start := src.rfind("\n", at)
		var prev_line_start := src.rfind("\n", line_start - 1)
		var prev_line := src.substr(prev_line_start + 1, line_start - prev_line_start - 1)
		assert_true(prev_line.strip_edges().begins_with("##"),
			"the line directly above an @export must be a ## doc comment")


func test_back_pos_collapsed_is_lower_than_expanded() -> void:
	var src := _read(KOPRASI_GD)
	if src.is_empty():
		return
	var expanded := _vector2_after(src, "@export var back_pos_expanded: Vector2 =")
	var collapsed := _vector2_after(src, "@export var back_pos_collapsed: Vector2 =")
	assert_true(expanded != Vector2.INF and collapsed != Vector2.INF,
		"both back_pos exports must have a literal Vector2 default")
	assert_true(collapsed.y > expanded.y,
		"the collapsed position must sit lower on screen than the expanded one")


func test_back_pos_x_matches_authored_back_button_x() -> void:
	var script_src := _read(KOPRASI_GD)
	var scene_src := _read(KOPRASI_TSCN)
	if script_src.is_empty() or scene_src.is_empty():
		return
	var expanded := _vector2_after(script_src, "@export var back_pos_expanded: Vector2 =")
	var collapsed := _vector2_after(script_src, "@export var back_pos_collapsed: Vector2 =")
	var back_block := _node_block(scene_src, "[node name=\"BackButton\" type=\"TextureButton\" parent=\"Stage\"")
	assert_true(back_block != "", "Stage/BackButton not found in koprasi.tscn")
	var authored_x := _prop_float(back_block, "offset_left")
	assert_true(expanded.x == authored_x, "back_pos_expanded.x must match BackButton's authored x")
	assert_true(collapsed.x == authored_x, "back_pos_collapsed.x must match BackButton's authored x -- it never moves sideways")


## The BackButton's authored rect in the .tscn must equal back_pos_expanded
## exactly, so nothing jumps on scene load before koprasi.gd's _ready() runs.
func test_authored_back_button_position_equals_back_pos_expanded() -> void:
	var script_src := _read(KOPRASI_GD)
	var scene_src := _read(KOPRASI_TSCN)
	if script_src.is_empty() or scene_src.is_empty():
		return
	var expanded := _vector2_after(script_src, "@export var back_pos_expanded: Vector2 =")
	var back_block := _node_block(scene_src, "[node name=\"BackButton\" type=\"TextureButton\" parent=\"Stage\"")
	assert_true(back_block != "", "Stage/BackButton not found in koprasi.tscn")
	var authored := Vector2(_prop_float(back_block, "offset_left"), _prop_float(back_block, "offset_top"))
	assert_true(authored.distance_to(expanded) < 0.5,
		"BackButton's authored offset_left/offset_top must equal back_pos_expanded (%s vs %s)" % [authored, expanded])


## Flushness against the tray's own visible top (Body, whose Stage-local top
## is 117 (TrayDock) + 1243 (Body offset_top) = 1360 -- see
## crate_pos_expanded's doc comment in koprasi.gd) and BackButton's authored
## height (185px, offset_bottom(1342) - offset_top(1157)). The gap comes out
## to 18px here rather than a flat 12, because back_pos_expanded was pinned
## to BackButton's PRE-EXISTING authored position (test_tall_screen_layout.gd
## asserts that exact rect as "unchanged") instead of being moved to hit
## 12px on the nose. Either way this test locks the real gap so a future
## layout change that pushes the tray (or the button) out of flush alignment
## fails here.
func test_expanded_gap_against_tray_top_is_locked() -> void:
	var script_src := _read(KOPRASI_GD)
	var scene_src := _read(KOPRASI_TSCN)
	if script_src.is_empty() or scene_src.is_empty():
		return
	var expanded := _vector2_after(script_src, "@export var back_pos_expanded: Vector2 =")
	var back_block := _node_block(scene_src, "[node name=\"BackButton\" type=\"TextureButton\" parent=\"Stage\"")
	var back_height := _prop_float(back_block, "offset_bottom") - _prop_float(back_block, "offset_top")
	var tray_dock_block := _node_block(scene_src, "[node name=\"TrayDock\" type=\"Control\" parent=\"Stage\"")
	var tray_dock_top := _prop_float(tray_dock_block, "offset_top")
	var body_block := _node_block(_read("res://Scenes/Koperasi/BasketTray.tscn"),
		"[node name=\"Body\" type=\"Control\" parent=\".\"")
	var body_top := _prop_float(body_block, "offset_top")
	var tray_top := tray_dock_top + body_top
	var gap := tray_top - (expanded.y + back_height)
	assert_true(absf(gap - 18.0) < 0.5,
		"expanded gap against the tray's visible top should be 18px (tray_top=%s, button_bottom=%s), got %s" %
			[tray_top, expanded.y + back_height, gap])


## Flushness against the collapsed crate handle's top edge: crate_pos_collapsed
## is CrateHandle's authored top-left (pivot (0,0), COLLAPSED scale 1.0 --
## see _on_tray_state_changed), so its .y IS the crate's on-screen top there.
func test_collapsed_gap_against_crate_top_is_12px() -> void:
	var script_src := _read(KOPRASI_GD)
	var scene_src := _read(KOPRASI_TSCN)
	if script_src.is_empty() or scene_src.is_empty():
		return
	var collapsed := _vector2_after(script_src, "@export var back_pos_collapsed: Vector2 =")
	var crate_pos_collapsed := _vector2_after(script_src, "@export var crate_pos_collapsed: Vector2 =")
	var back_block := _node_block(scene_src, "[node name=\"BackButton\" type=\"TextureButton\" parent=\"Stage\"")
	var back_height := _prop_float(back_block, "offset_bottom") - _prop_float(back_block, "offset_top")
	var gap := crate_pos_collapsed.y - (collapsed.y + back_height)
	assert_true(absf(gap - 12.0) < 0.5,
		"collapsed gap against the crate's top edge should be 12px, got %s" % gap)


## Spec section 4 / "Cross-cutting: one tween per user gesture" -- the back
## button's tween_property must live in the SAME tween the crate uses
## (_crate_tween), not a second create_tween() of its own.
func test_back_button_animates_inside_the_shared_crate_tween() -> void:
	var src := _read(KOPRASI_GD)
	if src.is_empty():
		return
	var start := src.find("func _on_tray_state_changed(")
	assert_true(start != -1, "_on_tray_state_changed must exist")
	if start == -1:
		return
	var next_func := src.find("\nfunc ", start + 1)
	if next_func == -1:
		next_func = src.length()
	var body := src.substr(start, next_func - start)
	assert_true(body.contains("_crate_tween.tween_property(back_button,"),
		"the back button must be animated on _crate_tween, the same shared tween as the crate")
	assert_eq(body.count("create_tween()"), 1,
		"there must be exactly one create_tween() call in this handler -- no second tween for the back button")
	assert_true(body.contains("back_pos_expanded if expanded else back_pos_collapsed"),
		"the back button's tween target must switch on the same `expanded` flag as the crate's")


## On _ready(), the back button is placed to match the tray's current state
## without any tween/await (CLAUDE.md rule 2: no await in tests, and the
## brief calls for a snap, not an animation, at boot).
func test_ready_places_back_button_without_animating() -> void:
	var src := _read(KOPRASI_GD)
	if src.is_empty():
		return
	var start := src.find("func _ready():")
	assert_true(start != -1, "_ready() must exist")
	if start == -1:
		return
	var next_func := src.find("\nfunc ", start + 1)
	var body := src.substr(start, next_func - start)
	assert_true(body.contains("back_button.position = back_pos_expanded if tray_expanded else back_pos_collapsed") \
			or body.contains("back_button.position = back_pos_expanded"),
		"_ready() must set back_button.position directly (no tween) from the export(s)")
	assert_false(body.contains("create_tween()"),
		"_ready() must not animate the back button into place")
