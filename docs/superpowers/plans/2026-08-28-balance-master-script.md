# Balance Master Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all 105 balance numbers out of function bodies into one readable file, `Scripts/Balance.gd`, so a non-programmer tester can change any of them and re-run the game.

**Architecture:** A single `class_name Balance` holding 105 `static var` fields, grouped and commented in Indonesian, ordered by how likely a tester is to reach for them. Every call site that used a literal reads `Balance.FIELD` instead. Randomness is untouched — where the game rolls a random amount, the *range* becomes tunable, the roll does not change.

> **Note on the count.** The spec states ~93. Writing this plan turned up 12 further hardcoded numbers in `SchoolDay.gd`'s random events (the Akademis/Olahraga/Seni events, plus Nasi Kotak and Hujan), which are balance numbers by any reasonable reading — "Hujan drains 15 mood and that feels brutal" is exactly the complaint this tool exists to answer. They are included here as Task 9, bringing the total to 105.

**Tech Stack:** Godot 4.6, GDScript, the in-editor `McpTestSuite` runner.

**Spec:** `docs/superpowers/specs/2026-08-28-balance-tuning-tools-design.md`

## Global Constraints

- Godot **4.6**, GDScript.
- **`static var`, never `const`.** A `const` is compile-time and could never be changed by a future editing panel. `static var` is already used in this codebase (`AnimUtils.gd:8`, `Juice.gd:14`, `atur_jadwal.gd:77`, `student_list.gd:20`).
- **Behaviour must not change.** `Balance.gd` ships seeded with today's exact values. A correct extraction alters nothing observable.
- **Field names and comments are Indonesian**; the surrounding code stays English. This extends the codebase's existing habit (`WIRAUSAHA_EARN_MIN`).
- Use the vocabulary the tester sees on screen: **Libur** (not the internal `"Istirahat"`), **Sifat Pasif** (not "quirk"), **Kelas 7/8/9**.
- Test suites live in `tests/test_*.gd`, extend `McpTestSuite`, must be `@tool`, and **no test may be a coroutine** — the runner calls `suite.call(name)` without awaiting, so an `await` silently aborts the test.
- **The Godot MCP bridge is single-client.** Subagents must never call `mcp__godot-ai__*`; the controller runs every scan and test run and supplies results.
- After editing any `.gd`, run `filesystem_manage(op="scan")` before `test_run`, or the editor serves a stale script.
- Conventional Commits with a scope.

## The safety property

The existing 303-test suite is this plan's real guard. `test_wirausaha`, `test_school_day` and `test_economy_state` assert outcomes that depend on these exact numbers, so a value that shifts during extraction fails a test rather than silently altering difficulty. **The full suite must be green after every task.**

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scripts/Balance.gd` | Every tunable number, grouped and documented in Indonesian. The tester's only file. | Create |
| `Scripts/GameState.gd` | Grade target uplift reads from `Balance`. | Modify |
| `Scripts/SchoolSimulation/StudentManager.gd` | Study gains + Wirausaha read from `Balance`. | Modify |
| `Scripts/SchoolSimulation/StudentData.gd` | The bulk — efficiency, thresholds, minigame, decay, costs, traits. | Modify |
| `Scripts/SchoolSimulation/SchoolDay.gd` | Random events (in both copies), skip-mode odds, and the day-preview badges read from `Balance`. | Modify |
| `tests/test_balance.gd` | Field existence, default values, and the no-leftover-literals scan. | Create |

**Task order matters.** Task 1 creates the file with nothing reading it — safe by construction. Tasks 2–9 each wire one region and are independently reviewable. Task 10 adds the scan that proves nothing was missed. Task 11 fixes the day-screen preview badges, which quote the study numbers from a private copy — the one place where the tester's first edit would otherwise appear to do nothing.

---

# Task 1: Create `Scripts/Balance.gd`

**Files:**
- Create: `Scripts/Balance.gd`
- Test: `tests/test_balance.gd`

**Interfaces:**
- Produces: `class_name Balance` with 105 `static var` fields. Every later task reads from it. Exact field names are fixed here and must not be renamed later.

Nothing reads this file yet, so it cannot break anything. Values are copied from the current source — do not round, adjust, or "tidy" any number.

- [ ] **Step 1: Write the failing test**

Create `tests/test_balance.gd`:

```gdscript
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
	"SIFAT_BIANG_ONAR_EVENT_BURUK": 0.20,
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


## 105 numbers is the whole extraction surface. If the count drifts, either a
## field was added without a test entry or one was quietly dropped.
func test_the_expected_table_covers_every_number() -> void:
	assert_eq(_EXPECTED.size(), 105,
		"the extraction covers 105 numbers; update this test deliberately if that changes")
```

- [ ] **Step 2: Run and confirm failure**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="balance")`.
Expected: FAIL — `Balance` does not exist yet.

- [ ] **Step 3: Create `Scripts/Balance.gd`**

Create the file with exactly this content:

