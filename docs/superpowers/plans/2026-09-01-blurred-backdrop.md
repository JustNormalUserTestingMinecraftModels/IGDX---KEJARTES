# Blurred Backdrop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **STATUS — executed 2026-09-01, both tasks complete. Suite green (555/555,
> 45 suites).**
>
> **Deviation, Task 1:** the hand-edited `.tscn` in Step 4 did not work — see
> spec §6.0. The `Backdrop` node was built with `scene_open` →
> `node_create` → `node_set_property` ×5 → `node_manage(op="move", index=0)`
> → `scene_save` instead. `anchors_preset` had to be replaced by setting
> `anchor_right`/`anchor_bottom` to `1` individually.
>
> **Deviation, Task 2:** the suite already has a `_CHECKUP_SCENE` constant
> (`tests/test_result_checkup.gd:21`); the new test uses that rather than
> adding `_SCENE_PATH`. The export was set via `node_set_property` on the
> root, then `scene_save`.

**Goal:** Put the new `blur_background.png` behind the Daily Results popup and the weekly ResultCheckup screen, so both read as the same blurred-classroom setting.

**Architecture:** `blur_background.png` is a **pre-blurred raster**, not the screen-space blur shader — see spec §1.1. DaySummary gets a new `Backdrop` `TextureRect` inserted as the root's first child, behind the existing `&"Scrim"` `DimOverlay`, which stays for text contrast. ResultCheckup already has a designed extension point for exactly this: `@export var background_texture: Texture2D`, which `_apply_visual_exports()` swaps in over the themed `Background` panel — so that screen needs a scene-level export assignment and no new code at all.

**Tech Stack:** Godot 4.6, GDScript, `godot-ai` MCP (`filesystem_manage`, `test_run`).

**Spec:** `docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md`

**Depends on:** `2026-09-01-splash-art-batch.md` Task 1 (`blur_background.png` must be imported).

## Global Constraints

- Godot **4.6**, portrait **1080×1920**, `mobile` renderer.
- **Never add a `theme_override_*`.** `tests/test_day_summary.gd:849` (`test_row_scene_declares_no_theme_overrides`) scans the scene source for `theme_override_colors` / `theme_override_fonts` / `theme_override_styles`. Layout-only constants (`separation`, `margin_*`) are the only accepted exception.
- **Do not reparent anything under ResultCheckup's `Margin`.** `tests/test_result_checkup.gd` hardcodes `Margin/VBox/ScrollContainer/MainContent/StudentsContainer`, `.../HistoryList` and `Margin/VBox/BtnClose`.
- **No new runtime visual construction.** `tests/test_viewport_editability.gd` freezes `Scripts/SchoolSimulation/ResultCheckup.gd` at **7** and it may only go down. This plan adds zero `.new()` calls.
- **`ext_resource` uids must be real.** `tests/test_project_hygiene.gd:48-72` asserts `ResourceUID.get_id_path(uid) == path` for every `[ext_resource]` in every scene. Read the uid out of the generated `.import`; never copy one from another asset.
- **Rescan after editing any `.gd`, before running tests.**
- Tests must be `@tool`; **no test may be a coroutine**.
- Assertion helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_not_null`, `assert_gt`, `assert_has_key`, `assert_contains`, `assert_is_error`, `track()`. No `assert_lt` / `assert_null` / `assert_almost_eq`.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scenes/SchoolSimulation/DaySummaryPopup.tscn` | The end-of-day recap modal | new `Backdrop` TextureRect at child index 0 |
| `Scenes/SchoolSimulation/ResultCheckup.tscn` | The end-of-week report screen | `background_texture` export assigned |
| `tests/test_day_summary.gd` | Pins the popup's structure | one test added |
| `tests/test_result_checkup.gd` | Pins the screen's structure | one test added |

---

## Task 1: Backdrop behind the Daily Results popup

**Files:**
- Modify: `Scenes/SchoolSimulation/DaySummaryPopup.tscn`
- Test: `tests/test_day_summary.gd`

**Interfaces:**
- Consumes: `res://Assets/Images/UI/blur_background.png` (plan 1, Task 1).
- Produces: a node at path `Backdrop` under the `DaySummaryPopup` root, type `TextureRect`, occupying child index 0. Nothing else reads it; `DaySummaryPopup.gd`'s `@onready` bindings (`$DimOverlay`, `$DimOverlay/Content`, `$DimOverlay/Content/RowsScroll/RowsContainer`) are unaffected because the new node is a sibling, not a parent.

