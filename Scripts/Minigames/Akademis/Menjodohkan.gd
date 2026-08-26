extends BaseMinigame

# ─── Inspector-editable fallback question bank ────────────────────────────────
@export_group("Fallback Q&A")
@export var fallback_questions: Array[String] = [
	"Apa ibukota Indonesia?",
	"Siapa Presiden pertama?",
	"Candi terbesar di Indonesia?",
	"Pulau Dewata?"
]
@export var fallback_answers: Array[String] = [
	"Jakarta",
	"Soekarno",
	"Borobudur",
	"Bali"
]

@export_group("Card Templates")
@export var question_card_scene: PackedScene = preload("res://Scenes/Minigames/Akademis/QuestionCard.tscn")
@export var answer_card_scene: PackedScene   = preload("res://Scenes/Minigames/Akademis/AnswerCard.tscn")

# ─── Visual - Background ─────────────────────────────────────────────────────
@export_group("Visual - Background")
## Drag a background image here. Leave empty to use a solid colour via the scene.
@export var background_texture: Texture2D = null

# ─── Visual - Cards ──────────────────────────────────────────────────────────
@export_group("Visual - Cards")
## Drag a PNG here for Question card backgrounds.
@export var card_question_bg_texture: Texture2D = null
## Drag a PNG here for Answer card backgrounds.
@export var card_answer_bg_texture: Texture2D   = null

# ─── Visual - Buttons ────────────────────────────────────────────────────────
@export_group("Visual - Buttons")
## Drag a PNG here to replace navigation arrows (◀ and ▶ on both carousels).
@export var button_nav_texture: Texture2D    = null
## Drag a PNG here for the Lock / Unlock button.
@export var button_lock_texture: Texture2D   = null
## Drag a PNG here for the Submit button.
@export var button_submit_texture: Texture2D = null
## Grey tint applied when a button is pressed (0=black, 1=full colour).
@export var button_pressed_tint: Color   = Color(0.65, 0.65, 0.65, 1.0)
## Grey tint applied when buttons are disabled.
@export var button_disabled_tint: Color  = Color(0.55, 0.55, 0.55, 0.75)
## Scale the button shrinks to on press (e.g. 0.92 = 92% size).
@export var button_press_scale: float    = 0.92
## Duration of the press-shrink animation in seconds.
@export var button_press_duration: float = 0.07
## Margin (pixels) inside the button texture where content is drawn.
@export var button_texture_margin: int   = 8
## Fallback StyleBox overrides if no texture assigned (leave null = theme default).
@export var lock_btn_locked_style:     StyleBox = null
@export var lock_btn_cancel_style:     StyleBox = null
@export var submit_btn_active_style:   StyleBox = null
@export var submit_btn_disabled_style: StyleBox = null
@export var nav_btn_style:             StyleBox = null

# ─── Visual - Icons (replace emoji with textures) ─────────────────────────────
@export_group("Visual - Icons")
## Replaces the 🔒 emoji on progress badges. Leave null to keep emoji.
@export var badge_locked_texture: Texture2D = null

# ─── Visual - Colors ─────────────────────────────────────────────────────────
@export_group("Visual - Colors")
@export var correct_color: Color         = Color(0.3, 0.85, 0.4, 1)
@export var wrong_color: Color           = Color(0.9, 0.3, 0.3, 1)
@export var score_label_color: Color     = Color(0.75, 0.85, 1.0, 1)
@export var question_header_color: Color = Color(1.0, 0.7, 0.3, 1)
@export var answer_header_color: Color   = Color(0.4, 0.7, 1.0, 1)
@export var badge_default_color: Color   = Color(0.85, 0.85, 0.9, 1)
@export var badge_bg_color: Color        = Color(0.2, 0.25, 0.35, 0.9)

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
@export var font: Font = null
@export var title_font_size: int  = 48
@export var score_font_size: int  = 36
@export var header_font_size: int = 32
@export var button_font_size: int = 36
@export var badge_font_size: int  = 26

# ─── Animation - Transitions ─────────────────────────────────────────────────
@export_group("Animation - Transitions")
@export var carousel_step_duration: float = 0.26  ## Seconds per card wheel step

