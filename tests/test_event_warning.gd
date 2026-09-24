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


## WCAG large-text floor (3:1). The caption's cream fill and its navy rim
## must each hold the 3:1 large-text floor on the mustard panel,
## independently of one another.
func test_caption_reads_on_the_panel() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	var fill := _contrast(theme.get_color("font_color", "EventWarningCaptionLabel"),
		t.event_warning_bg)
	var rim := _contrast(t.event_warning_ink, t.event_warning_bg)
	assert_true(fill >= 3.0, "the cream fill alone must hold 3:1, got %.2f" % fill)
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
	var caption := w.get_node_or_null("Panel/Center/Content/Band/Rows/Caption") as Label
	assert_true(icon != null and caption != null, "icon over the band's caption")
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


## Scoped to play_warning's own body: _ready also calls panel_x(&"enter", ...)
## to pre-position the panel, so an unscoped scan of the whole file would
## still pass even if play_warning stopped using the authored motion calls.
func test_play_warning_runs_the_authored_motion() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var start := src.find("func play_warning")
	assert_true(start >= 0, "play_warning must exist")
	var next_func := src.find("\nfunc ", start + 1)
	var body := src.substr(start, (src.length() - start) if next_func == -1 else (next_func - start))
	for needle in ['panel_x(&"enter"', 'panel_x(&"rest"', 'panel_x(&"exit"',
		"Juice.pop_in(icon)", "Juice.fade_in(caption)"]:
		assert_contains(body, needle, "play_warning must still drive the authored motion")


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
	assert_contains(src,
		'func _show_event_warning(caption: String, category: String = "", mode: String = "")')
	for call in [['KEGIATAN AKADEMIS!', 'Akademis', 'MINIGAME'],
			['KEGIATAN OLAHRAGA!', 'Olahraga', 'MINIGAME'],
			['KEGIATAN SENI BUDAYA!', 'SeniBudaya', 'MINIGAME'],
			['Kejutan Nasi Kotak Orang Tua!', 'Sosial', 'KABAR'],
			['Hujan Deras & Jalanan Licin!', 'Cuaca', 'KABAR']]:
		assert_contains(src, '_show_event_warning("%s", "%s", "%s")' % call,
			"each interruption names its category and mode")
	assert_contains(src, "await _show_event_warning(title, category, mode)",
		"the choice events mark themselves PILIHAN")
	assert_contains(src, "EventDialogueCatalog.MODE_CHOICE", "the mode comes from the catalog")
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


# ── The 2026-09-24 news-announcement redesign (liveliness pass, layer 7) ─────

func test_the_band_is_authored() -> void:
	var w := _warning()
	var band := w.get_node_or_null("Panel/Center/Content/Band") as PanelContainer
	assert_true(band != null, "the caution band")
	if band:
		assert_eq(band.theme_type_variation, &"EventBandPanel", "the band's variation")
		assert_true(band.custom_minimum_size.x > 1080.0, "the band runs off both screen edges")
	for path in ["Panel/Center/Content/Band/Rows/TapeTop/Stripes",
			"Panel/Center/Content/Band/Rows/TapeBottom/Stripes"]:
		var tape := w.get_node_or_null(path) as TextureRect
		assert_true(tape != null, "the band carries %s" % path)
		if tape:
			assert_eq(tape.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED, "the stripes tile")
			assert_true(tape.get_parent().clip_contents, "and scroll inside a clipped strip")
	var marker := w.get_node_or_null("Panel/Center/Content/Band/Rows/Marker") as Label
	assert_true(marker != null, "the KATEGORI \u00b7 MODE marker")
	if marker:
		assert_eq(marker.theme_type_variation, &"EventBandMarkerLabel", "the marker's variation")
	var gradient := w.get_node_or_null("Panel/Gradient") as TextureRect
	assert_true(gradient != null and gradient.texture is GradientTexture2D, "the gradient ground")
	if gradient:
		assert_true(gradient.texture.resource_local_to_scene, "each notice recolours its own copy")
		assert_true(gradient.get_index() < w.get_node("Panel/Center").get_index(),
			"the gradient draws behind the content")


