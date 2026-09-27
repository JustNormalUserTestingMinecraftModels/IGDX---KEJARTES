# The SchoolDay calendar header — design

2026-09-21 · branch `feat/schoolday-calendar-header`

Two asks. The second is already shipped, so this spec records why and scopes
the work to the first.

1. `BookClockWidget.tscn` carries the day and the week the way EventDialogue
   does, drawn on the daily-login calendar illustration rather than on new UI.
2. The koperasi `BasketTray` drags up and down with the mouse.

---

## 0. Ask 2 is already built and merged

PR #65 (`feat/tray-fireworks-audio`) merged into `Textures` at 11:56 today,
and it contains exactly this:

- `BasketTray.classify_drag()` plus `begin_drag` / `update_drag` / `end_drag`
  (`59abde7`), driven from `Body`'s `gui_input` — the tray follows the pointer
  between docked and hidden, clamped to its dock, and the release settles by
  flick velocity (≥ 900 px/s) or the halfway point.
- `11d0780`, which is the reason it actually works: the handler was first
  written as `_gui_input` on the scene root, and that root is a bare anchor
  (`anchors_preset = 0`, no offsets) with a **zero-sized rect**, so it was
  never hit-tested and the gesture never fired. It moved to `Body`, which
  carries the geometry, and `TraySlot`'s root became `MOUSE_FILTER_PASS` so a
  press landing on an item reaches the drag surface too.

Mouse specifically is covered: the handler reads `InputEventMouseButton` and
`InputEventMouseMotion`. `project.godot` sets
`pointing/emulate_touch_from_mouse=true` and Godot's
`emulate_mouse_from_touch` defaults true, so finger and mouse both arrive.

**Gap: none in the mechanism.** The work here is verification — run the
koperasi suites on this branch and confirm they are green on the merged code.
If the drag is misbehaving in the running game, that is a different bug from
the one this spec would fix, and it needs a reproduction rather than a
rewrite.

---

## 1. What the player sees today

`BookClockWidget` is no longer a clock. It is the full-screen day-passing
cinematic behind SchoolDay: a square sky texture rotating about a pivot at the
school's ground line, and a stationary school-on-a-hill painted over it. It
already takes the weekday through `set_day(day_name)` and stores it in
`_day_name` — **and displays nothing**. `day_name()` exists purely so tests
can read it back.

The day information the player actually sees is `SchoolDay.tscn`'s `DayScreen`,
a plain top-left `VBoxContainer`:

| Node | Variation | Text |
|---|---|---|
| `DayNumberLabel` | `CaptionLabel` | "Hari 1 dari 5" |
| `DayLabel` | `H1Label` | "Senin" |

Two bare labels in a corner. No illustration, and **no week count at all** —
the player simulating a week has nothing on this screen telling them which
week of the grade they are in.

EventDialogue, by contrast, has a proper header (`EventDialogue.tscn`):

```
Header/
  DayBanner            Panel,       theme_type_variation = DayBannerPanel
    DayLabel           Label,       DayBannerLabel     "Senin"
  Calendar             TextureRect, calendar_badge.png
    Text               VBox,        separation = -10
      MingguLabel      Label,       CalendarLabel      "Minggu"
      WeekLabel        Label,       DayBannerLabel     "2/6"
```

filled by `open()`:

```gdscript
week_label.text = "%d/%d" % [week, max_weeks]
day_label.text = day_name
```

and called with `GameState.minggu_ke, GameState.get_max_weeks()`.

## 2. The change

`BookClockWidget.tscn` gains a `Header` of the same shape, using the **same
`ThemeFactory` variations** — `DayBannerPanel`, `DayBannerLabel`,
`CalendarLabel`. Same format means the same variations, not a lookalike built
from overrides; the project's rule forbids the overrides anyway.

Two differences from EventDialogue's header, both deliberate:

