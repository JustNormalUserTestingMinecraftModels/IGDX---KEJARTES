extends Control
class_name BookClockWidget

# ── Exports — Art Team Asset Slots ───────────────────────────────────────────
@export_group("Visual - Book")
## Optional PNG for the open book icon. If set, replaces the procedural book drawing.
@export var book_texture: Texture2D = null
## Optional PNG for the closed book state (shown at 100%). Falls back to book_texture.
@export var book_closed_texture: Texture2D = null

@export_group("Visual - Clock")
## Optional PNG for the clock face background. If set, replaces procedural clock circle.
@export var clock_face_texture: Texture2D = null
## Optional PNG for the clock hand. If set, replaces the procedural line hand.
@export var clock_hand_texture: Texture2D = null
## Optional PNG for the sun/progress indicator dot on the arc.
@export var sun_texture: Texture2D = null
## Sky color at progress = 0.0 (morning)
@export var clock_morning_color: Color = Color(0.25, 0.45, 0.82)
## Sky color at progress = 0.5 (midday)
@export var clock_noon_color: Color = Color(0.95, 0.82, 0.28)
## Sky color at progress = 1.0 (late afternoon)
@export var clock_evening_color: Color = Color(0.88, 0.42, 0.1)

@export_group("Visual - Progress Bar Fill")
## Optional texture for the fill portion of the bar (overrides color gradient).
@export var progress_fill_texture: Texture2D = null
## Optional texture for the bar background track.
@export var progress_bg_texture: Texture2D = null
@export var progress_fill_color: Color = Color(0.95, 0.68, 0.08)
@export var progress_fill_color_end: Color = Color(1.0, 0.88, 0.3)
@export var progress_bg_color: Color = Color(0.08, 0.08, 0.14, 0.92)
@export var progress_bar_height: float = 48.0
@export var progress_bar_corner_radius: float = 10.0

@export_group("Visual - Font")
@export var widget_font: Font = null

# ── Internal State ────────────────────────────────────────────────────────────
var _progress: float = 0.0          # 0.0 to 1.0
var _day_name: String = ""
var _book_closed: bool = false       # true when progress reaches 1.0
var _page_flip_scales: Array = [1.0, 1.0]  # [width_scale, height_scale] for book squash
var _last_flip_milestone: int = 0   # tracks which 25/50/75% milestone was last triggered

# ── Clock layout constants ─────────────────────────────────────────────────────
const CLOCK_START_ANGLE_DEG: float = -60.0   # 7 AM position (slightly left of top)
const CLOCK_END_ANGLE_DEG: float = 90.0      # 3 PM position (bottom-right)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 110)
	generate_png_placeholders()

# ── Public API ────────────────────────────────────────────────────────────────
func set_progress(value: float) -> void:
	var old_progress = _progress
	_progress = clampf(value, 0.0, 1.0)
	
	# Trigger page flip tweens at 25%, 50%, 75%
	var milestone = int(_progress * 4.0)  # 0,1,2,3,4
	if milestone > _last_flip_milestone and milestone < 4 and old_progress < _progress:
		_last_flip_milestone = milestone
		_animate_page_flip()
	
	# Trigger book close at 100%
	if _progress >= 1.0 and not _book_closed:
		_book_closed = true
		_animate_book_close()
	elif _progress < 1.0:
		_book_closed = false
	
	queue_redraw()

func set_day(day_name: String) -> void:
	_day_name = day_name
	_last_flip_milestone = 0
	_book_closed = false
	_page_flip_scales = [1.0, 1.0]
	queue_redraw()

func reset() -> void:
	_progress = 0.0
	_day_name = ""
	_last_flip_milestone = 0
	_book_closed = false
	_page_flip_scales = [1.0, 1.0]
	queue_redraw()

# ── Page Flip Animation ───────────────────────────────────────────────────────
func _animate_page_flip() -> void:
	# Squash the book width to 0 and back — simulates a page turning
	var tw = create_tween()
	tw.tween_method(func(v: float): _page_flip_scales[0] = v; queue_redraw(), 1.0, 0.05, 0.08).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(v: float): _page_flip_scales[0] = v; queue_redraw(), 0.05, 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): _page_flip_scales[0] = v; queue_redraw(), 1.1, 1.0, 0.08).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

func _animate_book_close() -> void:
	# Squeeze book down (height) and release — simulates closing
	var tw = create_tween()
	tw.tween_method(func(v: float): _page_flip_scales[1] = v; queue_redraw(), 1.0, 0.1, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(v: float): _page_flip_scales[1] = v; queue_redraw(), 0.1, 1.2, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): _page_flip_scales[1] = v; queue_redraw(), 1.2, 1.0, 0.1).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

