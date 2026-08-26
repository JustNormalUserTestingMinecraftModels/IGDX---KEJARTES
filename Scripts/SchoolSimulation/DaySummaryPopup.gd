extends Control
class_name DaySummaryPopup

signal summary_dismissed

@export var student_row_scene: PackedScene

@export_group("Card Styling")
@export var card_bg_color: Color = Color(0.06, 0.08, 0.16)
@export var card_border_color: Color = Color(0.18, 0.22, 0.38)
@export var card_border_width: int = 4
@export var card_corner_radius: int = 28

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var card_panel: PanelContainer = $DimOverlay/MarginContainer/CardPanel
@onready var title_label: Label = $DimOverlay/MarginContainer/CardPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var rows_container: VBoxContainer = $DimOverlay/MarginContainer/CardPanel/MarginContainer/VBoxContainer/RowsContainer
@onready var hint_label: Label = $DimOverlay/MarginContainer/CardPanel/MarginContainer/VBoxContainer/HintLabel

var is_dismissable: bool = false

func _ready() -> void:
	_apply_visual_styles()

func _apply_visual_styles() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = card_bg_color
	sb.border_color = card_border_color
	sb.border_width_left = card_border_width
	sb.border_width_top = card_border_width
	sb.border_width_right = card_border_width
	sb.border_width_bottom = card_border_width
	sb.corner_radius_top_left = card_corner_radius
	sb.corner_radius_top_right = card_corner_radius
	sb.corner_radius_bottom_left = card_corner_radius
	sb.corner_radius_bottom_right = card_corner_radius
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	sb.content_margin_left = 32
	sb.content_margin_top = 28
	sb.content_margin_right = 32
	sb.content_margin_bottom = 28
	card_panel.add_theme_stylebox_override("panel", sb)

func setup_summary(day_name: String, summary_data: Array, students: Array[StudentData]) -> void:
	title_label.text = "%s - Rangkuman Hari" % day_name.to_upper()
	
	# Clear old rows
	for child in rows_container.get_children():
		child.queue_free()
		
	# Populate rows
	for entry in summary_data:
		var s_name = entry.get("student_name", "")
		var changes = entry.get("changes", [])
		if changes.is_empty():
			continue
			
		var student: StudentData = null
		for s in students:
			if s.student_name == s_name:
				student = s
				break
				
		var row_inst = student_row_scene.instantiate()
		rows_container.add_child(row_inst)
		row_inst.setup_row(s_name, changes, student)
		
	# Animate in
	dim_overlay.color.a = 0.0
	card_panel.modulate.a = 0.0
	card_panel.scale = Vector2(0.85, 0.85)
	
	# Set pivot dynamically for scale bounce
	var vp_size = get_viewport_rect().size
	card_panel.pivot_offset = Vector2((vp_size.x - 72) / 2.0, (vp_size.y - 96) / 2.0)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(dim_overlay, "color:a", 0.62, 0.25)
	tw.tween_property(card_panel, "modulate:a", 1.0, 0.22)
	tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	is_dismissable = true

func _input(event: InputEvent) -> void:
	if not is_dismissable:
		return
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch = (event is InputEventScreenTouch and event.pressed)
	var is_key = (event is InputEventKey and event.pressed and event.keycode != KEY_O)
	
	if is_click or is_touch or is_key:
		is_dismissable = false
		dismiss()

func dismiss() -> void:
	var tw = create_tween().set_parallel(true)
	tw.tween_property(card_panel, "modulate:a", 0.0, 0.18)
	tw.tween_property(dim_overlay, "modulate:a", 0.0, 0.22)
	await tw.finished
	summary_dismissed.emit()
	queue_free()
