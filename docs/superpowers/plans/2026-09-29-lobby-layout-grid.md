# Lobby Layout Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Lobby's progress plate into the gap between the two back-row heads, move the coin box into the book's step beside JADWAL!, and put the book HUD back on the 48 px grid.

**Architecture:** Pure layout. One scene (`Scenes/Lobby/Lobby.tscn`) is re-laid out by hand-editing its text **with the worktree editor closed**. Two small script changes follow: `LobbyProgressHeader.WEEK_FORMAT` and `LobbyHud._set_book_live`. The tests are written first and pin every rect, the hair clearance measured from the real art, the spacing and the on-screen margins.

**Tech Stack:** Godot 4.6.2, GDScript, the Godot AI MCP bridge (`test_run`, `project_run`, `editor_screenshot`), `McpTestSuite` suites in `tests/`.

**Spec:** `docs/superpowers/specs/2026-09-29-lobby-layout-grid-design.md`

## Global Constraints

- Work only in the worktree: `C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\lobby-layout-grid` (branch `feat/lobby-layout-grid`). Every path below is relative to that folder. **Never edit the main checkout** (`...\new-game-project\` without `.claude\worktrees\...`). Another session owns it.
- Never add a `theme_override_*`. The only allowed overrides are layout constants (`separation`, `margin_*`). This plan adds none.
- No visual is built at runtime. Every new node is a `[node]` block in `Lobby.tscn`.
- Every script keeps its `##` file header, and every `@export` and new `const` has a `##` line (`tests/test_script_documentation.gd`).
- No test may be a coroutine (no `await`). Suites stay `@tool`.
- Never edit `Scripts/Balance.gd`. No rebake: this plan adds no theme variation.
- Commits: Conventional Commits with a scope, written to a file and committed with `git commit -F <file>`. The message ends with a blank line, then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Git runs as plain single commands (no `cd … &&`, no heredocs).
- Before every commit: `git branch --show-current` must print `feat/lobby-layout-grid`.

## Design-screen numbers (1080×1920) this plan pins

| Node | Rect (x, y, w, h) |
|---|---|
| `ProgressHeader` (the tag) | 420, 48, 232, 184 |
| `DisplayUang` (coin box) | 684, 1444, 348, 112 |
| `IconRail` | 936, 964, 96, 456 (buttons at y 964, 1084, 1204, 1324) |
| `ChevronGrip` | 214, 1352, 280, 96 |
| `Student` / `Jadwal` | 88, 1444, 532, 144 |
| `Koperasi` / `Inventory` / `ReportStudent` | x 88 / 397 / 706, y 1656, 285×160 |

At 1080×2400 the book, coin box and rail sit 480 px lower. The tag stays at the top.

---

### Task 1: Worktree editor and the failing tests

**Files:**
- Modify: `tests/test_lobby_layout.gd` (the header doc lines 12-16 and 32-54, plus new tests at the end of the file)
- Modify: `tests/test_lobby_hud.gd` (the header doc lines 4-5, `test_header_draws_grade_week_and_stars`, `test_the_hud_hides_to_its_peek_and_comes_back`, `_assert_only_the_grip_peeks`, plus two new tests)
- Modify: `tests/test_tall_screen_layout.gd:188-207`

**Interfaces:**
- Consumes: nothing yet.
- Produces: the unique names the scene must provide: `%WeekCaption` (Label), plus the existing `%ProgressHeader`, `%DisplayUang`, `%BookHud`, `%IconRail`, `%RaisedBlock`, `%Shelf`, `%ChevronGrip`, `%GradeNumber`, `%WeekLabel`, `%StarNum`. It also expects `LobbyProgressHeader.WEEK_FORMAT == "%d / %d"` and `STAR_FORMAT` unchanged.

- [ ] **Step 1: Seed and launch a Godot editor on the worktree**

The editor on the MCP bridge belongs to other checkouts, so this worktree needs its own. Copy the main checkout's import cache so it boots without a reimport (skip `.godot/editor/`):

```powershell
$main = "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.godot"
$wt = "C:\Users\user\Downloads\KejarTestAlphaVer2.15\KejarTestAlphaVer2.15\new-game-project\.claude\worktrees\lobby-layout-grid"
New-Item -ItemType Directory -Force "$wt\.godot" | Out-Null
foreach ($p in "imported","shader_cache") { Copy-Item -Recurse -Force "$main\$p" "$wt\.godot\" }
foreach ($f in "uid_cache.bin","global_script_class_cache.cfg","scene_groups_cache.cfg") { Copy-Item -Force "$main\$f" "$wt\.godot\" }
$exe = "C:\Users\user\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "`"$exe`" --path `"$wt`" -e"; CurrentDirectory = $wt }
```

Expected: `ReturnValue 0` and a `ProcessId`. Record the PID. (The outer `Godot_v4.6.2-stable_win64.exe` is a directory.)

Then poll `session_manage(op="list")` until a session whose `project_path` ends in `lobby-layout-grid/` reports `readiness: ready`. Record its `session_id`. **Pass that `session_id` on every godot-ai call from here on, and never call `session_activate`**: other sessions share this server.

- [ ] **Step 2: Rewrite the design rects in `tests/test_lobby_layout.gd`**

Replace lines 32-54 (from `## Where every HUD control sits` through the closing `}` of `DESIGN_RECTS`) with:

