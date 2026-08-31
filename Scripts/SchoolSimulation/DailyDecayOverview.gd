extends Control

## "What the night cost them": a per-student breakdown of the daily energy
## and mood decay, with the bars animating down from yesterday's value.
##
## Fully theme-driven now -- Scrim behind a Card, one &"Card" per student,
## StatBars for the two needs, and the shared DaySummaryBadge chip for the
## personality tag. No StyleBoxFlat and no Color literal remains.

signal overview_closed

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the overview. When set it replaces the Scrim panel.
@export var background_texture: Texture2D = null

# ── Visual - Header & Typography ──────────────────────────────────────────────
@export_group("Visual - Header & Typography")
@export var title_format_text: String = "🌅 Aktivitas & Evaluasi Harian (%s)"
@export var subtitle_text: String = "Pengurangan Energi & Mood siswa sesuai kepribadian & rutinitas"
@export var sunrise_icon_texture: Texture2D = null
@export var font: Font = null

# ── Visual - Buttons (Single-PNG System) ─────────────────────────────────────
@export_group("Visual - Buttons")
@export var button_continue_texture: Texture2D = null
@export var continue_button_text: String = "Lanjutkan"

const _BADGE_SCENE := "res://Scenes/SchoolSimulation/DaySummaryBadge.tscn"

## Shared icon(-or-glyph) + bar + number row used for the Energy/Mood
## breakdown lines. This screen never has an icon texture, so its rows
## always show the full-sentence Glyph label ("Energy ⚡") instead.
@export var student_stat_row_scene: PackedScene = preload("res://Scenes/SchoolSimulation/StudentStatRow.tscn")
## Shared Card+Margin chrome for the per-student decay card. Uses the
## component's own 20/16/20/16 margin defaults unchanged.
@export var student_summary_card_scene: PackedScene = preload("res://Scenes/SchoolSimulation/StudentSummaryCard.tscn")

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
	AudioDirector.play_sfx(&"popup_open")
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, Juice.tokens().dur_normal)
	await fade_in.finished

	var cards: Array = []
	for res in decay_results:
		var card = _create_student_decay_card(res)
		students_container.add_child(card)
		_set_mouse_filter_pass(card)
		cards.append(card)

	Juice.stagger_in(cards)

	await get_tree().create_timer(Juice.tokens().dur_fast).timeout

	for child in students_container.get_children():
		if child.has_meta("animate_bars"):
			var anim_callable = child.get_meta("animate_bars") as Callable
			if anim_callable.is_valid():
				anim_callable.call()

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

	if title_label:
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
	var tokens := Juice.tokens()
	var card: StudentSummaryCard = student_summary_card_scene.instantiate()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# The panel hasn't entered the tree yet (it's returned to the caller,
	# which parents it later), so the @onready `margin` isn't live --
	# get_node still works because instantiate() built the subtree.
	var margin: MarginContainer = card.get_node("Margin")

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(header_hbox)

	var name_lbl = Label.new()
	name_lbl.text = res.get("student_name", "")
	name_lbl.theme_type_variation = &"H2Label"
	if font: name_lbl.add_theme_font_override("font", font)
	header_hbox.add_child(name_lbl)

	header_hbox.add_child(_make_badge(
		" %s " % res.get("personality", "Santai"), tokens.brand_primary))

	var reason_lbl = Label.new()
	reason_lbl.text = "💬 %s" % res.get("reason", "Aktivitas harian")
	reason_lbl.theme_type_variation = &"TitleLabel"
	reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: reason_lbl.add_theme_font_override("font", font)
	vbox.add_child(reason_lbl)

	var curr_e = float(res.get("current_energy", 80.0))
	var e_loss = float(res.get("energy_loss", 5.0))
	var start_e = clampf(curr_e + e_loss, 0.0, 100.0)

	var curr_m = float(res.get("current_mood", 80.0))
	var m_loss = float(res.get("mood_loss", 5.0))
	var start_m = clampf(curr_m + m_loss, 0.0, 100.0)

	# Energy and Mood are needs, not schedule categories; Libur (warm gold)
	# and Istirahat (violet) are the accents the rest of the game already
	# uses for them.
	var e_data = _add_bar_row(vbox, "Energy ⚡", start_e, "Libur")
	var m_data = _add_bar_row(vbox, "Mood 😊", start_m, "Istirahat")

	var animate_func = func():
		var e_bar = e_data["bar"] as StatBar
		var e_info = e_data["info_lbl"] as Label
		Juice.fill_bar(e_bar, curr_e)
		e_info.text = "%d ➔ %d (-%d)" % [int(start_e), int(curr_e), int(e_loss)]
		e_info.self_modulate = tokens.state_danger

		var m_bar = m_data["bar"] as StatBar
		var m_info = m_data["info_lbl"] as Label
		Juice.fill_bar(m_bar, curr_m)
		m_info.text = "%d ➔ %d (-%d)" % [int(start_m), int(curr_m), int(m_loss)]
		m_info.self_modulate = tokens.state_danger

	card.set_meta("animate_bars", animate_func)
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


## Instantiates the shared StudentStatRow with this screen's wider Glyph
## label, taller bar and TitleLabel-variant InfoLabel -- the three ways
## this row differs from SchoolDay's embedded one. Returns the same
## {"bar", "info_lbl"} shape callers have always used.
func _add_bar_row(parent_vbox: VBoxContainer, label_text: String, start_val: float, category: String) -> Dictionary:
	var row: StudentStatRow = student_stat_row_scene.instantiate()
	row.glyph_min_width = 220.0
	row.bar_min_height = 48.0
	row.info_label_variation = &"TitleLabel"
	if font:
		row.custom_font = font
	parent_vbox.add_child(row)
	row.setup(label_text, start_val, category)

	return {
		"bar": row.bar,
		"info_lbl": row.info_label
	}

func _set_mouse_filter_pass(node: Node) -> void:
	if node is Control and not (node is Button):
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_filter_pass(child)

func _on_continue_pressed() -> void:
	AudioDirector.play_sfx(&"popup_close")
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, Juice.tokens().dur_normal)
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
