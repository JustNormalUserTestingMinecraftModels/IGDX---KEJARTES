@tool
class_name EndCutscene
extends Control

## The win / lose beat between StatCheck and RunResult (2026-09-05).
##
## One scene for both outcomes: StatCheck writes GameState.run_failed on its
## way out, this screen reads it once in _ready() and picks a backdrop, a
## badge and a BGM from the paired exports below. Nothing else here
## branches, and it never recomputes the verdict.
##
## Sequence: the scene opens under an opaque white overlay -- completing the
## fade StatCheck ends on, which is why that hand-off deliberately bypasses
## Transition -- fades it out over the image, holds so the image reads,
## slams the badge into the top-left, holds again, then reveals the Next
## button. The button is the only way forward, and is disabled until then.
##
## Pressing it blurs the backdrop in place and swaps RunResult in underneath.
## That blur is the transition: this screen does not call Transition, exactly
## as StatCheck does not on the way in, so the three screens read as one
## continuous beat instead of three wipes.
##
## @tool so the MCP test suite can instantiate the scene inside the editor;
## every runtime side effect sits behind Engine.is_editor_hint(). The button
## signal is wired before that guard so the wiring stays testable.

@export_group("Win")
## Backdrop shown when the run passed. Placeholder until final art lands.
@export var win_backdrop: Texture2D
## Badge stamped into the top-left when the run passed.
@export var win_badge: Texture2D
## BGM started when the run passed.
@export var win_bgm: StringName = &"result_win"

@export_group("Lose")
## Backdrop shown when the run failed.
@export var lose_backdrop: Texture2D
## Badge stamped into the top-left when the run failed.
@export var lose_badge: Texture2D
## BGM started when the run failed.
@export var lose_bgm: StringName = &"result_lose"

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

@export_group("Pacing")
## Seconds the opaque white overlay takes to clear.
@export var white_fade_seconds: float = 0.8
## Pause after the white clears, so the image reads before the badge lands.
@export var image_hold_seconds: float = 0.6
## Pause after the badge lands before the Next button appears.
@export var button_delay_seconds: float = 0.5

@export_group("Exit blur")
## Seconds the backdrop takes to blur once Next is pressed. This IS the
## transition to RunResult -- there is no wipe over the top of it.
@export var blur_seconds: float = 0.5
## Final blur strength, as a screen-texture mip level. Matches the shop's
## BlurLayer (koprasi.tscn) so the two blurs read as the same effect.
@export var blur_lod: float = 3.0
## Final dim applied with the blur, 0-1. RunResult opens on exactly this
## value so the swap between the two screens is invisible -- change one and
## you must change the other (test_run_result pins them together).
@export var blur_darkness: float = 0.3

## Where the button goes.
const RUN_RESULT_SCENE := "res://Scenes/EndGame/RunResult.tscn"

## The backdrop's native size. Students are positioned in this space and
## the whole Stage is scaled into the viewport, so numbers measured off
## the mockup transfer 1:1 and the composition never drifts from the art.
const ART_SIZE := Vector2(1536.0, 2048.0)

@onready var backdrop: TextureRect = $Stage/Backdrop
@onready var badge: TextureRect = $Badge
@onready var btn_next: Button = $BtnNext
@onready var white_fade: ColorRect = $WhiteFade
@onready var stage: Control = $Stage
@onready var shadows: Control = $Stage/Shadows
@onready var students: Control = $Stage/Students
## Sits between Backdrop and Badge on purpose: the shader samples what is
## already drawn, so only the backdrop blurs and the badge stays sharp.
@onready var blur_layer: ColorRect = $BlurLayer

var _exiting: bool = false


func _ready() -> void:
	btn_next.pressed.connect(_on_next_pressed)

	# Re-asserted here as well as authored in the scene: @tool means the
	# editor may have left any of these part-way through an edit.
	white_fade.modulate.a = 1.0
	badge.modulate.a = 0.0
	btn_next.modulate.a = 0.0
	btn_next.disabled = true

	# Park the blur inert. lod 0 makes textureLod an identity sample and
	# darkness 0 leaves the colour alone, so the layer is a no-op even if it
	# is shown -- the scene authors darkness at the shader's own 0.3 default,
	# which would otherwise dim the image the moment the layer appeared.
	blur_layer.hide()
	_set_blur(0.0, 0.0)

	if Engine.is_editor_hint():
		return

	_dress_for_verdict()
	_play()


