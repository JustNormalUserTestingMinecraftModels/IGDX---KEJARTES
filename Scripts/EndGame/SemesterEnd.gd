extends Control

## The results/payoff screen. Deliberately the most-animated screen in the
## game: title pops in, the cards stagger in behind it, each card's stat
## bars fill with a count-up, and the LULUS/TIDAK LULUS stamp slams down
## one beat later -- see @export_group("Reveal Timing") below for the
## tunable spacing between those beats.

@export_group("Reveal Timing")
## Delay between each card/page-dot appearing during the initial reveal.
@export var card_stagger: float = 0.12
## Delay after a card appears before its stat bars start filling.
@export var stat_fill_delay: float = 0.35
## Delay after the stat bars finish before the pass/fail stamp slams in.
@export var stamp_delay: float = 0.9

# ── Node References ───────────────────────────────────────────────────────────
@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/SubtitleLabel
@onready var card_container: Control = $MarginContainer/VBoxContainer/CardContainer
@onready var page_indicator: HBoxContainer = $MarginContainer/VBoxContainer/PageIndicator
@onready var congrats_title: Label = $MarginContainer/VBoxContainer/NarrativeContainer/CongratsTitle
@onready var congrats_text: Label = $MarginContainer/VBoxContainer/NarrativeContainer/CongratsText
@onready var teacher_title_label: Label = $MarginContainer/VBoxContainer/TeacherContainer/TeacherTitleLabel

@onready var btn_restart: Button = $MarginContainer/VBoxContainer/ButtonContainer/BtnRestart

@onready var left_arrow: Button = $LeftArrow
@onready var right_arrow: Button = $RightArrow

# Carousel / Swipe gesture state
var active_students: Array = []
var card_nodes: Array[Control] = []
var current_card_index: int = 0
var card_animating: bool = false

var is_pointer_down: bool = false
var pointer_start_pos: Vector2 = Vector2.ZERO
var min_swipe_distance: float = 75.0

# Per-card data computed once in _evaluate_students(), consumed beat-by-beat
# by the reveal sequence in _reveal_card(). Index-aligned with card_nodes.
var _card_data: Array[Dictionary] = []
var _card_revealed: Array[bool] = []

const _SUBJECT_NODE_NAMES := ["Akademis", "Seni", "Olahraga"]
const _SUBJECT_DATA_KEYS := ["akademis", "seni", "olahraga"]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Connect buttons
	btn_restart.pressed.connect(_on_restart_pressed)
	left_arrow.pressed.connect(_prev_card)
	right_arrow.pressed.connect(_next_card)

	# Setup juice
	_setup_button_juice(left_arrow)
	_setup_button_juice(right_arrow)
	_setup_button_juice(btn_restart)

	if GameState.check_semester_passed():
		AudioDirector.play_bgm(&"result_win")
	else:
		AudioDirector.play_bgm(&"result_lose")

	# Calculate evaluation, then play the sequenced reveal.
	_evaluate_students()
	_play_reveal()

