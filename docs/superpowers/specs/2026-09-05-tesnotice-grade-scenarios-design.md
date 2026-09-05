# TesNotice grade-letter test scenarios — design

**Date:** 2026-09-05
**Status:** Approved

## Problem

The debug overlay's Scenes tab already offers "Gladi Resik Akhir Kelas" — three
one-click rehearsals of the whole end-of-grade sequence (TesNotice ->
ExamProgress -> StatCheck -> RunResult) tuned around the star-meter
pass/fail narrative (Semua Lulus / Semua Gagal / Campur). There is no
equivalent for exercising RunResult's *letter grade* specifically: verifying
that the A, B, C and D bands each render correctly still requires manually
tuning a run's minigame/money/event stats and academic targets by hand.

## Design

Extend the existing rehearsal jig (`Scripts/Debug/EndGameRehearsal.gd`,
`Scripts/Debug/DebugManager.gd`) with four more presets, one per letter
bucket, using the same snapshot/arm/teleport machinery already proven by the
Lulus/Gagal/Campur presets. No new architecture — just new preset data plus
four new buttons.

### The math

`RunGrade.score()` (`Scripts/EndGame/RunGrade.gd`) computes a 0-100 score as
four weighted parts: targets cleared 55%, minigame win-rate 20%, wirausaha
money 15%, event participation 10%. `RunGrade.letter()` maps that score to a
band (A+/A/A- ... C-) only when `GameState.check_semester_passed()` is true
(roster-wide star meter >= `Balance.STAR_WIN_THRESHOLD`, i.e. cleared/total
>= 2/3); otherwise the letter is unconditionally "D".

With the debug roster fixed at 4 students (`DebugManager.DEFAULT_STUDENTS`),
academic targets total 12 (4 students x 3 skills each). Each new preset is
tuned to land its resulting score comfortably inside one letter band (a few
points of margin from both edges, so it isn't flaky):

| Preset | Cleared/total | Minigames (W-L) | Money | Events | Score | Band | Letter |
|---|---|---|---|---|---|---|---|
| `PRESET_GRADE_A` | 12/12 | 6-5 | 20,000 | 4/4 | 55 + 10.91 + 15 + 10 = 90.91 | [88, 95) | **A** |
| `PRESET_GRADE_B` | 9/12 | 6-4 | 12,000 | 2/4 | 41.25 + 12 + 9 + 5 = 67.25 | [64, 72) | **B** |
| `PRESET_GRADE_C` | 8/12 | 0-0 | 10,000 | 0/4 | 36.67 + 0 + 7.5 + 0 = 44.17 | [40, 48) | **C** |
| `PRESET_GRADE_D` | 4/12 | 1-6 | 2,000 | 1/4 | n/a — fails to pass (4/12 < 2/3) | — | **D** |

Per-student cleared counts (out of 3 skills), matching the existing
`CLEARED_COUNTS` shape:
- A: `[3, 3, 3, 3]` (full clear)
- B: `[3, 3, 2, 1]` (9 total)
- C: `[3, 2, 2, 1]` (8 total — exactly the 2/3 pass threshold)
- D: `[2, 1, 1, 0]` (4 total — clearly under threshold)

### Code changes

1. **`Scripts/Debug/EndGameRehearsal.gd`**
   - Add `PRESET_GRADE_A`, `PRESET_GRADE_B`, `PRESET_GRADE_C`, `PRESET_GRADE_D`
     string constants.
   - Add their entries to `CLEARED_COUNTS` (the per-student cleared-count
     arrays above).
   - Add their entries to `REHEARSAL_STATS` (won/lost/points/items/money/events
     matching the table above). `points` and `items` are cosmetic display
     values only — not part of `RunGrade.score()` — set to plausible numbers
     consistent with the win/loss counts.
   - A short comment block explaining these four target specific letter
     bands (unlike Lulus/Gagal/Campur, which target the star-meter
     narrative), with the band math cross-referenced to `RunGrade.gd`.

2. **`Scripts/Debug/DebugManager.gd`**
   - In `_build_scenes_panel()`, add a new labeled subsection below the
     existing "Gladi Resik Akhir Kelas" block: "Skenario Nilai Akhir
     (A/B/C/D)", with four buttons wired to the existing
     `_start_end_game_rehearsal(preset)` handler (unchanged) — same
     snapshot/arm/teleport-to-`TesNotice.tscn` flow, same restore button
     already covers these too since `_rehearsal_snapshot` is shared state.

### Tests

1. **`tests/test_end_game_rehearsal.gd`** — four new behavioral tests, one
   per preset, mirroring the existing
   `test_arm_makes_the_lulus_preset_actually_pass_the_stat_check` /
   `..._gagal_preset_actually_fail...` pattern: arm the preset against a
   4-student fake source, then independently compute
   `RunGrade.score()` + `RunGrade.letter()` from the resulting `GameState`
   (same call RunResult itself makes) and assert the letter is exactly
   "A" / "B" / "C" / "D".
2. **`tests/test_debug_manager.gd`** — extend the existing
   `test_rehearsal_buttons_exist_for_all_three_presets`-style source scan (or
   add a sibling test) asserting `_build_scenes_panel` references each of
   the four new preset constants.

### Out of scope

- No change to `RunGrade.gd`, `RunResult.gd`, or any shipped screen.
- No change to the existing Lulus/Gagal/Campur presets or their tests.
- Not wiring these into `EndGameRehearsal.arm()`'s public contract beyond
  adding dictionary entries — `build_roster()` and `_seed_run_stats()`
  already handle arbitrary presets via dictionary lookup with a `campur`
  fallback, so no control-flow changes are needed there.
