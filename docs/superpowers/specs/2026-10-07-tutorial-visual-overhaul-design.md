# First-Day Tutorial — Visual Overhaul (design)

Handoff spec. Nothing here is built. Build on a fresh branch off `Textures`.
Read `## Visual system`, `## Testing` and `## Working efficiently here` in
`CLAUDE.md` before touching a node — this design assumes those rules (no
`theme_override_*`, no runtime-built visuals, tests run inside the editor via
the MCP bridge).

Interactive reference mockup (look + behaviour, placeholder art):
`docs/superpowers/mockups/tutorial-handoff.html` — open it in a browser. It is
the source of truth for *feel*; this file is the source of truth for *rules*.

---

## 0. For the implementing team — READ FIRST

This design was audited visually with the owner before it was written. Two
standing rules for whoever picks it up:

1. **Ask before any new tweak.** The structure, copy, motion, box design and
   scope below were chosen deliberately with the owner (relaying a reviewer's
   notes — see memory `design-direction-comes-from-a-mentor`). Do **not**
   improvise new visuals, rewrite the Indonesian, add beats, change the box,
   or re-scope on your own. If something here is ambiguous or you believe a
   change is warranted, **stop and ask the owner** rather than deciding it.
   A small wording fix for grammar is fine; a design or scope change is not.

2. **The mockup is placeholder art — real assets must be made.** Every drawn
   element in the reference (the headmaster mascot + expressions, the Nota Guru
   paper / paperclip / name tab, the pointing hand, the comic cold-open plates,
   the star/check marks) is a stand-in. Ship them as **drop-replaceable
   placeholder SVGs at stable paths** and **log every one in
   `docs/superpowers/DEBT.md`** under a single "tutorial art" group so the
   artist/owner can swap real art later with no code change. **No emoji as
   iconography** (`CLAUDE.md` conventions) — drawn transparent SVG only. See
   §7 for the asset list.

---

## 1. Problem

The Grade-7 onboarding is **14 sequential text cards**
(`StudentCard.gd::_populate_default_tutorial_steps`, the `current_grade == 7`
branch): each a title plus two or three sentences of Indonesian body text, a
spotlight + arrow, and forced taps — all served before the player has touched
anything. Playtesters (competition feedback) read it as a "text assault,"
got confused, and skipped it. The machinery is sound; the **content model** is
the problem: it front-loads reading, every card looks the same, and there is no
per-card payoff.

Two smaller issues surface alongside it:
- The coach note and the trait pop-up (`TraitDetailPopup`) can occupy the screen
  at once and overlap — a real layering bug the owner flagged.
- The tutorial's look is not yet consistent across every screen that teaches
  (Lobby, StudentList, SchoolDay), risking the same "costume change mid-flow"
  the earlier unify pass fought.

---

## 2. Goals / non-goals

**Goals**
1. Replace the Grade-7 text-wall with a **show-and-do** flow: a comic cold-open
   stating the goal, tap-to-learn stat spotlights, a trait hand-off, and a
   learn-by-doing schedule beat — all **as an overlay on the live screen, not a
   new scene** (reuse the shipped `TutorialPanel` spotlight / arrow / wrong-tap).
2. Give every tutorial one voice and one look: the **Nota Guru** dialogue box
   (headmaster Pak Kepsek), adopted on **every** tutorial screen (Lobby
   included), with a **typewriter** reveal, **tap-anywhere** advance, and the
   **one-focal-box** rule that fixes the pop-up overlap.
3. Add an **idle layer** (resting loops + a timed escalation nudge) so a
   hesitating player is pulled toward the next tap — **touch-first, no hover.**
4. Keep the **grade-transition** promotion beats, re-skinned to the Nota Guru
   box (content already exists in `HeadmasterBeat`).

**Non-goals**
- No new persistence beyond the existing session flags
  (`GameState.headmaster_beats_seen`; a tutorial-seen `static var` as today).
  `CLAUDE.md`: do not add persistence unasked.
- No change to simulation/`Balance` numbers, and no new mechanics — this teaches
  what already exists.
- No deep content redesign of Lobby / StudentList / SchoolDay this pass — they
  adopt the shared look only (see §6).
- No final art. Placeholders only; real art is a tracked follow-up (§0.2, §7).
- EndCutscene graduation and the minigame how-to (`MinigameTutorial`) are out of
  scope.

---

## 3. The shared coach-mark system (every tutorial screen)

### 3a. The Nota Guru dialogue box
A torn-paper note — Pak Kepsek's single voice game-wide. Build it as a
**`NotebookFrame` variant** so `tests/test_popup_frames.gd` keeps guarding it;
it extends/retheme the existing `TutorialPanel` scene rather than a new one.
- Cream paper surface, warm 2px border, a **torn top edge**, a **paperclip**,
  and a **name tab** reading the speaker. All colours from `DesignTokens`
  (no `Color()` literals); mint = `accent_mint`/`state_success` for the prompt,
  never gold for the main action (style guide).
