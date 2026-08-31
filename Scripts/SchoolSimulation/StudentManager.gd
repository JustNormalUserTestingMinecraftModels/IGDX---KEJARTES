extends Node
class_name StudentManager

## Drives one school day's simulation for the `StudentData` roster.
##
## Not an autoload -- SchoolDay.gd instantiates one per day. Holds the
## `Array[StudentData]` being simulated (`initialize_from_gamestate()`
## builds it from `GameState.convert_to_student_data_array()`), logs
## every stat change to `daily_stat_log` for the end-of-day/end-of-week
## summaries, and at the end of the day `write_back_to_gamestate()`
## pushes the simulated stats back onto `GameState.approved_students` --
## remapping StudentData's real field names to the UI's
## akademis1/2/3 + kepribadian1/2 keys, the same mismatch documented on
## GameState.gd.
##
## Wirausaha balance numbers now live in Scripts/Balance.gd.

var students: Array[StudentData] = []
var minigame_history: Array[Dictionary] = [] # entries: {day, category, game_name, won, details}

# daily_stat_log[day_name] = Array of {student_name, stat_key, delta, source}
# stat_key: "akademis"|"seni_budaya"|"olahraga"|"energy"|"mood"
# source: "decay"|"activity"|"minigame_win"|"minigame_loss"|"event"|"holiday"
var daily_stat_log: Dictionary = {}

func _init() -> void:
	initialize_students()

func initialize_students() -> void:
	students.clear()
	minigame_history.clear()
	daily_stat_log.clear()
	
	var student_names = ["Budi", "Ani", "Cici", "Doni"]
	var personalities = ["Aktif", "Tekun", "Kreatif", "Santai"]
	var personality_descs = [
		"Sporty & Energik",
		"Akademis & Serius",
		"Seni & Ekspresif",
		"Seimbang & Santai"
	]
	var specialties = ["Olahraga", "Akademis", "SeniBudaya", "Seimbang"]
	
	# We can initialize students with slightly different base stats to make them unique
	var base_stats = [
		{"akademis": 45, "seni_budaya": 40, "olahraga": 65, "energy": 80, "mood": 85}, # Budi: sporty
		{"akademis": 70, "seni_budaya": 50, "olahraga": 35, "energy": 75, "mood": 90}, # Ani: academic
		{"akademis": 40, "seni_budaya": 68, "olahraga": 45, "energy": 85, "mood": 75}, # Cici: artistic
		{"akademis": 55, "seni_budaya": 52, "olahraga": 50, "energy": 80, "mood": 80}  # Doni: balanced
	]
	
	for i in range(4):
		var student = StudentData.new()
		student.student_name = student_names[i]
		student.personality = personalities[i]
		student.personality_desc = personality_descs[i]
		student.specialty_category = specialties[i]
		student.akademis = base_stats[i]["akademis"]
		student.seni_budaya = base_stats[i]["seni_budaya"]
		student.olahraga = base_stats[i]["olahraga"]
		student.energy = base_stats[i]["energy"]
		student.mood = base_stats[i]["mood"]
		
		var port_path = "res://Assets/Images/MuridPotrait/Murid%d.jpg" % (i + 1)
		if ResourceLoader.exists(port_path):
			student.avatar_texture = load(port_path)
			
		student.record_initial_stats()
		students.append(student)

func record_minigame_result(day_name: String, category: String, game_name: String, won: bool, score: int = -1, max_score: int = -1) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for student in students:
		var deltas = student.apply_minigame_result(category, won, score, max_score)
		results.append({
			"student_name": student.student_name,
			"deltas": deltas
		})
		
		# Log minigame stat changes
		var mg_source = "minigame_win" if won else "minigame_loss"
		var mg_stat_key_map = {"Akademis": "akademis", "SeniBudaya": "seni_budaya", "Olahraga": "olahraga"}
		var mg_sk = mg_stat_key_map.get(category, "")
		if mg_sk != "":
			log_stat_change(day_name, student.student_name, mg_sk, deltas.get("stat_delta", 0.0), mg_source)
		log_stat_change(day_name, student.student_name, "energy", deltas.get("energy_delta", 0.0), mg_source)
		log_stat_change(day_name, student.student_name, "mood", deltas.get("mood_delta", 0.0), mg_source)
	
	minigame_history.append({
		"day": day_name,
		"category": category,
		"game_name": game_name,
		"won": won,
		"score": score,
		"max_score": max_score,
		"results": results
	})
	
	return results

