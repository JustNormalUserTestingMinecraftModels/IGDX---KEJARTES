# Splash Art Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **STATUS — executed 2026-09-01, all four tasks complete. Suite green (553/553
> at the time, 45 suites).** No deviations from the plan as written. The uids
> Godot generated for the two UI textures, needed by plans 2/4/5:
> `blur_background.png` → `uid://csno01mdnqmpx`,
> `cutscene_dialogue.png` → `uid://u0inspdoga14`.
> The six crops were verified by rendering them to a contact sheet rather than
> booting the game — all six frame head-and-shoulders correctly.

**Goal:** Land the six new student splash arts plus the two new UI textures, rewire every roster to point at them, and recrop the Daily Results avatars against the new canvases.

**Architecture:** Copy the PNGs in and let Godot generate the `.import` files. The `splash` key is duplicated across four scripts with no single source of truth, so all four change together. `DaySummaryAvatar.SPLASH_CROP` holds per-student head windows in each splash's own pixels — every entry is invalidated by the new art and is replaced with measured values from the spec. Finally, honour the pre-planned flip at `DaySummaryAvatar.gd:48-50`: with the batch landed, splash art leads and the portrait becomes the fallback.

**Tech Stack:** Godot 4.6, GDScript, `godot-ai` MCP (`filesystem_manage`, `test_run`).

**Spec:** `docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md`

## Global Constraints

- Godot **4.6**, portrait **1080×1920**, `mobile` renderer.
- **Never hand-author a `.import` file.** Copy the PNG, then `filesystem_manage(op="scan")` — Godot generates the `uid://` and the `.ctex` path. A copied uid is exactly what `tests/test_project_hygiene.gd:48-72` exists to catch.
- **Rescan after editing any `.gd`, before running tests** — `test_run` serves a stale autoload otherwise.
- Tests must be `@tool`; **no test may be a coroutine** (the runner does `suite.call(name)` without awaiting).
- Assertion helpers available on `McpTestSuite`: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_not_null`, `assert_gt`, `assert_has_key`, `assert_contains`, `assert_is_error`, plus `track()`. There is **no** `assert_lt`, `assert_null`, or `assert_almost_eq`.
- Comments and docs in English; game-facing identifiers and UI strings in Indonesian.
- Commits are Conventional Commits with a scope.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Assets/Images/SplashArtMurid/splash_{marcel,doni,andi,citra,shinta,thea}.png` | The six student splash arts | 4 replaced, 2 created |
| `Assets/Images/UI/blur_background.png` | Blurred classroom backdrop (used by plans 2 and 4) | created |
| `Assets/Images/UI/cutscene_dialogue.png` | Dialogue panel art (used by plan 5) | created |
| `docs/superpowers/mockups/mockup_atur_jadwal.png` | Reference art | created |
| `docs/superpowers/mockups/mockup_intro_cutscene.png` | Reference art | created |
| `Scripts/StudentCard/student_card.gd` | `student_data_list` — the de-facto roster source of truth | 6 `splash` paths |
| `Scripts/StudentList/student_list.gd` | `default_students` | 6 `splash` paths |
| `Scripts/Debug/DebugManager.gd` | `DEFAULT_STUDENTS` (4 entries) | 4 `splash` paths |
| `Scripts/AturJadwal/atur_jadwal.gd` | Hardcoded "Marcel" fallback student | 1 `splash` path |
| `Scripts/SchoolSimulation/DaySummaryAvatar.gd` | Per-student crop table + texture resolution order | `SPLASH_CROP` rewritten, `set_student` flipped |
| `tests/test_day_summary.gd` | Pins the art batch and the crop contract | 4 tests updated |

---

## Task 1: Land the assets

