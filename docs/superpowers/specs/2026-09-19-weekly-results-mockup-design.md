# Weekly Results: the mockup pass

**Date:** 2026-09-19
**Screen:** `ResultCheckup` (the end-of-week report), plus every scene that draws
a result star.
**Branch:** `feat/weekly-results-redesign`, from `origin/Textures` (d0cd987).
**Source:** `~/Downloads/mockup_weeklyresults.png`, and the new art
`events.png`, `soccerball.png`, `star.png` from the same folder.

## What the player gets

The weekly report gets the mockup's look. The red **WEEKLY RESULTS** ribbon
tops the screen. Under it a yellow panel holds three white tiles, left to
right: money earned, minigames won (`2/3`), events. Each tile has a big icon
with its number underneath. The **Poin** total is gone. **Logs** turns a
lighter red than the ribbon, so it stops reading as a second Selanjutnya.
Every result star (minigame result card, StatCheck's star meter, the event
student card) uses the new glossy `star.png`.

Loop position is unchanged: SchoolDay → **ResultCheckup** → Lobby. The student
cards are already the mockup's cards and are not touched.

## Current vs. new

```
CURRENT                                  NEW (mockup)
┌───────────────────────────────┐        ┌───────────────────────────────┐
│ [1.500][NETRAL][2/3][1]  pills│        │      ◢ WEEKLY RESULTS ◣       │  ribbon
│ number drawn OVER the icon    │        ├───────────────────────────────┤
├───────────────────────────────┤        │ ┌─────┐  ┌─────┐  ┌─────┐     │  yellow panel
│  EVALUASI MINGGUAN SISWA      │        │ │coins│  │ ball│  │notes│     │  white tiles
│  subtitle                     │        │ │1.500│  │ 2/3 │  │  4  │     │  icon above number
├───────────────────────────────┤        │ └─────┘  └─────┘  └─────┘     │
│  student cards (unchanged)    │        ├───────────────────────────────┤
│  [LOGS brown] [SELANJUTNYA]   │        │  student cards (unchanged)    │
└───────────────────────────────┘        │  [LOGS light red][SELANJUTNYA]│
                                         └───────────────────────────────┘
```

## Logic

- `WeekRecap.compute()` is unchanged and still returns `net_skill_delta`. The
  banner just stops displaying it. Nothing else reads the key for this screen.
- The banner shows three tiles in a fixed order, `PILL_ORDER = ["uang",
  "menang", "event"]`. The idle bounce, the tap-to-explain popup, the slide-in
  cascade and the count-up all iterate that order, so they all drop to three.
- The coin shower still fires only when `money_earned > 0`.
- Every tile's value is `text_primary`. The old gold tint on money would be
  unreadable on a white tile, and the mockup shows all three in the same ink.
  The old sign-coloured tint went with Poin.
- The value strings are unchanged: `WeekRecap.format_money()`, `"%d/%d"` for
  minigames, `"%d"` for events.

## Layout

### ResultCheckup.tscn

`Margin/VBox` children, top to bottom:

1. **`TitleRibbon`** (new): a `TextureRect` showing
   `Assets/Images/DaySummary/title_weekly_results.png` (1058×325, already in
   the repo, orphaned since the 2026-09-16 revert). `expand_mode = 1`,
   `stretch_mode = 5` (keep aspect, centred), `custom_minimum_size.y = 250`,
   `mouse_filter = 2`.
2. `Banner` (the `WeekRecapBanner` instance, restyled below).
3. `ScrollContainer/StudentsPane`, unchanged.
4. `ScrollFade`, unchanged.
5. `Buttons`: `LogsButton` takes the new `ResultLogsButton` variation;
   `NextButton` keeps `ResultButton`.

**Removed:** `HeaderPanel` with `TitleLabel` and `SubtitleLabel`, plus the
script's `header_title_text` / `header_subtitle_text` exports and their
`@onready`s. The ribbon replaces them.

### WeekRecapBanner.tscn