```gdscript
## Balance.gd — semua angka yang menentukan murid lulus atau tidak.
##
## Cara pakai: ubah angkanya, simpan (Ctrl+S), lalu jalankan ulang game.
## Angka-angka ini tidak ada di tempat lain — semuanya dibaca dari sini.
##
## Biar cepat balik ke situasi yang mau diuji setelah restart:
## tekan F1 > "Seed Playtest State", lalu buka tab "Scenes" untuk
## langsung lompat ke layar yang kamu mau.
##
## Hati-hati: kalau salah ketik (misal "6.o" bukan "6.0") game tidak mau
## jalan. Errornya langsung kelihatan, tinggal perbaiki angkanya.
##
## Catatan buat programmer: di dalam kode, kategori "Libur" tersimpan
## dengan nama "Istirahat". Nama di file ini mengikuti tombol yang
## dilihat tester, bukan nama internalnya.
class_name Balance


## ═══════════════════════════════════════════════════════════
## SYARAT LULUS
## ═══════════════════════════════════════════════════════════

## Berapa poin yang harus dinaikkan murid di SEMUA mata pelajaran
## supaya lulus. Ditambahkan di atas nilai awal mereka — jadi makin
## besar angkanya, makin sulit kelasnya. Ini pengatur kesulitan
## paling berpengaruh di seluruh game.
static var TARGET_KENAIKAN_KELAS_7 := 15.0
static var TARGET_KENAIKAN_KELAS_8 := 30.0
static var TARGET_KENAIKAN_KELAS_9 := 40.0


## ═══════════════════════════════════════════════════════════
## HARI BELAJAR BIASA
## (saat kamu menjadwalkan Akademis, Seni Budaya, atau Olahraga)
## ═══════════════════════════════════════════════════════════

## Poin mata pelajaran yang didapat dari satu hari belajar.
static var BELAJAR_POIN_KELAS_7 := 3.0
static var BELAJAR_POIN_KELAS_8 := 2.5
static var BELAJAR_POIN_KELAS_9 := 2.0

## Poin tambahan kalau itu mata pelajaran favoritnya (sesuai hobi).
static var BELAJAR_BONUS_FAVORIT_KELAS_7 := 3.0
static var BELAJAR_BONUS_FAVORIT_KELAS_8 := 2.5
static var BELAJAR_BONUS_FAVORIT_KELAS_9 := 2.0

## Nilai cadangan, dipakai di satu jalur kode lama yang tidak
## membedakan kelas. Jarang terpakai — ubah yang di atas dulu.
static var BELAJAR_POIN_CADANGAN := 5.0
static var BELAJAR_BONUS_FAVORIT_CADANGAN := 3.0

## Energi yang terpakai untuk satu hari belajar. Game mengacak
## angka di antara kedua nilai ini, jadi tiap hari tidak persis sama.
static var BELAJAR_BIAYA_ENERGI_MIN := 15.0
static var BELAJAR_BIAYA_ENERGI_MAX := 20.0

## Mood yang terpakai untuk satu hari belajar, juga diacak.
static var BELAJAR_BIAYA_MOOD_MIN := 10.0
static var BELAJAR_BIAYA_MOOD_MAX := 15.0

## Pengali biaya di atas, tergantung mata pelajarannya.
## Di bawah 1.0 = lebih hemat. Di atas 1.0 = lebih melelahkan.
## 0.6 artinya mapel favorit cuma memakan 60% biaya.
static var BIAYA_KALAU_MAPEL_FAVORIT := 0.6
## Untuk murid "Seimbang", yang tidak punya mapel favorit.
static var BIAYA_KALAU_MURID_SEIMBANG := 0.85
## Mapel yang bukan favoritnya — 20% lebih melelahkan.
static var BIAYA_KALAU_BUKAN_FAVORIT := 1.20


## ═══════════════════════════════════════════════════════════
## HARI LIBUR
## ═══════════════════════════════════════════════════════════

## Energi yang pulih saat Libur, diacak di antara dua nilai ini.
static var LIBUR_ENERGI_PULIH_MIN := 20.0
static var LIBUR_ENERGI_PULIH_MAX := 30.0

## Mood yang pulih saat Libur.
static var LIBUR_MOOD_PULIH_MIN := 15.0
static var LIBUR_MOOD_PULIH_MAX := 25.0

## Kalau energi turun sampai angka ini atau lebih rendah, murid
## otomatis mengambil Izin — mengabaikan jadwal yang sudah kamu atur.
static var IZIN_OTOMATIS_BATAS_ENERGI := 5.0

## Di bawah angka ini, murid ditandai "lelah" di layar.
static var BATAS_KELELAHAN := 20.0


## ═══════════════════════════════════════════════════════════
## MINIGAME — menang dan kalah
## ═══════════════════════════════════════════════════════════

## Kalau minigame punya skor, poin dihitung: DASAR + (skor × SKALA).
## Jadi menang tipis dapat poin mendekati DASAR, menang telak
## mendekati DASAR + SKALA.
static var MINIGAME_MENANG_POIN_DASAR_KELAS_7 := 5.0
static var MINIGAME_MENANG_POIN_DASAR_KELAS_8 := 4.0
static var MINIGAME_MENANG_POIN_DASAR_KELAS_9 := 3.0
static var MINIGAME_MENANG_POIN_SKALA_KELAS_7 := 10.0
static var MINIGAME_MENANG_POIN_SKALA_KELAS_8 := 8.0
static var MINIGAME_MENANG_POIN_SKALA_KELAS_9 := 6.0

## Kalau minigame tidak punya skor (cuma menang/kalah), pakai ini.
static var MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_7 := 10.0
static var MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_8 := 8.0
static var MINIGAME_MENANG_POIN_TANPA_SKOR_KELAS_9 := 6.0

## Energi dan mood yang terpakai walaupun MENANG — main tetap capek.
static var MINIGAME_MENANG_ENERGI_KELAS_7 := -5.0
static var MINIGAME_MENANG_ENERGI_KELAS_8 := -7.0
static var MINIGAME_MENANG_ENERGI_KELAS_9 := -10.0
static var MINIGAME_MENANG_MOOD_KELAS_7 := -5.0
static var MINIGAME_MENANG_MOOD_KELAS_8 := -7.0
static var MINIGAME_MENANG_MOOD_KELAS_9 := -10.0

## Poin yang HILANG kalau kalah. Angka minus artinya nilainya turun.
static var MINIGAME_KALAH_POIN_KELAS_7 := -3.0
static var MINIGAME_KALAH_POIN_KELAS_8 := -4.0
static var MINIGAME_KALAH_POIN_KELAS_9 := -5.0

## Energi yang hilang saat kalah.
static var MINIGAME_KALAH_ENERGI_KELAS_7 := -10.0
static var MINIGAME_KALAH_ENERGI_KELAS_8 := -12.0
static var MINIGAME_KALAH_ENERGI_KELAS_9 := -15.0

## Mood yang hilang saat kelas kalah. Kalah terasa jauh lebih berat
## daripada lelah karena menang — angka ini sering jadi penyebab
## satu kelas terasa tidak adil.
static var MINIGAME_KALAH_MOOD_KELAS_7 := -15.0
static var MINIGAME_KALAH_MOOD_KELAS_8 := -18.0
static var MINIGAME_KALAH_MOOD_KELAS_9 := -20.0


## ═══════════════════════════════════════════════════════════
## KEPRIBADIAN — energi & mood yang habis dengan sendirinya
## ═══════════════════════════════════════════════════════════

## Tiap murid kehilangan sedikit energi dan mood setiap hari, sebelum
## kegiatan apa pun dihitung. Tiap kepribadian punya pola sendiri.
## Semua angka di bagian ini diacak antara MIN dan MAX.

## Aktif — Doni. Boros energi karena banyak bergerak.
static var DECAY_AKTIF_ENERGI_MIN := 6.0
static var DECAY_AKTIF_ENERGI_MAX := 8.0
static var DECAY_AKTIF_MOOD_MIN := 2.0
static var DECAY_AKTIF_MOOD_MAX := 4.0

## Tekun — Marcel. Boros mood karena fokus berpikir terus.
static var DECAY_TEKUN_ENERGI_MIN := 3.0
static var DECAY_TEKUN_ENERGI_MAX := 5.0
static var DECAY_TEKUN_MOOD_MIN := 6.0
static var DECAY_TEKUN_MOOD_MAX := 8.0

## Kreatif — Andi DAN Thea. Mengubah angka ini kena dua murid sekaligus.
static var DECAY_KREATIF_ENERGI_MIN := 5.0
static var DECAY_KREATIF_ENERGI_MAX := 7.0
static var DECAY_KREATIF_MOOD_MIN := 3.0
static var DECAY_KREATIF_MOOD_MAX := 5.0

## Seni Dalam Kesunyian — Citra.
static var DECAY_KESUNYIAN_ENERGI_MIN := 4.0
static var DECAY_KESUNYIAN_ENERGI_MAX := 6.0
static var DECAY_KESUNYIAN_MOOD_MIN := 4.0
static var DECAY_KESUNYIAN_MOOD_MAX := 6.0

## Santai — Shinta. Ini juga jadi nilai cadangan: dipakai kalau
## kepribadian murid tidak cocok dengan pilihan mana pun di atas.
static var DECAY_SANTAI_ENERGI_MIN := 4.0
static var DECAY_SANTAI_ENERGI_MAX := 6.0
static var DECAY_SANTAI_MOOD_MIN := 4.0
static var DECAY_SANTAI_MOOD_MAX := 6.0


## ═══════════════════════════════════════════════════════════
## SIFAT PASIF — keistimewaan tiap murid
## ═══════════════════════════════════════════════════════════

## ── Kutu Buku (Marcel) ──
## Poin Akademis tambahan di hari belajar.
static var SIFAT_KUTU_BUKU_BONUS_POIN := 1.0
## Akademis lebih hemat mood karena dia menikmatinya.
## 0.25 artinya 25% lebih hemat.
static var SIFAT_KUTU_BUKU_HEMAT_MOOD := 0.25
## Sebaliknya, Olahraga lebih boros mood. 0.20 artinya 20% lebih boros.
static var SIFAT_KUTU_BUKU_BOROS_MOOD_OLAHRAGA := 0.20

## ── Semangat Juang (Doni) ──
## Poin tambahan setiap kali kelas MENANG minigame.
static var SIFAT_SEMANGAT_BONUS_MENANG := 2.0
## Energi yang pulih saat Libur berkurang — terlalu gelisah untuk santai.
## 0.15 artinya 15% lebih sedikit.
static var SIFAT_SEMANGAT_LIBUR_KURANG := 0.15
## Kalau energinya di bawah angka ini, dia justru makin bersemangat.
static var SIFAT_SEMANGAT_BATAS_ENERGI_KRITIS := 30.0
## Seberapa besar biaya mood dipotong saat energinya kritis.
## 0.5 artinya jadi setengahnya.
static var SIFAT_SEMANGAT_POTONGAN_MOOD_KRITIS := 0.5

## ── Penasaran (Andi) ──
## Poin tambahan saat belajar mapel yang BUKAN favoritnya.
static var SIFAT_PENASARAN_BONUS_MAPEL_LAIN := 1.0
## Tapi semua hari belajar jadi lebih boros energi. 0.10 artinya 10%.
static var SIFAT_PENASARAN_BOROS_ENERGI := 0.10

## ── Penyendiri (Citra) ──
## Kalau ada sebanyak ini murid (atau lebih) belajar mapel yang sama
## di hari yang sama, Citra jadi terganggu.
static var SIFAT_PENYENDIRI_BATAS_KERAMAIAN := 3
## Tambahan biaya mood saat ramai. 0.05 artinya 5% lebih boros.
static var SIFAT_PENYENDIRI_BOROS_MOOD_RAMAI := 0.05
## Efek event ke mood-nya dikurangi 25% — senangnya kurang terasa,
## sedihnya lebih terasa.
static var SIFAT_PENYENDIRI_EVENT_MOOD := 0.25

## ── Biang Onar (Shinta) ──
## Menambah peluang event muncul tiap hari.
static var SIFAT_BIANG_ONAR_PELUANG_EVENT := 10
## Event yang bagus jadi 20% lebih bagus untuknya.
static var SIFAT_BIANG_ONAR_EVENT_BAGUS := 0.20
## Event yang buruk jadi 20% lebih buruk.
static var SIFAT_BIANG_ONAR_EVENT_BURUK := 0.20

## ── Pekerja Keras (Thea) ──
## Hari belajar lebih hemat energi. 0.10 artinya 10% lebih hemat.
static var SIFAT_PEKERJA_HEMAT_ENERGI := 0.10
## Tapi lebih boros mood. 0.15 artinya 15% lebih boros.
static var SIFAT_PEKERJA_BOROS_MOOD := 0.15
## Bonus mood setiap kali kelas MENANG minigame.
static var SIFAT_PEKERJA_BONUS_MOOD_MENANG := 3.0

## ── Seni Dalam Kesunyian (Citra) ──
## Ini efek KEPRIBADIAN, bukan Sifat Pasif — tapi ditaruh di sini
## biar gampang dicari. Bonus poin kalau Citra belajar Seni Budaya
## SENDIRIAN (tidak ada murid lain di mapel itu hari yang sama).
## 0.10 artinya +10%.
##
## Perlu diperhatikan: mapel favorit Citra sebenarnya Olahraga, bukan
## Seni Budaya — jadi bonus ini jarang kepakai. Kalau terasa mubazir,
## ini penyebabnya.
static var SIFAT_CITRA_SENI_SENDIRI_BONUS := 0.10


## ═══════════════════════════════════════════════════════════
## WIRAUSAHA — hari cari uang
## ═══════════════════════════════════════════════════════════

## Uang yang didapat per hari Wirausaha, diacak antara dua nilai ini.
static var WIRAUSAHA_UANG_MIN := 120
static var WIRAUSAHA_UANG_MAX := 320

## Hasilnya dikali sesuai sisa energi murid. Angka ini batas bawahnya:
## 0.35 artinya murid yang sudah kehabisan energi tetap dapat 35%.
static var WIRAUSAHA_BATAS_BAWAH_ENERGI := 0.35

## Mood dan energi ekstra yang terpakai di hari Wirausaha,
## di luar penurunan harian biasa.
static var WIRAUSAHA_BIAYA_MOOD := 6.0
static var WIRAUSAHA_BIAYA_ENERGI := 10.0


## ═══════════════════════════════════════════════════════════
## EVENT — kejadian acak saat simulasi hari
## ═══════════════════════════════════════════════════════════

## Event kegiatan Akademis: poin Akademis naik, energi terpakai.
static var EVENT_AKADEMIS_POIN := 15.0
static var EVENT_AKADEMIS_ENERGI := -15.0

## Event kegiatan Olahraga.
static var EVENT_OLAHRAGA_POIN := 15.0
static var EVENT_OLAHRAGA_MOOD := 10.0
static var EVENT_OLAHRAGA_ENERGI := -20.0

## Event kegiatan Seni Budaya.
static var EVENT_SENI_POIN := 15.0
static var EVENT_SENI_MOOD := 15.0
static var EVENT_SENI_ENERGI := -10.0

## "Kejutan Nasi Kotak Orang Tua" — event baik, semua murid kebagian.
static var EVENT_NASI_KOTAK_ENERGI := 20.0
static var EVENT_NASI_KOTAK_MOOD := 25.0

## "Hujan Deras & Jalanan Licin" — event buruk, semua murid kena.
static var EVENT_HUJAN_ENERGI := -15.0
static var EVENT_HUJAN_MOOD := -15.0


## ═══════════════════════════════════════════════════════════
## MODE SKIP
## ═══════════════════════════════════════════════════════════

## Saat pemain menekan Skip, minigame tidak dimainkan — hasilnya diundi.
## Angka ini peluang KALAH: 0.4 artinya kelas menang 60% dari waktu.
static var SKIP_PELUANG_KALAH := 0.4
```

