@tool
class_name AmbientGlow
extends WorldEnvironment

## Bloom for one screen's `World` layer (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, "Light bleed").
## The Lobby's recipe (Scenes/Lobby/lobby_environment.tres): a Canvas
## background, screen-blend glow, and background_canvas_max_layer = -1, so
## only CanvasLayers at -1 or below bloom and the UI on layer 0 never does.
## The Environment is local to the scene, so each screen's instance tunes its
## own copy. Tune it in the Inspector and watch the 2D view, which previews
## Canvas-mode glow live (changelog 2026-09-23).
##
## THE CREAM CATCH. hdr_2d is off (test_look_layer pins it), so nothing is
## brighter than 1.0, and this palette's paper, cloud and pale wood sit close
## to it. A threshold low enough to catch a light pool catches those too and
## fogs the screen: raise glow_threshold until the lightest surface stops
## blooming. Efek Suasana off turns the glow off; it does not move, so
## Kurangi Gerakan leaves it.

## Brightness above which a pixel blooms, 0 to 1. Keep it high; see the header.
@export_range(0.0, 1.0, 0.01) var glow_threshold: float = 0.9:
	set(value):
		glow_threshold = value
		_refresh()

## How strongly the bloom is added back (the Environment's glow_intensity).
@export_range(0.0, 4.0, 0.05) var glow_intensity: float = 1.0:
	set(value):
		glow_intensity = value
		_refresh()

## How far the bloom spreads (the Environment's glow_strength).
@export_range(0.0, 2.0, 0.05) var glow_strength: float = 1.0:
	set(value):
		glow_strength = value
		_refresh()


func _ready() -> void:
	AmbientKit.follow_settings(_refresh)


func _refresh() -> void:
	if environment == null:
		return
	environment.glow_hdr_threshold = glow_threshold
	environment.glow_intensity = glow_intensity
	environment.glow_strength = glow_strength
	environment.glow_enabled = AmbientKit.is_enabled()