# ── Drawing ───────────────────────────────────────────────────────────────────
# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0 or h <= 0:
		return

	# Centered clock, 80% of the smallest dimension
	var clock_size = minf(w, h) * 0.8
	var clock_cx = w * 0.5
	var clock_cy = h * 0.5
	var clock_r = clock_size * 0.45

	_draw_clock(clock_cx, clock_cy, clock_r)

func _draw_clock(cx: float, cy: float, r: float) -> void:
	# Check if child nodes exist
	var dial = get_node_or_null("InsideDial")
	var plate = get_node_or_null("CoverPlate")
	var frame = get_node_or_null("OuterFrame")
	
	if not dial or not plate or not frame:
		# First clear all children to be clean
		for child in get_children():
			child.queue_free()
			
		dial = TextureRect.new()
		dial.name = "InsideDial"
		dial.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dial.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(dial)
		
		plate = Control.new()
		plate.name = "CoverPlate"
		plate.draw.connect(func():
			var pr = plate.size.x * 0.5
			var pcx = pr
			var pcy = pr
			var pts = PackedVector2Array()
			pts.append(Vector2(pcx, pcy))
			for i in range(181):
				var angle = deg_to_rad(i)
				pts.append(Vector2(pcx + cos(angle) * pr, pcy + sin(angle) * pr))
			var colors = PackedColorArray()
			for p in pts:
				colors.append(Color(0.83, 0.69, 0.22))
			plate.draw_polygon(pts, colors)
			plate.draw_line(Vector2(0, pcy), Vector2(pr * 2, pcy), Color(0.67, 0.52, 0.11), 2.0, true)
		)
		add_child(plate)
		
		frame = TextureRect.new()
		frame.name = "OuterFrame"
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(frame)
		
	# Resolve textures
	var face_tex = clock_face_texture
	if face_tex == null and ResourceLoader.exists("res://Assets/Images/UI/Placeholders/clock_outer.png"):
		face_tex = load("res://Assets/Images/UI/Placeholders/clock_outer.png")
		
	var hand_tex = clock_hand_texture
	if hand_tex == null and ResourceLoader.exists("res://Assets/Images/UI/Placeholders/clock_inside.png"):
		hand_tex = load("res://Assets/Images/UI/Placeholders/clock_inside.png")
		
	# Update layout and visibility
	if face_tex != null and hand_tex != null:
		dial.show()
		plate.show()
		frame.show()
		
		dial.texture = hand_tex
		frame.texture = face_tex
		
		var size_vec = Vector2(r * 2, r * 2)
		var pos_vec = Vector2(cx - r, cy - r)
		
		dial.size = size_vec
		dial.position = pos_vec
		dial.pivot_offset = Vector2(r, r)
		
		var hand_angle_deg = CLOCK_START_ANGLE_DEG + _progress * (CLOCK_END_ANGLE_DEG - CLOCK_START_ANGLE_DEG)
		dial.rotation = deg_to_rad(hand_angle_deg)
		
		plate.size = size_vec
		plate.position = pos_vec
		plate.queue_redraw()
		
		frame.size = size_vec
		frame.position = pos_vec
	else:
		dial.hide()
		plate.hide()
		frame.hide()
		
		_draw_clock_procedural(cx, cy, r)

