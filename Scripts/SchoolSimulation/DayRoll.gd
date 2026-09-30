@tool
extends RefCounted

## The school day's Normal / Minigame / Event roll weights, moved out of
## SchoolDay.gd (2026-09-30) to keep that script under its clean-code size
## ratchet. SchoolDay.day_roll_weights() forwards here, so callers and tests
## keep their one entry point; the tuning below is read by
## tests/test_school_day.gd off this script.
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


## The day's weights (see SchoolDay.day_roll_weights() for the contract).
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
