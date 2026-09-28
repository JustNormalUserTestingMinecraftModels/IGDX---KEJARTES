@tool
extends McpTestSuiteCompat

## Proves the shared minigame UI kit variations ThemeFactory._build_minigame_kit()
## registers (spec 2026-09-28 minigame-polish-part-1, section 4.1).
## Build-based: the theme is constructed in process once per run, so this never
## depends on the baked kejartes_theme.tres (test_theme_factory pins the bake).
## Affects nothing at runtime. Must be @tool, and no test here may be a coroutine.

var _tokens: DesignTokens
var _theme: Theme


func suite_name() -> String:
	return "minigame_kit"


## One theme build for the whole suite.
func suite_setup(_ctx: Dictionary) -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


## `variation`'s `item` stylebox as a StyleBoxFlat, or null. Asserting
## has_stylebox first matters: Theme.get_stylebox() returns the engine's
## fallback box, never null, for a type that does not exist.
func _flat(item: String, variation: String) -> StyleBoxFlat:
	assert_true(_theme.has_stylebox(item, variation),
		"%s must define stylebox: %s" % [variation, item])
	return _theme.get_stylebox(item, variation) as StyleBoxFlat


func test_minigame_card_is_a_wood_frame() -> void:
	var frame: StyleBoxFlat = _flat("panel", "MinigameCard")
	if frame == null:
		return
	assert_true(frame.bg_color.is_equal_approx(_tokens.brand_primary),
		"frame is filled with the brand wood colour")
	assert_gt(frame.border_width_top, 0, "the frame has a visible rim")
	assert_true(frame.border_color.is_equal_approx(_tokens.outline_card),
		"the rim is cream, so the card pops on the bright wood (spec section 3)")
	assert_gt(frame.shadow_size, 0, "the card is lifted off the wood by a shadow")


func test_minigame_card_inner_is_cream() -> void:
	var inner: StyleBoxFlat = _flat("panel", "MinigameCardInner")
	if inner == null:
		return
	assert_true(inner.bg_color.is_equal_approx(_tokens.surface_card),
		"inner face is the cream card colour")


func test_minigame_image_plate_is_a_recessed_slot() -> void:
	var plate: StyleBoxFlat = _flat("panel", "MinigameImagePlate")
	if plate == null:
		return
	assert_true(plate.bg_color.is_equal_approx(_tokens.preview_pill_fill),
		"plate uses the recessed slot colour")
