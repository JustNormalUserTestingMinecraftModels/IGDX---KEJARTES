# Grade Progression, Difficulty Curve & Anti-Exploit Balance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make grade 7 demand tactical scheduling (not one lucky week), ramp grades 8–9 progressively, reset roster skill stats with a small head-start on every grade change, teach specialty scheduling with particle/SFX feedback in AturJadwal, and close the "farm one minigame category" exploit — all without changing how often minigames or events appear.

**Architecture:** Every tunable moves through `Scripts/Balance.gd` (pinned by `tests/test_balance.gd`). A new `GameState.reset_roster_for_new_grade()` is the single roster-reset path shared by real progression and debug grade-jumps. A per-student weekly minigame-points cap is clipped inside `StudentManager.record_minigame_result()`. The AturJadwal feedback is one new authored `CPUParticles2D` scene plus toggled authored child nodes — no runtime visual construction, no `theme_override_*`. A headless greedy-sim suite (`tests/test_balance_pacing.gd`) is the tuning loop for the estimated numbers.

**Tech Stack:** Godot 4.6 (mobile renderer, portrait), GDScript, `McpTestSuite` test suites run via the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-04-grade-progression-balance-and-difficulty.md` — read it alongside this plan.

## Global Constraints

- **Godot 4.6**, mobile renderer, portrait. Main scene `Scenes/MainMenu/main_menu.tscn` — open it in the editor before trusting any `test_run` failure (`scene_warning` names the scene a suite needs).
- **Every tunable gameplay number lives in `Scripts/Balance.gd`** as a `static var` with a `##` Indonesian doc line, grouped under the existing section banners. No gameplay literal anywhere else.
- **`tests/test_balance.gd` pins every `Balance` field.** Any add/rename/retune updates `_EXPECTED` **and** the `_EXPECTED.size()` literal in `test_the_expected_table_covers_every_number()` in the same commit.
- **Test suites** extend `McpTestSuite`, are `@tool`, define `suite_name() -> String`, and contain **no coroutines** — an `await` in a test silently aborts it ("0 assertions"). Assertions: `assert_true`, `assert_false`, `assert_eq`, `assert_null`.
- **Rescan after editing a `.gd` from outside the editor**: Godot AI MCP `filesystem_manage(op="scan")` before `test_run`. If a new `static var` / `@export` stays invisible, force a reload with a no-op `script_patch` on that file (add then remove a blank line) — logs a benign `reload failed with error code 43`, then works.
- **Never hand-edit a `.tscn` while the editor is attached.** Scene changes go through the editor: `scene_open` → `node_create` / `node_set_property` / `batch_execute` → `scene_save`. `anchors_preset` is inert (set the four anchors); numbers unquoted; a node's type needs delete-and-recreate.
- **Visual system:** no `theme_override_*` (use a `ThemeFactory` type variation or a layout-only constant override); no visual built at runtime that could be an authored node or `PackedScene`. `@tool` visual scripts gate real side effects behind `if Engine.is_editor_hint(): return`.
- **UI text is Indonesian**; engine/systems identifiers are English. Every script needs a `##` file header; every `@export` needs a `##` line (`tests/test_script_documentation.gd` enforces this).
- **Commits:** Conventional Commits with a scope, e.g. `feat(balance): cap weekly minigame skill gain per student`. End the message with:
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
- **Week counts stay 6 / 12 / 16.** `CHANCE_MINIGAME` (40), `CHANCE_EVENT` (40), the `active_studying * 15` minigame weight, and `w_normal` are **not touched**.
- **The two student representations do not share key names.** `GameState.approved_students` is `Array[Dictionary]` with UI keys (`akademis1`=academic, `akademis2`=seni, `akademis3`=olahraga, `kepribadian1`=mood, `kepribadian2`=energy). `StudentData` has real fields (`akademis`, `seni_budaya`, `olahraga`, `mood`, `energy`). `hobby_category` "Akademik" maps to specialty "Akademis".

---

## Task 1: Balance.gd constants + test_balance.gd pinning

**Files:**
- Modify: `Scripts/Balance.gd`
- Modify: `tests/test_balance.gd:14-133` (`_EXPECTED` dict) and `:159-161` (`_EXPECTED.size()` assertion)

**Interfaces:**
- Produces (all `static var` on `Balance`, read as `Balance.NAME`):
  - `TARGET_KENAIKAN_KELAS_8: float = 34.0` (retuned from 30.0)
  - `TARGET_KENAIKAN_KELAS_9: float = 50.0` (retuned from 40.0)
  - `KENAIKAN_KELAS_HEAD_START_FRAKSI: float = 0.20` (new)
  - `BIAYA_KALAU_MAPEL_FAVORIT: float = 0.55` (retuned from 0.6)
  - `BIAYA_KALAU_BUKAN_FAVORIT: float = 1.28` (retuned from 1.20)
  - `SIFAT_KUTU_BUKU_BONUS_POIN: float = 1.5` (retuned from 1.0)
  - `SIFAT_KUTU_BUKU_HEMAT_MOOD: float = 0.35` (retuned from 0.25)
  - `SIFAT_SEMANGAT_BONUS_MENANG: float = 3.0` (retuned from 2.0)
  - `SIFAT_PENASARAN_BONUS_MAPEL_LAIN: float = 1.5` (retuned from 1.0)
  - `SIFAT_PEKERJA_BONUS_MOOD_MENANG: float = 4.0` (retuned from 3.0)
  - `MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7: float = 14.0` (new)
  - `MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8: float = 12.0` (new)
  - `MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9: float = 10.0` (new)
  - `MINIGAME_WAKTU_SKALA_KELAS_8: float = 0.8` (new; extracted literal)
  - `MINIGAME_WAKTU_SKALA_KELAS_9: float = 0.6` (new; extracted literal)
  - `MINIGAME_KATEGORI_ACAK_PELUANG: float = 0.35` (new)
  - `MINIGAME_MAKS_MINGGU_MIN: int = 1` (new)
  - `MINIGAME_MAKS_MINGGU_MAX: int = 3` (new)
  - `SKIP_PELUANG_KALAH_KELAS_7: float = 0.4` (renamed from `SKIP_PELUANG_KALAH`)
  - `SKIP_PELUANG_KALAH_KELAS_8: float = 0.5` (new)
  - `SKIP_PELUANG_KALAH_KELAS_9: float = 0.6` (new)
- Removes: `SKIP_PELUANG_KALAH` (renamed — see Task 2 for its only non-test call site).

- [ ] **Step 1: Confirm the current pinning-count baseline**

Run: Godot AI MCP `test_run` filtered to suite `balance` (or full run).
Expected: PASS, 107 in `test_the_expected_table_covers_every_number`. If it is not 107, stop — someone changed `Balance` without updating the count; reconcile before continuing.

- [ ] **Step 2: Grep for every `SKIP_PELUANG_KALAH` reference**

Run: `grep -rn "SKIP_PELUANG_KALAH" Scripts/ tests/`
Expected: exactly two files — `Scripts/SchoolSimulation/SchoolDay.gd` (one line, ~1257) and `tests/test_balance.gd`. If anything else references it, note it for Task 2.

- [ ] **Step 3: Edit `Scripts/Balance.gd` — retune existing fields**

Under `## SYARAT LULUS`, change the two target lines:

```gdscript
static var TARGET_KENAIKAN_KELAS_8 := 34.0
static var TARGET_KENAIKAN_KELAS_9 := 50.0
```

Add, directly below `TARGET_KENAIKAN_KELAS_9`:

```gdscript
## Bagian kenaikan skill di atas nilai awal roster yang DISIMPAN saat murid
## naik kelas. 0.20 = murid membawa 20% kemajuannya sebagai modal awal kelas
## berikutnya; sisanya di-reset. Dipakai GameState.reset_roster_for_new_grade().
static var KENAIKAN_KELAS_HEAD_START_FRAKSI := 0.20
```

Under `## HARI BELAJAR BIASA`, change:

```gdscript
static var BIAYA_KALAU_MAPEL_FAVORIT := 0.55
static var BIAYA_KALAU_BUKAN_FAVORIT := 1.28
```

Under `## SIFAT PASIF`, change these four (leave every other `SIFAT_*` untouched):

