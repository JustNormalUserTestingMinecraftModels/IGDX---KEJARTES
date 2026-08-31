extends BaseMinigame

# ─── Visual - Shuttlecock ───────────────────────────────────────────────────
@export_group("Visual - Shuttlecock")
## Drag a PNG here to replace the default shuttlecock/puck.
@export var shuttlecock_texture: Texture2D = null
## Currently unreferenced by this script -- the Puck sprite's colour
## comes from its scene-assigned texture, not this export.
@export var shuttlecock_color: Color = Color(1, 0.8, 0, 1)

# ─── Visual - Rackets ────────────────────────────────────────────────────────
@export_group("Visual - Rackets")
## Drag a PNG here for the Player racket.
@export var player_racket_texture: Texture2D = null
## Currently unreferenced by this script -- see shuttlecock_color above.
@export var player_racket_color: Color = Color(0, 0.5, 1, 1)
## Drag a PNG here for the Enemy racket.
@export var enemy_racket_texture: Texture2D = null
## Currently unreferenced by this script -- see shuttlecock_color above.
@export var enemy_racket_color: Color = Color(1, 0, 0.5, 1)
## Drag a PNG here for the brief "hit" pose shown when a racket connects
## with the shuttlecock. Shared by both rackets; leave null to keep the
## squash-only animation with no texture swap.
@export var racket_hit_texture: Texture2D = null

# ─── Visual - Trail & VFX ────────────────────────────────────────────────────
@export_group("Visual - Trail & VFX")
## Texture for the Line2D trail following the shuttlecock. Null draws a
## plain gradient-only line.
@export var trail_texture: Texture2D = null
## Texture for the puck's motion smoke particles. Null falls back to a
## procedurally-generated soft dot.
@export var particle_texture: Texture2D = null
## Master switch for the shuttlecock's motion trail.
@export var show_trail: bool = true
## Currently unreferenced by this script -- the trail's colour comes
## from a hardcoded Gradient in _setup_trail_and_particles(), not this
## export.
@export var trail_color: Color = Color(1.0, 0.9, 0.3, 0.6)
## Currently unreferenced by this script -- the trail's width comes from
## screen_size in _setup_trail_and_particles(), not this export.
@export var trail_width: float = 8.0

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Assign a custom Font resource. Leave null to use default theme font.
@export var font: Font = null
## Font size for the score label.
@export var score_font_size: int = 48
## Text colour for the score label.
@export var score_color: Color = Color.WHITE

@export_group("Configuration")
## Speed cap (px/s) on the player paddle's drag-follow movement.
@export var max_paddle_speed: float = 2400.0

var player_score: int = 0
var enemy_score: int = 0
var target_score: int = 5

@onready var puck: RigidBody2D           = $Puck
@onready var player_paddle: CharacterBody2D = $PlayerPaddle
@onready var enemy_paddle: CharacterBody2D  = $EnemyPaddle

@onready var player_goal: Area2D         = $PlayerGoal
@onready var enemy_goal: Area2D          = $EnemyGoal
@onready var score_label: Label          = $ScoreLabel

var is_dragging_player: bool = false
var player_target_pos: Vector2 = Vector2.ZERO
var puck_start_pos: Vector2

# ─── Visual nodes ────────────────────────────────────────────────────────────
# These are real nodes in Badminton.tscn, positioned and textured there.
# The @export textures on this script still win at runtime so an artist can
# override the scene's choice from the root's Inspector without opening the
# subtree.
@onready var puck_sprite: Sprite2D = $Puck/Sprite2D
@onready var player_paddle_sprite: Sprite2D = $PlayerPaddle/Sprite2D
@onready var enemy_paddle_sprite: Sprite2D = $EnemyPaddle/Sprite2D

var screen_size: Vector2

var min_puck_speed: float = 350.0
var max_puck_speed: float = 1200.0
var is_puck_in_serve: bool = false
var last_conceding_side: String = "player"  # "player" or "enemy"
var _saved_puck_velocity: Vector2 = Vector2.ZERO
var _serve_tween: Tween = null

