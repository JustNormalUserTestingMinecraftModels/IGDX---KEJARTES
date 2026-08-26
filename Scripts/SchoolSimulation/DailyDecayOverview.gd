extends Control

signal overview_closed

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
@export var background_texture: Texture2D = null
@export var background_color: Color = Color(0.04, 0.06, 0.1, 0.88)

# ── Visual - Header & Typography ──────────────────────────────────────────────
@export_group("Visual - Header & Typography")
@export var title_format_text: String = "🌅 Aktivitas & Evaluasi Harian (%s)"
@export var subtitle_text: String = "Pengurangan Energi & Mood siswa sesuai kepribadian & rutinitas"
@export var sunrise_icon_texture: Texture2D = null
@export var font: Font = null
@export var title_font_size: int = 48
@export var title_font_color: Color = Color.WHITE
@export var subtitle_font_size: int = 30
@export var subtitle_font_color: Color = Color(0.7, 0.8, 0.95)

# ── Visual - Buttons (Single-PNG System) ─────────────────────────────────────
@export_group("Visual - Buttons")
@export var button_continue_texture: Texture2D = null
@export var continue_button_text: String = "Lanjutkan"

@onready var title_label: Label = $Margin/Panel/Margin/VBox/HeaderVBox/TitleLabel
@onready var subtitle_label: Label = $Margin/Panel/Margin/VBox/HeaderVBox/SubtitleLabel
@onready var students_container: VBoxContainer = $Margin/Panel/Margin/VBox/ScrollContainer/StudentsContainer
@onready var continue_button: Button = $Margin/Panel/Margin/VBox/ContinueButton
@onready var scroll_container: ScrollContainer = $Margin/Panel/Margin/VBox/ScrollContainer

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

func _ready() -> void:
	modulate.a = 0.0
	_apply_visual_exports()
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)

func show_decay_overview(day_name: String, decay_results: Array[Dictionary]) -> void:
	_apply_visual_exports()
	if title_label:
		title_label.text = title_format_text % day_name
	if subtitle_label:
		subtitle_label.text = subtitle_text

	for child in students_container.get_children():
		child.queue_free()

	modulate.a = 0.0
	show()
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.3)
	await fade_in.finished

	for res in decay_results:
		var card = _create_student_decay_card(res)
		students_container.add_child(card)
		_set_mouse_filter_pass(card)

	await get_tree().create_timer(0.15).timeout
	
	for child in students_container.get_children():
		if child.has_meta("animate_bars"):
			var anim_callable = child.get_meta("animate_bars") as Callable
			if anim_callable.is_valid():
				anim_callable.call()

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

	if title_label:
		title_label.add_theme_font_size_override("font_size", title_font_size)
		title_label.add_theme_color_override("font_color", title_font_color)
		if font: title_label.add_theme_font_override("font", font)

		if sunrise_icon_texture:
			var tex_rect = title_label.get_node_or_null("SunriseTexture") as TextureRect
			if not tex_rect:
				tex_rect = TextureRect.new()
				tex_rect.name = "SunriseTexture"
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.custom_minimum_size = Vector2(24, 24)
				title_label.add_child(tex_rect)
			tex_rect.texture = sunrise_icon_texture

	if subtitle_label:
		subtitle_label.text = subtitle_text
		subtitle_label.add_theme_font_size_override("font_size", subtitle_font_size)
		subtitle_label.add_theme_color_override("font_color", subtitle_font_color)
		if font: subtitle_label.add_theme_font_override("font", font)

	if continue_button:
		continue_button.text = "" if button_continue_texture else continue_button_text
		if font: continue_button.add_theme_font_override("font", font)
		if button_continue_texture:
			var sb = StyleBoxTexture.new()
			sb.texture = button_continue_texture
			continue_button.add_theme_stylebox_override("normal", sb)
			continue_button.add_theme_stylebox_override("hover", sb)
			continue_button.add_theme_stylebox_override("pressed", sb)

func _create_student_decay_card(res: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.14, 0.22, 0.95)
	style.border_color = Color(0.25, 0.4, 0.65, 0.8)
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
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(header_hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = res.get("student_name", "")
	name_lbl.add_theme_font_size_override("font_size", 54)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	if font: name_lbl.add_theme_font_override("font", font)
	header_hbox.add_child(name_lbl)
	
	var p_badge = Label.new()
	p_badge.text = " %s " % res.get("personality", "Santai")
	p_badge.add_theme_font_size_override("font_size", 36)
	p_badge.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.15, 0.3, 0.5, 0.7)
	p_style.corner_radius_top_left = 6
	p_style.corner_radius_top_right = 6
	p_style.corner_radius_bottom_left = 6
	p_style.corner_radius_bottom_right = 6
	p_badge.add_theme_stylebox_override("normal", p_style)
	header_hbox.add_child(p_badge)
	
	var reason_lbl = Label.new()
	reason_lbl.text = "💬 %s" % res.get("reason", "Aktivitas harian")
	reason_lbl.add_theme_font_size_override("font_size", 44)
	reason_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: reason_lbl.add_theme_font_override("font", font)
	vbox.add_child(reason_lbl)
	
	var curr_e = float(res.get("current_energy", 80.0))
	var e_loss = float(res.get("energy_loss", 5.0))
	var start_e = clampf(curr_e + e_loss, 0.0, 100.0)
	
	var curr_m = float(res.get("current_mood", 80.0))
	var m_loss = float(res.get("mood_loss", 5.0))
	var start_m = clampf(curr_m + m_loss, 0.0, 100.0)
	
	var e_data = _add_bar_row(vbox, "Energy ⚡", start_e, Color(1.0, 0.85, 0.2))
	var m_data = _add_bar_row(vbox, "Mood 😊", start_m, Color(1.0, 0.45, 0.7))
	
	var animate_func = func():
		var tween = card.create_tween().set_parallel(true)
		var e_bar = e_data["bar"] as ProgressBar
		var e_info = e_data["info_lbl"] as Label
		tween.tween_property(e_bar, "value", curr_e, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		e_info.text = "%d ➔ %d (-%d)" % [int(start_e), int(curr_e), int(e_loss)]
		e_info.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
		
		var m_bar = m_data["bar"] as ProgressBar
		var m_info = m_data["info_lbl"] as Label
		tween.tween_property(m_bar, "value", curr_m, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		m_info.text = "%d ➔ %d (-%d)" % [int(start_m), int(curr_m), int(m_loss)]
		m_info.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))

	card.set_meta("animate_bars", animate_func)
	return card

func _add_bar_row(parent_vbox: VBoxContainer, label_text: String, start_val: float, bar_color: Color) -> Dictionary:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent_vbox.add_child(row)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(340, 0)
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	if font: lbl.add_theme_font_override("font", font)
	row.add_child(lbl)
	
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(100, 48)
	bar.value = start_val
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_left = 6
	fill_style.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.14, 1.0)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("background", bg_style)
	row.add_child(bar)
	
	var info_lbl = Label.new()
	info_lbl.custom_minimum_size = Vector2(240, 0)
	info_lbl.add_theme_font_size_override("font_size", 38)
	info_lbl.text = "%d/100" % int(start_val)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	if font: info_lbl.add_theme_font_override("font", font)
	row.add_child(info_lbl)
	
	return {
		"bar": bar,
		"info_lbl": info_lbl
	}

func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control and not (node is Button):
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)

func _on_continue_pressed() -> void:
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	overview_closed.emit()
	queue_free()

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
