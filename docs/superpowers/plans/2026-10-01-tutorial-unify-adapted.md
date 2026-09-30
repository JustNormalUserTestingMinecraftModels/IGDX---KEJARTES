# Tutorial Unification + Headmaster Beat — adapted plan

> **For agentic workers:** executed with superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Source:** the collaborator's handoff, `docs/superpowers/specs/2026-09-30-tutorial-unify-and-headmaster-beat-design.md` (the spec; read the section each task names) and `docs/superpowers/plans/2026-09-30-tutorial-unify-and-headmaster-beat.md` (their 7-phase plan). This file adapts that plan to the project's rules as of 2026-10-01 and regroups it into three tasks. Where this file and theirs differ, **this file governs**.

**Goal:** one shared coach-mark (`TutorialPanel`) used by all four tutorial screens, real wrong-tap feedback instead of silent dead taps, a smaller arrow that points beside its target, and the grade 7→8 / 8→9 headmaster congratulation moved out of the tutorial into its own beat that plays on every promotion regardless of the tutorial toggle.

**Architecture:** extend `Scenes/UI/TutorialPanel.tscn` + `Scripts/UI/TutorialPanel.gd` (a `NotebookFrame` "dialog" popup) with a step pill and a name-plate mode; delete the two runtime-built panels in `AturJadwal.gd` / `StudentList.gd` and instance the shared scene instead; split the headmaster lines out of `StudentCard._populate_default_tutorial_steps()`.

## Adaptations to the collaborator's plan (why this file exists)

1. **The coach-mark stays on `NotebookFrame`.** Their Option A re-skins it as a pinned sticky note (pin, −1.4° tilt, idle sway). CLAUDE.md: popups sit in NotebookFrame, and `tests/test_popup_frames.gd` pins `TutorialPanel.tscn` as `["Frame", "dialog", "free"]`. So: **no pin, no tilt, no idle sway, no `pin.png`**. Everything else in their §3 carries over: step pill, name plate, entrance/exit springs, wrong-tap feedback, smaller offset arrow, anchoring.
2. **No runtime-built visuals** (CLAUDE.md second rule; `tests/test_viewport_editability.gd` ratchet): the step pill and name plate are authored nodes in `TutorialPanel.tscn`; `TutorialArrow` becomes an authored scene `Scenes/UI/TutorialArrow.tscn` instead of `TextureRect.new()`. Every `BASELINE` entry touched only goes **down**.
3. **No `theme_override_*`** beyond layout constants: new looks are `ThemeFactory` variations (`TutorialStepPill`, `TutorialStepPillLabel`, `TutorialNamePlate`, `TutorialNamePlateLabel`), colours from `DesignTokens`, mint = `state_success`. A display-font label joins `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`. The controller rebakes the theme; implementers do not run Godot.
4. **Glyph rule:** the name plate's school icon is a new hand-drawn SVG `Assets/Images/UI/Icons/school.svg` in token colours (no emoji, no placeholder PNG); list it in `docs/superpowers/DEBT.md`'s placeholder inventory as owner-replaceable.
5. **Suite names** are without the `test_` prefix: `tutorial_panel`, `atur_jadwal`, `student_list`, `student_card`, `school_day`, `viewport_editability`, `popup_frames`, `theme_factory`, `clean_code`, `script_documentation`, `tall_screen_layout`.
6. **Headmaster home: 5-A** (on StudentCard), the spec's recommendation.
7. **Their Phase 5** (SchoolDay "Option A knobs") shrinks to: SchoolDay's end-of-week panel hides the step pill (a single step) and stays green.
8. **Implementers never run Godot or the MCP bridge** (single client; the controller owns the editor and runs every suite). They hand-edit `.tscn` text only while the controller has closed the editor, keep every existing `unique_id`, and never touch `Assets/Theme/kejartes_theme.tres`.

## Global Constraints