# ─── Trail & Particles ────────────────────────────────────────────────────────
var trail_line: Line2D
var puck_particles: CPUParticles2D
var trail_points: PackedVector2Array = PackedVector2Array()
var max_trail_length: int = 12

func start_minigame(game_difficulty: int, _time_limit: float = 30.0) -> void:
	super.start_minigame(game_difficulty, 0.0)
	if difficulty == 2:
		target_score = 7
	elif difficulty >= 3:
		target_score = 9
	else:
		target_score = 5
	player_score = 0
	enemy_score = 0
	last_conceding_side = "player"
	_update_score_ui()

func activate_minigame() -> void:
	await super.activate_minigame()
	_reset_puck("player")

func _on_countdown_start() -> void:
	if puck:
		_saved_puck_velocity = puck.linear_velocity
		puck.freeze = true
		puck.linear_velocity = Vector2.ZERO
		puck.angular_velocity = 0.0
	if is_puck_in_serve and _serve_tween and _serve_tween.is_valid():
		_serve_tween.pause()

func _on_countdown_end() -> void:
	if puck and not is_puck_in_serve:
		puck.freeze = false
		puck.linear_velocity = _saved_puck_velocity
	if is_puck_in_serve and _serve_tween and _serve_tween.is_valid():
		_serve_tween.play()

func _ready() -> void:
	super._ready()
	screen_size = get_viewport_rect().size
	_add_background()
	
	# Position walls at court edge with active collision to safely bounce puck inward
	var wall_left = get_node_or_null("WallLeft")
	if wall_left:
		wall_left.global_position = Vector2(8, screen_size.y / 2)
		var col = wall_left.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(20, screen_size.y)
			col.disabled = false
			
	var wall_right = get_node_or_null("WallRight")
	if wall_right:
		wall_right.global_position = Vector2(screen_size.x - 8, screen_size.y / 2)
		var col = wall_right.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(20, screen_size.y)
			col.disabled = false
			
	var wall_top = get_node_or_null("WallTopLimit")
	if wall_top:
		wall_top.global_position = Vector2(screen_size.x / 2, -10)
		var col = wall_top.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(screen_size.x, 20)
			col.disabled = false
			
	var wall_bottom = get_node_or_null("WallBottomLimit")
	if wall_bottom:
		wall_bottom.global_position = Vector2(screen_size.x / 2, screen_size.y + 10)
		var col = wall_bottom.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(screen_size.x, 20)
			col.disabled = false
			
	if player_goal:
		player_goal.global_position = Vector2(screen_size.x / 2, screen_size.y - 30)
		var col = player_goal.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(screen_size.x * 0.98, 60)
			
	if enemy_goal:
		enemy_goal.global_position = Vector2(screen_size.x / 2, 30)
		var col = enemy_goal.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(screen_size.x * 0.98, 60)
			
	if puck:
		puck.global_position = Vector2(screen_size.x / 2, screen_size.y * 0.5)
		puck_start_pos = puck.global_position
		puck.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		puck.contact_monitor = true
		puck.max_contacts_reported = 4
		puck.body_entered.connect(_on_puck_body_entered)
		var col = puck.get_node_or_null("CollisionShape2D")
		if col and col.shape is CircleShape2D:
			col.shape.radius = screen_size.x * 0.04

	if player_paddle:
		player_paddle.global_position = Vector2(screen_size.x / 2, screen_size.y * 0.8)
		var col = player_paddle.get_node_or_null("CollisionShape2D")
		if col and col.shape is CircleShape2D:
			col.shape.radius = screen_size.x * 0.06

	if enemy_paddle:
		enemy_paddle.global_position = Vector2(screen_size.x / 2, screen_size.y * 0.2)
		var col = enemy_paddle.get_node_or_null("CollisionShape2D")
		if col and col.shape is CircleShape2D:
			col.shape.radius = screen_size.x * 0.06

	_apply_visual_exports()

	if player_goal:
		player_goal.body_entered.connect(_on_player_goal)
	if enemy_goal:
		enemy_goal.body_entered.connect(_on_enemy_goal)
		
	min_puck_speed = max(screen_size.x * 0.45, 320.0)
	max_puck_speed = max(screen_size.x * 1.5, 900.0)
	
	_setup_trail_and_particles()

