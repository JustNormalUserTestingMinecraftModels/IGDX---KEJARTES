@tool
class_name DayVerdict
extends RefCounted

## The teacher's verdict on one school day (2026-09-24 SchoolDay liveliness
## pass, the Daily Results reward layer): a 1-4 star rating with a headline,
## the day's tally, and its Bintang Hari Ini. Pure static logic over data the
## daily result popup already has -- the day's logged stat changes, the
## students with their targets, and the Wirausaha money accrued today -- so it
## is tested without the popup.
##
## Star rule (mockup section 3): the targets crossed today drive the tier, the
## day's net skill change breaks the tie, and a day never scores below one.
##   4  two or more targets crossed and no skill went down anywhere
##   3  at least one target crossed
##   2  no target crossed, and the skills did not fall overall
##   1  no target crossed and the skills fell overall -- "Besok lebih baik!"

## The three skills, keyed as the stat log keys them, with the StudentData
## field holding each one's target. The naming trap: akademis2 is Seni.
const TARGET_FIELD := {
	"akademis": "target_akademis1",
	"seni_budaya": "target_akademis2",
	"olahraga": "target_akademis3",
}
## The word the popup prints for each skill.
const SKILL_WORD := {
	"akademis": "Akademis",
	"seni_budaya": "Seni Budaya",
	"olahraga": "Olahraga",
}
## Headline for each star count, 1 to 4.
const HEADLINES := ["", "Hari yang berat", "Lumayan", "Hari produktif!", "Luar biasa!"]
## The encouragement under a one-star day.
const HARD_DAY_LINE := "Besok lebih baik!"


## Everything the popup's reward layer shows, from the day's summary (as
## StudentManager.get_day_summary returns it), the roster, and the money
## Wirausaha earned today. Keys: stars, headline, subline, total_gain,
## targets_crossed, money, star_name, star_gain, star_skill.
static func compute(summary: Array, students: Array, money: int) -> Dictionary:
	var total_gain := 0.0
	var net := 0.0
	var crossed := 0
	var anyone_down := false
	var best_name := ""
	var best_gain := 0.0
	var best_skill := ""

	for entry in summary:
		var who: String = entry.get("student_name", "")
		var student: StudentData = _find(students, who)
		var per_skill := {}
		for change in entry.get("changes", []):
			var key: String = change.get("stat_key", "")
			if not TARGET_FIELD.has(key):
				continue
			per_skill[key] = per_skill.get(key, 0.0) + float(change.get("delta", 0.0))
		var student_gain := 0.0
		var top_skill := ""
		var top_delta := 0.0
		for key in per_skill:
			var delta: float = per_skill[key]
			net += delta
			if delta < 0.0:
				anyone_down = true
				continue
			total_gain += delta
			student_gain += delta
			if delta > top_delta:
				top_delta = delta
				top_skill = key
			if student != null and crossed_today(student, key, delta):
				crossed += 1
		if student_gain > best_gain:
			best_gain = student_gain
			best_name = who
			best_skill = top_skill

	var stars := star_count(crossed, net, anyone_down)
	return {
		"stars": stars,
		"headline": HEADLINES[stars],
		"subline": HARD_DAY_LINE if stars == 1 else "",
		"total_gain": int(round(total_gain)),
		"targets_crossed": crossed,
		"money": money,
		"star_name": best_name,
		"star_gain": int(round(best_gain)),
		"star_skill": SKILL_WORD.get(best_skill, ""),
	}


## The star rule on its own. See the file header.
static func star_count(targets_crossed: int, net_change: float, anyone_down: bool) -> int:
	if targets_crossed >= 2 and not anyone_down:
		return 4
	if targets_crossed >= 1:
		return 3
	if net_change >= 0.0:
		return 2
	return 1


## True when today's `delta` carried this student's `skill` from below its
## target to at or above it.
static func crossed_today(student: StudentData, skill: String, delta: float) -> bool:
	if delta <= 0.0 or not TARGET_FIELD.has(skill):
		return false
	var now := float(student.get(skill))
	var target := float(student.get(TARGET_FIELD[skill]))
	return now >= target and now - delta < target


static func _find(students: Array, who: String) -> StudentData:
	for s in students:
		if s is StudentData and (s as StudentData).student_name == who:
			return s
	return null
