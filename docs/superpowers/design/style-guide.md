# UI Style Guide

This is the reference for anyone touching visuals in this project after the
core-ui-polish pass (Tasks 0-18). It covers how the design system is
structured, how to change it safely, and the one rule that keeps it that way.

Scope: the 10 core screens (Splashscreen, Loading, MainMenu, CutScene,
StudentCard, Lobby, AturJadwal, StudentList, SchoolDay, SemesterEnd) plus the
Settings screen added in Task 18. **Minigames (`Scenes/Minigames/**`) are
explicitly out of scope** — they inherit the Theme automatically but have not
had a dedicated juice/layout pass.

## Changing a color, radius, or font globally

Everything visual flows from one resource: `Assets/Theme/design_tokens.tres`
(a `DesignTokens` resource — see `Scripts/Design/DesignTokens.gd` for every
exported field: brand colors, category colors, spacing scale, radii, shadow,
outline widths, font slots/sizes, text colors, etc).

To change something globally:

1. Open `design_tokens.tres` (`Assets/Theme/design_tokens.tres`) in the Godot Inspector (select it in the
   FileSystem dock) and edit the field directly — e.g. `brand_primary`,
   `radius_pill`, `space_md`, `font_body`.
2. Rebake the Theme resource from the edited tokens: open
   `Scripts/Design/BakeTheme.gd` in the Script editor and run it with
   **File > Run** (or the "Run current script" shortcut, Ctrl+Shift+X). This
   calls `ThemeFactory.build(tokens)` and saves the result over the shared
   `Theme` resource every scene references.
3. Re-open any scenes you have open in the editor (or just re-run the game)
   to see the new values — Godot caches the Theme in memory per open scene.

No scene file, script, or `.tscn` needs to change for a token edit to take
effect everywhere. That's the point of the system.

## Theme variations (`Scripts/Design/ThemeFactory.gd`)

`ThemeFactory.build()` produces one `Theme` with named type variations. Use
the existing variation that matches intent rather than styling a node by
hand. As of this pass:

