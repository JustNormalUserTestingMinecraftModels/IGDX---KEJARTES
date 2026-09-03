@tool
extends McpTestSuite

## The day-passing cinematic on SchoolDay: a square sky texture that
## rotates counter-clockwise around a stationary school foreground.
##
## Everything here is synchronous by construction. set_progress() applies
## rotation directly rather than tweening it, and set_size() fires
## NOTIFICATION_RESIZED immediately, so no test in this suite needs to
## await -- which the runner could not honour anyway (it calls
## suite.call(name) without awaiting).

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _WIDGET_SCENE := "res://Scenes/SchoolSimulation/BookClockWidget.tscn"
const _WIDGET_SCRIPT := "res://Scripts/SchoolSimulation/BookClockWidget.gd"
const _SCHOOL_DAY_SCENE := "res://Scenes/SchoolSimulation/SchoolDay.tscn"
const _SCHOOL_DAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"

## The project's design resolution. The cover-scale assertions below are
## written against it.
const _DESIGN_SIZE := Vector2(1080, 1920)


func suite_name() -> String:
	return "sky_transition"


func _instantiate(path: String) -> Control:
	var scene: PackedScene = load(path)
	var inst := scene.instantiate() as Control
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	return inst


## A widget sized to the design resolution, so geometry is deterministic.
func _sized_widget() -> Control:
	var w := _instantiate(_WIDGET_SCENE)
	w.size = _DESIGN_SIZE
	return w


# ------------------------------------------------ scene shape

func test_scene_has_both_named_layers() -> void:
	var w := _instantiate(_WIDGET_SCENE)
	var sky := w.get_node_or_null("SkyBackground")
	var fg := w.get_node_or_null("SchoolForeground")
	assert_not_null(sky, "the rotating sky layer must be named SkyBackground")
	assert_not_null(fg, "the stationary layer must be named SchoolForeground")
	assert_true(sky is TextureRect, "SkyBackground must be a TextureRect")
	assert_true(fg is TextureRect, "SchoolForeground must be a TextureRect")


func test_both_layers_carry_their_texture_from_the_scene() -> void:
	var w := _instantiate(_WIDGET_SCENE)
	var sky: TextureRect = w.get_node("SkyBackground")
	var fg: TextureRect = w.get_node("SchoolForeground")
	assert_not_null(sky.texture, "the sky texture must be assigned in the .tscn, not at runtime")
	assert_not_null(fg.texture, "the foreground texture must be assigned in the .tscn, not at runtime")


func test_the_foreground_is_drawn_over_the_sky() -> void:
	var w := _instantiate(_WIDGET_SCENE)
	var sky_idx := w.get_node("SkyBackground").get_index()
	var fg_idx := w.get_node("SchoolForeground").get_index()
	assert_true(fg_idx > sky_idx,
		"SchoolForeground must come after SkyBackground so it paints on top")


func test_no_layer_swallows_input() -> void:
	# A full-screen Control defaults to MOUSE_FILTER_STOP, which would eat
	# SchoolDay's tap-to-continue. All three nodes must ignore the mouse.
	var w := _instantiate(_WIDGET_SCENE)
	assert_eq(w.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the cinematic root must not intercept taps")
	for child_name in ["SkyBackground", "SchoolForeground"]:
		var c: Control = w.get_node(child_name)
		assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			child_name + " must not intercept taps")


# ------------------------------------------------ progress -> rotation

func test_progress_zero_is_the_start_angle() -> void:
	var w := _sized_widget()
	w.call("set_progress", 0.0)
	assert_eq(w.call("current_rotation_degrees"), w.get("start_rotation_degrees"),
		"progress 0 must sit exactly on the authored morning pose")


func test_progress_one_is_the_full_sweep() -> void:
	var w := _sized_widget()
	w.call("set_progress", 1.0)
	var expected: float = w.get("start_rotation_degrees") + w.get("total_rotation_degrees")
	assert_true(absf(w.call("current_rotation_degrees") - expected) < 0.001,
		"progress 1 must land exactly on start + total")


func test_the_sweep_turns_counter_clockwise() -> void:
	# Godot's rotation is clockwise-positive with y down, so a
	# counter-clockwise sweep must end at a smaller angle than it started.
	var w := _sized_widget()
	w.call("set_progress", 0.0)
	var start: float = w.call("current_rotation_degrees")
	w.call("set_progress", 1.0)
	assert_true(w.call("current_rotation_degrees") < start,
		"the sky must turn counter-clockwise, matching the mechanism reference")


func test_rotation_is_monotone_across_the_day() -> void:
	var w := _sized_widget()
	var previous: float = INF
	for i in range(21):
		w.call("set_progress", float(i) / 20.0)
		var current: float = w.call("current_rotation_degrees")
		assert_true(current <= previous + 0.001,
			"the sky must never turn back on itself at progress %f" % (float(i) / 20.0))
		previous = current


