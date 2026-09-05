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

@export_group("Pacing")
## Seconds the opaque white overlay takes to clear.
@export var white_fade_seconds: float = 0.8
## Pause after the white clears, so the image reads before the badge lands.
@export var image_hold_seconds: float = 0.6
## Pause after the badge lands before the Next button appears.
@export var button_delay_seconds: float = 0.5

## Where the button goes.
const RUN_RESULT_SCENE := "res://Scenes/EndGame/RunResult.tscn"

@onready var backdrop: TextureRect = $Backdrop
@onready var badge: TextureRect = $Badge
@onready var btn_next: Button = $BtnNext
@onready var white_fade: ColorRect = $WhiteFade

var _exiting: bool = false


func _ready() -> void:
	btn_next.pressed.connect(_on_next_pressed)

	# Re-asserted here as well as authored in the scene: @tool means the
	# editor may have left any of these part-way through an edit.
	white_fade.modulate.a = 1.0
	badge.modulate.a = 0.0
	btn_next.modulate.a = 0.0
	btn_next.disabled = true

	if Engine.is_editor_hint():
		return

	_dress_for_verdict()
	_play()


## Reads the verdict once and dresses the screen for it. StatCheck decided
## it; this screen is only the reveal.
func _dress_for_verdict() -> void:
	var failed: bool = GameState.run_failed
	backdrop.texture = lose_backdrop if failed else win_backdrop
	badge.texture = lose_badge if failed else win_badge
	AudioDirector.play_bgm(lose_bgm if failed else win_bgm)


## The beat, as a coroutine -- never call this from a test.
func _play() -> void:
	var tw := create_tween()
	tw.tween_property(white_fade, "modulate:a", 0.0, white_fade_seconds) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(image_hold_seconds).timeout
	if not is_inside_tree():
		return

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


## Guarded so a double-tap cannot fire two scene changes, the same way
## TesNotice and RunResult guard theirs.
func _on_next_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	Transition.change_scene(RUN_RESULT_SCENE)
