extends Control

signal _holiday_dismissed

@export_group("Calendar Display")
@export var calendar_icon: Texture2D
@export var label_font_color: Color = Color(0.12, 0.22, 0.45)
@export var label_outline_color: Color = Color.WHITE

# National Holidays definition
const HOLIDAYS = {
	3: {
		"Rabu": {
			"title": "Hari Kemerdekaan RI",
			"desc": "Kemerdekaan Republik Indonesia (17 Agustus)"
		}
	},
	6: {
		"Senin": {
			"title": "Maulid Nabi Muhammad SAW",
			"desc": "Kelahiran Nabi Muhammad SAW"
		}
	}
}

@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea
@onready var select_student_button = $TextureButton
@onready var name_label = $LabelNama
@onready var start_week_button = $StartWeek
@onready var calendar_icon_rect = $TanggalContainer/CalendarIcon
@onready var label_tanggal = $TanggalContainer/LabelTanggal
@onready var back_button = $BackButton

var _holiday_active: bool = false

@onready var ak1_bar = $TextureButton/BGStat/Akademis1
@onready var ak2_bar = $TextureButton/BGStat/Akademis2
@onready var ak3_bar = $TextureButton/BGStat/Akademis3
@onready var kp1_bar = $TextureButton/BGStat/Kepribadian1
@onready var kp2_bar = $TextureButton/BGStat/Kepribadian2

@onready var ak1_value_label = $TextureButton/BGStat/Akademis1/ValueLabel
@onready var ak2_value_label = $TextureButton/BGStat/Akademis2/ValueLabel
@onready var ak3_value_label = $TextureButton/BGStat/Akademis3/ValueLabel
@onready var kp1_value_label = $TextureButton/BGStat/Kepribadian1/ValueLabel
@onready var kp2_value_label = $TextureButton/BGStat/Kepribadian2/ValueLabel

@onready var senin_btn = $BGHari/Senin
@onready var selasa_btn = $BGHari/Selasa
@onready var rabu_btn = $BGHari/Rabu
@onready var kamis_btn = $BGHari/Kamis
@onready var jumat_btn = $BGHari/Jumat

@onready var peringatan = $Peringatan
@onready var btn_yes = $Peringatan/TextureRect/ButtonYes
@onready var btn_no = $Peringatan/TextureRect/ButtonNo

# --- Penjadwalan Popup ---
@onready var penjadwalan_popup = $Penjadwalan
@onready var popup_akademik_btn = $Penjadwalan/TextureRect/Akademik
@onready var popup_olahraga_btn = $Penjadwalan/TextureRect/Olahraga
@onready var popup_senibudaya_btn = $Penjadwalan/TextureRect/SeniBudaya
@onready var popup_dayoff_btn = $Penjadwalan/TextureRect/Libur
@onready var popup_akademik_bar = $Penjadwalan/TextureRect/Akademik/ProgressBar
@onready var popup_olahraga_bar = $Penjadwalan/TextureRect/Olahraga/ProgressBar2
@onready var popup_senibudaya_bar = $Penjadwalan/TextureRect/SeniBudaya/ProgressBar3

# --- Tutorial 3 Phase Setup ---
@export_group("Tutorial")
## Phase 1 tutorial steps (Initial entry to schedule scene)
@export var tutorial_phase1_steps: Array[TutorialStepData] = []
## Phase 2 tutorial steps (Returning from student selection)
@export var tutorial_phase2_steps: Array[TutorialStepData] = []
## Phase 2 alternative step for when student needs academic boost
@export var tutorial_phase2_alt_step: TutorialStepData = null
## Phase 3 tutorial steps (After scheduling Monday)
@export var tutorial_phase3_steps: Array[TutorialStepData] = []
## Optional PNG texture for custom tutorial dialogue box background.
@export var custom_panel_texture: Texture2D = null
## Optional custom StyleBox override for the tutorial panel.
@export var custom_panel_stylebox: StyleBox = null

static var tutorial_phase1_done := false
static var tutorial_phase3_done := false
# Tutorial UI variables
const TutorialArrow = preload("res://Scripts/TutorialArrow.gd")
var current_step := 0
var current_phase_steps: Array[TutorialStepData] = []
var tutorial_active := true
var _tutorial_panel: PanelContainer
var _tutorial_title_label: Label
var _tutorial_body_label: Label
var _tutorial_prompt_label: Label
var _blink_tween: Tween
var _tutorial_arrow: Control = null

var blur_overlay: ColorRect

const BASE_GAIN := 3.0       # Must match StudentManager.gd apply_jadwal_activity base_gain
const HOBBY_BONUS_GAIN := 6.0  # Must match base_gain + specialty_bonus (3 + 3 = 6 total for specialty)

const MOOD_LOSS_MIN := 10
const MOOD_LOSS_MAX := 15
const ENERGY_LOSS_MIN := 15
const ENERGY_LOSS_MAX := 20
const DAYOFF_GAIN_MIN := 20
const DAYOFF_GAIN_MAX := 30

var penjadwalan_popup_open := false
var is_overtired_warning := false

func _ready():
	_setup_portrait_juice(select_student_button)
	_setup_back_button()
	_apply_stat_bar_colors()
	_update_tanggal_display()
	_check_and_lock_holidays()
	_create_blur_overlay()
	_update_student_display()
	_update_day_button_colors()
	_start_day_button_sway()

func _setup_back_button():
	if back_button:
		back_button.show()
		_setup_portrait_juice(back_button)
		if not back_button.pressed.is_connected(_on_back_button_pressed):
			back_button.pressed.connect(_on_back_button_pressed)

func _on_back_button_pressed():
	if tutorial_active:
		return
	print("Kembali ke Lobby...")
	Transition.change_scene("res://Scenes/Lobby/loby.tscn")

