# Plan: tutorial box unify (Tutorialfixpart2)

Spec: `docs/superpowers/specs/2026-10-16-tutorial-box-unify-design.md` (read it first; §0 guardrails are binding: no new art, no `theme_override_*`, no `Balance.gd`, ask the owner before improvising copy/visuals).

Follow `CLAUDE.md` editor hazards: **scene work first, scripts second**, edit `.tscn` only through the Godot MCP, restart the editor before `script_patch`, rescan before `test_run`. Targeted `test_run(suite=...)` per task.

## Task 1 — `placement()` head room (TDD)
- Files: `Scripts/UI/TutorialPanel.gd` (`placement`, `place_step`), `tests/test_tutorial_panel.gd`.
- Write failing pure-geometry tests: card+mascot (196px head room) inside bounds at top and bottom anchors; no overlap with `spot`; arrow tip keeps a min gap from other controls; 1080x2400 case.
- Add a documented `head_room` term (named const or `@export`, `##` doc) and make tests pass. Recompute tucked rect + popup-floor guard from the same value.

## Task 2 — one placement path on StudentCard
- `Scripts/StudentCard/StudentCard.gd`: delete `_tutorial_card_rect()` / `_tutorial_card_position()`, route `_position_tutorial_panel()` through `TutorialPanel.place_step`.
- Update pinned tests: `test_student_card`, `test_popup_frames`, `test_tall_screen_layout`, `test_atur_jadwal`, `test_lobby`.
- Verify: energy-step arrow no longer lands on the Mood bar; Lobby inventory arrow clear of JADWAL; mascot inside Safe/UI.

## Task 3 — TutorialComic in the Nota Guru note (scene first)
- `Scenes/UI/TutorialComic.tscn`: replace the white `Card` Plate with the shared note (NotebookFrame + name tab + mascot + step pill); LEWATI, tap prompt, counter in the same spots as `TutorialPanel`. Keep the `plate_*.svg` illustration slot, scrim, `finished` signal. Centred.
- Then `Scripts/UI/TutorialComic.gd` node paths. Source-scan test that it instances the shared note nodes.

## Task 4 — MinigameTutorial (CARA MAIN) in the Nota Guru note
- `Scenes/Minigames/UI/MinigameTutorial.tscn`: add mascot + name tab (PAK KEPSEK) on the existing NotebookFrame; step rows + Mulai stay in the body; stays a `CanvasLayer`.
- Update `test_popup_frames` / `test_minigame_layout_kit` entries + source scan.

## Task 5 — Voice B copy trim
- `Scripts/StudentCard/FirstRunTutorial.gd` `STEPS`: one nudge line per step using spec §4 drafts; spotlight stays on the existing stat-row `Label` (no new pill art). Same trim for `HeadmasterBeat` and the pick-TUGAS beat.
- **Get owner sign-off on final Indonesian strings before committing.** Update copy pins in `test_tutorial_panel` / `test_student_card`.

## Task 6 — verify and ship
- Full `test_run` once; `git checkout --` unintended `kejartes_theme.tres` / `default_bus_layout.tres` changes.
- Full-size screenshots of comic, energy step, Lobby inventory step, CARA MAIN → send to owner.
- Update `DEBT.md` (remove the 2026-10-13 mascot known gap), add a `CHANGELOG.md` entry, then finish with the `ship-pr` skill.
