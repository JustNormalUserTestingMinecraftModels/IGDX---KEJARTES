extends Control

signal checkup_closed

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
@export var background_texture: Texture2D = null
@export var background_color: Color = Color(0.04, 0.06, 0.1, 0.88)

# ── Visual - Header & Typography ──────────────────────────────────────────────
@export_group("Visual - Header & Typography")
@export var header_title_text: String = "EVALUASI MINGGUAN SISWA"
@export var header_subtitle_text: String = "Perkembangan statistik & riwayat kegiatan selama satu minggu"
@export var students_section_header_text: String = "RAPOR MINGGUAN SISWA"
@export var history_section_header_text: String = "RIWAYAT MINIGAME & EVENT"
@export var students_header_icon_texture: Texture2D = null
@export var history_header_icon_texture: Texture2D = null
@export var font: Font = null
@export var title_font_size: int = 52
@export var title_font_color: Color = Color.WHITE
@export var subtitle_font_size: int = 30
@export var subtitle_font_color: Color = Color(0.7, 0.8, 0.95)

# ── Visual - Buttons (Single-PNG System) ─────────────────────────────────────
@export_group("Visual - Buttons")
@export var button_close_texture: Texture2D = null
@export var close_button_text: String = "Selesai Evaluasi"

@onready var title_label: Label = $Margin/VBox/HeaderPanel/TitleLabel
@onready var subtitle_label: Label = $Margin/VBox/HeaderPanel/SubtitleLabel
@onready var students_container: VBoxContainer = $Margin/VBox/ScrollContainer/MainContent/StudentsContainer
@onready var history_list: VBoxContainer = $Margin/VBox/ScrollContainer/MainContent/HistoryList
@onready var scroll_container: ScrollContainer = $Margin/VBox/ScrollContainer
@onready var btn_close: Button = $Margin/VBox/BtnClose

var animated_bars: Array[Dictionary] = []

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

func _ready() -> void:
	modulate.a = 0.0
	_apply_visual_exports()
	btn_close.pressed.connect(_on_close_pressed)
	btn_close.modulate.a = 0.0
	btn_close.disabled = true
	
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)

func initialize_checkup(student_manager: StudentManager) -> void:
	_apply_visual_exports()
	if student_manager == null:
		return
		
	for child in students_container.get_children():
		child.queue_free()
	for child in history_list.get_children():
		child.queue_free()
		
	animated_bars.clear()
	
	for student in student_manager.students:
		var card = _create_student_card(student, student_manager.minigame_history)
		students_container.add_child(card)
		_set_mouse_filter_pass(card)
		
	if student_manager.minigame_history.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Tidak ada minigame yang dimainkan minggu ini."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font: empty_lbl.add_theme_font_override("font", font)
		history_list.add_child(empty_lbl)
	else:
		for entry in student_manager.minigame_history:
			var item = _create_history_item(entry)
			history_list.add_child(item)
			_set_mouse_filter_pass(item)
			
	_play_entrance_animations()

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
		title_label.text = header_title_text
		title_label.add_theme_font_size_override("font_size", title_font_size)
		title_label.add_theme_color_override("font_color", title_font_color)
		if font: title_label.add_theme_font_override("font", font)

	if subtitle_label:
		subtitle_label.text = header_subtitle_text
		subtitle_label.add_theme_font_size_override("font_size", subtitle_font_size)
		subtitle_label.add_theme_color_override("font_color", subtitle_font_color)
		if font: subtitle_label.add_theme_font_override("font", font)

	var std_hdr = get_node_or_null("Margin/VBox/ScrollContainer/MainContent/StudentsSectionHeader/Label") as Label
	if std_hdr:
		std_hdr.text = students_section_header_text
		if font: std_hdr.add_theme_font_override("font", font)

	var hist_hdr = get_node_or_null("Margin/VBox/ScrollContainer/MainContent/HistorySectionHeader/Label") as Label
	if hist_hdr:
		hist_hdr.text = history_section_header_text
		if font: hist_hdr.add_theme_font_override("font", font)

	if btn_close:
		btn_close.text = "" if button_close_texture else close_button_text
		if font: btn_close.add_theme_font_override("font", font)
		if button_close_texture:
			var sb = StyleBoxTexture.new()
			sb.texture = button_close_texture
			btn_close.add_theme_stylebox_override("normal", sb)
			btn_close.add_theme_stylebox_override("hover", sb)
			btn_close.add_theme_stylebox_override("pressed", sb)

