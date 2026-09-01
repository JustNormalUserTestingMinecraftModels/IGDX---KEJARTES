# Art Pass & Screen Restyle — Design Spec

**Date:** 2026-09-01
**Branch:** `Textures`
**Status:** approved for planning

Five requests, delivered as one art batch:

1. Give ReportCard the same UI as StudentCard, showing each student's *current*
   stats.
2. Match AturJadwal to `mockup_atur_jadwal.png`, keeping the whiteboard and
   sticky notes as they are; separate the splash art from the progress pills;
   tapping the splash art opens StudentList.
3. Use the new splash art supplied in `~/Downloads`.
4. Rebuild the intro cutscene against `mockup_intro_cutscene.png`, moving the
   text into `cutscene_dialogue.png`.
5. Use `blur_background` on DaySummary, ResultCheckup and AturJadwal.

---

## 1. Three findings that change what the work actually is

Investigation turned up three cases where the shipped code already does part of
what was asked, and the real defect is elsewhere. Recording them here because
they redirect three of the five plans.

### 1.1 "blur_background" is a texture, not the blur shader

The project has a screen-space blur shader (`Scripts/Shaders/blur.gdshader`,
sampling `hint_screen_texture`), and AturJadwal **deliberately removed** it —
`Scripts/AturJadwal/atur_jadwal.gd:103` and `:807-809` both carry comments
saying the `&"Scrim"` Panel *replaces* "the old ad-hoc blur shader ColorRect".

The request is not a reversal of that decision. `blur_background.png` is a
**pre-blurred raster** of a classroom (369×654, fully opaque, warm). The
AturJadwal mockup confirms it: the top band of the mockup is exactly that image
stretched. So this work adds a **static textured backdrop**, and the Scrim
decision stands untouched.

This also dissolves the objection that a screen-space blur is meaningless on
ResultCheckup (a full scene, not a modal, so there is nothing behind it to
sample). A texture has no such problem.

### 1.2 ReportCard already shows live stats

`Scripts/ReportCard/report_card.gd:58` reads `GameState.approved_students`
directly, and `:70-79` re-renders on window focus. Both screens already call the
same shared renderer, `StudentCardView.populate(...)`.
`tests/test_student_card_layout.gd:61` pins the live read.

So "showing the current updated stats" is already true. What is *not* true is
that the two screens **look** the same. `report_card.tscn` is a stale hand-edited
copy of `student_card.tscn`, and three concrete divergences make it render
differently:

- **Stale `CARD_ROW_ORDER`** (`report_card.gd:229-231`) names four nodes that
  `tests/test_student_card_layout.gd:224` asserts must *not* exist (`Nama`,
  `Profil`, `Kepribadian`, `Akademis`), and omits `BioPanel` and all five
  `Icon*` clusters. On ReportCard the bio panel and stat icons therefore never
  take part in `Juice.stagger_in` — they pop in unanimated.
- **30 baked `self_modulate` colour lines** in `report_card.tscn` that
  `student_card.tscn` does not have (e.g. `report_card.tscn:1172`). These are
  `StatBar._apply_tint()` results that the `@tool` script serialised into the
  scene; they fight the live tint.
- **`KertasMurid1`'s trait pills are hand-tuned differently.**
  `report_card.tscn:1151-1153` gives `KutuBuku` height 137 where every other
  card in both scenes uses 104; `KutuBuku2` at `:1165-1167` likewise.

The work is **parity**, not a port.

### 1.3 Tapping AturJadwal's splash art already opens StudentList

`atur_jadwal.gd:674-687` (`_on_select_student_pressed`) already calls
`Transition.change_scene("res://Scenes/StudentList/student_list.tscn")`, wired
at `:403-408`.

The real defect is the second half of that request. The five stat bars live in
`BGStat`, which is a **child of the splash-art `TextureButton`**
(`atur_jadwal.tscn:158-238`). The pills are inside the button's hit area, so
tapping a progress pill navigates away. That is what "separate the student
splash art from the progress pill" means, and it is a genuine bug.

---

## 2. Asset policy

