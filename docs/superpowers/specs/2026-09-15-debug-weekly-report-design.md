# Debug: weekly report preview (2026-09-15)

Agreed in chat. The one decision took the default: the same fixed sample week
on every press.

## What it gives

One button in the debug overlay's **Scenes** tab opens the weekly report
(`ResultCheckup`) over whatever screen is showing, filled with a sample week,
so the reveal (`2026-09-14-weekly-report-reveal-design.md`) can be watched in
one click instead of played for a week.

```
Debug overlay → Scenes → "📊 Laporan Mingguan (ResultCheckup)"
  → the overlay closes → the report plays over the current screen
  → Selanjutnya closes it → back where you were
```

## Logic

- **Roster:** the approved roster, so Kelas 7 shows 2 cards and Kelas 9 shows
  4. When nothing is approved yet, the handler first calls
  `_auto_approve_students()`, the same thing the Students tab's button does,
  and logs it.
- **Sample week:** `WeekReportRehearsal.apply_sample_week(manager)` works on a
  throwaway `StudentManager` built with `initialize_from_gamestate()`, which
  takes the Monday snapshot the card measures from. It is fixed, so every
  press shows every beat of the reveal. Numbers are consts in the helper.
  - Skills (akademis, seni_budaya, olahraga), by roster slot:
    `[12, 8, 5]`, `[9, -3, 6]`, `[0, 7, 0]`, `[0, 0, 0]`. That is all three
    up; two up and one down; one up; flat. Slots past the ladder repeat its
    last entry. Every stat is clamped to 0–100, as the simulation clamps.
  - Needs: energy −12 and mood +6 for everyone, so both bars travel and show
    their chevrons.
  - History: three minigames (Pilihan Ganda won, Badminton lost, Buat Batik
    won) and one Nasi Kotak event, in the shapes
    `StudentManager.record_minigame_result`/`record_event_result` append.
    That makes EVENT BERHASIL 2 and EVENT GAGAL 1, and gives Logs four rows.
  - Coins: 1.500 (`SAMPLE_EARNINGS`), handed to `initialize_checkup`.
- **Nothing in the run changes.** `GameState` stats, money, week and
  schedules are not written: the sample lives on the throwaway manager's
  `StudentData` copies, and `ResultCheckup` writes nothing. The manager is a
  `Node`, so it is freed right after `initialize_checkup`, which has already
  copied everything it needs.
- **Hosting:** like the standalone minigame launcher, a `CanvasLayer` just
  under the overlay (layer 124; the launcher uses 125, the overlay 128). It
  is parented to the current scene (falling back to the overlay itself when
  there is none), so a teleport also takes it down.
  `checkup_closed` frees it. A second press while it is open is a logged
  no-op. Game speed is reset to 1× first.
- **Debug only:** nothing outside `Scripts/Debug/` may name
  `WeekReportRehearsal`, enforced the same way as `EndGameRehearsal`.

## Files

- `Scripts/Debug/WeekReportRehearsal.gd`: new, a pure static helper.
- `Scripts/Debug/DebugManager.gd`: the button, `_open_week_report_preview()`
  and `_close_week_report_preview()`. The debug overlay is out of the design
  system's scope, so building its button in code is the file's norm.
- Tests:
  - `week_report_rehearsal`, a new behavioural suite over a `StudentManager`
  - `debug_manager`, source scans: the button is wired; the handler approves
    only when empty, builds from GameState, applies the sample, hosts on the
    current scene, frees on `checkup_closed`, and frees the manager; the
    debug-only ratchet covers the new name

## Not doing

- Replaying the real last week: its data is gone once SchoolDay writes the
  week back, and nothing persists it.
- Random gains on each press.
- Going on to the Lobby after Selanjutnya.
