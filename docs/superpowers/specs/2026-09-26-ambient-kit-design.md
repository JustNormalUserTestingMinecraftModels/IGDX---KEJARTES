# Ambient kit — design

**Date:** 2026-09-26
**Status:** approved in brainstorming, section by section; amended while
planning (2026-09-27, see "Amendments from planning" at the end).
**Source:** a list of beginner 2D-polish tips (CanvasModulate colour overlays,
CPU particles, lights, parallax weather, small random details, shaders),
audited against what the game already has.
**Was blocked on** the clean-code pass (`2026-09-26-clean-code-design.md`),
whose PR2 renamed the scenes this kit is placed in and whose rulebook binds
every new script. Its Phase 1 (PR1–PR3) landed on 2026-09-27; the plan,
`docs/superpowers/plans/2026-09-27-ambient-kit.md`, uses the renamed paths.

## Problem

The Lobby and SchoolDay already carry most of the tips: a shared colour
grade, the look layer (vignette + grain), window light, light shafts and bloom,
`ParallaxDiorama`, SchoolDay's motes, rain and rotating sky. Every other
screen is a still backdrop with UI on it. MainMenu, LevelSelect, CutScene,
StudentCard, StudentList, ReportCard and the end-of-grade sequence have no
ambient light, no motion and no mood.

Tips that do **not** apply, and why:

- **Real `Light2D`** needs a normal map per illustration (~30 plates); blocked
  on art, not code (changelog 2026-09-23).
- **Random cracks and grass** suit tile-based worlds; every backdrop here is a
  single painted plate.
- **A raw `CanvasModulate`** tints its whole canvas layer, UI included.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Focus | A shared ambient kit, dropped into every flat screen. |
| Kit contents | Particles, colour mood tint, soft light pools, glint shader. |
| Architecture | A: separate building blocks, placed by hand in each screen's `.tscn` between backdrop and UI. Rejected: one combined `AmbientLayer` (per-screen positions become arrays on one node), and a global autoload (cannot sit between backdrop and UI). |
| Leaf/petal art | Wait for the artist. The format is specified below; the DAUN preset is built when the art lands. |
| Sway shader | Deferred: no flat screen has separated plant/paper/curtain art to move. Lands with the leaf art. |
| On/off | A separate Settings switch, on by default. |
| Light bleed | Bloom + spill: the Lobby's WorldEnvironment glow recipe on MainMenu and the four desk screens (amendment 1), threshold tuned per screen, and LightPools free to sit above illustrations. Rejected for now: `hdr_2d` (a project-wide rendering change) and light wrap on the shared cutout materials. Both go to DEBT.md. |

## 1. The kit

Every piece is born clean under the clean-code rulebook: PascalCase file,
`@tool`, a `##` header, a `##` line on every `@export`, typed throughout, no
bare magic numbers (named `const` or `@export`), no nodes created at runtime.

| Piece | Path | What it is | Knobs |
|---|---|---|---|
| **MoodTint** | `Scenes/Look/MoodTint.tscn` + script | Full-rect `ColorRect` with a multiply shader (`Scripts/Shaders/mood_tint.gdshader`). Placed directly above the backdrop, so it never touches the UI drawn after it. | `mood` enum: `NETRAL`, `PAGI` (warm morning), `SORE` (orange dusk), `MALAM` (blue night), `TEGANG` (cool, darker exam mood); `strength` 0–1; `vertical_falloff` 0–1 (tint heavier at the top) |
| **LightPool** | `Scenes/Look/LightPool.tscn` + script | Additive glow using `light_falloff.gdshader` unchanged, with an optional child using `light_shafts.gdshader` for slow rays. Brightness breathes slowly. | `light_color`, `intensity` (capped, see "Cream" below), `radius`, `rays_enabled`, `breath_period`, `breath_depth` |
| **AmbientParticles** | `Scenes/Look/AmbientParticles.tscn` + script | One `CPUParticles2D` that fills its own rect, additive `CanvasItemMaterial`, set up like SchoolDay's `Motes`. | `preset` enum: `DEBU` (dust, `particle_glow.png`), `KILAU` (sparkle, `particle_spark.png`); `density`; `drift`; `tint`. The area is the node's own rect (amendment 4). |
| **Glint** | `Scripts/Shaders/glint.gdshader` + `glint_material.tres` | A diagonal highlight band sweeping across a texture's alpha every N seconds. | `interval`, `band_width`, `angle`, `strength`, `glint_color`, `motion` |
| **AmbientGlow** | `Scenes/Look/AmbientGlow.tscn` + script | A `WorldEnvironment` carrying the Lobby's recipe (`lobby_environment.tres`): `background_mode` Canvas, glow in screen blend, `background_canvas_max_layer = -1` so the glow stops below the UI. Its `Environment` is `resource_local_to_scene`, so each screen's instance tunes its own copy. | `glow_threshold`, `glow_intensity`, `glow_strength` (written into the local environment) |
| **DeskAmbience** | `Scenes/Look/DeskAmbience.tscn` | The desk recipe (PAGI tint + lamp LightPool + DEBU particles + AmbientGlow), authored once and instanced by the four desk screens. | `particle_density`, `glow_threshold`, forwarded to its children (amendment 6) |

