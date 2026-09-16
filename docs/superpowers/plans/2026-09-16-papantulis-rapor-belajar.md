# Papan tulis, Rapor and the Belajar button — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Swap AturJadwal's board for `papantulis.png` with headroom for tall phones, make Rapor fill the screen the way StudentCard does, and put StudentCard's BELAJAR button back on screen.

**Architecture:** All three are layout changes in `.tscn` files, driven through the Godot editor bridge, plus two small script edits. Each follows the four rules of `docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md`: backgrounds fill and cover, UI sits on its edge inside a `SafeAreaMargin`, and a picture carries its items as one fixed-size piece.

**Spec:** `docs/superpowers/specs/2026-09-16-papantulis-rapor-belajar-design.md`

**Tech Stack:** Godot 4.6.2, GDScript, the `godot-ai` MCP bridge, `McpTestSuite` suites in `tests/`.

## Global Constraints

- **Work in the main checkout on branch `feat/papantulis-rapor-belajar`.** The editor bridge is attached there. This deviates from the usual worktree rule because the bridge is single-client and the Phase 1 spec mandates the main checkout.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through `scene_open` → `node_create` / `node_set_property` / `node_manage` / `batch_execute` → `scene_save`.
- **Do scene work first, script work second.** After any `script_patch`, restart the editor before the next `scene_save`, or the editor writes its stale script tab back over the patch.
- **After every `scene_save`, run `git diff HEAD -- '*.gd'`** and `git checkout --` anything you were not editing.
- **Never stage:** the uncommitted `window/size/window_*_override` lines in `project.godot`, the `*.png.import` churn under `Assets/Images/MuridPotrait/` and `Assets/Images/SplashArtMurid/`, `Assets/Audio/default_bus_layout.tres`, `addons/godot_ai/utils/update_activation_runner.gd(.uid)`. Stage files by name, never `git add -A`.
- **Every suite is `@tool`, extends `McpTestSuite`, and no test may be a coroutine** — the runner calls `suite.call(name)` without awaiting.
- **Every `@export` and every script needs a `##` doc line** (`tests/test_script_documentation.gd`).
- **No `theme_override_*`.** Use a `ThemeFactory` type variation.
- **`node_create` appends last**, so fix z-order with `node_manage(op="move")`. `anchors_preset` is inert — set the four anchors. Numbers are unquoted.
- **MCP calls in this project's client require every parameter explicitly**, including empty `session_id`, `test_name`, `exclude_test_name`, and `params`.
- **Prefer targeted `test_run(suite=...)`.** A full run drops the bridge; budget one editor restart for it, at the end.
- Indonesian for game-facing identifiers and UI text; English for systems code.

---

### Task 0: Branch and land the spec

**Files:**
- Create: `docs/superpowers/specs/2026-09-16-papantulis-rapor-belajar-design.md` (already written, uncommitted)
- Create: `docs/superpowers/plans/2026-09-16-papantulis-rapor-belajar.md` (this file, uncommitted)

**Interfaces:**
- Consumes: nothing.
- Produces: the branch every later task commits to.

- [ ] **Step 1: Confirm the user has agreed to close Godot, then close it**

The editor holds ~70 scene tabs and ~24 script tabs loaded from the current HEAD. `origin/Textures` is 16 commits ahead and rewrites 80 files, so the editor must not be open across the switch.

```bash
powershell -Command "Get-Process Godot_v4.6.2-stable_win64 | Stop-Process -Force"
```

Kill only `Godot_v*.exe`. Leave every `godot-ai.exe` alone.

- [ ] **Step 2: Branch from `origin/Textures`**

```bash
git fetch origin && git switch -c feat/papantulis-rapor-belajar origin/Textures
```

Expected: the branch is created at `5ad34ef` or later. The uncommitted `.import` and `project.godot` changes carry across untouched.

- [ ] **Step 3: Relaunch the editor and confirm the bridge**

```bash
powershell -Command "Start-Process 'C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe' -ArgumentList '--path','C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project','-e'"
```

Then `editor_state(session_id="")` until `readiness` is `ready`. Open the main scene so suites do not report a `scene_warning`:
`scene_open(path="res://Scenes/MainMenu/main_menu.tscn", force_reload=false, session_id="")`.

- [ ] **Step 4: Confirm the tree is sane before any work**

Run: `test_run(suite="tall_screen_layout", test_name="", exclude_test_name="", session_id="", verbose=false)`
Expected: PASS. If it fails, stop — the base is broken, not your change.

- [ ] **Step 5: Commit the spec and the plan**

```bash
git add docs/superpowers/specs/2026-09-16-papantulis-rapor-belajar-design.md docs/superpowers/plans/2026-09-16-papantulis-rapor-belajar.md
git commit -F -
```

Message (write to a file and use `git commit -F`; PowerShell 5.1 splits a here-string at embedded quotes):

