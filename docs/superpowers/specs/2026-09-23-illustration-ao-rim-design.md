# Illustration AO, rim light and Lobby shafts — design

2026-09-23. Follows the premium-look programme (`.superpowers/gamecode/premium-look/`)
and the look layer shipped in `6930dfa`.

## Motivation

The painted plates read flat. They are cutouts pasted onto backdrops: nothing
says a desk sits **on** the classroom floor rather than in front of it, and
nothing gives a character an edge that catches light. The colour grade shipped
in `6930dfa` changes the plates' colour but not their form — and it has since
been reduced to a quarter of its original strength twice over, because contrast
about mid-grey darkened scenes that were already dark enough.

So the goal here is **surface richness without a net darkening**: make each
plate read as a solid object, without taking the scene's brightness back down.

### What was ruled out, and why

**SSAO is unavailable, twice over.** In Godot 4 it is an `Environment`
post-process that reads the 3D depth buffer, and it is Forward+ only. This
project runs the `mobile` renderer, and its illustrations are `TextureRect`s and
`Sprite2D`s on a canvas, which write no depth. There is no configuration that
makes real screen-space AO see a 2D plate. (Switching to Forward+ makes the
*setting* appear and still changes nothing — this was tested on 2026-09-23 and
reverted.)

**Real `Light2D` + normal maps was considered and deferred.** It is the only
route where light genuinely moves across a painted surface, and `light_mask` /
`item_cull_mask` would let lights touch the illustration plates while skipping
the UI on the same layer 0 — so it is not structurally blocked here, which was
the open question. It is blocked on art: a normal map per illustration, for
thirty plates. That is a different, larger project.

**A screen-space pass is still wrong**, for the reason the grade already
documents: UI and illustrations share `CanvasLayer 0` on every screen, so
anything applied to the whole viewport tints the buttons and the text too, and
`design_tokens.tres` stops being the honest description of the UI's colour.

## The decisions

| Decision | Chosen | Rejected |
|---|---|---|
| What the pass is | Surface richness | Depth separation; a lit room; grounding alone |
| Core effect | Inner AO **+** rim light, together | Either alone; form shading; paper fibre |
| Outer AO | Option C — zero offset, tight radius | Nothing; the old offset drop shadow; a tighter option D |
| Volumetric | Shafts, **Lobby only** | Everywhere; nowhere; later |
| Build shape | One shader, **two materials** | One material for everything; per-plate overlay nodes |
| Control | **Developer only** | A player-facing setting |

## 1. Architecture

### 1.1 One shader, two materials

`Scripts/Shaders/illustration_grade.gdshader` gains a second stage after the
existing grade. Two materials point at it:

- `illustration_grade_material.tres` — unchanged behaviour, with
  `ao_strength = 0.0` and `rim_strength = 0.0`. Worn by the **backdrops**.
- `illustration_grade_cutout.tres` — new, both effects on. Worn by the
  **cutouts**.

Why not one material for everything: a full-bleed backdrop has no alpha edge to
find, so it would pay five extra texture taps per pixel and get nothing back.
The game is mostly full-screen backdrops, and a 1080×2400 backdrop paying for an
effect it cannot show is the whole screen paying for nothing. The strength
uniforms are per-material and coherent across a draw call, so the branch is
free.

### 1.2 How AO finds an edge without a distance field

Four taps of the plate's own alpha at ±r in x and y. Deep inside the silhouette
all four return 1, so `edge = 1 − avg = 0` and nothing happens. Near the edge
some taps fall outside the silhouette, the average drops, and the pixel is
multiplied toward a warm dark.

AO is **ambient**: uniform all the way around the silhouette, no direction. That
is what distinguishes it from a cast shadow.

### 1.3 How rim finds the lit side

One tap of alpha, offset *toward* the light. If that neighbour is transparent
while this pixel is opaque, the pixel is standing on the lit edge, and
`rim_color` is added. Additive, because light brightens what is behind it —
the same reasoning `light_falloff.gdshader` already documents.