- [ ] **Step 4: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="balance")`.
Expected: PASS, 2 tests.

If the suite reports "cannot instantiate — abstract or broken", that is a GDScript parse error, not a runner bug. Read `logs_read(source="editor", include_details=true)` for the real message.

- [ ] **Step 5: Run the full suite**

**Controller action:** `test_run()`.
Expected: **303 passed, 1 failed** — the single failure is the pre-existing `audio_director / test_volumes_persist_across_a_fresh_director` coroutine bug documented in CLAUDE.md. Nothing else may fail; no call site has changed yet.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Balance.gd tests/test_balance.gd
git commit -m "feat(balance): add the master tuning script"
```

---

# Task 2: Grade targets read from `Balance`

**Files:**
- Modify: `Scripts/GameState.gd:60-72`

**Interfaces:**
- Consumes: `Balance.TARGET_KENAIKAN_KELAS_7/8/9`.

- [ ] **Step 1: Replace the match block**

In `GameState.initialize_grade_targets()`, replace:

```gdscript
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
```

with:

```gdscript
			var uplift := Balance.TARGET_KENAIKAN_KELAS_7
			match current_grade:
				8: uplift = Balance.TARGET_KENAIKAN_KELAS_8
				9: uplift = Balance.TARGET_KENAIKAN_KELAS_9
			student["target_akademis1"] = clampf(b1 + uplift, 0.0, 100.0)
			student["target_akademis2"] = clampf(b2 + uplift, 0.0, 100.0)
			student["target_akademis3"] = clampf(b3 + uplift, 0.0, 100.0)
```

