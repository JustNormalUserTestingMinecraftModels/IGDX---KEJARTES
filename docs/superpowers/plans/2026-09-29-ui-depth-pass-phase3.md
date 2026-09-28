# UI Depth Pass — Phase 3 (Screen Pass) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the UI depth pass on the full screens with three things:
- the Lobby tiles and every screen's arrows, exit and category icons move to the new icon set;
- the two buttons wearing the wrong role get the right one;
- typed emoji and dingbats leave the UI text, and a test keeps them out.

**Architecture:** This is a pass, not a new system. Scenes change their icon references (`icon` on a Button, or `texture` on a TextureRect) to `Assets/Images/UI/Icons/*.svg`. Two buttons change `theme_type_variation`. UI strings lose their glyphs. One new suite ratchets the glyph rule. The trait-chip gloss is checked on a render, and it gets thinner only if it reads as a crescent.

**Tech Stack:** Godot 4.6 GDScript, `.tscn` text edits made while the worktree editor is closed, and the Godot AI MCP bridge (driven only by the controller).

**Spec:** `docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md`, Rollout step 3. Phase 2's plan (`2026-09-28-ui-depth-pass-phase2.md`) is the format reference.

## Survey (2026-09-29): what the screens hold

Four read-only surveys covered every screen in the spec's list. This is what they found.

| Screen | Finding | Action |
|---|---|---|
| Lobby | The five tiles' Button `icon` still points at `UI/Nav/icon_cta_student.png`, `icon_cta_jadwal.png`, `icon_nav_koperasi.png`, `icon_nav_inventory.png`, `icon_nav_rapor.png` (spec: "retired"). | Task 1 |
| MainMenu | QuitButton's icon is `UI/icon_exit.svg`; the new set has `Icons/exit.svg`. SettingButton's `setting.png` has no replacement in the set. | Task 1 (Quit only) |
| LevelSelect, StudentCard, StudentList | Their page arrows are a child `TextureRect` showing `Placeholders/arrow.png` rotated ±90°. The arrow does not sink with the lipped face on press. | Task 2 |
| ReportCard | `NextButtonKiri`/`Kanan` icons are `UI/Nav/icon_chevron_left/right.png`. | Task 2 |
| StudentList, AturJadwal, DapatkanUang | The Istirahat and Wirausaha category icons are stand-ins: `stat_energy.png`/`uang.png` in `RosterCard.gd`, generated placeholder PNGs in `DayStickyNote.gd`, and `Placeholders/icon_wirausaha.svg` for DapatkanUang's tip. | Task 3 |
| ReportCard | `Safe/UI/BackButton` wears `PrimaryButton` (mint) for a pure back. Inventory, ShopHub, CosmeticShop and Settings use brown for the same job. | Task 4 |
| Password / Variabel (minigames) | `AksiRow/BtnHapus` wears `LobbyCtaButton` (mint, ticks) but only clears the unsent answer (DEBT). | Task 4 |
| SchoolDay, AturJadwal, CutScene, DaySummaryBadge, DailyDecayOverview, DayStickyNote | Typed emoji and dingbats in UI text: ⏭ ✨ ➔ 📅 ⏩ 🌅 💬 ⚡ 😊 🎓 🎯 🔒. | Task 5 |
| StudentList | The trait chips (M step, 96 px tall pills, radius clamps to 48) carry the fixed 14 px gloss (`LippedBox.GLOSS_WIDTH`). The owner asked whether it reads as a crescent. | Task 6 |
| Everything else | Every other button already wears its role. | none |

Everything else in the list checked out, so it is not an oversight:
- ResultCheckup: Logs / Selanjutnya.
- ShopHub and CosmeticShop: Kembali.
- Koperasi: Beli is mint. Its footer fits the 128 px button exactly, but the lip lives inside the button's own rect, so a press cannot clip.
- Inventory and ApplyItemScreen.
- AchievementsScreen.
- EndCutscene: Lanjut.
- RunResult: its single CTA is mint.
- MinigameWinScreen, MinigameResultPopup and QuitConfirmDialog.

## Decisions taken while planning

| # | Decision | Why |
|---|---|---|
| P1 | **The canonical back arrow stays.** `UI/Nav/return_button.png` is on 11 controls, pinned by `tests/test_back_controls.gd` and `test_ui_icon_refresh.gd`. The new `chevron_left` is used for paging arrows, not for Back. | The back arrow was unified on purpose (2026-09-22). One picture per job. |
| P2 | **SchoolDay's end-of-week "Kembali ke Menu" stays mint.** | It is the only way forward when the week ends (to the Lobby, or TesNotice on the last week), so it is that screen's main action, like RunResult's single CTA. ReportCard's Back is a return, so it goes brown. |
| P3 | **Hapus becomes `SecondaryButton` (brown).** | It clears the unsent answer: routine and reversible, set beside Kirim (mint). Tomato would say "destructive", and `DangerButton` ticks the motor on every clear. |
| P4 | **StudentCard's page arrows keep `StudentCardSecondaryButtonL` (cream, quiet).** Only their picture changes. | A page flip on a paper card is a quiet control. Switching variations would move geometry that `tall_screen_layout` and `student_card_layout` pin. |
| P5 | **Arrows use the Button's own `icon`** (`icon_alignment = 1`, `expand_icon = true`) instead of a rotated child `TextureRect`, which is deleted. | The icon is content, so it sinks with the face when pressed. |
| P6 | **The glyph rule covers pictographs and dingbats, not typography.** Banned: U+2300–23FF, U+2600–27BF, U+2B00–2BFF, U+1F000–1FAFF, U+FE0F. Allowed: the Arrows block (→, U+2190–21FF), ×, and code comments. A small reviewed allowlist covers the two deliberate exceptions: `StatInfo.gd`'s glyph fallback, and CutScene's debug-only 🐛 toggle. | CLAUDE.md: "No emoji as UI iconography." A number that "becomes" another number (`12 → 9`) is typography. |
| P7 | **Phase 3 runs in the Phase 2 worktree** (`focused-williamson-19deed`) on a new branch, not in a new worktree. | The session that ran Phase 2 is pinned to that worktree and may not write into another. The worktree is removed once Phase 3 merges. |

