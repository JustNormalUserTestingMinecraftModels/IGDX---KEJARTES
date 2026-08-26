extends Control

signal simulation_finished
signal _minigame_result(won: bool)  # internal: bridges minigame signals back to _play_minigame
signal _event_decision_signal(accepted: bool, selected_students: Array[StudentData])
signal _continue_tapped
signal _tutorial_closed
signal _summary_closed

@export var menjodohkan_scene: PackedScene
@export var variabel_scene: PackedScene
@export var pilihan_ganda_scene: PackedScene
@export var password_scene: PackedScene
@export var main_bola_scene: PackedScene
@export var badminton_scene: PackedScene
@export var buat_batik_scene: PackedScene
@export var lomba_menari_scene: PackedScene
@export var event_warning_scene: PackedScene
@export var result_checkup_scene: PackedScene
@export var event_announcement_scene: PackedScene
@export var event_student_select_scene: PackedScene
@export var day_summary_popup_scene: PackedScene

# ── Visual - Student Cards ────────────────────────────────────────────────────
@export_group("Visual - Student Cards")
## Optional PNG for the student card panel background.
@export var student_card_texture: Texture2D = null
@export var student_card_color: Color = Color(0.1, 0.14, 0.22, 0.9)
@export var student_card_border_color: Color = Color(0.2, 0.35, 0.55, 0.7)
## Optional PNG to replace the ⚡ energy icon.
@export var energy_icon_texture: Texture2D = null
## Optional PNG to replace the 😊 mood icon.
@export var mood_icon_texture: Texture2D = null
@export var card_font: Font = null
@export var card_name_font_size: int = 36

# ── Visual - Stat Pill Badges ─────────────────────────────────────────────────
@export_group("Visual - Stat Pill Badges")
@export var pill_akademis_color: Color = Color(0.16, 0.27, 1.0)
@export var pill_senibudaya_color: Color = Color(0.0, 0.6, 0.25)
@export var pill_olahraga_color: Color = Color(0.75, 0.1, 0.1)
@export var pill_energy_loss_color: Color = Color(0.85, 0.2, 0.2)
@export var pill_mood_loss_color: Color = Color(0.88, 0.42, 0.08)
@export var pill_recovery_color: Color = Color(0.1, 0.65, 0.3)
@export var pill_bonus_color: Color = Color(0.82, 0.68, 0.08)
@export var pill_warning_color: Color = Color(0.78, 0.08, 0.08)
@export var pill_holiday_color: Color = Color(0.32, 0.52, 0.12)
@export var pill_font_size: int = 26

# ── Visual - Day Summary Popup ────────────────────────────────────────────────
@export_group("Visual - Day Summary Popup")
## Optional PNG for the summary card background.
@export var day_summary_card_texture: Texture2D = null
@export var day_summary_card_color: Color = Color(0.06, 0.08, 0.16, 0.97)
@export var day_summary_border_color: Color = Color(0.35, 0.48, 0.72, 0.85)
@export var day_summary_dim_color: Color = Color(0.0, 0.0, 0.0, 0.62)
@export var day_summary_font: Font = null
@export var day_summary_title_font_size: int = 44
@export var day_summary_body_font_size: int = 30

@export_group("End Simulation Tutorial (Week 1)")
@export var end_tutorial_title: String = "Selamat Menyelesaikan Minggu Pertama! 🎓"
@export_multiline var end_tutorial_text: String = "Kerja bagus, Guru! Kamu telah berhasil membimbing murid-muridmu melewati simulasi minggu pertama.\n\nMulai sekarang, alur permainan akan terus berlanjut dalam siklus:\nAtur Jadwal ➔ Simulasi Hari Sekolah ➔ Evaluasi Mingguan\n\n🎯 Misi Utamamu:\nTingkatkan seluruh kemampuan murid (Akademis, Olahraga, dan Seni Budaya) hingga melampaui Target Ambang Batas masing-masing sebelum Minggu ke-8 selesai!\n\nPada akhir Minggu ke-8, akan diadakan Ujian Kenaikan Kelas untuk menentukan kelulusan murid-muridmu ke jenjang berikutnya. Rencanakan jadwal belajar dan istirahat dengan taktis!"
@export var end_tutorial_prompt: String = "KLIK DIMANA SAJA UNTUK MELANJUTKAN"

# ── Node references ───────────────────────────────────────────────────────────
@onready var day_screen: VBoxContainer    = $DayScreen
@onready var day_number_label: Label      = $DayScreen/DayNumberLabel
@onready var day_label: Label             = $DayScreen/DayLabel
@onready var book_clock_widget: Control   = $DayScreen/BookClockWidget
@onready var progress_bar: ProgressBar    = $DayScreen/ProgressBar
@onready var status_label: Label          = $DayScreen/StatusLabel
@onready var student_status_container: VBoxContainer = $DayScreen/StudentScroll/StudentStatusContainer
@onready var click_to_continue_label: Label = $DayScreen/ClickToContinueLabel
@onready var back_button: Button          = $DayScreen/BackButton
@onready var skip_button: Button          = $DayScreen/SkipButton
@onready var game_container: Control      = $GameContainer

const DAYS = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
const DAY_FILL_DURATION = 2.0   # seconds to fill a day's progress bar

# Event distribution chances (total 100)
const CHANCE_NOTHING  = 20
const CHANCE_MINIGAME = 40
const CHANCE_EVENT    = 40

# National Holidays definition
const HOLIDAYS = {
	3: { "Rabu": "Hari Kemerdekaan RI" },
	6: { "Senin": "Maulid Nabi Muhammad SAW" }
}

# ── State ─────────────────────────────────────────────────────────────────────
var current_day: int = 0
var is_running: bool = false
var current_minigame: Node = null

var akademis_scenes: Array = []
var olahraga_scenes: Array = []
var seni_scenes: Array     = []
var student_manager: StudentManager = null
var is_skipped: bool = false
var minigames_played_this_week: int = 0
var events_triggered_this_week: int = 0
var max_events_this_week: int = 2
var is_waiting_for_continue: bool = false

var embedded_widgets: Dictionary = {} # student_name -> Dictionary of node refs

# End Simulation Tutorial internal variables
var _tutorial_panel: PanelContainer = null
var _tutorial_title_label: Label = null
var _tutorial_body_label: Label = null
var _tutorial_prompt_label: Label = null
var _blink_tween: Tween = null
var _is_tutorial_active: bool = false
var _is_summary_active: bool = false

