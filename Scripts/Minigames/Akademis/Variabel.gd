extends BaseMinigame

# ─── Visual - Background ─────────────────────────────────────────────────────
@export_group("Visual - Background")
## Drag a background image here. Leave empty to use a solid colour via the scene.
@export var background_texture: Texture2D = null

# ─── Visual - Colors ─────────────────────────────────────────────────────────
@export_group("Visual - Colors")
## Flash tint on a correct submission.
@export var correct_color: Color          = Color(0.2, 0.9, 0.4, 1)
## Flash tint on an incorrect submission.
@export var error_color: Color            = Color(0.9, 0.25, 0.25, 1)
## Tint used when revealing the correct answer after a failed attempt.
@export var reveal_color: Color           = Color(0.3, 0.95, 0.5, 1)
## Tint on the equation text during reveal_pause_seconds' variable reveal.
@export var equation_reveal_color: Color  = Color(0.9, 0.9, 0.5, 1)
## Text colour for the "question N of ..." progress label.
@export var progress_label_color: Color   = Color(0.75, 0.85, 1.0, 1)
## Colour of the floating "+20s" time-boost popup text.
@export var time_boost_popup_color: Color = Color(0.2, 1.0, 0.5, 1)

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Assign a custom Font resource. Leave null to use the project theme font.
@export var font: Font = null
## Font size for the progress label.
@export var progress_font_size: int       = 34
## Font size for the equation/prompt text.
@export var equation_font_size: int       = 72
## Font size for the player's entered-answer display.
@export var input_font_size: int          = 64
## Font size for each numpad button's digit.
@export var numpad_btn_font_size: int     = 48
## Font size for the floating time-boost popup text.
@export var time_boost_font_size: int     = 48

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
## Placeholder text when no number has been typed.
@export var input_box_placeholder: String = "Jawaban"
## Placeholder text color.
@export var input_box_placeholder_color: Color = Color(0.6, 0.6, 0.6, 0.7)

# ─── Visual - Numpad ────────────────────────────────────────────────────────
@export_group("Visual - Numpad")
## Size of each number button
@export var numpad_btn_size: Vector2     = Vector2(180, 140)
## Height of the C (clear) row
@export var clear_btn_height: float      = 140.0
## Drag a PNG here — applies to all number and C keys automatically.
@export var numpad_btn_normal_texture: Texture2D = null
## Optional custom PNG for the Submit button. If left null, uses numpad_btn_normal_texture.
@export var submit_btn_normal_texture: Texture2D = null
## Grey tint applied when a button is pressed (0=black, 1=full colour).
@export var numpad_btn_pressed_tint: Color   = Color(0.65, 0.65, 0.65, 1.0)
## Grey tint applied when buttons are disabled after answering.
@export var numpad_btn_disabled_tint: Color  = Color(0.55, 0.55, 0.55, 0.75)
## Scale the button shrinks to on press (e.g. 0.90 = 90% size).
@export var numpad_btn_press_scale: float    = 0.90
## Duration of the press-shrink animation in seconds.
@export var numpad_btn_press_duration: float = 0.07
## Margin (pixels) inside the button texture where the label is drawn.
@export var numpad_btn_texture_margin: int   = 8

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
var numpad_bottom_row: HBoxContainer = null   # holds wide-C + 0 (separate from GridContainer)

@export_group("Configuration")
## Seconds the timer is frozen after each answer so the player can read
## the variable reveal
@export var reveal_pause_seconds: float = 3.0

@onready var progress_label: Label        = $VBoxContainer/ProgressLabel
@onready var equation_label: Label        = $VBoxContainer/EquationLabel
@onready var input_line_edit: LineEdit    = $VBoxContainer/InputLineEdit
@onready var numpad_grid: GridContainer   = $VBoxContainer/NumpadGrid
@onready var submit_button: Button        = $VBoxContainer/SubmitButton

func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	setup_game()

	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)

	_setup_numpad()