func _draw_clock_procedural(cx: float, cy: float, r: float) -> void:
	var hand_angle_deg = CLOCK_START_ANGLE_DEG + _progress * (CLOCK_END_ANGLE_DEG - CLOCK_START_ANGLE_DEG)
	var hand_angle_rad = deg_to_rad(hand_angle_deg)
	# ── 1. Draw the inside rotating dial (Day/Night cycle) procedurally ──
	# Set transform centered at (cx, cy) and rotated by hand_angle_rad
	draw_set_transform(Vector2(cx, cy), hand_angle_rad, Vector2.ONE)
	
	# Dial background: Night side (full dark blue circle)
	var night_color = Color(0.1, 0.15, 0.23)
	draw_circle(Vector2.ZERO, r, night_color)
	
	# Day side (top half - light blue semi-circle)
	var day_color = Color(0.3, 0.65, 0.87)
	var day_points = PackedVector2Array()
	day_points.append(Vector2.ZERO)
	for i in range(181):
		var angle = deg_to_rad(i - 180.0)
		day_points.append(Vector2(cos(angle) * r, sin(angle) * r))
	
	var day_colors = PackedColorArray()
	for p in day_points:
		day_colors.append(day_color)
	draw_polygon(day_points, day_colors)
	
	# Divider line
	draw_line(Vector2(-r, 0), Vector2(r, 0), Color(0.98, 0.82, 0.4), 1.5, true)
	
	# Cute Sun on the day side (top)
	var sun_color = Color(0.98, 0.78, 0.31)
	var sun_ray_color = Color(0.95, 0.45, 0.17)
	var sun_pos = Vector2(0, -r * 0.5)
	draw_circle(sun_pos, r * 0.18, sun_color)
	# Sun rays
	var ray_len = r * 0.08
	var ray_dist = r * 0.24
	for i in range(8):
		var angle = deg_to_rad(i * 45.0)
		var p1 = sun_pos + Vector2(cos(angle) * ray_dist, sin(angle) * ray_dist)
		var p2 = sun_pos + Vector2(cos(angle) * (ray_dist + ray_len), sin(angle) * (ray_dist + ray_len))
		draw_line(p1, p2, sun_ray_color, 1.5, true)
		
	# Cute Moon on the night side (bottom)
	var moon_color = Color(0.98, 0.82, 0.4)
	var moon_pos = Vector2(0, r * 0.5)
	# Draw crescent using two circles
	draw_circle(moon_pos, r * 0.18, moon_color)
	draw_circle(moon_pos + Vector2(r * 0.08, -r * 0.05), r * 0.18, night_color)
	
	# Stars on the night side
	draw_circle(Vector2(-r * 0.4, r * 0.4), 1.2, Color(1, 1, 1))
	draw_circle(Vector2(r * 0.4, r * 0.6), 1.2, Color(1, 1, 1))
	draw_circle(Vector2(r * 0.25, r * 0.35), 0.8, Color(1, 1, 1, 0.7))
	
	# Reset transform
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# ── 1b. Draw the solid brass plate covering the lower half of the dial ──
	var plate_points = PackedVector2Array()
	plate_points.append(Vector2(cx, cy))
	for i in range(181):
		var angle = deg_to_rad(i) # 0 to 180 degrees (bottom half)
		plate_points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
	
	var plate_colors = PackedColorArray()
	for p in plate_points:
		plate_colors.append(Color(0.83, 0.69, 0.22)) # Golden frame color
	draw_polygon(plate_points, plate_colors)
	
	# Divider line on top of the plate
	draw_line(Vector2(cx - r, cy), Vector2(cx + r, cy), Color(0.67, 0.52, 0.11), 2.0, true)

	# ── 2. Draw the outer frame (Cute Cat Pocket Watch Frame) ──
	# Pocket watch loop at the top
	var loop_y = cy - r - 8
	draw_arc(Vector2(cx, loop_y), 7.0, 0, TAU, 16, Color(0.83, 0.69, 0.22), 3.0, true)
	
	# Cute cat ears (left and right)
	var ear_offset = r * 0.68
	var ear_y = cy - r * 0.68
	# Left ear
	draw_circle(Vector2(cx - ear_offset, ear_y), r * 0.25, Color(0.83, 0.69, 0.22))
	draw_circle(Vector2(cx - ear_offset, ear_y), r * 0.15, Color(1.0, 0.75, 0.75)) # pink inner ear
	# Right ear
	draw_circle(Vector2(cx + ear_offset, ear_y), r * 0.25, Color(0.83, 0.69, 0.22))
	draw_circle(Vector2(cx + ear_offset, ear_y), r * 0.15, Color(1.0, 0.75, 0.75)) # pink inner ear
	
	# Outer golden ring
	draw_arc(Vector2(cx, cy), r + 4, 0, TAU, 64, Color(0.83, 0.69, 0.22), 8.0, true)
	# Inner dark accent border
	draw_arc(Vector2(cx, cy), r, 0, TAU, 64, Color(0.67, 0.52, 0.11), 1.5, true)
	# Outer dark accent border
	draw_arc(Vector2(cx, cy), r + 8, 0, TAU, 64, Color(0.67, 0.52, 0.11), 1.5, true)
	
	# Glass highlight reflection (semi-transparent white overlay arc)
	draw_arc(Vector2(cx, cy), r - 2, deg_to_rad(-140.0), deg_to_rad(-40.0), 32, Color(1, 1, 1, 0.35), 3.0, true)