# Helper to retrieve custom UI textures dynamically without declaring new class variables
func _get_playful_texture(type: String) -> Texture2D:
	var path := ""
	match type:
		"energy":
			if energy_icon_texture != null:
				return energy_icon_texture
			path = "res://Assets/Images/UI/Placeholders/icon_energy.png"
		"mood":
			if mood_icon_texture != null:
				return mood_icon_texture
			path = "res://Assets/Images/UI/Placeholders/icon_mood.png"
		"akademis":
			path = "res://Assets/Images/UI/Placeholders/icon_akademis.png"
		"seni":
			path = "res://Assets/Images/UI/Placeholders/icon_seni.png"
		"olahraga":
			path = "res://Assets/Images/UI/Placeholders/icon_olahraga.png"
		"istirahat":
			path = "res://Assets/Images/UI/Placeholders/icon_istirahat.png"
		"libur":
			path = "res://Assets/Images/UI/Placeholders/icon_libur.png"
		"warning":
			path = "res://Assets/Images/UI/Placeholders/icon_warning.png"
		"dialogue_box":
			path = "res://Assets/Images/UI/Placeholders/dialogue_box.png"
		"card_bg":
			if student_card_texture != null:
				return student_card_texture
			path = "res://Assets/Images/UI/Placeholders/student_card_bg.png"
	
	if path != "" and ResourceLoader.exists(path):
		return load(path)
		
	# Fallback check for SVGs
	if path.ends_with(".png"):
		var svg_path = path.replace(".png", ".svg")
		if ResourceLoader.exists(svg_path):
			return load(svg_path)
			
	return null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.hide()
	if skip_button:
		skip_button.pressed.connect(skip_to_results)
	_reset_day_ui()
	
	if menjodohkan_scene == null: menjodohkan_scene = load("res://Scenes/Minigames/Akademis/Menjodohkan.tscn")
	if variabel_scene == null: variabel_scene = load("res://Scenes/Minigames/Akademis/Variabel.tscn")
	if pilihan_ganda_scene == null: pilihan_ganda_scene = load("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	if password_scene == null: password_scene = load("res://Scenes/Minigames/Akademis/Password.tscn")
	if main_bola_scene == null: main_bola_scene = load("res://Scenes/Minigames/Olahraga/MainBola.tscn")
	if badminton_scene == null: badminton_scene = load("res://Scenes/Minigames/Olahraga/Badminton.tscn")
	if buat_batik_scene == null: buat_batik_scene = load("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	if lomba_menari_scene == null: lomba_menari_scene = load("res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn")
	if event_warning_scene == null: event_warning_scene = load("res://Scenes/SchoolSimulation/EventWarning.tscn")
	
	setup_scenes(
		menjodohkan_scene, variabel_scene, pilihan_ganda_scene, password_scene,
		main_bola_scene, badminton_scene, buat_batik_scene, lomba_menari_scene
	)
	start_simulation()

func _input(event: InputEvent) -> void:
	if _is_tutorial_active:
		var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		var is_touch = (event is InputEventScreenTouch and event.pressed)
		var is_key = (event is InputEventKey and event.pressed and event.keycode != KEY_O)
		
		if is_click or is_touch or is_key:
			_tutorial_closed.emit()
			get_viewport().set_input_as_handled()
			return

	if _is_summary_active:
		var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		var is_touch = (event is InputEventScreenTouch and event.pressed)
		var is_key = (event is InputEventKey and event.pressed and event.keycode != KEY_O)
		
		if is_click or is_touch or is_key:
			_summary_closed.emit()
			get_viewport().set_input_as_handled()
			return

	if is_waiting_for_continue:
		var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		var is_touch = (event is InputEventScreenTouch and event.pressed)
		var is_key = (event is InputEventKey and event.pressed and event.keycode != KEY_O)
		
		if is_click or is_touch or is_key:
			is_waiting_for_continue = false
			_continue_tapped.emit()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_O:
			skip_to_results()

func setup_scenes(
	menjodohkan: PackedScene, variabel: PackedScene,
	pilihan_ganda: PackedScene, password: PackedScene,
	main_bola: PackedScene, badminton: PackedScene,
	buat_batik: PackedScene, lomba_menari: PackedScene
) -> void:
	akademis_scenes = [menjodohkan, variabel, pilihan_ganda, password]
	olahraga_scenes = [main_bola, badminton]
	seni_scenes     = [buat_batik, lomba_menari]

# ─────────────────────────────────────────────────────────────────────────────
func start_simulation() -> void:
	if is_running:
		return
	is_running  = true
	current_day = 0
	is_skipped = false
	minigames_played_this_week = 0
	events_triggered_this_week = 0
	max_events_this_week = randi_range(1, 2)
	student_manager = StudentManager.new()
	student_manager.initialize_from_gamestate()
	if skip_button:
		skip_button.show()
	_run_day()

# ─────────────────────────────────────────────────────────────────────────────
# Runs one full day: shows the day screen, fills the progress bar,
# triggers an optional minigame or event, then awaits click to continue to next day.
func _run_day() -> void:
	if is_skipped:
		return
	if current_day >= DAYS.size():
		_on_week_complete()
		return

	var day_name = DAYS[current_day]

	# ── Background color and pattern transitions ─────────────────────────────
	var bg_colors = [
		Color(0.25, 0.08, 0.08, 0.95),  # Monday: soft red/crimson
		Color(0.08, 0.22, 0.35, 0.95),  # Tuesday: soft dark blue/teal
		Color(0.22, 0.08, 0.32, 0.95),  # Wednesday: soft plum/purple
		Color(0.35, 0.20, 0.08, 0.95),  # Thursday: soft orange/amber
		Color(0.08, 0.28, 0.18, 0.95)   # Friday: soft forest/mint green
	]
	var bg_node = get_node_or_null("Background")
	if bg_node:
		var target_color = bg_colors[current_day % bg_colors.size()]
		var target_pattern = current_day % 5 # Grid, Stripes, Dots, Zigzag, Stars
		bg_node.set("pattern_type", target_pattern)
		if current_day == 0:
			bg_node.set("bg_color", target_color)
		else:
			var bg_tween = create_tween()
			bg_tween.tween_property(bg_node, "bg_color", target_color, 1.0)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── Reset this day's UI ───────────────────────────────────────────────────
	_reset_day_ui()
	
	# Apply unique progress bar fill texture for each day
	var eng_days = ["monday", "tuesday", "wednesday", "thursday", "friday"]
	var eng_day = eng_days[current_day % eng_days.size()]
	var fill_path = "res://Assets/Images/UI/Placeholders/progress_fill_%s.png" % eng_day
	if ResourceLoader.exists(fill_path):
		var fill_tex = load(fill_path)
		if fill_tex and progress_bar:
			var fill_style = StyleBoxTexture.new()
			fill_style.texture = fill_tex
			fill_style.axis_stretch_horizontal = 1 # StyleBoxTexture.AXIS_STRETCH_TILE
			progress_bar.add_theme_stylebox_override("fill", fill_style)

	day_number_label.text = "Hari %d dari %d" % [current_day + 1, DAYS.size()]
	day_label.text        = day_name
	status_label.text     = "Perjalanan ke sekolah..."

	# Reset and configure book-clock widget for the new day
	if book_clock_widget and book_clock_widget.has_method("set_day"):
		book_clock_widget.call("reset")
		book_clock_widget.call("set_day", day_name)

	# Render embedded student status UI on DayScreen
	_render_embedded_student_status()

	# Fade the screen in fresh for each day
	day_screen.modulate.a = 0.0
	day_screen.show()
	var fade_in = create_tween()
	fade_in.tween_property(day_screen, "modulate:a", 1.0, 0.5)
	await fade_in.finished
	if is_skipped:
		return

	# ── Daily Energy & Mood Decay (Integrated non-blocking animation) ────────
	var decay_results: Array[Dictionary] = []
	if student_manager:
		decay_results = student_manager.apply_daily_decay_all(day_name)

	# ── Phase 1: Fill bar to a random "event trigger" point ──────────────────
	var trigger_pct = randf_range(0.5, 0.8) * 100.0
	var phase1_dur  = DAY_FILL_DURATION * (trigger_pct / 100.0)

	status_label.text = "Melewati hari sekolah..."
	
	# Create parallel tweens for day progress bar AND embedded student energy/mood decay bars!
	var day_tween = create_tween().set_parallel(true)
	day_tween.tween_property(progress_bar, "value", trigger_pct, phase1_dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if book_clock_widget and book_clock_widget.has_method("set_progress"):
		day_tween.tween_method(func(v: float): book_clock_widget.call("set_progress", v / 100.0), 0.0, trigger_pct, phase1_dur)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	_animate_embedded_decay_bars(day_tween, decay_results, phase1_dur)
	await day_tween.finished
	if is_skipped:
		return

	# ── Event rolls here ──────────────────────────────────────────────────────
	await _roll_event(day_name)
	if is_skipped:
		return

	# ── Phase 2: Fill remaining bar to 100% ──────────────────────────────────
	var phase2_dur = DAY_FILL_DURATION * ((100.0 - trigger_pct) / 100.0)
	status_label.text = "Melanjutkan hari..."
	var bar_phase2 = create_tween().set_parallel(true)
	bar_phase2.tween_property(progress_bar, "value", 100.0, phase2_dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if book_clock_widget and book_clock_widget.has_method("set_progress"):
		bar_phase2.tween_method(func(v: float): book_clock_widget.call("set_progress", v / 100.0), trigger_pct, 100.0, phase2_dur)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await bar_phase2.finished
	if is_skipped:
		return

	status_label.text = day_name + " selesai! ✓"
	progress_bar.show()
	
	# ── End-of-Day Summary ────────────────────────────────────────────────────
	await _show_day_summary(day_name)

	# ── Blinking "Click anywhere to continue" prompt ─────────────────────────
	await _await_click_to_continue()
	if is_skipped:
		return

	# Fade out before moving to the next day
	var fade_out = create_tween()
	fade_out.tween_property(day_screen, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	if is_skipped:
		return

	current_day += 1
	_run_day()

func _await_click_to_continue() -> void:
	if click_to_continue_label == null:
		await get_tree().create_timer(1.0).timeout
		return
		
	click_to_continue_label.modulate.a = 1.0
	click_to_continue_label.show()
	is_waiting_for_continue = true

	# Blinking in and out animation
	var pulse = create_tween().set_loops()
	pulse.tween_property(click_to_continue_label, "modulate:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(click_to_continue_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	await _continue_tapped

	pulse.kill()
	click_to_continue_label.hide()

# ─────────────────────────────────────────────────────────────────────────────
# Render embedded 4 student status cards directly into DayScreen
func _render_embedded_student_status() -> void:
	if student_status_container == null or student_manager == null:
		return

	for child in student_status_container.get_children():
		child.queue_free()

	embedded_widgets.clear()

	for student in student_manager.students:
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var card_bg = _get_playful_texture("card_bg")
		if card_bg != null:
			var style_tex = StyleBoxTexture.new()
			style_tex.texture = card_bg
			style_tex.content_margin_left = 24
			style_tex.content_margin_right = 24
			style_tex.content_margin_top = 16
			style_tex.content_margin_bottom = 16
			panel.add_theme_stylebox_override("panel", style_tex)
		else:
			var style = StyleBoxFlat.new()
			style.bg_color = student_card_color
			style.border_color = student_card_border_color
			style.corner_radius_top_left = 12
			style.corner_radius_top_right = 12
			style.corner_radius_bottom_left = 12
			style.corner_radius_bottom_right = 12
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			panel.add_theme_stylebox_override("panel", style)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(margin)

		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 8)
		margin.add_child(card_vbox)

		var main_hbox = HBoxContainer.new()
		main_hbox.add_theme_constant_override("separation", 24)
		card_vbox.add_child(main_hbox)

		# Left column: Name & Personality tag
		var left_vbox = VBoxContainer.new()
		left_vbox.custom_minimum_size = Vector2(240, 0)
		left_vbox.add_theme_constant_override("separation", 8)
		main_hbox.add_child(left_vbox)

		var name_lbl = Label.new()
		name_lbl.text = student.student_name
		name_lbl.add_theme_font_size_override("font_size", 36)
		var is_dark_bg = (card_bg == null)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1) if is_dark_bg else Color(0.1, 0.15, 0.25))
		left_vbox.add_child(name_lbl)

		var p_badge = Label.new()
		p_badge.text = " %s " % student.personality
		p_badge.add_theme_font_size_override("font_size", 26)
		p_badge.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0) if is_dark_bg else Color(0.12, 0.32, 0.55))
		p_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color(0.15, 0.3, 0.5, 0.6) if is_dark_bg else Color(0.82, 0.88, 0.94)
		p_style.corner_radius_top_left = 6
		p_style.corner_radius_top_right = 6
		p_style.corner_radius_bottom_left = 6
		p_style.corner_radius_bottom_right = 6
		p_badge.add_theme_stylebox_override("normal", p_style)
		left_vbox.add_child(p_badge)

		# Right column: Bars (Energy & Mood)
		var right_vbox = VBoxContainer.new()
		right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.add_theme_constant_override("separation", 12)
		main_hbox.add_child(right_vbox)

		var e_data = _add_embedded_bar_row(right_vbox, "⚡", student.energy, Color(1.0, 0.85, 0.2))
		var m_data = _add_embedded_bar_row(right_vbox, "😊", student.mood, Color(1.0, 0.45, 0.7))

		# Pill badges row
		var pill_flow = _build_pill_badges_for_student(student, DAYS[current_day] if current_day < DAYS.size() else "")
		if pill_flow:
			card_vbox.add_child(pill_flow)

		student_status_container.add_child(panel)

		embedded_widgets[student.student_name] = {
			"student": student,
			"e_bar": e_data["bar"],
			"e_lbl": e_data["lbl"],
			"m_bar": m_data["bar"],
			"m_lbl": m_data["lbl"]
		}

func _add_embedded_bar_row(parent_vbox: VBoxContainer, icon_text: String, current_val: float, color: Color) -> Dictionary:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent_vbox.add_child(row)

	var icon_tex := _get_playful_texture("energy" if icon_text == "⚡" else "mood")
	if icon_tex != null:
		var tex_rect = TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.custom_minimum_size = Vector2(36, 36)
		tex_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tex_rect)
	else:
		var icon_lbl = Label.new()
		icon_lbl.text = icon_text
		icon_lbl.custom_minimum_size = Vector2(36, 0)
		icon_lbl.add_theme_font_size_override("font_size", 28)
		icon_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon_lbl)

	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(100, 32)
	bar.value = current_val

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("background", bg_style)
	row.add_child(bar)

	var info_lbl = Label.new()
	info_lbl.custom_minimum_size = Vector2(180, 0)
	info_lbl.add_theme_font_size_override("font_size", 26)
	info_lbl.text = "%d/100" % int(current_val)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	info_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	row.add_child(info_lbl)

	return {
		"bar": bar,
		"lbl": info_lbl
	}

