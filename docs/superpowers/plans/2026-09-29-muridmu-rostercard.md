# MURIDMU RosterCard "Schooly & Alive" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The StudentList ("MURIDMU") roster card reads as a weekly planner on a desk: sticky notes with tape at authored angles, inviting "+ Atur" slots for unplanned days, a torn "JADWAL MINGGU INI" band with a five-dot tally, a paperclipped photo and a pencilled catatan; it arrives alive, swipes like a stack of files that follows the finger, quietly pulses what is tappable, and reopens on the student you were just on.

**Spec (binds):** `docs/superpowers/specs/2026-09-28-muridmu-rostercard-schooly-design.md` (§3–§8). Supersedes the collaborator's handoff plan `docs/superpowers/plans/2026-09-28-muridmu-rostercard-schooly.md`. **Look:** `docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md`.

## Revision (2026-09-29, maintainer)

The handoff predates the UI depth pass and the clean-code ratchet's size
limits. Same scope, different *how*:

- **`StudentList.gd` must not grow.** It is 943 lines (the ceiling for any
  script is 1,000) and `_setup_students` (74 lines) and `_show_step` are
  already tracked long functions that may not get longer. So:
  - The swipe/drag/ghost-card transition moves out into a new component,
    `Scripts/StudentList/RosterDeck.gd` (`class_name RosterDeck`, a Node child
    of StudentList). `_switch_card` and the swipe half of `_on_card_gui_input`
    become calls into it, so StudentList.gd gets **shorter**.
  - The week wiring (`scheduled`, `days_scheduled`) is a small extracted
    helper called from `_setup_students`, which shrinks it.
  - Card entry beats live on `RosterCard` (`play_entry()`), idle loops on the
    nodes they animate (StickyNote, RosterCard's inner paper, RosterAvatar,
    and a tiny reusable `NudgeLoop.gd` on the nav arrows). StudentList only
    calls down.
  - The two `Juice.stagger_in` call sites in StudentList.gd stay **verbatim**
    (`test_motion_is_wired`).
