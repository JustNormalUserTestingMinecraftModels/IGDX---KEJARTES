@tool
class_name ConfettiFireworks
extends Control

## Three confetti fireworks placed on the result screen, fired one per star as
## the stars land.
##
## Replaces the star-shaped spray ResultStar.celebrate() used to instance into
## each star's own BurstSlot: three bursts at three authored points read as a
## celebration over the whole card, where three sprays behind three stars read
## as the stars themselves fizzing.
##
## Placement is authored, not computed. Each burst is a real GPUParticles2D
## child of Bursts/ in this scene's .tscn, and the designer drags it in the
## editor viewport. While Engine.is_editor_hint() is true this script draws a
## labelled ring at each burst so the three positions are visible without
## pressing play; the rings never draw at runtime.
##
## A separate white full-house rain (ResultConfetti.tscn) used to fall beside
## these at three stars; it was retired on 2026-09-25.
##
## Affects: nothing outside itself. fire_burst() is fire-and-forget -- the
## emitters are one_shot and stop themselves.
##
## @tool so the placement rings preview in the editor.

## Node holding the three burst emitters, in firing order.
const BURSTS_PATH := ^"Bursts"
## How many fireworks a volley has. Three, one per star.
const BURST_COUNT: int = 3

## Seconds between one burst and the next when the caller runs them as a
## timed sequence. The popup instead fires one per star as it lands, so this
## is the fallback spacing for any caller without its own rhythm.
@export var burst_delay: float = 0.14
## Radius (px) of the editor-only placement ring drawn at each burst.
@export var marker_radius: float = 34.0
## Colour of the editor-only placement rings. Never drawn at runtime.
@export var marker_color: Color = Color(1.0, 0.45, 0.1, 0.9)


func _ready() -> void:
	# Belt and braces: the .tscn already authors emitting = false, but a scene
	# that emits on load would fire the whole volley the moment the result
	# card is instanced, before a single star has landed.
	for i in BURST_COUNT:
		var burst := get_burst(i)
		if burst != null:
			burst.emitting = false
	queue_redraw()


## How many fireworks this volley has.
func burst_count() -> int:
	return BURST_COUNT


## The emitter for burst `index`, or null when the scene is missing one.
func get_burst(index: int) -> GPUParticles2D:
	var bursts := get_node_or_null(BURSTS_PATH)
	if bursts == null or index < 0 or index >= bursts.get_child_count():
		return null
	return bursts.get_child(index) as GPUParticles2D


## Where burst `index` sits, in this Control's own coordinates.
func burst_position(index: int) -> Vector2:
	var burst := get_burst(index)
	return burst.position if burst != null else Vector2.ZERO


## Sets burst `index` off. Fire-and-forget. An out-of-range index is ignored
## rather than erroring: a minigame may award one or two stars, and the popup
## fires one burst per star, so a short volley is normal.
func fire_burst(index: int) -> void:
	if Engine.is_editor_hint():
		return
	var burst := get_burst(index)
	if burst == null:
		return
	burst.restart()
	burst.emitting = true


## The editor-only placement rings. See the file header: this is how the
## designer sees where the three fireworks are without pressing play.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for i in BURST_COUNT:
		var burst := get_burst(i)
		if burst == null:
			continue
		var at: Vector2 = burst.position
		draw_arc(at, marker_radius, 0.0, TAU, 32, marker_color, 3.0, true)
		draw_line(at - Vector2(marker_radius, 0.0),
			at + Vector2(marker_radius, 0.0), marker_color, 2.0)
		draw_line(at - Vector2(0.0, marker_radius),
			at + Vector2(0.0, marker_radius), marker_color, 2.0)
