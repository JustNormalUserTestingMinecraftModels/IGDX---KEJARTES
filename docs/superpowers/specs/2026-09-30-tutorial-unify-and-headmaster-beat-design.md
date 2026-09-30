# Tutorial Unification + Decoupled Headmaster Beat (design)

Handoff spec. Nothing here is built. Build on a fresh branch off `Textures`.
Read `## Visual system` and `## Testing` in `CLAUDE.md` before touching a node —
this design assumes those rules (no `theme_override_*`, no runtime-built
visuals, tests run inside the editor via the MCP bridge).

---

## 1. Problem

The onboarding tutorial reads as broken for two separate reasons, and they need
two separate fixes.

### 1a. Four parallel tutorial implementations

One coach-mark concept is implemented four times with three different looks:

| Screen | Panel source | Chrome |
|---|---|---|
| StudentCard (welcome) | `Scenes/UI/TutorialPanel.tscn` + `TutorialStepData` | lined-paper "TUTORIAL" tab |
| SchoolDay (end-of-week) | `Scenes/UI/TutorialPanel.tscn` | NotebookFrame |
| AturJadwal | **hand-built at runtime** in `_build_tutorial_panel()` | flat brown box |
| StudentList | **hand-built at runtime**, a near-duplicate | flat brown box + 320px arrow |

`Scripts/UI/TutorialPanel.gd` was written to be *the* shared coach-mark (its
header documents both callers and exposes knobs for their differing numbers),
but AturJadwal and StudentList never adopted it. The runtime construction also
violates the project's "no visual is built at runtime" rule
(`tests/test_viewport_editability.gd`) and, in AturJadwal, adds a StyleBox
override the design system bans.

Downstream symptoms (visible in the reference captures):
- Coach-mark changes costume mid-flow — paper tab → brown box → brown box with
  a giant arrow → NotebookFrame. No single "voice."
- Panels position from ad-hoc math instead of anchoring in `SafeAreaMargin`, so
  on the tall viewport (1080×2400) they jam against and spill off the bottom
  edge, overlapping the very card they explain.
- The arrow (`Scripts/TutorialArrow.gd`, 320×320) lands on top of the panel or
  target instead of beside it.
- **Silent dead taps.** In AturJadwal's forced "tap Senin" step, tapping any
  other day hits `AturJadwal.gd:1190` and `return`s with only a
  `print(...)` — no feedback. The button looks broken.

### 1b. The grade-transition congratulation is not a tutorial

`StudentCard.gd::_populate_default_tutorial_steps()` branches on grade:

- **Grade 7** (`:258`) — a real 14-step how-to-play (mood, energy, skills,
  quirk, persona, approve). Genuine teaching.
- **Grade 8** (`:283`) — 3 steps that are pure story: *"Selamat atas
  keberhasilanmu… naik ke Kelas 8"*, *"Tantangan Baru"*, *"pilih 1 murid
  tambahan"*. No mechanic taught.
- **Grade 9** (`:296`) — same shape: *"Luar biasa!… jenjang akhir"*,
  *"Persiapan Ujian Akhir"*, *"pilih murid terakhir"*.

All of it is gated by the tutorial toggle at `StudentCard.gd:207`:

```gdscript
if GameState.tutorials_bypassed:
    tutorial_active = false
    color_rect.hide()
```

So a player with tutorials off (or who has already seen them) **gets no
"welcome to Kelas 8/9" beat at all** — a per-grade story reward silently
vanishes because it was never its own system. The content is also
placeholder-grade: the speaker is baked into the body string as literal
`"Kepala Sekolah: '...'"`, with no name plate or dialogue styling.

The insight driving this design: *"you cleared a grade"* is a story beat every
player earns on every promotion; *"this is a mood bar"* is a one-time lesson.
They must not share a code path or a toggle.

---

## 2. Goals / non-goals

**Goals**
1. One consistent coach-mark look across all four tutorial screens — the
   "pinned sticky note" (Option A), built from a scene, never at runtime.
2. Fix the broken feel: anchored positioning (no bottom spill), a smaller
   offset arrow, and real wrong-tap feedback (shake target + dim non-targets)
   instead of silent dead taps.
3. Decouple the grade-transition headmaster congratulation into its own
   lightweight beat that plays on **every** promotion **regardless** of the
   tutorial toggle, and clean up its placeholder text.

