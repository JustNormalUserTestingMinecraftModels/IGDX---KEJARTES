@tool
extends Node

## The source of truth for a run.
##
## An autoload. Everything the player does between the main menu and the
## semester end lands here: the approved roster, the week's schedules, the
## current week and grade, money, and the inventory. There is deliberately
## no save system -- a run is session-scoped, and adding persistence here
## is a design change, not a refactor.
##
## Written by: student_card.gd (approves the roster into
## `approved_students`), atur_jadwal.gd (fills `day_schedules`),
## StudentManager.write_back_to_gamestate() (pushes simulated stats back
## after each day), koprasi.gd and Cart (`player_money`, `inventory`), and
## DebugManager (every field, on purpose -- that is what the debug overlay
## is for).
##
## Read by: every screen.
##
## The trap: `approved_students` holds Array[Dictionary] whose keys are the
## UI's names -- `akademis1/2/3` are academic/seni/olahraga, and
## `kepribadian1/2` are mood/energy. StudentData, used inside the
## simulation, has real field names instead. convert_to_student_data_array()
## bridges in and StudentManager.write_back_to_gamestate() bridges out. The
## two namings do not line up, and that mismatch is the most common source
## of bugs here.

# Scene navigation
var next_scene: String = "res://Scenes/MainMenu/main_menu.tscn"

# Student selection state (from student_card)
var returned_from_student_card: bool = false
var approved_students: Array = []  # Array of Dictionary (reference format)
var selected_student: Dictionary = {}
var selected_day: String = ""

# Jadwal storage: day_schedules[student_id][day_name] = {category, mood_cost, energy_cost}
var day_schedules: Dictionary = {}

# Week tracking  
var minggu_ke: int = 1
var max_minggu: int = 6
var lobby_tutorial_completed: bool = false
## Debug-menu master switch: true skips every tutorial in the game (lobby,
## atur jadwal, student card, student list, school day, minigames), not just
## the lobby one. Session-scoped like everything else on GameState -- no save.
var tutorials_bypassed: bool = false
var current_grade: int = 7:
	set(val):
		current_grade = clampi(val, 7, 9)
		max_minggu = get_max_weeks()
var is_game_beaten: bool = false
var debug_level_select_enabled: bool = true
var grade7_student_ids: Array = []

## Per-grade tally consumed by the run-result screen. Never null; reset by
## set_grade() and by the grade-advance path in RunResult.
var run_stats: RunStats = RunStats.new()

## True once the stat check has decided the run was lost. Read by
## RunResult to force a D grade without re-running the evaluation.
var run_failed: bool = false

func get_max_weeks() -> int:
	match current_grade:
		8: return Balance.JUMLAH_MINGGU_KELAS_8
		9: return Balance.JUMLAH_MINGGU_KELAS_9
		_: return Balance.JUMLAH_MINGGU_KELAS_7

func get_grade_from_week() -> int:
	return current_grade

func get_grade_name() -> String:
	return "Kelas " + str(current_grade)

func set_grade(grade_num: int) -> void:
	current_grade = grade_num
	minggu_ke = 1
	run_stats.reset()
	run_failed = false
	print("GameState grade set to: Kelas ", current_grade, " (Minggu ", minggu_ke, ", Max Minggu ", max_minggu, ")")

func initialize_grade_targets() -> void:
	for student in approved_students:
		if not student.has("base_akademis1"):
			student["base_akademis1"] = student.get("akademis1", 50.0)
		if not student.has("base_akademis2"):
			student["base_akademis2"] = student.get("akademis2", 50.0)
		if not student.has("base_akademis3"):
			student["base_akademis3"] = student.get("akademis3", 50.0)
			
		var b1 = student["base_akademis1"]
		var b2 = student["base_akademis2"]
		var b3 = student["base_akademis3"]
		
		var uplift := Balance.TARGET_KENAIKAN_KELAS_7
		match current_grade:
			8: uplift = Balance.TARGET_KENAIKAN_KELAS_8
			9: uplift = Balance.TARGET_KENAIKAN_KELAS_9
		student["target_akademis1"] = clampf(b1 + uplift, 0.0, 100.0)
		student["target_akademis2"] = clampf(b2 + uplift, 0.0, 100.0)
		student["target_akademis3"] = clampf(b3 + uplift, 0.0, 100.0)
		print("Initialized targets for student: ", student.get("name", ""), " to [", student["target_akademis1"], ", ", student["target_akademis2"], ", ", student["target_akademis3"], "]")



