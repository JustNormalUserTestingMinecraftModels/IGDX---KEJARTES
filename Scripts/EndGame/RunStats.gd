@tool
class_name RunStats
extends Resource

## The per-grade tally the run-result screen reports on.
##
## One instance lives on GameState (`GameState.run_stats`) and is reset
## whenever a grade starts. It is written from four places that already
## know these events happen -- StudentManager.record_minigame_result(),
## GameState.use_item(), SchoolDay._pay_out_wirausaha(), and SchoolDay's
## event branch -- and read only by RunGrade and RunResult.
##
## Saved with the run through to_dict()/from_dict() (SaveGame); a Resource
## for the typed fields and the Inspector, never written with ResourceSaver.

## Minigames the roster won this grade.
@export var minigames_won: int = 0
## Minigames the roster lost this grade.
@export var minigames_lost: int = 0
## Net stat points minigames awarded (wins) or deducted (losses).
@export var minigame_points: float = 0.0
## Successful GameState.use_item() applications this grade.
@export var items_used: int = 0
## Rupiah paid out from wirausaha this grade.
@export var wirausaha_money: int = 0
## Ids of students that appeared in at least one event. Stored as a list
## of unique ids rather than a count so re-recording the same student is
## idempotent -- SchoolDay's event branch can fire more than once per
## student per grade.
@export var event_student_ids: Array[int] = []
## Random events and pick-students events the roster sat through this grade.
## Unlike event_student_ids this counts every occurrence, and it is what the
## run report shows as "Event yang diikuti".
@export var events_attended: int = 0


func record_minigame(won: bool, points: float) -> void:
	if won:
		minigames_won += 1
	else:
		minigames_lost += 1
	minigame_points += points


func record_item_use(count: int = 1) -> void:
	items_used += count


func record_wirausaha(amount: int) -> void:
	wirausaha_money += amount


func record_event_student(student_id: int) -> void:
	if not event_student_ids.has(student_id):
		event_student_ids.append(student_id)


func record_event_attended() -> void:
	events_attended += 1


func event_student_count() -> int:
	return event_student_ids.size()


func minigames_played() -> int:
	return minigames_won + minigames_lost


func minigame_win_rate() -> float:
	var played := minigames_played()
	if played <= 0:
		return 0.0
	return float(minigames_won) / float(played)


## Every tally as {name: value}, for SaveGame. Walks the property list, so a
## tally added or removed later is saved without touching this.
func to_dict() -> Dictionary:
	var d := {}
	for prop in get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = get(prop.name)
		d[prop.name] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return d


## Inverse of to_dict(): resets, then copies back every key this build still
## has. Unknown keys (a tally since removed) are ignored; typed arrays come
## back through assign() so they keep their type.
func from_dict(d: Dictionary) -> void:
	reset()
	for prop in get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not d.has(prop.name):
			continue
		var current: Variant = get(prop.name)
		if current is Array:
			var typed: Array = current.duplicate()
			typed.assign(d[prop.name])
			set(prop.name, typed)
		else:
			set(prop.name, d[prop.name])


func reset() -> void:
	minigames_won = 0
	minigames_lost = 0
	minigame_points = 0.0
	items_used = 0
	wirausaha_money = 0
	event_student_ids.clear()
	events_attended = 0
