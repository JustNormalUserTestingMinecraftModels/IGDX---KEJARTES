@tool
extends Control

## The win beat: the mirror of the existing game-over cutscene branch, but
## warm instead of grey.
##
## It is deliberately a separate scene rather than a fourth branch inside
## cut_scene.gd: that script already carries three branches plus a level
## select modal, and the win path wants its own BGM and its own exit. What
## it is NOT allowed to differ on is the look -- the chatbox art, geometry
## and typewriter here are copied from cut_scene.tscn on purpose, and
## tests/test_win_screen.gd fails if the anchors drift apart.
##
## @tool for the same placeholder-instance reason as cut_scene.gd; every
## runtime side effect sits behind the Engine.is_editor_hint() guard.

@onready var dialogue_label: RichTextLabel = $DialogueBox/DialogueLabel
@onready var bg: TextureRect = $BgCutScene
@onready var fade_overlay: ColorRect = $FadeOverlay

## Typewriter speed, matching the intro cutscene's default.
@export var typewriter_chars_per_second: float = 45.0

## How long the fade to the next screen takes, in seconds.
@export var exit_fade_seconds: float = 0.6

## The win dialogue. Placeholders until the final script is written --
## keep them four lines so the pacing stays close to the lose cutscene's.
@export var dialogues: Array[String] = [
	"[PLACEHOLDER] Hasilnya keluar sore itu. Aku membaca daftar nama satu per satu, dan tanganku sedikit gemetar.",
	"[PLACEHOLDER] Semuanya lulus. Tidak ada satu pun nama yang tertinggal di daftar itu.",
	"[PLACEHOLDER] Mereka berteriak di halaman, saling memeluk, dan salah satu dari mereka berbalik dan berkata, 'Terima kasih sudah tidak menyerah pada kami.'",
	"[PLACEHOLDER] Aku hanya tersenyum. Ini bukan hasil kerjaku -- ini hasil kerja mereka. Aku cuma kebetulan berdiri di sampingnya.",
]

var _index: int = 0
var _reveal_tween: Tween
var _exiting: bool = false


func _ready() -> void:
	fade_overlay.color.a = 0.0
	if Engine.is_editor_hint():
		return
	AudioDirector.play_bgm(&"result_win")
	_show_current()


func _input(event: InputEvent) -> void:
	if _exiting:
		return
	var tapped := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return
	# A tap mid-typewriter completes the line; a tap on a finished line
	# advances. Same two-stage feel as the intro cutscene.
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
		dialogue_label.visible_ratio = 1.0
		return
	AudioDirector.play_sfx(&"tap")
	_advance()


func _show_current() -> void:
	if _index >= dialogues.size():
		return
	dialogue_label.text = dialogues[_index]
	dialogue_label.visible_ratio = 0.0
	var chars := float(dialogue_label.text.length())
	var seconds := chars / maxf(typewriter_chars_per_second, 1.0)
	if _reveal_tween:
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(dialogue_label, "visible_ratio", 1.0, seconds)


func _advance() -> void:
	_index += 1
	if _index < dialogues.size():
		_show_current()
	else:
		_exit_to_result()


func _exit_to_result() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	var tw := create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, exit_fade_seconds)
	await tw.finished
	Transition.change_scene("res://Scenes/EndGame/RunResult.tscn")
