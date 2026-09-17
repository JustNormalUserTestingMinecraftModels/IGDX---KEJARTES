extends BaseMinigame

## Variabel: an Akademis quiz of stationery-item equations ("Buku + Buku = 8").
##
## Played on the desk (meja_background) with Menjodohkan's QuestionCard as the
## paper at the top and the shared Kalkulator in the middle. The player types
## a 1-9 answer on the calculator's keys, which the LCD shows, then presses
## Kirim; Hapus clears the entry. Every visual is authored in Variabel.tscn,
## Kalkulator.tscn and KalkulatorKey.tscn -- this script builds no nodes
## except the floating "+20s" time-boost popup.

# ─── Visual - Background ─────────────────────────────────────────────────────
@export_group("Visual - Background")
## Drag a background image here. Leave empty to use a solid colour via the scene.
@export var background_texture: Texture2D = null

# ─── Visual - Colors ─────────────────────────────────────────────────────────
@export_group("Visual - Colors")
## LCD digit tint on a correct submission.
@export var correct_color: Color          = Color(0.1, 0.45, 0.18, 1)
## LCD digit tint on an incorrect submission.
@export var error_color: Color            = Color(0.62, 0.1, 0.1, 1)
## LCD digit tint when revealing the correct answer after a failed attempt.
@export var reveal_color: Color           = Color(0.1, 0.45, 0.18, 1)
## Question text colour during reveal_pause_seconds' variable reveal. Dark
## enough to read on the white question card.
@export var equation_reveal_color: Color  = Color(0.72, 0.4, 0.04, 1)
## Colour of the floating "+20s" time-boost popup text.
@export var time_boost_popup_color: Color = Color(0.2, 1.0, 0.5, 1)

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Assign a custom Font resource. Leave null to use the project theme font.
@export var font: Font = null
## Font size a short question is shown at; longer ones shrink from here
## until they fit the card (see SoalFit.gd).
@export var equation_font_size: int       = 64
## Smallest size _fit_font_size() will shrink a long question to.
@export var min_equation_font_size: int   = 28
## Font size for the floating time-boost popup text.
@export var time_boost_font_size: int     = 48

# ─── Animation - Transitions ─────────────────────────────────────────────────
@export_group("Animation - Transitions")
## Fade-out before question swap.
@export var question_fade_out_duration: float = 0.25
## Fade-in after question swap.
@export var question_fade_in_duration: float  = 0.30

# ─── Animation - Feedback ───────────────────────────────────────────────────
@export_group("Animation - Feedback")
## Seconds before showing correct answer
@export var reveal_delay: float             = 0.3
## Pixels the +20s popup floats up
@export var time_boost_float_height: float  = 55.0
## Duration of the popup animation
@export var time_boost_float_duration: float = 0.9

# ─── State ───────────────────────────────────────────────────────────────────
var score: int = 0
var max_score: int = 3
var current_question_index: int = 0
var expected_answer: int = 0
var is_submitting_answer: bool = false

# Per-round question data
var active_questions: Array[Dictionary] = []  # list of {eq_text, answer}

@export_group("Configuration")
## Seconds the timer is frozen after each answer so the player can read
## the variable reveal
@export var reveal_pause_seconds: float = 3.0

## Measures question text against the SoalCard; shared with Password.
const SoalFit := preload("res://Scripts/Minigames/Akademis/SoalFit.gd")

## What the player has typed so far; the LCD shows it.
var typed_answer: String = ""
## The question card label's authored colour, restored after a reveal tint.
var _card_text_color: Color = Color.BLACK

@onready var score_hud: MinigameScoreHUD = $HeaderRow/ScoreHUD
@onready var progress_label: Label       = $SoalCard/StatusBadge/BadgeLabel
@onready var equation_label: Label       = $SoalCard/VBox/TextLabel
@onready var kalkulator: Control         = $KalkulatorSlot/Kalkulator
@onready var clear_button: Button        = $AksiRow/BtnHapus
@onready var submit_button: Button       = $AksiRow/BtnKirim

func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	setup_game()
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if kalkulator:
		kalkulator.digit_pressed.connect(_on_numpad_pressed)

func _apply_visual_exports() -> void:
	var bg = get_node_or_null("Background") as TextureRect
	if bg and background_texture:
		bg.texture = background_texture
	if equation_label:
		_card_text_color = equation_label.get_theme_color("font_color")
		if font:
			equation_label.add_theme_font_override("font", font)
		# The first question is set from _ready(), before the card has its laid-
		# out size, so fit again whenever the label's real size arrives.
		equation_label.resized.connect(_refit_equation)

