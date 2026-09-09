# Win Screen Lineup & StatCheck Rush Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `EndCutscene` win branch's placeholder CG with the run's own approved roster posed on the new `win_background` art with ground shadows, and make `StatCheck` tappable so a touch rushes the current student's reveal.

**Architecture:** Two independent parts sharing only the end-of-grade sequence. Part A adds a letterboxed art-space `Stage` to `EndCutscene.tscn` holding the backdrop, a `Shadows` layer and a `Students` layer, with slot assignment factored into a new `WinLineup.gd` of plain static functions. Part B makes every awaited beat in `StatCheck._run_check()` a `Tween` held in a member, so a tap can rush it by speed-scaling rather than killing.

**Tech Stack:** Godot 4.6, GDScript, `McpTestSuiteCompat` test suites run in-editor via the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-09-win-screen-lineup-design.md`

## Global Constraints

- **Godot 4.6**, mobile renderer, portrait 1080×1920 design space.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only layout-only constant overrides (`separation`, `margin_*`) are exempt.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`; repeated rows are a `PackedScene` template. `tests/test_viewport_editability.gd` holds a frozen `BASELINE` that may only be lowered.
- **Every script needs a `##` file header, and every `@export` a `##` line.** Enforced by `tests/test_script_documentation.gd`.
- **Test suites must be `@tool`** or the runner reports them abstract/broken.
- **No test may be a coroutine.** The runner does `suite.call(name)` without awaiting; an `await` silently aborts the test and reports "0 assertions".
- **Suites extend `McpTestSuiteCompat`** (`tests/mcp_test_suite_compat.gd`), not `McpTestSuite` — that shim restores `assert_not_null()`.
- Available asserts: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_gt`, `assert_has_key`, `assert_contains`, `assert_not_null`. There is **no** `assert_lt` — write `assert_true(a < b, "…")`.
- **UI text is Indonesian**; engine and systems code is English.
- **No emoji as UI iconography.** Real transparent SVG/PNG textures only.
- **`Balance.gd` is collaborator-owned.** Read freely, never edit.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through MCP: `scene_open` → `node_create` / `node_set_property` → `scene_save`.
- **Do scene work first, script work second.** `scene_save` flushes stale editor script buffers over whatever you patched. After any `scene_save`, check `git diff HEAD -- '*.gd'` for files you were not editing.
- **Rescan after editing a `.gd`, before running tests**, or `test_run` serves stale bytecode. If the file was written from outside the editor, a no-op `script_patch` on it forces the reload.
- Commits: Conventional Commits with a scope, e.g. `feat(endgame): …`.

---

# Part A — Win screen roster lineup

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/EndGame/WinLineup.gd` *(create)* | Pure static functions: slot maps per roster size, Doni-first fill order, per-character foot anchors. No nodes, no scene. |
| `Scenes/EndGame/EndCutscene.tscn` *(modify)* | Gains `Stage` (Backdrop + Shadows + Students), reordered so `BlurLayer` sits above `Stage`. `BtnNext` moves into the bottom letterbox bar. |
| `Scripts/EndGame/EndCutscene.gd` *(modify)* | Fits the stage, dresses the slots from `WinLineup.assign()`, skips the badge slam on the win path. |
| `Assets/Images/CG/Win/*.png` *(create)* | Background + six splashes. |
| `Assets/Images/UI/Placeholders/shadow_ellipse.png` *(create)* | Shared soft ellipse. |
| `tests/test_win_lineup.gd` *(create)* | Behavioural tests for the static functions. |
| `tests/test_end_cutscene.gd` *(modify)* | Structural tests for the new nodes and draw order. |

---

### Task A1: Import the art

**Files:**
- Create: `Assets/Images/CG/Win/win_background.png`, `win_andi.png`, `win_citra.png`, `win_doni.png`, `win_marcel.png`, `win_shinta.png`, `win_thea.png`
- Create: `Assets/Images/UI/Placeholders/shadow_ellipse.png`
- Test: `tests/test_win_lineup.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: seven texture paths under `res://Assets/Images/CG/Win/`, and `res://Assets/Images/UI/Placeholders/shadow_ellipse.png`. Every later task loads these by path.

- [ ] **Step 1: Copy the seven source files, renaming Sinta**

