extends BaseMinigame

## Seconds between the losing point and the loss card, the beat
## BaseMinigame.lose_game() gave before this game overrode it.
const LOSS_CARD_DELAY := 1.2
## How far the court art sits above the screen (the scene's Background
## offsets, spec 2026-09-30 minigame hierarchy B5); the player's goal line
## moves up with it so a point still lands at the painted baseline.
const COURT_LIFT := 48.0
## How far below the net line (a fraction of screen height) the player's racket
## can be and still count as crowding the net; past it the enemy plays freely.
const NET_CROWD_ZONE_FRAC := 0.15
## Deepest the enemy may stand while the player's racket is right at the net,
## as a fraction of screen height from the top. It eases out to the enemy's
## normal reach as the player backs off across NET_CROWD_ZONE_FRAC.
const ENEMY_RETREAT_Y_FRAC := 0.14
## The shuttle counts as pinned once it has stayed inside PIN_RADIUS of one
## spot for this long (seconds).
const PIN_SECONDS := 0.5
## How far (px) the shuttle may wander and still count as staying in one spot.
const PIN_RADIUS := 40.0
## Sideways share of a pop-out's direction, aimed at the court's centre line.
const PIN_POP_SIDEWAYS := 0.3
## How far (px) a pop-out nudges the shuttle off the wall it was pinned against.
const PIN_POP_NUDGE := 60.0
## The player's racket stays this far (px) inside the screen edges and the net half.
const PLAYER_EDGE_MARGIN := 50.0
## The enemy racket keeps this far (px) inside the screen's top and side edges.
const ENEMY_EDGE_MARGIN := 80.0
## The enemy's normal forward reach: this far (px) short of the net line.
const ENEMY_NET_MARGIN := 80.0

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
@export_group("Configuration")
## The shuttle's hit circle radius, as a fraction of screen width. Doubled
## from 0.04 with the shuttle's picture on 2026-09-10, so the circle still
## matches the art's box (Puck/Sprite2D's scale sets the picture's size).
@export var puck_radius_frac: float = 0.08

var player_score: int = 0
## True once the player's racket has made its first clean return; the hint
## pill settles to its resting alpha then and never again.
var _hint_settled := false
var enemy_score: int = 0
var target_score: int = 5
## Mirror of player_score under the name BaseMinigame's result card reads.
## Badminton is the only minigame that names its own score `player_score`; the
## card would otherwise hide its score row entirely. Kept in step by
## sync_score_alias() -- never assigned directly.
var score: int = 0
## Mirror of target_score under the name the result card reads.
var max_score: int = 0

@onready var puck: RigidBody2D           = $Puck
@onready var player_paddle: CharacterBody2D = $PlayerPaddle
@onready var enemy_paddle: CharacterBody2D  = $EnemyPaddle

@onready var player_goal: Area2D         = $PlayerGoal
@onready var enemy_goal: Area2D          = $EnemyGoal
@onready var score_hud: MinigameHeader = %MinigameHeader

var is_dragging_player: bool = false
var player_target_pos: Vector2 = Vector2.ZERO
## How close (px, centre to centre) a racket must be to hit the shuttle: the
## racket's circle plus the shuttle's. Set once by _setup_rackets().
var _hit_reach: float = 0.0
## Where the shuttle was when it last moved more than PIN_RADIUS, and for how
## long (s) it has stayed within PIN_RADIUS of there.
var _pin_anchor: Vector2 = Vector2.ZERO
var _pin_time: float = 0.0
var puck_start_pos: Vector2

# ─── Visual nodes ────────────────────────────────────────────────────────────
# These are real nodes in Badminton.tscn, positioned and textured there.
# The @export textures on this script still win at runtime so an artist can
# override the scene's choice from the root's Inspector without opening the
# subtree.
@onready var puck_sprite: ShuttlecockSprite = $Puck/Sprite2D
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
	sync_score_alias()
	last_conceding_side = "player"
	if score_hud:
		score_hud.setup(load("res://Assets/Images/UI/Placeholders/icon_olahraga.svg"), 0)  # "0 - 0" has no target
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
		player_goal.global_position = Vector2(screen_size.x / 2, screen_size.y - 30 - COURT_LIFT)
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
		var col = puck.get_node_or_null("CollisionShape2D")
		if col and col.shape is CircleShape2D:
			col.shape.radius = screen_size.x * puck_radius_frac

	# The paddles' hit circle is authored in the scene -- both share
	# CircleShape2D_paddle -- so resizing it in the 2D editor is what plays.
	# It used to be forced to screen_size.x * 0.06 here, which silently threw
	# away any size set in the editor (2026-09-10).
	if player_paddle:
		player_paddle.global_position = Vector2(screen_size.x / 2, screen_size.y * 0.8)

	if enemy_paddle:
		enemy_paddle.global_position = Vector2(screen_size.x / 2, screen_size.y * 0.2)

	_apply_visual_exports()
	_setup_rackets()
	_remember_racket_poses()

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

