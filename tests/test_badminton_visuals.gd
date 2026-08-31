@tool
extends McpTestSuite

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
