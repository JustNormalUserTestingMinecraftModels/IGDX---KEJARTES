# Lobby look everywhere — design

**Date:** 2026-09-28
**Status:** approved in brainstorming, section by section.
**Request:** "apply the same graphics from the lobby to all of the minigames,
shops, end game" — clarified as the Lobby's **lighting and atmosphere**, not its
UI style and not its classroom art.
**Builds on:** the ambient kit (`2026-09-26-ambient-kit-design.md`), whose
"Out of this pass" line left Koperasi/ShopHub and the minigames for later.

## Problem

The Lobby's look is a stack of five things:

1. **Colour grade** on every illustration (`illustration_grade_material.tres`
   on backdrops, the cutout materials with inner AO and rim on cutouts).
2. **Window light**: a warm additive pool (`window_light_material.tres`,
   `light_falloff.gdshader`, intensity 0.11).
3. **Light shafts**: full-screen slow rays (`window_shafts_material.tres`,
   `light_shafts.gdshader`, intensity 0.20).
4. **Bloom**: `lobby_environment.tres` on a `WorldEnvironment`, reaching only
   the `World` CanvasLayer at −1.
5. **Parallax**: `ParallaxDiorama` sliding the room's depth bands on tilt.

The shops, the end-of-grade sequence and the minigames carry only parts of it:

| Area | Has | Missing |
|---|---|---|
| Minigames | grade on most backdrops | light, shafts, bloom, parallax |
| ShopHub, CosmeticShop | nothing | everything |
| Koperasi | grade, parallax | light, shafts, bloom |
| TesNotice, StatCheck, RunResult | ambient-kit tint/pool/particles | shafts, grade on WinStage, bloom, parallax |
| ExamProgress, EndCutscene | nothing | everything |

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Which "graphics" | Lighting and atmosphere only. UI style and the minigames' design-system status are untouched. |
| Bloom | Try per screen. Measure on a frozen full-size frame; ship where a threshold blooms the light without fogging the backdrop, otherwise drop it and record the numbers in DEBT.md's `hdr_2d` entry. `hdr_2d` itself stays off. |
| Parallax | Menus and shops only, never minigames: MainBola's pitch lines are drawn over the field art and would slide out of register, and drift distracts in a timed game. |
| Architecture | A: reuse the ambient kit, placed by hand in each `.tscn`. Rejected: one combined `LobbyLook` scene (would reparent the backdrop at runtime, breaking "no visual is built at runtime"), and a global lighting autoload (cannot sit between backdrop and UI, so it would light the UI). |
| Scope split | One spec, three PRs in order: Shops → End game → Minigames. |
| Minigames and the design system | CLAUDE.md keeps minigames out of scope for the design system. This pass touches only their backdrops' lighting, never their UI, and says so here. |

## 1. The new piece and the shared recipe

### SunShafts

`Scenes/Look/SunShafts.tscn` + `Scripts/Look/SunShafts.gd`. The Lobby's
`WindowShafts` as a kit piece. `LightPool`'s own rays cannot stand in: its
`MAX_RAYS_REACH` stops them at the pool's edge, where the Lobby's cross the room.

- A Full Rect `ColorRect` running `light_shafts.gdshader` unchanged. The
  `ShaderMaterial` is `resource_local_to_scene`, so every instance tunes its own.
- `@export`s, each with a `##` line: `origin` (UV where the rays converge),
  `shaft_color`, `intensity`, `shaft_count`, `reach`. `intensity` is clamped by a
  named `const MAX_INTENSITY := 0.2`, the Lobby's swept safe maximum over cream
  (`light_shafts.gdshader`'s header).
- Plumbing through `AmbientKit`, like every kit piece: `follow_settings` with a
  bound method (never a lambda), `fill_parent` in `_ready`. **Efek Suasana** off
  hides it. **Kurangi Gerakan** on sets the shader's `drift_speed` to 0, restoring
  the export's value when it goes off.
- `mouse_filter = MOUSE_FILTER_IGNORE`. `@tool`, `##` header, typed, no nodes
  built at runtime.
- The Lobby keeps its hand-built `WindowShafts`. Swapping it for this piece is
  out of scope.

### The recipe

Every screen in this pass follows it, except where section 2 says otherwise.

1. **Layering.** The backdrop and any art the player cannot tap move under a
   `World` CanvasLayer at `layer = -1`. Buttons, cards and gameplay stay on
   layer 0, unlit and unbloomed, so input order does not change. Moving a node
   changes its path: `test_tall_screen_layout`'s pins move with it, as they did
   for the Lobby.
   - A CanvasLayer does not inherit its parent Control's `modulate`. A screen
     that fades its own root must also fade `World`'s content (see RunResult).
2. **Grade.** Every illustration wears one of the two materials: full-bleed
   backdrops take `illustration_grade_material.tres`, cutouts take
   `illustration_grade_cutout.tres`. `test_illustration_ao`'s census gains each
   new plate. Only the Lobby uses the `_lobby` and face variants.
3. **Light.** One warm `LightPool` at the art's window, sun or lamp, plus a
   `SunShafts` converging at the same point. Direction comes from the painted
   art: upper left by default, the game's convention (only the Lobby is lit
   from the upper right; `style-guide.md`, "Illustration materials").
