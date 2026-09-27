@tool
extends CanvasLayer

## The global look layer: a bloom, a vignette and a film grain drawn over every
## screen in the game, from a single autoload.
##
## WHY LAYER 90. Everything in this game except a handful of overlays lives on
## the default layer 0, so 90 covers all of it while staying under the things
## that must not be tinted: the transition wipe (1000), the debug overlay
## (1128), touch ripples (125) and the achievement toast (120). Going higher
## would dim the wipe and the developer tools; going lower would let popups
## punch through the grade. Layers 1-9 and 11-99 were entirely unused.
##
## WHY IT IS A SCENE AUTOLOAD, NOT A SCRIPT ONE. tests/test_viewport_editability
## counts `CanvasLayer.new(` and `ColorRect.new(` in res://Scripts and fails a
## file that builds visuals at runtime. Authored as a .tscn with the nodes in
## the scene, this scans as zero and belongs in neither the BASELINE nor the
## ALLOWED dict -- the same way Transition gets away with it. Building the
## same nodes from code would have needed an ALLOWED entry, and that entry
## would not have been honest: this is static authored chrome, not the
## per-call-dynamic content ALLOWED is for.
##
## WHY THE VIGNETTE IS PROCEDURAL. See the shader's own header: with
## aspect="expand" the viewport is 1080x2400 on a 20:9 phone, and a
## fixed-size vignette texture would crop its own falloff off the sides.
##
## DEFAULT OFF. The brief set the performance floor as unknown and asked for
## one switch, so this answers to GameSettings.look_layer_enabled and starts
## off. It listens to that setting's signal rather than polling it.
##
## Must be @tool: as an autoload it is instantiated by the editor process
## itself, and a non-@tool autoload is a placeholder whose every property
## access throws (the failure GameSettings.gd documents at length). Its only
## real side effect -- following the viewport -- is harmless in the editor,
## but it starts hidden there so it never tints the editor's own preview.

## The full-rect ColorRect carrying the vignette and grain shader.
@onready var _cover: ColorRect = $Cover

## The full-rect ColorRect carrying the bloom, drawn under the cover so the
## vignette darkens the bloom rather than the bloom washing out the vignette.
##
## It reads the screen texture once per frame, which is the only genuinely
## expensive thing in this layer -- and the reason it lives here rather than in
## its own always-on autoload. _refresh() takes the whole layer out of the draw
## list when the setting is off, so an unchecked box costs nothing at all.
@onready var _bloom: ColorRect = $Bloom

## How long the layer takes to fade in or out when the setting is flipped, in
## seconds. A hard cut on a full-screen tint reads as a glitch.
@export_range(0.0, 1.5, 0.05) var fade_seconds: float = 0.35

## The fade in flight, if any. Killed before a new one starts, or a fade-out's
## closing `visible = false` would land after a quick re-enable and hide the
## layer while the setting reads on.
var _tween: Tween = null

## Set false to keep the layer off regardless of the saved setting. Exists so
## a screen that must be colour-accurate can suppress it.
var suppressed: bool = false:
	set(value):
		suppressed = value
		_refresh()


func _ready() -> void:
	layer = 90
	# The cover must never eat a tap: it spans the whole screen, so a
	# hit-testable one would make the entire game unclickable.
	for rect in [_cover, _bloom]:
		if rect != null:
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.modulate.a = 0.0
	if Engine.is_editor_hint():
		visible = false
		return
	get_viewport().size_changed.connect(_push_viewport_size)
	GameSettings.look_layer_changed.connect(_on_setting_changed)
	_push_viewport_size()
	_refresh(true)


## Tells the shader how big the screen is, so the vignette stays circular
## rather than stretching into an ellipse. Recomputed on every size change
## rather than read once, because a phone can rotate and the editor's window
## can be dragged to any aspect.
func _push_viewport_size() -> void:
	if _cover == null:
		return
	var mat := _cover.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)


func _on_setting_changed(_enabled: bool) -> void:
	_refresh()


## Brings the layer to whatever the setting and `suppressed` currently say.
## `instant` skips the fade, for the first frame of a run where there is
## nothing to fade from.
func _refresh(instant: bool = false) -> void:
	if _cover == null or Engine.is_editor_hint():
		return
	var want: bool = GameSettings.look_layer_enabled and not suppressed
	var target: float = 1.0 if want else 0.0
	# Keep the node out of the draw list entirely when it is off, so an
	# unchecked setting costs nothing at all rather than costing a
	# full-screen transparent quad.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if want:
		visible = true
	if instant or fade_seconds <= 0.0:
		_cover.modulate.a = target
		if _bloom != null:
			_bloom.modulate.a = target
		visible = want
		return
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_cover, "modulate:a", target, fade_seconds)
	if _bloom != null:
		_tween.tween_property(_bloom, "modulate:a", target, fade_seconds)
	if not want:
		_tween.chain().tween_callback(func() -> void: visible = false)
