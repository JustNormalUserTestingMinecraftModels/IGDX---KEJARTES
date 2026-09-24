@tool
class_name AvatarChip
extends VBoxContainer

## One student on the SchoolDay avatar strip (2026-09-24 liveliness pass,
## layer 5): their face in a round frame inside two rings -- energy outside,
## mood inside -- and their name beneath. It replaced the full-width status
## cards, which were built at runtime and crowded the screen; the strip
## scrolls sideways, so any roster size fits.
##
## The rings sweep as energy and mood change through the day, and the chip
## squash-springs with a floating "+N" when the student gains a skill point.
## Full per-student numbers live in the daily result popup, not here.

## How far the chip's floating "+N" rises from, relative to the rings'
## top-centre, in px. The chip's Headroom node above the rings gives the
## rise room inside the strip, which clips anything above its own top.
const GAIN_TEXT_OFFSET := Vector2(0, -8)

@onready var _energy_ring: TextureProgressBar = $Rings/EnergyRing
@onready var _mood_ring: TextureProgressBar = $Rings/MoodRing
@onready var _face: TextureRect = $Rings/Disc/Face
@onready var _name: Label = $NamePill/NameLabel
@onready var _rings: Control = $Rings


func _ready() -> void:
	var tokens := DesignTokens.load_default()
	if _energy_ring:
		_energy_ring.tint_progress = tokens.category_color_on_dark("Energy")
	if _mood_ring:
		_mood_ring.tint_progress = tokens.category_color_on_dark("Mood")


## Fills the chip for `student`: face, name, and both rings at their
## current values, with no animation.
func setup(student: StudentData) -> void:
	if student == null:
		return
	if _name:
		_name.text = student.student_name
	if _face:
		_face.texture = face_texture_for(student)
	set_needs(student.energy, student.mood)


## The student's head-and-shoulders crop -- the same window the daily
## result card uses (DaySummaryAvatar.crop_for), so the two agree.
static func face_texture_for(student: StudentData) -> Texture2D:
	var tex: Texture2D = null
	var is_splash := false
	if student.splash_path != "" and ResourceLoader.exists(student.splash_path):
		tex = load(student.splash_path)
		is_splash = true
	elif student.avatar_texture != null:
		tex = student.avatar_texture
	if tex == null:
		return null
	var region := DaySummaryAvatar.crop_for(student.student_name, tex, is_splash)
	if region.size.x <= 0.0:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	return atlas


## Sets both rings at once, 0-100.
func set_needs(energy: float, mood: float) -> void:
	if _energy_ring:
		_energy_ring.value = energy
	if _mood_ring:
		_mood_ring.value = mood


## Energy and mood as the rings show them now.
func needs() -> Vector2:
	return Vector2(_energy_ring.value if _energy_ring else 0.0,
		_mood_ring.value if _mood_ring else 0.0)


## Sweeps both rings to new values over `duration` seconds.
func tween_needs(energy: float, mood: float, duration: float) -> Tween:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_energy_ring, "value", energy, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_mood_ring, "value", mood, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


## The student gained `amount` skill points: the chip squash-springs and a
## "+N" floats up from it. The number shows even under reduce_motion; the
## spring does not.
func pop_gain(amount: int) -> void:
	if amount <= 0 or _rings == null or not is_inside_tree():
		return
	if not GameSettings.reduce_motion:
		AnimUtils.squash_bounce(_rings)
	var tokens := DesignTokens.load_default()
	# create_floating_text places its label 100 px left of at_pos, so aim it
	# that far right of the rings' top-centre.
	var at := Vector2(_rings.size.x * 0.5 + 100.0, 0.0) + GAIN_TEXT_OFFSET
	AnimUtils.create_floating_text(_rings, "+%d" % amount, at,
		tokens.state_success.lightened(0.35), tokens.font_title)
