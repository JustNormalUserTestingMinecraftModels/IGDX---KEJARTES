# Tutorial Unification + Headmaster Beat (implementation plan)

Handoff plan for the design in
`docs/superpowers/specs/2026-09-30-tutorial-unify-and-headmaster-beat-design.md`.
Build on a fresh branch off `Textures`. Read spec §3–§6 before touching a node —
this plan assumes them, and assumes design decision **5-A** (headmaster beat on
StudentCard). If the team picks 5-B, only Phase 4 changes.

**Golden rule:** scene work first, script work second, then rebake if tokens
moved, then tests. Restart the editor after patching any `class_name`/`@export`
script before the next `scene_save`. Never hand-edit a `.tscn` while the editor
is attached — go through `scene_open` → node ops → `scene_save`.

---

## Phase 0 — Branch + placeholder art

1. Branch off `Textures` (e.g. `tutorial-unify-headmaster`).
2. Drop a drop-replaceable `Assets/Images/UI/Placeholders/pin.png` (small red
   disc, any legible stand-in). Import: `filesystem_manage(op="scan")`.
3. `test_run` the currently-green tutorial suites to capture a baseline
   (`test_tutorial_panel`, `test_atur_jadwal`, `test_student_list`,
   `test_student_card`). **Checkpoint.**

## Phase 1 — Shared coach-mark: pin, step pill, name-plate variant (TDD)

1. Tests first, in `tests/test_tutorial_panel.gd`:
   - `TutorialPanel` exposes a documented `@export` for **mode**
     (`STEP` vs `HEADMASTER`) or an equivalent name-plate toggle;
   - a `show_step()`/`show_beat()` API sets the pill vs name-plate text;
   - no `theme_override_*` on the new nodes (extend the existing scan).
2. Edit `Scenes/UI/TutorialPanel.tscn` via the editor:
   - add `Pin` (`TextureRect`, `pin.png`, top-center);
   - add `StepPill` (mint `Card`/pill variation + label) above `TitleLabel`;
   - add `NamePlate` (mint pill + `school` glyph + label), hidden by default;
   - set root `pivot_offset` to top-center for the hang/sway.
3. Edit `Scripts/UI/TutorialPanel.gd`:
   - documented `@export` mode + setters (guard on `is_inside_tree()`),
     swapping `StepPill`↔`NamePlate` visibility;
   - `show_beat(name, title, body, prompt)` alongside `show_step(...)`;
   - pull mint from `DesignTokens` (no `Color()` literals).
4. `scene_save`, restart editor, scan.
5. `test_run(suite="test_tutorial_panel")`. **Checkpoint.**

## Phase 2 — Animation + arrow

1. Add the entrance/idle-sway/exit tweens to `TutorialPanel.gd` (spec §3b),
   using `AnimUtils`/`Juice` — a helper `play_in()` / `play_out()` and a
   looped `_start_sway()`. Guard live side effects behind
   `if Engine.is_editor_hint(): return` where they run in `_ready`.
2. Edit `Scripts/TutorialArrow.gd`: shrink to ~180×180, offset the tip beside
   the target; keep the bounce.
3. Test: assert the sway tween is created and the arrow size const changed
   (source scan is acceptable per house pattern).
4. `test_run(suite="test_tutorial_panel")`. **Checkpoint.**

## Phase 3 — Adopt the shared panel in AturJadwal + StudentList; wrong-tap fix

Do these two screens one at a time; keep the suite green between them.

1. Tests first: assert `AturJadwal.gd` / `StudentList.gd` no longer contain
   `PanelContainer.new()` / `add_theme_stylebox_override` (the runtime-panel
   deletion); assert a forced-step wrong tap triggers `shake` + `error` sfx.
2. `AturJadwal.gd`:
   - delete `_build_tutorial_panel()` and its label vars; instantiate
     `TutorialPanel.tscn` instead (mirror StudentCard's `_build_tutorial_panel`
     at `StudentCard.gd:318`);
   - route `_show_step` text through the scene's `show_step`;
   - at the forced-day gate (`~:1185–1196`), replace the silent `return` with:
     `error` sfx + `Juice.shake` on the target day + dim non-targets, panel stays.
3. `StudentList.gd`: same deletion + adoption; apply wrong-tap feedback to its
   forced steps (`current_step == 2` path).
4. Anchor both inside `SafeAreaMargin`/`UI` (spec §3c) rather than viewport math.
5. `scene_save` if any scene changed, restart editor, scan.
6. `test_run(suite="test_atur_jadwal")`, then `test_run(suite="test_student_list")`.
7. Lower the `BASELINE` in `tests/test_viewport_editability.gd` by the two
   deleted runtime panels (ratchet **down**). `test_run(suite="test_viewport_editability")`.
   **Checkpoint.**

## Phase 4 — Decouple the headmaster beat (design decision 5-A)

1. Tests first, in `tests/test_student_card.gd`:
   - the grade-8 and grade-9 congratulation strings are **absent** from
     `_populate_default_tutorial_steps()`;
   - the new beat data holds the rewritten (no `"Kepala Sekolah:"` prefix)
     strings;
   - the beat trigger does **not** reference `tutorials_bypassed`.
2. `Scripts/GameState.gd`: add a session-scoped `headmaster_beats_seen` set (no
   disk). Document it.
3. `StudentCard.gd`:
   - remove the grade-8/9 branches from `_populate_default_tutorial_steps()`;
     keep only the real grade-7 teaching steps and the single "pilih N murid"
     instruction step (tutorial-gated);
   - add a `_maybe_play_headmaster_beat()` in `_ready()` that, when
     `current_grade` just advanced and its grade is not in
     `headmaster_beats_seen`, shows the `TutorialPanel` in `HEADMASTER` mode
     with the §4b strings — **independent of `tutorials_bypassed`** — then marks
     the grade seen.
4. Reuse the existing tutorial CanvasLayer for the overlay.
5. Restart editor, scan.
6. `test_run(suite="test_student_card")`. **Checkpoint.**

## Phase 5 — SchoolDay end-of-week restyle (knobs only)

1. Point SchoolDay's `TutorialPanel` at the Option A look via its existing
   `@export` knobs (no structural change; spec §3a). Verify its shipped numbers
   (`width_fraction` 0.85, `max_width` 900, `content_margin` 30) still read well
   with the pin/pill added.
2. `test_run(suite="test_school_day")`. **Checkpoint.**

## Phase 6 — Full run + hygiene

1. Full `test_run` (budget one editor restart — the runner can drop the bridge).
2. `git status`: `git checkout --` any unintended `kejartes_theme.tres` /
   `default_bus_layout.tres` churn from the run (CLAUDE.md ## Testing).
3. Check `git diff HEAD -- '*.gd'` for stale-tab writebacks after scene saves.
4. Confirm `test_viewport_editability` BASELINE only went **down**.
5. Commit per phase with Conventional Commits, scope `tutorial`, e.g.
   `refactor(tutorial): adopt shared sticky-note coach-mark in atur jadwal`.

---

## Handoff notes

- This is a design + plan handoff — **not executed**. The implementing session
  runs the editor/bridge; per CLAUDE.md the bridge is single-client, so one
  driver at a time.
- Open decision for the implementer: spec §5 (5-A vs 5-B). Plan assumes 5-A.
- All Indonesian player copy must read naturally (KBBI); the §4b strings are a
  starting draft, tune as needed.
- `Balance.gd` is not touched.
