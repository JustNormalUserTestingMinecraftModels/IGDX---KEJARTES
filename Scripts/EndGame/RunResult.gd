extends Control

## The last screen of a run: what the player actually did this grade,
## reported as six counted-up figures and one letter grade.
##
## Deliberately NOT @tool -- like SemesterEnd and StudentCard, _ready()
## reads GameState, starts BGM and kicks off a tween chain, none of which
## should fire because the editor opened the scene. Its tests are
## therefore source-text scans plus structural checks on a bare
## instantiate(), never live property reads.
##
## This screen also owns grade progression, which used to live in
## SemesterEnd._on_restart_pressed(). It moved here because RunResult is
## now the last thing a run touches, and progression has to happen exactly
## once, after the report has been read.

@export_group("Reveal Timing")
## Delay between each report row appearing.
@export var row_stagger: float = 0.14
## How long each row's number takes to count up.
@export var count_up_seconds: float = 0.7
## Pause after the last row before the letter grade slams in.
@export var grade_delay: float = 0.5

@onready var rows_box: VBoxContainer = $MarginContainer/Column/RowsBox
@onready var grade_letter: Label = $MarginContainer/Column/GradeCard/GradeStack/GradeLetter
@onready var grade_caption: Label = $MarginContainer/Column/GradeCard/GradeStack/GradeCaption
@onready var title_label: Label = $MarginContainer/Column/TitleLabel
@onready var btn_selesai: Button = $MarginContainer/Column/BtnSelesai

const ROW_SCENE := preload("res://Scenes/EndGame/RunResultRow.tscn")

## The report's six icons, preloaded so a row swap costs nothing at
## reveal time. Transparent SVGs authored alongside the project's other
## placeholder icons -- see Task 11's note on why SVG and not PNG.
const ICON_MINIGAME_MENANG := preload("res://Assets/Images/UI/Placeholders/icon_minigame_menang.svg")
const ICON_MINIGAME_KALAH := preload("res://Assets/Images/UI/Placeholders/icon_minigame_kalah.svg")
const ICON_POIN := preload("res://Assets/Images/UI/Placeholders/icon_poin.svg")
const ICON_BARANG := preload("res://Assets/Images/UI/Placeholders/icon_barang.svg")
const ICON_UANG := preload("res://Assets/Images/UI/Placeholders/icon_uang.svg")
const ICON_EVENT := preload("res://Assets/Images/UI/Placeholders/icon_event.svg")

## One caption per letter band, so the grade says something rather than
## just scoring something.
const GRADE_CAPTIONS := {
	"A+": "Sempurna. Tidak ada yang tertinggal.",
	"A": "Luar biasa. Kelas ini beruntung punya kamu.",
	"A-": "Sangat baik. Hampir sempurna.",
	"B+": "Baik sekali. Masih ada ruang untuk rapi.",
	"B": "Baik. Targetnya tercapai.",
	"B-": "Cukup baik. Beberapa hal bisa lebih halus.",
	"C+": "Lulus, dengan perjuangan.",
	"C": "Lulus tipis. Lain kali lebih awal.",
	"C-": "Nyaris tidak lulus, tapi lulus.",
	"D": "Belum berhasil. Mereka masih menunggumu.",
}

var _grade_text: String = "D"
var _money_row: Control = null
var _exiting: bool = false


func _ready() -> void:
	btn_selesai.pressed.connect(_on_selesai_pressed)
	AudioDirector.play_bgm(&"run_result")

	title_label.text = "Hasil %s" % GameState.get_grade_name()
	grade_letter.text = ""
	grade_caption.text = ""

	_build_rows()
	_compute_grade()
	_play_reveal()


## The six rows are instanced from RunResultRow.tscn rather than authored
## in this scene. Reviewed exception to the no-runtime-construction rule
## (per-call-dynamic content): the row count is fixed, but every value is
## run-dependent, and authoring six frozen rows would mean six near-empty
## nodes plus a parallel wiring table. Registered in
## tests/test_viewport_editability.gd's ALLOWED dict, not BASELINE.
func _build_rows() -> void:
	var stats: RunStats = GameState.run_stats
	var spec := [
		[ICON_MINIGAME_MENANG, "Minigame selesai", float(stats.minigames_won), ""],
		[ICON_MINIGAME_KALAH, "Minigame kalah", float(stats.minigames_lost), ""],
		[ICON_POIN, "Total poin minigame", stats.minigame_points, " poin"],
		[ICON_BARANG, "Barang dipakai", float(stats.items_used), ""],
		[ICON_UANG, "Uang dari wirausaha", float(stats.wirausaha_money), "G"],
		[ICON_EVENT, "Murid ikut event", float(stats.event_student_count()), " murid"],
	]
	for entry in spec:
		# Corrected from the brief: `var row := ROW_SCENE.instantiate()`
		# infers the static type Node (PackedScene.instantiate()'s
		# declared return type), so `row.set_row(...)` below would not
		# compile -- set_row() only exists on RunResultRow. Explicitly
		# typing the var performs the downcast GDScript allows on
		# assignment.
		var row: RunResultRow = ROW_SCENE.instantiate()
		rows_box.add_child(row)
		row.set_row(String(entry[1]), float(entry[2]), String(entry[3]),
			entry[0] as Texture2D)
		row.modulate.a = 0.0
		if String(entry[1]) == "Uang dari wirausaha":
			_money_row = row