func _build_pill_badges_for_student(student: StudentData, day_name: String) -> HBoxContainer:
	# Returns an HBoxContainer of colored pill Label badges showing what will change today.
	# Sources: schedule (known before day), warnings (energy low).
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var student_id = student.id
	var schedule = {}
	if student_id != 0 and GameState.day_schedules.has(student_id):
		schedule = GameState.day_schedules[student_id].get(day_name, {})
	
	var category = schedule.get("category", "")
	if category == "Akademik": category = "Akademis"
	
	# Holiday
	var week = GameState.minggu_ke
	var week_holidays = {}
	if week == 3: week_holidays["Rabu"] = true
	if week == 6: week_holidays["Senin"] = true
	if week_holidays.has(day_name):
		_add_pill(hbox, "🌿 Libur", pill_holiday_color)
		return hbox

	match category:
		"Akademis":
			var gain = 6.0 if student.specialty_category == "Akademis" else 3.0
			_add_pill(hbox, "+%.0f Akademis 📚" % gain, pill_akademis_color)
		"SeniBudaya":
			var gain = 6.0 if student.specialty_category == "SeniBudaya" else 3.0
			_add_pill(hbox, "+%.0f Seni 🎨" % gain, pill_senibudaya_color)
		"Olahraga":
			var gain = 6.0 if student.specialty_category == "Olahraga" else 3.0
			_add_pill(hbox, "+%.0f Olahraga ⚽" % gain, pill_olahraga_color)
		"Istirahat":
			_add_pill(hbox, "+25 ⚡ Istirahat", pill_recovery_color)
		_:
			_add_pill(hbox, "Kosong", Color(0.35, 0.35, 0.4))

	# Energy/Mood cost estimate (show if studying)
	if category != "" and category != "Istirahat":
		_add_pill(hbox, "~-15 ⚡", pill_energy_loss_color)
		_add_pill(hbox, "~-10 😊", pill_mood_loss_color)
	
	# Warning if already low energy
	if student.energy <= 20.0:
		_add_pill(hbox, "⚠ KELELAHAN", pill_warning_color)
	
	return hbox

