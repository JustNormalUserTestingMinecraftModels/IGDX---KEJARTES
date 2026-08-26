extends Control

signal event_decision_made(accepted: bool, selected_students: Array[StudentData])

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
@export var background_texture: Texture2D = null
@export var background_color: Color = Color(0.04, 0.06, 0.1, 0.88)

# ── Visual - Dialog Card Panel ───────────────────────────────────────────────
@export_group("Visual - Dialog Card Panel")
@export var dialog_card_texture: Texture2D = null
@export var dialog_card_bg_color: Color = Color(0.08, 0.12, 0.2, 0.95)
@export var dialog_card_border_color: Color = Color(0.2, 0.45, 0.7, 0.8)

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
@export var title_font_size: int = 48
@export var title_font_color: Color = Color.WHITE
@export var desc_font_size: int = 32
@export var desc_font_color: Color = Color(0.85, 0.9, 0.95)

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
	fade_in.tween_property(self, "modulate:a", 1.0, 0.25)

func _apply_visual_exports() -> void:
	var bg = get_node_or_null("Background")
	if bg:
		if background_texture:
			if bg is ColorRect:
				var tex_rect = TextureRect.new()
				tex_rect.name = "Background"
				tex_rect.texture = background_texture
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				add_child(tex_rect)
				move_child(tex_rect, 0)
				bg.queue_free()
		elif bg is ColorRect:
			bg.color = background_color

	if dialog_panel:
		if dialog_card_texture:
			var sb = StyleBoxTexture.new()
			sb.texture = dialog_card_texture
			dialog_panel.add_theme_stylebox_override("panel", sb)
		else:
			var style = StyleBoxFlat.new()
			style.bg_color = dialog_card_bg_color
			style.border_color = dialog_card_border_color
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_left = 10
			style.corner_radius_bottom_right = 10
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			dialog_panel.add_theme_stylebox_override("panel", style)

	if title_label:
		title_label.add_theme_font_size_override("font_size", title_font_size)
		title_label.add_theme_color_override("font_color", title_font_color)
		if font: title_label.add_theme_font_override("font", font)

	if desc_label:
		desc_label.add_theme_font_size_override("font_size", desc_font_size)
		desc_label.add_theme_color_override("font_color", desc_font_color)
		if font: desc_label.add_theme_font_override("font", font)

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
	
	for student in student_list:
		var card = _create_card(student)
		students_container.add_child(card)
		_set_mouse_filter_pass(card)
		
	_update_confirm_button()

func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control and not (node is Button or node is CheckBox):
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)