func apply_daily_decay_all(day_name: String) -> Array[Dictionary]:
	var decay_results: Array[Dictionary] = []
	
	# ── Pre-compute how many students share each subject today ──
	var category_counts: Dictionary = {}
	for s in students:
		var sid = s.id
		var cat = "Istirahat"
		if sid != 0 and GameState.day_schedules.has(sid):
			var day_sched = GameState.day_schedules[sid].get(day_name, {})
			var sched_cat = day_sched.get("category", "")
			if sched_cat != "":
				cat = sched_cat
				if cat == "Akademik": cat = "Akademis"
				elif cat == "DayOff": cat = "Istirahat"
		if not category_counts.has(cat):
			category_counts[cat] = 0
		category_counts[cat] += 1
	
	for student in students:
		# 1. Base personality decay
		var decay_res = student.apply_personality_daily_decay()
		var energy_loss = decay_res["energy_loss"]
		var mood_loss = decay_res["mood_loss"]
		var reason = decay_res["reason"]
		
		# 2. Activity / Rest based on schedule
		var category = "Istirahat" # Default to Istirahat (Libur) if unassigned
		var student_id = student.id
		if student_id != 0 and GameState.day_schedules.has(student_id):
			var day_sched = GameState.day_schedules[student_id].get(day_name, {})
			var sched_category = day_sched.get("category", "")
			if sched_category != "":
				category = sched_category
				if category == "Akademik": category = "Akademis"
				elif category == "DayOff": category = "Istirahat"
		
		var same_subject_count: int = category_counts.get(category, 1)
		
		var activity_reason = ""
		var act_res: Dictionary = {}
		if category == "Wirausaha":
			var energy_fraction: float = clampf(student.energy / 100.0, 0.0, 1.0)
			var floor_frac: float = Balance.WIRAUSAHA_BATAS_BAWAH_ENERGI
			var multiplier: float = floor_frac + (1.0 - floor_frac) * energy_fraction
			var earned: int = int(round(randi_range(Balance.WIRAUSAHA_UANG_MIN,
				Balance.WIRAUSAHA_UANG_MAX) * multiplier))
			GameState.pending_earnings[student.id] = GameState.pending_earnings.get(student.id, 0) + earned

			student.mood = clampf(student.mood - Balance.WIRAUSAHA_BIAYA_MOOD, 0.0, 100.0)
			student.energy = clampf(student.energy - Balance.WIRAUSAHA_BIAYA_ENERGI, 0.0, 100.0)
			mood_loss += Balance.WIRAUSAHA_BIAYA_MOOD
			energy_loss += Balance.WIRAUSAHA_BIAYA_ENERGI
			activity_reason = " & Wirausaha (Rp%d)" % earned
			log_stat_change(day_name, student.student_name, "mood", -Balance.WIRAUSAHA_BIAYA_MOOD, "activity")
			log_stat_change(day_name, student.student_name, "energy", -Balance.WIRAUSAHA_BIAYA_ENERGI, "activity")
		elif category != "":
			var base_gain := Balance.BELAJAR_POIN_KELAS_7
			var specialty_bonus := Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
			var grade_num = GameState.current_grade
			if grade_num == 8:
				base_gain = Balance.BELAJAR_POIN_KELAS_8
				specialty_bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
			elif grade_num == 9:
				base_gain = Balance.BELAJAR_POIN_KELAS_9
				specialty_bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
			act_res = student.apply_jadwal_activity(category, base_gain, specialty_bonus, same_subject_count)
			var e_delta = act_res["energy_delta"]
			var m_delta = act_res["mood_delta"]
			
			energy_loss -= e_delta
			mood_loss -= m_delta
			
			if act_res.get("took_ijin", false):
				var ijin_msg = act_res.get("ijin_reason", "Izin (Istirahat) memulihkan tenaga")
				activity_reason = " & " + ijin_msg
				record_event_result(day_name, "Izin Sakit/Istirahat", [student.student_name], ijin_msg)
			elif category == "Istirahat":
				activity_reason = " & Istirahat memulihkan tenaga"
			else:
				activity_reason = " & Belajar " + category

		# Log decay
		log_stat_change(day_name, student.student_name, "energy", -energy_loss, "decay")
		log_stat_change(day_name, student.student_name, "mood", -mood_loss, "decay")
		# Log activity stat gain
		if category != "Istirahat" and category != "Wirausaha" and category != "":
			var act_cat_key = category.to_lower().replace(" ", "_")
			var stat_key_map = {"akademis": "akademis", "senibudaya": "seni_budaya", "olahraga": "olahraga"}
			var stat_k = stat_key_map.get(act_cat_key, "")
			if stat_k != "" and act_res.get("stat_delta", 0.0) != 0.0:
				log_stat_change(day_name, student.student_name, stat_k, act_res.get("stat_delta", 0.0), "activity")
		elif category == "Istirahat":
			log_stat_change(day_name, student.student_name, "energy", act_res.get("energy_delta", 0.0), "activity")
			log_stat_change(day_name, student.student_name, "mood", act_res.get("mood_delta", 0.0), "activity")
				
		decay_results.append({
			"student_name": student.student_name,
			"personality": student.personality,
			"energy_loss": energy_loss,
			"mood_loss": mood_loss,
			"reason": reason + activity_reason,
			"current_energy": student.energy,
			"current_mood": student.mood
		})
	return decay_results

