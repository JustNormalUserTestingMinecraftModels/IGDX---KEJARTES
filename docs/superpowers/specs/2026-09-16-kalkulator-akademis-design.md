# Kalkulator for Variabel and Password — design

2026-09-16. Branch `feat/kalkulator-akademis`.

Re-skins the two number-entry Akademis minigames (`Variabel.tscn`,
`Password.tscn`) onto the artist's calculator. Both today are a bare
`VBoxContainer` of default-themed Labels and a numpad the script builds with
`Button.new()`; Password renders a badminton court behind it and Variabel
renders nothing at all.

Source of truth for the layout is `mockup_calculator.png` (1080x1920, dropped
in Downloads 2026-09-16), plus `kalkulator_base.png` and
`kalkulator_button.png`.

## What the player gets

A wooden desk (the same `meja_background.png` Menjodohkan uses), a white paper
question card at the top (the same `QuestionCard.tscn` Menjodohkan's wheel
uses), a drawn calculator in the middle whose green LCD shows what they have
typed, and two Lobby-style buttons at the bottom: **Hapus** and **Kirim**.

Each key squishes down onto its own skirt and darkens while held, then springs
back — the art already draws the skirt, so the squish reads as a real
keypress rather than a UI scale tween.

## Layout

Fractions are of the 1080x1920 design viewport, taken from the mockup and then
shifted down 97 px so nothing collides with `BaseMinigame`'s pause button
(32,28)-(172,168) and its visual timer (-172,28)-(-32,168). The mockup's card
already sits horizontally between those two corner widgets (182 > 172,
897 < 908); only the vertical shift is new.

| Node | anchors L / T / R / B | px |
|---|---|---|
| `Background` | 0 / 0 / 1 / 1 | full rect, Keep Aspect Covered |
| `HeaderRow` (ScoreHUD) | 0.25 / 0.0146 / 0.75 / 0.0875 | 270,28 – 810,168 |
| `SoalCard` | 0.1685 / 0.0938 / 0.8306 / 0.2734 | 182,180 – 897,525 |
| `KalkulatorSlot` | 0 / 0.2896 / 1 / 0.8328 | 0,556 – 1080,1599 |
| `AksiRow` | 0.0778 / 0.8635 / 0.9333 / 0.9448 | 84,1658 – 1008,1814 |

`KalkulatorSlot` holds a `Kalkulator.tscn` instance whose root is an
`AspectRatioContainer` at 1080/1487 = 0.7263, the imported texture's own
ratio rather than the mockup's measured 0.7257, so the body never
letterboxes inside its own container — the calculator keeps the
artwork's proportions and centres itself when the slot is wider or (on a 20:9
phone) taller. Everything else is anchored in fractions, so the screen fills
any phone.

### Inside `Kalkulator.tscn`

Fractions of the fitted 757x1043 body rect. The LCD one is measured from
`kalkulator_base.png`'s own pixels (the green field spans x 722–6733,
y 968–2812 of 7458x10265) and it lands exactly where the mockup draws it,
which is what confirms the mockup is a 1:1 placement of the base texture.

| Node | L / T / R / B |
|---|---|
| `BodyTexture` | 0 / 0 / 1 / 1 |
| `Layar` (Label) | 0.0968 / 0.0943 / 0.9028 / 0.2740 |
| `KeyGrid` (GridContainer, 3 cols) | 0.1242 / 0.2896 / 0.8560 / 0.8188 |
| `ZeroRow` (HBoxContainer) | 0.1242 / 0.8245 / 0.8560 / 0.9971 |

The base texture draws **no** key recesses below the LCD — the recess is part
of `kalkulator_button.png` itself — so the grid is free geometry, constrained
only by the mockup's proportions (180x180 cells, 6 px separation).

