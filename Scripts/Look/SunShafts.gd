@tool
class_name SunShafts
extends ColorRect

## Slow sunlight shafts across a whole screen: the Lobby's WindowShafts as a
## kit piece (spec docs/superpowers/specs/2026-09-28-lobby-look-everywhere-design.md,
## section 1). LightPool's own rays stop at its pool's edge
## (LightPool.MAX_RAYS_REACH); these cross the room.
##
## Additive, through light_shafts.gdshader unchanged, so it only ever
## brightens. The material is local to the scene, so every placed SunShafts
## tunes its own copy. The root restores Full Rect in _ready
## (AmbientKit.fill_parent), so it covers a tall phone. Kurangi Gerakan stops
## the drift; Efek Suasana off hides it.

## The brightest the shafts may be: the Lobby's WindowShafts ship at 0.20, the
## top of the range swept over cream without clipping
## (light_shafts.gdshader's header).
const MAX_INTENSITY := 0.2

## Where the shafts converge, in this node's UV: (0, 0) is the top-left
## corner. Upper left by default, the game's light direction.
@export var origin: Vector2 = Vector2(0.12, -0.08):
	set(value):
		origin = value
		_refresh()

## Colour of the light. Warm by default, matching LightPool's.
@export var shaft_color: Color = Color(1.0, 0.898, 0.706):
	set(value):
		shaft_color = value
		_refresh()

## Peak brightness; clamped to MAX_INTENSITY.
@export_range(0.0, 0.2, 0.005) var intensity: float = 0.2:
	set(value):
		intensity = minf(value, MAX_INTENSITY)
		_refresh()

## How many shafts. Few and wide reads as sun; many and thin as a starburst.
@export_range(1.0, 16.0, 1.0) var shaft_count: float = 7.0:
	set(value):
		shaft_count = value
		_refresh()

## Edge softness of each shaft; higher is softer.
@export_range(1.0, 12.0, 0.1) var softness: float = 5.0:
	set(value):
		softness = value
		_refresh()

## How far from `origin` the shafts fade out, in UV.
@export_range(0.1, 3.0, 0.01) var reach: float = 1.4:
	set(value):
		reach = value
		_refresh()

## How fast the shafts turn. Dust moves; sunlight does not strobe.
@export_range(0.0, 0.2, 0.005) var drift_speed: float = 0.035:
	set(value):
		drift_speed = value
		_refresh()


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AmbientKit.follow_settings(_refresh)


func _refresh() -> void:
	if not is_node_ready():
		return
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("shaft_color", shaft_color)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("origin", origin)
	mat.set_shader_parameter("shaft_count", shaft_count)
	mat.set_shader_parameter("softness", softness)
	mat.set_shader_parameter("reach", reach)
	mat.set_shader_parameter("drift_speed", 0.0 if AmbientKit.is_still() else drift_speed)
	visible = AmbientKit.is_enabled()
