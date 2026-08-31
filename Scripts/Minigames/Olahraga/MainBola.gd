@tool
extends BaseMinigame

# ─── Visual - Art ────────────────────────────────────────────────────────────
@export_group("Visual - Art")
## The goalkeeper standing ready, before the shot resolves.
@export var goalie_idle_texture: Texture2D = preload("res://Assets/Images/Textures/KiperIdle.jpg")
## The goalkeeper diving left. Shown when the save resolves to the left.
@export var goalie_left_texture: Texture2D = preload("res://Assets/Images/Textures/KiperLeft.jpg")
## The goalkeeper diving right.
@export var goalie_right_texture: Texture2D = preload("res://Assets/Images/Textures/KiperRight.jpg")
## The goalkeeper beaten. Shown on a scored goal.
@export var goalie_fail_texture: Texture2D = preload("res://Assets/Images/Textures/Fail.jpg")
## The ball.
@export var ball_texture: Texture2D = preload("res://Assets/Images/Textures/bola.png")
## The pitch and goal frame behind everything. When this is set the procedural
## goal overlays (GoalBack, GoalNet, Crossbar, PostLeft, PostRight) hide, so
## the artwork's own goalposts show cleanly instead of being double-drawn.
@export var field_background_texture: Texture2D = preload("res://Assets/Images/Textures/Gawang.jpg")

# ─── Layout knobs ────────────────────────────────────────────────────────────
# project.godot sets stretch/aspect="expand", so viewport height varies by
# device and this layout has to be computed rather than authored as fixed
# positions. Each knob below is a fraction of the viewport; changing one
# re-runs _setup_layout() immediately, in the editor as well as at runtime.
@export_group("Layout")

## Top edge of the goal mouth, as a fraction of viewport height.
@export_range(0.0, 1.0, 0.005) var goal_top_frac: float = 0.28:
	set(value):
		goal_top_frac = value
		if is_inside_tree():
			_setup_layout()

## Height of the goal mouth, as a fraction of viewport height.
@export_range(0.05, 1.0, 0.005) var goal_height_frac: float = 0.28:
	set(value):
		goal_height_frac = value
		if is_inside_tree():
			_setup_layout()

## Width of the goal mouth, as a fraction of viewport width.
@export_range(0.1, 1.0, 0.005) var goal_width_frac: float = 0.88:
	set(value):
		goal_width_frac = value
		if is_inside_tree():
			_setup_layout()

## Width of each goalpost, as a fraction of viewport width.
@export_range(0.0, 0.1, 0.001) var post_width_frac: float = 0.020:
	set(value):
		post_width_frac = value
		if is_inside_tree():
			_setup_layout()

## Height of the crossbar, as a fraction of viewport height.
@export_range(0.0, 0.05, 0.001) var crossbar_height_frac: float = 0.013:
	set(value):
		crossbar_height_frac = value
		if is_inside_tree():
			_setup_layout()

## Width of the goalkeeper's hitbox and sprite, as a fraction of viewport width.
@export_range(0.1, 1.0, 0.005) var goalie_width_frac: float = 0.42:
	set(value):
		goalie_width_frac = value
		if is_inside_tree():
			_setup_layout()

## Height of the goalkeeper's hitbox and sprite, as a fraction of viewport height.
@export_range(0.05, 1.0, 0.005) var goalie_height_frac: float = 0.22:
	set(value):
		goalie_height_frac = value
		if is_inside_tree():
			_setup_layout()

## How far the goalkeeper stands into the goal, as a fraction of goal height
## measured down from the goal's top edge.
@export_range(0.0, 1.0, 0.005) var goalie_depth_frac: float = 0.76:
	set(value):
		goalie_depth_frac = value
		if is_inside_tree():
			_setup_layout()

## The ball's resting height, as a fraction of viewport height.
@export_range(0.0, 1.0, 0.005) var ball_start_height_frac: float = 0.86:
	set(value):
		ball_start_height_frac = value
		if is_inside_tree():
			_setup_layout()