4. **Bloom.** An `AmbientGlow` goes on every `World` screen, then is measured
   on a frozen full-size frame (memories: freeze game time, measure pixels
   rather than the half-size embed). Sweep `glow_threshold` 0.85–0.95 against
   the lightest backdrop surface.
   - If a threshold blooms the pool and shafts while the backdrop moves by
     less than +0.01 mean luminance, ship that threshold.
   - Otherwise delete the node and add the screen, with its measured numbers,
     to DEBT.md's `hdr_2d` entry.
5. **Parallax.** Menus and shops get a `ParallaxDiorama` driving the `World`
   bands. The backdrop is the far band (0.15, like the Lobby's `BGLayer`, with
   overscan) and `SunShafts` rides the same depth, so the light stays glued to
   its window.
6. **Blurred screens** (ShopHub, CosmeticShop, TesNotice, StatCheck, and the
   blurred half of EndCutscene/RunResult): the light sits **under** the blur,
   inside `World`, so it softens with the picture instead of drawing crisp rays
   over a soft room. The screen-texture blur on layer 0 samples `World` below it.
   Verify that on the first blurred screen before repeating it.

## 2. Placement

Origins, colours and strengths below are the intent. The numbers are tuned
against the real art on a frozen full-size frame and written into each `.tscn`.

### Pass 1 — Shops

| Screen | Layering | Light + shafts | Bloom | Parallax |
|---|---|---|---|---|
| ShopHub | `Backdrop` → `World`; `BlurLayer`, `Tiles`, `BackButton` stay on layer 0 | warm, under the blur | measure | backdrop + shafts as one far band |
| CosmeticShop | as ShopHub | as ShopHub | measure | as ShopHub |
| Koperasi | **stays on layer 0**: `Background` shares `Stage` with the tappable goods (`Barang*`) and the existing `ParallaxDiorama` drives `Stage`'s children | `LightPool` + `SunShafts` inside `Stage`, directly after `Background`, added to `depth_by_child` at the backdrop's depth | none: nothing on layer 0 can bloom. Recorded in DEBT.md | already has it |

`SunShafts` lands in this pass.

### Pass 2 — End game

| Screen | Layering | Light + shafts | Bloom | Parallax |
|---|---|---|---|---|
| TesNotice | `Backdrop` → `World`, under `Scrim` | cool, dim, matching its TEGANG tint | measure | one band, light drift |
| StatCheck | as TesNotice | as TesNotice | measure | as TesNotice |
| ExamProgress | `Backdrop` → `World` | warm | measure | one band |
| EndCutscene | `WinStage` → `World` | two pre-built groups, `LightPass` (warm pool + shafts) and `LightFail` (dim cool pool, no shafts); the script shows the one matching `GameState.run_failed` | measure | WinStage's own bands: backdrop far, shadows and students near |
| RunResult | `WinStage` → `World`; existing `AmbientPass`/`AmbientFail` stay where they are | `SunShafts` inside `World` for pass only, shown by the same pass/fail switch that already picks the ambient group | measure | as EndCutscene |