**Non-goals**
- No new mascot / portrait art. The headmaster beat reuses the sticky-note card
  with a name-plate badge (see §4). Explicitly low visual lift, per direction.
- No change to *what* the grade-7 tutorial teaches — only its chrome and the
  wrong-tap feedback.
- No new persistence. Tutorial "shown" flags stay session-scoped `static var`s
  as today (CLAUDE.md: do not add persistence unasked).
- The SchoolDay end-of-week tutorial and StudentCard already use
  `TutorialPanel.tscn`; they are restyled to Option A but not restructured.

---

## 3. The shared sticky-note coach-mark (Option A)

Extend the existing `Scenes/UI/TutorialPanel.tscn` / `Scripts/UI/TutorialPanel.gd`
to *be* the single coach-mark, and delete the two runtime-built panels.

### 3a. Visual

A note "pinned to the board", reusing existing paper/token assets:
- Paper surface: the `Card`/`Sheet` variation (or `tutorial_panel_bg.png`),
  cream, 2px warm border, resting rotation **−1.4°** (`pivot_offset` at top so
  it hangs from the pin).
- A **pin**: a small red disc `TextureRect` centered on the top edge (new
  drop-replaceable placeholder `Assets/Images/UI/Placeholders/pin.png`, or a
  `LippedBox`-style disc — placeholder is fine).
