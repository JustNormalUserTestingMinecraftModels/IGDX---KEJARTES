@tool
extends McpTestSuite

## Headless greedy simulation: run each grade week-by-week against the REAL
## sim functions under two scripted player policies, assert the clear-week
## lands in the intended window. This is the tuning loop for the grade weeks
## and targets (GameState.WEEKS_BY_GRADE / TARGET_UPLIFT_BY_GRADE) and the
## weekly minigame cap -- if an assertion fails, retune and re-run (~2s), then
## update the spec's Status block. _weeks_to_clear returns weeks + 1 for a
## roster that never clears, so every bound below sits INSIDE the grade's own
## length: a bound at or past it would let "never cleared" pass.
##
## No coroutines. Deterministic: every scenario seeds the global RNG stream
## first (via the global seed()/randi_range/randf_range calls, not a local
## RandomNumberGenerator object).

func suite_name() -> String:
	return "balance_pacing"

# --- GameState snapshot/restore, so this suite never leaks its synthetic
# 4-student roster into whichever suite the runner executes next.
var _snap_current_grade: int
var _snap_approved_students: Array
var _snap_day_schedules: Dictionary
var _snap_minigame_gain_this_week: Dictionary

func setup() -> void:
	_snap_current_grade = GameState.current_grade
	_snap_approved_students = GameState.approved_students.duplicate(true)
	_snap_day_schedules = GameState.day_schedules.duplicate(true)
	_snap_minigame_gain_this_week = GameState.minigame_gain_this_week.duplicate(true)

func teardown() -> void:
	GameState.current_grade = _snap_current_grade
	GameState.approved_students = _snap_approved_students
	GameState.day_schedules = _snap_day_schedules
	GameState.minigame_gain_this_week = _snap_minigame_gain_this_week

# The real roster values, hard-copied from StudentCard.gd (student_data_list,
# lines ~896-1035) so a roster edit does not silently move the goalposts.
# Keys use the UI spelling. Only the first four roster students are used here
# (Marcel, Doni, Andi, Citra) -- the approved roster this harness seeds.
const ROSTER := [
	{"id": 1, "name": "Marcel", "hobby_category": "Akademis", "personality": "Tekun",
	 "quirk": "Kutu Buku", "akademis": 28.0, "seni_budaya": 48.0, "olahraga": 38.0,
	 "mood": 60.0, "energy": 55.0},
	{"id": 2, "name": "Doni", "hobby_category": "Olahraga", "personality": "Aktif",
	 "quirk": "Semangat Juang", "akademis": 38.0, "seni_budaya": 22.0, "olahraga": 33.0,
	 "mood": 55.0, "energy": 55.0},
	{"id": 3, "name": "Andi", "hobby_category": "SeniBudaya", "personality": "Kreatif",
	 "quirk": "Penasaran", "akademis": 48.0, "seni_budaya": 55.0, "olahraga": 32.0,
	 "mood": 60.0, "energy": 60.0},
	{"id": 4, "name": "Citra", "hobby_category": "Olahraga", "personality": "Seni Dalam Kesunyian",
	 "quirk": "Penyendiri", "akademis": 28.0, "seni_budaya": 25.0, "olahraga": 15.0,
	 "mood": 35.0, "energy": 60.0},
]

const SUBJECTS := ["Akademis", "SeniBudaya", "Olahraga"]
const DAY_NAMES := ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]

func _grade_uplift(grade: int) -> float:
	return GameState.target_uplift_for_grade(grade)

# Build a fresh approved_students with roster_base_* and per-grade targets.
func _seed_gamestate(grade: int) -> void:
	GameState.current_grade = grade
	GameState.approved_students = []
	for r in ROSTER:
		var s: Dictionary = r.duplicate(true)
		s["roster_base_akademis"] = s["akademis"]
		s["roster_base_seni_budaya"] = s["seni_budaya"]
		s["roster_base_olahraga"] = s["olahraga"]
		var up := _grade_uplift(grade)
		s["target_akademis"] = clampf(s["akademis"] + up, 0.0, 100.0)
		s["target_seni_budaya"] = clampf(s["seni_budaya"] + up, 0.0, 100.0)
		s["target_olahraga"] = clampf(s["olahraga"] + up, 0.0, 100.0)
		GameState.approved_students.append(s)
	GameState.day_schedules = {}
	GameState.minigame_gain_this_week = {}

# --- policies: return an Array[String] of 5 day categories for one student/week
func _policy_well_played(student: Dictionary, week: int) -> Array:
	# Rotate the focus subject week to week so all three targets advance.
	var focus: String = SUBJECTS[week % 3]
	var spec: String = ActivityPreview._specialty_of(student)
	var plan := []
	for d in range(5):
		if d == 4:
			plan.append("Istirahat")           # one guaranteed recovery day
		elif d < 2 and spec in SUBJECTS:
			plan.append(spec)                   # bank specialty progress cheaply
		else:
			plan.append(focus)
	return plan