func _evaluate_students() -> void:
	var students: Array[StudentData] = GameState.convert_to_student_data_array()
	active_students = students
	card_nodes.clear()
	_card_data.clear()
	_card_revealed.clear()

	# Populate card_nodes with Murid1 to Murid4 based on active selection size
	for i in range(4):
		var node_name = "Murid" + str(i + 1)
		var card_node = card_container.get_node_or_null(node_name)
		if not card_node:
			continue

		if i < active_students.size():
			var student = active_students[i]
			card_nodes.append(card_node)
			_card_revealed.append(false)

			# Set Name
			var name_lbl = card_node.get_node_or_null("Nama")
			if name_lbl:
				name_lbl.text = student.student_name

			# Set Portrait
			var portrait_rect = card_node.get_node_or_null("Portrait")
			if portrait_rect:
				portrait_rect.texture = student.avatar_texture

			# Compute subject passing
			var tuntas_akademis = student.akademis >= student.target_akademis1
			var tuntas_seni = student.seni_budaya >= student.target_akademis2
			var tuntas_olahraga = student.olahraga >= student.target_akademis3
			var student_passed = tuntas_akademis and tuntas_seni and tuntas_olahraga

			_card_data.append({
				"akademis": {"value": student.akademis, "target": student.target_akademis1},
				"seni": {"value": student.seni_budaya, "target": student.target_akademis2},
				"olahraga": {"value": student.olahraga, "target": student.target_akademis3},
				"passed": student_passed,
			})

			# Stamp text is set now, but stays invisible (alpha 0) until
			# _slam_stamp reveals it during the sequenced reveal below.
			var stamp_lbl = card_node.get_node_or_null("Stamp")
			if stamp_lbl:
				stamp_lbl.text = "LULUS!" if student_passed else "TIDAK LULUS..."
				stamp_lbl.modulate.a = 0.0

			# Stat rows stay hidden until the reveal fills them in, so the
			# card doesn't flash a "0/target" number ahead of its beat.
			var stats_container = card_node.get_node_or_null("StatsContainer")
			if stats_container:
				stats_container.modulate.a = 0.0

			# Connect Swipe / Touch handlers
			var card_btn = card_node.get_node_or_null("CardButton")
			if card_btn:
				if not card_btn.gui_input.is_connected(_on_card_gui_input.bind(card_node)):
					card_btn.gui_input.connect(_on_card_gui_input.bind(card_node))
				if not card_btn.pressed.is_connected(_on_card_pressed.bind(card_node)):
					card_btn.pressed.connect(_on_card_pressed.bind(card_node))
			else:
				if not card_node.gui_input.is_connected(_on_card_gui_input.bind(card_node)):
					card_node.gui_input.connect(_on_card_gui_input.bind(card_node))
		else:
			card_node.hide()

	# Page indicators and carousel state
	_build_page_indicators()
	_init_carousel_state()

	# Overall Evaluation Result
	var grade_num = GameState.current_grade
	var all_passed = GameState.check_semester_passed()
	var tokens := DesignTokens.load_default()

	if all_passed:
		AudioDirector.play_sfx(&"reward")
		title_label.text = "Hasil Tes Besar - %s" % GameState.get_grade_name()
		congrats_title.text = "Semua murid berhasil!"
		congrats_title.add_theme_color_override("font_color", tokens.state_success)

		# Compute teacher title
		var total_tuntas = 0
		for student in students:
			if student.akademis >= student.target_akademis1: total_tuntas += 1
			if student.seni_budaya >= student.target_akademis2: total_tuntas += 1
			if student.olahraga >= student.target_akademis3: total_tuntas += 1

		var teacher_rank_str = "Guru Pembimbing Aktif ⭐"
		if total_tuntas >= 10:
			teacher_rank_str = "Guru Teladan Utama ⭐⭐⭐"
		elif total_tuntas >= 6:
			teacher_rank_str = "Guru Berdedikasi Tinggi ⭐⭐"

		teacher_title_label.text = "Gelar Gurumu: %s" % teacher_rank_str

		congrats_text.text = "Seluruh muridmu memenuhi target %s. Mereka siap melangkah ke tahap berikutnya." % GameState.get_grade_name()
		btn_restart.text = "Lihat Hasil"
	else:
		title_label.text = "Hasil Tes Besar - %s" % GameState.get_grade_name()
		congrats_title.text = "Belum semua murid tuntas"
		congrats_title.add_theme_color_override("font_color", tokens.state_danger)

		teacher_title_label.text = "Gelar Gurumu: Guru Pembimbing Remedial"
		congrats_text.text = "Sebagian muridmu belum mencapai target %s. Mari lihat bagaimana tahun ajaran ini berjalan." % GameState.get_grade_name()
		btn_restart.text = "Lihat Hasil"

