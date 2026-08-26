extends Node2D

# Configurable parameters
const CIRCLE_START_RADIUS: float = 80.0
const CIRCLE_END_RADIUS: float = 12.0
const CIRCLE_START_WIDTH: float = 8.0
const CIRCLE_END_WIDTH: float = 1.0
const CIRCLE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0) # White base

const STAR_COUNT: int = 8
const DUST_COUNT: int = 12
const EFFECT_LIFETIME: float = 0.55

# Vibrant Gradient pairs: [start_color, end_color]
const GRADIENTS = [
	[Color(1.0, 0.85, 0.1), Color(1.0, 0.3, 0.1)],  # Gold to Red-Orange
	[Color(0.1, 0.85, 1.0), Color(0.7, 0.3, 1.0)],  # Neon Cyan to Deep Purple
	[Color(1.0, 0.25, 0.55), Color(0.6, 0.1, 0.9)], # Hot Pink to Violet
	[Color(0.25, 0.95, 0.4), Color(0.1, 0.6, 1.0)], # Lime Green to Electric Blue
	[Color(1.0, 0.6, 0.0), Color(1.0, 0.1, 0.5)],   # Orange to Crimson
	[Color(0.8, 1.0, 0.2), Color(0.0, 0.8, 0.6)]    # Lemon-Lime to Teal
]

# State variables for collapsing circle (out to in)
var circle_radius: float = CIRCLE_START_RADIUS
var circle_width: float = CIRCLE_START_WIDTH
var circle_alpha: float = 1.0

# State variables for expanding circle (in to out)
var expand_radius: float = 10.0
var expand_width: float = CIRCLE_START_WIDTH
var expand_alpha: float = 1.0

# Particle representation
class TouchParticle:
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var rotation_speed: float
	var scale: float
	var initial_scale: float
	var start_color: Color
	var end_color: Color
	var color: Color
	var alpha: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float
	var is_star: bool = false
	var star_points: PackedVector2Array

# Array of all active particles inside this effect
var particles: Array[TouchParticle] = []

func _ready() -> void:
	# Spawn particles
	_spawn_particles()
	
	# Create tween for circle stroke animation (collapsing and fading)
	var tween = create_tween().set_parallel(true)
	
	# Shrink the circle from big to small
	tween.tween_property(self, "circle_radius", CIRCLE_END_RADIUS, EFFECT_LIFETIME)\
		.from(CIRCLE_START_RADIUS)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	# Thin the line width
	tween.tween_property(self, "circle_width", CIRCLE_END_WIDTH, EFFECT_LIFETIME)\
		.from(CIRCLE_START_WIDTH)\
		.set_trans(Tween.TRANS_LINEAR)
		
	# Fade the circle alpha
	tween.tween_property(self, "circle_alpha", 0.0, EFFECT_LIFETIME)\
		.from(1.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	# Expand the circle from small to big
	tween.tween_property(self, "expand_radius", CIRCLE_START_RADIUS + 20.0, EFFECT_LIFETIME)\
		.from(10.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	# Thin the expand line width
	tween.tween_property(self, "expand_width", CIRCLE_END_WIDTH, EFFECT_LIFETIME)\
		.from(CIRCLE_START_WIDTH)\
		.set_trans(Tween.TRANS_LINEAR)
		
	# Fade the expand circle alpha
	tween.tween_property(self, "expand_alpha", 0.0, EFFECT_LIFETIME)\
		.from(1.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	# Free the node after the lifetime ends
	tween.chain().tween_callback(queue_free)

func _spawn_particles() -> void:
	# Calculate a template 5-pointed star polygon vertices
	var star_pts = _generate_star_points(16.0, 7.0) # Outer radius 16, inner 7
	
	# 1. Spawn stars (exploding outward)
	for i in range(STAR_COUNT):
		var p = TouchParticle.new()
		p.is_star = true
		p.star_points = star_pts
		p.position = Vector2.ZERO # Starts at center
		
		# Random direction and velocity
		var angle = randf() * TAU
		var speed = randf_range(250.0, 500.0)
		p.velocity = Vector2(cos(angle), sin(angle)) * speed
		
		p.rotation = randf() * TAU
		p.rotation_speed = randf_range(-12.0, 12.0)
		
		p.initial_scale = randf_range(0.6, 1.2)
		p.scale = p.initial_scale
		
		# Assign dynamic gradient
		var grad = GRADIENTS[randi() % GRADIENTS.size()]
		p.start_color = grad[0]
		p.end_color = grad[1]
		p.color = p.start_color
		
		p.max_lifetime = randf_range(0.4, EFFECT_LIFETIME)
		particles.append(p)
		
	# 2. Spawn dust circles (softer trail/smoke after touch)
	for i in range(DUST_COUNT):
		var p = TouchParticle.new()
		p.is_star = false
		p.position = Vector2.ZERO
		
		# Random direction and velocity (slightly slower)
		var angle = randf() * TAU
		var speed = randf_range(100.0, 300.0)
		p.velocity = Vector2(cos(angle), sin(angle)) * speed
		
		p.initial_scale = randf_range(4.0, 9.0) # Use initial_scale as radius
		p.scale = p.initial_scale
		
		# Assign dynamic gradient (slightly lighter/faded)
		var grad = GRADIENTS[randi() % GRADIENTS.size()]
		p.start_color = Color.WHITE.lerp(grad[0], 0.5)
		p.end_color = Color.WHITE.lerp(grad[1], 0.3)
		p.color = p.start_color
		
		p.max_lifetime = randf_range(0.3, EFFECT_LIFETIME - 0.1)
		particles.append(p)

func _generate_star_points(outer: float, inner: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(10):
		var angle = i * PI / 5.0 - PI / 2.0
		var r = outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	return pts

func _process(delta: float) -> void:
	# Update particles
	for p in particles:
		p.lifetime += delta
		var t = clampf(p.lifetime / p.max_lifetime, 0.0, 1.0)
		
		# Apply drag and gravity
		p.velocity *= exp(-3.0 * delta) # smooth drag
		if p.is_star:
			p.velocity.y += 650.0 * delta # Gravity pulling stars down slightly
			p.rotation += p.rotation_speed * delta
			
		p.position += p.velocity * delta
		
		# Scale down, interpolate gradient color, and fade out
		p.scale = lerpf(p.initial_scale, 0.0, t)
		p.color = p.start_color.lerp(p.end_color, t)
		p.alpha = lerpf(1.0, 0.0, t)
		
	# Request redraw
	queue_redraw()

func _draw() -> void:
	# 1a. Draw collapsing circle stroke (out to in)
	if circle_alpha > 0.01 and circle_width > 0.1:
		var c = CIRCLE_COLOR
		c.a = circle_alpha
		draw_arc(Vector2.ZERO, circle_radius, 0.0, TAU, 48, c, circle_width, true)
		
	# 1b. Draw expanding circle stroke (in to out)
	if expand_alpha > 0.01 and expand_width > 0.1:
		var c = CIRCLE_COLOR
		c.a = expand_alpha
		draw_arc(Vector2.ZERO, expand_radius, 0.0, TAU, 48, c, expand_width, true)
		
	# 2. Draw active particles
	for p in particles:
		if p.lifetime >= p.max_lifetime:
			continue
		
		var col = p.color
		col.a = p.alpha
		
		if p.is_star:
			# Use custom transform matrix to draw rotated and scaled star
			draw_set_transform(p.position, p.rotation, Vector2(p.scale, p.scale))
			draw_colored_polygon(p.star_points, col)
			# Reset transform
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			# Draw simple dust circles
			draw_circle(p.position, p.scale, col)
