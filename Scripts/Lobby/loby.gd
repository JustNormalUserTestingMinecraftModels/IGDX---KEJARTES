extends Control

@export_group("UI Textures")
@export var btn_texture: Texture2D
@export var btn_texture_student: Texture2D
@export var btn_texture_koperasi: Texture2D
@export var btn_texture_report: Texture2D
@export var btn_texture_inventory: Texture2D
@export var btn_texture_jadwal: Texture2D

@export_group("Background Layers")
@export var bg_texture: Texture2D
@export var tables_overlay_texture: Texture2D
@export var default_portrait: Texture2D = preload("res://Assets/Images/MuridPotrait/Thea.png")

@export_group("Hand Portraits by Persona")
@export var hand_tekun: Texture2D = preload("res://Assets/Images/Lobby/Hands/hand_tekun.png")
@export var hand_aktif: Texture2D = preload("res://Assets/Images/Lobby/Hands/hand_aktif.png")
@export var hand_kreatif: Texture2D = preload("res://Assets/Images/Lobby/Hands/hand_kreatif.png")
@export var hand_pendiam: Texture2D = preload("res://Assets/Images/Lobby/Hands/hand_pendiam.png")
@export var hand_santai: Texture2D = preload("res://Assets/Images/Lobby/Hands/hand_santai.png")

@export_group("Button Styling")
@export var btn_font_size: int = 42
@export var btn_font_color: Color = Color(0.93, 0.93, 0.93)
@export var btn_outline_color: Color = Color(0, 0, 0, 0.6)

@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea
@onready var student_button = $Student
@onready var jadwal_button = $Jadwal
@onready var koperasi_button = $Koperasi
@onready var report_student_button = $ReportStudent
@onready var inventory_button = $Inventory

@onready var money_label = $DisplayUang/Label
@onready var daily_login_btn = $DailyLogin
@onready var daily_reward = $DailyLogin/DailyReward
@onready var claim_button = $DailyLogin/DailyReward/ButtonClaim
@onready var day_nodes = {
	1: $DailyLogin/DailyReward/Day1,
	2: $DailyLogin/DailyReward/Day2,
	3: $DailyLogin/DailyReward/Day3,
	4: $DailyLogin/DailyReward/Day4,
	5: $DailyLogin/DailyReward/Day5,
	6: $DailyLogin/DailyReward/Day6,
	7: $DailyLogin/DailyReward/Day7,
}

@onready var portrait_slots = [
	$StudentPortraitsContainer_Back/Slot1,
	$StudentPortraitsContainer_Back/Slot2,
	$StudentPortraitsContainer_Front/Slot3,
	$StudentPortraitsContainer_Front/Slot4,
]
@onready var hand_slots = [
	$StudentHandsContainer_Back/Slot1,
	$StudentHandsContainer_Back/Slot2,
	$StudentHandsContainer_Front/Slot3,
	$StudentHandsContainer_Front/Slot4,
]

const DAILY_REWARD := 10

@export_group("Tutorial")
@export var tutorial_phase1_steps: Array[TutorialStepData] = []
@export var tutorial_phase2_steps: Array[TutorialStepData] = []
@export var custom_panel_texture: Texture2D = preload("res://Assets/Images/UI/tutorial_panel_bg.png")
@export var custom_panel_stylebox: StyleBox = null

const TutorialArrow = preload("res://Scripts/TutorialArrow.gd")

var current_step := 0
var current_phase_steps: Array[TutorialStepData] = []
var tutorial_active := true
var _tutorial_panel: PanelContainer
var _tutorial_title_label: Label
var _tutorial_body_label: Label
var _tutorial_prompt_label: Label
var _tutorial_panel_should_center: bool = false
var _blink_tween: Tween
var _tutorial_arrow: Control = null

var blur_overlay: ColorRect
var reward_popup_open := false

@onready var bg_layer = $BGLayer