## Re-runs the font fit on whatever the card currently shows.
func _refit_equation() -> void:
	if equation_label:
		equation_label.add_theme_font_size_override("font_size",
			_fit_font_size(equation_label.text))

# ── Build 3 random questions ───────────────────────────────────────────────────
func setup_game() -> void:
	score = 0
	max_score = 3
	current_question_index = 0
	is_submitting_answer = false
	if score_hud:
		score_hud.setup(load("res://Assets/Images/UI/Placeholders/icon_akademis.svg"), max_score)
	active_questions.clear()

	# Indonesian school stationery items — makes it feel like a real classroom assignment
	var items_pool = ["Buku", "Pensil", "Penggaris", "Penghapus", "Pulpen", "Rautan", "Jangka", "Busur", "Kamus", "Spidol"]

	# Generate 3 distinct questions using different patterns
	var patterns_used: Array[int] = []
	while active_questions.size() < max_score:
		var pattern = randi() % 11
		# Avoid repeating the same pattern twice
		if pattern in patterns_used:
			continue
		patterns_used.append(pattern)
		var q = _generate_question(pattern, items_pool)
		if q.size() > 0:
			active_questions.append(q)

	_show_current_question()

# ── Generate one equation question ────────────────────────────────────────────
func _generate_question(pattern: int, items_pool: Array) -> Dictionary:
	var items = items_pool.duplicate()
	items.shuffle()
	var item_a = items[0]
	var item_b = items[1]
	var item_c = items[2]
	var eq_text = ""
	var answer = 0
	var variables: Dictionary = {}  # item_name -> numeric value, shown after answering

	match pattern:
		0:
			var val_a = randi() % 5 + 1
			var val_b = randi() % 5 + 1
			var sum1 = val_a + val_a
			var sum2 = val_a + val_b
			eq_text = "%s + %s = %d\n" % [item_a, item_a, sum1]
			eq_text += "%s + %s = %d\n\n" % [item_a, item_b, sum2]
			eq_text += "Berapakah nilai %s?" % item_b
			answer = val_b
			variables = {item_a: val_a, item_b: val_b}
		1:
			var val_a = randi() % 5 + 2
			var val_b = randi() % 5 + 2
			var val_c = randi() % 5 + 2
			var sum1 = val_a + val_a
			var sum2 = val_a + val_b
			var sum3 = val_b + val_c
			eq_text = "%s + %s = %d\n" % [item_a, item_a, sum1]
			eq_text += "%s + %s = %d\n" % [item_a, item_b, sum2]
			eq_text += "%s + %s = %d\n\n" % [item_b, item_c, sum3]
			eq_text += "Berapakah nilai %s?" % item_c
			answer = val_c
			variables = {item_a: val_a, item_b: val_b, item_c: val_c}
		2:
			var val_a = randi() % 5 + 5
			var val_b = randi() % 4 + 1
			var sum1 = val_a + val_a
			var diff = val_a - val_b
			eq_text = "%s + %s = %d\n" % [item_a, item_a, sum1]
			eq_text += "%s - %s = %d\n\n" % [item_a, item_b, diff]
			eq_text += "Berapakah nilai %s?" % item_b
			answer = val_b
			variables = {item_a: val_a, item_b: val_b}
		3:
			var val_a = randi() % 4 + 2
			var val_b = randi() % 6 + 1
			var sum1 = val_a + val_a
			var sum2 = val_a + val_a + val_b
			eq_text = "%s + %s = %d\n" % [item_a, item_a, sum1]
			eq_text += "%s + %s + %s = %d\n\n" % [item_a, item_a, item_b, sum2]
			eq_text += "Berapakah nilai %s?" % item_b
			answer = val_b
			variables = {item_a: val_a, item_b: val_b}
		4:
			var val_a = randi() % 5 + 2
			var val_b = randi() % 5 + 2
			var sum1 = val_a + val_b
			var sum2 = val_a + val_a
			eq_text = "%s + %s = %d\n" % [item_a, item_b, sum1]
			eq_text += "%s + %s = %d\n\n" % [item_a, item_a, sum2]
			eq_text += "Berapakah nilai %s?" % item_b
			answer = val_b
			variables = {item_a: val_a, item_b: val_b}
		5:
			var val_a = randi() % 4 + 2
			var val_b = randi() % 4 + 2
			var val_c = randi() % 4 + 1
			var sum1 = val_a * 3
			var sum2 = val_b * 2
			var sum3 = val_a + val_b + val_c
			eq_text = "%s + %s + %s = %d\n" % [item_a, item_a, item_a, sum1]
			eq_text += "%s + %s = %d\n" % [item_b, item_b, sum2]
			eq_text += "%s + %s + %s = %d\n\n" % [item_a, item_b, item_c, sum3]
			eq_text += "Berapakah nilai %s?" % item_c
			answer = val_c
			variables = {item_a: val_a, item_b: val_b, item_c: val_c}
		6:
			var val_a = randi() % 5 + 5
			var val_b = randi() % 4 + 1
			var diff = val_a - val_b
			var sum = val_a + val_a
			eq_text = "%s - %s = %d\n" % [item_a, item_b, diff]
			eq_text += "%s + %s = %d\n\n" % [item_a, item_a, sum]
			eq_text += "Berapakah nilai %s?" % item_b
			answer = val_b
			variables = {item_a: val_a, item_b: val_b}
		7:
			var val_a = randi() % 4 + 5
			var val_b = randi() % 3 + 1
			var sum1 = val_a + val_b
			var diff = val_a - val_b
			eq_text = "%s + %s = %d\n" % [item_a, item_b, sum1]
			eq_text += "%s - %s = %d\n\n" % [item_a, item_b, diff]
			eq_text += "Berapakah nilai %s?" % item_a
			answer = val_a
			variables = {item_a: val_a, item_b: val_b}
		8:
			var val_a = randi() % 4 + 5
			var val_b = randi() % 3 + 1
			var sum1 = val_a + val_b
			var diff = val_a - val_b
			eq_text = "%s + %s = %d\n" % [item_a, item_b, sum1]
			eq_text += "%s - %s = %d\n\n" % [item_a, item_b, diff]
			eq_text += "Berapakah nilai %s?" % item_b
			answer = val_b
			variables = {item_a: val_a, item_b: val_b}
		9:
			var val_a = randi() % 6 + 1
			var val_b = randi() % 4 + 1
			var sum1 = val_a + val_b + val_b
			eq_text = "%s + %s + %s = %d\n" % [item_a, item_b, item_b, sum1]
			eq_text += "%s = %d\n\n" % [item_a, val_a]
			eq_text += "Berapakah nilai %s?" % item_b
			answer = val_b
			variables = {item_a: val_a, item_b: val_b}
		10:
			var val_a = randi() % 6 + 1
			var val_b = randi() % 4 + 2
			var sum1 = val_a + val_b
			var sum2 = val_b * 3
			eq_text = "%s + %s = %d\n" % [item_a, item_b, sum1]
			eq_text += "%s + %s + %s = %d\n\n" % [item_b, item_b, item_b, sum2]
			eq_text += "Berapakah nilai %s?" % item_a
			answer = val_a
			variables = {item_a: val_a, item_b: val_b}

	if eq_text == "":
		return {}
	return {"eq_text": eq_text, "answer": answer, "variables": variables}


