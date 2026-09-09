# Cream panel language — AturJadwal rows, ghost tracks, and confirm-pair semantics

**Date:** 2026-09-10
**Status:** design, awaiting review
**Branch:** `Textures`

## Problem

A design mentor reviewed the project and raised three notes:

1. The olive-green panel behind the AturJadwal activity rows is drab and
   clashes with the warm chrome established by the two 2026-09-07 warm-UI
   passes.
2. The screen is cluttered: each activity row nests four surfaces — the green
   card, a dark brown slab, a darker inset pill, and a saturated category
   bar — so the eye has no single place to land.
3. The result should read sleeker without becoming sterile. It is a game for
   school-age players; the rows must still look tappable and the bars must
   still feel satisfying to fill.

This is part two of the consistency work begun in the 2026-09-07 passes.

## What is actually green

The green is not a token. `Assets/Theme/design_tokens.tres` is already
cream-based (`surface_page #FBF1E3`, `surface_card #FFFDF8`). The green comes
from a single texture, `Assets/Images/UI/penjadwalan_card_bg.png`, used twice
in `Scenes/AturJadwal/atur_jadwal.tscn`:

- as the card behind the activity rows, and
- 9-sliced at a different `region_rect` as the panel behind the "PERINGATAN"
  confirm dialog.

One replacement therefore fixes both surfaces the mentor pointed at.

The clutter, by contrast, *is* in the tokens: `preview_row_fill #6B4B33` and
`preview_pill_fill #4A3728`, plus a 3px `preview_row_border #2E2118` stroke
around every row.

## Scope

Four sections, in dependency order. Sections 1 to 3 are confined to AturJadwal.
Section 4 spans eight scenes and is the only part carrying real regression
risk.

### Section 1 — the cream row

`PreviewRow` and `PreviewPill` are consumed by exactly one scene,
`Scenes/AturJadwal/ActivityRow.tscn`. Nothing else inherits these changes.

- The card becomes a single cream sheet, `#FFFDF8`, inside the existing
  `#7A4A2B` border. No per-row slab, no black stroke.
- Rows are divided by a 1px `#EFE0CB` hairline.
- Every row keeps a recessed track at `#E6DAC6`: a gauge on Akademik, Seni
  Budaya and Atletik.
- Category colour appears **only** as the bar fill. Row icons and labels move
  to `text_secondary` brown.

Token changes in `Assets/Theme/design_tokens.tres`:

| Token | From | To |
|---|---|---|
| `preview_row_fill` | `#6B4B33` | `#FFFDF8` |
| `preview_pill_fill` | `#4A3728` | `#E6DAC6` |
| `preview_row_separator` (new) | — | `#EFE0CB` |
| `preview_row_pressed_fill` (new) | — | `#F0E2CD` |

`Assets/Images/UI/penjadwalan_card_bg.png` is **replaced in place** with a cream
recolour at identical dimensions and `region_rect` geometry, rather than
deleted. Both consumers in `atur_jadwal.tscn` reference it by two different
`region_rect` values against the same source image, so replacing the file
leaves both call sites untouched; removing it would require re-authoring the
dialog panel as well. The replacement is a generated placeholder in the
established manner and is recorded as such in the project guide.

`preview_row`'s `set_border_width_all(3)` drops to 0. The hard drop shadow
(`preview_row_shadow_*`) goes with it; depth now comes from the inset track,
not from a stroke plus shadow.

Because two of these are **new** `@export`s on a `Resource`, the editor cannot
see them until it restarts. This section therefore requires an editor restart
followed by a theme rebake, the same constraint that deferred the AturJadwal
shelf work.

### Section 2 — ghost tracks for Wirausaha and Libur

Wirausaha and Libur have no target stat, so they carry no gauge — today they
use `PreviewPillFlat`, an empty stylebox, and show cost/gain chips directly on
the row. On a dark slab that reads acceptably. On a flat cream sheet with
hairline rules, a row with no track collapses visually beside the three that
have one.

These two rows get a **ghost track**: the same silhouette as a gauge, used as a
container rather than a meter.

- A new `StyleBoxTexture` variation, `PreviewTrackGhost`, drawn from a
  placeholder PNG whose body is flat `#E6DAC6` and whose **alpha** ramps from
  0.18 at the left edge to 1.0 at the right.
- The ramp floors at 0.18 rather than 0 so the left-hand chip keeps a faint
  bed instead of floating on bare cream.
- The category motif — the coin for Wirausaha, the crescent for Libur — is
  watermarked at the track's solid right end in `#C9B694`, a step lighter than
  the row icon's `#7A4A2B`, so it reads as absent rather than as a second
  active element.
- Cost/gain chips group left in reading order rather than splitting to both
  ends, so they do not collide with the watermark.

The stylebox must use `AXIS_STRETCH_MODE_STRETCH`, **not** the
`AXIS_STRETCH_MODE_TILE` that `ThemeFactory.gd:637` uses for the `BarFill`
textures: a horizontal alpha ramp sawtooths back to transparent at every
repeat if tiled. The 9-slice's left cap must be authored at alpha 0.18 to match
the ramp's start, or a seam shows at the rounded end.

