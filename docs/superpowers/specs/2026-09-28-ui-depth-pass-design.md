# UI Depth Pass — Design

**Date:** 2026-09-28
**Status:** approved in brainstorm, awaiting spec review
**Mockups:** `docs/superpowers/specs/mockups/ui-depth-pass/`. Each is a standalone HTML file; open it in any browser.
- `1-palette-and-lobby.html`: the palette, the button family, and the three Lobby options (B chosen).
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
| Lobby | Option B: a sunflower **JADWAL!**, and cream nav tiles, each with a round, colour-coded icon badge. |
| Popup frame | **Notebook:** brown hardcover with a lip, a cream ruled page with two paper edges and a red margin line, chunky spiral rings through punched holes, lipped tabs, a stitched sticker title, controls in a sunken well, torn-end washi tape, and a round tomato ✕. There are two variants, `SHEET` and `DIALOG`. |
| Press | **Sink onto the lip:** the face drops by the lip height on touch, then gets a small pop on release. Buttons without a lip keep today's shrink. |
| Haptics | A ~10 ms tick on press, for **main-action roles only**. It respects the existing Getar setting. |
| Sound | The existing tap SFX on every button, unchanged. |
| Icons | The owner supplies a chunky set later. Placeholders are drawn now at fixed paths and swapped in with no code change. |
| Scope | The theme changes everywhere. The notebook frame and icons are hand-fitted on **all core screens and popups**. Minigames get only the automatic theme change. |
| Build approach | **Hybrid.** A code-drawn `LippedStyleBox` for everything that recolours and resizes; small drop-replaceable textures only for the notebook's illustration pieces. |

### Palette

| Name | Gloss | Base | Lip | Role |
|---|---|---|---|---|
| Sunflower | `FFE07A` | `FFC93C` | `C9801A` | The one main action per screen (`LobbyCtaButton`, `PrimaryButton`), the active tab, coins |
| Mint | `6BE3BB` | `2EC99A` | `178A68` | Affirm (`SuccessButton`: Terima, Lanjut), toggles on |
| Sky | `8CC2F5` | `5EA1E6` | `3469B3` | Info, inactive tabs, slider knobs |
| Tomato | `F58A72` | `E5553E` | `A3301E` | Danger and close (`DangerButton`, the ✕) |
| Tangerine | `FFB36A` | `F58A3C` | `BD561A` | Koperasi badge, secondary warm accent |
| Brown | `B87A52` | `9C6440` | `56321B` | Back and neutral (`SecondaryButton`), notebook cover |
| Cream | `FFFFFF` | `FFF1DC` | `C9A57E` | Nav tiles, Batal (`StudentCardSecondaryButton`) |

The stat categories already own blue (Akademis), red (Olahraga), green (Seni) and teal (Wirausaha). So colour is spent only on the action roles above, never as full-candy button rows.

## Architecture

### 1. `LippedStyleBox`

`Scripts/Design/LippedStyleBox.gd` is a `@tool class_name LippedStyleBox extends StyleBox`. `_draw(canvas_item, rect)` draws three internal `StyleBoxFlat`s, which keeps Godot's anti-aliased corners:

1. **Lip:** `lip_color`, the full rect, drawn with its top edge `lip_height` below the face's top.
2. **Face:** `face_color`, the rect minus `lip_height` at the bottom. It carries the existing soft shadow (`shadow_color`/`shadow_size`/`shadow_offset` tokens).
3. **Gloss:** white at `gloss_strength` alpha fading to near zero, inset 8 px left/right and 4 px from the top, covering the top third of the face.

Exported properties:
- `face_color`, `lip_color`, `lip_height`, `corner_radius`, `gloss_strength`
- `pressed: bool`. When true, no lip is drawn and the face moves down by `lip_height`.

The content margins are the base `StyleBox` margins. For the pressed state, the factory adds `lip_height` to `content_margin_top` and subtracts it from `content_margin_bottom`, so the label sinks with the face.

