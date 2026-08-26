extends Control

## "Who takes part in this event?" — one selectable card per student with
## a live preview of what accepting would do to their stats.
##
## Every card, bar and chip is now theme-driven: cards are &"Card"
## PanelContainers tinted by state, the three preview bars are StatBars
## (category-tinted, animated through Juice), and the state chips reuse
## the shared DaySummaryBadge scene. Nothing here builds a StyleBoxFlat.

signal event_decision_made(accepted: bool, selected_students: Array[StudentData])

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the dialog. When set it replaces the Scrim panel.
@export var background_texture: Texture2D = null

# ── Visual - Dialog Card Panel ───────────────────────────────────────────────
@export_group("Visual - Dialog Card Panel")
@export var dialog_card_texture: Texture2D = null

# ── Visual - Buttons (Single-PNG System) ─────────────────────────────────────
@export_group("Visual - Buttons")
@export var button_select_all_texture: Texture2D = null
@export var button_cancel_texture: Texture2D = null
@export var button_confirm_texture: Texture2D = null
@export var select_all_text: String = "Pilih Semua"
@export var cancel_text: String = "Lewati Event"
@export var confirm_format_text: String = "Ya, Ikutsertakan (%d Siswa)"

# ── Visual - Typography ───────────────────────────────────────────────────────
@export_group("Visual - Typography")
@export var font: Font = null

const _BADGE_SCENE := "res://Scenes/SchoolSimulation/DaySummaryBadge.tscn"

## How much white to mix into a state color before using it as a card
## tint. A card is a large surface; the raw accent at full strength reads
## as an alert, not as a highlight.
const _CARD_TINT_MIX := 0.85

@onready var dialog_panel: PanelContainer = $Margin/DialogPanel
@onready var title_label: Label = $Margin/DialogPanel/Margin/MainVBox/TitleLabel
@onready var desc_label: Label = $Margin/DialogPanel/Margin/MainVBox/DescLabel
@onready var cost_benefit_label: Label = $Margin/DialogPanel/Margin/MainVBox/CostBenefitLabel
@onready var scroll_container: ScrollContainer = $Margin/DialogPanel/Margin/MainVBox/ScrollContainer
@onready var students_container: VBoxContainer = $Margin/DialogPanel/Margin/MainVBox/ScrollContainer/StudentsContainer
@onready var select_all_button: Button = $Margin/DialogPanel/Margin/MainVBox/ActionVBox/SecondaryHBox/SelectAllButton
@onready var cancel_button: Button = $Margin/DialogPanel/Margin/MainVBox/ActionVBox/SecondaryHBox/CancelButton
@onready var confirm_button: Button = $Margin/DialogPanel/Margin/MainVBox/ActionVBox/ConfirmButton

var event_data: Dictionary = {}
var student_list: Array[StudentData] = []
var card_widgets: Dictionary = {}

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

func _ready() -> void:
	modulate.a = 0.0
	_apply_visual_exports()
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)

func setup_event(
	title: String,
	description: String,
	benefit_info: String,
	cost_info: String,
	category: String,
	students: Array[StudentData],
	stat_boost: float = 15.0,
	energy_cost: float = -15.0,
	mood_boost: float = 0.0
) -> void:
	event_data = {
		"title": title,
		"description": description,
		"benefit_info": benefit_info,
		"cost_info": cost_info,
		"category": category,
		"stat_boost": stat_boost,
		"energy_cost": energy_cost,
		"mood_boost": mood_boost
	}
	student_list = students

	if title_label:
		title_label.text = title
	if desc_label:
		desc_label.text = description
	if cost_benefit_label:
		cost_benefit_label.text = "📈 Manfaat: %s\n📉 Biaya: %s" % [benefit_info, cost_info]

	_populate_student_cards()

	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, Juice.tokens().dur_normal)

func _apply_visual_exports() -> void:
	# The Scrim panel is the default backdrop; an art-supplied photo
	# replaces it outright. Guarded on `is Panel` so a second call cannot
	# stack another TextureRect.
	var bg = get_node_or_null("Background")
	if bg is Panel and background_texture:
		var tex_rect = TextureRect.new()
		tex_rect.name = "Background"
		tex_rect.texture = background_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.queue_free()
		add_child(tex_rect)
		move_child(tex_rect, 0)

	# A texture card still wins over the theme, for the art-swap workflow.
	if dialog_panel and dialog_card_texture:
		var sb = StyleBoxTexture.new()
		sb.texture = dialog_card_texture
		dialog_panel.add_theme_stylebox_override("panel", sb)

	for lbl in [title_label, desc_label, cost_benefit_label]:
		if lbl and font:
			lbl.add_theme_font_override("font", font)

	var btns = {
		select_all_button: {"tex": button_select_all_texture, "txt": select_all_text},
		cancel_button: {"tex": button_cancel_texture, "txt": cancel_text},
		confirm_button: {"tex": button_confirm_texture, "txt": confirm_format_text % 0}
	}

	for btn in btns:
		if not btn: continue
		var tex: Texture2D = btns[btn]["tex"]
		var txt: String = btns[btn]["txt"]
		btn.text = "" if tex else txt
		if font: btn.add_theme_font_override("font", font)
		if tex:
			var sb_norm = StyleBoxTexture.new()
			sb_norm.texture = tex
			btn.add_theme_stylebox_override("normal", sb_norm)
			btn.add_theme_stylebox_override("hover", sb_norm)
			btn.add_theme_stylebox_override("pressed", sb_norm)