- **Removed:** the `Header` row (`WeekLabel`, `GradeLabel`), `PillPoin`, the
  `icon_poin` export and its ext_resource. The mockup shows no week line.
  `icon_poin.svg` itself stays on disk because RunResult and
  MinigameResultPopup still use it.
- The root stays a `PanelContainer` wearing `RecapBannerPanel`, now a yellow
  fill with no border.
- `Pills` becomes a three-tile `HBoxContainer` with `separation = 28`.
- The icons are `icon_uang` = `Assets/Images/UI/Placeholders/icon_uang.svg`
  (unchanged, per the request), `icon_menang` =
  `Assets/Images/ResultCheckup/icon_minigame.png` (from `soccerball.png`),
  and `icon_event` = `Assets/Images/ResultCheckup/icon_event.png` (from
  `events.png`).

### WeekRecapPill.tscn (the tile)

A pill today is a `PanelContainer` whose `Icon` and `Value` overlap. They
become one column:

```
WeekRecapPill (PanelContainer, RecapPillPanel, min 0×250)
└── Column (VBoxContainer, separation 8, alignment centre)
    ├── Icon  (TextureRect, min 0×150, expand 1, stretch 5)
    └── Value (Label, RecapPillValueLabel, centred)
Ring (RewardBurst) stays a direct child of the root.
```

`WeekRecapPill.gd`'s `@onready` paths move to `Column/Icon` and
`Column/Value`.

## Theme (ThemeFactory + DesignTokens)

New tokens in `DesignTokens.gd`, each with a `##` line. New Resource
`@export`s mean a full editor restart before the rebake takes them.

| Token | Value | Used by |
|---|---|---|
| `recap_banner_fill` | `FFE17D` | `RecapBannerPanel` bg |
| `recap_tile_fill` | `F6F4F2` | `RecapPillPanel` bg |
| `result_logs_fill` | `E0574B` | `ResultLogsButton` face |
| `result_logs_dark` | `A8342A` | `ResultLogsButton` bevel |

For reference, the ribbon's own red is `C00000`, so `E0574B` is the same hue,
lighter.

- **`RecapBannerPanel`**: `recap_banner_fill`, `radius_lg`, no border.
  Margins are `space_md` on every side.
- **`RecapPillPanel`**: `recap_tile_fill`, `radius_md` (a rounded square, not
  a capsule), margins `space_sm`.
- **`RecapPillValueLabel`**: display face, `font_h2`, `text_primary`, with a
  `text_outline_color` outline at `text_outline_size`, the mockup's white rim.
- **`ResultLogsButton`** (new): `_add_button_variation(theme, tokens,
  "ResultLogsButton", result_logs_fill, result_logs_dark, outline_card,
  text_on_brand)`, then the same content margins and font size as
  `ResultButton`. Brown stays the one primary-action colour, on Selanjutnya.

Rebake after the token edits. `DISPLAY_ROSTER` in `test_theme_factory.gd`
gains `ResultLogsButton`.

## Student cards: PR #53's cream ID card

Added after the first summary. The user asked for the weekly cards to match
the daily ones, then chose PR #53's (`feat/weekly-results-polish`, open and
unmerged since 2026-09-16) cream ID card over the current green
`card_bg.png`.

Both screens already share `DaySummaryStudentRow.tscn`, so the new look
lands on the weekly report, the daily popup, SchoolDay's embedded cards and
every `StudentCardButton` wrapper at once. What comes across from PR #53:

- The card: a `CardBg` Panel wearing `IdCardPanel` (cream, a brand-brown top
  rule), a 76 px brown `HeaderBand` (`RecapMastheadPanel`) with faint
  `header_stripes.svg`, and the name in the band as `TraitPopupNameLabel`.
  The card grows from 992×410 to 992×486, and everything below the band
  shifts down 76 px.
- `StudentCardButton.card_design_size` changes from 410 to 486.
- The theme variations `IdCardPanel` and `RecapMastheadPanel`. PR #53's
  `RecapChipPanel`, masthead, stars row and popup changes are not taken.
  This pass's ribbon and tiles replace them.

Textures has not touched these files since PR #53's merge-base, so they come
across unchanged. PR #53 is then superseded; closing it is the user's call.

