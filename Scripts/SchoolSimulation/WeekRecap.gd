extends RefCounted
class_name WeekRecap

## The week's minigame tallies, computed from one StudentManager, and the
## Indonesian money format Weekly Results shows (2026-09-14 weekly-results
## spec; first written for the 2026-09-03 banner, since retired).
##
## A plain RefCounted rather than a node or an autoload, so the numbers can
## be tested without instantiating a scene. Nothing here is persisted.
##
## The week's coins are NOT computed here. SchoolDay pays the Wirausaha
## earnings out -- emptying GameState's pending-earnings dict -- before
## Weekly Results opens, so it hands the paid total to
## ResultCheckup.initialize_checkup() instead.

## The history category that marks an entry as a random event rather than a
## played minigame. Everything else is a minigame.
const EVENT_CATEGORY := "Event"


## The week's minigame tallies for `manager`. Random events are counted
## apart: they are recorded as won and cannot fail. Safe on a null manager,
## which reports an empty week -- the editor's test runner builds
## ResultCheckup with no simulation behind it.
static func compute(manager: StudentManager) -> Dictionary:
	var result := {
		"minigames_won": 0,
		"minigames_lost": 0,
		"minigames_total": 0,
		"events_count": 0,
	}
	if manager == null:
		return result

	for entry in manager.minigame_history:
		if entry.get("category", "") == EVENT_CATEGORY:
			result["events_count"] += 1
		else:
			result["minigames_total"] += 1
			if entry.get("won", false):
				result["minigames_won"] += 1
			else:
				result["minigames_lost"] += 1

	return result


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
