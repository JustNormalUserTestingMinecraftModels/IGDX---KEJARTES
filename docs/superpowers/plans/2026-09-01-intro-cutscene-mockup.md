# Intro Cutscene Mockup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **STATUS — executed 2026-09-01, both tasks complete. Suite green (568/568,
> 45 suites).**
>
> **Deviation:** a node's *type* cannot be changed in place, so `DialogueBox`
> was deleted and recreated as a `TextureRect`, and `DialogueLabel` recreated
> inside it. That was safe here because `DialogueLabel` carried nothing but
> offsets — check before repeating this on a richer node.
>
> Task 1 Step 6 (widening `dialogue_box: Panel` to `Control`) was done FIRST,
> before the scene edit, so the scene never loaded against a stale annotation.
> Placement verified by compositing `cg0.jpg` + `cutscene_dialogue.png` at
> (0, 940) offline rather than by screenshot — the opaque `FadeOverlay` makes
> an editor capture useless here.

**Goal:** Rebuild the intro cutscene to `mockup_intro_cutscene.png` — the CG filling the frame, with the dialogue moved into the `cutscene_dialogue.png` panel across the lower third.

**Architecture:** The dialogue currently sits in a `Panel` wearing the `&"Card"` theme variation at offsets 165,629 → 908,896. The mockup replaces that with supplied panel art. Because the art is 1:1 with its on-screen size, `DialogueBox` becomes a `TextureRect` at offset (0, 940) at the texture's native 1080×1080, which lands the opaque panel within 1 px of the mockup on every edge. The text and the tap hint move inside its white content area. The two hardcoded full-screen rects that miss 1080×1920 are corrected while we are in the file.

**Tech Stack:** Godot 4.6, GDScript, `godot-ai` MCP (`filesystem_manage`, `test_run`).

**Spec:** `docs/superpowers/specs/2026-09-01-art-pass-and-screen-restyle.md`

**Depends on:** `2026-09-01-splash-art-batch.md` Task 1 (`cutscene_dialogue.png` must be imported).

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
- **No `Color(` literal in `cut_scene.gd`.** `tests/test_cutscene.gd:117` runs the regex `Color\s*\(` and requires zero matches. Anything needing a colour reads `DesignTokens` (the script already uses `_tokens.scrim_color()`).
- **Never add a `theme_override_*`.** `tests/test_cutscene.gd` scans the scene.
- **`tests/test_viewport_editability.gd` freezes `Scripts/CutScene/cut_scene.gd` at 15** and it may only go down. This plan adds **zero** `.new()` calls — every change is scene data.
- **`ext_resource` uids must be real.** `tests/test_project_hygiene.gd:48-72` asserts `ResourceUID.get_id_path(uid) == path`. Read the uid from the generated `.import`.
- **Do not touch the advance mechanics.** `_input()` (`cut_scene.gd:328`), `_on_tap()` (`:344`), `advance()` (`:354`) and `transition_to_next()` (`:363`) implement a two-tap visual-novel contract pinned by four tests. This plan only moves where the text is drawn.
- **`cut_scene.gd` has uncommitted changes** on the working tree (the `cg0.jpg` swap). Do not revert them.
- **Rescan after editing any `.gd`, before running tests.**
- Tests must be `@tool`; **no test may be a coroutine**.
- Assertion helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_not_null`, `assert_gt`, `assert_has_key`, `assert_contains`, `assert_is_error`, `track()`. No `assert_lt` / `assert_null` / `assert_almost_eq`.
- UI text is Indonesian.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scenes/CutScene/cut_scene.tscn` | The cutscene screen | `DialogueBox` becomes a TextureRect; label and hint repositioned; two rects corrected |
| `tests/test_cutscene.gd` | Pins the screen | one test replaced, two added |

`Scripts/CutScene/cut_scene.gd` needs **no change**. `@onready var dialogue_label: RichTextLabel = $DialogueBox/DialogueLabel` (`:24`) and `@onready var dialogue_box: Panel = $DialogueBox` (`:25`) both keep resolving — except that `dialogue_box`'s static type must widen, which Task 1 Step 6 covers.

---

## Task 1: Move the dialogue into the panel art