### 1.4 Radius is in screen pixels, not texels

The plates are drawn at wildly different scales: a 1240×1754 racket renders at
0.34, a desk at 1.0, a face at whatever the Lobby's parallax gives it. A radius
in source texels would give every plate a differently-sized band and the game
would not look like one thing.

So the offsets are `fwidth(UV) * radius_px` — `fwidth` gives UV-per-screen-pixel,
making the band a constant number of **screen** pixels on every plate regardless
of its draw scale.

> **Verify first.** Canvas-shader derivatives are supported on Vulkan, but this
> must be confirmed on a real frame before the rest of the design leans on it.
> If it fails, the fallback is a radius in texels plus a second cutout material
> for the small-scale plates — uglier, which is why this is checked first, not
> last.

### 1.5 One light direction, whole game

A single `light_dir` uniform, default upper-left. AO ignores it; rim obeys it.
Three independent sources in the existing game agree on that direction:

- The Lobby's `WindowLight` pool centres at about `W/2 − 170, H/2 − 490`.
- The sun streaks painted into `loby_no_tables.png` run down-right.
- All three existing contact shadows are offset down-right: Herman `(12,10)`,
  `BGHari` `(8,12)`, `Splash` `(14,10)`.

## 2. The plate census

Measured on 2026-09-23 by sampling each texture's alpha channel, not by eye.
Thirty plates wear the grade today; this is how they split.

### 2.1 Cutouts — 21 nodes, get `illustration_grade_cutout.tres`

| Scene | Nodes | Transparent |
|---|---|---|
| `loby.tscn` | `Meja_KiriAtas`, `Meja_KananAtas`, `Meja_KiriBawah`, `Meja_KananBawah` | 90–92% |
| `koprasi.tscn` | `Stage/Herman`, `Stage/Foreground` | 79%, 61% |
| `EventDialogue.tscn` | `Splash` | 66% |
| six `*Face.tscn` | `Canvas/Base` | 55% |
| `DancerRig.tscn` | `Body`, `Head` | 88%, 92% |
| `MainBola.tscn` | `Goalie/GFX`, `Ball/GFX` | 76%, 78% |
| `Badminton.tscn` | `Puck/Sprite2D`, `PlayerPaddle/Sprite2D`, `EnemyPaddle/Sprite2D` | 79%, 94% |
| `Kalkulator.tscn` | `Body/BodyTexture` | 1.4% — see below |

`Kalkulator`'s plate is only 1.4% transparent, but it has a real rounded
silhouette with soft edges, so it is treated as a cutout. It is the one
judgement call in this table; if the calculator ends up looking like furniture
rather than UI, give it the plain material back.

### 2.2 Backdrops — 9 nodes, unchanged

`loby.tscn/Classroom/BGLayer` (RGB — no alpha channel at all),
`koprasi.tscn/Stage/Background` (100% opaque), the four Akademis `Background`
nodes (all `meja_background.png`, 0% transparent), `BuatBatik/Background`,
`LombaMenari/Background` and `MainBola/FieldBG` (JPEGs, no alpha).

These keep the material they wear today. Nine of the thirty graded plates are
untouched by this pass by construction.

## 3. The four effects

### 3.1 Inner AO — shader

Uniforms `ao_strength`, `ao_radius_px`, `ao_color`. On cutouts only.

### 3.2 Rim light — shader

Uniforms `rim_strength`, `rim_radius_px`, `rim_color`, `light_dir`. On cutouts
only.

### 3.3 Outer AO — seven `PaperShadow` instances

A node can only draw inside its own rect, so darkening the floor *around* a desk
cannot be shader work on the desk. It needs a node behind the plate — which is
exactly what `Scenes/UI/PaperShadow.tscn` already is.

Option C values: `shadow_offset = (0,0)`, `blur 3.0 → 1.2`, `shadow_alpha → 0.34`.

