# Minigame Polish — Part 2 (Depth & Feel)

**Date:** 2026-09-28
**Status:** Draft for review (design only — no code until approved)
**Author:** Handoff from a design/brainstorming session (all six games prototyped
live in an in-app animated mockup).
**Origin:** Mentor review notes, relayed. The feel this spec encodes was audited
in a living prototype — treat **mentor sign-off** and, for the scoring numbers,
**Balance-owner sign-off** as hard gates before build.

**Prerequisite:** [Part 1](2026-09-28-minigame-polish-part-1-design.md)'s shared
kit (backdrop, Bingkai-Kayu cards, button family, overlays, shared HUD). Part 2
**layers on** it — it must not start until Part 1's Phase 1–2 (kit foundation +
HUD) have landed, or the two passes fight the same scenes and `ThemeFactory`.

---

## 1. Problem

Part 1 makes the minigames *look* like one game. They still don't *feel* deep.
Reading `BaseMinigame.gd` and each game:

- **The scoring contract is shallow and shared.** Every game wins at
  `score >= get_target_win_score()` — a target of only **1 / 2 / 3** points by
  grade. Stars come separately from a per-game `get_star_ratio()` mastery ratio.
- **No combo, no streak, no timing grade, no in-game difficulty curve.**
  Difficulty is a single integer from the grade. A correct answer feels the same
  as the tenth correct answer in a row.
- **Score is a static number.** No count-up, no floating points, no reason to
  watch it.
- **Deferred items from Part 1** remain: the bespoke Password / Variabel /
  Kalkulator layouts, and LombaMenari beat-sync.

The result: Part 1 removes the "two different apps" problem; Part 2 is what makes
the games *rewarding to play*.

## 2. Goal & non-goals

**Goal:** a shared **Depth Kit** — a combo/streak system, a live multiplier, a
timing/answer **grade** vocabulary, a **score display** with count-up and
floating points, and one score→star curve — plus per-game "what is a hit"
mappings, LombaMenari rhythm depth, and the fresh layout fixes. The games should
feel *cute, lively and rewarding*, with escalating tension that pays off.

**Non-goals:**
- **No new persistence** (per `CLAUDE.md`).
- **No CosmeticShop** or non-minigame screens.
- **No coin economy.** Wins stay stat-only (as Part 1 settled).
- **No beat-locked LombaMenari** yet — timing *grades* are in; true BPM sync is
  deferred (needs the track BPM from the audio owner). Leave a clean seam.
- **No bespoke rewrite of the win/lose hero screen** — that is Part 1's; Part 2
  only feeds it the new score/stars/combo-best figures.

## 3. Locked design decisions

From this session's live-prototype review, these are settled:

| Piece | Decision |
|---|---|
| **Backbone** | **Approach C** — shared *primitives* in `BaseMinigame` (combo counter, `HitQuality` enum, multiplier, score→star helper, shared meter + grade HUD), and each game maps its own "hit". Not one rigid engine (A), not nine bespoke systems (B). |
| **Score display** | **B + C + D combined.** B = a **fused pill**: score + a live multiplier badge that glows/scales when hot, greys to ×1 on break. C = **motion**: odometer digit-roll + a floating `+points` on each hit. D = **per-game content**: same pill frame, but the label/icon flex (quiz = points, football = GOL count, badminton = SKOR). One `MinigameScorePill` variation + one small reusable node. |
| **Combo timing is per-game** | Most games judge a hit **immediately** (per-action combo). **Menjodohkan judges at reveal** — see below. The per-game table carries a "when judged" column so the kit never forces immediate feedback where the mechanic has none. |
| **Menjodohkan** | **Blind lock → reveal cascade.** Kunci stays non-committal (🔒, no verdict, cancellable — unchanged from today). The entire Depth Kit fires during the **Submit `reveal_answers()` cascade**: correct pairs pop green and chain the combo + multiplier + count-up one at a time; a wrong pair flips red and breaks the combo. Respects the existing commit-blind mechanic. |
| **Badminton** | **Rally is the score.** Every clean return grows `RELI` (the combo) and a **rally pot** (`reli × mult`); the **shuttlecock heats up** (glow → fire) as the pot climbs. At a threshold rally a **SMASH!** finisher lights — a timed swipe that banks the pot + bonus and ends the rally. Whiff/opponent-point = lose the pot, combo resets. Replaces the generic match score. |
| **MainBola** | **Accuracy streak + shrinking target + bonus zone.** Consecutive on-target goals build the combo; the moving target **shrinks** as the multiplier climbs. On a streak a **top-corner bonus zone** lights up — risk the harder spot for a big multiplier (football's signature moment, like Badminton's SMASH). A save resets the combo. |
| **LombaMenari** | **Timing grades.** Single-runway note flow (from Part 1) gains **Perfect / Good / Miss** timing windows feeding the shared combo + grade popup. Dancer reacts to the last result. Beat-sync deferred behind a clean seam. |
| **BuatBatik** | **Precision opt-out.** No combo (a 5-step ordered sequence resists one). Each correct tool step reveals a pattern layer + a progress dot and grants a **precision bonus**; the kit's grade popup still fires ("PRESISI!/BAGUS"). Proves the shared kit does not force a combo where it doesn't fit. |
| **Motion** | Extends Part 1's cute-lively vocabulary: heat build, spring-in prompts (SMASH/KUNCI/bonus-zone), screen shake on break, floating points, odometer count-up, heart bursts on long streaks, grade-popup pop. All map to `Juice.gd` / `AnimUtils.gd` + existing `ConfettiFireworks`/`StarBurst`/`ScorePopBurst`. |
| **Economy / balance** | Full mechanical depth **with** a Balance-owner proposal for the numbers that move (§4.5). Ships the *feel*; the *numbers* land on their sign-off. |

## 4. Architecture

### 4.1 The Depth Kit in `BaseMinigame`

New shared logic on `BaseMinigame` (subclasses opt in; nothing forced):

- `enum HitQuality { MISS, GOOD, PERFECT }`.
- A `ComboTracker` (plain `RefCounted`, preload — not an autoload): current
  combo, best combo, and the multiplier derived from a documented curve.
- `func register_hit(quality: HitQuality) -> int` — advances/breaks the combo,
  updates the multiplier, returns the points awarded for this hit
  (`base_points × multiplier`), and emits signals.
- New signals: `hit_registered(quality, points)`, `combo_changed(combo, mult)`,
  `combo_broken()`.
- One score→star helper reused by every game's `get_star_ratio()` so mastery
  reads consistently (accumulated score ÷ a per-game `max_score`).
- All new tunables are **our own** `const` blocks / `@export`s in the owning
  script (never inline, never in `Balance.gd`) — the curve constants live in a
  named block like `RunGrade.gd`'s `WEIGHT_*`.

Menjodohkan calls `register_hit` **inside `reveal_answers()`**, once per revealed
pair, not on Kunci. Every other game calls it at its own hit moment.

### 4.2 Shared HUD additions (ThemeFactory, no overrides)

New variations in `ThemeFactory.gd` (rebake via `Scripts/Design/BakeTheme.gd`):

- `MinigameScorePill` — the fused score+multiplier pill (B/C/D). The multiplier
  badge's hot/cold state is a script-driven property, not a variation swap.
- `MinigameComboMeter` — the combo bar (fill + rim) + its label plank.
- `MinigameGradePopup` — the Perfect/Good/Miss/BENAR/SALAH popup styling.
- `MinigameFloatText` — the floating `+points` style.

Reusable nodes (authored `.tscn`, **not** built at runtime):
- A small **score-pill scene** carrying the odometer digits + the floater spawn
  point, with `@export`s on its **root** (per the instance-child-override hazard).
- A **combo-meter scene** instanced into each game's HUD region.

The odometer and floaters animate via script using `Juice.count_up` /
`AnimUtils.create_floating_text`; the digit strips are authored nodes, only their
transform is driven — this stays inside the `test_viewport_editability.gd`
ratchet (document any new dynamic call in `ALLOWED`, do not raise `BASELINE`).

### 4.3 Per-game "hit" definitions (the only per-game surface)