func _populate_student_cards() -> void:
	if students_container == null:
		return

	for child in students_container.get_children():
		child.queue_free()

	card_widgets.clear()

	var cards: Array = []
	for student in student_list:
		var card = _create_card(student)
		students_container.add_child(card)
		_set_mouse_filter_pass(card)
		# Only now is the card (and its StatBars) inside the tree, which
		# Juice.fill_bar needs before it can create a tween on the bar.
		_update_card_preview(student.student_name)
		cards.append(card)

	Juice.stagger_in(cards)
	_update_confirm_button()

func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control and not (node is Button or node is CheckBox):
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)

func _create_card(student: StudentData) -> PanelContainer:
	var tokens := Juice.tokens()
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.theme_type_variation = &"Card"

	var is_tired = student.is_tired()
	var category = event_data.get("category", "Akademis")
	var is_spec = (student.specialty_category == category)

	# The card's own state, said with a wash of the matching state color
	# rather than a bespoke StyleBoxFlat per case.
	if is_tired:
		card.self_modulate = tokens.state_danger.lerp(Color.WHITE, _CARD_TINT_MIX)
	elif is_spec:
		card.self_modulate = tokens.state_success.lerp(Color.WHITE, _CARD_TINT_MIX)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_hbox)

	# Checkbox
	var chk = CheckBox.new()
	chk.disabled = is_tired
	chk.focus_mode = Control.FOCUS_NONE
	chk.custom_minimum_size = Vector2(120, 120)
	chk.scale = Vector2(2.4, 2.4)
	chk.pivot_offset = Vector2(60, 60)
	main_hbox.add_child(chk)

	# Details Column
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	main_hbox.add_child(vbox)

	# Header HBox (Name + Badges)
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(header_hbox)

	var name_lbl = Label.new()
	name_lbl.text = student.student_name
	name_lbl.theme_type_variation = &"H2Label"
	if is_tired:
		name_lbl.self_modulate = tokens.text_disabled
	if font: name_lbl.add_theme_font_override("font", font)
	header_hbox.add_child(name_lbl)

	if is_tired:
		header_hbox.add_child(_make_badge(" 😴 SANGAT LELAH ", tokens.state_danger))
	elif is_spec:
		header_hbox.add_child(
			_make_badge(" 🌟 KEAHLIAN (-40% Energy) ", tokens.state_success))

	# Stats & Needs Progress Bars
	var init_stat: float = 0.0
	var stat_name: String = "Stat"

	match category:
		"Akademis":
			init_stat = student.akademis
			stat_name = "Akademis 📚"
		"Olahraga":
			init_stat = student.olahraga
			stat_name = "Olahraga ⚽"
		"SeniBudaya":
			init_stat = student.seni_budaya
			stat_name = "Seni Budaya 🎨"

	var stat_bar_data = _add_stat_bar_row(vbox, stat_name, init_stat, category)
	# Energy and Mood have no schedule category of their own; Libur (warm
	# gold) and Istirahat (violet) are the two accents the rest of the game
	# already uses for "how the student is doing" rather than "what they study".
	var energy_bar_data = _add_stat_bar_row(vbox, "Energy ⚡", student.energy, "Libur")
	var mood_bar_data = _add_stat_bar_row(vbox, "Mood 😊", student.mood, "Istirahat")

	var widgets = {
		"student": student,
		"checkbox": chk,
		"stat_name": stat_name,
		"init_stat": init_stat,
		"init_energy": student.energy,
		"init_mood": student.mood,
		"stat_data": stat_bar_data,
		"energy_data": energy_bar_data,
		"mood_data": mood_bar_data
	}
	card_widgets[student.student_name] = widgets

	if not is_tired:
		chk.toggled.connect(func(_on): _update_card_preview(student.student_name))

	# The initial render happens in _populate_student_cards, once the card
	# is actually parented -- see the note there.
	return card


## Shared chip: the DaySummaryBadge scene (SunkenPanel + BarLabel), tinted
## via self_modulate so the child label keeps the theme's own contrast.
func _make_badge(text: String, tint: Color) -> PanelContainer:
	var chip := load(_BADGE_SCENE).instantiate() as PanelContainer
	chip.self_modulate = tint
	var lbl := chip.get_node("Text") as Label
	lbl.text = text
	if font: lbl.add_theme_font_override("font", font)
	return chip


