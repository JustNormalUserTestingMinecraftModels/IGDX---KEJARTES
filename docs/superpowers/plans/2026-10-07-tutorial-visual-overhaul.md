# First-Day Tutorial Visual Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 14-card Grade-7 text tutorial with a show-and-do overlay flow, give every tutorial one voice (the "Nota Guru" headmaster box), add an idle nudge layer, and fix the coach-note / pop-up overlap — reusing the shipped `TutorialPanel` machinery, no new scenes except the comic cold-open.

**Architecture:** The shipped `TutorialPanel` (spotlight hole, arrow, wrong-tap, step change) stays the engine; this swaps its skin to a `NotebookFrame`-variant torn-note box, adds a typewriter + idle layer, and changes the *content* each screen rides on it. Grade-7 first-run gets a deep redesign (comic cold-open + tap-to-learn spotlights + learn-by-doing in AturJadwal); every other tutorial screen (Lobby, StudentList, SchoolDay) and the `HeadmasterBeat` transition adopt the shared look only.

**Tech Stack:** Godot 4.6, GDScript, `@tool` editor-bridge test suites (`McpTestSuite`), `DesignTokens`/`ThemeFactory` theme, `Juice`/`AnimUtils` animation.

**Spec:** `docs/superpowers/specs/2026-10-07-tutorial-visual-overhaul-design.md` (read it; this plan argues from it). Interactive reference: `docs/superpowers/mockups/tutorial-handoff.html`.

## Global Constraints

