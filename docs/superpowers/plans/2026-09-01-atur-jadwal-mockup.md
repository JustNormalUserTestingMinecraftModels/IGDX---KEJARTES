# Atur Jadwal Mockup Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **STATUS — executed 2026-09-01. Tasks 1, 3 and 4 complete; Task 2 (the
> `ShelfEdge` theme variation) DEFERRED. Suite green (566/566, 45 suites).**
>
> **Task 2 is deferred, not abandoned.** The tokens and the variation were
> written exactly as planned, but the running editor cannot pick up a new
> `@export` on a `class_name Resource`: `DesignTokens.load_default()` returns
> the cached `design_tokens.tres` instance, so `tokens.shelf_face` evaluated to
> `Nil` and every `ThemeFactory.build()` call threw. Neither
> `filesystem_manage(op="scan")` nor `script_patch` (which reports
> `GDScript reload failed with error code 43`) clears it — it needs a real
> editor restart, which is also why CLAUDE.md makes the theme rebake a manual
> step. Rather than leave 17 red tests, the token/variation/test trio was
> reverted and the shelf now ships as two `ColorRect`s in the scene —
> `ShelfFace` (`#B37D4D`, y 766-817) and `ShelfEdge` (`#77573A`, y 817-843).
> That breaks no project rule (the ban is on `theme_override_*` in scenes and
> `Color(` literals in *scripts*; a ColorRect's `color` is scene data, as in
> `cut_scene.tscn`'s `FadeOverlay`) and it stays fully viewport-editable.
> **To finish it:** restart Godot, re-apply the Task 2 diff, run
> `Scripts/Design/BakeTheme.gd` (File > Run), then replace the two ColorRects
> with one `ShelfEdge`-variation Panel spanning y 766-843.
>
> **Deviation, Task 1:** the splash→StudentList wiring already worked, as the
> spec predicted; only the reparent and the four `BGStat/...` tutorial path
> strings were needed. The three bare `"TextureButton"` references
> (`atur_jadwal.gd:210`, `:681`, `:1114`) were correctly left alone.
>
> **Addition, Task 3:** the scene's baked splash placeholder was an opaque
> screenshot (`Assets/Images/UI/Screenshot 2026-08-02 104848.png`) that hid the
> new backdrop in the editor viewport. Repointed at `splash_marcel.png` so the
> viewport shows the real composition. The runtime swap is unaffected.
>
> All scene edits were applied through the editor (spec §6.0), and
> `batch_execute` with the plugin command names (`create_node`, `set_property`,
> `move_node`, `delete_node`) works well for this — one call per node instead
> of a round-trip per property.

> **STATUS — 2026-09-01, sticky-note polish (separate plan).** The five day
> sticky notes were reworked into a reusable
> `Scenes/AturJadwal/DayStickyNote.tscn` template (`DayStickyNote.gd`). Plan:
> `docs/superpowers/plans/2026-09-01-atur-jadwal-sticky-note-polish.md`.
>
> - Each scheduled note now shows three lines — day / pembelajaran name
>   (`Akademik` / `Seni Budaya` / `Atletik` / `Wirausaha` / `Libur`) / a
>   one-word flavour label (`Fokus` / `Berkarya` / `Semangat` / `Cuan` /
>   `Santai`) — plus a category icon peeking from the top-right corner and a
>   soft drop shadow (`Scripts/Shaders/soft_shadow.gdshader`).
> - Assigning a day plays a squash-pop with the icon sliding in; the idle
>   sway is unchanged.
> - National-holiday days (e.g. Week 3 Rabu) render locked gold with the real
>   holiday title, a `Libur Nasional` flavour line, and a padlock glyph.
> - **Deferred art:** `icon_wirausaha_placeholder.png`,
>   `icon_istirahat_placeholder.png` and `icon_libur_nasional_placeholder.png`
>   in `Assets/Images/AturJadwal/` are flat geometric placeholders drawn by
>   `Scripts/Design/GenerateStickyNoteIcons.gd` (File > Run). The visual team
>   overrides them in place — keep the file names. The three skill categories
>   already use the real `stat_*.png`.
> - No `ThemeFactory` variation was added, so no theme rebake was needed —
>   the note reuses `H2Label` / `CaptionLabel` / `MicroLabel`.

**Goal:** Rebuild the top third of Atur Jadwal to `mockup_atur_jadwal.png` — blurred classroom backdrop, wooden shelf, splash art on the left, five icon-and-pill stat rows on the right — while leaving the whiteboard and sticky notes exactly as they are.

**Architecture:** The five stat bars currently live in `BGStat`, a **child of the splash-art `TextureButton`**, so tapping a progress pill navigates to StudentList. Task 1 reparents `BGStat` to the root, which is what "separate the splash art from the progress pill" means (spec §1.3) — the splash→StudentList wiring itself already works and is untouched. Tasks 2-4 then lay the mockup's chrome in: a `Backdrop` TextureRect over the whiteboard's top band, a `Shelf` Panel wearing a new `ShelfEdge` theme variation, the splash resized so every student's figure lands in the mockup's window without clipping, and the five rows repositioned with their icons.

**Tech Stack:** Godot 4.6, GDScript, `godot-ai` MCP (`filesystem_manage`, `test_run`), `Scripts/Design/BakeTheme.gd` (manual editor run).

**Spec:** `docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md`

**Depends on:** `2026-09-01-splash-art-batch.md` (both the new splash art and `blur_background.png`). Run that plan first.

## Global Constraints

- **Never hand-edit a `.tscn` as text.** The Godot editor caches every scene and its
  in-memory copy wins — a text edit is invisible to `load()` and is silently
  overwritten by the next `scene_save`. Neither `scan`, `reimport`, nor
  `scene_open(force_reload=true)` evicts the cache. Every scene change below states the
  intended **end state**; apply it as `scene_open` → `node_create` /
  `node_set_property` / `node_manage` → `scene_save`. See spec §6.0 for the
  gotchas (`anchors_preset` is inert; numbers must be passed unquoted;
  `node_create` appends last so use `node_manage(op="move")` for z-order).
- Godot **4.6**, portrait **1080×1920**, `mobile` renderer.
- **The whiteboard and sticky notes do not move.** `BGHari` and its five `TextureButton` children (`Senin`…`Jumat`) keep their current textures, geometry and parenting. The mockup's lower-panel measurements in spec §4.3 are reference only.
- **Never add a `theme_override_*`.** `tests/test_atur_jadwal.gd:97` scans the whole scene. Layout-only constants (`separation`, `margin_*`) are the only exception.
- **No `Color(` literal in `atur_jadwal.gd`.** `tests/test_atur_jadwal.gd:104` runs the regex `Color\s*\(` and requires zero matches. The shelf colours go in `DesignTokens`, not the script.
- **`tests/test_viewport_editability.gd` freezes `Scripts/AturJadwal/atur_jadwal.gd` at 17** and it may only go down. This plan adds **zero** `.new()` calls — every node it introduces is authored in the `.tscn`.
- **The Penjadwalan popup's geometry is pinned to exact pixels** by five tests (`test_atur_jadwal.gd:257-325`): `Rows` offsets 375/1024/102, separation 40, `PopupBack` at 329/1170, row height 180, card 1394×1394 centred at −105. **Do not touch anything under `Penjadwalan`.**
- **`ext_resource` uids must be real.** `tests/test_project_hygiene.gd:48-72` asserts `ResourceUID.get_id_path(uid) == path` for every scene. Read the uid from the generated `.import`.
- **Adding a theme variation requires a manual rebake**: open `Scripts/Design/BakeTheme.gd` in the editor, File > Run (Ctrl+Shift+X). There is no headless path.
- **Rescan after editing any `.gd`, before running tests.**
- Tests must be `@tool`; **no test may be a coroutine**.
- Assertion helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_not_null`, `assert_gt`, `assert_has_key`, `assert_contains`, `assert_is_error`, `track()`. No `assert_lt` / `assert_null` / `assert_almost_eq`.

### The stat-row order is deliberately not the node order

`kepribadian1` is **mood** and `kepribadian2` is **energy** (CLAUDE.md, and `student_card.tscn`'s labels confirm it). The mockup's fourth row is the lightning glyph (energy) and its fifth is the smiley (mood). So top-to-bottom the rows are:

| Mockup row | Stat | Node | `category` |
|---|---|---|---|
| 1 | Akademis | `Akademis1` | `Akademis` |
| 2 | Seni Budaya | `Akademis2` | `SeniBudaya` |
| 3 | Olahraga | `Akademis3` | `Olahraga` |
| 4 | **Energy** | **`Kepribadian2`** | `Libur` |
| 5 | **Mood** | **`Kepribadian1`** | `Istirahat` |

Rows 4 and 5 are swapped relative to the node numbering. Getting this backwards puts the lightning bolt on the mood bar. The `category` column must not change — `tests/test_atur_jadwal.gd:193` pins each one.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scenes/AturJadwal/atur_jadwal.tscn` | The screen | `BGStat` reparented; `Backdrop`, `Shelf`, 5 icons added; splash and bars repositioned |
| `Scripts/AturJadwal/atur_jadwal.gd` | Screen controller | 5 `@onready` paths, 4 tutorial path strings |
| `Scripts/Design/DesignTokens.gd` | Token definitions | 2 shelf colours |
| `Scripts/Design/ThemeFactory.gd` | Theme builder | `ShelfEdge` variation |
| `Assets/Theme/kejartes_theme.tres` | Baked theme | regenerated |
| `tests/test_atur_jadwal.gd` | Pins the screen | paths updated, 3 tests added |
| `tests/test_theme_factory.gd` | Pins the theme | 1 test added |

---

## Task 1: Separate the splash art from the progress pills

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` — reparent `BGStat`
- Modify: `Scripts/AturJadwal/atur_jadwal.gd:52-56, 222, 223, 239, 247`
- Test: `tests/test_atur_jadwal.gd:193-199`

**Interfaces:**
- Consumes: nothing.
- Produces: node path `BGStat` at the root, with the same five children `Akademis1`, `Akademis2`, `Akademis3`, `Kepribadian1`, `Kepribadian2`, each still a `StatBar` with its unchanged `category`. `$TextureButton` keeps its name, its `pressed` wiring and its `_on_select_student_pressed` handler.

`BGStat` sits inside the splash-art button, so its five bars are inside the button's hit area and tapping a pill navigates away to StudentList. That is the bug. Note the guard at `atur_jadwal.gd:681` and the check at `:1114` both key on the bare string `"TextureButton"`, which is unaffected; only the four tutorial paths that go *through* `BGStat` change.

- [x] **Step 1: Write the failing test**

In `tests/test_atur_jadwal.gd`, replace the five path keys in `test_bg_stat_bars_are_statbars` (lines 195-199):

```gdscript
		"BGStat/Akademis1": "Akademis",
		"BGStat/Akademis2": "SeniBudaya",
		"BGStat/Akademis3": "Olahraga",
		"BGStat/Kepribadian1": "Istirahat",
		"BGStat/Kepribadian2": "Libur",
```

Then append a test that pins the decoupling itself:

```gdscript
## The five stat bars used to live inside the splash-art TextureButton, so
## tapping a progress pill fell through to the button and navigated to
## StudentList. They must be siblings, not descendants.
func test_stat_pills_are_not_inside_the_splash_button() -> void:
	var splash := _screen.get_node_or_null("TextureButton")
	assert_not_null(splash, "the splash TextureButton is gone")
	assert_true(splash.get_node_or_null("BGStat") == null,
		"BGStat is still a child of the splash button")
	assert_not_null(_screen.get_node_or_null("BGStat"),
		"BGStat is not at the root")
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="atur_jadwal")
```

Expected: `test_bg_stat_bars_are_statbars` FAILS (node `BGStat/Akademis1` not found) and `test_stat_pills_are_not_inside_the_splash_button` FAILS with `BGStat is still a child of the splash button`.

- [x] **Step 3: Reparent the node in the scene**

In `Scenes/AturJadwal/atur_jadwal.tscn`:

1. Change the `BGStat` node header from `parent="TextureButton"` to `parent="."`:

```
[node name="BGStat" type="Control" parent="."]
```

2. Change all five bar node headers from `parent="TextureButton/BGStat"` to `parent="BGStat"`:

```
[node name="Akademis1" type="ProgressBar" parent="BGStat"]
```

…and the same for `Akademis2`, `Akademis3`, `Kepribadian1`, `Kepribadian2`.

3. Move the whole `BGStat` block (its header plus the five bar blocks) so it sits **after** the `TextureButton` block and before `LabelNama`. Godot orders children by their appearance in the file; keeping `BGStat` after `TextureButton` means the pills draw over the splash, matching the mockup.

- [x] **Step 4: Update the script's node paths**

In `Scripts/AturJadwal/atur_jadwal.gd`, lines 52-56:

```gdscript
@onready var ak1_bar = $BGStat/Akademis1
@onready var ak2_bar = $BGStat/Akademis2
@onready var ak3_bar = $BGStat/Akademis3
@onready var kp1_bar = $BGStat/Kepribadian1
@onready var kp2_bar = $BGStat/Kepribadian2
```

- [x] **Step 5: Update the four tutorial path strings**

Still in `atur_jadwal.gd`, strip the `TextureButton/` prefix from every path that goes through `BGStat`. Line 222:

```gdscript
			["Evaluasi Murid", "Murid ini membutuhkan bantuan agar mereka terfokuskan untuk meningkatkan apa yang ketertinggalan.", "BGStat/Akademis1,BGStat/Akademis2,BGStat/Akademis3", ""],