**Files:**
- Modify: `Scenes/CutScene/cut_scene.tscn` — `DialogueBox`, `DialogueBox/DialogueLabel`, `HintLabel`
- Modify: `Scripts/CutScene/cut_scene.gd:25` (type annotation only)
- Test: `tests/test_cutscene.gd`

**Interfaces:**
- Consumes: `res://Assets/Images/UI/cutscene_dialogue.png` (plan 1, Task 1).
- Produces: `DialogueBox` is a `TextureRect` at the same node path; `DialogueBox/DialogueLabel` keeps its path and stays a `RichTextLabel`. `_reveal()` (`cut_scene.gd:319`) — the single writer of `dialogue_label.text` — is untouched.

Measured placement (spec §5): the art is 1080×1080 with its opaque panel at x 66…1013, y 164…915. Placing the texture at **(0, 940)** at native size lands the panel at x 66…1013, y 1104…1855 — within 1 px of the mockup's measured x 68…1015, y 1105…1856 on every edge. The transparent remainder overflows the 1920 bottom harmlessly.

Inner white content area on screen: **x 110…967, y 1148…1815**. In `DialogueBox`-local coordinates (origin 0,940) that is x 110…967, y 208…875.

- [x] **Step 1: Replace the test that pins the old design**

In `tests/test_cutscene.gd`, replace `test_dialogue_box_uses_the_card_variation` entirely — it pins the design being replaced, not an invariant:

```gdscript
## The mockup supplies the panel as art (cutscene_dialogue.png), so the
## box draws a texture instead of the Card stylebox. The art is 1:1 with
## its on-screen size, so it is placed at its native 1080x1080 with no
## scaling -- see the spec, section 5.
func test_dialogue_box_draws_the_mockup_panel_art() -> void:
	var box := _scene.get_node_or_null("DialogueBox") as TextureRect
	assert_not_null(box, "DialogueBox is missing or is no longer a TextureRect")
	assert_not_null(box.texture, "DialogueBox has no texture")
	assert_eq(box.texture.resource_path,
		"res://Assets/Images/UI/cutscene_dialogue.png",
		"DialogueBox is not drawing the mockup's panel art")
	assert_eq(box.offset_left, 0.0, "panel left")
	assert_eq(box.offset_top, 940.0, "panel top")
	assert_eq(box.offset_right, 1080.0, "panel right")
	assert_eq(box.offset_bottom, 2020.0, "panel bottom (native 1080 tall)")


## The text and the tap hint must both sit inside the panel's white
## content area -- screen x 110-967, y 1148-1815, which is x 110-967,
## y 208-875 in the box's own coordinates. Outside it they would print
## over the orange frame.
func test_dialogue_text_sits_inside_the_panel_content_area() -> void:
	var label := _scene.get_node_or_null("DialogueBox/DialogueLabel") as Control
	assert_not_null(label, "DialogueLabel is missing")
	assert_true(label.offset_left >= 110.0, "text starts left of the frame")
	assert_true(label.offset_right <= 967.0, "text runs past the right frame")
	assert_true(label.offset_top >= 208.0, "text starts above the frame")
	assert_true(label.offset_bottom <= 875.0, "text runs past the bottom frame")

	var hint := _scene.get_node_or_null("HintLabel") as Control
	assert_not_null(hint, "HintLabel is missing")
	assert_true(hint.offset_top >= 1148.0,
		"the tap hint sits above the panel's content area")
	assert_true(hint.offset_bottom <= 1815.0,
		"the tap hint runs past the panel's content area")
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="cutscene")
```

Expected: `test_dialogue_box_draws_the_mockup_panel_art` FAILS with `DialogueBox is missing or is no longer a TextureRect` (it is currently a `Panel`, so the cast yields null).

