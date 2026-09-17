# Tall-phone layout — design

**Date:** 2026-09-15 · **Status:** design approved in brainstorm; plan not yet written
**Branch:** `fix/tall-phone-layout`, off `Textures`

## Problem

On a 20:9 Android phone (720×1600 screenshots), several screens show a bare
gray band at the bottom, and in the Lobby the students sit at the wrong desks.

`project.godot` runs `window/stretch/mode="canvas_items"` with
`aspect="expand"`. On a 20:9 phone the viewport becomes **1080×2400** design
px instead of 1080×1920. Screens authored as fixed 1080×1920 layouts never
grow into the extra 480 px, and the empty area shows Godot's default clear
colour. It measures `(0.298, 0.298, 0.298)`, the gray in the phone
screenshots; `project.godot` sets no clear colour.

**Why the editor never shows it.** The editor runs the game embedded at the
360×640 window override (9:16), and an embedded window cannot be resized:
Godot logs `Embedded window can't be resized` and
`Engine.is_embedded_in_editor()` returns true. Every desktop run is 9:16.

**Reproduced** by rendering the real scenes into `SubViewport`s at 1080×2400
inside the running game (Appendix B). The renders match the phone to the
pixel. The Rapor wood ends at y 1920 design px, which is 1280 phone px. The
Lobby's JADWAL button sits at 1520 design px, which is 1013 phone px.

## Root cause: three ways a screen breaks

1. **Fixed background.** A backdrop in position layout (`layout_mode = 0`, no
   anchor lines) sized 1080×1920, or a TextureRect that takes its texture's
   native size. It stays 1920 tall.
   - *Rapor* `Backdrop`: `Scenes/ReportCard/report_card.tscn:31-40`.
   - *Koperasi* room `TextureRect`: `Scenes/Koperasi/koprasi.tscn:47-51`.
2. **Fit instead of cover.** A full-rect background with `stretch_mode = 5`
   (Keep Aspect Centered) letterboxes itself, with bars top and bottom.
   - *Lobby* `BGLayer` and its four full-screen desk layers:
     `Scenes/Lobby/loby.tscn:52-91, 393-415`.
3. **Pinned content.** Content at fixed top-left offsets inside the 1920
   space. It never follows the bottom edge, and it drifts off a background
   that moves.
   - *Lobby* seats `Slot1..4` (`anchors_preset = 0`,
     `loby.tscn:101-141, 425-467`).
   - *Lobby* button block (`layout_mode = 0`, `loby.tscn:719-835`).

   On 20:9 the classroom slides down 232 px and the seats stay put, so the
   front-row students land at the back desks.

**Working example.** `Scenes/Minigames/Akademis/PilihanGanda.tscn:80-101`
fills the phone: a full-rect background with `stretch_mode = 6` (Keep Aspect
Covered) and content in containers anchored by fractions.

**Not layout bugs:**
- the phone's screen-recorder bar;
- the star circles, which are `TouchFeedbackManager` tap ripples;
- the Inventory's gray band. It is painted into `bg_inventory_blur.png`, a
  768×1376 blurred copy of the classroom; the gray is its floor.

## Decision

Every screen **fills** the phone.

**Considered and rejected:**
- *A global letterbox* (`aspect="keep"`). It takes one setting, but puts black
  bars on every screen and wastes a fifth of a 20:9 phone. Godot 4.6 cannot
  colour the bars; `RenderingServer` exposes only `viewport_attach_to_screen`.
- *For the Lobby:* zoom-to-fill, which trims ~12% per side and cuts students
  at the edges, and blurred bands, which are kept as a later option.

**Invariant.** At 1080×1920, every screen renders as it does today, with two
deliberate exceptions:
- the Inventory background, cropped above its painted floor;
- the Lobby classroom's 4 px side slivers, gone because its background now
  covers instead of fits.

**Targets.** Portrait phones from 9:16 to 9:21. Wider screens (tablets) follow
the same rules and fall back to side bands; they are not a target.

## The four rules

1. **Backgrounds fill.** Use a `TextureRect` with anchors `0,0,1,1` (Full
   Rect), `expand_mode = 1` (Ignore Size) and `stretch_mode = 6` (Keep Aspect
   Covered). Nothing distorts; on 20:9 it trims ~12% off each side.
2. **UI sits on its edge.** Each UI group takes the preset for where it
   belongs:
   - header: Top Wide;
   - back button: Top Left;
   - action rows: Bottom Wide or Bottom Right;
   - cards and popups: Center.

   **Re-anchor, don't move.** Set the anchors, then set each offset to
   `old_global − (parent_origin + anchor × parent_size)`, measured at the
   design size. The node keeps today's rect at 1080×1920 and follows its edge
   on taller screens.

   Set all four anchors explicitly, because `anchors_preset` is inert over
   MCP. On a Control under a plain Control, set `layout_mode = 1` first, or
   the anchors are not saved.