```

Line 223:

```gdscript
			["Perhatian Akademis", "Wah, sepertinya \"Nama Murid\" mempunyai nilai akademis yang bagus!", "BGStat/Akademis1", ""],
```

Line 239:

```gdscript
		alt.target_node_path = "BGStat/Akademis1"
```

Line 247:

```gdscript
			["Perubahan Stats & Energy", "Kedua, stats akan mempunyai nilai plus berdasarkan berapa pelajaran per hari yang mereka ambil!\n\nTapi Mood dan energi mereka akan berkurang!", "BGStat/Akademis1/ValueLabel,BGStat/Akademis2/ValueLabel,BGStat/Akademis3/ValueLabel,BGStat/Kepribadian1/ValueLabel,BGStat/Kepribadian2/ValueLabel", ""],
```

Leave line 210 (`"TextureButton"`), line 681 (`"TextureButton" in …`) and line 1114 (`== "TextureButton"`) alone — all three refer to the splash button itself, which has not moved.

- [x] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: both tests PASS and the whole suite is green — including `test_interactive_controls_meet_the_minimum_touch_target`, which walks a hardcoded node-path list that does not include `BGStat`.

- [x] **Step 7: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn Scripts/AturJadwal/atur_jadwal.gd tests/test_atur_jadwal.gd && git commit -m "fix(atur-jadwal): lift the stat pills out of the splash-art button"
```

