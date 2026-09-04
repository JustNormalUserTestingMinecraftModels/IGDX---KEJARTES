class_name EndGameRehearsal
extends RefCounted

## Debug-only jig for the end-of-grade sequence: builds a fixed, known
## roster so TesNotice -> ExamProgress -> CutScene -> SemesterEnd ->
## RunResult can be rehearsed in one click instead of played for six to
## sixteen weeks.
##
## Nothing in the shipped game calls this file -- DebugManager's Scenes
## tab is its only caller. Everything it writes to GameState is captured
## by snapshot() first and undone by restore(), so arming a rehearsal
## mid-run does not cost the run.
##
## Plain static functions over Dictionaries, no nodes, which is why
## tests/test_end_game_rehearsal.gd can test it behaviourally rather than
## by source scan the way DebugManager has to be tested.

## The three fixed outcomes the debug overlay offers.
const PRESET_LULUS := "lulus"
const PRESET_GAGAL := "gagal"
const PRESET_CAMPUR := "campur"

# ── Tunables ──────────────────────────────────────────────────────────────────
## Base skill value every rehearsal student starts from. Targets are
## derived as base + the grade's uplift -- the same arithmetic
## GameState.initialize_grade_targets() does -- so one number keeps the
## presets correct at grade 7, 8 and 9 instead of three hardcoded sets.
const BASE_SKILL := 45.0
## How far above its target a "cleared" skill sits.
const CLEAR_MARGIN := 10.0
## How far below its target a "missed" skill sits.
const MISS_MARGIN := 20.0
## Mood and energy every rehearsal student carries. Comfortably above the
## energy <= 5 threshold that would force an "Izin" day, so nothing the
## sequence passes through second-guesses the roster.
const REHEARSAL_MOOD := 70.0
const REHEARSAL_ENERGY := 70.0

## How many of the three skills each student clears, by slot in the
## roster. The campur ladder is deliberate: one card per star rating, so
## the SemesterEnd carousel shows 3-, 2-, 1- and 0-star detail popups and
## both stamp kinds in a single pass. Slots past the end of the list
## repeat its last entry, so a roster of any size still works.
const CLEARED_COUNTS := {
	PRESET_LULUS: [3, 3, 3, 3],
	PRESET_GAGAL: [0, 0, 0, 0],
	PRESET_CAMPUR: [3, 2, 1, 0],
}

## Skill keys in the order CLEARED_COUNTS counts them, paired with the
## target key each is checked against. Mirrors GameState's own naming
## quirk: akademis2 is Seni Budaya, akademis3 is Olahraga.
const SKILL_KEYS := [
	["akademis1", "base_akademis1", "target_akademis1"],
	["akademis2", "base_akademis2", "target_akademis2"],
	["akademis3", "base_akademis3", "target_akademis3"],
]


## The target every skill is measured against for `grade`. Duplicates
## GameState.initialize_grade_targets()'s uplift table rather than calling
## it, because that function works in place on GameState.approved_students
## and this one must stay pure.
static func target_for_grade(grade: int) -> float:
	var uplift := Balance.TARGET_KENAIKAN_KELAS_7
	match grade:
		8: uplift = Balance.TARGET_KENAIKAN_KELAS_8
		9: uplift = Balance.TARGET_KENAIKAN_KELAS_9
	return clampf(BASE_SKILL + uplift, 0.0, 100.0)


## Builds a rehearsal roster in approved_students' dictionary format.
## `source_students` supplies identity only (id, name, portrait, splash,
## quirk, persona, hobby_category and anything else the screens read);
## every stat is overwritten. The source is deep-copied, never mutated.
static func build_roster(preset: String, grade: int,
		source_students: Array) -> Array:
	var counts: Array = CLEARED_COUNTS.get(preset, CLEARED_COUNTS[PRESET_CAMPUR])
	var target := target_for_grade(grade)
	var cleared_value := clampf(target + CLEAR_MARGIN, 0.0, 100.0)
	var missed_value := clampf(target - MISS_MARGIN, 0.0, 100.0)

	var roster: Array = []
	for i in range(source_students.size()):
		var student: Dictionary = source_students[i].duplicate(true)
		var cleared: int = int(counts[mini(i, counts.size() - 1)])

		for s in range(SKILL_KEYS.size()):
			var value := cleared_value if s < cleared else missed_value
			student[SKILL_KEYS[s][0]] = value
			# base_* is what initialize_grade_targets() derives targets
			# from; setting it keeps the targets stable if any screen
			# recomputes them after the rehearsal is armed.
			student[SKILL_KEYS[s][1]] = BASE_SKILL
			student[SKILL_KEYS[s][2]] = target

		student["kepribadian1"] = REHEARSAL_MOOD
		student["kepribadian2"] = REHEARSAL_ENERGY
		roster.append(student)

	return roster


# ─────────────────────────────────────────────────────── snapshot / restore

## Every GameState field a rehearsal can move, directly or through the
## sequence it starts. RunResult's own progression is the reason this list
## is longer than what arm() writes: a rehearsal that runs to completion
## advances the grade, clears schedules, resets run_stats and may clear the
## roster, so all of that has to be captured up front.
const SNAPSHOT_KEYS := [
	"approved_students", "selected_student", "day_schedules",
	"pending_earnings", "grade7_student_ids", "inventory",
	"minggu_ke", "current_grade", "player_money",
	"run_failed", "is_exam_intro_cutscene", "is_game_beaten",
	"lobby_tutorial_completed", "tutorials_bypassed",
	"returned_from_student_card",
]


## Captures the current run. Collections are deep-copied and run_stats is
## duplicated, so nothing the rehearsal does afterwards writes through into
## the snapshot.
static func snapshot() -> Dictionary:
	var snap := {}
	for key in SNAPSHOT_KEYS:
		var value = GameState.get(key)
		if value is Array or value is Dictionary:
			snap[key] = value.duplicate(true)
		else:
			snap[key] = value
	snap["run_stats"] = GameState.run_stats.duplicate(true)
	return snap


## Puts a snapshot() back. Returns false (and changes nothing) for an empty
## dictionary, so a "restore" pressed before anything was ever armed is a
## logged no-op rather than a wipe.
##
## Known limitation, deliberate: assigning `inventory` back does not emit
## GameState.inventory_changed, so an Inventory screen left open across a
## restore keeps its old grid until it rebuilds. Restoring is a debug
## action taken from the overlay, before navigating anywhere, so the case
## does not arise in practice -- and emitting the signal here would fire it
## at screens mid-teardown.
static func restore(snap: Dictionary) -> bool:
	if snap.is_empty():
		return false

	# current_grade first: its setter recomputes max_minggu, so restoring
	# it after minggu_ke would leave the pair briefly inconsistent.
	if snap.has("current_grade"):
		GameState.current_grade = snap["current_grade"]

	for key in SNAPSHOT_KEYS:
		if key == "current_grade" or not snap.has(key):
			continue
		var value = snap[key]
		if value is Array or value is Dictionary:
			GameState.set(key, value.duplicate(true))
		else:
			GameState.set(key, value)

	if snap.has("run_stats") and snap["run_stats"] != null:
		GameState.run_stats = snap["run_stats"].duplicate(true)

	return true
