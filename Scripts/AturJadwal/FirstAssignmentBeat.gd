@tool
class_name FirstAssignmentBeat
extends RefCounted

## The learn-by-doing beat on the first AturJadwal assignment (2026-10-07
## tutorial overhaul, spec
## docs/superpowers/specs/2026-10-07-tutorial-visual-overhaul-design.md
## section 4, beat 4). Phase 2 of AturJadwal's tutorial already gates the
## player onto Senin and the picker; when they pick, the real stat bars refill
## (AturJadwal._update_student_display), this floats the pick's deltas over
## each changed row, and the Nota Guru names the trade-off -- one line for a
## study pick, one for Istirahat, so either choice teaches it.
##
## Data and pure helpers, plus one call that drops the floating numbers
## (AnimUtils.create_floating_text, the project's floating-delta helper).

## The trade-off after a study pick (Akademis, Seni Budaya, Olahraga). Spec copy.
const LINE_STUDY := "Lihat, kan? Belajar menaikkan skill, tapi menguras energi dan mood. Di situ serunya!"
## The trade-off after an Istirahat pick. Spec copy.
const LINE_REST := "Istirahat memulihkan energi dan mood, tapi skill tidak naik. Pintar-pintar mengatur, ya!"
## The skill each study category raises, by GameState stat key.
const SKILL_KEY := {"Akademis": "akademis", "SeniBudaya": "seni_budaya", "Olahraga": "olahraga"}
## The AturJadwal stat row a delta floats over, by stat key.
const ROW := {"akademis": "BGStat/Akademis", "seni_budaya": "BGStat/SeniBudaya",
		"olahraga": "BGStat/Olahraga", "mood": "BGStat/Mood", "energy": "BGStat/Energy"}
## How far above a row's centre its number starts, in pixels.
const LIFT := 24.0


## The trade-off line for a pick of `category`; empty for a pick the spec gives
## no line (Wirausaha), which keeps the tutorial's own words.
static func line_for(category: String) -> String:
	if category == "Istirahat":
		return LINE_REST
	if SKILL_KEY.has(category):
		return LINE_STUDY
	return ""


## What one day of `category` does to `student`, by stat key: the skill it
## raises (ActivityPreview.skill_gain) and the mood and energy it costs, as
## signed amounts (Istirahat's costs are negative, so they come out as gains).
static func deltas_for(category: String, student: Dictionary, grade: int) -> Dictionary:
	var out := {"mood": -ActivityPreview.mood_cost(category),
			"energy": -ActivityPreview.energy_cost(category)}
	if SKILL_KEY.has(category):
		out[SKILL_KEY[category]] = ActivityPreview.skill_gain(category, student, grade)
	return out


## How a delta reads on screen: "+15" or a true minus sign, "−6".
static func label_for(amount: float) -> String:
	var whole := int(round(absf(amount)))
	return ("+%d" if amount >= 0.0 else "−%d") % whole


## Floats each non-zero delta over its stat row on `screen` (AturJadwal), green
## for a gain and red for a cost (DesignTokens).
static func play(screen: Control, deltas: Dictionary) -> void:
	var tokens := Juice.tokens()
	for key: String in deltas:
		var amount: float = deltas[key]
		var row := screen.get_node_or_null(ROW.get(key, "")) as Control
		if row == null or is_zero_approx(amount):
			continue
		# create_floating_text places in its parent's space, not the canvas's.
		var at := row.global_position - screen.global_position + Vector2(row.size.x / 2.0, -LIFT)
		var color := tokens.state_success if amount > 0.0 else tokens.state_danger
		AnimUtils.create_floating_text(screen, label_for(amount), at, color)
