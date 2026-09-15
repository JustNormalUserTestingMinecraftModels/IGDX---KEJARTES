extends Control

## "Who takes part in this event?" — one selectable card per student with
## a live preview of what accepting would do to their stats.
##
## Each student is an EventStudentCard: the real DaySummary card inside a
## toggle Button (StudentCardButton), showing where the student stands now.
## Selecting a card layers the event's effect on top. The dialog's own
## chrome is theme-driven; nothing here builds a StyleBoxFlat.

signal event_decision_made(accepted: bool, selected_students: Array[StudentData])

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the dialog. When set it replaces the Scrim panel.
@export var background_texture: Texture2D = null

# ── Visual - Dialog Card Panel ───────────────────────────────────────────────
@export_group("Visual - Dialog Card Panel")
## Art-supplied background for dialog_panel. Null keeps the theme's Card
## styling.
@export var dialog_card_texture: Texture2D = null

# ── Visual - Buttons ─────────────────────────────────────────────────────────
# The three action buttons take their look from the theme's
# PrimaryButton / SecondaryButton / DangerButton variations -- the same
# ones every other screen in the game uses. The StyleBoxTexture override
# path that used to sit here was removed on 2026-09-07: it was the one
# thing that let these three drift out of theme.
@export_group("Visual - Buttons")
## Label on the select-all button.
@export var select_all_text: String = "Pilih Semua"
## Label on the cancel button.
@export var cancel_text: String = "Lewati Event"
## Label on the confirm button. `%d` is filled with the currently-selected
## student count.
@export var confirm_format_text: String = "Ya, Ikutsertakan (%d Siswa)"

# ── Visual - Typography ───────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Optional font override applied to every label and button on this
## screen. Null keeps the theme's default font.
@export var font: Font = null

# Each selectable student is EventStudentCard.tscn: the real DaySummary card
# inside a toggle Button. The cards used to be assembled here at runtime;
# that went on 2026-09-07.
const CARD_SCENE := preload("res://Scenes/SchoolSimulation/EventStudentCard.tscn")


@onready var dialog_panel: PanelContainer = $Margin/DialogPanel
@onready var title_label: Label = $Margin/DialogPanel/Margin/MainVBox/TitleLabel
@onready var desc_label: Label = $Margin/DialogPanel/Margin/MainVBox/DescLabel
@onready var benefit_label: Label = $Margin/DialogPanel/Margin/MainVBox/CostBenefitBox/BenefitRow/Text
@onready var cost_label: Label = $Margin/DialogPanel/Margin/MainVBox/CostBenefitBox/CostRow/Text
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
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"popup_open")
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
	# Two icon-and-text rows now, so the up/down arrows are real SVGs
	# textures rather than the emoji glyphs this line used to carry.
	if benefit_label:
		benefit_label.text = "Manfaat: %s" % benefit_info
	if cost_label:
		cost_label.text = "Biaya: %s" % cost_info

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

	for lbl in [title_label, desc_label, benefit_label, cost_label]:
		if lbl and font:
			lbl.add_theme_font_override("font", font)

	# Text and font only. The look is the theme's -- see the note on the
	# Visual - Buttons group.
	var btns := {
		select_all_button: select_all_text,
		cancel_button: cancel_text,
		confirm_button: confirm_format_text % 0,
	}
	for btn in btns:
		if not btn:
			continue
		btn.text = btns[btn]
		if font:
			btn.add_theme_font_override("font", font)

func _populate_student_cards() -> void:
	if students_container == null:
		return

	for child in students_container.get_children():
		child.queue_free()

	card_widgets.clear()

	var category: String = event_data.get("category", "Akademis")
	var cards: Array = []
	for student in student_list:
		var card: EventStudentCard = CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_FILL
		students_container.add_child(card)
		# setup() only after the card is in the tree: its stat rows tween
		# through Juice, which needs the bar parented before it can make
		# a tween on it.
		card.setup(student, category)
		card.selection_changed.connect(
			func(_selected: bool) -> void: _update_card_preview(student.student_name))
		card_widgets[student.student_name] = card
		cards.append(card)

	Juice.stagger_in(cards)
	_update_confirm_button()


## Re-reads one card against the current selection: selected shows what
## accepting would do, cleared rewinds to the student's standing values.
func _update_card_preview(student_name: String) -> void:
	var card := card_widgets.get(student_name) as EventStudentCard
	if card == null:
		return

	if not card.is_selected():
		card.set_preview(0.0, 0.0, 0.0)
		_update_confirm_button()
		return

	var category: String = event_data.get("category", "Akademis")
	var student := card.student()
	var energy_cost := float(event_data.get("energy_cost", -15.0))
	# Specialty students spend less energy on their own category, so the
	# preview has to show the discounted figure or the card lies about
	# what accepting costs.
	if energy_cost < 0.0 and student != null:
		energy_cost = roundf(
			energy_cost * student.get_category_efficiency_multiplier(category))

	card.set_preview(
		float(event_data.get("stat_boost", 15.0)),
		energy_cost,
		float(event_data.get("mood_boost", 0.0)))
	_update_confirm_button()


func _update_confirm_button() -> void:
	var count := 0
	for student_name in card_widgets:
		var card := card_widgets[student_name] as EventStudentCard
		if card and card.is_selected():
			count += 1

	if confirm_button:
		confirm_button.text = confirm_format_text % count
		confirm_button.disabled = (count == 0)


func _on_select_all_pressed() -> void:
	AudioDirector.play_sfx(&"select")
	# Toggle: if every selectable card is already on, this clears them.
	var all_selected := true
	for student_name in card_widgets:
		var card := card_widgets[student_name] as EventStudentCard
		if card and not card.disabled and not card.is_selected():
			all_selected = false
			break

	for student_name in card_widgets:
		var card := card_widgets[student_name] as EventStudentCard
		if card and not card.disabled:
			card.button_pressed = not all_selected

	_update_confirm_button()


func _on_confirm_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	var selected: Array[StudentData] = []
	for student in student_list:
		var card := card_widgets.get(student.student_name) as EventStudentCard
		if card and card.is_selected():
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
