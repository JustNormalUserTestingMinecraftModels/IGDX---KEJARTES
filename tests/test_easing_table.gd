@tool
extends McpTestSuite

## Ground truth for Motion Lab's browser preview (2026-09-05).
##
## The editor page does not re-implement Penner easing in JavaScript -- it
## reads a table sampled from Godot's own Tween.interpolate_value(). This
## suite owns that table. It re-samples the engine and asserts the checked-in
## JSON still matches, so an engine upgrade that changes a curve fails here
## instead of silently desyncing every future preview.
##
## Bootstrapping: if the JSON is missing, the first run writes it and fails
## with a "generated -- re-run" message. It never overwrites an existing
## file; a real mismatch must be read by a human, not papered over.
##
## Suite is @tool and no test is a coroutine (see test_lobby.gd's note).

const _TABLE_PATH := "res://.claude/skills/motion-lab/assets/godot-easing.json"

## Samples per curve. 256 keeps BOUNCE's corners and ELASTIC's oscillation
## legible under the linear interpolation the page does between samples.
const _SAMPLES := 256

## Absolute tolerance comparing the checked-in table to the live engine.
## The file stores 5 decimals, so rounding contributes at most 5e-6.
const _EPSILON := 1.0e-5

## Name -> Tween.TransitionType. Names are the page's own identifiers and
## the token format's, so they must not be renamed casually.
const _TRANSITIONS := {
	"LINEAR": Tween.TRANS_LINEAR,
	"SINE": Tween.TRANS_SINE,
	"QUINT": Tween.TRANS_QUINT,
	"QUART": Tween.TRANS_QUART,
	"QUAD": Tween.TRANS_QUAD,
	"EXPO": Tween.TRANS_EXPO,
	"ELASTIC": Tween.TRANS_ELASTIC,
	"CUBIC": Tween.TRANS_CUBIC,
	"CIRC": Tween.TRANS_CIRC,
	"BOUNCE": Tween.TRANS_BOUNCE,
	"BACK": Tween.TRANS_BACK,
	"SPRING": Tween.TRANS_SPRING,
}

## Name -> Tween.EaseType, in the order the page's grid renders them.
const _EASES := {
	"IN": Tween.EASE_IN,
	"OUT": Tween.EASE_OUT,
	"IN_OUT": Tween.EASE_IN_OUT,
	"OUT_IN": Tween.EASE_OUT_IN,
}


func suite_name() -> String:
	return "easing_table"


## "TRANS/EASE" -> Array[float] of _SAMPLES values, sampled from the engine.
func _sample_all() -> Dictionary:
	var out := {}
	for tname in _TRANSITIONS:
		for ename in _EASES:
			var curve: Array = []
			for i in _SAMPLES:
				var t := float(i) / float(_SAMPLES - 1)
				curve.append(float(Tween.interpolate_value(
					0.0, 1.0, t, 1.0,
					_TRANSITIONS[tname], _EASES[ename])))
			out[tname + "/" + ename] = curve
	return out


## Hand-rolled rather than JSON.stringify() so every float is written at a
## fixed 5 decimals. Godot's stringify emits full double precision, which
## triples the file and makes diffs unreadable.
func _encode(table: Dictionary) -> String:
	var parts: Array[String] = []
	for key in table:
		var nums: Array[String] = []
		for v in table[key]:
			nums.append("%.5f" % v)
		parts.append("\"%s\":[%s]" % [key, ",".join(nums)])
	return "{\"samples\":%d,\"curves\":{%s}}" % [_SAMPLES, ",".join(parts)]


func _write_table(table: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(_TABLE_PATH.get_base_dir())
	var f := FileAccess.open(_TABLE_PATH, FileAccess.WRITE)
	if f == null:
		return "could not open %s for writing (error %d)" % [
			_TABLE_PATH, FileAccess.get_open_error()]
	f.store_string(_encode(table))
	f.close()
	return ""


## Guards the one engine assumption the whole tool rests on: that
## interpolate_value is callable statically off the Tween class. If 4.6 ever
## moves it to an instance method this fails first and alone, naming the
## problem, instead of every other test failing with a confusing table.
func test_interpolate_value_is_callable_statically() -> void:
	var half: float = Tween.interpolate_value(
		0.0, 1.0, 0.5, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
	assert_true(absf(half - 0.5) < _EPSILON,
		"LINEAR/IN at t=0.5 is 0.5, got %f" % half)
	var end: float = Tween.interpolate_value(
		0.0, 1.0, 1.0, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT)
	assert_true(absf(end - 1.0) < _EPSILON,
		"every curve lands on 1.0 at t=1, BACK/OUT gave %f" % end)


## Godot's TRANS_EXPO never fully closes the asymptote it approaches: measured
## directly, EXPO/IN ends at 0.999000013 and EXPO/OUT_IN at 0.999499977, while
## EXPO/OUT and EXPO/IN_OUT do land on exactly 1.0. All four still start at
## exactly 0.0. This is a genuine, if obscure, engine characteristic, not a
## sampling bug -- so only EXPO gets the looser tolerance below.
const _EXPO_END_EPSILON := 2.0e-3


func test_all_48_combinations_sample_cleanly() -> void:
	var table := _sample_all()
	assert_eq(table.size(), 48, "12 transitions x 4 eases")
	for key in table:
		var curve: Array = table[key]
		assert_eq(curve.size(), _SAMPLES, key + " has _SAMPLES points")
		assert_true(absf(float(curve[0])) < _EPSILON,
			key + " starts at 0.0, got %f" % curve[0])
		var end_tolerance := _EXPO_END_EPSILON if key.begins_with("EXPO/") else _EPSILON
		assert_true(absf(float(curve[-1]) - 1.0) < end_tolerance,
			key + " ends at 1.0, got %f" % curve[-1])
		for v in curve:
			assert_true(is_finite(v), key + " has no NaN or INF")


func test_checked_in_table_matches_the_engine() -> void:
	var table := _sample_all()
	if not FileAccess.file_exists(_TABLE_PATH):
		var err := _write_table(table)
		assert_true(false, "table was missing. %s Re-run this suite." % (
			err if err != "" else "Generated it at " + _TABLE_PATH + "."))
		return
	var raw := FileAccess.get_file_as_string(_TABLE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary, _TABLE_PATH + " parses as JSON")
	if not (parsed is Dictionary):
		return
	var doc: Dictionary = parsed
	assert_eq(int(doc.get("samples", 0)), _SAMPLES, "sample count matches")
	var curves: Dictionary = doc.get("curves", {})
	assert_eq(curves.size(), 48, "checked-in table has 48 curves")
	for key in table:
		assert_has_key(curves, key, "checked-in table has " + key)
		if not curves.has(key):
			continue
		var stored: Array = curves[key]
		var live: Array = table[key]
		var worst := 0.0
		var worst_at := -1
		for i in mini(stored.size(), live.size()):
			var d: float = absf(float(stored[i]) - float(live[i]))
			if d > worst:
				worst = d
				worst_at = i
		assert_true(worst < _EPSILON,
			"%s drifted from the engine: %f at sample %d. If Godot changed "
			% [key, worst, worst_at]
			+ "this curve deliberately, delete the JSON and re-run to rebake.")
