@tool
class_name MinigameCountdown
extends CanvasLayer

## The "3, 2, 1, Mulai!" countdown every minigame plays before input unlocks.
##
## Instantiated by Scripts/Minigames/UI/BaseMinigame.gd, which previously
## built this CanvasLayer/CenterContainer/Label by hand every time. The node
## now lives in Scenes/Minigames/UI/MinigameCountdown.tscn; the font, size,
## colours and step text still come from BaseMinigame's own @exports, passed
## in through configure().
##
## Affects: nothing outside itself. Frees itself at the end of play().
##
## @tool so the scene previews in the editor. process_mode is ALWAYS (set in
## the scene) because a minigame's own process_mode is flipped to DISABLED
## while paused, and the countdown must still animate on resume.

@onready var count_label: Label = $Center/CountLabel

## The step strings to show in order. Defaults to BaseMinigame's own default
## if configure() is never called or is given an empty array.
var _steps: Array[String] = ["3", "2", "1", "Mulai!"]


## Fill the label's styling from BaseMinigame's countdown @exports.
##
## Affects: this node's own label only.
func configure(steps: Array[String], font: Font, font_size: int,
		font_color: Color, outline_color: Color, outline_size: int) -> void:
	if not steps.is_empty():
		_steps = steps
	count_label.add_theme_font_size_override("font_size", font_size)
	count_label.add_theme_color_override("font_color", font_color)
	count_label.add_theme_constant_override("outline_size", outline_size)
	count_label.add_theme_color_override("font_outline_color", outline_color)
	if font:
		count_label.add_theme_font_override("font", font)


## Play every configured step, then free this node.
##
## Affects: this node's own label text/scale. Frees this node when done --
## callers must await it (it is the whole reveal, not fire-and-forget).
func play() -> void:
	for step in _steps:
		count_label.text = step
		count_label.scale = Vector2(1.4, 1.4)
		count_label.pivot_offset = count_label.size / 2.0

		var tw := create_tween()
		tw.tween_property(count_label, "scale", Vector2(1.0, 1.0), 0.35)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		await get_tree().create_timer(0.45).timeout

	queue_free()