func _ready():
	if bg_texture:
		bg_layer.texture = bg_texture
	else:
		bg_layer.texture = load("res://Assets/Images/UI/loby.png")
		


	if not hand_tekun:
		hand_tekun = load("res://Assets/Images/Lobby/Hands/hand_tekun.png")
	if not hand_aktif:
		hand_aktif = load("res://Assets/Images/Lobby/Hands/hand_aktif.png")
	if not hand_kreatif:
		hand_kreatif = load("res://Assets/Images/Lobby/Hands/hand_kreatif.png")
	if not hand_pendiam:
		hand_pendiam = load("res://Assets/Images/Lobby/Hands/hand_pendiam.png")
	if not hand_santai:
		hand_santai = load("res://Assets/Images/Lobby/Hands/hand_santai.png")

	if GameState.has_method("initialize_grade_targets"):
		GameState.initialize_grade_targets()

	_setup_students()

	if tutorial_phase1_steps.is_empty() or tutorial_phase2_steps.is_empty():
		_populate_default_tutorial_steps()

	var viewport_size = get_viewport_rect().size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	call_deferred("_fit_color_rect_to_viewport")
	get_tree().root.size_changed.connect(_fit_color_rect_to_viewport)

	_tutorial_arrow = TutorialArrow.new()
	_tutorial_arrow.visible = false
	color_rect.add_child(_tutorial_arrow)

	_build_tutorial_panel()

	for btn in [student_button, jadwal_button, koperasi_button, report_student_button, inventory_button, daily_login_btn, claim_button]:
		_setup_button_juice(btn)

	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	if GameState.lobby_tutorial_completed or GameState.minggu_ke > 1:
		GameState.lobby_tutorial_completed = true
		color_rect.hide()
		tutorial_active = false
		student_button.visible = false
		jadwal_button.visible = true
		if student_button is BaseButton:
			student_button.disabled = false
		else:
			student_button.mouse_filter = Control.MOUSE_FILTER_STOP
		
		if not student_button.pressed.is_connected(_on_student_pressed):
			student_button.pressed.connect(_on_student_pressed)
		if not jadwal_button.pressed.is_connected(_on_jadwal_pressed):
			jadwal_button.pressed.connect(_on_jadwal_pressed)

		_create_blur_overlay()
		_setup_daily_login()
		return

	if GameState.returned_from_student_card:
		student_button.visible = false
		jadwal_button.visible = true
		current_phase_steps = tutorial_phase2_steps.duplicate()
	else:
		student_button.visible = true
		jadwal_button.visible = false

		if student_button is BaseButton:
			student_button.disabled = true
		else:
			student_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

		current_phase_steps = tutorial_phase1_steps.duplicate()

	if not student_button.pressed.is_connected(_on_student_pressed):
		student_button.pressed.connect(_on_student_pressed)
	if not jadwal_button.pressed.is_connected(_on_jadwal_pressed):
		jadwal_button.pressed.connect(_on_jadwal_pressed)

	if click_area.has_signal("pressed"):
		if not click_area.pressed.is_connected(_next_step):
			click_area.pressed.connect(_next_step)
	else:
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		if not click_area.gui_input.is_connected(_on_click_area_gui_input):
			click_area.gui_input.connect(_on_click_area_gui_input)

	_show_step(0)
	_create_blur_overlay()
	_setup_daily_login()

func _setup_students():
	var students = GameState.approved_students.duplicate()
	if students.size() == 0:
		for s in portrait_slots: s.hide()
		for h in hand_slots: h.hide()
		return

	var ordered = _compute_seat_order(students)
	for i in range(portrait_slots.size()):
		var p_slot = portrait_slots[i]
		var h_slot = hand_slots[i]
		if i < ordered.size() and ordered[i] != null:
			p_slot.show()
			h_slot.show()
			var s = ordered[i]
			var portrait_node = p_slot.get_node("Portrait")
			var hand_node = h_slot.get_node("Hand")
			
			var port_path = s.get("portrait", "")
			if port_path != "" and ResourceLoader.exists(port_path):
				portrait_node.texture = load(port_path)
			else:
				portrait_node.texture = default_portrait
				
			var p_val = str(s.get("persona", "")) + " " + str(s.get("personality", ""))
			if "Tekun" in p_val:
				hand_node.texture = hand_tekun
			elif "Aktif" in p_val:
				hand_node.texture = hand_aktif
			elif "Kreatif" in p_val:
				hand_node.texture = hand_kreatif
			elif "Pendiam" in p_val or "Kesunyian" in p_val:
				hand_node.texture = hand_pendiam
			else:
				hand_node.texture = hand_santai
			
			hand_node.show()
			var breathing_delay = float(i) * 0.4
			_animate_breathing(portrait_node, breathing_delay)
		else:
			p_slot.hide()
			h_slot.hide()

