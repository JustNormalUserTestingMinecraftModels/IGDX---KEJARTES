# Weekly report reveal (2026-09-14)

Agreed through the /gamecode Brief; all three decisions took the defaults.
Builds on `2026-09-14-weekly-results-design.md`, whose "the student card is
unchanged" line this spec supersedes for the weekly path only.

## What the player gets

The end-of-week report plays out one reward at a time, so every gain gets its
own moment, and the pops climb in pitch as the week adds up.

```
SchoolDay → ResultCheckup → Lobby
  background only → ribbon pops
  card 1 lands → stat 1 counts → pop + sprinkles → stat 2 → stat 3
  card 2 … card N            (the list scrolls to follow)
  coins → EVENT BERHASIL → EVENT GAGAL, each counts, then pops
  confetti (only if the week gained) → Logs / Selanjutnya
```

Entry and exit are unchanged: SchoolDay instances `ResultCheckup.tscn`, calls
`initialize_checkup(student_manager, week_earnings)` and waits for
`checkup_closed`. The nightly Daily Results popup (`DaySummaryPopup`) is not
touched: it keeps calling `play_gain()` and its all-at-once fill.

## Logic

- **Start.** Only the blurred backdrop shows. The ribbon pops in, then the
  cards, the three summary lines and the buttons wait hidden (`modulate.a = 0`,
  which keeps the layout, so nothing reflows as they appear).
- **A card's turn.** The card pops in (`Juice.pop_in`), its energy and mood
  bars travel from Monday to now, and the list scrolls just far enough to show
  the whole card. Then its three stat rows play one at a time, top to bottom.
