# ResultCheckup Week Recap — Design

**Date:** 2026-09-03
**Screen:** `Scenes/SchoolSimulation/ResultCheckup.tscn` / `Scripts/SchoolSimulation/ResultCheckup.gd`
**Status:** approved in brainstorming, not yet planned

## 1. Why

`ResultCheckup` is the payoff screen for a whole in-game week — five
simulated days of scheduling collapse into it — and it currently reads
as a flat list. Four problems, all verified against the files:

1. **Dead exports.** `_apply_visual_exports()` looks up
   `Margin/VBox/ScrollContainer/MainContent/StudentsSectionHeader/Label`
   and `.../HistorySectionHeader/Label`. Neither node exists in the
   scene. `students_section_header_text` and
   `history_section_header_text` have never rendered; the scene shows
   hardcoded text instead.
2. **Banned emoji as iconography.** The scene's two headers read
   `"📊 Rapor Status Siswa"` and `"📝 Catatan Kegiatan (Minigame)"`, and
   `_create_history_item()` prints `"📢 Event: %s"`. The project banned
   emoji as UI iconography during the 2026-09-02 pass and ships real
   transparent SVGs for exactly these meanings.
3. **No week-level information.** The screen never states the week
   number, the grade, the money earned, how many minigames were won, or
   how many events fired — although `GameState.pending_earnings`,
   `GameState.current_grade`, and `StudentManager.minigame_history` all
   hold it. The player leaves without a summary of the week they just
   played.
4. **Mobile layout drift.** `StudentsContainer` separation is 56 px
   between 992×410 art cards. Four students is ~1 800 px of continuous
   scroll with no fixed landmark, on a 1 920 px-tall portrait screen.
   The history rows below them are built at runtime with a hardcoded
   180 px day column that wraps badly at 1 080 wide, and use
   `TitleLabel` for both the day tag and the description — so the day,
   the game name, and the outcome all carry the same typographic weight.

Additionally, `_create_history_item()` is live runtime visual
construction — the debt `tests/test_viewport_editability.gd` ratchets
against. Replacing it with an authored template lowers `BASELINE` rather
than adding to it.

## 2. Goal

Restructure the screen so the week reads at a glance and rewards a
second look: a pinned summary banner over two tabbed panes, richer
history rows that say who an event happened to and what it did, and a
staged entrance whose particles and audio are gated on the week
actually having gone well.

## 3. Layout

