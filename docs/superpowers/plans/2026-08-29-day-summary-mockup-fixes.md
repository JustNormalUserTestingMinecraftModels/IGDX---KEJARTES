# Daily Results Popup — Mockup Fidelity Fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the gap between the shipped Daily Results popup and
`dailyresults_mockup.png`, whose art currently renders as small squares because
two source PNGs are letterboxed inside 1:1 canvases.

**Architecture:** The two offending PNGs are cropped on disk to their measured
content boxes, so canvas aspect equals content aspect and Godot's
`KEEP_ASPECT_CENTERED` stops collapsing them. The avatar is then repointed at
each student's existing portrait rather than the splash art, and the DayScreen
chrome that bleeds through the scrim is hidden while the popup is up.

**Tech Stack:** Godot 4.6, GDScript, PowerShell + System.Drawing for the crops,
Godot AI MCP `test_run` for the suite.

**Spec:** `docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md`
(the original measurement pass; this plan corrects two asset defects that spec
did not catch, because it measured the mockup but never measured the exported
PNGs against their own canvases).

## Global Constraints

- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation.
  Only layout-only constant overrides (`separation`, `margin_*`) are allowed.
- **Rescan before running tests** after any `.gd` edit:
  `filesystem_manage(op="scan")`. `test_run` serves a stale autoload otherwise.
- **Never leave a scene this plan rewrites open as an editor tab.** The editor
  keeps an in-memory copy that shadows the disk file for `load()` inside
  `test_run`, and neither `scan` nor `scene_open(force_reload=true)` clears it.
  Check with `scene_manage(op="get_roots")` before trusting a "missing node"
  failure. This cost two editor restarts during the previous plan.
- Test suites must be `@tool`, extend `McpTestSuite`, and **contain no
  coroutines** — the runner calls `suite.call(name)` without awaiting.
- `McpTestSuite` provides `assert_true/false/eq/ne/gt/not_null/has_key/contains/is_error`.
  There is **no** `assert_almost_eq` — compare floats with
  `assert_true(absf(a - b) < tol, ...)`.
- Game-facing identifiers and UI text are **Indonesian**; systems code English.
- Tunable numbers go in a named `const` block or an `@export`, never inline.
- Commits: Conventional Commits with a scope, e.g. `fix(day-summary): ...`.
- Mockup pixels **are** game pixels. There is no scale factor. Do not add one.

## Measured Asset Defects

Probed with the `pixel-accurate-ui-from-mockups` skill's `probe.ps1 -Mode bbox`:

| Asset | Canvas | Content box | Content size | Content aspect | Currently renders as |
|---|---|---|---|---|---|
| `card_bg.png` | 1080×1080 (1.0) | x 44..1035, y 338..747 | **992×410** | 2.4195 | 405×405 square |
| `title_daily_results.png` | 1080×1080 (1.0) | x 11..1068, y 358..682 | **1058×325** | 3.2554 | 287×287 square |

Both are placed with `expand_mode = 1` (IGNORE_SIZE) and `stretch_mode = 5`
(KEEP_ASPECT_CENTERED). That mode honours the **canvas** aspect, not the
content's, so each collapses to a square the height of its box. The three stat
icons and the chevron have modest padding in square canvases too, but their
content aspects (1.5, 1.0, 1.5, 0.74) are close enough that centring reads
correctly — they are explicitly **out of scope**.

Note `card_bg.png`'s content is 992 wide — exactly the card width the original
spec derived from the mockup. That is the confirmation the crop is right.

---

## File Structure

| File | Responsibility |
|---|---|
| `Assets/Images/DaySummary/card_bg.png` (modify) | Cropped to its 992×410 content box |
| `Assets/Images/DaySummary/title_daily_results.png` (modify) | Cropped to its 1058×325 content box |
| `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` (modify) | CardArt stretch mode + card box height |
| `Scenes/SchoolSimulation/DaySummaryPopup.tscn` (modify) | TitleBanner box to the banner's real aspect |
| `Scripts/SchoolSimulation/DaySummaryAvatar.gd` (modify) | Prefer the portrait over the splash art |
| `Scripts/SchoolSimulation/SchoolDay.gd` (modify) | Hide DayScreen chrome behind the popup |
| `tests/test_day_summary.gd` (modify) | Pin the cropped sizes and the new avatar order |