```
docs(spec): papan tulis, Rapor fill and the Belajar button

Continues the 2026-09-15 tall-phone pass with the two Phase 2 screens
the user asked for, plus the StudentCard defect Phase 1 left behind.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

### Task 1: AturJadwal's board becomes `papantulis.png`

**Files:**
- Create: `Assets/Images/UI/papantulis.png`
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` — `BGHari`, its five note children, a new `BoardFill`
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `BGHari` at anchors `(0,0,0,0)` offsets `(0, 493, 1080, 2413)` on `res://Assets/Images/UI/papantulis.png`; a `ColorRect` named `BoardFill` at child index 2.

- [ ] **Step 1: Copy the art in and let the editor import it**

```bash
cp /c/Users/user/Downloads/papantulis.png "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/Assets/Images/UI/papantulis.png"
```

Then `filesystem_manage(op="scan", params={}, session_id="")`. Expected: `scan_completed: true`, and `Assets/Images/UI/papantulis.png.import` appears.

- [ ] **Step 2: Write the failing tests**

Replace `test_the_whiteboard_is_unchanged_and_notes_are_stickynotes` in `tests/test_atur_jadwal.gd` (it currently pins `whiteboard.png`) with the two tests below, and add the third.

```gdscript
## The board is papantulis.png, drawn 1:1 as a fixed 1080x1920 picture unit
## pinned 493px down -- 766 minus the art's own shelf row 273 -- so the art's
## baked shelf lands exactly on the ShelfFace/ShelfEdge ColorRects at 766-843
## and cannot drift on a taller viewport. Its board face then reaches y 2413,
## which covers a 20:9 phone's 2400 with room to spare. Any scale other than
## 1:1 slides the baked shelf bands out from under the ColorRects.
func test_the_board_is_papantulis_pinned_so_its_shelf_cannot_move() -> void:
	var board := _screen.get_node_or_null("BGHari") as TextureRect
	assert_true(board != null, "BGHari is gone")
	assert_eq(board.texture.resource_path, "res://Assets/Images/UI/papantulis.png",
		"the board must draw papantulis.png")
	assert_eq(Vector4(board.anchor_left, board.anchor_top,
		board.anchor_right, board.anchor_bottom), Vector4.ZERO,
		"the board is a fixed picture unit, not a stretching full-rect node")
	assert_eq(Vector4(board.offset_left, board.offset_top,
		board.offset_right, board.offset_bottom),
		Vector4(0, 493, 1080, 2413),
		"the board keeps its 1080x1920 art 1:1, with its shelf row on 766")


## The five notes are children of the board, so they ride it as one piece.
## Their offsets are in the board's local space, which now starts 493px down
## the screen, so each sits 493 above where it used to -- and lands on the
## same screen pixel as before.
func test_the_sticky_notes_ride_the_board_at_their_old_screen_rows() -> void:
	var want := {
		"Senin": Vector2(507, 774), "Selasa": Vector2(713, 980),
		"Rabu": Vector2(524, 791), "Kamis": Vector2(921, 1188),
		"Jumat": Vector2(933, 1200),
	}
	for day in want:
		var note := _screen.get_node_or_null("BGHari/%s" % day) as DayStickyNote
		assert_true(note != null, "sticky note %s is gone or was reparented" % day)
		if note == null:
			continue
		assert_eq(Vector2(note.offset_top, note.offset_bottom), want[day],
			"%s must keep its screen row" % day)
		var paper := note.get_node_or_null("Paper") as TextureButton
		assert_true(paper != null and paper.texture_normal != null
			and paper.texture_normal.resource_path == "res://Assets/Images/UI/stickynotes.png",
			"%s Paper must still draw stickynotes.png" % day)


## Below 2413 the art runs out. BoardFill continues it in the art's own
## bottom-centre tone for any screen taller than that -- a 21:9 phone gets
## 2520 -- and is invisible at every height up to it, because the opaque
## board draws over it. It sits above the splash and below the board, so the
## z-order the top band depends on is unchanged.
func test_board_fill_continues_the_board_past_the_art() -> void:
	var fill := _screen.get_node_or_null("BoardFill") as ColorRect
	assert_true(fill != null, "BoardFill is missing")
	if fill == null:
		return
	assert_eq(Vector4(fill.anchor_left, fill.anchor_top,
		fill.anchor_right, fill.anchor_bottom), Vector4(0, 0, 1, 1),
		"BoardFill follows the screen's bottom edge")
	assert_eq(Vector4(fill.offset_left, fill.offset_top,
		fill.offset_right, fill.offset_bottom), Vector4(0, 843, 0, 0),
		"BoardFill starts under the shelf and runs to the bottom")
	assert_eq(fill.color, Color(0.8784314, 0.8784314, 0.8784314, 1.0),
		"BoardFill matches the art's bottom-centre tone")
	assert_eq(fill.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"BoardFill is art: no clicks")
	var splash := _screen.get_node_or_null("TextureButton")
	var board := _screen.get_node_or_null("BGHari")
	assert_true(splash.get_index() < fill.get_index()
		and fill.get_index() < board.get_index(),
		"BoardFill draws over the splash and under the board")
```

