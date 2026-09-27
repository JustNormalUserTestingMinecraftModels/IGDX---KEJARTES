# Paper confetti for the week-end checkup — design

**Date:** 2026-09-12
**Scope:** `ResultCheckup` only. `CelebrationConfetti.tscn`, `ApplyItemScreen`,
the minigame `ResultConfetti` and `particle_confetti.png` are untouched.

## Goal

The week-end celebration on `ResultCheckup` currently drops ~90 untinted white
chips from the top edge. Replace it with a **party-popper burst from both
bottom corners**: red, yellow and blue flat sheets that shoot up and inward,
hang at the top of their arc, and flutter down while visibly flipping like
paper.

The gate does not change: it fires only when a card `gained_ground()`, on the
same beat as today (`ResultCheckup.gd` stage 5).

## Approach

Flip shader + air drag (chosen over "process-material only", which reads as
spinning chips, and a sprite-sheet flip, which needs art that does not exist).

- **Flip** — a `canvas_item` shader squashes each particle's quad on its own
  x axis by `cos(TIME * speed + phase)`, phase and speed hashed per particle
  from `INSTANCE_ID`. A flat sheet turning edge-on reads as 3D tumbling. The
  back face (`cos < 0`) is darkened, so the flip is legible.
  In a 2D canvas shader the particle's instance transform is folded into
  `MODEL_MATRIX`, so `VERTEX` in `vertex()` is still the quad's local space —
  the squash follows each piece's own rotation.
- **Paper drag** — `ParticleProcessMaterial.damping` below `gravity`: the
  climb decelerates at `gravity + damping`, the fall accelerates at only
  `gravity − damping`, so pieces hang and drift instead of dropping.
  Turbulence adds a small side-to-side wobble. (Damping ≥ gravity would park
  pieces mid-air, since damping pulls speed toward zero every frame.)

## Components

### `Scripts/Shaders/paper_flutter.gdshader` (new)

`shader_type canvas_item;` Uniforms, each with a hint and a `//` doc line:

| Uniform | Default | Meaning |
|---|---|---|
| `flip_speed` | `7.0` | Base flip rate, radians/s |
| `flip_speed_jitter` | `0.5` | Per-piece speed spread, ± fraction of `flip_speed` |
| `back_shade` | `0.35` | How much darker the back face is (0 = same, 1 = black) |

