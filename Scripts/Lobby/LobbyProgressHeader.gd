@tool
class_name LobbyProgressHeader
extends Panel

## The Lobby's top-left progress plate (2026-09-27 scrapbook HUD spec §3.1):
## the grade badge, "Minggu N / total" and the run's star bar toward
## Balance.STARS_TOTAL. Reads GameState only when the Lobby calls refresh()
## down; announces nothing. @tool so the lobby_hud suite can call refresh()
## on a Lobby it instances. It has no _ready side effects, so an editor
## save never bakes a drawn state into Lobby.tscn.

## The week line: the week, then the grade's length.
const WEEK_FORMAT := "Minggu %d / %d"
## The star line: the run's stars over the total, as the spec's "2.0 / 3.0".
const STAR_FORMAT := "%.1f / %.1f"

## Seconds the star bar takes to slide to a new count.
@export var fill_seconds: float = 0.6

## The count this session last drew. Session memory, not persistence: the
## bar slides from here on the next Lobby entry and sparkles on a rise (Q8).
static var _last_shown_stars: float = 0.0

@onready var grade_number: Label = %GradeNumber
@onready var week_label: Label = %WeekLabel
@onready var star_bar: ProgressBar = %StarBar
@onready var star_label: Label = %StarNum
@onready var tip_sparkle: CPUParticles2D = %TipSparkle


## Draws the grade, the week and the stars from GameState.
func refresh() -> void:
	grade_number.text = str(GameState.current_grade)
	week_label.text = WEEK_FORMAT % [GameState.minggu_ke, GameState.max_minggu]
	var stars: float = GameState.run_stars()
	star_label.text = STAR_FORMAT % [stars, Balance.STARS_TOTAL]
	_slide_bar(_last_shown_stars, stars)
	_last_shown_stars = stars


## Slides the bar from `from_stars` to `to_stars`; a rise sparkles at the
## new tip. Under reduce_motion it simply lands.
func _slide_bar(from_stars: float, to_stars: float) -> void:
	star_bar.max_value = Balance.STARS_TOTAL
	star_bar.value = from_stars
	if GameSettings.reduce_motion or is_equal_approx(from_stars, to_stars):
		star_bar.value = to_stars
		return
	Juice.fill_bar(star_bar, to_stars, fill_seconds)
	if to_stars > from_stars:
		_sparkle_at(to_stars)


## Moves the one-shot sparkle to where the bar will end, and fires it.
func _sparkle_at(stars: float) -> void:
	var tip_x: float = star_bar.size.x * stars / Balance.STARS_TOTAL
	# TipSparkle is StarBar's child, so tip_x is already in the bar's frame.
	tip_sparkle.position = Vector2(tip_x, tip_sparkle.position.y)
	tip_sparkle.restart()