# ── Reveal Sequencing ─────────────────────────────────────────────────────────
## Title pops in -> the page dots (one per card) stagger in -> the current
## card pops in -> that card's own beat (stat fill, then stamp) plays via
## _reveal_card(). Each beat is gated behind the previous one via await, so
## the payoff never dumps everything on screen at once.
func _play_reveal() -> void:
	var t := Juice.tokens()
	Juice.pop_in(title_label)
	Juice.pop_in(subtitle_label, t.dur_instant)

	if page_indicator:
		Juice.stagger_in(page_indicator.get_children(), card_stagger)

	if card_nodes.is_empty():
		return

	var lead_in := card_stagger * float(page_indicator.get_child_count() if page_indicator else 1)
	await get_tree().create_timer(lead_in).timeout
	if not is_instance_valid(self):
		return

	Juice.pop_in(card_nodes[current_card_index])
	_reveal_card(current_card_index)

## Plays one card's stat-fill-then-stamp-slam beat. Safe to call multiple
## times for the same card (e.g. re-swiping to it) -- it only plays once,
## tracked via _card_revealed.
func _reveal_card(index: int) -> void:
	if index < 0 or index >= card_nodes.size() or index >= _card_revealed.size():
		return
	if _card_revealed[index]:
		return
	_card_revealed[index] = true

	var card := card_nodes[index]
	var data: Dictionary = _card_data[index]

	await get_tree().create_timer(stat_fill_delay).timeout
	if not is_instance_valid(card):
		return

	var stats_container = card.get_node_or_null("StatsContainer")
	if stats_container:
		Juice.fade_in(stats_container)
		for j in range(_SUBJECT_NODE_NAMES.size()):
			var row = stats_container.get_node_or_null(_SUBJECT_NODE_NAMES[j])
			if row:
				var d: Dictionary = data[_SUBJECT_DATA_KEYS[j]]
				row.set_result(d["value"], d["target"])

	await get_tree().create_timer(stamp_delay).timeout
	if not is_instance_valid(card):
		return

	var stamp_lbl = card.get_node_or_null("Stamp")
	if stamp_lbl:
		_slam_stamp(stamp_lbl, data["passed"])

## The stamp is the emotional beat of the whole screen: it slams down from
## 3x scale, then gives the card a little shake and plays the pass/fail
## sting. Colors always come from DesignTokens, never a literal -- this is
## the only place the stamp's color is ever set (no static override lives
## in the .tscn).
func _slam_stamp(stamp: Control, passed: bool) -> void:
	var tokens := DesignTokens.load_default()
	stamp.add_theme_color_override("font_color",
		tokens.state_success if passed else tokens.state_danger)

	Juice.set_pivot_center(stamp)
	stamp.scale = Vector2(3.0, 3.0)
	stamp.modulate.a = 0.0

	var t := Juice.tokens()
	var tw := stamp.create_tween().set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(stamp, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		Juice.shake(stamp.get_parent(), 8.0)
		AudioDirector.play_sfx(&"success" if passed else &"fail"))

# ── Carousel Logic ────────────────────────────────────────────────────────────
## The dots are authored in the .tscn (four of them, the roster cap), so
## this only decides how many are visible. Nothing is constructed here --
## see the authoring guide's "no visual is built at runtime" rule.
func _build_page_indicators() -> void:
	if not page_indicator:
		return
	for i in range(page_indicator.get_child_count()):
		page_indicator.get_child(i).visible = (i < card_nodes.size())

func _update_page_indicators() -> void:
	var tokens := DesignTokens.load_default()
	if page_indicator:
		var dots = page_indicator.get_children()
		for i in range(dots.size()):
			if dots[i] is Label:
				if i == current_card_index:
					dots[i].add_theme_color_override("font_color", tokens.currency_gold)
				else:
					dots[i].add_theme_color_override("font_color", tokens.text_disabled)

	if left_arrow:
		left_arrow.visible = (card_nodes.size() > 1)
	if right_arrow:
		right_arrow.visible = (card_nodes.size() > 1)

func _init_carousel_state() -> void:
	if card_nodes.is_empty():
		return
	for i in range(card_nodes.size()):
		var card = card_nodes[i]
		if i == current_card_index:
			card.show()
			card.position = Vector2.ZERO
			card.rotation_degrees = 0
			card.modulate.a = 1.0
		else:
			card.hide()
	_update_page_indicators()

