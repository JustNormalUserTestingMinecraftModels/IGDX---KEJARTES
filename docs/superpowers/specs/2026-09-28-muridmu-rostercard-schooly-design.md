# MURIDMU RosterCard — "Schooly & Alive" polish (design spec)

**Date:** 2026-09-28
**Branch:** (handoff — build on a fresh branch off `Textures`)
**Screen:** `StudentList` ("MURIDMU"), the per-student roster carousel reached
by tapping a student's portrait in AturJadwal.
**Status:** Design approved (Option A, schooly direction). Handoff — not built.

---

## 1. What this screen is, and why it feels blank

`Scenes/StudentList/StudentList.tscn` shows one `RosterCard`
(`Scenes/StudentList/RosterCard.tscn`) at a time, swiped through a carousel,
with a `RosterStrip` of avatars up top and left/right nav + page dots at the
bottom. Each card is one student.

The card today (`RosterCard.tscn`) stacks:

- `Nama` (H2Label) + `Belum`/`Sudah` status stamp (`RosterStatusBelum/Sudah`).
- `PortraitFrame` — `SunkenPanel` backdrop + `Portrait` + two `photo_corner`
  taped corners.
- `TraitRow` (HBox) — `SpecialtyChip` / `PersonaChip` / `QuirkChip`
  (`SpecialtyBadgeM` / `PersonaBadgeM` / `QuirkBadgeM`).
- `StickyNotesContainer` — five `StickyNote` instances (`Senin`…`Jumat`,
  day_name SEN…JUM), each showing that day's scheduled activity (icon +
  `ActivityLabel`), category-tinted; **grey with "-" when the day is not yet
  scheduled**.
- `CatatanGuru` — `catatan_rule` texture + `CatatanLabel`, a teacher's note
  composed from persona + quirk (`RosterCard.compose_catatan`).

**The blank problem, precisely:** an *unscheduled* student (the common first
visit, arriving from AturJadwal) shows all five sticky notes as identical grey
"-" placeholders — a dead grey block filling the card's lower half — and the
whole card is flat: no tape, no life, uniform right angles, no sense of a
week in progress.

## 2. The direction: a school desk, mid-planning

Keep every element and every data binding. Make the lower half read as a
**real weekly planner on paper**: five sticky-notes tacked to the card, a
torn-paper section header, a five-dot "hari terjadwal" tally, and small
schooly touches (a paperclip on the photo, a pencil on the note line). The
empty days stop being dead grey and become **inviting kraft "+ Atur" slots**
that say "plan me". Filled days wear their subject's category colour and icon.

This is a **visual + surface-more-info** pass. It does **not** change the
approve/schedule flow, routing (still opens AturJadwal on card tap), or
`GameState`. The five-dot tally and the filled/empty note states are read
from data the card already receives.

Nothing is built at runtime that can be authored: tape, torn header, the dot
tally template, and the empty/filled note skins are nodes/`PackedScene`s in
the `.tscn`, tinted by `@tool` setters and ThemeFactory variations — never
`theme_override_*` (pinned by `tests/test_student_list.gd` and
`test_stickynote_scene_has_no_theme_overrides`).

## 3. Component-by-component design

### 3.1 Sticky notes — the heart of the change (`StickyNote.tscn` / `.gd`)

Each note gains two authored children and one state flag:

- **Tape strip** — a `TextureRect` (`Tape`) pinned top-centre, a translucent
  washi-tape placeholder texture (`Assets/Images/UI/StudentList/tape.png`,
  drop-replaceable), `self_modulate` alpha ~0.55. Static node, always present.
- **Jaunty angle** — each note's `rotation` set per-slot in `RosterCard.tscn`
  (SEN −2.5°, SEL +1.5°, RAB −1.5°, KAM +2°, JUM −1°). Authored, not random,
  so it's stable across frames and tests. `pivot_offset` = note centre.
