@tool
class_name StudentChatterPicker
extends RefCounted

## Anti-repetition for StudentChatterCatalog: one shuffle bag per
## (student, pool). Every line in a pool is said once before any repeats,
## and a refilled bag never opens with the line that closed the last one.
## LobbyChatter keeps one picker for the Lobby's lifetime.

## Drives shuffles and the state-vs-trait roll; tests seed it.
var rng := RandomNumberGenerator.new()
var _bags := {}
var _last := {}


func _init() -> void:
	rng.randomize()


## A line for `student`: STATE_CHANCE of the time from their state pool
## while a state applies, otherwise from their trait pool.
func pick(student: Dictionary) -> String:
	var who := str(student.get("name", ""))
	var state := StudentChatterCatalog.state_for(student)
	if state != &"" and rng.randf() < StudentChatterCatalog.STATE_CHANCE:
		return draw("%s|%s" % [who, state], StudentChatterCatalog.STATE_LINES[state])
	return draw("%s|trait" % who, StudentChatterCatalog.trait_pool(student))


## Next line from the bag `key`, refilled from `pool` when empty.
func draw(key: String, pool: Array) -> String:
	if pool.is_empty():
		return ""
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = pool.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = bag[i]
			bag[i] = bag[j]
			bag[j] = t
		if bag.size() > 1 and bag.back() == _last.get(key, ""):
			var t2 = bag[0]
			bag[0] = bag[bag.size() - 1]
			bag[bag.size() - 1] = t2
	var line := str(bag.pop_back())
	_bags[key] = bag
	_last[key] = line
	return line
