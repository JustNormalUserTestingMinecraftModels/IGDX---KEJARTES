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
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
