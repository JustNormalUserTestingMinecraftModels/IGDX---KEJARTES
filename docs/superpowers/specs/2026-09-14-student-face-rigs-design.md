# Student face rigs for the whole roster — design

Agreed 2026-09-14 (via `/gamecode`, one Brief, approved "yes").

## What the player gets

Every student seated in the Lobby diorama gets a living layered face — the
pupils glance around exactly as Citra's already do — instead of a flat
portrait. Citra has had one since 2026-09-06 (`Scenes/Lobby/CitraFace.tscn`);
this pass adds Andi, Doni, Marcel, Shinta and Thea.

```
StudentCard → Lobby  ← NEW: Andi, Doni, Marcel, Shinta, Thea get live faces
            → AturJadwal → StudentList → SchoolDay → ResultCheckup
```

Same in every grade. No game state is read or written: this is art, scenes
and one Lobby inspector list.

## Source art

Google Drive folder "Aset terpisah"
(`1nIRi9VaZ-yUQq3hkqAHnnd_wbFiZ-x60`), one subfolder per student. Files are
numbered by layer:

| # | Layer | Node | File |
|---|---|---|---|
| 1 | Base | `Base` | `<name>_base.png` |
| 2 | Sclera | `Sclera` | `<name>_sclera.png` |
| 3 | Pupil | `Pupil` | `<name>_pupil.png` |
| 4 | Eyelashes | `Eyelashes` | `<name>_eyelashes.png` |
| 5 | Eyelid | `Eyelid` | `<name>_eyelid.png` |
| 6 | Eyebrows | `Eyebrows` | `<name>_eyebrows.png` |
| 7 | Glasses (Marcel only) | `Glasses` | `marcel_glasses.png` |

Names follow Citra's real files (`citra_base.png`, lowercase student first),
into `Assets/Images/MuridPotrait/<Name>/`. The files come down through the
user's logged-in Chrome into `C:/Users/user/Downloads/`; every file on the
Drive has a distinct byte size, which is how each download is matched back to
its student and layer number.

The Drive's Citra subfolder holds named files dated after her rig was built.
They are compared against the imported ones and any difference is reported,
not swapped in.

## Placement — solved, not eyeballed

The layers arrive as separate crops with no canvas offsets. Each student's
current flat sprite (`Assets/Images/MuridPotrait/<Name>.png`, 1280×1280) is
the reference: each crop is template-matched onto it, the method used for
Citra (see the 2026-09-06 CHANGELOG entry). Where the base carries
transparent eye cut-outs, Sclera and Eyelid are pinned by plugging them.
The Eyelid is the closed-eye pose and is not visible in the open-eyed sprite,
so if it cannot be matched to the portrait it is pinned by the cut-out or,
failing that, centred on the Sclera; the report says which.

**Marcel's glasses** go wherever his portrait shows them: the draw order is
the one whose composite reproduces `Marcel.png` best. A layer that matches its
portrait nowhere stops the pass and is reported rather than guessed.

The solve runs from a scratch Python script (numpy/PIL/scipy) and is not
committed; its results are frozen in the new test suite.

## Scenes

- `Scenes/Lobby/<Name>Face.tscn` ×5 — structurally a copy of `CitraFace.tscn`:
  root `Control` named `<Name>Face` with `StudentFace.gd`,
  `student_name = "<Name>"`, a `Canvas` holding the layers as `TextureRect`s at
  their solved canvas-pixel offsets and native sizes, `Eyelid` hidden. Marcel
  adds a `Glasses` TextureRect at its solved draw position.
- `Scenes/Lobby/<name>_eye_mask.tres` ×5 — a copy of `citra_eye_mask.tres`
  pointing `mask_texture` at that student's sclera, `resource_local_to_scene`.
- `Scenes/Lobby/loby.tscn` — the `face_rigs` export lists all six rigs. The
  Citra-only fallback in `loby.gd` stays as it is.
- `Scripts/Lobby/StudentFace.gd` — header documents that a rig may carry extra
  always-visible layers (Marcel's `Glasses`) beyond `LAYER_NAMES`; no
  behaviour change. Gaze and blink defaults stay untouched.

## Tests

- `student_face` — unchanged; it pins Citra.
- **New** `face_rig_roster` (`tests/test_face_rig_roster.gd`): for each of the
  six rigs — the rig loads as a `StudentFace` whose `student_name` matches;
  layer order (plus Marcel's `Glasses`); each layer's solved position and
  native size (a `_GEOMETRY` table); textures from that student's folder;
  Eyelid alone starts hidden; the pupil mask uses that student's own sclera
  and is local to the scene; `loby.tscn` lists every rig; every roster name
  in `student_list.gd` has a rig.

## Docs

- `docs/superpowers/DEBT.md` — delete "Layered faces exist for Citra only".
- `docs/superpowers/CHANGELOG.md` — new entry, newest first.
- `CLAUDE.md` — suite/test count line.

## Not doing

Re-importing Citra; turning idle blinking on; per-student gaze tuning;
committing the solver script.

## As built

What the art turned out to be, and what that changed:

- **Numbering.** The Drive numbers did not follow Base, Sclera, Pupil,
  Eyelashes, Eyelid, Eyebrows for every student. File 4 is the closed eyelid
  and 5 the lashes for all five, and 2/3 are pupil/sclera for Doni, Marcel,
  Shinta and Thea (Andi's 2/3 are as stated). Established by which layer
  plugs the eye cut-outs, which matches the portrait, and a contact sheet.
  The files are named by role.
- **Citra's Drive copies** are byte-identical to the imported art; nothing
  to report.
- **Eyelid fallback** was never needed: every base has cut-outs to pin it.
- **Shinta** shows one eye (the other is under her hair). Her portrait is a
  darker grade of her base, so matching ran through a per-channel recolour
  fitted base -> portrait. Her base's second transparent hole is a gap in the
  hair, also transparent in the portrait, so it is left open.
- **Marcel's glasses** are the top layer, as his portrait shows. Their lens
  is additive in the portrait while the frame is opaque. That needed two
  files the Brief did not list: `Scripts/Shaders/glasses_lens.gdshader`
  (`blend_premul_alpha`) and `Scenes/Lobby/marcel_glasses_lens.tres`
  (`lens_gain` 1.173, fitted). His lashes sit under the tinted lens and were
  found by where they darken the face.
- **See-through budget.** A few anti-aliased cut-out rim pixels are covered
  by no layer in any placement: Doni 5, Marcel 10. The suite freezes them.
- **Andi's** layered eye opening is shorter than his pupil art, so the top
  of the iris always tucks under the lash line.
- **Citra's committed rig** leaves 114 cut-out pixels uncovered at Sclera
  y=578 (y=579 covers them). Recorded in DEBT.md and handed off; not changed
  here.
