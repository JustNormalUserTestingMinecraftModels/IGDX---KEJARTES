extends Control

## StudentCard: the player reviews the roster and approves which students
## join the class for this grade.
##
## Reached from CutScene on a new grade, and re-reached from the Lobby
## when the player taps the student button mid-grade. On approve, it
## writes GameState.returned_from_student_card = true and replaces
## GameState.approved_students wholesale (Array[Dictionary], the UI-named
## keys documented on GameState.gd) -- never a partial update. Grade 7's
## approval flow force-fills a minimum roster if the player approves too
## few (see the GameState.current_grade branches around
## `GameState.approved_students = [...]`).

@export_group("UI Textures (Optional Replace)")
## Currently unreferenced by this script -- appears unused.
@export var icon_magnify: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_magnify.svg")
## Icon for the "Kepribadian1" (mood) stat bar -- see _get_stat_icon().
@export var icon_mood: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_mood.svg")
## Icon for the "Kepribadian2" (energy) stat bar.
@export var icon_energy: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_energy.svg")
## Icon for the "Akademis1" (academic) stat bar.
@export var icon_akademis: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_akademis.svg")
## Icon for the "Akademis2" (seni budaya) stat bar.
@export var icon_seni: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_seni.svg")
## Icon for the "Akademis3" (olahraga) stat bar.
@export var icon_olahraga: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_olahraga.svg")

# ================= TRAIT DESCRIPTIONS =================
# QUIRK_DESCRIPTIONS / PERSONA_DESCRIPTIONS now live on StudentCardView;
# use StudentCardView.quirk_description()/persona_description().

# ================= TOKENS =================

## The project's modal scrim. `alpha_scale` of 0 gives the same hue at
## zero opacity, which is what both popup fades tween from and back to --
## tweening between two different hues would flash mid-fade.
func _scrim_color(alpha_scale: float = 1.0) -> Color:
	var c := DesignTokens.load_default().scrim_color()
	c.a *= alpha_scale
	return c


# ================= ACTIVE POPUP & TUTORIAL BADGE =================
var _active_popup: Node = null
var _tutorial_badge_cleanup: Callable

# --- Tutorial ---
@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea

@export_group("Tutorial")
## Edit this array in the Inspector to customize each tutorial step.
@export var tutorial_steps: Array[TutorialStepData] = []

const TutorialArrow = preload("res://Scripts/TutorialArrow.gd")

## Shared onboarding coach-mark (title/separator/body/separator/prompt on
## the Card surface). This screen's per-step tutorial keeps StudentCard's
## shipped 0.92/1000 width and zero content margin -- the component
## defaults -- and only overrides nothing.
@export var tutorial_panel_scene: PackedScene = preload("res://Scenes/UI/TutorialPanel.tscn")

var current_step := 0
var tutorial_active := true
var _tutorial_panel: TutorialPanel
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
			if not approve_btn.pressed.is_connected(_on_approve_pressed.bind(i)):
				approve_btn.pressed.connect(_on_approve_pressed.bind(i))

		var batal_btn = kertas_murid[i].get_node_or_null("Batal")
		if batal_btn:
			batal_btn.set_meta("original_position", batal_btn.position)
			_setup_button_juice(batal_btn)
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
	belajar_button.visible = false

	# Populate UI with data from script (overrides placeholder data in .tscn)
	_populate_ui_from_data()

	_sync_student_data_from_ui()

	# Every kertas_murid card defaults to visible in the .tscn; without this
	# they all render stacked on top of each other for one frame before
	# _end_tutorial()/_show_page() first runs, which is what made a card
	# (Shinta's) appear to glitch in "behind" the others on first entry.
	_show_page(current_page)

	if GameState.tutorials_bypassed:
		tutorial_active = false
		color_rect.hide()
	else:
		_show_step(0)
	AudioDirector.play_bgm_playlist(&"lobby")

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




## Instantiates the shared TutorialPanel with StudentCard's shipped look
## (its component defaults: 0.92/1000 width, no content margin, H1Label
## title, TitleLabel body/prompt). Keeps the three label vars pointed at
## the panel's own nodes so the rest of this file's per-step text logic
## (_show_step, _start_prompt_blink) is unchanged.
func _build_tutorial_panel():
	_tutorial_panel = tutorial_panel_scene.instantiate()
	_tutorial_panel.name = "TutorialPanel"

	# The panel hasn't entered the tree yet (it's appended below), so its
	# @onready title_label/body_label/prompt_label aren't live -- get_node
	# still works because instantiate() built the subtree.
	_tutorial_title_label = _tutorial_panel.get_node("Margin/Layout/TitleLabel")
	_tutorial_body_label = _tutorial_panel.get_node("Margin/Layout/BodyLabel")
	_tutorial_prompt_label = _tutorial_panel.get_node("Margin/Layout/PromptLabel")
	_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"

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
		AudioDirector.play_sfx(&"swipe")
		var old_page = current_page
		current_page += 1
		_transition_page(old_page, current_page, -1)