## The ball's collision and sprite radius, as a fraction of viewport width.
@export_range(0.0, 0.2, 0.001) var ball_radius_frac: float = 0.065:
	set(value):
		ball_radius_frac = value
		if is_inside_tree():
			_setup_layout()

## Width and height of the moving target box, as a fraction of viewport width.
@export_range(0.05, 0.5, 0.005) var target_size_frac: float = 0.18:
	set(value):
		target_size_frac = value
		if is_inside_tree():
			_setup_layout()

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Assign a custom Font resource. Leave null to use default theme font.
@export var font: Font = null
@export var score_font_size: int   = 40
@export var attempts_font_size: int = 30
@export var hint_font_size: int     = 26
@export var score_color: Color      = Color.WHITE
@export var attempts_color: Color   = Color.WHITE
@export var hint_color: Color       = Color(1, 1, 1, 0.65)

# ─── Constants ───────────────────────────────────────────────────────────────
const MAX_ATTEMPTS: int = 8
const TIMER_DURATION: float = 60.0
const GOALIE_SPEED_INCREASE: float = 0.15  # +15% per goal

# ─── Game State ──────────────────────────────────────────────────────────────
var score: int = 0
var target_score: int = 5
var attempts_left: int = MAX_ATTEMPTS
var is_game_over: bool = false
var is_resolving: bool = false   # true while ball/goalie animation plays
var goalie_speed_mult: float = 1.0

# ─── Swipe tracking ──────────────────────────────────────────────────────────
var swipe_start_pos: Vector2
var is_swiping: bool = false

# ─── Node references ─────────────────────────────────────────────────────────
@onready var goal_area: Area2D           = $GoalArea
@onready var goalie: CharacterBody2D     = $Goalie
@onready var ball: CharacterBody2D       = $Ball
@onready var field_markings: Node2D      = $FieldMarkings
@onready var score_label: Label          = $HUDLayer/ScoreLabel
@onready var attempts_label: Label       = $HUDLayer/AttemptsLabel
@onready var swipe_hint: Label           = $HUDLayer/SwipeHint
@onready var target_box_node: Control    = $TargetBox

# ─── Target Box (Pou style moving square target) ─────────────────────────────
var target_x_pos: float = 0.0
var target_dir: float   = 1.0
var target_speed: float = 130.0
var target_w: float     = 70.0
var target_h: float     = 70.0
var pulse_time: float   = 0.0

# ─── GFX children ────────────────────────────────────────────────────────────
var goalie_gfx: TextureRect = null
var ball_gfx:   TextureRect = null

# ─── Layout values (set in _setup_layout) ────────────────────────────────────
var screen_size:    Vector2
var ball_start_pos: Vector2
var goalie_base_pos: Vector2
var goal_left_x:  float
var goal_right_x: float
var goal_top_y:   float
var goal_bot_y:   float
var goalie_half_w: float


# ─── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	super._ready()

	target_score = randi() % 3 + 4   # 4 – 6 goals to win
	attempts_left = MAX_ATTEMPTS

	_setup_layout()
	_setup_field_markings()
	_update_hud()
	_setup_target_box()

	# Note: start_minigame() and activate_minigame() are called externally
	# by MinigameMenu after the scene is instantiated and faded in.

func start_minigame(game_difficulty: int, time_limit: float = 30.0) -> void:
	super.start_minigame(game_difficulty, time_limit)
	if difficulty == 2:
		target_score = randi() % 3 + 6
		goalie_speed_mult = 1.25
	elif difficulty >= 3:
		target_score = randi() % 3 + 8
		goalie_speed_mult = 1.50
	else:
		target_score = randi() % 3 + 4
		goalie_speed_mult = 1.0
	score = 0
	attempts_left = MAX_ATTEMPTS
	_update_hud()


