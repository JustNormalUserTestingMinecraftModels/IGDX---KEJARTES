# Daily Results (DaySummaryPopup) Mockup — Design & Measurement

**Mockup:** `dailyresults_mockup.png` (1080×1920)
**Date:** 2026-08-29
**Target:** `Scenes/SchoolSimulation/DaySummaryPopup.tscn`

---

## 1. The mockup maps 1:1 to the game

| | Canvas | Content box | Aspect |
|---|---|---|---|
| Mockup | 1080 × 1920 | x 34..1036, y 42..1696 (1003 × 1655) | 0.606 |
| Game viewport | 1080 × 1920 | — | 0.5625 |

The mockup canvas **is** the project's design resolution
(`project.godot: viewport_width=1080, viewport_height=1920`). Every
measurement below is therefore a game pixel too — **no rescale factor
anywhere in this document.** This is unusual for this project and is the
single biggest simplification available; do not reintroduce a scale term.

The card background asset confirms it: `daysummarystudent_background.png`
has a content box of **992 × 410**, and the card in the mockup measures
**992** wide. The art is placed at native size.

### The three cards are the same card

The mockup stacks the card three times. They are **geometrically
identical** — verified by scanline: card 1 at y=505 and card 3 at
y=1437 return the same run widths (avatar 269, bar track 243, pill
height 36), differing only by a 10px x-offset of the whole card.

The **only** difference between them is the size of the "Marcel" label.
Per the user, the **middle card** is canonical: cap height **40px**.

---

## 2. Surface table

All coordinates are mockup/game pixels. Card-relative coordinates use the
card's top-left fill corner as origin — in the mockup that is **(44, 359)**
for card 1, the geometric reference.

Fills are centroid samples. "Border" and "fill" are separate columns; a
blank border cell means *measured to have none*, not *unknown*.

| # | Surface | Parent | Rect (card-rel) | Fill (centroid) | Border | Radius |
|---|---------|--------|-----------------|-----------------|--------|--------|
| 1 | Banner (title art) | popup root | abs 93,42 932×287 | art | — | — |
| 2 | Card body | rows list | 0,0 992×393 | vertical gradient `#F1F3B7` → `#B9BA8C` | — | ~16 |
| 3 | Card drop shadow | card body | 0,393 992×12 | `#232323` | — | ~16 |
| 4 | Avatar frame | card body | 50,52 269×286 | `#5E4EBC` | `#3D3D3D`, 5px | ~22 |
| 5 | Avatar art | avatar frame | fills #4, clipped | student splash | — | inherits |
| 6 | Energy bar track | card body | 336,113 243×68 | vertical gradient `#636363` → `#4E4E4E` | `#2B2B2B`, 5px | ~18 |
| 7 | Energy bar fill | #6 | 341,118 85×58 @36.5% | vertical gradient `#7062C7` → `#695CB9` | `#3D2048`, 3px | pill |
| 8 | Mood bar track | card body | 336,201 243×67 | same as #6 | `#2B2B2B`, 5px | ~18 |
| 9 | Mood bar fill | #8 | 341,206 191×57 @82% | vertical gradient `#DFC361` → `#A69249` | `#3D2048`, 3px | pill |
| 10 | Stat track 1 | card body | ~616,105 →right edge of #14, h 36 | vertical gradient `#3C3C3C` → `#353535` | `#2B2B2B`, 5px | pill |
| 11 | Stat track 2 | card body | ~616,202 (same shape) | same as #10 | `#2B2B2B`, 5px | pill |
| 12 | Stat track 3 | card body | ~616,302 (same shape) | same as #10 | `#2B2B2B`, 5px | pill |
| 12a | Stat track fill (×3) | #10–#12 | fills #10–#12 left-to-right @ current/target | per category: Akademis `#3D8BFF`, Seni Budaya `#7CB342`, Olahraga `#E5484D` | `#3D1E48`, 3px | pill |

Stat-track rows sit at card-rel y **105 / 202 / 302** (pitch ≈ 98), each
**36px** tall — measured on the vertical scanline at x=790, which lands
between the chevron and the number and so crosses only the track.

> **Departure from the mockup (2026-08-30, director-approved).** The mockup
> draws these three tracks with no visible fill, and the first implementation
> honoured that by pinning the bar to full and documenting it as decorative.
> The director has since asked for them to be real gauges: **100% of the bar
> means the student is at the target set for that run.** Row 12a above
> supersedes the "no fill" reading of rows 10–12.

