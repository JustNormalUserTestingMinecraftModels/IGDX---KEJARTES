extends Resource
class_name StudentData

@export var student_name: String = ""
@export var avatar_texture: Texture2D

# Stats (0 to 100)
@export var akademis: float = 50.0
@export var seni_budaya: float = 50.0
@export var olahraga: float = 50.0

# Needs (0 to 100)
@export var energy: float = 80.0
@export var mood: float = 80.0

# Personality & Specialty
@export var personality: String = "Santai"
@export var personality_desc: String = ""
@export var specialty_category: String = "Seimbang" # "Akademis", "Olahraga", "SeniBudaya", "Seimbang"

@export var id: int = 0
@export var splash_path: String = ""
@export var target_akademis1: float = 50.0
@export var target_akademis2: float = 50.0
@export var target_akademis3: float = 50.0
@export var target_kepribadian1: float = 50.0
@export var target_kepribadian2: float = 50.0
@export var quirk: String = ""
@export var persona: String = ""
@export var profil: String = ""

# Personality & Quirk Inspector-Editable Parameters
@export_group("Personality: Seni Dalam Kesunyian")
## Stat bonus multiplier when studying SeniBudaya ALONE (no other student in same subject)
@export var seni_kesunyian_solo_bonus: float = 0.10

@export_group("Quirk: Penyendiri")
## How many students in the same subject triggers crowd penalty
@export var penyendiri_crowd_threshold: int = 3
## Extra mood cost % when crowd threshold is met during study
@export var penyendiri_crowd_mood_penalty: float = 0.05
## Mood penalty % for event participation (positive gains reduced, negative losses increased)
@export var penyendiri_event_mood_penalty: float = 0.25

@export_group("Quirk: Kutu Buku")
## Bonus stat added when studying Akademis
@export var kutu_buku_akademis_stat_bonus: float = 1.0
## Mood cost reduction (%) when studying Akademis
@export var kutu_buku_akademis_mood_discount: float = 0.25
## Extra mood cost (%) when studying Olahraga
@export var kutu_buku_olahraga_mood_penalty: float = 0.20

@export_group("Quirk: Semangat Juang")
## Bonus stat added to minigame WIN result
@export var semangat_minigame_win_stat_bonus: float = 2.0
## Rest energy recovery reduction (%)
@export var semangat_rest_energy_penalty: float = 0.15
## Energy threshold below which mood cost for studying is halved
@export var semangat_low_energy_threshold: float = 30.0

@export_group("Quirk: Penasaran")
## Bonus stat for non-specialty study days
@export var penasaran_nonspec_stat_bonus: float = 1.0
## Extra energy cost (%) on all study days
@export var penasaran_energy_cost_penalty: float = 0.10

@export_group("Quirk: Biang Onar")
## Extra event weight added to daily roll (makes events more likely)
@export var biang_onar_event_weight_bonus: int = 10
## Positive event stat/mood bonus multiplier
@export var biang_onar_positive_event_scale: float = 0.20
## Negative event penalty multiplier
@export var biang_onar_negative_event_scale: float = 0.20

@export_group("Quirk: Pekerja Keras")
## Study energy cost reduction (%)
@export var pekerja_energy_discount: float = 0.10
## Extra study mood cost (%)
@export var pekerja_mood_penalty: float = 0.15
## Bonus mood added on minigame WIN
@export var pekerja_minigame_win_mood_bonus: float = 3.0

# Initial stats at week start for accurate end-of-week checkup deltas
var initial_akademis: float = 50.0
var initial_seni_budaya: float = 50.0
var initial_olahraga: float = 50.0
var initial_energy: float = 80.0
var initial_mood: float = 80.0

func record_initial_stats() -> void:
	initial_akademis = akademis
	initial_seni_budaya = seni_budaya
	initial_olahraga = olahraga
	initial_energy = energy
	initial_mood = mood

func get_akademis_delta() -> float: return akademis - initial_akademis
func get_seni_delta() -> float: return seni_budaya - initial_seni_budaya
func get_olahraga_delta() -> float: return olahraga - initial_olahraga
func get_energy_delta() -> float: return energy - initial_energy
func get_mood_delta() -> float: return mood - initial_mood


func get_category_efficiency_multiplier(category: String) -> float:
	if category == specialty_category:
		return Balance.BIAYA_KALAU_MAPEL_FAVORIT
	elif specialty_category == "Seimbang":
		return Balance.BIAYA_KALAU_MURID_SEIMBANG
	else:
		return Balance.BIAYA_KALAU_BUKAN_FAVORIT