func _create_card(student: StudentData) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var is_tired = student.is_tired()
	var category = event_data.get("category", "Akademis")
	var is_spec = (student.specialty_category == category)
	
	var style = StyleBoxFlat.new()
	if is_tired:
		style.bg_color = Color(0.14, 0.08, 0.08, 0.85)
		style.border_color = Color(0.6, 0.25, 0.25, 0.9)
	elif is_spec:
		style.bg_color = Color(0.08, 0.18, 0.24, 0.95)
		style.border_color = Color(0.2, 0.7, 0.55, 0.9)
	else:
		style.bg_color = Color(0.1, 0.16, 0.26, 0.95)
		style.border_color = Color(0.25, 0.5, 0.8, 0.9)
		
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	card.add_theme_stylebox_override("panel", style)
	
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
	name_lbl.add_theme_font_size_override("font_size", 54)
	name_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65) if is_tired else Color(1, 1, 1))
	if font: name_lbl.add_theme_font_override("font", font)
	header_hbox.add_child(name_lbl)
	
	if is_tired:
		var badge = Label.new()
		badge.text = " 😴 SANGAT LELAH "
		badge.add_theme_font_size_override("font_size", 36)
		badge.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color(0.45, 0.1, 0.1, 0.8)
		badge_style.corner_radius_top_left = 6
		badge_style.corner_radius_top_right = 6
		badge_style.corner_radius_bottom_left = 6
		badge_style.corner_radius_bottom_right = 6
		badge.add_theme_stylebox_override("normal", badge_style)
		header_hbox.add_child(badge)
	elif is_spec:
		var spec_badge = Label.new()
		spec_badge.text = " 🌟 KEAHLIAN (-40% Energy) "
		spec_badge.add_theme_font_size_override("font_size", 36)
		spec_badge.add_theme_color_override("font_color", Color(0.3, 0.95, 0.65))
		spec_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		var spec_style = StyleBoxFlat.new()
		spec_style.bg_color = Color(0.1, 0.4, 0.25, 0.8)
		spec_style.corner_radius_top_left = 6
		spec_style.corner_radius_top_right = 6
		spec_style.corner_radius_bottom_left = 6
		spec_style.corner_radius_bottom_right = 6
		spec_badge.add_theme_stylebox_override("normal", spec_style)
		header_hbox.add_child(spec_badge)

	# Stats & Needs Progress Bars
	var init_stat: float = 0.0
	var stat_name: String = "Stat"
	var stat_color: Color = Color(0.3, 0.7, 1.0)
	
	match category:
		"Akademis":
			init_stat = student.akademis
			stat_name = "Akademis 📚"
			stat_color = Color(0.3, 0.7, 1.0)
		"Olahraga":
			init_stat = student.olahraga
			stat_name = "Olahraga ⚽"
			stat_color = Color(0.3, 0.9, 0.5)
		"SeniBudaya":
			init_stat = student.seni_budaya
			stat_name = "Seni Budaya 🎨"
			stat_color = Color(1.0, 0.75, 0.3)
			
	var stat_bar_data = _add_stat_bar_row(vbox, stat_name, init_stat, stat_color)
	var energy_bar_data = _add_stat_bar_row(vbox, "Energy ⚡", student.energy, Color(1.0, 0.85, 0.2))
	var mood_bar_data = _add_stat_bar_row(vbox, "Mood 😊", student.mood, Color(1.0, 0.45, 0.7))
	
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
		
	# Initial render
	_update_card_preview(student.student_name)
	
	return card

func _add_stat_bar_row(parent_vbox: VBoxContainer, label_text: String, initial_val: float, bar_color: Color) -> Dictionary:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_vbox.add_child(row)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(340, 0)
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	if font: lbl.add_theme_font_override("font", font)
	row.add_child(lbl)
	
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 48)
	bar.value = initial_val
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_left = 6
	fill_style.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("background", bg_style)
	row.add_child(bar)
	
	var val_lbl = Label.new()
	val_lbl.custom_minimum_size = Vector2(200, 0)
	val_lbl.add_theme_font_size_override("font_size", 38)
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	val_lbl.text = "%d/100" % int(initial_val)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font: val_lbl.add_theme_font_override("font", font)
	row.add_child(val_lbl)
	
	var delta_lbl = Label.new()
	delta_lbl.custom_minimum_size = Vector2(100, 0)
	delta_lbl.add_theme_font_size_override("font_size", 24)
	delta_lbl.text = "--"
	delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
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
	var bar = bar_data["bar"] as ProgressBar
	var val_lbl = bar_data["val_label"] as Label
	var delta_lbl = bar_data["delta_label"] as Label
	
	if is_checked and delta != 0.0:
		var target_val = clampf(init_val + delta, 0.0, 100.0)
		var tween = create_tween()
		tween.tween_property(bar, "value", target_val, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		val_lbl.text = "%d ➔ %d" % [int(init_val), int(target_val)]
		if delta > 0:
			delta_lbl.text = "(+%d)" % int(delta)
			delta_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
		else:
			delta_lbl.text = "(%d)" % int(delta)
			delta_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	else:
		var tween = create_tween()
		tween.tween_property(bar, "value", init_val, 0.2).set_trans(Tween.TRANS_QUAD)
		val_lbl.text = "%d/100" % int(init_val)
		delta_lbl.text = "--"
		delta_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

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
	var selected: Array[StudentData] = []
	for student in student_list:
		if not student.is_tired():
			var w = card_widgets.get(student.student_name, {})
			var chk = w.get("checkbox") as CheckBox
			if chk and chk.button_pressed:
				selected.append(student)
				
	event_decision_made.emit(true, selected)

func _on_cancel_pressed() -> void:
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