## Reads the verdict once and dresses the screen for it. StatCheck decided
## it; this screen is only the reveal.
##
## The two paths diverge more than they used to. Lose keeps the CG and the
## stamp. Win puts the roster on the new backdrop and shows no badge --
## the chalkboard already reads "Selamat Kelulusan", so a LULUS stamp over
## it would be redundant and would cover the art.
func _dress_for_verdict() -> void:
	var failed: bool = GameState.run_failed
	backdrop.texture = lose_backdrop if failed else win_backdrop
	badge.texture = lose_badge if failed else win_badge
	# Stage stays visible either way -- Backdrop lives under it and carries
	# both verdicts' art. The lineup slots are authored hidden and are only
	# ever shown by _dress_lineup(), so the lose path never sees them.
	if not failed:
		_fit_stage()
		_dress_lineup()
	AudioDirector.play_bgm(lose_bgm if failed else win_bgm)


## Letterbox the painting into the viewport: scale by the smaller ratio so
## the whole 3:4 image survives on a 9:16 screen, and centre it. At
## 1080x1920 this gives 1080x1440 with 240px bars top and bottom -- which
## is where BtnNext sits, clear of the art.
func _fit_stage() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / ART_SIZE.x, vp.y / ART_SIZE.y)
	stage.size = ART_SIZE
	stage.scale = Vector2(s, s)
	stage.position = (vp - ART_SIZE * s) * 0.5


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


## Put the run's own roster on the stage. Called only on the win path --
## the lose branch keeps its CG and its stamp.
##
## Slots and shadows are authored nodes; this only sets texture, size,
## position and visibility on them. Nothing is constructed here.
func _dress_lineup() -> void:
	var names: Array = []
	for s in GameState.approved_students:
		names.append(s.get("name", ""))

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
			push_warning("EndCutscene: no win splash for '%s'" % p["name"])
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


## The beat, as a coroutine -- never call this from a test.
func _play() -> void:
	var tw := create_tween()
	tw.tween_property(white_fade, "modulate:a", 0.0, white_fade_seconds) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(image_hold_seconds).timeout
	if not is_inside_tree():
		return

	var failed: bool = GameState.run_failed
	if failed:
		_slam_badge()
		await get_tree().create_timer(button_delay_seconds).timeout
		if not is_inside_tree():
			return

	btn_next.disabled = false
	Juice.pop_in(btn_next)


## The stamp gesture RunResult._slam_grade() uses for the letter grade: down
## from 3x with a back-out overshoot, a shake, and the stamp cue.
func _slam_badge() -> void:
	Juice.set_pivot_center(badge)
	badge.scale = Vector2(3.0, 3.0)
	badge.modulate.a = 0.0
	var t := Juice.tokens()
	var tw := badge.create_tween().set_parallel(true)
	tw.tween_property(badge, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(badge, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(badge.get_parent(), 8.0))


## Writes both blur uniforms at once. Kept in one place because they are
## only ever meaningful together: lod without darkness reads as a smear,
## darkness without lod as a plain dim.
func _set_blur(lod: float, darkness: float) -> void:
	var mat: ShaderMaterial = blur_layer.material
	mat.set_shader_parameter("lod", lod)
	mat.set_shader_parameter("darkness", darkness)


## The hand-off: the backdrop blurs where it stands, and RunResult is swapped
## in underneath it. A coroutine -- never call it from a test.
##
## Deliberately bypasses the project-wide wipe. The blur is the transition; a
## wipe over the top would read as two of them. StatCheck bypasses it on the
## way in here for the same reason, so the whole StatCheck -> this ->
## RunResult stretch is one continuous piece rather than three wipes.
##
## (Naming the autoload's method in full here would trip the suite's own
## grep for it -- that assertion is how the wipe is kept out.)
func _blur_out() -> void:
	_set_blur(0.0, 0.0)
	blur_layer.show()
	var mat: ShaderMaterial = blur_layer.material
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "shader_parameter/lod", blur_lod, blur_seconds)
	tw.tween_property(mat, "shader_parameter/darkness", blur_darkness,
		blur_seconds)
	await tw.finished


## Guarded so a double-tap cannot fire two scene changes, the same way
## TesNotice and RunResult guard theirs.
func _on_next_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	await _blur_out()
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(RUN_RESULT_SCENE)