> **Motion (2026-08-30).** The three tracks do not snap to their value. Each
> rewinds to `(current − today's delta) / target` and grows to
> `current / target` over `dur_slow`, so the day's gain is visible as
> movement — the gold chevron pops in on the same beat. Rows within a card
> are offset by `DaySummaryStudentRow.GAIN_STEP` (0.08s); cards within the
> stack by `tokens.stagger_step`, matching their own entrance. The needs
> bars (#6–#9) are deliberately **not** animated: energy and mood mostly
> fall over a day, and replaying that alongside three growing skill tracks
> reads as a contradiction rather than as progress.

### Glyphs, icons and text — not surfaces

| Element | Rect (card-rel) | Colour | Note |
|---|---|---|---|
| Name "Marcel" | 349,48 · cap height **40** | `#FFFFFF` fill, `#25132C` outline ~5px | left-aligned; middle-card size |
| Stat icon (×3) | ~601,83 · box ~95×70 (art aspect kept) | `#FFFFFF` fill, `#3D1E48` outline | **overlaps** the track's left end |
| Gold chevron (×3) | ~683,93 · ~40×58 | `#E4B012` | drawn **on top** of the track, right of the icon; **visible only when that stat gained points that day** (delta > 0). Hidden at +0 and on a loss — the asset is an up arrow and there is no down variant. Absolutely anchored, so hiding it reflows nothing. |
| Number "+12/65" | right-aligned, ends ~966 · height ~38 | `#FFFFFF` fill, `#3D1E48` outline | sits on the card fill, **not** on the track |

**The stat track's right edge equals the number's left edge.** Verified:
row 1 (`+12/65`, wider) track ends at abs x=833; row 3 (`+9/65`,
narrower) track ends at abs x=873. The number is right-aligned and the
track expands to meet it. Build the row as
`[icon overlay] [track: expand] [number: shrink, right-aligned]`.

The track's *left* edge is occluded by the icon in every row and cannot
be measured. It is not needed: the track is the expanding member.

### Notes on edge treatments

- Row 3 in the table is a **shadow**, not a border — it is a hard-edged
  band *below* the card only, `#232323`, present on no other side, and
  it is baked into `daysummarystudent_background.png`. Do not build it
  as a StyleBox border.
- Every fill marked "vertical gradient" is a real gradient in the art.
  `StyleBoxFlat` cannot express one. Where the surface comes from the
  card PNG (#2, #3) this is free. Where it must be drawn (#6–#12), use
  the gradient's **midpoint** as a flat colour — the convention this
  project already set for the Penjadwalan preview tokens
  (`preview_row_fill`, `preview_pill_fill`).
- `#3D2048` — the bar fill's stroke — is already tokenised as
  `preview_row_border`. `#363636` (`preview_pill_fill`) is the midpoint
  of the stat track's `#3C3C3C` → `#353535`. Both tokens are reusable
  verbatim; this mockup and the Penjadwalan mockup share an art language.

---

## 3. Asset inventory

All source files are in `C:\Users\ASUS\Downloads\`.

| Source file | Content box | Destination | Role |
|---|---|---|---|
| `daysummarystudent_background.png` | 992×410 | `Assets/Images/DaySummary/card_bg.png` | card body + shadow (#2, #3) |
| `daily results title.png` | 1058×325 | `Assets/Images/DaySummary/title_daily_results.png` | banner (#1) |
| `addition_icon.png` | 80×108 | `Assets/Images/DaySummary/icon_chevron_up.png` | gold chevron |
| `academy.png` | 126×84 | `Assets/Images/DaySummary/icon_akademis.png` | Akademis stat icon |
| `Gunungan.png` | 128×128 | `Assets/Images/DaySummary/icon_seni.png` | Seni Budaya stat icon |
| `athletic.png` | 126×84 | `Assets/Images/DaySummary/icon_olahraga.png` | Olahraga stat icon |
| `splash_marcel.png` | 706×1853 | `Assets/Images/SplashArtMurid/splash_marcel.png` | avatar art |
| `splash_andi.png` | — | `Assets/Images/SplashArtMurid/splash_andi.png` | avatar art |
| `splash_shinta.png` | — | `Assets/Images/SplashArtMurid/splash_shinta.png` | avatar art |
| `splash_thea.png` | — | `Assets/Images/SplashArtMurid/splash_thea.png` | avatar art |

The three stat icons were verified against the mockup by alpha sample:
`academy.png` at (63,40), (63,55), (63,75) and (40,80) all return
`#FFFFFF A=255` — the interior is **opaque white**, not transparent.
They are the mockup's icons as-drawn, no restyling needed.

The banner is placed at 932/1058 = **0.881 scale** in the mockup
(aspect 3.2474 measured vs 3.2554 native — within 0.2%, so it is a
uniform scale, not a stretch).

### Known gap: two students have no new splash art

The roster is Marcel, Doni, Andi, Citra, Shinta, Thea
(`Scripts/StudentCard/student_card.gd:878-994`). The new art covers
**four**: Marcel, Andi, Shinta, Thea. **Doni and Citra have none.**

The avatar must therefore fall back, in order:
`splash_path` → existing `Assets/Images/SplashArtMurid/SplashMurid{N}.jpg`
→ `portrait` → empty purple frame. Never a broken texture.

---

## 4. Architecture: the popup's rows are currently dead code

`SchoolDay._show_day_summary()` (`Scripts/SchoolSimulation/SchoolDay.gd:658`)
calls `setup_summary(day_name, summary, students, false)` — `build_rows=false` —
then **reparents its own live `DayScreen/StudentScroll`** into the popup's
`RowsContainer`, and reparents it back on dismiss.

Consequence: `DaySummaryStudentRow.tscn` **never renders in the game.**
What the player sees is the programmatic card built by
`_render_embedded_student_status()` (`SchoolDay.gd:384`). Restyling the
row scene alone would change nothing on screen.

**Decision (confirmed with the user): rebuild the row scene and retire
the reparenting hack.** `setup_summary` is called with `build_rows=true`,
the reparent/reparent-back block is deleted, and the popup owns its rows.

Rationale beyond tidiness: the mockup's `+12/65` is **delta / target**.
`delta` lives only in `summary_data[].changes[].delta`, which the popup
already receives and the live `StudentScroll` cards never see. The
mockup is not buildable on the reparented path.

`_render_embedded_student_status()` stays as-is — it still draws the
mid-day DayScreen. Only its trip into the popup goes away.

---

## 5. Data mapping

Per student, per card:

| Card element | Source |
|---|---|
| Name | `StudentData.student_name` |
| Avatar | `StudentData.splash_path` → fallbacks in §3 |
| Energy bar (top, purple) | `StudentData.energy` / 100 |
| Mood bar (bottom, gold) | `StudentData.mood` / 100 |
| Row 1 `+N/T` | Akademis: delta from `changes` where `stat_key=="akademis"`; T = `target_akademis1` |
| Row 2 `+N/T` | Seni: `stat_key=="seni_budaya"`; T = `target_akademis2` |
| Row 3 `+N/T` | Olahraga: `stat_key=="olahraga"`; T = `target_akademis3` |

Note the naming trap this project documents in CLAUDE.md:
`target_akademis2` is the **seni_budaya** target, `target_akademis3` the
**olahraga** target.

**Colour-order conflict, resolved in favour of the mockup.** The existing
`SchoolDay._add_embedded_bar_row()` gives energy the warm gold `Libur`
tint and mood the violet `Istirahat` tint. The mockup is the opposite:
top bar (energy) is **violet**, bottom bar (mood) is **gold**. The
mockup wins for the popup card. The DayScreen embedded cards are not in
scope and keep their current tints, so the two screens will disagree
until someone reconciles them — flagged, not fixed here.

All three stat rows are always shown, even at delta 0, because the
mockup shows a fixed three-row block and a card that changes height per
student would break the stack rhythm.

---

## 6. Out of scope

- The DayScreen mid-day cards (`_render_embedded_student_status`).
- `DaySummaryBadge.tscn` / `DaySummaryPill.tscn` — the mockup has no
  badge or pill row. They stay on disk because `SchoolDay._make_chip()`
  and `_build_pill_badges_for_student()` still use them for DayScreen.
- The weekly results banner (`weekly results title.png`), which is a
  different screen.
- Splash art for Doni and Citra.