## Global Constraints

- **Worktree.** Work in `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/focused-williamson-19deed/`, on branch `feat/ui-depth-pass-phase3`. **Every path you edit must start with that directory; check it before every Edit or Write.** The parent folder is a different, shared checkout; never touch it.
- **Never use `git stash`.** The stash stack is shared.
- **Editor work belongs to the controller.** Implementers never call godot-ai or MCP tools and never launch Godot. The worktree editor is closed while an implementer works, so `.tscn` text edits are safe.
- **Editing a `.tscn` as text:**
  - Moving a node means changing its `parent="…"` path.
  - Keep `unique_id=` on existing blocks.
  - A new `ext_resource` needs an id that is unique in the file (`ic_…`), and one that nothing references any more is dropped.
  - A property set on an instanced scene's child is dropped on save; only root properties serialise.
  - **Touch only the nodes a task names.** Lobby.tscn, StudentCard.tscn and AturJadwal.tscn are large and shared. After each edit, `git diff --stat` on them must show only the task's hunks.
- **Icon files** (all exist, `.svg`, 256 px class): `Assets/Images/UI/Icons/` holds `nav_jadwal`, `nav_students`, `nav_koperasi`, `nav_inventory`, `nav_rapor`, `chevron_left`, `chevron_right`, `exit`, `close`, `home`, `info`, `music`, `sound`, `vibrate`, `cat_istirahat` and `cat_wirausaha`. Their uids are in the matching `.svg.import` files (`uid="uid://…"`); copy them into the `ext_resource` line.
- **Never touch** these four Lobby rail icons: `setting.png`, `achievement_button.png`, `icon_daily_login.png` and `skin_switch.png`. Leave `UI/Nav/return_button.png` wherever it is used (P1).
- **Tests:**
  - Suites are `McpTestSuite`, `@tool`, and **never coroutines**.
  - Helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_contains`, `track`.
  - Existing suites that pin an old path, variation or string are **updated, never deleted**, and each updated assertion must still prove its intent.
  - Before finishing, `grep -rn` the old path or string across `tests/ Scripts/ Scenes/` and fix every hit.
- **Theme rules:**
  - No new `theme_override_*` except layout-only constants.
  - No runtime `.new()` of Controls in `Scripts/`.
  - After any `ThemeFactory.gd` change, the controller rebakes with `test_run(suite="theme_rebake")` and checks that `grep -c 'type="Script"' Assets/Theme/kejartes_theme.tres` prints 0.
- **Docs:** every script keeps its `##` header and an `##` line on each `@export`/const/function.
- **Clean code:** in `Scripts/`, no bare numbers except 0/1/2/0.5 outside `const` lines, typed vars, and `->` returns. A script listed in `ci/clean_code_baseline.gd` LARGE_SCRIPTS must not grow past its number. A count that shrinks is locked in by lowering its baseline entry; only ever lower numbers.
- **Clean-code gotcha:** `tests/test_audio_coverage.gd`'s double-sfx scan treats every line up to the next `func` as the previous function's body. A comment like `after close() runs` counts as a call, so name sfx-playing functions in comments without parentheses.
- **Commits** follow Conventional Commits with a scope, plus a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Write the message to a file under `<worktree>/.superpowers/sdd/2026-09-29-ui-depth-pass-phase3/`, then run `git -C <worktree> commit -F <file>`. Stage only the task's files.

## Controller loop (every task)

The same loop as Phase 2:
1. **Before dispatch:** the worktree editor is closed.
2. **After the handback:**
   - `git -C <main checkout> status --short` shows no new changes.
   - `git stash list` is unchanged.
   - Read the diff.
3. **Launch this worktree's editor detached**, redirecting its console output to a scratchpad log:

   ```
   cmd /c ""<exe>" --path "<worktree>" -e > "<log>" 2>&1"
   ```

   Use Win32_Process Create, pass the `session_id`, then read the log for `ERROR`.
4. **Run the task's suites** plus the gate set: `script_documentation`, `clean_code`, `viewport_editability`, `audio_coverage` and `popup_frames`.
5. **Render** the touched screens with the throwaway screenshot harness (memory: popup-screenshot-harness). Judge the icons at full size.
6. **Close the editor** and revert `Assets/Audio/default_bus_layout.tres`.

---

## File Structure

