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
## squash-springs when the student gains a skill, with one StatGainPop per
## gaining skill -- its icon, the gold arrow and "+N", dressed like the daily
## result card's row. Full per-student numbers live in that card, not here.

## Where a gain pop starts, relative to sitting just above the rings'
## top-centre, in px. The chip's Headroom node above the rings gives the
## rise room inside the strip, which clips anything above its own top.
const GAIN_TEXT_OFFSET := Vector2(0, 12)
## The template each gaining skill floats up as. Instanced, never built.
const GAIN_POP_SCENE: PackedScene = preload("res://Scenes/SchoolSimulation/StatGainPop.tscn")
## Seconds between one skill's pop and the next, when a student gains more
## than one at once. Equal to StatGainPop's default rise_seconds, so the
## next pop starts as the last one fades out: any shorter and two pops sit
## on top of each other in the chip's narrow headroom (seen 2026-09-25).
const GAIN_POP_STAGGER := 1.2

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


## The skills that rose in `gains` (stat key -> whole points), in the card's
## row order, dropping any that did not rise.
static func gaining_stats(gains: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in DaySummaryStatRow.ICON_FOR:
		if int(gains.get(key, 0)) > 0:
			out.append(key)
	return out


## The student gained skill points: `gains` maps a stat key (akademis /
## seni_budaya / olahraga) to the whole points it rose. The chip squash-
## springs once and each gaining skill floats up as its own StatGainPop,
## GAIN_POP_STAGGER apart. The pops show even under reduce_motion; the
## spring does not.
func pop_gains(gains: Dictionary) -> void:
	if _rings == null or not is_inside_tree():
		return
	var keys := gaining_stats(gains)
	if keys.is_empty():
		return
	if not GameSettings.reduce_motion:
		AnimUtils.squash_bounce(_rings)
	for i in keys.size():
		var amount := int(gains[keys[i]])
		if i == 0:
			_float_gain(keys[i], amount)
		else:
			get_tree().create_timer(GAIN_POP_STAGGER * i).timeout.connect(
				_float_gain.bind(keys[i], amount))


## One skill's pop, centred over the rings' top edge.
func _float_gain(stat_key: String, amount: int) -> void:
	if _rings == null or not is_inside_tree():
		return
	var pop := GAIN_POP_SCENE.instantiate() as StatGainPop
	_rings.add_child(pop)
	pop.set_gain(stat_key, amount)
	# Rings is a plain Control, so nothing sizes the pop for it.
	var sz := pop.get_combined_minimum_size()
	pop.size = sz
	pop.position = Vector2((_rings.size.x - sz.x) * 0.5, -sz.y) + GAIN_TEXT_OFFSET
	pop.play()
