# Atur Jadwal Balance Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Exception to the usual recommendation:** all test verification in this
> plan runs through the `godot-ai` MCP `test_run` tool, which drives a
> single live Godot editor session. That bridge is single-client (see
> CLAUDE.md "The Godot MCP bridge is single-client") — a dispatched
> subagent that tries to connect will **displace** whichever session
> currently holds it, and neither session ends up with a working
> connection. If executing via subagent-driven-development, the
> orchestrating session (not the per-task subagent) must run every
> `test_run` / `filesystem_manage` call and report results back into the
> task; subagents should write code only.

**Goal:** Make `Scripts/AturJadwal/atur_jadwal.gd`'s weekly-schedule preview
(study-gain stat bars, mood/energy cost badges) read from `Balance.gd`
instead of its own untouched local copy, closing the gap the
balance-tuning-tools review found and flagged in `Balance.gd`'s header.

**Architecture:** Extract the grade-aware study-gain lookup that already
exists twice (once inline in `StudentManager.apply_daily_decay_all`, once
as `SchoolDay._preview_gain`) into one static helper on `StudentManager`,
so `atur_jadwal.gd` becomes a third caller instead of a third copy. Then
point every other local constant in `atur_jadwal.gd` directly at the
matching `Balance.gd` field. Purely behavior-preserving for Grade 7 (today's
shipped numbers); Grades 8/9 and the Libur-mood/Wirausaha ranges become
correct for the first time, which is the deliberate, expected effect.

**Tech Stack:** Godot 4 / GDScript. Tests run via the `godot-ai` MCP
`test_run` tool against `tests/test_*.gd` suites (`McpTestSuite`), inside
the live editor — not headless.

**Spec:** This plan's spec is the task brief given at kickoff (no separate
spec doc was written — the brief itself, reproduced in context below, plus
`docs/superpowers/specs/2026-08-28-balance-tuning-tools-design.md` for the
original Balance.gd extraction this continues).

## Global Constraints

- **Behavior-preserving for Grade 7.** Every value `atur_jadwal.gd` shows
  today for a Grade 7 roster must be bit-for-bit identical after this plan.
  Grade 7 is the only grade where the stale local consts happened to match
  `Balance.gd`'s Grade-7 fields exactly (`BASE_GAIN=3.0` ==
  `BELAJAR_POIN_KELAS_7`, `HOBBY_BONUS_GAIN=6.0` ==
  `BELAJAR_POIN_KELAS_7 + BELAJAR_BONUS_FAVORIT_KELAS_7`, `MOOD_LOSS_MIN/MAX`
  == `BELAJAR_BIAYA_MOOD_MIN/MAX`, `ENERGY_LOSS_MIN/MAX` ==
  `BELAJAR_BIAYA_ENERGI_MIN/MAX`, `DAYOFF_GAIN_MIN/MAX` ==
  `LIBUR_ENERGI_PULIH_MIN/MAX`). Confirmed by direct comparison against
  `Scripts/Balance.gd` before writing this plan.
- **Grades 8/9 and the Libur-mood/Wirausaha display are expected to
  change.** Today they show the flat Grade-7-shaped numbers regardless of
  grade (silently wrong for 8/9), and the wrong range for Libur mood
  recovery and Wirausaha cost (silently wrong for every grade). After this
  plan they show the real numbers the simulation will apply. This is the
  fix, not a regression.
- **No behavior change to the simulation itself
  (`StudentManager.apply_daily_decay_all`, `StudentData.apply_jadwal_activity`).**
  Only the two preview screens (`SchoolDay.gd`'s day badges, `atur_jadwal.gd`'s
  stat bars) are touched.
- **Godot MCP is single-client.** Only the orchestrating session runs
  `test_run` / `filesystem_manage`. See the note under "For agentic
  workers" above.
- **Rescan before every test run.** After any `.gd` edit, call
  `filesystem_manage(op="scan")` before `test_run` — the runner otherwise
  serves a stale script (CLAUDE.md, "Rescan after editing a `.gd`").