**Files:**
- Create: `Assets/Images/SplashArtMurid/splash_doni.png`, `Assets/Images/SplashArtMurid/splash_citra.png`
- Modify (overwrite): `Assets/Images/SplashArtMurid/splash_{marcel,andi,shinta,thea}.png`
- Create: `Assets/Images/UI/blur_background.png`, `Assets/Images/UI/cutscene_dialogue.png`
- Create: `docs/superpowers/mockups/mockup_atur_jadwal.png`, `docs/superpowers/mockups/mockup_intro_cutscene.png`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: eight importable `res://` texture paths. Later tasks and plans reference `res://Assets/Images/SplashArtMurid/splash_<lowercase name>.png`, `res://Assets/Images/UI/blur_background.png`, `res://Assets/Images/UI/cutscene_dialogue.png`.

`whiteboard.png` in Downloads is byte-identical to the shipped `Assets/Images/UI/whiteboard.png` (md5 `d2512f1b181f9d4ce5922cd3631d5262`). **Do not copy it.**

- [x] **Step 1: Extend the test's art manifest to cover all six splashes**

In `tests/test_day_summary.gd`, replace the `_SPLASH` constant (currently four entries) with six:

```gdscript
const _SPLASH := [
	"res://Assets/Images/SplashArtMurid/splash_marcel.png",
	"res://Assets/Images/SplashArtMurid/splash_doni.png",
	"res://Assets/Images/SplashArtMurid/splash_andi.png",
	"res://Assets/Images/SplashArtMurid/splash_citra.png",
	"res://Assets/Images/SplashArtMurid/splash_shinta.png",
	"res://Assets/Images/SplashArtMurid/splash_thea.png",
]
```

- [x] **Step 2: Run the suite to verify it fails**

```
test_run(suite="day_summary")
```

Expected: `test_every_new_splash_imports` FAILS with `missing splash res://Assets/Images/SplashArtMurid/splash_doni.png`.

- [x] **Step 3: Copy the eight files in**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && D="/c/Users/user/Downloads" && cp "$D/splash_marcel.png" "$D/splash_doni.png" "$D/splash_andi.png" "$D/splash_citra.png" "$D/splash_shinta.png" "$D/splash_thea.png" Assets/Images/SplashArtMurid/ && cp "$D/blur_background.png" "$D/cutscene_dialogue.png" Assets/Images/UI/ && cp "$D/mockup_atur_jadwal.png" "$D/mockup_intro_cutscene.png" docs/superpowers/mockups/
```

- [x] **Step 4: Make Godot import them**

```
filesystem_manage(op="scan")
```

Then confirm Godot wrote a `.import` for each of the eight:

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && ls Assets/Images/SplashArtMurid/splash_*.png.import Assets/Images/UI/blur_background.png.import Assets/Images/UI/cutscene_dialogue.png.import
```

Expected: eight lines, no "No such file".

- [x] **Step 5: Run the suite to verify it passes**

```
test_run(suite="day_summary")
```

Expected: `test_every_new_splash_imports` PASSES. Other tests in the suite may now fail — the crop tests are addressed in Task 2. Do not fix them here.

- [x] **Step 6: Commit**

```bash
git add Assets/Images/SplashArtMurid Assets/Images/UI/blur_background.png Assets/Images/UI/blur_background.png.import Assets/Images/UI/cutscene_dialogue.png Assets/Images/UI/cutscene_dialogue.png.import docs/superpowers/mockups tests/test_day_summary.gd && git commit -m "feat(assets): land the six-student splash batch and the new UI textures"
```

---

## Task 2: Recrop the Daily Results avatars

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryAvatar.gd:23-28` (`SPLASH_CROP`)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: the six `res://Assets/Images/SplashArtMurid/splash_*.png` paths from Task 1.
- Produces: `DaySummaryAvatar.SPLASH_CROP` — a `Dictionary` keyed by the student's display name (`"Marcel"`, `"Doni"`, `"Andi"`, `"Citra"`, `"Shinta"`, `"Thea"`) returning `Rect2`. Unchanged signature: `DaySummaryAvatar.crop_for(student_name: String, tex: Texture2D, is_splash: bool = false) -> Rect2`.

