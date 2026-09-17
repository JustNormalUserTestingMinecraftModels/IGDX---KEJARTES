# Achievement claim celebration — design

Asked 2026-09-17 through `/gamecode`. Follows
`2026-09-17-achievements-design.md`. Reference: `achievementclaim_mockup.png`.

## What the player gets

1. **Debug reset.** Every launch of the game starts with no achievement
   progress: nothing unlocked, nothing claimed, counters at zero.
2. **Claim celebration.** Tapping **Klaim** blurs the Achievements screen and
   shows "SELAMAT, ANDA MENDAPATKAN", the achievement's icon large in the
   middle with animated light rays and a glow behind it, the achievement's
   title below, and "tekan dimana saja untuk menutup" near the bottom.
   Paper confetti bursts. A tap anywhere closes it.
3. **White outline** around every achievement icon: on the cards, in the
   unlock banner and in the celebration.

```
Achievements screen ─Klaim─→ Achievements.claim() ─ok─→ row turns gradient
                                                     └→ AchievementClaimPopup (blur, rays, confetti)
                                                          tap anywhere → fades out, frees itself
```

## Logic

- **Reset.** `Achievements.gd` gains `const RESET_ON_LAUNCH := true`. When it
  is true, `_ready()` calls `reset()`, which also deletes
  `user://achievements.cfg`, instead of `load_progress()`. All saving stays as
  it is, so progress still survives scene changes within a session. Setting
  the const to `false` restores cross-session saving. The line is marked as
  a debug switch.
- **Popup.** `achievements_screen.gd` instances `claim_popup_scene` (an
  `@export PackedScene`) on a successful claim, adds it on top of the screen
  and calls `open(entry)`. `open` fills the icon and title, then plays the
  entry: blur fades in, the icon pops in (`Juice.pop_in`), the texts fade in
  and the confetti fires. Input is ignored for `input_lock_time` (0.4 s) so
  the Klaim tap does not close it. After that, any press closes it: a fade
  out, then `closed` is emitted and the node frees itself.
- **Glow.** `Scripts/Shaders/achievement_glow.gdshader` is an additive
  canvas_item shader on a square `ColorRect` behind the icon. A soft radial
  core plus `ray_count` light shafts rotate slowly (`rotate_speed`). Each ray
  flickers on its own noise over `TIME`, and the rays fade with distance.
  Colour, intensity and speeds are uniforms, authored in the scene's
  material.
- **Outline.** `Scripts/Shaders/icon_outline.gdshader` shrinks the art inside
  its rect by `outline_width` (a UV share) and paints `outline_color` wherever
  a neighbouring sample within that width is opaque. It samples 16
  directions, so the outline follows the icon's rounded corners exactly. One
  shared material, `Assets/Images/Achievements/icon_outline_material.tres`
  (white, 0.03), goes on the three icon nodes.

## State

No new state. It reads `AchievementCatalog.get_entry(id)`, calls
`Achievements.claim(id)` as before, and uses `Achievements.RESET_ON_LAUNCH`.
Nothing crosses the `approved_students` / `StudentData` bridge.

## Grades

Same in every grade.

## Files

- `Scripts/Achievements/Achievements.gd`: edit, the reset switch
- `Scripts/Shaders/achievement_glow.gdshader`: new
- `Scripts/Shaders/icon_outline.gdshader` and `Assets/Images/Achievements/icon_outline_material.tres`: new
- `Scenes/Achievements/AchievementClaimPopup.tscn` and `Scripts/Achievements/AchievementClaimPopup.gd`: new
- `Scripts/Achievements/achievements_screen.gd`: edit, spawn the popup
- `Scenes/Achievements/AchievementRow.tscn` and `AchievementToast.tscn`: edit, outline material on the icon
- `Scripts/Design/ThemeFactory.gd`: new `AchievementClaimHeadlineLabel`,
  `AchievementClaimTitleLabel` (display font, `text_on_brand` fill,
  `event_warning_ink` outline) and `AchievementClaimHintLabel` (body, white)
- Tests: `achievement_claim_popup` (new), `achievements` (reset),
  `achievement_screen` (outline), `theme_factory` roster

## Layout (1080×1920, anchored so that it fills tall phones)

- `Blur` is full rect, using the shared `shop_hub_blur_material.tres`.
- The headline is top-centre at y 240–450 and 960 wide, wrapping to two lines.
- The icon is centre-anchored at 540×540, its centre 165 px above screen
  centre. `Glow` is 1100×1100 around the same centre.
- The title is centre-anchored at y +230 to +460 and 960 wide.
- The hint is bottom-anchored, 270 px above the bottom edge.
- `Confetti` is a `PaperConfetti.tscn` instance at (-40, 1780), as ResultCheckup uses it.

## Not doing

A mixed-case face for the title (the mockup's lettering is not Boohong; we
keep the project's display font, which renders in capitals). A settings
toggle for the reset. Particles for the light (a shader is cheaper and loops
smoothly).