All source art is in `C:\Users\user\Downloads\`, dated 2026-09-01.

| Source file | Size | Destination | Action |
|---|---|---|---|
| `splash_marcel.png` | 1080×1920 | `Assets/Images/SplashArtMurid/splash_marcel.png` | **replace** |
| `splash_doni.png` | 1080×1920 | `Assets/Images/SplashArtMurid/splash_doni.png` | **new** |
| `splash_andi.png` | 1080×1920 | `Assets/Images/SplashArtMurid/splash_andi.png` | **replace** |
| `splash_citra.png` | 1080×1920 | `Assets/Images/SplashArtMurid/splash_citra.png` | **new** |
| `splash_shinta.png` | 1080×1920 | `Assets/Images/SplashArtMurid/splash_shinta.png` | **replace** |
| `splash_thea.png` | 1080×1920 | `Assets/Images/SplashArtMurid/splash_thea.png` | **replace** |
| `blur_background.png` | 369×654 | `Assets/Images/UI/blur_background.png` | **new** |
| `cutscene_dialogue.png` | 1080×1080 | `Assets/Images/UI/cutscene_dialogue.png` | **new** |
| `whiteboard.png` | 1080×1920 | — | **skip: byte-identical to the shipped `Assets/Images/UI/whiteboard.png`** (md5 `d2512f1b…`) |
| `mockup_atur_jadwal.png` | 1080×1920 | `docs/superpowers/mockups/` | reference only |
| `mockup_intro_cutscene.png` | 1080×1920 | `docs/superpowers/mockups/` | reference only |

The four *replaced* splashes are **not** the files already in the repo — every
md5 differs. Treat all six as one new batch.

**Never hand-author `.import` files.** Copy the PNG in, then run
`filesystem_manage(op="scan")`; Godot generates the `uid://` and the
`.godot/imported/*.ctex` path. Copying a uid from another asset is the exact
failure `tests/test_project_hygiene.gd:48-72` exists to catch.

### 2.1 Splash art measurements

All six are full-bleed 1080×1920 transparent cut-outs of a standing figure.

| File | Opaque bbox (x0,y0,x1,y1) | Opaque w×h |
|---|---|---|
| `splash_marcel.png` | 225, 59, 936, 1908 | 711×1849 |
| `splash_doni.png` | 154, 143, 926, 1912 | 772×1769 |
| `splash_andi.png` | 183, 15, 929, 1917 | 746×1902 |
| `splash_citra.png` | 264, 83, 949, 1899 | 685×1816 |
| `splash_shinta.png` | 267, 129, 926, 1915 | 659×1786 |
| `splash_thea.png` | 201, 104, 956, 1906 | 755×1802 |

### 2.2 `blur_background.png`

369×654, aspect 0.5642 against the screen's 0.5625 — a 0.3% difference, so it
stretches to any full-width band with no visible distortion. Fully opaque.
Corner samples TL `#AB9080`, TR `#C6B5AA`, BL `#AB9B98`, BR `#B2A29E`, centre
`#FDCBA4`.

It is small on purpose (already-blurred raster). Import with filtering on; use
`expand_mode = 1` (`EXPAND_IGNORE_SIZE`) and `stretch_mode = 6`
(`STRETCH_KEEP_ASPECT_COVERED`) so it fills without letterboxing.

---

## 3. The splash art batch invalidates the DaySummary avatar crops

`Scripts/SchoolSimulation/DaySummaryAvatar.gd:23-28` holds a per-student
`SPLASH_CROP` of head-and-shoulders windows, in each splash's own pixels,
shaped to `FRAME_ASPECT` (269/286 ≈ 0.94056). Those rects were derived from the
**old** art. Every source file has changed, and Thea's canvas changes from
550×1119 to 1080×1920, so all four existing entries are now wrong and two
students had no entry at all.

New rects, derived from each file's opaque bbox — head band taken as the top 18%
of the figure, crop height 42% of figure height, centred on the head, nudged 1%
above the crown so hair is not clipped:

```gdscript
const SPLASH_CROP := {
	"Marcel": Rect2(132, 40, 736, 782),
	"Doni": Rect2(192, 125, 702, 746),
	"Andi": Rect2(112, 0, 752, 800),
	"Citra": Rect2(167, 65, 726, 772),
	"Shinta": Rect2(160, 111, 707, 752),
	"Thea": Rect2(154, 86, 718, 763),
}
```

Every rect is inside its texture and within 0.002 of `FRAME_ASPECT` — the
existing tests allow 0.02 (`test_day_summary.gd:218`).

