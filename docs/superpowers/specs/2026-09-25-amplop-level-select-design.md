# Amplop Coklat level select — design spec

**Date:** 2026-09-25
**Status:** Design approved (visual + interaction). Ready for an implementation plan.
**Interaction prototype:** [`mockups/amplop-level-select-prototype.html`](mockups/amplop-level-select-prototype.html)
— open it in a browser; it pins interaction, staging and motion only, not final art.

> This document is a self-contained brief. A dev (or their Claude) should be
> able to pick it up without the brainstorming conversation. Read the prototype
> and this file together, then run it through `superpowers:writing-plans` to
> produce the step-by-step implementation plan before writing code.

---

## 1. Why

The current grade picker (the "PILIH TINGKAT KELAS" screen with DEBUG LEVEL /
SKIP) is a developer-grade list: three text buttons, a debug banner, no visual
identity. It works but reads as a debug tool, not a consumer screen. Players get
no *feel* for what each grade is or how hard it is.

**Goal:** replace the plain-text picker with a diegetic **stack of brown
envelopes (amplop coklat)** — one per grade — that the player thumbs through and
opens like a real assignment. Picking a grade should communicate, at a glance:
who you're teaching, how long you have, and how hard it will be — without making
the player read numbers.

Non-goal: changing any gameplay, balance, or the DEBUG LEVEL / SKIP developer
controls. Those stay exactly as they are; this is a presentation layer over the
same grade-selection action.

## 2. What the player does (interaction)

Three amplop fan out, tabs peeking: **Kelas 7 / 8 / 9**. One is centered
(selected); the other two sit back, dimmed and rotated.

- **Navigate** between grades three redundant ways (all must work):
  - **Swipe** left/right across the envelope area.
  - **Tap** a side envelope to bring it to center.
  - **‹ / ›** arrow hints at the edges.
- The centered envelope drives a **briefing card** below it (see §4).
- **Idle:** envelopes bob gently; the centered one does a small **attention-hop**
  every few seconds so the screen reads as touchable.
- **Pick:** "Buka map ini" (or tapping the already-centered envelope) opens a
  **confirmation** (§5): the envelope opens, students peek out, an assignment
  letter (surat tugas) appears, with **Mulai (Terima tugas) / Batal**.
- On **Terima tugas**: set the grade and transition into the game (§6).

## 3. Motion

Every motion below maps to an existing `Juice.gd` / `AnimUtils.gd` Tween — none
is new tech.

| Moment | Motion | Godot implementation |
|---|---|---|
| Change grade (swipe/tap/arrow) | **Shuffle-and-bounce**: the fan re-clusters into its new arrangement with a spring overshoot — like riffling a paper stack | Tween each envelope's `position` + `rotation` + `scale` with `TRANS_BACK`, `EASE_OUT` |
| Idle | Gentle vertical bob; centered envelope adds an occasional hop | Looping `TRANS_SINE` tween (bob) + a periodic `TRANS_BACK` hop, mirrors `main_menu.gd`'s `_float_forever` |
| Open (confirm) | Flap rotates back, wax seal pops away, pupils rise to peek, letter slides/expands in | Sequenced Tween; flap `rotation`/`scale`, seal `scale`→0, pupils `position`+`modulate:a`, letter reveal |

The prototype uses CSS `cubic-bezier(.34,1.6,.5,1)` for the bounce — that's a
`TRANS_BACK`/`EASE_OUT` analogue. Tune the exact overshoot with the
`motion-lab` skill against the real nodes once built.

## 4. The briefing card (label-over-numbers)

The centered grade shows three **iconographic** stats, not a text list:

1. **Murid** — that many literal little pupil heads (2, 3, 4). Not a filling
   bar; discrete heads, because the counts are tiny.
2. **Minggu** — a small calendar grid; one cell fills per week of the grade.
3. **Tingkat (difficulty)** — a **gauge bar + a single word**, deliberately **no
   raw number**. The word is the point: it makes the player weigh the challenge
   instead of doing arithmetic. Green→amber→red as it climbs.

### Data (from `Scripts/Balance.gd`, do not hardcode elsewhere)

| Grade | Weeks (`JUMLAH_MINGGU_KELAS_*`) | Target uplift (`TARGET_KENAIKAN_KELAS_*`) | Roster size | Difficulty word |
|---|---|---|---|---|
| 7 | 6 | +15 | 2 | santai |
| 8 | 12 | +34 | 3 | menantang |
| 9 | 16 | +40 | 4 | susah |

- Weeks and target uplift **must be read from `Balance.gd`**, never re-typed, so
  the screen can't drift from balance.
- Roster size (2/3/4) is stated by the game designer. **Verify** against however
  `GameState` builds the roster for a grade; if the real count differs, the head
  icon must reflect the real count, not this table.
- The difficulty word is presentational. Put it in a documented `const` map in
  the level-select script (per the CLAUDE.md rule: new tunable values live in a
  named `const` block, never inline). Suggested comment cites the reasoning below.

### Why the difficulty word is honest (rationale for the reviewer)

Weeks and target are a *pair* — `Balance.gd` says so
("keduanya bareng yang menentukan satu kelas terasa adil atau mustahil"). Each
student has 3 academic targets; clearing one means raising that subject by the
grade's uplift, and per-day learning points *drop* each grade
(`BELAJAR_POIN_KELAS_*`: 3.0 / 2.5 / 2.0). So the study-days a grade demands vs.
the days it gives:

| Grade | Study-days to clear 1 pupil (3 subjects) | Days available (weeks×5) | Rest slack |
|---|---|---|---|
| 7 | ~15 | 30 | ~50% free → santai |
| 8 | ~41 | 60 | ~32% free → menantang |
| 9 | ~60 | 80 | ~25% free → susah |

