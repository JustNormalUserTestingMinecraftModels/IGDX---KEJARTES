# Weekly Results polish — masthead, kartu-pelajar cards, popup & logs

Date: 2026-09-16
Screen: `Scenes/SchoolSimulation/ResultCheckup.tscn` and its parts.
Builds on: `2026-09-16-weekly-results-hybrid-design.md` (the Logs-sheet
layout) — this pass does not change navigation or data, only the visual
treatment of four surfaces the mentor flagged as unfinished.

## Why

Mentor review of Weekly Results, five notes:

1. The per-student card still uses the "forbidden green card of doom"
   (`Assets/Images/DaySummary/card_bg.png`).
2. The top of the screen is placeholder: `WeekRecapBanner` pills load
   `Assets/Images/UI/Placeholders/icon_*.svg`, and a *second* header
   ("EVALUASI MINGGUAN SISWA" + subtitle) stacks under the banner —
   redundant and crowded.
3. That top lacks life and is not mobile-friendly — jumbled.
4. The pill tap explainer (`WeekRecapPillInfoPopup`) is underdesigned.
5. The Logs rows are too small to read on a phone.

## Constraints carried in

- **Consistency over novelty.** The redesign extends the app's existing
  polished vocabulary — the inventory `ApplyItemScreen` and the `Result*`
  panel family (`ResultCardPanel`, `ResultStatPanel`, `ResultBadgePanel`,
  `ResultDeltaLabel`), the shared `Card` / `Scrim` popup skeleton, and the
  `StatBar*` bar variations — rather than inventing a one-off brown look.
  Any new surface treatment is added **once** as a `ThemeFactory`
  variation and reused, never as a `theme_override_*` (CLAUDE.md visual
  rule 1) and never built at runtime (rule 2).
- **The student card is shared.** `DaySummaryStudentRow` renders in both
  the nightly Daily Results popup (`setup_row`, daily deltas) and Weekly
  Results (`setup_week_row`, week-wide deltas). The new layout must read
  correctly for both; both screens get the redesign (user-approved).
- **Art is generated in-project** as project-style SVG/textures at real
  asset paths, drop-replaceable at the same path (CLAUDE.md asset rule).
- **Tall phones.** Every surface re-anchors and fills 1080×2400
  (`test_tall_screen_layout.gd`); the masthead's vertical economy is a
  feature, not incidental.

## Design

### 1. Report masthead (replaces the banner + duplicate header)

One brown header band absorbs the redundant title. Top-to-bottom:

- **Band** (`RecapMastheadPanel`, a new variation derived from the
  brand-primary panel): a school crest icon (generated SVG), the run line
  "Minggu N · <grade name>", and the **run-wide stars** figure
  (`run_stars()` of 3.0) right-aligned as the pass metric the player is
  actually chasing. The old `TitleLabel`/`SubtitleLabel` VBox in
  `ResultCheckup.tscn` is deleted — its words live in the band now.
- **Chip strip** (under the band): the four weekly totals — uang, poin,
  menang, event — as `WeekRecapPill`s, re-skinned from a thin
  placeholder row into a compact chip strip on a `Card` ground, each with
  a **generated real icon** (retiring the `Placeholders/` SVGs).

Stars: `WeekRecap.compute()` gains a `stars` field (or the banner reads
`GameState`/`RunGrade.run_stars()` directly — decided at plan time by
which is cheapest and side-effect-free). It is display-only here; the
end-of-grade screens remain the authority on pass/fail.

Living vibe (CLAUDE.md animation APIs, `Juice`/`AnimUtils` only): crest a
small idle wobble; chips keep the existing cascade count-up entrance; the
stars figure counts up once on entrance. No new looping alarm cues.

### 2. Kartu-pelajar student card (`DaySummaryStudentRow`)

