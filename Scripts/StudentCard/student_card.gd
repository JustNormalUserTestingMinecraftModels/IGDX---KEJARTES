extends Control

@export_group("Stat & Needs Colors")
@export var color_mood: Color = Color(0.50, 0.14, 0.74)
@export var color_energy: Color = Color(0.90, 0.66, 0.04)
@export var color_akademis: Color = Color(0.10, 0.28, 0.90)
@export var color_senibudaya: Color = Color(0.10, 0.62, 0.22)
@export var color_olahraga: Color = Color(0.87, 0.21, 0.07)
@export var color_quirk_badge: Color = Color(0.04, 0.56, 0.68)
@export var color_persona_badge: Color = Color(0.48, 0.13, 0.78)

@export_group("UI Textures (Optional Replace)")
@export var icon_magnify: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_magnify.svg")
@export var icon_mood: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_mood.svg")
@export var icon_energy: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_energy.svg")
@export var icon_akademis: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_akademis.svg")
@export var icon_seni: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_seni.svg")
@export var icon_olahraga: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_olahraga.svg")
@export var popup_bg_tex: Texture2D = preload("res://Assets/Images/UI/Placeholders/popup_bg.svg")
@export var popup_inner_tex: Texture2D = preload("res://Assets/Images/UI/Placeholders/popup_inner.svg")
@export var badge_bg_tex: Texture2D = preload("res://Assets/Images/UI/Placeholders/badge_bg.svg")
@export var tex_btn_approve: Texture2D = preload("res://Assets/Images/UI/Placeholders/btn_approve.svg")
@export var tex_btn_batal: Texture2D = preload("res://Assets/Images/UI/Placeholders/btn_batal.svg")
@export var tex_btn_belajar: Texture2D = preload("res://Assets/Images/UI/Placeholders/btn_belajar.svg")

# ================= TRAIT DESCRIPTIONS =================

const QUIRK_DESCRIPTIONS: Dictionary = {
	"Kutu Buku":     "Nilai Akademis naik 15% lebih cepat saat dijadwalkan kegiatan Akademis.",
	"Semangat Juang":"Tidak mudah lelah — biaya Energi berkurang 10% per sesi Olahraga.",
	"Penasaran":     "Seni Budaya & Akademis sama-sama meningkat lebih merata per minggu.",
	"Penyendiri":    "Lebih efektif sendiri — sesi Akademis solo memberi +5% bonus nilai.",
	"Biang Onar":    "Ada peluang kecil mengganggu murid lain saat dijadwalkan bersama.",
	"Pekerja Keras": "Skill growth +10% tapi Energy berkurang lebih cepat setiap minggu."
}

const PERSONA_DESCRIPTIONS: Dictionary = {
	"Persona Tekun":   "Konsisten belajar — tidak kehilangan progress meski Mood sedang rendah.",
	"Persona Aktif":   "Butuh minimal 1 sesi Olahraga per minggu atau Mood turun otomatis.",
	"Persona Kreatif": "Seni Budaya memberi bonus ganda jika dijadwalkan 2x atau lebih seminggu.",
	"Persona Pendiam": "Mood naik lebih lambat dalam kegiatan kelompok, tapi Akademis lebih stabil.",
	"Persona Santai":  "Perlu 1 sesi Istirahat per minggu atau Energi drop drastis akhir minggu."
}

# ================= ACTIVE POPUP & TUTORIAL BADGE =================
var _active_popup: Node = null
var _tutorial_badge_cleanup: Callable

# --- Tutorial ---
@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea

@export_group("Tutorial")
## Edit this array in the Inspector to customize each tutorial step.
@export var tutorial_steps: Array[TutorialStepData] = []
## Optional PNG texture for custom tutorial dialogue box background.
@export var custom_panel_texture: Texture2D = preload("res://Assets/Images/UI/tutorial_panel_bg.png")
## Optional custom StyleBox override for the tutorial panel.
@export var custom_panel_stylebox: StyleBox = null

const TutorialArrow = preload("res://Scripts/TutorialArrow.gd")

var current_step := 0
var tutorial_active := true
var _tutorial_panel: PanelContainer
var _tutorial_title_label: Label
var _tutorial_body_label: Label
var _tutorial_prompt_label: Label
var _blink_tween: Tween
var _highlight_tween: Tween
var _tutorial_arrow: Control = null

# --- Paginasi Kertas Murid ---
@onready var kertas_murid: Array = [$KertasMurid1, $KertasMurid2, $KertasMurid3, $KertasMurid4, $KertasMurid5, $KertasMurid6]
@onready var next_kanan: BaseButton = $NextButtonKanan
@onready var next_kiri: BaseButton = $NextButtonKiri
@onready var stamp: TextureRect = $StampApprove
@onready var page_label: Label = $PageLabel
@onready var belajar_button: BaseButton = $BelajarButton

var current_page := 0
var approved := []
var previously_approved_ids := []
var is_animating := false

# --- Limit Approve ---
var MAX_APPROVE := 4
var approved_count := 0

# --- Geser Approve/Batal ---
var approve_shifted := false

func _ready():
	_tutorial_badge_cleanup = func(): pass

	# Determine MAX_APPROVE based on grade
	match GameState.current_grade:
		7: MAX_APPROVE = 2
		8: MAX_APPROVE = 3
		9: MAX_APPROVE = 4
		_: MAX_APPROVE = 2

	# Record already approved IDs and carry over latest stats
	previously_approved_ids.clear()
	for approved_s in GameState.approved_students:
		previously_approved_ids.append(approved_s.get("id"))
		# Update student_data_list with stats from GameState
		for i in range(student_data_list.size()):
			if student_data_list[i].get("id") == approved_s.get("id"):
				student_data_list[i] = approved_s.duplicate()
				break

	# ---------- Setup Tutorial ----------
	if tutorial_steps.is_empty():
		_populate_default_tutorial_steps()

	# Wrap color_rect in a CanvasLayer to ensure tutorial overlay and panel always render on top of popups
	var tut_canvas = CanvasLayer.new()
	tut_canvas.name = "TutorialCanvasLayer"
	tut_canvas.layer = 101 # Trait popups are layer 100
	add_child(tut_canvas)
	color_rect.get_parent().remove_child(color_rect)
	tut_canvas.add_child(color_rect)

	_tutorial_arrow = TutorialArrow.new()
	_tutorial_arrow.visible = false
	color_rect.add_child(_tutorial_arrow)

	# Set shader rect_size immediately so overlay renders correctly from the first frame
	var viewport_size = get_viewport_rect().size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	# Defer positioning until global_position is resolved after layout
	call_deferred("_fit_color_rect_to_viewport")
	get_tree().root.size_changed.connect(_fit_color_rect_to_viewport)

	# Build the dynamic tutorial panel UI
	_build_tutorial_panel()

	if click_area.has_signal("pressed"):
		click_area.pressed.connect(_next_step)
	else:
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.gui_input.connect(_on_click_area_gui_input)

	# ---------- Setup Paginasi & Stamp ----------
	approved.resize(kertas_murid.size())
	approved_count = 0
	for i in approved.size():
		var s_data = student_data_list[i]
		if previously_approved_ids.has(s_data.get("id")):
			approved[i] = true
			approved_count += 1
		else:
			approved[i] = false

	stamp.visible = false

	next_kanan.pressed.connect(_on_next_kanan_pressed)
	next_kiri.pressed.connect(_on_next_kiri_pressed)

	for i in kertas_murid.size():
		var approve_btn = kertas_murid[i].get_node_or_null("Aprove")
		if approve_btn:
			approve_btn.set_meta("original_position", approve_btn.position)
			_setup_button_juice(approve_btn)
			_apply_button_texture(approve_btn, tex_btn_approve, 32, 90.0, Color(0.1, 0.3, 0.15)) # dark green text
			if not approve_btn.pressed.is_connected(_on_approve_pressed.bind(i)):
				approve_btn.pressed.connect(_on_approve_pressed.bind(i))

		var batal_btn = kertas_murid[i].get_node_or_null("Batal")
		if batal_btn:
			batal_btn.set_meta("original_position", batal_btn.position)
			_setup_button_juice(batal_btn)
			_apply_button_texture(batal_btn, tex_btn_batal, 32, 90.0, Color(0.3, 0.1, 0.1)) # dark red text
			if not batal_btn.pressed.is_connected(_on_batal_pressed.bind(i)):
				batal_btn.pressed.connect(_on_batal_pressed.bind(i))
			batal_btn.visible = false

	next_kanan.visible = false
	next_kiri.visible = false

	for k in kertas_murid:
		k.set_meta("original_position", k.position)

	# ---------- Setup Tombol Belajar ----------
	belajar_button.pressed.connect(_on_belajar_pressed)
	_setup_button_juice(belajar_button)
	_apply_button_texture(belajar_button, tex_btn_belajar, 42, 0.0, Color.WHITE)
	belajar_button.visible = false

	# Populate UI with data from script (overrides placeholder data in .tscn)
	_populate_ui_from_data()
	
	_sync_student_data_from_ui()
	_show_step(0)

