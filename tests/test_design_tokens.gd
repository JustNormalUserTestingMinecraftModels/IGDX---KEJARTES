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
	assert_eq(tokens.brand_primary.to_html(false), "7a4a2b", "brand_primary")
	assert_eq(tokens.surface_card.to_html(false), "fffdf8", "surface_card")
	assert_eq(tokens.text_primary.to_html(false), "3b2412", "text_primary")

func test_category_color_lookup_covers_every_schedule_category() -> void:
	var tokens := DesignTokens.load_default()
	for category in ["Akademis", "Olahraga", "SeniBudaya", "Istirahat", "Libur", "Wirausaha"]:
		var c := tokens.category_color(category)
		assert_true(c.a > 0.0, "category_color must resolve for: " + category)

func test_category_color_falls_back_for_unknown_category() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.category_color("TidakAda"), tokens.text_secondary, "unknown category falls back")

func test_wirausaha_color_is_distinct_from_other_categories() -> void:
	var tokens := DesignTokens.load_default()
	var wirausaha := tokens.category_color("Wirausaha")
	for other in ["Akademis", "Olahraga", "SeniBudaya", "Istirahat", "Libur"]:
		assert_true(wirausaha != tokens.category_color(other),
			"Wirausaha must be visually distinct from: " + other)

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


## 2026-09-28 UI depth pass: the palette pairs, verbatim from the spec.
func test_depth_palette_matches_the_spec() -> void:
	var tokens := DesignTokens.load_default()
	var want := {
		"accent_mint": "2ec99a", "accent_mint_lip": "178a68",
		"accent_sky": "5ea1e6", "accent_sky_lip": "3469b3",
		"accent_sunflower": "ffc93c", "accent_sunflower_lip": "c9801a",
		"accent_tomato": "e5553e", "accent_tomato_lip": "a3301e",
		"accent_tangerine": "f58a3c", "accent_tangerine_lip": "bd561a",
		"button_cream": "fff1dc", "button_cream_lip": "c9a57e",
	}
	for key in want:
		assert_eq((tokens.get(key) as Color).to_html(false), want[key], key)


## Every lip is darker than its face, so the slab reads as a shadow side.
func test_every_lip_is_darker_than_its_face() -> void:
	var tokens := DesignTokens.load_default()
	for base in ["accent_mint", "accent_sky", "accent_sunflower", "accent_tomato",
			"accent_tangerine", "button_cream"]:
		var face: Color = tokens.get(base)
		var lip: Color = tokens.get(base + "_lip")
		assert_true(lip.get_luminance() < face.get_luminance(), base + "'s lip is darker")


func test_depth_and_release_tokens() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.lip_height, 7, "lip_height")
	assert_true(absf(tokens.gloss_strength - 0.35) < 0.001, "gloss_strength")
	assert_true(absf(tokens.lipped_light_face_luminance - 0.7) < 0.001, "label-ink threshold")
	assert_eq(tokens.lipped_label_outline, 8, "label outline")
	assert_true(absf(tokens.release_pop_scale - 1.03) < 0.001, "release pop")
	assert_true(absf(tokens.release_pop_duration - 0.12) < 0.001, "release pop length")
