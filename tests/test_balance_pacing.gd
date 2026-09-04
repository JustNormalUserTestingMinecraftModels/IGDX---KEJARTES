@tool
extends McpTestSuite

## Headless greedy simulation: run each grade week-by-week against the REAL
## sim functions under two scripted player policies, assert the clear-week
## lands in the intended window. This is the tuning loop for Balance.gd's
## grade 8/9 targets and the weekly minigame cap -- if an assertion fails,
## retune Balance and re-run (~2s), then update the spec's Status block.
##
## No coroutines. Deterministic: every scenario seeds the RNG first.

func suite_name() -> String:
	return "balance_pacing"

# The real roster values, hard-copied from student_card.gd (student_data_list,
# lines ~896-1035) so a roster edit does not silently move the goalposts.
# Keys use the UI spelling. Only the first four roster students are used here
# (Marcel, Doni, Andi, Citra) -- the approved roster this harness seeds.
const ROSTER := [
	{"id": 1, "name": "Marcel", "hobby_category": "Akademis", "personality": "Tekun",
	 "quirk": "Kutu Buku", "akademis1": 28.0, "akademis2": 48.0, "akademis3": 38.0,
	 "kepribadian1": 60.0, "kepribadian2": 55.0},
	{"id": 2, "name": "Doni", "hobby_category": "Olahraga", "personality": "Aktif",
	 "quirk": "Semangat Juang", "akademis1": 38.0, "akademis2": 22.0, "akademis3": 33.0,
	 "kepribadian1": 55.0, "kepribadian2": 55.0},
	{"id": 3, "name": "Andi", "hobby_category": "SeniBudaya", "personality": "Kreatif",
	 "quirk": "Penasaran", "akademis1": 48.0, "akademis2": 55.0, "akademis3": 32.0,
	 "kepribadian1": 60.0, "kepribadian2": 60.0},
	{"id": 4, "name": "Citra", "hobby_category": "Olahraga", "personality": "Seni Dalam Kesunyian",
	 "quirk": "Penyendiri", "akademis1": 28.0, "akademis2": 25.0, "akademis3": 15.0,
	 "kepribadian1": 35.0, "kepribadian2": 60.0},
]

const SUBJECTS := ["Akademis", "SeniBudaya", "Olahraga"]
const DAY_NAMES := ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]

func _grade_uplift(grade: int) -> float:
	match grade:
		8: return Balance.TARGET_KENAIKAN_KELAS_8
		9: return Balance.TARGET_KENAIKAN_KELAS_9
		_: return Balance.TARGET_KENAIKAN_KELAS_7

# Build a fresh approved_students with roster_base_* and per-grade targets.
func _seed_gamestate(grade: int) -> void:
	GameState.current_grade = grade
	GameState.approved_students = []
	for r in ROSTER:
		var s: Dictionary = r.duplicate(true)
		s["roster_base_akademis1"] = s["akademis1"]
		s["roster_base_akademis2"] = s["akademis2"]
		s["roster_base_akademis3"] = s["akademis3"]
		var up := _grade_uplift(grade)
		s["target_akademis1"] = clampf(s["akademis1"] + up, 0.0, 100.0)
		s["target_akademis2"] = clampf(s["akademis2"] + up, 0.0, 100.0)
		s["target_akademis3"] = clampf(s["akademis3"] + up, 0.0, 100.0)
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
func _run_week(policy: Callable, week: int, rng: RandomNumberGenerator, minigames: int, win_ratio: float) -> void:
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
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	seed(seed_val)
	_seed_gamestate(grade)
	var weeks: int = GameState.get_max_weeks()
	for w in range(1, weeks + 1):
		var mg := randi_range(Balance.MINIGAME_MAKS_MINGGU_MIN, Balance.MINIGAME_MAKS_MINGGU_MAX)
		var ratio := 0.7 if policy == Callable(self, "_policy_well_played") else 0.4
		_run_week(policy, w, rng, mg, ratio)
		if _all_cleared():
			return w
	return weeks + 1

func test_grade7_well_played_clears_by_week_4_not_before_2() -> void:
	var w := _weeks_to_clear(7, Callable(self, "_policy_well_played"), 12345)
	assert_true(w >= 2, "grade 7 must not be clearable in week 1, cleared week %d" % w)
	assert_true(w <= 4, "grade 7 (well played) should clear by week 4, took %d" % w)

func test_grade7_careless_still_clears_within_six_weeks() -> void:
	var w := _weeks_to_clear(7, Callable(self, "_policy_careless"), 777)
	assert_true(w <= 6, "grade 7 must never be unwinnable; careless took %d" % w)

func test_grade8_well_played_clears_by_week_9() -> void:
	var w := _weeks_to_clear(8, Callable(self, "_policy_well_played"), 22)
	assert_true(w <= 9, "grade 8 (well played) should clear by week 9, took %d" % w)

func test_grade9_well_played_clears_by_week_14() -> void:
	var w := _weeks_to_clear(9, Callable(self, "_policy_well_played"), 99)
	assert_true(w <= 14, "grade 9 (well played) should clear by week 14, took %d" % w)

func test_well_played_is_not_seed_luck() -> void:
	var total := 0
	var seeds := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
	var worst := 0
	for s in seeds:
		var w := _weeks_to_clear(7, Callable(self, "_policy_well_played"), s)
		total += w
		worst = maxi(worst, w)
	var mean := float(total) / float(seeds.size())
	assert_true(mean >= 2.0 and mean <= 4.5,
		"grade 7 well-played mean clear-week should sit in [2, 4.5], got %.2f" % mean)
	assert_true(worst <= 5, "no seed should push grade 7 well-played past week 5, worst %d" % worst)

func test_stack_exploit_edge_is_bounded() -> void:
	var seeds := [3, 14, 15, 92, 65]
	for s in seeds:
		var wp := _weeks_to_clear(7, Callable(self, "_policy_well_played"), s)
		var ex := _weeks_to_clear(7, Callable(self, "_policy_stack_exploit"), s)
		assert_true(ex >= wp - 1,
			"stacking one subject must not beat well-played by more than 1 week (seed %d: %d vs %d)" % [s, ex, wp])
