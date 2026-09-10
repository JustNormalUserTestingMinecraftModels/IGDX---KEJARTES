# Asset refresh and UI pass — design

**Date:** 2026-09-10
**Branch:** `fix/test-suite-compat-shim` (off `Textures`)
**Status:** approved, awaiting implementation plan

Six independent changes driven by a batch of new art dropped in
`~/Downloads`. They share only their asset-intake step; each can land and be
verified on its own.

---

## 0. Asset intake

Every source file is copied into the repo under a project-conventional name.
Four are downscaled first: the project imports textures at `compress/mode=0`
(lossless on disk, **RGBA8 in VRAM**), so a source's pixel dimensions are its
VRAM cost, and several sources are far larger than anything that renders them.

| Source (`~/Downloads`) | Destination | Transform | VRAM after |
|---|---|---|---|
| `CG 2.jpg` | `Assets/Images/CG/cg2.jpg` | copy — already 1080×1920 | — |
| `CG 4.jpg` | `Assets/Images/CG/cg4.jpg` | copy — already 1080×1920 | — |
| `transition_bakcground.png` | `Assets/Images/SchoolDay/transition_background.png` | 3998² → **2048²** | 16 MB |
| `transition_foreground.png` | `Assets/Images/SchoolDay/transition_foreground.png` | copy — already 1080×1920 | 8 MB |
| `uang.png` | `Assets/Images/UI/uang.png` | 1484×1192 → **256×206** | 0.2 MB |
| `dailylogin.png` | `Assets/Images/UI/icon_daily_login.png` | copy — 317×385 | 0.5 MB |
| `day1…day7.png` | `Assets/Images/UI/DailyLogin/day1…day7.png` | 7281×3231 → **1600×710** | 4.5 MB ×7 |
| `rank_s/a/b/c/d.png` | `Assets/Images/EndGame/Ranks/rank_*.png` | 1521×1471 → **512×495** | 1 MB ×5 |

Untransformed, the seven daily-login panels alone would cost 94 MB of VRAM
each — 658 MB. At 1600×710 they are still ~1.7× oversampled against the
~940 px they render at; dropping to 1280 would halve the total again if VRAM
proves tight.

The sky is the one genuine tradeoff. The widget magnifies it to ~4069 px on a
1080×1920 screen, so the 3998² source is near 1:1 and 2048² is ~2× soft — but
the shipped texture today is 1600², so 2048² is already a 28% improvement for
+6 MB, where full resolution costs +54 MB. **Decision: 2048².**

### Known defect in the sky source

`transition_bakcground.png` has a stray layer the artist left visible: a night
street scene pasted into the bottom-left corner. Measured against the widget's
geometry it sits ~2480 source texels from centre versus a 1960-texel visible
radius, so it should never rotate into view — but that is a ~20% margin on a
number that moves if `sky_pivot_ratio` or `sky_cover_margin` is ever retuned.

Implementation must screenshot a full sweep to confirm. The corner should be
cleaned at source; until it is, this belongs in the project guide's
outstanding-debt list.

---

## 1. Intro cutscene

**Files:** `Scenes/CutScene/cut_scene.tscn`, `Scripts/Design/ThemeFactory.gd`

### CG swap

`cut_scene.gd` preloads CGs by path, so overwriting `cg2.jpg` and `cg4.jpg` is
the entire change. No code edit.

### Dialogue box → rounded panel

`DialogueBox` is a `TextureRect` wearing `Assets/Images/UI/cutscene_dialogue.png`.
It becomes a **`Panel` on the existing `Card` type variation** — rounded at
`radius_lg`, `surface_card` fill, `outline_card` border, token shadow.

`Card` is reused rather than adding a `DialoguePanel` variation: a new one
would be field-for-field identical, and every added variation is another
rebake that can silently miss the shipped theme. If the card treatment reads
too light over a full-bleed CG once it is on screen, a distinct variation is
the follow-up — not a pre-emptive one.

A node's type cannot be changed in place, so this is delete-and-recreate
through the editor (project guide rule 4). `DialogueLabel` must be recreated as
a direct child named exactly that: `cut_scene.gd` binds
`$DialogueBox/DialogueLabel`, and `dialogue_box` is typed `Control`, which a
`Panel` satisfies.

### Bigger text

`DialogueLabel` is a `RichTextLabel` with no variation, so it inherits the base
`RichTextLabel` styling ThemeFactory sets at line 951: `normal_font_size` =
`font_body_size` (28).

Add a **`CutsceneDialogue`** RichTextLabel type variation at `font_title` (36),
body face, `text_primary`.

> **Gotcha, already documented in ThemeFactory at line 944:** RichTextLabel
> reads `normal_font_size` and `default_color`, *not* `font_size` and
> `font_color`. Setting the wrong keys is a silent no-op. This variation must
> set `normal_font_size` and `default_color`.

