@tool
class_name WinStage
extends Control

## The end-of-grade painting with the run's roster posed on it (2026-09-11):
## the letterbox bars, win_background.png, four student slots and their
## ground shadows. EndCutscene and RunResult both instance this one scene,
## so the frame RunResult opens on is the frame EndCutscene blurred out on --
## the same art, the same framing, the same students -- rather than two
## layouts kept in step by hand. It used to live inside EndCutscene; it moved
## here when RunResult needed the same picture behind its report.
##
## dress() is the only entry point, and the host passes everything in: the
## verdict StatCheck wrote and the roster's names. Nothing here decides the
## verdict or reads the roster itself.
##
## The root is a bare anchor that draws from its children. An instanced
## scene's root under a plain Control reloads with its rect snapped to zero
## (authoring guide, "Two ways the editor silently drops a Control's rect"),
## so dress() sizes BarFill and fits Stage to the viewport in code, the way
## PaperShadow draws from its Silhouette.
##
## @tool so the test suites can instantiate it inside the editor. _ready()
## only re-asserts the bar colour; the layout happens when a host calls
## dress() at runtime.

@export_group("Backdrops")
## Painting shown when the run passed. Real graduation artwork; the students and shadows compose on top.
@export var win_backdrop: Texture2D
## CG shown when the run failed. Covers the viewport, with no lineup on it.
@export var lose_backdrop: Texture2D

@export_group("Win lineup")
## Splash art for roster name "Doni". Null leaves its slot hidden.
@export var win_splash_doni: Texture2D
## Splash art for roster name "Andi". Null leaves its slot hidden.
@export var win_splash_andi: Texture2D
## Splash art for roster name "Citra". Null leaves its slot hidden.
@export var win_splash_citra: Texture2D
## Splash art for roster name "Shinta". Null leaves its slot hidden.
@export var win_splash_shinta: Texture2D
## Splash art for roster name "Marcel". Null leaves its slot hidden.
@export var win_splash_marcel: Texture2D
## Splash art for roster name "Thea". Null leaves its slot hidden.
@export var win_splash_thea: Texture2D
## Fills the letterbox bars above and below the painting. Defaults to the
## surface_overlay token so the bars read as the game's own chrome rather
## than as a video letterbox.
@export var bar_color: Color = Color("141a2e")
## Texture every ground shadow wears. Drop-replacement point for real art.
@export var shadow_texture: Texture2D
## Alpha of every ground shadow, 0-1.
@export var shadow_opacity: float = 0.28
## Multiplies each student's measured foot span to get its shadow width.
@export var shadow_spread: float = 1.25
## Ellipse height as a fraction of its width. Lower reads as a flatter
## floor, higher as a softer pool.
@export var shadow_flatness: float = 0.28

## The painting's native size. Students are positioned in this space and the
## whole Stage is scaled into the viewport, so numbers measured off the
## mockup transfer 1:1 and the composition never drifts from the art.
const ART_SIZE := Vector2(1536.0, 2048.0)

@onready var bar_fill: ColorRect = $BarFill
@onready var stage: Control = $Stage
@onready var backdrop: TextureRect = $Stage/Backdrop
@onready var shadows: Control = $Stage/Shadows
@onready var students: Control = $Stage/Students


func _ready() -> void:
	# Authored at the token's value too, but re-asserted so changing the
	# export is enough -- the bars and the export must not drift apart.
	bar_fill.color = bar_color


## The names of an approved_students-shaped roster, in roster order. A
## student with no "name" key contributes "", which has no splash and so
## leaves its slot hidden.
static func names_of(roster: Array) -> Array:
	var names: Array = []
	for student in roster:
		names.append(student.get("name", ""))
	return names


## Where the letterboxed painting lands in a viewport of `area`: scaled by
## the smaller ratio so the whole 3:4 image survives on a 9:16 screen, and
## centred. At 1080x1920 that is 1080x1440 with 240px bars top and bottom.
## Returns {"scale": float, "position": Vector2}.
static func letterbox(area: Vector2) -> Dictionary:
	var s := minf(area.x / ART_SIZE.x, area.y / ART_SIZE.y)
	return {"scale": s, "position": (area - ART_SIZE * s) * 0.5}