- **The illustration is `Assets/Images/UI/icon_daily_login.png`**, the tilted
  desk calendar the lobby's daily-login button wears — asked for by name.
  `calendar_badge.png` (flat, square, front-facing) stays EventDialogue's.
  Nothing new is drawn.
- **The text is rotated to sit on the paper.** See §3.

### API

`set_day(day_name)` keeps its signature and now writes the banner as well as
recording the name. One new method beside it:

```gdscript
## The week this day belongs to, as EventDialogue shows it: "Minggu 3/6".
## max_weeks is grade-scaled, so the same call reads 3/6 in Kelas 7 and
## 3/16 in Kelas 9 with nothing here to change.
func set_week(week: int, max_weeks: int) -> void
```

`reset()` clears both. `SchoolDay._run_single_day()` calls `set_week()` beside
its existing `set_day()`, from `GameState.minggu_ke` and
`GameState.get_max_weeks()` — the same two values EventDialogue is handed, so
the two screens can never disagree.

### Avoiding a doubled day name

With the banner showing "Senin", `DayScreen/DayLabel` shows it a second time a
few hundred pixels away. `DayLabel` is therefore **hidden**, not deleted:
`tests/test_school_day.gd` pins the node path `DayScreen/DayLabel`, and
deleting a node from a shipped scene to avoid a duplicate is a bigger decision
than this branch needs to make.

`DayNumberLabel` ("Hari 1 dari 5") **stays visible**. It is the day's position
*within the week*, which the header does not carry — the header is the day's
name and the week's position within the grade. Three facts, no repeats.

## 3. Drawing text on a tilted calendar

EventDialogue's badge is axis-aligned, so its `Text` VBox sits square on it.
The daily-login calendar is drawn in perspective: its paper is a parallelogram
rising to the right. Straight text on it reads as sliding off the page.

Measured from the art rather than eyeballed — a least-squares fit through the
first cream pixel in each of 48 columns across `icon_daily_login.png`
(317×385):

- **paper top edge slope −0.1579 → −8.97°**
- cream top edge spans x 79…267 px (0.25…0.84 of the width)
- full cream extent y 112…356 px (0.29…0.93 of the height)

So the `Text` container is rotated **−9°** and anchored inside the paper at
roughly `x 0.25…0.84`, `y 0.40…0.88` of the badge, with `pivot_offset` at its
own centre so the rotation does not shift it off the paper.

−9° is measured, but the *text box* inside the paper is still a judgement: the
paper has perspective as well as rotation, so a rotated rectangle can only
approximate it. Verified by screenshot at full size, not by eye at thumbnail
size — a 1px misalignment is invisible in a scaled capture.

## 4. Files

| File | Change |
|---|---|
| `Scenes/SchoolSimulation/BookClockWidget.tscn` | **new** `Header` — DayBanner + Calendar |
| `Scripts/SchoolSimulation/BookClockWidget.gd` | `set_week()`; `set_day()` writes the banner |
| `Scenes/SchoolSimulation/SchoolDay.tscn` | `DayScreen/DayLabel` hidden |
| `Scripts/SchoolSimulation/SchoolDay.gd` | calls `set_week()` |
| `tests/test_book_clock_phases.gd` | header, format, rotation |
| `tests/test_school_day.gd` | the hidden label |

No new art, no new `ThemeFactory` variation, no rebake.

## 5. Grades 7/8/9

The only grade-scaled thing here, and it needs no code: `get_max_weeks()`
returns 6 / 12 / 16 for Kelas 7 / 8 / 9, so the badge reads "Minggu 3/6" in
Kelas 7 and "Minggu 3/16" in Kelas 9 from the same call. Worth a test per
grade, because a hard-coded 6 would pass every Kelas 7 test and be wrong for
two thirds of the game.

## 6. State across the bridge

None. This branch reads `GameState.minggu_ke` (an int) and
`GameState.get_max_weeks()` and writes two Labels. It never touches
`approved_students` or `StudentData`, so the `akademis2` (seni_budaya) /
`kepribadian1` (mood) naming trap does not apply.