Also update the stale comment on `test_top_band_matches_the_mockup`: the two lines reading `whiteboard.png is transparent above y~766` become `papantulis.png is transparent above its own row 273, which the board's 493px offset puts at screen 766`.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `test_run(suite="atur_jadwal", test_name="", exclude_test_name="", session_id="", verbose=false)`
Expected: FAIL — `the board must draw papantulis.png`, `Senin must keep its screen row`, `BoardFill is missing`.

- [ ] **Step 4: Retexture and re-anchor the board, and move its notes**

```
scene_open(path="res://Scenes/AturJadwal/atur_jadwal.tscn", force_reload=false, session_id="")
```

Then one `batch_execute(commands=[...], undo=true, session_id="")` with `set_property` for each of:

| path | property | value |
|---|---|---|
| `/AturJadwal/BGHari` | `texture` | `res://Assets/Images/UI/papantulis.png` |
| `/AturJadwal/BGHari` | `anchor_right` | `0` |
| `/AturJadwal/BGHari` | `anchor_bottom` | `0` |
| `/AturJadwal/BGHari` | `offset_left` | `0` |
| `/AturJadwal/BGHari` | `offset_top` | `493` |
| `/AturJadwal/BGHari` | `offset_right` | `1080` |
| `/AturJadwal/BGHari` | `offset_bottom` | `2413` |
| `/AturJadwal/BGHari/Senin` | `offset_top` | `507` |
| `/AturJadwal/BGHari/Senin` | `offset_bottom` | `774` |
| `/AturJadwal/BGHari/Selasa` | `offset_top` | `713` |
| `/AturJadwal/BGHari/Selasa` | `offset_bottom` | `980` |
| `/AturJadwal/BGHari/Rabu` | `offset_top` | `524` |
| `/AturJadwal/BGHari/Rabu` | `offset_bottom` | `791` |
| `/AturJadwal/BGHari/Kamis` | `offset_top` | `921` |
| `/AturJadwal/BGHari/Kamis` | `offset_bottom` | `1188` |
| `/AturJadwal/BGHari/Jumat` | `offset_top` | `933` |
| `/AturJadwal/BGHari/Jumat` | `offset_bottom` | `1200` |

`anchor_left` and `anchor_top` are already 0. Leave `expand_mode = 1`; with a rect exactly the texture's size it draws 1:1 either way, and leaving it matches the neighbouring nodes.

- [ ] **Step 5: Add `BoardFill` and put it in the z-order**

```
node_create(parent_path="", name="BoardFill", type="ColorRect", scene_path="", scene_file="", session_id="")
```

Then set, in one `batch_execute`: `layout_mode` = `1`, `anchor_left` = `0`, `anchor_top` = `0`, `anchor_right` = `1`, `anchor_bottom` = `1`, `offset_left` = `0`, `offset_top` = `843`, `offset_right` = `0`, `offset_bottom` = `0`, `color` = `"#e0e0e0"`, `mouse_filter` = `2`.

`node_create` appends last, so move it to index 2 (after `Backdrop` at 0 and `TextureButton` at 1):

```
node_manage(op="move", params={"path": "/AturJadwal/BoardFill", "index": 2}, session_id="")
```

`layout_mode = 1` must be set before the anchors: a `Control` created under a plain `Control` starts in position mode, where anchors are not saved.

- [ ] **Step 6: Save and check nothing else moved**

```
scene_save(session_id="")
```

```bash
git diff HEAD -- '*.gd'
```

Expected: empty. If a script you were not editing appears, `git checkout --` it — that is the editor writing a stale tab back.

```bash
git diff --stat HEAD -- Scenes/
```

Expected: only `Scenes/AturJadwal/atur_jadwal.tscn`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `test_run(suite="atur_jadwal", test_name="", exclude_test_name="", session_id="", verbose=false)`
Expected: PASS, all tests.

- [ ] **Step 8: Look at it**

`project_run` to the game, use the debug overlay (F1 or five taps top-right) → General → **⚡ Seed Playtest State**, then Scenes → **AturJadwal**. Confirm the shelf line, the board and the five notes are exactly where they were. Then set `window/size/window_height_override` to `800` in `project.godot` (width stays 360), run again for a 1080×2400 viewport, and confirm the board reaches the bottom with no wall showing and no doubled shelf. **Set the override back to 640 afterwards and never commit it.**

- [ ] **Step 9: Commit**

```bash
git add Assets/Images/UI/papantulis.png Assets/Images/UI/papantulis.png.import Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd
git commit -F <message file>
```