func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control:
		if not node is Button:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)

func _create_student_card(student: StudentData, _history: Array[Dictionary]) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.3, 0.4, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_hbox)
	
	var avatar_vbox = VBoxContainer.new()
	avatar_vbox.custom_minimum_size = Vector2(240, 0)
	main_hbox.add_child(avatar_vbox)
	
	var avatar_frame = AspectRatioContainer.new()
	avatar_frame.ratio = 1.0
	avatar_frame.custom_minimum_size = Vector2(240, 240)
	avatar_vbox.add_child(avatar_frame)
	
	var avatar = TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if student.avatar_texture != null:
		avatar.texture = student.avatar_texture
	else:
		var name_lower = student.student_name.to_lower()
		var texture_path = ""
		if "marcel" in name_lower:
			texture_path = "res://Assets/Images/MuridPotrait/Marcel.png"
		elif "doni" in name_lower:
			texture_path = "res://Assets/Images/MuridPotrait/Doni.png"
		elif "andi" in name_lower:
			texture_path = "res://Assets/Images/MuridPotrait/Andi.png"
		elif "citra" in name_lower:
			texture_path = "res://Assets/Images/MuridPotrait/Citra.png"
		elif "shinta" in name_lower:
			texture_path = "res://Assets/Images/MuridPotrait/Shinta.png"
		elif "thea" in name_lower:
			texture_path = "res://Assets/Images/MuridPotrait/Thea.png"
			
		if texture_path != "" and ResourceLoader.exists(texture_path):
			avatar.texture = load(texture_path)
			student.avatar_texture = avatar.texture
		else:
			var placeholder = GradientTexture2D.new()
			placeholder.width = 240
			placeholder.height = 240
			var grad = Gradient.new()
			var col = Color.from_hsv(randf(), 0.6, 0.8)
			grad.colors = PackedColorArray([col.darkened(0.5), col])
			placeholder.gradient = grad
			avatar.texture = placeholder
		
	avatar_frame.add_child(avatar)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = student.student_name
	name_lbl.add_theme_font_size_override("font_size", 54)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: name_lbl.add_theme_font_override("font", font)
	info_vbox.add_child(name_lbl)
	
	var akademis_delta: float = student.get_akademis_delta()
	var seni_delta: float     = student.get_seni_delta()
	var olahraga_delta: float = student.get_olahraga_delta()
	var energy_delta: float   = student.get_energy_delta()
	var mood_delta: float     = student.get_mood_delta()

	var stats_hdr = Label.new()
	stats_hdr.text = "STATS"
	stats_hdr.add_theme_font_size_override("font_size", 38)
	stats_hdr.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 0.8))
	if font: stats_hdr.add_theme_font_override("font", font)
	info_vbox.add_child(stats_hdr)

	_add_stat_bar(info_vbox, "Akademis", student.akademis, akademis_delta, Color(0.3, 0.7, 1.0))
	_add_stat_bar(info_vbox, "Seni Budaya", student.seni_budaya, seni_delta, Color(1.0, 0.75, 0.3))
	_add_stat_bar(info_vbox, "Olahraga", student.olahraga, olahraga_delta, Color(0.3, 0.9, 0.5))
	
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	info_vbox.add_child(sep)
	
	var needs_hdr = Label.new()
	needs_hdr.text = "NEEDS"
	needs_hdr.add_theme_font_size_override("font_size", 38)
	needs_hdr.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 0.8))
	if font: needs_hdr.add_theme_font_override("font", font)
	info_vbox.add_child(needs_hdr)

	_add_stat_bar(info_vbox, "Energy ⚡", student.energy, energy_delta, Color(1.0, 0.85, 0.2))
	_add_stat_bar(info_vbox, "Mood 😊", student.mood, mood_delta, Color(1.0, 0.45, 0.7))
	
	return panel