Retire `card_bg.png`. New layout on a cream `ResultCardPanel` frame with a
brown header rule (a new `IdCardPanel` variation extending
`ResultCardPanel`, or an added top-rule stylebox — plan-time call), laid
out left-to-right like an Indonesian student ID:

- **Left:** framed portrait (photo frame, generated) + a small NIS-style
  tag chip (`ResultBadgePanel`).
- **Right:** name (`DaySummaryName`), the two personality/quirk badges
  (existing chips), then the **three skill bars** reusing the inventory
  `StatBar*` variations with category-colored icons and `ResultDeltaLabel`
  deltas ("+15/43"), then the **two needs** (energy/mood) as thin
  sub-bars with their existing icons + delta chevrons.

The card keeps its current `@onready` node contract and both
`setup_row` / `setup_week_row` entry points; this is a re-layout and
re-skin of existing nodes, not a new data path. The three-row gain rhythm
(`GAIN_STEP`, `play_week_gain`) is preserved.

### 3. Pill explainer popup (`WeekRecapPillInfoPopup`)

Stays on the shared `Card` + `Scrim` popup skeleton (consistency), gaining
the same ID-card header treatment as a **reusable** variation, not a
bespoke panel:

- Header row: icon in a rounded tile + pill title + `SecondaryButton`
  close (as today).
- Body: the pill's own number **restated large** and centered, a one-line
  caption, then the existing explanatory sentence under a hairline rule.
- Entrance: `AnimUtils.popup_spring_in`, matching other popups.

### 4. Logs sheet rows (`WeekHistoryRow` in `WeekLogsPopup`)

Readability pass, same `Card`/`Scrim` sheet:

- Row height and type up to comfortable mobile sizes (title ~14–15px on
  `font_body`, meta ~11–12px), a 40px category icon tile per row.
- Win / loss / event coded by **color + tag** (green check / danger /
  purple EVENT), so the week scans at a glance.
- The stamp/shake/event entrance (`_play_rows_entrance`) is unchanged.

## New assets (generated, project-style SVG, real paths)

- Masthead crest icon.
- Four real pill icons replacing `Assets/Images/UI/Placeholders/icon_*` —
  land at a non-`Placeholders/` path and rewire the `@export`s.
- Portrait photo-frame and NIS tag ground (or express via new stylebox).
- Skill-category and needs icons only if the existing `StudentCard`/
  `DaySummary` icons don't already cover them (reuse first).

Every generated SVG stays drop-replaceable at its path.

## ThemeFactory additions (rebake after)

Anticipated new variations (final set decided at plan time, each added
once and reused): `RecapMastheadPanel`, an ID-card frame/header treatment
for the card and popup, and any chip-strip pill ground not already
covered. Rebake `kejartes_theme.tres` via `Scripts/Design/BakeTheme.gd`;
update `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` if any new
variation takes a display vs body font.

## Testing

- Extend `tests/test_result_checkup.gd` (and the banner/card/logs suites)
  with source-text scans asserting: no `card_bg.png` reference remains; the
  duplicate title node is gone; the masthead carries the stars label; the
  new icon paths (not `Placeholders/`) are wired; popup and logs use `Card`
  variations, not overrides.
- `test_theme_factory.gd` covers the new variations + roster.
- `test_tall_screen_layout.gd`, `test_script_documentation.gd`,
  `test_viewport_editability.gd` must stay green (re-anchoring, `##` docs,
  no runtime visual construction).
- `test_bar_contrast.gd` / `test_ghost_track.gd` if bar tiles change.

## Out of scope

Navigation, week/grade/stat simulation, the Logs data contract, and the
end-of-grade pass/fail screens. Minigames and the debug overlay remain
outside the design system.

## Open questions for plan time

- `stars` on `WeekRecap.compute()` vs a direct `run_stars()` read — pick
  the side-effect-free path.
- ID-card header as a distinct `IdCardPanel` variation vs a top-rule
  stylebox on `ResultCardPanel` — pick the one that reuses the most.