```
feat(atur-jadwal): papan tulis art with headroom for tall phones

BGHari stops stretching with the viewport and becomes a fixed 1080x1920
picture unit pinned 493px down, so papantulis.png's baked shelf lands
exactly on the ShelfFace/ShelfEdge ColorRects and the board reaches
y 2413. BoardFill continues it past that for a 21:9 screen.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

### Task 2: Rapor fills the screen

**Files:**
- Modify: `Scenes/ReportCard/report_card.tscn`
- Modify: `Scripts/ReportCard/report_card.gd:43-46`
- Test: `tests/test_tall_screen_layout.gd`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `Safe/UI/BottomBar` on Rapor, and `%NextButtonKanan`, `%NextButtonKiri`, `%PageLabel`, `%BackButton` as unique names.

- [ ] **Step 1: Write the failing tests**

Append a Rapor section to `tests/test_tall_screen_layout.gd`, after the StudentList section and before `test_unique_name_paths_are_not_format_strings`. It reuses the suite's existing `_scene`, `_stood_up`, `_anchors`, `_offsets`, `_assert_background_fills`, `_assert_under_safe_area`, `_assert_placed` and `_authored_rect` helpers.

```gdscript
# ── Rapor ────────────────────────────────────────────────────────────────────

const REPORT_CARD := "res://Scenes/ReportCard/report_card.tscn"


## Rapor was StudentCard before the tall-phone pass: a root inset by
## 70/254/-77/-352 with every child carrying a negative offset that cancels
## it. The inset is gone and the desk fills, which is what closes the 480px
## of empty grey a 1080x2400 phone used to show below it.
func test_report_card_backdrop_fills() -> void:
	var rapor := _scene(REPORT_CARD)
	assert_eq(_offsets(rapor), Vector4.ZERO, "the Rapor root is not inset")
	_assert_background_fills(rapor.get_node_or_null("Backdrop") as TextureRect,
		"Rapor Backdrop")


## Each paper sheet is Center-anchored at its 1080x1920 rect, as
## StudentCard's are, so the stack sits centred on any screen.
func test_report_card_papers_are_centred() -> void:
	var rapor := _scene(REPORT_CARD)
	for i in range(1, 7):
		var sheet := rapor.get_node_or_null("KertasMurid%d" % i) as Control
		assert_true(sheet != null, "missing KertasMurid%d" % i)
		if sheet == null:
			continue
		assert_eq(_anchors(sheet), Vector4(0.5, 0.5, 0.5, 0.5),
			"KertasMurid%d is Center-anchored" % i)
		assert_eq(_offsets(sheet), Vector4(-540, -960, 540, 960),
			"KertasMurid%d stays 1080x1920" % i)


## Title and KEMBALI on the top edge, page arrows and page label in a Bottom
## Wide bar, all inside the safe area -- the same group StudentCard carries.
func test_report_card_ui_is_pinned_inside_the_safe_area() -> void:
	var rapor := _scene(REPORT_CARD)
	_assert_under_safe_area(rapor.get_node_or_null("%PilihMurid"), "PilihMurid")
	_assert_under_safe_area(rapor.get_node_or_null("%BackButton"), "BackButton")
	var bar := rapor.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "Rapor needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets taps through")
	for n in ["NextButtonKiri", "NextButtonKanan", "PageLabel"]:
		var c := rapor.get_node_or_null("%" + n)
		assert_true(c != null and c.get_parent() == bar, n + " rides in BottomBar")


## On a 1080x2400 phone the paper sits 240px down, centred, and the page row
## rides the bottom edge instead of stopping at 1920.
func test_report_card_on_a_tall_phone() -> void:
	var rapor := _stood_up(REPORT_CARD, TALL)
	_assert_placed((rapor.get_node("Backdrop") as Control),
		Rect2(0, 0, 1080, 2400), "Backdrop")
	_assert_placed((rapor.get_node("KertasMurid1") as Control),
		Rect2(0, 240, 1080, 1920), "KertasMurid1")
	_assert_placed((rapor.get_node("%NextButtonKanan") as Control),
		Rect2(870, 2260, 120, 120), "NextButtonKanan")
	assert_eq(_authored_rect(rapor.get_node("%PilihMurid") as Control).position,
		Vector2(160, 82), "the title stays at the top")