- **`scheduled` state** — a new `@export var scheduled: bool` on
  `StickyNote.gd`, driving a **filled vs empty skin**:
  - *Filled:* paper tinted to `DesignTokens.category_color(cat)` at a soft
    wash (existing `self_modulate` path already does category tint — keep it),
    `Icon` = category glyph, `ActivityLabel` = activity name. Dog-ear kept.
  - *Empty:* kraft paper (`surface_sunken` tone), a **dashed border**
    (via a new `StickyNoteEmpty` ThemeFactory variation on a Panel child, or a
    dashed-frame placeholder texture `sticky_empty_frame.png` — see §5), `Icon`
    = a "+" glyph (`Assets/Images/UI/StudentList/icon_add.png`, drop-in),
    `ActivityLabel` = "Atur", both in `text_secondary`/muted tone.

  `StickyNote.gd` already tints `self_modulate` and sets `activity`/`icon_texture`;
  add the `scheduled` setter that swaps the frame child's visibility and the
  muted/vivid label tone. All guarded on `is_node_ready()` (StickyNote's
  established `@tool` pattern).

`StudentList.gd::_setup_students()` already knows `is_day_set`
(`day_schedules_for_student.has(day_name)`); pass that straight into
`sticky_node.scheduled = is_day_set`. No new data source.

### 3.2 Week header band + five-dot tally (in `RosterCard.tscn`)

A new `WeekHeader` `Control` above `StickyNotesContainer`, holding:

- **Torn-paper band** — a `TextureRect` (`Band`) with a torn-edge placeholder
  (`Assets/Images/UI/StudentList/torn_band.png`), `self_modulate`
  `surface_sunken`, slight −1° rotation, behind a `Label` ("JADWAL MINGGU INI",
  `CardSectionLabel` variation — already exists in the project) with a
  `ti-calendar`-equivalent authored glyph `icon_calendar.png` to its left.
- **Dot tally** — a right-aligned `HBox` (`DayTally`) of five `TextureRect`
  dots built from one `TallyDot.tscn` template (repeated-row rule: a
  `PackedScene`, not five inline nodes). Each dot has a `filled: bool`
  `@export`; filled = `state_success`/category tone, empty = ringed
  `surface_sunken`. A `Label` "n/5 hari" precedes it.

  `RosterCard.gd` gains `@export var days_scheduled: int` (0–5), whose setter
  fills the first *n* dots and sets the count label. `StudentList.gd` already
  computes `fully_scheduled` and per-day `is_day_set`; sum the set days and
  assign `murid_node.days_scheduled = count`.

### 3.3 Photo — paperclip + settle

- Add a **paperclip** `TextureRect` (`Clip`) at portrait top-centre,
  overlapping the frame edge (`Assets/Images/UI/StudentList/paperclip.png`,
  drop-in), ~8° rotation.
- Give `PortraitFrame` a gentle authored −1.5° `rotation` (pivot centre) so the
  photo reads as taped down, not pasted flat. Keep the two existing
  `photo_corner` corners.

### 3.4 Catatan — ruled line + pencil

`CatatanGuru` keeps `catatan_rule` + `CatatanLabel`. Add:

- A **pencil** `TextureRect` (`Pencil`) at the note's left gutter
  (`Assets/Images/UI/StudentList/pencil.png`, drop-in).
- A thin **red margin rule** — a 1px `ColorRect` (or a stroke baked into the
  existing `catatan_rule.png` replacement) at the left, `state_danger` tone,
  the classic exercise-book margin. Layout-only; a `ColorRect`'s `color` reads
  a token in `_ready`, or bake it into the rule texture.

The italic/handwritten feel comes from `CatatanLabel`'s existing variation;
if it is not already the display/handwritten face, the executor may add a
`CatatanNoteLabel` variation using `font_display` — **propose, don't force**,
since `CatatanLabel` is pinned nowhere but is shared.

### 3.5 QoL: reopen on the student you were just on

**Bug today:** tapping a card calls `_on_student_selected`, which sets
`GameState.selected_student = student` and routes to AturJadwal
(`StudentList.gd:596`). But `_init_carousel_state()` always starts
`current_card_index = 0`, so returning from AturJadwal (or arriving after
scheduling Marcel) always snaps back to the first student (Murid1) instead of
the one you were working with. Annoying, and it makes the carousel feel
stateless.

