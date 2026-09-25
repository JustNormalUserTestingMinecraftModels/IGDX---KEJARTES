@tool
extends McpTestSuite

## The SchoolDay sky's ambient life (2026-09-24 liveliness pass, layers 4, 6
## and 8): a sun and moon riding the rotating sky, drifting clouds, the deep
## night beat between days, and rain on a Hujan day.
##
## Suite is @tool and no test is a coroutine, per the runner constraints.

const SCENE_PATH := "res://Scenes/SchoolSimulation/BookClockWidget.tscn"
const SCHOOL_DAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const SCHOOL_DAY_SCENE := "res://Scenes/SchoolSimulation/SchoolDay.tscn"


func suite_name() -> String:
	return "sky_life"


var _w: BookClockWidget


## One widget for the whole suite (see test_school_day for why); every
## test sets the progress, night and size it reads. Not tracked;
## suite_teardown frees it.
func suite_setup(_ctx: Dictionary) -> void:
	_w = (load(SCENE_PATH) as PackedScene).instantiate() as BookClockWidget
	Engine.get_main_loop().root.add_child(_w)
	# The widget is full-rect anchored, so under the editor's root it takes the
	# editor window's size. Unpin it and give it the phone's.
	_w.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_w.size = Vector2(1080, 1920)
	_w._fit_layers()


func suite_teardown() -> void:
	if is_instance_valid(_w):
		_w.get_parent().remove_child(_w)
		_w.free()
	_w = null


## Where a body's centre actually draws. get_global_rect() ignores the
## rotating parent, so transform the local centre instead.
func _screen_centre(path: NodePath) -> Vector2:
	var c := _w.get_node(path) as Control
	return c.get_global_transform() * (c.size * 0.5)