### 3.1 The pre-planned flip

`DaySummaryAvatar.gd:48-50` says:

> Resolution order: the student's portrait first, then their splash art, then
> nothing. The portrait leads because the splash batch is being replaced —
> **flip these two branches back once the new art lands.**

The new art is landing. `set_student` must flip to splash-first, portrait-second.
`tests/test_day_summary.gd:979-987` currently asserts the *opposite* order by
source-index comparison and must flip with it.

### 3.2 The roster is triplicated

The `splash` key still points at the legacy `SplashMurid{N}.jpg` in **three**
places, all of which must change together:

- `Scripts/StudentCard/student_card.gd:896-1034` — `student_data_list`, the
  de-facto source of truth (richest: adds `persona`, `profil`,
  `jenis_kelamin`, `tanggal_lahir`)
- `Scripts/StudentList/student_list.gd:22-137` — `default_students`
- `Scripts/Debug/DebugManager.gd:30+` — `DEFAULT_STUDENTS`

| id | name | new `splash` |
|---|---|---|
| 1 | Marcel | `res://Assets/Images/SplashArtMurid/splash_marcel.png` |
| 2 | Doni | `res://Assets/Images/SplashArtMurid/splash_doni.png` |
| 3 | Andi | `res://Assets/Images/SplashArtMurid/splash_andi.png` |
| 4 | Citra | `res://Assets/Images/SplashArtMurid/splash_citra.png` |
| 5 | Shinta | `res://Assets/Images/SplashArtMurid/splash_shinta.png` |
| 6 | Thea | `res://Assets/Images/SplashArtMurid/splash_thea.png` |

The six legacy `SplashMurid{1..6}.jpg` become unreferenced. Leave them on disk —
deleting them is out of scope and risks a stale `uid` elsewhere.

---

## 4. `mockup_atur_jadwal.png` — measured geometry

Band structure, from a full-width sharp-edge scan:

| Band | y range | Content |
|---|---|---|
| Backdrop | 0…765 | `blur_background.png`, with splash art + 5 stat rows over it |
| Shelf, light | 766…816 | flat `#B37D4D`, 51 px |
| Shelf, dark | 817…842 | flat `#77573A`, 26 px |
| Panel | 843…1919 | flat `#ECECEC` — the existing whiteboard + sticky notes |

### 4.1 Splash art placement

Figure bbox in the mockup: **x 47…416 (w 370), y 56…765 (h 710)**. The figure is
cut off by the shelf at y=766, i.e. it runs off the bottom of the backdrop band.

### 4.2 The five stat rows

| Row | Stat | Pill y | h | Pill x | w | Icon centre |
|---|---|---|---|---|---|---|
| 1 | Akademis | 129…198 | 70 | 651…973 | 323 | 566, 155 |
| 2 | Seni Budaya | 258…327 | 70 | 651…973 | 323 | 568, 287 |
| 3 | Olahraga | 384…453 | 70 | 651…973 | 323 | 569, 418 |
| 4 | Energy | 511…583 | 73 | 649…971 | 323 | 574, 547 |
| 5 | Mood | 628…701 | 74 | 649…971 | 323 | 572, 665 |

Pill fill `#363636`, corner radius ≈ 20 px (the inset profile converges by
dy≈12, so it is not a stadium). Icons are vertically centred on their pill
(max delta 8 px).

**Deviation:** the mockup's row pitch is irregular — 129, 126, 127, 117,
averaging 124.75 — because the art was hand-placed. The build uses a **uniform
126 px pitch** starting at y=129, which lands rows at 129 / 255 / 381 / 507 /
633 (max drift from the mockup 5 px, invisible at this scale) and keeps the
layout expressible as a container with one separation constant.

### 4.3 What the mockup does *not* drive

The mockup's lower panel shows a title reading "MINGGU 1 DARI 24" (centred,
bbox x 253…827, y 901…942) and 220×228 sticky notes on a 347 px grid. The
shipped scene has 271×267 notes at entirely different coordinates, and its week
readout is `TanggalContainer/LabelTanggal` rendering "Agustus — Minggu Pertama",
which never says "dari N".

**Per the request, the whiteboard and sticky notes stay exactly as they are.**
The lower-panel geometry above is recorded for reference only. `LabelTanggal`
keeps its current wording; changing it is not in scope.