3. **UI inside the margin.** Every screen with UI on its top or bottom edge
   puts that UI in a Full Rect `SafeAreaMargin`
   (`Scripts/UI/SafeAreaMargin.gd`): the Lobby, Rapor, StudentCard, Koperasi,
   Inventory, AturJadwal, StudentList, CutScene and EndCutscene. Screens
   whose only UI is centred (ExamProgress, StatCheck) do not need one. It
   applies the theme's `screen_margin` (48 px,
   `Scripts/Design/DesignTokens.gd:292`) plus the device's camera and
   gesture-bar insets.

   Presets are ignored on a container's direct children. So the margin holds
   one plain `UI` Control, and the anchored groups live inside that. The
   margin is 48 px, not 50: it is the existing token, as agreed in the
   brainstorm.
4. **Pictures carry their items.** A picture and anything placed on it (seats
   on desks, items on shelves, notes on a board) form one fixed-size Control
   at the art's size, pinned where the composition wants it. Only the plain
   background behind it fills.

**Screen root order:** background, then picture unit(s), then
`SafeAreaMargin` / `UI`, then overlays and popups.

## Screen by screen

The worklist. Evidence comes from two read-only audits and this session's
renders; Appendix A has the full map.

| Screen | Today | Change | Watch out for |
|---|---|---|---|
| **Lobby** — `Scenes/Lobby/loby.tscn`, `Scripts/Lobby/loby.gd` | modes 2 and 3 (above) | See **Lobby changes** below the table. | See **Lobby hazards** below the table. |
| **Rapor** — `Scenes/ReportCard/report_card.tscn` | Root inset by 70/254/−77/−352 (`:18-29`). `Backdrop` is position-mode 1080×1920 (`:31-40`). | `Backdrop` fills the screen through the inset: anchors 0..1, offsets −70/−254/+77/+352. Header pinned top. Paper card Center. Page nav (`1/2` and arrows) pinned bottom. | The KEMBALI-overlap fix (a separate session) edits this file. Do this screen after it merges. |
| **StudentCard** — `Scenes/StudentCard/student_card.tscn` | Same structure as Rapor (`:27-57, 306-311, 1579-1691`): six card sheets on the 1080×1920 `card_bg.png`. Arrows at y 1524, Belajar at 1740, PageLabel at 1551, all fixed. | As Rapor. | `PaperShadow` instances sit under plain Controls (authoring guide, "an instanced scene's root loses its rect"). |
| **Koperasi** — `Scenes/Koperasi/koprasi.tscn` | See **Koperasi today** below the table. | Room fills. `Rak1` stays one piece, pinned bottom (anchors 1, offsets −1803/−92), so the tray still ends flush with the bottom. `CoinHUD` goes Top Left. The landing button `TextureRect/Rak1` ("KEBUTUHAN SEKOLAH", `:53-61`) is pinned bottom; from 9:16 to 9:21 it stays on the counter's glass front. | `BasketTray` is an instance: set its layout on the instance root only, because overrides on an instance's children are dropped on save. Two nodes are named `Rak1`. `test_basket_tray.gd` and `test_koperasi_tray.gd` pin tray geometry. |
| **Inventory** — `Scenes/Inventory/inventory.tscn` | `Background` is already Full Rect, but `stretch_mode = 0` distorts it ~24% (`:23-31`). The bottom ~23% of its art is the classroom floor. | `stretch_mode = 6` on an `AtlasTexture` region of `bg_inventory_blur.png` that stops above the floor; find the row by pixel scan. This is the one deliberate 9:16 change. | The glyph/icon fix (a separate session) edits this file: do this after it merges. `MainColumn` is `layout_mode = 0` with full anchor lines (`:33-38`), which is full rect at runtime; normalise it to `layout_mode = 1`. |
| **AturJadwal** — `Scenes/AturJadwal/atur_jadwal.tscn` | See **AturJadwal today** below the table. | The wall backdrop fills. Top band and shelf pin top. The whiteboard and its notes become one picture unit that keeps the board's aspect, pinned bottom together with `StartWeek` beside `BackButton`. If the render shows an awkward gap between shelf and board, centre the board unit in that gap instead. | `penjadwalan_card_bg.png` must stay 1080×1080, because `test_atur_jadwal.gd` pins the Peringatan dialog's `region_rect` (CLAUDE.md). The screen needs `day_schedules`, so reach it through the game, not as a bare instance. |
| **StudentList** — `Scenes/StudentList/student_list.tscn` | Background already covers. `CardContainer` (310–1720) and the arrows and page dots (1772–1900) are fixed (`:31-60, 141-195`). | `CardContainer` Center. Arrows and page dots Bottom Wide. | An editor save of `RosterCard.tscn` shifts all five StickyNotes by 20 px (`@tool` `_apply_pin` bakes offsets). After any save, diff it and restore from HEAD. |
| **CutScene** — `Scenes/CutScene/cut_scene.tscn`, `Scripts/CutScene/cut_scene.gd` | `DialogueBox` (1340–1660) and `HintLabel` (1700) are fixed (`:48-57`). Code places the top bar at (30, 40) (`cut_scene.gd:87-88`) and the level-select panel at (90, 360) (`:147-148`). | Dialogue box and hint go Bottom Wide. The top bar moves into the safe margin. The level-select panel becomes Center-anchored instead of placed by code. | The level-select panel also shows for players who have finished the game (`cut_scene.gd:78-79`), not only in debug. |
| **ExamProgress** — `Scenes/EndGame/ExamProgress.tscn` | `Backdrop` is position-mode 1296×1920 and pans horizontally (`:15-22`, `ExamProgress.gd:28-33, 51`). `Scrim` is position-mode 1080×1920 (`:23-35`). | `Backdrop` becomes full height (anchor_top 0, anchor_bottom 1) and keeps its 1296 width and its pan. `Scrim` goes Full Rect. | DEBT's "ExamProgress shows only the middle of cg_ujian" stays open. |
| **StatCheck** — `Scenes/EndGame/StatCheck.tscn` | `Backdrop` and `Scrim` are position-mode 1080×1920 (`:15-36`). | Both go Full Rect. | — |
| **EndCutscene** — `Scenes/EndGame/EndCutscene.tscn` | `BtnNext` is fixed at 1736–1864 (`:25-59`). | Pinned bottom, keeping its horizontal placement. | WinStage letterboxes its 3:4 painting on purpose. Leave it. |
| **ResultCheckup** — `Scenes/SchoolSimulation/ResultCheckup.tscn` | The celebration fires from the `Celebration` instance's authored `position` (−40, 1780) (`:122-124`; read at `ResultCheckup.gd:376` on `Textures`). It is a 2D node, so anchors do not apply to it. | Wrap `Celebration` in a Bottom Left–anchored Control, converting its offset as in rule 2. `ResultCheckup.gd` then reads the marker's `global_position`, so the spawn point is still authored in the scene. | Never instance it bare (it hung the editor once). Verify it through a real week. |
| **MainBola** — `Scripts/Minigames/Olahraga/MainBola.gd` | See **MainBola today** below the table. | Map the goal geometry through the art's cover transform, so the zones match the drawn posts. | Minigames are otherwise outside the design system. This bug shows in play, so it is in scope. |

