# Tall-Phone Layout — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:executing-plans
> (inline), not subagent-driven-development. Almost every task edits scenes
> through the Godot editor bridge, which is single-client (CLAUDE.md, "The
> bridge is single-client"): a subagent cannot hold it. Steps use checkbox
> (`- [ ]`) syntax for tracking.

**Goal:** On a 20:9 phone (viewport 1080×2400), the Lobby, Koperasi,
StudentCard and StudentList fill the screen: no bare gray band, students on
their desks, and the UI on the real screen edges. At 1080×1920 they look as
they do today.

**Architecture:** Each screen follows the spec's four rules:
1. Backgrounds are Full Rect + Keep Aspect Covered.
2. UI is re-anchored to its edge without moving: the anchors change and the
   offsets are converted, so the 1080×1920 rect is unchanged.
3. That UI sits in `SafeAreaMargin` → `UI` → edge groups.
4. A picture and the items on it move as one fixed-size piece.

A new suite, `tests/test_tall_screen_layout.gd`, pins each rule. It also
stands every screen up at 1080×2400 through a small helper,
`tests/layout_frame.gd`, and checks real rects there.

**Tech Stack:** Godot 4.6.2, GDScript, the godot-ai MCP editor bridge
(`scene_open`, `batch_execute`, `scene_save`, `script_patch`, `test_run`,
`project_run`, `editor_manage(op="game_eval")`), McpTestSuite.

**Spec:** `docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md`.
**Branch:** `fix/tall-phone-layout`, already checked out in the main
checkout. Phases 2 and 3 get their own plans.

## Global Constraints

- **Invariant.** At 1080×1920 every screen renders as it does today. Phase 1
  allows two exceptions:
  - the Lobby classroom's background covers instead of fitting, so its
    ~4 px gray side slivers go;
  - the Lobby root's stray `offset_left = -3` is removed.
- **Rule 1.** A background is a `TextureRect` with anchors `0,0,1,1`,
  offsets 0, `expand_mode = 1` and `stretch_mode = 6`.
- **Rule 2.** New offset = `old_global − (parent_origin + anchor ×
  parent_size)`, measured at 1080×1920.
  - Set all four anchors explicitly; `anchors_preset` is inert over MCP.
  - On a Control under a plain Control, set `layout_mode = 1` before the
    anchors, or they are not saved.
- **Rule 3.** Each edge-UI screen has a Full Rect `SafeAreaMargin` named
  `Safe`, holding one plain `Control` named `UI`. `Safe`, `UI` and every
  bar Control have `mouse_filter = 2` (IGNORE).
  - The margin is the theme's `screen_margin`, 48 px. It is not 50.
  - At 1080×1920 in the editor, `UI` spans (48,48)–(1032,1872), size
    984×1824.
- **Rule 4.** A picture unit is one Control at the art's size, anchored as
  a whole.
- **Unique names.** Every node a script or tutorial reaches after a move is
  a unique name (`unique_name_in_owner = true`) and is found with `%Name`.
- **No `theme_override_*`.** Layout constants (`margin_*`, `separation`)
  are the accepted exception.
- **No new runtime visual construction.** The `tests/test_viewport_editability.gd`
  BASELINE is frozen: `loby.gd` 8, `student_card.gd` 1, `student_list.gd` 7,
  `rakbarang_1.gd` 1.
- **Script documentation.** Every script opens with a `##` block, and every
  `@export` has a `##` line.
- **Test suites.** Every suite is `@tool`, no test is a coroutine, and
  every suite overrides `suite_name()`. Without the override a suite
  registers as `unnamed`.
- **Editor-only scene edits.** `.tscn` files are edited only through the
  editor: `scene_open` → `batch_execute` / `node_*` → `scene_save`. Never by
  hand while the editor is attached.
  - Within a task, do scene work first and script work second.
  - After every `scene_save`, run `git diff HEAD --stat -- '*.gd'`. Only
    files this task already edited may appear.
  - After any `script_patch`, restart the editor (Procedure E) before the
    next `scene_save`.
- **Script edits.**
  - Edit existing `.gd` files with `script_patch`. It matches bytes exactly,
    and the files are LF.
  - Create new `.gd` files with the Write tool, then run
    `filesystem_manage(op="scan")`.
  - A `.gd` file rewritten wholesale with the Write tool gets a no-op
    `script_patch` afterwards, to refresh the editor's copy.
- **Never stage:**
  - `project.godot` (the user's uncommitted `window_*_override` lines);
  - `Assets/Audio/default_bus_layout.tres`;
  - `addons/godot_ai/utils/update_activation_runner.gd` and its `.uid`.

  Stage files by name. Never use `git add -A` or `git add .`.
- **Scene saves.** Never save `Scenes/StudentList/RosterCard.tscn`: its
  `@tool` StickyNotes bake a 20 px drop on save. Never open
  `Scenes/SchoolSimulation/BookClockWidget.tscn`: it hangs the editor.
- **Commits.**
  - Use Conventional Commits with a scope.
  - Pass the message with `git commit -F <file>`, never `-m`, because
    PowerShell 5.1 splits here-strings at quotes.
  - Every message ends with the line
    `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
  - Before every commit, run `git branch --show-current`. It must print
    `fix/tall-phone-layout`.
- **Balance.** `Scripts/Balance.gd` is not touched.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `tests/layout_frame.gd` | create | Test helper: stands a screen up at a given size in the editor's tree and settles its Containers in the same frame |
| `tests/test_tall_screen_layout.gd` | create | The four rules, per screen, plus 1080×2400 and 1080×1920 rect checks |
| `Scripts/UI/SafeAreaMargin.gd` | modify | Clamp warning only on a device |
| `tests/test_ui_components.gd` | modify | Pins that gate |
| `Scenes/Lobby/loby.tscn` | modify | `Backdrop` + `Classroom` + `Safe/UI/BottomBar`; popup centred |
| `Scripts/Lobby/loby.gd` | modify | `%` lookups; blur inserted at `DailyReward`'s index; tutorial finds `%` targets |
| `tests/test_lobby.gd`, `tests/test_lobby_layout.gd`, `tests/test_shorten.gd` | modify | Follow the moved nodes |
| `Scenes/Koperasi/koprasi.tscn`, `Scripts/Koperasi/koprasi.gd` | modify | Room fills; shelf view pinned bottom; coins in the safe area |
| `Scenes/StudentCard/student_card.tscn`, `Scripts/StudentCard/student_card.gd` | modify | Root inset removed; papers centred; page row pinned bottom |
| `tests/test_student_card.gd`, `tests/test_student_card_layout.gd` | modify | Follow the moved nodes; settle before reading rects |
| `Scenes/StudentList/student_list.tscn`, `Scripts/StudentList/student_list.gd` | modify | Cards centred; header and strip pinned top; nav row pinned bottom |
| `tests/test_student_list.gd` | modify | Follow the moved nodes |
| `CLAUDE.md`, `docs/superpowers/design/authoring-guide.md`, `docs/superpowers/CHANGELOG.md`, `docs/superpowers/DEBT.md` | modify | The rule, the how-to, the record |

## Procedures

These are used by several tasks. Each task names the procedure and gives
its parameters.

### Procedure E — restart the editor

1. Call `session_manage(op="list")`. Note `editor_pid`. If `count` is not 1,
   stop: another session shares the editor.
2. Run in PowerShell, putting the noted pid in `$editorPid`:

```powershell
$editorPid = 0  # set to editor_pid from step 1
$p = Get-Process -Id $editorPid
if ($p.MainWindowTitle.Contains('(*)')) { throw "unsaved scene: $($p.MainWindowTitle)" }
Stop-Process -Id $editorPid -Confirm:$false
$null = $p.WaitForExit(15000)
$exe = "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
$project = (Get-Location).Path
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$project`" -e"; CurrentDirectory = $project }
"ReturnValue=$($r.ReturnValue) ProcessId=$($r.ProcessId)"
```

3. Poll `session_manage(op="list")` until it reports one session with
   `readiness: "ready"` (about 20 s).
4. If a cold start then logs `Could not parse global class "StatBar"`, run
   `filesystem_manage(op="scan")`. It is a stale class table, not this
   work.

### Procedure R — render check

Parameters: `SCENE`, `TAG`, `PHASE` (`"before"` or `"after"`), and `PREP`
(a method to call on the screen after it settles, or `""`).

1. `project_run(mode="main", autosave=false)`.
2. `editor_manage(op="game_eval", params={"code": <the code below, with the four parameters filled in>})`.
3. `project_manage(op="stop")`.
4. Read the returned numbers, and look at
   `C:/Users/user/AppData/Local/Temp/kejartes-tall-phone/<TAG>_<PHASE>_2400.png`
   with the Read tool.
   - `bare_2400` counts sampled pixels of Godot's bare clear colour.
     After a fix it must be 0.
   - `changed_1920` is the share of sampled pixels that moved against the
     baseline. It must be under 0.02, or under 0.10 for the Lobby, whose
     background changes on purpose.

```gdscript
var SCENE := "res://Scenes/Lobby/loby.tscn"
var TAG := "lobby"
var PHASE := "before"
var PREP := ""
var DIR := "C:/Users/user/AppData/Local/Temp/kejartes-tall-phone/"
var tree := Engine.get_main_loop() as SceneTree
DirAccess.make_dir_recursive_absolute(DIR)
tree.root.get_node("DebugManager")._seed_playtest_state()
var out := {}
for h in [1920, 2400]:
	var sv := SubViewport.new()
	sv.size = Vector2i(1080, h)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(sv)
	var inst := (load(SCENE) as PackedScene).instantiate()
	sv.add_child(inst)
	await tree.create_timer(1.5, true, false, true).timeout
	if PREP != "":
		inst.call(PREP)
		await tree.create_timer(1.0, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(DIR + "%s_%s_%d.png" % [TAG, PHASE, h])
	var bare := 0
	for y in range(0, h, 4):
		for x in range(0, 1080, 4):
			var c := img.get_pixel(x, y)
			if c.r8 == c.g8 and c.g8 == c.b8 and absi(c.r8 - 76) <= 1:
				bare += 1
	out["bare_%d" % h] = bare
	var base_path := DIR + "%s_before_1920.png" % TAG
	if PHASE == "after" and h == 1920 and FileAccess.file_exists(base_path):
		var base := Image.load_from_file(base_path)
		base.convert(Image.FORMAT_RGBA8)
		var changed := 0
		var total := 0
		for y in range(0, 1920, 4):
			for x in range(0, 1080, 4):
				var a := img.get_pixel(x, y)
				var b := base.get_pixel(x, y)
				total += 1
				if absf(a.r - b.r) > 0.0625 or absf(a.g - b.g) > 0.0625 or absf(a.b - b.b) > 0.0625:
					changed += 1
		out["changed_1920"] = float(changed) / float(total)
	sv.queue_free()
	await tree.process_frame
return out
```

### Procedure S — run suites

- Run `test_run(suite="<name>")` for each named suite, one call at a time.
- Before judging a failure, check the reply's `scene_warning`. If it names
  the main scene, call
  `scene_open(path="res://Scenes/MainMenu/main_menu.tscn")` and re-run.
- Never run the full suite except in Task 7. It drops the bridge.

---

### Task 1: SafeAreaMargin warns only on a device

`SafeAreaMargin` logs a clamp warning in every editor and desktop run,
because the monitor's safe area always exceeds the window. Phase 1 puts one
on four more screens, so the warning becomes noise.

**Files:**
- Modify: `Scripts/UI/SafeAreaMargin.gd:70-73`
- Test: `tests/test_ui_components.gd` (after line 81)

**Interfaces:** Consumes nothing. Produces nothing later tasks call.

- [ ] **Step 1: Write the failing test.** Use `script_patch` on
  `res://tests/test_ui_components.gd`.

  old_text:
```gdscript
	assert_eq(m.get_theme_constant("margin_left"), tokens.screen_margin,
		"with safe area off, margin is exactly screen_margin")
```
  new_text:
```gdscript
	assert_eq(m.get_theme_constant("margin_left"), tokens.screen_margin,
		"with safe area off, margin is exactly screen_margin")


## The clamp warning is for devices only. In an editor or desktop run the
## monitor's safe area always exceeds the window, so it fired once for every
## SafeAreaMargin on screen -- noise once every screen has one (tall-phone
## layout spec, 2026-09-15).
func test_safe_area_clamp_warning_is_device_only() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/SafeAreaMargin.gd")
	assert_true(src.contains('if clamped != inset and OS.has_feature("mobile"):'),
		"the clamp warning must be gated to mobile devices")
```

- [ ] **Step 2: Run it and watch it fail.** Procedure S, suite
  `ui_components`. Expected: `test_safe_area_clamp_warning_is_device_only`
  FAILS with "the clamp warning must be gated to mobile devices". Every
  other test passes.

- [ ] **Step 3: Gate the warning.** Use `script_patch` on
  `res://Scripts/UI/SafeAreaMargin.gd`.

  old_text:
```gdscript
		# warn whenever the raw value actually needed correcting.
		if clamped != inset:
```
  new_text:
```gdscript
		# warn whenever the raw value actually needed correcting. Devices
		# only: in an editor or desktop run the monitor's safe area always
		# exceeds the window, so the warning fired for every SafeAreaMargin.
		if clamped != inset and OS.has_feature("mobile"):
```

- [ ] **Step 4: Run it and watch it pass.** Procedure S, suites
  `ui_components`, `boot_screens` and `script_documentation`. Expected: all
  PASS.

- [ ] **Step 5: Commit.** Write this message to
  `C:\Users\user\AppData\Local\Temp\kejartes-msg.txt`:
```
fix(ui): SafeAreaMargin warns about a clamped inset only on a device

In an editor or desktop run the monitor's safe area always exceeds the
window, so the warning fired for every SafeAreaMargin. The tall-phone pass
puts one on four more screens.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```
  Then run:
```bash
git branch --show-current
git add Scripts/UI/SafeAreaMargin.gd tests/test_ui_components.gd
git commit -F C:/Users/user/AppData/Local/Temp/kejartes-msg.txt
```

- [ ] **Step 6: Restart the editor.** Procedure E. The next task saves a
  scene, and this task patched a script.

---

### Task 2: Confirm the desktop tall-phone preview (no commit)

The spec asks whether a 360×800 window override shows a 9:20 embedded run
on the desktop. The result goes into the authoring guide in Task 7.

**Files:** none are committed. `project.godot` changes temporarily and is
restored.

**Interfaces:** Produces one recorded fact for Task 7, "desktop preview:
works" or "desktop preview: does not work". If it works, Tasks 3–6 may also
take a `editor_screenshot(source="game", max_resolution=0)` at 9:20.

- [ ] **Step 1: Snapshot the user's diff.**
```powershell
git diff -- project.godot | Out-File -Encoding utf8 C:\Users\user\AppData\Local\Temp\kejartes-projgodot-before.diff
Get-Content C:\Users\user\AppData\Local\Temp\kejartes-projgodot-before.diff
```
  Expected: exactly two added lines,
  `window/size/window_width_override=360` and
  `window/size/window_height_override=640`.

- [ ] **Step 2: Set a 9:20 override.**
  `project_manage(op="settings_set", params={"key": "display/window/size/window_height_override", "value": 800})`.

- [ ] **Step 3: Run the game and measure.** Call
  `project_run(mode="main", autosave=false)`, then
  `editor_manage(op="game_eval", params={"code": "var t := Engine.get_main_loop() as SceneTree\nreturn {\"window\": str(DisplayServer.window_get_size()), \"visible\": str(t.root.get_visible_rect().size)}"})`.
  - It works if `window` is `(360, 800)` and `visible` is `(1080.0, 2400.0)`.
  - It does not work if it still says `(360, 640)`.

- [ ] **Step 4: Stop and restore.** Call `project_manage(op="stop")`, then
  `project_manage(op="settings_set", params={"key": "display/window/size/window_height_override", "value": 640})`.

- [ ] **Step 5: Prove the restore.**
```powershell
git diff -- project.godot | Out-File -Encoding utf8 C:\Users\user\AppData\Local\Temp\kejartes-projgodot-after.diff
Compare-Object (Get-Content C:\Users\user\AppData\Local\Temp\kejartes-projgodot-before.diff) (Get-Content C:\Users\user\AppData\Local\Temp\kejartes-projgodot-after.diff)
```
  Expected: no output. If there is any, set the override back with
  `settings_set` until there is none.

- [ ] **Step 6: Record the result.** Write "desktop preview: works" or
  "desktop preview: does not work" in the session notes, for Task 7.

---

### Task 3: Lobby — the classroom is one centred piece, the HUD pins to the edges

**Files:**
- Create: `tests/layout_frame.gd`, `tests/test_tall_screen_layout.gd`
- Modify: `Scenes/Lobby/loby.tscn` (editor only), `Scripts/Lobby/loby.gd:55-83, 130, 614-624, 871`
- Modify: `tests/test_lobby.gd`, `tests/test_lobby_layout.gd` (rewrite), `tests/test_shorten.gd:164-192`

**Interfaces:**
- `tests/layout_frame.gd` produces
  `static func stand_up(scene_path: String, screen: Vector2) -> Control`,
  which returns a frame; the screen is `frame.get_child(0)`. It also
  produces `static func settle(node: Node) -> void`. Tasks 5 and 6 use both.
- `tests/test_tall_screen_layout.gd` produces these helpers, which Tasks 4–6
  append tests against:
  - `_scene(path) -> Control` (out of tree, tracked)
  - `_stood_up(path, screen) -> Control`
  - `_anchors(c) -> Vector4` and `_offsets(c) -> Vector4`
  - `_assert_background_fills(tex, label)`
  - `_assert_under_safe_area(node, label)`
  - `_assert_rect(got, want, label)`
  - the constants `TALL` (1080×2400) and `DESIGN` (1080×1920)
- The Lobby's new node paths:
  - `Backdrop` and `Classroom`
  - `Classroom/{BGLayer, Meja_*, StudentPortraitsContainer_*, StudentHandsContainer_*}`
  - `Safe/UI/JUDUL` and `Safe/UI/BottomBar/{Student, Koperasi, ReportStudent, Inventory, Jadwal, DisplayUang, ShortenButton, DailyLogin}`
  - `DailyReward` and `ColorRect` stay at the root.
  - Unique names: `%BGLayer`, the four containers, `%JUDUL`, and the eight
    bar nodes.

**The Lobby geometry** (design px on 1080×1920, after the root's −3 px
offset is removed):

| Node | Global rect now | New parent | Anchors (L,T,R,B) | New offsets (L,T,R,B) |
|---|---|---|---|---|
| Classroom (new) | — | root | 0.5,0.5,0.5,0.5 | −540,−960,540,960 |
| JUDUL | 381,40–704,140 | Safe/UI | 0.5,0,0.5,0 | −159,−8,164,92 |
| BottomBar (new) | 48,1392–1032,1872 | Safe/UI | 0,1,1,1 | 0,−480,0,0 |
| Student / Jadwal | 48,1520–1032,1680 | BottomBar | 0,0,0,0 | 0,128,984,288 |
| Koperasi | 48,1712–354,1872 | BottomBar | 0,0,0,0 | 0,320,306,480 |
| Inventory | 386,1712–692,1872 | BottomBar | 0,0,0,0 | 338,320,644,480 |
| ReportStudent | 724,1712–1030,1872 | BottomBar | 0,0,0,0 | 676,320,982,480 |
| DisplayUang | 700,1392–1032,1488 | BottomBar | 0,0,0,0 | 652,0,984,96 |
| ShortenButton | 168,1392–408,1488 | BottomBar | 0,0,0,0 | 120,0,360,96 |
| DailyLogin | 48,1392–144,1488 | BottomBar | 0,0,0,0 | 0,0,96,96 |
| DailyReward | 80,558–1022,976 | root | 0.5,0.5,0.5,0.5 | −460,−402,482,16 |

- [ ] **Step 1: Capture the baseline.** Procedure R with
  `SCENE = "res://Scenes/Lobby/loby.tscn"`, `TAG = "lobby"`,
  `PHASE = "before"` and `PREP = ""`. Expected: `bare_2400` > 0. That is
  the gray bars you are fixing.

- [ ] **Step 2: Create the layout helper.** Write
  `tests/layout_frame.gd`:

```gdscript
@tool
extends RefCounted

## Test helper, not a suite: stands a screen up at a given screen size inside
## the editor's tree and settles it in the same frame, so a test can read its
## real rects without awaiting (the MCP runner never awaits a test).
##
## A Container sorts its children one frame late; anchored children follow
## their parent at once. Verified 2026-09-15 with a throwaway probe: after
## Container.NOTIFICATION_SORT_CHILDREN was sent by hand, a Button two levels
## under a 48 px MarginContainer sat at its final rect in the same frame.
##
## Screen scripts that are not @tool (loby.gd, koprasi.gd, student_card.gd,
## student_list.gd) do not run their _ready here, so no screen side effects
## fire. Used by test_tall_screen_layout.gd, test_lobby_layout.gd and
## test_student_card_layout.gd.

const THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


## Instances `scene_path` under a frame of `screen` size in the editor's root,
## with the baked theme, and settles its Containers. Returns the frame: the
## caller passes it to track() so the runner frees it, and reads the screen
## as frame.get_child(0).
static func stand_up(scene_path: String, screen: Vector2) -> Control:
	var frame := Control.new()
	frame.size = screen
	frame.theme = load(THEME_PATH)
	var root := (load(scene_path) as PackedScene).instantiate() as Control
	frame.add_child(root)
	Engine.get_main_loop().root.add_child(frame)
	settle(root)
	return frame


## Sends every Container under `node` its sort notification, parents first,
## so each child's rect is final now instead of next frame.
static func settle(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		settle(child)
```

- [ ] **Step 3: Create the suite with its helpers and the Lobby tests.**
  Write `tests/test_tall_screen_layout.gd`:

```gdscript
@tool
extends McpTestSuite

## Tall-phone layout (spec: docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md).
##
## A 20:9 phone gives the game a 1080x2400 viewport, not 1080x1920. Every
## screen must fill it by four rules: (1) backgrounds are Full Rect and Keep
## Aspect Covered; (2) UI is anchored to the edge it belongs to; (3) that UI
## sits in a SafeAreaMargin; (4) a picture and the items drawn on it move as
## one fixed-size piece. Each screen gets two kinds of test: the contract
## (anchors and stretch modes read from the saved scene, out of the tree) and
## the behaviour (the screen stood up at 1080x2400 and at 1080x1920 through
## tests/layout_frame.gd, with real global rects checked).
##
## Must be @tool, and no test here may be a coroutine.

const LayoutFrame := preload("res://tests/layout_frame.gd")

const TALL := Vector2(1080, 2400)
const DESIGN := Vector2(1080, 1920)

const LOBBY := "res://Scenes/Lobby/loby.tscn"


func suite_name() -> String:
	return "tall_screen_layout"


## `path` instanced out of the tree (no _ready runs), freed after the test.
func _scene(path: String) -> Control:
	var root := (load(path) as PackedScene).instantiate() as Control
	track(root)
	return root


## `path` stood up at `screen` size and settled; returns the screen's root.
func _stood_up(path: String, screen: Vector2) -> Control:
	var frame := track(LayoutFrame.stand_up(path, screen)) as Control
	return frame.get_child(0) as Control


## The four anchors as (left, top, right, bottom).
func _anchors(c: Control) -> Vector4:
	return Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom)


## The four offsets as (left, top, right, bottom).
func _offsets(c: Control) -> Vector4:
	return Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)


## Rule 1: fills its parent and covers without distortion.
func _assert_background_fills(tex: TextureRect, label: String) -> void:
	assert_true(tex != null, label + " is missing")
	if tex == null:
		return
	assert_eq(_anchors(tex), Vector4(0, 0, 1, 1), label + " must be Full Rect")
	assert_eq(_offsets(tex), Vector4.ZERO, label + " must not be inset")
	assert_eq(tex.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
		label + " must ignore its texture's size")
	assert_eq(tex.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		label + " must cover, not fit or stretch")


## Rule 3: `node` sits somewhere under a SafeAreaMargin.
func _assert_under_safe_area(node: Node, label: String) -> void:
	assert_true(node != null, label + " is missing")
	if node == null:
		return
	var p := node.get_parent()
	while p != null and not (p is SafeAreaMargin):
		p = p.get_parent()
	assert_true(p != null, label + " must sit under a SafeAreaMargin")


## `got` equals `want` to within half a pixel on both corners.
func _assert_rect(got: Rect2, want: Rect2, label: String) -> void:
	var close := got.position.distance_to(want.position) < 0.5 \
		and got.end.distance_to(want.end) < 0.5
	assert_true(close, "%s sits at %s, expected %s" % [label, str(got), str(want)])


# ── Lobby ────────────────────────────────────────────────────────────────────

## The classroom -- background, four desk layers, seats and hands -- is one
## 1080x1920 piece held at the centre, so the students always sit at their
## desks. The root carries no stray inset.
func test_lobby_classroom_is_one_centred_piece() -> void:
	var lobby := _scene(LOBBY)
	assert_eq(_offsets(lobby), Vector4.ZERO, "the Lobby root is not inset")
	var room := lobby.get_node_or_null("Classroom") as Control
	assert_true(room != null, "the Lobby needs a Classroom node")
	if room == null:
		return
	assert_eq(_anchors(room), Vector4(0.5, 0.5, 0.5, 0.5), "Classroom is Center-anchored")
	assert_eq(_offsets(room), Vector4(-540, -960, 540, 960), "Classroom stays 1080x1920")
	assert_eq(room.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Classroom is art: no clicks")
	for n in ["BGLayer", "Meja_KiriAtas", "Meja_KananAtas",
			"StudentPortraitsContainer_Back", "StudentHandsContainer_Back",
			"Meja_KiriBawah", "Meja_KananBawah",
			"StudentPortraitsContainer_Front", "StudentHandsContainer_Front"]:
		assert_true(room.get_node_or_null(n) != null, n + " moves with the Classroom")
	_assert_background_fills(room.get_node_or_null("BGLayer") as TextureRect,
		"Classroom/BGLayer")


## A black Full Rect behind the classroom fills the bands a tall phone adds.
func test_lobby_backdrop_is_black_and_full_rect() -> void:
	var back := _scene(LOBBY).get_node_or_null("Backdrop") as ColorRect
	assert_true(back != null, "the Lobby needs a Backdrop ColorRect")
	if back == null:
		return
	assert_eq(back.get_index(), 0, "Backdrop draws first, behind the Classroom")
	assert_eq(_anchors(back), Vector4(0, 0, 1, 1), "Backdrop is Full Rect")
	assert_eq(back.color, Color.BLACK, "the bands are black")
	assert_eq(back.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Backdrop takes no clicks")


## The HUD sits in Safe/UI: the title on the top edge, the button block in a
## Bottom Wide bar. Every HUD node is a unique name, so loby.gd and the
## tutorial find it wherever it sits.
func test_lobby_hud_is_pinned_inside_the_safe_area() -> void:
	var lobby := _scene(LOBBY)
	var safe := lobby.get_node_or_null("Safe")
	assert_true(safe is SafeAreaMargin, "the Lobby HUD needs a SafeAreaMargin named Safe")
	if not safe is SafeAreaMargin:
		return
	assert_eq(_anchors(safe as Control), Vector4(0, 0, 1, 1), "Safe is Full Rect")
	assert_eq((safe as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Safe lets clicks through")
	var ui := lobby.get_node_or_null("Safe/UI") as Control
	assert_true(ui != null and ui.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Safe/UI exists and lets clicks through")
	_assert_under_safe_area(lobby.get_node_or_null("%JUDUL"), "JUDUL")
	var bar := lobby.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "the Lobby needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets clicks through")
	for n in ["Student", "Jadwal", "Koperasi", "Inventory", "ReportStudent",
			"DisplayUang", "ShortenButton", "DailyLogin"]:
		var c := lobby.get_node_or_null("%" + n) as Control
		assert_true(c != null, n + " must be a unique name")
		if c != null:
			assert_eq(c.get_parent(), bar, n + " rides in BottomBar")


## On a 1080x2400 phone the classroom sits 240 px down, centred; the HUD rides
## the bottom edge 48 px up; the title stays on top; the popup stays centred.
func test_lobby_on_a_tall_phone() -> void:
	var lobby := _stood_up(LOBBY, TALL)
	_assert_rect((lobby.get_node("Backdrop") as Control).get_global_rect(),
		Rect2(0, 0, 1080, 2400), "Backdrop")
	_assert_rect((lobby.get_node("Classroom") as Control).get_global_rect(),
		Rect2(0, 240, 1080, 1920), "Classroom")
	_assert_rect((lobby.get_node("%Jadwal") as Control).get_global_rect(),
		Rect2(48, 2000, 984, 160), "Jadwal")
	_assert_rect((lobby.get_node("%ReportStudent") as Control).get_global_rect(),
		Rect2(724, 2192, 306, 160), "ReportStudent")
	_assert_rect((lobby.get_node("%DailyLogin") as Control).get_global_rect(),
		Rect2(48, 1872, 96, 96), "DailyLogin")
	_assert_rect((lobby.get_node("%JUDUL") as Control).get_global_rect(),
		Rect2(381, 40, 323, 100), "JUDUL")
	_assert_rect((lobby.get_node("DailyReward") as Control).get_global_rect(),
		Rect2(80, 798, 942, 418), "DailyReward")


## At 1080x1920 the classroom fills the screen and the popup is where it was.
## (The HUD's design rects are pinned in test_lobby_layout.gd.)
func test_lobby_at_the_design_size_is_unchanged() -> void:
	var lobby := _stood_up(LOBBY, DESIGN)
	_assert_rect((lobby.get_node("Classroom") as Control).get_global_rect(),
		Rect2(0, 0, 1080, 1920), "Classroom")
	_assert_rect((lobby.get_node("DailyReward") as Control).get_global_rect(),
		Rect2(80, 558, 942, 418), "DailyReward")
```

- [ ] **Step 4: Rewrite `tests/test_lobby_layout.gd`.**
  1. Write the file below with the Write tool.
  2. Run `filesystem_manage(op="scan")`.
  3. Run a no-op `script_patch` on it (old_text = new_text =
     `	return "lobby_layout"`) so the editor's copy matches disk.

  The rim, row and face checks survive; they read real global rects now,
  because the HUD's offsets are no longer screen coordinates.

```gdscript
@tool
extends McpTestSuite

## Geometry guards for the lobby, from the 2026-09-08 warm-UI pass.
##
## Three defects motivated these, all measured rather than eyeballed:
## ReportStudent ended at x=1059 on a 1080-wide screen with a 6px border
## and a 14px shadow, so it clipped; DisplayUang spanned to x=1120, i.e.
## 40px off-screen entirely; and DisplayUang and DailyLogin sat centred
## on the two front-row students' heads (x~845 y~389 and x~225 y~389).
##
## Since the 2026-09-15 tall-phone pass the HUD lives in Safe/UI/BottomBar
## and the art in a centred Classroom, so a node's offsets are no longer
## screen coordinates. The Lobby is stood up on the 1080x1920 design screen
## (tests/layout_frame.gd) and every check reads real global rects.
##
## The Meja_* desk layers' 8-10 px nudges inside the Classroom are deliberate
## (2026-09-10): at zero offset the desks stopped short of the students'
## bodies and left a seam. Do not "correct" them.

const LayoutFrame := preload("res://tests/layout_frame.gd")

const SCREEN_W := 1080.0
const SCREEN_H := 1920.0
const RIM_CLEARANCE := 24.0

const SCENE := "res://Scenes/Lobby/loby.tscn"

const NAV_TILES := ["Koperasi", "Inventory", "ReportStudent"]

## Where every HUD control sits on the 1080x1920 design screen. The
## tall-phone pass re-anchored them without moving them: these are the rects
## they had before it, less the root's stray 3 px left offset it removed.
const DESIGN_RECTS := {
	"Student": Rect2(48, 1520, 984, 160),
	"Jadwal": Rect2(48, 1520, 984, 160),
	"Koperasi": Rect2(48, 1712, 306, 160),
	"Inventory": Rect2(386, 1712, 306, 160),
	"ReportStudent": Rect2(724, 1712, 306, 160),
	"DisplayUang": Rect2(700, 1392, 332, 96),
	"ShortenButton": Rect2(168, 1392, 240, 96),
	"DailyLogin": Rect2(48, 1392, 96, 96),
	"JUDUL": Rect2(381, 40, 323, 100),
}

var _lobby: Control


func suite_name() -> String:
	return "lobby_layout"


func setup() -> void:
	var frame := track(LayoutFrame.stand_up(SCENE, Vector2(SCREEN_W, SCREEN_H))) as Control
	_lobby = frame.get_child(0) as Control


## The HUD control named `n` (a unique name), or null after a recorded failure.
func _hud(n: String) -> Control:
	var c := _lobby.get_node_or_null("%" + n) as Control
	assert_true(c != null, "lobby is missing HUD node %" + n)
	return c


func test_the_hud_keeps_its_design_rects() -> void:
	for n in DESIGN_RECTS:
		var c := _hud(n)
		if c == null:
			continue
		var got := c.get_global_rect()
		var want: Rect2 = DESIGN_RECTS[n]
		assert_true(got.position.distance_to(want.position) < 0.5
				and got.end.distance_to(want.end) < 0.5,
			"%s sits at %s on the design screen, expected %s" % [n, str(got), str(want)])


func test_nav_tiles_share_one_height_and_one_baseline() -> void:
	var first := _hud(NAV_TILES[0])
	if first == null:
		return
	for i in range(1, NAV_TILES.size()):
		var tile := _hud(NAV_TILES[i])
		if tile == null:
			continue
		assert_eq(tile.get_global_rect().size.y, first.get_global_rect().size.y,
			"%s height differs from %s -- the three tiles are one row"
				% [NAV_TILES[i], NAV_TILES[0]])
		assert_eq(tile.get_global_rect().position.y, first.get_global_rect().position.y,
			"%s top differs from %s -- they must share a baseline"
				% [NAV_TILES[i], NAV_TILES[0]])


func test_nothing_clips_the_screen_rim() -> void:
	var offenders := []
	for n in DESIGN_RECTS:
		var c := _hud(n)
		if c == null:
			continue
		var r := c.get_global_rect()
		if r.position.x < RIM_CLEARANCE or r.end.x > SCREEN_W - RIM_CLEARANCE:
			offenders.append("%s spans %f..%f" % [n, r.position.x, r.end.x])
	assert_eq(offenders.size(), 0,
		"lobby controls within %fpx of the rim:\n  " % RIM_CLEARANCE
			+ "\n  ".join(offenders))


func test_hud_does_not_sit_on_the_front_row_faces() -> void:
	# Front-row head centres, derived from the portrait art's opaque
	# bounds (Thea.png: art starts 10.8% down, centred 49.9% across)
	# mapped through Slot3 and Slot4's rects.
	var heads := [Vector2(225, 389), Vector2(845, 389)]
	var radius := 110.0
	for n in ["DisplayUang", "DailyLogin", "ShortenButton"]:
		var c := _hud(n)
		if c == null:
			continue
		var r := c.get_global_rect()
		for head in heads:
			var overlaps: bool = head.x + radius > r.position.x and head.x - radius < r.end.x \
				and head.y + radius > r.position.y and head.y - radius < r.end.y
			assert_true(not overlaps,
				"%s %s covers a student's head at %s" % [n, str(r), str(head)])
```

- [ ] **Step 5: Point `tests/test_lobby.gd` at the unique names.** Make
  nine `script_patch` calls on `res://tests/test_lobby.gd`, each old_text →
  new_text exactly as below. Leave `DailyReward/...` paths alone: that node
  stays at the root.

  1. `		assert_true(_lobby.get_node_or_null(name) != null, "missing nav button: " + name)`
     → `		assert_true(_lobby.get_node_or_null("%" + name) != null, "missing nav button: " + name)`
  2. `	assert_true(_lobby.get_node_or_null("JUDUL") != null, "missing JUDUL")`
     → `	assert_true(_lobby.get_node_or_null("%JUDUL") != null, "missing JUDUL")`
  3. `	assert_true(_lobby.get_node_or_null("DisplayUang/Label") != null, "missing money label")`
     → `	assert_true(_lobby.get_node_or_null("%DisplayUang/Label") != null, "missing money label")`
  4. The `paths` block in the touch-target test. old_text:
```gdscript
	var paths := _NAV_BUTTONS.duplicate()
	paths.append("DailyReward/ButtonClaim")
	paths.append("ShortenButton")
```
     new_text:
```gdscript
	var paths := []
	for n in _NAV_BUTTONS:
		paths.append("%" + n)
	paths.append("DailyReward/ButtonClaim")
	paths.append("%ShortenButton")
```
  5. `		var b := _lobby.get_node_or_null(name) as Button` → `		var b := _lobby.get_node_or_null("%" + name) as Button`
     with `replace_all: true`. It occurs twice.
  6. `	var judul := _lobby.get_node_or_null("JUDUL") as Label` → `	var judul := _lobby.get_node_or_null("%JUDUL") as Label`
  7. `	var money := _lobby.get_node_or_null("DisplayUang/Label") as Label` → `	var money := _lobby.get_node_or_null("%DisplayUang/Label") as Label`
  8. `	var chip := _lobby.get_node_or_null("DisplayUang") as Panel` → `	var chip := _lobby.get_node_or_null("%DisplayUang") as Panel`
  9. Two more lines:
     - `	var icon := _lobby.get_node_or_null("DisplayUang/CoinIcon") as TextureRect` → `	var icon := _lobby.get_node_or_null("%DisplayUang/CoinIcon") as TextureRect`
     - `	var btn := _lobby.get_node_or_null("DailyLogin") as TextureButton` → `	var btn := _lobby.get_node_or_null("%DailyLogin") as TextureButton`

- [ ] **Step 6: Update the two Lobby tests in `tests/test_shorten.gd`.**
  Make two `script_patch` calls.

  **Patch 1.** old_text is the whole function
  `test_the_shorten_button_sits_on_the_money_row` (lines 164-174):
```gdscript
func test_the_shorten_button_sits_on_the_money_row() -> void:
	var block := _node_block(FileAccess.get_file_as_string(_LOBBY_SCENE), "ShortenButton")
	assert_contains(block, 'type="Button" parent="."')
	assert_contains(block, 'theme_type_variation = &"SecondaryButton"')
	assert_contains(block, 'text = "Shorten"')
	assert_contains(block, "offset_top = 1392.0")
	assert_contains(block, "offset_bottom = 1488.0")
	var left := float(block.get_slice("offset_left = ", 1).get_slice("\n", 0))
	var right := float(block.get_slice("offset_right = ", 1).get_slice("\n", 0))
	assert_true(left > 144.0 and right < 700.0,
		"between the daily-login icon (..144) and the money chip (700..), got %f..%f" % [left, right])
```
  new_text:
```gdscript
## Since the 2026-09-15 tall-phone pass the money row rides in
## Safe/UI/BottomBar, so the button is checked against its row-mates there
## rather than by screen offsets.
func test_the_shorten_button_sits_on_the_money_row() -> void:
	var lobby := (load(_LOBBY_SCENE) as PackedScene).instantiate() as Control
	track(lobby)
	var btn := lobby.get_node_or_null("%ShortenButton") as Button
	var login := lobby.get_node_or_null("%DailyLogin") as Control
	var chip := lobby.get_node_or_null("%DisplayUang") as Control
	assert_true(btn != null and login != null and chip != null,
		"ShortenButton, DailyLogin and DisplayUang must be unique names")
	if btn == null or login == null or chip == null:
		return
	assert_eq(btn.theme_type_variation, &"SecondaryButton")
	assert_eq(btn.text, "Shorten")
	assert_eq(btn.get_parent(), chip.get_parent(), "it rides in the same bar as the money chip")
	assert_eq(btn.offset_top, chip.offset_top, "on the money row")
	assert_eq(btn.offset_bottom, chip.offset_bottom, "on the money row")
	assert_true(btn.offset_left > login.offset_right and btn.offset_right < chip.offset_left,
		"between the daily-login icon (..%f) and the money chip (%f..), got %f..%f"
			% [login.offset_right, chip.offset_left, btn.offset_left, btn.offset_right])
```

  **Patch 2.** old_text is lines 177-192:
```gdscript
## loby.gd's _create_blur_overlay() inserts the reward popup's blur at
## DailyLogin's child index, so only nodes BEFORE DailyLogin end up under it.
## Code review, 2026-09-14: ShortenButton first sat between DailyLogin and
## DailyReward, so it stayed sharp and tappable over the open reward popup;
## it now sits just before DailyLogin.
func test_the_popups_draw_over_the_shorten_button() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCENE)
	var btn := src.find('[node name="ShortenButton" ')
	assert_true(btn != -1, "ShortenButton exists")
	assert_true(btn < src.find('[node name="DailyLogin" '),
		"the reward popup's blur, inserted at DailyLogin's index, must cover it")
	assert_true(btn < src.find('[node name="DailyReward" '), "the reward popup covers it")
	assert_true(btn < src.find('[node name="ColorRect" '), "the tutorial overlay covers it")
	assert_contains(FileAccess.get_file_as_string(_LOBBY_SCRIPT),
		"move_child(blur_overlay, daily_login_btn.get_index())",
		"if the blur's insertion point moves, re-check which HUD nodes it covers")
```
  new_text:
```gdscript
## loby.gd's _create_blur_overlay() inserts the reward popup's blur at
## DailyReward's child index, so every node serialized before DailyReward --
## the Classroom and the whole Safe HUD, ShortenButton and DailyLogin
## included -- ends up under it. (Until the 2026-09-15 tall-phone pass the
## insertion point was DailyLogin's index, while the HUD nodes were direct
## children of the root; a 2026-09-14 review had found ShortenButton sharp
## and tappable over the open popup.)
func test_the_popups_draw_over_the_shorten_button() -> void:
	var src := FileAccess.get_file_as_string(_LOBBY_SCENE)
	var btn := src.find('[node name="ShortenButton" ')
	assert_true(btn != -1, "ShortenButton exists")
	assert_true(btn < src.find('[node name="DailyReward" '),
		"the reward popup's blur, inserted at DailyReward's index, must cover it")
	assert_true(btn < src.find('[node name="ColorRect" '), "the tutorial overlay covers it")
	assert_contains(FileAccess.get_file_as_string(_LOBBY_SCRIPT),
		"move_child(blur_overlay, daily_reward.get_index())",
		"if the blur's insertion point moves, re-check which HUD nodes it covers")
```

- [ ] **Step 7: Run the tests and watch them fail.** Run
  `filesystem_manage(op="scan")`, then Procedure S with the suites
  `tall_screen_layout`, `lobby_layout`, `lobby` and `shorten`. Expected
  failures:
  - `tall_screen_layout`: all six Lobby tests. Classroom, Backdrop and Safe
    are missing, and the root is inset by −3.
  - `lobby_layout`: all four tests, because `%` lookups find nothing.
  - `lobby`: every test that looks up a `%` name.
  - `shorten`: `test_the_shorten_button_sits_on_the_money_row`, and
    `test_the_popups_draw_over_the_shorten_button` on the script line.

  Nothing else in those suites may fail. If something does, stop and find
  out why before editing the scene.

- [ ] **Step 8: Build the Classroom.**
  1. `scene_open(path="res://Scenes/Lobby/loby.tscn")`. The root is
     `TutorialOverlay`, and every path below starts `/TutorialOverlay`.
  2. One `batch_execute` (`undo: true`). Each `sp` is
     `{"command":"set_property","params":{"path":P,"property":K,"value":V}}`.
     In order:
     - `sp /TutorialOverlay offset_left 0`
     - `create_node {"type":"ColorRect","name":"Backdrop","parent_path":"/TutorialOverlay"}`
     - on `/TutorialOverlay/Backdrop`: `sp layout_mode 1`, `sp anchor_right 1`,
       `sp anchor_bottom 1`, `sp offset_right 0`, `sp offset_bottom 0`,
       `sp grow_horizontal 2`, `sp grow_vertical 2`, `sp mouse_filter 2`,
       `sp color "#000000"`
     - `move_node {"path":"/TutorialOverlay/Backdrop","index":0}`
     - `create_node {"type":"Control","name":"Classroom","parent_path":"/TutorialOverlay"}`
     - on `/TutorialOverlay/Classroom`: `sp layout_mode 1`,
       `sp anchor_left 0.5`, `sp anchor_top 0.5`, `sp anchor_right 0.5`,
       `sp anchor_bottom 0.5`, `sp offset_left -540`, `sp offset_top -960`,
       `sp offset_right 540`, `sp offset_bottom 960`, `sp mouse_filter 2`
     - `move_node {"path":"/TutorialOverlay/Classroom","index":1}`
     - `reparent_node {"path":"/TutorialOverlay/<N>","new_parent":"/TutorialOverlay/Classroom"}`
       for each N in this order, which preserves draw order: `BGLayer`,
       `Meja_KiriAtas`, `Meja_KananAtas`, `StudentPortraitsContainer_Back`,
       `StudentHandsContainer_Back`, `Meja_KiriBawah`, `Meja_KananBawah`,
       `StudentPortraitsContainer_Front`, `StudentHandsContainer_Front`
     - `sp /TutorialOverlay/Classroom/BGLayer stretch_mode 6`
     - `sp unique_name_in_owner true` on `Classroom/BGLayer` and the four
       `Classroom/Student*Container_*` nodes

  Reparenting keeps local offsets. Those nodes are Full Rect, so they now
  fill the Classroom exactly as they filled the root. The Meja 8-10 px
  nudges ride along unchanged.

- [ ] **Step 9: Build Safe/UI/BottomBar and move the HUD.** One
  `batch_execute` (`undo: true`), in order:
  - `create_node {"type":"MarginContainer","name":"Safe","parent_path":"/TutorialOverlay"}`
  - on `/TutorialOverlay/Safe`:
    - `sp script "res://Scripts/UI/SafeAreaMargin.gd"`
    - `sp layout_mode 1`, `sp anchor_right 1`, `sp anchor_bottom 1`
    - `sp offset_right 0`, `sp offset_bottom 0`
    - `sp grow_horizontal 2`, `sp grow_vertical 2`, `sp mouse_filter 2`
  - `move_node {"path":"/TutorialOverlay/Safe","index":2}`
  - `create_node {"type":"Control","name":"UI","parent_path":"/TutorialOverlay/Safe"}`,
    then `sp /TutorialOverlay/Safe/UI mouse_filter 2`
  - `create_node {"type":"Control","name":"BottomBar","parent_path":"/TutorialOverlay/Safe/UI"}`
  - on `.../Safe/UI/BottomBar`:
    - `sp layout_mode 1`, `sp anchor_top 1`, `sp anchor_right 1`,
      `sp anchor_bottom 1`
    - `sp offset_left 0`, `sp offset_top -480`, `sp offset_right 0`,
      `sp offset_bottom 0`
    - `sp grow_horizontal 2`, `sp grow_vertical 0`, `sp mouse_filter 2`
  - `reparent_node {"path":"/TutorialOverlay/JUDUL","new_parent":"/TutorialOverlay/Safe/UI"}`
  - on `.../Safe/UI/JUDUL`:
    - `sp layout_mode 1`, `sp anchor_left 0.5`, `sp anchor_right 0.5`
    - `sp offset_left -159`, `sp offset_top -8`, `sp offset_right 164`,
      `sp offset_bottom 92`
    - `sp unique_name_in_owner true`
  - `reparent_node` each of these into `/TutorialOverlay/Safe/UI/BottomBar`,
    in this order: `Student`, `Koperasi`, `ReportStudent`, `Inventory`,
    `Jadwal`, `DisplayUang`, `ShortenButton`, `DailyLogin`
  - for each moved node, set `offset_left`, `offset_top`, `offset_right`
    and `offset_bottom` to the "New offsets" column of the geometry table
    above, then `sp unique_name_in_owner true`:
    - Student and Jadwal: 0, 128, 984, 288
    - Koperasi: 0, 320, 306, 480
    - Inventory: 338, 320, 644, 480
    - ReportStudent: 676, 320, 982, 480
    - DisplayUang: 652, 0, 984, 96
    - ShortenButton: 120, 0, 360, 96
    - DailyLogin: 0, 0, 96, 96

- [ ] **Step 10: Centre the reward popup.** One `batch_execute` on
  `/TutorialOverlay/DailyReward`:
  - `sp layout_mode 1`
  - `sp anchor_left 0.5`, `sp anchor_top 0.5`, `sp anchor_right 0.5`,
    `sp anchor_bottom 0.5`
  - `sp offset_left -460`, `sp offset_top -402`, `sp offset_right 482`,
    `sp offset_bottom 16`

- [ ] **Step 11: Check the tree, then save.**
  1. `scene_get_hierarchy(depth=4)`. The root's children must be exactly,
     in order: `Backdrop`, `Classroom`, `Safe`, `DailyReward`, `ColorRect`.
  2. `scene_save`.
  3. Run the checks:
```powershell
git diff HEAD --stat -- '*.gd'
(Select-String -Path Scenes/Lobby/loby.tscn -Pattern 'unique_name_in_owner = true').Count
```
  Expected:
  - The diff lists only `tests/test_lobby.gd`, `tests/test_lobby_layout.gd`
    and `tests/test_shorten.gd`.
  - The count is `14`.
  - If any other `.gd` changed, restore it with `git checkout -- <file>`.
    A stale tab wrote it back.

- [ ] **Step 12: Point `loby.gd` at the new tree.** Make five
  `script_patch` calls on `res://Scripts/Lobby/loby.gd`.

  **Patch 1.** old_text:
```gdscript
@onready var student_button = $Student
@onready var jadwal_button = $Jadwal
@onready var koperasi_button = $Koperasi
@onready var report_student_button = $ReportStudent
@onready var inventory_button = $Inventory
@onready var shorten_button = $ShortenButton

@onready var money_label = $DisplayUang/Label
@onready var daily_login_btn = $DailyLogin
```
  new_text:
```gdscript
# The HUD sits in Safe/UI/BottomBar and the diorama in Classroom since the
# 2026-09-15 tall-phone pass; unique names find them wherever they sit.
@onready var student_button = %Student
@onready var jadwal_button = %Jadwal
@onready var koperasi_button = %Koperasi
@onready var report_student_button = %ReportStudent
@onready var inventory_button = %Inventory
@onready var shorten_button = %ShortenButton

@onready var money_label = get_node("%DisplayUang/Label")
@onready var daily_login_btn = %DailyLogin
```

  **Patch 2.** old_text:
```gdscript
@onready var portraits_back: Control = $StudentPortraitsContainer_Back
@onready var portraits_front: Control = $StudentPortraitsContainer_Front

@onready var portrait_slots = [
	$StudentPortraitsContainer_Back/Slot1,
	$StudentPortraitsContainer_Back/Slot2,
	$StudentPortraitsContainer_Front/Slot3,
	$StudentPortraitsContainer_Front/Slot4,
]
@onready var hand_slots = [
	$StudentHandsContainer_Back/Slot1,
	$StudentHandsContainer_Back/Slot2,
	$StudentHandsContainer_Front/Slot3,
	$StudentHandsContainer_Front/Slot4,
]
```
  new_text:
```gdscript
@onready var portraits_back: Control = %StudentPortraitsContainer_Back
@onready var portraits_front: Control = %StudentPortraitsContainer_Front

@onready var portrait_slots = [
	get_node("%StudentPortraitsContainer_Back/Slot1"),
	get_node("%StudentPortraitsContainer_Back/Slot2"),
	get_node("%StudentPortraitsContainer_Front/Slot3"),
	get_node("%StudentPortraitsContainer_Front/Slot4"),
]
@onready var hand_slots = [
	get_node("%StudentHandsContainer_Back/Slot1"),
	get_node("%StudentHandsContainer_Back/Slot2"),
	get_node("%StudentHandsContainer_Front/Slot3"),
	get_node("%StudentHandsContainer_Front/Slot4"),
]
```

  **Patch 3.** `@onready var bg_layer = $BGLayer` →
  `@onready var bg_layer = %BGLayer`

  **Patch 4.** old_text:
```gdscript
	add_child(blur_overlay)
	# DailyReward is now a sibling of DailyLogin, not its child (Task 10
	# re-anchored it to the scene root). Place blur_overlay just before
	# DailyLogin, i.e. at DailyLogin's own index -- DailyReward sits right
	# after DailyLogin in child order (with the root's own ColorRect after
	# it), so inserting here still puts blur_overlay ahead of DailyReward --
	# so it renders on top of the rest of the lobby UI but behind the popup.
	# Any HUD node the popup must cover (ShortenButton, 2026-09-14) has to
	# sit BEFORE DailyLogin: one between DailyLogin and DailyReward stays
	# sharp and tappable over the open popup.
	move_child(blur_overlay, daily_login_btn.get_index())
```
  new_text:
```gdscript
	add_child(blur_overlay)
	# Place blur_overlay at DailyReward's index, just before it: it then
	# renders over the Classroom and the whole HUD (Safe and everything in
	# it, DailyLogin and ShortenButton included) but behind the popup. Since
	# the 2026-09-15 tall-phone pass the HUD sits in Safe/UI/BottomBar, so a
	# HUD node's own index says nothing about the root's draw order.
	move_child(blur_overlay, daily_reward.get_index())
```

  **Patch 5.** old_text (four tabs of indent):
```gdscript
				var target = get_node_or_null(trimmed)
```
  new_text:
```gdscript
				# A bare name ("Jadwal") is a HUD button, found by unique name
				# wherever it sits; anything else is a path from the root.
				var target = get_node_or_null("%" + trimmed)
				if target == null:
					target = get_node_or_null(trimmed)
```

- [ ] **Step 13: Run the tests and watch them pass.** Procedure S with the
  suites `tall_screen_layout`, `lobby_layout`, `lobby`, `shorten`,
  `face_rig_roster`, `confirm_pair_semantics`, `viewport_editability` and
  `script_documentation`. Expected: all PASS.

- [ ] **Step 14: Render the result.** Procedure R with `SCENE` = loby,
  `TAG = "lobby"`, `PHASE = "after"` and `PREP = ""`. Expected:
  - `bare_2400` is 0;
  - `changed_1920` is under 0.10;
  - in `lobby_after_2400.png`, all four students sit at their own desks,
    with black bands above and below, the title at the top, and the button
    block at the bottom edge.

- [ ] **Step 15: Restart the editor.** Procedure E. This task patched
  `loby.gd`.

- [ ] **Step 16: Commit.** Write the message file:
```
feat(lobby): the classroom stays one centred piece and the HUD pins to the edges

On a 20:9 phone the classroom slid down while the seats stayed put, so the
students sat at the wrong desks. The background, desks, seats and hands now
live in one Classroom node held at the centre, with black behind it; the
title and button block sit in Safe/UI and ride the top and bottom edges.
loby.gd finds the moved nodes by unique name, and the reward blur is
inserted at DailyReward's index.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```
  Then stage the files by name. A new script's `.uid` is staged only if
  Godot made one.
```powershell
git branch --show-current
git add Scenes/Lobby/loby.tscn Scripts/Lobby/loby.gd tests/layout_frame.gd tests/test_tall_screen_layout.gd tests/test_lobby.gd tests/test_lobby_layout.gd tests/test_shorten.gd
foreach ($f in @("tests/layout_frame.gd.uid", "tests/test_tall_screen_layout.gd.uid")) { if (Test-Path $f) { git add $f } }
git commit -F C:/Users/user/AppData/Local/Temp/kejartes-msg.txt
```

---

### Task 4: Koperasi — the room fills, the shelf view rides the bottom edge

The shop has two views on one scene:
- **Landing:** the room picture `TextureRect` (Illustration4.jpg, 1080×1920),
  with its child Button `TextureRect/Rak1` ("KEBUTUHAN SEKOLAH").
- **Shelf view:** `Rak1`, a TextureRect cropped from rak2.jpg, holding
  `Barang1-4`, `BackButton` and the `BasketTray` instance. It is hidden
  until `koprasi.gd._on_rak1_pressed()` fades it in over the room.

`CoinHUD` (z 10) and `MessageLabel` (z 20, already anchored at 0.47) stay on
top of both. No test pins any koprasi.tscn geometry.

**Files:**
- Modify: `Scenes/Koperasi/koprasi.tscn` (editor only), `Scripts/Koperasi/koprasi.gd:16-17`
- Test: `tests/test_tall_screen_layout.gd` (append)

**Interfaces:**
- Consumes Task 3's suite helpers: `_scene`, `_stood_up`, `_anchors`,
  `_offsets`, `_assert_background_fills`, `_assert_under_safe_area`,
  `_assert_rect`, `TALL`, `DESIGN`.
- Produces the new paths `Safe/UI/CoinHUD` (unique `%CoinHUD`) and
  `Safe/UI`. `TextureRect`, `TextureRect/Rak1`, `Rak1/*` and `MessageLabel`
  keep their paths.

**Geometry:**

| Node | Now | Anchors (L,T,R,B) | New offsets (L,T,R,B) | At 1080×2400 |
|---|---|---|---|---|
| TextureRect (room) | native 1080×1920 at 0,0 | 0,0,1,1 | 0,0,0,0 (+ `expand_mode 1`, `stretch_mode 6`) | 0,0–1080,2400 |
| TextureRect/Rak1 (sign) | 303,1401–745,1497 | 0,1,0,1 | 303,−519,745,−423 | 303,1881 |
| Rak1 (shelf view) | 0,117–1080,1828 | 0,1,0,1 | 0,−1803,1080,−92 | 0,597–1080,2308; tray body 24,1840–1056,2400 |
| CoinHUD → Safe/UI | 20,20 | 0,0,0,0 | −28,−28,−11,0 | 20,20 |

- [ ] **Step 1: Capture the baselines.** Procedure R twice with
  `SCENE = "res://Scenes/Koperasi/koprasi.tscn"` and `PHASE = "before"`:
  - `TAG = "koperasi_landing"`, `PREP = ""`;
  - `TAG = "koperasi_shelf"`, `PREP = "_on_rak1_pressed"`.

  Expected: `bare_2400` > 0 both times.

- [ ] **Step 2: Append the Koperasi tests.** `script_patch` on
  `res://tests/test_tall_screen_layout.gd`.

  old_text (the suite's last two lines, from Task 3):
```gdscript
	_assert_rect((lobby.get_node("DailyReward") as Control).get_global_rect(),
		Rect2(80, 558, 942, 418), "DailyReward")
```
  new_text:
```gdscript
	_assert_rect((lobby.get_node("DailyReward") as Control).get_global_rect(),
		Rect2(80, 558, 942, 418), "DailyReward")


# ── Koperasi ─────────────────────────────────────────────────────────────────

const KOPERASI := "res://Scenes/Koperasi/koprasi.tscn"


## The room picture behind both views fills the screen and covers.
func test_koperasi_room_fills() -> void:
	_assert_background_fills(_scene(KOPERASI).get_node_or_null("TextureRect") as TextureRect,
		"Koperasi room picture (TextureRect)")


## The shelf view -- shelf picture, items, back button and basket tray -- is
## one piece pinned to the bottom edge, so the tray still ends flush with it.
func test_koperasi_shelf_view_is_one_piece_pinned_bottom() -> void:
	var shelf := _scene(KOPERASI).get_node_or_null("Rak1") as Control
	assert_true(shelf != null, "missing the Rak1 shelf view")
	if shelf == null:
		return
	assert_eq(_anchors(shelf), Vector4(0, 1, 0, 1), "Rak1 pins to the bottom edge")
	assert_eq(_offsets(shelf), Vector4(0, -1803, 1080, -92), "Rak1 keeps its 1080x1711 rect")
	for n in ["BackButton", "Barang1", "Barang2", "Barang3", "Barang4", "BasketTray"]:
		assert_true(shelf.get_node_or_null(n) != null, n + " moves with the shelf")


## The landing's "KEBUTUHAN SEKOLAH" sign pins to the bottom edge, which keeps
## it on the counter's glass front from 9:16 to 9:21.
func test_koperasi_landing_sign_pins_bottom() -> void:
	# Not `sign`: that name shadows the built-in sign() and warns.
	var shelf_sign := _scene(KOPERASI).get_node_or_null("TextureRect/Rak1") as Control
	assert_true(shelf_sign != null, "missing the landing sign TextureRect/Rak1")
	if shelf_sign == null:
		return
	assert_eq(_anchors(shelf_sign), Vector4(0, 1, 0, 1), "the sign pins to the bottom edge")
	assert_eq(_offsets(shelf_sign), Vector4(303, -519, 745, -423), "and keeps its 1080x1920 rect")


## The coin readout sits in the safe area, top-left; Safe lets taps through
## to the shelf underneath.
func test_koperasi_coin_hud_sits_in_the_safe_area() -> void:
	var shop := _scene(KOPERASI)
	var hud := shop.get_node_or_null("%CoinHUD") as Control
	_assert_under_safe_area(hud, "CoinHUD")
	if hud == null:
		return
	assert_eq(_anchors(hud), Vector4.ZERO, "CoinHUD pins top-left")
	for p in ["Safe", "Safe/UI"]:
		var c := shop.get_node_or_null(p) as Control
		assert_true(c != null and c.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			p + " must let taps through to the shelf")


## On a 1080x2400 phone the tray reaches the bottom edge, the shelf rides it,
## and the coins stay at the top.
func test_koperasi_on_a_tall_phone() -> void:
	var shop := _stood_up(KOPERASI, TALL)
	_assert_rect((shop.get_node("TextureRect") as Control).get_global_rect(),
		Rect2(0, 0, 1080, 2400), "room picture")
	_assert_rect((shop.get_node("Rak1") as Control).get_global_rect(),
		Rect2(0, 597, 1080, 1711), "shelf view")
	_assert_rect((shop.get_node("Rak1/BasketTray/Body") as Control).get_global_rect(),
		Rect2(24, 1840, 1032, 560), "basket tray")
	assert_eq((shop.get_node("TextureRect/Rak1") as Control).get_global_rect().position,
		Vector2(303, 1881), "the sign stays on the counter")
	assert_eq((shop.get_node("%CoinHUD") as Control).get_global_rect().position,
		Vector2(20, 20), "the coins stay top-left")


## At 1080x1920 the Koperasi is where it was.
func test_koperasi_at_the_design_size_is_unchanged() -> void:
	var shop := _stood_up(KOPERASI, DESIGN)
	_assert_rect((shop.get_node("Rak1") as Control).get_global_rect(),
		Rect2(0, 117, 1080, 1711), "shelf view")
	assert_eq((shop.get_node("TextureRect/Rak1") as Control).get_global_rect().position,
		Vector2(303, 1401), "landing sign")
	assert_eq((shop.get_node("%CoinHUD") as Control).get_global_rect().position,
		Vector2(20, 20), "coins")
```

- [ ] **Step 3: Run the tests and watch them fail.** Procedure S, suite
  `tall_screen_layout`. Expected: the six Koperasi tests FAIL, and every
  Lobby test passes.

- [ ] **Step 4: Re-anchor the scene.**
  1. `scene_open(path="res://Scenes/Koperasi/koprasi.tscn")`. The root is
     `Koprasi`.
  2. One `batch_execute` (`undo: true`; `sp` as in Task 3), in order:
     - on `/Koprasi/TextureRect`:
       - `sp layout_mode 1`, `sp anchor_right 1`, `sp anchor_bottom 1`
       - `sp offset_right 0`, `sp offset_bottom 0`
       - `sp grow_horizontal 2`, `sp grow_vertical 2`
       - `sp expand_mode 1`, `sp stretch_mode 6`
     - on `/Koprasi/TextureRect/Rak1`: `sp layout_mode 1`,
       `sp anchor_top 1`, `sp anchor_bottom 1`, `sp offset_top -519`,
       `sp offset_bottom -423`
     - on `/Koprasi/Rak1`: `sp layout_mode 1`, `sp anchor_top 1`,
       `sp anchor_bottom 1`, `sp offset_top -1803`, `sp offset_bottom -92`
     - `create_node {"type":"MarginContainer","name":"Safe","parent_path":"/Koprasi"}`
     - on `/Koprasi/Safe`:
       - `sp script "res://Scripts/UI/SafeAreaMargin.gd"`
       - `sp layout_mode 1`, `sp anchor_right 1`, `sp anchor_bottom 1`
       - `sp offset_right 0`, `sp offset_bottom 0`
       - `sp grow_horizontal 2`, `sp grow_vertical 2`, `sp mouse_filter 2`
     - `move_node {"path":"/Koprasi/Safe","index":2}`
     - `create_node {"type":"Control","name":"UI","parent_path":"/Koprasi/Safe"}`,
       then `sp /Koprasi/Safe/UI mouse_filter 2`
     - `reparent_node {"path":"/Koprasi/CoinHUD","new_parent":"/Koprasi/Safe/UI"}`
     - on `/Koprasi/Safe/UI/CoinHUD`: `sp offset_left -28`,
       `sp offset_top -28`, `sp offset_right -11`, `sp offset_bottom 0`,
       `sp unique_name_in_owner true`

- [ ] **Step 5: Check the tree, then save.**
  1. `scene_get_hierarchy(depth=3)`. The root's children must be, in
     order: `TextureRect`, `Rak1`, `Safe`, `MessageLabel`.
  2. `scene_save`.
  3. `git diff HEAD --stat -- '*.gd'` must list only
     `tests/test_tall_screen_layout.gd`.

- [ ] **Step 6: Point `koprasi.gd` at the coins.** `script_patch` on
  `res://Scripts/Koperasi/koprasi.gd`.

  old_text:
```gdscript
@onready var coin_hud: HBoxContainer = $CoinHUD
@onready var coin_label: Label = $CoinHUD/CoinLabel
```
  new_text:
```gdscript
# CoinHUD sits in Safe/UI since the 2026-09-15 tall-phone pass.
@onready var coin_hud: HBoxContainer = %CoinHUD
@onready var coin_label: Label = get_node("%CoinHUD/CoinLabel")
```

- [ ] **Step 7: Run the tests and watch them pass.** Procedure S with the
  suites `tall_screen_layout`, `koperasi`, `koperasi_hud`,
  `koperasi_tray`, `basket_tray`, `shop_hub`, `lobby_style_buttons`,
  `viewport_editability` and `script_documentation`. Expected: all PASS.

- [ ] **Step 8: Render the result.** Procedure R twice with
  `PHASE = "after"`, using the Step 1 tags and PREPs. Expected, for both:
  - `bare_2400` is 0 and `changed_1920` is under 0.02;
  - on the shelf render, the tray sits on the bottom edge, with more wall
    and the clock above the shelves.

- [ ] **Step 9: Restart the editor.** Procedure E.

- [ ] **Step 10: Commit.** Write the message file:
```
feat(koperasi): the room fills and the shelf view rides the bottom edge

The room picture is Full Rect and covers; the shelf view (shelf, items,
back button and basket tray) moves as one piece pinned to the bottom, so
the tray reaches a tall phone's edge; the landing sign pins to the bottom
too, and the coin readout sits in a SafeAreaMargin.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```
  Then run:
```bash
git branch --show-current
git add Scenes/Koperasi/koprasi.tscn Scripts/Koperasi/koprasi.gd tests/test_tall_screen_layout.gd
git commit -F C:/Users/user/AppData/Local/Temp/kejartes-msg.txt
```

---

### Task 5: StudentCard — root inset removed, papers centred, page row pinned bottom

The root `StudentCard` is inset by 70/254/−77/−352, and every direct child
compensates in position mode. The task first zeroes that inset and gives
each child its plain screen rect, which is pixel-identical. It then
re-anchors by the rules.

- The six `KertasMurid*` sheets are full-screen paper art (card_bg.png,
  1080×1920) with the card content inside. They become one Center-anchored
  piece each, with `StampApprove` riding alongside.
- `BelajarButton` is placed at runtime from the active card's position
  (student_card.gd:811-826), so it follows the cards by itself. It only has
  its offsets shifted.
- `ColorRect` (the tutorial overlay) is moved onto a CanvasLayer at runtime
  and refitted to the viewport (gd:119-124, 382-391). Leave it untouched.

**Files:**
- Modify: `Scenes/StudentCard/student_card.tscn` (editor only), `Scripts/StudentCard/student_card.gd:76-79, 430`
- Modify: `tests/test_student_card.gd:107`, `tests/test_student_card_layout.gd:9, 530-531, 627-630`
- Test: `tests/test_tall_screen_layout.gd` (append)

**Interfaces:**
- Consumes `tests/layout_frame.gd` (`settle`) and the suite helpers from
  Task 3.
- Produces the new paths `Safe/UI/PilihMurid` and
  `Safe/UI/BottomBar/{NextButtonKiri, NextButtonKanan, PageLabel}`, all
  unique names.
- `KertasMurid1-6`, `Backdrop`, `StampApprove`, `BelajarButton` and
  `ColorRect` stay root children.

**Geometry.** "Screen rect" is the node's global rect today: root inset
plus child offsets.

| Node | Screen rect | Parent after | Anchors (L,T,R,B) | New offsets (L,T,R,B) |
|---|---|---|---|---|
| root StudentCard | 70,254–1003,1568 | — | 0,0,1,1 | 0,0,0,0 |
| Backdrop | 0,0–1080,1920 | root | 0,0,1,1 | 0,0,0,0 |
| KertasMurid1…6 | 0,0–1080,1920 | root | 0.5 ×4 | −540,−960,540,960 |
| StampApprove | 55,352–1054,1172 | root | 0.5 ×4 | −485,−608,514,212 |
| BelajarButton | (placed by script) | root | 0,0,0,0 | 398,1994,888,2154 |
| PilihMurid | 160,44–1060,194 | Safe/UI | 0.5,0,0.5,0 | −380,−4,520,146 |
| BottomBar (new) | 48,1778–1032,1906 | Safe/UI | 0,1,1,1 | 0,−94,0,34 |
| NextButtonKiri | 90,1778–250,1906 | BottomBar | 0,0,0,0 | 42,0,202,128 |
| NextButtonKanan | 860,1778–1020,1906 | BottomBar | 0,0,0,0 | 812,0,972,128 |
| PageLabel | 440,1805–640,1875 | BottomBar | 0,0,0,0 | 392,27,592,97 |

The arrows reach 14 px from the bottom edge today, 34 px below the 48 px
margin. The bar keeps that, following "re-anchor, don't move".

- [ ] **Step 1: Capture the baseline.** Procedure R with
  `SCENE = "res://Scenes/StudentCard/student_card.tscn"`,
  `TAG = "student_card"`, `PHASE = "before"` and `PREP = ""`.

- [ ] **Step 2: Append the StudentCard tests.** `script_patch` on
  `res://tests/test_tall_screen_layout.gd`.

  old_text (the suite's last two lines, from Task 4):
```gdscript
	assert_eq((shop.get_node("%CoinHUD") as Control).get_global_rect().position,
		Vector2(20, 20), "coins")
```
  new_text:
```gdscript
	assert_eq((shop.get_node("%CoinHUD") as Control).get_global_rect().position,
		Vector2(20, 20), "coins")


# ── StudentCard ──────────────────────────────────────────────────────────────

const STUDENT_CARD := "res://Scenes/StudentCard/student_card.tscn"


## The root carries no inset, and the wood fills and covers.
func test_student_card_backdrop_fills() -> void:
	var card := _scene(STUDENT_CARD)
	assert_eq(_offsets(card), Vector4.ZERO, "the StudentCard root is not inset")
	_assert_background_fills(card.get_node_or_null("Backdrop") as TextureRect,
		"StudentCard Backdrop")


## Each paper sheet and the approval stamp are Center-anchored at their
## 1080x1920 rects, so a paper and its stamp stay together, centred.
func test_student_card_papers_are_centred() -> void:
	var card := _scene(STUDENT_CARD)
	for i in range(1, 7):
		var sheet := card.get_node_or_null("KertasMurid%d" % i) as Control
		assert_true(sheet != null, "missing KertasMurid%d" % i)
		if sheet == null:
			continue
		assert_eq(_anchors(sheet), Vector4(0.5, 0.5, 0.5, 0.5),
			"KertasMurid%d is Center-anchored" % i)
		assert_eq(_offsets(sheet), Vector4(-540, -960, 540, 960),
			"KertasMurid%d stays 1080x1920" % i)
	var stamp := card.get_node_or_null("StampApprove") as Control
	assert_true(stamp != null, "missing StampApprove")
	if stamp == null:
		return
	assert_eq(_anchors(stamp), Vector4(0.5, 0.5, 0.5, 0.5), "StampApprove rides with the paper")
	assert_eq(_offsets(stamp), Vector4(-485, -608, 514, 212), "StampApprove keeps its rect")


## The title on the top edge; page arrows and page label in a Bottom Wide
## bar; all inside the safe area.
func test_student_card_ui_is_pinned_inside_the_safe_area() -> void:
	var card := _scene(STUDENT_CARD)
	_assert_under_safe_area(card.get_node_or_null("%PilihMurid"), "PilihMurid")
	var bar := card.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "StudentCard needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets taps through")
	for n in ["NextButtonKiri", "NextButtonKanan", "PageLabel"]:
		var c := card.get_node_or_null("%" + n)
		assert_true(c != null and c.get_parent() == bar, n + " rides in BottomBar")


## On a 1080x2400 phone the paper sits 240 px down, centred, and the page
## row rides the bottom edge.
func test_student_card_on_a_tall_phone() -> void:
	var card := _stood_up(STUDENT_CARD, TALL)
	_assert_rect((card.get_node("Backdrop") as Control).get_global_rect(),
		Rect2(0, 0, 1080, 2400), "Backdrop")
	_assert_rect((card.get_node("KertasMurid1") as Control).get_global_rect(),
		Rect2(0, 240, 1080, 1920), "KertasMurid1")
	_assert_rect((card.get_node("%NextButtonKanan") as Control).get_global_rect(),
		Rect2(860, 2258, 160, 128), "NextButtonKanan")
	assert_eq((card.get_node("%PilihMurid") as Control).get_global_rect().position,
		Vector2(160, 44), "the title stays at the top")


## At 1080x1920 the StudentCard is where it was.
func test_student_card_at_the_design_size_is_unchanged() -> void:
	var card := _stood_up(STUDENT_CARD, DESIGN)
	_assert_rect((card.get_node("KertasMurid1") as Control).get_global_rect(),
		Rect2(0, 0, 1080, 1920), "KertasMurid1")
	_assert_rect((card.get_node("%NextButtonKiri") as Control).get_global_rect(),
		Rect2(90, 1778, 160, 128), "NextButtonKiri")
	_assert_rect((card.get_node("%NextButtonKanan") as Control).get_global_rect(),
		Rect2(860, 1778, 160, 128), "NextButtonKanan")
	assert_eq((card.get_node("%PageLabel") as Control).get_global_rect().position,
		Vector2(440, 1805), "PageLabel")
	assert_eq((card.get_node("StampApprove") as Control).get_global_rect().position,
		Vector2(55, 352), "StampApprove")
	assert_eq((card.get_node("%PilihMurid") as Control).get_global_rect().position,
		Vector2(160, 44), "PilihMurid")
```

- [ ] **Step 3: Update the StudentCard suites.**

  **(a) `tests/test_student_card.gd`**, one `script_patch`:
  `		"BelajarButton", "NextButtonKanan", "NextButtonKiri",` →
  `		"BelajarButton", "%NextButtonKanan", "%NextButtonKiri",`

  **(b) `tests/test_student_card_layout.gd`**, three `script_patch` calls.
  1. old_text:
```gdscript
const _ART := "res://Assets/Images/StudentCard/"
```
     new_text:
```gdscript
const _ART := "res://Assets/Images/StudentCard/"

## Settles Containers in the same frame: since the 2026-09-15 tall-phone
## pass the page arrows and PageLabel sit in Safe/UI/BottomBar.
const LayoutFrame := preload("res://tests/layout_frame.gd")
```
  2. This is inside the loop over student_card.tscn and report_card.tscn.
     The report card keeps a root-level `PageLabel` until Phase 2, hence
     the fallback. old_text:
```gdscript
		inst.size = Vector2(1080, 1920)
		var page_label := inst.get_node("PageLabel") as Control
```
     new_text:
```gdscript
		inst.size = Vector2(1080, 1920)
		LayoutFrame.settle(inst)
		var page_label := inst.get_node_or_null("%PageLabel") as Control
		if page_label == null:
			page_label = inst.get_node("PageLabel") as Control
```
  3. old_text:
```gdscript
	inst.size = Vector2(1080, 1920)

	var left_arrow := inst.get_node("NextButtonKiri") as Control
	var right_arrow := inst.get_node("NextButtonKanan") as Control
```
     new_text:
```gdscript
	inst.size = Vector2(1080, 1920)
	LayoutFrame.settle(inst)

	var left_arrow := inst.get_node("%NextButtonKiri") as Control
	var right_arrow := inst.get_node("%NextButtonKanan") as Control
```

- [ ] **Step 4: Run the tests and watch them fail.** Run
  `filesystem_manage(op="scan")`, then Procedure S with the suites
  `tall_screen_layout`, `student_card` and `student_card_layout`.
  Expected failures:
  - the five StudentCard tests in `tall_screen_layout`;
  - `test_interactive_controls_meet_the_minimum_touch_target` in
    `student_card`;
  - `test_the_action_row_is_not_crowded_against_the_paper` in
    `student_card_layout`;
  - `test_page_label_sits_between_the_arrows` passes, because of its
    fallback.

- [ ] **Step 5: Re-anchor the scene.**
  1. `scene_open(path="res://Scenes/StudentCard/student_card.tscn")`. The
     root is `StudentCard`, so paths start `/StudentCard`.
  2. One `batch_execute` (`undo: true`), in order:
     - on `/StudentCard`: `sp offset_left 0`, `sp offset_top 0`,
       `sp offset_right 0`, `sp offset_bottom 0`
     - on `/StudentCard/Backdrop`: `sp layout_mode 1`, `sp anchor_right 1`,
       `sp anchor_bottom 1`, `sp offset_left 0`, `sp offset_top 0`,
       `sp offset_right 0`, `sp offset_bottom 0`
     - for each of `KertasMurid1` to `KertasMurid6`: `sp layout_mode 1`,
       `sp anchor_left 0.5`, `sp anchor_top 0.5`, `sp anchor_right 0.5`,
       `sp anchor_bottom 0.5`, `sp offset_left -540`, `sp offset_top -960`,
       `sp offset_right 540`, `sp offset_bottom 960`
     - on `/StudentCard/StampApprove`: `sp layout_mode 1`, the four anchors
       0.5, `sp offset_left -485`, `sp offset_top -608`,
       `sp offset_right 514`, `sp offset_bottom 212`
     - on `/StudentCard/BelajarButton`: `sp offset_left 398`,
       `sp offset_top 1994`, `sp offset_right 888`, `sp offset_bottom 2154`
     - `create_node {"type":"MarginContainer","name":"Safe","parent_path":"/StudentCard"}`
     - on `/StudentCard/Safe`:
       - `sp script "res://Scripts/UI/SafeAreaMargin.gd"`
       - `sp layout_mode 1`, `sp anchor_right 1`, `sp anchor_bottom 1`
       - `sp offset_right 0`, `sp offset_bottom 0`
       - `sp grow_horizontal 2`, `sp grow_vertical 2`, `sp mouse_filter 2`
     - `create_node {"type":"Control","name":"UI","parent_path":"/StudentCard/Safe"}`,
       then `sp /StudentCard/Safe/UI mouse_filter 2`
     - `create_node {"type":"Control","name":"BottomBar","parent_path":"/StudentCard/Safe/UI"}`
     - on `.../Safe/UI/BottomBar`:
       - `sp layout_mode 1`, `sp anchor_top 1`, `sp anchor_right 1`,
         `sp anchor_bottom 1`
       - `sp offset_left 0`, `sp offset_top -94`, `sp offset_right 0`,
         `sp offset_bottom 34`
       - `sp grow_horizontal 2`, `sp grow_vertical 0`, `sp mouse_filter 2`
     - `reparent_node /StudentCard/PilihMurid` → `/StudentCard/Safe/UI`
     - on `.../Safe/UI/PilihMurid`:
       - `sp layout_mode 1`, `sp anchor_left 0.5`, `sp anchor_right 0.5`
       - `sp offset_left -380`, `sp offset_top -4`, `sp offset_right 520`,
         `sp offset_bottom 146`
       - `sp unique_name_in_owner true`
     - `reparent_node` into `/StudentCard/Safe/UI/BottomBar`, in order:
       `NextButtonKiri`, `NextButtonKanan`, `PageLabel`
     - their offsets, then `sp unique_name_in_owner true` on each:
       - NextButtonKiri: 42, 0, 202, 128
       - NextButtonKanan: 812, 0, 972, 128
       - PageLabel: 392, 27, 592, 97

  Safe is appended last among the root's children, so the page row draws
  over the papers as before. Leave `ColorRect` alone.

- [ ] **Step 6: Check the tree, then save.**
  1. `scene_get_hierarchy(depth=2)`. The root's children must be, in
     order: `Backdrop`, `KertasMurid6` … `KertasMurid1`, `BelajarButton`,
     `ColorRect`, `StampApprove`, `Safe`.
  2. `scene_save`.
  3. `git diff HEAD --stat -- '*.gd'` must list only the three test files
     from Steps 2–3.

- [ ] **Step 7: Point `student_card.gd` at the moved nodes.**

  **(a)** Three `script_patch` calls on
  `res://Scripts/StudentCard/student_card.gd`:
  - `@onready var next_kanan: BaseButton = $NextButtonKanan` →
    `@onready var next_kanan: BaseButton = %NextButtonKanan`
  - `@onready var next_kiri: BaseButton = $NextButtonKiri` →
    `@onready var next_kiri: BaseButton = %NextButtonKiri`
  - `@onready var page_label: Label = $PageLabel` →
    `@onready var page_label: Label = %PageLabel`

  **(b)** One more `script_patch`. The tutorial's paths include bare
  `NextButtonKanan`. Card paths such as `KertasMurid1/Aprove` fall through
  to the plain lookup. old_text (four tabs):
```gdscript
				var target = get_node_or_null(trimmed)
```
  new_text:
```gdscript
				# A bare name is found by unique name wherever it sits (the page
				# row moved into Safe/UI/BottomBar); card paths resolve as before.
				var target = get_node_or_null("%" + trimmed)
				if target == null:
					target = get_node_or_null(trimmed)
```

- [ ] **Step 8: Run the tests and watch them pass.** Procedure S with the
  suites `tall_screen_layout`, `student_card`, `student_card_layout`,
  `paper_shadow`, `report_card`, `lobby_style_buttons`,
  `confirm_pair_semantics`, `viewport_editability` and
  `script_documentation`. Expected: all PASS.

- [ ] **Step 9: Render the result.** Procedure R with `PHASE = "after"`
  and Step 1's other parameters. Expected:
  - `bare_2400` is 0 and `changed_1920` is under 0.02;
  - on the 2400 render, the paper is centred and the arrows sit on the
    bottom edge.

- [ ] **Step 10: Restart the editor.** Procedure E.

- [ ] **Step 11: Commit.** Write the message file:
```
feat(student-card): papers stay centred and the page row pins to the bottom

The root's 70/254 inset is gone, with every child given its plain screen
rect, so nothing moves at 1080x1920. The wood fills and covers, each paper
and the approval stamp are Center-anchored, and the title and page row sit
in Safe/UI on the top and bottom edges.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```
  Then run:
```bash
git branch --show-current
git add Scenes/StudentCard/student_card.tscn Scripts/StudentCard/student_card.gd tests/test_tall_screen_layout.gd tests/test_student_card.gd tests/test_student_card_layout.gd
git commit -F C:/Users/user/AppData/Local/Temp/kejartes-msg.txt
```

---

### Task 6: StudentList — cards centred, header on top, nav row on the bottom

The background already covers (rule 1 holds). Four root children still
move:
- `CardContainer` is re-anchored to the centre;
- `HeaderLabel` and `RosterStrip` move into `Safe/UI` at the top;
- `LeftArrow`, `RightArrow` and `PageIndicator` move into a bottom bar.

`ColorRect` (the tutorial overlay) must stay the last root child, over the
HUD. The screen runs with only the debug seed, since `day_schedules` reads
are guarded.

Never save `RosterCard.tscn`: its StickyNotes bake a 20 px drop. Instance
overrides on its children are dropped when `student_list.tscn` is saved, so
saving the list itself is safe.

**Files:**
- Modify: `Scenes/StudentList/student_list.tscn` (editor only), `Scripts/StudentList/student_list.gd:35-37, 342, 372, 825-833`
- Modify: `tests/test_student_list.gd:48, 146, 166, 190-191, 384, 392-400, 415`
- Test: `tests/test_tall_screen_layout.gd` (append)

**Interfaces:**
- Consumes `tests/layout_frame.gd` (`stand_up`) and the suite helpers.
- Produces the new paths `Safe/UI/{HeaderLabel, RosterStrip}` and
  `Safe/UI/BottomBar/{LeftArrow, RightArrow, PageIndicator}`, all unique
  names. `CardContainer`, `Backdrop` and `ColorRect` keep their paths.

**Geometry:**

| Node | Screen rect | Parent after | Anchors (L,T,R,B) | New offsets (L,T,R,B) |
|---|---|---|---|---|
| CardContainer | 50,310–1030,1720 | root | 0.5 ×4 | −490,−650,490,760 |
| HeaderLabel | 190,24–890,140 | Safe/UI | 0.5,0,0.5,0 | −350,−24,350,92 |
| RosterStrip | 70,128–1010,278 | Safe/UI | 0.5,0,0.5,0 | −470,80,470,230 |
| BottomBar (new) | 48,1772–1032,1900 | Safe/UI | 0,1,1,1 | 0,−100,0,28 |
| LeftArrow | 70,1772–230,1900 | BottomBar | 0,0,0,0 | 22,0,182,128 |
| RightArrow | 850,1772–1010,1900 | BottomBar | 0,0,0,0 | 802,0,962,128 |
| PageIndicator | 400,1794–680,1878 | BottomBar | 0,0,0,0 | 352,22,632,106 |

- [ ] **Step 1: Capture the baseline.** Procedure R with
  `SCENE = "res://Scenes/StudentList/student_list.tscn"`,
  `TAG = "student_list"`, `PHASE = "before"` and `PREP = ""`.

- [ ] **Step 2: Append the StudentList tests.** `script_patch` on
  `res://tests/test_tall_screen_layout.gd`.

  old_text (the suite's last two lines, from Task 5):
```gdscript
	assert_eq((card.get_node("%PilihMurid") as Control).get_global_rect().position,
		Vector2(160, 44), "PilihMurid")
```
  new_text:
```gdscript
	assert_eq((card.get_node("%PilihMurid") as Control).get_global_rect().position,
		Vector2(160, 44), "PilihMurid")


# ── StudentList ──────────────────────────────────────────────────────────────

const STUDENT_LIST := "res://Scenes/StudentList/student_list.tscn"


func test_student_list_backdrop_fills() -> void:
	_assert_background_fills(_scene(STUDENT_LIST).get_node_or_null("Backdrop") as TextureRect,
		"StudentList Backdrop")


## The roster cards are one Center-anchored piece at their 980x1410 rect.
func test_student_list_cards_are_centred() -> void:
	var cards := _scene(STUDENT_LIST).get_node_or_null("CardContainer") as Control
	assert_true(cards != null, "missing CardContainer")
	if cards == null:
		return
	assert_eq(_anchors(cards), Vector4(0.5, 0.5, 0.5, 0.5), "CardContainer is Center-anchored")
	assert_eq(_offsets(cards), Vector4(-490, -650, 490, 760), "CardContainer keeps its rect")


## The header and avatar strip on the top edge; the arrows and page dots in a
## Bottom Wide bar; all inside the safe area. The tutorial overlay stays the
## last child, over the HUD.
func test_student_list_ui_is_pinned_inside_the_safe_area() -> void:
	var list := _scene(STUDENT_LIST)
	_assert_under_safe_area(list.get_node_or_null("%HeaderLabel"), "HeaderLabel")
	_assert_under_safe_area(list.get_node_or_null("%RosterStrip"), "RosterStrip")
	var bar := list.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "StudentList needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets taps through")
	for n in ["LeftArrow", "RightArrow", "PageIndicator"]:
		var c := list.get_node_or_null("%" + n)
		assert_true(c != null and c.get_parent() == bar, n + " rides in BottomBar")
	var overlay := list.get_node_or_null("ColorRect")
	assert_true(overlay != null and overlay.get_index() == list.get_child_count() - 1,
		"the tutorial overlay stays the last child, over the HUD")


## On a 1080x2400 phone the cards sit centred and the nav row rides the
## bottom edge; the header stays on top.
func test_student_list_on_a_tall_phone() -> void:
	var list := _stood_up(STUDENT_LIST, TALL)
	_assert_rect((list.get_node("CardContainer") as Control).get_global_rect(),
		Rect2(50, 550, 980, 1410), "CardContainer")
	_assert_rect((list.get_node("%RightArrow") as Control).get_global_rect(),
		Rect2(850, 2252, 160, 128), "RightArrow")
	assert_eq((list.get_node("%HeaderLabel") as Control).get_global_rect().position,
		Vector2(190, 24), "the header stays at the top")


## At 1080x1920 the StudentList is where it was.
func test_student_list_at_the_design_size_is_unchanged() -> void:
	var list := _stood_up(STUDENT_LIST, DESIGN)
	_assert_rect((list.get_node("CardContainer") as Control).get_global_rect(),
		Rect2(50, 310, 980, 1410), "CardContainer")
	_assert_rect((list.get_node("%LeftArrow") as Control).get_global_rect(),
		Rect2(70, 1772, 160, 128), "LeftArrow")
	_assert_rect((list.get_node("%RosterStrip") as Control).get_global_rect(),
		Rect2(70, 128, 940, 150), "RosterStrip")
	assert_eq((list.get_node("%PageIndicator") as Control).get_global_rect().position,
		Vector2(400, 1794), "PageIndicator")
```

- [ ] **Step 3: Update `tests/test_student_list.gd`.** Make seven
  `script_patch` calls.
  1. `const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"` →
```gdscript
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## Stands the list up and settles its Containers in the same frame.
const LayoutFrame := preload("res://tests/layout_frame.gd")
```
  2. `		"CardContainer/Murid1/CardButton", "LeftArrow", "RightArrow",` →
     `		"CardContainer/Murid1/CardButton", "%LeftArrow", "%RightArrow",`
  3. `	var header := _list.get_node_or_null("HeaderLabel") as Label` →
     `	var header := _list.get_node_or_null("%HeaderLabel") as Label`, with
     `replace_all: true`. It occurs twice.
  4. old_text:
```gdscript
	for name in ["LeftArrow", "RightArrow"]:
		var b := _list.get_node_or_null(name) as Button
```
     new_text:
```gdscript
	for name in ["LeftArrow", "RightArrow"]:
		var b := _list.get_node_or_null("%" + name) as Button
```
  5. `	var strip := _list.get_node_or_null("RosterStrip")` →
     `	var strip := _list.get_node_or_null("%RosterStrip")`
  6. old_text (lines 392-400):
```gdscript
## The arrows used to sit pinned to the vertical centre of a 1920-tall
## screen, which is nowhere near a thumb. They move to a nav row with
## the page dots.
func test_navigation_sits_in_thumb_reach() -> void:
	for n in ["LeftArrow", "RightArrow", "PageIndicator"]:
		var c := _list.get_node_or_null(n) as Control
		assert_true(c != null, "missing " + n)
		assert_true(c.offset_top >= 1600.0,
			"%s must sit in the lower third, got offset_top %f" % [n, c.offset_top])
```
     new_text:
```gdscript
## The arrows used to sit pinned to the vertical centre of a 1920-tall
## screen, which is nowhere near a thumb. They sit in a nav row with the
## page dots -- since the 2026-09-15 tall-phone pass a Bottom Wide bar in
## Safe/UI, so their offsets are bar-local and the check reads global rects.
func test_navigation_sits_in_thumb_reach() -> void:
	var frame := track(LayoutFrame.stand_up(_SCENE_PATH, Vector2(1080, 1920))) as Control
	var list := frame.get_child(0) as Control
	var cards_bottom := (list.get_node("CardContainer") as Control).get_global_rect().end.y
	for n in ["LeftArrow", "RightArrow", "PageIndicator"]:
		var c := list.get_node_or_null("%" + n) as Control
		assert_true(c != null, "missing " + n)
		if c == null:
			continue
		var top := c.get_global_rect().position.y
		assert_true(top >= 1600.0, "%s must sit in the lower third, got y %f" % [n, top])
		assert_true(top >= cards_bottom,
			"%s must sit below the cards (their bottom is %f), got y %f" % [n, cards_bottom, top])
```
  7. Confirm that no bare lookup of a moved node is left:
```powershell
Select-String -Path tests/test_student_list.gd -Pattern 'get_node_or_null\("(LeftArrow|RightArrow|PageIndicator|HeaderLabel|RosterStrip)'
```
     Expected: no matches. The source scans at 452-459 stay as they are:
     they check tutorial target strings in the script, not node paths.

- [ ] **Step 4: Run the tests and watch them fail.** Run
  `filesystem_manage(op="scan")`, then Procedure S with the suites
  `tall_screen_layout` and `student_list`. Expected failures:
  - the StudentList tests in `tall_screen_layout`;
  - in `student_list`: the touch-target, header, nav-arrow, roster-strip,
    thumb-reach and plaque tests.

- [ ] **Step 5: Re-anchor the scene.**
  1. `scene_open(path="res://Scenes/StudentList/student_list.tscn")`. The
     root is `StudentList`.
  2. One `batch_execute` (`undo: true`), in order:
     - on `/StudentList/CardContainer`: the four anchors 0.5,
       `sp offset_left -490`, `sp offset_top -650`, `sp offset_right 490`,
       `sp offset_bottom 760`
     - `create_node {"type":"MarginContainer","name":"Safe","parent_path":"/StudentList"}`
     - on `/StudentList/Safe`:
       - `sp script "res://Scripts/UI/SafeAreaMargin.gd"`
       - `sp layout_mode 1`, `sp anchor_right 1`, `sp anchor_bottom 1`
       - `sp offset_right 0`, `sp offset_bottom 0`
       - `sp grow_horizontal 2`, `sp grow_vertical 2`, `sp mouse_filter 2`
     - `create_node {"type":"Control","name":"UI","parent_path":"/StudentList/Safe"}`,
       then `sp /StudentList/Safe/UI mouse_filter 2`
     - `create_node {"type":"Control","name":"BottomBar","parent_path":"/StudentList/Safe/UI"}`
     - on `.../Safe/UI/BottomBar`:
       - `sp layout_mode 1`, `sp anchor_top 1`, `sp anchor_right 1`,
         `sp anchor_bottom 1`
       - `sp offset_left 0`, `sp offset_top -100`, `sp offset_right 0`,
         `sp offset_bottom 28`
       - `sp grow_horizontal 2`, `sp grow_vertical 0`, `sp mouse_filter 2`
     - `reparent_node` `HeaderLabel`, then `RosterStrip`, into
       `/StudentList/Safe/UI`
     - on `.../Safe/UI/HeaderLabel`: `sp anchor_left 0.5`,
       `sp anchor_right 0.5`, `sp offset_left -350`, `sp offset_top -24`,
       `sp offset_right 350`, `sp offset_bottom 92`,
       `sp unique_name_in_owner true`
     - on `.../Safe/UI/RosterStrip`: `sp layout_mode 1`, `sp anchor_left 0.5`,
       `sp anchor_right 0.5`, `sp offset_left -470`, `sp offset_top 80`,
       `sp offset_right 470`, `sp offset_bottom 230`,
       `sp unique_name_in_owner true`
     - `reparent_node` into `/StudentList/Safe/UI/BottomBar`, in order:
       `LeftArrow`, `RightArrow`, `PageIndicator`
     - their offsets, then `sp unique_name_in_owner true` on each:
       - LeftArrow: 22, 0, 182, 128
       - RightArrow: 802, 0, 962, 128
       - PageIndicator: 352, 22, 632, 106
     - `move_node {"path":"/StudentList/Safe","index":2}`. This puts Safe
       before `ColorRect`.

- [ ] **Step 6: Check the tree, then save.**
  1. `scene_get_hierarchy(depth=2)`. The root's children must be, in
     order: `Backdrop`, `CardContainer`, `Safe`, `ColorRect`.
  2. `scene_save`.
  3. Run the checks:
```powershell
git status --short -- Scenes/StudentList
git diff HEAD --stat -- '*.gd'
```
  Expected:
  - Only `student_list.tscn` is modified. If `RosterCard.tscn` shows up,
    run `git checkout -- Scenes/StudentList/RosterCard.tscn`, then restart
    the editor (Procedure E).
  - The `.gd` diff lists only the two test files from Steps 2–3.

- [ ] **Step 7: Point `student_list.gd` at the moved nodes.** Make six
  `script_patch` calls on `res://Scripts/StudentList/student_list.gd`.
  1. `@onready var left_arrow = $LeftArrow` → `@onready var left_arrow = %LeftArrow`
  2. `@onready var right_arrow = $RightArrow` → `@onready var right_arrow = %RightArrow`
  3. `@onready var page_indicator = $PageIndicator` → `@onready var page_indicator = %PageIndicator`
  4. `get_node_or_null("RosterStrip/Avatar%d" % (i + 1))` →
     `get_node_or_null("%RosterStrip/Avatar%d" % (i + 1))`
  5. `	var strip := get_node_or_null("RosterStrip")` →
     `	var strip := get_node_or_null("%RosterStrip")`
  6. old_text:
```gdscript
func _find_target_node(path_str: String) -> Node:
	var node = get_node_or_null(path_str)
```
     new_text:
```gdscript
func _find_target_node(path_str: String) -> Node:
	# A bare name ("RightArrow", "RosterStrip") is found by unique name wherever
	# it sits (Safe/UI since the 2026-09-15 tall-phone pass).
	var node = get_node_or_null("%" + path_str)
	if node:
		return node
	node = get_node_or_null(path_str)
```

- [ ] **Step 8: Run the tests and watch them pass.** Procedure S with the
  suites `tall_screen_layout`, `student_list`, `face_rig_roster`,
  `confirm_pair_semantics`, `lobby_style_buttons`, `viewport_editability`
  and `script_documentation`. Expected: all PASS.

- [ ] **Step 9: Render the result.** Procedure R with `PHASE = "after"`
  and Step 1's other parameters. Expected:
  - `bare_2400` is 0 and `changed_1920` is under 0.02;
  - on the 2400 render, the cards are centred and the arrows and dots sit
    on the bottom edge.

- [ ] **Step 10: Restart the editor.** Procedure E.

- [ ] **Step 11: Commit.** Write the message file:
```
feat(student-list): cards stay centred and the nav row pins to the bottom

The roster cards are one Center-anchored piece; the header and avatar
strip sit in Safe/UI on the top edge and the arrows and page dots in a
Bottom Wide bar. student_list.gd and the tutorial find them by unique name.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```
  Then run:
```bash
git branch --show-current
git add Scenes/StudentList/student_list.tscn Scripts/StudentList/student_list.gd tests/test_tall_screen_layout.gd tests/test_student_list.gd
git commit -F C:/Users/user/AppData/Local/Temp/kejartes-msg.txt
```

---

### Task 7: Docs, full suite, ship

**Files:**
- Modify: `CLAUDE.md` (Visual system, Godot MCP, Working efficiently here, Testing)
- Modify: `docs/superpowers/design/authoring-guide.md` (two new sections before `## Asset references`)
- Modify: `docs/superpowers/DEBT.md`, `docs/superpowers/CHANGELOG.md`

**Interfaces:** Consumes Task 2's recorded fact, "desktop preview: works"
or "does not work".

`CLAUDE.md` is already at 23,690 characters, over its 23,000 soft budget.
Its own rule: a pass that would exceed the budget moves something out
first, and never thins the live rules. So Step 1 moves three how-to
paragraphs out before Step 2 adds the rule.

- [ ] **Step 1: Move three paragraphs out of `CLAUDE.md`.** Cut each one
  whole, keeping its text verbatim for Steps 3 and 4:
  - The `## Godot MCP` paragraph that starts
    ``scene_open` on `Scenes/SchoolSimulation/BookClockWidget.tscn` hangs the``.
    It goes to `DEBT.md` in Step 4, because it is a known bug.
  - The `## Working efficiently here` paragraph that starts
    `**Clicking, when you must.**`. It goes to the authoring guide in
    Step 3.
  - The paragraph that starts `**Rebaking without File > Run.**`. It also
    goes to the authoring guide in Step 3.

- [ ] **Step 2: Add the third rule to `CLAUDE.md`.** Use the Edit tool.

  old_string:
```
Full detail: `docs/superpowers/design/authoring-guide.md`.

**Cards.**
```
  new_string:
```
Full detail: `docs/superpowers/design/authoring-guide.md`.

**The third rule: every screen fills any phone.** A 20:9 phone runs the game
at 1080×2400 (`aspect="expand"`); the editor's embedded run is locked to
9:16 and never shows it. Backgrounds are Full Rect + Keep Aspect Covered; UI
is re-anchored to its edge inside `SafeAreaMargin` → `UI`; a picture and its
items move as one piece. Pinned by `tests/test_tall_screen_layout.gd`; how-to
in the authoring guide's "Tall phones".

**Cards.**
```
  Then run `(Get-Content -Raw CLAUDE.md).Length`. If it is over 23,000,
  also move the `**Tuning how something animates**` paragraph into the
  authoring guide's new "Editor and game recipes" section, and measure
  again.

- [ ] **Step 3: Add two sections to the authoring guide.** Use the Edit
  tool on `docs/superpowers/design/authoring-guide.md`.

  old_string: `## Asset references`. new_string: the block below, followed by
  a blank line and `## Asset references`.
  - Keep only the desktop-preview paragraph that matches Task 2's result.
  - Paste the two moved paragraphs verbatim where the block says so.

```markdown
## Tall phones: fill the screen

The game runs `window/stretch/aspect="expand"`, so a 20:9 phone gets a
1080×2400 viewport, and a 21:9 one gets 1080×2520. The editor never shows
this: its embedded run is locked to the 360×640 window override (Godot
logs `Embedded window can't be resized`). Author every screen at 1080×1920,
and apply four rules (spec
`docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md`):

1. **Backgrounds fill.** Use a `TextureRect` with anchors `0,0,1,1`,
   offsets 0, `expand_mode = 1` and `stretch_mode = 6` (Keep Aspect
   Covered). Stretch (0) distorts the art; fit (5) leaves bars.
2. **UI sits on its edge.** Pick the preset by role: header Top Wide, back
   button Top Left, action row Bottom Wide, card or popup Center.
   **Re-anchor, don't move:** set the anchors, then each offset to
   `old_global − (parent_origin + anchor × parent_size)` measured at
   1080×1920. The node keeps its rect there and follows its edge on taller
   screens.
3. **UI inside the margin.** Use a Full Rect `SafeAreaMargin` named `Safe`
   (`mouse_filter` IGNORE), holding one plain `Control` named `UI`, then
   the edge groups. A container places its children itself, so presets on
   `Safe`'s direct children do nothing. Inside `UI` at 1080×1920, the rect
   is (48,48)–(1032,1872).
4. **Pictures carry their items.** A picture and anything placed on it
   (seats on desks, items on shelves) form one fixed-size Control, anchored
   as a whole. The Lobby's `Classroom` is Center-anchored at 1080×1920,
   with black behind it.

**Doing it through the bridge.**
- `reparent_node` keeps local offsets and appends the node as the last
  child. Set its offsets explicitly afterwards, and fix its order with
  `move_node`.
- Set `layout_mode = 1` before anchors on any Control under a plain
  Control.
- Mark anything a script or tutorial looks up as a unique name, and find it
  with `%Name` or `get_node("%Name/Child")`.

**Testing.**
- `tests/layout_frame.gd` stands a screen up at any size in the editor's
  tree. It sends every Container `NOTIFICATION_SORT_CHILDREN` by hand, so
  rects are final in the same frame. Containers otherwise sort a frame
  late, while anchored children follow at once.
- `tests/test_tall_screen_layout.gd` checks each screen's contract and its
  rects at 1080×2400 and 1080×1920.
- For a picture of the result, render the scene into 1080×1920 and
  1080×2400 `SubViewport`s inside the running game (spec, Appendix B).
  `bare` counts Godot's gray clear colour, and must be 0 at 2400.

**Desktop preview (if Task 2 found it works).** To see a tall phone on the
desktop, set `display/window/size/window_height_override` to 800 (width
360), run, and set it back to 640 afterwards. Never commit the override.

**Desktop preview (if Task 2 found it does not).** The embedded run ignores
a changed override, so the `SubViewport` render check is the desktop
preview.

## Editor and game recipes

<the moved **Clicking, when you must.** paragraph, verbatim>

<the moved **Rebaking without File > Run.** paragraph, verbatim>
```

- [ ] **Step 4: Move the BookClockWidget note to `DEBT.md`.** Append it as
  its own entry at the end of `docs/superpowers/DEBT.md`. Head it
  `**Opening BookClockWidget.tscn hangs the editor (moved from CLAUDE.md, 2026-09-15).**`,
  followed by the paragraph from Step 1, verbatim.

- [ ] **Step 5: Run the full suite.**
  1. `scene_open(path="res://Scenes/MainMenu/main_menu.tscn")`.
  2. `test_run()`. Expected: every suite passes, including the new
     `tall_screen_layout`. Note the reply's suite and test counts.
  3. The bridge usually drops after a full run: Procedure E.
  4. Run `git status --short`. If `Assets/Theme/kejartes_theme.tres` is
     modified, restore it with `git checkout --`: no token changed in this
     work. Leave `default_bus_layout.tres` and `project.godot` as they are,
     unstaged.

- [ ] **Step 6: Update the suite count.** In `CLAUDE.md` `## Testing`,
  change `110 suites, 1577 tests (2026-09-15).` to the numbers from Step 5,
  in the same format.

- [ ] **Step 7: Add a changelog entry.** In `docs/superpowers/CHANGELOG.md`,
  insert this directly above the first `## 2026-09-15 —` entry. Replace
  `<N>` and `<M>` with Step 5's counts, and write the Task 2 result in its
  sentence.

```markdown
## 2026-09-15 — Tall phones, Phase 1: Lobby, Koperasi, StudentCard, StudentList

Plan `docs/superpowers/plans/2026-09-15-tall-phone-layout-phase-1.md`, spec
`docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md`.

A 20:9 phone runs the game at 1080×2400, and these four screens were laid out
for exactly 1080×1920. Their fixed backgrounds left a bare gray band, and the
Lobby's classroom slid down while the seats stayed put, so the students sat
at the wrong desks. The editor never showed it, because its embedded run is
locked to 9:16. Each screen now follows four rules:

- the background fills;
- the UI is re-anchored to its edge, without moving, inside a
  `SafeAreaMargin`;
- a picture keeps its items.

At 1080×1920 nothing moved.

- **Lobby.** `Classroom` holds the background, desks, seats and hands,
  Center-anchored at 1080×1920 over a black `Backdrop`. The title and
  button block sit in `Safe/UI`. `loby.gd` uses unique names, and the
  reward blur is inserted at `DailyReward`'s index.
- **Koperasi.** The room covers. The shelf view moves as one piece pinned
  to the bottom, so the tray reaches the edge. The coins sit in the safe
  area.
- **StudentCard.** The root's 70/254 inset is gone. The papers and stamp
  are centred, and the page row pins to the bottom.
- **StudentList.** The cards are centred. The header and strip sit on top,
  and the nav row at the bottom.
- **Tests.** New `tests/layout_frame.gd` settles Containers in the same
  frame, and new suite `tall_screen_layout` checks each screen at
  1080×2400 and 1080×1920. `SafeAreaMargin` now warns only on a device.
- **Desktop preview:** <works via a 360×800 override / does not work; use
  the render check>.

Suite: <N> suites, <M> tests, green.
```

- [ ] **Step 8: Commit the docs.**
  1. Before committing, check that `Assets/Theme/kejartes_theme.tres` is
     not staged.
  2. Write the message file:
```
docs(layout): the third visual rule, the tall-phone how-to and the changelog

CLAUDE.md gains "every screen fills any phone" and moves three how-to
paragraphs out to stay under its budget: the BookClockWidget hang to DEBT,
the clicking and rebaking recipes to the authoring guide.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```
  3. Run:
```bash
git branch --show-current
git add CLAUDE.md docs/superpowers/design/authoring-guide.md docs/superpowers/DEBT.md docs/superpowers/CHANGELOG.md
git commit -F C:/Users/user/AppData/Local/Temp/kejartes-msg.txt
```

- [ ] **Step 9: Ship.** Invoke the `ship-pr` skill. It runs the full suite
  and a local review, pushes `fix/tall-phone-layout`, opens the PR into
  `Textures`, and stamps the tested commit. Straight after `gh pr create`,
  bind the PR and set its monitor.

- [ ] **Step 10: Ask for the device check.** Ask the user to export a build
  and check the four screens on their phone.

## After Phase 1

Write Phase 2's plan (AturJadwal, CutScene, Rapor, Inventory) against the
scene files as they stand then. Rapor and Inventory wait until the two
separate fixes that edit those scenes (the `KEMBALI` overlap, and the
Inventory glyph and icons) have merged. Phase 3 covers ExamProgress,
StatCheck, EndCutscene, the ResultCheckup confetti and MainBola.