| File | Task | Change |
|---|---|---|
| `Scenes/Lobby/Lobby.tscn` | 1 | Five tile `icon` references. |
| `Scenes/MainMenu/MainMenu.tscn`, `tests/test_main_menu.gd` | 1 | QuitButton icon. |
| `Scenes/LevelSelect/LevelSelect.tscn`, `Scenes/StudentCard/StudentCard.tscn`, `Scenes/StudentList/StudentList.tscn`, `Scenes/ReportCard/ReportCard.tscn` (+ tests) | 2 | Arrows. |
| `Scripts/StudentList/RosterCard.gd`, `Scripts/AturJadwal/DayStickyNote.gd`, `Scenes/Lobby/DapatkanUang.tscn` (+ tests) | 3 | Category icons. |
| `Scenes/ReportCard/ReportCard.tscn`, `Scenes/Minigames/Akademis/Password.tscn`, `Variabel.tscn` (+ tests) | 4 | Roles. |
| The glyph sites listed in Task 5, and `tests/test_ui_text_glyphs.gd` (new) | 5 | Glyphs. |
| `Scripts/Design/ThemeFactory.gd`, `tests/test_theme_factory.gd` (only if the render shows a crescent) | 6 | Chip gloss. |
| `docs/superpowers/design/style-guide.md`, `DEBT.md`, `CHANGELOG.md`, `CLAUDE.md`, `Assets/Images/UI/Icons/README.md` | 7 | Docs. |

---

### Task 1: The Lobby tiles and MainMenu's exit wear the new icons

**Files:**
- Modify: `Scenes/Lobby/Lobby.tscn`: the `icon` of five Buttons and their `ext_resource` lines, nothing else.
- Modify: `Scenes/MainMenu/MainMenu.tscn`: QuitButton's `icon`.
- Modify: `tests/test_main_menu.gd` (~194–200).
- Create: `tests/test_lobby_tile_icons.gd`.

**Interfaces:** Produces the Lobby's tile → icon mapping, which Task 7's docs describe.

The mapping (node paths from the survey):

| Button (in Lobby.tscn) | Old `icon` | New `icon` |
|---|---|---|
| `Safe/UI/Hud/BookHud/RaisedBlock/RaisedPage/Student` | `Assets/Images/UI/Nav/icon_cta_student.png` | `Assets/Images/UI/Icons/nav_students.svg` |
| `Safe/UI/Hud/BookHud/RaisedBlock/RaisedPage/Jadwal` | `Assets/Images/UI/Nav/icon_cta_jadwal.png` | `Assets/Images/UI/Icons/nav_jadwal.svg` |
| `Safe/UI/Hud/BookHud/Shelf/ShelfPage/Koperasi` | `Assets/Images/UI/Nav/icon_nav_koperasi.png` | `Assets/Images/UI/Icons/nav_koperasi.svg` |
| `Safe/UI/Hud/BookHud/Shelf/ShelfPage/Inventory` | `Assets/Images/UI/Nav/icon_nav_inventory.png` | `Assets/Images/UI/Icons/nav_inventory.svg` |
| `Safe/UI/Hud/BookHud/Shelf/ShelfPage/ReportStudent` | `Assets/Images/UI/Nav/icon_nav_rapor.png` | `Assets/Images/UI/Icons/nav_rapor.svg` |

In MainMenu.tscn, `SafeArea/Content/IconBar/QuitButton`'s `icon` changes from `Assets/Images/UI/icon_exit.svg` to `Assets/Images/UI/Icons/exit.svg`.

- [ ] **Step 1: Write the failing test** `tests/test_lobby_tile_icons.gd`:

```gdscript
@tool
extends McpTestSuite

## UI depth pass Phase 3 (docs/superpowers/plans/2026-09-29-ui-depth-pass-phase3.md):
## the Lobby's five nav tiles wear the Icons/ set, so the owner's chunky
## icons drop in at those paths with no scene change. The four rail icons
## (settings, achievements, daily login, skins) are finished art and stay.
##
## Must be @tool; no test here may be a coroutine.

const LOBBY := "res://Scenes/Lobby/Lobby.tscn"
## Tile node path -> the icon it must wear.
const TILES := {
	"Safe/UI/Hud/BookHud/RaisedBlock/RaisedPage/Student": "res://Assets/Images/UI/Icons/nav_students.svg",
	"Safe/UI/Hud/BookHud/RaisedBlock/RaisedPage/Jadwal": "res://Assets/Images/UI/Icons/nav_jadwal.svg",
	"Safe/UI/Hud/BookHud/Shelf/ShelfPage/Koperasi": "res://Assets/Images/UI/Icons/nav_koperasi.svg",
	"Safe/UI/Hud/BookHud/Shelf/ShelfPage/Inventory": "res://Assets/Images/UI/Icons/nav_inventory.svg",
	"Safe/UI/Hud/BookHud/Shelf/ShelfPage/ReportStudent": "res://Assets/Images/UI/Icons/nav_rapor.svg",
}
## The retired Nav art no scene may point at any more.
const RETIRED := ["icon_cta_student.png", "icon_cta_jadwal.png", "icon_nav_koperasi.png",
	"icon_nav_inventory.png", "icon_nav_rapor.png"]


func suite_name() -> String:
	return "lobby_tile_icons"


func test_each_tile_wears_its_icons_set_picture() -> void:
	var lobby := (load(LOBBY) as PackedScene).instantiate()
	track(lobby)
	for path in TILES:
		var tile := lobby.get_node_or_null(path) as Button
		assert_true(tile != null, "missing tile " + path)
		if tile != null:
			assert_true(tile.icon != null, path + " has no icon")
			if tile.icon != null:
				assert_eq(tile.icon.resource_path, TILES[path], path)


func test_the_retired_nav_art_is_unreferenced() -> void:
	var src := FileAccess.get_file_as_string(LOBBY)
	for name in RETIRED:
		assert_false(src.contains(name), "Lobby.tscn still references " + name)
```