| Game | A HIT is… | Perfect vs Good | Breaks combo | When judged |
|---|---|---|---|---|
| PilihanGanda / Password / Variabel | correct answer | fast vs slow answer | wrong answer | immediate |
| Menjodohkan | a revealed **correct** pair | (correct only) | a revealed wrong pair | **at reveal** (cascade) |
| LombaMenari | note swiped in the hit-circle | timing window | miss / wrong direction | immediate |
| Badminton | a clean return | sweet-spot hit | opponent scores | immediate (SMASH banks) |
| MainBola | goal on target | target centre / bonus zone | keeper save / off target | immediate |
| BuatBatik | correct tool + correct step | precision bonus (no combo) | — (wrong tool fails step) | immediate |

### 4.4 LombaMenari rhythm depth

- Timing windows around the hit-circle → `HitQuality`; grades feed the shared
  combo + popup. Windows are documented `@export`s (grade-scalable), owned by
  `LombaMenari.gd`.
- Dancer pose reflects the last result (existing hook).
- **Beat-sync deferred:** keep the existing pattern/`note_speed` timing; leave a
  documented seam (`## Beat-sync: supply BPM from the audio owner here`) so
  locking spawns to the track is a later, isolated change. Flag the dependency.

### 4.5 Balance coordination (proposal, gated)

Package a separate proposal to the Balance owner covering **only** the numbers
this pass moves — never edited by us directly:

- The **multiplier curve** (how fast ×mult climbs with combo, and its cap).
- Whether/how **`get_target_win_score()`** thresholds change now that a run can
  score far more than 1–3 points (the win gate must still map to the grade table
  10/8/6 stat and the star ratio).
- **Badminton** SMASH threshold + bonus.
- **MainBola** target-shrink rate + bonus-zone multiplier.
- **BuatBatik** precision-bonus values.
- Per-grade scaling of all of the above.

Part 2 ships the *feel* with our own placeholder constants; the *numbers* are
replaced on their sign-off (take their version on merge, per `CLAUDE.md`).

### 4.6 Fresh layout critique (deferred-from-Part-1 fixes)

- **Password / Variabel** — bespoke desk composition beyond the shared kit:
  the QuestionCard paper, the shared Kalkulator slot, the LCD, and the Kirim/Hapus
  affordances re-laid for a phone so the calculator and the question breathe. The
  new score pill + combo meter must fit above without crowding (see §9 risk).
- **Kalkulator widget** — key feel (press/release juice), LCD styling on tokens,
  and the zero-key/3-digit variance handled cleanly.
- Keep `SoalFit.gd` as the text-fit path; do not regress it.

### 4.7 Cross-cutting rules to honour