- A small ribbon distinguishes a **lesson** (`TUTORIAL`) from a **story beat**
  (`PENGUMUMAN`) / instruction (`TUGAS`) — this is the existing
  `step_sticker_text` / `beat_sticker_text` split in `TutorialPanel.gd`, reused.
- Content order unchanged from the current panel (badge/pill or name plate →
  title → body → prompt). The body is the typewritten line.

### 3b. Advancing
- **Teaching + story beats:** the blinking prompt `KETUK DI MANA SAJA UNTUK
  LANJUT` (the panel's existing `DEFAULT_PROMPT`); a tap **anywhere** on the
  dimmed overlay advances.
- **Action beats** (tap a badge, pick an activity, tap Approve / a roster card):
  gate on that one real control; a tap on a dimmed neighbour triggers the
  existing wrong-tap feedback (`TutorialPanel.answer_wrong_tap`), never a dead
  tap. On completion the beat switches to the tap-anywhere prompt.
- **Typewriter** ~30 ms/char with **tap-to-skip**: the first tap fills the line
  instantly, the next advances. Honour the "Lewati Dialog" setting
  (`GameSettings.skip_event_dialogue`) by rendering lines instantly when set.

### 3c. One focal box (the overlap fix)
The coach note and any game pop-up (`TraitDetailPopup`, and the quirk/persona
effect panels) are **mutually exclusive**:
- Tapping a trait badge makes the note **tuck away** (slide down + fade) first;
  then the real pop-up springs in. Closing the pop-up slides the note back with
  the follow-up line. **Never both visible.**
- Z-order backstop regardless: the coach layer sits **below** game pop-ups.
- The idle nudge (§3e) **pauses** while a pop-up / comic / beat is on screen.

### 3d. Positioning (unchanged rules)
Anchor inside `SafeAreaMargin` → `UI`; the note sits on the half opposite the
spotlight so the arrow has room (the existing `TutorialPanel.placement` /
`place_step`). Tall-phone rule applies (`tests/test_tall_screen_layout.gd`).

### 3e. Idle layer (touch-first)
- **Resting loops, always on:** note sway ±1.4°, mascot breathe + blink, a soft
  highlight ring on the active target, breathing CTA. Looped
  `create_tween().set_loops()`.
- **Escalation nudge** after `idle_nudge_seconds` (new `@export`/const on the
  owning controller, **default 2.5 s**) of no input: the pointing hand slides
  in, the target wiggles harder, the ring intensifies, Pak Kepsek drops a
  one-line nudge. **Any tap resets** the timer. Capped at one level — no endless
  escalation. Fires on a **timer or tap only**, never pointer-enter; every
  target ≥ 44 px.

---

## 4. The Grade-7 first-run flow (deep redesign)

An overlay on StudentCard, then the first AturJadwal. Beats:

1. **Misi (cold-open, 3 beats).** Full-dim; a centered comic plate states the
   goal, then the stakes. Copy (final, KBBI, keep verbatim unless owner approves
   a change):
   - "Selamat datang, Pak Guru! Ini kelas yang akan kamu bimbing."
   - "Tiap murid punya 3 target. Capai minimal 2, dia lulus." (targets ✓ ✓ ✕)
   - "Hati-hati: satu murid saja gagal, satu kelas kena nilai D." (✓ ✕ ✕)
   The "2 of 3 to pass, one failure sinks the class" is
   `GameState.MIN_TARGETS_PER_STUDENT` — keep the rule exact.
2. **Kenalan (3 spotlights).** One **traveling** note hops the real bars:
   - Mood — "Ini Mood Siti. Kalau bagus, dia belajar dengan semangat; kalau
     habis, gampang ngambek."
   - Energi — "Ini Energi. Tiap kegiatan menguras energi. Kalau habis, Siti
     terpaksa izin istirahat." (reflects the energy ≤ 5 auto-Izin rule)
   - Skill — "Dan ini tiga skill-nya: Akademis, Seni Budaya, Olahraga. Inilah
     yang kamu kejar biar dia lulus."
3. **Sifat (hand-off).** Spotlight the Quirk/Persona badges; tapping one hands
   off to the real `TraitDetailPopup` (§3c). Follow-up: "Nah, begitu cara baca
   sifat murid. Sesuaikan jadwalnya, ya!"
4. **Jadwal (learn-by-doing)** on the first AturJadwal: spotlight the activity
   choice for one day; on pick, the real stat bars animate the consequence with
   floating deltas (`Juice.fill_bar` + `AnimUtils.create_floating_text` +
   `Juice.count_up`). Lines for the Belajar and Istirahat branches are in the
   mockup; keep both so either choice teaches the trade-off.
5. **Mulai.** Spotlight Approve; tap to finish into the first week.

The traveling single note (never two side-by-side) is the existing in-place
step change (`TutorialPanel._play_step_change`), not a second panel.

---

## 5. The grade-transition beats (7→8, 8→9)

Already implemented as `HeadmasterBeat` (`HEADMASTER_BEATS` + `PICK_STEPS`),
decoupled from the tutorial toggle and in name-plate mode. This pass **only
re-skins** it to the Nota Guru box and the shared animation kit; **content
stays.** Shape, per promotion:
- **Story beats (1–2)** — congratulation + "it's harder now." Play on **every**
  promotion **regardless of `tutorials_bypassed`** (`HeadmasterBeat.is_due`).
  Ribbon `PENGUMUMAN`.
- **Instruction beat (3)** — "pick one more student" (`PICK_STEPS`): the roster
  genuinely grows (Kelas 8 = 3, Kelas 9 = 4). The **coach note respects
  `tutorials_bypassed`**, but the pick itself happens either way. Ribbon `TUGAS`.
No new mechanics are taught; the player keeps Grade-7 knowledge.

---

## 6. Scope split

- **Shared system — every tutorial screen, Lobby included:** the Nota Guru box,
  tap-anywhere prompt, one-focal-box rule, idle tiers, touch-first behaviour and
  typewriter. Keep each screen's current teaching **content**; only re-skin and
  re-behave it. This is the anti-"costume-change" guarantee.
- **Deep redesign — Grade-7 first-run only:** the §4 comic + learn-by-doing
  beats. StudentList / SchoolDay / Lobby do **not** get content redesigns this
  pass.

---

## 7. Assets (placeholder-first, must become real — §0.2)

Ship each as a drop-replaceable placeholder SVG at a stable path and list it in
`DEBT.md` (one "tutorial art" group):
- Pak Kepsek mascot, with 2–3 expressions (senang / serius / bangga).
- Nota Guru paper texture (torn top), paperclip, name tab.
- Pointing hand / cursor (idle nudge).
- Comic cold-open plates (3): class scene, happy student + targets, warning
  student + failing targets.
- Target ✓/✕ and reward ★ marks.
Honour existing asset rules where they apply (bar fills, ghost track, etc. —
`CLAUDE.md` "Asset constraints"). None of these are tested for art; they are
tested only for presence/structure (§9).

---

## 8. Files touched (expected)

- `Scenes/UI/TutorialPanel.tscn`, `Scripts/UI/TutorialPanel.gd` — Nota Guru
  skin as a `NotebookFrame` variant; typewriter + tap-to-skip; ribbon modes;
  idle hooks.
- `Scripts/StudentCard/StudentCard.gd` — replace the grade-7 14-step table with
  the §4 beats (comic overlay + spotlight beats + learn-by-doing handoff to
  AturJadwal); keep grade-8/9 routing via `HeadmasterBeat`.
- `Scripts/StudentCard/HeadmasterBeat.gd` — re-skin only (box/animation); no
  content change.
- `Scripts/AturJadwal/AturJadwal.gd` — the learn-by-doing beat on first
  assignment (live bar reaction already exists; gate + spotlight it).
- Lobby / StudentList / SchoolDay tutorial callers — adopt the Nota Guru box +
  shared rules (re-skin; no content redesign).
- `Scripts/GameState.gd` — only if a session flag is missing; prefer existing.
- A new comic cold-open overlay scene (static chrome in `.tscn`, no runtime
  construction — `tests/test_viewport_editability.gd`).
- `docs/superpowers/DEBT.md` — the tutorial-art placeholder group.

---

## 9. Testing approach

Follow the project's source-scan + editor-bridge pattern (`CLAUDE.md`
`## Testing`; suites are `@tool`, no `await`, run via `test_run`):
- `tests/test_tutorial_panel.gd` — assert the Nota Guru variant exists, the
  typewriter + tap-to-skip path, the three ribbon modes, and the one-focal-box
  tuck/return (scan for the handoff behaviour).
- `tests/test_student_card.gd` — assert the grade-7 14-step table is **gone**
  and the new beats/overlay are wired; grade-8/9 still routes through
  `HeadmasterBeat`.
- `tests/test_atur_jadwal.gd` — the first-assignment learn-by-doing gate.
- `tests/test_viewport_editability.gd` — the comic overlay is authored in the
  scene, not built at runtime (BASELINE must not rise).
- Keep the idle nudge logic behind a knob and assert its default and the
  pointer-enter-free (touch-only) wiring by source scan.
- Assert the transition story beats do **not** read `tutorials_bypassed` and the
  pick instruction does.

---

## 10. Open decisions for the owner (ask — do not assume)

- Exact `idle_nudge_seconds` default (2.5 s proposed).
- Whether the comic cold-open is skippable independently of the rest.
- Final placeholder-vs-real art timing (who draws, when).
Everything else in this file is settled; raise anything new with the owner per
§0.1.