- **RunResult's exit fade** (`RunResult.gd`, `tween_property(self,
  "modulate:a", …)`) must also fade `World`'s content node. `World` holds one
  Control that everything else sits under, and the tween fades it alongside
  the root.
- **EndCutscene's pass/fail choice** reads the same input WinStage is dressed
  from. No kit piece knows about pass or fail.

### Pass 3 — Minigames

**No `World` layer, no bloom, no parallax.** SchoolDay hosts a minigame
inside its own tree (`SchoolDay.gd`, `game_container.add_child`) over its
full-screen layer-0 `Background`, which stays visible. A `World` layer at −1
would draw under that background, and SchoolDay's fade-in on the minigame's
root `modulate` would not reach it. So each minigame keeps its backdrop on
layer 0 and places the light pieces directly after it, the ambient kit's
"other kit screens" order. Bloom there would need reworking SchoolDay's
minigame hosting. That goes to DEBT.md, not into this pass.

| Game | Backdrop | Light |
|---|---|---|
| PilihanGanda, Menjodohkan, Password, Variabel | `meja_background.png` | warm desk-lamp `LightPool`, upper left; soft `SunShafts` |
| MainBola | `Gawang.jpg` field | sun `LightPool` + `SunShafts`, upper left, placed before `FieldMarkings` so the pitch lines stay crisp |
| Badminton | `lapanganBadminton.jpg`, today built by `_add_background()` at runtime | the court becomes an authored `Background` node in the `.tscn`, and `_add_background()` is deleted; then as MainBola |
| LombaMenari | `budaya_background.jpg` stage | warm spotlight pool from the top; shafts pointing down |
| BuatBatik | `Background` | pool only, no shafts, so no rays cross the drawing canvas |

Kalkulator is a component inside Password and Variabel, not a screen. It gets
nothing.

## 3. Testing

Suites follow CLAUDE.md's hard rules: `@tool`, no coroutines, and a source
scan where a scene cannot be instanced.

- **`test_ambient_kit`**: `SunShafts` gets the same coverage as `LightPool`:
  intensity clamps to `MAX_INTENSITY`; additive, local to the scene and
  untappable; Efek Suasana hides it; Kurangi Gerakan zeroes the drift and
  restores it; it refills its parent. It joins `KIT_SCENES`.
- **Placement, one test per screen**, in the style of
  `test_main_menu_wears_the_morning_kit`: the expected pieces exist in
  order, and nothing tappable (`BUTTON_TYPES`) sits under `World`.
- **Bloom pinned both ways**: each screen that kept glow has its threshold
  scanned; each that dropped it has no `AmbientGlow`.
- **RunResult**: the exit tween fades `World`'s content as well as the root.
- **EndCutscene**: pass shows `LightPass` only, fail shows `LightFail` only.
- **Minigames**: all eight games have a `LightPool` directly after their
  backdrop, and none has a `CanvasLayer` below layer 0 or an `AmbientGlow`. This
  pins the SchoolDay finding.
- **Moved pins**: `test_tall_screen_layout` paths, the `test_illustration_ao`
  census, and `test_viewport_editability`'s `BASELINE` for `Badminton.gd`,
  lowered by the removed `TextureRect.new()`.

Tests prove the pieces are placed. The look is judged on one frozen full-size
capture per screen.

## 4. Docs

- `style-guide.md`, "Illustration materials": one paragraph naming the Lobby
  recipe (grade, pool, `SunShafts`, glow, parallax) and pointing here.
- The ambient-kit spec's "Out of this pass" line points to this spec.
- `DEBT.md`:
  - the `hdr_2d` entry gains each screen that dropped bloom, with numbers
  - a new entry records minigames and Koperasi as structurally unbloomable,
    with the reason
  - "Koperasi/ShopHub" comes off the "kit not yet extended to" list
- `CHANGELOG.md`: one entry per pass. CLAUDE.md's suite count is updated by
  each PR.

## 5. Shipping

Three branches, each in its own worktree off `Textures`, each through
`ship-pr` after a full suite run, merged in order:

1. `feat/lobby-look-shops`: `SunShafts` + ShopHub, CosmeticShop, Koperasi
2. `feat/lobby-look-endgame`: TesNotice, StatCheck, ExamProgress, EndCutscene,
   RunResult
3. `feat/lobby-look-minigames`: the eight games, plus the Badminton court moved
   into its scene

Worktrees are removed once their PR merges.

## Success criteria

- Every screen in the three tables has the grade, the light and shafts
  (except BuatBatik and the two fail states), matching the placement.
- No UI or gameplay node is lit, bloomed or moved by parallax.
- Efek Suasana off hides every new piece; Kurangi Gerakan holds them still.
- Every screen fills a 20:9 phone (`test_tall_screen_layout` green).
- Each bloom decision is backed by a measured number in the PR or DEBT.md.
- The full suite is green on each PR's tested commit.
