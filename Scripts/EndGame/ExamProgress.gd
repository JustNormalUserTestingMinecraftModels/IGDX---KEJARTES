@tool
extends Control

## The beat between TesNotice and the stat check: "Tes sedang
## berlangsung", with a progress bar that fills over a fixed duration
## while the backdrop drifts slowly left-to-right behind it, and then hands
## off to StatCheck. Purely a pacing beat -- it carries no verdict, same
## contract as TesNotice.
##
## @tool for the same reason every other end-of-grade screen is: without
## it, this becomes a placeholder instance when the MCP test suite
## instantiates the scene inside the editor process. The runtime side
## effects (the two tweens and the scene hand-off) sit behind the
## Engine.is_editor_hint() guard in _ready().

@onready var progress_bar: ProgressBar = $MarginContainer/Content/Inner/ProgressBar
@onready var status_label: Label = $MarginContainer/Content/Inner/StatusLabel
@onready var backdrop: TextureRect = $Backdrop

## Where the fill hands off. Plan A's StatCheck replaced the exam-intro
## cutscene beat that used to sit here.
const STAT_CHECK_SCENE := "res://Scenes/EndGame/StatCheck.tscn"

## Seconds for the bar to fill from 0 to 100 before advancing. The pan
## below runs over the same span so both end on the same frame.
@export var fill_seconds: float = 4.0

## How far the backdrop drifts during the fill, in px. Negative moves the
## image left, which reads as the camera panning right. The Backdrop node
## is authored 1296 px wide (viewport 1080 + |pan|) under
## KEEP_ASPECT_COVERED, so the drift never exposes an edge -- if you widen
## the pan, widen the node to match.
@export var pan_pixels: float = -216.0

var _advancing: bool = false


func _ready() -> void:
	status_label.text = "Tes sedang berlangsung"
	progress_bar.value = 0.0

	if Engine.is_editor_hint():
		return

	AudioDirector.play_bgm(&"exam_notice")

	# One tween, two tracks, one duration: the pan is deliberately not
	# eased so it reads as a slow, steady camera move rather than a settle.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(progress_bar, "value", 100.0, fill_seconds)
	tw.tween_property(backdrop, "position:x", backdrop.position.x + pan_pixels, fill_seconds) \
		.set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	if is_instance_valid(self):
		_advance()


## Guarded the same way TesNotice guards its own auto-advance, in case a
## future tap-to-skip is added alongside the timed fill.
func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	Transition.change_scene(STAT_CHECK_SCENE)
