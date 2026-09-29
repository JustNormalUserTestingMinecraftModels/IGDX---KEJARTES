@tool
class_name ScreenSaturation
extends ColorRect

## Pulls the colour out of everything drawn before it on this screen (ambient
## kit piece; shader Scripts/Shaders/screen_saturation.gdshader). Place it
## right after the art and before the lights, so the pass grades the picture
## and the light stays as bright as authored. Anything drawn after it -- the
## UI -- is untouched.
##
## The material is local to the scene, so each placed piece tunes its own copy.
## The root restores Full Rect in _ready (AmbientKit.fill_parent), so it covers
## a tall phone. It is a colour grade, not an effect: Efek Suasana and Kurangi
## Gerakan leave it on, and it follows its screen's fades through the inherited
## modulate.

## How much colour stays: 1 leaves the frame alone, 0.7 removes 30%, 0 is
## greyscale.
@export_range(0.0, 2.0, 0.01) var saturation: float = 0.7:
	set(value):
		saturation = value
		_refresh()


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	(material as ShaderMaterial).set_shader_parameter("saturation", saturation)
