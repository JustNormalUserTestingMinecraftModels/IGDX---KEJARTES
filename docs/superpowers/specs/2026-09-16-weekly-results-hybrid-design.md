# Weekly Results: the reverted report, with Logs and Selanjutnya

**Date:** 2026-09-16
**Screen:** `ResultCheckup` — the end-of-week report.
**Branch:** `worktree-revert-weekly-results` (continues
`docs/superpowers/specs/2026-09-16-revert-weekly-results-design.md`).

## What the player gets

The 2026-09-03 report keeps its banner, pills, header and student cards, but
the SISWA / RIWAYAT tabs go away and the rebuild's two-button row comes back:
**Logs** opens the week's history as a sheet, **Selanjutnya** closes the
screen.

The week's history is not lost — it moves from the retired RIWAYAT pane into
`WeekLogsPopup`, which already exists, is covered by the `week_logs_popup`
suite, and was re-orphaned by the revert two commits ago. The rebuild had
borrowed it; this borrows it back.

Loop position is unchanged: SchoolDay → **ResultCheckup** → Lobby.

## What goes

From `ResultCheckup.tscn`:

- `Margin/VBox/TabBar` with `TabSiswa` and `TabRiwayat`.
- `Margin/VBox/ScrollContainer/PaneStack/HistoryPane` and its `EmptyLabel`
  (the sheet has its own empty state, `empty_text`).
- `PaneStack` itself — with one pane left it stacks nothing, so
  `StudentsPane` moves up to sit directly under `ScrollContainer`
  (Decision 1). Its own properties are unchanged: `layout_mode = 2`,
  `size_flags_horizontal = 3`, `separation = 28`, `alignment = 1`.
- `BtnClose`.

From `ResultCheckup.gd`:

- `enum Pane`, `PANE_SLIDE_DISTANCE`.
- `show_pane()`, `_transition_panes()`, `_sync_tab_buttons()`,
  `_update_tab_counts()`, `_play_history_entrance()`.
- `_active_pane`, `_pane_scroll`, `_history_animated`, `_history_rows`.
- The `tab_students_text` / `tab_history_text` exports, and the
  `button_close_texture` / `close_button_text` pair.
- `history_row_scene` — the sheet carries its own.
- The `tab_siswa`, `tab_riwayat`, `history_pane`, `history_empty_label` and
  `btn_close` `@onready`s, and the tab wiring in `_ready`.

## What comes back

The button row, exactly as the rebuild had it:

```
[node name="Buttons" type="HBoxContainer" parent="Margin/VBox"]
theme_override_constants/separation = 120
alignment = 1
```

with `LogsButton` and `NextButton` inside it — `ResultButton` variation,
`custom_minimum_size = Vector2(0, 160)`, `size_flags_horizontal = 3` so the
row splits equally. The 2026-09-14 spec's note stands: the display face sets
SELANJUTNYA in capitals and needs about 435 px, which is why the two share
the row rather than taking the mockup's fixed 368.

And the sheet's wiring, lifted from the rebuild:

- `@export var logs_popup_scene: PackedScene`, assigned to
  `WeekLogsPopup.tscn`.
- `@export var logs_button_text: String = "Logs"` and
  `@export var next_button_text: String = "Selanjutnya"`.
- `var _history: Array`, `var _logs_seen: bool`, `var _logs_popup: Control`.
- `open_logs()`, unchanged: it refuses to stack a second sheet, presets the
  instance to full rect, hands it `_history`, clears `_logs_popup` on the
  `closed` signal, and animates the rows only on the first open so reopening
  never re-fires the stamp cue.

## What stays

Everything the last two days restored and the user did not ask to change:
`WeekRecapBanner` and its pills, `WeekRecapPillInfoPopup`, `CoinShower`, the
header and subtitle, `ScrollFade`, the `DaySummaryStudentRow` cards, the
drag-to-scroll handler, and the paper confetti behind its week-gained gate.

`initialize_checkup(student_manager, week_earnings)` keeps both arguments and
the `money_earned` override — `SchoolDay.gd:1291` and `DebugManager.gd:1420`
both call the two-argument form. Its only change: instead of building
`WeekHistoryRow`s into a pane, it stores
`_history = student_manager.minigame_history.duplicate()` for the sheet.

`pill_tap`, `pill_popup_open` and `pill_popup_close` all stay — the pills
they belong to stay.

## What is retired, again (Decision 2)

Both were restored two commits ago for the tabs, and the tabs are now gone:

- The `WeekTabButton` theme variation, with a rebake. It is **not** in
  `DISPLAY_ROSTER`, so `test_theme_factory` needs no change for it;
  `RecapPillValueLabel` stays there for the pills.
- The `pane_swipe` cue, its `_resolve_sfx` arm, its `.ogg` and `.import`,
  and its entries in `test_audio_director` and `test_audio_coverage`.

`RecapBannerPanel`, `RecapPillPanel` and `RecapPillValueLabel` stay — the
banner and pills still use them.

## Debt this resolves

Two thirds of the entry the revert added to `DEBT.md`:

- `ResultButton` gets its call site back, so it is no longer a variation kept
  alive only by `tests/test_lobby_style_buttons.gd:82`.
- `WeekLogsPopup` gets its call site back and is no longer orphaned.

`Assets/Images/DaySummary/title_weekly_results.png` is **still** orphaned —
the ribbon does not come back, only the buttons. That line stays.

## Risks

- **The entrance's last stage.** It currently fades in `btn_close` alone;
  it must fade in and enable both buttons. Modelled on the rebuild's own
  finale, which enables each button only once shown, so the tap that
  dismissed something else cannot land on a freshly-enabled button.
- **`viewport_editability`.** `ResultCheckup.gd`'s baseline entry is `1`,
  earned by building history rows at runtime. Those rows move into
  `WeekLogsPopup`, which has its own entry, so this screen's number should
  fall. The ratchet only ever goes down — if it now needs 0, set 0.
- **`test_school_day`'s touch-target map** names `Margin/VBox/BtnClose`. It
  becomes the two buttons under `Margin/VBox/Buttons/`.
- **`result_checkup`'s tab and pane coverage** — the scroll-memory tests, the
  pane transition, the tab counts and the history-pane tests — is deleted
  with the feature, not adapted. New coverage takes its place for the Logs
  button and the sheet it opens.
- **Pre-existing red on `Textures`** — 5 failures in `inventory` and
  `light_ground_text` from PR #48. Not this branch's; they are the floor.

## Tests

`result_checkup`, `week_logs_popup`, `school_day`, `debug_manager`,
`viewport_editability`, `theme_factory`, `theme_rebake`, `button_geometry`,
`lobby_style_buttons`, `audio_director`, `audio_coverage`,
`script_documentation`, `paper_confetti`, `week_report_rehearsal`.

## Decisions as agreed

1. **`StudentsPane` moves up under `ScrollContainer`**, and `PaneStack` is
   deleted rather than left wrapping a single child.
2. **`WeekTabButton` and `pane_swipe` are retired**, rather than left in the
   tree with no consumer.

## Not doing

The banner, pills, pill info popup, header, subtitle, cards, `ScrollFade` or
the confetti; the three pill cues; the ribbon art; `WeekRecap`'s API.
