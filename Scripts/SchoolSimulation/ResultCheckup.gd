extends Control

## The end-of-week report card: one &"Card" per student with five
## category-tinted StatBars filling from last week's value, followed by a
## log of the week's minigames and events.
##
## Every surface is a theme variation and every accent is a DesignToken;
## this script builds no StyleBoxFlat and holds no Color literal.

signal checkup_closed

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the report. When set it replaces the panel.
@export var background_texture: Texture2D = null

# ── Visual - Header & Typography ──────────────────────────────────────────────
@export_group("Visual - Header & Typography")
@export var header_title_text: String = "EVALUASI MINGGUAN SISWA"
@export var header_subtitle_text: String = "Perkembangan statistik & riwayat kegiatan selama satu minggu"
@export var students_section_header_text: String = "RAPOR MINGGUAN SISWA"
@export var history_section_header_text: String = "RIWAYAT MINIGAME & EVENT"
@export var students_header_icon_texture: Texture2D = null
@export var history_header_icon_texture: Texture2D = null
@export var font: Font = null

# ── Visual - Buttons (Single-PNG System) ─────────────────────────────────────
@export_group("Visual - Buttons")
@export var button_close_texture: Texture2D = null
@export var close_button_text: String = "Selesai Evaluasi"

const _BADGE_SCENE := "res://Scenes/SchoolSimulation/DaySummaryBadge.tscn"
const _AVATAR_SIZE := 240

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

	var cards: Array = []
	for student in student_manager.students:
		var card = _create_student_card(student, student_manager.minigame_history)
		students_container.add_child(card)
		_set_mouse_filter_pass(card)
		cards.append(card)

	if student_manager.minigame_history.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Tidak ada minigame yang dimainkan minggu ini."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.theme_type_variation = &"CaptionLabel"
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font: empty_lbl.add_theme_font_override("font", font)
		history_list.add_child(empty_lbl)
	else:
		for entry in student_manager.minigame_history:
			var item = _create_history_item(entry)
			history_list.add_child(item)
			_set_mouse_filter_pass(item)

	_play_entrance_animations(cards)

func _apply_visual_exports() -> void:
	# The themed panel is the default backdrop; an art-supplied photo
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

	if title_label:
		title_label.text = header_title_text
		if font: title_label.add_theme_font_override("font", font)

	if subtitle_label:
		subtitle_label.text = header_subtitle_text
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
	panel.theme_type_variation = &"Card"

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
	avatar_vbox.custom_minimum_size = Vector2(_AVATAR_SIZE, 0)
	main_hbox.add_child(avatar_vbox)

	var avatar_frame = AspectRatioContainer.new()
	avatar_frame.ratio = 1.0
	avatar_frame.custom_minimum_size = Vector2(_AVATAR_SIZE, _AVATAR_SIZE)
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
			avatar.texture = _placeholder_avatar()

	avatar_frame.add_child(avatar)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = student.student_name
	name_lbl.theme_type_variation = &"H2Label"
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: name_lbl.add_theme_font_override("font", font)
	info_vbox.add_child(name_lbl)

	var akademis_delta: float = student.get_akademis_delta()
	var seni_delta: float     = student.get_seni_delta()
	var olahraga_delta: float = student.get_olahraga_delta()
	var energy_delta: float   = student.get_energy_delta()
	var mood_delta: float     = student.get_mood_delta()

	info_vbox.add_child(_section_header("STATS"))

	_add_stat_bar(info_vbox, "Akademis", student.akademis, akademis_delta, "Akademis")
	_add_stat_bar(info_vbox, "Seni Budaya", student.seni_budaya, seni_delta, "SeniBudaya")
	_add_stat_bar(info_vbox, "Olahraga", student.olahraga, olahraga_delta, "Olahraga")

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	info_vbox.add_child(sep)

	info_vbox.add_child(_section_header("NEEDS"))

	# Energy and Mood are needs, not schedule categories; Libur (warm gold)
	# and Istirahat (violet) are the accents the rest of the game uses.
	_add_stat_bar(info_vbox, "Energy ⚡", student.energy, energy_delta, "Libur")
	_add_stat_bar(info_vbox, "Mood 😊", student.mood, mood_delta, "Istirahat")

	return panel