func _animate_breathing(node: Control, delay: float):
	if not node: return
	# Wait one frame so the node's size is properly calculated before setting pivot
	await get_tree().process_frame
	if not is_instance_valid(node): return
	
	node.pivot_offset = Vector2(node.size.x / 2.0, node.size.y)
	var tw = create_tween().set_loops()
	
	# Start with a delay so they don't breathe perfectly in sync
	if delay > 0:
		tw.tween_interval(delay)
		
	# Subtle breathing up and down
	# Time to inhale (expand slightly)
	tw.tween_property(node, "scale", Vector2(1.01, 1.02), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Time to exhale (shrink back to normal)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _compute_seat_order(students: Array) -> Array:
	if not GameState.has_method("get_grade_from_week"):
		return students # Fallback if GameState isn't updated
	var seed_val = GameState.get_grade_from_week()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val * 1337 + 42

	var front_candidates = []
	var back_candidates = []

	for s in students:
		var gender = s.get("gender", "")
		var profil = s.get("profil", "")
		var is_female = (gender == "Perempuan") or ("Perempuan" in profil)
		var quirk = s.get("quirk", "")
		var is_nerd = (quirk == "Kutu Buku")
		
		# Priority for front row seats: Female students or Kutu Buku
		if is_female or is_nerd:
			front_candidates.append(s)
		else:
			back_candidates.append(s)

	# Keep max 2 candidates in the front row
	while front_candidates.size() > 2:
		var overflow_idx = rng.randi() % front_candidates.size()
		var overflow = front_candidates[overflow_idx]
		front_candidates.remove_at(overflow_idx)
		back_candidates.append(overflow)
		
	while front_candidates.size() < 2 and back_candidates.size() > 0:
		var pull_idx = rng.randi() % back_candidates.size()
		var pull = back_candidates[pull_idx]
		back_candidates.remove_at(pull_idx)
		front_candidates.append(pull)

	_seeded_shuffle(front_candidates, rng)
	_seeded_shuffle(back_candidates, rng)

	# Back row seats are Slot1 & Slot2 (Indices 0 & 1)
	# Front row seats are Slot3 & Slot4 (Indices 2 & 3)
	var ordered = []
	ordered.append(back_candidates[0]  if back_candidates.size()  > 0 else null)
	ordered.append(back_candidates[1]  if back_candidates.size()  > 1 else null)
	ordered.append(front_candidates[0] if front_candidates.size() > 0 else null)
	ordered.append(front_candidates[1] if front_candidates.size() > 1 else null)
	return ordered

func _seeded_shuffle(arr: Array, rng: RandomNumberGenerator):
	if arr.size() <= 1:
		return
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func _apply_lobby_button_style(btn: Button, tex: Texture2D) -> void:
	if not btn: return
	
	btn.add_theme_font_size_override("font_size", btn_font_size)
	btn.add_theme_color_override("font_color", btn_font_color)
	btn.add_theme_color_override("font_hover_color", btn_font_color)
	btn.add_theme_color_override("font_pressed_color", btn_font_color)
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", btn_outline_color)
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF

	if tex:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var s := StyleBoxTexture.new()
			s.texture = tex
			s.texture_margin_left = 32
			s.texture_margin_right = 32
			s.texture_margin_top = 16
			s.texture_margin_bottom = 16
			s.content_margin_left = 32
			s.content_margin_right = 32
			
			if state == "hover":
				s.modulate_color = Color(1.1, 1.1, 1.1)
			elif state == "pressed":
				s.modulate_color = Color(0.9, 0.9, 0.9)
			elif state == "disabled":
				s.modulate_color = Color(0.5, 0.5, 0.5)
				
			btn.add_theme_stylebox_override(state, s)
	else:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var s = StyleBoxFlat.new()
			match state:
				"hover":    s.bg_color = Color(0.25, 0.35, 0.45)
				"pressed":  s.bg_color = Color(0.15, 0.22, 0.28)
				"disabled": s.bg_color = Color(0.18, 0.22, 0.26)
				_:          s.bg_color = Color(0.17, 0.25, 0.31)
			s.corner_radius_top_left    = 10
			s.corner_radius_top_right   = 10
			s.corner_radius_bottom_left = 10
			s.corner_radius_bottom_right= 10
			s.border_width_left   = 5
			s.border_width_top    = 5
			s.border_width_right  = 5
			s.border_width_bottom = 5
			s.border_color = Color(0.50, 0.51, 0.52)
			s.content_margin_left   = 32
			s.content_margin_right  = 32
			s.content_margin_top    = 16
			s.content_margin_bottom = 16
			s.shadow_color  = Color(0, 0, 0, 0.4)
			s.shadow_size   = 8
			s.shadow_offset = Vector2(0, 4)
			btn.add_theme_stylebox_override(state, s)

func _populate_default_tutorial_steps():
	if tutorial_phase1_steps.is_empty():
		var p1 = [
			["Selamat Datang!", "Halo! Sebelum anda terjun untuk mengajar generasi muda di sekolah ini.\n\nMari kita mengenali fasilitas untuk menunjang perjalananmu!", "", ""],
			["Pilih Muridmu", "Hmmm, kepikiran kalau kelasmu masih sepi, belum ada murid?\n\nAyo, kita langsung saja pilih muridmu!", "Student", "Tekan tombol 'Student' untuk lanjut!"]
		]
		for entry in p1:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase1_steps.append(step)

	if tutorial_phase2_steps.is_empty():
		var p2 = [
			["Pilihan Bagus!", "Pilihan yang sangat bagus!", "", ""],
			["Inventory", "Inventory adalah tempat dimana seluruh items kalian berada!", "Inventory", ""],
			["Raport Murid", "Raport adalah untuk melihat secara keseluruhan stats murid anda!", "ReportStudent", ""],
			["Koperasi Sekolah", "Koperasi adalah dimana kalian dapat belanja item dan customisasi untuk murid-murid ampu kalian!", "Koperasi", ""],
			["Jadwal Sekolah", "Ahh, sepertinya bel sekolah sudah berbunyi.", "Jadwal", "Tekan tombol 'Jadwal' untuk lanjut!"]
		]
		for entry in p2:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase2_steps.append(step)

func _build_tutorial_panel():
	var viewport_size = get_viewport_rect().size

	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.name = "TutorialPanel"
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBox
	if custom_panel_stylebox:
		style = custom_panel_stylebox
	elif custom_panel_texture:
		var tex_style = StyleBoxTexture.new()
		tex_style.texture = custom_panel_texture
		tex_style.texture_margin_left = 40
		tex_style.texture_margin_top = 40
		tex_style.texture_margin_right = 40
		tex_style.texture_margin_bottom = 40
		tex_style.content_margin_left = 36
		tex_style.content_margin_top = 28
		tex_style.content_margin_right = 36
		tex_style.content_margin_bottom = 24
		style = tex_style
	else:
		var flat = StyleBoxFlat.new()
		flat.bg_color = Color(0.17, 0.25, 0.31, 0.95) # Blackboard dark teal #2c3e50
		flat.corner_radius_top_left = 18
		flat.corner_radius_top_right = 18
		flat.corner_radius_bottom_left = 18
		flat.corner_radius_bottom_right = 18
		flat.border_width_left = 4
		flat.border_width_top = 4
		flat.border_width_right = 4
		flat.border_width_bottom = 4
		flat.border_color = Color(0.50, 0.51, 0.52) # Chalk grey #7f8c8d
		flat.shadow_color = Color(0, 0, 0, 0.5)
		flat.shadow_size = 12
		flat.content_margin_left = 28
		flat.content_margin_top = 20
		flat.content_margin_right = 28
		flat.content_margin_bottom = 16
		style = flat
	_tutorial_panel.add_theme_stylebox_override("panel", style)

	var panel_width = min(viewport_size.x * 0.92, 1000)
	_tutorial_panel.custom_minimum_size = Vector2(panel_width, 0)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	_tutorial_panel.add_child(vbox)

	_tutorial_title_label = Label.new()
	_tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_title_label.add_theme_font_size_override("font_size", 56)
	_tutorial_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7)) # Chalk yellow
	_tutorial_title_label.add_theme_constant_override("outline_size", 6)
	_tutorial_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	vbox.add_child(_tutorial_title_label)

	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.add_theme_font_size_override("font_size", 40)
	_tutorial_body_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98)) # Chalk white
	_tutorial_body_label.add_theme_constant_override("line_spacing", 8)
	_tutorial_body_label.custom_minimum_size = Vector2(panel_width - 60, 0)
	vbox.add_child(_tutorial_body_label)

	var sep2 = HSeparator.new()
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep2)

	_tutorial_prompt_label = Label.new()
	_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"
	_tutorial_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_prompt_label.add_theme_font_size_override("font_size", 32)
	_tutorial_prompt_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6)) # Chalk green
	_tutorial_prompt_label.add_theme_constant_override("outline_size", 5)
	_tutorial_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	vbox.add_child(_tutorial_prompt_label)

	color_rect.add_child(_tutorial_panel)
	var click_idx = click_area.get_index()
	color_rect.move_child(_tutorial_panel, click_idx)

	_start_prompt_blink()
	call_deferred("_position_tutorial_panel")