**Fix (minimal, reuses the existing field):** in `_init_carousel_state()`
(before the first reveal / `_stagger_card_notes`), if
`GameState.selected_student` is non-empty, find the index in `active_students`
whose `id` matches `selected_student.id` and set `current_card_index` to it
(clamped to range; fall back to 0 if not found). Then paint the roster strip
and page dots from that index as usual.

- `selected_student` already exists, is set on selection, and is cleared by
  `GameState`'s session reset (line ~401) — so this is **session-scoped
  memory, no new field and no disk persistence** (consistent with the project's
  "roster/schedules are session-scoped by design" rule).
- Does **not** change the approve flow or which student AturJadwal schedules —
  only which card the list reopens on.
- If the roster strip avatars are tappable, keep their existing behaviour; this
  only changes the initial index, not navigation.

## 4. Motion — make it arrive alive

`StudentList.gd` already calls `Juice.stagger_in(card_nodes)` and
`Juice.stagger_in(sticky_container.get_children(), stagger_step * 0.5)`
(pinned by `test_motion_is_wired` — **keep both call sites verbatim**). Layer
on top:

- **Sticky-note settle:** as each note staggers in, add a tiny rotate-overshoot
  to its authored angle (e.g. start at 0°, overshoot to angle×1.4, settle) via
  `Juice` or `AnimUtils.squash_bounce`. Reads as notes being slapped down.
- **BELUM stamp thunk:** a one-shot scale-punch + settle when the card lands
  (reuse the StudentCard stamp feel; `AnimUtils`/`Juice`).
- **Empty-slot invite:** a slow, low-amplitude modulate pulse on the empty
  notes' "+" so unplanned days quietly ask to be tapped. Cheap, looped, killed
  when the card leaves.
- **Dot fill:** when `days_scheduled` changes, pop the newly-filled dot
  (`AnimUtils.coin_pulse`-style).

All motion is opt-in juice on existing nodes; none of it constructs a visual.

**The entry beat (the cadence in the approved live mock), on card-arrive:**

| Beat | Node | Motion | Real API |
|---|---|---|---|
| 0.00s | whole card | slide in from carousel side + de-rotate | existing `_switch_card` slide; keep |
| ~0.25s | `Nama` | fade up | `Juice.pop_in` / fade |
| ~0.30s | `Portrait` frame | scale-pop to rest (−1.5°) | `AnimUtils.squash_bounce` |
| ~0.45s | `TraitRow` chips | stagger in from right | `Juice.stagger_in` |
| ~0.7s | `Belum`/`Sudah` stamp | scale-punch "thunk" + settle | `AnimUtils.popup_spring_in` |
| ~0.9–1.5s | five `StickyNote`s | drop + rotate-overshoot to authored angle, one per `stagger_step` | `Juice.stagger_in` (kept) + per-note overshoot |
| ~1.8s | first n `TallyDot`s | pop fill | `AnimUtils.coin_pulse` |
| loop, after entry | empty notes' "+" | slow modulate/scale pulse | looped `Tween`, killed on card-leave |

Keep the two pinned `Juice.stagger_in` call sites; the overshoot and thunk
layer on top of them, they do not replace them.

### 4.1 The swipe between students (`_switch_card`)

Today `_switch_card(new_index, direction)` throws the old card out (0.20s,
`rotation_degrees` 12°×dir, fade), *awaits it fully*, then slides the new card
in (0.20s) — sequential, flat, with a dead beat and no depth. Rework it into a
**stack-of-files** transition:

- **Peek/ghost:** add a static `GhostCard` node behind the carousel
  (`surface_sunken` paper, `translateX +34px, rotate 4°, scale 0.9`, ~0.5
  alpha) so a second file always shows behind the front one — the deck reads as
  a stack, not a single floating card. Authored node, not runtime-built.
