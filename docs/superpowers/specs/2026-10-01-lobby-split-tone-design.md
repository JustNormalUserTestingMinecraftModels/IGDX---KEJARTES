# Lobby split-tone grade — design

Date: 2026-10-01. Branch `feat/lobby-split-tone`. Owner-approved in
brainstorming the same day.

## Goal

Give the Lobby the colour of the owner's key-art reference (the KEJAR TES
poster: six students around the calendar logo): **cream highlights,
plum-brown shadows, a dusty rose in the mid-tones, muted saturation**. Colour
only. The Lobby's light (shafts, LightPool, WorldEnvironment bloom) stays as
it is. Once the values are tuned on the Lobby, a later pass carries them to
the rest of the game.

### What the reference measures

Sampled from the poster (640x369), pixels with saturation under 25% (the
neutral greys and whites, where a grade shows most plainly):

| Band (luma) | Mean RGB | Reads as |
|---|---|---|
| 40–90 | 63, 53, 54 | plum-brown: red up, blue at or above green |
| 90–150 | 141, 118, 118 | dusty rose |
| 150–200 | 194, 166, 157 | warm rose-beige |
| 200–256 | 242, 232, 224 | cream |

The darkest pixels average 32, 20, 30: blue stays above green all the way
down. Today's single multiplied `tint` cannot produce that. It pushes every
band the same way, so warm highlights also mean orange shadows. Hence a
split-tone: one colour for shadows, another for highlights.

## Out of scope

- Spotlight pool, stronger vignette, background blur (the owner chose
  "colour only").
- Any screen but the Lobby. The spread is its own later pass (below).
- The Lobby's eye layers (Sclera, Pupil, Eyelashes, Eyelid, Eyebrows). They
  are small and mostly black or white, and stay ungraded.
- Today's five grade values (saturation, contrast, exposure, tint, amount)
  on every material, the Lobby's included. They do not change.

## Revisions after the first live capture (2026-10-01)

1. **Clamp before the rescale.** Contrast above 1 leaves a near-black
   pixel's green and blue just under zero; its luma lands on zero and the
   rescale divided two near-zero numbers, turning black hair (0, 0, 0) into
   grey (37, 32, 32) on Marcel. The block now works on `max(rgb, 0)`.
2. **`shadow_saturation`, a fifth uniform** (owner's pick, option A). The
   tones alone shifted every band about +6 red: the Lobby's darks (about
   94, 43, 21) have almost no blue for a plum tone to multiply, so they read
   redder, not plum. The darks are now pulled toward their own grey first
   (luma-preserving, fading out toward the highlights with the same
   crossfade). Default 1.0 (untouched); the Lobby starts at 0.35 with
   `split_strength` raised to 0.85. Simulated on the captured frame, that
   moves the 40–90 band from about 105, 50, 25 to about 88, 53, 43, toward
   the reference's 63, 53, 54.

