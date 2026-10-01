extends Node
class_name StudentManager

## Drives one school day's simulation for the `StudentData` roster.
##
## Not an autoload -- SchoolDay.gd instantiates one per day. Holds the
## `Array[StudentData]` being simulated (`initialize_from_gamestate()`
## builds it from `GameState.convert_to_student_data_array()`), logs
## every stat change to `daily_stat_log` for the end-of-day/end-of-week
## summaries, and at the end of the day `write_back_to_gamestate()`
## pushes the simulated stats back onto `GameState.approved_students`,
## whose stat keys are StudentData's own field names.
##
## Wirausaha balance numbers now live in Scripts/Balance.gd.

## The history category of a student's forced rest day (energy spent): logged
## for the report's rows, but neither a random event nor a minigame, so the
## week's EVENT TERJADI count leaves it out (bug sweep 2026-09-30).
const IZIN_CATEGORY := "Izin"
var students: Array[StudentData] = []
var minigame_history: Array[Dictionary] = [] # entries: {day, category, game_name, won, details}

## Set by initialize_from_gamestate() when GameState.approved_students was
## empty and it fell back to initialize_students()'s hardcoded demo roster
## (Budi/Ani/Cici/Doni) instead of the real approved cast. Lets a caller or
## test tell the two apart instead of the placeholder cast passing silently
## for a real one.
var used_fallback_roster: bool = false

# daily_stat_log[day_name] = Array of {student_name, stat_key, delta, source}
# stat_key: "akademis"|"seni_budaya"|"olahraga"|"energy"|"mood"
# source: "decay"|"activity"|"minigame_win"|"minigame_loss"|"event"|"holiday"
var daily_stat_log: Dictionary = {}

## This grade's per-student weekly minigame-win skill cap.
func _weekly_minigame_cap() -> float:
	match GameState.current_grade:
		8: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8
		9: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9
		_: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7

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
		
		var port_path = "res://Assets/Images/MuridPortrait/Murid%d.jpg" % (i + 1)
		if ResourceLoader.exists(port_path):
			student.avatar_texture = load(port_path)
			
		student.record_initial_stats()
		students.append(student)

func record_minigame_result(day_name: String, category: String, game_name: String, won: bool, score: int = -1, max_score: int = -1) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	# Roster-wide points for this one minigame. The run-result screen
	# reports the class total, not any single student's share.
	var roster_points := 0.0
	# Categories StudentData.apply_minigame_result() actually applies a skill
	# change for. An "Event" category (the skip path sent one until 2026-09-30)
	# still computes a positive stat_delta from the win-points formula though no skill category
	# match arm exists for it, so the weekly cap must only track real skill
	# categories -- otherwise "Event" burns budget out of
	# minigame_gain_this_week for a gain that never happened, potentially
	# zeroing out a genuine minigame win later in the same week.
	var mg_stat_key_map = {"Akademis": "akademis", "SeniBudaya": "seni_budaya", "Olahraga": "olahraga"}
	for student in students:
		# The skill before the result, so a capped win lands on before + allowed
		# rather than subtracting the overflow from an already-clamped 100.
		var skill_before: float = float(student.get(mg_stat_key_map[category])) if mg_stat_key_map.has(category) else 0.0
		var deltas = student.apply_minigame_result(category, won, score, max_score)

		# Apply weekly minigame cap: wins are capped per student, losses are untouched
		var raw_delta: float = float(deltas.get("stat_delta", 0.0))
		if won and raw_delta > 0.0 and mg_stat_key_map.has(category):
			var cap: float = _weekly_minigame_cap()
			var sid: int = student.id
			var already: float = float(GameState.minigame_gain_this_week.get(sid, 0.0))
			var allowed: float = maxf(0.0, cap - already)
			if raw_delta > allowed:
				var capped: float = clampf(skill_before + allowed, 0.0, 100.0)
				student.set(mg_stat_key_map[category], capped)
				deltas["stat_delta"] = capped - skill_before
			GameState.minigame_gain_this_week[sid] = already + minf(raw_delta, allowed)

		roster_points += float(deltas.get("stat_delta", 0.0))
		results.append({
			"student_name": student.student_name,
			"deltas": deltas
		})

		# Log minigame stat changes
		var mg_source = "minigame_win" if won else "minigame_loss"
		var mg_sk = mg_stat_key_map.get(category, "")
		if mg_sk != "":
			log_stat_change(day_name, student.student_name, mg_sk, deltas.get("stat_delta", 0.0), mg_source)
		log_stat_change(day_name, student.student_name, "energy", deltas.get("energy_delta", 0.0), mg_source)
		log_stat_change(day_name, student.student_name, "mood", deltas.get("mood_delta", 0.0), mg_source)

	GameState.run_stats.record_minigame(won, roster_points)

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
			# The cost rides the "decay" entries below (energy_loss/mood_loss),
			# so it is not logged a second time as "activity".
			activity_reason = " & Wirausaha (Rp%d)" % earned
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
				record_event_result(day_name, "Izin Sakit/Istirahat", [student.student_name], ijin_msg, {}, IZIN_CATEGORY)
			elif category == "Istirahat":
				activity_reason = " & Istirahat memulihkan tenaga"
			else:
				activity_reason = " & Belajar " + category

		# Log decay. These are the day's NET needs changes: energy_loss and
		# mood_loss already fold in Istirahat's recovery and Wirausaha's cost,
		# so neither is logged again below (the day summary sums every entry).
		log_stat_change(day_name, student.student_name, "energy", -energy_loss, "decay")
		log_stat_change(day_name, student.student_name, "mood", -mood_loss, "decay")
		# Log activity stat gain
		if category != "Istirahat" and category != "Wirausaha" and category != "":
			var act_cat_key = category.to_lower().replace(" ", "_")
			var stat_key_map = {"akademis": "akademis", "senibudaya": "seni_budaya", "olahraga": "olahraga"}
			var stat_k = stat_key_map.get(act_cat_key, "")
			if stat_k != "" and act_res.get("stat_delta", 0.0) != 0.0:
				log_stat_change(day_name, student.student_name, stat_k, act_res.get("stat_delta", 0.0), "activity")

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