## At 1080x1920 every piece of Rapor is exactly where it was.
func test_report_card_at_the_design_size_is_unchanged() -> void:
	var rapor := _stood_up(REPORT_CARD, DESIGN)
	_assert_placed((rapor.get_node("KertasMurid1") as Control),
		Rect2(0, 0, 1080, 1920), "KertasMurid1")
	_assert_placed((rapor.get_node("%NextButtonKiri") as Control),
		Rect2(90, 1780, 120, 120), "NextButtonKiri")
	_assert_placed((rapor.get_node("%NextButtonKanan") as Control),
		Rect2(870, 1780, 120, 120), "NextButtonKanan")
	assert_eq(_authored_rect(rapor.get_node("%PageLabel") as Control).position,
		Vector2(440, 1805), "PageLabel")
	assert_eq(_authored_rect(rapor.get_node("%PilihMurid") as Control).position,
		Vector2(160, 82), "PilihMurid")
	assert_eq(_authored_rect(rapor.get_node("%BackButton") as Control).position,
		Vector2(90, 82), "BackButton")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="tall_screen_layout", test_name="report_card", exclude_test_name="", session_id="", verbose=false)`
Expected: FAIL — `the Rapor root is not inset`, `Rapor needs Safe/UI/BottomBar`.

- [ ] **Step 3: Un-inset the root, fill the backdrop, centre the papers**

```
scene_open(path="res://Scenes/ReportCard/report_card.tscn", force_reload=false, session_id="")
```

The scene root node is named `StudentCard` (Rapor was copied from it). One `batch_execute` of `set_property`:

| path | property | value |
|---|---|---|
| `/StudentCard` | `offset_left` | `0` |
| `/StudentCard` | `offset_top` | `0` |
| `/StudentCard` | `offset_right` | `0` |
| `/StudentCard` | `offset_bottom` | `0` |
| `/StudentCard/Backdrop` | `layout_mode` | `1` |
| `/StudentCard/Backdrop` | `anchor_right` | `1` |
| `/StudentCard/Backdrop` | `anchor_bottom` | `1` |
| `/StudentCard/Backdrop` | `offset_left` | `0` |
| `/StudentCard/Backdrop` | `offset_top` | `0` |
| `/StudentCard/Backdrop` | `offset_right` | `0` |
| `/StudentCard/Backdrop` | `offset_bottom` | `0` |

`Backdrop` already has `expand_mode = 1` and `stretch_mode = 6`; verify with `node_get_properties` rather than assuming.

Then for each of `KertasMurid1` … `KertasMurid6`, in a second `batch_execute`: `layout_mode` = `1`, `anchor_left` = `0.5`, `anchor_top` = `0.5`, `anchor_right` = `0.5`, `anchor_bottom` = `0.5`, `offset_left` = `-540`, `offset_top` = `-960`, `offset_right` = `540`, `offset_bottom` = `960`.

- [ ] **Step 4: Build the safe-area group**

```
node_create(parent_path="", name="Safe", type="MarginContainer", scene_path="", scene_file="", session_id="")
```

Set on `/StudentCard/Safe`: `layout_mode` = `1`, `anchor_right` = `1`, `anchor_bottom` = `1`, `grow_horizontal` = `2`, `grow_vertical` = `2`, `mouse_filter` = `2`, and the script:

```
script_attach(path="/StudentCard/Safe", script_path="res://Scripts/UI/SafeAreaMargin.gd", session_id="")
```

```
node_create(parent_path="/Safe", name="UI", type="Control", scene_path="", scene_file="", session_id="")
node_create(parent_path="/Safe/UI", name="BottomBar", type="Control", scene_path="", scene_file="", session_id="")
```

Set on `UI`: `layout_mode` = `2`, `mouse_filter` = `2`. `Safe` is a `MarginContainer`, so it places `UI` itself — `layout_mode = 2` is correct here and anchors on `UI` would do nothing.

Set on `BottomBar`: `layout_mode` = `1`, `anchor_left` = `0`, `anchor_top` = `1`, `anchor_right` = `1`, `anchor_bottom` = `1`, `offset_left` = `0`, `offset_top` = `-94`, `offset_right` = `0`, `offset_bottom` = `34`, `grow_horizontal` = `2`, `grow_vertical` = `0`, `mouse_filter` = `2`.

- [ ] **Step 5: Reparent the five UI nodes and give them their offsets**

`reparent` keeps local offsets and appends the node last, so set every offset explicitly afterwards.

```
node_manage(op="reparent", params={"path": "/StudentCard/NextButtonKiri", "new_parent": "/StudentCard/Safe/UI/BottomBar"}, session_id="")
```
…and the same for `NextButtonKanan`, `PageLabel` into `BottomBar`, and `PilihMurid`, `BackButton` into `/StudentCard/Safe/UI`.

Then one `batch_execute` setting `layout_mode` = `1` first, then the anchors and offsets, for each:

| node | anchors (l,t,r,b) | offsets (l,t,r,b) |
|---|---|---|
| `Safe/UI/BottomBar/NextButtonKiri` | 0,0,0,0 | 42, 2, 162, 122 |
| `Safe/UI/BottomBar/NextButtonKanan` | 0,0,0,0 | 822, 2, 942, 122 |
| `Safe/UI/BottomBar/PageLabel` | 0,0,0,0 | 392, 27, 592, 97 |
| `Safe/UI/PilihMurid` | 0,0,0,0 | 112, 34, 1012, 162 |
| `Safe/UI/BackButton` | 0,0,0,0 | 42, 34, 302, 130 |

Set `unique_name_in_owner` = `true` on all five.

`NextButtonKiri` keeps `visible = false` (page 1 hides it); do not change it.

- [ ] **Step 6: Save, then check the reparents did not duplicate anything**

```
scene_save(session_id="")
```

```bash
git diff HEAD -- '*.gd'
grep -n '^\[node' Scenes/ReportCard/report_card.tscn | grep -v 'instance=' | grep 'parent=".*PaperShadow'
```

Expected: the first is empty; the second prints nothing. `reparent_node` makes the scene root the owner of every descendant, which can make the next save write an instanced sub-scene's internals out again as new typed nodes — `PaperShadow` is the instance at risk here. If any appear, close the editor without saving, delete those `[node …]` blocks by text, and relaunch.

- [ ] **Step 7: Run the layout tests**

Run: `test_run(suite="tall_screen_layout", test_name="report_card", exclude_test_name="", session_id="", verbose=false)`
Expected: PASS.

- [ ] **Step 8: Point the script at the unique names**

Four `script_patch` calls on `res://Scripts/ReportCard/report_card.gd`:

```gdscript
@onready var next_kanan: BaseButton = $NextButtonKanan
```
→
```gdscript
@onready var next_kanan: BaseButton = %NextButtonKanan
```

and the same shape for `next_kiri` (`$NextButtonKiri` → `%NextButtonKiri`), `back_button` (`$BackButton` → `%BackButton`) and `page_label` (`$PageLabel` → `%PageLabel`).

`script_patch` matches bytes exactly; if a multi-line anchor misses, the file has CRLF endings — normalise to LF first.

- [ ] **Step 9: Restart the editor, then run the suites**

A patched script must not be followed by a `scene_save` from an editor holding the stale tab. Kill `Godot_v*.exe`, relaunch as in Task 0 Step 3, and `scene_open` the main scene.

Run: `test_run(suite="tall_screen_layout", test_name="", exclude_test_name="", session_id="", verbose=false)`
Run: `test_run(suite="report_card", test_name="", exclude_test_name="", session_id="", verbose=false)`
Expected: PASS for both. `test_unique_name_paths_are_not_format_strings` must stay green — none of the four names is used in a format string.

- [ ] **Step 10: Look at it**

Seed the playtest state, go to the Lobby, open **Rapor Murid**. Confirm nothing moved at 1080×1920. Then set `window_height_override` to `800`, run again, and confirm the desk fills the screen with the papers centred and the arrows on the bottom edge. Set the override back to `640`.

- [ ] **Step 11: Commit**

```bash
git add Scenes/ReportCard/report_card.tscn Scripts/ReportCard/report_card.gd tests/test_tall_screen_layout.gd
git commit -F <message file>
```

```
fix(reportcard): fill a tall phone instead of stopping at 1920

Rapor was StudentCard before the tall-phone pass: a root inset by
70/254/-77/-352 with every child cancelling it back out, so a 1080x2400
screen showed 480px of empty grey below the desk. It now carries the
same structure StudentCard does -- filling backdrop, Center-anchored
papers, and a Safe/UI/BottomBar holding the page row.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

### Task 3: StudentCard's BELAJAR button comes back on screen

**Files:**
- Modify: `Scenes/StudentCard/student_card.tscn` — `BelajarButton`
- Modify: `Scripts/StudentCard/student_card.gd:691-695`
- Test: `tests/test_tall_screen_layout.gd`, `tests/test_student_card.gd`

**Interfaces:**
- Consumes: the Rapor section's helpers in `tests/test_tall_screen_layout.gd` are already present; nothing from Task 2's scene.
- Produces: nothing later tasks rely on.

- [ ] **Step 1: Write the failing tests**

In `tests/test_tall_screen_layout.gd`, add to the StudentCard section:

```gdscript
## BELAJAR belongs to the paper, not to the screen. Phase 1 pushed every
## child's offsets by the root's old (70, 254) inset and left this one in
## position mode, which put its rest position at y 1994 -- 74px below a
## 1080x1920 screen. Center-anchored like StampApprove, it is back at its
## authored 1740 and rides the paper's 240px drop on a tall phone.
func test_student_card_belajar_button_rides_the_paper() -> void:
	var card := _scene(STUDENT_CARD)
	var belajar := card.get_node_or_null("BelajarButton") as Control
	assert_true(belajar != null, "missing BelajarButton")
	if belajar == null:
		return
	assert_eq(_anchors(belajar), Vector4(0.5, 0.5, 0.5, 0.5),
		"BelajarButton rides with the paper")
	assert_eq(_offsets(belajar), Vector4(-142, 780, 348, 940),
		"BelajarButton keeps its 398,1740-888,1900 rect")
	var design := _stood_up(STUDENT_CARD, DESIGN)
	_assert_placed((design.get_node("BelajarButton") as Control),
		Rect2(398, 1740, 490, 160), "BelajarButton at the design size")
	var tall := _stood_up(STUDENT_CARD, TALL)
	_assert_placed((tall.get_node("BelajarButton") as Control),
		Rect2(398, 1980, 490, 160), "BelajarButton on a tall phone")