**Lobby changes.**
- Add a `Classroom` Control with Center anchors and offsets ±540/±960, so it
  is always 1080×1920.
- Move into it, with their authored rects:
  - `BGLayer`, set to `stretch_mode = 6`;
  - the four `Meja_*` layers;
  - the four portrait and hand containers.
- Put a Full Rect black `ColorRect` behind it.
- `JUDUL` pins top.
- The button block pins bottom as one group: `DailyLogin`, `ShortenButton`,
  `DisplayUang`, `Jadwal`/`Student` and the three tiles.

**Lobby hazards.**
- `loby.gd:55-82, 130` reach nodes by path. Switch them to `%` unique names.
- The Daily Reward blur is inserted at `DailyLogin`'s child index and must
  cover the HUD (`loby.gd:604-625`, `tests/test_shorten.gd:178-187`). Keep the
  popup and blur at the root, after `UI`.
- Face rigs copy their slot's layout (`loby.gd:379-390`). That is unaffected
  as long as the slots keep their local rects.
- Suites that pin the old paths: `test_lobby.gd`, `test_lobby_layout.gd`,
  `test_shorten.gd`.

**Koperasi today.**
- The room `TextureRect` takes the native 1080×1920 (`:47-51`).
- The shelf view `Rak1` is a crop of `rak2.jpg` (an AtlasTexture, region
  0,259 1080×1661, `:17-19`), placed at 0,117–1080,1828 (`:63-70`). Its
  children are `Barang1-4`, `BackButton` and `BasketTray` (`:72-223`).
- `CoinHUD` sits at x 20 (`:225`).

