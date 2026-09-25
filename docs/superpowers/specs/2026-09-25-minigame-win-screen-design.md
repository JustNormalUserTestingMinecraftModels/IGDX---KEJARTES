# Minigame win screen, day outfits and the icon refresh — design

2026-09-25 · branch `feat/minigame-win-screen` · requested through `/gamecode`

Six asks from one message, delivered as one pass because they share art
(the new splash outfits appear on the new win screen) and one review:

1. Replace the Lobby's achievement, settings, skin-select and daily-login icons.
2. Lower every EventDialogue speaker to where `eventdialogue_mockup.jpeg` has them.
3. A new minigame **win** screen, per `minigamewinscreen_mockup.jpeg`.
4. Its staged reveal over the live minigame.
5. Replace every back button with the new arrow.
6. Day outfits: `_batik` on Kamis, `_pramuka` on Jumat, on every event screen.

Mockups and icons were delivered in `C:/Users/user/Downloads/`; the outfits
are in the artist's Drive folder `1kYGIbcsWrSh8o3C2pbOgoT0kM5y06Lb4`.

## 1. Icons — drop-replace at the same path

All four new icons are 322×359 RGBA. Each lands on the path the old art had,
so every scene, test and `.import` (mipmap flag included, pinned by
`test_texture_mipmaps`) keeps pointing at the right file:

| New file (Downloads) | Replaces | Also shown on |
|---|---|---|
| `achievement_icon.png` | `Assets/Images/Achievements/achievement_button.png` | — |
| `settings_icon.png` | `Assets/Images/UI/setting.png` (was 512×512) | MainMenu's gear |
| `skinselect_icon.png` | `Assets/Images/UI/skin_switch.png` (was 540×540) | — |
| `dailylogin_icon.png` | `Assets/Images/UI/icon_daily_login.png` (was 317×385) | SchoolDay's book-clock badge |

- The Lobby's `DailyLogin` button is the only one of the four drawn with
  `stretch_mode = 0` (scale), which squashes the art into its 96×96 box. It
  moves to `5` (keep aspect centred) like its three siblings.
- **The book-clock badge follows the swap on purpose.** It was asked for as
  "the lobby's daily-login calendar" (`test_book_clock_phases`). The new art is
  the same illustration recoloured: fitting the header-to-page edge gives
  −8.94° on both, so the badge's −9° text rotation still holds. The canvas
  changes (317×385 → 322×359), which moves the art inside the badge's keep-
  aspect rect by a few pixels; one measurement confirms the week text still
  sits on the page, and the text box's anchors move only if it does not.

## 2. EventDialogue — speakers lowered

Every speaker splash (the six students, their skins, Mom, both teachers) is
a 1080×1920 canvas with shared registration. Matching `splash_thea.png`
against the mockup (search over scale and offset, mean RGB error 13.5 on the
face region) gives **scale 1.0, offset (−30, +276)**: the art is drawn 1:1,
276 px lower and 30 px left of today.

`Splash` in `EventDialogue.tscn` becomes a 1080×1920 box **anchored to the
bottom edge** — anchors (0, 1, 1, 1), offsets (−30, −1644, −30, 276) — still
keep-aspect-centred. On a 9:16 screen that is exactly the mockup. On a 20:9
phone the character stays locked to the bottom-anchored dialogue box (the
tall-phone rule: a picture and its items move as one piece), and the extra
height opens above her head instead of splitting her from the box. The
bottom 276 px of the art falls below the screen, under the dialogue box,
where the mockup also hides it. `Shadow` follows its parent's rect already.

## 3–4. The minigame win screen

### What the player sees

```
 ┌──────────────────────────┐
 │   live minigame, blurred  │
 │        ┌──────┐          │  Splash: the speaker, 0.915×, bottom-anchored
 │        │ face │          │
 │   ┌────┴──────┴───────┐  │
 │   │ TERIMA KASIH, GURU!│  │  Bubble + tail (surface_card)
 │   └─▲─────────────────┘  │
 │ ╭────────────────────────╮│  Card ("the big box"), top corners rounded
 │ │   ★      ★      ★      ││  Stars: ResultStar ×3 (star.png)
 │ │ 🎓^ +8     ⚡ −5        ││  Stats: skill chip, energy chip
 │ │ [ LOBBY ]  [ LANJUT ]  ││  SecondaryButtonL, PrimaryButtonL
 │ ╰────────────────────────╯│
 └──────────────────────────┘
```

