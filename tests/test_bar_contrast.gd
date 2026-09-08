@tool
extends McpTestSuite

## WCAG contrast floor for every progress-bar fill against its track.
##
## This test exists because of a measured failure, not a hypothetical
## one. Before 2026-09-08 the DaySummary energy bar was #6d60c0 on a
## #585858 track -- 1.36:1, which is not a dim bar but an invisible one --
## and Olahraga was 2.55:1. Both shipped green for months because nothing
## checked.
##
## The floor is 3.0. The values chosen in the warm-UI pass all clear
## 3.5, so there is deliberate headroom for tuning.

const FLOOR := 3.0


func suite_name() -> String:
	return "bar_contrast"


## sRGB relative luminance, per WCAG 2.x. Godot's Color components are
## already sRGB-encoded 0..1, so they feed this directly.
static func _relative_luminance(c: Color) -> float:
	var out := 0.0
	var weights := [0.2126, 0.7152, 0.0722]
	var channels := [c.r, c.g, c.b]
	for i in 3:
		var v: float = channels[i]
		var lin: float = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += weights[i] * lin
	return out


static func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var hi: float = max(la, lb)
	var lo: float = min(la, lb)
	return (hi + 0.05) / (lo + 0.05)


func test_every_on_dark_accent_clears_the_floor() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	for category in ["Akademis", "Olahraga", "SeniBudaya",
			"Istirahat", "Libur", "Wirausaha"]:
		var fill := tokens.category_color_on_dark(category)
		var ratio := _contrast(fill, tokens.day_bar_track)
		assert_true(ratio >= FLOOR,
			"%s on-dark is %s against day_bar_track -- %.2f:1, floor is %.1f"
				% [category, fill.to_html(false), ratio, FLOOR])


func test_the_two_needs_fills_clear_the_floor() -> void:
	var tokens := DesignTokens.load_default()
	for spec in [["energy", tokens.day_energy_fill],
			["mood", tokens.day_mood_fill]]:
		var ratio := _contrast(spec[1], tokens.day_bar_track)
		assert_true(ratio >= FLOOR,
			"%s fill is %.2f:1 against day_bar_track, floor is %.1f"
				% [spec[0], ratio, FLOOR])


func test_light_track_accents_clear_the_floor_too() -> void:
	# The light StatBar track is the other half of the pair. If someone
	# "simplifies" by pointing both grounds at one token, this catches it.
	var tokens := DesignTokens.load_default()
	for category in ["Akademis", "Olahraga", "SeniBudaya",
			"Istirahat", "Libur", "Wirausaha"]:
		var fill := tokens.category_color(category)
		var ratio := _contrast(fill, tokens.surface_sunken)
		assert_true(ratio >= FLOOR,
			"%s on the light StatBar track is %.2f:1, floor is %.1f"
				% [category, ratio, FLOOR])


func test_libur_and_currency_gold_are_distinguishable() -> void:
	# They were the same yellow until 2026-09-08 -- #ffd333 and #ffc93c --
	# so a Libur bar and a coin count could not be told apart by hue.
	var tokens := DesignTokens.load_default()
	var d := absf(tokens.cat_libur.h - tokens.currency_gold.h) \
		+ absf(tokens.cat_libur.v - tokens.currency_gold.v)
	assert_true(d > 0.08,
		"cat_libur %s and currency_gold %s are too close in hue/value"
			% [tokens.cat_libur.to_html(false), tokens.currency_gold.to_html(false)])
