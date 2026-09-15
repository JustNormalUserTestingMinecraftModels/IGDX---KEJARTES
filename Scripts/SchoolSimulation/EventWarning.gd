@tool
extends Control

## The full-screen "something is about to happen" warning (2026-09-12
## event-cards spec, section 2). A flat mustard panel carrying the
## eventwarning_icon art and one caption line slides in from the right edge,
## holds, and keeps going out through the left edge. It fronts both kinds of
## mid-day interruption: the three minigames ("KEGIATAN AKADEMIS!") and the
## random events (their own name). Everything is authored in the scene; the
## script only moves it and sets the caption.

## The megaphone art on the panel. Swappable from the Inspector.
@export var icon_texture: Texture2D = preload("res://Assets/Images/SchoolDay/eventwarning_icon.png"):
	set(v):
		icon_texture = v
		if is_node_ready():
			icon.texture = v
## Seconds the panel takes to cover the screen from the right edge.
@export_range(0.05, 2.0, 0.01) var slide_in_duration: float = 0.35
## Seconds the panel rests on screen with the icon and caption showing.
@export_range(0.1, 5.0, 0.05) var hold_duration: float = 1.1
## Seconds the panel takes to leave through the left edge.
@export_range(0.05, 2.0, 0.01) var slide_out_duration: float = 0.35

@onready var panel: Panel = $Panel
@onready var icon: TextureRect = $Panel/Center/Content/Icon
@onready var caption: Label = $Panel/Center/Content/Caption


func _ready() -> void:
	icon.texture = icon_texture
	if Engine.is_editor_hint():
		return
	panel.position.x = panel_x(&"enter", size.x)


## Where the panel's left edge sits at each stage of the pass, for a screen
## `width` wide: off the right edge, resting, off the left edge.
static func panel_x(stage: StringName, width: float) -> float:
	match stage:
		&"enter":
			return width
		&"exit":
			return -width
		_:
			return 0.0


## Slide through the screen once showing `caption_text`, then free. Awaitable:
## SchoolDay waits on it before the minigame or event begins.
func play_warning(caption_text: String) -> void:
	caption.text = caption_text
	AudioDirector.play_sfx(&"event_announce")
	var width := size.x
	panel.position.x = panel_x(&"enter", width)
	icon.modulate.a = 0.0
	caption.modulate.a = 0.0

	var slide_in := create_tween()
	slide_in.tween_property(panel, "position:x", panel_x(&"rest", width), slide_in_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slide_in.finished

	Juice.pop_in(icon)
	Juice.fade_in(caption)
	await get_tree().create_timer(hold_duration).timeout

	var slide_out := create_tween()
	slide_out.tween_property(panel, "position:x", panel_x(&"exit", width), slide_out_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await slide_out.finished
	queue_free()