```
┌────────────────────────────── 1080 ─────────────────────────────┐
│  blurred-classroom backdrop (existing blur_background.png)      │
│  ┌ 36px margin ────────────────────────────────────────────┐   │
│  │  WeekRecapBanner            (authored, fixed ~340 px)    │   │
│  │  ┌──────────────────────────────────────────────────┐   │   │
│  │  │  MINGGU 3          Kelas 7 · Evaluasi Mingguan   │   │   │
│  │  │  ┌ pill ─┐ ┌ pill ─┐ ┌ pill ─┐ ┌ pill ─┐         │   │   │
│  │  │  │[uang] │ │[poin] │ │[menang│ │[event]│         │   │   │
│  │  │  │ 4.200 │ │  +37  │ │  3/5  │ │   2   │         │   │   │
│  │  │  └───────┘ └───────┘ └───────┘ └───────┘         │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  │  ┌ TabBar (2 × Button, 88 px) ──────────────────────┐   │   │
│  │  │  ▐ SISWA (4) ▌   RIWAYAT (7)                     │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  │  ┌ ScrollContainer (size_flags_vertical = FILL) ────┐   │   │
│  │  │  PaneStack                                        │   │   │
│  │  │   ├ StudentsPane — 4 × DaySummaryStudentRow,      │   │   │
│  │  │   │                sep 28, centred in 1008        │   │   │
│  │  │   └ HistoryPane  — N × WeekHistoryRow, sep 16     │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  │  ScrollFade (bottom edge affordance, 96 px)              │   │
│  │  BtnClose  PrimaryButton, 96 px, full width              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

Decisions this locks in:

- **The banner and the tab bar never scroll.** They sit outside the
  `ScrollContainer`, so the week's four totals stay on screen while the
  player reads cards.
- **Both `HSeparator`s are deleted.** The pane boundary and the banner's
  own edge do that work now.
- **Both emoji headers are deleted**, not repaired. The tab labels carry
  the section names, so `students_section_header_text`,
  `history_section_header_text`, `students_header_icon_texture` and
  `history_header_icon_texture` are removed from `ResultCheckup.gd`
  along with the dead lookups in `_apply_visual_exports()`.
- **Card separation drops 56 → 28** and `StudentsPane` centres its
  992-wide cards in the 1 008-wide column.
- **`DaySummaryStudentRow.tscn` is not modified.** Reuse is the point:
  the weekly card must stay visually identical to the nightly one, one
  week wide instead of one day. All five gauges (three
  `DaySummaryStatRow` tracks at the 97 px pitch, two
  `DaySummaryNeedsBar`s with icon and Indonesian tier word) and
  `play_week_gain()` are unchanged.

### 3.1 Tab behaviour

- Both panes are built once during `initialize_checkup()` and switched
  with `visible`. Neither is ever freed or rebuilt.
- **`SISWA` is the default tab.** The entrance choreography lives there;
  opening on `RIWAYAT` would waste it.
- **Each pane keeps its own scroll offset** — two ints on the script,
  written on tab-out and restored on tab-in, so returning to `SISWA`
  lands on the card you were reading rather than at the top.
- **`HistoryPane` animates lazily, once.** Its rows stagger in the first
  time `RIWAYAT` is opened; every later switch is an instant show, so
  tabbing back and forth never re-fires audio. A `bool` latch.
- **Tab labels carry live counts**: `SISWA (n)` from the roster size,
  `RIWAYAT (n)` from `minigame_history.size()`, so the player can see
  there is something worth tapping before tapping.
- Tapping a tab plays `select`. Tapping the already-active tab is a
  no-op and plays nothing.
- `BtnClose` sits outside the panes and keeps its existing gate —
  transparent and `disabled` until the entrance completes — so it is
  unaffected by the active tab.

With the banner (~340), tab bar (88), close button (96) and margins
pinned, the pane has roughly **1 240 px** of visible height. Three cards
fit; the fourth needs a scroll. A soft bottom fade (`ScrollFade`, a
texture or themed panel, never a runtime-built gradient) is the
affordance, in place of a scrollbar.

## 4. The four pills

A new `Scripts/SchoolSimulation/WeekRecap.gd` — a plain `RefCounted`,
not a node and not an autoload — computes every pill from a
`StudentManager`. `ResultCheckup.gd` reads only this dictionary and
stops touching `GameState` directly.

| Pill | Key | Source | Reads as |
|---|---|---|---|
| Uang | `money_earned` | sum of `GameState.pending_earnings.values()` | `4.200` |
| Poin | `net_skill_delta` | **net** sum of `akademis` + `seni_budaya` + `olahraga` deltas across every day in `daily_stat_log` | `+37` |
| Menang | `minigames_won` / `minigames_total` | `minigame_history` entries where `category != "Event"` | `3/5` |
| Event | `events_count` | `minigame_history` entries where `category == "Event"` | `2` |

**`poin` is net, not positive-only.** A week whose skills fell must read
negative, or the banner would contradict the cards below it — a card
whose tracks went down cannot sit under a total that only ever counts
up. The pill tints from `state_success` above zero, `state_danger`
below, and renders the word `Netral` at exactly zero rather than a bare
`0`.

**Energy and mood are deliberately excluded from `poin`.** Summing a
mood drop into the same integer as an academic gain produces a
meaningless number: −12 mood and +12 akademis would cancel to `0` and
report a flat week that was not flat. Needs movement stays on the cards,
attached to the bar that moved.

The banner's own header line is **not** a pill and is not part of
`WeekRecap`'s arithmetic. It reads
`"MINGGU %d" % GameState.minggu_ke` and
`GameState.get_grade_name()` — note the field is `minggu_ke`, with
`GameState.max_minggu` as its ceiling; there is no `current_week`.

Pill icons are the existing transparent SVGs in
`Assets/Images/UI/Placeholders/`: `icon_uang`, `icon_poin`,
`icon_minigame_menang`, `icon_event`. No emoji, no new art.

### 4.1 Negative needs deltas must read as bad news

`DaySummaryStudentRow.format_needs_delta()` already produces the correct
string for a loss (`-12`), but nothing colours the label — a drain
renders in the same ink as a gain. The delta label is tinted from the
same `state_success` / `state_danger` pair the `poin` pill uses, so a
draining week is visibly red on the card.

This is the one change to a `DaySummary*` script in this pass. It is
made in `DaySummaryStudentRow._show_needs_delta()`, which both
`setup_row` and `setup_week_row` already funnel through, so the nightly
popup gets the same correctness fix.

## 5. History rows

`Scenes/SchoolSimulation/WeekHistoryRow.tscn` +
`Scripts/SchoolSimulation/WeekHistoryRow.gd` replace
`ResultCheckup._create_history_item()` entirely.

```
┌─────────────────────────────────────────────────┐
│ [icon]  Senin · Olahraga                        │
│         Lomba Badminton              ( BERHASIL )│
│         Budi, Doni  ·  +10 olahraga, −3 energi  │
└─────────────────────────────────────────────────┘
```

- **Line 1** (`CaptionLabel`): the day and the category, as one
  breadcrumb. This removes the hardcoded 180 px day column that was
  wrapping at 1 080 wide.
- **Line 2** (`TitleLabel`): the game or event name, with the outcome
  badge right-aligned — the existing `DaySummaryBadge` scene, tinted
  `state_success` / `state_danger` / `brand_primary`, unchanged.
- **Line 3** (`MicroLabel`, the new information): **who it happened to**
  from `affected_students` (events, already recorded by
  `record_event_result`) or the participant names in `results`
  (minigames), then **what it did** from `details`, and the score where
  `max_score` is present. Today all of this is recorded and discarded.
- The leading icon is `icon_minigame_menang`, `icon_minigame_kalah`, or
  `icon_event`.
- Line 3 is hidden (not blanked) when an entry carries neither
  participants nor details, so an old-format entry collapses to a
  two-line row rather than leaving a gap.

The empty state keeps its current copy — "Tidak ada minigame yang
dimainkan minggu ini." — but moves from a runtime-built `Label` into an
authored node using the existing `EmptyStateLabel` variation.

## 6. Entrance choreography

Five stages, each gated. Timings come from `DesignTokens`
(`dur_fast` / `dur_normal` / `stagger_step`); no literal durations.

| # | Beat | Particle | SFX |
|---|---|---|---|
| 1 | Banner slides down, title settles | — | `whoosh` |
| 2 | Four pills count up in sequence, ~140 ms apart | `particle_ring` pulse per pill | `tally` ×4 |
| 3 | Money pill finishes → coin shower, **only if `money_earned > 0`** | `particle_coin` | `coin` |
| 4 | Cards stagger in, five gauges filling per card | `particle_spark` per card, plus `particle_plus` on each gaining track's own burst — both gated on `gained_ground()` | `sparkle`, first gaining card only |
| 5 | Week-wide celebration, **only if any card gained** | `particle_confetti` + `particle_glow` | `reward` |

The gating discipline from the 2026-09-03 Daily Results pass carries
over intact: **a flat or losing week gets stages 1–2 and nothing else.**
No coin, no sparkle, no confetti. The silence is the feedback.
`RewardParticles.plays_sfx` is set `false` on every burst after the
first in a gesture, so four gaining cards do not play `sparkle` four
times.

`RIWAYAT`'s lazy first open stamps each `BERHASIL` row in with a
scale-punch and `stamp`; `GAGAL` rows use `Juice.shake`. Once only, per
the latch in §3.1.

**No new `AudioDirector` ids are needed.** `whoosh`, `tally`, `coin`,
`sparkle`, `reward`, `select` and `stamp` all already exist and are
already documented in `AudioDirector.gd`'s header. This pass adds no
audio placeholders.

## 7. New art

Four placeholder PNGs in `Assets/Images/Particles/`, alongside the
existing `particle_star` / `particle_ring` / `particle_confetti`:

| File | Used by | Shape |
|---|---|---|
| `particle_coin.png` | stage 3 coin shower | flat disc with an inner ring |
| `particle_spark.png` | stage 4 per-card burst | four-point glint |
| `particle_plus.png` | the `+` riding a gaining track's burst | thick plus |
| `particle_glow.png` | stage 5, behind the confetti | soft radial falloff |

All are white/greyscale with alpha, so emitters tint them from
`DesignTokens` rather than baking a colour into the asset. They are
explicitly placeholders, in the same sense as the three that shipped on
2026-09-03.

## 8. New theme variations

Per the project's no-`theme_override_*` rule, four variations are added
to `Scripts/Design/ThemeFactory.gd` and the theme is rebaked:

- `RecapBannerPanel` — the banner's own surface.
- `RecapPillPanel` — a pill's `radius_pill` capsule on `surface_sunken`.
- `RecapPillValueLabel` — the pill's number, `font_h2`.
- `WeekTabButton` — the tab, with a real `pressed` state so the active
  tab is legible without a manual tint.

Rebaking has no headless path: a new `@export` on a Resource is
invisible to a running editor. Use the transient `@tool` `McpTestSuite`
technique in `res://tests/` documented in CLAUDE.md — a single test that
does `ThemeFactory.build()` + `ResourceSaver.save()`, run via
`test_run`, then deleted.