- Godot 4.6 GDScript. Suites `@tool`, extend `McpTestSuite`, **no test may be a coroutine** (no `await` in tests).
- Every script: a `##` file header and a `##` line on every `@export` (`tests/test_script_documentation.gd`).
- Clean code: `docs/superpowers/design/clean-code.md`; `tests/test_clean_code.gd` counts only go down.
- Player-facing text is natural KBBI Indonesian. Code identifiers English.
- No new persistence: the headmaster flag is session-scoped on `GameState`, never saved.
- Tall phones (1080×2400): the panel anchors inside the screen's `SafeAreaMargin` → `UI` where the screen has one; no raw viewport math for its position.
- Commits: Conventional Commits, scope `tutorial`, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Step pill, name-plate mode, and the arrow as a scene

**Spec:** §3a (content only — see adaptation 1), §3b rows Entrance / Step change / Exit, §3c arrow, §4a name plate.

**Files:**
- Modify: `Scenes/UI/TutorialPanel.tscn`, `Scripts/UI/TutorialPanel.gd`, `Scripts/Design/ThemeFactory.gd`
- Create: `Scenes/UI/TutorialArrow.tscn`, `Assets/Images/UI/Icons/school.svg`
- Modify: `Scripts/TutorialArrow.gd`
- Test: `tests/test_tutorial_panel.gd`, `tests/test_theme_factory.gd`, `tests/test_viewport_editability.gd`

**Produces (later tasks rely on these exact names):**
- `enum Mode { STEP, HEADMASTER }` and `@export var mode: Mode = Mode.STEP` on `TutorialPanel` — STEP shows `StepPill`, HEADMASTER shows `NamePlate`; both live in `Frame/Margin/Layout` above `TitleLabel`.
- `func show_step(title: String, body: String, prompt: String, step: int = 0, step_count: int = 0) -> void` — existing callers keep working; `step_count <= 1` hides the pill; otherwise the pill reads `"Langkah %d / %d" % [step, step_count]`.
- `func show_beat(speaker: String, title: String, body: String, prompt: String) -> void` — switches to HEADMASTER, name plate reads `speaker`.
- `func play_in() -> void` / `func play_out() -> Tween` — the entrance/exit springs (AnimUtils/Juice), no-ops under `Engine.is_editor_hint()`.
- `Scenes/UI/TutorialArrow.tscn`: root `Control` with `TutorialArrow.gd`, an authored `Visual` TextureRect child; `@export var arrow_size: Vector2 = Vector2(180, 180)`; `set_direction(pointing_up: bool)` unchanged.

- [ ] Tests first (`tests/test_tutorial_panel.gd`): mode export exists and toggles pill/plate visibility; `show_step` with `step_count` 1 hides the pill and with 3 shows "Langkah 2 / 3"; `show_beat` shows the plate with the speaker; the new nodes carry no `theme_override_*` except layout constants; `TutorialArrow.tscn` exists, its arrow is 180×180 by default, and `TutorialArrow.gd` no longer calls `.new()` for a visual node.
- [ ] `ThemeFactory.gd`: the four variations, mint from tokens; `DISPLAY_ROSTER` updated for any display-font label.
- [ ] `school.svg`: simple school-building glyph, transparent, token colours, sized like the other `UI/Icons` glyphs.
- [ ] Scene + script edits as above; `TutorialArrow.gd`'s runtime `TextureRect.new()` removed; its `BASELINE` entry in `tests/test_viewport_editability.gd` lowered/removed.
- [ ] Callers that build the arrow (`StudentCard.gd`) instance the new scene.
- [ ] Commit.

### Task 2: AturJadwal, StudentList and the Lobby adopt the shared panel; wrong taps answer; the arrow points beside

**Spec:** §1a (the four implementations, the dead tap at `AturJadwal.gd` ~1190), §3c positioning and arrow, §3d wrong-tap feedback. Their plan Phase 3.

