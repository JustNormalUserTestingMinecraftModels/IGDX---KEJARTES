# UI Depth Pass — Design

**Date:** 2026-09-28
**Status:** approved in brainstorm and spec review (revised the same day: the scrapbook Lobby is kept and harmonised, and green is the main-action colour)
**Mockups:** `docs/superpowers/specs/mockups/ui-depth-pass/`. Each is a standalone HTML file; open it in any browser.
- `1-palette-and-lobby.html`: the palette, the button family, and three Lobby options. These are **superseded for the Lobby** by the mentor-approved scrapbook HUD; see Decisions.
- `2-button-rim.html`: rim or no rim (column 2 chosen: no rim, outlined text).
- `3-notebook-frame.html`: the chosen popup frame, as a sheet with tabs and as a dialog.
- `4-press-feel.html`: the press demo (B, sink onto the lip, chosen).

## Why

The game's UI reads flat next to typical mobile games. Every button and panel is a single-colour `StyleBoxFlat` with a soft blurred shadow, so everything looks like a sticker. Almost every control is the same brown on cream, so nothing leads, and the Lobby's nav icons are thin white glyphs.

The owner's three references share a handful of traits:
- a solid darker **lip** under every button
- a **gloss** band on top
- **colour that means something** (go, back, danger)
- **punchy outlined lettering**
- **built frames** with plaques or tabs
- **chunky filled icons**

This pass gives KejarTes those traits while keeping its identity.

## Decisions

| Topic | Decision |
|---|---|
| Anchors | Brown (`brand_primary` family) and cream (`surface_*`) stay the anchor colours. |
| Accents | Sampled from the references. Each accent is a gloss / base / lip trio (table below). |
| Buttons | **No cream rim.** Depth comes from the lip plus a gloss band. White display text, outlined and hard-dropped in the button's lip colour. On cream buttons the text is brown with no outline. |
| Lobby | **Keep the mentor-approved scrapbook HUD** (`2026-09-27-lobby-scrapbook-hud-design.md`, live on `Textures`): its book, layout, washi-taped tiles, header plates and the four rail icons stay. This pass only **harmonises** it. Its buttons get the lipped stylebox and outlined lettering; its tile hues keep their meaning but take the palette's tones (JADWAL! and Koperasi mint, Inventory sky, Rapor sunflower); and its tiles' thin nav icons move to the new icon paths. The rail icons (`setting.png`, `achievement_button.png`, `icon_daily_login.png`, `skin_switch.png`) are finished assets and are not touched. |
| Popup frame | **Notebook:** brown hardcover with a lip, a cream ruled page with two paper edges and a red margin line, chunky spiral rings through punched holes, lipped tabs, a stitched sticker title, controls in a sunken well, torn-end washi tape, and a round tomato ✕. A dialog is the same frame with fewer decorations. |
| Press | **Sink onto the lip:** the face drops by the lip height on touch, then gets a small pop on release. Buttons without a lip keep today's shrink. |
| Haptics | A ~10 ms tick on press, for **main-action roles only**. It respects the existing Getar setting. |
| Sound | The existing tap SFX on every button, unchanged. |
| Icons | The owner supplies a chunky set later. Placeholders are drawn now at fixed paths and swapped in with no code change. |
| Scope | The theme changes everywhere. The notebook frame and icons are hand-fitted on **all core screens and popups**. Minigames get only the automatic theme change. |
| Build approach | **Hybrid.** Lipped faces built in code (`LippedBox`, native `StyleBoxFlat`) for everything that recolours and resizes; small drop-replaceable textures only for the notebook's illustration pieces. |

### Palette

