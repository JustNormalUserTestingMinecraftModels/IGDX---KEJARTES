# Live Balance Tuning Tools — Design

**Date:** 2026-08-28
**Status:** Approved, pending implementation plan

## Problem

KejarTes is a stat-check game: whether a student clears their three academic
targets before the grade's final week is decided entirely by numbers —
personality decay rates, activity gains, efficiency multipliers, minigame
win/loss deltas, quirk coefficients, and the per-grade target uplift.

A tester who plays a week and feels something is wrong ("losing that minigame
gutted her mood") currently has no way to act on it. The number they want is
a hardcoded literal inside a function body — `roundf(randf_range(6.0, 8.0))`
in `apply_personality_daily_decay`, or `mood_change = -18.0` in an
`elif grade_num == 8` branch. Finding it means reading gameplay source;
changing it means editing code and restarting.

That is the gap this fills. **The tester should be able to change the number
themselves, mid-playtest, and immediately replay the situation that exposed
the problem.**

## Goals

1. Every number that affects balance is editable at runtime, from inside a
   running dev build, with no restart and no code editing.
2. A change takes effect on the next call that reads it — the next day
   simulated, the next minigame scored.
3. The tester can capture the situation that revealed the imbalance and
   restore it after changing a number, so the comparison is a real A/B and
   not a vibe.
4. Tuned values can leave the session: written back to a versioned resource,
   or copied out as text.

## Non-Goals

- **No batch simulator.** An earlier draft proposed running semesters
  headlessly and reporting win rates. That answers "is this statistically
  winnable", which is not the question being asked. The tester plays the
  game; the tool only removes the friction between noticing a problem and
  testing a fix.
- **No new save system.** `balance_tokens.tres` is a versioned project asset
  edited by developers, not player state. `GameState` gains no persistence.
- **No rebalancing.** This ships the current numbers unchanged. It supplies
  the instrument, not the tuning.
- **No editor-side tool.** The overlay is the surface, because the user is
  someone mid-playtest. The resource is Inspector-editable for free, which
  covers editor use without extra work.

---

## 1. Mechanism

### The store

`Scripts/Design/BalanceTokens.gd` — a `Resource` whose fields are
`@export var` (not `const`), saved as `Assets/Balance/balance_tokens.tres`.
It mirrors `DesignTokens` / `design_tokens.tres` exactly, including a
`load_default()` accessor:

```gdscript
class_name BalanceTokens
extends Resource

const DEFAULT_PATH := "res://Assets/Balance/balance_tokens.tres"

static func load_default() -> BalanceTokens:
	return load(DEFAULT_PATH) as BalanceTokens
```

### Why this gives live editing for free

Godot's `load()` returns the **cached instance** for an already-loaded
resource. Every caller of `BalanceTokens.load_default()` therefore holds the
same object. Mutating a field on it is immediately visible to every call site
across the codebase — no autoload, no signals, no reload, no restart.

This is the whole trick, and it is why `const` had to go: a GDScript `const`
is compile-time and no UI can ever reach it.

### Call sites

Each extracted literal becomes a field read. A representative example, in
`StudentData.apply_personality_daily_decay`:

```gdscript
# before
"Aktif":
	energy_loss = roundf(randf_range(6.0, 8.0))
	mood_loss = roundf(randf_range(2.0, 4.0))

# after
var b := BalanceTokens.load_default()
"Aktif":
	energy_loss = roundf(randf_range(b.decay_aktif_energy_min, b.decay_aktif_energy_max))
	mood_loss = roundf(randf_range(b.decay_aktif_mood_min, b.decay_aktif_mood_max))
```

Randomness is untouched. The rolled *range* becomes tunable; the roll itself
stays exactly as it is.

---

## 2. Extraction surface

Roughly **90 numbers**, counted from source rather than estimated:

| Group | Count | Where | Notes |
|---|---|---|---|
| Quirk coefficients | 19 | `StudentData.gd` `@export`s | Already exports; re-pointed to read from the resource |
| Personality decay ranges | 20 | `StudentData.apply_personality_daily_decay` | 5 personalities × energy/mood × min/max |
| Minigame win/loss deltas | 21 | `StudentData.apply_minigame_result` | Grade-branched stat, energy and mood values |
| Rest recovery + activity cost | 8 | `StudentData.apply_jadwal_activity` | `randf_range` bounds |
| Efficiency multipliers | 3 | `StudentData.get_category_efficiency_multiplier` | 0.6 / 0.85 / 1.20 |
| Thresholds | 2 | `StudentData` | Auto-Izin at energy ≤ 5, `is_tired` at ≤ 20 |
| Base gain / specialty bonus | 6+2 | `StudentManager.apply_daily_decay_all`, `apply_jadwal_effects_all` | Per-grade, plus the two defaults |
| Wirausaha | 5 | `StudentManager` `const` block | Mechanical move |
| Grade target uplift | 3 | `GameState.initialize_grade_targets` | +15 / +30 / +40 |
| Fast-path minigame odds | 1 | `SchoolDay.skip_to_results` | The `randf() > 0.4` threshold |

### The safety property

Extraction must be provably behaviour-preserving. Two things guarantee it:

1. `balance_tokens.tres` ships seeded with **today's exact values**, so a
   correct extraction changes nothing observable.
2. The existing 303-test suite already pins real numeric outcomes —
   `test_wirausaha`, `test_school_day`, `test_economy_state`,
   `test_student_card` — so a literal that shifts during the move fails a
   test rather than silently altering difficulty.

Extraction lands in small per-group commits with the suite green after each.

---

## 3. The Balance tab

A sixth tab in `DebugManager`, beside General / Students / Minigames /
Scenes / Logs, built with the same data-driven pattern the student stat
editor already uses: an array of row descriptors rendered as a label showing
the current value above a row of adjust buttons.

Each row descriptor carries its own metadata, because the knobs differ in
scale by three orders of magnitude — an efficiency multiplier steps by 0.05,
a target uplift by 5:

```gdscript
{ "key": "decay_aktif_energy_min", "label": "Aktif · energy loss (min)",
  "step": 0.5, "min": 0.0, "max": 20.0 }
```

**Grouping.** Ninety rows in a flat list is unusable mid-playtest, so:

- **Common** — the eight knobs most likely to be the culprit when something
  feels wrong, duplicated at the top rather than moved (they also appear in
  their own group):
  1. Grade target uplift, current grade
  2. Base gain, current grade
  3. Minigame loss — stat penalty, current grade
  4. Minigame loss — mood penalty, current grade
  5. Minigame win — stat gain, current grade
  6. Rest recovery — energy min/max
  7. Non-specialty efficiency multiplier (1.20)
  8. Auto-Izin energy threshold (5.0)
- Then Targets / Decay / Activity / Minigame / Quirks / Wirausaha.
- A **filter box** at the top of the tab. This is load-bearing at 90 rows,
  not a nicety: type `mood` and see every mood-related number at once.

**Change tracking.** A row whose value differs from the shipped default is
marked, so the tester can see at a glance what they have touched. Per-row
and global "reset to default".

---

## 4. Scenario snapshot

Two buttons, and the piece that makes the loop an actual comparison.

- **Snapshot** — captures `GameState.approved_students` (deep, including
  every stat), `minggu_ke`, `current_grade`, `day_schedules`, and
  `player_money` into memory.
- **Restore** — writes them all back.

The intended loop:

> play → something feels wrong → **Snapshot** → change a number →
> **Restore** → replay that exact week with one variable changed

Same students, same stats, same schedule. Without this, reproducing "week 5,
Citra at 41 energy, these schedules" means hand-driving the week setter and
five per-student stat editors — the friction that makes a tool go unused.

In-memory only, one slot, cleared on quit. It is a comparison aid, not a save
system.

---

## 5. Getting values out

Two exits, because the tester may be in the editor or on a device:

- **Save to `.tres`** — `ResourceSaver.save()` over `balance_tokens.tres`.
  Real persistence, git-diffable, a developer commits it. Works wherever
  `res://` is writable, i.e. editor and debug builds.
- **Copy changed values** — dumps **only fields differing from default** as
  a paste-ready block. For a tester on an exported build who needs to hand
  numbers to someone else. Only-the-diff matters: a 90-line dump where two
  numbers changed is not a useful message.

---

## 6. Behavioural caveats

**Target uplift is baked, not read per call.** `initialize_grade_targets()`
writes `target_akademis1/2/3` onto each student dictionary once. Changing the
uplift mid-semester does not retarget anyone already in play, so that group
gets a **"Re-apply targets now"** button that re-runs it against the live
roster. Every other number is read at call time and applies to the next day
or next minigame with no action needed.

**Quirk coefficients change globally, not per student.** They are currently
per-instance `@export`s on `StudentData`, though every instance carries
identical values. Reading from the shared resource makes that sameness
explicit. Per-student variation was never used and is not being removed —
it never existed.

**`load_default()` on a hot path.** It is called per student per day. Since
`load()` hits the resource cache rather than disk, this is a dictionary
lookup. Call sites in loops hoist it to a local (`var b := ...`) as shown
above, matching how `DesignTokens` is already used in this codebase.

---

## 7. Testing

- `tests/test_balance_tokens.gd` — the resource loads; every field in the
  row-descriptor tables exists on it (catches a typo'd key silently
  rendering a dead row); `load_default()` returns the same instance twice
  (the property the whole design rests on); defaults match the values the
  game shipped with.
- `tests/test_balance_snapshot.gd` — snapshot then restore leaves all five
  captured fields byte-identical; restore with no snapshot taken is a no-op
  rather than a crash.
- **The existing suite is the extraction's real guard.** No new test proves
  a literal moved correctly; `test_wirausaha` and `test_school_day` already
  do, by asserting outcomes that depend on those numbers.

Per the runner's constraints: suites are `@tool`, no test is a coroutine,
and `DebugManager.gd` stays non-`@tool`, so UI wiring is verified by
source-scan in the manner `tests/test_debug_manager.gd` already establishes.

---

## 8. Risks

1. **Extraction is ~90 mechanical edits in gameplay-critical files.** The
   value is guarded by the existing suite, but the volume is the main cost
   and the main risk. Mitigated by per-group commits, each verified green.
2. **A missed literal is invisible.** If one is left hardcoded, its row
   silently does nothing when the tester drags it. The per-group commit
   structure and a final grep sweep for bare numeric literals in the four
   touched functions are the defence.
3. **90 rows is a lot of UI.** Mitigated by grouping, the Common section,
   and the filter box — but if it still reads as unusable in practice, the
   fix is curation of the Common set, not more features.
4. **`ResourceSaver.save()` fails in an exported release build**, where
   `res://` is read-only. The tool is dev-facing, and "Copy changed values"
   is the fallback path for exactly that case.

---

## 9. Deliberately deferred

- **Batch simulation / win-rate analysis.** Cut deliberately; see Non-Goals.
  The design does not preclude it — a headless runner could later drive the
  same `StudentManager` against the same tokens — but it answers a different
  question and is not being built now.
- **Wirausaha and the item economy remain untuned by feedback.** Their
  constants are extracted and editable, but nothing in this tool exercises
  the Koperasi purchase loop, so changes there get no signal beyond
  ordinary play.
- **Multiple snapshot slots / named scenarios.** One slot until one slot
  proves insufficient.
- **Undo history on tuning.** "Reset to default" covers the common case.
