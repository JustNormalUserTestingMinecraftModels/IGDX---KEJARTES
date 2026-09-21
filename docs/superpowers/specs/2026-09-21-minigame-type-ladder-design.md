# Minigame type ladder and the shared QuestionCard — design

2026-09-21. Branch `feat/minigame-type-ladder`.

Grew out of a `/design-audit-ui` pass over Menjodohkan, the Shop, Variabel,
Password, PilihanGanda, BuatBatik, Badminton and Achievements. Shop and
Achievements came back clean — both already run `ThemeFactory` variations
(`ShopHubTileLabel` = `font_h2`, `AchievementTitleLabel` 44 /
`AchievementDescLabel` 29) and are out of scope here. The six minigames are
the subject.

## The problem

The six minigame scenes carry **25 hard-coded text sizes** between them: 14,
16, 18, 26, 30, 32, 36, 40, 44, 48, 60, 70, 80, 90. Only 18, 28, 36, 48 and 96
are token rungs; the rest were invented at the call site, either as a
`theme_override_font_sizes/font_size` in the `.tscn` or an
`add_theme_font_size_override` in the script. CLAUDE.md puts minigames outside
the design system, which is how they drifted this far.

Three consequences, in severity order.

1. **Two labels ship below the project's body floor.** `BuatBatik.gd:516` and
   `:557` draw the batik step name and the wrong-order warning at **16px**, 57%
   of `font_body_size` (28), centred across a full-screen `ColorRect`.
2. **No ladder.** Nothing relates one size to the next, so the same role
   (a question, a choice, a counter) is a different size on each screen.
3. **Two labels cannot reach body contrast on any ground.**
   `Menjodohkan.tscn:80` `Color(0.85, 0.45, 0.1)` and `:181`
   `Color(0.2, 0.5, 0.85)` have relative luminances 0.27 and 0.21 — mid-tone,
   unoutlined, over painted card art. Against pure white they cap at 3.3:1 and
   4.0:1, under the 4.5:1 body floor; on the card they actually sit on they
   fall toward 1.5:1. The same orange is `QuestionCard.tscn`'s border and badge
   fill.

## Decision: φ is already in the tokens — do not re-space them

The house ladder in `DesignTokens.gd` is 18 / 22 / 28 / 36 / 48 / 64 / 96 —
ratios 1.22 to 1.33, a major third. Re-spacing it at ×1.618 would give
28 / 45 / 73 / 118, change all ~40 screens on rebake, and overflow Boohong's
tracking at the top of a 1080px canvas.

It is not needed. The top three rungs already are the ladder:

| Rung | Token | Role |
|---|---|---|
| 96 | `font_display_size` | score |
| 64 | `font_h1` | question |
| 36 | `font_title` | choices, meta, overlay |

36 → 64 is 1.78, 64 → 96 is 1.50; the geometric mean is **1.63**, φ within
rounding, and `MinigameScoreHUD` already uses `font_h1` for its value.
So the change is subtractive: **every minigame uses 36, 64 and 96 and nothing
else.** 28 (`font_body_size`) stays the floor, reserved for dense rows. That
retires 20 of the 25 invented sizes.

## Decision: PilihanGanda adopts the shared QuestionCard

The user's ask was to enlarge PilihanGanda's question box so a picture fits.
The picture already exists and the card already exists:

- `PilihanGanda.tscn` has a `QuestionImage` TextureRect at
  `custom_minimum_size = Vector2(0, 420)`, `visible = false`, which
  `PilihanGanda.gd:251–267` toggles per question from the `"image"` key.
- `Scenes/Minigames/Akademis/QuestionCard.tscn` is a shared `PanelContainer`
  with a hidden `RowImage` slot (116px), a `TextLabel`, and a `StatusBadge`.
  **Password, Variabel and Menjodohkan all instance it.** It has no script;
  each user drives it through `find_child`.

So PilihanGanda does not get a bespoke card. It instances `QuestionCard`, and
the card's `RowImage` slot grows to hold real art. Fixing the card's
typography once fixes four screens.

Two defects the current PilihanGanda layout has, both cured by the move:

- `QuestionImage` sits **above** `ProgressLabel`, which sits above
  `QuestionLabel`. A question reading "Dari gambar di atas…" points at a
  picture with the score counter wedged between it and the words.
- The `VBoxContainer` has `alignment = 1` (centre) and the script toggles the
  image's `visible`, so the whole stack re-centres between questions and the
  choice buttons move under the player's thumb mid-game.