## Stars

The new art lives at `Assets/Images/UI/star.png` (345×357). It is already
gold, so no tint is applied on top.

| Where | Today | After |
|---|---|---|
| `Scenes/EndGame/StatCheck.tscn` StarMeter, 3× `TextureProgressBar` | `icon_star.svg` under and progress, `tint_under` grey | `star.png` both. `tint_under` still greys the unearned part |
| `Scenes/SchoolSimulation/EventStudentCard.tscn` star icon | `icon_star.svg` | `star.png` |
| `ResultStar.gd` (minigame result card) defaults | `icon_bintang.svg` / `icon_bintang_kosong.svg` | `star.png` for both. The empty one is darkened by `popup_star_empty_color` |
| `BaseMinigame.popup_star_color` default | `Color(1, 0.85, 0.2)` | `Color.WHITE`, so the art shows its own gold |

No minigame scene overrides `popup_star_*`. That was checked with grep on
d0cd987.

The now-unreferenced `icon_star.svg`, `icon_bintang.svg` and
`icon_bintang_kosong.svg` are deleted, with their `.import` files and their
lines in `DEBT.md`'s placeholder inventory, provided a grep shows nothing else
loads them.

**Not stars for this pass:** `particle_star.png` (the four-point sparkle in
bursts and confetti) and the achievement `three_star_*.png` badges. They are
particles and badge art, not result stars.

## Kelas 7 / 8 / 9

No difference. The screen shows the same three totals at every grade; only the
numbers differ.

## State

No new state. The screen reads `WeekRecap.compute(student_manager)` and the
`StudentData` deltas as before. `approved_students` is not touched.

## Files

- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn`, `WeekRecapBanner.tscn`,
  `WeekRecapPill.tscn`, `Scenes/EndGame/StatCheck.tscn`,
  `Scenes/SchoolSimulation/EventStudentCard.tscn`.
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd`, `WeekRecapBanner.gd`,
  `WeekRecapPill.gd`, `Scripts/Minigames/UI/ResultStar.gd`,
  `Scripts/Minigames/UI/BaseMinigame.gd`, `Scripts/EndGame/StarMeter.gd`
  (doc line only), `Scripts/Design/DesignTokens.gd`, `ThemeFactory.gd`,
  `Assets/Theme/design_tokens.tres` (if it pins values), and the rebaked
  `kejartes_theme.tres`.
- Create: `Assets/Images/ResultCheckup/icon_minigame.png`, `icon_event.png`,
  `Assets/Images/UI/star.png`, with the `.import` files the editor writes.
- Delete: the three star SVGs, if orphaned.
- Tests: `test_result_checkup.gd`, `test_stat_check.gd`,
  `test_minigame_result_popup.gd`, `test_theme_factory.gd`, and any hygiene
  list naming the deleted SVGs.
- Docs: `CHANGELOG.md` entry, `DEBT.md` (the `title_weekly_results.png` orphan
  note is resolved, and the star SVGs leave the inventory).

## Testing

Source and scene scans in the style `test_result_checkup` already uses:

- The banner has exactly `PillUang`, `PillMenang`, `PillEvent`, in that order,
  and no `PillPoin` or `Header`. `PILL_ORDER` has three entries.
- `set_recap` writes `format_money` / `"w/t"` / count into the three tiles.
- Each tile's `Icon` sits above its `Value` inside `Column`.
- `ResultCheckup.tscn` has `TitleRibbon` with `title_weekly_results.png`, and
  no `HeaderPanel`.
- `LogsButton` wears `ResultLogsButton`, and the baked theme has that
  variation with the `result_logs_fill` face.
- StatCheck's three bars and EventStudentCard point at `star.png`. The
  `ResultStar` defaults are `star.png`. The `popup_star_color` default is
  white.
- The existing `tall_screen_layout`, `viewport_editability` and
  `script_documentation` suites stay green.

One visual check at the end: open ResultCheckup through Debug → Scenes →
📊 Laporan Mingguan and compare a full-size screenshot against the mockup.