---

## Task 2: Add the shelf theme variation

> **NOT DONE — reverted 2026-09-01, blocked on an editor restart.** Steps
> below are unchecked because they don't reflect the shipped state. See the
> file's top STATUS block for what actually shipped in its place (two
> `ColorRect`s in the scene) and the exact restart-then-reapply procedure.

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (Category Accents block, around line 95)
- Modify: `Scripts/Design/ThemeFactory.gd` (`_build_panels`, after `Scrim` at line 265)
- Modify: `Assets/Theme/kejartes_theme.tres` (regenerated, not hand-edited)
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `DesignTokens.shelf_face: Color` and `DesignTokens.shelf_edge: Color`; a theme type variation named `ShelfEdge` varying `Panel`, whose `panel` stylebox is a `StyleBoxFlat` with `bg_color = shelf_face` and `border_width_bottom = 26` in `shelf_edge`.

The mockup's divider is two flat bands — `#B37D4D` for 51 px then `#77573A` for 26 px. One `Panel` with a bottom border reproduces both exactly, so the scene needs one node rather than two `ColorRect`s carrying hardcoded colours.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_theme_factory.gd`:

```gdscript
## Atur Jadwal's wooden divider, measured off mockup_atur_jadwal.png: a
## 51px light face over a 26px dark underside. One Panel with a bottom
## border draws both bands, so the scene needs one node, not two
## ColorRects carrying hardcoded colours.
func test_shelf_edge_variation_draws_both_mockup_bands() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)

	assert_true(theme.get_type_list().has("ShelfEdge"),
		"ShelfEdge variation must exist")
	assert_eq(theme.get_type_variation_base("ShelfEdge"), &"Panel",
		"ShelfEdge must vary the Panel type")

	var sb := theme.get_stylebox("panel", "ShelfEdge")
	assert_true(sb is StyleBoxFlat,
		"ShelfEdge must be a flat box, not textured")
	assert_eq(sb.bg_color, tokens.shelf_face,
		"ShelfEdge face must read from the shelf_face token")
	assert_eq(sb.border_color, tokens.shelf_edge,
		"ShelfEdge underside must read from the shelf_edge token")
	assert_eq(sb.border_width_bottom, 26,
		"the mockup's dark band is 26px")
	assert_eq(sb.border_width_top, 0, "the shelf has no top border")
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="theme_factory")
```