---

## Task 1: Crop the two letterboxed PNGs

**Files:**
- Modify: `Assets/Images/DaySummary/card_bg.png`
- Modify: `Assets/Images/DaySummary/title_daily_results.png`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `card_bg.png` at exactly 992×410, `title_daily_results.png` at
  exactly 1058×325. Tasks 2 and 3 lay out against these sizes.

The originals are kept as `*_uncropped.png` siblings so a later re-export can be
re-measured rather than reverse-engineered.

- [ ] **Step 1: Update the size test to the cropped dimensions**

In `tests/test_day_summary.gd`, replace the whole
`test_card_background_is_native_size` function with:

```gdscript
## Both card art and banner ship letterboxed inside 1:1 canvases from the
## design tool. Godot's KEEP_ASPECT_CENTERED honours the CANVAS aspect, so
## an uncropped 1080x1080 export collapses to a square and the card loses
## its background entirely. These pin the cropped content boxes measured
## with probe.ps1 -Mode bbox.
func test_card_background_is_cropped_to_its_content_box() -> void:
	var tex := load(_ART["card_bg"]) as Texture2D
	assert_eq(tex.get_width(), 992, "card_bg width is not its content box")
	assert_eq(tex.get_height(), 410, "card_bg height is not its content box")


func test_title_banner_is_cropped_to_its_content_box() -> void:
	var tex := load(_ART["title"]) as Texture2D
	assert_eq(tex.get_width(), 1058, "banner width is not its content box")
	assert_eq(tex.get_height(), 325, "banner height is not its content box")


## The bug this plan exists to kill: a 1:1 canvas holding a wide band of
## art. If either asset is ever re-exported square again, this fails loudly
## instead of silently rendering a stamp.
func test_neither_card_art_nor_banner_is_square() -> void:
	for key in ["card_bg", "title"]:
		var tex := load(_ART[key]) as Texture2D
		var aspect := float(tex.get_width()) / float(tex.get_height())
		assert_true(aspect > 1.5,
			"%s is square-ish (aspect %f) -- it must be cropped to its content box" % [key, aspect])
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: FAIL — `card_bg width is not its content box` (it is still 1080).

- [ ] **Step 3: Crop both PNGs**

Run this in PowerShell from the repo root. It keeps the originals and writes
the crops in place:

```powershell
Add-Type -AssemblyName System.Drawing
$dir = "Assets\Images\DaySummary"
$jobs = @(
  @{ Name = "card_bg.png";             X = 44; Y = 338; W = 992;  H = 410 },
  @{ Name = "title_daily_results.png"; X = 11; Y = 358; W = 1058; H = 325 }
)
foreach ($j in $jobs) {
  $path = Join-Path $dir $j.Name
  $full = (Resolve-Path $path).Path
  $backup = $full -replace '\.png$', '_uncropped.png'
  if (-not (Test-Path $backup)) { Copy-Item $full $backup }
  $src = [System.Drawing.Image]::FromFile($backup)
  $dst = New-Object System.Drawing.Bitmap($j.W, $j.H)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $j.W, $j.H)),
               (New-Object System.Drawing.Rectangle($j.X, $j.Y, $j.W, $j.H)),
               [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $src.Dispose()
  $dst.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()
  Write-Output "cropped $($j.Name) -> $($j.W)x$($j.H)"
}
```

- [ ] **Step 4: Confirm the crops landed**

```powershell
Add-Type -AssemblyName System.Drawing
foreach ($n in @("card_bg.png","title_daily_results.png")) {
  $i = [System.Drawing.Image]::FromFile((Resolve-Path "Assets\Images\DaySummary\$n").Path)
  Write-Output "$n : $($i.Width) x $($i.Height)"; $i.Dispose()
}
```

Expected: `card_bg.png : 992 x 410` and `title_daily_results.png : 1058 x 325`.

- [ ] **Step 5: Reimport and run the tests**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: PASS. The suite gains one test (the old native-size test was
replaced by three), so the count rises by 2 from its previous total.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/DaySummary tests/test_day_summary.gd
git commit -m "fix(day-summary): crop the card and banner art to their content boxes"
```