func _section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.theme_type_variation = &"TitleLabel"
	lbl.self_modulate = Juice.tokens().text_secondary
	if font: lbl.add_theme_font_override("font", font)
	return lbl


## Last-resort avatar when a student has neither an assigned texture nor a
## portrait PNG: a two-stop gradient in a random hue. No literal needed --
## Color.from_hsv builds it and darkened() derives the second stop.
func _placeholder_avatar() -> GradientTexture2D:
	var placeholder = GradientTexture2D.new()
	placeholder.width = _AVATAR_SIZE
	placeholder.height = _AVATAR_SIZE
	var grad = Gradient.new()
	var col = Color.from_hsv(randf(), 0.6, 0.8)
	grad.colors = PackedColorArray([col.darkened(0.5), col])
	placeholder.gradient = grad
	return placeholder


func _add_stat_bar(parent: VBoxContainer, stat_name: String, target_val: float, delta: float, category: String) -> void:
	var tokens := Juice.tokens()
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var label = Label.new()
	label.text = stat_name
	label.custom_minimum_size = Vector2(220, 0)
	label.theme_type_variation = &"TitleLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: label.add_theme_font_override("font", font)
	row.add_child(label)

	var bar := StatBar.new()
	bar.category = category
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 48)

	var start_val = clampf(target_val - delta, 0.0, 100.0)
	bar.value = start_val
	row.add_child(bar)

	animated_bars.append({
		"bar": bar,
		"target": target_val
	})

	var delta_lbl = Label.new()
	delta_lbl.custom_minimum_size = Vector2(120, 0)
	delta_lbl.theme_type_variation = &"TitleLabel"
	if font: delta_lbl.add_theme_font_override("font", font)
	if delta > 0:
		delta_lbl.text = "+%d" % int(delta)
		delta_lbl.self_modulate = tokens.state_success
	elif delta < 0:
		delta_lbl.text = "%d" % int(delta)
		delta_lbl.self_modulate = tokens.state_danger
	else:
		delta_lbl.text = "--"
		delta_lbl.self_modulate = tokens.text_secondary
	row.add_child(delta_lbl)

func _create_history_item(entry: Dictionary) -> PanelContainer:
	var tokens := Juice.tokens()
	var item = PanelContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.theme_type_variation = &"SunkenPanel"

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
	day_lbl.theme_type_variation = &"TitleLabel"
	day_lbl.self_modulate = tokens.brand_primary
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
	info_lbl.theme_type_variation = &"TitleLabel"
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: info_lbl.add_theme_font_override("font", font)
	hbox.add_child(info_lbl)

	var won = entry.get("won", false)
	if category_str == "Event":
		hbox.add_child(_make_badge(" EVENT ", tokens.brand_primary))
	elif won:
		hbox.add_child(_make_badge(" BERHASIL ", tokens.state_success))
	else:
		hbox.add_child(_make_badge(" GAGAL ", tokens.state_danger))

	return item


## Shared chip: the DaySummaryBadge scene (SunkenPanel + BarLabel), tinted
## via self_modulate so the child label keeps the theme's own contrast.
func _make_badge(text: String, tint: Color) -> PanelContainer:
	var chip := load(_BADGE_SCENE).instantiate() as PanelContainer
	chip.self_modulate = tint
	var lbl := chip.get_node("Text") as Label
	lbl.text = text
	if font: lbl.add_theme_font_override("font", font)
	return chip


func _play_entrance_animations(cards: Array = []) -> void:
	var t := Juice.tokens()
	modulate.a = 0.0
	var fader = create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished

	# Cards land one at a time only after the screen itself is visible --
	# staggering under a still-transparent root wastes the effect.
	Juice.stagger_in(cards)

	for bar_data in animated_bars:
		Juice.fill_bar(bar_data["bar"] as StatBar, bar_data["target"] as float)
	await get_tree().create_timer(t.dur_slow).timeout

	var button_tween = create_tween()
	button_tween.tween_property(btn_close, "modulate:a", 1.0, t.dur_fast)
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
	AudioDirector.play_sfx(&"confirm")
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, Juice.tokens().dur_normal)
	await fade_out.finished
	checkup_closed.emit()
