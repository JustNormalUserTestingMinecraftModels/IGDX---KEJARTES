extends Control

## Atur Jadwal: the player assigns each approved student one activity per
## school day, then commits the week.
##
## Reached from the Lobby. On commit it fills GameState.day_schedules --
## a dictionary keyed by student id, each holding five category strings --
## and hands off to StudentList and then SchoolDay, which simulate it.
##
## Categories are Akademis / SeniBudaya / Olahraga / Istirahat / Wirausaha.
## Two legacy spellings are normalised on the way in: "Akademik" becomes
## "Akademis" and "DayOff" becomes "Istirahat". A student whose energy has
## fallen to 5 or below is forced to "Izin", which is Istirahat under a
## different label -- the player cannot override that.
##
## Affects: GameState.day_schedules only. It never touches stats; SchoolDay
## does that when the week runs.

signal _holiday_dismissed

## Id of the student whose stat rows were last staggered in. Guards
## _stagger_stat_rows() so it only plays on screen entry or an actual
## student switch -- _update_student_display() also runs on every activity
## assignment, and an unconditional stagger there would re-fade the whole
## stat panel on every tap and fight the per-bar pop. The very first display
## is handled separately by _has_staggered_once below, not by this -1
## initial value.
var _last_staggered_student_id = -1

## True once _update_student_display() has staggered at least once.
## Needed because student.get("id", -1) shares the -1 fallback with
## _last_staggered_student_id's initial value: two different students that
## both happen to lack an "id" key would compare equal (-1 == -1) and
## silently skip the stagger on the switch between them. This sentinel is
## independent of whatever value "id" holds, so that collision can't happen.
var _has_staggered_once := false

@export_group("Calendar Display")
## Icon shown next to the current date in the TanggalContainer header.
@export var calendar_icon: Texture2D

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

@onready var ak1_bar = $BGStat/Akademis1
@onready var ak2_bar = $BGStat/Akademis2
@onready var ak3_bar = $BGStat/Akademis3
@onready var kp1_bar = $BGStat/Kepribadian1
@onready var kp2_bar = $BGStat/Kepribadian2

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
@onready var popup_rows = $Penjadwalan/TextureRect/Rows
@onready var popup_back_btn = $Penjadwalan/TextureRect/PopupBack

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

## Full-screen dimming backdrop shared by Peringatan and Penjadwalan. A
## &"Scrim"-variation Panel, not the old ad-hoc blur shader ColorRect.
var blur_overlay: Control

var _tokens_cache: DesignTokens

## Every preview number this screen shows now comes from Balance.gd via
## ActivityPreview. Do not reintroduce local copies -- a shadow constant
## means the tester edits Balance and the screen silently ignores it.

var penjadwalan_popup_open := false
var is_overtired_warning := false


func _get_tokens() -> DesignTokens:
	if _tokens_cache == null:
		_tokens_cache = DesignTokens.load_default()
	return _tokens_cache


func _ready():
	# Full-screen invisible click-catcher: a scale pulse would visibly
	# distort the whole overlay.
	$ColorRect/ClickArea.set_meta(Juice.NO_AUTO_JUICE, true)
	_setup_portrait_juice(select_student_button)
	_setup_back_button()
	_setup_gameplay()
	_update_tanggal_display()
	_check_and_lock_holidays()
	_create_blur_overlay()
	_update_student_display()
	_update_day_button_colors()
	_start_day_button_sway()
	AudioDirector.play_bgm_playlist(&"lobby")

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