```gdscript
static var SIFAT_KUTU_BUKU_BONUS_POIN := 1.5
static var SIFAT_KUTU_BUKU_HEMAT_MOOD := 0.35
static var SIFAT_SEMANGAT_BONUS_MENANG := 3.0
static var SIFAT_PENASARAN_BONUS_MAPEL_LAIN := 1.5
static var SIFAT_PEKERJA_BONUS_MOOD_MENANG := 4.0
```

- [ ] **Step 4: Edit `Scripts/Balance.gd` — add the new MINIGAME constants**

Under `## MINIGAME — menang dan kalah`, after the `MINIGAME_MENANG_POIN_TANPA_SKOR_*` block, add:

```gdscript
## Batas poin skill yang bisa didapat SATU murid dari MENANG minigame dalam
## satu minggu. Kekalahan TIDAK dibatasi. Menahan agar satu minggu penuh
## kemenangan minigame tidak langsung menuntaskan satu target.
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7 := 14.0
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8 := 12.0
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9 := 10.0

## Pengali durasi minigame per kelas (dulu angka mati di SchoolDay). Di bawah
## 1.0 = waktu lebih singkat. Tidak mengubah perilaku, hanya memindah angka.
static var MINIGAME_WAKTU_SKALA_KELAS_8 := 0.8
static var MINIGAME_WAKTU_SKALA_KELAS_9 := 0.6

## Saat sebuah hari memunculkan Minigame, sebesar peluang ini kategorinya
## diundi RATA (Akademis/Olahraga/Seni) tanpa melihat jadwal; sisanya ikut
## proporsi murid yang belajar. BUKAN peluang munculnya minigame — itu tetap.
static var MINIGAME_KATEGORI_ACAK_PELUANG := 0.35

## Berapa minigame paling banyak dalam satu minggu — diundi ulang tiap minggu
## di rentang ini (rata-rata ~2, seperti dulu, tapi tidak bisa dipastikan).
## Harus angka bulat (tanpa titik).
static var MINIGAME_MAKS_MINGGU_MIN := 1
static var MINIGAME_MAKS_MINGGU_MAX := 3
```

- [ ] **Step 5: Edit `Scripts/Balance.gd` — split the skip constant**

Under `## MODE SKIP`, replace `static var SKIP_PELUANG_KALAH := 0.4` with:

```gdscript
## Peluang KALAH saat pemain menekan Skip (minigame tidak dimainkan, hasil
## diundi). Naik per kelas: skip makin berisiko di kelas atas, tapi tetap ada
## sebagai jalan aksesibilitas. 0.4 = menang 60% di kelas 7.
static var SKIP_PELUANG_KALAH_KELAS_7 := 0.4
static var SKIP_PELUANG_KALAH_KELAS_8 := 0.5
static var SKIP_PELUANG_KALAH_KELAS_9 := 0.6
```

- [ ] **Step 6: Update `tests/test_balance.gd` `_EXPECTED`**

In the `_EXPECTED` dict: change the values for `TARGET_KENAIKAN_KELAS_8` (34.0), `TARGET_KENAIKAN_KELAS_9` (50.0), `BIAYA_KALAU_MAPEL_FAVORIT` (0.55), `BIAYA_KALAU_BUKAN_FAVORIT` (1.28), `SIFAT_KUTU_BUKU_BONUS_POIN` (1.5), `SIFAT_KUTU_BUKU_HEMAT_MOOD` (0.35), `SIFAT_SEMANGAT_BONUS_MENANG` (3.0), `SIFAT_PENASARAN_BONUS_MAPEL_LAIN` (1.5), `SIFAT_PEKERJA_BONUS_MOOD_MENANG` (4.0).

Remove the `"SKIP_PELUANG_KALAH": 0.4,` line. Add, in the matching ban"# Skip" / "# Syarat lulus" / "# Minigame" groups:

```gdscript
	"KENAIKAN_KELAS_HEAD_START_FRAKSI": 0.20,
	"MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7": 14.0,
	"MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8": 12.0,
	"MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9": 10.0,
	"MINIGAME_WAKTU_SKALA_KELAS_8": 0.8,
	"MINIGAME_WAKTU_SKALA_KELAS_9": 0.6,
	"MINIGAME_KATEGORI_ACAK_PELUANG": 0.35,
	"MINIGAME_MAKS_MINGGU_MIN": 1,
	"MINIGAME_MAKS_MINGGU_MAX": 3,
	"SKIP_PELUANG_KALAH_KELAS_7": 0.4,
	"SKIP_PELUANG_KALAH_KELAS_8": 0.5,
	"SKIP_PELUANG_KALAH_KELAS_9": 0.6,
```

- [ ] **Step 7: Update the count assertion**

In `test_the_expected_table_covers_every_number()`, change `107` to `118` and update the comment:

```gdscript
	assert_eq(_EXPECTED.size(), 118,
		"the extraction covers 118 numbers; update this test deliberately if that changes")
```

(107 − 1 removed `SKIP_PELUANG_KALAH` + 12 added = 118.)

- [ ] **Step 8: Rescan and run the balance suite**

Run: `filesystem_manage(op="scan")` then `test_run` suite `balance`.
Expected: PASS — `test_every_field_exists_and_holds_its_shipped_value`, `test_the_expected_table_covers_every_number` (118), `test_no_balance_literals_left_in_extracted_functions`, `test_grade_week_counts_come_from_balance` all green. If a new field reads `null`, force-reload `Balance.gd` with a no-op `script_patch` and re-run.

- [ ] **Step 9: Run the full suite to catch call-site breakage**

Run: `test_run` (all suites), `main_menu.tscn` open.
Expected: the only new failures are anything referencing `Balance.SKIP_PELUANG_KALAH` by its old name (fixed in Task 2). Note them; do not fix here.

- [ ] **Step 10: Commit**

```bash
git add Scripts/Balance.gd tests/test_balance.gd
git commit -m "feat(balance): retune grade 8/9 targets, add weekly minigame cap, head-start and anti-exploit constants

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: SchoolDay call-sites for the renamed / extracted Balance constants

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — `_play_minigame()` (~line 1086-1093) and the skip resolution (~line 1257)
- Modify: `tests/test_school_day.gd` (add source-scan assertions)

**Interfaces:**
- Consumes: `Balance.MINIGAME_WAKTU_SKALA_KELAS_8/9`, `Balance.SKIP_PELUANG_KALAH_KELAS_7/8/9` (Task 1).
- Produces: no new symbols. Behaviour: skip loss-chance now varies by grade; minigame duration scaling unchanged in value.

- [ ] **Step 1: Write the failing source-scan test**

In `tests/test_school_day.gd`, add:

```gdscript
func test_skip_uses_per_grade_loss_chance() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_false(src.contains("Balance.SKIP_PELUANG_KALAH)"),
		"skip must not read the old single SKIP_PELUANG_KALAH constant")
	assert_true(src.contains("SKIP_PELUANG_KALAH_KELAS_"),
		"skip resolution must pick a per-grade SKIP_PELUANG_KALAH_KELAS_* value")

func test_minigame_time_scale_comes_from_balance() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("Balance.MINIGAME_WAKTU_SKALA_KELAS_8"),
		"grade-8 minigame duration must read Balance.MINIGAME_WAKTU_SKALA_KELAS_8")
	assert_true(src.contains("Balance.MINIGAME_WAKTU_SKALA_KELAS_9"),
		"grade-9 minigame duration must read Balance.MINIGAME_WAKTU_SKALA_KELAS_9")
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `school_day`.
Expected: FAIL — both new tests (old constant name still present, `MINIGAME_WAKTU_SKALA_*` absent).

- [ ] **Step 3: Replace the minigame time-scale literals**

In `_play_minigame()`, the `match GameState.current_grade:` block that currently reads:

```gdscript
		match GameState.current_grade:
			8: duration = base_duration * 0.8
			9: duration = base_duration * 0.6
```

becomes:

```gdscript
		match GameState.current_grade:
			8: duration = base_duration * Balance.MINIGAME_WAKTU_SKALA_KELAS_8
			9: duration = base_duration * Balance.MINIGAME_WAKTU_SKALA_KELAS_9
```

- [ ] **Step 4: Make the skip loss-chance per-grade**

At the skip resolution (currently `var won = randf() > Balance.SKIP_PELUANG_KALAH`), replace with:

```gdscript
	var skip_lose_chance := Balance.SKIP_PELUANG_KALAH_KELAS_7
	match GameState.current_grade:
		8: skip_lose_chance = Balance.SKIP_PELUANG_KALAH_KELAS_8
		9: skip_lose_chance = Balance.SKIP_PELUANG_KALAH_KELAS_9
	var won = randf() > skip_lose_chance
```