| Name | Gloss | Base | Lip | Role |
|---|---|---|---|---|
| Mint | `6BE3BB` | `2EC99A` | `178A68` | **The main action and affirm, everywhere** (`PrimaryButton`, `LobbyCtaButton`, `BookHeroButton`, `SuccessButton`: Terima, Lanjut; the coin `+`), toggles on, the Koperasi tile |
| Sunflower | `FFE07A` | `FFC93C` | `C9801A` | **Highlight only, never an action:** the active tab, stars, coins, rewards, the Rapor tile. Gold on a button reads as "buy currency" (scrapbook spec §3). |
| Sky | `8CC2F5` | `5EA1E6` | `3469B3` | Info, inactive tabs, slider knobs |
| Tomato | `F58A72` | `E5553E` | `A3301E` | Danger and close (`DangerButton`, the ✕) |
| Tangerine | `FFB36A` | `F58A3C` | `BD561A` | Koperasi badge, secondary warm accent |
| Brown | `B87A52` | `9C6440` | `56321B` | Back and neutral (`SecondaryButton`), notebook cover |
| Cream | `FFFFFF` | `FFF1DC` | `C9A57E` | Nav tiles, Batal (`StudentCardSecondaryButton`) |

The stat categories already own blue (Akademis), red (Olahraga), green (Seni) and teal (Wirausaha). So colour is spent only on the action roles above, never as full-candy button rows. The Lobby's colour-coded tiles are the one approved exception.

## Architecture

### 1. Lipped faces (`LippedBox`, native `StyleBoxFlat`)

`Scripts/Design/LippedBox.gd` is a static helper that builds the look from a plain `StyleBoxFlat`. It is **not** a script-backed StyleBox, because the project theme loads at startup before the SceneTree exists, and any script in it makes every debug run log a SceneTree error. That was found and fixed during Phase 1.

The three parts:
- **Lip:** the box's drop shadow in the lip colour, 1 px soft, offset down by `lip_height` into the strip a negative `expand_margin_bottom` frees under the face.
- **Face:** `bg_color` with the corner radius. There is no soft drop shadow any more; the shadow is the lip.
- **Gloss:** a blended top border (`border_width_top` = `LippedBox.GLOSS_WIDTH`), lighter than the face by `gloss_strength`.

**Held (pressed)** drops the face with `expand_margin_top` = −`lip_height` and hides the lip. `LippedBox.set_vertical_padding()` keeps the height and moves the label with the face. The readers `is_lipped()`, `lip_height_of()` and `is_pressed()` recover the lip from those same fields.

**New tokens** in `DesignTokens.gd` / `design_tokens.tres`, each with a `##` line:
- the accent trios above
- `lip_height` = 7
- `gloss_strength` = 0.35 (how much lighter the top band starts)
- `release_pop_scale` = 1.03
- `release_pop_duration` = 0.12
- `outline_width` stays, used by text only

**ThemeFactory:**
- `_button_box()` returns a lipped `StyleBoxFlat` from `LippedBox`, so roughly 25 button roles follow in one rebake.
- `_add_button_variation()` builds all five states:
  - `normal` and `hover`/`focus` share one look (touch game)
  - `pressed` sets `pressed = true` and shifts the margins
  - `disabled` blends the face 70% toward `surface_sunken` and halves the lip
- **Role colours** follow the palette table. Information badges (`RosterStatusBelum`/`Sudah`, `QuirkBadge`/`PersonaBadge`, `SpecialtyBadge`) keep their meaning colours and gain a lip.
- **New variations:** `NotebookTab`, `NotebookTabActive`, `NotebookClose`, `NotebookSticker` (label).
- **The Lobby scrapbook variations** (`BookHeroButton`, `NavTileKoperasi`/`Inventory`/`Rapor`, `PlusButton`) already go through `_add_button_variation`, so they become lipped with everything else. `_thicken_lip()` sets `lip_height` to its `LOBBY_HUD_LIP` instead of `border_width_bottom`. Their fills move to the palette trios above. The textured plates (`BookCoverPanel`, `BookPagePanel`, `CoinPlate`, `ChevronGripButton`) keep their art.
- **Readers of a button box** use `LippedBox`'s readers for the lip and its state; everything else on it is an ordinary `StyleBoxFlat`.
- **Text:** chosen by the face's brightness. A face at or below `lipped_light_face_luminance` (0.7) gets `text_on_brand` with `font_outline_color` = the lip colour and `outline_size` = `lipped_label_outline` (8). A brighter face (cream, sunflower, sunken) gets `text_primary` with no outline. Godot Buttons have no font shadow, so there is no drop under the letters.

### 2. `NotebookFrame`

`Scenes/UI/NotebookFrame.tscn` plus `Scripts/UI/NotebookFrame.gd`: a `@tool class_name NotebookFrame extends Container`.

