@tool
extends McpTestSuiteCompat

## Badminton's art must be visible in the 2D viewport, not conjured in
## _ready(). The scene ships three ColorRect placeholders that the script used
## to hide and replace with runtime Sprite2Ds -- meaning a human opening the
## scene saw rectangles and could not position the rackets.
##
## Affects nothing at runtime. Scene-file text scan plus one instantiation.
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "badminton_visuals"


const SCENE_PATH := "res://Scenes/Minigames/Olahraga/Badminton.tscn"


func test_every_moving_piece_has_a_sprite_node_in_the_scene() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	for path in ["Puck/Sprite2D", "PlayerPaddle/Sprite2D", "EnemyPaddle/Sprite2D"]:
		var sprite := root.get_node_or_null(path) as Sprite2D
		assert_not_null(sprite, "missing scene node: %s" % path)
		assert_not_null(sprite.texture,
			"%s has no texture -- the scene should supply it, not _ready()" % path)


func test_the_script_no_longer_creates_sprites_at_runtime() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Olahraga/Badminton.gd")
	assert_false(src.contains("Sprite2D.new("),
		"Badminton.gd still builds sprites in code")


func test_placeholder_colorrects_are_gone_from_the_scene() -> void:
	# They existed only as a stand-in before there was art. Leaving them in
	# means the next person edits the wrong node.
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for parent in ["Puck", "PlayerPaddle", "EnemyPaddle"]:
		assert_false(
			text.contains('[node name="ColorRect" type="ColorRect" parent="%s"' % parent),
			"%s still carries the placeholder ColorRect" % parent)


func test_textures_still_come_from_exports_on_the_root() -> void:
	# The Inspector drag-and-drop path must survive the refactor: an artist
	# swaps raket_1.png on the root, and both the scene sprite and the hit
	# animation follow.
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for export_name in ["shuttlecock_texture", "player_racket_texture",
			"enemy_racket_texture", "racket_hit_texture"]:
		assert_contains(text, export_name,
			"%s is no longer assigned in the scene" % export_name)


const SCRIPT_PATH := "res://Scripts/Minigames/Olahraga/Badminton.gd"
## puck.png is a 1240x1754 canvas; the old scale drew it in an 86.4px box,
## the hit circle's diameter. Doubled on 2026-09-10.
const _PUCK_SCALE := Vector2(0.1393548, 0.0985176)


func test_the_puck_is_twice_its_old_size() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var sprite := root.get_node("Puck/Sprite2D") as Sprite2D
	assert_true(sprite.scale.is_equal_approx(_PUCK_SCALE),
		"Puck/Sprite2D should be drawn at 2x its old scale, got %s" % sprite.scale)
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_contains(src, "@export var puck_radius_frac: float = 0.08",
		"the hit circle doubles with the picture, as an Inspector knob")
	assert_false(src.contains("screen_size.x * 0.04"), "the old literal hit radius must be gone")


func test_the_shuttle_stands_cork_up_in_the_scene() -> void:
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var sprite := root.get_node("Puck/Sprite2D") as Sprite2D
	assert_true(is_equal_approx(sprite.rotation_degrees, 90.0),
		"puck.png draws the cork on the left; 90 degrees clockwise stands it up")
	assert_eq(sprite.get_script().resource_path,
		"res://Scripts/Minigames/Olahraga/ShuttlecockSprite.gd",
		"the shuttle's look is owned by ShuttlecockSprite.gd")


func test_hits_drive_the_shuttle_rather_than_flipping_it() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("flip_v"),
		"flip_v mirrors a sideways shuttle invisibly; the cork turns instead")
	assert_false(src.contains("var base_scale: Vector2 = puck_sprite.scale"),
		"reading the live, mid-punch scale as the base is what grew the puck")
	assert_contains(src, "puck_sprite.punch()", "a hit swells the shuttle through ShuttlecockSprite")
	assert_contains(src, "puck_sprite.face(puck.linear_velocity.y)",
		"a hit turns the cork to lead the new flight")
	assert_contains(src, "puck_sprite.reset_pose(target_vel.y < 0.0)",
		"a serve snaps the cork toward the receiver")


func test_the_racket_squash_returns_to_remembered_values() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("var base_scale: Vector2 = sprite.scale"),
		"the racket squash must not read its rest scale off a mid-squash sprite")
	assert_false(src.contains("var idle_texture: Texture2D = sprite.texture"),
		"the racket must not capture its idle art mid-swap")
	assert_contains(src, "_racket_rest_scale", "each racket's rest scale is stored once")
	assert_contains(src, "_racket_idle_texture", "each racket's idle art is stored once")


func test_the_paddles_match_and_their_hit_circle_is_authored_in_the_scene() -> void:
	# Both paddles share one CircleShape2D, so resizing it in the 2D editor
	# resizes both. The script used to force it to screen_size.x * 0.06 at
	# startup, which threw that size away (2026-09-10).
	var root: Node = load(SCENE_PATH).instantiate()
	track(root)
	var player_col := root.get_node("PlayerPaddle/CollisionShape2D") as CollisionShape2D
	var enemy_col := root.get_node("EnemyPaddle/CollisionShape2D") as CollisionShape2D
	assert_true(player_col.shape == enemy_col.shape, "both paddles must share one hit circle")
	var player_sprite := root.get_node("PlayerPaddle/Sprite2D") as Sprite2D
	var enemy_sprite := root.get_node("EnemyPaddle/Sprite2D") as Sprite2D
	assert_true(player_sprite.scale.is_equal_approx(enemy_sprite.scale),
		"the rackets must be drawn at the same size, got %s vs %s" % [player_sprite.scale, enemy_sprite.scale])
	assert_true(player_sprite.position.is_equal_approx(enemy_sprite.position),
		"the rackets must sit over their circles the same way, got %s vs %s"
			% [player_sprite.position, enemy_sprite.position])
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("col.shape.radius = screen_size.x * 0.06"),
		"the script must not override the paddle circle authored in the scene")