func _add_pill(parent: HBoxContainer, text: String, bg_color: Color) -> void:
	var clean_text := text
	var icon_key := ""
	
	if "Libur" in text:
		clean_text = "Libur"
		icon_key = "libur"
	elif "Akademis" in text:
		clean_text = text.replace("📚", "").strip_edges()
		icon_key = "akademis"
	elif "Seni" in text:
		clean_text = text.replace("🎨", "").strip_edges()
		icon_key = "seni"
	elif "Olahraga" in text:
		clean_text = text.replace("⚽", "").strip_edges()
		icon_key = "olahraga"
	elif "Istirahat" in text:
		clean_text = text.replace("⚡", "").strip_edges()
		icon_key = "istirahat"
	elif "⚡" in text:
		clean_text = text.replace("⚡", "").replace("~", "").strip_edges()
		icon_key = "energy"
	elif "😊" in text:
		clean_text = text.replace("😊", "").replace("~", "").strip_edges()
		icon_key = "mood"
	elif "KELELAHAN" in text:
		clean_text = "KELELAHAN"
		icon_key = "warning"

	var icon_tex = _get_playful_texture(icon_key) if icon_key != "" else null
	if icon_tex != null:
		var pill_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = bg_color
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		pill_panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		pill_panel.add_child(hbox)
		
		var tex_rect = TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.custom_minimum_size = Vector2(24, 24)
		tex_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tex_rect)
		
		var lbl = Label.new()
		lbl.text = clean_text
		lbl.add_theme_font_size_override("font_size", pill_font_size)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		if card_font: lbl.add_theme_font_override("font", card_font)
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(lbl)
		
		parent.add_child(pill_panel)
	else:
		# Fallback to the original raw label behavior
		var lbl = Label.new()
		lbl.text = " %s " % text
		lbl.add_theme_font_size_override("font_size", pill_font_size)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		if card_font: lbl.add_theme_font_override("font", card_font)
		var style = StyleBoxFlat.new()
		style.bg_color = bg_color
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		lbl.add_theme_stylebox_override("normal", style)
		parent.add_child(lbl)

func _show_day_summary(day_name: String) -> void:
	if not student_manager:
		return
	var summary = student_manager.get_day_summary(day_name)
	if summary.is_empty():
		return
		
	var summary_scene = day_summary_popup_scene
	if summary_scene == null:
		summary_scene = load("res://Scenes/SchoolSimulation/DaySummaryPopup.tscn")
		
	if summary_scene == null:
		return
		
	var summary_instance = summary_scene.instantiate()
	
	# Clear the default instanced rows in the popup (to keep it clean)
	var rows_container = summary_instance.get_node("DimOverlay/MarginContainer/CardPanel/MarginContainer/VBoxContainer/RowsContainer")
	if rows_container:
		for child in rows_container.get_children():
			child.queue_free()

	add_child(summary_instance)
	summary_instance.setup_summary(day_name, [], student_manager.students) # Pass empty summary array to skip instantiating simple rows!
	
	# Reparent our StudentScroll container into the popup's RowsContainer AFTER setup_summary has cleared the old rows
	if rows_container:
		var scroll = get_node_or_null("DayScreen/StudentScroll")
		if scroll:
			scroll.get_parent().remove_child(scroll)
			rows_container.add_child(scroll)
			scroll.show()
			# Ensure it takes full vertical space inside the popup
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	await summary_instance.summary_dismissed
	
	# Reparent back to DayScreen
	var scroll_back = summary_instance.find_child("StudentScroll", true, false)
	if scroll_back:
		scroll_back.get_parent().remove_child(scroll_back)
		var day_screen_node = get_node_or_null("DayScreen")
		if day_screen_node:
			day_screen_node.add_child(scroll_back)
			# Move it to the bottom of the children list so order is preserved
			day_screen_node.move_child(scroll_back, day_screen_node.get_child_count() - 1)
		scroll_back.hide()


