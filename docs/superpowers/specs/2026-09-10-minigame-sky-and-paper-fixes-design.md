# Minigame, sky and paper fixes — design

**Date:** 2026-09-10
**Status:** approved ("okay do it now", 2026-09-10), not yet implemented
**Scope:** six independent fixes. Badminton (`Badminton.tscn/.gd`, new
`ShuttlecockSprite.gd`), MainBola (`MainBola.tscn/.gd`), BuatBatik
(`BuatBatik.tscn/.gd`), the SchoolDay sky (`BookClockWidget.gd` only — no scene
edit), the StudentCard and ReportCard paper stacks (new
`Scenes/UI/PaperShadow.tscn`), and LombaMenari's backdrop (new
`Assets/Images/Textures/budaya_background.jpg`). No autoload, no `GameState`,
no theme rebake, no `Balance.gd`.

## Summary

| # | What the player sees today | Root cause | Fix |
|---|---|---|---|
| 1 | Badminton shuttle is small, lies sideways, grows on hits | the hit punch saves the live, mid-tween scale as its rest | 2× picture and hit area, upright pose, cork leads, stored rest pose |
| 2 | MainBola goalie cannot be placed in the 2D editor | layout measures a 2×2 editor stub viewport and rewrites the goalie | measure the root's size; the goalie's scene position is the truth |
| 3 | BuatBatik tool pictures do not match their tools | pictures dealt by slot index after the slots are shuffled | each picture authored inside its own tool node |
| 4 | The day's sky starts half-lit and eases in-out | poses −90/−270; SINE/IN_OUT plus smoothstep | +60 → −300 full turn, SINE/OUT, smoothstep off |
| 5 | A paper's shadow stays on the desk when the paper flies | one static `Shadow` behind the stack | `PaperShadow.tscn` inside every paper, drawn behind it |
| 6 | LombaMenari dances in front of a football goal | `background_texture` is `Gawang.jpg`, MainBola's art | `budaya_background.jpg` |

## 1. Badminton — the shuttle

### Today

`Puck/Sprite2D` shows `puck.png` (1240×1754 canvas; the shuttle lies on its
side with the cork on the LEFT) at scale (0.0696774, 0.0492588) — an
86.4×86.4 box, the hit circle's diameter (radius `screen_size.x * 0.04`,
hardcoded in `_ready()`). On a racket hit `_on_puck_body_entered()` toggles
`flip_v`, which is invisible on a sideways shuttle.

**The growth bug.** `_play_hit_bounce_animation()` reads
`base_scale = puck_sprite.scale`, tweens to `base_scale * 1.6` and back to
`base_scale` over 0.52 s. The hit cooldown is 0.22 s. A hit that lands
mid-punch reads an already swollen scale as its base, and its tween ends there,
so the resting size ratchets up with every overlapping hit.
`_play_racket_squash_animation()` has the same flaw (a 0.28 s squash against
the same 0.22 s cooldown) and also captures `idle_texture = sprite.texture`
mid-swap, which can leave a racket stuck on its hit pose.

### Design

**Size.** Double `Puck/Sprite2D.scale` in the scene to (0.1393548, 0.0985176)
and double the hit circle: a new `@export var puck_radius_frac: float = 0.08`
(Configuration group) replaces the literal `0.04`. The hit circle keeps
matching the picture's box (172.8 px at 1080 wide).

**Pose.** `Puck/Sprite2D.rotation_degrees = 90` in the scene: a quarter-turn
clockwise stands the cork up. The authored rotation *is* the cork-up pose — the
script reads it and never hardcodes it — so re-aligning replacement art is an
editor rotate, not a code change.

