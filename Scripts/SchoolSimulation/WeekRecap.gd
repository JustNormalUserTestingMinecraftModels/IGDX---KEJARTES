extends RefCounted
class_name WeekRecap

## The week's four headline totals, computed from one StudentManager
## (2026-09-03 spec section 4).
##
## A plain RefCounted rather than a node or an autoload: the numbers on
## ResultCheckup's banner are the most likely thing in this screen to be
## argued about during balancing, and keeping them here means they can be
## tested without instantiating a scene.
##
## Nothing here is persisted. The week's totals are recomputed on demand
## from the live StudentManager, matching GameState's session-scoped
## design.

## The three skill keys that count toward net_skill_delta. energy and
## mood are deliberately absent: summing a mood drop into the same
## integer as an academic gain produces a number that means nothing --
## -12 mood against +12 akademis would cancel to 0 and report a flat week
## that was not flat.
const SKILL_KEYS := ["akademis", "seni_budaya", "olahraga"]

## The history category that marks an entry as a random event rather than
## a played minigame. Everything else is a minigame.
const EVENT_CATEGORY := "Event"

## Shown by the poin pill at exactly zero, in place of a bare "0".
const NEUTRAL_WORD := "Netral"


## Every headline total for the week `manager` just simulated. Safe on a
## null manager, which reports an empty week rather than erroring -- the
## editor's test runner builds ResultCheckup with no simulation behind
## it.
static func compute(manager: StudentManager) -> Dictionary:
	var result := {
		"money_earned": _sum_pending_earnings(),
		"net_skill_delta": 0,
		"minigames_won": 0,
		"minigames_total": 0,
		"events_count": 0,
	}
	if manager == null:
		return result

	var net := 0.0
	for day_name in manager.daily_stat_log:
		for change in manager.daily_stat_log[day_name]:
			if SKILL_KEYS.has(change.get("stat_key", "")):
				net += change.get("delta", 0.0)
	result["net_skill_delta"] = int(round(net))

	for entry in manager.minigame_history:
		if entry.get("category", "") == EVENT_CATEGORY:
			result["events_count"] += 1
		else:
			result["minigames_total"] += 1
			if entry.get("won", false):
				result["minigames_won"] += 1

	return result


## This week's un-paid Wirausaha earnings. GameState empties
## pending_earnings at week end, so this must be read before SchoolDay's
## payout, which is exactly when ResultCheckup runs.
static func _sum_pending_earnings() -> int:
	var total := 0
	for amount in GameState.pending_earnings.values():
		total += int(amount)
	return total


## "4.200" -- Indonesian thousands grouping, which uses a dot where
## English uses a comma.
static func format_money(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	return ("-" if value < 0 else "") + grouped


## "+37" / "-4" / "Netral". The "+" is explicit and the "-" comes free
## from %d, the same sign rule DaySummaryStudentRow.format_needs_delta
## uses. Zero reads as a word because a bare "0" beside a coloured pill
## looks like the pill failed to populate.
static func format_skill_delta(value: int) -> String:
	if value == 0:
		return NEUTRAL_WORD
	return "%s%d" % ["+" if value > 0 else "", value]