- **ASK BEFORE ANY NEW TWEAK.** Structure, copy, motion, box design and scope were set with the owner (a relayed reviewer's direction — memory `design-direction-comes-from-a-mentor`). Do not improvise visuals, rewrite the Indonesian, add/remove beats, or re-scope. Grammar fixes are fine; design/scope changes must be confirmed with the owner first. Spec §0.1 and §10.
- **ALL ART IS PLACEHOLDER — REAL ASSETS MUST BE MADE.** Ship drop-replaceable placeholder SVGs at stable paths and log every one in `docs/superpowers/DEBT.md` under one "tutorial art" group. No emoji as iconography — drawn transparent SVG only. Spec §0.2, §7. (Task 8 owns the DEBT entry; every task that adds a placeholder updates it.)
- **No `theme_override_*`** — use a `ThemeFactory` type variation; layout-only constant overrides (`separation`, `margin_*`) allowed. Rebake via `Scripts/Design/BakeTheme.gd` after token edits.
- **No visual built at runtime** — static chrome is a node in the `.tscn`; `tests/test_viewport_editability.gd` BASELINE only ever drops.
- **No new persistence** beyond existing session flags (`GameState.headmaster_beats_seen`, tutorial-seen `static var`).
- **Player-facing text is Indonesian (KBBI, natural); systems code English.** Commits: Conventional Commits with scope, e.g. `feat(tutorial): ...`.
- **Tests run inside the editor** via the Godot AI MCP `test_run` tool (never headless). Suites are `@tool`, no `await`. Rescan after editing a `.gd` before running. Open `Scenes/MainMenu/MainMenu.tscn` before trusting a failure.
- **Touch-first, no hover** — every cue fires on tap or an inactivity timer; targets ≥ 44 px; never pointer-enter.

---

## File Structure

- `Scripts/UI/TutorialPanel.gd` + `Scenes/UI/TutorialPanel.tscn` — the shared box: Nota Guru skin, typewriter, ribbon modes, idle hooks, the focal-box tuck/return. (Extend, do not fork.)
- `Scripts/Design/ThemeFactory.gd` — a `NotebookFrameNota` variation if the torn-note needs its own StyleBox/tokens (rebake after).
- `Scenes/UI/TutorialComic.tscn` + `Scripts/UI/TutorialComic.gd` — the Grade-7 cold-open overlay (static chrome).
- `Scripts/StudentCard/StudentCard.gd` — replace the grade-7 14-step table with the comic + spotlight beats; keep grade-8/9 via `HeadmasterBeat`.
- `Scripts/StudentCard/HeadmasterBeat.gd` — re-skin only.
- `Scripts/AturJadwal/AturJadwal.gd` — learn-by-doing gate on the first assignment.
- `Scripts/Lobby/Lobby.gd`, `Scripts/StudentList/StudentList.gd`, `Scripts/SchoolSimulation/SchoolDay.gd` — adopt the Nota Guru box + shared rules (re-skin only).
- `Scripts/UI/TutorialIdle.gd` (new, small) — the resting-loop + escalation-nudge helper, so the timer logic lives in one focused place.
- Tests: `tests/test_tutorial_panel.gd`, `tests/test_student_card.gd`, `tests/test_atur_jadwal.gd`, `tests/test_viewport_editability.gd`, plus a new `tests/test_tutorial_idle.gd`.
- `docs/superpowers/DEBT.md` — the tutorial-art placeholder group.
- Placeholder art under `Assets/Images/UI/Placeholders/tutorial/`.

Phases are ordered so each produces a testable deliverable and later phases build on earlier ones. Phase 1 (box) and Phase 3 (idle) are the shared foundation; Phases 4–5 are the deep first-run; Phase 6 is the transition re-skin; Phase 7 is adoption; Phase 8 closes the asset debt.

---

## Phase 1 — The Nota Guru box

### Task 1: Ribbon mode + typewriter on TutorialPanel

**Files:**
- Modify: `Scripts/UI/TutorialPanel.gd`
- Modify: `Scenes/UI/TutorialPanel.tscn` (via editor bridge: add the ribbon node + name-tab/paperclip placeholders)
- Test: `tests/test_tutorial_panel.gd`

**Interfaces:**
- Consumes: existing `show_step()`, `show_beat()`, `Mode.STEP|HEADMASTER`, `step_sticker_text`/`beat_sticker_text`.
- Produces: `type_line(text: String) -> void` (typewriter reveal of the body), `skip_typing() -> void` (fill instantly), `is_typing() -> bool`, and a third sticker value `TUGAS` for the pick instruction (new `task_sticker_text` export, default `"TUGAS"`).

- [ ] **Step 1: Write the failing test** — add to `tests/test_tutorial_panel.gd`:

```gdscript
func test_panel_exposes_typewriter_and_task_sticker() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/UI/TutorialPanel.gd")
    assert_true(src.contains("func type_line("), "type_line() must exist")
    assert_true(src.contains("func skip_typing("), "skip_typing() must exist")
    assert_true(src.contains("func is_typing("), "is_typing() must exist")
    assert_true(src.contains("task_sticker_text"), "TUGAS ribbon mode must exist")
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_tutorial_panel")`. Expected: FAIL (methods absent). Rescan first if edited outside the editor.
- [ ] **Step 3: Implement** — add the three methods and the export. `type_line` drives a per-char reveal with a `Timer`/tween on the body label at ~30 ms/char (knob: `const TYPE_INTERVAL := 0.03`); it respects `GameSettings.skip_event_dialogue` by filling instantly when set. `skip_typing` fills `body_label.text` to the full line and stops the reveal. Keep all existing behaviour; the typewriter replaces the direct body assignment inside `show_step`/`show_beat` only when not instant. Document each new `@export`/method with a `##` line (`tests/test_script_documentation.gd`).
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_tutorial_panel")`. Expected: PASS. Also `test_run(suite="test_script_documentation")`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): typewriter reveal and TUGAS ribbon on TutorialPanel"`

### Task 2: Nota Guru skin (NotebookFrame variant)

**Files:**
- Modify: `Scenes/UI/TutorialPanel.tscn` (editor bridge), `Scripts/Design/ThemeFactory.gd`
- Test: `tests/test_tutorial_panel.gd`, `tests/test_popup_frames.gd`

**Interfaces:**
- Produces: the torn-note look as a frame variation; placeholder nodes `Paperclip` and `NameTab` on the panel scene, driven by `@export var speaker_name: String`.

- [ ] **Step 1: Write the failing test**:

```gdscript
func test_nota_guru_nodes_present() -> void:
    var scene := load("res://Scenes/UI/TutorialPanel.tscn")
    var inst := scene.instantiate()
    assert_not_null(inst.find_child("NameTab", true, false), "name tab node required")
    assert_not_null(inst.find_child("Paperclip", true, false), "paperclip placeholder required")
    inst.free()
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_tutorial_panel")`. Expected: FAIL.
- [ ] **Step 3: Implement** — via the editor bridge (`scene_open` → `node_create` → `node_set_property` → `scene_save`; never hand-edit the `.tscn` while attached): add `NameTab` (a `Label` on a mint/gold pill reading `speaker_name`) and `Paperclip` (`TextureRect`, placeholder SVG at `Assets/Images/UI/Placeholders/tutorial/paperclip.svg`). If the torn-note surface needs its own StyleBox, add a `NotebookFrameNota` variation in `ThemeFactory.gd` and rebake (`BakeTheme.gd` via Ctrl+Shift+X). Colours from `DesignTokens` only. Restart the editor after script edits before the next `scene_save` (CLAUDE.md save hazards).
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_tutorial_panel")` then `test_run(suite="test_popup_frames")`. Expected: PASS (the panel still satisfies the frame roster). Check `git status` for an unintended `kejartes_theme.tres` rebake and keep only the intended one.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): Nota Guru torn-note skin for the coach box"`

---

## Phase 2 — One focal box (overlap fix)

### Task 3: Note tuck / return around game pop-ups

**Files:**
- Modify: `Scripts/UI/TutorialPanel.gd`
- Test: `tests/test_tutorial_panel.gd`

**Interfaces:**
- Produces: `tuck(hidden: bool) -> void` (slide the card down + fade when true, restore when false) and a `below_popups` z-ordering contract (the panel's CanvasLayer/`z_index` sits under game pop-ups).

- [ ] **Step 1: Write the failing test**:

```gdscript
func test_panel_has_tuck_and_sits_below_popups() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/UI/TutorialPanel.gd")
    assert_true(src.contains("func tuck("), "tuck() must exist for the focal-box handoff")
    assert_true(src.to_lower().contains("below") or src.contains("z_index"),
        "panel must document sitting below game popups")
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_tutorial_panel")`. Expected: FAIL.
- [ ] **Step 3: Implement** — `tuck(true)` runs a slide-down + fade (reuse `AnimUtils.popup_spring_out`-style or a short tween on `position.y`/`modulate.a`); `tuck(false)` restores with a spring. Document the z-order rule (coach layer below pop-ups) in the file header. The StudentCard trait step (Task 6) calls `tuck(true)` before opening `TraitDetailPopup` and `tuck(false)` on its close.
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_tutorial_panel")`. Expected: PASS.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): coach note tucks away for game popups (one focal box)"`

---

## Phase 3 — Idle layer (touch-first)

### Task 4: TutorialIdle helper — resting loops + escalation nudge

**Files:**
- Create: `Scripts/UI/TutorialIdle.gd`
- Test: `tests/test_tutorial_idle.gd` (new)

**Interfaces:**
- Produces: `class_name TutorialIdle`; `@export var idle_nudge_seconds: float = 2.5`; `start(target: Control, cues: Array) -> void`, `reset() -> void`, `pause() -> void`, `resume() -> void`. On `idle_nudge_seconds` elapsed with no `reset()`, it plays the escalation (hand slide-in, target wiggle via `Juice.shake`-style loop, ring intensify) once; any `reset()` restores rest.

- [ ] **Step 1: Write the failing test** (`tests/test_tutorial_idle.gd`, `@tool`, extends `McpTestSuite`):

```gdscript
func test_idle_defaults_and_touch_only() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/UI/TutorialIdle.gd")
    assert_true(src.contains("idle_nudge_seconds: float = 2.5"), "default 2.5s")
    assert_false(src.to_lower().contains("mouse_entered"), "no hover triggers (touch-first)")
    assert_true(src.contains("func reset(") and src.contains("func pause("),
        "reset() and pause() required")
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_tutorial_idle")`. Expected: FAIL (file absent). Register the new suite (rescan).
- [ ] **Step 3: Implement** — a `Node`/`RefCounted` that owns a `SceneTreeTimer`-driven countdown; `reset()` on any input restarts it; at timeout it plays one escalation level and holds; `pause()`/`resume()` for when a pop-up/comic/beat is up. Resting loops (sway, breathe, ring) are looped tweens started by `start()`. No `mouse_entered`/hover.
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_tutorial_idle")`. Expected: PASS.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): idle resting loops and 2.5s escalation nudge (touch-first)"`

---

## Phase 4 — Grade-7 first-run: comic + spotlights

### Task 5: Comic cold-open overlay scene

**Files:**
- Create: `Scenes/UI/TutorialComic.tscn`, `Scripts/UI/TutorialComic.gd`
- Modify: `docs/superpowers/DEBT.md`
- Test: `tests/test_viewport_editability.gd`, new assertions in `tests/test_student_card.gd`

**Interfaces:**
- Produces: `class_name TutorialComic`; `play(panels: Array[Dictionary]) -> void`, `signal finished`. Static chrome authored in the `.tscn`; panels fed as data (illustration path + rich-text line). Advances on tap-anywhere with the `KETUK DI MANA SAJA UNTUK LANJUT` prompt.

- [ ] **Step 1: Write the failing test** — in `tests/test_student_card.gd`:

```gdscript
func test_comic_scene_exists_and_is_authored() -> void:
    assert_true(ResourceLoader.exists("res://Scenes/UI/TutorialComic.tscn"),
        "comic cold-open scene must exist")
    var src := FileAccess.get_file_as_string("res://Scripts/UI/TutorialComic.gd")
    assert_true(src.contains("signal finished"), "comic must emit finished")
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_student_card")`. Expected: FAIL.
- [ ] **Step 3: Implement** — author the overlay in the editor (full-dim scrim + centered plate with illustration `TextureRect`, `RichTextLabel` line, target-mark row, blinking prompt — all nodes in the `.tscn`, none built at runtime). Three placeholder plate SVGs under `Assets/Images/UI/Placeholders/tutorial/comic/`; log them in `DEBT.md`. Copy verbatim from spec §4 beat 1.
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_student_card")` then `test_run(suite="test_viewport_editability")` (BASELINE must not rise). Expected: PASS.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): comic cold-open overlay scene for Grade-7 goal"`

### Task 6: Replace the 14-step table with the first-run beats

**Files:**
- Modify: `Scripts/StudentCard/StudentCard.gd`
- Test: `tests/test_student_card.gd`

**Interfaces:**
- Consumes: `TutorialComic.play`, `TutorialPanel.type_line`/`tuck`, `TutorialIdle`, existing `place_step`/spotlight helpers, `TraitDetailPopup`.
- Produces: a grade-7 flow that = comic (Task 5) → Mood/Energi/Skill spotlights (traveling note) → trait hand-off (tuck → popup → return) → hand to AturJadwal; grade-8/9 still routes through `HeadmasterBeat`.

- [ ] **Step 1: Write the failing test**:

```gdscript
func test_grade7_textwall_removed_and_beats_present() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/StudentCard.gd")
    assert_false(src.contains("Ini adalah bar Mood murid"),
        "old 14-step wall copy must be gone")
    assert_true(src.contains("TutorialComic") or src.contains("tutorial_comic"),
        "comic cold-open must be wired")
    assert_true(src.contains("tuck("), "trait hand-off must tuck the note")
    assert_true(src.contains("HeadmasterBeat"), "grade 8/9 still routes via HeadmasterBeat")
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_student_card")`. Expected: FAIL.
- [ ] **Step 3: Implement** — rewrite `_populate_default_tutorial_steps` / the grade-7 flow to drive the comic then the three spotlight beats with the spec §4 copy; on the Sifat beat call `tuck(true)` → open `TraitDetailPopup` → on close `tuck(false)` and show the follow-up line. Keep the `elif HeadmasterBeat.PICK_STEPS.has(...)` routing. Hand off to AturJadwal's learn-by-doing (Task 7) at the end. Respect `tutorials_bypassed` for the lesson beats.
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_student_card")`. Expected: PASS. Open `MainMenu.tscn` and seed + teleport (Debug ⚡ Seed, Scenes tab) to eyeball the flow once at full size; screenshot for the owner.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): replace Grade-7 text wall with show-and-do beats"`

---

## Phase 5 — Learn-by-doing (AturJadwal)

### Task 7: Gate + spotlight the first assignment

**Files:**
- Modify: `Scripts/AturJadwal/AturJadwal.gd`
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `TutorialPanel` (Nota Guru), `TutorialIdle`, the existing per-activity stat-preview/bar logic.
- Produces: a first-run-only gated beat — spotlight the activity choice for one day; on pick, the real bars animate the consequence (`Juice.fill_bar` + `AnimUtils.create_floating_text` + `Juice.count_up`), then the note shows the trade-off line (spec §4 beat 4, both branches) and advances on tap.

- [ ] **Step 1: Write the failing test**:

```gdscript
func test_first_assignment_learn_by_doing_gate() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/AturJadwal.gd")
    assert_true(src.contains("create_floating_text"), "floating delta on the taught pick")
    assert_true(src.contains("Di situ serunya") or src.contains("Pintar-pintar"),
        "trade-off teaching line present (spec copy)")
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_atur_jadwal")`. Expected: FAIL.
- [ ] **Step 3: Implement** — detect the first-run tutorial state; spotlight the day's activity buttons via the shared helper; on the player's pick run the existing stat math + the floating deltas and count-up, then show the matching spec line. Wrong-tap on a dimmed control uses `answer_wrong_tap`. Idle nudge armed via `TutorialIdle`, paused during the bar animation.
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_atur_jadwal")`. Expected: PASS. (Seed does not fill `day_schedules`; make one pass through Atur Jadwal to eyeball.)
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): learn-by-doing first-assignment beat in AturJadwal"`