func _apply_stat_bar_colors():
	var bar_colors = {
		ak1_bar: Color(0.16, 0.27, 1.0, 1.0),      # Blue (Akademik)
		ak2_bar: Color(0.0, 0.6, 0.25, 1.0),       # Green (Seni Budaya)
		ak3_bar: Color(0.85, 0.2, 0.2, 1.0),       # Red (Olahraga)
		kp1_bar: Color(0.0, 0.75, 1.0, 1.0),       # Cyan (Energi)
		kp2_bar: Color(1.0, 0.85, 0.2, 1.0),       # Yellow (Mood)
		popup_akademik_bar: Color(0.16, 0.27, 1.0, 1.0),
		popup_senibudaya_bar: Color(0.0, 0.6, 0.25, 1.0),
		popup_olahraga_bar: Color(0.85, 0.2, 0.2, 1.0)
	}

	for bar in bar_colors.keys():
		if bar and is_instance_valid(bar) and bar is ProgressBar:
			# Dark rounded container background with subtle border
			var bg = StyleBoxFlat.new()
			bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)
			bg.border_width_left = 2
			bg.border_width_top = 2
			bg.border_width_right = 2
			bg.border_width_bottom = 2
			bg.border_color = Color(0.25, 0.25, 0.35, 0.9)
			bg.corner_radius_top_left = 8
			bg.corner_radius_top_right = 8
			bg.corner_radius_bottom_left = 8
			bg.corner_radius_bottom_right = 8
			bar.add_theme_stylebox_override("background", bg)

			# Polished fill stylebox with matching rounded corners
			var fill = StyleBoxFlat.new()
			fill.bg_color = bar_colors[bar]
			fill.corner_radius_top_left = 6
			fill.corner_radius_top_right = 6
			fill.corner_radius_bottom_left = 6
			fill.corner_radius_bottom_right = 6
			bar.add_theme_stylebox_override("fill", fill)

	# --- Setup Penjadwalan Popup ---
	if penjadwalan_popup:
		penjadwalan_popup.hide()
	_connect_activity_buttons()

	_connect_day_button(senin_btn, "Senin")
	_connect_day_button(selasa_btn, "Selasa")
	_connect_day_button(rabu_btn, "Rabu")
	_connect_day_button(kamis_btn, "Kamis")
	_connect_day_button(jumat_btn, "Jumat")

	_connect_start_week_button()

	# Populate default tutorial step resources if empty
	if tutorial_phase1_steps.is_empty() or tutorial_phase2_steps.is_empty() or tutorial_phase3_steps.is_empty():
		_populate_default_tutorial_steps()

	# Setup shader rect_size and resize fitting
	var viewport_size = get_viewport_rect().size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	call_deferred("_fit_color_rect_to_viewport")
	get_tree().root.size_changed.connect(_fit_color_rect_to_viewport)

	_tutorial_arrow = TutorialArrow.new()
	_tutorial_arrow.visible = false
	color_rect.add_child(_tutorial_arrow)

	# Build dynamic tutorial UI panel
	_build_tutorial_panel()

	if tutorial_phase3_done:
		# Semua fase tutorial sudah selesai, tidak muncul lagi
		color_rect.hide()
		tutorial_active = false
		_enable_select_button()
		return

	if not tutorial_phase1_done:
		# Pertama kali buka scene ini
		_setup_phase1_tutorial()
		return

	var schedules = _get_current_schedules()
	if schedules.has("Senin"):
		# Senin sudah dijadwalkan, lanjut ke fase 3
		_setup_phase3_tutorial()
	else:
		# Baru balik dari student_list, belum jadwalkan Senin
		_setup_phase2_tutorial()