# ================= TOUCH SWIPE NAVIGATION =================

var swipe_start_pos: Vector2 = Vector2.ZERO
var is_swiping: bool = false
const SWIPE_THRESHOLD: float = 60.0

func _input(event: InputEvent):
	if tutorial_active or is_animating or (_active_popup != null and is_instance_valid(_active_popup)):
		is_swiping = false
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				swipe_start_pos = event.position
				is_swiping = true
			else:
				if is_swiping:
					is_swiping = false
					_evaluate_swipe(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			swipe_start_pos = event.position
			is_swiping = true
		else:
			if is_swiping:
				is_swiping = false
				_evaluate_swipe(event.position)

func _evaluate_swipe(end_pos: Vector2):
	if _active_popup != null and is_instance_valid(_active_popup):
		return
	var delta_x = end_pos.x - swipe_start_pos.x
	var delta_y = end_pos.y - swipe_start_pos.y
	if abs(delta_x) > 40.0 and abs(delta_x) > abs(delta_y):
		if delta_x < 0:
			_on_next_kanan_pressed()
		else:
			_on_next_kiri_pressed()

# ================= TUTORIAL =================

func _populate_default_tutorial_steps():
	tutorial_steps.clear()
	if GameState.current_grade == 7:
		var defaults = [
			["Selamat Datang!", "Kita disini mempunyai beberapa laporan berbagai macam murid yang dapat anda pilih untuk anda ajari!\n\nMereka mempunyai performance dan sifat berbeda-beda, jadi pilihlah dengan bijak!", "", ""],
			["Mood Murid", "Ini adalah bar Mood murid. Mood menunjukkan tingkat kebahagiaan murid.\n\nJika mood rendah, murid akan sulit untuk belajar dengan baik.", "KertasMurid1/Kepribadian1", ""],
			["Energy Murid", "Ini adalah bar Energy murid. Energy menunjukkan kapasitas seberapa banyak murid untuk dapat diajar berbagai mata pelajaran.", "KertasMurid1/Kepribadian2", ""],
			["Skill Murid", "Sekarang kita lihat bagian Skill. Skill menunjukkan kemampuan murid di berbagai bidang pelajaran.", "KertasMurid1/Akademis1,KertasMurid1/Akademis2,KertasMurid1/Akademis3", ""],
			["Akademis", "Bar Akademis menunjukkan kemampuan murid dalam pelajaran akademis.\n\nSemakin tinggi nilainya, semakin mudah murid memahami pelajaran.", "KertasMurid1/Akademis1", ""],
			["Seni Budaya", "Bar Seni Budaya menunjukkan kemampuan murid dalam bidang seni dan kebudayaan.", "KertasMurid1/Akademis2", ""],
			["Olahraga", "Bar Olahraga menunjukkan kemampuan fisik dan ketangkasan murid dalam bidang olahraga.", "KertasMurid1/Akademis3", ""],
			["Quirk Murid", "Setiap murid punya Quirk — sifat unik yang mempengaruhi cara mereka berkembang!\n\nQuirk bisa jadi keunggulan atau tantangan tersendiri saat menyusun jadwal belajar.", "KertasMurid1/KutuBuku", ""],
			["Coba Quirk!", "Sekarang coba sentuh badge Quirk milik murid ini untuk melihat langsung efeknya pada gameplay!", "KertasMurid1/KutuBuku", "TEKAN BADGE QUIRK UNTUK LIHAT EFEKNYA!"],
			["Efek Quirk", "Pop-up ini menjelaskan efek dari Quirk yang akan mempengaruhi gameplay ke depannya.\n\nSilahkan baca efeknya lalu tutup pop-up ini untuk melanjutkan.", "KertasMurid1/PopupCanvas/TraitOverlay/TraitPopupPanel", "TUTUP POP-UP UNTUK LANJUT!"],
			["Persona Murid", "Persona adalah kepribadian dasar murid yang menentukan kebutuhan mereka setiap minggu.\n\nPilih jadwal yang cocok dengan Persona murid agar mereka tetap semangat!", "KertasMurid1/KutuBuku2", ""],
			["Coba Persona!", "Sekarang sentuh badge Persona untuk melihat efeknya pada jadwal mingguan murid!", "KertasMurid1/KutuBuku2", "TEKAN BADGE PERSONA UNTUK LIHAT EFEKNYA!"],
			["Efek Persona", "Sama seperti Quirk, pop-up ini menjelaskan efek Persona yang mempengaruhi gameplay.\n\nSilahkan baca dan tutup pop-up ini untuk melanjutkan.", "KertasMurid1/PopupCanvas/TraitOverlay/TraitPopupPanel", "TUTUP POP-UP UNTUK LANJUT!"],
			["Memilih Murid", "Kamu bisa memilih hingga 2 murid untuk diajar.\n\nGunakan tombol panah untuk melihat murid lainnya dan pilih dengan bijak!", "NextButtonKanan", "Tekan tombol panah Kanan untuk lanjut!"],
			["Approve Murid", "Tekan tombol APPROVE untuk memilih murid ini.\n\nSetelah memilih 2 murid, tombol BELAJAR akan muncul untuk melanjutkan!", "KertasMurid1/Aprove", "Tekan tombol 'APPROVE' untuk lanjut!"]
		]
		for entry in defaults:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_steps.append(step)
	elif GameState.current_grade == 8:
		var defaults = [
			["Selamat Datang di Kelas 8!", "Kepala Sekolah: 'Selamat atas keberhasilanmu membimbing murid-murid di Kelas 7! Namun perjuangan belum usai. Sekarang mereka resmi naik ke Kelas 8.'", "", ""],
			["Tantangan Baru", "Kepala Sekolah: 'Kelas 8 akan memiliki kurikulum yang lebih menantang. Untuk membantu menyeimbangkan dinamika kelas, kita kedatangan murid-murid baru.'", "", ""],
			["Pilih Murid Tambahan", "Narator: 'Silakan pilih 1 murid tambahan dari kartu yang tersedia untuk melengkapi kelasmu menjadi 3 murid. Murid lama tidak bisa diganti.'", "", ""]
		]
		for entry in defaults:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_steps.append(step)
	elif GameState.current_grade == 9:
		var defaults = [
			["Selamat Datang di Kelas 9!", "Kepala Sekolah: 'Luar biasa! Murid-muridmu sekarang telah mencapai jenjang akhir di Kelas 9. Ini tahun penentuan kelulusan mereka.'", "", ""],
			["Persiapan Ujian Akhir", "Kepala Sekolah: 'Ujian akhir nasional sudah di depan mata. Kita membutuhkan satu murid lagi agar kelas bimbinganmu genap berisi 4 murid.'", "", ""],
			["Pilih Murid Terakhir", "Narator: 'Pilihlah murid terakhir dari kartu yang tersisa untuk melengkapi kelasmu menjadi 4 murid. Persiapkan mereka untuk kelulusan!'", "", ""]
		]
		for entry in defaults:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_steps.append(step)




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
		flat.border_width_left = 4
		flat.border_width_top = 4
		flat.border_width_right = 4
		flat.border_width_bottom = 8
		flat.border_color = Color(0.5, 0.55, 0.55) # Chalk border #7f8c8d
		flat.corner_radius_top_left = 18
		flat.corner_radius_top_right = 18
		flat.corner_radius_bottom_left = 18
		flat.corner_radius_bottom_right = 18
		flat.shadow_color = Color(0, 0, 0, 0.4)
		flat.shadow_size = 6
		flat.shadow_offset = Vector2(0, 4)
		flat.content_margin_left = 32
		flat.content_margin_top = 24
		flat.content_margin_right = 32
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

	# Start blinking prompt
	_start_prompt_blink()

	# Position panel at bottom-center
	call_deferred("_position_tutorial_panel")




func _start_prompt_blink():
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	if _tutorial_prompt_label:
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
	_tutorial_panel.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(_tutorial_panel):
		return
	var panel_size = _tutorial_panel.size
	
	var target_y: float
	if current_step >= 7:
		# Center vertically in the viewport for steps 7+ to avoid covering bottom controls and popups
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

func _on_click_area_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_step()
	elif event is InputEventScreenTouch and event.pressed:
		_next_step()

func _fit_color_rect_to_viewport():
	var viewport_size = get_viewport_rect().size
	color_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if color_rect.get_parent() is CanvasLayer:
		color_rect.position = Vector2.ZERO
	else:
		color_rect.position = -global_position
	color_rect.size = viewport_size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	if tutorial_active and _tutorial_panel and is_instance_valid(_tutorial_panel):
		call_deferred("_position_tutorial_panel")

func _next_step():
	current_step += 1
	if current_step >= tutorial_steps.size():
		_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int):
	if index < 0 or index >= tutorial_steps.size():
		return
	var step = tutorial_steps[index]
	
	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_property(_tutorial_panel, "scale", Vector2(0.8, 0.8), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween_out.tween_property(_tutorial_panel, "modulate:a", 0.0, 0.15)
	
	await tween_out.finished
	
	_tutorial_title_label.text = "(%d/%d) %s" % [index + 1, tutorial_steps.size(), step.title]
	_tutorial_body_label.text = step.text

	if GameState.current_grade == 7:
		next_kanan.visible = (index == 11)
	else:
		next_kanan.visible = false

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
			if GameState.current_grade == 7 and index == 13 and next_kanan:
				next_kanan.show() # Force it visible just in case
			
			var padding = 16.0 # increased default padding
			if GameState.current_grade == 7 and index == 13:
				padding = 64.0 # Huge padding to ensure arrow is seen
			elif GameState.current_grade == 7 and index in [9, 12]:
				padding = 40.0 # generous padding for popups
			_highlight_multiple(targets, padding)
		else:
			_clear_highlight()
	else:
		_clear_highlight()

	# Dynamic Prompt Text
	var requires_button_press = (GameState.current_grade == 7 and index == tutorial_steps.size() - 1 and step.target_node_path != "") or (GameState.current_grade == 7 and index == 11)
	if step.prompt_text != "":
		_tutorial_prompt_label.text = step.prompt_text
	elif requires_button_press and not targets.is_empty():
		var btn_name = _get_button_display_name(targets[0])
		_tutorial_prompt_label.text = "TEKAN TOMBOL '%s' UNTUK LANJUT!" % btn_name.to_upper()
	else:
		_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"

	_position_tutorial_panel()
	_tutorial_panel.pivot_offset = _tutorial_panel.size / 2.0
	
	# Transition In: cute bouncy scale-up pop-in
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(_tutorial_panel, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.2)
	
	await tween_in.finished
	
	# Badge-gated steps (8, 11) and popup-gated steps (9, 12) require manual interaction
	if GameState.current_grade == 7 and index in [8, 9, 11, 12]:
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if index == 8 or index == 11:
			_arm_tutorial_badge(index)
	else:
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

func _highlight_multiple(controls: Array[Control], padding: float = 12.0):
	# Defer one frame so layout is resolved and control sizes are accurate
	await get_tree().process_frame
	
	var valid_controls: Array[Control] = []
	for c in controls:
		if is_instance_valid(c):
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
		# Use global transform matrix of control to transform the 4 corners,
		# perfectly handling scaled, rotated, or offset elements (like NextButtonKanan)
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
	
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
		
	var current_size = mat.get_shader_parameter("hole_size")
	var arrow_pos = Vector2(local_pos.x + size_with_padding.x / 2.0, local_pos.y - 35.0)
	if _tutorial_arrow:
		var viewport_size = get_viewport_rect().size
		var W = 320.0
		var H = 320.0
		var margin = 20.0
		arrow_pos.x = clamp(arrow_pos.x, W/2.0 + margin, viewport_size.x - W/2.0 - margin)
		arrow_pos.y = clamp(arrow_pos.y, H + margin, viewport_size.y - margin)
	if current_size == null or (current_size is Vector2 and current_size.length_squared() < 1.0):
		# If coming from a cleared state, warp the position to center immediately to avoid swiping across screen
		var center = local_pos + size_with_padding / 2.0
		mat.set_shader_parameter("hole_pos", center)
		mat.set_shader_parameter("hole_size", Vector2.ZERO)
		if _tutorial_arrow:
			_tutorial_arrow.position = arrow_pos
		
	_highlight_tween = create_tween().set_parallel(true)
	_highlight_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(mat, "shader_parameter/hole_pos", local_pos, 0.45)
	_highlight_tween.tween_property(mat, "shader_parameter/hole_size", size_with_padding, 0.45)
	if _tutorial_arrow:
		_tutorial_arrow.show()
		_highlight_tween.tween_property(_tutorial_arrow, "position", arrow_pos, 0.45)

func _clear_highlight():
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		return
	
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
		
	if _tutorial_arrow:
		_tutorial_arrow.hide()
		
	_highlight_tween = create_tween().set_parallel(true)
	_highlight_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var current_pos = mat.get_shader_parameter("hole_pos")
	var current_size = mat.get_shader_parameter("hole_size")
	if current_pos is Vector2 and current_size is Vector2:
		var center = current_pos + current_size / 2.0
		_highlight_tween.tween_property(mat, "shader_parameter/hole_pos", center, 0.3)
	_highlight_tween.tween_property(mat, "shader_parameter/hole_size", Vector2.ZERO, 0.3)

func _end_tutorial():
	tutorial_active = false
	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_panel.queue_free()
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
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null
	is_animating = true
	next_kanan.disabled = true
	next_kiri.disabled = true

	var old_kertas = kertas_murid[old_index]
	var new_kertas = kertas_murid[new_index]

	var screen_width = get_viewport_rect().size.x
	var throw_distance = screen_width * direction

	var stamp_orig_pos = stamp.position
	var belajar_orig_pos = belajar_button.position

	# --- TWEEN OUT (Throw old card, stamp, and belajar button off-screen) ---
	var tween_out = create_tween().set_parallel(true)
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out.tween_property(old_kertas, "position:x", old_kertas.position.x + throw_distance, 0.35)
	tween_out.tween_property(old_kertas, "rotation_degrees", 15 * direction, 0.35)
	tween_out.tween_property(old_kertas, "modulate:a", 0.0, 0.35)

	if stamp.visible:
		tween_out.tween_property(stamp, "position:x", stamp.position.x + throw_distance, 0.35)
		tween_out.tween_property(stamp, "rotation_degrees", 15 * direction, 0.35)
		tween_out.tween_property(stamp, "modulate:a", 0.0, 0.35)

	if belajar_button.visible:
		tween_out.tween_property(belajar_button, "position:x", belajar_button.position.x + throw_distance, 0.35)
		tween_out.tween_property(belajar_button, "modulate:a", 0.0, 0.35)

	await tween_out.finished

	# Reset old card
	old_kertas.hide()
	old_kertas.position = old_kertas.get_meta("original_position")
	old_kertas.rotation_degrees = 0
	old_kertas.modulate.a = 1.0

	# Reset stamp & belajar_button transforms
	stamp.position = stamp_orig_pos
	stamp.rotation_degrees = 0
	stamp.modulate.a = 1.0
	belajar_button.position = belajar_orig_pos
	belajar_button.modulate.a = 1.0

	_reset_all_approve_positions()

	# Prepare new card, new stamp (if approved), and nav state
	new_kertas.show()
	var original_pos = new_kertas.get_meta("original_position")
	new_kertas.position = original_pos - Vector2(throw_distance, 0)
	new_kertas.rotation_degrees = -15 * direction
	new_kertas.modulate.a = 0.0

	_show_stamp_if_approved(new_index)
	_update_nav_buttons(new_index)

	# --- TWEEN IN (Slide new card, stamp, and belajar button in from off-screen) ---
	var tween_in = create_tween().set_parallel(true)
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(new_kertas, "position", original_pos, 0.35)
	tween_in.tween_property(new_kertas, "rotation_degrees", 0, 0.35)
	tween_in.tween_property(new_kertas, "modulate:a", 1.0, 0.35)

	if stamp.visible:
		stamp.position = stamp_orig_pos - Vector2(throw_distance, 0)
		stamp.rotation_degrees = -15 * direction
		stamp.modulate.a = 0.0
		tween_in.tween_property(stamp, "position", stamp_orig_pos, 0.35)
		tween_in.tween_property(stamp, "rotation_degrees", 0, 0.35)
		tween_in.tween_property(stamp, "modulate:a", 1.0, 0.35)

	if belajar_button.visible:
		belajar_button.position = belajar_orig_pos - Vector2(throw_distance, 0)
		belajar_button.modulate.a = 0.0
		tween_in.tween_property(belajar_button, "position", belajar_orig_pos, 0.35)
		tween_in.tween_property(belajar_button, "modulate:a", 1.0, 0.35)

	await tween_in.finished

	_update_page_label(new_index)

	is_animating = false
	next_kanan.disabled = false
	next_kiri.disabled = false

func _update_nav_buttons(index: int):
	if not tutorial_active:
		next_kiri.visible = index > 0
		next_kanan.visible = index < kertas_murid.size() - 1

		var limit_reached = approved_count >= MAX_APPROVE

		belajar_button.visible = limit_reached

		if belajar_button.visible:
			_shift_approve_for_belajar(index)
		else:
			_reset_approve_position(index)

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
			var s_data = student_data_list[index]
			if GameState.grade7_student_ids.has(s_data.get("id")):
				batal_btn.visible = false
			else:
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

	_show_stamp_if_approved(index)
	_update_nav_buttons(index)
	_update_page_label(index)

# ================= GESER APPROVE + TOMBOL BELAJAR =================

func _shift_approve_for_belajar(index: int):
	if approve_shifted:
		return

	var active_kertas = kertas_murid[index]
	var approve_btn = active_kertas.get_node_or_null("Aprove")
	var batal_btn = active_kertas.get_node_or_null("Batal")

	var ref_btn = approve_btn if (approve_btn and approve_btn.visible) else batal_btn
	if not ref_btn:
		return

	var orig_pos = ref_btn.get_meta("original_position") if ref_btn.has_meta("original_position") else ref_btn.position
	var ref_size = ref_btn.size * ref_btn.scale
	var gap = 10.0
	var shift_amount = (ref_size.x + gap) / 2.0
	
	var is_locked = (approve_btn and not approve_btn.visible) and (batal_btn and not batal_btn.visible)
	var shifted_x = orig_pos.x
	var kertas_pos = active_kertas.position
	var belajar_target = Vector2.ZERO

	if is_locked:
		var b_width = belajar_button.size.x * belajar_button.scale.x
		belajar_target = Vector2(
			kertas_pos.x + (active_kertas.size.x - b_width) / 2.0,
			kertas_pos.y + ref_btn.position.y
		)
	else:
		shifted_x = orig_pos.x - shift_amount
		belajar_target = Vector2(
			kertas_pos.x + orig_pos.x + ref_size.x + gap - shift_amount,
			kertas_pos.y + ref_btn.position.y
		)

	# Start Belajar off-screen to the right, then slide in
	belajar_button.position = Vector2(belajar_target.x + 300, belajar_target.y)
	belajar_button.modulate.a = 0.0
	belajar_button.visible = true

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Slide Approve/Batal to the left if not locked
	if not is_locked:
		if approve_btn:
			tween.tween_property(approve_btn, "position:x", shifted_x, 0.35)
		if batal_btn:
			tween.tween_property(batal_btn, "position:x", shifted_x, 0.35)

	# Slide Belajar in from the right
	tween.tween_property(belajar_button, "position", belajar_target, 0.35)
	tween.tween_property(belajar_button, "modulate:a", 1.0, 0.2)

	approve_shifted = true

func _reset_approve_position(index: int):
	if not approve_shifted:
		return

	var active_kertas = kertas_murid[index]
	var approve_btn = active_kertas.get_node_or_null("Aprove")
	var batal_btn = active_kertas.get_node_or_null("Batal")

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	if approve_btn and approve_btn.has_meta("original_position"):
		tween.tween_property(approve_btn, "position", approve_btn.get_meta("original_position"), 0.25)
	if batal_btn and batal_btn.has_meta("original_position"):
		tween.tween_property(batal_btn, "position", batal_btn.get_meta("original_position"), 0.25)

	# Slide Belajar out to the right
	tween.tween_property(belajar_button, "position:x", belajar_button.position.x + 300, 0.25)
	tween.tween_property(belajar_button, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func(): belajar_button.visible = false)

	approve_shifted = false

func _reset_all_approve_positions():
	for i in kertas_murid.size():
		var kertas = kertas_murid[i]
		var approve_btn = kertas.get_node_or_null("Aprove")
		var batal_btn = kertas.get_node_or_null("Batal")
		if approve_btn and approve_btn.has_meta("original_position"):
			approve_btn.position = approve_btn.get_meta("original_position")
		if batal_btn and batal_btn.has_meta("original_position"):
			batal_btn.position = batal_btn.get_meta("original_position")
	approve_shifted = false

func _sync_student_data_from_ui():
	# This function previously read hardcoded values from the UI and overwrote the true data.
	# We no longer read from the UI because the data array is the source of truth.
	pass

func _populate_ui_from_data():
	for i in range(kertas_murid.size()):
		if i >= student_data_list.size():
			break
		var kertas = kertas_murid[i]
		if not kertas:
			continue
			
		var s_data = student_data_list[i]
		
		# Update Name
		var name_label = kertas.get_node_or_null("Nama")
		if name_label and name_label is Label:
			name_label.text = s_data.get("name", "Unknown")
			
		# Update Quirk (KutuBuku)
		var quirk_label = kertas.get_node_or_null("KutuBuku")
		if quirk_label and quirk_label is Label:
			var quirk_text = s_data.get("quirk", "")
			quirk_label.text = ("Quirk " + quirk_text) if quirk_text != "" else ""
			
		# Update Persona (KutuBuku2)
		var persona_label = kertas.get_node_or_null("KutuBuku2")
		if persona_label and persona_label is Label:
			persona_label.text = s_data.get("persona", "")
			
		# Update Profil
		var profil_label = kertas.get_node_or_null("Profil")
		if profil_label and profil_label is Label:
			var p_text = "Nama: " + s_data.get("name", "") + "\n\n"
			p_text += s_data.get("profil", "")
			profil_label.text = p_text
			
		# Update Portrait Texture
		var portrait_node = kertas.get_node_or_null("TextureRect")
		if portrait_node and portrait_node is TextureRect:
			var p_path = s_data.get("portrait", "")
			if p_path != "" and ResourceLoader.exists(p_path):
				portrait_node.texture = load(p_path)
				
		# Update ProgressBars
		var kp1 = kertas.get_node_or_null("Kepribadian1")
		if kp1 and kp1 is ProgressBar:
			kp1.value = s_data.get("kepribadian2", 0)
		var kp2 = kertas.get_node_or_null("Kepribadian2")
		if kp2 and kp2 is ProgressBar:
			kp2.value = s_data.get("kepribadian1", 0)
		var ak1 = kertas.get_node_or_null("Akademis1")
		if ak1 and ak1 is ProgressBar:
			ak1.value = s_data.get("akademis1", 0)
		var ak2 = kertas.get_node_or_null("Akademis2")
		if ak2 and ak2 is ProgressBar:
			ak2.value = s_data.get("akademis2", 0)
		var ak3 = kertas.get_node_or_null("Akademis3")
		if ak3 and ak3 is ProgressBar:
			ak3.value = s_data.get("akademis3", 0)

		# ── Upgrade bar visuals & replace trait labels with animated badges ──
		_resize_and_style_bars(kertas, s_data)
		_create_trait_badge(kertas, "KutuBuku", "quirk",
			"⚡  QUIRK: " + s_data.get("quirk", "—"), s_data)
		_create_trait_badge(kertas, "KutuBuku2", "persona",
			"🌟  PERSONA: " + s_data.get("persona", "—").replace("Persona ", ""), s_data)

var student_data_list = [
	{
		"id": 1,
		"name": "Marcel",
		"portrait": "res://Assets/Images/MuridPotrait/Marcel.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid1.jpg",
		"kepribadian1": 60.0,   # Mood
		"kepribadian2": 55.0,   # Energy
		"akademis1": 28.0,      # Akademis (Specialty ★)
		"akademis2": 48.0,      # Seni Budaya
		"akademis3": 38.0,      # Olahraga
		"target_akademis1": 52.0,
		"target_akademis2": 60.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 40.0,
		"hobby_category": "Akademis",
		"personality": "Tekun",
		"quirk": "Kutu Buku",
		"persona": "Persona Tekun",
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki"
	},
	{
		"id": 2,
		"name": "Doni",
		"portrait": "res://Assets/Images/MuridPotrait/Doni.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid2.jpg",
		"kepribadian1": 55.0,   # Mood
		"kepribadian2": 55.0,   # Energy
		"akademis1": 38.0,      # Akademis
		"akademis2": 22.0,      # Seni Budaya
		"akademis3": 33.0,      # Olahraga (Specialty ★)
		"target_akademis1": 50.0,
		"target_akademis2": 40.0,
		"target_akademis3": 51.0,
		"target_kepribadian1": 40.0,
		"target_kepribadian2": 35.0,
		"hobby_category": "Olahraga",
		"personality": "Aktif",
		"quirk": "Semangat Juang",
		"persona": "Persona Aktif",
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki"
	},
	{
		"id": 3,
		"name": "Andi",
		"portrait": "res://Assets/Images/MuridPotrait/Andi.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid3.jpg",
		"kepribadian1": 60.0,   # Mood
		"kepribadian2": 60.0,   # Energy
		"akademis1": 48.0,      # Akademis
		"akademis2": 55.0,      # Seni Budaya (Specialty ★)
		"akademis3": 32.0,      # Olahraga
		"target_akademis1": 60.0,
		"target_akademis2": 64.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 60.0,
		"target_kepribadian2": 55.0,
		"hobby_category": "SeniBudaya",
		"personality": "Kreatif",
		"quirk": "Penasaran",
		"persona": "Persona Kreatif",
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki"
	},
	{
		"id": 4,
		"name": "Citra",
		"portrait": "res://Assets/Images/MuridPotrait/Citra.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid4.jpg",
		"kepribadian1": 35.0,   # Mood (LOW — recovery week 1 needed!)
		"kepribadian2": 60.0,   # Energy
		"akademis1": 28.0,      # Akademis
		"akademis2": 25.0,      # Seni Budaya
		"akademis3": 15.0,      # Olahraga (Specialty ★)
		"target_akademis1": 40.0,
		"target_akademis2": 43.0,
		"target_akademis3": 39.0,
		"target_kepribadian1": 35.0,
		"target_kepribadian2": 45.0,
		"hobby_category": "Olahraga",
		"personality": "Seni Dalam Kesunyian",
		"quirk": "Penyendiri",
		"persona": "Persona Pendiam",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	},
	{
		"id": 5,
		"name": "Shinta",
		"portrait": "res://Assets/Images/MuridPotrait/Shinta.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid5.jpg",
		"kepribadian1": 30.0,   # Mood (LOW — patience test)
		"kepribadian2": 40.0,   # Energy (LOW — needs early rest)
		"akademis1": 35.0,      # Akademis (Specialty ★)
		"akademis2": 22.0,      # Seni Budaya
		"akademis3": 22.0,      # Olahraga
		"target_akademis1": 53.0,
		"target_akademis2": 37.0,
		"target_akademis3": 37.0,
		"target_kepribadian1": 30.0,
		"target_kepribadian2": 35.0,
		"hobby_category": "Akademis",
		"personality": "Santai",
		"quirk": "Biang Onar",
		"persona": "Persona Santai",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	},
	{
		"id": 6,
		"name": "Thea",
		"portrait": "res://Assets/Images/MuridPotrait/Thea.png",
		"splash": "res://Assets/Images/SplashArtMurid/SplashMurid6.jpg",
		"kepribadian1": 55.0,   # Mood
		"kepribadian2": 50.0,   # Energy
		"akademis1": 33.0,      # Akademis
		"akademis2": 22.0,      # Seni Budaya (Specialty ★)
		"akademis3": 38.0,      # Olahraga
		"target_akademis1": 45.0,
		"target_akademis2": 46.0,
		"target_akademis3": 53.0,
		"target_kepribadian1": 50.0,
		"target_kepribadian2": 45.0,
		"hobby_category": "SeniBudaya",
		"personality": "Kreatif",
		"quirk": "Pekerja Keras",
		"persona": "Persona Kreatif",
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan"
	}
]


# ================= BAR RESIZE & BADGE CREATION =================

func _get_stat_icon(bname: String) -> Texture2D:
	match bname:
		"Kepribadian1": return icon_mood
		"Kepribadian2": return icon_energy
		"Akademis1": return icon_akademis
		"Akademis2": return icon_seni
		"Akademis3": return icon_olahraga
	return null

func _get_bar_color(bname: String) -> Color:
	match bname:
		"Kepribadian1": return color_mood
		"Kepribadian2": return color_energy
		"Akademis1": return color_akademis
		"Akademis2": return color_senibudaya
		"Akademis3": return color_olahraga
	return Color.WHITE

func _resize_and_style_bars(kertas: Control, s_data: Dictionary) -> void:
	const BAR_HEIGHT := 68.0
	const BAR_GAP    := 18.0
	const START_Y    := 890.0

	var bar_names = ["Kepribadian1", "Kepribadian2", "Akademis1", "Akademis2", "Akademis3"]
	var bar_index := { 
		"Kepribadian1": 0, 
		"Kepribadian2": 1,
		"Akademis1": 2, 
		"Akademis2": 3, 
		"Akademis3": 4 
	}

	
	for bname in bar_names:
		var bar = kertas.get_node_or_null(bname)
		if not bar or not bar is ProgressBar:
			continue

		
		var idx: int = bar_index[bname]

		
		var current_val = 0.0
		var max_val = 100.0
		if bname == "Kepribadian1":
			current_val = s_data.get("kepribadian1", 0)
			max_val = 100.0
		elif bname == "Kepribadian2":
			current_val = s_data.get("kepribadian2", 0)
			max_val = 100.0
		elif bname == "Akademis1":
			current_val = s_data.get("akademis1", 0)
		elif bname == "Akademis2":
			current_val = s_data.get("akademis2", 0)
		elif bname == "Akademis3":
			current_val = s_data.get("akademis3", 0)
			
		# Style stat name label (MOOD, ENERGY, AKADEMIS, SENI BUDAYA, OLAHRAGA).
		# The old code picked between a dark and a light text color based on
		# how full the bar was, so a label could flip color mid-run. The
		# BarLabel theme variation replaces that with one legible treatment
		# (white glyph, dark rim) that reads over both the track and every
		# category fill, so no per-node override is needed at all.
		var stat_lbl = bar.get_node_or_null("Label")
		if stat_lbl and stat_lbl is Label:
			stat_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
			stat_lbl.offset_left = 24
			stat_lbl.offset_top = 0
			stat_lbl.offset_right = 300
			stat_lbl.offset_bottom = BAR_HEIGHT
			stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			stat_lbl.theme_type_variation = &"BarLabel"

		# Rounded background
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.15)
		bg.corner_radius_top_left    = 18
		bg.corner_radius_top_right   = 18
		bg.corner_radius_bottom_left = 18
		bg.corner_radius_bottom_right= 18
		bar.add_theme_stylebox_override("background", bg)

		# Rounded fill
		var fill = StyleBoxFlat.new()
		fill.bg_color = _get_bar_color(bname)
		fill.corner_radius_top_left    = 18
		fill.corner_radius_top_right   = 18
		fill.corner_radius_bottom_left = 18
		fill.corner_radius_bottom_right= 18
		bar.add_theme_stylebox_override("fill", fill)
		
		bar.show_percentage = false

		# Make it obviously clickable
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Ensure clean event binding for bar
		var callable = _on_bar_gui_input.bind(kertas, bname, s_data)
		if bar.has_meta("bar_gui_callable"):
			bar.gui_input.disconnect(bar.get_meta("bar_gui_callable"))
		bar.gui_input.connect(callable)
		bar.set_meta("bar_gui_callable", callable)
		
		# Add a magnifying glass icon (Lup)
		var info_icon = bar.get_node_or_null("InfoIcon")
		if not info_icon:
			if icon_magnify:
				var tex = TextureRect.new()
				tex.texture = icon_magnify
				tex.name = "InfoIcon"
				tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				info_icon = tex
			else:
				var lbl = Label.new()
				lbl.name = "InfoIcon"
				lbl.text = "??"
				lbl.theme_type_variation = &"TitleLabel"
				info_icon = lbl

			info_icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			info_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			info_icon.custom_minimum_size = Vector2(56, 56)
			info_icon.offset_left = 16
			info_icon.offset_right = 72
			info_icon.offset_top = -28
			info_icon.offset_bottom = 28
			
			info_icon.mouse_filter = Control.MOUSE_FILTER_STOP
			info_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			bar.add_child(info_icon)
			_start_button_wiggle(info_icon, idx * 0.2, "big")
			
		if info_icon.has_meta("icon_gui_callable"):
			info_icon.gui_input.disconnect(info_icon.get_meta("icon_gui_callable"))
		info_icon.gui_input.connect(callable)
		info_icon.set_meta("icon_gui_callable", callable)

		# Add or update numerical value label
		var val_lbl = bar.get_node_or_null("ValueLabel")
		if not val_lbl:
			val_lbl = Label.new()
			val_lbl.name = "ValueLabel"
			bar.add_child(val_lbl)
		
		val_lbl.text = "%d / %d" % [int(current_val), int(max_val)]
		val_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		val_lbl.offset_left = 10
		val_lbl.offset_top = 0
		val_lbl.offset_right = bar.size.x - 24
		val_lbl.offset_bottom = BAR_HEIGHT
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.theme_type_variation = &"BarLabel"