Note `win_sinta.png` → `win_shinta.png`. The roster spells her `Shinta` everywhere (`student_card.gd:991`, `splash_shinta.png`); the Downloads spelling is the odd one out.

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
mkdir -p Assets/Images/CG/Win
cp ~/Downloads/win_background.png Assets/Images/CG/Win/
for n in andi citra doni marcel thea; do cp ~/Downloads/win_$n.png Assets/Images/CG/Win/; done
cp ~/Downloads/win_sinta.png Assets/Images/CG/Win/win_shinta.png
ls Assets/Images/CG/Win/
```

- [ ] **Step 2: Generate the shadow ellipse placeholder**

A 512×256 soft radial ellipse, white so it can be tinted, alpha falling from centre to edge on a smoothstep. Generated, not hand-authored — it goes on the debt list in Task A8.

```powershell
Add-Type -AssemblyName System.Drawing
$w=512; $h=256
$bmp=New-Object System.Drawing.Bitmap($w,$h,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for($y=0;$y -lt $h;$y++){
  for($x=0;$x -lt $w;$x++){
    $dx=($x-($w/2.0))/($w/2.0); $dy=($y-($h/2.0))/($h/2.0)
    $d=[math]::Sqrt($dx*$dx+$dy*$dy)
    $t=1.0-[math]::Min(1.0,$d)
    $a=[int](255*$t*$t*(3.0-2.0*$t))
    $bmp.SetPixel($x,$y,[System.Drawing.Color]::FromArgb($a,255,255,255))
  }
}
$bmp.Save("Assets/Images/UI/Placeholders/shadow_ellipse.png",[System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
```

- [ ] **Step 3: Import them into Godot**

The editor generates `.import` sidecars on scan. Use the MCP tool, not a shell command:

```
filesystem_manage(op="scan")
```

- [ ] **Step 4: Write the failing test**

Create `tests/test_win_lineup.gd` with just the asset test for now:

```gdscript
@tool
extends McpTestSuiteCompat

## WinLineup (2026-09-09): the win screen's roster arrangement. Doni is
## pinned to the front slot; everyone else fills in roster order. Plain
## static functions over Dictionaries, so these are behavioural tests
## rather than the source scans this project falls back on for scenes it
## cannot instantiate headlessly.

const _SCRIPT := "res://Scripts/EndGame/WinLineup.gd"

const _SPLASHES := ["andi", "citra", "doni", "marcel", "shinta", "thea"]


func suite_name() -> String:
	return "win_lineup"


func test_the_win_art_imported() -> void:
	var bg := "res://Assets/Images/CG/Win/win_background.png"
	assert_true(ResourceLoader.exists(bg), bg + " exists")
	assert_true(load(bg) is Texture2D, bg + " imports as a texture")
	for n in _SPLASHES:
		var p := "res://Assets/Images/CG/Win/win_%s.png" % n
		assert_true(ResourceLoader.exists(p), p + " exists")
		assert_true(load(p) is Texture2D, p + " imports as a texture")


func test_the_shadow_ellipse_imported_and_is_soft() -> void:
	var p := "res://Assets/Images/UI/Placeholders/shadow_ellipse.png"
	assert_true(ResourceLoader.exists(p), p + " exists")
	var tex: Texture2D = ResourceLoader.load(
		p, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	var img: Image = tex.get_image()
	assert_not_null(img, "the ellipse rasterised")
	# Opaque at the centre, clear at the corner, and genuinely soft in
	# between -- a hard-edged ellipse would read as a sticker, not a shadow.
	var w := img.get_width()
	var h := img.get_height()
	assert_gt(img.get_pixel(w / 2, h / 2).a, 0.9, "solid at the centre")
	assert_true(img.get_pixel(2, 2).a < 0.05, "clear at the corner")
	var mid := img.get_pixel(int(w * 0.75), h / 2).a
	assert_true(mid > 0.05 and mid < 0.9,
		"partially transparent partway out (got %f) -- the falloff is a gradient" % mid)
```

- [ ] **Step 5: Run it to verify it passes**

```
test_run(suite="win_lineup")
```

Expected: 2 tests PASS. If the assets are missing it fails on `ResourceLoader.exists`; re-run the scan.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/CG/Win Assets/Images/UI/Placeholders/shadow_ellipse.png tests/test_win_lineup.gd
git commit -m "feat(endgame): import the win screen art and a shadow placeholder"
```

---

### Task A2: WinLineup — foot anchors

**Files:**
- Create: `Scripts/EndGame/WinLineup.gd`
- Test: `tests/test_win_lineup.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `WinLineup.FOOT_ANCHORS: Dictionary` — roster name (`"Doni"`, `"Shinta"`, …) → `{"centre_x": float, "span": float}` in the splash's own 1080² canvas space. Task A4 reads it.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_win_lineup.gd`:

```gdscript
const _ROSTER := ["Marcel", "Doni", "Andi", "Citra", "Shinta", "Thea"]


func test_every_roster_name_has_a_foot_anchor() -> void:
	for name in _ROSTER:
		assert_has_key(WinLineup.FOOT_ANCHORS, name,
			name + " has a measured foot anchor")
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_has_key(a, "centre_x", name + ".centre_x")
		assert_has_key(a, "span", name + ".span")


## The anchors are measured from the splash alpha at threshold 128 -- see
## the spec's section 5. These pin the measurement so a re-export that
## silently moves a figure is caught here rather than on screen.
func test_the_anchors_match_the_measured_art() -> void:
	var expected := {
		"Doni": [587.0, 597.0],
		"Andi": [488.0, 390.0],
		"Citra": [530.0, 352.0],
		"Shinta": [526.0, 186.0],
		"Marcel": [480.0, 116.0],
		"Thea": [546.0, 100.0],
	}
	for name in expected:
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_true(is_equal_approx(a["centre_x"], expected[name][0]),
			"%s centre_x is %f, expected %f" % [name, a["centre_x"], expected[name][0]])
		assert_true(is_equal_approx(a["span"], expected[name][1]),
			"%s span is %f, expected %f" % [name, a["span"], expected[name][1]])


## Marcel leans on one foot and Thea is mid-stride, so their contact bands
## are far narrower than their bodies. A shadow that narrow reads as a
## smudge, so both carry an explicit widening factor.
func test_the_narrow_contact_poses_are_widened() -> void:
	for name in ["Marcel", "Thea"]:
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_gt(a.get("widen", 1.0), 1.0,
			name + " is one-footed and widens toward the body")
	for name in ["Doni", "Andi", "Citra", "Shinta"]:
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_true(is_equal_approx(a.get("widen", 1.0), 1.0),
			name + " stands on two feet and is not widened")
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="win_lineup")
```

Expected: FAIL — `WinLineup` is an unknown identifier, the suite will not even parse.

- [ ] **Step 3: Write the implementation**

Create `Scripts/EndGame/WinLineup.gd`:

```gdscript
class_name WinLineup
extends RefCounted

## The win screen's roster arrangement (2026-09-09). EndCutscene shows the
## run's own approved students posed on win_background; this file decides
## who stands where, and where each one's ground shadow goes.
##
## Plain static functions over Dictionaries, no nodes, which is why
## tests/test_win_lineup.gd can test it behaviourally rather than by source
## scan the way a scene script has to be tested. Same shape as
## Scripts/Debug/EndGameRehearsal.gd.
##
## Coordinates are in the backdrop's own 1536x2048 art space, except
## FOOT_ANCHORS, which is in each splash's own 1080x1080 canvas space.
## EndCutscene.gd converts. Full derivation:
## docs/superpowers/specs/2026-09-09-win-screen-lineup-design.md

## The one fixed rule: Doni is always the front figure.
const PINNED_FRONT := "Doni"

## Slot ids, front to back. Draw order follows this array reversed, so
## FRONT_LOW ends up on top.
const SLOT_FRONT_LOW := "front_low"
const SLOT_FRONT_MID := "front_mid"
const SLOT_SIDE_LEFT := "side_left"
const SLOT_SIDE_RIGHT := "side_right"

## Where each figure's feet meet the floor, measured from its splash's
## alpha at threshold 128 -- the low threshold used for a bounding box
## reports a shared baseline whether or not one exists, because every PNG
## carries stray near-transparent pixels to the canvas edge.
##
## `centre_x` and `span` are the midpoint and width of the contact band
## (the 40 rows above the baseline). `widen` multiplies the shadow for
## poses whose contact band is far narrower than the body: Marcel leans on
## one foot, Thea is mid-stride, and an unwidened shadow under either
## reads as a smudge rather than as contact.
const FOOT_ANCHORS := {
	"Doni": {"centre_x": 587.0, "span": 597.0},
	"Andi": {"centre_x": 488.0, "span": 390.0},
	"Citra": {"centre_x": 530.0, "span": 352.0},
	"Shinta": {"centre_x": 526.0, "span": 186.0},
	"Marcel": {"centre_x": 480.0, "span": 116.0, "widen": 2.0},
	"Thea": {"centre_x": 546.0, "span": 100.0, "widen": 2.0},
}
```

- [ ] **Step 4: Rescan, then run the tests**

The file was written from outside the editor, so a plain scan can still serve old bytecode. Scan first; if the suite still reports `WinLineup` unknown, force a reload with a no-op `script_patch` (add and remove a blank line) — it logs a benign `GDScript reload failed with error code 43` and then works.

```
filesystem_manage(op="scan")
test_run(suite="win_lineup")
```

Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/WinLineup.gd tests/test_win_lineup.gd
git commit -m "feat(endgame): add WinLineup with the measured foot anchors"
```

---

### Task A3: WinLineup — slot maps and fill order

**Files:**
- Modify: `Scripts/EndGame/WinLineup.gd`
- Test: `tests/test_win_lineup.gd`

**Interfaces:**
- Consumes: `WinLineup.FOOT_ANCHORS`, `SLOT_*` consts, `PINNED_FRONT` from Task A2.
- Produces:
  - `WinLineup.slots_for(count: int) -> Array[String]` — slot ids, back to front, for a roster of that size.
  - `WinLineup.assign(names: Array) -> Array[Dictionary]` — one entry per student, each `{"name": String, "slot": String, "anchor": Vector2, "scale": float}`. `anchor` is the bottom-centre of the splash in art space; `scale` multiplies the 1080² canvas. Task A5 consumes this.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_win_lineup.gd`:

```gdscript
func test_slot_counts_track_the_roster_size() -> void:
	# Grades 7/8/9 approve 2/3/4 students -- student_card.gd:99-102.
	assert_eq(WinLineup.slots_for(2).size(), 2, "grade 7 roster")
	assert_eq(WinLineup.slots_for(3).size(), 3, "grade 8 roster")
	assert_eq(WinLineup.slots_for(4).size(), 4, "grade 9 roster")


func test_every_arrangement_includes_the_front_slot() -> void:
	for n in [2, 3, 4]:
		assert_contains(WinLineup.slots_for(n), WinLineup.SLOT_FRONT_LOW,
			"a roster of %d still has a front figure" % n)


func test_doni_takes_the_front_slot_at_every_roster_size() -> void:
	var rosters := [
		["Andi", "Doni"],
		["Andi", "Citra", "Doni"],
		["Marcel", "Doni", "Andi", "Citra"],
	]
	for roster in rosters:
		for placed in WinLineup.assign(roster):
			if placed["name"] == "Doni":
				assert_eq(placed["slot"], WinLineup.SLOT_FRONT_LOW,
					"Doni is pinned front in a roster of %d" % roster.size())


func test_everyone_else_fills_in_roster_order() -> void:
	# Doni is second in roster order but takes the front slot, so Marcel,
	# Andi and Citra fill the remaining three in the order they appear.
	var placed := WinLineup.assign(["Marcel", "Doni", "Andi", "Citra"])
	var by_name := {}
	for p in placed:
		by_name[p["name"]] = p["slot"]
	var remaining := WinLineup.slots_for(4).duplicate()
	remaining.erase(WinLineup.SLOT_FRONT_LOW)
	assert_eq(by_name["Marcel"], remaining[0], "first non-Doni takes the first free slot")
	assert_eq(by_name["Andi"], remaining[1], "second non-Doni takes the second")
	assert_eq(by_name["Citra"], remaining[2], "third non-Doni takes the third")


func test_a_roster_without_doni_still_fills_the_front() -> void:
	var placed := WinLineup.assign(["Marcel", "Andi", "Citra"])
	var front := ""
	for p in placed:
		if p["slot"] == WinLineup.SLOT_FRONT_LOW:
			front = p["name"]
	assert_eq(front, "Marcel",
		"with Doni absent the front goes to the first student in roster order")


func test_no_two_students_share_a_slot() -> void:
	for roster in [["Andi", "Doni"], ["Andi", "Citra", "Doni"],
			["Marcel", "Doni", "Andi", "Citra"]]:
		var placed := WinLineup.assign(roster)
		assert_eq(placed.size(), roster.size(),
			"every student is placed in a roster of %d" % roster.size())
		var seen := {}
		for p in placed:
			assert_false(seen.has(p["slot"]),
				"%s is used once in a roster of %d" % [p["slot"], roster.size()])
			seen[p["slot"]] = true


func test_a_roster_larger_than_the_slot_map_is_truncated() -> void:
	# Nothing produces five approvals today, but the screen must not throw
	# if the cap ever moves -- it shows the first four and drops the rest.
	var placed := WinLineup.assign(["Marcel", "Doni", "Andi", "Citra", "Thea"])
	assert_eq(placed.size(), 4, "at most four figures fit the composition")


func test_an_empty_roster_places_nobody() -> void:
	assert_eq(WinLineup.assign([]).size(), 0, "no students, no placements")


func test_every_placement_carries_an_anchor_and_a_scale() -> void:
	for p in WinLineup.assign(["Marcel", "Doni", "Andi", "Citra"]):
		assert_true(p["anchor"] is Vector2, p["name"] + " has a Vector2 anchor")
		assert_gt(p["scale"], 0.0, p["name"] + " has a positive scale")
		# Art space is 1536x2048; the group sits in the lower half.
		assert_true(p["anchor"].x > 0.0 and p["anchor"].x < 1536.0,
			"%s anchors inside the canvas horizontally" % p["name"])
		assert_true(p["anchor"].y > 1024.0 and p["anchor"].y <= 2048.0,
			"%s stands in the lower half of the painting" % p["name"])
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="win_lineup")
```

Expected: FAIL — `slots_for` and `assign` are not defined.

- [ ] **Step 3: Write the implementation**

Append to `Scripts/EndGame/WinLineup.gd`:

```gdscript
## Art-space geometry per slot: where the splash's bottom-centre lands in
## the backdrop's 1536x2048 space, and what the 1080x1080 canvas scales by.
##
## Seeded from mockup_winscreen.png -- the four figures there occupy
## x 244-1386, y 818-1797 -- and tuned by eye in the editor. These are the
## only estimated numbers in this file; everything else is measured.
const SLOT_GEOMETRY := {
	SLOT_FRONT_LOW: {"anchor": Vector2(700.0, 1810.0), "scale": 0.95},
	SLOT_FRONT_MID: {"anchor": Vector2(940.0, 1770.0), "scale": 0.90},
	SLOT_SIDE_LEFT: {"anchor": Vector2(470.0, 1660.0), "scale": 0.86},
	SLOT_SIDE_RIGHT: {"anchor": Vector2(1210.0, 1680.0), "scale": 0.86},
}

## Which slots a roster of `count` uses, ordered BACK TO FRONT so a caller
## can add nodes in array order and get the right z-order for free.
##
## Each size is arranged rather than derived: a 2-student shot that simply
## left the side slots empty would read as a gappy 4-figure composition
## instead of a deliberate 2-figure one.
const ARRANGEMENTS := {
	2: [SLOT_SIDE_LEFT, SLOT_FRONT_LOW],
	3: [SLOT_SIDE_LEFT, SLOT_FRONT_MID, SLOT_FRONT_LOW],
	4: [SLOT_SIDE_LEFT, SLOT_SIDE_RIGHT, SLOT_FRONT_MID, SLOT_FRONT_LOW],
}

## How many figures the composition holds.
const MAX_FIGURES := 4


## The slots a roster of `count` uses, back to front. Counts outside 2-4
## clamp into range: 0 and 1 borrow the 2-figure arrangement's tail, and
## anything above MAX_FIGURES is truncated by assign().
static func slots_for(count: int) -> Array[String]:
	var n := clampi(count, 1, MAX_FIGURES)
	if ARRANGEMENTS.has(n):
		var out: Array[String] = []
		out.assign(ARRANGEMENTS[n])
		return out
	# n == 1: the front figure alone.
	return [SLOT_FRONT_LOW]


## Place `names` into slots. Doni takes the front whenever he is approved;
## everyone else fills the remaining slots in roster order. Deterministic,
## so the arrangement can be asserted in tests and screenshotted without
## surprise.
##
## Returns one Dictionary per placed student:
##   {"name": String, "slot": String, "anchor": Vector2, "scale": float}
## `anchor` is the splash's bottom-centre in art space; `scale` multiplies
## its 1080x1080 canvas. Extra students beyond MAX_FIGURES are dropped.
static func assign(names: Array) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	if names.is_empty():
		return placed

	var roster: Array = names.slice(0, MAX_FIGURES)
	var slots := slots_for(roster.size())

	# Front first, so the pinned student is resolved before anyone else
	# can take the slot. The rest keep roster order.
	var front_name: String = PINNED_FRONT if roster.has(PINNED_FRONT) else roster[0]
	var rest: Array = []
	for n in roster:
		if n != front_name:
			rest.append(n)

	var free_slots: Array = slots.duplicate()
	free_slots.erase(SLOT_FRONT_LOW)

	placed.append(_place(front_name, SLOT_FRONT_LOW))
	for i in range(rest.size()):
		if i >= free_slots.size():
			break
		placed.append(_place(rest[i], free_slots[i]))
	return placed


static func _place(name: String, slot: String) -> Dictionary:
	var g: Dictionary = SLOT_GEOMETRY[slot]
	return {
		"name": name,
		"slot": slot,
		"anchor": g["anchor"],
		"scale": g["scale"],
	}
```

- [ ] **Step 4: Rescan and run the tests**

```
filesystem_manage(op="scan")
test_run(suite="win_lineup")
```

Expected: all 14 tests PASS.

Note `slots_for()` returns back-to-front, so `slots_for(4)` is `[side_left, side_right, front_mid, front_low]`. `test_everyone_else_fills_in_roster_order` erases `front_low` and expects Marcel/Andi/Citra in `[side_left, side_right, front_mid]` order — matching `assign()`'s own `free_slots`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/WinLineup.gd tests/test_win_lineup.gd
git commit -m "feat(endgame): add the win screen slot maps and Doni-first fill order"
```

---

### Task A4: WinLineup — shadow geometry

**Files:**
- Modify: `Scripts/EndGame/WinLineup.gd`
- Test: `tests/test_win_lineup.gd`

**Interfaces:**
- Consumes: `FOOT_ANCHORS`, `SLOT_GEOMETRY`, `assign()` from Tasks A2–A3.
- Produces: `WinLineup.shadow_for(placed: Dictionary, spread: float, flatness: float) -> Dictionary` returning `{"centre": Vector2, "size": Vector2}` in art space. Task A5 consumes it.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_win_lineup.gd`:

```gdscript
func _placed(name: String) -> Dictionary:
	for p in WinLineup.assign(["Marcel", "Doni", "Andi", "Citra"]):
		if p["name"] == name:
			return p
	return {}


func test_a_shadow_sits_at_its_students_feet() -> void:
	var doni := _placed("Doni")
	var sh := WinLineup.shadow_for(doni, 1.25, 0.28)
	# The splash's feet are on its canvas bottom, so the shadow's centre
	# sits on the anchor's own y -- not above or below it.
	assert_true(is_equal_approx(sh["centre"].y, doni["anchor"].y),
		"the shadow is on the ground line, not floating (%f vs %f)"
			% [sh["centre"].y, doni["anchor"].y])


func test_a_shadow_follows_its_students_foot_centre_not_the_canvas_centre() -> void:
	# Marcel's contact band centres at 480, 60px left of the 540 canvas
	# centre. A shadow that ignored that would sit visibly off his foot.
	var marcel := _placed("Marcel")
	var sh := WinLineup.shadow_for(marcel, 1.25, 0.28)
	var offset: float = (480.0 - 540.0) * marcel["scale"]
	assert_true(is_equal_approx(sh["centre"].x, marcel["anchor"].x + offset),
		"the shadow tracks the measured foot centre")


func test_shadow_width_scales_with_the_foot_span() -> void:
	# Doni's 597px crouch against Shinta's 186px stance: the shadows must
	# differ by roughly the same factor, or one of them reads wrong.
	var doni := WinLineup.shadow_for(_placed("Doni"), 1.25, 0.28)
	var citra := WinLineup.shadow_for(_placed("Citra"), 1.25, 0.28)
	assert_gt(doni["size"].x, citra["size"].x,
		"the wide crouch throws the wider shadow")


func test_the_narrow_poses_are_widened_by_their_factor() -> void:
	var marcel := _placed("Marcel")
	# Explicitly typed: indexing a Dictionary yields a Variant, so ":=" has
	# nothing to infer from and GDScript rejects it at parse time.
	var plain: float = 116.0 * 1.25 * float(marcel["scale"])
	var sh := WinLineup.shadow_for(marcel, 1.25, 0.28)
	assert_true(is_equal_approx(sh["size"].x, plain * 2.0),
		"Marcel's one-footed contact is widened toward his body")


func test_flatness_sets_the_ellipse_height() -> void:
	var sh := WinLineup.shadow_for(_placed("Doni"), 1.25, 0.28)
	assert_true(is_equal_approx(sh["size"].y, sh["size"].x * 0.28),
		"height is flatness x width")


func test_spread_widens_every_shadow() -> void:
	var narrow := WinLineup.shadow_for(_placed("Andi"), 1.0, 0.28)
	var wide := WinLineup.shadow_for(_placed("Andi"), 2.0, 0.28)
	assert_true(is_equal_approx(wide["size"].x, narrow["size"].x * 2.0),
		"spread multiplies the width")


func test_an_unknown_name_still_returns_a_usable_shadow() -> void:
	# A roster name with no measured anchor must not crash the end-of-grade
	# sequence -- it falls back to the canvas centre and a nominal span.
	var sh := WinLineup.shadow_for(
		{"name": "Nobody", "slot": WinLineup.SLOT_FRONT_LOW,
		"anchor": Vector2(700.0, 1810.0), "scale": 1.0}, 1.25, 0.28)
	assert_gt(sh["size"].x, 0.0, "a fallback shadow still has a width")
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="win_lineup")
```

Expected: FAIL — `shadow_for` is not defined.

- [ ] **Step 3: Write the implementation**

Append to `Scripts/EndGame/WinLineup.gd`:

```gdscript
## Half of a splash canvas, in its own space. A figure's horizontal offset
## from its anchor is measured from here.
const CANVAS_HALF := 540.0

## Foot span assumed for a name with no measured anchor. Roughly a
## two-footed stance, so an unmeasured student gets a plausible shadow
## instead of none.
const FALLBACK_SPAN := 300.0


## Where a placed student's ground shadow goes, in art space.
##
## `spread` multiplies the measured foot span and `flatness` sets the
## ellipse's height as a fraction of its width -- both are EndCutscene
## exports, so the shadows can be art-directed without touching the
## measured numbers in FOOT_ANCHORS.
##
## Returns {"centre": Vector2, "size": Vector2}.
static func shadow_for(placed: Dictionary, spread: float,
		flatness: float) -> Dictionary:
	var scale: float = placed["scale"]
	var anchor: Vector2 = placed["anchor"]
	var a: Dictionary = FOOT_ANCHORS.get(placed["name"], {})

	var centre_x: float = a.get("centre_x", CANVAS_HALF)
	var span: float = a.get("span", FALLBACK_SPAN)
	var widen: float = a.get("widen", 1.0)

	var width: float = span * widen * spread * scale
	return {
		# The splash is anchored bottom-CENTRE, so the foot centre's offset
		# from the canvas midline is what displaces the shadow.
		"centre": Vector2(anchor.x + (centre_x - CANVAS_HALF) * scale, anchor.y),
		"size": Vector2(width, width * flatness),
	}
```

- [ ] **Step 4: Rescan and run the tests**

```
filesystem_manage(op="scan")
test_run(suite="win_lineup")
```

Expected: all 21 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/WinLineup.gd tests/test_win_lineup.gd
git commit -m "feat(endgame): derive win screen shadow geometry from the foot anchors"
```

---

### Task A5: Build the Stage in EndCutscene.tscn

**Files:**
- Modify: `Scenes/EndGame/EndCutscene.tscn`
- Test: `tests/test_end_cutscene.gd`

**Interfaces:**
- Consumes: the texture paths from Task A1.
- Produces: node paths `Stage`, `Stage/Backdrop`, `Stage/Shadows`, `Stage/Students`, and eight children `Stage/Shadows/Shadow1..4`, `Stage/Students/Student1..4`. Task A6's script wires them by these exact names.

**Scene work comes before script work in this plan on purpose** — `scene_save` flushes the editor's stale script buffers over anything patched first.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_end_cutscene.gd`:

```gdscript
func test_the_scene_carries_an_art_space_stage() -> void:
	var s := _scene()
	var stage := s.get_node_or_null("Stage")
	assert_true(stage is Control, "Stage holds the painting and its figures")
	assert_true(stage.get_node_or_null("Backdrop") is TextureRect,
		"the backdrop moved under Stage")
	assert_true(stage.get_node_or_null("Shadows") is Control, "the Shadows layer")
	assert_true(stage.get_node_or_null("Students") is Control, "the Students layer")


## All shadows are drawn before all figures, rather than pairing each
## shadow with its own sprite. Pairing would let Doni's wide crouch-shadow
## smear across the side students' shoes.
func test_shadows_draw_beneath_every_student() -> void:
	var stage := _scene().get_node("Stage")
	var shadows: int = stage.get_node("Shadows").get_index()
	var students: int = stage.get_node("Students").get_index()
	var backdrop: int = stage.get_node("Backdrop").get_index()
	assert_true(backdrop < shadows, "the backdrop is behind the shadows")
	assert_true(shadows < students, "every shadow is behind every figure")


func test_the_stage_has_four_authored_slots_and_four_shadows() -> void:
	var stage := _scene().get_node("Stage")
	for i in range(1, 5):
		assert_true(stage.get_node_or_null("Students/Student%d" % i) is TextureRect,
			"Student%d is authored in the scene, not built at runtime" % i)
		assert_true(stage.get_node_or_null("Shadows/Shadow%d" % i) is TextureRect,
			"Shadow%d is authored in the scene, not built at runtime" % i)


## The exit blur samples what is already drawn, so it must sit above the
## whole Stage -- otherwise the painting softens on the way to RunResult
## while the students stay sharp.
func test_the_blur_layer_draws_above_the_stage() -> void:
	var s := _scene()
	assert_true(s.get_node("Stage").get_index() < s.get_node("BlurLayer").get_index(),
		"BlurLayer is above Stage, so the students blur out with the backdrop")


func test_the_next_button_sits_in_the_bottom_letterbox_bar() -> void:
	# The 1536x2048 art letterboxes to 1080x1440 inside 1080x1920, leaving
	# 240px bars. The button belongs in the bottom bar, clear of the art.
	var btn: Button = _scene().get_node("BtnNext")
	assert_gt(btn.offset_top, 1680.0, "the button clears the bottom of the art")
	assert_true(btn.offset_bottom <= 1920.0, "and stays on screen")
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="end_cutscene")
```

Expected: FAIL — no `Stage` node.

- [ ] **Step 3: Build the nodes through the editor**

Never hand-edit the `.tscn`; the attached editor's in-memory copy wins and the next `scene_save` silently overwrites text edits.

```
scene_open(path="res://Scenes/EndGame/EndCutscene.tscn")
```

Then, with `batch_execute` (plugin command names: `create_node`, `set_property`, `move_node`, `delete_node`):

1. `create_node` `Stage` of type `Control` under `.`.
2. `move_node` `Stage` to index 0, so it sits below `BlurLayer`.
3. `set_property` on `Stage`: `mouse_filter = 2` (ignore — nothing here is interactive).
4. `create_node` `Backdrop2` of type `TextureRect` under `Stage`; set `texture` to `res://Assets/Images/CG/Win/win_background.png`, `expand_mode = 1`, `stretch_mode = 0`, `mouse_filter = 2`, `offset_right = 1536`, `offset_bottom = 2048`.
5. `delete_node` the old root-level `Backdrop`, then rename `Backdrop2` to `Backdrop`. A node's *type* and parent cannot be changed in place — delete-and-recreate is the only route.
6. `create_node` `Shadows` (`Control`) under `Stage`, then `Students` (`Control`) under `Stage`. `node_create` appends last, so creating Shadows before Students gives the required order for free.
7. Under `Shadows`, create `Shadow1`..`Shadow4` as `TextureRect`, each with `texture = res://Assets/Images/UI/Placeholders/shadow_ellipse.png`, `expand_mode = 1`, `stretch_mode = 0`, `mouse_filter = 2`, `visible = false`.
8. Under `Students`, create `Student1`..`Student4` as `TextureRect`, each with `expand_mode = 1`, `stretch_mode = 0`, `mouse_filter = 2`, `visible = false`. Leave `texture` unset — Task A6 assigns it per run.
9. `set_property` on `BtnNext`: `offset_top = 1730`, `offset_bottom = 1870`.

Remember: numbers must be unquoted (`1`, not `"1.0"`), and `anchors_preset` is inert — set the four anchors individually if you need them.

- [ ] **Step 4: Save the scene, then check for collateral damage**

```
scene_save()
```

```bash
git diff HEAD -- '*.gd'
```

Expected: **empty**. If it lists scripts you were not editing, the editor flushed a stale buffer over them — restore those files from HEAD before continuing.

- [ ] **Step 5: Repair the two existing tests that reference the old Backdrop path**

Moving `Backdrop` under `Stage` breaks two tests in `tests/test_end_cutscene.gd`, and **one of them fails silently** — fix both in this commit.

`test_scene_has_the_chrome:65` asserts a root-level `Backdrop`. Point it at the new path:

```gdscript
	assert_true(s.get_node_or_null("Stage/Backdrop") is TextureRect, "Backdrop")
```

`test_the_blur_layer_blurs_the_backdrop_but_not_the_badge_or_button:222` is the dangerous one. It scans the **root's** children for `"Backdrop"`; once the node moves, `order.find("Backdrop")` returns `-1`, and `-1 < blur_at` is trivially true — the assertion keeps passing while testing nothing. Replace the backdrop lookup with the stage, which is what the blur must now sit above:

```gdscript
	var stage_at := order.find("Stage")
	var blur_at := order.find("BlurLayer")
	var badge_at := order.find("Badge")
	var btn_at := order.find("BtnNext")
	assert_gt(stage_at, -1, "Stage is a direct child of the root")
	assert_true(stage_at < blur_at,
		"Stage draws first, so the shader samples the painting and its figures")
	assert_true(blur_at < badge_at and blur_at < btn_at,
		"Badge and BtnNext draw after the blur, so they stay sharp")
```

The trailing `WhiteFade`-is-last assertion still holds — `BarFill` goes in at index 0 in Task A7, and `WhiteFade` stays at the end.

- [ ] **Step 6: Run the tests**

```
test_run(suite="end_cutscene")
```

Expected: the five new tests PASS and both repaired tests PASS.

Sanity-check the repair rather than trusting a green run: an assertion that passes because its subject went missing looks identical to one that passes correctly. `assert_gt(stage_at, -1, …)` is what makes the difference visible.

- [ ] **Step 7: Commit**

```bash
git add Scenes/EndGame/EndCutscene.tscn tests/test_end_cutscene.gd
git commit -m "feat(endgame): add the win screen stage, shadow and student layers"
```

---

### Task A6: Fit the stage and dress the slots

**Files:**
- Modify: `Scripts/EndGame/EndCutscene.gd`
- Test: `tests/test_end_cutscene.gd`

**Interfaces:**
- Consumes: `WinLineup.assign()`, `WinLineup.shadow_for()` (A3, A4); the node paths from A5.
- Produces: `EndCutscene.ART_SIZE`, `_fit_stage()`, `_dress_lineup()`, and the exports `win_splashes`, `bar_color`, `shadow_opacity`, `shadow_spread`, `shadow_flatness`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_end_cutscene.gd`:

```gdscript
func test_the_stage_fits_by_computed_scale_not_a_hardcoded_transform() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _fit_stage()"), "the stage is fitted by script")
	assert_true(src.contains("minf("), "it fits by the smaller of the two ratios")
	assert_false(src.contains("0.703125"),
		"the letterbox scale is derived from the viewport, not pasted in")


func test_the_lineup_comes_from_win_lineup() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("WinLineup.assign("),
		"slot assignment lives in WinLineup, not here")
	assert_true(src.contains("WinLineup.shadow_for("),
		"so does shadow geometry")


func test_the_win_path_skips_the_badge() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("if failed:"),
		"the badge slam is behind the lose branch")
	# The chalkboard already reads "Selamat Kelulusan"; a LULUS stamp over
	# it is redundant and covers the art.
	assert_true(src.contains("_slam_badge()"), "the lose path still stamps")


func test_the_shadow_knobs_are_exported() -> void:
	var s := _scene()
	for prop in ["shadow_opacity", "shadow_spread", "shadow_flatness",
			"bar_color", "win_splashes"]:
		assert_true(prop in s, prop + " is tunable in the Inspector")


func test_every_roster_name_has_a_splash_wired() -> void:
	var s := _scene()
	for name in ["Doni", "Andi", "Citra", "Shinta", "Marcel", "Thea"]:
		assert_has_key(s.win_splashes, name, name + " has a win splash")
		assert_true(s.win_splashes[name] is Texture2D, name + "'s splash is a texture")
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="end_cutscene")
```

Expected: FAIL — `_fit_stage` is not in the source, `shadow_opacity` is not a property.

- [ ] **Step 3: Add the exports and the stage fit**

Patch `Scripts/EndGame/EndCutscene.gd` with `script_patch` (editing through the editor avoids the stale-buffer problem entirely).

After the existing `@export_group("Lose")` block, add:

```gdscript
@export_group("Win lineup")
## Splash art per roster name -- "Doni", "Andi", "Citra", "Shinta",
## "Marcel", "Thea". A name with no entry leaves its slot hidden.
@export var win_splashes: Dictionary = {}
## Fills the letterbox bars above and below the painting. Defaults to the
## surface_overlay token so the bars read as the game's own chrome rather
## than as a video letterbox.
@export var bar_color: Color = Color("141a2e")
## Texture every ground shadow wears. Drop-replacement point for real art.
@export var shadow_texture: Texture2D
## Alpha of every ground shadow, 0-1.
@export var shadow_opacity: float = 0.28
## Multiplies each student's measured foot span to get its shadow width.
@export var shadow_spread: float = 1.25
## Ellipse height as a fraction of its width. Lower reads as a flatter
## floor, higher as a softer pool.
@export var shadow_flatness: float = 0.28
```

Add the node references beside the existing `@onready` block:

```gdscript
@onready var stage: Control = $Stage
@onready var shadows: Control = $Stage/Shadows
@onready var students: Control = $Stage/Students
```

And the art-space constant, beside `RUN_RESULT_SCENE`:

```gdscript
## The backdrop's native size. Students are positioned in this space and
## the whole Stage is scaled into the viewport, so numbers measured off
## the mockup transfer 1:1 and the composition never drifts from the art.
const ART_SIZE := Vector2(1536.0, 2048.0)
```

Then the fit itself:

```gdscript
## Letterbox the painting into the viewport: scale by the smaller ratio so
## the whole 3:4 image survives on a 9:16 screen, and centre it. At
## 1080x1920 this gives 1080x1440 with 240px bars top and bottom -- which
## is where BtnNext sits, clear of the art.
func _fit_stage() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / ART_SIZE.x, vp.y / ART_SIZE.y)
	stage.size = ART_SIZE
	stage.scale = Vector2(s, s)
	stage.position = (vp - ART_SIZE * s) * 0.5