- **Host content:** a screen adds its own nodes as children of the instance root. In `NOTIFICATION_SORT_CHILDREN` the frame fits every non-internal child into the page's content rect, inside the sunken well.
- **Decoration:** internal children marked with the meta `notebook_chrome`, drawn behind or around the content:
  - `Cover` and `Page` (lipped faces with no gloss: a brown lip, and cream paper edges)
  - `Rules` (`TextureRect` with `paper_rule.png` tiled, including the red margin line)
  - `Rings` (a row of `spiral_ring.png`)
  - `Tabs` (`HBoxContainer` of `NotebookTab` Buttons)
  - `Sticker` (a `NinePatchRect` of `sticker_stitch.png` + a Boohong label, rotated −2°)
  - `Tape` (`washi_tape` texture, tinted)
  - `Close` (a `NotebookClose` Button with the close icon)
- **Root `@export`s.** Overrides only serialise on an instanced root, so everything a screen changes lives here:
  - `title_text`
  - `tabs: PackedStringArray` (up to 3; empty hides the tab strip)
  - `active_tab`
  - `ring_count` (0–8)
  - `show_well`
  - `show_tape`, `tape_color`
  - `show_close`
  - `content_padding`
- **A dialog is not a separate mode.** It is the same frame with no tabs, `ring_count` 4 and `show_well` off. The three tab Buttons and eight rings are authored in the scene and shown or hidden, never built at runtime.
- **Signals:** `tab_selected(index: int)`, `close_pressed`.
- **Opening and closing:** `AnimUtils.popup_spring_in/out`. The scrim stays the `Scrim` variation, and the frame centres inside `SafeAreaMargin` (the tall-phone rule).

**Textures** go in `Assets/Images/UI/Notebook/`, drop-replaceable at the same path, with a `README.md` giving their sizes and slice margins:
- `spiral_ring.png`
- `paper_rule.png` (tileable, with the red margin)
- `sticker_stitch.png` (9-slice)
- the washi tape, reusing `Assets/Images/AturJadwal/washi_tape.svg`

All four are generated placeholders at first and listed in `DEBT.md`.

### 3. Press feel and haptics (`Scripts/UI/UIPolish.gd`)

- **Lipped buttons:** when a button's `normal` stylebox is lipped (`LippedBox.is_lipped`):
  - no scale on press (the pressed stylebox does the sink, on the touch frame)
  - on release, a scale bump 1.0 → `release_pop_scale` → 1.0 over `release_pop_duration`, through a new `Juice.pop_release()`