## Wires the day/activity/start-week buttons, tints the Penjadwalan category
## buttons per DesignTokens.category_color(), and populates the tutorial.
## Category tinting for the stat bars themselves lives on each StatBar's
## `category` export in the scene, not here.
func _setup_gameplay():
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

	if GameState.tutorials_bypassed or tutorial_phase3_done:
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
			["Evaluasi Murid", "Murid ini membutuhkan bantuan agar mereka terfokuskan untuk meningkatkan apa yang ketertinggalan.", "BGStat/Akademis1,BGStat/Akademis2,BGStat/Akademis3", ""],
			["Perhatian Akademis", "Wah, sepertinya \"Nama Murid\" mempunyai nilai akademis yang bagus!", "BGStat/Akademis1", ""],
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
		alt.target_node_path = "BGStat/Akademis1"
		alt.prompt_text = ""
		tutorial_phase2_alt_step = alt

	if tutorial_phase3_steps.is_empty():
		var p3_data = [
			["Penjadwalan Berhasil", "Kerja bagus!\n\nSekarang, kita perhatikan 2 unsur yang akan berubah jikalau anda meng-input sebuah hari dengan mata pelajaran.", "", ""],
			["Warna Hari", "Pertama, hari akan berganti warna sesuai dengan warna mata pelajaran.\nBiru: Akademis, Hijau: Seni Budaya, dan Merah: Olahraga", "BGHari/Senin", ""],
			["Perubahan Stats & Energy", "Kedua, stats akan mempunyai nilai plus berdasarkan berapa pelajaran per hari yang mereka ambil!\n\nTapi Mood dan energi mereka akan berkurang!", "BGStat/Akademis1/ValueLabel,BGStat/Akademis2/ValueLabel,BGStat/Akademis3/ValueLabel,BGStat/Kepribadian1/ValueLabel,BGStat/Kepribadian2/ValueLabel", ""],
			["Siap Mengajar!", "Wow, dirimu sangat cepat untuk beradaptasi di lingkungan sekolah ini.\nKamu punya potensi besar untuk sukses mendidik lebih jauh disini!", "", ""]
		]
		for entry in p3_data:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase3_steps.append(step)

## The tutorial panel and its three labels are built at runtime (they are
## not part of the .tscn), so test_scene_has_no_theme_overrides never sees
## them -- but every color/size here still comes from DesignTokens, not a
## literal, matching the rest of the migration.
func _build_tutorial_panel():
	var viewport_size = get_viewport_rect().size
	var tokens := _get_tokens()

	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.name = "TutorialPanel"
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBox
	if custom_panel_stylebox:
		style = custom_panel_stylebox
	elif custom_panel_texture:
		var tex_style = StyleBoxTexture.new()
		tex_style.texture = custom_panel_texture
		tex_style.content_margin_left = tokens.space_lg
		tex_style.content_margin_top = tokens.space_md
		tex_style.content_margin_right = tokens.space_lg
		tex_style.content_margin_bottom = tokens.space_sm
		style = tex_style
	else:
		var flat = StyleBoxFlat.new()
		flat.bg_color = tokens.surface_overlay
		var border := tokens.currency_gold
		border.a = 0.5
		flat.border_color = border
		flat.set_border_width_all(int(tokens.outline_width) / 2)
		flat.set_corner_radius_all(tokens.radius_lg)
		flat.shadow_color = tokens.shadow_color
		flat.shadow_size = tokens.shadow_size
		flat.set_content_margin_all(tokens.space_md)
		style = flat
	_tutorial_panel.add_theme_stylebox_override("panel", style)

	var panel_width = min(viewport_size.x * 0.92, 1000)
	_tutorial_panel.custom_minimum_size = Vector2(panel_width, 0)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", tokens.space_sm)
	_tutorial_panel.add_child(vbox)

	# BarLabel: white glyph, dark rim -- reads on both the light main scene
	# and this dark overlay, which is why all three tutorial labels share
	# it instead of the light-background label variations.
	_tutorial_title_label = Label.new()
	_tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_title_label.theme_type_variation = &"BarLabel"
	vbox.add_child(_tutorial_title_label)

	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.theme_type_variation = &"BarLabel"
	_tutorial_body_label.add_theme_constant_override("line_spacing", tokens.space_xs)
	_tutorial_body_label.custom_minimum_size = Vector2(panel_width - 60, 0)
	vbox.add_child(_tutorial_body_label)

	var sep2 = HSeparator.new()
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep2)

	_tutorial_prompt_label = Label.new()
	_tutorial_prompt_label.text = "CLICK DIMANA SAJA UNTUK LANJUT"
	_tutorial_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_prompt_label.theme_type_variation = &"BarLabel"
	vbox.add_child(_tutorial_prompt_label)

	color_rect.add_child(_tutorial_panel)
	var click_idx = click_area.get_index()
	color_rect.move_child(_tutorial_panel, click_idx)

	_start_prompt_blink()
	call_deferred("_position_tutorial_panel")