func _start_prompt_blink():
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_tutorial_prompt_label.modulate.a = 1.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 0.25, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 1.0, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _position_tutorial_panel(force_center: bool = false):
	if not _tutorial_panel or not is_instance_valid(_tutorial_panel):
		return
	var viewport_size = get_viewport_rect().size
	_tutorial_panel.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(_tutorial_panel):
		return
	var panel_size = _tutorial_panel.size

	var target_y: float
	if force_center or _tutorial_panel_should_center:
		target_y = (viewport_size.y - panel_size.y) / 2.0
	else:
		var min_y = viewport_size.y * 0.55
		var ideal_y = viewport_size.y - panel_size.y - 40
		target_y = max(min_y, ideal_y)

	_tutorial_panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2.0,
		target_y
	)
	_tutorial_panel.pivot_offset = panel_size / 2.0

func _fit_color_rect_to_viewport():
	var viewport_size = get_viewport_rect().size
	color_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	color_rect.position = -global_position
	color_rect.size = viewport_size
	if click_area:
		click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_area.position = Vector2.ZERO
		click_area.size = viewport_size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	if tutorial_active and _tutorial_panel and is_instance_valid(_tutorial_panel):
		call_deferred("_position_tutorial_panel")

func _create_blur_overlay():
	blur_overlay = ColorRect.new()
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.color = Color(0, 0, 0, 0)
	var shader = load("res://Scripts/Shaders/blur.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("lod", 0.0)
	mat.set_shader_parameter("darkness", 0.0)
	blur_overlay.material = mat
	blur_overlay.visible = false
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blur_overlay)
	# Place blur_overlay just before DailyLogin so it renders on top of other UI but behind the popup
	move_child(blur_overlay, daily_login_btn.get_index())
	# Connect click on blur overlay to close popup
	blur_overlay.gui_input.connect(_on_blur_overlay_input)