---

## Phase 6 — Grade-transition re-skin

### Task 8: HeadmasterBeat on the Nota Guru box

**Files:**
- Modify: `Scripts/StudentCard/HeadmasterBeat.gd` (re-skin wiring only), `Scripts/StudentCard/StudentCard.gd` (box styling on the beat)
- Test: `tests/test_student_card.gd`

**Interfaces:**
- Consumes: `TutorialPanel` Nota Guru skin (name-plate mode), `type_line`.
- Produces: no content change — `HEADMASTER_BEATS`/`PICK_STEPS` unchanged; only the box look + typewriter + `PENGUMUMAN`/`TUGAS` ribbons applied, and the gating preserved.

- [ ] **Step 1: Write the failing test**:

```gdscript
func test_transition_gating_preserved() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/HeadmasterBeat.gd")
    assert_false(src.contains("tutorials_bypassed"),
        "story beats must NOT read the tutorial toggle")
    assert_true(src.contains("HEADMASTER_BEATS") and src.contains("PICK_STEPS"),
        "transition content unchanged")
```

- [ ] **Step 2: Run to verify it fails** — if the assertions already pass (content untouched), this task is a styling-only no-op on logic; still add the test to lock the gating. Run `test_run(suite="test_student_card")`.
- [ ] **Step 3: Implement** — ensure the beat renders in the Nota Guru box with the `PENGUMUMAN` ribbon for story cards and `TUGAS` for the pick step; the pick step continues to respect `tutorials_bypassed` while the story beats do not (`is_due`). No copy edits.
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_student_card")`. Expected: PASS. Rehearse via Debug → Scenes → 🎭 Gladi Resik Akhir Kelas.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "refactor(tutorial): re-skin grade-transition beats to the Nota Guru box"`

