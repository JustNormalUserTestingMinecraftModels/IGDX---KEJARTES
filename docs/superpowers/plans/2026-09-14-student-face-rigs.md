# Student Face Rigs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Andi, Doni, Marcel, Shinta and Thea a layered, gazing `StudentFace` rig in the Lobby, like Citra's, with every layer placed where their current flat sprite has it.

**Architecture:** Five new rig scenes, structurally copies of `Scenes/Lobby/CitraFace.tscn`, each with a per-student eye-mask material. Marcel adds a `Glasses` layer drawn through a new premultiplied-alpha lens shader. The layer offsets were solved offline against each `MuridPotrait/<Name>.png` by a scratch Python solver, and they are frozen in a new `face_rig_roster` suite. `loby.tscn`'s `face_rigs` export lists all six rigs. `StudentFace.gd` gets documentation only.

**Tech Stack:** Godot 4.6 (GDScript, `.tscn`/`.tres` text, canvas_item shader), Godot AI MCP bridge (`test_run`, `scene_open`, `node_set_property`, `scene_save`, `filesystem_manage`), Python 3.14 + numpy/PIL/scipy for the offline solve (scratchpad only, never committed).

Spec: `docs/superpowers/specs/2026-09-14-student-face-rigs-design.md`.

## Global Constraints

- Branch `feat/student-face-rigs` in the main checkout; check `git branch --show-current` before every commit (another session can switch it).
- Art names are `<name>_<layer>.png`, lowercase student first, in `Assets/Images/MuridPotrait/<Name>/`, matching Citra's real files.
- The layer roles come from the art, not from the Drive numbers. Files 4 and 5 are eyelid and eyelashes for all five students, and 2/3 are pupil/sclera for all but Andi. The staged files in the scratchpad already carry the corrected names.
- Sclera and Eyelid positions are the eye-hole plug solutions and must never be nudged.
- The new face `.tscn` files are written as text and **never opened and saved in the editor**. `StudentFace` is `@tool`, and its `fit_canvas()` would bake a Canvas scale/position into the file.
- `loby.tscn` is changed only through the editor (`scene_open` → `node_set_property` → `scene_save`), never by hand. Scene work comes before script work; after `scene_save`, run `git diff HEAD -- '*.gd'` for stale-tab writes.
- No `theme_override_*`, no runtime visual construction, `Balance.gd` untouched.
- Commits: Conventional Commits with scope `face-rigs`. Write the message to a BOM-free file and `git commit -F` it, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Stage by name, never the untracked `addons/godot_ai/utils/update_activation_runner.gd*`.

Scratchpad (`SP`):
`C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project/98e660b2-3f7c-42d1-9045-90a9dc779bde/scratchpad`.
It holds `art/<Name>/` (the 31 renamed PNGs), `<name>.json` (the solves), `solve_rig.py`, `gen_scenes.py`, and `draft/` (`glasses_lens.gdshader`, `test_face_rig_roster.gd` with placeholders).

---

### Task 1: The five rigs, their art, and the roster suite

**Files:**
- Create: `tests/test_face_rig_roster.gd` (from `SP/draft/test_face_rig_roster.gd`, filled by `gen_scenes.py`)
- Create: `Assets/Images/MuridPotrait/{Andi,Doni,Marcel,Shinta,Thea}/<name>_{base,sclera,pupil,eyelashes,eyelid,eyebrows}.png`, plus `marcel_glasses.png`, and their `.import` files
- Create: `Scenes/Lobby/{Andi,Doni,Marcel,Shinta,Thea}Face.tscn`
- Create: `Scenes/Lobby/{andi,doni,marcel,shinta,thea}_eye_mask.tres`, `Scenes/Lobby/marcel_glasses_lens.tres`
- Create: `Scripts/Shaders/glasses_lens.gdshader` (from `SP/draft/glasses_lens.gdshader`)

**Interfaces:**
- Consumes: `StudentFace` (`Scripts/Lobby/StudentFace.gd`): `student_name` export, a `Canvas` child holding `TextureRect` layers named `Base, Sclera, Pupil, Eyelashes, Eyelid, Eyebrows`; `eye_mask.gdshader` uniforms `mask_texture`, `mask_uv_offset`, `mask_uv_scale`, `mask_softness`.
- Produces: rig scenes at `res://Scenes/Lobby/<Name>Face.tscn` whose root `student_name` is `<Name>`; Marcel's extra `Canvas/Glasses` using `glasses_lens.gdshader` (uniforms `lens_gain`, `frame_alpha_from`). Task 2 lists these paths in `loby.tscn`.

- [ ] **Step 1: Generate scenes, materials and the filled suite**

