@tool
extends Control

## The end-of-week report card: one Daily Results card per student -- the
## same DaySummaryStudentRow the nightly popup shows -- read one week
## wide instead of one day, followed by a log of the week's minigames and
## events.
##
## Each card's three stat numbers are "+<the week's gain>/<target>", and
## its two needs bars carry the week's energy and mood movement as a
## signed number. All of that lives on the card; this screen only chooses
## WHICH deltas the card is shown (see DaySummaryStudentRow.setup_week_row).
##
## @tool so the in-editor test runner can build the screen and inspect it
## (CLAUDE.md, testing constraint 3). Everything with a real side effect
## is gated on Engine.is_editor_hint(); signal wiring deliberately is not.
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

# ── Wiring ───────────────────────────────────────────────────────────────────
## The per-student card. Assigned in ResultCheckup.tscn to
## DaySummaryStudentRow.tscn -- the same scene the nightly popup uses.
@export var student_card_scene: PackedScene

const _BADGE_SCENE := "res://Scenes/SchoolSimulation/DaySummaryBadge.tscn"

@onready var title_label: Label = $Margin/VBox/HeaderPanel/TitleLabel
@onready var subtitle_label: Label = $Margin/VBox/HeaderPanel/SubtitleLabel
@onready var students_container: VBoxContainer = $Margin/VBox/ScrollContainer/MainContent/StudentsContainer
@onready var history_list: VBoxContainer = $Margin/VBox/ScrollContainer/MainContent/HistoryList
@onready var scroll_container: ScrollContainer = $Margin/VBox/ScrollContainer
@onready var btn_close: Button = $Margin/VBox/BtnClose

var is_dragging_scroll: bool = false
var drag_start_y: float = 0.0
var initial_scroll_v: int = 0

func _ready() -> void:
	# Signal wiring stays ungated so the editor's test runner can exercise
	# it; everything below the guard is a real side effect.
	btn_close.pressed.connect(_on_close_pressed)
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)
	if Engine.is_editor_hint():
		return

	AudioDirector.play_sfx(&"popup_open")
	modulate.a = 0.0
	_apply_visual_exports()
	btn_close.modulate.a = 0.0
	btn_close.disabled = true

func initialize_checkup(student_manager: StudentManager) -> void:
	_apply_visual_exports()
	if student_manager == null:
		return

	for child in students_container.get_children():
		child.queue_free()
	for child in history_list.get_children():
		child.queue_free()

	var cards: Array = []
	for student in student_manager.students:
		var card := student_card_scene.instantiate() as DaySummaryStudentRow
		students_container.add_child(card)
		# Set up only once the card is in the tree: its @onready nodes are
		# null until then. Same order DaySummaryPopup.setup_summary uses.
		card.setup_week_row(student)
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
	# The runner builds this screen to inspect it, not to watch it. Under
	# the editor the cards stay exactly where setup_week_row left them.
	if Engine.is_editor_hint():
		return

	var t := Juice.tokens()
	modulate.a = 0.0
	var fader = create_tween()
	fader.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fader.finished

	# Cards land one at a time only after the screen itself is visible --
	# staggering under a still-transparent root wastes the effect.
	Juice.stagger_in(cards)

	# Each card's five gauges start moving on the beat that card ARRIVES
	# on -- the same offset stagger_in uses, so the week's growth and the
	# card's entrance share a rhythm. This is the nightly popup's own
	# cadence, one week long.
	for i in cards.size():
		cards[i].play_week_gain(float(i) * t.stagger_step)
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
