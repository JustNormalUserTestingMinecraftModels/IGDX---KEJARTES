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

# Personality and Sifat Pasif coefficients now live in Scripts/Balance.gd.

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
		stat_change += Balance.SIFAT_SEMANGAT_BONUS_MENANG
	
	# ── Quirk: Pekerja Keras — minigame WIN gives +3 mood (satisfied from effort) ──
	if won and quirk == "Pekerja Keras":
		mood_change += Balance.SIFAT_PEKERJA_BONUS_MOOD_MENANG
		
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
			final_mood_boost = roundf(final_mood_boost * (1.0 - Balance.SIFAT_PENYENDIRI_EVENT_MOOD))
		elif final_mood_boost < 0:
			final_mood_boost = roundf(final_mood_boost * (1.0 + Balance.SIFAT_PENYENDIRI_EVENT_MOOD))
	
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
		energy_change = roundf(randf_range(Balance.LIBUR_ENERGI_PULIH_MIN, Balance.LIBUR_ENERGI_PULIH_MAX))
		mood_change = roundf(randf_range(Balance.LIBUR_MOOD_PULIH_MIN, Balance.LIBUR_MOOD_PULIH_MAX))
		
		# ── Quirk: Semangat Juang — rest recovers less energy (too restless) ──
		if quirk == "Semangat Juang":
			energy_change = roundf(energy_change * (1.0 - Balance.SIFAT_SEMANGAT_LIBUR_KURANG))
	else:
		# Activity day: increases main stat, costs energy and mood
		stat_change = base_gain
		if is_specialty:
			stat_change += specialty_bonus
		
		# ── Personality: Seni Dalam Kesunyian ──
		# When studying SeniBudaya ALONE, stat gain increases by 10%
		if personality == "Seni Dalam Kesunyian" and category == "SeniBudaya" and same_subject_count <= 1:
			stat_change = roundf(stat_change * (1.0 + Balance.SIFAT_CITRA_SENI_SENDIRI_BONUS))
		
		# ── Quirk: Kutu Buku — Akademis specialist, hates Olahraga ──
		if quirk == "Kutu Buku" and category == "Akademis":
			stat_change += Balance.SIFAT_KUTU_BUKU_BONUS_POIN
		
		# ── Quirk: Penasaran — non-specialty study gets +1 stat ──
		if quirk == "Penasaran" and not is_specialty:
			stat_change += Balance.SIFAT_PENASARAN_BONUS_MAPEL_LAIN
		
		energy_change = -roundf(randf_range(Balance.BELAJAR_BIAYA_ENERGI_MIN, Balance.BELAJAR_BIAYA_ENERGI_MAX) * mult)
		mood_change = -roundf(randf_range(Balance.BELAJAR_BIAYA_MOOD_MIN, Balance.BELAJAR_BIAYA_MOOD_MAX) * mult)
		
		# ── Quirk: Penasaran — all study costs +10% energy ──
		if quirk == "Penasaran":
			energy_change = roundf(energy_change * (1.0 + Balance.SIFAT_PENASARAN_BOROS_ENERGI))
		
		# ── Quirk: Pekerja Keras — study costs -10% energy, +15% mood ──
		if quirk == "Pekerja Keras":
			energy_change = roundf(energy_change * (1.0 - Balance.SIFAT_PEKERJA_HEMAT_ENERGI))
			mood_change = roundf(mood_change * (1.0 + Balance.SIFAT_PEKERJA_BOROS_MOOD))
		
		# ── Quirk: Kutu Buku — Akademis: -25% mood cost; Olahraga: +20% mood cost ──
		if quirk == "Kutu Buku":
			if category == "Akademis":
				mood_change = roundf(mood_change * (1.0 - Balance.SIFAT_KUTU_BUKU_HEMAT_MOOD))
			elif category == "Olahraga":
				mood_change = roundf(mood_change * (1.0 + Balance.SIFAT_KUTU_BUKU_BOROS_MOOD_OLAHRAGA))
		
		# ── Quirk: Penyendiri — 3+ students same subject: +5% mood cost ──
		if quirk == "Penyendiri" and same_subject_count >= Balance.SIFAT_PENYENDIRI_BATAS_KERAMAIAN:
			mood_change = roundf(mood_change * (1.0 + Balance.SIFAT_PENYENDIRI_BOROS_MOOD_RAMAI))
		
		# ── Quirk: Semangat Juang — when energy is critically low, mood cost halved ──
		if quirk == "Semangat Juang" and energy <= Balance.SIFAT_SEMANGAT_BATAS_ENERGI_KRITIS:
			mood_change = roundf(mood_change * Balance.SIFAT_SEMANGAT_POTONGAN_MOOD_KRITIS)
		
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