**New tokens** in `DesignTokens.gd` / `design_tokens.tres`, each with a `##` line:
- the accent trios above
- `lip_height` = 7
- `gloss_strength` = 0.5
- `release_pop_scale` = 1.03
- `release_pop_duration` = 0.12
- `outline_width` stays, used by text only

**ThemeFactory:**
- `_button_box()` returns a `LippedStyleBox`, so roughly 25 button roles follow in one rebake.
- `_add_button_variation()` builds all five states:
  - `normal` and `hover`/`focus` share one look (touch game)
  - `pressed` sets `pressed = true` and shifts the margins
  - `disabled` blends the face 70% toward `surface_sunken` and halves the lip
- **Role colours** follow the palette table. Information badges (`RosterStatusBelum`/`Sudah`, `QuirkBadge`/`PersonaBadge`, `SpecialtyBadge`) keep their meaning colours and gain a lip.
- **New variations:** `NotebookTab`, `NotebookTabActive`, `NotebookClose`, `IconBadge` (with a size step), `NotebookSticker` (label).
- **Code that casts a button stylebox to `StyleBoxFlat` switches to `StyleBox`.** That covers `_set_content_margins`, `_add_size_step` and any test or runtime reader.
- **Text:** button font colour is white, `font_outline_color` is the lip colour, `outline_size` is 8, and there is a font shadow in the lip colour at offset (0, 3). Cream roles use brown text with no outline.

### 2. `NotebookFrame`

`Scenes/UI/NotebookFrame.tscn` plus `Scripts/UI/NotebookFrame.gd`: a `@tool class_name NotebookFrame extends Container`.

- **Host content:** a screen adds its own nodes as children of the instance root. In `NOTIFICATION_SORT_CHILDREN` the frame fits every non-internal child into the page's content rect, inside the sunken well.
- **Decoration:** internal children marked with the meta `notebook_chrome`, drawn behind or around the content:
  - `Cover` and `Page` (`LippedStyleBox`, with brown-lip and cream-edge lips)
  - `Rules` (`TextureRect` with `paper_rule.png` tiled, including the red margin line)
  - `Rings` (a row of `spiral_ring.png`)
  - `Tabs` (`HBoxContainer` of `NotebookTab` Buttons)
  - `Sticker` (a `NinePatchRect` of `sticker_stitch.png` + a Boohong label, rotated −2°)
  - `Tape` (`washi_tape` texture, tinted)
  - `Close` (a `NotebookClose` Button with the close icon)
- **Root `@export`s.** Overrides only serialise on an instanced root, so everything a screen changes lives here:
  - `variant: SHEET | DIALOG`
  - `title_text`
  - `tabs: PackedStringArray`
  - `active_tab`
  - `ring_count`
  - `show_tape`, `tape_color`
  - `show_close`
  - `content_padding`
- **Signals:** `tab_selected(index: int)`, `close_pressed`.
- **Opening and closing:** `AnimUtils.popup_spring_in/out`. The scrim stays the `Scrim` variation, and the frame centres inside `SafeAreaMargin` (the tall-phone rule).

**Textures** go in `Assets/Images/UI/Notebook/`, drop-replaceable at the same path, with a `README.md` giving their sizes and slice margins:
- `spiral_ring.png`
- `paper_rule.png` (tileable, with the red margin)
- `sticker_stitch.png` (9-slice)
- the washi tape, reusing `Assets/Images/AturJadwal/washi_tape.svg`

All four are generated placeholders at first and listed in `DEBT.md`.

### 3. Press feel and haptics (`Scripts/UI/UIPolish.gd`)

- **Lipped buttons:** when a button's `normal` stylebox is a `LippedStyleBox`:
  - no scale on press (the pressed stylebox does the sink, on the touch frame)
  - on release, a scale bump 1.0 → `release_pop_scale` → 1.0 over `release_pop_duration`, through a new `Juice.pop_release()`