---

## Task 2: Lay the cropped art out at its true aspect

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn` (the `CardArt` node)
- Modify: `Scenes/SchoolSimulation/DaySummaryPopup.tscn` (the `TitleBanner` node)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: the cropped assets from Task 1.
- Produces: no new API. The card box height becomes **410** (was 405), so any
  later task positioning against the card uses 410.

**Why the height changes.** The original spec derived a 992×393 fill plus a
12px shadow and rounded that to 405. The art's own content box is 992×410 — the
authoritative number, since the art is what gets drawn. Adopting 410 makes the
card box exactly the texture, so `STRETCH_SCALE` cannot distort it.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## STRETCH_SCALE (0) is correct ONLY because Task 1 made the texture's
## aspect equal the box's. KEEP_ASPECT_CENTERED (5) was what collapsed the
## art to a square, so this pins the mode as much as the size.
func test_card_art_fills_the_card_box_without_letterboxing() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	assert_eq(inst.custom_minimum_size, Vector2(992, 410),
		"card box must equal the card art's content box")
	var art := inst.get_node_or_null("CardArt") as TextureRect
	assert_not_null(art, "row is missing CardArt")
	assert_eq(art.stretch_mode, TextureRect.STRETCH_SCALE,
		"CardArt must STRETCH_SCALE -- KEEP_ASPECT_CENTERED squares the art")
	var tex: Texture2D = art.texture
	assert_not_null(tex, "CardArt has no texture")
	var box_aspect := 992.0 / 410.0
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	assert_true(absf(box_aspect - tex_aspect) < 0.01,
		"card box aspect %f does not match the texture's %f" % [box_aspect, tex_aspect])
	inst.free()


func test_banner_box_matches_the_banner_art_aspect() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	var inst := scene.instantiate()
	var banner := inst.find_child("TitleBanner", true, false) as TextureRect
	assert_not_null(banner, "popup is missing TitleBanner")
	var tex: Texture2D = banner.texture
	assert_not_null(tex, "TitleBanner has no texture")
	var box := banner.custom_minimum_size
	assert_true(box.x > 0.0 and box.y > 0.0, "TitleBanner has no reserved box")
	var box_aspect := box.x / box.y
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	assert_true(absf(box_aspect - tex_aspect) < 0.05,
		"banner box aspect %f does not match the art's %f" % [box_aspect, tex_aspect])
	inst.free()
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: FAIL — `card box must equal the card art's content box` (it is 405).

- [ ] **Step 3: Fix the CardArt node**

In `Scenes/SchoolSimulation/DaySummaryStudentRow.tscn`, change the root's
minimum size and the `CardArt` stretch mode. Replace:

```
custom_minimum_size = Vector2(992, 405)
```

with:

```
custom_minimum_size = Vector2(992, 410)
```

and in the `[node name="CardArt" type="TextureRect" parent="."]` block replace:

```
expand_mode = 1
stretch_mode = 5
```

with:

```
expand_mode = 1
stretch_mode = 0
```

Leave every other node's offsets untouched — the card grew by 5px at the
bottom, which is below the lowest child (StatRow3 ends at 350).

- [ ] **Step 4: Fix the TitleBanner node**

In `Scenes/SchoolSimulation/DaySummaryPopup.tscn`, in the
`[node name="TitleBanner" type="TextureRect" parent="DimOverlay/Content"]`
block, replace:

```
custom_minimum_size = Vector2(932, 287)
stretch_mode = 5
```

with:

```
custom_minimum_size = Vector2(932, 286)
stretch_mode = 0
```

932/286 = 3.2587, within 0.01 of the art's 3.2554 — so `STRETCH_SCALE` draws
it at the mockup's width with no visible distortion.

- [ ] **Step 5: Run the tests**