func test_the_marker_names_category_and_mode() -> void:
	var script = load(_SCRIPT)
	assert_eq(script.marker_text("Akademis", "PILIHAN"), "AKADEMIS \u00b7 PILIHAN")
	assert_eq(script.marker_text("SeniBudaya", "MINIGAME"), "SENI BUDAYA \u00b7 MINIGAME")
	assert_eq(script.marker_text("Cuaca", "KABAR"), "CUACA \u00b7 KABAR")
	assert_eq(script.marker_text("", "KABAR"), "KABAR", "a missing half drops cleanly")
	assert_eq(script.marker_text("", ""), "", "nothing to say, no marker")


## Skill categories take their own colour; Cuaca and Sosial must not borrow a
## skill's colour (purple and teal belong to Istirahat and Wirausaha too).
func test_the_gradient_follows_the_category_palette() -> void:
	var script = load(_SCRIPT)
	var t := DesignTokens.load_default()
	for category in ["Akademis", "Olahraga", "SeniBudaya"]:
		var stops: Array = script.gradient_colors(category, t)
		assert_eq(stops.size(), 3, "%s has deep, mid and light stops" % category)
		assert_eq(stops[1], t.category_color(category), "%s's own colour" % category)
		assert_eq(stops[2], t.category_color_on_dark(category), "%s's on-dark variant" % category)
		assert_true(stops[0].get_luminance() < stops[1].get_luminance(), "the deep stop is darker")
	var skill_colours := []
	for c in ["Akademis", "Olahraga", "SeniBudaya", "Istirahat", "Wirausaha"]:
		skill_colours.append(t.category_color(c))
	for category in ["Cuaca", "Sosial"]:
		var stops: Array = script.gradient_colors(category, t)
		assert_eq(stops.size(), 3, "%s is tinted" % category)
		assert_false(stops[1] in skill_colours, "%s must not borrow a skill colour" % category)
	assert_eq(script.gradient_colors("", t).size(), 0, "no category keeps the flat panel")


## The marker is set in the body face and must carry the "\u00b7"; the
## caption is the display face and must carry every title's letters.
func test_the_band_text_is_covered_by_its_faces() -> void:
	var t := DesignTokens.load_default()
	var body: Font = t.font_body_bold if t.font_body_bold != null else t.font_body
	var script = load(_SCRIPT)
	for m in [script.marker_text("SeniBudaya", "PILIHAN"), script.marker_text("Cuaca", "KABAR"),
			script.marker_text("Olahraga", "MINIGAME"), script.marker_text("Sosial", "KABAR")]:
		for i in m.length():
			assert_true(body.has_char(m.unicode_at(i)), "'%s' of the marker is in the body face" % m[i])


func test_the_new_motion_honours_reduce_motion() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var start := src.find("func play_warning")
	var next_func := src.find("\nfunc ", start + 1)
	# play_warning is the file's last function, so there may be no next one.
	var body := src.substr(start, (src.length() - start) if next_func == -1 else (next_func - start))
	assert_contains(body, "GameSettings.reduce_motion", "the typewriter and wiggle skip under reduce_motion")
	assert_contains(body, 'tween_property(caption, "visible_ratio"', "the title types in")
	assert_contains(body, 'tween_property(band, "scale:x"', "the band rolls in")
	# Review 2026-09-24: the band is a container child, and a sort resets its
	# scale, so the roll must start after the slide, not before it.
	assert_true(body.find("band.scale.x = 0.0") > body.find("await slide_in.finished"),
		"the roll starts from zero only once the panel has landed")
	assert_contains(src, "Engine.is_editor_hint() or GameSettings.reduce_motion",
		"the stripes never scroll in the editor or under reduce_motion")
