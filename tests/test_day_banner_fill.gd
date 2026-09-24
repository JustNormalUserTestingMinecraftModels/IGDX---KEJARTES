@tool
extends McpTestSuite

## The day banner as the day's progress bar (2026-09-24 SchoolDay liveliness
## pass, layers 1-2). The banner fills left to right in the day's category
## colour as the day runs, and the day name is an inverting knockout: dark on
## the empty side, white under the fill, flipping exactly at the fill edge.
##
## Suite is @tool and no test is a coroutine, per the runner constraints.

const SCENE_PATH := "res://Scenes/SchoolSimulation/BookClockWidget.tscn"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "day_banner_fill"


var _w: BookClockWidget


func setup() -> void:
	_w = (load(SCENE_PATH) as PackedScene).instantiate() as BookClockWidget
	_w.theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	_w.size = Vector2(1080, 1920)
	Engine.get_main_loop().root.add_child(_w)
	track(_w)


func teardown() -> void:
	if is_instance_valid(_w):
		_w.queue_free()
	_w = null


func test_the_fill_nodes_are_authored() -> void:
	for path in [BookClockWidget.FILL_TRACK_PATH, BookClockWidget.FILL_CLIP_PATH,
			BookClockWidget.FILL_PATH, BookClockWidget.MOTIF_PATH,
			BookClockWidget.KNOCKOUT_PATH, BookClockWidget.PROGRESS_PATH]:
		assert_true(_w.get_node_or_null(path) != null, "the scene must author %s" % path)
	var clip := _w.get_node(BookClockWidget.FILL_CLIP_PATH) as Control
	assert_true(clip.clip_contents, "Clip cuts the fill and the white name to the progress")
	var fill := _w.get_node(BookClockWidget.FILL_PATH) as Panel
	assert_eq(fill.theme_type_variation, &"DayBannerFill", "the fill's variation")
	assert_eq(fill.clip_children, CanvasItem.CLIP_CHILDREN_AND_DRAW,
		"the motif is masked to the fill's rounded shape")
	var knockout := _w.get_node(BookClockWidget.KNOCKOUT_PATH) as Label
	assert_eq(knockout.theme_type_variation, &"DayBannerKnockoutLabel", "the white twin's variation")


## The driver is invisible: the banner is the bar the player sees.
func test_the_driver_is_hidden_and_mouse_transparent() -> void:
	var bar := _w.day_progress_bar()
	assert_true(bar != null, "the driver Range must exist")
	if bar:
		assert_false(bar.visible, "the driver never draws")
		assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and never eats a tap")


## Draw order: the dark name, then the fill over it, then the white name on
## the fill. That order is what makes the knockout invert at the edge.
func test_the_white_name_draws_over_the_fill_over_the_dark_name() -> void:
	var day_label := _w.get_node(BookClockWidget.DAY_LABEL_PATH)
	var track := _w.get_node(BookClockWidget.FILL_TRACK_PATH)
	assert_true(day_label.get_index() < track.get_index(), "the fill draws over the dark name")
	var fill := _w.get_node(BookClockWidget.FILL_PATH)
	var knockout := _w.get_node(BookClockWidget.KNOCKOUT_PATH)
	assert_true(fill.get_index() < knockout.get_index(), "the white name draws over the fill")


func test_the_clip_width_follows_the_progress() -> void:
	var bar := _w.day_progress_bar()
	var clip := _w.get_node(BookClockWidget.FILL_CLIP_PATH) as Control
	var fill := _w.get_node(BookClockWidget.FILL_PATH) as Control
	bar.value = 0.0
	_w.layout_banner_fill()
	assert_eq(clip.size.x, 0.0, "an unstarted day shows no fill")
	bar.value = 50.0
	_w.layout_banner_fill()
	assert_true(absf(clip.size.x - fill.size.x * 0.5) < 1.0,
		"half a day fills half the pill, got %f of %f" % [clip.size.x, fill.size.x])
	bar.value = 100.0
	_w.layout_banner_fill()
	assert_true(absf(clip.size.x - fill.size.x) < 1.0, "a finished day fills the pill")


## The fill sits inside the pill's rim, not over it, and the white name lies
## exactly over the dark one so the flip happens in place.
func test_the_fill_sits_inside_the_rim_and_the_names_align() -> void:
	var banner := _w.get_node(BookClockWidget.DAY_BANNER_PATH) as Control
	var box := banner.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(box != null, "the banner's stylebox is a StyleBoxFlat")
	if box == null:
		return
	_w.day_progress_bar().value = 100.0
	_w.layout_banner_fill()
	var fill := _w.get_node(BookClockWidget.FILL_PATH) as Control
	var rim := box.border_width_left + box.border_width_right
	assert_true(absf(fill.size.x - (banner.size.x - rim)) < 1.0,
		"the fill spans the pill inside its rim")
	var clip := _w.get_node(BookClockWidget.FILL_CLIP_PATH) as Control
	var day_label := _w.get_node(BookClockWidget.DAY_LABEL_PATH) as Control
	var knockout := _w.get_node(BookClockWidget.KNOCKOUT_PATH) as Control
	assert_true((knockout.global_position - day_label.global_position).length() < 1.0,
		"the white name sits exactly on the dark one")
	assert_eq(knockout.size, day_label.size, "and is the same size")
	assert_true(clip.global_position.x > banner.global_position.x,
		"the fill starts inside the rim, not under it")


func test_set_day_style_tints_and_picks_the_weekday_motif() -> void:
	var tint := DesignTokens.load_default().category_color("Akademis")
	_w.set_day_style(tint, 2)
	var fill := _w.get_node(BookClockWidget.FILL_PATH) as CanvasItem
	assert_eq(fill.self_modulate, tint, "the fill wears the day's colour")
	var motif := _w.get_node(BookClockWidget.MOTIF_PATH) as TextureRect
	assert_eq(_w.motif_textures.size(), 5, "one motif per school day")
	assert_eq(motif.texture, _w.motif_textures[2], "Rabu takes the third motif")
	_w.set_day_style(tint, 7)
	assert_eq(motif.texture, _w.motif_textures[2], "the weekday wraps")


func test_the_knockout_name_follows_the_banner_text() -> void:
	_w.set_day("Kamis")
	var knockout := _w.get_node(BookClockWidget.KNOCKOUT_PATH) as Label
	assert_eq(knockout.text, "Kamis", "both names change together")
	_w.set_banner("Akhir Pekan")
	assert_eq(knockout.text, "Akhir Pekan", "including the week's closing banner")


## The white name must read against every weekday's fill.
func test_white_reads_on_every_day_colour() -> void:
	var tokens := DesignTokens.load_default()
	for category in ["Olahraga", "Akademis", "Istirahat", "Libur", "SeniBudaya"]:
		# WCAG relative luminance is measured on linear light.
		var bg := tokens.category_color(category).srgb_to_linear()
		var fg := tokens.text_on_brand.srgb_to_linear()
		var l1 := maxf(fg.get_luminance(), bg.get_luminance()) + 0.05
		var l2 := minf(fg.get_luminance(), bg.get_luminance()) + 0.05
		assert_true(l1 / l2 >= 3.0,
			"white on %s is %.2f:1, below 3:1 for this large bold name" % [category, l1 / l2])