func test_the_sweep_eases_in_and_out() -> void:
	# smoothstep's defining property: it is slower than linear in the
	# first quarter, faster than linear across the middle.
	var w := _sized_widget()
	assert_true(w.get("ease_in_out"), "the widget must ship with easing on")
	w.call("set_progress", 0.25)
	assert_true(w.call("eased_progress") < 0.25,
		"the first quarter of the day must move less than linear (ease in)")
	w.call("set_progress", 0.75)
	assert_true(w.call("eased_progress") > 0.75,
		"the last quarter must have already covered more than linear (ease out)")
	w.call("set_progress", 0.5)
	assert_true(absf(float(w.call("eased_progress")) - 0.5) < 0.001,
		"the easing must stay symmetric about the midpoint")


func test_progress_is_clamped() -> void:
	var w := _sized_widget()
	w.call("set_progress", -3.0)
	assert_eq(w.call("progress"), 0.0, "progress must clamp at 0")
	w.call("set_progress", 42.0)
	assert_eq(w.call("progress"), 1.0, "progress must clamp at 1")


func test_the_sky_node_actually_receives_the_rotation() -> void:
	var w := _sized_widget()
	w.call("set_progress", 1.0)
	var sky: TextureRect = w.get_node("SkyBackground")
	assert_true(absf(sky.rotation_degrees - float(w.call("current_rotation_degrees"))) < 0.001,
		"set_progress must push the angle onto SkyBackground immediately")


func test_the_foreground_never_rotates() -> void:
	var w := _sized_widget()
	w.call("set_progress", 0.6)
	var fg: TextureRect = w.get_node("SchoolForeground")
	assert_eq(fg.rotation, 0.0, "the school must stay put while the sky turns")


# ------------------------------------------------ lifecycle

func test_set_day_starts_the_sweep_from_morning() -> void:
	var w := _sized_widget()
	w.call("set_progress", 0.8)
	w.call("set_day", "Senin")
	assert_eq(w.call("progress"), 0.0, "a new day must restart the sweep")
	assert_eq(w.call("day_name"), "Senin", "set_day must record the weekday")


func test_reset_clears_day_and_progress() -> void:
	var w := _sized_widget()
	w.call("set_day", "Jumat")
	w.call("set_progress", 0.9)
	w.call("reset")
	assert_eq(w.call("progress"), 0.0, "reset must rewind the sweep")
	assert_eq(w.call("day_name"), "", "reset must clear the weekday")


# ------------------------------------------------ responsive geometry

## The farthest a rectangle's corner (0,0)-(extent) can be from an
## arbitrary point -- the radius a pivoted rotating square must reach to
## guarantee full coverage. Shared by every covering-math assertion below
## so the "farthest corner" rule is expressed once, not four times.
func _farthest_corner_distance(pivot: Vector2, extent: Vector2) -> float:
	var farthest: float = 0.0
	for corner in [Vector2.ZERO, Vector2(extent.x, 0.0), Vector2(0.0, extent.y), extent]:
		farthest = maxf(farthest, pivot.distance_to(corner))
	return farthest


func test_the_default_pivot_matches_the_mockup() -> void:
	# docs/superpowers/mockups/day-transition-mechanism.png marks the
	# rotation point (a blue dot) at the visible frame's bottom-centre:
	# the sky's vortex converges at the school's ground line, not at the
	# screen's geometric middle.
	var w := _instantiate(_WIDGET_SCENE)
	var ratio: Vector2 = w.get("sky_pivot_ratio")
	assert_true(ratio.distance_to(Vector2(0.5, 1.0)) < 0.001,
		"the default pivot must match the mechanism mockup's blue dot")


func test_the_sky_is_square_and_centred_on_the_pivot() -> void:
	var w := _sized_widget()
	var sky: TextureRect = w.get_node("SkyBackground")
	assert_true(absf(sky.size.x - sky.size.y) < 0.001,
		"the rotating layer must be square or it will wobble")
	var sky_centre := sky.position + sky.size * 0.5
	var ratio: Vector2 = w.get("sky_pivot_ratio")
	var pivot_point: Vector2 = _DESIGN_SIZE * ratio
	assert_true(sky_centre.distance_to(pivot_point) < 0.001,
		"the sky must be centred on the configured pivot, or it will orbit off-axis")


func test_the_sky_pivots_about_its_own_centre() -> void:
	var w := _sized_widget()
	var sky: TextureRect = w.get_node("SkyBackground")
	assert_true(sky.pivot_offset.distance_to(sky.size * 0.5) < 0.001,
		"rotating about anything but the centre would swing the sky off-screen")