Keep the surrounding lines (the loop over students / `record_minigame_result` call) exactly as they are.

- [ ] **Step 5: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `school_day` and `balance`.
Expected: PASS. Full `test_run` shows no remaining `SKIP_PELUANG_KALAH` old-name failures.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_school_day.gd
git commit -m "refactor(school-day): read per-grade skip risk and minigame time-scale from Balance

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: `GameState.reset_roster_for_new_grade()` + `minigame_gain_this_week`

**Files:**
- Modify: `Scripts/GameState.gd` (add field near line 39; add function near `initialize_grade_targets`, ~line 91)
- Create: `tests/test_roster_reset.gd`

**Interfaces:**
- Consumes: `Balance.KENAIKAN_KELAS_HEAD_START_FRAKSI` (Task 1).
- Produces:
  - `GameState.minigame_gain_this_week: Dictionary` — `int student_id -> float` skill gained from minigame wins this week. Read/written by Task 5; cleared here and in Task 6.
  - `GameState.reset_roster_for_new_grade() -> void` — rebases each `approved_students` skill to `roster_base + 0.20*max(0, end-roster_base)` (floored at `roster_base`), sets `kepribadian1/2 = 80.0`, erases `base_akademis1/2/3`, clears `minigame_gain_this_week`. No-op when `approved_students` is empty. Populates a missing `roster_base_akademisN` key from the current value before using it.

- [ ] **Step 1: Write the failing test**

Create `tests/test_roster_reset.gd`:

```gdscript
@tool
extends McpTestSuite

## GameState.reset_roster_for_new_grade() is the one path that rebases roster
## skill stats when a grade changes -- real progression and debug jumps both
## call it. These tests pin the head-start formula, the mood/energy snap, the
## target-cache wipe, and the empty-roster no-op.

func suite_name() -> String:
	return "roster_reset"

func _make_student(id: int, ak1: float, base1: float) -> Dictionary:
	return {
		"id": id, "name": "T%d" % id,
		"akademis1": ak1, "akademis2": 60.0, "akademis3": 70.0,
		"roster_base_akademis1": base1, "roster_base_akademis2": 40.0, "roster_base_akademis3": 55.0,
		"kepribadian1": 22.0, "kepribadian2": 15.0,
		"base_akademis1": 30.0, "base_akademis2": 40.0, "base_akademis3": 55.0,
	}

func test_head_start_keeps_twenty_percent_of_gains() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	var s: Dictionary = GameState.approved_students[0]
	# 30 + 0.20 * (50 - 30) = 34.0
	assert_true(is_equal_approx(float(s["akademis1"]), 34.0),
		"akademis1 should rebase to roster_base + 20% of gains, got %s" % str(s["akademis1"]))
	GameState.approved_students = saved

func test_skill_below_roster_base_floors_at_roster_base() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = [_make_student(1, 25.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	assert_true(is_equal_approx(float(GameState.approved_students[0]["akademis1"]), 30.0),
		"a skill ending below roster_base must snap up to roster_base exactly")
	GameState.approved_students = saved

func test_mood_energy_snap_and_target_cache_wiped() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	var s: Dictionary = GameState.approved_students[0]
	assert_true(is_equal_approx(float(s["kepribadian1"]), 80.0), "mood snaps to 80")
	assert_true(is_equal_approx(float(s["kepribadian2"]), 80.0), "energy snaps to 80")
	assert_false(s.has("base_akademis1"), "base_akademis1 must be erased")
	assert_false(s.has("base_akademis2"), "base_akademis2 must be erased")
	assert_false(s.has("base_akademis3"), "base_akademis3 must be erased")
	assert_true(s.has("roster_base_akademis1"), "roster_base_akademis1 must be preserved")
	GameState.approved_students = saved

func test_missing_roster_base_is_captured_from_current() -> void:
	var saved := GameState.approved_students
	var s := _make_student(1, 50.0, 30.0)
	s.erase("roster_base_akademis2")  # simulate the debug-seed roster path
	GameState.approved_students = [s]
	GameState.reset_roster_for_new_grade()
	var out: Dictionary = GameState.approved_students[0]
	assert_true(out.has("roster_base_akademis2"),
		"a missing roster_base_akademis2 must be captured from the pre-reset value")
	assert_true(is_equal_approx(float(out["roster_base_akademis2"]), 60.0),
		"captured roster_base_akademis2 should equal the pre-reset akademis2 (60)")
	# end==base -> stays at base
	assert_true(is_equal_approx(float(out["akademis2"]), 60.0),
		"with roster_base just captured from current, akademis2 is unchanged")
	GameState.approved_students = saved

func test_empty_roster_is_a_noop() -> void:
	var saved := GameState.approved_students
	GameState.approved_students = []
	GameState.reset_roster_for_new_grade()  # must not error
	assert_eq(GameState.approved_students.size(), 0)
	GameState.approved_students = saved

func test_gain_tracker_cleared() -> void:
	var saved := GameState.approved_students
	GameState.minigame_gain_this_week = {5: 9.0}
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.reset_roster_for_new_grade()
	assert_eq(GameState.minigame_gain_this_week.size(), 0,
		"reset must clear the weekly minigame-gain tracker")
	GameState.approved_students = saved
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `roster_reset`.
Expected: FAIL — `reset_roster_for_new_grade` not defined / `minigame_gain_this_week` not a property.

- [ ] **Step 3: Add the field**

In `Scripts/GameState.gd`, near the other week-tracking vars (after `var day_schedules: Dictionary = {}`), add:

```gdscript
## Per-week tally of skill points each student has gained from minigame WINS,
## student_id -> float. Enforces Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_*.
## Cleared at week start (SchoolDay.start_simulation) and on grade change
## (reset_roster_for_new_grade). Session-scoped like everything here.
var minigame_gain_this_week: Dictionary = {}
```

- [ ] **Step 4: Add the function**

In `Scripts/GameState.gd`, directly above `func initialize_grade_targets() -> void:`, add:

```gdscript
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
```

- [ ] **Step 5: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suite `roster_reset`.
Expected: PASS all 7 tests. If `minigame_gain_this_week` or the function is invisible, no-op `script_patch` on `GameState.gd` and re-run.

- [ ] **Step 6: Commit**

```bash
git add Scripts/GameState.gd tests/test_roster_reset.gd
git commit -m "feat(gamestate): add reset_roster_for_new_grade with 20% head-start

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Capture `roster_base_akademis*` at roster approval

**Files:**
- Modify: `Scripts/StudentCard/student_card.gd` (~lines 1179-1188, where `GameState.approved_students` is populated from `student_data_list`)
- Modify: `tests/test_student_card.gd` (source-scan assertion) — if no such suite exists, add the assertion to `tests/test_roster_reset.gd` instead as a source-scan.

**Interfaces:**
- Consumes: nothing new.
- Produces: each dict pushed into `GameState.approved_students` carries `roster_base_akademis1/2/3` copied from its `akademis1/2/3` at approval time. Task 3's fallback covers dicts that somehow lack them.

- [ ] **Step 1: Write the failing source-scan test**

Add to `tests/test_roster_reset.gd`:

```gdscript
func test_student_card_captures_roster_base_on_approval() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/student_card.gd")
	assert_true(src.contains("roster_base_akademis1"),
		"student_card must stamp roster_base_akademis1 when it approves the roster")
	assert_true(src.contains("roster_base_akademis3"),
		"student_card must stamp roster_base_akademis3 when it approves the roster")
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `roster_reset`.
Expected: FAIL — `roster_base_akademis1` string absent from `student_card.gd`.

- [ ] **Step 3: Read the approval block**

Read `Scripts/StudentCard/student_card.gd:1160-1200`. The relevant lines append `student_data_list[i]` (or slices of it) into `GameState.approved_students`. Identify the single point where the final `approved_students` array is settled (after the `< 2` / `< 3` / else branches).

- [ ] **Step 4: Stamp the keys**

Immediately after `GameState.approved_students` is assigned its final value (and before `initialize_grade_targets` could run — it runs later, in the Lobby), add:

```gdscript
	# Freeze each student's starting skills as the permanent roster baseline.
	# GameState.reset_roster_for_new_grade() rebases toward these every grade;
	# they are never erased. base_akademis* (set later by
	# initialize_grade_targets) is the per-grade cache and IS erased on reset.
	for _s in GameState.approved_students:
		_s["roster_base_akademis1"] = float(_s.get("akademis1", 50.0))
		_s["roster_base_akademis2"] = float(_s.get("akademis2", 50.0))
		_s["roster_base_akademis3"] = float(_s.get("akademis3", 50.0))
```

If `approved_students` entries are references shared with `student_data_list`, this still only adds keys (harmless). If a later screen rebuilds the dicts, the Task 3 fallback re-captures — acceptable.

- [ ] **Step 5: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `roster_reset` and any `student_card` suite.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/StudentCard/student_card.gd tests/test_roster_reset.gd
git commit -m "feat(student-card): stamp permanent roster_base skills on approval

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Weekly per-student minigame-points cap

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` — `record_minigame_result()` (~lines 71-105); add a private helper
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — `start_simulation()` (~line 263)
- Create: `tests/test_minigame_weekly_cap.gd`

**Interfaces:**
- Consumes: `Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7/8/9` (Task 1); `GameState.minigame_gain_this_week` (Task 3).
- Produces: `StudentManager._weekly_minigame_cap() -> float` (private). `record_minigame_result()` now clips each student's winning `stat_delta` so cumulative weekly minigame skill gain per student never exceeds the cap; `deltas["stat_delta"]`, `roster_points`, the stat log and `run_stats` all see the clipped value. Losses untouched.

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_weekly_cap.gd`:

```gdscript
@tool
extends McpTestSuite

## The per-student weekly minigame-points cap: a student can gain at most
## Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_* skill from minigame
## WINS per week. Losses are never capped.

func suite_name() -> String:
	return "minigame_weekly_cap"

func _fresh_manager() -> StudentManager:
	var sm := StudentManager.new()
	sm.students.clear()
	var s := StudentData.new()
	s.id = 1
	s.student_name = "Cap"
	s.akademis = 10.0
	s.specialty_category = "Seimbang"  # 0.85 cost mult, no specialty stat bonus
	sm.students.append(s)
	return sm

func _win(sm: StudentManager) -> void:
	# score 3 / max 4 -> ratio 0.75 -> grade-7 stat = round(5 + 0.75*10) = 13
	sm.record_minigame_result("Sen", "Akademis", "Q", true, 3, 4)

func test_wins_stop_at_the_grade7_cap() -> void:
	var saved_grade := GameState.current_grade
	var saved_gain := GameState.minigame_gain_this_week
	GameState.current_grade = 7
	GameState.minigame_gain_this_week = {}
	var sm := _fresh_manager()

	_win(sm)
	var after1: float = sm.students[0].akademis
	assert_true(after1 <= 10.0 + 14.0 + 0.01, "one win cannot exceed the 14 cap")
	assert_true(after1 >= 10.0 + 12.0, "one ~13-point win should mostly land")

	_win(sm)
	var after2: float = sm.students[0].akademis
	assert_true(is_equal_approx(after2, 24.0),
		"cumulative minigame gain is capped at 14 over base 10, got %s" % str(after2))

	_win(sm)
	assert_true(is_equal_approx(sm.students[0].akademis, 24.0),
		"a third win adds nothing once the weekly cap is reached")

	GameState.current_grade = saved_grade
	GameState.minigame_gain_this_week = saved_gain

func test_losses_are_not_capped() -> void:
	var saved_grade := GameState.current_grade
	var saved_gain := GameState.minigame_gain_this_week
	GameState.current_grade = 7
	GameState.minigame_gain_this_week = {}
	var sm := _fresh_manager()
	sm.students[0].akademis = 24.0
	GameState.minigame_gain_this_week[1] = 14.0  # cap already reached this week

	sm.record_minigame_result("Sen", "Akademis", "Q", false, 0, 4)
	# grade-7 loss = MINIGAME_KALAH_POIN_KELAS_7 = -3, x Seimbang 0.85 mult is
	# applied to costs only, not the stat penalty -> akademis 24 - 3 = 21
	assert_true(is_equal_approx(sm.students[0].akademis, 21.0),
		"a loss still subtracts in full after the win cap is hit, got %s" % str(sm.students[0].akademis))

	GameState.current_grade = saved_grade
	GameState.minigame_gain_this_week = saved_gain

func test_cap_value_is_per_grade() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/StudentManager.gd")
	assert_true(src.contains("MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8"),
		"grade 8 must select its own cap")
	assert_true(src.contains("MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9"),
		"grade 9 must select its own cap")

func test_week_start_clears_the_tracker() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("minigame_gain_this_week"),
		"start_simulation must clear GameState.minigame_gain_this_week each week")
```

> Note on the loss-penalty number: verify against `StudentData.apply_minigame_result` — the specialty multiplier is applied to `energy_change`/`mood_change` only, not `stat_change`, so a Seimbang student's loss is exactly `MINIGAME_KALAH_POIN_KELAS_7`. If a future change scales the stat penalty, update this assertion.

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `minigame_weekly_cap`.
Expected: FAIL — cap not enforced (`after2` ≈ 36, not 24).

- [ ] **Step 3: Add the helper to `StudentManager.gd`**

Near the top of the file (after the `var daily_stat_log` block):

```gdscript
## This grade's per-student weekly minigame-win skill cap.
func _weekly_minigame_cap() -> float:
	match GameState.current_grade:
		8: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8
		9: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9
		_: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7
```

- [ ] **Step 4: Clip inside `record_minigame_result()`**

Inside the `for student in students:` loop, immediately after
`var deltas = student.apply_minigame_result(category, won, score, max_score)`
and before `roster_points += float(deltas.get("stat_delta", 0.0))`:

```gdscript
		var raw_delta: float = float(deltas.get("stat_delta", 0.0))
		if won and raw_delta > 0.0:
			var cap: float = _weekly_minigame_cap()
			var sid: int = student.id
			var already: float = float(GameState.minigame_gain_this_week.get(sid, 0.0))
			var allowed: float = maxf(0.0, cap - already)
			if raw_delta > allowed:
				var overflow: float = raw_delta - allowed
				match category:
					"Akademis":   student.akademis    = clampf(student.akademis    - overflow, 0.0, 100.0)
					"SeniBudaya": student.seni_budaya  = clampf(student.seni_budaya  - overflow, 0.0, 100.0)
					"Olahraga":   student.olahraga     = clampf(student.olahraga     - overflow, 0.0, 100.0)
				deltas["stat_delta"] = allowed
			GameState.minigame_gain_this_week[sid] = already + minf(raw_delta, allowed)
```

The existing lines below (`roster_points += ...`, the `log_stat_change(...)` calls) then use the possibly-updated `deltas`.

- [ ] **Step 5: Clear the tracker at week start**

In `Scripts/SchoolSimulation/SchoolDay.gd`, `start_simulation()`, right after
`minigames_played_this_week = 0` / `events_triggered_this_week = 0`:

```gdscript
	GameState.minigame_gain_this_week.clear()
```

- [ ] **Step 6: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `minigame_weekly_cap`, `school_day`, `run_result`, `semester_end`.
Expected: PASS. If cap logic seems ignored, no-op `script_patch` on `StudentManager.gd`.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_minigame_weekly_cap.gd
git commit -m "feat(school-day): cap weekly minigame skill gain per student

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Wire the roster reset into real progression + debug jumps

**Files:**
- Modify: `Scripts/EndGame/RunResult.gd` — `_apply_progression()` (~lines 197-210)
- Modify: `Scripts/GameState.gd` — `set_grade()` (~lines 83-89)
- Modify: `tests/test_run_result.gd` (source-scan) and `tests/test_roster_reset.gd` (set_grade behaviour)

**Interfaces:**
- Consumes: `GameState.reset_roster_for_new_grade()` (Task 3).
- Produces: the grade-advance branch of `RunResult._apply_progression()` calls `reset_roster_for_new_grade()` instead of its inline mood/energy/base loop. `GameState.set_grade()` calls `reset_roster_for_new_grade()` only when the grade actually changed and a roster exists.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_roster_reset.gd`:

```gdscript
func test_set_grade_resets_roster_only_on_real_change() -> void:
	var saved := GameState.approved_students
	var saved_grade := GameState.current_grade
	GameState.approved_students = [_make_student(1, 50.0, 30.0)]
	GameState.current_grade = 7

	GameState.set_grade(8)
	assert_true(is_equal_approx(float(GameState.approved_students[0]["akademis1"]), 34.0),
		"set_grade(8) from 7 must rebase the roster")

	GameState.approved_students[0]["akademis1"] = 90.0
	GameState.set_grade(8)  # same grade -> no-op
	assert_true(is_equal_approx(float(GameState.approved_students[0]["akademis1"]), 90.0),
		"set_grade to the SAME grade must not re-rebase (no stacked head-start)")

	GameState.approved_students = saved
	GameState.current_grade = saved_grade
```

Add to `tests/test_run_result.gd`:

```gdscript
func test_progression_delegates_roster_reset_to_gamestate() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/EndGame/RunResult.gd")
	assert_true(src.contains("reset_roster_for_new_grade"),
		"the grade-advance branch must call GameState.reset_roster_for_new_grade()")
	assert_false(src.contains("student[\"kepribadian1\"] = 80.0"),
		"the inline mood/energy reset must move into GameState")
```

- [ ] **Step 2: Run to verify they fail**

Run: `test_run` suites `roster_reset`, `run_result`.
Expected: FAIL — `set_grade` no-ops on real change too; `RunResult` still has the inline loop.

- [ ] **Step 3: Edit `RunResult._apply_progression()`**

Replace this block (the `if GameState.current_grade < 9:` branch):

```gdscript
	if GameState.current_grade < 9:
		GameState.current_grade += 1
		for student in GameState.approved_students:
			student["kepribadian1"] = 80.0
			student["kepribadian2"] = 80.0
			student.erase("base_akademis1")
			student.erase("base_akademis2")
			student.erase("base_akademis3")
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.returned_from_student_card = false
		GameState.lobby_tutorial_completed = true
		GameState.run_stats.reset()
		return "res://Scenes/StudentCard/student_card.tscn"
```

with:

```gdscript
	if GameState.current_grade < 9:
		GameState.current_grade += 1
		GameState.reset_roster_for_new_grade()
		GameState.day_schedules.clear()
		GameState.minggu_ke = 1
		GameState.returned_from_student_card = false
		GameState.lobby_tutorial_completed = true
		GameState.run_stats.reset()
		return "res://Scenes/StudentCard/student_card.tscn"
```

Note: `current_grade += 1` runs **before** the reset, matching Task 3's contract (the reset reads `approved_students`, not the grade). The `else` "game beaten" branch is unchanged.

- [ ] **Step 4: Edit `GameState.set_grade()`**

```gdscript
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
```

(`current_grade`'s setter clamps to 7–9, so `previous_grade` is captured before assignment.)

- [ ] **Step 5: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `roster_reset`, `run_result`, `semester_end`, `school_day`.
Expected: PASS. Full `test_run` green except anything from Tasks 7+.

- [ ] **Step 6: Commit**

```bash
git add Scripts/EndGame/RunResult.gd Scripts/GameState.gd tests/test_roster_reset.gd tests/test_run_result.gd
git commit -m "feat(progression): reset roster with head-start on grade advance and debug jump

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Anti-exploit — unpredictable minigame category + randomised weekly allowance

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — field near line 121, `start_simulation()` ~line 265, `_roll_event()` minigame guard ~line 850 and category pick ~lines 889-905
- Modify: `tests/test_school_day.gd`

**Interfaces:**
- Consumes: `Balance.MINIGAME_KATEGORI_ACAK_PELUANG`, `Balance.MINIGAME_MAKS_MINGGU_MIN`, `Balance.MINIGAME_MAKS_MINGGU_MAX` (Task 1).
- Produces: `SchoolDay.max_minigames_this_week: int` — rolled once per week. The minigame-count guard and the category pick now read Balance, not literals.

- [ ] **Step 1: Write the failing source-scan tests**

Add to `tests/test_school_day.gd`:

```gdscript
func test_weekly_minigame_count_is_randomised() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("max_minigames_this_week"),
		"SchoolDay must track a per-week max minigame count")
	assert_true(src.contains("randi_range(Balance.MINIGAME_MAKS_MINGGU_MIN, Balance.MINIGAME_MAKS_MINGGU_MAX)"),
		"the per-week minigame count must be rolled from Balance each week")
	assert_false(src.contains("minigames_played_this_week < 2"),
		"the hardcoded < 2 minigame guard must be gone")

func test_minigame_category_has_uniform_noise() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("Balance.MINIGAME_KATEGORI_ACAK_PELUANG"),
		"the minigame category pick must branch on the uniform-noise chance")
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `school_day`.
Expected: FAIL — `max_minigames_this_week` absent, `< 2` still present, no noise branch.

- [ ] **Step 3: Add the per-week field**

Next to `var max_events_this_week: int = 2` (~line 121):

```gdscript
## Rolled once per week from Balance.MINIGAME_MAKS_MINGGU_MIN..MAX. The player
## cannot bank on a fixed number of minigames -- see the anti-exploit spec.
var max_minigames_this_week: int = 2
```

- [ ] **Step 4: Roll it each week**

In `start_simulation()`, next to `max_events_this_week = randi_range(1, 2)`:

```gdscript
	max_minigames_this_week = randi_range(Balance.MINIGAME_MAKS_MINGGU_MIN, Balance.MINIGAME_MAKS_MINGGU_MAX)
```

- [ ] **Step 5: Use it in the guard**

In `_roll_event()`, change:

```gdscript
	if minigames_played_this_week < 2:
		w_minigame = active_studying * 15
```

to:

```gdscript
	if minigames_played_this_week < max_minigames_this_week:
		w_minigame = active_studying * 15
```

- [ ] **Step 6: Add category noise**

In `_roll_event()`, the `elif outcome == "Minigame":` branch, the code currently computes `category_selected` from `total_subject_weight`. Wrap that in the noise branch:

```gdscript
		var category_selected = ""
		if randf() < Balance.MINIGAME_KATEGORI_ACAK_PELUANG:
			var r := randi() % 3
			category_selected = "Akademis" if r == 0 else ("Olahraga" if r == 1 else "SeniBudaya")
		else:
			var total_subject_weight = w_akademis + w_olahraga + w_seni
			if total_subject_weight == 0:
				var cat_roll = randi() % 3
				if cat_roll == 0: category_selected = "Akademis"
				elif cat_roll == 1: category_selected = "Olahraga"
				else: category_selected = "SeniBudaya"
			else:
				var choice = randi() % total_subject_weight
				if choice < w_akademis:
					category_selected = "Akademis"
				elif choice < w_akademis + w_olahraga:
					category_selected = "Olahraga"
				else:
					category_selected = "SeniBudaya"
```

Keep everything below (the `if category_selected == "Akademis":` scene-selection and `_play_minigame` calls) exactly as it is. Remove the now-duplicated old `var total_subject_weight` / `var category_selected` lines that preceded this block.

- [ ] **Step 7: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `school_day`, `balance`.
Expected: PASS. Full `test_run` green.

- [ ] **Step 8: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_school_day.gd
git commit -m "feat(school-day): randomise minigame category and weekly count to close the farm exploit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: `ActivityPreview.is_specialty()` + AudioDirector cue

**Files:**
- Modify: `Scripts/AturJadwal/ActivityPreview.gd` (after `_specialty_of`, ~line 24)
- Modify: `Scripts/Audio/AudioDirector.gd` — new `@export`, new `match` arm (~line 235), header doc list
- Modify: the AudioDirector autoload scene (assign `sfx_specialty_match` = same stream as `sfx_reward`) — **through the editor**
- Modify: `tests/test_audio_coverage.gd` if it enumerates cues; add a scan to a new suite otherwise (Task 12 owns the combined AturJadwal test suite — put the audio scan there)

**Interfaces:**
- Produces:
  - `ActivityPreview.is_specialty(category: String, student: Dictionary) -> bool` (static).
  - `AudioDirector` cue `&"specialty_match"` → `sfx_specialty_match` (placeholder alias of `sfx_reward`).

- [ ] **Step 1: Write the failing test**

Create `tests/test_atur_jadwal_specialty_feedback.gd` (Task 12 extends it):

```gdscript
@tool
extends McpTestSuite

## AturJadwal specialty feedback: is_specialty() truth table, the SFX cue,
## the particle scene, the sticky-note matched state, the picker badge, and
## the atur_jadwal wiring. Source-scan + light-instantiate, matching this
## project's established AturJadwal test style.

func suite_name() -> String:
	return "atur_jadwal_specialty_feedback"

func test_is_specialty_truth_table() -> void:
	var marcel := {"hobby_category": "Akademis"}
	assert_true(ActivityPreview.is_specialty("Akademis", marcel))
	assert_false(ActivityPreview.is_specialty("Olahraga", marcel))
	var ui_spelling := {"hobby_category": "Akademik"}
	assert_true(ActivityPreview.is_specialty("Akademis", ui_spelling),
		"the UI spelling 'Akademik' must normalize to 'Akademis'")
	assert_false(ActivityPreview.is_specialty("Akademis", {}),
		"a student with no hobby_category has no specialty")

func test_specialty_match_cue_registered() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Audio/AudioDirector.gd")
	assert_true(src.contains("sfx_specialty_match"), "AudioDirector needs the sfx_specialty_match export")
	assert_true(src.contains("&\"specialty_match\": return sfx_specialty_match"),
		"the &\"specialty_match\" cue must map to sfx_specialty_match")
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `atur_jadwal_specialty_feedback`.
Expected: FAIL — `is_specialty` not defined, cue absent.

- [ ] **Step 3: Add `is_specialty()`**

In `Scripts/AturJadwal/ActivityPreview.gd`, after `_specialty_of()`:

```gdscript
## True when `category` is this student's normalized specialty. The one place
## any screen should ask "does this activity play to the student's strength" --
## the raw hobby_category spelling ("Akademik") is a trap.
static func is_specialty(category: String, student: Dictionary) -> bool:
	return _specialty_of(student) == category
```

- [ ] **Step 4: Add the AudioDirector cue**

In `Scripts/Audio/AudioDirector.gd`:

- Near the other `@export var sfx_*` declarations:

```gdscript
## Dimainkan saat pemain menjadwalkan murid ke mapel favoritnya di Atur
## Jadwal. PLACEHOLDER: alias sfx_reward sampai ada aset sendiri.
@export var sfx_specialty_match: AudioStream
```

- In the `_stream_for()` `match` block, next to `&"reward": return sfx_reward`:

```gdscript
		&"specialty_match": return sfx_specialty_match
```

- In the file-header `## play_sfx(...)` list, add a line:

```gdscript
## `play_sfx(&"specialty_match")`: AturJadwal, a day is assigned to the
## selected student's specialty subject. Placeholder: aliases sfx_reward.
```

- [ ] **Step 5: Assign the stream in the editor**

Via Godot AI MCP: `scene_open` the AudioDirector autoload scene (path from `project.godot` `[autoload] AudioDirector`), `node_set_property` on the root to set `sfx_specialty_match` to the **same `AudioStream` resource** currently in `sfx_reward` (read it with `node_get_properties` first), `scene_save`. If AudioDirector is a script-only autoload with no scene, set the export default in the script to `preload(...)` the same path `sfx_reward` uses.

- [ ] **Step 6: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `atur_jadwal_specialty_feedback`, `audio_coverage`, `project_hygiene`, `script_documentation`.
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Scripts/AturJadwal/ActivityPreview.gd Scripts/Audio/AudioDirector.gd tests/test_atur_jadwal_specialty_feedback.gd
git commit -m "feat(atur-jadwal): add ActivityPreview.is_specialty and the specialty_match SFX cue

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: `SpecialtyMatchBurst` particle scene

**Files:**
- Create: `Scripts/AturJadwal/SpecialtyMatchBurst.gd`
- Create: `Scenes/AturJadwal/SpecialtyMatchBurst.tscn` — **through the editor**
- Modify: `tests/test_atur_jadwal_specialty_feedback.gd`

**Interfaces:**
- Produces: `SpecialtyMatchBurst` (`class_name`), root `CPUParticles2D`, `one_shot = true`, method `play() -> void` (emits, then self-frees via a `SceneTreeTimer` — no `await` in `play()` itself). Exports: `burst_amount: int`, `spread_px: float`, `life_seconds: float`, `burst_color: Color`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_atur_jadwal_specialty_feedback.gd`:

```gdscript
func test_specialty_burst_scene_shape() -> void:
	var packed := load("res://Scenes/AturJadwal/SpecialtyMatchBurst.tscn") as PackedScene
	assert_true(packed != null, "SpecialtyMatchBurst.tscn must exist")
	var inst := packed.instantiate()
	assert_true(inst is CPUParticles2D, "root must be CPUParticles2D")
	assert_true(inst.one_shot, "the burst must be one_shot")
	assert_true(inst.has_method("play"), "the burst must expose play()")
	inst.free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `atur_jadwal_specialty_feedback`.
Expected: FAIL — scene missing.

- [ ] **Step 3: Write the script**

`Scripts/AturJadwal/SpecialtyMatchBurst.gd`:

```gdscript
@tool
class_name SpecialtyMatchBurst
extends CPUParticles2D

## A one-shot gold star burst fired on the AturJadwal sticky note when the
## player schedules a student onto their specialty subject. Authored scene
## (Scenes/AturJadwal/SpecialtyMatchBurst.tscn), driven entirely by the
## @export knobs below -- no runtime visual construction. play() is a no-op
## in the editor; it never awaits, it schedules its own free with a timer.

## Jumlah partikel bintang saat murid dijadwalkan ke mapel favoritnya.
@export var burst_amount: int = 14
## Radius sebaran partikel dari titik tengah note, dalam piksel.
@export var spread_px: float = 46.0
## Umur tiap partikel, dalam detik.
@export var life_seconds: float = 0.7
## Warna partikel. Kosong (default) = emas dari DesignTokens.currency_gold.
@export var burst_color: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	emitting = false
	one_shot = true
	if burst_color.a == 0.0:
		burst_color = DesignTokens.load_default().currency_gold


## Fire the burst once, then free self after the particles finish.
func play() -> void:
	if Engine.is_editor_hint():
		return
	amount = maxi(1, burst_amount)
	lifetime = life_seconds
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = spread_px
	color = burst_color
	restart()
	emitting = true
	get_tree().create_timer(life_seconds + 0.3).timeout.connect(queue_free)
```

- [ ] **Step 4: Build the scene in the editor**

Via Godot AI MCP `batch_execute` / `node_create` on a new scene:
- Root node type `CPUParticles2D`, name `SpecialtyMatchBurst`, attach `res://Scripts/AturJadwal/SpecialtyMatchBurst.gd`.
- Set `texture` = `res://Assets/Images/Particles/particle_star.png`.
- Set `one_shot = true`, `emitting = false`, `explosiveness = 1.0`, `amount = 14`, `lifetime = 0.7`.
- Set `direction = Vector2(0, -1)`, `spread = 180.0`, `initial_velocity_min = 120.0`, `initial_velocity_max = 240.0`, `gravity = Vector2(0, 300)`, `scale_amount_min = 0.4`, `scale_amount_max = 0.9`.
- `scene_save` to `res://Scenes/AturJadwal/SpecialtyMatchBurst.tscn`.

- [ ] **Step 5: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `atur_jadwal_specialty_feedback`, `viewport_editability`, `script_documentation`.
Expected: PASS. `viewport_editability` stays green — this is an authored template, not runtime construction.

- [ ] **Step 6: Commit**

```bash
git add Scripts/AturJadwal/SpecialtyMatchBurst.gd Scenes/AturJadwal/SpecialtyMatchBurst.tscn tests/test_atur_jadwal_specialty_feedback.gd
git commit -m "feat(atur-jadwal): add the SpecialtyMatchBurst particle scene

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: `DayStickyNote` matched-state visuals

**Files:**
- Modify: `Scripts/AturJadwal/DayStickyNote.gd`
- Modify: `Scenes/AturJadwal/DayStickyNote.tscn` — **through the editor** (add `MatchGlow`, `SpecialtyStar` under `$Paper`)
- Modify: `tests/test_atur_jadwal_specialty_feedback.gd`

**Interfaces:**
- Consumes: `Scenes/AturJadwal/SpecialtyMatchBurst.tscn` (Task 9).
- Produces: `DayStickyNote.play_specialty_match() -> void` — runs `play_assign_pop()`, shows the two matched-state child nodes with a glow pulse, and instances one burst at the note centre. Every repaint (`show_empty` / `show_scheduled` / `show_holiday` via `_apply()`) hides both nodes.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_atur_jadwal_specialty_feedback.gd`:

```gdscript
func test_sticky_note_has_matched_state_api() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/DayStickyNote.gd")
	assert_true(src.contains("func play_specialty_match"), "DayStickyNote needs play_specialty_match()")
	assert_true(src.contains("play_assign_pop()"), "play_specialty_match must reuse play_assign_pop()")
	assert_true(src.contains("specialty_match_burst_scene"), "the burst scene must be an @export")
	assert_true(src.contains("_match_glow") and src.contains("_specialty_star"),
		"both matched-state child nodes must be referenced")

func test_sticky_note_scene_has_matched_nodes() -> void:
	var packed := load("res://Scenes/AturJadwal/DayStickyNote.tscn") as PackedScene
	var inst := packed.instantiate()
	assert_true(inst.get_node_or_null("Paper/MatchGlow") != null, "MatchGlow node must exist")
	assert_true(inst.get_node_or_null("Paper/SpecialtyStar") != null, "SpecialtyStar node must exist")
	inst.free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `atur_jadwal_specialty_feedback`.
Expected: FAIL — method and nodes missing.

- [ ] **Step 3: Add the child nodes in the editor**

Via Godot AI MCP on `Scenes/AturJadwal/DayStickyNote.tscn`:
- Under `Paper`: `TextureRect` named `MatchGlow`, `texture` = `res://Assets/Images/Particles/particle_glow.png`, all four anchors centred / full-rect behind the labels, `mouse_filter = 2` (IGNORE), `visible = false`. Move it below the labels in the tree so it draws behind them (`move_node`).
- Under `Paper`: `TextureRect` named `SpecialtyStar`, `texture` = `res://Assets/Images/Particles/particle_star.png`, small (`custom_minimum_size = Vector2(40, 40)`), top-left corner, `mouse_filter = 2`, `visible = false`.
- `scene_save`.

- [ ] **Step 4: Edit `DayStickyNote.gd`**

- Add `@onready` refs next to the existing ones:

```gdscript
@onready var _match_glow: TextureRect = $Paper/MatchGlow
@onready var _specialty_star: TextureRect = $Paper/SpecialtyStar
```

- Add the export next to `category_icons`:

```gdscript
## Partikel yang muncul saat hari ini cocok dengan mapel favorit murid.
## @export agar tim visual bisa mengganti per instance di Inspector.
@export var specialty_match_burst_scene: PackedScene = preload("res://Scenes/AturJadwal/SpecialtyMatchBurst.tscn")
```

- In `_apply()`, after the existing visibility lines, add:

```gdscript
	# A repaint always clears the specialty-match decoration; play_specialty_match()
	# re-adds it for the one note the player just assigned.
	if _match_glow:
		_match_glow.visible = false
	if _specialty_star:
		_specialty_star.visible = false
```

- Add the method at the end of the file:

```gdscript
## Plays the specialty-match reaction on top of the normal assign-pop: a gold
## particle burst from the note centre, a glow pulse, and a persistent star.
## No-op in the editor. atur_jadwal.gd calls this INSTEAD OF play_assign_pop()
## when the assigned activity is the selected student's specialty.
func play_specialty_match() -> void:
	play_assign_pop()
	if _specialty_star:
		_specialty_star.visible = true
	if _match_glow:
		_match_glow.visible = true
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if _match_glow:
		_match_glow.modulate.a = 0.0
		var t := _get_tokens()
		var glow_tw := create_tween()
		glow_tw.tween_property(_match_glow, "modulate:a", 0.55, t.dur_fast)
		glow_tw.tween_property(_match_glow, "modulate:a", 0.30, t.dur_normal)
	if specialty_match_burst_scene:
		var burst := specialty_match_burst_scene.instantiate()
		add_child(burst)
		burst.position = size / 2.0
		if burst.has_method("play"):
			burst.play()
```

- [ ] **Step 5: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `atur_jadwal_specialty_feedback`, `atur_jadwal` (if present), `viewport_editability`, `script_documentation`.
Expected: PASS. If `specialty_match_burst_scene` is invisible to the editor, no-op `script_patch` on `DayStickyNote.gd`.

- [ ] **Step 6: Commit**

```bash
git add Scripts/AturJadwal/DayStickyNote.gd Scenes/AturJadwal/DayStickyNote.tscn tests/test_atur_jadwal_specialty_feedback.gd
git commit -m "feat(atur-jadwal): sticky note reacts when a day matches the student's specialty

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: Wire the specialty feedback into `atur_jadwal.gd` + `ActivityRow` badge

**Files:**
- Modify: `Scripts/AturJadwal/atur_jadwal.gd` — `_on_activity_selected()` (~lines 979-999)
- Modify: `Scripts/AturJadwal/ActivityRow.gd` — end of `refresh()`
- Modify: `Scenes/AturJadwal/ActivityRow.tscn` — **through the editor** (add `SpecialtyBadge` under `Container`)
- Modify: `tests/test_atur_jadwal_specialty_feedback.gd`

**Interfaces:**
- Consumes: `ActivityPreview.is_specialty()` (Task 8), `DayStickyNote.play_specialty_match()` (Task 10), cue `&"specialty_match"` (Task 8).
- Produces: on a specialty assignment the note plays `play_specialty_match()` and `&"specialty_match"` plays *instead of* `&"select"`; the picker row shows a `SpecialtyBadge` for the selected student's specialty.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_atur_jadwal_specialty_feedback.gd`:

```gdscript
func test_atur_jadwal_calls_specialty_feedback() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
	assert_true(src.contains("ActivityPreview.is_specialty("),
		"_on_activity_selected must check ActivityPreview.is_specialty")
	assert_true(src.contains("play_specialty_match()"),
		"_on_activity_selected must call play_specialty_match on a match")
	assert_true(src.contains("&\"specialty_match\""),
		"_on_activity_selected must play the specialty_match cue on a match")

func test_activity_row_toggles_specialty_badge() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/ActivityRow.gd")
	assert_true(src.contains("SpecialtyBadge") and src.contains("ActivityPreview.is_specialty"),
		"ActivityRow.refresh must toggle SpecialtyBadge via ActivityPreview.is_specialty")
	var packed := load("res://Scenes/AturJadwal/ActivityRow.tscn") as PackedScene
	var inst := packed.instantiate()
	assert_true(inst.get_node_or_null("Container/SpecialtyBadge") != null,
		"ActivityRow.tscn must contain Container/SpecialtyBadge")
	inst.free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `test_run` suite `atur_jadwal_specialty_feedback`.
Expected: FAIL.

- [ ] **Step 3: Edit `_on_activity_selected()`**

Read `Scripts/AturJadwal/atur_jadwal.gd:979-999`. It currently unconditionally calls `AudioDirector.play_sfx(&"select")` (line ~980) and later, in the `if _assigned_note:` block (~997-999), calls `_assigned_note.play_assign_pop()`. Restructure so exactly one animation and one cue fire:

- Remove the unconditional `AudioDirector.play_sfx(&"select")` at line ~980.
- Replace the `if _assigned_note:` / `play_assign_pop()` block with:

```gdscript
	var _assigned_note := _get_day_button(GameState.selected_day) as DayStickyNote
	if _assigned_note:
		if ActivityPreview.is_specialty(category, GameState.selected_student):
			_assigned_note.play_specialty_match()
			AudioDirector.play_sfx(&"specialty_match")
		else:
			_assigned_note.play_assign_pop()
			AudioDirector.play_sfx(&"select")
```

Confirm `GameState.selected_student` holds the student whose day was just assigned at this point in the function (it is set when the player picks a student; the popup assigns for that student). If the function instead iterates a `student_id` local, pass the matching dict from `GameState.approved_students` into `is_specialty` instead.

- [ ] **Step 4: Add the badge node in the editor**

Via Godot AI MCP on `Scenes/AturJadwal/ActivityRow.tscn`:
- Under `Container`: `TextureRect` named `SpecialtyBadge`, `texture` = `res://Assets/Images/Particles/particle_star.png` (or a dedicated `res://Assets/Images/UI/Placeholders/icon_specialty_star.svg` if you add one), top-right of the container, `custom_minimum_size = Vector2(44, 44)`, `mouse_filter = 2`, `visible = false`.
- `scene_save`.

- [ ] **Step 5: Toggle it in `ActivityRow.refresh()`**

At the end of `func refresh(student: Dictionary, grade: int, progress_percent: float) -> void:`:

```gdscript
	var badge := get_node_or_null("Container/SpecialtyBadge") as TextureRect
	if badge:
		badge.visible = ActivityPreview.is_specialty(category, student)
```

- [ ] **Step 6: Rescan and run**

