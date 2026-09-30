# Lobby students sit at the desk, not on the chair — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move each Lobby seat down so every student's body ends on the desk's real back edge, instead of on the chair-back top that the 2026-09-30 pass mistook for it.

**Architecture:** The 2026-09-30 picture mapping stays, and each seat's vertical anchor moves from the chair top to the real desk edge. The Lobby scene moves 8 slot Controls (a portrait slot and a hands slot per seat) down by that correction. Tests read the desk edge from the plate texture itself, so a stale anchor cannot pass again.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuite` tests run through the godot-ai MCP `test_run`.

Spec: `docs/superpowers/specs/2026-10-01-lobby-seat-on-desk-edge-design.md`.

## Global Constraints

- Work only in the worktree `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/lobby-seat-desk-edge/` on branch `fix/lobby-seat-desk-edge`. Every path below is relative to it. Never edit the main checkout.
- The godot-ai bridge's default editor is the MAIN checkout's (`new-game-project@…`). Every godot-ai call in this plan passes the worktree editor's `session_id` (Task 2). Never `session_activate`.
- No test may be a coroutine; suites stay `@tool`; every new `const`/`func` gets a `##` doc line (`tests/test_script_documentation.gd`).
- Never hand-edit `Lobby.tscn` while an editor on the worktree is running; make scene edits through that editor, then `scene_save`, then diff.
- Change nothing but the 8 slots' `offset_top`/`offset_bottom`: portrait sizes, hand scales, x positions and Marcel's Slot3 flip stay.
- Commits: Conventional Commits with a scope, message written to a file and committed with `git commit -F`, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run git as single plain commands (no `cd &&` chains).
- Before committing, revert `Assets/Audio/default_bus_layout.tres` and any `*.png.import` that an editor boot rewrote (check `git status --short`).

## The numbers

| Seat | Desk plate | Real back edge (classroom px) | Old anchor | drop |
|---|---|---|---|---|
| Slot1 back-left | `Meja_KiriAtas` | 400.045 | 338 | 62.045 |
| Slot2 back-right | `Meja_KananAtas` | 400.0 | 338 | 62.0 |
| Slot3 front-left | `Meja_KiriBawah` | 766.0 | 683 | 83.0 |
| Slot4 front-right | `Meja_KananBawah` | 766.0 | 683 | 83.0 |

Target slot offsets (all other properties untouched):

| Node (under `World/Classroom/`) | offset_top | offset_bottom |
|---|---|---|
| `StudentPortraitsContainer_Back/Slot1` | 0 → **62.045** | 450 → **512.045** |
| `StudentPortraitsContainer_Back/Slot2` | 0 → **62.0** | 450 → **512.0** |
| `StudentHandsContainer_Back/Slot1` | -88 → **-25.955** | 362 → **424.045** |
| `StudentHandsContainer_Back/Slot2` | -85 → **-23.0** | 365 → **427.0** |
| `StudentPortraitsContainer_Front/Slot3` | 370 → **453.0** | 820 → **903.0** |
| `StudentPortraitsContainer_Front/Slot4` | 370 → **453.0** | 820 → **903.0** |
| `StudentHandsContainer_Front/Slot3` | 370 → **453.0** | 820 → **903.0** |
| `StudentHandsContainer_Front/Slot4` | 370 → **453.0** | 820 → **903.0** |

---

### Task 1: Tests that pin the seats to the real desk edge (red)

**Files:**
- Modify: `tests/test_lobby_desk_items_fit.gd` (header 16-18, `SEATS` 52-77, new consts/helpers/tests, portrait test 201-212)
- Modify: `tests/test_lobby_layout.gd:140-144` (front heads), `:162-164` (`DESK_TOP_ROWS`)

**Interfaces:**
- Produces: `_desk_back_edge(plate: String) -> float`, `_portrait_rect(slot_path: String) -> Rect2`, `_edges: Dictionary` (seat name → edge), the `"desk"` key on each `SEATS` entry, and the tests `test_each_seat_is_anchored_on_its_desks_back_edge` and `test_each_seats_portrait_ends_on_its_desks_back_edge`.

