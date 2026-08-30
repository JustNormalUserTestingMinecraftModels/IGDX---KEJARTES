@tool
extends Control
class_name DaySummaryStudentRow

## One student's card in the Daily Results popup, built to
## dailyresults_mockup.png (spec:
## 2026-08-29-day-summary-mockup-design.md).
##
## The card background is art, placed at native size, so this scene
## positions its children at fixed card-relative offsets rather than
## letting containers negotiate. Every colour, font and stylebox comes
## from a ThemeFactory variation; nothing here builds a StyleBox.

## The three skills, in the mockup's top-to-bottom order, paired with
## the StudentData field holding each one's target. The pairing is the
## project's documented naming trap: target_akademis2 is the SENI
## target, target_akademis3 the OLAHRAGA one.
const STAT_ORDER := ["akademis", "seni_budaya", "olahraga"]
const TARGET_FOR := {
	"akademis": "target_akademis1",
	"seni_budaya": "target_akademis2",
	"olahraga": "target_akademis3",
}

## How far apart the card's three tracks start filling, in seconds. Short
## enough to read as one gesture, long enough that the eye catches each
## bar leaving the gate. Lives here rather than on the stat row because
## it is a property of the card's three-row rhythm, not of one row.
const GAIN_STEP := 0.08

@onready var avatar: DaySummaryAvatar = $Avatar
@onready var name_label: Label = $NameLabel
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var mood_bar: ProgressBar = $MoodBar
@onready var energy_delta_label: Label = $EnergyBar/DeltaLabel
@onready var mood_delta_label: Label = $MoodBar/DeltaLabel
@onready var stat_rows: Array[DaySummaryStatRow] = [
	$StatRow1, $StatRow2, $StatRow3,
]


## "+8" / "-12" -- the week's movement on a needs bar. Same sign rule as
## DaySummaryStatRow.format_value: the "+" is explicit and the "-" comes
## free from %d, so a loss never reads "+-12". Zero reads "+0" rather
## than blank, because an empty slot on the card looks like a bug.
static func format_needs_delta(delta: float) -> String:
	var d := int(round(delta))
	var sign_str := "+" if d >= 0 else ""
	return "%s%d" % [sign_str, d]


func setup_row(student_name: String, changes: Array, student: StudentData) -> void:
	name_label.text = student_name
	avatar.set_student(student)

	# The scene ships the mockup's 36/82 placeholders baked in. Leaving
	# them when the popup's name lookup misses would paint a confident,
	# fabricated reading, so an unknown student empties both bars --
	# matching the avatar, which already clears its texture on null.
	energy_bar.value = student.energy if student != null else 0.0
	mood_bar.value = student.mood if student != null else 0.0
	# The needs numbers belong to ResultCheckup's weekly card; the mockup
	# has none. Hidden explicitly rather than relying on the scene's
	# default, so a card re-armed from the weekly path is still correct.
	energy_delta_label.hide()
	mood_delta_label.hide()

	var deltas := _sum_deltas(changes)
	for i in STAT_ORDER.size():
		var key: String = STAT_ORDER[i]
		var target := 0.0
		var current := 0.0
		if student != null:
			target = float(student.get(TARGET_FOR[key]))
			# STAT_ORDER's keys are StudentData's own field names, so the
			# standing value reads straight off the resource -- it is only
			# the TARGET field names that carry the akademis2/3 naming trap.
			current = float(student.get(key))
		stat_rows[i].set_stat(key, deltas.get(key, 0.0), target, current)


## A stat can move more than once in a day -- a scheduled activity plus
## an event, say -- and the mockup shows one number per stat, so the
## day's changes are summed rather than shown one chip per source.
func _sum_deltas(changes: Array) -> Dictionary:
	var out := {}
	for ch in changes:
		var key := String(ch.get("stat_key", ""))
		if not TARGET_FOR.has(key):
			continue
		out[key] = float(out.get(key, 0.0)) + float(ch.get("delta", 0.0))
	return out


## Replay every stat track's growth for today, one row after the next.
## `delay` shifts the whole card, so the popup can line each card's fill
## up with its own staggered entrance.
func play_gain(delay: float = 0.0) -> void:
	for i in stat_rows.size():
		stat_rows[i].play_gain(delay + float(i) * GAIN_STEP)
