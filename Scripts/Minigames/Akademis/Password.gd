extends BaseMinigame

## Password: an Akademis quiz of two-number sums and differences ("37 + 58 = ?").
##
## Played on the desk (meja_background) with Menjodohkan's QuestionCard as the
## paper at the top and the shared Kalkulator in the middle, zero key shown
## (answers run to three digits). The player types on the calculator's keys,
## which the LCD shows, then presses Kirim; Hapus clears the entry. Every
## visual is authored in Password.tscn, Kalkulator.tscn and
## KalkulatorKey.tscn -- this script builds no nodes.

# ─── Visual - Background ─────────────────────────────────────────────────────
@export_group("Visual - Background")
## Drag a background image here. Leave empty to use a solid colour via the scene.
@export var background_texture: Texture2D = null

# ─── Visual - Colors ─────────────────────────────────────────────────────────
@export_group("Visual - Colors")
## LCD digit tint on a correct submission.
@export var correct_color: Color        = Color(0.1, 0.45, 0.18, 1)
## LCD digit tint on an incorrect submission.
@export var error_color: Color          = Color(0.62, 0.1, 0.1, 1)
## LCD digit tint when revealing the correct answer after a failed attempt.
@export var reveal_color: Color         = Color(0.1, 0.45, 0.18, 1)

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Assign a custom Font resource. Leave null to use the project theme font.
@export var font: Font = null
## Font size a short problem is shown at; a longer one shrinks from here
## until it fits the card (see SoalFit.gd).
@export var problem_font_size: int  = 96
## Smallest size SoalFit will shrink a problem to.
@export var min_problem_font_size: int = 28

# ─── Animation - Transitions ─────────────────────────────────────────────────
@export_group("Animation - Transitions")
## Fade-out before question swap.
@export var question_fade_out_duration: float = 0.25
## Fade-in after question swap.
@export var question_fade_in_duration: float  = 0.30

# ─── Animation - Feedback ───────────────────────────────────────────────────
@export_group("Animation - Feedback")
## Pause before next question
@export var feedback_hold_duration: float = 0.9
## Delay before showing correct answer
@export var reveal_delay: float           = 0.3

# ─── State ───────────────────────────────────────────────────────────────────
var score: int = 0
var max_score: int = 3
var current_question_index: int = 0
var expected_answer: int = 0
var is_submitting_answer: bool = false

var active_questions: Array[Dictionary] = []  # list of {problem_text, answer}

## Measures question text against the SoalCard; shared with Variabel.
const SoalFit := preload("res://Scripts/Minigames/Akademis/SoalFit.gd")

## What the player has typed so far; the LCD shows it.
var typed_answer: String = ""

@onready var score_hud: MinigameScoreHUD = $HeaderRow/ScoreHUD
@onready var progress_label: Label       = $SoalCard/StatusBadge/BadgeLabel
@onready var problem_label: Label        = $SoalCard/VBox/TextLabel
@onready var kalkulator: Control         = $KalkulatorSlot/Kalkulator
@onready var clear_button: Button        = $AksiRow/BtnHapus
@onready var submit_button: Button       = $AksiRow/BtnKirim