- **A stat row's turn.** The track fills from Monday's ratio to tonight's and
  the number counts from `+0/65` to the week's `+12/65`, both over
  `count_seconds`. The chevron pops in as the count starts.
  - A row that went **up**: when the count lands the number punches (scale-only
    overshoot about the text's own centre), a `RewardBurst` fires from the
    number, and the `tally` cue plays at the report's climbing pitch.
  - A row that did **not** go up (zero or a loss) counts over the shorter
    `quiet_row_seconds` and lands with no punch, no burst and no sound. This
    keeps the game's standing rule that a flat or losing result stays quiet.
- **Summary.** After the last card's last row, the coin row, EVENT BERHASIL
  and EVENT GAGAL appear in that order. Each pops in and counts from 0 to its
  value. A non-zero value punches when it lands (`coin` for the money line,
  `pop` for the two event lines, all at the climbing pitch). A zero value
  appears already reading 0 and does not punch.
- **Finale.** The paper confetti fires if any card gained (unchanged gate),
  then the Logs and Selanjutnya buttons fade in and enable.
- **Pitch.** Every punch in the report, stats and summary alike, is one step
  higher than the one before: `pitch = min(1.0 + index * pitch_step,
  pitch_max)`. It restarts at 1.0 each week, because each report is a fresh
  screen.
- **Tap to skip.** A tap anywhere during the reveal kills the timeline and
  lands everything at once: every card visible on its final values, every
  summary line on its final text, one `tally` cue (not one per row), then the
  finale. Taps after the reveal do nothing special. It is `_input()` for the
  same reason as `StatCheck`'s: the full-screen controls would otherwise
  claim the tap first.
- **Timing knobs.** `@export`s in a "Reveal" group on `ResultCheckup`, each
  with a `##` line: `card_lead_seconds` 0.35, `count_seconds` 0.35,
  `row_gap_seconds` 0.08, `quiet_row_seconds` 0.15, `card_gap_seconds` 0.15,
  `line_gap_seconds` 0.12, `finale_gap_seconds` 0.2, `pitch_step` 0.06,
  `pitch_max` 1.6. A Kelas 9 roster of four gaining students runs about 9 s;
  Kelas 7's two about 5 s.
- **State.** Reads what the card already reads: `StudentData`'s week deltas
  (`get_akademis_delta()` etc., via `setup_week_row`), `minigame_history`, and
  the `week_earnings` SchoolDay hands over. Writes nothing.
- **Grades.** The same in every grade; only the roster size (2/3/4) changes how
  long it runs and whether the list scrolls (two cards fit on screen).

## Units

| Unit | Role |
|---|---|
| `WeekReportReveal` (new, `Scripts/SchoolSimulation/WeekReportReveal.gd`) | Pure `RefCounted`. `build(row_deltas, line_values, pacing) -> Array` returns the ordered steps (`{at, kind, card, row, pop_index}`), with kinds `CARD`, `ROW_COUNT`, `ROW_POP`, `LINE`, `LINE_POP`, `FINALE`. Also `scroll_to_show(top, bottom, view_height, current) -> float`. No nodes; fully testable without playing anything. |
| `ResultCheckup` | Owns the knobs and pitch. Builds the steps, plays them through one parallel `Tween` of delayed `tween_callback`s, tracks `_revealing`, and implements `skip_reveal()`, `_land_all()`, `_finale()` and `pop_pitch(index)` (static). |
| `DaySummaryStudentRow` | New week-reveal API: `rewind_week()` (stats and needs bars back to Monday, numbers at +0), `play_needs_week()` (the two bars travel), `land_week()` (everything final at once). `play_gain`/`play_week_gain` stay for the nightly popup and existing tests. |
| `DaySummaryStatRow` | New: `rewind()`, `play_count(seconds)`, `land_pop(pitch)`, `land()`, and `shown_delta()` (the delta `set_stat` cached, which `ResultCheckup` feeds the timeline). `land()` kills the row's in-flight tweens so a skip never leaves a number still counting. `play_gain`/`_play_burst` are unchanged (nightly path). |
| `Juice` | New `punch(node, pivot)` (scale-only overshoot, `PUNCH_SCALE` const, `dur_normal`) and `text_center(label) -> Vector2` (honours `horizontal_alignment`). `count_up_formatted` gains an optional `duration` and returns its `Tween`. |
| `AudioDirector` | `play_sfx(id, pitch := 1.0)`: the pitch multiplies the existing random variance. Every current call is unchanged. |

Nothing visual is built at runtime: the burst is the authored `RewardBurst.tscn`
(with `plays_sfx = false` so the climbing tally carries the sound), the cards
are the existing `DaySummaryStudentRow.tscn`, and no scene file changes.

## Tests

- **New suite `week_report_reveal`:** step order (cards in order; a card's rows
  top to bottom before the next card; a pop exactly `count_seconds` after its
  count; no pop for a zero or negative row; lines after the last row, in
  money → won → lost order; no `LINE_POP` for a zero line; `FINALE` last);
  `pop_index` climbs by one per pop across stats and lines; an empty roster
  goes straight to the lines; `scroll_to_show` math.
- **`result_checkup`:** entrance scans updated from `stagger_in(cards)` to the
  timeline; `pop_pitch` climbs and caps; `_land_all()` puts every card and line
  on its final values; `skip_reveal` and `_input` exist and are gated on
  `_revealing`; the week-card tests stay.
- **`day_summary`:** the stat row's `rewind`/`play_count`/`land`/`land_pop`
  behave (tween-stepped); the nightly `play_gain` tests keep passing.
- **`juice`:** `punch` ends at scale 1; `text_center` for left, centre and
  right alignment; `count_up_formatted` honours `duration` and returns a tween.
- **`audio_director`:** `play_sfx` with a pitch sets the player's
  `pitch_scale` around that pitch.
- Kept passing: `audio_coverage` (including the double-fire scan),
  `viewport_editability`, `script_documentation`, `paper_confetti`,
  `card_standing_mode`.
- The final task runs the full suite.

## Not doing

- The nightly Daily Results popup.
- Sparkle particles on the summary lines.
- An extra reward when a stat reaches its target.
- A new particle scene or any `.tscn` change.
- The rejected alternative of speeding the timeline up on tap (StatCheck's
  "rush"): a weekly screen seen up to 16 times per grade should get out of the
  way on one tap.
