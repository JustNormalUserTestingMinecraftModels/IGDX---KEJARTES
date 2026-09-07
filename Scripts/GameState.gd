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

## Per-week tally of skill points each student has gained from minigame WINS,
## student_id -> float. Enforces Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_*.
## Cleared at week start (SchoolDay.start_simulation) and on grade change
## (reset_roster_for_new_grade). Session-scoped like everything here.
var minigame_gain_this_week: Dictionary = {}

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
var is_game_over_cutscene: bool = false
var grade7_student_ids: Array = []

## Per-grade tally consumed by the run-result screen. Never null; reset by
## set_grade() and by the grade-advance path in RunResult.
var run_stats: RunStats = RunStats.new()

## True while the exam cutscene branch of cut_scene.gd should play, set by
## TesNotice and cleared by the cutscene itself. Distinct from
## is_game_over_cutscene, which selects the losing branch.
var is_exam_intro_cutscene: bool = false

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
	var previous_grade: int = current_grade
	current_grade = grade_num
	minggu_ke = 1
	run_stats.reset()
	is_exam_intro_cutscene = false
	run_failed = false
	if current_grade != previous_grade:
		reset_roster_for_new_grade()  # no-op when the roster is empty
	print("GameState grade set to: Kelas ", current_grade, " (Minggu ", minggu_ke, ", Max Minggu ", max_minggu, ")")

## Rebases every roster student's three skill stats for a new grade: keep
## Balance.KENAIKAN_KELAS_HEAD_START_FRAKSI of the gains made above roster
## base, snap mood/energy to 80, and drop the cached base_akademis* so
## initialize_grade_targets() recomputes targets from the new baseline.
##
## Called by RunResult._apply_progression() on a real grade advance and by
## set_grade() on a debug grade-jump, so both paths behave identically.
## A no-op when approved_students is empty.
func reset_roster_for_new_grade() -> void:
	if approved_students.is_empty():
		return
	var frac: float = Balance.KENAIKAN_KELAS_HEAD_START_FRAKSI
	var skill_keys := [
		["akademis1", "roster_base_akademis1"],
		["akademis2", "roster_base_akademis2"],
		["akademis3", "roster_base_akademis3"],
	]
	for student in approved_students:
		for pair in skill_keys:
			var cur: float = float(student.get(pair[0], 50.0))
			if not student.has(pair[1]):
				student[pair[1]] = cur
			var rbase: float = float(student[pair[1]])
			student[pair[0]] = rbase + frac * maxf(0.0, cur - rbase)
		student["kepribadian1"] = 80.0
		student["kepribadian2"] = 80.0
		student.erase("base_akademis1")
		student.erase("base_akademis2")
		student.erase("base_akademis3")
	minigame_gain_this_week.clear()

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


const INVENTORY_SAVE_PATH := "user://inventory.cfg"

## Serialize `inventory` into `cfg` (pure -- no disk, no editor gate). Split
## out so a headless test can round-trip it without the is_editor_hint guard.
func _write_inventory_to(cfg: ConfigFile) -> void:
	cfg.set_value("inventory", "items", inventory.duplicate())

## Inverse of _write_inventory_to. A missing section leaves `inventory` empty.
## Coerces keys to String and values to int.
func _read_inventory_from(cfg: ConfigFile) -> void:
	var raw: Dictionary = cfg.get_value("inventory", "items", {})
	inventory.clear()
	for k in raw:
		inventory[String(k)] = int(raw[k])

## Persist the current inventory. No-op in editor/test context: a placeholder
## instance must never touch user://.
func save_inventory() -> void:
	if Engine.is_editor_hint():
		return
	var cfg := ConfigFile.new()
	_write_inventory_to(cfg)
	cfg.save(INVENTORY_SAVE_PATH)

## Load the persisted inventory at boot. Emits inventory_changed so any
## already-built screen rebuilds. No-op in editor/test context.
func load_inventory() -> void:
	if Engine.is_editor_hint():
		return
	var cfg := ConfigFile.new()
	if cfg.load(INVENTORY_SAVE_PATH) == OK:
		_read_inventory_from(cfg)
		inventory_changed.emit()

## Delete the on-disk inventory save, if present.
func clear_inventory_save() -> void:
	if FileAccess.file_exists(INVENTORY_SAVE_PATH):
		DirAccess.remove_absolute(INVENTORY_SAVE_PATH)

