@tool
class_name AmbientParticles
extends Control

## Ambient particles over an area of a screen (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 1 and
## amendment 4). The node's own rect is the area: the Emitter child sits at
## its centre and fills it, and re-fits on every resize, so a Full Rect
## instance covers a 20:9 phone as well as a 9:16 one.
##
## Additive, like SchoolDay's Motes, so the specks read as light; the
## Emitter's colour ramp fades each one in and out. Efek Suasana off, or
## Kurangi Gerakan on, stops the emitter and hides it.
##
## Leaves and petals (a DAUN preset) wait for the artist's sprite sheets:
## spec section 3 has the format.

## DEBU: slow dust drifting in the light. KILAU: small sparkles twinkling.
enum Preset { DEBU, KILAU }

## The most particles any emitter may carry. CPU particles at this count cost
## next to nothing on a phone; the preset counts sit well under it.
const MAX_AMOUNT := 40

## Each preset at density 1.0. Speeds in pixels per second, scales as a share
## of the 128 px texture, spin in degrees per second, spread in degrees.
const PRESETS := {
	Preset.DEBU: {
		"texture": preload("res://Assets/Images/Particles/particle_glow.png"),
		"amount": 24, "lifetime": 9.0, "spread": 30.0, "spin": 0.0,
		"speed_min": 10.0, "speed_max": 26.0, "scale_min": 0.06, "scale_max": 0.16,
	},
	Preset.KILAU: {
		"texture": preload("res://Assets/Images/Particles/particle_spark.png"),
		"amount": 16, "lifetime": 5.0, "spread": 45.0, "spin": 40.0,
		"speed_min": 8.0, "speed_max": 20.0, "scale_min": 0.08, "scale_max": 0.2,
	},
}

## Which particles.
@export var preset: Preset = Preset.DEBU:
	set(value):
		preset = value
		_refresh()

## Share of the preset's full count, 0 to 1 (at least one particle).
@export_range(0.0, 1.0, 0.05) var density: float = 1.0:
	set(value):
		density = value
		_refresh()

## Direction the particles drift; (0, -1) rises. Normalised before use.
@export var drift: Vector2 = Vector2(0.15, -1.0):
	set(value):
		drift = value
		_refresh()

## Colour the particles are multiplied by. They add, so a dim tint is a faint light.
@export var tint: Color = Color(1.0, 0.96, 0.86, 0.6):
	set(value):
		tint = value
		_refresh()

@onready var _emitter: CPUParticles2D = $Emitter


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)
	_fit()
	AmbientKit.follow_settings(_refresh)


## The emitter's count for `which` at `share` of full density, 1..MAX_AMOUNT.
static func amount_for(which: Preset, share: float) -> int:
	var full: int = PRESETS[which]["amount"]
	return clampi(roundi(full * share), 1, MAX_AMOUNT)


func _fit() -> void:
	if not is_node_ready():
		return
	_emitter.position = size * 0.5
	_emitter.emission_rect_extents = size * 0.5


func _refresh() -> void:
	if not is_node_ready():
		return
	_apply_look(PRESETS[preset])
	var shown := AmbientKit.is_enabled() and not AmbientKit.is_still()
	_emitter.emitting = shown
	visible = shown


func _apply_look(look: Dictionary) -> void:
	_emitter.texture = look["texture"]
	_emitter.amount = amount_for(preset, density)
	_emitter.lifetime = look["lifetime"]
	_emitter.preprocess = look["lifetime"]
	_emitter.direction = drift.normalized()
	_emitter.spread = look["spread"]
	_emitter.initial_velocity_min = look["speed_min"]
	_emitter.initial_velocity_max = look["speed_max"]
	_emitter.scale_amount_min = look["scale_min"]
	_emitter.scale_amount_max = look["scale_max"]
	_emitter.angular_velocity_min = -float(look["spin"])
	_emitter.angular_velocity_max = look["spin"]
	_emitter.color = tint
