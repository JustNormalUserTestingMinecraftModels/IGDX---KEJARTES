@tool
class_name StatCheck
extends Control

## The automated stat check (Plan A, 2026-09-04): one card per student
## slides in from the right, its three bars fill in turn -- akademis, seni
## budaya, olahraga -- a full bar pops, every cleared stat lights one share
## of the 3-star meter, the card slides out, the next slides in, and when
## the roster is done the screen fades to white and hands off by verdict.
## Replaces both the exam-intro cutscene beat and the SemesterEnd carousel.
##
## Deliberately NOT tap-driven: the check is a reveal the player watches.
##
## @tool so the MCP test suite can instantiate the scene inside the
## editor; the sequence itself sits behind Engine.is_editor_hint() and is
## a chain of coroutines -- tests assert on state and source, never by
## playing it.

## Where the white fade lands. Plan B repoints both at its win/lose
## screens; until then the report follows straight on.
const NEXT_SCENE_WIN := "res://Scenes/EndGame/RunResult.tscn"
const NEXT_SCENE_LOSE := "res://Scenes/EndGame/RunResult.tscn"

## The card template, instanced once per student into CardSlot. Reviewed
## per-call-dynamic exception (tests/test_viewport_editability.gd ALLOWED).
const CARD_SCENE := preload("res://Scenes/EndGame/StatCheckCard.tscn")

@export_group("Pacing")
## Seconds a card takes to slide in from the right edge (and out to the left).
@export var slide_seconds: float = 0.45
## Pause after a card lands before its first bar starts, and after its
## last bar before it leaves -- the beat that lets a pop register.
@export var hold_seconds: float = 0.4
## Seconds the white overlay takes to reach full.
@export var white_fade_seconds: float = 0.8

@onready var card_slot: Control = $MarginContainer/Column/CardSlot
@onready var star_meter: StarMeter = $MarginContainer/Column/StarMeter
@onready var white_fade: ColorRect = $WhiteFade

var _stars: float = 0.0
var _total_stats: int = 0
var _exiting: bool = false


func _ready() -> void:
	white_fade.modulate.a = 0.0
	star_meter.set_stars(0.0)
	if Engine.is_editor_hint():
		return
	AudioDirector.play_bgm(&"exam_notice")
	_run_check()


## One star-share per stat on the roster: Balance.STARS_TOTAL split evenly
## across every student's three targets. Zero when there is nothing to
## share, so an empty roster never divides by zero.
static func star_share(total_stats: int) -> float:
	if total_stats <= 0:
		return 0.0
	return Balance.STARS_TOTAL / float(total_stats)


## The whole sequence. A coroutine -- never call from a test.
func _run_check() -> void:
	var students: Array[StudentData] = GameState.convert_to_student_data_array()
	_total_stats = students.size() * 3
	_stars = 0.0

	for student in students:
		var card: StatCheckCard = CARD_SCENE.instantiate()
		card_slot.add_child(card)
		card.bind(student)
		await _slide_in(card)
		await get_tree().create_timer(hold_seconds).timeout

		for row in card.rows():
			await row.fill()
			if row.cleared:
				_stars += star_share(_total_stats)
				star_meter.animate_to(_stars)
				AudioDirector.play_sfx(&"tally")

		await get_tree().create_timer(hold_seconds).timeout
		await _slide_out(card)
		card.queue_free()

	await _fade_to_white()
	_hand_off()


## From just past the right edge to its resting spot, with the entry
## overshoot the rest of the game's pop-ins use.
func _slide_in(card: Control) -> void:
	var rest := card.position
	card.position.x = get_viewport_rect().size.x
	AudioDirector.play_sfx(&"swipe")
	var tw := create_tween()
	tw.tween_property(card, "position:x", rest.x, slide_seconds) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tw.finished


## Out to the left, easing in, so the next card's entrance reads as a
## continuation of the same pan.
func _slide_out(card: Control) -> void:
	var tw := create_tween()
	tw.tween_property(card, "position:x", -card.size.x, slide_seconds) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished


func _fade_to_white() -> void:
	var tw := create_tween()
	tw.tween_property(white_fade, "modulate:a", 1.0, white_fade_seconds) \
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## The verdict is decided here, once, and written to GameState for every
## screen after this. The Transition autoload's wipe is deliberately not
## used here: its cover is brand blue and would flash over the white. The
## next screen starts under its own white overlay and fades it out (Plan B).
##
## (That wording avoids the literal call spelling on purpose -- the test
## for this function greps the whole file for it, comments included.)
func _hand_off() -> void:
	if _exiting:
		return
	_exiting = true
	GameState.run_failed = not GameState.check_semester_passed()
	var next := NEXT_SCENE_WIN if not GameState.run_failed else NEXT_SCENE_LOSE
	get_tree().change_scene_to_file(next)