func _populate_default_tutorial_steps():
	if tutorial_phase1_steps.is_empty():
		var p1_data = [
			["Penjadwalan Murid", "Disini dimana kalian akan harus menjadwalkan murid mata pelajaran apa yang perlu mereka tingkatkan lebih untuk lolos ujian!", "", ""],
			["Pilih Murid", "Anda memilih \"Nama Murid\" untuk dijadwalkan terlebih dahulu.", "TextureButton", "Tekan kartu murid untuk lanjut!"]
		]
		for entry in p1_data:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase1_steps.append(step)

	if tutorial_phase2_steps.is_empty():
		var p2_data = [
			["Evaluasi Murid", "Murid ini membutuhkan bantuan agar mereka terfokuskan untuk meningkatkan apa yang ketertinggalan.", "TextureButton/BGStat/Akademis1,TextureButton/BGStat/Akademis2,TextureButton/BGStat/Akademis3", ""],
			["Perhatian Akademis", "Wah, sepertinya \"Nama Murid\" mempunyai nilai akademis yang bagus!", "TextureButton/BGStat/Akademis1", ""],
			["Hari Kosong", "Hari berwarnakan Ungu Muda mempunyai arti hari tersebut kosong bagi murid tersebut!", "BGHari/Senin,BGHari/Selasa,BGHari/Rabu,BGHari/Kamis,BGHari/Jumat", ""],
			["Jadwal Hari Senin", "Mari kita jadwalkan hari senin untuk diisikan mata pelajaran yang mereka sedang butuhkan!", "BGHari/Senin", "Tekan tombol 'Senin' untuk lanjut!"]
		]
		for entry in p2_data:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase2_steps.append(step)

	if not tutorial_phase2_alt_step:
		var alt = TutorialStepData.new()
		alt.title = "Perhatian Akademis"
		alt.text = "Wah, sepertinya \"Nama Murid\" perlu nilai akademisnya untuk dinaikan lebih lagi."
		alt.target_node_path = "TextureButton/BGStat/Akademis1"
		alt.prompt_text = ""
		tutorial_phase2_alt_step = alt

	if tutorial_phase3_steps.is_empty():
		var p3_data = [
			["Penjadwalan Berhasil", "Kerja bagus!\n\nSekarang, kita perhatikan 2 unsur yang akan berubah jikalau anda meng-input sebuah hari dengan mata pelajaran.", "", ""],
			["Warna Hari", "Pertama, hari akan berganti warna sesuai dengan warna mata pelajaran.\nBiru: Akademis, Hijau: Seni Budaya, dan Merah: Olahraga", "BGHari/Senin", ""],
			["Perubahan Stats & Energy", "Kedua, stats akan mempunyai nilai plus berdasarkan berapa pelajaran per hari yang mereka ambil!\n\nTapi Mood dan energi mereka akan berkurang!", "TextureButton/BGStat/Akademis1/ValueLabel,TextureButton/BGStat/Akademis2/ValueLabel,TextureButton/BGStat/Akademis3/ValueLabel,TextureButton/BGStat/Kepribadian1/ValueLabel,TextureButton/BGStat/Kepribadian2/ValueLabel", ""],
			["Siap Mengajar!", "Wow, dirimu sangat cepat untuk beradaptasi di lingkungan sekolah ini.\nKamu punya potensi besar untuk sukses mendidik lebih jauh disini!", "", ""]
		]
		for entry in p3_data:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase3_steps.append(step)

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
		tex_style.content_margin_left = 28
		tex_style.content_margin_top = 20
		tex_style.content_margin_right = 28
		tex_style.content_margin_bottom = 16
		style = tex_style
	else:
		var flat = StyleBoxFlat.new()
		flat.bg_color = Color(0.06, 0.06, 0.1, 0.93)
		flat.corner_radius_top_left = 18
		flat.corner_radius_top_right = 18
		flat.corner_radius_bottom_left = 18
		flat.corner_radius_bottom_right = 18
		flat.border_width_left = 2
		flat.border_width_top = 2
		flat.border_width_right = 2
		flat.border_width_bottom = 2
		flat.border_color = Color(1.0, 0.85, 0.3, 0.5)
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
	_tutorial_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_tutorial_title_label.add_theme_constant_override("outline_size", 6)
	_tutorial_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(_tutorial_title_label)

	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.add_theme_font_size_override("font_size", 40)
	_tutorial_body_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
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
	_tutorial_prompt_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
	_tutorial_prompt_label.add_theme_constant_override("outline_size", 5)
	_tutorial_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
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
	if force_center:
		# Position panel near the top (Y = 15% of screen height) so it stays cleanly above day sticky notes
		target_y = viewport_size.y * 0.15
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
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	if tutorial_active and _tutorial_panel and is_instance_valid(_tutorial_panel):
		call_deferred("_position_tutorial_panel")

func _dismiss_tutorial():
	tutorial_phase3_done = true
	_end_tutorial()

func _end_tutorial():
	tutorial_active = false
	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_panel.hide()
	color_rect.hide()
	if back_button:
		back_button.show()
	_enable_select_button()

func _enable_select_button():
	if select_student_button is BaseButton:
		select_student_button.disabled = false
	if select_student_button:
		if not select_student_button.pressed.is_connected(_on_select_student_pressed):
			select_student_button.pressed.connect(_on_select_student_pressed)

func _connect_start_week_button():
	if start_week_button and start_week_button.has_signal("pressed"):
		if not start_week_button.pressed.is_connected(_on_start_week_pressed):
			start_week_button.pressed.connect(_on_start_week_pressed)
	if btn_yes and not btn_yes.pressed.is_connected(_on_peringatan_yes):
		btn_yes.pressed.connect(_on_peringatan_yes)
	if btn_no and not btn_no.pressed.is_connected(_on_peringatan_no):
		btn_no.pressed.connect(_on_peringatan_no)

func _setup_phase1_tutorial():
	current_phase_steps = tutorial_phase1_steps.duplicate()
	_start_tutorial_overlay()
	_enable_select_button()

func _has_akademis_below_target(student: Dictionary) -> bool:
	var pairs = [
		["akademis1", "target_akademis1"],
		["akademis2", "target_akademis2"],
		["akademis3", "target_akademis3"]
	]
	for p in pairs:
		var current = student.get(p[0], 0.0)
		var target = student.get(p[1], 65.0)
		if current < target:
			return true
	return false

func _setup_phase2_tutorial():
	current_phase_steps = tutorial_phase2_steps.duplicate()
	var student = GameState.selected_student
	if _has_akademis_below_target(student) and tutorial_phase2_alt_step and current_phase_steps.size() > 1:
		current_phase_steps[1] = tutorial_phase2_alt_step
	_start_tutorial_overlay()

func _setup_phase3_tutorial():
	current_phase_steps = tutorial_phase3_steps.duplicate()
	_start_tutorial_overlay()

func _start_tutorial_overlay():
	current_step = 0
	tutorial_active = true
	if back_button:
		back_button.show()
	color_rect.show()
	if _tutorial_panel:
		_tutorial_panel.show()

	if click_area.has_signal("pressed"):
		if click_area.pressed.is_connected(_dismiss_tutorial):
			click_area.pressed.disconnect(_dismiss_tutorial)
		if not click_area.pressed.is_connected(_next_step):
			click_area.pressed.connect(_next_step)
	else:
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		if not click_area.gui_input.is_connected(_on_click_area_gui_input):
			click_area.gui_input.connect(_on_click_area_gui_input)
	click_area.disabled = false if click_area is BaseButton else click_area.disabled

	_show_step(0)


