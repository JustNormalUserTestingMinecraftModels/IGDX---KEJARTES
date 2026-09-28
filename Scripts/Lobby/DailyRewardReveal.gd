@tool
class_name DailyRewardReveal
extends Control

## The daily-login claim moment: a prize box at the panel's centre crouches,
## springs (flipping its lid when it is a chest), bursts into a fan of coins
## and stars under a firework and a turning shine, and sends one coin
## arcing to the wallet. It shows only while it plays.
##
## Signals up, calls down: DailyLoginPanel calls show_ready() / play() /
## skip(), and this announces burst_started (the panel counts the amount
## up) and coin_landed (the panel pays out, so the Lobby's wallet rolls the
## moment the coin arrives). Every play() emits each signal exactly once,
## even when skip() cuts it short or reduce_motion drops the motion.
##
## Every position, size and burst placement is authored in
## DailyRewardReveal.tscn; the fan's coins and stars are instanced from the
## coin_template / star_template scenes because their count is per call.
## The gift is the fallback art (use_chest_sprite = false): Box shows the
## day-1 slot's gift and Lid stays hidden, so missing chest art never
## blocks the reveal.
##
## @tool only so the Lobby's and this component's suites can instance it
## in the editor. _ready is gated behind Engine.is_editor_hint(), and the
## writers (show_ready, play, skip) run only from the non-@tool Lobby at
## runtime, so no pose is baked into a saved scene.

## The box burst open: the reward row may pop and count up now.
signal burst_started
## The flying coin reached the wallet: the claim may pay out now.
signal coin_landed

## Show the chest (chest_base_texture + chest_lid_texture) instead of the
## gift fallback authored on Box.
@export var use_chest_sprite: bool = false
## The chest body, shown on Box when use_chest_sprite is on.
@export var chest_base_texture: Texture2D
## The chest lid, shown on Lid when use_chest_sprite is on.
@export var chest_lid_texture: Texture2D
## One fanned coin (RevealCoin.tscn), instanced per burst.
@export var coin_template: PackedScene
## One fanned star (RevealStar.tscn), instanced per burst.
@export var star_template: PackedScene

@export_group("Burst")
## Coins fanned out of the box on an ordinary day.
@export var coin_count: int = 14
## Stars fanned out of the box on an ordinary day.
@export var star_count: int = 6
## On the last streak day, coin_count and star_count are scaled by this,
## and the whole firework volley fires instead of the first burst.
@export var peak_count_multiplier: float = 1.5
## Distance (px) from the box centre to the outer ring of the fan.
@export var fan_radius: float = 230.0
## The inner ring's distance, as a fraction of fan_radius; every other
## piece lands on it so the fan reads as a spray, not a single line.
@export var fan_inner_ratio: float = 0.65
## Width of the fan (degrees), centred straight up.
@export var fan_arc_degrees: float = 170.0
## How high (px) above the straight path each piece hops on its way out.
@export var fan_hop_height: float = 90.0
## Box squash at the bottom of the crouch (x wide, y short).
@export var crouch_scale: Vector2 = Vector2(1.15, 0.8)
## How far (degrees) the chest lid swings open. Chest art only.
@export var lid_open_degrees: float = -35.0

@export_group("Timing")
## Seconds the box takes to squash down before it springs.
@export var crouch_seconds: float = 0.18
## Seconds the box takes to spring back to full size.
@export var release_seconds: float = 0.22
## Seconds the chest lid takes to swing open. Chest art only.
@export var lid_seconds: float = 0.25
## Seconds each piece takes to hop from the box to its place in the fan.
@export var fan_seconds: float = 0.45
## Delay (s) between one fanned piece leaving and the next.
@export var fan_stagger_seconds: float = 0.015
## Seconds the shine takes to fade in behind the box.
@export var shine_fade_seconds: float = 0.2
## Seconds of the shine's one full turn; the fan settles meanwhile, then
## the wallet coin flies.
@export var shine_turn_seconds: float = 1.0
## Seconds the coin takes to arc from the box to the wallet.
@export var wallet_arc_seconds: float = 0.55
## How high (px) the wallet coin's arc bows above the straight line.
@export var wallet_arc_height: float = 260.0
## Seconds the reveal lingers after the coin lands, before it hides.
@export var linger_seconds: float = 0.15
@export_group("")