3. **Warm, not plum** (owner, after the full-size capture: "the contrast is
   better now (light and dark) but apply the same warmer color like
   before"). `shadow_tone` is now warm, 1.08 / 1.00 / 0.86, and
   `shadow_saturation` 0.55: the darks keep most of their depth (30–90 band
   about 91, 51, 32, against the original 104, 48, 24) with their warmth
   back. The "plum" in the goal and starting values below is superseded;
   the test pins "shadows stay warm (blue under red)" instead.

4. **Every screen, in the same PR** (owner: "a and apply it to all
   scenes"). Section 6's spread happened at once: the shared plain, cutout
   and splash materials take the landed values, the Look page drives all
   six materials, and the Lobby-only assertion became "every grade
   material agrees". The Lobby's own backdrop material stays, equal to the
   plain one, as the place for a Lobby-only tweak.

## 1. Shader: `Scripts/Shaders/illustration_grade.gdshader`

Four new uniforms, each with a `//` line in the existing style:

| Uniform | Type | Default | Meaning |
|---|---|---|---|
| `shadow_tone` | `vec4 : source_color` | `(1, 1, 1, 1)` | colour the dark parts lean toward |
| `highlight_tone` | `vec4 : source_color` | `(1, 1, 1, 1)` | colour the light parts lean toward |
| `split_balance` | `float : hint_range(0.0, 1.0)` | `0.5` | the luma where shadow hands over to highlight |
| `split_strength` | `float : hint_range(0.0, 1.0)` | `0.0` | 0 = off, 1 = full |

Plus one shader `const`, `SPLIT_WIDTH = 0.35`: the half-width of the
crossfade around `split_balance`. It is fixed, not a knob, to keep the slider
count down.

Applied right after `rgb *= tint.rgb * exposure;` and before the `amount`
mix, inside a uniform branch (`if (split_strength > 0.0)`, constant across a
draw call, so free on every plate that leaves it off):

```glsl
float l = dot(rgb, LUMA);
float t = smoothstep(split_balance - SPLIT_WIDTH, split_balance + SPLIT_WIDTH, l);
vec3 toned = rgb * mix(shadow_tone.rgb, highlight_tone.rgb, t);
toned *= l / max(dot(toned, LUMA), 1e-4);   // hue moves, brightness does not
rgb = mix(rgb, toned, split_strength);
```

**Brightness is preserved exactly before the final clamp.** The renormalising
line scales each pixel back to its own pre-tone luma, so split-tone can never
darken the art. That rule answers the "too dark" history, so the
implementation must keep it.

The shader's header comment gains a "SPLIT-TONE" paragraph: what it is, why
a single tint could not do it, that it preserves luma, and that it is
Lobby-only until the spread pass.

**Every other material keeps the defaults** (white, white, 0.5, 0), so every
non-Lobby screen renders pixel-for-pixel as before.

## 2. Lobby materials

| Material | Wears it | Change |
|---|---|---|
| `illustration_grade_material_lobby.tres` (**new**) | `World/Classroom/BGLayer` | copy of `illustration_grade_material.tres` plus split-tone |
| `illustration_grade_cutout_lobby.tres` | the four `Meja_*` desks | plus split-tone |
| `illustration_grade_face.tres` | each `*Face.tscn`'s `Base` | plus split-tone |
| `illustration_grade_face.tres` (**newly assigned**) | all 24 `Hand_*` and 24 `Items_*` TextureRects under `StudentHandsContainer_Back/Front` | assignment only |

All three carry the same split-tone values. Starting values, read off the
reference:

- `shadow_tone` = `(1.10, 0.96, 1.00)`: plum-brown
- `highlight_tone` = `(1.04, 1.00, 0.94)`: cream
- `split_balance` = `0.5`
- `split_strength` = `0.7`: start under full, because the owner tunes these
  values live and every past round has asked for less

**The hands and items need a grade.** Today they wear no material, which is
invisible only because the grade is faint. Under split-tone, an ungraded hand
next to a plum-and-cream face would read cooler and flatter. They take the
face material, so their colour and light direction match the face beside
them.

**Fallback, decided on the screenshot:** if the face material's inner AO or
rim draws an outline round a hand or item, they get
`illustration_grade_hands_lobby.tres` instead: the face material with
`ao_strength` and `rim_strength` at 0, the same grade and split-tone. That
adds a fourth Lobby material to every agreement check below.

The 48 assignments go through the editor (`scene_open` → `batch_execute`
`set_property` → `scene_save`), never a hand edit of `Lobby.tscn` (CLAUDE.md
4). Diff the scene after the save for baked `@tool` state (memory: editor
saves bake @tool state).

## 3. Tuning: the debug Look page

`Scripts/Debug/DebugLookPanel.gd` gains a **"Split-Tone Lobby:"** block after
"Tampilan Ilustrasi (material bersama)", built with its existing helpers and
driving all Lobby split-tone materials together, like the AO and rim
sliders:

- **Switch:** "Split-Tone Aktif". Off writes `split_strength` 0 and
  remembers the value; on restores it.
- `split_strength`: "Split-Tone: Kekuatan", 0–1, step 0.01
- `split_balance`: "Split-Tone: Titik Tengah", 0–1, step 0.01
- `shadow_tone` R, G, B: "Bayangan R/G/B", 0.8–1.2, step 0.005 each
- `highlight_tone` R, G, B: "Sorot R/G/B", 0.8–1.2, step 0.005 each

`_add_material_slider` writes floats. The six channel sliders need a sibling
helper that writes one channel of a `Color` parameter. The file is at 256
lines; if the block pushes it past its clean-code ceiling
(`tests/test_clean_code.gd`, `ci/clean_code_baseline.gd`), the block moves
into its own `DebugLookSplitTone.gd` helper, as the Look tab itself was
moved out of `DebugManager`.

**Editor preview:** open the Lobby and edit any of the materials in the
Inspector; the change shows live in the 2D view. Nothing persists from the
debug page. Landed values get written into the `.tres` files.

## 4. Tests

| Where | Asserts |
|---|---|
| new `tests/test_lobby_split_tone.gd` (`@tool`, no coroutines) | the Lobby's split-tone materials carry identical `shadow_tone`, `highlight_tone`, `split_balance`, `split_strength`; strength > 0 |
| same | `BGLayer` wears `illustration_grade_material_lobby.tres`; every `Hand_*` and `Items_*` under the two hand containers wears the Lobby face (or hands) material: a new student or slot cannot slip through ungraded |
| same | the shared `illustration_grade_material.tres`, `illustration_grade_cutout.tres` and `illustration_grade_splash.tres` keep `split_strength` 0: the Lobby-only rule, relaxed on purpose by the spread pass |
| same | the shader source contains the luma renormalisation and the `split_strength > 0.0` gate (a source scan; it pins the rule but does not prove the arithmetic, so the live measurement below backs it) |
| same | the new Lobby backdrop material matches the shared backdrop on the five base values and keeps AO and rim at 0 |
| `tests/test_illustration_ao.gd` | census and agreement checks updated for the new backdrop material, the 48 newly graded hand and item plates (cutouts, by alpha) and, if used, the hands material |
| `tests/test_look_layer.gd` | `GRADED` gains the 48 plates and the new material; its saturation and contrast ceilings still hold |
| `tests/test_script_documentation.gd` | any new `.gd` has its `##` header and `##` line per `@export` |

**Live verification (not a test, but required before shipping):**

- Full-size 1080x1920 captures of the Lobby before and after at the starting
  values, sent to the owner (memory: send screenshots of visual changes).
- Mean luma of the `World` layer before and after, measured by sampling the
  viewport with the tree frozen (memory: measure pixels when the game runs
  embedded). Expected change: about zero.
- A zoomed check of one hand against its face for an AO or rim outline: this
  decides the fallback in section 2.
- One non-Lobby screen (a minigame) captured before and after: identical.

## 5. Documentation

- `docs/superpowers/design/style-guide.md`, "Illustration materials": a
  paragraph on split-tone and the Lobby's own backdrop material, naming each
  knob and file, and stating that it is Lobby-only until the spread.
- `docs/superpowers/CHANGELOG.md`: an entry on landing.
- `CLAUDE.md`: nothing. The style guide carries it.

## 6. The spread (a later pass, its own spec)

Copy the landed split-tone values into `illustration_grade_material.tres`,
`illustration_grade_cutout.tres` and the splash material, delete the
Lobby-only assertion, decide whether the Lobby's own backdrop material still
earns its place, and capture every screen with a `World` layer. No new code.
