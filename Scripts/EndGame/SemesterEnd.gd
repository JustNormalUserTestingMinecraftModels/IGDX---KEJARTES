extends Control

# ── Node References ───────────────────────────────────────────────────────────
@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/SubtitleLabel
@onready var card_container: Control = $MarginContainer/VBoxContainer/CardContainer
@onready var page_indicator: HBoxContainer = $MarginContainer/VBoxContainer/PageIndicator
@onready var congrats_title: Label = $MarginContainer/VBoxContainer/NarrativeContainer/CongratsTitle
@onready var congrats_text: Label = $MarginContainer/VBoxContainer/NarrativeContainer/CongratsText
@onready var teacher_title_label: Label = $MarginContainer/VBoxContainer/TeacherContainer/TeacherTitleLabel

@onready var btn_restart: Button = $MarginContainer/VBoxContainer/ButtonContainer/BtnRestart
@onready var btn_menu: Button = $MarginContainer/VBoxContainer/ButtonContainer/BtnMainMenu

@onready var left_arrow: Button = $LeftArrow
@onready var right_arrow: Button = $RightArrow

# Carousel / Swipe gesture state
var active_students: Array = []
var card_nodes: Array[Control] = []
var current_card_index: int = 0
var card_animating: bool = false

var is_pointer_down: bool = false
var pointer_start_pos: Vector2 = Vector2.ZERO
var min_swipe_distance: float = 75.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Connect buttons
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	left_arrow.pressed.connect(_prev_card)
	right_arrow.pressed.connect(_next_card)

	# Setup juice
	_setup_button_juice(left_arrow)
	_setup_button_juice(right_arrow)
	_setup_button_juice(btn_restart)
	_setup_button_juice(btn_menu)

	# Calculate evaluation
	_evaluate_students()