func _on_bar_gui_input(ev: InputEvent, kertas: Control, bname: String, s_data: Dictionary) -> void:
	if tutorial_active or is_animating or _active_popup != null:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or \
	   (ev is InputEventScreenTouch and ev.pressed):
		_show_bar_popup(kertas, bname, s_data)

func _show_bar_popup(kertas: Control, bname: String, s_data: Dictionary) -> void:
	if next_kanan: next_kanan.hide()
	if next_kiri: next_kiri.hide()
	
	var vp: Vector2 = get_viewport_rect().size

	var canvas := CanvasLayer.new()
	canvas.name = "PopupCanvas"
	canvas.layer = 100
	kertas.add_child(canvas)

	# Full-screen dim overlay
	var overlay := ColorRect.new()
	overlay.name = "TraitOverlay"  # Keep name for easy cleanup/identification
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	_active_popup = canvas

	var popup := PanelContainer.new()
	popup.name = "TraitPopupPanel"
	var panel_w := vp.x * 0.94
	popup.custom_minimum_size = Vector2(panel_w, 0)
	
	if popup_bg_tex:
		var bg_tex := StyleBoxTexture.new()
		bg_tex.texture = popup_bg_tex
		bg_tex.texture_margin_left = 32
		bg_tex.texture_margin_right = 32
		bg_tex.texture_margin_top = 32
		bg_tex.texture_margin_bottom = 32
		popup.add_theme_stylebox_override("panel", bg_tex)
	else:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.96, 0.95, 0.92)
		bg.corner_radius_top_left = 32
		bg.corner_radius_top_right = 32
		bg.corner_radius_bottom_left = 32
		bg.corner_radius_bottom_right = 32
		bg.content_margin_left = 0
		bg.content_margin_top = 0
		bg.content_margin_right = 0
		bg.content_margin_bottom = 0
		popup.add_theme_stylebox_override("panel", bg)
	overlay.add_child(popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	popup.add_child(vbox)

	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 32)
	header.add_theme_constant_override("margin_top", 32)
	header.add_theme_constant_override("margin_right", 32)
	header.add_theme_constant_override("margin_bottom", 24)
	vbox.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	header.add_child(hbox)

	var is_needs = (bname == "Kepribadian1" or bname == "Kepribadian2")
	var category_name = "NEEDS" if is_needs else "STATS"
	var stat_name = ""
	var current_val = 0.0
	var max_val = 100.0
	var desc = ""
	var icon = ""
	
	if bname == "Kepribadian1":
		stat_name = "Mood"
		current_val = s_data.get("kepribadian1", 0)
		max_val = 100.0
		desc = "Mood mempengaruhi tingkat kemauan murid belajar. Jika mood rendah, murid akan stress dan performanya menurun!"
		icon = "😊"
	elif bname == "Kepribadian2":
		stat_name = "Energy"
		current_val = s_data.get("kepribadian2", 0)
		max_val = 100.0
		desc = "Energy digunakan untuk melakukan aktivitas. Pastikan energy cukup sebelum memberikan tugas berat!"
		icon = "⚡"
	elif bname == "Akademis1":
		stat_name = "Akademis"
		current_val = s_data.get("akademis1", 0)
		desc = "Menunjukkan tingkat kemampuan murid dalam memahami pelajaran akademis dan teoritis."
		icon = "📚"
	elif bname == "Akademis2":
		stat_name = "Seni Budaya"
		current_val = s_data.get("akademis2", 0)
		desc = "Menunjukkan tingkat kemampuan murid dalam menciptakan dan memahami karya kesenian."
		icon = "🎨"
	elif bname == "Akademis3":
		stat_name = "Olahraga"
		current_val = s_data.get("akademis3", 0)
		desc = "Menunjukkan tingkat kemampuan fisik dan kebugaran tubuh murid dalam bidang olahraga."
		icon = "⚽"

	var tex_icon = _get_stat_icon(bname)
	if tex_icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = tex_icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(80, 80)
		hbox.add_child(icon_rect)
	else:
		var icon_lbl := Label.new()
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", 72)
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(icon_lbl)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_vbox)

	var type_lbl := Label.new()
	type_lbl.text = category_name
	type_lbl.add_theme_font_size_override("font_size", 30)
	type_lbl.add_theme_color_override("font_color", Color(0, 0, 0, 0.4))
	type_lbl.add_theme_constant_override("outline_size", 0)
	title_vbox.add_child(type_lbl)

	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 58)
	name_lbl.add_theme_color_override("font_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.1))
	title_vbox.add_child(name_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 52)
	close_btn.add_theme_color_override("font_color", Color.BLACK)
	close_btn.custom_minimum_size = Vector2(76, 76)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(close_btn)

	var body := PanelContainer.new()
	if popup_inner_tex:
		var body_tex := StyleBoxTexture.new()
		body_tex.texture = popup_inner_tex
		body_tex.texture_margin_left = 32
		body_tex.texture_margin_right = 32
		body_tex.texture_margin_top = 24
		body_tex.texture_margin_bottom = 28
		body.add_theme_stylebox_override("panel", body_tex)
	else:
		var body_bg := StyleBoxFlat.new()
		body_bg.bg_color = Color(0, 0, 0, 0.05)
		body_bg.content_margin_left = 32
		body_bg.content_margin_top = 24
		body_bg.content_margin_right = 32
		body_bg.content_margin_bottom = 28
		body.add_theme_stylebox_override("panel", body_bg)
	vbox.add_child(body)
	
	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 24)
	body.add_child(body_vbox)

	var num_lbl := Label.new()
	num_lbl.text = "%s: %d / %d" % [stat_name.to_upper(), int(current_val), int(max_val)]
	num_lbl.add_theme_font_size_override("font_size", 60)
	num_lbl.add_theme_color_override("font_color", _get_bar_color(bname))
	num_lbl.add_theme_constant_override("outline_size", 2)
	num_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.2))
	body_vbox.add_child(num_lbl)
	
	# Create a visual progress bar for the popup
	var popup_bar := ProgressBar.new()
	popup_bar.custom_minimum_size = Vector2(0, 64)
	popup_bar.max_value = max_val
	popup_bar.value = current_val
	popup_bar.show_percentage = false
	
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0, 0, 0, 0.1)
	pb_bg.corner_radius_top_left = 16
	pb_bg.corner_radius_top_right = 16
	pb_bg.corner_radius_bottom_left = 16
	pb_bg.corner_radius_bottom_right = 16
	popup_bar.add_theme_stylebox_override("background", pb_bg)
	
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = _get_bar_color(bname)
	pb_fill.corner_radius_top_left = 16
	pb_fill.corner_radius_top_right = 16
	pb_fill.corner_radius_bottom_left = 16
	pb_fill.corner_radius_bottom_right = 16
	popup_bar.add_theme_stylebox_override("fill", pb_fill)
	
	body_vbox.add_child(popup_bar)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 40)
	desc_lbl.add_theme_color_override("font_color", Color(0.14, 0.09, 0.04))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_constant_override("line_spacing", 12)
	body_vbox.add_child(desc_lbl)

	await get_tree().process_frame
	if not is_instance_valid(popup):
		return
	var ph: float = popup.size.y
	popup.position = Vector2((vp.x - popup.size.x) * 0.5, vp.y)

	var tw1 := create_tween()
	tw1.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw1.tween_property(popup, "position:y", vp.y - ph - 36.0, 0.36)

	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_LINEAR)
	tw2.tween_property(overlay, "color", Color(0, 0, 0, 0.58), 0.22)

	var close_fn = func(): _close_trait_popup(canvas, overlay, popup, Callable())
	close_btn.pressed.connect(close_fn)
	overlay.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_close_trait_popup(canvas, overlay, popup, Callable())
	)