**AturJadwal today** (`:39-124, 338-360`).
- The top-band backdrop covers 0–766 in position mode.
- Whiteboard `BGHari` is Full Rect but `stretch_mode = 0`, so it stretches
  1.25× on 20:9. Its art is opaque only from row 766 down.
- The sticky notes (1000–1693) and `StartWeek` (1754) are fixed.
- `BackButton` is already bottom-anchored.

**MainBola today** (`MainBola.gd:343-364, 408-411, 487-495`).
- The goal art covers, which on 20:9 scales it 1.25× about the centre.
- The posts and scoring zones are placed as screen fractions.
- By arithmetic, the drawn posts land off-screen (x ≈ −81 and 1161) while the
  scoring zone stays at 103–977.

**Render check only.** The audits found these already fine: MainMenu,
Settings, SchoolDay, RunResult, ApplyItemScreen, the other seven minigames,
the `Transition` wipe, and every popup and overlay.
- ShopHub, CosmeticShop and TesNotice are fine only by inference. Their
  position-mode nodes also carry full anchor lines, which load after
  `layout_mode` and make them full rect at runtime. A render confirms it.

**Skipped:** WinScreen, which nothing references, and Splashscreen, which
nothing routes to.

## SafeAreaMargin

Its current math is right for a filling game, where content covers the whole
window. Only one change: quiet its clamp warning (`SafeAreaMargin.gd:70-76`)
outside real devices, by warning only when `OS.has_feature("mobile")`. In an
editor run the reported safe area always exceeds the window. With a dozen
screens on it, every run would log the warning once per screen.
`tests/test_ui_components.gd:63-81` and `tests/test_boot_screens.gd:100` must
stay green.

## Testing

1. **New suite, written first:** `tests/test_tall_screen_layout.gd`
   (`@tool`, `McpTestSuite`, no coroutines, `##` docs). A per-screen table
   asserts the rules on the saved scenes:
   - the background's anchors are `0,0,1,1` and its `stretch_mode` is 6;
   - the pinned groups' anchors match their edge;
   - the Lobby `Classroom` has 0.5 anchors and a 1080×1920 size;
   - on the rule-3 screens, the UI sits under a `SafeAreaMargin`.

   Read properties from an instanced PackedScene, or scan the source where
   instancing is unsafe. Each screen's row is added failing and turns green
   when that screen is done.
2. **Existing suites** that pin old paths or offsets are updated in the same
   task as their screen. Known so far: `test_lobby.gd`,
   `test_lobby_layout.gd`, `test_shorten.gd`, `test_basket_tray.gd`,
   `test_koperasi_tray.gd`. Grep each screen's name to find the rest.
3. **Render check per screen** (Appendix B).
   - Capture a 1080×1920 baseline before touching a screen. After the
     change, the 1920 render must match it, apart from the two stated
     exceptions.
   - The 1080×2400 render must show no bare clear-colour gray.
   - Freeze motion for the comparison: `Engine.time_scale = 0.02`, not 0,
     because GPU particles vanish at 0.
4. **Desktop preview.** The first task checks whether
   `window_width_override = 360` with `window_height_override = 800` gives a
   9:20 embedded run. If it does, record the recipe in the authoring guide. If
   not, the render check is the preview. Never commit the override.
5. **Full suite at the end of each phase** (CLAUDE.md), then `ship-pr`.
6. **Device check** by the user on their phone, once per phase.

## Docs

- **`CLAUDE.md`, `## Visual system`:** the four rules, in a few lines. They
  govern all future screens.
- **`docs/superpowers/design/authoring-guide.md`:** the how-to: the re-anchor
  offset formula, `SafeAreaMargin` → `UI`, picture units, the render check,
  and the desktop preview recipe.
- **`docs/superpowers/CHANGELOG.md`:** one entry per phase.
- **`docs/superpowers/DEBT.md`:** anything deferred along the way.

## Phases

Each phase is its own PR.

1. The new suite, the `SafeAreaMargin` warning, then the **Lobby**,
   **Koperasi**, **StudentCard** and **StudentList**.
2. **AturJadwal**, **CutScene**, **Rapor** and **Inventory**. Rapor is done
   (2026-09-16), as is AturJadwal's board; AturJadwal's wall, top band and
   `StartWeek` are still open. Inventory waits for the glyph fix to merge.
3. **ExamProgress**, **StatCheck**, **EndCutscene**, the **ResultCheckup**
   confetti and **MainBola**.

## Out of scope

- Full-screen Lobby art, perhaps as taller art from the artist, and blurred
  or themed bands.
- A global letterbox (rejected above).
- Bugs found along the way, each in its own task:
  - the Rapor `KEMBALI` button covering its title;
  - the Inventory `‹` glyph and tab icons missing on Android;
  - the two suspected dialog bugs (`QuitConfirmDialog`'s dim;
    `EventStudentSelectDialog.gd:121` looking up `Background` where the node
    is `BackgroundDim`).