```

- [ ] **Step 4: Add the lineup dressing**

```gdscript
## Put the run's own roster on the stage. Called only on the win path --
## the lose branch keeps its CG and its stamp.
##
## Slots and shadows are authored nodes; this only sets texture, size,
## position and visibility on them. Nothing is constructed here.
func _dress_lineup() -> void:
	var names: Array = []
	for s in GameState.approved_students:
		names.append(s.get("name", ""))

	var placed := WinLineup.assign(names)
	for i in range(4):
		var sprite: TextureRect = students.get_node("Student%d" % (i + 1))
		var shadow: TextureRect = shadows.get_node("Shadow%d" % (i + 1))
		if i >= placed.size():
			sprite.hide()
			shadow.hide()
			continue

		var p: Dictionary = placed[i]
		var tex: Texture2D = win_splashes.get(p["name"])
		if tex == null:
			push_warning("EndCutscene: no win splash for '%s'" % p["name"])
			sprite.hide()
			shadow.hide()
			continue

		# The splash is anchored bottom-centre: its canvas is square, so
		# half its scaled width sits either side of the anchor and its
		# full scaled height sits above it.
		var side: float = tex.get_width() * p["scale"]
		sprite.texture = tex
		sprite.size = Vector2(side, side)
		sprite.position = p["anchor"] - Vector2(side * 0.5, side)
		sprite.show()

		var sh := WinLineup.shadow_for(p, shadow_spread, shadow_flatness)
		shadow.texture = shadow_texture
		shadow.size = sh["size"]
		shadow.position = sh["centre"] - sh["size"] * 0.5
		shadow.modulate = Color(0.0, 0.0, 0.0, shadow_opacity)
		shadow.show()
