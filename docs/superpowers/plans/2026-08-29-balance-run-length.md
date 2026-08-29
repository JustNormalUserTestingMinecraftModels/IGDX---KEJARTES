# Run Length in Balance.gd Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the tester set how many weeks each grade runs for by editing `Scripts/Balance.gd`, instead of the counts being hardcoded in `GameState.get_max_weeks()`.

**Architecture:** Three new `static var` fields in `Balance.gd`'s existing `SYARAT LULUS` section, and `GameState.get_max_weeks()` reads them instead of its own literals. The rest of the game already derives run length from `GameState.max_minggu`, which the `current_grade` setter recomputes from `get_max_weeks()` — so this one function is the only place that needs to change.

**Tech Stack:** Godot 4.6, GDScript, the in-editor `McpTestSuite` runner.

**Spec:** No spec document — this plan answers a direct question ("for the balance.gd to add the week numbers for 1 run, is it possible?"). It extends the balance-tuning work specified in `docs/superpowers/specs/2026-08-28-balance-tuning-tools-design.md`, whose stated goal is that *"every number affecting balance lives in exactly one file"* — run length qualifies and was missed in the original 105-number inventory.

## Global Constraints

- Godot **4.6**, GDScript.
- **`static var`, never `const`** in `Balance.gd` — a `const` is compile-time and could never be changed by a future editing panel.
- **Behaviour must not change.** `Balance.gd` ships seeded with today's exact values (6 / 12 / 16). A correct extraction alters nothing observable.
- **Field names and comments are Indonesian**; the surrounding code stays English.
- Use the vocabulary the tester sees on screen: **Kelas 7/8/9**, **Minggu**.
- Test suites live in `tests/test_*.gd`, extend `McpTestSuite`, must be `@tool`, and **no test may be a coroutine** — the runner calls `suite.call(name)` without awaiting.
- **The Godot MCP bridge is single-client.** Implementer subagents must never call `mcp__godot-ai__*`; the controller runs every scan and test run.
- After editing any `.gd`, the controller runs `filesystem_manage(op="scan")` before `test_run`.
- Conventional Commits with a scope.

## Known baseline

The full suite is **310 passed / 1 failed**. The single failure is `audio_director / test_volumes_persist_across_a_fresh_director`, a pre-existing coroutine bug documented in CLAUDE.md Known Issues. It is unrelated — do not fix it, do not treat it as a regression.

`Scripts/Balance.gd` currently holds **104** `static var` fields, and `tests/test_balance.gd` asserts that count. This plan takes it to **107**.

## Why this one is safe — what was verified before writing

The original extraction was bitten three separate times by numbers that had a hidden second copy (the 12 event amounts duplicated in `force_event`, the Biang Onar coefficient read at three sites not two, the study gains copied into the day-preview badges). Run length was checked for the same trap and is clean:

| Consumer | How it gets run length | Duplicate? |
|---|---|---|
| `GameState.get_max_weeks()` (`GameState.gd:29-34`) | The literals `6` / `12` / `16`, plus a `_:` fallback of `6` | **This is the only definition** |
| `GameState.max_minggu` (`GameState.gd:18`, `:23`) | Assigned from `get_max_weeks()` inside the `current_grade` setter | Derived — no |
| `SchoolDay.gd:1261-1263` (end-of-run → SemesterEnd) | Reads `GameState.max_minggu` | Derived — no |
| `DebugManager.gd:606`, `:611` (week +/- and jump) | Clamps against `GameState.max_minggu` | Derived — no |

A repo-wide grep for a bare `6`/`12`/`16` in week context turned up only `DebugManager.gd:409` (`" Set Minggu 16 "`, a debug jump-to shortcut that clamps against `max_minggu`, not a rule) and `SchoolDay.gd:569` (a holiday week — see below). No test asserts on 6/12/16.

### The one coupling this plan deliberately does not touch

`Scripts/AturJadwal/atur_jadwal.gd:9` declares `const HOLIDAYS`, pinning two national holidays to **week 3** (Hari Kemerdekaan RI) and **week 6** (Maulid Nabi Muhammad SAW). These are simulation-affecting, not cosmetic — `_check_and_lock_holidays()` locks every student's schedule to Istirahat on those days.

