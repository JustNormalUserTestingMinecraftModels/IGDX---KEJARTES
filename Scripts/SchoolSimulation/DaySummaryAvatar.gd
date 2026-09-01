@tool
extends Panel
class_name DaySummaryAvatar

## The Daily Results card's profile image: a rounded violet frame that
## clips a head-and-shoulders crop out of the student's portrait, falling
## back to their full-body splash art when no portrait is set (see
## set_student for the exact resolution order).
##
## The crop is per-student and cannot be derived from a shared rule --
## the figures differ in height, pose and framing within a common
## 1080x1920 canvas. See the 2026-09-01 spec, section 3.

## Frame size in game pixels, measured off the mockup.
const FRAME_SIZE := Vector2(269, 286)
const FRAME_ASPECT := FRAME_SIZE.x / FRAME_SIZE.y

## Head-and-shoulders window into each splash, in that splash's own
## pixels. Each is FRAME_ASPECT-shaped so nothing stretches. Derived from
## the 2026-09-01 batch's content bounding boxes: head band taken as the
## top 18% of the figure, crop height 42% of figure height, centred on the
## head and lifted 1% above the crown so hair is not clipped. See the
## spec, section 3 -- adjust here, not by scaling the TextureRect.
const SPLASH_CROP := {
	"Marcel": Rect2(132, 40, 736, 782),
	"Doni": Rect2(192, 125, 702, 746),
	"Andi": Rect2(112, 0, 752, 800),
	"Citra": Rect2(167, 65, 726, 772),
	"Shinta": Rect2(160, 111, 707, 752),
	"Thea": Rect2(154, 86, 718, 763),
}

@onready var art: TextureRect = $Art


## Falls back for any student with no entry in SPLASH_CROP, and for every
## student when the texture is a portrait rather than a splash: the named
## rects are windows into 1080x1920 full-body art and cut the wrong region
## out of anything else. Takes the full width and the top FRAME_ASPECT-worth
## of rows, which frames a head without knowing anything about the pose.
static func crop_for(student_name: String, tex: Texture2D, is_splash: bool = false) -> Rect2:
	if is_splash and SPLASH_CROP.has(student_name):
		return SPLASH_CROP[student_name]
	if tex == null:
		return Rect2()
	var w := float(tex.get_width())
	var h := minf(float(tex.get_height()), w / FRAME_ASPECT)
	return Rect2(0.0, 0.0, h * FRAME_ASPECT, h)


## Resolution order: the student's splash art first, then their portrait,
## then nothing. The splash leads now that the 2026-09-01 batch has landed
## -- it is full-body art cropped to a head window by SPLASH_CROP, which
## frames better than the square portrait.
func set_student(student: StudentData) -> void:
	if student == null:
		art.texture = null
		return

	var tex: Texture2D = null
	var is_splash := false
	if student.splash_path != "" and ResourceLoader.exists(student.splash_path):
		tex = load(student.splash_path)
		is_splash = true
	elif student.avatar_texture != null:
		tex = student.avatar_texture

	if tex == null:
		art.texture = null
		return

	var region := crop_for(student.student_name, tex, is_splash)
	if region.size.x <= 0.0:
		art.texture = tex
		return

	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	art.texture = atlas