func _create_trait_badge(kertas: Control, node_name: String, type: String, badge_text: String, s_data: Dictionary) -> void:
	var btn = kertas.get_node_or_null(node_name)
	if not btn or not btn is Button:
		return

	btn.text = badge_text
	
	var badge_color := color_quirk_badge if type == "quirk" else color_persona_badge

	for state in ["normal", "hover", "pressed", "focus"]:
		if badge_bg_tex:
			var s_tex := StyleBoxTexture.new()
			s_tex.texture = badge_bg_tex
			s_tex.texture_margin_left = 45
			s_tex.texture_margin_right = 45
			s_tex.texture_margin_top = 10
			s_tex.texture_margin_bottom = 10
			s_tex.modulate_color = badge_color
			btn.add_theme_stylebox_override(state, s_tex)
		else:
			var s := StyleBoxFlat.new()
			s.bg_color = badge_color
			s.set_corner_radius_all(40)
			s.shadow_color  = Color(0, 0, 0, 0.30)
			s.shadow_size   = 6
			s.shadow_offset = Vector2(0, 3)
			btn.add_theme_stylebox_override(state, s)

	btn.pivot_offset = btn.size / 2.0

	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_btn_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))
	var trait_name: String = s_data.get(type, "")
	if not btn.pressed.is_connected(_on_trait_btn_pressed):
		btn.pressed.connect(_on_trait_btn_pressed.bind(kertas, type, trait_name))

	var anim_delay = randf_range(0.4, 0.8) if type == "quirk" else randf_range(1.2, 1.6)
	_start_button_wiggle(btn, anim_delay, "medium")
		
 
