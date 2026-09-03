extends Control

## Simulates one week's five school days: the day-by-day loop, random
## minigame/event rolls, and the embedded per-student status cards.
##
## Reached from AturJadwal/StudentList once the week's schedule is
## committed. This is the one screen that mutates student stats -- it
## does so through a StudentManager instance (`initialize_from_gamestate()`
## builds it from GameState, `write_back_to_gamestate()` pushes the
## simulated results back), never by writing GameState.approved_students
## directly. At week's end it also updates GameState.minggu_ke and pays
## out GameState.pending_earnings via `_pay_out_wirausaha()`.

signal simulation_finished
signal _minigame_result(won: bool)  # internal: bridges minigame signals back to _play_minigame
signal _event_decision_signal(accepted: bool, selected_students: Array[StudentData])
signal _continue_tapped
signal _tutorial_closed
signal _summary_closed

## One of four Akademis minigames _play_minigame() may pick when the
## day's roll lands on a minigame event. Null lazy-loads
## Menjodohkan.tscn -- the export exists so a test/level can swap it.
@export var menjodohkan_scene: PackedScene
## Same as menjodohkan_scene, for the Variabel minigame.
@export var variabel_scene: PackedScene
## Same as menjodohkan_scene, for the PilihanGanda minigame.
@export var pilihan_ganda_scene: PackedScene
## Same as menjodohkan_scene, for the Password minigame.
@export var password_scene: PackedScene
## One of two Olahraga minigames that may be picked for the day.
@export var main_bola_scene: PackedScene
## Same as main_bola_scene, for the Badminton minigame.
@export var badminton_scene: PackedScene
## One of two SeniBudaya minigames that may be picked for the day.
@export var buat_batik_scene: PackedScene
## Same as buat_batik_scene, for the LombaMenari minigame.
@export var lomba_menari_scene: PackedScene
## Popup shown before an interactive random event (accept/decline).
@export var event_warning_scene: PackedScene
## Popup shown at the end of the week's simulation with the final tally.
@export var result_checkup_scene: PackedScene
## Popup shown for a non-interactive random event (applies automatically).
@export var event_announcement_scene: PackedScene
## Dialog for interactive events that need the player to pick which
## students take part.
@export var event_student_select_scene: PackedScene
## Popup shown at the end of each simulated day with that day's summary.
@export var day_summary_popup_scene: PackedScene

# ── Visual - Student Cards ────────────────────────────────────────────────────
@export_group("Visual - Student Cards")
## Optional PNG for the student card panel background.
@export var student_card_texture: Texture2D = null
## Optional PNG to replace the ⚡ energy icon.
@export var energy_icon_texture: Texture2D = null
## Optional PNG to replace the 😊 mood icon.
@export var mood_icon_texture: Texture2D = null
## Optional font override for the day-summary chip's label (_make_chip).
## Null keeps the theme's default font.
@export var card_font: Font = null
## Shared icon(-or-glyph) + bar + number row used for the embedded
## energy/mood readout on each student card.
@export var student_stat_row_scene: PackedScene = preload("res://Scenes/SchoolSimulation/StudentStatRow.tscn")
## Shared Card+Margin chrome for the per-student day-summary card.
@export var student_summary_card_scene: PackedScene = preload("res://Scenes/SchoolSimulation/StudentSummaryCard.tscn")
## The end-of-week tutorial's coach-mark. Overridden below to SchoolDay's
## shipped 0.85/900 width, 30px content margin, H2Label title, unstyled
## body and success-tinted CaptionLabel prompt -- everything TutorialPanel
## doesn't default to.
@export var tutorial_panel_scene: PackedScene = preload("res://Scenes/UI/TutorialPanel.tscn")