func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	setup_game()
	if submit_button:
		submit_button.pressed.connect(_on_enter_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if kalkulator:
		kalkulator.digit_pressed.connect(_on_keypad_pressed)

func _apply_visual_exports() -> void:
	# Apply background texture if provided
	var bg = get_node_or_null("Background") as TextureRect
	if bg and background_texture:
		bg.texture = background_texture
	if problem_label:
		if font:
			problem_label.add_theme_font_override("font", font)
		# The first problem is set from _ready(), before the card has its laid-
		# out size, so fit again whenever the label's real size arrives.
		problem_label.resized.connect(_refit_problem)

## Re-runs the font fit on whatever the card currently shows.
func _refit_problem() -> void:
	if problem_label:
		problem_label.add_theme_font_size_override("font_size",
			_fit_font_size(problem_label.text))

## Largest size, from problem_font_size down to min_problem_font_size, at
## which `text` fits the question card without clipping or touching its badge.
func _fit_font_size(text: String) -> int:
	return SoalFit.font_size(problem_label, get_node_or_null("SoalCard/StatusBadge") as Control,
		text, problem_font_size, min_problem_font_size)

# ── Build 3 random arithmetic problems ───────────────────────────────────────
func setup_game() -> void:
	score = 0
	max_score = 3
	current_question_index = 0
	is_submitting_answer = false
	if score_hud:
		score_hud.setup(load("res://Assets/Images/UI/Placeholders/icon_akademis.svg"), max_score)
	active_questions.clear()

	while active_questions.size() < max_score:
		var q = _generate_question()
		active_questions.append(q)

	_show_current_question()

func _generate_question() -> Dictionary:
	var num1 = randi() % 100 + 1
	var num2 = randi() % 100 + 1
	var is_addition = randi() % 2 == 0
	var problem_text: String
	var answer: int

	if is_addition:
		answer = num1 + num2
		problem_text = "%d + %d = ?" % [num1, num2]
	else:
		# Ensure positive result
		if num1 < num2:
			var temp = num1
			num1 = num2
			num2 = temp
		answer = num1 - num2
		problem_text = "%d - %d = ?" % [num1, num2]

	return {"problem_text": problem_text, "answer": answer}


# ── Show the current question ─────────────────────────────────────────────────
func _show_current_question() -> void:
	if current_question_index >= active_questions.size():
		_finish_quiz()
		return

	# Fade out before swapping content.
	# Skip on question 0 — SchoolDay already handles the minigame entrance fade.
	if current_question_index > 0:
		var tween_out = create_tween()
		tween_out.tween_property(problem_label, "modulate:a", 0.0, question_fade_out_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween_out.finished

	# ── Swap content while invisible ─────────────────────────────────────────
	is_submitting_answer = false

	var q_data = active_questions[current_question_index]
	expected_answer = q_data["answer"]

	_update_progress()

	if problem_label:
		problem_label.text = q_data["problem_text"]
		problem_label.add_theme_font_size_override("font_size",
			_fit_font_size(q_data["problem_text"]))

	_set_typed("")
	if kalkulator:
		kalkulator.reset_layar_color()
	_set_input_disabled(false)

	# Fade fresh content back in
	problem_label.modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.tween_property(problem_label, "modulate:a", 1.0, question_fade_in_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished

## Shows "Soal N/M" on the question card's badge. The score already lives in
## the shared ScoreHUD, and the badge is a narrow pill.
func _update_progress() -> void:
	if progress_label:
		progress_label.text = "Soal %d/%d" % [current_question_index + 1, active_questions.size()]

## Stores and displays the player's entry.
func _set_typed(value: String) -> void:
	typed_answer = value
	if kalkulator:
		kalkulator.set_layar(typed_answer)

# ── Calculator input ──────────────────────────────────────────────────────────
func _on_keypad_pressed(digit: String) -> void:
	if is_submitting_answer or not is_game_active:
		return
	_set_typed(typed_answer + digit)

func _on_clear_pressed() -> void:
	if is_submitting_answer or not is_game_active:
		return
	_set_typed("")
	if kalkulator:
		kalkulator.reset_layar_color()

## Locks or unlocks the keys and both action buttons together.
func _set_input_disabled(disabled: bool) -> void:
	if kalkulator:
		kalkulator.set_keys_disabled(disabled)
	if submit_button:
		submit_button.disabled = disabled
	if clear_button:
		clear_button.disabled = disabled

# ── Submit answer ─────────────────────────────────────────────────────────────
func _on_enter_pressed() -> void:
	if is_submitting_answer or not is_game_active:
		return
	if typed_answer == "":
		return

	is_submitting_answer = true

	# Disable input while evaluating
	_set_input_disabled(true)

	var answered = typed_answer.to_int()

	if answered == expected_answer:
		score += 1
		if score_hud:
			score_hud.set_score(score)
		if kalkulator:
			kalkulator.set_layar_color(correct_color)
			_play_jump_animation(kalkulator)
	else:
		apply_time_penalty(5.0)
		if kalkulator:
			kalkulator.set_layar_color(error_color)
			_play_wiggle_animation(kalkulator)
		# Show correct answer briefly before moving on
		await get_tree().create_timer(reveal_delay).timeout
		if kalkulator and is_instance_valid(kalkulator):
			kalkulator.set_layar(str(expected_answer))
			kalkulator.set_layar_color(reveal_color)

	await get_tree().create_timer(feedback_hold_duration).timeout

	current_question_index += 1
	if current_question_index < active_questions.size():
		_show_current_question()
	else:
		_finish_quiz()

# ── Finish quiz ───────────────────────────────────────────────────────────────
func _finish_quiz() -> void:
	result_subtitle = "Skor Akhir: %d / %d" % [score, max_score]
	if score >= get_target_win_score():
		win_game()
	else:
		lose_game()


# ── Reveal answers (called by BaseMinigame when time runs out) ────────────────
func reveal_answers() -> void:
	# Ensure the score subtitle is available for the timeout-triggered win path
	# (BaseMinigame calls lose_game → win_game without going through _finish_quiz)
	result_subtitle = "Skor Akhir: %d / %d" % [score, max_score]

	if kalkulator:
		kalkulator.set_layar(str(expected_answer))
		kalkulator.set_layar_color(reveal_color)
		_play_wiggle_animation(kalkulator)

	_set_input_disabled(true)
