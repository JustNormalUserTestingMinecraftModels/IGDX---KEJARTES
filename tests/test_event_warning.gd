@tool
extends McpTestSuite

## The slide warning (2026-09-12 event-cards spec, section 2): its tokens and
## theme variations, its authored scene and motion, and SchoolDay's use of
## it for both minigames and random events.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "event_warning"


func test_warning_tokens_match_the_mockup() -> void:
	var t := DesignTokens.load_default()
	assert_eq(t.event_warning_bg, Color("9E8830"), "mockup_eventwarning.png's panel")
	assert_eq(t.event_warning_ink, Color("1D196E"), "the icon's outline navy")
	assert_eq(t.event_warning_caption_outline, 16)


func test_factory_builds_both_variations() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	assert_eq(theme.get_type_variation_base("EventWarningPanel"), &"Panel")
	var box := theme.get_stylebox("panel", "EventWarningPanel") as StyleBoxFlat
	assert_true(box != null, "the panel is a flat fill")
	if box != null:
		assert_eq(box.bg_color, t.event_warning_bg)
	assert_eq(theme.get_type_variation_base("EventWarningCaptionLabel"), &"Label")
	assert_eq(theme.get_color("font_color", "EventWarningCaptionLabel"), t.text_on_brand)
	assert_eq(theme.get_color("font_outline_color", "EventWarningCaptionLabel"), t.event_warning_ink)
	assert_eq(theme.get_constant("outline_size", "EventWarningCaptionLabel"),
		t.event_warning_caption_outline)
	assert_eq(theme.get_font_size("font_size", "EventWarningCaptionLabel"), t.font_display_size)


func test_the_bake_declares_both_variations() -> void:
	var baked := ResourceLoader.load(_THEME_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for variation in ["EventWarningPanel", "EventWarningCaptionLabel"]:
		assert_true(baked.get_type_list().has(variation),
			variation + " must be in the baked theme -- rebake")


## WCAG large-text floor (3:1). The caption is display-size, and its navy rim
## must hold the floor on its own.
func test_caption_reads_on_the_panel() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	var fill := _contrast(theme.get_color("font_color", "EventWarningCaptionLabel"),
		t.event_warning_bg)
	var rim := _contrast(t.event_warning_ink, t.event_warning_bg)
	assert_true(maxf(fill, rim) >= 3.0,
		"caption fill %.2f:1, rim %.2f:1 on the panel" % [fill, rim])
	assert_true(rim >= 3.0, "the navy rim alone must hold 3:1, got %.2f" % rim)


func _luminance(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# ── The scene and its motion ─────────────────────────────────────────────────

const _SCENE := "res://Scenes/SchoolSimulation/EventWarning.tscn"
const _SCRIPT := "res://Scripts/SchoolSimulation/EventWarning.gd"
const _ICON := "res://Assets/Images/SchoolDay/eventwarning_icon.png"


func _warning() -> Control:
	var w: Control = (load(_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(w)
	track(w)
	return w


func test_scene_is_the_authored_slide_panel() -> void:
	var w := _warning()
	var panel := w.get_node_or_null("Panel") as Panel
	assert_true(panel != null, "the panel that slides")
	if panel == null:
		return
	assert_eq(panel.theme_type_variation, &"EventWarningPanel")
	assert_eq(panel.anchor_right, 1.0, "the panel covers the screen")
	assert_eq(panel.anchor_bottom, 1.0)
	var icon := w.get_node_or_null("Panel/Center/Content/Icon") as TextureRect
	var caption := w.get_node_or_null("Panel/Center/Content/Caption") as Label
	assert_true(icon != null and caption != null, "icon over caption")
	if caption != null:
		assert_eq(caption.theme_type_variation, &"EventWarningCaptionLabel")
	assert_eq(w.mouse_filter, Control.MOUSE_FILTER_STOP, "taps are swallowed while it runs")
	for retired in ["Background", "TopBar", "BottomBar", "Center"]:
		assert_true(w.get_node_or_null(retired) == null,
			retired + " belonged to the old hazard-stripe warning")


func test_icon_is_the_cropped_art() -> void:
	var tex := load(_ICON) as Texture2D
	assert_true(tex != null, "the cropped art is imported")
	if tex == null:
		return
	assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(755, 751),
		"cropped to the art plus a 16 px pad, not the 1080x1920 canvas")
	var w := _warning()
	assert_eq((w.get("icon_texture") as Texture2D).resource_path, _ICON)
	var icon := w.get_node("Panel/Center/Content/Icon") as TextureRect
	assert_eq(icon.texture.resource_path, _ICON)


func test_panel_passes_right_to_left() -> void:
	var script = load(_SCRIPT)
	assert_eq(script.panel_x(&"enter", 1080.0), 1080.0, "enters from the right edge")
	assert_eq(script.panel_x(&"rest", 1080.0), 0.0)
	assert_eq(script.panel_x(&"exit", 1080.0), -1080.0, "leaves through the left edge")


func test_timings_match_the_spec() -> void:
	var w := _warning()
	assert_eq(w.get("slide_in_duration"), 0.35)
	assert_eq(w.get("hold_duration"), 1.1)
	assert_eq(w.get("slide_out_duration"), 0.35)


func test_one_cue_and_nothing_built() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_contains(src, 'play_sfx(&"event_announce")', "one cue for every warning")
	assert_false(src.contains("popup_open"), "SchoolDay's old second cue is gone")
	assert_false(src.contains(".new("), "the scene is fully authored")
	assert_false(src.contains("⚠"), "no emoji fallback")


# ── SchoolDay uses it for everything ─────────────────────────────────────────

const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"


func test_school_day_sends_every_interruption_through_the_slide() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	assert_false(src.contains("_show_event_announcement"), "one warning for both paths")
	assert_false(src.contains("event_announcement_scene"), "the announcement export is gone")
	assert_contains(src, "func _show_event_warning(caption: String)")
	for caption in ["KEGIATAN AKADEMIS!", "KEGIATAN OLAHRAGA!", "KEGIATAN SENI BUDAYA!"]:
		assert_contains(src, '_show_event_warning("%s")' % caption)
	var start := src.find("func _show_event_warning")
	var body := src.substr(start, src.find("\nfunc ", start + 1) - start)
	assert_false(body.contains("popup_open"), "the warning plays its own single cue")


## Scoped to the three interactive event titles, which become the warning's
## caption. SchoolDay's mid-day pill code still uses these glyphs as internal
## markers that it strips before display; that is existing debt outside this
## change, logged for the final review.
func test_event_titles_carry_no_emoji() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	for title in ["Les Tambahan Akademis", "Latihan Olahraga Ekstra", "Workshop Sanggar Seni"]:
		assert_contains(src, '"%s"' % title, "the event title %s is still there" % title)
	for tagged in ["Les Tambahan Akademis 📚", "Latihan Olahraga Ekstra ⚽", "Workshop Sanggar Seni 🎨"]:
		assert_false(src.contains(tagged),
			"event titles reach the warning's caption; \"%s\" still carries emoji iconography" % tagged)


func test_school_day_scene_no_longer_wires_the_announcement() -> void:
	var scene := FileAccess.get_file_as_string("res://Scenes/SchoolSimulation/SchoolDay.tscn")
	assert_false(scene.contains("EventAnnouncement.tscn"))