# ─── Process loop for target movement & glow animation ──────────────────────
func _process(delta: float) -> void:
	super._process(delta)
	if not is_game_active or is_resolving or is_game_over:
		return

	# Faster pulse rate for cute urgency feel
	pulse_time += delta * 6.5

	# Move target ping-pong horizontally inside goal
	var current_speed: float = target_speed * goalie_speed_mult
	target_x_pos += target_dir * current_speed * delta

	var min_target_x: float = goal_left_x + target_w * 0.5 + 10.0
	var max_target_x: float = goal_right_x - target_w * 0.5 - 10.0

	if target_x_pos <= min_target_x:
		target_x_pos = min_target_x
		target_dir = 1.0
	elif target_x_pos >= max_target_x:
		target_x_pos = max_target_x
		target_dir = -1.0

	if target_box_node:
		# Scale pulse for cute urgency
		var scale_pulse: float = 1.0 + sin(pulse_time * 1.5) * 0.08
		target_box_node.scale = Vector2(scale_pulse, scale_pulse)
		target_box_node.pivot_offset = target_box_node.size * 0.5
		target_box_node.position = Vector2(target_x_pos - target_w * 0.5, goal_top_y + (goal_bot_y - goal_top_y) * 0.35 - target_h * 0.5)
		target_box_node.queue_redraw()


## Place every visual node from the layout knobs above.
##
## Runs on _ready(), on viewport resize, and whenever a knob changes -- in the
## editor as well as at runtime, which is what makes the 2D viewport show the
## real layout instead of an empty scene.
##
## Affects: the position and size of FieldBG, GoalBack, GoalNet, Crossbar,
## PostLeft, PostRight, GoalArea's collision shape, Goalie (and its
## CollisionShape2D and GFX), Ball (same), and TargetBox. Writes the cached
## goal_left_x / goal_right_x / goal_top_y / goal_bot_y / ball_start_pos /
## goalie_base_pos values the shot resolution reads.
func _setup_layout() -> void:
	screen_size = get_viewport_rect().size
	var sw: float = screen_size.x
	var sh: float = screen_size.y

	# ── Goal dimensions matching Gawang picture ───────────
	var goal_top: float      = sh * goal_top_frac
	var goal_height: float   = sh * goal_height_frac
	var goal_width: float    = sw * goal_width_frac
	var goal_x_left: float   = (sw - goal_width) * 0.5
	var goal_x_right: float  = goal_x_left + goal_width
	var post_w: float        = sw * post_width_frac
	var crossbar_h: float    = sh * crossbar_height_frac

	goal_left_x  = goal_x_left
	goal_right_x = goal_x_right
	goal_top_y   = goal_top
	goal_bot_y   = goal_top + goal_height
	target_x_pos = sw * 0.5
	target_w     = sw * target_size_frac
	target_h     = target_w

	# FieldBG image setup. When set, the artwork's own goalposts show cleanly
	# and the procedural goal overlays below hide instead of double-drawing.
	var field_bg_node: TextureRect = get_node_or_null("FieldBG") as TextureRect
	if field_bg_node:
		field_bg_node.texture = field_background_texture
		for node_name in ["GoalBack", "GoalNet", "Crossbar", "PostLeft", "PostRight"]:
			var n: CanvasItem = get_node_or_null(node_name) as CanvasItem
			if n:
				n.visible = field_background_texture == null

	# GoalBack (dark shadow behind net)
	var goal_back: ColorRect = $GoalBack
	if goal_back:
		goal_back.position = Vector2(goal_x_left, goal_top)
		goal_back.size     = Vector2(goal_width, goal_height)

	# GoalNet (white mesh overlay)
	var goal_net: ColorRect = $GoalNet
	if goal_net:
		goal_net.position = Vector2(goal_x_left, goal_top)
		goal_net.size     = Vector2(goal_width, goal_height)

	# Crossbar (top bar)
	var crossbar: ColorRect = $Crossbar
	if crossbar:
		crossbar.position = Vector2(goal_x_left - post_w, goal_top)
		crossbar.size     = Vector2(goal_width + post_w * 2.0, crossbar_h)

	# PostLeft
	var post_left: ColorRect = $PostLeft
	if post_left:
		post_left.position = Vector2(goal_x_left - post_w, goal_top)
		post_left.size     = Vector2(post_w, goal_height)

	# PostRight
	var post_right: ColorRect = $PostRight
	if post_right:
		post_right.position = Vector2(goal_x_right, goal_top)
		post_right.size     = Vector2(post_w, goal_height)

	# ── GoalArea collision ────────────────────────────────────
	if goal_area:
		goal_area.global_position = Vector2(sw * 0.5, goal_top + goal_height * 0.5)
		var col: CollisionShape2D = goal_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.shape is RectangleShape2D:
			(col.shape as RectangleShape2D).size = Vector2(goal_width * 0.92, goal_height)

	# ── Goalie ───────────────────────────────────────────────
	var g_width: float  = sw * goalie_width_frac
	var g_height: float = sh * goalie_height_frac
	goalie_half_w = g_width * 0.5

	if goalie:
		# Place goalie grounded on the goal line inside Gawang image
		goalie.global_position = Vector2(sw * 0.5, goal_top + goal_height * goalie_depth_frac)
		goalie_base_pos = goalie.global_position

		var col: CollisionShape2D = goalie.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.shape is RectangleShape2D:
			(col.shape as RectangleShape2D).size = Vector2(g_width, g_height)

		goalie_gfx = goalie.get_node_or_null("GFX") as TextureRect
		if goalie_gfx:
			goalie_gfx.texture  = goalie_idle_texture
			goalie_gfx.size     = Vector2(g_width, g_height)
			goalie_gfx.position = Vector2(-g_width * 0.5, -g_height * 0.78)

	# ── Ball ─────────────────────────────────────────────────
	var ball_r: float = sw * ball_radius_frac

	if ball:
		ball.global_position = Vector2(sw * 0.5, sh * ball_start_height_frac)
		ball_start_pos = ball.global_position

		var col: CollisionShape2D = ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.shape is CircleShape2D:
			(col.shape as CircleShape2D).radius = ball_r

		ball_gfx = ball.get_node_or_null("GFX") as TextureRect
		if ball_gfx:
			var side: float = ball_r * 2.0
			ball_gfx.texture  = ball_texture
			ball_gfx.size     = Vector2(side, side)
			ball_gfx.position = Vector2(-ball_r, -ball_r)

		# Add fallback vector draw on Ball node in case texture is invisible or not imported yet
		var draw_node: Control = ball.get_node_or_null("FallbackDraw") as Control
		if not draw_node:
			draw_node = Control.new()
			draw_node.name = "FallbackDraw"
			ball.add_child(draw_node)
		if not draw_node:
			draw_node = Control.new()
			draw_node.name = "FallbackDraw"
			ball.add_child(draw_node)
			draw_node.draw.connect(func():
				if ball_gfx == null or ball_gfx.texture == null:
					draw_node.draw_circle(Vector2.ZERO, ball_r, Color(1, 1, 1, 1))
					draw_node.draw_arc(Vector2.ZERO, ball_r, 0, TAU, 32, Color(0, 0, 0, 1), 2.0, true)
			)
			draw_node.queue_redraw()


