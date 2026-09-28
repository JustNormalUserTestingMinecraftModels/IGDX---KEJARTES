# Level Selection Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the shipped amplop coklat level select — de-crowd the fan, make
"Buka Map Ini" zoom the chosen envelope up onto a large thumb-friendly confirm,
add soft drop shadows — and write a week-length rebalance **proposal** for the
`Balance.gd` owner (no balance edit here).

**Architecture:** Presentation-only changes to the existing
`Scenes/LevelSelect/*` scenes and `Scripts/LevelSelect/*` scripts, plus one
markdown proposal. Reuses the existing `PaperShadow` component. No new runtime
visual construction; no `theme_override_*`; no `Balance.gd` diff.

**Tech Stack:** Godot 4.6, GDScript, `ThemeFactory` variations, Tweens,
`Scenes/UI/PaperShadow.tscn`, the `godot-ai` MCP bridge (scene/node/test tools),
`McpTestSuite` source-scan tests.

**Spec:** [`docs/superpowers/specs/2026-09-28-level-selection-polish-design.md`](../specs/2026-09-28-level-selection-polish-design.md)

**Reference screenshots (mentor review):** the two captures in the branch's PR
description — (1) the fan at rest showing the sliced side tabs, (2) the opened
confirm showing the small envelope + small surat tugas. Land Part A and B by eye
against these, and send the human a before/after.

## Global Constraints

Copied from the spec and CLAUDE.md. Every task implicitly includes these.

- **No `theme_override_*`.** Use `ThemeFactory` type variations; add one +
  rebake (`Scripts/Design/BakeTheme.gd` via Ctrl+Shift+X) if none fits.
  Layout-only constant overrides (`separation`, `margin_*`,
  `custom_minimum_size`) are the only exception.
- **No visual built at runtime.** Static chrome = `.tscn` nodes; responsive
  geometry = `@tool` script with documented `@export` knobs.
  `test_viewport_editability.gd` is a one-way ratchet — do not add to `BASELINE`.
- **Every script `@tool`**, `##` file header, `##` on every `@export`
  (`test_script_documentation.gd`).
- **`@export`s on the instance ROOT, never children** — child overrides drop on
  save (CLAUDE.md 4b). The `PaperShadow` knobs live on its instance root.
