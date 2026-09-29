# Minigame text hierarchy, spacing and fixes — design

**Date:** 2026-09-30
**Branch:** `feat/minigame-hierarchy`, stacked on `feat/minigame-mobile-layout`
(PR #155, open, `hold`). This pass needs #155's kit (`MinigameHeader`,
`MinigameTray`, `MinigameHintPill`), which is not on `origin/Textures` yet.
**Status:** approved by the owner in brainstorming, section by section, with
mockups. The PR carries `hold` for the mentor (§9).
**Scope:** the eight minigame scenes and their shared chrome in
`Scenes/Minigames/UI/`. Text, spacing, the header plaque and the bugs found
on the way. The play art (goal, court, dancer, canvas) stays where it is,
except for one nudge to Badminton's court (§5).

---

## 1. Problem

Captured mid-play on 2026-09-30 at 1080×1920, after #155:
`docs/superpowers/mockups/minigame-hierarchy-before.jpg`.

#155 gave every minigame the same skeleton. Five layout problems remain:

1. **The HUD cannot be read at a glance.** The timer is a ring with no
   number. The score pill is translucent grey, and its "/3" target is 22px
   (`ResultBodyLabel`). On busy art (MainBola, LombaMenari) it disappears.
2. **No shared edge margin.** The header sits 48px from the edge, the tray's
   buttons 75, Menjodohkan's cards 115 and Password's question card 160.
3. **The hierarchy is inverted in PilihanGanda.** The question renders at 36px
   regular while the answers are 36px bold display capitals. The answers
   shout and the question whispers.
4. **Wasted space.** PilihanGanda has ~700px of empty wood between question
   and tray. Menjodohkan's SOAL label floats 200px above a 480px card that
   holds one line. Password's question card is 992px wide over a 790px
   calculator.
5. **The header shows two counters that disagree.** MainBola shows "0/4" and
   "TENDANGAN 1/8"; Badminton shows "0-0 /5" and "POIN 0/5".

Bugs found during the audit:

- **B1** `SoalFit` settles PilihanGanda's question on its 36px floor although
  the card has room for 64.
- **B2** The blue outlines. Hand-authored `StyleBoxFlat`s with blue borders
  sit in `PilihanGanda.tscn` (`answer_btn_normal_style`, and the script's
  `add_theme_stylebox_override` calls), `AnswerCard.tscn` and
  `BuatBatik.tscn`. These are the `#3380D9` family Part 1 already flagged.
- **B3** The calculator keys look off-centre (Password and Variabel). Measured
  on `kalkulator_base.png` (1080×1487): the art has **no** painted key wells.
  The keypad face spans x 0.0537–0.9796 (centre 0.5167), but `KeyGrid` spans
  0.1242–0.856 (centre 0.4901), about 29 texture px left. A stray painted key
  outline sits in the art's top-left, at about (0.051, 0.293)–(0.275, 0.468).
  `ZeroRow` ends at 0.9971, past the face's bottom (0.9812), onto the rim.
  `Layar` ends at 0.274, past the LCD glass (0.0963, 0.0935)–(0.9037, 0.2495).