Expected: FAIL with `ShelfEdge variation must exist`.

- [ ] **Step 3: Add the tokens**

In `Scripts/Design/DesignTokens.gd`, at the end of the Category Accents block (after `cat_wirausaha`, around line 95), add:

```gdscript

## The light face of Atur Jadwal's wooden shelf, under the student header.
## Measured off mockup_atur_jadwal.png (band y 766-816).
@export var shelf_face: Color = Color("#b37d4d")
## The shelf's shadowed underside, drawn as the face's bottom border.
## Measured off mockup_atur_jadwal.png (band y 817-842).
@export var shelf_edge: Color = Color("#77573a")
```

The `##` line immediately above each `@export`, with no blank line between, is required by `tests/test_script_documentation.gd`.

- [ ] **Step 4: Add the variation**

In `Scripts/Design/ThemeFactory.gd`, inside `_build_panels`, immediately after the `Scrim` block (which ends at line 265), add:

```gdscript

	# -- Atur Jadwal's shelf. The mockup's divider is two flat bands; one
	# -- Panel with a bottom border draws both, so the scene needs a single
	# -- node instead of two ColorRects holding raw colours. --
	theme.add_type("ShelfEdge")
	theme.set_type_variation("ShelfEdge", "Panel")
	var shelf := StyleBoxFlat.new()
	shelf.bg_color = tokens.shelf_face
	shelf.border_width_bottom = 26
	shelf.border_color = tokens.shelf_edge
	theme.set_stylebox("panel", "ShelfEdge", shelf)
```