Body face, so `CutsceneDialogue` is **not** added to
`tests/test_theme_factory.gd`'s `DISPLAY_ROSTER`.

### Layout

The box currently spans y 940→2020 on a 1920-tall screen: 100 px hangs off the
bottom edge. Rework:

- Anchor the panel to the bottom with `space_lg` (44) side margins.
- Size it to its text with `space_md` (28) inner padding.
- Place `HintLabel` below it, inside the safe area.

No `theme_override_*`; only layout-only constant overrides, which the style
guide permits.

---

## 2. BookClockWidget — two poses, one sweep

**Files:** `Scripts/SchoolSimulation/BookClockWidget.gd`,
`Scripts/SchoolSimulation/SchoolDay.gd`,
`Scenes/SchoolSimulation/BookClockWidget.tscn`

### Textures

The new sky is square, matching the widget's rotating-square geometry, and the
new foreground is 1080×1920. Both drop in over the existing pair at the same
paths (downscaled per §0); the scene already points at those paths, so no scene
edit is needed.

### Motion

Today the day rests at three authored poses — Dawn (−90°), Midday (−180°),
Evening (−270°) — and `SchoolDay` drives it as two `transition_to()` calls with
the random event between them, so the sky freezes at Midday while the event
popup is up.

Changes:

- **`BookClockWidget.gd`**: delete `midday_rotation_degrees`.
  `current_rotation_degrees()` collapses from a piecewise lerp through midday
  to a single `lerpf(dawn_rotation_degrees, evening_rotation_degrees, eased)`.
  Endpoints stay −90° → −270°, so the day still covers a half-turn — how *far*
  the sky travels is unchanged, only that it no longer rests mid-day.
- **`SchoolDay.gd`**: issue one `transition_to(EVENING, phase1_dur + phase2_dur)`
  at the top of the day and never touch the sky again. The progress bar keeps
  its two-phase fill and `EVENT_TRIGGER_PCT` stays at 50.0, so the event still
  fires exactly when it does now.
- Update the `EVENT_TRIGGER_PCT` docstring, which currently explains the pin in
  terms of "the BookClock's middle pose".
- `Phase.MIDDAY` and `angle_for_phase()` / `progress_for_phase()` keep working
  (progress 0.5 is still meaningful), but nothing drives the sky through
  MIDDAY any more.

### Accepted consequence

The event popup is player-blocking, so a day has variable length while the
sky's sweep is fixed. A slow player will see the sky reach Evening before the
day's second half finishes and hold there. This was flagged and accepted: it
reads as the day getting away from you.

### Tests

`tests/test_book_clock_phases.gd` asserts the three-pose behaviour and must be
rewritten to the two-pose model.

---

## 3. Soft shadows on papers and cards

**Files:** `Scenes/ReportCard/report_card.tscn`,
`Scenes/Minigames/Akademis/QuestionCard.tscn`,
`Scenes/Minigames/Akademis/AnswerCard.tscn`,
`Scenes/Minigames/Akademis/PilihanGanda.tscn`

Two mechanisms, matched to what each target actually is. Nothing here is built
at runtime and nothing is a `theme_override`.

### Textured paper → shader shadow

A `Shadow` `TextureRect` sibling behind the paper, wearing
`Scripts/Shaders/soft_shadow_material.tres` (which blurs the texture's alpha
silhouette), `self_modulate` a translucent black, offset and scaled ~1.03.

- `student_card.tscn` — **already present** in the working tree, uncommitted.
- `student_list.tscn` — **already present** in the working tree, uncommitted.
  Not requested, but pre-existing work in flight; kept rather than reverted.
- `report_card.tscn` — **add**. Same six-`KertasMurid` structure on the same
  `card_bg.png`, so one shared `Shadow` behind the stack, exactly as
  `student_card.tscn` does it.

Implementation must confirm the shadow rect actually lines up with the
`KertasMurid` papers rather than trusting the offsets copied across.

### StyleBox card → `shadow_*` properties

`StyleBoxFlat` renders its own soft shadow, which is the right tool where
there is no texture alpha to blur.

- **`QuestionCard.tscn` / `AnswerCard.tscn`** already carry
  `shadow_color = Color(0,0,0,0.12)`, `shadow_size = 4`,
  `shadow_offset = Vector2(0,2)` — present but barely visible. Deepen to
  approximately `0.22` / `12` / `(0,6)`, tuned on screen.
