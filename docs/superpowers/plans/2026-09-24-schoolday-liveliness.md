# SchoolDay liveliness — implementation plan

**Spec:** `docs/superpowers/specs/2026-09-24-schoolday-liveliness-design.md`
**Behavioural source of truth:** `docs/superpowers/specs/mockups/schoolday-interactive-prototype.html`
**Branch:** `feat/schoolday-liveliness-impl`, off `feat/schoolday-liveliness` (PR #75, the design handoff).

## Owner decisions (2026-09-24, asked before building)

- **Scope:** mockup sections 1–3 (the day screen, the event notice, the daily
  result's reward layer). The weekly additions (section 4) and the weekly tile
  depth (section 5) belong to PR #53 `feat/weekly-results-polish` and are not
  built here.
- **Weekly tile depth, for whoever builds it on PR #53:** option **A**,
  gradient + drop shadow + highlight.
- **Status line:** the spec default — a slim scrim that fades in only for the
  status beats.
- **Teacher faces, crown, stars:** placeholder SVGs drawn here, drop-in
  replaceable and logged in `DEBT.md`.

## What the code actually looks like (measured 2026-09-24)

- **Hidden during the day:** `_reset_day_ui()` hides `DayScreen/ProgressBar`
  and `StudentScroll` at the start of every day, and nothing re-shows the
  scroll. During a live day the player sees only the sky, the banner and
  `StatusLabel`. The avatar strip is therefore new visible content, not a
  declutter.
- **No safe area:** SchoolDay has no `SafeAreaMargin`, and
  `test_tall_screen_layout` does not cover SchoolDay or EventWarning.
- **Rain leaves no flag:** Hujan exists only inside `_run_event` case 4.
- **Event data:** EventWarning receives only a caption string, no category or
  mode.
- **Event deltas unlogged:** event stat changes are not logged
  (`record_event_result` is called without `stat_deltas`), so the daily
  summary sees only activity, decay and minigame deltas.
- **Sky art:** the foreground is one 1080×1920 painting that fits with
  KEEP_ASPECT_COVERED. The night-window glow is therefore a matching
  full-frame overlay texture that `_fit_layers` sizes like the foreground,
  never nodes at fixed pixels.

## Phases (a commit each; targeted suites after each)

**A · Banner-as-progress, knockout, status scrim, stamp.**
- **Banner fill:** `BookClockWidget/Header/DayBanner` gains a `FillClip`
  (clip_contents) holding a category-tinted fill panel, a per-weekday motif
  tile and a white knockout copy of the day name. The existing
  `DayScreen/ProgressBar` moves into the banner as an invisible driver, so
  `Juice.fill_bar(progress_bar, …)` stays byte-identical; the widget sizes
  `FillClip` from its `value_changed`.
- **Status line:** `DayNumberLabel` is removed. `StatusLabel` rides a
  `StatusStrip` scrim that fades in for status beats, and "Minggu selesai!"
  reroutes to it.
- **Stamp:** "<hari> selesai" slams in as an authored stamp label, replacing
  the `✓` line.

**B · Sky life.**
- **Bodies:** a sun and a moon ride the sky as children of `SkyBackground`, so
  they rotate with it and cannot drift from the sweep.
- **Clouds:** 2–3 drifting cloud sprites run on a `@tool` `CloudDrift` driver
  with documented speed/opacity knobs.
- **Night beat:** at the day-advance fade, a `NightLayer` (blue tint, star
  field, moon, window-glow overlay) holds for an `@export` interval.
- **Rain:** a streak overlay runs on days Hujan fired.

**C · Avatar strip.** `AvatarChip.tscn` shows the portrait inside an energy
(outer) and mood (inner) ring (radial `TextureProgressBar`s) with the name
beneath. The chips sit in a horizontal `ScrollContainer` with a right-edge
peek. It replaces the runtime-built status cards, lowering SchoolDay's
editability count. Rings tween with each decay/event update, chips
`squash_bounce`, and a floating "+N" pops on each gain.

**D · Event notice.**
- **Look:** EventWarning keeps its tree root, panel and megaphone, and gains a
  per-category diagonal gradient, a scrolling caution band carrying
  `<KATEGORI> · <MODE>` over the caption (typewritten), and a megaphone pop
  plus wiggle.
- **API:** `play_warning(caption, category := "", mode := "")`. SchoolDay
  passes category and mode from `EventDialogueCatalog` (minigames by subject;
  nasi_kotak → Sosial, hujan → Cuaca; the three choice events → their subject
  + PILIHAN).

**E · Daily result reward layer.**
- **Contents:** `DaySummaryPopup` gains a verdict header (teacher face, one of
  four, a headline, 1–4 stars), a tally (total naik / target tercapai / uang)
  and "Bintang Hari Ini".
- **Logic:** a pure `DayVerdict.gd` computes these from the summary, the
  students' targets and the day's Wirausaha accrual. Star rule: 4 = two or
  more targets crossed and nobody down, 3 = a target crossed, 2 = a net gain,
  otherwise 1.

**F · Escalation and micro-motion.**
- **Day-done escalation:** a small burst on a normal day, `ConfettiFireworks`
  on the week's last school day.
- **Micro-motion:** a day-name idle bob and a banner-fill wobble.
- **Motion rules:** motion honours `GameSettings.reduce_motion` and the skip
  path.

## Test surface to update

`test_school_day`, `test_book_clock_phases`, `test_sky_transition`,
`test_event_warning`, `test_event_polish`, `test_day_summary`,
`test_viewport_editability` (SchoolDay's count goes down),
`test_audio_coverage`. New suites: `test_day_verdict`, `test_avatar_chip`,
`test_cloud_drift`.