func _add_stat_bar(parent: VBoxContainer, stat_name: String, target_val: float, delta: float, color: Color) -> void:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	
	var label = Label.new()
	label.text = stat_name
	label.custom_minimum_size = Vector2(340, 0)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: label.add_theme_font_override("font", font)
	row.add_child(label)
	
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 48)
	
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = color
	bar_style.corner_radius_top_left = 6
	bar_style.corner_radius_top_right = 6
	bar_style.corner_radius_bottom_left = 6
	bar_style.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("fill", bar_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("background", bg_style)
	
	var start_val = clampf(target_val - delta, 0.0, 100.0)
	bar.value = start_val
	row.add_child(bar)
	
	animated_bars.append({
		"bar": bar,
		"target": target_val
	})
	
	var delta_lbl = Label.new()
	delta_lbl.custom_minimum_size = Vector2(180, 0)
	delta_lbl.add_theme_font_size_override("font_size", 38)
	if font: delta_lbl.add_theme_font_override("font", font)
	if delta > 0:
		delta_lbl.text = "+%d" % int(delta)
		delta_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	elif delta < 0:
		delta_lbl.text = "%d" % int(delta)
		delta_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		delta_lbl.text = "--"
		delta_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	row.add_child(delta_lbl)

func _create_history_item(entry: Dictionary) -> PanelContainer:
	var item = PanelContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.3, 0.8)
	item.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	item.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	var day_lbl = Label.new()
	day_lbl.text = "[%s]" % entry.get("day", "")
	day_lbl.add_theme_font_size_override("font_size", 36)
	day_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	day_lbl.custom_minimum_size = Vector2(180, 0)
	if font: day_lbl.add_theme_font_override("font", font)
	hbox.add_child(day_lbl)
	
	var category_str = entry.get("category", "")
	var game_name = entry.get("game_name", "Minigame")
	var info_lbl = Label.new()
	if category_str == "Event":
		info_lbl.text = "📢 Event: %s" % game_name
	else:
		info_lbl.text = "%s - %s" % [category_str, game_name]
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.add_theme_font_size_override("font_size", 36)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: info_lbl.add_theme_font_override("font", font)
	hbox.add_child(info_lbl)
	
	var won = entry.get("won", false)
	var badge = Label.new()
	if category_str == "Event":
		badge.text = " EVENT "
		badge.add_theme_font_size_override("font_size", 32)
		badge.add_theme_color_override("font_color", Color(0.3, 0.75, 1.0))
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color(0.2, 0.6, 1.0, 0.2)
		badge_style.corner_radius_top_left = 6
		badge_style.corner_radius_top_right = 6
		badge_style.corner_radius_bottom_left = 6
		badge_style.corner_radius_bottom_right = 6
		badge.add_theme_stylebox_override("normal", badge_style)
	else:
		badge.text = " BERHASIL " if won else " GAGAL "
		badge.add_theme_font_size_override("font_size", 32)
		badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color(0.2, 0.9, 0.4, 0.15) if won else Color(0.9, 0.3, 0.3, 0.15)
		badge_style.corner_radius_top_left = 6
		badge_style.corner_radius_top_right = 6
		badge_style.corner_radius_bottom_left = 6
		badge_style.corner_radius_bottom_right = 6
		badge.add_theme_stylebox_override("normal", badge_style)
	if font: badge.add_theme_font_override("font", font)
	hbox.add_child(badge)
	
	return item

func _play_entrance_animations() -> void:
	modulate.a = 0.0
	var fader = create_tween()
	fader.tween_property(self, "modulate:a", 1.0, 0.3)
	await fader.finished
	
	var fill_tween = create_tween().set_parallel(true)
	for bar_data in animated_bars:
		var bar = bar_data["bar"] as ProgressBar
		var target = bar_data["target"] as float
		fill_tween.tween_property(bar, "value", target, 1.0)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
			
	await fill_tween.finished
	
	var button_tween = create_tween()
	button_tween.tween_property(btn_close, "modulate:a", 1.0, 0.2)
	btn_close.disabled = false

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

func _on_close_pressed() -> void:
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	checkup_closed.emit()