```bash
python "$SP/gen_scenes.py" "$SP" "$SP/gen"
```
Expected: `generated [...] see-through {...} lens gain 1.1xx`. `SP/gen/` holds `Scenes/Lobby/*Face.tscn`, `*_eye_mask.tres`, `marcel_glasses_lens.tres`, `geometry.gd.txt` and `tests/test_face_rig_roster.gd`, with no `__` placeholder left (`grep -c __ "$SP/gen/tests/test_face_rig_roster.gd"` → 0).

- [ ] **Step 2: Add the suite first and watch it fail**

Copy `SP/gen/tests/test_face_rig_roster.gd` to `tests/`, then `filesystem_manage(op="scan")`.

Run: `test_run(suite="face_rig_roster")`
Expected: FAIL. Every test that loads a rig errors on the missing `res://Scenes/Lobby/<Name>Face.tscn`, and `test_every_roster_student_has_a_face_rig` still passes.

- [ ] **Step 3: Drop in the art, the shader, the scenes and the materials**

```bash
for n in Andi Doni Marcel Shinta Thea; do mkdir -p "Assets/Images/MuridPotrait/$n"; cp "$SP/art/$n/"*.png "Assets/Images/MuridPotrait/$n/"; done
cp "$SP/draft/glasses_lens.gdshader" Scripts/Shaders/
cp "$SP/gen/Scenes/Lobby/"* Scenes/Lobby/
```
Then `filesystem_manage(op="scan")` so Godot imports the PNGs. Check that each new `.import` matches Citra's (`compress/mode=0`, `mipmaps/generate=false`):
`grep -L "compress/mode=0" Assets/Images/MuridPotrait/{Andi,Doni,Marcel,Shinta,Thea}/*.import` → prints nothing.

- [ ] **Step 4: Run the suite**

Run: `test_run(suite="face_rig_roster")`
Expected: every test passes except `test_the_lobby_lists_every_rig`, which fails on `loby.tscn's face_rigs must list res://Scenes/Lobby/AndiFace.tscn`. Task 2 fixes that. Also run `test_run(suite="student_face")` and expect PASS; Citra is untouched.

If `test_no_eye_cut_out_is_left_see_through` reports a count above its budget, the test's scan disagrees with the solver's measurement. Print the count, compare it with `holes_open` in `SP/<name>.json`, and fix whichever is wrong. Never raise the budget blindly.

- [ ] **Step 5: Commit**

```bash
git add tests/test_face_rig_roster.gd Scripts/Shaders/glasses_lens.gdshader Scenes/Lobby/*Face.tscn Scenes/Lobby/*_eye_mask.tres Scenes/Lobby/marcel_glasses_lens.tres Assets/Images/MuridPotrait/{Andi,Doni,Marcel,Shinta,Thea}
git commit -F <msgfile>   # feat(face-rigs): layered faces for Andi, Doni, Marcel, Shinta and Thea
```
Also add any `.uid` files the scan created next to the new shader and scenes (`git status --porcelain` shows them).

