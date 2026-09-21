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


# ------------------------------------------------------------ QuestionCard

## The shared question card, instanced by Password, Variabel, Menjodohkan's
## tiles and (since 2026-09-21) PilihanGanda.
const CARD := "res://Scenes/Minigames/Akademis/QuestionCard.tscn"

## Menjodohkan's answer tile. The same card family, with the same defects --
## it is held to the same rules.
const ANSWER_CARD := "res://Scenes/Minigames/Akademis/AnswerCard.tscn"

## Both cards, for the rules that govern the family rather than one scene.
const BOTH_CARDS := [CARD, ANSWER_CARD]

## The two mid-tone inks this pass retires, with their relative luminances.
## The orange (0.27) caps at 3.3:1 against pure white and the blue (0.21) at
## 4.0:1 -- both under the 4.5:1 body floor even in the best case, and both
## fall toward 1.5:1 on the cards they actually sit on. They are replaced by
## brand_primary (7.2:1) and cat_akademis (5.1:1) on surface_card, which
## keeps the warm/cool split between the question and answer cards.
const DEAD_INKS := ["Color(0.85, 0.45, 0.1, 1)", "Color(0.2, 0.5, 0.85, 1)"]


func test_question_card_carries_no_font_size_override() -> void:
	for path in BOTH_CARDS:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.is_empty(), "%s must be readable" % path)
		assert_false(src.contains("theme_override_font_sizes/font_size"),
			"%s must reach its sizes through variations" % path)


func test_question_card_image_slot_is_sized_for_real_art() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	assert_true(src.contains("custom_minimum_size = Vector2(0, 620)"),
		"QuestionCard.tscn's RowImage slot must be 620 tall -- monas.png is "
		+ "1080x1920 and borobudur.png 1920x1920, so a short wide slot "
		+ "letterboxes them to a narrow column")


func test_question_card_uses_the_ladder_variations() -> void:
	var src := FileAccess.get_file_as_string(CARD)
	for name in ["MinigameQuestionLabel", "MinigameBadgeLabel"]:
		assert_true(src.contains(name),
			"QuestionCard.tscn must use the %s variation" % name)


func test_question_card_border_clears_the_contrast_floor() -> void:
	for path in BOTH_CARDS:
		var src := FileAccess.get_file_as_string(path)
		for ink in DEAD_INKS:
			assert_false(src.contains(ink),
				"%s still carries the mid-tone ink %s" % [path, ink])


# ----------------------------------------------------------- PilihanGanda

const PILIHAN := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"


func test_pilihan_ganda_instances_the_shared_card() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN)
	assert_false(src.is_empty(), "PilihanGanda.tscn must be readable")
	assert_true(src.contains("QuestionCard.tscn"),
		"PilihanGanda.tscn must instance the shared QuestionCard")
	assert_true(src.contains('name="SoalCard"'),
		"the instance must be named SoalCard, as Password and Variabel name theirs")


func test_pilihan_ganda_drops_the_loose_trio() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN)
	# The image used to sit ABOVE the progress counter, which sat above the
	# question -- so "Dari gambar di atas..." pointed at a picture with the
	# score wedged between. The card owns all three now.
	for gone in ['name="QuestionImage"', 'name="ProgressLabel"', 'name="QuestionLabel"']:
		assert_false(src.contains(gone),
			"PilihanGanda.tscn must no longer declare %s -- the card owns it" % gone)


func test_pilihan_ganda_carries_no_font_size_override() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN)
	assert_false(src.contains("theme_override_font_sizes/font_size"),
		"PilihanGanda.tscn's authored 14px and 18px overrides must be gone")


const PILIHAN_GD := "res://Scripts/Minigames/Akademis/PilihanGanda.gd"


## A size written straight into the call, e.g.
## add_theme_font_size_override("font_size", 48). A call whose size comes
## from SoalFit is the supported form and is not matched here.
func _has_literal_size_override(src: String) -> bool:
	var needle := 'add_theme_font_size_override("font_size", '
	var at := src.find(needle)
	while at != -1:
		var ch := src.substr(at + needle.length(), 1)
		if ch.is_valid_int():
			return true
		at = src.find(needle, at + needle.length())
	return false


func test_pilihan_ganda_has_no_literal_font_size() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN_GD)
	assert_false(src.is_empty(), "PilihanGanda.gd must be readable")
	assert_false(_has_literal_size_override(src),
		"PilihanGanda.gd must reach its sizes through SoalFit and variations")


func test_pilihan_ganda_choice_rows_clear_the_touch_floor() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN_GD)
	assert_true(src.contains("answer_btn_min_height: int       = 130"),
		"answer_btn_min_height must be 130 -- 100 is under the ~48dp touch "
		+ "floor in the 1080-wide design space")


func test_pilihan_ganda_fits_the_question_with_soalfit() -> void:
	var src := FileAccess.get_file_as_string(PILIHAN_GD)
	assert_true(src.contains("SoalFit.font_size"),
		"the question must step down the ladder rather than clip")
	assert_true(src.contains("MinigameChoiceButton"),
		"the answer buttons must take the choice-button variation")


func test_question_card_has_no_emoji_lock() -> void:
	for path in BOTH_CARDS:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("🔒"),
			"%s: the lock must be icon_lock.svg -- CLAUDE.md bans emoji" % path)
		assert_true(src.contains("icon_lock.svg"),
			"%s must reference the real lock texture" % path)
