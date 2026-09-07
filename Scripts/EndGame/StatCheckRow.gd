@tool
class_name StatCheckRow
extends HBoxContainer

## One subject row on a StatCheck card: an icon and a StatBar, nothing
## else -- the mockup shows no numbers. Replaces SemesterEnd's
## ResultStatRow, which carried a title and a value label the new design
## dropped.
##
## Two-phase on purpose. set_result() only arms the target ratio and
## leaves the bar empty; fill() is the animated beat StatCheck plays for
## each row in turn, and it is the only thing that moves the bar. A full
## fill pops -- squash, an authored RewardBurst, the pop cue -- and reports
## `cleared` so the card's star meter can count it.

## One of StatBar's categories: Akademis, SeniBudaya, Olahraga.
@export var category: String = "Akademis":
	set(value):
		category = value
		if is_node_ready():
			bar.category = value

## Subject icon shown on Icon.
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			icon_rect.texture = value

## Seconds a fill takes from empty to its target ratio. Slower than
## Juice's dur_slow because this is the whole beat, not a settle.
@export var fill_seconds: float = 0.9

## Emitted when fill() finishes; true when the bar reached 100.
signal filled(cleared: bool)

## The authored one-shot burst thrown at a full bar. Instanced, never
## built -- see the project's "no visual is built at runtime" rule.
const BURST_SCENE := "res://Scenes/SchoolSimulation/RewardBurst.tscn"

## Where the fill will stop, 0-100. Armed by set_result().
var target_ratio: float = 0.0
## True once fill() has played to 100.
var cleared: bool = false

@onready var icon_rect: TextureRect = $Icon
@onready var bar: StatBar = $Bar


func _ready() -> void:
	bar.category = category
	# Only push the export down when it actually carries one. Unset, it is
	# null, and assigning it unconditionally wiped the icon authored on
	# Icon in StatCheckRow.tscn for any instance that did not override it.
	if icon != null:
		icon_rect.texture = icon
	else:
		icon = icon_rect.texture
	bar.value = 0.0


## value ÷ target as a 0-100 percentage, capped so a stat past its target
## reads as exactly full. A zero target reads as empty rather than
## dividing by zero -- the case when a row is armed with no StudentData.
##
## Reaching 100 is what makes a row `cleared`, so this must agree with
## GameState.target_cleared(), which decides the run's verdict. Both treat
## a zero target as not cleared; if you relax one, relax both, or the star
## meter and the win/lose routing will disagree on screen.
static func ratio(value: float, target: float) -> float:
	if target <= 0.0:
		return 0.0
	return clampf(value / target * 100.0, 0.0, 100.0)


## Arm the row. Does not animate: the bar stays empty until fill().
func set_result(value: float, target: float) -> void:
	target_ratio = ratio(value, target)
	cleared = false
	bar.value = 0.0


## The beat. A coroutine -- StatCheck awaits it row by row; never call it
## from a test (the MCP runner does not await).
func fill() -> void:
	# Juice.fill_bar returns null for a dead node; awaiting .finished on
	# that is a hard null-deref, so refuse rather than crash.
	var tween: Tween = Juice.fill_bar(bar, target_ratio, fill_seconds)
	if tween == null:
		return
	await tween.finished
	if not is_inside_tree():
		return
	if target_ratio >= 100.0:
		cleared = true
		pop()
	filled.emit(cleared)


## The satisfying part: a scale-only squash (Juice.pop_in would blink the
## bar transparent), a burst off the bar's right cap, and the pop cue.
func pop() -> void:
	AnimUtils.squash_bounce(bar)
	var burst: RewardParticles = load(BURST_SCENE).instantiate()
	add_child(burst)
	burst.position = bar.position + Vector2(bar.size.x, bar.size.y * 0.5)
	burst.plays_sfx = false
	burst.fire()
	AudioDirector.play_sfx(&"pop")