- [ ] **Step 1: Correct the header.** In `tests/test_lobby_desk_items_fit.gd` replace lines 16-18:

```gdscript
## The picture's desks are other art than the game's (429 px wide against
## 448), so its numbers are mapped through K = 448 / 429, anchored on each
## desk's back edge: spec and plan 2026-09-30-lobby-seating-and-planks.
```

with:

```gdscript
## The picture's numbers are mapped through K = 448 / 429 (game desk width
## over the picture's), anchored on each desk's back edge: spec and plan
## 2026-09-30-lobby-seating-and-planks. That pass anchored on the top of the
## chair back drawn into every desk plate, which is the same wood as the desk,
## so every seat sat one chair-height too high; since 2026-10-01 the edge is
## read from the plate's own pixels (spec 2026-10-01-lobby-seat-on-desk-edge).
```

- [ ] **Step 2: Real anchors, and each seat's desk.** In `SEATS`, change only `anchor_game` and add `"desk"`:
  - Slot1: `"anchor_game": Vector2(271.26, 400.045), "desk": "Meja_KiriAtas",`
  - Slot2: `"anchor_game": Vector2(803.74, 400.0), "desk": "Meja_KananAtas",`
  - Slot3: `"anchor_game": Vector2(462, 766), "desk": "Meja_KiriBawah",`
  - Slot4: `"anchor_game": Vector2(622, 766), "desk": "Meja_KananBawah",`

  Put the `"desk"` key on the `"portraits"`/`"hands"` line of each entry. Also add a `## … "desk" is the seat's desk plate node.` sentence to the `SEATS` doc comment.

- [ ] **Step 3: Constants, preload, cache.** After `const PORTRAIT_SIDE := 1280.0` add:

```gdscript
## Reads a texture's pixels whatever its import compression.
const TexturePixels := preload("res://tests/texture_pixels.gd")
## A desk plate row with an opaque run wider than this is desk, not chair:
## the chair backs drawn into the plates run at most 223 px, and each desk's
## first row at least 303.
const DESK_MIN_RUN := 260
## Slack between a seat's Portrait bottom and its desk's back edge, px; the
## picture's own gap is 1.25 (Thea's square ends at 811.8, her desk at 813).
const EDGE_TOLERANCE := 1.5
```

  After `var _props: Dictionary` add:

```gdscript
## Each seat's desk back edge in classroom px, read once from the plates.
var _edges: Dictionary
```

  Make `suite_setup` fill it:

```gdscript
## Reads the scene's node properties and the desks' back edges once for
## every test.
func suite_setup(_ctx: Dictionary) -> void:
	_props = read_scene_props(load(SCENE) as PackedScene)
	_edges = {}
	for name: String in SEATS:
		_edges[name] = _desk_back_edge(SEATS[name]["desk"])
```

- [ ] **Step 4: Helpers.** After `_node()` add:

```gdscript
## The first row of `plate`'s texture whose longest opaque run is wider than
## DESK_MIN_RUN, in classroom px (the plate's offset_top added; the plates
## are never stretched vertically). A colour or alpha bounding box would start
## at the chair back's top instead.
func _desk_back_edge(plate: String) -> float:
	var props := _node(plate)
	var img := TexturePixels.of(props["texture"] as Texture2D)
	if img.is_compressed():
		img.decompress()
	for y in img.get_height():
		var run := 0
		for x in img.get_width():
			run = run + 1 if img.get_pixel(x, y).a > 0.5 else 0
			if run > DESK_MIN_RUN:
				return y + float(props.get("offset_top", 0.0))
	return INF


## A slot's Portrait rect in classroom pixels.
func _portrait_rect(slot_path: String) -> Rect2:
	var slot := _slot_rect(slot_path)
	var p := _node("%s/Portrait" % slot_path)
	return Rect2(slot.position + Vector2(p.get("offset_left", 0.0), p.get("offset_top", 0.0)),
		slot.size + Vector2(float(p.get("offset_right", 0.0)) - float(p.get("offset_left", 0.0)),
			float(p.get("offset_bottom", 0.0)) - float(p.get("offset_top", 0.0))))
```

  Place `_portrait_rect` after `_slot_rect` (it calls it). In `test_each_seats_portrait_sits_where_the_picture_puts_it` replace the `slot`/`p`/`got` lines with `var got := _portrait_rect(seat["portraits"])`.

