# Weekly results: colours under the design rules

**Date:** 2026-09-29
**Screen:** `Scenes/SchoolSimulation/ResultCheckup.tscn` (the end-of-week report, "Laporan Mingguan")
**Scope:** the weekly report only. The nightly day-summary popup, the apply-item rows and the event picker share the student card and stat row scenes; they must look exactly as they do today.

## Goal

Make the weekly report follow the role palette in the style guide
(`docs/superpowers/design/style-guide.md`, "Theme variations"): brown and
cream are the anchors, mint is the one main action, tomato means danger,
sunflower is a highlight and never an action, and colour carries meaning.
A player should read, at a glance, who gained and who lost this week.

## Already done upstream (not in this pass)

PR #131 (2026-09-29) already moved three things this audit found:

- Logs is brown (`result_logs_fill` = `brand_primary_light`), no longer red.
- The summary tiles are card cream (`recap_tile_fill` = `surface_card`).
- The scroll fade is a brown fade, no longer blue-white.

Selanjutnya stays mint.

## Decisions (picked by the owner in the visual companion)

1. **Header: option A, "no accent".** The title is a brown plate and the
   summary panel is cream, so the header carries no loud colour and the eye
   goes to the cards.
2. **Gain and loss: option A, "solid chip".** A gain shows a green chip
   (`+12`), a loss a red chip (`-3`), followed by the run target (`/52`).
3. **Scope: weekly report only** (the nightly popup keeps its look).

## The changes

### 1. Title: a brown plate reading "HASIL MINGGUAN"

Today `Margin/VBox/TitleRibbon` is a `TextureRect` wearing
`Assets/Images/DaySummary/title_weekly_results.png`: a red ribbon with the
English words "WEEKLY RESULTS" baked into the art.

It becomes a static `PanelContainer` named `TitlePlate`, still the first
child of `Margin/VBox`, holding a `Label` named `Title` with the text
`HASIL MINGGUAN`.

- New variation `ResultTitlePanel`: a `LippedBox` face in `brand_primary`
  on a `brand_primary_dark` lip, `radius_button`, `gloss_strength`, the same
  recipe as `KoperasiSignPanel`. Its content margins size the plate around
  the label; the plate is centred and shrinks to its text.
- New variation `ResultTitleLabel`: `font_display`, `text_on_brand`
  (cream), with the display outline rules the other on-brand labels use,
  and a size in the H1 range.
- `title_weekly_results.png` (and its `.import`) is deleted once nothing
  references it. `title_daily_results.png` stays: the nightly popup uses it.

If an artist later supplies a brown "HASIL MINGGUAN" ribbon, it can replace
the plate. That note goes in `docs/superpowers/DEBT.md`.

### 2. Summary panel: cream, with a cream-lip rim

`RecapBannerPanel` changes from `recap_banner_fill` (butter yellow, no
border) to `surface_sunken` with a 2 px `button_cream_lip` border, keeping
`radius_lg` and the `space_md` content margin. The tiles (`RecapPillPanel`,
`surface_card`) and their outlined numbers are unchanged.

The `recap_banner_fill` token is deleted. That is a removed `@export` on a
Resource, so the editor must be restarted before tests (CLAUDE.md).

### 3. Energy and mood: yellow and pink, on the weekly cards only

