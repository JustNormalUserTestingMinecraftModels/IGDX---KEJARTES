extends CanvasLayer
class_name MinigameTutorial

signal tutorial_finished

# ─── Visual - Background Overlay ─────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Drag a PNG here for the full-screen background overlay texture.
@export var overlay_bg_texture: Texture2D = null
## Color tint of the overlay background.
@export var overlay_bg_color: Color = Color(0, 0, 0, 0.85)

# ─── Visual - Dialog Box ─────────────────────────────────────────────────────
@export_group("Visual - Dialog Box")
## Drag a PNG here for the tutorial popup box card background.
@export var dialog_box_texture: Texture2D = null
@export var dialog_bg_color: Color = Color(0.1, 0.12, 0.18, 0.95)
@export var dialog_border_color: Color = Color(0.4, 0.65, 1.0, 0.75)
@export var dialog_corner_radius: int = 16
@export var dialog_texture_margin: int = 16

# ─── Visual - Texts & Typography ─────────────────────────────────────────────
@export_group("Visual - Texts & Typography")
## Prompt text displayed at the bottom of the popup (e.g. "Ketuk untuk melanjutkan").
@export var blink_prompt_text: String = "Ketuk untuk melanjutkan"
## Assign a custom Font resource. Leave null for default theme font.
@export var font: Font = null
@export var title_font_size: int = 48
@export var title_font_color: Color = Color(1.0, 0.88, 0.35)
@export var instructions_font_size: int = 32
@export var instructions_font_color: Color = Color(0.92, 0.94, 0.98)
@export var blink_font_size: int = 30
@export var blink_font_color: Color = Color(0.35, 0.9, 0.55)

var tutorial_title_text: String = ""
var tutorial_instructions_text: String = ""

var bg: Control
var center_container: CenterContainer
var blink_label: Label
var blink_tween: Tween
var is_dismissed: bool = false

func setup(title: String, instructions: String) -> void:
	tutorial_title_text = title
	tutorial_instructions_text = instructions

func _ready() -> void:
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS

	var screen_size = get_viewport().get_visible_rect().size

	# Background Overlay
	if overlay_bg_texture:
		var bg_tex = TextureRect.new()
		bg_tex.texture = overlay_bg_texture
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
		bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_tex.modulate = overlay_bg_color
		bg = bg_tex
	else:
		var bg_rect = ColorRect.new()
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_rect.color = overlay_bg_color
		bg = bg_rect
	add_child(bg)

	_build_ui(screen_size)
	_start_blinking()

func _build_ui(screen_size: Vector2) -> void:
	center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_container)

	var panel = PanelContainer.new()
	var target_w = min(screen_size.x * 0.9, 920)
	var max_h = min(screen_size.y * 0.8, 1500)
	panel.custom_minimum_size = Vector2(target_w, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if dialog_box_texture:
		var sb_tex = StyleBoxTexture.new()
		sb_tex.texture = dialog_box_texture
		sb_tex.texture_margin_left   = dialog_texture_margin
		sb_tex.texture_margin_right  = dialog_texture_margin
		sb_tex.texture_margin_top    = dialog_texture_margin
		sb_tex.texture_margin_bottom = dialog_texture_margin
		panel.add_theme_stylebox_override("panel", sb_tex)
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = dialog_bg_color
		style.corner_radius_top_left = dialog_corner_radius
		style.corner_radius_top_right = dialog_corner_radius
		style.corner_radius_bottom_left = dialog_corner_radius
		style.corner_radius_bottom_right = dialog_corner_radius
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = dialog_border_color
		style.shadow_color = Color(0, 0, 0, 0.6)
		style.shadow_size = 14
		panel.add_theme_stylebox_override("panel", style)
	center_container.add_child(panel)

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = tutorial_title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", title_font_size)
	title_lbl.add_theme_color_override("font_color", title_font_color)
	title_lbl.add_theme_constant_override("outline_size", 6)
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	if font: title_lbl.add_theme_font_override("font", font)
	vbox.add_child(title_lbl)

	# Divider line
	var hs = HSeparator.new()
	hs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hs)

	# ScrollContainer to prevent any text clipping on smaller screens
	var scroll = ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, min(screen_size.y * 0.45, 380))
	vbox.add_child(scroll)

	# Instructions Content
	var desc_lbl = Label.new()
	desc_lbl.text = tutorial_instructions_text
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(target_w - 50, 0)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", instructions_font_size)
	desc_lbl.add_theme_color_override("font_color", instructions_font_color)
	desc_lbl.add_theme_constant_override("line_spacing", 4)
	if font: desc_lbl.add_theme_font_override("font", font)
	scroll.add_child(desc_lbl)

	# Divider line
	var hs2 = HSeparator.new()
	hs2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hs2)

	# Blinking prompt text
	blink_label = Label.new()
	blink_label.text = blink_prompt_text
	blink_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blink_label.add_theme_font_size_override("font_size", blink_font_size)
	blink_label.add_theme_color_override("font_color", blink_font_color)
	blink_label.add_theme_constant_override("outline_size", 6)
	blink_label.add_theme_color_override("font_outline_color", Color.BLACK)
	if font: blink_label.add_theme_font_override("font", font)
	vbox.add_child(blink_label)

func _start_blinking() -> void:
	blink_label.modulate.a = 1.0
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(blink_label, "modulate:a", 0.25, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blink_tween.tween_property(blink_label, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _input(event: InputEvent) -> void:
	if is_dismissed:
		return

	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch = (event is InputEventScreenTouch and event.pressed)

	if is_click or is_touch:
		get_viewport().set_input_as_handled()
		_dismiss()

func _dismiss() -> void:
	if is_dismissed:
		return
	is_dismissed = true

	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()

	tutorial_finished.emit()
	queue_free()