func _apply_visual_exports() -> void:
	var bg = get_node_or_null("Background") as TextureRect
	if bg and background_texture:
		bg.texture = background_texture

	if input_line_edit:
		input_line_edit.custom_minimum_size.y = input_box_min_height
		input_line_edit.placeholder_text = input_box_placeholder
		input_line_edit.add_theme_font_size_override("font_size", input_font_size)
		input_line_edit.add_theme_color_override("font_color", input_box_font_color)
		input_line_edit.add_theme_color_override("font_placeholder_color", input_box_placeholder_color)
		if font:
			input_line_edit.add_theme_font_override("font", font)
		if input_box_texture:
			var sb = _make_btn_stylebox(input_box_texture, Color.WHITE)
			sb.texture_margin_left   = input_box_texture_margin
			sb.texture_margin_right  = input_box_texture_margin
			sb.texture_margin_top    = input_box_texture_margin
			sb.texture_margin_bottom = input_box_texture_margin
			input_line_edit.add_theme_stylebox_override("normal", sb)
			input_line_edit.add_theme_stylebox_override("focus", sb)
			input_line_edit.add_theme_stylebox_override("read_only", sb)

	if submit_button:
		var s_tex = submit_btn_normal_texture if submit_btn_normal_texture else numpad_btn_normal_texture
		if s_tex:
			_apply_button_texture_override(submit_button, s_tex)
		if font:
			submit_button.add_theme_font_override("font", font)

