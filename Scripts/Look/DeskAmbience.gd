@tool
class_name DeskAmbience
extends Control

## The desk recipe (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 2):
## LevelSelect, StudentCard, StudentList and ReportCard share one wooden desk,
## so they share one ambience -- a warm PAGI tint, a lamp pool upper left (the
## game's light comes from there; only the Lobby is lit from the right), and
## dust drifting in it. Placed in each screen's `World` layer, directly after
## the backdrop.
##
## No bloom: over this wood no glow threshold separates the lamp from the desk
## (measured 2026-09-28; spec amendment 7), so AmbientGlow waits for an
## hdr_2d pass.
##
## Overrides set on an instanced scene's children are dropped on save
## (CLAUDE.md, "Three save hazards"), so the knob a screen may need to
## change lives here on the root and is written through to the children.

## Share of the dust's full count on this screen (Dust's density).
@export_range(0.0, 1.0, 0.05) var particle_density: float = 1.0:
	set(value):
		particle_density = value
		_refresh()

@onready var _dust: AmbientParticles = $Dust


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_dust.density = particle_density