```

In `tests/test_student_card.gd`, add:

```gdscript
## _transition_page captures belajar_orig_pos before the page changes, which
## for a still-hidden button is its authored rect. It then calls
## _update_nav_buttons -> _shift_approve_for_belajar, which tweens the button
## to the correct spot beside Aprove/Batal -- and used to follow that with a
## second tween back to the stale belajar_orig_pos, undoing it. The swipe that
## first revealed BELAJAR therefore flew it off the bottom of the screen.
## The reveal belongs to _shift_approve_for_belajar alone, which parks the
## button off-screen right and slides it in on every page change
## (_reset_all_approve_positions clears approve_shifted first).
func test_page_transition_leaves_the_belajar_slide_to_the_shift() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := src.substr(src.find("func _transition_page"))
	body = body.substr(0, body.find("func _update_nav_buttons"))
	assert_true(body.contains("_shift_approve_for_belajar") == false,
		"_transition_page reaches the shift through _update_nav_buttons")
	assert_false(body.contains("tween_in.tween_property(belajar_button"),
		"_transition_page must not tween belajar_button back to the position " +
		"it captured before the page changed -- that undoes the shift")
	assert_true(body.contains("tween_out.tween_property(belajar_button"),
		"the button must still be thrown off with the old card")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test_run(suite="tall_screen_layout", test_name="belajar", exclude_test_name="", session_id="", verbose=false)`
Expected: FAIL — `BelajarButton rides with the paper`.

Run: `test_run(suite="student_card", test_name="belajar", exclude_test_name="", session_id="", verbose=false)`
Expected: FAIL — `_transition_page must not tween belajar_button back…`.

- [ ] **Step 3: Center-anchor the button**

```
scene_open(path="res://Scenes/StudentCard/student_card.tscn", force_reload=false, session_id="")
```

One `batch_execute` of `set_property` on `/StudentCard/BelajarButton`, `layout_mode` first:

`layout_mode` = `1`, `anchor_left` = `0.5`, `anchor_top` = `0.5`, `anchor_right` = `0.5`, `anchor_bottom` = `0.5`, `offset_left` = `-142`, `offset_top` = `780`, `offset_right` = `348`, `offset_bottom` = `940`.

- [ ] **Step 4: Save and check**

```
scene_save(session_id="")
```

```bash
git diff HEAD -- '*.gd'
git diff --stat HEAD -- Scenes/
```

Expected: the first empty; the second lists only `Scenes/StudentCard/student_card.tscn` (plus Tasks 1–2's files if they are not yet committed — they are, so only this one).

- [ ] **Step 5: Run the layout test to verify it passes**

Run: `test_run(suite="tall_screen_layout", test_name="belajar", exclude_test_name="", session_id="", verbose=false)`
Expected: PASS.

- [ ] **Step 6: Delete the stale slide-in**

One `script_patch` on `res://Scripts/StudentCard/student_card.gd`:

`old_text`:
```gdscript
	if belajar_button.visible:
		belajar_button.position = belajar_orig_pos - Vector2(throw_distance, 0)
		belajar_button.modulate.a = 0.0
		tween_in.tween_property(belajar_button, "position", belajar_orig_pos, 0.35)
		tween_in.tween_property(belajar_button, "modulate:a", 1.0, 0.35)

	await tween_in.finished
```

`new_text`:
```gdscript
	# BELAJAR is not slid in here. _update_nav_buttons above has already
	# called _shift_approve_for_belajar, which parks it off-screen right and
	# tweens it to the spot beside Aprove/Batal. Tweening it to
	# belajar_orig_pos as well undid that: the position was captured before
	# the page changed, so on the swipe that first reveals the button it is
	# the authored rest rect, 74px below a 1080x1920 screen.

	await tween_in.finished
```

- [ ] **Step 7: Restart the editor and run both suites**

Kill `Godot_v*.exe`, relaunch, `scene_open` the main scene.

Run: `test_run(suite="student_card", test_name="", exclude_test_name="", session_id="", verbose=false)`
Run: `test_run(suite="tall_screen_layout", test_name="", exclude_test_name="", session_id="", verbose=false)`
Expected: PASS for both.

- [ ] **Step 8: Look at it**

Run the game from the top (do **not** seed — seeding approves the roster and skips the screen). Approve students until the cap, then swipe between pages and confirm BELAJAR sits beside APPROVE/BATAL every time, at 640 and at 800 height override. Set the override back to `640`.

- [ ] **Step 9: Commit**

```bash
git add Scenes/StudentCard/student_card.tscn Scripts/StudentCard/student_card.gd tests/test_tall_screen_layout.gd tests/test_student_card.gd
git commit -F <message file>
```