func apply_minigame_result(category: String, won: bool, score: int = -1, max_score: int = -1) -> Dictionary:
	var stat_change: float = 0.0
	var energy_change: float = 0.0
	var mood_change: float = 0.0
	var grade_num = GameState.current_grade
	
	# Pick this grade's numbers once, then use them below.
	var win_base := Balance.MINIGAME_MENANG_POIN_DASAR_KELAS_7
	var win_scale := Balance.MINIGAME_MENANG_POIN_SKALA_KELAS_7
	var win_flat := Balance.MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_7
	var win_energy := Balance.MINIGAME_MENANG_ENERGI_KELAS_7
	var win_mood := Balance.MINIGAME_MENANG_MOOD_KELAS_7
	var lose_stat := Balance.MINIGAME_KALAH_POIN_KELAS_7
	var lose_energy := Balance.MINIGAME_KALAH_ENERGI_KELAS_7
	var lose_mood := Balance.MINIGAME_KALAH_MOOD_KELAS_7
	if grade_num == 8:
		win_base = Balance.MINIGAME_MENANG_POIN_DASAR_KELAS_8
		win_scale = Balance.MINIGAME_MENANG_POIN_SKALA_KELAS_8
		win_flat = Balance.MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_8
		win_energy = Balance.MINIGAME_MENANG_ENERGI_KELAS_8
		win_mood = Balance.MINIGAME_MENANG_MOOD_KELAS_8
		lose_stat = Balance.MINIGAME_KALAH_POIN_KELAS_8
		lose_energy = Balance.MINIGAME_KALAH_ENERGI_KELAS_8
		lose_mood = Balance.MINIGAME_KALAH_MOOD_KELAS_8
	elif grade_num == 9:
		win_base = Balance.MINIGAME_MENANG_POIN_DASAR_KELAS_9
		win_scale = Balance.MINIGAME_MENANG_POIN_SKALA_KELAS_9
		win_flat = Balance.MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_9
		win_energy = Balance.MINIGAME_MENANG_ENERGI_KELAS_9
		win_mood = Balance.MINIGAME_MENANG_MOOD_KELAS_9
		lose_stat = Balance.MINIGAME_KALAH_POIN_KELAS_9
		lose_energy = Balance.MINIGAME_KALAH_ENERGI_KELAS_9
		lose_mood = Balance.MINIGAME_KALAH_MOOD_KELAS_9

	if won:
		if score >= 0 and max_score > 0:
			var ratio = clampf(float(score) / float(max_score), 0.0, 1.0)
			stat_change = roundf(win_base + ratio * win_scale) if max_score > 1 else win_flat
		else:
			stat_change = win_flat
		energy_change = win_energy
		mood_change = win_mood
	else:
		stat_change = lose_stat
		energy_change = lose_energy
		mood_change = lose_mood
		
	# Apply specialty multiplier to costs
	var mult = get_category_efficiency_multiplier(category)
	if energy_change < 0:
		energy_change = roundf(energy_change * mult)
	if mood_change < 0:
		mood_change = roundf(mood_change * mult)
	
	# ── Quirk: Semangat Juang — minigame WIN gives +2 bonus stat (fired up!) ──
	if won and quirk == "Semangat Juang":
		stat_change += semangat_minigame_win_stat_bonus
	
	# ── Quirk: Pekerja Keras — minigame WIN gives +3 mood (satisfied from effort) ──
	if won and quirk == "Pekerja Keras":
		mood_change += pekerja_minigame_win_mood_bonus
		
	# Apply changes and clamp
	match category:
		"Akademis":
			akademis = clampf(akademis + stat_change, 0.0, 100.0)
		"SeniBudaya":
			seni_budaya = clampf(seni_budaya + stat_change, 0.0, 100.0)
		"Olahraga":
			olahraga = clampf(olahraga + stat_change, 0.0, 100.0)
			
	energy = clampf(energy + energy_change, 0.0, 100.0)
	mood = clampf(mood + mood_change, 0.0, 100.0)
	
	return {
		"stat_delta": stat_change,
		"energy_delta": energy_change,
		"mood_delta": mood_change,
		"is_specialty": (category == specialty_category)
	}

func is_tired() -> bool:
	return energy <= Balance.BATAS_KELELAHAN

func apply_daily_decay(_energy_loss: float = 5.0, _mood_loss: float = 5.0) -> Dictionary:
	return apply_personality_daily_decay()