- **`PilihanGanda.tscn`**: its three `@export` StyleBox slots
  (`answer_btn_normal_style`, `answer_btn_correct_style`,
  `answer_btn_wrong_style`) are null, so choice buttons fall through to the
  theme's dark ink — which that script's own docstring flags as wrong
  ("assign a light rounded StyleBoxFlat instead"). Author all three as light
  rounded `StyleBoxFlat`s carrying the same shadow. All three, not just the
  normal state: the script swaps between them on answer, and a shadow on only
  one would flicker.

### Ratchet

Both minigames are already listed in `tests/test_viewport_editability.gd`'s
`BASELINE` (`Menjodohkan.gd`: 2, `PilihanGanda.gd`: 1). All work here is
`.tscn` and Inspector, so the baseline does not move.

---

## 4. Money chip and coin icon

**Files:** `Scenes/Lobby/loby.tscn`, `Scenes/Koperasi/koprasi.tscn`,
`Scenes/Inventory/inventory.tscn`

### Lobby chip rebuild

`DisplayUang` is a `TextureRect` at 332×187 wearing
`Assets/Images/UI/Desain tanpa judul.png` — a 1920×1080 pink/magenta landscape
image, with the money `Label` sitting on top of it. The project guide already
lists it as debt on both counts: off-palette, and forcing a 332×187 box where
the layout wants 332×96.

Rebuild as a `Panel` on the existing `Card` variation, holding a `CoinIcon`
`TextureRect` (`uang.png`) and the money `Label`, and resize to **332×96 at
(700, 1392)–(1032, 1488)** — bottom edge unchanged, top edge dropped so the
chip matches `DailyLogin`'s height and both bottoms align at y=1488.

Two hard constraints:

- **`DisplayUang/Label` must stay a direct child with that exact name.**
  `loby.gd:57` binds `$DisplayUang/Label`, and `tests/test_lobby.gd` asserts
  that path at lines 114 and 196. So the chip's children are positioned
  absolutely rather than wrapped in an `HBoxContainer` — which also matches
  the surrounding scene, where every node is `layout_mode = 0`.
- **`tests/test_lobby_layout.gd` guards the new geometry.** 332×96 at
  y 1392–1488 clears the front-row head circles at (225, 389) and (845, 389)
  r=110, and the right edge at x=1032 clears the 24 px rim on a 1080-wide
  screen. Both pass.

Switch the `Label` from `BarLabel` to the existing **`CoinLabel`** variation —
`font_title`, `currency_gold`, subtle shadow — which is what it is for.

Type change means delete-and-recreate through the editor.
`Assets/Images/UI/Desain tanpa judul.png` becomes unreferenced, and its
outstanding-debt entry in the project guide is deleted.

### Coin icon elsewhere

Point these at `Assets/Images/UI/uang.png`:

- Koperasi `CoinHUD/CoinIcon`
- Inventory `MainColumn/Header/Row/CoinDisplay/CoinIcon`
- the new daily-login reward chip (§5)

A new file rather than overwriting `Koin.png`: that file is 33×33, shared
across scenes, and the aspect change (1:1 → 1.245:1) could quietly break a
layout not surveyed here. Repointing each consumer is explicit and reviewable.

`WeekRecapBanner`'s `icon_uang.svg` and `CoinShower`'s `particle_coin.png` are
**out of scope** — neither is a HUD coin logo.

---

## 5. Daily login overhaul

**Files:** `Scenes/Lobby/loby.tscn`, `Scripts/Lobby/loby.gd`,
`Scripts/Design/ThemeFactory.gd`

Each `dayN.png` is the **whole panel**: red spiral-bound header with an empty
cream title plate, seven reward slots with slot *N* lit gold and carrying a
gift icon, and a gold claim pill at bottom-centre.

- **Lobby button icon**: `DailyLogin`'s `texture_normal` goes from
  `Assets/Images/UI/pngwing.com (4).png` to `icon_daily_login.png`.
- **Panel background**: `DailyReward`'s texture swaps per day inside
  `_update_daily_login_visual()`, indexed by `GameState.daily_login_day`.
  Resize the panel to the art's 2.253:1 aspect, keeping its top-left anchor at
  (80, 558): 942×418, so the bottom edge moves from y=819 to y=976. It is a
  modal over a blurred lobby, so nothing below it constrains the growth.
- **Delete the seven `DayN` `TextureRect`s**, their `"10G"` and `"Day1…Day7"`
  labels, the `day_nodes` dictionary, and the per-tile tint block in
  `_update_daily_login_visual()`. The art carries all of it. `Juice.stagger_in`
  over `ordered_days` in `_show_daily_reward()` goes with them; the panel's own
  `Juice.pop_in` stays.
- **Header**: the existing `H1Label` retexts from `"Daily Reward"` to
  `"Daily Login"` and moves onto the baked cream plate, top-centre. `H1Label`
  is already on the display face, which satisfies the "head font" requirement.