---

## 5. `mockup_intro_cutscene.png` — measured geometry

Everything above the dialogue panel is pure white in the mockup: the CG fills
the frame behind, and the panel sits over its lower third.

- Panel on screen: **x 68…1015, y 1105…1856** → **948 × 752**; margins left 68,
  right 65, bottom 64.
- `cutscene_dialogue.png` is 1080×1080 with its opaque panel at **x 66…1013,
  y 164…915** → **948 × 752**. Identical size — the art is 1:1, no scaling.

**Placement rule:** put the texture at offset **(0, 940)** at native size. The
opaque panel then lands at x 66…1013, y 1104…1855 — within 1 px of the mockup on
every edge. The transparent remainder overflows the 1920 bottom harmlessly.

Border structure, measured on the centre row and column:

| Layer | Colour | Thickness |
|---|---|---|
| Outer frame | `#CA7B35` | ~32 px |
| Inner frame | `#85562C` | ~11 px |
| Fill | `#FFFFFF` | remainder |

Inner white content area on screen: **x 110…967, y 1148…1815 → 858 × 668**. Text
insets sit inside that.

### 5.1 Current state

`Scenes/CutScene/cut_scene.tscn` has `DialogueBox` (a `Panel`,
`theme_type_variation = &"Card"`) at offsets 165,629 → 908,896, with
`DialogueLabel` (`RichTextLabel`) inside it. The panel must move to the measured
rect and draw `cutscene_dialogue.png` instead of the `Card` stylebox.

`tests/test_cutscene.gd` asserts `box.theme_type_variation == &"Card"`
(`test_dialogue_box_uses_the_card_variation`). That test must change with the
scene — it is pinning the old design, not an invariant.

The CG is `BgCutScene` (`TextureRect`, `stretch_mode = 6`), textures preloaded in
the `cg_data` array at `cut_scene.gd:33-54`. `BgCutScene` (1075×1925) and
`FadeOverlay` (1088×1934) are both hardcoded rects that miss 1080×1920; correct
them while in there.

---

## 6. Global constraints

Every plan in this batch inherits these.

