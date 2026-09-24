# SchoolDay liveliness & legibility pass — design

**Date:** 2026-09-24
**Scope:** Full liveliness pass (Plan C) over the SchoolDay simulation screen.
**Screens/files:** `Scenes/SchoolSimulation/SchoolDay.tscn`,
`Scripts/SchoolSimulation/SchoolDay.gd`,
`Scenes/SchoolSimulation/BookClockWidget.tscn` +
`Scripts/SchoolSimulation/BookClockWidget.gd`,
`Scripts/SchoolSimulation/SimulationBackground.gd`, `ThemeFactory.gd`,
`Scenes/SchoolSimulation/EventWarning.tscn` + `Scripts/SchoolSimulation/EventWarning.gd`.

## Problem

The SchoolDay screen — the "meat" of the game — has two reviewer-flagged
faults and one felt fault:

1. **The day counter is unreadable.** `DayNumberLabel` ("Hari 1 dari 5") is a
   `CaptionLabel` — the theme's smallest, most muted variation — floated
   directly on the painted sky with no backing (`SchoolDay.tscn`,
   `DayScreen/DayNumberLabel`).
2. **Text vanishes at dusk.** The sky rotates dark→sunrise→midday→dusk→dark
   (`BookClockWidget.gd`, one full turn), but `StatusLabel` / `DayNumberLabel`
   use theme colors baked for a *light* surface. At the evening pose the dark
   text loses nearly all luminance separation from the warm-dark sky.
3. **The screen feels still and silent.** The only motion is the sky rotation
   and the progress bar. No parallax, no ambient life, no reaction from the
   students whose stats are changing. It reads as a wallpapered loading screen.

## Confirmed decisions (from brainstorming)

- **Progress lives in the day banner.** The white "Senin" banner in
  `BookClockWidget` becomes the day's progress bar — a per-day patterned fill
  sweeps across it (Option A). The separate `DayScreen/ProgressBar` and
  `DayNumberLabel` are removed from the day screen.
- **"Hari 1 / 5" is removed.** The day name carries the day; week context stays
  in the existing "Minggu 1/6" calendar badge.
- **Day name stays readable via inverting knockout.** The name is dark on the
  unfilled side and flips to white exactly where the fill covers it.
- **Escalating day-done FX.** A small stamp/burst on a normal day's "… selesai";
  full `ConfettiFireworks` reserved for the final school day of the week.
- **Night beat between days.** A short *deep-night* dip (dark-blue tint, moon,
  stars, warm-lit school windows — all procedural, no painted asset) plays
  during the existing day-advance moment, rising into the next day's dawn.
- **Event notice becomes a breaking-news ribbon.** The flat olive
  `EventWarning` card is redesigned as a school news announcement (alert ribbon
  + ticker + per-category tint) to fix the mood-killing flat surface.
- **No `theme_override`; no runtime-built chrome.** Every new visual is a
  `ThemeFactory` variation, an authored node, a `PackedScene`, or a `@tool`
  driver — per the project's two standing visual rules.

## Design — six layers

### 1 · Banner-as-progress (legibility, layer 1)

The `DayBanner` in `BookClockWidget.tscn` gains a clipped fill child behind the
day-name label:

- **Track:** the banner's existing white rounded pill.
- **Fill:** a `left→right` fill tinted by the day's category color and carrying
  that weekday's motif (reusing `SimulationBackground.PatternType`:
  GRID/STRIPES/DOTS/ZIGZAG/STARS for Mon–Fri) at low contrast, so each day
  *looks* different as it fills.
- **Driver:** the existing `ProgressBar` node is relocated into the banner as
  this fill. The `Juice.fill_bar(progress_bar, …)` calls in `SchoolDay.gd`
  (`:400`, `:428`) stay byte-for-byte the same — only the node's home and skin
  change — so the fill keeps its two-phase, event-in-the-middle pacing and its
  lockstep with the sky sweep for free.

### 2 · Inverting knockout day name

Two stacked labels on the banner, both centered:

- **Base label:** dark (category-dark ink), full opacity — the unfilled read.
- **Knockout label:** white, wrapped in a `Control` with `clip_contents = true`
  whose width tracks the same 0–100 value driving the fill. As the fill
  advances, more of the white name is revealed, so the name flips dark→white
  exactly at the fill edge and can never drift from the bar.

New `ThemeFactory` variation `DayBannerLabel` already exists (used by
`DayLabel`); we add a knockout sibling variation or reuse it with a white
modulate on the clipped copy. A hairline outline is *not* added (decision: pure
knockout); if device testing shows edge cases on the darkest category fill, a
subtle outline is the fallback and would go on the variation, not as an
override.

### 3 · Status-line treatment (the remaining floating text)