func apply_personality_daily_decay() -> Dictionary:
	var energy_loss: float = 5.0
	var mood_loss: float = 5.0
	var reason: String = "Aktivitas biasa"
	
	match personality:
		"Aktif": # Doni
			energy_loss = roundf(randf_range(Balance.DECAY_AKTIF_ENERGI_MIN, Balance.DECAY_AKTIF_ENERGI_MAX))
			mood_loss = roundf(randf_range(Balance.DECAY_AKTIF_MOOD_MIN, Balance.DECAY_AKTIF_MOOD_MAX))
			reason = "Banyak aktivitas fisik & aktif bergerak"
		"Tekun": # Marcel
			energy_loss = roundf(randf_range(Balance.DECAY_TEKUN_ENERGI_MIN, Balance.DECAY_TEKUN_ENERGI_MAX))
			mood_loss = roundf(randf_range(Balance.DECAY_TEKUN_MOOD_MIN, Balance.DECAY_TEKUN_MOOD_MAX))
			reason = "Fokus berpikir & belajar padat"
		"Kreatif": # Andi and Thea
			energy_loss = roundf(randf_range(Balance.DECAY_KREATIF_ENERGI_MIN, Balance.DECAY_KREATIF_ENERGI_MAX))
			mood_loss = roundf(randf_range(Balance.DECAY_KREATIF_MOOD_MIN, Balance.DECAY_KREATIF_MOOD_MAX))
			reason = "Lelah berkreasi & mengeksplor ide"
		"Seni Dalam Kesunyian": # Citra
			energy_loss = roundf(randf_range(Balance.DECAY_KESUNYIAN_ENERGI_MIN, Balance.DECAY_KESUNYIAN_ENERGI_MAX))
			mood_loss = roundf(randf_range(Balance.DECAY_KESUNYIAN_MOOD_MIN, Balance.DECAY_KESUNYIAN_MOOD_MAX))
			reason = "Merenung dalam ketenangan & berkarya sendiri"
		_: # Shinta ("Santai"), and the fallback for any unrecognised personality
			energy_loss = roundf(randf_range(Balance.DECAY_SANTAI_ENERGI_MIN, Balance.DECAY_SANTAI_ENERGI_MAX))
			mood_loss = roundf(randf_range(Balance.DECAY_SANTAI_MOOD_MIN, Balance.DECAY_SANTAI_MOOD_MAX))
			reason = "Menjalani rutinitas harian dengan santai"
			
	energy = clampf(energy - energy_loss, 0.0, 100.0)
	mood = clampf(mood - mood_loss, 0.0, 100.0)
	
	return {
		"energy_loss": energy_loss,
		"mood_loss": mood_loss,
		"reason": reason,
		"current_energy": energy,
		"current_mood": mood
	}

func apply_event_effects(category: String, stat_boost: float, energy_cost: float, mood_boost: float) -> Dictionary:
	# Apply specialty multiplier to energy costs.
	# Empty category means a global event (e.g. Nasi Kotak, Hujan) — use 1.0x (no scaling).
	var mult = 1.0 if category == "" else get_category_efficiency_multiplier(category)
	var final_energy_cost = energy_cost
	if final_energy_cost < 0:
		final_energy_cost = roundf(final_energy_cost * mult)
	
	# ── Quirk: Penyendiri — events cost +25% more mood ──
	# Positive mood gains are reduced, negative mood losses are amplified
	var final_mood_boost = mood_boost
	if quirk == "Penyendiri":
		if final_mood_boost > 0:
			final_mood_boost = roundf(final_mood_boost * (1.0 - penyendiri_event_mood_penalty))
		elif final_mood_boost < 0:
			final_mood_boost = roundf(final_mood_boost * (1.0 + penyendiri_event_mood_penalty))
	
	match category:
		"Akademis":
			akademis = clampf(akademis + stat_boost, 0.0, 100.0)
		"SeniBudaya":
			seni_budaya = clampf(seni_budaya + stat_boost, 0.0, 100.0)
		"Olahraga":
			olahraga = clampf(olahraga + stat_boost, 0.0, 100.0)
			
	energy = clampf(energy + final_energy_cost, 0.0, 100.0)
	mood = clampf(mood + final_mood_boost, 0.0, 100.0)
	
	return {
		"stat_delta": stat_boost,
		"energy_delta": final_energy_cost,
		"mood_delta": final_mood_boost,
		"is_specialty": (category == specialty_category)
	}