@export_group("End Simulation Tutorial (Week 1)")
## Title on the one-time tutorial shown after week 1's simulation ends
## (_show_end_simulation_tutorial) -- see TutorialPanel.show_step().
@export var end_tutorial_title: String = "Selamat Menyelesaikan Minggu Pertama! 🎓"
## Body text for the same end-of-week-1 tutorial.
@export_multiline var end_tutorial_text: String = "Kerja bagus, Guru! Kamu telah berhasil membimbing murid-muridmu melewati simulasi minggu pertama.\n\nMulai sekarang, alur permainan akan terus berlanjut dalam siklus:\nAtur Jadwal ➔ Simulasi Hari Sekolah ➔ Evaluasi Mingguan\n\n🎯 Misi Utamamu:\nTingkatkan seluruh kemampuan murid (Akademis, Olahraga, dan Seni Budaya) hingga melampaui Target Ambang Batas masing-masing sebelum Minggu ke-8 selesai!\n\nPada akhir Minggu ke-8, akan diadakan Ujian Kenaikan Kelas untuk menentukan kelulusan murid-muridmu ke jenjang berikutnya. Rencanakan jadwal belajar dan istirahat dengan taktis!"
## Prompt text for the same tutorial.
@export var end_tutorial_prompt: String = "KLIK DIMANA SAJA UNTUK MELANJUTKAN"

# ── Node references ───────────────────────────────────────────────────────────
@onready var day_screen: VBoxContainer    = $DayScreen
@onready var day_number_label: Label      = $DayScreen/DayNumberLabel
@onready var day_label: Label             = $DayScreen/DayLabel
@onready var book_clock_widget: Control   = $BookClockWidget
@onready var progress_bar: StatBar        = $DayScreen/ProgressBar
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
var _tutorial_panel: TutorialPanel = null
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
## Category accent per weekday, used both for the page tint and for the
## day-progress StatBar. Five days, five of the project's accents, so the
## week reads as a progression rather than as five arbitrary colors.
const DAY_CATEGORIES := ["Olahraga", "Akademis", "Istirahat", "Libur", "SeniBudaya", "Wirausaha"]

## How much of the day's accent is mixed into surface_page for the
## backdrop. A page is a large surface; anything stronger stops being a
## background.
const DAY_TINT_STRENGTH := 0.12


func _ready() -> void:
	AudioDirector.play_bgm(&"simulation")
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
# Drives the whole week. This must stay a loop: _run_single_day() awaits
# eight times, so calling it recursively (as this function used to) leaves
# every previous day's frame suspended on the stack. Depth then grows with
# the number of days simulated and eventually overflows. As a loop, depth is
# a constant 2 no matter how long the week runs.
func _run_day() -> void:
	while not is_skipped and current_day < DAYS.size():
		await _run_single_day()
		if is_skipped:
			return
		current_day += 1
	if not is_skipped:
		_on_week_complete()


# ─────────────────────────────────────────────────────────────────────────────
# Runs one full day: shows the day screen, fills the progress bar,
# triggers an optional minigame or event, then awaits click to continue.
# Returning early (every `if is_skipped: return` below) hands control back to
# the driver loop above, which re-checks is_skipped and stops.
func _run_single_day() -> void:
	var day_name = DAYS[current_day]

	# ── Background color and pattern transitions ─────────────────────────────
	# Each weekday takes one of the project's category accents, mixed into
	# tokens.surface_page so the page still reads as a page.
	var tokens := Juice.tokens()
	var day_category: String = DAY_CATEGORIES[current_day % DAY_CATEGORIES.size()]
	var bg_node = get_node_or_null("Background")
	if bg_node:
		var target_color: Color = tokens.surface_page.lerp(
			tokens.category_color(day_category), DAY_TINT_STRENGTH)
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

	# The day-progress bar wears the same accent as the page. This replaces
	# the five hand-generated progress_fill_<weekday>.png textures that used
	# to be pushed in as a per-day stylebox override.
	if progress_bar:
		progress_bar.category = day_category

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
	# The bar goes through Juice like every other bar in the game; the
	# explicit duration keeps it in lockstep with the book clock, which is
	# paced by the in-fiction day length rather than by a motion token.
	Juice.fill_bar(progress_bar, trigger_pct, phase1_dur)
	var day_tween = create_tween().set_parallel(true)
	# Pacing anchor. The bar no longer lives on this tween, and both the
	# clock widget and the decay bars are optional, so without this the
	# tween could end up with no tweeners at all and abort.
	day_tween.tween_interval(phase1_dur)
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
	Juice.fill_bar(progress_bar, 100.0, phase2_dur)
	var bar_phase2 = create_tween().set_parallel(true)
	bar_phase2.tween_interval(phase2_dur)
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