- **No `theme_override_*`** (layout-only `separation`/`margin_*` excepted).
- **No runtime-built visuals** beyond the documented ratchet.
- **`##` header + `##` on every `@export`** (`test_script_documentation.gd`).
- **Indonesian** UI text; **no emoji as iconography** (real transparent SVGs —
  the prototype's emoji are stand-ins only).
- **Tall phones:** re-anchor the new HUD inside `SafeAreaMargin → UI`
  (`test_tall_screen_layout.gd`).

## 5. Phases (build order)

| # | Phase | Depends on | Verified by |
|---|---|---|---|
| 0 | Part 1 kit (Phase 1–2) exists | — | prerequisite |
| 1 | **Depth Kit logic** — `HitQuality`, `ComboTracker`, `register_hit`, score→star | 0 | logic unit suite (headless-friendly) |
| 2 | **Shared HUD** — score pill + combo meter + grade popup + float scenes/variations + rebake | 1 | source-scan + theme suite |
| 3 | **Quiz family** wired — PilihanGanda (reference) → Password → Variabel | 1,2 | per-game scan suites |
| 4 | **Menjodohkan** reveal cascade | 1,2 | Menjodohkan suite (blind lock, cascade combo) |
| 5 | **LombaMenari** timing grades (+ beat-sync seam) | 1,2 | LombaMenari suite |
| 6 | **Olahraga** — Badminton rally-pot+SMASH, MainBola streak+shrink+bonus-zone | 1,2 | per-game suites |
| 7 | **BuatBatik** precision opt-out | 1,2 | BuatBatik suite |
| 8 | **Layout fixes** — Password/Variabel/Kalkulator bespoke layouts | 2 | tall-phone + scan suites |
| 9 | **Motion polish** across all | 3–8 | visual spot-check |
| P | **Balance proposal** (parallel, gated) | 1 | hand-off, not merged by us |

Phases 3–7 parallelize once 1–2 land. Each phase is independently shippable.

## 6. Asset dependencies (flag early)

- **Grade popup** art/treatment (Perfect/Good/Miss) as transparent SVGs.
- **Combo-meter fill** honouring `Assets/Images/UI/BarFill/README.md` (contrast
  floor, ghost track) if it reuses the bar system.
- **Badminton:** burning-shuttle heat states (glow/flame) — procedural or art.
- **MainBola:** bonus-zone highlight + shrinking-target treatment.
- Odometer digit styling (font_display numerals on tokens).

Replacements honour `CLAUDE.md` §Visual system and any asset README.

## 7. Build & test constraints (for whoever implements)

- **Edit `.tscn` through the editor** (`scene_open` → `node_*`/`batch_execute` →
  `scene_save`); scene work first, script work second; watch the three save
  hazards (stale script buffers, instance-child overrides, editor-across-pull).
  Give sub-scene `@export`s on their **root**.
- **Rescan after editing a `.gd`** before `test_run`; a full run rebakes the
  theme + rewrites `default_bus_layout.tres` — `git status` after, `git checkout
  --` what you didn't intend. Prefer targeted `test_run(suite=…)`.
- **Tests:** extend `McpTestSuite`, `@tool`, no coroutines, via MCP `test_run`.
  Add per-game suites; extend `test_script_documentation.gd`,
  `test_viewport_editability.gd` (ratchet only lowers), `test_tall_screen_layout.gd`,
  `test_theme_factory.gd` (new variations + `DISPLAY_ROSTER`). Source-text scans
  where a screen can't instantiate headlessly.
- Reach states by **seeding** (Debug overlay → Seed Playtest State; minigame
  launcher), never by playing.

## 8. Open items (gates, not blockers to planning)

1. **Mentor sign-off** on the feel (audited in the live prototype).
2. **Balance-owner sign-off** on §4.5 numbers.
3. **Dialogue copy** — any new combo/grade voice lines from the voice owner
   (structure ours, words theirs); respect `GameSettings.skip_event_dialogue`.
4. **LombaMenari BPM** — from the audio owner, only when beat-sync is pursued.

## 9. Risks

- **Vertical crowding.** Combo meter + HUD + question card + answers + score pill
  is a tall stack on a short (16:9) phone. Mitigation: the multiplier lives
  *inside* the pill (B), not a second row; the combo meter is a single thin bar.
  Validate on the 16:9 embedded run, not just 20:9.
- **Win-gate drift.** Bigger scores must not silently make wins trivial or
  impossible — the `get_target_win_score()` mapping is a Balance gate (§4.5),
  not something Phase 1 sets alone.
- **Menjodohkan pacing.** The reveal cascade adds seconds at round end; keep it
  snappy and skippable so it reads as a payoff, not a wait.

## 10. Success criteria

- Every game shares the combo meter, live multiplier, count-up score pill and
  grade popup; each still feels distinct to its verb.
- Streaks build visible, escalating tension that pays off (SMASH, bonus zone,
  reveal cascade, count-up).
- Menjodohkan keeps blind-lock; the combo lives in the reveal cascade.
- BuatBatik reads as intentional with a precision bonus and no combo.
- Password/Variabel/Kalkulator have real bespoke layouts, not just the kit.
- No new `theme_override_*`; no runtime-built visuals beyond the ratchet; all
  new scripts documented; all UI text Indonesian; no emoji iconography.
- The Balance-owner proposal is delivered; Part 2 ships feel with placeholder
  numbers pending sign-off.
- Full `test_run` green (theme/bus-layout caveats handled).
