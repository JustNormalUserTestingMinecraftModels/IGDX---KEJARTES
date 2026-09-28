# Settings layout — Inventory-style redesign

**Date:** 2026-09-28
**Branch:** `feat/settings-layout`
**Screen:** `Scenes/UI/Settings.tscn`, `Scripts/UI/Settings.gd`

## Why

Settings is the one screen reachable from the Lobby that does not look like its
siblings:

- It sits on `UI/BG.jpg`, the cutscene sky. Achievements, Inventory and ShopHub
  sit on a blurred picture of a room.
- Its title is a plain `H1Label`, and its `KEMBALI` button is the last item of
  the list rather than pinned chrome.
- Its body is seven loose `Card`s, six of them holding a single switch, with no
  grouping and no scroll. On a tall phone the stack floats at the top.
- Its switches and sliders are **unthemed**: `kejartes_theme.tres` has no
  `CheckButton` or `HSlider` entry, so they draw Godot's defaults — a ~42px
  grey switch and a ~16px slider grabber on a 1080px-wide screen.

## Decisions (settled with the user)

| Question | Decision |
|---|---|
| Sibling screen to match | **Inventory** — full-bleed header `Card` with the back button and a `DisplayLabel` title |
| Backdrop | **Blurred Lobby**, `Assets/Images/UI/blur_background.png` (already used by AturJadwal, ResultCheckup) |
| Body | **Three titled section cards**: SUARA / PERMAINAN / TAMPILAN, inside a `ScrollContainer` |
| Switches and sliders | **Brand-styled** (mockup option B), via new `ThemeFactory` variations |

## Layout

```
Settings (Control, full rect, theme = kejartes_theme.tres, script Settings.gd)
├─ Background    TextureRect · blur_background.png · Full Rect, expand_mode 1,
│                stretch_mode 6 (Keep Aspect Covered)
└─ SafeArea      MarginContainer · Full Rect · SafeAreaMargin.gd · margins 0
   └─ MainColumn VBoxContainer · separation 0
      ├─ Header  PanelContainer [Card]
      │   └─ HeaderCol  VBoxContainer · separation 18
      │       ├─ Row  HBoxContainer
      │       │   └─ BackButton  Button [SecondaryButton] · "Kembali"
      │       │                  · icon return_button.png · min height 96
      │       │                  · size_flags_horizontal 0
      │       └─ TitleLabel  Label [DisplayLabel] · "PENGATURAN"
      └─ Body    MarginContainer · margin_left/right/top/bottom 48
                 · size_flags_vertical 3 (expand, takes the rest)
         └─ Scroll  ScrollContainer · horizontal scroll disabled
            └─ Sections  VBoxContainer · separation 32 · size_flags_horizontal 3
               ├─ AudioCard     PanelContainer [Card]
               ├─ GameplayCard  PanelContainer [Card]
               └─ DisplayCard   PanelContainer [Card]
```

This is Inventory's header (`MainColumn/Header/HeaderCol/Row/BackButton`, the
`DisplayLabel` title under it) minus the coin pill. Settings is also reached
from MainMenu, where money means nothing. It keeps the `SafeAreaMargin` wrapper
the screen already has, so the header clears a notch.

### The three section cards