- **Depth-pass palette roles.** The tap-me glow on empty notes and the active
  roster ring use `accent_sunflower` (the palette's *highlight*, same hex as
  the spec's `currency_gold`); filled tally dots use `accent_mint` (affirm);
  the empty note is kraft `surface_sunken` with `text_secondary` ink; the
  catatan margin rule uses `accent_tomato`. Tokens only.
- **Reduced motion:** every idle loop and the entry overshoot are skipped when
  `GameSettings.reduce_motion` is on (the flag exists; AturJadwal already
  honours it).
- **Art:** reuse before drawing. Tape = `Assets/Images/AturJadwal/washi_tape.svg`.
  New placeholders, as small hand-written SVGs under
  `Assets/Images/UI/StudentList/` (drop-replaceable at the same path):
  `torn_band.svg`, `paperclip.svg`, `pencil.svg`, `icon_add.svg`,
  `icon_calendar.svg`, `sticky_empty_frame.svg` (a dashed rounded frame for a
  9-slice; StyleBoxFlat cannot dash). Every new path joins
  `tests/test_student_list.gd`'s art list and `DEBT.md`'s placeholder list.

## Global Constraints

- **Godot 4.6**, portrait. UI text Indonesian; systems code English.
- **Tests** run only in the editor via `test_run`; suites `@tool extends McpTestSuite`; no `await` in a test; `McpTestSuite` has only `assert_true/false/eq/ne/gt/has_key/contains/is_error`.
- **Scenes:** hand-edit a `.tscn` only while the controller has this worktree's editor **closed**; the controller re-saves touched scenes through the editor afterwards. New nodes get a random `unique_id` between 100000000 and 2147483647 not already in the file; omit default-valued properties; `texture_repeat` ENABLED is 2. Tunables of an instanced sub-scene live as `@export`s on its **root** (child overrides are dropped on save).
- **No `theme_override_*`** except layout constants (`separation`, `margin_*`); `StudentList.tscn` and `StickyNote.tscn` are scanned. New looks are `ThemeFactory` variations; the controller rebakes.
- **No runtime-built visuals**: tape, band, dots (a `TallyDot.tscn` `PackedScene` template, five instances authored), clip, pencil, ghost card, glow — all authored nodes; scripts only toggle, tint from tokens, and tween.
- **No `Color(...)` literals** in scripts (`test_no_hardcoded_colors_remain`); tones from `DesignTokens`.
- **Pinned, do not rename/retype:** `HeaderLabel`=H1Label, `Nama`=H2Label, `Belum`/`Sudah` stamps, nav arrows `SecondaryButtonL`, `Senin`…`Jumat` StickyNotes under `StickyNotesContainer`, cards `Murid1`…`Murid4`; routing to AturJadwal (`test_still_routes_to_atur_jadwal`); touch targets ≥ `tokens.touch_target_min`.
- **Clean code:** `##` header + `##` per `@export`; typed everything (loop variables too); no `var x := <Autoload>.…`; named `const`s for angles/periods/amplitudes (a `const` block per owning script); `%` names for nodes a script touches; `push_error` on a missing node the scene must have; no script may cross 1,000 lines and no tracked long function may grow. Run `clean_code` each task; lock in any shrink with `ci/clean_code_dump.gd`.
- **Every loop Tween** is stored on its node and `kill()`ed on card-leave, popup/tutorial open, and `_exit_tree`; none leak across swipes.
- **Out of scope:** approve flow, `day_schedules`, grade counts, persistence, the `Sudah` celebration.
- **Commits:** Conventional Commits with a scope, message via `git commit -F`, ending with the session's attribution trailer.

## File Structure

- `Assets/Images/UI/StudentList/*.svg` — six placeholders (above).
- `Scripts/Design/ThemeFactory.gd` — `StickyNoteEmptyFrame` (Panel), `StickyNoteEmptyLabel`, `WeekBandLabel` (or reuse `CardSectionLabel`), `TallyCountLabel`, tally dot looks if a Panel is used, `RosterAvatarRingActive` if needed.
- `Scenes/StudentList/StickyNote.tscn` + `Scripts/StudentList/StickyNote.gd` — `Tape`, `EmptyFrame`, `@export var scheduled`, `@export var tilt_degrees`, `set_inviting()` glow loop.
- `Scenes/StudentList/TallyDot.tscn` + `Scripts/StudentList/TallyDot.gd` — `@export var filled`, `pop()`.
- `Scenes/StudentList/RosterCard.tscn` + `Scripts/StudentList/RosterCard.gd` — `WeekHeader`, `DayTally`, `Clip`, `PortraitFrame` tilt, `Pencil` + margin rule, inner `Paper` node; `@export var days_scheduled`; `play_entry()`, `set_breathing()`.
- `Scripts/StudentList/RosterAvatar.gd` + `.tscn` — animated active state (scale, lift, sunflower ring, brand border).
- `Scripts/UI/NudgeLoop.gd` — a reusable ±px idle nudge for a Control (amplitude/period `@export`s).
- `Scripts/StudentList/RosterDeck.gd` — the stack-of-files transition, finger-follow drag, ghost-card parallax.
- `Scenes/StudentList/StudentList.tscn` + `Scripts/StudentList/StudentList.gd` — `GhostCard` node, delegate to `RosterDeck`, week wiring helper, reopen-on-last-student.
- Tests: `tests/test_student_list.gd` (+ a focused `tests/test_roster_deck.gd` for the deck math), `tests/test_theme_factory.gd`, `tests/test_tall_screen_layout.gd` if it pins StudentList.

---

## Task 1: Theme variations and placeholder art

- [ ] Add the six SVGs (simple, legible, transparent; `icon_add`/`icon_calendar` follow `Assets/Images/UI/Icons/README.md`'s outline-and-contrast rules). Add each path to `test_student_list.gd`'s art list (they must load as `Texture2D`) and list them in `DEBT.md`'s placeholder inventory.
- [ ] `ThemeFactory` (a `_build_student_list_week` builder): the empty-note label (`text_secondary`), the week band label (reuse `CardSectionLabel` if it fits the band; else a `WeekBandLabel`), the tally count label, and any Panel looks the later tasks need. Tokens only; pin in `test_theme_factory.gd` (and `DISPLAY_ROSTER` for display-face labels).
- [ ] Controller rebakes and runs `theme_factory`, `student_list`, `ui_icons` (if it scans the folder), `clean_code`.
- [ ] Commit `feat(muridmu): week-planner theme looks and placeholder art`.

## Task 2: StickyNote — filled/empty, tape, tilt

- [ ] Tests (in `test_student_list.gd` or a new `test_sticky_note.gd`): `scheduled` and `tilt_degrees` are `@export`s; `scheduled = false` shows `EmptyFrame`, sets the icon to `icon_add.svg` and the label to "Atur" in the muted look; `scheduled = true` hides the frame and keeps the category tint path; `Tape` exists with `washi_tape.svg`; no `theme_override_*` (existing scan).
- [ ] Scene (editor closed): `Tape` (top-centre, self_modulate alpha from a named const), `EmptyFrame` (NinePatchRect with `sticky_empty_frame.svg`, or a Panel variation), hidden by default. Tilt is applied to the root's `rotation` from `tilt_degrees` with a centred `pivot_offset` (StickyNotesContainer is a plain Control, so rotation holds).
- [ ] Script: setters guarded on `is_node_ready()` (the file's `@tool` pattern); `set_inviting(on: bool)` starts/stops a looped sunflower glow (the frame's `self_modulate` toward `accent_sunflower` and back, ~1.9 s sine, plus a sympathetic "+" scale pulse), stored and killed; skipped under `GameSettings.reduce_motion`; killed in `_exit_tree`.
- [ ] Controller re-saves, runs `student_list`, `script_documentation`, `clean_code`, `viewport_editability`.
- [ ] Commit `feat(muridmu): sticky notes plan-me slots, tape and tilt`.

## Task 3: RosterCard — week header, tally, photo, catatan

- [ ] `TallyDot.tscn` (root `@export var filled`, filled = `accent_mint`, empty = ringed `surface_sunken`; `pop()` = a `coin_pulse`-style scale pop).
- [ ] Tests: `RosterCard.days_scheduled` exists and clamps 0–5; setting 3 fills exactly the first three dots and the label reads "3/5 hari"; `WeekHeader` (with `Band` torn_band, a `CardSectionLabel`-family "JADWAL MINGGU INI" label and the calendar icon) and `DayTally` (five `TallyDot` instances) exist; the five notes carry the authored tilts SEN −2.5°, SEL +1.5°, RAB −1.5°, KAM +2°, JUM −1° via `tilt_degrees`; `Clip` over the portrait; `PortraitFrame` −1.5°; `Pencil` and a margin rule in `CatatanGuru`; the old `Senin`…`Jumat` names/types still pass.
- [ ] Scene (editor closed): add those nodes; wrap the card's visual content in an inner `Paper` Control if one does not exist (breathing animates it, never the card root the deck moves). Keep the card's rect; if the header needs room, take it from the notes' top offset, not the card size.
- [ ] Script: `days_scheduled` setter; `play_entry()` (the spec's §4 beats: Nama fade-up, portrait squash to rest, trait chips, stamp thunk via `AnimUtils.popup_spring_in`, notes' rotate-overshoot to their tilt, tally pops) with timings in a `const` block and skipped overshoot under reduce_motion; `set_breathing(on)` (inner `Paper` scale 1↔1.012 + shadow lift, ~3.6 s), stored and killed.
- [ ] Controller re-saves, runs `student_list`, `tall_screen_layout`, `viewport_editability`, `script_documentation`, `clean_code`; screenshots an unscheduled card.
- [ ] Commit `feat(muridmu): the card's week band, tally, paperclip and pencil`.

## Task 4: Wire the week and reopen on the last student

- [ ] Tests: after `_setup_students` with a partial schedule, each note's `scheduled` matches `day_schedules` and the card's `days_scheduled` is the count; empty notes are `inviting`; with `GameState.selected_student` set to the third student, `_init_carousel_state()` lands `current_card_index` on 2; unset/unknown → 0. (Source scan acceptable where the method cannot run headless; say so.)
- [ ] `StudentList.gd`: extract the per-card week wiring into one helper called from `_setup_students` (so that function shrinks); resolve the initial index from `GameState.selected_student.id` in `_init_carousel_state` (typed local, no autoload inference). Routing and both `Juice.stagger_in` call sites untouched. Call `card.play_entry()` where the card lands and toggle breathing/inviting on the front card only.
- [ ] Controller runs `student_list`, `clean_code` (lock in shrinks), `project_hygiene`.
- [ ] Commit `feat(muridmu): the planner reads the week and reopens on your student`.

## Task 5: Roster avatars and nav nudges

- [ ] `RosterAvatar`: `is_current` animates (inactive ~0.82 scale dimmed; active ~1.4 scale, a few px lift, sunflower ring, brand border) with an overshoot settle (~0.42 s, `AnimUtils`), consts named; touch target ≥ `touch_target_min` at the small scale (the Button's rect, not its visual scale). Replace `_sync_roster_strip`'s hard alpha swap with the animated setter (StudentList.gd shrinks or stays equal).
- [ ] `Scripts/UI/NudgeLoop.gd`: `@tool` Node that nudges its parent Control ±`amplitude` px on x with `period`, starts when enabled, honours reduce_motion; attach under each nav arrow in `StudentList.tscn` (editor closed), enabled only when there is more than one card (StudentList sets `enabled`).
- [ ] Tests: `RosterAvatar` current/inactive target values; NudgeLoop exists under both arrows and is disabled for one card.
- [ ] Controller re-saves, runs `student_list`, `back_controls`, `clean_code`, `script_documentation`.
- [ ] Commit `feat(muridmu): a bouncing roster ring and nudging arrows`.

## Task 6: RosterDeck — stack-of-files swipe that follows the finger

- [ ] `Scripts/StudentList/RosterDeck.gd` (`class_name RosterDeck`, Node): owns `switch(old_card, new_card, direction)` (overlapped tweens on one timeline: outgoing −screen_width×dir, −9°×dir, 0.92, fade; incoming from the peek slot +30 px, 4°, 0.9, alpha 0 to front with TRANS_BACK/EASE_OUT ~0.4 s), `begin_drag/update_drag/end_drag` (front card x follows the pointer with capped proportional tilt; ghost card follows at a parallax fraction; release past `min_swipe_distance` or a flick with the existing `abs(dx) > abs(dy) * 1.2` gate throws, else springs back), a `busy` flag, and signals (`switched`, `settled`) so StudentList listens (signals up). Constants in a block. Pure helpers (`classify_release(dx, dy, velocity) -> int`, `drag_pose(dx) -> Dictionary`) so `tests/test_roster_deck.gd` tests the math without a scene.
- [ ] `StudentList.tscn` (editor closed): `GhostCard` (a `surface_sunken` paper panel at the peek pose, ~0.5 alpha, behind the carousel, mouse ignored) and a `RosterDeck` node.
- [ ] `StudentList.gd`: `_switch_card` and the swipe path of `_on_card_gui_input` delegate to the deck; `card_animating` becomes the deck's `busy`; the tutorial lock and the `current_step == 2` auto-advance stay; a tap still routes to AturJadwal; `_stagger_card_notes` still runs on land; roster strip and page dots update when the deck emits `switched` (animated, not after the slide). Breathing/inviting pause during a drag/switch and resume on `settled`. StudentList.gd must end **shorter** than 943 lines.
- [ ] Tests: `test_roster_deck.gd` (classify_release for tap, vertical drag, short drag, long drag, flick; drag_pose tilt cap); `test_student_list.gd` pins that `_switch_card` no longer awaits `tween_out.finished`, that StudentList delegates to `RosterDeck`, that `GhostCard` exists and ignores the mouse, routing still intact.
- [ ] Controller re-saves, runs `student_list`, `roster_deck`, `clean_code`, `script_documentation`, `viewport_editability`; live check: drag follows the finger, short drag springs back, tap opens AturJadwal, vertical drag is not a swipe.
- [ ] Commit `feat(muridmu): a stack-of-files swipe that follows the finger`.

## Task 7: Verify, docs, ship

- [ ] Live screenshots at full size (1080×1920): an unscheduled card (five "+ Atur" slots, 0/5), a partially scheduled card, mid-swipe with the ghost card; 1080×2400 capture. Round-trip: tap Marcel → AturJadwal → back lands on Marcel. Repeated swipes leave no leaked tweens (count `get_tree().get_processed_tweens()` before/after).
- [ ] `CHANGELOG.md` entry; `DEBT.md` (placeholder art; anything deferred); CLAUDE.md suite/test counts after the full run.
- [ ] Final whole-branch review, full suite, `ship-pr`.