func record_event_result(day_name: String, event_name: String, affected_students: Array[String], details: String, stat_deltas: Dictionary = {}, category: String = "Event") -> void:
	minigame_history.append({
		"day": day_name,
		"category": category,
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


## Applies one event to `affected` through StudentData.apply_event_effects()
## (so quirks like Penyendiri apply), then records it with what really changed,
## clamping included, so the day summary and the week's net skill change see
## the event, not only the history. `category` is "" for a class-wide event
## (Nasi Kotak, Hujan), which moves only energy and mood.
func apply_event(day_name: String, title: String, details: String, affected: Array[StudentData],
		category: String, stat_boost: float, energy_change: float, mood_change: float) -> void:
	var before: Dictionary = snapshot_stats()
	var names: Array[String] = []
	for student in affected:
		student.apply_event_effects(category, stat_boost, energy_change, mood_change)
		names.append(student.student_name)
	record_event_result(day_name, title, names, details, stat_deltas_since(before))


## Every student's name, in roster order: the affected list of an entry that
## concerns the whole class.
func student_names() -> Array[String]:
	var names: Array[String] = []
	for student in students:
		names.append(student.student_name)
	return names


## Every student's five stats, keyed by name, for stat_deltas_since().
func snapshot_stats() -> Dictionary:
	var snapshot: Dictionary = {}
	for student in students:
		snapshot[student.student_name] = student.stat_snapshot()
	return snapshot


## What each student's stats moved since `before` (a snapshot_stats()), in
## record_event_result()'s {student_name: {stat_key: delta}} shape. A student
## or stat that did not move is left out.
func stat_deltas_since(before: Dictionary) -> Dictionary:
	var deltas: Dictionary = {}
	for student in students:
		var was: Dictionary = before.get(student.student_name, {})
		var now: Dictionary = student.stat_snapshot()
		var moved: Dictionary = {}
		for key in now:
			var delta: float = float(now[key]) - float(was.get(key, now[key]))
			if delta != 0.0:
				moved[key] = delta
		if not moved.is_empty():
			deltas[student.student_name] = moved
	return deltas

func initialize_from_gamestate() -> void:
	students.clear()
	minigame_history.clear()
	daily_stat_log.clear()
	if GameState.approved_students.is_empty():
		used_fallback_roster = true
		push_warning("StudentManager: GameState.approved_students is empty -- " +
			"falling back to the placeholder demo roster (Budi/Ani/Cici/Doni). " +
			"This scene was reached without an approved roster.")
		initialize_students()
	else:
		used_fallback_roster = false
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
				dict["akademis"] = student.akademis
				dict["seni_budaya"] = student.seni_budaya
				dict["olahraga"] = student.olahraga
				dict["mood"] = student.mood
				dict["energy"] = student.energy
				break


## The StudentData fields SchoolDay's daily save carries, by student id:
## the live stats and the week-start ones the weekly report diffs against.
const SAVED_STAT_KEYS := [
	"akademis", "seni_budaya", "olahraga", "energy", "mood",
	"initial_akademis", "initial_seni_budaya", "initial_olahraga",
	"initial_energy", "initial_mood",
]


## The week so far, for SaveGame: each student's SAVED_STAT_KEYS by id, and
## the history and day log the weekly report reads. Plain data only.
func to_save_dict() -> Dictionary:
	var rows := []
	for s in students:
		var row := {"id": s.id}
		for k in SAVED_STAT_KEYS:
			row[k] = s.get(k)
		rows.append(row)
	return {
		"students": rows,
		"minigame_history": minigame_history.duplicate(true),
		"daily_stat_log": daily_stat_log.duplicate(true),
	}


## Inverse of to_save_dict(): rebuilds the roster from GameState (portraits,
## targets, quirks), then lays the saved stats over it by id, and restores
## the week's history. GameState itself is not written until the week ends.
func restore_from_save(d: Dictionary) -> void:
	initialize_from_gamestate()
	var by_id := {}
	for row in d.get("students", []):
		by_id[int(row.get("id", 0))] = row
	for s in students:
		var row: Dictionary = by_id.get(s.id, {})
		for k in SAVED_STAT_KEYS:
			if row.has(k):
				s.set(k, float(row[k]))
	minigame_history.assign(d.get("minigame_history", []))
	daily_stat_log = (d.get("daily_stat_log", {}) as Dictionary).duplicate(true)