func _evaluate_students() -> void:
	var students: Array[StudentData] = GameState.convert_to_student_data_array()
	active_students = students
	card_nodes.clear()

	# Populate card_nodes with Murid1 to Murid4 based on active selection size
	for i in range(4):
		var node_name = "Murid" + str(i + 1)
		var card_node = card_container.get_node_or_null(node_name)
		if not card_node:
			continue

		if i < active_students.size():
			var student = active_students[i]
			card_nodes.append(card_node)

			# Set Name
			var name_lbl = card_node.get_node_or_null("Nama")
			if name_lbl:
				name_lbl.text = student.student_name

			# Set Portrait
			var portrait_rect = card_node.get_node_or_null("Portrait")
			if portrait_rect:
				portrait_rect.texture = student.avatar_texture

			# Compute subject passing
			var tuntas_akademis = student.akademis >= student.target_akademis1
			var tuntas_seni = student.seni_budaya >= student.target_akademis2
			var tuntas_olahraga = student.olahraga >= student.target_akademis3
			var student_passed = tuntas_akademis and tuntas_seni and tuntas_olahraga

			# Set Stamp
			var stamp_lbl = card_node.get_node_or_null("Stamp")
			if stamp_lbl:
				if student_passed:
					stamp_lbl.text = "LULUS!"
					stamp_lbl.add_theme_color_override("font_color", Color(0.15, 0.7, 0.25))

					var style = StyleBoxFlat.new()
					style.bg_color = Color(0.15, 0.7, 0.25, 0.08)
					style.border_color = Color(0.15, 0.7, 0.25)
					style.border_width_left = 6
					style.border_width_top = 6
					style.border_width_right = 6
					style.border_width_bottom = 6
					style.corner_radius_top_left = 12
					style.corner_radius_top_right = 12
					style.corner_radius_bottom_left = 12
					style.corner_radius_bottom_right = 12
					stamp_lbl.add_theme_stylebox_override("normal", style)
				else:
					stamp_lbl.text = "TIDAK LULUS..."
					stamp_lbl.add_theme_color_override("font_color", Color(0.95, 0.2, 0.25))

					var style = StyleBoxFlat.new()
					style.bg_color = Color(0.95, 0.2, 0.25, 0.08)
					style.border_color = Color(0.95, 0.2, 0.25)
					style.border_width_left = 6
					style.border_width_top = 6
					style.border_width_right = 6
					style.border_width_bottom = 6
					style.corner_radius_top_left = 12
					style.corner_radius_top_right = 12
					style.corner_radius_bottom_left = 12
					style.corner_radius_bottom_right = 12
					stamp_lbl.add_theme_stylebox_override("normal", style)

			# Configure Stats Rows
			var stats_container = card_node.get_node_or_null("StatsContainer")
			if stats_container:
				_configure_stat_row(stats_container.get_node_or_null("Akademis"), student.akademis, student.target_akademis1, tuntas_akademis)
				_configure_stat_row(stats_container.get_node_or_null("Seni"), student.seni_budaya, student.target_akademis2, tuntas_seni)
				_configure_stat_row(stats_container.get_node_or_null("Olahraga"), student.olahraga, student.target_akademis3, tuntas_olahraga)

			# Connect Swipe / Touch handlers
			var card_btn = card_node.get_node_or_null("CardButton")
			if card_btn:
				if not card_btn.gui_input.is_connected(_on_card_gui_input.bind(card_node)):
					card_btn.gui_input.connect(_on_card_gui_input.bind(card_node))
				if not card_btn.pressed.is_connected(_on_card_pressed.bind(card_node)):
					card_btn.pressed.connect(_on_card_pressed.bind(card_node))
			else:
				if not card_node.gui_input.is_connected(_on_card_gui_input.bind(card_node)):
					card_node.gui_input.connect(_on_card_gui_input.bind(card_node))
		else:
			card_node.hide()

	# Page indicators and carousel state
	_build_page_indicators()
	_init_carousel_state()

	# Overall Evaluation Result
	var grade_num = GameState.current_grade
	var all_passed = GameState.check_semester_passed()

	if all_passed:
		title_label.text = "🎓 Evaluasi Akhir Semester - Kelas %d 🎓" % grade_num
		congrats_title.text = "Selamat! Tahun Ajaran Kelas %d Telah Selesai 🎉" % grade_num
		congrats_title.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))

		# Compute teacher title
		var total_tuntas = 0
		for student in students:
			if student.akademis >= student.target_akademis1: total_tuntas += 1
			if student.seni_budaya >= student.target_akademis2: total_tuntas += 1
			if student.olahraga >= student.target_akademis3: total_tuntas += 1

		var teacher_rank_str = "Guru Pembimbing Aktif ⭐"
		if total_tuntas >= 10:
			teacher_rank_str = "Guru Teladan Utama ⭐⭐⭐"
		elif total_tuntas >= 6:
			teacher_rank_str = "Guru Berdedikasi Tinggi ⭐⭐"

		teacher_title_label.text = "Gelar Gurumu: %s" % teacher_rank_str

		if grade_num >= 9:
			GameState.is_game_beaten = true
			GameSettings.save_settings()
			congrats_text.text = "Luar biasa! Kamu telah berhasil mendampingi seluruh murid menyelesaikan pendidikan dari Kelas 7 hingga LULUS Kelas 9! 🏆\n\nFITUR PILIH LEVEL (Level Selection) sekarang TERBUKA PERMANEN di Intro!"
			btn_restart.text = "Mulai Ulang Permainan"
		elif grade_num == 8:
			congrats_text.text = "Kamu telah berhasil mendampingi seluruh murid melewati ujian akhir kelas 8.\n\nTantangan akhir Ujian Kelulusan Kelas 9 telah menanti!"
			btn_restart.text = "Lanjut Kelas 9"
		else:
			congrats_text.text = "Kamu telah berhasil mendampingi seluruh murid melewati ujian semester akhir kelas 7.\n\nPetualangan dan tantangan baru di Kelas 8 & Kelas 9 menantimu!"
			btn_restart.text = "Lanjut Kelas 8"
	else:
		title_label.text = "❌ Evaluasi Akhir Semester - Kelas %d ❌" % grade_num
		congrats_title.text = "Tahun Ajaran Gagal - Coba Lagi ⚠️"
		congrats_title.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))

		teacher_title_label.text = "Gelar Gurumu: Guru Pembimbing Remedial ⚠️"
		congrats_text.text = "Kamu gagal mendampingi seluruh murid melewati target kelulusan kelas %d.\n\nBeberapa murid masih belum tuntas. Silakan coba lagi untuk membimbing mereka menuju kelulusan!" % grade_num
		btn_restart.text = "Coba Lagi Kelas %d" % grade_num

func _configure_stat_row(row_node: Control, value: float, target: float, is_tuntas: bool) -> void:
	if not row_node:
		return

	# Value Label
	var val_lbl = row_node.get_node_or_null("Labels/Value")
	if val_lbl:
		val_lbl.text = "%d/%d" % [int(value), int(target)]
		val_lbl.add_theme_color_override("font_color", Color(0.1, 0.55, 0.2) if is_tuntas else Color(0.85, 0.15, 0.15))

	# Progress Bar
	var progress = row_node.get_node_or_null("Progress")
	if progress:
		progress.value = value

		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color(0.2, 0.75, 0.35) if is_tuntas else Color(0.85, 0.2, 0.2)
		style_fill.corner_radius_top_left = 6
		style_fill.corner_radius_top_right = 6
		style_fill.corner_radius_bottom_left = 6
		style_fill.corner_radius_bottom_right = 6
		progress.add_theme_stylebox_override("fill", style_fill)

# ── Carousel Logic ────────────────────────────────────────────────────────────
func _build_page_indicators() -> void:
	if not page_indicator:
		return
	for child in page_indicator.get_children():
		child.queue_free()

	for i in range(card_nodes.size()):
		var dot = Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 36)
		page_indicator.add_child(dot)