func _get_current_schedules() -> Dictionary:
	var student_id = GameState.selected_student.get("id", null)
	if student_id == null:
		return {}
	return GameState.day_schedules.get(student_id, {})

func _update_day_button_colors():
	var schedules = _get_current_schedules()
	var default_color = Color(0.5529412, 0.45490196, 1, 1)  # unscheduled purple
	
	var week = GameState.minggu_ke
	var week_holidays = HOLIDAYS.get(week, {})
	
	var day_buttons = {
		"Senin": senin_btn,
		"Selasa": selasa_btn,
		"Rabu": rabu_btn,
		"Kamis": kamis_btn,
		"Jumat": jumat_btn
	}

	for day_name in day_buttons.keys():
		var btn = day_buttons[day_name]
		if not btn:
			continue
			
		var label = btn.get_child(0) as Label
		
		if week_holidays.has(day_name):
			# Soft warning red for Libur Nasional
			btn.modulate = Color(1.0, 0.35, 0.35, 1.0)
			if label:
				label.text = day_name.to_upper() + "\n(LIBUR)"
		elif schedules.has(day_name):
			var category = schedules[day_name]["category"]
			if category == "Akademis":
				btn.modulate = Color(0.16, 0.27, 1.0, 1.0)
			elif category == "Olahraga":
				btn.modulate = Color(0.6, 0.0, 0.0, 1.0)
			elif category == "SeniBudaya":
				btn.modulate = Color(0.0, 0.6, 0.25, 1.0)
			elif category == "Istirahat":
				btn.modulate = Color(0.672, 0.72, 0.0, 1.0)
			if label:
				label.text = day_name.to_upper()
		else:
			btn.modulate = default_color
			if label:
				label.text = day_name.to_upper()

func _start_day_button_sway():
	var buttons = [senin_btn, selasa_btn, rabu_btn, kamis_btn, jumat_btn]
	for i in range(buttons.size()):
		var btn = buttons[i]
		if not btn:
			continue
		btn.pivot_offset = btn.size / 2.0
		var duration = 1.8 + i * 0.25  # stagger durations for organic feel
		var angle = deg_to_rad(3.0 + i * 0.5)  # slightly different sway range
		# Start with a small random offset so they don't all begin in sync
		btn.rotation = deg_to_rad(randf_range(-1.5, 1.5))
		var tween = create_tween().set_loops()
		tween.tween_property(btn, "rotation", angle, duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(btn, "rotation", -angle, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(btn, "rotation", 0.0, duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _compute_pending_gain(category: String, student: Dictionary) -> float:
	var schedules = _get_current_schedules()
	var count := 0
	for day in schedules.keys():
		if schedules[day]["category"] == category:
			count += 1
	var increment = HOBBY_BONUS_GAIN if student.get("hobby_category", "") == category else BASE_GAIN
	return count * increment

func _compute_total_loss(key: String) -> float:
	var schedules = _get_current_schedules()
	var total := 0.0
	for day in schedules.keys():
		total += schedules[day].get(key, 0.0)
	return total

func _get_overtired_students() -> Array[String]:
	var overtired: Array[String] = []
	for student in GameState.approved_students:
		var student_id = student.get("id", null)
		if student_id == null:
			continue
		var initial_energy = student.get("kepribadian2", 50.0)
		var schedules = GameState.day_schedules.get(student_id, {})
		var total_cost := 0.0
		for day in schedules.keys():
			total_cost += schedules[day].get("energy_cost", 0.0)

		var final_energy = initial_energy - total_cost
		if final_energy <= 0.0:
			overtired.append(student.get("name", "Murid"))
	return overtired

func _update_student_display():
	print("DEBUG selected_student: ", GameState.selected_student)
	if GameState.selected_student.is_empty():
		if not GameState.approved_students.is_empty():
			GameState.selected_student = GameState.approved_students[0]
		else:
			GameState.selected_student = {
					"id": 1,
					"name": "Marcel",
					"splash": "res://Assets/Images/SplashArtMurid/SplashMurid1.jpg",
					"portrait": "res://Assets/Images/MuridPotrait/Marcel.png",
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
					"hobby_category": "Akademis"
				}

	var student = GameState.selected_student

	if name_label:
		name_label.text = student.get("name", "Murid")

	var splash_path = student.get("splash", "")
	if splash_path != "" and ResourceLoader.exists(splash_path):
		select_student_button.texture_normal = load(splash_path)
	else:
		var portrait_path = student.get("portrait", "")
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			select_student_button.texture_normal = load(portrait_path)

	if kp1_bar:
		kp1_bar.set_stat(student.get("kepribadian2", 50.0), 100.0)
		kp1_bar.set_pending_gain(-_compute_total_loss("energy_cost"))
	if kp2_bar:
		kp2_bar.set_stat(student.get("kepribadian1", 50.0), 100.0)
		kp2_bar.set_pending_gain(-_compute_total_loss("mood_cost"))
	if ak1_bar:
		var target = student.get("target_akademis1", 65.0)
		ak1_bar.set_stat(student.get("akademis1", 50.0), target)
		ak1_bar.set_pending_gain(_compute_pending_gain("Akademis", student))
	if ak2_bar:
		var target = student.get("target_akademis2", 65.0)
		ak2_bar.set_stat(student.get("akademis2", 50.0), target)
		ak2_bar.set_pending_gain(_compute_pending_gain("SeniBudaya", student))
	if ak3_bar:
		var target = student.get("target_akademis3", 65.0)
		ak3_bar.set_stat(student.get("akademis3", 50.0), target)
		ak3_bar.set_pending_gain(_compute_pending_gain("Olahraga", student))

	_update_day_button_colors()

func _setup_portrait_juice(btn: Control):
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	if not btn.mouse_entered.is_connected(_on_portrait_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_portrait_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_portrait_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_portrait_mouse_exited.bind(btn))

func _on_portrait_mouse_entered(btn: Control):
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.15)
	tw.tween_property(btn, "modulate", Color(1.2, 1.2, 1.08, 1.0), 0.15)

func _on_portrait_mouse_exited(btn: Control):
	if not is_instance_valid(btn):
		return
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

func _animate_button_click_bounce(btn: Control):
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(0.82, 1.22), 0.08)
	tw.tween_property(btn, "scale", Vector2(1.15, 0.88), 0.1)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)

