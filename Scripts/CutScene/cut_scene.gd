extends Control

@onready var dialogue_label: RichTextLabel = $DialogueBox/DialogueLabel
@onready var bg_cutscene: TextureRect = $BgCutScene
@onready var fade_overlay: ColorRect = $FadeOverlay

var cg_data = [
	{
		"image": preload("res://Assets/Images/UI/BG.jpg"),
		"text": "Fiuh, setelah sekian lama aku mendaftar di sekolah ini. Akhirnya saya resmi diakui untuk mengajar disini!"
	},
	{
		"image": preload("res://Assets/Images/CG/cg1.jpg"),
		"text": "Formulir pengajuan yang diterima dan ditandatangani resmi dari guru yang akan menjadi karakter kita ini"
	},
	{
		"image": preload("res://Assets/Images/CG/cg2.jpg"),
		"text": "Karakter kita ini senang atau bangga besar."
	},
	{
		"image": preload("res://Assets/Images/CG/cg3.jpg"),
		"text": "Lokasi halaman depan Akademi, yang akan menjadi latar kita nanti untuk mengajar."
	},
	{
		"image": preload("res://Assets/Images/CG/cg4.jpg"),
		"text": "Pemandangan kelas dari pojok kanan atas, memperlihatkan seluruh isi kelas yang kosong dan yang akan diajar oleh sang guru."
	}
]

var cg_index := 0
var is_typing := false
var char_index := 0
var is_transitioning := false

# Level Selection UI elements
var level_select_overlay: Control
var is_showing_level_select := false
var btn_skip: Button
var btn_debug_toggle: Button

func _ready():
	fade_overlay.color.a = 0.0
	_setup_top_bar_buttons()
	_setup_level_select_ui()
	
	if GameState.is_game_over_cutscene:
		_setup_game_over_cutscene()
	else:
		# Show level selection BEFORE playing intro cutscene if unlocked or in debug mode
		if GameState.is_game_beaten or GameState.debug_level_select_enabled:
			show_level_select_modal()
		else:
			GameState.set_grade(7)
			show_current()

func _setup_game_over_cutscene() -> void:
	if btn_debug_toggle: btn_debug_toggle.visible = false
	if btn_skip: btn_skip.visible = false
	if bg_cutscene:
		bg_cutscene.modulate = Color(0.45, 0.45, 0.45, 1.0)
		
	cg_data = [
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Kepala Sekolah menggelengkan kepalanya melihat hasil evaluasi akhir... 'Maaf, murid-muridmu belum memenuhi standar kelulusan.'"
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Aku tertunduk lesu di ruangannya. Semua usaha keras membimbing mereka selama satu semester ini terasa sirna..."
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Melihat ruang kelas yang kosong, aku teringat kembali wajah-wajah penuh harapan dari murid-muridku."
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Aku merasa bersalah. Aku telah gagal membuktikan diriku sebagai guru pembimbing yang baik bagi mereka."
		},
		{
			"image": preload("res://Assets/Images/UI/BG.jpg"),
			"text": "Tapi, aku tidak boleh menyerah begitu saja! Aku harus kembali mengajar mereka dengan segenap kemampuanku kali ini!"
		}
	]
	cg_index = 0
	show_current()

func _setup_top_bar_buttons() -> void:
	# Top HBox for Skip & Debug controls
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(30, 40)
	top_bar.size = Vector2(1020, 80)
	top_bar.add_theme_constant_override("separation", 20)
	add_child(top_bar)

	# Debug level select toggle button
	btn_debug_toggle = Button.new()
	_update_debug_button_text()
	btn_debug_toggle.custom_minimum_size = Vector2(360, 60)
	btn_debug_toggle.pressed.connect(_on_debug_toggle_pressed)
	top_bar.add_child(btn_debug_toggle)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Skip cutscene button
	btn_skip = Button.new()
	btn_skip.text = "⏩ Skip Intro"
	btn_skip.custom_minimum_size = Vector2(220, 60)
	btn_skip.pressed.connect(_on_skip_pressed)
	top_bar.add_child(btn_skip)

	_style_top_button(btn_debug_toggle, Color(0.15, 0.25, 0.4, 0.85))
	_style_top_button(btn_skip, Color(0.35, 0.2, 0.2, 0.85))

func _update_debug_button_text() -> void:
	if btn_debug_toggle:
		var mode_str = "ON (Pilih Kelas)" if GameState.debug_level_select_enabled else "OFF (Normal)"
		btn_debug_toggle.text = "🐛 Debug Level Select: " + mode_str

func _style_top_button(btn: Button, bg_col: Color) -> void:
	btn.add_theme_font_size_override("font_size", 24)
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 0.6)
	btn.add_theme_stylebox_override("normal", style)