# Currency
signal money_changed(new_amount: int)
signal inventory_changed

var _player_money: int = 0

var player_money: int:
	get: return _player_money
	set(value):
		_player_money = value
		money_changed.emit(value)

## Inventory: item_name -> quantity. Session-scoped, like every other
## field on this autoload -- the project has no save system.
var inventory: Dictionary = {}  ## Tracks item quantities by name

## Wirausaha earnings accrued this week, student_id -> rupiah. Emptied by
## SchoolDay at week end, when the total is paid into player_money.
var pending_earnings: Dictionary = {}


func add_to_inventory(item_name: String, quantity: int) -> void:
	inventory[item_name] = inventory.get(item_name, 0) + quantity
	inventory_changed.emit()


func remove_from_inventory(item_name: String, quantity: int = 1) -> bool:
	if not inventory.has(item_name):
		return false
	inventory[item_name] -= quantity
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	inventory_changed.emit()
	return true


func get_inventory_quantity(item_name: String) -> int:
	return inventory.get(item_name, 0)


## Debug/playtest helper: stock one entry per known item so a session can
## exercise the inventory screen without driving the shop purchase flow.
##
## Replaces the inventory rather than adding to it, so repeated calls are
## idempotent, and emits inventory_changed once at the end rather than once
## per item -- listening screens rebuild their grid on that signal.
func seed_playtest_inventory(quantity: int = 2) -> void:
	inventory.clear()
	if quantity > 0:
		for item in ItemDatabase.get_all_items():
			inventory[item.item_name] = quantity
	inventory_changed.emit()


## Stat ceiling shared with StudentData's mood/energy range.
const STAT_MAX := 100.0

## Applies an item's boosts to ONE student in approved_students.
##
## The teammate's build had a single global player_mood/player_energy;
## this project tracks both per student, so the caller must say who. The
## approved_students dictionaries are the cross-screen source of truth,
## so that is what gets written.
##
## Returns {"applied": bool, "mood_delta": float, "energy_delta": float}.
## The deltas are what actually landed after clamping, which is what the
## inventory's floating stat-pop labels display.
func use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary:
	var refused := {"applied": false, "mood_delta": 0.0, "energy_delta": 0.0}
	if item == null or quantity <= 0:
		return refused
	if get_inventory_quantity(item.item_name) < quantity:
		return refused

	var target: Dictionary = {}
	for student in approved_students:
		if student.get("id", -1) == student_id:
			target = student
			break
	if target.is_empty():
		return refused

	var mood_before: float = float(target.get("mood", 0.0))
	var energy_before: float = float(target.get("energy", 0.0))
	var mood_after := clampf(mood_before + item.mood_boost * quantity, 0.0, STAT_MAX)
	var energy_after := clampf(energy_before + item.energy_boost * quantity, 0.0, STAT_MAX)
	target["mood"] = mood_after
	target["energy"] = energy_after

	remove_from_inventory(item.item_name, quantity)
	run_stats.record_item_use(quantity)

	return {
		"applied": true,
		"mood_delta": mood_after - mood_before,
		"energy_delta": energy_after - energy_before,
	}

var daily_login_day: int = 1
var last_claim_date: String = ""

func _ready():
	print("GameState siap")

