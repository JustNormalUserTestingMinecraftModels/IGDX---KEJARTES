@tool
extends McpTestSuiteCompat

## Proves the shared minigame UI kit variations ThemeFactory._build_minigame_kit()
## registers (spec 2026-09-28 minigame-polish-part-1, section 4.1).
## Build-based: the theme is constructed in process once per run, so this never
## depends on the baked kejartes_theme.tres (test_theme_factory pins the bake).
## Affects nothing at runtime. Must be @tool, and no test here may be a coroutine.

## The answer button's five styleboxes: the spec's four plus a derived focus.
const ANSWER_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
## Slack, px, for padding built from int tokens.
const PAD_TOLERANCE := 1.0

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


func test_answer_button_has_all_five_states() -> void:
	for state: String in ANSWER_STATES:
		assert_true(_theme.has_stylebox(state, "MinigameAnswerButton"),
			"MinigameAnswerButton must define stylebox: " + state)


func test_answer_button_is_brand_filled_and_touch_sized() -> void:
	var resting: StyleBoxFlat = _flat("normal", "MinigameAnswerButton")
	if resting == null:
		return
	assert_true(resting.bg_color.is_equal_approx(_tokens.brand_primary),
		"filled with the brand colour")
	assert_gt(resting.border_width_top, 0, "has the light-lit top edge as a border")
	var pad_v: float = resting.content_margin_top + resting.content_margin_bottom
	assert_true(pad_v >= float(_tokens.btn_pad_v_s) * 2.0 - PAD_TOLERANCE,
		"vertical padding matches the small button step")


func test_answer_button_uses_the_display_font() -> void:
	if _tokens.font_display == null:
		return
	assert_eq(_theme.get_font("font", "MinigameAnswerButton"), _tokens.font_display,
		"answer text is set in the display face")


## Spec 4.1: a hard brandD drop shadow, which sinks while pressed.
func test_answer_button_casts_a_hard_brand_dark_shadow() -> void:
	var resting: StyleBoxFlat = _flat("normal", "MinigameAnswerButton")
	var pressed: StyleBoxFlat = _flat("pressed", "MinigameAnswerButton")
	if resting == null or pressed == null:
		return
	assert_true(resting.shadow_color.is_equal_approx(_tokens.brand_primary_dark),
		"the shadow is the dark brand tone")
	assert_eq(resting.shadow_size, ThemeFactory.MINIGAME_HARD_SHADOW_BLUR,
		"a hard edge: the least blur StyleBoxFlat still draws")
	assert_eq(resting.shadow_offset, _tokens.shadow_offset, "dropped by the house offset")
	assert_true(pressed.shadow_offset.y < resting.shadow_offset.y, "pressing sinks the button")


## Not in the spec; derived like _add_button_variation's disabled state.
func test_answer_button_disabled_state_reads_as_disabled() -> void:
	var resting: StyleBoxFlat = _flat("normal", "MinigameAnswerButton")
	var disabled: StyleBoxFlat = _flat("disabled", "MinigameAnswerButton")
	if resting == null or disabled == null:
		return
	assert_false(disabled.bg_color.is_equal_approx(resting.bg_color),
		"a disabled answer is visibly different from a live one")
	assert_eq(disabled.shadow_size, 0, "a disabled button lies flat")
	var disabled_text: Color = _theme.get_color("font_disabled_color", "MinigameAnswerButton")
	assert_true(disabled_text.is_equal_approx(_tokens.text_disabled), "and its text greys out")


## Godot draws focus OVER the current state, so it must be a rim, not a fill.
func test_answer_button_focus_is_a_gold_rim_overlay() -> void:
	var focus: StyleBoxFlat = _flat("focus", "MinigameAnswerButton")
	if focus == null:
		return
	assert_false(focus.draw_center, "focus draws no fill over the state beneath it")
	assert_true(focus.border_color.is_equal_approx(_tokens.currency_gold),
		"a gold rim reads on the brand wood fill")
