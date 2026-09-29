@tool
class_name ProgressTicks
extends Control

## Segment dividers over the minigame header's progress bar (spec 2026-09-29
## minigame mobile layout, 3.1): with `segments` > 1 it draws segments - 1
## vertical lines, so BuatBatik's four tool steps read as four cells. Drawn,
## not built; 0 or 1 draws nothing.

## How many cells to divide the bar into; 0 or 1 = a plain bar.
@export_range(0, 20, 1) var segments: int = 0:
	set(value):
		segments = maxi(0, value)
		queue_redraw()
## Divider stroke width in px.
@export_range(1.0, 12.0, 1.0) var tick_width: float = 4.0:
	set(value):
		tick_width = value
		queue_redraw()


func _draw() -> void:
	if segments <= 1:
		return
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return
	for i in range(1, segments):
		var x := size.x * float(i) / float(segments)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), tokens.brand_primary_dark, tick_width)