- **B4** BuatBatik's tool cards show no names, although
  `tool0_display_name`…`tool3_display_name` exist (their `##` says "shown on
  the tool slot") and the hint says "Seret Pensil". They reach only the
  tooltip. `tool0_display_name` also says "Specialized Pencil" in English.
- **B5** Badminton's hint pill sits on the court's bottom baseline. The
  court, its lines and its net are all one painted background
  (`lapanganBadminton.jpg`, Keep Aspect Covered), not nodes.
- **B6** Menjodohkan's reel arrows sit 8px from the carousel edge, over
  850px-wide cards, so they cover the card edges. The scene carries no
  overrides. The script's unused `nav_btn_style`, `submit_btn_*_style`,
  `correct_color` and `wrong_color` exports can add them, and
  `submit_btn_active_style`, `correct_color` and `wrong_color` are never read.

## 2. Decisions

| # | Decision | Chosen over |
|---|---|---|
| H1 | **Scope:** the shared chrome plus every text-bearing piece in the games, plus the bugs | chrome only; also re-composing the play art |
| H2 | **Designer intent first:** finish Part 1's locked kit (dark-brown pill with a cream rim and a gold number, Bingkai Kayu card, cream tool cards with a gold ring) rather than invent a look | a new look |
| H3 | **Header:** one row; score and progress merged into one **plaque** | today's two pieces (pill + bar under it) |
| H4 | **PilihanGanda:** the framed question card fills the field, with a **72px** gap to the tray | a compact card just above the answers |
| H5 | **Type ladder ×1.618 for minigames only:** 28 → 45 → 73 → 118 | the house 36/64/96 rungs (see §3) |
| H6 | **A card is as wide as the controls under it and no taller than its content**, except PilihanGanda's full-field card (H4) | fixed-width cards |
| H7 | **Menjodohkan gets more room:** tray gaps 28–44, reel arrows in their own lane beside the cards | 16px gaps, arrows over the card edges |

## 3. Type ladder (minigames only)

Each rung is ×1.618 of the one below, rounded, starting at the house body
floor (`font_body_size` = 28):

| Rung | Size | Face | Roles |
|---|---|---|---|
| T4 | **118** | Boohong / Open Sans | Password's sums, the calculator display (`Layar`) |
| T3 | **73** | Open Sans for questions, Boohong for numbers | question text (fitted, never below T2), Menjodohkan's answer card text, the plaque's score, calculator key labels |
| T2 | **45** | Boohong | answer buttons, tray buttons (Hapus, Kirim, Kunci, Selesai), tool names, timer seconds |
| T1 | **28** | Boohong for labels, Open Sans for the hint | hint line, plaque caption and target ("SOAL 2/3", "/ 3"), SOAL/JAWABAN planks, the Q1 badge |

- **Relation to the 2026-09-21 type-ladder spec.** That spec declined to
  re-space the *house* tokens at ×1.618, because it would change ~40
  screens. This pass does not touch the house tokens. The ladder lives in one
  small static script, `Scripts/Design/MinigameType.gd` (`class_name
  MinigameType`): `T1 := 28`, `T2 := 45`, `T3 := 73`, `T4 := 118` and
  `LADDER := [T1, T2, T3, T4]`, with a `##` saying each is ×1.618 of the last.
  `ThemeFactory`'s minigame variations and the games' fit exports both read
  it, so the numbers are written once. It supersedes the minigames' 36/64/96
  rungs from that spec.
- **Fitting.** Question maxima: PilihanGanda, Variabel and Menjodohkan's
  tiles T3 (73); Password T4 (118), since its sums are short. Every minimum is
  T2 (45), replacing today's 36 and 28. This retunes `question_font_size` /
  `min_question_font_size`, `problem_font_size` / `min_problem_font_size`,
  `equation_font_size` / `min_equation_font_size` and Menjodohkan's
  `TILE_TEXT_MAX` / `TILE_TEXT_MIN` to read the ladder, not literals.
- **Buttons.** The tray buttons wear house variations today
  (`SecondaryButtonM`, `LobbyCtaButton`, `PrimaryButton`, `SuccessButton`).
  Changing those would resize every non-minigame screen, so the minigames get
  their own lipped variations at T2, built with `_add_button_variation`:
  `MinigameCtaButton` (mint, the one main action) and
  `MinigameSecondaryButton` (brown). Role colours are unchanged.

## 4. Spacing

All values are in 1080-wide game pixels, inside `SafeAreaMargin → UI`.

| Where | Gap |
|---|---|
| Screen edge to any element (header, cards, tray contents, arrows) | **48** (`screen_margin`) |
| Header to first content | 28 (`space_md`) |
| Field content to tray top | **72** (`space_xl`) |
| Card to the controls under it (e.g. question card to calculator) | 44 |
| Tray: top edge to first item | 28 (Menjodohkan: 44) |
| Tray: between stacked buttons | 16 (`space_sm`) |
| Tray: buttons to hint | 16 (Menjodohkan: 28) |
| Hint to the screen's bottom | unchanged: the safe margin (48) plus the tray's bottom padding (24) |
| Text to its card's inner edge | 28 |

**48, not 44 (owner-approved 2026-09-30, after brainstorming).** Every
minigame already sits in a `SafeAreaMargin`, which applies the house
`screen_margin` (48) on every screen in the game. The edge rule therefore
uses 48, and the tray stops adding its own 28px side padding on top of it
(`MinigameTray.PADDING` goes from `(28, 28, 28, 24)` to `(0, 28, 0, 24)`).
Its plank still bleeds to the screen edges through `expand_margin`.

The values are the house `space_*` tokens. Where a scene needs them as
container constants, they are layout-only `separation` / `margin_*`, the one
accepted override (CLAUDE.md). Anything responsive is a documented `@export`
on the owning `@tool` script.

## 5. Components

### 5.1 The plaque (header, H3)

```
[pause 96]   ┌──────────────────────────────┐   [timer 96]
             │ (icon)  1  / 3               │   ring + "18"
             │ ▰▰▱▱▱▱▱▱▱▱        SOAL 2/3   │
             └──────────────────────────────┘
```

- **One row:** `PauseButton` · plaque · `TimerSlot`, each 48 from the edge.
  `MinigameHeader`'s `Stack/ProgressRow` moves into the plaque; `Stack`
  becomes the single `Row`. This frees ~50px for the field.
- **The plaque is `MinigameScoreHUD`, extended rather than forked:**
  - `Panel` wears `MinigameHudPill` (brand-dark fill, cream rim), which
    retires `ScoreHudPanel` here and closes DEBT's "Score HUD restyle
    deferred";
  - top line: `Icon` (category colour on dark), `ValueLabel` on
    `MinigameHudValue`, raised to T3 73 gold, and `TargetLabel` on a T1
    cream display variation;
  - bottom line: the segmented `ProgressBar` plus a T1 caption. With 10 or
    fewer steps the bar draws segments; above 10 it draws one continuous
    fill;
  - `ComboChip` stays at the plaque's right end, where Part 2's ×combo badge
    lands.
- **API.** `MinigameHeader.set_progress(value, max_value, label)` keeps its
  signature and forwards to the plaque. `show_score = false` hides the top
  line and keeps the bar (BuatBatik).
- **Timer.** Keep the draining `Ring`. `TimerGlyph` gives way to a
  `TimerLabel` (T2 45 cream display, new `MinigameTimerLabel`) showing whole
  seconds left. It turns `state_danger` for the last 5 s, as now. It stays
  display-only and hidden in Badminton and LombaMenari, and a hidden slot
  keeps its width. `MinigameHeader`'s `timer_icon` export and its `timer.svg`
  reference go; drop `timer.svg` from DEBT's placeholders if nothing else
  loads it.

**Per game:**

| Game | Gold number / target | Bar : caption |
|---|---|---|
| PilihanGanda, Password, Variabel | correct / questions ("1 / 3") | per question : `SOAL 2/3` |
| Menjodohkan | correct pairs ("0 / 4") | locked pairs : `PASANGAN 0/4` |
| BuatBatik | *(hidden)* | 4 steps : `LANGKAH 1/4` |
| MainBola | goals ("0 / 4") | kicks used : `TENDANGAN 1/8` |
| Badminton | rally score ("0 – 0", no target) | your points : `CAPAI 5 POIN` |
| LombaMenari | score ("0 / 1500") | lives : `NYAWA 10/10` |

### 5.2 Cards

- **Question cards** move from `QuestionCard.tscn`'s hand-made
  `StyleBoxFlat_4km62` to Part 1's **Bingkai Kayu** pair: `MinigameCard`
  (the frame) and `MinigameCardInner` (the cream face). The `StatusBadge`
  (`StyleBoxFlat_sp8rl`) moves to a variation too.
- **Menjodohkan's `AnswerCard`** drops `StyleBoxFlat_kthfr` (blue rim) for a
  new `MinigameAnswerCard`: `surface_card` with a `button_cream_lip` rim.
  The dark `StyleBoxFlat_lock` overlays in both cards become one variation,
  `MinigameCardLock`.
- **Sizing (H6).** Password and Variabel share one 860px column for the card
  and the calculator; the card is as tall as its text plus 28. Menjodohkan's
  cards are 736 wide, between the arrow lanes. PilihanGanda's card fills the
  field (H4) at 992 wide, like its answers, and keeps its picture slot inside.

### 5.3 Buttons and tools

- **PilihanGanda's answers** wear `MinigameChoiceButton` (cream,
  `button_cream_lip`) at T2. The right and wrong flashes become two variations,
  `MinigameChoiceButtonCorrect` (`state_success`) and
  `MinigameChoiceButtonWrong` (`state_danger`), swapped by
  `theme_type_variation`. The `answer_btn_*_style` exports and every
  `add_theme_stylebox_override` in `PilihanGanda.gd` go.
