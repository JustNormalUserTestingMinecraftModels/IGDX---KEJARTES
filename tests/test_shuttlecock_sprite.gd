@tool
extends McpTestSuite

## ShuttlecockSprite owns the badminton shuttle's look. The rule under test:
## every animation returns to a REMEMBERED pose, never one read back off the
## live node -- the old hit punch did the latter, so overlapping hits grew
## the shuttle without limit (2026-09-10).
##
## Tweens are driven with Tween.custom_step(), diffed against a snapshot of
## the tree's processed tweens (the technique from test_juice.gd): the runner
## calls each test synchronously, so nothing here may await. Methods go
## through call() so the suite parses even before the class_name is
## registered. Must be @tool.

func suite_name() -> String:
	return "shuttlecock_sprite"

const _SCRIPT := preload("res://Scripts/Minigames/Olahraga/ShuttlecockSprite.gd")
## A non-uniform rest scale, like the scene's, so no test passes by accident
## on Vector2.ONE.
const _REST := Vector2(0.14, 0.1)
## The authored cork-up angle, as Badminton.tscn gives it.
const _UP := 90.0

var _sprite: Sprite2D


func setup() -> void:
	_sprite = Sprite2D.new()
	_sprite.set_script(_SCRIPT)
	_sprite.scale = _REST
	_sprite.rotation_degrees = _UP
	Engine.get_main_loop().root.add_child(_sprite)
	track(_sprite)


func teardown() -> void:
	_sprite = null


## Fast-forward every live tween the tree picked up since `snapshot`.
func _step(snapshot: Array, seconds: float) -> void:
	for tw in Engine.get_main_loop().get_processed_tweens():
		if not snapshot.has(tw) and is_instance_valid(tw) and tw.is_valid():
			tw.custom_step(seconds)


## Rotation folded into [0, 360), so turns that accumulate compare cleanly.
func _facing() -> float:
	return fposmod(_sprite.rotation_degrees, 360.0)


func test_the_authored_pose_is_the_rest_pose() -> void:
	assert_true((_sprite.call("rest_scale") as Vector2).is_equal_approx(_REST),
		"the scene's scale is the rest scale")
	assert_true(_sprite.call("is_cork_up"), "the scene's rotation is the cork-up pose")


func test_a_punch_swells_before_it_settles() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("punch")
	_step(snap, 0.26)
	assert_true(_sprite.scale.x > _REST.x * 1.5,
		"the punch must visibly swell the shuttle, got %s" % _sprite.scale)
	_step(snap, 1.0)
	assert_true(_sprite.scale.is_equal_approx(_REST),
		"a single punch must settle back at the rest scale, got %s" % _sprite.scale)


func test_overlapping_punches_settle_back_to_the_rest_scale() -> void:
	# Each hit lands mid-punch, as the 0.22s hit cooldown allows against a
	# 0.52s punch. Reading the live scale as the base would ratchet upward.
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	for i in range(5):
		_sprite.call("punch")
		_step(snap, 0.1)
	_step(snap, 2.0)
	assert_true(_sprite.scale.is_equal_approx(_REST),
		"five overlapping punches must settle at the rest scale, got %s" % _sprite.scale)


func test_face_turns_only_when_the_direction_changes() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("face", -500.0)
	_step(snap, 1.0)
	assert_true(is_equal_approx(_facing(), _UP), "still flying up must keep the cork up")
	_sprite.call("face", 500.0)
	_step(snap, 1.0)
	assert_true(is_equal_approx(_facing(), _UP + 180.0),
		"flying down must turn the cork down, got %f" % _sprite.rotation_degrees)
	assert_false(_sprite.call("is_cork_up"), "the sprite must know its cork is down")


func test_an_interrupted_turn_still_lands_exactly() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("face", 500.0)
	_step(snap, 0.05)
	_sprite.call("face", -500.0)
	_step(snap, 1.0)
	assert_true(is_equal_approx(_facing(), _UP),
		"two turns must land back on cork-up exactly, got %f" % _sprite.rotation_degrees)


func test_reset_pose_snaps_to_rest_with_the_cork_either_way() -> void:
	var snap: Array = Engine.get_main_loop().get_processed_tweens()
	_sprite.call("punch")
	_sprite.call("face", 500.0)
	_step(snap, 0.1)
	_sprite.call("reset_pose", false)
	assert_true(_sprite.scale.is_equal_approx(_REST), "a serve starts at the rest scale")
	assert_true(is_equal_approx(_facing(), _UP + 180.0), "a serve toward the player starts cork-down")
	_step(snap, 2.0)
	assert_true(_sprite.scale.is_equal_approx(_REST), "no stale punch may resume after a reset")
	assert_true(is_equal_approx(_facing(), _UP + 180.0), "no stale turn may resume after a reset")
	_sprite.call("reset_pose", true)
	assert_true(is_equal_approx(_facing(), _UP), "a serve toward the enemy starts cork-up")
