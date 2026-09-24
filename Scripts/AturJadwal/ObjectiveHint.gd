@tool
class_name ObjectiveHint
extends RefCounted

## The words and numbers on AturJadwal's objective strip (2026-09-24 visual
## polish, D8): its title, its star chip, its progress bar, and the one-line
## plain-language hint it expands to. Pure static functions, tested directly.
##
## Nothing here restates a threshold. The pass line and the star total are
## Balance's; "tired" is Balance.BATAS_KELELAHAN; a skill's gap is measured
## against the student's own target. The most urgent skill is the same one
## StatFlags flags "perlu", so the strip and the bars never disagree.

## Months of the school calendar, four weeks each, starting in August. A week
## past the last one clamps to it rather than failing.
const MONTHS := ["Agustus", "September", "Oktober", "November", "Desember"]

## Weeks shown under each month.
const WEEKS_PER_MONTH := 4

## Skill key -> the schedule category it grows, for its display word.
const _SKILL_CATEGORY := {
	"akademis1": "Akademis",
	"akademis2": "SeniBudaya",
	"akademis3": "Olahraga",
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


## Stars as the chip shows them: one decimal, and none for a whole number.
static func format_stars(stars: float) -> String:
	var rounded := snappedf(stars, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return "%d" % int(roundf(rounded))
	return "%.1f" % rounded


## The star chip: the run's stars over the pass line.
static func star_text(stars: float) -> String:
	return "%s / %s" % [format_stars(stars), format_stars(Balance.STAR_WIN_THRESHOLD)]


## How far the run is toward passing, 0-100. Full means the grade passes;
## stars past the pass line do not overfill it.
static func progress_percent(stars: float) -> float:
	if Balance.STAR_WIN_THRESHOLD <= 0.0:
		return 100.0
	return clampf(stars / Balance.STAR_WIN_THRESHOLD * 100.0, 0.0, 100.0)


## The one-line hint for `student`: who they are, the skill they most need,
## and a warning when a need is under the tiredness line. `student` is the
## same projected dictionary the stat bars show.
static func compose(student: Dictionary) -> String:
	var who: String = student.get("name", "Murid")
	var flags := StatFlags.flags_for(student)
	var line := ""
	for key in _SKILL_CATEGORY:
		if flags.get(key, "") == StatFlags.PERLU:
			var word: String = DayStickyNote.DISPLAY_NAMES.get(_SKILL_CATEGORY[key], key)
			line = "%s butuh %s" % [who, word]
	if line == "":
		line = "%s sudah mencapai semua target" % who
	if flags.get("kepribadian2", "") == StatFlags.LELAH:
		line += " — jaga energi biar tidak Izin"
	elif flags.get("kepribadian1", "") == StatFlags.LELAH:
		line += " — jaga mood-nya, jadwalkan Libur"
	return line
