extends BaseMinigame

# ─── Visual - Background ─────────────────────────────────────────────────────
@export_group("Visual - Background")
## Drag a background image here. Leave empty to use a solid colour via the scene.
@export var background_texture: Texture2D = null

# ─── Visual - Colors ─────────────────────────────────────────────────────────
@export_group("Visual - Colors")
@export var correct_color: Color        = Color(0.2, 0.9, 0.4, 1)
@export var error_color: Color          = Color(0.9, 0.25, 0.25, 1)
@export var reveal_color: Color         = Color(0.3, 0.95, 0.5, 1)
@export var progress_label_color: Color = Color(0.75, 0.85, 1.0, 1)

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Assign a custom Font resource. Leave null to use the project theme font.
@export var font: Font = null
@export var progress_font_size: int = 34
@export var problem_font_size: int  = 72
@export var input_font_size: int    = 64
@export var keypad_btn_font_size: int = 48

# ─── Visual - Input Box ──────────────────────────────────────────────────────
@export_group("Visual - Input Box")
## Drag a PNG here to replace the answer display box background.
@export var input_box_texture: Texture2D = null
## Minimum height of the answer display box in pixels.
@export var input_box_min_height: int = 90
## Padding / texture margin inside the answer box in pixels.
@export var input_box_texture_margin: int = 8
## Default text color inside the answer display box.
@export var input_box_font_color: Color = Color.WHITE

# ─── Visual - Keypad ────────────────────────────────────────────────────────
@export_group("Visual - Keypad")
## Minimum size of each keypad button.
@export var keypad_btn_size: Vector2 = Vector2(180, 140)
## Drag a PNG here — applies to all number, C, and Enter keys automatically.
@export var keypad_btn_normal_texture: Texture2D = null
## Grey tint applied when a button is pressed (0=black, 1=full colour).
@export var keypad_btn_pressed_tint: Color   = Color(0.65, 0.65, 0.65, 1.0)
## Grey tint applied when buttons are disabled after answering.
@export var keypad_btn_disabled_tint: Color  = Color(0.55, 0.55, 0.55, 0.75)
## Scale the button shrinks to on press (e.g. 0.9 = 90% size).
@export var keypad_btn_press_scale: float    = 0.90
## Duration of the press-shrink animation in seconds.
@export var keypad_btn_press_duration: float = 0.07
## Margin (pixels) inside the button texture where the label is drawn.
@export var keypad_btn_texture_margin: int   = 8

# ─── Animation - Transitions ─────────────────────────────────────────────────
@export_group("Animation - Transitions")
@export var question_fade_out_duration: float = 0.25
@export var question_fade_in_duration: float  = 0.30

# ─── Animation - Feedback ───────────────────────────────────────────────────
@export_group("Animation - Feedback")
@export var feedback_hold_duration: float = 0.9    ## Pause before next question
@export var reveal_delay: float           = 0.3    ## Delay before showing correct answer

# ─── State ───────────────────────────────────────────────────────────────────
var score: int = 0
var max_score: int = 3
var current_question_index: int = 0
var expected_answer: int = 0
var is_submitting_answer: bool = false

var active_questions: Array[Dictionary] = []  # list of {problem_text, answer}

@onready var progress_label: Label    = $VBoxContainer/ProgressLabel
@onready var problem_label: Label     = $VBoxContainer/ProblemLabel
@onready var input_label: Label       = $VBoxContainer/InputLabel
@onready var keypad_grid: GridContainer = $VBoxContainer/KeypadGrid

func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	setup_game()
	_setup_keypad()

func _apply_visual_exports() -> void:
	# Apply background texture if provided
	var bg = get_node_or_null("Background") as TextureRect
	if bg and background_texture:
		bg.texture = background_texture

	if input_label:
		input_label.custom_minimum_size.y = input_box_min_height
		input_label.add_theme_font_size_override("font_size", input_font_size)
		input_label.add_theme_color_override("font_color", input_box_font_color)
		if font:
			input_label.add_theme_font_override("font", font)
		if input_box_texture:
			var sb = _make_btn_stylebox(input_box_texture, Color.WHITE)
			sb.texture_margin_left   = input_box_texture_margin
			sb.texture_margin_right  = input_box_texture_margin
			sb.texture_margin_top    = input_box_texture_margin
			sb.texture_margin_bottom = input_box_texture_margin
			input_label.add_theme_stylebox_override("normal", sb)