# ── Show the current question ─────────────────────────────────────────────────
func _show_current_question() -> void:
	if current_question_index >= active_questions.size():
		_finish_quiz()
		return

	# Fade out before swapping content.
	# Skip on question 0 — SchoolDay already handles the minigame entrance fade.
	if current_question_index > 0:
		var tween_out = create_tween()
		tween_out.tween_property(equation_label, "modulate:a", 0.0, question_fade_out_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween_out.finished

	# ── Swap content while invisible ─────────────────────────────────────────
	is_submitting_answer = false

	var q_data = active_questions[current_question_index]
	expected_answer = q_data["answer"]

	_update_progress()

	if equation_label:
		equation_label.text = q_data["eq_text"]
		equation_label.add_theme_color_override("font_color", _card_text_color)
		equation_label.add_theme_font_size_override("font_size",
			_fit_font_size(q_data["eq_text"]))

	_set_typed("")
	if kalkulator:
		kalkulator.reset_layar_color()
	_set_input_disabled(false)

	# Fade fresh content back in
	equation_label.modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.tween_property(equation_label, "modulate:a", 1.0, question_fade_in_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished

## Shows "Soal N/M" on the question card's badge. The score already lives in
## the shared ScoreHUD, and the badge is a narrow pill.
func _update_progress() -> void:
	if progress_label:
		progress_label.text = "Soal %d/%d" % [current_question_index + 1, active_questions.size()]

## Largest size, from equation_font_size down to min_equation_font_size, at
## which `text` fits the question card without clipping or touching its badge.
func _fit_font_size(text: String) -> int:
	return SoalFit.font_size(equation_label, get_node_or_null("SoalCard/StatusBadge") as Control,
		text, equation_font_size, min_equation_font_size)

## Stores and displays the player's entry.
func _set_typed(value: String) -> void:
	typed_answer = value
	if kalkulator:
		kalkulator.set_layar(typed_answer)

# ── Submit answer ─────────────────────────────────────────────────────────────
func _on_submit_pressed() -> void:
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
		# +20 second timer boost for correct answer
		if has_time_limit:
			game_time_left = minf(game_time_left + 20.0, max_game_time)
			_show_time_boost_popup()
	else:
		apply_time_penalty(5.0)
		if kalkulator:
			kalkulator.set_layar_color(error_color)
			_play_wiggle_animation(kalkulator)
		# Show correct answer briefly
		await get_tree().create_timer(reveal_delay).timeout
		if kalkulator and is_instance_valid(kalkulator):
			kalkulator.set_layar(str(expected_answer))
			kalkulator.set_layar_color(reveal_color)

	# Show variable values so the player can verify the calculation
	_show_variable_reveal(current_question_index)

	# Pause the timer while the reveal is visible so the player can read without pressure
	var prev_paused = is_paused
	is_paused = true
	await get_tree().create_timer(reveal_pause_seconds).timeout
	is_paused = prev_paused

	current_question_index += 1
	if current_question_index < active_questions.size():
		_show_current_question()
	else:
		_finish_quiz()

# ── Calculator input ──────────────────────────────────────────────────────────
func _on_numpad_pressed(num_str: String) -> void:
	if is_submitting_answer or not is_game_active:
		return
	_set_typed(typed_answer + num_str)

func _on_clear_pressed() -> void:
	if is_submitting_answer or not is_game_active:
		return
	_set_typed("")
	if kalkulator:
		kalkulator.reset_layar_color()

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
	result_subtitle = "Skor Akhir: %d / %d" % [score, max_score]

	if kalkulator:
		kalkulator.set_layar(str(expected_answer))
		kalkulator.set_layar_color(reveal_color)
		_play_wiggle_animation(kalkulator)

	_set_input_disabled(true)
	_show_variable_reveal(current_question_index)

# ── Input enable/disable helper ──────────────────────────────────────────────
func _set_input_disabled(disabled: bool) -> void:
	if kalkulator:
		kalkulator.set_keys_disabled(disabled)
	if submit_button:
		submit_button.disabled = disabled
	if clear_button:
		clear_button.disabled = disabled

# ── Variable value reveal ────────────────────────────────────────────────────
func _show_variable_reveal(q_index: int) -> void:
	if q_index < 0 or q_index >= active_questions.size():
		return
	var q_data = active_questions[q_index]
	var vars: Dictionary = q_data.get("variables", {})
	if vars.is_empty() or equation_label == null:
		return

	# Build a line like "Buku = 4   Pensil = 3   Penggaris = 7"
	var parts: Array[String] = []
	for item_name in vars:
		parts.append("%s = %d" % [item_name, vars[item_name]])
	var reveal_line = "\n─────────────\n" + "   ".join(parts)

	equation_label.text = q_data["eq_text"] + reveal_line
	equation_label.add_theme_color_override("font_color", equation_reveal_color)
	equation_label.add_theme_font_size_override("font_size",
		_fit_font_size(equation_label.text))

func _show_time_boost_popup() -> void:
	# Spawn a floating "+20s" label above the calculator: per-call popup text,
	# the one runtime-built node this script keeps.
	var popup = Label.new()
	popup.text = "+20s"
	popup.add_theme_font_size_override("font_size", time_boost_font_size)
	popup.add_theme_color_override("font_color", time_boost_popup_color)
	popup.add_theme_constant_override("outline_size", 6)
	popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	if font:
		popup.add_theme_font_override("font", font)
	popup.z_index = 50

	var start_pos: Vector2
	if kalkulator and is_instance_valid(kalkulator):
		start_pos = kalkulator.global_position + Vector2(kalkulator.size.x * 0.5 - 40.0, 0.0)
	else:
		start_pos = get_viewport_rect().size * 0.5

	popup.position = start_pos
	add_child(popup)

	# Animate: float upward + fade out
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", start_pos.y - time_boost_float_height, time_boost_float_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, time_boost_float_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)