### Task 2: The Lobby lists all six rigs

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (root node's `face_rigs` export; the editor adds the ext_resources)

**Interfaces:**
- Consumes: Task 1's rig paths and `res://Scenes/Lobby/CitraFace.tscn`.
- Produces: `face_rigs` saved on `loby.tscn`'s root, which `test_the_lobby_lists_every_rig` reads back through `PackedScene.get_state()`.

- [ ] **Step 1: Confirm the failing test** (Task 1 Step 4 left `test_the_lobby_lists_every_rig` red).

- [ ] **Step 2: Set the export through the editor**

`scene_open("res://Scenes/Lobby/loby.tscn")`, then `scene_get_hierarchy(depth=1)` to get the root's path (the root node is named `TutorialOverlay`), then:
```
node_set_property(path="<root path>", property="face_rigs", value=[
  "res://Scenes/Lobby/CitraFace.tscn", "res://Scenes/Lobby/AndiFace.tscn",
  "res://Scenes/Lobby/DoniFace.tscn", "res://Scenes/Lobby/MarcelFace.tscn",
  "res://Scenes/Lobby/ShintaFace.tscn", "res://Scenes/Lobby/TheaFace.tscn"])
```
Read it back with `node_get_properties(fields=["face_rigs"])`: six PackedScenes. If the tool cannot coerce a string list into `Array[PackedScene]`, try `batch_execute` `set_property` with the same value. If that fails too, **stop and report**; do not hand-edit `loby.tscn`.

- [ ] **Step 3: Save and inspect**

`scene_save()`, then:
```bash
git diff HEAD --stat -- '*.gd'          # must be empty (no stale-tab write-back)
git diff HEAD -- Scenes/Lobby/loby.tscn # only: 5-6 new ext_resource lines + one face_rigs line
```
Anything else in the diff, such as editor churn on unrelated nodes, gets reverted with `git checkout -- <file>` and the step is redone.

- [ ] **Step 4: Run the suites**

Run: `test_run(suite="face_rig_roster")` → PASS (all). `test_run(suite="student_face")` → PASS.

- [ ] **Step 5: Commit** — `feat(face-rigs): the lobby seats every student's layered face`.

### Task 3: Docs — StudentFace header, spec findings, debt, changelog

**Files:**
- Modify: `Scripts/Lobby/StudentFace.gd:8-19` (header), via `script_patch`
- Modify: `docs/superpowers/specs/2026-09-14-student-face-rigs-design.md` (as-built findings)
- Modify: `docs/superpowers/DEBT.md:234-241`
- Modify: `docs/superpowers/CHANGELOG.md` (new top entry)

- [ ] **Step 1: StudentFace header** — `script_patch` on `res://Scripts/Lobby/StudentFace.gd`:

old:
```
## The art is authored on a fixed square canvas (1280x1280 for Citra) and every
```
new:
```
## The art is authored on a fixed square canvas (1280x1280 for every student so
## far) and every
```
and old:
```
## pose and is the one layer that starts hidden.
```
new:
```
## pose and is the one layer that starts hidden. A rig may carry extra
## always-visible layers of its own after these -- Marcel's Glasses, drawn
## through Scripts/Shaders/glasses_lens.gdshader -- which this script never
## touches: they simply draw, and breathe with the rest.
```
Run: `test_run(suite="script_documentation")` → PASS.

- [ ] **Step 2: Spec as built.** Append an `## As built` section to the spec. It records: the corrected Drive numbering; Shinta's darker portrait grade and her one visible eye; Marcel's additive lens (the fitted gain, the new shader and material, and that the Brief's file list lacked them); the see-through budgets (Doni, Marcel); and Andi's shorter eye opening, which tucks the top of his iris under the lash.

- [ ] **Step 3: DEBT.md.** Delete the `**Layered faces exist for Citra only.**` paragraph. In the blink paragraph, replace `` `CitraFace.tscn`'s `Eyelid` layer`` with `` every face rig's `Eyelid` layer``.

- [ ] **Step 4: CHANGELOG.md.** Add a `## 2026-09-14 — Lobby: layered faces for the whole roster` entry above the lobby-style-buttons one: plan and spec paths, what was built, the solve method in one paragraph, the numbering correction, Marcel's lens, and the Citra rim bug that was found and handed off as a separate task.

- [ ] **Step 5: Commit** — `docs(face-rigs): as-built notes, debt and changelog`.

### Task 4: See it in the running game

**Files:** none (verification only).

- [ ] **Step 1:** `project_run`, wait for `game_capture_ready`, then Debug overlay → General → **⚡ Seed Playtest State**. That seeds Marcel, Doni, Andi and Citra.
- [ ] **Step 2:** Swap Shinta and Thea in with one `game_eval`. Instance `res://Scripts/StudentList/student_list.gd`, take its `default_students` entries for Shinta and Thea, replace Doni and Citra in `GameState.approved_students`, free the instance, and change scene to `res://Scenes/Lobby/loby.tscn`.
- [ ] **Step 3:** In one `game_eval`, once the Lobby is up, set `Engine.time_scale = 0.02` and capture `editor_screenshot(source="game", max_resolution=0)`. Judge each face at full size against its `MuridPotrait/<Name>.png`: eyes aligned, no background showing through the eye whites, lashes on the lids, and Marcel's lenses glowing pink with dark frames. Then restore `Engine.time_scale = 1`.
- [ ] **Step 4:** Repeat Steps 2–3 with the seeded four (Marcel, Doni, Andi, Citra) to see Doni.
- [ ] **Step 5:** `project_manage(op="stop")`. If Marcel's glasses render wrong (a white frame, or no glow), Godot premultiplies differently from the shader's assumption: adjust `glasses_lens.gdshader` and re-verify.

### Task 5: Full suite

- [ ] **Step 1:** `scene_open("res://Scenes/MainMenu/main_menu.tscn")`, then `test_run()` (full). Expected: all suites pass, with the counts one suite and ten tests up on CLAUDE.md's "107 suites, 1508 tests".
- [ ] **Step 2:** `git status --porcelain`. Revert the full run's rebake of `Assets/Theme/kejartes_theme.tres` and `default_bus_layout.tres` with `git checkout --` if they changed.
- [ ] **Step 3:** Update CLAUDE.md's suite/test count line to the new totals and date, then commit `docs(face-rigs): suite count`.
- [ ] **Step 4:** Restart the editor (the full run drops the bridge; see the godot-editor-restarts memory for the detached launch).
