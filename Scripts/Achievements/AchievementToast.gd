@tool
extends CanvasLayer

## The "achievement unlocked" banner, an autoload scene
## (AchievementToast.tscn; reference: achievement_notif.png). Every
## Achievements.unlocked id joins a queue. One banner at a time slides down
## from the top edge, holds, then slides back up, over whatever screen is
## showing. @tool so the test runner can instance it; the autoload
## connection is skipped in the editor.

## Seconds the banner takes to slide in.
@export var slide_in_time: float = 0.35
## Seconds the banner stays fully shown.
@export var hold_time: float = 2.2
## Seconds the banner takes to slide back out.
@export var slide_out_time: float = 0.3

@onready var banner: Control = $Banner
@onready var icon: TextureRect = $Banner/Icon
@onready var title_label: Label = $Banner/Title

var _queue: Array[String] = []
var _busy: bool = false


func _ready() -> void:
	banner.visible = false
	if Engine.is_editor_hint():
		return
	Achievements.unlocked.connect(enqueue)


## Queues achievement `id` for a banner, starting one if none is showing.
func enqueue(id: String) -> void:
	_queue.append(id)
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		banner.visible = false
		return
	_busy = true
	var entry := AchievementCatalog.get_entry(_queue.pop_front())
	icon.texture = load(AchievementCatalog.icon_path(entry.id))
	title_label.text = entry.title
	var hidden_y := -banner.size.y
	banner.position.y = hidden_y
	banner.visible = true
	AudioDirector.play_sfx(&"tap")
	var tw := create_tween()
	tw.tween_property(banner, "position:y", 0.0, slide_in_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold_time)
	tw.tween_property(banner, "position:y", hidden_y, slide_out_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(_show_next)