- [ ] **Step 2: Edit the scenes.**
  - In Lobby.tscn, add five `ext_resource` lines (`type="Texture2D"`, uid from each `.svg.import`, ids `ic_nav_students` … `ic_nav_rapor`).
  - Point the five `icon = ExtResource(...)` lines at them.
  - Delete the five old `ext_resource` lines once nothing references them (grep their ids first).
  - In MainMenu.tscn, do the same for QuitButton.
- [ ] **Step 3: Update `tests/test_main_menu.gd`.** The QuitButton icon assertion (~194–200) expects `res://Assets/Images/UI/Icons/exit.svg`. Keep the SettingButton assertion as it is.
- [ ] **Step 4: Controller** runs `lobby_tile_icons`, `main_menu`, `lobby`, `lobby_hud`, `lobby_style_buttons`, `ui_icon_refresh`, `ui_icons` and the gate set, then renders the Lobby at 1080x1920 and checks each icon sits in its tile's square.
- [ ] **Step 5: Commit** `feat(lobby): the nav tiles and the exit wear the new icon set`.

---

### Task 2: Paging arrows wear the chevrons and sink with the face

**Files:**
- Modify: `Scenes/LevelSelect/LevelSelect.tscn`: `Safe/UI/Stack/PrevArrow`, `NextArrow`.
- Modify: `Scenes/StudentCard/StudentCard.tscn`: `%NextButtonKiri`, `%NextButtonKanan`.
- Modify: `Scenes/StudentList/StudentList.tscn`: `%LeftArrow`, `%RightArrow`.
- Modify: `Scenes/ReportCard/ReportCard.tscn`: `Safe/UI/BottomBar/NextButtonKiri`, `NextButtonKanan`.
- Modify: tests that pin those arrows (see Step 4).
- Create: `tests/test_paging_arrows.gd`.

For each of the eight buttons:
- The **left/previous** arrow gets `icon = <Icons/chevron_left.svg>`; the **right/next** arrow gets `chevron_right.svg`.
- Each also gets `icon_alignment = 1` and `expand_icon = true`.
- For the six that draw the arrow with a child `TextureRect` showing `Placeholders/arrow.png` with a `rotation`, delete that child block. Before deleting, read the scripts: if one reaches the child by path (e.g. `$…/Arrow`) or tweens it, move that reference to the button, or report it.
- ReportCard's two buttons already use `icon`; only the texture changes (from `UI/Nav/icon_chevron_left/right.png`).
- Keep each button's variation, size and anchors (P4).
- Drop `ext_resource` lines left unused, but **not** `Placeholders/arrow.png` in other files: `Scripts/TutorialArrow.gd` still uses it.

- [ ] **Step 1: Write the failing test** `tests/test_paging_arrows.gd`:

```gdscript
@tool
extends McpTestSuite

## UI depth pass Phase 3: every paging arrow is the Button's own icon from
## the Icons/ set -- left is chevron_left, right is chevron_right -- so the
## glyph is content that sinks with the lipped face when pressed, instead
## of a rotated child picture that stayed put.
##
## Must be @tool; no test here may be a coroutine.

const LEFT := "res://Assets/Images/UI/Icons/chevron_left.svg"
const RIGHT := "res://Assets/Images/UI/Icons/chevron_right.svg"
## scene -> [left arrow path, right arrow path].
const ARROWS := {
	"res://Scenes/LevelSelect/LevelSelect.tscn": ["Safe/UI/Stack/PrevArrow", "Safe/UI/Stack/NextArrow"],
	"res://Scenes/StudentCard/StudentCard.tscn": ["%NextButtonKiri", "%NextButtonKanan"],
	"res://Scenes/StudentList/StudentList.tscn": ["%LeftArrow", "%RightArrow"],
	"res://Scenes/ReportCard/ReportCard.tscn": ["Safe/UI/BottomBar/NextButtonKiri", "Safe/UI/BottomBar/NextButtonKanan"],
}


func suite_name() -> String:
	return "paging_arrows"


func _check(scene: Node, path: String, want: String, label: String) -> void:
	var b := scene.get_node_or_null(path) as Button
	assert_true(b != null, label + ": missing " + path)
	if b == null:
		return
	assert_true(b.icon != null and b.icon.resource_path == want,
		"%s: %s must wear %s" % [label, path, want])
	assert_eq(b.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER, label + ": the chevron is centred")
	for child in b.get_children():
		assert_false(child is TextureRect, label + ": " + path + " still draws a child picture")


func test_every_paging_arrow_wears_its_chevron() -> void:
	for scene_path in ARROWS:
		var scene := (load(scene_path) as PackedScene).instantiate()
		track(scene)
		_check(scene, ARROWS[scene_path][0], LEFT, scene_path)
		_check(scene, ARROWS[scene_path][1], RIGHT, scene_path)
```