func _await_click_to_continue() -> void:
	if click_to_continue_label == null:
		await get_tree().create_timer(1.0).timeout
		return
		
	click_to_continue_label.modulate.a = 1.0
	click_to_continue_label.show()
	is_waiting_for_continue = true

	# The same looping alpha pulse the Splashscreen hint uses (Task 10), so
	# "tap to continue" reads identically wherever the game says it.
	var pulse = click_to_continue_label.create_tween().set_loops()
	pulse.tween_property(click_to_continue_label, "modulate:a", 0.35, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(click_to_continue_label, "modulate:a", 1.0, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)

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

	var cards: Array = []
	for student in student_manager.students:
		var panel: StudentSummaryCard = student_summary_card_scene.instantiate()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.margin_left = 24
		panel.margin_top = 14
		panel.margin_right = 24
		panel.margin_bottom = 12

		# An art-supplied card PNG still wins; otherwise the theme's Card
		# variation supplies fill, outline, radius, shadow and margins.
		panel.set_background_texture(_get_playful_texture("card_bg"))

		# The panel hasn't entered the tree yet (it's appended below, once
		# fully built, same as before), so the @onready `margin` isn't live
		# -- get_node still works because instantiate() built the subtree.
		var margin: MarginContainer = panel.get_node("Margin")

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
		name_lbl.theme_type_variation = &"TitleLabel"
		left_vbox.add_child(name_lbl)

		left_vbox.add_child(_make_chip(
			" %s " % student.personality, Juice.tokens().brand_primary))

		# Right column: Bars (Energy & Mood)
		var right_vbox = VBoxContainer.new()
		right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.add_theme_constant_override("separation", 12)
		main_hbox.add_child(right_vbox)

		# Energy and Mood are needs, not schedule categories; Libur (warm
		# gold) and Istirahat (violet) are the accents the rest of the game
		# already uses for them.
		var e_data = _add_embedded_bar_row(right_vbox, "⚡", student.energy, "Libur")
		var m_data = _add_embedded_bar_row(right_vbox, "😊", student.mood, "Istirahat")

		# Pill badges row
		var pill_flow = _build_pill_badges_for_student(student, DAYS[current_day] if current_day < DAYS.size() else "")
		if pill_flow:
			card_vbox.add_child(pill_flow)

		student_status_container.add_child(panel)
		cards.append(panel)

		embedded_widgets[student.student_name] = {
			"student": student,
			"e_bar": e_data["bar"],
			"e_lbl": e_data["lbl"],
			"m_bar": m_data["bar"],
			"m_lbl": m_data["lbl"]
		}

	Juice.stagger_in(cards)


## The shared summary chip (SunkenPanel + BarLabel), tinted via
## self_modulate so the child label keeps the theme's own contrast.
func _make_chip(text: String, tint: Color) -> PanelContainer:
	var chip := load("res://Scenes/SchoolSimulation/DaySummaryPill.tscn") \
		.instantiate() as PanelContainer
	chip.self_modulate = tint
	var lbl := chip.get_node("Text") as Label
	lbl.text = text
	if card_font:
		lbl.add_theme_font_override("font", card_font)
	return chip


## Instantiates the shared StudentStatRow. icon_text is a short glyph
## ("⚡"/"😊") shown only as a fallback when no playful texture exists for
## it -- see StudentStatRow.setup(). Returns the same {"bar", "lbl"} shape
## callers have always used, so nothing downstream had to change.
func _add_embedded_bar_row(parent_vbox: VBoxContainer, icon_text: String, current_val: float, category: String) -> Dictionary:
	var row: StudentStatRow = student_stat_row_scene.instantiate()
	parent_vbox.add_child(row)

	var icon_tex := _get_playful_texture("energy" if icon_text == "⚡" else "mood")
	row.setup(icon_text, current_val, category, icon_tex)

	return {
		"bar": row.bar,
		"lbl": row.info_label
	}

## The preview badge must quote the same gain the simulation will apply,
## or a tester changing Balance.gd sees the old number here and thinks
## nothing happened. Mirrors StudentManager.apply_daily_decay_all.
func _preview_gain(student: StudentData, category: String) -> float:
	var base := Balance.BELAJAR_POIN_CADANGAN
	var bonus := Balance.BELAJAR_BONUS_FAVORIT_CADANGAN
	match GameState.current_grade:
		7:
			base = Balance.BELAJAR_POIN_KELAS_7
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
		8:
			base = Balance.BELAJAR_POIN_KELAS_8
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
		9:
			base = Balance.BELAJAR_POIN_KELAS_9
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
	if student.specialty_category == category:
		return base + bonus
	return base

func _build_pill_badges_for_student(student: StudentData, day_name: String) -> HBoxContainer:
	# Returns an HBoxContainer of colored pill Label badges showing what will change today.
	# Sources: schedule (known before day), warnings (energy low).
	var tokens := Juice.tokens()
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
		_add_pill(hbox, "🌿 Libur", tokens.cat_libur)
		return hbox

	match category:
		"Akademis":
			var gain := _preview_gain(student, "Akademis")
			_add_pill(hbox, "+%.0f Akademis 📚" % gain, tokens.cat_akademis)
		"SeniBudaya":
			var gain := _preview_gain(student, "SeniBudaya")
			_add_pill(hbox, "+%.0f Seni 🎨" % gain, tokens.cat_senibudaya)
		"Olahraga":
			var gain := _preview_gain(student, "Olahraga")
			_add_pill(hbox, "+%.0f Olahraga ⚽" % gain, tokens.cat_olahraga)
		"Istirahat":
			_add_pill(hbox, "+%.0f ⚡ Libur" % Balance.LIBUR_ENERGI_PULIH_MAX, tokens.state_success)
		"Wirausaha":
			_add_pill(hbox, "💰 Wirausaha", tokens.category_color("Wirausaha"))
		_:
			_add_pill(hbox, "Kosong", tokens.text_secondary)

	# Energy/Mood cost estimate (show if studying)
	if category != "" and category != "Istirahat":
		_add_pill(hbox, "~-%.0f ⚡" % Balance.BELAJAR_BIAYA_ENERGI_MIN, tokens.state_danger)
		_add_pill(hbox, "~-%.0f 😊" % Balance.BELAJAR_BIAYA_MOOD_MIN, tokens.state_warning)

	# Warning if already low energy
	if student.energy <= Balance.BATAS_KELELAHAN:
		_add_pill(hbox, "⚠ KELELAHAN", tokens.state_danger)

	return hbox

func _add_pill(parent: HBoxContainer, text: String, tint: Color) -> void:
	var clean_text := text
	var icon_key := ""
	
	if "Libur" in text:
		clean_text = text.replace("⚡", "").replace("🌿", "").strip_edges()
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

	# Both branches use the same shared DaySummaryPill chip; the only
	# difference is whether an icon PNG sits beside the text.
	var icon_tex = _get_playful_texture(icon_key) if icon_key != "" else null
	if icon_tex == null:
		parent.add_child(_make_chip(text, tint))
		return

	var chip := _make_chip(clean_text, tint)
	var lbl := chip.get_node("Text") as Label
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var tex_rect = TextureRect.new()
	tex_rect.texture = icon_tex
	tex_rect.custom_minimum_size = Vector2(24, 24)
	tex_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	chip.remove_child(lbl)
	# lbl came from DaySummaryPill.tscn and still names that scene's root as
	# its owner. Re-parenting it under a runtime-built HBoxContainer (owner ==
	# null) makes the ownership inconsistent, and Godot warns every single
	# time -- per badge, per student, per day.
	lbl.owner = null
	chip.add_child(hbox)
	hbox.add_child(tex_rect)
	hbox.add_child(lbl)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	parent.add_child(chip)


## Nodes on the DayScreen that would otherwise read through the summary
## popup's scrim and collide with the card stack. Paths, not @onready refs,
## because several are optional depending on how far the day got.
##
## The sky cinematic is deliberately absent: it is the screen's backdrop
## now, not chrome, and should keep turning behind the summary's scrim.
const _DAY_CHROME_PATHS := [
	"DayScreen/DayNumberLabel",
	"DayScreen/DayLabel",
	"DayScreen/ProgressBar",
	"DayScreen/StatusLabel",
]


func _set_day_chrome_visible(shown: bool) -> void:
	for p in _DAY_CHROME_PATHS:
		var n := get_node_or_null(p)
		if n != null:
			n.visible = shown


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
	_set_day_chrome_visible(false)
	add_child(summary_instance)

	# The popup builds its own mockup cards from the summary. It used to
	# be handed this screen's live StudentScroll instead, which is why
	# DaySummaryStudentRow went unrendered for so long -- and why the
	# mockup's "+12/65" was unbuildable, since only `summary` carries a
	# delta at all.
	summary_instance.setup_summary(summary, student_manager.students)

	await summary_instance.summary_dismissed
	_set_day_chrome_visible(true)


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

		var tokens := Juice.tokens()
		var e_bar = w["e_bar"] as StatBar
		var e_lbl = w["e_lbl"] as Label
		var m_bar = w["m_bar"] as StatBar
		var m_lbl = w["m_lbl"] as Label

		e_bar.value = start_e
		m_bar.value = start_m

		parallel_tween.tween_property(e_bar, "value", curr_e, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		parallel_tween.tween_property(m_bar, "value", curr_m, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

		# The number rolls with the bar, and the label carries the verdict
		# as a tint rather than as a font_color override.
		if e_loss >= 0:
			Juice.count_up(e_lbl, start_e, curr_e, "%d/100 (-" + str(int(e_loss)) + ")")
			e_lbl.self_modulate = tokens.state_danger
		else:
			Juice.count_up(e_lbl, start_e, curr_e, "%d/100 (+" + str(int(-e_loss)) + ")")
			e_lbl.self_modulate = tokens.state_success

		if m_loss >= 0:
			Juice.count_up(m_lbl, start_m, curr_m, "%d/100 (-" + str(int(m_loss)) + ")")
			m_lbl.self_modulate = tokens.state_danger
		else:
			Juice.count_up(m_lbl, start_m, curr_m, "%d/100 (+" + str(int(-m_loss)) + ")")
			m_lbl.self_modulate = tokens.state_success

# Smoothly animate embedded progress bars for post-event or minigame stat updates
func _animate_embedded_stat_updates(duration: float = 0.6) -> void:
	if student_status_container == null or student_manager == null:
		return
		
	if embedded_widgets.is_empty():
		_render_embedded_student_status()
		return
		
	var tokens := Juice.tokens()
	var parallel_tween = create_tween().set_parallel(true)
	var has_updates = false

	for student in student_manager.students:
		var w = embedded_widgets.get(student.student_name, {})
		if w.is_empty():
			continue

		var e_bar = w["e_bar"] as StatBar
		var e_lbl = w["e_lbl"] as Label
		var m_bar = w["m_bar"] as StatBar
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
			Juice.count_up(e_lbl, start_e, target_e, "%d/100 (" + sign_str + ")")
			e_lbl.self_modulate = tokens.state_success if delta_e > 0 else tokens.state_danger

		if absf(delta_m) > 0.1:
			has_updates = true
			parallel_tween.tween_property(m_bar, "value", target_m, duration)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var sign_str = "+%d" % int(delta_m) if delta_m > 0 else "%d" % int(delta_m)
			Juice.count_up(m_lbl, start_m, target_m, "%d/100 (" + sign_str + ")")
			m_lbl.self_modulate = tokens.state_success if delta_m > 0 else tokens.state_danger

	if has_updates:
		await parallel_tween.finished
		await get_tree().create_timer(tokens.dur_slow).timeout
		# Reset label text to clean standard format
		for student in student_manager.students:
			var w = embedded_widgets.get(student.student_name, {})
			if not w.is_empty():
				var e_lbl = w["e_lbl"] as Label
				var m_lbl = w["m_lbl"] as Label
				e_lbl.text = "%d/100" % int(student.energy)
				e_lbl.self_modulate = Color.WHITE
				m_lbl.text = "%d/100" % int(student.mood)
				m_lbl.self_modulate = Color.WHITE

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
							w_event += Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT
	
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

		var tokens := Juice.tokens()
		if category_selected == "Akademis":
			var scene = akademis_scenes[randi() % akademis_scenes.size()]
			await _show_event_warning("📚 KEGIATAN AKADEMIS!", tokens.cat_akademis)
			await _play_minigame(scene, "Akademis")
		elif category_selected == "Olahraga":
			var scene = olahraga_scenes[randi() % olahraga_scenes.size()]
			await _show_event_warning("⚽ KEGIATAN OLAHRAGA!", tokens.cat_olahraga)
			await _play_minigame(scene, "Olahraga")
		else:
			var scene = seni_scenes[randi() % seni_scenes.size()]
			await _show_event_warning("🎨 KEGIATAN SENI BUDAYA!", tokens.cat_senibudaya)
			await _play_minigame(scene, "SeniBudaya")

	else:
		await _trigger_random_event(day_name)

# ─────────────────────────────────────────────────────────────────────────────
func _trigger_random_event(day_name: String) -> void:
	events_triggered_this_week += 1
	# Every student on the roster is present for an event, so
	# an event marks the whole roster as having participated.
	for s in GameState.approved_students:
		GameState.run_stats.record_event_student(int(s.get("id", -1)))
	var event_id = randi() % 5
	
	# ── Quirk: Biang Onar — events are ±20% stronger when active ──
	# Check if any student with Biang Onar is in the roster (affects all events)
	var biang_onar_active: bool = false
	var biang_onar_scale: float = 0.0
	if student_manager:
		for s in student_manager.students:
			if s.quirk == "Biang Onar":
				biang_onar_active = true
				biang_onar_scale = Balance.SIFAT_BIANG_ONAR_EVENT_BAGUS
				break
	
	match event_id:
		0:
			var stat_val := Balance.EVENT_AKADEMIS_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_AKADEMIS_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Les Tambahan Akademis 📚",
				"Sekolah membuka kelas Les Bimbingan Intensif setelah jam pelajaran.",
				"Akademis +%d" % int(stat_val),
				"Energy %d" % int(nrg_val),
				"Akademis", stat_val, nrg_val, 0.0
			)
		1:
			var stat_val := Balance.EVENT_OLAHRAGA_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_OLAHRAGA_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_OLAHRAGA_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Latihan Olahraga Ekstra ⚽",
				"Fasilitas lapangan terbuka gratis untuk sesi latihan bersama.",
				"Olahraga +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"Olahraga", stat_val, nrg_val, mood_val
			)
		2:
			var stat_val := Balance.EVENT_SENI_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_SENI_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_SENI_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
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
			var energy_bonus := Balance.EVENT_NASI_KOTAK_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_bonus := Balance.EVENT_NASI_KOTAK_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
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
			var energy_penalty := Balance.EVENT_HUJAN_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_penalty := Balance.EVENT_HUJAN_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
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

	AudioDirector.pause_bgm()
	AudioDirector.play_minigame_bgm(_minigame_bgm_id(game_scene, category))

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

	AudioDirector.stop_minigame_bgm()
	var tween_close = create_tween()
	tween_close.tween_property(current_minigame, "modulate:a", 0.0, 0.4)
	await tween_close.finished
	current_minigame.queue_free()
	current_minigame = null
	for child in game_container.get_children():
		child.queue_free()

	day_screen.show()
	AudioDirector.resume_bgm()
	var tween_back = create_tween()
	tween_back.tween_property(day_screen, "modulate:a", 1.0, 0.4)
	await tween_back.finished

	await _animate_embedded_stat_updates(0.6)

## Wirausaha pays weekly, not daily -- the week's accrued earnings across
## every assigned student land at once, so the player plans a week of
## trading stats for money rather than watching coins trickle in.
## Returns the total paid, for the summary line.
func _pay_out_wirausaha() -> int:
	var total: int = 0
	for student_id in GameState.pending_earnings:
		total += GameState.pending_earnings[student_id]
	GameState.run_stats.record_wirausaha(total)
	GameState.pending_earnings.clear()
	if total > 0:
		GameState.player_money += total
	return total

# ─────────────────────────────────────────────────────────────────────────────
func _on_week_complete() -> void:
	AudioDirector.play_sfx(&"reward")
	is_running = false
	if skip_button:
		skip_button.hide()
	_reset_day_ui()

	var wirausaha_total := _pay_out_wirausaha()
	if wirausaha_total > 0:
		await get_tree().process_frame
		AudioDirector.play_sfx(&"coin")

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
	progress_bar.show()
	Juice.fill_bar(progress_bar, 100.0)
	status_label.text     = "Selamat! Minggu sekolah telah selesai."
	if wirausaha_total > 0:
		var wirausaha_chip := _make_chip(
			"Pendapatan Wirausaha: Rp%d" % wirausaha_total,
			DesignTokens.load_default().category_color("Wirausaha"))
		status_label.get_parent().add_child(wirausaha_chip)
	back_button.show()

	if not GameState.tutorials_bypassed and GameState.current_grade == 7 and GameState.minggu_ke == 1:
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
				# Every student on the roster is present for an event, so
				# an event marks the whole roster as having participated.
				for s in GameState.approved_students:
					GameState.run_stats.record_event_student(int(s.get("id", -1)))

			var won = randf() > Balance.SKIP_PELUANG_KALAH
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
	AudioDirector.play_sfx(&"cancel")
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
		Transition.change_scene("res://Scenes/EndGame/TesNotice.tscn")
	else:
		Transition.change_scene("res://Scenes/Lobby/loby.tscn")

# ── End Simulation Tutorial Implementation ──────────────────────────────────────
func _show_end_simulation_tutorial() -> void:
	_is_tutorial_active = true
	
	# Dimmer overlay -- a themed Scrim rather than a hand-colored ColorRect.
	var overlay = Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.theme_type_variation = &"Scrim"
	add_child(overlay)

	# The shared TutorialPanel, on the Card surface -- this used to prefer
	# the dialogue_box.png placeholder when present. It no longer does:
	# that art is a near-black box from the old dark palette, and the
	# theme's label colors are now dark-on-light, so the tutorial text
	# rendered black-on-black. Confirmed in a live run. The Card variation
	# is the correct surface for a modal panel and keeps the text legible;
	# the PNG stays in the project for the student-card slot, which is
	# light and still reads fine.
	_tutorial_panel = tutorial_panel_scene.instantiate()
	_tutorial_panel.width_fraction = 0.85
	_tutorial_panel.max_width = 900.0
	_tutorial_panel.content_margin = 30
	_tutorial_panel.vbox_separation = 20
	_tutorial_panel.title_variation = &"H2Label"
	_tutorial_panel.body_variation = &""
	_tutorial_panel.body_width_offset = 100.0
	_tutorial_panel.prompt_variation = &"CaptionLabel"
	_tutorial_panel.prompt_success_tint = true

	var viewport_size = get_viewport_rect().size

	overlay.add_child(_tutorial_panel)
	_tutorial_panel.show_step(end_tutorial_title, end_tutorial_text, end_tutorial_prompt)

	# Pulsing Prompt Tween -- same hint pulse as the Splashscreen (Task 10).
	_tutorial_panel.prompt_label.modulate.a = 1.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_tutorial_panel.prompt_label, "modulate:a", 0.35, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_tutorial_panel.prompt_label, "modulate:a", 1.0, Juice.tokens().dur_slow) \
		.set_ease(Tween.EASE_IN_OUT)

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