var _puck_hit_cooldown: float = 0.0
## Each racket sprite's resting scale and idle art, remembered once in
## _ready() so a squash always returns to them -- never to values read off a
## sprite that is still mid-squash or mid-swap.
var _racket_rest_scale: Dictionary = {}
var _racket_idle_texture: Dictionary = {}
## The running squash per racket sprite, killed before the next one starts.
var _racket_tweens: Dictionary = {}

## Takes both rackets off the physics board and measures how close one must
## be to hit. A racket collides with nothing, so a wall or the shuttle can
## never slow or block it, and the shuttle can never be squeezed between a
## racket and a wall (that squeeze is what once launched it at extreme
## speed). Hits are found by _check_racket_hits() instead. Needs the shuttle's
## radius, so it runs after _ready() has sized the shuttle.
func _setup_rackets() -> void:
	for racket in [player_paddle, enemy_paddle]:
		if racket:
			racket.collision_layer = 0
			racket.collision_mask = 0
	var racket_shape := player_paddle.get_node("CollisionShape2D").shape as CircleShape2D
	var puck_shape := puck.get_node("CollisionShape2D").shape as CircleShape2D
	_hit_reach = racket_shape.radius + puck_shape.radius

## Hits the shuttle for whichever racket has swept within reach of it since
## the last frame. A sweep, not a snapshot: a fast swipe cannot jump clean over
## the shuttle between two frames.
func _check_racket_hits(player_from: Vector2, enemy_from: Vector2) -> void:
	if not puck or is_puck_in_serve or is_scoring_delay or _puck_hit_cooldown > 0.0:
		return
	var sweeps := [[player_paddle, player_from], [enemy_paddle, enemy_from]]
	for sweep in sweeps:
		var racket: CharacterBody2D = sweep[0]
		var closest := Geometry2D.get_closest_point_to_segment(puck.global_position, sweep[1], racket.global_position)
		if closest.distance_to(puck.global_position) <= _hit_reach:
			_hit_puck(racket)
			return

# Racket hit: re-aim the puck, swell the shuttle, turn its cork to lead the
# new flight, and squash the racket that hit it.
func _hit_puck(racket: CharacterBody2D) -> void:
	_puck_hit_cooldown = 0.22 # Prevent multi-hit trigger jitter
	if racket == player_paddle and not _hint_settled:
		_hint_settled = true
		hint_settle()
	# Three racket samples picked at random: a rally is the same action
	# a dozen times in ten seconds, and one sample reads as a metronome.
	AudioDirector.play_sfx_variant(&"racket_hit")
	_redirect_puck_towards_opponent(racket)
	puck_sprite.punch()
	puck_sprite.face(puck.linear_velocity.y)
	_play_racket_squash_animation(racket)

## Counts how long the shuttle has stayed in one spot and, past PIN_SECONDS,
## pops it out gently. A shuttle stuck on a wall or in a corner never ends the
## rally, so the pin is broken for it.
func _watch_for_pin(delta: float) -> void:
	if not puck or is_puck_in_serve or is_scoring_delay or puck.freeze:
		_pin_time = 0.0
		return
	if puck.global_position.distance_to(_pin_anchor) > PIN_RADIUS:
		_pin_anchor = puck.global_position
		_pin_time = 0.0
		return
	_pin_time += delta
	if _pin_time >= PIN_SECONDS:
		_pin_time = 0.0
		_pop_pinned_puck()

## Frees a pinned shuttle: nudges it off the wall towards the centre line and
## sends it, at the slowest legal speed, to the half opposite the one it was
## pinned in -- the pinner's rally continues, the pin does not pay.
func _pop_pinned_puck() -> void:
	var puck_shape := puck.get_node("CollisionShape2D").shape as CircleShape2D
	var inward := 1.0 if puck.global_position.x < screen_size.x / 2.0 else -1.0
	var nudged_x := puck.global_position.x + inward * PIN_POP_NUDGE
	var wall_gap := puck_shape.radius + ENEMY_EDGE_MARGIN
	puck.global_position.x = clampf(nudged_x, wall_gap, screen_size.x - wall_gap)
	puck.linear_velocity = pop_heading(puck.global_position, screen_size) * min_puck_speed
	puck_sprite.face(puck.linear_velocity.y)

