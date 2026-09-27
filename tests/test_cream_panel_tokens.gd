@tool
extends McpTestSuiteCompat

## The four tokens behind AturJadwal's cream activity row.
##
## The row itself and its Preview* variations were retired on 2026-09-24,
## when the picker was rebuilt as a tile grid (ActivityTile, Picker*
## variations). preview_pill_fill still feeds the StatBar light track;
## the other three have no reader now (docs/superpowers/DEBT.md).
##
## Before this pass a row nested four surfaces: the olive card, a
## #6B4B33 slab, a #4A3728 inset pill, and the category bar. The mentor
## review called that cluttered. These tokens collapse it to a cream
## sheet with one recessed track.

const CREAM_SHEET := Color("FFFDF8")
const TRACK := Color("E6DAC6")
## Darkened from #EFE0CB on 2026-09-10: once the card texture was
## lightened toward the reference the old value was within a hair of the
## sheet and the hairlines vanished entirely.
const SEPARATOR := Color("DCCFBB")
const PRESSED := Color("F0E2CD")


func suite_name() -> String:
	return "cream_panel_tokens"


func test_row_and_track_are_cream() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	assert_eq(tokens.preview_row_fill, CREAM_SHEET,
		"preview_row_fill should be the cream sheet, not the old brown slab")
	assert_eq(tokens.preview_pill_fill, TRACK,
		"preview_pill_fill should be the light recessed track")


func test_the_two_new_tokens_exist_and_are_set() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	assert_eq(tokens.preview_row_separator, SEPARATOR,
		"preview_row_separator missing or wrong")
	assert_eq(tokens.preview_row_pressed_fill, PRESSED,
		"preview_row_pressed_fill missing or wrong")


## The press recess must be darker than the resting sheet or the row
## appears to rise on touch instead of sinking.
func test_pressed_fill_is_darker_than_the_resting_sheet() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var resting: float = tokens.preview_row_fill.get_luminance()
	var pressed: float = tokens.preview_row_pressed_fill.get_luminance()
	assert_true(pressed < resting,
		"pressed fill (%f) must be darker than resting (%f)" % [pressed, resting])
