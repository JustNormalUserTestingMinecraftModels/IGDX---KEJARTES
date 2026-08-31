extends Control

## The hazard-striped "something is about to happen" card that fronts a
## minigame. All color now comes from DesignTokens: the dim layer is a
## &"Scrim" Panel, the two labels are theme variations, and the animated
## hazard stripes take their colors from a shader uniform set here rather
## than from constants baked into the scene's ShaderMaterial.

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the warning. When set it replaces the Scrim panel.
@export var background_texture: Texture2D = null

# ── Visual - Caution Icon & Text ─────────────────────────────────────────────
@export_group("Visual - Caution Icon & Text")
## Art-supplied caution icon. Null falls back to caution_symbol_text as
## an emoji glyph instead.
@export var caution_icon_texture: Texture2D = null
## Emoji shown when caution_icon_texture is null.
@export var caution_symbol_text: String = "⚠️"
## Optional font override for the caution glyph and event label. Null
## keeps the theme's default font.
@export var font: Font = null
## Size (px, both axes) of caution_icon_texture/caution_symbol_text.
@export var icon_font_size: int = 72

@onready var caution_lbl: Label = $Center/VBox/CautionLabel
@onready var event_lbl: Label = $Center/VBox/EventLabel

func _ready() -> void:
	modulate.a = 0.0

func play_warning(event_text: String, accent_color: Color) -> void:
	_apply_visual_exports()
	if event_lbl:
		event_lbl.text = event_text
		# The caller's accent says which subject is coming up. Applied as a
		# tint rather than a font_color override so the theme still owns the
		# label's size, font and outline.
		event_lbl.self_modulate = accent_color

	var t := Juice.tokens()

	# Fade in warning
	modulate.a = 0.0
	show()
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fade_in.finished

	# Flash caution icon 4 times
	var anim_node: CanvasItem = caution_lbl
	var tex_rect = caution_lbl.get_node_or_null("CautionTextureRect") as TextureRect
	if tex_rect and tex_rect.visible:
		anim_node = tex_rect
	if anim_node:
		for i in range(4):
			var flash = create_tween()
			flash.tween_property(anim_node, "modulate:a", 0.1, t.dur_normal).set_ease(Tween.EASE_IN_OUT)
			flash.tween_property(anim_node, "modulate:a", 1.0, t.dur_normal).set_ease(Tween.EASE_IN_OUT)
			await flash.finished

	await get_tree().create_timer(t.dur_normal).timeout

	# Fade out
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, t.dur_slow)
	await fade_out.finished
	queue_free()

func _apply_visual_exports() -> void:
	_apply_hazard_stripe_tokens()

	# The Scrim panel is the default backdrop; an art-supplied photo
	# replaces it outright. Guarded on `is Panel` so a second call (the
	# swap already happened) does not stack another TextureRect.
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

	if caution_lbl:
		if caution_icon_texture:
			caution_lbl.text = ""
			var icon_size = Vector2(icon_font_size, icon_font_size)
			caution_lbl.custom_minimum_size = icon_size
			var tex_rect = caution_lbl.get_node_or_null("CautionTextureRect") as TextureRect
			if not tex_rect:
				tex_rect = TextureRect.new()
				tex_rect.name = "CautionTextureRect"
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.custom_minimum_size = icon_size
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				caution_lbl.add_child(tex_rect)
			tex_rect.texture = caution_icon_texture
			tex_rect.custom_minimum_size = icon_size
			tex_rect.show()
		else:
			caution_lbl.text = caution_symbol_text
			caution_lbl.custom_minimum_size = Vector2.ZERO
			if font: caution_lbl.add_theme_font_override("font", font)
			var tex_rect = caution_lbl.get_node_or_null("CautionTextureRect")
			if tex_rect:
				tex_rect.hide()

	if event_lbl and font:
		event_lbl.add_theme_font_override("font", font)


## HazardStripeShader.gdshader stays exactly as it is; only its inputs
## move into the token system. Both bars share one ShaderMaterial
## sub-resource, so writing the uniform once repaints both.
func _apply_hazard_stripe_tokens() -> void:
	var t := Juice.tokens()
	for bar_name in ["TopBar", "BottomBar"]:
		var bar := get_node_or_null(bar_name) as CanvasItem
		if bar == null:
			continue
		var mat := bar.material as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("color1", t.state_warning)
		mat.set_shader_parameter("color2", t.text_primary)
