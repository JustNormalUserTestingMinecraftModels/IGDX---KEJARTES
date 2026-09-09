@tool
extends McpTestSuite

## The four tokens behind AturJadwal's cream activity row.
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


## A row draws nothing at rest. Painting a fill -- any fill -- makes the
## row read as a box on the card, which is what the mentor objected to;
## recolouring those boxes cream was the first attempt and it still looked
## like five stacked cards. The rows ARE the sheet, divided by hairlines.
func test_preview_row_draws_nothing_at_rest() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("panel", "PreviewRow")
	assert_true(box is StyleBoxEmpty,
		"PreviewRow must draw nothing, or every row reads as its own box")


func test_pressed_variation_exists_and_differs_from_resting() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	# The resting row draws nothing at all, so there is no resting colour to
	# differ from -- the press IS the appearance of a surface.
	assert_true(theme.get_stylebox("panel", "PreviewRow") is StyleBoxEmpty,
		"the resting row draws nothing")
	var pressed := theme.get_stylebox("panel", "PreviewRowPressed") as StyleBoxFlat
	assert_not_null(pressed, "PreviewRowPressed variation missing")
	assert_eq(pressed.bg_color, PRESSED, "pressed should use the recess token")


func test_separator_variation_is_the_hairline() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("separator", "PreviewRowSeparator") as StyleBoxLine
	assert_not_null(box, "PreviewRowSeparator should be a StyleBoxLine")
	assert_eq(box.color, SEPARATOR, "separator should use the hairline token")
	assert_eq(box.thickness, 1, "separator should be 1px")


## Source-text scan, following the established pattern for UI that
## cannot be instantiated headlessly. Five rows need four separators.
func test_the_rows_are_divided_by_hairlines() -> void:
	var path := "res://Scenes/AturJadwal/atur_jadwal.tscn"
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "could not open " + path)
	var src := f.get_as_text()
	f.close()
	assert_contains(src, "PreviewRowSeparator",
		"the activity rows should be divided by the hairline variation")
	var count := src.count("PreviewRowSeparator")
	assert_eq(count, 4, "five rows need exactly four separators, found %d" % count)


## Panel has no pressed state, so the sink is driven from the Button that
## wraps it. Signal wiring stays ungated by Engine.is_editor_hint so this
## can be exercised without instantiating the scene.
func test_the_row_wires_its_own_press_state() -> void:
	var f := FileAccess.open("res://Scripts/AturJadwal/ActivityRow.gd", FileAccess.READ)
	assert_not_null(f, "could not open ActivityRow.gd")
	var src := f.get_as_text()
	f.close()
	assert_contains(src, "button_down.connect",
		"Panel has no pressed state; the row must drive it from the Button")
	assert_contains(src, "button_up.connect",
		"a press with no release leaves the row stuck sunken")
	assert_contains(src, "PreviewRowPressed",
		"the press should swap to the baked pressed variation")


## The behavioural half: pressing must actually change the container's
## variation, and releasing must put it back.
func test_pressing_the_row_swaps_the_container_variation() -> void:
	var scene: PackedScene = load("res://Scenes/AturJadwal/ActivityRow.tscn")
	var row := scene.instantiate() as ActivityRow
	Engine.get_main_loop().root.add_child(row)
	track(row)
	var container := row.get_node("Container") as Panel
	assert_eq(container.theme_type_variation, &"PreviewRow",
		"a resting row wears the plain cream variation")
	row.button_down.emit()
	assert_eq(container.theme_type_variation, &"PreviewRowPressed",
		"holding the row must sink it")
	row.button_up.emit()
	assert_eq(container.theme_type_variation, &"PreviewRow",
		"releasing must lift it back, or the row stays stuck sunken")
	row.queue_free()