Inside the card the counter becomes the `StatusBadge` — which is what
`SoalFit` was built around ("keeps a badge-height strip clear at the top and
bottom, so vertically centred text never runs under the card's 'Soal N/M'
badge").

### Sizing the image slot

`monas.png` is **1080×1920** (aspect 0.562) and `borobudur.png` is
**1920×1920** (1.0). The question art is portrait and square, not landscape —
a wide short slot would letterbox it to a narrow column. With
`stretch_mode = 5` (KEEP_ASPECT_CENTERED) in a 924×620 slot:

| Asset | Rendered |
|---|---|
| `monas.png` | 349 × 620 |
| `borobudur.png` | 620 × 620 |

Both centred, neither distorted, and a future cropped landscape asset fills
the slot better rather than worse.

### Vertical budget

`PilihanGanda.tscn`'s `VBoxContainer` spans anchors 0.08 → 0.95 of 1920 =
**1670px**, at x 0.05 → 0.95 = 972px wide. There is no Jawab button —
`ChoicesGrid` is the last child and a choice tap commits.

| Band | px |
|---|---|
| `ScoreHUD` | 110 |
| separation | 16 |
| `SoalCard` | 960 |
| separation | 16 |
| 4 choices @ 130 + 3 gaps @ 12 | 556 |
| **total** | **1658** |

The question text runs through `SoalFit.font_size(label, badge, text, 64, 36)`,
the same call Password and Variabel already make, so a long question steps
down the ladder instead of clipping.

**Corrected after seeing it on device (2026-09-21).** The first build reserved
the full 960 on every question so the choice buttons could not move. That kept
the layout still, but about 10 of the 11 fallback questions have no picture,
and on those the card was a 960px empty field around a single line of text —
optimising for the rare case at the expense of the common one.

What shipped instead: the card **sizes to its content** (~250 text-only, ~960
with a picture), and an authored `Spacer` Control between it and `ChoicesGrid`
absorbs the difference. The choices sit at the bottom in both cases, verified
by screenshot across a picture question and a text-only one. `VBoxContainer`
takes `alignment = 0` (BEGIN) and `SoalCard` `size_flags_vertical = 0`, so the
card hangs from the top and the Spacer, not the card, carries the slack —
including the extra 480px on a 1080×2400 phone.

## Decision: choice rows 100 → 130

`PilihanGanda.gd:107` sets `answer_btn_min_height = 100`, under the ~130px
(48dp) touch floor in the 1080-wide design space. It goes to 130. This is the
number the vertical budget above is built on.

## The variations

Seven new `ThemeFactory` type variations, all Label or Button, all on the three
rungs. This brings the minigames inside the design system, which is the
direction CLAUDE.md's rule points even though it currently exempts them.

| Variation | Base | Size | Ink | For |
|---|---|---|---|---|
| `MinigameQuestionLabel` | Label | 64 | `text_primary` | `QuestionCard`'s `TextLabel` |
| `MinigameChoiceButton` | Button | 36 | `text_primary` | PilihanGanda's answer buttons |
| `MinigameMetaLabel` | Label | 36 | `text_secondary` | counters on a card |
| `MinigameBadgeLabel` | Label | 36 | `text_on_brand` | `QuestionCard`'s `StatusBadge` |
| `MinigameOverlayLabel` | Label | 36 | `text_on_brand` + 8px black outline | text over art |
| `MinigameWheelHeaderWarm` | Label | 36 | `brand_primary` | Menjodohkan's question wheel |
| `MinigameWheelHeaderCool` | Label | 36 | `cat_akademis` | Menjodohkan's answer wheel |

The question label takes the body face (Open Sans) — a quiz question is body
copy, not a heading. Buttons, badges and the wheel headers take Boohong per
the house rule.

### Contrast, measured

The two Menjodohkan headers keep a warm/cool distinction but move to inks that
clear the floor on the cream card they sit on (`surface_card` #FFFDF8):

| Ink | Hex | Luminance | On #FFFDF8 |
|---|---|---|---|
| `brand_primary` | `7A4A2B` | 0.091 | **7.2:1** |
| `cat_akademis` | `1F6FBA` | 0.151 | **5.1:1** |

Both pass the 4.5:1 body floor. The old orange and blue could not, on any
ground.

`QuestionCard`'s `Color(0.85, 0.45, 0.1)` border and badge fill move to
`brand_primary` for the same reason; the badge's own text is cream on that
fill.

## Decision: the 🔒 stays out

`QuestionCard.tscn`'s `LockOverlay/LockIcon` is a **🔒 emoji** at 64px.
CLAUDE.md bans emoji as UI iconography outright, and
`Assets/Images/UI/Placeholders/icon_lock.svg` already exists (it is
`AchievementTile`'s lock). The Label becomes a `TextureRect` pointing at it.

`BuatBatik.gd:557`'s `"⚠ Urutan Salah!"` loses its glyph for the same reason —
DEBT.md records that neither Boohong nor Open Sans carries these characters, so
they ride whatever system font the device picks. It becomes `"Urutan Salah!"`.

## Files

| File | Change |
|---|---|
| `Scripts/Design/ThemeFactory.gd` | seven new variations; rebake |
| `Assets/Theme/kejartes_theme.tres` | rebaked output |
| `Scenes/Minigames/Akademis/QuestionCard.tscn` | `Card` variation, variations on label/badge, `brand_primary` border, `RowImage` slot 116 → 620, lock icon |
| `Scenes/Minigames/Akademis/PilihanGanda.tscn` | instance `QuestionCard`; drop the loose image/progress/question trio; drop the 14/18 overrides |
| `Scripts/Minigames/Akademis/PilihanGanda.gd` | drive the card; `SoalFit` for the question; `answer_btn_min_height` 130; choice buttons take the variation; drop both font-size overrides |
| `Scripts/Minigames/Akademis/Menjodohkan.gd` | the two duplicated 90/80/70/60 chains at `:422`/`:472` → `SoalFit.font_size(..., 96, 36)` |
| `Scenes/Minigames/Akademis/Menjodohkan.tscn` | the two wheel headers take the new variations; drop four colour/size overrides |
| `Scripts/Minigames/SeniBudaya/BuatBatik.gd` | `:516`/`:557` 16px → `MinigameOverlayLabel`; drop the glyph |
| `Scenes/Minigames/Olahraga/Badminton.tscn` | `ScoreHUD` anchored top-centre instead of offset (390, 40) |
| `Scripts/Minigames/Akademis/SoalFit.gd` | docstring: it now serves four screens, not two |
| `tests/test_minigame_typography.gd` | new suite |

## State

No `GameState` or `StudentData` field is read or written by this pass — it is
presentation only. The `approved_students` ↔ `StudentData` bridge is not
touched. PilihanGanda's own `q_data` Dictionary keeps its existing keys
(`question`, `choices`, `correct_index`, `image`); the scoring path
(`MinigameScoreHUD`, the star rubric, `pending_earnings`) is unchanged.

## Kelas 7 / 8 / 9

No difference. Minigame presentation does not vary by grade — the grade scales
the win/loss stat deltas (10/−3, 8/−4, 6/−5) inside the result path, which
this pass does not touch.

## Testing

New suite `tests/test_minigame_typography.gd`, `@tool`, no coroutines,
`suite_name()` returns `"minigame_typography"`. Source-text scans in the
established house style, since these scenes cannot be instantiated headlessly:

1. No `theme_override_font_sizes/font_size` remains in the six minigame
   `.tscn` files.
2. No `add_theme_font_size_override` with an integer literal remains in the six
   minigame scripts; the only sizes reaching a label come from `SoalFit` or a
   variation.
3. Every one of the seven variations exists in the baked theme at its stated
   size and ink.
4. `QuestionCard.tscn`'s `RowImage` slot is 620 and its border is
   `brand_primary`, not the old orange.
5. `PilihanGanda.tscn` instances `QuestionCard` and no longer declares its own
   `QuestionImage` / `ProgressLabel` / `QuestionLabel`.
6. `PilihanGanda.gd`'s `answer_btn_min_height` is at least 130.
7. Neither `QuestionCard.tscn` nor `BuatBatik.gd` contains an emoji or a
   `⚠`/`←`-class glyph.

Existing suites that must stay green: `viewport_editability` (the runtime
construction ratchet — this pass only lowers counts, never raises; lower
`BASELINE` in the same commit if one drops), `minigame_art`,
`minigame_card_shadows`, `minigame_score_hud`, `kalkulator`, `theme_factory`,
`script_documentation`, `tall_screen_layout`, `achievements`.

## Not doing

- **Achievements 44 → 47.** A 3px change for φ purity on a screen the audit
  found correct, against a green suite, with no legibility gain.
- **Password and Variabel beyond the shared card.** Their own debt is a
  `separation` constant override, which CLAUDE.md explicitly permits.
- **Re-spacing `DesignTokens.gd` at ×1.618.** Rejected above; it is a
  whole-game change for a problem the top three rungs already solve.
- **Replacing `monas.png` / `borobudur.png` with cropped art.** An asset
  change; the slot is sized to work with what exists.
- **Converting the remaining runtime-built minigame UI.** BuatBatik's 7 and
  Badminton's 8 `.new()` sites stay on the `viewport_editability` ratchet as
  existing debt.