**Why CPU particles.** Counts stay at 12–40 per emitter, which is cheap on the
CPU and identical on every mobile GPU. SchoolDay's motes already use them.
Each preset's `amount` is a named `const` with a hard ceiling of 40.

**Cream.** The palette is near-white (`surface_page` #FBF1E3), so additive
light clips to flat white fast; the Lobby window light ships at 0.11 against a
measured knee of 0.12. `LightPool.intensity` is capped by a named `const`
at that measured knee, and each placement is tuned on a full-size frozen
capture (memory: measure pixels, don't screenshot the half-size embed).

### Light bleed

Two kinds, both from existing parts:

- **Glow bleed (bloom).** `AmbientGlow` blooms whatever crosses its threshold,
  so light pools and highlights leak a soft halo onto their surroundings.
  **The cream catch:** with `hdr_2d` off nothing exceeds 1.0, and cream paper
  (#FBF1E3) and white cloud sit almost as bright as the light itself. At the
  Lobby's 0.7 the paper cards and sky would glow too. So the threshold is
  tuned per screen, high enough that paper and sky stay mostly clean: start
  at 0.85 and raise it until the lightest paper stops blooming, measured on a
  frozen full-size frame. If no threshold on a screen blooms the pools without
  also blooming its paper, that screen ships without glow and the case goes
  into the `hdr_2d` DEBT entry.
- **Spill.** A `LightPool` may be placed **above** a non-interactive
  illustration (e.g. the MainMenu logo) so its soft edge washes across the art.
  That is only a tree-order choice, so it needs no new code.

Tuning happens in the editor: a Canvas-mode `WorldEnvironment` previews live
in the 2D viewport (changelog 2026-09-23), so `AmbientGlow`'s knobs are
tuned in the Inspector. The Debug overlay's Look page stays Lobby-only
(amendment 3).

### Switches

- **`GameSettings.ambient_effects_enabled`**: new, default `true`, saved under
  `[pengaturan]` as `ambient_effects`, emits `ambient_effects_changed(enabled)`.
  Settings gains an **Efek Suasana** card beside the Look Layer card, same
  CheckButton layout. Off hides every kit piece and sets `AmbientGlow`'s
  `glow_enabled` false. It does not touch the Lobby's own environment, which
  predates the kit.
- **`GameSettings.reduce_motion`** (existing): particles stop emitting and
  hide, rays and breathing hold one fixed pose, glint's `motion` uniform goes
  to 0. Tint and static glow stay.

Both are read once on `_ready` and followed by signal. Pieces listen; they
never poll. (`reduce_motion` has no change signal today; the plan adds one
the same way `look_layer_changed` works.)

## 2. Placement

| Screen | Backdrop | Tint | Light | Particles | Glint |
|---|---|---|---|---|---|
| MainMenu | Sky over rooftop | PAGI, light | Large sun pool, upper right, rays on | DEBU, a few specks rising | Logo, every ~5 s |
| LevelSelect | Desk + envelopes | DeskAmbience | DeskAmbience | DeskAmbience | Envelope wax seal |
| StudentCard | Desk | DeskAmbience | DeskAmbience | DeskAmbience | — |
| StudentList | Desk | DeskAmbience | DeskAmbience | DeskAmbience (sparser) | — |
| ReportCard | Desk | DeskAmbience | DeskAmbience | DeskAmbience | — |
| CutScene | Crayon sky and hills | none (NETRAL) | Soft sun pool | KILAU drifting across | — |
| TesNotice, StatCheck | Blurred school | TEGANG | — | — | — |
| ExamProgress | Exam art | none (amendment 2) | — | — | — |
| RunResult (pass) | WinStage | PAGI | Warm pool behind the grade card | KILAU | Grade badge |
| RunResult (fail) | WinStage | MALAM | — | DEBU, slow | — |

The desk lamp sits upper left, matching the game's light direction (only the
Lobby is lit from the upper right).

**RunResult** carries two pre-built groups, `AmbientPass` and `AmbientFail`,
in its `.tscn`; its script sets one visible from the result it already
computes. No kit piece knows about pass or fail.

**Tree order on the glow screens** (MainMenu and the four desk screens; the
Lobby's 2026-09-25 layering). The other kit screens keep their backdrop on
layer 0 and put the kit pieces directly after it, in the same order.

```
World  (CanvasLayer, layer = -1)     <- AmbientGlow blooms only this layer
├── Background
├── MoodTint           <- multiplies only what is drawn before it: the backdrop
├── LightPool(s)
├── AmbientParticles
├── non-interactive art (e.g. the MainMenu logo, with glint material)
└── LightPool (spill)  <- optional, above the art it washes over
AmbientGlow            (WorldEnvironment, anywhere in the scene)
SafeAreaMargin / UI    <- layer 0, untouched, never bloomed
```

**Only non-interactive art moves into `World`.** Anything the player taps
(LevelSelect's envelopes, the student cards and their portraits, buttons) stays on layer 0 with the UI, so
input order does not change; it is simply not bloomed.

Full-rect pieces use Full Rect anchors so they fill a 20:9 phone
(`aspect="expand"`), per the tall-screen rule. Moving a backdrop under
`World` changes its node path, so `test_tall_screen_layout`'s path pins move
with it, as they did for the Lobby.

**Out of this pass:** Lobby and SchoolDay (already rich), Inventory,
Achievements, Koperasi/ShopHub (blurred or busy backdrops; the kit can extend
there later), minigames (out of scope for the design system).

## 3. Particle art for the artist

Delivered to `Assets/Images/Particles/` at these exact names, so the
art drops in with no code change.

| File | Size | Content | Colour |
|---|---|---|---|
| `particle_leaf_sheet.png` | 512×128, 4 frames of 128×128 in one row | 4 leaf variants | Real colour |
| `particle_petal_sheet.png` | 512×128, 4 frames of 128×128 in one row | 4 petal variants (frangipani suggested) | Real colour |
| `particle_dust.png` (optional) | 128×128 | Soft round mote | White on transparent |
| `particle_sparkle.png` (optional) | 128×128 | 4-point sparkle | White on transparent |

All: PNG, RGBA, straight (not premultiplied) alpha, transparent background,
8 px empty border inside every frame (stops neighbour-frame bleed), no drop
shadow, no text. Leaves and petals point **tip up, stem down**. Shapes stay
simple: they display at roughly 40–64 px on a 1080-wide screen.

Why a sheet: an emitter takes one texture, so four frames in a strip let one
emitter show four shapes (random frame per particle). Why white for dust and
sparkle: they blend additively and are tinted by the kit's colour knob.

**When the sheets land:** `AmbientParticles` gains a `DAUN` preset
(normal blend, sheet frames), and `paper_flutter.gdshader` gains an `h_frames`
uniform (default 1, so confetti is unchanged) to pick the frame. The optional
dust/sparkle files replace `particle_glow` / `particle_spark` in the DEBU and
KILAU presets only.

## 4. Testing

Suites follow the house constraints: `@tool`, no coroutine tests, fixtures
instanced once in `suite_setup` (per-test instancing overflows the message
queue on a full run).

- **`tests/test_ambient_kit.gd`**:
  - each kit scene loads, and its script is `@tool`;
  - every `MoodTint` preset maps to its documented colour;
  - `ambient_effects_changed(false)` hides every piece and `true` restores it;
  - a `reduce_motion` change stops particle emission and zeroes glint's
    `motion` uniform;
  - every preset's `amount` is at or under the 40 ceiling;
  - `LightPool.intensity` cannot exceed its cap;
  - `AmbientGlow`'s environment is Canvas mode,
    `background_canvas_max_layer = -1`, local to scene, and glow turns off
    with the switch.
- **Placement census** (same suite): each screen in the placement table
  contains its listed kit instances inside a `World` CanvasLayer at −1,
  exactly one `AmbientGlow` (unless the screen is recorded as shipping without
  glow), and no kit piece and no interactive Control inside `World`.
  RunResult has both `AmbientPass` and `AmbientFail`.
- **`test_look_layer`** keeps pinning `hdr_2d` off.
- **UI stays clean (measured once per screen):** on a frozen full-size frame,
  UI pixels are identical with the kit on and off, and the lightest paper
  surface moves by less than the bloom it is meant to show.
- **Settings:** the new key saves and loads with default `true`; the Efek
  Suasana toggle exists and is wired.
- **Existing ratchets stay green:** `test_script_documentation`,
  `test_viewport_editability` (no runtime construction; no new `ALLOWED`
  entry), `test_tall_screen_layout` (full-rect kit pieces),
  `test_clean_code` (new scripts at zero debt), `test_project_hygiene`.
- **Visual check, once per screen:** a frozen full-size capture (tree paused,
  `Engine.time_scale` 0.02 for particles) to tune intensity and density;
  record the landed values in the `.tscn`, not in code.

## 5. Docs

- `docs/superpowers/DEBT.md`: the leaf/petal sheets (format as in section 3),
  the optional dust/sparkle redraws, the deferred Sway shader, the kit's
  not-yet-covered screens, `hdr_2d` (the clean way to bloom only the lights;
  a project-wide switch that `test_look_layer` pins off, plus any screen that
  shipped without glow because of it), and light wrap on the cutout materials.
- `docs/superpowers/CHANGELOG.md`: an entry when the pass lands.
- `docs/superpowers/design/authoring-guide.md`: a short "Ambient kit" section
  (the tree order above and where each piece goes).
- CLAUDE.md: at most one line under `## Visual system` pointing to the
  authoring-guide section, if the budget allows.

## Success criteria

- Every screen in the placement table shows its tint, light and particles on
  device, and the UI's colours are unchanged (measured, not eyeballed).
- Light pools visibly bleed a glow onto their surroundings; paper and sky do
  not glow along with them.
- Efek Suasana off hides the whole kit, glow included; Reduce Motion freezes it.
- No runtime-built visuals; every new script passes the clean-code ratchet
  with zero debt.
- Full suite green.

## Amendments from planning (2026-09-27)

Found while reading the post-clean-code code for the plan. Each one
supersedes the text above where they disagree.

1. **Glow on MainMenu and the four desk screens only.** RunResult draws
   `WinStage` under a live blur (`BlurLayer`), so bloom there is invisible,
   and moving `WinStage` into a layer would reorder the blur it depends on
   (pinned by `test_run_result` and `test_end_cutscene`). CutScene's picture
   changes slide to slide, so no one threshold fits it. The exam screens have
   no light to bloom. Those screens take their kit pieces on layer 0, with
   no `World` layer and no `AmbientGlow`.
2. **ExamProgress takes no tint.** Its exam art was made undarkened on
   2026-09-20 so that `text_primary` reads at ~4.6:1 over it; a TEGANG
   multiply would darken the art and cut that contrast. TesNotice and
   StatCheck keep TEGANG: their text sits on a `Scrim`, not on the art.
3. **The Debug Look page is not generalised.** `DebugManager.gd` is listed at
   its size in the clean-code ratchet's `LARGE_SCRIPTS` (1,880 lines) and may
   not grow, and the editor's 2D view already previews Canvas-mode glow.
4. **`AmbientParticles` is a `Control` holding a `CPUParticles2D`.** A bare
   `Node2D` emitter sits at fixed coordinates and would not cover a 20:9
   phone. The control's own rect is the emission area, re-fitted on
   `resized`, so `rect_size` is gone.
5. **The glint's switch lives in `LookLayer`.** Every glinting node shares one
   `glint_material.tres`, so its `motion` uniform is set once, on that shared
   resource, by the autoload that already owns global look state.
6. **`DeskAmbience` forwards `particle_density` and `glow_threshold`.**
   Overrides set on an instanced scene's children do not survive a save
   (CLAUDE.md, "Three save hazards"), so the per-screen knobs live on
   `DeskAmbience`'s root.
7. **No glow ships (measured 2026-09-28).** On MainMenu the sky sits at ~0.89
   luminance and the sun core at ~0.88; on the desk screens the wood is
   ~0.84 everywhere. Swept over threshold 0.6-0.9, intensity 1-4 and strength
   1-1.5, no setting bloomed a light pool by +0.01 without blooming the far
   background as much (+0.04 to +0.11 at the strong end: fog). With hdr_2d
   off, no threshold can separate a light from a background this bright. The
   user chose to drop the glow: MainMenu and DeskAmbience place no
   AmbientGlow; the piece and its tests stay for a later hdr_2d pass
   (DEBT.md). Measured at the same time: the desk lamp lands at 0.12, its cap
   (0.06 added only +0.006 mean, 0.12 clips nothing), and the menu sun stays
   at 0.08 (0.12 drove 122 sampled pixels to white).
