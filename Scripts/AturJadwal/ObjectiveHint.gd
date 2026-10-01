@tool
class_name ObjectiveHint
extends RefCounted

## The words and numbers on AturJadwal's objective strip (2026-09-24 visual
## polish, D8): its title, its safe-student chip, its progress bar, and the one-line
## plain-language hint it expands to. Pure static functions, tested directly.
##
## Nothing here restates a threshold. The pass line is GameState's
## per-student rule (MIN_TARGETS_PER_STUDENT), counted by
## GameState.safe_student_count(); "tired" is Balance.BATAS_KELELAHAN; a
## skill's gap is measured against the student's own target. The most
## urgent skill is the same one StatFlags flags "perlu", so the strip and
## the bars never disagree.

## Months of the school calendar, four weeks each, starting in August. A week
## past the last one clamps to it rather than failing.
const MONTHS := ["Agustus", "September", "Oktober", "November", "Desember"]

## Weeks shown under each month.
const WEEKS_PER_MONTH := 4

## Skill key -> the schedule category it grows, for its display word. Also
## NeedGauge's, so the strip and the portrait callout name the same subject.
const SKILL_CATEGORY := {
	"akademis": "Akademis",
	"seni_budaya": "SeniBudaya",
	"olahraga": "Olahraga",
}


## "Agustus - Minggu 3/6": the month the week falls in, and the week counted
## against the grade's length. A plain hyphen, not the plan's "·" or the old
## header's "—": Boohong, the display face this is set in, carries neither
## (measured 2026-09-24), and a missing glyph falls back to whatever font the
## device has, or to a box. test_objective_hint pins every character here to
## the display face.
static func title(week: int, total_weeks: int) -> String:
	@warning_ignore("integer_division")
	var month: String = MONTHS[clampi((week - 1) / WEEKS_PER_MONTH, 0, MONTHS.size() - 1)]
	return "%s - Minggu %d/%d" % [month, week, total_weeks]


## The chip: students on or past the pass line, over the roster.
static func safe_text(safe: int, total: int) -> String:
	return "%d / %d" % [safe, total]


## How far the run is toward passing, 0-100: the share of the roster that is
## safe. Full means the grade passes. An empty roster reads full, matching
## GameState.check_semester_passed().
static func safe_percent(safe: int, total: int) -> float:
	if total <= 0:
		return 100.0
	return clampf(float(safe) / float(total) * 100.0, 0.0, 100.0)


## The one-line hint for `student`: who they are, the skill they most need,
## and a warning when a need is under the tiredness line. `student` is the
## same projected dictionary the stat bars show.
static func compose(student: Dictionary) -> String:
	var who: String = student.get("name", "Murid")
	var flags := StatFlags.flags_for(student)
	var line := ""
	for key in SKILL_CATEGORY:
		if flags.get(key, "") == StatFlags.PERLU:
			var word: String = DayStickyNote.DISPLAY_NAMES.get(SKILL_CATEGORY[key], key)
			line = "%s butuh %s" % [who, word]
	if line == "":
		line = "%s sudah mencapai semua target" % who
	if flags.get("energy", "") == StatFlags.LELAH:
		line += " — jaga energi biar tidak Izin"
	elif flags.get("mood", "") == StatFlags.LELAH:
		line += " — jaga mood-nya, jadwalkan Libur"
	return line
