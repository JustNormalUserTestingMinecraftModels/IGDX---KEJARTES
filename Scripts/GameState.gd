extends Node

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
var current_grade: int = 7:
	set(val):
		current_grade = clampi(val, 7, 9)
		max_minggu = get_max_weeks()
var is_game_beaten: bool = false
var debug_level_select_enabled: bool = true
var is_game_over_cutscene: bool = false
var grade7_student_ids: Array = []

func get_max_weeks() -> int:
	match current_grade:
		7: return 6
		8: return 12
		9: return 16
		_: return 6

func get_grade_from_week() -> int:
	return current_grade

func get_grade_name() -> String:
	return "Kelas " + str(current_grade)

func set_grade(grade_num: int) -> void:
	current_grade = grade_num
	minggu_ke = 1
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
		
		match current_grade:
			7:
				student["target_akademis1"] = clampf(b1 + 15.0, 0.0, 100.0)
				student["target_akademis2"] = clampf(b2 + 15.0, 0.0, 100.0)
				student["target_akademis3"] = clampf(b3 + 15.0, 0.0, 100.0)
			8:
				student["target_akademis1"] = clampf(b1 + 30.0, 0.0, 100.0)
				student["target_akademis2"] = clampf(b2 + 30.0, 0.0, 100.0)
				student["target_akademis3"] = clampf(b3 + 30.0, 0.0, 100.0)
			9:
				student["target_akademis1"] = clampf(b1 + 40.0, 0.0, 100.0)
				student["target_akademis2"] = clampf(b2 + 40.0, 0.0, 100.0)
				student["target_akademis3"] = clampf(b3 + 40.0, 0.0, 100.0)
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
	var counts = {"Akademis": 0, "Olahraga": 0, "SeniBudaya": 0, "Istirahat": 0}
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