They are **not** moved into `Balance.gd` and **not** rescaled, because they are real calendar dates: Indonesian Independence Day does not shift because a grade got longer. But the tester should know the consequence, so Task 1 documents it in the field's own comment:

- Grade 7 runs 6 weeks today, so its holidays land in weeks 3 and 6 — the middle and the *last* week.
- Grades 8 (12 weeks) and 9 (16 weeks) already get both holidays in their first six weeks and none afterward.
- Lengthening any grade adds only holiday-free weeks to the back half.

If that ever needs to change, it is a separate piece of work with its own design question (do holidays repeat? scale? stay fixed?) — not a rename.

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scripts/Balance.gd` | Every tunable number, documented in Indonesian. The tester's only file. | Modify — 3 new fields in the existing `SYARAT LULUS` section |
| `Scripts/GameState.gd` | Owns run/week state; `get_max_weeks()` is the single definition of run length. | Modify — `get_max_weeks()` reads Balance |
| `tests/test_balance.gd` | Pins every field's name and shipped value, and that the extraction is actually wired. | Modify — 3 `_EXPECTED` entries, count 104→107, one behavioural test |

**One task.** The three edits are a single atomic deliverable — fields with no reader, or a reader with no fields, is a broken half. There is no point at which a reviewer could accept one and reject another.

---

# Task 1: Run length reads from `Balance`

**Files:**
- Modify: `Scripts/Balance.gd:33` (append after the `TARGET_KENAIKAN_*` block)
- Modify: `Scripts/GameState.gd:29-34`
- Test: `tests/test_balance.gd`

**Interfaces:**
- Produces: `Balance.JUMLAH_MINGGU_KELAS_7` (int, 6), `Balance.JUMLAH_MINGGU_KELAS_8` (int, 12), `Balance.JUMLAH_MINGGU_KELAS_9` (int, 16).
- Consumes: `GameState.current_grade`, `GameState.get_max_weeks() -> int`.

These fields go in `SYARAT LULUS` rather than a new section on purpose: run length is the other half of the passing requirement the tester is already reading there. `TARGET_KENAIKAN_*` says *how much they must gain*; this says *how long they have to gain it*. The two only make sense together.

- [ ] **Step 1: Write the failing tests**

Two changes to `tests/test_balance.gd`.

First, add the three entries to the `_EXPECTED` dictionary, immediately after the `TARGET_KENAIKAN_KELAS_9` line so the table stays in the same order as `Balance.gd`:

```gdscript
	"TARGET_KENAIKAN_KELAS_9": 40.0,
	"JUMLAH_MINGGU_KELAS_7": 6,
	"JUMLAH_MINGGU_KELAS_8": 12,
	"JUMLAH_MINGGU_KELAS_9": 16,
```

Second, bump the count assertion — the table just grew by three, so the guard that catches silent drift has to move with it. Change:

```gdscript
## 104 numbers is the whole extraction surface. If the count drifts, either a
## field was added without a test entry or one was quietly dropped.
func test_the_expected_table_covers_every_number() -> void:
	assert_eq(_EXPECTED.size(), 104,
		"the extraction covers 104 numbers; update this test deliberately if that changes")
```

to:

```gdscript
## 107 numbers is the whole extraction surface. If the count drifts, either a
## field was added without a test entry or one was quietly dropped.
func test_the_expected_table_covers_every_number() -> void:
	assert_eq(_EXPECTED.size(), 107,
		"the extraction covers 107 numbers; update this test deliberately if that changes")
```

Third, append this test to the end of the file. It is the one that proves the wiring, not just the fields' existence:

```gdscript
## Fields with no reader are the failure mode this whole file exists to
## avoid -- the tester changes a number, nothing happens, and they
## conclude Balance.gd is decorative. GameState.get_max_weeks() is what
## the simulation actually asks for a run's length, so it must resolve
## through Balance rather than keeping literals of its own.
func test_grade_week_counts_come_from_balance() -> void:
	var original_grade: int = GameState.current_grade
	for grade in [7, 8, 9]:
		GameState.current_grade = grade
		var expected: int = _EXPECTED["JUMLAH_MINGGU_KELAS_%d" % grade]
		assert_eq(GameState.get_max_weeks(), expected,
			"Kelas %d must run for Balance.JUMLAH_MINGGU_KELAS_%d weeks" % [grade, grade])
	GameState.current_grade = original_grade
```

Two notes on that test, both deliberate:

1. It mutates the `GameState` autoload and restores it on the last line. `McpTestSuite`'s `assert_eq` returns early from the *assertion* once `_failed` is set, not from the test function — so the loop always runs to completion and the restore always executes, even when an assertion fails.
2. It assigns `GameState.current_grade` directly rather than calling `GameState.set_grade()`. The property's setter is what recomputes `max_minggu`, which is all this needs; `set_grade()` additionally resets `minggu_ke` to 1, which would be a side effect on shared state that this test has no reason to cause.

- [ ] **Step 2: Run them and confirm they fail**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="balance")`.

Expected: **two** failures.
- `test_every_field_exists_and_holds_its_shipped_value` — `Balance` has no `JUMLAH_MINGGU_KELAS_7`.
- `test_the_expected_table_covers_every_number` — the table now holds 107 entries but still asserts 104.

`test_grade_week_counts_come_from_balance` will also fail, on the missing `_EXPECTED` lookup or the field itself. If any of the three *passes* at this point, stop and investigate — it means the fields already exist somewhere and this plan's premise is wrong.

- [ ] **Step 3: Add the fields to `Balance.gd`**

In `Scripts/Balance.gd`, the `SYARAT LULUS` section currently ends at line 33:

```gdscript
## Berapa poin yang harus dinaikkan murid di SEMUA mata pelajaran
## supaya lulus. Ditambahkan di atas nilai awal mereka — jadi makin
## besar angkanya, makin sulit kelasnya. Ini pengatur kesulitan
## paling berpengaruh di seluruh game.
static var TARGET_KENAIKAN_KELAS_7 := 15.0
static var TARGET_KENAIKAN_KELAS_8 := 30.0
static var TARGET_KENAIKAN_KELAS_9 := 40.0
```

Append this directly beneath it, inside the same section (before the two blank lines and the `HARI BELAJAR BIASA` banner):

```gdscript

## Berapa minggu satu kelas berlangsung — ini "waktu yang kamu punya"
## untuk mengejar target di atas. Menambah minggu = lebih gampang
## (lebih banyak kesempatan belajar); mengurangi = lebih sulit.
## Pasangan angka ini dengan TARGET_KENAIKAN di atas: keduanya bareng
## yang menentukan satu kelas terasa adil atau mustahil.
##
## Harus angka bulat (tanpa titik) — ini jumlah minggu, bukan persentase.
##
## Perlu diperhatikan: dua hari libur nasional terkunci di minggu 3
## (Hari Kemerdekaan RI) dan minggu 6 (Maulid Nabi Muhammad SAW) — lihat
## HOLIDAYS di atur_jadwal.gd. Keduanya TIDAK ikut bergeser kalau kamu
## mengubah angka di sini, karena itu tanggal kalender asli. Jadi kalau
## kelasnya kamu panjangkan, minggu-minggu tambahannya tidak ada liburnya.
static var JUMLAH_MINGGU_KELAS_7 := 6
static var JUMLAH_MINGGU_KELAS_8 := 12
static var JUMLAH_MINGGU_KELAS_9 := 16
```

Write `:= 6`, not `:= 6.0`. `get_max_weeks()` is typed `-> int` and the values are used in `clampi()`, so these must infer as `int`.

- [ ] **Step 4: Point `get_max_weeks()` at them**

In `Scripts/GameState.gd`, replace lines 29-34:

```gdscript
func get_max_weeks() -> int:
	match current_grade:
		7: return 6
		8: return 12
		9: return 16
		_: return 6
```

with:

```gdscript
func get_max_weeks() -> int:
	match current_grade:
		8: return Balance.JUMLAH_MINGGU_KELAS_8
		9: return Balance.JUMLAH_MINGGU_KELAS_9
		_: return Balance.JUMLAH_MINGGU_KELAS_7
```

The `7:` branch and the `_:` fallback both returned `6`, so they collapse into one catch-all that is behaviourally identical: 7 → 6, 8 → 12, 9 → 16, anything else → 6. This matches how `Task 2` of the balance plan handled the grade-target uplift and how `SchoolDay._preview_gain()` handles the same three-way branch. (`current_grade`'s setter clamps to 7-9, so the catch-all only ever sees 7 in practice.)

Nothing else in `GameState.gd` changes — `max_minggu` on line 23 already recomputes from this function.

- [ ] **Step 5: Run the balance suite and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="balance")`.
Expected: PASS, 4 tests.

- [ ] **Step 6: Run the full suite**

**Controller action:** `test_run()`.
Expected: **311 passed, 1 failed** — the known `audio_director` bug only. The pass count rises from 310 by the one new test.

`test_school_day` and `test_semester_end` both exercise the end-of-run path that reads `max_minggu`; a mistake in Step 4 shows up there rather than silently.

- [ ] **Step 7: Prove the knob actually turns**

The tests confirm the wiring resolves to today's values, but not that *changing* a value changes the game — which is the entire point of the file. Verify once by hand.

**Controller action:** temporarily set `JUMLAH_MINGGU_KELAS_7 := 2` in `Scripts/Balance.gd`, then:

```
filesystem_manage(op="scan")
project_run(mode="main")
```

Then via `editor_manage(op="game_eval")`:

```gdscript
GameState.current_grade = 7
return {"max_minggu": GameState.max_minggu, "get_max_weeks": GameState.get_max_weeks()}
```

Expected: both report `2`. Then restore `:= 6`, rescan, and re-run the same eval to confirm both report `6` again.

**Do not commit the temporary value.** `git diff Scripts/Balance.gd` must show only the added block before Step 8.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Balance.gd Scripts/GameState.gd tests/test_balance.gd
git commit -m "feat(balance): let the tester set how many weeks each grade runs"
```

---

## Self-Review

**Requirement coverage.** The request was "add the week numbers for 1 run" to `Balance.gd` — Task 1 adds all three (one per grade) and wires the single function that defines them. The spec's governing principle (*every number affecting balance lives in exactly one file*) is satisfied for run length: after this change, `GameState.gd` holds no week literal, and every other consumer was already derived rather than duplicated.

**Type consistency.** `JUMLAH_MINGGU_KELAS_7/8/9` is the same name in `Balance.gd`, in `_EXPECTED`, in the new behavioural test's `"JUMLAH_MINGGU_KELAS_%d"` interpolation, and in `get_max_weeks()`. All three are `int`, matching `get_max_weeks() -> int` and the `clampi()` calls downstream in `DebugManager.gd`.

**Count arithmetic.** 104 existing fields + 3 = 107. Step 1 adds exactly 3 `_EXPECTED` entries *and* moves the count assertion to 107; Step 3 adds exactly 3 `static var` lines. Field count and table count move together in one commit, so a mismatch cannot ship — and if the implementer does the entries without the assertion, Step 2 shows it immediately as the expected second failure.

**Risks.**
1. *The behavioural test leaves `GameState` dirty.* Mitigated by capturing `original_grade` and restoring it; `assert_eq` short-circuits the assertion rather than the function, so the restore is not skipped on failure. Reviewed explicitly because a leaked autoload mutation would surface as a confusing failure in an unrelated suite.
2. *The tester lengthens a grade and finds the extra weeks have no holidays.* Real, pre-existing, and out of scope — documented directly in the field's comment (Step 3) so it reads as a known property rather than a bug.
3. *Values written as floats.* `:= 6.0` would infer `float` and break `get_max_weeks() -> int`. Called out inline in Step 3, and the "harus angka bulat" note matches the convention already used on `WIRAUSAHA_UANG_MIN/MAX` and `SIFAT_BIANG_ONAR_PELUANG_EVENT`.
