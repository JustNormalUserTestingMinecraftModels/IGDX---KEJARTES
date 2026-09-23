@tool
extends Control

## The celebration shown when the player claims an achievement
## (AchievementClaimPopup.tscn; reference: achievementclaim_mockup.png). A
## blurred screen, "SELAMAT, ANDA MENDAPATKAN", the icon large over animated
## light rays, the achievement's title, and paper confetti. Opened by
## achievements_screen.gd with open(); any tap after a short lock closes it,
## and it frees itself. @tool so the test runner can call open().

signal closed

## Seconds a tap is ignored after opening, so the Klaim tap cannot close it.
@export var input_lock_time: float = 0.4
## Seconds the content takes to fade in.
@export var fade_in_time: float = 0.25
## Seconds the popup takes to fade out once tapped.
@export var fade_out_time: float = 0.2

@onready var icon: TextureRect = $Safe/UI/Icon
@onready var title_label: Label = $Safe/UI/Title
@onready var content: Control = $Safe/UI
@onready var confetti: RewardParticles = $Confetti

var _accepting: bool = false
var _closing: bool = false


## Shows catalog entry `entry` and plays the entrance.
func open(entry: Dictionary) -> void:
	icon.texture = load(AchievementCatalog.icon_path(entry.id))
	title_label.text = entry.title
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	content.modulate.a = 0.0
	create_tween().tween_property(content, "modulate:a", 1.0, fade_in_time)
	Juice.pop_in(icon)
	RewardFeedback.play(&"achievement_claimed", self)
	confetti.fire()
	get_tree().create_timer(input_lock_time).timeout.connect(func() -> void: _accepting = true)


func _gui_input(event: InputEvent) -> void:
	if not _accepting or _closing:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		close()


## Fades the popup out, emits `closed` and frees it. Idempotent: a second
## call (e.g. a fast double Android back) is a no-op instead of starting a
## second fade tween and double-emitting/double-freeing.
func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_out_time)
	tw.finished.connect(_on_faded_out)


func _on_faded_out() -> void:
	closed.emit()
	queue_free()