func record_event_result(day_name: String, event_name: String, affected_students: Array[String], details: String, stat_deltas: Dictionary = {}) -> void:
	minigame_history.append({
		"day": day_name,
		"category": "Event",
		"game_name": event_name,
		"won": true,
		"details": details,
		"affected_students": affected_students
	})

	# stat_deltas format: { student_name: {stat_key: delta, ...}, ... }
	for sn in stat_deltas.keys():
		var d = stat_deltas[sn]
		for sk in d.keys():
			log_stat_change(day_name, sn, sk, d[sk], "event")

func initialize_from_gamestate() -> void:
	students.clear()
	minigame_history.clear()
	daily_stat_log.clear()
	if GameState.approved_students.is_empty():
		initialize_students()
	else:
		students = GameState.convert_to_student_data_array()

func apply_jadwal_effects_all(day_name: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for student in students:
		var student_id = student.id
		if student_id != 0 and GameState.day_schedules.has(student_id):
			var day_sched = GameState.day_schedules[student_id].get(day_name, {})
			var category = day_sched.get("category", "")
			if category == "Akademik": category = "Akademis"
			elif category == "DayOff": category = "Istirahat"
			
			if category != "":
				var deltas = student.apply_jadwal_activity(category,
					Balance.BELAJAR_POIN_CADANGAN, Balance.BELAJAR_BONUS_FAVORIT_CADANGAN)
				results.append({
					"student_name": student.student_name,
					"category": category,
					"deltas": deltas
				})
	return results

func log_stat_change(day_name: String, student_name: String, stat_key: String, delta: float, source: String) -> void:
	if delta == 0.0:
		return
	if not daily_stat_log.has(day_name):
		daily_stat_log[day_name] = []
	daily_stat_log[day_name].append({
		"student_name": student_name,
		"stat_key": stat_key,
		"delta": delta,
		"source": source
	})

func get_day_summary(day_name: String) -> Array:
	# Returns all stat changes for a day, grouped by student.
	# Each entry: { student_name, changes: Array[{stat_key, delta, source}] }
	var raw: Array = daily_stat_log.get(day_name, [])
	var grouped: Dictionary = {}
	for entry in raw:
		var sn = entry["student_name"]
		if not grouped.has(sn):
			grouped[sn] = []
		grouped[sn].append({
			"stat_key": entry["stat_key"],
			"delta": entry["delta"],
			"source": entry["source"]
		})
	var result: Array = []
	for sn in grouped.keys():
		result.append({"student_name": sn, "changes": grouped[sn]})
	return result

func write_back_to_gamestate() -> void:
	for student in students:
		for i in range(GameState.approved_students.size()):
			var dict = GameState.approved_students[i]
			if dict.get("id", 0) == student.id or dict.get("name", "") == student.student_name:
				dict["akademis1"] = student.akademis
				dict["akademis2"] = student.seni_budaya
				dict["akademis3"] = student.olahraga
				dict["kepribadian1"] = student.mood
				dict["kepribadian2"] = student.energy
				break
