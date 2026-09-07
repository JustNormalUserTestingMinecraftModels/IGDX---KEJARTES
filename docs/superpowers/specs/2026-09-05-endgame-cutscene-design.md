# End-game cutscene (win / lose beat) — design

**Date:** 2026-09-05
**Status:** Approved
**Supersedes:** the unimplemented parts of
`docs/superpowers/plans/2026-09-04-endgame-b-win-lose-screens.md` (Plan B).

## Problem

`StatCheck` decides the verdict (`GameState.run_failed`, `StatCheck.gd:157`)
and ends on a full white fade, but both of its hand-off constants still point
straight at `RunResult.tscn` (`StatCheck.gd:21-22`). There is no beat between
the check and the report — the run's outcome is never *shown*, only tallied.

Plan B specified a win/lose pair for this slot on 2026-09-04 but was never
built: `EndScreen.gd` and `LoseScreen.tscn` do not exist, and the
`WinScreen.tscn` in the working tree is an abandoned stub (a copy of
CutScene's layout — dialogue box and hint label, no stamp, no script).

## Design

One scene, `EndCutscene`, between StatCheck and RunResult. It shows a single
full-bleed image for the outcome, stamps a badge into the top-left, then
reveals a Next button.

This revises Plan B in two ways, per the 2026-09-05 brief:

- **One scene, not two.** `EndCutscene.tscn` picks its backdrop and badge from
  `GameState.run_failed` rather than the verdict picking between two authored
  scenes. For a screen this small (backdrop, badge, button) two near-identical
  scenes cost more to keep in sync than the three ternaries the branch costs.
- **A Next button, not tap-anywhere.** The button is the only way forward, and
  it does not exist until the badge has landed.

### Sequence

Every duration below is an `@export` on `EndCutscene.gd`.

| Beat | What happens | Default |
|---|---|---|
| 0 | Scene opens under an **opaque white** `ColorRect`, completing the fade StatCheck ends on. Badge and button start invisible. | — |
| 1 | White fades out, revealing the backdrop. | `white_fade_seconds = 0.8` |
| 2 | Hold, so the image reads before anything lands on it. | `image_hold_seconds = 0.6` |
| 3 | **Badge slams** into the top-left: down from 3× scale with a `TRANS_BACK` overshoot, `Juice.shake` on its parent, `stamp` SFX — the same gesture `RunResult._slam_grade()` uses for the letter. | `Juice.tokens().dur_fast` |
| 4 | Hold. | `button_delay_seconds = 0.5` |
| 5 | **Next button** pops in (`Juice.pop_in`) and becomes pressable. | — |
| 6 | Press → `Transition.change_scene(RunResult)`. | — |

Taps before beat 5 do nothing: the button is the only input, and it is
`disabled` + transparent until then.

### Verdict binding

`GameState.run_failed` is read once in `_ready()`. It selects backdrop
texture, badge texture, and BGM id from two `@export` pairs. Nothing else in
the scene branches.

BGM ids are `result_win` / `result_lose`, the ids the deleted SemesterEnd
used (Plan B's D4); both already resolve through `AudioDirector`.

### Assets

| Asset | Source |
|---|---|
| `Assets/Images/CG/cg_lose.jpg` | Imported from the supplied `Downloads/CG_lose.jpg`. |
| Win backdrop | `Assets/Images/CG/cg2.jpg`, existing, as a **placeholder**. |
| `Assets/Images/UI/Placeholders/stamp_lulus.svg` | Generated: rotated rounded-rect rubber stamp, green, "LULUS". |
| `Assets/Images/UI/Placeholders/stamp_gagal.svg` | Generated: same, red, "GAGAL". |

The badges are real transparent SVG textures, not emoji glyphs — emoji as UI
iconography is banned project-wide (CLAUDE.md, Conventions).

**Note on the win backdrop.** The file supplied as `Downloads/CG_win.jpg` was
not imported. It depicts a Nazi concentration camp — the Auschwitz gate
("ARBEIT MACHT FREI"), a figure in camp-guard uniform, prisoners in the
background — which is not something this project will ship as the screen
celebrating a passed grade. The backdrop is an `@export`, so final art can be
assigned in the Inspector without touching code.

### Code changes

| File | Responsibility |
|---|---|
| `Scripts/EndGame/EndCutscene.gd` (create) | The whole beat: verdict binding, white fade-out, badge slam, button reveal, hand-off. |
| `Scenes/EndGame/EndCutscene.tscn` (create) | Authored chrome: Backdrop, Badge, BtnNext, WhiteFade. |
| `Scripts/EndGame/StatCheck.gd` (modify) | `NEXT_SCENE_WIN` / `NEXT_SCENE_LOSE` both repoint at `EndCutscene.tscn`. |
| `Scenes/EndGame/WinScreen.tscn` (delete) | Abandoned stub, superseded. |
| `CLAUDE.md` (modify) | Flow line gains the new screen. |

### Tests

- `tests/test_end_cutscene.gd` (create) — structural checks on a bare
  `instantiate()` (the four nodes exist; WhiteFade starts opaque; badge and
  button start invisible; button starts disabled) plus source scans for beat
  order (fade → slam → button → hand-off) and the RunResult destination.
  Same technique the other end-game suites use: the sequence is a tween chain
  the runner cannot await.
- `tests/test_stat_check.gd` (modify) — the one test asserting the hand-off
  target now expects `EndCutscene.tscn` for both verdicts.
- `tests/test_audio_coverage.gd` (modify, if it names the result BGM ids) —
  point at the new scene's exports.

### Out of scope

- No change to StatCheck's verdict logic, RunGrade, or RunResult.
- No dialogue, no multi-image sequence — one image per outcome, per the brief.
- The debug overlay's rehearsal presets need no change: they enter at
  TesNotice and will flow through this screen automatically.