func test_the_sky_covers_the_screen_at_every_angle() -> void:
	# The worst case for a rotating square is its inscribed circle: any
	# point further from the pivot than size/2 can rotate out of frame.
	# With an off-centre pivot the danger corner is whichever screen
	# corner sits FARTHEST from it, not the nearest -- for the default
	# bottom-centre pivot that is one of the top corners, not the bottom
	# ones the pivot sits right next to.
	var w := _sized_widget()
	var sky: TextureRect = w.get_node("SkyBackground")
	var ratio: Vector2 = w.get("sky_pivot_ratio")
	var pivot_point: Vector2 = _DESIGN_SIZE * ratio
	var inscribed_radius: float = sky.size.x * 0.5
	var farthest_corner: float = _farthest_corner_distance(pivot_point, _DESIGN_SIZE)
	assert_true(inscribed_radius >= farthest_corner,
		"a corner of the page would show through at some angle: radius %f < %f"
			% [inscribed_radius, farthest_corner])


func test_the_foreground_fills_the_screen_exactly() -> void:
	var w := _sized_widget()
	var fg: TextureRect = w.get_node("SchoolForeground")
	assert_eq(fg.position, Vector2.ZERO, "the foreground must start at the origin")
	assert_eq(fg.size, _DESIGN_SIZE, "the foreground must fill the screen")


func test_geometry_follows_a_resize() -> void:
	var w := _sized_widget()
	w.size = Vector2(720, 1280)
	var sky: TextureRect = w.get_node("SkyBackground")
	var ratio: Vector2 = w.get("sky_pivot_ratio")
	var expected_pivot: Vector2 = Vector2(720, 1280) * ratio
	var sky_centre := sky.position + sky.size * 0.5
	assert_true(sky_centre.distance_to(expected_pivot) < 0.001,
		"the sky must re-centre on the configured pivot when the viewport changes")
	assert_true(sky.size.x * 0.5 >= _farthest_corner_distance(expected_pivot, Vector2(720, 1280)),
		"the sky must re-cover when the viewport changes")


func test_changing_the_pivot_ratio_moves_and_recovers_the_sky() -> void:
	# A non-default pivot -- e.g. tuning the mockup reading later -- must
	# still produce a correctly centred, fully covering square, not just
	# the default (0.5, 1.0) case.
	var w := _sized_widget()
	w.set("sky_pivot_ratio", Vector2(0.3, 0.7))
	var sky: TextureRect = w.get_node("SkyBackground")
	var expected_pivot: Vector2 = _DESIGN_SIZE * Vector2(0.3, 0.7)
	var sky_centre := sky.position + sky.size * 0.5
	assert_true(sky_centre.distance_to(expected_pivot) < 0.001,
		"changing sky_pivot_ratio must move the sky's centre to match")
	assert_true(sky.size.x * 0.5 >= _farthest_corner_distance(expected_pivot, _DESIGN_SIZE),
		"changing sky_pivot_ratio must still keep the screen fully covered")


# ------------------------------------------------ the old widget is gone

func test_no_procedural_drawing_survives() -> void:
	var src := FileAccess.get_file_as_string(_WIDGET_SCRIPT)
	for banned in ["func _draw(", "draw_circle(", "draw_arc(", "Image.create(", "save_png("]:
		assert_false(src.contains(banned),
			"the cinematic is authored art now, not procedural: found " + banned)


func test_no_runtime_node_construction_survives() -> void:
	var src := FileAccess.get_file_as_string(_WIDGET_SCRIPT)
	assert_false(src.contains("add_child("),
		"both layers live in the .tscn; nothing may be built at runtime")


func test_every_export_is_documented() -> void:
	# Mirrors tests/test_script_documentation.gd's rule, checked here too
	# so this suite fails loudly if a knob is added without a ## line.
	var lines := FileAccess.get_file_as_string(_WIDGET_SCRIPT).split("\n")
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("@export") \
				and not lines[i].strip_edges().begins_with("@export_group"):
			var previous := lines[i - 1].strip_edges() if i > 0 else ""
			assert_true(previous.begins_with("##"),
				"every @export needs a ## line above it, missing on: " + lines[i].strip_edges())


# ------------------------------------------------ placement in SchoolDay

func test_the_cinematic_is_a_full_screen_backdrop_not_a_vbox_row() -> void:
	var day := _instantiate(_SCHOOL_DAY_SCENE)
	assert_true(day.get_node_or_null("DayScreen/BookClockWidget") == null,
		"the cinematic must no longer be a row inside the DayScreen VBox")
	var widget := day.get_node_or_null("BookClockWidget")
	assert_not_null(widget, "the cinematic must sit on the SchoolDay root")
	var background := day.get_node_or_null("Background")
	var day_screen := day.get_node_or_null("DayScreen")
	assert_true(widget.get_index() > background.get_index(),
		"the cinematic must paint over the page background")
	assert_true(widget.get_index() < day_screen.get_index(),
		"the day's labels and bars must read over the cinematic")


func test_school_day_points_at_the_new_path() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_false(src.contains("DayScreen/BookClockWidget"),
		"no reference to the old VBox path may survive")
	assert_true(src.contains("$BookClockWidget"),
		"the @onready ref must point at the root-level node")
