@tool
extends McpTestSuite

func suite_name() -> String:
	return "design_tokens"

func test_default_resource_loads() -> void:
	var tokens := DesignTokens.load_default()
	assert_true(tokens != null, "design_tokens.tres must load")
	assert_true(tokens is DesignTokens, "must be a DesignTokens instance")

func test_brand_palette_matches_approved_values() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.brand_primary.to_html(false), "2e5bff", "brand_primary")
	assert_eq(tokens.surface_card.to_html(false), "ffffff", "surface_card")
	assert_eq(tokens.text_primary.to_html(false), "1e2436", "text_primary")

func test_category_color_lookup_covers_every_schedule_category() -> void:
	var tokens := DesignTokens.load_default()
	for category in ["Akademis", "Olahraga", "SeniBudaya", "Istirahat", "Libur"]:
		var c := tokens.category_color(category)
		assert_true(c.a > 0.0, "category_color must resolve for: " + category)

func test_category_color_falls_back_for_unknown_category() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.category_color("TidakAda"), tokens.text_secondary, "unknown category falls back")

func test_spacing_scale_is_monotonic() -> void:
	var tokens := DesignTokens.load_default()
	var scale := [tokens.space_xs, tokens.space_sm, tokens.space_md, tokens.space_lg, tokens.space_xl]
	for i in range(1, scale.size()):
		assert_true(scale[i] > scale[i - 1], "spacing step %d must exceed step %d" % [i, i - 1])

func test_font_size_scale_is_monotonic() -> void:
	var tokens := DesignTokens.load_default()
	var scale := [tokens.font_micro, tokens.font_caption, tokens.font_body_size, tokens.font_title, tokens.font_h2, tokens.font_h1, tokens.font_display_size]
	for i in range(1, scale.size()):
		assert_true(scale[i] > scale[i - 1], "font step %d must exceed step %d" % [i, i - 1])

func test_durations_are_positive_and_snappy() -> void:
	var tokens := DesignTokens.load_default()
	assert_true(tokens.dur_instant > 0.0 and tokens.dur_instant <= 0.12, "dur_instant")
	assert_true(tokens.dur_fast > 0.0 and tokens.dur_fast <= 0.25, "dur_fast")
	assert_true(tokens.dur_normal > 0.0 and tokens.dur_normal <= 0.45, "dur_normal")