Run: `filesystem_manage(op="scan")` then `test_run` suites `atur_jadwal_specialty_feedback`, `atur_jadwal` (if present), `audio_coverage`, `viewport_editability`, `script_documentation`, `project_hygiene`.
Expected: PASS.

- [ ] **Step 7: MCP visual confirm**

Seed Playtest State → Scenes tab → AturJadwal. Select a student, open the picker (confirm the ★ badge sits on their specialty row), assign that day to the specialty subject. Confirm: burst fires on the note, glow + star persist, `specialty_match` SFX plays. `editor_screenshot`. Assign a non-specialty day and confirm the plain pop + `select` SFX, and that the earlier note's star cleared when it repainted.

- [ ] **Step 8: Commit**

```bash
git add Scripts/AturJadwal/atur_jadwal.gd Scripts/AturJadwal/ActivityRow.gd Scenes/AturJadwal/ActivityRow.tscn tests/test_atur_jadwal_specialty_feedback.gd
git commit -m "feat(atur-jadwal): fire specialty burst/SFX on assign and badge the picker row

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 12: `test_balance_pacing.gd` — headless greedy pacing sim

**Files:**
- Create: `tests/test_balance_pacing.gd`

**Interfaces:**
- Consumes: `GameState`, `StudentManager`, `StudentData`, `Balance`, `GameState.reset_roster_for_new_grade()`, `GameState.check_semester_passed()`, `GameState.minigame_gain_this_week`.
- Produces: nothing consumed downstream. This is the verification harness and the tuning loop for §4/§3/§7 numbers.

- [ ] **Step 1: Write the harness + assertions**

Create `tests/test_balance_pacing.gd`. Structure (fill every helper — no stubs):

```gdscript
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

# The real roster values, hard-copied from student_card.gd so a roster edit
# does not silently move the goalposts. Keys use the UI spelling.
const ROSTER := [
	{"id": 1, "name": "Marcel", "hobby_category": "Akademis", "personality": "Tekun",
	 "quirk": "Kutu Buku", "akademis1": 28.0, "akademis2": 48.0, "akademis3": 38.0,
	 "kepribadian1": 60.0, "kepribadian2": 55.0},
	{"id": 2, "name": "Doni", "hobby_category": "Olahraga", "personality": "Aktif",
	 "quirk": "Semangat Juang", "akademis1": 38.0, "akademis2": 22.0, "akademis3": 33.0,
	 "kepribadian1": 55.0, "kepribadian2": 55.0},
	# ... include all four roster students; read student_card.gd:896-1030 for
	# the remaining two and their exact akademis1/2/3, personality, quirk,
	# hobby_category, kepribadian1/2.
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
```

- [ ] **Step 2: Fill the roster constant**

Read `Scripts/StudentCard/student_card.gd:896-1035` and complete `ROSTER` with all four students' exact `akademis1/2/3`, `kepribadian1/2`, `personality`, `quirk`, `hobby_category`.

- [ ] **Step 3: Run**

Run: `filesystem_manage(op="scan")` then `test_run` suite `balance_pacing`.
Expected: some assertions may FAIL on the first run — that is the signal to tune. If grade 9 never clears by week 14, lower `TARGET_KENAIKAN_KELAS_9` in `Balance.gd` (and `test_balance.gd` `_EXPECTED`) by 2–4 and re-run. If grade 7 clears in week 1, lower `MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7` by 2 and re-run. Iterate until green.

- [ ] **Step 4: Reconcile any tuned numbers**

If Step 3 changed any `Balance` value: update `tests/test_balance.gd` `_EXPECTED` to match (count literal unchanged — values only), re-run suites `balance` and `balance_pacing`, and record each moved number in the spec's Status block (§7.3).

- [ ] **Step 5: Full suite**

Run: `test_run` (all), `main_menu.tscn` open.
Expected: 48+ suites green.

- [ ] **Step 6: Commit**

```bash
git add tests/test_balance_pacing.gd Scripts/Balance.gd tests/test_balance.gd docs/superpowers/specs/2026-09-04-grade-progression-balance-and-difficulty.md
git commit -m "test(balance): add headless pacing sim and tune grade targets to its windows

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 13: Manual MCP playthrough verification + spec status close-out

**Files:**
- Modify: `docs/superpowers/specs/2026-09-04-grade-progression-balance-and-difficulty.md` (Status block)
- Modify: `CLAUDE.md` "Current work" section (add a one-paragraph entry)

**Interfaces:** none — verification + documentation only.

- [ ] **Step 1: Grade 7 full playthrough**

Godot AI MCP: `DebugManager` → ⚡ Seed Playtest State → Scenes → AturJadwal. Play all 6 weeks of grade 7 with sensible specialty-first scheduling (seed does not fill `day_schedules`, so pass through Atur Jadwal each week). After each week read ResultCheckup. Confirm: targets clear around week 3–4, **not** week 1; energy management matters; the specialty burst/SFX fires on matching assignments.

- [ ] **Step 2: Grade boundary reset check**

At grade-7 clear, proceed through RunResult. Confirm on the next StudentCard/Lobby that each student's three skills rebased toward roster base (not carried at grade-7-end values), mood/energy show 80, and new targets = new base + 34. Then via DebugManager jump to grade 9 and confirm the same reset happened (skills rebased, not the grade-8 values).

- [ ] **Step 3: Grades 8 & 9 first 3 weeks**

Seed, jump to grade 8, play weeks 1–3, and compare the per-week skill deltas to `test_balance_pacing.gd`'s figures for those weeks (read the sim's intermediate values by adding a temporary `print` if needed, then remove it). Repeat for grade 9. Confirm the minigame category is not always the stacked subject (play a stacked week, observe 2–3 assignments, confirm at least one off-subject minigame appears across a few weeks) and that the weekly minigame count is not always 2.

- [ ] **Step 4: Update the spec Status block**

Change "balance-pass estimates" to "verified by `test_balance_pacing.gd` seed sweep on 2026-09-04 + manual grade-7 playthrough", and list any number that moved during Task 12 tuning with its final value.

- [ ] **Step 5: Add the CLAUDE.md "Current work" entry**

One paragraph under "Current work": what landed (roster reset + head-start, weekly minigame cap 14/12/10, grade 8/9 targets 34/50, skip risk ramp, quirk amplification, AturJadwal specialty feedback, minigame category/allowance randomisation), the spec/plan paths, and any outstanding placeholder (the `sfx_specialty_match` alias, the star/glow particle sprites if still placeholder).

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-09-04-grade-progression-balance-and-difficulty.md CLAUDE.md
git commit -m "docs(balance): record the grade-progression difficulty pass and close verification

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-review

**Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §1 Architecture | all |
| §2 Roster reset + head-start | 3 (function), 4 (roster_base capture), 6 (call sites) |
| §3 Weekly minigame-points cap | 1 (consts), 3 (`minigame_gain_this_week`), 5 (clip logic + week clear) |
| §4 Balance numbers | 1 (all fields), 2 (SchoolDay call sites) |
| §5 Base testing | every task rescans + runs; 12 Step 5 full-suite gate |
| §6 AturJadwal specialty feedback | 8 (`is_specialty` + cue), 9 (burst scene), 10 (sticky note), 11 (wiring + picker badge) |
| §7 Beatability verification | 12 (sim harness + tuning), 13 (manual playthrough + status close-out) |
| §8 Anti-exploit randomisation | 1 (consts), 7 (category noise + weekly count) |

**Placeholder scan:** no "TBD"/"handle edge cases"/"similar to Task N". Task 12's `ROSTER` const and Task 11's `GameState.selected_student` check are explicitly flagged as "read these exact lines and fill/confirm" steps, not hand-waves. Every code step carries the actual code.

**Type consistency:** `reset_roster_for_new_grade()`, `minigame_gain_this_week` (Dictionary `int->float`), `_weekly_minigame_cap() -> float`, `is_specialty(category, student) -> bool`, `play_specialty_match()`, `SpecialtyMatchBurst.play()`, cue `&"specialty_match"`, `max_minigames_this_week` — each defined once and consumed under the same name/signature everywhere it appears. `roster_base_akademis1/2/3` and `base_akademis1/2/3` are used consistently (permanent vs per-grade cache). Grade-target constant names (`TARGET_KENAIKAN_KELAS_8/9`) match `test_balance.gd` and `initialize_grade_targets()`.

**Known follow-ups (not blockers):** `sfx_specialty_match` and any still-flat particle sprite stay placeholder-aliased, consistent with the project's convention; noted in Task 13 Step 5.
