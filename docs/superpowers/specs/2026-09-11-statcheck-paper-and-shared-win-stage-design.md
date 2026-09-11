# StatCheck on StudentCard's paper, and one shared win stage — design

2026-09-11. Two independent changes to the end-of-grade sequence, requested
together:

1. "In the end game StatCheck, turn each student page into the paper used in
   StudentCard, use the same icons as the others for akademik, atletik and
   seni budaya, remove the extra details on the paper and put only the
   student name."
2. "In RunResult, combine it with the win screen so the RunResult background
   is directly the win screen that was shown."

They share no code and can land in either order.

Decisions taken with the user during brainstorming:

| Question | Decision |
|---|---|
| What sits on the top of the paper? | The student's photo in the paper's printed frame, and **only the name** on the printed brown plate. |
| How does RunResult get the win screen? | One **shared scene** (`WinStage`) instanced by both EndCutscene and RunResult. Not a merge of the two screens, not a frame snapshot. |
| Blur behind RunResult's report? | **Kept**, exactly as today (lod 3.0, darkness 0.3). |

"Win screen" means what EndCutscene shows after a passed run: the painting
with the run's own students standing on it. `Scenes/EndGame/WinScreen.tscn`
is unused scaffolding and is not touched.

---

## Part 1 — StatCheck's page on StudentCard's paper

### What the player sees

Before: a themed `Card` panel with a purple bio panel (name plus the
`profil` lines "Agama: …" / "Jenis Kelamin: …"), a portrait, and three rows
with placeholder SVG icons.

After: StudentCard's own paper, scaled into the same slot.

| Place on the paper | Content |
|---|---|
| Printed photo frame | The student's photo (`StudentData.avatar_texture`), with StudentCard's `portrait_frame.png` over it. |
| Printed brown plate | The student's name, alone: display face, 96px, cream, centred, upper case. |
| Below | Three `StatCheckRow`s: `stat_akademis.png`, `stat_senibudaya.png`, `stat_olahraga.png` — the art StudentCard, StudentList and AturJadwal already use — each beside its animated bar. |
| Gone | The purple bio panel and every `profil` line. |

The star meter, the fill animation, the pop on a full bar and tap-to-rush are
unchanged. `StatCheck.tscn` is unchanged.

### The source art, measured

`Assets/Images/StudentCard/card_bg.png` is 1080×1920 but is paper only in its
middle. Measured at alpha > 200 on 2026-09-11:

- **Sheet:** x 52..1045, y 238..1558, so `Rect2(52, 238, 994, 1321)`.
  Everything outside is transparent.
- Cream, with a faint radial shading; 0% of opaque pixels are pure white.
- **Printed photo frame:** (136, 294)–(419, 670). This is StudentCard's own
  `PortraitFrame` rect.
- **Printed brown plate:** interior `Rect2(452, 300, 489, 367)`. This is
  `StudentCardView.BIO_PANEL_RECT`.
- **Curl:** a folded corner at the bottom right, inside roughly
  x 890..1045, y 1480..1558.

The three stat icons are 128×128 transparent PNGs.

### Layout

The card root stays 760×1000, so `StatCheck`'s `CardSlot` needs no change.

`Paper` becomes a `TextureRect` showing `card_bg.png` at its **native
1080×1920**, scaled uniformly by **0.757** (= 1000 / 1321). Its position is
**(-35.59, -180.17)**, which puts the sheet at x 3.8..756.2, y 0..1000 of the
card: the full height, centred across the width.

Authoring the paper at native size is the point. Every child is placed in
StudentCard's own card coordinates, so the measured numbers transfer 1:1, and
`PaperShadow.tscn` works unmodified because its geometry is authored in
exactly that space.

Children of `Paper`, in paper space and in draw order:

| Node | Type | Rect / settings |
|---|---|---|
| `PaperShadow` | instance of `Scenes/UI/PaperShadow.tscn` | as in StudentCard; `show_behind_parent` puts it under the sheet |
| `Photo` | TextureRect | (136, 294)–(419, 670); expand IGNORE_SIZE, stretch KEEP_ASPECT_COVERED |
| `PortraitFrame` | TextureRect, `portrait_frame.png` | (136, 294)–(419, 670); mouse ignore |
| `Name` | Label, `PlateNameLabel` | (468, 300)–(925, 667): the plate interior inset 16px left and right; centred both ways; `uppercase = true` |
| `Rows` | VBoxContainer | (132, 740)–(941, 1480); `alignment = center`; separation 64 |

