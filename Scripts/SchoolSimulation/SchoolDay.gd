extends Control

## Simulates one week's five school days: the day-by-day loop, random
## minigame/event rolls, and the avatar strip of per-student energy/mood rings.
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
## The sliding warning shown before every minigame and random event.
@export var event_warning_scene: PackedScene
## Popup shown at the end of the week's simulation with the final tally.
@export var result_checkup_scene: PackedScene
## Dialog for interactive events that need the player to pick which
## students take part.
@export var event_student_select_scene: PackedScene
## The per-event character line between the warning and a minigame or event
## (2026-09-14 event-dialogue spec). Null lazy-loads
## Scenes/SchoolSimulation/EventDialogue.tscn.
@export var event_dialogue_scene: PackedScene
## Popup shown at the end of each simulated day with that day's summary.
@export var day_summary_popup_scene: PackedScene

# ── Visual - Student Cards ────────────────────────────────────────────────────
@export_group("Visual - Student Cards")
## Optional font override for the day-summary chip's label (_make_chip).
## Null keeps the theme's default font.
@export var card_font: Font = null
## The ambient mote sprite for each weekday, Senin to Jumat, in the same
## order as the banner's motifs, so each day drifts with its own texture.
@export var weekday_mote_textures: Array[Texture2D] = []
## One student on the day's avatar strip: face, energy and mood rings, name.
## Replaced the runtime-built status cards (2026-09-24 liveliness pass).
@export var avatar_chip_scene: PackedScene = preload("res://Scenes/SchoolSimulation/AvatarChip.tscn")
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
@onready var book_clock_widget: Control   = $BookClockWidget
## The day's progress. Since the 2026-09-24 liveliness pass it is the
## invisible driver inside BookClockWidget's banner: the banner fills as this
## Range's value rises, so the Juice.fill_bar calls below pace both.
@onready var progress_bar: Range          = $BookClockWidget/Header/DayProgress
@onready var status_label: Label          = $DayScreen/StatusStrip/StatusLabel
## The slim scrim the status line rides; faded in only for its beats.
@onready var status_strip: Control        = $DayScreen/StatusStrip
## The "<hari> selesai" ink stamp that slams in when a day ends.
@onready var day_stamp: Control           = $DayStamp
@onready var day_stamp_label: Label       = $DayStamp/StampLabel
## Rain streaks over the day screen, on for the rest of a day Hujan hits.
@onready var rain: CPUParticles2D         = $Rain
## Faint motes drifting up the sky, a different sprite each weekday.
@onready var motes: CPUParticles2D        = $Motes
## The fireworks volley that crowns the week's last school day.
@onready var week_fireworks: ConfettiFireworks = $WeekFireworks
## The avatar strip: a sideways-scrolling row of AvatarChips, one per
## student, so any roster size fits without crowding the sky.
@onready var avatar_strip: Control        = $DayScreen/AvatarStrip
@onready var avatar_row: HBoxContainer    = $DayScreen/AvatarStrip/AvatarRow
## "Energi / Mood" under the strip, teaching which ring is which.
@onready var ring_legend: Control         = $DayScreen/RingLegend
@onready var click_to_continue_label: Label = $DayScreen/ClickToContinueLabel
@onready var back_button: Button          = $DayScreen/BackButton
@onready var skip_button: Button          = $DayScreen/SkipButton
@onready var game_container: Control      = $GameContainer

const DAYS = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
## Fallback seconds to fill a day's progress bar, used only when the
## BookClock widget is absent. Normally the pacing comes from the
## widget's own transition_duration -- see _phase_duration() -- so the
## sky's tuned motion and the bar can never drift apart.
const DAY_FILL_DURATION = 2.0

## Where in the school day the event rolls, as a percentage of it.
##
## The day's progress bar still fills in two phases with the event between
## them, but the sky is swept once across both -- so the event lands at
## the middle of the day without the sky stopping there. It was pinned to
## a named midday pose until 2026-09-10, and to a randomised afternoon
## point before that.
const EVENT_TRIGGER_PCT := 50.0

# -- Status line and day stamp (2026-09-24 liveliness pass) -------------------
## Seconds a passing status beat stays on its scrim before the scrim fades
## and leaves the sky open again.
const STATUS_BEAT_HOLD := 1.4
## Seconds the "selesai" stamp sits before the day's summary opens.
const STAMP_HOLD := 0.9
## The stamp's size as it starts to slam down, relative to its rest size.
const STAMP_SLAM_FROM := 1.7
## Seconds the deep night holds between two school days, once it has fallen
## and before the next dawn. Short, so it never stalls a fast player.
const NIGHT_HOLD := 0.5