`StatusLabel` ("Melewati hari sekolah…", "… selesai") is the only text left on
the open sky. **Proposed default (open for review):** it becomes light text
with a soft drop-shadow via a new `ThemeFactory` variation, riding a slim
`Scrim` strip that *fades in only for the status beats* and fades out during the
quiet sweep — legible when it matters, sky open when it doesn't. Alternative if
you'd rather it always be present: a persistent slim `Scrim` strip.

`day_number_label` is currently reused for "Minggu selesai!" (`SchoolDay.gd:1325`);
that string reroutes to `StatusLabel` when the counter node is removed.

### 4 · Ambient sky motion (liveliness)

- **Parallax clouds:** 2–3 authored cloud sprites in `BookClockWidget`, drifting
  horizontally at different speeds via a `@tool` driver with documented
  `@export` speed/opacity knobs. Loop off-screen edges. These are *new* sprites
  layered above the rotating sky — the sky's own painted clouds rotate with the
  texture and can't drift (see layer 8's cloud-asset note).
- **Sun / moon body:** a body that rides the sky's existing rotation so it rises
  and sets in sync with the dawn→evening sweep — no independent timer to drift.

### 5 · Weekday particles + student-row reactions

- **Weekday particles:** upgrade `SimulationBackground`'s dead 0.07-alpha motif
  wash into slow ambient motes keyed to the same `PatternType`, so each weekday
  has its own drifting texture. Kept subtle (it is backdrop, not content).
- **Student status → avatar strip (decluttered).** The full-width per-student
  bar cards (`_render_embedded_student_status()`) crowd the screen and don't
  scale to a full roster. During the live day they become a **horizontal
  scrolling avatar strip**: each student is an avatar with an **energy (outer)
  and mood (inner) ring** and a reaction face, scrolling sideways so any roster
  size fits without crowding. Rings pulse and a floating "+N"
  (`AnimUtils.create_floating_text`) pops on a gain. Full per-student numbers
  move to the **daily result popup**, where the detail belongs. The strip is a
  `PackedScene` avatar template in a scroll container (not runtime-built chrome).

### 6 · Day-done burst + night beat + weather tie-in

- **Day-done burst (escalating):** replace `day_name + " selesai! ✓"`
  (`SchoolDay.gd:435` — also removes a lingering emoji flagged in `DEBT.md`)
  with a stamp/burst. Normal day → small puff; final school day of the week →
  `ConfettiFireworks.tscn` (already in the working tree) at full strength.
- **Night beat (deep night + lit windows):** at the day-advance fade
  (`SchoolDay.gd:446`), the sky dips to a *real* night — the rotation carries
  past dusk while a night layer fades in: a dark-blue tint, a moon sprite, a
  star field, and warm window-glow sprites on the school building. It holds for
  a short, `@export`-tunable interval, then lifts into the next day's dawn as
  the new day renders. Fully procedural — composed from layered sprites over the
  existing sky, **no hand-painted night texture required.** Duration tuned short
  so it never stalls fast-clicking players.
- **Weather tie-in:** when the Hujan event is active, rain streaks fall on the
  day screen (a lightweight particle/overlay layer), so the sky reacts to the
  event instead of only the event screen showing rain.

### 7 · Event notice — breaking-news ribbon

The `EventWarning` screen is today a flat `EventWarningPanel` fill with the
megaphone centered on it — the same olive rectangle for every event, which
reads as dead air. Redesign it as a **school breaking-news announcement**:

- **Single caution band (animated entrance):** one bold "caution-tape" band
  rolls in and carries the event title + category — the police-line/alert read
  without the busier two-tape news frame (audited down from it, 2026-09-24). The
  band's yellow/black stripes scroll continuously.
- **Gradient background:** the flat fill becomes a diagonal gradient (authored
  `GradientTexture2D`), per-category tinted, for depth instead of dead color.
- **Megaphone pop:** the anchor megaphone pops in above the band with a
  `squash_bounce` and a small shake as the notice lands (`AnimUtils` / `Juice`).
- **Title reveal:** the event/minigame name on the band can type in via a
  `visible_characters` reveal (the technique `EventDialogue` already uses).
- **Category color language:** the tape accent and gradient key off the event's
  real `category` from `EventDialogueCatalog`, using the existing
  `DesignTokens.category_color()` palette (its `_on_dark` variants, since the
  event ground is dark) — **Akademis → blue (`#1F6FBA`/`#3BA7F5`), Olahraga →
  red (`#E03A18`/`#FF5A36`), Seni Budaya → green (`#3D7F12`/`#6BD425`)**. The
  categoryless events stay neutral: **Cuaca (hujan) → storm grey, Sosial
  (nasi_kotak) → warm amber** (they are not skill categories, so they must not
  borrow a skill color — purple/teal belong to Istirahat/Wirausaha). The color
  teaches the player what kind of event it is at a glance. A **mode marker** reads MINIGAME / KABAR for tap events and **PILIHAN**
  for the choice events (les_akademis, latihan_olahraga, workshop_seni), warning
  that a Tolak/Terima decision is coming before the picker appears. This maps to
  data the catalog already carries (`category`, `mode`), so it is honest, not
  decorative.

