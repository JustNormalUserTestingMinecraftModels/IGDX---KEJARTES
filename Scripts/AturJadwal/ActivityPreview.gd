@tool
class_name ActivityPreview

## Every number the Penjadwalan popup shows, in one place, read from
## Balance.gd. Pure static functions -- no nodes, no scene, no state --
## so the numbers can be unit-tested without instantiating the screen.
##
## This file deliberately holds NO literals of its own. If you find
## yourself typing a number here, it belongs in Balance.gd instead.
##
## Note on preview honesty: the simulation rolls fresh randomness when the
## week actually runs (StudentData.apply_jadwal_activity). These functions
## return a stable estimate, not the exact value the student will get --
## the same contract SchoolDay._preview_gain has always used.


## The student's specialty, normalized. The roster stores the UI spelling
## "Akademik"; every category key in code is "Akademis". Getting this
## wrong silently drops the specialty bonus.
static func _specialty_of(student: Dictionary) -> String:
	var hobby: String = student.get("hobby_category", "")
	if hobby == "Akademik":
		return "Akademis"
	return hobby


## Points this category adds in ONE day, for this student, at this grade.
static func skill_gain(category: String, student: Dictionary, grade: int) -> float:
	var base := Balance.BELAJAR_POIN_CADANGAN
	var bonus := Balance.BELAJAR_BONUS_FAVORIT_CADANGAN
	match grade:
		7:
			base = Balance.BELAJAR_POIN_KELAS_7
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
		8:
			base = Balance.BELAJAR_POIN_KELAS_8
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
		9:
			base = Balance.BELAJAR_POIN_KELAS_9
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
	if _specialty_of(student) == category:
		return base + bonus
	return base


## Render a Balance range for display. Equal bounds collapse to one number
## so a fixed value does not read as a fake range ("+10", not "+10~10").
static func format_range(low: float, high: float, prefix_sign: bool) -> String:
	var sign_text := "+" if prefix_sign else "-"
	if is_equal_approx(low, high):
		return "%s%d" % [sign_text, int(low)]
	return "%s%d~%d" % [sign_text, int(low), int(high)]


## The chips shown inside one row's pill, left to right.
## Each entry: {"icon": "" | "energy" | "mood" | "money", "text": String}
static func chips_for(category: String, student: Dictionary, grade: int) -> Array[Dictionary]:
	var chips: Array[Dictionary] = []
	match category:
		"Wirausaha":
			chips.append({
				"icon": "energy",
				"text": format_range(Balance.WIRAUSAHA_BIAYA_ENERGI, Balance.WIRAUSAHA_BIAYA_ENERGI, false),
			})
			chips.append({
				"icon": "money",
				"text": format_range(Balance.WIRAUSAHA_UANG_MIN, Balance.WIRAUSAHA_UANG_MAX, true),
			})
		"Istirahat":
			chips.append({
				"icon": "energy",
				"text": format_range(Balance.LIBUR_ENERGI_PULIH_MIN, Balance.LIBUR_ENERGI_PULIH_MAX, true),
			})
			chips.append({
				"icon": "mood",
				"text": format_range(Balance.LIBUR_MOOD_PULIH_MIN, Balance.LIBUR_MOOD_PULIH_MAX, true),
			})
		_:
			var gain := skill_gain(category, student, grade)
			chips.append({"icon": "", "text": "+%d" % int(gain)})
	return chips


## Energy this category costs for one day, in the sign convention
## day_schedules has always used: positive drains, negative recovers.
static func energy_cost(category: String) -> float:
	match category:
		"Istirahat":
			return -Balance.LIBUR_ENERGI_PULIH_MAX
		"Wirausaha":
			return Balance.WIRAUSAHA_BIAYA_ENERGI
		_:
			return Balance.BELAJAR_BIAYA_ENERGI_MAX


## Mood this category costs for one day. Same sign convention as energy_cost.
static func mood_cost(category: String) -> float:
	match category:
		"Istirahat":
			return -Balance.LIBUR_MOOD_PULIH_MAX
		"Wirausaha":
			return Balance.WIRAUSAHA_BIAYA_MOOD
		_:
			return Balance.BELAJAR_BIAYA_MOOD_MAX