func _add_stat_bar_row(parent_vbox: VBoxContainer, label_text: String, initial_val: float, category: String) -> Dictionary:
	var tokens := Juice.tokens()
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_vbox.add_child(row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(340, 0)
	lbl.theme_type_variation = &"TitleLabel"
	if font: lbl.add_theme_font_override("font", font)
	row.add_child(lbl)

	var bar := StatBar.new()
	bar.category = category
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 48)
	bar.value = initial_val
	row.add_child(bar)

	var val_lbl = Label.new()
	val_lbl.custom_minimum_size = Vector2(200, 0)
	val_lbl.theme_type_variation = &"TitleLabel"
	val_lbl.text = "%d/100" % int(initial_val)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font: val_lbl.add_theme_font_override("font", font)
	row.add_child(val_lbl)

	var delta_lbl = Label.new()
	delta_lbl.custom_minimum_size = Vector2(100, 0)
	delta_lbl.theme_type_variation = &"CaptionLabel"
	delta_lbl.text = "--"
	delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta_lbl.self_modulate = tokens.text_secondary
	if font: delta_lbl.add_theme_font_override("font", font)
	row.add_child(delta_lbl)

	return {
		"bar": bar,
		"val_label": val_lbl,
		"delta_label": delta_lbl
	}

func _update_card_preview(student_name: String) -> void:
	var w = card_widgets.get(student_name) as Dictionary
	if w.is_empty():
		return

	var student = w["student"] as StudentData
	var chk = w["checkbox"] as CheckBox
	var category = event_data.get("category", "Akademis")
	var base_stat_boost = float(event_data.get("stat_boost", 15.0))
	var base_energy_cost = float(event_data.get("energy_cost", -15.0))
	var base_mood_boost = float(event_data.get("mood_boost", 0.0))

	var mult = student.get_category_efficiency_multiplier(category)
	var actual_energy_cost = base_energy_cost
	if actual_energy_cost < 0:
		actual_energy_cost = roundf(actual_energy_cost * mult)

	var is_checked = chk.button_pressed

	_apply_bar_preview(
		w["stat_data"],
		w["init_stat"],
		base_stat_boost if is_checked else 0.0,
		is_checked
	)

	_apply_bar_preview(
		w["energy_data"],
		w["init_energy"],
		actual_energy_cost if is_checked else 0.0,
		is_checked
	)

	_apply_bar_preview(
		w["mood_data"],
		w["init_mood"],
		base_mood_boost if is_checked else 0.0,
		is_checked
	)

	_update_confirm_button()

func _apply_bar_preview(bar_data: Dictionary, init_val: float, delta: float, is_checked: bool) -> void:
	var tokens := Juice.tokens()
	var bar = bar_data["bar"] as StatBar
	var val_lbl = bar_data["val_label"] as Label
	var delta_lbl = bar_data["delta_label"] as Label

	if is_checked and delta != 0.0:
		var target_val = clampf(init_val + delta, 0.0, 100.0)
		Juice.fill_bar(bar, target_val)

		val_lbl.text = "%d ➔ %d" % [int(init_val), int(target_val)]
		if delta > 0:
			delta_lbl.text = "(+%d)" % int(delta)
			delta_lbl.self_modulate = tokens.state_success
		else:
			delta_lbl.text = "(%d)" % int(delta)
			delta_lbl.self_modulate = tokens.state_danger
	else:
		Juice.fill_bar(bar, init_val)
		val_lbl.text = "%d/100" % int(init_val)
		delta_lbl.text = "--"
		delta_lbl.self_modulate = tokens.text_secondary

func _update_confirm_button() -> void:
	var count = 0
	for student_name in card_widgets:
		var w = card_widgets[student_name] as Dictionary
		var chk = w.get("checkbox") as CheckBox
		if chk and chk.button_pressed:
			count += 1

	if confirm_button:
		if button_confirm_texture == null:
			confirm_button.text = confirm_format_text % count
		confirm_button.disabled = (count == 0)

func _on_select_all_pressed() -> void:
	AudioDirector.play_sfx(&"tap")
	var all_checked = true
	for student in student_list:
		if not student.is_tired():
			var w = card_widgets.get(student.student_name, {})
			var chk = w.get("checkbox") as CheckBox
			if chk and not chk.button_pressed:
				all_checked = false
				break

	for student in student_list:
		if not student.is_tired():
			var w = card_widgets.get(student.student_name, {})
			var chk = w.get("checkbox") as CheckBox
			if chk:
				chk.button_pressed = not all_checked
				_update_card_preview(student.student_name)

	_update_confirm_button()

func _on_confirm_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	var selected: Array[StudentData] = []
	for student in student_list:
		if not student.is_tired():
			var w = card_widgets.get(student.student_name, {})
			var chk = w.get("checkbox") as CheckBox
			if chk and chk.button_pressed:
				selected.append(student)

	event_decision_made.emit(true, selected)

func _on_cancel_pressed() -> void:
	AudioDirector.play_sfx(&"cancel")
	var empty_students: Array[StudentData] = []
	event_decision_made.emit(false, empty_students)

func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_scroll = true
			drag_start_y = event.global_position.y
			initial_scroll_v = scroll_container.scroll_vertical
		else:
			is_dragging_scroll = false
	elif event is InputEventMouseMotion and is_dragging_scroll:
		var delta_y = event.global_position.y - drag_start_y
		scroll_container.scroll_vertical = int(initial_scroll_v - delta_y)