- **BuatBatik's tool cards** follow Part 1's intent with two **new**
  variations (Part 1 named them but never built them): `MinigameToolCard`
  (cream, lipped) and `MinigameToolCardSelected` (the same plus a
  `currency_gold` 8px ring on the next tool to use). Each card shows its `toolN_display_name` in
  a new `MinigameToolNameLabel` (T2, `text_primary`) under the icon (**B4**).
  The blue `StyleBoxFlat_6wcp2` goes (**B2**).
- **Menjodohkan's arrows** wear a **new** `WoodNavArrow` variation (named in
  Part 1, never built: a brown lipped square, `radius_md`), sit in the 48px edge
  lanes with 28 clear of the card. The cards are 736 wide
  (1080 − 2 × (48 + 96 + 28)). The dead style exports (`nav_btn_style`,
  `submit_btn_active_style`, `submit_btn_disabled_style`, `correct_color`,
  `wrong_color`) go, and so do the override branches that read them (**B6**).
  Kunci and Selesai take `MinigameSecondaryButton` and `MinigameCtaButton`.
- **Planks.** SOAL and JAWABAN wear `MinigamePlankPanel` +
  `MinigamePlankLabel` (gold), raised to T1 28. The `MinigameWheelHeader*`
  variations retire if nothing else reads them.