`KeyGrid` holds nine `KalkulatorKey.tscn` instances, `Key1`..`Key9`.
`ZeroRow` holds one more, `Key0`, between two expanding spacer Controls
(`SpacerKiri`, `SpacerKanan`) at the grid's 6 px separation, so it is
exactly one column wide and centred at every screen size. (A fixed
`custom_minimum_size` was tried first and drifted wider or narrower than
the grid cells as the calculator scaled.) The LCD label drops
`DisplayLabel`'s outline (`outline_size = 0`): a cream halo reads wrong
on a segment display. Password needs it
(answers run to 198); Variabel does not (its answers are always 1–9, as
`Variabel.gd` already comments), so Variabel sets `show_zero_key = false` and
the row hides, leaving the plain body space the mockup shows.

### `KalkulatorKey.tscn`

Root `Button`, `flat = true`, no text. Children:

- `Visual` (Control, full rect, `mouse_filter = IGNORE`) — the thing that
  animates, so the Button's own hit rect never moves.
  - `Cap` (TextureRect, `kalkulator_button.png`, full rect, stretch scale)
  - `Digit` (Label, full rect, centred)

`KalkulatorKey.gd` is `@tool`, so the editor shows the digit. Its `@export`s:
`key_text`, `press_scale`, `press_offset`, `press_tint`, `press_duration`,
`release_duration`. `_ready()` sets `Digit.text = key_text`, parks
`Visual.pivot_offset` at bottom-centre (so the cap squishes *onto* its skirt
rather than shrinking in place) and sets `Juice.NO_AUTO_JUICE` so `UIPolish`
does not add a second, competing scale tween. `button_down` tweens
`Visual.scale` → `press_scale` and `Visual.modulate` → `press_tint`;
`button_up` springs both back with `TRANS_BACK`. It emits
`key_pressed(key_text)`, which `Kalkulator.gd` relays as `digit_pressed`.

Every property an instance needs lives on the sub-scene **root**, per
CLAUDE.md 4b — overrides set on an instance's children are dropped on save.

## State

Nothing crosses the `approved_students` ↔ `StudentData` bridge. This pass is
presentational: the two scripts keep `score`, `max_score`,
`current_question_index`, `expected_answer`, `active_questions` and their
question generators untouched, and still finish through
`get_target_win_score()` → `win_game()` / `lose_game()`.

What moves inside the scripts:

- `input_line_edit` (Variabel, a `LineEdit`) and `input_label` (Password, a
  `Label`) both become `layar`, the `Kalkulator`'s LCD Label. Variabel loses
  the `LineEdit`'s `editable` handling; a Label has no such state.
- `numpad_grid` / `keypad_grid` and `_setup_numpad()` / `_setup_keypad()` are
  deleted. Keys are authored nodes; the script only connects
  `digit_pressed` and calls `set_keys_disabled()`.
- `submit_button` → `AksiRow/BtnKirim`; a new `AksiRow/BtnHapus` takes
  `_on_clear_pressed`. Password's in-grid `Enter` and `C` keys are gone.
- `progress_label` → the card's `StatusBadge/BadgeLabel`, showing `Soal 1/3`.
  `PanelContainer` sorts through `fit_child_in_rect`, which honours size
  flags, so the badge keeps its `SHRINK_END` / `SHRINK_BEGIN` corner instead
  of filling the card.
  The score already lives in the shared `MinigameScoreHUD`, which stays
  instanced (`tests/test_minigame_score_hud.gd` requires it).
- Dead `@export`s go: `input_box_*`, `numpad_btn_*` / `keypad_btn_*`
  textures, tints, press scale and duration, `clear_btn_height`,
  `submit_btn_normal_texture`. Their jobs now belong to `KalkulatorKey.gd`.
  `background_texture` stays and is re-pointed at `meja_background.png` in
  both scenes — Password's currently loads `lapanganBadminton.jpg` over the
  desk at runtime, which is the bug behind "replace the background".

### Fitting the question text

`SoalCard` is 715x345 where Menjodohkan's wheel card is 850x480, and
Variabel shows the longest text either game produces — four equation lines
plus the question, and five more on the post-answer variable reveal. Both
scripts therefore size the card's `TextLabel` from the text length, the way
`Menjodohkan._instantiate_cards()` already does, but on a shorter ladder:
Password's one-line sums land at the top rung, Variabel's multi-line blocks
near the bottom. `TextLabel.clip_text` stays on, so an overflow crops rather
than bursting the card — which is exactly why the rungs have to be checked
against a real screenshot, not just against the tests.

