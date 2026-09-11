# PR3 — Strategic Depth Mechanics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three composed scheduling mechanics — diminishing returns per student per category per week (A), weekly Fokus meta-choice (C, unlocks G8), duet bonus at exactly 2 students same-cat same-day (D) — plus per-grade sliding star threshold and Fokus-Wirausaha payout. All guarded by `Balance.STRATEGIC_MECHANICS_ENABLED` for one-flag rollback.

**Architecture:** Mechanics live in `StudentManager.gd` (applied in the daily gain pipeline). Fokus state on `GameState`; Fokus UI on AturJadwal (new `FokusRow` above the schedule grid, `PrimaryButton` variation, disabled on G7). Sliding threshold read by `GameState.check_win()`. No new autoloads. Tutorial rollout: G7 hint line in the existing cutscene, G8 new fokus tutorial beat.

**Tech Stack:** GDScript 4.6, McpTestSuite, existing ThemeFactory variations (no `theme_override_*`).

**Spec:** `docs/superpowers/specs/2026-09-11-balance-and-depth-design.md`, section "PR3 — Strategic depth mechanics".

**Depends on:** PR1 (Balance.gd constants) merged by collaborator. Tests here assume `DIMINISHING_DAY_*`, `FOKUS_*`, `DUET_BONUS`, `STAR_WIN_THRESHOLD_KELAS_*`, `STRATEGIC_MECHANICS_ENABLED` exist.

## Global Constraints

- All new suites `extends McpTestSuite`, `@tool`, no coroutines.
- `Balance.gd` is read-only for us. If a test needs a value change, propose in the doc from PR1 — do not edit.
- Order of gain multipliers in code: `base → duet → fokus → diminishing → quirks/personality`. Consistent across all study categories.
- Every new mechanic is wrapped in `if Balance.STRATEGIC_MECHANICS_ENABLED`. Setting it false must make all three mechanics no-op — a test asserts this.
- Indonesian for UI copy; `[PLACEHOLDER]` prefix on new cutscene lines per project convention.
- No `theme_override_*`. Fokus buttons use `PrimaryButton` variation from `ThemeFactory`.
- Runtime visual construction ratchet: any new node lives in the `.tscn`, not built in `_ready()`.
- Conventional Commits: `feat(scheduling): …`, `feat(gamestate): …`, `test(mechanics): …`, `feat(atur-jadwal): …`.

---

### Task 1: Diminishing returns

**Files:**
- Create: `tests/test_diminishing_returns.gd`
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` — add per-week counter and multiplier lookup.

**Interfaces:**
- Consumes: `Balance.DIMINISHING_DAY_3/4/5`, `Balance.STRATEGIC_MECHANICS_ENABLED`.
- Produces:
  - `StudentManager._weekly_category_days: Dictionary` — `{sid: {"Akademis": int, "SeniBudaya": int, "Olahraga": int}}`.
  - `StudentManager.begin_week() -> void` — clears the counter.
  - `StudentManager._diminishing_multiplier(sid: int, category: String) -> float` — increments and returns.

- [ ] **Step 1: Failing tests**

```gdscript
@tool
extends McpTestSuite

func test_days_1_and_2_full_gain() -> void:
    var sm := StudentManager.new()
    sm.begin_week()
    var sid := 1
    assert_eq(sm._diminishing_multiplier(sid, "Akademis"), 1.0)
    assert_eq(sm._diminishing_multiplier(sid, "Akademis"), 1.0)

func test_day_3_4_5_apply() -> void:
    var sm := StudentManager.new()
    sm.begin_week()
    var sid := 1
    for i in 2:
        sm._diminishing_multiplier(sid, "Akademis")
    assert_eq(sm._diminishing_multiplier(sid, "Akademis"), Balance.DIMINISHING_DAY_3)
    assert_eq(sm._diminishing_multiplier(sid, "Akademis"), Balance.DIMINISHING_DAY_4)
    assert_eq(sm._diminishing_multiplier(sid, "Akademis"), Balance.DIMINISHING_DAY_5)

func test_per_student_per_category() -> void:
    var sm := StudentManager.new()
    sm.begin_week()
    for i in 3:
        sm._diminishing_multiplier(1, "Akademis")
    # Student 2 unaffected
    assert_eq(sm._diminishing_multiplier(2, "Akademis"), 1.0)
    # Same student, different category unaffected
    assert_eq(sm._diminishing_multiplier(1, "SeniBudaya"), 1.0)

func test_master_flag_disables() -> void:
    Balance.STRATEGIC_MECHANICS_ENABLED = false
    var sm := StudentManager.new()
    sm.begin_week()
    for i in 5:
        assert_eq(sm._diminishing_multiplier(1, "Akademis"), 1.0)
    Balance.STRATEGIC_MECHANICS_ENABLED = true
```

Run: `test_run(suite="test_diminishing_returns")` — FAIL.

- [ ] **Step 2: Implement**

In `Scripts/SchoolSimulation/StudentManager.gd`, add near top-level state:

```gdscript
var _weekly_category_days: Dictionary = {}

func begin_week() -> void:
    _weekly_category_days = {}

func _diminishing_multiplier(sid: int, category: String) -> float:
    if not _weekly_category_days.has(sid):
        _weekly_category_days[sid] = {}
    var count: int = _weekly_category_days[sid].get(category, 0) + 1
    _weekly_category_days[sid][category] = count
    if not Balance.STRATEGIC_MECHANICS_ENABLED:
        return 1.0
    match count:
        3: return Balance.DIMINISHING_DAY_3
        4: return Balance.DIMINISHING_DAY_4
        5: return Balance.DIMINISHING_DAY_5
        _: return 1.0
```

Call `begin_week()` at the start of `initialize_from_gamestate()` (or wherever the weekly reset lives). Multiplier is called in `_apply_category_day` — locate the gain-computation site and multiply the final gain by `_diminishing_multiplier(sid, category)` **after** duet and fokus (see order in Global Constraints).

- [ ] **Step 3: Run test — PASS. Commit.**

```bash
git add tests/test_diminishing_returns.gd Scripts/SchoolSimulation/StudentManager.gd
git commit -m "feat(scheduling): diminishing returns per student per category per week"
```

---

### Task 2: Duet bonus

**Files:**
- Create: `tests/test_duet_bonus.gd`
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` — count same-cat students that day, apply 1.15× at exactly 2.

**Interfaces:**
- Consumes: `Balance.DUET_BONUS`, `Balance.STRATEGIC_MECHANICS_ENABLED`, `GameState.day_schedules`.
- Produces: `StudentManager._duet_multiplier(day_name: String, category: String) -> float`.

- [ ] **Step 1: Failing tests**

```gdscript
@tool
extends McpTestSuite

func _seed_schedule(pairs: Array) -> void:
    # pairs: [[sid, category], ...] for Monday
    GameState.day_schedules = {}
    for p in pairs:
        var sid: int = p[0]
        var cat: String = p[1]
        GameState.day_schedules[sid] = {"Monday": {"category": cat}}

func test_solo_no_bonus() -> void:
    _seed_schedule([[1, "Akademis"], [2, "Olahraga"]])
    var sm := StudentManager.new()
    assert_eq(sm._duet_multiplier("Monday", "Akademis"), 1.0)

func test_pair_gives_bonus() -> void:
    _seed_schedule([[1, "Akademis"], [2, "Akademis"], [3, "Olahraga"]])
    var sm := StudentManager.new()
    assert_eq(sm._duet_multiplier("Monday", "Akademis"), 1.0 + Balance.DUET_BONUS)

func test_three_or_more_no_bonus() -> void:
    _seed_schedule([[1, "Akademis"], [2, "Akademis"], [3, "Akademis"]])
    var sm := StudentManager.new()
    assert_eq(sm._duet_multiplier("Monday", "Akademis"), 1.0)

func test_master_flag_disables() -> void:
    _seed_schedule([[1, "Akademis"], [2, "Akademis"]])
    Balance.STRATEGIC_MECHANICS_ENABLED = false
    var sm := StudentManager.new()
    assert_eq(sm._duet_multiplier("Monday", "Akademis"), 1.0)
    Balance.STRATEGIC_MECHANICS_ENABLED = true
```

- [ ] **Step 2: Implement**

```gdscript
func _duet_multiplier(day_name: String, category: String) -> float:
    if not Balance.STRATEGIC_MECHANICS_ENABLED:
        return 1.0
    var count: int = 0
    for sid in GameState.day_schedules.keys():
        var sched: Dictionary = GameState.day_schedules[sid]
        if not sched.has(day_name):
            continue
        if sched[day_name].get("category", "") == category:
            count += 1
    return (1.0 + Balance.DUET_BONUS) if count == 2 else 1.0
```

Call in `_apply_category_day` before diminishing.

- [ ] **Step 3: Test PASS, commit.**

```bash
git add tests/test_duet_bonus.gd Scripts/SchoolSimulation/StudentManager.gd
git commit -m "feat(scheduling): duet bonus (+15%) when exactly 2 students share a category-day"
```

---

### Task 3: Weekly Fokus state on GameState

**Files:**
- Create: `tests/test_weekly_fokus_state.gd`
- Modify: `Scripts/GameState.gd` — `weekly_fokus: String` + reset in `advance_week()`.

**Interfaces:**
- Produces: `GameState.weekly_fokus: String` (default `"None"`), reset on week advance.

- [ ] **Step 1: Failing test**

```gdscript
@tool
extends McpTestSuite

func test_default_is_none() -> void:
    GameState.weekly_fokus = "Akademis"
    GameState.reset_weekly_fokus()
    assert_eq(GameState.weekly_fokus, "None")

func test_advance_week_resets() -> void:
    GameState.weekly_fokus = "Olahraga"
    GameState.advance_week()
    assert_eq(GameState.weekly_fokus, "None")
```

- [ ] **Step 2: Implement**

Add to `Scripts/GameState.gd`:

```gdscript
var weekly_fokus: String = "None"

func reset_weekly_fokus() -> void:
    weekly_fokus = "None"
```

Call `reset_weekly_fokus()` inside the existing `advance_week()` function (find it — likely near the roster reset logic).

- [ ] **Step 3: Test PASS, commit.**

---

### Task 4: Fokus application in gain pipeline

**Files:**
- Create: `tests/test_fokus_gain.gd`
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` — `_fokus_multiplier(category: String)`.

**Interfaces:**
- Consumes: `GameState.weekly_fokus`, `Balance.FOKUS_BONUS`, `Balance.FOKUS_PENALTY`, `Balance.STRATEGIC_MECHANICS_ENABLED`.
- Produces: `StudentManager._fokus_multiplier(category: String) -> float`.

- [ ] **Step 1: Failing tests**

```gdscript
@tool
extends McpTestSuite

func test_none_no_effect() -> void:
    GameState.weekly_fokus = "None"
    var sm := StudentManager.new()
    assert_eq(sm._fokus_multiplier("Akademis"), 1.0)

func test_match_bonus() -> void:
    GameState.weekly_fokus = "Akademis"
    var sm := StudentManager.new()
    assert_eq(sm._fokus_multiplier("Akademis"), 1.0 + Balance.FOKUS_BONUS)

func test_mismatch_penalty() -> void:
    GameState.weekly_fokus = "Akademis"
    var sm := StudentManager.new()
    assert_eq(sm._fokus_multiplier("SeniBudaya"), 1.0 - Balance.FOKUS_PENALTY)

func test_wirausaha_fokus_no_skill_effect() -> void:
    # Wirausaha grants no skill points, so category multiplier just no-ops
    # for the skill categories.
    GameState.weekly_fokus = "Wirausaha"
    var sm := StudentManager.new()
    assert_eq(sm._fokus_multiplier("Akademis"), 1.0 - Balance.FOKUS_PENALTY)
    assert_eq(sm._fokus_multiplier("Wirausaha"), 1.0)  # only kicks in at money payout
```

- [ ] **Step 2: Implement**

```gdscript
func _fokus_multiplier(category: String) -> float:
    if not Balance.STRATEGIC_MECHANICS_ENABLED:
        return 1.0
    var f: String = GameState.weekly_fokus
    if f == "None":
        return 1.0
    if f == category:
        return 1.0 + Balance.FOKUS_BONUS
    if f == "Wirausaha":
        # Wirausaha fokus penalizes skill categories the same way as any other fokus;
        # the bonus lives in the money payout path (Task 5), not here.
        return 1.0 - Balance.FOKUS_PENALTY
    return 1.0 - Balance.FOKUS_PENALTY
```

Call in `_apply_category_day` between duet and diminishing.

- [ ] **Step 3: Test PASS, commit.**

---

### Task 5: Fokus-Wirausaha payout

**Files:**
- Create: `tests/test_fokus_wirausaha.gd`
- Modify: `Scripts/SchoolSimulation/StudentManager.gd` — Wirausaha payout branch.

**Interfaces:**
- Consumes: `GameState.weekly_fokus`, `Balance.FOKUS_WIRAUSAHA_BONUS`, `Balance.FOKUS_WIRAUSAHA_REST_COIN`.
- Produces: `StudentManager._wirausaha_fokus_payout_multiplier() -> float`, `_wirausaha_fokus_rest_bonus_per_day() -> int`.

- [ ] **Step 1: Failing tests**

```gdscript
@tool
extends McpTestSuite

func test_no_fokus_no_bonus() -> void:
    GameState.weekly_fokus = "None"
    var sm := StudentManager.new()
    assert_eq(sm._wirausaha_fokus_payout_multiplier(), 1.0)
    assert_eq(sm._wirausaha_fokus_rest_bonus_per_day(), 0)

func test_wirausaha_fokus_boosts() -> void:
    GameState.weekly_fokus = "Wirausaha"
    var sm := StudentManager.new()
    assert_eq(sm._wirausaha_fokus_payout_multiplier(), 1.0 + Balance.FOKUS_WIRAUSAHA_BONUS)
    assert_eq(sm._wirausaha_fokus_rest_bonus_per_day(), Balance.FOKUS_WIRAUSAHA_REST_COIN)

func test_other_fokus_no_wirausaha_bonus() -> void:
    GameState.weekly_fokus = "Akademis"
    var sm := StudentManager.new()
    assert_eq(sm._wirausaha_fokus_payout_multiplier(), 1.0)
    assert_eq(sm._wirausaha_fokus_rest_bonus_per_day(), 0)
```

- [ ] **Step 2: Implement**

```gdscript
func _wirausaha_fokus_payout_multiplier() -> float:
    if not Balance.STRATEGIC_MECHANICS_ENABLED:
        return 1.0
    return (1.0 + Balance.FOKUS_WIRAUSAHA_BONUS) if GameState.weekly_fokus == "Wirausaha" else 1.0

func _wirausaha_fokus_rest_bonus_per_day() -> int:
    if not Balance.STRATEGIC_MECHANICS_ENABLED:
        return 0
    return Balance.FOKUS_WIRAUSAHA_REST_COIN if GameState.weekly_fokus == "Wirausaha" else 0
```

Wire into the existing Wirausaha payout site (look for `WIRAUSAHA_UANG_MIN` references in StudentManager to find the exact function). Multiply the day's earning by `_wirausaha_fokus_payout_multiplier()`. In the Istirahat branch, add `pending_earnings += _wirausaha_fokus_rest_bonus_per_day()`.

- [ ] **Step 3: Test PASS, commit.**

---

### Task 6: Sliding star threshold

**Files:**
- Create: `tests/test_sliding_threshold.gd`
- Modify: `Scripts/GameState.gd` — `check_win()` reads per-grade constant.
- Modify (if needed): `Scripts/EndGame/RunGrade.gd` — same threshold source.

**Interfaces:**
- Consumes: `Balance.STAR_WIN_THRESHOLD_KELAS_7/8/9`, `GameState.current_grade`.
- Produces: `GameState.win_threshold_for_grade(grade: int) -> float`.

- [ ] **Step 1: Failing tests**

```gdscript
@tool
extends McpTestSuite

func test_thresholds_per_grade() -> void:
    assert_eq(GameState.win_threshold_for_grade(7), Balance.STAR_WIN_THRESHOLD_KELAS_7)
    assert_eq(GameState.win_threshold_for_grade(8), Balance.STAR_WIN_THRESHOLD_KELAS_8)
    assert_eq(GameState.win_threshold_for_grade(9), Balance.STAR_WIN_THRESHOLD_KELAS_9)

func test_check_win_uses_grade() -> void:
    GameState.current_grade = 9
    # Simulate 10 cleared of 12 (1.67 stars exactly at G9 threshold).
    GameState._debug_set_stars(1.67)
    assert_true(GameState.check_win())
    GameState._debug_set_stars(1.66)
    assert_false(GameState.check_win())
```

(If `_debug_set_stars` doesn't exist, either add a test-only shim or seed `approved_students` clear-counts directly.)

- [ ] **Step 2: Implement**

```gdscript
func win_threshold_for_grade(grade: int) -> float:
    match grade:
        7: return Balance.STAR_WIN_THRESHOLD_KELAS_7
        8: return Balance.STAR_WIN_THRESHOLD_KELAS_8
        9: return Balance.STAR_WIN_THRESHOLD_KELAS_9
        _: return 2.0
```

Update `check_win()` — replace the existing `>= STAR_WIN_THRESHOLD` with `>= win_threshold_for_grade(current_grade)`.

In `RunGrade.gd`, grep for `STAR_WIN_THRESHOLD` and route through the new function.

- [ ] **Step 3: Test PASS, commit.**

---

### Task 7: Fokus UI on AturJadwal

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` — add `FokusRow` HBoxContainer with 4 `Button`s (`PrimaryButton` variation) above the schedule grid.
- Modify: `Scripts/AturJadwal/atur_jadwal.gd` — wire toggle behavior, write to `GameState.weekly_fokus`, disable on G7.

**Interfaces:**
- Consumes: `GameState.weekly_fokus`, `GameState.current_grade`.
- Produces: UI writes `GameState.weekly_fokus` on selection.

- [ ] **Step 1: Failing behavioral test**

Source-scan style per project convention (many AturJadwal tests can't run headless):

```gdscript
@tool
extends McpTestSuite

func test_scene_has_fokus_row() -> void:
    var text := FileAccess.get_file_as_string("res://Scenes/AturJadwal/atur_jadwal.tscn")
    assert_true(text.contains("FokusRow"), "FokusRow node missing")
    for cat in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha"]:
        assert_true(text.contains("FokusBtn" + cat), "FokusBtn%s missing" % cat)

func test_script_wires_fokus() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/atur_jadwal.gd")
    assert_true(src.contains("GameState.weekly_fokus"))
    assert_true(src.contains("Balance.STRATEGIC_MECHANICS_ENABLED"))
    assert_true(src.contains("current_grade") and src.contains("7"))  # G7 gate
```

- [ ] **Step 2: Edit the scene via MCP**

Follow the CLAUDE.md pattern: `scene_open` → `node_create` for `FokusRow` HBoxContainer above the existing schedule grid → four child Buttons named `FokusBtnAkademis`, `FokusBtnSeniBudaya`, `FokusBtnOlahraga`, `FokusBtnWirausaha`, each with `theme_type_variation = "PrimaryButton"` and `toggle_mode = true` → `scene_save`.

Button text (Indonesian): "Fokus Akademis", "Fokus Seni", "Fokus Olahraga", "Fokus Wirausaha".

- [ ] **Step 3: Wire the script**

Add to `Scripts/AturJadwal/atur_jadwal.gd`:

```gdscript
@onready var _fokus_buttons := {
    "Akademis": %FokusBtnAkademis,
    "SeniBudaya": %FokusBtnSeniBudaya,
    "Olahraga": %FokusBtnOlahraga,
    "Wirausaha": %FokusBtnWirausaha,
}

func _ready_fokus_row() -> void:
    var enabled: bool = Balance.STRATEGIC_MECHANICS_ENABLED and GameState.current_grade >= 8
    for cat in _fokus_buttons.keys():
        var btn: Button = _fokus_buttons[cat]
        btn.disabled = not enabled
        if not enabled:
            btn.tooltip_text = "Terbuka di Kelas 8"
        btn.button_pressed = (GameState.weekly_fokus == cat)
        btn.toggled.connect(_on_fokus_toggled.bind(cat))

func _on_fokus_toggled(pressed: bool, category: String) -> void:
    if pressed:
        GameState.weekly_fokus = category
        for cat in _fokus_buttons.keys():
            if cat != category:
                _fokus_buttons[cat].button_pressed = false
    elif GameState.weekly_fokus == category:
        GameState.weekly_fokus = "None"
```

Call `_ready_fokus_row()` from the existing `_ready()`.

- [ ] **Step 4: Rescan + test PASS. Commit.**

Per CLAUDE.md: `filesystem_manage(op="scan")` before `test_run` after editing the `.gd` outside the editor. Then `test_run(suite="test_fokus_ui")`.

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn Scripts/AturJadwal/atur_jadwal.gd tests/test_fokus_ui.gd
git commit -m "feat(atur-jadwal): Fokus row (G8+) writes GameState.weekly_fokus"
```

---

### Task 8: Update balance-pacing test for new targets

**Files:**
- Modify: `tests/test_balance_pacing.gd` — new pass bands.

**Interfaces:**
- Consumes: PR1 Balance.gd values (10/22/32 targets, 4/6/8 weeks).

- [ ] **Step 1: Update the realistic-run simulation asserts**

Find the existing test's target-check block; replace with:

```gdscript
assert_eq(Balance.TARGET_KENAIKAN_KELAS_7, 10.0)
assert_eq(Balance.TARGET_KENAIKAN_KELAS_8, 22.0)
assert_eq(Balance.TARGET_KENAIKAN_KELAS_9, 32.0)
assert_eq(Balance.JUMLAH_MINGGU_KELAS_7, 4)
assert_eq(Balance.JUMLAH_MINGGU_KELAS_8, 6)
assert_eq(Balance.JUMLAH_MINGGU_KELAS_9, 8)
```

If the file has a simulated-run realistic-gain check, update its expected bands per the spec's Section 2 math.

- [ ] **Step 2: Test PASS after PR1 lands. Commit.**

```bash
git add tests/test_balance_pacing.gd
git commit -m "test(balance): update targets to new short-run pacing"
```

---

### Task 9: Tutorial copy hooks

**Files:**
- Modify: `Scripts/CutScene/` — G7 opening cutscene copy gets one hint line; G8 opening cutscene gets a Fokus tutorial beat.

**Interfaces:**
- Consumes: existing cutscene copy data (usually a script or a `.tres`).

- [ ] **Step 1: Locate the cutscene copy source**

Grep: `grep -rn "CutScene" Scripts/CutScene/`. Copy typically lives in a script or resource.

- [ ] **Step 2: Add G7 rotation hint line**

Add one line to the G7 opening: `"[PLACEHOLDER] Cobalah merotasi kegiatan tiap harinya."`

- [ ] **Step 3: Add G8 Fokus intro beat**

Add a new frame/line to the G8 opening: `"[PLACEHOLDER] Minggu ini kamu bisa pilih FOKUS — kegiatan yang paling penting."` Follow-up frame: `"[PLACEHOLDER] Nilai fokus naik 30%, kegiatan lain turun 20%."`

- [ ] **Step 4: Commit**

```bash
git add Scripts/CutScene/
git commit -m "feat(cutscene): rotation hint (G7) and Fokus tutorial beat (G8)"
```

---

## Self-review checklist (run before opening PR)

- [ ] All new tests green: `test_diminishing_returns`, `test_duet_bonus`, `test_weekly_fokus_state`, `test_fokus_gain`, `test_fokus_wirausaha`, `test_sliding_threshold`, `test_fokus_ui`, `test_balance_pacing`.
- [ ] Full `test_run` green (accept the two tracked-file churn per CLAUDE.md — `git checkout --` on `default_bus_layout.tres` and re-baked theme if unintended).
- [ ] Flip `STRATEGIC_MECHANICS_ENABLED = false` locally, rerun the four mechanic suites — all return to identity behavior. Flip back.
- [ ] Manual smoke: seed playtest state → Atur Jadwal on G8 → Fokus row visible + selectable; on G7 → disabled with tooltip.
- [ ] SchoolDay run of one week: diminishing kicks in at day 3, duet fires at 2, fokus multiplies as expected.
- [ ] No `theme_override_*` added. Fokus buttons render as `PrimaryButton`.
- [ ] No new runtime visual construction — every new node is in `atur_jadwal.tscn`.

## Done when

- All tasks committed on the working branch.
- Playtest verifies the three mechanics are noticeable in gameplay.
- Design's success criteria hold (G7 casual win ≥ 90%, G8 ~65–75%, G9 ~40–55%) — measurement is post-merge, not gating this PR.