func _setup_level_select_ui() -> void:
	# Overlay container
	level_select_overlay = Control.new()
	level_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_select_overlay.visible = false
	add_child(level_select_overlay)

	# Dark dim backdrop
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.05, 0.1, 0.92)
	level_select_overlay.add_child(dim)

	# Centered Modal Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 1100)
	panel.position = Vector2(90, 360)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.22, 0.95)
	panel_style.border_color = Color(0.9, 0.75, 0.3, 0.9)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 24
	panel_style.corner_radius_top_right = 24
	panel_style.corner_radius_bottom_left = 24
	panel_style.corner_radius_bottom_right = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	level_select_overlay.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Header Title
	var title = Label.new()
	title.text = "🎓 PILIH TINGKAT KELAS 🎓"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Pilih tingkat jenjang kelas yang ingin kamu bimbing:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 26)
	vbox.add_child(subtitle)

	# Debug Badge
	var debug_badge = Label.new()
	debug_badge.text = "🔧 [MODE DEBUG: LEVEL SELECT AKTIF]"
	debug_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_badge.add_theme_font_size_override("font_size", 20)
	debug_badge.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(debug_badge)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Buttons Container
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_vbox)

	# Grade 7 Button
	_create_grade_button(btn_vbox, 7, "🏫 KELAS 7 (Tingkat Pertama)", "Awal Tahun Ajaran • Minggu 1 • Dasar Pembimbingan", Color(0.2, 0.5, 0.8))
	
	# Grade 8 Button
	_create_grade_button(btn_vbox, 8, "🏫 KELAS 8 (Tingkat Menengah)", "Tahun Ajaran Ke-2 • Minggu 17 • Tantangan Meningkat", Color(0.2, 0.7, 0.5))

	# Grade 9 Button
	_create_grade_button(btn_vbox, 9, "🎓 KELAS 9 (Tingkat Akhir)", "Ujian Kelulusan Utama • Minggu 33 • Evaluasi Final", Color(0.85, 0.4, 0.2))

func _create_grade_button(parent: VBoxContainer, grade_num: int, title_text: String, desc_text: String, theme_col: Color) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 140)
	
	var btn_vbox = VBoxContainer.new()
	btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	var title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	btn_vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = desc_text
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	btn_vbox.add_child(desc_lbl)

	btn.add_child(btn_vbox)

	var style = StyleBoxFlat.new()
	style.bg_color = theme_col * 0.4
	style.border_color = theme_col
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = theme_col * 0.7
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	btn.pressed.connect(func(): _on_grade_selected(grade_num))
	parent.add_child(btn)

func _on_debug_toggle_pressed() -> void:
	GameState.debug_level_select_enabled = not GameState.debug_level_select_enabled
	GameSettings.save_settings()
	_update_debug_button_text()
	print("Debug Level Select toggled: ", GameState.debug_level_select_enabled)
	if GameState.debug_level_select_enabled and not is_showing_level_select:
		show_level_select_modal()

func _on_skip_pressed() -> void:
	print("Skip Cutscene pressed")
	go_to_gameplay()

func show_level_select_modal() -> void:
	is_showing_level_select = true
	level_select_overlay.visible = true
	var tween = create_tween()
	level_select_overlay.modulate.a = 0.0
	tween.tween_property(level_select_overlay, "modulate:a", 1.0, 0.3)

func _on_grade_selected(grade_num: int) -> void:
	print("Grade selected before cutscene: ", grade_num)
	GameState.set_grade(grade_num)
	
	is_showing_level_select = false
	var tween = create_tween()
	tween.tween_property(level_select_overlay, "modulate:a", 0.0, 0.25)
	await tween.finished
	level_select_overlay.visible = false
	
	show_current()

func show_current():
	bg_cutscene.texture = cg_data[cg_index]["image"]
	type_text(cg_data[cg_index]["text"])

func type_text(full_text: String):
	is_typing = true
	char_index = 0
	dialogue_label.text = ""
	while is_typing and char_index < full_text.length():
		dialogue_label.text += full_text[char_index]
		char_index += 1
		await get_tree().create_timer(0.03).timeout
	is_typing = false

func _input(event):
	if is_transitioning or is_showing_level_select:
		return

	var tapped = false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true

	if not tapped:
		return

	if is_typing:
		dialogue_label.text = cg_data[cg_index]["text"]
		is_typing = false
		return

	advance()

func advance():
	cg_index += 1
	if cg_index >= cg_data.size():
		go_to_gameplay()
	else:
		transition_to_next()

func transition_to_next():
	is_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.4)
	await tween.finished

	show_current()

	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 0.4)
	await tween_in.finished

	is_transitioning = false

func go_to_gameplay():
	is_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.8)
	await tween.finished
	
	if GameState.is_game_over_cutscene:
		GameState.is_game_over_cutscene = false
		var grade_num = GameState.current_grade
		var next_scene_path = "res://Scenes/Lobby/loby.tscn"
		if grade_num > 7:
			next_scene_path = "res://Scenes/StudentCard/student_card.tscn"
		
		# Reset schedules and week
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.returned_from_student_card = false
		
		if grade_num == 7:
			# Grade 7 full restart: clear selection so they select again
			GameState.lobby_tutorial_completed = false
			GameState.approved_students.clear()
			GameState.grade7_student_ids.clear()
			
			var AturJadwalScript = load("res://Scripts/AturJadwal/atur_jadwal.gd")
			if AturJadwalScript and "tutorial_phase1_done" in AturJadwalScript:
				AturJadwalScript.tutorial_phase1_done = false
				AturJadwalScript.tutorial_phase3_done = false
			var LobbyScript = load("res://Scripts/Lobby/loby.gd")
			if LobbyScript and "tutorial_shown" in LobbyScript:
				LobbyScript.tutorial_shown = false
		else:
			# Grade 8 or 9 restart: restore academic stats back to base_akademis
			GameState.lobby_tutorial_completed = true
			for student in GameState.approved_students:
				student["kepribadian1"] = 80.0
				student["kepribadian2"] = 80.0
				if student.has("base_akademis1"):
					student["akademis1"] = student["base_akademis1"]
				if student.has("base_akademis2"):
					student["akademis2"] = student["base_akademis2"]
				if student.has("base_akademis3"):
					student["akademis3"] = student["base_akademis3"]
					
		GameState.next_scene = next_scene_path
	else:
		GameState.next_scene = "res://Scenes/Lobby/loby.tscn"
		
	get_tree().change_scene_to_file("res://Scenes/Loading/loading.tscn")
