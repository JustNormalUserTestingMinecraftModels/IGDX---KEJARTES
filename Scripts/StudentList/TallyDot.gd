@tool
class_name TallyDot
extends Panel

## One dot of RosterCard's five-dot "hari terjadwal" tally, the row beside
## the WeekHeader's "n/5 hari" count (MURIDMU RosterCard spec 3.2). A
## PackedScene template (Scenes/StudentList/TallyDot.tscn) authored five
## times under RosterCard's DayTally -- the repeated-row rule: a template,
## never five dots built at runtime.
##
## The look is two ThemeFactory variations, swapped on theme_type_variation
## rather than tinted, so no colour ever lives in this script: TallyDotFilled
## (a solid accent_mint pill, the palette's "affirm") and TallyDotEmpty (a
## ringed surface_sunken pill). RosterCard.days_scheduled decides which dots
## are filled; this script only owns how one dot shows it and how it pops.
##
## @tool so the Inspector and the MCP test suite see the applied look, with
## the setter guarded on is_node_ready() -- StickyNote.gd's pattern.

## The variation a scheduled day's dot wears.
const FILLED_VARIATION := &"TallyDotFilled"

## The variation an unscheduled day's dot wears.
const EMPTY_VARIATION := &"TallyDotEmpty"

## True when the day this dot stands for is scheduled: swaps the dot to the
## solid mint TallyDotFilled look; false shows the ringed kraft
## TallyDotEmpty look.
@export var filled: bool = false:
	set(value):
		filled = value
		if is_node_ready():
			_apply_filled()


func _ready() -> void:
	_apply_filled()


func _apply_filled() -> void:
	theme_type_variation = FILLED_VARIATION if filled else EMPTY_VARIATION


## A coin-counter style scale pop (AnimUtils.coin_pulse, the same bounce
## the coin display uses when money lands), for the moment a dot fills --
## RosterCard.play_entry() pops the first days_scheduled dots in turn.
## Returns the one-shot Tween, or null when nothing plays: in the editor,
## outside the tree, or under GameSettings.reduce_motion.
func pop() -> Tween:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	if GameSettings.reduce_motion:
		return null
	return AnimUtils.coin_pulse(self)