- [ ] **Step 5: Rebake the theme**

This step is manual and has no headless equivalent. In the Godot editor: open `Scripts/Design/BakeTheme.gd`, then **File > Run** (Ctrl+Shift+X). The output panel prints the new type count.

- [ ] **Step 6: Verify the bake landed on disk**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep -c "ShelfEdge" Assets/Theme/kejartes_theme.tres
```

Expected: a non-zero count. If it prints `0`, the rebake did not run — repeat Step 5 before continuing, or every scene-level test in Task 3 will fail for the wrong reason.

- [ ] **Step 7: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="theme_factory")
```

Expected: PASS. Then run the whole suite — several suites load the baked theme from disk and a bad bake surfaces there:

```
test_run()
```

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd && git commit -m "feat(theme): add the ShelfEdge variation for Atur Jadwal's divider"
```

---

## Task 3: Lay in the backdrop, the shelf, and the splash

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn`
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `res://Assets/Images/UI/blur_background.png` (plan 1), the `ShelfEdge` variation (Task 2), `BGStat` at the root (Task 1).
- Produces: node paths `Backdrop` (TextureRect) and `Shelf` (Panel) at the root. `TextureButton` keeps its path and its wiring; only its rect changes.

Child order at the root becomes: `BGHari` (whiteboard, unchanged, index 0) → `Backdrop` → `TextureButton` → `BGStat` → `Shelf` → everything else unchanged. The backdrop covers the whiteboard's top band; the shelf draws over the splash's feet, which is what gives the mockup's clean cut at y=766 without any clipping container.

**Splash sizing.** The mockup's figure window is x 47…416, y 56…765. Rather than clip, size the button to **0,0 → 431,766** — an aspect of 0.5626 against the source art's 0.5625, so a plain uniform scale fits with no distortion. Scaled by 431/1080 = 0.399, every student's figure lands inside x 61…381, y 6…765, consistently left-placed with the feet meeting the shelf. No per-student tuning, and the node keeps `ignore_texture_size = true`.

- [x] **Step 1: Write the failing test**

Append to `tests/test_atur_jadwal.gd`:

```gdscript
## The mockup's top band: blurred classroom from y=0 to the shelf at 766,
## then the wooden divider to 843, then the untouched whiteboard. The
## backdrop must sit above BGHari (or the whiteboard covers it) and below
## the splash and pills (or it covers them).
func test_top_band_matches_the_mockup() -> void:
	var backdrop := _screen.get_node_or_null("Backdrop") as TextureRect
	assert_not_null(backdrop, "Backdrop TextureRect is missing")
	assert_not_null(backdrop.texture, "Backdrop has no texture")
	assert_eq(backdrop.texture.resource_path,
		"res://Assets/Images/UI/blur_background.png",
		"Backdrop is not drawing blur_background.png")
	assert_eq(backdrop.offset_bottom, 766.0,
		"the backdrop band ends at the shelf line")

	var shelf := _screen.get_node_or_null("Shelf") as Panel
	assert_not_null(shelf, "Shelf Panel is missing")
	assert_eq(shelf.theme_type_variation, &"ShelfEdge",
		"Shelf must wear the ShelfEdge variation")
	assert_eq(shelf.offset_top, 766.0, "shelf starts where the backdrop ends")
	assert_eq(shelf.offset_bottom, 843.0, "shelf ends where the panel starts")

	var whiteboard := _screen.get_node_or_null("BGHari")
	assert_not_null(whiteboard, "BGHari is gone")
	assert_true(whiteboard.get_index() < backdrop.get_index(),
		"the backdrop must draw over the whiteboard")

	var splash := _screen.get_node_or_null("TextureButton")
	assert_true(backdrop.get_index() < splash.get_index(),
		"the splash must draw over the backdrop")


## Sized to the source art's own aspect (431/766 = 0.5626 against
## 1080/1920 = 0.5625) so a uniform scale fits with no distortion and no
## clipping container -- the shelf covers the feet instead.
func test_splash_is_sized_to_the_mockup_window() -> void:
	var splash := _screen.get_node_or_null("TextureButton") as Control
	assert_not_null(splash, "the splash TextureButton is gone")
	assert_eq(splash.offset_left, 0.0, "splash left")
	assert_eq(splash.offset_top, 0.0, "splash top")
	assert_eq(splash.offset_right, 431.0, "splash right")
	assert_eq(splash.offset_bottom, 766.0, "splash bottom")


## The whiteboard and its five sticky notes are explicitly out of scope for
## the restyle -- they must survive it untouched.
func test_the_whiteboard_and_sticky_notes_are_unchanged() -> void:
	var board := _screen.get_node_or_null("BGHari") as TextureRect
	assert_not_null(board, "BGHari is gone")
	assert_eq(board.texture.resource_path,
		"res://Assets/Images/UI/whiteboard.png",
		"the whiteboard texture changed")
	for day in ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]:
		var note := _screen.get_node_or_null("BGHari/%s" % day) as Control
		assert_not_null(note, "sticky note %s is gone or was reparented" % day)
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="atur_jadwal")
```

