extends Control

# --- Tutorial ---
@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea

var steps := []
var current_step := 0
var tutorial_active := true

# --- Paginasi Kertas Murid ---
@onready var kertas_murid: Array = [$KertasMurid1, $KertasMurid2, $KertasMurid3, $KertasMurid4, $KertasMurid5, $KertasMurid6]
@onready var next_kanan: BaseButton = $NextButtonKanan
@onready var next_kiri: BaseButton = $NextButtonKiri
@onready var stamp: TextureRect = $StampApprove
@onready var page_label: Label = $PageLabel
@onready var belajar_button: BaseButton = $KertasMurid6/BelajarButton

var current_page := 0
var approved := []
var is_animating := false

# --- Limit Approve ---
const MAX_APPROVE := 4
var approved_count := 0

# --- Geser Approve/Batal di halaman terakhir ---
var last_page_approve_original_pos: Vector2
var last_page_batal_original_pos: Vector2
var approve_shifted := false

func _ready():
	# ---------- Setup Tutorial ----------
	steps = [
		{ "node": $ColorRect/Step1, "target": null },
		{ "node": $ColorRect/Step2, "target": $KertasMurid1/Kepribadian1 },
		{ "node": $ColorRect/Step3, "target": $KertasMurid1/Kepribadian2 },
		{ "node": $ColorRect/Step4, "target": null },
		{ "node": $ColorRect/Step5, "target": $KertasMurid1/Akademis1 },
		{ "node": $ColorRect/Step6, "target": $KertasMurid1/Akademis2 },
		{ "node": $ColorRect/Step7, "target": $KertasMurid1/Akademis3 },
		{ "node": $ColorRect/Step8, "target": null },
		{ "node": $ColorRect/Step9, "target": null },
		{ "node": $ColorRect/Step10, "target": $KertasMurid1/Aprove },
	]

	# Set shader rect_size immediately so overlay renders correctly from the first frame
	var viewport_size = get_viewport_rect().size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	# Defer positioning until global_position is resolved after layout
	call_deferred("_fit_color_rect_to_viewport")
	get_tree().root.size_changed.connect(_fit_color_rect_to_viewport)

	if click_area.has_signal("pressed"):
		click_area.pressed.connect(_next_step)
	else:
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.gui_input.connect(_on_click_area_gui_input)

	# ---------- Setup Paginasi & Stamp ----------
	approved.resize(kertas_murid.size())
	for i in approved.size():
		approved[i] = false

	stamp.visible = false

	next_kanan.pressed.connect(_on_next_kanan_pressed)
	next_kiri.pressed.connect(_on_next_kiri_pressed)

	for i in kertas_murid.size():
		var approve_btn = kertas_murid[i].get_node_or_null("Aprove")
		if approve_btn:
			if not approve_btn.pressed.is_connected(_on_approve_pressed.bind(i)):
				approve_btn.pressed.connect(_on_approve_pressed.bind(i))

		var batal_btn = kertas_murid[i].get_node_or_null("Batal")
		if batal_btn:
			if not batal_btn.pressed.is_connected(_on_batal_pressed.bind(i)):
				batal_btn.pressed.connect(_on_batal_pressed.bind(i))
			batal_btn.visible = false

	next_kanan.visible = false
	next_kiri.visible = false

	for k in kertas_murid:
		k.set_meta("original_position", k.position)

	# ---------- Setup Tombol Belajar ----------
	belajar_button.pressed.connect(_on_belajar_pressed)
	belajar_button.visible = false

	var last_kertas = kertas_murid[kertas_murid.size() - 1]
	var last_approve_btn = last_kertas.get_node_or_null("Aprove")
	if last_approve_btn:
		last_page_approve_original_pos = last_approve_btn.position
	var last_batal_btn = last_kertas.get_node_or_null("Batal")
	if last_batal_btn:
		last_page_batal_original_pos = last_batal_btn.position

	_sync_student_data_from_ui()
	_show_step(0)

# ================= TUTORIAL =================

func _on_click_area_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_step()
	elif event is InputEventScreenTouch and event.pressed:
		_next_step()

func _fit_color_rect_to_viewport():
	var viewport_size = get_viewport_rect().size
	# Remove anchor-based layout so we can position freely
	color_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	color_rect.position = -global_position
	color_rect.size = viewport_size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)

func _next_step():
	current_step += 1
	if current_step >= steps.size():
		_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int):
	for s in steps:
		s["node"].hide()
	steps[index]["node"].show()

	var target = steps[index]["target"]
	if target != null:
		_highlight(target)
	else:
		_clear_highlight()

func _highlight(control: Control, padding: float = 8.0):
	var mat := color_rect.material as ShaderMaterial
	var local_pos = control.global_position - color_rect.global_position - Vector2(padding, padding)
	var size_with_padding = control.size + Vector2(padding, padding) * 2
	mat.set_shader_parameter("hole_pos", local_pos)
	mat.set_shader_parameter("hole_size", size_with_padding)

