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
		"image": "res://Assets/Images/monas.png"
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
## Scale the button shrinks to on press (e.g. 0.96 = 96% size).
@export var choice_btn_press_scale: float    = 0.96
## Duration of the press-shrink animation in seconds.
@export var choice_btn_press_duration: float = 0.07
## Minimum height (px) of each answer button, regardless of text length.
## 130 is the project's ~48dp touch floor in the 1080-wide design space;
## this shipped at 100 until 2026-09-21.
@export var answer_btn_min_height: int       = 130


# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Fits the question to the card, the same helper Password and Variabel use.
const SoalFit := preload("res://Scripts/Minigames/Akademis/SoalFit.gd")

## Largest size for the question text; SoalFit shrinks from here when a
## long question will not fit the card. T3 (73) of the minigame ladder.
@export var question_font_size: int  = MinigameType.T3
## Smallest size SoalFit will shrink a long question to: T2 (45), one rung
## down, never lower (spec 2026-09-30 minigame hierarchy, 3).
@export var min_question_font_size: int = MinigameType.T2

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

@onready var score_hud: MinigameHeader = %MinigameHeader
## The shared QuestionCard (Password and Variabel instance the same scene).
## It owns the picture, the question and the "Soal N/M" badge, which used to
## be three loose siblings here in the wrong reading order.
@onready var soal_card: Control           = %SoalCard
@onready var question_label: Label = soal_card.find_child("TextLabel", true, false) as Label
@onready var question_image: TextureRect = soal_card.find_child("RowImage", true, false) as TextureRect
@onready var progress_label: Label = soal_card.find_child("BadgeLabel", true, false) as Label
@onready var choices_container: GridContainer = %ChoicesGrid
## The answer tray; it fades with the card between questions.
@onready var answer_tray: Control = %MinigameTray

func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	# B1 (2026-09-30): the first question used to be fitted before the card
	# was laid out, so SoalFit measured a sliver and fell to its floor. Refit
	# whenever the label settles into its real size.
	question_label.resized.connect(_refit_question)
	setup_game()


## Refit the current question to the label's laid-out size.
func _refit_question() -> void:
	if question_label.text.is_empty():
		return
	question_label.add_theme_font_size_override("font_size",
		_fit_font_size(question_label.text))

## Largest size, from question_font_size down to min_question_font_size, at
## which the question fits the card without running under its "Soal N/M"
## badge. Password and Variabel fit their problem text the same way.
func _fit_font_size(text: String) -> int:
	return SoalFit.font_size(question_label, null, text,
		question_font_size, min_question_font_size)


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
	if score_hud:
		score_hud.setup(load("res://Assets/Images/UI/Placeholders/icon_akademis.svg"), max_score)

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

	# The card and the tray fade between questions; the strip stays put.
	var faded: Array[Control] = [soal_card, answer_tray]

	# Fade out before swapping content.
	# Skip on question 0 — SchoolDay already handles the minigame entrance fade.
	if current_question_index > 0:
		var tween_out = create_tween().set_parallel(true)
		for node in faded:
			tween_out.tween_property(node, "modulate:a", 0.0, question_fade_out_duration)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween_out.finished

	# ── Swap content while invisible ─────────────────────────────────────────
	is_submitting_answer = false
	var q_data = active_questions[current_question_index]

	# The counter lives on the strip's progress bar now; the card's badge
	# no longer reserves room, so it stays hidden.
	show_question_progress(current_question_index, active_questions.size(), soal_card)

	if question_label:
		question_label.text = q_data.get("question", "")
		question_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		question_label.add_theme_font_size_override("font_size",
			_fit_font_size(question_label.text))

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

		choices_container.columns = 1

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
			btn.theme_type_variation = &"MinigameChoiceButton"
			_wire_choice_btn(btn)
			btn.pressed.connect(_on_choice_pressed.bind(i, btn))
			choices_container.add_child(btn)

	# Fade fresh content back in
	var tween_in = create_tween().set_parallel(true)
	for node in faded:
		node.modulate.a = 0.0
		tween_in.tween_property(node, "modulate:a", 1.0, question_fade_in_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished

## Wires an answer button's press feel. Its chrome is the theme's
## MinigameChoiceButton, set where the button is made.
func _wire_choice_btn(btn: Button) -> void:
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

## Flash an answer right or wrong. The colours are theme variations
## (MinigameChoiceButtonCorrect / Wrong), whose disabled state keeps the flash,
## since the button is already disabled when it lands.
func _flash_button_box(btn: Button, correct: bool) -> void:
	if not btn or not is_instance_valid(btn):
		return
	btn.theme_type_variation = (&"MinigameChoiceButtonCorrect" if correct
		else &"MinigameChoiceButtonWrong")

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
		if score == 1:
			hint_settle()
		if score_hud:
			score_hud.set_score(score)
		_flash_button_box(pressed_btn, true)
		_play_jump_animation(pressed_btn)
	else:
		apply_time_penalty(3.0)
		_flash_button_box(pressed_btn, false)
		_play_wiggle_animation(soal_card)

		# Highlight correct answer button in green box for educational feedback
		if expected_answer_index >= 0 and expected_answer_index < choices_container.get_child_count():
			var correct_btn = choices_container.get_child(expected_answer_index) as Button
			if correct_btn:
				_flash_button_box(correct_btn, true)

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
				_flash_button_box(child, false)
				_play_wiggle_animation(child)
			else:
				_flash_button_box(child, true)

func _finish_quiz() -> void:
	set_progress(active_questions.size(), active_questions.size(),
		"Soal %d/%d" % [active_questions.size(), active_questions.size()])
	result_subtitle = "Skor Akhir: %d / %d" % [score, max_score]
	if score >= get_target_win_score():
		win_game()
	else:
		lose_game()