func apply_jadwal_activity(category: String, base_gain: float = 5.0, specialty_bonus: float = 3.0, same_subject_count: int = 1) -> Dictionary:
	var stat_change: float = 0.0
	var energy_change: float = 0.0
	var mood_change: float = 0.0
	var took_ijin: bool = false
	var ijin_reason: String = ""
	
	# Automatic "Izin Sakit / Istirahat" check if student energy is depleted (see Balance.IZIN_OTOMATIS_BATAS_ENERGI)
	if category != "Istirahat" and energy <= Balance.IZIN_OTOMATIS_BATAS_ENERGI:
		took_ijin = true
		category = "Istirahat"
		ijin_reason = "Murid %s kehabisan energi dan mengambil Izin (Istirahat) untuk memulihkan tenaga!" % student_name
	
	var is_specialty = (category == specialty_category)
	var mult = get_category_efficiency_multiplier(category)
	
	if category == "Istirahat":
		# Recovery day: recovers energy and mood
		energy_change = roundf(randf_range(20.0, 30.0))
		mood_change = roundf(randf_range(15.0, 25.0))
		
		# ── Quirk: Semangat Juang — rest recovers less energy (too restless) ──
		if quirk == "Semangat Juang":
			energy_change = roundf(energy_change * (1.0 - semangat_rest_energy_penalty))
	else:
		# Activity day: increases main stat, costs energy and mood
		stat_change = base_gain
		if is_specialty:
			stat_change += specialty_bonus
		
		# ── Personality: Seni Dalam Kesunyian ──
		# When studying SeniBudaya ALONE, stat gain increases by 10%
		if personality == "Seni Dalam Kesunyian" and category == "SeniBudaya" and same_subject_count <= 1:
			stat_change = roundf(stat_change * (1.0 + seni_kesunyian_solo_bonus))
		
		# ── Quirk: Kutu Buku — Akademis specialist, hates Olahraga ──
		if quirk == "Kutu Buku" and category == "Akademis":
			stat_change += kutu_buku_akademis_stat_bonus
		
		# ── Quirk: Penasaran — non-specialty study gets +1 stat ──
		if quirk == "Penasaran" and not is_specialty:
			stat_change += penasaran_nonspec_stat_bonus
		
		energy_change = -roundf(randf_range(15.0, 20.0) * mult)
		mood_change = -roundf(randf_range(10.0, 15.0) * mult)
		
		# ── Quirk: Penasaran — all study costs +10% energy ──
		if quirk == "Penasaran":
			energy_change = roundf(energy_change * (1.0 + penasaran_energy_cost_penalty))
		
		# ── Quirk: Pekerja Keras — study costs -10% energy, +15% mood ──
		if quirk == "Pekerja Keras":
			energy_change = roundf(energy_change * (1.0 - pekerja_energy_discount))
			mood_change = roundf(mood_change * (1.0 + pekerja_mood_penalty))
		
		# ── Quirk: Kutu Buku — Akademis: -25% mood cost; Olahraga: +20% mood cost ──
		if quirk == "Kutu Buku":
			if category == "Akademis":
				mood_change = roundf(mood_change * (1.0 - kutu_buku_akademis_mood_discount))
			elif category == "Olahraga":
				mood_change = roundf(mood_change * (1.0 + kutu_buku_olahraga_mood_penalty))
		
		# ── Quirk: Penyendiri — 3+ students same subject: +5% mood cost ──
		if quirk == "Penyendiri" and same_subject_count >= penyendiri_crowd_threshold:
			mood_change = roundf(mood_change * (1.0 + penyendiri_crowd_mood_penalty))
		
		# ── Quirk: Semangat Juang — when energy is critically low, mood cost halved ──
		if quirk == "Semangat Juang" and energy <= semangat_low_energy_threshold:
			mood_change = roundf(mood_change * 0.5)
		
	# Apply changes and clamp
	match category:
		"Akademis":
			akademis = clampf(akademis + stat_change, 0.0, 100.0)
		"SeniBudaya":
			seni_budaya = clampf(seni_budaya + stat_change, 0.0, 100.0)
		"Olahraga":
			olahraga = clampf(olahraga + stat_change, 0.0, 100.0)
			
	energy = clampf(energy + energy_change, 0.0, 100.0)
	mood = clampf(mood + mood_change, 0.0, 100.0)
	
	return {
		"stat_delta": stat_change,
		"energy_delta": energy_change,
		"mood_delta": mood_change,
		"is_specialty": is_specialty,
		"took_ijin": took_ijin,
		"ijin_reason": ijin_reason,
		"final_category": category
	}

