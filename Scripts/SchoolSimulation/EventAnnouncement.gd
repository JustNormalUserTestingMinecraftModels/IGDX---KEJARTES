extends Control

## The "school announcement" card that fronts a non-minigame event.
## Sibling of EventWarning: same hazard-striped frame, calmer palette.
## Every color now comes from DesignTokens -- the backdrop is a &"Scrim"
## Panel, the three labels are theme variations, and the stripe shader is
## fed brand colors from script instead of baked constants.

# ── Visual - Background Overlay ───────────────────────────────────────────────
@export_group("Visual - Background Overlay")
## Optional photo behind the announcement. When set it replaces the Scrim.
@export var background_texture: Texture2D = null

# ── Visual - Header & Texts ───────────────────────────────────────────────────
@export_group("Visual - Header & Texts")
## Art-supplied icon shown above the header. Null falls back to
## announcement_symbol_text as an emoji glyph instead.
@export var announcement_icon_texture: Texture2D = null
## Emoji shown when announcement_icon_texture is null.
@export var announcement_symbol_text: String = "📢"
## Header line above the event's own title (set per-call via
## play_announcement()'s event_title argument).
@export var header_prefix_text: String = "📢 PENGUMUMAN EVENT SEKOLAH"
## Optional font override for the icon glyph and header/event labels.
## Null keeps the theme's default font.
@export var font: Font = null
## Size (px, both axes) of announcement_icon_texture/announcement_symbol_text.
@export var icon_font_size: int = 72

@onready var icon_lbl: Label = $ContentMargin/Center/VBox/IconLabel
@onready var header_lbl: Label = $ContentMargin/Center/VBox/HeaderLabel
@onready var event_lbl: Label = $ContentMargin/Center/VBox/EventLabel

func _ready() -> void:
	modulate.a = 0.0

func play_announcement(event_title: String, _event_description: String = "") -> void:
	_apply_visual_exports()
	if event_lbl:
		event_lbl.text = event_title

	var t := Juice.tokens()

	# Fade in announcement
	modulate.a = 0.0
	show()
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await fade_in.finished

	# Pulse loudspeaker icon 3 times
	var anim_node: CanvasItem = icon_lbl
	var tex_rect = icon_lbl.get_node_or_null("IconTextureRect") as TextureRect
	if tex_rect and tex_rect.visible:
		anim_node = tex_rect
	if anim_node:
		for i in range(3):
			var pulse = create_tween()
			pulse.tween_property(anim_node, "scale", Vector2(1.2, 1.2), t.dur_fast).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pulse.tween_property(anim_node, "scale", Vector2(1.0, 1.0), t.dur_fast).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await pulse.finished

	await get_tree().create_timer(t.dur_normal).timeout

	# Fade out
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, t.dur_slow)
	await fade_out.finished
	queue_free()

func _apply_visual_exports() -> void:
	_apply_stripe_tokens()

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
			if font: icon_lbl.add_theme_font_override("font", font)
			var tex_rect = icon_lbl.get_node_or_null("IconTextureRect")
			if tex_rect:
				tex_rect.hide()

	if header_lbl:
		header_lbl.text = header_prefix_text
		if font: header_lbl.add_theme_font_override("font", font)

	if event_lbl and font:
		event_lbl.add_theme_font_override("font", font)


## Same shader as EventWarning, different mood: an announcement is
## informational, so the stripes run in brand blue rather than the hazard
## amber EventWarning uses. Both bars share one ShaderMaterial
## sub-resource, so writing the uniform once repaints both.
func _apply_stripe_tokens() -> void:
	var t := Juice.tokens()
	for bar_name in ["TopBar", "BottomBar"]:
		var bar := get_node_or_null(bar_name) as CanvasItem
		if bar == null:
			continue
		var mat := bar.material as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("color1", t.brand_primary_light)
		mat.set_shader_parameter("color2", t.brand_primary_dark)