# ─── Animation - Cards ───────────────────────────────────────────────────────
@export_group("Animation - Cards")
@export var card_side_scale: float   = 0.75   ## Scale of non-focused cards
@export var card_side_alpha: float   = 0.35   ## Opacity of 1-away cards
@export var card_side_rotation: float = 5.0   ## Rotation degrees of side cards

# ─── Animation - Buttons ─────────────────────────────────────────────────────
@export_group("Animation - Buttons")
@export var btn_boing_squash_x: float   = 1.15  ## X scale at squash peak
@export var btn_boing_squash_y: float   = 0.80  ## Y scale at squash peak
@export var btn_wiggle_interval: float  = 1.8   ## Seconds between submit wiggles
@export var btn_wiggle_rot_deg: float   = 5.0   ## Degrees of submit button wiggle

@export_group("Configuration")
@export var questions_count: int = 4 # Default 4 questions

# ─── Runtime Data ────────────────────────────────────────────────────────────
var selected_pairs_data: Array = []
var questions: Array[String]   = []
var answers: Array[String]     = []
var correct_answer_indices: Array[int] = []

# Focus and Lock State
var current_q_focus: int = 0
var current_a_focus: int = 0
var locked_matches: Dictionary = {} # q_idx -> a_idx

var question_cards: Array[Control] = []
var answer_cards: Array[Control]   = []
var progress_badges: Array[Node]   = []

# Score tracking
var correct_matches: int   = 0
var incorrect_matches: int = 0
var score: int             = 0
var max_score: int         = 4

# Impatient Wiggle Tween
var submit_wiggle_tween: Tween = null

# Drag Swipe Gesture variables
var q_drag_start_x: float = 0.0
var q_is_dragging: bool   = false
var a_drag_start_x: float = 0.0
var a_is_dragging: bool   = false

# ─── Scene Nodes ─────────────────────────────────────────────────────────────
@onready var title_label: Label           = $HeaderVBox/TitleLabel
@onready var score_label: Label           = $HeaderVBox/ScoreLabel
@onready var progress_hbox: HBoxContainer = $HeaderVBox/ProgressHBox

@onready var top_carousel: Control          = $TopCarousel
@onready var q_wheel_parent: Control        = $TopCarousel/QuestionWheelParent
@onready var btn_prev_q: Button             = $TopCarousel/BtnPrevQ
@onready var btn_next_q: Button             = $TopCarousel/BtnNextQ

@onready var middle_action_bar: HBoxContainer = $MiddleActionBar
@onready var btn_lock: Button                 = $MiddleActionBar/BtnLock
@onready var btn_submit: Button               = $MiddleActionBar/BtnSubmit

@onready var bottom_carousel: Control       = $BottomCarousel
@onready var a_wheel_parent: Control        = $BottomCarousel/AnswerWheelParent
@onready var btn_prev_a: Button             = $BottomCarousel/BtnPrevA
@onready var btn_next_a: Button             = $BottomCarousel/BtnNextA

func _ready() -> void:
	super._ready()
	_apply_visual_exports()
	_connect_ui_signals()
	setup_game()

func _apply_visual_exports() -> void:
	# Apply background texture if provided
	var bg = get_node_or_null("Background") as TextureRect
	if bg and background_texture:
		bg.texture = background_texture
	# Apply nav button styles & single-PNG texture
	for btn in [btn_prev_q, btn_next_q, btn_prev_a, btn_next_a]:
		if btn:
			if button_nav_texture:
				_apply_custom_button(btn, button_nav_texture)
			elif nav_btn_style:
				btn.add_theme_stylebox_override("normal", nav_btn_style)
	# Apply initial lock and submit button textures
	if btn_lock and button_lock_texture:
		_apply_custom_button(btn_lock, button_lock_texture)
	if btn_submit and button_submit_texture:
		_apply_custom_button(btn_submit, button_submit_texture)
	elif btn_submit and submit_btn_disabled_style:
		btn_submit.add_theme_stylebox_override("normal", submit_btn_disabled_style)
	# Apply font overrides to static labels
	if font:
		for lbl in [title_label, score_label]:
			if lbl:
				lbl.add_theme_font_override("font", font)

