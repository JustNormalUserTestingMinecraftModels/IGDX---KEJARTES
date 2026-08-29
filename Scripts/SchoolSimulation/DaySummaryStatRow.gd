@tool
extends Control
class_name DaySummaryStatRow

## One line of the Daily Results card: a white stat icon and a gold
## chevron sitting ON TOP of a dark track, with "+12/65" right-aligned
## on the card fill beside it.
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

@onready var icon: TextureRect = $Icon
@onready var chevron: TextureRect = $Chevron
@onready var track: ProgressBar = $Track
@onready var value: Label = $Value


## "+12/65" -- the sign rides with the number so a loss reads "-3/65"
## rather than "+-3/65".
static func format_value(delta: float, target: float) -> String:
	var d := int(round(delta))
	var sign_str := "+" if d >= 0 else ""
	return "%s%d/%d" % [sign_str, d, int(round(target))]


func set_stat(stat_key: String, delta: float, target: float) -> void:
	if ICON_FOR.has(stat_key):
		icon.texture = load(ICON_FOR[stat_key])
	value.text = format_value(delta, target)
	# The track is decorative in the mockup -- it reads as a rail the
	# chevron sits on, not as a gauge -- so it stays full rather than
	# encoding delta a second time next to the number that already says it.
	track.value = track.max_value
