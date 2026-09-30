# SchoolDay cloud layer — design

**Date:** 2026-09-30 · **Branch:** `feat/schoolday-cloud-layer` · **Status:** approved in chat

## Goal

The artist split the SchoolDay sky into two paintings: `loading day2_sky`
(the colour gradient) and `loading day2 _cloud only` (the painted clouds on
transparency), both 3998×3997, from the team Drive folder
`170OalnwhLifMfQaOjjkhZFJrl0cYvo5I`. Swap them into `BookClockWidget`:

- the new sky replaces the current rotating sky, same behaviour;
- the new cloud painting replaces the three drifting SVG clouds and keeps
  their behaviour, except that instead of sliding sideways it **turns slowly
  and constantly on its own clock**, independent of the sky (owner's pick
  "B", 2026-09-30, knowing the painted sunset/day colours will drift out of
  register with the sky over time).

## Art

| Source (Downloads) | Target | Size |
|---|---|---|
| `loading day2_sky - Copy.png` | `Assets/Images/SchoolDay/transition_background.png` (overwrite, uid kept) | 2048×2048 |
| `loading day2 _cloud only- Copy.png` | `Assets/Images/SchoolDay/Sky/cloud_layer.png` (new) | 2048×2048, alpha kept |

Both are downscaled with a high-quality filter to 2048, the size the current
sky already uses (a 4000² RGBA texture is ~64 MB of VRAM on a phone). The
3998×3997 source is stretched to square; the one-pixel difference is
invisible.

The new sky still carries the stray bottom-left layer; the existing
`sky_cover_margin >= 1.0` rule keeps it off screen, unchanged.

`cloud_a.svg`, `cloud_b.svg`, `cloud_c.svg` (and their `.import`) are deleted
once nothing references them. DEBT.md's liveliness-set line drops "three
clouds" and the new `cloud_layer.png` is listed as final artist art, not a
placeholder.

## Scene (`BookClockWidget.tscn`)

`CloudLayer` keeps its name, its place in the draw order (above `SkyBodies`,
below `SchoolForeground`) and the `CloudDrift` script. Its three
TextureRect children are replaced by one:

- `CloudLayer/Clouds` — TextureRect, `cloud_layer.png`, `expand_mode = 1`,
  `stretch_mode = 6`, `mouse_filter = 2`.

## Geometry (`BookClockWidget.gd`)

`_fit_layers()` gives `CloudLayer/Clouds` exactly the sky's square: same
side, same position, same `pivot_offset`, so the cloud vortex is centred on
the same pivot (`sky_pivot_ratio`, bottom-centre) at the same scale and no
screen corner is ever uncovered mid-turn. A `CLOUDS_PATH` const names the
node. At `_ready()` the clouds' rotation is set to the sky's
`dawn_rotation_degrees`, so a visit starts in register with the sky; from
then on the widget never touches the clouds' rotation again.

Night dimming is unchanged: `set_night()` already modulates `CloudLayer` by
`night_cloud_dim`, and that reaches the new child.

## Motion (`CloudDrift.gd`, rewritten)

The header comment is rewritten for the one-painting layer. Exports:

- `spin_degrees_per_second: float = -2.0` — how fast the clouds turn;
  negative is counter-clockwise, the sky's direction; 0 stops it. At 2°/s a
  full turn takes 3 minutes.
- `base_opacity: float = 0.85` — the layer's alpha (kept; `opacity_step` and
  the per-child parallax `base_speed` / `speed_step` go, having no meaning
  with one child).
- `preview_in_editor: bool = false` — spins in the editor viewport too.

Behaviour:

- `_process` spins only in the game, or in the editor when
  `preview_in_editor` is on; never under `GameSettings.reduce_motion`.
- `step(delta)` is public (the suite drives it): adds
  `spin_degrees_per_second * delta` to every Control child's
  `rotation_degrees`.
- `NOTIFICATION_EDITOR_PRE_SAVE` puts each child back to the rotation it had
  when the preview started, so a scene save never bakes a random angle.

Every `@export` keeps its `##` line (`test_script_documentation`).

## Tests (`tests/test_sky_life.gd`)

- Replace `test_clouds_drift_at_parallax_speeds_and_wrap` with
  `test_clouds_spin_on_their_own_clock`: `step(1.0)` changes the child's
  rotation by `spin_degrees_per_second`; the sky's rotation is unchanged
  by it; the source gates `_process` on `reduce_motion`.
- New `test_cloud_layer_matches_the_sky_square`: after `_fit_layers()` at
  1080×1920 and 1080×2400, `Clouds` has the sky's size, position and
  pivot offset.
- New `test_clouds_start_in_register_with_the_sky`: a fresh widget's clouds
  rotation equals `dawn_rotation_degrees`.
- Keep the draw-order and night-dim tests as they are.
- Scan: no `.tscn`/`.gd` references `cloud_a/b/c.svg`.

## Verification

Targeted `test_run` of `test_sky_life`, `test_book_clock_phases`,
`test_sky_transition`, `test_tall_screen_layout`,
`test_viewport_editability`, `test_script_documentation`; then the full suite
at the end. Before/after full-size screenshots of SchoolDay at dawn, midday
and night sent to the owner.

## Out of scope

Tinting the clouds by time of day (the painting carries its own colours);
changing the sky's sweep, the sun/moon or the stars.