Every card: `PanelContainer [Card]` → `Margin` (MarginContainer, 24 left/right,
20 top/bottom — the current cards' values) → `VBox` (separation 12) holding a
`SectionLabel` (`Label [CardSectionLabel]`), then its rows with an
`HSeparator [SettingsDivider]` between consecutive rows.

| Card | SectionLabel | Rows, in order |
|---|---|---|
| `AudioCard` | `SUARA` | `MasterRow` Suara Utama · `BgmRow` Musik · `SfxRow` Efek Suara |
| `GameplayCard` | `PERMAINAN` | `TutorialRow` Tutorial Minigame · `SkipDialogRow` Lewati Dialog Minigame |
| `DisplayCard` | `TAMPILAN` | `LookLayerRow` Efek Visual · `AmbientRow` Efek Suasana · `ReduceMotionRow` Kurangi Gerakan · `HapticsRow` Getaran (Haptic) |

The slider rows keep today's shape and names: `MasterRow` (VBoxContainer) →
`MasterLabel` [BodyLabel] + `MasterSlider` (HSlider, `unique_name_in_owner`),
and likewise `Bgm*` and `Sfx*`. Each slider gets `theme_type_variation =
&"SettingsSlider"`.

At 1080×1920 the header plus all three cards measure about 1,580px, so on 9:16
and taller the list fits with no scrolling. The `ScrollContainer` is there for
very short screens.

## The switch row template

Six rows have the same shape, so they become one `PackedScene` (CLAUDE.md
"repeated rows are a PackedScene template"):

**`Scenes/UI/SettingsToggleRow.tscn`**

```
SettingsToggleRow  HBoxContainer · script SettingsToggleRow.gd · min height 80
├─ Label   Label [BodyLabel] · size_flags_horizontal 3 · vertical_alignment 1
└─ Toggle  CheckButton [SettingsSwitch] · size_flags_vertical 4
```

**`Scripts/UI/SettingsToggleRow.gd`** — `@tool`, `extends HBoxContainer`,
`##` file header.

- `@export var label_text: String` (`##`-documented). Its setter writes
  `$Label.text` when the node is ready, and `_ready()` applies it, so the
  editor shows the real label. The export is on the **root** because overrides
  on an instance's children are dropped on save (CLAUDE.md 4b).
- `var toggle: CheckButton` — an `@onready` reference to `$Toggle`. `Settings.gd`
  wires the switches, so the row stays generic.
- No other logic, and no runtime node construction.

`Settings.tscn` instances it six times, named as in the table above, each
with `unique_name_in_owner = true` and its `label_text` set.

## Theme: `SettingsSwitch`, `SettingsSlider`, `SettingsDivider`

`ThemeFactory` stays pure (no file I/O), so the three textures come through
`DesignTokens` the way fonts do:

**`DesignTokens.gd`** — three new `##`-documented exports, each defaulting to a
`preload` of its file (the `font_body_bold` pattern):

| Export | File (new, real transparent SVG) | Drawn size |
|---|---|---|
| `settings_switch_on` | `Assets/Images/UI/Settings/switch_on.svg` | 112×64, `state_success` #35A05A pill, `surface_card` #FFFDF8 knob on the right |
| `settings_switch_off` | `Assets/Images/UI/Settings/switch_off.svg` | 112×64, `surface_sunken` #EFE0CB pill, #FFFDF8 knob on the left |
| `settings_slider_grabber` | `Assets/Images/UI/Settings/slider_grabber.svg` | 56×56, #FFFDF8 disc, 6px `brand_primary` #7A4A2B ring |

**`ThemeFactory.gd`** — a new `_build_settings(theme, tokens)`, called from
`build()`, with a `##` block comment in the file's style:

- `SettingsSwitch` (variation of `CheckButton`): icons `checked` and
  `checked_disabled` get `settings_switch_on`, and `unchecked` and
  `unchecked_disabled` get `settings_switch_off`. The `normal`, `hover`,
  `pressed`, `hover_pressed`, `focus` and `disabled` styleboxes are all
  `StyleBoxEmpty`, because the row's `Label` carries the text and the button
  should draw only the switch.
- `SettingsSlider` (variation of `HSlider`):
  - `slider` (the track) is a `StyleBoxFlat`, `surface_sunken`, 20px thick
    (content margins 10 top and bottom), `radius_pill`.
  - `grabber_area` and `grabber_area_highlight` (the filled part) are the
    same shape in `brand_primary`.
  - Icons `grabber`, `grabber_highlight` and `grabber_disabled` get
    `settings_slider_grabber`.

- `SettingsDivider` (variation of `HSeparator`): `separator` is a
  `StyleBoxLine`, `surface_sunken`, 2px thick. It is the rule between rows in
  the mockup. Without it, the separators draw the default grey line.

None of the three holds text, so none joins `DISPLAY_ROSTER`. Rebake with
`BakeTheme.gd` after the change. A new Resource `@export` needs a **full editor
restart** before the rebake and before any test reads it (CLAUDE.md "Editing a
`class_name` script").

## `Settings.gd` changes

Behaviour does not change: the same saves, the same `return_scene`, the same
`titlescreen` music, the same Android back handling. Only the node references
move:

```gdscript
@onready var _tutorial: CheckButton = %TutorialRow.toggle
@onready var _skip_dialog: CheckButton = %SkipDialogRow.toggle
@onready var _look_layer: CheckButton = %LookLayerRow.toggle
@onready var _ambient: CheckButton = %AmbientRow.toggle
@onready var _haptics: CheckButton = %HapticsRow.toggle
@onready var _reduce_motion: CheckButton = %ReduceMotionRow.toggle
```

The sliders and `%BackButton` keep their unique names. `_collect_rows()`
becomes `_collect_cards()`, returning `%Sections`' three children, so
`Juice.stagger_in` brings the cards in one by one. `%Layout` goes away, and
`Sections` takes `unique_name_in_owner`.

## Tests

| Suite | Change |
|---|---|
| `test_settings` | The slider tests pass unchanged. `TutorialToggle` is looked up as `find_child("TutorialRow")` and then `.toggle`. New tests: the three cards exist under `Sections` in order, with the rows listed above in order; `Background.texture` is `blur_background.png`; a `ScrollContainer` sits between `Body` and `Sections`; `TitleLabel` uses `DisplayLabel`. `test_scene_has_no_theme_overrides` stays and now also walks the row instances. |
| `test_back_controls` | The Settings roster path becomes `SafeArea/MainColumn/Header/HeaderCol/Row/BackButton`, still checked through `icon`. |
| `test_theme_factory` | New: `SettingsSwitch`, `SettingsSlider` and `SettingsDivider` are variations of `CheckButton`, `HSlider` and `HSeparator`; their icons are the token textures; the switch's styleboxes are all `StyleBoxEmpty`. |
| `test_tall_screen_layout` | New Settings block, following the suite's per-screen pattern: the backdrop fills at 1080×2400, the header is pinned to the top of the safe area, `Body` grows to take the extra height, and the design size is unchanged. |
| `test_script_documentation` | Covers `SettingsToggleRow.gd` automatically (file header plus `##` on its export). |
| `test_viewport_editability` | Nothing new is built at runtime, so `BASELINE` and `ALLOWED` do not change. |
| `test_shorten`, `test_device_back_button`, `test_audio_coverage` | Unaffected: they scan `Settings.gd` for strings that survive. |

## Docs

- `DEBT.md`: `UI/BG.jpg`'s note drops "and Settings" (it becomes CutScene
  only). Add a placeholder entry for the three `UI/Settings/*.svg` files,
  which are drawn by us, not the artist.
- `CHANGELOG.md`: one entry when the pass lands.

## Out of scope

- No new settings, no change to `GameSettings`, and no change to what any
  switch does.
- No coin pill in the header.
- Other screens that happen to use a `CheckButton` or `HSlider` keep the
  default look. The variations are opt-in by name.
