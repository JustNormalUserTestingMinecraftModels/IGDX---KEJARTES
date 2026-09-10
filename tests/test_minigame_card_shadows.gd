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
	var box := card.get_theme_stylebox("panel") as StyleBoxFlat
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
## the player answers, and a shadow on only one would flicker at that swap.
func test_every_choice_button_state_carries_the_same_shadow() -> void:
	var screen = load(PILIHAN_GANDA).instantiate()
	var boxes := {
		"normal": screen.answer_btn_normal_style,
		"correct": screen.answer_btn_correct_style,
		"wrong": screen.answer_btn_wrong_style,
	}
	var report := {}
	for key in boxes:
		var b = boxes[key]
		report[key] = {
			"is_flat": b is StyleBoxFlat,
			"alpha": (b.shadow_color.a if b is StyleBoxFlat else -1.0),
			"size": (b.shadow_size if b is StyleBoxFlat else -1),
		}
	screen.free()
	for key in report:
		assert_true(report[key]["is_flat"],
			"answer_btn_%s_style must be an authored StyleBoxFlat, not null" % key)
		assert_true(report[key]["alpha"] >= MIN_SHADOW_ALPHA,
			"%s shadow alpha %f is below the floor" % [key, report[key]["alpha"]])
		assert_true(report[key]["size"] >= MIN_SHADOW_SIZE,
			"%s shadow size %d is below the floor" % [key, report[key]["size"]])