Every existing crop was derived from the **old** art and is now wrong. Thea's canvas in particular changes from 550×1119 to 1080×1920.

- [x] **Step 1: Extend the "inside its texture" test to all six students**

In `tests/test_day_summary.gd`, in `test_every_named_crop_is_inside_its_texture`, replace the four-entry `paths` dict with six:

```gdscript
	var paths := {
		"Marcel": "res://Assets/Images/SplashArtMurid/splash_marcel.png",
		"Doni": "res://Assets/Images/SplashArtMurid/splash_doni.png",
		"Andi": "res://Assets/Images/SplashArtMurid/splash_andi.png",
		"Citra": "res://Assets/Images/SplashArtMurid/splash_citra.png",
		"Shinta": "res://Assets/Images/SplashArtMurid/splash_shinta.png",
		"Thea": "res://Assets/Images/SplashArtMurid/splash_thea.png",
	}
```

- [x] **Step 2: Repoint the fallback test at a genuinely unknown student**

`test_unknown_students_get_a_computed_crop` uses `"Doni"` as its stand-in for a student with no entry. Doni now has one, so the test would silently stop testing the fallback. Replace the doc comment and the name:

```gdscript
## Every student in the roster now has a named crop, so the fallback is
## reached only by a student who is not in the table at all -- a debug or
## test fixture. It must still produce a usable, correctly-shaped crop.
func test_unknown_students_get_a_computed_crop() -> void:
	var tex := load("res://Assets/Images/SplashArtMurid/splash_marcel.png") as Texture2D
	var r := DaySummaryAvatar.crop_for("Budi", tex)
	assert_true(r.size.x > 0.0 and r.size.y > 0.0,
		"fallback crop is empty")
	var aspect := r.size.x / r.size.y
	assert_true(absf(aspect - _FRAME_ASPECT) < 0.02,
		"fallback crop aspect %f is not the frame's" % aspect)
	assert_true(r.end.y <= float(tex.get_height()),
		"fallback crop runs off the bottom")
```

- [x] **Step 3: Run the suite to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: `test_every_named_crop_is_inside_its_texture` FAILS — `Doni crop runs past the bottom edge` or a missing-key error, because `SPLASH_CROP` has no `Doni`/`Citra` entry and Thea's old rect targets a 550×1119 canvas.

- [x] **Step 4: Replace the crop table**

In `Scripts/SchoolSimulation/DaySummaryAvatar.gd`, replace `SPLASH_CROP` (lines 19-28, doc comment included) with:

```gdscript
## Head-and-shoulders window into each splash, in that splash's own
## pixels. Each is FRAME_ASPECT-shaped so nothing stretches. Derived from
## the 2026-09-01 batch's content bounding boxes: head band taken as the
## top 18% of the figure, crop height 42% of figure height, centred on the
## head and lifted 1% above the crown so hair is not clipped. See the spec,
## section 3 -- adjust here, not by scaling the TextureRect.
const SPLASH_CROP := {
	"Marcel": Rect2(132, 40, 736, 782),
	"Doni": Rect2(192, 125, 702, 746),
	"Andi": Rect2(112, 0, 752, 800),
	"Citra": Rect2(167, 65, 726, 772),
	"Shinta": Rect2(160, 111, 707, 752),
	"Thea": Rect2(154, 86, 718, 763),
}
```

Also correct the class doc block at lines 10-13, which claims the batch does not share a canvas. It now does:

```gdscript
## The crop is per-student and cannot be derived from a shared rule --
## the figures differ in height, pose and framing within a common
## 1080x1920 canvas. See the spec, section 3.
```

- [x] **Step 5: Run the suite to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: `test_every_named_crop_matches_the_frame_aspect`, `test_every_named_crop_is_inside_its_texture` and `test_unknown_students_get_a_computed_crop` all PASS.