# Day-roll weights. Each school day rolls Normal / Minigame / Event in
# proportion to these -- shares of the day's total, not percentages -- and
# day_roll_weights() is their only reader. Biang Onar's extra event weight,
# in the same units, is Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT.

## Normal-day weight every day starts with.
const ROLL_WEIGHT_NORMAL_BASE := 20
## Extra normal-day weight for each student resting (Istirahat) that day.
const ROLL_WEIGHT_NORMAL_PER_RESTING := 10
## Minigame weight for each student studying Akademis, Olahraga or
## SeniBudaya that day, while the week's minigame cap has room.
const ROLL_WEIGHT_MINIGAME_PER_STUDYING := 15
## Event weight a day starts with while the week's event cap has room.
const ROLL_WEIGHT_EVENT_BASE := 25
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
## Rolled once per week from Balance.MINIGAME_MAKS_MINGGU_MIN..MAX. The player
## cannot bank on a fixed number of minigames -- see the anti-exploit spec.
var max_minigames_this_week: int = 2
var is_waiting_for_continue: bool = false

var embedded_widgets: Dictionary = {} # student_name -> {student, chip}
## GameState.pending_earnings' total when today began, so the daily result
## can show what Wirausaha earned today (it is paid out at week's end).
var _money_at_day_start := 0

# End Simulation Tutorial internal variables
var _tutorial_panel: TutorialPanel = null
var _blink_tween: Tween = null
var _is_tutorial_active: bool = false
var _is_summary_active: bool = false

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
	_tint_ring_legend()
	
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
	max_minigames_this_week = randi_range(Balance.MINIGAME_MAKS_MINGGU_MIN, Balance.MINIGAME_MAKS_MINGGU_MAX)
	GameState.minigame_gain_this_week.clear()
	student_manager = StudentManager.new()
	student_manager.initialize_from_gamestate()
	if skip_button:
		skip_button.show()
	# The classroom bed runs under the whole week. _on_week_complete() stops
	# it; a bed left running would murmur on under the shop and the lobby.
	AudioDirector.play_ambience(&"classroom_1")
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
	_money_at_day_start = _pending_total()
	# One bell per day, not per student: this is the top of the day loop, and
	# the per-student work happens further down.
	AudioDirector.play_sfx(&"school_bell")

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
	_set_status("Perjalanan ke sekolah...")

	# Reset and configure book-clock widget for the new day
	if book_clock_widget and book_clock_widget.has_method("set_day"):
		book_clock_widget.call("reset")
		book_clock_widget.call("set_day", day_name)
		# The same two values EventDialogue is handed, so the day banner and
		# the dialogue's header can never disagree about which week it is.
		book_clock_widget.call("set_week",
			GameState.minggu_ke, GameState.get_max_weeks())
		# The banner fills in the day's own colour, with its weekday motif.
		book_clock_widget.call("set_day_style", tokens.category_color(day_category), current_day)
		# The deep night between days lifts into this day's dawn.
		_lift_night()
	# Yesterday's rain has passed.
	_set_rain(false)
	_set_weekday_motes(current_day)

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

	# ── Phase 1: dawn to midday, where the event rolls ───────────────────────
	# Both phases run for one BookClock transition. Taking the length from
	# the widget rather than splitting a constant here is what keeps the
	# day's progress bar and the sky in lockstep: the sweep's tuned
	# duration is the single source, and the bar follows it.
	var trigger_pct := EVENT_TRIGGER_PCT
	var phase1_dur := _phase_duration()

	_set_status("Melewati hari sekolah...", STATUS_BEAT_HOLD)
	
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
	# One sweep across the whole day. The sky is deliberately NOT paused
	# for the event: it used to rest at a midday pose while the popup was
	# up, which read as the day stopping. Because the event is
	# player-blocking, a slow player will see the sky reach evening before
	# the day's second half finishes and hold there -- accepted.
	if book_clock_widget and book_clock_widget.has_method("transition_to"):
		book_clock_widget.call("transition_to", BookClockWidget.Phase.EVENING,
			phase1_dur + _phase_duration())

	_animate_embedded_decay_bars(day_tween, decay_results, phase1_dur)
	_pop_todays_gains(day_name, phase1_dur)
	await day_tween.finished
	if is_skipped:
		return

	# ── Event rolls here ──────────────────────────────────────────────────────
	await _roll_event(day_name)
	if is_skipped:
		return

	# ── Phase 2: Fill remaining bar to 100% ──────────────────────────────────
	var phase2_dur := _phase_duration()
	_set_status("Melanjutkan hari...", STATUS_BEAT_HOLD)
	Juice.fill_bar(progress_bar, 100.0, phase2_dur)
	var bar_phase2 = create_tween().set_parallel(true)
	bar_phase2.tween_interval(phase2_dur)
	await bar_phase2.finished
	if is_skipped:
		return

	# The day ends on an ink stamp rather than a status line (and its old
	# emoji tick, flagged in DEBT.md).
	_set_status("")
	await _play_day_stamp(day_name)
	if is_skipped:
		return
	
	# ── End-of-Day Summary ────────────────────────────────────────────────────
	await _show_day_summary(day_name)

	# ── Blinking "Click anywhere to continue" prompt ─────────────────────────
	await _await_click_to_continue()
	if is_skipped:
		return

	# Fade out before moving to the next day, as the deep night falls: the
	# sky dips to a real night -- tint, stars, the school dark with its
	# windows lit -- and holds briefly before the next day's dawn lifts it.
	var night_fall := _begin_night()
	var fade_out = create_tween()
	fade_out.tween_property(day_screen, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	if is_skipped:
		return
	if night_fall != null and night_fall.is_running():
		await night_fall.finished
	await get_tree().create_timer(NIGHT_HOLD).timeout
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
## Fills the avatar strip with one AvatarChip per student, rings at their
## start-of-day values, and staggers them in. Instanced from a template
## (2026-09-24 liveliness pass) -- the old full-width cards were built node by
## node at runtime and crowded the screen.
func _render_embedded_student_status() -> void:
	if avatar_row == null or student_manager == null or avatar_chip_scene == null:
		return

	for child in avatar_row.get_children():
		child.queue_free()
	embedded_widgets.clear()

	var chips: Array = []
	for student in student_manager.students:
		var chip := avatar_chip_scene.instantiate() as AvatarChip
		avatar_row.add_child(chip)
		chip.setup(student)
		chips.append(chip)
		embedded_widgets[student.student_name] = {
			"student": student, "chip": chip, "skills": _skill_sum(student)}

	if avatar_strip:
		avatar_strip.show()
	if ring_legend:
		ring_legend.show()
	if not GameSettings.reduce_motion:
		Juice.stagger_in(chips)


## A student's three skills added up, to tell when any of them rose.
func _skill_sum(student: StudentData) -> float:
	return student.akademis + student.seni_budaya + student.olahraga


## Colours the legend's two dots like the rings they name.
func _tint_ring_legend() -> void:
	var tokens := Juice.tokens()
	var energy := get_node_or_null("DayScreen/RingLegend/Row/EnergyDot") as CanvasItem
	if energy:
		energy.self_modulate = tokens.category_color_on_dark("Energy")
	var mood := get_node_or_null("DayScreen/RingLegend/Row/MoodDot") as CanvasItem
	if mood:
		mood.self_modulate = tokens.category_color_on_dark("Mood")


## Floats a "+N" from each student who gained skill points today, spread
## across the first half of the day so the gains land one by one.
func _pop_todays_gains(day_name: String, span: float) -> void:
	if student_manager == null:
		return
	var gains := {}
	for entry in student_manager.daily_stat_log.get(day_name, []):
		if entry.get("source", "") != "activity":
			continue
		if not (entry.get("stat_key", "") in ["akademis", "seni_budaya", "olahraga"]):
			continue
		var who: String = entry.get("student_name", "")
		gains[who] = gains.get(who, 0.0) + float(entry.get("delta", 0.0))
	# The activity's gains are applied by now; bank them so a later event or
	# minigame update does not pop them a second time.
	for w in embedded_widgets.values():
		w["skills"] = _skill_sum(w["student"])
	var pops: Array = []
	for who in gains:
		var chip := (embedded_widgets.get(who, {}) as Dictionary).get("chip") as AvatarChip
		if chip != null and gains[who] > 0.0:
			pops.append([chip, int(round(gains[who]))])
	if pops.is_empty():
		return
	var gap: float = span / float(pops.size() + 1)
	var timeline := create_tween()
	for pop in pops:
		timeline.tween_interval(gap)
		timeline.tween_callback((pop[0] as AvatarChip).pop_gain.bind(pop[1]))


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


## Nodes on the DayScreen that would otherwise read through the summary
## popup's scrim and collide with the card stack. Paths, not @onready refs,
## because several are optional depending on how far the day got.
##
## The sky cinematic is deliberately absent: it is the screen's backdrop
## now, not chrome, and should keep turning behind the summary's scrim.
## What the day-summary popup hides behind itself, and shows again on the way
## out. DayScreen/DayLabel is deliberately NOT here: since 2026-09-21 the
## BookClockWidget header carries the day name and the scene hides this label
## permanently, so listing it would set visible = true on the way out and
## bring the duplicate back for the rest of the run.
const _DAY_CHROME_PATHS := [
	"DayScreen/StatusStrip",
	"DayScreen/AvatarStrip",
	"DayScreen/RingLegend",
]


## Everything Wirausaha has earned this week and not yet been paid.
func _pending_total() -> int:
	var total := 0
	for amount in GameState.pending_earnings.values():
		total += int(amount)
	return total


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
	summary_instance.setup_summary(summary, student_manager.students,
		_pending_total() - _money_at_day_start)

	await summary_instance.summary_dismissed
	_set_day_chrome_visible(true)


func _animate_embedded_decay_bars(parallel_tween: Tween, decay_results: Array[Dictionary], duration: float) -> void:
	# The rings sweep to each student's post-decay needs over the day's first
	# half. parallel_tween only paces the day; each chip tweens itself.
	for res in decay_results:
		var w: Dictionary = embedded_widgets.get(res.get("student_name", ""), {})
		var chip := w.get("chip") as AvatarChip
		if chip == null:
			continue
		chip.tween_needs(float(res.get("current_energy", 80.0)),
			float(res.get("current_mood", 80.0)), duration)


## Sweeps every chip's rings to the student's needs after an event or
## minigame changed them, and springs the chips that moved.
func _animate_embedded_stat_updates(duration: float = 0.6) -> void:
	if avatar_row == null or student_manager == null:
		return
	if embedded_widgets.is_empty():
		_render_embedded_student_status()
		return
	var moved := false
	for student in student_manager.students:
		var w: Dictionary = embedded_widgets.get(student.student_name, {})
		var chip := w.get("chip") as AvatarChip
		if chip == null:
			continue
		var now := chip.needs()
		if absf(now.x - student.energy) < 0.1 and absf(now.y - student.mood) < 0.1:
			continue
		moved = true
		chip.tween_needs(student.energy, student.mood, duration)
		if not GameSettings.reduce_motion:
			AnimUtils.squash_bounce(chip)
	# A won minigame or a Terima'd event can raise a skill too; the chip pops
	# a +N for it just as it does for the day's activity.
	for student in student_manager.students:
		var w: Dictionary = embedded_widgets.get(student.student_name, {})
		var chip := w.get("chip") as AvatarChip
		if chip == null:
			continue
		var now := _skill_sum(student)
		var gained: float = now - float(w.get("skills", now))
		w["skills"] = now
		if gained >= 0.5:
			moved = true
			chip.pop_gain(int(round(gained)))
	if moved:
		await get_tree().create_timer(duration).timeout


# ─────────────────────────────────────────────────────────────────────────────
## How long one half of the school day runs, in seconds.
##
## Read off the BookClock so the sky's tuned sweep is the single source
## of pacing and the day's progress bar simply follows it -- the two used
## to be kept in step by hand, by splitting DAY_FILL_DURATION here and
## passing the same number to both. Falls back to that split when the
## widget is missing, which is the case in headless tests.
func _phase_duration() -> float:
	if book_clock_widget != null and "transition_duration" in book_clock_widget:
		return float(book_clock_widget.transition_duration)
	return DAY_FILL_DURATION * 0.5


# ─────────────────────────────────────────────────────────────────────────────
## A school day's Normal / Minigame / Event roll weights, as
## {"normal": int, "minigame": int, "event": int}.
##
## `counts` is GameState.get_jadwal_for_day(day_name), `roster` the
## simulated StudentData and `schedules` GameState.day_schedules. Resting
## students add normal-day weight and studying students minigame weight;
## each Biang Onar student scheduled for anything but rest that day adds
## Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT to the event weight. Once the
## week's minigame or event cap is reached, that weight is 0 -- the bonus
## included.
##
## Static and pure so a test can call it without the scene. Shared by
## _roll_event() and skip_to_results(), through _todays_roll_weights(), so
## the two simulation paths can't drift apart: skipping once rolled
## without Biang Onar's bonus.
static func day_roll_weights(counts: Dictionary, roster: Array, schedules: Dictionary,
		day_name: String, minigames_played: int, max_minigames: int,
		events_triggered: int, max_events: int) -> Dictionary:
	var active_studying: int = (counts.get("Akademis", 0) + counts.get("Olahraga", 0)
		+ counts.get("SeniBudaya", 0))
	var resting_count: int = counts.get("Istirahat", 0)

	var w_minigame := 0
	if minigames_played < max_minigames:
		w_minigame = active_studying * ROLL_WEIGHT_MINIGAME_PER_STUDYING

	var w_event := 0
	if events_triggered < max_events:
		w_event = ROLL_WEIGHT_EVENT_BASE

		# ── Quirk: Biang Onar — extra event weight per one who isn't resting ──
		for s in roster:
			if s.quirk == "Biang Onar":
				var sid = s.id
				if sid != 0 and schedules.has(sid):
					var cat = schedules[sid].get(day_name, {}).get("category", "")
					# Anything but rest counts, Wirausaha included
					if cat != "" and cat != "DayOff" and cat != "Istirahat":
						w_event += Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT

	return {
		"normal": ROLL_WEIGHT_NORMAL_BASE + resting_count * ROLL_WEIGHT_NORMAL_PER_RESTING,
		"minigame": w_minigame,
		"event": w_event,
	}


## day_roll_weights() for `day_name`, fed from this screen's live state --
## the week's minigame and event counters, the simulated roster and
## GameState's schedules. Both simulation paths make this one call, so they
## can't hand the helper different inputs either.
func _todays_roll_weights(day_name: String, counts: Dictionary) -> Dictionary:
	var roster: Array = []
	if student_manager:
		roster = student_manager.students
	return day_roll_weights(counts, roster, GameState.day_schedules, day_name,
		minigames_played_this_week, max_minigames_this_week,
		events_triggered_this_week, max_events_this_week)


func _roll_event(day_name: String) -> void:
	var week = GameState.minggu_ke
	if HOLIDAYS.has(week) and HOLIDAYS[week].has(day_name):
		var holiday_name = HOLIDAYS[week][day_name]
		_set_status("Hari Libur Nasional: %s" % holiday_name)
		await get_tree().create_timer(1.2).timeout
		return

	var counts = GameState.get_jadwal_for_day(day_name)
	var w_akademis = counts.get("Akademis", 0)
	var w_olahraga = counts.get("Olahraga", 0)
	var w_seni = counts.get("SeniBudaya", 0)

	var weights := _todays_roll_weights(day_name, counts)
	var w_normal: int = weights["normal"]
	var w_minigame: int = weights["minigame"]
	var w_event: int = weights["event"]

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
		_set_status("Hari biasa...", STATUS_BEAT_HOLD)
		await get_tree().create_timer(0.8).timeout

	elif outcome == "Minigame":
		var category_selected = _pick_minigame_category(w_akademis, w_olahraga, w_seni)

		if category_selected == "Akademis":
			var scene = akademis_scenes[randi() % akademis_scenes.size()]
			await _show_event_warning("KEGIATAN AKADEMIS!", "Akademis", "MINIGAME")
			await _show_event_dialogue(minigame_dialogue_key(scene))
			await _play_minigame(scene, "Akademis")
		elif category_selected == "Olahraga":
			var scene = olahraga_scenes[randi() % olahraga_scenes.size()]
			await _show_event_warning("KEGIATAN OLAHRAGA!", "Olahraga", "MINIGAME")
			await _show_event_dialogue(minigame_dialogue_key(scene))
			await _play_minigame(scene, "Olahraga")
		else:
			var scene = seni_scenes[randi() % seni_scenes.size()]
			await _show_event_warning("KEGIATAN SENI BUDAYA!", "SeniBudaya", "MINIGAME")
			await _show_event_dialogue(minigame_dialogue_key(scene))
			await _play_minigame(scene, "SeniBudaya")

	else:
		await _trigger_random_event(day_name)

# ─────────────────────────────────────────────────────────────────────────────
## Picks a minigame category with a chance of uniform-random noise
## (Balance.MINIGAME_KATEGORI_ACAK_PELUANG) before falling back to a pick
## proportional to the day's scheduled subject weights, with a uniform
## fallback if all weights are zero. Shared by _roll_event() and
## skip_to_results() so the two simulation paths can't drift apart.
func _pick_minigame_category(w_akademis: int, w_olahraga: int, w_seni: int) -> String:
	if randf() < Balance.MINIGAME_KATEGORI_ACAK_PELUANG:
		var r := randi() % 3
		return "Akademis" if r == 0 else ("Olahraga" if r == 1 else "SeniBudaya")
	else:
		var total_subject_weight = w_akademis + w_olahraga + w_seni
		if total_subject_weight == 0:
			var cat_roll = randi() % 3
			if cat_roll == 0:
				return "Akademis"
			elif cat_roll == 1:
				return "Olahraga"
			else:
				return "SeniBudaya"
		else:
			var choice = randi() % total_subject_weight
			if choice < w_akademis:
				return "Akademis"
			elif choice < w_akademis + w_olahraga:
				return "Olahraga"
			else:
				return "SeniBudaya"

func _trigger_random_event(day_name: String) -> void:
	events_triggered_this_week += 1
	# Every student on the roster is present for an event, so
	# an event marks the whole roster as having participated.
	for s in GameState.approved_students:
		GameState.run_stats.record_event_student(int(s.get("id", -1)))
	await _run_event(randi() % 5, day_name)


## Plays random event `event_id` (0-4) on `day_name`: its warning, its
## dialogue, then its effect. The one copy of the event list --
## _trigger_random_event() rolls the id, force_event() takes it from the
## debug overlay.
func _run_event(event_id: int, day_name: String) -> void:
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
				"Les Tambahan Akademis",
				"Sekolah membuka kelas Les Bimbingan Intensif setelah jam pelajaran.",
				"Akademis +%d" % int(stat_val),
				"Energy %d" % int(nrg_val),
				"Akademis", stat_val, nrg_val, 0.0,
				"les_akademis"
			)
		1:
			var stat_val := Balance.EVENT_OLAHRAGA_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_OLAHRAGA_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_OLAHRAGA_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Latihan Olahraga Ekstra",
				"Fasilitas lapangan terbuka gratis untuk sesi latihan bersama.",
				"Olahraga +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"Olahraga", stat_val, nrg_val, mood_val,
				"latihan_olahraga"
			)
		2:
			var stat_val := Balance.EVENT_SENI_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_SENI_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_SENI_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Workshop Sanggar Seni",
				"Terdapat workshop pembuatan kerajinan dan tari daerah setempat.",
				"Seni Budaya +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"SeniBudaya", stat_val, nrg_val, mood_val,
				"workshop_seni"
			)
		3:
			await _show_event_warning("Kejutan Nasi Kotak Orang Tua!", "Sosial", "KABAR")
			await _show_event_dialogue("nasi_kotak")
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
			await _show_event_warning("Hujan Deras & Jalanan Licin!", "Cuaca", "KABAR")
			await _show_event_dialogue("hujan")
			# The sky reacts too: it rains on the day screen for the rest of
			# the day, not only on the event screen.
			_set_rain(true)
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
	stat_boost: float, energy_cost: float, mood_boost: float,
	dialogue_key: String = ""
) -> void:
	# A choice event says so on its notice (PILIHAN), before Tolak / Terima.
	var entry: Dictionary = EventDialogueCatalog.entry(dialogue_key) 		if EventDialogueCatalog.has_entry(dialogue_key) else {}
	var mode := "PILIHAN" if entry.get("mode", "") == EventDialogueCatalog.MODE_CHOICE else "KABAR"
	await _show_event_warning(title, category, mode)
	# Tolak skips the event: no picker, nothing applied or recorded. It still
	# counted toward the week's limit when it was rolled.
	var wants_in: bool = await _show_event_dialogue(dialogue_key)
	if not wants_in:
		return

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
	day_screen.process_mode = Node.PROCESS_MODE_DISABLED

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
			8: duration = base_duration * Balance.MINIGAME_WAKTU_SKALA_KELAS_8
			9: duration = base_duration * Balance.MINIGAME_WAKTU_SKALA_KELAS_9
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

	# Only a minigame really played here counts toward achievements.
	var mg_stars: int = 0
	var mg_time_left: float = -1.0
	if current_minigame and "last_result_stars" in current_minigame:
		mg_stars = current_minigame.last_result_stars
		mg_time_left = current_minigame.last_time_left_ratio
	Achievements.record_minigame(category, game_name, won, mg_stars, mg_time_left)

	AudioDirector.stop_minigame_bgm()
	var tween_close = create_tween()
	tween_close.tween_property(current_minigame, "modulate:a", 0.0, 0.4)
	await tween_close.finished
	current_minigame.queue_free()
	current_minigame = null
	for child in game_container.get_children():
		child.queue_free()

	day_screen.process_mode = Node.PROCESS_MODE_INHERIT
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
	# Claimed Wirausaha prizes (Pembimbing Sepuh, Seorang CEO) scale the payout.
	total = roundi(total * Achievements.effect_multiplier("wirausaha"))
	GameState.run_stats.record_wirausaha(total)
	GameState.pending_earnings.clear()
	if total > 0:
		GameState.player_money += total
	return total

# ─────────────────────────────────────────────────────────────────────────────
func _on_week_complete() -> void:
	AudioDirector.stop_ambience()
	_lift_night()
	_set_rain(false)
	RewardFeedback.play(&"week_cleared", self)
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
		day_screen.process_mode = Node.PROCESS_MODE_DISABLED
		var checkup_instance = result_checkup_scene.instantiate()
		game_container.add_child(checkup_instance)
		checkup_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# _pay_out_wirausaha() above already emptied pending_earnings, so the
		# week's coins travel in by hand.
		checkup_instance.initialize_checkup(student_manager, wirausaha_total)
		await checkup_instance.checkup_closed
		checkup_instance.queue_free()

	day_screen.modulate.a = 0.0
	day_screen.process_mode = Node.PROCESS_MODE_INHERIT
	day_screen.show()
	var fade = create_tween()
	fade.tween_property(day_screen, "modulate:a", 1.0, 0.6)
	await fade.finished

	if book_clock_widget and book_clock_widget.has_method("set_banner"):
		book_clock_widget.call("set_banner", "Akhir Pekan")
	Juice.fill_bar(progress_bar, 100.0)
	# "Minggu selesai!" used to sit on the day counter, which the banner's
	# fill replaced; it rides the status strip now, and stays up.
	_set_status("Minggu selesai! Selamat!")
	if wirausaha_total > 0:
		var wirausaha_chip := _make_chip(
			"Pendapatan Wirausaha: Rp%d" % wirausaha_total,
			DesignTokens.load_default().category_color("Wirausaha"))
		day_screen.add_child(wirausaha_chip)
		day_screen.move_child(wirausaha_chip, status_strip.get_index() + 1)
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

		var weights := _todays_roll_weights(day_name, counts)
		var w_normal: int = weights["normal"]
		var w_minigame: int = weights["minigame"]
		var w_event: int = weights["event"]
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
				category = _pick_minigame_category(w_akademis, w_olahraga, w_seni)
			else:
				category = "Event"
				events_triggered_this_week += 1
				# Every student on the roster is present for an event, so
				# an event marks the whole roster as having participated.
				for s in GameState.approved_students:
					GameState.run_stats.record_event_student(int(s.get("id", -1)))

			var skip_lose_chance := Balance.SKIP_PELUANG_KALAH_KELAS_7
			match GameState.current_grade:
				8: skip_lose_chance = Balance.SKIP_PELUANG_KALAH_KELAS_8
				9: skip_lose_chance = Balance.SKIP_PELUANG_KALAH_KELAS_9
			var won = randf() > skip_lose_chance
			if student_manager:
				student_manager.record_minigame_result(day_name, category, "Simulasi Cepat", won)
		current_day += 1
		
	if current_minigame:
		current_minigame.queue_free()
		current_minigame = null
		
	for child in game_container.get_children():
		child.queue_free()
		
	_on_week_complete()

## Android delivers the hardware/gesture back press as a notification, not as
## ui_cancel, so an _input handler never sees it. Routed to the same function
## the on-screen continue button calls, so both do exactly the same thing --
## which here means advancing the week, not abandoning it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _on_back_pressed() -> void:
	# Belt and braces: _on_week_complete() already stops the bed on both the
	# normal and the skipped path, but leaving the screen by any route must
	# not leave a classroom murmuring under the lobby.
	AudioDirector.stop_ambience()
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
	if avatar_strip:
		avatar_strip.hide()
	if ring_legend:
		ring_legend.hide()
	_set_status("")
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
## Lets the deep night fall between two school days (2026-09-24 liveliness
## pass, layer 6). Hands back the widget's Tween, or null without one.
func _begin_night() -> Tween:
	if book_clock_widget == null or not book_clock_widget.has_method("night_in"):
		return null
	return book_clock_widget.call("night_in")


## Lifts the night, if any, into the new day's dawn.
func _lift_night() -> void:
	if book_clock_widget == null or not book_clock_widget.has_method("night_out"):
		return
	if float(book_clock_widget.call("night")) > 0.0:
		book_clock_widget.call("night_out")


## The day-done burst, escalating (spec layer 6): every day gets a small Pop
## burst from the stamp; the week's last school day also sets off the
## ConfettiFireworks volley over the sky.
func _celebrate_day_end(is_last_day: bool) -> void:
	RewardFeedback.play(&"day_done", day_stamp)
	if not is_last_day or week_fireworks == null or GameSettings.reduce_motion:
		return
	var volley := create_tween()
	for i in week_fireworks.burst_count():
		volley.tween_callback(week_fireworks.fire_burst.bind(i))
		volley.tween_interval(week_fireworks.burst_delay)


## Gives the sky's drifting motes this weekday's sprite. They stop under
## reduce_motion: they are ambience, not information.
func _set_weekday_motes(weekday: int) -> void:
	if motes == null:
		return
	if not weekday_mote_textures.is_empty():
		motes.texture = weekday_mote_textures[posmod(weekday, weekday_mote_textures.size())]
	motes.emitting = not GameSettings.reduce_motion


## Starts or stops the rain over the day screen. It stays on under
## reduce_motion: it is the day's weather, not decoration.
func _set_rain(on: bool) -> void:
	if rain == null:
		return
	rain.emitting = on
	rain.visible = on


# ─────────────────────────────────────────────────────────────────────────────
var _status_tween: Tween

## Writes the status line and fades its scrim in (2026-09-24 liveliness pass,
## owner's pick: the strip shows only for the beats). With `hold` above zero
## the beat passes: the scrim fades back out after that many seconds and
## leaves the sky open. Otherwise it stays until the next call. "" fades it out.
func _set_status(text: String, hold: float = -1.0) -> void:
	if status_label:
		status_label.text = text
	if status_strip == null:
		return
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
	var t := Juice.tokens()
	_status_tween = create_tween()
	_status_tween.tween_property(status_strip, "modulate:a", 0.0 if text == "" else 1.0, t.dur_fast)
	if text != "" and hold > 0.0:
		_status_tween.tween_interval(hold)
		_status_tween.tween_property(status_strip, "modulate:a", 0.0, t.dur_normal)


