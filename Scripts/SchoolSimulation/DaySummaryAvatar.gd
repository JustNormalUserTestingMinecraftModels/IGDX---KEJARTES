@tool
extends Panel
class_name DaySummaryAvatar

## The Daily Results card's profile image: a rounded violet frame that
## clips a head-and-shoulders crop out of the student's full-body splash.
##
## The crop is per-student and cannot be derived from a shared rule --
## the splash batch does not share a canvas (Thea's is 550x1119, the
## others 1080x1920) and splash_andi.png carries a sliver of a second
## figure baked into its right edge. See the spec, section 3.

## Frame size in game pixels, measured off the mockup.
const FRAME_SIZE := Vector2(269, 286)
const FRAME_ASPECT := FRAME_SIZE.x / FRAME_SIZE.y

## Head-and-shoulders window into each splash, in that splash's own
## pixels. Each is FRAME_ASPECT-shaped so nothing stretches. Values were
## derived from the content bounding boxes in the spec and confirmed
## visually in Task 9 -- adjust here, not by scaling the TextureRect.
const SPLASH_CROP := {
	"Marcel": Rect2(202, 40, 752, 800),
	"Andi": Rect2(224, 45, 752, 800),
	"Shinta": Rect2(210, 100, 752, 800),
	"Thea": Rect2(99, 0, 442, 470),
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


## Resolution order: the student's portrait first, then their splash art,
## then nothing. The portrait leads because the splash batch is being
## replaced -- flip these two branches back once the new art lands.
func set_student(student: StudentData) -> void:
	if student == null:
		art.texture = null
		return

	var tex: Texture2D = null
	var is_splash := false
	if student.avatar_texture != null:
		tex = student.avatar_texture
	elif student.splash_path != "" and ResourceLoader.exists(student.splash_path):
		tex = load(student.splash_path)
		is_splash = true

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