func _draw_book(cx: float, cy: float, book_size: Vector2) -> void:
	# Apply squash/stretch from animation
	var bw = book_size.x * _page_flip_scales[0]
	var bh = book_size.y * _page_flip_scales[1]
	var rect = Rect2(cx - bw / 2.0, cy - bh / 2.0, bw, bh)

	if _book_closed:
		var tex = book_closed_texture if book_closed_texture else book_texture
		if tex:
			draw_texture_rect(tex, rect, false)
		else:
			_draw_procedural_closed_book(rect)
	else:
		if book_texture:
			draw_texture_rect(book_texture, rect, false)
		else:
			_draw_procedural_open_book(rect)

func _draw_procedural_open_book(rect: Rect2) -> void:
	var book_color = Color(0.92, 0.88, 0.78)
	var spine_color = Color(0.25, 0.45, 0.68)
	var line_color = Color(0.55, 0.5, 0.42, 0.6)
	
	# Left page
	var left_page = Rect2(rect.position, Vector2(rect.size.x / 2.0 - 2.0, rect.size.y))
	draw_rect(left_page, book_color, true, -1.0, true)
	draw_rect(left_page, Color(0.4, 0.35, 0.28, 0.5), false, 1.5)
	
	# Right page
	var right_page = Rect2(Vector2(rect.position.x + rect.size.x / 2.0 + 2.0, rect.position.y), Vector2(rect.size.x / 2.0 - 2.0, rect.size.y))
	draw_rect(right_page, book_color, true, -1.0, true)
	draw_rect(right_page, Color(0.4, 0.35, 0.28, 0.5), false, 1.5)
	
	# Spine
	draw_rect(Rect2(rect.position.x + rect.size.x / 2.0 - 2.5, rect.position.y, 5.0, rect.size.y), spine_color)
	
	# Text lines on left page
	for i in range(3):
		var ly = rect.position.y + rect.size.y * (0.25 + i * 0.22)
		draw_line(Vector2(left_page.position.x + 4, ly), Vector2(left_page.end.x - 4, ly), line_color, 1.5)
	# Text lines on right page
	for i in range(3):
		var ly = rect.position.y + rect.size.y * (0.25 + i * 0.22)
		draw_line(Vector2(right_page.position.x + 4, ly), Vector2(right_page.end.x - 4, ly), line_color, 1.5)

func _draw_procedural_closed_book(rect: Rect2) -> void:
	draw_rect(rect, Color(0.25, 0.45, 0.68), true, -1.0, true)
	draw_rect(rect, Color(0.85, 0.75, 0.3, 0.8), false, 2.0)
	# Gold checkmark or star in center
	var cx = rect.position.x + rect.size.x / 2.0
	var cy = rect.position.y + rect.size.y / 2.0
	draw_circle(Vector2(cx, cy), 8.0, Color(1.0, 0.88, 0.2))

func _draw_progress_bar(bx: float, by: float, bw: float, bh: float) -> void:
	var corner = progress_bar_corner_radius
	var fill_w = bw * _progress

	# Background track
	if progress_bg_texture:
		draw_texture_rect(progress_bg_texture, Rect2(bx, by, bw, bh), false)
	else:
		# Procedural rounded rect background
		var bg_pts = _rounded_rect_points(bx, by, bw, bh, corner)
		draw_colored_polygon(bg_pts, progress_bg_color)

	# Fill
	if fill_w > corner * 2.0:
		if progress_fill_texture:
			draw_texture_rect(progress_fill_texture, Rect2(bx, by, fill_w, bh), false)
		else:
			# Procedural fill with slight gradient (top lighter)
			var fill_pts = _rounded_rect_points(bx, by, fill_w, bh, corner)
			draw_colored_polygon(fill_pts, progress_fill_color)
			# Highlight strip at top
			var hi_h = bh * 0.28
			var hi_pts = _rounded_rect_points(bx + 2, by + 2, fill_w - 4, hi_h, corner * 0.5)
			draw_colored_polygon(hi_pts, Color(1, 1, 1, 0.18))
	elif fill_w > 2.0:
		draw_rect(Rect2(bx, by, fill_w, bh), progress_fill_color)

func _rounded_rect_points(rx: float, ry: float, rw: float, rh: float, r: float, segments: int = 6) -> PackedVector2Array:
	var pts = PackedVector2Array()
	r = minf(r, rw / 2.0)
	r = minf(r, rh / 2.0)
	# Four corners: TL, TR, BR, BL
	var corners = [
		Vector2(rx + r, ry + r),
		Vector2(rx + rw - r, ry + r),
		Vector2(rx + rw - r, ry + rh - r),
		Vector2(rx + r, ry + rh - r)
	]
	var start_angles = [PI, PI * 1.5, 0.0, PI * 0.5]
	for c_idx in range(4):
		for seg in range(segments + 1):
			var angle = start_angles[c_idx] + (PI / 2.0) * (float(seg) / float(segments))
			pts.append(corners[c_idx] + Vector2(cos(angle), sin(angle)) * r)
	return pts