func _on_next_kiri_pressed():
	if tutorial_active or is_animating:
		return
	if current_page > 0:
		AudioDirector.play_sfx(&"swipe")
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

	# Pre-hide the new page's rows before the card itself fades in, so they
	# don't ride the card's own modulate up to fully visible only to be
	# yanked back to invisible a moment later when _stagger_in_card's
	# pop_in() takes over -- that jump was the "not fully invisible" glitch.
	_hide_card_rows(new_index)

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

	_stagger_in_card(new_index)
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

## The rows of one student page, top to bottom, for staggered entry.
## Order matters: Juice.stagger_in delays each node by one stagger_step,
## so this list is what the player's eye follows down the card.
const CARD_ROW_ORDER := ["BioPanel", "IconAkademis1", "Akademis1",
	"IconAkademis2", "Akademis2", "IconAkademis3", "Akademis3",
	"IconKepribadian1", "Kepribadian1", "IconKepribadian2", "Kepribadian2",
	"KutuBuku", "KutuBuku2"]


## Sets every row of the given page to the same invisible state pop_in()
## starts from, ahead of time -- see the call sites for why.
func _hide_card_rows(index: int) -> void:
	if index < 0 or index >= kertas_murid.size():
		return
	var kertas: Node = kertas_murid[index]
	for row_name in CARD_ROW_ORDER:
		var node = kertas.get_node_or_null(row_name)
		if node is Control:
			node.modulate.a = 0.0
			node.scale = Vector2(0.82, 0.82)


## Reveal the newly-shown page's contents row by row instead of having
## the whole card appear at once. Only ever called for a page that is
## already visible and settled, never mid page-transition.
func _stagger_in_card(index: int) -> void:
	if index < 0 or index >= kertas_murid.size():
		return
	var kertas: Node = kertas_murid[index]
	var rows: Array = []
	for row_name in CARD_ROW_ORDER:
		var node = kertas.get_node_or_null(row_name)
		if node != null:
			rows.append(node)
	Juice.stagger_in(rows)


func _show_page(index: int):
	for i in kertas_murid.size():
		kertas_murid[i].visible = (i == index)

	_stagger_in_card(index)
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

		StudentCardView.populate(kertas, student_data_list[i],
			_on_bar_gui_input, _on_btn_mouse_entered, _on_btn_mouse_exited,
			_on_trait_btn_pressed)