## Push the root's @export art onto the scene's sprites.
##
## The scene already supplies a texture for each piece, baked in when the
## sprites were authored; these exports let an artist override the choice
## from one Inspector panel without opening the subtree. A null export
## leaves the scene's own texture alone.
##
## The `*_color` exports are not applied here. They used to paint a flat
## ColorRect shown only when no texture was set; now every piece always has
## a real texture baked into the scene, so there is no colorless state left
## to tint -- applying them as a sprite modulate would visibly recolour the
## shipped artwork instead of acting as a fallback.
##
## Affects: the three Sprite2D nodes' texture. Nothing else.
func _apply_visual_exports() -> void:
	if shuttlecock_texture != null:
		puck_sprite.texture = shuttlecock_texture
	if player_racket_texture != null:
		player_paddle_sprite.texture = player_racket_texture
	if enemy_racket_texture != null:
		enemy_paddle_sprite.texture = enemy_racket_texture

func _add_background() -> void:
	var tex_path := "res://Assets/Images/Textures/lapanganBadminton.jpg"
	if not ResourceLoader.exists(tex_path):
		return
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load(tex_path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

var _puck_hit_cooldown: float = 0.0

# Hit Bounce Arc Scale Animation on Puck Visual + Cute Racket Squash Animation
func _on_puck_body_entered(body: Node) -> void:
	if is_scoring_delay:
		return
	if (body == player_paddle or body == enemy_paddle) and _puck_hit_cooldown <= 0.0:
		_puck_hit_cooldown = 0.22 # Prevent multi-hit trigger jitter
		_redirect_puck_towards_opponent(body)
		_play_hit_bounce_animation()
		_play_racket_squash_animation(body as CharacterBody2D)
		if puck_sprite:
			puck_sprite.flip_v = not puck_sprite.flip_v

func _redirect_puck_towards_opponent(body: Node) -> void:
	if not puck: return
	var cur_speed = clamp(puck.linear_velocity.length(), min_puck_speed, max_puck_speed)
	
	# Determine target direction towards opposing half-court
	var target_y_dir: float = -1.0 if body == player_paddle else 1.0 # Player hits UP (-Y), Enemy hits DOWN (+Y)
	
	# Calculate aim vector towards opposing center area with slight lateral variance based on contact offset
	var offset_x = puck.global_position.x - body.global_position.x
	var normalized_offset_x = clamp(offset_x / (screen_size.x * 0.12), -0.6, 0.6)
	
	var desired_dir = Vector2(normalized_offset_x, target_y_dir * 1.8).normalized()
	puck.linear_velocity = desired_dir * cur_speed

func _play_hit_bounce_animation() -> void:
	if not puck: return

	# Punch relative to the node's resting scale -- a Sprite2D showing a
	# texture much larger than its display size (see shuttlecock_texture)
	# rests at a fractional scale, not 1.0, so animating to absolute
	# values here would permanently blow it up to native texture size.
	var base_scale: Vector2 = puck_sprite.scale

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Scale the sprite only so collision shape stays constant (prevents physics jitter)
	tw.tween_property(puck_sprite, "scale", base_scale * 1.6, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(puck_sprite, "scale", base_scale, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _play_racket_squash_animation(racket: CharacterBody2D) -> void:
	if not racket or not is_instance_valid(racket): return
	var sprite: Sprite2D = player_paddle_sprite if racket == player_paddle else enemy_paddle_sprite

	# Swap to the "hit" pose for the duration of the squash, then back to
	# whatever the sprite was actually showing -- not the @export texture,
	# which may be null while the scene's own baked texture is what is
	# really on screen.
	var idle_texture: Texture2D = sprite.texture
	if racket_hit_texture:
		sprite.texture = racket_hit_texture

	# Punch relative to the node's resting scale -- see _play_hit_bounce_animation's
	# note on why an absolute (1,1) target would be wrong once a racket texture
	# is assigned (its rest scale is a fraction, sized to fit the touch target).
	var base_scale: Vector2 = sprite.scale

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sprite, "scale", base_scale * Vector2(1.35, 0.72), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", base_scale * Vector2(0.78, 1.35), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", base_scale, 0.12).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	if racket_hit_texture:
		tw.tween_callback(func():
			if is_instance_valid(sprite):
				sprite.texture = idle_texture
		)

func _physics_process(delta: float) -> void:
	if not is_game_active or is_paused:
		return

	if _puck_hit_cooldown > 0.0:
		_puck_hit_cooldown -= delta

	# Safety Rescue Net
	if puck and is_game_active:
		var margin = 100.0
		var court_rect = Rect2(-margin, -margin, screen_size.x + margin * 2, screen_size.y + margin * 2)
		if not court_rect.has_point(puck.global_position) and not is_puck_in_serve:
			call_deferred("_reset_puck", last_conceding_side)
			return

	# Player Paddle Movement
	if is_dragging_player and player_paddle and player_target_pos != Vector2.ZERO:
		var move_vec = player_target_pos - player_paddle.global_position
		var desired_velocity = move_vec / delta
		if desired_velocity.length() > max_paddle_speed:
			desired_velocity = desired_velocity.normalized() * max_paddle_speed
		player_paddle.velocity = desired_velocity
		player_paddle.move_and_slide()

	# Enemy AI
	if enemy_paddle and puck:
		var target_x = puck.global_position.x
		var target_y = puck.global_position.y
		if puck.global_position.y > screen_size.y / 2:
			target_y = screen_size.y * 0.25
			
		# Clamp target position to the enemy's playable area
		target_y = clamp(target_y, 80.0, screen_size.y / 2.0 - 80.0)
		target_x = clamp(target_x, 80.0, screen_size.x - 80.0)
		
		var current_x = enemy_paddle.global_position.x
		var current_y = enemy_paddle.global_position.y
		
		var diff_x = target_x - current_x
		var diff_y = target_y - current_y
		var max_speed = 260.0
		if difficulty == 2:
			max_speed = 360.0
		elif difficulty >= 3:
			max_speed = 460.0
		
		enemy_paddle.velocity.x = diff_x / delta * 0.15
		enemy_paddle.velocity.y = diff_y / delta * 0.15
		
		if enemy_paddle.velocity.length() > max_speed:
			enemy_paddle.velocity = enemy_paddle.velocity.normalized() * max_speed
			
		enemy_paddle.move_and_slide()

	# Puck Velocity regulation & Directional Safety Clamping
	if puck and not is_puck_in_serve:

		var vel = puck.linear_velocity
		var speed = vel.length()
		if speed > 10.0:
			var new_vel = vel.lerp(vel.normalized() * min_puck_speed, 1.2 * delta)
			var new_speed = new_vel.length()
			if new_speed > max_puck_speed:
				puck.linear_velocity = new_vel.normalized() * max_puck_speed
			elif new_speed < min_puck_speed:
				puck.linear_velocity = new_vel.normalized() * min_puck_speed
			else:
				puck.linear_velocity = new_vel
				
			# Guarantee strong forward Y movement (minimum 120.0 speed in Y axis) so puck never travels horizontally
			if abs(puck.linear_velocity.y) < 120.0:
				puck.linear_velocity.y = 120.0 * (-1.0 if puck.linear_velocity.y < 0.0 else 1.0)

	_update_trail_and_particles()

func _input(event: InputEvent) -> void:
	if not is_game_active or is_paused:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			var touch_radius = screen_size.x * 0.12
			if player_paddle and event.position.distance_to(player_paddle.global_position) < touch_radius:
				is_dragging_player = true
				player_target_pos = player_paddle.global_position
		else:
			is_dragging_player = false
			
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_dragging_player:
			var target_pos = event.position
			target_pos.y = clamp(target_pos.y, screen_size.y / 2 + 50, screen_size.y - 50)
			target_pos.x = clamp(target_pos.x, 50, screen_size.x - 50)
			player_target_pos = target_pos

var is_scoring_delay: bool = false

func _on_player_goal(body: Node2D) -> void:
	if not is_game_active or is_scoring_delay:
		return
	if body == puck:
		is_scoring_delay = true
		enemy_score += 1
		last_conceding_side = "player"
		_trigger_score_sequence(false)

func _on_enemy_goal(body: Node2D) -> void:
	if not is_game_active or is_scoring_delay:
		return
	if body == puck:
		is_scoring_delay = true
		player_score += 1
		last_conceding_side = "enemy"
		_trigger_score_sequence(true)

func _trigger_score_sequence(is_player_score: bool) -> void:
	if puck:
		puck.set_deferred("freeze", true)
		puck.set_deferred("linear_velocity", Vector2.ZERO)
		puck.set_deferred("angular_velocity", 0.0)
		
	# 1. Spawn floating "+1 Poin" label in screen center with white banner stripes
	_spawn_point_popup(is_player_score)

	_update_score_ui()

	# 2. Blinking puck animation
	var rect = puck.get_node_or_null("ColorRect") if puck else null
	var visual_node: CanvasItem = rect if rect else puck
	
	if visual_node:
		var blink_tween = create_tween()
		blink_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		for i in range(3):
			blink_tween.tween_property(visual_node, "modulate:a", 0.15, 0.12)
			blink_tween.tween_property(visual_node, "modulate:a", 1.0, 0.12)
			
		await blink_tween.finished
		visual_node.modulate.a = 1.0
		
	# 3. Resume / Serve next round
	is_scoring_delay = false
	_check_win_condition()
	if is_game_active:
		_reset_puck(last_conceding_side)

func _spawn_point_popup(is_player_score: bool) -> void:
	var container = Control.new()
	container.name = "ScoreBannerPopup"
	container.position = Vector2(0, screen_size.y * 0.45)
	container.size = Vector2(screen_size.x, 90)
	container.z_index = 100
	add_child(container)
	
	# Semi-transparent dark background rectangle (UI placeholder box)
	var bg_rect = ColorRect.new()
	bg_rect.name = "BannerBG"
	bg_rect.color = Color(0.08, 0.10, 0.14, 0.78) # Dark Slate Blue-Black with opacity
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg_rect)
	
	# Top & Bottom horizontal white banner stripes that expand left and right
	var stripe_top = ColorRect.new()
	stripe_top.color = Color(1, 1, 1, 0.9)
	stripe_top.size = Vector2(0, 4)
	stripe_top.position = Vector2(screen_size.x / 2.0, 0)
	container.add_child(stripe_top)
	
	var stripe_bottom = ColorRect.new()
	stripe_bottom.color = Color(1, 1, 1, 0.9)
	stripe_bottom.size = Vector2(0, 4)
	stripe_bottom.position = Vector2(screen_size.x / 2.0, 86)
	container.add_child(stripe_bottom)
	
	var popup_label = Label.new()
	popup_label.text = "+1 Poin!"
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_label.add_theme_font_size_override("font_size", 44)
	popup_label.add_theme_constant_override("outline_size", 10)
	popup_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	if is_player_score:
		popup_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4)) # Bright Green
	else:
		popup_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35)) # Coral Red
		
	container.add_child(popup_label)
	
	container.modulate.a = 0.0
	
	# Synchronized Animation (0.95s total)
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	
	# 1. Fade Container In & Out
	tw.tween_property(container, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(container, "modulate:a", 0.0, 0.35).set_delay(0.60).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 2. Expand White Stripes Left & Right across screen
	tw.tween_property(stripe_top, "position:x", 0.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(stripe_top, "size:x", screen_size.x, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tw.tween_property(stripe_bottom, "position:x", 0.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(stripe_bottom, "size:x", screen_size.x, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tw.set_parallel(false)
	tw.tween_callback(container.queue_free)

func _reset_puck(receiver_side: String = "player") -> void:
	if not is_game_active:
		return
	if puck:
		is_puck_in_serve = true
		puck.freeze = true
		puck.linear_velocity = Vector2.ZERO
		puck.angular_velocity = 0.0
		trail_points.clear()
		if trail_line:
			trail_line.points = []
		
		var serve_origin: Vector2
		var peak_pos: Vector2
		var target_vel: Vector2
		
		if receiver_side == "player":
			serve_origin = Vector2(screen_size.x * 0.5, screen_size.y * 0.35)
			target_vel = Vector2(randf_range(-160, 160), randf_range(320, 460))
			peak_pos = serve_origin + Vector2(randf_range(-40, 40), 100.0)
		else:
			serve_origin = Vector2(screen_size.x * 0.5, screen_size.y * 0.65)
			target_vel = Vector2(randf_range(-160, 160), -randf_range(320, 460))
			peak_pos = serve_origin + Vector2(randf_range(-40, 40), -100.0)

		puck.global_position = serve_origin
		puck.scale = Vector2(1.0, 1.0)
		
		var tween = create_tween()
		_serve_tween = tween
		
		tween.tween_property(puck, "global_position", peak_pos, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(puck, "scale", Vector2(1.7, 1.7), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		tween.tween_property(puck, "global_position", serve_origin, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(puck, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		tween.tween_callback(func():
			puck.freeze = false
			is_puck_in_serve = false
			puck.linear_velocity = target_vel
		)

func _update_score_ui() -> void:
	if score_label:
		score_label.text = "%d - %d" % [enemy_score, player_score]
		score_label.add_theme_font_size_override("font_size", score_font_size)
		score_label.add_theme_color_override("font_color", score_color)
		score_label.add_theme_constant_override("outline_size", 8)
		score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		if font:
			score_label.add_theme_font_override("font", font)

func _check_win_condition() -> void:
	if player_score >= target_score:
		win_game()
	elif enemy_score >= target_score:
		lose_game()

func win_game() -> void:
	if puck:
		puck.set_deferred("freeze", true)
		puck.set_deferred("linear_velocity", Vector2.ZERO)
		puck.set_deferred("angular_velocity", 0.0)
	super.win_game()

func lose_game() -> void:
	if puck:
		puck.set_deferred("freeze", true)
		puck.set_deferred("linear_velocity", Vector2.ZERO)
		puck.set_deferred("angular_velocity", 0.0)
	super.lose_game()

func _update_trail_and_particles() -> void:
	if show_trail and trail_line:
		if puck and not is_puck_in_serve and is_game_active:
			trail_points.append(puck.global_position)
			if trail_points.size() > max_trail_length:
				trail_points.remove_at(0)
		else:
			trail_points.clear()
		trail_line.points = trail_points
		
	if puck_particles:
		if puck and not is_puck_in_serve and is_game_active and puck.linear_velocity.length() > 80.0:
			puck_particles.emitting = true
		else:
			puck_particles.emitting = false

func _create_procedural_smoke_texture() -> Texture2D:
	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var t = dist / radius
				var alpha = (1.0 - t * t) * 0.45
				img.set_pixel(x, y, Color(0.95, 0.97, 1.0, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _setup_trail_and_particles() -> void:
	var smoke_tex: Texture2D = particle_texture if particle_texture else _create_procedural_smoke_texture()

	trail_line = Line2D.new()
	trail_line.name = "PuckTrailLine"
	trail_line.width = screen_size.x * 0.01
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.05))
	curve.add_point(Vector2(1, 1.0))
	trail_line.width_curve = curve
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(0.9, 0.95, 1.0, 0.25))
	trail_line.gradient = gradient
	
	if trail_texture:
		trail_line.texture = trail_texture
		trail_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		
	add_child(trail_line)
	
	if puck:
		puck_particles = CPUParticles2D.new()
		puck_particles.name = "PuckTrailParticles"
		puck_particles.amount = 10
		puck_particles.lifetime = 0.22
		puck_particles.direction = Vector2.ZERO
		puck_particles.spread = 180.0
		puck_particles.gravity = Vector2(0, -15.0)
		puck_particles.initial_velocity_min = 5.0
		puck_particles.initial_velocity_max = 20.0
		puck_particles.scale_amount_min = 0.05
		puck_particles.scale_amount_max = 0.15
		
		var p_gradient = Gradient.new()
		p_gradient.set_color(0, Color(0.95, 0.97, 1.0, 0.35))
		p_gradient.set_color(1, Color(0.85, 0.9, 1.0, 0.0))
		puck_particles.color_ramp = p_gradient
		
		puck_particles.texture = smoke_tex
		puck_particles.emitting = false
		puck.add_child(puck_particles)