func _compute_grade() -> void:
	var counted: Array = GameState.count_targets_cleared()
	var passed := not GameState.run_failed and GameState.check_semester_passed()
	var run_score := RunGrade.score(GameState.run_stats,
		int(counted[0]), int(counted[1]), GameState.approved_students.size())
	_grade_text = RunGrade.letter(run_score, passed)


## Title first, then the rows one at a time counting up, then the letter.
## The letter lands last on purpose: the numbers build the case, and the
## grade is the verdict on them.
func _play_reveal() -> void:
	Juice.pop_in(title_label)

	for i in range(rows_box.get_child_count()):
		await get_tree().create_timer(row_stagger).timeout
		if not is_instance_valid(self):
			return
		# Corrected from the brief: `var row: Control = ...` would not
		# compile against `row.play_count_up(...)` below -- play_count_up()
		# only exists on RunResultRow, not on Control. Typed to the actual
		# runtime class instead.
		var row: RunResultRow = rows_box.get_child(i)
		Juice.pop_in(row)
		row.play_count_up(count_up_seconds)
		if row == _money_row:
			AudioDirector.play_sfx(&"coin")
		else:
			AudioDirector.play_sfx(&"pop")

	await get_tree().create_timer(count_up_seconds + grade_delay).timeout
	if not is_instance_valid(self):
		return
	_slam_grade()


func _slam_grade() -> void:
	var tokens := DesignTokens.load_default()
	grade_letter.text = _grade_text
	grade_caption.text = String(GRADE_CAPTIONS.get(_grade_text, ""))
	grade_letter.add_theme_color_override("font_color",
		tokens.state_success if RunGrade.is_top_grade(_grade_text)
		else (tokens.state_danger if _grade_text == "D" else tokens.currency_gold))

	Juice.set_pivot_center(grade_letter)
	grade_letter.scale = Vector2(3.0, 3.0)
	grade_letter.modulate.a = 0.0

	var t := Juice.tokens()
	var tw := grade_letter.create_tween().set_parallel(true)
	tw.tween_property(grade_letter, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(grade_letter, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(grade_letter.get_parent(), 8.0)
		if RunGrade.is_top_grade(_grade_text):
			AudioDirector.play_sfx(&"reward")
		elif _grade_text == "D":
			AudioDirector.play_sfx(&"fail"))


## Applies the progression SemesterEnd used to apply, then goes home.
## Exactly the same three cases as before -- advance, beat-the-game reset,
## or retry the same grade -- just moved to the end of the sequence.
func _on_selesai_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	var destination := _apply_progression()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	Transition.change_scene(destination)


func _apply_progression() -> String:
	if GameState.run_failed:
		# A loss returns to the main menu; the normal MainMenu -> CutScene
		# bootstrap handles the restart from there (a fresh grade-7 run, or
		# the level-select modal if already unlocked).
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.run_stats.reset()
		GameState.run_failed = false
		return "res://Scenes/MainMenu/main_menu.tscn"

	if GameState.current_grade < 9:
		GameState.current_grade += 1
		GameState.reset_roster_for_new_grade()
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.returned_from_student_card = false
		GameState.lobby_tutorial_completed = true
		GameState.run_stats.reset()
		return "res://Scenes/StudentCard/student_card.tscn"
	else:
		# The game is beaten: unlock level select and reset to Kelas 7.
		# set_grade() resets current_grade/minggu_ke/run_stats/
		# is_exam_intro_cutscene/run_failed but NOT day_schedules -- confirmed
		# against the current Scripts/GameState.gd -- so it is cleared
		# explicitly here, matching the other two branches above.
		GameState.is_game_beaten = true
		GameSettings.save_settings()
		GameState.set_grade(7)
		GameState.day_schedules.clear()
		GameState.approved_students.clear()
		GameState.grade7_student_ids.clear()
		GameState.lobby_tutorial_completed = false

		# Tutorial flags, carried over from SemesterEnd's old grade-7
		# full-restart branch (see Scripts/CutScene/cut_scene.gd for the
		# same pattern still in use there).
		var AturJadwalScript = load("res://Scripts/AturJadwal/atur_jadwal.gd")
		if AturJadwalScript and "tutorial_phase1_done" in AturJadwalScript:
			AturJadwalScript.tutorial_phase1_done = false
			AturJadwalScript.tutorial_phase3_done = false
		var LobbyScript = load("res://Scripts/Lobby/loby.gd")
		if LobbyScript and "tutorial_shown" in LobbyScript:
			LobbyScript.tutorial_shown = false
		return "res://Scenes/MainMenu/main_menu.tscn"