`vertex()`: hash `INSTANCE_ID` into two values in [0,1); `c = cos(TIME *
flip_speed * (1 + jitter * (2*h1 − 1)) + h2 * TAU)`; `VERTEX.x *= c`; pass
`shade = mix(1.0, 1.0 − back_shade, step(c, 0.0))` as a varying.
`fragment()`: `COLOR = texture(TEXTURE, UV) * COLOR; COLOR.rgb *= shade;`
(`COLOR` carries the particle's ramp-picked tint from the vertex stage).

### `Scenes/SchoolSimulation/PaperConfetti.tscn` (new)

```
PaperConfetti   GPUParticles2D, script RewardParticles   ← left cannon, at (0,0)
└─ RightCannon  GPUParticles2D                           ← at (1160, 0)
```

Shared by both emitters (one sub-resource each, referenced twice):

- `texture` = `particle_confetti.png` (white rounded rect, tinted by the ramp)
- `material` = one `ShaderMaterial` using `paper_flutter.gdshader`
- one `GradientTexture1D`, set as `color_initial_ramp` on **each** cannon's
  `ParticleProcessMaterial` (the property lives on the process material, not
  the node), over a `Gradient` with
  `interpolation_mode = 1` (constant), offsets `[0.0, 0.3333, 0.6667]`,
  colors **red `#E5484D`, yellow `#FFC93C`, blue `#3B82F6`** — each piece
  draws a uniform random point on the ramp, so it lands on exactly one of the
  three, never a blend. (Yellow is `currency_gold`'s value; the tokens carry
  no blue, and particle resources do not read tokens.)

Per emitter (starting values — tune live, see Verification):

| Setting | Value |
|---|---|
| `emitting` / `one_shot` | `false` / `true` |
| `amount` | `60` each (120 total) |
| `lifetime` | `3.2` |
| `explosiveness` | `0.9` |
| `visibility_rect` | left `Rect2(-100, -1900, 1300, 2100)`; right `Rect2(-1200, -1900, 1300, 2100)` — the default 200×200 rect sits half off-screen at the corners and would cull the burst |

Two `ParticleProcessMaterial`s, mirror images:

| Setting | Left | Right |
|---|---|---|
| `direction` | `(0.45, -1, 0)` | `(-0.45, -1, 0)` |
| `spread` | `14` | `14` |
| `initial_velocity` | `1800–2400` | same |
| `gravity` | `(0, 900, 0)` | same |
| `damping` | `560–640` | same |
| `angle` | `0–360` | same |
| `angular_velocity` | `−180–180` | same |
| `scale` | `0.25–0.40` | same |
| `turbulence_enabled` | `true`, `noise_strength 1.5`, `influence 0.08–0.16` | same |
| `emission_shape` | sphere, radius `20` | same |

`RewardParticles.fire()` already restarts child emitters and frees the root
after `lifetime * (2 − explosiveness) + 0.5` ≈ 4.0 s, so no script changes.

### `ResultCheckup` wiring

- `ResultCheckup.tscn`: the `Celebration` node becomes an instance of
  `PaperConfetti.tscn` (replacing the `CelebrationConfetti` instance), at
  `position = Vector2(-40, 1780)`, `z_index = 100` kept. It stays an idle
  position marker, as today.
- `ResultCheckup.gd`: `_CELEBRATION_SCENE` points at `PaperConfetti.tscn`.
  Nothing else in the stage-5 block changes.

## Screen-size note

`window/stretch/aspect = "expand"` at 1080×1920. On phones taller than 9:16
the width stays 1080 and extra height is added below, so the cannons sit a
little above the true bottom — acceptable. On screens wider than 9:16 (tablets)
the right cannon lands short of the right edge. Accepted for now; making the
right cannon track the viewport would need a `@tool` script and is not wanted
yet.

## Testing

New `tests/test_paper_confetti.gd` (`@tool`, no coroutines):

- root is a `RewardParticles`, `one_shot`, idle; child `RightCannon` exists,
  is a `GPUParticles2D`, `one_shot`, idle
- the cannons sit at opposite edges (`RightCannon.position.x > 1000`) and aim
  inward (left `direction.x > 0`, right `direction.x < 0`, both `y < 0`)
- `damping.max < gravity.y` on both (paper falls, never parks)
- both use one `ShaderMaterial` whose shader path is `paper_flutter.gdshader`
- the color ramp has constant interpolation and exactly the three colors
- `visibility_rect` is wider than 1000 px on both
- the shader source declares the three uniforms

`tests/test_result_checkup.gd`: add a scan that `ResultCheckup.gd` references
`PaperConfetti.tscn` and not `CelebrationConfetti.tscn`; the existing
`Celebration`-node test keeps passing (still a one-shot, idle `GPUParticles2D`).

Existing `test_day_summary` / `test_apply_item_screen` checks on
`CelebrationConfetti.tscn` stay green because that scene is untouched.

## Verification

Targeted `test_run` for `paper_confetti`, `result_checkup`, `day_summary`,
`viewport_editability`. Then run the game, reach `ResultCheckup` with a week
that gained, freeze `Engine.time_scale = 0` about 1.2 s after the burst fires,
and judge a **full-size** screenshot: three distinct colors, pieces at varied
flip widths (some edge-on), darker backs visible, both corners contributing.
Adjust velocity/damping in the `.tscn` if the arc peaks too low or too high.

## Out of scope

`CelebrationConfetti`, `ApplyItemScreen`, minigame confetti, new art, audio
(the `reward` cue is unchanged), viewport-tracking cannons.
