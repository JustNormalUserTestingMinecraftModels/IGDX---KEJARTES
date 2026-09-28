@tool
extends McpTestSuite

## Press feel (2026-09-28 UI depth pass): a button on a lipped face (LippedBox) sinks
## through its own pressed stylebox, so UIPolish must not also shrink it --
## it pops on release instead. Every other button keeps the shrink. Only the
## main-action roles tick the phone's motor. PressFeel holds both answers,
## pure; UIPolish is an autoload the editor never runs, so its wiring is
## checked by source.
##
## Must be @tool; no test here may be a coroutine.

const UIPOLISH_PATH := "res://Scripts/UI/UIPolish.gd"
const JUICE_PATH := "res://Scripts/Design/Juice.gd"

var _theme: Theme


func suite_name() -> String:
	return "press_feel"


func setup() -> void:
	_theme = ThemeFactory.build(DesignTokens.load_default())


func test_lipped_buttons_sink() -> void:
	for name in ["PrimaryButton", "SecondaryButton", "BookHeroButton", "FilterChipButton"]:
		assert_true(PressFeel.sinks(_theme.get_stylebox("normal", name)), name + " sinks")


func test_lipless_buttons_shrink() -> void:
	assert_false(PressFeel.sinks(_theme.get_stylebox("normal", "ShopHubTile")),
		"an empty tile has no lip to sink onto")
	assert_false(PressFeel.sinks(_theme.get_stylebox("normal", "EventSelectCard")),
		"a flat card shrinks")
	assert_false(PressFeel.sinks(null), "no stylebox, no sink")


func test_only_main_actions_tick() -> void:
	for name in [&"PrimaryButton", &"LobbyCtaButton", &"BookHeroButton", &"SuccessButton",
			&"DangerButton"]:
		assert_true(PressFeel.ticks(name), String(name) + " ticks")
	for name in [&"SecondaryButton", &"LobbyNavTile", &"FilterChipButton", &"", &"NavTileRapor"]:
		assert_false(PressFeel.ticks(name), String(name) + " stays silent")


func test_the_tick_is_haptics_tick_tier() -> void:
	assert_eq(PressFeel.PRESS_TICK_MS, 8, "Haptics' existing Tick tier")


func test_uipolish_uses_press_feel() -> void:
	var src := FileAccess.get_file_as_string(UIPOLISH_PATH)
	assert_contains(src, "Haptics.buzz(PressFeel.PRESS_TICK_MS)", "the tick")
	assert_contains(src, "PressFeel.ticks(", "only for main actions")
	assert_contains(src, "Juice.pop_release(", "lipped buttons pop on release")
	assert_contains(src, "PressFeel.sinks(", "sink or shrink is decided per button")


func test_pop_release_reads_its_tokens() -> void:
	var src := FileAccess.get_file_as_string(JUICE_PATH)
	assert_contains(src, "static func pop_release(", "Juice.pop_release exists")
	assert_contains(src, "release_pop_scale", "bumps to the token's scale")
	assert_contains(src, "release_pop_duration", "over the token's length")