```gdscript
## Where every HUD control sits on the 1080x1920 design screen. The
## 2026-09-27 scrapbook pass (Task 4) replaced the flat BottomBar row with a
## stepped book (RaisedPage over Student/Jadwal, ShelfPage over the three
## tiles) plus ChevronGrip and a right-edge IconRail. The 2026-09-29 layout
## grid pass put the book back on Safe's 48 px margin (undoing 60d6d7d7's
## nudge), moved the coin box into the book's step beside JADWAL!, lifted the
## rail to end 24 px above it, and made the progress plate a tag in the gap
## between the two back-row heads.
const DESIGN_RECTS := {
	"Student": Rect2(88, 1444, 532, 144),
	"Jadwal": Rect2(88, 1444, 532, 144),
	"Koperasi": Rect2(88, 1656, 285, 160),
	"Inventory": Rect2(397, 1656, 285, 160),
	"ReportStudent": Rect2(706, 1656, 285, 160),
	"ChevronGrip": Rect2(214, 1352, 280, 96),
	"DisplayUang": Rect2(684, 1444, 348, 112),
	"IconRail": Rect2(936, 964, 96, 456),
	"DailyLogin": Rect2(936, 964, 96, 96),
	"SettingsButton": Rect2(936, 1084, 96, 96),
	"AchievementButton": Rect2(936, 1204, 96, 96),
	"SkinSwitchButton": Rect2(936, 1324, 96, 96),
	"ProgressHeader": Rect2(420, 48, 232, 184),
}
```

In the file's header doc (lines 12-16), append one line after `## screen (tests/layout_frame.gd) and every check reads real global rects.`:

```gdscript
## The 2026-09-29 layout grid pass added the spacing, margin, fit and
## hair-clearance checks at the end of this file.
```

- [ ] **Step 3: Append the new layout tests to `tests/test_lobby_layout.gd`**

Add at the end of the file:

```gdscript
# ── the layout grid (2026-09-29) ───────────────────────────────────────────

## Neighbouring HUD pieces sit at least this far apart, px.
const MIN_GAP := 24.0
## The HUD pieces the spacing rule covers.
const SPACED: Array[String] = ["ProgressHeader", "IconRail", "DisplayUang",
	"RaisedBlock", "Shelf", "ChevronGrip"]
## Pairs drawn overlapping on purpose: the grip caps the raised block, and
## the raised block sits on the shelf.
const AUTHORED_OVERLAPS := [["ChevronGrip", "RaisedBlock"], ["RaisedBlock", "Shelf"]]
## How far, px, the book, the coin box and the rail keep from the screen's
## sides and bottom (Safe's margin).
const EDGE_MARGIN := 48.0
## A 20:9 phone in the 1080-wide space.
const TALL_SCREEN_H := 2400.0
## How far, px, the tag keeps from the nearest back-row hair beyond the
## parallax swing. The owner wants hair clear, not only faces (spec §2).
const HAIR_CLEARANCE := 4.0
## Lobby._animate_breathing's inhale scale, about the rig's bottom centre.
const BREATH_PEAK := Vector2(1.01, 1.02)
## StudentFace.canvas_size: the square every face rig's layers draw on.
const RIG_CANVAS := Vector2(1280, 1280)
## Every nth row and column of the art is checked, to keep the suite fast.
const HAIR_SAMPLE_STEP := 2


## The distance between two rects: negative when they overlap.
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
	var dy := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
	return maxf(dx, dy)


func test_hud_pieces_keep_their_spacing() -> void:
	for i in SPACED.size():
		for j in range(i + 1, SPACED.size()):
			var a: String = SPACED[i]
			var b: String = SPACED[j]
			if [a, b] in AUTHORED_OVERLAPS or [b, a] in AUTHORED_OVERLAPS:
				continue
			var ca := _hud(a)
			var cb := _hud(b)
			if ca == null or cb == null:
				continue
			var gap := _gap(_authored_rect(ca), _authored_rect(cb))
			assert_true(gap >= MIN_GAP - 0.5,
				"%s and %s are %.1f px apart; the grid wants %d" % [a, b, gap, MIN_GAP])


## `lobby`'s book, coin box and rail sit EDGE_MARGIN inside `screen`'s sides
## and bottom.
func _assert_inside_margin(lobby: Control, screen: Vector2) -> void:
	for n: String in ["BookHud", "DisplayUang", "IconRail"]:
		var c := lobby.get_node_or_null("%" + n) as Control
		assert_true(c != null, "lobby is missing %" + n)
		if c == null:
			continue
		var r := c.get_global_rect()
		assert_true(r.position.x >= EDGE_MARGIN - 0.5
				and r.end.x <= screen.x - EDGE_MARGIN + 0.5
				and r.end.y <= screen.y - EDGE_MARGIN + 0.5,
			"%s spans %s on a %s screen; it must sit %d px inside the sides and bottom"
				% [n, str(r), str(screen), EDGE_MARGIN])


func test_the_hud_sits_inside_the_screen_margin() -> void:
	_assert_inside_margin(_lobby, Vector2(SCREEN_W, SCREEN_H))
	var tall_screen := Vector2(SCREEN_W, TALL_SCREEN_H)
	var tall := track(LayoutFrame.stand_up(SCENE, tall_screen)) as Control
	_assert_inside_margin(tall.get_child(0) as Control, tall_screen)


## `c`'s minimum size fits its authored rect. A Control whose minimum size
## outgrows its rect draws past it: the old 88x84 grade badge really drew
## 106 wide.
func _assert_fits_rect(c: Control) -> void:
	if c == null:
		return
	var room := Vector2(c.offset_right - c.offset_left, c.offset_bottom - c.offset_top)
	var need := c.get_combined_minimum_size()
	assert_true(need.x <= room.x + 0.5 and need.y <= room.y + 0.5,
		"%s needs %s but its rect is %s" % [c.name, str(need), str(room)])


func test_the_progress_tag_fits_its_longest_lines() -> void:
	var tag := _hud("ProgressHeader")
	if tag == null:
		return
	(tag.get_node("%GradeNumber") as Label).text = "9"
	(tag.get_node("%WeekLabel") as Label).text = LobbyProgressHeader.WEEK_FORMAT % [8, 8]
	(tag.get_node("%StarNum") as Label).text = LobbyProgressHeader.STAR_FORMAT % [3.0, 3.0]
	for child in tag.get_children():
		_assert_fits_rect(child as Control)


func test_the_largest_balance_fits_the_coin_box() -> void:
	var label := _lobby.get_node_or_null("%DisplayUang/Label") as Label
	assert_true(label != null, "the coin box needs its Label")
	if label == null:
		return
	label.text = "999999G"
	_assert_fits_rect(label)


## The rect no back-row hair may enter: the tag grown by the back seats'
## parallax swing and HAIR_CLEARANCE.
func _tag_keep_out(tag: Control) -> Rect2:
	var parallax := _lobby.get_node("World/Classroom/Parallax")
	var depths := parallax.get("depth_by_child") as Dictionary
	var depth: float = depths.get("StudentPortraitsContainer_Back", 0.0)
	var reach: Vector2 = (parallax.get("travel") as Vector2) * depth \
		+ Vector2.ONE * HAIR_CLEARANCE
	return _authored_rect(tag).grow_individual(reach.x, reach.y, reach.x, reach.y)


## The first on-screen point where `tex`, drawn as a face rig into
## `portrait` (StudentFace.fit_canvas: keep aspect, centred) at rest or at
## its breathing peak, puts an opaque pixel inside `keep_out`; Vector2.INF
## when none does.
func _first_hair_in(keep_out: Rect2, tex: Texture2D, portrait: Rect2) -> Vector2:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var fit := minf(portrait.size.x / RIG_CANVAS.x, portrait.size.y / RIG_CANVAS.y)
	var drawn := RIG_CANVAS * fit
	var origin := portrait.position + (portrait.size - drawn) * 0.5
	var per_pixel := drawn / Vector2(img.get_width(), img.get_height())
	var pivot := Vector2(portrait.get_center().x, portrait.end.y)
	for peak: Vector2 in [Vector2.ONE, BREATH_PEAK]:
		# Only the art pixels that can land in keep_out at this breath.
		var lo := (pivot + (keep_out.position - pivot) / peak - origin) / per_pixel
		var hi := (pivot + (keep_out.end - pivot) / peak - origin) / per_pixel
		var x0 := clampi(floori(lo.x), 0, img.get_width())
		var x1 := clampi(ceili(hi.x) + 1, 0, img.get_width())
		var y0 := clampi(floori(lo.y), 0, img.get_height())
		var y1 := clampi(ceili(hi.y) + 1, 0, img.get_height())
		for y in range(y0, y1, HAIR_SAMPLE_STEP):
			for x in range(x0, x1, HAIR_SAMPLE_STEP):
				if img.get_pixel(x, y).a <= 0.5:
					continue
				var at := pivot + (origin + Vector2(x, y) * per_pixel - pivot) * peak
				if keep_out.has_point(at):
					return at
	return Vector2.INF


## The owner's rule for the tag (spec §2): it clears every back-row student's
## hair and face, for every student and skin, in both back seats, breathing
## and swaying with the parallax.
func test_the_progress_tag_clears_every_back_row_head() -> void:
	var tag := _hud("ProgressHeader")
	if tag == null:
		return
	var keep_out := _tag_keep_out(tag)
	var back := _lobby.get_node("World/Classroom/StudentPortraitsContainer_Back")
	for slot: String in ["Slot1", "Slot2"]:
		var portrait := (back.get_node(slot + "/Portrait") as Control).get_global_rect()
		for student: String in StudentSkins.NAMES:
			for id: String in StudentSkins.skins_for(student):
				var path := StudentSkins.layer_path(student, id, "face_base")
				var tex := load(path) as Texture2D
				assert_true(tex != null, "no face base at " + path)
				if tex == null:
					continue
				var hit := _first_hair_in(keep_out, tex, portrait)
				assert_eq(hit, Vector2.INF,
					"%s (%s) in %s reaches the tag's keep-out %s at %s"
						% [student, id, slot, str(keep_out), str(hit)])
```

- [ ] **Step 4: Update `tests/test_lobby_hud.gd`**

(a) Replace the file doc's first two lines (lines 4-5):

```gdscript
## LobbyProgressHeader and the coin plate (2026-09-27 scrapbook HUD, Task 3):
## the grade/week/star header at Safe/UI's top left and the restyled money
## chip at top right, still wired to DailyLoginPanel's flying reward coin.
```

with:

```gdscript
## LobbyProgressHeader and the coin plate (2026-09-27 scrapbook HUD, Task 3):
## the grade/week/star tag, since the 2026-09-29 layout grid pass in the gap
## between the back-row heads, and the money chip, now in the book's step
## beside JADWAL!, still wired to DailyLoginPanel's flying reward coin.
```

(b) In `test_header_draws_grade_week_and_stars`, after the `WeekLabel` assertion, add:

```gdscript
	assert_eq((header.get_node("%WeekCaption") as Label).text, "Minggu",
		"the word Minggu sits on its own caption above the week")
```

(c) In `test_the_hud_hides_to_its_peek_and_comes_back`, after `assert_false(hud.is_open)`, add:

```gdscript
	var coins := hud.get_node("%DisplayUang") as Control
	assert_eq(coins.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED,
		"the hidden book's + cannot be pressed")
```

and after `assert_true(hud.is_open)`, add:

```gdscript
	assert_eq(coins.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED,
		"the reopened book's + works again")
```

(d) In `_assert_only_the_grip_peeks`, before the `var chip :=` line, add:

```gdscript
	var coins: Rect2 = _drawn_rect(hud.get_node("%DisplayUang") as Control)
	assert_true(coins.position.y >= screen_bottom,
		"%s: the coin box (top %.1f) leaves with the book" % [where, coins.position.y])
```

(e) After `test_the_reward_coin_still_flies_to_the_wallet`, add:

```gdscript
## The 2026-09-29 layout grid pass: the coin box sits in the book's step
## beside JADWAL!, so it rides the swipe with the book.
func test_the_coin_box_rides_in_the_book() -> void:
	var book := _lobby.get_node("%BookHud") as Node
	var coins := _lobby.get_node("%DisplayUang") as Node
	assert_true(book.is_ancestor_of(coins), "DisplayUang rides in BookHud")


## Only the tag idles to a fade: the coin box leaves with the book instead.
func test_only_the_progress_tag_idles_to_a_fade() -> void:
	var fade := _lobby.get_node("IdleFade") as IdleFade
	assert_eq(fade.targets.size(), 1, "one idle-fade target")
	if fade.targets.size() == 1:
		assert_eq(fade.targets[0], _lobby.get_node("%ProgressHeader"),
			"the tag fades; the coins leave with the book")
```

- [ ] **Step 5: Update `tests/test_tall_screen_layout.gd`**

Replace the doc comment and body of `test_lobby_on_a_tall_phone` (lines 188-207, from `## On a 1080x2400 phone` through the `DailyReward` assertion) with:

```gdscript
## On a 1080x2400 phone the classroom sits 240 px down, centred; the book HUD,
## the coin box and the icon rail ride the bottom edge, 480 px below their
## design rects (test_lobby_layout.gd's DESIGN_RECTS, 2026-09-29 layout grid
## pass); the progress tag stays on top; the popup stays centred.
func test_lobby_on_a_tall_phone() -> void:
	var lobby := _stood_up(LOBBY, TALL)
	_assert_placed((lobby.get_node("World/Backdrop") as Control),
		Rect2(0, 0, 1080, 2400), "Backdrop")
	_assert_placed((lobby.get_node("World/Classroom") as Control),
		Rect2(0, 240, 1080, 1920), "Classroom")
	_assert_placed((lobby.get_node("%Jadwal") as Control),
		Rect2(88, 1924, 532, 144), "Jadwal")
	_assert_placed((lobby.get_node("%ReportStudent") as Control),
		Rect2(706, 2136, 285, 160), "ReportStudent")
	_assert_placed((lobby.get_node("%DailyLogin") as Control),
		Rect2(936, 1444, 96, 96), "DailyLogin")
	_assert_placed((lobby.get_node("%DisplayUang") as Control),
		Rect2(684, 1924, 348, 112), "DisplayUang")
	_assert_placed((lobby.get_node("%ProgressHeader") as Control),
		Rect2(420, 48, 232, 184), "ProgressHeader")
	_assert_placed((lobby.get_node("DailyReward") as Control),
		Rect2(80, 798, 942, 418), "DailyReward")
```

Before replacing, read lines 186-210 to confirm the block's exact start and end lines. Keep the next function (`test_lobby_at_the_design_size_is_unchanged`) untouched.

- [ ] **Step 6: Reload the edited suites and run them to see them fail**

The suites were edited from outside the editor, so force a reload. Call `script_patch` once per file with an empty/no-op patch on `res://tests/test_lobby_layout.gd`, `res://tests/test_lobby_hud.gd` and `res://tests/test_tall_screen_layout.gd` (a benign "reload failed with error code 43" may appear). Then:

`test_run(suite="lobby_layout", session_id=<wt>)`, `test_run(suite="lobby_hud", session_id=<wt>)`, `test_run(suite="tall_screen_layout", session_id=<wt>)`