The popup currently shows the live SchoolDay screen through a 72%-alpha scrim. The opaque backdrop replaces what shows through; the scrim stays so the white row text keeps its contrast against the warm art.

- [x] **Step 1: Write the failing test**

Append to `tests/test_day_summary.gd`:

```gdscript
## The popup sits over the live SchoolDay screen. An opaque blurred-
## classroom backdrop replaces that view so the recap reads as its own
## setting, and it must sit BEHIND the scrim -- in front, it would hide
## the dimming that keeps the white row text legible.
func test_popup_has_a_blurred_backdrop_behind_the_scrim() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	assert_not_null(scene, "DaySummaryPopup.tscn failed to load")
	var inst := scene.instantiate()

	var backdrop := inst.get_node_or_null("Backdrop") as TextureRect
	assert_not_null(backdrop, "popup is missing its Backdrop TextureRect")
	assert_not_null(backdrop.texture, "Backdrop has no texture assigned")
	assert_eq(backdrop.texture.resource_path,
		"res://Assets/Images/UI/blur_background.png",
		"Backdrop is not drawing blur_background.png")

	var dim := inst.get_node_or_null("DimOverlay")
	assert_not_null(dim, "popup is missing its DimOverlay")
	assert_true(backdrop.get_index() < dim.get_index(),
		"Backdrop must render behind DimOverlay")

	# 369x654 art on a 1080x1920 screen: it must fill, not letterbox.
	assert_eq(backdrop.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
		"Backdrop must ignore its texture's native size")
	assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Backdrop must cover the screen without distorting")

	inst.free()
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="day_summary")
```

Expected: FAIL with `popup is missing its Backdrop TextureRect`.