func _clear_highlight():
	var mat := color_rect.material as ShaderMaterial
	mat.set_shader_parameter("hole_size", Vector2.ZERO)

func _end_tutorial():
	tutorial_active = false
	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.hide()
	_show_page(current_page)

# ================= PAGINASI =================

func _on_next_kanan_pressed():
	if tutorial_active or is_animating:
		return
	if current_page < kertas_murid.size() - 1:
		var old_page = current_page
		current_page += 1
		_transition_page(old_page, current_page, -1)

func _on_next_kiri_pressed():
	if tutorial_active or is_animating:
		return
	if current_page > 0:
		var old_page = current_page
		current_page -= 1
		_transition_page(old_page, current_page, 1)

func _transition_page(old_index: int, new_index: int, direction: int):
	is_animating = true
	next_kanan.disabled = true
	next_kiri.disabled = true

	var old_kertas = kertas_murid[old_index]
	var new_kertas = kertas_murid[new_index]

	stamp.visible = false

	var screen_width = get_viewport_rect().size.x
	var throw_distance = screen_width * direction

	var tween_out = create_tween()
	tween_out.set_trans(Tween.TRANS_CUBIC)
	tween_out.set_ease(Tween.EASE_IN)
	tween_out.tween_property(old_kertas, "position:x", old_kertas.position.x + throw_distance, 0.35)
	tween_out.parallel().tween_property(old_kertas, "rotation_degrees", 15 * direction, 0.35)
	tween_out.parallel().tween_property(old_kertas, "modulate:a", 0.0, 0.35)

	await tween_out.finished

	old_kertas.hide()
	old_kertas.position = old_kertas.get_meta("original_position")
	old_kertas.rotation_degrees = 0
	old_kertas.modulate.a = 1.0

	new_kertas.show()
	var original_pos = new_kertas.get_meta("original_position")
	new_kertas.position = original_pos - Vector2(throw_distance, 0)
	new_kertas.rotation_degrees = -15 * direction
	new_kertas.modulate.a = 0.0

	var tween_in = create_tween()
	tween_in.set_trans(Tween.TRANS_CUBIC)
	tween_in.set_ease(Tween.EASE_OUT)
	tween_in.tween_property(new_kertas, "position", original_pos, 0.35)
	tween_in.parallel().tween_property(new_kertas, "rotation_degrees", 0, 0.35)
	tween_in.parallel().tween_property(new_kertas, "modulate:a", 1.0, 0.35)

	await tween_in.finished

	_update_nav_buttons(new_index)
	_show_stamp_if_approved(new_index)
	_update_page_label(new_index)

	is_animating = false
	next_kanan.disabled = false
	next_kiri.disabled = false

func _update_nav_buttons(index: int):
	if not tutorial_active:
		next_kiri.visible = index > 0
		next_kanan.visible = index < kertas_murid.size() - 1

		var is_last_page = index == kertas_murid.size() - 1
		var limit_reached = approved_count >= MAX_APPROVE

		belajar_button.visible = is_last_page and limit_reached

		if belajar_button.visible:
			_shift_approve_for_belajar()
		else:
			_reset_approve_position()

func _update_page_label(index: int):
	page_label.text = str(index + 1) + "/" + str(kertas_murid.size())

func _show_stamp_if_approved(index: int):
	var approve_btn = kertas_murid[index].get_node_or_null("Aprove")
	var batal_btn = kertas_murid[index].get_node_or_null("Batal")
	if approved[index]:
		stamp.visible = true
		stamp.scale = Vector2(1.0, 1.0)
		stamp.modulate.a = 1.0
		if approve_btn:
			approve_btn.visible = false
		if batal_btn:
			batal_btn.visible = true
	else:
		stamp.visible = false
		if approve_btn:
			approve_btn.visible = true
		if batal_btn:
			batal_btn.visible = false

func _show_page(index: int):
	for i in kertas_murid.size():
		kertas_murid[i].visible = (i == index)

	_update_nav_buttons(index)
	_show_stamp_if_approved(index)
	_update_page_label(index)

# ================= GESER APPROVE + TOMBOL BELAJAR =================