func _start_button_wiggle(btn: Control, delay: float = 0.0, wiggle_type: String = "small") -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	
	# Kill existing wiggle tween if it exists on this button to prevent duplicates
	if btn.has_meta("wiggle_tween"):
		var old_tw = btn.get_meta("wiggle_tween")
		if is_instance_valid(old_tw):
			old_tw.kill()

	var tw := create_tween().set_loops()
	btn.set_meta("wiggle_tween", tw)
	
	if delay > 0:
		tw.tween_interval(delay)
	
	if wiggle_type == "big":
		tw.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.2)
		tw.tween_property(btn, "rotation_degrees", 15.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -15.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 10.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -10.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 0.0, 0.1)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
		tw.tween_interval(2.0)
	elif wiggle_type == "medium":
		tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.2)
		tw.tween_property(btn, "rotation_degrees", 8.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -8.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 0.0, 0.1)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
		tw.tween_interval(3.5)
	else:
		tw.tween_property(btn, "rotation_degrees", 5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 0.0, 0.1)
		tw.tween_interval(2.0)

# ================= TRAIT POPUP =================

func _show_trait_popup(kertas: Control, type: String, name: String, desc: String, on_close: Callable = Callable()) -> void:
	if _active_popup and is_instance_valid(_active_popup):
		return  # already open

	var vp: Vector2 = get_viewport_rect().size
	var is_quirk := (type == "quirk")
	var accent := Color(0.04, 0.56, 0.68) if is_quirk else Color(0.48, 0.13, 0.78)

	var canvas := CanvasLayer.new()
	canvas.name = "PopupCanvas"
	canvas.layer = 100
	kertas.add_child(canvas)

	# Full-screen dim overlay 
	var overlay := ColorRect.new()
	overlay.name = "TraitOverlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	_active_popup = canvas

	# ── Popup panel ──
	var popup := PanelContainer.new()
	popup.name = "TraitPopupPanel"
	var panel_w := vp.x * 0.94
	popup.custom_minimum_size = Vector2(panel_w, 0)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.97, 0.96, 0.93)
	bg.corner_radius_top_left    = 30
	bg.corner_radius_top_right   = 30
	bg.corner_radius_bottom_left = 22
	bg.corner_radius_bottom_right= 22
	bg.content_margin_left   = 0
	bg.content_margin_top    = 0
	bg.content_margin_right  = 0
	bg.content_margin_bottom = 0
	popup.add_theme_stylebox_override("panel", bg)
	overlay.add_child(popup)
	
	# Hide navigation arrows to prevent accidental sliding
	if next_kanan: next_kanan.hide()
	if next_kiri: next_kiri.hide()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	popup.add_child(vbox)

	# ── Colored header ──
	var header := PanelContainer.new()
	var hdr_bg := StyleBoxFlat.new()
	hdr_bg.bg_color = accent
	hdr_bg.corner_radius_top_left    = 30
	hdr_bg.corner_radius_top_right   = 30
	hdr_bg.content_margin_left   = 28
	hdr_bg.content_margin_top    = 22
	hdr_bg.content_margin_right  = 18
	hdr_bg.content_margin_bottom = 22
	header.add_theme_stylebox_override("panel", hdr_bg)
	vbox.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	header.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "⚡" if is_quirk else "🌟"
	icon_lbl.add_theme_font_size_override("font_size", 72)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_vbox)

	var type_lbl := Label.new()
	type_lbl.text = "QUIRK" if is_quirk else "PERSONA"
	type_lbl.add_theme_font_size_override("font_size", 30)
	type_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	type_lbl.add_theme_constant_override("outline_size", 3)
	type_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	title_vbox.add_child(type_lbl)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 58)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_constant_override("outline_size", 5)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_vbox.add_child(name_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 52)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.custom_minimum_size = Vector2(76, 76)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(close_btn)

	# ── Body ──
	var body := PanelContainer.new()
	var body_bg := StyleBoxFlat.new()
	body_bg.bg_color = Color(0, 0, 0, 0)
	body_bg.content_margin_left   = 32
	body_bg.content_margin_top    = 24
	body_bg.content_margin_right  = 32
	body_bg.content_margin_bottom = 28
	body.add_theme_stylebox_override("panel", body_bg)
	vbox.add_child(body)

	var desc_lbl := Label.new()
	desc_lbl.text = "💡  EFEK GAMEPLAY:\n" + desc
	desc_lbl.add_theme_font_size_override("font_size", 40)
	desc_lbl.add_theme_color_override("font_color", Color(0.14, 0.09, 0.04))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_constant_override("line_spacing", 12)
	body.add_child(desc_lbl)

	# ── Slide-up animation ──
	await get_tree().process_frame
	if not is_instance_valid(popup):
		return
	var pw := popup.size.x
	var ph := popup.size.y
	popup.position = Vector2((vp.x - pw) * 0.5, vp.y)

	var tw1 := create_tween()
	tw1.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw1.tween_property(popup, "position:y", vp.y - ph - 36, 0.36)

	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_LINEAR)
	tw2.tween_property(overlay, "color", Color(0, 0, 0, 0.58), 0.22)

	var close_fn = func(): _close_trait_popup(canvas, overlay, popup, on_close)
	close_btn.pressed.connect(close_fn)
	overlay.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or \
		   (ev is InputEventScreenTouch and ev.pressed):
			_close_trait_popup(canvas, overlay, popup, on_close)
	)

