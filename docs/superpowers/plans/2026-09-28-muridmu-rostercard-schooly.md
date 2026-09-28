# MURIDMU RosterCard — "Schooly & Alive" (implementation plan)

Handoff plan for the design in
`docs/superpowers/specs/2026-09-28-muridmu-rostercard-schooly-design.md`.
Build on a fresh branch off `Textures`. Read the spec's §6 constraints before
touching a node — this plan assumes them.

**Golden rule:** scene work first, script work second, then rebake, then tests.
Restart the editor after patching any `class_name`/`@export` script before the
next `scene_save`.

---

## Phase 0 — Branch, art placeholders, and the test art-list

1. Branch off `Textures` (e.g. `muridmu-rostercard-schooly`).
2. Drop placeholder art at the seven paths in spec §5 (any legible stand-in;
   they are drop-replaceable). Import them (`filesystem_manage(op="scan")`).
3. Add all seven paths to the scanned list in
   `tests/test_student_list.gd::test_part_three_art_exists_and_loads`.
4. `test_run(suite="test_student_list")` → the art test should pass; others
   unchanged. **Checkpoint.**

## Phase 1 — StickyNote: filled/empty skin + tape (TDD)

1. In `tests/test_student_list.gd` (or a focused StickyNote test), add:
   - a test that `StickyNote.gd` exposes a `scheduled` bool `@export`;
   - a test that the empty state uses no `theme_override_*` (the scene scan
     already covers this — extend if you add nodes).
2. Edit `Scenes/StudentList/StickyNote.tscn` via the editor:
   - add `Tape` (`TextureRect`, `tape.png`, top-centre, alpha ~0.55);
   - add the empty-state frame child (dashed `StickyNoteEmpty` Panel variation
     *or* `sticky_empty_frame.png` `TextureRect`), hidden by default.
3. Edit `Scripts/StudentList/StickyNote.gd`:
   - add `## `-documented `@export var scheduled: bool` with an
     `is_node_ready()`-guarded setter that swaps filled↔empty (frame child
     visibility, `Icon` glyph, `ActivityLabel` text/tone), pulling tones from
     `DesignTokens` (no `Color()` literals);
   - keep the existing category-tint path for the filled state.
4. `scene_save`, restart editor, `filesystem_manage(op="scan")`.
5. `test_run(suite="test_student_list")`. **Checkpoint.**

## Phase 2 — RosterCard: per-slot angles, WeekHeader, dot tally

1. Tests first: assert `RosterCard` exposes `days_scheduled: int`; assert
   `WeekHeader` and `DayTally` nodes exist; assert `Senin`…`Jumat` still named
   and typed as `StickyNote` (existing test — keep green).
2. Create `Scenes/StudentList/TallyDot.tscn` (a `TextureRect` + documented
   `@export var filled: bool` on its root, tone from tokens).
3. Edit `Scenes/StudentList/RosterCard.tscn`:
   - set per-slot `rotation` + centre `pivot_offset` on the five notes
     (SEN −2.5°, SEL +1.5°, RAB −1.5°, KAM +2°, JUM −1°);
   - add `WeekHeader` (torn `Band` + `CardSectionLabel` "JADWAL MINGGU INI" +
     `icon_calendar`) above `StickyNotesContainer`;
   - add `DayTally` HBox of five `TallyDot` instances + an "n/5 hari" Label;
   - add `Clip` (paperclip) over `PortraitFrame`, and `PortraitFrame`
     rotation −1.5°;
   - add `Pencil` + margin rule to `CatatanGuru`.
   Remember: every tunable belongs on a sub-scene **root** `@export`, not poked
   into a child (dropped on save).
4. Edit `Scripts/StudentList/RosterCard.gd`: add documented
   `@export var days_scheduled: int` whose setter fills the first *n* `TallyDot`s
   and sets the count label (guarded on `is_node_ready()`).
5. `scene_save`, restart editor, scan.
6. `test_run(suite="test_student_list")`. **Checkpoint.**

## Phase 3 — Wire data in StudentList.gd

1. In `_setup_students()`: set `sticky_node.scheduled = is_day_set` for each
   day (the loop already computes `is_day_set`); sum the set days into a local
   `count` and set `murid_node.days_scheduled = count`.
2. Confirm routing and the two `Juice.stagger_in` call sites are untouched.
3. `test_run(suite="test_student_list")`. **Checkpoint.**

## Phase 3b — QoL: reopen on the last-viewed student (spec §3.5)

1. Test first: an `_init_carousel_state()`-level test that, with
   `GameState.selected_student` set to a non-first student's dict,
   `current_card_index` resolves to that student's index (and falls back to 0
   when unset or unmatched). Source-scan is acceptable if the method can't run
   headless.