## The bodies are placed from the same progress that turns the sky, inside
## set_progress() -- the spec's "no independent timer to drift".
func test_the_sun_and_moon_follow_the_day_progress() -> void:
	for path in [BookClockWidget.SUN_PATH, BookClockWidget.MOON_PATH]:
		var body := _w.get_node_or_null(path) as TextureRect
		assert_true(body != null, "the sky needs %s" % path)
		if body:
			assert_true(body.texture != null, "%s has art" % path)
			assert_eq(body.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s never eats a tap" % path)
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/BookClockWidget.gd")
	var at := src.find("func set_progress(")
	var body_src := src.substr(at, src.find("
func ", at + 1) - at)
	assert_true(body_src.contains("_place_bodies()"), "set_progress moves the bodies with the sky")


## Midday: the sun stands high over the school and the moon is down. The
## dark dawn and evening: the other way round. Under the school's roofline
## in between, the painting hides whichever is setting.
func test_the_sun_is_up_at_midday_and_the_moon_at_the_dark_poses() -> void:
	var sun := _w.get_node(BookClockWidget.SUN_PATH) as Control
	var moon := _w.get_node(BookClockWidget.MOON_PATH) as Control
	var header := _w.get_node("Header") as Control
	_w.set_progress(0.5)
	assert_true(sun.visible, "the midday sun is up")
	assert_false(moon.visible, "the midday moon is down")
	var centre := sun.position + sun.size * 0.5
	assert_true(absf(centre.x - 540.0) < 1.0, "the midday sun is overhead, x %d" % int(centre.x))
	assert_true(sun.position.y > header.offset_bottom, "and below the header, y %d" % int(sun.position.y))
	for p in [0.0, 1.0]:
		_w.set_progress(p)
		assert_false(sun.visible, "the sun is down at progress %.1f" % p)
		assert_true(moon.visible, "the moon is up at progress %.1f" % p)
		assert_true(moon.position.y < 1920.0 * 0.5, "and high, y %d" % int(moon.position.y))


## The sun rises on the right and sets on the left, and stays on screen.
## The moon keeps to the dark: it is never up while the sun is high.
func test_the_moon_is_not_up_beside_the_afternoon_sun() -> void:
	var sun := _w.get_node(BookClockWidget.SUN_PATH) as Control
	var moon := _w.get_node(BookClockWidget.MOON_PATH) as Control
	for p in [0.3, 0.4, 0.5, 0.6, 0.7]:
		_w.set_progress(p)
		assert_true(sun.visible, "the sun is up at %.1f" % p)
		assert_false(moon.visible, "and the moon is not, at %.1f" % p)


func test_the_sun_crosses_the_screen_right_to_left() -> void:
	var sun := _w.get_node(BookClockWidget.SUN_PATH) as Control
	_w.set_progress(0.3)
	var morning := sun.position.x
	_w.set_progress(0.7)
	var afternoon := sun.position.x
	assert_true(morning > afternoon, "morning sun on the right, afternoon on the left")
	for p in [0.2, 0.35, 0.5, 0.65, 0.8]:
		_w.set_progress(p)
		var c := sun.position + sun.size * 0.5
		assert_true(c.x > 0.0 and c.x < 1080.0, "the sun stays on screen at %.2f, x %d" % [p, int(c.x)])


func test_night_fades_every_night_layer_together() -> void:
	_w.set_night(0.0)
	for path in [BookClockWidget.NIGHT_TINT_PATH, BookClockWidget.STARS_PATH,
			BookClockWidget.WINDOW_GLOW_PATH, BookClockWidget.SCHOOL_NIGHT_PATH]:
		var layer := _w.get_node_or_null(path) as CanvasItem
		assert_true(layer != null, "the night needs %s" % path)
		if layer:
			assert_eq(layer.modulate.a, 0.0, "%s is invisible by day" % path)
			assert_eq((layer as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s never eats a tap" % path)
	_w.set_night(1.0)
	assert_eq((_w.get_node(BookClockWidget.STARS_PATH) as CanvasItem).modulate.a, 1.0, "stars out")
	assert_eq((_w.get_node(BookClockWidget.WINDOW_GLOW_PATH) as CanvasItem).modulate.a, 1.0,
		"windows lit")
	assert_true(absf((_w.get_node(BookClockWidget.SCHOOL_NIGHT_PATH) as CanvasItem).modulate.a
		- _w.school_night_strength) < 0.001, "the school darkens by the tuned strength")
	assert_eq(_w.night(), 1.0, "night() reports it")
	_w.set_night(0.0)


## The lit windows are a full-frame twin of the foreground, fitted the same
## way -- so at 1080x2400 they stay on the painted windows.
func test_the_night_twins_cover_the_foreground_exactly() -> void:
	for h in [1920.0, 2400.0]:
		_w.size = Vector2(1080, h)
		_w._fit_layers()
		var fg := _w.get_node("SchoolForeground") as TextureRect
		for path in [BookClockWidget.SCHOOL_NIGHT_PATH, BookClockWidget.WINDOW_GLOW_PATH]:
			var twin := _w.get_node(path) as TextureRect
			assert_eq(twin.get_rect(), fg.get_rect(), "%s matches the foreground at %d" % [path, int(h)])
			assert_eq(twin.stretch_mode, fg.stretch_mode, "and stretches the same way")
		var school := _w.get_node(BookClockWidget.SCHOOL_NIGHT_PATH) as TextureRect
		assert_eq(school.texture, fg.texture, "the silhouette is the foreground itself")
	_w.size = Vector2(1080, 1920)


func test_the_night_layers_sit_between_the_sky_and_the_header() -> void:
	var idx := func(path) -> int: return _w.get_node(path).get_index()
	var sky: int = idx.call(^"SkyBackground")
	var tint: int = idx.call(BookClockWidget.NIGHT_TINT_PATH)
	var bodies: int = idx.call(^"SkyBodies")
	var clouds: int = idx.call(^"CloudLayer")
	var fg: int = idx.call(^"SchoolForeground")
	assert_true(sky < tint, "the tint darkens the sky")
	assert_true(tint < idx.call(BookClockWidget.STARS_PATH), "the stars shine over the tint")
	assert_true(tint < bodies, "and so does the moon")
	assert_true(bodies < clouds, "clouds drift in front of the sun and moon")
	assert_true(clouds < fg, "the school stands in front of everything in the sky")
	assert_true(fg < idx.call(BookClockWidget.SCHOOL_NIGHT_PATH), "the silhouette darkens the school")
	assert_true(idx.call(BookClockWidget.SCHOOL_NIGHT_PATH) < idx.call(BookClockWidget.WINDOW_GLOW_PATH),
		"the windows glow through it")
	assert_true(idx.call(BookClockWidget.WINDOW_GLOW_PATH) < idx.call(^"Header"), "the header stays on top")


## The clouds sit above the tint, so they darken themselves at night.
func test_the_clouds_dim_at_night() -> void:
	var clouds := _w.get_node("CloudLayer") as CanvasItem
	_w.set_night(0.0)
	assert_eq(clouds.modulate, Color.WHITE, "full white by day")
	_w.set_night(1.0)
	assert_true(clouds.modulate.v < 0.5, "dimmed at night, value %.2f" % clouds.modulate.v)
	_w.set_night(0.0)


func test_clouds_drift_at_parallax_speeds_and_wrap() -> void:
	var layer := _w.get_node("CloudLayer") as CloudDrift
	assert_true(layer != null, "CloudLayer carries the CloudDrift driver")
	if layer == null:
		return
	assert_true(layer.get_child_count() >= 2, "at least two drifting clouds")
	assert_true(layer.speed_for(1) > layer.speed_for(0), "later clouds drift faster")
	var c := layer.get_child(0) as Control
	var x0 := c.position.x
	layer.step(1.0)
	assert_true(absf(c.position.x - (x0 + layer.speed_for(0))) < 0.01, "one second moves it its speed")
	c.position.x = layer.size.x + 1.0
	layer.step(0.0)
	assert_eq(c.position.x, -c.size.x, "a cloud leaving the right edge re-enters from the left")
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/CloudDrift.gd")
	assert_true(src.contains("Engine.is_editor_hint() or GameSettings.reduce_motion"),
		"drift never runs in the editor or under reduce_motion")


func test_school_day_plays_the_night_beat_and_the_rain() -> void:
	var src := FileAccess.get_file_as_string(SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("var night_fall := _begin_night()"), "night falls at the day-advance fade")
	assert_true(src.contains("await get_tree().create_timer(NIGHT_HOLD).timeout"), "and holds briefly")
	assert_true(src.contains("_lift_night()"), "the next dawn lifts it")
	var hujan := src.find('_show_event_dialogue("hujan")')
	assert_true(hujan > 0 and src.find("_set_rain(true)", hujan) > hujan,
		"the Hujan event turns the rain on")
	assert_true(src.contains("_set_rain(false)"), "a new day clears it")
	var scene := (load(SCHOOL_DAY_SCENE) as PackedScene).instantiate()
	var rain := scene.get_node_or_null("Rain") as CPUParticles2D
	assert_true(rain != null, "the rain is authored in the scene")
	if rain:
		assert_false(rain.emitting, "no rain until Hujan")
		assert_true(rain.texture != null, "the streak texture is set")
	scene.free()


# ── Escalation and micro-motion (liveliness pass, layers 5, 6 and 8) ─────────

## Every day ends on a small burst from the stamp; the week's last school
## day adds the fireworks volley.
func test_the_day_end_escalates_on_the_last_day() -> void:
	var src := FileAccess.get_file_as_string(SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("_celebrate_day_end(current_day == DAYS.size() - 1)"),
		"the stamp knows whether this is the week's last school day")
	assert_true(src.contains('RewardFeedback.play(&"day_done", day_stamp)'), "every day bursts")
	assert_true(src.contains("week_fireworks.fire_burst.bind(i)"), "the last day fires the volley")
	assert_true(RewardFeedback.RECIPES.has(&"day_done"), "RewardFeedback knows day_done")
	assert_true(RewardFeedback.RECIPES[&"day_done"].get("centred", false), "bursting from the stamp's middle")
	var scene := (load(SCHOOL_DAY_SCENE) as PackedScene).instantiate()
	var fireworks := scene.get_node_or_null("WeekFireworks") as ConfettiFireworks
	assert_true(fireworks != null, "the fireworks are authored in the scene")
	if fireworks:
		assert_eq(fireworks.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and never eat a tap")
		assert_true(fireworks.get_index() < scene.get_node("GameContainer").get_index(),
			"under the minigames and the result screen")
	scene.free()


## The motes are the weekday texture layer the dead 0.07-alpha wash was
## meant to be: one sprite per school day, drifting up the sky.
func test_each_weekday_drifts_its_own_motes() -> void:
	var scene := (load(SCHOOL_DAY_SCENE) as PackedScene).instantiate()
	var motes := scene.get_node_or_null("Motes") as CPUParticles2D
	assert_true(motes != null, "the motes are authored")
	var textures: Array = scene.get("weekday_mote_textures")
	assert_eq(textures.size(), 5, "one mote sprite per school day")
	var unique := {}
	for t in textures:
		unique[t] = true
	assert_eq(unique.size(), 5, "each day's sprite is its own")
	if motes:
		assert_true(motes.modulate.a < 0.6, "kept faint: backdrop, not content")
		assert_true(motes.get_index() < scene.get_node("DayScreen").get_index(), "behind the day's UI")
	scene.free()
	var src := FileAccess.get_file_as_string(SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("_set_weekday_motes(current_day)"), "each day swaps the sprite")


func test_the_banner_bobs_and_its_fill_drifts_in_game_only() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/BookClockWidget.gd")
	var at := src.find("func _process(")
	assert_true(at >= 0, "the widget has an idle loop")
	var body := src.substr(at, src.find("\nfunc ", at + 1) - at)
	assert_true(body.contains("Engine.is_editor_hint() or GameSettings.reduce_motion"),
		"never in the editor, never under reduce_motion")
	assert_true(body.contains("banner_bob_px"), "the banner bobs")
	assert_true(body.contains("motif_drift_speed"), "the fill's motif drifts")
	var motif := _w.get_node(BookClockWidget.MOTIF_PATH) as Control
	assert_eq(motif.offset_right, BookClockWidget.MOTIF_PERIOD,
		"the motif runs one repeat past the fill so the drift never shows a gap")


## Review 2026-09-24: under reduce_motion the motes must never show, so the
## scene authors them off and each day turns them on only without it.
func test_the_motes_start_off() -> void:
	var scene := (load(SCHOOL_DAY_SCENE) as PackedScene).instantiate()
	var motes := scene.get_node("Motes") as CPUParticles2D
	assert_false(motes.emitting, "authored off; _set_weekday_motes turns them on")
	scene.free()
	var src := FileAccess.get_file_as_string(SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("motes.emitting = not GameSettings.reduce_motion"), "never under reduce_motion")


## Review 2026-09-24: a minigame or event skill gain pops too -- since
## 2026-09-25 one pop per risen skill, not one summed +N.
func test_event_and_minigame_gains_pop_too() -> void:
	var src := FileAccess.get_file_as_string(SCHOOL_DAY_SCRIPT)
	var at := src.find("func _animate_embedded_stat_updates(")
	var body := src.substr(at, src.find("
func ", at + 1) - at)
	assert_true(body.contains("chip.pop_gains(gained)"),
		"a skill rise after an event or minigame floats its pops")
	assert_true(src.contains('w["skills"] = _skill_values(w["student"])'),
		"the activity's gains are banked so they never pop twice")
