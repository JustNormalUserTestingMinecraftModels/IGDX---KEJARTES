@tool
class_name MoodTint
extends ColorRect

## A colour mood washed over a screen's backdrop (ambient kit, spec
## docs/superpowers/specs/2026-09-26-ambient-kit-design.md, section 1).
## A multiply blend (mood_tint.gdshader), so it only darkens and tints what
## is drawn BEFORE it in the same canvas layer. Place it directly after the
## backdrop: everything drawn later -- the UI above all -- keeps its true
## colour, which a CanvasModulate (it tints its whole layer) could not promise.
## Efek Suasana off hides it; it does not move, so Kurangi Gerakan leaves it.

## The moods. NETRAL multiplies by white and changes nothing; it is the
## default so every placed tint writes its mood into the scene file.
enum Mood { NETRAL, PAGI, SORE, MALAM, TEGANG }

## Each mood's full-strength colour; `strength` fades it toward white.
## PAGI warm morning, SORE orange dusk, MALAM blue night, TEGANG the cooler,
## darker mood of the exam.
const MOOD_COLORS := {
	Mood.NETRAL: Color(1.0, 1.0, 1.0),
	Mood.PAGI: Color(1.0, 0.9, 0.74),
	Mood.SORE: Color(1.0, 0.72, 0.52),
	Mood.MALAM: Color(0.55, 0.62, 0.9),
	Mood.TEGANG: Color(0.72, 0.76, 0.86),
}

## Which mood this screen wears.
@export var mood: Mood = Mood.NETRAL:
	set(value):
		mood = value
		_refresh()

## How far toward the mood colour: 0 is no tint, 1 the full colour.
@export_range(0.0, 1.0, 0.01) var strength: float = 0.35:
	set(value):
		strength = value
		_refresh()

## How much heavier the tint sits at the top: 0 even, 1 fading to nothing at
## the bottom edge.
@export_range(0.0, 1.0, 0.01) var vertical_falloff: float = 0.0:
	set(value):
		vertical_falloff = value
		_refresh()


func _ready() -> void:
	AmbientKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AmbientKit.follow_settings(_refresh)


## The colour this node multiplies by: the mood faded toward white.
func tint_color() -> Color:
	return Color.WHITE.lerp(MOOD_COLORS[mood] as Color, strength)


func _refresh() -> void:
	color = tint_color()
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("vertical_falloff", vertical_falloff)
	visible = AmbientKit.is_enabled()