The "+15 / +34 / +40" number alone *undersells* Kelas 9 because it hides the
pts/day drop. The word carries the felt difficulty the number doesn't.

## 5. Confirmation (the opened envelope)

Tapping "Buka map ini" opens an in-scene confirmation overlay (a Scrim +
centered envelope), NOT a plain dialog:

1. The envelope's **flap folds open** and the **wax seal pops off**.
2. The grade's **pupils peek out** over the envelope's top edge (2/3/4 faces).
3. A **surat tugas** card appears with the grade title, a one-line brief, and
   the difficulty **word** (still no raw target number — the mystery is
   intentional).
4. Buttons: **Terima tugas** (commit) / **Batal** (reseal, return to picker).

Pupil faces should use real student portraits via `StudentSkins`
(`portrait_for` / `face_base_for`), so the worn skin shows — never a static
placeholder, per CLAUDE.md's StudentSkins rule.

## 6. Integration & flow

- On **Terima tugas**: set the grade, then `Transition.change_scene(...)` into
  the normal start-of-game flow. Grade is set via `GameState.set_grade(g)` if it
  exists, else `GameState.current_grade = clampi(g, 7, 9)` — mirror
  `Scripts/Debug/DebugManager.gd:_set_grade()` (line ~672).
- The game's real entry today is `main_menu.gd` → WIPE →
  `res://Scenes/CutScene/cut_scene.tscn`. **Decision needed (see §9):** does this
  screen sit between MainMenu and CutScene, or replace the debug picker's slot?
  Whichever, the commit path ends in a single `Transition.change_scene` to the
  same next scene the flow already uses.
- Keep the DEBUG LEVEL / SKIP dev controls reachable and unchanged.

## 7. Scene & node structure (design-system compliant)

Follow CLAUDE.md's visual rules strictly. Key constraints:

- **No `theme_override_*`.** Use `ThemeFactory` type variations
  (`DisplayLabel`/`H1Label`/`CaptionLabel`, `Card`, `Scrim`,
  `PrimaryButton`/`SecondaryButton`, `StatBar`, …). If a needed variation is
  missing, add it in `ThemeFactory.gd` and rebake — do not reach for overrides.
  Layout-only constant overrides (`separation`, `margin_*`) are the sole allowed
  exception.
- **No visual built at runtime.** Static chrome is nodes in the `.tscn`. The
  envelope is a **`PackedScene` template** instanced ×3 — not three
  hand-built node trees, and not constructed in `_ready()`.
- **`@tool` + documented:** every script gets a `##` file header and a `##` line
  on every `@export` (enforced by `tests/test_script_documentation.gd`). Runtime
  side effects gated behind `if Engine.is_editor_hint(): return`, signal wiring
  ungated — copy the pattern in `main_menu.gd`.
- **Tall phones:** background Full Rect + Keep Aspect Covered; UI re-anchored
  inside `SafeAreaMargin` → `UI`. Pinned by `tests/test_tall_screen_layout.gd`.

Suggested files (names are a starting point):

```
Scenes/LevelSelect/level_select.tscn        # the screen
Scripts/LevelSelect/level_select.gd         # @tool, owns nav + state + commit
Scenes/LevelSelect/AmplopCard.tscn          # one envelope, PackedScene template
Scripts/LevelSelect/AmplopCard.gd           # @tool, @export grade/label/textures
Scenes/LevelSelect/OpenAmplopConfirm.tscn   # the open-envelope confirmation
Scripts/LevelSelect/OpenAmplopConfirm.gd    # @tool
```

- `AmplopCard` carries its data as `@export`s **on its root** (grade, tab label,
  envelope/flap/seal textures) — remember overrides on an instance's *children*
  are dropped on save (CLAUDE.md save-hazard 2); this is why `ShopHubTile` and
  `ActivityRow` expose root `@export`s.

## 8. Art & assets

All envelope art is **placeholder-replaceable at a fixed path** (see the
reference amplop PNG the designer supplied: kraft body, navy/maroon striped
border, red button-and-string wax seal). Register new placeholders in
`docs/superpowers/DEBT.md` per the asset-constraints rule. Pupil faces come from
`StudentSkins`, not static textures.

## 9. Open questions for the implementer (resolve in the plan)

1. **Placement in the flow (§6):** new scene between MainMenu and CutScene, or a
   promotion of the existing debug picker's slot? Confirm with the team.
2. **Roster size source (§4):** is 2/3/4 a real per-grade roster count in
   `GameState`, or designer intent? The head icon must match the real count.
3. **Where DEBUG LEVEL / SKIP live** on the new screen (keep them as a small dev
   affordance, unchanged).

## 10. Tests to add

Follow the established **source-scan** style (`src.contains(...)`) where live
instantiation isn't possible; add behavioral checks where the node tree can be
built in-editor. At minimum, a `tests/test_level_select.gd` (`@tool`, extends
`McpTestSuite`, no coroutines) asserting:

- three `AmplopCard` instances exist, one per grade 7/8/9;
- weeks/target come from `Balance.gd` (scan for the constant reads, not literals);
- the difficulty word map covers all three grades;
- commit path calls the grade setter and a single `Transition.change_scene`;
- **no `theme_override_*`** anywhere in the scene (mirror the existing
  no-override traversal check);
- documentation present on every script and `@export`.

## 11. Out of scope

Gameplay/balance changes, new persistence, the CutScene/StudentCard screens
themselves, and any change to how grades advance mid-run. This screen only picks
a grade and hands off.