func _shift_approve_for_belajar():
	if approve_shifted:
		return

	var last_kertas = kertas_murid[kertas_murid.size() - 1]
	var approve_btn = last_kertas.get_node_or_null("Aprove")
	var batal_btn = last_kertas.get_node_or_null("Batal")

	var ref_btn = approve_btn if approve_btn else batal_btn
	if not ref_btn:
		return

	var gap = 10.0
	var shift_amount = (ref_btn.size.x + gap) / 2.0
	var shifted_x = last_page_approve_original_pos.x - shift_amount
	var belajar_target = Vector2(
		last_page_approve_original_pos.x + ref_btn.size.x + gap - shift_amount,
		ref_btn.position.y
	)

	# Start Belajar off-screen to the right, then slide in
	belajar_button.position = Vector2(belajar_target.x + 300, belajar_target.y)
	belajar_button.modulate.a = 0.0
	belajar_button.visible = true

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Slide Approve/Batal to the left
	if approve_btn:
		tween.tween_property(approve_btn, "position:x", shifted_x, 0.35)
	if batal_btn:
		tween.tween_property(batal_btn, "position:x", shifted_x, 0.35)

	# Slide Belajar in from the right
	tween.tween_property(belajar_button, "position", belajar_target, 0.35)
	tween.tween_property(belajar_button, "modulate:a", 1.0, 0.2)

	approve_shifted = true

func _reset_approve_position():
	if not approve_shifted:
		return

	var last_kertas = kertas_murid[kertas_murid.size() - 1]
	var approve_btn = last_kertas.get_node_or_null("Aprove")
	var batal_btn = last_kertas.get_node_or_null("Batal")

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	if approve_btn:
		tween.tween_property(approve_btn, "position", last_page_approve_original_pos, 0.25)
	if batal_btn:
		tween.tween_property(batal_btn, "position", last_page_batal_original_pos, 0.25)

	# Slide Belajar out to the right
	tween.tween_property(belajar_button, "position:x", belajar_button.position.x + 300, 0.25)
	tween.tween_property(belajar_button, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func(): belajar_button.visible = false)

	approve_shifted = false

func _sync_student_data_from_ui():
	for i in range(kertas_murid.size()):
		if i >= student_data_list.size():
			break
		var kertas = kertas_murid[i]
		if not kertas:
			continue
		var kp1 = kertas.get_node_or_null("Kepribadian1")
		if kp1 and kp1 is ProgressBar:
			student_data_list[i]["kepribadian1"] = kp1.value
		var kp2 = kertas.get_node_or_null("Kepribadian2")
		if kp2 and kp2 is ProgressBar:
			student_data_list[i]["kepribadian2"] = kp2.value
		var ak1 = kertas.get_node_or_null("Akademis1")
		if ak1 and ak1 is ProgressBar:
			student_data_list[i]["akademis1"] = ak1.value
		var ak2 = kertas.get_node_or_null("Akademis2")
		if ak2 and ak2 is ProgressBar:
			student_data_list[i]["akademis2"] = ak2.value
		var ak3 = kertas.get_node_or_null("Akademis3")
		if ak3 and ak3 is ProgressBar:
			student_data_list[i]["akademis3"] = ak3.value

var student_data_list = [
	{
		"id": 1,
		"name": "Hamamiya",
		"portrait": "res://Asset/MuridPotrait/Murid1.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid1.jpg",
		"kepribadian1": 65.0,
		"kepribadian2": 50.0,
		"akademis1": 30.0,
		"akademis2": 50.0,
		"akademis3": 40.0,
		"target_akademis1": 50.0,
		"target_akademis2": 60.0,
		"target_akademis3": 55.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 40.0,
		"hobby_category": "Akademik",
		"quirk": "Quirk Kutu Buku",
		"persona": "Persona Rajin",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	},
	{
		"id": 2,
		"name": "Ambatukam",
		"portrait": "res://Asset/MuridPotrait/Murid2.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid2.jpg",
		"kepribadian1": 60.0,
		"kepribadian2": 60.0,
		"akademis1": 40.0,
		"akademis2": 20.0,
		"akademis3": 35.0,
		"target_akademis1": 50.0,
		"target_akademis2": 30.0,
		"target_akademis3": 45.0,
		"target_kepribadian1": 40.0,
		"target_kepribadian2": 35.0,
		"hobby_category": "Olahraga",
		"quirk": "Quirk Kutu Buku",
		"persona": "Persona Rajin",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	},
	{
		"id": 3,
		"name": "Zeta",
		"portrait": "res://Asset/MuridPotrait/Murid3.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid3.jpg",
		"kepribadian1": 65.0,
		"kepribadian2": 65.0,
		"akademis1": 50.0,
		"akademis2": 60.0,
		"akademis3": 35.0,
		"target_akademis1": 60.0,
		"target_akademis2": 65.0,
		"target_akademis3": 55.0,
		"target_kepribadian1": 60.0,
		"target_kepribadian2": 55.0,
		"hobby_category": "SeniBudaya",
		"quirk": "Quirk Kutu Buku",
		"persona": "Persona Rajin",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	},
	{
		"id": 4,
		"name": "Bocchi",
		"portrait": "res://Asset/MuridPotrait/Murid4.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid4.jpg",
		"kepribadian1": 30.0,
		"kepribadian2": 65.0,
		"akademis1": 30.0,
		"akademis2": 20.0,
		"akademis3": 10.0,
		"target_akademis1": 40.0,
		"target_akademis2": 50.0,
		"target_akademis3": 30.0,
		"target_kepribadian1": 35.0,
		"target_kepribadian2": 45.0,
		"hobby_category": "Olahraga",
		"quirk": "Quirk Kutu Buku",
		"persona": "Persona Rajin",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	},
	{
		"id": 5,
		"name": "Ga Peduli",
		"portrait": "res://Asset/MuridPotrait/Murid5.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid5.jpg",
		"kepribadian1": 10.0,
		"kepribadian2": 20.0,
		"akademis1": 40.0,
		"akademis2": 20.0,
		"akademis3": 20.0,
		"target_akademis1": 50.0,
		"target_akademis2": 40.0,
		"target_akademis3": 30.0,
		"target_kepribadian1": 30.0,
		"target_kepribadian2": 35.0,
		"hobby_category": "Akademik",
		"quirk": "Quirk Kutu Buku",
		"persona": "Persona Rajin",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	},
	{
		"id": 6,
		"name": "Jokoteno",
		"portrait": "res://Asset/MuridPotrait/Murid6.jpg",
		"splash": "res://Asset/SplashArtMurid/SplashMurid6.jpg",
		"kepribadian1": 60.0,
		"kepribadian2": 50.0,
		"akademis1": 35.0,
		"akademis2": 20.0,
		"akademis3": 40.0,
		"target_akademis1": 45.0,
		"target_akademis2": 40.0,
		"target_akademis3": 55.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 45.0,
		"hobby_category": "SeniBudaya",
		"quirk": "Quirk Kutu Buku",
		"persona": "Persona Rajin",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	}
]

