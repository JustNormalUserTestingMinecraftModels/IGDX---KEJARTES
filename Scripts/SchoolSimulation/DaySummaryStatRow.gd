@tool
extends Control
class_name DaySummaryStatRow

## One line of the Daily Results card: a white stat icon and a gold
## chevron sitting ON TOP of a dark track, with "+12/65" right-aligned
## and sitting ON TOP of the track's own right end -- not beside it in
## a separate column. The chevron shows only on a day that actually
## gained points for this stat -- see shows_chevron.
##
## 2026-09-03 follow-up: the number used to own a fixed-width column to
## the RIGHT of the track (VALUE_WIDTH), so the track visibly ended
## before the row did. That does not match the reference mockup, where
## the track runs the full row and the number is white text laid over
## its right end, the same way the needs bars carry their tier word.
## Track now spans (almost) the full row (TRACK_RIGHT_MARGIN); Value
## spans the same width and is drawn last, so it paints on top.

## Geometry in game pixels, measured off the mockup (spec section 2).
##
## The icon is drawn ON TOP of the track's left end, so every pixel it
## covers is a pixel of fill the player can never see -- keep ICON_BOX
## well under half the row width, or a partly-full stat reads as an
## empty bar. See test_stat_row_icon_does_not_hide_most_of_the_track.
const ROW_HEIGHT := 96
const TRACK_HEIGHT := 36
const TRACK_LEFT := 0
const ICON_BOX := Vector2(110, 81)
const ICON_LEFT := -17
const CHEVRON_BOX := Vector2(46, 67)
const CHEVRON_LEFT := 100
## How far the track's right edge sits from the row's own right edge --
## a small margin so the fill's rounded cap does not touch the card's
## own edge.
const TRACK_RIGHT_MARGIN := 8
## How far the number's right edge sits from the row's own right edge.
## Slightly more than TRACK_RIGHT_MARGIN so the text reads with a
## little breathing room inside the track's rounded cap rather than
## running flush against it.
const VALUE_RIGHT_MARGIN := 20

## The authored one-shot burst thrown at a row that gained. Instanced,
## never built -- see the project's "no visual is built at runtime" rule.
const BURST_SCENE := "res://Scenes/SchoolSimulation/RewardBurst.tscn"

const ICON_FOR := {
	"akademis": "res://Assets/Images/DaySummary/icon_akademis.png",
	"seni_budaya": "res://Assets/Images/DaySummary/icon_seni.png",
	"olahraga": "res://Assets/Images/DaySummary/icon_olahraga.png",
}

## Which baked variation each stat's track wears. The fills are the
## category colours, so the three rows read apart the way the icons do.
const TRACK_VARIATION_FOR := {
	"akademis": &"DaySummaryStatTrackAkademis",
	"seni_budaya": &"DaySummaryStatTrackSeniBudaya",
	"olahraga": &"DaySummaryStatTrackOlahraga",
}

@onready var icon: TextureRect = $Icon
@onready var chevron: TextureRect = $Chevron
@onready var track: ProgressBar = $Track
@onready var value: Label = $Value

## Where the track sat this morning and where it sits tonight, cached by
## set_stat so play_gain can rewind and grow back. set_stat itself still
## lands the track on the final value, so a row that is never animated is
## still correct.
var _fill_from: float = 0.0
var _fill_to: float = 0.0

## The day's (or week's) raw delta and its target, cached by set_stat so
## play_gain can count the "+12/65" label up from zero the same way it
## rewinds the track -- see play_gain.
var _delta: float = 0.0
var _target: float = 0.0


## "+12/65" -- the sign rides with the number so a loss reads "-3/65"
## rather than "+-3/65".
static func format_value(delta: float, target: float) -> String:
	var d := int(round(delta))
	var sign_str := "+" if d >= 0 else ""
	return "%s%d/%d" % [sign_str, d, int(round(target))]


## How full the track sits, 0-100. A full bar means the student has
## reached the target set for this run -- so this is the STANDING stat
## over its target, not the day's gain, which the number beside it
## already carries.
##
## A target of zero reaches this whenever a row is built with no
## StudentData; returning 0 there is what keeps it off a divide by zero.
static func track_ratio(current: float, target: float) -> float:
	if target <= 0.0:
		return 0.0
	return clampf(current / target * 100.0, 0.0, 100.0)