- **Overlap, don't await:** run tween-out and tween-in on the **same**
  timeline (drop the `await tween_out.finished` gate). Outgoing: `translateX
  −screen_width×dir`, `rotate −9°×dir`, `scale 0.92`, fade. Incoming: starts at
  `translateX +30px, rotate 4°, scale 0.9, alpha 0` (the peek slot) and springs
  to front (`0, 0°, 1.0, alpha 1`), `TRANS_BACK`/`EASE_OUT`, ~0.4s.
- **Land:** on arrival, re-run `_stagger_card_notes(new_card)` (already called)
  so the incoming week re-drops with the §4 overshoot.
- **Chrome follows:** the `RosterStrip` active-avatar highlight and the
  `PageIndicator` dot animate to the new index *during* the slide, not after
  (`_sync_roster_strip` / `_update_page_indicators` tween the modulate rather
  than hard-setting it).
- **Direction:** left-swipe/Next moves the stack forward, right-swipe/Prev back,
  matching the existing `_next_card`/`_prev_card` mapping — unchanged.

**Finger-follow drag (required — the mobile interaction):** the card must
track the finger, not just fire on release. In `_on_card_gui_input`, while the
pointer is down, move the front card's `position:x` with the drag delta and
tilt it proportionally (`rotation_degrees` scaled by offset, small cap), and
drag the peek `GhostCard` a fraction behind for parallax. On release:
- past `min_swipe_distance` (or a fast flick) in the horizontal-dominant axis
  → complete the throw into `_switch_card` in that direction;
- otherwise → spring the card back to rest (`TRANS_BACK`/`EASE_OUT`), no page
  change.
Keep the existing release-threshold mapping and the `abs(delta.x) >
abs(delta.y) * 1.2` horizontal gate so a vertical scroll/tap is never a swipe;
respect `card_animating` (no drag mid-transition) and the tutorial lock. This
makes the carousel feel native on a phone instead of a button-only pager.

Keep `card_animating` guarding re-entry, and keep routing/tutorial hooks
(`current_step == 2` auto-advance) intact.

### 4.2 Idle affordance loops — teach the player to touch

After the entry beats settle, persistent low-amplitude loops signal what is
interactive. They run **only where there is something to do** and pause during
`card_animating` / while a popup or the tutorial scrim is up.

- **Empty day-notes — outer glow (primary affordance):** each empty kraft note
  pulses a glow around its *outer edge* — a looping soft `currency_gold` bloom
  plus the dashed border brightening toward `currency_gold` and back (~1.9s
  sine). This is the main "these are tappable" cue; the "+" glyph does a subtle
  scale/opacity pulse in sympathy. Filled notes do **not** glow — a scheduled
  week is calm. (Replaces the earlier tap-finger/ripple idea.)
- **Paper breathing:** the whole card paper breathes at rest — a slow
  scale 1↔~1.012 with a lifting drop-shadow (~3.6s sine), so the surface feels
  alive rather than static. Apply it to the *front* card only, on an inner
  paper node so it never fights the swipe transform on the card root; pause it
  during the swipe and while a popup/tutorial is up.
- **Nav arrows:** a ±4px horizontal nudge loop on the left/right arrow glyphs
  when `card_nodes.size() > 1`, hinting the carousel swipes.
- **Roster avatar highlight (`RosterStrip` / `RosterAvatar`):** the current
  student's circle reads unmistakably — inactive avatars sit at ~0.82 scale and
  dimmed; the active one scales to ~1.4, lifts a few px, and wears a
  `currency_gold` glow ring + `brand_primary` border. On selection change it
  **bounces** into that state (overshoot settle, ~0.42s, `AnimUtils`), so the
  eye follows the swipe up to the strip. This replaces the current flat
  `is_current` alpha swap in `_sync_roster_strip`; drive it from there and
  animate rather than hard-set. Keep the strip tap-to-jump behaviour if present.
- Amplitudes/periods live in a named `const` block; every loop is a `Tween`
  stored on the node and `kill()`ed on card-leave / popup-open so nothing
  leaks across swipes. Respect `GameSettings` reduced-motion if such a flag
  exists; otherwise these are gentle enough to keep always-on.

This is the affordance layer the current screen lacks — the reason a first-time
player does not realise the grey slots are tappable.

## 5. Assets (all placeholders, drop-replaceable at the same path)