func _start_prompt_blink():
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	var t := _get_tokens()
	_tutorial_prompt_label.modulate.a = 1.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 0.25, t.dur_slow) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 1.0, t.dur_slow) \
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

## Drives each BGHari day button through the DayStickyNote template API
## (set_day_name, show_empty, show_scheduled, show_holiday), which handles
## tinting and content display internally.
func _update_day_button_colors():
	var schedules = _get_current_schedules()

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
		var note := btn as DayStickyNote
		if note == null:
			continue

		note.set_day_name(day_name)

		if week_holidays.has(day_name):
			note.show_holiday(week_holidays[day_name].get("title", "Libur Nasional"))
		elif schedules.has(day_name):
			note.show_scheduled(schedules[day_name]["category"])
		else:
			note.show_empty()

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
	return count * ActivityPreview.skill_gain(category, student, GameState.current_grade)

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

## Normalizes `current` (optionally shifted by `delta`, a positive gain or
## negative loss) against `target` into a 0-100 percentage for StatBar,
## which only understands a fixed 0-100 range. This is how the preview of
## this week's pending schedule effect still reaches the bar, now that the
## bar itself has no separate ghost/goal-marker channel.
func _percent(current: float, target: float) -> float:
	if target <= 0.0:
		return 0.0
	return clampf(current / target * 100.0, 0.0, 100.0)

## pop: whether this update should play StatBar's squash-pop. Callers pass
## false during a student switch, where _stagger_stat_rows()'s stagger
## already owns the motion for the row; callers pass true (the default) for
## a same-student edit -- e.g. assigning an activity -- where there is no
## stagger and the pop is the only motion telling the player the bar moved.
func _feed_stat_bar(bar: StatBar, current: float, delta: float, target: float, pop: bool = true) -> void:
	if bar == null:
		return
	bar.set_stat(_percent(current + delta, target), true, pop)