## The unit direction a pinned shuttle at `puck_pos` is popped in: up the court
## if it sits in the player's half, down if in the enemy's, leaning a little
## towards the centre line so it leaves the wall it was pinned against.
static func pop_heading(puck_pos: Vector2, screen: Vector2) -> Vector2:
	var inward := 1.0 if puck_pos.x < screen.x / 2.0 else -1.0
	var up_court := -1.0 if puck_pos.y > screen.y / 2.0 else 1.0
	return Vector2(inward * PIN_POP_SIDEWAYS, up_court).normalized()

## The nearest point to `point` that the player's racket may stand on: the
## player's half of the court, inside the screen edges.
func _player_half_point(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, PLAYER_EDGE_MARGIN, screen_size.x - PLAYER_EDGE_MARGIN),
		clampf(point.y, screen_size.y / 2.0 + PLAYER_EDGE_MARGIN, screen_size.y - PLAYER_EDGE_MARGIN))

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

## Remember each racket sprite's resting scale and idle art, once, after the
## @export art has been applied. The idle art is whatever the sprite really
## shows -- the scene's baked texture when the @export is null.
func _remember_racket_poses() -> void:
	for sprite in [player_paddle_sprite, enemy_paddle_sprite]:
		if sprite:
			_racket_rest_scale[sprite] = sprite.scale
			_racket_idle_texture[sprite] = sprite.texture

func _play_racket_squash_animation(racket: CharacterBody2D) -> void:
	if not racket or not is_instance_valid(racket): return
	var sprite: Sprite2D = player_paddle_sprite if racket == player_paddle else enemy_paddle_sprite
	if not _racket_rest_scale.has(sprite):
		return

	# Squash relative to the REMEMBERED rest scale: a racket texture rests at
	# a fractional scale sized to its touch target, and a hit can land while
	# the previous squash is still running.
	var base_scale: Vector2 = _racket_rest_scale[sprite]
	var idle_texture: Texture2D = _racket_idle_texture[sprite]

	var previous: Tween = _racket_tweens.get(sprite)
	if previous and previous.is_valid():
		previous.kill()

	# Swap to the "hit" pose for the duration of the squash.
	if racket_hit_texture:
		sprite.texture = racket_hit_texture

	var tw = create_tween()
	_racket_tweens[sprite] = tw
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sprite, "scale", base_scale * Vector2(1.35, 0.72), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", base_scale * Vector2(0.78, 1.35), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", base_scale, 0.12).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	if racket_hit_texture:
		tw.tween_callback(func():
			if is_instance_valid(sprite):
				sprite.texture = idle_texture
		)

## The deepest line (largest y) the enemy racket may stand on, given where the
## player's racket is. Away from the net it is the enemy's normal reach; as the
## player closes on the net it slides back to ENEMY_RETREAT_Y_FRAC, so the
## enemy keeps its distance instead of crowding the player.
static func enemy_forward_limit(player_y: float, screen_h: float) -> float:
	var net_y := screen_h / 2.0
	var free_y := net_y - ENEMY_NET_MARGIN
	var crowd := 1.0 - clampf((player_y - net_y) / (screen_h * NET_CROWD_ZONE_FRAC), 0.0, 1.0)
	return lerpf(free_y, minf(screen_h * ENEMY_RETREAT_Y_FRAC, free_y), crowd)

## Where the enemy racket heads on y, inside its playable area: the shuttle
## while it is on the enemy's half, else a ready line, never past
## enemy_forward_limit() for where the player's racket is.
func _enemy_target_y() -> float:
	var target_y := puck.global_position.y
	if puck.global_position.y > screen_size.y / 2:
		target_y = screen_size.y * 0.25
	var forward_limit := ENEMY_EDGE_MARGIN
	if player_paddle:
		forward_limit = enemy_forward_limit(player_paddle.global_position.y, screen_size.y)
	return clampf(target_y, ENEMY_EDGE_MARGIN, maxf(forward_limit, ENEMY_EDGE_MARGIN))

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

	# Player Paddle Movement: exactly under the finger, nothing to slow it.
	var player_from := player_paddle.global_position
	var enemy_from := enemy_paddle.global_position
	if is_dragging_player and player_target_pos != Vector2.ZERO:
		player_paddle.global_position = player_target_pos

	# Enemy AI
	if enemy_paddle and puck:
		var target_x = puck.global_position.x
		var target_y = _enemy_target_y()
		target_x = clamp(target_x, ENEMY_EDGE_MARGIN, screen_size.x - ENEMY_EDGE_MARGIN)
		
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

	_check_racket_hits(player_from, enemy_from)

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

	_watch_for_pin(delta)
	_update_trail_and_particles()

