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

## Where the two needs bars stood before today's (or this week's) gain,
## cached by setup_row/setup_week_row so play_gain can rewind and travel
## back.
var _energy_from: float = 0.0
var _mood_from: float = 0.0

## The week's raw energy/mood deltas, cached by setup_week_row so
## play_gain can count the "+8"/"-12" labels up from zero alongside the
## bars they sit beside. setup_row never shows these labels, so they
## stay 0.0 there.
var _energy_delta: float = 0.0
var _mood_delta: float = 0.0


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

	var needs_deltas := _sum_needs_deltas(changes)
	_energy_from = clampf(energy_bar.value - needs_deltas.get("energy", 0.0), 0.0, 100.0)
	_mood_from = clampf(mood_bar.value - needs_deltas.get("mood", 0.0), 0.0, 100.0)

	_write_stat_rows(_sum_deltas(changes), student)


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


## Same idea as _sum_deltas, but for the two needs bars -- energy or mood
## can also move more than once in a day, and TARGET_FOR (the filter
## _sum_deltas applies) only ever holds the three skills, so needs need
## their own small sum rather than a shared one.
func _sum_needs_deltas(changes: Array) -> Dictionary:
	var out := {"energy": 0.0, "mood": 0.0}
	for ch in changes:
		var key := String(ch.get("stat_key", ""))
		if key == "energy" or key == "mood":
			out[key] = float(out[key]) + float(ch.get("delta", 0.0))
	return out


## The three stat rows, given one delta per stat. Shared by the daily and
## weekly entry points, which differ ONLY in where their deltas come
## from -- a card that drew its rows two different ways would drift, and
## the akademis2/3 naming trap below is the last thing that should be
## written down twice.
func _write_stat_rows(deltas: Dictionary, student: StudentData) -> void:
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


## The same card, one week wide: ResultCheckup's end-of-week report.
##
## Every delta here is "now minus Monday morning", straight off the
## week-start snapshot record_initial_stats() takes when GameState
## converts the roster -- StudentManager is rebuilt at the top of every
## week, so no snapshot has to be threaded through the simulation.
##
## Two things separate this from setup_row: the deltas span the week
## rather than the day, and the two needs numbers are shown. The stat
## rows themselves need no special case -- DaySummaryStatRow already
## rewinds to (current - delta) / target, which IS Monday's ratio once
## the delta is a week long.
func setup_week_row(student: StudentData) -> void:
	name_label.text = student.student_name if student != null else ""
	avatar.set_student(student)

	if student == null:
		energy_bar.value = 0.0
		mood_bar.value = 0.0
		_energy_from = 0.0
		_mood_from = 0.0
		_energy_delta = 0.0
		_mood_delta = 0.0
		energy_delta_label.hide()
		mood_delta_label.hide()
		_write_stat_rows({}, null)
		return

	var energy_delta := student.get_energy_delta()
	var mood_delta := student.get_mood_delta()
	energy_bar.value = student.energy
	mood_bar.value = student.mood
	# StudentData clamps its needs as it applies them, so on a week that
	# hit the 0 or 100 ceiling this opening value overshoots the true
	# Monday reading slightly and the bar travels a touch further than it
	# really did. Cosmetic, and the same trade DaySummaryStatRow already
	# documents for the stat tracks.
	_energy_from = clampf(student.energy - energy_delta, 0.0, 100.0)
	_mood_from = clampf(student.mood - mood_delta, 0.0, 100.0)
	_energy_delta = energy_delta
	_mood_delta = mood_delta
	_show_needs_delta(energy_delta_label, energy_delta)
	_show_needs_delta(mood_delta_label, mood_delta)

	_write_stat_rows({
		"akademis": student.get_akademis_delta(),
		"seni_budaya": student.get_seni_delta(),
		"olahraga": student.get_olahraga_delta(),
	}, student)


func _show_needs_delta(label: Label, delta: float) -> void:
	label.text = format_needs_delta(delta)
	label.show()


## Replay every stat track's growth for today (or this week), one row
## after the next, and travel both needs bars from their opening value to
## tonight's -- ease-out, like every other bar on this card. `delay`
## shifts the whole card, so the popup/checkup can line each card's fill
## up with its own staggered entrance.
##
## Never awaited and never required: setup_row/setup_week_row have
## already written every final value, so a caller that skips this sees a
## correct, static card. Call setup_row or setup_week_row first -- this
## reads the two openings they cached, which otherwise default to 0.
func play_gain(delay: float = 0.0) -> void:
	for i in stat_rows.size():
		stat_rows[i].play_gain(delay + float(i) * GAIN_STEP)
	_play_needs_travel(energy_bar, _energy_from, delay)
	_play_needs_travel(mood_bar, _mood_from, delay)
	if energy_delta_label.visible:
		Juice.count_up_formatted(energy_delta_label, 0.0, _energy_delta,
			func(v: float) -> String: return format_needs_delta(v), delay)
	if mood_delta_label.visible:
		Juice.count_up_formatted(mood_delta_label, 0.0, _mood_delta,
			func(v: float) -> String: return format_needs_delta(v), delay)


## The same replay, read off a week instead of a day: setup_week_row
## primes _energy_from/_mood_from with Monday's values rather than this
## morning's, so play_gain's own needs-bar travel already covers the
## week. Kept as its own name for callers that mean "replay the week".
func play_week_gain(delay: float = 0.0) -> void:
	play_gain(delay)


func _play_needs_travel(bar: ProgressBar, from_value: float, delay: float) -> void:
	var to_value: float = bar.value
	bar.value = from_value
	Juice.fill_bar(bar, to_value, -1.0, delay)