Note the indentation: these lines sit inside the existing `for student in approved_students:` loop, at the same level as the `match` they replace.

- [ ] **Step 2: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed** (the known `audio_director` bug only). `test_semester_end` and `test_school_day` exercise targets — any new failure means the uplift changed.

- [ ] **Step 3: Commit**

```bash
git add Scripts/GameState.gd
git commit -m "feat(balance): read grade targets from Balance"
```

---

# Task 3: Study gains and Wirausaha read from `Balance`

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd:9-17` (the const block), `:143-166`, `:243`

**Interfaces:**
- Consumes: `Balance.WIRAUSAHA_*`, `Balance.BELAJAR_POIN_KELAS_*`, `Balance.BELAJAR_BONUS_FAVORIT_KELAS_*`, `Balance.BELAJAR_POIN_CADANGAN`, `Balance.BELAJAR_BONUS_FAVORIT_CADANGAN`.

- [ ] **Step 1: Delete the Wirausaha const block**

Remove these lines near the top of `StudentManager.gd` (the whole commented block from `# ================= WIRAUSAHA BALANCE =================` through `const WIRAUSAHA_ENERGY_COST := 10.0`):

```gdscript
## Roll range for a single Wirausaha day at full energy.
const WIRAUSAHA_EARN_MIN := 120
const WIRAUSAHA_EARN_MAX := 320
## Earnings are multiplied by this floor plus the student's energy
## fraction, so an exhausted student still earns something.
const WIRAUSAHA_ENERGY_FLOOR := 0.35
## Stat cost on top of the normal personality decay.
const WIRAUSAHA_MOOD_COST := 6.0
const WIRAUSAHA_ENERGY_COST := 10.0
```

Leave a one-line pointer in their place so a reader is not left wondering:

```gdscript
# Wirausaha balance numbers now live in Scripts/Balance.gd.
```

- [ ] **Step 2: Update the Wirausaha branch**

In `apply_daily_decay_all`, replace:

```gdscript
				var multiplier: float = WIRAUSAHA_ENERGY_FLOOR + (1.0 - WIRAUSAHA_ENERGY_FLOOR) * energy_fraction
				var earned: int = int(round(randi_range(WIRAUSAHA_EARN_MIN, WIRAUSAHA_EARN_MAX) * multiplier))

				student.mood = clampf(student.mood - WIRAUSAHA_MOOD_COST, 0.0, 100.0)
				student.energy = clampf(student.energy - WIRAUSAHA_ENERGY_COST, 0.0, 100.0)
				mood_loss += WIRAUSAHA_MOOD_COST
				energy_loss += WIRAUSAHA_ENERGY_COST
```

with:

```gdscript
				var floor_frac: float = Balance.WIRAUSAHA_BATAS_BAWAH_ENERGI
				var multiplier: float = floor_frac + (1.0 - floor_frac) * energy_fraction
				var earned: int = int(round(randi_range(Balance.WIRAUSAHA_UANG_MIN,
					Balance.WIRAUSAHA_UANG_MAX) * multiplier))

				student.mood = clampf(student.mood - Balance.WIRAUSAHA_BIAYA_MOOD, 0.0, 100.0)
				student.energy = clampf(student.energy - Balance.WIRAUSAHA_BIAYA_ENERGI, 0.0, 100.0)
				mood_loss += Balance.WIRAUSAHA_BIAYA_MOOD
				energy_loss += Balance.WIRAUSAHA_BIAYA_ENERGI
```

Two lines further down, the same function logs those costs — update them too:

```gdscript
				log_stat_change(day_name, student.student_name, "mood", -Balance.WIRAUSAHA_BIAYA_MOOD, "activity")
				log_stat_change(day_name, student.student_name, "energy", -Balance.WIRAUSAHA_BIAYA_ENERGI, "activity")
```

- [ ] **Step 3: Update the per-grade study gains**

Still in `apply_daily_decay_all`, replace:

```gdscript
			var base_gain = 3.0
			var specialty_bonus = 3.0
			var grade_num = GameState.current_grade
			if grade_num == 8:
				base_gain = 2.5
				specialty_bonus = 2.5
			elif grade_num == 9:
				base_gain = 2.0
				specialty_bonus = 2.0
```

with:

```gdscript
			var base_gain := Balance.BELAJAR_POIN_KELAS_7
			var specialty_bonus := Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
			var grade_num = GameState.current_grade
			if grade_num == 8:
				base_gain = Balance.BELAJAR_POIN_KELAS_8
				specialty_bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
			elif grade_num == 9:
				base_gain = Balance.BELAJAR_POIN_KELAS_9
				specialty_bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
```

- [ ] **Step 4: Update the fallback call**

In `apply_jadwal_effects_all`, replace:

```gdscript
					var deltas = student.apply_jadwal_activity(category, 5.0, 3.0)
```

with:

```gdscript
					var deltas = student.apply_jadwal_activity(category,
						Balance.BELAJAR_POIN_CADANGAN, Balance.BELAJAR_BONUS_FAVORIT_CADANGAN)
```

- [ ] **Step 5: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed**. `test_wirausaha` asserts the earning range and costs directly — a mistake here fails it loudly.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd
git commit -m "feat(balance): read study gains and Wirausaha from Balance"
```

---

# Task 4: Efficiency multipliers and thresholds

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentData.gd:104-110`, `:192-193`, `:279`

**Interfaces:**
- Consumes: `Balance.BIAYA_KALAU_*`, `Balance.BATAS_KELELAHAN`, `Balance.IZIN_OTOMATIS_BATAS_ENERGI`.

- [ ] **Step 1: Replace the efficiency multipliers**

Replace the whole of `get_category_efficiency_multiplier`:

```gdscript
func get_category_efficiency_multiplier(category: String) -> float:
	if category == specialty_category:
		return 0.6 # 40% less energy/mood spent when learning specialty!
	elif specialty_category == "Seimbang":
		return 0.85 # 15% balanced discount
	else:
		return 1.20 # 20% more energy/mood spent when learning non-specialty subject
```

with:

```gdscript
func get_category_efficiency_multiplier(category: String) -> float:
	if category == specialty_category:
		return Balance.BIAYA_KALAU_MAPEL_FAVORIT
	elif specialty_category == "Seimbang":
		return Balance.BIAYA_KALAU_MURID_SEIMBANG
	else:
		return Balance.BIAYA_KALAU_BUKAN_FAVORIT
```

- [ ] **Step 2: Replace the tired threshold**

```gdscript
func is_tired() -> bool:
	return energy <= Balance.BATAS_KELELAHAN
```

- [ ] **Step 3: Replace the auto-Izin threshold**

In `apply_jadwal_activity`, replace:

```gdscript
	if category != "Istirahat" and energy <= 5.0:
```

with:

```gdscript
	if category != "Istirahat" and energy <= Balance.IZIN_OTOMATIS_BATAS_ENERGI:
```

- [ ] **Step 4: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed**.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/StudentData.gd
git commit -m "feat(balance): read efficiency multipliers and thresholds from Balance"
```

---

# Task 5: Minigame results read from `Balance`

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentData.gd:118-152`

**Interfaces:**
- Consumes: all 24 `Balance.MINIGAME_*` fields.

This is the largest single block. Replace it wholesale rather than editing line by line.

- [ ] **Step 1: Replace the win/loss branches**

In `apply_minigame_result`, replace everything from `if won:` down to the line immediately before `# Apply specialty multiplier to costs`:

```gdscript
	if won:
		if score >= 0 and max_score > 0:
			var ratio = clampf(float(score) / float(max_score), 0.0, 1.0)
			if grade_num == 8:
				stat_change = roundf(4.0 + ratio * 8.0) if max_score > 1 else 8.0
			elif grade_num == 9:
				stat_change = roundf(3.0 + ratio * 6.0) if max_score > 1 else 6.0
			else:
				stat_change = roundf(5.0 + ratio * 10.0) if max_score > 1 else 10.0
		else:
			if grade_num == 8:
				stat_change = 8.0
			elif grade_num == 9:
				stat_change = 6.0
			else:
				stat_change = 10.0
		
		if grade_num == 8:
			energy_change = -7.0
			mood_change = -7.0
		elif grade_num == 9:
			energy_change = -10.0
			mood_change = -10.0
		else:
			energy_change = -5.0
			mood_change = -5.0
	else:
		if grade_num == 8:
			stat_change = -4.0
			energy_change = -12.0
			mood_change = -18.0
		elif grade_num == 9:
			stat_change = -5.0
			energy_change = -15.0
			mood_change = -20.0
		else:
			stat_change = -3.0
			energy_change = -10.0
			mood_change = -15.0
```

with:

```gdscript
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
```

This collapses three parallel grade branches into one lookup. The arithmetic is unchanged: `roundf(win_base + ratio * win_scale)` with Grade 7's values is exactly `roundf(5.0 + ratio * 10.0)`.

- [ ] **Step 2: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed**. `test_school_day` exercises minigame results across grades.

- [ ] **Step 3: Commit**

```bash
git add Scripts/SchoolSimulation/StudentData.gd
git commit -m "feat(balance): read minigame win and loss amounts from Balance"
```

---

# Task 6: Personality decay reads from `Balance`

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentData.gd:203-223`

**Interfaces:**
- Consumes: the 20 `Balance.DECAY_*` fields.

The existing comments here name `Budi`, `Ani` and `Cici` — students from an old fallback roster who are not in the game's actual six. This task replaces them with the correct names, which is part of the deliverable, not an aside.

- [ ] **Step 1: Replace the match block**

In `apply_personality_daily_decay`, replace:

```gdscript
	match personality:
		"Aktif": # Budi: Sporty
			energy_loss = roundf(randf_range(6.0, 8.0))
			mood_loss = roundf(randf_range(2.0, 4.0))
			reason = "Banyak aktivitas fisik & aktif bergerak"
		"Tekun": # Ani: Academic
			energy_loss = roundf(randf_range(3.0, 5.0))
			mood_loss = roundf(randf_range(6.0, 8.0))
			reason = "Fokus berpikir & belajar padat"
		"Kreatif": # Cici: Artistic
			energy_loss = roundf(randf_range(5.0, 7.0))
			mood_loss = roundf(randf_range(3.0, 5.0))
			reason = "Lelah berkreasi & mengeksplor ide"
		"Seni Dalam Kesunyian": # Citra: Artistic Introvert
			energy_loss = roundf(randf_range(4.0, 6.0))
			mood_loss = roundf(randf_range(4.0, 6.0))
			reason = "Merenung dalam ketenangan & berkarya sendiri"
		_: # Default: Balanced
			energy_loss = roundf(randf_range(4.0, 6.0))
			mood_loss = roundf(randf_range(4.0, 6.0))
			reason = "Menjalani rutinitas harian dengan santai"
```

with:

```gdscript
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
```

The `reason` strings are player-facing Indonesian and must not change.

- [ ] **Step 2: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed**.

- [ ] **Step 3: Commit**

```bash
git add Scripts/SchoolSimulation/StudentData.gd
git commit -m "feat(balance): read personality decay from Balance, fix stale student names"
```

---

# Task 7: Study costs, rest recovery, and the critical-mood cut

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentData.gd:287-290`, `:314-315`, `:339`

**Interfaces:**
- Consumes: `Balance.LIBUR_*`, `Balance.BELAJAR_BIAYA_*`, `Balance.SIFAT_SEMANGAT_POTONGAN_MOOD_KRITIS`.

- [ ] **Step 1: Replace rest recovery**

In `apply_jadwal_activity`, inside the `if category == "Istirahat":` branch, replace:

```gdscript
		energy_change = roundf(randf_range(20.0, 30.0))
		mood_change = roundf(randf_range(15.0, 25.0))
```

with:

```gdscript
		energy_change = roundf(randf_range(Balance.LIBUR_ENERGI_PULIH_MIN, Balance.LIBUR_ENERGI_PULIH_MAX))
		mood_change = roundf(randf_range(Balance.LIBUR_MOOD_PULIH_MIN, Balance.LIBUR_MOOD_PULIH_MAX))
```

- [ ] **Step 2: Replace study costs**

In the same function's `else:` branch, replace:

```gdscript
		energy_change = -roundf(randf_range(15.0, 20.0) * mult)
		mood_change = -roundf(randf_range(10.0, 15.0) * mult)
```

with:

```gdscript
		energy_change = -roundf(randf_range(Balance.BELAJAR_BIAYA_ENERGI_MIN, Balance.BELAJAR_BIAYA_ENERGI_MAX) * mult)
		mood_change = -roundf(randf_range(Balance.BELAJAR_BIAYA_MOOD_MIN, Balance.BELAJAR_BIAYA_MOOD_MAX) * mult)
```

- [ ] **Step 3: Replace the Semangat Juang mood cut**

Still in the same function, replace:

```gdscript
		if quirk == "Semangat Juang" and energy <= semangat_low_energy_threshold:
			mood_change = roundf(mood_change * 0.5)
```

with:

```gdscript
		if quirk == "Semangat Juang" and energy <= semangat_low_energy_threshold:
			mood_change = roundf(mood_change * Balance.SIFAT_SEMANGAT_POTONGAN_MOOD_KRITIS)
```

The `semangat_low_energy_threshold` reference stays as-is here — Task 8 converts it.

- [ ] **Step 4: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed**.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/StudentData.gd
git commit -m "feat(balance): read study costs and rest recovery from Balance"
```

---

# Task 8: Trait coefficients read from `Balance`

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentData.gd:33-81` (delete the exports), and their use sites at `:166`, `:171`, `:247-251`, `:294`, `:303`, `:308`, `:312`, `:319`, `:323-324`, `:329`, `:331`, `:335`, `:338`

**Interfaces:**
- Consumes: the 18 `Balance.SIFAT_*` fields plus `Balance.SIFAT_CITRA_SENI_SENDIRI_BONUS`.

These 18 are currently `@export`s carrying identical values on every student. Reading from `Balance` makes that sameness explicit and puts them in the tester's one file. **The `quirk == "..."` string comparisons are not touched** — only where each coefficient is read.

- [ ] **Step 1: Delete the export block**

Remove the whole `@export_group` region from `## Personality & Quirk Inspector-Editable Parameters` through `@export var pekerja_minigame_win_mood_bonus: float = 3.0`, and put a pointer in its place:

```gdscript
# Personality and Sifat Pasif coefficients now live in Scripts/Balance.gd.
```

Keep every other `@export` on this class — the stats, targets, `quirk`, `persona`, `personality` and so on are untouched.

- [ ] **Step 2: Replace each use site**

Substitute throughout `StudentData.gd`:

| Old identifier | New |
|---|---|
| `seni_kesunyian_solo_bonus` | `Balance.SIFAT_CITRA_SENI_SENDIRI_BONUS` |
| `penyendiri_crowd_threshold` | `Balance.SIFAT_PENYENDIRI_BATAS_KERAMAIAN` |
| `penyendiri_crowd_mood_penalty` | `Balance.SIFAT_PENYENDIRI_BOROS_MOOD_RAMAI` |
| `penyendiri_event_mood_penalty` | `Balance.SIFAT_PENYENDIRI_EVENT_MOOD` |
| `kutu_buku_akademis_stat_bonus` | `Balance.SIFAT_KUTU_BUKU_BONUS_POIN` |
| `kutu_buku_akademis_mood_discount` | `Balance.SIFAT_KUTU_BUKU_HEMAT_MOOD` |
| `kutu_buku_olahraga_mood_penalty` | `Balance.SIFAT_KUTU_BUKU_BOROS_MOOD_OLAHRAGA` |
| `semangat_minigame_win_stat_bonus` | `Balance.SIFAT_SEMANGAT_BONUS_MENANG` |
| `semangat_rest_energy_penalty` | `Balance.SIFAT_SEMANGAT_LIBUR_KURANG` |
| `semangat_low_energy_threshold` | `Balance.SIFAT_SEMANGAT_BATAS_ENERGI_KRITIS` |
| `penasaran_nonspec_stat_bonus` | `Balance.SIFAT_PENASARAN_BONUS_MAPEL_LAIN` |
| `penasaran_energy_cost_penalty` | `Balance.SIFAT_PENASARAN_BOROS_ENERGI` |
| `biang_onar_event_weight_bonus` | `Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT` |
| `biang_onar_positive_event_scale` | `Balance.SIFAT_BIANG_ONAR_EVENT_BAGUS` |
| `biang_onar_negative_event_scale` | `Balance.SIFAT_BIANG_ONAR_EVENT_BURUK` |
| `pekerja_energy_discount` | `Balance.SIFAT_PEKERJA_HEMAT_ENERGI` |
| `pekerja_mood_penalty` | `Balance.SIFAT_PEKERJA_BOROS_MOOD` |
| `pekerja_minigame_win_mood_bonus` | `Balance.SIFAT_PEKERJA_BONUS_MOOD_MENANG` |

- [ ] **Step 3: Convert `SchoolDay.gd`'s reads — this is required, not conditional**

