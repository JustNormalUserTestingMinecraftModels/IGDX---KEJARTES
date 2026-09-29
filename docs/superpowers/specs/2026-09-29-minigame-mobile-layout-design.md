# Minigame mobile layout — design

**Date:** 2026-09-29
**Branch:** `feat/minigame-mobile-layout`, cut from `feat/minigame-polish-part-1`
**Status:** Approved by the owner in brainstorming. Three points need mentor
sign-off before they are built (§9).
**Scope:** the eight minigame scenes (PilihanGanda, Menjodohkan, Password,
Variabel, BuatBatik, LombaMenari, MainBola, Badminton), their shared chrome in
`Scenes/Minigames/UI/`, and `BaseMinigame.gd`.

This spec is the **screen skeleton** that
[Part 1](2026-09-28-minigame-polish-part-1-design.md) and
[Part 2](2026-09-28-minigame-polish-part-2-design.md) both assume but never
define. It folds into Part 1: it mounts Part 1's built `MinigameHeader`, it is
Part 1 Phase 2's Tutorial design, and it leaves Part 2 one slot for its combo.

---

## 1. Problem

The minigames are uncomfortable on a phone, and each lays out differently.

- **The score HUD sits somewhere else in every game.** It sits at y 154 in
  PilihanGanda, below the pause row, and at y 28–168 in Password/Variabel,
  inside that row. LombaMenari and MainBola centre it at x 390, with its top
  cut off. Badminton centres it at y 40, also clipped. Menjodohkan puts it
  near y 220, under a title. BuatBatik has none.
- **Instructions have no home.**
  - BuatBatik's title and instruction sit over the pause button and the timer.
  - Menjodohkan labels its carousels "(GESER / SWIPE)".
  - MainBola says "Shots Left: 8" and "↑ Swipe Up to Shoot", in English and
    at 26px.
  - The other five games say nothing during play.
- **The how-to popup is a placeholder.**
  - `MinigameTutorial.gd` builds 12 nodes in code: a dark box of paragraphs
    under an emoji title, with a blinking "Ketuk untuk melanjutkan".
  - Password overrides its text with "lorem ipsum".
  - Turning tutorials off also skips the 3‑2‑1 countdown, because
    `BaseMinigame.activate_minigame()` only awaits `_play_countdown()` inside
    the tutorial branch.
- **No minigame respects the notch.**
  - `BaseMinigame` builds the pause button (32,28)–(172,168) and the
    `VisualTimer` (908,28)–(1048,168) in code, on a CanvasLayer with no safe
    area.
  - No minigame scene contains a `SafeAreaMargin`.
- **Controls are sometimes out of thumb reach.**
  - Menjodohkan's question carousel sits in the top half.
  - Its action bar overlaps the answer carousel.
  - `AnswerCard`'s 960px minimum overflows a ~538px slot.
- **Emoji are live in UI text:**
  - Menjodohkan's 🔒 and 🔓 button text, and its 🔒 ✅ ❌ badges;
  - BuatBatik's ⬜ ✅ ❌ 🟨 step string and its 🔧 tooltip prefix;
  - the tutorial titles (🎓 ⚽ 🏸 …).

  These slip through because `tests/test_ui_text_glyphs.gd` skips
  `Scenes/Minigames` and `Scripts/Minigames`.

## 2. References and the decisions taken

The owner supplied three famous mobile games as references. They share one
structure, and this spec adopts it:

```
┌─────────────────────────────┐
│ [pause] [progress]  [timer] │  top strip: small chips, identical everywhere
│         PLAY FIELD          │  full-bleed; nothing parks on it
│  [ctrl] [ctrl] [ctrl]       │  bottom: every control, in thumb reach
│      one-line hint          │
└─────────────────────────────┘
```

| # | Decision | Chosen over |
|---|---|---|
| D1 | **Instructions:** a short how-to card before play (2–3 illustrated steps and a **Mulai** button), plus a one-line hint during play | hint line only; a pointing hand; the card only |
| D2 | **Scope:** fold into Part 1 by building on its `MinigameHeader` | a separate pass on Textures; spec only |
| D3 | **Tray:** a solid wood tray only in the button games; the sports games stay full-screen with a floating hint | a tray on every screen |
| D4 | **Progress:** one bar under the score, in every game, with a short label | progress inside each game's content |
| D5 | **Approach:** four shared pieces, each placed by the scene under one written band rule | one `MinigameFrame` that every game plugs into |
| D6 | **The design rules apply to the minigame chrome** (§5) | leaving the minigames outside the design system |

