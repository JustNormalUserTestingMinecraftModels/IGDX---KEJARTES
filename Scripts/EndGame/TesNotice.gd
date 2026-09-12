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
@onready var title_art: TextureRect = $MarginContainer/NoticeCard/Content/TitleArt
@onready var body_label: Label = $MarginContainer/NoticeCard/Content/BodyLabel

## Seconds before the notice advances on its own. Zero disables the
## auto-advance and waits for the button.
@export var auto_advance_seconds: float = 6.0

## Title logo for the grades below nasional_from_grade (Kelas 7 and 8).
@export var ujian_sekolah_texture: Texture2D = preload("res://Assets/Images/EndGame/ujian_sekolah.png")

## Title logo from nasional_from_grade upward (Kelas 9).
@export var ujian_nasional_texture: Texture2D = preload("res://Assets/Images/EndGame/ujian_nasional.png")

## The first grade whose exam is the Ujian Nasional rather than the Ujian
## Sekolah.
@export var nasional_from_grade: int = 9

## Body copy for the grades below nasional_from_grade. The scene's BodyLabel
## text is only the editor preview; _ready() replaces it with one of these.
@export_multiline var ujian_sekolah_body: String = "Minggu pembelajaran sudah berakhir. Sekarang seluruh murid akan menghadapi Tes Besar Sekolah. Hasilnya akan menentukan apakah mereka naik ke tahap berikutnya."

## Body copy from nasional_from_grade upward.
@export_multiline var ujian_nasional_body: String = "Minggu pembelajaran sudah berakhir. Sekarang seluruh murid akan menghadapi Ujian Nasional. Hasilnya akan menentukan apakah mereka naik ke tahap berikutnya."

var _advancing: bool = false


## The body copy for a grade, naming the same exam as its title logo.
func body_text_for_grade(grade: int) -> String:
	if grade >= nasional_from_grade:
		return ujian_nasional_body
	return ujian_sekolah_body


func _ready() -> void:
	btn_lanjut.pressed.connect(_on_lanjut_pressed)

	if Engine.is_editor_hint():
		return

	grade_label.text = GameState.get_grade_name()
	title_art.texture = title_texture_for_grade(GameState.current_grade)
	body_label.text = body_text_for_grade(GameState.current_grade)

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
	Transition.change_scene("res://Scenes/EndGame/ExamProgress.tscn")


## The exam logo for a grade: Ujian Sekolah below nasional_from_grade,
## Ujian Nasional from it upward. Pure, so tests can call it without
## GameState.
func title_texture_for_grade(grade: int) -> Texture2D:
	if grade >= nasional_from_grade:
		return ujian_nasional_texture
	return ujian_sekolah_texture