Confirm neither scene is open as an editor tab first
(`scene_manage(op="get_roots")`), then:

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: PASS, 2 more tests than Task 1 left.

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryStudentRow.tscn Scenes/SchoolSimulation/DaySummaryPopup.tscn tests/test_day_summary.gd
git commit -m "fix(day-summary): draw the card and banner art at their true aspect"
```

---

## Task 3: Use the existing portrait, not the splash art

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryAvatar.gd`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryAvatar.FRAME_ASPECT` (unchanged).
- Produces: `DaySummaryAvatar.set_student` resolving
  `avatar_texture` → `splash_path` → null, the reverse of today's order, and
  `crop_for(student_name, tex, is_splash: bool)` — note the **new third
  parameter**. `SPLASH_CROP`'s named rects apply only when `is_splash` is true.

**Why.** The named `SPLASH_CROP` rects are head-and-shoulders windows into
1080×1920 full-body splashes. Applied to a portrait — a different image at a
different size — they crop the wrong region entirely. So the crop table must
only be consulted for the art it was measured against. The splash art is being
replaced later, so this keeps the table and its tests intact rather than
deleting work that will be wanted again.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## The portrait is the source of truth for now -- the splash art is being
## replaced, so the avatar must not reach for it even when a student has
## one. Source-scanned because building a StudentData with both textures
## set requires resources this suite cannot load headlessly.
func test_avatar_prefers_the_portrait_over_the_splash() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/DaySummaryAvatar.gd")
	var portrait_at := src.find("student.avatar_texture")
	var splash_at := src.find("student.splash_path")
	assert_true(portrait_at != -1, "avatar no longer reads avatar_texture")
	assert_true(splash_at != -1, "avatar no longer reads splash_path")
	assert_true(portrait_at < splash_at,
		"avatar_texture must be tried BEFORE splash_path")


## A named splash crop applied to a portrait would cut the wrong region,
## so the table is gated behind the is_splash flag.
func test_named_crops_apply_only_to_splash_art() -> void:
	var tex := load("res://Assets/Images/SplashArtMurid/splash_marcel.png") as Texture2D
	var as_splash := DaySummaryAvatar.crop_for("Marcel", tex, true)
	var as_portrait := DaySummaryAvatar.crop_for("Marcel", tex, false)
	assert_eq(as_splash, DaySummaryAvatar.SPLASH_CROP["Marcel"],
		"splash lookup must return the named crop")
	assert_true(as_portrait != as_splash,
		"a portrait must NOT get the named splash crop")
	var aspect := as_portrait.size.x / as_portrait.size.y
	assert_true(absf(aspect - DaySummaryAvatar.FRAME_ASPECT) < 0.02,
		"computed portrait crop aspect %f is not the frame's" % aspect)
```

- [ ] **Step 2: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: FAIL — `crop_for` currently takes two arguments, so the call errors.

- [ ] **Step 3: Add the `is_splash` parameter to `crop_for`**

In `Scripts/SchoolSimulation/DaySummaryAvatar.gd`, replace the whole
`crop_for` function with:

```gdscript
## Falls back for any student with no entry in SPLASH_CROP, and for every
## student when the texture is a portrait rather than a splash: the named
## rects are windows into 1080x1920 full-body art and cut the wrong region
## out of anything else. Takes the full width and the top FRAME_ASPECT-worth
## of rows, which frames a head without knowing anything about the pose.
static func crop_for(student_name: String, tex: Texture2D, is_splash: bool = false) -> Rect2:
	if is_splash and SPLASH_CROP.has(student_name):
		return SPLASH_CROP[student_name]
	if tex == null:
		return Rect2()
	var w := float(tex.get_width())
	var h := minf(float(tex.get_height()), w / FRAME_ASPECT)
	return Rect2(0.0, 0.0, h * FRAME_ASPECT, h)
```

- [ ] **Step 4: Flip the resolution order in `set_student`**

In the same file, replace the whole `set_student` function with:

```gdscript
## Resolution order: the student's portrait first, then their splash art,
## then nothing. The portrait leads because the splash batch is being
## replaced -- flip these two branches back once the new art lands.
func set_student(student: StudentData) -> void:
	if student == null:
		art.texture = null
		return

	var tex: Texture2D = null
	var is_splash := false
	if student.avatar_texture != null:
		tex = student.avatar_texture
	elif student.splash_path != "" and ResourceLoader.exists(student.splash_path):
		tex = load(student.splash_path)
		is_splash = true

	if tex == null:
		art.texture = null
		return

	var region := crop_for(student.student_name, tex, is_splash)
	if region.size.x <= 0.0:
		art.texture = tex
		return

	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	art.texture = atlas
```