Measured off the mockup (900×1600 scaled ×1.2 to 1080×1920):

| Piece | Rect at 1080×1920 | Notes |
|---|---|---|
| Splash | (20, −13) 988×1757 | Citra's splash at 0.915×, error 7.6; bottom-anchored |
| Bubble | (50, 898) 980×144 | tail at x≈288–342, pointing up at the speaker |
| Card | (0, 1092) to the bottom edge | top corners rounded |
| Stars | centres x 246 / 540 / 834, y 1254, ~258 px | |
| Stat row | y 1446–1614; chips at x 102 and 618 | icon ~216 px wide, value to its right |
| Buttons | (102, 1674) and (569, 1674), 400×152 | the mockup's dark pills are placeholders |

Every piece hangs off the bottom edge, so the whole composition moves as one
on a tall phone and only the blurred minigame above it grows. As anchors
(0, 1, 1, 1) and offsets (left, top, right, bottom):

| Node | Offsets |
|---|---|
| Splash | (20, −1933, −72, −176), keep aspect centred (988/1757 = 1080/1920) |
| Bubble | (50, −1022, −50, −878) |
| Card | (0, −828, 0, 0) |

### Nodes (`Scenes/Minigames/UI/MinigameWinScreen.tscn`)

```
MinigameWinScreen (CanvasLayer, layer 999, process_mode ALWAYS)
└─ Root (Control, Full Rect, mouse_filter STOP — nothing reaches the game)
   ├─ Blur (ColorRect, Full Rect, event_dialogue_blur_material.tres)
   ├─ Splash (TextureRect, illustration_grade_cutout.tres, bottom-anchored)
   ├─ Bubble (Control, bottom-anchored — a plain Control, because a
   │  │        Container would stretch the tail over the whole box)
   │  ├─ Panel (PanelContainer, Full Rect, MinigameWinBubble)
   │  │  └─ Line (Label, MinigameWinLine, uppercase = true)
   │  └─ Tail (TextureRect, chat_bubble_tail.svg flipped both ways so it
   │           points up-left at the speaker; its fill is already surface_card)
   ├─ Card (PanelContainer, MinigameWinCard, bottom-anchored)
   │  └─ Layout (VBoxContainer)
   │     ├─ StarRow (HBoxContainer) ── Star1..3 (ResultStar.tscn, 258×258)
   │     ├─ StatRow (HBoxContainer) ── SkillChip, EnergyChip (MinigameWinStat.tscn)
   │     └─ ButtonRow (HBoxContainer) ── LobbyButton (SecondaryButtonL), LanjutButton (PrimaryButtonL)
   ├─ ConfettiFireworks (instance) — one burst per earned star
   └─ ResultConfetti (instance) — the three-star rain
```