## 9. Testing

- **`tests/test_week_recap.gd` (new).** `WeekRecap` is pure `RefCounted`
  arithmetic, so it tests without a scene. Cases: a normal mixed week; a
  net-negative week; zero earnings; an all-event history; an empty
  history; and that energy/mood deltas never leak into
  `net_skill_delta`.
- **`tests/test_result_checkup.gd` (extended).** Node existence for the
  banner, tab bar and both panes; the tab default and the scroll-offset
  restore; the pane latch; and source-scan guards that no
  `theme_override_*` and no emoji re-enter either file.
- **`tests/test_viewport_editability.gd`.** `ResultCheckup.gd`'s
  `BASELINE` entry is **lowered**, since `_create_history_item()` and
  the runtime empty-state `Label` both become authored scenes. The
  ratchet is one-way: lower it, never raise it.
- Every suite is `@tool` and no test is a coroutine — the runner does
  not await.

## 10. Out of scope

- `DaySummaryStudentRow.tscn` and `DaySummaryPopup` layout. Only the
  `_show_needs_delta` tint in §4.1 touches that family.
- Balance. `net_skill_delta` reports what the simulation produced; it
  does not change what the simulation produces.
- Persistence. `WeekRecap` is computed on demand from the live
  `StudentManager` and stored nowhere.
