@tool
extends Control
class_name DaySummaryStatRow

## One line of the Daily Results card: a white stat icon and a gold
## chevron sitting ON TOP of a dark track, with "+12/65" right-aligned
## on the card fill beside it. The chevron shows only on a day that
## actually gained points for this stat -- see shows_chevron.
##
## The track's right edge is the number's left edge -- in the mockup a
## wider number ("+12/65") pushes the track shorter than a narrow one
## ("+9/65"). That falls out of the anchors below: the number is
## right-aligned and shrink-sized, the track expands into what is left.

## Geometry in game pixels, measured off the mockup (spec section 2).
const ROW_HEIGHT := 96
const TRACK_HEIGHT := 36
const TRACK_LEFT := 0
const ICON_BOX := Vector2(95, 70)
const ICON_LEFT := -15
const CHEVRON_BOX := Vector2(40, 58)
const CHEVRON_LEFT := 67
const VALUE_WIDTH := 200

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
	value.text = format_value(delta, target)
	chevron.visible = shows_chevron(delta)
	_fill_from = track_ratio_before(current, delta, target)
	_fill_to = track_ratio(current, target)
	track.value = _fill_to


## Replay today's movement: rewind the track to where it stood this
## morning and grow it back to where set_stat already left it, popping
## the chevron in over the same beat. `delay` holds the whole gesture so
## a card can stagger its three rows.
##
## Never awaited and never required -- set_stat has already written the
## final value, so a caller that skips this sees a correct, static card.
func play_gain(delay: float = 0.0) -> void:
	track.value = _fill_from
	Juice.fill_bar(track, _fill_to, -1.0, delay)
	if chevron.visible:
		Juice.pop_in(chevron, delay)