- [ ] **Step 5: The two new tests.** Append:

```gdscript
## The picture is anchored on each desk's real back edge, read from the
## plate's pixels, so a moved plate or new desk art cannot leave the seats
## on a stale number.
func test_each_seat_is_anchored_on_its_desks_back_edge() -> void:
	for name: String in SEATS:
		var seat: Dictionary = SEATS[name]
		var plate := _node(seat["desk"])
		assert_eq((plate.get("scale", Vector2.ONE) as Vector2).y, 1.0,
			"%s is not stretched vertically" % seat["desk"])
		assert_true(absf((seat["anchor_game"] as Vector2).y - float(_edges[name])) < 0.01,
			"%s is anchored at y=%.3f, its desk's back edge is at %.3f"
				% [name, (seat["anchor_game"] as Vector2).y, _edges[name]])


## As in the picture, each seat's body ends on its desk's back edge, so the
## arms rest on the desk top and the body hides the chair behind it.
func test_each_seats_portrait_ends_on_its_desks_back_edge() -> void:
	for name: String in SEATS:
		var bottom := _portrait_rect(SEATS[name]["portraits"]).end.y
		assert_true(absf(bottom - float(_edges[name])) <= EDGE_TOLERANCE,
			"%s's Portrait ends at y=%.2f, its desk's back edge is at %.2f"
				% [name, bottom, _edges[name]])
```

- [ ] **Step 6: `test_lobby_layout.gd`.** Replace lines 141-144:

```gdscript
	# Front-row head centres, derived from the portrait art's opaque
	# bounds (Thea.png: art starts 10.8% down, centred 49.9% across)
	# mapped through Slot3 and Slot4's rects.
	var heads := [Vector2(225, 389), Vector2(845, 389)]
```

  with:

```gdscript
	# Front-row head centres, derived from the portrait art's opaque
	# bounds (Thea.png: art starts 10.8% down, centred 49.9% across)
	# mapped through Slot3 and Slot4's rects; 83 px lower since the seats
	# sit on the desk's real back edge (2026-10-01).
	var heads := [Vector2(225, 472), Vector2(845, 472)]
```

  and lines 162-164:

```gdscript
## The rows of a desk's top surface, in the desk plate's own pixels, that the
## seat is centred against (the back desks' tops run from y=343 to about 560).
const DESK_TOP_ROWS := Vector2i(343, 560)
```

  with:

```gdscript
## The rows of a desk's top surface, in the desk plate's own pixels, that the
## seat is centred against: the back desks' tops run from y=410 to about 560.
## Rows 343-409 are the chair back drawn behind the desk, not the desk.
const DESK_TOP_ROWS := Vector2i(410, 560)
```

- [ ] **Step 7: Commit the red tests.** Message file `…/scratchpad/msg_t1.txt`:

```
test(lobby): pin seats to the desk's real back edge, not the chair

The desk plates carry a chair back in the desk's own wood; the 2026-09-30
anchors (338 / 683) were its top. Anchors are now the real edges, read
from each plate's pixels, and each seat's Portrait must end on its desk.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

```bash
git add tests/test_lobby_desk_items_fit.gd tests/test_lobby_layout.gd
```
```bash
git commit -F <scratchpad>/msg_t1.txt
```

### Task 2: Worktree editor, red run

**Files:** none tracked (seeds `.godot/`, which is ignored).

- [ ] **Step 1: Seed the cache.** Copy `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg`, `scene_groups_cache.cfg` from the main checkout's `.godot/` into the worktree's `.godot/` (skip `.godot/editor/`).
- [ ] **Step 2: Launch detached** (PowerShell):

```powershell
$exe = "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
$wt = "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\lobby-seat-desk-edge"
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$wt`" -e"; CurrentDirectory = $wt }
```

  Poll `session_manage(op="list")` until a `lobby-seat-desk-edge@…` session is `ready`. Use its id as `session_id` from here on.