# ── Build 3 random arithmetic problems ───────────────────────────────────────
func setup_game() -> void:
	score = 0
	max_score = 3
	current_question_index = 0
	is_submitting_answer = false
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

	var vbox := $VBoxContainer as Control

	# Fade out before swapping content.
	# Skip on question 0 — SchoolDay already handles the minigame entrance fade.
	if current_question_index > 0:
		var tween_out = create_tween()
		tween_out.tween_property(vbox, "modulate:a", 0.0, question_fade_out_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween_out.finished

	# ── Swap content while invisible ─────────────────────────────────────────
	is_submitting_answer = false

	var q_data = active_questions[current_question_index]
	expected_answer = q_data["answer"]

	if progress_label:
		progress_label.text = "Soal %d dari %d  |  Skor: %d" % [current_question_index + 1, active_questions.size(), score]
		progress_label.add_theme_font_size_override("font_size", progress_font_size)
		progress_label.add_theme_color_override("font_color", progress_label_color)
		if font:
			progress_label.add_theme_font_override("font", font)

	if problem_label:
		problem_label.text = q_data["problem_text"]
		problem_label.remove_theme_color_override("font_color")
		problem_label.add_theme_font_size_override("font_size", problem_font_size)
		if font:
			problem_label.add_theme_font_override("font", font)

	if input_label:
		input_label.text = ""
		input_label.add_theme_color_override("font_color", input_box_font_color)

	# Re-enable keypad buttons
	if keypad_grid:
		for child in keypad_grid.get_children():
			if child is Button:
				child.disabled = false

	# Fade fresh content back in
	vbox.modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.tween_property(vbox, "modulate:a", 1.0, question_fade_in_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished

# ── Keypad setup ──────────────────────────────────────────────────────────────
func _setup_keypad() -> void:
	if keypad_grid == null:
		return

	for i in range(1, 10):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = keypad_btn_size
		btn.add_theme_font_size_override("font_size", keypad_btn_font_size)
		if font:
			btn.add_theme_font_override("font", font)
		_apply_keypad_btn_textures(btn)
		btn.pressed.connect(_on_keypad_pressed.bind(str(i)))
		keypad_grid.add_child(btn)

	var clear_btn = Button.new()
	clear_btn.text = "C"
	clear_btn.custom_minimum_size = keypad_btn_size
	clear_btn.add_theme_font_size_override("font_size", keypad_btn_font_size)
	if font:
		clear_btn.add_theme_font_override("font", font)
	_apply_keypad_btn_textures(clear_btn)
	clear_btn.pressed.connect(_on_clear_pressed)
	keypad_grid.add_child(clear_btn)

	var zero_btn = Button.new()
	zero_btn.text = "0"
	zero_btn.custom_minimum_size = keypad_btn_size
	zero_btn.add_theme_font_size_override("font_size", keypad_btn_font_size)
	if font:
		zero_btn.add_theme_font_override("font", font)
	_apply_keypad_btn_textures(zero_btn)
	zero_btn.pressed.connect(_on_keypad_pressed.bind("0"))
	keypad_grid.add_child(zero_btn)

	var enter_btn = Button.new()
	enter_btn.text = "Enter"
	enter_btn.custom_minimum_size = keypad_btn_size
	enter_btn.add_theme_font_size_override("font_size", keypad_btn_font_size)
	if font:
		enter_btn.add_theme_font_override("font", font)
	_apply_keypad_btn_textures(enter_btn)
	enter_btn.pressed.connect(_on_enter_pressed)
	keypad_grid.add_child(enter_btn)

## Applies texture-based StyleBoxes to a keypad button when textures are exported.
## Falls back to the theme default when no texture is assigned.
func _apply_keypad_btn_textures(btn: Button) -> void:
	if keypad_btn_normal_texture == null:
		return  # No texture assigned — keep the default theme style
	# Normal and hover use the full-colour texture
	var sb_normal = _make_btn_stylebox(keypad_btn_normal_texture, Color.WHITE)
	var sb_pressed  = _make_btn_stylebox(keypad_btn_normal_texture, keypad_btn_pressed_tint)
	var sb_disabled = _make_btn_stylebox(keypad_btn_normal_texture, keypad_btn_disabled_tint)
	btn.add_theme_stylebox_override("normal",   sb_normal)
	btn.add_theme_stylebox_override("hover",    sb_normal)
	btn.add_theme_stylebox_override("pressed",  sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_stylebox_override("focus",    sb_normal)
	# Wire up scale-shrink animation on press
	btn.pivot_offset = keypad_btn_size / 2.0
	btn.resized.connect(func(): if is_instance_valid(btn): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(_on_keypad_btn_down.bind(btn))
	btn.button_up.connect(_on_keypad_btn_up.bind(btn))

func _on_keypad_btn_down(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE * keypad_btn_press_scale, keypad_btn_press_duration)

func _on_keypad_btn_up(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, keypad_btn_press_duration)

## Builds a StyleBoxTexture from a Texture2D with a modulate tint and content margins.
func _make_btn_stylebox(tex: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.modulate_color = tint
	sb.texture_margin_left   = keypad_btn_texture_margin
	sb.texture_margin_right  = keypad_btn_texture_margin
	sb.texture_margin_top    = keypad_btn_texture_margin
	sb.texture_margin_bottom = keypad_btn_texture_margin
	return sb

func _on_keypad_pressed(digit: String) -> void:
	if is_submitting_answer or not is_game_active:
		return
	if input_label:
		input_label.text += digit

func _on_clear_pressed() -> void:
	if is_submitting_answer or not is_game_active:
		return
	if input_label:
		input_label.text = ""

# ── Submit answer ─────────────────────────────────────────────────────────────
func _on_enter_pressed() -> void:
	if is_submitting_answer or not is_game_active:
		return
	if input_label == null or input_label.text == "":
		return

	is_submitting_answer = true

	# Disable keypad while evaluating
	if keypad_grid:
		for child in keypad_grid.get_children():
			if child is Button:
				child.disabled = true

	var answered = input_label.text.to_int()

	if answered == expected_answer:
		score += 1
		if input_label:
			input_label.add_theme_color_override("font_color", correct_color)
		_play_jump_animation(input_label)
	else:
		apply_time_penalty(5.0)
		if input_label:
			input_label.add_theme_color_override("font_color", error_color)
		_play_wiggle_animation($VBoxContainer)
		# Show correct answer briefly before moving on
		await get_tree().create_timer(reveal_delay).timeout
		if input_label and is_instance_valid(input_label):
			input_label.text = "Jawaban: %d" % expected_answer
			input_label.add_theme_color_override("font_color", reveal_color)

	# Update progress label score
	if progress_label:
		progress_label.text = "Soal %d dari %d  |  Skor: %d" % [current_question_index + 1, active_questions.size(), score]

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

	if input_label:
		input_label.text = "Jawaban: %d" % expected_answer
		input_label.add_theme_color_override("font_color", reveal_color)

	if keypad_grid:
		for child in keypad_grid.get_children():
			if child is Button:
				child.disabled = true

	_play_wiggle_animation($VBoxContainer)
