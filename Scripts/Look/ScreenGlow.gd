@tool
class_name ScreenGlow
extends ColorRect

## Bloom for one screen, placed by hand right after its backdrop and light:
## the bright parts of what is drawn so far, blurred and added back
## (bloom.gdshader, the same shader the Efek Visual layer uses).
##
## WHY NOT AmbientGlow. AmbientGlow is the Lobby's WorldEnvironment glow, which
## reaches only CanvasLayers at -1 or below. The minigames draw
## their backdrops on layer 0 (SchoolDay hosts a minigame inside its own
## tree), and on the shops and end-game screens that glow measured as no
## bloom at all (DEBT.md, "Ambient kit gaps"). This one reads the screen, so it
## works on any layer, and because it draws before the UI, only the picture
## blooms: the buttons and cards above it are drawn after its read.
##
## Additive, so it only ever brightens. The material is local to the scene, so
## each placed ScreenGlow tunes its own copy; the root restores Full Rect in
## _ready (AmbientKit.fill_parent). It follows its screen's fades through the
## inherited modulate, and Efek Suasana off hides it, which also drops its
## screen read. It does not move, so Kurangi Gerakan leaves it.
##
## THE CREAM CATCH. Nothing is brighter than 1.0 (hdr_2d is off), and this
## palette's paper sits close to it: a low threshold fogs a pale screen. Dark
## and dimmed screens can take a lower one. Judge each on a full-size capture.

## Brightness a pixel must already have before it blooms, 0 to 1.
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.7:
	set(value):
		threshold = value
		_refresh()

## How much of the bloom is added back; 0 for none.
@export_range(0.0, 2.0, 0.01) var intensity: float = 0.6:
	set(value):
		intensity = value
		_refresh()

## Which screen mip the blur starts at; higher is wider and softer.
@export_range(0.0, 5.0, 0.1) var spread: float = 2.0:
	set(value):
		spread = value
		_refresh()

## Colour the bloom is pushed toward. Warm by default, like the kit's light.
@export var bloom_tint: Color = Color(1.0, 0.96, 0.88):
	set(value):
		bloom_tint = value
		_refresh()


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AmbientKit.follow_settings(_refresh)


func _refresh() -> void:
	if not is_node_ready():
		return
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("threshold", threshold)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("spread", spread)
	mat.set_shader_parameter("bloom_tint", bloom_tint)
	visible = AmbientKit.is_enabled()