- **Godot 4.6**, portrait 1080×1920, `mobile` renderer.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only
  layout-only constant overrides (`separation`, `margin_*`) are accepted.
  Enforced per-scene by `test_*_has_no_theme_overrides` in six suites.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`;
  repeated rows are a `PackedScene`; responsive geometry is a `@tool` script
  driven by documented `@export` knobs. Enforced by
  `tests/test_viewport_editability.gd` — a per-file `BASELINE` ratchet that
  **may only go down**, and fails equally if a count drops without the dict
  being edited in the same commit.
- **No `Color(` literal in any screen script.** Enforced by
  `test_no_hardcoded_colors_remain_in_the_script` in several suites. Read from
  `DesignTokens`.
- **Every script needs a `##` header** in its first 12 lines and a `##` line
  immediately above every `@export`, with no blank line between. Enforced by
  `tests/test_script_documentation.gd`.
- **Art references are `@export var …: Texture2D`**, not `load("res://…")` in a
  function body.
- **Tests must be `@tool`, and no test may be a coroutine** — the runner calls
  `suite.call(name)` without awaiting, so an `await` silently aborts the test
  and scores it as a false pass.
- **Rescan before running tests** after editing any `.gd`
  (`filesystem_manage(op="scan")`), or `test_run` serves a stale autoload.
- **Adding a ThemeFactory variation requires a manual rebake**: open
  `Scripts/Design/BakeTheme.gd` in the editor, File > Run (Ctrl+Shift+X). There
  is no headless path. Suites that load the baked `.tres` from disk will fail
  until it is rerun.
- Game-facing identifiers and UI text are **Indonesian**; engine and systems
  code is English.
- Commits are Conventional Commits with a scope.

### 6.0 Never hand-edit a `.tscn` — mutate through the editor

Learned the hard way on 2026-09-01 while executing plan 2. Editing a `.tscn`
as text **does not work** while the Godot editor is attached:

- Godot caches the `PackedScene` by path. A test calling `load(path)` keeps
  getting the **stale** scene.
- `filesystem_manage(op="scan")` does not evict it. Neither does
  `op="reimport"` (a `.tscn` is not an imported resource — it reports under
  `skipped_non_imported`). Neither does `scene_open(force_reload=true)`, which
  returned `reloaded_from_disk: false`.
- Worse, the editor's in-memory copy is authoritative: the next `scene_save`
  **silently overwrites** the hand-edited file.

The working procedure, and the only one to use:

1. `scene_open(path)`
2. `node_create` / `node_set_property` / `node_manage(op="move"|"reparent"|…)`
3. `scene_save`

Notes from doing it: `anchors_preset` is an inspector-only helper and silently
does nothing — set `anchor_left/top/right/bottom` individually. Numeric
properties reject `"1.0"` as a string (`WRONG_TYPE`); pass `1`. `node_create`
appends as the last child, so a node that must render behind its siblings
needs `node_manage(op="move", index=0)` afterwards. On save, the editor
rewrites the whole file — adding `uid=` to every `ext_resource` and
`unique_id=` to every node — so expect a larger diff than the change implies,
and let it generate the uid rather than supplying one.

Consequence for the plans below: every step phrased as "in `X.tscn`, change
`offset_top = …`" states the **intended end state**, not the mechanism. Apply
it with `node_set_property`, then `scene_save`.

### 6.1 Node paths frozen by tests

Renaming or reparenting any of these breaks a suite. Check before moving.

| Path | Pinned by |
|---|---|
| `TextureButton` (AturJadwal splash) and `TextureButton/BGStat/{Akademis1,Akademis2,Akademis3,Kepribadian1,Kepribadian2}` | `test_atur_jadwal.gd:193` |
| `BGHari/{Senin,Selasa,Rabu,Kamis,Jumat}` | `test_atur_jadwal.gd:87,111` |
| `Penjadwalan/TextureRect/Rows`, `.../PopupBack` | `test_atur_jadwal.gd:142,187`, `test_wirausaha.gd:26` |
| `Margin/VBox/ScrollContainer/MainContent/StudentsContainer`, `.../HistoryList`, `Margin/VBox/BtnClose` (ResultCheckup) | `test_result_checkup.gd` |
| `KertasMurid1..6` and every per-card child name (both card scenes) | `test_student_card_layout.gd` |
| `KertasMurid1/Kepribadian1`, `KertasMurid1/KutuBuku` (tutorial targets) | `test_student_card.gd:194` |
| ReportCard must keep resolving `find_child("BackButton")` and must keep returning `null` for `Aprove` / `StampApprove` / `BelajarButton` **recursively** | `test_report_card.gd:23-39,69` |

The last row is why ReportCard cannot simply instance `student_card.tscn` as a
sub-scene: `find_child(..., recursive = true)` would find the approve chrome
inside it.

---

## 7. Plans produced from this spec

| # | Plan | Covers | Depends on |
|---|---|---|---|
| 1 | `2026-09-01-splash-art-batch.md` | Request 3 — import the batch, rewire all three rosters, recrop the avatars, flip the resolution order | — |
| 2 | `2026-09-01-blurred-backdrop.md` | Request 5 (DaySummary, ResultCheckup) | 1 |
| 3 | `2026-09-01-report-card-parity.md` | Request 1 | — |
| 4 | `2026-09-01-atur-jadwal-mockup.md` | Request 2, and request 5's AturJadwal half | 1, 2 |
| 5 | `2026-09-01-intro-cutscene-mockup.md` | Request 4 | 1 |

Plans 1→2→4 are a chain. Plan 3 and plan 5 are independent of everything except
the asset import in plan 1 (plan 3 needs nothing at all).

---

## 8. Out of scope

- Deleting the six legacy `SplashMurid{N}.jpg` files.
- Changing `LabelTanggal`'s wording to the mockup's "MINGGU 1 DARI 24".
- Moving AturJadwal's sticky notes or whiteboard to the mockup coordinates.
- Reinstating the screen-space blur shader anywhere (see §1.1).
- Extracting a shared `KertasMurid` PackedScene from the two card scenes —
  worth doing, but it would rewrite two test suites and is a separate project.
- `Scripts/Lobby/loby.gd:487-503`'s surviving `ShaderMaterial.new()` blur.
- The latent crossed-assignment redundancy at `StudentCardView.gd:79-84` (the
  values are immediately overwritten correctly by `build_stat_bars`, so it is
  dead code, not a live bug).