func _animate_embedded_decay_bars(parallel_tween: Tween, decay_results: Array[Dictionary], duration: float) -> void:
	for res in decay_results:
		var s_name = res.get("student_name", "")
		var w = embedded_widgets.get(s_name, {})
		if w.is_empty():
			continue

		var curr_e = float(res.get("current_energy", 80.0))
		var e_loss = float(res.get("energy_loss", 5.0))
		var start_e = clampf(curr_e + e_loss, 0.0, 100.0)

		var curr_m = float(res.get("current_mood", 80.0))
		var m_loss = float(res.get("mood_loss", 5.0))
		var start_m = clampf(curr_m + m_loss, 0.0, 100.0)

		var e_bar = w["e_bar"] as ProgressBar
		var e_lbl = w["e_lbl"] as Label
		var m_bar = w["m_bar"] as ProgressBar
		var m_lbl = w["m_lbl"] as Label

		e_bar.value = start_e
		m_bar.value = start_m

		parallel_tween.tween_property(e_bar, "value", curr_e, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		parallel_tween.tween_property(m_bar, "value", curr_m, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

		var is_dark_bg = (_get_playful_texture("card_bg") == null)
		if e_loss >= 0:
			e_lbl.text = "%d/100 (-%d)" % [int(curr_e), int(e_loss)]
			e_lbl.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4) if is_dark_bg else Color(0.75, 0.15, 0.15))
		else:
			e_lbl.text = "%d/100 (+%d)" % [int(curr_e), int(-e_loss)]
			e_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5) if is_dark_bg else Color(0.1, 0.5, 0.2))

		if m_loss >= 0:
			m_lbl.text = "%d/100 (-%d)" % [int(curr_m), int(m_loss)]
			m_lbl.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4) if is_dark_bg else Color(0.75, 0.15, 0.15))
		else:
			m_lbl.text = "%d/100 (+%d)" % [int(curr_m), int(-m_loss)]
			m_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5) if is_dark_bg else Color(0.1, 0.5, 0.2))

# Smoothly animate embedded progress bars for post-event or minigame stat updates
func _animate_embedded_stat_updates(duration: float = 0.6) -> void:
	if student_status_container == null or student_manager == null:
		return
		
	if embedded_widgets.is_empty():
		_render_embedded_student_status()
		return
		
	var parallel_tween = create_tween().set_parallel(true)
	var has_updates = false
	
	var is_dark_bg = (_get_playful_texture("card_bg") == null)
	var gain_color = Color(0.3, 0.95, 0.5) if is_dark_bg else Color(0.1, 0.5, 0.2)
	var loss_color = Color(0.95, 0.4, 0.4) if is_dark_bg else Color(0.75, 0.15, 0.15)
	var normal_color = Color(0.8, 0.85, 0.9) if is_dark_bg else Color(0.2, 0.25, 0.35)
	
	for student in student_manager.students:
		var w = embedded_widgets.get(student.student_name, {})
		if w.is_empty():
			continue
			
		var e_bar = w["e_bar"] as ProgressBar
		var e_lbl = w["e_lbl"] as Label
		var m_bar = w["m_bar"] as ProgressBar
		var m_lbl = w["m_lbl"] as Label
		
		var start_e = e_bar.value
		var target_e = student.energy
		var delta_e = target_e - start_e
		
		var start_m = m_bar.value
		var target_m = student.mood
		var delta_m = target_m - start_m
		
		if absf(delta_e) > 0.1:
			has_updates = true
			parallel_tween.tween_property(e_bar, "value", target_e, duration)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var sign_str = "+%d" % int(delta_e) if delta_e > 0 else "%d" % int(delta_e)
			e_lbl.text = "%d/100 (%s)" % [int(target_e), sign_str]
			if delta_e > 0:
				e_lbl.add_theme_color_override("font_color", gain_color)
			else:
				e_lbl.add_theme_color_override("font_color", loss_color)
				
		if absf(delta_m) > 0.1:
			has_updates = true
			parallel_tween.tween_property(m_bar, "value", target_m, duration)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var sign_str = "+%d" % int(delta_m) if delta_m > 0 else "%d" % int(delta_m)
			m_lbl.text = "%d/100 (%s)" % [int(target_m), sign_str]
			if delta_m > 0:
				m_lbl.add_theme_color_override("font_color", gain_color)
			else:
				m_lbl.add_theme_color_override("font_color", loss_color)

	if has_updates:
		await parallel_tween.finished
		await get_tree().create_timer(0.5).timeout
		# Reset label text to clean standard format
		for student in student_manager.students:
			var w = embedded_widgets.get(student.student_name, {})
			if not w.is_empty():
				var e_lbl = w["e_lbl"] as Label
				var m_lbl = w["m_lbl"] as Label
				e_lbl.text = "%d/100" % int(student.energy)
				e_lbl.add_theme_color_override("font_color", normal_color)
				m_lbl.text = "%d/100" % int(student.mood)
				m_lbl.add_theme_color_override("font_color", normal_color)

# ─────────────────────────────────────────────────────────────────────────────
func _roll_event(day_name: String) -> void:
	var week = GameState.minggu_ke
	if HOLIDAYS.has(week) and HOLIDAYS[week].has(day_name):
		var holiday_name = HOLIDAYS[week][day_name]
		status_label.text = "Hari Libur Nasional: %s 🌿" % holiday_name
		await get_tree().create_timer(1.2).timeout
		return

	var counts = GameState.get_jadwal_for_day(day_name)
	var w_akademis = counts.get("Akademis", 0)
	var w_olahraga = counts.get("Olahraga", 0)
	var w_seni = counts.get("SeniBudaya", 0)
	var active_studying = w_akademis + w_olahraga + w_seni
	var resting_count = counts.get("Istirahat", 0)

	# Dynamic weight calculation:
	# Minigame weight scales with active studying students (0 to 4 * 15 = 0 to 60)
	var w_minigame: int = 0
	if minigames_played_this_week < 2:
		w_minigame = active_studying * 15

	# Event weight capped at 1-2 per week
	var w_event: int = 0
	if events_triggered_this_week < max_events_this_week:
		w_event = 25
		
		# ── Quirk: Biang Onar — adds +10 event weight when this student is studying ──
		if student_manager:
			for s in student_manager.students:
				if s.quirk == "Biang Onar":
					var sid = s.id
					if sid != 0 and GameState.day_schedules.has(sid):
						var day_sched = GameState.day_schedules[sid].get(day_name, {})
						var cat = day_sched.get("category", "")
						# Only boost if Biang Onar student is actively studying (not resting)
						if cat != "" and cat != "DayOff" and cat != "Istirahat":
							w_event += s.biang_onar_event_weight_bonus
	
	# Normal day weight scales inversely with active studying (base 20 + resting * 10)
	var w_normal: int = 20 + (resting_count * 10)

	var total_weight = w_normal + w_minigame + w_event

	var outcome = "Normal"
	if total_weight > 0:
		var roll = randi() % total_weight
		if roll < w_normal:
			outcome = "Normal"
		elif roll < w_normal + w_minigame:
			outcome = "Minigame"
		else:
			outcome = "Event"

	if outcome == "Normal":
		status_label.text = "Hari biasa..."
		await get_tree().create_timer(0.8).timeout

	elif outcome == "Minigame":
		var total_subject_weight = w_akademis + w_olahraga + w_seni
		var category_selected = ""

		if total_subject_weight == 0:
			var cat_roll = randi() % 3
			if cat_roll == 0: category_selected = "Akademis"
			elif cat_roll == 1: category_selected = "Olahraga"
			else: category_selected = "SeniBudaya"
		else:
			var choice = randi() % total_subject_weight
			if choice < w_akademis:
				category_selected = "Akademis"
			elif choice < w_akademis + w_olahraga:
				category_selected = "Olahraga"
			else:
				category_selected = "SeniBudaya"

		if category_selected == "Akademis":
			var scene = akademis_scenes[randi() % akademis_scenes.size()]
			await _show_event_warning("📚 KEGIATAN AKADEMIS!", Color(0.3, 0.6, 1.0))
			await _play_minigame(scene, "Akademis")
		elif category_selected == "Olahraga":
			var scene = olahraga_scenes[randi() % olahraga_scenes.size()]
			await _show_event_warning("⚽ KEGIATAN OLAHRAGA!", Color(0.2, 0.9, 0.4))
			await _play_minigame(scene, "Olahraga")
		else:
			var scene = seni_scenes[randi() % seni_scenes.size()]
			await _show_event_warning("🎨 KEGIATAN SENI BUDAYA!", Color(1.0, 0.75, 0.2))
			await _play_minigame(scene, "SeniBudaya")

	else:
		await _trigger_random_event(day_name)