# ── Build 3 random questions ───────────────────────────────────────────────────
func setup_game() -> void:
	score = 0
	max_score = 3
	current_question_index = 0
	is_submitting_answer = false
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

	if equation_label:
		equation_label.text = q_data["eq_text"]
		equation_label.remove_theme_color_override("font_color")
		equation_label.add_theme_font_size_override("font_size", equation_font_size)
		if font:
			equation_label.add_theme_font_override("font", font)

	if input_line_edit:
		input_line_edit.text = ""
		input_line_edit.editable = true
		input_line_edit.add_theme_color_override("font_color", input_box_font_color)

	_set_numpad_disabled(false)

	if submit_button:
		submit_button.disabled = false

	# Fade fresh content back in
	vbox.modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.tween_property(vbox, "modulate:a", 1.0, question_fade_in_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished

# ── Submit answer ─────────────────────────────────────────────────────────────
func _on_submit_pressed() -> void:
	if is_submitting_answer or not is_game_active:
		return
	if input_line_edit == null or input_line_edit.text == "":
		return

	is_submitting_answer = true

	# Disable input while evaluating
	if submit_button:
		submit_button.disabled = true
	_set_numpad_disabled(true)

	var answered = input_line_edit.text.to_int()

	if answered == expected_answer:
		score += 1
		if input_line_edit:
			input_line_edit.add_theme_color_override("font_color", correct_color)
		_play_jump_animation(input_line_edit)
		# +20 second timer boost for correct answer
		if has_time_limit:
			game_time_left = minf(game_time_left + 20.0, max_game_time)
			_show_time_boost_popup()
	else:
		apply_time_penalty(5.0)
		if input_line_edit:
			input_line_edit.add_theme_color_override("font_color", error_color)
		_play_wiggle_animation($VBoxContainer)
		# Show correct answer briefly
		await get_tree().create_timer(reveal_delay).timeout
		if input_line_edit and is_instance_valid(input_line_edit):
			input_line_edit.text = "Jawaban: %d" % expected_answer
			input_line_edit.add_theme_color_override("font_color", reveal_color)

	# Show variable values so the player can verify the calculation
	_show_variable_reveal(current_question_index)

	# Update progress label score immediately
	if progress_label:
		progress_label.text = "Soal %d dari %d  |  Skor: %d" % [current_question_index + 1, active_questions.size(), score]

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

# ── Numpad ────────────────────────────────────────────────────────────────────
func _setup_numpad() -> void:
	if numpad_grid == null:
		return

	# Buttons 1-9 fill the 3-column GridContainer exactly (3 rows)
	for i in range(1, 10):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = numpad_btn_size
		btn.add_theme_font_size_override("font_size", numpad_btn_font_size)
		if font:
			btn.add_theme_font_override("font", font)
		_apply_keypad_btn_textures(btn)
		btn.pressed.connect(_on_numpad_pressed.bind(str(i)))
		numpad_grid.add_child(btn)

	# Bottom row: C spanning the full width (answers are always 1-9, so 0 is never needed)
	numpad_bottom_row = HBoxContainer.new()
	numpad_bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var clear_btn = Button.new()
	clear_btn.text = "C"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # fills the full row
	clear_btn.custom_minimum_size = Vector2(0, clear_btn_height)
	clear_btn.add_theme_font_size_override("font_size", numpad_btn_font_size)
	if font:
		clear_btn.add_theme_font_override("font", font)
	_apply_keypad_btn_textures(clear_btn)
	clear_btn.pressed.connect(_on_clear_pressed)
	numpad_bottom_row.add_child(clear_btn)

	# Insert the bottom row directly after the grid in the parent VBoxContainer
	var parent = numpad_grid.get_parent()
	if parent:
		parent.add_child(numpad_bottom_row)
		parent.move_child(numpad_bottom_row, numpad_grid.get_index() + 1)

## Applies texture-based StyleBoxes to a numpad button when textures are exported.
## Falls back to the theme default when no texture is assigned.
func _apply_keypad_btn_textures(btn: Button) -> void:
	if numpad_btn_normal_texture == null:
		return  # No texture assigned — keep the default theme style
	_apply_button_texture_override(btn, numpad_btn_normal_texture)

func _apply_button_texture_override(btn: Button, tex: Texture2D) -> void:
	var sb_normal   = _make_btn_stylebox(tex, Color.WHITE)
	var sb_pressed  = _make_btn_stylebox(tex, numpad_btn_pressed_tint)
	var sb_disabled = _make_btn_stylebox(tex, numpad_btn_disabled_tint)
	btn.add_theme_stylebox_override("normal",   sb_normal)
	btn.add_theme_stylebox_override("hover",    sb_normal)
	btn.add_theme_stylebox_override("pressed",  sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_stylebox_override("focus",    sb_normal)
	# Wire up scale-shrink animation on press
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): if is_instance_valid(btn): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(_on_numpad_btn_down.bind(btn))
	btn.button_up.connect(_on_numpad_btn_up.bind(btn))

func _on_numpad_btn_down(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE * numpad_btn_press_scale, numpad_btn_press_duration)

func _on_numpad_btn_up(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, numpad_btn_press_duration)

## Builds a StyleBoxTexture from a Texture2D with a modulate tint and content margins.
func _make_btn_stylebox(tex: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.modulate_color = tint
	sb.texture_margin_left   = numpad_btn_texture_margin
	sb.texture_margin_right  = numpad_btn_texture_margin
	sb.texture_margin_top    = numpad_btn_texture_margin
	sb.texture_margin_bottom = numpad_btn_texture_margin
	return sb

func _on_numpad_pressed(num_str: String) -> void:
	if is_submitting_answer or not is_game_active:
		return
	if input_line_edit:
		input_line_edit.text += num_str

func _on_clear_pressed() -> void:
	if is_submitting_answer or not is_game_active:
		return
	if input_line_edit:
		input_line_edit.text = ""

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

	if input_line_edit:
		input_line_edit.editable = false
		input_line_edit.text = "Jawaban: %d" % expected_answer
		input_line_edit.add_theme_color_override("font_color", reveal_color)

	_set_numpad_disabled(true)
	_show_variable_reveal(current_question_index)
	_play_wiggle_animation($VBoxContainer)

# ── Numpad enable/disable helper ─────────────────────────────────────────────
func _set_numpad_disabled(disabled: bool) -> void:
	if numpad_grid:
		for child in numpad_grid.get_children():
			if child is Button:
				child.disabled = disabled
	if numpad_bottom_row:
		for child in numpad_bottom_row.get_children():
			if child is Button:
				child.disabled = disabled

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
func _show_time_boost_popup() -> void:
	# Spawn a floating "+20s ⏱" label anchored near the input field
	var popup = Label.new()
	popup.text = "+20s ⏱"
	popup.add_theme_font_size_override("font_size", time_boost_font_size)
	popup.add_theme_color_override("font_color", time_boost_popup_color)
	popup.add_theme_constant_override("outline_size", 6)
	popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	if font:
		popup.add_theme_font_override("font", font)
	popup.z_index = 50

	# Position it at the input field's location (or screen centre if not available)
	var start_pos: Vector2
	if input_line_edit and is_instance_valid(input_line_edit):
		start_pos = input_line_edit.global_position + Vector2(input_line_edit.size.x * 0.5 - 20.0, -8.0)
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