Expected: `test_top_band_matches_the_mockup` FAILS with `Backdrop TextureRect is missing`.

- [x] **Step 3: Read the generated uid**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep '^uid=' Assets/Images/UI/blur_background.png.import
```

- [x] **Step 4: Add the two nodes**

In `Scenes/AturJadwal/atur_jadwal.tscn`:

1. Bump `load_steps` on line 1 by 1.

2. Add an `ext_resource` line alongside the others, with the uid from Step 3 and an `id` that does not collide (`18_backdrop` is free):

```
[ext_resource type="Texture2D" uid="uid://REPLACE_WITH_STEP_3_UID" path="res://Assets/Images/UI/blur_background.png" id="18_backdrop"]
```

3. Insert the `Backdrop` block **immediately after** the last `BGHari/...` sticky-note block and **before** the `TextureButton` block:

```
[node name="Backdrop" type="TextureRect" parent="."]
layout_mode = 0
offset_right = 1080.0
offset_bottom = 766.0
mouse_filter = 2
texture = ExtResource("18_backdrop")
expand_mode = 1
stretch_mode = 6
```

4. Insert the `Shelf` block **immediately after** the `BGStat` block (so it draws over the splash's feet):

```
[node name="Shelf" type="Panel" parent="."]
layout_mode = 0
offset_top = 766.0
offset_right = 1080.0
offset_bottom = 843.0
mouse_filter = 2
theme_type_variation = &"ShelfEdge"
```

Both carry `mouse_filter = 2` (`MOUSE_FILTER_IGNORE`) so neither eats taps meant for the splash, the pills or the sticky notes.

- [x] **Step 5: Resize the splash button**

In the `[node name="TextureButton" type="TextureButton" parent="."]` block, replace the whole anchor/offset group — the node currently uses `anchors_preset = -1` with fractional anchors that fight explicit offsets:

```
[node name="TextureButton" type="TextureButton" parent="." unique_id=1727823902]
layout_mode = 0
offset_right = 431.0
offset_bottom = 766.0
texture_normal = ExtResource("3_dc5y4")
ignore_texture_size = true
stretch_mode = 0
```

Delete the `anchors_preset`, `anchor_left`, `anchor_top`, `anchor_right`, `anchor_bottom`, `offset_left` and `offset_top` lines — `layout_mode = 0` with omitted left/top means 0,0. Keep `unique_id`, `texture_normal`, `ignore_texture_size` and `stretch_mode` exactly as they are; `stretch_mode = 0` is `STRETCH_SCALE`, which is correct now that the box matches the art's aspect.

- [x] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: all three new tests PASS, and the pre-existing suite stays green — especially `test_scene_has_no_theme_overrides`, `test_interactive_controls_meet_the_minimum_touch_target`, and the five Penjadwalan geometry tests.

- [x] **Step 7: Confirm the ratchet did not move**

```
test_run(suite="viewport_editability")
```

Expected: PASS. Every node added here is scene data, so `atur_jadwal.gd` must still count exactly 17.

- [x] **Step 8: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd && git commit -m "feat(atur-jadwal): lay in the mockup's backdrop, shelf and splash window"
```

---