```

- [ ] **Step 5: Branch the verdict**

Replace `_dress_for_verdict()` with:

```gdscript
## Reads the verdict once and dresses the screen for it. StatCheck decided
## it; this screen is only the reveal.
##
## The two paths diverge more than they used to. Lose keeps the CG and the
## stamp. Win puts the roster on the new backdrop and shows no badge --
## the chalkboard already reads "Selamat Kelulusan", so a LULUS stamp over
## it would be redundant and would cover the art.
func _dress_for_verdict() -> void:
	var failed: bool = GameState.run_failed
	backdrop.texture = lose_backdrop if failed else win_backdrop
	badge.texture = lose_badge if failed else win_badge
	stage.visible = not failed
	if not failed:
		_fit_stage()
		_dress_lineup()
	AudioDirector.play_bgm(lose_bgm if failed else win_bgm)
```

And in `_play()`, guard the slam so the win path goes straight to the button:

```gdscript
	if GameState.run_failed:
		_slam_badge()
		await get_tree().create_timer(button_delay_seconds).timeout
		if not is_inside_tree():
			return
```

- [ ] **Step 6: Wire the exports in the Inspector**

`scene_open` the scene and `node_set_property` on the root: set `win_backdrop` to `res://Assets/Images/CG/Win/win_background.png`, `shadow_texture` to the ellipse, and `win_splashes` to the six-entry dictionary keyed by roster name. Then `scene_save`, and check `git diff HEAD -- '*.gd'` is empty again.