func _update_student_display():
	if GameState.selected_student.is_empty():
		if not GameState.approved_students.is_empty():
			GameState.selected_student = GameState.approved_students[0]
		else:
			GameState.selected_student = {
					"id": 1,
					"name": "Marcel",
					"splash": "res://Assets/Images/SplashArtMurid/splash_marcel.png",
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

	# Decide whether this is a real student switch BEFORE feeding the bars.
	# The stagger and the per-bar pop both animate `scale` on the same five
	# nodes; if both fired on a switch frame, two independently-tracked
	# tweens (AnimUtils._safe_tween's dictionary vs Juice.pop_in's bare
	# create_tween()) would fight over the same property. So on a switch,
	# feed the bars WITHOUT popping (pop=false) and let the stagger own the
	# motion; on a same-student edit, feed WITH popping and skip the stagger.
	var current_id = student.get("id", -1)
	var is_switch: bool = not _has_staggered_once or current_id != _last_staggered_student_id
	var pop_bars: bool = not is_switch

	if kp1_bar:
		_feed_stat_bar(kp1_bar, student.get("kepribadian2", 50.0), -_compute_total_loss("energy_cost"), 100.0, pop_bars)
	if kp2_bar:
		_feed_stat_bar(kp2_bar, student.get("kepribadian1", 50.0), -_compute_total_loss("mood_cost"), 100.0, pop_bars)
	if ak1_bar:
		var target1 = student.get("target_akademis1", 65.0)
		_feed_stat_bar(ak1_bar, student.get("akademis1", 50.0), _compute_pending_gain("Akademis", student), target1, pop_bars)
	if ak2_bar:
		var target2 = student.get("target_akademis2", 65.0)
		_feed_stat_bar(ak2_bar, student.get("akademis2", 50.0), _compute_pending_gain("SeniBudaya", student), target2, pop_bars)
	if ak3_bar:
		var target3 = student.get("target_akademis3", 65.0)
		_feed_stat_bar(ak3_bar, student.get("akademis3", 50.0), _compute_pending_gain("Olahraga", student), target3, pop_bars)

	_update_day_button_colors()

	if is_switch:
		_has_staggered_once = true
		_last_staggered_student_id = current_id
		_stagger_stat_rows()

## Brings the five stat rows in together with their icons when the
## displayed student changes. Opacity and scale only -- the icons sit on
## the mockup's measured 126px grid and must not be moved.
func _stagger_stat_rows() -> void:
	var rows := []
	for pair in [["Akademis1", "IconAkademis1"], ["Akademis2", "IconAkademis2"],
			["Akademis3", "IconAkademis3"], ["Kepribadian2", "IconKepribadian2"],
			["Kepribadian1", "IconKepribadian1"]]:
		for node_name in pair:
			var node := get_node_or_null("BGStat/%s" % node_name)
			if node != null:
				rows.append(node)
	Juice.stagger_in(rows)

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
	var highlight := Color.WHITE
	highlight.r = 1.2
	highlight.g = 1.2
	highlight.b = 1.08
	var t := _get_tokens()
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06), t.dur_fast)
	tw.tween_property(btn, "modulate", highlight, t.dur_fast)

func _on_portrait_mouse_exited(btn: Control):
	if not is_instance_valid(btn):
		return
	var t := _get_tokens()
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), t.dur_fast)
	tw.tween_property(btn, "modulate", Color.WHITE, t.dur_fast)

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
	AudioDirector.play_sfx(&"confirm")
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
	# This case includes an incomplete schedule, so it gets the same
	# rejection feedback as the incomplete-only warning below.
	Juice.shake(peringatan)
	AudioDirector.play_sfx(&"fail")

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
	Juice.shake(peringatan)
	AudioDirector.play_sfx(&"fail")

## Full-screen &"Scrim" backdrop shared by Peringatan and Penjadwalan.
## Replaces the old blur-shader ColorRect: a plain themed Panel faded via
## modulate:a instead of a custom lod/darkness shader sweep.
func _create_blur_overlay():
	var scrim := Panel.new()
	scrim.name = "Scrim"
	scrim.theme_type_variation = &"Scrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.visible = false
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	move_child(scrim, peringatan.get_index())
	scrim.gui_input.connect(_on_blur_overlay_input)
	blur_overlay = scrim

func _show_peringatan():
	if not peringatan:
		return
	AudioDirector.play_sfx(&"popup_open")
	var t := _get_tokens()
	var warning_label: Label = $Peringatan/TextureRect/Label
	if warning_label:
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Dynamic sizing so long warning text still fits the fixed art
		# frame; no single theme variation encodes "shrink to fit".
		var text_len = warning_label.text.length()
		if text_len > 110:
			warning_label.add_theme_font_size_override("font_size", t.font_caption)
		elif text_len > 75:
			warning_label.add_theme_font_size_override("font_size", t.font_body_size)
		else:
			warning_label.add_theme_font_size_override("font_size", t.font_title)

	blur_overlay.visible = true
	blur_overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(blur_overlay, "modulate:a", 1.0, t.dur_fast)

	peringatan.show()
	Juice.pop_in(peringatan)