- **Four new instances** on the Lobby desks. This reverses the removal made
  earlier the same day (see §6).
- **Three existing instances retuned** to the same values so the game agrees
  with itself: `koprasi.tscn` `Stage/Herman` (was `(12,10)`, 0.26, blur 3.0),
  `atur_jadwal.tscn` `BGHari` (was `(8,12)`, 0.30, blur 3.0),
  `EventDialogue.tscn` `Splash` (was `(14,10)`, 0.24, blur 3.5).

The twelve paper-card shadows in StudentCard and ReportCard stay as offset drop
shadows. A paper thrown off-screen by `_transition_page()` **should** cast one;
that is a different effect with a different job, and `test_paper_shadow.gd`
already documents why it rides its paper.

### 3.4 Lobby shafts — one node

A new `Classroom/WindowShafts` `ColorRect` carrying a new
`Scripts/Shaders/light_shafts.gdshader`, extracted from
`achievement_glow.gdshader` — the rotating shafts without the starburst core.
Additive, `mouse_filter = 2`.

Registered in `ParallaxDiorama.depth_by_child` at the room's `0.15` so the
shafts move with the wall instead of floating over it.

`Classroom`'s own rect is pinned by `test_tall_screen_layout.gd` at
`(-540,-960,540,960)`. The shafts go in as a **child**; `Classroom` itself is
never touched.

Intensity starts far lower than instinct suggests. `light_falloff.gdshader`'s
header records why: this palette is mostly near-white, `surface_page` is
`#FBF1E3`, and additive light clips to flat white fast. The window light ships
at 0.11 against a measured knee of 0.12.

## 4. Tuning

Values are **measured, not chosen**, by the method that produced the window
light's 0.11 ceiling:

1. Freeze the tree (`Engine.time_scale = 0.02` — GPU particles vanish at 0).
2. Render the Lobby at true 1080×2400 through a `SubViewport`. The editor's
   embedded run is half-size and will lie about a 1px band.
3. Sweep each strength. For rim, count pixels driven to pure white that were not
   already. For AO, count pixels driven below the shadow floor.
4. Ship under each knee with margin.

The method goes in the test file's header so the next person re-measures instead
of re-guessing.

## 5. Control and reversibility

Developer control only. No new player-facing setting: AO and rim are five taps
on cutouts, cheap enough to be always on, exactly as the colour grade already is.

### 5.1 Four independent off-switches

| Effect | Off by | Scope |
|---|---|---|
| Inner AO | `ao_strength = 0` in the cutout material | Whole game, one number |
| Rim light | `rim_strength = 0` in the cutout material | Whole game, one number |
| Outer AO | `shadow_alpha = 0`, or delete the node | Per plate, or all seven |
| Lobby shafts | `visible = false`, or `intensity = 0` | One node |

Nothing is entangled. Killing rim does not disturb AO; killing both leaves the
colour grade exactly as it is today.

**Per-plate opt-out** is the existing mechanism: give any node the plain
`illustration_grade_material.tres` back.

### 5.2 Live control

A new **Look** page in the debug overlay (`F1`, or five taps top-right) with a
toggle per effect and a slider per uniform. Both materials are shared resources,
so a slider there writes once and every plate in the scene moves together — sit
in the Lobby, drag until it is right, then bake the landed number into the
`.tres`.

This is deliberate: it replaces the "halve it, then halve it again" round-trip
through a session with a dial the user turns while looking at the result.

### 5.3 Revert path

Four commits, one per effect, in this order:

1. shader + the two materials
2. material assignment on the 21 cutouts
3. outer AO (four new, three retuned)
4. Lobby shafts

Each is a clean `git revert` on its own, and reverting an earlier one does not
strand a later one: commit 2 is inert while the uniforms are zero, and commit 4
touches nothing the others touch.

## 6. The desk-shadow reversal