## Dress the stage for a verdict. Win letterboxes the painting and poses
## `names` on it; lose covers the viewport with the lose CG and hides every
## slot. Sets BarFill, Stage's transform, Backdrop's texture and every
## Student/Shadow slot -- nothing is constructed.
func dress(failed: bool, names: Array) -> void:
	var vp := get_viewport_rect().size
	bar_fill.position = Vector2.ZERO
	bar_fill.size = vp
	backdrop.texture = lose_backdrop if failed else win_backdrop
	if not failed:
		_fit_stage(vp)
		_dress_lineup(names)
	else:
		_fit_stage_cover(vp)
		_hide_lineup()


## Letterbox the painting into `vp` (see letterbox()).
func _fit_stage(vp: Vector2) -> void:
	var fit := letterbox(vp)
	var s: float = fit["scale"]
	stage.size = ART_SIZE
	stage.scale = Vector2(s, s)
	stage.position = fit["position"]


## The lose path keeps the framing the CG has always had: Stage fills the
## viewport and Backdrop covers it (KEEP_ASPECT_COVERED), so cg_lose.jpg is
## centred and cropped rather than stretched. Left at the 1536x2048 art
## size, Stage would show only the CG's top-left corner.
func _fit_stage_cover(vp: Vector2) -> void:
	stage.size = vp
	stage.scale = Vector2.ONE
	stage.position = Vector2.ZERO


## Splash art for a roster name, or null when the name is unknown.
##
## Six separate exports rather than one Dictionary: a Dictionary's nested
## values cannot be wired as Resources through the editor's property API,
## so the paths stayed strings and the textures never loaded.
func _splash_for(student_name: String) -> Texture2D:
	match student_name:
		"Doni": return win_splash_doni
		"Andi": return win_splash_andi
		"Citra": return win_splash_citra
		"Shinta": return win_splash_shinta
		"Marcel": return win_splash_marcel
		"Thea": return win_splash_thea
	return null


## Put the roster on the stage. Slots and shadows are authored nodes; this
## only sets texture, size, position and visibility on them.
func _dress_lineup(names: Array) -> void:
	var placed := WinLineup.assign(names)
	for i in range(4):
		var sprite: TextureRect = students.get_node("Student%d" % (i + 1))
		var shadow: TextureRect = shadows.get_node("Shadow%d" % (i + 1))
		if i >= placed.size():
			sprite.hide()
			shadow.hide()
			continue

		var p: Dictionary = placed[i]
		var tex: Texture2D = _splash_for(p["name"])
		if tex == null:
			push_warning("WinStage: no win splash for '%s'" % p["name"])
			sprite.hide()
			shadow.hide()
			continue

		# The splash is anchored bottom-centre: its canvas is square, so
		# half its scaled width sits either side of the anchor and its
		# full scaled height sits above it.
		var side: float = tex.get_width() * float(p["scale"])
		sprite.texture = tex
		sprite.size = Vector2(side, side)
		sprite.position = Vector2(p["anchor"]) - Vector2(side * 0.5, side)
		sprite.show()

		var sh := WinLineup.shadow_for(p, shadow_spread, shadow_flatness)
		var sh_size: Vector2 = sh["size"]
		var sh_centre: Vector2 = sh["centre"]
		shadow.texture = shadow_texture
		shadow.size = sh_size
		shadow.position = sh_centre - sh_size * 0.5
		shadow.modulate = Color(0.0, 0.0, 0.0, shadow_opacity)
		shadow.show()


## Hide every student and shadow. The lose CG has no lineup, and a stage
## dressed twice must not keep a previous win's figures.
func _hide_lineup() -> void:
	for i in range(1, 5):
		students.get_node("Student%d" % i).hide()
		shadows.get_node("Shadow%d" % i).hide()
