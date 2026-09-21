# EventDialogue weekly status badge — rebuild on the lobby calendar art

2026-09-21. Replaces the flat `calendar_badge.png` in EventDialogue's header
with the lobby's daily-login calendar, and resizes the week fraction so the
widest real state (Kelas 9, `12/16`) fits the tilted page.

## Why

`Assets/Images/EventDialogue/calendar_badge.png` is a flat orange-and-cream
block, listed as placeholder art in `docs/superpowers/DEBT.md`. The lobby
already ships a finished desk calendar — `Assets/Images/UI/icon_daily_login.png`
— and the two surfaces should not carry two different calendars.

The swap is not only cosmetic. Both badges are too narrow for the text they
carry, and the tilted art is narrower still, so the fraction has to shrink.

### Measured fit

Advances from `Assets/Fonts/OpenSans-Bold.ttf`, the `font_body_bold` token,
against the usable cream field on a 208px-wide node:

| Art | Usable field | `12/16` at 64 | at 56 | at 56/32 |
|---|---|---|---|---|
| `calendar_badge.png` (flat) | 179px | 174px | 151px | 113px |
| `icon_daily_login.png` (tilted) | **148px** | 174px | 151px | **113px** |

The current build draws `12/16` at 64 in the 179px field: 2.5px of clearance
each side, and a Godot `Label` neither shrinks nor clips, so it touches the
rim. On the tilted art it would overflow the page outright. A single-size
label at 56 still overflows (151 > 148). Splitting the numerator (56) from the
denominator (32) is what makes it fit, with 17px clear each side.

`Minggu` at `font_body_size` 28 is 103px and fits both fields unchanged.

### Why the field is narrower

`icon_daily_login.png` is 317x385 and drawn in perspective: the cream page is
a sheared quad, not a rectangle. Measured left and right cream edges:

| Height | Left | Right |
|---|---|---|
| 0.40 | 41 | 291 |
| 0.60 | 54 | 304 |
| 0.80 | 69 | 313 |

Every row is ~251px wide, but both edges drift right by ~28px down the page.
A rectangular, horizontally-centred text block only gets the **intersection**
of the rows it covers: x 69..294, i.e. 0.71 of the node width, centred 0.073
of the node width right of the node's own centre.

## Logic

No gameplay logic changes. `EventDialogue.open()` already reads the true week
from `GameState.minggu_ke` and `GameState.get_max_weeks()`
(`SchoolDay.gd:1588`), which resolve to `Balance.JUMLAH_MINGGU_KELAS_7/8/9` =
6, 12, 16. Only the presentation of that string changes.

`WeekLabel` becomes a `RichTextLabel` so one line can carry two font sizes on
a shared baseline. A `Label` cannot; two Labels in an `HBoxContainer` cannot
baseline-align (bottom-aligning them leaves a ~5px descender mismatch between
56 and 32). `EventDialogue`'s sibling `Line` node is already a
`RichTextLabel`, so the pattern is established in this scene.

The BBCode is built in `open()`:

```gdscript
week_label.text = "%d[font_size=%d]/%d[/font_size]" % [
    week, week_denominator_font_size, max_weeks]
```

## State

None. This screen owns no state and writes none. It reads two ints from
`GameState` through arguments already passed by `SchoolDay`. The
`approved_students` <-> `StudentData` bridge is untouched — `open()`'s
`featured: StudentData` argument is used only for the splash and the name in
the line, both unchanged.

## Kelas 7 / 8 / 9

The only per-grade difference is the denominator, and it is the reason for the
change:

| Kelas | `get_max_weeks()` | Widest string | Width at 56/32 |
|---|---|---|---|
| 7 | 6 | `6/6` | 66px |
| 8 | 12 | `12/12` | 113px |
| 9 | 16 | `12/16` | 113px |

All three fit the 148px field. Kelas 9 is the binding case and the one the
test asserts.

## Files

**Art**

- `Scripts/SchoolSimulation/EventDialogueCatalog.gd` — `CALENDAR_BADGE` points
  at `res://Assets/Images/UI/icon_daily_login.png`. The constant is shared
  with the test, so both sides move together.
- `Assets/Images/EventDialogue/calendar_badge.png` (+ `.import`) — deleted,
  unreferenced after the swap.
- `docs/superpowers/DEBT.md` — drop `calendar_badge.png` from the placeholder
  list; the entry is resolved, not marked done.

