@tool
## Guards that the two typography fonts are imported and usable.
##
## Godot cannot `load()` a font that has no `.import` sidecar, and a
## missing sidecar fails silently at bake time -- ThemeFactory's
## `if tokens.font_display != null` guard just skips the assignment and
## every heading quietly falls back to the body font. This suite turns
## that silent fallback into a red test.
extends McpTestSuite

const DISPLAY_PATH := "res://Assets/Fonts/Catfiles.otf"
const BODY_PATH := "res://Assets/Fonts/OpenSans-Medium.ttf"

## Indonesian UI copy plus the digits and punctuation the stat readouts
## use. Every glyph here must exist in both faces or text renders as
## tofu boxes in the shipped build.
const PROBE := "Jadwal Minggu Ini: 12/65 (Seni Budaya) - Rp1.000"


func suite_name() -> String:
	return "fonts_present"


func test_display_font_loads() -> void:
	var f := load(DISPLAY_PATH)
	assert_true(f != null, "Catfiles.otf must be imported (run a filesystem scan)")
	assert_true(f is FontFile, "Catfiles.otf must import as a FontFile")


func test_body_font_loads() -> void:
	var f := load(BODY_PATH)
	assert_true(f != null, "OpenSans-Medium.ttf must be imported")
	assert_true(f is FontFile, "OpenSans-Medium.ttf must import as a FontFile")


func test_display_font_covers_the_ui_alphabet() -> void:
	var f: FontFile = load(DISPLAY_PATH)
	assert_true(f != null, "font must load before glyph coverage can be checked")
	var missing := _missing_glyphs(f, PROBE)
	assert_eq(missing, "", "Catfiles is missing glyphs: %s" % missing)


func test_body_font_covers_the_ui_alphabet() -> void:
	var f: FontFile = load(BODY_PATH)
	assert_true(f != null, "font must load before glyph coverage can be checked")
	var missing := _missing_glyphs(f, PROBE)
	assert_eq(missing, "", "OpenSans-Medium is missing glyphs: %s" % missing)


## Scans a font for missing glyphs in the given probe string.
## Returns a string containing all missing glyphs (excluding spaces).
## Safe to call with a null font (e.g. after a failed load): returns ""
## immediately so a load failure fails cleanly on the assert_true above it
## instead of crashing here on a null dereference -- this framework's
## assert_true does not halt execution on failure.
func _missing_glyphs(font: FontFile, probe: String) -> String:
	if font == null:
		return ""
	var missing := ""
	for i in probe.length():
		var c := probe[i]
		if c == " ":
			continue
		if not font.has_char(c.unicode_at(0)):
			missing += c
	return missing