# ─── Field markings (_draw callback on Node2D) ───────────────────────────────
func _setup_field_markings() -> void:
	if not field_markings:
		return
	field_markings.draw.connect(_on_field_markings_draw)
	field_markings.queue_redraw()

func _on_field_markings_draw() -> void:
	# Hide green line drawings when full background illustration is active
	if get_node_or_null("FieldBG") and (get_node_or_null("FieldBG") as TextureRect).texture != null:
		return
	if not field_markings:
		return
	var sw := screen_size.x
	var sh := screen_size.y
	var lc := Color(0.50, 0.82, 0.40, 0.55)  # subtle bright-green lines
	var lw: float = maxf(2.5, sw * 0.003)

	# Halfway line
	var mid_y := sh * 0.54
	field_markings.draw_line(Vector2(sw * 0.04, mid_y), Vector2(sw * 0.96, mid_y), lc, lw)

	# Center circle
	field_markings.draw_arc(Vector2(sw * 0.5, mid_y), sw * 0.115, 0, TAU, 48, lc, lw)
	field_markings.draw_circle(Vector2(sw * 0.5, mid_y), 5.5, lc)

	# Penalty spot
	var pen_y := sh * 0.70
	field_markings.draw_circle(Vector2(sw * 0.5, pen_y), 7.0, lc)

	# Penalty D-arc (top half only, opens toward goal)
	field_markings.draw_arc(
		Vector2(sw * 0.5, pen_y),
		sw * 0.13,
		deg_to_rad(195), deg_to_rad(345),
		28, lc, lw
	)

	# Six-yard / small box below goal
	var box_w: float = sw * 0.46
	var box_h: float = sh * 0.065
	var bx: float    = (sw - box_w) * 0.5
	var by: float    = goal_bot_y
	field_markings.draw_rect(Rect2(bx, by, box_w, box_h), lc, false, lw)

	# Penalty area box (larger box)
	var pa_w: float = sw * 0.72
	var pa_h: float = sh * 0.12
	var pax: float  = (sw - pa_w) * 0.5
	var pay: float  = goal_bot_y
	field_markings.draw_rect(Rect2(pax, pay, pa_w, pa_h), lc, false, lw)