# ─────────────────────────────────────────────────────────────────────────────
func _trigger_random_event(day_name: String) -> void:
	events_triggered_this_week += 1
	var event_id = randi() % 5
	
	# ── Quirk: Biang Onar — events are ±20% stronger when active ──
	# Check if any student with Biang Onar is in the roster (affects all events)
	var biang_onar_active: bool = false
	var biang_onar_scale: float = 0.0
	if student_manager:
		for s in student_manager.students:
			if s.quirk == "Biang Onar":
				biang_onar_active = true
				biang_onar_scale = s.biang_onar_positive_event_scale
				break
	
	match event_id:
		0:
			var stat_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := -15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Les Tambahan Akademis 📚",
				"Sekolah membuka kelas Les Bimbingan Intensif setelah jam pelajaran.",
				"Akademis +%d" % int(stat_val),
				"Energy %d" % int(nrg_val),
				"Akademis", stat_val, nrg_val, 0.0
			)
		1:
			var stat_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := 10.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := -20.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Latihan Olahraga Ekstra ⚽",
				"Fasilitas lapangan terbuka gratis untuk sesi latihan bersama.",
				"Olahraga +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"Olahraga", stat_val, nrg_val, mood_val
			)
		2:
			var stat_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := -10.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Workshop Sanggar Seni 🎨",
				"Terdapat workshop pembuatan kerajinan dan tari daerah setempat.",
				"Seni Budaya +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"SeniBudaya", stat_val, nrg_val, mood_val
			)
		3:
			await _show_event_announcement("🍱 Kejutan Nasi Kotak Orang Tua!")
			# Biang Onar: global positive events are stronger
			var energy_bonus := 20.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_bonus := 25.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				# Route through apply_event_effects so quirks like Penyendiri apply correctly
				s.apply_event_effects("", 0.0, energy_bonus, mood_bonus)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Nasi Kotak Berbagi", names, "Semua siswa mendapat Energy +%d dan Mood +%d" % [int(energy_bonus), int(mood_bonus)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout
		4:
			await _show_event_announcement("🌧 Hujan Deras & Jalanan Licin!")
			# Biang Onar: global negative events are worse
			var energy_penalty := -15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_penalty := -15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				# Route through apply_event_effects so quirks like Penyendiri apply correctly
				s.apply_event_effects("", 0.0, energy_penalty, mood_penalty)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Kehujanan & Terpeleset", names, "Semua siswa mendapat Energy %d dan Mood %d" % [int(energy_penalty), int(mood_penalty)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout

func _handle_interactive_event(
	day_name: String, title: String, description: String,
	benefit: String, cost: String, category: String,
	stat_boost: float, energy_cost: float, mood_boost: float
) -> void:
	await _show_event_announcement(title)
	
	var dialog_scene = event_student_select_scene
	if dialog_scene == null:
		dialog_scene = load("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
		
	if dialog_scene == null:
		return
		
	var dialog_instance = dialog_scene.instantiate()
	add_child(dialog_instance)
	dialog_instance.setup_event(
		title, description, benefit, cost, category, student_manager.students,
		stat_boost, energy_cost, mood_boost
	)

	dialog_instance.event_decision_made.connect(
		func(evt_accepted: bool, selected: Array[StudentData]):
			_event_decision_signal.emit(evt_accepted, selected),
		CONNECT_ONE_SHOT
	)
	
	var res: Array = await _event_decision_signal
	var accepted: bool = res[0]
	var selected_students: Array[StudentData] = res[1]
	
	dialog_instance.queue_free()
	
	if accepted and not selected_students.is_empty():
		var affected_names: Array[String] = []
		for s in selected_students:
			s.apply_event_effects(category, stat_boost, energy_cost, mood_boost)
			affected_names.append(s.student_name)

		student_manager.record_event_result(day_name, title, affected_names, "%d siswa diikutsertakan" % selected_students.size())
		await _animate_embedded_stat_updates(0.6)

# ─────────────────────────────────────────────────────────────────────────────
func _play_minigame(game_scene: PackedScene, category: String) -> void:
	if game_scene == null:
		return

	# --- Debug Cheat Interception ---
	if "DebugManager" in get_node_or_null("/root") and get_node("/root/DebugManager").cheat_force_outcome != "":
		var forced_won = (get_node("/root/DebugManager").cheat_force_outcome == "win")
		minigames_played_this_week += 1
		var game_name = _scene_name(game_scene)
		var day_name = DAYS[current_day]
		if student_manager:
			student_manager.record_minigame_result(day_name, category, game_name + " (Bypass Cheat)", forced_won, 10, 10)
		await _animate_embedded_stat_updates(0.6)
		get_node("/root/DebugManager").log_message("Skipped minigame: %s, forced outcome: %s" % [game_name, "Win" if forced_won else "Lose"])
		return

	# Hide the day screen
	var tween_out = create_tween()
	tween_out.tween_property(day_screen, "modulate:a", 0.0, 0.4)
	await tween_out.finished
	day_screen.hide()

	# Spawn minigame
	current_minigame = game_scene.instantiate()
	current_minigame.modulate.a = 0.0
	game_container.add_child(current_minigame)
	current_minigame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if current_minigame.has_signal("minigame_won"):
		current_minigame.minigame_won.connect(_minigame_result.emit.bind(true), CONNECT_ONE_SHOT)
	if current_minigame.has_signal("minigame_lost"):
		current_minigame.minigame_lost.connect(_minigame_result.emit.bind(false), CONNECT_ONE_SHOT)

	if current_minigame.has_method("start_minigame"):
		var base_duration: float = 40.0 if _scene_name(game_scene) == "Menjodohkan" else 30.0
		var duration: float = base_duration
		match GameState.current_grade:
			8: duration = base_duration * 0.8
			9: duration = base_duration * 0.6
		var diff_level = clampi(GameState.current_grade - 6, 1, 3)
		current_minigame.start_minigame(diff_level, duration)


	var tween_in = create_tween()
	tween_in.tween_property(current_minigame, "modulate:a", 1.0, 0.4)
	await tween_in.finished

	if current_minigame.has_method("activate_minigame"):
		current_minigame.activate_minigame()

	var won: bool = await _minigame_result
	minigames_played_this_week += 1

	var game_name = _scene_name(game_scene)
	var day_name = DAYS[current_day]
	var mg_score: int = -1
	var mg_max_score: int = -1
	if current_minigame:
		if "score" in current_minigame:
			mg_score = current_minigame.score
		if "max_score" in current_minigame:
			mg_max_score = current_minigame.max_score

	if student_manager:
		student_manager.record_minigame_result(day_name, category, game_name, won, mg_score, mg_max_score)

	var tween_close = create_tween()
	tween_close.tween_property(current_minigame, "modulate:a", 0.0, 0.4)
	await tween_close.finished
	current_minigame.queue_free()
	current_minigame = null
	for child in game_container.get_children():
		child.queue_free()

	day_screen.show()
	var tween_back = create_tween()
	tween_back.tween_property(day_screen, "modulate:a", 1.0, 0.4)
	await tween_back.finished

	await _animate_embedded_stat_updates(0.6)

# ─────────────────────────────────────────────────────────────────────────────
func _on_week_complete() -> void:
	is_running = false
	if skip_button:
		skip_button.hide()
	_reset_day_ui()

	if result_checkup_scene:
		day_screen.hide()
		var checkup_instance = result_checkup_scene.instantiate()
		game_container.add_child(checkup_instance)
		checkup_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		checkup_instance.initialize_checkup(student_manager)
		await checkup_instance.checkup_closed
		checkup_instance.queue_free()

	day_screen.modulate.a = 0.0
	day_screen.show()
	var fade = create_tween()
	fade.tween_property(day_screen, "modulate:a", 1.0, 0.6)
	await fade.finished

	day_number_label.text = "Minggu selesai! 🎉"
	day_label.text        = "Akhir Pekan"
	progress_bar.value    = 100.0
	status_label.text     = "Selamat! Minggu sekolah telah selesai."
	back_button.show()

	if GameState.current_grade == 7 and GameState.minggu_ke == 1:
		await _show_end_simulation_tutorial()

func skip_to_results() -> void:
	if not is_running or is_skipped:
		return
	is_skipped = true
	
	if skip_button:
		skip_button.hide()
		
	while current_day < DAYS.size():
		var day_name = DAYS[current_day]
		if student_manager:
			var _decay = student_manager.apply_daily_decay_all(day_name)

		var week = GameState.minggu_ke
		if HOLIDAYS.has(week) and HOLIDAYS[week].has(day_name):
			current_day += 1
			continue

		var counts = GameState.get_jadwal_for_day(day_name)
		var w_akademis = counts.get("Akademis", 0)
		var w_olahraga = counts.get("Olahraga", 0)
		var w_seni = counts.get("SeniBudaya", 0)
		var active_studying = w_akademis + w_olahraga + w_seni
		var resting_count = counts.get("Istirahat", 0)

		var w_minigame: int = 0
		if minigames_played_this_week < 2:
			w_minigame = active_studying * 15

		var w_event: int = 0
		if events_triggered_this_week < max_events_this_week:
			w_event = 25

		var w_normal: int = 20 + (resting_count * 10)
		var total_weight = w_normal + w_minigame + w_event

		var outcome = "Normal"
		if total_weight > 0:
			var roll = randi() % total_weight
			if roll < w_normal:
				outcome = "Normal"
			elif roll < w_normal + w_minigame:
				outcome = "Minigame"
			else:
				outcome = "Event"

		if outcome != "Normal":
			var category = "Akademis"
			if outcome == "Minigame":
				minigames_played_this_week += 1
				var total_subj = w_akademis + w_olahraga + w_seni
				if total_subj > 0:
					var choice = randi() % total_subj
					if choice < w_akademis: category = "Akademis"
					elif choice < w_akademis + w_olahraga: category = "Olahraga"
					else: category = "SeniBudaya"
			else:
				category = "Event"
				events_triggered_this_week += 1

			var won = randf() > 0.4
			if student_manager:
				student_manager.record_minigame_result(day_name, category, "Simulasi Cepat", won)
		current_day += 1
		
	if current_minigame:
		current_minigame.queue_free()
		current_minigame = null
		
	for child in game_container.get_children():
		child.queue_free()
		
	_on_week_complete()

func _on_back_pressed() -> void:
	if student_manager:
		student_manager.write_back_to_gamestate()
	
	var completed_week = GameState.minggu_ke
	GameState.minggu_ke += 1
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	simulation_finished.emit()
	
	var max_weeks = GameState.max_minggu

	if completed_week >= max_weeks:
		Transition.change_scene("res://Scenes/EndGame/SemesterEnd.tscn")
	else:
		Transition.change_scene("res://Scenes/Lobby/loby.tscn")

# ── End Simulation Tutorial Implementation ──────────────────────────────────────
func _show_end_simulation_tutorial() -> void:
	_is_tutorial_active = true
	
	# Dimmer overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	add_child(overlay)
	
	# PanelContainer setup
	_tutorial_panel = PanelContainer.new()
	var box_tex = _get_playful_texture("dialogue_box")
	if box_tex != null:
		var style = StyleBoxTexture.new()
		style.texture = box_tex
		style.content_margin_left = 36
		style.content_margin_right = 36
		style.content_margin_top = 36
		style.content_margin_bottom = 36
		_tutorial_panel.add_theme_stylebox_override("panel", style)
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.06, 0.1, 0.93)
		style.border_color = Color(0.85, 0.7, 0.25, 0.9)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 18
		style.corner_radius_top_right = 18
		style.corner_radius_bottom_left = 18
		style.corner_radius_bottom_right = 18
		_tutorial_panel.add_theme_stylebox_override("panel", style)
	
	var viewport_size = get_viewport_rect().size
	var panel_width = min(viewport_size.x * 0.85, 900)
	_tutorial_panel.custom_minimum_size = Vector2(panel_width, 0)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_tutorial_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Title Label
	_tutorial_title_label = Label.new()
	_tutorial_title_label.text = end_tutorial_title
	_tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_title_label.add_theme_font_size_override("font_size", 42)
	_tutorial_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_tutorial_title_label.add_theme_constant_override("outline_size", 6)
	_tutorial_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(_tutorial_title_label)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Body Label
	_tutorial_body_label = Label.new()
	_tutorial_body_label.text = end_tutorial_text
	_tutorial_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.add_theme_font_size_override("font_size", 28)
	_tutorial_body_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	_tutorial_body_label.add_theme_constant_override("line_spacing", 8)
	_tutorial_body_label.custom_minimum_size = Vector2(panel_width - 100, 0)
	vbox.add_child(_tutorial_body_label)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Prompt Label
	_tutorial_prompt_label = Label.new()
	_tutorial_prompt_label.text = end_tutorial_prompt
	_tutorial_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_prompt_label.add_theme_font_size_override("font_size", 24)
	_tutorial_prompt_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
	_tutorial_prompt_label.add_theme_constant_override("outline_size", 5)
	_tutorial_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(_tutorial_prompt_label)
	
	overlay.add_child(_tutorial_panel)
	
	# Pulsing Prompt Tween
	_tutorial_prompt_label.modulate.a = 1.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 0.25, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Position Centering
	await get_tree().process_frame
	var panel_size = _tutorial_panel.size
	_tutorial_panel.position = (viewport_size - panel_size) / 2.0
	_tutorial_panel.pivot_offset = panel_size / 2.0
	
	# Scale animation bounce-in
	_tutorial_panel.scale = Vector2(0.8, 0.8)
	_tutorial_panel.modulate.a = 0.0
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(_tutorial_panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.25)
	await tween_in.finished
	
	# Wait for click
	await _tutorial_closed
	
	# Bounce scale-out
	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_property(_tutorial_panel, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween_out.tween_property(_tutorial_panel, "modulate:a", 0.0, 0.2)
	await tween_out.finished
	
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
		
	overlay.queue_free()
	_is_tutorial_active = false

# ─────────────────────────────────────────────────────────────────────────────
func _reset_day_ui() -> void:
	progress_bar.value    = 0.0
	progress_bar.hide()
	var scroll = get_node_or_null("DayScreen/StudentScroll")
	if scroll:
		scroll.hide()
	day_label.text        = ""
	day_number_label.text = ""
	status_label.text     = ""
	back_button.hide()
	if skip_button:
		skip_button.hide()
	_apply_progress_bar_style()

func _apply_progress_bar_style() -> void:
	if not progress_bar:
		return
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.95, 0.68, 0.08)
	fill_style.corner_radius_top_left = 10
	fill_style.corner_radius_top_right = 10
	fill_style.corner_radius_bottom_left = 10
	fill_style.corner_radius_bottom_right = 10
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.14, 0.92)
	bg_style.corner_radius_top_left = 10
	bg_style.corner_radius_top_right = 10
	bg_style.corner_radius_bottom_left = 10
	bg_style.corner_radius_bottom_right = 10
	progress_bar.add_theme_stylebox_override("background", bg_style)
	progress_bar.show_percentage = false