### 5.4 Calculator (Password, Variabel)

- The calculator is 860 wide in the shared column, 44 below its card and 72
  above the tray.
- `Layar` at T4 118. Key labels at T3 73. `KalkulatorKey.tscn`'s
  `theme_override_colors/font_color` moves into a variation.
- **B3:** re-anchor to the measured art. `KeyGrid` and `ZeroRow` are centred
  on the face's centre (x 0.5167) and kept inside the face (x 0.0537–0.9796,
  y 0.2751–0.9812). The grid starts far enough left (x ≤ 0.085) that key 1
  covers most of the stray outline. `Layar` fits the LCD glass
  (0.0963, 0.0935)–(0.9037, 0.2495). The measured fractions go in
  `Kalkulator.gd` as documented `const`s, which the scene's anchors and the
  test both use. The remaining sliver of the stray outline is the artist's:
  log it in DEBT, and do not paint over it.
- Variabel (`show_zero_key = false`): the three rows take the zero row's
  height instead of leaving it empty.

### 5.5 Hint

`MinigameHintLabel` drops from 36 to T1 28, the quietest line on screen. The
tray's hint and the pill's hint share it. The settle-to-60% behaviour is
unchanged.

## 6. Per-game layout

| Game | Field | Tray / bottom |
|---|---|---|
| **PilihanGanda** | Bingkai Kayu card from header+28 to tray−72, 48 margins, question T3 centred, picture slot inside | 4 cream answers (130 tall, 16 apart), hint |
| **Password** | 860 column: card hugging the sum (T4), 44, calculator | Hapus (brown) · Kirim (mint), hint |
| **Variabel** | as Password; question fits T3→T2 (three lines at 45) | as Password |
| **Menjodohkan** | SOAL plank; 736-wide framed card with peeking neighbours; arrows in the edge lanes | tray gaps 44/28/44/28: JAWABAN plank, answer card (320), Kunci · Selesai, hint |
| **BuatBatik** | canvas, 48 margins | 4 tool cards with names, gold ring on the next tool, hint |
| **MainBola** | unchanged art | hint pill |
| **Badminton** | the court background shifts up (`offset_top` = `offset_bottom` = −N, so its cover scale is unchanged) until the painted baseline sits ≥ 16 above the hint pill; a `Surround` `ColorRect` in the art's edge colour fills the strip it uncovers (**B5**). N comes from the baseline's measured row in the texture | hint pill |
| **LombaMenari** | unchanged art | hint pill |

Thumb reach from #155 still holds: every tappable control is below 0.55 of
the frame height, except pause and Menjodohkan's SOAL arrows, which #155
already recorded.

## 7. Rules honoured

- **No `theme_override_*`** beyond layout-only constants. This pass *removes*
  overrides: `PilihanGanda`, `AnswerCard`, `QuestionCard`, `BuatBatik`,
  `Menjodohkan`, `KalkulatorKey`. The minigame count in DEBT's override tally
  goes down.
- **No runtime visuals.** Tool names and the timer label are nodes in the
  `.tscn`. Plaque segments are drawn by the existing `@tool` `Ticks` control.
  No `.new()` added; `test_viewport_editability` baselines only go down.
