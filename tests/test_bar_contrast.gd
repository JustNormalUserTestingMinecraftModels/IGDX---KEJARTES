@tool
extends McpTestSuiteCompat

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


func test_light_chrome_accents_stay_legible() -> void:
	# surface_sunken is no longer any progress bar's track -- StatBar and
	# its six siblings moved to the dark stat_bar_track on 2026-09-09. But
	# the light (non-"_on_dark") cat_* accents are still used directly on
	# sunken panels as schedule pills and icons, so that relationship is
	# still real and still worth guarding.
	var tokens := DesignTokens.load_default()
	for category in ["Akademis", "Olahraga", "SeniBudaya",
			"Istirahat", "Libur", "Wirausaha"]:
		var fill := tokens.category_color(category)
		var ratio := _contrast(fill, tokens.surface_sunken)
		assert_true(ratio >= FLOOR,
			"%s on light chrome (surface_sunken) is %.2f:1, floor is %.1f"
				% [category, ratio, FLOOR])


## Every stat's fill tile, keyed by the category string StatBar carries.
## One file per stat since 2026-09-09, when each gained its own batik
## motif -- they were a single shared capsule before that.
const _FILL_ART := {
	"Akademis": "res://Assets/Images/UI/BarFill/fill_akademis.png",
	"SeniBudaya": "res://Assets/Images/UI/BarFill/fill_senibudaya.png",
	"Olahraga": "res://Assets/Images/UI/BarFill/fill_olahraga.png",
	"Wirausaha": "res://Assets/Images/UI/BarFill/fill_wirausaha.png",
	"Istirahat": "res://Assets/Images/UI/BarFill/fill_istirahat.png",
	"Libur": "res://Assets/Images/UI/BarFill/fill_libur.png",
	"Mood": "res://Assets/Images/UI/BarFill/fill_mood.png",
	"Energy": "res://Assets/Images/UI/BarFill/fill_energi.png",
}

## The region every tile is cropped to, matching ThemeFactory.
const _FILL_REGION := Rect2i(60, 66, 148, 124)

## How dark a fill texture may be before it starts eating the accent. At
## 0.90 a token measured at the floor still renders within a hair of it.
const _MIN_FILL_BRIGHTNESS := 0.90


## Mean luminance of a fill texture's cropped region, 0..1 -- the factor a
## StyleBoxTexture's modulate_color is multiplied by before it reaches the
## screen.
func _fill_brightness(path: String, region: Rect2i) -> float:
	var texture: Texture2D = load(path)
	var image := texture.get_image()
	var total := 0.0
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return total / maxf(count, 1)


## Measures the fill as it is DRAWN, not as it is declared.
##
## This test used to read cat_*_on_dark straight off the tokens and call
## it the fill colour. It is not: both fill styleboxes are textures, and
## modulate_color multiplies the accent through the art. Those textures
## were mid-grey (mean luminance ~0.53), so every bar rendered at about
## half the token's brightness and measured 1.3-1.9:1 against the track --
## while this test read 3.6-5.9:1 and passed. The user saw dark bars a
## green suite said were fine.
##
## So the brightness of each texture is measured from the PNG and folded
## into the colour before the ratio is taken, and the textures themselves
## are held above a floor so a future art pass cannot re-open the gap by
## darkening them back down.
## Each stat is now measured through ITS OWN tile, because each tile
## carries a different motif and so a different amount of ink. Kawung
## (istirahat) is the heaviest by some way -- four overlapping circles per
## period against nitik's two small squares -- and it is the one that will
## fail first if the motifs are ever redrawn darker.
func test_stat_bar_on_dark_accents_clear_the_floor_as_rendered() -> void:
	var tokens := DesignTokens.load_default()
	for category in _FILL_ART:
		var path: String = _FILL_ART[category]
		assert_true(ResourceLoader.exists(path),
			"%s has no fill tile at %s" % [category, path])

		var brightness := _fill_brightness(path, _FILL_REGION)
		assert_true(brightness >= _MIN_FILL_BRIGHTNESS,
			"%s is %.3f bright; a modulate through it cuts the accent to that "
				% [path.get_file(), brightness]
				+ "fraction (floor %.2f)" % _MIN_FILL_BRIGHTNESS)

		var token := tokens.category_color_on_dark(category)
		var rendered := Color(token.r * brightness, token.g * brightness,
			token.b * brightness, 1.0)
		var ratio := _contrast(rendered, tokens.stat_bar_track)
		assert_true(ratio >= FLOOR,
			"%s renders as %s through %s -- %.2f:1 against stat_bar_track, floor is %.1f"
				% [category, rendered.to_html(false), path.get_file(), ratio, FLOOR])


func test_libur_and_currency_gold_are_distinguishable() -> void:
	# They were the same yellow until 2026-09-08 -- #ffd333 and #ffc93c --
	# so a Libur bar and a coin count could not be told apart by hue.
	var tokens := DesignTokens.load_default()
	var d := absf(tokens.cat_libur.h - tokens.currency_gold.h) \
		+ absf(tokens.cat_libur.v - tokens.currency_gold.v)
	assert_true(d > 0.08,
		"cat_libur %s and currency_gold %s are too close in hue/value"
			% [tokens.cat_libur.to_html(false), tokens.currency_gold.to_html(false)])
