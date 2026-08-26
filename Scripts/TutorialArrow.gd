# res://Scripts/TutorialArrow.gd
extends Control

var visual_arrow: TextureRect
var bounce_tween: Tween

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create visual TextureRect child
	visual_arrow = TextureRect.new()
	visual_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual_arrow.texture = preload("res://Assets/Images/UI/Placeholders/arrow.png")
	
	# Set size
	var arrow_size := Vector2(320, 320)
	visual_arrow.size = arrow_size
	# Center the bottom point at (0, 0) of the parent Control
	visual_arrow.position = Vector2(-arrow_size.x / 2.0, -arrow_size.y)
	visual_arrow.pivot_offset = Vector2(arrow_size.x / 2.0, arrow_size.y)
	
	add_child(visual_arrow)
	
	_start_bounce()

var _pointing_up := false

func set_direction(pointing_up: bool) -> void:
	if _pointing_up == pointing_up:
		return
	_pointing_up = pointing_up
	if _pointing_up:
		visual_arrow.rotation_degrees = 180.0
	else:
		visual_arrow.rotation_degrees = 0.0
	_start_bounce()

func _start_bounce():
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
	bounce_tween = create_tween().set_loops()
	bounce_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Bounce visual_arrow up and down by 50 pixels
	var start_pos = visual_arrow.position
	var bounce_offset = Vector2(0, 50) if _pointing_up else Vector2(0, -50)
	bounce_tween.tween_property(visual_arrow, "position", start_pos + bounce_offset, 0.45)
	bounce_tween.tween_property(visual_arrow, "position", start_pos, 0.45)