func _on_select_student_pressed():
	print("DEBUG: TOMBOL TERTEKAN!")
	if select_student_button:
		_animate_button_click_bounce(select_student_button)

	if tutorial_active:
		var current_step_data = current_phase_steps[current_step] if current_step < current_phase_steps.size() else null
		if current_step_data:
			if current_step_data.target_node_path == "" or not ("TextureButton" in current_step_data.target_node_path):
				print("Tutorial active: ignoring student card press on step ", current_step)
				return
		tutorial_phase1_done = true
		tutorial_active = false
		color_rect.hide()
	Transition.change_scene("res://Scenes/StudentList/student_list.tscn")

func _has_incomplete_schedules() -> bool:
	var students = GameState.approved_students
	if students.is_empty():
		return false
	var days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
	for student in students:
		var student_id = student.get("id", null)
		if student_id == null:
			return true
		var schedules = GameState.day_schedules.get(student_id, {})
		for day in days:
			if not schedules.has(day):
				return true
	return false

var current_warning_mode := ""

func _on_start_week_pressed():
	print("DEBUG: START WEEK DITEKAN!")
	if tutorial_active:
		print("Tutorial active: ignoring start week button press")
		return

	# 1. Safety check: prevent start if any student runs out of energy (predicted <= 0)
	var overtired = _get_overtired_students()
	if not overtired.is_empty():
		_show_overtired_warning(overtired)
		return

	var mentally_tired = _get_mentally_tired_students()
	var has_incomplete = _has_incomplete_schedules()

	# 2. Both Mental Fatigue AND Incomplete Schedule
	if not mentally_tired.is_empty() and has_incomplete:
		_show_combined_warning(mentally_tired)
		return

	# 3. Mental Fatigue only
	if not mentally_tired.is_empty():
		_show_mental_fatigue_warning(mentally_tired)
		return

	# 4. Incomplete Schedule only
	if has_incomplete:
		_show_incomplete_schedule_warning()
		return

	# 5. Everything optimal
	_proceed_start_week()

func _get_mentally_tired_students() -> Array[String]:
	var mentally_tired: Array[String] = []
	for student in GameState.approved_students:
		var student_id = student.get("id", null)
		if student_id == null:
			continue
		var initial_mood = student.get("kepribadian1", 50.0)
		var schedules = GameState.day_schedules.get(student_id, {})
		var total_cost := 0.0
		for day in schedules.keys():
			total_cost += schedules[day].get("mood_cost", 0.0)
		var final_mood = initial_mood - total_cost
		if final_mood <= 0.0:
			mentally_tired.append(student.get("name", "Murid"))
	return mentally_tired

var _last_overtired_student_name: String = ""

func _show_overtired_warning(names: Array[String]):
	current_warning_mode = "energy"
	is_overtired_warning = true
	var name_list = ", ".join(names)
	if not names.is_empty():
		_last_overtired_student_name = names[0]
	$Peringatan/TextureRect/Label.text = "PERINGATAN\n\nMurid berikut kehabisan energi:\n" + name_list + "\n\nHarap pilih murid tersebut & jadwalkan Istirahat (Libur)!"
	btn_yes.text = "OK"
	btn_no.hide()
	_show_peringatan()

func _show_combined_warning(names: Array[String]):
	current_warning_mode = "combined"
	is_overtired_warning = false
	var name_list = ", ".join(names)
	if not names.is_empty():
		_last_overtired_student_name = names[0]
	$Peringatan/TextureRect/Label.text = "PERINGATAN MOOD & JADWAL\n\nMurid \"" + name_list + "\" kehabisan MOOD (Terlalu lelah secara mental) dan masih terdapat jadwal yang belum diisi! Teruskan?"
	btn_yes.text = "YES"
	btn_no.text = "NO"
	btn_no.show()
	_show_peringatan()

func _show_mental_fatigue_warning(names: Array[String]):
	current_warning_mode = "mental"
	is_overtired_warning = false
	var name_list = ", ".join(names)
	if not names.is_empty():
		_last_overtired_student_name = names[0]
	$Peringatan/TextureRect/Label.text = "PERINGATAN MOOD SANGAT RENDAH\n\nMurid \"" + name_list + "\" kehabisan MOOD (Terlalu lelah secara mental)!\n\nPelajaran yang didapat akan berkurang jika mood habis. Teruskan minggu ini?"
	btn_yes.text = "YES"
	btn_no.text = "NO"
	btn_no.show()
	_show_peringatan()

func _show_incomplete_schedule_warning():
	current_warning_mode = "incomplete"
	is_overtired_warning = false
	$Peringatan/TextureRect/Label.text = "PERINGATAN JADWAL\n\nTerdapat murid yang masih \nbelum memiliki jadwal belajar \noptimal!! Teruskan?"
	btn_yes.text = "YES"
	btn_no.text = "NO"
	btn_no.show()
	_show_peringatan()

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
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blur_overlay)
	move_child(blur_overlay, peringatan.get_index())
	blur_overlay.gui_input.connect(_on_blur_overlay_input)