- [ ] **Step 7: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="end_cutscene")
test_run(suite="win_lineup")
```

Expected: both suites fully PASS.

- [ ] **Step 8: Commit**

```bash
git add Scripts/EndGame/EndCutscene.gd Scenes/EndGame/EndCutscene.tscn tests/test_end_cutscene.gd
git commit -m "feat(endgame): put the approved roster on the win screen with ground shadows"
```

---

### Task A7: Paint the letterbox bars and verify on screen

**Files:**
- Modify: `Scenes/EndGame/EndCutscene.tscn`, `Scripts/EndGame/EndCutscene.gd`
- Test: `tests/test_end_cutscene.gd`

**Interfaces:**
- Consumes: `bar_color` (A6), `Stage` (A5).
- Produces: node `BarFill` behind `Stage`. This is the last Part A task; nothing consumes it.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_the_letterbox_bars_are_painted() -> void:
	var s := _scene()
	var bars := s.get_node_or_null("BarFill")
	assert_true(bars is ColorRect, "a ColorRect fills the letterbox bars")
	assert_true(bars.get_index() < s.get_node("Stage").get_index(),
		"the bars are behind the painting")
	assert_true(bars.color.a > 0.9, "the bars are opaque -- nothing shows through")
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="end_cutscene")
```

Expected: FAIL — no `BarFill`.