func _scene_name(scene: PackedScene) -> String:
	if scene == null:
		return "Unknown"
	match scene.resource_path.get_file().replace(".tscn", ""):
		"Menjodohkan":  return "Menjodohkan"
		"Variabel":     return "Variabel Matematika"
		"PilihanGanda": return "Pilihan Ganda"
		"Password":     return "Sandi Matematika"
		"MainBola":     return "Main Bola"
		"Badminton":    return "Badminton"
		"BuatBatik":    return "Buat Batik"
		"LombaMenari":  return "Lomba Menari"
	return scene.resource_path.get_file().replace(".tscn", "")

# ─────────────────────────────────────────────────────────────────────────────
func _show_event_warning(event_label: String, accent_color: Color) -> void:
	var warning_scene = event_warning_scene
	if warning_scene == null:
		warning_scene = load("res://Scenes/SchoolSimulation/EventWarning.tscn")
		
	if warning_scene == null:
		return
		
	var warning_instance = warning_scene.instantiate()
	add_child(warning_instance)
	
	if warning_instance.has_method("play_warning"):
		await warning_instance.play_warning(event_label, accent_color)
	else:
		await get_tree().create_timer(1.5).timeout
		warning_instance.queue_free()

func _show_event_announcement(event_label: String) -> void:
	var ann_scene = event_announcement_scene
	if ann_scene == null:
		ann_scene = load("res://Scenes/SchoolSimulation/EventAnnouncement.tscn")
		
	if ann_scene == null:
		return
		
	var ann_instance = ann_scene.instantiate()
	add_child(ann_instance)
	
	if ann_instance.has_method("play_announcement"):
		await ann_instance.play_announcement(event_label)
	else:
		await get_tree().create_timer(1.5).timeout
		ann_instance.queue_free()

func force_event(event_id: int) -> void:
	# Trigger a specific event immediately during simulation
	var day_name = DAYS[current_day] if current_day < DAYS.size() else "Senin"
	events_triggered_this_week += 1
	
	var biang_onar_active: bool = false
	var biang_onar_scale: float = 0.0
	if student_manager:
		for s in student_manager.students:
			if s.quirk == "Biang Onar":
				biang_onar_active = true
				biang_onar_scale = s.biang_onar_positive_event_scale
				break
				
	match event_id:
		0:
			var stat_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := -15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Les Tambahan Akademis 📚",
				"Sekolah membuka kelas Les Bimbingan Intensif setelah jam pelajaran.",
				"Akademis +%d" % int(stat_val),
				"Energy %d" % int(nrg_val),
				"Akademis", stat_val, nrg_val, 0.0
			)
		1:
			var stat_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := 10.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := -20.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Latihan Olahraga Ekstra ⚽",
				"Fasilitas lapangan terbuka gratis untuk sesi latihan bersama.",
				"Olahraga +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"Olahraga", stat_val, nrg_val, mood_val
			)
		2:
			var stat_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := 15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := -10.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Workshop Sanggar Seni 🎨",
				"Terdapat workshop pembuatan kerajinan dan tari daerah setempat.",
				"Seni Budaya +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"SeniBudaya", stat_val, nrg_val, mood_val
			)
		3:
			await _show_event_announcement("🍱 Kejutan Nasi Kotak Orang Tua!")
			var energy_bonus := 20.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_bonus := 25.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				s.apply_event_effects("", 0.0, energy_bonus, mood_bonus)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Nasi Kotak Berbagi", names, "Semua siswa mendapat Energy +%d dan Mood +%d" % [int(energy_bonus), int(mood_bonus)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout
		4:
			await _show_event_announcement("🌧 Hujan Deras & Jalanan Licin!")
			var energy_penalty := -15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_penalty := -15.0 * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				s.apply_event_effects("", 0.0, energy_penalty, mood_penalty)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Kehujanan & Terpeleset", names, "Semua siswa mendapat Energy %d dan Mood %d" % [int(energy_penalty), int(mood_penalty)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout
