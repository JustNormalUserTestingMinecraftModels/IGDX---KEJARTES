# Balance, Pacing, and Strategic Depth — Design Spec

**Date:** 2026-09-11
**Branch of origin:** `feat/koperasi-rework` (this work starts on a new
branch off `Textures` after the koperasi rework merges)
**Author:** Claude (design), collaborator (Balance.gd values)

## Problem

Playtest surfaced three coupled issues:

1. **Runs are too long.** 6 weeks in G7 is already boring; 12/16 in G8/G9
   is a slog.
2. **Seni Menari never appears.** In 2–3 sessions of max-seni scheduling,
   only BuatBatik showed. Wiring in `SchoolDay.gd:270` is `seni_scenes =
   [buat_batik, lomba_menari]`, picked 50/50 — so either a runtime bug is
   silently rejecting LombaMenari, or the specific SchoolDay instance's
   `@export` fallback is misbehaving.
3. **Scheduling has no tactics.** It reads as "match student to hobby,"
   with no forced tradeoff. Energy/mood decay is gentle, Izin auto-catches
   holes, quirks nudge but never punish. The player has no scarce resource
   to allocate.

## Decisions (locked)

- **Run length: Short.** G7 = 4 weeks, G8 = 6, G9 = 8. Total ~18 weeks.
- **Difficulty ladder.** Targets G7/8/9 = 10 / 22 / 32.
- **Depth mechanics (composed):**
  - A. Diminishing returns per student per category per week.
  - C. Weekly Fokus pick (+30% / −20%), unlocks G8.
  - D. Duet bonus at 2 students same-category same-day (+15%).
- **Minigame variety.** Anti-repeat cooldown + never-shown safety net in
  the last two weeks. Density unchanged (1–3/week).
- **Wirausaha bump.** `WIRAUSAHA_UANG_MIN/MAX` 120/320 → 160/420 (+33%).
- **Sliding star threshold.** G7 = 2.00, G8 = 1.83, G9 = 1.67.
- **Rollout: three PRs, split by concern.**

## Ship plan

Three PRs, in order:

- **PR1** — Balance.gd proposal doc (owned by collaborator).
- **PR2** — Menari bug + minigame variety picker.
- **PR3** — Strategic depth mechanics + fokus + sliding threshold +
  wirausaha bump wiring.

PR1 lands (via collaborator) before PR3, since PR3's tests depend on the
new balance numbers. PR2 is independent and can land anytime.

---

## PR1 — Balance.gd proposal

**Deliverable:** `docs/superpowers/plans/2026-09-11-balance-pacing-proposal.md`.

Content: a proposal to the collaborator with the numbers below, the math
behind each, and the holiday-schedule note. We do NOT edit Balance.gd
ourselves — CLAUDE.md's convention is that Balance.gd is theirs.

### Numbers to change

| Constant | Current | Proposed | Rationale |
|---|---|---|---|
| `JUMLAH_MINGGU_KELAS_7` | 6 | 4 | Short-run pacing |
| `JUMLAH_MINGGU_KELAS_8` | 12 | 6 | Short-run pacing |
| `JUMLAH_MINGGU_KELAS_9` | 16 | 8 | Short-run pacing |
| `TARGET_KENAIKAN_KELAS_7` | 15 | 10 | G7 teaches, low bar |
| `TARGET_KENAIKAN_KELAS_8` | 34 | 22 | G8 medium, real challenge |
| `TARGET_KENAIKAN_KELAS_9` | 40 | 32 | G9 hard, gates mastery |
| `WIRAUSAHA_UANG_MIN` | 120 | 160 | Compensate shorter run |
| `WIRAUSAHA_UANG_MAX` | 320 | 420 | Same |

### New constants

```gdscript
static var STAR_WIN_THRESHOLD_KELAS_7 := 2.00
static var STAR_WIN_THRESHOLD_KELAS_8 := 1.83
static var STAR_WIN_THRESHOLD_KELAS_9 := 1.67

## Diminishing returns per student per category per week.
## Days 1–2 unaffected; day 3 = 0.70, day 4 = 0.50, day 5 = 0.30.
static var DIMINISHING_DAY_3 := 0.70
static var DIMINISHING_DAY_4 := 0.50
static var DIMINISHING_DAY_5 := 0.30

## Weekly Fokus.
static var FOKUS_BONUS := 0.30
static var FOKUS_PENALTY := 0.20
static var FOKUS_WIRAUSAHA_BONUS := 0.40
static var FOKUS_WIRAUSAHA_REST_COIN := 50

## Duet bonus at exactly 2 students on the same category same day.
static var DUET_BONUS := 0.15

## Master flag for the depth mechanics. Flip to false to revert without
## a code rollback if playtest hates them.
static var STRATEGIC_MECHANICS_ENABLED := true
```

### Holiday note

`HOLIDAYS` in `Scripts/AturJadwal/atur_jadwal.gd` pins two dates: week 3
(Kemerdekaan RI) and week 6 (Maulid). With G7 at 4 weeks, only week 3
lands inside G7 — Maulid falls outside. That leaves G7's final week
holiday-less. Two options for collaborator: (a) accept, (b) move Maulid
to week 4 for G7 only, keyed by `GameState.current_grade`.

### Math (why these numbers)

- **G7:** 4×5 = 20 study slots ÷ 4 students = 5 slots/student. At
  `BELAJAR_POIN_KELAS_7 = 3.0` + favorite bonus 3.0 ≈ 6/day on favorite,
  3/day on other. With rotation and rest, realistic gain ~18/student
  before minigame swings. Target 10 = comfortable teach.
- **G8:** 6×5 = 30 ÷ 4 = 7.5 slots/student, 2.5+2.5=5/day favorite.
  Realistic ~22–28. Target 22 = tight, real puzzle.
- **G9:** 8×5 = 40 ÷ 4 = 10 slots/student, 2.0+2.0=4/day favorite.
  Realistic ~28–36. Target 32 = hard, mastery-gated.

### Consumer changes (in PR3)

- `GameState.check_win()` reads `STAR_WIN_THRESHOLD_KELAS_[grade]`.
- `StudentManager` reads `DIMINISHING_DAY_*`, `FOKUS_*`, `DUET_BONUS`.
- Everything guarded by `if Balance.STRATEGIC_MECHANICS_ENABLED`.

---

## PR2 — Menari bug + variety picker

### Bug investigation

Wiring is textually correct:

- `SchoolDay.gd:37-38` — `@export var lomba_menari_scene: PackedScene`.
- `SchoolDay.gd:216-217` — null-guard fallback `load(...)`.
- `SchoolDay.gd:270` — `seni_scenes = [buat_batik, lomba_menari]`.
- `SchoolDay.gd:939` — `seni_scenes[randi() % seni_scenes.size()]`.

The tester's ~1-in-8 zero-menari rate over 2–3 sessions has ~1.5% prior
probability of being unlucky RNG. So it's a bug.

**Hypotheses to check, in order:**

1. **`SchoolDay.tscn`'s `@export` is null AND the fallback `load()`
   returns `null` silently.** Godot's `load()` can return null on
   circular imports or class_name resolution failure. If so,
   `seni_scenes = [batik, null]`, and `null.instantiate()` throws in
   `_play_minigame` — but if that throw is caught upstream, the day
   silently ends and the roll effectively becomes 100% batik.
2. **LombaMenari.gd throws in `_ready()`** (dancer rig missing texture,
   audio bus mismatch) — instantiates but crashes on entry, aborting
   the day.
3. **BaseMinigame's `start_game()` returns early on some LombaMenari
   invariant** — target_score = 0, rhythm_patterns empty, etc.

**Fix approach:** open the game via MCP `project_run`, use the debug
overlay's minigame launcher to load LombaMenari directly, read
`logs_read(source="game")` for the actual failure. Fix root cause.

**Reachability test (new):** `tests/test_minigame_variants_reachable.gd`.
Instantiate each variant scene (all four Akademis, both Olahraga, both
SeniBudaya), assert `is_instance_valid()` and that the root script
resolves. Runs headless as a source-instantiation test.

### Variety picker

Replace pure random picking with a **weighted, cooldown-aware, safety-net
picker.** New state on `SchoolDay`:

```gdscript
# Cleared on grade advance in GameState.reset_roster_for_new_grade().
# Structure: {"Akademis": {"Menjodohkan": 1, ...}, "SeniBudaya": {...}, "Olahraga": {...}}
# Value is the count of times that variant played this grade.
var _variants_played_this_grade: Dictionary = {}

# Local state, reset at the start of each week (in start_simulation()).
# Holds names of the last 1-2 variants played; length capped at 2.
var _variant_cooldown: Array[String] = []
```

Picker pseudocode (`SchoolDay._pick_variant(category: String, scenes: Array) -> PackedScene`):

```
candidates = scenes.filter(s => s.resource_path.get_file() not in cooldown)
if candidates.is_empty(): candidates = scenes  # cooldown fully saturated

# Safety net: in the last 2 weeks of the grade, prefer unseen variants.
weeks_left = GameState.total_weeks_this_grade() - GameState.current_week
if weeks_left <= 2:
    unseen = candidates.filter(s => _variants_played_this_grade[category].get(s.name, 0) == 0)
    if not unseen.is_empty(): candidates = unseen

# Weight: unseen this grade × 3, seen once × 1.
weights = candidates.map(s => 3 if played_count(s) == 0 else 1)
picked = weighted_random(candidates, weights)

# Update state.
_variant_cooldown.push_back(picked.name); trim to length 2
_variants_played_this_grade[category][picked.name] = played_count(picked) + 1
return picked
```

Applies to all three categories (not just seni). Cooldown is category-
agnostic (a variant that just played is on cooldown even if the next
minigame is a different category — otherwise a menari + batik streak is
still possible on consecutive seni rolls).

Actually re-reading: cooldown is *per variant name*, not per category, so
this works fine — the cooldown list holds names like "LombaMenari" and
"BuatBatik" independent of category.

### Tests for PR2

- `tests/test_minigame_variants_reachable.gd` — all 8 variants
  instantiate cleanly.
- `tests/test_variety_picker.gd`:
  - Cooldown honored: same variant never picked back-to-back.
  - Weighted preference: over 1000 rolls with one seen and one unseen,
    unseen appears ≥ 65% of the time.
  - Safety net: in the last 2 weeks with one variant still unseen,
    forces unseen 100% of the time.
- Update `tests/test_school_day.gd` picker-fairness test (existing
  passes) — replace with the new picker's expected distribution.

---

## PR3 — Strategic depth mechanics

### A. Diminishing returns

In `StudentManager.gd`, add per-week per-student per-category counter:

```gdscript
# {sid: {"Akademis": int, "SeniBudaya": int, "Olahraga": int}}
# Reset at week start.
var _weekly_category_days: Dictionary = {}
```

In `_apply_category_day(student, day_data)`:

```
count = _weekly_category_days[sid][category] + 1
_weekly_category_days[sid][category] = count

mult = 1.0
if Balance.STRATEGIC_MECHANICS_ENABLED:
    match count:
        3: mult = Balance.DIMINISHING_DAY_3  # 0.70
        4: mult = Balance.DIMINISHING_DAY_4  # 0.50
        5: mult = Balance.DIMINISHING_DAY_5  # 0.30

gain *= mult
```

Applies only to Akademis / SeniBudaya / Olahraga — not Istirahat or
Wirausaha (those don't grant skill points).

Reset hook: `StudentManager.begin_week()` clears `_weekly_category_days`.

**Enabled from G7** (invisible teaching — player learns rotation matters
without being told; if they don't, they still clear the low target).

### C. Weekly Fokus

**State:** `GameState.weekly_fokus: String = "None"`. Reset at week end
in `advance_week()`.

**UI:** AturJadwal top bar gains a "Fokus Minggu Ini" segmented control
with 4 pills: Akademis / Seni / Olahraga / Wirausaha. On G7,
disabled with tooltip "Terbuka di Kelas 8". On G8+, active.

**Node changes in `atur_jadwal.tscn`:**
- Add `FokusRow` HBoxContainer above the existing schedule grid.
- Four `Button`s with `PrimaryButton` variation, one selected at a
  time (toggle group behavior implemented in `atur_jadwal.gd`).
- Fokus icon slot uses category color from tokens.
- On G7, `disabled = true` on all four, `hint_tooltip` set.

**Effect (in StudentManager and Wirausaha payout):**

```
if Balance.STRATEGIC_MECHANICS_ENABLED and GameState.weekly_fokus != "None":
    if category == GameState.weekly_fokus:
        gain *= (1.0 + Balance.FOKUS_BONUS)  # 1.30
    else:
        gain *= (1.0 - Balance.FOKUS_PENALTY)  # 0.80
```

For Wirausaha fokus:
- All Wirausaha earnings that week × `1.0 + FOKUS_WIRAUSAHA_BONUS` (1.40).
- Each Istirahat day of any student adds a flat
  `FOKUS_WIRAUSAHA_REST_COIN` (50) to `pending_earnings`.

**Gain preview:** `atur_jadwal.gd`'s preview strip needs to reflect
fokus multipliers so the player sees the tradeoff before confirming.

### D. Duet bonus

In StudentManager, before applying skill gain, count same-category
students that day:

```
same_cat_count = 0
for other_sid, other_sched in day_schedules.items():
    if other_sched[day_name].category == category:
        same_cat_count += 1

if Balance.STRATEGIC_MECHANICS_ENABLED and same_cat_count == 2:
    gain *= (1.0 + Balance.DUET_BONUS)  # 1.15
# 3+ is intentionally NOT bonused — Penyendiri already penalizes there.
```

Applied before diminishing returns; order in code:
`base_gain → duet → fokus → diminishing → quirks/personality`.

No UI. Passive teaching — players notice their friend-pair students gain
faster together, learn to pair intentionally.

### Sliding star threshold

`GameState.check_win()`:

```gdscript
var thresh: float
match current_grade:
    7: thresh = Balance.STAR_WIN_THRESHOLD_KELAS_7
    8: thresh = Balance.STAR_WIN_THRESHOLD_KELAS_8
    9: thresh = Balance.STAR_WIN_THRESHOLD_KELAS_9
    _: thresh = 2.0
return computed_stars >= thresh
```

`RunGrade.gd` uses the same value for its win-band computation. Update
its LETTER_BANDS interpretation if any consumer assumes 2.0 exactly.

### Tutorial rollout

- **G7 CutScene:** existing intro copy adds one line hint: "Cobalah
  merotasi kegiatan tiap harinya." (Teaches A implicitly.)
- **G8 intro CutScene:** new "Fokus Minggu Ini" tutorial beat — one
  extra frame explaining the choice.
- **G9:** no new mechanics introduced; the challenge itself is the
  teaching.

### Files touched (PR3)

- `Scripts/GameState.gd` — `weekly_fokus`, `check_win()`, week reset.
- `Scripts/SchoolSimulation/StudentManager.gd` — mechanics application,
  `_weekly_category_days`, `begin_week()`.
- `Scripts/AturJadwal/atur_jadwal.gd` — Fokus UI + preview integration.
- `Scenes/AturJadwal/atur_jadwal.tscn` — FokusRow node.
- `Scripts/CutScene/*` — G7 hint line, G8 fokus intro copy (both marked
  `[PLACEHOLDER]` until copy pass, per project convention).
- `Scripts/EndGame/RunGrade.gd` — threshold consumer.

### Tests for PR3

- `tests/test_diminishing_returns.gd` — day 1/2 = 1.0×, day 3 = 0.70×,
  day 4 = 0.50×, day 5 = 0.30×. Multi-student cross-check.
- `tests/test_fokus_gain.gd` — fokus cat gains +30%, non-fokus −20%,
  wirausaha fokus payout math correct, G7 has fokus == "None" and no
  multiplier applies.
- `tests/test_duet_bonus.gd` — 1 student = 1.0×, 2 = 1.15×, 3+ = 1.0×
  (bonus doesn't stack past pair).
- `tests/test_sliding_threshold.gd` — check_win reads per-grade
  threshold; boundary tests at exactly 1.67, 1.83, 2.00.
- `tests/test_strategic_mechanics_flag.gd` — with
  `STRATEGIC_MECHANICS_ENABLED = false`, all three mechanics no-op.
- Update `tests/test_balance_pacing.gd` — new pass bands for
  10/22/32 targets; new realistic-run simulation.

---

## Success criteria

- **Pacing:** A full playthrough (G7 → G8 → G9) fits in ~90–120 min
  wall time; each grade playable in one sitting.
- **Menari:** Both seni variants appear at least once in any 4+ minigame
  seni run. Reachability test green.
- **Depth:** In playtest, players report choosing between subjects
  actively — not "matching." Duet pairs form intentionally. Fokus is
  used and its choice varies week to week.
- **Difficulty:** G7 win rate for a casual player ≥ 90%; G8 ~65–75%;
  G9 ~40–55%. Measured across ≥ 5 playtest sessions.

## Rollback

- PR1 revert = one commit on Balance.gd (collaborator's call).
- PR2 revert = replace picker with `randi() % arr.size()`, remove tests.
- PR3 revert = flip `STRATEGIC_MECHANICS_ENABLED := false`. Numbers stay
  in Balance.gd (dead), UI stays visible but inert. Cleanup PR follows
  if we abandon.

## Out of scope

- Cosmetic shop stub (existing debt entry).
- New minigame variants (menari/batik are the seni set; adding a third
  is a separate design).
- Faces/blink work (existing debt).
- End-of-grade cutscene copy pass (existing `[PLACEHOLDER]` entries).

## Open items for collaborator

1. Approve or amend the Balance.gd numbers in PR1.
2. Decide on the G7 Maulid holiday (accept zero-holiday final week, or
   remap for G7).
3. Approve `STRATEGIC_MECHANICS_ENABLED` as a master flag, or ask us to
   land the mechanics without the escape hatch.
