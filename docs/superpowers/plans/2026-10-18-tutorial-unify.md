# Plan: tutorial unify (Tutorialfixpart2), one plan

Date: 2026-10-18. Branch: `Tutorialfixpart2`. Target: `Textures`.
Spec: `docs/superpowers/specs/2026-10-16-tutorial-box-unify-design.md` (§0
guardrails bind: no new art, no `theme_override_*`, no `Balance.gd`, ask the
owner before improvising copy or visuals). Replaces
`plans/2026-10-14-tutorial-text-unify.md` and `plans/2026-10-17-tutorial-box-unify.md`,
which disagreed with each other and with the code on this branch.

## 0. Where the branch stands

Landed (commits `e428f9e5`, `a679bd22`):

- Debug boot no longer bypasses tutorials (`DebugManager._apply_playtest_defaults`).
- Text ladder: `TutorialTitleLabel` (display, h2, outlined), `TutorialNoteLabel`
  (body, title size), `TutorialPromptLabel` (body, body size, secondary) on every
  `TutorialPanel`; the `title_/body_/prompt_variation` exports are gone.
- SchoolDay's end-of-week-1 card is four short pages with a step pill.

Not done, and wrong in the earlier plans (each fixed below):

| # | Finding | Fixed in |
|---|---|---|
| A1 | `nota_style` survives as a chrome-only flag, though the 10-14 plan said delete it and the spec makes the chrome uniform. | Task 6 |
| A2 | `BodyLabel` keeps `custom_minimum_size = Vector2(-170.16, 0)` in the scene. | Task 1 |
| A3 | `BodyLabel` carries `theme_override_constants/line_spacing = 8`. The 10-14 plan let `line_spacing` through as "layout-only"; CLAUDE.md allows only `separation` and `margin_*`. | Task 1 |
| A4 | `SchoolDay` reads `end_tutorial_pages[0]` with no guard: an emptied export in the inspector crashes the week-1 end. | Task 1 |
| A5 | Both plans say "restart the editor **before** `script_patch`". CLAUDE.md 4b says the opposite: after patching a script, restart **before the next `scene_save`**. | §Hazards |
| A6 | Spec §4 copy calls itself KBBI-standard but uses `bikin`, `ngambek`, `biar`, `skill`, `KETUK APPROVE`. | Task 7 |
| A7 | 10-17 Task 1 asks `placement()` to keep the arrow tip clear of "other controls"; `placement()` only receives `spot`, and the arrow is aimed by `arrow.point_at`, not by `placement()`. | Task 3 |
| A8 | 10-17 Task 3/4 say comic and CARA MAIN "instance the shared note", but there is no shared note scene: mascot, `NameTab` and pill live inside `TutorialPanel.tscn` (`Decor/*`). | Task 2 |
| A9 | 10-17 Task 2 lists `test_atur_jadwal` / `test_lobby` for a StudentCard-only change. They move only because `placement()`'s signature changes (Task 3). | Task 3 |
| A10 | 10-14 header names branch `fix/tutorial-visuals`; the work is on `Tutorialfixpart2`. | this file |

## Hazards (CLAUDE.md, applied to this plan)

- Edit `.tscn` only through the Godot MCP (`scene_open` → node ops → `scene_save`).
- Per task: **scene work first, script work second.** After any `script_patch`,
  restart the editor before the next `scene_save`. After every `scene_save`,
  `git diff HEAD -- '*.gd'` for files you did not touch.
- `ThemeFactory` edits: rebake (`BakeTheme.gd`), then a full editor restart if a
  Resource `@export` default changed.
- Targeted `test_run(suite=...)` per task; one full run in Task 8 only.

## Task 1: finish the text ladder (A2, A3, A4)

1. `ThemeFactory._build_labels`: give `TutorialNoteLabel` a `line_spacing`
   constant of 8 (set after the specs loop, the way other per-variation
   constants are set in this file; grep `set_constant(` for the pattern). Rebake.
2. `TutorialPanel.tscn` (editor): drop `BodyLabel`'s `line_spacing` override;
   set its `custom_minimum_size` to `Vector2(0, 0)` (`_apply_geometry()` sets the
   real width at runtime).
3. `SchoolDay._show_end_simulation_tutorial`: if `end_tutorial_pages` is empty,
   return before the panel is built (`push_warning` naming the export).
4. Tests: `test_theme_factory` pins the 8; `test_tutorial_panel` scans the scene
   for no `theme_override_constants/line_spacing` and no negative min size;
   `test_school_day` scans for the empty guard.

## Task 2: extract the shared note chrome (A8)

The prerequisite both earlier plans skipped.

1. New `Scenes/UI/TutorialNoteChrome.tscn` (`@tool` root script
   `TutorialNoteChrome.gd`, `##` docs): Mascot, NameTab + NameTabLabel, StepPill,
   moved out of `TutorialPanel.tscn`'s `Decor`. Root `@export`s for
   `expression`, `step_text`, `pill_visible` (overrides on instanced children
   are dropped on save, CLAUDE.md 4b).
2. `TutorialPanel.tscn` instances it as `Decor/Chrome`; `TutorialPanel.gd`
   drives it through the root exports. Behaviour unchanged.
3. `test_tutorial_panel`: existing mascot/name-tab/pill tests pass unchanged
   (paths updated); add `test_popup_frames` / `test_script_documentation`
   entries for the new scene as those suites require.

## Task 3: `placement()` head room (A7, A9), TDD

1. Signature: `placement(bounds, panel_size, spot, arrow_size, head_room := 0.0)`.
   `head_room` comes from a documented `const MASCOT_HEAD_ROOM := 196.0` in
   `TutorialPanel.gd` (DEBT.md "Tutorial art" gives 196). The card rect used for
   containment is the panel rect grown upward by `head_room`.
