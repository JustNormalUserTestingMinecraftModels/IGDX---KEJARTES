@tool
extends RefCounted

## The school day's Normal / Minigame / Event roll -- its weights, the outcome
## drawn from them, and the minigame category -- moved out of SchoolDay.gd
## (2026-09-30; the outcome and category 2026-10-01) to keep that script under
## its clean-code size ratchet. SchoolDay.day_roll_weights() and
## _pick_minigame_category() forward here, so callers and tests keep their one
## entry point; the tuning below is read by tests/test_school_day.gd off this
## script.
##
## Each school day rolls Normal / Minigame / Event in proportion to these --
## shares of the day's total, not percentages -- and weights() is their only
## reader. Biang Onar's extra event weight, in the same units, is
## Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT.

## Normal-day weight every day starts with.
const ROLL_WEIGHT_NORMAL_BASE := 20
## Extra normal-day weight for each student resting (Istirahat) that day.
const ROLL_WEIGHT_NORMAL_PER_RESTING := 10
## Minigame weight for each student studying Akademis, Olahraga or
## SeniBudaya that day, while the week's minigame cap has room.
const ROLL_WEIGHT_MINIGAME_PER_STUDYING := 15
## Event weight a day starts with while the week's event cap has room.
const ROLL_WEIGHT_EVENT_BASE := 25
## The minigame categories, in the order the uniform pick indexes them.
const CATEGORIES: Array[String] = ["Akademis", "Olahraga", "SeniBudaya"]


## A school day's Normal / Minigame / Event roll weights, as
## {"normal": int, "minigame": int, "event": int}.
##
## `counts` is GameState.get_jadwal_for_day(day_name), `roster` the
## simulated StudentData and `schedules` GameState.day_schedules. Resting
## students add normal-day weight and studying students minigame weight;
## each Biang Onar student scheduled for anything but rest that day adds
## Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT to the event weight. Once the
## week's minigame or event cap is reached, that weight is 0 -- the bonus
## included.
##
## Static and pure so a test can call it without the scene. Shared by
## SchoolDay._roll_event() and skip_to_results(), through
## _todays_roll_weights(), so the two simulation paths can't drift apart:
## skipping once rolled without Biang Onar's bonus.
static func weights(counts: Dictionary, roster: Array, schedules: Dictionary,
		day_name: String, minigames_played: int, max_minigames: int,
		events_triggered: int, max_events: int) -> Dictionary:
	var active_studying: int = (counts.get("Akademis", 0) + counts.get("Olahraga", 0)
		+ counts.get("SeniBudaya", 0))
	var resting_count: int = counts.get("Istirahat", 0)

	var w_minigame := 0
	if minigames_played < max_minigames:
		w_minigame = active_studying * ROLL_WEIGHT_MINIGAME_PER_STUDYING

	var w_event := 0
	if events_triggered < max_events:
		w_event = ROLL_WEIGHT_EVENT_BASE

		# ── Quirk: Biang Onar — extra event weight per one who isn't resting ──
		for s in roster:
			if s.quirk == "Biang Onar":
				var sid: int = s.id
				if sid != 0 and schedules.has(sid):
					var cat: String = schedules[sid].get(day_name, {}).get("category", "")
					# Anything but rest counts, Wirausaha included
					if cat != "" and cat != "DayOff" and cat != "Istirahat":
						w_event += Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT

	return {
		"normal": ROLL_WEIGHT_NORMAL_BASE + resting_count * ROLL_WEIGHT_NORMAL_PER_RESTING,
		"minigame": w_minigame,
		"event": w_event,
	}


## The day's outcome -- "Normal", "Minigame" or "Event" -- rolled in
## proportion to `day_weights` (weights()'s result). A day with no weight at
## all is a Normal one. Shared by SchoolDay._roll_event() and
## skip_to_results() so the two simulation paths can't drift apart.
static func outcome(day_weights: Dictionary) -> String:
	var w_normal: int = day_weights["normal"]
	var w_minigame: int = day_weights["minigame"]
	var total: int = w_normal + w_minigame + int(day_weights["event"])
	if total <= 0:
		return "Normal"
	var roll := randi() % total
	if roll < w_normal:
		return "Normal"
	if roll < w_normal + w_minigame:
		return "Minigame"
	return "Event"


## Picks a minigame category with a chance of uniform-random noise
## (Balance.MINIGAME_KATEGORI_ACAK_PELUANG) before falling back to a pick
## proportional to the day's scheduled subject weights, with a uniform
## fallback if all weights are zero. Shared by SchoolDay._roll_event() and
## skip_to_results() so the two simulation paths can't drift apart.
static func pick_category(w_akademis: int, w_olahraga: int, w_seni: int) -> String:
	var total := w_akademis + w_olahraga + w_seni
	if randf() < Balance.MINIGAME_KATEGORI_ACAK_PELUANG or total == 0:
		return CATEGORIES[randi() % CATEGORIES.size()]
	var choice := randi() % total
	if choice < w_akademis:
		return CATEGORIES[0]
	if choice < w_akademis + w_olahraga:
		return CATEGORIES[1]
	return CATEGORIES[2]