Everywhere else in the game energy is `cat_energy_on_dark` (yellow,
`F5D423`) and mood is `cat_mood_on_dark` (pink, `E86FA8`): `StatBarEnergy`,
`StatBarMood`, `StatPillEnergy`, `StatPillMood`. The student card instead
uses `day_energy_fill` (purple, which is also Istirahat's colour) and
`day_mood_fill` (orange, which is also Libur's and the warning colour).

- Two new variations, `WeekEnergyBar` and `WeekMoodBar`, built by the same
  loop as `DaySummaryEnergyBar`/`DaySummaryMoodBar` (same track, rim and
  radius), with fills `cat_energy_on_dark` and `cat_mood_on_dark`.
- `DaySummaryStudentRow.setup_week_row()` switches the card's energy and
  mood bars to those variations. It is the only week entry point, and only
  `ResultCheckup` calls it. The other entry points (`setup_row()` for the
  nightly popup, `setup_current_row()` for the apply-item and event
  cards) set the `DaySummary*` variations back explicitly, so a pooled or reused card can never carry the
  week look into another screen.
- The needs word on the bar (`DaySummaryNeedsLabel`, white on a dark
  outline) must stay legible on yellow. A test measures it against the fill,
  following `tests/test_bar_contrast.gd`; if it fails, the week bars get
  their own label variation with dark ink (`text_primary`) and no outline.

### 4. Gain and loss chips, on the weekly cards only

Today each stat row (`DaySummaryStatRow`) shows a gold chevron on a gain,
nothing on a loss, and one white label reading `+12/52` or `-3/40`.

- `DaySummaryStatRow.tscn` gains a static, hidden `DeltaChip`
  (`PanelContainer`) holding a `DeltaChipLabel`, placed just left of
  `Value` on the track's right end.
- New variations:
  - `DeltaChipGain`: fill `state_success`, pill radius.
  - `DeltaChipLoss`: fill `state_danger`, pill radius.
  - `DeltaChipLabel`: white, `font_display`, one step smaller than
    `DaySummaryStat`, thin dark outline.
- New public method `set_chip_mode(on: bool)` on `DaySummaryStatRow`.
  `setup_week_row()` turns it on before writing the rows;
  `setup_row()` and `setup_current_row()` turn it off. `set_standing()`
  and `show_preview()` (the apply-item preview) never show a chip. In chip mode:
  - delta > 0: chip shows `+N` in `DeltaChipGain`; `Value` reads `/target`;
    chevron hidden.
  - delta < 0: chip shows `-N` in `DeltaChipLoss`; `Value` reads `/target`;
    chevron hidden.
  - delta = 0: no chip; `Value` reads as today (`+0/52`).
  - The ASCII hyphen is the minus sign, as today; the display font's
    coverage of U+2212 is not assumed.
- The entrance keeps its rhythm: where `play_count` pops the chevron in,
  chip mode pops the chip in (`Juice.pop_in`), and the gain's star burst
  centres on the chip. A loss gets no burst, as today.
- The text comes from two small static helpers (`chip_text(delta)` and
  `target_text(target)`) next to `format_value`, so the formatting can be
  tested without a scene.

## What does not change

- The nightly `DaySummaryPopup`, `ApplyStudentRow` and `EventStudentCard`:
  purple and orange needs, gold chevrons, `+12/52`. Pinned by the existing
  `test_day_summary` and by a new assertion that `setup_row()` and
  `setup_current_row()` leave the `DaySummary*` variations and chip mode
  off.
- The energy and mood bars' own change readout (`EnergyBar/DeltaLabel`,
  `DeltaChevron`) keeps its look on the weekly report too. Needs rise and
  fall every day by design, and the chip decision covered the three
  skills; chips on the needs would be a follow-up.
- Card layout, mastheads, portraits, bar geometry, the three category
  track colours, the summary tiles' icons and numbers, the buttons and
  their order, the confetti and the entrance timing.

## Rules this has to keep

- No `theme_override_*`; every look is a `ThemeFactory` variation, then a
  rebake (`Scripts/Design/BakeTheme.gd`). Rebake alone, restart, and diff
  the bake before committing (memory: rebake then restart before saving).
- The plate and the chip are static nodes in their `.tscn`; runtime code
  only sets text, visibility and `theme_type_variation`.
- `##` docs on every new `@export`, method and file header
  (`tests/test_script_documentation.gd`).
- New display-font variations join `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd`.
- Tall phones: the plate re-anchors with the column; nothing new is
  absolutely positioned (`tests/test_tall_screen_layout.gd`).

## Testing

- `test_result_checkup`: the ribbon test becomes "the screen opens with the
  HASIL MINGGUAN plate" (node `TitlePlate`, index 0, `Title.text`,
  variation); the recap test asserts `surface_sunken`, the 2 px
  `button_cream_lip` rim, cream tiles; `setup_week_row` sets `WeekEnergyBar`
  and `WeekMoodBar` and turns chip mode on.
- `test_day_summary`: `setup_row()` keeps `DaySummaryEnergyBar`,
  `DaySummaryMoodBar` and chip mode off, including on a card that ran
  `setup_week_row` first.
- New stat-row tests: `chip_text(12) == "+12"`, `chip_text(-3) == "-3"`,
  `target_text(52) == "/52"`; in chip mode a gain shows `DeltaChipGain`, a
  loss `DeltaChipLoss`, zero shows no chip; the chevron is hidden in chip
  mode.
- `test_bar_contrast`: the week fills against the track, and the needs word
  against the yellow and pink fills.
- `test_theme_factory`: the new variations exist and `DISPLAY_ROSTER` lists
  the display-font ones.
- Live check: Debug > Scenes > Laporan Mingguan, screenshot at full size,
  and confirm the nightly popup unchanged with one day of SchoolDay.
- Full suite before shipping (`ship-pr`).
