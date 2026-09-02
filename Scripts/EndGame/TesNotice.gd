@tool
extends Control

## The first screen of the end-of-grade sequence: the Tes Besar Sekolah
## announcement.
##
## It shows at the end of every grade's final week, win or lose, and must
## never reveal the verdict -- that is the stat check's job two screens
## later. All it does is name the grade, set the stakes, and hand off to
## the exam branch of the cutscene.
##
## @tool for the same reason main_menu.gd and cut_scene.gd are: without
## it, this becomes a placeholder instance when the MCP test suite
## instantiates the scene inside the editor process, which breaks every
## traversal-based check. Everything with a real runtime side effect --
## reading GameState, starting BGM, arming the auto-advance timer -- sits
## behind the Engine.is_editor_hint() guard in _ready().

@onready var grade_label: Label = $MarginContainer/NoticeCard/Content/GradeLabel
@onready var btn_lanjut: Button = $MarginContainer/NoticeCard/Content/BtnLanjut
@onready var notice_card: NinePatchRect = $MarginContainer/NoticeCard

## Seconds before the notice advances on its own. Zero disables the
## auto-advance and waits for the button.
@export var auto_advance_seconds: float = 6.0

## How long the card takes to pop in, in seconds.
@export var card_pop_seconds: float = 0.45

var _advancing: bool = false


func _ready() -> void:
	btn_lanjut.pressed.connect(_on_lanjut_pressed)

	if Engine.is_editor_hint():
		return

	grade_label.text = GameState.get_grade_name()

	AudioDirector.play_bgm(&"exam_notice")
	AudioDirector.play_sfx(&"popup_open")

	Juice.pop_in(notice_card, 0.0)

	if auto_advance_seconds > 0.0:
		await get_tree().create_timer(auto_advance_seconds).timeout
		if is_instance_valid(self):
			_advance()


func _on_lanjut_pressed() -> void:
	AudioDirector.play_sfx(&"confirm")
	_advance()


## Guarded so the auto-advance timer and an impatient tap cannot both fire
## a scene change.
func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	GameState.is_exam_intro_cutscene = true
	Transition.change_scene("res://Scenes/CutScene/cut_scene.tscn")
