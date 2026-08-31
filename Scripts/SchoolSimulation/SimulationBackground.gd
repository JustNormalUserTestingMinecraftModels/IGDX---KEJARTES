extends ColorRect

## SchoolDay's page backdrop: a flat fill plus a subtly drawn pattern that
## changes shape per weekday.
##
## The fill starts at tokens.surface_page and SchoolDay tints it per day;
## the pattern is drawn in text_primary at a very low alpha so it reads as
## texture on a light surface rather than as content.

enum PatternType {
	GRID,
	STRIPES,
	DOTS,
	ZIGZAG,
	STARS
}

## Left transparent so _ready() can seed it from the design tokens --
## an @export default cannot call load(). Anything the scene or SchoolDay
## sets before/after wins, because the setter runs either way.
@export var bg_color: Color = Color.TRANSPARENT:
	set(val):
		bg_color = val
		color = val
		queue_redraw()

## Which weekday motif _draw() renders. SchoolDay sets this per weekday
## (GRID Monday, STRIPES Tuesday, DOTS Wednesday, ZIGZAG Thursday,
## STARS Friday).
@export var pattern_type: PatternType = PatternType.GRID:
	set(val):
		pattern_type = val
		queue_redraw()

## Alpha of the pattern wash over bg_color -- low by design so it reads
## as texture, not content.
@export var pattern_opacity: float = 0.07:
	set(val):
		pattern_opacity = val
		queue_redraw()


func _ready() -> void:
	if bg_color.a == 0.0:
		bg_color = DesignTokens.load_default().surface_page


func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0 or h <= 0:
		return

	# Ink, not paper: the surfaces are light now, so the pattern has to be
	# a dark wash rather than the white one it used to be.
	var pat_color: Color = DesignTokens.load_default().text_primary
	pat_color.a = pattern_opacity

	match pattern_type:
		PatternType.GRID:
			# Monday grid pattern
			var spacing = 50.0
			var cols = int(w / spacing) + 1
			var rows = int(h / spacing) + 1

			for i in range(cols):
				var x = i * spacing
				draw_line(Vector2(x, 0), Vector2(x, h), pat_color, 1.0)
			for j in range(rows):
				var y = j * spacing
				draw_line(Vector2(0, y), Vector2(w, y), pat_color, 1.0)

		PatternType.STRIPES:
			# Tuesday diagonal stripes pattern
			var spacing = 60.0
			var line_width = 2.0
			var steps = int((w + h) / spacing) + 1
			for i in range(steps):
				var offset = i * spacing
				draw_line(Vector2(offset, 0), Vector2(offset - h, h), pat_color, line_width)

		PatternType.DOTS:
			# Wednesday polka dots pattern
			var spacing = 50.0
			var radius = 3.0
			var cols = int(w / spacing) + 1
			var rows = int(h / spacing) + 1

			for i in range(cols):
				for j in range(rows):
					var stagger = (spacing * 0.5) if (i % 2 == 1) else 0.0
					var cx = i * spacing
					var cy = j * spacing + stagger
					if cx <= w and cy <= h:
						draw_circle(Vector2(cx, cy), radius, pat_color)

		PatternType.ZIGZAG:
			# Thursday zigzag pattern
			var spacing_y = 80.0
			var seg_w = 30.0
			var amplitude = 12.0
			var rows = int(h / spacing_y) + 1

			for j in range(rows):
				var y_base = j * spacing_y
				var points = PackedVector2Array()
				var x = 0.0
				var count = 0
				while x <= w + seg_w:
					var y = y_base + (amplitude if (count % 2 == 0) else -amplitude)
					points.append(Vector2(x, y))
					x += seg_w
					count += 1

				for i in range(points.size() - 1):
					draw_line(points[i], points[i+1], pat_color, 2.0)

		PatternType.STARS:
			# Friday sparkles pattern
			var grid_size = 90.0
			var cols = int(w / grid_size) + 1
			var rows = int(h / grid_size) + 1

			for i in range(cols):
				for j in range(rows):
					var seed_val = (i * 73 + j * 97)
					var dx = (seed_val % 40) - 20.0
					var dy = ((seed_val * 13) % 40) - 20.0
					var cx = i * grid_size + grid_size * 0.5 + dx
					var cy = j * grid_size + grid_size * 0.5 + dy

					if cx >= 0 and cx <= w and cy >= 0 and cy <= h:
						var size_spark = 6.0 + (seed_val % 6)
						draw_line(Vector2(cx - size_spark, cy), Vector2(cx + size_spark, cy), pat_color, 1.5)
						draw_line(Vector2(cx, cy - size_spark), Vector2(cx, cy + size_spark), pat_color, 1.5)
						draw_circle(Vector2(cx, cy), 1.5, pat_color)