func _hide_peringatan():
	if not peringatan:
		return
	var t := _get_tokens()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(peringatan, "modulate:a", 0.0, t.dur_fast).set_ease(Tween.EASE_IN)
	tween.tween_property(peringatan, "scale", Vector2(0.8, 0.8), t.dur_fast).set_ease(Tween.EASE_IN)
	tween.tween_property(blur_overlay, "modulate:a", 0.0, t.dur_fast)
	tween.chain().tween_callback(func():
		peringatan.hide()
		blur_overlay.visible = false
		is_overtired_warning = false
	)

func _switch_to_flagged_student():
	if _last_overtired_student_name != "":
		for student in GameState.approved_students:
			if student.get("name", "") == _last_overtired_student_name:
				GameState.selected_student = student
				_update_student_display()
				break

func _on_peringatan_yes():
	AudioDirector.play_sfx(&"confirm")
	_hide_peringatan()
	if current_warning_mode == "energy":
		_switch_to_flagged_student()
		return
	elif current_warning_mode == "mental" or current_warning_mode == "combined":
		_proceed_start_week()
	elif current_warning_mode == "incomplete":
		_proceed_start_week()

func _on_peringatan_no():
	AudioDirector.play_sfx(&"popup_close")
	_hide_peringatan()
	_switch_to_flagged_student()

func _proceed_start_week():
	Transition.change_scene("res://Scenes/SchoolSimulation/SchoolDay.tscn")

# ================= PENJADWALAN POPUP =================

func _connect_activity_buttons():
	for row in popup_rows.get_children():
		if not (row is ActivityRow):
			continue
		if not row.pressed.is_connected(_on_activity_selected.bind(row.category)):
			row.pressed.connect(_on_activity_selected.bind(row.category))
	if popup_back_btn and not popup_back_btn.pressed.is_connected(_hide_penjadwalan_popup):
		popup_back_btn.pressed.connect(_hide_penjadwalan_popup)

func _show_penjadwalan_popup():
	if not penjadwalan_popup:
		return
	AudioDirector.play_sfx(&"popup_open")
	penjadwalan_popup_open = true
	_update_popup_stats()

	blur_overlay.visible = true
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	blur_overlay.modulate.a = 0.0
	var t := _get_tokens()
	var fade := create_tween()
	fade.tween_property(blur_overlay, "modulate:a", 1.0, t.dur_fast)

	penjadwalan_popup.show()
	Juice.pop_in(penjadwalan_popup)

func _hide_penjadwalan_popup():
	if not penjadwalan_popup:
		return
	AudioDirector.play_sfx(&"popup_close")
	penjadwalan_popup_open = false
	var t := _get_tokens()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(penjadwalan_popup, "modulate:a", 0.0, t.dur_fast).set_ease(Tween.EASE_IN)
	tween.tween_property(penjadwalan_popup, "scale", Vector2(0.8, 0.8), t.dur_fast).set_ease(Tween.EASE_IN)
	tween.tween_property(blur_overlay, "modulate:a", 0.0, t.dur_fast)
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
		var mood_cost: int = int(ActivityPreview.mood_cost(category))
		var energy_cost: int = int(ActivityPreview.energy_cost(category))
		GameState.day_schedules[student_id][GameState.selected_day] = {
			"category": category,
			"mood_cost": mood_cost,
			"energy_cost": energy_cost
		}
	_hide_penjadwalan_popup()
	_update_day_button_colors()
	# The one genuine player assignment -- pop only this note. Every other
	# caller of show_scheduled/show_holiday is a repaint (Design decision #8).
	var _assigned_note := _get_day_button(GameState.selected_day) as DayStickyNote
	if _assigned_note:
		if ActivityPreview.is_specialty(category, student):
			_assigned_note.play_specialty_match()
			AudioDirector.play_sfx(&"specialty_match")
		else:
			_assigned_note.play_assign_pop()
			AudioDirector.play_sfx(&"select")
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