**Scene** — `Scenes/SchoolSimulation/EventDialogue.tscn`

- `Header/Calendar` — texture swapped; `offset_right` 312 -> 308 so the node is
  204x248 and matches the art's 0.823 aspect exactly. With
  `STRETCH_KEEP_ASPECT_CENTERED` a 208-wide node would letterbox the art by 2px
  each side and put the anchors 2px off the page they are measured against.
  Moving the right edge in also widens, never narrows, the gap to the day pill,
  so `DayBannerPanel`'s `content_margin_left` of 116 still clears it.
- `Header/Calendar/Text` — anchors from `0.0/1.0 x 0.42/0.96` to
  `0.218/0.927 x 0.44/0.84`. Horizontally this is the measured safe field;
  vertically it clears the page seam at 0.34 and the base at 0.90.
- `Header/Calendar/Text/WeekLabel` — `Label` -> `RichTextLabel`, variation
  `DayBannerLabel` -> `CalendarWeekLabel`, `bbcode_enabled = true`,
  `fit_content = true`, `autowrap_mode = 0`, `scroll_active = false`,
  centred. A node's type cannot be changed in place, so this is a
  delete-and-recreate through the editor.
- `Header/Calendar/Text/MingguLabel` — unchanged, stays on `CalendarLabel`.

**Theme** — `Scripts/Design/ThemeFactory.gd`

- New `CalendarWeekLabel` variation of `RichTextLabel`:
  `normal_font_size = CALENDAR_WEEK_SIZE`, `default_color = tokens.text_primary`,
  `normal_font = font_body_bold`.
- New `const CALENDAR_WEEK_SIZE := 56`, beside the existing
  `DAY_BANNER_OUTLINE`, with a `##` line recording that it is the largest size
  at which Kelas 9's `12/16` clears the tilted page.
- Rebake `Assets/Theme/kejartes_theme.tres` via `Scripts/Design/BakeTheme.gd`.

**Script** — `Scripts/SchoolSimulation/EventDialogue.gd`

- `week_label` retyped `Label` -> `RichTextLabel`.
- New `@export var week_denominator_font_size: int = 32`, documented with `##`.
  It lives here rather than in `ThemeFactory` because BBCode carries the size
  inline and this script is what writes it.
- `open()` writes the BBCode string shown above.

**Tests** — `tests/test_event_dialogue.gd`

- `test_open_dresses_the_screen` — `d.week_label.text` -> `get_parsed_text()`,
  still `"2/6"`, so the assertion keeps reading as the player-visible string.
- `test_the_scene_is_authored_and_themed` — `WeekLabel`'s expected variation
  becomes `CalendarWeekLabel`.
- `_VARIATIONS` — add `"CalendarWeekLabel": &"RichTextLabel"`.
- `test_factory_builds_the_dialogue_variations` — assert the new variation's
  font and size.
- **New** `test_the_widest_week_fits_the_calendar_page` — measure
  `font_body_bold.get_string_size("12", …, CALENDAR_WEEK_SIZE).x` plus
  `get_string_size("/16", …, 32).x` and assert the total is under the safe
  field (`Text`'s anchor span x node width). This is a real measurement,
  not a source scan: it fails if anyone raises the size or narrows the anchors.
- **New** `test_the_text_block_sits_on_the_calendar_page` — assert `Text`'s
  four anchors, so the fix cannot silently regress to a centred block.

## Not doing

- **A `SafeAreaMargin` for the SchoolDay stack.** `Calendar` starts 44px from
  the screen top and nothing in SchoolDay or EventDialogue sits under a
  `SafeAreaMargin`, so a punch-hole clips the spiral binding. Real, and pinned
  by `tests/test_tall_screen_layout.gd:65` for other screens — but it is a
  structural change to a whole scene stack, not to this badge.
- **The lobby's squashed icon.** `Scenes/Lobby/loby.tscn:918` draws this same
  art at 96x96 with `stretch_mode = 0` (`STRETCH_SCALE`), squashing 0.823 into
  a square; its siblings use `stretch_mode = 5`. Different screen.
- **A countdown instead of a fraction** ("14 minggu lagi"). The fraction is a
  ratio the player must subtract to use, and `2/16` reads worse than `2/6`.
  Worth considering, but it is a content change, not the art swap asked for.
- **Re-tuning the day pill.** `DayBannerPanel` is correct as built.
