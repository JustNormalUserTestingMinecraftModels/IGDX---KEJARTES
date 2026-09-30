extends Control

## The Lobby hub: the screen between weeks, and the launch point for every
## other screen (StudentCard, AturJadwal, Koperasi, Inventory, ReportCard).
##
## Draws the roster diorama from GameState.approved_students -- a portrait
## and matching desk art per approved student slot, keyed by name -- and
## the daily-login popup, a DailyLoginPanel that owns the claim and its
## GameState writes; this screen owns its backdrop blur. Writes
## GameState.lobby_tutorial_completed once its own tutorial finishes;
## every other button here just transitions to another screen.

@export_group("Background Layers")
## Lobby backdrop. Null falls back to loading lobby.png directly.
@export var bg_texture: Texture2D
## Portrait shown in a roster slot when that student has no
## StudentData.avatar_texture of their own.
@export var default_portrait: Texture2D = preload("res://Assets/Images/MuridPortrait/Thea.png")

## Name prefix marking a slot child as one student's desk art. Everything
## after the prefix is the student name it belongs to, so adding a
## character means duplicating a Hand_* node in Lobby.tscn and renaming it
## -- no code change here.
const HAND_NODE_PREFIX := "Hand_"

## Which Hand_* node stands in for a student with no node of their own.
## Doni's is the deliberate choice: his art is desk props with no arms, so
## a wrong match reads as a plain desk rather than as another character's
## hands.
const HAND_FALLBACK_NAME := "Doni"

## The Settings screen's script; the gear sets where its back button returns.
const SettingsScript := preload("res://Scripts/UI/Settings.gd")

@export_group("Idle Motion")
## Subtle looping vertical bob applied to the diorama's portrait
## containers, so the hub does not read as a still image.
@export var idle_bob_pixels: float = 6.0
## Full up-down-up cycle length (seconds) for idle_bob_pixels.
@export var idle_bob_period: float = 3.2

@export_group("Layered Faces")
## Multi-layer face rigs (StudentFace: base, eye white, iris, lashes, brows
## and a blink lid) that replace the flat Portrait TextureRect for the students
## that have one. A rig is matched to a roster slot by its own student_name,
## so adding a character is a matter of dropping their .tscn in here; a
## student with no rig keeps the flat portrait. Left empty, _ready() falls
## back to Citra's rig, the same shape as hand_fallback above.
@export var face_rigs: Array[PackedScene] = []

@export_group("Skins")
## The skin picker opened by SkinSwitchButton.
@export var skin_select_scene: PackedScene = preload("res://Scenes/Skins/SkinSelect.tscn")


@onready var color_rect = $ColorRect
@onready var click_area: Button = $ColorRect/ClickArea
## The HUD's Safe/UI: the area the tutorial's card and arrow keep to.
@onready var tutorial_safe_ui: Control = $Safe/UI
# The HUD sits in Safe/UI/Hud/BookHud and the diorama in Classroom since the
# 2026-09-15 tall-phone pass; unique names find them wherever they sit.
@onready var student_button: Button = %Student
@onready var jadwal_button: Button = %Jadwal
@onready var koperasi_button: Button = %Koperasi
@onready var report_student_button: Button = %ReportStudent
@onready var inventory_button: Button = %Inventory
@onready var settings_button = %SettingsButton
@onready var achievement_button = %AchievementButton
@onready var skin_switch_button = %SkinSwitchButton

@onready var money_label = get_node("%DisplayUang/Label")
@onready var daily_login_btn = %DailyLogin
@onready var daily_reward: DailyLoginPanel = %DailyReward
@onready var progress_header: LobbyProgressHeader = %ProgressHeader
@onready var hud: LobbyHud = %Hud
@onready var earn_panel: DapatkanUang = %DapatkanUang
@onready var plus_button: Button = %PlusUang

@onready var portraits_back: Control = %StudentPortraitsContainer_Back
@onready var portraits_front: Control = %StudentPortraitsContainer_Front