```
fix(studentcard): keep BELAJAR on screen and on the paper

The tall-phone pass pushed every child's offsets by the root's old inset
and left BelajarButton in position mode, putting its rest rect 74px below
a 1080x1920 screen. _transition_page then tweened the button to exactly
that stale position, undoing the shift that had just placed it beside
Aprove/Batal. The button is now Center-anchored with the paper, and the
reveal belongs to _shift_approve_for_belajar alone.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

### Task 4: Full suite and the docs

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`
- Modify: `docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md` (Phase 2 worklist)

**Interfaces:**
- Consumes: all three tasks' commits.
- Produces: a tree ready for `ship-pr`.

- [ ] **Step 1: Run the full suite**

Run: `test_run(suite="", test_name="", exclude_test_name="", session_id="", verbose=false)`
Expected: every suite passes. The bridge will probably drop during this run; the results are still valid if the reply arrived. Restart the editor afterwards.

- [ ] **Step 2: Check what the full run dirtied**

```bash
git status --porcelain
```

The `theme_rebake` suite calls `ResourceSaver.save()` in-process, so `Assets/Theme/kejartes_theme.tres` may be rewritten, and `AudioDirector` rewrites `Assets/Audio/default_bus_layout.tres` on boot. `git checkout --` whichever you did not intend to change — here, both.

- [ ] **Step 3: Add the changelog entry**

Newest first, at the top of `docs/superpowers/CHANGELOG.md`:

```markdown
## 2026-09-16 — Papan tulis, Rapor's fill and the Belajar button

AturJadwal's board is `papantulis.png`, whose art carries 493px more board
above its shelf. `BGHari` stops stretching with the viewport and becomes a
fixed 1080x1920 picture unit pinned 493px down, so the baked shelf lands
exactly on the `ShelfFace`/`ShelfEdge` `ColorRect`s and the board reaches
y 2413; a `BoardFill` `ColorRect` continues it for a 21:9 screen. The five
sticky notes ride it.

Rapor gets Phase 2 of the tall-phone pass: the root loses its
70/254/-77/-352 inset, the desk fills and covers, the papers are
Center-anchored, and the page row moves into a `Safe/UI/BottomBar`. That
closes the 480px of empty grey a 1080x2400 phone showed below the desk.

StudentCard's BELAJAR button was left in position mode by Phase 1, which
put its rest rect 74px off the bottom of a 1080x1920 screen, and
`_transition_page` tweened it to exactly that stale position, undoing the
shift that had just placed it beside Aprove/Batal. It is now
Center-anchored with the paper and the reveal belongs to
`_shift_approve_for_belajar` alone.

Spec: `docs/superpowers/specs/2026-09-16-papantulis-rapor-belajar-design.md`.
```

- [ ] **Step 4: Update the Phase 2 worklist**

In `docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md`, the phase list reads:

```
2. **AturJadwal**, **CutScene**, **Rapor** and **Inventory**. Rapor and
   Inventory wait until the two separate fixes that edit those scenes have
   merged.
```

Replace with:

```
2. **AturJadwal**, **CutScene**, **Rapor** and **Inventory**. Rapor is done
   (2026-09-16), as is AturJadwal's board; AturJadwal's wall, top band and
   `StartWeek` are still open. Inventory waits for the glyph fix to merge.
```

The `KEMBALI`-covers-its-title bug stays in the Out-of-scope list: Rapor's restructure kept both nodes at their current screen rects rather than guessing a new composition.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/CHANGELOG.md docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md
git commit -F <message file>
```

```
docs(changelog): papan tulis, Rapor's fill and the Belajar button

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

## Self-review

**Spec coverage.** §1 (board) → Task 1. §2 (Rapor) → Task 2, including the
`report_card.gd` unique-name switch at Step 8 and the two explicit
non-changes (title overlap, arrow styling) recorded in Task 4 Step 4. §3
(Belajar) → Task 3, both halves: the anchors in Steps 3–5, the
`_transition_page` deletion in Step 6. The Files table and the Testing
section map one-to-one onto the tasks' Files blocks.

**Placeholders.** None: every test is written out, every property table
carries real numbers, every commit has its message.

**Type consistency.** `BGHari`, `BoardFill`, `Safe/UI/BottomBar`,
`BelajarButton`, `%NextButtonKanan`, `%NextButtonKiri`, `%PageLabel`,
`%BackButton`, `%PilihMurid` are spelled the same in the spec, the tests and
the editor calls. Rapor's scene root is `StudentCard`, not `ReportCard` —
used consistently in every path in Task 2.

**One number to watch.** Task 2's tall-phone test expects
`NextButtonKanan` at `Rect2(870, 2260, 120, 120)`. `BottomBar` sits at
`offset_top = -94` from the safe area's bottom (1872 at 1920, 2352 at 2400),
so the button's top is 2352 − 94 + 2 = 2260. If `SafeAreaMargin` reports a
non-zero device inset in the editor, this shifts; `tests/layout_frame.gd`
stands screens up without the host desktop's safe area (commit `64d3e9d`),
so it should read 2260. If it does not, read the actual value from the
failure and fix the expectation rather than the scene.