## Task 4: Reposition the stat rows and add their icons

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` — `BGStat` and its five bars; five new `TextureRect` icons
- Test: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `BGStat` at the root (Task 1).
- Produces: node paths `BGStat/IconAkademis1`, `BGStat/IconAkademis2`, `BGStat/IconAkademis3`, `BGStat/IconKepribadian2`, `BGStat/IconKepribadian1`. The five bar node names and their `category` values are unchanged.

Measured pill geometry is x 649…973, height ~70, at y 129 / 258 / 384 / 511 / 628. The mockup's pitch is irregular (129, 126, 127, 117 — hand-placed art), so the build uses a **uniform 126 px pitch from y=129**, landing rows at 129 / 255 / 381 / 507 / 633. Maximum drift from the mockup is 5 px. Icons are 88×88 at x 523, vertically centred on their pill.

Re-read the row-order table in the Global Constraints before writing this: **row 4 is `Kepribadian2` (energy) and row 5 is `Kepribadian1` (mood)**.

| Row | Bar node | Bar offsets (L,T,R,B) | Icon node | Icon offsets (L,T,R,B) | Icon texture |
|---|---|---|---|---|---|
| 1 | `Akademis1` | 649, 129, 973, 199 | `IconAkademis1` | 523, 120, 611, 208 | `13_icon_akademis` |
| 2 | `Akademis2` | 649, 255, 973, 325 | `IconAkademis2` | 523, 246, 611, 334 | `14_icon_seni` |
| 3 | `Akademis3` | 649, 381, 973, 451 | `IconAkademis3` | 523, 372, 611, 460 | `15_icon_olahraga` |
| 4 | `Kepribadian2` | 649, 507, 973, 577 | `IconKepribadian2` | 523, 498, 611, 586 | `16_icon_energy` |
| 5 | `Kepribadian1` | 649, 633, 973, 703 | `IconKepribadian1` | 523, 624, 611, 712 | `17_icon_mood` |

The five icon `ext_resource` ids already exist in the scene (`13_icon_akademis` … `17_icon_mood`, all pointing at `res://Assets/Images/StudentCard/stat_*.png`) and are currently declared but bound to no node. No new `ext_resource` is needed.

- [x] **Step 1: Write the failing test**

Append to `tests/test_atur_jadwal.gd`:

```gdscript
## Uniform 126px pitch from y=129. The mockup's own pitch drifts (129,
## 126, 127, 117) because the art was hand-placed; a uniform pitch is
## within 5px of it everywhere and is what a container can express.
func test_stat_rows_sit_on_the_mockup_grid() -> void:
	var expected := {
		"Akademis1": 129.0,
		"Akademis2": 255.0,
		"Akademis3": 381.0,
		"Kepribadian2": 507.0,
		"Kepribadian1": 633.0,
	}
	for bar_name in expected:
		var bar := _screen.get_node_or_null("BGStat/%s" % bar_name) as Control
		assert_not_null(bar, "BGStat/%s is missing" % bar_name)
		assert_eq(bar.offset_top, expected[bar_name],
			"%s row top" % bar_name)
		assert_eq(bar.offset_bottom, expected[bar_name] + 70.0,
			"%s row height must be the mockup's 70px" % bar_name)
		assert_eq(bar.offset_left, 649.0, "%s pill left" % bar_name)
		assert_eq(bar.offset_right, 973.0, "%s pill right" % bar_name)


## kepribadian1 is MOOD and kepribadian2 is ENERGY, but the mockup's
## fourth row is the lightning glyph and its fifth is the smiley. The
## visual order is therefore swapped from the node numbering -- getting it
## backwards puts the lightning bolt on the mood bar.
func test_each_row_carries_its_mockup_icon() -> void:
	var expected := {
		"IconAkademis1": "res://Assets/Images/StudentCard/stat_akademis.png",
		"IconAkademis2": "res://Assets/Images/StudentCard/stat_senibudaya.png",
		"IconAkademis3": "res://Assets/Images/StudentCard/stat_olahraga.png",
		"IconKepribadian2": "res://Assets/Images/StudentCard/stat_energy.png",
		"IconKepribadian1": "res://Assets/Images/StudentCard/stat_mood.png",
	}
	for icon_name in expected:
		var icon := _screen.get_node_or_null("BGStat/%s" % icon_name) as TextureRect
		assert_not_null(icon, "BGStat/%s is missing" % icon_name)
		assert_not_null(icon.texture, "%s has no texture" % icon_name)
		assert_eq(icon.texture.resource_path, expected[icon_name],
			"%s is drawing the wrong glyph" % icon_name)

	# Each icon is vertically centred on the pill it labels.
	var pairs := {
		"IconAkademis1": "Akademis1",
		"IconAkademis2": "Akademis2",
		"IconAkademis3": "Akademis3",
		"IconKepribadian2": "Kepribadian2",
		"IconKepribadian1": "Kepribadian1",
	}
	for icon_name in pairs:
		var icon := _screen.get_node_or_null("BGStat/%s" % icon_name) as Control
		var bar := _screen.get_node_or_null("BGStat/%s" % pairs[icon_name]) as Control
		var icon_mid := (icon.offset_top + icon.offset_bottom) / 2.0
		var bar_mid := (bar.offset_top + bar.offset_bottom) / 2.0
		assert_true(absf(icon_mid - bar_mid) <= 1.0,
			"%s is not centred on %s" % [icon_name, pairs[icon_name]])
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="atur_jadwal")
```

Expected: `test_stat_rows_sit_on_the_mockup_grid` FAILS on `Akademis1 row top` (the node currently sits at 37), and `test_each_row_carries_its_mockup_icon` FAILS with `BGStat/IconAkademis1 is missing`.

