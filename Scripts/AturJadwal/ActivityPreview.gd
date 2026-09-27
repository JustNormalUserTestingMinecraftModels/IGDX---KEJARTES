@tool
class_name ActivityPreview

## Every number the Penjadwalan picker shows, in one place, read from
## Balance.gd. Pure static functions -- no nodes, no scene, no state --
## so the numbers can be unit-tested without instantiating the screen.
##
## This file deliberately holds NO tuning literals of its own. If you find
## yourself typing a number here, it belongs in Balance.gd instead. The one
## int below, MAX_ARROWS, is a display cap, not tuning.
##
## Since the 2026-09-24 picker rebuild (visual polish D11/D12) the picker
## speaks in arrows rather than raw numbers: gold up for a gain, red down
## for a cost, more arrows for a bigger effect. The counts are derived here
## from Balance, measured against the biggest swing Balance allows, so a
## retune moves the arrows with it. Skill tiles keep their exact number
## beside the arrows; nothing shows a "~" range any more.
##
## Note on preview honesty: the simulation rolls fresh randomness when the
## week actually runs (StudentData.apply_jadwal_activity). These functions
## return a stable estimate, not the exact value the student will get --
## the same contract SchoolDay._preview_gain has always used.

## Most arrows (or coin pips) one effect ever shows.
const MAX_ARROWS := 3

## The three categories that raise a skill toward a target.
const SKILL_CATEGORIES := ["Akademis", "SeniBudaya", "Olahraga"]


## The student's specialty, normalized. The roster stores the UI spelling
## "Akademik"; every category key in code is "Akademis". Getting this
## wrong silently drops the specialty bonus.
static func _specialty_of(student: Dictionary) -> String:
	var hobby: String = student.get("hobby_category", "")
	if hobby == "Akademik":
		return "Akademis"
	return hobby


## True when `category` is this student's normalized specialty. The one place
## any screen should ask "does this activity play to the student's strength" --
## the raw hobby_category spelling ("Akademik") is a trap.
static func is_specialty(category: String, student: Dictionary) -> bool:
	return _specialty_of(student) == category


## True when `category` is the student's favourite SUBJECT: a skill that is
## also their specialty. The picker's Favorit ribbon and the gold
## specialty-match burst on assign both ask this, so they always agree.
static func is_favorit(category: String, student: Dictionary) -> bool:
	return is_skill(category) and is_specialty(category, student)


## True for the three study categories, which gain a skill and whose costs
## scale with the student's specialty.
static func is_skill(category: String) -> bool:
	return category in SKILL_CATEGORIES


## Points one ordinary study day adds at this grade, before any bonus.
static func base_gain(grade: int) -> float:
	match grade:
		7: return Balance.BELAJAR_POIN_KELAS_7
		8: return Balance.BELAJAR_POIN_KELAS_8
		9: return Balance.BELAJAR_POIN_KELAS_9
	return Balance.BELAJAR_POIN_CADANGAN


## Extra points a day in the student's own specialty adds at this grade.
static func favorit_bonus(grade: int) -> float:
	match grade:
		7: return Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
		8: return Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
		9: return Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
	return Balance.BELAJAR_BONUS_FAVORIT_CADANGAN


## Points this category adds in ONE day, for this student, at this grade.
static func skill_gain(category: String, student: Dictionary, grade: int) -> float:
	if is_specialty(category, student):
		return base_gain(grade) + favorit_bonus(grade)
	return base_gain(grade)


## The study-cost multiplier the simulation applies, mirrored for the
## dictionary the picker holds -- StudentData.get_category_efficiency_multiplier
## owns the real one. Favourite subject, a "Seimbang" student, or anything
## else. Libur and Wirausaha are never scaled.
static func cost_multiplier(category: String, student: Dictionary) -> float:
	if not is_skill(category):
		return 1.0
	var specialty := _specialty_of(student)
	if specialty == category:
		return Balance.BIAYA_KALAU_MAPEL_FAVORIT
	if specialty == "Seimbang":
		return Balance.BIAYA_KALAU_MURID_SEIMBANG
	return Balance.BIAYA_KALAU_BUKAN_FAVORIT


## The typical one-day energy change: negative drains, positive recovers.
## The middle of Balance's random range, scaled the way the simulation
## scales it.
static func energy_delta(category: String, student: Dictionary) -> float:
	match category:
		"Istirahat":
			return (Balance.LIBUR_ENERGI_PULIH_MIN + Balance.LIBUR_ENERGI_PULIH_MAX) / 2
		"Wirausaha":
			return -Balance.WIRAUSAHA_BIAYA_ENERGI
	var study := (Balance.BELAJAR_BIAYA_ENERGI_MIN + Balance.BELAJAR_BIAYA_ENERGI_MAX) / 2
	return -study * cost_multiplier(category, student)


## Same as energy_delta, for mood.
static func mood_delta(category: String, student: Dictionary) -> float:
	match category:
		"Istirahat":
			return (Balance.LIBUR_MOOD_PULIH_MIN + Balance.LIBUR_MOOD_PULIH_MAX) / 2
		"Wirausaha":
			return -Balance.WIRAUSAHA_BIAYA_MOOD
	var study := (Balance.BELAJAR_BIAYA_MOOD_MIN + Balance.BELAJAR_BIAYA_MOOD_MAX) / 2
	return -study * cost_multiplier(category, student)


## The biggest multiplier any study day can carry.
static func _worst_multiplier() -> float:
	return maxf(maxf(Balance.BIAYA_KALAU_MAPEL_FAVORIT, Balance.BIAYA_KALAU_MURID_SEIMBANG),
		Balance.BIAYA_KALAU_BUKAN_FAVORIT)


## The largest one-day energy swing Balance allows, in either direction.
## Arrow counts are measured against this, so every tile shares one scale.
static func energy_scale() -> float:
	var study := Balance.BELAJAR_BIAYA_ENERGI_MAX * _worst_multiplier()
	return maxf(maxf(study, Balance.LIBUR_ENERGI_PULIH_MAX), Balance.WIRAUSAHA_BIAYA_ENERGI)


## Same as energy_scale, for mood.
static func mood_scale() -> float:
	var study := Balance.BELAJAR_BIAYA_MOOD_MAX * _worst_multiplier()
	return maxf(maxf(study, Balance.LIBUR_MOOD_PULIH_MAX), Balance.WIRAUSAHA_BIAYA_MOOD)


## How many arrows `amount` earns against `scale`: 0 for no effect at all,
## otherwise 1 to MAX_ARROWS. Any real effect shows at least one arrow, so
## a small cost never reads as free.
static func arrows_for(amount: float, scale: float) -> int:
	if scale <= 0.0 or is_zero_approx(amount):
		return 0
	return clampi(roundi(absf(amount) / scale * MAX_ARROWS), 1, MAX_ARROWS)


## Arrows on a tile's energy effect. Its direction is energy_delta's sign.
static func energy_arrows(category: String, student: Dictionary) -> int:
	return arrows_for(energy_delta(category, student), energy_scale())


## Arrows on a tile's mood effect. Its direction is mood_delta's sign.
static func mood_arrows(category: String, student: Dictionary) -> int:
	return arrows_for(mood_delta(category, student), mood_scale())


## Up-arrows on a skill tile. An ordinary day is one arrow; the favourite
## bonus adds the rest in proportion to its size next to the base, so the
## favourite reads as MAX_ARROWS while the bonus matches the base, and
## shrinks with it if Balance ever cuts the bonus. 0 for non-skill tiles.
static func gain_arrows(category: String, student: Dictionary, grade: int) -> int:
	if not is_skill(category):
		return 0
	var base := base_gain(grade)
	if base <= 0.0:
		return 0
	if not is_specialty(category, student):
		return 1
	var extra := ceili(favorit_bonus(grade) / base * (MAX_ARROWS - 1))
	return clampi(1 + extra, 1, MAX_ARROWS)


## Coin pips on the Wirausaha tile: a typical day's earnings against the
## best day Balance allows. A magnitude, never the money range itself.
static func earning_pips() -> int:
	var typical := float(Balance.WIRAUSAHA_UANG_MIN + Balance.WIRAUSAHA_UANG_MAX) / 2
	return arrows_for(typical, float(Balance.WIRAUSAHA_UANG_MAX))


## The one line under the picker's grid. With nothing selected it says what
## to do; with a tile selected it explains that tile. The favourite's line
## is the breakdown that teaches the bonus (D14): base, bonus, total, and
## the cheaper energy. Rendered in the body face, which carries the "·"
## the display face lacks.
static func selection_note(category: String, student: Dictionary, grade: int) -> String:
	if category == "":
		return "Ketuk satu kegiatan, lalu tekan Pilih."
	if is_skill(category):
		var base := int(base_gain(grade))
		if is_specialty(category, student):
			return "Dasar +%d / Bonus favorit +%d / Total +%d · energi lebih hemat" % [
				base, int(favorit_bonus(grade)), int(skill_gain(category, student, grade))]
		if cost_multiplier(category, student) > 1.0:
			return "+%d per hari · bukan favoritnya, jadi lebih melelahkan" % base
		return "+%d per hari" % base
	if category == "Wirausaha":
		return "Cuan dibayar di akhir minggu · energi dan mood turun"
	return "Istirahat seharian · energi dan mood pulih"


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