- [ ] **Step 3: Red run.** `test_run(suite="lobby_desk_items_fit", session_id=…)`. Expected: `test_each_seat_is_anchored_on_its_desks_back_edge` PASSES (the constants match the art). These FAIL, each off by the seat's drop: `…portrait_sits_where_the_picture_puts_it`, `…pictured_students_match_the_picture`, `…every_student_wears_its_rows_scale_and_rises_with_it`, `…portrait_ends_on_its_desks_back_edge`. If the anchor test fails, the edge helper is wrong: fix it before going on. Then run `test_run(suite="lobby_layout", …)`: `test_back_row_students_sit_on_their_desks_centre` must pass (1.54 px shift inside 2.5).

### Task 3: Move the eight slots (green)

**Files:**
- Modify: `Scenes/Lobby/Lobby.tscn` (8 slot nodes, via the editor)

- [ ] **Step 1:** `scene_open(path="res://Scenes/Lobby/Lobby.tscn", session_id=…)`.
- [ ] **Step 2:** One `batch_execute` of 16 `set_property` commands, setting `offset_top` then `offset_bottom` on each node in "The numbers" table (paths `World/Classroom/<node>`). Setting `offset_top` first keeps each slot's height.
- [ ] **Step 3:** `scene_save(session_id=…)`, then:

```bash
git diff --stat
```
```bash
git diff -- Scenes/Lobby/Lobby.tscn
```

  Expect only the 16 offset lines (the two back portrait slots gain an `offset_top` line). If anything else changed (StickyNote/DancerRig offsets, theme overrides, uids), restore those hunks by hand-editing the file **after** closing the worktree editor (`editor_manage(op="quit")`), then relaunch it. Also run `git diff HEAD --stat -- '*.gd'`: it should list only the two test files.
- [ ] **Step 4: Green run.** `test_run` with `session_id` for suites `lobby_desk_items_fit`, `lobby_layout`, `tall_screen_layout`, `student_chatter`, `parallax_diorama`. Expected: all pass. If `test_the_hair_check_sees_a_head_under_the_old_header` fails, Andi's hair now sits below that guard's old header. Report it rather than retuning the guard.
- [ ] **Step 5: Commit.** Message `msg_t3.txt`:

```
fix(lobby): seat the class on the desk's edge, not on the chair

Every seat moves down by the chair back's height (62 px back row, 83 px
front) so each student's body ends on the desk's real back edge, as in
the owner's picture: arms and items rest on the desk top and the body
hides the chair. Sizes, x positions and flips are unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

```bash
git add Scenes/Lobby/Lobby.tscn
```
```bash
git commit -F <scratchpad>/msg_t3.txt
```

### Task 4: Visual verification (owner-facing)

**Files:** none tracked; all images go to the session scratchpad.

- [ ] **Step 1: Before image.** Re-use `lobby_set_pic_1920.png` from the 2026-09-30 session scratchpad (`…/3c29b585-3db3-4d88-81fe-cf342db2ee3d/scratchpad/`) as "before".
- [ ] **Step 2: After at 1080x1920.** `project_run(mode="main", session_id=…)`. Open the debug overlay (F1), then General → **⚡ Seed Playtest State**, then Scenes → Lobby. Capture with `editor_screenshot(source="game", max_resolution=0, session_id=…)`. If the capture is smaller than 1080 wide (the embedded run renders at half size), use the popup-screenshot harness instead: a throwaway `@tool` suite `tests/test_zz_lobby_shots.gd` (add it to `.git/info/exclude`, never commit it). It builds a 1080x1920 `SubViewport`, instances `Lobby.tscn`, sets each `Portrait.texture = load(StudentSkins.layer_path(<name>, StudentSkins.DEFAULT_ID, "portrait"))` and shows only that seat's `Hand_<name>`. It saves the image in a second `test_run` call.
- [ ] **Step 3: After at 1080x2400.** The same harness with a 1080x2400 viewport, or the game window resized to 1080x2400.
- [ ] **Step 4: All six per seat.** Using the harness, render the four seats for each of the six students (6 images, each with the same student in all four seats, or one sheet of 6×4 crops). Check every image: no chair back shows above an arm, and no back-row item runs under a front desk plate or a front student.
- [ ] **Step 5: Side-by-side.** Build the reference-vs-game crop again (reference rows 260-1200, game rows 60-1000, as in the 2026-10-01 chat image) with the after image.
- [ ] **Step 6:** Send the before/after pair (full size), the side-by-side and the all-students sheet to the owner with `SendUserFile`. Stop the game run. Delete the harness suite, rescan, and revert `Assets/Audio/default_bus_layout.tres` and any rewritten `*.png.import`.

### Task 5: Docs

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (new entry at the top of the entries)
- Modify: `docs/superpowers/specs/2026-09-30-lobby-seating-and-planks-design.md` (status line)
- Modify: `docs/superpowers/plans/2026-09-30-lobby-seating-and-planks.md` (above "Desk top surfaces")

- [ ] **Step 1: Changelog entry**, inserted above `## 2026-10-01 — Intro VN polish…`:

```markdown
## 2026-10-01 — Lobby students sit at the desk, not on the chair

Branch `fix/lobby-seat-desk-edge`; spec and plan
`2026-10-01-lobby-seat-on-desk-edge`. Every desk plate carries a chair back
drawn in the desk's own wood, and the 2026-09-30 seating pass (#169)
measured each desk by its wood-colour box, so it anchored every seat on the
chair's top. Students sat one chair-height too high, with arms resting on the
chair. Each seat's portrait and hands slots move down together by the
correction (Slot1 62.045, Slot2 62.0, Slot3 and Slot4 83.0 px), so each body
ends on the desk's real back edge (400.045 / 400.0 / 766). With the chair
left out, the game's desks are the picture's art (156 px deep against 155).
`test_lobby_desk_items_fit` now reads each edge from the plate's pixels
(first row with an opaque run over 260 px) and requires each Portrait to end
on it; `test_lobby_layout`'s front-head pins and `DESK_TOP_ROWS` follow.
```

- [ ] **Step 2: Notes on the 2026-09-30 docs.** In the spec, append to the `**Status:**` line: ` · **Desk edges corrected 2026-10-01:** the "game desk" numbers below were the chair back's top; see 2026-10-01-lobby-seat-on-desk-edge-design.md.` In the plan, insert above `**Desk top surfaces**`: `> **Corrected 2026-10-01:** the game y0 values here (338, 683) are the top of the chair back drawn into each plate; the desks' real back edges are 400.045 / 400.0 / 766 / 766 (2026-10-01-lobby-seat-on-desk-edge).`
- [ ] **Step 3: Commit** (`msg_t5.txt`: `docs(lobby): log the desk-edge seating fix; flag the 2026-09-30 numbers`, plus the trailer):

```bash
git add docs/superpowers/CHANGELOG.md docs/superpowers/specs/2026-09-30-lobby-seating-and-planks-design.md docs/superpowers/plans/2026-09-30-lobby-seating-and-planks.md docs/superpowers/plans/2026-10-01-lobby-seat-on-desk-edge.md docs/superpowers/specs/2026-10-01-lobby-seat-on-desk-edge-design.md
```
```bash
git commit -F <scratchpad>/msg_t5.txt
```

- [ ] **Step 4:** Close the worktree editor (`editor_manage(op="quit")`, or stop its PID after checking its CommandLine). Report the git state: branch, commits ahead of `origin/Textures`, nothing pushed, no PR. Shipping is `ship-pr`, only when the owner says so.