## Kelas 7 / 8 / 9

Identical. Grade never reaches these files: `BaseMinigame.get_target_win_score()`
keys off `difficulty`, and the win-stat/loss-penalty table is applied by the
caller in `SchoolDay`. Nothing in this pass reads `GameState.current_grade`.

## Assets

`kalkulator_base.png` and `kalkulator_button.png` arrive at 7458x10265 and
1716x1620 — the base alone would be a ~306 MB VRAM texture. They are
downscaled on the way in, to the size the game actually draws them plus
headroom:

| Source | In repo | Size |
|---|---|---|
| `kalkulator_base.png` | `Assets/Images/UI/Kalkulator/kalkulator_base.png` | 1080x1487 (drawn at 757x1043) |
| `kalkulator_button.png` | `Assets/Images/UI/Kalkulator/kalkulator_button.png` | 360x340 (drawn at 180x180) |

`kalkulator.png` (the base with keys already painted on) is reference only and
is not imported — the keys have to be live controls.

## Files

New:

- `Assets/Images/UI/Kalkulator/kalkulator_base.png`, `kalkulator_button.png`
- `Scenes/Minigames/Akademis/Kalkulator.tscn`, `KalkulatorKey.tscn`
- `Scripts/Minigames/Akademis/Kalkulator.gd`, `KalkulatorKey.gd`
- `tests/test_kalkulator.gd`

Changed:

- `Scenes/Minigames/Akademis/Variabel.tscn`, `Password.tscn`
- `Scripts/Minigames/Akademis/Variabel.gd`, `Password.gd`
- `tests/test_viewport_editability.gd` — the ratchet turns the right way.
  `Variabel.gd` goes 4 → 1 (only the `+20s` floating `Label.new()` remains,
  which is per-call-dynamic popup text); `Password.gd` goes 4 → 0 and leaves
  `BASELINE` entirely.

## Copy

Indonesian, per CLAUDE.md, even though the mockup letters them in English:
**Hapus** (mockup "CLear") and **Kirim** (mockup "submit"). Both carry
`theme_type_variation = &"LobbyCtaButton"` — the Lobby's STUDENT / JADWAL!
buttons — which is what "the same button design as the lobby" names.

## Testing

`tests/test_kalkulator.gd`, `suite_name()` = `"kalkulator"`, `@tool`, no
coroutines. Mostly source-text and asset-existence scans in the established
`tests/test_minigame_art.gd` style, plus two real instantiation tests —
`KalkulatorKey.tscn` and `Kalkulator.tscn` have no autoload dependencies, so
they can be built live:

1. Both textures exist and load as `Texture2D`.
2. Both game scenes point `Background.texture` **and** the
   `background_texture` export at `meja_background.png`, and no longer
   mention `lapanganBadminton`, `KiperLeft`, `DiagonalLeft` or
   `DiagonalRight`.
3. Both game scenes instance `Kalkulator.tscn` and `QuestionCard.tscn`.
4. `Kalkulator.tscn` instances ten `KalkulatorKey.tscn`; their `key_text`
   values are exactly `0`..`9`.
5. `KalkulatorKey.tscn` references `kalkulator_button.png`.
6. Variabel sets `show_zero_key = false`; Password does not.
7. Each game scene has two `LobbyCtaButton` buttons reading Hapus and Kirim.
8. `KalkulatorKey.gd` animates both `scale` and `modulate` off `button_down`
   (the squish and the darken), and opts out of `UIPolish`.
9. Neither game script contains `Button.new(` any more.
10. Live: a `KalkulatorKey` with `key_text = "7"` renders `7` and emits
    `key_pressed("7")`; a `Kalkulator` with `show_zero_key = false` hides
    `ZeroRow` and shows it again when set true.

## Not doing

- No change to question generation, scoring, timing, the result popup or the
  tutorial.
- No backspace key. `Hapus` clears the whole entry, as `C` does today.
- `papantulis.png` is another branch's asset and is not touched.
- No new persistence. Nothing here reaches `user://`.