- TesNotice's collapsing card, already in DEBT (2026-09-11).
- ExamProgress's full-art pan, already in DEBT (2026-09-14).

## Working notes for the plan

- **Where the work happens.** Work in the main checkout on this branch, since
  the editor bridge is attached there. Close Godot before switching branches
  (CLAUDE.md 4b) and restart it afterwards.
- **What never gets staged:**
  - the user's uncommitted `window_*_override` lines in `project.godot`;
  - `Assets/Audio/default_bus_layout.tres`;
  - `addons/godot_ai/utils/update_activation_runner.gd`.
- **Scene edits go through the editor** (`scene_open` → `node_*` /
  `batch_execute` → `scene_save`), never by hand while it is attached.
  - Do scene work first and script work second.
  - After each `scene_save`, run `git diff HEAD -- '*.gd'` to catch stale
    script tabs written back.
  - After any `script_patch`, restart the editor before the next
    `scene_save`.
- **Reparenting a Control under a plain `Control`** needs `layout_mode = 1`
  before the anchors are set. Anchors on position-mode Controls are not
  saved.
- **Targeted suites.** Prefer `test_run(suite=...)` while working. A full run
  drops the bridge: budget one editor restart per full run.
- **Unsafe to instance bare:** ResultCheckup, SchoolDay, AturJadwal and the
  EventDialogue family need data. Reach them through the game (seed, then an
  Atur Jadwal pass).

## Appendix A: audit map

Verdicts on a 1080×2400 viewport before this work. "Fails 1/2/3" refers to the
three ways a screen breaks, above.

| Screen | Verdict |
|---|---|
| Lobby | fails 2 and 3 |
| Rapor | fails 1 and 3 |
| StudentCard | fails 1 and 3 |
| Koperasi | fails 1 and 3 |
| Inventory | distorts (stretch-to-fill), and has a painted floor band |
| AturJadwal | fails 3, and its board stretches |
| StudentList | fails 3 |
| CutScene | fails 3, plus code-placed panels |
| ExamProgress | fails 1 |
| StatCheck | fails 1 |
| EndCutscene | fails 3 (one button) |
| ResultCheckup | fine; the confetti starts from a fixed point |
| MainBola | fails 3 on the x axis; its art and gameplay zones disagree |
| MainMenu, Settings, SchoolDay, RunResult, ApplyItemScreen | fine |
| PilihanGanda, Menjodohkan, Password, Variabel, BuatBatik, LombaMenari, Badminton | fine |
| ShopHub, CosmeticShop, TesNotice | fine by inference (position mode with full anchor lines) |
| WinStage | letterboxes on purpose |
| WinScreen, Splashscreen | unused |
| Transition, EventWarning, EventDialogue, EventStudentSelectDialog, DaySummaryPopup, WeekLogsPopup, TutorialPanel, Stat/TraitDetailPopup, ItemDetailSheet, ShortenPanel, PauseMenu, MinigameResultPopup, MinigameTutorial | fine |
| QuitConfirmDialog | rect fine, but its dim draws at 1×1 px (suspected; separate task) |

## Appendix B: render check

This runs through `editor_manage(op="game_eval")` with the game running
(`project_run`, `autosave=false`). It renders one screen at both heights,
saves the PNGs and counts bare clear-colour samples.

**Seed first.** Screens that need data must be reached through the game, not
instanced like this.

```gdscript
var tree := Engine.get_main_loop() as SceneTree
tree.root.get_node("DebugManager")._seed_playtest_state()
var scene := "res://Scenes/ReportCard/report_card.tscn"
var out_dir := "C:/path/to/scratch/"  # set to a scratch folder outside the repo
var out := {}
for h in [1920, 2400]:
	var sv := SubViewport.new()
	sv.size = Vector2i(1080, h)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(sv)
	sv.add_child((load(scene) as PackedScene).instantiate())
	await tree.create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.save_png(out_dir + "screen_%d.png" % h)
	var bare := 0
	for y in range(0, h, 4):
		for x in range(0, 1080, 4):
			var c := img.get_pixel(x, y)
			if c.r8 == c.g8 and c.g8 == c.b8 and absi(c.r8 - 76) <= 1:
				bare += 1
	out[h] = bare
	sv.queue_free()
	await tree.process_frame
return out
```

A clean screen reports `bare` ≈ 0 at 2400. The investigation's renders (Lobby
and Rapor at 9:16 against 9:20, and the Lobby fill options) were made this
way.