Under `Assets/Images/UI/StudentList/`:

| File | Use | Notes |
|---|---|---|
| `tape.png` | note + band tape strip | translucent, ~120×40, tiled/stretched |
| `torn_band.png` | week header background | torn top/bottom edge, tintable white |
| `paperclip.png` | photo clip | transparent, ~64×96 |
| `pencil.png` | catatan gutter | transparent, ~40×120 |
| `icon_add.png` | empty-note "+" glyph | matches stat-icon weight |
| `icon_calendar.png` | week header glyph | matches trait-chip icon weight |
| `sticky_empty_frame.png` | dashed empty-note frame (if not a ThemeFactory dashed StyleBox) | 9-slice safe |

`tests/test_student_list.gd::test_part_three_art_exists_and_loads` scans a
declared art list — **add every new path to that list** so its existence is
pinned. All new art must load as `Texture2D`.

Prefer a ThemeFactory `StickyNoteEmpty` variation with a dashed `StyleBoxFlat`
border over `sticky_empty_frame.png` if a dashed stroke is achievable in the
StyleBox; the texture is the fallback. Either way: **no `theme_override_*`.**

## 6. Hard constraints for the executor

- **No `theme_override_*`** on `StudentList.tscn` or `StickyNote.tscn` (both
  scanned). Layout-only constant overrides (`separation`, `margin_*`) are the
  only exception. New colour/border/font work → a ThemeFactory variation +
  rebake (`Scripts/Design/BakeTheme.gd`, Ctrl+Shift+X).
- **Do not rename or retype** pinned nodes/variations: `HeaderLabel`=H1Label,
  `Nama`=H2Label, `Belum`=RosterStatusBelum, `Sudah`=RosterStatusSudah, nav
  arrows=SecondaryButtonL, the five StickyNote instances named `Senin`…`Jumat`
  under `StickyNotesContainer`, all four cards named `Murid1`…`Murid4`.
- **Keep both `Juice.stagger_in` call sites verbatim** (`test_motion_is_wired`).
- **Keep routing** to `res://Scenes/AturJadwal/AturJadwal.tscn`
  (`test_still_routes_to_atur_jadwal`).
- Interactive controls stay ≥ `tokens.touch_target_min`
  (`test_interactive_controls_meet_the_minimum_touch_target`).
- No `Color(...)` literals in scripts (`test_no_hardcoded_colors_remain`); pull
  every tone from `DesignTokens`.
- Every new `@export`/script gets a `##` doc header + per-export `##`
  (`test_script_documentation`), and `@tool` scripts guard live side effects on
  `Engine.is_editor_hint()`.
- New tunable numbers (rotation angles, pulse period) go in a named `const`
  block or `@export`, never inline — and never in `Balance.gd`.
- Editor workflow: scene work via `scene_open`→`node_*`→`scene_save`; never
  hand-edit `.tscn` while the editor is attached. Overrides on an instanced
  sub-scene's *children* are dropped on save — put every tunable on the
  sub-scene root (`StickyNote`, `TallyDot`) as an `@export`.

## 7. Out of scope

- No change to the approve flow, `day_schedules`, grade counts, or persistence.
- No change to the carousel/nav/RosterStrip behaviour.
- The `Sudah` (fully-scheduled) card state reuses the same filled-note skin;
  no separate celebratory treatment in this pass (candidate for a follow-up).

## 8. Acceptance

- Tapping Marcel, scheduling in AturJadwal, and returning lands back on
  Marcel's card — not Murid1 (§3.5).
- An unscheduled Marcel shows five kraft "+ Atur" sticky-notes at varied
  angles under a torn "JADWAL MINGGU INI" band, a "0/5 hari" five-dot tally,
  paperclipped photo, and pencilled catatan — no dead grey block.
- A partially/fully scheduled student shows filled category-coloured notes for
  set days and the tally advancing.
- Cards and notes stagger/settle in with the new juice; empty "+" pulses.
- `test_run(suite="test_student_list")` and `test_run(suite="test_theme_factory")`
  green; full suite green at the milestone.
```
```
