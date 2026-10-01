# Per-student lose rule — design

Approved in conversation, 2026-10-01. Plan:
`docs/superpowers/plans/2026-10-01-per-student-lose-rule.md`.

## The request

> for the lose scenario, the player must fill at least 2 of all student
> required stats, if the student only have 1 stat filled then he/she will be
> considered failed and player will get D and lose

Confirmed reading: each student has three skill targets (`akademis`,
`seni_budaya`, `olahraga`; energy and mood never count). If **any one**
student clears fewer than 2 of their 3, the whole run is lost and gets a D.

## The rule

- `GameState.MIN_TARGETS_PER_STUDENT := 2` is our own tunable const in
  `GameState.gd`. `Balance.gd` is a collaborator's file and is not touched.
- A target is cleared by the existing predicate `GameState.target_cleared()`
  (`value >= target`, and a target of 0 or less never clears).
- `check_semester_passed()`: an empty roster passes (unchanged, for debug
  teleports). Otherwise the run passes only when every student is safe.
- This replaces the 2.0-star rule rather than adding to it. "Every student
  clears at least 2 of 3" already means "the roster clears at least 8 of 12",
  so the star check could never fire on its own.
  `Balance.STAR_WIN_THRESHOLD` stops being read anywhere and is left in place,
  noted beside the other unread Balance values in CLAUDE.md.
- Downstream stays as it is. StatCheck writes `run_failed`,
  `RunGrade.letter()` forces a D on a failed run, and
  `RunResult.destination_for()` routes the loss (Kelas 7 to the menu, Kelas 8
  and 9 to a retry).
- The stars (`run_stars()`) stay as a score: in the Lobby header, on
  StatCheck's meter, and in RunGrade's target component. They no longer
  decide the verdict.

## The UI

1. **AturJadwal objective strip.** The chip reads the safe students over the
   roster, "3 / 4", where it read "1.5 / 2" stars. The bar fills to
   safe ÷ roster, so a full bar means the grade passes. The chip's icon
   changes from `star.png` to the existing `Assets/Images/UI/Icons/nav_students.svg`.
   The chip nodes are renamed `StarChip`→`SafeChip` and `Stars`→`Count`.
   Theme variations keep their names, so no rebake is needed.
2. **StatCheck "TIDAK LULUS" stamp.** `StatCheckCard.tscn` gains a hidden
   `FailStamp` (a `DayStampPanel` PanelContainer holding a `DayStampLabel`
   Label, tilted about -6° like SchoolDay's day stamp). After a card's three
   rows fill, StatCheck calls `card.stamp_if_failed()`. For a student under
   the line, that shows the stamp with `Juice.pop_in` and the `stamp` SFX.

## Debug rehearsal presets

Under the new rule, `PRESET_GRADE_B` `[3,3,2,1]` and `PRESET_GRADE_C`
`[3,2,2,1]` would both fail and show a D. They become `[3,3,2,2]` and
`[2,2,2,2]`, and B's minigame tally is retuned so its score stays inside
the B band. `CAMPUR` `[3,2,1,0]` stays as the mixed loss.

## Out of scope

- No change to the star meter, RunGrade weights or letter bands.
- No per-student hint copy on AturJadwal beyond the chip and bar. The
  existing hint already names each student's most urgent skill.
- No retuning of `Balance.gd`. If `test_balance_pacing` fails under the
  stricter rule, it is reported to the owner, not fixed here.
