# ResultCheckup clarity pass — design

Date: 2026-09-29. Approved by the owner in chat, with a side-by-side widget
mockup (current vs proposed).

## Problem

The end-of-week report (`Scenes/SchoolSimulation/ResultCheckup.tscn`) is
harder to read than the nightly Daily Results popup it grew out of:

1. The three pills in `WeekRecapBanner` show an icon and a bare number.
   "2/3" and "1" do not say what they count.
2. The money pill wears a placeholder coin (`Assets/Images/UI/Placeholders/icon_uang.svg`),
   not the Lobby's coin (`Assets/Images/UI/uang.png`).
3. The weekly student card reads differently from the daily one, although
   both are the same `DaySummaryStudentRow` scene: green/red delta chips
   beside a separate `/43`, yellow/pink needs bars with dark arrows and
   `+8` week numbers, and a staged rewind-and-replay entrance.

## Design

### 1. The three pills

- **Coin.** `WeekRecapBanner.tscn`'s `icon_uang` export points at
  `res://Assets/Images/UI/uang.png`, the Lobby's coin. The placeholder SVG
  stays: RunResult still uses it (`tests/test_run_result.gd`).
- **Caption.** `WeekRecapPill` gains a `Caption` Label under `Value`, in
  the display face (Boohong), navy ink. The banner supplies the text:

  | Pill | Caption |
  |---|---|
  | PillUang | UANG DIDAPAT |
  | PillMenang | MINIGAME MENANG |
  | PillEvent | EVENT TERJADI |

  `set_pill(icon, value_text, tint)` becomes
  `set_pill(icon, value_text, caption_text)`; the per-pill tint goes (all
  three already pass the same ink). Caption strings live in a `const` in
  `WeekRecapBanner.gd` beside the existing per-pill info copy.
- **Navy outline on the number.** The value reads white with a navy rim.
  Colour source: the existing token `event_warning_ink` (#1D196E), the
  project's one navy outline colour. Styling goes through ThemeFactory,
  never a `theme_override_*`:
  - `RecapPillValueLabel` changes to white `font_color`, navy
    `font_outline_color`, keeping `outline_size`.
  - New variation `RecapPillCaptionLabel`: `font_display`,
    `font_caption` (22 px; 28 px wrapped MINIGAME MENANG onto two lines in the live check, so the owner chose the smaller size), navy `font_color`, no outline.
  - Rebake `kejartes_theme.tres`; add `RecapPillCaptionLabel` to
    `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`.
  - ThemeFactory reads `tokens.event_warning_ink` directly for both
    variations; no second token holding the same hex.
- **Kept as-is.** Pill panel art, icon size, count-up, ring pulse, coin
  shower, tap-for-info popup, idle bounce.

### 2. The student cards

The weekly card becomes the daily card showing a week's numbers.

- **Look.** `ResultCheckup` dresses each card through the same look as
  `setup_row`: plain `+12/43` readout with the gain chevron (no delta
  chip), the daily needs-bar variations (purple energy, orange mood,
  white icons), and no energy/mood delta numbers or arrows.
  Implementation: `setup_week_row` keeps computing week deltas (now minus
  Monday's snapshot, unchanged) but applies the daily look
  (`_apply_look(false)`) and hides the needs delta label/chevron exactly
  as `setup_row` does.
- **Motion.** `ResultCheckup._play_entrance_animations` stage 4 uses the
  daily cadence: `Juice.stagger_in(cards)` and `cards[i].play_gain(i *
  stagger_step)` — the same call `DaySummaryPopup` makes. The week-only
  `play_week_gain` / `rewind_week` / `play_needs_week` / `land_week` and
  their state go if nothing else calls them. Stages 1–3 (banner) and 5
  (celebration, buttons) are unchanged.
- **Retiring the week-only look.** With no weekly caller left,
  `DaySummaryStatRow`'s chip mode (`set_chip_mode`, `shows_chip`,
  `chip_variation`, `chip_text`, `target_text`, the chip nodes) and the
  weekly entries of `DaySummaryStudentRow.NEEDS_VARIATION` are dead. The
  plan greps every one and deletes what is truly unused, including their
  ThemeFactory variations and scene nodes; anything still referenced
  stays. `_energy_delta` / `_mood_delta` and `format_needs_delta` go only
  if their sole readers were the weekly path.
- **Daily path untouched.** `setup_row`, `play_gain` and
  `DaySummaryPopup` do not change behaviour.

### 3. Testing

- Update `tests/test_result_checkup.gd`, `tests/test_day_summary.gd` and
  `tests/test_card_standing_mode.gd` where they pin the weekly chip,
  weekly needs colours or the staged entrance, so they pin the daily look
  on the weekly card instead.
- New assertions: banner `icon_uang` is `uang.png`; each pill has a
  `Caption` with the three strings above; `RecapPillValueLabel` outline
  colour equals the navy; `RecapPillCaptionLabel` uses `font_display`.
- Full `test_run` in a worktree editor; live check through Debug >
  Scenes > Laporan Mingguan, screenshot judged at full size.

## Out of scope

- Captions or outline changes on the student cards' own numbers.
- The Daily Results popup.
- WeekLogsPopup, the title ribbon, buttons and background.