`SchoolDay.gd` reads these coefficients off `StudentData` instances, so deleting the exports in Step 1 **will** break it. Three sites:

`SchoolDay.gd:834`, inside the event-weight roll:

```gdscript
							w_event += s.biang_onar_event_weight_bonus
```

becomes:

```gdscript
							w_event += Balance.SIFAT_BIANG_ONAR_PELUANG_EVENT
```

`SchoolDay.gd:903`, where the Biang Onar scale is picked up:

```gdscript
				biang_onar_scale = s.biang_onar_positive_event_scale
```

becomes:

```gdscript
				biang_onar_scale = Balance.SIFAT_BIANG_ONAR_EVENT_BAGUS
```

`SchoolDay.gd:1449`, inside `force_event` — the debug overlay's copy of the same block, which must get the identical edit:

```gdscript
					biang_onar_scale = Balance.SIFAT_BIANG_ONAR_EVENT_BAGUS
```

Note the deeper indentation at this third site; it sits one level further in than the one at 903.

- [ ] **Step 4: Prove no other reader survives**

```bash
grep -rn "kutu_buku_\|semangat_\|penasaran_\|penyendiri_\|biang_onar_\|pekerja_\|seni_kesunyian_" Scripts/ tests/
```

Expected: hits in `Scripts/Balance.gd` only. Anything else is a use site still to convert — `tests/` included, where a test reading a deleted `@export` would fail. Note that a local variable named `biang_onar_scale` in `SchoolDay.gd` also matches this pattern; that is a local, not a coefficient read, and stays as it is.

- [ ] **Step 5: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed**.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/StudentData.gd Scripts/SchoolSimulation/SchoolDay.gd
git commit -m "feat(balance): read Sifat Pasif coefficients from Balance"
```

---

# Task 9: Random event values read from `Balance`

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:908-964` (`_trigger_random_event`)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:1454-1509` (`force_event`)

**Interfaces:**
- Consumes: the 12 `Balance.EVENT_*` fields.

Five random events carry hardcoded stat, mood and energy amounts. Each is wrapped in the same Biang Onar scaling expression, which stays exactly as it is — only the bare number at the front of each line changes.

**These twelve numbers appear twice.** `_trigger_random_event` (the real roll) and `force_event` (the debug overlay's "trigger event N" hook) hold byte-identical copies of all five event bodies. Both must be edited, or the tester changes a number, forces the event from the overlay to check it, and sees the old value — the exact confusion this tool exists to prevent. Every replacement below applies to **both** functions; the bodies differ only in the `match` label above them (`"Akademis Event":` vs `0:`, and so on).

- [ ] **Step 1: Replace the three subject-event blocks**

In `_trigger_random_event`, replace each bare literal with its field, leaving the surrounding `* (1.0 + biang_onar_scale if biang_onar_active else 1.0)` untouched:

```gdscript
			# Akademis event
			var stat_val := Balance.EVENT_AKADEMIS_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_AKADEMIS_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
```

```gdscript
			# Olahraga event
			var stat_val := Balance.EVENT_OLAHRAGA_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_OLAHRAGA_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_OLAHRAGA_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
```

```gdscript
			# Seni Budaya event
			var stat_val := Balance.EVENT_SENI_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_SENI_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_SENI_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
```

- [ ] **Step 2: Replace the two whole-class events**

Nasi Kotak:

```gdscript
			var energy_bonus := Balance.EVENT_NASI_KOTAK_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_bonus := Balance.EVENT_NASI_KOTAK_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
```

Hujan:

```gdscript
			var energy_penalty := Balance.EVENT_HUJAN_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_penalty := Balance.EVENT_HUJAN_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
```

The player-facing announcement strings that interpolate these values (`"Akademis +%d"` and friends) read from the same variables and need no change.

- [ ] **Step 3: Confirm both copies were caught**

```bash
grep -n "15.0 \* (1.0 + biang_onar_scale\|20.0 \* (1.0 + biang_onar_scale\|25.0 \* (1.0 + biang_onar_scale\|10.0 \* (1.0 + biang_onar_scale" Scripts/SchoolSimulation/SchoolDay.gd
```

Expected: no output. Any hit is a line in `force_event` that Step 1 or 2 missed.

- [ ] **Step 4: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed**.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd
git commit -m "feat(balance): read random event amounts from Balance"
```

---

# Task 10: Skip-mode odds, and prove nothing was missed

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:1214`
- Modify: `tests/test_balance.gd`

**Interfaces:**
- Consumes: `Balance.SKIP_PELUANG_KALAH`.

The scan below polices `StudentData.gd`'s five simulation functions — where a stray literal would silently change the game. It deliberately does not police `SchoolDay.gd`, which is mostly tween durations and modulate values that would flood the results with false positives. Task 11 closes the one part of `SchoolDay.gd` that matters to a tester by hand.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_balance.gd`:

```gdscript
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
```

- [ ] **Step 2: Run and confirm it fails**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="balance")`.
Expected: FAIL — `apply_jadwal_activity` still contains `0.5` from the Semangat Juang branch if Task 7 was skipped, and in any case this test has never run before. If it passes immediately, verify by temporarily reverting one extracted literal, watching it fail, then restoring.

- [ ] **Step 3: Replace the skip-mode odds**

In `SchoolDay.skip_to_results`, replace:

```gdscript
			var won = randf() > 0.4
```

with:

```gdscript
			var won = randf() > Balance.SKIP_PELUANG_KALAH
```

- [ ] **Step 4: Run and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="balance")`.
Expected: PASS, 3 tests.

If a literal is flagged that is genuinely structural rather than balance — a coordinate, a duration, a ratio that is part of the formula rather than a tunable — add it to the `allowed` list **with a comment saying why**, rather than inventing a `Balance` field for it.

- [ ] **Step 5: Run the full suite**

**Controller action:** `test_run()`.
Expected: **303 passed, 1 failed** (the known `audio_director` bug only).

- [ ] **Step 6: Verify the file works end to end**

This is the one check no test can make: that changing a number actually changes the game.

**Controller action:** temporarily set `Balance.MINIGAME_KALAH_MOOD_KELAS_7 := -60.0` in `Scripts/Balance.gd`, then:

```
filesystem_manage(op="scan")
project_run(mode="main")
```

Press `F1`, click **Seed Playtest State**, go to the **Minigames** tab, force a loss, and confirm the mood drop is visibly far larger than before. Then restore `-15.0`, rescan, and confirm it returns to normal.

**Do not commit the temporary value.** `git diff Scripts/Balance.gd` must be empty before Step 7.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_balance.gd
git commit -m "feat(balance): read skip-mode odds from Balance, guard against missed literals"
```

---

# Task 11: The day-preview badges tell the truth

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:554-578`

