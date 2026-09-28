@tool
class_name StatFlags
extends RefCounted

## Which of AturJadwal's five stat bars wears a weak-stat chip (2026-09-24
## visual polish, D7). Pure static logic over a student dictionary, keyed by
## the dictionary's own stat names (`akademis`, `seni_budaya`, `olahraga`,
## `mood`, `energy`).
##
## A SKILL is weak below the student's own target for it. Early in a grade
## all three sit below target, so flagging every weak skill would put a chip
## on every bar all the time and say nothing; only the single most urgent
## one -- the biggest gap to its target -- is flagged "perlu". This is the
## plan's own fallback for a crowded top section. Every target starts as
## base + one shared uplift, so at the start of a grade the three gaps tie
## exactly; a tie (within GAP_EPSILON) goes to the weakest raw skill, never
## to whichever skill happens to be listed first.
##
## A NEED (mood, energy) is weak strictly below Balance.BATAS_KELELAHAN, the
## collaborator's own "lelah" line, and every weak need is flagged: they are
## rare, and a tired student is worth saying even beside a skill flag.
##
## No threshold is restated here. Skills read the student's own targets;
## needs read Balance, which is the collaborator's to tune.

## The chip word for a skill behind its target.
const PERLU := "perlu"

## The chip word for a need under the tiredness line.
const LELAH := "lelah"

## The three skills, each paired with its target key.
const _SKILLS := [
	["akademis", "target_akademis"],
	["seni_budaya", "target_seni_budaya"],
	["olahraga", "target_olahraga"],
]

## Two skill gaps closer than this, in stat points, count as a tie and fall to
## the tie-break. Half a point: bars show whole numbers, so gaps that differ by
## less look identical to the player.
const GAP_EPSILON := 0.5

## The two needs.
const _NEEDS := ["mood", "energy"]


## Stat key -> chip word, for every stat that should wear a chip. A stat
## missing from the dictionary is never flagged.
static func flags_for(student: Dictionary) -> Dictionary:
	var flags := {}
	# Two passes, so the answer never depends on _SKILLS' order: the biggest
	# gap first, then the weakest raw skill within GAP_EPSILON of it.
	var gaps := {}
	var biggest := 0.0
	for pair in _SKILLS:
		if not (student.has(pair[0]) and student.has(pair[1])):
			continue
		var gap := float(student[pair[1]]) - float(student[pair[0]])
		if gap > 0.0:
			gaps[pair[0]] = gap
			biggest = maxf(biggest, gap)
	var worst_key := ""
	var worst_current := INF
	for key: String in gaps:
		var current := float(student[key])
		if float(gaps[key]) >= biggest - GAP_EPSILON and current < worst_current:
			worst_current = current
			worst_key = key
	if worst_key != "":
		flags[worst_key] = PERLU
	for key in _NEEDS:
		if student.has(key) and float(student[key]) < Balance.BATAS_KELELAHAN:
			flags[key] = LELAH
	return flags