- **Documentation.** `##` on every new file, `@export` and const block.
- **Fonts.** New display variations join `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd`; rebake.
- **Tall phones.** Everything stays under `SafeAreaMargin → UI`. The extra
  480px at 1080×2400 goes to the field (PilihanGanda's card grows,
  Menjodohkan's SOAL card grows, the calculator centres in its slot).
- **Indonesian, KBBI.** New copy: `CAPAI 5 POIN`.
- **`Balance.gd`** is untouched.

## 8. Testing

**New suite `tests/test_minigame_hierarchy.gd`** (`@tool`, no coroutines;
scenes stood up once in `suite_setup`, with `kejartes_theme.tres` assigned to
each root: under the editor root a Control otherwise inherits the editor's
theme and measures nothing):

- **Ladder:** `MINIGAME_TYPE_LADDER == [28, 45, 73, 118]`, each ratio within
  1.60–1.64. Each role in §3 is read back from the baked theme.
- **Fitter (behaviour, B1):** PilihanGanda's sample question on the real card
  returns 73. Variabel's three-line question returns ≥ 45. No fit call passes
  a minimum below 45.
- **Spacing:** at 1080×1920 and 1080×2400, cards and tray contents sit 48
  from the edges; field content ends 72 above the tray. Password's card and
  calculator share left and right edges.
- **Plaque:** the header is one row; `ProgressBar` lives under
  `MinigameScoreHUD`; `set_time(18, 30)` shows "18"; `show_score = false`
  hides only the top line.
- **Bugs:** no `border_color` blue and no `theme_override_styles` in
  PilihanGanda, `AnswerCard`, `QuestionCard` or BuatBatik; no
  `add_theme_stylebox_override` in `PilihanGanda.gd` (B2). BuatBatik shows 4
  tool names (B4). The calculator's key block is centred on the measured face
  within 0.01, stays inside the face, and `Layar` stays inside the glass (B3).
  Badminton's painted baseline, computed from the cover geometry at
  1080×1920 and 1080×2400, is ≥ 16 above the pill's top (B5). Menjodohkan's
  arrows do not intersect the card rects (B6).

**Suites that change** (paths and values updated, asserted properties kept):
`test_minigame_header`, `test_minigame_score_hud`,
`test_minigame_typography`, `test_minigame_layout`,
`test_minigame_layout_kit`, `test_kalkulator`, `test_button_roles_phase3`,
`test_theme_factory` (`DISPLAY_ROSTER`), `test_light_ground_text` (gold on
brand-dark, cream T1 on the plaque and the tray), `test_viewport_editability`
(down only).

**Live check.** Recapture all eight mid-play at 1080×1920 and 1080×2400 with
the debug launcher (the method behind the before-sheet), and send the owner a
full-size before/after sheet. A full `test_run` is green before the PR.

## 9. Gates and coordination

- **Stacked on #155.** This branch is cut from `feat/minigame-mobile-layout`.
  Open its PR against that branch, or against `Textures` once #155 merges.
  Never merge it first.
- **Mentor.** The plaque (H3) and the ×1.618 ladder (H5) are new visual
  decisions, so the PR carries `hold`. The cream answers and the Bingkai Kayu
  card are already under #155's mentor gate.
- **Part 2's author.** The ×combo badge still belongs in the plaque's
  `ComboChip`. Tray buttons are now `MinigameCtaButton` /
  `MinigameSecondaryButton`, which is relevant to Phase 8's key feel.
- **DEBT.** Close "Score HUD restyle deferred"; update the minigame override
  count; drop `timer.svg` from the placeholders if it is unused; the
  Badminton duplicate-score glance is resolved by `CAPAI 5 POIN`.

## 10. Build order

Scene work before script work within each step; restart the editor after
script patches and before the next `scene_save` (CLAUDE.md 4b). Verify in a
second editor opened on this worktree: the bridge's usual editor is the main
checkout's, which is on another session's branch.

1. **Theme:** `MINIGAME_TYPE_LADDER`, the new and retuned variations, rebake.
2. **Plaque and header:** extend `MinigameScoreHUD`, flatten
   `MinigameHeader` to one row, add `TimerLabel`.
3. **Cards:** `QuestionCard`, `AnswerCard`, the lock overlay.
4. **PilihanGanda** (B1, B2).
5. **Password and Variabel:** calculator measurement and re-anchor (B3).
6. **Menjodohkan** (B6, H7).
7. **BuatBatik** (B2, B4).
8. **Sports games:** hint size, plaque content, Badminton court (B5).
9. **Tests, the live before/after sheet, DEBT and CHANGELOG.**

## 11. Out of scope

- Re-composing the play art (goal, court, dancer, canvas), beyond B5.
- The house type tokens and every non-minigame screen.
- Overlays (how-to card, JEDA, KELUAR?), the win screen and the result
  popup.
- Part 2's depth kit (combo meter, grades, odometer) and Part 1's motion
  vocabulary.
- The category ribbon from Part 1's locked table: the plaque's category-
  coloured icon carries that signal for now.
