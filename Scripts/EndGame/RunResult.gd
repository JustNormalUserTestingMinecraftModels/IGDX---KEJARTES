extends Control

## The last screen of a run: what the player actually did this grade,
## reported as four counted-up figures and one letter grade.
##
## Deliberately NOT @tool -- like StatCheck and StudentCard, _ready()
## reads GameState, starts BGM and kicks off a tween chain, none of which
## should fire because the editor opened the scene. Its tests are
## therefore source-text scans plus structural checks on a bare
## instantiate(), never live property reads.
##
## This screen also owns grade progression, which used to live in
## SemesterEnd._on_restart_pressed() (SemesterEnd has since been deleted,
## replaced by StatCheck). It moved here because RunResult is
## now the last thing a run touches, and progression has to happen exactly
## once, after the report has been read.

@export_group("Reveal Timing")
## Delay between each report row appearing.
@export var row_stagger: float = 0.14
## How long each row's number takes to count up.
@export var count_up_seconds: float = 0.7
## Pause after the last row before the letter grade slams in.
@export var grade_delay: float = 0.5

@export_group("Backdrop blur")
## Blur strength, as a screen-texture mip level. Must equal EndCutscene's
## blur_lod -- the hand-off is only invisible if both match.
@export var blur_lod: float = 3.0
## Dim applied with the blur, 0-1. Must equal EndCutscene's blur_darkness.
## This replaced the old Scrim panel, which at 0.72 alpha was far darker
## than the blur and made the swap read as a sudden drop in brightness.
@export var blur_darkness: float = 0.3

@export_group("Rank badges")
## Shown for an S rank. The art draws its own letter and RANK ribbon, so
## there is no text label beside it.
@export var rank_badge_s: Texture2D
## Shown for an A rank.
@export var rank_badge_a: Texture2D
## Shown for a B rank.
@export var rank_badge_b: Texture2D
## Shown for a C rank.
@export var rank_badge_c: Texture2D
## Shown for a D rank, which is also every failed run.
@export var rank_badge_d: Texture2D

## Seconds the report and its Room take to fade out on Selesai.
const EXIT_FADE_SECONDS := 0.4

## The painting, the letterbox bars and the posed roster: the same scene
## EndCutscene shows, dressed the same way (_dress_backdrop()).
@onready var win_stage: WinStage = %WinStage
## The World layer's one Control. A CanvasLayer ignores this screen's own
## modulate, so the exit fade fades the Room too (lobby-look amendment 1).
@onready var room: Control = %Room
## Between WinStage and the report UI: the shader samples what is already
## drawn, so the image blurs and the report stays sharp.
@onready var blur_layer: ColorRect = $BlurLayer
@onready var rows_box: VBoxContainer = $MarginContainer/Column/RowsBox
@onready var grade_badge: TextureRect = $MarginContainer/Column/GradeCard/GradeStack/GradeBadge
@onready var grade_caption: Label = $MarginContainer/Column/GradeCard/GradeStack/GradeCaption
@onready var title_label: Label = $MarginContainer/Column/TitleLabel
@onready var btn_selesai: Button = $MarginContainer/Column/BtnSelesai
@onready var ambient_pass: Control = $AmbientPass
@onready var ambient_fail: Control = $AmbientFail

const ROW_SCENE := preload("res://Scenes/EndGame/RunResultRow.tscn")

## The report's four icons, preloaded so a row swap costs nothing at
## reveal time. Authored art (gamewin, gamelose, coin, event), transparent PNGs.
const ICON_MINIGAME_MENANG := preload("res://Assets/Images/EndGame/Icons/gamewin_icon.png")
const ICON_MINIGAME_KALAH := preload("res://Assets/Images/EndGame/Icons/gamelose_icon.png")
const ICON_UANG := preload("res://Assets/Images/EndGame/Icons/coin_icon.png")
const ICON_EVENT := preload("res://Assets/Images/EndGame/Icons/event_icon.png")

## One caption per rank, so the grade says something rather than just
## scoring something.
const GRADE_CAPTIONS := {
	"S": "Sempurna. Tidak ada yang tertinggal.",
	"A": "Luar biasa. Kelas ini beruntung punya kamu.",
	"B": "Baik. Targetnya tercapai.",
	"C": "Lulus tipis. Lain kali lebih awal.",
	"D": "Belum berhasil. Mereka masih menunggumu.",
}

## The first-run tutorial flags a beaten game resets, by the script that owns
## them as static vars. StudentList's walkthrough flag once pointed at Lobby.gd,
## which has none, and the old silent guard hid it.
##
## Deliberately an untyped Dictionary of plain Arrays. It was once typed
## `Dictionary[String, PackedStringArray]` over Array literals, and iterating it
## in _apply_progression() handed back empty flag names and then hard-crashed
## Godot 4.6.2 (signal 11) the moment a beaten game pressed Selesai.
const TUTORIAL_FLAGS := {
	"res://Scripts/AturJadwal/AturJadwal.gd": ["tutorial_phase1_done", "tutorial_phase3_done"],
	"res://Scripts/StudentList/StudentList.gd": ["tutorial_shown"],
}