@onready var shine: TextureRect = %Shine
@onready var box: TextureRect = %Box
@onready var lid: TextureRect = %Lid
@onready var fireworks: ConfettiFireworks = %Fireworks
@onready var coins: Control = %Coins
@onready var stars: Control = %Stars
@onready var wallet_coin: TextureRect = %WalletCoin

var _sequence: Tween
var _volley: Tween
var _burst_pending: bool = false
var _landing_pending: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	show_ready()


## Resets every piece to its closed, at-rest pose and hides the reveal: it
## only shows while play() runs.
func show_ready() -> void:
	_stop_tweens()
	_clear_fan()
	visible = false
	box.scale = Vector2.ONE
	if use_chest_sprite:
		box.texture = chest_base_texture
		lid.texture = chest_lid_texture
	lid.visible = use_chest_sprite
	lid.rotation = 0.0
	shine.modulate.a = 0.0
	shine.rotation = 0.0
	wallet_coin.visible = false
	for holder: Control in [coins, stars]:
		holder.modulate.a = 1.0


## Plays the whole claim moment. `is_peak` is the last streak day (a bigger
## fan and the full firework volley); `wallet_position` is the global point
## the coin flies to.
func play(is_peak: bool, wallet_position: Vector2) -> void:
	skip()
	_burst_pending = true
	_landing_pending = true
	if GameSettings.reduce_motion or not _has_templates():
		skip()
		return
	visible = true
	_sequence = create_tween()
	_crouch(_sequence)
	_release(_sequence)
	_flip_lid(_sequence)
	_sequence.tween_callback(_burst.bind(is_peak))
	_spin_shine(_sequence)
	_fly_to_wallet(_sequence, wallet_position)
	_sequence.tween_interval(linger_seconds)
	_sequence.tween_callback(_end_play)


## The sequence's last step. It drops its own handle first, so show_ready
## does not kill the tween from inside that tween's callback.
func _end_play() -> void:
	_sequence = null
	show_ready()


## Cuts the reveal short: stops every tween, emits whichever of
## burst_started / coin_landed is still owed (each exactly once) and hides.
func skip() -> void:
	_emit_burst_started()
	_land()
	show_ready()


func _has_templates() -> bool:
	if coin_template == null or star_template == null:
		push_error("DailyRewardReveal: coin_template / star_template are not wired in the scene")
		return false
	return true