func _on_belajar_pressed():
	_sync_student_data_from_ui()
	GameState.returned_from_student_card = true
	GameState.approved_students.clear()
	for i in approved.size():
		if approved[i]:
			GameState.approved_students.append(student_data_list[i])

	if GameState.approved_students.is_empty():
		GameState.approved_students = [student_data_list[0], student_data_list[1], student_data_list[2], student_data_list[3]]

	GameState.selected_student = GameState.approved_students[0]
	Transition.change_scene("res://Scene/loby.tscn")

# ================= STAMP APPROVE / BATAL =================

func _on_approve_pressed(page_index: int):
	print("DEBUG approve ditekan, tutorial_active: ", tutorial_active)
	if tutorial_active or is_animating:
		return
	if approved[page_index]:
		return
	if approved_count >= MAX_APPROVE:
		print("Batas approve tercapai, tidak bisa approve murid lain")
		return

	approved[page_index] = true
	approved_count += 1
	_play_stamp_effect()

	var approve_btn = kertas_murid[page_index].get_node_or_null("Aprove")
	var batal_btn = kertas_murid[page_index].get_node_or_null("Batal")
	if approve_btn:
		approve_btn.visible = false
	if batal_btn:
		batal_btn.visible = true

	_update_approve_buttons_state()
	_update_nav_buttons(current_page)

func _on_batal_pressed(page_index: int):
	if tutorial_active or is_animating:
		return
	if not approved[page_index]:
		return

	approved[page_index] = false
	approved_count = max(0, approved_count - 1)
	stamp.visible = false

	var approve_btn = kertas_murid[page_index].get_node_or_null("Aprove")
	var batal_btn = kertas_murid[page_index].get_node_or_null("Batal")
	if batal_btn:
		batal_btn.visible = false
	if approve_btn:
		approve_btn.visible = true

	_update_approve_buttons_state()
	_update_nav_buttons(current_page)

func _update_approve_buttons_state():
	var limit_reached = approved_count >= MAX_APPROVE
	for i in kertas_murid.size():
		var approve_btn = kertas_murid[i].get_node_or_null("Aprove")
		if approve_btn:
			if approved[i]:
				approve_btn.disabled = true
			else:
				approve_btn.disabled = limit_reached

var stamp_tween: Tween

func _play_stamp_effect():
	stamp.visible = true
	stamp.pivot_offset = stamp.size / 2
	stamp.scale = Vector2(3.0, 3.0)
	stamp.modulate.a = 0.0
	stamp.rotation_degrees = randf_range(-8, 8)

	if stamp_tween and stamp_tween.is_running():
		stamp_tween.kill()

	stamp_tween = create_tween()
	stamp_tween.set_trans(Tween.TRANS_BACK)
	stamp_tween.set_ease(Tween.EASE_OUT)

	stamp_tween.tween_property(stamp, "scale", Vector2(1.0, 1.0), 0.3)
	stamp_tween.parallel().tween_property(stamp, "modulate:a", 1.0, 0.15)
