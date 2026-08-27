extends Control

@export_group("Paper Card Design")
## Custom paper card texture override.
@export var paper_texture: Texture2D = preload("res://Assets/Images/UI/paper.png")
## Custom sticky note texture override.
@export var sticky_note_texture: Texture2D = preload("res://Assets/Images/UI/stickynotes.png")

@export_group("Tutorial")
## Edit this array in the Inspector to customize each tutorial step.
@export var tutorial_steps: Array[TutorialStepData] = []

@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea
@onready var card_container = $CardContainer
@onready var left_arrow = $LeftArrow
@onready var right_arrow = $RightArrow
@onready var page_indicator = $PageIndicator

static var tutorial_shown := false  # <-- penanda global

var default_students = [
	{
		"id": 1,
		"name": "Marcel",
		"portrait": "res://Assets/Images/MuridPotrait/Marcel.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid1.jpg",
		"kepribadian1": 60.0,
		"kepribadian2": 55.0,
		"akademis1": 28.0,
		"akademis2": 48.0,
		"akademis3": 38.0,
		"target_akademis1": 52.0,
		"target_akademis2": 60.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 40.0,
		"hobby_category": "Akademis",
		"personality": "Tekun",
		"quirk": "Kutu Buku"
	},
	{
		"id": 2,
		"name": "Doni",
		"portrait": "res://Assets/Images/MuridPotrait/Doni.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid2.jpg",
		"kepribadian1": 55.0,
		"kepribadian2": 55.0,
		"akademis1": 38.0,
		"akademis2": 22.0,
		"akademis3": 33.0,
		"target_akademis1": 50.0,
		"target_akademis2": 40.0,
		"target_akademis3": 51.0,
		"target_kepribadian1": 40.0,
		"target_kepribadian2": 35.0,
		"hobby_category": "Olahraga",
		"personality": "Aktif",
		"quirk": "Semangat Juang"
	},
	{
		"id": 3,
		"name": "Andi",
		"portrait": "res://Assets/Images/MuridPotrait/Andi.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid3.jpg",
		"kepribadian1": 60.0,
		"kepribadian2": 60.0,
		"akademis1": 48.0,
		"akademis2": 55.0,
		"akademis3": 32.0,
		"target_akademis1": 60.0,
		"target_akademis2": 64.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 60.0,
		"target_kepribadian2": 55.0,
		"hobby_category": "SeniBudaya",
		"personality": "Kreatif",
		"quirk": "Penasaran"
	},
	{
		"id": 4,
		"name": "Citra",
		"portrait": "res://Assets/Images/MuridPotrait/Citra.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid4.jpg",
		"kepribadian1": 35.0,
		"kepribadian2": 60.0,
		"akademis1": 28.0,
		"akademis2": 25.0,
		"akademis3": 15.0,
		"target_akademis1": 40.0,
		"target_akademis2": 43.0,
		"target_akademis3": 39.0,
		"target_kepribadian1": 35.0,
		"target_kepribadian2": 45.0,
		"hobby_category": "Olahraga",
		"personality": "Seni Dalam Kesunyian",
		"quirk": "Penyendiri"
	},
	{
		"id": 5,
		"name": "Shinta",
		"portrait": "res://Assets/Images/MuridPotrait/Shinta.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid5.jpg",
		"kepribadian1": 30.0,
		"kepribadian2": 40.0,
		"akademis1": 35.0,
		"akademis2": 22.0,
		"akademis3": 22.0,
		"target_akademis1": 53.0,
		"target_akademis2": 37.0,
		"target_akademis3": 37.0,
		"target_kepribadian1": 30.0,
		"target_kepribadian2": 35.0,
		"hobby_category": "Akademis",
		"personality": "Santai",
		"quirk": "Biang Onar"
	},
	{
		"id": 6,
		"name": "Thea",
		"portrait": "res://Assets/Images/MuridPotrait/Thea.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid6.jpg",
		"kepribadian1": 55.0,
		"kepribadian2": 50.0,
		"akademis1": 33.0,
		"akademis2": 22.0,
		"akademis3": 38.0,
		"target_akademis1": 45.0,
		"target_akademis2": 46.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 45.0,
		"hobby_category": "SeniBudaya",
		"personality": "Kreatif",
		"quirk": "Pekerja Keras"
	}
]

var active_students: Array = []
var card_nodes: Array[Control] = []
var current_card_index: int = 0

