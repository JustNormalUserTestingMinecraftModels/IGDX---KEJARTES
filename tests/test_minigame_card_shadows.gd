@tool
extends McpTestSuiteCompat

## Every card in the two Akademis minigames casts a shadow deep enough to
## read as lifted.
##
## StyleBoxFlat rather than the soft_shadow shader: these are StyleBox-
## driven panels and buttons with no texture alpha for the shader to blur.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_card_shadows"


const QUESTION_CARD := "res://Scenes/Minigames/Akademis/QuestionCard.tscn"
const ANSWER_CARD := "res://Scenes/Minigames/Akademis/AnswerCard.tscn"
const PILIHAN_GANDA := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"

## Floors, not exact values -- the look is tunable, the presence is not.
const MIN_SHADOW_ALPHA := 0.18
const MIN_SHADOW_SIZE := 8


func _panel_box(scene_path: String) -> StyleBoxFlat:
	var card = load(scene_path).instantiate()
	# Since 2026-09-30 the cards' boxes come from the theme (MinigameCard,
	# MinigameAnswerCard): the card needs the baked theme, and a theme only
	# resolves for a Control inside the tree.
	card.theme = load("res://Assets/Theme/kejartes_theme.tres")
	Engine.get_main_loop().root.add_child(card)
	var box := card.get_theme_stylebox("panel") as StyleBoxFlat
	card.get_parent().remove_child(card)
	card.free()
	return box


func test_the_question_card_casts_a_readable_shadow() -> void:
	var box := _panel_box(QUESTION_CARD)
	assert_not_null(box, "QuestionCard's root must carry a StyleBoxFlat panel")
	assert_true(box.shadow_color.a >= MIN_SHADOW_ALPHA,
		"shadow alpha %f is below the %f floor" % [box.shadow_color.a, MIN_SHADOW_ALPHA])
	assert_true(box.shadow_size >= MIN_SHADOW_SIZE,
		"shadow size %d is below the %d floor" % [box.shadow_size, MIN_SHADOW_SIZE])
	assert_true(box.shadow_offset.y > 0.0,
		"the shadow falls downward, so the card reads as lifted")


func test_the_answer_card_casts_a_readable_shadow() -> void:
	var box := _panel_box(ANSWER_CARD)
	assert_not_null(box, "AnswerCard's root must carry a StyleBoxFlat panel")
	assert_true(box.shadow_color.a >= MIN_SHADOW_ALPHA,
		"shadow alpha %f is below the %f floor" % [box.shadow_color.a, MIN_SHADOW_ALPHA])
	assert_true(box.shadow_size >= MIN_SHADOW_SIZE,
		"shadow size %d is below the %d floor" % [box.shadow_size, MIN_SHADOW_SIZE])
	assert_true(box.shadow_offset.y > 0.0,
		"the shadow falls downward, so the card reads as lifted")


## All three states, not just normal: PilihanGanda swaps between them when
## the player answers, and a lip on only one would flicker at that swap.
## Since 2026-09-30 (minigame hierarchy) the three are theme variations --
## MinigameChoiceButton and its Correct/Wrong flashes -- all lipped faces from
## LippedBox, so the pin is one lip height across the three, not a shadow.
func test_every_choice_button_state_carries_the_same_lip() -> void:
	var theme := load("res://Assets/Theme/kejartes_theme.tres") as Theme
	var lips := {}
	for name in ["MinigameChoiceButton", "MinigameChoiceButtonCorrect",
			"MinigameChoiceButtonWrong"]:
		var box := theme.get_stylebox("normal", name) as StyleBoxFlat
		assert_true(box != null and LippedBox.is_lipped(box), name + " is a lipped face")
		if box != null:
			lips[name] = LippedBox.lip_height_of(box)
	var heights := lips.values()
	for h in heights:
		assert_eq(h, heights[0], "every answer state stands on the same lip: %s" % lips)