@onready var portrait_slots = [
	get_node("%StudentPortraitsContainer_Back/Slot1"),
	get_node("%StudentPortraitsContainer_Back/Slot2"),
	get_node("%StudentPortraitsContainer_Front/Slot3"),
	get_node("%StudentPortraitsContainer_Front/Slot4"),
]
@onready var hand_slots = [
	get_node("%StudentHandsContainer_Back/Slot1"),
	get_node("%StudentHandsContainer_Back/Slot2"),
	get_node("%StudentHandsContainer_Front/Slot3"),
	get_node("%StudentHandsContainer_Front/Slot4"),
]

## The daily-reward popup's backdrop blur: shader lod and darkness at
## full strength, and how long it takes to come in and to go out.
const BLUR_LOD := 3.0
const BLUR_DARKNESS := 0.3
const BLUR_IN_SECONDS := 0.25
const BLUR_OUT_SECONDS := 0.15

@export_group("Tutorial")
## Steps shown the first time the player reaches the Lobby.
@export var tutorial_phase1_steps: Array[TutorialStepData] = []
## Steps shown when returning to the Lobby from StudentCard
## (GameState.returned_from_student_card), instead of phase1's steps.
@export var tutorial_phase2_steps: Array[TutorialStepData] = []
## The shared onboarding coach-mark the steps show on: the look StudentCard
## ships (its component defaults), so the tutorial has one voice on every screen.
@export var tutorial_panel_scene: PackedScene = preload("res://Scenes/UI/TutorialPanel.tscn")

const TutorialArrow: PackedScene = preload("res://Scenes/UI/TutorialArrow.tscn")

var current_step := 0
var current_phase_steps: Array[TutorialStepData] = []
var tutorial_active := true
var _tutorial_panel: TutorialPanel
var _tutorial_prompt_label: Label
## The controls the current step highlights; the card and the arrow are placed from them.
var _step_targets: Array[Control] = []
var _blink_tween: Tween
var _tutorial_arrow: Control = null

var blur_overlay: ColorRect
var reward_popup_open := false

@onready var bg_layer = %BGLayer

## Seated students' chatter (2026-09-19 student-chatter spec); null in an
## older scene without the Chatter node.
@onready var chatter: LobbyChatter = get_node_or_null("Chatter") as LobbyChatter
## True while SkinSelect is open; mutes the chatter.
var _skin_select_open := false

## The front row's idle bob starts this far (a fraction of idle_bob_period)
## behind the back row's, so the two containers never move in lockstep.
const FRONT_ROW_BOB_PHASE := 0.25

func _ready() -> void:
	if bg_texture:
		bg_layer.texture = bg_texture
	else:
		bg_layer.texture = load("res://Assets/Images/UI/lobby.png")

	if face_rigs.is_empty():
		face_rigs = [load("res://Scenes/Lobby/CitraFace.tscn")]

	GameState.initialize_grade_targets()
	progress_header.refresh()

	if chatter:
		chatter.can_speak = _chatter_allowed
		# The HUD sits over the front-row faces; its taps are not theirs.
		chatter.tap_blockers = [progress_header] + hud.tap_blockers()
	_setup_students()
	_start_idle_bob(portraits_back, 0.0)
	_start_idle_bob(portraits_front, idle_bob_period * FRONT_ROW_BOB_PHASE)

	if tutorial_phase1_steps.is_empty() or tutorial_phase2_steps.is_empty():
		_populate_default_tutorial_steps()

	var viewport_size: Vector2 = get_viewport_rect().size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	call_deferred("_fit_color_rect_to_viewport")
	get_tree().root.size_changed.connect(_fit_color_rect_to_viewport)

	_tutorial_arrow = TutorialArrow.instantiate()
	_tutorial_arrow.visible = false
	color_rect.add_child(_tutorial_arrow)

	_build_tutorial_panel()

	for btn in [student_button, jadwal_button, koperasi_button, report_student_button, inventory_button, settings_button, achievement_button, skin_switch_button, daily_login_btn, daily_reward.claim_button]:
		_setup_button_juice(btn)

	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not achievement_button.pressed.is_connected(_on_achievement_pressed):
		achievement_button.pressed.connect(_on_achievement_pressed)
	if not skin_switch_button.pressed.is_connected(_on_skin_switch_pressed):
		skin_switch_button.pressed.connect(_on_skin_switch_pressed)
	skin_switch_button.disabled = GameState.approved_students.is_empty()

	AudioDirector.play_bgm_playlist(&"lobby")

	if GameState.lobby_tutorial_completed or GameState.minggu_ke > 1:
		GameState.lobby_tutorial_completed = true
		color_rect.hide()
		tutorial_active = false
		student_button.visible = false
		jadwal_button.visible = true
		student_button.disabled = false

		_connect_hud_buttons()

		_create_blur_overlay()
		_setup_daily_login()
		hud.activate(true)
		return

	_start_tutorial()