**Revised 2026-10-01 during execution:** the spec counted four implementations; `Scripts/Lobby/Lobby.gd` builds a fifth runtime panel (`_build_tutorial_panel`, `PanelContainer.new()`, "(n/N)" titles), so it adopts the shared panel too. And every arrow caller (StudentCard, AturJadwal, StudentList, Lobby) still clamps with a hard-coded 320×320 arrow; all four read `TutorialArrow.arrow_size` instead and place the tip beside the target (§3c).

**Consumes:** Task 1's `TutorialPanel.show_step(title, body, prompt, step, step_count)`, `play_in()`, `play_out()`, and `Scenes/UI/TutorialArrow.tscn` with `@export var arrow_size`.

**Files:**
- Modify: `Scripts/AturJadwal/AturJadwal.gd`, `Scripts/StudentList/StudentList.gd`, `Scripts/Lobby/Lobby.gd`, `Scripts/StudentCard/StudentCard.gd` (arrow math only) (and their `.tscn` only if a node must be authored there)
- Test: `tests/test_atur_jadwal.gd`, `tests/test_student_list.gd`, `tests/test_lobby.gd`, `tests/test_student_card.gd`, `tests/test_viewport_editability.gd`

- [ ] Tests first: none of AturJadwal, StudentList or Lobby contains `PanelContainer.new()` or `add_theme_stylebox_override` for the tutorial any more; all three instance `TutorialPanel.tscn`; a forced-step wrong tap calls the `error` sfx and `Juice.shake` on the correct target (source scan is the house pattern); the panel is placed inside the screen's safe area; no arrow caller hard-codes 320 for the arrow's size.
- [ ] Delete each runtime `_build_tutorial_panel()` and its label vars; instance the shared scene (mirror `StudentCard._build_tutorial_panel`); route each step through `show_step` with its step number and count (drop any "(n/N)" title prefix — the pill is the counter).
- [ ] All four arrow callers size and clamp from `arrow_size`, tip beside the target.
- [ ] Replace the silent `return` at the forced-day gate with: `AudioDirector.play_sfx(&"error")`, `Juice.shake` on the target, a brief dim of the non-targets, panel stays up. Same for StudentList's forced steps.
- [ ] Lower each touched file's `BASELINE` count by what was deleted (never raise).
- [ ] Commit.

### Task 3: The headmaster beat (5-A) and the SchoolDay check

**Spec:** §1b, §4 (all), §5 option 5-A. Their plan Phases 4 and 5.

**Consumes:** Task 1's `TutorialPanel.show_beat(speaker, title, body, prompt)`, `mode`, `play_in()`, `play_out()`.

**Files:**
- Modify: `Scripts/GameState.gd`, `Scripts/StudentCard/StudentCard.gd`, `Scripts/SchoolSimulation/SchoolDay.gd` (only if its panel needs the pill hidden explicitly)
- Test: `tests/test_student_card.gd`, `tests/test_school_day.gd`

- [ ] Tests first: the grade-8/9 congratulation strings are gone from `_populate_default_tutorial_steps()`; a `HEADMASTER_BEATS` const (keyed by grade 8 and 9) holds the §4b lines with no `"Kepala Sekolah:"` prefix; the beat trigger does not read `tutorials_bypassed`; `GameState.headmaster_beats_seen` exists, is reset with the session (`forget_session` / new run), and is never written to disk.
- [ ] `GameState.gd`: documented session-scoped `headmaster_beats_seen: Dictionary` (grade → true), cleared where the session is cleared.
- [ ] `StudentCard.gd`: remove the grade-8/9 branches; keep the grade-7 teaching steps and the single "pilih N murid" instruction step (tutorial-gated); add `_maybe_play_headmaster_beat()` from `_ready()` that, when `current_grade` is 8 or 9 and not yet seen, shows the panel via `show_beat("Pak Kepala Sekolah", …)` for each of that grade's lines in order (tap to advance), independent of `tutorials_bypassed`, reusing the tutorial CanvasLayer, then marks the grade seen.
- [ ] SchoolDay's end-of-week panel: one step, so the pill stays hidden; keep `school_day` green.
- [ ] Commit.