2. In `_init_carousel_state()`, before the first reveal, resolve
   `current_card_index` from `GameState.selected_student.id` against
   `active_students` (clamp; 0 on miss). Leave `selected_student` assignment in
   `_on_student_selected` untouched.
3. `test_run(suite="test_student_list")`. **Checkpoint.**

## Phase 4 — Theme variations + rebake

1. If Phase 1/2 introduced `StickyNoteEmpty` / dot / band variations, add them
   to `Scripts/Design/ThemeFactory.gd` (tones from `DesignTokens`), plus any
   `CatatanNoteLabel` display-face variation *if adopted* (propose first).
2. Rebake: run `Scripts/Design/BakeTheme.gd` (Ctrl+Shift+X), or rely on a full
   `test_run` (the `theme_rebake` suite rebakes in-process — then check
   `git status` and keep only the intended `kejartes_theme.tres` change).
3. `test_run(suite="test_theme_factory")`. **Checkpoint.**

## Phase 5 — Motion pass

1. Add note-settle rotate-overshoot, BELUM stamp thunk, empty-"+" pulse, and
   dot-fill pop per spec §4, using `Juice` / `Scripts/AnimUtils.gd`. Store
   angles/periods as named `const`s.
2. **Idle affordance loops (spec §4.2):** the empty-note **outer glow** (soft
   `currency_gold` bloom + dashed-border brighten, the primary tap cue) with a
   sympathetic "+" pulse; **paper breathing** on the front card (slow scale +
   lifting shadow) applied to an **inner paper node** so it never fights the
   swipe transform on the card root; and the ±4px nav-arrow nudge. Filled notes
   stay calm. Store every loop `Tween` on its node; `kill()` / pause on
   card-leave / popup-open / tutorial. Verify no leaked tweens after repeated
   swipes, and that breathing is paused mid-swipe.
   Also rework the **roster avatar highlight** in `_sync_roster_strip`: active
   avatar scales up (~1.4) + gold ring + brand border with a bounce on
   selection change (`AnimUtils`), inactive ones dim/shrink — animate, don't
   hard-set `is_current`. Touch targets on tappable avatars stay ≥
   `touch_target_min`.
3. **Swipe rework (spec §4.1):** add the authored `GhostCard` peek node behind
   the carousel; rework `_switch_card` to overlap tween-out/tween-in (drop the
   `await tween_out.finished` gate) with the stack-toss/spring-in transforms;
   tween the `RosterStrip` highlight + `PageIndicator` dot during the slide;
   keep `_stagger_card_notes` on land and the `card_animating` guard + the
   `current_step == 2` tutorial auto-advance.
3b. **Finger-follow drag (spec §4.1, required):** in `_on_card_gui_input`,
   track the front card's `position:x` under the pointer with proportional tilt
   and a parallax drag on the `GhostCard`; on release complete the throw past
   `min_swipe_distance`/flick, else spring back. Keep the
   `abs(delta.x) > abs(delta.y) * 1.2` horizontal gate, the `card_animating`
   guard, and the tutorial lock. Verify a vertical drag or a tap still isn't
   read as a swipe, and that a tap on the card still opens AturJadwal.
4. `test_run(suite="test_student_list")` (keeps `test_motion_is_wired` and
   `test_still_routes_to_atur_jadwal` green). **Checkpoint.**

## Phase 6 — Verify, screenshot, ship

1. Seed + teleport to StudentList: Debug (`F1`) → General → ⚡ Seed Playtest
   State, then Scenes → StudentList. To see filled notes, pass through Atur
   Jadwal first (the seed does not fill `day_schedules`).
2. Full-size `editor_screenshot` of an unscheduled card and a partially
   scheduled card; compare against the approved mock. Verify tall-phone
   (1080×2400) framing — nothing clips, header/tally/notes re-anchor cleanly.
3. Full `test_run` at the milestone (budget one editor restart; a full run
   rebakes the theme and rewrites `default_bus_layout.tres` — `git checkout --`
   whatever you did not intend). Confirm green.
4. Update `docs/superpowers/CHANGELOG.md` (newest first); delete any DEBT entry
   this resolves.
5. Finish with the `ship-pr` skill.

---

## Risk notes

- **Dashed borders in a StyleBox** may not render as true dashes in Godot 4.6;
  if not, fall back to `sticky_empty_frame.png` (already an allowed asset).
- **Rotation + touch targets:** rotating a note doesn't shrink its rect, but
  confirm the card tap still routes and any per-note hit stays ≥
  `touch_target_min`.
- **Sub-scene child overrides silently dropped:** if a tint "doesn't stick"
  after save, it was set on a child — move it to the sub-scene root `@export`.
- **`days_scheduled` vs `is_scheduled`:** `is_scheduled` (Belum/Sudah stamp)
  already exists; `days_scheduled` is the new granular count for the tally.
  Keep both; the stamp logic is unchanged.
```
```