---

## Phase 7 — Shared adoption (Lobby, StudentList, SchoolDay)

### Task 9: Re-skin the remaining tutorial callers

**Files:**
- Modify: `Scripts/Lobby/Lobby.gd`, `Scripts/StudentList/StudentList.gd`, `Scripts/SchoolSimulation/SchoolDay.gd`
- Test: `tests/test_lobby.gd`, `tests/test_student_list.gd`, `tests/test_school_day.gd`

**Interfaces:**
- Consumes: the shared Nota Guru `TutorialPanel`, tap-anywhere prompt, `TutorialIdle`, one-focal-box rule.
- Produces: each screen's existing tutorial **content** unchanged, rendered in the shared box with shared behaviour.

- [ ] **Step 1: Write the failing test** — one per suite, e.g. in `tests/test_lobby.gd`:

```gdscript
func test_lobby_tutorial_uses_shared_box() -> void:
    var src := FileAccess.get_file_as_string("res://Scripts/Lobby/Lobby.gd")
    assert_true(src.contains("TutorialPanel"), "Lobby tutorial uses the shared panel")
    assert_false(src.contains("PanelContainer.new()"),
        "no runtime-built tutorial panel")
```

- [ ] **Step 2: Run to verify it fails** — `test_run(suite="test_lobby")` (and the other two). Expected: FAIL where a screen still builds its own.
- [ ] **Step 3: Implement** — point each caller at the shared Nota Guru panel + prompt + idle; keep their teaching lines verbatim. Delete any remaining runtime-built panels (lower `test_viewport_editability` BASELINE, never raise).
- [ ] **Step 4: Run to verify it passes** — `test_run(suite="test_lobby")`, `test_run(suite="test_student_list")`, `test_run(suite="test_school_day")`, `test_run(suite="test_viewport_editability")`. Expected: PASS.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(tutorial): adopt the shared Nota Guru box on Lobby, StudentList, SchoolDay"`