func _update_page_indicators() -> void:
	if page_indicator:
		var dots = page_indicator.get_children()
		for i in range(dots.size()):
			if dots[i] is Label:
				if i == current_card_index:
					dots[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				else:
					dots[i].add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

	if left_arrow:
		left_arrow.visible = (card_nodes.size() > 1)
	if right_arrow:
		right_arrow.visible = (card_nodes.size() > 1)

func _init_carousel_state() -> void:
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

func _next_card() -> void:
	if card_animating or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index + 1) % card_nodes.size()
	_switch_card(target_index, -1)

func _prev_card() -> void:
	if card_animating or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index - 1 + card_nodes.size()) % card_nodes.size()
	_switch_card(target_index, 1)

func _switch_card(new_index: int, direction: int) -> void:
	if card_animating or new_index == current_card_index:
		return
	card_animating = true

	var old_card = card_nodes[current_card_index]
	var new_card = card_nodes[new_index]
	current_card_index = new_index

	var screen_width = get_viewport_rect().size.x
	var throw_distance = screen_width * direction
	var orig_pos = Vector2.ZERO

	var tween_out = create_tween().set_parallel(true)
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out.tween_property(old_card, "position:x", orig_pos.x + throw_distance, 0.20)
	tween_out.tween_property(old_card, "rotation_degrees", 12.0 * direction, 0.20)
	tween_out.tween_property(old_card, "modulate:a", 0.0, 0.20)

	await tween_out.finished

	old_card.hide()
	old_card.position = orig_pos
	old_card.rotation_degrees = 0
	old_card.modulate.a = 1.0

	new_card.show()
	new_card.position = orig_pos - Vector2(throw_distance, 0)
	new_card.rotation_degrees = -12.0 * direction
	new_card.modulate.a = 0.0

	_update_page_indicators()

	var tween_in = create_tween().set_parallel(true)
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(new_card, "position", orig_pos, 0.20)
	tween_in.tween_property(new_card, "rotation_degrees", 0.0, 0.20)
	tween_in.tween_property(new_card, "modulate:a", 1.0, 0.20)

	await tween_in.finished

	card_animating = false

func _on_card_pressed(card_node: Control) -> void:
	pass

func _on_card_gui_input(event: InputEvent, card_node: Control) -> void:
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

# ── Button Actions ────────────────────────────────────────────────────────────
func _on_restart_pressed() -> void:
	var all_passed = GameState.check_semester_passed()
	var next_scene_path = ""

	if not all_passed:
		# Fail: Trigger Game Over cutscene
		GameState.is_game_over_cutscene = true
		next_scene_path = "res://Scenes/CutScene/cut_scene.tscn"
	else:
		# Win: standard progress
		var grade_num = GameState.current_grade
		if grade_num < 9:
			GameState.current_grade += 1

			# Reset mood/energy, clear base targets for recalculations
			for student in GameState.approved_students:
				student["kepribadian1"] = 80.0
				student["kepribadian2"] = 80.0
				student.erase("base_akademis1")
				student.erase("base_akademis2")
				student.erase("base_akademis3")

			GameState.day_schedules.clear()
			GameState.minggu_ke = 1
			GameState.returned_from_student_card = false
			GameState.lobby_tutorial_completed = true
			next_scene_path = "res://Scenes/StudentCard/student_card.tscn"
		else:
			# Beat Game: restart Grade 7 fresh
			GameState.current_grade = 7
			GameState.is_game_beaten = false

			var AturJadwalScript = load("res://Scripts/AturJadwal/atur_jadwal.gd")
			if AturJadwalScript and "tutorial_phase1_done" in AturJadwalScript:
				AturJadwalScript.tutorial_phase1_done = false
				AturJadwalScript.tutorial_phase3_done = false
			var LobbyScript = load("res://Scripts/Lobby/loby.gd")
			if LobbyScript and "tutorial_shown" in LobbyScript:
				LobbyScript.tutorial_shown = false

			GameState.day_schedules.clear()
			GameState.minggu_ke = 1
			GameState.returned_from_student_card = false
			GameState.lobby_tutorial_completed = false
			GameState.approved_students.clear()
			GameState.grade7_student_ids.clear()
			next_scene_path = "res://Scenes/Lobby/loby.tscn"

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	Transition.change_scene(next_scene_path)

func _on_menu_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	Transition.change_scene("res://Scenes/MainMenu/main_menu.tscn")

# ── Button Juice ──────────────────────────────────────────────────────────────
func _setup_button_juice(btn: Control) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_btn_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))

func _on_btn_mouse_entered(btn: Control) -> void:
	if not is_instance_valid(btn) or (btn is BaseButton and btn.disabled):
		return
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)

func _on_btn_mouse_exited(btn: Control) -> void:
	if not is_instance_valid(btn):
		return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