- **Other buttons** keep `Juice.press`/`release`.
- **The tick:** on `button_down`, `Haptics.buzz(PRESS_TICK_MS)` fires for roles in `MAIN_ACTION_ROLES`. Both are named consts in `UIPolish.gd`:
  - `PRESS_TICK_MS = 10`
  - `MAIN_ACTION_ROLES` = `LobbyCtaButton`, `PrimaryButton`, `PrimaryButtonL`, `PrimaryButtonM`, `SuccessButton`, `DangerButton`, `NotebookClose`
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
- **Lobby badges:** `IconBadge` is a circular `LippedStyleBox`. Koperasi is tangerine, Inventory sky, Rapor mint, Students sunflower. The icon sits on top.

## Rollout

Four phases, each its own plan-driven branch and `ship-pr` PR. Each phase gets its own implementation plan, written when the previous phase has merged. The first plan covers Phase 1 only.

1. **Foundation.**
   - Tokens and `LippedStyleBox`, proving first that a script-backed stylebox survives `BakeTheme`'s `.tres` save and a cold editor load.
   - ThemeFactory switched over, then a rebake.
   - `Juice.pop_release`, and UIPolish's sink and tick.
   - `NotebookFrame` with its textures, and `IconBadge`.
   - The 16 placeholder icons.
   - After this phase the whole game is lipped.
2. **Lobby.**
   - The sunflower JADWAL!, and cream nav tiles with badges.
   - HUD icons (gear, trophy, notes, skin) in badges.
   - The coin pill with a lip.
3. **Popups into `NotebookFrame`.**
   - `SHEET` with tabs: Settings (SUARA / MAIN), AchievementDetailSheet.
   - `SHEET`: ItemDetailSheet, DapatkanUang, DailyLoginPanel, WeekLogsPopup, DaySummaryPopup, DailyDecayOverview.
   - `DIALOG`: StatDetailPopup, TraitDetailPopup, WeekRecapPillInfoPopup, EventStudentSelectDialog, OpenAmplopConfirm, AturJadwal's Peringatan dialog, TesNotice's scrim card, the scrim card inside StatCheck, TutorialPanel.
   - Each popup keeps its behaviour and signals. Only its box and close control move into the frame.
4. **Full screens.** A button-role, icon and screenshot pass over:
   - MainMenu, LevelSelect, StudentCard, StudentList, AturJadwal
   - SchoolDay's HUD, ResultCheckup
   - ShopHub, Koperasi, Inventory, ReportCard, Achievements
   - the end-game screens
   - MinigameWinScreen and MinigameResultPopup (shared UI, not minigame internals)

## Testing

- **New suites**, all `@tool`, none a coroutine:
  - `test_lipped_stylebox`:
    - lip, face and gloss rects for a given rect and lip height
    - the pressed face offset and margin shift
    - the disabled lip at half height
    - survives a save/load round trip
  - `test_notebook_frame`:
    - host children land inside the page content rect
    - the `DIALOG` variant hides tabs
    - `tab_selected` and `close_pressed` fire
    - the decoration is behind the content
    - the root exports serialise
    - it fills a 1080×2400 viewport
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

- **A script-backed StyleBox inside the baked theme.** A cold editor restart must keep drawing it; a `@tool` script and `class_name` registration are needed. Phase 1's first task proves the round trip before anything builds on it.
- **Editor save hazards** (CLAUDE.md 4b): scene work first, then scripts, with a restart in between. Diff every `.tscn` after saves.
- **Pressed-state margins shift content by `lip_height`.** A button inside a tight container may clip. Phase 4's screenshot pass is the check.
- **Theme conflicts with parallel branches.** Never hand-merge `kejartes_theme.tres`; rebake.

## Out of scope

- Minigame internals (HUDs, pause menus, per-game UI) beyond the automatic theme change.
- New art beyond the placeholders; the owner's icon set and any artist repaint land later at the same paths.
- Background and backdrop changes. Screens keep their current backgrounds.
- Persistence or gameplay changes.
