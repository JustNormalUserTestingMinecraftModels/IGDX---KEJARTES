# Tutorial box: one Nota Guru note, one placement, less dialogue

**Date:** 2026-10-16
**Status:** design, awaiting owner review
**Supersedes direction of:** `specs/2026-10-07-tutorial-visual-overhaul-design.md`
(the Nota Guru box shipped; this tightens placement and voice)

## 0. Guardrails (unchanged from the overhaul)

1. **Ask before any new tweak.** Copy, visuals and scope here are relayed
   mentor direction. No improvising beyond what this doc locks.
2. **No new art.** Every surface reuses already-finished assets or the
   existing placeholder SVGs. Any gap goes in `DEBT.md`, not into a new
   drawing. No emoji/icon-font iconography.
3. **No `theme_override_*`.** New looks are `ThemeFactory` variations, rebaked.
4. **`Balance.gd` untouched.**

## 1. Problem

Two faults, both visible in the 2026-10-16 captures:

- **The box drifts.** The welcome comic is a plain white card with no mascot;
  the spotlight steps are the Nota Guru note; CARA MAIN is a third frame
  without Pak Kepsek. Three looks for one voice.
- **The note over-talks.** Spotlight steps carry two or three full sentences
  ("Ini Energi. Tiap kegiatan menguras energi. Kalau habis, Marcel terpaksa
  izin istirahat.") — the "text assault" the overhaul set out to kill,
  resurfacing one layer down.
- **Placement bugs** (`DEBT.md`, 2026-10-13 known gap): the mascot stands
  196px above the card's own rect, which `TutorialPanel.placement()` and
  StudentCard's `_tutorial_card_rect()` do not account for. Where the card
  seats at the top of Safe/UI the mascot rides above the safe area; a low card
  can cover what sits just above it. The arrow can also land on a neighbouring
  button (energy step → mood bar; Lobby step → JADWAL).

## 2. Direction (owner-picked)

**Voice B — label on the thing, note is one nudge.** The spotlight already
lands on the real UI element, and that element already carries its own fixed
label and icon in the scene. So the note stops naming the thing and gives a
single consequence/nudge line instead.

- Each `KertasMurid*` stat bar in `StudentCard.tscn` already has a `Label`
  child (`ENERGY`, `MOOD`, `AKADEMIS`, `SENI BUDAYA`, `OLAHRAGA`), a value
  readout and an icon. The spotlight frames that finished row; the note no
  longer repeats "Ini Energi".
- **One nudge line per spotlight step.** Target ≈ 8 words, one clause of
  consequence. Draft copy in §4; owner approves the final strings.

**Consistent, not identical.** The welcome comic (goal-setting) and CARA MAIN
(a numbered rules list) cannot become one line. They keep the shared Nota Guru
frame, name tab, mascot, LEWATI, tap-prompt and step pill — same chrome, same
positions — but their body stays multi-element. Consistency is the frame and
the chrome, not the word count.

## 3. Placement — the one function

`TutorialPanel.placement(bounds, panel_size, spot, arrow_size)` gains a
`head_room` term equal to the mascot's height, so the card **plus** the mascot
stays inside `bounds`. The function:

- never overlaps the spotlight `spot`;
- keeps the arrow tip clear of any control (a min gap from `spot` edges);
- seats the mascot inside the safe area at every anchor.

StudentCard's separate `_tutorial_card_rect()` / `_tutorial_card_position()`
are deleted and routed through the same function, so there is exactly one
placement path. The tucked-card rect and the popup-floor height guard are
recomputed from the same head-room value (this is the piece the 2026-10-13
note said a naive top margin broke).

Pinned tests (`test_popup_frames`, `test_tall_screen_layout`,
`test_student_card`, `test_atur_jadwal`, `test_lobby`) move with the function.

## 4. Copy (draft — owner approves finals)

Spotlight steps, Grade-7 first run (`FirstRunTutorial.STEPS`). `%s` = student
name. Kept in Indonesian, KBBI-standard.

| Step | Spotlight | Nudge line (draft) | Prompt |
|---|---|---|---|
| Mood | `Mood` bar | `Mood bagus bikin dia semangat; habis, gampang ngambek.` | — |
| Energi | `Energy` bar | `Kalau habis, %s terpaksa izin istirahat.` | — |
| Skill | 3 skill bars | `Tiga skill inilah yang kamu kejar biar dia lulus.` | — |
| Sifat | 2 trait badges | `Ketuk sifatnya untuk baca wataknya.` | `KETUK SEBUAH SIFAT` |
| Sifat (after) | — | `Begitu cara baca sifat murid. Sesuaikan jadwalnya!` | — |
| Mulai | Approve | `Terima %s, lalu kita mulai minggu pertama.` | `KETUK APPROVE` |

Promotion beats (`HeadmasterBeat`) and the pick-TUGAS beat get the same
one-nudge trim, same frame.

## 5. Comic and CARA MAIN — same frame, own body

- **`TutorialComic`** keeps its beats and `finished` signal, but renders
  through the shared note: name tab, mascot, scrim, LEWATI, tap-prompt, step
  pill, all in the §3 positions. Its body keeps the illustration slot
  (`plate_*.svg`, existing placeholder) beside a short line. Placement:
  centred.
- **`MinigameTutorial` (CARA MAIN)** keeps the note, mascot and name tab; its
  numbered step rows and the Mulai button sit in the body. Stays on its
  `CanvasLayer` so minigame layering is unchanged.

## 6. Out of scope

- `EventDialogue` (the in-world event box) — different family, left alone.
- The English stat-bar labels (`ENERGY` vs `ENERGI`) — existing `DEBT.md`
  copy-pass, not this change.
- The reward star and idle-nudge copy still owed in `DEBT.md`.
- `Balance.gd`.

## 7. Testing

- **Pure-geometry tests** for `placement()`: head-room containment at a top
  anchor and a bottom anchor; spotlight non-overlap; arrow-tip clearance; the
  1080×2400 tall-phone case.
- **Source-scan tests** that `TutorialComic` and `MinigameTutorial` instance
  the shared note and carry the mascot/name-tab/pill nodes.
- Updated pinned entries in the suites listed in §3.
- Targeted `test_run` per suite, then one **full-size** screenshot of each of
  the four surfaces (comic, a spotlight step, the Lobby step, CARA MAIN) sent
  to the owner, since this is a visual change.

## 8. Build order (hazard-aware)

Per `CLAUDE.md`: **scene work first, scripts second.** Edit the `.tscn`
through the editor (`scene_open` → node ops → `scene_save`), restart the
editor before patching the scripts, then `script_patch` the `.gd` changes and
rescan before `test_run`.
