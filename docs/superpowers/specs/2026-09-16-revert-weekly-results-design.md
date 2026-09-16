# Revert Weekly Results to the 2026-09-03 report

**Date:** 2026-09-16
**Screen:** `ResultCheckup` — the end-of-week report.
**Branch:** `worktree-revert-weekly-results`, from `origin/Textures` (501d6a5).

## What the player gets

The week-end report goes back to the design that stood before 2026-09-14:
a header, SISWA / RIWAYAT tabs, and the week recap banner with its tappable
pills — and it keeps the paper confetti.

Loop position is unchanged: SchoolDay → **ResultCheckup** → Lobby. Only the
screen's insides change.

## The confetti was never part of the redesign

Worth stating plainly, because it is the whole reason this is a revert and
not a rebuild.

`PaperConfetti.tscn` landed on 2026-09-12 in `c346f62`, **two days before**
the rebuild in `27ce108`. The 2026-09-03 screen already instances it, from
the same `_CELEBRATION_SCENE` constant, at the same `Celebration` node
position, behind the same "did any card gain ground" gate:

```gdscript
if week_gained:
    AudioDirector.play_sfx(&"reward")
    var celebration := load(_CELEBRATION_SCENE).instantiate() as RewardParticles
    celebration.position = get_node("Celebration").position
    add_child(celebration)
    celebration.fire(float(cards.size()) * t.stagger_step)
```

`PaperConfetti.tscn` and `paper_flutter.gdshader` are untouched by every
commit in the redesign range. Restoring the old screen keeps the confetti
for free; nothing is ported and `paper_confetti` stays green.