func _apply_custom_button(btn: Button, tex: Texture2D) -> void:
	if not btn or not tex:
		return
	var sb_normal   = _make_btn_stylebox(tex, Color.WHITE)
	var sb_pressed  = _make_btn_stylebox(tex, button_pressed_tint)
	var sb_disabled = _make_btn_stylebox(tex, button_disabled_tint)
	btn.add_theme_stylebox_override("normal",   sb_normal)
	btn.add_theme_stylebox_override("hover",    sb_normal)
	btn.add_theme_stylebox_override("pressed",  sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_stylebox_override("focus",    sb_normal)

	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): if is_instance_valid(btn): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(_on_btn_down.bind(btn))
	btn.button_up.connect(_on_btn_up.bind(btn))

func _on_btn_down(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE * button_press_scale, button_press_duration)

func _on_btn_up(btn: Button) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, button_press_duration)

func _make_btn_stylebox(tex: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.modulate_color = tint
	sb.texture_margin_left   = button_texture_margin
	sb.texture_margin_right  = button_texture_margin
	sb.texture_margin_top    = button_texture_margin
	sb.texture_margin_bottom = button_texture_margin
	return sb

func start_minigame(game_difficulty: int, time_limit: float = 40.0) -> void:
	# Enforce 40 seconds time limit for Menjodohkan minigame
	super.start_minigame(game_difficulty, 40.0)
	
	# Responsive resize handler
	if get_viewport():
		get_viewport().size_changed.connect(func():
			call_deferred("_update_carousel_layout", true)
		)

func _connect_ui_signals() -> void:
	if btn_prev_q: btn_prev_q.pressed.connect(_rotate_q_carousel.bind(-1))
	if btn_next_q: btn_next_q.pressed.connect(_rotate_q_carousel.bind(1))
	if btn_prev_a: btn_prev_a.pressed.connect(_rotate_a_carousel.bind(-1))
	if btn_next_a: btn_next_a.pressed.connect(_rotate_a_carousel.bind(1))
	
	if btn_lock: btn_lock.pressed.connect(_on_btn_lock_pressed)
	if btn_submit: btn_submit.pressed.connect(_on_btn_submit_pressed)
	
	# Touch & Drag Swipe Gesture area connections
	if top_carousel:
		top_carousel.gui_input.connect(_on_top_carousel_gui_input)
	if bottom_carousel:
		bottom_carousel.gui_input.connect(_on_bottom_carousel_gui_input)

func load_question_bank() -> Array:
	var file_path = "res://Assets/Data/menjodohkan_questions.json"
	if not FileAccess.file_exists(file_path):
		print("Question bank JSON not found at: ", file_path)
		return []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK and json.data is Array:
		return json.data
	return []

func setup_game() -> void:
	is_revealing = false
	score = 0
	max_score = questions_count
	correct_matches = 0
	incorrect_matches = 0
	locked_matches.clear()
	current_q_focus = 0
	current_a_focus = 0
	
	_clear_containers()
	
	# Load question pool
	var pool = load_question_bank()
	if pool.is_empty():
		for i in range(fallback_questions.size()):
			var ans = fallback_answers[i] if i < fallback_answers.size() else ""
			pool.append({"question": fallback_questions[i], "answer": ans})
			
	pool.shuffle()
	selected_pairs_data = pool.slice(0, min(questions_count, pool.size()))
	
	# Create random order for question cards and answer cards independently
	var n = selected_pairs_data.size()
	var q_order: Array[int] = []
	var a_order: Array[int] = []
	for i in range(n):
		q_order.append(i)
		a_order.append(i)
	
	q_order.shuffle()
	
	# Guarantee derangement (no position i has a_order[i] == q_order[i])
	if n > 1:
		var has_collision = true
		for attempt in range(100):
			a_order.shuffle()
			has_collision = false
			for i in range(n):
				if a_order[i] == q_order[i]:
					has_collision = true
					break
			if not has_collision:
				break
		
		# Fallback deterministic shift if random shuffle didn't eliminate all collisions
		if has_collision:
			for i in range(n):
				a_order[i] = q_order[(i + 1) % n]
	else:
		a_order.shuffle()
	
	questions.clear()
	for pair_q_idx in q_order:
		questions.append(selected_pairs_data[pair_q_idx]["question"])
		
	answers.clear()
	for pair_a_idx in a_order:
		answers.append(selected_pairs_data[pair_a_idx]["answer"])
		
	correct_answer_indices.clear()
	for q_i in range(questions.size()):
		var target_pair_idx = q_order[q_i]
		correct_answer_indices.append(a_order.find(target_pair_idx))
		
	_build_progress_badges()
	_instantiate_cards(q_order, a_order)
	_update_score_ui()
	_update_action_bar_ui()
	
	# Initial Carousel positions
	call_deferred("_update_carousel_layout", true)

func _clear_containers() -> void:
	for child in q_wheel_parent.get_children():
		child.queue_free()
	for child in a_wheel_parent.get_children():
		child.queue_free()
	for child in progress_hbox.get_children():
		child.queue_free()
	question_cards.clear()
	answer_cards.clear()
	progress_badges.clear()

func _build_progress_badges() -> void:
	for i in range(questions.size()):
		var badge = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = badge_bg_color
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", style)
		
		var lbl = Label.new()
		lbl.text = "Q%d ⚪" % (i + 1)
		lbl.add_theme_font_size_override("font_size", badge_font_size)
		lbl.add_theme_color_override("font_color", badge_default_color)
		if font:
			lbl.add_theme_font_override("font", font)
		badge.add_child(lbl)
		
		progress_hbox.add_child(badge)
		progress_badges.append(lbl)

func _instantiate_cards(q_order: Array[int], a_order: Array[int]) -> void:
	# Question cards
	for i in range(questions.size()):
		var card = question_card_scene.instantiate() as Control
		q_wheel_parent.add_child(card)
		question_cards.append(card)
		
		var pair_q_idx = q_order[i]
		var txt_lbl = card.find_child("TextLabel", true, false) as Label
		if txt_lbl:
			txt_lbl.text = questions[i]
			var q_len = questions[i].length()
			if q_len <= 15:
				txt_lbl.add_theme_font_size_override("font_size", 36)
			elif q_len <= 32:
				txt_lbl.add_theme_font_size_override("font_size", 32)
			elif q_len <= 55:
				txt_lbl.add_theme_font_size_override("font_size", 28)
			else:
				txt_lbl.add_theme_font_size_override("font_size", 24)
				
		var img_rect = card.find_child("RowImage", true, false) as TextureRect
		if img_rect:
			var img_path = selected_pairs_data[pair_q_idx].get("image", "")
			if img_path != "" and ResourceLoader.exists(img_path):
				img_rect.texture = load(img_path)
				img_rect.visible = true
				if txt_lbl:
					txt_lbl.add_theme_font_size_override("font_size", 24)
			else:
				img_rect.visible = false
				
		var bg_tex = card.find_child("CardBgTexture", true, false) as TextureRect
		if bg_tex and card_question_bg_texture:
			bg_tex.texture = card_question_bg_texture
			var transparent_sb = StyleBoxEmpty.new()
			card.add_theme_stylebox_override("panel", transparent_sb)

		var q_idx = i
		card.gui_input.connect(func(event: InputEvent):
			_on_top_carousel_gui_input(event)
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if abs(event.global_position.x - q_drag_start_x) <= 10:
					current_q_focus = q_idx
					_update_carousel_layout()
					_update_action_bar_ui()
		)
			
	# Answer cards
	for i in range(answers.size()):
		var card = answer_card_scene.instantiate() as Control
		a_wheel_parent.add_child(card)
		answer_cards.append(card)
		
		var pair_a_idx = a_order[i]
		var txt_lbl = card.find_child("TextLabel", true, false) as Label
		if txt_lbl:
			txt_lbl.text = answers[i]
			var a_len = answers[i].length()
			if a_len <= 15:
				txt_lbl.add_theme_font_size_override("font_size", 36)
			elif a_len <= 30:
				txt_lbl.add_theme_font_size_override("font_size", 32)
			elif a_len <= 50:
				txt_lbl.add_theme_font_size_override("font_size", 28)
			else:
				txt_lbl.add_theme_font_size_override("font_size", 24)
			
		var img_rect = card.find_child("RowImage", true, false) as TextureRect
		if img_rect:
			var img_path = selected_pairs_data[pair_a_idx].get("answer_image", "")
			if img_path != "" and ResourceLoader.exists(img_path):
				img_rect.texture = load(img_path)
				img_rect.visible = true
			else:
				img_rect.visible = false
				
		var bg_tex = card.find_child("CardBgTexture", true, false) as TextureRect
		if bg_tex and card_answer_bg_texture:
			bg_tex.texture = card_answer_bg_texture
			var transparent_sb = StyleBoxEmpty.new()
			card.add_theme_stylebox_override("panel", transparent_sb)
			
		var a_idx = i
		card.gui_input.connect(func(event: InputEvent):
			_on_bottom_carousel_gui_input(event)
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if abs(event.global_position.x - a_drag_start_x) <= 10:
					current_a_focus = a_idx
					_update_carousel_layout()
					_update_action_bar_ui()
		)

func _update_score_ui() -> void:
	if score_label:
		score_label.text = "Pasangan Terjodohkan: %d dari %d | Skor: %d" % [locked_matches.size(), max_score, score]

func _update_action_bar_ui() -> void:
	if not is_game_active:
		return
		
	var is_q_locked = (current_q_focus in locked_matches)
	
	# Update Lock/Cancel Button (`BtnLock`)
	if is_q_locked:
		btn_lock.text = "" if button_lock_texture else "🔓 Batalkan"
		if button_lock_texture:
			var sb_cancel = _make_btn_stylebox(button_lock_texture, Color(1.0, 0.45, 0.45))
			btn_lock.add_theme_stylebox_override("normal", sb_cancel)
			btn_lock.add_theme_stylebox_override("hover", sb_cancel)
		elif lock_btn_cancel_style:
			btn_lock.add_theme_stylebox_override("normal", lock_btn_cancel_style)
		else:
			_set_button_style(btn_lock, Color(0.8, 0.25, 0.25), Color(1.0, 0.45, 0.45))
		btn_lock.disabled = false
	else:
		btn_lock.text = "" if button_lock_texture else "🔒 Kunci Jawaban!"
		var is_a_used = (current_a_focus in locked_matches.values())
		btn_lock.disabled = is_a_used
		
		if button_lock_texture:
			if is_a_used:
				var sb_dis = _make_btn_stylebox(button_lock_texture, button_disabled_tint)
				btn_lock.add_theme_stylebox_override("disabled", sb_dis)
			else:
				var sb_norm = _make_btn_stylebox(button_lock_texture, Color.WHITE)
				btn_lock.add_theme_stylebox_override("normal", sb_norm)
				btn_lock.add_theme_stylebox_override("hover", sb_norm)
		elif lock_btn_locked_style:
			btn_lock.add_theme_stylebox_override("normal", lock_btn_locked_style)
		else:
			_set_button_style(btn_lock, Color(0.85, 0.45, 0.1), Color(1, 0.65, 0.2))
		
	# Update Submit Button (`BtnSubmit`)
	var all_locked = (locked_matches.size() >= questions_count)
	btn_submit.disabled = not all_locked
	
	if button_submit_texture:
		btn_submit.text = ""
		if all_locked:
			var sb_act = _make_btn_stylebox(button_submit_texture, Color.WHITE)
			btn_submit.add_theme_stylebox_override("normal", sb_act)
			btn_submit.add_theme_stylebox_override("hover", sb_act)
		else:
			var sb_dis = _make_btn_stylebox(button_submit_texture, button_disabled_tint)
			btn_submit.add_theme_stylebox_override("disabled", sb_dis)
	
	if all_locked:
		_start_impatient_submit_wiggle()
	else:
		_stop_impatient_submit_wiggle()

func _set_button_style(btn: Button, bg_color: Color, border_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)

func _start_impatient_submit_wiggle() -> void:
	if submit_wiggle_tween and submit_wiggle_tween.is_valid():
		return
		
	btn_submit.pivot_offset = btn_submit.size / 2.0
	submit_wiggle_tween = create_tween().set_loops()
	submit_wiggle_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	submit_wiggle_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	submit_wiggle_tween.tween_property(btn_submit, "scale", Vector2(1.08, 0.92), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	submit_wiggle_tween.tween_property(btn_submit, "rotation_degrees", -btn_wiggle_rot_deg, 0.08)
	submit_wiggle_tween.tween_property(btn_submit, "rotation_degrees", btn_wiggle_rot_deg, 0.08)
	submit_wiggle_tween.tween_property(btn_submit, "rotation_degrees", -btn_wiggle_rot_deg * 0.6, 0.08)
	submit_wiggle_tween.tween_property(btn_submit, "rotation_degrees", 0.0, 0.08)
	submit_wiggle_tween.tween_property(btn_submit, "scale", Vector2(1.0, 1.0), 0.12)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	submit_wiggle_tween.tween_interval(btn_wiggle_interval)

func _stop_impatient_submit_wiggle() -> void:
	if submit_wiggle_tween:
		submit_wiggle_tween.kill()
		submit_wiggle_tween = null
	if btn_submit:
		btn_submit.scale = Vector2(1.0, 1.0)
		btn_submit.rotation_degrees = 0.0

# ─── Carousel Wheel Movement & 3D Roll Animation ─────────────────────────────
func _rotate_q_carousel(dir: int) -> void:
	if question_cards.is_empty(): return
	current_q_focus = posmod(current_q_focus + dir, question_cards.size())
	
	# Auto-redirect answer carousel to matched answer if question is locked
	if current_q_focus in locked_matches:
		current_a_focus = locked_matches[current_q_focus]
		
	_update_carousel_layout()
	_update_action_bar_ui()

func _rotate_a_carousel(dir: int) -> void:
	if answer_cards.is_empty(): return
	current_a_focus = posmod(current_a_focus + dir, answer_cards.size())
	
	# Auto-redirect question carousel to matched question if answer is locked
	if current_a_focus in locked_matches.values():
		for q_k in locked_matches.keys():
			if locked_matches[q_k] == current_a_focus:
				current_q_focus = q_k
				break
				
	_update_carousel_layout()
	_update_action_bar_ui()

func _update_carousel_layout(instant: bool = false) -> void:
	_animate_wheel(q_wheel_parent, question_cards, current_q_focus, instant)
	_animate_wheel(a_wheel_parent, answer_cards, current_a_focus, instant)

func _animate_wheel(parent_node: Control, cards: Array[Control], focus_idx: int, instant: bool) -> void:
	if cards.is_empty() or not parent_node: return
	
	var container_w = parent_node.size.x if parent_node.size.x > 0 else get_viewport_rect().size.x
	var container_h = parent_node.size.y if parent_node.size.y > 0 else (get_viewport_rect().size.y * 0.28)
	var center_x = container_w / 2.0
	
	var card_spacing = min(container_w * 0.80, 550.0)
	var count = cards.size()
	
	for i in range(count):
		var card = cards[i]
		card.pivot_offset = card.size / 2.0
		
		var offset = i - focus_idx
		if offset > count / 2:
			offset -= count
		elif offset < -count / 2:
			offset += count
			
		var target_x = center_x + (offset * card_spacing) - (card.size.x / 2.0)
		var label_h = 18.0
		var avail_h = max(10.0, container_h - label_h)
		var target_y = label_h + max(0.0, (avail_h / 2.0) - (card.size.y / 2.0))
		var target_pos = Vector2(target_x, target_y)
		
		var distance = abs(offset)
		var target_scale = Vector2(1.0, 1.0) if distance == 0 else Vector2(card_side_scale, card_side_scale)
		var target_alpha = 1.0 if distance == 0 else (card_side_alpha if distance == 1 else 0.0)
		var target_rot = 0.0 if distance == 0 else (sign(offset) * card_side_rotation)
		var z_ord = 10 - distance
		
		card.z_index = z_ord
		card.visible = (target_alpha > 0.05)
		
		if instant:
			card.position = target_pos
			card.scale = target_scale
			card.modulate.a = target_alpha
			card.rotation_degrees = target_rot
		else:
			var tw = create_tween().set_parallel(true)
			tw.tween_property(card, "position", target_pos, carousel_step_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", target_scale, carousel_step_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "modulate:a", target_alpha, carousel_step_duration)
			tw.tween_property(card, "rotation_degrees", target_rot, carousel_step_duration)

# ─── Touch & Drag Swipe Gesture Input ─────────────────────────────────────────
func _on_top_carousel_gui_input(event: InputEvent) -> void:
	if not is_game_active: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				q_drag_start_x = event.global_position.x
				q_is_dragging = true
			elif q_is_dragging:
				q_is_dragging = false
				var diff = event.global_position.x - q_drag_start_x
				if abs(diff) > 20:
					# Swiping left (diff < 0) moves next card (+1) to center
					# Swiping right (diff > 0) moves previous card (-1) to center
					_rotate_q_carousel(1 if diff < 0 else -1)
	elif event is InputEventScreenTouch:
		if event.pressed:
			q_drag_start_x = event.position.x
			q_is_dragging = true
		elif q_is_dragging:
			q_is_dragging = false
			var diff = event.position.x - q_drag_start_x
			if abs(diff) > 20:
				_rotate_q_carousel(1 if diff < 0 else -1)
	elif event is InputEventScreenDrag and q_is_dragging:
		var diff = event.position.x - q_drag_start_x
		if abs(diff) > 25:
			q_is_dragging = false
			_rotate_q_carousel(1 if diff < 0 else -1)

func _on_bottom_carousel_gui_input(event: InputEvent) -> void:
	if not is_game_active: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				a_drag_start_x = event.global_position.x
				a_is_dragging = true
			elif a_is_dragging:
				a_is_dragging = false
				var diff = event.global_position.x - a_drag_start_x
				if abs(diff) > 20:
					_rotate_a_carousel(1 if diff < 0 else -1)
	elif event is InputEventScreenTouch:
		if event.pressed:
			a_drag_start_x = event.position.x
			a_is_dragging = true
		elif a_is_dragging:
			a_is_dragging = false
			var diff = event.position.x - a_drag_start_x
			if abs(diff) > 20:
				_rotate_a_carousel(1 if diff < 0 else -1)
	elif event is InputEventScreenDrag and a_is_dragging:
		var diff = event.position.x - a_drag_start_x
		if abs(diff) > 25:
			a_is_dragging = false
			_rotate_a_carousel(1 if diff < 0 else -1)

# ─── Lock & Unlock Actions ───────────────────────────────────────────────────
func _on_btn_lock_pressed() -> void:
	if not is_game_active: return
	
	if current_q_focus in locked_matches:
		# CANCEL LOCK ("Batalkan")
		var prev_a = locked_matches[current_q_focus]
		locked_matches.erase(current_q_focus)
		
		_set_question_card_lock_state(current_q_focus, false)
		_set_answer_card_lock_state(prev_a, false)
		_update_badge_status(current_q_focus, "⚪")
		_play_button_boing(btn_lock)
		_update_score_ui()
		_update_action_bar_ui()
	else:
		# LOCK PAIR ("Kunci Jawaban!")
		if current_a_focus in locked_matches.values():
			_play_wiggle_animation(answer_cards[current_a_focus])
			return
			
		locked_matches[current_q_focus] = current_a_focus
		_set_question_card_lock_state(current_q_focus, true)
		_set_answer_card_lock_state(current_a_focus, true)
		_update_badge_status(current_q_focus, "🔒")
		
		_play_jump_animation(question_cards[current_q_focus])
		_play_jump_animation(answer_cards[current_a_focus])
		_play_button_boing(btn_lock)
		
		_update_score_ui()
		_update_action_bar_ui()
		
		_auto_advance_focus()

func _auto_advance_focus() -> void:
	if locked_matches.size() >= questions_count:
		return
		
	for i in range(1, questions_count + 1):
		var next_q = (current_q_focus + i) % questions_count
		if not (next_q in locked_matches):
			current_q_focus = next_q
			break
			
	for j in range(1, answers.size() + 1):
		var next_a = (current_a_focus + j) % answers.size()
		if not (next_a in locked_matches.values()):
			current_a_focus = next_a
			break
			
	_update_carousel_layout()
	_update_action_bar_ui()

func _set_question_card_lock_state(q_idx: int, is_locked: bool) -> void:
	if q_idx >= 0 and q_idx < question_cards.size():
		var card = question_cards[q_idx]
		var lock_ov = card.find_child("LockOverlay", true, false)
		if lock_ov:
			lock_ov.visible = is_locked

func _set_answer_card_lock_state(a_idx: int, is_locked: bool) -> void:
	if a_idx >= 0 and a_idx < answer_cards.size():
		var card = answer_cards[a_idx]
		var lock_ov = card.find_child("LockOverlay", true, false)
		if lock_ov:
			lock_ov.visible = is_locked

func _update_badge_status(q_idx: int, symbol: String) -> void:
	if q_idx >= 0 and q_idx < progress_badges.size():
		progress_badges[q_idx].text = "Q%d %s" % [q_idx + 1, symbol]

func _on_btn_submit_pressed() -> void:
	if not is_game_active: return
	_stop_impatient_submit_wiggle()
	_play_button_boing(btn_submit, func():
		reveal_answers()
	)

var is_revealing: bool = false

# ─── Automated Reveal Sequence ───────────────────────────────────────────────
func reveal_answers() -> void:
	if is_revealing:
		return
	is_revealing = true
	is_game_active = false
	_stop_impatient_submit_wiggle()
	if btn_lock: btn_lock.disabled = true
	if btn_submit: btn_submit.disabled = true
	if btn_prev_q: btn_prev_q.disabled = true
	if btn_next_q: btn_next_q.disabled = true
	if btn_prev_a: btn_prev_a.disabled = true
	if btn_next_a: btn_next_a.disabled = true
	
	# Hide all "Locked" overlays on both question cards and answer cards during reveal
	for q_i in range(question_cards.size()):
		_set_question_card_lock_state(q_i, false)
	for a_i in range(answer_cards.size()):
		_set_answer_card_lock_state(a_i, false)
	
	score = 0
	correct_matches = 0
	incorrect_matches = 0
	
	for q_i in range(questions.size()):
		current_q_focus = q_i
		
		var user_a_idx = locked_matches.get(q_i, -1)
		var correct_a_idx = correct_answer_indices[q_i]
		
		if user_a_idx == correct_a_idx:
			# MATCH IS CORRECT!
			current_a_focus = user_a_idx
			_update_carousel_layout()
			await get_tree().create_timer(0.4).timeout
			
			score += 1
			correct_matches += 1
			_update_badge_status(q_i, "✅")
			_play_jump_animation(question_cards[q_i])
			if user_a_idx >= 0 and user_a_idx < answer_cards.size():
				_play_jump_animation(answer_cards[user_a_idx])
			_update_score_ui()
			await get_tree().create_timer(0.85).timeout
			
		elif user_a_idx != -1:
			# MATCH IS INCORRECT!
			# Step 1: Show player's wrong choice in red wiggle
			current_a_focus = user_a_idx
			_update_carousel_layout()
			await get_tree().create_timer(0.4).timeout
			
			incorrect_matches += 1
			_update_badge_status(q_i, "❌")
			_play_wiggle_animation(question_cards[q_i])
			if user_a_idx >= 0 and user_a_idx < answer_cards.size():
				_play_wiggle_animation(answer_cards[user_a_idx])
			_update_score_ui()
			await get_tree().create_timer(0.85).timeout
			
			# Step 2: Auto-scroll to correct answer and highlight in green jump
			current_a_focus = correct_a_idx
			_update_carousel_layout()
			await get_tree().create_timer(0.4).timeout
			if correct_a_idx >= 0 and correct_a_idx < answer_cards.size():
				_play_jump_animation(answer_cards[correct_a_idx])
			await get_tree().create_timer(0.85).timeout
			
		else:
			# UNLOCKED / UNMATCHED QUESTION!
			current_a_focus = correct_a_idx
			_update_carousel_layout()
			await get_tree().create_timer(0.4).timeout
			
			incorrect_matches += 1
			_update_badge_status(q_i, "❌")
			_play_wiggle_animation(question_cards[q_i])
			_update_score_ui()
			
			# Highlight correct answer in green jump
			if correct_a_idx >= 0 and correct_a_idx < answer_cards.size():
				_play_jump_animation(answer_cards[correct_a_idx])
			await get_tree().create_timer(0.85).timeout
		
	_finish_quiz()

func _finish_quiz() -> void:
	result_subtitle = "Skor Akhir: %d / %d" % [score, max_score]
	if score >= get_target_win_score():
		win_game()
	else:
		_show_result_overlay(false, result_subtitle)

func _play_button_boing(btn: Button, on_complete: Callable = Callable()) -> void:
	if not btn or not is_instance_valid(btn):
		if on_complete.is_valid(): on_complete.call()
		return
		
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(btn, "scale", Vector2(btn_boing_squash_x, btn_boing_squash_y), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(2.0 - btn_boing_squash_x, 2.0 - btn_boing_squash_y + 0.18), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	if on_complete.is_valid():
		tween.tween_callback(on_complete)
