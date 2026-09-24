@tool
class_name CloudDrift
extends Control

## Drifting clouds over the SchoolDay sky (2026-09-24 liveliness pass,
## layers 4 and 8). The clouds painted into transition_background.png rotate
## with the sky and cannot drift, so these are separate sprites layered above
## it: each child slides sideways at its own speed and wraps round the edges.
## The children are authored TextureRects; this only moves them.
##
## Drift runs in the game only. In the editor nothing moves -- a scene save
## would otherwise bake wherever the clouds happened to be. It also stops
## under GameSettings.reduce_motion.

## Speed of the slowest (first) cloud, px per second, left to right.
@export_range(0.0, 200.0, 1.0) var base_speed: float = 18.0
## How much faster each later cloud drifts than the one before, as a
## fraction of base_speed -- the parallax that makes them read as layers.
@export_range(0.0, 2.0, 0.05) var speed_step: float = 0.45
## Opacity of the nearest (first) cloud; each later one is fainter by
## opacity_step, so the far clouds sit back into the sky.
@export_range(0.0, 1.0, 0.01) var base_opacity: float = 0.85:
	set(value):
		base_opacity = value
		_apply_opacity()
## How much fainter each later cloud is.
@export_range(0.0, 0.5, 0.01) var opacity_step: float = 0.15:
	set(value):
		opacity_step = value
		_apply_opacity()


func _ready() -> void:
	_apply_opacity()


func _apply_opacity() -> void:
	var i := 0
	for cloud in get_children():
		if cloud is CanvasItem:
			(cloud as CanvasItem).modulate.a = clampf(base_opacity - opacity_step * i, 0.0, 1.0)
			i += 1


## Speed of the cloud at `index`, px per second.
func speed_for(index: int) -> float:
	return base_speed * (1.0 + speed_step * index)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or GameSettings.reduce_motion:
		return
	step(delta)


## Moves every cloud on by `delta` seconds and wraps any that left the right
## edge back in from the left. Public so the suite can drive it.
func step(delta: float) -> void:
	var i := 0
	for cloud in get_children():
		if cloud is Control:
			var c := cloud as Control
			c.position.x += speed_for(i) * delta
			if c.position.x > size.x:
				c.position.x = -c.size.x
			i += 1