`%Name` paths resolve on an out-of-tree instance through its owner; if one does not, use the full path from the `.tscn` and say so in the report.

- [ ] **Step 2: Edit the four scenes** as described.
- [ ] **Step 3: Scripts.** Grep `Scripts/LevelSelect`, `Scripts/StudentCard`, `Scripts/StudentList` and `Scripts/ReportCard` for the deleted child's name. Fix any reference.
- [ ] **Step 4: Tests.** Run `grep -rn "arrow.png\|icon_chevron_left\|icon_chevron_right\|NextButtonKiri/Arrow\|LeftArrow/Arrow\|PrevArrow/Arrow" tests/` and update each hit. The survey lists `test_student_card_layout.gd` (arrow geometry, 642–643), `test_student_list.gd` and `test_tall_screen_layout.gd`. Button rects are unchanged, so only child-node assertions should need edits.
- [ ] **Step 5: Controller** runs `paging_arrows`, `level_select`, `student_card`, `student_card_layout`, `student_list`, `report_card`, `tall_screen_layout`, `button_geometry`, `texture_mipmaps` and the gate set, then renders the four screens.
- [ ] **Step 6: Commit** `feat(ui): paging arrows wear the chevrons and sink with the face`.

---

### Task 3: Istirahat and Wirausaha get their category icons

**Files:**
- Modify: `Scripts/StudentList/RosterCard.gd`: the `SPECIALTY_ICONS` entries (~77–84).
- Modify: `Scripts/AturJadwal/DayStickyNote.gd`: its icons dict (~66–67).
- Modify: `Scenes/Lobby/DapatkanUang.tscn`: `TipIcon`'s texture (`Placeholders/icon_wirausaha.svg`).
- Modify: `tests/test_student_list.gd` (the SPECIALTY_ICONS path pins, ~585–598), plus any DayStickyNote or DapatkanUang pin found by grep.
- Create: `tests/test_category_icons.gd`.

The changes:
- In RosterCard's `SPECIALTY_ICONS`, `"Istirahat"` → `preload("res://Assets/Images/UI/Icons/cat_istirahat.svg")` and `"Wirausaha"` → `preload("res://Assets/Images/UI/Icons/cat_wirausaha.svg")`. Keep the preload vs path form the dict already uses.
- In DayStickyNote's dict, `"Wirausaha"` and `"Istirahat"` get the same two icons. The holiday icon stays.
- DapatkanUang's `TipIcon` texture becomes `Icons/cat_wirausaha.svg`.
- Do not delete the old PNGs (other users may exist); Task 7 logs any that became unreferenced.

- [ ] **Step 1: Write the failing test** `tests/test_category_icons.gd`:

```gdscript
@tool
extends McpTestSuite

## UI depth pass Phase 3: the two activity categories that have no stat of
## their own -- Istirahat (rest) and Wirausaha (earning) -- show their own
## icons from the Icons/ set wherever a screen names them, instead of the
## energy bar's glyph, the coin, or generated placeholder PNGs.
##
## Must be @tool; no test here may be a coroutine.

const REST := "res://Assets/Images/UI/Icons/cat_istirahat.svg"
const EARN := "res://Assets/Images/UI/Icons/cat_wirausaha.svg"


func suite_name() -> String:
	return "category_icons"


func test_the_sources_name_the_category_icons() -> void:
	for path in ["res://Scripts/StudentList/RosterCard.gd", "res://Scripts/AturJadwal/DayStickyNote.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, REST, path + " shows Istirahat's own icon")
		assert_contains(src, EARN, path + " shows Wirausaha's own icon")


func test_the_earn_money_tip_shows_the_wirausaha_icon() -> void:
	var panel := (load("res://Scenes/Lobby/DapatkanUang.tscn") as PackedScene).instantiate()
	track(panel)
	var icon := panel.find_child("TipIcon", true, false) as TextureRect
	assert_true(icon != null and icon.texture != null, "the tip has an icon")
	if icon != null and icon.texture != null:
		assert_eq(icon.texture.resource_path, EARN)
```

- [ ] **Step 2: Edit** the two scripts and the scene.
- [ ] **Step 3: Tests.** Grep `stat_energy.png\|uang.png\|icon_wirausaha\|icon_istirahat_placeholder\|icon_wirausaha_placeholder` in `tests/`, and update the pins that concern these three sites only. `uang.png` is the coin everywhere else; leave those.
- [ ] **Step 4: Controller** runs `category_icons`, `student_list`, `day_sticky_note`, `sticky_note_assets`, `dapatkan_uang`, `atur_jadwal` and the gate set, then renders StudentList (a roster with a Wirausaha specialty if the seed has one) and DapatkanUang.
- [ ] **Step 5: Commit** `feat(ui): Istirahat and Wirausaha wear their category icons`.

---

### Task 4: Two buttons get their right role

