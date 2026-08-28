@tool
extends McpTestSuite

## Balance.gd is the tester-facing file: every number that decides whether a
## student passes. These tests pin two things -- that each field exists under
## the exact name the game reads, and that it still holds the value the game
## shipped with. A renamed field breaks a call site; a drifted default is a
## silent balance change.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

## Every field, with the value it must hold. Grouped in the same order as
## Balance.gd so the two can be read side by side.
const _EXPECTED: Dictionary = {
	# Syarat lulus
	"TARGET_KENAIKAN_KELAS_7": 15.0,
	"TARGET_KENAIKAN_KELAS_8": 30.0,
	"TARGET_KENAIKAN_KELAS_9": 40.0,
	# Hari belajar
	"BELAJAR_POIN_KELAS_7": 3.0,
	"BELAJAR_POIN_KELAS_8": 2.5,
	"BELAJAR_POIN_KELAS_9": 2.0,
	"BELAJAR_BONUS_FAVORIT_KELAS_7": 3.0,
	"BELAJAR_BONUS_FAVORIT_KELAS_8": 2.5,
	"BELAJAR_BONUS_FAVORIT_KELAS_9": 2.0,
	"BELAJAR_POIN_CADANGAN": 5.0,
	"BELAJAR_BONUS_FAVORIT_CADANGAN": 3.0,
	"BELAJAR_BIAYA_ENERGI_MIN": 15.0,
	"BELAJAR_BIAYA_ENERGI_MAX": 20.0,
	"BELAJAR_BIAYA_MOOD_MIN": 10.0,
	"BELAJAR_BIAYA_MOOD_MAX": 15.0,
	"BIAYA_KALAU_MAPEL_FAVORIT": 0.6,
	"BIAYA_KALAU_MURID_SEIMBANG": 0.85,
	"BIAYA_KALAU_BUKAN_FAVORIT": 1.20,
	# Libur
	"LIBUR_ENERGI_PULIH_MIN": 20.0,
	"LIBUR_ENERGI_PULIH_MAX": 30.0,
	"LIBUR_MOOD_PULIH_MIN": 15.0,
	"LIBUR_MOOD_PULIH_MAX": 25.0,
	"IZIN_OTOMATIS_BATAS_ENERGI": 5.0,
	"BATAS_KELELAHAN": 20.0,
	# Minigame
	"MINIGAME_MENANG_POIN_DASAR_KELAS_7": 5.0,
	"MINIGAME_MENANG_POIN_DASAR_KELAS_8": 4.0,
	"MINIGAME_MENANG_POIN_DASAR_KELAS_9": 3.0,
	"MINIGAME_MENANG_POIN_SKALA_KELAS_7": 10.0,
	"MINIGAME_MENANG_POIN_SKALA_KELAS_8": 8.0,
	"MINIGAME_MENANG_POIN_SKALA_KELAS_9": 6.0,
	"MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_7": 10.0,
	"MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_8": 8.0,
	"MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_9": 6.0,
	"MINIGAME_MENANG_ENERGI_KELAS_7": -5.0,
	"MINIGAME_MENANG_ENERGI_KELAS_8": -7.0,
	"MINIGAME_MENANG_ENERGI_KELAS_9": -10.0,
	"MINIGAME_MENANG_MOOD_KELAS_7": -5.0,
	"MINIGAME_MENANG_MOOD_KELAS_8": -7.0,
	"MINIGAME_MENANG_MOOD_KELAS_9": -10.0,
	"MINIGAME_KALAH_POIN_KELAS_7": -3.0,
	"MINIGAME_KALAH_POIN_KELAS_8": -4.0,
	"MINIGAME_KALAH_POIN_KELAS_9": -5.0,
	"MINIGAME_KALAH_ENERGI_KELAS_7": -10.0,
	"MINIGAME_KALAH_ENERGI_KELAS_8": -12.0,
	"MINIGAME_KALAH_ENERGI_KELAS_9": -15.0,
	"MINIGAME_KALAH_MOOD_KELAS_7": -15.0,
	"MINIGAME_KALAH_MOOD_KELAS_8": -18.0,
	"MINIGAME_KALAH_MOOD_KELAS_9": -20.0,
	# Kepribadian
	"DECAY_AKTIF_ENERGI_MIN": 6.0,
	"DECAY_AKTIF_ENERGI_MAX": 8.0,
	"DECAY_AKTIF_MOOD_MIN": 2.0,
	"DECAY_AKTIF_MOOD_MAX": 4.0,
	"DECAY_TEKUN_ENERGI_MIN": 3.0,
	"DECAY_TEKUN_ENERGI_MAX": 5.0,
	"DECAY_TEKUN_MOOD_MIN": 6.0,
	"DECAY_TEKUN_MOOD_MAX": 8.0,
	"DECAY_KREATIF_ENERGI_MIN": 5.0,
	"DECAY_KREATIF_ENERGI_MAX": 7.0,
	"DECAY_KREATIF_MOOD_MIN": 3.0,
	"DECAY_KREATIF_MOOD_MAX": 5.0,
	"DECAY_KESUNYIAN_ENERGI_MIN": 4.0,
	"DECAY_KESUNYIAN_ENERGI_MAX": 6.0,
	"DECAY_KESUNYIAN_MOOD_MIN": 4.0,
	"DECAY_KESUNYIAN_MOOD_MAX": 6.0,
	"DECAY_SANTAI_ENERGI_MIN": 4.0,
	"DECAY_SANTAI_ENERGI_MAX": 6.0,
	"DECAY_SANTAI_MOOD_MIN": 4.0,
	"DECAY_SANTAI_MOOD_MAX": 6.0,
	# Sifat Pasif
	"SIFAT_KUTU_BUKU_BONUS_POIN": 1.0,
	"SIFAT_KUTU_BUKU_HEMAT_MOOD": 0.25,
	"SIFAT_KUTU_BUKU_BOROS_MOOD_OLAHRAGA": 0.20,
	"SIFAT_SEMANGAT_BONUS_MENANG": 2.0,
	"SIFAT_SEMANGAT_LIBUR_KURANG": 0.15,
	"SIFAT_SEMANGAT_BATAS_ENERGI_KRITIS": 30.0,
	"SIFAT_SEMANGAT_POTONGAN_MOOD_KRITIS": 0.5,
	"SIFAT_PENASARAN_BONUS_MAPEL_LAIN": 1.0,
	"SIFAT_PENASARAN_BOROS_ENERGI": 0.10,
	"SIFAT_PENYENDIRI_BATAS_KERAMAIAN": 3,
	"SIFAT_PENYENDIRI_BOROS_MOOD_RAMAI": 0.05,
	"SIFAT_PENYENDIRI_EVENT_MOOD": 0.25,
	"SIFAT_BIANG_ONAR_PELUANG_EVENT": 10,
	"SIFAT_BIANG_ONAR_EVENT_BAGUS": 0.20,
	"SIFAT_PEKERJA_HEMAT_ENERGI": 0.10,
	"SIFAT_PEKERJA_BOROS_MOOD": 0.15,
	"SIFAT_PEKERJA_BONUS_MOOD_MENANG": 3.0,
	"SIFAT_CITRA_SENI_SENDIRI_BONUS": 0.10,
	# Wirausaha
	"WIRAUSAHA_UANG_MIN": 120,
	"WIRAUSAHA_UANG_MAX": 320,
	"WIRAUSAHA_BATAS_BAWAH_ENERGI": 0.35,
	"WIRAUSAHA_BIAYA_MOOD": 6.0,
	"WIRAUSAHA_BIAYA_ENERGI": 10.0,
	# Event
	"EVENT_AKADEMIS_POIN": 15.0,
	"EVENT_AKADEMIS_ENERGI": -15.0,
	"EVENT_OLAHRAGA_POIN": 15.0,
	"EVENT_OLAHRAGA_MOOD": 10.0,
	"EVENT_OLAHRAGA_ENERGI": -20.0,
	"EVENT_SENI_POIN": 15.0,
	"EVENT_SENI_MOOD": 15.0,
	"EVENT_SENI_ENERGI": -10.0,
	"EVENT_NASI_KOTAK_ENERGI": 20.0,
	"EVENT_NASI_KOTAK_MOOD": 25.0,
	"EVENT_HUJAN_ENERGI": -15.0,
	"EVENT_HUJAN_MOOD": -15.0,
	# Skip
	"SKIP_PELUANG_KALAH": 0.4,
}