**Cork leads** (user's choice, 2026-09-10). The cork always points the way the
shuttle flies. After a racket hit re-aims the puck, the sprite turns 180°
(tweened, 0.18 s, QUAD/OUT) when the vertical direction changed. Each serve
snaps the pose to face the receiver — a serve to the player is cork-down — with
no animation, since the puck is teleporting to the serve spot anyway.

**New `Scripts/Minigames/Olahraga/ShuttlecockSprite.gd`** (`@tool`,
`extends Sprite2D`, `class_name ShuttlecockSprite`) on `Puck/Sprite2D` owns the
shuttle's look:

| Member | Role |
|---|---|
| `_ready()` | remembers the rest scale and the cork-up angle: the authored `scale` and `rotation_degrees` |
| `punch()` | kills the running punch, swells to `rest × punch_scale`, settles to rest. Never uses the live scale as a base |
| `face(velocity_y)` | turns 180° only when the direction changed; tweens to an absolute target angle, so an interrupted turn still lands exactly |
| `reset_pose(cork_up)` | kills both tweens, restores the rest scale, snaps the angle |
| `punch_scale` 1.6, `punch_half_duration` 0.26, `turn_duration` 0.18 | the old literals, now documented `@export`s |

Its tweens keep `TWEEN_PAUSE_PROCESS`, as the old punch did. It is a separate
script so the invariant — any sequence of punches returns to rest — can be
tested by behaviour with `Tween.custom_step()`. `Badminton.gd` is not `@tool`,
so its methods do not run in the editor-hosted test runner.

**`Badminton.gd`.** `puck_sprite` is typed `ShuttlecockSprite`.
`_on_puck_body_entered()` calls `puck_sprite.punch()` and
`puck_sprite.face(puck.linear_velocity.y)` after
`_redirect_puck_towards_opponent()`; the `flip_v` toggle and
`_play_hit_bounce_animation()` are deleted. `_reset_puck()` kills any previous
`_serve_tween` before starting a new one and calls
`puck_sprite.reset_pose(target_vel.y < 0.0)`. Rackets: each racket sprite's rest
scale and idle texture are stored once in `_ready()` (after
`_apply_visual_exports()`), a racket's running squash is killed before a new
one starts, and the squash always returns to the stored values.

The serve's lob keeps scaling the `Puck` body (1.0 → 1.7 → 1.0 while frozen) —
a different property from the sprite's punch, so no two tweens share one.

## 2. MainBola — a goalie you can drag

### Today

`MainBola.gd` is `@tool` so the 2D editor can preview the layout.
`_setup_layout()` sizes everything from `get_viewport_rect().size`, which
inside the editor is a 2×2 stub. Confirmed live on 2026-09-10: the root reports
`size` 1080×1920 while the goalie sits at (1, 0.9856) — that is
(2 × 0.5, 2 × 0.28 + 2 × 0.28 × 0.76). Every node is laid out inside a 2×2 box,
the saved `.tscn` carries those values, and `_setup_layout()` rewrites the
goalie's position whenever it runs, so a drag never sticks.

### Design

1. **Measure the root, not the viewport.** `_setup_layout()` reads the root
   Control's own `size`: 1080×1920 in the editor, the full screen in the game
   (`MinigameMenu` adds the scene full-rect). A
   `_notification(NOTIFICATION_RESIZED)` hook re-runs it once the node is
   ready, so the layout follows real resizes. The 2D editor then shows the real
   layout.
2. **The goalie's scene position is the truth.** In the editor
   `_setup_layout()` never moves the Goalie, so he can be dragged anywhere. In
   the game his authored position — design space, 1080×1920 from
   `ProjectSettings` — is captured once and mapped to the real screen by a
   static `design_to_screen()`: `x / 1080 × width`, `y / 1920 × height`, the
   same proportional rule the goal follows. On a taller phone he moves down
   with the goal. `goalie_base_pos`, the dive logic's origin, comes from the
   mapped position.
3. **Retire `goalie_depth_frac`.** Dragging replaces it. `goalie_width_frac`,
   `goalie_height_frac` and `goalie_feet_frac` stay: they size the sprite and
   hitbox around the node's origin, which is his feet.
4. **No visible change until someone drags him.** The scene's Goalie is set to
   (540, 946.176), exactly what today's defaults produce at 1080×1920
   (537.6 + 537.6 × 0.76). Re-saving the scene after the script fix also
   replaces every other node's 2×2 values with real design-space ones.

**Rejected:** a drag that writes back into fraction knobs. It needs editor-side
change detection on a node that has no transform-changed signal — fragile.
**Rejected:** an absolute position with no runtime mapping. The goal would
slide away from him on any phone that is not 9:16.

## 3. BuatBatik — pictures that match their tools

### Today

`_ready()` shuffles the four tool slots (finding the order is the puzzle), then
`_apply_visual_exports()` deals textures by slot index: `tool_texs[i]` onto
`tools_container.get_child(i)`. Slot 0 always shows the pencil, whichever tool
it holds, so the picture disagrees with the tooltip (keyed by node name) and
with the answer check.

### Design

- Author a `ToolTextureRect` (`TextureRect`: full rect, `expand_mode`
  IGNORE_SIZE, `stretch_mode` KEEP_ASPECT_CENTERED, `mouse_filter` IGNORE)
  inside each `ToolN` in `BuatBatik.tscn`, carrying its own tool's art. The
  picture is now part of the tool and travels with it through the shuffle, the
  drag ghost (`duplicate()`) and `reveal_answers()`'s auto-drag. It also shows
  in the 2D editor.
- `_apply_visual_exports()` keeps the root exports as overrides, matched **by
  node name** (`"Tool0": tool0_texture`, …), and no longer builds a
  `TextureRect`. `tests/test_viewport_editability.gd`'s BASELINE for
  `BuatBatik.gd` drops 8 → 7 in the same commit.
- The four `IconLabel` emoji nodes (✏ 🖊 🎨 🔥 — hidden whenever a picture
  exists, which is now always) and the never-called `_get_tool_icon()` are
  deleted.

## 4. The SchoolDay sky — a full day, easing out

Poses chosen from a 12-angle contact sheet of the real composite (sky plus
school foreground), 2026-09-10.

| | Today | New |
|---|---|---|
| `dawn_rotation_degrees` | −90 (half dark, half blue) | **60** (the same view as −300°, the darkest frame) |
| `evening_rotation_degrees` | −270 | **−300** |
| Sweep | 180° | **360°** counter-clockwise: dark → sunrise → blue → dusk → dark |
| Easing | Tween SINE/IN_OUT plus smoothstep (`ease_in_out` true) | Tween **SINE/OUT**, `ease_in_out` **false** |
| `transition_duration` | 2.0 s per phase (4.0 s day) | unchanged unless motion-lab picks otherwise |

- Midday, the arc's midpoint, is −120° (blue). Under SINE/OUT the sky is 71%
  of the way round when the event pops at the day's halfway time: −195°, blue.
- The smoothstep layer must default off. Left on, it would put an ease-in back
  under the tween's ease-out.
- A full turn in the same 4 s spins twice as fast as today, fastest at the very
  start. That is what motion-lab is for: its lab is published for this tween
  (property `fill`, because the tween drives a 0 → 1 progress value) and a
  token re-patches transition, ease and duration. The user is often away, so
  SINE/OUT ships first and a token only overrides it. `transition_duration` is
  also the school day's on-screen length (`SchoolDay._phase_duration()`).
- Script-only. Do **not** `scene_open` `BookClockWidget.tscn` over the bridge;
  it hangs the editor (CLAUDE.md).

## 5. Paper shadows that follow each paper

### Today

`student_card.tscn` and `report_card.tscn` each carry one root-level `Shadow`
(`card_bg.png`, `soft_shadow_material.tres`, tint (0, 0, 0, 0.33), offset
+14/+18 from the paper, scale 1.03) behind six stacked papers
`KertasMurid1..6`. `_transition_page()` throws a paper off-screen (position, a
15° tilt, a fade) and slides the next one in. The shadow never moves.

### Design

- New `Scenes/UI/PaperShadow.tscn`: one `TextureRect` root with exactly
  today's look — `card_bg.png`, `soft_shadow_material.tres`, `self_modulate`
  (0, 0, 0, 0.33), full-rect anchors offset +14/+18, `expand_mode`
  IGNORE_SIZE, scale 1.03, `mouse_filter` IGNORE — plus
  `show_behind_parent = true`.
- Instance it as the first child of all twelve papers (six per scene). A child
  inherits its paper's position, rotation and `modulate`, and
  `show_behind_parent` draws it under the paper, so it flies, tilts and fades
  with it. No animation code changes.
- Delete both root-level `Shadow` nodes.
- One template: tuning the shadow once changes all twelve. Every property sits
  on the instance's root, the only place instance overrides serialise
  (CLAUDE.md 4b).

**Rejected:** keep one shadow and tween it alongside whichever paper moves.
More code, and it couples `_transition_page()` in two scripts to the shadow.

## 6. LombaMenari — the festival backdrop

- Copy `C:\Users\user\Downloads\budaya_background.jpg` (1080×1920, a "Festival
  Budaya Indonesia" school courtyard) to
  `Assets/Images/Textures/budaya_background.jpg`, beside the other minigame
  backdrops. The source stays in Downloads.
- `LombaMenari.tscn`: the root's `background_texture` points at the new art,
  replacing `Gawang.jpg` — MainBola's football goal, a leftover placeholder.
  The `Background` node also gets the texture, so the 2D editor shows it, and
  `stretch_mode` KEEP_ASPECT_COVERED, so a taller phone crops the sides instead
  of stretching the art (matching MainBola's `FieldBG` and BuatBatik's
  backdrop).
- `Gawang.jpg` stays; MainBola still uses it.

## Order of work

The editor hazards in CLAUDE.md (rules 4, 4b, 5) set the order:

1. Asset copy and filesystem scan (§6).
2. Scene edits through the editor — Badminton sprite, BuatBatik tool nodes,
   `PaperShadow.tscn` and its twelve instances, LombaMenari, the MainBola
   goalie's position. Every `scene_save` is followed by
   `git diff HEAD -- '*.gd'`.
3. Script edits through `script_patch`. A new file is written, then given a
   no-op `script_patch` to force the editor to load it.
4. MainBola re-opened and re-saved once the new `_setup_layout()` is live, to
   flush design-space values into the `.tscn`.

## Testing

| Suite | Change |
|---|---|
| `test_shuttlecock_sprite` (new) | behavioural: overlapping punches with `custom_step()` between them return to the rest scale; `face()` turns only on a direction change and lands exactly on cork-up or cork-down, also when interrupted mid-turn; `reset_pose()` restores the rest pose |
| `test_badminton_visuals` | sprite scale doubled, rotation 90 and `ShuttlecockSprite.gd` attached in the scene; `puck_radius_frac` 0.08 export; no `flip_v`; the racket squash reads stored rest values |
| `test_main_bola_layout` | `goalie_depth_frac` retired; layout reads `size`; the editor never moves the goalie; the scene's goalie stands inside the goal mouth; `design_to_screen()` maths; resize hook |
| `test_minigame_art` | each tool slot's own picture matches its name, before and after a shuffle; no `IconLabel`; matching by name; LombaMenari wired to `budaya_background.jpg`, not `Gawang.jpg` |
| `test_viewport_editability` | BASELINE `BuatBatik.gd` 8 → 7 |
| `test_book_clock_phases`, `test_sky_transition` | poses 60 / −300, a 360° sweep, SINE/OUT, `ease_in_out` off |
| `test_paper_shadow` (new) | the template's properties; each of the twelve papers carries a `PaperShadow` drawn behind it; no root `Shadow` left. Replaces `test_report_card`'s root-`Shadow` test |

Targeted `test_run(suite=…)` after each task, one full run at the end (budget
an editor restart, then `git status` for the rebake and bus-layout files).
Visual checks, judged at full size: the running game via the debug overlay's
minigame launcher (Badminton, MainBola, BuatBatik, LombaMenari) and the
StudentCard and ReportCard screens. The sky's new poses are checked with the
offline contact-sheet render, which uses the same maths as `_fit_layers()`,
because SchoolDay needs a scheduled week to reach.

## Risks

- `class_name ShuttlecockSprite` is new: `project_run` needs stop → scan →
  relaunch after it lands (CLAUDE.md).
- `scene_save` can flush a stale script buffer over a patched `.gd`; diff after
  every save.
- MainBola's `NOTIFICATION_RESIZED` can arrive before `_ready()`; the hook
  checks `is_node_ready()`.
- The 2× puck's hit radius is 86 px against the rackets' 65 px, so rallies get
  easier. That is what "2× the size" asks for; `puck_radius_frac` is the knob.

## Out of scope

- The serve lob's size, the trail and particle sizes, the rackets' size.
- MainBola's dead duplicate `FallbackDraw` block (its ratchet count stays 2).
- BuatBatik's other emoji (the tooltip's 🔧, the progress row's ✅ ❌ 🟨 ⬜) —
  minigames sit outside the design system.
- `student_list.tscn`'s own soft shadow.
- The sky art's stray bottom-left layer. Rotation never brings it on screen
  while `sky_cover_margin` ≥ 1.0 (CLAUDE.md, Outstanding debt).