- [x] **Step 3: Read the generated uid**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep '^uid=' Assets/Images/UI/blur_background.png.import
```

Expected: one line like `uid="uid://xxxxxxxxxxxxx"`. Use that exact value in Step 4 — do not invent one.

- [x] **Step 4: Add the node to the scene**

Open `Scenes/SchoolSimulation/DaySummaryPopup.tscn`.

First, bump the `load_steps` count on line 1 by 1 (it must equal the number of `ext_resource` + `sub_resource` entries plus one).

Add an `ext_resource` line alongside the existing ones near the top, substituting the uid from Step 3:

```
[ext_resource type="Texture2D" uid="uid://REPLACE_WITH_STEP_3_UID" path="res://Assets/Images/UI/blur_background.png" id="3_backdrop"]
```

If `id="3_backdrop"` collides with an existing id in that file, pick the next free number instead and use it consistently below.

Then insert this node block **immediately before** the `[node name="DimOverlay" ...]` block, so it lands at child index 0:

```
[node name="Backdrop" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("3_backdrop")
expand_mode = 1
stretch_mode = 6
```

`mouse_filter = 2` is `MOUSE_FILTER_IGNORE` — the backdrop must not eat the popup's tap-anywhere dismiss. `expand_mode = 1` is `EXPAND_IGNORE_SIZE`; `stretch_mode = 6` is `STRETCH_KEEP_ASPECT_COVERED`.

- [x] **Step 5: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="day_summary")
```

Expected: `test_popup_has_a_blurred_backdrop_behind_the_scrim` PASSES, and the rest of the suite stays green — in particular `test_row_scene_declares_no_theme_overrides` and the popup-structure tests.

- [x] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/DaySummaryPopup.tscn tests/test_day_summary.gd && git commit -m "feat(day-summary): put the blurred classroom backdrop behind the recap"
```

---

## Task 2: Backdrop on the weekly ResultCheckup

**Files:**
- Modify: `Scenes/SchoolSimulation/ResultCheckup.tscn` (root node's exported properties)
- Test: `tests/test_result_checkup.gd`

**Interfaces:**
- Consumes: `res://Assets/Images/UI/blur_background.png` (plan 1, Task 1).
- Produces: nothing new. `ResultCheckup.gd:124-138` (`_apply_visual_exports`) already swaps the themed `Background` `Panel` for a full-rect `TextureRect` named `Background` at child index 0 whenever `background_texture` is set. No script change.

This is the one screen where the work is a single property assignment. The swap code sets `EXPAND_IGNORE_SIZE` + `STRETCH_SCALE` on a full-rect preset; with the art's aspect only 0.3% off the screen's, the stretch is imperceptible.

- [x] **Step 1: Write the failing test**

Append to `tests/test_result_checkup.gd`:

```gdscript
## The screen ships with a themed SunkenPanel backdrop and an @export that
## replaces it with art. Assigning the blurred classroom there keeps the
## weekly report in the same setting as the nightly popup, and reuses the
## existing swap in _apply_visual_exports rather than adding a node.
func test_screen_declares_the_blurred_backdrop_texture() -> void:
	var scene := load(_SCENE_PATH) as PackedScene
	assert_not_null(scene, "ResultCheckup.tscn failed to load")
	var inst := scene.instantiate()

	var tex: Texture2D = inst.background_texture
	assert_not_null(tex, "background_texture export is not assigned")
	assert_eq(tex.resource_path, "res://Assets/Images/UI/blur_background.png",
		"background_texture is not blur_background.png")

	inst.free()
```

That suite has no `_SCENE_PATH` constant — it only defines `_ROW_SCENE` and `_ROW_SCRIPT` (lines 19-20). Add it beside them:

```gdscript
const _SCENE_PATH := "res://Scenes/SchoolSimulation/ResultCheckup.tscn"
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="result_checkup")
```

Expected: FAIL with `background_texture export is not assigned`.

- [x] **Step 3: Read the generated uid**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep '^uid=' Assets/Images/UI/blur_background.png.import
```

- [x] **Step 4: Assign the export in the scene**

Open `Scenes/SchoolSimulation/ResultCheckup.tscn`.

Bump `load_steps` on line 1 by 1, then add an `ext_resource` line with the uid from Step 3, picking an `id` that does not collide with an existing one:

```
[ext_resource type="Texture2D" uid="uid://REPLACE_WITH_STEP_3_UID" path="res://Assets/Images/UI/blur_background.png" id="3_backdrop"]
```

Then add a `background_texture` line to the **root** node block, alongside the existing `student_card_scene` assignment:

```
[node name="ResultCheckup" type="Control" unique_id=1540732834]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_checkup")
student_card_scene = ExtResource("2_ouvge")
background_texture = ExtResource("3_backdrop")
```

Leave the `Background` `Panel` node exactly as it is — `_apply_visual_exports()` frees it and inserts the TextureRect at index 0 at runtime. Removing it by hand would break the `is Panel` guard that stops a second call stacking a duplicate.

- [x] **Step 5: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="result_checkup")
```

Expected: `test_screen_declares_the_blurred_backdrop_texture` PASSES and the rest of the suite stays green — especially the tests that resolve `Margin/VBox/ScrollContainer/MainContent/StudentsContainer` and `.../HistoryList`.

- [x] **Step 6: Confirm the ratchet did not move**

```
test_run(suite="viewport_editability")
```

Expected: PASS. This plan adds no `.new()` call, so `ResultCheckup.gd` must still count exactly 7.

- [x] **Step 7: Commit**

```bash
git add Scenes/SchoolSimulation/ResultCheckup.tscn tests/test_result_checkup.gd && git commit -m "feat(result-checkup): use the blurred classroom as the screen backdrop"
```

---

## Verification

- [x] `test_run()` — every suite green, `viewport_editability` included.
- [x] Screenshot check: seed playtest state (`F1` → ⚡ Seed Playtest State), pass through Atur Jadwal to fill `day_schedules`, then run a week. Confirm the nightly Daily Results popup and the weekly ResultCheckup both sit on the blurred classroom, and that row text is still legible against it.
- [x] If the DaySummary text turns out too low-contrast over the warm art, raise `overlay_scrim_alpha` in `Assets/Theme/design_tokens.tres` and rebake (`Scripts/Design/BakeTheme.gd`, File > Run) — do **not** add a `theme_override_*` or a second scrim node.

## Follow-up, not in this plan

`ResultCheckup.gd`'s Panel→TextureRect swap is runtime visual construction counted in `test_viewport_editability.gd`'s `BASELINE`. Now that the backdrop is permanent, authoring `Background` as a `TextureRect` directly in the scene and deleting the swap would let that baseline drop. It touches the `is Panel` guard and the `SunkenPanel` fallback, so it belongs in its own task.
