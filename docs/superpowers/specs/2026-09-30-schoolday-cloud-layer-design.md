# SchoolDay cloud layer — design

**Date:** 2026-09-30 · **Branch:** `feat/schoolday-cloud-layer` · **Status:** approved in chat; revised in build (see Goal)

## Goal

The artist split the SchoolDay sky into two paintings: `loading day2_sky`
(the colour gradient) and `loading day2 _cloud only` (the painted clouds on
transparency), both 3998×3997, from the team Drive folder
`170OalnwhLifMfQaOjjkhZFJrl0cYvo5I`. Swap them into `BookClockWidget`:

- the new sky replaces the current rotating sky, same behaviour;
- the new cloud painting replaces the three drifting SVG clouds and keeps
  their behaviour (night dimming, game-only motion, reduce_motion), but it
  **rides the sky's angle and creeps slowly on top** (owner's pick "A").

**Revised in build, 2026-09-30.** The first pick, an own-clock spin
("B"), was built and screenshotted: the sky turns a full circle in a few
seconds of play, so by every midday the dusk clouds hung over the noon
sky. The owner switched to A. The first render also showed the cloud
painting all but hiding the sun, so the owner put the sun and moon in
front of it ("A" again).

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

`CloudLayer` keeps its name and the `CloudDrift` script, and moves in the
draw order to just above `Stars` and below `SkyBodies`, so the sun and
moon shine in front of it. Its three
TextureRect children are replaced by one:

- `CloudLayer/Clouds` — TextureRect, `cloud_layer.png`, `expand_mode = 1`,
  `stretch_mode = 6`, `mouse_filter = 2`.

## Geometry (`BookClockWidget.gd`)

`_fit_layers()` gives `CloudLayer/Clouds` exactly the sky's square: same
side, same position, same `pivot_offset`, so the cloud vortex is centred on
the same pivot (`sky_pivot_ratio`, bottom-centre) at the same scale and no
screen corner is ever uncovered mid-turn. A `CLOUDS_PATH` const names the
node. `_apply_rotation()` hands every sky angle to
`CloudLayer.follow_sky()`, and `set_day()` calls `reset_drift()` -- SchoolDay
starts each day under the full night, where the snap is hidden.

Night dimming is unchanged: `set_night()` already modulates `CloudLayer` by
`night_cloud_dim`, and that reaches the new child.

## Motion (`CloudDrift.gd`, rewritten)

- `follow_sky(degrees)` sets the angle the clouds ride on; `step(delta)` adds
  `spin_degrees_per_second * delta` to a creep; every child's rotation is
  sky + creep. `reset_drift()` clears the creep; `drift_degrees()` reads it.
- `spin_degrees_per_second: float = -2.0` -- the creep; negative is the
  sky's direction; 0 leaves the clouds riding the sky alone.
- `max_drift_degrees: float = 24.0` -- the creep folds back and forth inside
  this (`pingpong`), so an idle day screen never walks the clouds out of
  register; 0 removes the limit. Added by the local review.
- `base_opacity: float = 0.85` -- the layer's alpha.
- `preview_in_editor: bool = false` -- creeps in the editor viewport too.
- `_process` creeps only in the game, or in the editor under the preview;
  never under `GameSettings.reduce_motion`. `NOTIFICATION_EDITOR_PRE_SAVE`
  clears the creep, so a save never bakes an angle.
## Tests (`tests/test_sky_life.gd`)

- `test_clouds_ride_the_sky_and_creep`: in register at progress 0 / 0.5 / 1;
  `step(1.0)` creeps them `spin_degrees_per_second` past the sky, and the
  creep survives the sky moving.
- `test_a_new_day_puts_the_clouds_back_in_register`.
- `test_cloud_layer_matches_the_sky_square` at 1080x1920 and 1080x2400.
- `test_clouds_start_in_register_with_the_sky`.
- `test_the_old_svg_clouds_are_retired`.
- The draw-order test now pins tint < clouds < sun/moon < school.
- `test_clean_code`'s pinned function count for this file goes 20 -> 24.
## Verification

Targeted `test_run` of `test_sky_life`, `test_book_clock_phases`,
`test_sky_transition`, `test_tall_screen_layout`,
`test_viewport_editability`, `test_script_documentation`; then the full suite
at the end. Before/after full-size screenshots of SchoolDay at dawn, midday
and night sent to the owner.

## Out of scope

Tinting the clouds by time of day (the painting carries its own colours);
changing the sky's sweep, the sun/moon or the stars.