func _setup_daily_login():
	# Hide the reward panel initially
	if daily_reward:
		daily_reward.visible = false
	_update_money_display()
	_check_daily_login_reset()
	_update_daily_login_visual()
	if claim_button and not claim_button.pressed.is_connected(_on_claim_pressed):
		claim_button.pressed.connect(_on_claim_pressed)
	if daily_login_btn and not daily_login_btn.pressed.is_connected(_on_daily_login_pressed):
		daily_login_btn.pressed.connect(_on_daily_login_pressed)

func _update_money_display():
	if money_label:
		money_label.text = str(GameState.player_money) + "G"

func _check_daily_login_reset():
	var today = Time.get_date_string_from_system()
	if GameState.last_claim_date == "" or GameState.last_claim_date == today:
		return
	var today_unix = Time.get_unix_time_from_datetime_string(today + " 00:00:00")
	var last_claim_unix = Time.get_unix_time_from_datetime_string(GameState.last_claim_date + " 00:00:00")
	if today_unix - last_claim_unix > 86400:
		# lewat lebih dari 1 hari tanpa klaim, streak reset ke Day1
		GameState.daily_login_day = 1

func _update_daily_login_visual():
	var today = Time.get_date_string_from_system()
	var already_claimed_today = GameState.last_claim_date == today

	for day_num in day_nodes.keys():
		var node = day_nodes[day_num]
		if not node:
			continue
		if day_num < GameState.daily_login_day:
			node.modulate = Color(0.5, 0.5, 0.5, 1.0)
		elif day_num == GameState.daily_login_day:
			node.modulate = Color(0.5, 0.5, 0.5, 1.0) if already_claimed_today else Color(1.0, 1.0, 0.6, 1.0)
		else:
			node.modulate = Color(1, 1, 1, 0.5)

	if claim_button and claim_button is BaseButton:
		claim_button.disabled = already_claimed_today

func _on_daily_login_pressed():
	if reward_popup_open:
		return
	_show_daily_reward()

func _show_daily_reward():
	if not daily_reward:
		return
	reward_popup_open = true

	# Show and animate blur overlay
	blur_overlay.visible = true
	var blur_mat = blur_overlay.material as ShaderMaterial
	blur_mat.set_shader_parameter("lod", 0.0)
	blur_mat.set_shader_parameter("darkness", 0.0)

	# Show and animate popup
	daily_reward.visible = true
	daily_reward.modulate = Color(1, 1, 1, 0)
	daily_reward.scale = Vector2(0.8, 0.8)
	daily_reward.pivot_offset = daily_reward.size / 2.0

	var tween = create_tween().set_parallel(true)
	tween.tween_property(daily_reward, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(daily_reward, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_method(_set_blur_lod, 0.0, 3.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_blur_darkness, 0.0, 0.3, 0.25).set_ease(Tween.EASE_OUT)

func _hide_daily_reward():
	if not daily_reward:
		return
	reward_popup_open = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(daily_reward, "modulate", Color(1, 1, 1, 0), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(daily_reward, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_lod, 3.0, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_darkness, 0.3, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): daily_reward.visible = false; blur_overlay.visible = false)

func _on_blur_overlay_input(event: InputEvent):
	if not reward_popup_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_daily_reward()
	elif event is InputEventScreenTouch and event.pressed:
		_hide_daily_reward()

func _set_blur_lod(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("lod", value)

func _set_blur_darkness(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("darkness", value)

func _setup_button_juice(btn: Control):
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_btn_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))

func _on_btn_mouse_entered(btn: Control):
	if not is_instance_valid(btn) or (btn is BaseButton and btn.disabled):
		return
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.15)

func _on_btn_mouse_exited(btn: Control):
	if not is_instance_valid(btn):
		return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)

func _animate_button_click_bounce(btn: Control):
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(0.8, 1.25), 0.08)
	tw.tween_property(btn, "scale", Vector2(1.18, 0.85), 0.1)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)

func _on_claim_pressed():
	_animate_button_click_bounce(claim_button)
	var today = Time.get_date_string_from_system()
	if GameState.last_claim_date == today:
		return

	GameState.player_money += DAILY_REWARD
	GameState.last_claim_date = today

	_update_money_display()
	_update_daily_login_visual()

	GameState.daily_login_day += 1
	if GameState.daily_login_day > 7:
		GameState.daily_login_day = 1

func _on_student_pressed():
	_animate_button_click_bounce(student_button)
	print("Tombol Student ditekan, pindah ke student_card")
	Transition.change_scene("res://Scenes/StudentCard/student_card.tscn")

func _on_jadwal_pressed():
	_animate_button_click_bounce(jadwal_button)
	print("Tombol Jadwal ditekan, pindah ke atur_jadwal")
	Transition.change_scene("res://Scenes/AturJadwal/atur_jadwal.tscn")

func _on_click_area_gui_input(event: InputEvent):
	if not tutorial_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_step()
	elif event is InputEventScreenTouch and event.pressed:
		_next_step()

func _next_step():
	current_step += 1
	if current_step >= current_phase_steps.size():
		_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int):
	if index < 0 or index >= current_phase_steps.size():
		return
	var step = current_phase_steps[index]

	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _tutorial_panel and _tutorial_panel.modulate.a > 0.1:
		var tween_out = create_tween().set_parallel(true)
		tween_out.tween_property(_tutorial_panel, "scale", Vector2(0.8, 0.8), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween_out.tween_property(_tutorial_panel, "modulate:a", 0.0, 0.15)
		await tween_out.finished

	_tutorial_title_label.text = "(%d/%d) %s" % [index + 1, current_phase_steps.size(), step.title]
	_tutorial_body_label.text = step.text

	# Move to center specifically for Inventory, ReportStudent, Koperasi, and Jadwal tutorial steps in Lobby
	_tutorial_panel_should_center = (step.target_node_path in ["Inventory", "ReportStudent", "Koperasi", "Jadwal", "Jadwalkan", "Student"]) or (step.prompt_text != "" and ("jadwal" in step.prompt_text.to_lower() or "student" in step.prompt_text.to_lower()))
	var center_for_lobby_buttons := _tutorial_panel_should_center

	var targets: Array[Control] = []
	if step.target_node_path != "":
		var paths = step.target_node_path.split(",")
		for p in paths:
			var trimmed = p.strip_edges()
			if trimmed != "":
				var target = get_node_or_null(trimmed)
				if target and target is Control:
					targets.append(target)
		if not targets.is_empty():
			_highlight_multiple(targets)
		else:
			_clear_highlight()
	else:
		_clear_highlight()

	# Dynamic Prompt Text
	var requires_button_press = (!GameState.returned_from_student_card and index == current_phase_steps.size() - 1) or (GameState.returned_from_student_card and index == current_phase_steps.size() - 1)
	if step.prompt_text != "":
		_tutorial_prompt_label.text = step.prompt_text
	elif requires_button_press and not targets.is_empty():
		var btn_name = _get_button_display_name(targets[0])
		_tutorial_prompt_label.text = "TEKAN TOMBOL '%s' UNTUK LANJUT!" % btn_name.to_upper()
	else:
		_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"

	_position_tutorial_panel(center_for_lobby_buttons)
	_tutorial_panel.pivot_offset = _tutorial_panel.size / 2.0

	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(_tutorial_panel, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.2)

	await tween_in.finished

	if not GameState.returned_from_student_card and index == current_phase_steps.size() - 1:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if student_button is BaseButton:
			student_button.disabled = false
		else:
			student_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP

func _get_button_display_name(node: Node) -> String:
	if not node:
		return ""
	if node is Button and node.text.strip_edges() != "":
		return node.text.strip_edges()
	for child in node.get_children():
		if child is Label and child.text.strip_edges() != "":
			return child.text.strip_edges().split("\n")[0]
	return node.name

func _highlight_multiple(controls: Array, padding: float = 12.0):
	await get_tree().process_frame
	var valid_controls: Array[Control] = []
	for c in controls:
		if c and is_instance_valid(c) and c is Control:
			valid_controls.append(c)
	if valid_controls.is_empty():
		_clear_highlight()
		return
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		return
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	for c in valid_controls:
		var trans = c.get_global_transform()
		var local_corners = [
			Vector2.ZERO,
			Vector2(c.size.x, 0),
			Vector2(0, c.size.y),
			Vector2(c.size.x, c.size.y)
		]
		for corner in local_corners:
			var global_corner = trans * corner
			var local_corner = global_corner - color_rect.global_position
			min_pos.x = min(min_pos.x, local_corner.x)
			min_pos.y = min(min_pos.y, local_corner.y)
			max_pos.x = max(max_pos.x, local_corner.x)
			max_pos.y = max(max_pos.y, local_corner.y)

	var local_pos = min_pos - Vector2(padding, padding)
	var size_with_padding = (max_pos - min_pos) + Vector2(padding, padding) * 2

	mat.set_shader_parameter("hole_pos", local_pos)
	mat.set_shader_parameter("hole_size", size_with_padding)
	if _tutorial_arrow:
		var arrow_pos = Vector2(local_pos.x + size_with_padding.x / 2.0, local_pos.y - 35.0)
		var viewport_size = get_viewport_rect().size
		var W = 320.0
		var H = 320.0
		var margin = 20.0
		arrow_pos.x = clamp(arrow_pos.x, W/2.0 + margin, viewport_size.x - W/2.0 - margin)
		arrow_pos.y = clamp(arrow_pos.y, H + margin, viewport_size.y - margin)
		_tutorial_arrow.position = arrow_pos
		_tutorial_arrow.show()

func _clear_highlight():
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("hole_pos", Vector2(-9999.0, -9999.0))
	mat.set_shader_parameter("hole_size", Vector2.ZERO)
	if _tutorial_arrow:
		_tutorial_arrow.hide()

func _end_tutorial():
	GameState.lobby_tutorial_completed = true
	tutorial_active = false
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_panel.hide()
	if color_rect:
		color_rect.hide()