Built as authored nodes + a new/updated `ThemeFactory` variation for the panel,
a `GradientTexture2D` per category, and `@tool` drivers for the tape roll-in and
stripe scroll (documented speed `@export`s). Motion honors the skip/fast-click
path — the roll-in and typewriter are short and interruptible. A deliberate
tonal step up in energy from the current flat card, chosen to fix the "kills
the mood" complaint head-on.

### 8 · Micro-motion (the "cute" layer)

A hierarchy of small motions, all from the existing `Juice.gd` / `AnimUtils.gd`
toolkits, tuned subtle so they read as charm not noise and never add waiting
(they honor the skip/fast-click path). Split into ambient vs. reactive so the
contrast reads as responsiveness:

**Ambient (always, quiet):**
- **Day-name bob** — a gentle idle bob/tilt on the banner name so the hero is
  never dead still.
- **Cloud drift** — see the cloud-asset note below.
- **Breathing fill** — a soft living wobble on the banner progress fill as it
  advances.

**Reactive (only when something happens):**
- **Pip squash-spring** — student avatars `squash_bounce` when their stat ticks.
- **Floating +N** — `AnimUtils.create_floating_text` pops a "+N" on each gain.
- **Day-done stamp** — "selesai" slams in like an ink stamp with a squash
  (replaces the removed `✓` line).
- **Megaphone wiggle** — the event icon shakes as the notice slides in.

**Cloud asset note.** The clouds visible today are *painted into*
`transition_background.png`, the rotating sky texture, so they rotate with the
sky and cannot drift independently. Cloud drift is therefore added as
**separate cloud sprites layered above the rotating sky** — the painted clouds
stay as rotating ambient depth; 2–3 new drifting sprites parallax across on top.
Default production: a small drop-in-replaceable PNG sprite set (honoring the
asset-replacement rules), with a `@tool` drift driver carrying documented
speed/opacity `@export`s. Procedural `_draw()` puffs are the fallback if art is
deferred. This is layer 4's "parallax clouds" made concrete.

## Mobile layout (verify in-engine)

The design is mobile-sound and most of it is enforced by systems the project
already has — but four things must be consciously honored when the new nodes go
into Godot (a desktop-frame prototype cannot prove them):

1. **Safe area.** The header (calendar + day banner) must anchor inside
   `SafeAreaMargin → UI`, not at a hardcoded top offset, so it clears the
   notch/status bar on every device.
2. **Scroll affordance.** The horizontal avatar strip must keep a visible *peek*
   of the next avatar at the right edge (or an edge fade), so players see it
   scrolls. A strip that ends flush reads as "that's everyone."
3. **Tall phones.** The banner-fill, avatar strip, night layer and event chrome
   must re-anchor under `aspect="expand"` and stay pinned by
   `tests/test_tall_screen_layout.gd` at 1080×2400.
4. **Touch targets & motion.** Any tappable element stays ≥ 48dp (~96px at
   1080-wide); avatar rings already clear this. Keep motion amplitudes small and
   honor the skip/fast-tap path so no animation ever makes a quick player wait.

Touch targets, thumb-zone placement (primary actions at the bottom), and the
tap-anywhere dismiss on events/results are already satisfied by the design.

## Non-goals / out of scope

- No changes to simulation math, decay, scheduling, or any `Balance.gd` value.
- No new persistence.
- Minigame internals and the debug overlay stay out of the design system, as
  always.
- Cosmetic layering only over the existing sky-sweep + day-loop machinery.

## Constraints this pass must honor

- `ThemeFactory` variations only — never a `theme_override_*` (layout-only
  constant overrides excepted).
- Static chrome authored in the `.tscn`; repeated content as `PackedScene`;
  responsive geometry as documented `@tool` `@export` knobs. `##` doc headers
  and per-`@export` `##` lines are required (`test_script_documentation`).
- Every new/changed script gets test coverage in the established source-scan or
  behavioral pattern under `tests/test_*.gd`; the existing SchoolDay/BookClock
  suites must stay green.
- The sky rotation's tuned angles (`dawn_rotation_degrees`,
  `evening_rotation_degrees`) and the `sky_cover_margin` floor are load-bearing
  — the night beat extends the rotation, it does not retune those.

## Rollout

Recommend a dedicated branch/worktree (`feat/schoolday-liveliness`) off
`Textures`, kept separate from the in-flight `feat/weekly-results-polish` and
`feat/achievements-polish-plan` work. Ship via the `ship-pr` skill.
