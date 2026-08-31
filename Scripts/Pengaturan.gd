extends CanvasLayer
class_name Pengaturan

## The settings overlay: a single toggle for the minigame tutorial,
## reading and writing `GameSettings.minigame_tutorial_enabled`
## (persisted immediately via `GameSettings.save_settings()`, unlike
## `GameState` which is session-only).
##
## Not an autoload -- whichever screen offers a settings button
## instantiates this by script and listens for `back_pressed` to know
## when to free it. Entirely hand-built in `_ready()`, including raw
## `StyleBoxFlat`/`theme_override_*` calls that predate the project's
## ThemeFactory rule -- out of scope for this documentation pass, but
## flagged here since it is the most-violating file in the viewport
## editability ratchet baseline.

signal back_pressed

func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS

	var screen_size = get_viewport().get_visible_rect().size

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(min(screen_size.x * 0.90, 960), 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.22, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 0.9, 0.8)
	style.shadow_size = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Pengaturan"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)

	var hs = HSeparator.new()
	vbox.add_child(hs)

	# Tutorial CheckBox Option
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var checkbox = CheckBox.new()
	checkbox.button_pressed = GameSettings.minigame_tutorial_enabled
	checkbox.toggled.connect(_on_tutorial_toggled)
	checkbox.custom_minimum_size = Vector2(120, 120)
	checkbox.scale = Vector2(2.4, 2.4)
	checkbox.pivot_offset = Vector2(60, 60)
	hbox.add_child(checkbox)

	var option_label = Label.new()
	option_label.text = "Minigame Tutorial"
	option_label.add_theme_font_size_override("font_size", 48)
	option_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hbox.add_child(option_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Back Button
	var btn_back = Button.new()
	btn_back.text = "Kembali"
	btn_back.custom_minimum_size = Vector2(480, 120)
	btn_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_back.add_theme_font_size_override("font_size", 48)
	btn_back.pressed.connect(_on_back_pressed.bind(btn_back))
	vbox.add_child(btn_back)

func _on_tutorial_toggled(toggled_on: bool) -> void:
	GameSettings.minigame_tutorial_enabled = toggled_on
	GameSettings.save_settings()

func _on_back_pressed(btn: Button) -> void:
	_play_button_boing(btn, func():
		back_pressed.emit()
		queue_free()
	)

func _play_button_boing(btn: Button, on_complete: Callable) -> void:
	if not btn or not is_instance_valid(btn):
		if on_complete.is_valid(): on_complete.call()
		return

	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	tween.tween_property(btn, "scale", Vector2(1.22, 0.75), 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(0.82, 1.28), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.08, 0.92), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.09)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	if on_complete.is_valid():
		tween.tween_callback(on_complete)