- [x] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryAvatar.gd tests/test_day_summary.gd && git commit -m "fix(day-summary): recrop every avatar against the new splash batch"
```

---

## Task 3: Flip the avatar to splash-first

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryAvatar.gd:48-62` (`set_student`)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `SPLASH_CROP` from Task 2.
- Produces: no signature change. `set_student(student: StudentData) -> void` keeps its contract; only the resolution order inside changes.

`DaySummaryAvatar.gd:48-50` carries an explicit instruction: *"The portrait leads because the splash batch is being replaced — flip these two branches back once the new art lands."* The batch has landed.

- [x] **Step 1: Flip the test that pins the old order**

In `tests/test_day_summary.gd`, replace `test_avatar_prefers_the_portrait_over_the_splash` entirely:

```gdscript
## The splash batch has landed (spec section 3.1), so the full-body art is
## now the source of truth and the portrait is the fallback. Source-scanned
## because building a StudentData with both textures set requires resources
## this suite cannot load headlessly.
func test_avatar_prefers_the_splash_over_the_portrait() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/DaySummaryAvatar.gd")
	var portrait_at := src.find("student.avatar_texture")
	var splash_at := src.find("student.splash_path")
	assert_true(portrait_at != -1, "avatar no longer reads avatar_texture")
	assert_true(splash_at != -1, "avatar no longer reads splash_path")
	assert_true(splash_at < portrait_at,
		"splash_path must be tried BEFORE avatar_texture")
```

- [x] **Step 2: Run the suite to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: `test_avatar_prefers_the_splash_over_the_portrait` FAILS with `splash_path must be tried BEFORE avatar_texture`.

- [x] **Step 3: Flip the branches**

In `Scripts/SchoolSimulation/DaySummaryAvatar.gd`, replace the doc comment and body of `set_student` (lines 48-62) with:

```gdscript
## Resolution order: the student's splash art first, then their portrait,
## then nothing. The splash leads now that the 2026-09-01 batch has landed
## -- it is full-body art cropped to a head window by SPLASH_CROP, which
## frames better than the square portrait.
func set_student(student: StudentData) -> void:
	if student == null:
		art.texture = null
		return

	var tex: Texture2D = null
	var is_splash := false
	if student.splash_path != "" and ResourceLoader.exists(student.splash_path):
		tex = load(student.splash_path)
		is_splash = true
	elif student.avatar_texture != null:
		tex = student.avatar_texture

	if tex == null:
		art.texture = null
		return
```

Everything from `var region := crop_for(...)` onward is unchanged.

- [x] **Step 4: Run the suite to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: the whole `day_summary` suite PASSES.

- [x] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryAvatar.gd tests/test_day_summary.gd && git commit -m "feat(day-summary): prefer the new splash art over the portrait"
```

---

## Task 4: Rewire all four rosters

**Files:**
- Modify: `Scripts/StudentCard/student_card.gd` (lines 901, 924, 947, 970, 993, 1016)
- Modify: `Scripts/StudentList/student_list.gd` (lines 27, 46, 65, 84, 103, 122)
- Modify: `Scripts/Debug/DebugManager.gd` (lines 35, 56, 77, 98)
- Modify: `Scripts/AturJadwal/atur_jadwal.gd` (line 588)
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: the six splash paths from Task 1.
- Produces: every `student` dictionary's `"splash"` key now resolves to a `splash_*.png`. `GameState.convert_to_student_data_array()` copies it to `StudentData.splash_path` unchanged (`Scripts/GameState.gd:224`), which is what Task 3's `set_student` reads.

There is no single source of truth for the roster — the same six students are declared verbatim in three scripts, plus a one-off fallback in a fourth. All four must move together or a student shows the wrong art depending on which screen built the dictionary.

Mapping (id → name → new path):

| id | name | new `splash` value |
|---|---|---|
| 1 | Marcel | `res://Assets/Images/SplashArtMurid/splash_marcel.png` |
| 2 | Doni | `res://Assets/Images/SplashArtMurid/splash_doni.png` |
| 3 | Andi | `res://Assets/Images/SplashArtMurid/splash_andi.png` |
| 4 | Citra | `res://Assets/Images/SplashArtMurid/splash_citra.png` |
| 5 | Shinta | `res://Assets/Images/SplashArtMurid/splash_shinta.png` |
| 6 | Thea | `res://Assets/Images/SplashArtMurid/splash_thea.png` |