## Maps a category + the specific minigame scene to the AudioDirector
## minigame bgm id that should play for it. Deliberately independent
## from _scene_name()'s display-text mapping above -- that text is
## presentation-only and could change without this needing to.
func _minigame_bgm_id(game_scene: PackedScene, category: String) -> StringName:
	match category:
		"Akademis":
			return &"minigame_akademis"
		"Olahraga":
			return &"minigame_olahraga"
		"SeniBudaya":
			var file_name := game_scene.resource_path.get_file()
			if file_name == "LombaMenari.tscn":
				return &"minigame_senibudaya_menari"
			return &"minigame_senibudaya_batik"
	return &""

# ─────────────────────────────────────────────────────────────────────────────
func _show_event_warning(event_label: String, accent_color: Color) -> void:
	var warning_scene = event_warning_scene
	if warning_scene == null:
		warning_scene = load("res://Scenes/SchoolSimulation/EventWarning.tscn")

	if warning_scene == null:
		return

	AudioDirector.play_sfx(&"popup_open")
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

	AudioDirector.play_sfx(&"popup_open")
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
	# Every student on the roster is present for an event, so
	# an event marks the whole roster as having participated.
	for s in GameState.approved_students:
		GameState.run_stats.record_event_student(int(s.get("id", -1)))

	var biang_onar_active: bool = false
	var biang_onar_scale: float = 0.0
	if student_manager:
		for s in student_manager.students:
			if s.quirk == "Biang Onar":
				biang_onar_active = true
				biang_onar_scale = Balance.SIFAT_BIANG_ONAR_EVENT_BAGUS
				break

	match event_id:
		0:
			var stat_val := Balance.EVENT_AKADEMIS_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_AKADEMIS_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Les Tambahan Akademis 📚",
				"Sekolah membuka kelas Les Bimbingan Intensif setelah jam pelajaran.",
				"Akademis +%d" % int(stat_val),
				"Energy %d" % int(nrg_val),
				"Akademis", stat_val, nrg_val, 0.0
			)
		1:
			var stat_val := Balance.EVENT_OLAHRAGA_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_OLAHRAGA_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_OLAHRAGA_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Latihan Olahraga Ekstra ⚽",
				"Fasilitas lapangan terbuka gratis untuk sesi latihan bersama.",
				"Olahraga +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"Olahraga", stat_val, nrg_val, mood_val
			)
		2:
			var stat_val := Balance.EVENT_SENI_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_SENI_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_SENI_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
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
			var energy_bonus := Balance.EVENT_NASI_KOTAK_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_bonus := Balance.EVENT_NASI_KOTAK_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				s.apply_event_effects("", 0.0, energy_bonus, mood_bonus)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Nasi Kotak Berbagi", names, "Semua siswa mendapat Energy +%d dan Mood +%d" % [int(energy_bonus), int(mood_bonus)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout
		4:
			await _show_event_announcement("🌧 Hujan Deras & Jalanan Licin!")
			var energy_penalty := Balance.EVENT_HUJAN_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_penalty := Balance.EVENT_HUJAN_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				s.apply_event_effects("", 0.0, energy_penalty, mood_penalty)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Kehujanan & Terpeleset", names, "Semua siswa mendapat Energy %d dan Mood %d" % [int(energy_penalty), int(mood_penalty)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout
