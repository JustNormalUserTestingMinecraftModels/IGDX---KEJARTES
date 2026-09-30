## The roster hub. AturJadwal routes here; tapping a student's paper card
## sends that student back to AturJadwal to have their week set, and the
## player returns. So this screen exists to answer one question -- "who
## still needs a schedule?" -- which is why the RosterStrip above the
## carousel carries every student's state at once rather than making the
## player page through four cards to find out.
##
## Deliberately NOT @tool. This scene's runtime setup reads the GameState
## autoload and mounts the tutorial panel, and Godot only runs
## a plain script's lifecycle callbacks inside an actually-running game
## tree -- so under the MCP test runner _ready() never fires and the suite
## asserts authored .tscn structure and source text instead. See
## tests/test_student_list.gd's header for the full finding.
extends Control

const PageDotScene: PackedScene = preload("res://Scenes/StudentList/PageDot.tscn")

@export_group("Paper Card Design")
## Custom paper card texture override.
@export var paper_texture: Texture2D = preload("res://Assets/Images/UI/paper.png")
## Custom sticky note texture override.
@export var sticky_note_texture: Texture2D = preload("res://Assets/Images/UI/stickynotes.png")

@export_group("Tutorial")
## Edit this array in the Inspector to customize each tutorial step.
@export var tutorial_steps: Array[TutorialStepData] = []
## The shared onboarding coach-mark the steps show on: the look StudentCard
## ships (its component defaults), so the tutorial has one voice on every screen.
@export var tutorial_panel_scene: PackedScene = preload("res://Scenes/UI/TutorialPanel.tscn")

@onready var color_rect = $ColorRect
@onready var click_area = $ColorRect/ClickArea
## The screen's Safe/UI: the area the tutorial's card and arrow keep to.
@onready var tutorial_safe_ui: Control = $Safe/UI
@onready var card_container = $CardContainer
@onready var left_arrow = %LeftArrow
@onready var right_arrow = %RightArrow
@onready var page_indicator = %PageIndicator
## The carousel's motion (drag, throw, spring-back, the overlapped switch)
## and its single re-entry guard, `busy`. Its signals are wired in the .tscn.
@onready var deck: RosterDeck = %RosterDeck

## A page dot's tint fade to its new state as the deck switches, seconds.
const DOT_TINT_SECONDS := 0.2

static var tutorial_shown := false  # <-- penanda global

var default_students = [
	{
		"id": 1,
		"name": "Marcel",
		"portrait": "res://Assets/Images/MuridPortrait/Marcel.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_marcel.png",
		"mood": 60.0,
		"energy": 55.0,
		"akademis": 28.0,
		"seni_budaya": 48.0,
		"olahraga": 38.0,
		"target_akademis": 52.0,
		"target_seni_budaya": 60.0,
		"target_olahraga": 53.0,
		"target_mood": 50.0,
		"target_energy": 40.0,
		"hobby_category": "Akademis",
		"personality": "Tekun",
		"quirk": "Kutu Buku"
	},
	{
		"id": 2,
		"name": "Doni",
		"portrait": "res://Assets/Images/MuridPortrait/Doni.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_doni.png",
		"mood": 55.0,
		"energy": 55.0,
		"akademis": 38.0,
		"seni_budaya": 22.0,
		"olahraga": 33.0,
		"target_akademis": 50.0,
		"target_seni_budaya": 40.0,
		"target_olahraga": 51.0,
		"target_mood": 40.0,
		"target_energy": 35.0,
		"hobby_category": "Olahraga",
		"personality": "Aktif",
		"quirk": "Semangat Juang"
	},
	{
		"id": 3,
		"name": "Andi",
		"portrait": "res://Assets/Images/MuridPortrait/Andi.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_andi.png",
		"mood": 60.0,
		"energy": 60.0,
		"akademis": 48.0,
		"seni_budaya": 55.0,
		"olahraga": 32.0,
		"target_akademis": 60.0,
		"target_seni_budaya": 64.0,
		"target_olahraga": 53.0,
		"target_mood": 60.0,
		"target_energy": 55.0,
		"hobby_category": "SeniBudaya",
		"personality": "Kreatif",
		"quirk": "Penasaran"
	},
	{
		"id": 4,
		"name": "Citra",
		"portrait": "res://Assets/Images/MuridPortrait/Citra.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_citra.png",
		"mood": 35.0,
		"energy": 60.0,
		"akademis": 28.0,
		"seni_budaya": 25.0,
		"olahraga": 15.0,
		"target_akademis": 40.0,
		"target_seni_budaya": 43.0,
		"target_olahraga": 39.0,
		"target_mood": 35.0,
		"target_energy": 45.0,
		"hobby_category": "Olahraga",
		"personality": "Seni Dalam Kesunyian",
		"quirk": "Penyendiri"
	},
	{
		"id": 5,
		"name": "Shinta",
		"portrait": "res://Assets/Images/MuridPortrait/Shinta.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_shinta.png",
		"mood": 30.0,
		"energy": 40.0,
		"akademis": 35.0,
		"seni_budaya": 22.0,
		"olahraga": 22.0,
		"target_akademis": 53.0,
		"target_seni_budaya": 37.0,
		"target_olahraga": 37.0,
		"target_mood": 30.0,
		"target_energy": 35.0,
		"hobby_category": "Akademis",
		"personality": "Santai",
		"quirk": "Biang Onar"
	},
	{
		"id": 6,
		"name": "Thea",
		"portrait": "res://Assets/Images/MuridPortrait/Thea.png",
		"splash": "res://Assets/Images/SplashArtMurid/splash_thea.png",
		"mood": 55.0,
		"energy": 50.0,
		"akademis": 33.0,
		"seni_budaya": 22.0,
		"olahraga": 38.0,
		"target_akademis": 45.0,
		"target_seni_budaya": 46.0,
		"target_olahraga": 53.0,
		"target_mood": 50.0,
		"target_energy": 45.0,
		"hobby_category": "SeniBudaya",
		"personality": "Kreatif",
		"quirk": "Pekerja Keras"
	}
]

var active_students: Array = []
var card_nodes: Array[RosterCard] = []
var current_card_index: int = 0
var _dots_tween: Tween

# Tutorial UI variables
const TutorialArrow: PackedScene = preload("res://Scenes/UI/TutorialArrow.tscn")

## Schedule category -> week-strip glyph, keyed by every spelling the
## day_schedules data can carry. Anything unresolved (an empty category,
## the "-" placeholder for an unscheduled day) falls back to the libur
## icon. Mirrors DesignTokens.category_color()'s key set.
## The glyph each schedule category shows on its sticky note.
##
## These are the team's own authored art, not the generated placeholder
## set: the four skill/needs icons are the same 128x128 StudentCard
## stat_* icons the stat rows use, so a day's note and that student's
## stat row carry the identical symbol. Libur borrows stat_mood.
## Istirahat and Wirausaha have no stat of their own, so they wear their
## dedicated UI/Icons/cat_*.svg category icons -- the same ones as the
## roster card's trait chip (RosterCard.SPECIALTY_ICONS) and AturJadwal's
## sticky notes.
##
## A category absent from this map draws no glyph at all -- see the
## lookup in _setup_students().
const CATEGORY_ICONS := {
	"Akademis": "res://Assets/Images/StudentCard/stat_akademis.png",
	"Akademik": "res://Assets/Images/StudentCard/stat_akademis.png",
	"SeniBudaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
	"Seni Budaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
	"Olahraga": "res://Assets/Images/StudentCard/stat_olahraga.png",
	"Istirahat": "res://Assets/Images/UI/Icons/cat_istirahat.svg",
	"Wirausaha": "res://Assets/Images/UI/Icons/cat_wirausaha.svg",
	"Libur": "res://Assets/Images/StudentCard/stat_mood.png",
}
var current_step := 0
var tutorial_active := true
var _tutorial_panel: TutorialPanel
var _tutorial_prompt_label: Label
## The controls the current step highlights; the card and the arrow are placed from them.
var _step_targets: Array[Control] = []
var _blink_tween: Tween
var _panel_tween: Tween
var _tutorial_arrow: Control = null

func _ready():
	_setup_tutorial()
	_setup_students()
	_set_front_idle(not tutorial_active)
	_setup_navigation_arrows()
	AudioDirector.play_bgm_playlist(&"lobby")

## Runs or pauses the front card's idle loops (breath, "tap me" glow). The
## tutorial holds them paused while it is up and resumes them when it ends.
func _set_front_idle(on: bool) -> void:
	if card_nodes.is_empty():
		return
	card_nodes[current_card_index].set_idle(on)

func _setup_navigation_arrows():
	if left_arrow:
		_setup_button_juice(left_arrow)
		if not left_arrow.pressed.is_connected(_prev_card):
			left_arrow.pressed.connect(_prev_card)
		(left_arrow.get_node(^"NudgeLoop") as NudgeLoop).enabled = true
	if right_arrow:
		_setup_button_juice(right_arrow)
		if not right_arrow.pressed.is_connected(_next_card):
			right_arrow.pressed.connect(_next_card)
		(right_arrow.get_node(^"NudgeLoop") as NudgeLoop).enabled = true

## Deal one day-note its pin height: 0 up, 1 middle, 2 down.
##
## Hashed from the student and the day rather than drawn from a RNG, on
## purpose. The strip should look hand-pinned, but a given student's
## Wednesday has to hang at the SAME height every time the player swipes
## back to that card -- a note that jumps on every visit reads as a bug,
## not as charm. Hashing the pair also varies the five days within one
## card and varies the pattern between students, which one shared
## sequence would not.
func _pin_slot_for(student: Dictionary, day_name: String) -> int:
	var key: String = str(student.get("id", student.get("name", "")))
	return absi(("%s|%s" % [key, day_name]).hash()) % 3

func _setup_students():
	var students = GameState.approved_students
	if students.is_empty():
		students = default_students
	active_students = students

	card_nodes.clear()

	for i in range(4):
		var node_name = "Murid" + str(i + 1)
		var murid_node = card_container.get_node_or_null(node_name)
		if not murid_node:
			continue

		if i < active_students.size():
			var student_data = active_students[i]
			card_nodes.append(murid_node)

			if paper_texture:
				murid_node.texture = paper_texture

			# Set Portrait
			# RosterCard's bands live under its inner Paper; every node read
			# here is a %unique name in RosterCard.tscn, so no path is spelt.
			var portrait_node = murid_node.get_node_or_null("%Portrait")
			var portrait_path = StudentSkins.portrait_for(student_data)
			if portrait_node and portrait_path != "" and ResourceLoader.exists(portrait_path):
				portrait_node.texture = load(portrait_path)

			# Set Name
			var nama_label = murid_node.get_node_or_null("%Nama")
			if nama_label:
				nama_label.text = student_data.get("name", "MURID " + str(i + 1))

			# Schedule calculation
			var student_id = student_data.get("id", null)
			var fully_scheduled := _is_student_scheduled(student_data)
			var day_schedules_for_student: Dictionary = {}
			if student_id != null and GameState.day_schedules.has(student_id):
				day_schedules_for_student = GameState.day_schedules[student_id]

			# Drive RosterCard's trait chips and catatan guru. specialty is
			# hobby_category; persona is the clean `personality` value
			# ("Tekun") -- NOT the `persona` key, which is the prefixed
			# "Persona Tekun". Both approved_students and default_students
			# carry personality/quirk/hobby_category as clean strings.
			murid_node.specialty = student_data.get("hobby_category", "")
			murid_node.persona = student_data.get("personality", "")
			murid_node.quirk = student_data.get("quirk", "")
			murid_node.is_scheduled = fully_scheduled

			# Status Badges
			var belum_btn = murid_node.get_node_or_null("%Belum")
			var sudah_btn = murid_node.get_node_or_null("%Sudah")
			if belum_btn:
				belum_btn.visible = not fully_scheduled
			if sudah_btn:
				sudah_btn.visible = fully_scheduled

			_apply_card_week(murid_node, student_data, day_schedules_for_student)

			# Attach CardButton signals for 100% click & swipe reliability
			var card_button = murid_node.get_node_or_null("CardButton")
			if card_button:
				if not card_button.gui_input.is_connected(_on_card_gui_input.bind(student_data, murid_node)):
					card_button.gui_input.connect(_on_card_gui_input.bind(student_data, murid_node))
				if not card_button.pressed.is_connected(_on_card_pressed.bind(student_data, murid_node)):
					card_button.pressed.connect(_on_card_pressed.bind(student_data, murid_node))
			else:
				if not murid_node.gui_input.is_connected(_on_card_gui_input.bind(student_data, murid_node)):
					murid_node.gui_input.connect(_on_card_gui_input.bind(student_data, murid_node))

			# Wire the matching roster-strip avatar ONCE here, not in the
			# per-sync loop -- _sync_roster_strip() runs on every page turn
			# and its is_connected() guard can never match a bound callable.
			# "%%" is a literal "%": the unique-name prefix, escaped for the format.
			var roster_avatar = get_node_or_null("%%RosterStrip/Avatar%d" % (i + 1))
			if roster_avatar and not roster_avatar.pressed.is_connected(_on_avatar_pressed.bind(i)):
				roster_avatar.pressed.connect(_on_avatar_pressed.bind(i))

		else:
			murid_node.hide()

	_build_page_indicators()
	_init_carousel_state()
	_sync_roster_strip()

## Each note's activity/glyph/pin; card.apply_week() owns scheduled/days_scheduled.
func _apply_card_week(card: RosterCard, student_data: Dictionary, day_schedules_for_student: Dictionary) -> void:
	var sticky_container: Node = card.get_node_or_null("%StickyNotesContainer")
	if sticky_container:
		for day_name in RosterCard.WEEKDAY_KEYS:
			var sticky_node := sticky_container.get_node_or_null(day_name) as StickyNote
			if sticky_node:
				if sticky_note_texture:
					sticky_node.texture = sticky_note_texture

				var is_day_set: bool = day_schedules_for_student.has(day_name)
				var cat := ""
				if is_day_set:
					cat = day_schedules_for_student[day_name].get("category", "")
					sticky_node.activity = cat if cat != "" else "Terjadwal"
				else:
					sticky_node.activity = "-"

				# Category glyph for the week strip (Part 3). An
				# unscheduled day gets NO glyph rather than a stand-in:
				# giving every blank day the same icon made all five
				# notes read as identical, which is the opposite of
				# what the strip is for.
				var icon_path: String = CATEGORY_ICONS.get(cat, "")
				sticky_node.icon_texture = (
					load(icon_path) if icon_path != "" else null)

				sticky_node.pin_slot = _pin_slot_for(
					student_data, day_name)
	card.apply_week(day_schedules_for_student)

## True when every weekday in RosterCard.WEEKDAY_KEYS has a category assigned for this
## student. Same source as the Belum/Sudah badge in _setup_students(), so
## the strip and the stamp can never disagree.
func _is_student_scheduled(student: Dictionary) -> bool:
	var student_id = student.get("id", null)
	if student_id == null or not GameState.day_schedules.has(student_id):
		return false
	var sched = GameState.day_schedules[student_id]
	for day in RosterCard.WEEKDAY_KEYS:
		if not sched.has(day):
			return false
	return true

## Pushes every student's scheduled state and the current index onto the
## strip. Called after _setup_students() and as the deck starts a switch,
## so the strip and the carousel never disagree.
func _sync_roster_strip() -> void:
	var strip := get_node_or_null("%RosterStrip")
	if strip == null:
		return
	for i in range(active_students.size()):
		var avatar := strip.get_node_or_null("Avatar%d" % (i + 1))
		if avatar == null:
			continue
		avatar.visible = true
		var student: Dictionary = active_students[i]
		var portrait_path: String = StudentSkins.portrait_for(student)
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			avatar.portrait_texture = load(portrait_path)
		avatar.is_scheduled = _is_student_scheduled(student)
		avatar.is_current = (i == current_card_index)

	# A roster smaller than four (grade 7's fallback is two students)
	# leaves surplus avatars stranded in red rings -- hide them.
	for i in range(active_students.size(), 4):
		var extra := strip.get_node_or_null("Avatar%d" % (i + 1))
		if extra:
			extra.visible = false

## Jumps straight to a student instead of paging. Reuses the carousel's
## own switch so the slide direction and the animation guard still apply.
func _on_avatar_pressed(index: int) -> void:
	if deck.busy or index == current_card_index:
		return
	# -1 throws left, as Next does: a later student comes off the stack.
	var direction := -1 if index > current_card_index else 1
	_switch_card(index, direction)

func _build_page_indicators():
	if not page_indicator:
		return
	for child in page_indicator.get_children():
		child.queue_free()

	for i in range(card_nodes.size()):
		page_indicator.add_child(PageDotScene.instantiate())

func _init_carousel_state():
	if card_nodes.is_empty():
		return
	current_card_index = RosterCard.initial_card_index(active_students, GameState.selected_student)
	for i in range(card_nodes.size()):
		var card = card_nodes[i]
		if i == current_card_index:
			card.show()
			RosterDeck.place_at_rest(card)
		else:
			card.hide()
	deck.set_card_count(card_nodes.size())
	_update_page_indicators()
	Juice.stagger_in(card_nodes)
	_stagger_card_notes(card_nodes[current_card_index])
	card_nodes[current_card_index].set_front(true)

## Reveal one card's five day-notes with a shorter step than the
## card-level stagger, as if they're being pinned up as the card opens.
func _stagger_card_notes(card: Control) -> void:
	var sticky_container = card.get_node_or_null("%StickyNotesContainer")
	if not sticky_container:
		return
	Juice.stagger_in(sticky_container.get_children(), DesignTokens.load_default().stagger_step * 0.5)

## Fades each page dot to its state (gold current, green scheduled, red
## not) on one stored Tween, killed if the next switch starts mid-fade.
func _update_page_indicators():
	var tokens := DesignTokens.load_default()
	if _dots_tween and _dots_tween.is_valid():
		_dots_tween.kill()
	_dots_tween = null
	if not page_indicator:
		push_error("StudentList: %PageIndicator is missing")
		return
	var dot_count: int = mini(page_indicator.get_child_count(), active_students.size())
	if dot_count > 0 and not GameSettings.reduce_motion:
		_dots_tween = create_tween().set_parallel(true)
	for i: int in range(dot_count):
		var tone: Color = tokens.state_danger
		if i == current_card_index:
			tone = tokens.currency_gold
		elif _is_student_scheduled(active_students[i]):
			tone = tokens.state_success
		if _dots_tween:
			_dots_tween.tween_property(page_indicator.get_child(i), "self_modulate", tone, DOT_TINT_SECONDS)
		else:
			page_indicator.get_child(i).self_modulate = tone

	if left_arrow: left_arrow.visible = card_nodes.size() > 1
	if right_arrow: right_arrow.visible = card_nodes.size() > 1

func _next_card():
	if deck.busy or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index + 1) % card_nodes.size()
	_switch_card(target_index, -1)

func _prev_card():
	if deck.busy or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index - 1 + card_nodes.size()) % card_nodes.size()
	_switch_card(target_index, 1)

## Hands the swap to the deck: one overlapped timeline, never awaited here.
## The rest of the switch answers the deck's signals below.
func _switch_card(new_index: int, direction: int) -> void:
	if deck.busy or new_index == current_card_index:
		return
	var old_card: RosterCard = card_nodes[current_card_index]
	var new_card: RosterCard = card_nodes[new_index]
	current_card_index = new_index
	old_card.set_front(false)
	deck.switch(old_card, new_card, direction)

## The deck started a switch: the strip and the dots follow now, during
## the slide, not after it lands.
func _on_deck_switched(_card: Control) -> void:
	_update_page_indicators()
	_sync_roster_strip()

## A drag picked the front card up: its idle loops pause under the finger.
func _on_deck_picked_up(card: RosterCard) -> void:
	card.set_idle(false)

## A release threw the front card; the carousel's own paging answers it.
func _on_deck_thrown(kind: int) -> void:
	if kind == RosterDeck.Release.NEXT:
		_next_card()
	else:
		_prev_card()

## The deck is at rest. A card that LANDED re-drops its week and replays
## its entry; one that only sprang back from a short drag resumes its idle
## loops without re-arriving (see RosterCard.set_idle).
func _on_deck_settled(front: RosterCard, landed: bool) -> void:
	if not landed:
		front.set_idle(not tutorial_active)
		return
	_stagger_card_notes(front)
	front.set_front(true)
	if tutorial_active:
		front.set_idle(false)
	# The Navigasi Card step (index 2 since the Status Jadwal step was
	# inserted at 1) auto-advances once the card slide it asked for lands.
	if tutorial_active and current_step == 2:
		_next_step()

func _on_card_pressed(student_data: Dictionary, card_node: Control):
	# The deck read this same release first: a drag is not a tap.
	if not deck.accepts_tap():
		return
	if tutorial_active:
		if current_step == 3:  # Pilih Murid, the final step, locks onto the card
			_end_tutorial()
			_on_student_selected(student_data, card_node)
		else:
			_reject_tutorial_tap()
		return

	_on_student_selected(student_data, card_node)

## Every pointer event on the front card goes to the deck, which follows
## the finger and answers a throw through its `thrown` signal.
func _on_card_gui_input(event: InputEvent, _student_data: Dictionary, card_node: Control) -> void:
	deck.handle_pointer(event, card_node)

func _on_student_selected(student: Dictionary, card_node: Control = null):
	if deck.busy:
		return
	deck.busy = true  # the screen is leaving: hold the deck for good

	if card_node and is_instance_valid(card_node):
		card_node.pivot_offset = card_node.size / 2.0

		# Fast cute squash & stretch bounce
		var tw1 = create_tween()
		tw1.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw1.tween_property(card_node, "scale", Vector2(0.9, 1.1), 0.07)
		tw1.tween_property(card_node, "scale", Vector2(1.0, 1.0), 0.07)
		await tw1.finished

		# Discard paper off-screen to right smoothly
		var screen_width = get_viewport_rect().size.x
		var tw2 = create_tween().set_parallel(true)
		tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw2.tween_property(card_node, "position:x", card_node.position.x + screen_width, 0.25)
		tw2.tween_property(card_node, "rotation_degrees", 15.0, 0.25)
		tw2.tween_property(card_node, "modulate:a", 0.0, 0.22)
		await tw2.finished

	AudioDirector.play_sfx(&"select")
	print("Murid dipilih: ", student.get("name", ""))
	GameState.selected_student = student
	Transition.change_scene("res://Scenes/AturJadwal/AturJadwal.tscn")

# --- Tutorial System ---

func _setup_tutorial():
	if GameState.tutorials_bypassed or tutorial_shown:
		if color_rect:
			color_rect.hide()
		tutorial_active = false
		return

	if tutorial_steps.is_empty():
		_populate_default_tutorial_steps()

	var viewport_size = get_viewport_rect().size
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		var shader = load("res://Scripts/Shaders/spotlight.gdshader")
		if shader:
			mat = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("overlay_color", DesignTokens.load_default().scrim_color())
			mat.set_shader_parameter("rect_size", viewport_size)
			color_rect.material = mat
	else:
		mat.set_shader_parameter("rect_size", viewport_size)

	_fit_color_rect_to_viewport()
	get_tree().root.size_changed.connect(_fit_color_rect_to_viewport)

	_tutorial_arrow = TutorialArrow.instantiate()
	_tutorial_arrow.visible = false
	color_rect.add_child(_tutorial_arrow)

	_build_tutorial_panel()

	if color_rect:
		color_rect.show()
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if click_area:
		if click_area.has_signal("pressed"):
			if not click_area.pressed.is_connected(_next_step):
				click_area.pressed.connect(_next_step)
		else:
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP
			if not click_area.gui_input.is_connected(_on_click_area_gui_input):
				click_area.gui_input.connect(_on_click_area_gui_input)

	_show_step(0)

func _populate_default_tutorial_steps():
	var defaults = [
		["Muridmu", "Di sini kalian bebas memilih murid-murid yang belum terjadwalkan untuk belajar selama seminggu!", "CardContainer"],
		["Status Jadwal", "Hijau berarti sudah terjadwal, merah berarti belum. Ketuk untuk langsung ke murid itu!", "RosterStrip"],
		["Navigasi Card", "Geser layar atau tekan tombol panah kanan untuk melihat murid lainnya!", "RightArrow"],
		["Pilih Murid", "Bagus! Sekarang tekan kertas dokumen murid ini untuk mulai mengatur jadwal belajarnya!", ""]
	]
	for entry in defaults:
		var step = TutorialStepData.new()
		step.title = entry[0]
		step.text = entry[1]
		step.target_node_path = entry[2]
		tutorial_steps.append(step)

## Mounts the shared TutorialPanel in the spotlight overlay. Keeps its prompt
## label, which _start_prompt_blink fades; every step's text goes through
## TutorialPanel.show_step() in _show_step.
func _build_tutorial_panel() -> void:
	_tutorial_panel = TutorialPanel.mount(tutorial_panel_scene, color_rect, click_area)
	_tutorial_prompt_label = _tutorial_panel.prompt_label
	_start_prompt_blink()
	_position_tutorial_panel()

func _start_prompt_blink():
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_tutorial_prompt_label.modulate.a = 1.0
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 0.25, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_tutorial_prompt_label, "modulate:a", 1.0, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Seats the card and the arrow for the current step's targets, inside the
## screen's Safe/UI (TutorialPanel.place_step).
func _position_tutorial_panel() -> void:
	TutorialPanel.place_step(_tutorial_panel, tutorial_safe_ui, color_rect, _step_targets, _tutorial_arrow)

func _fit_color_rect_to_viewport():
	var viewport_size = get_viewport_rect().size
	color_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	color_rect.position = -global_position
	color_rect.size = viewport_size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	if tutorial_active and _tutorial_panel and is_instance_valid(_tutorial_panel):
		_position_tutorial_panel()

func _next_step():
	current_step += 1
	if current_step >= tutorial_steps.size():
		_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int) -> void:
	if index < 0 or index >= tutorial_steps.size():
		return
	current_step = index
	var step := tutorial_steps[index]

	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_step_targets = _targets_for_step(index)
	if _step_targets.is_empty():
		_clear_highlight()
	else:
		_highlight_multiple(_step_targets)

	var prompt := TutorialPanel.DEFAULT_PROMPT
	if step.prompt_text != "":
		prompt = step.prompt_text
	elif index == 2:
		prompt = "TEKAN PANAH ATAU GESER UNTUK PINDAH MURID!"
	elif index == 3:
		prompt = "TEKAN KERTAS UNTUK MEMILIH MURID!"
	# The panel's own step pill is this screen's one counter ("Langkah n / N").
	_tutorial_panel.show_step(step.title, step.text, prompt, index + 1, tutorial_steps.size())

	_position_tutorial_panel()

	# Snappy 0.12s panel animation without frame delays
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(_tutorial_panel, "scale", Vector2(1.0, 1.0), 0.12)
	_panel_tween.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.10)

	if index == 0 or index == 1:
		# Muridmu and Status Jadwal are spotlight-only: the scrim
		# blocks, a tap anywhere advances.
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	elif index == 2:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if left_arrow: left_arrow.mouse_filter = Control.MOUSE_FILTER_STOP
		if right_arrow: right_arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	elif index == 3:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

## The controls step `index` highlights: the right arrow for the navigation
## step, the front card for the last, otherwise the step's target_node_path.
func _targets_for_step(index: int) -> Array[Control]:
	var targets: Array[Control] = []
	if index == 2:
		var arrow_target: Control = right_arrow if right_arrow else left_arrow
		if arrow_target and is_instance_valid(arrow_target):
			targets.append(arrow_target)
	elif index == 3 and not card_nodes.is_empty():
		var active_card := card_nodes[current_card_index]
		if active_card and is_instance_valid(active_card):
			targets.append(active_card)
	else:
		for path in tutorial_steps[index].target_node_path.split(","):
			var trimmed := path.strip_edges()
			if trimmed == "":
				continue
			var target := _find_target_node(trimmed) as Control
			if target:
				targets.append(target)
	return targets

## A card tap before the last step: the tutorial wants another control (the
## right arrow, at step 2), and the tap used to be dropped without a sound, so
## the screen looked broken. Now the error cue plays, the control the step
## wants shakes and its sibling buttons dim (TutorialPanel.answer_wrong_tap).
## The card stays up and says nothing: the motion says "not that one, this one."
func _reject_tutorial_tap() -> void:
	var targets := _targets_for_step(current_step)
	if targets.is_empty():
		AudioDirector.play_sfx(&"error")
		return
	TutorialPanel.answer_wrong_tap(targets[0])

func _find_target_node(path_str: String) -> Node:
	# A bare name ("RightArrow", "RosterStrip") is found by unique name wherever
	# it sits (Safe/UI since the 2026-09-15 tall-phone pass).
	var node = get_node_or_null("%" + path_str)
	if node:
		return node
	node = get_node_or_null(path_str)
	if node:
		return node
	if card_container:
		node = card_container.get_node_or_null(path_str)
		if node:
			return node
	return null

## Cuts the spotlight hole around `controls`. The arrow is not placed here: it
## needs the card's rectangle to stay off it, so _position_tutorial_panel
## places both once the card has sized itself.
func _highlight_multiple(controls: Array, padding: float = TutorialPanel.SPOT_PADDING):
	if color_rect.material == null:
		var shader = load("res://Scripts/Shaders/spotlight.gdshader")
		if shader:
			var fallback := ShaderMaterial.new()
			fallback.shader = shader
			fallback.set_shader_parameter("overlay_color", DesignTokens.load_default().scrim_color())
			fallback.set_shader_parameter("rect_size", get_viewport_rect().size)
			color_rect.material = fallback
	if not TutorialPanel.cut_hole(color_rect, controls, padding):
		_clear_highlight()

func _clear_highlight():
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("hole_pos", Vector2(-9999.0, -9999.0))
	mat.set_shader_parameter("hole_size", Vector2.ZERO)
	if _tutorial_arrow:
		_tutorial_arrow.hide()

func _end_tutorial():
	tutorial_shown = true
	tutorial_active = false
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_panel.hide()
	if color_rect:
		color_rect.hide()
	_set_front_idle(true)

func _on_click_area_gui_input(event: InputEvent):
	# Steps 0 (Muridmu) and 1 (Status Jadwal) are both spotlight-only
	# -- a tap anywhere advances.
	if tutorial_active and (current_step == 0 or current_step == 1):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_next_step()

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
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.15)

func _on_btn_mouse_exited(btn: Control):
	if not is_instance_valid(btn):
		return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
