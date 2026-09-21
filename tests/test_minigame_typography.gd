@tool
extends McpTestSuite

## Pins the minigame type ladder: every minigame text size is one of the
## three token rungs (36 font_title, 64 font_h1, 96 font_display_size), and
## each role reaches its size through a ThemeFactory variation rather than a
## theme_override_* or an add_theme_font_size_override literal.
##
## The rungs are not arbitrary. 36 -> 64 is 1.78 and 64 -> 96 is 1.50, a
## geometric mean of 1.63 -- the golden ratio within rounding, and already
## baked, so the ladder costs no change to DesignTokens.gd (which would
## re-space every screen in the game).
##
## Source-text scans in the house style -- these scenes cannot be
## instantiated headlessly. Must be @tool or the runner reports the class
## abstract, and no test here may be a coroutine: the runner calls
## suite.call(name) without awaiting, so an await silently aborts the test.

func suite_name() -> String:
	return "minigame_typography"


## Every variation this pass adds, with the token rung it must carry.
const VARIATIONS: Dictionary = {
	"MinigameQuestionLabel": 64,
	"MinigameChoiceButton": 36,
	"MinigameMetaLabel": 36,
	"MinigameBadgeLabel": 36,
	"MinigameOverlayLabel": 36,
	"MinigameWheelHeaderWarm": 36,
	"MinigameWheelHeaderCool": 36,
}


func test_theme_factory_declares_every_minigame_variation() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Design/ThemeFactory.gd")
	assert_false(src.is_empty(), "ThemeFactory.gd must be readable")
	for name in VARIATIONS:
		assert_true(src.contains('"%s"' % name),
			"ThemeFactory.gd must declare the %s variation" % name)


func test_every_variation_is_baked_at_its_rung() -> void:
	var theme := load("res://Assets/Theme/kejartes_theme.tres") as Theme
	assert_true(theme != null, "the baked theme must load")
	for name in VARIATIONS:
		var want: int = VARIATIONS[name]
		assert_true(theme.has_font_size("font_size", name),
			"%s must carry a baked font_size" % name)
		assert_eq(theme.get_font_size("font_size", name), want,
			"%s must be %d" % [name, want])