func _next_card() -> void:
	if card_animating or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index + 1) % card_nodes.size()
	_switch_card(target_index, -1)

func _prev_card() -> void:
	if card_animating or card_nodes.size() <= 1:
		return
	var target_index = (current_card_index - 1 + card_nodes.size()) % card_nodes.size()
	_switch_card(target_index, 1)

func _switch_card(new_index: int, direction: int) -> void:
	if card_animating or new_index == current_card_index:
		return
	card_animating = true

	var old_card = card_nodes[current_card_index]
	var new_card = card_nodes[new_index]
	current_card_index = new_index

	var screen_width = get_viewport_rect().size.x
	var throw_distance = screen_width * direction
	var orig_pos = Vector2.ZERO

	var tween_out = create_tween().set_parallel(true)
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out.tween_property(old_card, "position:x", orig_pos.x + throw_distance, 0.20)
	tween_out.tween_property(old_card, "rotation_degrees", 12.0 * direction, 0.20)
	tween_out.tween_property(old_card, "modulate:a", 0.0, 0.20)

	await tween_out.finished

	old_card.hide()
	old_card.position = orig_pos
	old_card.rotation_degrees = 0
	old_card.modulate.a = 1.0

	new_card.show()
	new_card.position = orig_pos - Vector2(throw_distance, 0)
	new_card.rotation_degrees = -12.0 * direction
	new_card.modulate.a = 0.0

	_update_page_indicators()

	var tween_in = create_tween().set_parallel(true)
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(new_card, "position", orig_pos, 0.20)
	tween_in.tween_property(new_card, "rotation_degrees", 0.0, 0.20)
	tween_in.tween_property(new_card, "modulate:a", 1.0, 0.20)

	await tween_in.finished

	card_animating = false

	# Swiping to a card that hasn't had its own reveal beat yet plays it now.
	_reveal_card(new_index)

func _on_card_pressed(card_node: Control) -> void:
	pass

func _on_card_gui_input(event: InputEvent, card_node: Control) -> void:
	if card_animating:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pointer_down = true
				pointer_start_pos = event.global_position
			else:
				if is_pointer_down:
					is_pointer_down = false
					var delta = event.global_position - pointer_start_pos
					var total_distance = delta.length()

					if total_distance >= min_swipe_distance and abs(delta.x) > abs(delta.y) * 1.2:
						if delta.x < 0:
							_next_card()
						else:
							_prev_card()

	elif event is InputEventScreenTouch:
		if event.pressed:
			is_pointer_down = true
			pointer_start_pos = event.position
		else:
			if is_pointer_down:
				is_pointer_down = false
				var delta = event.position - pointer_start_pos
				var total_distance = delta.length()

				if total_distance >= min_swipe_distance and abs(delta.x) > abs(delta.y) * 1.2:
					if delta.x < 0:
						_next_card()
					else:
						_prev_card()

# ── Button Actions ────────────────────────────────────────────────────────────
## The stat check no longer decides progression -- it only decides which
## emotional beat plays next. RunResult applies the grade advance, because
## RunResult is now the last screen of a run.
func _on_restart_pressed() -> void:
	var all_passed := GameState.check_semester_passed()
	var next_scene_path := ""

	if all_passed:
		next_scene_path = "res://Scenes/EndGame/WinScreen.tscn"
	else:
		GameState.run_failed = true
		GameState.is_game_over_cutscene = true
		next_scene_path = "res://Scenes/CutScene/cut_scene.tscn"

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	Transition.change_scene(next_scene_path)

# ── Button Juice ──────────────────────────────────────────────────────────────
func _setup_button_juice(btn: Control) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_btn_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))

func _on_btn_mouse_entered(btn: Control) -> void:
	if not is_instance_valid(btn) or (btn is BaseButton and btn.disabled):
		return
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)

func _on_btn_mouse_exited(btn: Control) -> void:
	if not is_instance_valid(btn):
		return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
