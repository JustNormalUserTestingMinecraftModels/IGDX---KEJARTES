extends Control

@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea
@onready var select_student_button = $TextureButton
@onready var name_label = $LabelNama
@onready var start_week_button = $StartWeek

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

# --- Tutorial 3 fase, masing-masing bertahan selama game berjalan ---
static var tutorial_phase1_done := false
static var tutorial_phase3_done := false

var steps := []
var current_step := 0
var tutorial_active := true
var blur_overlay: ColorRect

const BASE_GAIN := 2.0
const HOBBY_BONUS_GAIN := 4.0

const MOOD_LOSS_MIN := 10
const MOOD_LOSS_MAX := 15
const ENERGY_LOSS_MIN := 15
const ENERGY_LOSS_MAX := 20
const DAYOFF_GAIN_MIN := 20
const DAYOFF_GAIN_MAX := 30

var penjadwalan_popup_open := false

func _ready():
	_create_blur_overlay()
	_update_student_display()
	_update_day_button_colors()
	_start_day_button_sway()

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

func _dismiss_tutorial():
	tutorial_phase3_done = true
	tutorial_active = false
	if color_rect:
		color_rect.hide()
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
	steps = [
		{ "node": $ColorRect/Step1, "target": null },
		{ "node": $ColorRect/Step2, "target": select_student_button },
	]
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

func _replace_placeholder_recursive(node: Node, student_name: String):
	for child in node.get_children():
		if child is Label and "Nama Murid" in child.text:
			if not child.has_meta("original_text"):
				child.set_meta("original_text", child.text)
			var original = child.get_meta("original_text")
			child.text = original.replace("Nama Murid", student_name)
		_replace_placeholder_recursive(child, student_name)

func _setup_phase2_tutorial():
	var student = GameState.selected_student
	var step4_node = $ColorRect/Step4_2
	if _has_akademis_below_target(student):
		step4_node = $ColorRect/Step4_1

	_replace_placeholder_recursive(step4_node, student.get("name", "Murid"))

	steps = [
		{ "node": $ColorRect/Step3, "target": [ak1_bar, ak2_bar, ak3_bar] },
		{ "node": step4_node, "target": $TextureButton/BGStat/Akademis1 },
		{ "node": $ColorRect/Step5, "target": $BGHari },
		{ "node": $ColorRect/Step6, "target": $BGHari/Senin },
	]
	_start_tutorial_overlay()

func _setup_phase3_tutorial():
	# GANTI target di bawah ini sesuai node yang benar-benar mau di-highlight
	steps = [
		{ "node": $ColorRect/Step7, "target": null },
		{ "node": $ColorRect/Step8, "target": $BGHari/Senin },
		{ "node": $ColorRect/Step9, "target": [ak1_value_label, ak2_value_label, ak3_value_label, kp1_value_label, kp2_value_label] },
		{ "node": $ColorRect/Step10, "target": null },
	]
	_start_tutorial_overlay()

func _start_tutorial_overlay():
	current_step = 0
	tutorial_active = true
	color_rect.show()

	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", color_rect.size)
		if not color_rect.resized.is_connected(_update_rect_size):
			color_rect.resized.connect(_update_rect_size)

	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	if click_area.has_signal("pressed"):
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
		if schedules.has(day_name):
			var category = schedules[day_name]["category"]
			if category == "Akademik":
				btn.modulate = Color(0.16, 0.27, 1.0, 1.0)
			elif category == "Olahraga":
				btn.modulate = Color(0.6, 0.0, 0.0, 1.0)
			elif category == "SeniBudaya":
				btn.modulate = Color(0.0, 0.6, 0.25, 1.0)
			elif category == "DayOff":
				btn.modulate = Color(0.672, 0.72, 0.0, 1.0)
		else:
			btn.modulate = default_color

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
		total += schedules[day].get(key, 0)
	return total