- **Other buttons** keep `Juice.press`/`release`.
- **The tick:** on `button_down`, `Haptics.buzz(PRESS_TICK_MS)` fires for roles in `MAIN_ACTION_ROLES`. Both are named consts in `UIPolish.gd`:
  - `PRESS_TICK_MS = 8` (Haptics' existing "Tick" tier)
  - `MAIN_ACTION_ROLES` = `BookHeroButton`, `LobbyCtaButton`, `PrimaryButton`, `PrimaryButtonL`, `PrimaryButtonM`, `SuccessButton`, `DangerButton`, `NotebookClose`
- `Haptics.buzz` already no-ops when Getar is off, and shows its pip on desktop.

### 4. Icons

`Assets/Images/UI/Icons/` holds the new files, with fixed English names:

| Group | Files |
|---|---|
| Lobby nav | `nav_jadwal`, `nav_students`, `nav_koperasi`, `nav_inventory`, `nav_rapor` |
| Navigation | `chevron_left`, `chevron_right`, `exit`, `close`, `home` |
| Misc | `info`, `music`, `sound`, `vibrate` |
| Nice to have | `cat_istirahat`, `cat_wirausaha` |

- **Placeholders:** drawn now as SVGs in the target style (filled shape, dark outline). The owner's set replaces them at the same paths.
- **Retired:** the five `UI/Nav/icon_cta_*`/`icon_nav_*` references and the typed "✕" in `StatDetailPopup`, `TraitDetailPopup` and `WeekRecapPillInfoPopup` stop being used.
- **Kept:** the ~25 icons that already read well stay where they are.
- **Rules** (a folder `README.md`, pinned by `test_ui_icons`):
  - transparent background
  - at least 256 px, or an SVG
  - the outline or edge reaches enough contrast on both `FFF6E8` cream and `9C6440` brown, measured like `test_bar_contrast`
  - one centred subject per file
- **The Lobby tiles** keep the scrapbook's icon square; only the icon file changes to the new path.

## Rollout

Three phases, each its own plan-driven branch and `ship-pr` PR. Each phase gets its own implementation plan, written when the previous phase has merged. The first plan covers Phase 1 only.

1. **Foundation.**
   - Tokens and `LippedBox` (native, so the bake carries no script).
   - ThemeFactory switched over (the Lobby scrapbook variations included), then a rebake.
   - `Juice.pop_release`, and UIPolish's sink and tick.
   - `NotebookFrame` with its textures.
   - The 16 placeholder icons.
   - After this phase every button in the game, the Lobby's included, is lipped.
2. **Popups into `NotebookFrame`.**
   - With tabs: Settings (SUARA / MAIN), AchievementDetailSheet.
   - Without tabs: ItemDetailSheet, DapatkanUang, DailyLoginPanel, WeekLogsPopup, DaySummaryPopup, DailyDecayOverview.
   - As dialogs (no tabs, 4 rings, no well): StatDetailPopup, TraitDetailPopup, WeekRecapPillInfoPopup, EventStudentSelectDialog, OpenAmplopConfirm, AturJadwal's Peringatan dialog, TesNotice's scrim card, the scrim card inside StatCheck, TutorialPanel.
   - Each popup keeps its behaviour and signals. Only its box and close control move into the frame.
3. **Full screens.** A button-role, icon and screenshot pass over:
   - the Lobby (tile icons only)
   - MainMenu, LevelSelect, StudentCard, StudentList, AturJadwal
   - SchoolDay's HUD, ResultCheckup
   - ShopHub, Koperasi, Inventory, ReportCard, Achievements
   - the end-game screens
   - MinigameWinScreen and MinigameResultPopup (shared UI, not minigame internals)

## Testing

- **New suites**, all `@tool`, none a coroutine:
  - `test_lipped_box`:
    - the face/lip/gloss fields for resting and held
    - the padding split and clamp
    - relip
    - not-lipped cases
    - no script in the built theme
  - `test_notebook_frame`:
    - host children land inside the page content rect
    - empty `tabs` hides the tab strip, and `ring_count` hides the extra rings
    - `tab_selected` and `close_pressed` fire
    - the decoration is behind the content
    - the root exports serialise
  - `test_ui_icons`: size, alpha, contrast on cream and brown, the expected files present.
  - `test_press_feel`: `MAIN_ACTION_ROLES` gets the tick, lipped buttons get the sink/pop path, and lipless buttons get the shrink.
- **Existing suites that assume `StyleBoxFlat` or a rim are updated, never deleted:**
  - `button_geometry`, `lobby_style_buttons`, `theme_factory`, `cream_panel_tokens`
  - any other suite a full run reveals
- **The ratchets hold:**
  - no new `theme_override_*`
  - runtime construction does not grow (`NotebookFrame`'s decoration is authored in its `.tscn`, not built in code)
  - `test_script_documentation`
  - `clean_code`, locked in when it shrinks
- **Each phase ends with:** a full `test_run`, full-size screenshots of every touched screen at 9:16 and 20:9, and `ship-pr`.

## Risks

- Resolved in Phase 1: a script-backed StyleBox in the startup-loaded theme logged a SceneTree error on every debug run, so the look is built natively (`LippedBox`) and `test_lipped_box` guards that the built theme carries no script.
- **Editor save hazards** (CLAUDE.md 4b): scene work first, then scripts, with a restart in between. Diff every `.tscn` after saves.
- **Pressed-state margins shift content by `lip_height`.** A button inside a tight container may clip. Phase 3's screenshot pass is the check.
- **Theme conflicts with parallel branches.** Never hand-merge `kejartes_theme.tres`; rebake.

## Out of scope

- Minigame internals (HUDs, pause menus, per-game UI) beyond the automatic theme change.
- New art beyond the placeholders; the owner's icon set and any artist repaint land later at the same paths.
- Background and backdrop changes. Screens keep their current backgrounds.
- Persistence or gameplay changes.