## Debug: return every session run-state field to its declared default and
## drop the on-disk inventory save. Deliberately leaves is_game_beaten and
## debug_level_select_enabled alone -- those are persisted progress flags
## (GameSettings writes them to settings.cfg), not run state.
func forget_session() -> void:
	next_scene = "res://Scenes/MainMenu/main_menu.tscn"
	returned_from_student_card = false
	approved_students = []
	selected_student = {}
	selected_day = ""
	day_schedules = {}
	minigame_gain_this_week = {}
	minggu_ke = 1
	lobby_tutorial_completed = false
	tutorials_bypassed = false
	current_grade = 7
	max_minggu = get_max_weeks()
	is_game_over_cutscene = false
	grade7_student_ids = []
	is_exam_intro_cutscene = false
	run_failed = false
	player_money = 0
	pending_earnings = {}
	inventory.clear()
	daily_login_day = 1
	last_claim_date = ""
	run_stats.reset()
	clear_inventory_save()
	inventory_changed.emit()


## Stat ceiling shared with StudentData's mood/energy range.
const STAT_MAX := 100.0

## Applies an item's boosts to ONE student in approved_students.
##
## The teammate's build had a single global player_mood/player_energy;
## this project tracks both per student, so the caller must say who. The
## approved_students dictionaries are the cross-screen source of truth,
## so that is what gets written. Writes the CANONICAL roster keys the
## simulation reads: kepribadian1 (mood), kepribadian2 (energy),
## akademis1/2/3 (the three skills) — never the dead "mood"/"energy" keys.
##
## Returns {"applied": bool, "mood_delta","energy_delta","akademis_delta",
## "seni_delta","olahraga_delta": float} — five deltas, each the amount that
## actually landed after clamping, which is what the inventory's floating
## stat-pop labels display.
func use_item(item: ItemData, student_id: int, quantity: int = 1) -> Dictionary:
	var refused := {"applied": false, "mood_delta": 0.0, "energy_delta": 0.0,
		"akademis_delta": 0.0, "seni_delta": 0.0, "olahraga_delta": 0.0}
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

	var fields := [
		["kepribadian1", item.mood_boost,        "mood_delta"],
		["kepribadian2", item.energy_boost,      "energy_delta"],
		["akademis1",    item.akademis_boost,    "akademis_delta"],
		["akademis2",    item.seni_budaya_boost, "seni_delta"],
		["akademis3",    item.olahraga_boost,    "olahraga_delta"],
	]
	var out := {"applied": true}
	for f in fields:
		var before: float = float(target.get(f[0], 0.0))
		var after := clampf(before + float(f[1]) * quantity, 0.0, STAT_MAX)
		target[f[0]] = after
		out[f[2]] = after - before

	remove_from_inventory(item.item_name, quantity)
	run_stats.record_item_use(quantity)
	return out


## Applies one copy of `item` to each id in `student_ids` (one application
## each; quantity is fixed at 1 per student). All-or-nothing: if the stack
## cannot cover every id, nothing is applied and "applied" is false.
## Returns {"applied": bool, "results": Array} where each result is
## {"student_id": int, "name": String, "mood_delta","energy_delta",
##  "akademis_delta","seni_delta","olahraga_delta": float}.
func use_item_on_students(item: ItemData, student_ids: Array) -> Dictionary:
	if item == null or student_ids.is_empty():
		return {"applied": false, "results": []}
	if get_inventory_quantity(item.item_name) < student_ids.size():
		return {"applied": false, "results": []}
	for sid in student_ids:
		var found := false
		for s in approved_students:
			if s.get("id", -1) == sid:
				found = true
				break
		if not found:
			return {"applied": false, "results": []}
	var results: Array = []
	for sid in student_ids:
		var sname := ""
		for s in approved_students:
			if s.get("id", -1) == sid:
				sname = str(s.get("name", ""))
				break
		var r := use_item(item, sid, 1)
		if r["applied"]:
			r.erase("applied")
			r["student_id"] = sid
			r["name"] = sname
			results.append(r)
	return {"applied": not results.is_empty(), "results": results}

var daily_login_day: int = 1
var last_claim_date: String = ""

func _ready():
	print("GameState siap")
	load_inventory()

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
		
		sd.target_akademis1 = dict.get("target_akademis1", 50.0)
		sd.target_akademis2 = dict.get("target_akademis2", 50.0)
		sd.target_akademis3 = dict.get("target_akademis3", 50.0)
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

func check_semester_passed() -> bool:
	var students = convert_to_student_data_array()
	if students.is_empty():
		return true
	for student in students:
		var tuntas_akademis = student.akademis >= student.target_akademis1
		var tuntas_seni = student.seni_budaya >= student.target_akademis2
		var tuntas_olahraga = student.olahraga >= student.target_akademis3
		if not (tuntas_akademis and tuntas_seni and tuntas_olahraga):
			return false
	return true


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
			if float(student.get(pair[0], 0.0)) >= float(student.get(pair[1], 0.0)):
				cleared += 1
	return [cleared, total]