**Buttons** (`theme_type_variation` on a `Button`). Since the 2026-09-28 UI depth pass every framed button is a lipped face
built by `Scripts/Design/LippedBox.gd` from a plain `StyleBoxFlat`: a face
on a solid darker lip (the box's drop shadow, in a strip freed by a
negative `expand_margin_bottom`) with a soft gloss along its top (a blended
top border), sinking onto the lip when held (`expand_margin_top`), with no
rim. It is native on purpose: the theme loads before the SceneTree exists,
and a script-backed StyleBox there makes every debug run log a SceneTree
error. Its colours say its role — mint is the main
action and affirm on every screen, tomato is danger, brown is neutral
(a cream button vanishes on the cream cards and paper of most screens, so
StudentCard's secondary buttons and the filter chips are brown; cream stays
for the skin tiles' photo cards and the minigame answers, whose scene authors
the box); sky and sunflower belong
to the Lobby tiles and the
notebook tabs, and sunflower is never an action (gold reads as "buy").
A Back is a return, so it is brown, not mint (ReportCard's included); a
routine, reversible clear beside the main action is brown too, never
tomato (the minigames' Hapus beside a mint Kirim). The one exception is a
screen whose only way forward is "back": SchoolDay's end-of-week
"Kembali ke Menu" and RunResult's single CTA are that screen's main action,
so they stay mint.
Information badges keep their meaning colours. The palette pairs are the
`accent_*` / `button_cream*` tokens. Labels on a dark face are outlined
white; on a light face they are plain dark ink. `EventSelectCard` stays a
flat box, because its pressed state means *selected*.

The Lobby's scrapbook buttons (`BookHeroButton`, `NavTileKoperasi`/`Inventory`/
`Rapor`, `PlusButton`) wear the same role palette; the hero and the three
tiles also get a thicker lip (`ThemeFactory.LOBBY_HUD_LIP`).

**Panels**:
- `Card` — the standard raised surface (white bg, border, shadow).
- `SunkenPanel` — an inset/recessed surface (e.g. a text well).
- `Scrim` — a translucent full-screen dim behind a modal/dialog.
- `CoinPlate` / `ProgressPlate` — the Lobby header's cream 9-slice plates
  (the wallet display and the grade/week/star strip).
- `GradeBadge` — the header's flat "KELAS 7" chip.
- `BookCoverPanel` / `BookPagePanel` — the stepped book's board and page,
  9-sliced.
- `NotifBadge` — the icon rail and nav tiles' small red count pill
  (`NotifBadgeLabel` for its digit/mark text).
- `RosterChip` — the book's "N murid" pill.
- `ResultTitlePanel` — the weekly report's brown "HASIL MINGGUAN" title plate
  (`KoperasiSignPanel`'s recipe). `DeltaChipGain` / `DeltaChipLoss` — the weekly
  report's change chips, `state_success` / `state_danger` pills.

**Labels**:
- `DisplayLabel` — largest heading, outlined, uses the display font.
- `H1Label` — outlined, large.
- `H2Label` — large, no outline.
- `TitleLabel` — button/section-title size.
- `CaptionLabel` / `MicroLabel` — secondary, smaller text.
- `BarLabel` — text drawn directly on a `StatBar` fill (light text, thinner
  dark outline than `DisplayLabel` so it doesn't swallow small text).
- `ResultHeroLabel` / `ResultBodyLabel` — light-on-dark variants, made for
  SemesterEnd's dark backdrop and outliving it. They need a **dark ground**:
  `ResultBodyLabel` is cream and all but vanishes on a `Card`.
- `RunResultNameLabel` — dark body text on a light `Card` at the phone step
  (`font_body_size + 8`): the name beside each figure in RunResult's report.
- `ResultCardBodyLabel` — dark caption-size text on the minigame result card
  and its sunken stat panel: the minigame's name, and "Skor:".
- `ScoreHudComboLabel` — dark caption-size text on the score HUD's light
  combo chip. The HUD's `TargetLabel` beside it stays on `ResultBodyLabel`:
  it sits on the dark translucent pill itself.
- `ResultDeltaLabel` — white caption text with a 4px dark (`text_primary`)
  outline, made to be tinted: callers colour-code it through `self_modulate`
  (the result card's green gain and red loss, the apply-item preview's
  `state_success`). The tint multiplies the outline too but cannot lighten
  it, so on a light ground the rim carries the text; untinted, it reads as
  white letters with a dark edge. Keep the base white: a dark base would
  crush the tint to near-black.
- `ResultTitleLabel` — cream display letters on `ResultTitlePanel`.
  `DeltaChipLabel` — the white number on a change chip.

**Progress**:
- `StatBar` — the mood/energy/skill bars. Fill renders white so callers tint
  per-category via `self_modulate` rather than needing per-stat styleboxes.
- `WeekEnergyBar` / `WeekMoodBar` — the weekly report's needs bars, in the
  game-wide `cat_energy_on_dark` / `cat_mood_on_dark`; the nightly popup keeps
  `DaySummaryEnergyBar` / `DaySummaryMoodBar`.

Unstyled `Label`, `Button`, and `Panel` nodes (no variation set) still get a
sane themed default from `_build_base_overrides` — so a bare `Button` dropped
into a scene never renders as flat Godot gray.

**If a screen needs a style that doesn't exist yet**: add a new variation
function in `ThemeFactory.gd` (following the existing `_add_button_variation`
/ label-spec patterns), rebake, and use it by name. Do not reach for a
per-node `theme_override_*` (see The Rule, below).

## Illustration materials

**Illustration plates wear one of two materials.** Cutouts take
`illustration_grade_cutout.tres` (grade + inner AO + rim); full-bleed backdrops
take `illustration_grade_material.tres` (grade only), because a backdrop has no
alpha edge and would pay five texture taps per pixel for nothing. Which is
which is pinned by `tests/test_illustration_ao.gd`'s census, measured from each
texture's alpha. The Lobby is lit from the upper right, the rest of the game
from the upper left: its desks wear `illustration_grade_cutout_lobby.tres` and
its faces `illustration_grade_face.tres`, both kept equal to the cutout except
`light_dir`. Tune them, the Lobby's shafts and its WorldEnvironment bloom live
from the debug overlay's **Look** page, then write the landed value into the
`.tres`. That bloom reaches only canvas layers ≤ −1: the room lives in the
Lobby's `World` CanvasLayer, and UI stays on layer 0, out of the glow.

**The Lobby look on other screens** (spec
`docs/superpowers/specs/2026-09-28-lobby-look-everywhere-design.md`): the
backdrop and its light move into a `World` CanvasLayer at −1 holding one
`Room` Control; the light is a `LightPool` plus a full-screen `SunShafts`
(`Scenes/Look/SunShafts.tscn`); the blurred shops (and, in later passes, the
exam notices) add a flat `ParallaxDiorama`. Koperasi's `World` holds its wall
strip and a `Room` that mirrors `Stage`'s bottom-pinned 1080x1920 rect: the
backdrop, light, Pak Herman and the counter bloom there, while the goods and
every piece of shop UI stay on `Stage`; minigames keep their backdrop on
layer 0.
**Bloom off the Lobby.** A screen with a `World` layer (ShopHub, CosmeticShop,
Koperasi, the end-game screens) carries the Lobby's own bloom: an
`AmbientGlow` named `Glow`, second in the root, whose defaults are
`lobby_environment.tres`'s values. It blooms layer −1 only, so the UI stays
crisp. A screen whose art shares layer 0 with its UI (every minigame) cannot
take it: it blooms whole layers, and measured, it washed Koperasi's text out
before Koperasi's room moved to `World`. Those carry a `ScreenGlow` named `Bloom` right after
their light, which reads only the art drawn before it; thresholds and its 0.8
intensity are pinned in `tests/test_lobby_look.gd`. Measure an Environment
glow in the running game, never in an offscreen `SubViewport`, where it does
not render at all.

## Swapping fonts

See `Assets/Fonts/README.md` for the exact procedure (font files live there;
`DesignTokens.font_body` / `font_display` are `FontFile` export slots — point
them at a new file and rebake).

## Filling or swapping audio

See `Assets/Audio/README.md`. Bus/SFX/BGM slots are defined on
`AudioDirector` and are currently silent placeholders (BGM tracks are
explicitly deferred — "a stronger authorship choice than SFX").

## The notebook frame

Popups sit in `Scenes/UI/NotebookFrame.tscn`: drop your content in as
children of the frame and it lays them into the page. Set `title_text`,
`tabs` (up to three), `ring_count`, `show_well`, `show_tape` and
`show_close` on the instance's root, and listen to `tab_selected` /
`close_pressed`. The ring, rule and sticker textures are placeholders
(`Assets/Images/UI/Notebook/README.md`). All 17 popups now use it;
`tests/test_popup_frames.gd` is the roster — a new popup adds its row there.

**The three kinds:**

- **dialog** — `tabs` empty, `ring_count = 4`, `show_well = false`.
- **sheet** — `tabs` empty, rings and well at their defaults unless a row
  says otherwise.
- **tabs** — `tabs` set (Settings is the only one).

**Host recipe.** A centred popup is
`SafeAreaMargin → CenterContainer → Frame`; a full-height one drops the
`CenterContainer` and puts the frame straight under `SafeAreaMargin`. `Safe`
and `Center` ignore taps (`mouse_filter = 2`) so a tap on empty space still
reaches the popup's scrim; the frame's own root stops taps, so a tap on the
page never dismisses it. `Chrome/Cover` sticks out past that rect (12px left,
20px right, 24px down) and passes taps (`mouse_filter = 1`) rather than
ignoring them, so a tap on its overhang also reaches the frame root instead
of falling through to the scrim. `DaySummaryPopup` is the deliberate
exception to "a tap on the page never dismisses": it dismisses on a tap
anywhere, including the page.

Two placement popups sit outside this recipe and stay positioned by their
screen: `OpenAmplopConfirm`, whose letter tweens `position` (a container
would undo that), and the Lobby's `DailyLogin`, whose frame sits behind the
calendar art. `TutorialPanel` is placed by each caller.

**Closing.** Delete the popup's own ✕ or Tutup control (its node, its
`@onready`, its `connect`) and wire the frame's `close_pressed` to the
function that button called. The frame's own ✕ (`show_close`) shows only
where it adds nothing new — where it would mean the same as an existing
Batal/Tidak, or the popup already closed on a tap elsewhere — and stays
hidden where the player must decide (`EventStudentSelectDialog`) or the flow
is forced (`DailyDecayOverview`, `TesNotice`, `StatCheck`, `TutorialPanel`).

**Titles.** The sticker carries a short fixed word (`PENGATURAN`,
`STATISTIK`, `PERINGATAN`, …) and widens to fit it; it hides entirely when
`title_text` is empty. A popup's dynamic heading — a stat name, an event
name, a step title — stays in the host content, not the sticker.

**Three traps found while migrating popups into the frame:**

- The baked theme gives every `MarginContainer` 48px margins
  (`screen_margin`). A `MarginContainer` used only as a plain wrapper around
  a frame's host content must zero its `margin_*` overrides, or the content
  measures wider than the frame and layout tests fail against a
  hard-coded screen width (`TutorialPanel`'s root does this).
- A label moved onto the frame's cream page needs dark ink, not the pale
  ink it wore on a dark scrim (`TesNotice`'s body moved from
  `ResultBodyLabel` to `EventBodyLabel`).
- A dialog's own buttons belong inside the frame's host content, not
  positioned against the old (smaller) box — `OpenAmplopConfirm`'s
  Batal/Terima moved into `Letter/VBox` once the taller frame started
  overlapping them.

## Icons

**One picture per job, from `Assets/Images/UI/Icons/`** (placeholders for
the owner's chunky set, drop-replaceable at the same path; the folder's
README has the replacement rules and the full "where each icon is used"
table). The Lobby's five nav tiles wear `nav_*`; every paging arrow
(LevelSelect, StudentCard, StudentList, ReportCard) wears `chevron_left` /
`chevron_right`; MainMenu's Quit wears `exit`; the notebook frame's ✕ wears
`close`; and the two categories with no stat of their own wear
`cat_istirahat` / `cat_wirausaha` wherever a screen names them (the roster
card's chip, the day notes, Dapatkan Uang's tip). A paging arrow draws its
chevron as a child `Arrow` `TextureRect` (full rect, 24 px inset,
unrotated, taps ignored), not as the Button's `icon`: the lipped buttons'
content margins squeeze an icon to about 15 px. `Scripts/UI/ButtonGlyph.gd`
on the child makes it act like an icon, sinking while held and dimming
while disabled; give any future picture-on-a-button child the same script. **Back is not a chevron:**
every Back keeps `UI/Nav/return_button.png`, the arrow unified on
2026-09-22 (`tests/test_back_controls.gd`). The four Lobby rail icons
(settings, achievements, daily login, skins) are finished art and stay
where they are.

**No emoji or dingbats in UI text.** A pictograph typed into a label
renders in whatever emoji font the phone has, at the wrong weight and
colour; a picture is a texture from `Icons/` (or a placeholder SVG) on a
`TextureRect` or a Button's `icon`. Banned: U+2300–23FF, U+2600–27BF,
U+2B00–2BFF, U+1F000–1FAFF and U+FE0F. Typography stays allowed: the
Arrows block (`12 → 9`), `×`, and anything in a code comment.
`tests/test_ui_text_glyphs.gd` scans every `.tscn` and `.gd` under
`Scenes/` and `Scripts/` (minigames and the debug overlay excepted, both
outside the design system); its `ALLOWED` dict is the reviewed list of
exceptions, and a new one needs a comment saying why.

## The Juice API (`Scripts/Design/Juice.gd`)

Static helpers for consistent motion feel. All read shared timing/easing from
`Juice.tokens()` (a `DesignTokens` accessor also used by `StatBar` and
`Transition`).

| Method | One-line example |
|---|---|
| `Juice.set_pivot_center(node)` | `Juice.set_pivot_center(my_button)` — center a Control's pivot before scaling it. |
| `Juice.press(node)` | `Juice.press(button)` on `button_down` — quick squash toward the pivot. |
| `Juice.release(node)` | `Juice.release(button)` on `button_up`/`pressed` — spring back to scale 1. |
| `Juice.pop_release(node)` | `Juice.pop_release(button)` on release of a lipped button: its pressed stylebox already sank it, so it bumps to `release_pop_scale` and settles. |
| `Juice.pop_in(node, delay)` | `Juice.pop_in(card, 0.1)` — scale-and-fade a Control in, optionally staggered. |
| `Juice.fade_in(node, delay)` | `Juice.fade_in(icon)` — plain alpha fade for a `CanvasItem`. |
| `Juice.stagger_in(nodes, step)` | `Juice.stagger_in(get_children())` — `pop_in` each node in sequence. |
| `Juice.count_up(label, from, to, fmt)` | `Juice.count_up($MoneyLabel, 0, 1500, "Rp%d")` — animate a number tick-up. |
| `Juice.fill_bar(bar, to, duration)` | `Juice.fill_bar($StatBar, 80.0)` — tween a `Range`/`ProgressBar` value. |
| `Juice.shake(node, strength)` | `Juice.shake(panel, 18.0)` — a denial/error shake. |

Buttons are auto-juiced (press/release wiring) by `UIPolish` when the scene
loads — most screens never call `Juice.press`/`release` directly. Lipped
buttons sink through their pressed stylebox and pop on release (`PressFeel`
decides, per button), other and flat buttons keep the shrink, and the
main-action roles tick the motor (`PressFeel.MAIN_ACTION_ROLES`, 8 ms,
honouring Getar).

## The rule: never add a `theme_override_*`

Per-node `theme_override_*` properties on a scene bypass the Theme entirely —
they can't be changed by editing tokens, they don't rebake, and they silently
drift from the rest of the game. **Do not add new ones.**

The one accepted exception, already present in a few scenes
(`Scenes/SchoolSimulation/SchoolDay.tscn`, `Scenes/UI/Settings.tscn`), is
**layout-only constant overrides** — `separation`, `margin_left/top/right/
bottom` — for spacing that is specific to one container's local layout rather
than a global rhythm. These carry no color or font information and don't
fight the Theme. A `theme_override_colors/*`, `theme_override_font_sizes/*`,
or `theme_override_styles/*` on a scene is always a regression: add or reuse
a `ThemeFactory` variation instead, and rebake.

## Opting a button out of auto-juicing

`UIPolish` wires press/release juice onto every `Button` it finds during
scene setup. To exclude a specific button (e.g. one that already has custom
animation, or one that must never scale-bounce):

```gdscript
my_button.set_meta(Juice.NO_AUTO_JUICE, true)
```

Set this before `UIPolish` processes the scene (e.g. in `_ready()` before
`super._ready()` if the base class wires juice there, or immediately after
instancing the button).

## Known constant-override exceptions (Step 2 verification)

The zero-`theme_override_*` grep across the 10 core scenes plus Settings
found exactly two files with non-zero counts, both exclusively
`theme_override_constants/separation` and `margin_*`:

- `Scenes/SchoolSimulation/SchoolDay.tscn` — 2 occurrences (container
  separation local to that screen's layout).
- `Scenes/UI/Settings.tscn` — 14 occurrences (separation/margin on the
  settings list and its rows).

No color, font-size, or stylebox overrides were found in either file — both
fall under the accepted layout-only exception above.

## `@tool` and `Engine.is_editor_hint()` for MCP-testable scripts

Any script that the in-editor MCP test runner needs to instantiate live
(i.e. a test adds an instance of it to a live tree) must be `@tool`. Without
it, Godot silently replaces the instance with an uncallable placeholder when
it's created inside the editor process — even ordinary method calls fail
with a "placeholder instance" error, and the test can't exercise anything.

But `@tool` has a cost: it makes `_ready()` run for real the moment a human
just opens that scene or resource in the editor, not only during actual
play. Any *real* side effect in `_ready()` — reading or writing another
autoload's state, playing audio, kicking off a gameplay-only animation
sequence, mutating save data — must therefore be gated behind
`if Engine.is_editor_hint(): return` (or an inline check) so it never fires
just from opening the scene. Pure UI wiring (connecting signals, reading
initial display values) should stay *above* that guard, ungated, since the
test suite needs to exercise exactly that wiring.

- See `Scripts/MainMenu/MainMenu.gd` for the worked "gated" example: it's
  `@tool`, button-signal wiring runs unconditionally, and BGM/entry
  animation are gated behind `Engine.is_editor_hint()`.
- See `Scripts/UI/UIPolish.gd` for the worked "correctly needs no `@tool`"
  example: its `_ready()` can only ever run during a real `project_run`
  (nothing instantiates it live from the editor process), so there's no
  placeholder risk and nothing to gate.

## Out of scope (deferred, not this pass)

See the plan's task briefs for the full list — in short: minigames, haptic
vibration, BGM tracks, localization, landscape/tablet layouts, and custom
9-slice/icon art. None of these are regressions; they're documented,
intentional deferrals.