`tests/test_bar_contrast.gd`'s 0.90 mean-luminance floor governs `BarFill/`
textures specifically, because those multiply against an accent colour. A track
texture is not multiplied by anything and sits outside that test's remit. This
section does not fight that ratchet.

New assets, all generated placeholders in the established manner (PowerShell +
`System.Drawing`), drop-replaceable at the same paths:

- `Assets/Images/UI/BarFill/track_ghost.png` — 256x48, 22px 9-slice caps.
- `Assets/Images/UI/BarFill/icon_ghost_koin.png`
- `Assets/Images/UI/BarFill/icon_ghost_sabit.png`

The row icons in the left circles are **not** part of this. `stat_akademis`,
`stat_senibudaya`, `stat_olahraga`, `stat_energy` and `stat_mood` are existing
team art, already wired at `atur_jadwal.tscn:13-17`, and stay as they are.

The watermark is a `TextureRect` authored into `ActivityRow.tscn` behind the
chip labels, not built at runtime, so it stays clear of the
`tests/test_viewport_editability.gd` ratchet.

### Section 3 — the press state

`ActivityRow` extends `Button`, but the surface being pressed is a child
`Panel` carrying `PreviewRow`, and `Panel` has no pressed state in Godot. The
sink is therefore driven from `Scripts/AturJadwal/ActivityRow.gd`, swapping the
container's stylebox on `button_down` / `button_up`, alongside the existing
`Juice.press` hook.

This means the row bakes two variations, `PreviewRow` and `PreviewRowPressed`.
Pressed, the row sinks into `#F0E2CD` with an inset top edge; the hairlines do
not move.

### Section 4 — confirm-pair semantics

`SuccessButton` and `DangerButton` are used across eight scenes and four
scripts. Today every confirm is a green/red pair regardless of what is being
confirmed. That spends the loudest colours in the palette on ordinary "carry
on?" prompts, and leaves nothing louder for genuinely destructive ones. Two of
the scripted uses are outright misuses:

- `Scripts/CutScene/cut_scene.gd:116` styles a **skip** button as danger.
- `Scripts/CutScene/cut_scene.gd:205` styles the **grade 9 selection** as
  danger.

Neither discards anything. The split is by meaning, not by colour:

| Case | Variation | Rationale |
|---|---|---|
| Genuinely destructive — minigame quit, discarding progress | `DangerButton` | Rare, so red stays alarming |
| Ordinary confirm — AturJadwal "Teruskan?", event select, ApplyItemScreen | `PrimaryButton` + `SecondaryButton` | One coloured element per dialog |
| Something is earned rather than confirmed | `SuccessButton` | Reward, not confirmation |

The AturJadwal warning becomes a cream panel with a solid brown **YA** and an
outlined **TIDAK**.

Affected: `atur_jadwal.tscn`, `ApplyItemScreen.tscn`, `loby.tscn`,
`QuitConfirmDialog.tscn`, `EventStudentSelectDialog.tscn`, `student_card.tscn`,
`student_list.tscn`, `cut_scene.gd`, `BaseMinigame.gd`,
`EventStudentSelectDialog.gd`, `student_card.gd`.

`cut_scene.gd` and `BaseMinigame.gd` assign variations in script and must be
read before the swap. `BaseMinigame.gd:144` documents a null-PNG fallback that
depends on the theme's `DangerButton` styling; a blind find-and-replace there
would put an outline button where a minigame expects a filled one.

## Non-goals

- No new persistence. Nothing here touches `GameState`.
- `Balance.gd` is untouched.
- The `stat_*.png` row icons stay as the team authored them.
- The emoji in `cut_scene.gd:205` ("🎓 KELAS 9") violates the 2026-09-02
  iconography ban but is unrelated to this pass. It is recorded here so it is
  not lost, and should be fixed separately.

## Testing

- `tests/test_theme_factory.gd` — extend for the new variations
  (`PreviewTrackGhost`, `PreviewRowPressed`) and the two new tokens.
- `tests/test_bar_contrast.gd` — unchanged; assert explicitly that the ghost
  track is outside its remit rather than leaving that implicit.
- `tests/test_viewport_editability.gd` — `BASELINE` must not rise. The
  watermark is authored in the scene, so it should not.
- `tests/test_script_documentation.gd` — every new `@export` needs its `##`
  line.
- A new suite covering the section 4 split: assert that no non-destructive
  confirm carries `DangerButton`.

The suite is 960 tests across 65 suites and must stay green.

## Risks

- **Editor restart required.** Two new `Resource` `@export`s are invisible to a
  running editor. Restart, then rebake via `Scripts/Design/BakeTheme.gd`.
- **Section 4 is the regression surface.** Eight scenes, two of them driven by
  script. Sections 1 to 3 are confined to one scene and can land
  independently.
- **The ghost track is a judgement call.** It solves a problem predicted from a
  sketch, not observed in a build. Section 1 should be screenshotted before
  section 2 is committed to; the two rows may look fine without it.

## Sequencing

1. Section 1, then screenshot and review before continuing.
2. Sections 2 and 3.
3. Section 4 last, as its own reviewable change.