- [x] **Step 3: Read the generated uid**

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep '^uid=' Assets/Images/UI/cutscene_dialogue.png.import
```

- [x] **Step 4: Swap the panel for the art**

In `Scenes/CutScene/cut_scene.tscn`:

1. Bump `load_steps` on line 1 by 1.

2. Add an `ext_resource` line beside the others, with the uid from Step 3 and a free `id`:

```
[ext_resource type="Texture2D" uid="uid://REPLACE_WITH_STEP_3_UID" path="res://Assets/Images/UI/cutscene_dialogue.png" id="4_dialogue"]
```

3. Replace the whole `DialogueBox` node block with:

```
[node name="DialogueBox" type="TextureRect" parent="."]
layout_mode = 0
offset_right = 1080.0
offset_top = 940.0
offset_bottom = 2020.0
mouse_filter = 2
texture = ExtResource("4_dialogue")
```

`mouse_filter = 2` (`MOUSE_FILTER_IGNORE`) matters: the tap-to-advance is a global `_input()` handler, and a panel that stopped input would swallow taps in the lower third of the screen. Do **not** set `expand_mode` or `stretch_mode` — the default draws the texture at its native size, which is the point.

Note the removed `theme_type_variation = &"Card"` line; that variation stays defined in `ThemeFactory` for its other users.

- [x] **Step 5: Reposition the text and the hint**

Replace the `DialogueLabel` block's geometry (keeping its `bbcode`/`text`/other properties if present) so it sits inside the content area with a 40 px inset, leaving room for the hint beneath:

```
[node name="DialogueLabel" type="RichTextLabel" parent="DialogueBox"]
layout_mode = 0
offset_left = 150.0
offset_top = 248.0
offset_right = 927.0
offset_bottom = 790.0
```

Then move `HintLabel` — a root child, so its offsets are screen coordinates — into the bottom of the white area:

```
[node name="HintLabel" type="Label" parent="."]
layout_mode = 0
offset_left = 110.0
offset_top = 1745.0
offset_right = 967.0
offset_bottom = 1805.0
theme_type_variation = &"CaptionLabel"
horizontal_alignment = 1
text = "Ketuk untuk melanjutkan"
script = ExtResource("3_hint_lbl")
```

Keep the `script` reference — `hint_label.gd` bobs it ±10 px forever, and the bob is relative to its position.

- [x] **Step 6: Widen the script's type annotation**

`Scripts/CutScene/cut_scene.gd:25` declares `@onready var dialogue_box: Panel = $DialogueBox`. The node is no longer a `Panel`, so that annotation would fail at load. The variable is bound but never read anywhere in the script, so widen it rather than removing it:

```gdscript
@onready var dialogue_box: Control = $DialogueBox
```

- [x] **Step 7: Run the tests to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="cutscene")
```

Expected: both new tests PASS and the rest of the suite is green — especially the four that pin the advance mechanics (`test_tap_during_reveal_completes_the_line_instead_of_advancing`, `test_typewriter_reveal_uses_visible_ratio_not_character_slicing`, `test_cg_changes_crossfade_instead_of_hard_cutting`, `test_show_current_starts_with_a_hold_before_revealing`) and `test_scene_has_no_theme_overrides`.

- [x] **Step 8: Commit**

```bash
git add Scenes/CutScene/cut_scene.tscn Scripts/CutScene/cut_scene.gd tests/test_cutscene.gd && git commit -m "feat(cutscene): move the dialogue into the mockup's panel art"
```

---

## Task 2: Correct the two full-screen rects

**Files:**
- Modify: `Scenes/CutScene/cut_scene.tscn` — `BgCutScene`, `FadeOverlay`
- Test: `tests/test_cutscene.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: no API change. `@onready var bg_cutscene: TextureRect = $BgCutScene` (`cut_scene.gd:26`) keeps resolving; the script assigns `bg_cutscene.texture` and tweens `bg_cutscene.modulate:a`, neither of which depends on the rect.

Both nodes are hardcoded rects that miss the project's 1080×1920: `BgCutScene` is 1075×1925 and `FadeOverlay` is 1088×1934, and neither is anchored. The CG is therefore 5 px short horizontally and 5 px over vertically, and the black fade overruns the screen. Anchoring both to the full rect fixes it and makes them resolution-independent.

- [x] **Step 1: Write the failing test**

Append to `tests/test_cutscene.gd`:

```gdscript
## Both were authored as hardcoded rects that miss 1080x1920 -- the CG
## 1075x1925, the fade 1088x1934 -- so the CG was 5px short across and the
## fade overran the screen. Anchoring both makes them exact and
## resolution-independent.
func test_the_full_screen_layers_fill_the_screen_exactly() -> void:
	for node_name in ["BgCutScene", "FadeOverlay"]:
		var node := _scene.get_node_or_null(node_name) as Control
		assert_not_null(node, "%s is missing" % node_name)
		assert_eq(node.anchor_right, 1.0, "%s must anchor to the right edge"
			% node_name)
		assert_eq(node.anchor_bottom, 1.0, "%s must anchor to the bottom edge"
			% node_name)
		assert_eq(node.offset_right, 0.0, "%s has a stray right offset"
			% node_name)
		assert_eq(node.offset_bottom, 0.0, "%s has a stray bottom offset"
			% node_name)