## Slams the "<hari> selesai" ink stamp down, holds it, and lifts it away as
## the day's summary opens. Under reduce_motion it simply appears.
func _play_day_stamp(day_name: String) -> void:
	if day_stamp == null:
		return
	if day_stamp_label:
		day_stamp_label.text = "%s selesai" % day_name.to_lower()
	day_stamp.pivot_offset = day_stamp.size / 2.0
	var t := Juice.tokens()
	if GameSettings.reduce_motion:
		day_stamp.scale = Vector2.ONE
		day_stamp.modulate.a = 1.0
	else:
		day_stamp.scale = Vector2.ONE * STAMP_SLAM_FROM
		day_stamp.modulate.a = 0.0
		var slam := create_tween().set_parallel(true)
		slam.tween_property(day_stamp, "scale", Vector2.ONE, t.dur_fast) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slam.tween_property(day_stamp, "modulate:a", 1.0, t.dur_instant)
		await slam.finished
	_celebrate_day_end(current_day == DAYS.size() - 1)
	await get_tree().create_timer(STAMP_HOLD).timeout
	var lift := create_tween()
	lift.tween_property(day_stamp, "modulate:a", 0.0, t.dur_fast)


# ─────────────────────────────────────────────────────────────────────────────
## Slide the full-screen event warning through once, captioned with what is
## coming -- a minigame's subject or a random event's name -- and wait for it
## to leave (2026-09-12 event-cards spec, 2.3). The warning plays its own cue.
## `category` tints the notice (a skill category, "Cuaca" or "Sosial") and
## `mode` marks it: MINIGAME, KABAR, or PILIHAN for a choice event.
func _show_event_warning(caption: String, category: String = "", mode: String = "") -> void:
	var warning_scene = event_warning_scene
	if warning_scene == null:
		warning_scene = load("res://Scenes/SchoolSimulation/EventWarning.tscn")

	if warning_scene == null:
		return

	var warning_instance = warning_scene.instantiate()
	add_child(warning_instance)

	if warning_instance.has_method("play_warning"):
		await warning_instance.play_warning(caption, category, mode)
	else:
		await get_tree().create_timer(1.5).timeout
		warning_instance.queue_free()