# --- Converter: Dictionary → StudentData (for simulation) ---
func convert_to_student_data_array() -> Array[StudentData]:
	var result: Array[StudentData] = []
	for dict in approved_students:
		var sd = StudentData.new()
		sd.id = dict.get("id", 0)
		sd.student_name = dict.get("name", "")
		sd.akademis = dict.get("akademis1", 50.0)
		sd.seni_budaya = dict.get("akademis2", 50.0)
		sd.olahraga = dict.get("akademis3", 50.0)
		sd.mood = dict.get("kepribadian1", 80.0)
		sd.energy = dict.get("kepribadian2", 80.0)
		
		# 0.0, not 50.0: count_targets_cleared() reads the same three keys
		# with a 0.0 default, and the two sides of the bridge must agree on
		# what an uninitialized target looks like. See target_cleared().
		sd.target_akademis1 = dict.get("target_akademis1", 0.0)
		sd.target_akademis2 = dict.get("target_akademis2", 0.0)
		sd.target_akademis3 = dict.get("target_akademis3", 0.0)
		sd.target_kepribadian1 = dict.get("target_kepribadian1", 50.0)
		sd.target_kepribadian2 = dict.get("target_kepribadian2", 50.0)
		sd.quirk = dict.get("quirk", "")
		sd.persona = dict.get("persona", "")
		sd.personality = dict.get("personality", "Santai")
		sd.profil = dict.get("profil", "")
		sd.splash_path = dict.get("splash", "")
		
		var port_path = dict.get("portrait", "")
		if port_path != "" and ResourceLoader.exists(port_path):
			sd.avatar_texture = load(port_path)
		
		# Map hobby_category: "Akademik" → "Akademis"
		var hobby = dict.get("hobby_category", "")
		sd.specialty_category = "Akademis" if hobby == "Akademik" else hobby
		sd.record_initial_stats()
		result.append(sd)
	return result

# Get jadwal for a day across all approved students
func get_jadwal_for_day(day_name: String) -> Dictionary:
	# Returns {category_name: count} for weighted minigame selection
	var counts = {"Akademis": 0, "Olahraga": 0, "SeniBudaya": 0, "Istirahat": 0, "Wirausaha": 0}
	for student in approved_students:
		var sid = student.get("id", null)
		if sid != null and day_schedules.has(sid):
			var cat = day_schedules[sid].get(day_name, {}).get("category", "")
			# Normalize: "Akademis" → "Akademis", "Istirahat" → "Istirahat"
			if cat == "Akademis": cat = "Akademis"
			elif cat == "Istirahat": cat = "Istirahat"
			if counts.has(cat):
				counts[cat] += 1
	return counts

## The run's star meter, 0.0 to Balance.STARS_TOTAL: every academic target
## cleared anywhere on the roster earns an equal share of the three stars.
## Continuous on purpose -- StatCheck's meter fills star by star as the
## check plays, and 7 of 12 must read as 1.75, not "1".
func run_stars() -> float:
	var counted: Array = count_targets_cleared()
	var total := int(counted[1])
	if total <= 0:
		return 0.0
	return Balance.STARS_TOTAL * float(counted[0]) / float(total)


## Win rule since Plan A: the star meter at or above
## Balance.STAR_WIN_THRESHOLD. Replaces "every student clears all three
## targets" -- one weak student on a strong roster no longer loses the run.
## An empty roster still passes, as it always did, so a debug teleport with
## nothing approved never reads as a loss.
func check_semester_passed() -> bool:
	if approved_students.is_empty():
		return true
	return run_stars() >= Balance.STAR_WIN_THRESHOLD


## Counts how many of the roster's three-per-student academic targets have
## been cleared, as [cleared, total]. RunGrade's dominant scoring
## component -- kept here rather than in RunResult because it reads the
## approved_students dictionaries, whose key naming (akademis1/2/3 =
## academic/seni/olahraga) is this file's own concern.
func count_targets_cleared() -> Array:
	var cleared := 0
	var total := 0
	for student in approved_students:
		var pairs := [
			["akademis1", "target_akademis1"],
			["akademis2", "target_akademis2"],
			["akademis3", "target_akademis3"],
		]
		for pair in pairs:
			total += 1
			if target_cleared(float(student.get(pair[0], 0.0)),
					float(student.get(pair[1], 0.0))):
				cleared += 1
	return [cleared, total]


## The one predicate for "this stat cleared its target", shared by the
## verdict (count_targets_cleared, and so run_stars and
## check_semester_passed) and by the reveal (StatCheckRow.ratio, which
## reaches 100 on exactly this condition).
##
## A target of zero or less is NOT cleared. Targets are only ever zero when
## initialize_grade_targets() never ran, which is a data bug -- and the two
## sides used to disagree about it: this function's `value >= target` read a
## missing target as cleared while the bar filled to 0%, so a malformed
## roster could show an empty star meter and still route to the win screen.
## Failing an uninitialized target keeps the meter and the verdict telling
## the same story.
static func target_cleared(value: float, target: float) -> bool:
	if target <= 0.0:
		return false
	return value >= target
