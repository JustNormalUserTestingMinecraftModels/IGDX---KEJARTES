@tool
extends Control
class_name DancerRig

## The dance minigame's character, as two layers rather than one sprite.
##
## The body swaps between three poses and mirrors for the left-hand
## arrows; the head is a single texture that never swaps and never
## mirrors, so her face and hairclip stay fixed while the body dances.
##
## Both layers draw the same 1280x1280 source canvas into the same rect
## with STRETCH_KEEP_ASPECT_CENTERED, so they align at zero offset. The
## head then shifts by head_offset_ratio, which was solved by
## compositing dance_head over dance_body_idle and minimising per-pixel
## difference against dance_mockup.png -- not eyeballed. All three body
## poses put the neck within a few pixels of the same spot, so one
## offset serves every pose.
##
## @tool, so the composite previews in the editor viewport. Nothing in
## _ready() has a side effect outside this rig's own children.

## The body's three poses. SIDE covers both side arrows and UP covers
## both diagonal-up arrows; direction comes from the `flipped` argument
## rather than from a pose of its own.
enum Pose { IDLE, SIDE, UP }

@export_group("Art")
## Body at rest, between notes.
@export var body_idle_texture: Texture2D = preload("res://Assets/Images/Textures/dance_body_idle.png")
## Body with one arm thrown out sideways. Used for LEFT and RIGHT.
@export var body_side_texture: Texture2D = preload("res://Assets/Images/Textures/dance_body_side.png")
## Body with arms crossed upward. Used for TOP_LEFT and TOP_RIGHT.
@export var body_up_texture: Texture2D = preload("res://Assets/Images/Textures/dance_body_up.png")
## The head layer. One texture for every pose, and it never mirrors.
@export var head_texture: Texture2D = preload("res://Assets/Images/Textures/dance_head.png")

@export_group("Layout")
## Where the head sits relative to the body, as a fraction of the drawn
## square. Solved against dance_mockup.png as (+2, +28) px on the
## sprites' own 1280 canvas. Change this only against a new mockup.
@export var head_offset_ratio: Vector2 = Vector2(2.0 / 1280.0, 28.0 / 1280.0):
	set(value):
		head_offset_ratio = value
		_place_head()

@export_group("State")
## Tint applied by set_failed(). Red enough to read as a miss over the
## stage background without hiding the pose underneath it.
@export var fail_tint: Color = Color(1.0, 0.45, 0.45, 1.0)

@onready var body: TextureRect = $Body
@onready var head: TextureRect = $Head


func _ready() -> void:
	_place_head()
	set_pose(Pose.IDLE, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_head()


## Shows one pose, optionally mirrored. `flipped` mirrors the BODY only:
## the head is deliberately excluded so her face does not swap sides
## every time a left-hand arrow comes up.
func set_pose(pose: Pose, flipped: bool) -> void:
	var body_rect := _body_rect()
	if body_rect == null:
		return
	match pose:
		Pose.SIDE:
			body_rect.texture = body_side_texture
		Pose.UP:
			body_rect.texture = body_up_texture
		_:
			body_rect.texture = body_idle_texture
	body_rect.flip_h = flipped


## Tints the whole rig for a missed note, or clears the tint. The shake
## and droop motion stays with the caller -- this only says "missed".
func set_failed(on: bool) -> void:
	modulate = fail_tint if on else Color.WHITE


## Offsets the head against the drawn square. With
## STRETCH_KEEP_ASPECT_CENTERED and a square source, the drawn image is
## min(width, height) on both axes regardless of the rect's own aspect,
## so that is what the ratio scales against -- not the rect.
func _place_head() -> void:
	var head_rect := _head_rect()
	if head_rect == null:
		return
	var drawn_square: float = minf(size.x, size.y)
	head_rect.position = head_offset_ratio * drawn_square


## The @onready vars are null until this rig enters the tree, and both
## the head-offset setter and the tests reach in before that. These two
## helpers fall back to a live lookup so neither case has to care.
func _body_rect() -> TextureRect:
	if body == null:
		body = get_node_or_null("Body") as TextureRect
	return body


func _head_rect() -> TextureRect:
	if head == null:
		head = get_node_or_null("Head") as TextureRect
	return head
