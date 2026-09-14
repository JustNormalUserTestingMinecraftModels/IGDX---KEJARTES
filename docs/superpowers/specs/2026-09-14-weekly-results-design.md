# Weekly Results — ResultCheckup rebuilt to the mockup (2026-09-14)

Mockup: `docs/superpowers/mockups/mockup_weeklyresults.png` (1080x1920, from
the team Drive). Agreed through the /gamecode Brief; all three decisions took
the defaults.

## What the player gets

The end-of-week screen now matches the mockup. A red "WEEKLY RESULTS" ribbon
sits over the blurred school, with one cream card per student beneath it. Then
come the coins earned this week, how many minigames were won and lost, and
two buttons: **Logs** and **Selanjutnya**.

```
SchoolDay → [Weekly Results] → Lobby
               └─ Logs ─→ the week's minigames & events → back
```

Entry and exit are unchanged: SchoolDay instances `ResultCheckup.tscn`, calls
`initialize_checkup(student_manager)`, and waits for `checkup_closed`.

## Layout (top to bottom, 1080x1920)

| Node | What | Mockup geometry |
|---|---|---|
| `Backdrop` | `TextureRect`, `blur_background.png`, full rect, authored in the scene | full screen |
| `TitleBanner` | `TextureRect`, `title_weekly_results.png`, centred | x 95..1025, y 40..330 |
| `CardsScroll` / `CardsList` | vertical `ScrollContainer` > `VBoxContainer` of `DaySummaryStudentRow` (week mode) | cards x 45..1035, ~400 tall, ~65 apart |
| `Summary/CoinRow` | `uang.png` icon + money label | y ~1270..1390 |
| `Summary/EventWonLabel` | "EVENT BERHASIL : 4" | y ~1430 |
| `Summary/EventLostLabel` | "EVENT GAGAL : 3" | y ~1515 |
| `Buttons/LogsButton`, `Buttons/NextButton` | "Logs", "Selanjutnya" | two ~370-wide buttons, y ~1655..1810 |
| `Logs` | the `WeekLogsPopup` instance, hidden until opened | overlay |
| `Celebration` | the existing idle `PaperConfetti` anchor | unchanged |

When the roster doesn't fit in the space between the ribbon and the summary,
the cards scroll. The existing touch-drag handler moves to `CardsScroll`.

The money and event labels use the card's own `DaySummaryStat` text style:
display face, white fill, purple outline. The mockup's summary text is the
same style as the card's "+12/65".

## Logic

- **The student card is unchanged.** `DaySummaryStudentRow.setup_week_row()`
  and `play_week_gain()` keep doing what they do today.
- **Money** is `WeekRecap.compute().money_earned`, the week's unpaid Wirausaha
  earnings. It reads `"+" + format_money(v)` for a positive week and
  `format_money(v)` otherwise, and counts up on entrance.
- **EVENT BERHASIL** counts the minigames won, and **EVENT GAGAL** the
  minigames lost (`minigames_total - minigames_won`, a new `minigames_lost`
  key). Random events (`category == "Event"`) are always recorded as won and
  cannot fail, so they are counted in neither line. They appear in Logs.
- **Logs** opens `WeekLogsPopup`. It holds a scrim, a card with the title
  "LOGS", and a scroll of one `WeekHistoryRow` per `minigame_history` entry.
  It also carries the existing empty line ("Tidak ada minigame yang dimainkan
  minggu ini.") and a close button. It follows the popup-dismiss rule: the
  scrim starts at `MOUSE_FILTER_IGNORE` and turns STOP only after the open.
  The rows are built once, in `initialize_checkup`. Their stamp-and-shake
  entrance plays on the first open only, keeping today's latch.
- **Selanjutnya** fades out and emits `checkup_closed`, like today's close
  button.
- **Entrance:**
  1. The screen fades in.
  2. The ribbon pops in.
  3. The cards stagger in, each playing its week gain.
  4. The money counts up and the event lines pop.
  5. The confetti fires, gated as today on a week that gained ground.
  6. The buttons fade in and enable.
- State: reads `StudentManager.minigame_history`,
  `StudentManager.daily_stat_log` (through the card) and
  `GameState.pending_earnings`. Writes nothing.
- Grades: the same in every grade.
- Every label string is an `@export` with a `##` line: the two event-line
  prefixes, the button labels and the Logs title.

## Theme

A new `ResultButton` variation, a `StyleBoxTexture` over
`Assets/Images/DaySummary/card_bg.png`: the same cream as the cards, 9-sliced.
The text is the display face, white with the purple outline. Authored height
160, a button size step. Like `MainMenuButton`, it is a textured variation, so
`test_button_geometry` allow-lists it and checks the texture path instead.
Rebake `kejartes_theme.tres`.

## The ribbon asset

`Assets/Images/DaySummary/title_weekly_results.png` is a **placeholder**. The
mockup's ribbon region is cut out and given the alpha of
`title_daily_results.png`, scaled to that region, since the two ribbons are
the same art with different words. It is checked by eye against the mockup,
and noted in CLAUDE.md's generated-placeholder list as drop-replaceable at
the same path.

## Retired

- `WeekRecapBanner` (`.gd`, `.tscn`), `WeekRecapPill` (`.gd`, `.tscn`) and
  `WeekRecapPillInfoPopup` (`.gd`, `.tscn`, and its suite).
- The SISWA/RIWAYAT tabs and their pane code.
- Whatever only they used: the `WeekTabButton` variation, the
  `pill_popup_open`/`pill_popup_close`/`pane_swipe` cues, `CoinShower`, and
  the recap placeholder icons. Each is removed only if a usage check shows
  nothing else references it.
- `WeekRecap.net_skill_delta` and `format_skill_delta`, if nothing else
  reads them.

## Tests

- `result_checkup` rewritten for the new layout. The week-card tests stay;
  the tab, pane, banner and pill tests go.
- `week_recap` gains `minigames_lost`.
- New suite: `week_logs_popup`.
- Kept passing: `paper_confetti`, `button_geometry` (allow-lists
  `ResultButton`), `viewport_editability` (ResultCheckup's `BASELINE`
  lowered, since the runtime backdrop and close-button styleboxes go),
  `audio_coverage` and `theme_factory`.
- The final task runs the full suite.

## Not doing

- The tabs; Logs replaces them.
- Changes to the student card.
- New stats, or anything persisted.
- Waiting for final ribbon art.