- **`Balance.gd` is read-only for us.** Weeks/target are read, never re-typed.
  Task C writes a proposal, not a `Balance.gd` edit.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` → `node_create`/`node_set_property`/`batch_execute` →
  `scene_save`. Scene work first, script work second. After patching a `.gd`,
  `filesystem_manage(op="scan")` before `test_run`; restart the editor before
  the next `scene_save` if you patched a script.
- **Verify visuals with the human.** A small editor screenshot is not proof a
  design change is done — capture at full size and send before/after; the human
  checks against reference before it's "done".
- **Indonesian** game-facing text; English systems code. **Conventional
  Commits** with scope, e.g. `feat(level-select): de-crowd the amplop fan`.
  Commit at the end of every task.

---

## Task 0: Orient (no code)

**Files:** none — read only.

- [ ] **Step 1:** Read the spec above end-to-end.
- [ ] **Step 2:** Open `Scenes/LevelSelect/LevelSelect.tscn` in the editor
      (`scene_open`). It is the main-flow screen reached from MainMenu while
      `GameState.is_level_select_enabled()`. Take a full-size `editor_screenshot`
      of the fan at rest — this is your Part A "before".
- [ ] **Step 3:** Read `Scripts/LevelSelect/LevelSelect.gd`,
      `Scripts/LevelSelect/AmplopCard.gd`, `Scripts/LevelSelect/OpenAmplopConfirm.gd`,
      and note: the fan `@export` knobs (`fan_step_x` etc.), how the confirm's
      `set_envelope_scale` / `play_open` work, and which `ThemeFactory` variations
      the confirm's Accept/Cancel buttons and letter labels use today.
- [ ] **Step 4:** Read `Scripts/UI/PaperShadow.gd` and open
      `Scenes/UI/PaperShadow.tscn` to see the two-node (root anchor + Silhouette)
      shape you will instance in Task D. Note the `match_source()` helper.
- [ ] No commit (no file changes).

---

## Task A: De-crowd the amplop fan

**Files:**
- Edit: `Scripts/LevelSelect/LevelSelect.gd` (fan `@export` defaults)
- Possibly edit: `Scenes/LevelSelect/AmplopCard.tscn` (Tab node offset, only if
  the centre tab still collides with the seal)
- Test: `tests/test_level_select.gd`

**Interfaces:** unchanged — same `@export` knobs, new default values. The layout
is driven by `_layout_cards()`, which already re-poses from these knobs in the
editor, so new defaults preview live.

- [ ] **Step 1 (test first):** In `tests/test_level_select.gd` add a source-scan
      test asserting the script still exposes `fan_step_x`, `fan_drop_y`,
      `fan_step_degrees`, `side_scale` (guards against a knob being deleted).
      This is a light guard; the real acceptance is visual.
- [ ] **Step 2:** In the editor, adjust the fan knobs toward: `fan_step_x` ≈
      210–230, `fan_drop_y` ≈ 48, `fan_step_degrees` ≈ 10–12. Tune live against
      the Task 0 "before" screenshot until each side envelope reads as a whole
      tilted card and no tab edge is sliced by another body. Persist the chosen
      values as the `@export` **defaults** in `LevelSelect.gd` (via `script_patch`
      — scene work, then script; remember the CLAUDE.md restart-before-next-save
      rule).
- [ ] **Step 3:** If the centre "KELAS N" tab still overlaps the wax seal, nudge
      the `Tab` node's authored offset in `AmplopCard.tscn` (through
      `node_set_property` → `scene_save`), not per-instance. A layout-only change.
- [ ] **Step 4:** Full-size `editor_screenshot` "after". Send before/after to the
      human. Adjust on feedback.
- [ ] **Step 5:** `filesystem_manage(op="scan")`, then
      `test_run(suite="test_level_select")`. Green.
- [ ] **Step 6:** Commit: `fix(level-select): de-crowd the amplop fan so side tabs read whole`.

---

## Task B: Zoom-in open + large mobile confirm

**Files:**
- Edit: `Scripts/LevelSelect/OpenAmplopConfirm.gd` (zoom `@export`s + open tween)
- Edit: `Scenes/LevelSelect/OpenAmplopConfirm.tscn` (bigger letter + buttons)
- Test: `tests/test_level_select.gd`

**Interfaces:**
- Produces on `OpenAmplopConfirm`: `@export var open_scale_target: float = 1.9`,
  `@export var open_zoom_sec: float = 0.35`.
- `play_open()` scales `envelope` from `card_scale` up to `open_scale_target`
  in parallel with the existing seal/flap/pupil tweens; `dismiss()` resets it.

- [ ] **Step 1 (test first):** In `tests/test_level_select.gd`, source-scan
      `OpenAmplopConfirm.gd` for `open_scale_target`, `open_zoom_sec`, and an
      `envelope`/`scale` tween in the open path. Failing now.
- [ ] **Step 2 (script):** Add the two documented `@export`s. In `play_open()`,
      tween `envelope.scale` from its current value to
      `Vector2.ONE * open_scale_target` with `TRANS_BACK`/`EASE_OUT` over
      `open_zoom_sec`, parallel to the existing open tween. Keep the
      bottom-centre pivot from `set_envelope_scale` so it rises off the letter.
      In `dismiss()`, reset `envelope.scale` to `Vector2.ONE * card scale`
      (mirror `_rest_letter()`). Patch via `script_patch`.
- [ ] **Step 3 (scene):** In `OpenAmplopConfirm.tscn`: enlarge `$Letter`
      (`custom_minimum_size`, more `Margin` padding), promote the title/body
      labels to larger `ThemeFactory` variations (no `theme_override_*`), and
      raise `$Buttons/Accept` and `$Buttons/Cancel` `custom_minimum_size.y` to a
      ≈ 96–112px tap target. Keep their existing semantic variations (Terima =
      affirmative, Batal = cancel). Do scene edits through the bridge, save.
- [ ] **Step 4:** Verify the enlarged confirm fits inside `SafeAreaMargin` on a
      20:9 phone; re-anchor the confirm to the bottom edge if it overflows
      (see `test_tall_screen_layout.gd`).
- [ ] **Step 5:** Run the game to the level select (Debug > Scenes teleport if
      available, or from MainMenu), tap Buka Map Ini, confirm the envelope surges
      toward the player and the buttons are thumb-sized. Screenshot to the human.
- [ ] **Step 6:** `scan`, `test_run(suite="test_level_select")` and
      `test_run(suite="test_tall_screen_layout")`. Green.
- [ ] **Step 7:** Commit:
      `feat(level-select): zoom the opened amplop up onto a large mobile confirm`.

---

## Task C: Week-length rebalance PROPOSAL (docs only)

**Files:**
- Create: `docs/superpowers/specs/2026-09-28-week-length-rebalance-proposal.md`

**Do NOT edit `Balance.gd`.** This is a proposal for its owner.

- [ ] **Step 1:** Write the proposal doc containing: the current
      weeks/target/rest-slack table, the proposed 0.75× cut for Grades 8 and 9
      (12→9 wk / +34→+26; 16→12 wk / +40→+30; Grade 7 untouched), the slack math
      showing felt difficulty is held, and an explicit statement that the edit is
      the collaborator's to make. Note that the level-select screen reads both
      numbers from `Balance.gd`, so it updates for free once accepted.
- [ ] **Step 2:** Confirm `git diff` shows **no** change to `Scripts/Balance.gd`.
- [ ] **Step 3:** Commit: `docs(balance): propose shorter Grade 8/9 week lengths`.

---

## Task D: Drop shadows on the amplop cards + confirm

**Files:**
- Edit: `Scenes/LevelSelect/AmplopCard.tscn` (`PaperShadow` inside `Bob`)
- Edit: `Scenes/LevelSelect/OpenAmplopConfirm.tscn` (`PaperShadow` behind `Letter`)
- Test: `tests/test_level_select.gd`

- [ ] **Step 1 (test first):** In `tests/test_level_select.gd`, source-scan the
      two `.tscn`s for a `PaperShadow` instance. Failing now.
- [ ] **Step 2 (scene, AmplopCard):** Instance `Scenes/UI/PaperShadow.tscn` as
      the **backmost child of `$Bob`** (draw order before `Body`). On its ROOT
      set `shadow_texture` = the kraft `Body` art, `shadow_size` = 400×526 (or
      enable `follow_parent_rect`), `shadow_stretch_mode` to match `Body`,
      `shadow_offset` scaled for the template's size (smaller than the 1080px
      default), `shadow_alpha` ≈ 0.33, `blur` in 2–4. Save.
- [ ] **Step 3 (scene, Confirm):** Add a `PaperShadow` behind `$Letter` in
      `OpenAmplopConfirm.tscn`, textured from the letter card. Save.
- [ ] **Step 4:** Full-size screenshot of the fan and the open confirm; confirm
      each shadow matches its element's shape, offset down-right, subtle. Send to
      the human.
- [ ] **Step 5:** `test_run(suite="test_level_select")` and
      `test_run(suite="test_paper_shadow")` — the latter must stay green (the 13
      pre-existing instances untouched; this is a 14th with its own knobs).
- [ ] **Step 6:** Commit: `feat(level-select): soft drop shadows on the amplop cards`.

---

## Task E: Finish

- [ ] **Step 1:** Targeted re-run of `test_level_select`, `test_paper_shadow`,
      `test_tall_screen_layout`. If a full `test_run` is taken, budget one editor
      restart after (CLAUDE.md), and `git checkout --` any incidental
      `kejartes_theme.tres` / `default_bus_layout.tres` rebake.
- [ ] **Step 2:** `git status` clean except intended files; **no `Balance.gd`
      diff**.
- [ ] **Step 3:** Ship with the `ship-pr` skill (runs the full suite + local
      review, opens the PR, stamps the tested commit).

## Notes for the picking-up worker

- The bridge is single-client: run the editor yourself; if you delegate code to
  a subagent, do not let it connect to the editor.
- Parts A/B/D are independent enough to do in any order, but do **scene edits
  before script edits within a task** and restart the editor between a script
  patch and the next `scene_save`.
- Part C touches no game code — safe to do first to get it out of the way.