func generate_png_placeholders() -> void:
	var dir_path = "res://Assets/Images/UI/Placeholders"
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
		
	var outer_path = dir_path + "/clock_outer.png"
	var inside_path = dir_path + "/clock_inside.png"
	
	_generate_outer_png(outer_path)
	_generate_inside_png(inside_path)
	_generate_bar_pngs(dir_path)

func _generate_outer_png(path: String) -> void:
	var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	
	var gold = Color(0.83, 0.69, 0.22)
	var dark_gold = Color(0.67, 0.52, 0.11)
	var pink = Color(1.0, 0.75, 0.75)
	
	for y in range(256):
		for x in range(256):
			var dx = x - 128
			var dy = y - 138
			var dist = sqrt(dx*dx + dy*dy)
			
			# Left Ear
			var lex = x - 70
			var ley = y - 78
			var l_dist = sqrt(lex*lex + ley*ley)
			if l_dist < 25:
				if l_dist < 15:
					img.set_pixel(x, y, pink)
				else:
					img.set_pixel(x, y, gold)
					
			# Right Ear
			var rex = x - 186
			var rey = y - 78
			var r_dist = sqrt(rex*rex + rey*rey)
			if r_dist < 25:
				if r_dist < 15:
					img.set_pixel(x, y, pink)
				else:
					img.set_pixel(x, y, gold)
					
			# Main ring
			if dist >= 76 and dist <= 84:
				img.set_pixel(x, y, gold)
			elif (dist >= 74 and dist < 76) or (dist > 84 and dist <= 86):
				img.set_pixel(x, y, dark_gold)
				
			# Top loop
			var lox = x - 128
			var loy = y - 42
			var lo_dist = sqrt(lox*lox + loy*loy)
			if lo_dist >= 9 and lo_dist <= 12:
				img.set_pixel(x, y, gold)
				
	img.save_png(path)

func _generate_inside_png(path: String) -> void:
	var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	
	var day_color = Color(0.3, 0.65, 0.87)
	var night_color = Color(0.1, 0.15, 0.23)
	var sun_color = Color(0.98, 0.78, 0.31)
	var moon_color = Color(0.98, 0.82, 0.4)
	
	for y in range(256):
		for x in range(256):
			var dx = x - 128
			var dy = y - 128
			var dist = sqrt(dx*dx + dy*dy)
			
			if dist <= 74:
				if dy <= 0:
					img.set_pixel(x, y, day_color)
				else:
					img.set_pixel(x, y, night_color)
					
				# Sun
				var sdx = x - 128
				var sdy = y - 90
				var s_dist = sqrt(sdx*sdx + sdy*sdy)
				if s_dist <= 14:
					img.set_pixel(x, y, sun_color)
					
				# Moon
				var mdx = x - 128
				var mdy = y - 166
				var m_dist = sqrt(mdx*mdx + mdy*mdy)
				if m_dist <= 14:
					var m_mask_dx = x - 134
					var m_mask_dy = y - 160
					var m_mask_dist = sqrt(m_mask_dx*m_mask_dx + m_mask_dy*m_mask_dy)
					if m_mask_dist > 14:
						img.set_pixel(x, y, moon_color)
						
				# Divider line
				if abs(dy) <= 1:
					img.set_pixel(x, y, Color(0.98, 0.82, 0.4))
					
	img.save_png(path)

func _generate_bar_pngs(dir_path: String) -> void:
	var eng_days = ["monday", "tuesday", "wednesday", "thursday", "friday"]
	var colors = [
		Color(0.85, 0.33, 0.31),
		Color(0.26, 0.55, 0.79),
		Color(0.55, 0.42, 0.73),
		Color(0.94, 0.68, 0.31),
		Color(0.36, 0.72, 0.36)
	]
	
	for i in range(5):
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(colors[i])
		
		var highlight = Color(1.0, 1.0, 1.0, 0.3)
		for y in range(32):
			for x in range(32):
				if x + y < 10:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(highlight, 0.5))
				if (32 - x) + (32 - y) < 12:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(highlight, 0.5))
					
		img.save_png(dir_path + "/progress_fill_" + eng_days[i] + ".png")
