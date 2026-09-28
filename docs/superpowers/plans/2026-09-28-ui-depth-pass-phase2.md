# UI Depth Pass — Phase 2 (Popups into NotebookFrame) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all 17 popups into `NotebookFrame` (Settings with tabs, six sheets and nine dialogs), keeping every behaviour and signal, and pin the result with one contract suite.

**Architecture:**
- **The frame learns to size itself.** `NotebookFrame` gets `_get_minimum_size()` (the host's minimum plus `content_padding`), a sticker that widens to its title and hides when there is none, and taps that stop at the page.
- **One host recipe.** Each popup's own box (a `Card` panel, a nine-patch or a book panel) is replaced by a `NotebookFrame` instance, and the content inside moves under the frame unchanged. The popup's own close control is deleted and the frame's `close_pressed` is wired to the old close handler. A centred popup sits in `SafeAreaMargin → CenterContainer → Frame`; a full-height one in `SafeAreaMargin → Frame`.
- **One contract suite.** `tests/test_popup_frames.gd` holds a roster of every popup and checks the frame, its kind and its place. Each task adds its rows.

**Tech Stack:** Godot 4.6 GDScript, `.tscn` text edits made while the worktree editor is closed, and the Godot AI MCP bridge (`test_run`, `scene_open`, `editor_screenshot`), which only the controller drives.

**Spec:** `docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md`, Rollout step 2. The format follows `docs/superpowers/plans/2026-09-28-ui-depth-pass-phase1.md`.

## Decisions taken while planning

The spec leaves these open; each is the conservative reading. The owner can overturn any of them in review.

| # | Decision | Why |
|---|---|---|
| D1 | **Settings' tabs are SUARA and MAIN.** SUARA shows the three sliders. MAIN shows the PERMAINAN and TAMPILAN switches, which keep their own headings. | The spec and the mockup both name exactly these two tabs, and the screen has three sections. |
| D2 | **AchievementDetailSheet has no tabs**, although the spec lists it under "with tabs". | It shows one achievement and has nothing to switch between. A one-tab strip would be noise. Settings is the only tabbed popup. |
| D3 | **Sticker titles are short fixed words** (the table in Global Constraints). The popup's dynamic heading (a stat name, an event name, a step title) stays in its content. | The sticker's size is authored, and a trait name like "Seni Dalam Kesunyian" would crowd it. It does widen to fit its title (Task 1), but a fixed word keeps it calm. |
| D4 | **The frame's ✕ shows only where it adds nothing new.** It shows where it means the same as an existing Batal or Tidak, or where the popup already closed on a tap. It is hidden where the player must decide (EventStudentSelectDialog) or the flow is forced (DailyDecayOverview, TesNotice, StatCheck, TutorialPanel). | "Each popup keeps its behaviour": a ✕ must never create a new way out. |
| D5 | **Centred means centred.** The three bottom-sliding stat, trait and pill dialogs, and ItemDetailSheet, now centre in the safe area. They keep their open pop and their slide-down exit. | The spec says the frame centres inside `SafeAreaMargin`. Their old placement was a computed `position` that ignored the safe area. |
| D6 | **Two popups stay placed by their screen** (fit `free` in the roster): OpenAmplopConfirm, whose letter's rise tweens `position` (a container would undo it), and the Lobby's DailyLogin, whose frame sits behind the calendar art. TutorialPanel is placed by each caller. | Each is commented on its roster row. |

## Global Constraints

- **Worktree.** Work in `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/focused-williamson-19deed/` on branch `feat/ui-depth-pass-phase2`. **Every path you edit must start with that directory; check it before every Edit or Write.** The parent folder is a different, shared checkout, so never touch it.
- **Never use `git stash`.** The stash stack is shared by every session and worktree.
- **Editor work belongs to the controller.** Implementers write files and report back. They never call godot-ai or MCP tools, and never launch Godot. The controller keeps this worktree's editor **closed** while an implementer works, because `.tscn` files are edited as text and an open editor's copy would win.
- **Editing a `.tscn` as text:**
  - Moving a node means changing its `parent="…"` path, and the `parent=` of every descendant.
  - A node block keeps its `unique_id=`; new node blocks may omit it.
  - New `ext_resource` ids must be unique in the file (use `nb_frame`, `nb_safe`).
  - Delete a deleted node's whole block and the blocks of its children.
  - Drop an `ext_resource` nothing references any more.
  - A property set on an instance's **root** serialises; one set on an instance's child is dropped. So a frame is configured only through its root exports.
- **The frame's API** (`Scripts/UI/NotebookFrame.gd`, `class_name NotebookFrame`, extends `Container`):
  - Root exports: `title_text: String`, `tabs: PackedStringArray`, `active_tab: int`, `ring_count: int` (0–8, default 7), `show_well: bool` (default true), `show_tape: bool`, `tape_color: Color`, `show_close: bool` (default true), `content_padding: Vector4i` (default `(72, 120, 40, 48)`: left, top, right, bottom).
  - Signals: `tab_selected(index: int)`, `close_pressed`.
  - Every child except `Chrome` is host content, laid into `content_rect()` (all such children get the same rect, so put one VBox in).
  - The decoration sticks out of the frame's rect: the cover 12 px left, 20 px right and 24 px down; the tabs 60 px up; the ✕ 36 px up and 36 px right.
- **The three kinds:**
  - **dialog:** `tabs` empty, `ring_count = 4`, `show_well = false`.
  - **sheet:** `tabs` empty (rings and well at their defaults unless a row says otherwise).
  - **tabs:** `tabs` set.
- **The host recipe** (a centred popup). New blocks, adapted per task:

  ```
  [ext_resource type="PackedScene" uid="uid://djkgrgndtsvc7" path="res://Scenes/UI/NotebookFrame.tscn" id="nb_frame"]
  [ext_resource type="Script" uid="uid://88qrfscj2817" path="res://Scripts/UI/SafeAreaMargin.gd" id="nb_safe"]

  [node name="Safe" type="MarginContainer" parent="<scrim or root>"]
  layout_mode = 1
  anchors_preset = 15
  anchor_right = 1.0
  anchor_bottom = 1.0
  grow_horizontal = 2
  grow_vertical = 2
  mouse_filter = 2
  script = ExtResource("nb_safe")

  [node name="Center" type="CenterContainer" parent="<…>/Safe"]
  layout_mode = 2
  mouse_filter = 2

  [node name="Frame" parent="<…>/Safe/Center" instance=ExtResource("nb_frame")]
  unique_name_in_owner = true
  custom_minimum_size = Vector2(900, 0)
  layout_mode = 2
  title_text = "…"
  ring_count = 4
  show_well = false
  ```

  - `layout_mode = 1` is for a node whose parent is a plain Control (anchors); `layout_mode = 2` is for a container child. A node directly under a `CanvasLayer` uses `layout_mode = 3` with anchors (copy the existing Scrim's lines).
  - **Full-height popups** drop `Center` and put `Frame` straight under `Safe`.
  - The frame's width is its `custom_minimum_size.x`. Keep it at most **900** in a 1080 screen, so the ✕ and the cover stay on screen inside the 48 px safe margin. Its height follows its content.
- **Taps:**
  - `Safe` and `Center` ignore taps (`mouse_filter = 2`), so a tap on empty space still reaches the popup's scrim.
  - The frame's root stops them (Task 1 sets this in `NotebookFrame.tscn`), so a tap on the page never dismisses.
- **Close wiring:**
  - Delete the popup's own ✕ or Tutup button (its node, its `@onready`, its `connect`).
  - Connect `<frame>.close_pressed` to the function that button called.
  - `tests/test_popup_frames.gd` checks that the root script (or, for the Lobby and AturJadwal, the screen script) mentions `close_pressed.connect` when `show_close` is true.
- **Sticker titles (D3):**

  | Popup | Title |
  |---|---|
  | Settings | `PENGATURAN` |
  | AchievementDetailSheet | `PENCAPAIAN` |
  | ItemDetailSheet | `DETAIL ITEM` |
  | DapatkanUang | `DAPATKAN UANG` |
  | DailyLogin | `DAILY LOGIN` |
  | WeekLogsPopup | `LOGS` |
  | DaySummaryPopup | *(empty: its banner art stays the title)* |
  | DailyDecayOverview | `EVALUASI` |
  | StatDetailPopup | `STATISTIK` |
  | TraitDetailPopup | `SIFAT` |
  | WeekRecapPillInfoPopup | `INFO` |
  | EventStudentSelectDialog | `ACARA` |
  | OpenAmplopConfirm | `SURAT TUGAS` |
  | Peringatan | `PERINGATAN` |
  | TesNotice | `PENGUMUMAN` |
  | StatCheck | `CEK NILAI` |
  | TutorialPanel | `TUTORIAL` |

  A label whose only job was that title (for example "LOGS", "Dapatkan Uang", the "SURAT TUGAS" and "PENGUMUMAN" kickers, "Daily Login") is deleted.
- **Tests:**
  - Tests are `McpTestSuite` suites in `tests/test_*.gd`. Every suite is `@tool`, and **no test may be a coroutine** (no `await`).
  - Helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_gt`, `assert_contains`, `track`.
  - A test that measures layout mounts its node with `Engine.get_main_loop().root.add_child(x)` (and `track(x)`), because layout is empty out of the tree.
  - **Existing suites that pin an old node path are updated, never deleted.** A popup's old box, close button or title label is gone, so its assertions move to the frame (`title_text`, `show_close`, the new path).
  - Before finishing a task, run `grep -rn "<every old path you changed>" tests/ Scripts/ Scenes/` from the worktree and fix every hit.
- **Theme rules.** Never add a `theme_override_*`, except layout-only constants (`separation`, `margin_*`, `line_spacing` where one already exists). Do not add a Control `.new()` in `Scripts/` (`test_viewport_editability` ratchets it).
- **Documentation.** Every script has a `##` file header and every `@export` a `##` line (`test_script_documentation`). When a script's header describes the old box ("the Card", "Scrim/Card"), update it.
- **Clean code** (`ci/clean_code_scan.gd`, ratcheted by `test_clean_code`) applies to new or changed lines in `Scripts/`:
  - no numeric literal other than 0, 1, 2 or 0.5 outside a `const` line
  - typed `var`s
  - `->` return types
  - functions of at most 50 code lines
- **Commits** follow Conventional Commits with a scope, for example `feat(popups): …` or `test(popups): …`.
  - End each message with a blank line, then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Run git as plain separate commands (no `cd … &&` chains).
  - Write the message to a file in the scratchpad and use `git commit -F <file>`.

## Controller loop (every task)

The controller (not the implementer) runs this around each task:

1. **Before dispatch.** Confirm that this worktree's editor is not running:

   ```powershell
   Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v%'" | Where-Object { $_.CommandLine -like '*focused-williamson-19deed*' }
   ```

   It must return nothing.
2. **After the handback:**
   - `git -C <main checkout> status --short` must show no new changes.
   - `git stash list` must be unchanged.
   - Read the worktree diff.
3. **Launch the worktree editor, detached.** The exe path's outer `.exe` is a directory.

   ```powershell
   Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = '"C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" --path "<worktree>" -e'; CurrentDirectory = '<worktree>' }
   ```

   Then poll `session_manage(op="list")` for the `focused-williamson-19deed@…` session, and pass its `session_id` on every godot-ai call.
4. **Run the targeted suites** named in the task, plus `popup_frames`, `notebook_frame`, `script_documentation`, `viewport_editability` and `clean_code`. Also read `logs_read(source="editor")` for parse errors.
5. **Look at the result.** `scene_open` each touched popup scene and take one `editor_screenshot` at full size, to judge the frame's fit.
6. **Close the editor** (`editor_manage(op="quit")`, or `Stop-Process` on the checked PID). Then revert `Assets/Audio/default_bus_layout.tres` and any `*.png.import` that the boot rewrote.

**One-time setup, before Task 1:**
- Seed `<worktree>/.godot/` from the main checkout's `.godot/`: `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg` and `scene_groups_cache.cfg`. Leave out `editor/`.
- Then run `"<exe>" --headless --path "<worktree>" --import` once.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `Scripts/UI/NotebookFrame.gd`, `Scenes/UI/NotebookFrame.tscn` | Modify | Minimum size, the sticker's width and visibility, and taps that stop at the page. |
| `tests/fixtures/notebook_host.tscn` | Create | A throwaway host that instances the frame with root overrides and host content. |
| `tests/test_notebook_frame.gd` | Modify | Minimum size, the sticker, and the nested-instance tests. |
| `tests/test_popup_frames.gd` | Create | The roster of every popup, and the frame contract. |
| `Scenes/UI/StatDetailPopup.tscn`, `TraitDetailPopup.tscn`, `WeekRecapPillInfoPopup.tscn` + their scripts | Modify | Dialogs (Task 2). |
| `Scenes/SchoolSimulation/WeekLogsPopup.tscn`, `DailyDecayOverview.tscn`, `DaySummaryPopup.tscn` + scripts | Modify | Sheets (Task 3). |
| `Scenes/Inventory/ItemDetailSheet.tscn`, `Scenes/Achievements/AchievementDetailSheet.tscn`, `Scenes/Lobby/DapatkanUang.tscn` + scripts | Modify | Sheets (Task 4). |
| `Scenes/UI/Settings.tscn`, `Scripts/UI/Settings.gd` | Modify | The tabbed frame (Task 5). |
| `Scenes/SchoolSimulation/EventStudentSelectDialog.tscn`, `Scenes/LevelSelect/OpenAmplopConfirm.tscn`, `Scenes/AturJadwal/AturJadwal.tscn` + scripts | Modify | Dialogs with a button pair (Task 6). |
| `Scenes/EndGame/TesNotice.tscn`, `Scenes/EndGame/StatCheck.tscn`, `Scenes/UI/TutorialPanel.tscn` + scripts, `Scripts/StudentCard/StudentCard.gd` | Modify | Forced-flow dialogs (Task 7). |
| `Scenes/Lobby/Lobby.tscn`, `Scripts/Lobby/Lobby.gd` | Modify | DailyLogin (Task 8). |
| `docs/superpowers/design/style-guide.md`, `DEBT.md`, `CHANGELOG.md`, `CLAUDE.md` | Modify | Docs (Task 9). |

---

### Task 1: The frame sizes itself, and the contract suite

**Files:**
- Modify: `Scripts/UI/NotebookFrame.gd`
- Modify: `Scenes/UI/NotebookFrame.tscn` (root block only)
- Create: `tests/fixtures/notebook_host.tscn`
- Modify: `tests/test_notebook_frame.gd`
- Create: `tests/test_popup_frames.gd`

**Interfaces:**
- Produces:
  - `NotebookFrame._get_minimum_size() -> Vector2`
  - `NotebookFrame.STICKER_MIN_WIDTH: float`, `NotebookFrame.STICKER_SIDE_PAD: float`
  - `tests/test_popup_frames.gd`'s `const POPUPS := {}`, which Tasks 2–8 extend with rows of `scene path: [frame node path, kind, fit]`
    - kind is `"dialog"`, `"sheet"` or `"tabs"`
    - fit is `"safe"` (has a `SafeAreaMargin` ancestor) or `"free"` (placed by its screen, with the reason in a comment on the row)
  - `tests/test_popup_frames.gd`'s `const SCREEN_SCRIPTS := {}`, for popups whose close is wired by the screen's script rather than the instanced root's (Tasks 6 and 8 add `AturJadwal.tscn` and `Lobby.tscn`).

- [ ] **Step 1: Write the host fixture** `tests/fixtures/notebook_host.tscn`:

```
[gd_scene format=3]

[ext_resource type="PackedScene" uid="uid://djkgrgndtsvc7" path="res://Scenes/UI/NotebookFrame.tscn" id="1_frame"]

[node name="Host" type="Control"]
layout_mode = 3
anchors_preset = 0
offset_right = 1080.0
offset_bottom = 1920.0

[node name="Frame" parent="." instance=ExtResource("1_frame")]
layout_mode = 0
offset_right = 800.0
offset_bottom = 900.0
title_text = "UJI"
tabs = PackedStringArray("SATU", "DUA")
active_tab = 1
ring_count = 4
show_well = false

[node name="Body" type="Control" parent="Frame"]
custom_minimum_size = Vector2(900, 1000)
layout_mode = 2
```

- [ ] **Step 2: Write the failing tests.** Append to `tests/test_notebook_frame.gd`:

```gdscript
## The throwaway host scene: the frame instanced inside another scene, with
## root overrides and a host child -- the shape every Phase 2 popup takes.
const HOST := "res://tests/fixtures/notebook_host.tscn"


## `HOST` instanced (out of the tree unless `mount`), freed after the test.
func _host(mount: bool) -> Control:
	var host := load(HOST).instantiate() as Control
	track(host)
	if mount:
		Engine.get_main_loop().root.add_child(host)
	return host


func test_a_nested_frame_applies_its_root_overrides() -> void:
	# NOTIFICATION_SCENE_INSTANTIATED reaches a nested frame BEFORE the
	# host's overrides are set; each setter must refresh the chrome again.
	var frame := _host(false).get_node("Frame") as NotebookFrame
	assert_eq((frame.get_node("Chrome/Sticker/Title") as Label).text, "UJI")
	assert_true((frame.get_node("Chrome/Tabs") as Control).visible, "two tabs show the strip")
	assert_eq((frame.get_node("Chrome/Tabs/Tab1") as Button).text, "DUA")
	assert_eq((frame.get_node("Chrome/Tabs/Tab1") as Button).theme_type_variation,
		&"NotebookTabActive", "active_tab = 1 is the gold one")
	assert_false((frame.get_node("Chrome/Tabs/Tab2") as Control).visible, "no third tab")
	assert_true((frame.get_node("Chrome/Rings/Ring3") as Control).visible, "four rings")
	assert_false((frame.get_node("Chrome/Rings/Ring4") as Control).visible, "not five")
	assert_false((frame.get_node("Chrome/Well") as Control).visible, "no well")
	assert_eq(frame.get_child(1).name, &"Body", "host content follows the chrome")


func test_a_nested_frame_wires_its_buttons_once() -> void:
	var frame := _host(false).get_node("Frame") as NotebookFrame
	var tab := frame.get_node("Chrome/Tabs/Tab0") as Button
	var close := frame.get_node("Chrome/Close") as Button
	assert_eq(tab.pressed.get_connections().size(), 1, "one tab wiring, not one per refresh")
	assert_eq(close.pressed.get_connections().size(), 1, "one close wiring")
	var got := []
	frame.tab_selected.connect(func(i: int) -> void: got.append(i))
	tab.pressed.emit()
	assert_eq(got, [0], "tab 0 reports itself")


## Mounted: out of the tree Control.update_minimum_size() returns early and
## get_combined_minimum_size() keeps serving its first cached answer.
func test_the_minimum_size_wraps_the_host_content() -> void:
	var frame := _host(true).get_node("Frame") as NotebookFrame
	var pad := frame.content_padding
	var want := Vector2(900 + pad.x + pad.z, 1000 + pad.y + pad.w)
	assert_eq(frame.get_combined_minimum_size(), want, "host minimum plus the padding")


func test_the_page_grows_to_hold_big_content() -> void:
	var host := _host(true)
	var frame := host.get_node("Frame") as NotebookFrame
	frame.sort_now()
	var body := frame.get_node("Body") as Control
	assert_true(frame.size.x >= frame.get_combined_minimum_size().x, "the frame grew wide enough")
	assert_true(Rect2(Vector2.ZERO, frame.size).encloses(body.get_rect()), "the content stays on the page")


func test_the_minimum_never_drops_below_the_authored_size() -> void:
	var frame := _frame()
	assert_eq(frame.get_combined_minimum_size(), frame.custom_minimum_size,
		"no host content: the scene's own 640x520 floor")


func test_a_padding_change_updates_the_minimum() -> void:
	var frame := _host(true).get_node("Frame") as NotebookFrame
	var before := frame.get_combined_minimum_size()
	frame.content_padding = Vector4i(0, 0, 0, 0)
	assert_eq(frame.get_combined_minimum_size(), Vector2(900, 1000), "padding gone")
	assert_ne(before, frame.get_combined_minimum_size())


func test_an_empty_title_hides_the_sticker() -> void:
	var frame := _frame()
	frame.title_text = ""
	assert_false((frame.get_node("Chrome/Sticker") as Control).visible, "no title, no sticker")
	frame.title_text = "LOGS"
	assert_true((frame.get_node("Chrome/Sticker") as Control).visible)


func test_the_sticker_widens_to_a_long_title() -> void:
	var frame := _frame()
	var sticker := frame.get_node("Chrome/Sticker") as Control
	frame.title_text = "LOGS"
	frame.sort_now()
	assert_eq(sticker.size.x, NotebookFrame.STICKER_MIN_WIDTH, "a short title keeps the authored width")
	frame.title_text = "DAPATKAN UANG SEKARANG JUGA"
	frame.sort_now()
	var title := sticker.get_node("Title") as Control
	assert_true(sticker.size.x >= title.get_combined_minimum_size().x + 2 * NotebookFrame.STICKER_SIDE_PAD,
		"a long title gets its width plus the stitching margin")
	assert_eq(sticker.offset_left, -sticker.offset_right, "still centred")


func test_the_page_stops_taps() -> void:
	assert_eq(_frame().mouse_filter, Control.MOUSE_FILTER_STOP,
		"a tap on the page must never fall through to a scrim that dismisses")
```

- [ ] **Step 3: Write the contract suite** `tests/test_popup_frames.gd`:

```gdscript
@tool
extends McpTestSuite

## Phase 2 of the UI depth pass (docs/superpowers/plans/
## 2026-09-28-ui-depth-pass-phase2.md): every popup sits in a NotebookFrame.
## POPUPS is the roster, one row per popup, added task by task: the scene,
## the frame's node path in it, the frame's kind and how it is placed.
##
## kind -- "dialog": no tabs, four rings, no well. "sheet": no tabs.
## "tabs": a tab strip.
## fit -- "safe": the frame has a SafeAreaMargin ancestor (the tall-phone
## rule). "free": its screen places it; each such row says why.
##
## Must be @tool; no test here may be a coroutine.

const FRAME_SCENE := "res://Scenes/UI/NotebookFrame.tscn"
## A dialog's ring count.
const DIALOG_RINGS := 4
## The typed close glyph every popup used before the frame's round close.
const CLOSE_GLYPH := "✕"

## scene -> [frame node path, kind, fit].
const POPUPS := {
}

## scene -> the script that wires its frame's close, when that is the
## screen's own script rather than the instanced root's.
const SCREEN_SCRIPTS := {
}


func suite_name() -> String:
	return "popup_frames"


## `path` instanced out of the tree (no _ready runs), freed after the test.
func _instance(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	track(root)
	return root


## The row's frame, or null (with a failed assertion) when it is missing.
func _frame_of(root: Node, path: String) -> NotebookFrame:
	var frame := root.get_node_or_null(POPUPS[path][0]) as NotebookFrame
	assert_true(frame != null, "%s: no NotebookFrame at %s" % [path, POPUPS[path][0]])
	return frame


func test_the_frame_scene_exists() -> void:
	assert_true(ResourceLoader.exists(FRAME_SCENE), "NotebookFrame.tscn is the one popup frame")


func test_every_popup_wears_the_frame() -> void:
	for path in POPUPS:
		var frame := _frame_of(_instance(path), path)
		if frame != null:
			assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_STOP, path + ": the page stops taps")


func test_each_frame_is_its_kind() -> void:
	for path in POPUPS:
		var frame := _frame_of(_instance(path), path)
		if frame == null:
			continue
		match String(POPUPS[path][1]):
			"dialog":
				assert_true(frame.tabs.is_empty(), path + ": a dialog has no tabs")
				assert_eq(frame.ring_count, DIALOG_RINGS, path + ": a dialog has four rings")
				assert_false(frame.show_well, path + ": a dialog has no well")
			"sheet":
				assert_true(frame.tabs.is_empty(), path + ": a sheet has no tabs")
			"tabs":
				assert_false(frame.tabs.is_empty(), path + ": a tabbed frame has tabs")
			_:
				assert_true(false, path + ": unknown kind " + String(POPUPS[path][1]))


func test_safe_frames_sit_in_the_safe_area() -> void:
	for path in POPUPS:
		if POPUPS[path][2] != "safe":
			continue
		var frame := _frame_of(_instance(path), path)
		if frame == null:
			continue
		var p := frame.get_parent()
		while p != null and not (p is SafeAreaMargin):
			p = p.get_parent()
		assert_true(p != null, path + ": the frame must sit under a SafeAreaMargin")


func test_no_popup_types_its_close_glyph() -> void:
	for path in POPUPS:
		assert_false(FileAccess.get_file_as_string(path).contains(CLOSE_GLYPH),
			path + " still types a close glyph")
		var script := _instance(path).get_script() as Script
		if script != null:
			assert_false(script.source_code.contains(CLOSE_GLYPH),
				script.resource_path + " still types a close glyph")


func test_every_shown_close_is_heard() -> void:
	for path in POPUPS:
		var root := _instance(path)
		var frame := _frame_of(root, path)
		if frame == null or not frame.show_close:
			continue
		var script_path: String = SCREEN_SCRIPTS.get(path, "")
		if script_path == "":
			script_path = (root.get_script() as Script).resource_path
		assert_contains(FileAccess.get_file_as_string(script_path), "close_pressed.connect",
			"%s shows the frame's close, so %s must wire it" % [path, script_path])
```

- [ ] **Step 4: Run the tests to see the new ones fail.** Controller: `test_run(suite="notebook_frame")`. Expected: the minimum-size, sticker and tap tests fail; the override tests may already pass. Then `test_run(suite="popup_frames")`: until Task 2 adds the first rows, each roster test fails its opening `assert_false(POPUPS.is_empty(), …)` (a test with no assertion is itself reported as a failure, so an empty roster cannot pass vacuously).

- [ ] **Step 5: Implement in `Scripts/UI/NotebookFrame.gd`.**

Add the consts after `DEFAULT_TAPE`:

```gdscript
## Narrowest the title sticker gets, px: its authored width in the scene.
const STICKER_MIN_WIDTH := 360.0
## Room the sticker keeps either side of its title, px: clear of the stitching.
const STICKER_SIDE_PAD := 40.0
```

Change `content_padding`'s setter to:

```gdscript
		set(value):
			content_padding = value
			update_minimum_size()
			queue_sort()
```

Add, after `content_rect()`:

```gdscript
## The frame is never smaller than its biggest visible host child plus the
## padding round it, so content bigger than the page grows the page instead
## of spilling off it. Control keeps custom_minimum_size as a floor on top.
func _get_minimum_size() -> Vector2:
	var pad := content_padding
	var host := Vector2.ZERO
	for child in get_children():
		var control := child as Control
		if control == null or control.has_meta(CHROME_META) or not control.visible:
			continue
		host = host.max(control.get_combined_minimum_size())
	return host + Vector2(pad.x + pad.z, pad.y + pad.w)
```

In `sort_now()`, after `_spread_rings()` (so inside the part the edited-scene guard skips), add `_fit_sticker()`, and add the function after `_spread_rings()`:

```gdscript
## Widen the sticker to its title -- never narrower than its authored
## STICKER_MIN_WIDTH -- keeping it centred and its tilt about its middle.
## Layout only, on an authored node: nothing is built.
func _fit_sticker() -> void:
	var sticker := get_node_or_null("Chrome/Sticker") as Control
	if sticker == null:
		return
	var title := sticker.get_node("Title") as Control
	var half := maxf(STICKER_MIN_WIDTH,
		title.get_combined_minimum_size().x + 2 * STICKER_SIDE_PAD) * 0.5
	sticker.offset_left = -half
	sticker.offset_right = half
	sticker.pivot_offset.x = half
```

In `_refresh()`, after the line that sets the sticker title, add:

```gdscript
	(get_node("Chrome/Sticker") as CanvasItem).visible = title_text != ""
```

Update the file header's paragraph on host content with one sentence: "The frame's minimum size is its host content's plus content_padding, so a popup's content sizes its page."

- [ ] **Step 6: Make the page stop taps.** In `Scenes/UI/NotebookFrame.tscn`, add `mouse_filter = 0` to the root node block, after `offset_bottom = 900.0`. Leave the rest of the file alone.

- [ ] **Step 7: Run the tests to see them pass.** Controller: `test_run(suite="notebook_frame")` and `test_run(suite="popup_frames")`, both all green. Also run `script_documentation`, `clean_code` and `viewport_editability`, all green. Then `git diff -- Scenes/UI/NotebookFrame.tscn` must show only the `mouse_filter` line.

- [ ] **Step 8: Commit**

```bash
git add Scripts/UI/NotebookFrame.gd Scenes/UI/NotebookFrame.tscn tests/fixtures/notebook_host.tscn tests/test_notebook_frame.gd tests/test_popup_frames.gd
git commit -F <msgfile>   # feat(notebook): the frame sizes to its content and its title
```

---

### Task 2: The stat, trait and pill dialogs

**Files:**
- Modify: `Scenes/UI/StatDetailPopup.tscn`, `Scripts/UI/StatDetailPopup.gd`
- Modify: `Scenes/UI/TraitDetailPopup.tscn`, `Scripts/UI/TraitDetailPopup.gd`
- Modify: `Scenes/UI/WeekRecapPillInfoPopup.tscn`, `Scripts/UI/WeekRecapPillInfoPopup.gd`
- Modify: `tests/test_popup_frames.gd` (3 rows), `tests/test_stat_detail_popup.gd`, `tests/test_trait_detail_popup.gd`, `tests/test_week_recap_pill_info_popup.gd`, `tests/test_popup_dismiss.gd`, plus every other suite that `grep -rn "Scrim/Card" tests/` lists for these three scenes

**Interfaces:**
- Consumes: the Task 1 frame and roster.
- Produces: each script's `card` var is now the `NotebookFrame` at `Scrim/Safe/Center/Frame` (its name kept, so `open()`/`close()` read the same).

The three share one shell. For each:

1. **Target tree** (StatDetailPopup shown; the other two are the same shape):

   ```
   StatDetailPopup (CanvasLayer)          unchanged
   └ Scrim (ColorRect, full rect)          unchanged
     └ Safe (SafeAreaMargin)               new, layout_mode 1, full rect, mouse_filter 2
       └ Center (CenterContainer)          new, mouse_filter 2
         └ Frame (NotebookFrame instance)  new; replaces Card
           └ Layout …                      was Scrim/Card/Layout, children unchanged
   ```

2. **Frame root overrides:**

   | Popup | `custom_minimum_size` | `title_text` |
   |---|---|---|
   | StatDetailPopup | `Vector2(900, 0)` | `STATISTIK` |
   | TraitDetailPopup | `Vector2(900, 0)` | `SIFAT` |
   | WeekRecapPillInfoPopup | `Vector2(840, 0)` | `INFO` |

   Each also takes `ring_count = 4` and `show_well = false`.
3. **Delete** each `CloseButton` block (the typed ✕).
4. **Scripts:**
   - Replace `Scrim/Card/` with `Scrim/Safe/Center/Frame/` in every `@onready` path.
   - `card` becomes `@onready var card: NotebookFrame = $Scrim/Safe/Center/Frame`.
   - Delete the `close_button` var, and replace `close_button.pressed.connect(close)` with `card.close_pressed.connect(close)`.
   - In `open()`, delete the lines that compute and assign `card.position` (and `vp`, if it is then unused). The `CenterContainer` places the frame now. Keep `Juice.pop_in(card)` and the scrim fade.
   - `close()` keeps its slide of `card.position:y` to the bottom edge.
   - Update each file header's description of the shell ("scrim+card" becomes "scrim + notebook dialog").

- [ ] **Step 1: Write the failing tests.** In `tests/test_popup_frames.gd`, add to `POPUPS`:

```gdscript
	"res://Scenes/UI/StatDetailPopup.tscn": ["Scrim/Safe/Center/Frame", "dialog", "safe"],
	"res://Scenes/UI/TraitDetailPopup.tscn": ["Scrim/Safe/Center/Frame", "dialog", "safe"],
	"res://Scenes/UI/WeekRecapPillInfoPopup.tscn": ["Scrim/Safe/Center/Frame", "dialog", "safe"],
```

In each of `test_stat_detail_popup.gd`, `test_trait_detail_popup.gd` and `test_week_recap_pill_info_popup.gd`, add (with the suite's own `SCENE`/`SCRIPT` path consts, or literal paths if it has none):

```gdscript
func test_the_card_is_the_notebook_dialog() -> void:
	var popup := (load("<scene path>") as PackedScene).instantiate()
	track(popup)
	var frame := popup.get_node_or_null("Scrim/Safe/Center/Frame") as NotebookFrame
	assert_true(frame != null, "the popup's box is a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "<its title>", "its sticker names the popup")
		assert_true(frame.show_close, "the frame's round close replaces the typed one")


func test_the_frame_close_closes() -> void:
	var src := FileAccess.get_file_as_string("<script path>")
	assert_contains(src, "card.close_pressed.connect(close)", "the frame's close runs close()")
	assert_false(src.contains("close_button"), "the old button is gone")
```

- [ ] **Step 2: Run them to see them fail.** Controller: `test_run` on `popup_frames`, `stat_detail_popup`, `trait_detail_popup` and `week_recap_pill_info_popup`. Expected: the new tests fail on the missing frame.

- [ ] **Step 3: Edit the three scenes and scripts** as above.

- [ ] **Step 4: Fix old-path hits.** Run `grep -rn "Scrim/Card\|CloseButton\|close_button" tests/ Scripts/UI/StatDetailPopup.gd Scripts/UI/TraitDetailPopup.gd Scripts/UI/WeekRecapPillInfoPopup.gd`.
   - Each hit that concerns these three popups moves to the new path, or to the frame.
   - Where a test asserted the ✕ button's text or size, assert `frame.show_close` instead.
   - `test_popup_dismiss.gd`'s scrim `MOUSE_FILTER_IGNORE`/`STOP` source scans keep passing unchanged.

- [ ] **Step 5: Run to see them pass.** Controller: the four suites above, plus `popup_dismiss`, `student_card`, `result_checkup`, `audio_coverage` and the Controller-loop set. Then take one `editor_screenshot` of each scene opened in the editor.

- [ ] **Step 6: Commit** (`feat(popups): stat, trait and pill info open in the notebook dialog`).

---

### Task 3: The SchoolSimulation sheets — WeekLogs, DailyDecay, DaySummary

**Files:**
- Modify: `Scenes/SchoolSimulation/WeekLogsPopup.tscn`, `Scripts/SchoolSimulation/WeekLogsPopup.gd`
- Modify: `Scenes/SchoolSimulation/DailyDecayOverview.tscn`, `Scripts/SchoolSimulation/DailyDecayOverview.gd`
- Modify: `Scenes/SchoolSimulation/DaySummaryPopup.tscn`, `Scripts/SchoolSimulation/DaySummaryPopup.gd`
- Modify: `tests/test_popup_frames.gd` (3 rows), `tests/test_week_logs_popup.gd`, `tests/test_day_summary.gd`, `tests/test_school_day.gd`, plus every suite that the grep in Step 4 lists

**WeekLogsPopup:**

```
WeekLogsPopup (Control)
├ Scrim                                unchanged
└ Safe (SafeAreaMargin)                new, layout_mode 1, full rect, mouse_filter 2
  └ Center (CenterContainer)           the existing Center, re-parented under Safe:
  │                                     drop its anchor lines, layout_mode 2, mouse_filter 2
    └ Frame (NotebookFrame)            replaces Card: custom_minimum_size (900, 0), title_text "LOGS"
      └ Content (VBox)                 was Center/Card/Content
        └ Scroll → Rows → EmptyLabel   unchanged
```

- Delete `TitleLabel` ("LOGS") and `CloseButton` ("Tutup").
- Script:
  - `card` becomes `@onready var card: NotebookFrame = $Safe/Center/Frame`.
  - The `rows` and `empty_label` paths become `$Safe/Center/Frame/Content/Scroll/…`.
  - Delete `title_label` and `close_button`, and every line that uses them (read the file for them first).
  - Wire `card.close_pressed.connect(close)`.

**DailyDecayOverview** (full height, no ✕: "Lanjutkan Hari" stays the only way on, D4):

```
DailyDecayOverview (Control)
├ BackgroundDim                        unchanged
└ Safe (SafeAreaMargin)                replaces the outer Margin: layout_mode 1, full rect, mouse_filter 2
  └ Frame (NotebookFrame)              replaces Panel: layout_mode 2, title_text "EVALUASI",
    │                                   show_close false
    └ VBox                             was Margin/Panel/Margin/VBox, children unchanged
```

- The inner `Margin/Panel/Margin` MarginContainer is dropped; the frame pads the content.
- Script: `$Margin/Panel/Margin/VBox/` becomes `$Safe/Frame/VBox/` in every path.
- Read `_apply_visual_exports()`. If it inserts a texture behind the old `Panel` (`move_child(tex_rect, 0)`), target the frame's parent instead, so nothing lands inside the frame's host content.
- `TitleLabel` stays: it carries the day name.

**DaySummaryPopup** (a sheet whose banner art stays its title, so `title_text` is empty and the sticker hides):

```
DaySummaryPopup (Control)
├ Backdrop                             unchanged
└ DimOverlay (Scrim)                   unchanged
  └ Safe (SafeAreaMargin)              new, layout_mode 1, full rect, mouse_filter 2
    └ Content (VBox)                   was DimOverlay/Content: layout_mode 2, drop its anchor lines
      ├ TitleBanner                    unchanged
      └ Frame (NotebookFrame)          new, layout_mode 2, size_flags_vertical = 3, title_text ""
        └ Body (VBox)                  new, layout_mode 2, separation = the Content VBox's
          ├ Reward                     moved; set its custom_minimum_size to Vector2(0, 0)
          │                             (932 no longer fits inside the page)
          └ RowsScroll                 moved
  ```

- Script: `$DimOverlay/Content/Reward/` becomes `$DimOverlay/Safe/Content/Frame/Body/Reward/`, and the `RowsScroll/RowsContainer` path changes the same way. `content` becomes `$DimOverlay/Safe/Content`.
- Factor the body of the `_input` dismiss path into `func _dismiss() -> void`, keeping the `is_dismissable` guard.
- Wire the frame's close in `_ready` with `(%Frame as NotebookFrame).close_pressed.connect(_dismiss)`. Give the frame `unique_name_in_owner = true`.

- [ ] **Step 1: Write the failing tests.** Add to `POPUPS`:

```gdscript
	"res://Scenes/SchoolSimulation/WeekLogsPopup.tscn": ["Safe/Center/Frame", "sheet", "safe"],
	"res://Scenes/SchoolSimulation/DailyDecayOverview.tscn": ["Safe/Frame", "sheet", "safe"],
	"res://Scenes/SchoolSimulation/DaySummaryPopup.tscn": ["DimOverlay/Safe/Content/Frame", "sheet", "safe"],
```

Add to `tests/test_week_logs_popup.gd`:

```gdscript
func test_the_logs_sit_in_a_notebook_sheet() -> void:
	var popup := (load("res://Scenes/SchoolSimulation/WeekLogsPopup.tscn") as PackedScene).instantiate()
	track(popup)
	var frame := popup.get_node_or_null("Safe/Center/Frame") as NotebookFrame
	assert_true(frame != null, "the logs card is a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "LOGS")
	assert_true(popup.get_node_or_null("Safe/Center/Frame/Content/CloseButton") == null,
		"Tutup is the frame's round close now")
	assert_contains(FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/WeekLogsPopup.gd"),
		"card.close_pressed.connect(close)")
```

Add to `tests/test_day_summary.gd`:

```gdscript
func test_the_recap_sits_in_a_notebook_sheet_under_its_banner() -> void:
	var popup := (load("res://Scenes/SchoolSimulation/DaySummaryPopup.tscn") as PackedScene).instantiate()
	track(popup)
	var frame := popup.get_node_or_null("DimOverlay/Safe/Content/Frame") as NotebookFrame
	assert_true(frame != null, "the reward and rows sit in a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "", "the banner art stays the title, so the sticker hides")
		assert_true(frame.get_node_or_null("Body/Reward") != null, "the reward layer is inside")
		assert_true(frame.get_node_or_null("Body/RowsScroll") != null, "and the rows")
	assert_true(popup.get_node_or_null("DimOverlay/Safe/Content/TitleBanner") != null,
		"the banner stays above the frame")
```

Add to `tests/test_school_day.gd` (or whichever suite already covers DailyDecayOverview's scene; grep first):

```gdscript
func test_the_decay_overview_sits_in_a_notebook_sheet_without_a_close() -> void:
	var overview := (load("res://Scenes/SchoolSimulation/DailyDecayOverview.tscn") as PackedScene).instantiate()
	track(overview)
	var frame := overview.get_node_or_null("Safe/Frame") as NotebookFrame
	assert_true(frame != null, "the overview is a NotebookFrame")
	if frame != null:
		assert_false(frame.show_close, "Lanjutkan Hari stays the only way on")
		assert_true(frame.get_node_or_null("VBox/ContinueButton") != null)
```

- [ ] **Step 2: Run them to see them fail.** Controller: `popup_frames`, `week_logs_popup`, `day_summary` and `school_day`.
- [ ] **Step 3: Edit the three scenes and scripts** as above.
- [ ] **Step 4: Fix old-path hits.** Run `grep -rn "Center/Card\|Margin/Panel/Margin\|DimOverlay/Content" tests/ Scripts/ Scenes/` and fix every hit that concerns these popups. `test_viewport_editability` names DailyDecayOverview, so read that entry and keep its count unchanged.
- [ ] **Step 5: Run to see them pass.** Controller: the suites above, plus `result_checkup`, `day_verdict`, `inventory_text_size`, `audio_coverage`, `student_stat_row`, `student_summary_card` and the Controller-loop set. Then take one `editor_screenshot` per scene.
- [ ] **Step 6: Commit** (`feat(popups): the week logs, decay overview and day recap become notebook sheets`).

---

### Task 4: The item, achievement and earn-money sheets

**Files:**
- Modify: `Scenes/Inventory/ItemDetailSheet.tscn`, `Scripts/Inventory/ItemDetailSheet.gd`
- Modify: `Scenes/Achievements/AchievementDetailSheet.tscn`, `Scripts/Achievements/AchievementDetailSheet.gd`
- Modify: `Scenes/Lobby/DapatkanUang.tscn`, `Scripts/Lobby/DapatkanUang.gd`
- Modify: `tests/test_popup_frames.gd` (3 rows), `tests/test_item_detail_sheet.gd`, `tests/test_achievement_detail_sheet.gd`, `tests/test_dapatkan_uang.gd`, `tests/test_back_controls.gd`, plus every suite that the grep in Step 4 lists

**ItemDetailSheet** (D5: centred now):

```
ItemDetailSheet (Control, theme)
├ Scrim (ColorRect)                    unchanged
└ Safe (SafeAreaMargin)                new, layout_mode 1, full rect, mouse_filter 2
  └ Center (CenterContainer)           new, mouse_filter 2
    └ Sheet (NotebookFrame)            replaces the Sheet PanelContainer (same name, so $Sheet
      │                                 reads the same after the path prefix): custom_minimum_size
      │                                 (900, 0), title_text "DETAIL ITEM"
      └ VBox                           was Sheet/Margin/VBox (Margin dropped)
        ├ HeaderBand … ApplyButton     unchanged
        └ (Grabber deleted: a drag handle means nothing on a centred sheet)
```

- Script: `$Sheet/Margin/VBox/` becomes `$Safe/Center/Sheet/VBox/`. `_sheet` becomes `@onready var _sheet: NotebookFrame = $Safe/Center/Sheet`.
- Wire `_sheet.close_pressed.connect(_dismiss)` (guarded with `is_connected`, like the scrim's wiring). `_on_scrim_input`'s `_sheet.get_global_rect()` test still works.

**AchievementDetailSheet** (D2: no tabs):

```
AchievementDetailSheet (Control)
├ Scrim (%Scrim)                       unchanged
└ Safe (SafeAreaMargin)                new, layout_mode 1, full rect, mouse_filter 2
  └ Center (CenterContainer)           new, mouse_filter 2
    └ Sheet (NotebookFrame, %Sheet)    replaces the Sheet PanelContainer, keeping
      │                                 unique_name_in_owner so %Sheet still resolves:
      │                                 custom_minimum_size (900, 0), title_text "PENCAPAIAN"
      └ VBox                           was Sheet/Margin/VBox (Margin dropped)
        └ IconSlot, Title, Desc, PrizeChip, StateRow   unchanged (BackButton deleted)
```

- Script:
  - `_sheet: NotebookFrame = %Sheet`.
  - Delete `_back_button`.
  - In `_ready`: `if not _sheet.close_pressed.is_connected(_on_back_pressed): _sheet.close_pressed.connect(_on_back_pressed)`.
  - Update the header's "Closes on scrim tap, the back arrow, or Android back" to "the frame's close".
- Drop the `return_button.png` ext_resource if it is now unused.

**DapatkanUang:**

```
DapatkanUang (Control)
├ Scrim (%Scrim)                       unchanged
├ Safe (SafeAreaMargin)                new, layout_mode 1, full rect, mouse_filter 2
│ └ Center (CenterContainer)           new, mouse_filter 2
│   └ Book (NotebookFrame, %Book)      replaces the Book/Page panels, keeping unique_name_in_owner:
│     │                                 custom_minimum_size (900, 0), title_text "DAPATKAN UANG"
│     └ Column (VBox)                  was Book/Page/Margin/Column (Page and Margin dropped)
│       └ Subtitle … Tip               unchanged (Title "Dapatkan Uang" deleted)
└ Toast                                unchanged
```

- Delete `Tutup` (the ✕ DangerButton).
- Script:
  - Delete `close_button`.
  - Wire `(book as NotebookFrame).close_pressed.connect(close)`. `book` stays `%Book`; its type can become `NotebookFrame`.
  - `AnimUtils.popup_spring_in(book)` and `popup_spring_out(book, scrim, hide)` are unchanged.

- [ ] **Step 1: Write the failing tests.** Add to `POPUPS`:

```gdscript
	"res://Scenes/Inventory/ItemDetailSheet.tscn": ["Safe/Center/Sheet", "sheet", "safe"],
	"res://Scenes/Achievements/AchievementDetailSheet.tscn": ["Safe/Center/Sheet", "sheet", "safe"],
	"res://Scenes/Lobby/DapatkanUang.tscn": ["Safe/Center/Book", "sheet", "safe"],
```

In `tests/test_back_controls.gd`'s `ROSTER`, delete the `AchievementDetailSheet.tscn` entry and add a comment above `ROSTER`: "AchievementDetailSheet's back arrow became the notebook frame's round close (2026-09-28, UI depth pass Phase 2); tests/test_popup_frames.gd pins it."

Add to each of the three popup suites (`<path>`, `<frame path>`, `<title>` and `<script>` from the rows above):

```gdscript
func test_the_sheet_is_a_notebook_frame() -> void:
	var popup := (load("<path>") as PackedScene).instantiate()
	track(popup)
	var frame := popup.get_node_or_null("<frame path>") as NotebookFrame
	assert_true(frame != null, "the sheet is a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "<title>")
		assert_true(frame.tabs.is_empty(), "no tabs")
	assert_contains(FileAccess.get_file_as_string("<script>"), "close_pressed.connect",
		"the frame's close is wired")
```

- [ ] **Step 2: Run them to see them fail.** Controller: `popup_frames`, `item_detail_sheet`, `achievement_detail_sheet`, `dapatkan_uang` and `back_controls`.
- [ ] **Step 3: Edit the three scenes and scripts.**
- [ ] **Step 4: Fix old-path hits.** Run `grep -rn "Sheet/Margin\|Book/Page\|%Tutup\|\"Tutup\"\|BackButton\|close_button\|_back_button" tests/ Scripts/Inventory Scripts/Achievements Scripts/Lobby/DapatkanUang.gd` and fix every hit that concerns these three.
- [ ] **Step 5: Run to see them pass.** Controller: the suites above, plus `inventory`, `inventory_text_size`, `light_ground_text`, `achievement_screen`, `achievements_grid`, `button_geometry`, `lobby` and the Controller-loop set. Then take one `editor_screenshot` per scene.
- [ ] **Step 6: Commit** (`feat(popups): item, achievement and earn-money sheets move into the notebook`).

---

### Task 5: Settings — the tabbed notebook

**Files:**
- Modify: `Scenes/UI/Settings.tscn`, `Scripts/UI/Settings.gd`
- Modify: `tests/test_popup_frames.gd` (1 row), `tests/test_settings.gd`, `tests/test_tall_screen_layout.gd` (the Settings block), `tests/test_back_controls.gd` (the Settings row), `tests/test_device_back_button.gd` (only if it pins the button)

**Target tree** (D1):

```
Settings (Control)
├ Background                           unchanged
└ SafeArea (SafeAreaMargin)            unchanged, plus root override extra_margin = Vector4(0, 72, 0, 0)
  │                                     (the tabs stand 60 px above the frame)
  └ Frame (NotebookFrame, %Frame)      replaces MainColumn: layout_mode 2, title_text "PENGATURAN",
    │                                   tabs ["SUARA", "MAIN"], active_tab 0
    └ Scroll (ScrollContainer)         was SafeArea/MainColumn/Scroll, children unchanged
      └ Pad → Sections (%Sections)
        ├ AudioCard                    SUARA tab
        ├ GameplayCard                 MAIN tab
        └ DisplayCard                  MAIN tab
```

- Delete `Header` (the "PENGATURAN" title card) and `BackButton` ("Kembali"). The frame's ✕ is the way back (D4: it runs the same `_on_back_pressed`).
- **The three section cards lose their `Card` chrome**, since the page and its well are the surface now. Change each card block's `type="PanelContainer"` to `type="VBoxContainer"` and delete its `theme_type_variation = &"Card"` line. The names stay, so `%Sections`' children and the test tables keep their keys.
- Drop the `return_button.png` ext_resource if it is unused.

**Script** (`Scripts/UI/Settings.gd`):
- Delete `_back`; add `@onready var _frame: NotebookFrame = %Frame`.
- In `_ready()`, in place of `_back.pressed.connect(_on_back_pressed)`:

  ```gdscript
  	_frame.close_pressed.connect(_on_back_pressed)
  	_frame.tab_selected.connect(show_tab)
  	show_tab(_frame.active_tab)
  ```

- Add the tab consts and function:

  ```gdscript
  ## The SUARA tab: the three volume sliders.
  const TAB_SUARA := 0
  ## The MAIN tab: the gameplay and display switches.
  const TAB_MAIN := 1


  ## Show tab `index`'s sections: SUARA holds AudioCard, MAIN the gameplay and
  ## display cards. Public so the tests can switch tabs without a press.
  func show_tab(index: int) -> void:
  	%AudioCard.visible = index == TAB_SUARA
  	%GameplayCard.visible = index == TAB_MAIN
  	%DisplayCard.visible = index == TAB_MAIN
  ```

  Give `AudioCard`, `GameplayCard` and `DisplayCard` `unique_name_in_owner = true` in the scene.
- `_collect_entry_nodes()` becomes `[_frame]`: the frame pops in whole.
- Update the file header's second paragraph: "the title card" and "Kembali" become the frame.

- [ ] **Step 1: Write the failing tests.**

Add to `POPUPS`:

```gdscript
	"res://Scenes/UI/Settings.tscn": ["SafeArea/Frame", "tabs", "safe"],
```

In `tests/test_back_controls.gd`, delete the Settings `ROSTER` entry and extend the Task 4 comment to name Settings' Kembali too.

In `tests/test_settings.gd`:
- Replace `test_back_button_exists_and_is_wired` with:

  ```gdscript
  func test_the_frame_close_is_the_way_back() -> void:
  	var frame := _screen.get_node("SafeArea/Frame") as NotebookFrame
  	assert_true(frame.show_close, "the round close is the way back")
  	assert_contains(FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd"),
  		"_frame.close_pressed.connect(_on_back_pressed)")
  ```

- Add:

  ```gdscript
  func test_the_tabs_are_suara_and_main() -> void:
  	var frame := _screen.get_node("SafeArea/Frame") as NotebookFrame
  	assert_eq(Array(frame.tabs), ["SUARA", "MAIN"])
  	assert_eq(frame.title_text, "PENGATURAN")


  func test_each_tab_shows_its_sections() -> void:
  	_screen.show_tab(0)
  	assert_true(_screen.get_node("%AudioCard").visible, "SUARA shows the sliders")
  	assert_false(_screen.get_node("%GameplayCard").visible)
  	assert_false(_screen.get_node("%DisplayCard").visible)
  	_screen.show_tab(1)
  	assert_false(_screen.get_node("%AudioCard").visible)
  	assert_true(_screen.get_node("%GameplayCard").visible, "MAIN shows the switches")
  	assert_true(_screen.get_node("%DisplayCard").visible)
  ```

- Update these to the new shape. Read each first; keep what each one proves, and change only the surface it names:
  - `test_header_is_a_title_card` becomes "the title is the frame's sticker".
  - `test_back_button_sits_at_the_bottom`: the close sits on the frame's top-right corner.
  - `test_sections_scroll_under_the_header`: the scroll is the frame's host content.
  - `test_settings_are_grouped_into_three_titled_cards`: three titled sections, now plain VBoxes.
  - `test_entry_stagger_runs_top_to_bottom`: the entry pops the frame.
  - `test_every_card_fits_the_design_screen_without_scrolling`: each **tab's** sections fit without scrolling.

In `tests/test_tall_screen_layout.gd`, replace `_assert_settings_fills` and keep its two callers:

```gdscript
## At `screen` size: the notebook fills the safe area below the tabs' 72 px
## headroom, so the page grows with a tall phone and its tabs stay on screen.
func _assert_settings_fills(screen: Vector2) -> void:
	var s := _stood_up(SETTINGS, screen)
	var frame := s.get_node("SafeArea/Frame") as Control
	_assert_rect(frame.get_global_rect(),
		Rect2(Vector2(48, 48 + 72), Vector2(screen.x - 96, screen.y - 96 - 72)), "the Settings notebook")
```

`test_settings_column_is_inside_the_safe_area` changes its path to `SafeArea/Frame` (and "MainColumn" to "Frame" in its label).

- [ ] **Step 2: Run them to see them fail.** Controller: `popup_frames`, `settings`, `tall_screen_layout` and `back_controls`.
- [ ] **Step 3: Edit the scene and the script.**
- [ ] **Step 4: Fix old-path hits.** Run `grep -rn "MainColumn\|SafeArea/MainColumn\|%BackButton\|_back\b" tests/ Scripts/UI/Settings.gd` and fix every Settings hit. `test_ui_components.gd` line ~87 mentions Settings' column in a comment; update the comment if its code reads Settings.
- [ ] **Step 5: Run to see them pass.** Controller: the suites above, plus `device_back_button`, `ui_components`, `haptics`, `look_layer`, `ambient_kit` and the Controller-loop set. Then take a full-size `editor_screenshot` of Settings on both tabs. For the 20:9 check, `test_tall_screen_layout` stands Settings up at 1080x2400.
- [ ] **Step 6: Commit** (`feat(settings): a tabbed notebook, SUARA and MAIN`).

---

### Task 6: Dialogs with a button pair — the event picker, the amplop letter and Peringatan

**Files:**
- Modify: `Scenes/SchoolSimulation/EventStudentSelectDialog.tscn`, `Scripts/SchoolSimulation/EventStudentSelectDialog.gd`
- Modify: `Scenes/LevelSelect/OpenAmplopConfirm.tscn`, `Scripts/LevelSelect/OpenAmplopConfirm.gd`
- Modify: `Scenes/AturJadwal/AturJadwal.tscn` (the Peringatan block only), `Scripts/AturJadwal/AturJadwal.gd`
- Modify: `tests/test_popup_frames.gd` (3 rows + 1 `SCREEN_SCRIPTS` entry), `tests/test_atur_jadwal.gd`, `tests/test_level_select.gd`, `tests/test_event_polish.gd` (or whichever suite owns the event dialog's scene; grep), plus every suite that the grep in Step 4 lists

**EventStudentSelectDialog** (full height, no ✕: Tolak / Terima is the decision, D4):

```
EventStudentSelectDialog (Control)
├ Background, BackgroundDim            unchanged
└ Safe (SafeAreaMargin)                replaces Margin: layout_mode 1, full rect, mouse_filter 2
  └ Frame (NotebookFrame)              replaces DialogPanel: layout_mode 2, title_text "ACARA",
    │                                   ring_count 4, show_well false, show_close false
    └ MainVBox                         was Margin/DialogPanel/Margin/MainVBox, children unchanged
```

- Script:
  - `$Margin/DialogPanel/Margin/MainVBox/` becomes `$Safe/Frame/MainVBox/` in every path.
  - `dialog_panel` becomes `@onready var dialog_panel: NotebookFrame = $Safe/Frame`.
  - Read every use of `dialog_panel`; anything that styled it as a `PanelContainer` (a stylebox override) is deleted, because the frame is the surface.

**OpenAmplopConfirm** (fit `free`, D6; the ✕ means Batal):

```
OpenAmplopConfirm (Control)
├ Scrim, Envelope                      unchanged
├ Letter (NotebookFrame, %Letter)      replaces the Letter Panel, keeping its unique name, anchors
│ │                                     and offsets, plus grow_horizontal = 2, grow_vertical = 2:
│ │                                     title_text "SURAT TUGAS", ring_count 4, show_well false
│ └ VBox                               was Letter/Margin/VBox (Margin dropped), Kicker deleted
│   └ Title (%Title), Body (%Body)     unchanged
└ Buttons                              unchanged
```

- Script:
  - Add the handler below. Wire it in `_ready` with `_letter.close_pressed.connect(_on_close_pressed)`, and type `_letter` as `NotebookFrame`.

    ```gdscript
    ## The frame's round close is Batal: it cancels, but only while Batal
    ## itself could be pressed (the buttons are off while the letter animates).
    func _on_close_pressed() -> void:
    	if not _cancel.disabled:
    		cancelled.emit()
    ```

  - Read `play_open()`, `_rest_letter()` and `_set_buttons_enabled()`. The letter's rise still tweens `position.y` from its authored rest, and a frame outside any container keeps its authored offsets, so they need no change. Say so in the report after checking.

**Peringatan** (in `AturJadwal.tscn`):

```
Peringatan (Control)                   keep visible = false; offsets all 0 (full rect); mouse_filter = 2
└ Safe (SafeAreaMargin)                new, layout_mode 1, full rect, mouse_filter 2
  └ Center (CenterContainer)           new, mouse_filter 2
    └ Frame (NotebookFrame)            replaces TextureRect (the nine-patch): custom_minimum_size (760, 0),
      │                                 title_text "PERINGATAN", ring_count 4, show_well false
      └ Body (VBox)                    new, layout_mode 2, theme_override_constants/separation = 24
        ├ Label                        moved; layout_mode 2; custom_minimum_size = Vector2(620, 0);
        │                               delete its offsets; keep its variation, alignments, autowrap
        └ Buttons (HBox)               new, layout_mode 2, alignment = 1, separation = 48
          ├ ButtonYes                  moved; layout_mode 2; delete its offsets; custom_minimum_size (200, 96)
          └ ButtonNo                   the same
```

- Delete the `9_cardbg` (`penjadwalan_card_bg.png`) ext_resource if nothing else in the file uses it.
- Script (`AturJadwal.gd`):
  - Replace `$Peringatan/TextureRect/` with `$Peringatan/Safe/Center/Frame/Body/` for `Label`, and with `$Peringatan/Safe/Center/Frame/Body/Buttons/` for `ButtonYes` and `ButtonNo`.
  - Wire the frame's close next to the yes/no wiring (around line 481):

    ```gdscript
    	var peringatan_frame := $Peringatan/Safe/Center/Frame as NotebookFrame
    	if not peringatan_frame.close_pressed.is_connected(_on_peringatan_no):
    		peringatan_frame.close_pressed.connect(_on_peringatan_no)
    ```

  - Take the heading out of each warning string, because the sticker says it now:
    - `"PERINGATAN\n\n…"` becomes `"…"`
    - `"PERINGATAN MOOD & JADWAL\n\n…"` becomes `"Mood & Jadwal\n\n…"`
    - `"PERINGATAN MOOD SANGAT RENDAH\n\n…"` becomes `"Mood Sangat Rendah\n\n…"`
    - `"PERINGATAN JADWAL\n\n…"` becomes `"Jadwal\n\n…"`
    - The same in the scene's authored `Label` text.
  - `_show_peringatan()`'s font-size shrink stays as it is (behaviour kept).

- [ ] **Step 1: Write the failing tests.** Add to `POPUPS` and `SCREEN_SCRIPTS`:

```gdscript
	"res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn": ["Safe/Frame", "dialog", "safe"],
	# free: the letter rises out of the envelope by tweening its position,
	# which a container would reset; it is anchored to the screen's centre.
	"res://Scenes/LevelSelect/OpenAmplopConfirm.tscn": ["Letter", "dialog", "free"],
	"res://Scenes/AturJadwal/AturJadwal.tscn": ["Peringatan/Safe/Center/Frame", "dialog", "safe"],
```

```gdscript
	"res://Scenes/AturJadwal/AturJadwal.tscn": "res://Scripts/AturJadwal/AturJadwal.gd",
```

In `tests/test_atur_jadwal.gd`:
- Replace `test_peringatan_frame_is_a_ninepatch_of_the_card_art` with:

  ```gdscript
  ## The warning dialog is the notebook dialog (2026-09-28, UI depth pass
  ## Phase 2). It used to crop penjadwalan_card_bg.png as a nine-patch.
  func test_peringatan_is_the_notebook_dialog() -> void:
  	var frame := _screen.get_node_or_null("Peringatan/Safe/Center/Frame") as NotebookFrame
  	assert_true(frame != null, "Peringatan's box is a NotebookFrame")
  	if frame == null:
  		return
  	assert_eq(frame.title_text, "PERINGATAN")
  	for child in ["Body/Label", "Body/Buttons/ButtonYes", "Body/Buttons/ButtonNo"]:
  		assert_true(frame.get_node_or_null(child) != null, "%s survived the move" % child)
  ```

- In `test_no_pngwing_placeholder_remains_in_the_warning_dialog`, keep the pngwing assertion and add `assert_false(block.contains("9_cardbg"), "and no longer crops the card art")`.
- Update the paths at lines ~126, ~149 and ~505, and any other `Peringatan/TextureRect` hit.

Add to `tests/test_level_select.gd`:

```gdscript
func test_the_letter_is_the_notebook_dialog() -> void:
	var confirm := (load("res://Scenes/LevelSelect/OpenAmplopConfirm.tscn") as PackedScene).instantiate()
	track(confirm)
	var letter := confirm.get_node_or_null("Letter") as NotebookFrame
	assert_true(letter != null, "the letter is a NotebookFrame")
	if letter != null:
		assert_eq(letter.title_text, "SURAT TUGAS", "the kicker became the sticker")
	assert_contains(FileAccess.get_file_as_string("res://Scripts/LevelSelect/OpenAmplopConfirm.gd"),
		"_letter.close_pressed.connect(_on_close_pressed)")
```

Add to the event dialog's suite:

```gdscript
func test_the_event_picker_is_the_notebook_dialog_without_a_close() -> void:
	var dialog := (load("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn") as PackedScene).instantiate()
	track(dialog)
	var frame := dialog.get_node_or_null("Safe/Frame") as NotebookFrame
	assert_true(frame != null, "the picker is a NotebookFrame")
	if frame != null:
		assert_false(frame.show_close, "Tolak / Terima is the decision; no third way out")
		assert_true(frame.get_node_or_null("MainVBox/ActionVBox/ConfirmButton") != null)
```

- [ ] **Step 2: Run them to see them fail.** Controller: `popup_frames`, `atur_jadwal`, `level_select` and the event suite.
- [ ] **Step 3: Edit the scenes and scripts.**
- [ ] **Step 4: Fix old-path hits.** Run `grep -rn "Margin/DialogPanel\|Peringatan/TextureRect\|Letter/Margin\|Kicker" tests/ Scripts/ Scenes/LevelSelect Scenes/SchoolSimulation` and fix every hit that concerns these three.
- [ ] **Step 5: Run to see them pass.** Controller: the suites above, plus `confirm_pair_semantics`, `day_summary`, `school_day`, `student_summary_card`, `atur_jadwal_specialty_feedback`, `button_geometry`, `cream_panel_tokens` and the Controller-loop set. Then take one `editor_screenshot` per popup (AturJadwal with Peringatan made visible in the editor's in-memory scene only; **do not save it**).
- [ ] **Step 6: Commit** (`feat(popups): the event picker, amplop letter and Peringatan become notebook dialogs`).

---

### Task 7: Forced-flow dialogs — TesNotice, StatCheck and TutorialPanel

**Files:**
- Modify: `Scenes/EndGame/TesNotice.tscn`, `Scripts/EndGame/TesNotice.gd`
- Modify: `Scenes/EndGame/StatCheck.tscn`, `Scripts/EndGame/StatCheck.gd`
- Modify: `Scenes/UI/TutorialPanel.tscn`, `Scripts/UI/TutorialPanel.gd`, `Scripts/StudentCard/StudentCard.gd`, `Scripts/SchoolSimulation/SchoolDay.gd` (only if it reaches a TutorialPanel child by path)
- Modify: `tests/test_popup_frames.gd` (3 rows), `tests/test_tes_notice.gd`, `tests/test_stat_check.gd`, `tests/test_tutorial_panel.gd`, plus every suite that the grep in Step 4 lists

All three have **no ✕** (D4).

**TesNotice:**

```
TesNotice (Control)
├ World …, Scrim                       unchanged
└ Safe (SafeAreaMargin)                replaces MarginContainer: layout_mode 1, full rect, mouse_filter 2
  └ Center (CenterContainer)           new, mouse_filter 2
    └ NoticeCard (NotebookFrame)       replaces the NinePatchRect (same name): custom_minimum_size (860, 0),
      │                                 title_text "PENGUMUMAN", ring_count 4, show_well false, show_close false
      └ Content (VBox)                 children unchanged except Kicker (deleted)
```

- Script: `$MarginContainer/NoticeCard/` becomes `$Safe/Center/NoticeCard/`, and `notice_card: NotebookFrame`.
- Drop the `notice.png` ext_resource.

**StatCheck** (the cards slide through the frame, so the slot clips them):

```
StatCheck (Control)
├ World …, Scrim                       unchanged
├ Safe (SafeAreaMargin)                replaces MarginContainer: layout_mode 1, full rect, mouse_filter 2
│ └ Center (CenterContainer)           new, mouse_filter 2
│   └ Frame (NotebookFrame)            new: title_text "CEK NILAI", ring_count 4, show_well false, show_close false
│     └ Column (VBox)                  unchanged
│       ├ CardSlot                     unchanged plus clip_contents = true
│       └ StarMeter                    unchanged
└ WhiteFade                            unchanged
```

- Script: `$MarginContainer/Column/` becomes `$Safe/Center/Frame/Column/`.
- `_slide_in`/`_slide_out` tween the card's `position.x` inside `CardSlot`, so they need no change; the clip hides the travel.

**TutorialPanel** (fit `free`: each caller places it):

```
TutorialPanel (MarginContainer)        was a PanelContainer wearing Card: type becomes
│                                       MarginContainer, theme_type_variation line deleted
└ Frame (NotebookFrame)                new, layout_mode 2: title_text "TUTORIAL", ring_count 4,
  │                                     show_well false, show_close false
  └ Margin → Layout → TitleLabel, Separator1, BodyLabel, Separator2, PromptLabel   unchanged
```

- Script:
  - `extends PanelContainer` becomes `extends MarginContainer`.
  - `$Margin/` becomes `$Frame/Margin/` in the `@onready` paths.
  - Update the header to say the panel is a notebook dialog.
- `Scripts/StudentCard/StudentCard.gd`: `"Margin/Layout/` becomes `"Frame/Margin/Layout/` in its `get_node` calls (around line 322).
- Run `grep -rn "TutorialPanel\|_tutorial_panel" Scripts/`. Any caller that sets a `panel` stylebox or `theme_type_variation` on a `TutorialPanel.tscn` instance loses that line (the frame is the surface).
- Leave alone the runtime-built `PanelContainer.new()` tutorial panels in `AturJadwal.gd` and `Lobby.gd`, which are not this scene. They are logged in DEBT in Task 9.

- [ ] **Step 1: Write the failing tests.** Add to `POPUPS`:

```gdscript
	"res://Scenes/EndGame/TesNotice.tscn": ["Safe/Center/NoticeCard", "dialog", "safe"],
	"res://Scenes/EndGame/StatCheck.tscn": ["Safe/Center/Frame", "dialog", "safe"],
	# free: StudentCard and SchoolDay each place the panel themselves.
	"res://Scenes/UI/TutorialPanel.tscn": ["Frame", "dialog", "free"],
```

Add to `tests/test_tes_notice.gd`, `tests/test_stat_check.gd` and `tests/test_tutorial_panel.gd` (with each scene's row values):

```gdscript
func test_it_is_the_notebook_dialog_with_no_way_out() -> void:
	var root := (load("<path>") as PackedScene).instantiate()
	track(root)
	var frame := root.get_node_or_null("<frame path>") as NotebookFrame
	assert_true(frame != null, "the card is a NotebookFrame")
	if frame != null:
		assert_eq(frame.title_text, "<title>")
		assert_false(frame.show_close, "a forced step shows no close")
```

Also add to `tests/test_stat_check.gd`:

```gdscript
func test_the_card_slot_clips_the_slide() -> void:
	var root := (load("res://Scenes/EndGame/StatCheck.tscn") as PackedScene).instantiate()
	track(root)
	var slot := root.get_node("Safe/Center/Frame/Column/CardSlot") as Control
	assert_true(slot.clip_contents, "a card sliding in or out never draws over the frame")
```

- [ ] **Step 2: Run them to see them fail.** Controller: `popup_frames`, `tes_notice`, `stat_check` and `tutorial_panel`.
- [ ] **Step 3: Edit the scenes and scripts.**
- [ ] **Step 4: Fix old-path hits.** Run `grep -rn "MarginContainer/NoticeCard\|MarginContainer/Column\|\"Margin/Layout" tests/ Scripts/` and fix every hit. StatCheck is named by about 19 suites, and most name only its World/Scrim nodes. Read each hit, don't guess.
- [ ] **Step 5: Run to see them pass.** Controller: the suites above, plus `tall_screen_layout`, `end_game_rehearsal`, `exam_progress`, `end_cutscene`, `illustration_ao`, `lobby_look`, `look_layer`, `parallax_diorama`, `ambient_kit`, `light_ground_text`, `student_card`, `school_day`, `win_stage`, `run_result`, `minigame_result_popup`, `cutscene`, `day_summary`, `project_hygiene`, `theme_factory` and the Controller-loop set. Then take one `editor_screenshot` per scene.
- [ ] **Step 6: Commit** (`feat(popups): the exam notice, stat check and tutorial panel become notebook dialogs`).

---

### Task 8: The Lobby's DailyLogin

**Files:**
- Modify: `Scenes/Lobby/Lobby.tscn` (the `DailyReward` subtree only)
- Modify: `Scripts/Lobby/Lobby.gd` (`_setup_daily_login` only)
- Modify: `tests/test_popup_frames.gd` (1 row + 1 `SCREEN_SCRIPTS` entry), `tests/test_daily_login_panel.gd`, plus every suite that the grep in Step 4 lists

**Why this shape** (D6):
- `DailyReward` is the `DailyLoginPanel` script node, a `TextureRect` whose per-day art bakes the calendar.
- Its children sit at fixed offsets over that art, and it shows, hides and scales **itself** on open and close.
- So the frame goes **inside** it, as the first child drawn **behind** it (`show_behind_parent`). It rides every open, close and scale for free, and nothing about the panel's own layout moves.
- The frame has no host content, so `content_padding` is irrelevant. It has no rings, because the calendar art spans the width.

**Target:**

```
DailyReward (TextureRect, DailyLoginPanel)   unchanged, except its "Label" child ("Daily Login") is deleted
├ DailyLoginFrame (NotebookFrame)            new, FIRST child: unique_name_in_owner = true,
│                                             show_behind_parent = true, layout_mode = 1, anchors_preset = 15,
│                                             anchor_right = 1.0, anchor_bottom = 1.0,
│                                             offset_left = -40.0, offset_top = -290.0,
│                                             offset_right = 0.0, offset_bottom = 80.0,
│                                             title_text "DAILY LOGIN", ring_count 0, show_well false
├ ButtonClaim, RewardRow, DailyGreeting, DailyStreak, DailyRewardReveal, BesokTeaser   unchanged
```

- The offsets are chosen to hold the greeting and streak line (up to 170 px above the art), the sticker above them, and BesokTeaser below (to 474 px). They also keep the ✕ inside 1080 px, since the art is off-centre (−460 … +482). Task 9's screenshot is the check.
- `Lobby.gd`, at the end of `_setup_daily_login()`:

  ```gdscript
  	var frame := %DailyLoginFrame as NotebookFrame
  	if not frame.close_pressed.is_connected(_hide_daily_reward):
  		frame.close_pressed.connect(_hide_daily_reward)
  ```

  Read `_hide_daily_reward()` first. If it takes arguments, or is not the function the blur-overlay tap calls, wire to whichever function the tap-outside path uses.

- [ ] **Step 1: Write the failing tests.** Add to `POPUPS` and `SCREEN_SCRIPTS`:

```gdscript
	# free: the frame is drawn behind the calendar art it wraps, so it
	# rides DailyLoginPanel's own show, hide and scale.
	"res://Scenes/Lobby/Lobby.tscn": ["DailyReward/DailyLoginFrame", "sheet", "free"],
```

```gdscript
	"res://Scenes/Lobby/Lobby.tscn": "res://Scripts/Lobby/Lobby.gd",
```

Add to `tests/test_daily_login_panel.gd`:

```gdscript
func test_the_calendar_sits_on_a_notebook_page() -> void:
	var lobby := (load("res://Scenes/Lobby/Lobby.tscn") as PackedScene).instantiate()
	track(lobby)
	var panel := lobby.get_node("DailyReward") as Control
	var frame := panel.get_node_or_null("DailyLoginFrame") as NotebookFrame
	assert_true(frame != null, "the daily-login panel wears the notebook frame")
	if frame == null:
		return
	assert_eq(frame.get_index(), 0, "the frame is the first child")
	assert_true(frame.show_behind_parent, "and drawn behind the calendar art")
	assert_eq(frame.title_text, "DAILY LOGIN", "the old title label became the sticker")
	assert_true(panel.get_node_or_null("Label") == null, "the old title label is gone")


func test_the_frame_is_on_screen_at_the_design_size() -> void:
	var lobby := (load("res://Scenes/Lobby/Lobby.tscn") as PackedScene).instantiate()
	track(lobby)
	var panel := lobby.get_node("DailyReward") as Control
	var frame := panel.get_node("DailyLoginFrame") as Control
	# Out of the tree, anchors resolve against the offsets alone, so read the
	# rect as the panel's authored centre-anchored offsets plus the frame's.
	var left := 540.0 + panel.offset_left + frame.offset_left
	var right := 540.0 + panel.offset_right + frame.offset_right
	assert_true(left - 12 >= 0.0, "the cover's left edge is on screen (%d)" % left)
	assert_true(right + 36 <= 1080.0, "the close is on screen (%d)" % right)
```

- [ ] **Step 2: Run them to see them fail.** Controller: `popup_frames` and `daily_login_panel`.
- [ ] **Step 3: Edit `Lobby.tscn` and `Lobby.gd`.** Lobby.tscn is large and mentor-approved, so touch **only** the `DailyReward` subtree and add the one ext_resource. After the edit, `git diff --stat -- Scenes/Lobby/Lobby.tscn` must show only those hunks.
- [ ] **Step 4: Fix old-path hits.** Run `grep -rn "DailyReward/Label\|\"Daily Login\"" tests/ Scripts/` and fix every hit.
- [ ] **Step 5: Run to see them pass.** Controller: the suites above, plus `lobby`, `lobby_hud`, `lobby_layout`, `tall_screen_layout`, `ui_icon_refresh`, `dapatkan_uang` and the Controller-loop set. Then check it live: run the game, **⚡ Seed Playtest State**, teleport to the Lobby and tap the daily-login rail icon. Take full-size screenshots at 1080x1920 and 1080x2400.
- [ ] **Step 6: Commit** (`feat(lobby): the daily login sits on a notebook page`).

---

### Task 9: Docs, the full run, the screenshot pass and ship

**Files:**
- Modify: `docs/superpowers/design/style-guide.md` ("The notebook frame")
- Modify: `docs/superpowers/DEBT.md` (the "UI depth pass, Phases 2–3" entry)
- Modify: `docs/superpowers/CHANGELOG.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Style guide.** Extend "The notebook frame" with the host recipe:
  - `SafeAreaMargin → CenterContainer → Frame` for a centred popup; `SafeAreaMargin → Frame` for a full-height one.
  - `Safe` and `Center` ignore taps, and the page stops them.
  - The popup's close control is deleted and `close_pressed` wired to its handler; the ✕ is hidden where it would add a new way out.
  - A short fixed sticker word; the dynamic heading stays in the content.
  - The three kinds.
  - `tests/test_popup_frames.gd` is the roster: a new popup adds its row.
- [ ] **Step 2: DEBT.**
  - Delete the `_get_minimum_size()` bullet (solved).
  - Keep the `Hapus` bullet for Phase 3.
  - Add a bullet for the assets that became unused: `Assets/Images/UI/notice.png`, `Assets/Images/UI/penjadwalan_card_bg.png` (only if a grep of `Scenes/` and `Scripts/` finds no other user), and the TextureRect `day*.png` art, which stays in use.
  - Add a bullet for the runtime-built tutorial panels in `AturJadwal.gd` and `Lobby.gd` that are not `TutorialPanel.tscn` and so did not get the frame.
- [ ] **Step 3: CHANGELOG.** Add a newest-first entry, "2026-09-28 — UI depth pass, Phase 2: popups into the notebook". It lists the 17 popups by kind, the six decisions D1–D6, and the new suite.
- [ ] **Step 4: CLAUDE.md.**
  - Delete the `penjadwalan_card_bg.png` bullet under "Asset constraints": the Peringatan dialog no longer crops it.
  - Add one line after the Cards paragraph: "**Popups** sit in `NotebookFrame` (style guide, 'The notebook frame'); `tests/test_popup_frames.gd` is the roster."
  - Update the suite count once the full run gives it.
  - Keep the file under 23,000 characters (`wc -c CLAUDE.md`).
- [ ] **Step 5: Full run.** Controller: restart the worktree editor fresh, open `Scenes/MainMenu/MainMenu.tscn`, run a full `test_run`, fix real breakage and re-run.
  - A failing theme assertion in a full run may be ordering; re-run that suite alone before believing it.
  - After the run: `git status`. Revert `Assets/Audio/default_bus_layout.tres`. Keep `Assets/Theme/kejartes_theme.tres` only if it changed by content, and check that `grep -c 'type="Script"' Assets/Theme/kejartes_theme.tres` prints 0.
- [ ] **Step 6: Screenshot pass.** Take a full-size screenshot of every popup at 1080x1920. For the popups in `SafeAreaMargin`, also take one at 1080x2400: `resize_window` or the tall-screen stand-up.
  - Use the in-editor scene view for the stand-alone popups.
  - Use a live run (Seed Playtest State + Scenes tab teleports) for Settings, DapatkanUang, DailyLogin and AturJadwal's Peringatan.
  - Judge each for: the ✕ and cover on screen, no clipped text, the sticker fitting its title, and tabs visible.
  - Send the contact sheet to the owner with SendUserFile.
- [ ] **Step 7: Commit the docs** (`docs(ui-depth): phase 2 notebook popups`), then ship with the `ship-pr` skill. It stamps only the exact commit the full suite ran on.

---

## Self-review

- **Spec coverage.** Every popup in the spec's Rollout step 2 has a task and a roster row:
  - Settings (Task 5)
  - AchievementDetailSheet, ItemDetailSheet and DapatkanUang (Task 4)
  - DailyLoginPanel (Task 8)
  - WeekLogsPopup, DaySummaryPopup and DailyDecayOverview (Task 3)
  - StatDetail, TraitDetail and WeekRecapPillInfo (Task 2)
  - EventStudentSelectDialog, OpenAmplopConfirm and Peringatan (Task 6)
  - TesNotice, StatCheck and TutorialPanel (Task 7)
- **The prerequisites** are all covered:
  - minimum size (Task 1)
  - the nested-instance test (Task 1)
  - the typed ✕ removed from the three dialogs (Task 2, and pinned for all by `test_no_popup_types_its_close_glyph`)
  - tall phones (fit `safe` rows, plus `tall_screen_layout` in Tasks 5 and 7)
- **Where the spec was not followed literally** (D2, D6) is written down as a decision, not left silent.
- **Names used across tasks:** `NotebookFrame`, `close_pressed`, `tab_selected`, `title_text`, `ring_count`, `show_well`, `show_close`, `POPUPS`, `SCREEN_SCRIPTS`, `STICKER_MIN_WIDTH`, `STICKER_SIDE_PAD`, `show_tab`.