## The box squashes down from its base, winding up.
func _crouch(tween: Tween) -> void:
	box.pivot_offset = Vector2(box.size.x * 0.5, box.size.y)
	tween.tween_property(box, "scale", crouch_scale, crouch_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## ...and springs back up, overshooting.
func _release(tween: Tween) -> void:
	tween.tween_property(box, "scale", Vector2.ONE, release_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The chest lid swings open with the spring. The gift fallback has no lid.
func _flip_lid(tween: Tween) -> void:
	if not use_chest_sprite:
		return
	tween.parallel().tween_property(lid, "rotation", deg_to_rad(lid_open_degrees), lid_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The burst itself: announce it, set the fireworks off and fan the pieces.
func _burst(is_peak: bool) -> void:
	_emit_burst_started()
	_fire_fireworks(is_peak)
	_fan_out(coin_template, _count_for(coin_count, is_peak), coins)
	_fan_out(star_template, _count_for(star_count, is_peak), stars)


## The shine fades in behind the box and makes one slow turn while the fan
## settles; the next step waits for the turn.
func _spin_shine(tween: Tween) -> void:
	Juice.set_pivot_center(shine)
	tween.tween_property(shine, "modulate:a", 1.0, shine_fade_seconds)
	tween.parallel().tween_property(shine, "rotation", TAU, shine_turn_seconds).from(0.0)


## One coin arcs from the box to the wallet while the shine and the fan
## fade; coin_landed goes out as it arrives.
func _fly_to_wallet(tween: Tween, wallet_position: Vector2) -> void:
	tween.tween_callback(_launch_wallet_coin.bind(wallet_position))
	tween.tween_method(_place_wallet_coin.bind(wallet_position), 0.0, 1.0,
		wallet_arc_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for faded: CanvasItem in [shine, coins, stars]:
		tween.parallel().tween_property(faded, "modulate:a", 0.0, wallet_arc_seconds)
	tween.tween_callback(wallet_coin.hide)
	tween.tween_callback(_land)


## Instances `count` pieces of `template` into `holder` at the box centre
## and hops each out to its place in the fan, landing with a squash. The
## pieces are freed when the reveal hides.
func _fan_out(template: PackedScene, count: int, holder: Control) -> void:
	var origin: Vector2 = _box_centre_in(holder)
	for index: int in count:
		var piece: Control = template.instantiate() as Control
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(piece)
		var half_size: Vector2 = piece.size * 0.5
		var from: Vector2 = origin - half_size
		var to: Vector2 = from + _fan_offset(index, count)
		var bend: Vector2 = from.lerp(to, 0.5) + Vector2.UP * fan_hop_height
		piece.position = from
		var hop: Tween = piece.create_tween()
		hop.tween_interval(fan_stagger_seconds * float(index))
		hop.tween_method(_place_piece.bind(piece, from, bend, to), 0.0, 1.0, fan_seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_callback(AnimUtils.squash_bounce.bind(piece))


## Where piece `index` of `count` lands, relative to the box centre: spread
## evenly across fan_arc_degrees around straight up, alternating between
## the outer and the inner ring.
func _fan_offset(index: int, count: int) -> Vector2:
	var progress: float = 0.5 if count < 2 else float(index) / float(count - 1)
	var angle: float = -PI * 0.5 + deg_to_rad(fan_arc_degrees) * (progress - 0.5)
	var radius: float = fan_radius if index % 2 == 0 else fan_radius * fan_inner_ratio
	return Vector2.from_angle(angle) * radius


## The first firework, or the whole volley (burst_delay apart) on the peak.
func _fire_fireworks(is_peak: bool) -> void:
	if not is_peak:
		fireworks.fire_burst(0)
		return
	_volley = create_tween()
	for index: int in fireworks.burst_count():
		_volley.tween_callback(fireworks.fire_burst.bind(index))
		_volley.tween_interval(fireworks.burst_delay)


func _count_for(count: int, is_peak: bool) -> int:
	return roundi(float(count) * peak_count_multiplier) if is_peak else count


## The box's centre in `holder`'s own coordinates.
func _box_centre_in(holder: Control) -> Vector2:
	return holder.get_global_transform().affine_inverse() * box.get_global_rect().get_center()


## A point `t` (0..1) along the quadratic curve from `from` via `bend` to `to`.
static func _arc_point(t: float, from: Vector2, bend: Vector2, to: Vector2) -> Vector2:
	return from.lerp(bend, t).lerp(bend.lerp(to, t), t)


func _place_piece(t: float, piece: Control, from: Vector2, bend: Vector2, to: Vector2) -> void:
	piece.position = _arc_point(t, from, bend, to)


func _launch_wallet_coin(wallet_position: Vector2) -> void:
	_place_wallet_coin(0.0, wallet_position)
	wallet_coin.show()


## WalletCoin is top_level, so its position is in canvas space, as are
## the box's global rect and `to`; the coin is centred on the curve. The
## start is read from the box every frame, so the arc stays true while the
## panel itself is still popping in.
func _place_wallet_coin(t: float, to: Vector2) -> void:
	var from: Vector2 = box.get_global_rect().get_center()
	var bend: Vector2 = from.lerp(to, 0.5) + Vector2.UP * wallet_arc_height
	wallet_coin.global_position = _arc_point(t, from, bend, to) - wallet_coin.size * 0.5


func _emit_burst_started() -> void:
	if not _burst_pending:
		return
	_burst_pending = false
	burst_started.emit()


func _land() -> void:
	if not _landing_pending:
		return
	_landing_pending = false
	coin_landed.emit()


func _stop_tweens() -> void:
	for tween: Tween in [_sequence, _volley]:
		if tween != null:
			tween.kill()
	_sequence = null
	_volley = null


## Frees every fanned piece; a piece's own hop tween dies with it.
func _clear_fan() -> void:
	for holder: Control in [coins, stars]:
		for piece: Node in holder.get_children():
			piece.queue_free()