func _policy_careless(_student: Dictionary, _week: int) -> Array:
	return ["Akademis", "SeniBudaya", "Olahraga", "Akademis", "SeniBudaya"]

func _policy_stack_exploit(_student: Dictionary, week: int) -> Array:
	var subj: String = SUBJECTS[week % 3]
	return [subj, subj, subj, subj, subj]

# Run one week: writes day_schedules, runs 5 days of decay+activity, injects
# `minigames` minigame results, writes stats back. Returns nothing; mutates
# GameState.approved_students via StudentManager.
func _run_week(policy: Callable, week: int, minigames: int, win_ratio: float) -> void:
	GameState.minigame_gain_this_week = {}
	GameState.day_schedules = {}
	for student in GameState.approved_students:
		var cats: Array = policy.call(student, week)
		var per_day := {}
		for i in range(5):
			per_day[DAY_NAMES[i]] = {"category": cats[i], "mood_cost": 0, "energy_cost": 0}
		GameState.day_schedules[int(student["id"])] = per_day

	var sm := StudentManager.new()
	sm.initialize_from_gamestate()
	for i in range(5):
		sm.apply_daily_decay_all(DAY_NAMES[i])
		if i < minigames:
			var cat: String = SUBJECTS[(week + i) % 3]
			var mx := 4
			var sc := int(round(win_ratio * mx))
			sm.record_minigame_result(DAY_NAMES[i], cat, "sim", true, sc, mx)
	sm.write_back_to_gamestate()

func _all_cleared() -> bool:
	return GameState.check_semester_passed()

# Play a grade start-to-finish under one policy on one seed; return the 1-based
# week the roster fully cleared, or weeks+1 if it never did.
func _weeks_to_clear(grade: int, policy: Callable, seed_val: int) -> int:
	seed(seed_val)
	_seed_gamestate(grade)
	var weeks: int = GameState.get_max_weeks()
	for w in range(1, weeks + 1):
		var mg := randi_range(Balance.MINIGAME_MAKS_MINGGU_MIN, Balance.MINIGAME_MAKS_MINGGU_MAX)
		var ratio := 0.7 if policy == Callable(self, "_policy_well_played") else 0.4
		_run_week(policy, w, mg, ratio)
		if _all_cleared():
			return w
	return weeks + 1

func test_grade7_well_played_clears_by_week_3_not_before_2() -> void:
	var w := _weeks_to_clear(7, Callable(self, "_policy_well_played"), 12345)
	assert_true(w >= 2, "grade 7 must not be clearable in week 1, cleared week %d" % w)
	assert_true(w <= 3, "grade 7 (well played) should clear by week 3 of 4, took %d" % w)

func test_grade7_careless_still_clears_within_four_weeks() -> void:
	var w := _weeks_to_clear(7, Callable(self, "_policy_careless"), 777)
	assert_true(w <= 4, "grade 7 must never be unwinnable; careless took %d" % w)

func test_grade8_well_played_clears_by_week_5() -> void:
	var w := _weeks_to_clear(8, Callable(self, "_policy_well_played"), 22)
	assert_true(w <= 5, "grade 8 (well played) should clear by week 5 of 6, took %d" % w)

func test_grade9_well_played_clears_by_week_7() -> void:
	var w := _weeks_to_clear(9, Callable(self, "_policy_well_played"), 99)
	assert_true(w <= 7, "grade 9 (well played) should clear by week 7 of 8, took %d" % w)

## Even a careless roster can win the two long grades: the targets were
## halved-and-then-some for 6 and 8 weeks because 34 / 40 could not be cleared.
func test_grade8_and_9_careless_still_clear_within_the_grade() -> void:
	var w8 := _weeks_to_clear(8, Callable(self, "_policy_careless"), 22)
	assert_true(w8 <= 6, "grade 8 must never be unwinnable; careless took %d" % w8)
	var w9 := _weeks_to_clear(9, Callable(self, "_policy_careless"), 99)
	assert_true(w9 <= 8, "grade 9 must never be unwinnable; careless took %d" % w9)

func test_well_played_is_not_seed_luck() -> void:
	var total := 0
	var seeds := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
	var worst := 0
	for s in seeds:
		var w := _weeks_to_clear(7, Callable(self, "_policy_well_played"), s)
		total += w
		worst = maxi(worst, w)
	var mean := float(total) / float(seeds.size())
	assert_true(mean >= 2.0 and mean <= 3.5,
		"grade 7 well-played mean clear-week should sit in [2, 3.5], got %.2f" % mean)
	assert_true(worst <= 3, "no seed should push grade 7 well-played past week 3, worst %d" % worst)

func test_stack_exploit_edge_is_bounded() -> void:
	var seeds := [3, 14, 15, 92, 65]
	for s in seeds:
		var wp := _weeks_to_clear(7, Callable(self, "_policy_well_played"), s)
		var ex := _weeks_to_clear(7, Callable(self, "_policy_stack_exploit"), s)
		assert_true(ex >= wp - 1,
			"stacking one subject must not beat well-played by more than 1 week (seed %d: %d vs %d)" % [s, ex, wp])