## The first-visit path of _ready: shows the spotlight overlay, sets the HUD
## buttons for this phase (phase 2's steps when the player is back from
## StudentCard, else phase 1's), wires the taps and starts the first step.
func _start_tutorial() -> void:
	# The scene keeps the overlay hidden (visible = false) so the classroom shows
	# in the editor. An editor save once baked that state into the file while
	# nothing in code turned the overlay on, and the tutorial ran unseen for three
	# weeks. So the path that teaches shows the overlay itself, before step one;
	# the completed path in _ready and _end_tutorial hide it again.
	color_rect.show()
	if GameState.returned_from_student_card:
		student_button.visible = false
		jadwal_button.visible = true
		current_phase_steps = tutorial_phase2_steps.duplicate()
	else:
		student_button.visible = true
		jadwal_button.visible = false

		student_button.disabled = true

		current_phase_steps = tutorial_phase1_steps.duplicate()

	_connect_hud_buttons()

	if not click_area.pressed.is_connected(_next_step):
		click_area.pressed.connect(_next_step)

	_show_step(0)
	_create_blur_overlay()
	_setup_daily_login()

## Wires every HUD button and the reopen gate. Called once per Lobby, from
## whichever path _ready takes, so no is_connected guard is needed (the scene
## holds no connections).
func _connect_hud_buttons() -> void:
	student_button.pressed.connect(_on_student_pressed)
	jadwal_button.pressed.connect(_on_jadwal_pressed)
	koperasi_button.pressed.connect(_on_koperasi_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	report_student_button.pressed.connect(_on_report_student_pressed)
	plus_button.pressed.connect(earn_panel.open)
	plus_button.disabled = not earn_panel.is_available()  # free coins: debug only
	earn_panel.paid.connect(_on_wallet_paid)
	hud.can_reopen = _chatter_allowed  # popups keep the HUD down too

## Shows the one Hand_<Name> node in this slot that matches the student
## sitting here, and hides its five siblings.
##
## Every slot carries a hand node per student, each positioned and scaled
## by hand in the 2D viewport against the real desks. That is deliberate:
## the six art files were drawn at different scales and cropped without a
## shared registration point, so no single rule lines all of them up with
## the shoulders. The transforms are authored data, not something this
## script computes -- it only picks which one is visible, and must never
## write position, size or scale, or it would clobber that authoring.
##
## A name with no matching node (a stock Murid1-6 portrait, or a roster
## seeded by a test) falls back to HAND_FALLBACK_NAME's node, so the slot
## shows a plain desk rather than nothing.
func _show_hand_for(h_slot: Node, student_name: String) -> void:
	var matched: Node = null
	var fallback: Node = null
	for child in h_slot.get_children():
		if not child.name.begins_with(HAND_NODE_PREFIX):
			continue
		child.hide()
		var who := String(child.name).substr(HAND_NODE_PREFIX.length())
		if who == student_name:
			matched = child
		elif who == HAND_FALLBACK_NAME:
			fallback = child
	var chosen: Node = matched if matched != null else fallback
	if chosen != null:
		chosen.show()


## Dresses every Hand_<Name> node in this slot in its student's equipped
## skin, restoring the authored texture for the default. Only the texture is
## touched: the per-node transforms are hand-authored (see _show_hand_for).
## The first call stashes each node's authored texture in its
## "default_texture" meta so a later default can put it back. Static so the
## test runner can call it without an instance of this non-@tool script.
static func _apply_hand_skins(h_slot: Node) -> void:
	for child in h_slot.get_children():
		if not child.name.begins_with(HAND_NODE_PREFIX) or not child is TextureRect:
			continue
		var hand := child as TextureRect
		if not hand.has_meta(&"default_texture"):
			hand.set_meta(&"default_texture", hand.texture)
		var who := String(hand.name).substr(HAND_NODE_PREFIX.length())
		var path := StudentSkins.hand_for(who)
		hand.texture = load(path) if path != "" else hand.get_meta(&"default_texture")


func _setup_students():
	var students = GameState.approved_students.duplicate()
	if students.size() == 0:
		for s in portrait_slots: s.hide()
		for h in hand_slots: h.hide()
		if chatter:
			chatter.set_seats([])
		return

	var ordered = _compute_seat_order(students)
	var seats: Array = []
	for i in range(portrait_slots.size()):
		var p_slot = portrait_slots[i]
		var h_slot = hand_slots[i]
		if i < ordered.size() and ordered[i] != null:
			p_slot.show()
			h_slot.show()
			var s = ordered[i]
			var portrait_node = p_slot.get_node("Portrait")
			var port_path = StudentSkins.portrait_for(s)
			if port_path != "" and ResourceLoader.exists(port_path):
				portrait_node.texture = load(port_path)
			else:
				portrait_node.texture = default_portrait
				
			_show_hand_for(h_slot, str(s.get("name", "")))
			_apply_hand_skins(h_slot)
			var breathing_delay = float(i) * 0.4
			# A student with a layered rig gets it instead of the flat
			# portrait; both breathe identically, so the diorama reads the
			# same either way.
			var face := _acquire_face(p_slot, str(s.get("name", "")))
			if face != null:
				var skin_base := StudentSkins.face_base_for(str(s.get("name", "")))
				if skin_base != "":
					face.set_base_texture(load(skin_base))
				_match_rect(face, portrait_node)
				portrait_node.hide()
				face.show()
				_animate_breathing(face, breathing_delay)
			else:
				portrait_node.show()
				_animate_breathing(portrait_node, breathing_delay)
			var hit: Control = face if face != null else portrait_node
			var anchor := p_slot.get_node_or_null("ChatAnchor") as Control
			if anchor:
				seats.append({"student": s, "hit": hit, "anchor": anchor})
		else:
			p_slot.hide()
			h_slot.hide()
	if chatter:
		chatter.set_seats(seats)

func _animate_breathing(node: Control, delay: float):
	if not node: return
	# Wait one frame so the node's size is properly calculated before setting pivot
	await get_tree().process_frame
	if not is_instance_valid(node): return
	
	node.pivot_offset = Vector2(node.size.x / 2.0, node.size.y)
	# Bound to the node, not the Lobby: re-seating after the skin picker
	# frees the old face rigs, and a Lobby-owned looping tween would keep
	# stepping a dead node ("Infinite loop detected").
	var tw = node.create_tween().set_loops()
	
	# Start with a delay so they don't breathe perfectly in sync
	if delay > 0:
		tw.tween_interval(delay)
		
	# Subtle breathing up and down
	# Time to inhale (expand slightly)
	tw.tween_property(node, "scale", Vector2(1.01, 1.02), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Time to exhale (shrink back to normal)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The face rig registered for `student`, or null when that student has no
## layered art and should keep the flat portrait. The rig -- not this script --
## owns which roster name it belongs to, so matching reads student_name off
## the PackedScene's saved state rather than instantiating it to ask.
func _face_rig_for(student: String) -> PackedScene:
	var wanted := student.strip_edges().to_lower()
	if wanted == "":
		return null
	for rig in face_rigs:
		if rig == null:
			continue
		if _rig_student_name(rig).strip_edges().to_lower() == wanted:
			return rig
	return null


## Reads the student_name @export off a face rig's root node without loading
## the scene into the tree.
func _rig_student_name(rig: PackedScene) -> String:
	var state := rig.get_state()
	if state.get_node_count() == 0:
		return ""
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == &"student_name":
			return str(state.get_node_property_value(0, i))
	return ""


## Instances `student`'s face rig into `slot` and returns it, or null when
## that student has none. Replaces any rig already in the slot, so a second
## pass over the roster never stacks two faces on one seat.
func _acquire_face(slot: Control, student: String) -> StudentFace:
	var existing := slot.get_node_or_null(^"Face")
	if existing != null:
		slot.remove_child(existing)
		existing.queue_free()
	var rig := _face_rig_for(student)
	if rig == null:
		return null
	var face := rig.instantiate() as StudentFace
	if face == null:
		return null
	face.name = "Face"
	slot.add_child(face)
	return face


## Gives `target` the anchors and offsets of `source`, so a face rig lands
## exactly where the flat portrait it replaces sat. Keeps the diorama's layout
## a .tscn concern: nudge a Portrait in the viewport and the rig follows.
func _match_rect(target: Control, source: Control) -> void:
	target.anchor_left = source.anchor_left
	target.anchor_top = source.anchor_top
	target.anchor_right = source.anchor_right
	target.anchor_bottom = source.anchor_bottom
	target.offset_left = source.offset_left
	target.offset_top = source.offset_top
	target.offset_right = source.offset_right
	target.offset_bottom = source.offset_bottom
	target.grow_horizontal = source.grow_horizontal
	target.grow_vertical = source.grow_vertical


func _compute_seat_order(students: Array) -> Array:
	if not GameState.has_method("get_grade_from_week"):
		return students # Fallback if GameState isn't updated
	var seed_val = GameState.get_grade_from_week()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val * 1337 + 42

	var front_candidates = []
	var back_candidates = []

	for s in students:
		var gender = s.get("gender", "")
		var profil = s.get("profil", "")
		var is_female = (gender == "Perempuan") or ("Perempuan" in profil)
		var quirk = s.get("quirk", "")
		var is_nerd = (quirk == "Kutu Buku")
		
		# Priority for front row seats: Female students or Kutu Buku
		if is_female or is_nerd:
			front_candidates.append(s)
		else:
			back_candidates.append(s)

	# Keep max 2 candidates in the front row
	while front_candidates.size() > 2:
		var overflow_idx = rng.randi() % front_candidates.size()
		var overflow = front_candidates[overflow_idx]
		front_candidates.remove_at(overflow_idx)
		back_candidates.append(overflow)
		
	while front_candidates.size() < 2 and back_candidates.size() > 0:
		var pull_idx = rng.randi() % back_candidates.size()
		var pull = back_candidates[pull_idx]
		back_candidates.remove_at(pull_idx)
		front_candidates.append(pull)

	_seeded_shuffle(front_candidates, rng)
	_seeded_shuffle(back_candidates, rng)

	# Back row seats are Slot1 & Slot2 (Indices 0 & 1)
	# Front row seats are Slot3 & Slot4 (Indices 2 & 3)
	var ordered = []
	ordered.append(back_candidates[0]  if back_candidates.size()  > 0 else null)
	ordered.append(back_candidates[1]  if back_candidates.size()  > 1 else null)
	ordered.append(front_candidates[0] if front_candidates.size() > 0 else null)
	ordered.append(front_candidates[1] if front_candidates.size() > 1 else null)
	return ordered

func _seeded_shuffle(arr: Array, rng: RandomNumberGenerator):
	if arr.size() <= 1:
		return
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

## Slow looping vertical bob for a diorama portrait container, so the hub
## does not read as a still image. Mirrors _animate_breathing's 2-leg
## looped-tween shape; `delay` staggers the back/front containers so they
## never move in perfect lockstep.
func _start_idle_bob(container: Control, delay: float = 0.0) -> void:
	if not container:
		return
	var base_pos := container.position
	var tw := create_tween().set_loops()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(container, "position", base_pos + Vector2(0, -idle_bob_pixels), idle_bob_period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(container, "position", base_pos, idle_bob_period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _populate_default_tutorial_steps():
	if tutorial_phase1_steps.is_empty():
		var p1 = [
			["Selamat Datang!", "Halo! Sebelum anda terjun untuk mengajar generasi muda di sekolah ini.\n\nMari kita mengenali fasilitas untuk menunjang perjalananmu!", "", ""],
			["Pilih Muridmu", "Hmmm, kepikiran kalau kelasmu masih sepi, belum ada murid?\n\nAyo, kita langsung saja pilih muridmu!", "Student", "Tekan tombol 'Student' untuk lanjut!"]
		]
		for entry in p1:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase1_steps.append(step)

	if tutorial_phase2_steps.is_empty():
		var p2 = [
			["Pilihan Bagus!", "Pilihan yang sangat bagus!", "", ""],
			["Inventory", "Inventory adalah tempat dimana seluruh items kalian berada!", "Inventory", ""],
			["Raport Murid", "Raport adalah untuk melihat secara keseluruhan stats murid anda!", "ReportStudent", ""],
			["Koperasi Sekolah", "Koperasi adalah dimana kalian dapat belanja item dan customisasi untuk murid-murid ampu kalian!", "Koperasi", ""],
			["Jadwal Sekolah", "Ahh, sepertinya bel sekolah sudah berbunyi.", "Jadwal", "Tekan tombol 'Jadwal' untuk lanjut!"]
		]
		for entry in p2:
			var step = TutorialStepData.new()
			step.title = entry[0]
			step.text = entry[1]
			step.target_node_path = entry[2]
			step.prompt_text = entry[3]
			tutorial_phase2_steps.append(step)

## Mounts the shared TutorialPanel in the spotlight overlay. Keeps its prompt
## label, which _start_prompt_blink fades; every step's text goes through
## TutorialPanel.show_step() in _show_step.
func _build_tutorial_panel() -> void:
	_tutorial_panel = TutorialPanel.mount(tutorial_panel_scene, color_rect, click_area)
	_tutorial_prompt_label = _tutorial_panel.prompt_label
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

## Seats the card and the arrow for the current step's targets, inside the
## HUD's Safe/UI (TutorialPanel.place_step).
func _position_tutorial_panel() -> void:
	TutorialPanel.place_step(_tutorial_panel, tutorial_safe_ui, color_rect, _step_targets, _tutorial_arrow)

func _fit_color_rect_to_viewport():
	var viewport_size = get_viewport_rect().size
	color_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	color_rect.position = -global_position
	color_rect.size = viewport_size
	if click_area:
		click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_area.position = Vector2.ZERO
		click_area.size = viewport_size
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", viewport_size)
	if tutorial_active and _tutorial_panel and is_instance_valid(_tutorial_panel):
		call_deferred("_position_tutorial_panel")

func _create_blur_overlay():
	blur_overlay = ColorRect.new()
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.color = Color.TRANSPARENT
	var shader = load("res://Scripts/Shaders/blur.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("lod", 0.0)
	mat.set_shader_parameter("darkness", 0.0)
	blur_overlay.material = mat
	blur_overlay.visible = false
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blur_overlay)
	# Place blur_overlay at DailyReward's index, just before it: it then
	# renders over the Classroom and the whole HUD (Safe and everything in
	# it, DailyLogin and SettingsButton included) but behind the popup. Since
	# the 2026-09-15 tall-phone pass the HUD sits in Safe/UI/Hud/BookHud, so a
	# HUD node's own index says nothing about the root's draw order.
	move_child(blur_overlay, daily_reward.get_index())
	# Connect click on blur overlay to close popup
	blur_overlay.gui_input.connect(_on_blur_overlay_input)

func _setup_daily_login() -> void:
	_update_money_display()
	daily_reward.refresh(Time.get_date_string_from_system())
	if not daily_reward.claimed.is_connected(_on_wallet_paid):
		daily_reward.claimed.connect(_on_wallet_paid)
	if not daily_login_btn.pressed.is_connected(_on_daily_login_pressed):
		daily_login_btn.pressed.connect(_on_daily_login_pressed)
	hud.refresh(daily_reward.is_claimable())
	var frame := %DailyLoginFrame as NotebookFrame
	if not frame.close_pressed.is_connected(_hide_daily_reward):
		frame.close_pressed.connect(_hide_daily_reward)

## A payout landed (the daily claim or Dapatkan Uang): roll the wallet up
## from the old balance, and the gift badge follows the claim.
func _on_wallet_paid(_amount: int, previous_money: int) -> void:
	_update_money_display(previous_money)
	RewardFeedback.play(&"coins_earned", money_label)
	hud.refresh(daily_reward.is_claimable())

## Animates the money display via Juice.count_up instead of setting the
## label's text directly. Pass the pre-change amount as `from_amount` to
## get a rolling count and, when the value went up, a coin sfx; omitted
## (or equal to the current amount) this just lands on the correct text
## with no visible motion, which is what the initial _setup_daily_login()
## call wants.
func _update_money_display(from_amount: int = -1) -> void:
	if not money_label:
		return
	var to_amount: int = GameState.player_money
	var from := float(from_amount) if from_amount >= 0 else float(to_amount)
	Juice.count_up(money_label, from, float(to_amount), "%dG")
	if to_amount > int(from):
		AudioDirector.play_sfx(&"coin")

func _on_daily_login_pressed():
	if reward_popup_open:
		return
	_show_daily_reward()

func _show_daily_reward() -> void:
	AudioDirector.play_sfx(&"popup_open")
	reward_popup_open = true
	blur_overlay.visible = true
	_set_blur_lod(0.0)
	_set_blur_darkness(0.0)
	# Redraw for the current date: a Lobby left open past midnight would
	# otherwise show yesterday's claim as today's.
	daily_reward.refresh(Time.get_date_string_from_system())
	daily_reward.open()
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_blur_lod, 0.0, BLUR_LOD, BLUR_IN_SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_blur_darkness, 0.0, BLUR_DARKNESS, BLUR_IN_SECONDS).set_ease(Tween.EASE_OUT)

func _hide_daily_reward() -> void:
	reward_popup_open = false
	daily_reward.close()
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_blur_lod, BLUR_LOD, 0.0, BLUR_OUT_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blur_darkness, BLUR_DARKNESS, 0.0, BLUR_OUT_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: blur_overlay.visible = false)

func _on_blur_overlay_input(event: InputEvent):
	if not reward_popup_open:
		return
	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		AudioDirector.play_sfx(&"popup_close")
		_hide_daily_reward()

func _set_blur_lod(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("lod", value)

func _set_blur_darkness(value: float):
	var mat = blur_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("darkness", value)

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

func _animate_button_click_bounce(btn: Control):
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(0.8, 1.25), 0.08)
	tw.tween_property(btn, "scale", Vector2(1.18, 0.85), 0.1)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)

## Opens Settings (volumes, the minigame tutorial and "Lewati Dialog
## Minigame", which used to be the Shorten button), returning here.
func _on_settings_pressed() -> void:
	# A press Transition would drop must not leave Settings' return_scene
	# pointing at the Lobby for a later visit from the title (bug sweep 2026-09-30).
	if Transition.is_busy():
		return
	AudioDirector.play_sfx(&"tap")
	SettingsScript.return_scene = "res://Scenes/Lobby/Lobby.tscn"
	Transition.change_scene("res://Scenes/UI/Settings.tscn", Transition.Style.WIPE)


func _on_student_pressed():
	_animate_button_click_bounce(student_button)
	print("Tombol Student ditekan, pindah ke student_card")
	Transition.change_scene("res://Scenes/StudentCard/StudentCard.tscn")

func _on_jadwal_pressed():
	# Phase 2's last step has no tap-anywhere to finish it: this press is what
	# ends the tutorial, so the Lobby never replays it.
	if tutorial_active:
		_end_tutorial()
	_animate_button_click_bounce(jadwal_button)
	print("Tombol Jadwal ditekan, pindah ke atur_jadwal")
	Transition.change_scene("res://Scenes/AturJadwal/AturJadwal.tscn")


func _on_koperasi_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	# The shop button lands on the hub, which forks to the item shop or
	# the cosmetic shop, rather than dropping straight into the Koperasi.
	Transition.change_scene("res://Scenes/Koperasi/ShopHub.tscn", Transition.Style.WIPE)


func _on_inventory_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/Inventory/Inventory.tscn", Transition.Style.WIPE)

## Opens the skin picker over the Lobby. Skins apply the moment one is
## picked; closing re-seats the diorama so its faces and desks wear them.
func _on_skin_switch_pressed() -> void:
	if GameState.approved_students.is_empty():
		return
	var screen := skin_select_scene.instantiate() as SkinSelect
	_skin_select_open = true
	if chatter:
		chatter.dismiss()
	add_child(screen)
	screen.closed.connect(func(): _skin_select_open = false)
	screen.closed.connect(_setup_students)
	screen.covered.connect(_set_room_drawn.bind(false))
	screen.uncovering.connect(_set_room_drawn.bind(true))
	# Calls down with the roster's names -- SkinSelect never reads GameState
	# itself, so the rail shows this class, not every character.
	var names: Array[String] = SkinSelect.roster_names(GameState.approved_students)
	screen.open(names)


## Draws the room, or stops drawing it while the skin picker covers the whole
## screen with its own still of it. The room is the costly part of this
## screen (every plate is shaded, and the glow runs over all of it), and
## under the picker none of it can be seen. `World` sits on layer -1, and a
## hidden layer there also switches the Environment glow off, which is wanted
## here and comes back with the layer.
func _set_room_drawn(drawn: bool) -> void:
	($World as CanvasLayer).visible = drawn


## LobbyChatter's gate: nobody talks over the tutorial, the daily reward,
## the skin picker or Dapatkan Uang. It also keeps the HUD down under them.
func _chatter_allowed() -> bool:
	return not tutorial_active and not reward_popup_open and not _skin_select_open \
		and not earn_panel.visible


func _on_achievement_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/Achievements/AchievementsScreen.tscn", Transition.Style.WIPE)

func _on_report_student_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	Transition.change_scene("res://Scenes/ReportCard/ReportCard.tscn", Transition.Style.WIPE)

func _next_step():
	current_step += 1
	if current_step >= current_phase_steps.size():
		_end_tutorial()
		return
	_show_step(current_step)

func _show_step(index: int) -> void:
	if index < 0 or index >= current_phase_steps.size():
		return
	var step := current_phase_steps[index]

	click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _tutorial_panel and _tutorial_panel.modulate.a > 0.1:
		var tween_out := create_tween().set_parallel(true)
		tween_out.tween_property(_tutorial_panel, "scale", Vector2(0.8, 0.8), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween_out.tween_property(_tutorial_panel, "modulate:a", 0.0, 0.15)
		await tween_out.finished

	_step_targets = _resolve_step_targets(step)
	if _step_targets.is_empty():
		_clear_highlight()
	else:
		_highlight_multiple(_step_targets)

	# Dynamic Prompt Text
	var requires_button_press := index == current_phase_steps.size() - 1
	var prompt := TutorialPanel.DEFAULT_PROMPT
	if step.prompt_text != "":
		prompt = step.prompt_text
	elif requires_button_press and not _step_targets.is_empty():
		var btn_name := _get_button_display_name(_step_targets[0])
		prompt = "TEKAN TOMBOL '%s' UNTUK LANJUT!" % btn_name.to_upper()

	# The panel's own step pill is this screen's one counter ("Langkah n / N").
	_tutorial_panel.show_step(step.title, step.text, prompt, index + 1, current_phase_steps.size())
	_position_tutorial_panel()
	_tutorial_panel.pivot_offset = _tutorial_panel.size / 2.0

	var tween_in := create_tween().set_parallel(true)
	tween_in.tween_property(_tutorial_panel, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.2)

	await tween_in.finished

	if index == current_phase_steps.size() - 1:
		# The last step of either phase names the button that leaves the Lobby
		# (Student, then Jadwal): taps pass through the overlay to it, so its
		# first press works, as its prompt says.
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not _step_targets.is_empty() and _step_targets[0] is BaseButton:
			(_step_targets[0] as BaseButton).disabled = false
	else:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP

## The controls a step highlights: each comma-separated path in its
## target_node_path. A bare name ("Jadwal") is a HUD button, found by unique
## name wherever it sits; anything else is a path from the root.
func _resolve_step_targets(step: TutorialStepData) -> Array[Control]:
	var targets: Array[Control] = []
	for path in step.target_node_path.split(","):
		var trimmed := path.strip_edges()
		if trimmed == "":
			continue
		var target: Node = get_node_or_null("%" + trimmed)
		if target == null:
			target = get_node_or_null(trimmed)
		if target is Control:
			targets.append(target)
	return targets

func _get_button_display_name(node: Node) -> String:
	if not node:
		return ""
	if node is Button and node.text.strip_edges() != "":
		return node.text.strip_edges()
	for child in node.get_children():
		if child is Label and child.text.strip_edges() != "":
			return child.text.strip_edges().split("\n")[0]
	return node.name

## Cuts the spotlight hole around `controls`. The arrow is not placed here: it
## needs the card's rectangle to stay off it, so _position_tutorial_panel
## places both once the card has sized itself.
func _highlight_multiple(controls: Array, padding: float = TutorialPanel.SPOT_PADDING):
	await get_tree().process_frame
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

func _end_tutorial() -> void:
	GameState.lobby_tutorial_completed = true
	hud.activate(false)
	tutorial_active = false
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_panel.hide()
	if color_rect:
		color_rect.hide()
