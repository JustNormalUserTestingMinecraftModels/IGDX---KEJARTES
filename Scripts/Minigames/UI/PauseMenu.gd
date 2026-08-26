extends Control
class_name PauseMenu

signal resume_pressed
signal settings_pressed
signal quit_pressed

# [NEW FEATURE] Pause Menu component for Minigames

# ─── Visual - Background Overlay ─────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Drag a PNG here for the full-screen dark background overlay texture.
@export var overlay_bg_texture: Texture2D = null
@export var overlay_bg_color: Color = Color(0, 0, 0, 0.65)

# ─── Visual - Dialog Box ─────────────────────────────────────────────────────
@export_group("Visual - Dialog Box")
## Drag a PNG here for the pause menu dialog card background.
@export var dialog_box_texture: Texture2D = null
@export var dialog_bg_color: Color = Color(0.12, 0.15, 0.22, 0.95)
@export var dialog_border_color: Color = Color(0.4, 0.65, 1.0, 0.75)
@export var dialog_texture_margin: int = 12

# ─── Visual - Buttons (Single-PNG System) ───────────────────────────────────
@export_group("Visual - Buttons")
## PNG texture for Lanjutkan (Resume) button.
@export var button_resume_texture: Texture2D = null
## PNG texture for Pengaturan (Settings) button.
@export var button_settings_texture: Texture2D = null
## PNG texture for Keluar (Quit) button.
@export var button_quit_texture: Texture2D = null
## Grey tint applied when a button is pressed.
@export var button_pressed_tint: Color = Color(0.65, 0.65, 0.65, 1.0)
## Grey tint applied when a button is disabled.
@export var button_disabled_tint: Color = Color(0.55, 0.55, 0.55, 0.75)
## Scale the button shrinks to on press.
@export var button_press_scale: float = 0.92
## Duration of the press shrink animation.
@export var button_press_duration: float = 0.07
## Texture padding margin inside the button.
@export var button_texture_margin: int = 8

# ─── Visual - Texts & Typography ─────────────────────────────────────────────
@export_group("Visual - Texts & Typography")
@export var title_text: String = "GAME DIPAUS"
@export var resume_text: String = "Lanjutkan"
@export var settings_text: String = "Pengaturan"
@export var quit_text: String = "Keluar"
@export var font: Font = null
@export var title_font_size: int = 54
@export var title_font_color: Color = Color.WHITE
@export var button_font_size: int = 36
@export var button_font_color: Color = Color.WHITE

@onready var btn_resume: Button = $PanelContainer/VBoxContainer/BtnResume
@onready var btn_settings: Button = $PanelContainer/VBoxContainer/BtnSettings
@onready var btn_quit: Button = $PanelContainer/VBoxContainer/BtnQuit

func _ready() -> void:
	_apply_visual_exports()
	if btn_resume:
		btn_resume.pressed.connect(func(): _play_boing(btn_resume, func(): resume_pressed.emit()))
	if btn_settings:
		btn_settings.pressed.connect(func(): _play_boing(btn_settings, func(): settings_pressed.emit()))
	if btn_quit:
		btn_quit.pressed.connect(func(): _play_boing(btn_quit, func(): quit_pressed.emit()))

func _apply_visual_exports() -> void:
	var bg = get_node_or_null("OverlayBackground")
	if bg:
		if overlay_bg_texture:
			if bg is ColorRect:
				var tex_rect = TextureRect.new()
				tex_rect.name = "OverlayBackground"
				tex_rect.texture = overlay_bg_texture
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				tex_rect.modulate = overlay_bg_color
				add_child(tex_rect)
				move_child(tex_rect, 0)
				bg.queue_free()
		elif bg is ColorRect:
			bg.color = overlay_bg_color

	var title_lbl = get_node_or_null("PanelContainer/VBoxContainer/TitleLabel") as Label
	if title_lbl:
		title_lbl.text = title_text
		title_lbl.add_theme_font_size_override("font_size", title_font_size)
		title_lbl.add_theme_color_override("font_color", title_font_color)
		if font: title_lbl.add_theme_font_override("font", font)

	var btn_map = {
		btn_resume: {"tex": button_resume_texture, "txt": resume_text},
		btn_settings: {"tex": button_settings_texture, "txt": settings_text},
		btn_quit: {"tex": button_quit_texture, "txt": quit_text}
	}

	for btn in btn_map:
		if not btn: continue
		var info = btn_map[btn]
		var tex: Texture2D = info["tex"]
		var txt: String = info["txt"]

		btn.text = "" if tex else txt
		btn.add_theme_font_size_override("font_size", button_font_size)
		btn.add_theme_color_override("font_color", button_font_color)
		if font: btn.add_theme_font_override("font", font)

		if tex:
			var sb_norm = _make_btn_stylebox(tex, Color.WHITE)
			var sb_press = _make_btn_stylebox(tex, button_pressed_tint)
			var sb_dis = _make_btn_stylebox(tex, button_disabled_tint)
			btn.add_theme_stylebox_override("normal", sb_norm)
			btn.add_theme_stylebox_override("hover", sb_norm)
			btn.add_theme_stylebox_override("pressed", sb_press)
			btn.add_theme_stylebox_override("disabled", sb_dis)
			btn.add_theme_stylebox_override("focus", sb_norm)

		btn.pivot_offset = btn.size / 2.0
		btn.resized.connect(func(): if is_instance_valid(btn): btn.pivot_offset = btn.size / 2.0)

func _make_btn_stylebox(tex: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.modulate_color = tint
	sb.texture_margin_left   = button_texture_margin
	sb.texture_margin_right  = button_texture_margin
	sb.texture_margin_top    = button_texture_margin
	sb.texture_margin_bottom = button_texture_margin
	return sb

func _play_boing(btn: Button, on_complete: Callable) -> void:
	if not btn or not is_instance_valid(btn):
		on_complete.call()
		return
		
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	# Squash & Stretch Boing animation
	tween.tween_property(btn, "scale", Vector2(1.22, 0.75), 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(0.82, 1.28), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.08, 0.92), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.09)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		
	tween.tween_callback(on_complete)