# ─── HUD ─────────────────────────────────────────────────────────────────────
func _update_hud() -> void:
	if score_label:
		score_label.text = "Score: %d / %d" % [score, target_score]
		score_label.add_theme_font_size_override("font_size", score_font_size)
		score_label.add_theme_color_override("font_color", score_color)
		score_label.add_theme_constant_override("outline_size", 8)
		score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		if font:
			score_label.add_theme_font_override("font", font)
	if attempts_label:
		attempts_label.text = "Shots Left: %d" % attempts_left
		attempts_label.add_theme_font_size_override("font_size", attempts_font_size)
		attempts_label.add_theme_color_override("font_color", attempts_color)
		attempts_label.add_theme_constant_override("outline_size", 6)
		attempts_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		if font:
			attempts_label.add_theme_font_override("font", font)
	if swipe_hint:
		swipe_hint.add_theme_font_size_override("font_size", hint_font_size)
		swipe_hint.add_theme_color_override("font_color", hint_color)
		if font:
			swipe_hint.add_theme_font_override("font", font)


# ─── Input handling ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not is_game_active or is_resolving:
		return
	if event is InputEventScreenTouch:
		if event.is_pressed():
			swipe_start_pos = event.position
			is_swiping = true
		else:
			_end_swipe(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			swipe_start_pos = event.position
			is_swiping = true
		else:
			_end_swipe(event.position)

func _end_swipe(end_pos: Vector2) -> void:
	if not is_swiping or is_resolving:
		return
	is_swiping = false

	var swipe_vec: Vector2 = end_pos - swipe_start_pos
	var min_y: float = -screen_size.y * 0.06  # must swipe up at least 6% of screen height

	if swipe_vec.y < min_y:
		_shoot_ball(swipe_vec)


# ─── Shoot ───────────────────────────────────────────────────────────────────
func _shoot_ball(swipe_vec: Vector2) -> void:
	is_resolving = true

	# Deduct attempt & update HUD
	attempts_left -= 1
	_update_hud()

	# Hide hint after first shot
	if swipe_hint:
		var ht: Tween = create_tween()
		ht.tween_property(swipe_hint, "modulate:a", 0.0, 0.3)

	var sw: float = screen_size.x

	# ── Determine ball target in goal based on swipe X offset ──
	var goal_center_x: float = sw * 0.5
	var goal_half_w: float   = (goal_right_x - goal_left_x) * 0.42
	var norm_x: float        = clampf(swipe_vec.x / sw, -0.45, 0.45) * 2.2
	var calculated_target_x: float = clampf(goal_center_x + norm_x * goal_half_w, goal_left_x + 10.0, goal_right_x - 10.0)

	# Check if player actually aimed near the moving target box position AT THE MOMENT OF SWIPE
	var target_center_x: float = target_x_pos
	var aimed_at_target: bool = absf(calculated_target_x - target_center_x) < (target_w * 0.75)
	
	var target_x: float
	if aimed_at_target:
		# Player correctly aimed at the moving target! Lock ball straight to target center.
		target_x = target_center_x
	else:
		target_x = calculated_target_x

	var target_y: float      = goal_top_y + (goal_bot_y - goal_top_y) * 0.45
	var ball_target: Vector2 = Vector2(target_x, target_y)

	# ── Goalie dive logic ────────────────────────────────────
	var dive_dir: int
	if aimed_at_target:
		# Goalkeeper dives AWAY from the target box so player gets rewarded!
		if target_x >= goalie_base_pos.x:
			dive_dir = -1  # target is on right -> keeper dives left
		else:
			dive_dir = 1   # target is on left -> keeper dives right
	else:
		# Player did NOT hit/aim at target:
		# Keeper predicts shot location and moves to block it!
		if absf(target_x - goalie_base_pos.x) < goalie_half_w * 0.8:
			# Swiped straight down center: keeper stays/dives slightly to block center shot!
			dive_dir = 0
		elif target_x > goalie_base_pos.x:
			dive_dir = 1   # keeper dives right to block
		else:
			dive_dir = -1  # keeper dives left to block

	# How far the goalie dives
	var dive_dist: float = clampf(sw * 0.28 * goalie_speed_mult, sw * 0.18, sw * 0.45)
	var goalie_tx: float
	if dive_dir == 0:
		# Stay in center to block middle shot!
		goalie_tx = goalie_base_pos.x
	else:
		goalie_tx = clampf(goalie_base_pos.x + float(dive_dir) * dive_dist, goal_left_x + 5.0, goal_right_x - 5.0)

	var dive_time: float = clampf(0.35 / goalie_speed_mult, 0.18, 0.40)

	# ── Set goalie direction texture ─────────────────────────
	if goalie_gfx:
		goalie_gfx.texture = goalie_left_texture if dive_dir < 0 else goalie_right_texture

	# ── Animate ball → goal ──────────────────────────────────
	var ball_tween: Tween = create_tween()
	ball_tween.tween_property(ball, "global_position", ball_target, 0.40)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Ball scales down as it "flies away" (perspective feel)
	ball_tween.parallel().tween_property(ball, "scale", Vector2(0.45, 0.45), 0.40)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# ── Animate goalie dive simultaneously ───────────────────
	var goalie_tween: Tween = create_tween()
	goalie_tween.tween_property(goalie, "global_position:x", goalie_tx, dive_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Wait for ball to arrive, then resolve
	await ball_tween.finished
	_resolve_shot(ball_target, goalie_tx)


# ─── Target Box Setup & Custom Drawing (Pou Style Cute Glowing Target) ─────────
func _setup_target_box() -> void:
	if not target_box_node:
		return

	target_box_node.size = Vector2(target_w, target_h)
	target_box_node.draw.connect(func():
		var rect := Rect2(Vector2.ZERO, target_box_node.size)
		var center: Vector2 = target_box_node.size * 0.5
		var pulse: float = (sin(pulse_time) + 1.0) * 0.5
		var fast_pulse: float = (sin(pulse_time * 2.0) + 1.0) * 0.5

		# 1. Outer Neon Glow Aura (Layered transparent expand)
		var glow_expand: float = 6.0 + pulse * 6.0
		var outer_glow_rect := Rect2(Vector2(-glow_expand, -glow_expand), target_box_node.size + Vector2(glow_expand * 2, glow_expand * 2))
		target_box_node.draw_rect(outer_glow_rect, Color(1.0, 0.85, 0.1, 0.18 + pulse * 0.15), true)

		# 2. Glowing Inner Fill (Warm cute golden-yellow glow)
		var fill_color := Color(1.0, 0.9, 0.25, 0.35 + pulse * 0.2)
		target_box_node.draw_rect(rect, fill_color, true)

		# 3. Multiple Bright Pulsing Border Strokes
		var outer_border := Color(1.0, 0.95, 0.4, 0.95)
		var border_w: float = 4.5 + fast_pulse * 2.5
		target_box_node.draw_rect(rect, outer_border, false, border_w)

		# 4. Inner Cute Target Accents (Corners & Center Star/Crosshair)
		var inner_inset: float = target_w * 0.22
		var inner_rect := Rect2(Vector2(inner_inset, inner_inset), Vector2(target_w - inner_inset * 2, target_h - inner_inset * 2))
		target_box_node.draw_rect(inner_rect, Color(1.0, 1.0, 1.0, 0.85 + pulse * 0.15), false, 2.5)

		# 5. Four Corner Sparkle Dots for extra cuteness
		var dot_r: float = 3.5 + pulse * 1.5
		var c_inset: float = 6.0
		var corners := [
			Vector2(c_inset, c_inset),
			Vector2(target_w - c_inset, c_inset),
			Vector2(c_inset, target_h - c_inset),
			Vector2(target_w - c_inset, target_h - c_inset)
		]
		for dot in corners:
			target_box_node.draw_circle(dot, dot_r, Color(1.0, 1.0, 0.7, 0.9))

		# 6. Center Pulsing Bullseye Core
		var core_r: float = target_w * 0.09 + fast_pulse * 2.5
		target_box_node.draw_circle(center, core_r, Color(1.0, 1.0, 1.0, 0.95))
	)


# ─── Resolve shot ────────────────────────────────────────────────────────────
func _resolve_shot(ball_target: Vector2, goalie_x: float) -> void:
	var in_goal_x: bool = ball_target.x >= goal_left_x and ball_target.x <= goal_right_x
	var goalie_hit: bool = absf(ball_target.x - goalie_x) < goalie_half_w
	
	# Target box hit check (Pou style hit test)
	var target_center_x: float = target_x_pos
	var target_hit: bool = absf(ball_target.x - target_center_x) < (target_w * 0.75)

	# A goal is ONLY scored if the ball hits the moving target box AND avoids the goalkeeper!
	if target_hit and not goalie_hit and in_goal_x:
		await _on_goal_scored()
	else:
		await _on_shot_missed(goalie_hit)


# ─── Goal scored ─────────────────────────────────────────────────────────────
func _on_goal_scored() -> void:
	score += 1
	goalie_speed_mult += GOALIE_SPEED_INCREASE  # get harder each goal
	_update_hud()
	print("GOAL! %d / %d" % [score, target_score])

	# Brief flash green on score label
	if score_label:
		score_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		await get_tree().create_timer(0.35).timeout
		score_label.remove_theme_color_override("font_color")
	else:
		await get_tree().create_timer(0.35).timeout

	_reset_shot()

	if score >= target_score and not is_game_over:
		is_game_over = true
		win_game()


# ─── Shot missed / blocked ───────────────────────────────────────────────────
func _on_shot_missed(was_blocked: bool) -> void:
	print("Shot %s!" % ("blocked" if was_blocked else "missed"))

	if goalie_gfx and was_blocked:
		# Keep dive texture briefly to show the save
		pass

	await get_tree().create_timer(0.45).timeout
	_reset_shot()

	if attempts_left <= 0 and not is_game_over:
		is_game_over = true
		_show_result_overlay(false, "Skor: %d / %d" % [score, target_score])


# ─── Reset between shots ─────────────────────────────────────────────────────
func _reset_shot() -> void:
	is_resolving = false

	# Reset ball position and scale
	if ball:
		ball.global_position = ball_start_pos
		ball.scale = Vector2.ONE

	# Goalie returns to center, texture back to idle
	if goalie_gfx:
		goalie_gfx.texture = goalie_idle_texture
	if goalie:
		var rt := create_tween()
		rt.tween_property(goalie, "global_position:x", goalie_base_pos.x, 0.28)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ─── Override lose_game to bypass BaseMinigame's score-check shortcut ────────
func lose_game() -> void:
	if not is_game_active:
		return
	is_game_active = false
	is_game_over   = true
	process_mode   = Node.PROCESS_MODE_INHERIT
	if pause_button:
		pause_button.disabled     = true
		pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if timer:
		timer.stop()
	set_process_input(false)
	_show_result_overlay(false, "Skor akhir: %d / %d" % [score, target_score])