- **Baseline, confirmed by running `test_run` with no `suite` filter before
  this plan was written:** 307 tests across 25 suites, 306 passed, 1 failed
  — `test_audio_director.gd::test_volumes_persist_across_a_fresh_director`,
  a documented pre-existing coroutine bug (CLAUDE.md "Known issues" #1,
  reports "0 assertions"). This failure is **not** in scope; it must still
  be the only failure after this plan (307 + however many tests this plan
  adds, all passing except that one).
- **GDScript conventions in this codebase:** tabs for indentation; `static var`
  fields on `Balance` are read as `Balance.FIELD_NAME` directly (no
  instantiation); a mood/energy cost of type `int` needs `roundi(...)`
  around a `Balance` float field before passing it to `randi_range()`
  (which is `(int, int) -> int`).
- **Test style, per file:**
  - `tests/test_atur_jadwal.gd` and `tests/test_school_day.gd` cover
    non-`@tool` scene scripts. Their own header comments record that
    `_ready()` never runs when the runner instantiates these scenes, so
    every assertion there reads **scene-declared state or script source
    text** (`FileAccess.get_file_as_string(...).contains(...)`), never
    state built by calling an instance method at runtime. Follow this
    exactly — do not add a test that calls `_screen._compute_pending_gain(...)`
    or similar.
  - A new **static** function on `StudentManager` (no instantiation
    required) is not subject to that restriction — it can and should be
    called directly in a test for a real behavioral assertion, the same
    way `tests/test_balance.gd` calls `Balance.new().get(field_name)`.
  - Float comparisons follow `tests/test_balance.gd`'s pattern:
    `assert_true(is_equal_approx(actual, expected), msg)`, not `assert_eq`
    on raw floats.

---

## Task 1: Shared grade-aware study-gain helper

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` (add static helper)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:534-549` (`_preview_gain`,
  delegate instead of duplicating the lookup)
- Test: `tests/test_school_day.gd` (new test methods, appended before the
  closing helper section)

**Interfaces:**
- Produces: `StudentManager.study_preview_gain(grade: int, is_specialty: bool) -> float`
  — static, callable without instantiating `StudentManager`. Returns the
  base study-gain for `grade` (falling back to
  `Balance.BELAJAR_POIN_CADANGAN` for any grade not in {7, 8, 9}), plus
  `Balance.BELAJAR_BONUS_FAVORIT_KELAS_<grade>` (or `_CADANGAN`) when
  `is_specialty` is true. Task 2 consumes this exact signature.

- [ ] **Step 1: Read current `_preview_gain` and confirm the exact text to replace**

`Scripts/SchoolSimulation/SchoolDay.gd:531-549` currently reads:

```gdscript
## The preview badge must quote the same gain the simulation will apply,
## or a tester changing Balance.gd sees the old number here and thinks
## nothing happened. Mirrors StudentManager.apply_daily_decay_all.
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

Run: `Grep` for `func _preview_gain` in `Scripts/SchoolSimulation/SchoolDay.gd`
to confirm the line range hasn't drifted since this plan was written.
Expected: matches the block above.

- [ ] **Step 2: Add the static helper to `StudentManager.gd`**

Insert immediately after the existing top-of-file comment (currently line 4,
`# Wirausaha balance numbers now live in Scripts/Balance.gd.`) in
`Scripts/SchoolSimulation/StudentManager.gd`:

```gdscript
## Study-gain preview for a given grade and specialty match. The base/bonus
## table mirrors apply_daily_decay_all()'s own grade lookup below; shared
## here so every preview screen (SchoolDay's day badges, Atur Jadwal's stat
## bars) quotes the same number the simulation will actually award instead
## of keeping its own copy of this table.
static func study_preview_gain(grade: int, is_specialty: bool) -> float:
	var base := Balance.BELAJAR_POIN_CADANGAN
	var bonus := Balance.BELAJAR_BONUS_FAVORIT_CADANGAN
	match grade:
		7:
			base = Balance.BELAJAR_POIN_KELAS_7
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_7
		8:
			base = Balance.BELAJAR_POIN_KELAS_8
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_8
		9:
			base = Balance.BELAJAR_POIN_KELAS_9
			bonus = Balance.BELAJAR_BONUS_FAVORIT_KELAS_9
	return base + bonus if is_specialty else base
```

This is a pure port of the match statement already in `_preview_gain` — no
new logic, just a new home and two params (`grade`, `is_specialty`)
instead of reading `GameState.current_grade` and comparing
`student.specialty_category == category` itself, so a `Dictionary`-based
caller (Task 2) can use it too without needing a `StudentData` object.

Do **not** touch `apply_daily_decay_all`'s own inline block (lines ~146-154
of the same file) in this task — its default-for-non-8/9-grades behavior is
`KELAS_7`, not `CADANGAN`, which differs from this helper's fallback. Since
`GameState.current_grade` is always 7, 8, or 9 in practice the two never
actually diverge, but rewiring the simulation's own code path to a
CADANGAN-defaulting helper would be a real (if currently unobservable)
behavior change to the simulation, which the Global Constraints rule out.
Leave it as-is.

- [ ] **Step 3: Replace `_preview_gain`'s body to delegate**

In `Scripts/SchoolSimulation/SchoolDay.gd`, replace the block from Step 1
with:

```gdscript
## The preview badge must quote the same gain the simulation will apply,
## or a tester changing Balance.gd sees the old number here and thinks
## nothing happened. Delegates to StudentManager.study_preview_gain(), the
## shared lookup also used by Atur Jadwal's stat-bar preview.
func _preview_gain(student: StudentData, category: String) -> float:
	return StudentManager.study_preview_gain(GameState.current_grade, student.specialty_category == category)
```

- [ ] **Step 4: Rescan and run the `school_day` and `balance` suites**

Call `filesystem_manage(op="scan")`, then `test_run(suite="school_day")`
and `test_run(suite="balance")`.
Expected: both suites fully green (same pass counts as the 307-baseline
run for these two suites — `school_day` and `balance` had 0 failures in
the pre-plan baseline).

- [ ] **Step 5: Write the new tests in `tests/test_school_day.gd`**

The file is 326 lines. The last test method,
`test_summary_and_event_overlays_use_the_scrim_variation`, ends at line
296; a `# ----- helper` divider and `_collect_overrides` follow at line
299. Insert the two new test methods between them (after line 296, before
line 299):

```gdscript
func test_study_preview_gain_matches_balance_by_grade() -> void:
	assert_true(is_equal_approx(StudentManager.study_preview_gain(7, false), Balance.BELAJAR_POIN_KELAS_7),
		"grade 7, non-specialty must equal BELAJAR_POIN_KELAS_7")
	assert_true(is_equal_approx(StudentManager.study_preview_gain(7, true), Balance.BELAJAR_POIN_KELAS_7 + Balance.BELAJAR_BONUS_FAVORIT_KELAS_7),
		"grade 7, specialty must equal base + bonus")
	assert_true(is_equal_approx(StudentManager.study_preview_gain(8, false), Balance.BELAJAR_POIN_KELAS_8),
		"grade 8, non-specialty must equal BELAJAR_POIN_KELAS_8")
	assert_true(is_equal_approx(StudentManager.study_preview_gain(8, true), Balance.BELAJAR_POIN_KELAS_8 + Balance.BELAJAR_BONUS_FAVORIT_KELAS_8),
		"grade 8, specialty must equal base + bonus")
	assert_true(is_equal_approx(StudentManager.study_preview_gain(9, false), Balance.BELAJAR_POIN_KELAS_9),
		"grade 9, non-specialty must equal BELAJAR_POIN_KELAS_9")
	assert_true(is_equal_approx(StudentManager.study_preview_gain(9, true), Balance.BELAJAR_POIN_KELAS_9 + Balance.BELAJAR_BONUS_FAVORIT_KELAS_9),
		"grade 9, specialty must equal base + bonus")
	assert_true(is_equal_approx(StudentManager.study_preview_gain(0, false), Balance.BELAJAR_POIN_CADANGAN),
		"an out-of-range grade must fall back to BELAJAR_POIN_CADANGAN")
	assert_true(is_equal_approx(StudentManager.study_preview_gain(0, true), Balance.BELAJAR_POIN_CADANGAN + Balance.BELAJAR_BONUS_FAVORIT_CADANGAN),
		"an out-of-range grade, specialty must equal CADANGAN base + bonus")


func test_preview_gain_delegates_to_shared_helper() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("StudentManager.study_preview_gain"),
		"_preview_gain must delegate to the shared helper, not keep its own grade lookup")
```