`MinigameWinStat.tscn` is the repeated row's template (Pattern B): `Icon`
(TextureRect), `Chevron` (TextureRect, `icon_chevron_up.png`, shown only on a
gain — the art has no down variant, as `DaySummaryStatRow.shows_chevron`
already rules) and `Value` (Label, `MinigameWinStatLabel`). Its script
exposes `set_stat(icon: Texture2D, delta: float)`, `show_icon()` and
`count_up(seconds)`. Icons are the Daily Results set: the category's
`DaySummaryStatRow.ICON_FOR` icon for the skill chip, and
`Assets/Images/StudentCard/stat_energy.png` (the mockup's lightning) for
energy.

### Theme (ThemeFactory, then rebake)

New tokens in `DesignTokens` and four variations, no `theme_override_*`:

| Variation | Built from |
|---|---|
| `MinigameWinCard` (PanelContainer) | new token `minigame_win_card` `#E8EDCD` (the mockup card's mid-tone; its gradient is dropped), top radius new token `minigame_win_card_radius` = 72, margins `space_xl` |
| `MinigameWinBubble` (PanelContainer) | `surface_card`, radius `STUDENT_CHAT_BUBBLE_RADIUS`, margins `space_xl`/`space_md` — the same white the tail svg is filled with |
| `MinigameWinLine` (Label) | display face, `font_h2`, `text_primary` |
| `MinigameWinStatLabel` (Label) | display face, new token `minigame_win_stat_size` = 96, white with a `day_glyph_outline` rim at `text_outline_size` — `DaySummaryStat`'s look, larger |

Both labels join `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`.

### The reveal

A fixed order, one const, so the sequence is data and a test can pin it:

```
REVEAL_ORDER = [card, splash, bubble, stats, stars, buttons]

card     Blur fades in; Card rises from below the screen      CARD_RISE_TIME 0.35 s, TRANS_BACK
splash   SPLASH_GAP 0.12 s later: Splash fades in, rising 60 px   SPLASH_RISE_TIME 0.30 s
bubble   BUBBLE_GAP 0.12 s later: Juice.pop_in(Bubble)
stats    per chip, STAT_STAGGER 0.15 s apart: the icon (and a gain's
         chevron) pops in first, then Value counts 0 → delta   STAT_COUNT_TIME 0.5 s
stars    MinigameResultPopup's own ladder: STAR_POP_SCALES / STAR_HOLD_TIMES,
         celebrate(), one firework per earned star, confetti at three
buttons  Juice.stagger_in(ButtonRow's buttons)
```

About three seconds in all. Every named number is a `const` at the top of
`MinigameWinScreen.gd`. `RewardFeedback.play(&"minigame_win")` fires when the
card lands, as the old card did; the count-up plays `&"tally"`. A stat chip
whose delta is 0 is hidden, and a row with both hidden is hidden.

`play()` awaits either button and returns `&"lanjut"` or `&"lobby"`, then
fades out and frees itself.

### What the numbers are

Each roster student receives the minigame's result (`StudentManager.
record_minigame_result` loops the whole roster), and their deltas differ: the
specialty multiplier scales the energy cost, Semangat Juang adds a skill
bonus, the weekly cap trims a gain. The screen shows the **roster average of
the deltas actually applied, rounded**, with its sign: "+8" for the skill,
"−5" for energy on a Kelas 7 win. It is the class's result, which the day
summary then breaks down per student.

### Who is on the splash, and what they say

`EventDialogueCatalog.win_speaker_path(category, featured, day_name, roll)`:

| Category | Speaker |
|---|---|
| Akademis | the featured student |
| SeniBudaya | Guru Seni Budaya when `roll < WIN_TEACHER_CHANCE` (0.5), else the featured student |
| Olahraga | Guru Penjas when `roll < WIN_TEACHER_CHANCE`, else the featured student |
| any, empty roster | the category's teacher, or no splash for Akademis |

The featured student is **the one the pre-minigame EventDialogue featured**,
so the student who asked is the one who thanks you. With Lewati Dialog
Minigame on there was no dialogue, so SchoolDay picks one with the same
`pick_featured` rule the dialogue would have used. A student speaker wears
their day outfit (section 6).

Lines, drafts for the writer like the rest of the catalog:

| Speaker | `WIN_LINES` |
|---|---|
| a student | "Terima kasih, Guru!" |
| Guru Penjas | "Kerja bagus! Latihannya berhasil." |
| Guru Seni Budaya | "Indah sekali! Terima kasih sudah membimbing mereka." |

### Data flow

The stats used to be applied *after* the result card closed. The win screen
needs them before it opens, so recording moves to the moment the result is
decided:

```
SchoolDay._play_minigame                      BaseMinigame
  instantiate minigame
  mg.host_context = {category, speaker, line}
  mg.result_reporter = _report_minigame ─────►  _show_result_overlay(is_win)
                                                  stars = _calculate_stars(...)
                          ◄─ result_reporter.call(is_win, score, max_score)
  record_minigame_result(...)  (stats applied here, once)
  return {stat_delta: avg, energy_delta: avg}
                                                  win  → MinigameWinScreen.play() → result_exit
                                                  loss → MinigameResultPopup (unchanged)
                                                  _do_win / _do_lose → signal
  await _minigame_result
  skip its own record_minigame_result when the reporter already ran
  Achievements.record_minigame(...)             (unchanged, still after)
  tear the minigame down
  result_exit == &"lobby" → _leave_week_after_today()
```

- `host_context: Dictionary` and `result_reporter: Callable` are plain vars on
  `BaseMinigame`, empty/invalid by default. Without them — the debug
  launcher, `MinigameMenu`, F6 — the win screen still shows, with the
  category-less fallback: no stat row, the splash from `host_context` or none,
  and LOBBY behaves as LANJUT.
- A loss still calls the reporter (the stats apply at the same moment on
  both paths) but its card is the unchanged `MinigameResultPopup`, fed
  nothing new.
- `result_exit: StringName` (default `&"lanjut"`) is what SchoolDay reads.

### The two buttons

- **LANJUT** — continue the day, exactly as the old card's Lanjutkan did.
- **LOBBY** — leave the week now. SchoolDay's `_leave_week_after_today()`
  advances `current_day` past today (its decay and roll already happened) and
  runs the existing `skip_to_results()`, which auto-resolves the remaining
  days with the grade's skip odds, shows the weekly report, and leaves the
  day screen on its usual Kembali button to the Lobby (or to TesNotice on the
  grade's final week, as today). Advancing first matters: `skip_to_results()`
  starts at `current_day` and would decay and roll today a second time — the
  bug the dev Skip key already has mid-day.

Both use the project's button variations (`SecondaryButtonL`,
`PrimaryButtonL`, the Tolak/Terima pairing at the L step, whose 160 px
height is the nearest to the mockup's 152); the mockup's dark pills are
placeholders by the owner's note.

## 5. Back buttons — drop-replace the canonical arrow

`test_back_controls` already pins one canonical arrow,
`Assets/Images/UI/Nav/return_button.png` (512×512), across eleven controls,
plus SkinSelect's. The new `return_button.png` is also 512×512: it replaces
that file in place and every back control follows. The glyph changes from a
white arrow in a red outline to a solid dark red arrow; one screenshot of a
dark-backed screen (SchoolDay's week-end Kembali) checks it still reads.

## 6. Day outfits

The Drive folder holds `<Name>_batik`, `<Name>_pramuka` and `<Name>_osis` for
all six students. The `_osis` files are the everyday uniform — each within
0.5 % of the byte size of today's `splash_<name>.png` — and are not imported.

- **Download** the twelve batik and pramuka PNGs through Claude in Chrome's
  `drive.usercontent.google.com/download?id=<id>&export=download` links (the
  route that worked on 2026-09-14; plain curl gets a login page), and match
  each by byte size.
- **Verify** each is 1080×1920 with its student's default registration (the
  top of its alpha within ±40 px of the default splash's). Stop and report on
  any that is not; a mis-registered outfit would jump on screen.
- **Import** to `Assets/Images/SplashArtMurid/Seragam/splash_<name>_batik.png`
  and `…_pramuka.png`, lowercase like the default art.
- **`StudentSkins`** gains `DAY_OUTFITS := {"Kamis": "batik", "Jumat":
  "pramuka"}` and `static func day_splash_for(student_name, day_name) ->
  String`, "" on the other days or for a missing file.
- **`EventDialogueCatalog.splash_path_for(e, featured, day_name = "")`** uses
  it for a student speaker; `EventDialogue.open()` already receives
  `day_name` and passes it on; `win_speaker_path` goes through the same call.

Scope: the two event screens that draw the full-body splash — EventDialogue
and the win screen. On Kamis and Jumat the outfit **wins over an equipped
skin** there, as a uniform day would. The bust crops (avatar strip, day
summary, event picker) keep the equipped look.

## State

No new persisted state, no new `GameState` field.

| Where | What changes |
|---|---|
| `StudentData` (sim side) | nothing new; `skill` = the category's `akademis` / `seni_budaya` / `olahraga`, `energy`, `mood` move exactly as before, only earlier (at result, not after the card) |
| `GameState.approved_students` | unchanged — `write_back_to_gamestate()` still carries `akademis1/2/3` (akademis, seni_budaya, olahraga) and `kepribadian1/2` (**mood, energy**) back at week end |
| `GameState.minigame_gain_this_week` | still written by `record_minigame_result`, once per minigame |
| `SchoolDay` | `_last_featured: StudentData` (the dialogue's featured student), `_minigame_recorded: bool` |
| `BaseMinigame` | `host_context`, `result_reporter`, `result_exit` |

## Kelas 7 / 8 / 9

The screen reads the numbers; it sets none. What differs is what it shows:

| Grade | Win skill gain (score-rated) | Win energy | Win mood (not shown) |
|---|---|---|---|
| 7 | 5 + ratio × 10 (flat 10) | −5 | −5 |
| 8 | 4 + ratio × 8 (flat 8) | −7 | −7 |
| 9 | 3 + ratio × 6 (flat 6) | −10 | −10 |

before the specialty multiplier, quirks and the weekly cap (14 / 12 / 10),
all of which the roster average already includes. LOBBY's skip odds are the
grade's `SKIP_PELUANG_KALAH_KELAS_*`, as for any skip. Balance.gd is not
touched.

## Files

| File | Change |
|---|---|
| 5 PNGs listed in §1 and §5 | replaced in place |
| `Assets/Images/SplashArtMurid/Seragam/*.png` | 12 new |
| `Scenes/Lobby/loby.tscn` | `DailyLogin.stretch_mode` 0 → 5 |
| `Scenes/SchoolSimulation/EventDialogue.tscn` | `Splash` anchors/offsets |
| `Scenes/Minigames/UI/MinigameWinScreen.tscn`, `MinigameWinStat.tscn` | new |
| `Scripts/Minigames/UI/MinigameWinScreen.gd`, `MinigameWinStat.gd` | new |
| `Scripts/Minigames/UI/BaseMinigame.gd` | host context, reporter, win → win screen |
| `Scripts/SchoolSimulation/SchoolDay.gd` | host context, record via reporter, `_last_featured`, LOBBY exit |
| `Scripts/SchoolSimulation/EventDialogueCatalog.gd` | `win_speaker_path`, `WIN_LINES`, `WIN_TEACHER_CHANCE`, day-aware `splash_path_for` |
| `Scripts/SchoolSimulation/EventDialogue.gd` | passes `day_name` to `splash_path_for` |
| `Scripts/Skins/StudentSkins.gd` | `DAY_OUTFITS`, `day_splash_for` |
| `Scripts/Design/DesignTokens.gd`, `ThemeFactory.gd`, `Assets/Theme/kejartes_theme.tres` | 3 tokens, 4 variations, rebake |
| tests | new `test_minigame_win_screen.gd`, `test_ui_icon_refresh.gd`; additions to `event_dialogue`, `student_skins`, `minigame_single_result`, `school_day`, `theme_factory`, `illustration_ao`, `look_layer` (tall-phone checks live in the new suite, since `layout_frame.gd` stands up only a Control-rooted scene) |
| `CLAUDE.md` loop line, `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md` | one line each (DEBT: the Skip key's mid-day double decay) |

## Testing

Test-first, by suite:

- `ui_icon_refresh` (new) — each delivered file sits at its path:
  `FileAccess.get_md5` of the res:// file equals a constant taken from the
  Downloads original (the suite cannot read Downloads itself); the Lobby's
  `DailyLogin` keeps aspect.
- `event_dialogue` — `Splash` anchors (0,1,1,1) and offsets (−30,−1644,−30,276);
  a student speaker on Kamis gets `_batik`, on Jumat `_pramuka`, else their
  own; teachers never change.
- `student_skins` — `day_splash_for` for all six × two days; every outfit
  path exists and is 1080×1920.
- `minigame_win_screen` (new) — authored, themed, no overrides, no `.new(`;
  `REVEAL_ORDER`; `configure` hides zero chips and fills stars from the
  count; `win_speaker_path` table; `WIN_LINES`; bottom anchoring at
  1080×2400, with `Root` moved into a frame of that size (rect checks).
- `minigame_single_result` — a win builds the win screen and not the popup,
  a loss the reverse; the reporter is called once, before either card.
- `school_day` — records once when the reporter ran; `_leave_week_after_today`
  advances `current_day` before skipping (source scan plus the pure helper).
- `theme_factory`, `illustration_ao`, `look_layer` — roster, census and
  grade entries for the new screen.

Then one full `test_run`, and three looks at full size: the win screen
mid-reveal and settled over a real minigame, EventDialogue on a Kamis, and
the SchoolDay badge with the new calendar.

## Not doing

- A new **loss** screen — the ask is a win screen; losses keep
  `MinigameResultPopup`, fed nothing new.
- Tap-to-skip on the reveal.
- The mockup card's gradient (flat mid-tone instead) and its navy-outlined
  stars (the project's `star.png`, shared with StatCheck and the old card).
- Outfits on the bust crops (avatar strip, day summary, event picker).
- Importing the `_osis` art (it is today's default).
- A mood chip — the mockup shows two stats.
- Fixing the dev Skip key's mid-day double decay; LOBBY avoids it, the key
  keeps it (logged in DEBT.md).

**Considered and rejected:** keeping the win screen inside SchoolDay and
emitting the minigame's signal with no card. It would split the two result
cards between two owners and lose the win screen in the debug launcher,
where the card is most often checked.
