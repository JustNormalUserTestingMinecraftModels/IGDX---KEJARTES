@tool
extends CanvasLayer

## Scene transitions. Autoloaded as `Transition`.
##
## change_scene(path) keeps its original one-argument form because 21
## call sites across the project use it. The style parameter is optional.

enum Style { WIPE, FADE, IRIS }

## Emitted after the new scene is loaded and the cover has retracted.
## Screens connect to this to start their entry animations.
signal scene_changed(path: String)

@export_group("Appearance")
## Color of the cover. Defaults to brand_primary from the design tokens.
@export var cover_color: Color = Color("2e5bff")
## Unused by change_scene() itself (every call site passes its own style
## explicitly) -- kept as the Inspector-visible default for future call
## sites that omit the argument.
@export var default_style: Style = Style.WIPE

@onready var _cover: ColorRect = $ColorRect

var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tokens := DesignTokens.load_default()
	if tokens != null:
		cover_color = tokens.brand_primary
	_cover.color = cover_color
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_cover()


func _reset_cover() -> void:
	_cover.modulate.a = 0.0
	_cover.scale = Vector2.ONE
	_cover.position = Vector2.ZERO


## duration_override lets one call site request a slower (or faster) wipe
## than the shared default, without changing behavior for the ~20 other
## call sites that don't pass it. -1.0 (the default) means "use the
## normal token-based duration."
func change_scene(path: String, style: Style = Style.WIPE, duration_override: float = -1.0) -> void:
	# Guard against double-taps firing two transitions at once, which
	# would change scene twice and strand the cover on screen.
	if _busy:
		return
	_busy = true

	AudioDirector.play_sfx(&"whoosh")
	await _cover_in(style, duration_override)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Transition: failed to load %s (error %d)" % [path, err])

	# One frame so the incoming scene's _ready has run and it can paint
	# before the cover retracts, otherwise the first frame flashes.
	await get_tree().process_frame

	await _cover_out(style, duration_override)
	_busy = false
	scene_changed.emit(path)


func _durations(duration_override: float = -1.0) -> Array:
	if duration_override > 0.0:
		return [duration_override, duration_override]
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return [0.32, 0.32]
	return [tokens.dur_normal, tokens.dur_normal]


func _cover_in(style: Style, duration_override: float = -1.0) -> void:
	var d: float = _durations(duration_override)[0]
	var viewport := get_viewport().get_visible_rect().size
	var tw := create_tween()
	match style:
		Style.FADE:
			_cover.position = Vector2.ZERO
			tw.tween_property(_cover, "modulate:a", 1.0, d) \
				.set_ease(Tween.EASE_IN_OUT)
		Style.IRIS:
			_cover.modulate.a = 1.0
			_cover.pivot_offset = viewport * 0.5
			_cover.scale = Vector2(1.6, 1.6)
			tw.tween_property(_cover, "scale", Vector2.ONE, d) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_:
			# WIPE: the cover sweeps in from the right edge.
			_cover.modulate.a = 1.0
			_cover.position = Vector2(viewport.x, 0)
			tw.tween_property(_cover, "position", Vector2.ZERO, d) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished


func _cover_out(style: Style, duration_override: float = -1.0) -> void:
	var d: float = _durations(duration_override)[1]
	var viewport := get_viewport().get_visible_rect().size
	var tw := create_tween()
	match style:
		Style.FADE:
			tw.tween_property(_cover, "modulate:a", 0.0, d) \
				.set_ease(Tween.EASE_IN_OUT)
		Style.IRIS:
			tw.tween_property(_cover, "scale", Vector2(1.6, 1.6), d) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.parallel().tween_property(_cover, "modulate:a", 0.0, d)
		_:
			# WIPE: continues sweeping off the left edge.
			tw.tween_property(_cover, "position", Vector2(-viewport.x, 0), d) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	_reset_cover()