func _close_trait_popup(canvas: CanvasLayer, overlay: Control, popup: Control, on_close: Callable = Callable()) -> void:
	if not is_instance_valid(canvas) or _active_popup != canvas:
		return
	
	# Mark as closing immediately to prevent double-calls
	_active_popup = null
	
	var vp := get_viewport_rect().size
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if is_instance_valid(popup):
		tw.tween_property(popup, "position:y", vp.y, 0.26)
	if is_instance_valid(overlay):
		tw.tween_property(overlay, "color", Color(0, 0, 0, 0.0), 0.22)
	tw.chain().tween_callback(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
		if _active_popup == canvas:
			_active_popup = null
		if on_close.is_valid():
			on_close.call()
			
		# Restore navigation arrows
		if tutorial_active:
			if next_kanan: next_kanan.show()
			if next_kiri: next_kiri.hide()
		else:
			_update_nav_buttons(current_page)
	)

# ================= TUTORIAL BADGE GATING =================

func _arm_tutorial_badge(step_index: int) -> void:
	# Clean up any previous connection
	if _tutorial_badge_cleanup.is_valid():
		_tutorial_badge_cleanup.call()
	_tutorial_badge_cleanup = func(): pass

	var badge_name := "KutuBuku" if step_index == 8 else "KutuBuku2"
	var badge_type := "quirk"   if step_index == 8 else "persona"
	var badge = get_node_or_null("KertasMurid1/" + badge_name)

	if not badge or not badge is Button:
		# Badge not found — fall back to click-anywhere
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		return

	var s_data    = student_data_list[0]
	var trait_key: String = s_data.get("quirk" if badge_type == "quirk" else "persona", "")
	var desc: String
	if badge_type == "quirk":
		desc = QUIRK_DESCRIPTIONS.get(trait_key, "Tidak ada info.")
	else:
		desc = PERSONA_DESCRIPTIONS.get(trait_key, "Tidak ada info.")

	var handler := func():
		# The badge's own pressed handler runs first and sets _active_popup synchronously.
		if is_instance_valid(_active_popup):
			_next_step() # Advance to the "Highlight popup" step
			_active_popup.tree_exited.connect(func(): _next_step()) # Advance when popup closes

	badge.pressed.connect(handler)
	_tutorial_badge_cleanup = func():
		if is_instance_valid(badge) and badge.pressed.is_connected(handler):
			badge.pressed.disconnect(handler)

