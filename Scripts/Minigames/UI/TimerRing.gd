@tool
class_name TimerRing
extends Control

## The minigame header's time-left ring (spec 2026-09-29 minigame mobile
## layout, 3.1): a dark track with a gold arc that drains clockwise from
## twelve o'clock, turning state_danger for the last seconds. Drawn, not
## built: responsive geometry from documented @exports, so nothing is added
## to the tree at runtime. Colours come from the design tokens.

## Arc resolution, in points round a full circle.
const POINTS := 64

## Share of the time still left, 0..1.
@export_range(0.0, 1.0, 0.001) var fraction: float = 1.0:
	set(value):
		fraction = clampf(value, 0.0, 1.0)
		queue_redraw()
## True inside the header's danger window; the arc turns state_danger.
@export var danger: bool = false:
	set(value):
		danger = value
		queue_redraw()
## Ring stroke width in px.
@export_range(2.0, 40.0, 1.0) var ring_width: float = 10.0:
	set(value):
		ring_width = value
		queue_redraw()


func _draw() -> void:
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return
	var centre := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - ring_width / 2.0
	draw_arc(centre, radius, 0.0, TAU, POINTS, tokens.brand_primary_dark, ring_width, true)
	if fraction <= 0.0:
		return
	var start := -PI / 2.0
	var colour: Color = tokens.state_danger if danger else tokens.currency_gold
	draw_arc(centre, radius, start, start + TAU * fraction, POINTS, colour, ring_width, true)