- [ ] **Step 5: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: PASS. `test_unknown_students_get_a_computed_crop` still passes —
it calls `crop_for("Doni", tex)` and the new third parameter defaults to
`false`, which is the computed branch it already expected.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryAvatar.gd tests/test_day_summary.gd
git commit -m "fix(day-summary): show the student portrait instead of the splash art"
```

---

## Task 4: Hide the DayScreen chrome behind the popup

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (`_show_day_summary`)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `DaySummaryPopup.summary_dismissed` (unchanged).
- Produces: nothing new.

The popup is a scrim over the live DayScreen, so the book-clock widget and the
day banner read straight through it and collide with the cards. The mockup
shows the banner and the card stack on an otherwise empty field. Hiding the
chrome for the popup's lifetime — and restoring it after — is the smallest
change that gets there.

- [ ] **Step 1: Chrome node paths (already confirmed — do not re-derive)**

The controller read the live hierarchy of `SchoolDay.tscn` before this task
was dispatched (`scene_get_hierarchy()`), because no subagent has editor
access to do it. The offenders visible in the user's screenshot — a book/clock
dial over the stack, "SENIN" (the day name) bleeding through near the top, and
a dark red "...SELESAI" bar near the bottom — resolve to exactly these five
`DayScreen` children:

```
DayScreen/DayNumberLabel
DayScreen/DayLabel
DayScreen/BookClockWidget
DayScreen/ProgressBar
DayScreen/StatusLabel
```

There is no single "DayTitleLabel" — that was a guess corrected by the real
data. `StudentScroll`, `ClickToContinueLabel`, `BackButton`, and `SkipButton`
are deliberately excluded: they are not visible behind the popup in the
screenshot, and hiding `StudentScroll` in particular would be wrong regardless
— Task 8 of the previous plan made the popup build its own rows independently
of it.

- [ ] **Step 2: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## The popup is a scrim over the live DayScreen, so anything left visible
## underneath collides with the card stack. The mockup shows the banner and
## cards on an empty field.
func test_school_day_hides_its_chrome_behind_the_summary() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("_set_day_chrome_visible(false)"),
		"SchoolDay must hide its DayScreen chrome before showing the popup")
	assert_true(src.contains("_set_day_chrome_visible(true)"),
		"SchoolDay must restore its chrome after the popup is dismissed")
	assert_true(src.contains("func _set_day_chrome_visible("),
		"SchoolDay is missing the chrome helper")
```

- [ ] **Step 3: Run it to make sure it fails**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: FAIL — `SchoolDay is missing the chrome helper`.

- [ ] **Step 4: Add the helper and call it**

In `Scripts/SchoolSimulation/SchoolDay.gd`, add this function immediately
above `_show_day_summary`, substituting the two paths you read in Step 1 for
the placeholders in `_DAY_CHROME_PATHS`:

```gdscript
## Nodes on the DayScreen that would otherwise read through the summary
## popup's scrim and collide with the card stack. Paths, not @onready refs,
## because several are optional depending on how far the day got.
const _DAY_CHROME_PATHS := [
	"DayScreen/DayNumberLabel",
	"DayScreen/DayLabel",
	"DayScreen/BookClockWidget",
	"DayScreen/ProgressBar",
	"DayScreen/StatusLabel",
]


func _set_day_chrome_visible(shown: bool) -> void:
	for p in _DAY_CHROME_PATHS:
		var n := get_node_or_null(p)
		if n != null:
			n.visible = shown
```

Then in `_show_day_summary`, wrap the popup's lifetime. Replace:

```gdscript
	var summary_instance = summary_scene.instantiate()
	add_child(summary_instance)
```

with:

```gdscript
	var summary_instance = summary_scene.instantiate()
	_set_day_chrome_visible(false)
	add_child(summary_instance)
```

and replace:

```gdscript
	await summary_instance.summary_dismissed
```

with:

```gdscript
	await summary_instance.summary_dismissed
	_set_day_chrome_visible(true)
```

- [ ] **Step 5: Run the tests**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
test_run(suite="school_day")
```

Expected: both PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_day_summary.gd
git commit -m "fix(school-day): hide the day chrome while the summary popup is up"
```

---

## Task 5: Verify against the mockup

**Files:**
- Modify (only if the comparison demands it): offsets in
  `DaySummaryStudentRow.tscn` and `DaySummaryPopup.tscn`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing new.

Reading the code you just wrote is not verification. This task measures the
built result and diffs it against the mockup.

- [ ] **Step 1: Reach the popup without playing the game**

Open `Scenes/Splashscreen/Splashscreen.tscn`, run the project, then in the
debug overlay (F1, or 5 taps top-right): **⚡ Seed Playtest State**, then the
**Scenes** tab → **AturJadwal**. Assign any activity across the week, confirm,
and let SchoolDay run to the first day's end.

The seed covers roster, money, inventory and the lobby tutorial flag — it does
**not** fill `day_schedules`, which is why the Atur Jadwal pass is required.

**Focus the game window** before any `game_eval` or screenshot: a backgrounded
game stops advancing its main loop and both calls fail.

- [ ] **Step 2: Screenshot the live popup**

```
editor_screenshot(source="game")
```

- [ ] **Step 3: Diff it against the mockup, surface by surface**

Compare the screenshot against `dailyresults_mockup.png` on each of these,
which are the things this plan changed:

1. The banner spans most of the screen width, is not a small square, and is
   not distorted.
2. Each card shows the yellow-green rounded background behind all of its
   contents — not a square patch in the middle, not a bare scrim.
3. Each avatar shows that student's portrait, framed on the head, with no
   transparent gap and nothing stretched.
4. No book-clock dial and no day title overlap the card stack.

Write the comparison down. Any mismatch is a bug in the offsets, not in the
mockup.

- [ ] **Step 4: Measure the built geometry**

```
game_manage(op="get_ui_elements",
            params={"root_path": "/root/SchoolDay/DaySummaryPopup/DimOverlay/Content",
                    "max_depth": 4})
```

Scope the call — bare `get_ui_elements` serialises the whole tree. Card-relative
= reported global minus the card's own global origin. Tolerance: 2px against
the original spec's §2 table, with the card box now 410 tall rather than 405.

- [ ] **Step 5: Resolve the carried-over NameLabel question**

The previous plan's spec table says the name sits at y=48 with height 41; the
built scene uses `offset_top = 40`, `offset_bottom = 100`. Measure the name's
baseline in the screenshot against the mockup and adopt whichever the pixels
support, then note the decision in a comment on that node.

- [ ] **Step 6: Re-run the whole suite after any adjustment**

```
filesystem_manage(op="scan")
test_run()
```

Expected: no new failures beyond the ones documented in CLAUDE.md → Known
Issues (`test_audio_director` coroutine, `test_audio_coverage` double-SFX,
stale UID warnings).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "fix(day-summary): align the built popup with the mockup measurements"
```

---

## Self-Review

**Spec coverage.** The original spec's §1 (1:1 mapping) is what Tasks 1–2
restore — the art was never actually drawn 1:1 because of the canvas padding.
§2's surface table is re-verified in Task 5, including the NameLabel row the
previous plan deferred. §3's asset inventory gains the crop step. §5's data
mapping is untouched. The user's new requirement — portraits instead of splash
art — is Task 3, and is deliberately reversible (the `SPLASH_CROP` table and
its tests survive intact behind the `is_splash` flag).

**Deliberate carry-overs.** `*_uncropped.png` backups stay on disk so a later
re-export can be re-measured. The three stat icons and the chevron keep their
square canvases: their content aspects are close enough that centring reads
correctly, and cropping them would move every icon offset in
`DaySummaryStatRow.tscn` for no visible gain.

**Known risk not designed away.** Task 4 hides chrome by node path. If those
paths are wrong the calls no-op silently and the chrome stays visible — which
is why Step 1 makes you read the real hierarchy first, and why Step 3 of Task 5
checks the result on screen rather than trusting the test.
