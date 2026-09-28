# PR3 — Strategic Depth Mechanics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three composed scheduling mechanics: diminishing returns per student per category per week (A), a weekly Fokus meta-choice that unlocks at G8 (C), and a duet bonus when exactly 2 students share a category on a day (D). Also add a per-grade sliding star threshold and the Fokus-Wirausaha payout. All of it sits behind `Balance.STRATEGIC_MECHANICS_ENABLED`, so one flag rolls it back.

**Architecture:** The math lives in one new pure component, `StrategicMechanics` (`Scripts/SchoolSimulation/StrategicMechanics.gd`, static functions, no state). Two callers apply it. `StudentManager` applies it to the simulated week. `ActivityPreview.week_skill_gain` applies it to AturJadwal's projection, so the week the player previews is the week that runs. The Fokus state is `GameState.weekly_fokus`, reset by a new `GameState.advance_week()`. The Fokus UI is a new component scene, `FokusRow.tscn`, instanced into `AturJadwal.tscn`. The sliding threshold is `GameState.win_threshold()`, read by `check_semester_passed()` and `ObjectiveHint`. No new autoloads, no new persistence.

**Tech Stack:** GDScript 4.6, McpTestSuite, the existing `FilterChipButton` ThemeFactory variation (no `theme_override_*`, no new variation planned).

**Spec:** `docs/superpowers/specs/2026-09-11-balance-and-depth-design.md`, section "PR3 — Strategic depth mechanics".

**Depends on:** the collaborator applying PR1's `Balance.gd` constants. **That has not happened; see the revision note.** Task 0 is a hard gate.

## Revision (2026-09-28): clean-code pass; status audit

**Status: NOT IMPLEMENTED, and BLOCKED on `Balance.gd`.** Verified on `Textures` @ `b2890588`:

- Grepping `Scripts/`, `Scenes/` and `tests/` for `STRATEGIC_MECHANICS_ENABLED`, `weekly_fokus`, `FOKUS_`, `DUET_BONUS`, `DIMINISHING_DAY` and `STAR_WIN_THRESHOLD_KELAS` returns nothing. There is no Fokus node in `AturJadwal.tscn`. Every "Fokus" hit in the code is unrelated flavour text (`DayStickyNote.FLAVOR_WORDS["Akademis"]`, item copy, chatter).
- **The collaborator never applied PR1.** `Scripts/Balance.gd` has no commit since 2026-09-10. It still holds weeks 6/12/16, targets 15/34/40, `WIRAUSAHA_UANG_MIN/MAX` 120/320, and a single `STAR_WIN_THRESHOLD := 2.0`. None of the 11 constants this plan reads exist: `STAR_WIN_THRESHOLD_KELAS_7/8/9`, `DIMINISHING_DAY_3/4/5`, `FOKUS_BONUS`, `FOKUS_PENALTY`, `FOKUS_WIRAUSAHA_BONUS`, `FOKUS_WIRAUSAHA_REST_COIN`, `DUET_BONUS` and `STRATEGIC_MECHANICS_ENABLED`. Until they exist, every task from Task 1 on fails to parse. The PR1 proposal is `docs/superpowers/plans/2026-09-11-balance-pacing-proposal.md`.
- **A newer proposal contradicts PR1's pacing.** `docs/superpowers/specs/2026-09-28-week-length-rebalance-proposal.md` proposes weeks 6/9/12 and targets 15/26/30. PR1 proposed 4/6/8 and 10/22/32. The old Task 8 hard-coded PR1's numbers into a test. This plan no longer assumes either set: the tests read whatever `Balance.gd` actually holds.

**Ground that moved since 2026-09-11:**

- The stat keys were renamed to `akademis`/`seni_budaya`/`olahraga`/`mood`/`energy` (2026-09-26). This plan contains no numbered roster key (grepped). Every snippet uses the new names.
- The files were renamed to PascalCase (2026-09-26). The old `atur_jadwal.gd` and `atur_jadwal.tscn` are now `Scripts/AturJadwal/AturJadwal.gd` and `Scenes/AturJadwal/AturJadwal.tscn`.
- AturJadwal's activity picker was rebuilt on 2026-09-24 (`ActivityTile`, `EffectMeter`, `ActivityPreview`, `ObjectiveStrip`/`ObjectiveHint`). The projected gain now goes through `ActivityPreview.skill_gain`, and `atur_jadwal`'s `test_pending_gain_is_grade_aware` pins that.
- The clean-code ratchet landed (2026-09-26). Three scripts are at their `LARGE_SCRIPTS` cap: `AturJadwal.gd` (1626), `SchoolDay.gd` (1638) and `StudentCard.gd` (1451). `StudentManager.apply_daily_decay_all` is a 90-line `LONG_FUNCTIONS` entry, so adding to it fails.
- The win rule is `GameState.check_semester_passed()`, which is `run_stars() >= Balance.STAR_WIN_THRESHOLD`. `ObjectiveHint.star_text`/`progress_percent` read the same constant.

**Plan-vs-code conflicts, now fixed:**

1. `StudentManager._apply_category_day` does not exist. The gain site is `apply_daily_decay_all` → `StudentData.apply_jadwal_activity(category, base_gain, specialty_bonus, same_subject_count)`. The mechanics now scale `base_gain` and `specialty_bonus` before that call. Quirks and personality are applied inside it, so the spec's order `base → duet → fokus → diminishing → quirks/personality` holds without touching `StudentData`.
2. `GameState.advance_week()` did not exist. The week moves at exactly one site, `SchoolDay._on_back_pressed`: `GameState.minggu_ke += 1` (L1294). Task 2 adds `advance_week()`, and SchoolDay swaps that one line for the call. Its line count stays at 1638.
3. `GameState.check_win()` → `check_semester_passed()`. `_debug_set_stars` does not exist; the tests seed a roster instead.
4. `RunGrade.gd` never reads a star threshold, so it is dropped from the plan. `ObjectiveHint.gd` does read one, so it is added.
5. **Roster size is 2/3/4 by grade** (`StudentCard.max_approve_for`: G7 2, G8 3, G9 4), not 4 everywhere as the spec's math assumes. That gives 6/9/12 targets. Stars therefore move in steps of 0.5, 1/3 and 0.25, which has three consequences:
   - The old test's "10 of 12 = 1.67" was wrong: 10 of 12 is 2.5.
   - **G8's 1.83 changes nothing.** At 1.83, 5 of 9 (1.67) still fails, so 6 of 9 (2.0) is needed, exactly as today.
   - G9's 1.67 lowers the bar from 8 of 12 to 7 of 12.
   A human question (below).
6. Floating point: 5 of 9 × 3 = 1.666…, which is below a two-decimal "1.67". `check_semester_passed` now allows a named `STAR_THRESHOLD_TOLERANCE` (0.01).
7. The old Task 4 test asserted `_fokus_multiplier("Wirausaha") == 1.0` while its own code returned `1 + FOKUS_BONUS` for that call. Fokus now touches only skill categories (`ActivityPreview.is_skill`). The redundant duplicate `Wirausaha` branch is gone.
8. `StudentManager` lives one **week**, not one day. `SchoolDay.start_simulation()` L285-287 makes a new one per week, and its header's "one per day" was wrong (Boy Scout fix in Task 3). The weekly day counter can therefore live on the instance.
9. Day keys are `"Senin"…"Jumat"`, not `"Monday"`.
10. An Izin day (energy ≤ `Balance.IZIN_OTOMATIS_BATAS_ENERGI`) turns into Istirahat inside `StudentData`. It no longer counts toward diminishing returns.
11. The duet count reuses `apply_daily_decay_all`'s existing per-day `category_counts`. It counts roster students with normalised categories. The old code walked raw `day_schedules` keys and never normalised `Akademik`.
12. `PrimaryButton` toggles → `FilterChipButton`. That is the theme's existing toggle-chip variation: it has a pressed state and is pinned in `theme_factory`'s `expected` and `DISPLAY_ROSTER`. A `ButtonGroup` in the scene gives the one-at-a-time behaviour with no toggle-group code. The G7 lock shows as a visible note, because a tooltip never shows on a phone.
13. There is no "G8 intro cutscene" in the natural flow. Passing G7 goes RunResult → StudentCard, and CutScene plays only from MainMenu/LevelSelect. The Fokus lesson therefore lives on `FokusRow` itself, as a standing caption while nothing is picked. CutScene gets a grade-keyed hint frame (G7 rotation, G8 Fokus), which shows when a run starts at that grade.
14. `[PLACEHOLDER]` is no longer shown in-game. The convention is now a `##` `[PLACEHOLDER]` comment plus a DEBT "Audio and copy" line (DEBT.md, "Copy placeholders").
15. `StudentManager.apply_jadwal_effects_all` has zero callers. Task 3 deletes it, which also removes one of its three copies of the `Akademik`/`DayOff` normalisation.
16. The suite names were wrong: `test_run(suite=…)` takes `suite_name()`, not the file name, and each new suite now declares one. The old tests also mutated `GameState` and `Balance` without restoring them, and leaked `StudentManager` nodes. They now snapshot in `setup()`, restore in `teardown()`, and `track()` every node.
17. `economy_state`'s threshold tests and `objective_hint`'s star-chip tests assume 2.0 regardless of grade. Task 6 pins them to an explicit grade.

**Structural changes:** new behaviour goes into new components: `StrategicMechanics.gd`, `FokusRow.tscn` + `FokusRow.gd`, and `ActivityPreview.week_skill_gain`. The three large scripts only ever call down:

- `AturJadwal.gd` shrinks: `_compute_pending_gain` goes from 7 lines to 3, and the FokusRow signal is wired in the `.tscn`.
- `SchoolDay.gd` gets a one-line swap, net 0 lines, and the function it touches gets typed.
- `StudentCard.gd` is not touched (only `max_approve_for` is read).

`apply_daily_decay_all` is split into small typed helpers before any mechanic is added (Task 3). Tasks are renumbered 0–11.

## Global Constraints

**House rules (CLAUDE.md).**

- `Balance.gd` is read-only for us. Every new tuning number of the spec is a collaborator constant; we only read it. If a value needs changing, propose it (PR1 doc). Our own new tunables go in a named `const` block in the owning script: `StrategicMechanics.FOKUS_UNLOCK_GRADE`, `DUET_PAIR_SIZE` and `GameState.STAR_THRESHOLD_TOLERANCE`.
- No `theme_override_*` (layout constants excepted). No visual is built at runtime: every Fokus node lives in `FokusRow.tscn`. `viewport_editability` counts `.new()` on Controls.
- Every script has a `##` file header, and every `@export` a `##` line (`script_documentation`).
- UI text is Indonesian. Placeholder copy is marked by a `## [PLACEHOLDER]` comment and listed in DEBT, never shown in-game.
- No new persistence. `weekly_fokus` is session state like the rest of the run.
- Suites are `@tool`, `extends McpTestSuite`, and declare `suite_name()`. **No test awaits.** A `@tool` script the runner instances gates its real side effects behind `if Engine.is_editor_hint(): return`, and leaves its signal wiring ungated.
- Conventional Commits with a scope: `feat(simulation): …`, `feat(gamestate): …`, `feat(atur-jadwal): …`, `test(balance): …`, `refactor(simulation): …`.

**Mechanics rules.**

- Multiplier order: `base → duet → fokus → diminishing → quirks/personality`. The product scales `base_gain` and `specialty_bonus` before `StudentData.apply_jadwal_activity`, which adds quirks and personality afterwards.
- Only skill categories (`Akademis`, `SeniBudaya`, `Olahraga`) take duet, Fokus and diminishing. Istirahat and Wirausaha never do.
- With `Balance.STRATEGIC_MECHANICS_ENABLED == false`, every `StrategicMechanics` function returns its identity value (1.0 or 0), the Fokus row is locked, and `win_threshold()` returns `Balance.STAR_WIN_THRESHOLD`. The flag therefore rolls back all of PR3, including the sliding threshold, as the spec's Rollback section says. Tests assert this.
- A test that flips the flag or any `Balance` static var restores it in `teardown()`, never inline.

**Editor discipline.**

- **[editor]** steps need the live editor through the godot-ai bridge (`scene_open`, `node_*`, `batch_execute`, `script_attach`, `scene_save`, `test_run`, `filesystem_manage`, screenshots). Only the controller does these. The bridge is single-client.
- **[code]** steps are plain file edits a subagent can do. Subagents never touch the bridge.
- In each task, scene work comes first and script work second. After every `scene_save`, run `git diff HEAD -- '*.gd'` and revert any stray tab flushes. If any `.gd` was patched since the editor last started, restart the editor before that task's first `scene_save`.
- After a [code] edit, run a no-op `script_patch` on each touched `.gd` before `test_run`, or the editor serves the stale script. After creating a `class_name` script (`StrategicMechanics`, `FokusRow`), run `project_manage(op="stop")` then `filesystem_manage(op="scan")` before any `project_run`.
- Never hand-edit `AturJadwal.tscn` while the editor is attached. Instance overrides serialise only on an instanced scene's ROOT, so every knob AturJadwal needs on FokusRow is an `@export` on FokusRow's root.
- Open `Scenes/MainMenu/MainMenu.tscn` before trusting any test result.

**Clean code** (`docs/superpowers/design/clean-code.md`; ⚙ = ratchet):

- **No type inference from an autoload** (`tests/test_project_hygiene.gd`, PRs #97/#98, 2026-09-28): never `var x := GameState.…` or `:=` on any autoload call (ItemDatabase, GameSettings, …); declare the type, e.g. `var money: int = GameState.player_money`. A cold editor restart once left such results untyped, which makes `:=` a parse error.
- **Type everything ⚙.** This covers every `var` (`:=` only when the right side is obvious), every parameter and every `-> ReturnType`, including `-> void`. Loop variables are typed (`for student: StudentData in students`). New scripts start at zero debt.
- **No magic numbers ⚙.** Inline, only `0`, `1`, `2`, `-1` and `0.5`. Tuning comes from `Balance.gd`. Our own logic numbers go in a named const block with a `##` line. Layout goes in the `.tscn`. Colours come from `DesignTokens`.
- **Functions ≤ 50 code lines ⚙, one job each.** `apply_daily_decay_all` becomes a table of contents (Task 3).
- **Guard clauses and early `return`.** A repeated awaiting step is a loop, never recursion.
- **No duplicated 5+-line bodies ⚙.** There is one `normalize_category` and one per-grade gain lookup (`ActivityPreview.base_gain`/`favorit_bonus`); `StudentManager`'s copy goes. There is one earnings accrual helper.
- **Signals up, calls down.** `FokusRow` writes `GameState.weekly_fokus` (the source of truth) and announces `fokus_changed`. It never touches AturJadwal. AturJadwal listens through a connection authored in `AturJadwal.tscn`.
- **Node refs** are `@onready var x: Type = %UniqueName`. Every node `FokusRow.gd` touches gets `unique_name_in_owner`, prefixed `Fokus…`.
- **Fail loudly.** A missing chip is a typed `@onready` failing at once, never a silent `if node:` skip. An unknown category is a `push_error`.
- **No commented-out code. Boy Scout:** a function you touch ends typed, with its bare numbers named: `SchoolDay._on_back_pressed`, `GameState.check_semester_passed`, `ObjectiveHint.progress_percent`, `CutScene`'s `cg_data`.
- **No new legacy stat keys ⚙.** No file may gain an `akademis[123]` or `kepribadian[12]` key in any form, tests included. Use `akademis`/`seni_budaya`/`olahraga`/`mood`/`energy`.
- **Large scripts never grow ⚙.** `AturJadwal.gd` ≤ 1626, `SchoolDay.gd` ≤ 1638 and `StudentCard.gd` ≤ 1451 (blank and comment lines count). Check `wc -l` before every commit that touches one.
- **Ratchet stays green.** Every task that edits code ends with [editor] `test_run(suite="clean_code")`.
  - If it reports **shrank**, lock the gain in the same commit:
    `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd`
    Then `git diff ci/clean_code_baseline.gd` must only lower numbers or remove entries. Then run a no-op `script_patch` of the baseline so the editor re-reads it.
  - If you **moved, renamed or split** a function or script that has a baseline entry, run the same command with `-- --rekey`. The diff must show the same numbers under the new keys, and each piece of a split must be smaller than the original. Put its warnings in the PR description.
  - If the dump prints `RAISED (review):`, that is new debt. Fix the code; a re-key never hides it.
  - **Expected baseline diffs** (all lowering; no re-key expected, because no debt-carrying function is renamed):

    | Task | Baseline entries that go down |
    |---|---|
    | 2 | `SchoolDay.gd` UNTYPED (78); `GameState.gd` UNTYPED (9) if touched lines were untyped |
    | 3 | `StudentManager.gd::apply_daily_decay_all` LONG (90, removed once ≤ 50); `StudentManager.gd` UNTYPED (38) and BARE (31) |
    | 6 | `ObjectiveHint.gd` BARE (4); `GameState.gd` BARE (21) |
    | 8 | `AturJadwal.gd` LARGE (1626, now ≈1622); UNTYPED (198) and BARE (90) may drop |
    | 9 | `CutScene.gd` UNTYPED (14) and BARE (7) |

    Anything else moving is a surprise; investigate it.

## Orientation (do this first)

Key anchors, verified on `Textures` @ `b2890588`:

- `Scripts/SchoolSimulation/StudentManager.gd` (341 lines):
  - Header L4-14 says "instantiates one per day", which is wrong: it is one per week.
  - `_weekly_minigame_cap` L32.
  - `apply_daily_decay_all` L143-248:
    - The category-count pre-pass is L146-160.
    - The per-student normalisation is L170-178.
    - The Wirausaha accrual is L184-198 (`randi_range(Balance.WIRAUSAHA_UANG_MIN, …)`).
    - The grade gain lookup is L200-208, a duplicate of `ActivityPreview.base_gain`/`favorit_bonus`.
    - `apply_jadwal_activity(category, base_gain, specialty_bonus, same_subject_count)` is called at L209.
    - Logging is L225-237.
  - `initialize_from_gamestate` L266.
  - `apply_jadwal_effects_all` L280-298 is dead (zero callers).
- `Scripts/SchoolSimulation/StudentData.gd`: `apply_jadwal_activity` L283. The gain is `base_gain (+ specialty_bonus)`, then Kesunyian ×, then quirk flat adds. Izin rewrites the category to Istirahat at L291-294.
- `Scripts/SchoolSimulation/SchoolDay.gd` (1638 = cap):
  - `start_simulation` L275 makes the week's `StudentManager` at L286.
  - `_on_back_pressed` L1284 holds the only `GameState.minggu_ke += 1`, at L1294.
  - `DAYS` L109.
- `Scripts/GameState.gd` (641 lines):
  - `set_grade` L162, `forget_session` L397, `STAT_MAX` L430.
  - `run_stars` L586, `check_semester_passed` L599-602.
- `Scripts/AturJadwal/AturJadwal.gd` (1626 = cap):
  - `_ready` L162.
  - `_get_current_schedules` L544.
  - `_compute_pending_gain` L582-588, consumed by `_update_student_display` L687-689.
- `Scripts/AturJadwal/ActivityPreview.gd`: `SKILL_CATEGORIES` L28, `is_skill` L57, `base_gain` L62, `favorit_bonus` L71, `skill_gain` L80.
- `Scripts/AturJadwal/ObjectiveHint.gd`: `star_text` L50, `progress_percent` L56-59, both reading `Balance.STAR_WIN_THRESHOLD`.
- `Scenes/AturJadwal/AturJadwal.tscn`:
  - `ObjectiveStrip` covers y 846-942 (layout_mode 0, absolute offsets). AturJadwal is still 1080×1920-only (DEBT, "tall phones, Phases 2 and 3").
  - Category icons are `Assets/Images/StudentCard/stat_akademis.png`, `stat_senibudaya.png`, `stat_olahraga.png`, and the Wirausaha tile's `21_uang` texture.
- `Scripts/Design/ThemeFactory.gd`: `FilterChipButton` L1315-1328.
- `Scripts/CutScene/CutScene.gd`: untyped `cg_data` L38-60, read at L185/188/234/248-249.
- `Scripts/StudentCard/StudentCard.gd`: `max_approve_for` L97 (2/3/4). Read only.
- Tests touched:
  - `tests/test_atur_jadwal.gd` (`atur_jadwal`; `test_pending_gain_is_grade_aware` L534).
  - `tests/test_objective_hint.gd` (`objective_hint`, L98-104).
  - `tests/test_economy_state.gd` (`economy_state`, L320-351).
  - `tests/test_balance.gd` (`balance`, `_EXPECTED` L15; `test_the_expected_table_covers_every_number` L168).
  - `tests/test_balance_pacing.gd` (`balance_pacing`; its well-played policy puts all five days on one subject, L100).
  - `tests/test_cutscene.gd` (`cutscene`).
  - `tests/test_end_game_rehearsal.gd` (`end_game_rehearsal`).

Work on a branch off `Textures` (e.g. `feat/strategic-depth`). Each task ends green and is its own commit.

---

### Task 0: Gate — the collaborator's constants exist

**Files:**
- Modify (only if red): `tests/test_balance.gd`

- [ ] **Step 1 [code]: Check.** `grep -n "STRATEGIC_MECHANICS_ENABLED\|DIMINISHING_DAY_\|FOKUS_\|DUET_BONUS\|STAR_WIN_THRESHOLD_KELAS_" Scripts/Balance.gd` must list all 11 names. **If any is missing, stop.** Tell the human that PR3 is blocked on the collaborator, and do not add the constants yourself. Also record which pacing numbers they chose (weeks, targets, Wirausaha): PR1 or the 2026-09-28 week-length proposal. Tasks 6 and 10 read whatever landed.
- [ ] **Step 2 [editor]: Run `test_run(suite="balance")`.** The collaborator's commit adds fields, so `test_the_expected_table_covers_every_number` fails until `_EXPECTED` lists them. If it is red, add each new field to `_EXPECTED` **with the value `Balance.gd` actually holds**, grouped as `Balance.gd` groups them. Update the changed week/target/Wirausaha values the same way. The pin is our test file; the values are theirs.
- [ ] **Step 3: Commit** (only if Step 2 changed anything): `test(balance): pin the collaborator's strategic-depth constants`.

---

### Task 1: `StrategicMechanics` — the pure math

**Files:**
- Create: `Scripts/SchoolSimulation/StrategicMechanics.gd`
- Create: `tests/test_strategic_mechanics.gd`

**Interfaces (produced):** `StrategicMechanics.FOKUS_NONE`, `FOKUS_UNLOCK_GRADE`, `DUET_PAIR_SIZE`, `SCHOOL_DAYS`, `normalize_category()`, `diminishing_multiplier()`, `duet_multiplier()`, `is_fokus_unlocked()`, `effective_fokus()`, `fokus_multiplier()`, `study_multiplier()`, `wirausaha_payout_multiplier()`, `rest_coin()`.

- [ ] **Step 1 [code]: Failing tests.** Create `tests/test_strategic_mechanics.gd`:

```gdscript
@tool
extends McpTestSuite

## StrategicMechanics' pure math (balance-and-depth spec, PR3 A/C/D): diminishing
## returns, the duet bonus, the weekly Fokus, the Fokus-Wirausaha payout and the
## master flag. No coroutines. The flag is restored in teardown(), never inline.

func suite_name() -> String:
	return "strategic_mechanics"

var _snap_enabled: bool

func setup() -> void:
	_snap_enabled = Balance.STRATEGIC_MECHANICS_ENABLED
	Balance.STRATEGIC_MECHANICS_ENABLED = true

func teardown() -> void:
	Balance.STRATEGIC_MECHANICS_ENABLED = _snap_enabled

func test_days_one_and_two_are_full_gain() -> void:
	assert_eq(StrategicMechanics.diminishing_multiplier(1), 1.0)
	assert_eq(StrategicMechanics.diminishing_multiplier(2), 1.0)

func test_days_three_to_five_diminish() -> void:
	assert_eq(StrategicMechanics.diminishing_multiplier(3), Balance.DIMINISHING_DAY_3)
	assert_eq(StrategicMechanics.diminishing_multiplier(4), Balance.DIMINISHING_DAY_4)
	assert_eq(StrategicMechanics.diminishing_multiplier(5), Balance.DIMINISHING_DAY_5)

func test_duet_needs_exactly_a_pair() -> void:
	assert_eq(StrategicMechanics.duet_multiplier("Akademis", 1), 1.0, "solo")
	assert_eq(StrategicMechanics.duet_multiplier("Akademis", 2), 1.0 + Balance.DUET_BONUS, "pair")
	assert_eq(StrategicMechanics.duet_multiplier("Akademis", 3), 1.0, "a crowd is not a duet")

func test_duet_never_touches_rest_or_trade() -> void:
	assert_eq(StrategicMechanics.duet_multiplier("Istirahat", 2), 1.0)
	assert_eq(StrategicMechanics.duet_multiplier("Wirausaha", 2), 1.0)

func test_fokus_match_and_mismatch() -> void:
	assert_eq(StrategicMechanics.fokus_multiplier("Akademis", StrategicMechanics.FOKUS_NONE), 1.0)
	assert_eq(StrategicMechanics.fokus_multiplier("Akademis", "Akademis"), 1.0 + Balance.FOKUS_BONUS)
	assert_eq(StrategicMechanics.fokus_multiplier("SeniBudaya", "Akademis"), 1.0 - Balance.FOKUS_PENALTY)

func test_wirausaha_fokus_penalises_skills_and_leaves_itself_alone() -> void:
	assert_eq(StrategicMechanics.fokus_multiplier("Akademis", "Wirausaha"), 1.0 - Balance.FOKUS_PENALTY)
	assert_eq(StrategicMechanics.fokus_multiplier("Wirausaha", "Wirausaha"), 1.0,
		"Wirausaha's Fokus bonus is paid in money (wirausaha_payout_multiplier), not skill")

func test_fokus_is_locked_below_the_unlock_grade() -> void:
	assert_false(StrategicMechanics.is_fokus_unlocked(StrategicMechanics.FOKUS_UNLOCK_GRADE - 1))
	assert_true(StrategicMechanics.is_fokus_unlocked(StrategicMechanics.FOKUS_UNLOCK_GRADE))
	assert_eq(StrategicMechanics.effective_fokus(7, "Akademis"), StrategicMechanics.FOKUS_NONE)
	assert_eq(StrategicMechanics.effective_fokus(8, "Akademis"), "Akademis")

func test_wirausaha_payout_and_rest_coin() -> void:
	assert_eq(StrategicMechanics.wirausaha_payout_multiplier("Wirausaha"), 1.0 + Balance.FOKUS_WIRAUSAHA_BONUS)
	assert_eq(StrategicMechanics.wirausaha_payout_multiplier("Akademis"), 1.0)
	assert_eq(StrategicMechanics.rest_coin("Wirausaha"), Balance.FOKUS_WIRAUSAHA_REST_COIN)
	assert_eq(StrategicMechanics.rest_coin(StrategicMechanics.FOKUS_NONE), 0)

func test_study_multiplier_composes_in_spec_order() -> void:
	var expected: float = (1.0 + Balance.DUET_BONUS) * (1.0 + Balance.FOKUS_BONUS) * Balance.DIMINISHING_DAY_3
	assert_true(is_equal_approx(StrategicMechanics.study_multiplier("Akademis", "Akademis", 2, 3), expected))

func test_flag_off_makes_every_mechanic_identity() -> void:
	Balance.STRATEGIC_MECHANICS_ENABLED = false
	for day_count: int in range(1, 6):
		assert_eq(StrategicMechanics.diminishing_multiplier(day_count), 1.0)
	assert_eq(StrategicMechanics.duet_multiplier("Akademis", 2), 1.0)
	assert_eq(StrategicMechanics.fokus_multiplier("SeniBudaya", "Akademis"), 1.0)
	assert_eq(StrategicMechanics.wirausaha_payout_multiplier("Wirausaha"), 1.0)
	assert_eq(StrategicMechanics.rest_coin("Wirausaha"), 0)
	assert_false(StrategicMechanics.is_fokus_unlocked(9))

func test_normalize_category_maps_legacy_schedule_names() -> void:
	assert_eq(StrategicMechanics.normalize_category("Akademik"), "Akademis")
	assert_eq(StrategicMechanics.normalize_category("DayOff"), "Istirahat")
	assert_eq(StrategicMechanics.normalize_category("Olahraga"), "Olahraga")
```

- [ ] **Step 2 [editor]:** `filesystem_manage(op="scan")`, then `test_run(suite="strategic_mechanics")`. Expect it to FAIL: the class does not exist yet.
- [ ] **Step 3 [code]: Implement** `Scripts/SchoolSimulation/StrategicMechanics.gd`:

```gdscript
@tool
class_name StrategicMechanics
extends RefCounted

## The scheduling mechanics of the balance-and-depth spec (PR3) as pure math:
## diminishing returns (A), the weekly Fokus (C), the duet bonus (D) and the
## Fokus-Wirausaha payout. No nodes, no state. StudentManager applies these to
## the simulated week and ActivityPreview.week_skill_gain to AturJadwal's
## projection, so the week the player previews is the week that runs.
##
## The tuning numbers are Balance.gd's (collaborator-owned). The constants
## below are ours. With Balance.STRATEGIC_MECHANICS_ENABLED false every
## function returns its identity value, which is the spec's one-flag rollback.

## GameState.weekly_fokus when no Fokus is picked.
const FOKUS_NONE := "None"
## The first grade whose AturJadwal offers the Fokus row (spec: "unlocks G8").
const FOKUS_UNLOCK_GRADE := 8
## Exactly this many students on one skill on one day earn the duet bonus.
## Three or more do not: Penyendiri already prices a crowd.
const DUET_PAIR_SIZE := 2
## The school week, in simulation order. Diminishing returns count days in this order.
const SCHOOL_DAYS: Array[String] = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]


## Schedules may still hold the pre-rename names; the simulation reads these.
static func normalize_category(raw: String) -> String:
	match raw:
		"Akademik":
			return "Akademis"
		"DayOff":
			return "Istirahat"
	return raw


## Gain multiplier for a student's Nth day of one skill category this week.
static func diminishing_multiplier(day_count: int) -> float:
	if not Balance.STRATEGIC_MECHANICS_ENABLED:
		return 1.0
	var by_day: Array[float] = [1.0, 1.0, Balance.DIMINISHING_DAY_3,
		Balance.DIMINISHING_DAY_4, Balance.DIMINISHING_DAY_5]
	return by_day[clampi(day_count, 1, by_day.size()) - 1]


## Gain multiplier for a skill day shared by `same_category_count` students.
static func duet_multiplier(category: String, same_category_count: int) -> float:
	if not Balance.STRATEGIC_MECHANICS_ENABLED or not ActivityPreview.is_skill(category):
		return 1.0
	if same_category_count != DUET_PAIR_SIZE:
		return 1.0
	return 1.0 + Balance.DUET_BONUS


## Whether this grade's AturJadwal offers the Fokus row.
static func is_fokus_unlocked(grade: int) -> bool:
	return Balance.STRATEGIC_MECHANICS_ENABLED and grade >= FOKUS_UNLOCK_GRADE


## The Fokus that applies this week: the picked one, or none while locked.
static func effective_fokus(grade: int, picked: String) -> String:
	if not is_fokus_unlocked(grade):
		return FOKUS_NONE
	return picked


## Gain multiplier for a skill day under the week's Fokus.
static func fokus_multiplier(category: String, fokus: String) -> float:
	if not Balance.STRATEGIC_MECHANICS_ENABLED or not ActivityPreview.is_skill(category):
		return 1.0
	if fokus == FOKUS_NONE:
		return 1.0
	if fokus == category:
		return 1.0 + Balance.FOKUS_BONUS
	return 1.0 - Balance.FOKUS_PENALTY


## The whole mechanics multiplier for one study day, in the spec's order
## (duet, then Fokus, then diminishing); quirks and personality come after it.
static func study_multiplier(category: String, fokus: String,
		same_category_count: int, day_count: int) -> float:
	return duet_multiplier(category, same_category_count) \
		* fokus_multiplier(category, fokus) \
		* diminishing_multiplier(day_count)


## Multiplier on each Wirausaha day's earnings.
static func wirausaha_payout_multiplier(fokus: String) -> float:
	if not Balance.STRATEGIC_MECHANICS_ENABLED or fokus != "Wirausaha":
		return 1.0
	return 1.0 + Balance.FOKUS_WIRAUSAHA_BONUS


## Flat coins a scheduled Istirahat day adds to pending_earnings.
static func rest_coin(fokus: String) -> int:
	if not Balance.STRATEGIC_MECHANICS_ENABLED or fokus != "Wirausaha":
		return 0
	return Balance.FOKUS_WIRAUSAHA_REST_COIN
```

  `SCHOOL_DAYS` is a fifth copy of the weekday list (`SchoolDay.DAYS`, `StudentList.REQUIRED_DAYS`, AturJadwal's local lists). It is a const, not a duplicated body, so the ratchet ignores it. Consolidating the copies is out of scope.
- [ ] **Step 4 [editor]:** Run a no-op `script_patch` on both files. Then `project_manage(op="stop")` and `filesystem_manage(op="scan")`. Run `test_run(suite="strategic_mechanics")`: PASS. Run `test_run(suite="script_documentation")` and `test_run(suite="clean_code")`: both green. The new script has zero debt.
- [ ] **Step 5: Commit** `feat(simulation): StrategicMechanics, the PR3 depth math as pure functions`.

---

### Task 2: `GameState.weekly_fokus` and `advance_week()`

**Files:**
- Modify: `Scripts/GameState.gd` (not large)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (LARGE 1638: a one-line swap, net 0)
- Create: `tests/test_weekly_fokus.gd`

- [ ] **Step 1 [code]: Failing tests.** Create `tests/test_weekly_fokus.gd` (`suite_name()` `"weekly_fokus"`):
  - `setup()` snapshots `GameState.weekly_fokus`, `minggu_ke` and `current_grade`, and `teardown()` restores them.
  - **Never call `forget_session()` here.** It deletes the inventory save and resets Achievements. Scan its source instead.

```gdscript
func test_advance_week_moves_the_week_and_clears_the_fokus() -> void:
	var week: int = GameState.minggu_ke
	GameState.weekly_fokus = "Olahraga"
	GameState.advance_week()
	assert_eq(GameState.minggu_ke, week + 1)
	assert_eq(GameState.weekly_fokus, StrategicMechanics.FOKUS_NONE)

func test_set_grade_clears_the_fokus() -> void:
	GameState.weekly_fokus = "Akademis"
	GameState.set_grade(GameState.current_grade)  # same grade: no roster rebase
	assert_eq(GameState.weekly_fokus, StrategicMechanics.FOKUS_NONE)

func test_forget_session_clears_the_fokus() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var body: String = src.get_slice("func forget_session", 1).get_slice("\nfunc ", 0)
	assert_true(body.contains("weekly_fokus = StrategicMechanics.FOKUS_NONE"))

func test_school_day_ends_the_week_through_advance_week() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/SchoolDay.gd")
	assert_true(src.contains("GameState.advance_week()"))
	assert_false(src.contains("GameState.minggu_ke += 1"),
		"the week must move in one place, or the Fokus outlives its week")
```

- [ ] **Step 2 [editor]:** `test_run(suite="weekly_fokus")`: FAIL.
- [ ] **Step 3 [code]: Implement.** In `Scripts/GameState.gd`, next to `minggu_ke`, add:

```gdscript
## The week's Fokus category (StrategicMechanics), or FOKUS_NONE. Session
## state like the rest of the run; advance_week() clears it.
var weekly_fokus: String = StrategicMechanics.FOKUS_NONE

## Ends the current week. The one place the week counter moves forward, so
## per-week state (the Fokus) resets with it.
func advance_week() -> void:
	minggu_ke += 1
	weekly_fokus = StrategicMechanics.FOKUS_NONE
```

  Then:
  - Add `weekly_fokus = StrategicMechanics.FOKUS_NONE` to `set_grade()` (after `minggu_ke = 1`) and to `forget_session()` (after `minggu_ke = 1`).
  - In `SchoolDay._on_back_pressed`, replace `GameState.minggu_ke += 1` with `GameState.advance_week()`.
  - Boy Scout, same function: type `var completed_week: int`, `var tween: Tween` and `var max_weeks: int`. That adds no lines.
  - Confirm `wc -l Scripts/SchoolSimulation/SchoolDay.gd` is still ≤ 1638.
  - The `class_name` reference is typed explicitly (memory: cold-start inference). If `GameState` fails to load after a restart, read `logs_read(source="editor")` before anything else.
- [ ] **Step 4 [editor]:** Run a no-op `script_patch` on `GameState.gd` and `SchoolDay.gd`. Then:
  - `test_run(suite="weekly_fokus")`: PASS.
  - `test_run(suite="economy_state")`: green.
  - `test_run(suite="end_game_rehearsal")`: green.
  - `test_run(suite="clean_code")`: expect a SchoolDay UNTYPED shrink. Run the dump and review the baseline diff.
- [ ] **Step 5: Commit** `feat(gamestate): weekly Fokus state, reset by the new advance_week()`.

---

### Task 3: Split `apply_daily_decay_all` (pure refactor, no behaviour change)

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd`

The function is 90 lines, a `LONG_FUNCTIONS` entry, so the mechanics cannot be added to it. Split it first, with identical behaviour and the same RNG call order. The regression net is the existing suites.

- [ ] **Step 1 [code]: Split** into typed helpers of ≤ 50 lines each. Move lines verbatim, then type them:

```gdscript
## One school day for the whole roster: personality decay, then each
## student's scheduled activity. Returns one summary row per student.
func apply_daily_decay_all(day_name: String) -> Array[Dictionary]:
	var category_counts: Dictionary = _count_categories(day_name)
	var decay_results: Array[Dictionary] = []
	for student: StudentData in students:
		decay_results.append(_simulate_student_day(student, day_name, category_counts))
	return decay_results
```

  Helpers:
  - `_scheduled_category(student_id: int, day_name: String) -> String` returns the schedule's category through `StrategicMechanics.normalize_category`, or `""` when nothing is scheduled. It replaces both inline normalisations.
  - `_activity_category(student_id: int, day_name: String) -> String` returns `_scheduled_category(...)`, or `REST_CATEGORY` when that is empty. Add `## What an unscheduled day becomes.` `const REST_CATEGORY := "Istirahat"`.
  - `_count_categories(day_name: String) -> Dictionary` is the old pre-pass.
  - `_simulate_student_day(student: StudentData, day_name: String, category_counts: Dictionary) -> Dictionary` does the decay, dispatches the activity, logs, and builds the result row.
  - `_apply_wirausaha_day(student: StudentData, day_name: String) -> Dictionary` is the old L184-198. It returns `{energy_loss, mood_loss, reason}`.
  - `_apply_study_day(student: StudentData, day_name: String, category: String, same_category_count: int) -> Dictionary`:
    - It is the old L199-223, with the grade lookup replaced by `ActivityPreview.base_gain(grade)` / `ActivityPreview.favorit_bonus(grade)`. Those are identical for grades 7–9. Only the unreachable out-of-range fallback changes, from `…KELAS_7` to `…CADANGAN`. Say so in the commit body.
    - It calls `student.apply_jadwal_activity(category, base_gain, specialty_bonus, same_category_count)`.
  - `_add_earnings(student_id: int, amount: int) -> void` is the one `GameState.pending_earnings` accrual.
  - `_log_activity(day_name: String, student: StudentData, category: String, result: Dictionary) -> void` is the old L228-237.

  Bare numbers:
  - `student.energy / 100.0` → `GameState.STAT_MAX`.
  - `clampf(…, 0.0, 100.0)` → `GameState.STAT_MAX`.

  Also:
  - **Preserve the logging exactly.** Istirahat logs its recovery once inside the net `"decay"` row and again as `"activity"`. That looks double-counted, but it is a separate bug: add a DEBT "Known bugs" line and do not fix it inside a refactor.
  - Delete the dead `apply_jadwal_effects_all`. First run `grep -rn "apply_jadwal_effects_all" Scripts Scenes tests`; it must show only the definition.
  - Fix the header: "SchoolDay.gd instantiates one per **week** (`start_simulation()`)". Keep the rest.
- [ ] **Step 2 [editor]:** Run a no-op `script_patch` on `StudentManager.gd`. Then:
  - `test_run(suite="balance_pacing")`: green. It drives `apply_daily_decay_all` on seeded RNG, so any change in the order of random calls shows here.
  - `test_run(suite="wirausaha")`: green.
  - `test_run(suite="economy_state")`: green.
  - `test_run(suite="clean_code")`: expect **shrank**. The `apply_daily_decay_all` LONG entry is removed, and UNTYPED/BARE are lower. Run the dump (default mode, no re-key: the function keeps its name). The diff may only lower or remove entries.
- [ ] **Step 3: Commit** `refactor(simulation): split apply_daily_decay_all into typed one-job helpers`.

---

### Task 4: Diminishing returns, duet and Fokus in the simulation

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd`
- Create: `tests/test_student_manager_mechanics.gd`

- [ ] **Step 1 [code]: Failing tests.** Create `tests/test_student_manager_mechanics.gd` (`suite_name()` `"student_manager_mechanics"`).
  - `setup()` snapshots `GameState.approved_students`, `day_schedules`, `current_grade`, `weekly_fokus`, `pending_earnings`, `minigame_gain_this_week` and `Balance.STRATEGIC_MECHANICS_ENABLED`, and sets the flag true. `teardown()` restores all of them.
  - Every `StudentManager.new()` is `track()`ed.
  - Fixture students use `personality "Santai"` and `quirk ""`, a `hobby_category` that is not the studied skill (so gain = `ActivityPreview.base_gain(grade)` exactly), `energy 100.0` and `mood 100.0`. Study gain is deterministic; only energy and mood are random.

```gdscript
func _student(id: int, hobby: String) -> Dictionary:
	return {"id": id, "name": "Murid %d" % id, "hobby_category": hobby,
		"personality": "Santai", "quirk": "", "akademis": 20.0,
		"seni_budaya": 20.0, "olahraga": 20.0, "mood": 100.0, "energy": 100.0}

func _schedule(days: Dictionary) -> Dictionary:  # {"Senin": "Akademis", ...}
	var per_day: Dictionary = {}
	for day_name: String in days:
		per_day[day_name] = {"category": days[day_name]}
	return per_day

func _week(grade: int) -> StudentManager:
	GameState.current_grade = grade
	var sm: StudentManager = track(StudentManager.new())
	sm.initialize_from_gamestate()
	return sm

func _akademis_gain(sm: StudentManager, day_name: String, index: int) -> float:
	var before: float = sm.students[index].akademis
	sm.apply_daily_decay_all(day_name)
	return sm.students[index].akademis - before
```

  Tests. Energy runs out around day 4 (then Izin), so the diminishing tests stop at day 3:
  - `test_third_day_of_one_skill_diminishes`: one student, Akademis Senin–Rabu, G7. Senin and Selasa each gain `base_gain(7)`. Rabu gains `base_gain(7) * Balance.DIMINISHING_DAY_3` (`is_equal_approx`).
  - `test_other_skill_and_other_student_are_counted_apart`: student 1 has Akademis Senin–Selasa and SeniBudaya Rabu, so Rabu's SeniBudaya gain is full. Student 2 does not share the day, so there is no duet.
  - `test_pair_on_one_skill_gets_the_duet`: two students both on Akademis Senin. Each gains `base_gain(7) * (1 + DUET_BONUS)`.
  - `test_three_on_one_skill_get_no_duet`: G9, three students on Akademis Senin. Each gains `base_gain(9)`.
  - `test_fokus_applies_from_grade_eight`: G8, `weekly_fokus = "Akademis"`. The Akademis student gains `× (1 + FOKUS_BONUS)` and a SeniBudaya student gains `× (1 − FOKUS_PENALTY)`. At G7 with the same pick, nothing changes, because the Fokus is locked.
  - `test_izin_day_is_not_counted`: the student starts at energy 3 with Akademis Senin–Selasa. Senin is Izin, so after it `sm._studied_days(1, "Akademis") == 0`.
  - `test_flag_off_is_the_old_simulation`: flag false, the one-student Akademis Senin–Rabu week. Rabu gains full `base_gain(7)`.
- [ ] **Step 2 [editor]:** `test_run(suite="student_manager_mechanics")`: FAIL.
- [ ] **Step 3 [code]: Implement.** In `StudentManager.gd`:

```gdscript
## Days each student has actually studied each skill this week, as
## {student_id: {category: days}}. A StudentManager lives one week, so this
## starts clean. Izin days are not counted.
var _studied_days_this_week: Dictionary = {}
## This week's Fokus as it applies (none while locked), read once per week.
var _fokus: String = StrategicMechanics.FOKUS_NONE

## Called by initialize_from_gamestate(): the week's clean slate.
func _begin_week() -> void:
	_studied_days_this_week.clear()
	_fokus = StrategicMechanics.effective_fokus(GameState.current_grade, GameState.weekly_fokus)

func _studied_days(student_id: int, category: String) -> int:
	var per_student: Dictionary = _studied_days_this_week.get(student_id, {})
	return int(per_student.get(category, 0))

func _mark_studied_day(student_id: int, category: String, day_count: int) -> void:
	if not _studied_days_this_week.has(student_id):
		_studied_days_this_week[student_id] = {}
	_studied_days_this_week[student_id][category] = day_count
```

  Call `_begin_week()` at the end of `initialize_from_gamestate()`, on both branches. In `_apply_study_day`, fold the multiplier in before the call:

```gdscript
	var grade: int = GameState.current_grade
	var day_count: int = _studied_days(student.id, category) + 1
	var multiplier: float = StrategicMechanics.study_multiplier(
		category, _fokus, same_category_count, day_count)
	var result: Dictionary = student.apply_jadwal_activity(category,
		ActivityPreview.base_gain(grade) * multiplier,
		ActivityPreview.favorit_bonus(grade) * multiplier, same_category_count)
	if ActivityPreview.is_skill(category) and not bool(result.get("took_ijin", false)):
		_mark_studied_day(student.id, category, day_count)
```

  `same_category_count` is the existing `category_counts` value. The duet reuses it and counts nothing new.
- [ ] **Step 4 [editor]:** Run a no-op `script_patch`. Then:
  - `test_run(suite="student_manager_mechanics")`: PASS.
  - `test_run(suite="strategic_mechanics")`: green.
  - `test_run(suite="clean_code")`: green.
  - `balance_pacing` is **expected to go red now**. Its well-played policy puts five days on one subject, which the mechanic now punishes. That suite is re-tuned in Task 10. Note it in the commit body; do not loosen it here.
- [ ] **Step 5: Commit** `feat(simulation): diminishing returns, duet bonus and weekly Fokus in the daily gain`.

---

### Task 5: Fokus-Wirausaha payout and rest coin

**Files:**
- Modify: `Scripts/SchoolSimulation/StudentManager.gd`
- Modify: `tests/test_student_manager_mechanics.gd`

- [ ] **Step 1 [code]: Failing tests** in `student_manager_mechanics`:
  - `test_wirausaha_fokus_raises_the_day_s_earnings`: G8, one student with Wirausaha Senin.
    - Run it with `seed(1234)` and `weekly_fokus = FOKUS_NONE`, and read `pending_earnings[1]`.
    - Reset `pending_earnings`, then run it again with `seed(1234)` and `weekly_fokus = "Wirausaha"`.
    - Assert `absi(with_fokus - roundi(without * (1.0 + Balance.FOKUS_WIRAUSAHA_BONUS))) <= 1`. The Fokus consumes no RNG, so both runs draw the same numbers.
  - `test_wirausaha_fokus_pays_a_rest_coin_per_scheduled_istirahat`: G8, Wirausaha Fokus, one student with Istirahat Senin. `pending_earnings[1] == Balance.FOKUS_WIRAUSAHA_REST_COIN`.
  - `test_unscheduled_day_earns_no_rest_coin`: same setup, but nothing is scheduled Senin (a holiday is unscheduled). `pending_earnings` has no entry.
  - `test_other_fokus_pays_no_rest_coin`: Akademis Fokus with Istirahat Senin. No entry.
- [ ] **Step 2 [editor]:** `test_run(suite="student_manager_mechanics")`: the new tests FAIL.
- [ ] **Step 3 [code]: Implement.**
  - In `_apply_wirausaha_day`, the earning becomes `roundi(randi_range(Balance.WIRAUSAHA_UANG_MIN, Balance.WIRAUSAHA_UANG_MAX) * multiplier * StrategicMechanics.wirausaha_payout_multiplier(_fokus))`. Keep the `randi_range` call exactly where it is.
  - In `_simulate_student_day`, when `_scheduled_category(student.id, day_name) == REST_CATEGORY`, call `_add_earnings(student.id, StrategicMechanics.rest_coin(_fokus))`. `_add_earnings` returns early on 0.
  - Achievements' `effect_multiplier("wirausaha")` still scales the whole payout in `SchoolDay._pay_out_wirausaha`, rest coins included. That is intended, and nothing changes in SchoolDay.
- [ ] **Step 4 [editor]:** Run a no-op `script_patch`. Then `test_run(suite="student_manager_mechanics")`, `test_run(suite="wirausaha")` and `test_run(suite="clean_code")`: all green.
- [ ] **Step 5: Commit** `feat(simulation): Wirausaha Fokus raises trade earnings and pays a rest coin`.

---

### Task 6: Sliding star threshold

**Files:**
- Modify: `Scripts/GameState.gd`, `Scripts/AturJadwal/ObjectiveHint.gd`
- Modify: `tests/test_economy_state.gd`, `tests/test_objective_hint.gd`
- Create: `tests/test_sliding_threshold.gd`

- [ ] **Step 1 [code]: Failing tests.** Create `tests/test_sliding_threshold.gd` (`suite_name()` `"sliding_threshold"`).
  - `setup()`/`teardown()` snapshot `approved_students`, `current_grade`, the flag and the three `Balance.STAR_WIN_THRESHOLD_KELAS_*`.
  - Helper `_roster(students: int, cleared: int)`: each student has `target_akademis/seni_budaya/olahraga = 50.0`. The first `cleared` targets hold 60.0; the rest hold 40.0.
  - The expectations come from Balance, so they hold for whatever values the collaborator chose:

```gdscript
## StudentCard.gd has no class_name; preload it the way LevelSelect does.
const _STUDENT_CARD := preload("res://Scripts/StudentCard/StudentCard.gd")

## The fewest targets of `total` that pass `threshold` at this tolerance.
func _needed(threshold: float, total: int) -> int:
	return ceili((threshold - GameState.STAR_THRESHOLD_TOLERANCE) * total / Balance.STARS_TOTAL)

func test_each_grade_passes_at_its_own_line_and_fails_one_below() -> void:
	for grade: int in [7, 8, 9]:
		GameState.current_grade = grade
		var students: int = _STUDENT_CARD.max_approve_for(grade)
		var total: int = students * 3
		var need: int = _needed(GameState.win_threshold(), total)
		_roster(students, need)
		assert_true(GameState.check_semester_passed(), "G%d passes at %d/%d" % [grade, need, total])
		_roster(students, need - 1)
		assert_false(GameState.check_semester_passed(), "G%d fails at %d/%d" % [grade, need - 1, total])
```

  Plus:
  - `test_thresholds_come_from_balance`: `win_threshold_for_grade(7/8/9)` returns `Balance.STAR_WIN_THRESHOLD_KELAS_7/8/9`.
  - `test_two_decimal_line_passes_a_repeating_share`: set `Balance.STAR_WIN_THRESHOLD_KELAS_8 = 1.67`, then 5 of 9 (1.666…) passes at G8.
  - `test_flag_off_restores_the_single_line`: flag false. Every grade's `win_threshold()` equals `Balance.STAR_WIN_THRESHOLD`.


  Existing tests:
  - `economy_state`: the threshold tests (L320-351) pin `current_grade = 7`, with a snapshot and restore.
  - `objective_hint` L98-104: `Balance.STAR_WIN_THRESHOLD` → `GameState.win_threshold()`, with the grade pinned.
- [ ] **Step 2 [editor]:** `test_run(suite="sliding_threshold")`: FAIL.
- [ ] **Step 3 [code]: Implement.** In `GameState.gd`, beside `run_stars`:

```gdscript
## Stars are shares of a whole (7 of 12 targets is 1.75), while Balance writes
## each grade's pass line to two decimals: 5 of 9 is 1.666…, which must pass a
## 1.67 line.
const STAR_THRESHOLD_TOLERANCE := 0.01

## The grade's pass line. With the depth mechanics off it is the old single line.
func win_threshold_for_grade(grade: int) -> float:
	if not Balance.STRATEGIC_MECHANICS_ENABLED:
		return Balance.STAR_WIN_THRESHOLD
	match grade:
		8:
			return Balance.STAR_WIN_THRESHOLD_KELAS_8
		9:
			return Balance.STAR_WIN_THRESHOLD_KELAS_9
	return Balance.STAR_WIN_THRESHOLD_KELAS_7

## This run's pass line.
func win_threshold() -> float:
	return win_threshold_for_grade(current_grade)
```

  Then:
  - `check_semester_passed()` returns `run_stars() >= win_threshold() - STAR_THRESHOLD_TOLERANCE`. Update its `##` comment.
  - `ObjectiveHint.star_text`/`progress_percent` read `GameState.win_threshold()` instead of `Balance.STAR_WIN_THRESHOLD`. Boy Scout: name `100.0` as `const PERCENT_FULL := 100.0` with a `##` line.
  - Update the `EndGameRehearsal.gd` comment that says "2.0-star threshold" so it names `GameState.win_threshold()`. It is a comment only.
- [ ] **Step 4 [editor]:** Run a no-op `script_patch` on each touched `.gd`. Then:
  - `test_run(suite="sliding_threshold")`: PASS.
  - `test_run` on `economy_state`, `objective_hint`, `end_game_rehearsal` and `balance_pacing`: all green except `balance_pacing` (see Task 4).
  - `test_run(suite="clean_code")`: run the dump on a shrink.
- [ ] **Step 5: Commit** `feat(gamestate): per-grade star pass line behind the strategic flag`.

---

### Task 7: `FokusRow` component

**Files:**
- Create: `Scenes/AturJadwal/FokusRow.tscn`, `Scripts/AturJadwal/FokusRow.gd`
- Create: `tests/test_fokus_row.gd`

- [ ] **Step 1 [editor]: Scene first.** Build `Scenes/AturJadwal/FokusRow.tscn` with `scene_manage`/`batch_execute`, then `scene_save`:

```
FokusRow            VBoxContainer   (script attached in Step 4)
├─ Caption          Label           CaptionLabel   "Fokus Minggu Ini"
├─ Chips            HBoxContainer   separation (layout constant only)
│  ├─ %FokusAkademis    Button  FilterChipButton  toggle_mode, button_group=FokusGroup, text "Akademis",  icon stat_akademis.png
│  ├─ %FokusSeniBudaya  Button  FilterChipButton  … text "Seni",      icon stat_senibudaya.png
│  ├─ %FokusOlahraga    Button  FilterChipButton  … text "Olahraga",  icon stat_olahraga.png
│  └─ %FokusWirausaha   Button  FilterChipButton  … text "Wirausaha", icon (the picker's Wirausaha tile texture)
├─ %FokusLockedNote Label           MicroLabel     (text set by script; hidden)
└─ %FokusIntroNote  Label           CaptionLabel   (text set by script; hidden)
```

  Scene details:
  - `FokusGroup` is one `ButtonGroup` sub-resource with `allow_unpress = true`, so one chip at most can be on and tapping it again clears it.
  - The chip icons stay white glyphs (`FilterChipButton` inks them; ThemeFactory L1321).
  - Size the row in the scene. Its placement in AturJadwal is Task 8's.
- [ ] **Step 2 [code]: Failing tests.** Create `tests/test_fokus_row.gd` (`suite_name()` `"fokus_row"`):
  - Instance the scene once in `suite_setup`, add it to `Engine.get_main_loop().root`, and free it in `suite_teardown`. That is the memory's advice for full-run stability. `_ready` gates its GameState read, so the tests call `refresh()` directly.
  - `setup()`/`teardown()` snapshot `weekly_fokus`, `current_grade` and the flag.

  Tests:
  - `test_scene_shape`: the four `Fokus*` chips exist, are `FilterChipButton` with `toggle_mode`, share one `ButtonGroup` with `allow_unpress`, and `FokusLockedNote` and `FokusIntroNote` exist.
  - `test_locked_below_unlock_grade`: G7, then `refresh()`. Every chip is disabled and the locked note is visible.
  - `test_unlocked_from_grade_eight`: G8, then `refresh()`. The chips are enabled and the locked note is hidden. With `weekly_fokus` none the intro note is visible; once a Fokus is set, `refresh()` hides it.
  - `test_pressing_a_chip_writes_gamestate_and_announces`: connect `fokus_changed` to a counter lambda. `_on_chip_toggled(true, "Olahraga")` → `weekly_fokus == "Olahraga"`, and the counter is > 0. `_on_chip_toggled(false, "Olahraga")` → `FOKUS_NONE`.
  - `test_refresh_reflects_the_picked_fokus`: `weekly_fokus = "SeniBudaya"`, then `refresh()`. Only `%FokusSeniBudaya.button_pressed`.
  - `test_flag_off_locks_the_row`: flag false at G9, then `refresh()`. All chips are disabled.
- [ ] **Step 3 [editor]:** `test_run(suite="fokus_row")`: FAIL. There is no script yet.
- [ ] **Step 4 [code] then [editor]: Implement** `Scripts/AturJadwal/FokusRow.gd`. It is a new file, not open in any editor tab. Then `filesystem_manage(op="scan")`, `script_attach` it to the scene's root, `scene_save`, and `git diff HEAD -- '*.gd'`.

```gdscript
@tool
class_name FokusRow
extends VBoxContainer

## AturJadwal's "Fokus Minggu Ini" row (balance-and-depth spec, PR3 C): four
## toggle chips in one ButtonGroup, at most one on. It writes the pick to
## GameState.weekly_fokus, the source of truth, and announces fokus_changed so
## AturJadwal re-projects the week. It never reaches into AturJadwal. Locked
## below StrategicMechanics.FOKUS_UNLOCK_GRADE; while nothing is picked, the
## intro note teaches the trade.
##
## @tool so the test runner can instance it. The chip wiring runs everywhere;
## the GameState read in _ready is gated behind Engine.is_editor_hint().

## The player picked, switched or cleared the week's Fokus.
signal fokus_changed

## [PLACEHOLDER] copy (DEBT, "Audio and copy").
const LOCKED_TEXT := "Terbuka di Kelas %d"
## [PLACEHOLDER] copy. Filled with Balance's bonus and penalty, as percents.
const INTRO_TEXT := "Pilih satu fokus: kegiatannya naik %d%%, kegiatan lain turun %d%%."
## Balance writes the Fokus bonus as a fraction; the note shows percent.
const PERCENT := 100.0

@onready var _akademis: Button = %FokusAkademis
@onready var _seni_budaya: Button = %FokusSeniBudaya
@onready var _olahraga: Button = %FokusOlahraga
@onready var _wirausaha: Button = %FokusWirausaha
@onready var _locked_note: Label = %FokusLockedNote
@onready var _intro_note: Label = %FokusIntroNote

## Schedule category -> its chip. Filled in _ready from the @onready refs.
var _chips: Dictionary = {}


func _ready() -> void:
	_chips = {"Akademis": _akademis, "SeniBudaya": _seni_budaya,
		"Olahraga": _olahraga, "Wirausaha": _wirausaha}
	for category: String in _chips:
		var chip: Button = _chips[category]
		chip.toggled.connect(_on_chip_toggled.bind(category))
	if Engine.is_editor_hint():
		return
	refresh()


## Re-reads GameState: lock state, the picked chip, and the two notes.
func refresh() -> void:
	var is_unlocked: bool = StrategicMechanics.is_fokus_unlocked(GameState.current_grade)
	for category: String in _chips:
		var chip: Button = _chips[category]
		chip.disabled = not is_unlocked
		chip.set_pressed_no_signal(GameState.weekly_fokus == category)
	_locked_note.text = LOCKED_TEXT % StrategicMechanics.FOKUS_UNLOCK_GRADE
	_locked_note.visible = not is_unlocked
	_intro_note.text = INTRO_TEXT % [roundi(Balance.FOKUS_BONUS * PERCENT),
		roundi(Balance.FOKUS_PENALTY * PERCENT)]
	_intro_note.visible = is_unlocked and GameState.weekly_fokus == StrategicMechanics.FOKUS_NONE


func _on_chip_toggled(is_pressed: bool, category: String) -> void:
	if not _chips.has(category):
		push_error("FokusRow: unknown Fokus category '%s'" % category)
		return
	if is_pressed:
		GameState.weekly_fokus = category
	elif GameState.weekly_fokus == category:
		GameState.weekly_fokus = StrategicMechanics.FOKUS_NONE
	_intro_note.visible = GameState.weekly_fokus == StrategicMechanics.FOKUS_NONE
	fokus_changed.emit()
```

  In a ButtonGroup switch, both chips emit `toggled`. In either order the end state is the new pick, because the old chip's `false` only clears a Fokus that is still its own. `fokus_changed` may fire twice, which is harmless.
- [ ] **Step 5 [editor]:** Restart the editor, since a script was attached and a `class_name` is new. Then:
  - `test_run(suite="fokus_row")`: PASS.
  - `test_run` on `script_documentation`, `viewport_editability`, `theme_factory` and `clean_code`: all green.
  - If the live look shows `FilterChipButton` cannot carry this row and a new variation is truly needed (use `showwidget` to let the human pick first), add it in `ThemeFactory.gd` and pin it:
    - Add it to `test_theme_factory.gd`'s `expected` list (`test_every_declared_variation_exists`).
    - It is a display-font button, so add it to `DISPLAY_ROSTER`.
    - Rebake **alone**: restart the editor, run `test_run(suite="theme_rebake")` and nothing else, restart again, then `git diff Assets/Theme/kejartes_theme.tres` and check the bake by content.
    - Never hand-merge the bake.
- [ ] **Step 6: Commit** `feat(atur-jadwal): FokusRow component writes GameState.weekly_fokus`.

---

### Task 8: FokusRow on AturJadwal, and a projection that knows the mechanics

**Files:**
- Modify: `Scenes/AturJadwal/AturJadwal.tscn` (scene first)
- Modify: `Scripts/AturJadwal/ActivityPreview.gd`, `Scripts/AturJadwal/AturJadwal.gd` (LARGE 1626: shrinks)
- Modify: `tests/test_atur_jadwal.gd`, `tests/test_activity_preview.gd`

- [ ] **Step 1 [editor]: Placement.** The screen is packed: the day grid, the shelf at y 766-843, the ObjectiveStrip at 846-942 and the stat bars below. `project_run`, seed the playtest state, pass once through Atur Jadwal at G8, and screenshot at full size. Find a gap that holds the row at 1080×1920. If no gap exists without moving the authored layout, **stop and ask the human with `showwidget`**. Options include StudentList, the roster hub (spec open question), or a collapsed chip in the strip. Do not improvise a relayout.
- [ ] **Step 2 [editor]: Scene work.** Restart the editor first if any `.gd` was patched since it started.
  1. `scene_open("res://Scenes/AturJadwal/AturJadwal.tscn")`.
  2. Instance `FokusRow.tscn` as `FokusRow` at the chosen slot (layout_mode 0, like its siblings).
  3. Add the connection `fokus_changed` → `.` `_update_student_display` in the scene (signal_manage). It takes no arguments, and AturJadwal.gd gains no line.
  4. `scene_save`, then `git diff HEAD -- '*.gd' Scenes/AturJadwal/AturJadwal.tscn`. Only the instance, its ext_resource and the connection may appear. Revert any tab flush.
- [ ] **Step 3 [code]: Failing tests.**
  - `activity_preview`: add `test_week_skill_gain_counts_each_scheduled_day`. Flag off, `FOKUS_NONE`, two Akademis days: the result equals `2 * skill_gain(...)`.
  - `activity_preview`: add `test_week_skill_gain_applies_the_mechanics`. Flag on, the same student with Akademis on all five days, an Akademis Fokus at G8, and no partner. The result equals `skill_gain * (1+FOKUS_BONUS) * (1 + 1 + D3 + D4 + D5)`.
  - `activity_preview`: add a duet case, where a second schedule shares Senin.
  - `atur_jadwal` `test_pending_gain_is_grade_aware`: now asserts `src.contains("ActivityPreview.week_skill_gain(")`. Keep its intent in the `##` line.
  - Add `test_scene_instances_fokus_row`: the `.tscn` text contains `FokusRow.tscn` and `signal="fokus_changed"`.
- [ ] **Step 4 [code]: Implement.** In `ActivityPreview.gd`:

```gdscript
## One student's week of one skill, as the simulation will run it: each
## scheduled day's gain times the duet, Fokus and diminishing multipliers
## (StrategicMechanics). `schedules` is GameState.day_schedules; the duet
## counts every schedule holding the same skill that day. A projection:
## Izin days are only known once the week runs.
static func week_skill_gain(category: String, student: Dictionary, grade: int,
		schedules: Dictionary, fokus: String) -> float:
	var own: Dictionary = schedules.get(student.get("id", 0), {})
	var per_day: float = skill_gain(category, student, grade)
	var total := 0.0
	var day_count := 0
	for day_name: String in StrategicMechanics.SCHOOL_DAYS:
		if _category_on(own, day_name) != category:
			continue
		day_count += 1
		var sharing: int = _students_on(schedules, day_name, category)
		total += per_day * StrategicMechanics.study_multiplier(category, fokus, sharing, day_count)
	return total


static func _category_on(schedule: Dictionary, day_name: String) -> String:
	var day: Dictionary = schedule.get(day_name, {})
	return StrategicMechanics.normalize_category(str(day.get("category", "")))


static func _students_on(schedules: Dictionary, day_name: String, category: String) -> int:
	var count := 0
	for schedule: Dictionary in schedules.values():
		if _category_on(schedule, day_name) == category:
			count += 1
	return count
```

  In `AturJadwal.gd`, replace the body of `_compute_pending_gain` (L582-588, 7 lines):

```gdscript
func _compute_pending_gain(category: String, student: Dictionary) -> float:
	return ActivityPreview.week_skill_gain(category, student, GameState.current_grade,
		GameState.day_schedules, StrategicMechanics.effective_fokus(GameState.current_grade, GameState.weekly_fokus))
```

  `wc -l Scripts/AturJadwal/AturJadwal.gd` must be below 1626. The skill tiles' per-day number stays the unmultiplied `skill_gain`, because which day the pick lands on decides the multiplier. Add a DEBT line if the human wants it Fokus-aware.
- [ ] **Step 5 [editor]:** Run a no-op `script_patch` on `ActivityPreview.gd` and `AturJadwal.gd`. Then:
  - `test_run` on `activity_preview`, `atur_jadwal`, `atur_jadwal_specialty_feedback`, `objective_hint` and `fokus_row`: all green.
  - `test_run(suite="clean_code")`: expect a shrink of LARGE `AturJadwal.gd` to its new count, and possibly its UNTYPED/BARE. Run the dump and review the diff.
  - Then one screenshot at full size of Atur Jadwal at G7 (locked) and G8 (pick Akademis: the Akademis bar's projected delta rises, the others fall).
- [ ] **Step 6: Commit** `feat(atur-jadwal): Fokus row on the schedule screen; projection applies the depth mechanics`.

---

### Task 9: Tutorial copy

**Files:**
- Modify: `Scripts/CutScene/CutScene.gd` (273 lines, not large)
- Modify: `tests/test_cutscene.gd`

The natural G7→G8 route never replays CutScene. FokusRow's intro note (Task 7) is the real Fokus lesson; this frame reaches a run started at G8 from the Level Select, and G7's rotation hint reaches every new run.

- [ ] **Step 1 [code]: Failing test** in `cutscene`: `test_grade_hint_frames`. It checks that `CutScene.gd` declares `GRADE_HINTS` with keys 7 and 8, and that the playback reads the grade-built frame list, not `cg_data` directly. Use a source scan: CutScene's runtime is gated.
- [ ] **Step 2 [code]: Implement:**

```gdscript
## One extra closing frame per grade, reusing the last CG. [PLACEHOLDER] copy
## (DEBT, "Audio and copy"). 7 teaches rotation (diminishing returns),
## 8 introduces the Fokus row.
const GRADE_HINTS: Dictionary = {
	7: "Cobalah merotasi kegiatan tiap harinya.",
	8: "Mulai Kelas 8, kamu bisa memilih FOKUS minggu ini di Atur Jadwal.",
}
```

  Build `_frames: Array[Dictionary]` once, in the runtime (gated) part of `_ready`. It is `cg_data` plus, when `GRADE_HINTS.has(GameState.current_grade)`, a frame `{"image": cg_data[-1]["image"], "text": GRADE_HINTS[grade]}`. Point the four `cg_data[...]`/`cg_data.size()` reads (L185/188/234/248-249) at `_frames`. Boy Scout: type `var cg_data: Array[Dictionary]`.
- [ ] **Step 3 [editor]:** Run a no-op `script_patch`. Then `test_run(suite="cutscene")`, `test_run(suite="script_documentation")` and `test_run(suite="clean_code")`. Run the dump on a shrink.
- [ ] **Step 4: Commit** `feat(cutscene): grade hint frames for rotation (G7) and Fokus (G8)`.

---

### Task 10: Re-tune `balance_pacing` for the mechanics and the landed pacing

**Files:**
- Modify: `tests/test_balance_pacing.gd`

`balance_pacing` is red since Task 4. Do not hard-code PR1's 10/22/32 or 4/6/8. The numbers live in `Balance.gd`, and the `balance` suite pins them (Task 0).

- [ ] **Step 1 [code]:** The **well-played** policy (L100) puts all five days on one subject. Rewrite it to play the way the mechanics teach:
  - Rotate subjects so no skill runs past two days.
  - Pair students on a shared skill where they can.
  - From G8, pick the Fokus on the week's weakest skill (`GameState.weekly_fokus`).

  Keep the careless policy careless. Snapshot and restore `weekly_fokus` in `setup`/`teardown`.
- [ ] **Step 2 [code]:** Re-derive the clear-week windows from `Balance.JUMLAH_MINGGU_KELAS_*`:
  - "Well played clears by N weeks" becomes a named fraction of the grade's weeks, as a `const` with a `##` line at the top of the suite.
  - Keep "G7 careless never unwinnable".
  - Keep the seed-luck and stack-exploit bounds.
  - The harness seeds four students at every grade, but the real roster is 2/3/4. Seed `max_approve_for(grade)` students (preload `StudentCard.gd`, which has no `class_name`) so the star math matches play.
- [ ] **Step 3 [editor]:** `test_run(suite="balance_pacing")`. Then run it again with the flag false (flip it in a scratch `setup`, and never commit that). The flag-off run must be no harder than the flag-on run. If a window cannot be met without changing a Balance number, **stop and write the proposal for the collaborator**. Do not bend the test.
- [ ] **Step 4: Commit** `test(balance): pacing harness plays the depth mechanics on the real roster size`.

---

### Task 11: Docs, full run, ship

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md`, `CLAUDE.md`

- [ ] **Step 1 [code]: CHANGELOG.** Add an entry newest-first: the three mechanics, the Fokus row, the per-grade pass line, the flag, and the `apply_daily_decay_all` split.
- [ ] **Step 2 [code]: DEBT.**
  - Under "Audio and copy": the `[PLACEHOLDER]` Fokus strings (`FokusRow.LOCKED_TEXT`/`INTRO_TEXT`, `CutScene.GRADE_HINTS`).
  - Under "Known bugs": the Istirahat double log found in Task 3.
  - Any deferred item from Task 8: tile values that ignore the Fokus, or the row's home if the human chose to move it later.
  - Delete nothing unrelated.
- [ ] **Step 3 [code]: CLAUDE.md.** In "The game":
  - The pass rule becomes "`run_stars() >= GameState.win_threshold()`, per grade".
  - Add a "Pass stars" column to the grade table with the landed values.
  - Add one line to "Stats & activities": diminishing from day 3, a duet at exactly 2, and a weekly Fokus from G8, all behind `Balance.STRATEGIC_MECHANICS_ENABLED`.

  Also update the suite and test counts in "Testing" (five new suites: `strategic_mechanics`, `weekly_fokus`, `student_manager_mechanics`, `sliding_threshold`, `fokus_row`). **CLAUDE.md sits at about 22,878 of its 23,000-character budget.** Move something out first (per "Maintaining this file"), and do not thin a live rule.
- [ ] **Step 4 [editor]: Full `test_run`,** once, at this milestone. Budget an editor restart: a full run drops the bridge.
  - Then `git status`. `git checkout --` an unintended `Assets/Theme/kejartes_theme.tres` rebake or `default_bus_layout.tres` rewrite.
  - Re-run any lone red theme suite alone before believing it.
  - Confirm `wc -l` for `AturJadwal.gd` (< 1626), `SchoolDay.gd` (≤ 1638) and `StudentCard.gd` (1451, untouched).
- [ ] **Step 5: Ship** with the `ship-pr` skill. It runs the suite and a local review, opens the PR and stamps the tested commit. The PR description lists:
  - the collaborator constants it depends on;
  - the expected baseline diffs;
  - any `--rekey` warnings (none expected);
  - the flag-off check.

## Self-review checklist (before ship-pr)

- [ ] Every new suite is green: `strategic_mechanics`, `weekly_fokus`, `student_manager_mechanics`, `sliding_threshold` and `fokus_row`. So are the touched existing suites: `balance`, `balance_pacing`, `economy_state`, `objective_hint`, `activity_preview`, `atur_jadwal`, `cutscene`, `wirausaha`, `end_game_rehearsal`, `clean_code`, `script_documentation`, `viewport_editability` and `theme_factory`.
- [ ] Flag-off: `strategic_mechanics`, `student_manager_mechanics` and `sliding_threshold` each assert identity behaviour. The Fokus row is locked with the flag off.
- [ ] Manual smoke (seed playtest state, pass through Atur Jadwal):
  - G7: the row is locked, and the note is visible.
  - G8: pick a Fokus. The projected bars move and the intro note hides.
  - One SchoolDay week: the day-3 gain shrinks, a pair gains more, and the Fokus skews gains.
- [ ] No `theme_override_*`, no runtime-built nodes, no new legacy stat key (`grep -rn -i "akademis[123]\|kepribadian[12]"` on the diff), no new persistence, and `Balance.gd` untouched.
- [ ] The large scripts did not grow. The baseline diff only lowers or removes entries.

## Done when

- All tasks are committed on the working branch, and the PR has merged through ship-pr.
- Playtest shows the three mechanics are noticeable.
- The design's success criteria (G7 casual win ≥ 90%, G8 ~65–75%, G9 ~40–55%) are measured post-merge; they do not gate this PR.

## Questions for the human

1. **Balance.gd:** the collaborator never applied PR1. Ask them for the 11 constants. Also decide which pacing wins: PR1 (4/6/8 weeks, 10/22/32) or the 2026-09-28 week-length proposal (6/9/12, 15/26/30).
2. **G8's 1.83 pass line is a no-op** with a 3-student roster: 6 of 9 targets is still needed, the same as 2.0. Should it be 1.67 (5 of 9)? G9's 1.67 does lower the bar, to 7 of 12.
3. **G7 has only 2 students,** so any shared day is a duet and "3+ gets none" only exists from G8. Is that intended?
4. **Where the Fokus row lives:** AturJadwal edits one student at a time, but the Fokus is roster-wide. StudentList, the roster hub, may be the better home, and the component makes that a scene move. Task 8, Step 1 asks before any relayout.