- **Claim button**: `ButtonClaim` moves to middle-bottom, sized and placed over
  the baked gold pill, on a new **`GhostButton`** variation — transparent
  `StyleBoxEmpty` in every state, display face, `text_primary` ink — so the
  art *is* the button. Added to `DISPLAY_ROSTER`.
- **Reward readout**: a `uang.png` `CoinIcon` and a label reading `loby.gd`'s
  `DAILY_REWARD` (currently 10), beside the claim button, so the player can
  still see what claiming pays.

`_on_claim_pressed()`'s `Juice.pop_in(claimed_node)` currently pops the claimed
tile; with the tiles gone it pops the panel instead.

### Theme rebake

`CutsceneDialogue` (§1) and `GhostButton` are the only two new variations, and
both are built from tokens that already exist — so **no new `DesignTokens`
`@export`, and no editor restart.** One rebake covers both.
`test_baked_theme_matches_what_the_factory_builds` fails until it is run.

---

## 6. RunResult — S rank and the win backdrop

**Files:** `Scripts/EndGame/RunGrade.gd`, `Scripts/EndGame/RunResult.gd`,
`Scenes/EndGame/RunResult.tscn`

### Five ranks

`LETTER_BANDS` collapses from ten `+`/`−` bands to five:

| Rank | Score floor |
|---|---|
| S | 90 |
| A | 75 |
| B | 60 |
| C | 45 |
| D | below, **and always on a failed run** |

`LETTER_FLOOR` becomes `"C"`; `LETTER_FAILED` stays `"D"`. `is_top_grade()`
goes from `begins_with("A")` to S-or-A — it drives the success colour and the
fanfare. `GRADE_CAPTIONS` in `RunResult.gd` goes to five entries.

> These thresholds are estimates, in exactly the sense `MONEY_FULL_MARKS`
> already is. They belong in the project guide's pending-balance-pass entry
> rather than being presented as tuned.

### Badge replaces the letter

Delete the `GradeLetter` `Label` and replace it with a badge `TextureRect` in
`GradeCard/GradeStack`, fed by five `@export`s on `RunResult.gd`
(`rank_badge_s` … `rank_badge_d`) assigned in the Inspector, per the project's
convention for tunable art.

The art already draws both the letter and a "RANK" ribbon, so a text label
beside it would be redundant. The slam-in at `RunResult.gd:183–201` — scale
3→1, fade, shake, conditional fanfare — moves onto the badge node. Lines 89
(`grade_letter.text = ""`) and 185–186 (the `font_color` override, which has no
meaning on a texture) go away.

### Backdrop

This is a wiring bug, not a redesign. `RunResult.gd:27` documents the intent:

> Backdrop when the run passed. The SAME image EndCutscene shows, so this
> screen opens on the frame that one blurred out on.

But `RunResult.tscn` assigns `win_backdrop` and `Backdrop.texture` to
`Assets/Images/CG/cg_win.jpg` (735×865), while `EndCutscene.tscn`'s win branch
uses `Assets/Images/CG/Win/win_background.png` (1536×2048). EndCutscene's win
backdrop was changed and RunResult's was never updated.

Repoint both to `win_background.png`. `expand_mode = 1`, `stretch_mode = 6` and
`blur_lod = 3.0` already match on both sides, so the hand-off becomes seamless
exactly as the docstring claims. The lose path keeps `cg_lose.jpg`, which still
matches EndCutscene's.

### Tests

`tests/test_run_result.gd` and any band assertions in the RunGrade tests need
rewriting to the five-rank model.

---

## Verification

Per the project guide, `test_run` over the full suite is the primary check —
the whole suite returns in a couple of seconds, far cheaper than a single
screenshot. Screenshots are reserved for the genuinely visual claims:

1. **Full suite green.** Rescan after every `.gd` edit; a `script_patch` no-op
   forces a reload where a file was written from outside the editor.
2. **Theme rebake ran**, proven by
   `test_baked_theme_matches_what_the_factory_builds`.
3. **Screenshot: cutscene** — panel inside the screen, text visibly larger,
   hint label clear of the panel.
4. **Screenshot: a full BookClock sweep** — confirms the corner artifact in the
   new sky never enters frame.
5. **Screenshot: lobby** — rebuilt chip, new daily-login panel, both aligned.
6. **Screenshot: RunResult on the win path** — badge lands, and the backdrop is
   indistinguishable from EndCutscene's win frame.

Scene work before script work, and `git diff HEAD -- '*.gd'` after any
`scene_save`, per the project guide's save hazards.

## Out of scope

- `WeekRecapBanner` and `CoinShower` coin art.
- Cleaning the stray corner layer in the sky source — flagged as debt.
- Any change to `Balance.gd`, which is collaborator-owned.
- Tuning the five rank thresholds, which is the pending balance pass.