- [ ] **Step 6: Rescan and run the `school_day` suite again**

Call `filesystem_manage(op="scan")`, then `test_run(suite="school_day")`.
Expected: all previous `school_day` tests still pass, plus the 2 new ones
(`test_study_preview_gain_matches_balance_by_grade`,
`test_preview_gain_delegates_to_shared_helper`) passing — suite total up
by 2 from baseline.

- [ ] **Step 7: Commit**

```bash
git add Scripts/SchoolSimulation/StudentManager.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_school_day.gd
git commit -m "$(cat <<'EOF'
refactor(balance): extract study-gain preview into a shared helper

StudentManager.study_preview_gain() replaces SchoolDay's private
_preview_gain() match statement, so Atur Jadwal's stat-bar preview
(next commit) can reuse the same grade lookup instead of adding a
third copy of it.
EOF
)"
```

---

## Task 2: Wire Atur Jadwal's preview constants to Balance.gd

**Files:**
- Modify: `Scripts/AturJadwal/atur_jadwal.gd:97-109` (delete local consts),
  `:548-555` (`_compute_pending_gain`), `:958-980` (`_on_activity_selected`),
  `:1282-1300` (`_check_and_lock_holidays`)
- Test: `tests/test_atur_jadwal.gd` (new test method)

**Interfaces:**
- Consumes: `StudentManager.study_preview_gain(grade: int, is_specialty: bool) -> float`
  from Task 1.

- [ ] **Step 1: Confirm the current line ranges**

Run `Grep` for `const BASE_GAIN`, `func _compute_pending_gain`,
`func _on_activity_selected`, and `func _check_and_lock_holidays` in
`Scripts/AturJadwal/atur_jadwal.gd`. Expected: matches the line numbers
above (they may have drifted slightly if Task 1's commit touched a
different file — this file is untouched by Task 1, so they should not
have moved, but confirm before editing).

- [ ] **Step 2: Delete the twelve stale local consts**

Remove, in `Scripts/AturJadwal/atur_jadwal.gd`:

```gdscript
const BASE_GAIN := 3.0       # Must match StudentManager.gd apply_jadwal_activity base_gain
const HOBBY_BONUS_GAIN := 6.0  # Must match base_gain + specialty_bonus (3 + 3 = 6 total for specialty)

const MOOD_LOSS_MIN := 10
const MOOD_LOSS_MAX := 15
const ENERGY_LOSS_MIN := 15
const ENERGY_LOSS_MAX := 20
const DAYOFF_GAIN_MIN := 20
const DAYOFF_GAIN_MAX := 30
const WIRAUSAHA_MOOD_MIN := 8
const WIRAUSAHA_MOOD_MAX := 14
const WIRAUSAHA_ENERGY_MIN := 10
const WIRAUSAHA_ENERGY_MAX := 16
```

Replace with a one-line pointer comment so a future reader isn't left
wondering where the numbers went:

```gdscript
## Preview numbers (study gain, mood/energy cost, Libur recovery, Wirausaha
## cost) come from Balance.gd / StudentManager.study_preview_gain(), not a
## local copy -- see _compute_pending_gain() and _on_activity_selected().
```

- [ ] **Step 3: Fix `_compute_pending_gain`**

Replace:

```gdscript
func _compute_pending_gain(category: String, student: Dictionary) -> float:
	var schedules = _get_current_schedules()
	var count := 0
	for day in schedules.keys():
		if schedules[day]["category"] == category:
			count += 1
	var increment = HOBBY_BONUS_GAIN if student.get("hobby_category", "") == category else BASE_GAIN
	return count * increment
```

with:

```gdscript
func _compute_pending_gain(category: String, student: Dictionary) -> float:
	var schedules = _get_current_schedules()
	var count := 0
	for day in schedules.keys():
		if schedules[day]["category"] == category:
			count += 1
	var is_specialty = student.get("hobby_category", "") == category
	var increment = StudentManager.study_preview_gain(GameState.current_grade, is_specialty)
	return count * increment
```

- [ ] **Step 4: Fix `_on_activity_selected`**

Replace:

```gdscript
		var mood_cost: int
		var energy_cost: int
		if category == "Istirahat":
			mood_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
			energy_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
		elif category == "Wirausaha":
			mood_cost = randi_range(WIRAUSAHA_MOOD_MIN, WIRAUSAHA_MOOD_MAX)
			energy_cost = randi_range(WIRAUSAHA_ENERGY_MIN, WIRAUSAHA_ENERGY_MAX)
		else:
			mood_cost = randi_range(MOOD_LOSS_MIN, MOOD_LOSS_MAX)
			energy_cost = randi_range(ENERGY_LOSS_MIN, ENERGY_LOSS_MAX)
```

with:

```gdscript
		var mood_cost: int
		var energy_cost: int
		if category == "Istirahat":
			mood_cost = -randi_range(roundi(Balance.LIBUR_MOOD_PULIH_MIN), roundi(Balance.LIBUR_MOOD_PULIH_MAX))
			energy_cost = -randi_range(roundi(Balance.LIBUR_ENERGI_PULIH_MIN), roundi(Balance.LIBUR_ENERGI_PULIH_MAX))
		elif category == "Wirausaha":
			mood_cost = roundi(Balance.WIRAUSAHA_BIAYA_MOOD)
			energy_cost = roundi(Balance.WIRAUSAHA_BIAYA_ENERGI)
		else:
			mood_cost = randi_range(roundi(Balance.BELAJAR_BIAYA_MOOD_MIN), roundi(Balance.BELAJAR_BIAYA_MOOD_MAX))
			energy_cost = randi_range(roundi(Balance.BELAJAR_BIAYA_ENERGI_MIN), roundi(Balance.BELAJAR_BIAYA_ENERGI_MAX))
```

Two behavior changes here, both intentional per the Global Constraints:
Wirausaha stops being randomized (the simulation applies it as a flat
cost — `Scripts/SchoolSimulation/StudentManager.gd:138-141` — so the
preview should too), and Istirahat's mood recovery now uses its own
range (`LIBUR_MOOD_PULIH_MIN/MAX`, 15-25) instead of borrowing the energy
range (`LIBUR_ENERGI_PULIH_MIN/MAX`, 20-30).

- [ ] **Step 5: Fix `_check_and_lock_holidays`**

Replace:

```gdscript
					# Assign Istirahat with standard mood/energy gain cost delta
					var mood_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
					var energy_cost = -randi_range(DAYOFF_GAIN_MIN, DAYOFF_GAIN_MAX)
```

with:

```gdscript
					# Assign Istirahat with standard mood/energy gain cost delta
					var mood_cost = -randi_range(roundi(Balance.LIBUR_MOOD_PULIH_MIN), roundi(Balance.LIBUR_MOOD_PULIH_MAX))
					var energy_cost = -randi_range(roundi(Balance.LIBUR_ENERGI_PULIH_MIN), roundi(Balance.LIBUR_ENERGI_PULIH_MAX))
```

- [ ] **Step 6: Rescan and run the `atur_jadwal` suite**

Call `filesystem_manage(op="scan")`, then `test_run(suite="atur_jadwal")`.
Expected: same pass count as the pre-plan baseline for this suite (0
failures) — confirms Steps 2-5 didn't break any existing contract test
(especially `test_day_schedules_still_written_in_the_same_shape`, which
checks the `mood_cost`/`energy_cost`/`category` keys are still written).

- [ ] **Step 7: Write the new test in `tests/test_atur_jadwal.gd`**

Add after `test_day_schedules_still_written_in_the_same_shape`
(around line 66), in the same "behavioral contract net" section:

```gdscript
func test_preview_numbers_come_from_balance_not_a_local_copy() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var stale_consts := ["BASE_GAIN", "HOBBY_BONUS_GAIN", "MOOD_LOSS_MIN", "MOOD_LOSS_MAX",
		"ENERGY_LOSS_MIN", "ENERGY_LOSS_MAX", "DAYOFF_GAIN_MIN", "DAYOFF_GAIN_MAX",
		"WIRAUSAHA_MOOD_MIN", "WIRAUSAHA_MOOD_MAX", "WIRAUSAHA_ENERGY_MIN", "WIRAUSAHA_ENERGY_MAX"]
	for stale_const in stale_consts:
		assert_false(src.contains(stale_const),
			"stale local const still present: " + stale_const)
	assert_true(src.contains("StudentManager.study_preview_gain"),
		"study-gain preview must delegate to the shared grade-aware helper")
	var balance_fields := ["Balance.BELAJAR_BIAYA_MOOD_MIN", "Balance.BELAJAR_BIAYA_MOOD_MAX",
		"Balance.BELAJAR_BIAYA_ENERGI_MIN", "Balance.BELAJAR_BIAYA_ENERGI_MAX",
		"Balance.LIBUR_MOOD_PULIH_MIN", "Balance.LIBUR_MOOD_PULIH_MAX",
		"Balance.LIBUR_ENERGI_PULIH_MIN", "Balance.LIBUR_ENERGI_PULIH_MAX",
		"Balance.WIRAUSAHA_BIAYA_MOOD", "Balance.WIRAUSAHA_BIAYA_ENERGI"]
	for balance_field in balance_fields:
		assert_true(src.contains(balance_field),
			"preview must read " + balance_field + " instead of a local copy")
```

- [ ] **Step 8: Rescan and run the `atur_jadwal` suite again**

Call `filesystem_manage(op="scan")`, then `test_run(suite="atur_jadwal")`.
Expected: all previous tests still pass, plus
`test_preview_numbers_come_from_balance_not_a_local_copy` passing — suite
total up by 1.

- [ ] **Step 9: Commit**

```bash
git add Scripts/AturJadwal/atur_jadwal.gd tests/test_atur_jadwal.gd
git commit -m "$(cat <<'EOF'
fix(balance): Atur Jadwal preview reads Balance.gd, not its own copy

Study-gain badges now scale by grade via the shared
StudentManager.study_preview_gain() helper (silently wrong for
Grade 8/9 before this). Mood/energy cost badges, Libur recovery, and
Wirausaha cost now read their matching Balance.gd fields directly:
Libur's mood recovery gets its own range instead of borrowing
energy's, and Wirausaha's preview stops randomizing a cost the
simulation actually applies flat. Grade 7's numbers are unchanged.
EOF
)"
```

---

## Task 3: Close out the documented gap and verify the full suite

**Files:**
- Modify: `Scripts/Balance.gd:6-8` (header comment)

**Interfaces:**
- Consumes: nothing new; this task only removes a comment and verifies
  Tasks 1-2's combined effect.

- [ ] **Step 1: Remove the stale caveat from `Balance.gd`'s header**

Current text, `Scripts/Balance.gd:4-8`:

```gdscript
## Angka-angka simulasi utama (poin belajar, minigame, kepribadian,
## sifat pasif, event, Wirausaha) semuanya dibaca dari sini. Perkecualian:
## layar Atur Jadwal (atur_jadwal.gd) punya salinan sendiri untuk angka
## preview-nya — belum tersambung ke file ini.
```

Replace with:

```gdscript
## Angka-angka simulasi utama (poin belajar, minigame, kepribadian,
## sifat pasif, event, Wirausaha) semuanya dibaca dari sini, termasuk
## preview di layar Atur Jadwal (atur_jadwal.gd).
```

- [ ] **Step 2: Rescan and run the full suite**

Call `filesystem_manage(op="scan")`, then `test_run()` with no `suite`
filter.

Expected: `total` = 310 (307 baseline + 2 from Task 1 + 1 from Task 2),
`failed` = 1, and that one failure is still exactly
`test_audio_director.gd::test_volumes_persist_across_a_fresh_director`
(the documented pre-existing coroutine issue — unrelated to this plan).
If `failed` > 1, or the failing test name is anything else, stop and
diagnose before proceeding — do not assume it's unrelated.

If the response carries a `scene_warning` about the main scene not being
open, call `scene_open("res://Scenes/Splashscreen/Splashscreen.tscn")`
and re-run before trusting any failures beyond the known one.

- [ ] **Step 3: Commit**

```bash
git add Scripts/Balance.gd
git commit -m "$(cat <<'EOF'
docs(balance): Atur Jadwal preview no longer has its own number copy

Closes the gap Balance.gd's header called out after the master-script
extraction -- the previous two commits pointed atur_jadwal.gd at
Balance.gd directly.
EOF
)"
```