## How full the track stood BEFORE today. The day's gain has already been
## applied to the StudentData by the time the popup is built, so the
## starting point is the standing value minus the day's delta.
##
## StudentData clamps its stats when it applies them, so on a day that hit
## the 0 or 100 ceiling, current - delta overshoots the true morning value
## slightly and the bar travels a touch further than it really did. That is
## cosmetic, and is preferred over threading a pre-day snapshot through the
## whole simulation for the sake of one animation.
##
## A second and larger source of under-travel: random events apply their
## stat boosts straight to StudentData but never route them through
## StudentManager.log_stat_change(), so they are absent from the day
## summary and therefore from `delta`. On an event day the bar starts
## too high and the growth understates what really happened. The fix
## belongs in SchoolDay's record_event_result calls, not here.
static func track_ratio_before(current: float, delta: float, target: float) -> float:
	return track_ratio(current - delta, target)


## Whether the gold chevron shows for this day's movement. The asset is
## an UP arrow and there is no down variant, so it appears only on a real
## gain -- a stat that did not move, or that lost ground, shows the bare
## track instead of an arrow pointing the wrong way.
##
## The chevron is an absolutely-anchored overlay on the track, so hiding
## it reflows nothing: the icon and the number stay exactly where they are.
static func shows_chevron(delta: float) -> bool:
	return delta > 0.0


func set_stat(stat_key: String, delta: float, target: float, current: float) -> void:
	if ICON_FOR.has(stat_key):
		icon.texture = load(ICON_FOR[stat_key])
	if TRACK_VARIATION_FOR.has(stat_key):
		track.theme_type_variation = TRACK_VARIATION_FOR[stat_key]
	_delta = delta
	_target = target
	value.text = format_value(delta, target)
	# play_gain hands the chevron to Juice.pop_in, which zeroes its alpha and
	# shrinks it before tweening both back. Re-arming a row for another
	# student must undo that, or a row that is set up but never animated
	# shows an invisible arrow.
	chevron.visible = shows_chevron(delta)
	chevron.modulate.a = 1.0
	chevron.scale = Vector2.ONE
	_fill_from = track_ratio_before(current, delta, target)
	_fill_to = track_ratio(current, target)
	track.value = _fill_to


## Replay today's movement: rewind the track to where it stood this
## morning and grow it back to where set_stat already left it, popping
## the chevron in over the same beat and -- on a day that actually
## gained -- throwing a star burst from the chevron. `delay` holds the
## whole gesture so a card can stagger its three rows.
##
## `plays_sparkle` lets the card suppress the sparkle cue on the second and
## later bursts of one gesture, so three gaining rows do not fire three
## sparkle cues 80 ms apart; see DaySummaryStudentRow.play_gain. The tally
## tick is a separate decision and always plays on a real gain, regardless
## of `plays_sparkle`.
##
## Never awaited and never required -- set_stat has already written the
## final value, so a caller that skips this sees a correct, static card.
##
## Call set_stat first: this reads the two ends it cached, which default
## to 0.0 and would otherwise empty the track.
func play_gain(delay: float = 0.0, plays_sparkle: bool = true) -> void:
	track.value = _fill_from
	Juice.fill_bar(track, _fill_to, -1.0, delay)
	if chevron.visible:
		Juice.pop_in(chevron, delay)
		_play_burst(delay, plays_sparkle)
	Juice.count_up_formatted(value, 0.0, _delta,
		func(v: float) -> String: return format_value(v, _target), delay)


## The gain's reward: a star burst centred on the chevron, plus the tally
## tick on the same beat -- the tally always plays on a real gain; only
## the burst's own sparkle cue is deduplicated across a card's gesture
## (see DaySummaryStudentRow.play_gain). Editor-gated -- the test runner
## builds these rows to inspect them, not to watch them.
func _play_burst(delay: float, plays_sparkle: bool) -> void:
	if Engine.is_editor_hint():
		return
	var burst_scene: PackedScene = load(BURST_SCENE)
	var fx := burst_scene.instantiate() as RewardParticles
	fx.plays_sfx = plays_sparkle
	fx.position = chevron.position + chevron.size * 0.5
	add_child(fx)
	fx.fire(delay)
	AudioDirector.play_sfx(&"tally")
