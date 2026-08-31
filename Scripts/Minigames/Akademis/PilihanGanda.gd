extends BaseMinigame

## Akademis minigame: a straight multiple-choice quiz, total_questions_per_game
## questions drawn from fallback_questions, one at a time with a
## correct/wrong flash between each.
##
## Winning feeds the Akademis stat (see StudentData.apply_minigame_result);
## score is the count of correct answers.

# Inspector fallback question bank (used if JSON file fails to load)
@export_group("Fallback Question Bank")
## The question pool this game draws total_questions_per_game entries
## from, each a {question, choices, correct_index, image} Dictionary.
@export var fallback_questions: Array[Dictionary] = [
	{
		"question": "Dari gambar di atas, monumen ikonik apakah yang berdiri megah di Jakarta?",
		"choices": ["Monumen Nasional (Monas)", "Candi Prambanan", "Tugu Muda Semarang", "Monumen Pancasila Sakti"],
		"correct_index": 0,
		"image": "res://Assets/Images/monas_monument.jpg"
	},
	{
		"question": "Apa nama ibu kota negara Indonesia saat ini?",
		"choices": ["Nusantara", "Jakarta", "Bandung", "Surabaya"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Lagu kebangsaan Republik Indonesia adalah...",
		"choices": ["Indonesia Raya", "Garuda Pancasila", "Satu Nusa Satu Bangsa", "Rayuan Pulau Kelapa"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Mata uang resmi Republik Indonesia adalah...",
		"choices": ["Rupiah", "Ringgit", "Peso", "Baht"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Candi Borobudur terletak di provinsi...",
		"choices": ["Jawa Tengah", "Jawa Timur", "D.I. Yogyakarta", "Jawa Barat"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Dasar negara Republik Indonesia adalah...",
		"choices": ["Pancasila", "UUD 1945", "Bhinneka Tunggal Ika", "Sumpah Pemuda"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Semboyan Bhinneka Tunggal Ika memiliki arti...",
		"choices": ["Berbeda-beda tetapi tetap satu jua", "Bersatu kita teguh bercerai kita runtuh", "Satu nusa satu bangsa", "Majulah tanpa menyingkirkan"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Siapa Proklamator Kemerdekaan Indonesia?",
		"choices": ["Soekarno dan Moh. Hatta", "Soeharto dan B.J. Habibie", "Ki Hajar Dewantara", "Jenderal Sudirman"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Warna bendera Sang Saka Merah Putih melambangkan...",
		"choices": ["Keberanian dan Kesucian", "Kesucian dan Keberanian", "Keberanian dan Kejujuran", "Kesucian dan Perdamaian"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Hewan endemik Komodo dapat ditemukan di provinsi...",
		"choices": ["Nusa Tenggara Timur", "Nusa Tenggara Barat", "Bali", "Maluku"],
		"correct_index": 0,
		"image": ""
	},
	{
		"question": "Rumah adat khas Minangkabau dari Sumatera Barat adalah...",
		"choices": ["Rumah Gadang", "Rumah Joglo", "Rumah Tongkonan", "Rumah Honai"],
		"correct_index": 0,
		"image": ""
	}
]

@export_group("Configuration")
## How many questions this session draws from fallback_questions.
@export var total_questions_per_game: int = 3

# ─── Visual - Background ─────────────────────────────────────────────────────
@export_group("Visual - Background")
## Drag a background image here. Leave empty to use a solid colour via the scene.
@export var background_texture: Texture2D = null

# ─── Visual - Answer Buttons ─────────────────────────────────────────────────
@export_group("Visual - Answer Buttons")
## Drag a PNG here — applies to all answer choice buttons automatically.
@export var choice_btn_normal_texture:   Texture2D = null
## Grey tint applied when a choice button is pressed (0=black, 1=full colour).
@export var choice_btn_pressed_tint: Color   = Color(0.65, 0.65, 0.65, 1.0)
## Grey tint applied when choice buttons are disabled after answering.
@export var choice_btn_disabled_tint: Color  = Color(0.55, 0.55, 0.55, 0.75)
## Scale the button shrinks to on press (e.g. 0.96 = 96% size).
@export var choice_btn_press_scale: float    = 0.96
## Duration of the press-shrink animation in seconds.
@export var choice_btn_press_duration: float = 0.07
## Margin (pixels) inside the button texture where the text is drawn.
@export var choice_btn_texture_margin: int   = 12
## Minimum height (px) of each answer button, regardless of text length.
@export var answer_btn_min_height: int       = 100
## StyleBox fallback overrides if no texture assigned (leave null = uses theme default).
@export var answer_btn_normal_style:  StyleBox = null
## Style flashed on the button holding the correct answer.
@export var answer_btn_correct_style: StyleBox = null
## Style flashed on a button the player picked incorrectly.
@export var answer_btn_wrong_style:   StyleBox = null

# ─── Visual - Colors ─────────────────────────────────────────────────────────
@export_group("Visual - Colors")
## Procedural-mode tint matching answer_btn_correct_style's flash.
@export var correct_color: Color        = Color(0.2, 0.75, 0.35, 1)
## Procedural-mode tint matching answer_btn_wrong_style's flash.
@export var wrong_color: Color          = Color(0.85, 0.25, 0.25, 1)
## Text colour for the "question N of total_questions_per_game" label.
@export var progress_label_color: Color = Color(0.75, 0.85, 1.0, 1)

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Assign a custom Font resource. Leave null to use the project theme font.
@export var font: Font = null
## Font size for the progress label.
@export var progress_font_size: int  = 32
## Font size for the question text.
@export var question_font_size: int  = 48
## Font size for each answer button's label.
@export var answer_btn_font_size: int = 36

# ─── Animation - Transitions ─────────────────────────────────────────────────
@export_group("Animation - Transitions")
## Fade-out before question swap
@export var question_fade_out_duration: float = 0.25
## Fade-in after question swap
@export var question_fade_in_duration: float  = 0.30

# ─── Animation - Feedback ───────────────────────────────────────────────────
@export_group("Animation - Feedback")
## Seconds before next question
@export var feedback_hold_duration: float = 0.9
## Modulate brightness on correct/wrong flash
@export var flash_highlight_scale: float  = 1.35

var active_questions: Array[Dictionary] = []
var current_question_index: int = 0
var expected_answer_index: int = -1
var is_submitting_answer: bool = false
var score: int = 0
var max_score: int = 3

@onready var progress_label: Label        = $VBoxContainer/ProgressLabel
@onready var question_label: Label        = $VBoxContainer/QuestionLabel
@onready var question_image: TextureRect  = $VBoxContainer/QuestionImage
@onready var choices_container: GridContainer = $VBoxContainer/ChoicesGrid

func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	setup_game()

func _apply_visual_exports() -> void:
	var bg = get_node_or_null("Background") as TextureRect
	if bg and background_texture:
		bg.texture = background_texture

func load_question_bank() -> Array:
	var file_path = "res://Assets/Data/pilihanganda_questions.json"
	if not FileAccess.file_exists(file_path):
		print("Question bank JSON not found at: ", file_path)
		return []
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		if json.data is Array:
			return json.data
	else:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
	return []

func setup_game() -> void:
	score = 0
	max_score = total_questions_per_game
	current_question_index = 0
	is_submitting_answer = false

	var pool = load_question_bank()
	if pool.is_empty():
		pool = fallback_questions.duplicate(true)

	pool.shuffle()
	active_questions.clear()
	var selected_slice = pool.slice(0, min(total_questions_per_game, pool.size()))
	for item in selected_slice:
		if item is Dictionary:
			active_questions.append(item as Dictionary)

	_show_current_question()

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

	if progress_label:
		progress_label.text = "Pertanyaan %d dari %d | Skor: %d" % [current_question_index + 1, active_questions.size(), score]
		progress_label.add_theme_font_size_override("font_size", progress_font_size)
		progress_label.add_theme_color_override("font_color", progress_label_color)
		if font:
			progress_label.add_theme_font_override("font", font)

	if question_label:
		question_label.text = q_data.get("question", "")
		question_label.add_theme_font_size_override("font_size", question_font_size)
		if font:
			question_label.add_theme_font_override("font", font)
		question_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if question_image:
		var img_path = q_data.get("image", null)
		if img_path and img_path is String and img_path != "":
			var file_name: String = (img_path as String).get_file()
			var fallback_path: String = "res://Assets/Images/" + file_name
			if ResourceLoader.exists(img_path):
				question_image.texture = load(img_path)
				question_image.visible = true
			elif ResourceLoader.exists(fallback_path):
				question_image.texture = load(fallback_path)
				question_image.visible = true
			else:
				question_image.texture = null
				question_image.visible = false
		else:
			question_image.texture = null
			question_image.visible = false

	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()

		var viewport_size = get_viewport_rect().size
		if choices_container is GridContainer:
			if viewport_size.x <= viewport_size.y:
				choices_container.columns = 1
			else:
				choices_container.columns = 2

		var original_choices: Array = q_data.get("choices", []).duplicate()
		var orig_correct_idx: int = int(q_data.get("correct_index", 0))
		var correct_text: String = ""
		if orig_correct_idx >= 0 and orig_correct_idx < original_choices.size():
			correct_text = original_choices[orig_correct_idx]

		var indices = range(original_choices.size())
		indices.shuffle()

		expected_answer_index = 0
		for i in range(indices.size()):
			var original_i = indices[i]
			if original_choices[original_i] == correct_text:
				expected_answer_index = i
				break

		for i in range(indices.size()):
			var choice_text = original_choices[indices[i]]
			var btn = Button.new()
			btn.text = choice_text
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, answer_btn_min_height)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.add_theme_font_size_override("font_size", answer_btn_font_size)
			if font:
				btn.add_theme_font_override("font", font)
			_apply_choice_btn_textures(btn)
			btn.pressed.connect(_on_choice_pressed.bind(i, btn))
			choices_container.add_child(btn)

	# Fade fresh content back in
	vbox.modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.tween_property(vbox, "modulate:a", 1.0, question_fade_in_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished

## Applies texture-based StyleBoxes and press animations to choice buttons.
func _apply_choice_btn_textures(btn: Button) -> void:
	if choice_btn_normal_texture == null:
		if answer_btn_normal_style:
			btn.add_theme_stylebox_override("normal", answer_btn_normal_style)
		return

	var sb_normal   = _make_btn_stylebox(choice_btn_normal_texture, Color.WHITE)
	var sb_pressed  = _make_btn_stylebox(choice_btn_normal_texture, choice_btn_pressed_tint)
	var sb_disabled = _make_btn_stylebox(choice_btn_normal_texture, choice_btn_disabled_tint)
	btn.add_theme_stylebox_override("normal",   sb_normal)
	btn.add_theme_stylebox_override("hover",    sb_normal)
	btn.add_theme_stylebox_override("pressed",  sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_stylebox_override("focus",    sb_normal)

	btn.pivot_offset = Vector2(btn.size.x / 2.0, answer_btn_min_height / 2.0)
	btn.resized.connect(func(): if is_instance_valid(btn): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(_on_choice_btn_down.bind(btn))
	btn.button_up.connect(_on_choice_btn_up.bind(btn))

func _on_choice_btn_down(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE * choice_btn_press_scale, choice_btn_press_duration)

func _on_choice_btn_up(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, choice_btn_press_duration)

## Builds a StyleBoxTexture from a Texture2D with a modulate tint and content margins.
func _make_btn_stylebox(tex: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.modulate_color = tint
	sb.texture_margin_left   = choice_btn_texture_margin
	sb.texture_margin_right  = choice_btn_texture_margin
	sb.texture_margin_top    = choice_btn_texture_margin
	sb.texture_margin_bottom = choice_btn_texture_margin
	return sb

func _flash_button_box(btn: Button, box_color: Color) -> void:
	if not btn or not is_instance_valid(btn):
		return

	if choice_btn_normal_texture:
		var flash_sb = _make_btn_stylebox(choice_btn_normal_texture, box_color)
		btn.add_theme_stylebox_override("disabled", flash_sb)
		btn.add_theme_stylebox_override("normal", flash_sb)
	elif box_color == correct_color and answer_btn_correct_style:
		btn.add_theme_stylebox_override("disabled", answer_btn_correct_style)
		btn.add_theme_stylebox_override("normal", answer_btn_correct_style)
	elif box_color == wrong_color and answer_btn_wrong_style:
		btn.add_theme_stylebox_override("disabled", answer_btn_wrong_style)
		btn.add_theme_stylebox_override("normal", answer_btn_wrong_style)
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = box_color
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("disabled", style)
		btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)

	# Bright highlight flash then smooth settle
	btn.modulate = Color(flash_highlight_scale, flash_highlight_scale, flash_highlight_scale)
	var tween = btn.create_tween()
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_choice_pressed(index: int, pressed_btn: Button) -> void:
	if is_submitting_answer or not is_game_active:
		return

	is_submitting_answer = true

	# Disable all choice buttons to prevent multi-taps during animation
	for child in choices_container.get_children():
		if child is Button:
			child.disabled = true

	if index == expected_answer_index:
		score += 1
		_flash_button_box(pressed_btn, correct_color)
		_play_jump_animation(pressed_btn)
	else:
		apply_time_penalty(3.0)
		_flash_button_box(pressed_btn, wrong_color)
		_play_wiggle_animation($VBoxContainer)

		# Highlight correct answer button in green box for educational feedback
		if expected_answer_index >= 0 and expected_answer_index < choices_container.get_child_count():
			var correct_btn = choices_container.get_child(expected_answer_index) as Button
			if correct_btn:
				_flash_button_box(correct_btn, correct_color)

	# Update progress label score immediately
	if progress_label:
		progress_label.text = "Pertanyaan %d dari %d | Skor: %d" % [current_question_index + 1, active_questions.size(), score]

	# Pause briefly before advancing to next question
	await get_tree().create_timer(feedback_hold_duration).timeout

	current_question_index += 1
	if current_question_index < active_questions.size():
		_show_current_question()
	else:
		_finish_quiz()

func reveal_answers() -> void:
	# Ensure the score subtitle is available for the timeout-triggered win path
	result_subtitle = "Skor Akhir: %d / %d" % [score, max_score]

	if not choices_container or expected_answer_index < 0:
		return
	
	for i in range(choices_container.get_child_count()):
		var child = choices_container.get_child(i)
		if child is Button:
			child.disabled = true
			if i != expected_answer_index:
				_flash_button_box(child, wrong_color)
				_play_wiggle_animation(child)
			else:
				_flash_button_box(child, correct_color)

func _finish_quiz() -> void:
	result_subtitle = "Skor Akhir: %d / %d" % [score, max_score]
	if score >= get_target_win_score():
		win_game()
	else:
		lose_game()
