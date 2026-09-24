@tool
class_name StatFlags
extends RefCounted

## Which of AturJadwal's five stat bars wears a weak-stat chip (2026-09-24
## visual polish, D7). Pure static logic over a student dictionary, keyed by
## the dictionary's own stat names (`akademis1/2/3`, `kepribadian1/2`).
##
## A SKILL is weak below the student's own target for it. Early in a grade
## all three sit below target, so flagging every weak skill would put a chip
## on every bar all the time and say nothing; only the single most urgent
## one -- the biggest gap to its target -- is flagged "perlu". This is the
## plan's own fallback for a crowded top section.
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
	["akademis1", "target_akademis1"],
	["akademis2", "target_akademis2"],
	["akademis3", "target_akademis3"],
]

## The two needs: kepribadian1 is mood, kepribadian2 is energy.
const _NEEDS := ["kepribadian1", "kepribadian2"]


## Stat key -> chip word, for every stat that should wear a chip. A stat
## missing from the dictionary is never flagged.
static func flags_for(student: Dictionary) -> Dictionary:
	var flags := {}
	var worst_key := ""
	var worst_gap := 0.0
	for pair in _SKILLS:
		if not (student.has(pair[0]) and student.has(pair[1])):
			continue
		var gap := float(student[pair[1]]) - float(student[pair[0]])
		if gap > worst_gap:
			worst_gap = gap
			worst_key = pair[0]
	if worst_key != "":
		flags[worst_key] = PERLU
	for key in _NEEDS:
		if student.has(key) and float(student[key]) < Balance.BATAS_KELELAHAN:
			flags[key] = LELAH
	return flags