- [x] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## The roster is declared verbatim in four places with no single source of
## truth (spec section 3.2). A student whose splash is updated in one file
## and not another shows different art depending on which screen built the
## dictionary, so all four are pinned together here.
func test_every_roster_points_at_the_new_splash_batch() -> void:
	var sources := [
		"res://Scripts/StudentCard/student_card.gd",
		"res://Scripts/StudentList/student_list.gd",
		"res://Scripts/Debug/DebugManager.gd",
		"res://Scripts/AturJadwal/atur_jadwal.gd",
	]
	for path in sources:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("SplashArtMurid/SplashMurid"),
			"%s still points at the legacy SplashMurid*.jpg batch" % path)
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="day_summary")
```

Expected: FAILS four times — one per source file — with `still points at the legacy SplashMurid*.jpg batch`.

- [x] **Step 3: Rewrite every legacy path**

The legacy filenames map to the new ones by id, and the id order is identical in all four files, so a single ordered substitution is safe. Run:

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && for f in Scripts/StudentCard/student_card.gd Scripts/StudentList/student_list.gd Scripts/Debug/DebugManager.gd Scripts/AturJadwal/atur_jadwal.gd; do sed -i -e 's|SplashArtMurid/SplashMurid1\.jpg|SplashArtMurid/splash_marcel.png|g' -e 's|SplashArtMurid/SplashMurid2\.jpg|SplashArtMurid/splash_doni.png|g' -e 's|SplashArtMurid/SplashMurid3\.jpg|SplashArtMurid/splash_andi.png|g' -e 's|SplashArtMurid/SplashMurid4\.jpg|SplashArtMurid/splash_citra.png|g' -e 's|SplashArtMurid/SplashMurid5\.jpg|SplashArtMurid/splash_shinta.png|g' -e 's|SplashArtMurid/SplashMurid6\.jpg|SplashArtMurid/splash_thea.png|g' "$f"; done
```

- [x] **Step 4: Verify each replacement landed on the right student**

The substitution is by filename, not by name, so confirm each line sits in the block for the student it belongs to:

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep -n -B6 'SplashArtMurid/splash_' Scripts/StudentCard/student_card.gd | grep -E '"name"|splash_'
```

Expected: six pairs, each `"name": "X"` immediately followed within the block by `splash_<lowercase x>.png` — Marcel/marcel, Doni/doni, Andi/andi, Citra/citra, Shinta/shinta, Thea/thea. If any pair is crossed, fix that line by hand.

- [x] **Step 5: Run the suite to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: `test_every_roster_points_at_the_new_splash_batch` PASSES.

- [x] **Step 6: Run the full suite for regressions**

```
test_run()
```

Expected: all suites green. `student_card`, `student_list`, `debug_manager` and `atur_jadwal` all source-scan their rosters; if one pins a legacy path it will surface here.

- [x] **Step 7: Commit**

```bash
git add Scripts/StudentCard/student_card.gd Scripts/StudentList/student_list.gd Scripts/Debug/DebugManager.gd Scripts/AturJadwal/atur_jadwal.gd tests/test_day_summary.gd && git commit -m "feat(roster): point every student at the new splash batch"
```

---

## Verification

- [x] `test_run()` — every suite green.
- [x] Screenshot check: seed playtest state (debug overlay `F1` → ⚡ Seed Playtest State), teleport to SchoolDay, and confirm the Daily Results avatars show correctly-framed heads for all six students, not shoulders or empty space.