func _update_student_display():
	print("DEBUG selected_student: ", GameState.selected_student)
	if GameState.selected_student.is_empty():
		if not GameState.approved_students.is_empty():
			GameState.selected_student = GameState.approved_students[0]
		else:
			GameState.selected_student = {
				"id": 0,
				"name": "Hamamiya",
				"splash": "res://Asset/SplashArtMurid/SplashMurid1.jpg",
				"portrait": "res://Asset/MuridPotrait/Murid1.jpg",
				"kepribadian1": 65.0,
				"kepribadian2": 30.0,
				"akademis1": 30.0,
				"akademis2": 50.0,
				"akademis3": 40.0,
				"target_akademis1": 50.0,
				"target_akademis2": 60.0,
				"target_akademis3": 55.0,
				"target_kepribadian1": 50.0,
				"target_kepribadian2": 40.0,
				"hobby_category": ""
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
		kp1_bar.set_current(student.get("kepribadian1", 50.0))
		kp1_bar.set_pending_gain(-_compute_total_loss("mood_cost"))
	if kp2_bar:
		kp2_bar.set_current(student.get("kepribadian2", 50.0))
		kp2_bar.set_pending_gain(-_compute_total_loss("energy_cost"))
	if ak1_bar:
		ak1_bar.set_current(student.get("akademis1", 50.0))
		ak1_bar.set_pending_gain(_compute_pending_gain("Akademik", student))
	if ak2_bar:
		ak2_bar.set_current(student.get("akademis2", 50.0))
		ak2_bar.set_pending_gain(_compute_pending_gain("SeniBudaya", student))
	if ak3_bar:
		ak3_bar.set_current(student.get("akademis3", 50.0))
		ak3_bar.set_pending_gain(_compute_pending_gain("Olahraga", student))

func _on_select_student_pressed():
	print("DEBUG: TOMBOL TERTEKAN!")
	tutorial_phase1_done = true
	tutorial_active = false
	color_rect.hide()
	Transition.change_scene("res://Scene/student_list.tscn")

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

func _on_start_week_pressed():
	print("DEBUG: START WEEK DITEKAN!")
	tutorial_phase3_done = true
	tutorial_active = false
	color_rect.hide()

	if _has_incomplete_schedules():
		_show_peringatan()
		return
	_proceed_start_week()

func _create_blur_overlay():
	blur_overlay = ColorRect.new()
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.color = Color(0, 0, 0, 0)
	var shader = load("res://Script/blur.gdshader")
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
	# Show and animate blur overlay
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
	tween.chain().tween_callback(func(): peringatan.hide(); blur_overlay.visible = false)

func _set_blur_lod(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("lod", value)

func _set_blur_darkness(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("darkness", value)

func _on_peringatan_yes():
	_hide_peringatan()
	_proceed_start_week()

func _on_peringatan_no():
	_hide_peringatan()

func _proceed_start_week():
	print("DEBUG: PROCEEDING START WEEK")
	# TODO: nanti di sini bisa ditambahkan logic apply pending gain jadi stat permanen

# ================= PENJADWALAN POPUP =================

func _connect_activity_buttons():
	if popup_akademik_btn and not popup_akademik_btn.pressed.is_connected(_on_activity_selected.bind("Akademik")):
		popup_akademik_btn.pressed.connect(_on_activity_selected.bind("Akademik"))
	if popup_olahraga_btn and not popup_olahraga_btn.pressed.is_connected(_on_activity_selected.bind("Olahraga")):
		popup_olahraga_btn.pressed.connect(_on_activity_selected.bind("Olahraga"))
	if popup_senibudaya_btn and not popup_senibudaya_btn.pressed.is_connected(_on_activity_selected.bind("SeniBudaya")):
		popup_senibudaya_btn.pressed.connect(_on_activity_selected.bind("SeniBudaya"))
	if popup_dayoff_btn and not popup_dayoff_btn.pressed.is_connected(_on_activity_selected.bind("DayOff")):
		popup_dayoff_btn.pressed.connect(_on_activity_selected.bind("DayOff"))

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
		if category == "DayOff":
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
	if tutorial_active:
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
	if current_step >= steps.size() - 1:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_step()
	elif event is InputEventScreenTouch and event.pressed:
		_next_step()

func _update_rect_size():
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", color_rect.size)

func _next_step():
	current_step += 1
	if current_step >= steps.size():
		tutorial_active = false
		color_rect.hide()
		return
	_show_step(current_step)

func _show_step(index: int):
	for child in color_rect.get_children():
		if child.name.begins_with("Step"):
			child.hide()
	steps[index]["node"].show()

	var target = steps[index]["target"]
	if target == null:
		_clear_highlight()
	elif target is Array:
		_highlight_multiple(target)
	else:
		_highlight(target)

	if index == steps.size() - 1:
		if target and target is BaseButton:
			# Last step highlights a specific button the user must press (e.g. Phase 2 → Senin)
			color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
			click_area.hide()

			if steps[index]["node"] is Control:
				steps[index]["node"].mouse_filter = Control.MOUSE_FILTER_IGNORE

			if click_area is BaseButton:
				click_area.disabled = true

			target.disabled = false
		else:
			# Last step has no specific target → click anywhere to dismiss (e.g. Phase 3)
			color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			click_area.show()
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP
			if click_area is BaseButton:
				click_area.disabled = false
			# Reconnect click_area to dismiss instead of advancing steps
			if click_area.has_signal("pressed"):
				if click_area.pressed.is_connected(_next_step):
					click_area.pressed.disconnect(_next_step)
				if not click_area.pressed.is_connected(_dismiss_tutorial):
					click_area.pressed.connect(_dismiss_tutorial)
	else:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.show()
		if click_area is BaseButton:
			click_area.disabled = false
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP

func _highlight(control: Control, padding: float = 8.0):
	var mat := color_rect.material as ShaderMaterial
	if mat:
		var local_pos = control.global_position - color_rect.global_position - Vector2(padding, padding)
		var size_with_padding = control.size + Vector2(padding, padding) * 2
		mat.set_shader_parameter("hole_pos", local_pos)
		mat.set_shader_parameter("hole_size", size_with_padding)

func _highlight_multiple(controls: Array, padding: float = 8.0):
	if controls.is_empty():
		_clear_highlight()
		return
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		return
	var min_pos: Vector2 = controls[0].global_position
	var max_pos: Vector2 = controls[0].global_position + controls[0].size
	for c in controls:
		if not c:
			continue
		min_pos.x = min(min_pos.x, c.global_position.x)
		min_pos.y = min(min_pos.y, c.global_position.y)
		max_pos.x = max(max_pos.x, c.global_position.x + c.size.x)
		max_pos.y = max(max_pos.y, c.global_position.y + c.size.y)

	var local_pos = min_pos - color_rect.global_position - Vector2(padding, padding)
	var size_with_padding = (max_pos - min_pos) + Vector2(padding, padding) * 2
	mat.set_shader_parameter("hole_pos", local_pos)
	mat.set_shader_parameter("hole_size", size_with_padding)

func _clear_highlight():
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("hole_size", Vector2.ZERO)