**Interfaces:**
- Consumes: `Balance.BELAJAR_POIN_KELAS_*`, `Balance.BELAJAR_BONUS_FAVORIT_KELAS_*`, `Balance.BELAJAR_BIAYA_ENERGI_MIN`, `Balance.BELAJAR_BIAYA_MOOD_MIN`, `Balance.LIBUR_ENERGI_PULIH_MAX`, `Balance.BATAS_KELELAHAN`.

`_build_pill_badges_for_student` paints the "+3 Akademis 📚 / ~-15 ⚡ / ~-10 😊" badges above each student on the day screen. It computes them from **its own hardcoded copy** of the study numbers rather than from the simulation. Left alone, this is the first thing the tester hits: they raise `BELAJAR_POIN_KELAS_7` to 10, the day screen still says `+3`, and they conclude the file does not work.

**This task changes on-screen text, and that is deliberate.** The badge already lies today — it hardcodes `6.0`/`3.0` while the simulation scales gains by grade, so in Grades 8 and 9 the preview has always been wrong. Wiring it to `Balance` fixes that pre-existing bug as a side effect. Flagging it here so a reviewer sees the changed numbers in a Grade 8 screenshot and knows it was intended.

- [ ] **Step 1: Give the badge helper the grade's numbers**

Add above `_build_pill_badges_for_student`:

```gdscript
## The preview badge must quote the same gain the simulation will apply,
## or a tester changing Balance.gd sees the old number here and thinks
## nothing happened. Mirrors StudentManager.apply_jadwal_effects_all.
func _preview_gain(student: StudentData, category: String) -> float:
	var base := Balance.BELAJAR_POIN_CADANGAN
	var bonus := Balance.BELAJAR_BONUS_FAVORIT_CADANGAN
	match GameState.current_grade:
		7:
			base = Balance.BELAJAR_POIN_KELAS_7
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
		8:
			base = Balance.BELAJAR_POIN_KELAS_8
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
		9:
			base = Balance.BELAJAR_POIN_KELAS_9
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
	if student.specialty_category == category:
		return base + bonus
	return base
```

- [ ] **Step 2: Point the badges at it**

Replace the three `var gain = ...` lines:

```gdscript
	match category:
		"Akademis":
			var gain := _preview_gain(student, "Akademis")
			_add_pill(hbox, "+%.0f Akademis 📚" % gain, tokens.cat_akademis)
		"SeniBudaya":
			var gain := _preview_gain(student, "SeniBudaya")
			_add_pill(hbox, "+%.0f Seni 🎨" % gain, tokens.cat_senibudaya)
		"Olahraga":
			var gain := _preview_gain(student, "Olahraga")
			_add_pill(hbox, "+%.0f Olahraga ⚽" % gain, tokens.cat_olahraga)
```

- [ ] **Step 3: Un-bake the three numbers baked into strings**

The rest-recovery and cost badges have their numbers written inside the literal text, so they cannot drift-detect. Replace:

```gdscript
		"Istirahat":
			_add_pill(hbox, "+%.0f ⚡ Libur" % Balance.LIBUR_ENERGI_PULIH_MAX, tokens.state_success)
```

and:

```gdscript
	# Energy/Mood cost estimate (show if studying)
	if category != "" and category != "Istirahat":
		_add_pill(hbox, "~-%.0f ⚡" % Balance.BELAJAR_BIAYA_ENERGI_MIN, tokens.state_danger)
		_add_pill(hbox, "~-%.0f 😊" % Balance.BELAJAR_BIAYA_MOOD_MIN, tokens.state_warning)
```

The badge quotes the cheap end of each random range — it is an estimate, and the `~` already says so.

- [ ] **Step 4: The tiredness warning reads the shared threshold**

```gdscript
	# Warning if already low energy
	if student.energy <= Balance.BATAS_KELELAHAN:
```

- [ ] **Step 5: Run the full suite**

**Controller action:** `filesystem_manage(op="scan")` then `test_run()`.
Expected: **303 passed, 1 failed** (the known `audio_director` bug only).

If a test asserts on the badge text, it was pinning the old hardcoded string. Update it to the new value rather than reverting the change, and say so in the commit body.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd
git commit -m "fix(balance): day-preview badges quote the real numbers, not a stale copy"
```

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: the file and its conventions → Task 1; the extraction inventory → Tasks 2–9, one per group; the "two data facts" (stale student names, Citra's unused bonus) → Task 6's comment fix and Task 1's file comment respectively; the safety property → the full-suite run closing every task; the testing section → Tasks 1 and 10.

**Two deliberate departures from the spec**, both found while tracing which files read the trait exports, and both recorded here rather than folded in silently:

1. **The count is 105, not ~93.** The extra 12 are `SchoolDay.gd`'s random-event amounts, added as Task 9. "Hujan drains 15 mood and that feels brutal" is exactly the complaint this tool exists to answer, so leaving them out would put a visible hole in it.
2. **Task 11 was not in the spec at all.** The day-screen preview badges keep a private copy of the study gains, so without it the tester's very first edit appears to do nothing. It is the only task that changes on-screen output, and the only one that fixes a pre-existing bug (the badge has always been wrong in Grades 8 and 9).

The spec's inventory table should be updated to match if it is revised.

**Duplication caught during review.** Three of the numbers in this plan live in more than one place in `SchoolDay.gd`, and a task that edits only one copy leaves the tester with a file that half-works: the twelve event amounts appear in both `_trigger_random_event` and `force_event` (Task 9 edits both, Step 3 proves it), the Biang Onar scale is read at three sites rather than two (Task 8 Step 3), and the study gains have a third copy in the preview badges (Task 11).

**Placeholders.** None. Every code step carries the literal before-and-after text, and every run step names the command and its expected result.

**Type consistency.** Field names are fixed once in Task 1's `Balance.gd` and its test's `_EXPECTED` table, and every later task's substitutions use those exact names. The Task 8 mapping table lists all 18 old→new pairs explicitly rather than deferring to a search.

**Counts.** Task 1's `_EXPECTED` table has 93 entries and the test asserts that size, so a field added or dropped later fails deliberately rather than silently.

**Known risks.**
1. Task 10's regex flags any `N.N` literal. If a structural number lives in one of those five functions, the fix is the documented `allowed` list, not a fake `Balance` field.
2. Task 8's `grep` is the only thing standing between a deleted `@export` and a broken reader outside `StudentData.gd`; `SchoolDay.gd` is called out because it is the known case, but the grep is authoritative.
3. The expected full-suite figure (303/1) assumes the suite is at 304 with the one known `audio_director` failure. Re-baseline with `test_run()` before starting if the branch has moved.