func _input(event: InputEvent) -> void:
	if not is_game_active or is_paused:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			# A press anywhere on the player's half picks the racket up under
			# the finger; it used to need a press right on the racket.
			if player_paddle and event.position.y > screen_size.y / 2.0:
				is_dragging_player = true
				player_target_pos = _player_half_point(event.position)
		else:
			is_dragging_player = false
			
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_dragging_player:
			player_target_pos = _player_half_point(event.position)

var is_scoring_delay: bool = false

func _on_player_goal(body: Node2D) -> void:
	if not is_game_active or is_scoring_delay:
		return
	if body == puck:
		is_scoring_delay = true
		enemy_score += 1
		sync_score_alias()
		last_conceding_side = "player"
		_trigger_score_sequence(false)

func _on_enemy_goal(body: Node2D) -> void:
	if not is_game_active or is_scoring_delay:
		return
	if body == puck:
		is_scoring_delay = true
		player_score += 1
		sync_score_alias()
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
		# The cork leads: it faces the receiver before the serve flies.
		puck_sprite.reset_pose(target_vel.y < 0.0)
		
		# One serve at a time -- a second lob tween would fight this one over
		# the body's position and scale.
		if _serve_tween and _serve_tween.is_valid():
			_serve_tween.kill()
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

## The plaque's gold number is the rally score; its bar is the player's
## points toward the goal, and the caption names that goal rather than
## repeating the count (spec 2026-09-30 minigame hierarchy, 5.1). The court
## art sits 48 px higher than the screen (Background offsets, with Surround
## filling the strip below) so its painted baseline clears the hint pill (B5).
func _update_score_ui() -> void:
	if score_hud:
		score_hud.set_label_text("%d - %d" % [enemy_score, player_score])
	set_progress(player_score, target_score, "Capai %d poin" % target_score)

func _check_win_condition() -> void:
	if player_score >= target_score:
		win_game()
	elif enemy_score >= target_score:
		lose_game()

## Republish player_score / target_score under the names BaseMinigame's result
## card reads. Called after every rally point and once before the card shows.
##
## Affects: this node's own `score` and `max_score` mirrors.
func sync_score_alias() -> void:
	score = player_score
	max_score = target_score


## Rally dominance: the share of all points played that the player took. A
## shutout rates 1.0; scraping past the target in a long rally does not.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func _rally_margin_ratio(player_score: int, enemy_score: int) -> float:
	var rallies: int = player_score + enemy_score
	if rallies <= 0:
		return STAR_RATIO_UNKNOWN
	return clampf(float(player_score) / float(rallies), 0.0, 1.0)


## How well the player did this run, delegated to the static helper above.
##
## Affects: nothing. Pure. Read by BaseMinigame._show_result_overlay().
func get_star_ratio() -> float:
	return _rally_margin_ratio(player_score, enemy_score)


func win_game() -> void:
	sync_score_alias()
	_freeze_puck()
	super.win_game()

## Ends the match as a loss. Replaces BaseMinigame.lose_game(), whose
## score-versus-get_target_win_score() shortcut (a target of 1 to 3) would
## promote a 1-5 rally loss to a win. Mirrors LombaMenari's and MainBola's.
func lose_game() -> void:
	sync_score_alias()
	_freeze_puck()
	if not is_game_active:
		return
	is_game_active = false
	process_mode = Node.PROCESS_MODE_INHERIT
	var strip := header()
	if strip != null:
		strip.set_pause_enabled(false)
	if timer:
		timer.stop()
	set_process_input(false)
	# The base version's beat before the card: the last rally lands first.
	await get_tree().create_timer(LOSS_CARD_DELAY).timeout
	_show_result_overlay(false, result_subtitle)

## Stops the puck dead, deferred because it may be mid physics callback.
func _freeze_puck() -> void:
	if puck:
		puck.set_deferred("freeze", true)
		puck.set_deferred("linear_velocity", Vector2.ZERO)
		puck.set_deferred("angular_velocity", 0.0)

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
