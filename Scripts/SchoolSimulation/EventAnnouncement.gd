extends Control

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
@export var background_texture: Texture2D = null
@export var background_color: Color = Color(0.02, 0.08, 0.16, 0.92)

# ── Visual - Header & Texts ───────────────────────────────────────────────────
@export_group("Visual - Header & Texts")
@export var announcement_icon_texture: Texture2D = null
@export var announcement_symbol_text: String = "📢"
@export var header_prefix_text: String = "📢 PENGUMUMAN EVENT SEKOLAH"
@export var font: Font = null
@export var icon_font_size: int = 72
@export var icon_font_color: Color = Color(0.3, 0.75, 1.0, 1.0)
@export var header_font_size: int = 48
@export var header_font_color: Color = Color(0.4, 0.8, 1.0, 1.0)
@export var event_title_font_size: int = 56
@export var event_title_font_color: Color = Color.WHITE

@onready var icon_lbl: Label = $ContentMargin/Center/VBox/IconLabel
@onready var header_lbl: Label = $ContentMargin/Center/VBox/HeaderLabel
@onready var event_lbl: Label = $ContentMargin/Center/VBox/EventLabel

func _ready() -> void:
	modulate.a = 0.0

func play_announcement(event_title: String, _event_description: String = "") -> void:
	_apply_visual_exports()
	if event_lbl:
		event_lbl.text = event_title
		
	# Fade in announcement
	modulate.a = 0.0
	show()
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.25)
	await fade_in.finished
	
	# Pulse loudspeaker icon 3 times with blue glow feel
	var anim_node: CanvasItem = icon_lbl
	var tex_rect = icon_lbl.get_node_or_null("IconTextureRect") as TextureRect
	if tex_rect and tex_rect.visible:
		anim_node = tex_rect
	if anim_node:
		for i in range(3):
			var pulse = create_tween()
			pulse.tween_property(anim_node, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pulse.tween_property(anim_node, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await pulse.finished

	await get_tree().create_timer(0.4).timeout
	
	# Fade out
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.35)
	await fade_out.finished
	queue_free()

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

	if icon_lbl:
		if announcement_icon_texture:
			icon_lbl.text = ""
			var icon_size = Vector2(icon_font_size, icon_font_size)
			icon_lbl.custom_minimum_size = icon_size
			var tex_rect = icon_lbl.get_node_or_null("IconTextureRect") as TextureRect
			if not tex_rect:
				tex_rect = TextureRect.new()
				tex_rect.name = "IconTextureRect"
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.custom_minimum_size = icon_size
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				icon_lbl.add_child(tex_rect)
			tex_rect.texture = announcement_icon_texture
			tex_rect.custom_minimum_size = icon_size
			tex_rect.show()
		else:
			icon_lbl.text = announcement_symbol_text
			icon_lbl.custom_minimum_size = Vector2.ZERO
			icon_lbl.add_theme_font_size_override("font_size", icon_font_size)
			icon_lbl.add_theme_color_override("font_color", icon_font_color)
			if font: icon_lbl.add_theme_font_override("font", font)
			var tex_rect = icon_lbl.get_node_or_null("IconTextureRect")
			if tex_rect:
				tex_rect.hide()

	if header_lbl:
		header_lbl.text = header_prefix_text
		header_lbl.add_theme_font_size_override("font_size", header_font_size)
		header_lbl.add_theme_color_override("font_color", header_font_color)
		if font: header_lbl.add_theme_font_override("font", font)

	if event_lbl:
		event_lbl.add_theme_font_size_override("font_size", event_title_font_size)
		event_lbl.add_theme_color_override("font_color", event_title_font_color)
		if font: event_lbl.add_theme_font_override("font", font)