var student_data_list = [
	{
		"id": 1,
		"name": "Marcel",
		"portrait": "res://Assets/Images/MuridPotrait/Marcel.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_marcel.png",
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
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki",
		"jenis_kelamin": "Laki - Laki",
		"tanggal_lahir": "20 September"
	},
	{
		"id": 2,
		"name": "Doni",
		"portrait": "res://Assets/Images/MuridPotrait/Doni.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_doni.png",
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
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki",
		"jenis_kelamin": "Laki - Laki",
		"tanggal_lahir": "9 Maret"
	},
	{
		"id": 3,
		"name": "Andi",
		"portrait": "res://Assets/Images/MuridPotrait/Andi.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_andi.png",
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
		"profil": "Agama: Katolik\nJenis Kelamin: Laki-laki",
		"jenis_kelamin": "Laki - Laki",
		"tanggal_lahir": "25 Januari"
	},
	{
		"id": 4,
		"name": "Citra",
		"portrait": "res://Assets/Images/MuridPotrait/Citra.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_citra.png",
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
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan",
		"jenis_kelamin": "Perempuan",
		"tanggal_lahir": "17 Desember"
	},
	{
		"id": 5,
		"name": "Shinta",
		"portrait": "res://Assets/Images/MuridPotrait/Shinta.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_shinta.png",
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
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan",
		"jenis_kelamin": "Perempuan",
		"tanggal_lahir": "4 Juni"
	},
	{
		"id": 6,
		"name": "Thea",
		"portrait": "res://Assets/Images/MuridPotrait/Thea.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_thea.png",
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
		"profil": "Agama: Katolik\nJenis Kelamin: Perempuan",
		"jenis_kelamin": "Perempuan",
		"tanggal_lahir": "15 Mei"
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

## The accent colour a given bar wears, from DesignTokens via StatInfo.
## Affects: the tint of the bars drawn on the card itself.
func _get_bar_color(bname: String) -> Color:
	return DesignTokens.load_default().category_color(StatInfo.token_category(bname))

func _on_bar_gui_input(ev: InputEvent, kertas: Control, bname: String, s_data: Dictionary) -> void:
	if tutorial_active or is_animating or _active_popup != null:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or \
	   (ev is InputEventScreenTouch and ev.pressed):
		_show_bar_popup(kertas, bname, s_data)

## The scene the stat-detail modal is authored in. Exported so the popup can
## be restyled or swapped without touching this screen.
@export var stat_popup_scene: PackedScene = preload("res://Scenes/UI/StatDetailPopup.tscn")

## Open the stat-detail modal for one bar.
##
## Affects: adds a CanvasLayer child to `kertas`, hides the page-turn arrows
## while it is open, and sets `_active_popup` so a second tap is ignored.
## No longer a coroutine -- StatDetailPopup.open() owns the reveal.
func _show_bar_popup(kertas: Control, bname: String, s_data: Dictionary) -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		return
	if next_kanan: next_kanan.hide()
	if next_kiri: next_kiri.hide()

	var popup: StatDetailPopup = stat_popup_scene.instantiate()
	_active_popup = popup
	kertas.add_child(popup)
	popup.configure(bname, s_data, _get_stat_icon(bname))
	popup.closed.connect(_on_detail_popup_closed)
	popup.open()

## Clear the guard and restore the page-turn arrows once a modal finishes
## its exit animation. Shared by the stat and trait popups.
##
## During the onboarding tutorial only forward navigation is allowed, so the
## restore forces next_kanan visible / next_kiri hidden instead of asking
## _update_nav_buttons what the current page would normally show.
func _on_detail_popup_closed() -> void:
	_active_popup = null
	if tutorial_active:
		if next_kanan: next_kanan.show()
		if next_kiri: next_kiri.hide()
	else:
		_update_nav_buttons(current_page)
# ================= TRAIT POPUP =================

## The scene the trait-detail modal is authored in.
@export var trait_popup_scene: PackedScene = preload("res://Scenes/UI/TraitDetailPopup.tscn")

## Open the quirk/persona detail modal.
##
## Affects: adds a CanvasLayer child to `kertas`, hides the page-turn arrows
## while it is open, and sets `_active_popup`. `on_close` is invoked after
## the exit animation -- StudentCard's onboarding tutorial chains its next
## step off it.
func _show_trait_popup(kertas: Control, type: String, name: String,
		desc: String, on_close: Callable = Callable()) -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		return
	if next_kanan: next_kanan.hide()
	if next_kiri: next_kiri.hide()

	var popup: TraitDetailPopup = trait_popup_scene.instantiate()
	_active_popup = popup
	kertas.add_child(popup)
	popup.configure(type, name, desc)
	popup.closed.connect(func() -> void:
		_active_popup = null
		if tutorial_active:
			if next_kanan: next_kanan.show()
			if next_kiri: next_kiri.hide()
		else:
			_update_nav_buttons(current_page)
		if on_close.is_valid():
			on_close.call())
	popup.open()

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
		desc = StudentCardView.quirk_description(trait_key)
	else:
		desc = StudentCardView.persona_description(trait_key)
	if desc == "":
		desc = "Tidak ada info."

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

# No explicit SFX: UIPolish auto-plays `tap` on press and Transition
# plays `whoosh` on the scene change. Adding a third would stack.
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

	# Freeze each student's starting skills as the permanent roster baseline.
	# GameState.reset_roster_for_new_grade() rebases toward these every grade;
	# they are never erased. base_akademis* (set later by
	# initialize_grade_targets) is the per-grade cache and IS erased on reset.
	for _s in GameState.approved_students:
		_s["roster_base_akademis1"] = float(_s.get("akademis1", 50.0))
		_s["roster_base_akademis2"] = float(_s.get("akademis2", 50.0))
		_s["roster_base_akademis3"] = float(_s.get("akademis3", 50.0))

	GameState.selected_student = GameState.approved_students[0]
	
	if GameState.current_grade == 7:
		GameState.grade7_student_ids.clear()
		for approved_s in GameState.approved_students:
			GameState.grade7_student_ids.append(approved_s.get("id"))
			
	Transition.change_scene("res://Scenes/Lobby/loby.tscn")

# ================= STAMP APPROVE / BATAL =================

# _apply_button_texture() lived here. It painted a placeholder SVG
# nine-patch plus per-state modulate and per-node font overrides onto
# Aprove / Batal / BelajarButton at runtime. All three now carry a theme
# variation (SuccessButton / DangerButton / PrimaryButton) set in the
# scene, which supplies the same four states -- plus focus and disabled
# -- from the baked theme.


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
	if tutorial_active or is_animating:
		return
	if approved[page_index]:
		return
	if approved_count >= MAX_APPROVE:
		AudioDirector.play_sfx(&"error")
		print("Batas approve tercapai, tidak bisa approve murid lain")
		return

	var approve_btn = kertas_murid[page_index].get_node_or_null("Aprove")
	var batal_btn = kertas_murid[page_index].get_node_or_null("Batal")
	AudioDirector.play_sfx(&"stamp")
	if approve_btn:
		_animate_button_click_bounce(approve_btn,
			DesignTokens.load_default().state_success)

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
	AudioDirector.play_sfx(&"unstamp")
	if batal_btn:
		_animate_button_click_bounce(batal_btn,
			DesignTokens.load_default().state_danger)

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
		var desc = StudentCardView.quirk_description(trait_name)
		_show_trait_popup(kertas, "quirk", trait_name, desc if desc != "" else "Tidak ada info.")
	else:
		var desc = StudentCardView.persona_description(trait_name)
		_show_trait_popup(kertas, "persona", trait_name, desc if desc != "" else "Tidak ada info.")
