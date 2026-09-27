@tool
class_name LightPool
extends Control

## A soft pool of light placed by hand over a screen (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 1).
##
## The root is a bare Full Rect anchor -- an instance root under a plain
## Control loses its rect on an editor save (authoring guide, Pattern C), so
## AmbientKit.fill_parent restores it -- and the Pool child draws. `center`
## places the pool as a share of the root's rect, so it keeps its spot on a
## tall phone; `pool_size` is its size in pixels. Place it as the child of an
## illustration instead (MainMenu's Logo/Spill) and it rides that art.
##
## Additive, through light_falloff.gdshader, so it only ever brightens. With
## `rays_enabled`, Pool/Rays draws slow shafts through light_shafts.gdshader.
## Both materials are local to the scene, so every placed pool tunes its own.
## Kurangi Gerakan stops the breathing and the drift; Efek Suasana off hides it.

## The brightest a pool may be. The Lobby's window light started clipping cream
## paper to white at 0.12 (light_falloff.gdshader, "THE CREAM PROBLEM";
## changelog 2026-09-22).
const MAX_INTENSITY := 0.12
## The brightest the rays may be: the Lobby's shafts ship at 0.20, the top of
## the range swept without clipping (light_shafts.gdshader's header).
const MAX_RAYS_INTENSITY := 0.2
## The farthest the shafts may reach, in the Pool's UV from rays_origin: the
## Pool's own half-width. Past it a shaft would still be bright at the rect's
## edge and stop there in a straight line instead of fading inside it.
const MAX_RAYS_REACH := 0.5

## Where the pool's centre sits, as a share of this node's rect: (0, 0) the
## top-left corner, (1, 1) the bottom-right.
@export var center: Vector2 = Vector2(0.5, 0.5):
	set(value):
		center = value
		_place()

## The pool's width and height, in pixels.
@export var pool_size: Vector2 = Vector2(1000, 1000):
	set(value):
		pool_size = value
		_place()

## Colour of the light. Warm by default, to sit in the paper palette.
@export var light_color: Color = Color(1.0, 0.898, 0.706):
	set(value):
		light_color = value
		_refresh()

## Peak brightness at the centre; clamped to MAX_INTENSITY.
@export_range(0.0, 0.12, 0.005) var intensity: float = 0.08:
	set(value):
		intensity = minf(value, MAX_INTENSITY)
		_refresh()

## Where the light has faded to nothing, in the Pool's UV: 0.5 reaches its edge.
@export_range(0.05, 1.5, 0.01) var radius: float = 0.5:
	set(value):
		radius = value
		_refresh()

## Horizontal stretch of the pool; above 1 is wider than tall.
@export_range(0.1, 6.0, 0.05) var aspect: float = 1.0:
	set(value):
		aspect = value
		_refresh()

## How much the brightness breathes; 0 for none.
@export_range(0.0, 0.5, 0.01) var breath_depth: float = 0.06:
	set(value):
		breath_depth = value
		_refresh()

## Breaths per second.
@export_range(0.0, 2.0, 0.01) var breath_speed: float = 0.35:
	set(value):
		breath_speed = value
		_refresh()

## Draw slow light shafts converging on rays_origin.
@export var rays_enabled: bool = false:
	set(value):
		rays_enabled = value
		_refresh()

## Where the shafts converge, in the Pool's UV.
@export var rays_origin: Vector2 = Vector2(0.5, 0.5):
	set(value):
		rays_origin = value
		_refresh()

## Peak brightness of the shafts; clamped to MAX_RAYS_INTENSITY.
@export_range(0.0, 0.2, 0.005) var rays_intensity: float = 0.1:
	set(value):
		rays_intensity = minf(value, MAX_RAYS_INTENSITY)
		_refresh()

## How fast the shafts turn. Dust moves; sunlight does not strobe.
@export_range(0.0, 0.2, 0.005) var rays_drift_speed: float = 0.035:
	set(value):
		rays_drift_speed = value
		_refresh()

## How far the shafts reach before fading out, in the Pool's UV from
## rays_origin; at most MAX_RAYS_REACH so they fade inside the Pool's rect.
@export_range(0.1, 0.5, 0.01) var rays_reach: float = 0.5:
	set(value):
		rays_reach = minf(value, MAX_RAYS_REACH)
		_refresh()

@onready var _pool: ColorRect = $Pool
@onready var _rays: ColorRect = $Pool/Rays


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place()
	AmbientKit.follow_settings(_refresh)


func _place() -> void:
	if not is_node_ready():
		return
	var half := pool_size * 0.5
	_pool.anchor_left = center.x
	_pool.anchor_right = center.x
	_pool.anchor_top = center.y
	_pool.anchor_bottom = center.y
	_pool.offset_left = -half.x
	_pool.offset_right = half.x
	_pool.offset_top = -half.y
	_pool.offset_bottom = half.y


func _refresh() -> void:
	if not is_node_ready():
		return
	var still := AmbientKit.is_still()
	_push_pool(still)
	_push_rays(still)
	visible = AmbientKit.is_enabled()


func _push_pool(still: bool) -> void:
	var mat := _pool.material as ShaderMaterial
	mat.set_shader_parameter("light_color", light_color)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("aspect", aspect)
	mat.set_shader_parameter("breathe_amount", 0.0 if still else breath_depth)
	mat.set_shader_parameter("breathe_speed", breath_speed)


func _push_rays(still: bool) -> void:
	_rays.visible = rays_enabled
	var mat := _rays.material as ShaderMaterial
	mat.set_shader_parameter("shaft_color", light_color)
	mat.set_shader_parameter("intensity", rays_intensity)
	mat.set_shader_parameter("origin", rays_origin)
	mat.set_shader_parameter("drift_speed", 0.0 if still else rays_drift_speed)
	mat.set_shader_parameter("reach", rays_reach)