- [ ] **Step 3: Add the node and drive it from the export**

Through the editor: `create_node` `BarFill` (`ColorRect`) under `.`, `move_node` it to index 0 so it sits behind `Stage`, set `anchor_right = 1`, `anchor_bottom = 1`, `mouse_filter = 2`, `color = Color("141a2e")`. Then `scene_save` and check `git diff HEAD -- '*.gd'`.

In `_ready()`, before the `Engine.is_editor_hint()` guard, add:

```gdscript
	# Authored at the token's value too, but re-asserted so changing the
	# export is enough -- the bars and the export must not drift apart.
	$BarFill.color = bar_color
```

- [ ] **Step 4: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="end_cutscene")
```

Expected: PASS.

- [ ] **Step 5: Look at it, and tune the four slot anchors**

This is the one hand-tuning step in Part A. `SLOT_GEOMETRY` in `WinLineup.gd` holds estimates seeded from the mockup.

Seed a run and teleport rather than playing to reach the screen:

1. `project_run()`.
2. In the running game, open the debug overlay (F1, or five taps in the top-right corner).
3. General tab → **⚡ Seed Playtest State**.
4. Scenes tab → **🎭 Gladi Resik Akhir Kelas** → *Semua Lulus*, which arms the win path with a fixed four-student roster.
5. `editor_screenshot()` once the win screen is up.

Compare against `~/Downloads/mockup_winscreen.png` and adjust the four `anchor`/`scale` pairs. Re-run `test_run(suite="win_lineup")` after each change — `test_every_placement_carries_an_anchor_and_a_scale` keeps the numbers inside the canvas.

When you are done, use **↩ Pulihkan Run Sebelum Gladi Resik** to restore the run. RunResult's progression otherwise advances the grade and clears the roster on its way out.

- [ ] **Step 6: Run the full suite**

```
test_run()
```

Expected: every suite green. Investigate any failure before committing — `test_viewport_editability` in particular, since Part A adds nodes.

- [ ] **Step 7: Commit**

```bash
git add Scenes/EndGame/EndCutscene.tscn Scripts/EndGame/EndCutscene.gd Scripts/EndGame/WinLineup.gd tests/test_end_cutscene.gd
git commit -m "feat(endgame): paint the win screen letterbox bars and tune the slot anchors"
```

---

### Task A8: Update the project docs

**Files:**
- Modify: `CLAUDE.md`, `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Add the changelog entry**

Newest first, at the top of `docs/superpowers/CHANGELOG.md`. Cover: the roster lineup, the letterbox, `WinLineup.gd`, the shadows, the dropped win badge, and the `shadow_ellipse.png` placeholder.

- [ ] **Step 2: Fix the stale backdrop line in CLAUDE.md**

`CLAUDE.md:355` claims the win backdrop is `cg2.jpg`; the scene actually referenced `cg_win.jpg`, and now references `win_background.png`. Under **End cutscene art**, drop the win-backdrop and win-badge clauses and keep the lose backdrop and both stamps.

- [ ] **Step 3: Add the new placeholder to the debt list**

Under **Outstanding debt & placeholders**:

```markdown
**Win screen shadow (2026-09-09).** `Assets/Images/UI/Placeholders/shadow_ellipse.png`
is a generated radial-gradient ellipse (PowerShell + `System.Drawing`), not
hand-authored art. Every ground shadow on the win screen wears it, tinted
and scaled per student. Transparent PNG, drop-replaceable.
```

- [ ] **Step 4: Note the dead scene**

`Scenes/EndGame/WinScreen.tscn` has no script, is referenced by nothing and still points at `cg0.jpg`. It is *not* the win screen. Add a line to the debt list so the next reader does not edit the wrong file:

```markdown
**Dead scene.** `Scenes/EndGame/WinScreen.tscn` is orphaned scaffolding --
no script, no references, still on `cg0.jpg`. The real win screen is
`EndCutscene`'s win branch. Safe to delete.
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/superpowers/CHANGELOG.md
git commit -m "docs(endgame): record the win screen pass and its placeholder"
```

---

# Part B — StatCheck tap-to-rush

Independent of Part A. Can land before or after it.

## File Structure

| File | Responsibility |
|---|---|
| `Scripts/EndGame/StatCheckRow.gd` *(modify)* | Keeps its fill tween so it can be rushed. |
| `Scripts/EndGame/StarMeter.gd` *(modify)* | Exposes a rush on its existing tracked tween. |
| `Scripts/EndGame/StatCheck.gd` *(modify)* | Holds the live tween, catches input, scopes the rush to one student. |
| `tests/test_stat_check.gd` *(modify)* | Behavioural and source-scan tests. |

**The load-bearing detail:** `Tween.kill()` does **not** emit `finished`. Killing a tween the sequence is awaiting leaves the `await` pending forever and deadlocks the screen. `set_speed_scale()` finishes it within a frame *and* still emits, so every completion path downstream — `cleared`, the full-bar `pop()`, the `filled` signal, the star credit — runs exactly as it does today.

---

### Task B1: Make a row rushable

**Files:**
- Modify: `Scripts/EndGame/StatCheckRow.gd`
- Test: `tests/test_stat_check.gd`

**Interfaces:**
- Consumes: `Juice.fill_bar(bar: Range, to: float, duration: float = -1.0, delay: float = 0.0) -> Tween`.
- Produces: `StatCheckRow.RUSH_SPEED: float`, `StatCheckRow.rush() -> void`. Task B3 calls `rush()`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_stat_check.gd`:

```gdscript
## A rush must SPEED UP the live tween, never kill it. Tween.kill() does
## not emit finished, so killing the tween StatCheck is awaiting would hang
## the sequence forever -- the screen would sit on a half-filled bar with
## no way forward. This is a source scan because the alternative is a
## coroutine, and no test here may await.
func test_row_rush_speeds_the_tween_rather_than_killing_it() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("func rush() -> void:"), "a row can be rushed")
	assert_true(src.contains("set_speed_scale("),
		"the rush speed-scales the live tween")
	assert_false(src.contains(".kill()"),
		"it must never kill the tween -- kill() does not emit finished, " +
		"so the pending await would never resume")


func test_row_keeps_its_fill_tween_so_it_can_be_rushed() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("_fill_tween"),
		"the fill tween is held on the row, not a local")
	assert_true(src.contains("const RUSH_SPEED"),
		"the rush multiplier is a named const, not an inline literal")