func _show_peringatan():
	if not peringatan:
		return
	var warning_label: Label = $Peringatan/TextureRect/Label
	if warning_label:
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var text_len = warning_label.text.length()
		if text_len > 110:
			warning_label.add_theme_font_size_override("font_size", 28)
		elif text_len > 75:
			warning_label.add_theme_font_size_override("font_size", 32)
		else:
			warning_label.add_theme_font_size_override("font_size", 40)

	blur_overlay.visible = true
	var blur_mat = blur_overlay.material as ShaderMaterial
	blur_mat.set_shader_parameter("lod", 0.0)
	blur_mat.set_shader_parameter("darkness", 0.0)

	peringatan.show()
	peringatan.modulate = Color(1, 1, 1, 0)
	peringatan.scale = Vector2(0.8, 0.8)
	peringatan.pivot_offset = peringatan.size / 2.0

	var tween = create_tween().set_parallel(true)
	tween.tween_property(peringatan, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(peringatan, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_method(_set_blur_lod, 0.0, 3.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_blur_darkness, 0.0, 0.3, 0.25).set_ease(Tween.EASE_OUT)

func _hide_peringatan():
	if not peringatan:
		return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(peringatan, "modulate", Color(1, 1, 1, 0), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(peringatan, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_lod, 3.0, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_darkness, 0.3, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		peringatan.hide()
		blur_overlay.visible = false
		is_overtired_warning = false
	)

func _set_blur_lod(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("lod", value)

func _set_blur_darkness(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("darkness", value)

func _switch_to_flagged_student():
	if _last_overtired_student_name != "":
		for student in GameState.approved_students:
			if student.get("name", "") == _last_overtired_student_name:
				GameState.selected_student = student
				_update_student_display()
				break

func _on_peringatan_yes():
	_hide_peringatan()
	if current_warning_mode == "energy":
		_switch_to_flagged_student()
		return
	elif current_warning_mode == "mental" or current_warning_mode == "combined":
		_proceed_start_week()
	elif current_warning_mode == "incomplete":
		_proceed_start_week()

func _on_peringatan_no():
	_hide_peringatan()
	_switch_to_flagged_student()

func _proceed_start_week():
	print("DEBUG: PROCEEDING START WEEK")
	Transition.change_scene("res://Scenes/SchoolSimulation/SchoolDay.tscn")

# ================= PENJADWALAN POPUP =================

func _connect_activity_buttons():
	if popup_akademik_btn and not popup_akademik_btn.pressed.is_connected(_on_activity_selected.bind("Akademis")):
		popup_akademik_btn.pressed.connect(_on_activity_selected.bind("Akademis"))
	if popup_olahraga_btn and not popup_olahraga_btn.pressed.is_connected(_on_activity_selected.bind("Olahraga")):
		popup_olahraga_btn.pressed.connect(_on_activity_selected.bind("Olahraga"))
	if popup_senibudaya_btn and not popup_senibudaya_btn.pressed.is_connected(_on_activity_selected.bind("SeniBudaya")):
		popup_senibudaya_btn.pressed.connect(_on_activity_selected.bind("SeniBudaya"))
	if popup_dayoff_btn and not popup_dayoff_btn.pressed.is_connected(_on_activity_selected.bind("Istirahat")):
		popup_dayoff_btn.pressed.connect(_on_activity_selected.bind("Istirahat"))

func _show_penjadwalan_popup():
	if not penjadwalan_popup:
		return
	penjadwalan_popup_open = true
	_update_popup_stats()

	# Show and animate blur overlay
	blur_overlay.visible = true
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var blur_mat = blur_overlay.material as ShaderMaterial
	blur_mat.set_shader_parameter("lod", 0.0)
	blur_mat.set_shader_parameter("darkness", 0.0)

	# Show and animate popup
	penjadwalan_popup.show()
	penjadwalan_popup.modulate = Color(1, 1, 1, 0)
	penjadwalan_popup.scale = Vector2(0.8, 0.8)
	penjadwalan_popup.pivot_offset = penjadwalan_popup.size / 2.0

	var tween = create_tween().set_parallel(true)
	tween.tween_property(penjadwalan_popup, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(penjadwalan_popup, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_method(_set_blur_lod, 0.0, 3.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_blur_darkness, 0.0, 0.3, 0.25).set_ease(Tween.EASE_OUT)

func _hide_penjadwalan_popup():
	if not penjadwalan_popup:
		return
	penjadwalan_popup_open = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(penjadwalan_popup, "modulate", Color(1, 1, 1, 0), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(penjadwalan_popup, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_lod, 3.0, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_darkness, 0.3, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		penjadwalan_popup.hide()
		blur_overlay.visible = false
		blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)

func _on_activity_selected(category: String):
	var student = GameState.selected_student
	var student_id = student.get("id", null)
	if GameState.selected_day != "" and student_id != null:
		if not GameState.day_schedules.has(student_id):
			GameState.day_schedules[student_id] = {}
		var mood_cost: int
		var energy_cost: int
		if category == "Istirahat":
			mood_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
			energy_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
		else:
			mood_cost = randi_range(MOOD_LOSS_MIN, MOOD_LOSS_MAX)
			energy_cost = randi_range(ENERGY_LOSS_MIN, ENERGY_LOSS_MAX)
		GameState.day_schedules[student_id][GameState.selected_day] = {
			"category": category,
			"mood_cost": mood_cost,
			"energy_cost": energy_cost
		}
	_hide_penjadwalan_popup()
	_update_day_button_colors()
	_update_student_display()

	# Check if Phase 3 tutorial should start
	if not tutorial_phase3_done and tutorial_phase1_done:
		var schedules = _get_current_schedules()
		if schedules.has("Senin"):
			_setup_phase3_tutorial()

func _on_blur_overlay_input(event: InputEvent):
	if not penjadwalan_popup_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_penjadwalan_popup()
	elif event is InputEventScreenTouch and event.pressed:
		_hide_penjadwalan_popup()

func _update_popup_stats():
	var student = GameState.selected_student
	if student.is_empty():
		return
	if popup_akademik_bar:
		popup_akademik_bar.set_current(student.get("akademis1", 50.0))
		popup_akademik_bar.set_goal(student.get("target_akademis1", 0.0))
	if popup_senibudaya_bar:
		popup_senibudaya_bar.set_current(student.get("akademis2", 50.0))
		popup_senibudaya_bar.set_goal(student.get("target_akademis2", 0.0))
	if popup_olahraga_bar:
		popup_olahraga_bar.set_current(student.get("akademis3", 50.0))
		popup_olahraga_bar.set_goal(student.get("target_akademis3", 0.0))

func _get_day_button(day_name: String) -> Control:
	match day_name:
		"Senin": return senin_btn
		"Selasa": return selasa_btn
		"Rabu": return rabu_btn
		"Kamis": return kamis_btn
		"Jumat": return jumat_btn
	return null

func _animate_day_button_press(btn: Control):
	btn.pivot_offset = btn.size / 2.0

	var tween = create_tween()
	# Squish down — like pressing a jelly button!
	tween.tween_property(btn, "scale", Vector2(1.1, 0.75), 0.08).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Stretch up — bouncy!
	tween.tween_property(btn, "scale", Vector2(0.85, 1.2), 0.10).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Overshoot wide
	tween.tween_property(btn, "scale", Vector2(1.1, 0.95), 0.08).set_ease(Tween.EASE_IN_OUT)
	# Settle to normal with elastic bounce
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Show popup after animation completes
	tween.tween_callback(_show_penjadwalan_popup)

func _connect_day_button(btn, day_name: String):
	if btn and btn.has_signal("pressed"):
		if not btn.pressed.is_connected(_on_day_pressed.bind(day_name)):
			btn.pressed.connect(_on_day_pressed.bind(day_name))

func _on_day_pressed(day_name: String):
	var week = GameState.minggu_ke
	var week_holidays = HOLIDAYS.get(week, {})
	if week_holidays.has(day_name):
		_show_holiday_warning(week_holidays[day_name]["desc"])
		return

	if tutorial_active:
		var current_step_data = current_phase_steps[current_step] if current_step < current_phase_steps.size() else null
		if current_step_data:
			var target_path = current_step_data.target_node_path
			if "Senin" in target_path or "Selasa" in target_path or "Rabu" in target_path or "Kamis" in target_path or "Jumat" in target_path:
				if not target_path.ends_with(day_name):
					print("Tutorial active: expected target ", target_path, " but clicked ", day_name)
					return
			elif target_path != "" and not ("BGHari" in target_path):
				print("Tutorial active: step targets non-day element, ignoring day click")
				return
		tutorial_active = false
		color_rect.hide()

	GameState.selected_day = day_name
	var btn = _get_day_button(day_name)
	if btn:
		_animate_day_button_press(btn)
	else:
		_show_penjadwalan_popup()

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
		if not tutorial_phase1_done:
			tutorial_phase1_done = true
			_end_tutorial()
		elif not tutorial_phase3_done:
			var schedules = _get_current_schedules()
			if schedules.has("Senin"):
				tutorial_phase3_done = true
				_end_tutorial()
			else:
				_end_tutorial()
		else:
			_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int):
	if index < 0 or index >= current_phase_steps.size():
		return
	var step = current_phase_steps[index]

	# Disable click detection during bouncy transition
	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Transition Out: bouncy fade-out scale down
	if _tutorial_panel and _tutorial_panel.modulate.a > 0.1:
		var tween_out = create_tween().set_parallel(true)
		tween_out.tween_property(_tutorial_panel, "scale", Vector2(0.8, 0.8), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween_out.tween_property(_tutorial_panel, "modulate:a", 0.0, 0.15)
		await tween_out.finished

	# Update text contents
	_tutorial_title_label.text = "(%d/%d) %s" % [index + 1, current_phase_steps.size(), step.title]
	var student = GameState.selected_student
	var student_name = student.get("name", "Murid") if not student.is_empty() else "Murid"
	_tutorial_body_label.text = step.text.replace("Nama Murid", student_name)

	# Handle spotlight highlight
	var targets: Array[Control] = []
	if step.target_node_path != "":
		var paths = step.target_node_path.split(",")
		for p in paths:
			var trimmed = p.strip_edges()
			if trimmed == "BGHari":
				var bg_hari_node = get_node_or_null("BGHari")
				if bg_hari_node:
					for child in bg_hari_node.get_children():
						if child is Control and child.visible:
							targets.append(child)
			elif trimmed != "":
				var target = get_node_or_null(trimmed)
				if target and target is Control:
					targets.append(target)
		if not targets.is_empty():
			var arrow_at_bottom = (step.title == "Pilih Murid")
			_highlight_multiple(targets, 12.0, arrow_at_bottom)
		else:
			_clear_highlight()
	else:
		_clear_highlight()

	# Determine if step requires specific button interaction (only when prompt_text is explicitly set or when target is an actual action button)
	var is_button_target = (step.target_node_path == "TextureButton" or step.target_node_path == "BGHari/Senin")
	var requires_button_press = (step.prompt_text != "") or (is_button_target and index == current_phase_steps.size() - 1)

	# Dynamic Prompt Text
	if step.prompt_text != "":
		_tutorial_prompt_label.text = step.prompt_text.replace("Nama Murid", student_name)
	elif requires_button_press and not targets.is_empty():
		var btn_name = _get_button_display_name(targets[0])
		_tutorial_prompt_label.text = "TEKAN TOMBOL '%s' UNTUK LANJUT!" % btn_name.to_upper()
	else:
		_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"

	# Reposition panel (center vertically for 'Hari Kosong' step 3/4)
	var should_center = (step.title == "Hari Kosong" or "BGHari/Senin,BGHari/Selasa" in step.target_node_path)
	_position_tutorial_panel(should_center)
	_tutorial_panel.pivot_offset = _tutorial_panel.size / 2.0

	# Transition In: cute bouncy scale-up pop-in
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(_tutorial_panel, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.2)

	await tween_in.finished

	# Configure input filters for step completion
	if requires_button_press:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _highlight_multiple(controls: Array, padding: float = 12.0, arrow_at_bottom: bool = false):
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
		_tutorial_arrow.set_direction(arrow_at_bottom)
		var arrow_y = local_pos.y + size_with_padding.y + 35.0 if arrow_at_bottom else local_pos.y - 35.0
		var arrow_pos = Vector2(local_pos.x + size_with_padding.x / 2.0, arrow_y)
		var viewport_size = get_viewport_rect().size
		var W = 320.0
		var H = 320.0
		var margin = 20.0
		arrow_pos.x = clamp(arrow_pos.x, W/2.0 + margin, viewport_size.x - W/2.0 - margin)
		if arrow_at_bottom:
			arrow_pos.y = clamp(arrow_pos.y, margin, viewport_size.y - H - margin)
		else:
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

# ── Calendar & Holiday Helper Functions ────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _holiday_active:
		var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		var is_touch = (event is InputEventScreenTouch and event.pressed)
		var is_key = (event is InputEventKey and event.pressed and event.keycode != KEY_O)
		
		if is_click or is_touch or is_key:
			_holiday_dismissed.emit()
			get_viewport().set_input_as_handled()

func _update_tanggal_display() -> void:
	if calendar_icon_rect and calendar_icon:
		calendar_icon_rect.texture = calendar_icon
	
	if label_tanggal:
		var week = GameState.minggu_ke
		var months = ["Agustus", "September", "Oktober", "November", "Desember"]
		var month_idx = clampi((week - 1) / 4, 0, months.size() - 1)
		var month_str = months[month_idx]
		
		var week_in_month = ((week - 1) % 4) + 1
		var week_word = "Pertama"
		match week_in_month:
			1: week_word = "Pertama"
			2: week_word = "Kedua"
			3: week_word = "Ketiga"
			4: week_word = "Keempat"
				
		label_tanggal.text = "%s — Minggu %s" % [month_str, week_word]
		label_tanggal.add_theme_color_override("font_color", label_font_color)
		label_tanggal.add_theme_color_override("font_outline_color", label_outline_color)

func _check_and_lock_holidays() -> void:
	var week = GameState.minggu_ke
	if HOLIDAYS.has(week):
		var week_holidays = HOLIDAYS[week]
		for day_name in week_holidays.keys():
			# Lock schedule to Istirahat / DayOff for all approved students on this holiday
			for student in GameState.approved_students:
				var student_id = student.get("id", null)
				if student_id != null:
					if not GameState.day_schedules.has(student_id):
						GameState.day_schedules[student_id] = {}
					
					# Assign Istirahat with standard mood/energy gain cost delta
					var mood_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
					var energy_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
					GameState.day_schedules[student_id][day_name] = {
						"category": "Istirahat",
						"mood_cost": mood_cost,
						"energy_cost": energy_cost
					}

func _show_holiday_warning(holiday_title: String) -> void:
	_holiday_active = true
	
	# Dimmer overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	add_child(overlay)
	
	# PanelContainer setup
	var panel = PanelContainer.new()
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
	panel.add_theme_stylebox_override("panel", style)
	
	var viewport_size = get_viewport_rect().size
	var panel_width = min(viewport_size.x * 0.85, 800)
	panel.custom_minimum_size = Vector2(panel_width, 0)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Title Label
	var title_lbl = Label.new()
	title_lbl.text = "Hari Libur Nasional 📅"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_lbl.add_theme_constant_override("outline_size", 6)
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title_lbl)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Body Label
	var body_lbl = Label.new()
	body_lbl.text = "Ini merupakan hari libur nasional untuk memperingati '%s'.\n\nMaka murid tidak dapat dijadwalkan!" % holiday_title
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 26)
	body_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	body_lbl.add_theme_constant_override("line_spacing", 8)
	body_lbl.custom_minimum_size = Vector2(panel_width - 100, 0)
	vbox.add_child(body_lbl)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Prompt Label
	var prompt_lbl = Label.new()
	prompt_lbl.text = "KLIK DIMANA SAJA UNTUK LANJUT"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 22)
	prompt_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
	prompt_lbl.add_theme_constant_override("outline_size", 5)
	prompt_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(prompt_lbl)
	
	overlay.add_child(panel)
	
	# Pulsing prompt tween
	prompt_lbl.modulate.a = 1.0
	var pulse = create_tween().set_loops()
	pulse.tween_property(prompt_lbl, "modulate:a", 0.25, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(prompt_lbl, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Centering
	await get_tree().process_frame
	var panel_size = panel.size
	panel.position = (viewport_size - panel_size) / 2.0
	panel.pivot_offset = panel_size / 2.0
	
	# Bounce scale-in
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(panel, "modulate:a", 1.0, 0.25)
	await tween_in.finished
	
	# Wait for click
	await _holiday_dismissed
	
	# Bounce scale-out
	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween_out.tween_property(panel, "modulate:a", 0.0, 0.2)
	await tween_out.finished
	
	pulse.kill()
	overlay.queue_free()
	_holiday_active = false