# Pointer & Swipe Gesture variables
var is_pointer_down: bool = false
var pointer_start_pos: Vector2 = Vector2.ZERO
var min_swipe_distance: float = 75.0
var card_animating: bool = false

# Tutorial UI variables
const TutorialArrow = preload("res://Scripts/TutorialArrow.gd")
var current_step := 0
var tutorial_active := true
var _tutorial_panel: PanelContainer
var _tutorial_title_label: Label
var _tutorial_body_label: Label
var _tutorial_prompt_label: Label
var _blink_tween: Tween
var _panel_tween: Tween
var _tutorial_arrow: Control = null

func _ready():
	_setup_tutorial()
	_setup_students()
	_setup_navigation_arrows()
	AudioDirector.play_bgm_playlist(&"lobby")

func _setup_navigation_arrows():
	if left_arrow:
		_setup_button_juice(left_arrow)
		if not left_arrow.pressed.is_connected(_prev_card):
			left_arrow.pressed.connect(_prev_card)
	if right_arrow:
		_setup_button_juice(right_arrow)
		if not right_arrow.pressed.is_connected(_next_card):
			right_arrow.pressed.connect(_next_card)

func _setup_students():
	var students = GameState.approved_students
	if students.is_empty():
		students = default_students
	active_students = students

	var required_days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
	card_nodes.clear()

	for i in range(4):
		var node_name = "Murid" + str(i + 1)
		var murid_node = card_container.get_node_or_null(node_name)
		if not murid_node:
			continue

		if i < active_students.size():
			var student_data = active_students[i]
			card_nodes.append(murid_node)

			if paper_texture:
				murid_node.texture = paper_texture

			# Set Portrait
			var portrait_node = murid_node.get_node_or_null("Portrait")
			var portrait_path = student_data.get("portrait", "")
			if portrait_node and portrait_path != "" and ResourceLoader.exists(portrait_path):
				portrait_node.texture = load(portrait_path)

			# Set Name
			var nama_label = murid_node.get_node_or_null("Nama")
			if nama_label:
				nama_label.text = student_data.get("name", "MURID " + str(i + 1))

			# Schedule calculation
			var student_id = student_data.get("id", null)
			var fully_scheduled := false
			var day_schedules_for_student: Dictionary = {}
			if student_id != null and GameState.day_schedules.has(student_id):
				day_schedules_for_student = GameState.day_schedules[student_id]
				fully_scheduled = true
				for day in required_days:
					if not day_schedules_for_student.has(day):
						fully_scheduled = false
						break

			# Status Badges
			var belum_btn = murid_node.get_node_or_null("Belum")
			var sudah_btn = murid_node.get_node_or_null("Sudah")
			if belum_btn:
				belum_btn.visible = not fully_scheduled
			if sudah_btn:
				sudah_btn.visible = fully_scheduled

			# Setup sticky notes: each is a StickyNote instance whose own
			# script tints self_modulate from DesignTokens.category_color()
			# and refreshes its label — this loop only decides the text.
			var sticky_container = murid_node.get_node_or_null("StickyNotesContainer")
			if sticky_container:
				for day_name in required_days:
					var sticky_node = sticky_container.get_node_or_null(day_name) as StickyNote
					if sticky_node:
						if sticky_note_texture:
							sticky_node.texture = sticky_note_texture

						var is_day_set = day_schedules_for_student.has(day_name)
						if is_day_set:
							var cat = day_schedules_for_student[day_name].get("category", "")
							sticky_node.activity = cat if cat != "" else "Terjadwal"
						else:
							sticky_node.activity = "-"

			# Attach CardButton signals for 100% click & swipe reliability
			var card_button = murid_node.get_node_or_null("CardButton")
			if card_button:
				if not card_button.gui_input.is_connected(_on_card_gui_input.bind(student_data, murid_node)):
					card_button.gui_input.connect(_on_card_gui_input.bind(student_data, murid_node))
				if not card_button.pressed.is_connected(_on_card_pressed.bind(student_data, murid_node)):
					card_button.pressed.connect(_on_card_pressed.bind(student_data, murid_node))
			else:
				if not murid_node.gui_input.is_connected(_on_card_gui_input.bind(student_data, murid_node)):
					murid_node.gui_input.connect(_on_card_gui_input.bind(student_data, murid_node))

		else:
			murid_node.hide()

	_build_page_indicators()
	_init_carousel_state()

func _build_page_indicators():
	if not page_indicator:
		return
	for child in page_indicator.get_children():
		child.queue_free()

	for i in range(card_nodes.size()):
		var dot = Label.new()
		dot.text = "●"
		dot.theme_type_variation = &"H2Label"
		page_indicator.add_child(dot)

func _init_carousel_state():
	if card_nodes.is_empty():
		return
	for i in range(card_nodes.size()):
		var card = card_nodes[i]
		if i == current_card_index:
			card.show()
			card.position = Vector2.ZERO
			card.rotation_degrees = 0
			card.modulate.a = 1.0
		else:
			card.hide()
	_update_page_indicators()
	Juice.stagger_in(card_nodes)
	_stagger_card_notes(card_nodes[current_card_index])

## Reveal one card's five day-notes with a shorter step than the
## card-level stagger, as if they're being pinned up as the card opens.
func _stagger_card_notes(card: Control) -> void:
	var sticky_container = card.get_node_or_null("StickyNotesContainer")
	if not sticky_container:
		return
	Juice.stagger_in(sticky_container.get_children(), DesignTokens.load_default().stagger_step * 0.5)

func _update_page_indicators():
	var tokens := DesignTokens.load_default()
	if page_indicator:
		var dots = page_indicator.get_children()
		for i in range(dots.size()):
			if dots[i] is Label:
				if i == current_card_index:
					dots[i].self_modulate = tokens.currency_gold
				else:
					dots[i].self_modulate = tokens.text_secondary

	if left_arrow:
		left_arrow.visible = (card_nodes.size() > 1)
	if right_arrow:
		right_arrow.visible = (card_nodes.size() > 1)

func _next_card():
	if card_animating or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index + 1) % card_nodes.size()
	_switch_card(target_index, -1)

func _prev_card():
	if card_animating or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index - 1 + card_nodes.size()) % card_nodes.size()
	_switch_card(target_index, 1)

func _switch_card(new_index: int, direction: int):
	if card_animating or new_index == current_card_index:
		return
	card_animating = true

	var old_card = card_nodes[current_card_index]
	var new_card = card_nodes[new_index]
	current_card_index = new_index

	var screen_width = get_viewport_rect().size.x
	var throw_distance = screen_width * direction
	var orig_pos = Vector2.ZERO

	# Step 1: Sequential Tween OUT (Throw old card off screen cleanly)
	var tween_out = create_tween().set_parallel(true)
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out.tween_property(old_card, "position:x", orig_pos.x + throw_distance, 0.20)
	tween_out.tween_property(old_card, "rotation_degrees", 12.0 * direction, 0.20)
	tween_out.tween_property(old_card, "modulate:a", 0.0, 0.20)

	await tween_out.finished

	# Reset old card transform & hide
	old_card.hide()
	old_card.position = orig_pos
	old_card.rotation_degrees = 0
	old_card.modulate.a = 1.0

	# Prepare new card off-screen
	new_card.show()
	new_card.position = orig_pos - Vector2(throw_distance, 0)
	new_card.rotation_degrees = -12.0 * direction
	new_card.modulate.a = 0.0

	_update_page_indicators()

	# Step 2: Sequential Tween IN (Slide new card in smoothly)
	var tween_in = create_tween().set_parallel(true)
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(new_card, "position", orig_pos, 0.20)
	tween_in.tween_property(new_card, "rotation_degrees", 0.0, 0.20)
	tween_in.tween_property(new_card, "modulate:a", 1.0, 0.20)

	await tween_in.finished

	_stagger_card_notes(new_card)
	card_animating = false

	# If in tutorial Step 1 (Navigasi Card), advance to Step 2 after card transition completes
	if tutorial_active and current_step == 1:
		_next_step()

func _on_card_pressed(student_data: Dictionary, card_node: Control):
	if card_animating:
		return
	if tutorial_active:
		if current_step == 2:  # Step 2: Pilih Murid (Final step locks onto card)
			_end_tutorial()
			_on_student_selected(student_data, card_node)
		return

	_on_student_selected(student_data, card_node)

func _on_card_gui_input(event: InputEvent, student_data: Dictionary, card_node: Control):
	if card_animating:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pointer_down = true
				pointer_start_pos = event.global_position
			else:
				if is_pointer_down:
					is_pointer_down = false
					var delta = event.global_position - pointer_start_pos
					var total_distance = delta.length()

					if total_distance >= min_swipe_distance and abs(delta.x) > abs(delta.y) * 1.2:
						if delta.x < 0:
							_next_card()
						else:
							_prev_card()

	elif event is InputEventScreenTouch:
		if event.pressed:
			is_pointer_down = true
			pointer_start_pos = event.position
		else:
			if is_pointer_down:
				is_pointer_down = false
				var delta = event.position - pointer_start_pos
				var total_distance = delta.length()

				if total_distance >= min_swipe_distance and abs(delta.x) > abs(delta.y) * 1.2:
					if delta.x < 0:
						_next_card()
					else:
						_prev_card()

func _on_student_selected(student: Dictionary, card_node: Control = null):
	if card_animating:
		return
	card_animating = true

	if card_node and is_instance_valid(card_node):
		card_node.pivot_offset = card_node.size / 2.0

		# Fast cute squash & stretch bounce
		var tw1 = create_tween()
		tw1.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw1.tween_property(card_node, "scale", Vector2(0.9, 1.1), 0.07)
		tw1.tween_property(card_node, "scale", Vector2(1.0, 1.0), 0.07)
		await tw1.finished

		# Discard paper off-screen to right smoothly
		var screen_width = get_viewport_rect().size.x
		var tw2 = create_tween().set_parallel(true)
		tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw2.tween_property(card_node, "position:x", card_node.position.x + screen_width, 0.25)
		tw2.tween_property(card_node, "rotation_degrees", 15.0, 0.25)
		tw2.tween_property(card_node, "modulate:a", 0.0, 0.22)
		await tw2.finished

	AudioDirector.play_sfx(&"select")
	print("Murid dipilih: ", student.get("name", ""))
	GameState.selected_student = student
	Transition.change_scene("res://Scenes/AturJadwal/atur_jadwal.tscn")

# --- Tutorial System ---

func _setup_tutorial():
	if tutorial_shown:
		if color_rect:
			color_rect.hide()
		tutorial_active = false
		return

	if tutorial_steps.is_empty():
		_populate_default_tutorial_steps()

	var viewport_size = get_viewport_rect().size
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		var shader = load("res://Scripts/Shaders/spotlight.gdshader")
		if shader:
			mat = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("overlay_color", DesignTokens.load_default().scrim_color())
			mat.set_shader_parameter("rect_size", viewport_size)
			color_rect.material = mat
	else:
		mat.set_shader_parameter("rect_size", viewport_size)

	_fit_color_rect_to_viewport()
	get_tree().root.size_changed.connect(_fit_color_rect_to_viewport)

	_tutorial_arrow = TutorialArrow.new()
	_tutorial_arrow.visible = false
	color_rect.add_child(_tutorial_arrow)

	_build_tutorial_panel()

	if color_rect:
		color_rect.show()
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if click_area:
		if click_area.has_signal("pressed"):
			if not click_area.pressed.is_connected(_next_step):
				click_area.pressed.connect(_next_step)
		else:
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP
			if not click_area.gui_input.is_connected(_on_click_area_gui_input):
				click_area.gui_input.connect(_on_click_area_gui_input)

	_show_step(0)

func _populate_default_tutorial_steps():
	var defaults = [
		["Daftar Murid", "Disini kalian bebas memilih murid-murid yang belum terjadwalkan untuk belajar selama seminggu!", "CardContainer"],
		["Navigasi Card", "Geser layar atau tekan tombol panah kanan untuk melihat murid lainnya!", "RightArrow"],
		["Pilih Murid", "Bagus! Sekarang tekan kertas dokumen murid ini untuk mulai mengatur jadwal belajarnya!", ""]
	]
	for entry in defaults:
		var step = TutorialStepData.new()
		step.title = entry[0]
		step.text = entry[1]
		step.target_node_path = entry[2]
		tutorial_steps.append(step)

func _build_tutorial_panel():
	var viewport_size = get_viewport_rect().size

	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.name = "TutorialPanel"
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Was: a hand-rolled dark StyleBoxFlat with a gold border. Now the
	# project's Card surface, matching every other raised panel and
	# picking up token changes for free (established in StudentCard,
	# Task 12).
	_tutorial_panel.theme_type_variation = &"Card"

	var panel_width = min(viewport_size.x * 0.92, 1000)
	_tutorial_panel.custom_minimum_size = Vector2(panel_width, 0)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	_tutorial_panel.add_child(vbox)

	_tutorial_title_label = Label.new()
	_tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_title_label.theme_type_variation = &"H1Label"
	vbox.add_child(_tutorial_title_label)

	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.theme_type_variation = &"TitleLabel"
	_tutorial_body_label.add_theme_constant_override("line_spacing", 8)
	_tutorial_body_label.custom_minimum_size = Vector2(panel_width - 60, 0)
	vbox.add_child(_tutorial_body_label)

	var sep2 = HSeparator.new()
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep2)

	_tutorial_prompt_label = Label.new()
	_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"
	_tutorial_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_prompt_label.theme_type_variation = &"TitleLabel"
	vbox.add_child(_tutorial_prompt_label)

	color_rect.add_child(_tutorial_panel)
	var click_idx = click_area.get_index()
	color_rect.move_child(_tutorial_panel, click_idx)

	_start_prompt_blink()
	_position_tutorial_panel()

func _start_prompt_blink():
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_tutorial_prompt_label.modulate.a = 1.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 0.25, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 1.0, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _position_tutorial_panel():
	if not _tutorial_panel or not is_instance_valid(_tutorial_panel):
		return
	var viewport_size = get_viewport_rect().size
	var panel_size = _tutorial_panel.size
	var min_y = viewport_size.y * 0.55
	var ideal_y = viewport_size.y - panel_size.y - 40
	var target_y = max(min_y, ideal_y)

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
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	if tutorial_active and _tutorial_panel and is_instance_valid(_tutorial_panel):
		_position_tutorial_panel()

func _next_step():
	current_step += 1
	if current_step >= tutorial_steps.size():
		_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int):
	if index < 0 or index >= tutorial_steps.size():
		return
	current_step = index
	var step = tutorial_steps[index]

	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Update Tutorial Content instantly without frame stalls
	_tutorial_title_label.text = "(%d/%d) %s" % [index + 1, tutorial_steps.size(), step.title]
	_tutorial_body_label.text = step.text

	var targets: Array[Control] = []
	if index == 1:
		var arrow_target = right_arrow if right_arrow else left_arrow
		if arrow_target and is_instance_valid(arrow_target):
			targets.append(arrow_target)
	elif index == 2 and not card_nodes.is_empty():
		var active_card = card_nodes[current_card_index]
		if active_card and is_instance_valid(active_card):
			targets.append(active_card)
	elif step.target_node_path != "":
		var paths = step.target_node_path.split(",")
		for p in paths:
			var trimmed = p.strip_edges()
			if trimmed != "":
				var target = _find_target_node(trimmed)
				if target and target is Control:
					targets.append(target)

	if not targets.is_empty():
		_highlight_multiple(targets)
	else:
		_clear_highlight()

	if step.prompt_text != "":
		_tutorial_prompt_label.text = step.prompt_text
	elif index == 1:
		_tutorial_prompt_label.text = "TEKAN PANAH ATAU GESER UNTUK PINDAH MURID!"
	elif index == 2:
		_tutorial_prompt_label.text = "TEKAN KERTAS UNTUK MEMILIH MURID!"
	else:
		_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"

	_position_tutorial_panel()

	# Snappy 0.12s panel animation without frame delays
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(_tutorial_panel, "scale", Vector2(1.0, 1.0), 0.12)
	_panel_tween.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.10)

	if index == 0:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	elif index == 1:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if left_arrow: left_arrow.mouse_filter = Control.MOUSE_FILTER_STOP
		if right_arrow: right_arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	elif index == 2:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _find_target_node(path_str: String) -> Node:
	var node = get_node_or_null(path_str)
	if node:
		return node
	if card_container:
		node = card_container.get_node_or_null(path_str)
		if node:
			return node
	return null

func _highlight_multiple(controls: Array, padding: float = 12.0):
	var valid_controls: Array[Control] = []
	for c in controls:
		if c and is_instance_valid(c) and c is Control:
			valid_controls.append(c)
	if valid_controls.is_empty():
		_clear_highlight()
		return
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		var shader = load("res://Scripts/Shaders/spotlight.gdshader")
		if shader:
			mat = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("overlay_color", DesignTokens.load_default().scrim_color())
			mat.set_shader_parameter("rect_size", get_viewport_rect().size)
			color_rect.material = mat
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
	tutorial_shown = true
	tutorial_active = false
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_panel.hide()
	if color_rect:
		color_rect.hide()

func _on_click_area_gui_input(event: InputEvent):
	if tutorial_active and current_step == 0:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_next_step()

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