---

## Phase 8 — Close the asset debt

### Task 10: DEBT.md tutorial-art group + placeholder audit

**Files:**
- Modify: `docs/superpowers/DEBT.md`
- Test: manual checklist (no suite)

- [ ] **Step 1** — add a single "Tutorial art (placeholder)" group to `DEBT.md` listing every placeholder path from §7 (mascot + expressions, Nota Guru paper/paperclip/name tab, pointing hand, 3 comic plates, ✓/✕/★ marks), each marked drop-replaceable at a stable path, no emoji.
- [ ] **Step 2** — grep the repo to confirm every placeholder referenced by the new scenes/scripts exists at its path and nothing references an emoji glyph as iconography.
- [ ] **Step 3: Commit** — `git add -A && git commit -m "docs(tutorial): log tutorial placeholder art in DEBT.md"`

---

## Self-review notes (gaps to watch during execution)

- **Spec coverage:** §3 box → Tasks 1–3; §3e idle → Task 4; §4 first-run → Tasks 5–7; §5 transition → Task 8; §6 shared adoption → Task 9; §7 assets → Tasks 5/8. All spec sections map to a task.
- **Ask-before-tweak** is a Global Constraint, so it applies to every task — if execution hits an ambiguity (e.g. exact nudge timing, comic skippability — spec §10), stop and ask the owner, do not decide it.
- **Type consistency:** `type_line`/`skip_typing`/`is_typing` (Task 1), `tuck` (Task 3), `TutorialIdle.start/reset/pause/resume` + `idle_nudge_seconds` (Task 4), `TutorialComic.play`/`finished` (Task 5) — used consistently in Tasks 6–9.
- **Finish with `ship-pr`** per `CLAUDE.md` (full suite + local review, PR, stamp). This is a handoff branch off `Textures`.
