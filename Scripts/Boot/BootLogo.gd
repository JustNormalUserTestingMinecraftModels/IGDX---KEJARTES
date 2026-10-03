@tool
extends Control

## The boot logo: the first scene the game runs. The team's minusone_logo
## video plays on black, fading in at the start and out once it ends, then
## hands over to MainMenu. Godot's own boot splash is plain black
## (project.godot), so the two meet seamlessly. A tap skips to the fade-out.
## The video's size on screen is the Video node's rect in BootLogo.tscn.
##
## @tool so the test suite gets a live instance; playback and the scene
## change are runtime-only, behind Engine.is_editor_hint().

## Where the logo hands over once it has faded out.
@export_file("*.tscn") var next_scene: String = "res://Scenes/MainMenu/MainMenu.tscn"
## Seconds of black before the video starts.
@export_range(0.0, 2.0, 0.05) var start_delay: float = 0.3
## Seconds the video takes to fade in as it starts.
@export_range(0.05, 3.0, 0.05) var fade_in_seconds: float = 0.4
## Seconds the last frame stays up after the video ends.
@export_range(0.0, 3.0, 0.05) var hold_seconds: float = 0.3
## Seconds the video takes to fade out.
@export_range(0.05, 3.0, 0.05) var fade_out_seconds: float = 0.6

## The video's sound fades out to this level, in dB.
const SILENT_DB := -60.0
## Extra seconds the backstop waits past the video's own end before leaving.
const FALLBACK_GRACE_SECONDS := 1.0

@onready var _video: VideoStreamPlayer = %Video

var _leaving := false
var _tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_video.modulate.a = 0.0
	_video.finished.connect(_on_video_finished)
	_tween = create_tween()
	_tween.tween_interval(start_delay)
	_tween.tween_callback(_video.play)
	_tween.tween_property(_video, "modulate:a", 1.0, fade_in_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Backstop: a video that never plays (a codec the platform lacks) never
	# emits finished, so leave anyway once its length plus the hold has passed.
	get_tree().create_timer(start_delay + _video.get_stream_length() + hold_seconds
		+ FALLBACK_GRACE_SECONDS).timeout.connect(_leave)


## A tap or key press skips the rest of the video and fades it out now.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _leaving:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if pressed:
		_leave()


## Holds the last frame for hold_seconds, then leaves.
func _on_video_finished() -> void:
	get_tree().create_timer(hold_seconds).timeout.connect(_leave)


## Fades the video (and its sound) out from wherever it is, then changes to
## next_scene.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var out := create_tween().set_parallel(true)
	out.tween_property(_video, "modulate:a", 0.0, fade_out_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	out.tween_property(_video, "volume_db", SILENT_DB, fade_out_seconds)
	out.chain().tween_callback(func() -> void:
		_video.stop()
		Transition.change_scene(next_scene, Transition.Style.FADE))