- Content, top to bottom (already the panel's node order): a **step pill**
  (`Langkah n / N` on a mint pill), title (`H1Label`/`H2Label` per caller),
  one short body line, and the mint action prompt.
- Colors from `DesignTokens` — no `Color()` literals. Mint = `state_success`
  for the prompt; the pill uses the same mint. Never gold for the main action
  (style guide).

### 3b. Animation (maps to existing APIs — no new tooling)

| Moment | Behaviour | API |
|---|---|---|
| Entrance | slide up from below edge, settle with overshoot at −1.4° | `AnimUtils.popup_spring_in` / `Juice.pop_in` |
| Idle | slow sine sway −1.4°↔+1.4°, looped | looped `create_tween().set_loops()` on `rotation`, `TRANS_SINE/EASE_IN_OUT`, ~1.6s |
| Step change | three labels fade-and-rise-swap in place; card stays pinned | `Juice.count_up`-style label fade; no teardown |
| Wrong tap | target button shakes, non-targets dim | `Juice.shake` on target + modulate others |
| Exit | scale 0.8 + fade, arrow hides | `AnimUtils.popup_spring_out` |
| Pin | tiny squash on drop | `AnimUtils.squash_bounce` |

### 3c. Positioning + arrow

- The panel anchors inside `SafeAreaMargin` → `UI` (tall-phone rule,
  `tests/test_tall_screen_layout.gd`), not from raw viewport math. When a step
  targets a node, the panel sits on the opposite half of the screen from the
  target so the arrow has room; otherwise it centers.
- `TutorialArrow` shrinks to ~180×180 and offsets so its tip points *beside*
  the target, never over the panel. Keep its existing bounce.

### 3d. Wrong-tap feedback (the dead-tap fix)

Replace the silent `return` at `AturJadwal.gd:1190` (and the equivalent forced
steps in StudentList) with: play `error` sfx, `Juice.shake` the correct target,
briefly dim the non-target siblings, and keep the panel up. No text scolding —
the motion says "not that one, this one." This is a behaviour change on the
existing target-gating branch, not a new state.

---

## 4. The decoupled headmaster beat

### 4a. What it is

A tiny sequential dialogue that plays on grade promotion (7→8 and 8→9; the
graduation/EndCutscene already has its own chalkboard, out of scope). It reuses
the **same sticky-note card** as §3 with one change: the step pill is replaced
by a **name-plate badge** — a `school` glyph + "Pak Kepala Sekolah" on a mint
pill. Centered on screen, no arrow. Body is the quoted line; the speaker name
lives in the badge, so the placeholder `"Kepala Sekolah: '...'"` prefix is
removed from every string.

Same card, pin, and pop-in/pop-out animation as the tutorial → near-zero added
visual work.

### 4b. Content (rewritten, no speaker prefix)

Move these out of `tutorial_steps` into their own data (a small `const`
array keyed by grade in the owning script, or a `TutorialStepData`-shaped
resource array — see §5 for owner). Copy must read as natural KBBI Indonesian
(CLAUDE.md).

- **7→8:** "Selamat, naik ke Kelas 8!" / "Kerja bagusmu membimbing murid-murid
  Kelas 7 membuahkan hasil. Tapi perjuangan belum usai." — then "Tantangan
  baru" / "Kurikulum Kelas 8 lebih menantang. Untuk menyeimbangkan kelas, kita
  kedatangan murid baru."
- **8→9:** "Naik ke Kelas 9!" / "Murid-muridmu kini di jenjang akhir. Inilah
  tahun penentuan kelulusan mereka." — then "Persiapan ujian akhir" / "Ujian
  nasional sudah dekat. Kita butuh satu murid lagi agar kelasmu genap empat."

The final "pick N more students" line is **not** part of the beat — that is a
real instruction and stays a (single) sticky-note tutorial step on StudentCard,
shown only when tutorials are on.

### 4c. Gating (the core fix)

The headmaster beat is **independent of `tutorials_bypassed`**. It plays once
per promotion, tracked by its own session flag (e.g.
`GameState.headmaster_beats_seen` — a small `Dictionary`/set of grades, session
-scoped, no disk). The grade-7 how-to-play tutorial keeps respecting
`tutorials_bypassed` as today.

---

## 5. Where the beat lives — DECISION NEEDED (pick one before building)

Two viable homes; the implementing team should pick based on how the
grade-transition currently routes:

- **Option 5-A — on StudentCard (smaller change).** The beat plays as an
  overlay on the StudentCard screen (where it lives today), just moved out of
  `tutorial_steps` into its own overlay path with its own gate. Least routing
  churn; reuses StudentCard's existing tutorial CanvasLayer.
- **Option 5-B — on the existing CutScene (cleaner separation).** The beat
  rides `Scenes/CutScene` during the grade transition, before StudentCard.
  Cleaner conceptually (story beat in the story screen) but touches scene
  routing (`Transition.change_scene`) and needs CutScene to host the card.

Default recommendation: **5-A** for this pass (lower risk, no routing changes),
noting 5-B as a future move. The plan (§ separate file) is written for 5-A;
switching to 5-B changes only Phase 4.

---

## 6. Files touched

- `Scenes/UI/TutorialPanel.tscn`, `Scripts/UI/TutorialPanel.gd` — pin + step
  pill + name-plate variant + anchored layout.
- `Scripts/TutorialArrow.gd` — smaller, offset.
- `Scripts/AturJadwal/AturJadwal.gd` — delete `_build_tutorial_panel()`, use the
  shared scene; wrong-tap feedback.
- `Scripts/StudentList/StudentList.gd` — same: delete runtime panel, use scene;
  wrong-tap feedback on its forced steps.
- `Scripts/StudentCard/StudentCard.gd` — remove grade-8/9 story steps from
  `_populate_default_tutorial_steps()`; add the decoupled beat trigger (5-A).
- `Scripts/GameState.gd` — session flag for beats-seen.
- `Scripts/SchoolSimulation/SchoolDay.gd` — restyle its end-of-week
  `TutorialPanel` usage to Option A (knobs only; no structural change).
- Tests: `tests/test_tutorial_panel.gd`, `tests/test_atur_jadwal.gd`,
  `tests/test_student_list.gd`, `tests/test_student_card.gd`,
  `tests/test_viewport_editability.gd` (its runtime-construction BASELINE
  should *drop* as the two runtime panels are deleted — ratchet down, never up).

---

## 7. Testing approach

Follow the project's source-scan + editor-bridge pattern:
- Assert `TutorialPanel` exposes the name-plate mode and the pill, and that
  AturJadwal/StudentList no longer construct panels at runtime (scan for the
  removed `PanelContainer.new()` / `add_theme_stylebox_override`).
- Assert the grade-8/9 congratulation strings are **absent** from
  `StudentCard.gd::_populate_default_tutorial_steps()` and present in the new
  beat data.
- Assert the headmaster beat trigger does **not** read `tutorials_bypassed`.
- Lower the `test_viewport_editability` BASELINE by the two deleted panels.
- No `await` in tests; suites `@tool`; run via `test_run` inside the editor.

---

## 8. Out of scope / debt

- No mascot portrait art (deliberate — see §2 non-goals). A future pass could
  upgrade the name-plate beat to Option C (portrait + speech bubble) without
  changing the gating.
- EndCutscene graduation chalkboard is untouched.
- Minigame tutorials (`MinigameTutorial.gd`) are a separate system, not part of
  this pass.