# ──────────────────────────────────────────────────────────────────────────────

func _on_belajar_pressed():
	if belajar_button:
		_animate_button_click_bounce(belajar_button)
	_sync_student_data_from_ui()
	GameState.returned_from_student_card = true
	GameState.approved_students.clear()
	for i in approved.size():
		if approved[i]:
			GameState.approved_students.append(student_data_list[i])

	if GameState.approved_students.is_empty():
		match GameState.current_grade:
			7:
				GameState.approved_students = [student_data_list[0], student_data_list[1]]
			8:
				GameState.approved_students = [student_data_list[0], student_data_list[1], student_data_list[2]]
			9:
				GameState.approved_students = [student_data_list[0], student_data_list[1], student_data_list[2], student_data_list[3]]

	GameState.selected_student = GameState.approved_students[0]
	
	if GameState.current_grade == 7:
		GameState.grade7_student_ids.clear()
		for approved_s in GameState.approved_students:
			GameState.grade7_student_ids.append(approved_s.get("id"))
			
	Transition.change_scene("res://Scenes/Lobby/loby.tscn")

# ================= STAMP APPROVE / BATAL =================

func _apply_button_texture(btn: Control, tex: Texture2D, override_font_size: int = -1, push_text_left: float = 0.0, f_color: Color = Color.WHITE) -> void:
	if not btn or not tex: return
	
	if btn is Button:
		if override_font_size > 0:
			btn.add_theme_font_size_override("font_size", override_font_size)
		btn.add_theme_color_override("font_color", f_color)
		btn.add_theme_color_override("font_hover_color", f_color)
		btn.add_theme_color_override("font_pressed_color", f_color)

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.texture_margin_left = 16
		s.texture_margin_right = 16
		s.texture_margin_top = 12
		s.texture_margin_bottom = 12
		s.content_margin_left = push_text_left
		
		if state == "hover":
			s.modulate_color = Color(1.1, 1.1, 1.1)
		elif state == "pressed":
			s.modulate_color = Color(0.9, 0.9, 0.9)
		elif state == "disabled":
			s.modulate_color = Color(0.5, 0.5, 0.5)
			
		btn.add_theme_stylebox_override(state, s)

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
	
	# Pause wiggle tween if running
	if btn.has_meta("wiggle_tween"):
		var tw = btn.get_meta("wiggle_tween")
		if is_instance_valid(tw):
			tw.pause()
			
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(btn, "scale", Vector2(1.12, 1.12), 0.15)
	tw.parallel().tween_property(btn, "rotation_degrees", 0.0, 0.15)