Earlier on 2026-09-23 the four Lobby desk shadows were removed at the user's
instruction, and `test_the_lobby_desks_cast_no_shadow` was added to hold that
line. This spec brings them back, and that test is **deleted and replaced** by
`test_the_lobby_desks_carry_outer_ao`.

This is a deliberate reversal, not an accident, and the reason is that the two
are different objects. What was removed was a **drop shadow**: offset 10/14 px,
alpha 0.28, wide blur — a cast shadow implying a light direction nothing else in
the scene agreed with, which read as a smudge beside the desk. What returns is
**outer AO**: zero offset, a third of the blur. It is not a shadow from anywhere;
it is the floor going dark where the desk occludes it.

Recorded here because the next session reading the git log will otherwise think
someone undid a decision by mistake.

## 7. Testing

New suite `tests/test_illustration_ao.gd` — `look_layer` already carries twelve
tests and owns a different concern.

- **Census** — every one of the 30 graded nodes appears exactly once, as cutout
  or backdrop, and the union is cross-checked against `look_layer`'s `GRADED` so
  the two dicts cannot drift apart.
- Both materials resolve to the one shader.
- Ceilings on `ao_strength` and `rim_strength`, following the
  `GRADE_SATURATION_CEILING` pattern.
- `light_dir` points upper-left, asserted against the sign of the three
  historical shadow offsets, so the light story stays consistent if it moves.
- The seven outer-AO instances carry `offset == (0,0)` with alpha and blur in
  band.
- **The darkening guard** is a *measured gate*, not an automated test. Render
  the Lobby before and after and require the whole-frame mean luminance to move
  by less than ±1%. AO may redistribute light locally; it may not quietly
  re-darken a scene that has already been lightened twice. If a value cannot
  pass this, the value is wrong, not the gate.

  It cannot be automated here: the runner does `suite.call(name)` without
  awaiting, so no test can wait for a rendered frame, and a test that tried
  would abort mid-way and report zero assertions. So the numbers are taken by
  the §4 method in a running game and **recorded in the commit message**, the
  way `6930dfa` recorded the vignette's 5–8.5% corner darkening. What the suite
  *can* pin is the ceilings the measurement produced.
- Alpha still passes through untouched (extends the existing assertion).

Suites expected to stay green without edits: `viewport_editability` (the shafts
are authored in a `.tscn`, so nothing is built at runtime), `tall_screen_layout`,
`lobby`, `lobby_layout`, `minigame_art`.

`tests/test_paper_shadow.gd` changes: the Lobby re-enters `_CONTACT_SHADOWS`,
and `test_the_lobby_desks_cast_no_shadow` is removed.

## 8. Risks

| Risk | Mitigation |
|---|---|
| AO re-darkens what two rounds of grade-halving just lightened | The ±1% whole-frame luminance guard in §7 |
| Transparent pixels still run the fragment shader — a desk plate is 92% transparent but pays for its whole rect | Coherent early-out on `src.a <= 0.0`; the transparency is contiguous, so whole tiles skip the taps |
| `fwidth` unsupported or wrong on the mobile renderer | Checked on a real frame **first** (§1.4); documented fallback |
| The rackets are 3.5% opaque at 0.34 scale — mostly edge, so mostly rim | Per-plate opt-out costs nothing (§5.1) |
| Editor `scene_save` bakes `@tool` state into scenes it touches | Known hazard; diff every scene after every save, and prefer restore-from-HEAD plus a text edit for one-property changes |

## 9. Acceptance

- Every one of the 21 cutouts wears the cutout material; every one of the 9
  backdrops wears the plain one; the census test passes.
- The Lobby's whole-frame mean luminance moves less than ±1% against `HEAD`,
  measured by the §4 method and recorded in the commit message.
- Each of the four effects can be switched off independently, verified by the
  test suite passing with each strength zeroed in turn.
- The debug overlay's Look page moves every plate in the scene live.
- Full suite green, with the two expected dirty files (`kejartes_theme.tres`,
  `default_bus_layout.tres`) checked and reverted.