var _grade_text: String = "D"
var _money_row: Control = null
var _exiting: bool = false
## The verdict _compute_grade reached; _dress_ambience reads it.
var _passed: bool = false


func _ready() -> void:
	btn_selesai.pressed.connect(_on_selesai_pressed)
	btn_selesai.text = exit_label(GameState.run_failed, GameState.current_grade)
	AudioDirector.play_bgm(&"run_result")

	_dress_backdrop()

	title_label.text = "Hasil %s" % GameState.get_grade_name()
	grade_badge.texture = null
	grade_caption.text = ""

	_build_rows()
	_compute_grade()
	_dress_ambience()
	_play_reveal()


## Opens on the frame EndCutscene blurred out on -- literally the same
## scene, WinStage, dressed by the same call from the same two inputs, then
## blurred by the same shader at the same strength and dim. StatCheck
## decided the verdict and EndCutscene already showed it -- this only
## re-dresses, it never recomputes.
##
## The blur is live rather than a pre-blurred image so the two screens cannot
## drift apart: one shader, one pair of numbers, both read from exports that
## a test pins to EndCutscene's.
func _dress_backdrop() -> void:
	win_stage.dress(GameState.run_failed, WinStage.names_of(GameState.approved_students))
	var mat: ShaderMaterial = blur_layer.material
	mat.set_shader_parameter("lod", blur_lod)
	mat.set_shader_parameter("darkness", blur_darkness)
	blur_layer.show()