## 3. The shared pieces

```
SafeAreaMargin → UI
├─ MinigameHeader          (Part 1, built; mounted here)
│   ├─ Row: PauseButton · Center/ScoreHud · TimerButton
│   └─ ProgressRow: ProgressBar + ProgressLabel      ← new
├─ <play field nodes>      (per game)
└─ MinigameTray            (button games)            ← new
   ├─ Controls  (slot the host fills)
   └─ HintLabel
   or MinigameHintPill     (sports games)            ← new
```

### 3.1 `MinigameHeader` (extend Part 1's scene)

- Keep Part 1's `Row`: `PauseButton` (96×96, `MinigameHudIconButton`),
  `Center/ScoreHud` (the unchanged `MinigameScoreHUD` instance) and
  `TimerButton` (96×96).
- **Add `ProgressRow`** under `Row`. It holds a `ProgressBar` (new
  `MinigameProgressBar` variation) with a `ProgressLabel` on top
  (`BarLabel`-style, new `MinigameProgressLabel`).
  - API: `set_progress(value: int, max_value: int, label: String)`.
  - `@export var segmented := false` draws the bar as `max_value` segments
    (BuatBatik's 5 steps), which covers Part 1's "5-step progress dots".
- **Root `@export`s** (overrides only serialise on an instanced scene's root):
  `show_score`, `show_timer` and `show_progress`. A hidden slot keeps its
  width, so the pill stays centred.
- **Timer:** a ring that drains. `set_time(left: float, total: float)`. It
  turns `state_danger` for the last 5 s. It stays display-only, as Part 1
  decided (no signal, ignores taps).
- **Pause icon and timer icon** are SVGs from `Assets/Images/UI/Icons/`
  (`pause.svg`, `timer.svg`; placeholders until the owner's set lands),
  drawn as a child `TextureRect` with `ButtonGlyph.gd`.

### 3.2 `MinigameTray` (new)

- It is a `PanelContainer` with the new `MinigameTrayPanel` variation: a
  brown wood plank with a darker top lip and square bottom corners. It is
  anchored bottom-wide inside `SafeAreaMargin → UI`.
- **Children:**
  - `Controls`, a `VBoxContainer` that the host scene fills (adding children
    under an instance's child is saved by the host);
  - `HintLabel`, using the new `MinigameHintLabel` variation: Open Sans 36,
    cream on the plank.
- **Root `@export`s:** `hint_text` and `controls_separation`.
- **Height:** the tray is as tall as its contents. A `Spacer` in the host's
  field takes up the slack, so on a 1080×2400 phone the extra 480px goes to
  the field, never to the tray.

### 3.3 `MinigameHintPill` (new)

- It is a `PanelContainer` with the new `MinigameHintPillPanel` variation: a
  translucent dark pill. It is anchored bottom-centre, at the same distance
  from the bottom safe edge as the tray's `HintLabel`.
- **Children:** an optional `Icon` `TextureRect` (MainBola's swipe-up) and a
  `HintLabel`.
- **Root `@export`s:** `hint_text` and `icon_texture`.
- It ignores taps (`mouse_filter = 2`), so gestures pass through to the field.

### 3.4 How-to card (`MinigameTutorial.tscn`, redesigned in place)

- **Frame:** a **NotebookFrame dialog**:
  - host recipe `SafeAreaMargin → CenterContainer → Frame`;
  - `ring_count = 4`, `show_well = false`, `show_close = false` (a forced
    flow, like `TutorialPanel`);
  - sticker `title_text = "CARA MAIN"`.
- **Content, top to bottom:**
  - the game's name: an `H2Label`-size heading in the host content, because
    the sticker carries only the fixed word;
  - 2–3 `HowToStepRow` rows, each a 96px icon `TextureRect` and one line of
    Open Sans 36;
  - a mint **Mulai** button.
- **`HowToStepRow.tscn`:** a template. Root `@export`s `icon_texture` and
  `step_text`.
- **Content comes from data, not code.** A new `MinigameHowTo` Resource
  (`class_name`) holds `title: String` and
  `steps: Array[MinigameHowToStep]` (`icon: Texture2D`, `text: String`).
  - Each game has one `.tres` in `Resources/Minigames/HowTo/`.
  - `BaseMinigame` gains `@export var how_to: MinigameHowTo`.
  - This retires `_get_active_tutorial_title()`,
    `_get_active_tutorial_instructions()`, their emoji fallback table, the
    `tutorial_title` and `tutorial_instructions` exports, and Password's
    "lorem ipsum".
- **Motion:**
  - the frame springs in (the popup spring, as other notebook dialogs do);
  - the steps enter with `Juice.stagger_in`;
  - Mulai uses the standard lipped press.
- **Dismissal:** only **Mulai** closes the card. A tap on the scrim does
  nothing.
- The card's rows are template instances, so `MinigameTutorial.gd` builds no
  visuals. Its `test_viewport_editability` baseline goes from 12 to 0.

### 3.5 Pause and quit

- **`PauseMenu.tscn`** becomes a NotebookFrame dialog with sticker **JEDA**.
  Its buttons: mint **Lanjutkan**, brown **Pengaturan**, tomato **Keluar**.
- **`QuitConfirmDialog.tscn`** becomes a NotebookFrame dialog with sticker
  **KELUAR?**.
  - It shows the existing warning line.
  - Its buttons: mint **Tidak, lanjut main** and tomato **Ya, keluar**.
  - Keep the `Center/Card/Margin/Layout/...` paths that
    `test_minigame_overlays.gd` pins, or update that suite in the same change.

## 4. Per-game layout

Anchors are inside `SafeAreaMargin → UI`. The field is everything between
the header and the tray or hint.

| Game | Pill | Bar label | Timer | Play field | Bottom |
|---|---|---|---|---|---|
| PilihanGanda | skor | `Soal 3/10` | on | `SoalCard` (`QuestionCard`, picture slot as today) hanging from the header; `Spacer` below | **Tray:** 4 answers in one column (`answer_btn_min_height` 130, cream answers) + hint "Ketuk jawaban yang benar" |
| Password | skor | `Soal 3/10` | on | `SoalCard`, then `KalkulatorSlot` (`AspectRatioContainer`) bottom-aligned just above the tray | **Tray:** `AksiRow`: brown **Hapus** (`SecondaryButtonM`), mint **Kirim** (`LobbyCtaButton`) + hint "Ketik jawaban, lalu Kirim" |
| Variabel | skor | `Soal 3/10` | on | as Password (`show_zero_key = false` stays) | as Password |
| Menjodohkan | skor | `Pasangan 2/5` | on | question wheel (read only, cards clamped per Part 1 §4.5) + Part 1's pair chips under it | **Tray:** answer wheel (`WoodNavArrow`s) + brown **Kunci** and mint **Selesai** + hint "Pilih jawaban, lalu Kunci" |
| BuatBatik | hidden | `Langkah 2/5` (segmented) | on | canvas (`CanvasRect`) | **Tray:** 4 tool cards (Part 1's `MinigameToolCard`) + hint that names the next step ("Seret Canting ke kanvas") |
| MainBola | `GOL 3` | `Tendangan 4/8` | on | goal, goalie, target, ball; field full-bleed behind the header | **Hint pill:** swipe-up icon + "Geser ke atas untuk menendang" |
| Badminton | `2 - 3` | `Poin 3/5` | hidden | the whole court, full-bleed; the court `Background` gets `stretch_mode = KEEP_ASPECT_COVERED` | **Hint pill:** "Geser pemukulmu" |
| LombaMenari | skor + ×combo | `Not 12/40` | hidden | fixed dancer (Part 1 §4.6: do not move `CharacterDisplay`); Part 1's runway band floats over the lower field | **Hint pill:** "Geser searah panah"; the "Sisa N" miss warning shows here |

### Removed by this layout

- **BuatBatik:** `TitleLabel` and `InstructionLabel`. The title moves into
  the how-to card; the instruction becomes the hint. Also `ProgressStepsLabel`,
  which the segmented bar replaces.
- **Menjodohkan:**
  - `TitleLabel` and the ProgressHBox badges (replaced by the bar);
  - the two "(GESER / SWIPE)" headers, which Part 1's `MinigamePlankLabel`
    SOAL / JAWABAN plank replaces;
  - the emoji in button text.
- **MainBola:** `HUDLayer/AttemptsLabel`, `HUDLayer/SwipeHint` and the
  bespoke `HUDLayer`.
- **All quiz cards:** the "Soal N/M" `StatusBadge` text, and PilihanGanda's
  `"Pertanyaan %d dari %d | Skor: %d"` rewrite. The bar carries the count.
  `SoalFit` keeps its badge-strip reserve, because the badge node stays for
  per-question status such as correct or wrong.
- **LombaMenari:** the floating "UPS!\nSisa N" label, which moves to the hint
  pill.

### Thumb reach

Every tappable control sits in the bottom 45% of a 1080×1920 frame, except
pause. That excludes the read-only question wheel and cards, which are
content, not controls. The layout test pins this (§7).

## 5. Design rules applied (D6)

| Rule (style guide) | Applied here |
|---|---|
| Popups sit in `NotebookFrame` | How-to card, JEDA, KELUAR? (§3.4–3.5); three new rows in `tests/test_popup_frames.gd` |
| Button colour = role; lipped buttons | Mint = the one main action (Mulai, Kirim, Selesai, Lanjutkan, "Tidak, lanjut main"); brown = neutral (Hapus, Kunci, Pengaturan); tomato = destructive (Keluar, "Ya, keluar"); gold never an action; answers stay cream (commit `c228b4ef`) |
| Icons from `Icons/`, `ButtonGlyph` on picture-on-button children | pause, timer, swipe-up, how-to step icons, BuatBatik tool icons |
| No emoji or dingbats in UI text | drop `Scenes/Minigames` and `Scripts/Minigames` from `test_ui_text_glyphs.gd`'s `SKIP_DIRS`, and clean every hit |
| Type ladder | 36 / 64 / 96 for minigame text, 28 floor for dense rows only; Boohong for pill, bar label, planks and buttons; Open Sans for hints and how-to lines |
| No `theme_override_*` | new `ThemeFactory` variations: `MinigameProgressBar`, `MinigameProgressLabel`, `MinigameTrayPanel`, `MinigameHintLabel`, `MinigameHintPillPanel`, plus a `DISPLAY_ROSTER` update in `tests/test_theme_factory.gd`; rebake |
| No runtime visual construction | tutorial 12 → 0; `BaseMinigame`'s code-built pause and `VisualTimer` are removed (its baseline drops); MainBola's `HUDLayer` labels are gone |
| Every screen fills any phone | all 8 scenes gain `SafeAreaMargin → UI`; backgrounds stay Full Rect + Keep Aspect Covered |
| Illustration materials | unchanged; `test_look_layer.gd`'s paths stay valid |

## 6. Behaviour and flow

```
EventWarning → EventDialogue → [how-to card] → 3‑2‑1 Mulai! → play → MinigameWinScreen / MinigameResultPopup
                               only if shown (below)
```

- **When the card shows.** It shows when `GameSettings.minigame_tutorial_enabled`
  is on **and** the game has not shown it this session. Seen games are kept in
  a new `GameState.seen_minigame_how_to: Dictionary`. That is session-scoped,
  not persisted, per CLAUDE.md. The Debug overlay's Forget Session clears it.
- **Countdown.** `activate_minigame()` always awaits `_play_countdown()`. The
  toggle gates only the card.
- **Hint lifecycle.**
  - At play start the hint shows at full opacity.
  - After the first correct action, the game calls `hint_settle()` and the
    hint tweens to 60%. It stays readable and never hides.
  - `BaseMinigame.show_hint(text)` sets the text and restores full opacity.
    Games call it for a step change (BuatBatik), a wrong order (BuatBatik,
    "Urutan salah!", which flashes, then restores the step hint) or a
    near-loss (LombaMenari "Sisa N").
- **Strip wiring.** `BaseMinigame` finds the header by unique name
  (`%MinigameHeader`) and wires three things:
  - pause (`pause_pressed` → the JEDA dialog);
  - the timer (`set_time` each frame while a time limit runs);
  - progress (a `set_progress` wrapper each game calls on its own count).

  Score keeps flowing through the existing `MinigameScoreHUD` API
  (`set_score`, `set_combo`, `set_label_text`).
- **Win/lose** is unchanged. The pause button still disables when the game
  ends.

## 7. Testing

**New suite `tests/test_minigame_layout.gd`** (a `@tool` source scan plus
`LayoutFrame.stand_up()` where a scene instantiates cleanly). It checks:

- each of the 8 scenes has `SafeAreaMargin/UI/MinigameHeader`;
- the 5 button games have `.../MinigameTray`, and the 3 sports games have
  `.../MinigameHintPill`;
- no minigame scene contains `HUDLayer`, `AttemptsLabel`, `SwipeHint`,
  "(GESER / SWIPE)", "Shots Left" or "lorem";
- every scene sets `how_to` to a `.tres` with 2–3 steps and a non-empty
  title, with no emoji;
- `BaseMinigame.gd` awaits `_play_countdown()` outside the tutorial `if`;
- `BaseMinigame.gd` no longer contains `TextureButton.new()` for pause, or
  `_create_visual_timer`;
- tappable controls in the button games sit below 0.55 of the frame height;
- at 1080×2400, the tray's bottom edge meets the safe area's bottom.

**Suites that change:**

- `test_popup_frames.gd`: the three new rows.
- `test_ui_text_glyphs.gd`: minigames leave `SKIP_DIRS`.
- `test_tall_screen_layout.gd`: gains the minigames, via its
  `_assert_under_safe_area`.
- `test_viewport_editability.gd`: lower `MinigameTutorial` (12 → 0),
  `BaseMinigame` and `MainBola`; never raise a baseline.
- `test_minigame_score_hud.gd`, `test_minigame_typography.gd`,
  `test_kalkulator.gd` and `test_button_roles_phase3.gd`: update paths where
  the HUD, `AksiRow` or `SoalCard` move under `SafeAreaMargin/UI`. Keep every
  asserted *property*.
- `test_minigame_overlays.gd`: the JEDA and KELUAR? paths.
- `test_minigame_header.gd` (Part 1): the new `ProgressRow` and the three
  `show_*` exports.
- `test_theme_factory.gd`: `DISPLAY_ROSTER` for the new variations.

A full `test_run` must be green before the PR (ship-pr).

## 8. Build order (for the plan)

0. **Refresh the branch.** Merge `origin/Textures` into this branch. It is
   329 commits behind Part 1's base. Resolve `CLAUDE.md` and `DEBT.md` by
   hand, and rebake `kejartes_theme.tres` rather than hand-merging it.
1. **Kit:**
   - the variations (§5) and a rebake;
   - extend `MinigameHeader`;
   - add `MinigameTray`, `MinigameHintPill`, `HowToStepRow` and the
     `MinigameHowTo` resources.
2. **`BaseMinigame` wiring:** the header, hint API, countdown fix, `how_to`
   and the seen-this-session set. Retire the code-built pause, timer and
   tutorial table.
3. **Overlays:** the how-to card, JEDA and KELUAR? in `NotebookFrame`.
4. **The quiz family:** PilihanGanda, Password and Variabel.
5. **Menjodohkan**, with Part 1 Phase 4's wheel clamp and pair chips as far as
   the layout needs them.
6. **BuatBatik.**
7. **The sports games:** MainBola, Badminton and LombaMenari.
8. **The glyph sweep, and the tall-phone check on all 8.**

Scene work comes before script work within each step (CLAUDE.md 4b). Restart
the editor after patching scripts, before the next `scene_save`.

## 9. Gates and coordination

**Mentor sign-off** is needed on three points that differ from Part 1's
locked table:

1. The overlays use `NotebookFrame`, not Part 1's Bingkai Kayu overlays. The
   style guide's newer popup rule wins.
2. The answer buttons stay cream, not Part 1's brand-filled answers with a
   gold edge. `c228b4ef` and the button-role rule win.
3. BuatBatik's always-on wood title plank is dropped. The title lives on the
   how-to card, and the strip has no room for it.

**Part 2's author (JustNormalUserTestingMinecraftModels)** needs to know two
things:

- **Phase 8 shrinks.** This layout takes over the Password, Variabel and
  Kalkulator *layouts*. Part 2 Phase 8 keeps key feel (press and release
  juice), LCD styling on tokens and the zero-key variance.
- **One score component.** Part 2's `ScorePill` becomes a ×multiplier badge
  inside `MinigameScoreHUD`, which is Part 1's "extend rather than fork". The
  combo shows there, not in a second bar. The strip has no slot for a
  `ComboMeter`, so Part 2 should drop it or put it in the pill.

**Balance.gd:** untouched. All new numbers are ours: the hint settle opacity
0.6, the danger window 5 s and the thumb line 0.55. They go in named `const`s
in the owning script.

## 10. Assets

These are placeholders now and drop-replaceable at the same path. Record them
in `DEBT.md`.

- `Assets/Images/UI/Icons/pause.svg` and `timer.svg`, `swipe_up.svg`;
- how-to step icons: one per step, about 20 in all, under
  `Assets/Images/UI/Icons/HowTo/`;
- the tray plank and the hint pill are theme styleboxes, so they need no art.

## 11. Out of scope

- Part 2's depth kit (combo, grades, odometer).
- Part 1's win/lose hero and motion vocabulary.
- Part 1's Badminton court lines, net and rackets, MainBola's netted goal and
  goalie, and LombaMenari's runway mechanics. This spec only places those.
- SchoolDay's `GameContainer` and any non-minigame screen.
- Persisting the "seen" set.