`Rows` holds the three existing `StatCheckRow` instances: `Akademis`, `Seni`
(category `SeniBudaya`) and `Olahraga`. Each gets its `stat_*.png` through
the row's root `icon` export, which serialises on an instance root.

Where the numbers come from:
- **x 132** is where StudentCard puts its stat icons (`PILL_RECTS` x 284,
  minus the 24px gap, minus the 128px icon).
- **x 941** is the plate's right edge, so the rows line up under the header
  block.
- **y 1480** stops the rows short of the curl.

`StatCheckRow.tscn` changes to StudentCard's proportions:

| Node | Change |
|---|---|
| Root | `custom_minimum_size` (520, 96) → (0, 128); `theme_override_constants/separation = 24` (a layout constant, which the override rule allows) |
| `Icon` | 96×96 → 128×128; authored texture `icon_akademis.svg` → `stat_akademis.png` |
| `Bar` | height 56 → 68 (StudentCard's pill height); category and theme family unchanged |

At 0.757 on screen, the paper is 752×1000, the photo 214×285, an icon 97px and
a bar 51px tall.

### The name style: `PlateNameLabel`

This is a new `ThemeFactory` Label variation:
- display face (Boohong), `font_display_size` (96), `text_on_brand` cream
- no outline: the plate is opaque and flat, the same call as
  `TraitPopupNameLabel`

It joins `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`, and the theme is
rebaked.

No existing variation fits:
- `BioValue` is body face at 48, built to sit under a "Nama:" heading.
- The cream display labels that do exist are named for the trait popup, the
  shop hub and the minigame HUD.

Boohong advance widths, measured 2026-09-11 against the 457px `Name` slot:

| Name | 96px | 64px |
|---|---|---|
| MARCEL | 413 | 276 |
| SHINTA | 380 | 253 |
| CITRA | 295 | 197 |
| THEA | 266 | 178 |
| ANDI | 249 | 166 |
| DONI | 249 | 166 |

MARCEL fits at 96 with 44px to spare. A test re-measures all six with the
real font at the variation's real size, so a later size bump fails the suite
rather than clipping on screen.

### Code

- **`StatCheckCard.gd`**
  - `bind()` sets the name, the photo and the three rows. `profil` is no
    longer read.
  - The `@onready` paths follow the new tree.
  - The header explains the paper and why the bio lines are left off.
- **`StatCheck.gd`:** comment only. The `_input()` rationale names "the
  card's Paper" as a MOUSE_FILTER_STOP Panel, which it no longer is. The
  full-screen `Scrim` still is, so the rationale stands.
- **`ThemeFactory.gd`:** `PlateNameLabel`, next to `BioLabel`/`BioValue`.

---

## Part 2 — One win stage for EndCutscene and RunResult

### The problem today

EndCutscene letterboxes the 1536×2048 painting:
- scale min(1080/1536, 1920/2048) = 0.703125
- 1080×1440 of art with 240px navy bars (`bar_color` #141a2e) above and below
- the run's students and their ground shadows posed on it

Pressing *Lanjut* blurs that frame and swaps to RunResult.

RunResult's own `Backdrop` covers the screen with the painting alone:
- scale 0.9375, a 1440×1920 crop
- no students, no shadows, no bars

So the swap jumps in framing and the students vanish. RunResult.gd's header
already promises "the SAME image EndCutscene shows"; it is only half true.

### The shared scene

`Scenes/EndGame/WinStage.tscn` + `Scripts/EndGame/WinStage.gd` (`@tool`,
`class_name WinStage`). Its nodes move out of EndCutscene.tscn unchanged in
shape:

```
WinStage (Control, bare anchor, mouse ignore)
├── BarFill (ColorRect)            letterbox bars; sized by dress()
└── Stage (Control, 1536×2048)     the painting's own art space; fitted by dress()
    ├── Backdrop (TextureRect)     full-rect, KEEP_ASPECT_COVERED
    ├── Shadows (Control)          Shadow1..Shadow4, authored hidden
    └── Students (Control)         Student1..Student4, authored hidden
```

These move with the nodes from `EndCutscene.gd`:
- **Exports:** `win_backdrop`, `lose_backdrop`, the six `win_splash_*`,
  `bar_color`, `shadow_texture`, `shadow_opacity`, `shadow_spread`,
  `shadow_flatness`
- **Constant:** `ART_SIZE`
- **Functions:** `_fit_stage` (letterbox), `_fit_stage_cover` (lose),
  `_splash_for`, `_dress_lineup`

All art defaults live once, in `WinStage.tscn`. Neither host overrides them,
so the two screens cannot show different art.

API:

```gdscript
## Dress for a verdict: the backdrop, the fit, and (win only) the lineup.
func dress(failed: bool, names: Array) -> void
## Names from GameState.approved_students-shaped dictionaries, in roster order.
static func names_of(roster: Array) -> Array
## Where the letterboxed painting lands in `area`: {"scale", "position"}.
static func letterbox(area: Vector2) -> Dictionary
```

What `dress()` does:
- Sizes `BarFill` to the viewport and sets the backdrop.
- Win: letterboxes `Stage` and poses the lineup.
- Lose: covers the viewport with `Stage` and hides all eight slots.

It measures `get_viewport_rect()` exactly as `EndCutscene` does today, which is
correct because it only runs at runtime.

`WinStage` never reads the verdict itself: the host passes `failed` and the
names in. Its `_ready()` only re-asserts `BarFill.color = bar_color`.

**Why the root is a bare anchor.** An instanced scene's root under a plain
`Control` is saved with a `layout_mode = 0` override and reloads with its rect
snapped to zero (authoring guide, "Two ways the editor silently drops a
`Control`'s rect"). So nothing may hang off the root's rect. `BarFill` and
`Stage` are sized in code, the same way `PaperShadow` draws from its
`Silhouette`.

### EndCutscene after

```
EndCutscene
├── WinStage   (instance)   ← replaces BarFill + Stage
├── BlurLayer
├── Badge
├── BtnNext
└── WhiteFade
```

`EndCutscene.gd` keeps:
- the badges, the BGM ids, pacing and the exit blur
- the white fade, the lose-only badge slam and the blur-out hand-off

Its `_dress_for_verdict()` becomes:

```gdscript
var failed: bool = GameState.run_failed
win_stage.dress(failed, WinStage.names_of(GameState.approved_students))
badge.texture = lose_badge if failed else win_badge
AudioDirector.play_bgm(lose_bgm if failed else win_bgm)
```

### RunResult after

```
RunResult
├── WinStage   (instance)   ← replaces Backdrop
├── BlurLayer               unchanged: lod 3.0, darkness 0.3
└── MarginContainer         the report, unchanged except the title style
```

`RunResult.gd`:
- The `win_backdrop` / `lose_backdrop` exports are removed; the art lives in
  `WinStage.tscn`.
- `_dress_backdrop()` calls the identical line
  `win_stage.dress(GameState.run_failed,
  WinStage.names_of(GameState.approved_students))`, then applies the blur as
  now.
- The blur exports stay, still pinned equal to EndCutscene's by
  `test_both_screens_dim_the_blur_by_the_same_amount`.

**Title: a knock-on fix.** Letterboxed at 1080×1920, the top 240px behind the
report is the navy bar. RunResult's title is `H1Label`, `text_primary`
#3B2412 dark brown, and it sits at y 64..~150: dark on navy, unreadable.

It switches to the existing `ResultHeroLabel`:
- display face, gold, with a 12px `text_primary` outline
- documented as the "light-on-dark" label for results reveals, currently used
  by `MinigameResultPopup`

That reads both on the bar and, on shorter screens where there is no bar, on
the blurred painting. The size steps down from 64 to 48. Nothing else on the
report changes, because every row and the grade sit on opaque `Card` panels.

### The hand-off, after

Both screens:
- draw the same scene
- dress it with the same call from the same two inputs (`run_failed`, the
  roster names)
- blur it with the same shader at the same pinned numbers

EndCutscene's last frame and RunResult's first frame differ only by the UI
drawn over the blur: *Lanjut* disappears and the report appears.

The lose path is unchanged on screen (`cg_lose.jpg` covering the viewport, no
lineup). It just runs through the same scene.

---

## Testing

The suites run in-editor through the MCP bridge. No test is a coroutine;
structure is checked on bare `instantiate()`s, and wiring by source scans
where a scene cannot run.

**`tests/test_stat_check.gd`**
- **The paper:**
  - `Paper` is a `TextureRect` showing `StudentCard/card_bg.png`, scaled
    uniformly.
  - The measured sheet rect, mapped through the paper's position and scale,
    lies inside the 760×1000 card (±1px) and fills its height.
  - `Paper/PaperShadow` is an instance of `Scenes/UI/PaperShadow.tscn`.
- **The parts:**
  - `Photo` and `PortraitFrame` sit on the printed frame rect.
  - `Name` sits inside `StudentCardView.BIO_PANEL_RECT` and uses
    `PlateNameLabel`.
  - The three rows are `StatCheckRow`s.
  - The old `Header`/`BioPanel` tree is gone.
- **Only the name:** the page contains exactly one `Label`, and
  `StatCheckCard.gd` never reads `profil`.
- **Binding:** `bind()` fills the name and the photo and arms the three rows.
- **Icons:** each row's icon is `res://Assets/Images/StudentCard/stat_*.png`
  for its category.
- **Name fit:** all six roster names, upper-cased, fit the `Name` slot at
  `PlateNameLabel`'s real font and size, measured through
  `ThemeFactory.build()`.
- **Row proportions:** the row's authored icon is `stat_akademis.png`; icon
  128, bar 68.

**`tests/test_win_stage.gd`** (new suite `win_stage`, extends
`McpTestSuiteCompat`)
- **Scene shape:** `BarFill` is opaque and draws before `Stage`; `Stage` holds
  `Backdrop` (KEEP_ASPECT_COVERED), `Shadows` before `Students`, and four
  authored slots each.
- **Letterbox maths:**
  - 1080×1920 → scale 0.703125 at (0, 240)
  - 1080×2340 → (0, 450)
  - 1536×2048 → scale 1 at the origin
  - no `0.703125` literal in the source
- **Win:** `dress(false, four names)` shows four textured students and four
  shadows, fits `Stage` uniformly, and uses `win_backdrop`.
- **Lose:** `dress(true, …)` uses `lose_backdrop`, sets `Stage` to scale 1 at
  viewport size, and hides all eight slots. This also holds after a win
  dress.
- **Helpers:** `names_of()` returns names in roster order.
- **Moved in from `test_end_cutscene`:**
  - the six splashes are wired
  - the shadow knobs are exports
  - the lineup comes from `WinLineup`
  - the lose branch is what covers
- **Verdict:** `WinStage.gd` never calls `check_semester_passed`.

**`tests/test_end_cutscene.gd`**
- **Retargeted to `WinStage`:**
  - `Stage` → `WinStage` in the draw-order tests
  - the backdrops are read from the instance
- **Moved out:** the stage-internal tests listed above.
- **New:**
  - the first child is an instance of `WinStage.tscn`
  - `EndCutscene.gd` holds the exact dress line
  - EndCutscene no longer lays out or poses anything itself

**`tests/test_run_result.gd`**
- **Draw order:** `WinStage` < `BlurLayer` < `MarginContainer`.
- **`Backdrop` is gone** (resolved to a bool before `free()`).
- **Dress wiring:**
  - the backdrop exports are gone from `RunResult.gd`
  - `_dress_backdrop()` calls the exact dress line from `run_failed`
  - it never recomputes the verdict
- **One art source:**
  - both host scenes instance `WinStage.tscn`
  - neither references `win_background.png` directly
  - nothing references `cg_win.jpg`
- **Same call on both screens:** the exact dress line appears in both
  `RunResult.gd` and `EndCutscene.gd`.
- **Title:** `TitleLabel` uses `ResultHeroLabel`.

**`tests/test_theme_factory.gd`**
- `PlateNameLabel` is on `DISPLAY_ROSTER`.
- It is `text_on_brand` at `font_display_size`.

**Live check**
- Debug overlay rehearsals, *Semua Lulus* and *Semua Gagal*.
- Screenshot StatCheck, EndCutscene and RunResult at full resolution.
- Confirm by eye:
  - the paper, the icons and the name fit
  - RunResult's background shows the same students and letterbox as
    EndCutscene
  - RunResult's title reads over the bar

## Out of scope

- `WinScreen.tscn` (still unused; its debt entry stays).
- Bar styles. StatCheck's bars keep the `StatBar` family; they are not
  switched to StudentCard's `StatPill`.
- `StatCheck.tscn`'s layout, and RunResult's rows, grading and progression.

## Risks and how the work is ordered

- **Stale script tabs.** `scene_save` writes open script tabs back over
  patched files. Scripts are patched first, then the editor restarts, then
  the scenes are edited. Every scene save is followed by a
  `git diff -- '*.gd'` check.
- **Stale root exports.** `EndCutscene.tscn` and `RunResult.tscn` carry values
  for exports that move to `WinStage`. Re-saving them after the scripts change
  drops those lines. A test pins that neither host references
  `win_background.png`.
- **The theme bake.** A missing rebake leaves `PlateNameLabel` rendering as a
  plain `Label` in the game while every in-memory test passes. The rebake is
  its own step, and its output is checked with `git diff` on
  `kejartes_theme.tres`.