## The four rows are instanced from RunResultRow.tscn rather than authored
## in this scene. Reviewed exception to the no-runtime-construction rule
## (per-call-dynamic content): the row count is fixed, but every value is
## run-dependent, and authoring four frozen rows would mean four near-empty
## nodes plus a parallel wiring table. Registered in
## tests/test_viewport_editability.gd's ALLOWED dict, not BASELINE.
func _build_rows() -> void:
	var stats: RunStats = GameState.run_stats
	var spec := [
		[ICON_MINIGAME_MENANG, "Minigame selesai", float(stats.minigames_won), ""],
		[ICON_MINIGAME_KALAH, "Minigame kalah", float(stats.minigames_lost), ""],
		[ICON_UANG, "Uang dari wirausaha", float(stats.wirausaha_money), "G"],
		[ICON_EVENT, "Event yang diikuti", float(stats.events_attended), ""],
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
	_passed = not GameState.run_failed and GameState.check_semester_passed()
	var run_score := RunGrade.score(GameState.run_stats,
		int(counted[0]), int(counted[1]), GameState.approved_students.size())
	_grade_text = RunGrade.letter(run_score, _passed)


## The ambient kit's two moods (spec 2026-09-26, section 2): warm light and
## sparkles for a pass, a blue night and slow dust for a fail. Both groups
## are authored in the scene; this only picks one, from the verdict the
## grade letter used, and takes the glint off a failing badge.
##
## EndCutscene hands over to RunResult with an invisible scene swap (the same
## blurred WinStage, redrawn) -- so the chosen mood must not appear on frame
## one. It starts transparent and fades in over Juice.tokens().dur_slow, the
## same token source MainMenu.gd uses for its own fade-ins.
func _dress_ambience() -> void:
	ambient_pass.visible = _passed
	ambient_fail.visible = not _passed
	if not _passed:
		grade_badge.material = null
	var shown: Control = ambient_pass if _passed else ambient_fail
	shown.modulate.a = 0.0
	create_tween().tween_property(shown, "modulate:a", 1.0, Juice.tokens().dur_slow)


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


## The badge for a rank. Falls back to D, which is also the failed-run
## rank, so an unmapped string can never leave the card empty.
func _badge_for(rank: String) -> Texture2D:
	match rank:
		"S": return rank_badge_s
		"A": return rank_badge_a
		"B": return rank_badge_b
		"C": return rank_badge_c
		_: return rank_badge_d


func _slam_grade() -> void:
	grade_badge.texture = _badge_for(_grade_text)
	grade_caption.text = String(GRADE_CAPTIONS.get(_grade_text, ""))

	Juice.set_pivot_center(grade_badge)
	grade_badge.scale = Vector2(3.0, 3.0)
	grade_badge.modulate.a = 0.0

	var t := Juice.tokens()
	var tw := grade_badge.create_tween().set_parallel(true)
	tw.tween_property(grade_badge, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(grade_badge, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(grade_badge.get_parent(), 8.0)
		if RunGrade.is_top_grade(_grade_text):
			RewardFeedback.play(&"run_win", self)
		elif _grade_text == "D":
			AudioDirector.play_sfx(&"fail"))


## Applies the progression SemesterEnd used to apply (before it was deleted
## and replaced by StatCheck), then goes home.
## Exactly the same three cases as before -- advance, beat-the-game reset,
## or retry the same grade -- just moved to the end of the sequence.
func _on_selesai_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	AudioDirector.play_sfx(&"confirm")
	var destination := _apply_progression()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, EXIT_FADE_SECONDS)
	tween.parallel().tween_property(room, "modulate:a", 0.0, EXIT_FADE_SECONDS)
	await tween.finished
	Transition.change_scene(destination)


## The first grade: losing it restarts the whole run from the menu.
const FIRST_GRADE: int = 7
## The last grade: passing it beats the game.
const FINAL_GRADE: int = 9
## Where a full restart, or a beaten game, ends up.
const MENU_SCENE := "res://Scenes/MainMenu/MainMenu.tscn"
## Where the next grade, or a retry of this one, picks its roster.
const ROSTER_SCENE := "res://Scenes/StudentCard/StudentCard.tscn"


## Where a run that `run_failed` at `grade` goes next: the menu for a Kelas 7
## loss or a beaten Kelas 9, otherwise the roster (a retry of this grade, or
## the next one). The one place that decides; _apply_progression() and
## exit_label() both read it.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func destination_for(run_failed: bool, grade: int) -> String:
	if run_failed:
		return MENU_SCENE if grade == FIRST_GRADE else ROSTER_SCENE
	return ROSTER_SCENE if grade < FINAL_GRADE else MENU_SCENE


## The exit button's label, naming where destination_for() sends the player.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func exit_label(run_failed: bool, grade: int) -> String:
	if destination_for(run_failed, grade) == MENU_SCENE:
		return "Kembali ke Menu"
	return "Ulangi Kelas %d" % grade if run_failed else "Lanjut ke Kelas %d" % (grade + 1)


func _apply_progression() -> String:
	var destination := destination_for(GameState.run_failed, GameState.current_grade)
	if GameState.run_failed:
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		# The retry's week 1 is a new week: without this it would reuse the
		# lost attempt's Koperasi shelf and sold list (same grade, week 1).
		GameState.reset_shop_week()
		GameState.run_stats.reset()
		GameState.run_failed = false
		if destination == MENU_SCENE:
			# Grade-7 loss: full restart. Clear everything and go to MainMenu;
			# the MainMenu -> CutScene bootstrap picks up from there.
			GameState.approved_students.clear()
			GameState.grade7_student_ids.clear()
			GameState.grade8_student_ids.clear()
			GameState.returned_from_student_card = false
			return destination
		else:
			# Grade 8/9 loss: retry the same grade at StudentCard. Keep the
			# roster and grade7_student_ids so locked students stay locked and
			# the player only needs to re-pick the new-grade slot(s).
			GameState.returned_from_student_card = false
			return destination

	Achievements.record_grade_passed(GameState.current_grade)
	if destination == ROSTER_SCENE:
		GameState.current_grade += 1
		GameState.reset_roster_for_new_grade()
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.returned_from_student_card = false
		GameState.lobby_tutorial_completed = true
		GameState.run_stats.reset()
		return destination
	else:
		# The game is beaten: unlock level select and reset to Kelas 7.
		# set_grade() resets current_grade/minggu_ke/run_stats/
		# is_exam_intro_cutscene/run_failed but NOT day_schedules -- confirmed
		# against the current Scripts/GameState.gd -- so it is cleared
		# explicitly here, matching the other two branches above. Since
		# Finding 1's fix, set_grade() also calls reset_roster_for_new_grade()
		# and rebases the roster -- moot here, since approved_students is
		# cleared two lines below anyway.
		GameState.is_game_beaten = true
		GameSettings.save_settings()
		GameState.set_grade(FIRST_GRADE)
		GameState.day_schedules.clear()
		GameState.approved_students.clear()
		GameState.grade7_student_ids.clear()
		GameState.grade8_student_ids.clear()
		GameState.lobby_tutorial_completed = false

		# A beaten game replays the first-run tutorials.
		for path in TUTORIAL_FLAGS:
			for flag in TUTORIAL_FLAGS[path]:
				_reset_static_flag(String(path), String(flag))
		return destination


## Sets the static bool `flag` on the script at `path` back to false. The
## screens that own the tutorial flags have no class_name, so they are reached
## by path; a script or flag that is not there is an error, never a silent skip.
static func _reset_static_flag(path: String, flag: String) -> void:
	var script := load(path) as GDScript
	if script == null or not flag in script:
		push_error("RunResult: no static %s on %s to reset" % [flag, path])
		return
	script.set(flag, false)