func _on_btn_mouse_exited(btn: Control):
	if not is_instance_valid(btn):
		return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Resume wiggle tween if paused
	tw.chain().tween_callback(func():
		if is_instance_valid(btn) and btn.has_meta("wiggle_tween"):
			var wiggle = btn.get_meta("wiggle_tween")
			if is_instance_valid(wiggle):
				wiggle.play()
	)

func _animate_button_click_bounce(btn: Control, flash_color: Color = Color.TRANSPARENT) -> Tween:
	if not is_instance_valid(btn):
		return null
	btn.pivot_offset = btn.size / 2.0
	
	# Scale animation
	var scale_tw = create_tween()
	scale_tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tw.tween_property(btn, "scale", Vector2(0.8, 1.25), 0.08)
	scale_tw.tween_property(btn, "scale", Vector2(1.18, 0.85), 0.1)
	scale_tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	
	# Color flash animation
	if flash_color != Color.TRANSPARENT:
		var orig = btn.modulate
		btn.modulate = flash_color
		var color_tw = create_tween()
		color_tw.tween_property(btn, "modulate", orig, 0.3).set_delay(0.05)
		
	return scale_tw

func _on_approve_pressed(page_index: int):
	print("DEBUG approve ditekan, tutorial_active: ", tutorial_active)
	if tutorial_active or is_animating:
		return
	if approved[page_index]:
		return
	if approved_count >= MAX_APPROVE:
		print("Batas approve tercapai, tidak bisa approve murid lain")
		return

	var approve_btn = kertas_murid[page_index].get_node_or_null("Aprove")
	var batal_btn = kertas_murid[page_index].get_node_or_null("Batal")
	if approve_btn:
		_animate_button_click_bounce(approve_btn, Color(0.2, 0.9, 0.3))

	approved[page_index] = true
	approved_count += 1
	_play_stamp_effect()

	# Give a brief moment for the flash animation to be visible before swapping buttons
	await get_tree().create_timer(0.25).timeout

	if approve_btn:
		approve_btn.visible = false
	if batal_btn:
		batal_btn.visible = true
		_animate_button_click_bounce(batal_btn)

	_update_approve_buttons_state()
	_update_nav_buttons(current_page)

func _on_batal_pressed(page_index: int):
	if tutorial_active or is_animating:
		return
	if not approved[page_index]:
		return

	var approve_btn = kertas_murid[page_index].get_node_or_null("Aprove")
	var batal_btn = kertas_murid[page_index].get_node_or_null("Batal")
	if batal_btn:
		_animate_button_click_bounce(batal_btn, Color(0.9, 0.2, 0.2))

	approved[page_index] = false
	approved_count = max(0, approved_count - 1)
	_play_erase_stamp_effect()

	# Give a brief moment for the flash animation to be visible before swapping buttons
	await get_tree().create_timer(0.25).timeout

	if batal_btn:
		batal_btn.visible = false
	if approve_btn:
		approve_btn.visible = true
		_animate_button_click_bounce(approve_btn)

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
	stamp.pivot_offset = stamp.size / 2.0
	stamp.scale = Vector2(2.5, 2.5)
	stamp.modulate.a = 0.0
	stamp.rotation_degrees = randf_range(-12.0, 12.0)

	if stamp_tween and stamp_tween.is_running():
		stamp_tween.kill()

	stamp_tween = create_tween()
	stamp_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	stamp_tween.tween_property(stamp, "scale", Vector2(0.9, 1.15), 0.18)
	stamp_tween.parallel().tween_property(stamp, "modulate:a", 1.0, 0.1)
	stamp_tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	stamp_tween.tween_property(stamp, "scale", Vector2(1.05, 0.95), 0.1)
	stamp_tween.tween_property(stamp, "scale", Vector2(1.0, 1.0), 0.08)

func _play_erase_stamp_effect():
	if not stamp or not stamp.visible:
		return

	if stamp_tween and stamp_tween.is_running():
		stamp_tween.kill()

	stamp.pivot_offset = stamp.size / 2.0
	var start_rot = stamp.rotation_degrees

	stamp_tween = create_tween()
	stamp_tween.set_parallel(true)

	# Marker eraser back-and-forth wipe motion (left then right)
	var wipe_seq = create_tween()
	wipe_seq.tween_property(stamp, "rotation_degrees", start_rot - 12.0, 0.05).set_trans(Tween.TRANS_SINE)
	wipe_seq.tween_property(stamp, "rotation_degrees", start_rot + 12.0, 0.06).set_trans(Tween.TRANS_SINE)
	wipe_seq.tween_property(stamp, "rotation_degrees", start_rot - 6.0, 0.05).set_trans(Tween.TRANS_SINE)
	wipe_seq.tween_property(stamp, "rotation_degrees", start_rot, 0.05).set_trans(Tween.TRANS_SINE)

	# Fade out & horizontal eraser friction scale
	stamp_tween.tween_property(stamp, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_OUT)
	stamp_tween.tween_property(stamp, "scale:x", 1.25, 0.11).set_ease(Tween.EASE_OUT)
	stamp_tween.tween_property(stamp, "scale:x", 0.85, 0.11).set_ease(Tween.EASE_IN)

	await stamp_tween.finished
	stamp.visible = false
	stamp.scale = Vector2(1.0, 1.0)
	stamp.rotation_degrees = 0.0
	stamp.modulate.a = 1.0



func _on_trait_btn_pressed(kertas: Control, type: String, trait_name: String):
	if tutorial_active:
		if GameState.current_grade == 7:
			if type == "quirk" and current_step != 8:
				return
			if type == "persona" and current_step != 11:
				return
		else:
			return
			
	if type == "quirk":
		var desc = QUIRK_DESCRIPTIONS.get(trait_name, "Tidak ada info.")
		_show_trait_popup(kertas, "quirk", trait_name, desc)
	else:
		var desc = PERSONA_DESCRIPTIONS.get(trait_name, "Tidak ada info.")
		_show_trait_popup(kertas, "persona", trait_name, desc)