Expected FAILs (the scene is unchanged):
- `lobby_layout`: `test_the_hud_keeps_its_design_rects`, `test_the_hud_sits_inside_the_screen_margin` (the book ends at 1984), `test_the_progress_tag_clears_every_back_row_head`, `test_the_progress_tag_fits_its_longest_lines` (no `%WeekCaption` yet, and the grade badge's minimum outgrows 88×84).
- `lobby_hud`: `test_header_draws_grade_week_and_stars` (no `%WeekCaption`), `test_the_hud_hides_to_its_peek_and_comes_back`, `test_the_coin_box_rides_in_the_book`, `test_only_the_progress_tag_idles_to_a_fade`.
- `tall_screen_layout`: `test_lobby_on_a_tall_phone`.

Anything else failing is a typo in the test code. Fix it before going on. A **parse error** shows as a whole suite "abstract/broken": read it with `logs_read(source="editor", session_id=<wt>)`.

- [ ] **Step 7: Commit the tests**

```text
test(lobby): pin the layout grid, the tag's hair clearance and the coin box

Rects from the 2026-09-29 layout grid spec, plus spacing, screen-margin,
text-fit and hair-clearance checks measured from the face-rig art.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

```powershell
git add tests/test_lobby_layout.gd tests/test_lobby_hud.gd tests/test_tall_screen_layout.gd
git commit -F <message file>
```

---

### Task 2: Re-lay out `Lobby.tscn` (editor closed)

**Files:**
- Modify: `Scenes/Lobby/Lobby.tscn` (blocks at lines 912-968 `DisplayUang`, 969-1066 `ProgressHeader` subtree, 1067-1081 `Hud`, 1257-1272 `IconRail`, 1351 `wallet_anchor`, 1502 `targets`)

**Interfaces:**
- Consumes: Task 1's expected node names and rects.
- Produces: `%DisplayUang` under `Safe/UI/Hud/BookHud`; a new `%WeekCaption` Label (unique_id `1447350126`) under `Safe/UI/ProgressHeader`; `IdleFade.targets == [ProgressHeader]`.

CLAUDE.md § 4 forbids hand-editing a `.tscn` **while the editor is attached**. This task closes the worktree editor first, which also avoids the editor-reparent hazard (memory: editor reparent bakes instance internals).

- [ ] **Step 1: Close the worktree editor**

`editor_manage(op="quit", session_id=<wt>)`. If it times out, confirm the PID's CommandLine contains `lobby-layout-grid` (`Get-CimInstance Win32_Process -Filter "ProcessId=<pid>"`), then `Stop-Process -Id <pid> -Force`. Never stop a Godot process whose CommandLine is another checkout.

- [ ] **Step 2: Un-nudge `%Hud`**

In the `[node name="Hud" …]` block, delete these four lines:

```text
offset_left = -41.0
offset_top = 112.0
offset_right = -41.0
offset_bottom = 112.0
```

- [ ] **Step 3: Lift the rail**

In the `[node name="IconRail" …]` block, change `offset_top = -832.0` to `offset_top = -908.0` and `offset_bottom = -376.0` to `offset_bottom = -452.0`.

- [ ] **Step 4: Move and resize the coin box**

Cut the five blocks `DisplayUang`, `CoinIcon`, `Label`, `PlusUang` and `PlusIcon` (from `[node name="DisplayUang"` through the blank line after `PlusIcon`'s `stretch_mode = 5`). Paste them **immediately before** `[node name="IconRail" type="VBoxContainer" parent="Safe/UI/Hud"`, which is after the `ChevronGlyph` block, so they serialise as `BookHud`'s last child. Rewrite them as:

```text
[node name="DisplayUang" type="Panel" parent="Safe/UI/Hud/BookHud" unique_id=259983175]
unique_name_in_owner = true
layout_mode = 0
offset_left = 636.0
offset_top = 52.0
offset_right = 984.0
offset_bottom = 164.0
mouse_filter = 2
theme_type_variation = &"CoinPlate"

[node name="CoinIcon" type="TextureRect" parent="Safe/UI/Hud/BookHud/DisplayUang" unique_id=1731951124]
layout_mode = 0
offset_left = 20.0
offset_top = 24.0
offset_right = 76.0
offset_bottom = 84.0
mouse_filter = 2
texture = ExtResource("14_dyk4g")
expand_mode = 1
stretch_mode = 5

[node name="Label" type="Label" parent="Safe/UI/Hud/BookHud/DisplayUang" unique_id=664496077]
layout_mode = 0
offset_left = 80.0
offset_top = 24.0
offset_right = 236.0
offset_bottom = 84.0
theme_type_variation = &"CoinLabel"
text = "50"
horizontal_alignment = 2
vertical_alignment = 1

[node name="PlusUang" type="Button" parent="Safe/UI/Hud/BookHud/DisplayUang" unique_id=1462804132]
unique_name_in_owner = true
custom_minimum_size = Vector2(96, 96)
layout_mode = 0
offset_left = 240.0
offset_top = 8.0
offset_right = 336.0
offset_bottom = 104.0
theme_type_variation = &"PlusButton"
icon_alignment = 1
expand_icon = true

[node name="PlusIcon" type="TextureRect" parent="Safe/UI/Hud/BookHud/DisplayUang/PlusUang" unique_id=2008619712]
layout_mode = 0
offset_left = 24.0
offset_top = 20.0
offset_right = 72.0
offset_bottom = 68.0
mouse_filter = 2
texture = ExtResource("37_ty8k5")
expand_mode = 1
stretch_mode = 5

```

(BookHud's origin is x 48, y 1392 on the design screen, so local 636, 52 gives 684, 1444.)

- [ ] **Step 5: Re-lay out the tag**

Replace everything from `[node name="ProgressHeader" type="Panel" parent="Safe/UI"` up to (not including) `[node name="Hud" type="Control"` with:

```text
[node name="ProgressHeader" type="Panel" parent="Safe/UI" unique_id=923979542]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -120.0
offset_right = 112.0
offset_bottom = 184.0
grow_horizontal = 2
mouse_filter = 2
theme_type_variation = &"ProgressPlate"
script = ExtResource("38_ayldy")

[node name="GradeBadge" type="PanelContainer" parent="Safe/UI/ProgressHeader" unique_id=1892516588]
layout_mode = 0
offset_left = 10.0
offset_top = 10.0
offset_right = 116.0
offset_bottom = 129.0
mouse_filter = 2
theme_type_variation = &"GradeBadge"

[node name="Stack" type="VBoxContainer" parent="Safe/UI/ProgressHeader/GradeBadge" unique_id=1808440301]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 0
alignment = 1

[node name="GradeCaption" type="Label" parent="Safe/UI/ProgressHeader/GradeBadge/Stack" unique_id=196617970]
layout_mode = 2
theme_type_variation = &"GradeBadgeLabel"
text = "KELAS"
horizontal_alignment = 1

[node name="GradeNumber" type="Label" parent="Safe/UI/ProgressHeader/GradeBadge/Stack" unique_id=341293909]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"GradeBadgeNumber"
text = "7"
horizontal_alignment = 1

[node name="WeekCaption" type="Label" parent="Safe/UI/ProgressHeader" unique_id=1447350126]
unique_name_in_owner = true
layout_mode = 0
offset_left = 124.0
offset_top = 24.0
offset_right = 222.0
offset_bottom = 54.0
theme_type_variation = &"CaptionLabel"
text = "Minggu"
horizontal_alignment = 1
vertical_alignment = 1

[node name="WeekLabel" type="Label" parent="Safe/UI/ProgressHeader" unique_id=1839783328]
unique_name_in_owner = true
layout_mode = 0
offset_left = 124.0
offset_top = 58.0
offset_right = 222.0
offset_bottom = 108.0
theme_type_variation = &"WeekLabel"
text = "1 / 6"
horizontal_alignment = 1
vertical_alignment = 1

[node name="StarBar" type="ProgressBar" parent="Safe/UI/ProgressHeader" unique_id=555781510]
unique_name_in_owner = true
layout_mode = 0
offset_left = 10.0
offset_top = 143.0
offset_right = 83.0
offset_bottom = 167.0
mouse_filter = 2
theme_type_variation = &"StarProgressBar"
max_value = 3.0
show_percentage = false

[node name="TipSparkle" type="CPUParticles2D" parent="Safe/UI/ProgressHeader/StarBar" unique_id=1791549137]
unique_name_in_owner = true
position = Vector2(0, 12)
emitting = false
amount = 12
texture = ExtResource("39_nese6")
lifetime = 0.6
one_shot = true
explosiveness = 0.9
spread = 180.0
gravity = Vector2(0, 0)
initial_velocity_min = 40.0
initial_velocity_max = 90.0
scale_amount_min = 0.3
scale_amount_max = 0.6

[node name="StarIcon" type="TextureRect" parent="Safe/UI/ProgressHeader" unique_id=1236434420]
layout_mode = 0
offset_left = 89.0
offset_top = 139.0
offset_right = 119.0
offset_bottom = 169.0
mouse_filter = 2
texture = ExtResource("40_2xndu")
expand_mode = 1
stretch_mode = 5

[node name="StarNum" type="Label" parent="Safe/UI/ProgressHeader" unique_id=865703870]
unique_name_in_owner = true
layout_mode = 0
offset_left = 123.0
offset_top = 137.0
offset_right = 222.0
offset_bottom = 173.0
theme_type_variation = &"StarNumLabel"
text = "0.0 / 3.0"
vertical_alignment = 1

```

Before saving, confirm `1447350126` appears nowhere else in the file (`grep -c "unique_id=1447350126" Scenes/Lobby/Lobby.tscn` prints `1`).

- [ ] **Step 6: Rewire the wallet and the idle fade**

Change:

```text
wallet_anchor = NodePath("../Safe/UI/DisplayUang")
```

to:

```text
wallet_anchor = NodePath("../Safe/UI/Hud/BookHud/DisplayUang")
```

and:

```text
targets = [NodePath("../Safe/UI/ProgressHeader"), NodePath("../Safe/UI/DisplayUang")]
```

to:

```text
targets = [NodePath("../Safe/UI/ProgressHeader")]
```

- [ ] **Step 7: Check the text**

```bash
grep -n 'parent="Safe/UI/DisplayUang' Scenes/Lobby/Lobby.tscn
grep -c 'Safe/UI/Hud/BookHud/DisplayUang' Scenes/Lobby/Lobby.tscn
git diff --stat
```

Expected: the first prints nothing. The second prints `5`: four child `parent=` paths (CoinIcon, Label, PlusUang, and PlusIcon's `…/DisplayUang/PlusUang`) plus the `wallet_anchor` line. `DisplayUang`'s own block says `parent="Safe/UI/Hud/BookHud"`, which does not match. Only `Scenes/Lobby/Lobby.tscn` has changed.

Do not commit yet: Task 3's scripts must land before the suites pass.

---

### Task 3: Scripts, then prove it green

**Files:**
- Modify: `Scripts/Lobby/LobbyProgressHeader.gd:5-13`
- Modify: `Scripts/Lobby/LobbyHud.gd` (the `@onready` block around line 81-96, and `_set_book_live` around line 268-277)
- Modify: `Scripts/UI/IdleFade.gd:5-13` (doc comments only)

**Interfaces:**
- Consumes: Task 2's `%DisplayUang` under `%BookHud` and `%WeekCaption`.
- Produces: `LobbyProgressHeader.WEEK_FORMAT == "%d / %d"`, and `LobbyHud.coin_box: Control` (= `%DisplayUang`).

The editor is still closed, so plain file edits are safe here.

- [ ] **Step 1: `LobbyProgressHeader.gd`**

Replace the file doc lines:

```gdscript
## The Lobby's top-left progress plate (2026-09-27 scrapbook HUD spec §3.1):
## the grade badge, "Minggu N / total" and the run's star bar toward
## Balance.STARS_TOTAL.
```

with:

```gdscript
## The Lobby's progress tag (2026-09-27 scrapbook HUD spec §3.1), since the
## 2026-09-29 layout grid pass a narrow tag in the gap between the two
## back-row heads: the grade badge, the week "N / total" under a static
## "Minggu" caption in the scene, and the run's star bar toward
## Balance.STARS_TOTAL.
```

Keep the rest of that doc paragraph (`Reads GameState only when…`) as it is. Replace:

```gdscript
## The week line: the week, then the grade's length.
const WEEK_FORMAT := "Minggu %d / %d"
```

with:

```gdscript
## The week line under the tag's static "Minggu" caption: the week, then the
## grade's length. "Minggu 1 / 6" on one line (264 px) cannot fit the tag.
const WEEK_FORMAT := "%d / %d"
```

- [ ] **Step 2: `LobbyHud.gd`**

Read lines 1-20 and 78-100 first. After `@onready var report_student: Control = %ReportStudent`, add:

```gdscript
@onready var coin_box: Control = %DisplayUang
```

Replace `_set_book_live` and its doc comment:

```gdscript
## Hidden, the book's buttons ignore input, so nothing under a reopening
## tap or a mid-slide press opens a screen; the chevron, a sibling of the
## book's pages, stays live to bring it back.
func _set_book_live(live: bool) -> void:
	var behavior: Control.MouseBehaviorRecursive = Control.MOUSE_BEHAVIOR_INHERITED
	if not live:
		behavior = Control.MOUSE_BEHAVIOR_DISABLED
	for part: Control in [raised_page, koperasi, inventory, report_student]:
		part.mouse_behavior_recursive = behavior
```

with:

```gdscript
## Hidden, the book's buttons ignore input, so nothing under a reopening
## tap or a mid-slide press opens a screen; the coin box's + rides in the
## book's step (2026-09-29) and goes quiet with it. The chevron, a sibling of
## the book's pages, stays live to bring it back.
func _set_book_live(live: bool) -> void:
	var behavior: Control.MouseBehaviorRecursive = Control.MOUSE_BEHAVIOR_INHERITED
	if not live:
		behavior = Control.MOUSE_BEHAVIOR_DISABLED
	for part: Control in [raised_page, koperasi, inventory, report_student, coin_box]:
		part.mouse_behavior_recursive = behavior
```

If the file's header doc lists what rides in the book, add the coin box to it in one clause.

- [ ] **Step 3: `IdleFade.gd` doc comments**

Replace `## HUD spec §3, "Idle fade"). The Lobby uses it for its header and coin` and the following `## plate; nothing else fades.` with:

```gdscript
## HUD spec §3, "Idle fade"). The Lobby uses it for its progress tag only
## (the coin box rides the book since 2026-09-29); nothing else fades.
```

and `## What fades: the Lobby wires its header and coin plate here.` with:

```gdscript
## What fades: the Lobby wires its progress tag here.
```

Read lines 1-15 first and keep the paragraph's line breaks tidy.

- [ ] **Step 4: Relaunch the worktree editor**

Run Task 1 Step 1's `Invoke-CimMethod` line again (the cache is already seeded). Poll `session_manage(op="list")` for the new `lobby-layout-grid` session id (it changes on every launch). A fresh launch loads every script from disk, so no no-op `script_patch` is needed. Read `logs_read(source="editor", session_id=<wt>)` once and confirm there are no parse errors and no "Node not found" errors for `Lobby.tscn`.

- [ ] **Step 5: Run the Lobby suites**

`test_run` with `session_id=<wt>`, one suite at a time: `lobby_layout`, `lobby_hud`, `tall_screen_layout`, `lobby`, `lobby_skins`, `lobby_tile_icons`, `button_geometry`, `shorten`, `achievement_screen`, `ui_icon_refresh`, `viewport_editability`, `script_documentation`, `clean_code`, `popup_frames`, `daily_login_panel`.

Expected: all PASS. If `test_run` returns a `scene_warning` asking for a scene, open `Scenes/MainMenu/MainMenu.tscn` (`scene_open`, `session_id=<wt>`) and re-run.

If a check fails:
- **`test_the_progress_tag_fits_its_longest_lines`**: the message names the child and its real minimum size. Enlarge that child's rect within the tag and shift its neighbours, keeping the tag at 232×184. If it cannot fit, **stop and report** the measured sizes. Do not widen the tag: its width is set by the hair gap.
- **`test_the_largest_balance_fits_the_coin_box`**: move `CoinIcon` to `offset_left = 12.0`, `offset_right = 64.0` and `Label` to `offset_left = 68.0` (editor closed, then relaunch), and re-run.
- **`test_the_progress_tag_clears_every_back_row_head`**: **stop and report** the hit point. The spec's Python measurement put the closest hair 1.3 px outside the keep-out, so a hit means the fit maths or the rects differ from the spec.

Any scene fix follows the same routine: quit the editor, edit, relaunch.

- [ ] **Step 6: Check nothing else moved**

```bash
git status --short
git diff --stat
```

Expected changes: `Scenes/Lobby/Lobby.tscn`, `Scripts/Lobby/LobbyProgressHeader.gd`, `Scripts/Lobby/LobbyHud.gd` and `Scripts/UI/IdleFade.gd`. The editor boot may also rewrite `Assets/Audio/default_bus_layout.tres` and some `*.png.import` files. Do not stage those: revert them with `git checkout -- <path>`, the `.import` files only once the editor has exited (Task 4 Step 4).

- [ ] **Step 7: Commit**

```text
feat(lobby): fit the progress tag between the heads, coins beside JADWAL

The grade/week/star plate becomes a 232x184 tag in the gap between the
back-row heads, clear of every student's hair and face. The coin box
moves into the book's step and rides the HUD swipe, the rail ends 24 px
above it, and the book returns to the 48 px grid (undoing 60d6d7d7).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

```powershell
git add Scenes/Lobby/Lobby.tscn Scripts/Lobby/LobbyProgressHeader.gd Scripts/Lobby/LobbyHud.gd Scripts/UI/IdleFade.gd
git commit -F <message file>
```

---

### Task 4: See it in the running game

**Files:** none (screenshots go to the scratchpad).

- [ ] **Step 1: Run and seed**

`project_run(mode="main", session_id=<wt>)`. Open the debug overlay first. Per the memory note, the teleport toggles the overlay, and an overlay you did not open eats the tap. Then use General → **⚡ Seed Playtest State** and Scenes → **Lobby**.

- [ ] **Step 2: Capture at full size**

`editor_screenshot(source="game", max_resolution=0, session_id=<wt>)`. The embedded run renders at half size, so judge placement by these rects, and measure pixels rather than eyeballing 1 px detail. Check:
- the tag sits between the two back-row heads and touches no hair;
- the coin box sits in the step beside JADWAL!, lined up under the rail;
- the book is whole, with margins on both sides and at the bottom;
- `999999G` fits.

- [ ] **Step 3: Swipe**

Tap the chevron grip. The book, the coin box and the rail slide away together, and the tag stays. Double-tap to bring them back. Take one screenshot of the hidden state.

- [ ] **Step 4: Stop and clean up**

`project_manage(op="stop", session_id=<wt>)`. Revert `Assets/Audio/default_bus_layout.tres` if it changed. Once the editor has exited (Task 5 closes it), revert any `*.png.import` rewrites.

- [ ] **Step 5: Show the owner**

Send the two screenshots with `SendUserFile`, captioned "Lobby layout grid: HUD open / HUD swiped away".

---

### Task 5: Changelog, full run, ship

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (a new entry at the top, under the intro)

- [ ] **Step 1: Changelog entry**

Insert above the first `## 2026-09-29 —` heading:

```markdown
## 2026-09-29 — Lobby layout grid

The owner asked for spacing and for the Minggu plate off the students' faces.
The progress plate is now a 232x184 tag in the gap between the two back-row
heads. It clears every student's hair and face, in every skin, breathing and at
full parallax tilt; the art was measured, and `test_lobby_layout` checks it
pixel by pixel. `Minggu` moved to its own caption (`WEEK_FORMAT` is `"%d / %d"`),
because the one-line week is 264 px wide. The coin box moved into the book's
step beside JADWAL! and rides the HUD swipe; only the tag idle-fades now. The
book is back on the 48 px grid (`60d6d7d7`'s nudge had clipped the nav tiles),
and the rail ends 24 px above the coin box. Spec:
`specs/2026-09-29-lobby-layout-grid-design.md`.
```

Commit it (`docs(lobby): log the layout grid pass`).

- [ ] **Step 2: Full run**

Restart the worktree editor first: quit it, check the PID, relaunch with the Task 1 Step 1 command, and re-list for the new id. Then run `test_run(session_id=<wt>)` with no suite. The bridge usually drops after a full run. The results are still valid if the reply arrived. Expected: every suite passes. A lone theme assertion failing can be suite ordering (CLAUDE.md § Testing): re-run that suite alone before believing it.

After the run: `git status --short`. Revert `Assets/Theme/kejartes_theme.tres` if the `theme_rebake` suite rewrote it (this plan changes no tokens, so any diff is noise), and revert `Assets/Audio/default_bus_layout.tres` too. Then close the editor (checked PID) and revert any `*.png.import` rewrites.

- [ ] **Step 3: Ship**

Invoke the `ship-pr` skill from the worktree. Right after `gh pr create`, bind the PR with `bind_pr` and `set_monitor` (memory: bind the PR before stamping).

- [ ] **Step 4: After merge**

Remove the worktree (the owner's standing rule). If the seeded `.godot` cache hits Windows' path limit, `git worktree remove` fails with "Filename too long". In that case, delete the folder with `Remove-Item -LiteralPath "\\?\<full path>" -Recurse -Force` and then run `git worktree prune`.