## The EventDialogue catalog key for a minigame `scene`, or "" when the scene
## failed to load. "" has no dialogue, so a null scene falls through to
## _play_minigame()'s own null guard instead of crashing on .resource_path.
static func minigame_dialogue_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	return EventDialogueCatalog.minigame_key(scene.resource_path)


## Shows the EventDialogue for catalog `key` over the day and waits for it
## (2026-09-14 event-dialogue spec). Returns the player's answer: false only
## for Tolak. With no catalog entry, such as a new minigame without a line
## yet, there is nothing to show and it returns true.
func _show_event_dialogue(key: String) -> bool:
	if not EventDialogueCatalog.has_entry(key):
		return true
	# Shorten (Lobby): the player chose to skip the choice-free minigame lines.
	if GameSettings.skip_event_dialogue and EventDialogueCatalog.shorten_skips(key):
		return true
	var dialogue_scene = event_dialogue_scene
	if dialogue_scene == null:
		dialogue_scene = load("res://Scenes/SchoolSimulation/EventDialogue.tscn")
	if dialogue_scene == null:
		return true
	var e: Dictionary = EventDialogueCatalog.entry(key)
	var roster: Array = []
	if student_manager:
		roster = student_manager.students
	var featured: StudentData = EventDialogueCatalog.pick_featured(roster, e.get("category", ""))
	var day_name: String = DAYS[current_day] if current_day < DAYS.size() else ""
	var dialogue = dialogue_scene.instantiate()
	add_child(dialogue)
	dialogue.open(e, featured, GameState.minggu_ke, GameState.get_max_weeks(), day_name)
	var accepted: bool = await dialogue.closed
	dialogue.queue_free()
	return accepted


func force_event(event_id: int) -> void:
	# Trigger a specific event immediately during simulation
	var day_name = DAYS[current_day] if current_day < DAYS.size() else "Senin"
	events_triggered_this_week += 1
	# Every student on the roster is present for an event, so
	# an event marks the whole roster as having participated.
	for s in GameState.approved_students:
		GameState.run_stats.record_event_student(int(s.get("id", -1)))
	await _run_event(event_id, day_name)