- [x] **Step 3: Make BGStat a full-rect container**

`BGStat` currently sits at `offset 530,4 → 1059,604`, so its children's offsets are relative to that corner. The measured mockup values are screen coordinates, so make `BGStat` cover the screen and the numbers in the table can be used directly:

```
[node name="BGStat" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
```

`mouse_filter = 2` on the container keeps it from swallowing taps; the bars set their own filter.

- [x] **Step 4: Reposition the five bars**

For each of the five bar blocks under `parent="BGStat"`, replace its `offset_left` / `offset_top` / `offset_right` / `offset_bottom` lines with the row's values from the table above. For example `Akademis1`:

```
offset_left = 649.0
offset_top = 129.0
offset_right = 973.0
offset_bottom = 199.0
```

Leave `script`, `category`, `max_value`, `show_percentage` and `value` untouched on every bar. Do not renumber or rename any node.

- [x] **Step 5: Add the five icons**

Insert these five blocks inside `BGStat`, after the five bar blocks:

```
[node name="IconAkademis1" type="TextureRect" parent="BGStat"]
layout_mode = 0
offset_left = 523.0
offset_top = 120.0
offset_right = 611.0
offset_bottom = 208.0
mouse_filter = 2
texture = ExtResource("13_icon_akademis")
expand_mode = 1
stretch_mode = 5

[node name="IconAkademis2" type="TextureRect" parent="BGStat"]
layout_mode = 0
offset_left = 523.0
offset_top = 246.0
offset_right = 611.0
offset_bottom = 334.0
mouse_filter = 2
texture = ExtResource("14_icon_seni")
expand_mode = 1
stretch_mode = 5

[node name="IconAkademis3" type="TextureRect" parent="BGStat"]
layout_mode = 0
offset_left = 523.0
offset_top = 372.0
offset_right = 611.0
offset_bottom = 460.0
mouse_filter = 2
texture = ExtResource("15_icon_olahraga")
expand_mode = 1
stretch_mode = 5

[node name="IconKepribadian2" type="TextureRect" parent="BGStat"]
layout_mode = 0
offset_left = 523.0
offset_top = 498.0
offset_right = 611.0
offset_bottom = 586.0
mouse_filter = 2
texture = ExtResource("16_icon_energy")
expand_mode = 1
stretch_mode = 5

[node name="IconKepribadian1" type="TextureRect" parent="BGStat"]
layout_mode = 0
offset_left = 523.0
offset_top = 624.0
offset_right = 611.0
offset_bottom = 712.0
mouse_filter = 2
texture = ExtResource("17_icon_mood")
expand_mode = 1
stretch_mode = 5
```

`expand_mode = 1` is `EXPAND_IGNORE_SIZE`; `stretch_mode = 5` is `STRETCH_KEEP_ASPECT_CENTERED`, matching how StudentCard draws the same five glyphs.

- [x] **Step 6: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="atur_jadwal")
```

Expected: both new tests PASS and the suite is green.

- [x] **Step 7: Run the full suite**

```
test_run()
```

Expected: every suite green, `project_hygiene` (uid resolution) and `viewport_editability` included.

- [x] **Step 8: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd && git commit -m "feat(atur-jadwal): lay the stat rows and their icons onto the mockup grid"
```

---

## Verification

- [x] `test_run()` — every suite green.
- [x] Screenshot check. Seed playtest state (`F1` → ⚡ Seed Playtest State), teleport to AturJadwal, and compare against `docs/superpowers/mockups/mockup_atur_jadwal.png`:
  - blurred classroom fills y 0…766, wooden shelf 766…843, whiteboard below, unchanged;
  - the student's figure stands on the left with its feet at the shelf line;
  - five icon-and-pill rows on the right, glyphs in mockup order — cap, gunungan, dumbbell, **lightning**, **smiley**;
  - the five sticky notes are exactly where they were.
- [x] Tap check, the point of Task 1: tap a **progress pill** — nothing should happen. Tap the **splash art** — StudentList opens.
- [x] Page through all six students (via StudentList) and confirm every figure frames consistently in the window, none clipped at the side or floating above the shelf.

## Out of scope

- The mockup's "MINGGU 1 DARI 24" title and its 220×228 sticky-note grid — spec §4.3. `LabelTanggal` keeps its current "Agustus — Minggu Pertama" wording.
- Anything under `Penjadwalan`; its geometry is pinned to exact pixels by five tests.
- Lowering `atur_jadwal.gd`'s `BASELINE` of 17 by converting its runtime-built tutorial chrome — a real opportunity now that the screen is being edited, but a separate pass.