```

- [x] **Step 2: Run it to verify it fails**

```
test_run(suite="cutscene")
```

Expected: FAIL with `BgCutScene must anchor to the right edge` (it is currently `layout_mode = 0` with no anchors).

- [x] **Step 3: Anchor both nodes**

In `Scenes/CutScene/cut_scene.tscn`, replace the `BgCutScene` block's layout lines:

```
[node name="BgCutScene" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
stretch_mode = 6
```

Keep its `texture` line (the placeholder `BG.jpg`, which the script overwrites at runtime) and `stretch_mode = 6` (`STRETCH_KEEP_ASPECT_COVERED`). Delete `offset_right` and `offset_bottom`.

Then `FadeOverlay`:

```
[node name="FadeOverlay" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0, 0, 0, 1)
```

Keep `mouse_filter = 2` and the `color` line — a `ColorRect`'s colour is scene data, and the no-`Color(`-literal rule applies to scripts, not scenes.

- [x] **Step 4: Confirm FadeOverlay still draws above the panel**

`FadeOverlay` must remain **after** `DialogueBox` in the file, or the entrance fade will not cover the dialogue. Check the node order:

```bash
cd "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && grep -n '^\[node name=' Scenes/CutScene/cut_scene.tscn
```

Expected order: `CutScene`, `BgCutScene`, `DialogueBox`, `DialogueLabel`, `FadeOverlay`, `HintLabel`. If `FadeOverlay` sits before `DialogueBox`, move its block down.

- [x] **Step 5: Run the test to verify it passes**

```
filesystem_manage(op="scan")
test_run(suite="cutscene")
```

Expected: PASS, whole suite green.

- [x] **Step 6: Run the full suite**

```
test_run()
```

Expected: every suite green, `project_hygiene` and `viewport_editability` included.

- [x] **Step 7: Commit**

```bash
git add Scenes/CutScene/cut_scene.tscn tests/test_cutscene.gd && git commit -m "fix(cutscene): anchor the CG and fade layers to the real screen size"
```

---

## Verification

- [x] `test_run()` — every suite green.
- [x] Screenshot check against `docs/superpowers/mockups/mockup_intro_cutscene.png`. The cutscene is the boot flow's second screen (MainMenu → CutScene), or teleport via the debug overlay's Scenes tab. Confirm:
  - the CG fills the frame edge to edge with no letterbox;
  - the orange panel sits across the lower third with even margins (~65 px left, right and bottom);
  - the dialogue text wraps inside the white area and never crosses the orange frame;
  - "Ketuk untuk melanjutkan" sits inside the panel, below the text, still bobbing.
- [x] Tap through all five CG entries. Confirm the two-tap contract still holds: a tap mid-reveal completes the line, the next tap advances. Check the **longest** line (the cg4 text, the longest in `cg_data`) still fits the box without clipping — if it overflows, reduce `DialogueLabel`'s `offset_bottom` toward 790 rather than shrinking the font.

## Out of scope

- The game-over cutscene branch (`_setup_game_over_cutscene`, `cut_scene.gd:86-115`), which reassigns `cg_data` wholesale to five entries that all still use `res://Assets/Images/UI/BG.jpg` — the CG art was never swapped in for that path. Worth doing; not this plan.
- Lowering `cut_scene.gd`'s `BASELINE` of 15 by extracting its runtime-built top bar and level-select overlay into scene data. The authoring guide lists it as an unsurveyed candidate.