**Files:**
- Modify: `Scenes/ReportCard/ReportCard.tscn`: `Safe/UI/BackButton` `theme_type_variation` from `&"PrimaryButton"` to `&"SecondaryButton"`.
- Modify: `Scenes/Minigames/Akademis/Password.tscn` and `Variabel.tscn`: `AksiRow/BtnHapus` from `&"LobbyCtaButton"` to `&"SecondaryButton"`. BtnKirim stays `LobbyCtaButton`.
- Modify: `tests/test_report_card.gd` (a variation assertion).
- Create: `tests/test_button_roles_phase3.gd`.

- [ ] **Step 1: Write the failing test** `tests/test_button_roles_phase3.gd`:

```gdscript
@tool
extends McpTestSuite

## UI depth pass Phase 3's role fixes (plan decisions P2, P3). Back is
## brown, like Inventory's, ShopHub's and Settings'; mint is the one
## thing to press. Hapus only clears the unsent answer -- routine and
## reversible, beside Kirim -- so it is brown too: tomato would say
## "destructive", and DangerButton ticks the motor on every clear.
##
## Must be @tool; no test here may be a coroutine.

## scene -> {node path: the variation it must wear}.
const ROLES := {
	"res://Scenes/ReportCard/ReportCard.tscn": {"Safe/UI/BackButton": &"SecondaryButton"},
	"res://Scenes/Minigames/Akademis/Password.tscn": {
		"AksiRow/BtnHapus": &"SecondaryButton", "AksiRow/BtnKirim": &"LobbyCtaButton"},
	"res://Scenes/Minigames/Akademis/Variabel.tscn": {
		"AksiRow/BtnHapus": &"SecondaryButton", "AksiRow/BtnKirim": &"LobbyCtaButton"},
}


func suite_name() -> String:
	return "button_roles_phase3"


func test_each_button_wears_its_role() -> void:
	for scene_path in ROLES:
		var scene := (load(scene_path) as PackedScene).instantiate()
		track(scene)
		for node_path in ROLES[scene_path]:
			var b := scene.get_node_or_null(node_path) as Control
			assert_true(b != null, "%s: missing %s" % [scene_path, node_path])
			if b != null:
				assert_eq(b.theme_type_variation, ROLES[scene_path][node_path],
					"%s: %s" % [scene_path, node_path])
```

- [ ] **Step 2: Edit** the three variation lines. If BtnHapus's parent path differs in Variabel.tscn, use the real path in both the scene and the test.
- [ ] **Step 3: Tests.** Grep `tests/` for `BtnHapus` and for ReportCard's BackButton variation, and update any pin. `test_back_controls.gd` pins only the icon, which does not change.
- [ ] **Step 4: Controller** runs `button_roles_phase3`, `report_card`, `back_controls`, `button_geometry`, `press_feel`, the Password/Variabel suites (grep `tests/` for `Password.tscn`) and the gate set, then renders ReportCard.
- [ ] **Step 5: Commit** `fix(ui): Rapor's back is brown; Hapus clears quietly`.

---

### Task 5: Emoji and dingbats leave the UI text

**Files (the sites the survey found):**

| File | Line (approx.) | Now | Becomes |
|---|---|---|---|
| `Scenes/SchoolSimulation/SchoolDay.tscn` | 183 | `✨ Klik di mana saja untuk melanjutkan ➔` | `Klik di mana saja untuk melanjutkan` |
| `Scenes/SchoolSimulation/SchoolDay.tscn` | 202 | `⏭ Skip (Tekan O)` | `Skip (Tekan O)` |
| `Scripts/SchoolSimulation/SchoolDay.gd` | 73–77 | `end_tutorial_title`/`end_tutorial_text` defaults with 🎓 🎯 ➔ | the same text, glyphs removed (➔ becomes → only where it means "becomes" in a number) |
| `Scripts/AturJadwal/AturJadwal.gd` | 1517 | `"Hari Libur Nasional 📅"` | `"Hari Libur Nasional"` |
| `Scenes/SchoolSimulation/DaySummaryBadge.tscn` | 9 | `✨ BONUS EVENT +15` | `BONUS EVENT +15` |
| `Scenes/SchoolSimulation/DailyDecayOverview.tscn` | 53, 87 | `🌅 Aktivitas & Evaluasi Harian`, `Lanjutkan Hari ➔` | `Aktivitas & Evaluasi Harian`, `Lanjutkan Hari` |
| `Scripts/SchoolSimulation/DailyDecayOverview.gd` | 22, 174, 191, 192, 198, 204 | `🌅 …(%s)`, `💬 %s`, `Energy ⚡`, `Mood 😊`, `%d ➔ %d (-%d)` ×2 | `Aktivitas & Evaluasi Harian (%s)`, `%s`, `Energy`, `Mood`, `%d → %d (-%d)` ×2 |
| `Scripts/CutScene/CutScene.gd` | 124 | `"⏩ Skip Intro"` | `"Skip Intro"` (the 🐛 debug toggle at 102/133 stays; see P6) |
| `Scenes/AturJadwal/DayStickyNote.tscn` | 105 | a Label with `text = "🔒"` | a `TextureRect` of the same name and layout, `texture` = `Assets/Images/UI/Placeholders/icon_lock.svg`, `expand_mode = 1`, `stretch_mode = 5`, `mouse_filter = 2` (read `DayStickyNote.gd` for how it uses the node; a script that sets `.text` on it must set nothing, since the picture is authored) |

**Also:**
- Modify: every test that pins one of those strings (grep each old string in `tests/`).
- Create: `tests/test_ui_text_glyphs.gd`.

- [ ] **Step 1: Write the failing test** `tests/test_ui_text_glyphs.gd`:

```gdscript
@tool
extends McpTestSuite

## "No emoji as UI iconography" (CLAUDE.md), kept by a test (UI depth pass
## Phase 3, plan decision P6). A pictograph or dingbat typed into UI text
## renders in whatever emoji font the phone has, at the wrong weight and
## colour; the Icons/ set is the picture channel. Scans every .tscn and .gd
## under Scenes/ and Scripts/ except the minigames' internals and the debug
## overlay (both outside the design system), skipping comments. Typography
## stays allowed: the Arrows block (12 → 9) and ×.
##
## Must be @tool; no test here may be a coroutine.

## Banned code-point ranges: misc technical (fast-forward and skip marks),
## misc symbols and dingbats (bolts, sparkles, heavy arrows), misc symbols
## and arrows extended, the emoji planes, and the emoji-presentation
## selector.
const BANNED := [[0x2300, 0x23FF], [0x2600, 0x27BF], [0x2B00, 0x2BFF],
	[0x1F000, 0x1FAFF], [0xFE0F, 0xFE0F]]
## Folders outside the design system.
const SKIP_DIRS := ["res://Scenes/Minigames", "res://Scripts/Minigames", "res://Scripts/Debug"]
## Reviewed exceptions: file -> substrings a line may carry.
const ALLOWED := {
	# The stat glyph is the no-icon fallback StatDetailPopup shows when a
	# screen passes no artwork; every current caller passes one.
	"res://Scripts/UI/StatInfo.gd": ["\"glyph\":"],
	# The cutscene's debug-only level-select toggle.
	"res://Scripts/CutScene/CutScene.gd": ["Debug Level Select"],
}


func suite_name() -> String:
	return "ui_text_glyphs"


## `line` without a trailing GDScript comment: the first `#` outside a
## double-quoted string ends the code.
func _code_of(line: String) -> String:
	var in_str := false
	for i in line.length():
		var c := line[i]
		if c == "\"":
			in_str = not in_str
		elif c == "#" and not in_str:
			return line.substr(0, i)
	return line


func _banned(text: String) -> String:
	for i in text.length():
		var cp := text.unicode_at(i)
		for r in BANNED:
			if cp >= r[0] and cp <= r[1]:
				return text[i]
	return ""


func _allowed(path: String, line: String) -> bool:
	for needle in ALLOWED.get(path, []):
		if line.contains(needle):
			return true
	return false


func _scan(dir_path: String, hits: Array[String]) -> void:
	if dir_path in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub), hits)
	for file in dir.get_files():
		if not (file.ends_with(".tscn") or file.ends_with(".gd")):
			continue
		var path := dir_path.path_join(file)
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := _code_of(line) if file.ends_with(".gd") else line
			var hit := _banned(code)
			if hit != "" and not _allowed(path, line):
				hits.append("%s:%d %s" % [path, n, hit])


func test_no_ui_text_carries_an_emoji_or_dingbat() -> void:
	var hits: Array[String] = []
	_scan("res://Scenes", hits)
	_scan("res://Scripts", hits)
	assert_eq(hits.size(), 0, "glyphs in UI text:\n" + "\n".join(hits))
```

- [ ] **Step 2: Edit** each site in the table.
- [ ] **Step 3: Tests.** Grep `tests/` for each old string (e.g. `Skip (Tekan O)`, `Hari Libur Nasional`, `BONUS EVENT`, `Aktivitas & Evaluasi`, `Lanjutkan Hari`, `Skip Intro`, and the lock glyph) and update the pins. `test_minigame_result_popup.gd`'s emoji list is that suite's own ban, so leave it.
- [ ] **Step 4:** If the new suite still finds a hit that is not in the table, fix it the same way. If it is a deliberate exception, add it to `ALLOWED` with a comment, and report it.
- [ ] **Step 5: Controller** runs `ui_text_glyphs`, `school_day`, `day_summary`, `atur_jadwal`, `day_sticky_note`, `sticky_note_assets`, `cutscene` and the gate set, then renders SchoolDay's end-of-week state if reachable (otherwise the scene as authored) and AturJadwal's day notes.
- [ ] **Step 6: Commit** `fix(ui): emoji and dingbats leave the UI text; a suite keeps them out`.

---

### Task 6: The trait chips' gloss

**Files (only if Step 1 shows a crescent):**
- Modify: `Scripts/Design/ThemeFactory.gd`, near the chip block (~1318–1350).
- Modify: `tests/test_theme_factory.gd`.

- [ ] **Step 1 (controller): Render and judge.** Render StudentList at 1080x1920 with a seeded roster and crop the trait row (Specialty, Persona and Quirk chips, M step, 96 px tall). The question: does the 14 px gloss band, tapering to zero across each 48 px end-cap, read as a pale crescent on the pill's top edge rather than an even highlight?
  - **If it reads fine:** record "checked, 14 px reads as a highlight on a 96 px pill" in the ledger and in Task 7's CHANGELOG entry, and end the task with no code change.
  - **If it reads as a crescent:** do Steps 2–5.
- [ ] **Step 2: Write the failing test** in `tests/test_theme_factory.gd`:

```gdscript
## UI depth pass Phase 3: on a pill a fixed 14 px gloss band tapers across
## the whole end-cap and reads as a crescent, so the three trait chips (and
## their size steps) carry a thinner band.
func test_trait_chips_carry_a_thin_gloss() -> void:
	var theme: Theme = load("res://Assets/Theme/kejartes_theme.tres")
	for chip in ["SpecialtyBadge", "PersonaBadge", "QuirkBadge",
			"SpecialtyBadgeS", "PersonaBadgeS", "QuirkBadgeS",
			"SpecialtyBadgeM", "PersonaBadgeM", "QuirkBadgeM"]:
		if not theme.has_stylebox(&"normal", chip):
			continue
		var sb := theme.get_stylebox(&"normal", chip) as StyleBoxFlat
		assert_eq(sb.border_width_top, ThemeFactory.CHIP_GLOSS_WIDTH, chip)
```

- [ ] **Step 3: Implement.** In ThemeFactory.gd add:

```gdscript
## The trait chips' gloss band, px: thinner than LippedBox.GLOSS_WIDTH,
## because on a pill a 14 px band tapers across the whole end-cap and
## reads as a crescent (UI depth pass Phase 3).
const CHIP_GLOSS_WIDTH := 6
```

  After the chip size-step loop, for each chip name and each size suffix (`""`, `"S"`, `"M"` if it exists), and for each state in `["normal", "hover", "pressed", "disabled"]`: if the stylebox is a `StyleBoxFlat` with `border_width_top > 0`, set `border_width_top = CHIP_GLOSS_WIDTH`. Keep it in one helper function, `_thin_chip_gloss(theme)`, with a `##` line.
- [ ] **Step 4: Controller** runs `theme_rebake`, then `theme_factory`, `lipped_box`, `button_geometry` and `student_list`. It checks that the bake has 0 scripts, re-renders the chips, and restarts the editor before any scene save (memory: rebake-alone-never-beside-scene-ops).
- [ ] **Step 5: Commit** `fix(theme): trait chips carry a thin gloss` with `Assets/Theme/kejartes_theme.tres`.

---

### Task 7: Docs, the screenshot pass, the full run and ship

- [ ] **Step 1: Docs.**
  - **Style guide:** a short "Icons" paragraph covers which job uses which `Icons/` file (tiles, chevrons, exit, categories), notes that Back keeps `return_button.png` (P1), and states the glyph rule and its suite.
  - **`Assets/Images/UI/Icons/README.md`:** a "Where each icon is used" table.
  - **DEBT:**
    - delete the `Hapus` bullet;
    - add a bullet for art now unreferenced by any scene or script (grep first): the five `UI/Nav/icon_cta_*`/`icon_nav_*`, `UI/icon_exit.svg`, `UI/Nav/icon_chevron_left/right.png`, and the Istirahat/Wirausaha placeholder PNGs;
    - note that SettingButton's `setting.png` has no `Icons/` counterpart yet;
    - close the "UI depth pass, Phases 2–3" entry if nothing else in it remains open.
  - **CHANGELOG:** a newest-first "UI depth pass, Phase 3" entry covering P1–P7 and the chip verdict.
  - **CLAUDE.md:** the suite count after the full run (and nothing else, unless a rule changed).
- [ ] **Step 2: Screenshot pass (controller).**
  - Render at 1080x1920 and 1080x2400, with the throwaway harness, every screen in the spec's list: the Lobby, MainMenu, LevelSelect, StudentCard, StudentList, AturJadwal, SchoolDay, ResultCheckup, ShopHub, Koperasi, Inventory, ReportCard, Achievements, EndCutscene, RunResult, MinigameWinScreen and MinigameResultPopup.
  - Check the icons, the roles and that no glyphs remain.
  - Send a contact sheet to the owner.
- [ ] **Step 3: Final whole-branch review, full run, `code-review` high, and ship** with the `ship-pr` skill (the Phase 2 recipe: bind the PR and set the monitor, then stamp only the tested commit).

---

## Self-review

- **Spec coverage (Rollout step 3):**
  - Lobby tile icons: Task 1.
  - MainMenu, LevelSelect, StudentCard, StudentList, AturJadwal: Tasks 1, 2, 3 and 5.
  - SchoolDay HUD and ResultCheckup: Task 5; ResultCheckup checked OK.
  - ShopHub, Koperasi, Inventory, ReportCard, Achievements: Tasks 2 and 4, the rest checked OK.
  - End-game screens and MinigameWinScreen/MinigameResultPopup: checked OK.
  - The Hapus role: Task 4.
  - The chip crescent: Task 6.
  - The screenshot pass: Task 7.
  - "Retired Nav icons": Tasks 1 and 7.
- **Placeholders:** Task 6's fix is conditional on a render, and both branches are spelled out.
- **Names:** `CHIP_GLOSS_WIDTH`, `_thin_chip_gloss`, and the suites `lobby_tile_icons`, `paging_arrows`, `category_icons`, `button_roles_phase3` and `ui_text_glyphs`.