The one difference: the old call passes a `delay` (the cards' stagger), so
the burst lands just behind the last card's own fill. The new screen fires
`celebration.fire()` with no delay, because its reveal has already finished
by then. The old timing comes back with the old screen — intended.

## What comes back

- Header title `EVALUASI MINGGUAN SISWA` and its subtitle.
- SISWA / RIWAYAT tabs, with the slide+fade pane transition
  (`PANE_SLIDE_DISTANCE`), and the live count in each tab's brackets.
- `WeekRecapBanner` with `WeekRecapPill`s, the pills tappable into
  `WeekRecapPillInfoPopup`, and the banner's idle bounce hint.
- `CoinShower.tscn`.
- The RIWAYAT pane built from `WeekHistoryRow`, with its empty-state label.
- `ScrollFade`, and the `Selesai Evaluasi` close button.
- The old staged entrance: the banner counts, the pills cascade left to
  right, the cards stagger their week gain, then the confetti and the
  button.

## What goes

- The red WEEKLY RESULTS ribbon.
- The coins / `EVENT BERHASIL` / `EVENT GAGAL` summary lines.
- The `Logs` and `Selanjutnya` buttons, and the `ResultButton` variation's
  use here.
- `WeekReportReveal.gd` and its suite: the one-reward-at-a-time playback
  with tap-to-skip.

## What is kept from the redesign era

Three things are deliberately **not** reverted.

1. **`initialize_checkup(student_manager, week_earnings := 0)`.** The second
   argument arrived in `6043538`. `SchoolDay.gd:1291` pays the Wirausaha
   total out — which empties `GameState.pending_earnings` — before opening
   the screen, so without it the banner's money pill reads 0. `DebugManager`
   (2026-09-15, newer than the redesign) also calls
   `report.initialize_checkup(manager, coins)`, and `test_debug_manager`
   pins that call text. The restored screen keeps the two-argument
   signature and feeds `week_earnings` into the banner's money pill.

2. **`Juice.punch` / `Juice.text_center` / the paced count** (`63689da`) and
   **`AudioDirector.play_sfx`'s optional pitch** (`85a2c3f`). Both landed
   under weekly-reveal commits but are general utilities on shared
   autoloads, covered by `juice` and `audio_director`. Reverting them would
   be gratuitous and would risk other callers.

3. **`DaySummaryStudentRow` / `DaySummaryStatRow`.** Today's card is a
   superset of the one the old screen drove: `setup_week_row`,
   `play_week_gain` and `gained_ground` are all still there, so the restored
   `ResultCheckup.gd` calls them unchanged. The reveal-only additions
   (`rewind_week`, `play_needs_week`, `land_week`, `DaySummaryStatRow`'s
   `play_count`) become unused by this screen but stay: they are
   documented, tested, and `c3149e0` has since edited these files, so
   reverting them means fighting unrelated work for no gain.

`WeekLogsPopup` also stays on disk. It pre-dates the rebuild (it is present
at `27ce108^`), which only repurposed it; after the revert it returns to
being unreferenced by ResultCheckup, exactly as it was, and
`week_logs_popup` keeps covering it.

`title_weekly_results.png` stays on disk, unused (Decision 2). It is
referenced only by `ResultCheckup.tscn` and `test_result_checkup.gd` today.

## How the revert is done

The redesign is eight commits — `27ce108`, `6043538`, `e7fc308`, `205e3eb`,
`feebf96`, `4911165`, `dc5c4d7`, `c9c8ef9` — but they are interleaved in
history with unrelated work (face rigs, lobby buttons, exam CG, inventory,
the mobile perf pass), so a range revert is not available. Two mechanisms,
picked per file by who else has touched it since:

**Restore wholesale from `27ce108^`.** Only redesign commits ever touched
these, so the old content applies cleanly:

- `Scenes/SchoolSimulation/ResultCheckup.tscn`
- `Scripts/SchoolSimulation/ResultCheckup.gd`
- `tests/test_result_checkup.gd`

**Restore the files `e7fc308` deleted**, from `e7fc308^`. They do not exist
now, so there is nothing to conflict with:

- `Scenes/SchoolSimulation/WeekRecapBanner.tscn` + `Scripts/SchoolSimulation/WeekRecapBanner.gd` (+`.uid`)
- `Scenes/SchoolSimulation/WeekRecapPill.tscn` + `Scripts/SchoolSimulation/WeekRecapPill.gd` (+`.uid`)
- `Scenes/UI/WeekRecapPillInfoPopup.tscn` + `Scripts/UI/WeekRecapPillInfoPopup.gd` (+`.uid`)
- `Scenes/SchoolSimulation/CoinShower.tscn`
- `Assets/Audio/SFX/pill_tap.ogg`, `pill_popup_open.ogg`, `pill_popup_close.ogg`, `pane_swipe.ogg` (+ their `.import`)
- `tests/test_week_recap_pill_info_popup.gd` (+`.uid`)

**Patch surgically**, because later commits have edited them:

- `Scripts/Design/ThemeFactory.gd` — re-add `RecapBannerPanel`,
  `RecapPillPanel`, `RecapPillValueLabel`, `WeekTabButton`. `12461f1`,
  `6c9f873`, `d33c62f`, `fd3bba7` and `63eff34` have all since edited this
  file; the restored variations must sit alongside their work, not replace
  it.
- `Scripts/Audio/AudioDirector.gd` — re-register the four cues, keeping
  `85a2c3f`'s pitch parameter.
- `Scripts/SchoolSimulation/WeekRecap.gd` — restore the `net_skill_delta`
  key and its computation, `format_skill_delta`, and the money read
  (`_sum_pending_earnings`, feeding `money_earned`).
- `Scripts/SchoolSimulation/WeekHistoryRow.gd` — restore the seven lines
  `e7fc308` changed, keeping `feebf96`'s.
- `tests/test_theme_factory.gd` — `DISPLAY_ROSTER` must name the four
  restored variations, or the suite fails by its own rule (CLAUDE.md).
- `tests/test_week_recap.gd`, `tests/test_audio_director.gd`,
  `tests/test_audio_coverage.gd` — restore the retired coverage.

**Delete:** `Scripts/SchoolSimulation/WeekReportReveal.gd` (+`.uid`),
`tests/test_week_report_reveal.gd` (+`.uid`).

**Rebake the theme.** `Assets/Theme/kejartes_theme.tres` is generated.
Never hand-merge it: run `Scripts/Design/BakeTheme.gd` after ThemeFactory is
right, and verify the bake by content. A full `test_run` also rebakes it in
process, so check `git status` before every commit.

## Risks

- **`WeekTabButton` against the new button rules.** `12461f1` gave every
  action button the Lobby look and `5930d7e` ratcheted button heights onto
  an S/M/L scale. A variation restored from before both may fail
  `button_geometry` or `light_ground_text`. If so, bring it up to today's
  rules rather than loosening the suites.
- **`viewport_editability`'s BASELINE.** The restored screen builds pills
  and history rows at runtime. The ratchet only ever goes down, so if the
  restored code needs entries the current BASELINE does not have, that is a
  reviewed `ALLOWED` exception or a baseline the revert legitimately
  restores — it is not licence to raise the number silently.
- **Pre-existing red on `origin/Textures`.** The baseline run in this
  worktree was 1642/1647: five failures in `inventory` and
  `light_ground_text`, all from `431cc5d`'s inventory redesign (PR #48).
  They are unrelated to this branch. They must be green — by someone's fix
  — before ship-pr can stamp.

## Tests

`result_checkup`, `week_recap`, `week_recap_pill_info_popup` (restored),
`theme_factory`, `theme_rebake`, `audio_director`, `audio_coverage`,
`button_geometry`, `light_ground_text`, `debug_manager`, `school_day`,
`paper_confetti`, `viewport_editability`, `script_documentation`. Dropped:
`week_report_reveal`.

## Decisions as agreed

1. **How far back: the whole rebuild, to 2026-09-03.** The alternative —
   keeping the tap-to-skip reveal on the old layout — is a rewrite, not a
   revert: `WeekReportReveal` is written against a card list and three
   summary lines that the old design does not have.
2. **`title_weekly_results.png` stays on disk, unused.**

## Not doing

`PaperConfetti.tscn` and its shader; `WeekLogsPopup`; SchoolDay's payout;
the shared `Juice` / `AudioDirector` / `DaySummary*` additions listed above.