## rush() must be safe before anything is in flight -- a tap during the
## card's slide-in reaches it with no fill tween yet. It should leave the
## row exactly as set_result() armed it, not quietly complete the fill.
func test_rushing_an_idle_row_leaves_it_armed_but_unmoved() -> void:
	var row = load(_ROW_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	row.set_result(45.0, 60.0)
	row.rush()
	assert_true(is_equal_approx(row.get_node("Bar").value, 0.0),
		"rushing before fill() started does not move the bar")
	assert_true(is_equal_approx(row.target_ratio, 75.0), "the armed ratio survives")
	assert_false(row.cleared, "and the row is not marked cleared")
	Engine.get_main_loop().root.remove_child(row)
```

Follow the established pattern in this file: instantiate, `add_child` to `Engine.get_main_loop().root` so `@onready` vars resolve, `track()`, then `remove_child` at the end — see `test_row_set_result_arms_the_target_without_animating:55`.

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="stat_check")
```

Expected: FAIL — no `rush()`, and `test_rushing_an_idle_row_is_harmless` errors on the missing method.

- [ ] **Step 3: Implement**

Patch `Scripts/EndGame/StatCheckRow.gd` with `script_patch`.

Add beside the other consts:

```gdscript
## Speed multiplier a rush applies to the live fill. Large enough to land
## within a frame; the tween still emits `finished`, which is the whole
## point -- see rush().
const RUSH_SPEED := 1000.0
```

Add beside `var cleared`:

```gdscript
## The in-flight fill(), held so rush() can reach it.
var _fill_tween: Tween = null
```

Replace `fill()`:

```gdscript
## The beat. A coroutine -- StatCheck awaits it row by row; never call it
## from a test (the MCP runner does not await).
func fill() -> void:
	# Juice.fill_bar returns null for a dead node; awaiting .finished on
	# that is a hard null-deref, so refuse rather than crash.
	_fill_tween = Juice.fill_bar(bar, target_ratio, fill_seconds)
	if _fill_tween == null:
		return
	await _fill_tween.finished
	_fill_tween = null
	if not is_inside_tree():
		return
	if target_ratio >= 100.0:
		cleared = true
		pop()
	filled.emit(cleared)
```

And add:

```gdscript
## Finish the in-flight fill immediately, keeping every consequence.
##
## Speed-scales rather than kills on purpose: Tween.kill() does not emit
## `finished`, so killing the tween StatCheck is awaiting would leave that
## await pending forever and strand the screen on a half-filled bar.
## Speed-scaling lands it within a frame and still emits, so `cleared`, the
## full-bar pop and the `filled` signal all run their normal path.
##
## A no-op when nothing is in flight.
func rush() -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.set_speed_scale(RUSH_SPEED)
```

- [ ] **Step 4: Rescan and run**

```
filesystem_manage(op="scan")
test_run(suite="stat_check")
```

Expected: PASS. Watch `test_row_fill_is_a_coroutine_that_pops_only_at_full` — it greps the source and must still pass.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/StatCheckRow.gd tests/test_stat_check.gd
git commit -m "feat(statcheck): let a row's fill be rushed without killing its tween"
```

---

### Task B2: Make the star meter rushable

**Files:**
- Modify: `Scripts/EndGame/StarMeter.gd`
- Test: `tests/test_stat_check.gd`

**Interfaces:**
- Consumes: `StarMeter._tween`, which the class already tracks.
- Produces: `StarMeter.RUSH_SPEED: float`, `StarMeter.rush() -> void`. Task B3 calls it.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_star_meter_can_be_rushed() -> void:
	var src := FileAccess.get_file_as_string(_METER_SCRIPT)
	assert_true(src.contains("func rush() -> void:"), "the meter can be rushed")
	assert_true(src.contains("set_speed_scale("), "by speed-scaling its tween")
	assert_true(src.contains("const RUSH_SPEED"), "with a named multiplier")


## rush() must be safe before animate_to() has ever run -- the first tap can
## land before any stat has cleared. It should leave the rendered value
## alone rather than snapping the meter somewhere.
func test_rushing_an_idle_meter_leaves_the_stars_where_they_are() -> void:
	var screen = load(_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(screen)
	track(screen)
	var meter = screen.get_node("MarginContainer/Column/StarMeter")
	meter.set_stars(1.5)
	meter.rush()
	assert_true(is_equal_approx(meter.get_node("Star1").value, 100.0),
		"the first star stays full after an idle rush")
	assert_true(is_equal_approx(meter.get_node("Star2").value, 50.0),
		"the second stays half")
	Engine.get_main_loop().root.remove_child(screen)
```

Mirrors `test_star_meter_maps_a_float_onto_three_star_bars:183`. Instantiating `StatCheck.tscn` in-editor is safe: `_ready()` returns at the `Engine.is_editor_hint()` guard before it starts the sequence.

Note `StarMeter.animate_to()` legitimately calls `_tween.kill()` before starting a new tween — that is killing its *own* previous tween, which nothing awaits. Only the awaited tween must never be killed, so do not add a blanket no-`.kill()` assertion to this file.

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="stat_check")
```

Expected: FAIL — no `rush()` on `StarMeter`.

- [ ] **Step 3: Implement**

Add beside `@export var step_seconds`:

```gdscript
## Speed multiplier a rush applies to the live step. Matches
## StatCheckRow.RUSH_SPEED so a rushed student's bar and meter land
## together rather than one trailing the other.
const RUSH_SPEED := 1000.0
```

And after `animate_to()`:

```gdscript
## Land the in-flight step immediately. Speed-scaled rather than killed so
## the tween still completes normally; nothing awaits this one, but keeping
## both rushes identical means there is only one behaviour to reason about.
##
## A no-op when nothing is in flight.
func rush() -> void:
	if _tween != null and _tween.is_valid():
		_tween.set_speed_scale(RUSH_SPEED)
```

- [ ] **Step 4: Rescan and run**

```
filesystem_manage(op="scan")
test_run(suite="stat_check")
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/EndGame/StarMeter.gd tests/test_stat_check.gd
git commit -m "feat(statcheck): let the star meter's step be rushed"
```

---

### Task B3: Wire the tap

**Files:**
- Modify: `Scripts/EndGame/StatCheck.gd`
- Test: `tests/test_stat_check.gd`

**Interfaces:**
- Consumes: `StatCheckRow.rush()` (B1), `StarMeter.rush()` (B2).
- Produces: `StatCheck.RUSH_SPEED`, `_rushing`, `_live_tween`, `_hold()`, `_rush_current_student()`. Nothing consumes these.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_a_tap_rushes_the_current_student() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _unhandled_input("),
		"the screen listens for a tap")
	assert_true(src.contains("InputEventScreenTouch"), "touch on device")
	assert_true(src.contains("InputEventMouseButton"), "and click in the editor")
	assert_true(src.contains("func _rush_current_student()"), "the rush entry point")


## The rush is scoped to one student: the flag resets as each card starts,
## so a tap on student 2 never carries into student 3.
func test_the_rush_flag_resets_per_student() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var loop_at := src.find("for student in students:")
	var reset_at := src.find("_rushing = false", loop_at)
	var slide_at := src.find("await _slide_in(card)", loop_at)
	assert_true(loop_at != -1 and reset_at != -1 and slide_at != -1,
		"the loop resets the rush flag")
	assert_true(reset_at < slide_at,
		"the flag clears before the card animates, so each student starts unrushed")


## The holds must be tweens, not SceneTreeTimers. A SceneTreeTimer cannot
## be sped up, so a timer-based hold would ignore the tap and stall the
## rush for its full duration.
func test_the_holds_are_tween_based_so_they_can_be_rushed() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _hold("), "holds go through one helper")
	assert_true(src.contains("tween_interval("), "which is a tween, not a timer")
	assert_false(src.contains("create_timer(hold_seconds)"),
		"no SceneTreeTimer hold survives -- it could not be rushed")


## Rushing must not fire three tally cues inside one frame; they would
## overlap into a click rather than reading as three clears.
func test_a_rushed_student_plays_one_tally_not_three() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("if not _rushing:"),
		"the per-row cue is suppressed while rushing")


## The trailing hold and the slide-out are deliberately NOT rushed by the
## first tap: the point is to reach the numbers sooner, not to hide them.
func test_the_first_tap_leaves_the_read_beat_intact() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var rows_at := src.find("for row in card.rows():")
	var clear_at := src.find("_rushing = false", rows_at)
	var slide_out_at := src.find("await _slide_out(card)", rows_at)
	assert_true(clear_at != -1 and slide_out_at != -1 and clear_at < slide_out_at,
		"the rush is stood down before the trailing hold, so it plays in full")


func test_the_header_no_longer_claims_the_screen_is_not_tap_driven() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_false(src.contains("Deliberately NOT tap-driven"),
		"the old decision is superseded")
	assert_true(src.contains("tap"),
		"and the header explains the tap that replaced it")
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="stat_check")
```