func suite_name() -> String:
	return "balance"


func test_every_field_exists_and_holds_its_shipped_value() -> void:
	# Balance.get(field_name) is a parse error -- get() is an instance
	# method, and GDScript refuses to call it through a class name
	# directly ("make an instance instead"). Static vars are still
	# visible through an instance's get(), so this works.
	var balance_probe := Balance.new()
	for field_name in _EXPECTED.keys():
		var expected = _EXPECTED[field_name]
		var actual = balance_probe.get(field_name)
		assert_true(actual != null,
			"Balance is missing the field: " + field_name)
		assert_true(is_equal_approx(float(actual), float(expected)),
			"Balance.%s must stay at its shipped value %s, got %s"
				% [field_name, str(expected), str(actual)])


## 104 numbers is the whole extraction surface. If the count drifts, either a
## field was added without a test entry or one was quietly dropped.
func test_the_expected_table_covers_every_number() -> void:
	assert_eq(_EXPECTED.size(), 104,
		"the extraction covers 104 numbers; update this test deliberately if that changes")


## The point of Balance.gd is that a tester can change a number and feel it.
## A literal left behind in a function body breaks that promise silently:
## the field still shows up in the file, but moving it does nothing. This
## scan is the guard against that.
const _EXTRACTED_FUNCTIONS := {
	"res://Scripts/SchoolSimulation/StudentData.gd": [
		"get_category_efficiency_multiplier",
		"is_tired",
		"apply_minigame_result",
		"apply_personality_daily_decay",
		"apply_jadwal_activity",
	],
}


## Pulls one top-level function's body: from its `func` line to the next
## line starting at column 0.
func _function_body(src: String, fname: String) -> String:
	var out := ""
	var inside := false
	for line in src.split("\n"):
		if line.begins_with("func " + fname + "("):
			inside = true
			continue
		if inside:
			if line.length() > 0 and not (line.begins_with("\t") or line.begins_with(" ")):
				break
			out += line + "\n"
	return out


func test_no_balance_literals_left_in_extracted_functions() -> void:
	# Numbers that are structure, not balance: array indices, clamp bounds,
	# the 0.0/1.0 identity values, and the grade numbers themselves.
	var allowed := ["0.0", "1.0", "100.0", "0", "1", "2", "3", "7", "8", "9"]
	for path in _EXTRACTED_FUNCTIONS.keys():
		var src := FileAccess.get_file_as_string(path)
		for fname in _EXTRACTED_FUNCTIONS[path]:
			var body := _function_body(src, fname)
			assert_true(body != "", "could not find function " + fname + " in " + path)
			var regex := RegEx.new()
			regex.compile("(?<![\\w.])\\d+\\.\\d+")
			for m in regex.search_all(body):
				assert_true(allowed.has(m.get_string()),
					"%s() still has the hardcoded number %s -- it belongs in Balance.gd"
						% [fname, m.get_string()])