## The three skill rows show progress toward that subject's target; the
## other two have no target and ignore the percentage they are handed.
func _update_popup_stats():
	var student = GameState.selected_student
	if student.is_empty():
		return
	var progress := {
		"Akademis": _percent(student.get("akademis1", 50.0), student.get("target_akademis1", 65.0)),
		"SeniBudaya": _percent(student.get("akademis2", 50.0), student.get("target_akademis2", 65.0)),
		"Olahraga": _percent(student.get("akademis3", 50.0), student.get("target_akademis3", 65.0)),
	}
	for row in popup_rows.get_children():
		if row is ActivityRow:
			row.refresh(student, GameState.current_grade, progress.get(row.category, 0.0))

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
		AudioDirector.play_sfx(&"error")
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
	AudioDirector.play_sfx(&"select")
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
					var mood_cost = int(ActivityPreview.mood_cost("Istirahat"))
					var energy_cost = int(ActivityPreview.energy_cost("Istirahat"))
					GameState.day_schedules[student_id][day_name] = {
						"category": "Istirahat",
						"mood_cost": mood_cost,
						"energy_cost": energy_cost
					}

func _show_holiday_warning(holiday_title: String) -> void:
	_holiday_active = true
	AudioDirector.play_sfx(&"popup_open")
	var tokens := _get_tokens()

	# Dimmer overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = tokens.scrim_color()
	add_child(overlay)

	# PanelContainer setup
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = tokens.surface_overlay
	var border := tokens.currency_gold
	border.a = 0.9
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(tokens.radius_lg)
	style.shadow_color = tokens.shadow_color
	style.shadow_size = tokens.shadow_size
	panel.add_theme_stylebox_override("panel", style)

	var viewport_size = get_viewport_rect().size
	var panel_width = min(viewport_size.x * 0.85, 800)
	panel.custom_minimum_size = Vector2(panel_width, 0)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", tokens.space_md)
	margin.add_theme_constant_override("margin_top", tokens.space_md)
	margin.add_theme_constant_override("margin_right", tokens.space_md)
	margin.add_theme_constant_override("margin_bottom", tokens.space_md)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", tokens.space_sm)
	margin.add_child(vbox)

	# Title Label
	var title_lbl = Label.new()
	title_lbl.text = "Hari Libur Nasional 📅"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.theme_type_variation = &"BarLabel"
	vbox.add_child(title_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Body Label
	var body_lbl = Label.new()
	body_lbl.text = "Ini merupakan hari libur nasional untuk memperingati '%s'.\n\nMaka murid tidak dapat dijadwalkan!" % holiday_title
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.theme_type_variation = &"BarLabel"
	body_lbl.add_theme_constant_override("line_spacing", tokens.space_xs)
	body_lbl.custom_minimum_size = Vector2(panel_width - 100, 0)
	vbox.add_child(body_lbl)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Prompt Label
	var prompt_lbl = Label.new()
	prompt_lbl.text = "KLIK DIMANA SAJA UNTUK LANJUT"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.theme_type_variation = &"BarLabel"
	vbox.add_child(prompt_lbl)

	overlay.add_child(panel)

	# Pulsing prompt tween
	prompt_lbl.modulate.a = 1.0
	var pulse = create_tween().set_loops()
	pulse.tween_property(prompt_lbl, "modulate:a", 0.25, tokens.dur_slow).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(prompt_lbl, "modulate:a", 1.0, tokens.dur_slow).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Centering
	await get_tree().process_frame
	var panel_size = panel.size
	panel.position = (viewport_size - panel_size) / 2.0
	panel.pivot_offset = panel_size / 2.0

	# Bounce scale-in
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(panel, "scale", Vector2(1.0, 1.0), tokens.dur_normal).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(panel, "modulate:a", 1.0, tokens.dur_fast)
	await tween_in.finished

	# Wait for click
	await _holiday_dismissed

	# Bounce scale-out
	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_property(panel, "scale", Vector2(0.8, 0.8), tokens.dur_fast).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween_out.tween_property(panel, "modulate:a", 0.0, tokens.dur_fast)
	await tween_out.finished

	pulse.kill()
	overlay.queue_free()
	_holiday_active = false