Expected: FAIL on every one of the seven.

- [ ] **Step 3: Rewrite the header comment**

Replace the `## Deliberately NOT tap-driven: the check is a reveal the player watches.` line with:

```gdscript
## The check is a reveal the player watches, but a tap anywhere rushes the
## CURRENT student to its finished state -- bars, stars and pops land at
## once. The trailing hold and the slide-out still play in full, so the
## numbers stay readable; a second tap rushes those too. The next student
## animates normally and needs its own tap.
##
## (This reverses the screen's original "deliberately not tap-driven"
## rule, 2026-09-09, on the grounds that a player who has already read a
## student should not have to wait out the animation.)
```

- [ ] **Step 4: Add the rush state and the input handler**

Beside the other consts:

```gdscript
## Speed multiplier a rush applies to whichever tween is in flight. Matches
## StatCheckRow.RUSH_SPEED and StarMeter.RUSH_SPEED.
const RUSH_SPEED := 1000.0
```

Beside `var _exiting`:

```gdscript
## True once the player has tapped during the current student. Reset at the
## top of every card, which is what scopes a rush to one student.
var _rushing: bool = false
## Whichever beat is currently being awaited, held so a tap can rush it.
var _live_tween: Tween = null
```

Then:

```gdscript
## A tap anywhere rushes the current student. No node is added for this --
## nothing else on this screen is interactive, so a full-screen catcher
## would only be one more thing to keep in front of the card.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _exiting:
		return
	var pressed := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_rush_current_student()


## Land the in-flight beat at once, and mark the rest of this student's
## reveal as rushed.
##
## Speed-scaling rather than killing is load-bearing: Tween.kill() does not
## emit `finished`, so killing the tween _run_check() is awaiting would
## leave that await pending forever and strand the screen mid-card.
func _rush_current_student() -> void:
	_rushing = true
	if _live_tween != null and _live_tween.is_valid():
		_live_tween.set_speed_scale(RUSH_SPEED)
	star_meter.rush()
	var card := card_slot.get_child(card_slot.get_child_count() - 1) \
		if card_slot.get_child_count() > 0 else null
	if card != null and card.has_method("rows"):
		for row in card.rows():
			row.rush()


## A pause, as a tween rather than a SceneTreeTimer, so _rush_current_student()
## can speed it up. A timer cannot be rushed, and a timer-based hold would
## swallow the tap for its full duration.
func _hold(seconds: float) -> void:
	var tw := create_tween()
	_live_tween = tw
	tw.tween_interval(seconds)
	await tw.finished
	_live_tween = null
```

- [ ] **Step 5: Register the live tween in the existing beats**

In `_slide_in()`, `_slide_out()` and `_fade_to_white()`, assign the tween to `_live_tween` right after creating it and clear it after the await. For `_slide_in()`:

```gdscript
func _slide_in(card: Control) -> void:
	var rest := card.position
	card.position.x = get_viewport_rect().size.x
	AudioDirector.play_sfx(&"swipe")
	var tw := create_tween()
	_live_tween = tw
	tw.tween_property(card, "position:x", rest.x, slide_seconds) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tw.finished
	_live_tween = null
```

Do the same in `_slide_out()`. Leave `_fade_to_white()` **unregistered** — taps during the closing fade are ignored, since the hand-off is imminent and there is nothing left to reveal.

- [ ] **Step 6: Rework the loop**

In `_run_check()`, replace the loop body:

```gdscript
	for student in students:
		# Reset before anything animates: each student starts unrushed, so
		# a tap on one never carries into the next.
		_rushing = false

		var card: StatCheckCard = CARD_SCENE.instantiate()
		card_slot.add_child(card)
		card.bind(student)
		await _slide_in(card)
		if _abandoned():
			return
		await _hold(hold_seconds)
		if _abandoned():
			return

		var rushed_clears := 0
		for row in card.rows():
			if _rushing:
				row.rush()
			await row.fill()
			if _abandoned():
				return
			if row.cleared:
				_stars += star_share(_total_stats)
				star_meter.animate_to(_stars)
				if _rushing:
					# Three cues inside one frame overlap into a click.
					rushed_clears += 1
					star_meter.rush()
				else:
					AudioDirector.play_sfx(&"tally")
		if rushed_clears > 0:
			AudioDirector.play_sfx(&"tally")

		# Stand the rush down before the read beat. The trailing hold and
		# the slide-out play in full so the numbers can actually be read; a
		# second tap rushes those.
		_rushing = false
		await _hold(hold_seconds)
		if _abandoned():
			return
		await _slide_out(card)
		if _abandoned():
			return
		card.queue_free()
```

Note the `if _rushing: row.rush()` before `await row.fill()` handles rows that have not started yet — `rush()` is a no-op on an idle row, and `fill()` sets `_fill_tween` before the tap can reach it only for the row already in flight, which `_rush_current_student()` already covered.

- [ ] **Step 7: Rescan and run**

```
filesystem_manage(op="scan")
test_run(suite="stat_check")
```

Expected: PASS, including the pre-existing `test_the_sequence_slides_fills_in_order_and_awaits_each_beat`, which greps for `await _slide_in(card)`, `await row.fill()`, `await _slide_out(card)` and `for row in card.rows():` — all still present.

- [ ] **Step 8: Play it once to confirm the feel**

```
project_run()
```

Debug overlay → General → **⚡ Seed Playtest State**, then Scenes → **🎭 Gladi Resik Akhir Kelas** → *Campur*, which ladders 3/2/1/0 cleared targets across four students so one pass exercises a full clear, partial clears and a blank.

Confirm: a tap lands the current student's bars and stars at once; the card still pauses before sliding out; the next student animates normally. Then **↩ Pulihkan Run Sebelum Gladi Resik**.

If a tap ever leaves the screen stuck on a half-filled bar, a tween is being killed rather than speed-scaled somewhere — that is the deadlock this design exists to avoid.

- [ ] **Step 9: Run the full suite**

```
test_run()
```

Expected: every suite green.

- [ ] **Step 10: Commit**

```bash
git add Scripts/EndGame/StatCheck.gd tests/test_stat_check.gd
git commit -m "feat(statcheck): tap anywhere to rush the current student's reveal"
```

---

### Task B4: Document Part B

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: Add the entry**

Newest first. Record the tap-to-rush, that it is scoped per student, that the trailing hold survives on purpose, and the speed-scale-not-kill reason — that last one is the detail a future maintainer will otherwise rediscover the hard way.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/CHANGELOG.md
git commit -m "docs(statcheck): record the tap-to-rush pass"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| Source assets, Shinta rename | A1 |
| §1 Letterboxed art-space stage | A5, A6, A7 |
| §2 Slots, arrangements, fill order | A3 |
| §2 Re-exported art / shared baseline | A2 (anchors pin the measurement) |
| §3 WinLineup static functions | A2–A4 |
| §4 Texture lookup, missing-name warning | A6 |
| §5 Ground shadows, two layers, knobs | A1, A4, A5, A6 |
| §6 No badge on the win path | A6 |
| §7 BlurLayer above Stage | A5 |
| §8 Slot anchors tuned by screenshot | A7 step 5 |
| §9 Tests | A2–A7, B1–B3 |
| §10 Placeholders | A8 |
| §11 StatCheck tap-to-rush | B1–B3 |

**Type consistency:** `assign()` returns `Array[Dictionary]` with keys `name`/`slot`/`anchor`/`scale`, produced in A3 and consumed by `shadow_for()` (A4) and `_dress_lineup()` (A6). `shadow_for()` returns `centre`/`size`, consumed in A6. `rush()` is the method name on `StatCheckRow` (B1), `StarMeter` (B2) and the call sites in B3. `RUSH_SPEED` is the const name in all three.

**Placeholder scan:** no TBD/TODO; every code step carries real code. The only deliberately-unfixed numbers are `SLOT_GEOMETRY`'s four anchor/scale pairs, which A7 step 5 tunes against a screenshot — flagged as estimates in the spec's §8 and in the const's own doc comment.

**One risk worth naming:** A5 deletes and recreates `Backdrop` to reparent it under `Stage`, because a node's type and parent cannot be changed in place. Two existing tests reference the old root-level path, and the failure modes differ. `test_scene_has_the_chrome:65` fails loudly. `test_the_blur_layer_blurs_the_backdrop_but_not_the_badge_or_button:222` fails *silently* — it scans the root's children, `find()` returns `-1` for the moved node, and `-1 < blur_at` keeps the assertion green while it tests nothing. A5 step 5 repairs both and adds an `assert_gt(stage_at, -1, …)` guard so the same trap cannot reopen.