2. Failing tests first (`test_tutorial_panel`, pure geometry): card + head room
   inside `bounds` at the top and bottom anchors; no overlap with `spot`; the
   1080×2400 case.
3. Arrow on a neighbour (energy → Mood bar, Lobby inventory → JADWAL): that is
   `arrow.point_at`'s choice, not `placement()`'s. Reproduce each in a pure test
   against `TutorialArrow.point_at` with the two rects, then fix there. Do not
   add "other controls" to `placement()`.
4. `place_step` passes `MASCOT_HEAD_ROOM`. Callers that call `placement()` or
   `place_step` directly (grep) are Lobby, StudentList, AturJadwal: re-run
   `test_lobby`, `test_student_list`, `test_atur_jadwal`, `test_tall_screen_layout`.

## Task 4: one placement path on StudentCard

1. `StudentCard.gd`: delete `_tutorial_card_rect()` / `_tutorial_card_position()`;
   `_position_tutorial_panel()` calls `TutorialPanel.place_step`.
2. The tucked-card rect and the popup-floor height guard read
   `TutorialPanel.MASCOT_HEAD_ROOM` (the 2026-10-13 note: a naive top margin broke these).
3. Tests: `test_student_card`, `test_popup_frames`, `test_tall_screen_layout`.

## Task 5: comic and CARA MAIN wear the chrome

1. `TutorialComic.tscn`: replace the white `Card` look on `Plate` with
   `NotebookFrame` + an instance of `TutorialNoteChrome`; keep Scrim,
   Illustration row, Marks, Prompt, Skip (LEWATI) and the `finished` signal.
   Centred. Then `TutorialComic.gd` paths.
2. `MinigameTutorial.tscn`: instance `TutorialNoteChrome` on the existing
   `Safe/Center/Frame` (name tab PAK KEPSEK, pill hidden); Steps + Mulai stay in
   `Column`; root stays a `CanvasLayer`.
3. Source scans in `test_tutorial_panel` (comic) and `test_minigame_layout_kit`
   (CARA MAIN) that each instances `TutorialNoteChrome.tscn`;
   `test_popup_frames` roster updated.

## Task 6: retire `nota_style` (A1)

Once Task 5 lands every card wears the same chrome, so the flag has nothing left
to switch. Its only behaviour is "a STEP card hides the sticker and pill".

1. **Ask the owner** whether non-first-run step cards (Lobby, StudentList,
   AturJadwal, SchoolDay) should lose the sticker and pill like first-run does.
   - Yes → make it the default for every STEP card, delete `nota_style`, and
     drop `panel.nota_style = first_run` from `FirstRunTutorial.gd:78`.
   - No → keep the flag but rename it to what it now does
     (`hide_step_chrome`) and fix its `##` doc; do not leave a flag named for a
     text style that no longer exists.
2. Update `test_nota_style_drops_the_sticker_and_pill` and
   `test_every_card_wears_the_one_text_ladder` to match.

## Task 7: Voice B copy (A6)

1. Draft one nudge line per `FirstRunTutorial.STEPS` entry, `HeadmasterBeat`
   and the pick-TUGAS beat, in KBBI-standard Indonesian. Spec §4 drafts are a
   starting point, rewritten, e.g. `bikin` → `membuat`, `ngambek` → `merajuk`,
   `biar` → `agar`, `skill` → `kemampuan`, `KETUK APPROVE` → the approve
   button's own on-screen word.
2. **Send the full string table to the owner and wait for sign-off.** Nothing
   in this task is committed before that.
3. Update copy pins in `test_tutorial_panel` / `test_student_card`.

## Task 8: verify and ship

1. One full `test_run` (budget an editor restart). `git status`: revert
   `default_bus_layout.tres`; keep `kejartes_theme.tres` only if Task 1's rebake
   is in it.
2. Full-size screenshots: comic, energy step, Lobby inventory step, SchoolDay
   end page, CARA MAIN → owner.
3. `DEBT.md`: remove the 2026-10-13 mascot known gap. `CHANGELOG.md`: one
   entry for the whole pass. Delete this plan's "Not done" table rows as they land.
4. Finish with the `ship-pr` skill.

## Owner decisions this plan waits on

- Task 6: sticker and pill on non-first-run step cards.
- Task 7: final Indonesian strings.

## As built (2026-10-18, untested: no editor on this worktree)

- Tasks 1–7 are committed on this branch (Task 7 copy owner-approved 2026-10-18).
- Task 2: the chrome is the panel's `Decor` (torn edge, paperclip, name tab,
  mascot). `StepPill` stayed in the panel's `Layout`, not in the chrome.
- Task 4: `_tutorial_card_rect()` / `_tutorial_card_position()` stay, as
  thin wrappers: the position now comes from `TutorialPanel.placement()` with
  head room, and the rect includes the mascot. The old 55% floor is gone:
  the card sits on the half opposite the spot, as on the other screens.
- Task 5: the comic's `Plate` is now a `NotebookFrame`; both it and CARA
  MAIN carry the chrome as a `notebook_chrome` child of the frame.
- Task 6 (owner: yes): `nota_style` is gone; `step_sticker_text` defaults to
  "" and a new `count_steps` (off) gates the pill, so the grade 8/9 pick and
  SchoolDay's pages show no "Langkah" pill either.
- First editor pass must: rescan, restart (new `class_name`), rebake the
  theme, run `test_tutorial_panel`, `test_student_card`, `test_school_day`,
  `test_theme_factory`, `test_minigame_layout_kit`, `test_popup_frames`,
  `test_tall_screen_layout`, `test_script_documentation`, then Task 8.
